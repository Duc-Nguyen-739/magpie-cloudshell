# Prompt cho AI agent — nhân bản plugin FreePi trên máy khác

Bạn là AI agent đang làm việc trên một máy Linux (Cloud Shell/VPS/WSL) đã cài **magpie**
và đã cài **FreePi đầu tiên** (`magpie-freepi-auth`, provider `freepi`). Nhiệm vụ: tạo
một biến thể mới **FreePiN** (N là số tiếp theo) với repo private riêng, plugin magpie
riêng, icon riêng, kho dữ liệu riêng, để người dùng đăng nhập một tài khoản FreePi khác
và dùng như bình thường.

Đây là bản hướng dẫn đã được kiểm chứng qua FreePi2, FreePi3, FreePi4, FreePi5. Làm đúng
thứ tự, không tự nghĩ ra kiến trúc mới.

---

## 0. Biến và kiểm tra ban đầu

Chạy:

```sh
export PATH="$HOME/.local/bin:$PATH"
cd "$HOME"

magpie --version
magpie plugin list
magpie providers
magpie accounts
gh auth status
OWNER="$(gh api user -q .login)"
echo "GitHub owner: $OWNER"
```

Chọn:

```sh
N=6                                  # số mới, ví dụ FreePi6
BASE="$HOME/.local/src/FreePiLogin5" # bản template mới nhất nếu clone được
NEW="$HOME/.local/src/FreePiLogin$N"
REPO="$OWNER/FreePiLogin$N"
```

Quy tắc:

- `N` là số tiếp theo; kiểm tra `magpie plugin list` xem đã có `freepiN` chưa.
- Mỗi biến thể phải có **provider id riêng**, **session id riêng**, **thư mục riêng**.
- Không dùng chung token/thư mục với `freepi` hay bất kỳ FreePi2/3/4/5 nào.
- Không sửa tên dự án upstream `FreePi2API`.
- Không đưa token, `plugin-auth.json`, `~/.freepiN` hay secret vào git.

Kiểm tra repo chưa tồn tại:

```sh
gh repo view "$REPO" 2>&1 | head -2
```

Nếu đã tồn tại, dừng lại và hỏi người dùng, không ghi đè.

---

## 1. Lấy bản base

### Cách A — clone template chuẩn (khuyến nghị)

Nếu tài khoản GitHub trên máy đọc được repo private `Duc-Nguyen-739/FreePiLogin5`:

```sh
rm -rf "$BASE"
gh repo clone Duc-Nguyen-739/FreePiLogin5 "$BASE"
```

Sau đó:

```sh
rm -rf "$NEW"
cp -a "$BASE" "$NEW"
rm -rf "$NEW/.git"
cd "$NEW"
```

### Cách B — chỉ có FreePi đầu tiên, không đọc được repo private

Dùng plugin FreePi đang cài làm base:

```sh
PKG="$HOME/.config/magpie/plugins/node_modules/magpie-freepi-auth"
test -f "$PKG/index.mjs" || { echo "Không thấy $PKG"; exit 1; }

rm -rf "$NEW"
mkdir -p "$NEW"
cp -a "$PKG/index.mjs" "$PKG/lib" "$PKG/package.json" "$PKG/README.md" "$PKG/LICENSE" "$NEW/" 2>/dev/null || true
```

Nếu package không có `LICENSE`/`README.md`, tự tạo theo mục 4 và 5.

Lấy mã nguồn upstream công khai:

```sh
git clone --depth 1 https://github.com/ErfanBagheri404/FreePi2API.git "$NEW/upstream/FreePi2API"
rm -rf "$NEW/upstream/FreePi2API/.git"
```

Sau đó **bắt buộc** thêm `lib/store.mjs` và sửa `index.mjs`/`lib/upstream.mjs` theo
**Phụ lục A** ở cuối prompt, vì bản `magpie-freepi-auth` gốc dùng session id cố định
`magpie-freepi`, không tách kho như yêu cầu.

---

## 2. Đổi tên toàn bộ

Trong `$NEW`, chạy Python (thay `5` bằng số base thực tế):

