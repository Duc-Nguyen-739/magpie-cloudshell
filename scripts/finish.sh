#!/usr/bin/env bash
# finish.sh — bước cuối sau khi đã đăng nhập provider:
# cấu hình magpie, tạo/cập nhật group, trỏ agent vào group/main, rồi kiểm tra.
#
#   bash scripts/finish.sh
#
# Chạy lại bất cứ lúc nào: group được tạo lại theo đúng định nghĩa trong
# scripts/setup-groups.sh (nên đừng sửa tay group nếu bạn còn chạy lệnh này).
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf '\n\033[1m1/4 · cấu hình magpie (settings, provider tắt)\033[0m\n'
bash "$REPO_DIR/scripts/setup-settings.sh"

printf '\n\033[1m2/4 · routing group\033[0m\n'
bash "$REPO_DIR/scripts/setup-groups.sh" --force

printf '\n\033[1m3/4 · agent\033[0m\n'
bash "$REPO_DIR/scripts/setup-agents.sh"

printf '\n\033[1m4/4 · kiểm tra\033[0m\n'
bash "$REPO_DIR/scripts/doctor.sh"
