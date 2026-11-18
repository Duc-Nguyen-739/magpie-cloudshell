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
say "Đã cài $(magpie plugin list 2>/dev/null | grep -c '  on$' || true) plugin. Xem: magpie plugin list"

# FreePi2 — plugin trong repo private. Không dùng spec `github:` được: bun tải
# tarball qua api.github.com mà không gửi token nên GitHub trả 404 với repo private.
# Cách chạy được: clone bằng gh rồi cài từ thư mục local.
FREEPI2_DIR="${FREEPI2_DIR:-$HOME/.local/src/FreePiLogin2}"
if magpie plugin list 2>/dev/null | grep -q 'freepi2'; then
  say "đã có FreePi2"
else
  if [ ! -d "$FREEPI2_DIR/.git" ]; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      say "clone FreePi2 (repo private)…"
      if gh repo clone Duc-Nguyen-739/FreePiLogin2 "$FREEPI2_DIR" >/dev/null 2>&1; then
        say "  ✓ clone"
      else
        warn "không clone được FreePiLogin2 — kiểm tra quyền đọc repo (gh auth login)"
      fi
    else
      warn "FreePi2 là repo private: cần 'gh auth login' hoặc clone sẵn vào $FREEPI2_DIR"
    fi
  fi
  if [ -f "$FREEPI2_DIR/package.json" ]; then
    say "cài FreePi2 từ $FREEPI2_DIR…"
    if magpie plugin add "$FREEPI2_DIR" >/dev/null 2>&1; then
      say "  ✓ FreePi2"
    else
      warn "không cài được FreePi2 — chạy tay: magpie plugin add $FREEPI2_DIR"
      rc=1
    fi
  fi
fi

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

  # Ad gate: freepi.ai trả 403 ads_required cho completion khi tài khoản chưa
  # báo banner impression. magpie-freepi-auth đã báo; magpie-free-pi thì chưa.
  if node "$REPO_DIR/scripts/patch-free-pi-ads.mjs" >/dev/null 2>&1; then
    say "  ✓ free-pi: báo ad impression"
  else
    warn "không vá được ad gate free-pi — chạy tay: node scripts/patch-free-pi-ads.mjs"
    rc=1
  fi

  # Hai provider freepi.ai phải tách rời: mỗi user_id đúng một entry trong pool
  # của free-pi (đăng nhập lặp sinh entry trùng, budget vẫn chỉ một).
  if node "$REPO_DIR/scripts/setup-freepi-pair.mjs" >/dev/null 2>&1; then
    say "  ✓ free-pi: một tài khoản, không trùng"
  else
    warn "không dọn được pool free-pi — chạy tay: node scripts/setup-freepi-pair.mjs"
  fi
fi

exit "$rc"
