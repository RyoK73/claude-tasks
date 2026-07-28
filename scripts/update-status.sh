#!/usr/bin/env bash
set -euo pipefail

# 役割: 既存Projectに対してTaskStatusフィールドを作り直す（選択肢の追加・削除・変更を反映する）
# 使い方: update-status.sh
#
# GitHub Projectの新規作成時に自動生成されるデフォルトの"Status"フィールド
# （Todo/In Progress/Done）は削除できない仕様のため、claude-tasksでは
# "TaskStatus"という別名のカスタムフィールドを作成して使用する。
#
# 選択肢を追加・削除・変更したい場合は、下のSTATUS_OPTIONS配列を編集して
# このスクリプトを再実行する。Projectそのものは作り直さず、既存の
# TaskStatusフィールドのみを削除してから作り直す。
#
# 注意: フィールドを削除すると、そのフィールドに紐づく全itemの現在の
# TaskStatus値も失われる（値の自動引き継ぎは行わない）。
STATUS_OPTIONS=(
	"Discussion"
	"Plan Review"
	"In Progress"
	"Commit Review"
	"In Fix"
	"PR Review"
	"Done"
)

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

echo "TaskStatusフィールドを作り直します。既存の全itemに設定されているTaskStatus値は失われます。"
read -r -p "続行しますか？ (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
	echo "中止しました。"
	exit 1
fi

status_csv=$(
	IFS=,
	echo "${STATUS_OPTIONS[*]}"
)

echo "既存のTaskStatusフィールドを確認中..."
existing_field_id=$(gh project field-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
	--jq '.fields[] | select(.name=="TaskStatus") | .id')

if [ -n "$existing_field_id" ]; then
	echo "既存のTaskStatusフィールドを削除中..."
	gh project field-delete --id "$existing_field_id" >/dev/null
fi

echo "TaskStatusフィールドを作成中..."
gh project field-create "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" \
	--name "TaskStatus" \
	--data-type SINGLE_SELECT \
	--single-select-options "$status_csv" \
	>/dev/null

echo "TaskStatusフィールドを作り直しました。"
