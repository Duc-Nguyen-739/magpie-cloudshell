#!/usr/bin/env node
// agnes-login.mjs — trang đăng nhập Agnes chạy trên chính máy này, mở bằng
// trình duyệt ở laptop/điện thoại.
//
// Vì sao cần: plugin Agnes đăng nhập bằng cách mở Chrome trên **máy chạy
// magpie** rồi đọc `localStorage.token` qua CDP. Máy headless (Cloud Shell,
// VPS) không có Chrome và cũng không có màn hình, nên đường đó không dùng được.
// Agnes cũng không có OAuth callback về localhost như Kiro/AutoClaw — token
// không bao giờ nằm trong URL. Vì vậy trang này nhận **API key** (`cpk-…` /
// `apk-…`) do bạn copy từ trang API keys, rồi tự chạy
// `magpie plugin login agnes "Agnes API key"` và kiểm tra key với upstream.
//
// Key chỉ đi từ trình duyệt của bạn tới tiến trình này qua HTTPS của Cloud
// Shell, rồi vào stdin của magpie. Không ghi ra log, không gửi lên đâu khác.
//
// Biến môi trường:
//   AGNES_PAGE_KEY    token bắt buộc trong URL (?k=…) — agnes-link.sh tự sinh
//   AGNES_PAGE_PORT   cổng (mặc định 3455)
//   AGNES_PAGE_BIND   địa chỉ bind (mặc định 0.0.0.0, để Cloud Shell chuyển tiếp)
//   AGNES_PAGE_TTL    phút tự tắt nếu không ai dùng (mặc định 60)
//   AGNES_STATE_DIR   thư mục trạng thái
//   MAGPIE_BIN        đường dẫn magpie (mặc định "magpie")
import { createServer } from "node:http"
import { spawn } from "node:child_process"
import { mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"

const PORT = Number(process.env.AGNES_PAGE_PORT || 3455)
const BIND = process.env.AGNES_PAGE_BIND || "0.0.0.0"
const TOKEN = process.env.AGNES_PAGE_KEY || ""
const TTL_MIN = Number(process.env.AGNES_PAGE_TTL || 60)
const STATE = process.env.AGNES_STATE_DIR || join(process.env.HOME || ".", ".local/state/magpie/agnes-signin")
const MAGPIE = process.env.MAGPIE_BIN || "magpie"
const API = "https://apihub.agnes-ai.com/v1"
const LOGIN_PAGE = "https://platform.agnes-ai.com/login?redirect=%2Fsettings%2FapiKeys"

const PROFILES = {
  plan: { index: "1", label: "Plan" },
  default: { index: "2", label: "Personal" },
  enterprise: { index: "3", label: "Enterprise" },
}

mkdirSync(STATE, { recursive: true, mode: 0o700 })

function writeState(value) {
  try {
    writeFileSync(join(STATE, "state.json"), JSON.stringify(value, null, 2), { mode: 0o600 })
  } catch {}
}

function send(res, code, body, type = "application/json; charset=utf-8") {
  res.writeHead(code, { "content-type": type, "cache-control": "no-store" })
  res.end(body)
}

function tokenOk(url) {
  if (!TOKEN) return true
  const given = url.searchParams.get("k") || ""
  if (given.length !== TOKEN.length) return false
  let diff = 0
  for (let i = 0; i < TOKEN.length; i++) diff |= given.charCodeAt(i) ^ TOKEN.charCodeAt(i)
  return diff === 0
}

function readBody(req, limit = 16 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0
    const chunks = []
    req.on("data", (chunk) => {
      size += chunk.length
      if (size > limit) {
        reject(new Error("body quá lớn"))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")))
    req.on("error", reject)
  })
}

// Chạy `magpie plugin login agnes "Agnes API key"` và trả lời qua stdin:
// loại key (1/2/3), console token (có thể rỗng), rồi API key.
function magpieLogin(profile, key, consoleToken) {
  return new Promise((resolve) => {
    const child = spawn(MAGPIE, ["plugin", "login", "agnes", "Agnes API key"], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env, NO_COLOR: "1" },
    })
    let out = ""
    const timer = setTimeout(() => {
      try { child.kill("SIGKILL") } catch {}
      resolve({ ok: false, error: "magpie không trả lời sau 90 giây" })
    }, 90_000)
    child.stdout.on("data", (chunk) => { out += chunk })
    child.stderr.on("data", (chunk) => { out += chunk })
    child.on("error", (error) => {
      clearTimeout(timer)
      resolve({ ok: false, error: `không chạy được magpie: ${error.message}` })
    })
    child.on("close", () => {
      clearTimeout(timer)
      if (/signed in to Agnes/i.test(out)) return resolve({ ok: true })
      const line = out
        .split("\n")
        .map((l) => l.replace(/\x1b\[[0-9;]*m/g, "").trim())
        .filter((l) => l && !/^>\s*$/.test(l) && !/^magpie:/.test(l) && !/plugin \[error\]/.test(l))
        .pop()
      resolve({ ok: false, error: line || "magpie không xác nhận đăng nhập" })
    })
    child.stdin.end(`${PROFILES[profile].index}\n${consoleToken || ""}\n${key}\n`)
  })
}

async function verifyKey(key) {
  try {
    const res = await fetch(`${API}/models`, {
      headers: { authorization: `Bearer ${key}`, accept: "application/json" },
      signal: AbortSignal.timeout(12_000),
    })
    if (res.status === 401 || res.status === 403) return { ok: false, status: res.status }
    if (!res.ok) return { ok: true, unverified: true }
    const body = await res.json().catch(() => null)
    const count = Array.isArray(body?.data) ? body.data.length : null
    return { ok: true, count }
  } catch {
    return { ok: true, unverified: true }
  }
}

function magpieLogout() {
  return new Promise((resolve) => {
    const child = spawn(MAGPIE, ["plugin", "logout", "agnes"], { stdio: "ignore" })
    const timer = setTimeout(() => { try { child.kill("SIGKILL") } catch {} ; resolve() }, 20_000)
    child.on("close", () => { clearTimeout(timer); resolve() })
    child.on("error", () => { clearTimeout(timer); resolve() })
  })
}

async function applyLogin(payload) {
  const profile = PROFILES[payload.keyProfile] ? payload.keyProfile : "plan"
  const key = String(payload.key || "").trim()
  const consoleToken = String(payload.consoleToken || "").trim()
  if (!key) return { ok: false, error: "chưa có API key" }
  if (/\s/.test(key)) return { ok: false, error: "API key có khoảng trắng — copy lại cho đúng" }
  if (key.length < 12) return { ok: false, error: "API key quá ngắn, kiểm tra lại" }

  const saved = await magpieLogin(profile, key, consoleToken)
  if (!saved.ok) {
    writeState({ ok: false, at: new Date().toISOString(), error: saved.error })
    return saved
  }

  const check = await verifyKey(key)
  if (!check.ok) {
    await magpieLogout()
    const error = `Agnes từ chối key (HTTP ${check.status}). Kiểm tra loại key và copy lại.`
    writeState({ ok: false, at: new Date().toISOString(), error })
    return { ok: false, error }
  }

  const result = {
    ok: true,
    at: new Date().toISOString(),
    profile,
    profileLabel: PROFILES[profile].label,
    models: check.count ?? null,
    unverified: Boolean(check.unverified),
  }
  writeState(result)
  return result
}

const page = (body) => `<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Đăng nhập Agnes · magpie</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 0;
    font: 16px/1.55 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    background: #0b0f14; color: #e7edf5;
  }
  main { max-width: 620px; margin: 0 auto; padding: 26px 18px 64px; }
  .brand { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; }
  .mark {
    width: 34px; height: 34px; border-radius: 10px; flex: none;
    display: grid; place-items: center; font-weight: 700; font-size: 17px;
    background: linear-gradient(135deg, #4f7cff, #8a5cff); color: #fff;
  }
  .brand small { display: block; color: #8b98a9; font-size: 12.5px; letter-spacing: .02em; }
  .brand b { font-size: 16px; font-weight: 600; }
  h1 { font-size: 1.28rem; line-height: 1.3; margin: 0 0 8px; font-weight: 650; }
  p.lead { margin: 0 0 20px; color: #9aa8ba; }
  .card {
    background: #121821; border: 1px solid #22303f; border-radius: 14px;
    padding: 18px; margin: 0 0 16px;
  }
  .card h2 { font-size: .82rem; text-transform: uppercase; letter-spacing: .08em;
    color: #7f8ea3; margin: 0 0 12px; font-weight: 600; }
  ol { margin: 0; padding-left: 1.25rem; color: #c3cedd; }
  ol li { margin: 0 0 9px; }
  ol li:last-child { margin-bottom: 0; }
  code, .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .88em; }
  code { background: #1b2430; border: 1px solid #27364a; border-radius: 5px; padding: 1px 5px; }
  a.open {
    display: flex; align-items: center; justify-content: center; gap: 8px;
    text-decoration: none; color: #fff; font-weight: 600;
    background: #2f6bff; border-radius: 10px; padding: 12px 16px; margin: 0 0 4px;
  }
  a.open:hover { background: #3c76ff; }
  a.open .sub { font-weight: 400; color: #d6e2ff; }
  .hint { color: #8b98a9; font-size: 13.5px; margin: 10px 0 0; }
  fieldset { border: 0; padding: 0; margin: 0 0 16px; }
  legend { font-size: .82rem; text-transform: uppercase; letter-spacing: .08em;
    color: #7f8ea3; margin-bottom: 9px; font-weight: 600; }
  .seg { display: flex; gap: 8px; flex-wrap: wrap; }
  .seg label {
    flex: 1 1 0; min-width: 96px; text-align: center; cursor: pointer;
    border: 1px solid #27364a; background: #141b25; border-radius: 9px;
    padding: 9px 8px; font-size: 14.5px; color: #c3cedd; user-select: none;
  }
  .seg input { position: absolute; opacity: 0; pointer-events: none; }
  .seg input:checked + span { color: #fff; }
  .seg label:has(input:checked) { border-color: #3c76ff; background: #17233b; box-shadow: inset 0 0 0 1px #3c76ff; }
  .field { display: block; margin: 0 0 16px; }
  .field > span { display: block; font-size: .82rem; text-transform: uppercase;
    letter-spacing: .08em; color: #7f8ea3; margin-bottom: 8px; font-weight: 600; }
  input[type=text], textarea {
    width: 100%; background: #0e141c; color: #e7edf5;
    border: 1px solid #27364a; border-radius: 9px; padding: 11px 12px;
    font: inherit; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 14.5px;
  }
  input[type=text]:focus, textarea:focus { outline: none; border-color: #3c76ff; }
  textarea { min-height: 74px; resize: vertical; }
  button.send {
    width: 100%; border: 0; border-radius: 10px; padding: 13px 16px;
    font: inherit; font-weight: 650; color: #fff; background: #1f9d55; cursor: pointer;
  }
  button.send:hover { background: #24b061; }
  button.send:disabled { opacity: .55; cursor: progress; }
  details { margin: 12px 0 0; color: #9aa8ba; font-size: 14px; }
  details summary { cursor: pointer; color: #8fa8ff; }
  details p { margin: 8px 0 0; }
  .status { margin: 14px 0 0; border-radius: 10px; padding: 12px 14px; font-size: 14.5px; display: none; }
  .status.show { display: block; }
  .status.ok { background: #10241a; border: 1px solid #1f6b42; color: #b8f0cd; }
  .status.err { background: #2a1518; border: 1px solid #7a2b35; color: #ffc9cf; }
  .status.wait { background: #121821; border: 1px solid #27364a; color: #c3cedd; }
  .done { display: none; }
  .done h2 { font-size: 1.05rem; color: #b8f0cd; margin: 0 0 8px; }
  footer { margin-top: 22px; color: #6f7d8f; font-size: 12.5px; line-height: 1.5; }
</style>
</head>
<body>
<main>
  <div class="brand">
    <div class="mark">A</div>
    <div><b>Agnes</b><small>đăng nhập cho magpie</small></div>
  </div>
  ${body}
  <footer>
    Trang này chỉ chạy trên máy magpie của bạn (Cloud Shell/VPS), không phải dịch vụ ngoài.
    Key không đi vào chat, không ghi log; nó chỉ được đưa cho
    <span class="mono">magpie</span> trên máy này.
  </footer>
</main>
</body>
</html>`

const formPage = page(`
  <h1>Đăng nhập Agnes</h1>
  <p class="lead">Agnes không có callback URL như Kiro hay AutoClaw, nên cách gọn nhất
  là lấy API key từ trang quản lý rồi dán vào đây.</p>

  <div class="card">
    <h2>Bước 1 · lấy key</h2>
    <ol>
      <li><a href="${LOGIN_PAGE}" target="_blank" rel="noopener">Mở trang đăng nhập Agnes</a>
        và đăng nhập bằng Google, GitHub hoặc email.</li>
      <li>Vào <b>Settings → API Keys</b>, tạo hoặc copy một key.</li>
      <li>Key gói <b>Token/Agent Plan</b> bắt đầu bằng <code>cpk-</code>;
        key cá nhân/doanh nghiệp bằng <code>apk-</code>.</li>
    </ol>
  </div>

  <div class="card">
    <h2>Bước 2 · dán vào đây</h2>
    <form id="f" autocomplete="off">
      <fieldset>
        <legend>Loại key</legend>
        <div class="seg">
          <label><input type="radio" name="p" value="plan" checked><span>Plan</span></label>
          <label><input type="radio" name="p" value="default"><span>Personal</span></label>
          <label><input type="radio" name="p" value="enterprise"><span>Enterprise</span></label>
        </div>
      </fieldset>
      <label class="field">
        <span>API key</span>
        <input type="text" id="key" name="key" placeholder="cpk-…" spellcheck="false"
               autocapitalize="off" autocorrect="off">
      </label>
      <label class="field">
        <span>Console token · không bắt buộc</span>
        <textarea id="ct" name="ct" spellcheck="false" autocapitalize="off" autocorrect="off"
          placeholder="để trống nếu chỉ cần gọi model; dán vào để hiện hạn mức gói"></textarea>
      </label>
      <details>
        <summary>Lấy console token ở đâu?</summary>
        <p>Đang đăng nhập ở <span class="mono">platform.agnes-ai.com</span>, mở DevTools
        (F12) → Console, chạy:</p>
        <p><code>copy(localStorage.getItem("token"))</code></p>
        <p>Token đã nằm trong clipboard. Nó chỉ dùng để đọc hạn mức, không phải key gọi model.</p>
      </details>
      <div class="status" id="s"></div>
      <p></p>
      <button class="send" id="send" type="submit">Gửi cho magpie</button>
    </form>
  </div>

  <div class="card done" id="done">
    <h2>✓ Đã đăng nhập Agnes</h2>
    <p id="doneText" style="margin:0;color:#c3cedd"></p>
    <p class="hint">Quay lại chat báo tôi biết; model sẽ hiện là
      <span class="mono">agnes/agnes-3.0-flash</span>,
      <span class="mono">agnes/agnes-2.5-pro</span>…</p>
  </div>

<script>
(function () {
  var form = document.getElementById("f")
  var status = document.getElementById("s")
  var send = document.getElementById("send")
  var done = document.getElementById("done")
  var doneText = document.getElementById("doneText")

  function show(kind, text) {
    status.className = "status show " + kind
    status.textContent = text
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault()
    var key = document.getElementById("key").value.trim()
    var ct = document.getElementById("ct").value.trim()
    var profile = document.querySelector('input[name="p"]:checked').value
    if (!key) { show("err", "Chưa có API key."); return }
    if (/^https?:\\/\\//i.test(key)) {
      show("err", "Đó là URL, không phải API key. Agnes không trả token qua URL — " +
        "mở Settings → API Keys rồi copy key cpk-… / apk-….")
      return
    }

    send.disabled = true
    show("wait", "Đang lưu và kiểm tra key với Agnes…")
    try {
      var res = await fetch("/api/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          k: new URLSearchParams(location.search).get("k") || "",
          keyProfile: profile,
          key: key,
          consoleToken: ct
        })
      })
      var data = await res.json()
      if (data.ok) {
        status.className = "status"
        form.style.display = "none"
        done.style.display = "block"
        var extra = data.models ? (" · " + data.models + " model") : ""
        var warn = data.unverified ? " (chưa kiểm tra được với upstream)" : ""
        doneText.textContent = "Key " + data.profileLabel + extra + warn + "."
      } else {
        show("err", data.error || "Không đăng nhập được.")
      }
    } catch (error) {
      show("err", "Không gửi được: " + error.message)
    } finally {
      send.disabled = false
    }
  })
})()
</script>`)

const denied = page(`
  <h1>Thiếu hoặc sai key</h1>
  <p class="lead">Mở lại link mà <span class="mono">agnes-link.sh</span> in ra
  (link có <span class="mono">?k=…</span>). Đừng dùng địa chỉ trần.</p>`)

const server = createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "127.0.0.1"}`)

  if (req.method === "GET" && url.pathname === "/healthz") {
    return send(res, 200, "ok", "text/plain; charset=utf-8")
  }

  if (req.method === "GET" && url.pathname === "/") {
    if (!tokenOk(url)) return send(res, 403, denied, "text/html; charset=utf-8")
    return send(res, 200, formPage, "text/html; charset=utf-8")
  }

  if (req.method === "POST" && url.pathname === "/api/login") {
    let payload
    try {
      payload = JSON.parse(await readBody(req))
    } catch (error) {
      return send(res, 400, JSON.stringify({ ok: false, error: "yêu cầu không hợp lệ" }))
    }
    if (!TOKEN || String(payload.k || "") !== TOKEN) {
      return send(res, 403, JSON.stringify({ ok: false, error: "sai key của trang" }))
    }
    const result = await applyLogin(payload)
    return send(res, result.ok ? 200 : 400, JSON.stringify(result))
  }

  send(res, 404, JSON.stringify({ ok: false, error: "không có trang này" }))
})

server.listen(PORT, BIND, () => {
  console.log(`agnes login page on http://${BIND}:${PORT}`)
})

setTimeout(() => {
  console.log("hết hạn, tự tắt")
  process.exit(0)
}, TTL_MIN * 60_000).unref()
