#!/usr/bin/env bash
# setup-agents.sh — trỏ các agent đang cài vào group đúng: OpenCode → group/leader
# (lùi về group/main nếu máy chưa có leader), OpenChamber → group/leader.
# Small model của OpenCode để mặc định (không ghim model riêng).
#
#   bash scripts/setup-agents.sh
#   bash scripts/setup-agents.sh --dry-run
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$PATH"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

run() {
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*"; else "$@"; fi
}

command -v magpie >/dev/null 2>&1 || { echo "chưa có magpie trên PATH" >&2; exit 1; }

# Đọc vào biến rồi mới grep: grep -q trên pipe làm grep thoát sớm, magpie ăn SIGPIPE
# (141) và với pipefail cả pipeline báo lỗi oan.
groups_now="$(magpie groups 2>/dev/null || true)"
if ! printf '%s\n' "$groups_now" | grep -q "group/main"; then
  warn "chưa có group/main — chạy bash scripts/setup-groups.sh trước"
fi
if ! printf '%s\n' "$groups_now" | grep -q "group/leader"; then
  warn "chưa có group/leader — chạy bash scripts/setup-groups.sh trước"
fi

agents_now="$(magpie ls 2>/dev/null || true)"
have_agent() { printf '%s\n' "$agents_now" | grep -qiE "^[[:space:]]*$1[[:space:]]"; }

# ------------------------------------------------------------------ OpenCode
if have_agent "OpenCode"; then
  # Máy hiện tại dùng group/leader cho cả OpenCode và OpenChamber. Nếu máy mới
  # chưa có leader (chưa đăng nhập đủ provider) thì lùi về group/main.
  oc_group="group/leader"
  if ! printf '%s\n' "$groups_now" | grep -q "group/leader"; then
    oc_group="group/main"
    warn "chưa có group/leader — OpenCode dùng group/main"
  fi
  say "OpenCode → $oc_group"
  run magpie opencode "$oc_group" && ok "OpenCode xong"

  # Small model: để OpenCode tự chọn (máy hiện tại không ghim model riêng).
  if magpie opencode small 2>/dev/null | grep -q 'magpie/'; then
    say "OpenCode small → mặc định"
    run magpie opencode small default && ok "small model về mặc định"
  fi
else
  warn "không thấy OpenCode (cài bằng bash scripts/install-opencode.sh)"
fi

# --------------------------------------------------------------- OpenChamber
if have_agent "OpenChamber"; then
  say "OpenChamber → group/leader"
  run magpie openchamber group/leader && ok "OpenChamber xong"

  # Hai khoá này OpenChamber tự lưu trong settings.json, không có lệnh magpie.
  # Chỉ ghi khi app đang tắt (cổng 3000 không trả lời); app đang chạy sẽ ghi đè.
  OC_SETTINGS="$HOME/.config/openchamber/settings.json"
  if [ -f "$OC_SETTINGS" ] && ! curl -fsS -o /dev/null -m 1 "http://127.0.0.1:${OPENCHAMBER_PORT:-3000}/" 2>/dev/null; then
    if [ "$DRY" = 1 ]; then
      printf '  \033[2m[dry-run]\033[0m đặt OpenChamber defaultAgent=leader, defaultVariant=max\n'
    else
      python3 - "$OC_SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    data = json.load(f)
changed = []
for key, value in (("defaultAgent", "leader"), ("defaultVariant", "max")):
    if data.get(key) != value:
        data[key] = value
        changed.append(key)
if changed:
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  ✓ OpenChamber:", ", ".join(changed))
else:
    print("  ✓ OpenChamber: defaultAgent/defaultVariant đã đúng")
PY
    fi
  elif [ -f "$OC_SETTINGS" ]; then
    warn "OpenChamber đang chạy — không sửa settings.json; mở Settings để đặt agent leader / variant max"
  fi
else
  warn "không thấy OpenChamber (cài bằng bash scripts/install-openchamber.sh)"
fi

# Các agent khác (Claude Code, Codex, Gemini CLI, Pi…) không bị đụng tới.
# Muốn trỏ một cái: magpie <agent> group/main   (vd: magpie gemini group/main)

say ""
say "Agent đọc model lúc khởi động: mở phiên mới (hoặc restart) để nhận group mới."
