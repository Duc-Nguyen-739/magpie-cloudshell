#!/usr/bin/env bash
# autoclaw-link.sh — in "link localhost" để mở trang đăng nhập AutoClaw từ laptop
# khi magpie chạy trên Cloud Shell / máy headless.
#
#   bash scripts/autoclaw-link.sh              in link cho cổng đang mở (hoặc cả 4)
#   bash scripts/autoclaw-link.sh --watch      chờ tới khi magpie mở cổng rồi in
#   bash scripts/autoclaw-link.sh --port 18432 chỉ định cổng
#   bash scripts/autoclaw-link.sh --tunnel     in lệnh ssh -L thay vì link preview
#
# Vì sao cần: plugin AutoClaw mở server tạm trên 127.0.0.1:<cổng> của **máy chạy
# magpie**. Trình duyệt của bạn ở máy khác, nên 127.0.0.1 đó là laptop của bạn —
# không phải Cloud Shell. Cloud Shell có preview cho mọi cổng:
#   https://<cổng>-<WEB_HOST>/   →  chuyển tiếp vào 127.0.0.1:<cổng> của máy này.
set -uo pipefail

PORTS=(18432 19654 19723 53699)   # port pool của OAuth client chính thức
WATCH=0
TUNNEL=0
WANT_PORT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --watch)  WATCH=1 ;;
    --tunnel) TUNNEL=1 ;;
    --port)   WANT_PORT="${2:-}"; shift ;;
    --port=*) WANT_PORT="${1#--port=}" ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'tham số lạ: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '  %s\n' "$*"; }
bold() { printf '  \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

# Cổng đang LISTEN? Dùng bash /dev/tcp để không phụ thuộc ss/lsof.
listening() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3<&- 3>&-; return 0; }
  return 1
}

find_port() {
  local p
  for p in "${PORTS[@]}"; do listening "$p" && { printf '%s' "$p"; return 0; }; done
  return 1
}

preview_url() { # <port>
  if [ -n "${WEB_HOST:-}" ]; then printf 'https://%s-%s/' "$1" "$WEB_HOST"
  else printf 'http://127.0.0.1:%s/' "$1"; fi
}

show() { # <port>
  local port=$1
  local prev local_url
  prev="$(preview_url "$port")"
  local_url="http://127.0.0.1:$port/"

  printf '\n'
  if [ "$TUNNEL" = 1 ]; then
    ok "Lệnh tunnel cho cổng $port (chạy trên laptop của bạn):"
    say ""
    say "    ssh -L $port:127.0.0.1:$port <user@may-chay-magpie>"
    say ""
    say "  Rồi mở: $local_url"
  elif [ -n "${WEB_HOST:-}" ]; then
    ok "Link mở từ laptop (Cloud Shell preview, cổng $port):"
    say ""
    say "    $prev"
    say ""
    say "  Link gốc trên máy này (chỉ dùng khi có tunnel): $local_url"
  else
    warn "Không thấy \$WEB_HOST — máy này không phải Cloud Shell."
    say "  Mở trực tiếp: $local_url"
    say "  Hoặc dùng --tunnel để lấy lệnh ssh -L."
  fi

  printf '\n'
  bold "Các bước đăng nhập"
  say "  1. Trong magpie: Settings → Providers → Add provider → AutoClaw (Zhipu) → Sign in."
  say "  2. Mở link ở trên, chọn Google hoặc z.ai, qua slider Aliyun rồi uỷ quyền."
  say "  3. Trình duyệt sẽ dừng ở http://localhost:$port/auth/callback-… (trang không load"
  say "     được — đúng như vậy). Copy NGUYÊN địa chỉ trên thanh địa chỉ."
  printf '    4. Dán vào ô \033[1mCallback URL\033[0m trong hộp đăng nhập của magpie, Enter.\n'
  say "       Tài khoản hiện ra là xong."
  printf '\n'
}

# --------------------------------------------------------------- chọn cổng
if [ -n "$WANT_PORT" ]; then
  listening "$WANT_PORT" || warn "cổng $WANT_PORT chưa mở (magpie chưa bắt đầu phiên đăng nhập?)"
  show "$WANT_PORT"
  exit 0
fi

port="$(find_port || true)"

if [ -z "$port" ] && [ "$WATCH" = 1 ]; then
  say "Đang chờ magpie mở cổng đăng nhập (18432/19654/19723/53699)… Ctrl-C để dừng."
  say "Bấm Sign in trong web UI bây giờ."
  n=0
  while [ -z "$port" ] && [ $n -lt 300 ]; do
    sleep 2; n=$((n+1))
    port="$(find_port || true)"
  done
  [ -n "$port" ] && ok "thấy cổng $port" || { warn "10 phút không thấy cổng nào mở."; exit 1; }
fi

if [ -n "$port" ]; then
  show "$port"
  exit 0
fi

# Chưa có phiên nào: in sẵn cả 4 link để dùng khi magpie mở cổng.
warn "Chưa có phiên đăng nhập nào đang mở (không cổng nào trong ${PORTS[*]} listen)."
say "Bấm Sign in trong web UI rồi chạy lại với --watch, hoặc dùng sẵn link dưới đây"
say "ứng với cổng mà magpie hiện trong hộp đăng nhập:"
for p in "${PORTS[@]}"; do
  printf '    cổng %-5s → %s\n' "$p" "$(preview_url "$p")"
done
printf '\n'
say "Chi tiết: docs/autoclaw-login.md"
