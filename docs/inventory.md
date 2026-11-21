# Hiện trạng máy này — bản kiểm kê đầy đủ

Tài liệu này ghi lại **chính xác** những gì đang chạy trên máy đã dựng repo này, để
người/agent cài lại máy khác biết đích cần đạt tới. Số liệu lấy trực tiếp từ máy
(2026-11-17, magpie 0.1.4334).

## Môi trường

| | |
|---|---|
| Máy | Google Cloud Shell, Debian, user thường (không sudo cho magpie) |
| Display | không có (headless) |
| systemd | **không có user bus** → `magpie daemon install` thất bại, phải dùng supervisor riêng |
| node | v26.13.0, qua nvm ở `/usr/local/nvm` (Cloud Shell nạp lazy) |
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
| magpie | 0.1.4334 | `~/.local/bin/magpie` (88 MB) | bản terminal (`MAGPIE_CLI=1`) |
| OpenCode | v2.3.0 | `~/.opencode/bin/opencode` | cài bằng script curl |
| OpenChamber | 2.7.2 | `~/.npm-global/bin/openchamber` | npm global, `@openchamber/web` |
| bun (cho plugin) | 1.4.4 | `~/.cache/magpie/bun/` | magpie tự tải khi cần plugin |

Lệnh tiện dụng tự viết trong `~/.local/bin`:

| Lệnh | Việc |
|---|---|
| `openchamber` | bật magpie + OpenChamber, in 2 link **kèm key** |
| `openmagpie` (alias `openmagpei`) | bật magpie, in link kèm key |
| `magpie-headless-start/stop/status` | điều khiển supervisor |
| `magpie-headless` | chính vòng lặp supervisor (không gọi tay) |

## Provider (21 hiện trong `magpie providers` — 17 bật, 4 tắt)

`providers.json` còn record `qoder` và `antigravity`, nhưng `magpie providers` không
hiện vì thiếu plugin trên máy này.

| id | Tên | Xác thực | Model expose | Trạng thái |
|---|---|---|---|---|
| `workbuddy-ai` | WorkBuddy AI | OAuth web (plugin) | 3 / 26 | **bật**; expose `deepseek-v4.1-flash-sg`, `glm-5.3-flash`, `hy4flash-free` |
| `autoclaw` | AutoClaw (Zhipu) | OAuth Google/z.ai (plugin) | 2 / 4 | **bật**; `zai_glm-5.3-flash`, `zaicoding_glm-5.3` |
| `freepi` | FreePi | OAuth (plugin) | 1 / 24 | **bật**; `deepseek-v4.1-flash`, **một request tại một thời điểm** |
| `freepi2` | FreePi2 | OAuth (plugin riêng) | 1 / 24 | **bật**; tài khoản thứ ba, repo private `Duc-Nguyen-739/FreePiLogin2`, kho `~/.freepi2` + session id riêng; cài bằng clone + `magpie plugin add <thư mục>` — `docs/providers.md` |
| `freepi3` | FreePi3 | OAuth (plugin riêng) | 1 / 24 | **bật**; tài khoản thứ tư, repo private `Duc-Nguyen-739/FreePiLogin3`, kho `~/.freepi3` — `docs/freepi3.md` |
| `freepi4` | FreePi4 | OAuth (plugin riêng) | 1 / 24 | **bật**; tài khoản thứ năm, repo private `Duc-Nguyen-739/FreePiLogin4`, kho `~/.freepi4` — `docs/freepi4.md` |
| `freepi5` | FreePi5 | OAuth (plugin riêng) | 1 / 24 | **bật**; tài khoản thứ sáu, repo private `Duc-Nguyen-739/FreePiLogin5`, kho `~/.freepi5` — `docs/freepi5.md` |
| `freepi6` | FreePi6 | OAuth (plugin riêng) | 1 / 24 | **bật**; một tài khoản FreePi riêng, repo private `Duc-Nguyen-739/FreePiLogin6`, kho `~/.freepi6` — `docs/freepi6.md` |
| `freepi7` | FreePi7 | OAuth (plugin riêng) | 1 / 24 | **bật**, đã đăng nhập `thuylinh-coder` (Pi7 - Leader); `deepseek-v4.1-flash`, efforts `none…max`, 1 request/account, queue 32; repo private `Duc-Nguyen-739/FreePiLogin7`, kho `~/.freepi7` — `docs/freepi7.md` |
| `agy-cli` | agy-cli | OAuth Google (plugin) | 3 / 5 | **bật**; `gemini-3.8-flash`, `gemini-2.5-flash-lite`, `claude-opus-4-6-thinking` |
| `agnes` | Agnes | API key | 1 / 4 | **tắt** (`magpie provider on agnes`); `agnes-3.0-flash` |
| `kilo` | Kilo Gateway | API key | 3 / 410 | **bật**; có `reflection/beam-free` và `particle-1:free` |
| `openrouter` | OpenRouter | API key | 1 / 432 | **bật**; 50 request/ngày cho model `:free`; `particle-1:free` cho `group/free` |
| `groq` | Groq | API key | 1 / 9 | **bật**; `openai/gpt-oss-20b`, bậc dự phòng của `group/free` |
| `nvidia` | NVIDIA NIM | API key | 1 / 24 | **bật**; `nvidia/nemotron-3.5-super-vl-120b-a12b`, bậc dự phòng của `group/free` |
| `cline` | Cline | OAuth (plugin) | 1 / 478 | **bật**; `particle-1:free` |
| `kiro` | Kiro | OAuth Google (plugin) | 1 / 8 | **bật**; `claude-haiku-4.5` (50 credit/tháng) |
| `aihubmix` | AiHubMix | API key | 36 / 659 | **tắt**; nếu bật, cả 36 model `-free` trả HTTP 200 + câu "Sorry, to prevent abuse of free resources…", 0 token — tài khoản chưa nạp tiền |
| `xingchi` | Xingchi custom | API key | 1 / 1 | **bật**; `gpt-6.1-sol:high` đứng đầu `group/leader`. `gpt-6-astra` đã rời cả danh mục lẫn group (pool upstream 503, 2026-11-17) |
| `opencode-zen` | OpenCode Zen | API key | 1 / 48 | **bật**, chỉ expose `jev-1.13-free` làm classifier; free tier qua API key bị chặn |
| `qoder` | Qoder | OAuth web (plugin) | 18 | record còn, **không hiện** (thiếu plugin) |
| `antigravity` | Antigravity | OAuth (plugin) | 2 | record còn, **không hiện** (thiếu plugin) |
| `copilot` | Copilot | OAuth GitHub | 1 / 23 | **tắt** |
| `opencode-zen-free` | OpenCode Zen Free | plugin, key công khai | 15 / 8 | **tắt**; plugin vẫn cài, bật lại được |

