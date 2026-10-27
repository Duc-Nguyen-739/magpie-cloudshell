#!/usr/bin/env bash
# install.sh — cài magpie bản terminal (headless) vào ~/.local/bin.
# Không cần desktop, không cần WebKitGTK: MAGPIE_CLI=1 chọn bản CLI.
set -euo pipefail

BIN="${MAGPIE_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN"
export PATH="$BIN:$PATH"

say() { printf '  %s\n' "$*"; }

if command -v magpie >/dev/null 2>&1; then
  say "magpie đã có: $(magpie --version 2>/dev/null | head -1)"
  exit 0
fi

say "tải installer từ usemagpie.ai…"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL https://usemagpie.ai/install.sh -o "$tmp"
MAGPIE_CLI=1 sh "$tmp"
rm -f "$tmp"
trap - EXIT

if ! command -v magpie >/dev/null 2>&1; then
  printf 'magpie: đã cài nhưng không thấy trên PATH. Thêm %s vào PATH rồi mở shell mới.\n' "$BIN" >&2
  exit 1
fi

say "✓ $(magpie --version 2>/dev/null | head -1) tại $(command -v magpie)"
