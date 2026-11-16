#!/usr/bin/env bash
# kiro-link.sh — đăng nhập Kiro (app.kiro.dev, Google/GitHub) vào magpie khi
# magpie chạy trên Cloud Shell / máy headless, trình duyệt ở máy khác.
#
#   bash scripts/kiro-link.sh                    mở phiên, in link đăng nhập
#   bash scripts/kiro-link.sh --status           phiên đang chờ / xong / lỗi
#   bash scripts/kiro-link.sh --callback '<url>' nộp địa chỉ trình duyệt dừng lại
#   bash scripts/kiro-link.sh --watch            chờ tới khi xong rồi in tài khoản
#   bash scripts/kiro-link.sh --cancel           huỷ phiên đang chờ
#
# Vì sao cần: trang đăng nhập Kiro chuyển trình duyệt về
# http://localhost:<cổng>/oauth/callback?code=…&state=… trên **máy chạy
# magpie**. Trên laptop, localhost đó là laptop của bạn — trang không mở được.
# Copy nguyên địa chỉ trên thanh địa chỉ rồi nộp lại bằng --callback; magpie tự
# đổi code lấy token và lưu tài khoản.
#
# Phiên sống 10 phút (plugin tự đóng); hết thì chạy lại script để lấy link mới.
# Script giữ tiến trình `magpie plugin login kiro` trong nền (setsid) nên link
# không chết theo terminal — nhưng chết nếu máy restart.
set -uo pipefail

PATH="$HOME/.local/bin:$PATH"
export PATH

STATE="$HOME/.local/state/magpie"
DIR="$STATE/kiro-signin"
LOG="$DIR/log"
FIFO="$DIR/in"
PIDF="$DIR/pid"
KEEPERF="$DIR/keeper"
PORTF="$DIR/port"
BUNPIDF="$DIR/bunpid"
URLF="$DIR/url"

