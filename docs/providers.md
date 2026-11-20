# Provider — từng cái một

magpie gom mọi provider về một gateway `127.0.0.1:3425`. Agent chỉ thấy một provider
tên `magpie`; provider thật nằm sau gateway. Vì vậy thêm/bớt provider **không cần
sửa cấu hình agent** — magpie tự ghi lại danh sách model.

## Bảng tổng hợp

| id | Tên | Xác thực | Cần gì từ bạn | Kiểm tra |
|---|---|---|---|---|
| `autoclaw` | AutoClaw (Zhipu) | OAuth Google/z.ai (plugin) | tài khoản Google hoặc z.ai | `magpie accounts` |
| `workbuddy-ai` | WorkBuddy AI | OAuth web (plugin) | tài khoản WorkBuddy | `magpie accounts` |
| `agy-cli` | agy-cli | OAuth Google (plugin) | tài khoản Google (Antigravity) | `magpie provider test agy-cli gemini-3.8-flash` |
| `freepi` | FreePi | OAuth (plugin) | tài khoản FreePi | `magpie provider test freepi deepseek-v4.1-flash` |
| `freepi2` | FreePi2 | OAuth (plugin riêng, repo private) | tài khoản FreePi thứ ba | `magpie provider test freepi2 deepseek-v4.1-flash` |
| `freepi3` | FreePi3 | OAuth (plugin riêng, repo private) | tài khoản FreePi thứ tư | `magpie provider test freepi3 deepseek-v4.1-flash` |
| `freepi4` | FreePi4 | OAuth (plugin riêng, repo private) | tài khoản FreePi thứ năm | `magpie provider test freepi4 deepseek-v4.1-flash` |
| `freepi5` | FreePi5 | OAuth (plugin riêng, repo private) | tài khoản FreePi thứ sáu | `magpie provider test freepi5 deepseek-v4.1-flash` |
| `freepi6` | FreePi6 | OAuth (plugin riêng, repo private) | một tài khoản FreePi riêng | `magpie provider test freepi6 deepseek-v4.1-flash` |
| `cline` | Cline | OAuth (plugin) | tài khoản Cline | `magpie accounts` |
| `kiro` | Kiro | OAuth Google (plugin) | tài khoản Kiro | `magpie accounts` |
| `agnes` | Agnes | plugin + API key `cpk-…` | key từ `platform.agnes-ai.com` | **tắt** (`magpie provider on agnes`) |
| `kilo` | Kilo Gateway | API key `eyJ…` | key từ kilo.ai | `magpie provider test kilo` |
| `openrouter` | OpenRouter | API key `sk-or-…` | key từ openrouter.ai | `magpie provider test openrouter` |
| `groq` | Groq | API key `gsk_…` | key từ console.groq.com | `magpie provider test groq openai/gpt-oss-20b` |
| `nvidia` | NVIDIA NIM | API key `nvapi-…` | key từ build.nvidia.com | `magpie provider test nvidia nvidia/nemotron-3.5-super-vl-120b-a12b` |
| `xingchi` | Xingchi custom | API key + `baseAPI` riêng | key + endpoint `api.xingchiapi.com` | `magpie provider test xingchi gpt-6.1-sol` |
| `aihubmix` | AiHubMix | API key `sk-e…` | key + **đã nạp tiền** | **tắt**; nếu bật, 36 model `-free` trả câu từ chối khi chưa nạp — xem dưới |
| `opencode-zen` | OpenCode Zen | API key `oc_…` | key từ opencode.ai | đang **bật**, chỉ expose `jev-1.13-free` (classifier) |
| `qoder` | Qoder | OAuth web (plugin) | tài khoản Qoder | record còn, **không hiện** (thiếu plugin) |
| `antigravity` | Antigravity | OAuth (plugin) | tài khoản Google | record còn, **không hiện** (thiếu plugin) |
| `copilot` | Copilot | OAuth GitHub | tài khoản GitHub Copilot | **tắt** |
| `opencode-zen-free` | OpenCode Zen Free | plugin (key công khai) | không | **tắt** — hạn mức theo IP dùng chung |

### `aihubmix` (AiHubMix) — bẫy "xanh giả"

`magpie provider test aihubmix <model>` báo `✓ chat` chỉ vì gateway thấy **HTTP 200 + có
text**; AiHubMix trả 200 kèm câu *"Sorry, to prevent abuse of free resources, accounts
that have not been recharged can only try 10 times…"* và `completion_tokens: 0`. Cả 36
model `-free` đều như vậy khi tài khoản chưa nạp tiền lần nào. Muốn kiểm thật thì đọc
`choices[0].message.content`, đừng tin mã trạng thái. Đừng đưa provider này vào group nào.

### `xingchi` (Xingchi custom) — pool model và `reasoning_effort`

