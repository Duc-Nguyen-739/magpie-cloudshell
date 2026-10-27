# magpie trên Cloud Shell — cài một lần, chỉ còn đăng nhập

Dựng lại **đúng** cấu hình magpie đang chạy trên một máy Cloud Shell thật: 6 provider,
2 routing group (`Main`, `Code`), OpenCode + OpenChamber trỏ vào `group/main`, chạy
headless không cần systemd, và hai lệnh `openchamber` / `openmagpie` in ra **link web đã
kèm key** — bấm là vào, không phải dán gì.

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

A reproducible, headless magpie setup for Google Cloud Shell / VPS / WSL / container:

```sh
git clone https://github.com/Duc-Nguyen-739/magpie-cloudshell.git
cd magpie-cloudshell
bash bootstrap.sh          # magpie CLI + 6 plugins + OpenCode + OpenChamber + wrappers
bash scripts/login.sh      # the provider sign-ins (AutoClaw, WorkBuddy, Qoder, API keys)
bash scripts/finish.sh     # Main/Code routing groups + point agents at group/main
openchamber                # both UIs up, links printed with the key already in them
```

Everything except the sign-ins can be done by an AI agent — see [`AGENTS.md`](AGENTS.md).
The setup it reproduces is listed exactly in [`docs/inventory.md`](docs/inventory.md).

---

## Cài gì, ở đâu

| Thành phần | Vị trí | Vai trò |
|---|---|---|
| magpie 0.1.x (terminal build) | `~/.local/bin/magpie` | gateway + web UI + CLI quản lý |
| 6 plugin provider | `~/.config/magpie/plugins/` | AutoClaw, WorkBuddy, Qoder, ZCode, OpenCode Zen Free |
| OpenCode v2 | `~/.opencode/bin/opencode` | agent code trong terminal |
| OpenChamber | `~/.npm-global/bin/openchamber` | web UI cho OpenCode (cổng 3000) |
| 2 subagent | `~/.config/opencode/agents/` | `coder`, `tester` |
| skill | `~/.config/opencode/skills/magpie-setup` | hướng dẫn agent thao tác magpie |
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

```sh
git clone https://github.com/Duc-Nguyen-739/magpie-cloudshell.git
cd magpie-cloudshell
bash bootstrap.sh
```

`bootstrap.sh` chạy 7 bước, **chạy lại nhiều lần vẫn an toàn**:

1. Cài magpie bản terminal (`MAGPIE_CLI=1`) vào `~/.local/bin`.
2. Cài 6 plugin provider (lần đầu tải bun ~180 MB).
3. Copy `openchamber`, `openmagpie`, `magpie-headless-*` vào `~/.local/bin`.
4. Thêm khối PATH + tự bật vào `~/.bashrc` (đánh dấu `# >>> magpie-cloudshell >>>`).
5. Cài OpenCode (script curl chính thức) và OpenChamber (`npm -g @openchamber/web`).
6. Copy 2 subagent + skill, sinh provider block trong `opencode.jsonc`.
7. Bật gateway + web UI, in link đã kèm key, in việc còn lại.

Tuỳ chọn: `--minimal` (chỉ magpie, không OpenCode/OpenChamber), `--no-autostart`.

## Đăng nhập provider — phần duy nhất phải làm tay

```sh
bash scripts/login.sh              # trạng thái từng provider
bash scripts/login.sh autoclaw     # AutoClaw (Zhipu) — quan trọng nhất
bash scripts/login.sh workbuddy    # WorkBuddy AI
bash scripts/login.sh qoder        # Qoder
bash scripts/login.sh zcode        # ZCode (tuỳ chọn)
bash scripts/login.sh keys         # OpenCode Zen + Kilo (dán API key)
```

Hoặc mở link web UI → **Settings → Providers → Add / Sign in**. Hai cách gọi cùng một
gateway nên kết quả như nhau.

| Provider | Cách đăng nhập | Chi tiết |
|---|---|---|
| AutoClaw (Zhipu) | OAuth Google/z.ai; Cloud Shell cần forward cổng | [`docs/autoclaw-login.md`](docs/autoclaw-login.md) |
| WorkBuddy AI | OAuth web (hoặc desktop sign-in / API key) | [`docs/providers.md`](docs/providers.md) |
| Qoder | OAuth web | [`docs/providers.md`](docs/providers.md) |
| OpenCode Zen | API key `oc_…` | [`docs/providers.md`](docs/providers.md) |
| Kilo | API key `eyJ…` | [`docs/providers.md`](docs/providers.md) |
| OpenCode Zen Free | plugin, key công khai (mặc định tắt) | [`docs/providers.md`](docs/providers.md) |

## Tạo group + trỏ agent

```sh
bash scripts/finish.sh
```

Tạo (hoặc cập nhật) hai group và trỏ OpenCode + OpenChamber vào `group/main`:

| | `group/main` | `group/code` |
|---|---|---|
| Dùng cho | chat thường ngày | việc code |
| routing / stays | `order` / `session` | `order` / `turn` |
| levels / effort | `low,high,max` / `auto` | `low,high,max` / `auto` |
| classifier | `opencode-zen/jev-1.13-free` | `opencode-zen/jev-1.13-free` |
| rule | ảnh → DeepSeek V4.1 Flash; nén → GLM-5.3 Flash | 4 intent (plan, code, test, review) + ảnh |

Ladder 8 model (thứ tự fallback) và lý do: [`docs/groups.md`](docs/groups.md).

Chạy lại `finish.sh` sau khi đăng nhập thêm provider để lấp đủ model vào group —
script chỉ đưa vào group những model thật sự có.

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
| `bash scripts/doctor.sh` | kiểm tra toàn bộ (binary, gateway, provider, group, agent, cổng, key, dung lượng) |
| `openchamber <lệnh>` | chuyển nguyên cho CLI thật (`status`, `models`, `session`…) |

Agent đọc model lúc khởi động → sau khi đổi group/model, mở phiên mới.

## Cấu trúc repo

```
bootstrap.sh                cài đặt một lần
AGENTS.md                   playbook cho AI agent (đọc là cài được hết)
config/agents/              coder.md, tester.md (subagent OpenCode)
scripts/
  install.sh                magpie CLI (MAGPIE_CLI=1)
  plugins.sh                6 plugin provider
  install-opencode.sh       OpenCode (opencode.ai/install)
  install-openchamber.sh    @openchamber/web vào ~/.npm-global
  setup-opencode.sh         2 subagent + skill magpie-setup
  login.sh                  trạng thái + đăng nhập từng provider
  setup-groups.sh           group/main, group/code (--force, --dry-run)
  setup-agents.sh           trỏ agent vào group/main
  finish.sh                 setup-groups + setup-agents + doctor
  doctor.sh                 kiểm tra sức khoẻ toàn bộ
  magpie-headless*          supervisor không cần systemd
  openmagpie                magpie + link kèm key
  openchamber               magpie + OpenChamber + 2 link kèm key
docs/
  inventory.md              kiểm kê chính xác máy tham chiếu
  autoclaw-login.md         AutoClaw: 3 cách đăng nhập, lỗi thường gặp
  providers.md              từng provider: id, xác thực, kiểm tra
  groups.md                 hai group: model, rule, classifier, cách sửa
  opencode.md               OpenCode nối magpie thế nào, subagent, skill
  cloudshell.md             headless: cổng, key, preview, PATH, autostart
```

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
