#!/usr/bin/env bash
# plugins.sh — cài các plugin provider của magpie-community.
# Lần đầu sẽ tải bun (~180 MB) về ~/.cache/magpie/bun; sau đó mới nhanh.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGINS=(
  "@magpie-community/opencode-autoclaw-auth@0.2.9"  # AutoClaw (Zhipu) — OAuth Google/z.ai
  "@magpie-community/opencode-workbuddy-auth"   # WorkBuddy / WorkBuddy AI
  "@magpie-community/opencode-zen-free-auth"    # OpenCode Zen Free — classifier jev
  "opencode-zen-freex@latest"                   # cùng provider, plugin thứ hai đang cài
  "@magpie-community/opencode-kiro-auth"        # Kiro
  "@magpie-community/opencode-cline-auth"       # Cline
  "@magpie-community/opencode-agnes-auth"       # Agnes — cài nhưng provider đang tắt
  "magpie-freepi-auth"                          # FreePi — provider chính + 6 tài khoản private
  # Tuỳ chọn, không cài trên máy tham chiếu (thêm bằng `magpie plugin add`):
  #   @magpie-community/opencode-agy-cli-auth   agy-cli (Antigravity)
  #   @magpie-community/opencode-qoder-auth     Qoder
  #   @magpie-community/opencode-zcode-auth     ZCode
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
say "Đã cài $(magpie plugin list 2>/dev/null | grep -c '  on$' || true) plugin. Xem: magpie plugin list"

# FreePi2…FreePi7 — plugin trong repo private. Không dùng spec `github:` được: bun
# tải tarball qua api.github.com mà không gửi token nên GitHub trả 404 với repo
# private. Cách chạy được: clone bằng gh rồi cài từ thư mục local.
install_private_plugin() {
  local label="$1" repo="$2" provider="$3" dir="$4"
  if magpie plugin list 2>/dev/null | grep -q "$provider"; then
    say "đã có $label"
    return 0
  fi
  if [ ! -d "$dir/.git" ]; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      say "clone $label (repo private)…"
      if gh repo clone "Duc-Nguyen-739/$repo" "$dir" >/dev/null 2>&1; then
        say "  ✓ clone"
      else
        warn "không clone được $repo — kiểm tra quyền đọc repo (gh auth login)"
      fi
    else
      warn "$label là repo private: cần 'gh auth login' hoặc clone sẵn vào $dir"
    fi
  fi
  if [ -f "$dir/package.json" ]; then
    say "cài $label từ $dir…"
    if magpie plugin add "$dir" >/dev/null 2>&1; then
      say "  ✓ $label"
    else
      warn "không cài được $label — chạy tay: magpie plugin add $dir"
      rc=1
    fi
  fi
}

install_private_plugin "FreePi2" "FreePiLogin2" "freepi2" "${FREEPI2_DIR:-$HOME/.local/src/FreePiLogin2}"
install_private_plugin "FreePi3" "FreePiLogin3" "freepi3" "${FREEPI3_DIR:-$HOME/.local/src/FreePiLogin3}"
install_private_plugin "FreePi4" "FreePiLogin4" "freepi4" "${FREEPI4_DIR:-$HOME/.local/src/FreePiLogin4}"
install_private_plugin "FreePi5" "FreePiLogin5" "freepi5" "${FREEPI5_DIR:-$HOME/.local/src/FreePiLogin5}"
install_private_plugin "FreePi6" "FreePiLogin6" "freepi6" "${FREEPI6_DIR:-$HOME/.local/src/FreePiLogin6}"
install_private_plugin "FreePi7" "FreePiLogin7" "freepi7" "${FREEPI7_DIR:-$HOME/.local/src/FreePiLogin7}"

exit "$rc"
