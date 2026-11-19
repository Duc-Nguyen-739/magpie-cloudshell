#!/usr/bin/env bash
# setup-settings.sh — đặt cấu hình magpie giống máy tham chiếu:
#   - settings.json: theme, ngôn ngữ, vision model, image model, check-in, cỡ chữ…
#   - provider: opencode-zen bật nhưng chỉ expose jev-1.13-free (classifier); opencode-zen-free tắt
#     (free tier qua API key bị chặn, đường plugin cạn theo IP dùng chung — xem docs/zen-free.md);
#     qoder/aihubmix/agnes tắt hẳn; kilo **bật** (group/free dùng particle-1:free);
#     kiro **bật** (group/tester-3 dùng claude-haiku-4.5);
#     workbuddy-ai chỉ expose deepseek-v4.1-flash-sg, glm-5.3-flash, hy4flash-free
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
say "provider: opencode-zen bật (chỉ jev-1.13-free) · opencode-zen-free tắt"
# jev-1.13-free là model phân loại nội bộ, không bị chặn free tier và không hiện cho
# agent; các model free còn lại của Zen đã 429 nên không expose. Catalog đổi liên tục
# (model mới tự được expose), nên không dùng danh sách trừ cố định: đọc danh sách đang
# expose rồi bỏ hết trừ jev-1.13-free.
ZEN_KEEP="jev-1.13-free"
zen_drop_list() { # in ra từng model đang expose, trừ ZEN_KEEP
  magpie provider opencode-zen 2>/dev/null \
    | awk '/opencode-zen\// {print $1}' \
    | sed 's|^opencode-zen/||' \
    | grep -vx "$ZEN_KEEP" || true
}
if [ "$DRY" = 1 ]; then
  printf '  \033[2m[dry-run]\033[0m magpie provider on opencode-zen\n'
  printf '  \033[2m[dry-run]\033[0m magpie provider models opencode-zen +jev-1.13-free\n'
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    printf '  \033[2m[dry-run]\033[0m magpie provider models opencode-zen -%s\n' "$m"
  done < <(zen_drop_list)
  printf '  \033[2m[dry-run]\033[0m magpie provider off opencode-zen-free\n'
  printf '  \033[2m[dry-run]\033[0m magpie provider off qoder antigravity copilot aihubmix agnes\n'
  printf '  \033[2m[dry-run]\033[0m magpie provider models workbuddy-ai deepseek-v4.1-flash-sg glm-5.3-flash hy4flash-free\n'
else
  if magpie provider on opencode-zen >/dev/null 2>&1; then
    ok "opencode-zen đang bật"
  else
    warn "không bật được opencode-zen (chưa thêm key?) — bỏ qua"
  fi
  magpie provider models opencode-zen +jev-1.13-free >/dev/null 2>&1 \
    && ok "opencode-zen expose jev-1.13-free" \
    || warn "không expose được jev-1.13-free — classifier sẽ không đặt được"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    magpie provider models opencode-zen -"$m" >/dev/null 2>&1
  done < <(zen_drop_list)
  ok "opencode-zen chỉ còn jev-1.13-free"
  if magpie provider off opencode-zen-free >/dev/null 2>&1; then
    ok "opencode-zen-free đang tắt (plugin vẫn cài, bật lại được)"
  else
    warn "không tắt được opencode-zen-free (chưa cài plugin?) — bỏ qua"
  fi

  # qoder / antigravity / copilot / aihubmix / agnes không nằm trong ladder nào: tắt
  # hẳn. kilo thì BẬT — group/free dùng particle-1:free; kiro BẬT vì tester-3 dùng
  # claude-haiku-4.5.
  for off_id in qoder antigravity copilot aihubmix agnes; do
    if magpie provider off "$off_id" >/dev/null 2>&1; then
      ok "provider $off_id đang tắt"
    else
      warn "không tắt được $off_id (chưa thêm?) — bỏ qua"
    fi
  done
  # WorkBuddy: chỉ expose đúng ba model đang dùng trong group.
  wb_want=()
  for m in deepseek-v4.1-flash-sg glm-5.3-flash hy4flash-free; do
    has_model "workbuddy-ai/$m" && wb_want+=("$m")
  done
  if [ ${#wb_want[@]} -gt 0 ]; then
    magpie provider models workbuddy-ai "${wb_want[@]}" >/dev/null 2>&1 \
      && ok "workbuddy-ai expose: ${wb_want[*]}" \
      || warn "không đặt được danh sách model workbuddy-ai"
  fi
fi

# ---------------------------------------------------------------- settings
# Giá trị lấy từ máy tham chiếu (magpie 0.1.4334). vision/imageGen chỉ đặt khi
# model tương ứng đã có, để UI không trỏ vào model không tồn tại.
VISION="workbuddy-ai/hy4flash-free"
IMAGE="workbuddy-ai/hy-image-3.5"

seed='{
  "theme": "dark",
  "lang": "system",
  "tray": "panel",
  "currency": "usd",
  "dockNever": true,
  "dockSettled": true,
  "otel": {},
  "sessionReads": {"asked": true, "all": true},
  "pluginCheckins": {"autoclaw": true, "qoder": true},
  "updateEvery": 360,
  "redact": true,
  "redactShape": true,
  "redactModelName": "astrlink-guard",
  "redactModelAuto": true,
  "redactPersonal": true,
  "redactKinds": {"bucket": true, "home": true, "ip": true, "userhost": true},
  "quotaLeft": true,
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
