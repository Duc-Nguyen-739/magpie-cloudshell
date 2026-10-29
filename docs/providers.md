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
| `opencode-zen` | OpenCode Zen | API key | key `oc_…` | `magpie provider test opencode-zen` |
| `kilo` | Kilo Gateway | API key | key `eyJ…` | `magpie provider test kilo` |
| `opencode-zen-free` | OpenCode Zen Free | plugin (key công khai) | không | đang **tắt** |

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

Key lấy ở <https://opencode.ai/zen> (mục API keys), dạng `oc_…`.

```sh
magpie provider add opencode-zen oc_…
magpie provider test opencode-zen
```

Máy tham chiếu: 28 model, nhưng 20 model **không expose** cho agent (chỉ dùng nội bộ
được, ví dụ làm classifier `opencode-zen/jev-1.13-free`); 8 model hiện ra, trong đó có
`opencode-zen/deepseek-v4.1-flash-free` và `opencode-zen/glm-5.3-flash-free` nằm cuối
ladder của group.

### Kilo Gateway — `kilo`

```sh
magpie provider add kilo eyJ…
magpie provider test kilo
```

353 model; repo không đưa model Kilo vào group hay agent nào — key là tuỳ chọn, dùng
khi muốn thêm model ngoài ladder.

### OpenCode Zen Free — `opencode-zen-free`

Do plugin cung cấp, đăng nhập bằng key công khai, không cần tài khoản:

```sh
magpie plugin add @magpie-community/opencode-zen-free-auth
magpie plugin add opencode-zen-freex
magpie provider off opencode-zen-free    # máy tham chiếu để TẮT
magpie provider on  opencode-zen-free    # bật nếu muốn thêm model free
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
