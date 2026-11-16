#!/usr/bin/env bash
# setup-agents.sh — trỏ các agent đang cài vào group đúng: OpenCode → group/main,
# OpenChamber → group/leader, và đặt small model của OpenCode.
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

# Đọc vào biến rồi mới grep: grep -q trên pipe làm grep thoát sớm, magpie ăn SIGPIPE
# (141) và với pipefail cả pipeline báo lỗi oan.
groups_now="$(magpie groups 2>/dev/null || true)"
if ! printf '%s\n' "$groups_now" | grep -q "group/main"; then
  warn "chưa có group/main — chạy bash scripts/setup-groups.sh trước"
fi
if ! printf '%s\n' "$groups_now" | grep -q "group/leader"; then
  warn "chưa có group/leader — chạy bash scripts/setup-groups.sh trước"
fi

agents_now="$(magpie ls 2>/dev/null || true)"
have_agent() { printf '%s\n' "$agents_now" | grep -qiE "^[[:space:]]*$1[[:space:]]"; }

# ------------------------------------------------------------------ OpenCode
if have_agent "OpenCode"; then
  say "OpenCode → group/main"
  run magpie opencode group/main && ok "OpenCode xong"

  # small model: tiêu đề phiên, tóm tắt ngắn — dùng model free nhanh, không tốn quota.
  models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
  if printf '%s\n' "$models_now" | grep -Fxq "workbuddy-ai/hy4flash-free"; then
    say "OpenCode small → magpie/workbuddy-ai/hy4flash-free"
    run magpie opencode small magpie/workbuddy-ai/hy4flash-free && ok "small model xong"
  else
    warn "không có workbuddy-ai/hy4flash-free — để nguyên small model"
  fi
else
  warn "không thấy OpenCode (cài bằng bash scripts/install-opencode.sh)"
fi

# --------------------------------------------------------------- OpenChamber
if have_agent "OpenChamber"; then
  say "OpenChamber → group/leader"
  run magpie openchamber group/leader && ok "OpenChamber xong"
else
  warn "không thấy OpenChamber (cài bằng bash scripts/install-openchamber.sh)"
fi

# Các agent khác (Claude Code, Codex, Gemini CLI, Pi…) không bị đụng tới.
# Muốn trỏ một cái: magpie <agent> group/main   (vd: magpie gemini group/main)

say ""
say "Agent đọc model lúc khởi động: mở phiên mới (hoặc restart) để nhận group mới."
