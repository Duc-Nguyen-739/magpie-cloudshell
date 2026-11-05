#!/usr/bin/env bash
# setup-groups.sh — tạo ba routing group đang dùng: main, code, glm.
#
#   bash scripts/setup-groups.sh            tạo group còn thiếu, bỏ qua group đã có
#   bash scripts/setup-groups.sh --force    tạo lại (thay) cả ba group
#   bash scripts/setup-groups.sh --dry-run  chỉ in lệnh, không đổi gì
#
# Chỉ đưa vào group những model thật sự có (đã đăng nhập provider), nên chạy được
# cả khi mới đăng nhập 1-2 provider; chạy lại sau khi đăng nhập thêm để lấp đủ.
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
  if [ "$DRY" = 1 ]; then
    printf '  \033[2m[dry-run]\033[0m'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- dữ liệu
# Thứ tự này là thứ tự fallback: model đầu trả lời, hỏng/hết quota thì sang model sau.
# WorkBuddy chỉ còn serve DeepSeek V4.1 Flash ở region SG; bản thường và glm-5.3 đã bị
# bỏ khỏi danh sách provider nên không đưa vào đây (script cũng tự lọc theo thực tế).
MODELS=(
  workbuddy-ai/deepseek-v4.1-flash-sg            # WorkBuddy AI — Leader + Coder
  autoclaw/zai_glm-5.3-flash                     # AutoClaw — GLM-5.3 flash
  autoclaw/zaicoding_glm-5.3                     # AutoClaw — GLM-5.3 coding (quota free hay cạn)
  workbuddy-ai/glm-5.3-flash                     # WorkBuddy AI — GLM flash dự phòng
  workbuddy-ai/hy4free                           # WorkBuddy AI — đọc ảnh (rule images)
)

LEVELS=low,high,max                       # mức reasoning agent được chọn
CLASSIFIER=opencode-zen/jev-1.13-free     # model nhỏ đọc mỗi lượt khi effort=auto

# group/glm — Tester. Đúng 3 model GLM 1M, flash đứng đầu; không rule, không classifier.
GLM_MODELS=(
  autoclaw/zai_glm-5.3-flash
  autoclaw/zaicoding_glm-5.3
  workbuddy-ai/glm-5.3-flash
)

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH (~/.local/bin)"

# ------------------------------------------------------- model nào đang có
models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
groups_now="$(magpie groups 2>/dev/null || true)"
[ -n "$models_now" ] || die "magpie chưa có model nào — đăng nhập provider trước (bash scripts/login.sh)"

PRESENT=()
for m in "${MODELS[@]}"; do
  if printf '%s\n' "$models_now" | grep -Fxq "$m"; then PRESENT+=("$m"); fi
done

