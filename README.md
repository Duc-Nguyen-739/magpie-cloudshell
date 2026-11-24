# magpie trên Cloud Shell — cài một lần, chỉ còn đăng nhập

Dựng lại **đúng** cấu hình magpie đang chạy trên một máy Cloud Shell thật: 18 provider
(14 bật), 8 routing group mẫu, OpenCode + OpenChamber → `group/leader`, chạy
headless không cần systemd, và hai lệnh `openchamber` / `openmagpie` in ra **link web đã
kèm key** — bấm là vào, không phải dán gì. Model trong group do bạn tự chọn; repo không
đồng bộ ladder từ máy tham chiếu.

Mục tiêu: clone repo → `bash bootstrap.sh` → **bạn chỉ cần đăng nhập tài khoản** vào các
provider (phần lớn là bấm link, không phải dán key).

> **Phần quan trọng nhất là đăng nhập AutoClaw** (OAuth trình duyệt, không phải API key):
> [`docs/autoclaw-login.md`](docs/autoclaw-login.md). Trên Cloud Shell, trình duyệt của
> bạn không ở cùng máy với magpie nên phải chuyển tiếp cổng — tài liệu đó có 3 cách.

**magpie là dự án của yetone — repo chính thức: <https://github.com/yetone/magpie>.**
Repo này chỉ là bộ script cài đặt + cấu hình mẫu; mọi hành vi của magpie lấy tài liệu
chính thức làm chuẩn:

| | |
|---|---|
| Repo | <https://github.com/yetone/magpie> |
| Bắt đầu | <https://usemagpie.ai/docs/start> |
| Tham chiếu đầy đủ (mọi lệnh, mọi field) | <https://github.com/yetone/magpie/blob/main/docs/reference.md> |
| Plugin cộng đồng | <https://github.com/magpie-community/plugins> |
| Intent routing | <https://usemagpie.ai/docs/intent> |
| Docker / server / NAS | <https://usemagpie.ai/docs/docker> |
| Discord | <https://discord.gg/vGSnD3ZKQF> |
| OpenCode V2 docs | <https://opencode.ai/v2/docs/> |
| OpenChamber | <https://www.npmjs.com/package/@openchamber/web> |

---

## TL;DR (English)

A reproducible, headless magpie setup for Google Cloud Shell / VPS / WSL / container.
Step 1 is the official magpie repo; everything after that is this repo's setup, and the
only manual step left is signing in to providers.

```sh
# 1) magpie, from the official repo (or let bootstrap.sh do it — see below)
git clone https://github.com/yetone/magpie.git ~/.local/src/magpie
cd ~/.local/src/magpie && make cli && install -m755 magpie ~/.local/bin/magpie

# 2) this repo's setup: plugins, wrappers, OpenCode + OpenChamber, groups, agents
git clone https://github.com/Duc-Nguyen-739/magpie-cloudshell.git
cd magpie-cloudshell && bash bootstrap.sh

# 3) sign in — the only manual step; groups are created right after each sign-in
bash scripts/login.sh autoclaw
bash scripts/login.sh workbuddy
bash scripts/login.sh qoder        # tuỳ chọn — cài plugin qoder trước
bash scripts/login.sh keys

openchamber                # both UIs up, links printed with the key already in them
```

Nothing else to install after the sign-ins. An AI agent can do steps 1–2 —
see [`AGENTS.md`](AGENTS.md). The exact setup reproduced: [`docs/inventory.md`](docs/inventory.md).

---

## Cài gì, ở đâu

| Thành phần | Vị trí | Vai trò |
|---|---|---|
| magpie 0.1.x (terminal build) | `~/.local/bin/magpie` | gateway + web UI + CLI quản lý |
| 11 plugin provider | `~/.config/magpie/plugins/` | AutoClaw, WorkBuddy, agnes, FreePi, FreePi2, FreePi3, FreePi4, FreePi5, FreePi6, FreePi7, OpenCode Zen Free (máy tham chiếu có 12 entry vì `freepi` cài hai bản) |
| OpenCode v2 | `~/.opencode/bin/opencode` | agent code trong terminal |
| OpenChamber | `~/.npm-global/bin/openchamber` | web UI cho OpenCode (cổng 3000) |
| 7 agent | `~/.config/opencode/agents/` | `leader` + `review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3` |
| skill thư viện | `~/.config/magpie/library/skills/` | 7 skill; agent **không** nạp, chỉ hai ngoại lệ `magpie-sessions`/`magpie-quota` |
| wrapper | `~/.local/bin/openchamber`, `openmagpie`, `magpie-headless-*` | bật + in link kèm key |
| dữ liệu magpie | `~/.config/magpie/` (600) | provider, group, auth, web-key |
| log | `~/.local/state/magpie/headless.log` | log supervisor |

