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
| `opencode-zen` | OpenCode Zen | API key | key `oc_…` | đang **bật**, chỉ expose `jev-1.13-free` (classifier) |
| `kilo` | Kilo Gateway | API key | key `eyJ…` | `magpie provider test kilo` |
| `opencode-zen-free` | OpenCode Zen Free | plugin (key công khai) | không | đang **tắt** — hạn mức theo IP dùng chung |

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
khi muốn thêm model ngoài ladder.

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