say()  { printf '  %s\n' "$*"; }
bold() { printf '  \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; }

# cleanup — đóng phiên: magpie CLI, tiến trình bun giữ cổng (nó tự setsid nên
# không chết theo cha), và tiến trình giữ FIFO mở.
cleanup() {
  local pid bp
  pid="$(cat "$PIDF" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    sleep 0.3
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
  fi
  bp="$(cat "$BUNPIDF" 2>/dev/null || true)"
  [ -n "$bp" ] && kill -KILL "$bp" 2>/dev/null
  if [ -f "$KEEPERF" ]; then
    kill "$(cat "$KEEPERF")" 2>/dev/null
  fi
  rm -f "$PIDF" "$KEEPERF" "$FIFO" "$URLF" "$PORTF" "$BUNPIDF"
}

port_of() { # <url> — cổng trong redirect_uri=http%3A%2F%2Flocalhost%3A<port>
  printf '%s' "$1" | grep -oE 'redirect_uri=http%3A%2F%2Flocalhost%3A[0-9]+' \
    | grep -oE '[0-9]+$'
}

show_link() { # <url>
  local url=$1 port
  port="$(port_of "$url")"
  printf '\n'
  ok "phiên đăng nhập Kiro đã mở"
  printf '\n'
  bold "Link đăng nhập (bấm vào):"
  printf '\n    %s\n\n' "$url"
  bold "Các bước"
  say "  1. Mở link ở trên bằng trình duyệt trên laptop/điện thoại."
  say "  2. Chọn Google (đúng Gmail bạn muốn dùng), đồng ý cho Kiro."
  say "  3. Trình duyệt dừng ở http://localhost:${port:-<cổng>}/oauth/callback?code=…&state=…"
  say "     Trang đó KHÔNG mở được — đúng như vậy (localhost của bạn, không phải máy này)."
  say "     Copy NGUYÊN địa chỉ trên thanh địa chỉ."
  printf '  4. Nộp lại: \033[1mbash scripts/kiro-link.sh --callback '"'"'<địa chỉ vừa copy>'"'"'\033[0m\n'
  say "     (hoặc dán địa chỉ đó vào chat cho tôi)."
  printf '\n'
  say "Link sống 10 phút; hết hạn thì chạy lại script để lấy link mới."
  printf '\n'
}

start() {
  mkdir -p "$DIR"
  if alive; then
    local u
    u="$(cat "$URLF" 2>/dev/null || true)"
    if [ -n "$u" ]; then show_link "$u"; return 0; fi
  fi
  cleanup
  rm -f "$LOG"
  mkfifo "$FIFO"

  # giữ đầu ghi của FIFO mở, để CLI không thấy EOF sau mỗi lần ghi
  setsid bash -c "echo \$\$ > '$KEEPERF'; exec sleep 900 > '$FIFO'" \
    </dev/null >/dev/null 2>&1 &
  # phiên đăng nhập: 1 = Kiro, 3 = trang đăng nhập (Google/GitHub)
  setsid bash -c "echo \$\$ > '$PIDF'; exec magpie plugin login kiro < '$FIFO' > '$LOG' 2>&1" \
    </dev/null >/dev/null 2>&1 &

  sleep 0.5
  printf '1\n3\n' > "$FIFO"

  local n=0 url=""
  while [ "$n" -lt 60 ]; do
    url="$(grep -oE 'https://app\.kiro\.dev/signin\?[^[:space:]]+' "$LOG" 2>/dev/null | head -1)"
    [ -n "$url" ] && break
    sleep 0.5; n=$((n+1))
  done
  if [ -z "$url" ]; then
    warn "không lấy được link đăng nhập:"
    tail -20 "$LOG" 2>/dev/null | sed 's/^/    /'
    cleanup
    exit 1
  fi

  printf '%s' "$url" > "$URLF"
  printf '%s' "$(port_of "$url")" > "$PORTF"
  sleep 0.5
  # tiến trình bun của phiên này, để dọn cổng sau khi xong
  local bp
  bp="$(ss -ltnp 2>/dev/null | grep -E "127\.0\.0\.1:$(cat "$PORTF")\b" \
    | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)"
  [ -n "$bp" ] && printf '%s' "$bp" > "$BUNPIDF"
  show_link "$url"
}

# result — in kết quả nếu phiên đã xong; trả 0 khi xong, 1 khi còn chờ
result() {
  local line
  line="$(grep -E "signed in to Kiro|is now signed in as" "$LOG" 2>/dev/null | tail -1)"
  if [ -n "$line" ]; then
    printf '\n'
    ok "$(printf '%s' "$line" | sed -E 's/^.*(signed in to Kiro|is now signed in as) /\1 /')"
    printf '\n'
    say "kiểm tra: magpie plugin list | grep -A1 kiro"
    printf '\n'
    return 0
  fi
  return 1
}

do_callback() { # <url>
  local url=${1:-}
  [ -n "$url" ] || die "thiếu URL: --callback '<địa chỉ trình duyệt dừng lại>'"
  alive || die "phiên đã hết (quá 10 phút) — chạy lại script để lấy link mới"
  case "$url" in
    http://*|https://*) ;;
    localhost:*|127.0.0.1:*) url="http://$url" ;;
    *) die "địa chỉ phải là http://localhost:<cổng>/oauth/callback?…" ;;
  esac
  printf '%s\n' "$url" > "$FIFO"

  local n=0
  while [ "$n" -lt 60 ]; do
    result && { sleep 0.5; cleanup; return 0; }
    if grep -qiE "isn't from this sign-in|this sign-in is over|didn't finish|was refused|timed out" "$LOG" 2>/dev/null; then
      warn "$(grep -iE "isn't from this sign-in|this sign-in is over|didn't finish|was refused|timed out" "$LOG" | tail -1)"
      return 1
    fi
    sleep 1; n=$((n+1))
  done
  warn "chưa thấy kết quả sau 60s — xem: tail -20 $LOG"
  return 1
}

do_watch() {
  alive || { result || die "không có phiên nào đang chờ"; return 0; }
  say "đang chờ đăng nhập xong… Ctrl-C để dừng."
  local n=0
  while [ "$n" -lt 600 ]; do
    result && { cleanup; return 0; }
    alive || { result || warn "phiên đã đóng mà chưa đăng nhập được"; return 1; }
    sleep 1; n=$((n+1))
  done
  warn "hết 10 phút vẫn chưa xong."
}

case "${1:-}" in
  ""|--start)   start ;;
  --status)
    if alive; then
      show_link "$(cat "$URLF" 2>/dev/null)"
    else
      result || warn "không có phiên nào đang chờ"
    fi ;;
  --callback)   do_callback "${2:-}" ;;
  --callback=*) do_callback "${1#--callback=}" ;;
  --watch)      do_watch ;;
  --cancel)     cleanup; ok "đã huỷ phiên" ;;
  -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)            printf 'tham số lạ: %s (xem --help)\n' "$1" >&2; exit 2 ;;
esac
