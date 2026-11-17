#!/usr/bin/env bash
# plugins.sh — cài các plugin provider của magpie-community.
# Lần đầu sẽ tải bun (~180 MB) về ~/.cache/magpie/bun; sau đó mới nhanh.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGINS=(
  "@magpie-community/opencode-autoclaw-auth"    # AutoClaw (Zhipu) — OAuth Google/z.ai
  "@magpie-community/opencode-workbuddy-auth"   # WorkBuddy / WorkBuddy AI
  "@magpie-community/opencode-agy-cli-auth"     # agy-cli (Antigravity) — group/leader
  "@magpie-community/opencode-cline-auth"       # Cline — group/free
  "@magpie-community/opencode-kiro-auth"        # Kiro — group/free
  "@magpie-community/opencode-agnes-auth"       # Agnes — group/tester (đang tắt)
  "magpie-freepi-auth"                          # FreePi — group/review, reviewplan, coder
  "magpie-free-pi"                              # free-pi — provider thứ hai, tài khoản riêng
  "@magpie-community/opencode-zen-free-auth"    # OpenCode Zen Free
  "opencode-zen-freex"                          # phần phục vụ OpenCode Zen Free
  # qoder / zcode không cài trên máy tham chiếu (provider qoder đang tắt); cần thì
  # magpie plugin add @magpie-community/opencode-qoder-auth
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
say "Đã cài $(magpie plugin list 2>/dev/null | grep -vc '^[[:space:]]*$' || true) plugin. Xem: magpie plugin list"

# free-pi ghim phiên bản client trong mã nguồn, server nâng mức tối thiểu là mọi
# request chat bị 426 (trước cả khi chọn model). Vá lại sau mỗi lần cài/cập nhật.
if magpie plugin list 2>/dev/null | grep -q 'magpie-free-pi'; then
  say ""
  say "vá free-pi (lấy client version từ /client-version)…"
  if node "$REPO_DIR/scripts/patch-free-pi.mjs" >/dev/null 2>&1; then
    say "  ✓ free-pi"
  else
    warn "không vá được free-pi — chạy tay: node scripts/patch-free-pi.mjs"
    rc=1
  fi
fi

exit "$rc"
