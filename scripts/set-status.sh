#!/usr/bin/env bash
set -euo pipefail

# 役割: 現在のブランチに対応するissueのTaskStatusを更新する
# 使い方: set-status.sh "<TaskStatus値>"
#   issue番号はfind-by-branch.shで自動解決する。
#   field-id/option-idはハードコードせず、実行の都度gh project field-listで
#   動的に解決する（GitHub UI側でTaskStatus選択肢を変更してもズレない構造にするため）。

status="${1:?使い方: set-status.sh \"<TaskStatus値>\"}"

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

issue_number=$("$SCRIPT_DIR/scripts/find-by-branch.sh")

project_id=$(gh project view "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json --jq '.id')

field_json=$(gh project field-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
  | jq -c '.fields[] | select(.name=="TaskStatus")')

if [ -z "$field_json" ]; then
  echo "TaskStatusフィールドが見つかりませんでした。setup-project.shを実行済みか確認してください" >&2
  exit 1
fi

field_id=$(echo "$field_json" | jq -r '.id')
option_id=$(echo "$field_json" | jq -r --arg s "$status" '.options[] | select(.name==$s) | .id')

if [ -z "$option_id" ]; then
  echo "TaskStatus '${status}' は存在しません。選択可能な値:" >&2
  echo "$field_json" | jq -r '.options[].name' >&2
  exit 1
fi

item_id=$(gh project item-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
  | jq -r --argjson n "$issue_number" '.items[] | select(.content.number == $n) | .id')

if [ -z "$item_id" ]; then
  echo "issue #${issue_number} に対応するproject itemが見つかりませんでした" >&2
  exit 1
fi

gh project item-edit --id "$item_id" --field-id "$field_id" --project-id "$project_id" \
  --single-select-option-id "$option_id" >/dev/null

echo "issue #${issue_number} のTaskStatusを '${status}' に更新しました"
