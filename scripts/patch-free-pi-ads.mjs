#!/usr/bin/env node
// patch-free-pi-ads.mjs — dạy plugin magpie-free-pi báo banner impression và
// đếm số impression để UI hiện cửa sổ "广告展示".
//
// Vì sao: freepi.ai trả 403 {"code":"ads_required"} cho completion khi tài khoản
// chưa báo ad impression. magpie-freepi-auth đã làm việc này (GET /ads/next →
// POST /ads/impression), còn magpie-free-pi thì không, nên tài khoản free-pi bị
// tạm dừng dù còn credits. Script này chèn đúng luồng đó vào bản đã cài.
//
// Idempotent: chạy lại nhiều lần không hỏng gì. Chạy sau mỗi lần cài/cập nhật
// plugin (plugins.sh gọi nó ở cuối).
//
//   node scripts/patch-free-pi-ads.mjs           # vá bản đang cài
//   node scripts/patch-free-pi-ads.mjs --check   # chỉ kiểm tra, exit 1 nếu chưa vá
//   node scripts/patch-free-pi-ads.mjs --revert  # trả file về backup gần nhất
import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const PKG = "magpie-free-pi";
const dir = process.env.MAGPIE_PLUGIN_DIR || join(homedir(), ".config", "magpie", "plugins", "node_modules", PKG);
const corePath = join(dir, "free-pi-core.mjs");
const indexPath = join(dir, "index.mjs");
const MARK = "[magpie-ad-gate]";
const COUNT_MARK = "[magpie-ad-count]";
const stamp = new Date().toISOString().replace(/[:.]/g, "-");

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

function oldestBackup(path) {
  const base = path.slice(dirname(path).length + 1);
  let names = [];
  try {
    names = readdirSync(dirname(path))
      .filter((n) => n.startsWith(`${base}.bak-`))
      .sort();
  } catch {
    return null;
  }
  return names.length ? join(dirname(path), names[0]) : null;
}

if (!existsSync(corePath)) fail(`không thấy ${corePath} — cài trước: magpie plugin add ${PKG}`);

const core0 = read(corePath);
const index0 = read(indexPath);
if (core0 == null || index0 == null) fail(`thiếu file trong ${dir}`);

const corePatched = core0.includes(MARK);
const indexPatched = index0.includes(MARK);
const countPatched = index0.includes(COUNT_MARK);
const countConstBroken = index0.includes("const adCount = 0; // [magpie-ad-count]");

if (checkOnly) {
  if (corePatched && indexPatched && countPatched && !countConstBroken) {
    console.log(`  ✓ ${PKG} đã vá ad gate + ad count`);
    process.exit(0);
  }
  console.error(
    `  ! ${PKG} chưa vá đủ (core: ${corePatched ? "có" : "thiếu"}, index: ${indexPatched ? "có" : "thiếu"}, count: ${countPatched ? (countConstBroken ? "const (hỏng)" : "có") : "thiếu"})`,
  );
  process.exit(1);
}

if (revert) {
  if (!corePatched && !indexPatched && !countPatched) {
    console.log("  · chưa vá, không có gì để trả lại");
    process.exit(0);
  }
  for (const path of [corePath, indexPath]) {
    const src = read(path);
    if (src == null || (!src.includes(MARK) && !src.includes(COUNT_MARK))) continue;
    const bak = oldestBackup(path);
    if (!bak) fail(`không thấy backup cho ${path} — cài lại plugin là cách sạch nhất`);
    copyFileSync(bak, path);
    console.log(`  ✓ trả ${path.slice(dir.length + 1)} về bản gốc ${bak.slice(dir.length + 1)}`);
  }
  try {
    execFileSync(process.execPath, ["--check", corePath], { stdio: "pipe" });
    execFileSync(process.execPath, ["--check", indexPath], { stdio: "pipe" });
  } catch (err) {
    fail(`cú pháp sau khi trả lại không hợp lệ: ${err.stderr?.toString().slice(0, 400) ?? err.message}`);
  }
  process.exit(0);
}

if (corePatched && indexPatched && countPatched && !countConstBroken) {
  console.log(`  ✓ ${PKG} đã vá ad gate + ad count từ trước`);
  process.exit(0);
}

function insertBefore(src, anchor, block, label) {
  const i = src.indexOf(anchor);
  if (i < 0) fail(`không tìm thấy đoạn để vá: ${label} (plugin đã đổi cấu trúc?)`);
  if (src.indexOf(anchor, i + 1) >= 0) fail(`đoạn cần vá xuất hiện nhiều lần: ${label}`);
  return src.slice(0, i) + block + src.slice(i);
}

function insertAfter(src, anchor, block, label) {
  const i = src.indexOf(anchor);
  if (i < 0) fail(`không tìm thấy đoạn để vá: ${label} (plugin đã đổi cấu trúc?)`);
  if (src.indexOf(anchor, i + 1) >= 0) fail(`đoạn cần vá xuất hiện nhiều lần: ${label}`);
  const end = i + anchor.length;
  return src.slice(0, end) + block + src.slice(end);
}

function replaceOnce(src, needle, replacement, label) {
  const i = src.indexOf(needle);
  if (i < 0) fail(`không tìm thấy đoạn để vá: ${label} (plugin đã đổi cấu trúc?)`);
  if (src.indexOf(needle, i + 1) >= 0) fail(`đoạn cần vá xuất hiện nhiều lần: ${label}`);
  return src.slice(0, i) + replacement + src.slice(i + needle.length);
}

