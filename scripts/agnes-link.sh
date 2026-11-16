#!/usr/bin/env bash
# agnes-link.sh — đăng nhập Agnes vào magpie khi magpie chạy trên máy headless
# (Cloud Shell, VPS, container) và trình duyệt của bạn ở máy khác.
#
#   bash scripts/agnes-link.sh              mở trang đăng nhập, in link
#   bash scripts/agnes-link.sh --status     phiên còn sống không, link
#   bash scripts/agnes-link.sh --watch      chờ tới khi đăng nhập xong
#   bash scripts/agnes-link.sh --cancel     tắt trang
#
# Khác Kiro/AutoClaw: Agnes **không** có OAuth callback về localhost — token
# không bao giờ nằm trong URL, nên không có gì để copy rồi gửi lại. Plugin Agnes
# đọc `localStorage.token` qua Chrome chạy trên chính máy magpie; máy headless
# không có Chrome. Vì vậy trang này nhận API key (`cpk-…` / `apk-…`) bạn copy từ
# trang API keys của Agnes, rồi tự chạy `magpie plugin login agnes` và kiểm tra
# key với upstream. Không phải dán key vào chat.
#
# Trang sống 60 phút (mặc định); hết thì chạy lại script.
set -uo pipefail

PATH="$HOME/.local/bin:$PATH"
export PATH

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HOME/.local/state/magpie/agnes-signin"
LOG="$STATE/server.log"
PIDF="$STATE/pid"
KEYF="$STATE/key"
STATEF="$STATE/state.json"
PORT="${AGNES_PAGE_PORT:-3455}"