Endpoint `https://api.xingchiapi.com`, bán lại qua các "group" tài khoản: mỗi model do
một nhóm account riêng phục vụ. Khi nhóm đó không còn channel sống, upstream trả **503
`Service temporarily unavailable`** gần như tức thì (0,4–0,6 s) — khác với quá tải thật
(sẽ treo lâu rồi mới lỗi). Nếu client gửi `stream: true`, magpie giữ kết nối, upstream
nhả `: keepalive` khoảng 34 s rồi mới gửi event lỗi, nên client thường hiện thành **502**
dù HTTP header đã là 200.

- `gpt-6-astra` hỏng theo kiểu này từ 2026-11-17 (4/4 lần 503, balance vẫn còn) → đã bỏ
  khỏi `group/leader`. Muốn thử lại: `magpie provider test xingchi gpt-6-astra`.
- `gpt-6.1-sol` sống, nhưng upstream nhồi sẵn ~4.200 `prompt_tokens` system prompt vào
  mọi request, và mặc định (không gửi `reasoning_effort`) chậm ~4,6 s cho một câu hai
  chữ. Ghim level trong tên model — `xingchi/gpt-6.1-sol:high` — thì magpie gửi
  `reasoning_effort`, đo được **~2,0 s**; `:low` ~1,8 s. Vẫn có lúc queue lên 48 s, đó
  là phương sai phía họ, không sửa được từ phía mình.
- Cổng client: request có User-Agent lạ (ví dụ `curl/8`) bị chặn bằng **403
  `client_not_allowed`** kèm danh sách client được phép (Codex, Claude Code, OpenCode…).
  Muốn test bằng `curl` thì đặt `-H "User-Agent: opencode/2.3.0"`.

## Provider dùng OAuth (bấm trình duyệt)

Cả ba đều là plugin cộng đồng, cài bằng `magpie plugin add …` rồi `magpie plugin login …`.
Trên Cloud Shell phải chuyển tiếp cổng (xem `docs/autoclaw-login.md` mục 3).

### AutoClaw (Zhipu) — `autoclaw`

```sh
magpie plugin add @magpie-community/opencode-autoclaw-auth
magpie plugin login autoclaw          # 1 = Google, 2 = z.ai
magpie provider test autoclaw zai_auto
```

Chi tiết đầy đủ: [`autoclaw-login.md`](autoclaw-login.md).

### WorkBuddy AI — `workbuddy-ai`

```sh
magpie plugin add @magpie-community/opencode-workbuddy-auth
magpie plugin login workbuddy-ai
```

Plugin này đăng ký hai build:

| id | Build | API |
|---|---|---|
| `workbuddy-ai` | WorkBuddy AI (quốc tế) | `https://www.workbuddy.ai/v2` |
| `workbuddy` | WorkBuddy (Trung Quốc, plan CodeBuddy) | `https://copilot.tencent.com/v2` |

Ba cách đăng nhập (plugin hỏi khi chạy `login`):

1. **Account (browser)** — mở trang đăng nhập Tencent, plugin hỏi token mỗi giây tới 5 phút. Không copy gì.
2. **Desktop's sign-in** — đọc tài khoản app WorkBuddy desktop đang dùng (WorkBuddy ≥ 5.6 mã hoá file này nên cách này hỏng; dùng cách 1).
3. **API key** — key tạo ở trang keys của build tương ứng.

Nhiều tài khoản: chạy `magpie plugin login workbuddy-ai` lần nữa. Điểm danh hằng ngày
của WorkBuddy: `magpie accounts checkin` (hoặc bật trong Settings → Usage → Plugins).

### Qoder — `qoder`

```sh
magpie plugin add @magpie-community/opencode-qoder-auth
magpie plugin login qoder
```

Cùng plugin còn đăng ký `qoder-cn`, `qwenwork`, `qwenwork-enterprise` — chỉ cần nếu
bạn có tài khoản tương ứng.

Máy tham chiếu **không cài plugin này**: provider `qoder` đang tắt và không nằm trong
group nào. Cài lại đúng ba dòng trên khi muốn dùng.

### ZCode — `zcode` (tuỳ chọn)

```sh
magpie plugin add @magpie-community/opencode-zcode-auth
magpie plugin login zcode
```

Máy tham chiếu **không cài**; `zcode` không phải provider đang bật và không nằm trong
group nào.

### Agnes — `agnes`

```sh
magpie plugin add @magpie-community/opencode-agnes-auth
bash scripts/agnes-link.sh                 # mở link, đăng nhập, dán API key
magpie provider test agnes agnes-3.0-flash
```

Trên máy có màn hình, `magpie plugin login agnes` tự mở Chrome và đọc token. Trên máy
headless thì không: plugin cần Chrome **trên chính máy chạy magpie**, mà Agnes **không có
OAuth callback** về localhost — token nằm trong `localStorage`, không bao giờ vào URL, nên
không có gì để copy rồi gửi lại như Kiro/AutoClaw.

