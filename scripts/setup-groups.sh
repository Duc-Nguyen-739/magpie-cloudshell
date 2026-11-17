#!/usr/bin/env bash
# setup-groups.sh — tạo bảy routing group đang dùng: main, leader, coder,
# tester, tester-2, tester-3, free.
#
#   bash scripts/setup-groups.sh            tạo group còn thiếu, bỏ qua group đã có
#   bash scripts/setup-groups.sh --force    tạo lại (thay) cả bảy group
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
  if [ "$DRY" = 1 ]; then printf '  \033[2m[dry-run]\033[0m %s\n' "$*" >&2; else "$@"; fi
}

command -v magpie >/dev/null 2>&1 || die "chưa có magpie trên PATH (~/.local/bin)"

CLASSIFIER=opencode-zen/jev-1.13-free
LEVELS_FULL=low,high,max
LEVELS_HIGH=high

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

make_plain_group() { # <tên> <id> <model…> — không levels, không classifier
  local name=$1 id=$2; shift 2
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
    if [ "$(group_name_now "$id")" != "$name" ]; then
      say "thay group/$id (tên cũ khác)"
      run magpie group rm "$id" >/dev/null 2>&1 || warn "không xoá được group/$id"
    else
      say "thay group/$id"
    fi
  fi

  local list; list="$(join "${present[@]}")"
  run magpie group add "$name" "models=$list" routing=order >/dev/null \
    || { warn "không tạo được group/$id"; return 1; }
  ok "group/$id: ${#present[@]} model · không levels, không classifier"
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

# leader — OpenChamber: lên plan và điều phối; hai model Xingchi trước, Opus và
# DeepSeek SG dự phòng.
LEADER_MODELS=(
  xingchi/gpt-6-astra
  xingchi/gpt-6.1-sol
  agy-cli/claude-opus-4-6-thinking
  workbuddy-ai/deepseek-v4.1-flash-sg
)

# coder — viết code theo plan.
CODER_MODELS=(
  freepi/deepseek-v4.1-flash:high
)

# tester — kiểm tra và chạy test.
TESTER_MODELS=(
  freepi/deepseek-v4.1-flash:high
  agnes/agnes-3.0-flash:high
  workbuddy-ai/glm-5.3-flash
)

# tester-2 — tester độc lập, chạy song song với tester.
TESTER2_MODELS=(
  workbuddy-ai/hy4flash-free:high
  agnes/agnes-3.0-flash:high
  agy-cli/gemini-3.8-flash:high
  autoclaw/zai_glm-5.3-flash
)

# tester-3 — tester thứ ba, soi hợp đồng dữ liệu và regression ngoài phạm vi.
TESTER3_MODELS=(
  autoclaw/zai_glm-5.3-flash
  agy-cli/gemini-3.8-flash
  kilo/reflection/beam-free:high
  workbuddy-ai/hy4flash-free:high
)

# free — chỉ cho việc nén của billion-context: mỗi provider một model free nhanh
# nhất, không levels, không classifier, không stays. Xem docs/billion-context.md.
FREE_MODELS=(
  cline/cline-free/solar-mini4
  kilo/baidu/ernie-5.5-flash-preview:free
  kiro/claude-haiku-4.5
  openrouter/openrouter/free
  workbuddy-ai/hy4flash-free
)

# Group từng có trong định nghĩa nhưng nay đã bỏ. `group add` không xoá group thừa,
# nên phải dọn tay, nếu không máy sẽ lệch script sau mỗi lần đổi định nghĩa.
RETIRED_GROUPS=(code glm deepseek)
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
say "group/coder — viết code, stays=turn"
make_group "Coder" coder turn "$LEVELS_FULL" "${CODER_MODELS[@]}"

say ""
say "group/tester — kiểm tra, stays=turn"
make_group "Tester" tester turn "$LEVELS_HIGH" "${TESTER_MODELS[@]}"

say ""
say "group/tester-2 — tester độc lập, stays=turn"
make_group "Tester 2" tester-2 turn "$LEVELS_HIGH" "${TESTER2_MODELS[@]}"

say ""
say "group/tester-3 — tester thứ ba, stays=turn"
make_group "Tester 3" tester-3 turn "$LEVELS_HIGH" "${TESTER3_MODELS[@]}"

say ""
say "group/main — chat thường ngày, stays=session"
make_group "Main" main session "$LEVELS_FULL" "${MAIN_MODELS[@]}"

say ""
say "group/free — chỉ cho việc nén của billion-context"
make_plain_group "free" free "${FREE_MODELS[@]}"

say ""
if [ "$DRY" = 1 ]; then
  say "dry-run: không thay đổi gì."
else
  ok "xong. Xem lại: magpie groups"
fi