Cổng: **3425** gateway · **3430** magpie web UI · **3000** OpenChamber.
Kiểm kê chi tiết (phiên bản, tài khoản, model, rule): [`docs/inventory.md`](docs/inventory.md).

## Bạn cần gì

| | |
|---|---|
| Máy | Linux x86_64/arm64: Google Cloud Shell, VPS, WSL, container — không cần desktop |
| Phần mềm | `curl`, `git`, `node` ≥ 20 (Cloud Shell có qua nvm) |
| Dung lượng | ~800 MB (magpie 55 + bun 180 + OpenChamber 290 + OpenCode 300) |
| Tài khoản | AutoClaw (Zhipu), WorkBuddy, Qoder — đăng nhập bằng trình duyệt; OpenCode Zen / Kilo — API key (tuỳ chọn) |

## Cài

**Bước 1 — magpie từ repo chính chủ.** Chọn một trong hai:

```sh
# a) build từ source (cần git + Go ≥ 1.26; Cloud Shell có sẵn Go)
git clone https://github.com/yetone/magpie.git ~/.local/src/magpie
cd ~/.local/src/magpie && make cli
install -m755 magpie ~/.local/bin/magpie

# b) để bootstrap tự làm: nó clone repo chính chủ và build hộ
bash bootstrap.sh --from-source
```

Hoặc dùng bản dựng sẵn chính thức (nhanh nhất, không cần Go):
`curl -fsSL https://usemagpie.ai/install.sh | MAGPIE_CLI=1 sh`
— `bootstrap.sh` không có `--from-source` sẽ gọi đúng lệnh này.

**Bước 2 — setup của repo này:**

```sh
git clone https://github.com/Duc-Nguyen-739/magpie-cloudshell.git
cd magpie-cloudshell
bash bootstrap.sh
```

FreePi2/FreePi3/FreePi4/FreePi5/FreePi6/FreePi7 là sáu plugin trong **repo private**
`Duc-Nguyen-739/FreePiLogin2`, `FreePiLogin3`, `FreePiLogin4`, `FreePiLogin5`,
`FreePiLogin6`, `FreePiLogin7`: trước khi chạy `bootstrap.sh`, máy cần `gh auth login`
bằng tài khoản đọc được các repo đó (hoặc clone sẵn vào `~/.local/src/FreePiLogin2` …
`~/.local/src/FreePiLogin7`). Thiếu quyền thì `scripts/plugins.sh` chỉ cảnh báo và bỏ
qua các plugin đó, provider còn lại vẫn cài bình thường.

`bootstrap.sh` chạy 9 bước, **chạy lại nhiều lần vẫn an toàn**:

1. Cài magpie — bỏ qua nếu đã có (dùng `--from-source` để build từ repo chính chủ).
2. Cài 11 plugin provider (lần đầu tải bun ~180 MB).
3. Copy `openchamber`, `openmagpie`, `magpie-headless-*`, `magpie-finish` vào `~/.local/bin`
   (kèm bản sao scripts/config ở `~/.local/share/magpie-cloudshell`).
4. Thêm khối PATH + tự bật vào `~/.bashrc` (đánh dấu `# >>> magpie-cloudshell >>>`).
5. Cài OpenCode (script curl chính thức) và OpenChamber (`npm -g @openchamber/web`).
6. Bật gateway + web UI, in link đã kèm key.
7. Cấu hình magpie giống máy tham chiếu: `settings.json` (theme dark, vision + effort,
   redaction, check-in AutoClaw, cỡ chữ…), bật `opencode-zen` nhưng chỉ expose
   `jev-1.13-free`, tắt `opencode-zen-free`; **giá model (input/output/cache)**
   của WorkBuddy/Xingchi, context/output/reasoning của FreePi qua
   `scripts/setup-model-settings.sh`; cài `billion-context` + config nén (template
   `config/billion-context.json`, script `scripts/setup-billion-context.sh`).
