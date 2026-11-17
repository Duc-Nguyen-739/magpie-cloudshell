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
| `free-pi` | free-pi | OAuth (plugin) | tài khoản GitHub thứ hai | `magpie provider test free-pi particle` |
| `cline` | Cline | OAuth (plugin) | tài khoản Cline | `magpie accounts` |
| `kiro` | Kiro | OAuth Google (plugin) | tài khoản Kiro | `magpie accounts` |
| `agnes` | Agnes | plugin + API key `cpk-…` | key từ `platform.agnes-ai.com` | **tắt** (`magpie provider on agnes`) |
| `kilo` | Kilo Gateway | API key `eyJ…` | key từ kilo.ai | `magpie provider test kilo` |
| `openrouter` | OpenRouter | API key `sk-or-…` | key từ openrouter.ai | `magpie provider test openrouter` |
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

### free-pi — `free-pi` (plugin, **phải vá**)

Hai plugin, cùng một upstream `api.freepi.ai`, **hai tài khoản khác nhau** — không phải
bản sao của nhau:

| Plugin | Provider id | Tài khoản trên máy này | Model expose |
|---|---|---|---|
| `magpie-freepi-auth` | `freepi` | `ducnguyenvan05-source` (Free) | 1 / 18 — `deepseek-v4.1-flash` |
| `magpie-free-pi` | `free-pi` | `Duc-Nguyen-739` (young) | 4 / 9 — `particle`, `deepseek-v4.1-flash`, `glm-5.3-flash`, `deepseek-v4-flash` |

Mỗi tài khoản có budget riêng (15.000 credits/ngày) và **một slot đồng thời riêng**: gọi
đồng thời hai provider thì cả hai trả 200, còn hai request cùng lúc trên **một** provider
thì request thứ hai nhận `429 one request at a time`. Vì vậy hai tài khoản = hai slot +
hai budget, không phải "đổi tài khoản" và không bị server chặn.

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
