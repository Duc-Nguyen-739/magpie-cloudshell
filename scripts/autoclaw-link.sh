#!/usr/bin/env bash
# autoclaw-link.sh — in "link localhost" để mở trang đăng nhập AutoClaw từ laptop
# khi magpie chạy trên Cloud Shell / máy headless.
#
#   bash scripts/autoclaw-link.sh              in link cho cổng đang mở (hoặc cả 4)
#   bash scripts/autoclaw-link.sh --watch      chờ tới khi magpie mở cổng rồi in
#   bash scripts/autoclaw-link.sh --port 18432 chỉ định cổng
#   bash scripts/autoclaw-link.sh --tunnel     in lệnh ssh -L thay vì link preview
#   bash scripts/autoclaw-link.sh --relay      dựng relay bỏ Origin + cloudflared,
#                                              in link https://*.trycloudflare.com/
#   bash scripts/autoclaw-link.sh --callback '<url>'
#                                              gọi callback localhost trên máy này
#                                              (nhận cả dạng thiếu http://)
#
# Vì sao cần: plugin AutoClaw mở server tạm trên 127.0.0.1:<cổng> của **máy chạy
# magpie**. Trình duyệt của bạn ở máy khác, nên 127.0.0.1 đó là laptop của bạn —
# không phải Cloud Shell. Cloud Shell có preview cho mọi cổng:
#   https://<cổng>-<WEB_HOST>/   →  chuyển tiếp vào 127.0.0.1:<cổng> của máy này.
#
# Preview/tunnel thường gửi Origin: https://… nên plugin trả 403 forbidden origin ở
# /captcha và /open-auth. --relay dựng relay 127.0.0.1:$RELAY_PORT (mặc định 18080)
# bỏ Origin/Referer/Host rồi mới chuyển vào LOGIN_PORT, và mở relay ra ngoài bằng
# cloudflared (link https://*.trycloudflare.com). Callback vẫn là localhost nên phải
# gọi lại trên máy này bằng --callback.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PORTS=(18432 19654 19723 53699)   # port pool của OAuth client chính thức
WATCH=0
TUNNEL=0
RELAY=0
WANT_PORT=""
CALLBACK_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --watch)     WATCH=1 ;;
    --tunnel)    TUNNEL=1 ;;
    --relay)     RELAY=1 ;;
    --port)      WANT_PORT="${2:-}"; shift ;;
    --port=*)    WANT_PORT="${1#--port=}" ;;
    --callback)  CALLBACK_URL="${2:-}"; shift ;;
    --callback=*) CALLBACK_URL="${1#--callback=}" ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# ------------------------------------------------------- --callback: gọi callback
do_callback() { # <url>
  local url=$1 body rc h1
  # Người dùng hay copy từ thanh địa chỉ Safari dạng "localhost:18432/..." (thiếu scheme).
  case "$url" in
    localhost:*|127.0.0.1:*) url="http://$url" ;;
  esac
  if ! printf '%s' "$url" | grep -Eq '^http://(localhost|127\.0\.0\.1):(18432|19654|19723|53699)/auth/callback-'; then
    warn "URL không phải callback localhost của AutoClaw: $url"
    say "  Cần dạng: http://localhost:<18432|19654|19723|53699>/auth/callback-…?code=…&state=…"
    say "  (chấp nhận cả dạng thiếu http://, ví dụ localhost:18432/auth/callback-zai?…)"
    exit 2
  fi
  body="$(curl -sS --max-time 30 "$url")"
  rc=$?
  h1="$(printf '%s\n' "$body" | grep -oE '<h1[^>]*>[^<]*</h1>' | head -n 1)"
  if [ -n "$h1" ]; then
    say ""
    say "$h1"
  elif [ -n "$body" ]; then
    say ""
    printf '%s\n' "$body" | head -n 5 | sed 's/^/  /'
  fi
  if [ "$rc" = 0 ]; then
    ok "đã gọi callback — kiểm tra: magpie accounts | grep -i autoclaw"
  else
    warn "curl lỗi (exit $rc) — phiên đăng nhập có thể đã hết hạn, chạy lại --relay"
  fi
  exit "$rc"
}

