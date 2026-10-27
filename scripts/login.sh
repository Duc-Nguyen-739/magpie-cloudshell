#!/usr/bin/env bash
# login.sh — đăng nhập provider. Phần duy nhất mà con người phải làm.
#
#   bash scripts/login.sh              trạng thái từng provider
#   bash scripts/login.sh autoclaw     AutoClaw (Zhipu) — OAuth Google/z.ai
#   bash scripts/login.sh workbuddy    WorkBuddy AI
#   bash scripts/login.sh qoder        Qoder
#   bash scripts/login.sh zcode        ZCode
#   bash scripts/login.sh keys         dán API key (OpenCode Zen, Kilo)
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH — chạy bash bootstrap.sh trước"

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

# Cảnh báo chuyển tiếp cổng: server callback của AutoClaw chỉ nghe 127.0.0.1,
# nên trình duyệt phải ở cùng máy. Cloud Shell thì không.
headless_hint() {
  if [ -n "${WEB_HOST:-}" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }; then
    say ""
    warn "Máy này không có trình duyệt (headless). Cổng callback phải được chuyển tiếp."
    say "    Trên máy bạn, mở một phiên có forward 4 cổng rồi chạy lại lệnh này ở đó:"
    say ""
    say "      gcloud cloud-shell ssh --authorize-session \\"
    say "        --ssh-flag=\"-L 18432:127.0.0.1:18432\" \\"
    say "        --ssh-flag=\"-L 19654:127.0.0.1:19654\" \\"
    say "        --ssh-flag=\"-L 19723:127.0.0.1:19723\" \\"
    say "        --ssh-flag=\"-L 53699:127.0.0.1:53699\""
    say ""
    say "    (hoặc đăng nhập trên máy có desktop rồi magpie backup → magpie restore)"
    say "    Chi tiết: docs/autoclaw-login.md"
    say ""
  fi
}

case "${1:-status}" in
  status|"")
    status
    ;;

  autoclaw)
    say "AutoClaw (Zhipu) — chọn 1 = Google, 2 = z.ai, rồi làm theo trang mở ra."
    headless_hint
    exec magpie plugin login autoclaw
    ;;

  autoclaw-cn)
    say "AutoClaw 国内 — đăng nhập bằng số điện thoại +86 (nhận SMS)."
    exec magpie plugin login autoclaw-cn
    ;;

  workbuddy)
    say "WorkBuddy AI — chọn 'account (browser)' để đăng nhập trên web."
    headless_hint
    exec magpie plugin login workbuddy-ai
    ;;

  qoder)
    say "Qoder — đăng nhập trên trang của Qoder."
    headless_hint
    exec magpie plugin login qoder
    ;;

  zcode)
    say "ZCode — tuỳ chọn, không bắt buộc."
    exec magpie plugin login zcode
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
    ;;

  -h|--help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "không biết provider '$1' (autoclaw, autoclaw-cn, workbuddy, qoder, zcode, keys, status)"
    ;;
esac
