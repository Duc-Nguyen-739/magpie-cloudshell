# AGENTS.md — cài đặt này cho người dùng

Bạn đang cài một bộ magpie hoàn chỉnh trên máy Linux headless (Google Cloud Shell, VPS,
WSL, container). Việc của con người chỉ là **đăng nhập provider**; mọi thứ khác bạn làm.

Đọc hết file này trước khi chạy. Lệnh nằm trong `scripts/`.

## Nguồn chính thức — khi cần tra thêm

| | |
|---|---|
| magpie (repo) | <https://github.com/yetone/magpie> |
| Bắt đầu | <https://usemagpie.ai/docs/start> |
| Tham chiếu đầy đủ: mọi agent, provider option, endpoint, lệnh CLI, file | <https://github.com/yetone/magpie/blob/main/docs/reference.md> |
| Plugin cộng đồng (nguồn của AutoClaw/WorkBuddy/Qoder/ZCode) | <https://github.com/magpie-community/plugins> |
| Intent routing (rule `intent=`) | <https://usemagpie.ai/docs/intent> |
| OpenCode V2 | <https://opencode.ai/v2/docs/> |
| OpenChamber | <https://www.npmjs.com/package/@openchamber/web> |

Quy tắc: repo này mô tả **cách cài**, không định nghĩa lại magpie. Nếu tài liệu chính thức
mâu thuẫn với file này, tài liệu chính thức thắng — và hãy nói cho người dùng biết chỗ lệch.

## Bạn đang dựng gì

- magpie bản terminal trong `~/.local/bin` (không desktop, không systemd).
- 6 plugin provider: AutoClaw (Zhipu), WorkBuddy, Qoder, ZCode, OpenCode Zen Free.
- Hai routing group `group/main`, `group/code` trên cùng một ladder 8 model.
- OpenCode + OpenChamber trỏ `group/main`; 2 subagent `coder`, `tester`; skill `magpie-setup`.
- Supervisor bash giữ gateway + web UI sống; hai lệnh `openchamber` / `openmagpie` in
  link web **đã kèm key**.
- Đích chính xác của cấu hình: [`docs/inventory.md`](docs/inventory.md).

## Thứ tự làm

### 0. Kiểm tra môi trường

```sh
uname -s -m                 # Linux x86_64 hoặc aarch64
command -v curl git         # phải có
command -v node && node -v  # cần ≥ 20 cho OpenChamber
df -h "$HOME" | tail -1     # cần ≥ 1.5 GB trống
```

Thiếu node trên Cloud Shell: nó có nvm ở `/usr/local/nvm`; `scripts/install-openchamber.sh`
tự tìm. Đừng cài node bằng sudo nếu không cần.

### 1. Cài (không cần con người)

Cách nhanh:

```sh
bash bootstrap.sh
```

