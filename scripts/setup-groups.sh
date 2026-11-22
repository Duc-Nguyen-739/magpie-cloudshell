#!/usr/bin/env bash
# setup-groups.sh — tạo tám routing group mẫu: main, leader, review,
# reviewplan, coder, tester, tester-2, tester-3.
#
#   bash scripts/setup-groups.sh            tạo group còn thiếu, bỏ qua group đã có
#   bash scripts/setup-groups.sh --force    tạo lại (thay) sáu group cố định;
#                                           review/reviewplan chỉ tạo khi thiếu
#   bash scripts/setup-groups.sh --dry-run  chỉ in lệnh, không đổi gì
#
# Model trong group là do người dùng tự chọn: finish.sh và bootstrap.sh gọi script
# này **không** kèm --force, nên chỉ tạo group còn thiếu và giữ nguyên ladder đã
# sửa. Muốn reset một group: `magpie group rm <id>` rồi chạy lại script.
#
# Chỉ đưa vào group những model thật sự có (đã đăng nhập provider), nên chạy được
# cả khi mới đăng nhập 1-2 provider. Group đã có thì giữ nguyên; thêm model bằng
# `magpie group set <id> models+=<provider/model>`.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

FORCE=0
DRY=0
for a in "$@"; do
  case "$a" in
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'tham số lạ: %s (dùng --force, --dry-run)\n' "$a" >&2; exit 2 ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*" >&2; else "$@"; fi
}

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH (~/.local/bin)"

CLASSIFIER=opencode-zen/jev-1.13-free
LEVELS_FULL=low,high,max

# ------------------------------------------------------- model nào đang có
models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
groups_now="$(magpie groups 2>/dev/null || true)"
[ -n "$models_now" ] || die "magpie chưa có model nào — đăng nhập provider trước (bash scripts/login.sh)"

join() { local IFS=,; printf '%s' "$*"; }

# Bỏ hậu tố mức reasoning (:high/:max) khi kiểm tra model có thật; giữ nguyên hậu tố
# khi đưa vào group. Model mà tên vốn có hậu tố (:free) khớp đúng nguyên chuỗi.
filter_models() {
  local m base
  for m in "$@"; do
    base="${m%%:*}"
    if printf '%s\n' "$models_now" \
      | awk -v m="$m" -v base="$base" '$0 == m || $0 == base || index($0, base ":") == 1 { f = 1 } END { exit !f }'; then
      printf '%s\n' "$m"
    else
      warn "thiếu $base (provider chưa đăng nhập, hoặc model đã bị provider bỏ khỏi danh sách)"
    fi
  done
}

group_name_now() { # tên hiển thị hiện tại của một group id
  magpie group "$1" 2>/dev/null | head -1 | sed 's/^ *//; s/  *group\/.*//'
}

