#!/usr/bin/env bash
# plugins.sh — cài các plugin provider của magpie-community.
# Lần đầu sẽ tải bun (~180 MB) về ~/.cache/magpie/bun; sau đó mới nhanh.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

PLUGINS=(
  "@magpie-community/opencode-autoclaw-auth"    # AutoClaw (Zhipu) — OAuth Google/z.ai
  "@magpie-community/opencode-workbuddy-auth"   # WorkBuddy / WorkBuddy AI
  "@magpie-community/opencode-qoder-auth"       # Qoder
  "@magpie-community/opencode-zcode-auth"       # ZCode (tuỳ chọn, không bắt buộc đăng nhập)
  "@magpie-community/opencode-zen-free-auth"    # OpenCode Zen Free
  "opencode-zen-freex"                          # phần phục vụ OpenCode Zen Free
)

say()  { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

installed="$(magpie plugin list 2>/dev/null || true)"
rc=0

for spec in "${PLUGINS[@]}"; do
  if printf '%s\n' "$installed" | grep -q -- "$spec"; then
    say "đã có $spec"
    continue
  fi
  say "cài $spec…"
  if magpie plugin add "$spec" >/dev/null 2>&1; then
    say "  ✓ $spec"
  else
    warn "không cài được $spec (mạng? dung lượng?) — chạy lại sau: magpie plugin add $spec"
    rc=1
  fi
done

say ""
say "Đã cài $(magpie plugin list 2>/dev/null | grep -c '^@' || true) plugin. Xem: magpie plugin list"
exit "$rc"