Vì vậy `agnes-link.sh` dựng một trang local (link `https://<cổng>-<WEB_HOST>/?k=…`): bạn
đăng nhập Agnes bằng trình duyệt của mình, copy API key, dán vào trang. Trang tự chạy
`magpie plugin login agnes "Agnes API key"`, kiểm tra key với `apihub.agnes-ai.com`, rồi
báo xong. Key không đi qua chat và không ghi log.

| Loại key | Dạng | Hạn mức hiện trên `magpie accounts` |
|---|---|---|
| Token/Agent Plan | `cpk-…` | 5 giờ + tuần (request) hoặc credit tháng |
| Personal / Enterprise | `apk-…` | số dư USD |

Console token (`localStorage.getItem("token")` ở `platform.agnes-ai.com`) là tuỳ chọn, chỉ
để đọc hạn mức; không có nó vẫn gọi model bình thường.

### Cụm FreePi — `freepi`, `freepi2`, `freepi3`, `freepi4`, `freepi5`, `freepi6`

Sáu plugin, cùng một upstream `api.freepi.ai`, **sáu tài khoản khác nhau** — không phải
bản sao của nhau:

| Plugin | Provider id | Tài khoản trên máy này | Model expose |
|---|---|---|---|
| `magpie-freepi-auth` | `freepi` | `Duc-Nguyen-739` (Free) | 1 / 24 — `deepseek-v4.1-flash` |
| `magpie-freepi2-auth` | `freepi2` | `huenguyen-code` | 1 / 24 — `deepseek-v4.1-flash` |
| `magpie-freepi3-auth` | `freepi3` | `hoangphat-coder` | 1 / 24 — `deepseek-v4.1-flash` |
| `magpie-freepi4-auth` | `freepi4` | `phucth2002-spec` | 1 / 24 — `deepseek-v4.1-flash` |
| `magpie-freepi5-auth` | `freepi5` | `ngocson-coder` | 1 / 24 — `deepseek-v4.1-flash` |
| `magpie-freepi6-auth` | `freepi6` | `haiquan-tbs` | 1 / 24 — `deepseek-v4.1-flash` |

Mỗi tài khoản có budget riêng (15.000 credits/ngày; riêng FreePi2/FreePi3/FreePi4/FreePi5/FreePi6 là 6.000 trên tài khoản này) và **một slot đồng thời riêng**. Magpie đã đặt
`account-concurrency 1` + queue cho **cả sáu**, nên request thứ hai trên cùng provider
**xếp hàng** chứ không nhận 429; request chỉ bị 429 nếu queue đầy hoặc retry đã hết.
Sáu tài khoản = sáu slot + sáu budget, không phải "đổi tài khoản" và không bị server chặn.

Cấu hình đang áp cho cả sáu (đổi `<id>` và `<handle>` theo bảng trên):

```sh
magpie provider account-concurrency <id> <handle> 1
magpie provider queue <id> 32 0
magpie provider rpm <id> off
```

Plugin FreePi4 (và bốn plugin local FreePi2/3/5/6) còn giữ 1 giây sau mỗi reply và
retry 429 `concurrent` tối đa 5 lần; `freepi` là plugin npm nên chỉ có queue của magpie.

**Tách rời nhau ở đâu.** Các provider chỉ dùng chung domain; phần đăng nhập, session,
budget và slot là riêng từng cái (bảng dưới là hai provider gốc; FreePi2/FreePi3/FreePi4/FreePi5/FreePi6 có
mục riêng bên dưới). **`free-pi` đã được gỡ khỏi máy này ngày 2026-11-18** — phần
`free-pi` dưới đây giữ làm tham khảo nếu cài lại:

| | `freepi` | `free-pi` |
|---|---|---|
| Plugin | `magpie-freepi-auth` | `magpie-free-pi` (đã vá) |
| JWT giữ ở | auth store của magpie (khoá theo provider id) | `~/.free-pi/agent/accounts.json` (0600) |
| `x-session-id` | hằng số `magpie-freepi` | `~/.free-pi/agent/session-id` |
| Tài khoản / budget | `Duc-Nguyen-739` — 15.000 credits/ngày | `Duc-Nguyen-739` — 15.000 credits/ngày |
| Slot đồng thời | 1 | 1 |
| Client version | tự canh từ `/client-version` (12h/lần) | bản vá đọc `/client-version` mỗi request |

Pool của `free-pi` chỉ dedupe theo **chuỗi JWT**, nên đăng nhập cùng một tài khoản GitHub
hai lần sinh hai entry cùng `user_id`: server vẫn chỉ cấp một budget, chỉ bộ đếm
slot/rotation bị lệch (và có thể tự đụng `429 one request at a time`). Script gọi `/me`
cho từng entry rồi giữ entry **mới nhất** cho mỗi `user_id`:

```sh
node scripts/setup-freepi-pair.mjs --check   # 0 = sạch, 1 = có entry trùng
node scripts/setup-freepi-pair.mjs           # dọn, backup accounts.json.bak-…
```

`scripts/plugins.sh` chạy script này sau khi vá `free-pi`; `scripts/doctor.sh` báo nếu pool
còn trùng. Đừng sửa tay `accounts.json`: JWT trong đó là credential, và `freepi` không
dùng file này — nó nằm trong auth store của magpie.

**Cái bẫy:** bản `magpie-free-pi@0.1.5` trên npm ghim `FREEPI_CLIENT_VERSION` (lúc phát
hành là `0.6.16`) rồi gửi qua header `x-client-version`. freepi.ai nâng mức tối thiểu
(`GET /client-version` → `min`, `latest`) mà không báo trước; client cũ bị chặn bằng
**HTTP 426 `upgrade_required`** ngay trước bước định tuyến model, nên **mọi** model cùng
chết — UI báo "9 of 9 models didn't answer", còn `magpie provider test` chỉ thấy 426.

```sh
node scripts/patch-free-pi.mjs --check   # 0 = đã vá, 1 = chưa
node scripts/patch-free-pi.mjs           # vá (idempotent)
kill $(pgrep -f "magpie serve --web=0.0.0.0:3430")   # supervisor tự dựng lại
magpie provider test free-pi particle
```

Bản vá đổi hằng số thành biến sống: mỗi request chat đọc `min`/`latest` từ
`GET /client-version` (công khai, không cần auth, cache 10 phút, chính endpoint plugin đã
gọi để lấy catalog), lấy số lớn hơn, và giữ `0.6.22` làm mức dự phòng khi mạng hỏng. Nhờ
vậy server nâng mức nữa thì plugin tự theo, không phải sửa tay.

Vá nằm trong `~/.config/magpie/plugins/node_modules/`, nên **mất khi `magpie plugin update`
hoặc cài lại plugin** — `scripts/plugins.sh` (và `bootstrap.sh`) tự chạy lại bản vá sau khi
cài, `scripts/doctor.sh` báo nếu thiếu. Sửa gốc là việc của upstream
(`github.com/wawaTuna/magpie-free-pi`): đọc `min` từ `/client-version` thay vì ghim — đã mở
issue kèm bằng chứng và bản vá mẫu:
<https://github.com/wawaTuna/magpie-free-pi/issues/1>.

**Ad gate — 403 `ads_required`.** `magpie-free-pi` còn thiếu một phần nữa: nó không báo
banner impression. freepi.ai trả `403 {"code":"ads_required"}` cho completion khi tài khoản
chưa có impression gần đây; UI hiện "Ads aren't showing for this account, so free completions
are paused". `magpie-freepi-auth` đã báo (`GET /ads/next?slot=banner` → `POST /ads/impression`),
nên `freepi` chạy bình thường; `free-pi` thì không. Bản vá thêm `reportImpression()` vào
`free-pi-core.mjs`, gọi nó trong `loader.fetch` (fire-and-forget, không click, không đổi
JWT/header), và thêm cửa sổ `广告展示` vào `usage()` để UI đếm số impression đã báo
(giống `magpie-freepi-auth`):

```sh
node scripts/patch-free-pi-ads.mjs --check   # 0 = đã vá, 1 = chưa
node scripts/patch-free-pi-ads.mjs           # vá (idempotent)
node scripts/patch-free-pi-ads.mjs --revert  # trả file về bản gốc trước lần vá đầu
magpie provider test free-pi
```

Đây **không phải** "phát hiện đổi tài khoản": hai JWT có `sub` khác nhau, server không bind
`x-session-id` với tài khoản, và một impression thủ công mở lại chat ngay. `scripts/plugins.sh`
chạy cả hai bản vá sau khi cài/update plugin.

### FreePi2 — `freepi2` (plugin riêng, repo private)

Chi tiết đầy đủ (cài, đăng nhập, vướng mắc, giới hạn): [`docs/freepi2.md`](freepi2.md).

Bản sao logic của `freepi` nhưng **cổng đăng nhập và kho dữ liệu hoàn toàn riêng**, để
dùng tài khoản FreePi thứ ba mà không đụng `freepi` / `free-pi`:

| | `freepi2` |
|---|---|
| Repo | <https://github.com/Duc-Nguyen-739/FreePiLogin2> (**private**) |
| Plugin | `magpie-freepi2-auth` |
| Tên hiển thị | **FreePi2** — icon riêng (tia chớp xanh + số 2 cam), mô tả tiếng Việt |
| JWT giữ ở | `~/.config/magpie/plugin-auth.json`, khoá `freepi2` |
| `x-session-id` | `~/.freepi2/session-id` — UUID ngẫu nhiên, file 0600, thư mục 0700 |
| Đổi thư mục | `FREEPI2_HOME=/đường/dẫn/khác` |
| Tài khoản trên máy này | `ngaynaochavao7399-del` — 6.000 credits/ngày, 1 slot |
| Client version | tự canh từ `/client-version` (như `freepi`) |
| Ad gate | tự báo `GET /ads/next?slot=banner` → `POST /ads/impression` (như `freepi`) |

**Cài (repo private).** `magpie plugin add github:...` **không chạy** với repo private:
bun mà magpie gọi tới tải `api.github.com/repos/.../tarball/` mà không gửi token, nên
GitHub trả `404`. Cài bằng cách clone rồi trỏ vào thư mục:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin2 ~/.local/src/FreePiLogin2
magpie plugin add ~/.local/src/FreePiLogin2
```

Máy khác cần `gh auth login` bằng tài khoản có quyền đọc repo. Cập nhật:

```sh
git -C ~/.local/src/FreePiLogin2 pull --ff-only
magpie plugin rm ~/.local/src/FreePiLogin2
magpie plugin add ~/.local/src/FreePiLogin2
```

**Đăng nhập.** Web UI → Settings → Providers → Add provider → **From plugins** →
**FreePi2** → “Đăng nhập bằng mã thiết bị GitHub”. Trên Cloud Shell, dùng web UI
(`openmagpie`) thay vì CLI vì trình duyệt không ở cùng máy. `magpie providers` chỉ
hiện FreePi2 **sau khi** đăng nhập; trước đó xem `magpie plugin list`.

**Dùng.**

```sh
magpie provider test freepi2 deepseek-v4.1-flash   # ✓ chat
magpie provider models freepi2                     # chọn thêm model (18 có sẵn)
magpie group set main models+=freepi2/deepseek-v4.1-flash
```

**Giới hạn chống bị gộp tài khoản.** Ba provider tách session id, JWT, client
version và budget, nhưng **không tách được IP**: upstream vẫn thấy mọi request đi
từ cùng một địa chỉ và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm
server không phát hiện; nếu cần khác IP, đặt proxy riêng cho provider này:

```sh
magpie plugin options ~/.local/src/FreePiLogin2 '{"proxy":"http://proxy-host:8080"}'
```

Đây là plugin cộng đồng không chính thức, dịch ngược từ `free-pi-cli`; upstream đổi
là hỏng. Mã nguồn FreePi2API gốc nằm trong `upstream/FreePi2API/` của repo.

### FreePi3 — `freepi3` (plugin riêng, repo private)

Chi tiết đầy đủ (cài, đăng nhập, vướng mắc, giới hạn): [`docs/freepi3.md`](freepi3.md).

Bản sao logic của FreePi2 nhưng **cổng đăng nhập và kho dữ liệu hoàn toàn riêng**, để
dùng tài khoản FreePi thứ tư mà không đụng `freepi` / `free-pi` / `freepi2`:

| | `freepi3` |
|---|---|
| Repo | <https://github.com/Duc-Nguyen-739/FreePiLogin3> (**private**) |
| Plugin | `magpie-freepi3-auth` |
| Tên hiển thị | **FreePi3** — icon riêng (tia chớp trên nền cam/đỏ + số 3), mô tả tiếng Việt |
| JWT giữ ở | `~/.config/magpie/plugin-auth.json`, khoá `freepi3` |
| `x-session-id` | `~/.freepi3/session-id` — UUID ngẫu nhiên, file 0600, thư mục 0700 |
| Đổi thư mục | `FREEPI3_HOME=/đường/dẫn/khác` |
| Tài khoản trên máy này | `ngaynaochavao739-ui` — 6.000 credits/ngày, 1 slot |
| Client version | tự canh từ `/client-version` (như `freepi`) |
| Ad gate | tự báo `GET /ads/next?slot=banner` → `POST /ads/impression` (như `freepi`) |

**Cài (repo private).** Giống FreePi2, `magpie plugin add github:...` trả `404` vì bun
tải tarball qua API GitHub mà không gửi token. Clone rồi trỏ vào thư mục:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin3 ~/.local/src/FreePiLogin3
magpie plugin add ~/.local/src/FreePiLogin3
```

Cập nhật:

```sh
git -C ~/.local/src/FreePiLogin3 pull --ff-only
magpie plugin rm ~/.local/src/FreePiLogin3
magpie plugin add ~/.local/src/FreePiLogin3
```

**Đăng nhập.** Web UI → Settings → Providers → Add provider → **From plugins** →
**FreePi3** → “Đăng nhập bằng mã thiết bị GitHub”. Trên Cloud Shell dùng web UI
(`openmagpie`) thay vì CLI. `magpie providers` chỉ hiện FreePi3 **sau khi** đăng nhập;
trước đó xem `magpie plugin list`.