Muốn magpie build từ **repo chính chủ** (<https://github.com/yetone/magpie>) thay vì bản
dựng sẵn — người dùng yêu cầu, hoặc cần bản mới nhất từ source:

```sh
bash bootstrap.sh --from-source     # clone + make cli + install vào ~/.local/bin
# tương đương:
#   git clone https://github.com/yetone/magpie.git ~/.local/src/magpie
#   cd ~/.local/src/magpie && make cli && install -m755 magpie ~/.local/bin/magpie
#   cd - && bash bootstrap.sh        # bootstrap thấy magpie rồi thì bỏ qua bước cài
```

Nếu người dùng chỉ muốn gateway (không OpenCode/OpenChamber): `bash bootstrap.sh --minimal`.

Kiểm tra:

```sh
magpie --version                  # có số phiên bản
magpie healthcheck && echo ok     # exit 0
magpie plugin list                # 6 plugin, "on"
command -v openchamber openmagpie magpie-headless-start
```

`bootstrap.sh` chạy lại được nhiều lần; bước nào có rồi thì bỏ qua.

### 2. Nhờ con người đăng nhập (bạn không làm được)

Nói rõ, bằng ngôn ngữ của họ, rồi chờ:

> Cần đăng nhập provider — đây là phần duy nhất phải làm tay. **Trên Cloud Shell, làm
> qua web UI của magpie, không phải qua CLI** (trình duyệt của bạn không ở cùng máy):
>
> - `openmagpie` → mở link (đã kèm key) → Settings → Providers → Add provider →
>   **AutoClaw (Zhipu)** → Sign in → chọn Google/z.ai.
> - Làm slider Aliyun và uỷ quyền. Trình duyệt sẽ dừng ở
>   `http://localhost:<cổng>/auth/callback-…`; trang đó không load được — **copy nguyên
>   địa chỉ, dán vào ô `Callback URL`** trong hộp đăng nhập của magpie, Enter.
> - Tương tự cho WorkBuddy AI và Qoder (cũng trong web UI).
> - Hoặc dán API key OpenCode Zen / Kilo: `bash scripts/login.sh keys`.
> - Muốn dùng CLI thật thì cần SSH tunnel trước — `docs/autoclaw-login.md` Cách B.
>
> Xong thì báo tôi.

`login.sh` tự chạy `finish.sh` sau mỗi lần đăng nhập thành công, nên không cần bước nào thêm.
Thêm `--no-finish` nếu muốn tách ra. Trên máy headless, `login.sh autoclaw` chỉ in hướng dẫn
rồi thoát (không treo chờ callback); thêm `--cli` nếu bạn đã mở tunnel.

Không hỏi mật khẩu. Không ghi key vào file trong repo. Key người dùng đưa thì chỉ dùng
trên dòng lệnh: `magpie provider add opencode-zen <key>`.

### 3. Xem cái gì đã về

```sh
magpie providers        # từng provider: đã đăng nhập / key, số model
magpie accounts         # subscription + quota còn lại
magpie models | head -40
```

Provider còn "not signed in" thì bỏ qua — group chỉ dựng từ model thật sự có.

### 4. Group + agent (đã tự chạy — chỉ kiểm tra)

`login.sh` đã gọi `finish.sh` (= `setup-groups.sh --force` + `setup-agents.sh` + `doctor.sh`)
sau mỗi lần đăng nhập. Nếu người dùng đăng nhập qua **web UI** (cách dùng trên Cloud Shell),
`openmagpie` / `openchamber` tự gọi `magpie-finish` một lần khi thấy có model mà chưa có
`group/main`. Chạy tay khi cần:

```sh
magpie-finish          # bản cài
bash scripts/finish.sh # từ repo
```

Kiểm tra:

```sh
magpie group main      # 8 (hoặc ít hơn) model theo thứ tự, rule images + compact, levels, classifier
magpie group code      # rule 4 intent + images
magpie opencode        # model: magpie/group/main
magpie openchamber     # model: magpie/group/main
```

`setup-groups.sh` bỏ rule nếu model của rule không có trong group, nên cấu hình một phần
vẫn chạy. Đăng nhập thêm provider → chạy lại `finish.sh` để lấp ladder.

### 5. Bàn giao

```sh
openchamber
```

in 2 link đã kèm key. Nói cho người dùng:

- `openchamber` → magpie + OpenChamber (UI code), in cả hai link.
- `openmagpie` → chỉ magpie.
- `magpie-headless-status` → link + key nếu lạc mất.
- Agent đang chạy phải mở phiên mới mới nhận model mới.

### 6. (Tuỳ chọn) kiểm tra sâu

```sh
bash scripts/doctor.sh          # bảng ✓/!/✗ toàn bộ
magpie quota                    # credit từng tài khoản
magpie provider test autoclaw zai_auto
```

## Quy tắc

- Không chạy `magpie` bằng `sudo`.
- Không sửa tay file trong `~/.config/magpie` (provider, group, library…): dùng lệnh
  `magpie` — nó khoá file và ghi lại cấu hình agent cho khớp.
- Không đăng nhập/huỷ đăng nhập thay người dùng, không đổi tài khoản của họ.
- `magpie group add <tên đã dùng>` **thay** group đó. `setup-groups.sh` chỉ thay khi có
  `--force`; chỉ dùng `--force` khi người dùng muốn reset group.
- Không chạy `magpie daemon install` (không có user bus) và không dùng `magpie web` trực
  tiếp cho link bookmark (key đổi mỗi lần) — dùng `openmagpie`/`openchamber`.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key nào.

## Lỗi thường gặp và cách sửa

| Triệu chứng | Nguyên nhân | Sửa |
|---|---|---|
| `magpie: command not found` | `~/.local/bin` không có trên PATH | `export PATH="$HOME/.local/bin:$PATH"`, mở shell mới, hoặc chạy lại `bootstrap.sh` |
| `systemctl --user … No medium found` | Cloud Shell không có user bus | đúng như dự kiến: repo dùng supervisor, không systemd |
| `plugin add` treo/lỗi | bun chưa tải xong | `magpie plugin update`, `magpie plugin list`; kiểm tra dung lượng (~200 MB) |
| `magpie plugin login autoclaw` in URL `127.0.0.1` mà không mở được | trình duyệt không ở cùng máy | forward cổng, `docs/autoclaw-login.md` cách A |
| `本地端口 … 均被占用` | AutoClaw desktop/TokenServer giữ cổng | tắt app đó |
| AutoClaw `406 Not Acceptable` | shape request | plugin tự vá; `magpie plugin update` |
| AutoClaw bị "kicked" | cùng tài khoản đăng nhập ở desktop | chỉ dùng một nơi |
| Web hỏi key | mở link không có `?k=` | dùng link đã in, hoặc `magpie-headless-status` |
| Gateway chết theo terminal | chạy foreground | `magpie-headless-start` (setsid + supervisor) |
| Cloud Shell restart, không có gì chạy | thiếu hook `.bashrc` | `bash bootstrap.sh` thêm lại |
| `openchamber` không in link | PATH: binary npm che wrapper | `command -v openchamber` phải là `~/.local/bin/openchamber` |
| Model list rỗng trong OpenCode | gateway chưa chạy | `openmagpie` rồi `magpie healthcheck` |
| Subagent `coder` lỗi model | chưa có Kilo | `setup-opencode.sh` đã lùi về `group/main`; hoặc sửa dòng `model:` |

## Cái gì vẫn thuộc về con người

- Tài khoản provider (đăng nhập, quota, điểm danh hằng ngày).
- API key OpenCode Zen / Kilo.
- Quyết định dùng plugin cộng đồng — không chính thức, có thể hỏng hoặc bị ban tài khoản.
  Nói một lần, thẳng, rồi thôi.
- Dữ liệu của họ: repo này không chứa gì bí mật.