## Plugin (14)

```
@magpie-community/opencode-autoclaw-auth@0.2.9    autoclaw, autoclaw-cn
@magpie-community/opencode-workbuddy-auth@latest  workbuddy-ai, workbuddy
@magpie-community/opencode-kiro-auth@latest       kiro
@magpie-community/opencode-cline-auth@latest      cline
@magpie-community/opencode-agnes-auth@latest      agnes
magpie-freepi-auth@latest                         freepi
magpie-freepi2-auth (local clone)                  freepi2 (FreePi2)
magpie-freepi3-auth (local clone)                  freepi3 (FreePi3)
magpie-freepi4-auth (local clone)                  freepi4 (FreePi4)
magpie-freepi5-auth (local clone)                  freepi5 (FreePi5)
magpie-freepi6-auth (local clone)                  freepi6 (FreePi6)
magpie-freepi7-auth (local clone)                  freepi7 (FreePi7)
@magpie-community/opencode-agy-cli-auth@latest    agy-cli
@magpie-community/opencode-zen-free-auth@latest   opencode-zen-free
opencode-zen-freex@latest                         phục vụ opencode-zen-free
```

`qoder` / `zcode` không còn plugin trên máy này (provider `qoder` đang tắt, model vẫn
còn trong `providers.json`). AutoClaw **ghim 0.2.9** — bản vàng, xem mục cuối `AGENTS.md`.
FreePi2–FreePi7 là sáu plugin **không cài từ npm**: repo private
`Duc-Nguyen-739/FreePiLogin2` … `FreePiLogin7`, clone về `~/.local/src/FreePiLoginN`
rồi `magpie plugin add` đường dẫn đó (bun không gửi token khi tải tarball GitHub →
404). Máy khác cần được cấp quyền đọc sáu repo đó, hoặc bỏ qua và chạy với FreePi
chính.

## Routing group (9)

