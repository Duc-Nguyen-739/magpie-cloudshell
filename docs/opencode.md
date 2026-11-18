# OpenCode + magpie — chúng nối với nhau thế nào

OpenCode không gọi thẳng WorkBuddy/AutoClaw. Nó gọi **một** provider tên `magpie`,
trỏ vào gateway local; magpie mới là chỗ biết model nào thuộc provider nào.

```
opencode    ──HTTP──▶  http://127.0.0.1:3425/v1  ──▶  group/main    ──▶  provider thật
openchamber ──HTTP──▶  http://127.0.0.1:3425/v1  ──▶  group/leader  ──▶  provider thật
```

## magpie ghi gì vào `opencode.json`

Khi bạn chạy `magpie opencode group/main`, magpie sửa
`~/.config/opencode/opencode.json` (giữ nguyên phần còn lại) và thêm/cập nhật:

```json
{
  "model": "magpie/group/main",
  "providers": {
    "magpie": {
      "name": "magpie",
      "package": "aisdk:@ai-sdk/openai-compatible",
      "compatibility": { "supportsPromptCacheKey": true },
      "settings": {
        "baseURL": "http://127.0.0.1:3425/v1",
        "apiKey": "magpie"
      },
      "models": {
        "group/main":   { "name": "Main · routing group",   "limit": { "context": 1000000, "output": 128000 }, "variants": [ … ] },
        "group/leader": { "name": "Leader · routing group", … },
        "autoclaw/zai_glm-5.3-flash": { … },
        "…": {}
      }
    }
  }
}
```

- `apiKey: "magpie"` là chuỗi giả — gateway local không kiểm tra key. Đừng đổi thành key thật.
- Danh sách `models` do magpie sinh từ provider đang có: máy này **27 model** = 8
  `group/*` + model lẻ của các provider đang bật (gồm `freepi2/deepseek-v4.1-flash`). `group/main` **không** có trong danh
  sách vì group đó đang tắt (`disabled` trong `providers.json`), dù `model` ở trên vẫn
  trỏ vào nó — bật lại bằng `magpie group on main` thì magpie ghi lại file và nó xuất
  hiện. Thêm provider mới là model mới tự hiện ra.
- Mỗi group có `variants` đúng bằng levels của group: `low`/`high`/`max` với phần
  lớn group, riêng `review`/`reviewplan` có thêm `none`; gọi `magpie/group/main#high`
  là chọn mức đó.
- **Đừng sửa tay khối `providers.magpie`**: lần sau magpie ghi đè. Muốn đổi thì đổi ở
  magpie (`magpie provider …`, `magpie group …`, `magpie model name …`) rồi chạy lại
  `magpie opencode …`.

OpenCode V2 tự nạp lại cấu hình khi file đổi; agent đang chạy vẫn giữ model của phiên
hiện tại — mở phiên mới.

## Provider khác trong cùng file

Máy này còn ba provider khai báo nhưng **đều tắt** trong `disabled_providers`:

```json
"kiraai":      { "package": "aisdk:@ai-sdk/openai-compatible", "settings": { "baseURL": "https://kiraai.vn/api/v1" } },
"takenbarbor": { … },
"dsh":         { … }
```

`kilo` cũng nằm trong `disabled_providers` vì đã dùng `kilo/reflection/beam-free` qua
magpie, không cần gọi thẳng. Đây là lựa chọn riêng (relay/key riêng), repo không kèm
key. Cách gọn hơn là đưa vào magpie để mọi agent dùng chung — xem `docs/providers.md`
mục "Thêm relay".

## Agent tự viết (leader + 6 subagent)

`~/.config/opencode/agents/` chứa bảy agent, mỗi file có frontmatter chọn model:

| File | Vai trò | Model |
|---|---|---|
| `leader.md` | primary; chỉ nhận thông tin, suy luận, quyết định và điều phối. Không đọc file, không shell, không sửa gì | `magpie/group/leader#max` |
| `review.md` | khảo sát codebase và viết plan 13 mục; chỉ ghi trong `.opencode/plans/` | `magpie/group/review` |
| `reviewplan.md` | kiểm chứng/tự sửa plan, rồi audit cuối code với plan; chỉ ghi trong `.opencode/plans/` | `magpie/group/reviewplan` |
| `coder.md` | viết code theo plan, không tự lên plan | `magpie/group/coder` |
| `tester.md` | chạy test, báo lỗi chính xác, không sửa code | `magpie/group/tester` |
| `tester2.md` | tester độc lập chạy song song; soi test rỗng, case biên, regression | `magpie/group/tester-2` |
| `tester3.md` | tester thứ ba; soi hợp đồng dữ liệu, hành vi runtime, tác dụng phụ | `magpie/group/tester-3` |

`scripts/setup-opencode.sh` copy bảy file này vào và **tự lùi model về
`magpie/group/main`** nếu máy chưa có group/model đó. Sửa model bằng cách sửa dòng
`model:`.

Leader chỉ được gọi `review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3`;
các subagent đặt `permissions: subagent resource:"*" effect: deny` — không được tự gọi
agent khác. Leader còn bị deny `read`, `glob`, `grep`, `edit`, `shell`, `webfetch`,
`websearch`; chỉ giữ `question` và sáu subagent.

## Skill dùng chung

`~/.config/opencode/skills/magpie-skills` — bundle skill do magpie quản lý (symlink vào
`~/.config/magpie/skill-router/<hash>`), trong đó có `magpie-setup`: hướng dẫn agent thao
tác magpie đúng cách. Nguồn:
[magpie-community/plugins](https://github.com/magpie-community/plugins/tree/main/skills/magpie-setup).
`scripts/setup-opencode.sh` clone bản tương đương nếu máy chưa có.

## Kiểm tra

```sh
magpie opencode                 # model + small model + file config
magpie opencode small           # model phụ cho title/tóm tắt
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
| Subagent lỗi "model not found" | group riêng chưa có | chạy `bash scripts/setup-groups.sh`, rồi mở phiên mới |
| Title/tóm tắt chậm hoặc lỗi | small model trỏ model không tồn tại | `magpie opencode small magpie/workbuddy-ai/hy4flash-free` |

Tài liệu OpenCode V2: <https://opencode.ai/v2/docs/>
