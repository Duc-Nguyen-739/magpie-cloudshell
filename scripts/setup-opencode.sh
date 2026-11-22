#!/usr/bin/env bash
# setup-opencode.sh — thêm agent Leader + 6 subagent (review, reviewplan, coder,
# tester, tester2, tester3) vào OpenCode. Không cài skill: agent chỉ nạp skill của
# project đang làm, cộng hai skill môi trường opencode/report.
#
# Mặc định: chỉ cài file còn thiếu, không ghi đè file đã có.
#   --sync     cập nhật cả file đã có (backup, giữ dòng model cục bộ)
#   --no-mcp   không chạy setup-mcp.sh (dùng khi chỉ muốn đồng bộ agent)
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$HOME/.config/opencode"
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }

SYNC=0
NO_MCP=0
MANIFEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sync)   SYNC=1 ;;
    --no-mcp) NO_MCP=1 ;;
    --expected-manifest)
      shift
      MANIFEST="${1:-}"
      [ -n "$MANIFEST" ] || { warn "--expected-manifest cần đường dẫn"; exit 2; }
      ;;
    --expected-manifest=*) MANIFEST="${1#*=}" ;;
    -h|--help)
      say "dùng: bash scripts/setup-opencode.sh [--sync] [--no-mcp] [--expected-manifest FILE]"
      exit 0
      ;;
    *)
      warn "tham số không hỗ trợ: $1"
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$CONF/agents"
mkdir -p "$CONF/plugins"
install -m 644 "$REPO_DIR/config/plugins/leader-gate.js" "$CONF/plugins/leader-gate.js"
install -m 644 "$REPO_DIR/config/leader-gate.json" "$CONF/leader-gate.json"
ok "leader-gate plugin + config"


if [ "$SYNC" = 1 ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    warn "cần python3 để --sync"
    exit 1
  fi
  sync_args=(
    --source "$REPO_DIR/config/agents"
    --target "$CONF/agents"
    --apply
    --install-missing
  )
  [ -n "$MANIFEST" ] && sync_args+=(--expected-manifest "$MANIFEST")
  python3 "$REPO_DIR/scripts/sync-agents.py" "${sync_args[@]}" || exit $?
  ok "agent profiles đã đồng bộ (backup, nếu có, trong $CONF/agents/backups/)"
else
  if ! command -v magpie >/dev/null 2>&1; then
    warn "chưa có magpie trên PATH — chạy bash bootstrap.sh trước; bỏ qua bước này"
    exit 1
  fi
fi

models_now=""
groups_now=""
if command -v magpie >/dev/null 2>&1; then
  models_now="$(magpie models 2>/dev/null | awk '{print $1}')"
  groups_now="$(magpie groups 2>/dev/null || true)"
fi
has_model() { printf '%s\n' "$models_now" | grep -Fxq "$1"; }

install_agent() { # <tên>
  local name=$1 src="$REPO_DIR/config/agents/$1.md" dst="$CONF/agents/$1.md"
  if [ -f "$dst" ]; then
    warn "$dst đã có — không ghi đè"
    return 0
  fi
  cp "$src" "$dst"
  # Model riêng của agent; nếu máy chưa có group/model đó thì lùi về group/leader.
  local m mid
  m="$(sed -n 's/^model: *//p' "$dst" | head -1)"
  mid="${m#magpie/}"
  mid="${mid%%#*}"                 # bỏ #low/#high/#max trước khi kiểm tra
  if [ -z "$m" ] || [ -n "${m#magpie/}" ]; then
    ok "$dst"
    return 0
  fi
  if [ "${mid#group/}" != "$mid" ]; then
    local gid="${mid#group/}"
    if ! printf '%s\n' "$groups_now" | awk -v g="group/$gid" '{ for (i = 1; i <= NF; i++) if ($i == g) found = 1 } END { exit !found }'; then
      sed -i "s|^model: .*|model: magpie/group/leader|" "$dst"
      warn "$name: chưa có group/$gid, đã đổi sang magpie/group/leader"
    fi
  elif ! has_model "$mid"; then
    sed -i "s|^model: .*|model: magpie/group/leader|" "$dst"
    warn "$name: không có $mid, đã đổi sang magpie/group/leader"
  fi
  ok "$dst"
}

if [ "$SYNC" = 0 ]; then
  install_agent leader
  install_agent review
  install_agent reviewplan
  install_agent coder
  install_agent tester
  install_agent tester2
  install_agent tester3
fi

# Skill: repo này không cài skill vào OpenCode. Thư viện magpie (13 skill) do
# `magpie library` quản lý và hand over thành symlink trong ~/.config/opencode/skills;
# agent không nạp chúng (xem docs/opencode.md).

# --------------------------------------------------------------- MCP servers
if [ "$NO_MCP" = 0 ] && [ -x "$REPO_DIR/scripts/setup-mcp.sh" ]; then
  if command -v magpie >/dev/null 2>&1; then
    bash "$REPO_DIR/scripts/setup-mcp.sh" || warn "setup-mcp.sh lỗi — bỏ qua"
  else
    warn "không có magpie — bỏ qua setup-mcp.sh"
  fi
fi

say ""
say "Provider magpie trong opencode.jsonc do chính magpie ghi khi bạn chạy"
say "'magpie opencode group/leader' — không cần sửa tay. Xem docs/opencode.md."
