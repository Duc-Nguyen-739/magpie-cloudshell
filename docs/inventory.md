# Hiện trạng máy này — bản kiểm kê đầy đủ

Tài liệu này ghi lại **chính xác** những gì đang chạy trên máy đã dựng repo này, để
người/agent cài lại máy khác biết đích cần đạt tới. Số liệu lấy trực tiếp từ máy
(2026-11-22, magpie `0.1.4625`, OpenCode `v2.3.2`, OpenChamber `2.7.3`).

> **Model trong group không thuộc phạm vi đồng bộ.** Máy này đã đổi ladder nhiều lần;
> repo chỉ giữ ladder **mẫu** để tạo group, còn người dùng tự chọn model. Phần cần
> khớp chính xác là **settings, giá input/output, context/output, FreePi provider,
> agent, OpenCode/OpenChamber và billion-context**.

## Môi trường

| | |
|---|---|
| Máy | Google Cloud Shell, Debian, user thường (không sudo cho magpie) |
| Display | không có (headless) |
| systemd | **không có user bus** → `magpie daemon install` thất bại, phải dùng supervisor riêng |
| node | v26.13.0, qua nvm ở `/usr/local/nvm` (Cloud Shell nạp lazy) |
| npm prefix | `~/.npm-global` (mọi package global nằm trong `$HOME`) |
| `$HOME` | giữ được qua các lần restart Cloud Shell; `/usr/local` thì không |
| Dung lượng | ~825 MB trống (đã dùng 83%) — đủ cho cài lại, không đủ cài thêm nhiều package lớn |

## Cổng và tiến trình

| Cổng | Gì | Bind | Ghi chú |
|---|---|---|---|
| 3425 | magpie gateway | `127.0.0.1` | mọi agent trỏ vào đây |
| 3430 | magpie web UI | `0.0.0.0` | cần `?k=<web-key>`; Cloud Shell xem qua `https://3430-$WEB_HOST/` |
| 3000 | OpenChamber | `127.0.0.1` | UI code; gọi OpenCode service |
| 18787 | billion-context proxy | `127.0.0.1` | `/__bili/` để xem config; reload bằng POST |

Tiến trình: một supervisor (`magpie-headless`, vòng lặp bash) chạy `magpie serve
--web=0.0.0.0:3430`; OpenCode service do OpenChamber/CLI tự bật.

## Đã cài

| Thành phần | Phiên bản | Đường dẫn | Ghi chú |
|---|---|---|---|
| magpie | 0.1.4625 | `~/.local/bin/magpie` | bản terminal (`MAGPIE_CLI=1`) |
| OpenCode | v2.3.2 | `~/.opencode/bin/opencode` | cài bằng script curl |
| OpenChamber | 2.7.3 | `~/.npm-global/bin/openchamber` | npm global, `@openchamber/web` |
| billion-context | 0.1.216 | `~/.local/lib/node_modules/billion-context` | plugin shim trong `~/.config/opencode/plugins/billion-context` |
| bun (cho plugin) | 1.4.4 | `~/.cache/magpie/bun/` | magpie tự tải khi cần plugin |

Lệnh tiện dụng tự viết trong `~/.local/bin`:

| Lệnh | Việc |
|---|---|
| `openchamber` | bật magpie + OpenChamber, in 2 link **kèm key** |
| `openmagpie` (alias `openmagpei`) | bật magpie, in link kèm key |
| `magpie-headless-start/stop/status` | điều khiển supervisor |
| `magpie-headless` | chính vòng lặp supervisor (không gọi tay) |
| `magpie-finish` | chạy `finish.sh` từ bản sao trong `~/.local/share/magpie-cloudshell` |

## Provider (18 hiện trong `magpie providers` — 14 bật, 4 tắt)

`providers.json` còn record `qoder` và `antigravity`, nhưng `magpie providers` không
hiện vì thiếu plugin.

