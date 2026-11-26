# OpenCode + magpie — chúng nối với nhau thế nào

OpenCode không gọi thẳng WorkBuddy/AutoClaw. Nó gọi **một** provider tên `magpie`,
trỏ vào gateway local; magpie mới là chỗ biết model nào thuộc provider nào.

```
opencode    ──HTTP──▶  http://127.0.0.1:3425/v1  ──▶  group/leader  ──▶  provider thật
openchamber ──HTTP──▶  http://127.0.0.1:3425/v1  ──▶  group/leader  ──▶  provider thật
```

## magpie ghi gì vào `opencode.json`

Khi bạn chạy `magpie opencode group/leader`, magpie sửa
`~/.config/opencode/opencode.json` (bản OpenCode cũ dùng `opencode.jsonc`; giữ nguyên phần còn lại) và thêm/cập nhật:

```json
{
  "model": "magpie/group/leader",
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
        "group/leader": { "name": "Leader · routing group", "limit": { "context": 1000000, "output": 128000 }, "variants": [ … ] },
        "group/main":   { "name": "Main · routing group", … },
        "autoclaw/zai_glm-5.3-flash": { … },
        "…": {}
      }
    }
  }
}
```

- `apiKey: "magpie"` là chuỗi giả — gateway local không kiểm tra key. Đừng đổi thành key thật.
- Trên máy này (OpenCode V2) khối `providers.magpie` **không có `models`**: OpenCode
  tự hỏi gateway `GET /v1/models` rồi dựng danh sách, nên nó luôn khớp cái magpie đang
  phục vụ — hiện **95 model** = 8 `group/*` + 87 model lẻ (trong đó có `freepi/…` …
  `freepi7/…`, `nvidia/…`, `xingchi/…`). Bản OpenCode cũ (hoặc file do OpenChamber sinh)
  có thể kèm map `models` tĩnh; cả hai cách đều chạy, chỉ đừng sửa tay.
- Mỗi group có `variants` đúng bằng levels của group: `low`/`high`/`max` với phần
  lớn group, riêng `review`/`reviewplan` có `high`/`max`, và `compress` là
  `none`; gọi `magpie/group/leader#max` là chọn mức đó.
- **Đừng sửa tay khối `providers.magpie`**: lần sau magpie ghi đè. Muốn đổi thì đổi ở
  magpie (`magpie provider …`, `magpie group …`, `magpie model name …`) rồi chạy lại
  `magpie opencode …`.

OpenCode V2 tự nạp lại cấu hình khi file đổi; agent đang chạy vẫn giữ model của phiên
hiện tại — mở phiên mới.

## Provider khác trong cùng file

Máy này còn khai báo một số provider gọi thẳng, phần lớn **tắt** trong
`disabled_providers` (`pendraa`, `kenari`, `kira`, `tokenharbor`, `tokenhabor`,
`openrouter`, `kiro`, `amdradeon`, `dsh`). Các provider còn khai báo:
`bynara`, `kiraai`, `kiro`, `pendraa`, `amdradeon`, `tokenharbor`, `kira`, `dsh`,
`tokenhabor` — đây là relay/key riêng, repo không kèm key. Cách gọn hơn là đưa vào
magpie để mọi agent dùng chung — xem `docs/providers.md` mục "Thêm relay".

## Agent tự viết (leader + 6 subagent)

`~/.config/opencode/agents/` chứa bảy agent, mỗi file có frontmatter chọn model:

| File | Vai trò | Model |
|---|---|---|
| `leader.md` | primary; chốt task mode, điều phối, quyết định qua cổng. Không sửa gì; shell read-only (allowlist) | `magpie/group/leader#max` |
| `review.md` | khảo sát, brief hướng hoặc báo cáo CONSULT; viết plan STANDARD/STRICT khi được giao; chỉ ghi trong `.opencode/plans/` | `magpie/group/review` |
| `reviewplan.md` | gác hướng (`DIRECTION`), kiểm chứng/sửa minor repair, audit cuối; chỉ ghi trong `.opencode/plans/` | `magpie/group/reviewplan` |
| `coder.md` | triển khai/sửa code theo plan; không tự lên plan, không tự duyệt | `magpie/group/coder` |
| `tester.md` | coverage `functional`: AC tự động + regression chính; không sửa source, không browser | `magpie/group/tester` |
| `tester2.md` | coverage `adversarial`: biên, lỗi đầu vào, quyền, idempotency, chất lượng assertion | `magpie/group/tester-2` |
| `tester3.md` | coverage `runtime` + `ui` khi bắt buộc; lái browser chính | `magpie/group/tester-3` |

