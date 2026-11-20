#!/usr/bin/env bash
# setup-billion-context.sh — cài plugin + config billion-context cho OpenCode.
#
#   bash scripts/setup-billion-context.sh            cài nếu thiếu, giữ config hiện có
#   bash scripts/setup-billion-context.sh --force    ghi đè config (có backup)
#   bash scripts/setup-billion-context.sh --dry-run  chỉ in việc sẽ làm
#   bash scripts/setup-billion-context.sh --start    bật proxy nếu chưa chạy
#
# Config mẫu: config/billion-context.json. Không chứa key; credential `magpie`
# vẫn phải thêm một lần qua web UI (xem cuối script).
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FORCE=0
DRY=0
START=0
for a in "$@"; do
  case "$a" in
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    --start)   START=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'tham số lạ: %s (dùng --force, --dry-run, --start)\n' "$a" >&2; exit 2 ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*" >&2; else "$@"; fi
}

BILI_VERSION="${BILI_VERSION:-0.1.216}"
PREFIX="${BILI_PREFIX:-$HOME/.local}"
BILI_ROOT="$PREFIX/lib/node_modules/billion-context"
CONFIG_DIR="$HOME/.config/billion-context"
CONFIG="$CONFIG_DIR/billion-context.json"
CRED="$CONFIG_DIR/billion-context.json.summary-credentials.json"
TEMPLATE="$REPO_DIR/config/billion-context.json"
PLUGIN_DIR="$HOME/.config/opencode/plugins/billion-context"
PLUGIN="$PLUGIN_DIR/index.js"
OC_CONFIG="$HOME/.config/opencode/opencode.jsonc"

command -v node >/dev/null 2>&1 || die "chưa có node trên PATH"
command -v npm  >/dev/null 2>&1 || die "chưa có npm trên PATH"
[ -f "$TEMPLATE" ] || die "thiếu config mẫu: $TEMPLATE"

say "billion-context $BILI_VERSION → $PREFIX"

# ---------------------------------------------------------------- package
if [ -f "$BILI_ROOT/dist/agent/opencode-native.js" ]; then
  ok "đã có package: $BILI_ROOT"
else
  say "cài package (npm -g --prefix $PREFIX)…"
  if ! run npm install -g "billion-context@$BILI_VERSION" --prefix "$PREFIX"; then
    warn "cài package thất bại — kiểm tra mạng/quyền ghi $PREFIX"
    exit 1
  fi
  ok "đã cài package"
fi

# ---------------------------------------------------------------- plugin
if [ -f "$PLUGIN" ] && grep -qF "$BILI_ROOT/dist/agent/opencode-native.js" "$PLUGIN" 2>/dev/null; then
  ok "plugin đã trỏ đúng package"
else
  say "tạo plugin shim: $PLUGIN"
  run mkdir -p "$PLUGIN_DIR"
  if [ "$DRY" = 1 ]; then
    say "[dry-run] ghi export default từ $BILI_ROOT/dist/agent/opencode-native.js"
  else
    printf 'export { default } from "%s";\n' "$BILI_ROOT/dist/agent/opencode-native.js" > "$PLUGIN"
    ok "đã tạo plugin shim"
  fi
fi

# ---------------------------------------------------------------- config
if [ -f "$CONFIG" ] && [ "$FORCE" != 1 ]; then
  if cmp -s "$TEMPLATE" "$CONFIG"; then
    ok "config đã khớp mẫu: $CONFIG"
  else
    warn "config hiện có khác mẫu — giữ nguyên; dùng --force để ghi đè (có backup)"
  fi
else
  run mkdir -p "$CONFIG_DIR"
  if [ -f "$CONFIG" ]; then
    backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    run cp -a "$CONFIG" "$backup"
    say "backup: $backup"
  fi
  run cp "$TEMPLATE" "$CONFIG"
  run chmod 600 "$CONFIG"
  ok "đã đặt config: $CONFIG"
fi

# ------------------------------------------------- compaction.auto = false
if [ -f "$OC_CONFIG" ]; then
  if grep -q '"compaction"' "$OC_CONFIG"; then
    if grep -Eq '"auto"[[:space:]]*:[[:space:]]*false' "$OC_CONFIG"; then
      ok "OpenCode: compaction.auto=false"
    else
      warn "OpenCode có compaction nhưng auto không false — sửa tay: \"compaction\": {\"auto\": false}"
    fi
  else
    say "thêm compaction.auto=false vào $OC_CONFIG"
    if [ "$DRY" = 1 ]; then
      say "[dry-run] chèn khối compaction"
    else
      python3 - "$OC_CONFIG" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if '"compaction"' not in s:
    s2 = re.sub(r'^\s*\{', '{\n  "compaction": {"auto": false},', s, count=1, flags=re.M)
    if s2 == s:
        raise SystemExit("không tìm thấy dấu { đầu file")
    open(p, "w", encoding="utf-8").write(s2)
PY
      ok "đã thêm compaction.auto=false"
    fi
  fi
else
  warn "chưa có $OC_CONFIG — cài OpenCode trước rồi chạy lại"
fi

# ---------------------------------------------------------------- credential
if [ -f "$CRED" ]; then
  ok "đã có credential file (không đọc/in nội dung)"
else
  warn "chưa có credential 'magpie' — mở http://127.0.0.1:18787/__bili/ → Settings → Credentials → thêm tên 'magpie'"
fi

# ---------------------------------------------------------------- proxy
if curl -fsS -o /dev/null --max-time 2 http://127.0.0.1:18787/__bili/ 2>/dev/null; then
  if [ "$DRY" = 1 ]; then
    say "[dry-run] POST /__bili/config/reload"
  elif curl -fsS -X POST --max-time 10 http://127.0.0.1:18787/__bili/config/reload >/dev/null; then
    ok "đã reload config"
  else
    warn "reload thất bại — xem ~/.local/state/billion-context/bili.log"
  fi
else
  if [ "$START" = 1 ]; then
    say "bật proxy 127.0.0.1:18787…"
    run mkdir -p "$HOME/.local/state/billion-context"
    if [ "$DRY" != 1 ]; then
      nohup "$PREFIX/bin/bili" start --host 127.0.0.1 --port 18787 \
        >>"$HOME/.local/state/billion-context/bili.log" 2>&1 &
      sleep 2
      if curl -fsS -o /dev/null --max-time 2 http://127.0.0.1:18787/__bili/ 2>/dev/null; then
        ok "proxy đã chạy"
      else
        warn "proxy chưa trả lời — xem ~/.local/state/billion-context/bili.log"
      fi
    fi
  else
    say "proxy chưa chạy. Bật bằng:"
    say "  $PREFIX/bin/bili start --host 127.0.0.1 --port 18787"
    say "hoặc chạy lại script với --start"
  fi
fi

say ""
say "group/compress: tự tạo group (routing=rotate, stays=off) và thêm model; config chỉ trỏ target."
ok "xong. Mở phiên OpenCode mới để plugin nạp."