| id | Tên | Xác thực | Model expose | Trạng thái |
|---|---|---|---|---|
| `workbuddy-ai` | WorkBuddy AI | OAuth web (plugin) | 3 / 26 | **bật**; `hy4flash-free`, `deepseek-v4.1-flash-sg`, `glm-5.3-flash` |
| `autoclaw` | AutoClaw (Zhipu) | OAuth Google/z.ai (plugin 0.2.11) | 2 / 4 | **bật**; `zai_glm-5.3-flash`, `zaicoding_glm-5.3` |
| `freepi` | FreePi | OAuth (plugin npm) | 1 / 28 | **bật**; `deepseek-v4.1-flash`; 2 entry tài khoản, `routing=drain` |
| `freepi2` | FreePi2 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `huenguyen-code`, kho `~/.freepi2` |
| `freepi3` | FreePi3 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `hoangphat-coder`, kho `~/.freepi3` |
| `freepi4` | FreePi4 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `phucth2002-spec`, kho `~/.freepi4` |
| `freepi5` | FreePi5 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `ngocson-coder`, kho `~/.freepi5` |
| `freepi6` | FreePi6 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `haiquan-tbs`, kho `~/.freepi6` |
| `freepi7` | FreePi7 | OAuth (plugin riêng) | 1 / 28 | **bật**; tài khoản `thuylinh-coder`, kho `~/.freepi7` |
| `kilo` | Kilo Gateway | API key | 2 / 418 | **bật**; `particle-ai/particle-1:free`, `reflection/beam-free` |
| `openrouter` | OpenRouter | API key | 1 / 432 | **bật**; `particle-ai/particle-1:free` |
| `nvidia` | NVIDIA NIM | API key | 2 / 24 | **bật**; `nemotron-3.5-super-vl-120b-a12b`, `nemotron-3.5-lightning-30b-a3b` |
| `xingchi` | Xingchi custom | API key + endpoint riêng | 1 / 1 | **bật**; `gpt-6.1-sol` (Responses API) |
| `opencode-zen` | OpenCode Zen | API key | 1 / 48 | **bật**, chỉ expose `jev-1.13-free` làm classifier |
| `aihubmix` | AiHubMix | API key | 24 / 657 | **tắt**; model `-free` trả câu từ chối khi chưa nạp tiền |
| `copilot` | Copilot | OAuth GitHub | 1 / 24 | **tắt** |
| `agnes` | Agnes | API key | 1 / 9 | **tắt** |
| `opencode-zen-free` | OpenCode Zen Free | plugin, key công khai | 4 / 9 | **tắt**; free tier theo IP dùng chung đã cạn |

`agy-cli`, `cline`, `kiro`, `groq` **không cài** trên máy này. `scripts/plugins.sh`
cũng không cài chúng; muốn dùng thì `magpie plugin add @magpie-community/opencode-<tên>-auth`.
Group mẫu chỉ dùng model đang có.

## Plugin (12 entry — 11 plugin; `freepi` có hai bản)

```
@magpie-community/opencode-zen-free-auth@latest   opencode-zen-free
@magpie-community/opencode-workbuddy-auth@latest  workbuddy-ai, workbuddy
@magpie-community/opencode-autoclaw-auth@0.2.11   autoclaw, autoclaw-cn
github:yukiryo/magpie-plugin-agnes                agnes
magpie-freepi-auth@latest                         freepi
~/.local/src/FreePiLogin2                         freepi2
~/.local/src/FreePiLogin3                         freepi3
~/.local/src/FreePiLogin4                         freepi4
~/.local/src/FreePiLogin5                         freepi5
~/.local/src/FreePiLogin6                         freepi6
~/.local/src/FreePiLogin7                         freepi7
~/.config/magpie/plugins/node_modules/magpie-freepi-auth   freepi (bản thứ hai)
```

FreePi2–FreePi7 là sáu plugin **không cài từ npm**: repo private
`Duc-Nguyen-739/FreePiLogin2` … `FreePiLogin7`, clone về `~/.local/src/FreePiLoginN`
rồi `magpie plugin add` đường dẫn đó (bun không gửi token khi tải tarball GitHub →
404). Máy khác cần được cấp quyền đọc sáu repo đó, hoặc bỏ qua và chạy với FreePi
chính. AutoClaw đang chạy **0.2.11** (test `zai_auto` ✓ ngày 2026-11-22); 0.2.9 là
bản vàng dự phòng.