8. Tạo group còn thiếu + trỏ agent (chưa có model thì đăng nhập xong sẽ tự tạo).
   `finish.sh` không reset ladder đã có — model trong group do bạn chọn.
9. In việc còn lại: đăng nhập.

Tuỳ chọn: `--from-source`, `--minimal` (chỉ magpie, không OpenCode/OpenChamber), `--no-autostart`.

**Bước 3 — đăng nhập provider.** Xong, không phải cài gì nữa.

## Đăng nhập provider — phần duy nhất phải làm tay

```sh
bash scripts/login.sh              # trạng thái từng provider
bash scripts/login.sh autoclaw     # AutoClaw (Zhipu) — quan trọng nhất
bash scripts/login.sh workbuddy    # WorkBuddy AI
bash scripts/login.sh freepi       # FreePi chính (plugin npm)
bash scripts/login.sh freepi2      # FreePi2 … freepi7 (plugin private, mỗi cái một tài khoản)
bash scripts/login.sh qoder        # Qoder (tuỳ chọn — cần plugin qoder)
bash scripts/login.sh zcode        # ZCode (tuỳ chọn — cần plugin zcode)
bash scripts/login.sh keys         # OpenCode Zen + Kilo (dán API key)
```

Trên máy tham chiếu, plugin `qoder`/`zcode` **không** được cài nên `magpie providers`
không liệt kê hai provider này (chỉ còn record trong `providers.json`).

Hoặc mở link web UI → **Settings → Providers → Add / Sign in**. Hai cách gọi cùng một
gateway nên kết quả như nhau.

> **Trên Cloud Shell, đây là cách đã dùng ở máy tham chiếu**: chạy
> `magpie plugin login autoclaw` (chọn `2` = z.ai) trước, hoặc bấm **Sign in** cho AutoClaw
> trong web UI → chạy `bash scripts/autoclaw-link.sh --relay` → mở link
> `https://<random>.trycloudflare.com/` vừa in ra trên điện thoại → slider Aliyun → z.ai →
> đồng ý uỷ quyền → trình duyệt dừng ở `http://localhost:<cổng>/auth/callback-…` và trang
> đó không load được → **copy nguyên URL** rồi chạy
> `bash scripts/autoclaw-link.sh --callback '<url>'`.
> Lý do cần relay (preview trả `403 forbidden origin`) + từng bước + cách xử lý khi cổng
> bận: [`docs/autoclaw-login.md`](docs/autoclaw-login.md) (Cách A2).
> Cách cũ — mở preview `https://<cổng>-<WEB_HOST>/` rồi dán `Callback URL` vào hộp đăng
> nhập — vẫn là phương án thay thế khi `/captcha` không trả 403 (Cách A).

**Mỗi lần đăng nhập xong, `login.sh` tự chạy `finish.sh`** — tạo/cập nhật group và trỏ
agent, nên bạn không phải làm gì thêm. Thêm `--no-finish` nếu muốn tự chạy sau.

Nếu bạn đăng nhập **trong web UI** (cách dùng trên Cloud Shell), lần mở kế tiếp
`openmagpie` / `openchamber` sẽ tự tạo group một lần khi thấy đã có model. Muốn làm ngay:
`magpie-finish`.