**Dùng.**

```sh
magpie provider test freepi3 deepseek-v4.1-flash   # ✓ chat
magpie provider models freepi3                     # chọn thêm model (18 có sẵn)
magpie group set main models+=freepi3/deepseek-v4.1-flash
```

**Giới hạn chống bị gộp tài khoản.** FreePi3 tách session id, JWT, client version và
budget, nhưng **không tách được IP**: upstream vẫn thấy mọi request đi từ cùng một địa
chỉ và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server không phát hiện;
nếu cần khác IP, đặt proxy riêng:

```sh
magpie plugin options ~/.local/src/FreePiLogin3 '{"proxy":"http://proxy-host:8080"}'
```

Đây là plugin cộng đồng không chính thức, dịch ngược từ `free-pi-cli`; upstream đổi
là hỏng. Mã nguồn FreePi2API gốc nằm trong `upstream/FreePi2API/` của repo.

### FreePi4 — `freepi4` (plugin riêng, repo private)

Chi tiết đầy đủ (cài, đăng nhập, vướng mắc, giới hạn): [`docs/freepi4.md`](freepi4.md).

Bản sao logic của FreePi2 nhưng **cổng đăng nhập và kho dữ liệu hoàn toàn riêng**, để
dùng tài khoản FreePi thứ năm mà không đụng `freepi` / `free-pi` / `freepi2`:

| | `freepi4` |
|---|---|
| Repo | <https://github.com/Duc-Nguyen-739/FreePiLogin4> (**private**) |
| Plugin | `magpie-freepi4-auth` |
| Tên hiển thị | **FreePi4** — icon riêng (tia chớp trên nền tím/hồng + số 4), mô tả tiếng Việt |
| JWT giữ ở | `~/.config/magpie/plugin-auth.json`, khoá `freepi4` |
| `x-session-id` | `~/.freepi4/session-id` — UUID ngẫu nhiên, file 0600, thư mục 0700 |
| Đổi thư mục | `FREEPI4_HOME=/đường/dẫn/khác` |
| Tài khoản trên máy này | `ngaynaochavao73999-code` — 6.000 credits/ngày, 1 slot |
| Client version | tự canh từ `/client-version` (như `freepi`) |
| Ad gate | tự báo `GET /ads/next?slot=banner` → `POST /ads/impression` (như `freepi`) |

**Cài (repo private).** Giống FreePi2, `magpie plugin add github:...` trả `404` vì bun
tải tarball qua API GitHub mà không gửi token. Clone rồi trỏ vào thư mục:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin4 ~/.local/src/FreePiLogin4
magpie plugin add ~/.local/src/FreePiLogin4
```

Cập nhật:

```sh
git -C ~/.local/src/FreePiLogin4 pull --ff-only
magpie plugin rm ~/.local/src/FreePiLogin4
magpie plugin add ~/.local/src/FreePiLogin4
```

**Đăng nhập.** Web UI → Settings → Providers → Add provider → **From plugins** →
**FreePi4** → “Đăng nhập bằng mã thiết bị GitHub”. Trên Cloud Shell dùng web UI
(`openmagpie`) thay vì CLI. `magpie providers` chỉ hiện FreePi4 **sau khi** đăng nhập;
trước đó xem `magpie plugin list`.

**Dùng.**

```sh
magpie provider test freepi4 deepseek-v4.1-flash   # ✓ chat
magpie provider models freepi4                     # chọn thêm model (18 có sẵn)
magpie group set main models+=freepi4/deepseek-v4.1-flash
```

**Giới hạn chống bị gộp tài khoản.** FreePi4 tách session id, JWT, client version và
budget, nhưng **không tách được IP**: upstream vẫn thấy mọi request đi từ cùng một địa
chỉ và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server không phát hiện;
nếu cần khác IP, đặt proxy riêng:

```sh
magpie plugin options ~/.local/src/FreePiLogin4 '{"proxy":"http://proxy-host:8080"}'
```

Đây là plugin cộng đồng không chính thức, dịch ngược từ `free-pi-cli`; upstream đổi
là hỏng. Mã nguồn FreePi2API gốc nằm trong `upstream/FreePi2API/` của repo.

### FreePi5 — `freepi5` (plugin riêng, repo private)

Chi tiết đầy đủ (cài, đăng nhập, vướng mắc, giới hạn): [`docs/freepi5.md`](freepi5.md).

Bản sao logic của FreePi2 nhưng **cổng đăng nhập và kho dữ liệu hoàn toàn riêng**, để
dùng tài khoản FreePi thứ sáu mà không đụng `freepi` / `freepi2` / `freepi3` / `freepi4`:

| | `freepi5` |
|---|---|
| Repo | <https://github.com/Duc-Nguyen-739/FreePiLogin5> (**private**) |
| Plugin | `magpie-freepi5-auth` |
| Tên hiển thị | **FreePi5** — icon riêng (tia chớp trên nền xanh dương + số 5 hồng), mô tả tiếng Việt |
| JWT giữ ở | `~/.config/magpie/plugin-auth.json`, khoá `freepi5` |
| `x-session-id` | `~/.freepi5/session-id` — UUID ngẫu nhiên, file 0600, thư mục 0700 |
| Đổi thư mục | `FREEPI5_HOME=/đường/dẫn/khác` |
| Tài khoản trên máy này | `ngocson-ctrl` — 6.000 credits/ngày, 1 slot |
| Client version | tự canh từ `/client-version` (như `freepi`) |
| Ad gate | tự báo `GET /ads/next?slot=banner` → `POST /ads/impression` (như `freepi`) |

**Cài (repo private).** Giống FreePi2, `magpie plugin add github:...` trả `404` vì bun
tải tarball qua API GitHub mà không gửi token. Clone rồi trỏ vào thư mục:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin5 ~/.local/src/FreePiLogin5
magpie plugin add ~/.local/src/FreePiLogin5
```