```sh
cd "$NEW"
python3 - <<'PY'
from pathlib import Path
files = ['README.md','index.mjs','package.json','LICENSE','lib/store.mjs','lib/upstream.mjs','lib/catalog.mjs','.gitignore']
repl = [
    ('FreePiLogin5','FreePiLoginN'),
    ('freepi5','freepiN'),
    ('FreePi5','FreePiN'),
    ('FREEPI5','FREEPIN'),
    ('magpie-freepi5-auth','magpie-freepiN-auth'),
    ('thứ sáu','thứ bảy'),
]
for f in files:
    p = Path(f)
    if not p.exists():
        continue
    s = p.read_text()
    for a,b in repl:
        s = s.replace(a,b)
    p.write_text(s)
PY
```

Kiểm tra sót tên cũ:

```sh
grep -rn 'FreePi5\|freepi5\|FREEPI5\|FreePiLogin5\|thứ sáu' . --exclude-dir=upstream || true
```

Chỉ được còn tên cũ trong `upstream/` hoặc phần lịch sử có chủ đích.

Kiểm tra nhận dạng:

```sh
grep -n 'PROVIDER\|name: "FreePiN"\|SESSION_ID\|freepiN' index.mjs lib/upstream.mjs lib/store.mjs
```

Kỳ vọng:

```text
index.mjs: const PROVIDER = "freepiN"
index.mjs: name: "FreePiN"
lib/upstream.mjs: export const SESSION_ID = "magpie-freepiN"
lib/store.mjs: join(homedir(), ".freepiN")
```

`lib/store.mjs` phải đọc `FREEPIN_HOME` trước khi mặc định `~/.freepiN`.

---

## 3. Tạo icon riêng

Yêu cầu:

- `icon.svg`, 128×128, nền bo góc.
- Màu/bố cục khác mọi icon FreePi đang có; có số `N`.
- Không dùng icon `freepi.ai`, không copy icon FreePi2/3/4/5.

Ví dụ:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="FreePiN">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0f766e"/>
      <stop offset="0.55" stop-color="#0d9488"/>
      <stop offset="1" stop-color="#22d3ee"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="30" fill="url(#g)"/>
  <path d="M74 16 L40 72 H62 L52 112 L92 50 H68 Z" fill="#ffffff"/>
  <circle cx="98" cy="98" r="21" fill="#0f172a" stroke="#fde68a" stroke-width="4"/>
  <text x="98" y="108" text-anchor="middle" font-family="system-ui, sans-serif"
        font-size="26" font-weight="700" fill="#fde68a">N</text>
