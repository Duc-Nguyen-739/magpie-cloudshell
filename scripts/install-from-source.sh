#!/usr/bin/env bash
# install-from-source.sh — cài magpie từ **repo chính chủ**
# https://github.com/yetone/magpie, build bản terminal (không GUI).
#
#   bash scripts/install-from-source.sh
#   MAGPIE_SRC=~/src/magpie bash scripts/install-from-source.sh   # đổi chỗ clone
#
# Cần: git, go ≥ 1.26 (Cloud Shell có sẵn ở /usr/local/go/bin).
# Nhanh hơn và không cần Go: bash scripts/install.sh (installer chính thức).
set -euo pipefail

SRC="${MAGPIE_SRC:-$HOME/.local/src/magpie}"
BIN="${MAGPIE_BIN_DIR:-$HOME/.local/bin}"
REPO="https://github.com/yetone/magpie.git"

say() { printf '  %s\n' "$*"; }
die() { printf '  ✗ %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "cần git"
command -v go  >/dev/null 2>&1 || die "cần Go ≥ 1.26 (hoặc dùng bash scripts/install.sh để lấy bản dựng sẵn)"

gv="$(go env GOVERSION 2>/dev/null | sed 's/^go//')"
say "Go $gv · nguồn: $REPO"

mkdir -p "$(dirname "$SRC")" "$BIN"

if [ -d "$SRC/.git" ]; then
  say "cập nhật bản clone có sẵn: $SRC"
  git -C "$SRC" pull --ff-only
else
  say "clone repo chính chủ về $SRC"
  git clone --depth 1 "$REPO" "$SRC"
fi

say "build bản terminal (make cli)…"
( cd "$SRC" && make cli )

[ -x "$SRC/magpie" ] || die "build xong nhưng không thấy $SRC/magpie"
install -m 755 "$SRC/magpie" "$BIN/magpie"
say "✓ $( "$BIN/magpie" --version 2>/dev/null | head -1 ) tại $BIN/magpie"
