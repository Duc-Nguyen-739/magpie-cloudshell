# Cloud Shell / máy headless — chi tiết

Cloud Shell không có desktop, không có systemd user bus, `$HOME` giữ được nhưng
`/usr/local` thì mất khi máy bị thu hồi. Vì vậy mọi thứ ở đây nằm trong `$HOME` và
được giữ sống bằng một supervisor bash.

## Vì sao không dùng `magpie daemon install`

Nó ghi một unit systemd `--user`:

```
magpie: systemctl --user daemon-reload: Failed to connect to bus: No medium found
```

Cloud Shell không có user bus. Tương tự, `magpie web` tạo **key mới mỗi lần chạy**, làm
hỏng link đã bookmark. Repo này dùng `magpie serve --web=…` với `MAGPIE_WEB_KEY` cố định.

## Kiến trúc

```
.bashrc (shell đầu tiên)
   └─ magpie-headless-start        (trả về ngay, không chặn shell)
        └─ setsid magpie-headless  (vòng lặp supervisor, pid trong headless.pid)
             └─ magpie serve --web=0.0.0.0:3430
                  ├─ gateway 127.0.0.1:3425
                  └─ web UI  0.0.0.0:3430  (cần ?k=<web-key>)
```

Supervisor chết → `magpie-headless-start` lần sau bật lại. `magpie serve` chết → vòng lặp
restart sau 3 giây. VM bị thu hồi → hook `.bashrc` bật lại ở shell đầu tiên.

## Cổng và biến môi trường

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `MAGPIE_ADDR` | `127.0.0.1:3425` | địa chỉ gateway |
| `MAGPIE_WEB_ADDR` | `0.0.0.0:3430` | địa chỉ web UI (0.0.0.0 để Cloud Shell preview vào được) |
| `MAGPIE_WEB_PORT` | `3430` | chỉ đổi cổng web, dùng trong script |
| `MAGPIE_WEB_KEY` | đọc từ `~/.config/magpie/web-key` | key cố định, giữ link không đổi |
| `OPENCHAMBER_PORT` | `3000` | cổng OpenChamber |
| `WEB_HOST` | Cloud Shell đặt sẵn | host preview, dùng để in link `https://<port>-<host>/` |
| `MAGPIE_HEADLESS_QUIET` | — | đặt `1` để shell không tự bật magpie |

Đổi cổng:

```sh
MAGPIE_WEB_ADDR=0.0.0.0:3431 MAGPIE_ADDR=127.0.0.1:3426 magpie-headless-start
```

## Key và link

- Key sinh một lần: `head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > ~/.config/magpie/web-key` (quyền 600).
- `openmagpie` / `openchamber` đọc key đó và in link **đã kèm `?k=`** — bấm là vào, không phải dán.
- Trên Cloud Shell, link là `https://<port>-$WEB_HOST/?k=…` (preview proxy). Không có
  `WEB_HOST` thì là `http://127.0.0.1:<port>/?k=…`.
- Mở web UI không có `?k=` → 401. `magpie-headless-status` in lại key.

## PATH — cái bẫy đã gặp

`.bashrc` mặc định của Cloud Shell đặt `~/.npm-global/bin` **trước** `~/.local/bin`, nên
binary `openchamber` của npm che mất wrapper in-link. Repo này thêm khối:

```sh
# >>> magpie-cloudshell >>>
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"
if [ -z "${MAGPIE_HEADLESS_QUIET:-}" ] && [ -x "$HOME/.local/bin/magpie-headless-start" ]; then
  "$HOME/.local/bin/magpie-headless-start" >/dev/null 2>&1
fi
# <<< magpie-cloudshell <<<
```

Nếu `openchamber` hành xử như CLI npm (không in link), kiểm tra `command -v openchamber`
— phải là `~/.local/bin/openchamber`.

## Giết tiến trình đúng cách

`pkill -f "magpie serve"` khớp cả shell đang gõ câu đó và tự giết mình. Script trong repo
dùng pid (`headless.pid`) hoặc pattern neo ở argv[0]: `pgrep -f '^magpie serve'`.

