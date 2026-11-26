import crypto from "node:crypto"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

const HOME = os.homedir()
const CONFIG_PATH = path.join(HOME, ".config/opencode/leader-gate.json")
const DEFAULT_CONFIG = {
  enabled: true,
  semantic: true,
  judgeModel: "magpie/group/reviewplan",
  maxSteers: 2,
  enforceOneSession: true,
  enforceOneSessionAll: true,
  enforceGate: true,
  prepEnabled: true,
  artifactHash: true,
  logFile: path.join(HOME, ".local/share/opencode/leader-gate.log"),
}
const GATED_AGENTS = new Set(["review", "reviewplan"])
const ALL_AGENTS = new Set(["review", "reviewplan", "coder", "tester", "tester2", "tester3"])

function readConfig() {
  try {
    return { ...DEFAULT_CONFIG, ...JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8")) }
  } catch {
    return { ...DEFAULT_CONFIG }
  }
}

function log(cfg, event, data = {}) {
  try {
    fs.mkdirSync(path.dirname(cfg.logFile), { recursive: true })
    fs.appendFileSync(cfg.logFile, JSON.stringify({ ts: new Date().toISOString(), event, ...data }) + "\n")
  } catch {}
}

function parseKV(block) {
  const out = {}
  for (const line of block.split("\n")) {
    const m = line.match(/^\s*([A-Za-z_][\w-]*)\s*:\s*(.*?)\s*$/)
    if (m) out[m[1].toLowerCase()] = m[2]
  }
  return out
}

export function parseGate(prompt) {
  if (typeof prompt !== "string") return null
  const m = prompt.match(/(?:^|\n)GATE:\s*\n([\s\S]*?)(?=\n(?:GATE_REPORT:|##|---)|$)/)
  if (!m) return null
  const kv = parseKV(m[1])
  if (!kv.decision_id || !kv.phase || !kv.agent || !kv.scope || !kv.r || !kv.expected) return null
  return {
    decision_id: kv.decision_id,
    phase: kv.phase,
    agent: kv.agent,
    scope: kv.scope,
    r: kv.r.split(",").map((s) => s.trim()).filter(Boolean),
    expected: kv.expected,
    stop_if: kv.stop_if || "",
    artifact: kv.artifact || "",
    artifact_revision: kv.artifact_revision || "",
    artifact_hash: kv.artifact_hash || "",
    raw: m[0].trim(),
  }
}

export function parseSteer(prompt) {
  if (typeof prompt !== "string") return null
  const m = prompt.match(/(?:^|\n)STEER:\s*\n([\s\S]*?)(?=\n(?:GATE_REPORT:|GATE:|##|---)|$)/)
  if (!m) return null
  const kv = parseKV(m[1])
  if (!kv.decision_id || !kv.scope || !kv.r) return null
  return {
    decision_id: kv.decision_id,
    phase: kv.phase || "",
    agent: kv.agent || "",
    scope: kv.scope,
    r: kv.r.split(",").map((s) => s.trim()).filter(Boolean),
    expected: kv.expected || "",
    stop_if: kv.stop_if || "",
    artifact: kv.artifact || "",
    artifact_revision: kv.artifact_revision || "",
    artifact_hash: kv.artifact_hash || "",
    raw: m[0].trim(),
  }
}

const VERDICT_ALIASES = {
  "ĐẠT": "PASS",
  "ĐÃ SỬA": "PASS",
  "KHÔNG ĐẠT": "BLOCKED",
  "CẦN ĐIỀU TRA": "BLOCKED",
  "GO": "PASS",
  "STEER": "BLOCKED",
  "SẴN SÀNG": "PREP_READY",
  "CHƯA SẴN SÀNG": "PREP_BLOCKED",
}

function normalizeVerdict(raw) {
  const v = String(raw || "").toUpperCase()
  return VERDICT_ALIASES[v] || v
}

export function parseReport(text) {
  if (typeof text !== "string") return null
  const m = text.match(/(?:^|\n)GATE_REPORT:\s*\n([\s\S]*?)(?=\n(?:##|---)|$)/)
  if (!m) return null
  const kv = parseKV(m[1])
  return {
    decision_id: kv.decision_id || "",
    scope: kv.scope || "",
    r_covered: (kv.r_covered || kv.r || "").split(",").map((s) => s.trim()).filter(Boolean),
    verdict: normalizeVerdict(kv.verdict),
    evidence: kv.evidence || "",
    artifact_hash: kv.artifact_hash || "",
    raw: m[0].trim(),
  }
}

function lastAssistantText(messages) {
  const list = messages?.data ?? messages ?? []
  for (let i = list.length - 1; i >= 0; i--) {
    const m = list[i]
    if (m?.type !== "assistant") continue
    const parts = Array.isArray(m.content) ? m.content.filter((p) => p?.type === "text").map((p) => p.text) : []
    return parts.join("\n")
  }
  return ""
}

function hashText(text) {
  let h = 0
  for (let i = 0; i < text.length; i++) h = (Math.imul(31, h) + text.charCodeAt(i)) | 0
  return `${text.length}:${h}`
}

function findSessionID(value, depth = 0) {
  if (!value || depth > 4) return null
  if (typeof value === "string") return null
  if (typeof value === "object") {
    if (typeof value.sessionID === "string") return value.sessionID
    for (const v of Object.values(value)) {
      const found = findSessionID(v, depth + 1)
      if (found) return found
    }
  }
  return null
}

export function renderContract(gate) {
  const isPrep = gate.phase === "PREP"
  const hashRequired = gate.agent === "reviewplan" && ["PLAN", "GATE", "AUDIT"].includes(gate.phase)
  const hashValue = hashRequired
    ? gate.artifact_hash || "<sha256>"
    : "<sha256 thật của artifact; điền sau khi freeze>"
  const verdictLine = isPrep ? "verdict: PREP_READY|PREP_BLOCKED" : "verdict: PASS|BLOCKED"
  const verdictRule = isPrep
    ? "PREP chỉ dùng PREP_READY hoặc PREP_BLOCKED; không chấm PASS/BLOCKED khi chưa có artifact đóng băng."
    : "Chỉ dùng PASS hoặc BLOCKED; STEER là hành động của Leader, không phải verdict của report."
  return [
    "---",
    "## GATE CONTRACT (plugin-injected)",
    "Bạn đang bị Leader gác. Không đổi scope, R, expected.",
    `artifact: ${gate.artifact || "<path>"}`,
    `artifact_revision: ${gate.artifact_revision || "<rN>"}`,
    `artifact_hash: ${hashValue}`,
    "Cuối báo cáo, bắt buộc thêm:",
    "GATE_REPORT:",
    `decision_id: ${gate.decision_id}`,
    `scope: ${gate.scope}`,
    `R_covered: <R đã kiểm, vd ${gate.r.join(",")}>`,
    verdictLine,
    verdictRule,
    "evidence: <file:line / lệnh / output>",
    `artifact_hash: ${hashValue}`,
    `Nếu không thể theo đúng gate, ghi verdict: ${isPrep ? "PREP_BLOCKED" : "BLOCKED"} kèm lý do.`,
    "---",
  ].join("\n")
}

export function renderSteer(gate, verdict) {
  return [
    "STEER:",
    `decision_id: ${gate.decision_id}`,
    `phase: ${gate.phase || ""}`,
    `agent: ${gate.agent || ""}`,
    `scope: ${gate.scope}`,
    `R: ${gate.r.join(",")}`,
    `expected: ${gate.expected || ""}`,
    `artifact_hash: ${gate.artifact_hash || "<sha256>"}`,
    "",
    "Báo cáo trước đó lệch gate:",
    ...verdict.reasons.map((r) => `- ${r}`),
    "",
    "Sửa đúng các điểm sau, giữ nguyên phần còn lại, không mở rộng:",
    ...(verdict.corrections || []).map((c) => `- ${c}`),
    "",
    "Kết thúc bằng GATE_REPORT đúng contract.",
  ].join("\n")
}

function modelRef(ref) {
  if (!ref || typeof ref !== "string") return null
  const slash = ref.indexOf("/")
  if (slash <= 0 || slash === ref.length - 1) return null
  const providerID = ref.slice(0, slash)
  const rest = ref.slice(slash + 1)
  const hash = rest.indexOf("#")
  if (hash > 0) return { providerID, id: rest.slice(0, hash), variant: rest.slice(hash + 1) }
  return { providerID, id: rest }
}

async function findChild(ctx, parentID, agent) {
  try {
    const page = await ctx.session.list({ parentID, directory: ctx.location.directory, limit: 20, order: "desc" })
    const list = page?.data ?? page ?? []
    return list.find((s) => s.agent === agent)?.id ?? null
  } catch {
    return null
  }
}

async function findActiveChild(ctx, parentID, agent) {
  try {
    const page = await ctx.session.list({ parentID, directory: ctx.location.directory, limit: 20, order: "desc" })
    const list = page?.data ?? page ?? []
    const candidates = list.filter((s) => s.agent === agent)
    if (!candidates.length) return null

    // A run interrupted by a crash or shutdown leaves time.busy set and time.idle unset,
    // so the time fields alone would keep that session "active" forever. The active
    // endpoint is authoritative: a session absent from it is not running.
    try {
      const res = await ctx.session.active()
      const data = res?.data ?? res ?? {}
      const running = new Set(
        Array.isArray(data)
          ? data.map((v) => (typeof v === "string" ? v : v?.id)).filter(Boolean)
          : Object.entries(data)
              .filter(([, v]) => v === true || v === "running" || v?.type === "running")
              .map(([id]) => id),
      )
      return candidates.find((s) => running.has(s.id)) ?? null
    } catch {
      // fall through to the time heuristic when the endpoint is unavailable
    }

    const now = Date.now()
    return (
      candidates.find(
        (s) =>
          s.time?.busy &&
          (!s.time?.idle || s.time.busy > s.time.idle) &&
          now - (s.time.updated ?? s.time.busy) < 10 * 60 * 1000,
      ) ?? null
    )
  } catch {
    return null
  }
}

function normHash(value) {
  return String(value || "").replace(/^sha256:/i, "").trim()
}

function artifactHash(ctx, gate) {
  if (!gate.artifact || !ctx?.location?.directory) return null
  const abs = path.isAbsolute(gate.artifact) ? gate.artifact : path.resolve(ctx.location.directory, gate.artifact)
  let bytes
  try {
    bytes = fs.readFileSync(abs)
  } catch {
    return { ok: false, reason: `Không đọc được artifact: ${gate.artifact}` }
  }
  const normalized = bytes.toString("utf8").replace(/^artifact_hash: .*$/m, "artifact_hash: SELF")
  return {
    ok: true,
    abs,
    hash: crypto.createHash("sha256").update(normalized, "utf8").digest("hex"),
  }
}

async function judge(ctx, cfg, gate, reportText) {
  if (!cfg.semantic || !cfg.judgeModel) return { ok: true, skipped: true }
  const model = modelRef(cfg.judgeModel)
  if (!model) return { ok: true, skipped: true, reason: "judgeModel invalid" }
  const prompt = [
    "Bạn là cổng gác của Leader. So báo cáo của subagent với quyết định gate.",
    'Chỉ trả JSON: {"verdict":"GO"|"STEER"|"BLOCK","reasons":["..."],"corrections":["..."]}.',
    "STEER nếu báo cáo: đổi scope, bỏ R, tự thêm yêu cầu, dùng gate không có trong quyết định, hoặc thiếu bằng chứng.",
    "Không STEER chỉ vì báo cáo nhắc tên artifact của phase sau (ví dụ plan.md trong BRIEF) nếu báo cáo ghi rõ nó ngoài phạm vi phase hiện tại.",
    "Report chỉ có verdict PASS hoặc BLOCKED (PASS hợp lệ khi bằng chứng đủ). Không đòi verdict tiếng Việt (ĐẠT/ĐÃ SỬA/...); chỉ chấm nội dung, không chấm verdict string.",
    "",
    "GATE:",
    gate.raw,
    "",
    "REPORT:",
    reportText,
  ].join("\n")
  try {
    const out = await ctx.experimental.generate.text({ model, prompt })
    const text = out?.text ?? out?.data?.text ?? ""
    const json = JSON.parse(text.replace(/^```json\s*/i, "").replace(/```$/i, "").trim())
    const verdict = String(json.verdict || "").toUpperCase()
    log(cfg, "judge.result", { decision_id: gate.decision_id, verdict })
    if (verdict === "GO") return { ok: true }
    return {
      ok: false,
      reasons: Array.isArray(json.reasons) && json.reasons.length ? json.reasons : [`judge: ${verdict || "?"}`],
      corrections: Array.isArray(json.corrections) && json.corrections.length ? json.corrections : ["Bám đúng gate đã giao."],
    }
  } catch (e) {
    log(cfg, "judge.error", { decision_id: gate.decision_id, error: e?.message || String(e) })
    return { ok: true, warning: "judge unavailable: " + (e?.message || e) }
  }
}

export async function evaluate(ctx, cfg, gate, text) {
  const report = parseReport(text)
  if (!report) {
    return {
      ok: false,
      reasons: ["Thiếu GATE_REPORT ở cuối báo cáo."],
      corrections: ["Thêm GATE_REPORT đúng contract."],
    }
  }
  if (report.decision_id !== gate.decision_id) {
    return {
      ok: false,
      reasons: [`decision_id lệch: ${report.decision_id || "?"} != ${gate.decision_id}`],
      corrections: ["Dùng đúng decision_id của gate."],
    }
  }
  if (report.scope !== gate.scope) {
    return {
      ok: false,
      reasons: [`scope lệch: ${report.scope || "?"} != ${gate.scope}`],
      corrections: ["Giữ đúng scope."],
    }
  }
  const missing = gate.r.filter((r) => !report.r_covered.includes(r))
  if (missing.length) {
    return {
      ok: false,
      reasons: [`Thiếu R: ${missing.join(",")}`],
      corrections: [`Bổ sung R: ${missing.join(",")}`],
    }
  }
  if (gate.phase === "PREP") {
    if (report.verdict === "PREP_BLOCKED") return { ok: true, blocked: true, prep: true }
    if (report.verdict !== "PREP_READY") {
      return {
        ok: false,
        reasons: [`PREP verdict=${report.verdict || "?"}`],
        corrections: ["Chỉ dùng PREP_READY hoặc PREP_BLOCKED cho phase PREP."],
      }
    }
    return { ok: true, prep: true }
  }
  if (cfg.artifactHash && gate.agent === "reviewplan" && ["PLAN", "GATE", "AUDIT"].includes(gate.phase)) {
    if (!gate.artifact) {
      return {
        ok: false,
        reasons: ["Thiếu artifact path trong GATE."],
        corrections: ["Ghi artifact: <path plan.md> trong GATE."],
      }
    }
    if (!gate.artifact_hash) {
      return {
        ok: false,
        reasons: ["Thiếu artifact_hash trong GATE."],
        corrections: ["Freeze plan và ghi artifact_hash trước khi gate."],
      }
    }
    const verified = artifactHash(ctx, gate)
    if (verified && !verified.ok) {
      return {
        ok: false,
        reasons: [verified.reason],
        corrections: ["Kiểm lại artifact path; không gate khi không đọc được file."],
      }
    }
    if (verified && normHash(verified.hash) !== normHash(gate.artifact_hash)) {
      return {
        ok: false,
        reasons: [`artifact_hash không khớp file: ${normHash(verified.hash)} != ${normHash(gate.artifact_hash)}`],
        corrections: ["Tính lại hash theo quy ước SELF từ plan.md và cập nhật GATE."],
      }
    }
    if (normHash(report.artifact_hash) !== normHash(gate.artifact_hash)) {
      return {
        ok: false,
        reasons: [`artifact_hash lệch: ${report.artifact_hash || "?"} != ${gate.artifact_hash}`],
        corrections: ["Copy đúng artifact_hash từ GATE vào GATE_REPORT; gate lại trên artifact đã freeze."],
      }
    }
  }
  if (report.verdict === "BLOCKED") return { ok: true, blocked: true }
  if (report.verdict !== "PASS") {
    return {
      ok: false,
      reasons: [`verdict=${report.verdict || "?"}`],
      corrections: ["Chỉ PASS khi đã kiểm đủ; nếu không, BLOCKED kèm lý do."],
    }
  }
  return await judge(ctx, cfg, gate, text)
}

export default {
  id: "leader-gate",
  async setup(ctx) {
    const cfg = readConfig()
    if (!cfg.enabled) return
    const childGates = new Map()
    const steers = new Map()
    const lastSeen = new Map()

    const before = async (event) => {
      if (event.tool !== "subagent") return
      if (event.agent !== "leader") return
      const input = event.input
      const target = input?.agent
      if (!ALL_AGENTS.has(target)) return
      const targetSessionID = typeof input?.sessionID === "string" ? input.sessionID : null
      const enforceAll = cfg.enforceOneSessionAll || (cfg.enforceOneSession && GATED_AGENTS.has(target))
      if (enforceAll) {
        const active = await findActiveChild(ctx, event.sessionID, target)
        if (active && active.id !== targetSessionID) {
          throw new Error(
            `LEADER_GATE: ${target} đang có session ${active.id}; chỉ được STEER vào chính session đó bằng sessionID=${active.id}, hoặc chờ dừng trước khi mở session mới.`,
          )
        }
      }
      if (!GATED_AGENTS.has(target)) {
        if (targetSessionID) log(cfg, "steer.open", { parent: event.sessionID, child: targetSessionID, agent: target })
        return
      }
      const prompt = String(input?.prompt ?? "")
      const gate = parseGate(prompt)
      const steer = parseSteer(prompt)
      if (targetSessionID) {
        const existing = childGates.get(targetSessionID) || {}
        const merged = { ...existing, ...(gate || steer || {}), parentID: event.sessionID }
        if (!merged.agent) merged.agent = target
        if (!merged.decision_id || !merged.scope || !Array.isArray(merged.r) || !merged.r.length) {
          throw new Error(
            "LEADER_GATE: follow-up cho review/reviewplan phải có block STEER hoặc GATE (decision_id/scope/R), hoặc session đã có gate đang mở.",
          )
        }
        if (merged.agent !== target) {
          throw new Error(`LEADER_GATE: gate.agent=${merged.agent} nhưng STEER vào ${target}.`)
        }
        if (target === "reviewplan" && !merged.phase) {
          throw new Error("LEADER_GATE: STEER cho reviewplan phải có phase (PLAN|GATE|AUDIT|PREP).")
        }
        if (target === "reviewplan" && ["PLAN", "GATE", "AUDIT"].includes(merged.phase)) {
          const h = normHash(merged.artifact_hash)
          if (!/^[0-9a-f]{64}$/i.test(h)) {
            throw new Error(
              "LEADER_GATE: artifact_hash phải là 64 hex; không gửi hash cắt. Tính lại bằng scripts/plan-hash.py hoặc heredoc.",
            )
          }
        }
        childGates.set(targetSessionID, merged)
        log(cfg, "steer.open", {
          parent: event.sessionID,
          child: targetSessionID,
          agent: target,
          decision_id: merged.decision_id,
        })
        return
      }
      if (!gate) {
        throw new Error(
          "LEADER_GATE: thiếu block GATE trong prompt giao review/reviewplan. Thêm GATE: decision_id/phase/agent/scope/R/expected.",
        )
      }
      if (gate.agent !== target) {
        throw new Error(`LEADER_GATE: GATE.agent=${gate.agent} nhưng giao ${target}.`)
      }
      if (gate.agent === "reviewplan" && ["PLAN", "GATE", "AUDIT"].includes(gate.phase)) {
        const h = normHash(gate.artifact_hash)
        if (!/^[0-9a-f]{64}$/i.test(h)) {
          throw new Error(
            "LEADER_GATE: artifact_hash phải là 64 hex; không gửi hash cắt. Tính lại bằng scripts/plan-hash.py hoặc heredoc.",
          )
        }
      }
      input.prompt = prompt + "\n\n" + renderContract(gate)
      log(cfg, "gate.open", { parent: event.sessionID, agent: target, decision_id: gate.decision_id })
    }

    const after = async (event) => {
      if (event.tool !== "subagent") return
      if (event.agent !== "leader") return
      const input = event.input
      const target = input?.agent
      if (!GATED_AGENTS.has(target)) return
      const prompt = String(input?.prompt ?? "")
      const gate = parseGate(prompt) || parseSteer(prompt)
      if (!gate) return
      if (event.status !== "completed") {
        log(cfg, "gate.child_error", { parent: event.sessionID, agent: target, error: event.error?.message })
        return
      }
      const fromResult = findSessionID(event.result)
      const childID =
        input?.sessionID ||
        (fromResult && fromResult !== event.sessionID ? fromResult : null) ||
        (await findChild(ctx, event.sessionID, target))
      if (!childID) {
        log(cfg, "gate.no_child", { parent: event.sessionID, agent: target, decision_id: gate.decision_id })
        return
      }
      const existing = childGates.get(childID) || {}
      const merged = { ...existing, ...gate, parentID: event.sessionID }
      if (!merged.agent) merged.agent = target
      for (const [id, g] of childGates) {
        if (id !== childID && g.agent === target) childGates.delete(id)
      }
      childGates.set(childID, merged)
      log(cfg, "gate.registered", { parent: event.sessionID, child: childID, agent: target, decision_id: merged.decision_id })
    }

    const onIdle = async (event) => {
      const gate = childGates.get(event.sessionID)
      if (!gate) return
      const active = await findActiveChild(ctx, gate.parentID, gate.agent)
      if (active && active.id === event.sessionID) return
      let messages
      try {
        messages = await ctx.session.context({ sessionID: event.sessionID })
      } catch {
        return
      }
      const text = lastAssistantText(messages)
      if (!text) return
      const hash = hashText(text)
      if (lastSeen.get(event.sessionID) === hash) return
      lastSeen.set(event.sessionID, hash)
      const verdict = await evaluate(ctx, cfg, gate, text)
      if (verdict.ok) {
        if (verdict.prep) {
          log(cfg, "gate.prep", {
            parent: gate.parentID,
            child: event.sessionID,
            agent: gate.agent,
            decision_id: gate.decision_id,
            blocked: Boolean(verdict.blocked),
          })
          if (verdict.blocked) {
            await ctx.session.synthetic({
              sessionID: gate.parentID,
              text:
                `GATE_PREP_BLOCKED (child) — ${gate.agent}/${gate.decision_id}; đọc prep.md và quyết định.` +
                `\nNếu chỉ cần sửa cục bộ, STEER vào chính session ${event.sessionID}; nếu đổi hướng thì mở session mới.`,
            })
            return
          }
          childGates.delete(event.sessionID)
          return
        }
        if (verdict.blocked) {
          await ctx.session.synthetic({
            sessionID: gate.parentID,
            text:
              `GATE_BLOCKED (child) — ${gate.agent}/${gate.decision_id}; đọc báo cáo con và quyết định.` +
              `\nCó thể STEER vào chính session ${event.sessionID} bằng subagent sessionID + block STEER, hoặc mở session mới nếu đổi scope/phase.`,
          })
          return
        }
        childGates.delete(event.sessionID)
        log(cfg, "gate.pass", { parent: gate.parentID, child: event.sessionID, agent: gate.agent, decision_id: gate.decision_id })
        return
      }
      const steerKey = gate.decision_id
      const n = (steers.get(steerKey) ?? 0) + 1
      steers.set(steerKey, n)
      if (n > cfg.maxSteers) {
        childGates.delete(event.sessionID)
        const blocked =
          `GATE_BLOCKED ${gate.agent}/${gate.decision_id} — hết lượt STEER.\n` +
          verdict.reasons.map((r) => `- ${r}`).join("\n")
        await ctx.session.synthetic({ sessionID: gate.parentID, text: blocked })
        log(cfg, "gate.blocked", {
          parent: gate.parentID,
          child: event.sessionID,
          agent: gate.agent,
          decision_id: gate.decision_id,
          reasons: verdict.reasons,
        })
        return
      }
      const steerPrompt = renderSteer(gate, verdict)
      const summary = [
        `GATE_STEER ${gate.agent}/${gate.decision_id} — lần ${n}/${cfg.maxSteers}`,
        `Gửi nguyên khối dưới đây vào chính session con ${event.sessionID} bằng subagent với sessionID (không mở session mới):`,
        "```text",
        steerPrompt,
        "```",
        "Giữ nguyên decision_id/scope/R; không đổi gate để lách maxSteers.",
      ].join("\n")
      await ctx.session.synthetic({ sessionID: gate.parentID, text: summary })
      log(cfg, "gate.steer", {
        parent: gate.parentID,
        child: event.sessionID,
        agent: gate.agent,
        decision_id: gate.decision_id,
        reasons: verdict.reasons,
      })
    }

    const guardEdit = async (event) => {
      if (!GATED_AGENTS.has(event.agent)) return
      if (event.tool !== "edit" && event.tool !== "write") return
      const p = String(event.input?.path ?? event.input?.filePath ?? event.input?.file ?? "")
      if (!p) return
      const abs = path.isAbsolute(p) ? p : path.resolve(ctx.location.directory, p)
      const plans = path.join(ctx.location.directory, ".opencode/plans")
      if (!abs.startsWith(plans + path.sep) && !abs.startsWith("/tmp/opencode" + path.sep)) {
        throw new Error("LEADER_GATE: review/reviewplan chỉ được ghi trong .opencode/plans/ hoặc /tmp/opencode/.")
      }
    }

    const inject = async (event) => {
      if (!GATED_AGENTS.has(event.agent)) return
      const gate = childGates.get(event.sessionID)
      if (!gate) return
      event.system.push({ type: "text", text: renderContract(gate) })
    }

    await ctx.tool.hook("execute.before", before)
    await ctx.tool.hook("execute.before", guardEdit)
    await ctx.tool.hook("execute.after", after)
    await ctx.session.hook("context", inject)
    await ctx.session.hook("experimental.idle", onIdle)
    log(cfg, "plugin.loaded", { directory: ctx.location.directory })
  },
}
