#!/usr/bin/env bash
# setup-opencode.sh — thêm 2 subagent (coder, tester) và skill magpie-setup vào OpenCode.
# Không ghi đè file đã có; muốn cập nhật thì xoá file cũ rồi chạy lại.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$HOME/.config/opencode"
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

mkdir -p "$CONF/agents"

if ! command -v magpie >/dev/null 2>&1; then
  warn "chưa có magpie trên PATH — chạy bash bootstrap.sh trước; bỏ qua bước này"
  exit 1
fi

models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
has_model() { printf '%s\n' "$models_now" | grep -Fxq "$1"; }

install_agent() { # <tên>
  local name=$1 src="$REPO_DIR/config/agents/$1.md" dst="$CONF/agents/$1.md"
  if [ -f "$dst" ]; then
    warn "$dst đã có — không ghi đè"
    return 0
  fi
  cp "$src" "$dst"
  # Model riêng của subagent; nếu máy chưa có thì lùi về group/main để không lỗi.
  local m
  m="$(sed -n 's/^model: *//p' "$dst" | head -1)"
  if [ -n "$m" ] && [ -z "${m#magpie/}" ] && ! has_model "${m#magpie/}"; then
    sed -i "s|^model: .*|model: magpie/group/main|" "$dst"
    warn "$name: không có ${m#magpie/}, đã đổi sang magpie/group/main"
  fi
  ok "$dst"
}

install_agent coder
install_agent tester

# ------------------------------------------------------- skill magpie-setup
# Nguồn chính thức: https://github.com/magpie-community/plugins/tree/main/skills/magpie-setup
SKILL_DIR="$CONF/skills/magpie-setup"
if [ -d "$SKILL_DIR" ]; then
  say "skill magpie-setup đã có"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if git clone --depth 1 --filter=blob:none --sparse \
       https://github.com/magpie-community/plugins "$tmp/plugins" >/dev/null 2>&1 \
     && git -C "$tmp/plugins" sparse-checkout set skills/magpie-setup >/dev/null 2>&1; then
    mkdir -p "$CONF/skills"
    cp -r "$tmp/plugins/skills/magpie-setup" "$SKILL_DIR"
    ok "$SKILL_DIR"
  else
    warn "không tải được skill (mạng?) — bỏ qua, không ảnh hưởng cài đặt"
  fi
fi

say ""
say "Provider magpie trong opencode.jsonc do chính magpie ghi khi bạn chạy"
say "'magpie opencode group/main' — không cần sửa tay. Xem docs/opencode.md."
