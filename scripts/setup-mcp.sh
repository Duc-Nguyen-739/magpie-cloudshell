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

# Ba agent nhận MCP trên máy tham chiếu: opencode (OpenChamber đọc chung file này),
# gemini và agy. Agent nào chưa cài thì magpie library sync bỏ qua, không lỗi.
MCP_AGENTS="opencode,gemini,agy"

add_mcp() { # <tên> <url | lệnh…>
  local name=$1; shift
  if magpie library mcp show "$name" >/dev/null 2>&1; then
    say "$name đã có trong library — giữ nguyên, chỉ đặt lại agents"
    run magpie library mcp agents "$name" "$MCP_AGENTS" >/dev/null 2>&1 \
      || warn "không đặt được agents cho $name"
    return 0
  fi
  say "thêm MCP $name"
  run magpie library mcp add "$name" "$@" "agents=$MCP_AGENTS"
}

# magpie-sessions / browser / search: MCP server do chính magpie chạy, trỏ về
# gateway trên máy này (cùng cổng với scripts/magpie-headless).
add_mcp magpie-sessions "$MAGPIE_BIN" mcp sessions env="MAGPIE_ADDR=$ADDR"
# magpie-browser chỉ có ích khi có Chrome/Edge thật đang mở extension Magpie
# Browser. Trên máy headless nó luôn trả "isn't connected", nên mặc định không
# thêm; muốn dùng thì đặt MAGPIE_MCP_BROWSER=1.
if [ "${MAGPIE_MCP_BROWSER:-0}" = 1 ]; then
  add_mcp magpie-browser "$MAGPIE_BIN" mcp browser env="MAGPIE_ADDR=$ADDR"
else
  say "bỏ qua magpie-browser (cần trình duyệt thật + extension; MAGPIE_MCP_BROWSER=1 để thêm)"
fi
add_mcp magpie-web-search "$MAGPIE_BIN" mcp search env="MAGPIE_ADDR=$ADDR"

# Tài liệu Cloudflare (remote) và Chrome DevTools (npx, không hard-code path).
add_mcp cloudflare-docs https://docs.mcp.cloudflare.com/mcp
add_mcp chrome-devtools npx -y chrome-devtools-mcp@latest

# Web search: chưa có API nào thì You.com là bản miễn phí, không cần key
# (100 lượt/ngày). Không có nó, magpie-web-search trả lời mọi query bằng lỗi
# "no provider that can search the web".
if magpie search 2>/dev/null | grep -q "no search API"; then
  say "thêm search API You.com (miễn phí, không cần key)"
  run magpie search add you
fi

# Máy headless (Cloud Shell) không có Chrome: chrome-devtools-mcp không mở được
# trình duyệt. Dùng chrome-headless-shell trong cache puppeteer và ghi đè cục bộ
# bằng `mcp here` — entry npx của thư viện vẫn nguyên cho máy có Chrome.
CHROME_BIN="${CHROME_HEADLESS_SHELL:-$(find "$HOME/.cache/puppeteer/chrome-headless-shell" -name chrome-headless-shell -type f 2>/dev/null | head -1)}"
if ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1 && [ -n "$CHROME_BIN" ]; then
  CT_DIR="$HOME/.local/share/chrome-devtools-mcp"
  CT_JS="$CT_DIR/node_modules/chrome-devtools-mcp/out/Default/gen/src/bin/chrome-devtools-mcp.js"
  if [ ! -f "$CT_JS" ]; then
    say "cài chrome-devtools-mcp vào $CT_DIR (ổn định hơn cache npx)"
    run mkdir -p "$CT_DIR"
    if [ "$DRY" = 0 ]; then
      ( cd "$CT_DIR" && npm init -y >/dev/null 2>&1 \
        && npm install chrome-devtools-mcp@latest --no-audit --no-fund >/dev/null ) \
        || warn "npm install chrome-devtools-mcp lỗi — bỏ qua ghi đè headless"
    fi
  fi
  if [ -f "$CT_JS" ] || [ "$DRY" = 1 ]; then
    say "chrome-devtools: dùng $CHROME_BIN (headless, không sandbox)"
    run magpie library mcp here chrome-devtools node "$CT_JS" \
      --executablePath="$CHROME_BIN" --headless --isolated \
      --chromeArg=--no-sandbox --usageStatistics=false --no-page-id-routing
  fi
fi

say "ghi MCP vào OpenCode (magpie library sync)"
run magpie library sync && ok "OpenCode đã nhận MCP"

say ""
if [ "${MAGPIE_MCP_BROWSER:-0}" = 1 ]; then
  say "magpie-browser: cài một lần trong trình duyệt của bạn — mở link preview"
  say "  (magpie-headless-status), Library → Magpie Browser → Set up the extension…,"
  say "  tải zip rồi Load unpacked trong chrome://extensions."
fi
say "MCP chỉ nạp khi mở phiên mới."