</svg>
```

Nhúng vào `package.json` bằng Python (không dùng `base64 -w0`):

```sh
python3 - <<'PY'
import json, base64
p = 'package.json'
d = json.load(open(p))
d['magpie']['icon'] = 'data:image/svg+xml;base64,' + base64.b64encode(open('icon.svg','rb').read()).decode()
json.dump(d, open(p,'w'), ensure_ascii=False, indent=2)
open(p,'a').write('\n')
print(d['magpie']['name'], len(d['description']), len(d['magpie']['summary']['vi']))
PY
```

Prefix base64 phải là `PHN2Zy...`.

---

## 4. Sửa `package.json`

Các trường bắt buộc:

```json
{
  "name": "magpie-freepiN-auth",
  "version": "0.1.0",
  "description": "Provider FreePiN cho magpie — đăng nhập GitHub device flow vào api.freepi.ai, dùng tài khoản riêng, kho dữ liệu riêng ~/.freepiN, icon riêng, mô tả tiếng Việt.",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/OWNER/FreePiLoginN.git"
  },
  "author": "OWNER",
  "license": "MIT",
  "magpie": {
    "name": "FreePiN",
    "icon": "data:image/svg+xml;base64,...",
    "summary": {
      "vi": "Provider FreePiN cho magpie — đăng nhập GitHub device flow vào api.freepi.ai, tài khoản riêng; session id riêng trong ~/.freepiN, icon riêng, tiếng Việt."
    },
    "maxConcurrency": 4
  }
}
```

Quy tắc:

- `magpie.summary.vi` ≤ 300 byte; mô tả hoàn toàn tiếng Việt.
- `files` phải có `index.mjs`, `lib`, `icon.svg`, `README.md`, `LICENSE`.
- `LICENSE` giữ dòng gốc `Copyright (c) 2026 aqiu817 (magpie-freepi-auth, bản gốc được fork)`
  và thêm `Copyright (c) 2026 OWNER (phần chỉnh sửa cho FreePiN)`.

Kiểm tra:

```sh
node --check index.mjs
node --check lib/upstream.mjs
node --check lib/store.mjs
node --check lib/catalog.mjs
```

Smoke test:

```sh
node - <<'JS'
import('./index.mjs').then(m => {
  console.log(Object.keys(m), m.FreePiNPlugin?.provider?.id);
}).catch(e => { console.error(e); process.exit(1); });
JS
```

---

## 5. Sửa `README.md`

Bắt buộc có:

1. **Giới thiệu**: repo private chứa plugin `magpie-freepiN-auth` (provider `freepiN`,
   tên hiển thị `FreePiN`) và bản sao đầy đủ `upstream/FreePi2API/`.
2. **Cài đặt**: repo private nên `magpie plugin add github:...` **không chạy** (bun tải
   `api.github.com/.../tarball/` không kèm token → 404). Cách đúng:

   ```sh
   gh auth login
   gh repo clone OWNER/FreePiLoginN ~/.local/src/FreePiLoginN
   magpie plugin add ~/.local/src/FreePiLoginN
   ```

3. **Đăng nhập**: `openmagpie` → Settings → Providers → Add provider → From plugins →
   `FreePiN` → “Đăng nhập bằng mã thiết bị GitHub”. CLI:
   `magpie plugin login freepiN` (chỉ khi có trình duyệt cùng máy/SSH tunnel).
4. **Sử dụng**: `freepiN/<model>`, `magpie provider test freepiN deepseek-v4.1-flash`,
   `magpie provider models freepiN`, `magpie group set ...`.
5. **Bảng so sánh** với các provider FreePi đang có. Không thêm lại `free-pi` nếu máy
   đã gỡ. Cột mới phải có `x-session-id` = `~/.freepiN/session-id` (UUID, 0600).
6. **Lưu trữ tách biệt**: token ở `plugin-auth.json` khoá `freepiN`; session id ở
   `~/.freepiN/session-id`; `FREEPIN_HOME` để đổi chỗ.
7. **Giới hạn chống gộp tài khoản**: tách session/token/client version, **không tách
   được IP**; proxy chỉ giảm rủi ro:

   ```sh
   magpie plugin options ~/.local/src/FreePiLoginN '{"proxy":"http://proxy-host:8080"}'
   ```

8. **Cập nhật/gỡ**:

   ```sh
   git -C ~/.local/src/FreePiLoginN pull --ff-only
   magpie plugin add ~/.local/src/FreePiLoginN

   magpie plugin logout freepiN     # tuỳ chọn
   magpie plugin rm ~/.local/src/FreePiLoginN
   ```

---

## 6. Tạo repo private và push

```sh
cd "$NEW"
git init -b main
git add -A
git commit -m "FreePiN: plugin magpie provider freepiN + mã nguồn FreePi2API"
gh repo create "$REPO" --private --source=. --remote=origin --push
gh repo view "$REPO" --json visibility,url,defaultBranchRef \
  -q '.visibility+" "+.url+" "+.defaultBranchRef.name'