Cập nhật:

```sh
git -C ~/.local/src/FreePiLogin5 pull --ff-only
magpie plugin rm ~/.local/src/FreePiLogin5
magpie plugin add ~/.local/src/FreePiLogin5
```

**Đăng nhập.** Web UI → Settings → Providers → Add provider → **From plugins** →
**FreePi5** → “Đăng nhập bằng mã thiết bị GitHub”. Trên Cloud Shell dùng web UI
(`openmagpie`) thay vì CLI. `magpie providers` chỉ hiện FreePi5 **sau khi** đăng nhập;
trước đó xem `magpie plugin list`.

**Dùng.**

```sh
magpie provider test freepi5 deepseek-v4.1-flash   # ✓ chat
magpie provider models freepi5                     # chọn thêm model (18 có sẵn)
magpie group set main models+=freepi5/deepseek-v4.1-flash
```

**Giới hạn chống bị gộp tài khoản.** FreePi5 tách session id, JWT, client version và
budget, nhưng **không tách được IP**: upstream vẫn thấy mọi request đi từ cùng một địa
chỉ và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server không phát hiện;
nếu cần khác IP, đặt proxy riêng:

```sh
magpie plugin options ~/.local/src/FreePiLogin5 '{"proxy":"http://proxy-host:8080"}'
```

Đây là plugin cộng đồng không chính thức, dịch ngược từ `free-pi-cli`; upstream đổi
là hỏng. Mã nguồn FreePi2API gốc nằm trong `upstream/FreePi2API/` của repo.

### FreePi6 — `freepi6` (plugin riêng, repo private)

Chi tiết đầy đủ (cài, đăng nhập, vướng mắc, giới hạn): [`docs/freepi6.md`](freepi6.md).

Bản sao logic của FreePi2 nhưng **cổng đăng nhập và kho dữ liệu hoàn toàn riêng**, để
dùng một tài khoản FreePi riêng mà không đụng `freepi` / `freepi2` / `freepi3` / `freepi4` / `freepi5`:

| | `freepi6` |
|---|---|
| Repo | <https://github.com/Duc-Nguyen-739/FreePiLogin6> (**private**) |
| Plugin | `magpie-freepi6-auth` |
| Tên hiển thị | **FreePi6** — icon riêng (tia chớp trên nền xanh lá + số 6 vàng), mô tả tiếng Việt |
| JWT giữ ở | `~/.config/magpie/plugin-auth.json`, khoá `freepi6` |
| `x-session-id` | `~/.freepi6/session-id` — UUID ngẫu nhiên, file 0600, thư mục 0700 |
| Đổi thư mục | `FREEPI6_HOME=/đường/dẫn/khác` |
| Tài khoản trên máy này | *(đăng nhập để xem)* — 6.000 credits/ngày, 1 slot |
| Client version | tự canh từ `/client-version` (như `freepi`) |
| Ad gate | tự báo `GET /ads/next?slot=banner` → `POST /ads/impression` (như `freepi`) |

**Cài (repo private).** Giống FreePi2, `magpie plugin add github:...` trả `404` vì bun
tải tarball qua API GitHub mà không gửi token. Clone rồi trỏ vào thư mục:

```sh
gh repo clone Duc-Nguyen-739/FreePiLogin6 ~/.local/src/FreePiLogin6
magpie plugin add ~/.local/src/FreePiLogin6
```

Cập nhật:

```sh
git -C ~/.local/src/FreePiLogin6 pull --ff-only
magpie plugin rm ~/.local/src/FreePiLogin6
magpie plugin add ~/.local/src/FreePiLogin6
```

