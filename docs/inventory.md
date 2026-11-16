# Hiện trạng máy này — bản kiểm kê đầy đủ

Tài liệu này ghi lại **chính xác** những gì đang chạy trên máy đã dựng repo này, để
người/agent cài lại máy khác biết đích cần đạt tới. Số liệu lấy trực tiếp từ máy
(2026-10-27, magpie 0.1.1763).

## Môi trường

| | |
|---|---|
| Máy | Google Cloud Shell, Debian, user thường (không sudo cho magpie) |
| Display | không có (headless) |
| systemd | **không có user bus** → `magpie daemon install` thất bại, phải dùng supervisor riêng |
| node | v24.22.1, qua nvm ở `/usr/local/nvm` (Cloud Shell nạp lazy) |
| npm prefix | `~/.npm-global` (mọi package global nằm trong `$HOME`) |
| `$HOME` | giữ được qua các lần restart Cloud Shell; `/usr/local` thì không |

## Cổng và tiến trình

| Cổng | Gì | Bind | Ghi chú |
|---|---|---|---|
| 3425 | magpie gateway | `127.0.0.1` | mọi agent trỏ vào đây |
| 3430 | magpie web UI | `0.0.0.0` | cần `?k=<web-key>`; Cloud Shell xem qua `https://3430-$WEB_HOST/` |
| 3000 | OpenChamber | `127.0.0.1` | UI code; gọi OpenCode service |

Tiến trình: một supervisor (`magpie-headless`, vòng lặp bash) chạy `magpie serve --web=0.0.0.0:3430`,
và OpenCode service do OpenChamber/CLI tự bật.

## Đã cài

| Thành phần | Phiên bản | Đường dẫn | Ghi chú |
|---|---|---|---|
| magpie | 0.1.1763 | `~/.local/bin/magpie` (55 MB) | bản terminal (`MAGPIE_CLI=1`) |
| OpenCode | v2.2.0 | `~/.opencode/bin/opencode` | cài bằng script curl |
| OpenChamber | 2.5.2 | `~/.npm-global/bin/openchamber` | npm global, `@openchamber/web` |
| bun (cho plugin) | 1.4.4 | `~/.cache/magpie/bun/` | magpie tự tải khi cần plugin |

Lệnh tiện dụng tự viết trong `~/.local/bin`:

| Lệnh | Việc |
|---|---|
| `openchamber` | bật magpie + OpenChamber, in 2 link **kèm key** |
| `openmagpie` (alias `openmagpei`) | bật magpie, in link kèm key |
| `magpie-headless-start/stop/status` | điều khiển supervisor |
| `magpie-headless` | chính vòng lặp supervisor (không gọi tay) |

## Provider (6)

| id | Tên | Xác thực | Model | Trạng thái |
|---|---|---|---|---|
| `autoclaw` | AutoClaw (Zhipu) | OAuth Google/z.ai (plugin) | 4 | 3 tài khoản đã đăng nhập |
| `workbuddy-ai` | WorkBuddy AI | OAuth web (plugin) | 26 | 3 tài khoản, 1 đang dùng |
| `qoder` | Qoder | OAuth web (plugin) | 2 | đã đăng nhập |
| `opencode-zen` | OpenCode Zen | API key | 41 (1 expose: `jev-1.13-free`) | **bật**, chỉ expose `jev-1.13-free` làm classifier; free tier qua API key bị chặn |
| `kilo` | Kilo Gateway | API key | 353 | đã có key |
| `opencode-zen-free` | OpenCode Zen Free | plugin, key công khai | 8 | **đang tắt** (`magpie provider off opencode-zen-free`); plugin vẫn cài, bật lại được |

## Plugin (6)

```
@magpie-community/opencode-autoclaw-auth    autoclaw, autoclaw-cn
@magpie-community/opencode-workbuddy-auth   workbuddy-ai, workbuddy
@magpie-community/opencode-qoder-auth       qoder, qoder-cn, qwenwork, qwenwork-enterprise
@magpie-community/opencode-zcode-auth       zcode, zcode-cn (chưa đăng nhập)
@magpie-community/opencode-zen-free-auth    opencode-zen-free
opencode-zen-freex                          phục vụ opencode-zen-free
```

## Routing group (6)