`scripts/setup-opencode.sh` mặc định chỉ cài file còn thiếu và **tự lùi model về
`magpie/group/leader`** nếu máy chưa có group/model đó. Muốn cập nhật cả file đã có:
`bash scripts/setup-opencode.sh --sync --no-mcp` — backup, giữ dòng `model:` cục bộ,
ghi atomic từng file, không đụng group/MCP. Sửa model bằng cách sửa dòng `model:`.

Leader chỉ được gọi `review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3`;
các subagent đặt `permissions: subagent resource:"*" effect: deny` — không được tự gọi
agent khác. Leader còn bị deny `read`, `glob`, `grep`, `edit`, `shell`, `webfetch`,
`websearch`, `skill`, `execute`; chỉ giữ `question`, sáu subagent và MCP đọc.

Review có shell allowlist chỉ đọc; Reviewplan/Coder/tester có deny-list best-effort cho
lệnh phá huỷ. Tester chỉ được ghi file test thuộc ownership `testerN`; `tester`/
`tester2` bị deny `chrome-devtools`, `tester3` giữ quyền lái browser. Đây là giới hạn
best-effort, **không phải sandbox**: shell vẫn chạy bằng quyền user host.

Mỗi agent có mục `## Skill`: Leader gửi `Skill: <id> (required|optional)` (hoặc
`Skill: tự chọn`, `Skill: không`) trong prompt, agent tự gọi tool `skill` trước khi
làm. Leader không tự nạp skill. Chỉ id thật sự có trong catalog của phiên mới nạp
được; skill required thiếu → `BLOCKED`, optional thiếu → cảnh báo và làm tiếp.

## Skill

Luật của bảy agent (2026-11-20): **chỉ dùng skill của repo đang làm** — các thư mục
trong `skills/` của project, khai báo ở `opencode.json` — cộng hai skill môi trường
`opencode` và `report` khi câu hỏi đúng phạm vi. **Cấm nạp skill từ thư viện magpie**
(`magpie-skills`, `banner-design`, `brand`, `design`, `slides`, `ui-styling`,
`find-skills`, `magpie-setup`, …): thư viện chỉ là nguồn để cập nhật bản mới về repo.
Hai ngoại lệ của magpie được nạp khi giao đích danh **và có trong catalog**:
`magpie-sessions` (tra lịch sử phiên) và `magpie-quota` (quota/đăng nhập).

**Availability là runtime:** `opencode api get /api/skill` trên máy này từng chỉ trả
`opencode`, `report`, `magpie-skills`, `openchamber-extensions` — không có đủ 12 skill
repo. Vì vậy prompt ghi `required`/`optional`; required thiếu là `BLOCKED`, optional
thiếu chỉ cảnh báo. Không hard-code rằng mọi project có đủ danh sách skill.

`~/.config/opencode/skills/magpie-skills` vẫn tồn tại trên máy — đó là bundle do magpie
quản lý (symlink vào `~/.config/magpie/skill-router/<hash>`) — nhưng agent không dùng;
đừng giao id trong đó. `scripts/setup-opencode.sh` **không cài skill nào**: thư viện
magpie tự hand over qua `magpie library`, còn skill của project do chính project khai
trong `opencode.json`.

Leader giữ bảng "Task → Skill repo → Giao cho" và bảng skill theo vai; `Skill: tự chọn`
chỉ mở trong đúng danh sách của vai đó. Id không khớp thì giao `Skill: không`.

## MCP server

`scripts/setup-mcp.sh` thêm bốn server vào thư viện magpie rồi ghi vào OpenCode
(và Gemini CLI, agy nếu có): `magpie-sessions`, `magpie-web-search`
(do magpie chạy, trỏ `MAGPIE_ADDR` về gateway), `cloudflare-docs` (remote) và
`chrome-devtools`. Server nào đã có thì bỏ qua; `magpie library sync` ở cuối ghi
lại nếu file agent bị sửa tay. `magpie-browser` **tắt mặc định** vì nó chỉ có
ích khi có trình duyệt thật; thêm bằng `MAGPIE_MCP_BROWSER=1`.

| MCP | Trạng thái trên máy headless | Ghi chú |
|---|---|---|
| `magpie-sessions` | ✓ dùng được | đọc lại phiên của mọi agent trên máy; cần gateway sống |
| `magpie-web-search` | ✓ dùng được | cần một search API: `magpie search add you` (miễn phí, không key, 100 lượt/ngày) |
| `cloudflare-docs` | ✓ dùng được | remote HTTP, cần mạng ra ngoài |
| `chrome-devtools` | ✓ dùng được | chạy `chrome-headless-shell` trong `~/.cache/puppeteer`, cờ `--headless --isolated --chromeArg=--no-sandbox --no-page-id-routing` |