| Group | Dùng cho | stays | levels | Model (thứ tự fallback) |
|---|---|---|---|---|
| `main` | OpenCode — chat thường ngày, **đang bật** | `session` | `low,high,max` | `freepi/deepseek-v4.1-flash` → `workbuddy-ai/hy4flash-free` → `agy-cli/gemini-3.8-flash` → `agy-cli/gemini-2.5-flash-lite` → `autoclaw/zai_glm-5.3-flash` → `workbuddy-ai/glm-5.3-flash` |
| `leader` | OpenChamber — quyết định + điều phối | `turn` | `low,high,max` | `xingchi/gpt-6.1-sol:high` → `freepi6/deepseek-v4.1-flash` → `agy-cli/claude-opus-4-6-thinking` → `workbuddy-ai/deepseek-v4.1-flash-sg` |
| `review` | khảo sát + brief hướng + viết plan | `turn` | `none,low,high,max` | `freepi/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` → `workbuddy-ai/hy4flash-free:high` |
| `reviewplan` | gác hướng + kiểm chứng/sửa plan + audit cuối | `turn` | `none,low,high,max` | `freepi5/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` → `workbuddy-ai/hy4flash-free:high` |
| `coder` | viết code theo plan | `turn` | `low,high,max` | `freepi/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` |
| `tester` | chạy test, báo lỗi | `turn` | `low,high,max` | `freepi4/deepseek-v4.1-flash` → `workbuddy-ai/glm-5.3-flash` |
| `tester-2` | tester độc lập, chạy song song | `turn` | `low,high,max` | `freepi2/deepseek-v4.1-flash` → `workbuddy-ai/hy4flash-free` → `autoclaw/zai_glm-5.3-flash` |
| `tester-3` | tester thứ ba, soi hợp đồng dữ liệu | `turn` | `low,high,max` | `freepi3/deepseek-v4.1-flash` → `kiro/claude-haiku-4.5` → `autoclaw/zai_glm-5.3-flash` → `agy-cli/gemini-3.8-flash` → `workbuddy-ai/hy4flash-free` → `workbuddy-ai/deepseek-v4.1-flash-sg` |
| `free` | **chỉ** cho việc nén của billion-context | `auto` | `none,minimal,low,medium` | `kilo/particle-ai/particle-1:free` → `cline/particle-ai/particle-1:free` → `openrouter/particle-ai/particle-1:free` → `groq/openai/gpt-oss-20b` → `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` (rotate) |

Tám group dùng `routing=order`, `effort=auto`, classifier `opencode-zen/jev-1.13-free`;
**không group nào có rule**. `main`, `leader`, `coder` và ba tester mở levels
`low,high,max`; `review`/`reviewplan` mở `none,low,high,max` (FreePi không expose mức
reasoning nhưng magpie vẫn mở levels khi đặt `effort=auto`). `group/free` **không** có
classifier, `routing=rotate`, `stays=auto`; levels `none,minimal,low,medium` do magpie
tự suy từ các model trong ladder, không phải tay đặt — chỉ để billion-context gọi một
phát ([`billion-context.md`](billion-context.md)).

**`group/main` đang bật** (`magpie group on main`): gateway trả lời và OpenCode dùng nó
làm model mặc định. Bản cũ của repo ghi group này tắt — đó là trạng thái cũ, đã bật lại.

`autoclaw/zai_auto` và `autoclaw/zai_auto-fast` không nằm trong group nào vì chỉ có 200K
context — mọi member còn lại đều khai 1M. `workbuddy-ai/hy3` (192K) đã bị provider bỏ
khỏi danh sách expose, nên không còn trong group. `autoclaw/zaicoding_glm-5.3` đã rời
ladder (quota coding free hay 429); group vẫn chạy nhờ `autoclaw/zai_glm-5.3-flash`.

Ngoài 9 group trên, `magpie groups` còn liệt kê các **group `auto/*`** do magpie tự sinh
(`auto/free`, `auto/particle-1:free`, `auto/ernie-5.5-flash-preview:free`…) — mỗi cái gom
cùng một model từ kilo/openrouter/cline. Chúng không được agent nào trỏ tới; 11 cái đã
được ẩn (`{"hidden": true}` trong `providers.json`), `magpie group restore <id>` đưa lại.

## Agent được magpie quản lý

| Agent | Model | File magpie sửa |
|---|---|---|
| OpenCode | `magpie/group/main`, model phụ cho agent `title` = `magpie/workbuddy-ai/hy4flash-free` | `~/.config/opencode/opencode.json` |
| OpenChamber | `magpie/group/leader`, `defaultVariant: max`, `defaultAgent: leader` | `~/.config/openchamber/settings.json` (không phải `preferences.json`) |
| Gemini CLI | (auth google, không đặt model) | `~/.gemini/settings.json` |
| Antigravity CLI | — | `~/.gemini/antigravity-cli/settings.json` |
| DeepSeek Harness | CLI không có trên máy | `~/.dsh/profiles/web/cordis.patch.yml` |