## Routing group

Máy này có 8 group tự đặt + `group/compress` + các group `auto/*`. **Ladder dưới đây
là trạng thái hiện tại, không phải yêu cầu cài đặt** — model do người dùng chọn.

| Group | stays | levels | Model hiện tại |
|---|---|---|---|
| `leader` | `turn` | `low,high,max` | `freepi6/deepseek-v4.1-flash:max` → `xingchi/gpt-6.1-sol` |
| `main` | `session` | `low,high,max` | `freepi/deepseek-v4.1-flash` → `agy-cli/gemini-3.8-flash` (thiếu provider) → `autoclaw/zai_glm-5.3-flash` → `workbuddy-ai/glm-5.3-flash`; **đang tắt** |
| `review` | `turn` | `high,max` | `freepi4/deepseek-v4.1-flash:high` |
| `reviewplan` | `turn` | `high,max` | `freepi/deepseek-v4.1-flash:high` |
| `coder` | `turn` | `low,high,max` | `freepi3/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` |
| `tester` | `turn` | `low,high,max` | `freepi2/deepseek-v4.1-flash` → `workbuddy-ai/deepseek-v4.1-flash-sg` |
| `tester-2` | `turn` | `low,high,max` | `freepi7/deepseek-v4.1-flash` → `autoclaw/zai_glm-5.3-flash` |
| `tester-3` | `turn` | `low,high,max` | `freepi5/deepseek-v4.1-flash` → `autoclaw/zai_glm-5.3-flash` |
| `compress` | `off` | `none` | `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` → `openrouter/particle-ai/particle-1:free` → `kilo/particle-ai/particle-1:free` → `workbuddy-ai/hy4flash-free` (rotate) |

Tám group tự đặt dùng `routing=order`, `effort=auto`, classifier
`opencode-zen/jev-1.13-free`; không group nào có rule. `main`/`leader`/`coder` và ba
tester mở levels `low,high,max`; `review`/`reviewplan` mở `high,max` (magpie tự mở
thêm mức khi đặt `effort=auto`). `group/compress` do người dùng tạo cho billion-context.

Các group `auto/*` do magpie tự sinh (`auto/deepseek-v4.1-flash`, `auto/gpt-6.1-sol`)
gom cùng model từ nhiều provider; `auto-beam-free` đã bị ẩn.

## Agent được magpie quản lý

| Agent | Model | File magpie sửa |
|---|---|---|
| OpenCode | `magpie/group/leader`; small model **không ghim** (`—`) | `~/.config/opencode/opencode.jsonc` |
| OpenChamber | `magpie/group/leader`, `defaultVariant: max`, `defaultAgent: leader` | `~/.config/openchamber/settings.json` |
| Gemini CLI | (auth google, không đặt model) | `~/.gemini/settings.json` |
| Antigravity CLI | — | `~/.gemini/antigravity-cli/settings.json` |
| DeepSeek Harness | CLI không có trên máy | `~/.dsh/profiles/web/cordis.patch.yml` |

## OpenCode

- Provider `magpie`: `baseURL: http://127.0.0.1:3425/v1`, `apiKey: magpie` (chuỗi giả).
  OpenCode V2 hỏi `/v1/models` và thấy **24 model** = 8 `group/*` + 16 model lẻ.
  File hiện tại không có khoá `models`.
- `model: magpie/group/leader`; small model để trống.
- `compaction.auto: false` (billion-context tự nén).
- `disabled_providers`: `pendraa`, `kenari`, `kira`, `tokenharbor`, `tokenhabor`,
  `openrouter`, `kiro`, `amdradeon`, `dsh`. Các provider gọi thẳng còn khai báo:
  `bynara`, `kiraai`, `kiro`, `pendraa`, `amdradeon` (relay/key riêng, repo không kèm).
- MCP: `cloudflare-docs`, `magpie-web-search`, `magpie-vision`, `magpie-sessions`,
  `chrome-devtools` (5 bật).
- Agent tự viết: `leader.md` (primary, `group/leader#max`), `review.md`,
  `reviewplan.md`, `coder.md`, `tester.md`, `tester2.md`, `tester3.md`.
