#!/usr/bin/env bash
# bootstrap.sh — cài đặt một lần: magpie + provider plugin + OpenCode + OpenChamber
# + các lệnh tiện dụng (openchamber, openmagpie, magpie-headless-*).
#
#   bash bootstrap.sh              cài đủ
#   bash bootstrap.sh --from-source   build magpie từ repo chính chủ (cần Go)
#   bash bootstrap.sh --minimal    chỉ magpie (bỏ OpenCode/OpenChamber)
#   bash bootstrap.sh --no-autostart  không thêm hook vào ~/.bashrc
#
# Chạy lại nhiều lần vẫn an toàn: bước nào có rồi thì bỏ qua.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

MINIMAL=0
AUTOSTART=1
FROM_SOURCE=0
for a in "$@"; do
  case "$a" in
    --minimal)      MINIMAL=1 ;;
    --no-autostart) AUTOSTART=0 ;;
    --from-source)  FROM_SOURCE=1 ;;
    -h|--help)      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
step "1/9 · magpie (bản terminal, headless)"
if [ "$FROM_SOURCE" = 1 ]; then
  bash "$REPO_DIR/scripts/install-from-source.sh" || die "build từ repo chính chủ thất bại"
else
  bash "$REPO_DIR/scripts/install.sh" || die "cài magpie thất bại"
fi
export PATH="$HOME/.local/bin:$PATH"

# ----------------------------------------------------------------- 2. plugins
step "2/9 · plugin provider (lần đầu tải bun ~180 MB)"
bash "$REPO_DIR/scripts/plugins.sh" || warn "một số plugin chưa cài được; chạy lại sau"

# ------------------------------------------------------- 3. lệnh tiện dụng
step "3/9 · lệnh tiện dụng trong ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for f in openchamber openmagpie magpie-headless magpie-headless-start magpie-headless-stop magpie-headless-status; do
  install -m 755 "$REPO_DIR/scripts/$f" "$HOME/.local/bin/$f"
  ok "~/.local/bin/$f"
done
install -m 755 "$REPO_DIR/scripts/autoclaw-link.sh" "$HOME/.local/bin/autoclaw-link"
ok "~/.local/bin/autoclaw-link"

# Bản sao scripts + config, để `magpie-finish` chạy được cả khi repo đã bị xoá.
SHARE="$HOME/.local/share/magpie-cloudshell"
mkdir -p "$SHARE"
cp -R "$REPO_DIR/scripts" "$SHARE/"
cp -R "$REPO_DIR/config" "$SHARE/" 2>/dev/null || true
cat > "$HOME/.local/bin/magpie-finish" <<EOF
#!/usr/bin/env bash
# Tạo/cập nhật routing group + trỏ agent (bản cài từ magpie-cloudshell).
exec bash "$SHARE/scripts/finish.sh" "\$@"
EOF
chmod 755 "$HOME/.local/bin/magpie-finish"
ok "~/.local/bin/magpie-finish"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

# ------------------------------------------- 4. PATH + autostart trong .bashrc
step "4/9 · PATH và tự bật khi mở shell"
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
  step "5/9 · OpenCode + OpenChamber — bỏ qua (--minimal)"
else
  step "5/9 · OpenCode + OpenChamber"
  bash "$REPO_DIR/scripts/install-opencode.sh" || warn "OpenCode chưa cài được"
  bash "$REPO_DIR/scripts/install-openchamber.sh" || warn "OpenChamber chưa cài được"
  bash "$REPO_DIR/scripts/setup-opencode.sh" || warn "subagent/skill chưa cài được"
fi

# ------------------------------------------------------------ 6. bật magpie
step "6/9 · bật gateway + web UI"
"$HOME/.local/bin/openmagpie" || die "không bật được magpie"

# ------------------------------------------------------- 7. cấu hình magpie
step "7/9 · cấu hình magpie (settings, provider tắt)"
bash "$REPO_DIR/scripts/setup-settings.sh" || warn "chưa đặt được settings"

# ------------------------------------------------ 8. group + agent (nếu có model)
step "8/9 · routing group + agent"
if magpie models 2>/dev/null | grep -q .; then
  bash "$REPO_DIR/scripts/setup-groups.sh" --force || warn "chưa tạo được group (xem lỗi ở trên)"
  bash "$REPO_DIR/scripts/setup-agents.sh" || warn "chưa trỏ được agent"
else
  warn "chưa có provider/model nào — sau khi đăng nhập, login.sh tự tạo group"
fi

# ------------------------------------------------------------ 8. việc còn lại
step "9/9 · việc còn lại: chỉ đăng nhập"
cat <<'EOF'
  Không phải cài gì thêm. Chỉ đăng nhập provider:

    bash scripts/login.sh autoclaw     AutoClaw (Zhipu) — quan trọng nhất
    bash scripts/login.sh workbuddy    WorkBuddy AI
    bash scripts/login.sh qoder        Qoder
    bash scripts/login.sh keys         OpenCode Zen / Kilo (dán key)

  Mỗi lần đăng nhập xong, script tự tạo/cập nhật group và trỏ agent (chạy
  finish.sh). AutoClaw trên Cloud Shell cần chuyển tiếp cổng —
  đọc docs/autoclaw-login.md (mục "Cách A").

  Sau đó mở link ở trên, hoặc chạy `openchamber` để mở cả hai.
EOF

printf '\n\033[1mXong phần cài đặt.\033[0m\n'