| Provider | Cách đăng nhập | Chi tiết |
|---|---|---|
| AutoClaw (Zhipu) | OAuth Google/z.ai; trên Cloud Shell dùng **relay + cloudflared, gọi callback local** | [`docs/autoclaw-login.md`](docs/autoclaw-login.md) |
| WorkBuddy AI | OAuth web (hoặc desktop sign-in / API key) | [`docs/providers.md`](docs/providers.md) |
| Qoder | OAuth web | [`docs/providers.md`](docs/providers.md) |
| OpenCode Zen | API key `oc_…` — **bật**, chỉ expose `jev-1.13-free` (classifier) | [`docs/zen-free.md`](docs/zen-free.md) |
| Kilo | API key `eyJ…` | [`docs/providers.md`](docs/providers.md) |
| OpenCode Zen Free | plugin, key công khai — **tắt** (hạn mức theo IP dùng chung) | [`docs/providers.md`](docs/providers.md) |
| FreePi2 | OAuth plugin — tài khoản thứ hai, **repo private** `Duc-Nguyen-739/FreePiLogin2`; `scripts/plugins.sh` tự clone về `~/.local/src/FreePiLogin2` rồi cài; kho riêng `~/.freepi2` | [`docs/freepi2.md`](docs/freepi2.md) |
| FreePi3 | OAuth plugin — tài khoản thứ ba, **repo private** `Duc-Nguyen-739/FreePiLogin3`; clone `~/.local/src/FreePiLogin3`; kho riêng `~/.freepi3` | [`docs/freepi3.md`](docs/freepi3.md) |
| FreePi4 | OAuth plugin — tài khoản thứ tư, **repo private** `Duc-Nguyen-739/FreePiLogin4`; clone `~/.local/src/FreePiLogin4`; kho riêng `~/.freepi4` | [`docs/freepi4.md`](docs/freepi4.md) |
| FreePi5 | OAuth plugin — tài khoản thứ năm, **repo private** `Duc-Nguyen-739/FreePiLogin5`; clone `~/.local/src/FreePiLogin5`; kho riêng `~/.freepi5` | [`docs/freepi5.md`](docs/freepi5.md) |
| FreePi6 | OAuth plugin — một tài khoản riêng, **repo private** `Duc-Nguyen-739/FreePiLogin6`; clone `~/.local/src/FreePiLogin6`; kho riêng `~/.freepi6` | [`docs/freepi6.md`](docs/freepi6.md) |
| FreePi7 | OAuth plugin — một tài khoản riêng, **repo private** `Duc-Nguyen-739/FreePiLogin7`; clone `~/.local/src/FreePiLogin7`; kho riêng `~/.freepi7` | [`docs/freepi7.md`](docs/freepi7.md) |

## Group + agent (tự động sau khi đăng nhập)

`login.sh` đã chạy `finish.sh` cho bạn sau mỗi lần đăng nhập. Nếu bạn đăng nhập bằng
**web UI** thay vì `login.sh`, chạy một lần:

```sh
bash scripts/finish.sh
```

Nó tạo **group còn thiếu**, rồi trỏ OpenCode và OpenChamber → `group/leader`. Model
trong group là **ví dụ**; repo không đồng bộ ladder từ máy tham chiếu, và `finish.sh`
không reset group đã có. Bạn tự chọn model bằng
`magpie group set <id> models=…` / `models+=…` / `models-=…`:

| Group | Dùng cho | Model ví dụ |
|---|---|---|
| `main` | chat thường ngày, `stays=session` | `freepi/deepseek-v4.1-flash` → `workbuddy-ai/hy4flash-free` → `autoclaw/zai_glm-5.3-flash` → `workbuddy-ai/glm-5.3-flash` |
| `leader` | OpenCode + OpenChamber: quyết định + điều phối, `stays=turn` | `xingchi/gpt-6.1-sol:high` → `freepi6/deepseek-v4.1-flash` → `workbuddy-ai/deepseek-v4.1-flash-sg` |
| `review` | khảo sát + brief hướng + viết plan | `freepi/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` |
| `reviewplan` | gác hướng + kiểm chứng/sửa plan + audit cuối | `freepi5/deepseek-v4.1-flash:high` → `workbuddy-ai/hy4flash-free:high` |
| `coder` | viết code theo plan | `freepi/deepseek-v4.1-flash:high` → `workbuddy-ai/deepseek-v4.1-flash-sg:high` |
| `tester` | chạy test, báo lỗi | `freepi4/deepseek-v4.1-flash` → `workbuddy-ai/glm-5.3-flash` |
| `tester-2` | tester độc lập | `freepi2/deepseek-v4.1-flash` → `autoclaw/zai_glm-5.3-flash` |
| `tester-3` | tester thứ ba | `freepi3/deepseek-v4.1-flash` → `autoclaw/zai_glm-5.3-flash` |

