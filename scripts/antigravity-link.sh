#!/usr/bin/env bash
# antigravity-link.sh — đăng nhập Antigravity (Google) vào magpie khi magpie
# chạy trên Cloud Shell / máy headless, trình duyệt ở máy khác.
#
#   bash scripts/antigravity-link.sh              bắt đầu phiên, in link đăng nhập
#   bash scripts/antigravity-link.sh --status     phiên đang chờ / xong / lỗi
#   bash scripts/antigravity-link.sh --callback '<url>'
#                                                 nộp địa chỉ trình duyệt dừng lại
#   bash scripts/antigravity-link.sh --cancel     huỷ phiên đang chờ
#   bash scripts/antigravity-link.sh --watch      chờ tới khi xong rồi in tài khoản
#
# Vì sao cần: magpie mở một cổng 127.0.0.1:<ngẫu nhiên> trên **máy chạy
# magpie** và Google chuyển trình duyệt về
# http://localhost:<cổng>/oauth-callback?code=…&state=…
# Trên laptop, localhost đó là laptop của bạn — trang không mở được. Copy
# nguyên địa chỉ trên thanh địa chỉ rồi nộp lại bằng --callback; magpie tự
# đổi code lấy token. Phiên sống 10 phút, hết thì chạy lại lệnh này.
#
# Cảnh báo: Google có thể khoá tài khoản Antigravity bị thấy dùng ngoài
# Antigravity. Dùng tài khoản bạn chấp nhận mất được.
#
# Script nói chuyện với web UI của magpie (mặc định 127.0.0.1:3430, key ở
# ~/.config/magpie/web-key) — cùng đường mà nút "Add account" trong UI dùng,
# nên phiên nằm trong tiến trình magpie đang chạy, không chết theo terminal.
set -uo pipefail

CONF="$HOME/.config/magpie"
STATE="$HOME/.local/state/magpie"
PORT="${MAGPIE_WEB_PORT:-3430}"
JAR="$STATE/antigravity-signin.jar"
IDFILE="$STATE/antigravity-signin.id"
AGENT="antigravity"

say()  { printf '  %s\n' "$*"; }
bold() { printf '  \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

KEY="$(cat "$CONF/web-key" 2>/dev/null)"
[ -n "$KEY" ] || die "chưa có $CONF/web-key — chạy openmagpie trước"

# api <METHOD> <path> [json] — gọi web UI, trả body; in mã lỗi ra stderr
api() {
  local method=$1 path=$2 body=${3:-}
  local args=(-sS -b "$JAR" -c "$JAR" -X "$method" "http://127.0.0.1:$PORT/api/$path")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  curl "${args[@]}" 2>/dev/null
}

# login — lấy cookie từ ?k= (mỗi lần chạy, cookie hết hạn thì tự làm mới)
login() {
  mkdir -p "$STATE"
  curl -sS -c "$JAR" -o /dev/null "http://127.0.0.1:$PORT/?k=$KEY" 2>/dev/null \
    || die "không kết nối được web UI ở 127.0.0.1:$PORT — chạy openmagpie"
}

# field <json> <name> — một trường chuỗi của JSON trả về
field() {
  printf '%s' "$1" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
v=d.get(sys.argv[1],"")
print("" if v is None else v)' "$2" 2>/dev/null
}

status() { api GET "signin/$1"; }

print_steps() { # <port>
  local port=$1
  printf '\n'
  bold "Các bước"
  say "  1. Mở link ở trên bằng trình duyệt trên laptop/điện thoại."
  say "  2. Chọn tài khoản Google, đồng ý các quyền (cloud-platform, email, cclog…)."
  say "  3. Trình duyệt dừng ở http://localhost:$port/oauth-callback?code=…&state=…"
  say "     Trang đó KHÔNG mở được — đúng như vậy (localhost của bạn, không phải máy này)."
  say "     Copy NGUYÊN địa chỉ trên thanh địa chỉ."
  printf '  4. Nộp lại: \033[1mbash scripts/antigravity-link.sh --callback '"'"'<địa chỉ vừa copy>'"'"'\033[0m\n'
  say "  5. Kiểm tra: magpie accounts | grep -i antigravity"
  printf '\n'
  say "Link sống 10 phút; hết hạn thì chạy lại script để lấy link mới."
  say "Muốn tự làm trong UI: openmagpie → Providers → Add account → Antigravity,"
  say "rồi dán địa chỉ vào ô Callback URL — cùng một phiên."
  printf '\n'
}

start() {
  login
  local old
  old="$(cat "$IDFILE" 2>/dev/null || true)"
  if [ -n "$old" ]; then
    local st
    st="$(status "$old")"
    if [ "$(field "$st" state)" = "waiting" ]; then
      show "$st"
      return 0
    fi
  fi
  local st
  st="$(api POST "signin" "{\"agent\":\"$AGENT\"}")"
  local id url state
  id="$(field "$st" id)"; url="$(field "$st" url)"; state="$(field "$st" state)"
  if [ -z "$id" ] || [ -z "$url" ]; then
    warn "magpie không mở được phiên đăng nhập:"
    printf '%s\n' "$st" | head -c 400; printf '\n'
    exit 1
  fi
  printf '%s' "$id" > "$IDFILE"
  printf '%s\n' "$st" > "$STATE/antigravity-signin.json"
  printf '\n'
  ok "phiên đăng nhập Antigravity đã mở (id $id)"
  printf '\n'
  bold "Link đăng nhập (bấm vào):"
  say ""
  printf '    %s\n' "$url"
  local port
  port="$(printf '%s' "$url" | grep -oE 'redirect_uri=http%3A%2F%2Flocalhost%3A[0-9]+' | grep -oE '[0-9]+$')"
  print_steps "${port:-<cổng>}"
}

show() { # <json status>
  local url state
  url="$(field "$1" url)"; state="$(field "$1" state)"
  printf '\n'
  case "$state" in
    waiting|installing)
      ok "phiên đang chờ (state=$state)"
      printf '\n'
      bold "Link đăng nhập (bấm vào):"
      say ""
      printf '    %s\n' "$url"
      local port
      port="$(printf '%s' "$url" | grep -oE 'redirect_uri=http%3A%2F%2Flocalhost%3A[0-9]+' | grep -oE '[0-9]+$')"
      print_steps "${port:-<cổng>}" ;;
    done)
      ok "xong — tài khoản: $(field "$1" user) ${state:+· $(field "$1" plan)}"
      say "  kiểm tra: magpie accounts | grep -i antigravity" ;;
    *)
      warn "phiên đã kết thúc: $state $(field "$1" error)"
      say "  chạy lại script (không tham số) để mở phiên mới." ;;
  esac
  printf '\n'
}