```

Kỳ vọng: `PRIVATE`, nhánh `main`.

Kiểm tra đủ file:

```sh
git ls-tree -r --name-only HEAD | grep -E '^(index.mjs|package.json|icon.svg|README.md|LICENSE|lib/|upstream/FreePi2API/)'
```

---

## 7. Cài plugin và đăng nhập

```sh
export PATH="$HOME/.local/bin:$PATH"
magpie plugin add "$NEW"
magpie plugin list | grep -E 'FreePiN|freepiN'
```

Lúc này `magpie providers` **chưa** hiện `freepiN` — bình thường, vì chưa có auth
record. Chỉ `magpie plugin list` và web UI `/api/providers` (mục `plugins`) thấy nó.

Đăng nhập nền:

```sh
rm -f /tmp/opencode/freepiN-login.log
setsid nohup magpie plugin login freepiN > /tmp/opencode/freepiN-login.log 2>&1 < /dev/null &
sleep 3
cat /tmp/opencode/freepiN-login.log
```

Đưa người dùng URL + mã. Nhắc họ dùng tài khoản GitHub **khác** với mọi tài khoản đã
dùng cho FreePi. Nếu mã hết hạn, chạy lại lệnh và đưa mã mới.

Sau khi người dùng xác nhận:

```sh
tail -5 /tmp/opencode/freepiN-login.log
magpie plugin list | grep freepiN
magpie providers | grep freepiN
magpie accounts | grep freepiN
stat -c '%a %n' ~/.freepiN ~/.freepiN/session-id
magpie provider test freepiN deepseek-v4.1-flash
```

Kỳ vọng:

```text
freepiN (FreePiN, 18 models)  signed in as <account>
FreePiN  freepiN  freepiN  ● signed in as <account>  1 of 18 models
~/.freepiN: 700, ~/.freepiN/session-id: 600
✓ chat
```

Nếu `429 one request at a time`, chờ 5 giây rồi thử lại.

---

## 8. Kiểm tra model, tránh chọn nhầm

```sh
magpie provider models freepiN
magpie group tester
```

Nếu thấy `deepseek-v4-flash` thay vì `deepseek-v4.1-flash`:

```sh
magpie provider models freepiN +deepseek-v4.1-flash
magpie provider models freepiN -deepseek-v4-flash
magpie group set tester models=freepiN/deepseek-v4.1-flash,workbuddy-ai/glm-5.3-flash
magpie opencode
```

Kiểm tra thật qua gateway:

```sh
curl -s -D- -H 'Authorization: Bearer magpie' \
  -H 'content-type: application/json' \
  http://127.0.0.1:3425/v1/chat/completions \
  -d '{"model":"group/tester","messages":[{"role":"user","content":"OK"}],"max_tokens":64}' | head -20
```

Header phải có:

```text
X-Magpie-Model: freepiN/deepseek-v4.1-flash
X-Magpie-Provider: freepiN
```

OpenCode/OpenChamber đang mở phải tạo phiên mới mới thấy model mới.

---

## 9. Nếu máy có repo shell-cloud

Nếu trên máy có thư mục `magpie-cloudshell` (hoặc repo tương đương), cập nhật:

- `scripts/plugins.sh`: thêm
  `install_private_plugin "FreePiN" "FreePiLoginN" "freepiN" "${FREEPIN_DIR:-$HOME/.local/src/FreePiLoginN}"`.
- `scripts/doctor.sh`: thêm `"FreePiN:freepiN"` vào vòng lặp kiểm tra.
- `scripts/login.sh`: thêm `freepiN` vào usage/case và số thứ tự.
- `docs/providers.md`: thêm dòng + mục `### FreePiN — freepiN`.
- `docs/freepiN.md`: tạo từ `docs/freepi5.md`.
- `AGENTS.md`, `README.md`, `docs/inventory.md`, `docs/opencode.md`: đếm lại thật rồi
  cập nhật số provider/plugin/model.

Đếm lại, không đoán:

```sh
magpie plugin list | grep -c '  on$'
magpie providers | awk '/●/{on++} /○/{off++} END{print "on="on, "off="off, "total="on+off}'
python3 -c 'import json; d=json.load(open("/home/duc_nguyenvan05/.config/opencode/opencode.json")); print(len(d["providers"]["magpie"]["models"]))'
```

Nếu không có shell-cloud, bỏ qua mục này.

---

## 10. Checklist nghiệm thu

- [ ] Repo `OWNER/FreePiLoginN` **private**, nhánh `main`, có `index.mjs`, `lib/`,
      `upstream/FreePi2API/`, `icon.svg`, `package.json`, `README.md`, `LICENSE`.
- [ ] `package.json`: `name` = `magpie-freepiN-auth`, `magpie.name` = `FreePiN`,
      `magpie.icon` data URI, summary tiếng Việt ≤ 300 byte.
- [ ] `index.mjs`: `PROVIDER = "freepiN"`, `name: "FreePiN"`.
- [ ] `lib/store.mjs`: `~/.freepiN`, `FREEPIN_HOME`.
- [ ] `lib/upstream.mjs`: `SESSION_ID = "magpie-freepiN"`.
- [ ] `magpie plugin list` có `freepiN (FreePiN, 18 models)`.
- [ ] Đăng nhập xong: `magpie providers` có `FreePiN`, `magpie accounts` có tài khoản.
- [ ] `~/.freepiN` = 700, `~/.freepiN/session-id` = 600.
- [ ] `magpie provider test freepiN deepseek-v4.1-flash` = `✓ chat`.
- [ ] `magpie group tester` dùng `freepiN/deepseek-v4.1-flash` nếu có.
- [ ] `magpie opencode` đã chạy lại; OpenCode có model mới.
- [ ] Không có token/secret nào trong git.