Tám group dùng `routing=order`, `effort=auto`, classifier `opencode-zen/jev-1.13-free`;
không group nào có rule. `main`/`leader`/`coder` và ba tester mở levels `low,high,max`;
`review`/`reviewplan` mở `none,low,high,max`. Group nén của billion-context là
`group/compress` do bạn tự tạo. Chi tiết: [`docs/groups.md`](docs/groups.md).

Sau khi đăng nhập thêm provider, `finish.sh` chỉ áp lại giá/context/output và tạo group
còn thiếu; muốn thêm model vào group đã có thì chạy
`magpie group set <id> models+=<provider/model>`.

## Giá và input/output của model

`scripts/setup-model-settings.sh` chạy tự động trong `finish.sh` (và `bootstrap.sh`),
áp lại sau mỗi lần đăng nhập:

- **Giá**: `*/deepseek-v4.1-flash` = `1,4,0.1,1.25` (input/output/cache read/cache
  write, USD mỗi 1M token), `*/jev-1.13-free` = `0,0,0,0`, hai model WorkBuddy
  đang expose = `1,4,0.1,1.25`.
- **FreePi input/output**: cả bảy `freepi*/deepseek-v4.1-flash` đặt
  `--context 1048576 --output 32768 --vision on --reasoning none…max`.
- **FreePi provider**: expose `deepseek-v4.1-flash`, queue 32, account-concurrency 1,
  RPM off, `routing=drain` cho `freepi`.
- **Xingchi**: model đang có dùng Responses API.

Kiểm tra:

```sh
magpie model prices
magpie model spec freepi7/deepseek-v4.1-flash
magpie provider queue freepi7
magpie provider account-concurrency freepi7
```

## Dùng hằng ngày

| Lệnh | Việc |
|---|---|
| **`openchamber`** | bật **cả magpie + OpenChamber**, in 2 link đã kèm key |
| **`openmagpie`** | chỉ magpie, in link đã kèm key |
| `magpie-headless-status` | đang chạy?, link, health |
| `magpie-headless-stop` | tắt gateway |
| `magpie providers` / `accounts` / `groups` | xem provider, tài khoản, group |
| `magpie quota` | còn bao nhiêu credit |
| `magpie usage 7d` | agent/model/tài khoản đã dùng gì |
| `magpie-finish` | tạo/cập nhật group + trỏ agent (bản cài; giống `bash scripts/finish.sh`) |
| `bash scripts/autoclaw-link.sh` | in **link localhost/preview** để mở trang đăng nhập AutoClaw từ laptop (`--watch`, `--port`, `--tunnel`) |
| `autoclaw-link` | như trên, bản cài trong `~/.local/bin` |
| `bash scripts/agnes-link.sh` | trang local để đăng nhập **Agnes**: mở link, dán API key `cpk-…`; tự lưu + kiểm tra (`--watch`, `--cancel`) |
| `bash scripts/doctor.sh` | kiểm tra toàn bộ (binary, gateway, provider, group, agent, cổng, key, dung lượng) |
| `openchamber <lệnh>` | chuyển nguyên cho CLI thật (`status`, `models`, `session`…) |

Agent đọc model lúc khởi động → sau khi đổi group/model, mở phiên mới.

## Cấu trúc repo

