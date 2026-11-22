#!/usr/bin/env bash
# finish.sh — bước cuối sau khi đã đăng nhập provider:
# cấu hình magpie, giá/context/output/efforts theo model, tạo group còn thiếu,
# trỏ agent vào group/leader, rồi kiểm tra. MCP do scripts/setup-opencode.sh gọi
# scripts/setup-mcp.sh khi cài.
#
#   bash scripts/finish.sh
#
# Chạy lại bất cứ lúc nào: group được tạo lại theo đúng định nghĩa trong
# scripts/setup-groups.sh (nên đừng sửa tay group nếu bạn còn chạy lệnh này).
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf '\n\033[1m1/5 · cấu hình magpie (settings, trạng thái provider)\033[0m\n'
bash "$REPO_DIR/scripts/setup-settings.sh"

printf '\n\033[1m2/5 · cài đặt theo model + provider FreePi (giá, context/output, queue)\033[0m\n'
bash "$REPO_DIR/scripts/setup-model-settings.sh"

printf '\n\033[1m3/5 · routing group (chỉ tạo group còn thiếu)\033[0m\n'
# Không dùng --force: model trong group do người dùng tự chọn; finish.sh chỉ
# tạo group còn thiếu, không reset ladder đã sửa.
bash "$REPO_DIR/scripts/setup-groups.sh"

printf '\n\033[1m4/5 · agent\033[0m\n'
bash "$REPO_DIR/scripts/setup-agents.sh"

printf '\n\033[1m5/5 · kiểm tra\033[0m\n'
bash "$REPO_DIR/scripts/doctor.sh"
