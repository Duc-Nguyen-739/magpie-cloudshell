#!/usr/bin/env bash
# login.sh — đăng nhập provider. Phần duy nhất mà con người phải làm.
# Đăng nhập xong, script tự tạo/cập nhật routing group và trỏ agent (finish.sh).
#
#   bash scripts/login.sh              trạng thái từng provider
#   bash scripts/login.sh autoclaw     AutoClaw (Zhipu) — OAuth Google/z.ai
#   bash scripts/login.sh workbuddy    WorkBuddy AI
#   bash scripts/login.sh qoder        Qoder
#   bash scripts/login.sh zcode        ZCode
#   bash scripts/login.sh keys         dán API key (OpenCode Zen, Kilo)
#
#   thêm --no-finish để không tự chạy finish.sh sau khi đăng nhập
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NO_FINISH=0
CLI_FORCE=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --no-finish) NO_FINISH=1 ;;
    --cli)       CLI_FORCE=1 ;;
    *)           ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}
[ $# -eq 0 ] && set -- status
HEADLESS=0

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH — chạy bash bootstrap.sh trước"

# Sau khi có provider mới: tạo group + trỏ agent, để "đăng nhập là xong".
finish_after() {
  [ "$NO_FINISH" = 1 ] && return 0
  if [ -x "$REPO_DIR/scripts/finish.sh" ]; then
    say ""
    say "cập nhật routing group + agent theo provider vừa có…"
    bash "$REPO_DIR/scripts/finish.sh" || warn "finish.sh lỗi — chạy lại: bash scripts/finish.sh"
  fi
}

status() {
  say "Provider:"
  magpie providers 2>/dev/null | sed 's/^/  /'
  say ""
  say "Tài khoản đã đăng nhập:"
  magpie accounts 2>/dev/null | sed 's/^/  /'
  say ""
  say "Plugin:"
  magpie plugin list 2>/dev/null | sed 's/^/  /'
  say ""
  say "Đăng nhập: bash scripts/login.sh autoclaw|workbuddy|qoder|zcode|keys"
}

# Server callback của AutoClaw chỉ nghe 127.0.0.1, nên trình duyệt phải ở cùng máy.
# Trên Cloud Shell, cách đã dùng là đăng nhập qua web UI rồi dán Callback URL.
headless_hint() {
  if [ -n "${WEB_HOST:-}" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }; then
    HEADLESS=1
    say ""
    warn "Máy này không có trình duyệt. Cách gọn nhất: đăng nhập qua web UI của magpie."
    say ""
    say "  1. Mở link web UI (đã kèm key):   openmagpie"
    say "  2. Settings → Providers → Add provider → AutoClaw (Zhipu) → Sign in"
    say "     chọn Google hoặc z.ai"
    say "  3. Trang đăng nhập chạy trên 127.0.0.1:<cổng> của máy này. Nếu laptop không mở"
    say "     được link đó, mở cùng đường dẫn qua preview:  https://<cổng>-<WEB_HOST>/"
    say "     (cổng là 18432 / 19654 / 19723 / 53699)"
    say "  4. Uỷ quyền xong, trình duyệt bị đẩy tới http://localhost:<cổng>/auth/callback-…"
    say "     và trang đó KHÔNG load được (localhost là laptop của bạn). Copy nguyên địa"
    say "     chỉ trên thanh địa chỉ, dán vào ô Callback URL trong hộp đăng nhập, Enter."
    say ""
    say "  Chi tiết từng bước: docs/autoclaw-login.md (Cách A)."
    say ""
    say "  Nếu muốn luồng CLI tự khép kín, dùng SSH tunnel (Cách B) từ máy bạn:"
    say "      gcloud cloud-shell ssh --authorize-session \\"
    say "        --ssh-flag=\"-L 18432:127.0.0.1:18432\" \\"
    say "        --ssh-flag=\"-L 19654:127.0.0.1:19654\" \\"
    say "        --ssh-flag=\"-L 19723:127.0.0.1:19723\" \\"
    say "        --ssh-flag=\"-L 53699:127.0.0.1:53699\""
    say "    rồi chạy lệnh login trong phiên SSH đó."
    say ""
  fi
}

case "$1" in
  status)
    status
    ;;

  autoclaw)
    say "AutoClaw (Zhipu) — chọn 1 = Google, 2 = z.ai, rồi làm theo trang mở ra."
    headless_hint
    if [ "$HEADLESS" = 1 ] && [ "$CLI_FORCE" != 1 ]; then
      say "→ Làm theo Cách A ở trên (web UI + dán Callback URL). Không cần chạy CLI."
      say "  Muốn chạy CLI thật thì thêm --cli (mở tunnel trước)."
      exit 0
    fi
    magpie plugin login autoclaw || exit $?
    finish_after
    ;;

  autoclaw-cn)
    say "AutoClaw 国内 — đăng nhập bằng số điện thoại +86 (nhận SMS)."
    magpie plugin login autoclaw-cn || exit $?
    finish_after
    ;;

  workbuddy)
    say "WorkBuddy AI — chọn 'account (browser)' để đăng nhập trên web."
    headless_hint
    if [ "$HEADLESS" = 1 ] && [ "$CLI_FORCE" != 1 ]; then
      say "→ Dùng web UI (Cách A ở trên). Muốn chạy CLI: thêm --cli."
      exit 0
    fi
    magpie plugin login workbuddy-ai || exit $?
    finish_after
    ;;

  qoder)
    say "Qoder — đăng nhập trên trang của Qoder."
    headless_hint
    if [ "$HEADLESS" = 1 ] && [ "$CLI_FORCE" != 1 ]; then
      say "→ Dùng web UI (Cách A ở trên). Muốn chạy CLI: thêm --cli."
      exit 0
    fi
    magpie plugin login qoder || exit $?
    finish_after
    ;;

  zcode)
    say "ZCode — tuỳ chọn, không bắt buộc."
    magpie plugin login zcode || exit $?
    finish_after
    ;;

  keys)
    say "API key (không cần trình duyệt). Enter để bỏ qua cái nào không có."
    say ""
    printf '  OpenCode Zen key (oc_…): '
    read -r zen || true
    if [ -n "${zen:-}" ]; then
      magpie provider add opencode-zen "$zen" && ok "đã thêm opencode-zen"
    fi
    printf '  Kilo key (eyJ…): '
    read -r kilo || true
    if [ -n "${kilo:-}" ]; then
      magpie provider add kilo "$kilo" && ok "đã thêm kilo"
    fi
    say ""
    say "Kiểm tra: magpie providers && magpie provider test opencode-zen"
    finish_after
    ;;

  -h|--help)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "không biết provider '$1' (autoclaw, autoclaw-cn, workbuddy, qoder, zcode, keys, status)"
    ;;
esac