## OpenCode

- Provider `magpie`: khai trong `providers` của `opencode.json`, `baseURL:
  http://127.0.0.1:3425/v1`, `apiKey: magpie` (chuỗi giả — gateway local không cần key
  thật). OpenCode V2 **không** cần map `models`: nó hỏi gateway `GET /v1/models` và
  thấy **32 model** = 8 `group/*` + 24 model lẻ (`freepi2/…` … `freepi6/…`, `groq/…`,
  `nvidia/…`). File hiện tại không có khoá `models`; bản OpenCode/OpenChamber cũ có
  thể có map tĩnh, cả hai đều chạy. `model: magpie/group/main`, agent `title` dùng
  `magpie/workbuddy-ai/hy4flash-free`.
- Provider gọi thẳng còn khai báo: `xingchi` (bật, dùng cho `group/leader`), còn
  `kiraai`, `takenbarbor`, `dsh` nằm trong `disabled_providers` cùng `kilo` (đã có
  `kilo/reflection/beam-free` qua magpie nên không gọi thẳng nữa).
- Agent tự viết trong `~/.config/opencode/agents/`: `leader.md` (primary,
  `group/leader#max`, chỉ `question` + 6 subagent + MCP đọc; deny read/glob/grep/
  edit/shell/webfetch/websearch/skill/execute), `review.md` (`group/review`; shell
  allowlist chỉ đọc, chỉ ghi plan), `reviewplan.md` (`group/reviewplan`; shell
  deny-list, chỉ ghi plan), `coder.md` (`group/coder`; deny sửa plan/force-push),
  `tester.md` (`group/tester`; chỉ ghi test ownership `tester1`), `tester2.md`
  (`group/tester-2`; ownership `tester2`), `tester3.md` (`group/tester-3`; ownership
  `tester3`, lái browser). Mỗi agent có mục `## Skill`; Leader gửi
  `Skill: <id> (required|optional)` (hoặc `Skill: tự chọn` để agent tự khớp skill với
  việc đang làm) trong prompt, agent tự gọi tool `skill`.
- Skill: agent **chỉ** nạp skill của repo đang làm (`skills/` khai ở `opencode.json`)
  cộng `opencode`, `report`; **cấm** skill thư viện magpie (xem `docs/opencode.md`).
  `~/.config/opencode/skills/magpie-skills` vẫn là symlink vào skill router của magpie
  nhưng agent không dùng. Repo không cài skill nào; 13 skill thư viện đến từ trang
  Library của magpie rồi tự hand over.

## Thư viện magpie

| | |
|---|---|
| Instructions | chưa có |
| MCP servers | 5 bật → gemini, agy, opencode: `magpie-sessions`, `magpie-vision`, `magpie-web-search`, `cloudflare-docs`, `chrome-devtools`; `magpie-browser` **tắt** (cần Chrome/Edge thật + extension, bật lại bằng `MAGPIE_MCP_BROWSER=1` + `magpie library mcp on magpie-browser`). Gemini CLI còn 2 MCP riêng của Cloud Shell: data-agent-kit, notebooks |
| Skills | 13 skill thư viện → gemini, agy, opencode: `banner-design`, `brand`, `design`, `design-system`, `find-skills`, `hallmark`, `impeccable`, `magpie-quota`, `magpie-sessions`, `magpie-setup`, `slides`, `ui-styling`, `ui-ux-pro-max`. Agent **không** nạp các skill này (trừ hai ngoại lệ `magpie-sessions`, `magpie-quota`); thư viện chỉ là nguồn cập nhật về repo |
| Web search | You.com (miễn phí, không key, 100 lượt/ngày) |
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
~/.config/opencode/agents/              leader.md, review.md, reviewplan.md, coder.md, tester.md, tester2.md, tester3.md
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
| `visionEffort` | *(rỗng)* | để mặc định của magpie; đặt `max` nếu thấy vision trả lời nông |
| `redact` | `true` | bật che dữ liệu nhạy cảm khi chia sẻ log |
| `redactModelName` | `astrlink-guard` | tên model làm việc che |
| `redactKinds` | `bucket,home,ip,userhost` | những gì bị che |
| `quotaLeft` | `true` | hiện quota còn lại trong UI |
| `trayUsageEvery` | `3` | nhịp cập nhật usage trên tray |
| `textSize` | `110` | cỡ chữ UI |
| `dockNever` / `dockSettled` | `true` / `true` | không chiếm dock, đã chốt lựa chọn dock |
| `otel` | `{}` | chưa bật xuất telemetry |
| `sessionReads` | `{asked: true, all: true}` | đã hỏi và cho phép đọc lại phiên |
| `pluginCheckins` | `{autoclaw: true, qoder: true}` | điểm danh hằng ngày |
| `modelEfforts` | FreePi 1–4, 6–7: `none…max`; FreePi5: `none…xhigh` | magpie tự sinh theo model/level (không seed) |

