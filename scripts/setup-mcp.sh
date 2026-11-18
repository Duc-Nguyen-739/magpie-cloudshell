#!/usr/bin/env bash
# setup-mcp.sh — thêm MCP server vào thư viện magpie và ghi vào OpenCode.
# Idempotent: server nào đã có trong library thì bỏ qua. Chạy sau khi cài
# OpenCode; `magpie library sync` ở cuối ghi lại vào agent nếu file agent bị sửa.
#
#   bash scripts/setup-mcp.sh
#   bash scripts/setup-mcp.sh --dry-run
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
if ! command -v opencode >/dev/null 2>&1; then
  warn "chưa có OpenCode — bỏ qua MCP; cài OpenCode rồi chạy lại script này"
  exit 0
fi
MAGPIE_BIN="$(command -v magpie)"
ADDR="${MAGPIE_ADDR:-127.0.0.1:3425}"

add_mcp() { # <tên> <url | lệnh…>
  local name=$1; shift
  if magpie library mcp show "$name" >/dev/null 2>&1; then
    say "$name đã có trong library — bỏ qua"
    return 0
  fi
  say "thêm MCP $name"
  run magpie library mcp add "$name" "$@" agents=opencode
}

# magpie-sessions / browser / search: MCP server do chính magpie chạy, trỏ về
# gateway trên máy này (cùng cổng với scripts/magpie-headless).
add_mcp magpie-sessions "$MAGPIE_BIN" mcp sessions env="MAGPIE_ADDR=$ADDR"
add_mcp magpie-browser "$MAGPIE_BIN" mcp browser env="MAGPIE_ADDR=$ADDR"
add_mcp magpie-web-search "$MAGPIE_BIN" mcp search env="MAGPIE_ADDR=$ADDR"

# Tài liệu Cloudflare (remote) và Chrome DevTools (npx, không hard-code path).
add_mcp cloudflare-docs https://docs.mcp.cloudflare.com/mcp
add_mcp chrome-devtools npx -y chrome-devtools-mcp@latest

say "ghi MCP vào OpenCode (magpie library sync)"
run magpie library sync && ok "OpenCode đã nhận MCP"

say ""
say "MCP chỉ nạp khi mở phiên mới."