## Log và trạng thái

```sh
magpie-headless-status          # pid, gateway, health, link
tail -f ~/.local/state/magpie/headless.log
magpie-headless-stop            # dừng cả supervisor và gateway
```

## Đăng nhập provider trên Cloud Shell

OAuth của AutoClaw/WorkBuddy/Qoder kết thúc bằng một redirect về
`http://localhost:<cổng>` — "localhost" đó là **máy bạn**, không phải Cloud Shell, nên
trang cuối không load được. Magpie web UI có sẵn ô **Callback URL** để dán địa chỉ đó:
magpie gọi ngược vào server tạm của plugin (trên máy nó) và hoàn tất đăng nhập.

**Không cần SSH tunnel.** Đây là luồng đã dùng trên máy tham chiếu:

1. `openmagpie` → mở link preview (đã kèm key).
2. **Settings → Providers → Add provider → AutoClaw (Zhipu) → Sign in** → chọn Google/z.ai.
3. Trang đăng nhập của plugin chạy trên `127.0.0.1:<cổng>` của Cloud Shell. Nếu laptop
   không mở được link đó, mở cùng đường dẫn qua preview: `https://<cổng>-<WEB_HOST>/`
   (Cloud Shell cho preview mọi cổng; cổng là 18432 / 19654 / 19723 / 53699).
   Để script in hộ link: `bash scripts/autoclaw-link.sh --watch` (bản cài: `autoclaw-link`).
4. Làm slider Aliyun → đăng nhập → uỷ quyền.
5. Trình duyệt dừng ở `http://localhost:<cổng>/auth/callback-…` (trang trắng / lỗi).
   **Copy nguyên địa chỉ trên thanh địa chỉ**, dán vào ô **Callback URL** trong hộp đăng
   nhập của magpie, Enter. Tài khoản hiện ra trong danh sách.

Chính UI của magpie nói điều này khi chạy trên server/Docker:
*"If the page the browser ends on won't load (magpie runs on a server or in Docker),
copy its whole address and paste it here and press Enter."*

Trong terminal headless, `bash scripts/login.sh autoclaw` chỉ **in hướng dẫn rồi thoát**
(không treo chờ callback). Thêm `--cli` nếu bạn đã mở tunnel và muốn chạy luồng CLI.

## Chia sẻ gateway cho máy khác

Hai cách, chọn một:

**Gateway key (magpie hỗ trợ sẵn)** — bật Settings → Network and sharing → Share on local
network, rồi:

```sh
magpie gateway-key add laptop
magpie gateway-key limit <id> month --cost 20
magpie gateway-key models <id> 'autoclaw/*' group/main
```

Máy kia trỏ agent vào `http://<ip-máy-này>:3425/v1` với key đó.

**SSH tunnel (không mở cổng ra mạng)**:

```sh
ssh -L 3425:127.0.0.1:3425 -L 3430:127.0.0.1:3430 <máy-cloud-shell>
```

## Dung lượng

| Thứ | ~ |
|---|---|
| magpie binary | 55 MB |
| bun (cho plugin) | 180 MB |
| `@openchamber/web` | 290 MB |
| OpenCode binary + node_modules | 300 MB |
| plugin + auth + config | < 20 MB |

Tổng ~800 MB. Nếu `/home` chật, xoá `~/.cache/magpie/bun/*` khi không dùng plugin nữa
(magpie sẽ tải lại khi cần), và log cũ trong `~/.codeoss/data/logs/`.

## Tài liệu chính thức

- magpie: <https://github.com/yetone/magpie>
- bắt đầu: <https://usemagpie.ai/docs/start>
- tham chiếu đầy đủ (mọi lệnh, mọi field): <https://github.com/yetone/magpie/blob/main/docs/reference.md>
- plugin: <https://github.com/magpie-community/plugins>
- Docker (nếu muốn chạy trên server/NAS thay vì Cloud Shell): <https://usemagpie.ai/docs/docker>
- Discord: <https://discord.gg/vGSnD3ZKQF>
