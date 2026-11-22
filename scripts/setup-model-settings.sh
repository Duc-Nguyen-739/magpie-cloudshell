#!/usr/bin/env bash
# setup-model-settings.sh — đồng bộ phần cài đặt **theo model** và **theo provider**
# mà `setup-settings.sh` không đụng tới:
#
#   - giá model (input/output/cache read/cache write) — `magpie model price`
#   - context window (input) + max output — `magpie model spec`
#   - reasoning levels — `magpie model efforts` / `--reasoning`
#   - API của model (chat/responses/anthropic/gemini) — `magpie model api`
#   - FreePi: model expose, queue, account-concurrency, routing
#
# Chỉ áp cho model/provider **đang có**; thiếu thì cảnh báo rồi bỏ qua. Chạy lại
# nhiều lần vô hại. Đây là script duy nhất cần chạy lại sau khi đăng nhập provider.
#
#   bash scripts/setup-model-settings.sh
#   bash scripts/setup-model-settings.sh --dry-run
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

run() {
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*" >&2; else "$@"; fi
}

command -v magpie >/dev/null 2>&1 || { echo "chưa có magpie trên PATH" >&2; exit 1; }

models="$(magpie models 2>/dev/null | awk '{print $1}')"
providers="$(magpie providers 2>/dev/null || true)"
has_model()    { printf '%s\n' "$models" | grep -Fxq "$1"; }
has_provider() { printf '%s\n' "$providers" | awk -v id="$1" '$2 == id { found = 1 } END { exit !found }'; }

# ------------------------------------------------------------------ giá model
# Giá tính bằng USD / 1 triệu token: in,out,cache-read,cache-write.
# `*/<model>` là giá chung cho mọi provider chưa có giá riêng.
set_price() { # <provider/model|*/model> <in,out,cache-read,cache-write>
  local m=$1 p=$2
  case "$m" in
    *'*'*) ;;
    *) has_model "$m" || { warn "bỏ qua giá $m — model chưa có"; return 0; } ;;
  esac
  if run magpie model price "$m" "$p" >/dev/null 2>&1; then
    ok "giá $m = $p"
  else
    warn "không đặt được giá $m"
  fi
}

say "giá model (input/output/cache)"
set_price '*/deepseek-v4.1-flash'            1,4,0.1,1.25
set_price '*/jev-1.13-free'                  0,0,0,0
set_price 'workbuddy-ai/deepseek-v4.1-flash-sg' 1,4,0.1,1.25
set_price 'workbuddy-ai/glm-5.3-flash'       1,4,0.1,1.25
set_price 'workbuddy-ai/hy3'                 0,0,0,0
set_price 'workbuddy-ai/hy4free'             0,0,0,0

# -------------------------------------------------------- context / output
# Giới hạn của model FreePi: 1.048.576 token input, 32.768 token output. Catalog
# plugin cũng khai đúng, nhưng đặt tường minh để máy khác không phụ thuộc bản
# plugin đang cài. Model nào chưa có thì bỏ qua.
FREEPI_IDS=(freepi freepi2 freepi3 freepi4 freepi5 freepi6 freepi7)
FREEPI_MODEL=deepseek-v4.1-flash
FREEPI_CONTEXT=1048576
FREEPI_OUTPUT=32768
FREEPI_EFFORTS=none,minimal,low,medium,high,xhigh,max

# Provider FreePi: một request một lúc mỗi tài khoản, queue 32, không giới hạn RPM.
# `freepi` có hai entry tài khoản trong providers.json nên đặt theo từng account id;
# provider mới đăng nhập có thể chưa có entry → đọc account id từ `magpie accounts`.
freepi_accounts() { # <provider-id> — chỉ tài khoản đang đăng nhập
  # Dòng `magpie accounts`: "● freepi7 <tên hiển thị> · <account-id> · <quota>".
  # providers.json có thể còn entry cũ đã đăng xuất; đặt concurrency cho entry đó
  # sẽ lỗi, nên lấy danh sách từ `magpie accounts`.
  magpie accounts 2>/dev/null \
    | awk -v id="$1" '$2 == id { n = split($0, a, "·"); if (n >= 2) { gsub(/^[ \t]+|[ \t]+$/, "", a[2]); print a[2] } }' \
    | sort -u | tr '\n' ' '
}

for id in "${FREEPI_IDS[@]}"; do
  if ! has_provider "$id"; then
    say "$id chưa đăng nhập — bỏ qua cấu hình provider"
    continue
  fi
  run magpie provider models "$id" "$FREEPI_MODEL" >/dev/null 2>&1 \
    && ok "$id: expose $FREEPI_MODEL" \
    || warn "$id: không đặt được danh sách model"
  run magpie provider queue "$id" 32 0 >/dev/null 2>&1 \
    && ok "$id: queue 32, chờ không giới hạn" \
    || warn "$id: không đặt được queue"
  run magpie provider rpm "$id" off >/dev/null 2>&1 \
    && ok "$id: rpm không giới hạn" \
    || warn "$id: không đặt được rpm"
  for account in $(freepi_accounts "$id"); do
    run magpie provider account-concurrency "$id" "$account" 1 >/dev/null 2>&1 \
      && ok "$id/$account: 1 request cùng lúc" \
      || warn "$id/$account: không đặt được account-concurrency"
  done
done

# Đọc lại danh sách model sau khi expose, rồi mới ghim context/output/vision/efforts.
say ""
say "FreePi — input/output, vision, reasoning"
models="$(magpie models 2>/dev/null | awk '{print $1}')"
for id in "${FREEPI_IDS[@]}"; do
  m="$id/$FREEPI_MODEL"
  if ! has_model "$m"; then
    warn "bỏ qua $m — provider chưa đăng nhập hoặc chưa expose model"
    continue
  fi
  if run magpie model spec "$m" --context "$FREEPI_CONTEXT" --output "$FREEPI_OUTPUT" \
       --vision on --reasoning "$FREEPI_EFFORTS" >/dev/null 2>&1; then
    ok "$m: input $FREEPI_CONTEXT · output $FREEPI_OUTPUT · vision on · efforts 7 mức"
  else
    warn "$m: không đặt được context/output/efforts"
  fi
done

# `freepi` là tài khoản chính, có nhiều entry; drain một tài khoản hết budget rồi
# mới sang tài khoản kế. Các FreePi khác để mặc định.
if has_provider freepi; then
  run magpie provider set freepi routing=drain >/dev/null 2>&1 \
    && ok "freepi: routing=drain" \
    || warn "freepi: không đặt được routing=drain"
fi

# --------------------------------------------------------------- API model
# Xingchi chỉ sống trên Responses API; các model còn lại dùng chat mặc định.
say ""
say "API model"
for m in xingchi/gpt-5.3-codex-spark xingchi/gpt-6 xingchi/gpt-6.1-sol; do
  has_model "$m" || continue
  run magpie model api "$m" responses >/dev/null 2>&1 \
    && ok "$m: responses" \
    || warn "$m: không đặt được API responses"
done

say ""
if [ "$DRY" = 1 ]; then
  say "dry-run: không thay đổi gì."
else
  ok "xong. Xem: magpie model prices · magpie model specs · magpie provider freepi7"
fi