make_group() { # <tên> <id> <stays> <levels> <model…>
  local name=$1 id=$2 stays=$3 levels=$4; shift 4
  local present=() m
  while IFS= read -r m; do [ -n "$m" ] && present+=("$m"); done < <(filter_models "$@")
  if [ ${#present[@]} -eq 0 ]; then
    warn "bỏ qua group/$id: không có model nào trong danh sách"
    return 0
  fi

  if printf '%s\n' "$groups_now" | awk -v g="group/$id" '{ for (i = 1; i <= NF; i++) if ($i == g) found = 1 } END { exit !found }'; then
    if [ "$FORCE" != 1 ]; then
      say "group/$id đã có — bỏ qua (dùng --force để tạo lại)"
      return 0
    fi
    # Nếu tên hiển thị đã bị đổi, `group add <tên mới>` sẽ tạo id mới (main-2)
    # thay vì thay group cũ; xoá trước trong trường hợp đó.
    if [ "$(group_name_now "$id")" != "$name" ]; then
      say "thay group/$id (tên cũ khác)"
      run magpie group rm "$id" >/dev/null 2>&1 || warn "không xoá được group/$id"
    else
      say "thay group/$id"
    fi
  fi

  local list; list="$(join "${present[@]}")"
  run magpie group add "$name" "models=$list" routing=order "stays=$stays" >/dev/null \
    || { warn "không tạo được group/$id"; return 1; }

  # levels + classifier + effort đi cùng một lệnh: magpie ghi file có độ trễ, tách
  # lệnh thì lệnh sau có thể chưa thấy classifier của lệnh trước.
  if [ "$DRY" = 1 ]; then
    run magpie group set "$id" "levels=$levels" "classifier=$CLASSIFIER" effort=auto
  elif magpie group set "$id" "levels=$levels" "classifier=$CLASSIFIER" effort=auto >/dev/null 2>&1; then
    ok "group/$id: ${#present[@]} model · levels=$levels · classifier=$CLASSIFIER"
  elif magpie group set "$id" "levels=$levels" >/dev/null 2>&1; then
    warn "group/$id: không đặt được classifier $CLASSIFIER — giữ levels"
  else
    warn "group/$id: không đặt được levels"
  fi
}

# Như make_group nhưng có classifier và KHÔNG BAO GIỜ reset, kể cả --force:
# review và reviewplan là hai group người dùng tự thêm model vào ladder sau khi
# cài. Muốn reset: magpie group rm <id> rồi chạy lại script.
make_plain_group_keep() { # <tên> <id> <stays> <model…>
  local name=$1 id=$2 stays=$3; shift 3
  local present=() m
  while IFS= read -r m; do [ -n "$m" ] && present+=("$m"); done < <(filter_models "$@")
  if [ ${#present[@]} -eq 0 ]; then
    warn "bỏ qua group/$id: không có model nào trong danh sách"
    return 0
  fi

  if printf '%s\n' "$groups_now" | awk -v g="group/$id" '{ for (i = 1; i <= NF; i++) if ($i == g) found = 1 } END { exit !found }'; then
    say "group/$id đã có — giữ nguyên ladder (không reset kể cả --force)"
    return 0
  fi

  local list; list="$(join "${present[@]}")"
  run magpie group add "$name" "models=$list" routing=order "stays=$stays" >/dev/null \
    || { warn "không tạo được group/$id"; return 1; }
  # Levels none/low/high/max như đang chạy trên máy; group add không nhận levels
  # lẫn classifier nên đặt bằng một lệnh set (magpie ghi file có độ trễ).
  if [ "$DRY" = 1 ]; then
    run magpie group set "$id" levels=none,low,high,max "classifier=$CLASSIFIER" effort=auto
  elif magpie group set "$id" levels=none,low,high,max "classifier=$CLASSIFIER" effort=auto >/dev/null 2>&1; then
    ok "group/$id: ${#present[@]} model · levels none/low/high/max · classifier=$CLASSIFIER · stays=$stays"
  else
    warn "group/$id: ${#present[@]} model · không đặt được levels/classifier"
  fi
}

# ------------------------------------------------------------ định nghĩa
# main — chat thường ngày, stays=session để prompt cache còn giá trị.
MAIN_MODELS=(
  freepi/deepseek-v4.1-flash
  workbuddy-ai/hy4flash-free
  agy-cli/gemini-3.8-flash
  agy-cli/gemini-2.5-flash-lite
  autoclaw/zai_glm-5.3-flash
  workbuddy-ai/glm-5.3-flash
)

# leader — OpenChamber: lên plan và điều phối; sol ghim :high đứng đầu, FreePi6,
# Opus và DeepSeek SG dự phòng. gpt-6-astra bị bỏ: pool upstream Xingchi trả 503
# (2026-11-17). FreePi6 đứng sau sol để tài khoản FreePi chính không bị giành.
LEADER_MODELS=(
  xingchi/gpt-6.1-sol:high
  freepi6/deepseek-v4.1-flash
  agy-cli/claude-opus-4-6-thinking
  workbuddy-ai/deepseek-v4.1-flash-sg
)

# review — khảo sát, brief hướng rồi viết plan. FreePi chính ghim :high; DeepSeek SG
# và Hy4 cùng :high dự phòng. Levels none/low/high/max như đang chạy trên máy
# (magpie mở levels khi đặt effort=auto), classifier jev như các group khác.
REVIEW_MODELS=(
  freepi/deepseek-v4.1-flash:high
  workbuddy-ai/deepseek-v4.1-flash-sg:high
  workbuddy-ai/hy4flash-free:high
)

# reviewplan — gác hướng, kiểm chứng/sửa plan và audit cuối. Dùng tài khoản FreePi5
# để không giành slot với review; hai bậc WorkBuddy dự phòng.
REVIEWPLAN_MODELS=(
  freepi5/deepseek-v4.1-flash:high
  workbuddy-ai/deepseek-v4.1-flash-sg:high
  workbuddy-ai/hy4flash-free:high
)

# coder — viết code theo plan. FreePi chính ghim :high, DeepSeek SG dự phòng.
CODER_MODELS=(
  freepi/deepseek-v4.1-flash:high
  workbuddy-ai/deepseek-v4.1-flash-sg:high
)

# tester — kiểm tra và chạy test. FreePi4 để ba tester chạy song song không giành
# slot; Agnes đang tắt nên không đưa vào ladder.
TESTER_MODELS=(
  freepi4/deepseek-v4.1-flash
  workbuddy-ai/glm-5.3-flash
)

# tester-2 — tester độc lập, chạy song song với tester. FreePi2 đứng đầu; WorkBuddy
# và AutoClaw dự phòng.
TESTER2_MODELS=(
  freepi2/deepseek-v4.1-flash
  workbuddy-ai/hy4flash-free
  autoclaw/zai_glm-5.3-flash
)

# tester-3 — tester thứ ba, soi hợp đồng dữ liệu và regression ngoài phạm vi. FreePi3
# đứng đầu; Kiro, AutoClaw, Gemini và hai bậc WorkBuddy dự phòng.
TESTER3_MODELS=(
  freepi3/deepseek-v4.1-flash
  kiro/claude-haiku-4.5
  autoclaw/zai_glm-5.3-flash
  agy-cli/gemini-3.8-flash
  workbuddy-ai/hy4flash-free
  workbuddy-ai/deepseek-v4.1-flash-sg
)

# Group từng có trong định nghĩa nhưng nay đã bỏ. `group add` không xoá group thừa,
# nên phải dọn tay, nếu không máy sẽ lệch script sau mỗi lần đổi định nghĩa.
# `free` là tên cũ của group nén; máy hiện dùng `group/compress` do người dùng tạo.
RETIRED_GROUPS=(code glm deepseek free)
for id in "${RETIRED_GROUPS[@]}"; do
  printf '%s\n' "$groups_now" | awk -v g="group/$id" '{ for (i = 1; i <= NF; i++) if ($i == g) found = 1 } END { exit !found }' || continue
  if [ "$FORCE" = 1 ]; then
    if [ "$DRY" = 1 ]; then
      run magpie group rm "$id"
    elif magpie group rm "$id" >/dev/null 2>&1; then
      ok "đã xoá group/$id (bỏ khỏi định nghĩa)"
    else
      warn "không xoá được group/$id"
    fi
  else
    warn "group/$id còn trên máy nhưng không còn trong định nghĩa — chạy --force để xoá"
  fi
done

# --------------------------------------------------------------- tạo group
say ""
say "group/leader — OpenChamber, stays=turn"
make_group "Leader" leader turn "$LEVELS_FULL" "${LEADER_MODELS[@]}"

say ""
say "group/review — khảo sát + viết plan, stays=turn"
make_plain_group_keep "Review" review turn "${REVIEW_MODELS[@]}"

say ""
say "group/reviewplan — kiểm chứng/sửa plan + audit cuối, stays=turn"
make_plain_group_keep "Reviewplan" reviewplan turn "${REVIEWPLAN_MODELS[@]}"

say ""
say "group/coder — viết code, stays=turn"
make_group "Coder" coder turn "$LEVELS_FULL" "${CODER_MODELS[@]}"

say ""
say "group/tester — kiểm tra, stays=turn"
make_group "Tester" tester turn "$LEVELS_FULL" "${TESTER_MODELS[@]}"

say ""
say "group/tester-2 — tester độc lập, stays=turn"
make_group "Tester 2" tester-2 turn "$LEVELS_FULL" "${TESTER2_MODELS[@]}"

say ""
say "group/tester-3 — tester thứ ba, stays=turn"
make_group "Tester 3" tester-3 turn "$LEVELS_FULL" "${TESTER3_MODELS[@]}"

say ""
say "group/main — chat thường ngày, stays=session"
make_group "Main" main session "$LEVELS_FULL" "${MAIN_MODELS[@]}"

say ""
if [ "$DRY" = 1 ]; then
  say "dry-run: không thay đổi gì."
else
  ok "xong. Xem lại: magpie groups"
fi
