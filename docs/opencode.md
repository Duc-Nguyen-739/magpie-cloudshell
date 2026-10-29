# OpenCode + magpie — chúng nối với nhau thế nào

OpenCode không gọi thẳng WorkBuddy/AutoClaw. Nó gọi **một** provider tên `magpie`,
trỏ vào gateway local; magpie mới là chỗ biết model nào thuộc provider nào.

```
opencode  ──HTTP──▶  http://127.0.0.1:3425/v1  ──▶  group/main  ──▶  provider thật
```

## magpie ghi gì vào `opencode.jsonc`

Khi bạn chạy `magpie opencode group/main`, magpie sửa `~/.config/opencode/opencode.jsonc`
(giữ nguyên comment, thứ tự, định dạng) và thêm/cập nhật:

```jsonc
{
  "model": "magpie/group/main",
  "provider": {
    "magpie": {
      "name": "magpie",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://127.0.0.1:3425/v1",
        "apiKey": "magpie"
      },
      "models": {
        "group/main": { "name": "Main", ... },
        "group/code": { "name": "Code", ... },
        "autoclaw/zai_auto": { ... },
        "...": {}
      }
    }
  }
}
```

- `apiKey: "magpie"` là chuỗi giả — gateway local không kiểm tra key. Đừng đổi thành key thật.
- Danh sách `models` do magpie sinh từ provider đang có: thêm provider mới là model mới
  tự hiện ra (máy tham chiếu: **70 model**).
- **Đừng sửa tay khối `provider.magpie`**: lần sau magpie ghi đè. Muốn đổi thì đổi ở magpie
  (`magpie provider …`, `magpie group …`, `magpie model name …`) rồi chạy lại lệnh `magpie opencode …`.

OpenCode V2 tự nạp lại cấu hình khi file đổi; agent đang chạy vẫn giữ model của phiên
hiện tại — mở phiên mới.

## Provider khác trong cùng file

Máy tham chiếu còn 5 provider **gọi thẳng**, không qua magpie:

```jsonc
"bynara":    { "npm": "@ai-sdk/openai-compatible", "options": { "baseURL": "https://router.bynara.id/v1" },  "models": { … } },
"kiraai":    { … "https://kiraai.vn/api/v1" },
"kiro":      { … "https://api.xkiro.com/v1" },
"pendraa":   { … "https://api.pendra.ai/api/v1" },
"amdradeon": { … "https://developer.amd.com.cn/radeon/api/v1" }
```

Đây là lựa chọn riêng (relay/key riêng), repo không kèm key. Cách gọn hơn là đưa vào
magpie để mọi agent dùng chung — xem `docs/providers.md` mục "Thêm relay".

## Agent tự viết (leader, coder, tester)

`~/.config/opencode/agents/` chứa ba agent tự viết, mỗi file có frontmatter chọn model:

| File | Vai trò | Model |
|---|---|---|
| `leader.md` | primary; viết plan kỹ thuật, giao Coder/Tester, review và duyệt | `magpie/group/main#high` |
| `coder.md` | viết code theo plan của Leader, không tự lên plan | `magpie/group/code` |
| `tester.md` | chạy test, báo lỗi chính xác, không sửa code | `magpie/group/glm` |

`scripts/setup-opencode.sh` copy ba file này vào và **tự lùi model về `magpie/group/main`**
nếu máy chưa có model/group đó. Sửa model bằng cách sửa dòng `model:`.

Leader chỉ được gọi `coder` và `tester`; Coder/Tester đặt
`permissions: subagent resource:"*" effect: deny` — không được tự gọi agent khác.

## Skill dùng chung

`~/.config/opencode/skills/magpie-setup` — skill hướng dẫn agent thao tác magpie đúng cách
(nguồn: [magpie-community/plugins](https://github.com/magpie-community/plugins/tree/main/skills/magpie-setup)).
Trên máy tham chiếu nó là symlink vào `~/.config/magpie/library/skills/magpie-setup` do
magpie quản lý; `scripts/setup-opencode.sh` copy bản tương đương nếu bạn không dùng Library.

## Kiểm tra

```sh
magpie opencode                 # model + file config
opencode --version
opencode debug paths config     # nơi OpenCode đọc cấu hình
```

Trong OpenCode: `/models` phải thấy `magpie/group/main` và các model `magpie/...`.

## Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| Model list rỗng | gateway chưa chạy | `openmagpie`, rồi `magpie healthcheck` |
| `ECONNREFUSED 127.0.0.1:3425` | magpie tắt | `magpie-headless-start` |
| Model không có trong `/models` | magpie chưa ghi lại config | `magpie opencode group/main` |
| Đổi model mà agent không đổi | agent đọc model lúc khởi động | mở phiên mới / restart OpenCode |
| Subagent lỗi "model not found" | model riêng chưa có provider | sửa `model:` trong file agent, hoặc thêm provider |

Tài liệu OpenCode V2: <https://opencode.ai/v2/docs/>