`scripts/setup-settings.sh` chỉ **thêm khoá còn thiếu**, không ghi đè giá trị đã có; và chỉ
đặt `vision`/`imageGen` khi model tương ứng đã tồn tại (tức sau khi đăng nhập WorkBuddy).
Máy này **không còn `imageGen`**: WorkBuddy đã bỏ `hy-image-3.5` khỏi danh sách expose, nên
script không thêm khoá đó nữa — đó là hành vi đúng, không phải lỗi.

## Repo này tái tạo được gì

| Hạng mục | Repo | Ghi chú |
|---|---|---|
| magpie binary | ✅ | installer chính thức hoặc `--from-source` (clone yetone/magpie) |
| 14 plugin provider | ✅ | `scripts/plugins.sh` (FreePi2/3/4/5/6 clone từ repo private) |
| 9 routing group | ✅ | **giống hệt** cấu hình máy này, kể cả `group/free` (5 model); `review`/`reviewplan` chỉ tạo khi thiếu, `--force` không reset |
| settings.json | ✅ | chỉ thêm khoá thiếu |
| `opencode-zen` bật, chỉ expose `jev-1.13-free`; `opencode-zen-free` tắt | ✅ | `setup-settings.sh` |
| OpenCode + provider `magpie` | ✅ | magpie tự ghi `opencode.json` |
| `billion-context` plugin + config | ✅ | `scripts/setup-billion-context.sh` + `config/billion-context.json`; group/model do user tự tạo |
| 7 agent `leader`, `review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3` | ✅ | `config/agents/`; mỗi agent có mục `## Skill` |
| skill thư viện (13) | ➖ | thêm ở trang Library của magpie; agent **không** nạp |
| OpenChamber + cổng 3000 | ✅ | `install-openchamber.sh` |
| `openchamber` / `openmagpie` + link kèm key | ✅ | wrapper + supervisor |
| Tự bật ở shell đầu tiên | ✅ | khối `.bashrc` |
| Provider account/key | ➖ | **bạn đăng nhập** (phần duy nhất) |
| Provider gọi thẳng trong OpenCode (`xingchi`, `kiraai`, `takenbarbor`, `dsh`) | ❌ | key/relay riêng của chủ máy, không đưa vào repo; cách thêm: `docs/providers.md` |
| Gemini CLI / Antigravity CLI | ➖ | tuỳ chọn, repo không cài |
| Profiles `before-*` | ❌ | snapshot tạm thời, không cần |
| Theme/notification của OpenChamber | ➖ | chọn trong UI (10 giây) |

## Bản đồ kết nối

```
OpenCode    ─→ group/main             ─┐
OpenChamber ─→ group/leader        ─┤
Leader      ─→ group/leader        ─┼─→ gateway 127.0.0.1:3425
Review      ─→ group/review        ─┤
Reviewplan  ─→ group/reviewplan    ─┤
Coder       ─→ group/coder         ─┤
Tester      ─→ group/tester        ─┤
Tester 2    ─→ group/tester-2      ─┤
Tester 3    ─→ group/tester-3      ─┤
billion-context ─→ group/free      ─┘

Provider theo group:
  leader      xingchi, freepi6, agy-cli, workbuddy-ai
  review      freepi, workbuddy-ai
  reviewplan  freepi5, workbuddy-ai
  coder       freepi, workbuddy-ai
  tester      freepi4, workbuddy-ai
  tester-2    freepi2, workbuddy-ai, autoclaw
  tester-3    freepi3, kiro, autoclaw, agy-cli, workbuddy-ai
  free        kilo, cline, openrouter, groq, nvidia
```

Mỗi group · classifier ─→ `opencode-zen/jev-1.13-free` (chỉ model này, không vào ladder)

`opencode-zen` (API key) **đang bật** nhưng chỉ expose `jev-1.13-free` làm classifier;
`opencode-zen-free` (plugin) **đang tắt**: free tier qua API key bị chặn, đường plugin cạn
theo IP dùng chung — xem [`zen-free.md`](zen-free.md).