- Skill: agent chỉ nạp skill của repo đang làm + `opencode`, `report`; cấm skill thư
  viện magpie (hai ngoại lệ `magpie-sessions`, `magpie-quota`).

## OpenChamber

`~/.config/openchamber/settings.json`:

| Khoá | Giá trị |
|---|---|
| `defaultModel` | `magpie/group/leader` |
| `defaultVariant` | `max` |
| `defaultAgent` | `leader` |
| `themeId` / `themeVariant` | `onedarkpro-dark` / `dark` |
| `fontSize` | `110` |
| `permissionDefaultMode` | `auto` |
| `lastSelectedModel` | `magpie/workbuddy-ai/deepseek-v4.1-flash-sg` |

`magpie openchamber` in ra `~/.config/openchamber/preferences.json`, nhưng file thực
tế OpenChamber đọc/ghi là `settings.json`.

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
| `imageGen` | `workbuddy-ai/hy-image-3.5` | **stale**: model không còn trong catalog WorkBuddy; script chỉ đặt nếu model tồn tại |
| `redact` | `true` | bật che dữ liệu nhạy cảm |
| `redactModelName` | `astrlink-guard` | tên model làm việc che |
| `redactKinds` | `home, ip, serial` bật; `birthday, iban, ssn, userhost` tắt | những gì bị che |
| `quotaLeft` | `true` | hiện quota còn lại trong UI |
| `trayUsageEvery` | `3` | nhịp cập nhật usage trên tray |
| `textSize` | `110` | cỡ chữ UI (khoá cũ; OpenChamber dùng `fontSize`) |
| `disabledModels` | `freepi/deepseek-v4.1-flash-1017-ultrafast` | model bị ẩn |
| `sessionReads` | `{asked: true, all: true}` | đã cho phép đọc lại phiên |
| `pluginCheckins` | `{autoclaw: true, qoder: true}` | điểm danh hằng ngày |
| `modelEfforts` | FreePi 1–7: `none…max` | magpie tự sinh theo model/level |
| `modelOutputs` | FreePi 1–7 `deepseek-v4.1-flash`: `32768` | output cap do người dùng đặt |
| `modelImages` | FreePi 1–7 `deepseek-v4.1-flash`: `true` | model nhận ảnh (vision input) |
| `modelPrices` | xem dưới | giá input/output/cache |
| `modelAPIs` | `xingchi/gpt-6.1-sol`: `responses` | API của model |

Giá model đang đặt (`magpie model prices`):

| Model | input | output | cache read | cache write |
|---|---|---|---|---|
| `*/deepseek-v4.1-flash` | 1 | 4 | 0.1 | 1.25 |
| `*/jev-1.13-free` | 0 | 0 | 0 | 0 |
| `workbuddy-ai/deepseek-v4.1-flash-sg` | 1 | 4 | 0.1 | 1.25 |
| `workbuddy-ai/glm-5.3-flash` | 1 | 4 | 0.1 | 1.25 |

Context/output của FreePi (`magpie model spec`): `1048576` input / `32768` output,
reasoning `none,minimal,low,medium,high,xhigh,max` cho cả bảy provider.

`scripts/setup-settings.sh` chỉ **thêm khoá còn thiếu**, không ghi đè giá trị đã có;
`scripts/setup-model-settings.sh` áp giá/context/output/efforts và cấu hình FreePi
(queue 32, account-concurrency 1, RPM off, `routing=drain` cho `freepi`).

## Thư viện magpie