**Đăng nhập.** Web UI → Settings → Providers → Add provider → **From plugins** →
**FreePi6** → “Đăng nhập bằng mã thiết bị GitHub”. Trên Cloud Shell dùng web UI
(`openmagpie`) thay vì CLI. `magpie providers` chỉ hiện FreePi6 **sau khi** đăng nhập;
trước đó xem `magpie plugin list`.

**Dùng.**

```sh
magpie provider test freepi6 deepseek-v4.1-flash   # ✓ chat
magpie provider models freepi6                     # chọn thêm model (18 có sẵn)
magpie group set main models+=freepi6/deepseek-v4.1-flash
```

**Giới hạn chống bị gộp tài khoản.** FreePi6 tách session id, JWT, client version và
budget, nhưng **không tách được IP**: upstream vẫn thấy mọi request đi từ cùng một địa
chỉ và mỗi JWT đều định danh tài khoản. Plugin không thể bảo đảm server không phát hiện;
nếu cần khác IP, đặt proxy riêng:

```sh
magpie plugin options ~/.local/src/FreePiLogin6 '{"proxy":"http://proxy-host:8080"}'
```

Đây là plugin cộng đồng không chính thức, dịch ngược từ `free-pi-cli`; upstream đổi
là hỏng. Mã nguồn FreePi2API gốc nằm trong `upstream/FreePi2API/` của repo.

## Provider dùng API key

### OpenCode Zen — `opencode-zen`

**Đang bật, nhưng chỉ expose `jev-1.13-free`** (model phân loại nội bộ, không bị chặn free
tier, không hiện cho agent); 7 model free còn lại đã **429** nên bỏ khỏi danh sách expose.
Đầy đủ bằng chứng: [`zen-free.md`](zen-free.md). Muốn xoá hẳn key thì chạy
`magpie provider rm opencode-zen` (không hoàn lại được).

Phần dưới giữ làm tài liệu tham khảo, dùng lại khi Zen mở free tier cho API key:

Key lấy ở <https://opencode.ai/zen> (mục API keys), dạng `oc_…`.

```sh
magpie provider add opencode-zen oc_…
magpie provider test opencode-zen
```

Máy này: 41 model trong catalog, **1 model expose** (`jev-1.13-free`, dùng làm classifier);
40 model còn lại không picked, trong đó 7 model free bị 429 khi gọi bằng key (xem trên).

### Kilo Gateway — `kilo`

```sh
magpie provider add kilo eyJ…
magpie provider test kilo
```

353 model; repo không đưa model Kilo vào group hay agent nào — key là tuỳ chọn, dùng
khi muốn thêm model ngoài ladder. **Đang tắt** (`magpie provider off kilo`) để danh sách
model chỉ còn thứ ladder dùng; bật lại bằng `magpie provider on kilo`.

### OpenCode Zen Free — `opencode-zen-free`

**Đang tắt.** Provider này từng giữ hai rung cuối của ladder, nhưng bể free của Zen tính
theo **IP dùng chung** nên cạn và không hồi lại (429 liên tục sau hơn 40 phút) — không dùng
làm đường dự phòng được nữa. Đã `magpie provider off`; plugin vẫn cài nên bật lại được bằng
một lệnh. Xác thực bằng credential công khai dùng chung của client OpenCode (không cần tài
khoản, không cần key riêng). Bằng chứng và cách bật lại: [`zen-free.md`](zen-free.md).

```sh
magpie plugin add @magpie-community/opencode-zen-free-auth
magpie plugin add opencode-zen-freex
magpie provider on opencode-zen-free     # bật lại (setup-settings.sh đang để tắt)
magpie provider off opencode-zen-free    # tắt, giữ cấu hình — trạng thái hiện tại
```

## Thêm relay OpenAI-compatible của riêng bạn

Máy tham chiếu còn 5 provider gọi thẳng từ OpenCode (`bynara`, `kiraai`, `kiro`,
`pendraa`, `amdradeon`). Cách gọn hơn là đưa chúng vào magpie, để mọi agent dùng chung:

```sh
magpie provider add "My Relay" url=https://relay.example.com/v1 key=sk-…
magpie provider add "Own Claude" anthropic=https://gw.example.com key=sk-…   # Anthropic-compatible
magpie provider models my-relay                       # tải danh sách model
magpie provider models my-relay model-a model-b       # hoặc khai báo tay
magpie provider test my-relay
```

Sau đó model hiện ra là `my-relay/model-a`, dùng được trong group và cho mọi agent.

## Kiểm tra chung

```sh
magpie providers          # có những provider nào, model, ai đang dùng
magpie accounts           # tài khoản subscription + quota còn lại
magpie models             # toàn bộ model agent có thể chọn
magpie quota              # số dư từng key/tài khoản
magpie provider off <id>  # tạm tắt, giữ cấu hình
magpie provider rm <id>   # xoá hẳn (hỏi lại)
```
