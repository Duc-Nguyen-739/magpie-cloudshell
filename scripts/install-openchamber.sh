#!/usr/bin/env bash
# install-openchamber.sh — cài OpenChamber (web UI cho OpenCode) vào ~/.npm-global.
# Cần node ≥ 20; Cloud Shell có nvm, hàm ensure_node lo phần đó.
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

say()  { printf '  %s\n' "$*"; }
die()  { printf '  ✗ %s\n' "$*" >&2; exit 1; }

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

ensure_node || die "không có node ≥ 20. Cài node (hoặc nvm) rồi chạy lại."

have="$(node -p "try{require('$HOME/.npm-global/lib/node_modules/@openchamber/web/package.json').version}catch(e){''}" 2>/dev/null || true)"
if [ -n "$have" ] && [ -x "$HOME/.npm-global/bin/openchamber" ]; then
  say "OpenChamber đã có: $have"
  exit 0
fi

say "cài @openchamber/web vào ~/.npm-global (một lần, ~290 MB)…"
npm install -g --prefix "$HOME/.npm-global" @openchamber/web

[ -x "$HOME/.npm-global/bin/openchamber" ] || die "cài xong nhưng thiếu ~/.npm-global/bin/openchamber"
say "✓ OpenChamber $(node -p "require('$HOME/.npm-global/lib/node_modules/@openchamber/web/package.json').version")"
