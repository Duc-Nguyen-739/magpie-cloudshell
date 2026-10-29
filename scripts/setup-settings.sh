#!/usr/bin/env bash
# setup-settings.sh — đặt cấu hình magpie giống máy tham chiếu:
#   - settings.json: theme, ngôn ngữ, vision model, image model, check-in, cỡ chữ…
#   - provider: bật opencode-zen-free, tắt opencode-zen (free tier qua API key đã bị chặn;
#     xem docs/zen-free.md)
#
# Chỉ **thêm khoá còn thiếu**, không ghi đè giá trị bạn đã đặt. Chạy lại vô hại.
#
#   bash scripts/setup-settings.sh
#   bash scripts/setup-settings.sh --dry-run
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

CONF="$HOME/.config/magpie"
SETTINGS="$CONF/settings.json"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

command -v magpie >/dev/null 2>&1 || { echo "chưa có magpie trên PATH" >&2; exit 1; }

models="$(magpie models 2>/dev/null | awk '{print $1}')"
has_model() { printf '%s\n' "$models" | grep -Fxq "$1"; }

# ---------------------------------------------------------------- provider
say "provider opencode-zen-free → bật · opencode-zen → tắt"
if [ "$DRY" = 1 ]; then
  printf '  \033[2m[dry-run]\033[0m magpie provider on opencode-zen-free\n'
  printf '  \033[2m[dry-run]\033[0m magpie provider off opencode-zen\n'
else
  if magpie provider on opencode-zen-free >/dev/null 2>&1; then
    ok "opencode-zen-free đang bật"
  else
    warn "không bật được opencode-zen-free (có thể chưa cài plugin) — bỏ qua"
  fi
  if magpie provider off opencode-zen >/dev/null 2>&1; then
    ok "opencode-zen đang tắt (giữ key, không xoá)"
  else
    warn "không tắt được opencode-zen (chưa từng thêm?) — bỏ qua"
  fi
fi

# ---------------------------------------------------------------- settings
# Giá trị lấy từ máy tham chiếu (magpie 0.1.1763). vision/imageGen chỉ đặt khi
# model tương ứng đã có, để UI không trỏ vào model không tồn tại.
VISION="workbuddy-ai/deepseek-v4.1-flash"
IMAGE="workbuddy-ai/hy-image-3.5"

seed='{
  "theme": "dark",
  "lang": "system",
  "tray": "panel",
  "currency": "usd",
  "pluginCheckins": {"autoclaw": true},
  "updateEvery": 360,
  "visionEffort": "max",
  "trayUsageEvery": 3,
  "textSize": 110
}'

has_model "$VISION" && seed="$(printf '%s' "$seed" | python3 -c 'import json,sys;d=json.load(sys.stdin);d["vision"]="'"$VISION"'";print(json.dumps(d))')"
has_model "$IMAGE"  && seed="$(printf '%s' "$seed" | python3 -c 'import json,sys;d=json.load(sys.stdin);d["imageGen"]="'"$IMAGE"'";print(json.dumps(d))')"

say "settings.json — chỉ thêm khoá còn thiếu"
if [ "$DRY" = 1 ]; then
  printf '  \033[2m[dry-run]\033[0m merge: %s\n' "$(printf '%s' "$seed" | tr -d '\n' | cut -c1-160)"
else
  mkdir -p "$CONF"
  SEED="$seed" SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os, sys
p = os.environ["SETTINGS"]
seed = json.loads(os.environ["SEED"])
data = {}
if os.path.exists(p):
    try:
        with open(p) as f:
            data = json.load(f)
    except Exception:
        print("  ! settings.json hiện tại không đọc được — để nguyên", file=sys.stderr)
        sys.exit(0)
changed = []
for k, v in seed.items():
    if k not in data:
        data[k] = v
        changed.append(k)
    elif k == "pluginCheckins" and isinstance(data[k], dict):
        for kk, vv in v.items():
            if kk not in data[k]:
                data[k][kk] = vv
                changed.append(f"pluginCheckins.{kk}")
if changed:
    with open(p, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.chmod(p, 0o600)
    print("  ✓ thêm:", ", ".join(changed))
else:
    print("  ✓ đã đủ, không đổi gì")
PY
fi