# --------------------------------------------------------- --relay: relay + tunnel
do_relay() {
  local relay_port="${RELAY_PORT:-18080}"
  local login_port cf url n
  login_port="$(find_port || true)"
  if [ -z "$login_port" ]; then
    login_port="${LOGIN_PORT:-18432}"
    warn "chưa thấy phiên đăng nhập nào mở — relay sẽ trỏ tới cổng $login_port"
    say "  (bấm Sign in trong magpie; nếu magpie mở cổng khác, chạy lại với"
    say "   LOGIN_PORT=<cổng> bash scripts/autoclaw-link.sh --relay)"
  fi

  if [ -x "$HOME/.local/bin/cloudflared" ]; then
    cf="$HOME/.local/bin/cloudflared"
  elif command -v cloudflared >/dev/null 2>&1; then
    cf="$(command -v cloudflared)"
  else
    warn "chưa có cloudflared — tải bản Linux amd64 rồi chmod +x:"
    say ""
    say "    mkdir -p ~/.local/bin"
    say "    curl -L -o ~/.local/bin/cloudflared \\"
    say "      https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    say "    chmod +x ~/.local/bin/cloudflared"
    say ""
    say "  (mọi bản: https://github.com/cloudflare/cloudflared/releases)"
    say "  Rồi chạy lại: bash scripts/autoclaw-link.sh --relay"
    exit 1
  fi

  if listening "$relay_port"; then
    ok "relay đã chạy ở 127.0.0.1:$relay_port"
  else
    command -v node >/dev/null 2>&1 || { warn "chưa có node trên PATH"; exit 1; }
    : > /tmp/autoclaw-relay.log
    LOGIN_PORT="$login_port" RELAY_PORT="$relay_port" \
      nohup node "$HERE/autoclaw-relay.mjs" >>/tmp/autoclaw-relay.log 2>&1 &
    n=0
    while ! listening "$relay_port" && [ "$n" -lt 40 ]; do sleep 0.25; n=$((n+1)); done
    if ! listening "$relay_port"; then
      warn "relay không mở được cổng $relay_port — xem /tmp/autoclaw-relay.log"
      exit 1
    fi
    ok "relay 127.0.0.1:$relay_port → 127.0.0.1:$login_port (log /tmp/autoclaw-relay.log)"
  fi

  : > /tmp/autoclaw-cf.log
  nohup "$cf" tunnel --url "http://127.0.0.1:$relay_port" --no-autoupdate \
    >/tmp/autoclaw-cf.log 2>&1 &
  url=""
  n=0
  while [ -z "$url" ] && [ "$n" -lt 160 ]; do
    sleep 0.5; n=$((n+1))
    url="$(grep -Eo 'https://[A-Za-z0-9.-]+\.trycloudflare\.com' /tmp/autoclaw-cf.log | head -n 1)"
  done
  if [ -z "$url" ]; then
    warn "cloudflared chưa in link sau ~80s — xem /tmp/autoclaw-cf.log"
    exit 1
  fi

  printf '\n'
  ok "Link public (mở trên điện thoại/laptop):"
  say ""
  bold "    $url/"
  printf '\n'
  say "Chưa mở phiên? Chạy: magpie plugin login autoclaw (chọn 2 = z.ai) — hoặc bấm Sign in trong web UI."
  printf '\n'
  bold "Các bước đăng nhập"
  say "  1. Mở link ở trên."
  say "  2. Làm slider Aliyun → 继续授权 → đăng nhập z.ai → đồng ý uỷ quyền."
  say "  3. Trình duyệt dừng ở http://localhost:$login_port/auth/callback-…?code=…&state=…"
  say "     (trang không load được — đúng như vậy). Copy NGUYÊN URL đó."
  say "  4. Trên Cloud Shell: bash scripts/autoclaw-link.sh --callback '<URL vừa copy>'"
  say "  5. Kiểm tra: magpie accounts | grep -i autoclaw"
  printf '\n'
  say "Link sống ~5 phút (plugin chờ code 5 phút); hết thì chạy lại --relay."
  say "Cổng $relay_port bận thì dùng RELAY_PORT=18081 bash scripts/autoclaw-link.sh --relay"
  say "Log: /tmp/autoclaw-relay.log (relay), /tmp/autoclaw-cf.log (cloudflared)."
  printf '\n'
}

# ------------------------------------------------------------------ thực thi
if [ -n "$CALLBACK_URL" ]; then
  do_callback "$CALLBACK_URL"
fi

if [ "$RELAY" = 1 ]; then
  do_relay
  exit 0
fi

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
say "Nếu preview trả 403 forbidden origin: bash scripts/autoclaw-link.sh --relay"
say "Chi tiết: docs/autoclaw-login.md (Cách A2)"