```
bootstrap.sh                cài đặt một lần
AGENTS.md                   playbook cho AI agent (đọc là cài được hết)
config/agents/              leader.md + review, reviewplan, coder, tester (OpenCode)
config/agent-contract.json  contract cho validator/test của 7 agent
config/plugins/leader-gate.js  plugin gác GATE (PASS|BLOCKED|PREP_READY|PREP_BLOCKED, artifact_hash)
config/leader-gate.json        config plugin (judge model, maxSteers, one-session-all, prep, hash)
tests/                      regression offline cho profile + installer
scripts/
  install.sh                magpie CLI từ installer chính thức (MAGPIE_CLI=1)
  install-from-source.sh    clone repo chính chủ + make cli (cần Go)
  plugins.sh                11 plugin provider (+ clone FreePi2…7)
  patch-free-pi.mjs         vá free-pi: client version lấy từ /client-version, không ghim
  setup-freepi-pair.mjs     tách riêng 2 provider freepi.ai: một entry cho mỗi user_id
  install-opencode.sh       OpenCode (opencode.ai/install)
  install-openchamber.sh    @openchamber/web vào ~/.npm-global
  setup-opencode.sh         agent leader + 6 subagent (không cài skill; --sync để cập nhật có backup)
  check-agents.py           lint contract/permissions của 7 agent profile
  plan-hash.py              hash plan quy ước SELF cho GATE artifact_hash (cài vào ~/.config/opencode/scripts/)
  sync-agents.py            đồng bộ profile an toàn (check/dry-run/apply/install-missing)
  setup-mcp.sh              MCP: magpie-sessions/search, Cloudflare docs, Chrome DevTools (magpie-browser tắt)
  setup-settings.sh         settings.json + trạng thái provider (chỉ thêm khoá thiếu)
  setup-model-settings.sh   giá input/output/cache, context/output, efforts, API, FreePi
  setup-billion-context.sh  cài package + plugin shim + config billion-context
  autoclaw-link.sh          in link localhost/preview để đăng nhập AutoClaw
  agnes-link.sh             trang local để đăng nhập Agnes (dán API key)
  agnes-login.mjs           server của trang đó
  login.sh                  trạng thái + đăng nhập từng provider
  setup-groups.sh           tám group mẫu: main, leader, review, reviewplan, coder, tester, tester-2, tester-3
  setup-agents.sh           OpenCode + OpenChamber → group/leader; small model mặc định
  finish.sh                 settings + model-settings + groups + agents + doctor
  doctor.sh                 kiểm tra sức khoẻ toàn bộ
  magpie-headless*          supervisor không cần systemd
  openmagpie                magpie + link kèm key
  openchamber               magpie + OpenChamber + 2 link kèm key
docs/
  inventory.md              kiểm kê chính xác máy tham chiếu
  autoclaw-login.md         AutoClaw: 3 cách đăng nhập, lỗi thường gặp
  providers.md              từng provider: id, xác thực, kiểm tra
  groups.md                 tám group mẫu: model, level, classifier, cách sửa
  zen-free.md               vì sao tắt OpenCode Zen Free; vì sao chỉ giữ jev làm classifier
  opencode.md               OpenCode nối magpie thế nào, subagent, skill
  billion-context.md        nén hội thoại: budget, target, lỗi target-timeout
  cloudshell.md             headless: cổng, key, preview, PATH, autostart
```

`bootstrap.sh` còn cài `magpie-finish` (bản sao scripts trong
`~/.local/share/magpie-cloudshell`, chạy được cả khi đã xoá repo) và hai wrapper tự gọi
nó một lần khi thấy có model mà chưa có `group/leader`.

## Gỡ

```sh
bash scripts/magpie-headless-stop
rm -f ~/.local/bin/{openchamber,openmagpie,magpie-headless,magpie-headless-start,magpie-headless-stop,magpie-headless-status}
rm -f ~/.local/bin/magpie
rm -rf ~/.config/magpie ~/.local/state/magpie
# xoá khối "# >>> magpie-cloudshell >>>" trong ~/.bashrc
```

Trả agent về như trước: `magpie opencode default`, `magpie openchamber default`.
Gỡ OpenCode: `opencode uninstall`. Gỡ OpenChamber: `npm rm -g --prefix ~/.npm-global @openchamber/web`.

## Ghi chú

- Repo **không chứa key, token hay thông tin tài khoản**. Mọi thứ nằm trong
  `~/.config/magpie` (600) trên máy bạn; `web-key` và `plugin-auth.json` bị `.gitignore` chặn.
- Plugin AutoClaw/WorkBuddy/Qoder/ZCode là **cộng đồng, không chính thức** — dùng có thể
  bị khoá tài khoản, tự chịu rủi ro. Chúng không liên quan tới yetone hay Zhipu/Tencent.
- Cloud Shell là máy tạm: `$HOME` giữ được, `/usr/local` thì không — vì vậy mọi thứ ở đây
  nằm trong `$HOME` và được bật lại bằng hook `.bashrc`.
- Muốn dùng nhiều máy: `magpie github on github://<owner>/<repo>` hoặc `magpie webdav on <address>`
  (file mã hoá) — xem [`docs/cloudshell.md`](docs/cloudshell.md).