const adHelper = [
  '// [magpie-ad-gate] Ad gate: free-pi answers 403 {"code":"ads_required"} on',
  "// completions until the account reports a banner impression. Mirrors the CLI",
  "// (fetch an ad, report the impression, never click) and magpie-freepi-auth.",
  "// Never throws; returns 1 when an impression was reported, else 0.",
  "export async function reportImpression(jwt, { sessionId, fetchImpl = fetch } = {}) {",
  "  try {",
  "    const headers = upstreamHeaders({",
  "      jwt,",
  "      sessionId,",
  '      extra: { "user-agent": `free-pi-cli/${FREEPI_CLIENT_VERSION}` },',
  "    });",
  '    const next = await fetchImpl(new URL("/ads/next?slot=banner", FREEPI_BASE_URL), { headers });',
  "    if (next.status !== 200) return 0;",
  "    const ad = await next.json().catch(() => null);",
  "    if (!ad?.ad_id) return 0;",
  '    const imp = await fetchImpl(new URL("/ads/impression", FREEPI_BASE_URL), {',
  '      method: "POST",',
  '      headers: { "content-type": "application/json", ...headers },',
  "      body: JSON.stringify({ ad_id: ad.ad_id, click_token: ad.click_token, imp_fired: true }),",
  "    });",
  "    if (!imp.ok) return 0;",
  "    if (ad.imp_url) await fetchImpl(ad.imp_url, { headers }).catch(() => {});",
  "    return 1;",
  "  } catch {",
  "    return 0;",
  "  }",
  "}",
  "",
].join("\n");

const adImport = '\nimport { reportImpression } from "./free-pi-core.mjs"; // [magpie-ad-gate]';

const adCall = [
  "            // [magpie-ad-gate] Report a banner impression before the chat request;",
  "            // fire-and-forget so an ads hiccup never delays or breaks the request.",
  "            void reportImpression(jwt, { sessionId, fetchImpl: fetch }).catch(() => {});",
  "",
].join("\n");

const adCountDecl = "\nlet adCount = 0; // [magpie-ad-count]";

const adCountCall = [
  "            reportImpression(jwt, { sessionId, fetchImpl: fetch })",
  "              .then((n) => { adCount += n; })",
  "              .catch(() => {});",
].join("\n");

const countWindowAnchor = [
  "                span: 24 * 3600,",
  "              },",
  "            ],",
].join("\n");

const countWindowBlock = [
  "                span: 24 * 3600,",
  "              },",
  "              {",
  '                name: "广告展示",',
  "                display: `本次运行已上报 ${adCount} 条`,",
  "                aside: true,",
  "              },",
  "            ],",
].join("\n");

let core = core0;
let index = index0;

if (!corePatched) {
  const anchor = core.includes("/** Headers every upstream free-pi request must carry. */")
    ? "/** Headers every upstream free-pi request must carry. */"
    : "export function upstreamHeaders";
  core = insertBefore(core0, anchor, adHelper, "free-pi-core.mjs: upstreamHeaders");
}

if (!indexPatched) {
  index = insertAfter(index0, '} from "./free-pi-core.mjs";', adImport, "index.mjs: import free-pi-core");
  index = insertBefore(
    index,
    "            return fetch(input, { ...init, headers });",
    adCall,
    "index.mjs: loader.fetch return",
  );
}

if (countConstBroken) {
  index = replaceOnce(
    index,
    "const adCount = 0; // [magpie-ad-count]",
    "let adCount = 0; // [magpie-ad-count]",
    "index.mjs: adCount const→let",
  );
}

if (!countPatched) {
  index = insertAfter(
    index,
    "const JWT_LIFETIME_MS = 90 * 24 * 60 * 60 * 1000;",
    adCountDecl,
    "index.mjs: JWT_LIFETIME_MS",
  );
  index = replaceOnce(
    index,
    "            void reportImpression(jwt, { sessionId, fetchImpl: fetch }).catch(() => {});",
    adCountCall,
    "index.mjs: ad call",
  );
  index = replaceOnce(index, countWindowAnchor, countWindowBlock, "index.mjs: usage windows");
}

// --- backup + ghi + kiểm tra cú pháp ---------------------------------------
const backups = [];
function backup(path) {
  const b = `${path}.bak-${stamp}`;
  copyFileSync(path, b);
  backups.push([path, b]);
  return b;
}

try {
  if (!corePatched) backup(corePath);
  if (!indexPatched || !countPatched || countConstBroken) backup(indexPath);
  if (!corePatched) writeFileSync(corePath, core);
  if (!indexPatched || !countPatched || countConstBroken) writeFileSync(indexPath, index);
  execFileSync(process.execPath, ["--check", corePath], { stdio: "pipe" });
  execFileSync(process.execPath, ["--check", indexPath], { stdio: "pipe" });
} catch (err) {
  for (const [path, b] of backups) {
    try {
      copyFileSync(b, path);
    } catch {
      // best effort
    }
  }
  fail(`cú pháp sau khi vá không hợp lệ, đã trả backup: ${err.stderr?.toString().slice(0, 400) ?? err.message}`);
}

console.log(`  ✓ ${PKG} đã vá ad gate + ad count: mỗi request chat báo impression, UI hiện "广告展示"`);
console.log("    nạp lại: magpie-headless-stop rồi magpie-headless-start (chạy riêng, đừng nối bằng &&)");
