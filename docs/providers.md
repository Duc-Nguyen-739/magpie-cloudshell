# Provider — từng cái một

magpie gom mọi provider về một gateway `127.0.0.1:3425`. Agent chỉ thấy một provider
tên `magpie`; provider thật nằm sau gateway. Vì vậy thêm/bớt provider **không cần
sửa cấu hình agent** — magpie tự ghi lại danh sách model.

## Bảng tổng hợp

| id | Tên | Xác thực | Cần gì từ bạn | Kiểm tra |
|---|---|---|---|---|
| `autoclaw` | AutoClaw (Zhipu) | OAuth Google/z.ai (plugin) | tài khoản Google hoặc z.ai | `magpie accounts` |
| `workbuddy-ai` | WorkBuddy AI | OAuth web (plugin) | tài khoản WorkBuddy | `magpie accounts` |
| `qoder` | Qoder | OAuth web (plugin) | tài khoản Qoder | `magpie accounts` |
| `opencode-zen` | OpenCode Zen | API key | key `oc_…` | đang **tắt** — free tier qua API key bị chặn |
| `kilo` | Kilo Gateway | API key | key `eyJ…` | `magpie provider test kilo` |
| `opencode-zen-free` | OpenCode Zen Free | plugin (key công khai) | không | đang **bật**, dùng cho ladder |

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

### ZCode — `zcode` (tuỳ chọn)

```sh
magpie plugin add @magpie-community/opencode-zcode-auth
magpie plugin login zcode
```

Máy tham chiếu có cài nhưng **chưa đăng nhập**; không nằm trong group nào.

## Provider dùng API key

### OpenCode Zen — `opencode-zen`

**Hiện đang tắt.** Free tier qua API key trả **429** cho mọi model free ("Free usage limit
reached…"), và hạn mức đó không có cửa sổ reset — chờ vô ích. Vì vậy provider này đã bị
`magpie provider off` (key vẫn giữ, không xoá) và không còn model nào trong ladder; hai
rung OpenCode đã chuyển sang `opencode-zen-free`. Đầy đủ bằng chứng và cách hoàn tác:
[`zen-free.md`](zen-free.md). Muốn xoá hẳn key thì chạy `magpie provider rm opencode-zen`
(không hoàn lại được).

Phần dưới giữ làm tài liệu tham khảo, dùng lại khi Zen mở free tier cho API key:

Key lấy ở <https://opencode.ai/zen> (mục API keys), dạng `oc_…`.

```sh
magpie provider add opencode-zen oc_…
magpie provider test opencode-zen
```

Máy tham chiếu: 28 model, nhưng 20 model **không expose** cho agent (chỉ dùng nội bộ
được, ví dụ classifier `opencode-zen/jev-1.13-free`); 8 model hiện ra, tất cả đều là model
free — và chúng bị 429 khi gọi bằng key (xem trên).

### Kilo Gateway — `kilo`

```sh
magpie provider add kilo eyJ…
magpie provider test kilo
```

353 model; repo không đưa model Kilo vào group hay agent nào — key là tuỳ chọn, dùng
khi muốn thêm model ngoài ladder.

### OpenCode Zen Free — `opencode-zen-free`

Provider đang dùng cho ladder: 8 model free, **bật**, xác thực bằng credential công khai
dùng chung của client OpenCode (không cần tài khoản, không cần key riêng). Hai rung cuối của
`group/main`/`group/code` là `opencode-zen-free/deepseek-v4.1-flash-free` và
`opencode-zen-free/glm-5.3-flash-free`; classifier của hai group là
`opencode-zen-free/nemotron-3.5-lightning-free`. `group/glm` và `group/deepseek` cũng để
model của provider này ở cuối. Vì sao chọn đường này thay vì API key: [`zen-free.md`](zen-free.md).

```sh
magpie plugin add @magpie-community/opencode-zen-free-auth
magpie plugin add opencode-zen-freex
magpie provider on opencode-zen-free     # scripts/setup-settings.sh làm việc này
magpie provider off opencode-zen-free    # tắt tạm, giữ cấu hình
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
