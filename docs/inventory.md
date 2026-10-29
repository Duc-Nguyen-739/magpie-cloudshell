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
| `opencode-zen` | OpenCode Zen | API key | 28 (20 không expose) | tắt (`magpie provider off opencode-zen`); free tier qua API key bị chặn |
| `kilo` | Kilo Gateway | API key | 353 | đã có key |
| `opencode-zen-free` | OpenCode Zen Free | plugin, key công khai | 8 | **đang bật** |

## Plugin (6)

```
@magpie-community/opencode-autoclaw-auth    autoclaw, autoclaw-cn
@magpie-community/opencode-workbuddy-auth   workbuddy-ai, workbuddy
@magpie-community/opencode-qoder-auth       qoder, qoder-cn, qwenwork, qwenwork-enterprise
@magpie-community/opencode-zcode-auth       zcode, zcode-cn (chưa đăng nhập)
@magpie-community/opencode-zen-free-auth    opencode-zen-free
opencode-zen-freex                          phục vụ opencode-zen-free
```

## Routing group (4)

| | `group/main` | `group/code` |
|---|---|---|
| Dùng cho | chat thường ngày | việc code |
| routing | `order` | `order` |
| stays | `session` | `turn` |
| levels | `low,high,max` | `low,high,max` |
| effort | `auto` | `auto` |
| classifier | `workbuddy-ai/hy3` | `workbuddy-ai/hy3` |
| rule | ảnh → deepseek-v4.1-flash; compact → glm-5.3-flash | 4 intent + ảnh (test → zaicoding_glm) |
| agent dùng | Leader, OpenCode, OpenChamber | Coder |

Hai group còn lại không rule, không classifier:

| | `group/glm` | `group/deepseek` |
|---|---|---|
| Dùng cho | Tester | dự phòng (không agent nào trỏ) |
| routing / stays | `order` / `auto` | `order` / `turn` |
| levels | `low,high,max` | `low,high,max` |
| model | 7 model GLM, `zaicoding_glm-5.3` đầu | 3 endpoint DeepSeek |

Thứ tự 8 model trong `main` và `code` (DeepSeek trước, GLM sau, OpenCode Zen Free cuối):

```
1 workbuddy-ai/deepseek-v4.1-flash
2 workbuddy-ai/deepseek-v4.1-flash-sg
3 autoclaw/zaicoding_glm-5.3
4 autoclaw/zai_glm-5.3-flash
5 workbuddy-ai/glm-5.3
6 workbuddy-ai/glm-5.3-flash
7 opencode-zen-free/deepseek-v4.1-flash-free
8 opencode-zen-free/glm-5.3-flash-free
```

## Agent được magpie quản lý

| Agent | Model | File magpie sửa |
|---|---|---|
| OpenCode | `magpie/group/main` | `~/.config/opencode/opencode.jsonc` |
| OpenChamber | `magpie/group/main` | `~/.config/openchamber/preferences.json` |
| Gemini CLI | (auth google, không đặt model) | `~/.gemini/settings.json` |
| Antigravity CLI | — | `~/.gemini/antigravity-cli/settings.json` |
| Pi | CLI không có | `~/.pi/agent/settings.json` |

## OpenCode

- Provider `magpie`: `@ai-sdk/openai-compatible`, `baseURL: http://127.0.0.1:3425/v1`,
  `apiKey: magpie` (chuỗi giả — gateway local không cần key thật), **70 model** do magpie sinh.
- Ngoài magpie còn 5 provider gọi thẳng (không qua gateway): `bynara`, `kiraai`, `kiro`,
  `pendraa`, `amdradeon` — đây là lựa chọn riêng của chủ máy, repo chỉ mô tả cách thêm,
  không kèm key.
- `disabled_providers`: pendraa, kenari, kira, tokenharbor, tokenhabor, openrouter, kiro, amdradeon.
- Agent tự viết: `~/.config/opencode/agents/leader.md` (primary, `group/main#high`),
  `coder.md` (DeepSeek, `group/code`), `tester.md` (GLM zaicoding, `group/glm`).
- Skill: `~/.config/opencode/skills/magpie-setup` → symlink vào thư viện magpie.

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
| `vision` | `workbuddy-ai/deepseek-v4.1-flash` | model đọc ảnh cho tool vision |
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
| 2 routing group | ✅ | **giống hệt** cấu hình máy này (đã so JSON) |
| settings.json | ✅ | chỉ thêm khoá thiếu |
| `opencode-zen-free` bật, `opencode-zen` tắt | ✅ | `setup-settings.sh` |
| OpenCode + provider `magpie` | ✅ | magpie tự ghi `opencode.jsonc` |
| 3 agent `leader`, `coder`, `tester` | ✅ | `config/agents/` |
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
OpenCode ─┐
          ├─→ magpie gateway 127.0.0.1:3425 ─→ group/main ─┬─→ workbuddy-ai (OAuth)
OpenChamber┘                                              ├─→ autoclaw     (OAuth)
                                                          ├─→ qoder        (OAuth)
Gemini CLI ─→ (magpie đặt auth) ──────────────────────────┤
                                                          ├─→ opencode-zen-free (plugin)
                                                          └─→ kilo         (API key)
```

`opencode-zen` (API key) **đang tắt**: free tier qua API key bị chặn — xem
[`zen-free.md`](zen-free.md).
