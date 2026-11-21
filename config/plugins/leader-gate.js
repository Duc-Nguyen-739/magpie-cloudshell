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
  enforceGate: true,
  logFile: path.join(HOME, ".local/share/opencode/leader-gate.log"),
}
const GATED_AGENTS = new Set(["review", "reviewplan"])

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
    raw: m[0].trim(),
  }
}

const VERDICT_ALIASES = {
  "ĐẠT": "PASS",
  "ĐÃ SỬA": "PASS",
  "KHÔNG ĐẠT": "BLOCKED",
  "CẦN ĐIỀU TRA": "BLOCKED",
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
  return [
    "---",
    "## GATE CONTRACT (plugin-injected)",
    "Bạn đang bị Leader gác. Không đổi scope, R, expected.",
    "Cuối báo cáo, bắt buộc thêm:",
    "GATE_REPORT:",
    `decision_id: ${gate.decision_id}`,
    `scope: ${gate.scope}`,
    `R_covered: <R đã kiểm, vd ${gate.r.join(",")}>`,
    "verdict: PASS|BLOCKED",
    "Chỉ dùng PASS hoặc BLOCKED; STEER là hành động của Leader, không phải verdict của report.",
    "evidence: <file:line / lệnh / output>",
    "Nếu không thể theo đúng gate, ghi verdict: BLOCKED kèm lý do.",
    "---",
  ].join("\n")
}

export function renderSteer(gate, verdict) {
  return [
    "LEADER_GATE — STEER",
    `decision_id: ${gate.decision_id}`,
    `scope: ${gate.scope}`,
    `R: ${gate.r.join(",")}`,
    `expected: ${gate.expected}`,
    "",
    "Báo cáo trước đó lệch gate:",
    ...verdict.reasons.map((r) => `- ${r}`),
    "",
    "Sửa đúng các điểm sau, giữ nguyên phần còn lại, không mở rộng:",
    ...verdict.corrections.map((c) => `- ${c}`),
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
    return list.find((s) => s.agent === agent && s.time?.busy && (!s.time?.idle || s.time.busy > s.time.idle)) ?? null
  } catch {
    return null
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
      if (!GATED_AGENTS.has(target)) return
      const prompt = String(input?.prompt ?? "")
      const gate = parseGate(prompt)
      if (!gate) {
        throw new Error(
          "LEADER_GATE: thiếu block GATE trong prompt giao review/reviewplan. Thêm GATE: decision_id/phase/agent/scope/R/expected.",
        )
      }
      if (gate.agent !== target) {
        throw new Error(`LEADER_GATE: GATE.agent=${gate.agent} nhưng giao ${target}.`)
      }
      if (cfg.enforceOneSession) {
        const active = await findActiveChild(ctx, event.sessionID, target)
        if (active && input?.sessionID !== active.id) {
          throw new Error(
            `LEADER_GATE: ${target} đang có session ${active.id}; chờ session đó dừng trước khi mở session mới.`,
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
      const gate = parseGate(String(input?.prompt ?? ""))
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
      childGates.set(childID, { ...gate, parentID: event.sessionID })
      log(cfg, "gate.registered", { parent: event.sessionID, child: childID, agent: target, decision_id: gate.decision_id })
    }

    const onIdle = async (event) => {
      const gate = childGates.get(event.sessionID)
      if (!gate) return
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
        childGates.delete(event.sessionID)
        if (verdict.blocked) {
          await ctx.session.synthetic({
            sessionID: gate.parentID,
            text: `GATE_BLOCKED (child) — ${gate.agent}/${gate.decision_id}; đọc báo cáo con và quyết định.`,
          })
        }
        log(cfg, "gate.pass", { parent: gate.parentID, child: event.sessionID, agent: gate.agent, decision_id: gate.decision_id })
        return
      }
      const n = (steers.get(event.sessionID) ?? 0) + 1
      steers.set(event.sessionID, n)
      const summary =
        `GATE_STEER ${gate.agent}/${gate.decision_id} — lần ${n}/${cfg.maxSteers}\n` +
        verdict.reasons.map((r) => `- ${r}`).join("\n")
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
      try {
        await ctx.session.prompt({
          sessionID: event.sessionID,
          text: renderSteer(gate, verdict),
          delivery: "steer",
          resume: true,
        })
      } catch (e) {
        log(cfg, "gate.steer_error", { child: event.sessionID, error: e?.message })
      }
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
