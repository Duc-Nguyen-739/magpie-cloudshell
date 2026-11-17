#!/usr/bin/env node
// patch-free-pi.mjs — bỏ hằng số phiên bản client bị ghim trong plugin
// magpie-free-pi và lấy mức tối thiểu từ chính server (GET /client-version).
//
// Vì sao: plugin gửi `x-client-version` và freepi.ai chặn mọi request chat của
// client cũ bằng HTTP 426 `upgrade_required` — trước cả khi định tuyến model,
// nên *tất cả* model cùng chết ("9 of 9 models didn't answer"). Mức tối thiểu
// đổi mà không báo trước (0.6.2 ngày 2026-11-09 → 0.6.21 ngày 2026-11-17), còn
// plugin 0.1.5 trên npm vẫn ghim 0.6.16, nên cài mới hay `magpie plugin update`
// đều hỏng lại. Script này sửa bản đã cài: giá trị gửi đi lấy từ /client-version
// (endpoint công khai, không cần auth, plugin vốn đã gọi để lấy catalog model).
//
// Idempotent: chạy lại nhiều lần không hỏng gì. Chạy sau mỗi lần cài/cập nhật
// plugin (plugins.sh gọi nó ở cuối).
//
//   node scripts/patch-free-pi.mjs           # vá bản đang cài
//   node scripts/patch-free-pi.mjs --check   # chỉ kiểm tra, exit 1 nếu chưa vá
//   node scripts/patch-free-pi.mjs --revert  # trả về nguyên bản npm (0.1.5)
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const PKG = "magpie-free-pi";
const dir = process.env.MAGPIE_PLUGIN_DIR || join(homedir(), ".config", "magpie", "plugins", "node_modules", PKG);
const corePath = join(dir, "free-pi-core.mjs");
const indexPath = join(dir, "index.mjs");
const MARK = "refreshClientVersion";

const argv = new Set(process.argv.slice(2));
const checkOnly = argv.has("--check");
const revert = argv.has("--revert");

function fail(msg) {
  console.error(`  ! ${msg}`);
  process.exit(1);
}

function read(p) {
  try {
    return readFileSync(p, "utf8");
  } catch {
    return null;
  }
}

function replaceOnce(src, pattern, replacement, label) {
  const hits = src.match(new RegExp(pattern.source, "g"))?.length ?? 0;
  if (hits === 0) fail(`không tìm thấy đoạn để vá: ${label} (plugin đã đổi cấu trúc?)`);
  if (hits > 1) fail(`đoạn cần vá xuất hiện ${hits} lần: ${label}`);
  return src.replace(pattern, replacement);
}

if (!existsSync(corePath)) fail(`không thấy ${corePath} — cài trước: magpie plugin add ${PKG}`);

const core0 = read(corePath);
const index0 = read(indexPath);
if (core0 == null || index0 == null) fail(`thiếu file trong ${dir}`);

const patched = core0.includes(MARK);

if (checkOnly) {
  if (patched) {
    console.log(`  ✓ ${PKG} đã vá (client version lấy từ /client-version)`);
    process.exit(0);
  }
  console.error(`  ! ${PKG} chưa vá — request chat sẽ bị 426 khi server nâng mức tối thiểu`);
  process.exit(1);
}

if (revert) {
  if (!patched) {
    console.log("  · chưa vá, không có gì để trả lại");
    process.exit(0);
  }
  fail("chưa hỗ trợ --revert: gỡ rồi cài lại plugin là cách sạch nhất (magpie plugin rm free-pi && magpie plugin add magpie-free-pi)");
}

if (patched) {
  console.log(`  ✓ ${PKG} đã vá từ trước`);
  process.exit(0);
}