---

## 11. Bẫy đã gặp

1. **`magpie plugin add github:OWNER/FreePiLoginN` → 404.** Bun 1.4.4 tải
   `api.github.com/repos/OWNER/FreePiLoginN/tarball/` mà không gửi `Authorization`.
   `GITHUB_TOKEN` không được dùng cho spec `github:`. Dùng `gh repo clone` + local path.
2. **`git+https://...` cũng 404** vì bun chuẩn hoá về tarball API. `git+ssh://...` chỉ
   chạy nếu máy có SSH key riêng được thêm vào repo.
3. **`magpie providers` không thấy provider mới.** Bình thường khi chưa đăng nhập.
   Dùng `magpie plugin list` và web UI `/api/providers` mục `plugins`.
4. **`magpie plugin options magpie-freepiN-auth` báo “no plugin”.** Plugin cài bằng
   đường dẫn local, phải dùng `magpie plugin options ~/.local/src/FreePiLoginN ...`.
5. **`magpie plugin add` có thể làm mất plugin khác.** Sau mỗi lần add, chạy
   `magpie plugin list` và kiểm tra đủ plugin; nếu thiếu, cài lại và chạy lại bước vá.
6. **Chọn nhầm `deepseek-v4-flash`.** Sửa cả `magpie provider models` và
   `magpie group set`, rồi `magpie opencode`.
7. **`magpie plugin list --json | python3 - <<EOF` lỗi JSON.** Heredoc chiếm stdin;
   ghi JSON ra file tạm rồi đọc.
8. **Base64 icon sai.** Dùng Python `base64.b64encode`, không dùng `base64 -w0`.
9. **Đừng đổi `user-agent: free-pi-cli/<version>` hay bỏ `x-client-version`.** Đây là
   hai cổng upstream: `426` nếu client cũ, `403 ads_required` nếu không báo banner.
10. **Không thể giấu hoàn toàn nhiều tài khoản.** Session/token/thư mục/client version
    tách được; IP thì không. Proxy chỉ giảm rủi ro, không bảo đảm tuyệt đối.
11. **Redaction có thể che chuỗi tài khoản trong output.** Nếu thấy khác lạ, dùng
    `repr()`/codepoint trước khi kết luận file sai.
12. **OpenCode/OpenChamber đang mở không tự thấy model mới.** Phải mở phiên mới.

---

## Phụ lục A — `lib/store.mjs` nếu làm từ plugin FreePi gốc

Nếu dùng Cách B (không clone được template), tạo `lib/store.mjs`:

```js
import { randomUUID } from "node:crypto";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export function freePiNHome() {
  const fromEnv = process.env.FREEPIN_HOME;
  return fromEnv && fromEnv.trim() ? fromEnv.trim() : join(homedir(), ".freepiN");
}

export function sessionIdPath() {
  return join(freePiNHome(), "session-id");
}

export async function getSessionId() {
  const file = sessionIdPath();
  try {
    const id = (await readFile(file, "utf8")).trim();
    if (id) return id;
  } catch {}
  const id = randomUUID();
  await mkdir(freePiNHome(), { recursive: true, mode: 0o700 });
  await writeFile(file, id + "\n", { mode: 0o600 });
  await chmod(freePiNHome(), 0o700);
  await chmod(file, 0o600);
  return id;
}

export async function resetSessionId() {
  const { rm } = await import("node:fs/promises");
  await rm(sessionIdPath(), { force: true });
}
```

Sau đó sửa `lib/upstream.mjs`:

- `export const SESSION_ID = "magpie-freepiN";` (chỉ là fallback)
- `export function authHeaders(token, sessionId = SESSION_ID)` và dùng
  `"x-session-id": sessionId`.
- `reportImpression(token, { fetchImpl = fetch, sessionId = SESSION_ID } = {})` và
  truyền `sessionId` vào mọi `authHeaders`.

Sửa `index.mjs`:

- `import { getSessionId } from "./lib/store.mjs";`
- Trong plugin: `const sessionId = await getSessionId();`
- Truyền `sessionId` vào mọi chỗ gọi upstream (`/me`, loader, usage, `/client-version`,
  `reportImpression`).

Đây chính là phần giúp hai tài khoản không dùng chung `x-session-id`.
