#!/usr/bin/env bash
# install-opencode.sh — cài OpenCode CLI (bản curl, nằm trong ~/.opencode).
# Không cần root; installer tự thêm PATH vào file shell config.
set -euo pipefail

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

say() { printf '  %s\n' "$*"; }

if command -v opencode >/dev/null 2>&1; then
  say "OpenCode đã có: $(opencode --version 2>/dev/null | head -1)"
  exit 0
fi

say "cài OpenCode từ opencode.ai/install…"
curl -fsSL https://opencode.ai/install | bash

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1; then
  printf 'opencode: đã cài nhưng không thấy trên PATH. Thêm ~/.opencode/bin vào PATH.\n' >&2
  exit 1
fi
say "✓ OpenCode $(opencode --version 2>/dev/null | head -1)"