// --- free-pi-core.mjs -------------------------------------------------------
// 1. Hằng số ghim → biến sống, kèm bộ lấy phiên bản từ /client-version.
const versionBlock = `// Sent as x-client-version. The gate's floor moves without warning (0.6.2 on
// 2026-11-09, 0.6.21 on 2026-11-17) and a stale value is refused with HTTP 426
// upgrade_required for every model, before routing, so the number comes from
// the server's own GET /client-version instead of a pinned literal. This is the
// floor used until the first lookup lands.
export let FREEPI_CLIENT_VERSION = "0.6.22";
const CLIENT_VERSION_MAX_AGE_MS = 10 * 60 * 1000;
const SEMVER = /^\\d+\\.\\d+\\.\\d+$/;
let clientVersionAt = 0;

/** The version to send right now: the last one the server named. */
export function currentClientVersion() {
  return FREEPI_CLIENT_VERSION;
}

function noteClientVersion(body) {
  const versions = [body?.min, body?.latest].filter((v) => typeof v === "string" && SEMVER.test(v));
  if (!versions.length) return;
  const rank = (v) => v.split(".").map(Number);
  const newer = (a, b) => {
    const [x, y] = [rank(a), rank(b)];
    for (let i = 0; i < 3; i += 1) if (x[i] !== y[i]) return x[i] - y[i];
    return 0;
  };
  FREEPI_CLIENT_VERSION = versions.sort(newer).pop();
  clientVersionAt = Date.now();
}

/**
 * Refresh the client version from GET /client-version (unauthenticated, cached
 * for 10 minutes). Never throws: on failure the last known version stays.
 */
export async function refreshClientVersion(fetchImpl = fetch, { maxAgeMs = CLIENT_VERSION_MAX_AGE_MS } = {}) {
  if (clientVersionAt && Date.now() - clientVersionAt < maxAgeMs) return FREEPI_CLIENT_VERSION;
  try {
    const res = await fetchImpl(new URL("/client-version", FREEPI_BASE_URL), {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error(\`HTTP \${res.status}\`);
    noteClientVersion(await res.json());
  } catch {
    // keep the last known version
  }
  return FREEPI_CLIENT_VERSION;
}`;

let core = replaceOnce(
  core0,
  /\/\/ Sent as x-client-version\.[\s\S]*?export (?:const|let) FREEPI_CLIENT_VERSION = "[^"]*";/,
  versionBlock,
  "khối FREEPI_CLIENT_VERSION",
);

// 2. Dùng luôn phản hồi /client-version mà fetchCatalog đã tải (khỏi gọi thêm).
core = replaceOnce(
  core,
  /(\n    const body = await res\.json\(\);)(\n    const models = \(body\?\.models)/,
  "$1\n    noteClientVersion(body);$2",
  "fetchCatalog: noteClientVersion(body)",
);

// --- index.mjs --------------------------------------------------------------
// 3. Import thêm hai hàm mới.
let index = replaceOnce(
  index0,
  /(  FREEPI_CLIENT_VERSION,\n)/,
  "$1  currentClientVersion,\n  refreshClientVersion,\n",
  "import currentClientVersion/refreshClientVersion",
);

// 4. Mỗi request chat làm mới phiên bản (cached 10 phút, không chặn lâu).
index = replaceOnce(
  index,
  /(\n          fetch: )\(input, init = \{\}\) => \{/,
  "$1async (input, init = {}) => {\n            await refreshClientVersion().catch(() => {});",
  "loader.fetch: refreshClientVersion()",
);

// 5. Header trong hook chat.headers đọc giá trị hiện tại, không phải hằng số.
index = replaceOnce(
  index,
  /output\.headers\["x-client-version"\] = FREEPI_CLIENT_VERSION;/,
  'output.headers["x-client-version"] = currentClientVersion();',
  'chat.headers: x-client-version',
);

// --- ghi + kiểm tra cú pháp ------------------------------------------------
if (!checkOnly) {
  writeFileSync(corePath, core);
  writeFileSync(indexPath, index);
}

try {
  execFileSync(process.execPath, ["--check", corePath], { stdio: "pipe" });
  execFileSync(process.execPath, ["--check", indexPath], { stdio: "pipe" });
} catch (err) {
  fail(`cú pháp sau khi vá không hợp lệ: ${err.stderr?.toString().slice(0, 400) ?? err.message}`);
}

console.log(`  ✓ ${PKG} đã vá: client version lấy từ GET /client-version (fallback 0.6.22)`);
console.log("    khởi động lại gateway để nạp lại: kill $(pgrep -f 'magpie serve') — supervisor tự dựng lại");