| Group | Dùng cho | stays | levels | Model (thứ tự fallback) |
|---|---|---|---|---|
| `main` | OpenCode — chat thường ngày | `session` | `low,high,max` | `freepi/deepseek-v4.1-flash` → `workbuddy-ai/hy4flash-free` → `agy-cli/gemini-3.8-flash` → `autoclaw/zai_glm-5.3-flash` → `workbuddy-ai/glm-5.3-flash` |
| `leader` | OpenChamber — plan + điều phối | `turn` | `low,high,max` | `workbuddy-ai/deepseek-v4.1-flash-sg:max` → `agy-cli/claude-opus-4-6-thinking` |
| `coder` | viết code theo plan | `turn` | `low,high,max` | `freepi/deepseek-v4.1-flash:high` |
| `tester` | chạy test, báo lỗi | `turn` | `high` | `freepi/deepseek-v4.1-flash:high` → `agnes/agnes-3.0-flash:high` → `autoclaw/zai_glm-5.3-flash` |
| `tester-2` | tester độc lập, chạy song song | `turn` | `high` | `workbuddy-ai/hy4flash-free:high` → `kilo/reflection/beam-free:high` → `agy-cli/gemini-3.8-flash:high` → `agnes/agnes-3.0-flash:high` → `autoclaw/zai_glm-5.3-flash` |
| `tester-3` | tester thứ ba, soi hợp đồng dữ liệu | `turn` | `high` | `agy-cli/gemini-3.8-flash:high` → `autoclaw/zai_glm-5.3-flash` → `workbuddy-ai/hy4flash-free:high` |

Cả sáu dùng `routing=order`, `effort=auto`, classifier `opencode-zen/jev-1.13-free`;
**không group nào có rule**. `main`, `leader`, `coder` mở levels `low,high,max`; ba tester
chỉ `high`.

`autoclaw/zai_auto` và `autoclaw/zai_auto-fast` không nằm trong group nào vì chỉ có 200K
context — mọi member còn lại đều khai 1M. `workbuddy-ai/hy3` (192K) đã bị provider bỏ
khỏi danh sách expose, nên không còn trong group. `autoclaw/zaicoding_glm-5.3` đã rời
ladder (quota coding free hay 429); group vẫn chạy nhờ `autoclaw/zai_glm-5.3-flash`.

## Agent được magpie quản lý

| Agent | Model | File magpie sửa |
|---|---|---|
| OpenCode | `magpie/group/main`, small `magpie/workbuddy-ai/hy4flash-free` | `~/.config/opencode/opencode.json` |
| OpenChamber | `magpie/group/leader` | `~/.config/openchamber/preferences.json` |
| Gemini CLI | (auth google, không đặt model) | `~/.gemini/settings.json` |
| Antigravity CLI | — | `~/.gemini/antigravity-cli/settings.json` |
| Pi | CLI không có | `~/.pi/agent/settings.json` |

## OpenCode

- Provider `magpie`: khai trong `providers` của `opencode.json`, `baseURL:
  http://127.0.0.1:3425/v1`, `apiKey: magpie` (chuỗi giả — gateway local không cần key
  thật), **16 model** do magpie sinh: 6 `group/*` + 10 model lẻ.
- Ba provider gọi thẳng còn khai báo — `kiraai`, `takenbarbor`, `dsh` — đều nằm trong
  `disabled_providers`, cùng `kilo` (đã có `kilo/reflection/beam-free` qua magpie nên
  không gọi thẳng nữa).
- Agent tự viết trong `~/.config/opencode/agents/`: `leader.md` (primary,
  `group/leader#max`), `coder.md` (`group/coder`), `tester.md` (`group/tester`),
  `tester2.md` (`group/tester-2`), `tester3.md` (`group/tester-3`).
- Skill: `~/.config/opencode/skills/magpie-skills` → symlink vào skill router của magpie;
  `magpie-setup` nằm trong bundle đó.

## Thư viện magpie

| | |
|---|---|
| Instructions | chưa có |
| MCP servers | chưa có (Gemini CLI có 3 MCP riêng: data-agent-kit, notebooks, visualization) |
| Skills | `magpie-setup` → gemini, agy, opencode, dsh |
| Web search | chưa cấu hình |
| Gateway keys | chưa có (chưa chia sẻ ra máy khác) |
| Profiles | `before-setup`, `before-2groups`, `before-groups`, `before-jev` |

## Đường dẫn quan trọng

