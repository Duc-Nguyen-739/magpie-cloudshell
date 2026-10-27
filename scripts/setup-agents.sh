#!/usr/bin/env bash
# setup-agents.sh — trỏ các agent đang cài vào group/main.
#
#   bash scripts/setup-agents.sh
#   bash scripts/setup-agents.sh --dry-run
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

run() {
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*"; else "$@"; fi
}

command -v magpie >/dev/null 2>&1 || { echo "chưa có magpie trên PATH" >&2; exit 1; }

# group/main phải tồn tại trước
if ! magpie groups 2>/dev/null | grep -q "group/main"; then
  warn "chưa có group/main — chạy bash scripts/setup-groups.sh trước"
fi

have_agent() { magpie ls 2>/dev/null | grep -qiE "^[[:space:]]*$1[[:space:]]"; }

# ------------------------------------------------------------------ OpenCode
if have_agent "OpenCode"; then
  say "OpenCode → group/main"
  run magpie opencode group/main && ok "OpenCode xong"
else
  warn "không thấy OpenCode (cài bằng bash scripts/install-opencode.sh)"
fi

# --------------------------------------------------------------- OpenChamber
if have_agent "OpenChamber"; then
  say "OpenChamber → group/main"
  run magpie openchamber group/main && ok "OpenChamber xong"
else
  warn "không thấy OpenChamber (cài bằng bash scripts/install-openchamber.sh)"
fi

# Các agent khác (Claude Code, Codex, Gemini CLI, Pi…) không bị đụng tới.
# Muốn trỏ một cái: magpie <agent> group/main   (vd: magpie gemini group/main)

say ""
say "Agent đọc model lúc khởi động: mở phiên mới (hoặc restart) để nhận group/main."