| | |
|---|---|
| Instructions | chưa có |
| MCP servers | 5 bật → gemini, agy, opencode: `magpie-sessions`, `magpie-vision`, `magpie-web-search`, `cloudflare-docs`, `chrome-devtools`; `magpie-browser` có entry nhưng **không gán agent** (cần Chrome/Edge thật + extension) |
| Skills | 7 skill trong library: `find-skills`, `hallmark`, `impeccable`, `magpie-quota`, `magpie-sessions`, `magpie-setup`, `ui-ux-pro-max`; agent **không** nạp các skill này (trừ hai ngoại lệ `magpie-sessions`, `magpie-quota`) |
| Web search | You.com (miễn phí, không key, 100 lượt/ngày) |
| Gateway keys | chưa có |
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
~/.config/opencode/agents/              leader.md + 6 subagent
~/.config/openchamber/settings.json     OpenChamber (defaultModel/Variant/Agent)
~/.config/billion-context/billion-context.json  config nén
~/.npm-global/lib/node_modules/@openchamber/web
~/.opencode/bin/opencode
```

## Repo này tái tạo được gì

| Hạng mục | Repo | Ghi chú |
|---|---|---|
| magpie binary | ✅ | installer chính thức hoặc `--from-source` |
| 11 plugin provider | ✅ | `scripts/plugins.sh` (FreePi2…7 clone từ repo private) |
| 8 group mẫu | ✅ | `scripts/setup-groups.sh`; model do người dùng chọn, `finish.sh` không reset |
| settings.json | ✅ | chỉ thêm khoá thiếu; `visionEffort`, `redactKinds`, `disabledModels` |
| giá input/output/cache + context/output + efforts | ✅ | `scripts/setup-model-settings.sh` |
| FreePi provider (queue, slot, model, routing) | ✅ | cùng script trên |
| `opencode-zen` bật, chỉ expose `jev-1.13-free`; `opencode-zen-free` tắt | ✅ | `setup-settings.sh` |
| OpenCode + provider `magpie` | ✅ | magpie tự ghi `opencode.jsonc` |
| OpenCode/OpenChamber → `group/leader` | ✅ | `setup-agents.sh` (lùi `group/main` nếu thiếu) |
| `billion-context` plugin + config | ✅ | `scripts/setup-billion-context.sh` + `config/billion-context.json`; `group/compress` do user tạo |
| 7 agent | ✅ | `config/agents/`; mỗi agent có mục `## Skill` |
| skill thư viện | ➖ | thêm ở trang Library của magpie; agent **không** nạp |
| OpenChamber + cổng 3000 | ✅ | `install-openchamber.sh` |
| `openchamber` / `openmagpie` + link kèm key | ✅ | wrapper + supervisor |
| Tự bật ở shell đầu tiên | ✅ | khối `.bashrc` |
| Provider account/key | ➖ | **bạn đăng nhập** (phần duy nhất) |
| Provider gọi thẳng trong OpenCode (`bynara`, `kiraai`, `kiro`, `pendraa`, `amdradeon`, `tokenharbor`, `dsh`) | ❌ | key/relay riêng của chủ máy, không đưa vào repo |
| Gemini CLI / Antigravity CLI | ➖ | tuỳ chọn, repo không cài |
| Profiles `before-*` | ❌ | snapshot tạm thời, không cần |
| Theme/notification của OpenChamber | ➖ | chọn trong UI |

## Bản đồ kết nối

```
OpenCode    ─→ group/leader          ─┐
OpenChamber ─→ group/leader          ─┤
Leader      ─→ group/leader          ─┼─→ gateway 127.0.0.1:3425
Review      ─→ group/review          ─┤
Reviewplan  ─→ group/reviewplan      ─┤
Coder       ─→ group/coder           ─┤
Tester      ─→ group/tester          ─┤
Tester 2    ─→ group/tester-2        ─┤
Tester 3    ─→ group/tester-3        ─┤
billion-context ─→ group/compress    ─┘

Provider theo group (hiện tại):
  leader      freepi6, xingchi
  review      freepi4
  reviewplan  freepi
  coder       freepi3, workbuddy-ai
  tester      freepi2, workbuddy-ai
  tester-2    freepi7, autoclaw
  tester-3    freepi5, autoclaw
  compress    nvidia, openrouter, kilo, workbuddy-ai
```

Mỗi group tự đặt · classifier ─→ `opencode-zen/jev-1.13-free` (chỉ model này, không
vào ladder). `opencode-zen` (API key) **đang bật** nhưng chỉ expose `jev-1.13-free`;
`opencode-zen-free` (plugin) **đang tắt** — xem [`zen-free.md`](zen-free.md).