```
~/.local/bin/magpie                     binary
~/.local/bin/{openchamber,openmagpie}   wrapper in link kèm key
~/.local/bin/magpie-headless*           supervisor
~/.config/magpie/                       provider, group, plugin, auth (600), web-key
~/.config/magpie/library/               skill dùng chung
~/.local/state/magpie/headless.log      log supervisor
~/.config/opencode/opencode.jsonc       OpenCode config (magpie ghi)
~/.config/opencode/agents/              leader.md, coder.md, tester.md
~/.npm-global/lib/node_modules/@openchamber/web
~/.opencode/bin/opencode
```

## Settings của magpie (`settings.json`)

| Khoá | Giá trị | Ý nghĩa |
|---|---|---|
| `theme` | `dark` | giao diện tối |
| `lang` | `system` | theo ngôn ngữ hệ thống |
| `tray` | `panel` | menu bar mở panel |
| `currency` | `usd` | giá hiển thị bằng USD |
| `updateEvery` | `360` | kiểm tra cập nhật mỗi 360 phút |
| `vision` | `workbuddy-ai/hy4flash-free` | model đọc ảnh cho tool vision |
| `visionEffort` | `max` | mức reasoning cho vision |
| `imageGen` | `workbuddy-ai/hy-image-3.5` | model tạo ảnh |
| `trayUsageEvery` | `3` | nhịp cập nhật usage trên tray |
| `textSize` | `110` | cỡ chữ UI |
| `pluginCheckins.autoclaw` | `true` | điểm danh AutoClaw hằng ngày |

`scripts/setup-settings.sh` chỉ **thêm khoá còn thiếu**, không ghi đè giá trị đã có; và chỉ
đặt `vision`/`imageGen` khi model tương ứng đã tồn tại (tức sau khi đăng nhập WorkBuddy).

## Repo này tái tạo được gì

| Hạng mục | Repo | Ghi chú |
|---|---|---|
| magpie binary | ✅ | installer chính thức hoặc `--from-source` (clone yetone/magpie) |
| 6 plugin provider | ✅ | `scripts/plugins.sh` |
| 6 routing group | ✅ | **giống hệt** cấu hình máy này |
| settings.json | ✅ | chỉ thêm khoá thiếu |
| `opencode-zen` bật, chỉ expose `jev-1.13-free`; `opencode-zen-free` tắt | ✅ | `setup-settings.sh` |
| OpenCode + provider `magpie` | ✅ | magpie tự ghi `opencode.json` |
| 5 agent `leader`, `coder`, `tester`, `tester2`, `tester3` | ✅ | `config/agents/` |
| skill `magpie-setup` | ✅ (OpenCode) | Gemini/Antigravity: thêm qua Library page nếu muốn |
| OpenChamber + cổng 3000 | ✅ | `install-openchamber.sh` |
| `openchamber` / `openmagpie` + link kèm key | ✅ | wrapper + supervisor |
| Tự bật ở shell đầu tiên | ✅ | khối `.bashrc` |
| Provider account/key | ➖ | **bạn đăng nhập** (phần duy nhất) |
| 5 provider gọi thẳng trong OpenCode (`bynara`, `kiraai`, `kiro`, `pendraa`, `amdradeon`) | ❌ | key riêng của chủ máy, không đưa vào repo; cách thêm: `docs/providers.md` |
| Gemini CLI / Antigravity CLI | ➖ | tuỳ chọn, repo không cài |
| Profiles `before-*` | ❌ | snapshot tạm thời, không cần |
| Theme/notification của OpenChamber | ➖ | chọn trong UI (10 giây) |

## Bản đồ kết nối

```
OpenCode    ─→ group/main     ─┐
OpenChamber ─→ group/leader   ─┤
Leader      ─→ group/leader   ─┼─→ gateway 127.0.0.1:3425
Coder       ─→ group/coder    ─┤      ├─→ freepi, workbuddy-ai, agy-cli
Tester      ─→ group/tester   ─┤      ├─→ autoclaw, agnes, kilo
Tester 2    ─→ group/tester-2 ─┤      └─→ opencode-zen (classifier)
Tester 3    ─→ group/tester-3 ─┘
```

Mỗi group · classifier ─→ `opencode-zen/jev-1.13-free` (chỉ model này, không vào ladder)

`opencode-zen` (API key) **đang bật** nhưng chỉ expose `jev-1.13-free` làm classifier;
`opencode-zen-free` (plugin) **đang tắt**: free tier qua API key bị chặn, đường plugin cạn
theo IP dùng chung — xem [`zen-free.md`](zen-free.md).