if [ ${#PRESENT[@]} -eq 0 ]; then
  die "không có model nào trong danh sách hiện có. Chạy: bash scripts/login.sh"
fi

say "model có sẵn: ${#PRESENT[@]}/${#MODELS[@]}"
for m in "${MODELS[@]}"; do
  printf '%s\n' "${PRESENT[@]}" | grep -Fxq "$m" \
    || warn "thiếu $m (provider chưa đăng nhập, hoặc model đã bị provider bỏ khỏi danh sách)"
done

in_present() { printf '%s\n' "${PRESENT[@]}" | grep -Fxq "$1"; }

# Group từng có trong định nghĩa nhưng nay đã bỏ. `group add` không xoá group thừa,
# nên phải dọn tay, nếu không máy sẽ lệch script sau mỗi lần đổi định nghĩa.
RETIRED_GROUPS=(deepseek)
for id in "${RETIRED_GROUPS[@]}"; do
  printf '%s\n' "$groups_now" | grep -q "group/$id" || continue
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
join() { local IFS=,; printf '%s' "$*"; }

create_group() { # <tên> <id> <stays>; trả 1 nếu bỏ qua (đã có, không --force)
  local name=$1 id=$2 stays=$3
  local list; list="$(join "${PRESENT[@]}")"

  if printf '%s\n' "$groups_now" | grep -q "group/$id"; then
    if [ "$FORCE" != 1 ]; then
      say "group/$id đã có — bỏ qua (dùng --force để tạo lại)"
      return 1
    fi
    say "thay group/$id"
  fi

  run magpie group add "$name" "models=$list" routing=order "stays=$stays" >/dev/null || return 1

  # levels + classifier + effort đi cùng một lệnh: magpie ghi file có độ trễ, tách
  # lệnh thì lệnh sau có thể chưa thấy classifier của lệnh trước.
  if [ "$DRY" = 1 ]; then
    run magpie group set "$id" "levels=$LEVELS" "classifier=$CLASSIFIER" effort=auto
  elif magpie group set "$id" "levels=$LEVELS" "classifier=$CLASSIFIER" effort=auto >/dev/null 2>&1; then
    ok "levels=$LEVELS · effort=auto · classifier=$CLASSIFIER"
  elif magpie group set "$id" "levels=$LEVELS" >/dev/null 2>&1; then
    warn "không đặt được classifier $CLASSIFIER (thiếu provider?) — giữ levels, effort để agent tự chọn"
  else
    warn "không đặt được levels cho group/$id"
  fi
}

add_rule() { # <id> <model[,model…]> <cờ…>
  local id=$1 model=$2; shift 2
  local first="${model%%,*}"
  if ! in_present "$first"; then
    warn "bỏ rule cho $id: $first không có trong group"
    return 0
  fi
  run magpie group rule add "$id" "use=$model" "$@" >/dev/null || warn "rule lỗi: $*"
}

# Group đơn giản: đúng danh sách model được truyền, không rule, không classifier.
make_simple() { # <tên> <id> <stays> <model…>
  local name=$1 id=$2 stays=$3; shift 3
  local list; list="$(join "$@")"

  if printf '%s\n' "$groups_now" | grep -q "group/$id"; then
    if [ "$FORCE" != 1 ]; then
      say "group/$id đã có — bỏ qua (dùng --force để tạo lại)"
      return 1
    fi
    # Xoá trước rồi tạo lại: nếu group đã được đổi tên hiển thị thì
    # `group add <tên cũ>` sẽ tạo group mới với id bị đánh số (code-2).
    say "thay group/$id"
    run magpie group rm "$id" >/dev/null || warn "không xoá được group/$id"
  fi

  run magpie group add "$name" "models=$list" routing=order "stays=$stays" >/dev/null || return 1
  if [ "$DRY" = 1 ]; then
    run magpie group set "$id" "levels=$LEVELS"
  elif magpie group set "$id" "levels=$LEVELS" >/dev/null 2>&1; then
    ok "levels=$LEVELS"
  else
    warn "không đặt được levels cho group/$id"
  fi
}

# Lọc một danh sách model theo những model thật sự có (không chỉ trong ladder).
present_of() {
  local m
  for m in "$@"; do
    printf '%s\n' "$models_now" | grep -Fxq "$m" && printf '%s\n' "$m"
  done
}

# Như present_of nhưng trả về một danh sách ngăn bằng dấu phẩy, cho use=a,b của rule.
use_present() {
  local m out=()
  for m in "$@"; do in_present "$m" && out+=("$m"); done
  [ ${#out[@]} -gt 0 ] || return 1
  join "${out[@]}"
}

# ------------------------------------------------------------- group/main
# Chat thường ngày: giữ hội thoại trên một account (session) để prompt cache còn giá trị.
say ""
say "group/main — chat thường ngày, stays=session"
if create_group "Main" main session; then
  add_rule main workbuddy-ai/hy4free images                  # ảnh → model đọc được ảnh
  add_rule main workbuddy-ai/hy4free compact                 # nén hội thoại → model free 1M
fi

# ------------------------------------------------------------- group/code
# Việc code: đổi model theo từng lượt (turn) vì mỗi bước cần model khác nhau.
# Leader và Coder cùng dùng group này.
say ""
say "group/code — Leader + Coder, stays=turn, 6 rule"
if create_group "Code" code turn; then
  add_rule code workbuddy-ai/hy4free compact
  add_rule code workbuddy-ai/deepseek-v4.1-flash-sg \
    intent="asking for a detailed plan before any code is written (lên plan, lập kế hoạch chi tiết)"
  add_rule code workbuddy-ai/deepseek-v4.1-flash-sg \
    intent="writing, implementing or fixing code (viết code, code theo plan, implement, sửa code)"
  if test_use="$(use_present autoclaw/zai_glm-5.3-flash autoclaw/zaicoding_glm-5.3 workbuddy-ai/glm-5.3-flash)"; then
    add_rule code "$test_use" \
      intent="running tests or checking the code just written, before it is finished (kiểm tra, test code vừa viết)"
  else
    warn "bỏ rule test của code: không có model GLM nào"
  fi
  add_rule code workbuddy-ai/deepseek-v4.1-flash-sg \
    intent="final overall review of the finished code and releasing or publishing it (kiểm tra tổng thể lần cuối, duyệt, phát hành, release, ship)"
  add_rule code workbuddy-ai/hy4free images
fi

# ------------------------------------------------------------- group/glm
# Tester dùng group riêng thay vì dựa vào rule intent của group/code: classifier
# có thể đoán sai, còn group riêng thì luôn bắt đầu bằng zaicoding_glm.
say ""
say "group/glm — Tester, GLM 5.3 đứng đầu, stays=auto"
glm_present=(); while IFS= read -r m; do [ -n "$m" ] && glm_present+=("$m"); done \
  < <(present_of "${GLM_MODELS[@]}")
if [ ${#glm_present[@]} -eq 0 ]; then
  warn "không có model GLM nào — bỏ qua group/glm"
elif make_simple "GLM" glm auto "${glm_present[@]}"; then
  ok "group/glm: ${#glm_present[@]} model"
fi

say ""
if [ "$DRY" = 1 ]; then
  say "dry-run: không thay đổi gì."
else
  ok "xong. Xem lại: magpie groups · magpie group main · magpie group glm"
fi
