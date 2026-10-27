#!/usr/bin/env bash
# doctor.sh — kiểm tra toàn bộ: binary, gateway, provider, đăng nhập, group,
# agent, cổng, key, dung lượng. Không sửa gì.
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

CONF="$HOME/.config/magpie"
KEY_FILE="$CONF/web-key"
MP_PORT="${MAGPIE_WEB_PORT:-3430}"
OC_PORT="${OPENCHAMBER_PORT:-3000}"

ok_n=0; warn_n=0; bad_n=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; ok_n=$((ok_n+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; warn_n=$((warn_n+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; bad_n=$((bad_n+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

head_ "Cài đặt"
if command -v magpie >/dev/null 2>&1; then
  ok "magpie $(magpie --version 2>/dev/null | head -1) — $(command -v magpie)"
else
  bad "không có magpie trên PATH (chạy bash bootstrap.sh)"
fi

if command -v opencode >/dev/null 2>&1; then
  ok "OpenCode $(opencode --version 2>/dev/null | head -1)"
else
  warn "không có OpenCode (tuỳ chọn: bash scripts/install-opencode.sh)"
fi

if [ -x "$HOME/.npm-global/bin/openchamber" ]; then
  v="$(node -p "require('$HOME/.npm-global/lib/node_modules/@openchamber/web/package.json').version" 2>/dev/null || echo '?')"
  ok "OpenChamber $v"
else
  warn "không có OpenChamber (tuỳ chọn: bash scripts/install-openchamber.sh)"
fi

head_ "Gateway và web UI"
if magpie healthcheck >/dev/null 2>&1; then
  ok "gateway 127.0.0.1:3425 trả lời"
else
  bad "gateway không trả lời — bật bằng: openmagpie"
fi

if curl -fsS -o /dev/null -m 2 "http://127.0.0.1:$MP_PORT/?k=$(cat "$KEY_FILE" 2>/dev/null)" 2>/dev/null; then
  ok "web UI cổng $MP_PORT đang chạy"
else
  warn "web UI cổng $MP_PORT chưa chạy"
fi

if [ -s "$KEY_FILE" ]; then
  perm="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || echo '?')"
  [ "$perm" = "600" ] && ok "web-key có (quyền 600)" || warn "web-key quyền $perm (nên là 600)"
else
  warn "chưa có web-key (openmagpie sẽ tạo)"
fi

head_ "Provider"
np="$(magpie providers 2>/dev/null | grep -c . || true)"
[ "$np" -gt 0 ] && ok "$np provider" || bad "chưa có provider nào"
magpie providers 2>/dev/null | sed 's/^/      /'

head_ "Đăng nhập"
signed="$(magpie accounts 2>/dev/null | grep -c '^●' || true)"
[ "$signed" -gt 0 ] && ok "$signed tài khoản đang dùng" || warn "chưa đăng nhập tài khoản nào (bash scripts/login.sh)"

head_ "Routing group"
for g in main code; do
  if magpie groups 2>/dev/null | grep -q "group/$g"; then
    n="$(magpie group "$g" 2>/dev/null | awk '
      /^  models / {inm = 1; c = 1; next}
      /^  [a-z]/   {inm = 0}
      inm && /^ +[0-9]+ / {c++}
      END {print c+0}')"
    ok "group/$g ($n model)"
  else
    bad "chưa có group/$g (bash scripts/finish.sh)"
  fi
done

head_ "Agent"
for a in opencode openchamber; do
  if magpie ls 2>/dev/null | grep -qiE "^[[:space:]]*$a[[:space:]]"; then
    line="$(magpie "$a" 2>/dev/null | head -2 | tr -s ' ')"
    case "$line" in
      *group/main*) ok "$a → group/main" ;;
      *) warn "$a chưa trỏ group/main (bash scripts/setup-agents.sh)" ;;
    esac
  fi
done

head_ "Cổng"
if curl -fsS -o /dev/null -m 2 "http://127.0.0.1:$OC_PORT/" 2>/dev/null; then
  ok "OpenChamber cổng $OC_PORT đang chạy"
else
  warn "OpenChamber cổng $OC_PORT chưa chạy (openchamber)"
fi

head_ "Dung lượng"
avail="$(df -h "$HOME" | awk 'NR==2{print $4}')"
use="$(df -h "$HOME" | awk 'NR==2{print $5}')"
case "$use" in
  9[0-9]%|100%) bad "còn $avail trống ($use đã dùng)" ;;
  *)            ok "còn $avail trống ($use đã dùng)" ;;
esac

head_ "Link"
KEY="$(cat "$KEY_FILE" 2>/dev/null)"
if [ -n "${WEB_HOST:-}" ]; then
  printf '  magpie     : https://%s-%s/?k=%s\n' "$MP_PORT" "$WEB_HOST" "$KEY"
  printf '  openchamber: https://%s-%s/\n' "$OC_PORT" "$WEB_HOST"
else
  printf '  magpie     : http://127.0.0.1:%s/?k=%s\n' "$MP_PORT" "$KEY"
  printf '  openchamber: http://127.0.0.1:%s/\n' "$OC_PORT"
fi

printf '\n  %s ok · %s cảnh báo · %s lỗi\n' "$ok_n" "$warn_n" "$bad_n"
[ "$bad_n" -eq 0 ]