do_callback() { # <url>
  local url=$1 st id
  case "$url" in
    localhost:*|127.0.0.1:*) url="http://$url" ;;
  esac
  id="$(cat "$IDFILE" 2>/dev/null || true)"
  [ -n "$id" ] || die "chưa có phiên nào — chạy script không tham số trước"
  login
  local body
  body="$(printf '{"url":"%s"}' "$(printf '%s' "$url" | sed 's/\\/\\\\/g; s/"/\\"/g')")"
  local res
  res="$(api POST "signin/$id/callback" "$body")"
  if [ -n "$res" ] && [ "$res" != "{}" ] && [ "$res" != "null" ]; then
    # lỗi được trả về dạng {"error":"…"} hoặc chuỗi
    local err
    err="$(field "$res" error)"
    [ -z "$err" ] && err="$(field "$res" message)"
    [ -n "$err" ] && { warn "$err"; exit 1; }
  fi
  # chờ magpie đổi code lấy token
  local n=0
  while [ "$n" -lt 60 ]; do
    st="$(status "$id")"
    case "$(field "$st" state)" in
      done) show "$st"; return 0 ;;
      failed|canceled)
        warn "không xong: $(field "$st" state) $(field "$st" error)"
        exit 1 ;;
    esac
    sleep 1; n=$((n+1))
  done
  warn "đã nộp callback nhưng magpie chưa xong sau 60s — xem --status"
  exit 1
}

do_watch() {
  local id st n=0
  id="$(cat "$IDFILE" 2>/dev/null || true)"
  [ -n "$id" ] || die "chưa có phiên nào — chạy script không tham số trước"
  login
  say "đang chờ phiên $id xong… Ctrl-C để dừng."
  while [ "$n" -lt 600 ]; do
    st="$(status "$id")"
    case "$(field "$st" state)" in
      done|failed|canceled) show "$st"; return 0 ;;
    esac
    sleep 2; n=$((n+1))
  done
  warn "hết 20 phút vẫn chưa xong."
}

case "${1:-}" in
  ""|--start)   start ;;
  --status)     login; id="$(cat "$IDFILE" 2>/dev/null || true)"; [ -n "$id" ] || die "chưa có phiên nào"; show "$(status "$id")" ;;
  --callback)   [ -n "${2:-}" ] || die "thiếu URL: --callback '<địa chỉ trình duyệt dừng lại>'"; do_callback "$2" ;;
  --callback=*) do_callback "${1#--callback=}" ;;
  --cancel)     login; id="$(cat "$IDFILE" 2>/dev/null || true)"; [ -n "$id" ] || die "chưa có phiên nào"; api POST "signin/$id/cancel" '{}' >/dev/null; rm -f "$IDFILE"; ok "đã huỷ" ;;
  --watch)      do_watch ;;
  -h|--help)    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)            printf 'tham số lạ: %s (xem --help)\n' "$1" >&2; exit 2 ;;
esac