say()  { printf '  %s\n' "$*"; }
bold() { printf '  \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; }

ensure_node() {
  command -v node >/dev/null 2>&1 && return 0
  for nd in /usr/local/nvm/versions/node/v*/bin "$HOME"/.nvm/versions/node/v*/bin; do
    [ -x "$nd/node" ] && { export PATH="$nd:$PATH"; return 0; }
  done
  export NVM_DIR="${NVM_DIR:-/usr/local/nvm}"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use && nvm use default >/dev/null 2>&1
  command -v node >/dev/null 2>&1
}

cleanup() {
  local pid
  pid="$(cat "$PIDF" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    sleep 0.3
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
  fi
  rm -f "$PIDF" "$KEYF" "$STATEF"
}

free_port() { # <bắt đầu> — in cổng trống đầu tiên
  local p=$1 n=0
  while [ "$n" -lt 20 ]; do
    if ! ss -ltn 2>/dev/null | grep -qE ":$p\b"; then printf '%s' "$p"; return 0; fi
    p=$((p+1)); n=$((n+1))
  done
  return 1
}

link() { # <port> <key>
  if [ -n "${WEB_HOST:-}" ]; then
    printf 'https://%s-%s/?k=%s' "$1" "$WEB_HOST" "$2"
  else
    printf 'http://127.0.0.1:%s/?k=%s' "$1" "$2"
  fi
}

show_link() { # <port> <key>
  local url
  url="$(link "$1" "$2")"
  printf '\n'
  ok "trang đăng nhập Agnes đang chạy"
  printf '\n'
  bold "Link (mở bằng trình duyệt của bạn):"
  printf '\n    %s\n\n' "$url"
  bold "Các bước"
  say "  1. Mở link, bấm “Mở trang đăng nhập Agnes”, đăng nhập (Google/GitHub/email)."
  say "  2. Vào Settings → API Keys, tạo hoặc copy một key (cpk-… hoặc apk-…)."
  say "  3. Quay lại link, dán key, chọn loại key, bấm “Gửi cho magpie”."
  say "     Trang tự lưu và kiểm tra key với Agnes — không cần gửi URL hay key vào chat."
  printf '\n'
  say "Xong thì báo tôi. Trang sống 60 phút; tắt sớm: bash scripts/agnes-link.sh --cancel"
  printf '\n'
}

start() {
  mkdir -p "$STATE"
  chmod 700 "$STATE" 2>/dev/null
  if alive; then
    local p k
    p="$(cat "$STATE/port" 2>/dev/null || echo "$PORT")"
    k="$(cat "$KEYF" 2>/dev/null || true)"
    if [ -n "$k" ]; then show_link "$p" "$k"; return 0; fi
  fi
  cleanup
  rm -f "$LOG"
  ensure_node || die "không có node. Cài node rồi chạy lại."
  PORT="$(free_port "$PORT")" || die "không tìm được cổng trống quanh $PORT"
  local key
  key="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  printf '%s' "$key" > "$KEYF"
  chmod 600 "$KEYF"
  printf '%s' "$PORT" > "$STATE/port"

  AGNES_PAGE_KEY="$key" AGNES_PAGE_PORT="$PORT" AGNES_STATE_DIR="$STATE" \
    setsid node "$HERE/agnes-login.mjs" >"$LOG" 2>&1 </dev/null &
  printf '%s' "$!" > "$PIDF"

  local n=0
  while [ "$n" -lt 40 ]; do
    curl -fsS -m 1 "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 && break
    alive || { warn "trang không khởi động được:"; tail -10 "$LOG" 2>/dev/null | sed 's/^/    /'; cleanup; exit 1; }
    sleep 0.25; n=$((n+1))
  done
  curl -fsS -m 1 "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 \
    || { warn "trang không trả lời:"; tail -10 "$LOG" 2>/dev/null | sed 's/^/    /'; cleanup; exit 1; }

  show_link "$PORT" "$key"
}

result() { # 0 = đã xong, 1 = chưa
  [ -f "$STATEF" ] || return 1
  local okflag
  okflag="$(grep -o '"ok": *true' "$STATEF" 2>/dev/null | head -1)"
  if [ -n "$okflag" ]; then
    printf '\n'
    ok "đã đăng nhập Agnes vào magpie"
    local models
    models="$(grep -o '"models": *[0-9]*' "$STATEF" | grep -o '[0-9]*$')"
    [ -n "$models" ] && say "  $models model: magpie models | grep '^agnes/'"
    say "  kiểm tra: magpie provider test agnes agnes-3.0-flash"
    printf '\n'
    return 0
  fi
  local err
  err="$(grep -o '"error": *"[^"]*"' "$STATEF" 2>/dev/null | head -1 | sed 's/.*"error": *"//;s/"$//')"
  if [ -n "$err" ]; then
    warn "$err"
    return 0
  fi
  return 1
}

do_watch() {
  if ! alive; then
    result && return 0
    die "không có phiên nào đang chạy — chạy bash scripts/agnes-link.sh để mở"
  fi
  say "đang chờ bạn đăng nhập trên trang… Ctrl-C để dừng."
  local n=0
  while [ "$n" -lt 3600 ]; do
    result && { cleanup; return 0; }
    alive || { result || warn "trang đã tắt mà chưa đăng nhập"; return 1; }
    sleep 1; n=$((n+1))
  done
  warn "hết 60 phút vẫn chưa xong."
}

case "${1:-}" in
  ""|--start)  start ;;
  --status)
    if alive; then
      show_link "$(cat "$STATE/port" 2>/dev/null || echo "$PORT")" "$(cat "$KEYF" 2>/dev/null || true)"
    else
      result || warn "không có phiên nào đang chạy"
    fi ;;
  --link)
    alive || die "chưa chạy — bash scripts/agnes-link.sh"
    link "$(cat "$STATE/port")" "$(cat "$KEYF")"; printf '\n' ;;
  --watch)     do_watch ;;
  --cancel)    cleanup; ok "đã tắt trang" ;;
  -h|--help)   sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           printf 'tham số lạ: %s (xem --help)\n' "$1" >&2; exit 2 ;;
esac
