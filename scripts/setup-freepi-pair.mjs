#!/usr/bin/env node
// setup-freepi-pair.mjs — giữ hai provider freepi.ai tách rời nhau, mỗi provider
// đúng một tài khoản.
//
// Hai provider dùng chung domain api.freepi.ai nhưng khác nhau hoàn toàn ở phần
// đăng nhập:
//
//   freepi   (plugin magpie-freepi-auth)  JWT nằm trong auth store của magpie
//   free-pi  (plugin magpie-free-pi)      pool trong ~/.free-pi/agent/accounts.json
//
// Vấn đề: pool của free-pi chỉ dedupe theo *chuỗi JWT*. Đăng nhập cùng một tài
// khoản GitHub hai lần (mỗi lần một JWT mới) sinh hai entry cùng user_id — server
// vẫn chỉ cấp một budget 15.000 credits/ngày, còn bộ đếm slot/rotation tưởng có
// hai tài khoản. Script gom lại: mỗi user_id giữ entry mới nhất.
//
// Idempotent, không cần mạng khi không có gì để dọn. Chạy sau khi đăng nhập:
//
//   node scripts/setup-freepi-pair.mjs           # dọn + in bảng tách riêng
//   node scripts/setup-freepi-pair.mjs --check   # chỉ kiểm tra, exit 1 nếu còn trùng
import { copyFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const BASE = "https://api.freepi.ai";
const dir = process.env.FREEPI_AGENT_DIR || join(homedir(), ".free-pi", "agent");
const accountsPath = join(dir, "accounts.json");
const checkOnly = new Set(process.argv.slice(2)).has("--check");

const say = (s) => console.log(`  ${s}`);
const warn = (s) => console.error(`  ! ${s}`);
const fail = (s) => {
  console.error(`  ! ${s}`);
  process.exit(1);
};

function readJson(p) {
  try {
    return JSON.parse(readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

// Một entry = một lần đăng nhập. /me (chỉ cần Authorization, không qua cổng
// version) trả user_id — khoá thật của budget.
async function whoami(jwt) {
  try {
    const res = await fetch(`${BASE}/me`, {
      headers: { authorization: `Bearer ${jwt}` },
      signal: AbortSignal.timeout(8000),
    });
    if (res.status !== 200) return { error: `HTTP ${res.status}` };
    const body = await res.json();
    return { userId: body?.user_id ?? body?.handle ?? null, handle: body?.handle ?? null };
  } catch (e) {
    return { error: e.message };
  }
}

const accounts = existsSync(accountsPath) ? readJson(accountsPath) : null;
if (accounts === null) {
  if (existsSync(accountsPath)) fail(`${accountsPath} không đọc được — kiểm tra quyền/JSON`);
  say("free-pi chưa đăng nhập (không có accounts.json) — bỏ qua");
  process.exit(0);
}
if (!Array.isArray(accounts) || accounts.length === 0) {
  say("pool free-pi rỗng — bỏ qua");
  process.exit(0);
}

const groups = new Map(); // userId -> entry mới nhất
const unknown = [];
for (const entry of accounts) {
  const who = await whoami(entry.jwt);
  if (!who.userId) {
    warn(`${entry.id}: không đọc được /me (${who.error}) — giữ nguyên`);
    unknown.push(entry);
    continue;
  }
  const prev = groups.get(who.userId);
  if (!prev || String(entry.addedAt) > String(prev.entry.addedAt)) {
    groups.set(who.userId, { entry, handle: who.handle });
  }
}

const kept = [...groups.values()].map((g) => g.entry);
const removed = accounts.filter((e) => !kept.includes(e) && !unknown.includes(e));

if (removed.length === 0) {
  say(`pool free-pi sạch: ${accounts.length} tài khoản, không trùng`);
} else if (checkOnly) {
  for (const e of removed) warn(`trùng: ${e.id} (${e.label}, ${e.addedAt})`);
  fail(`${removed.length} entry trùng user_id — chạy: node scripts/setup-freepi-pair.mjs`);
} else {
  const stamp = new Date().toISOString().replace(/[-:T.]/g, "").slice(0, 14);
  const backup = `${accountsPath}.bak-${stamp}`;
  copyFileSync(accountsPath, backup);
  writeFileSync(accountsPath, `${JSON.stringify([...kept, ...unknown], null, 2)}\n`, { mode: 0o600 });
  say(`bỏ ${removed.length} entry trùng (cùng user_id): ${removed.map((e) => e.id).join(", ")}`);
  say(`giữ ${kept.length}: ${kept.map((e) => `${e.label} @ ${e.addedAt}`).join(", ")}`);
  say(`bản cũ: ${backup}`);
}

// Bảng tách riêng: cái gì dùng chung, cái gì riêng.
const rows = [
  ["freepi", "magpie-freepi-auth", "auth store của magpie", "magpie-freepi (hằng số)"],
  ["free-pi", "magpie-free-pi", "~/.free-pi/agent/accounts.json", "~/.free-pi/agent/session-id"],
];
say("");
say("provider   plugin                 đăng nhập giữ ở                    x-session-id");
for (const [id, plugin, store, session] of rows) say(`${id.padEnd(10)} ${plugin.padEnd(22)} ${store.padEnd(34)} ${session}`);
say("");
say("Chung: domain api.freepi.ai. Riêng: JWT, session id, budget 15.000 credits/ngày, slot đồng thời.");
say("Kiểm tra: magpie provider test freepi && magpie provider test free-pi");
