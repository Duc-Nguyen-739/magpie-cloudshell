#!/usr/bin/env bash
# setup-groups.sh — tạo bốn routing group đang dùng: main, code, glm, deepseek.
#
#   bash scripts/setup-groups.sh            tạo group còn thiếu, bỏ qua group đã có
#   bash scripts/setup-groups.sh --force    tạo lại (thay) cả bốn group
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
MODELS=(
  workbuddy-ai/deepseek-v4.1-flash               # WorkBuddy AI — Leader + Coder
  workbuddy-ai/deepseek-v4.1-flash-sg            # WorkBuddy AI — cùng model, region SG
  autoclaw/zaicoding_glm-5.3                     # AutoClaw — Tester, GLM ưu tiên số 1
  autoclaw/zai_glm-5.3-flash                     # AutoClaw — GLM-5.3 flash
  workbuddy-ai/glm-5.3                           # WorkBuddy AI — GLM dự phòng
  workbuddy-ai/glm-5.3-flash                     # WorkBuddy AI — GLM flash dự phòng
  opencode-zen-free/deepseek-v4.1-flash-free     # OpenCode Zen Free — DeepSeek free
  opencode-zen-free/glm-5.3-flash-free           # OpenCode Zen Free — GLM free
)

LEVELS=low,high,max                       # mức reasoning agent được chọn
CLASSIFIER=workbuddy-ai/hy3              # model nhỏ đọc mỗi lượt khi effort=auto (free, không tốn credit)

# group/glm — Tester. Chỉ GLM, zaicoding đứng đầu; không rule, không classifier.
GLM_MODELS=(
  autoclaw/zaicoding_glm-5.3
  autoclaw/zai_glm-5.3-flash
  autoclaw/zai_auto-fast
  autoclaw/zai_auto
  workbuddy-ai/glm-5.3
  workbuddy-ai/glm-5.3-flash
  opencode-zen-free/glm-5.3-flash-free
)

# group/deepseek — dự phòng, chỉ endpoint DeepSeek, không bao giờ rơi sang GLM.
DEEPSEEK_MODELS=(
  workbuddy-ai/deepseek-v4.1-flash
  workbuddy-ai/deepseek-v4.1-flash-sg
  opencode-zen-free/deepseek-v4.1-flash-free
)

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH (~/.local/bin)"

# ------------------------------------------------------- model nào đang có
models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
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
  printf '%s\n' "${PRESENT[@]}" | grep -Fxq "$m" || warn "thiếu $m (provider chưa đăng nhập?)"
done

in_present() { printf '%s\n' "${PRESENT[@]}" | grep -Fxq "$1"; }

# --------------------------------------------------------------- tạo group
join() { local IFS=,; printf '%s' "$*"; }

create_group() { # <tên> <id> <stays>; trả 1 nếu bỏ qua (đã có, không --force)
  local name=$1 id=$2 stays=$3
  local list; list="$(join "${PRESENT[@]}")"

  if magpie groups 2>/dev/null | grep -q "group/$id"; then
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

add_rule() { # <id> <model> <cờ…>
  local id=$1 model=$2; shift 2
  if ! in_present "$model"; then
    warn "bỏ rule cho $id: $model không có trong group"
    return 0
  fi
  run magpie group rule add "$id" "use=$model" "$@" >/dev/null || warn "rule lỗi: $*"
}

# Group đơn giản: đúng danh sách model được truyền, không rule, không classifier.
make_simple() { # <tên> <id> <stays> <model…>
  local name=$1 id=$2 stays=$3; shift 3
  local list; list="$(join "$@")"

  if magpie groups 2>/dev/null | grep -q "group/$id"; then
    if [ "$FORCE" != 1 ]; then
      say "group/$id đã có — bỏ qua (dùng --force để tạo lại)"
      return 1
    fi
    # Xoá trước rồi tạo lại: nếu group đã được đổi tên hiển thị thì
    # `group add <tên cũ>` sẽ tạo group mới với id bị đánh số (deepseek-2).
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

# ------------------------------------------------------------- group/main
# Chat thường ngày: giữ hội thoại trên một account (session) để prompt cache còn giá trị.
say ""
say "group/main — chat thường ngày, stays=session"
if create_group "Main" main session; then
  add_rule main workbuddy-ai/deepseek-v4.1-flash images      # ảnh → model mạnh nhất
  add_rule main workbuddy-ai/glm-5.3-flash compact           # nén hội thoại → model rẻ
fi

# ------------------------------------------------------------- group/code
# Việc code: đổi model theo từng lượt (turn) vì mỗi bước cần model khác nhau.
say ""
say "group/code — công việc code, stays=turn, 4 rule theo ý định"
if create_group "Code" code turn; then
  add_rule code workbuddy-ai/deepseek-v4.1-flash \
    intent="asking for a detailed plan before any code is written (lên plan, lập kế hoạch chi tiết)"
  add_rule code workbuddy-ai/deepseek-v4.1-flash \
    intent="writing, implementing or fixing code (viết code, code theo plan, implement, sửa code)"
  add_rule code autoclaw/zaicoding_glm-5.3 \
    intent="running tests or checking the code just written, before it is finished (kiểm tra, test code vừa viết)"
  add_rule code workbuddy-ai/deepseek-v4.1-flash \
    intent="final overall review of the finished code and releasing or publishing it (kiểm tra tổng thể lần cuối, duyệt, phát hành, release, ship)"
  add_rule code workbuddy-ai/deepseek-v4.1-flash images
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

# --------------------------------------------------------- group/deepseek
# Dự phòng: chỉ endpoint DeepSeek, để ép một phiên không rơi sang GLM.
say ""
say "group/deepseek — dự phòng, chỉ DeepSeek"
ds_present=(); while IFS= read -r m; do [ -n "$m" ] && ds_present+=("$m"); done \
  < <(present_of "${DEEPSEEK_MODELS[@]}")
if [ ${#ds_present[@]} -eq 0 ]; then
  warn "không có model DeepSeek nào — bỏ qua group/deepseek"
elif make_simple "deepseek" deepseek turn "${ds_present[@]}"; then
  run magpie group set deepseek name="DeepSeek V4.1 Flash" >/dev/null
  ok "group/deepseek: ${#ds_present[@]} model"
fi

say ""
if [ "$DRY" = 1 ]; then
  say "dry-run: không thay đổi gì."
else
  ok "xong. Xem lại: magpie groups · magpie group main · magpie group glm"
fi