**Tên action permission của MCP giữ dấu gạch ngang của server:** đúng là
`chrome-devtools_*` / `chrome-devtools_navigate_page`, **không** phải
`chrome_devtools_*`. Probe runtime ngày 2026-11-20 xác nhận rule underscore không
khớp và tool vẫn gọi được; rule hyphen ẩn tool khỏi cả direct tool lẫn Code Mode.
Khi thêm MCP mới, kiểm tên action bằng một phiên thử trước khi tin rule.
| `magpie-browser` | ✗ tắt | cần Chrome/Edge thật của người dùng + extension Magpie Browser đang mở; trên máy này đã `magpie library mcp off magpie-browser`. Muốn dùng: `MAGPIE_MCP_BROWSER=1 bash scripts/setup-mcp.sh` rồi `magpie library mcp on magpie-browser`, sau đó cài extension |

`chrome-devtools` trên máy headless: `setup-mcp.sh` cài
`chrome-devtools-mcp` vào `~/.local/share/chrome-devtools-mcp` (bền hơn cache
`mcp-npm`/`npx`, thứ có thể bị dọn) rồi ghi đè cục bộ bằng
`magpie library mcp here chrome-devtools …`. Entry `npx -y chrome-devtools-mcp@latest`
trong thư viện vẫn nguyên cho máy có Chrome; `magpie library sync` giữ bản `here`
trên máy này. Không có `chrome-headless-shell` thì tải bằng
`npx @puppeteer/browsers install chrome-headless-shell@stable`.

Script kiểm **file mà `chrome-devtools-mcp` tự gọi** (`/opt/google/chrome/chrome`,
channel `stable`), không kiểm `command -v google-chrome`: máy này có
`~/.local/bin/google-chrome` là symlink sang chrome-for-testing, nên phép thử theo
PATH tưởng là có Chrome trong khi mọi tool vẫn chết với
`Could not find Google Chrome executable for channel 'stable' at: /opt/google/chrome/chrome`.

Nếu sau này muốn bật `magpie-browser` trên Cloud Shell: `magpie library mcp on
magpie-browser`, rồi trong trình duyệt của bạn mở link preview mà
`magpie-headless-status` in ra → **Library → Magpie Browser → Set up the
extension…** → tải `Magpie Browser Extension.zip`, giải nén, mở
`chrome://extensions`, bật Developer mode, **Load unpacked**, chọn thư mục
`Magpie Browser Extension`. Extension nối bằng một key riêng chỉ mở được trình
duyệt (không gọi được model/MCP). Đóng Chrome là tool mất kết nối; mở lại Chrome
là tự nối. Chưa cài extension thì mọi lệnh `browser` trả “Magpie Browser isn't
connected…”.

OpenCode V2 tự nạp lại cấu hình khi file đổi (agent, command, skill, MCP); phiên
đang chạy vẫn giữ model/quyền/tool của phiên hiện tại, nên **mở phiên mới** để nhận
thay đổi. Nếu MCP không cập nhật, kiểm `opencode api get /api/mcp` rồi mở phiên mới;
chỉ restart service khi thật sự kẹt. Kiểm tra nhanh:

```sh
magpie library                 # 5 server đang bật (+ magpie-browser không gán agent)
magpie library mcp show chrome-devtools
magpie search                  # phải có ít nhất một API
```

## Kiểm tra

```sh
magpie opencode                 # model + small model + file config
magpie opencode small           # model phụ cho title/tóm tắt
opencode --version
opencode debug paths config     # nơi OpenCode đọc cấu hình
python3 scripts/check-agents.py # contract/permissions của 7 profile
python3 scripts/sync-agents.py --check
```

Trong OpenCode: `/models` phải thấy `magpie/group/leader` và các model `magpie/...`.

## Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| Model list rỗng | gateway chưa chạy | `openmagpie`, rồi `magpie healthcheck` |
| `ECONNREFUSED 127.0.0.1:3425` | magpie tắt | `magpie-headless-start` |
| Model không có trong `/models` | magpie chưa ghi lại config | `magpie opencode group/leader` |
| Đổi model mà agent không đổi | agent đọc model lúc khởi động | mở phiên mới / restart OpenCode |
| Subagent lỗi "model not found" | group riêng chưa có | chạy `bash scripts/setup-groups.sh`, rồi mở phiên mới |
| Title/tóm tắt chậm hoặc lỗi | small model để mặc định, dùng chính group/leader | ghim model nhanh: `magpie opencode small magpie/workbuddy-ai/hy4flash-free` |

Tài liệu OpenCode V2: <https://opencode.ai/v2/docs/>
