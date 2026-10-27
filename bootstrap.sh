#!/usr/bin/env bash
# bootstrap.sh — cài đặt một lần: magpie + provider plugin + OpenCode + OpenChamber
# + các lệnh tiện dụng (openchamber, openmagpie, magpie-headless-*).
#
#   bash bootstrap.sh              cài đủ
#   bash bootstrap.sh --minimal    chỉ magpie (bỏ OpenCode/OpenChamber)
#   bash bootstrap.sh --no-autostart  không thêm hook vào ~/.bashrc
#
# Chạy lại nhiều lần vẫn an toàn: bước nào có rồi thì bỏ qua.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

MINIMAL=0
AUTOSTART=1
for a in "$@"; do
  case "$a" in
    --minimal)      MINIMAL=1 ;;
    --no-autostart) AUTOSTART=0 ;;
    -h|--help)      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'tham số lạ: %s\n' "$a" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

printf '\033[1mmagpie trên Cloud Shell\033[0m — cài đặt\n'
printf 'repo: %s\n' "$REPO_DIR"

# ------------------------------------------------------------------ 1. magpie
step "1/7 · magpie (bản terminal, headless)"
bash "$REPO_DIR/scripts/install.sh" || die "cài magpie thất bại"
export PATH="$HOME/.local/bin:$PATH"

# ----------------------------------------------------------------- 2. plugins
step "2/7 · plugin provider (lần đầu tải bun ~180 MB)"
bash "$REPO_DIR/scripts/plugins.sh" || warn "một số plugin chưa cài được; chạy lại sau"

# ------------------------------------------------------- 3. lệnh tiện dụng
step "3/7 · lệnh tiện dụng trong ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for f in openchamber openmagpie magpie-headless magpie-headless-start magpie-headless-stop magpie-headless-status; do
  install -m 755 "$REPO_DIR/scripts/$f" "$HOME/.local/bin/$f"
  ok "~/.local/bin/$f"
done
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

# ------------------------------------------- 4. PATH + autostart trong .bashrc
step "4/7 · PATH và tự bật khi mở shell"
RC="$HOME/.bashrc"
BEGIN="# >>> magpie-cloudshell >>>"
END="# <<< magpie-cloudshell <<<"
if grep -qF "$BEGIN" "$RC" 2>/dev/null; then
  ok "đã có khối trong ~/.bashrc"
else
  {
    printf '\n%s\n' "$BEGIN"
    printf '# ~/.local/bin trước ~/.npm-global/bin: wrapper của mình phải thắng binary của npm.\n'
    printf 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"\n'
    if [ "$AUTOSTART" = 1 ]; then
      printf 'if [ -z "${MAGPIE_HEADLESS_QUIET:-}" ] && [ -x "$HOME/.local/bin/magpie-headless-start" ]; then\n'
      printf '  "$HOME/.local/bin/magpie-headless-start" >/dev/null 2>&1\n'
      printf 'fi\n'
    fi
    printf '%s\n' "$END"
  } >> "$RC"
  ok "đã thêm vào ~/.bashrc"
fi

# --------------------------------------------------- 5. OpenCode + OpenChamber
if [ "$MINIMAL" = 1 ]; then
  step "5/7 · OpenCode + OpenChamber — bỏ qua (--minimal)"
else
  step "5/7 · OpenCode + OpenChamber"
  bash "$REPO_DIR/scripts/install-opencode.sh" || warn "OpenCode chưa cài được"
  bash "$REPO_DIR/scripts/install-openchamber.sh" || warn "OpenChamber chưa cài được"
  bash "$REPO_DIR/scripts/setup-opencode.sh" || warn "subagent/skill chưa cài được"
fi

# ------------------------------------------------------------ 6. bật magpie
step "6/7 · bật gateway + web UI"
"$HOME/.local/bin/openmagpie" || die "không bật được magpie"

# ------------------------------------------------------------ 7. việc còn lại
step "7/7 · việc còn lại"
cat <<'EOF'
  Bạn cần đăng nhập provider (phần duy nhất phải làm bằng tay):

    bash scripts/login.sh              xem trạng thái
    bash scripts/login.sh autoclaw     AutoClaw (Zhipu) — quan trọng nhất
    bash scripts/login.sh workbuddy    WorkBuddy AI
    bash scripts/login.sh qoder        Qoder
    bash scripts/login.sh keys         OpenCode Zen / Kilo (dán key)

  AutoClaw trên Cloud Shell cần chuyển tiếp cổng — đọc docs/autoclaw-login.md.

  Đăng nhập xong thì tạo group + trỏ agent:

    bash scripts/finish.sh

  Rồi mở lại link ở trên (hoặc chạy `openchamber` để mở cả hai).
EOF

printf '\n\033[1mXong phần cài đặt.\033[0m\n'
