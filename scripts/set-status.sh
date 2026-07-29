#!/usr/bin/env bash
set -euo pipefail

# Role: update the TaskStatus of the issue corresponding to the current branch
# Usage: set-status.sh "<TaskStatus value>"
#   The issue number is auto-resolved via find-by-branch.sh.
#   field-id/option-id are not hardcoded; they're resolved dynamically on every
#   run via gh project field-list (so this stays in sync even if the TaskStatus
#   options are edited directly in the GitHub UI).

status="${1:?Usage: set-status.sh \"<TaskStatus value>\"}"

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

issue_number=$("$SCRIPT_DIR/scripts/find-by-branch.sh")

project_id=$(gh project view "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json --jq '.id')

field_json=$(gh project field-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
  | jq -c '.fields[] | select(.name=="TaskStatus")')

if [ -z "$field_json" ]; then
  echo "TaskStatus field not found. Check whether setup-project.sh has been run" >&2
  exit 1
fi

field_id=$(echo "$field_json" | jq -r '.id')
option_id=$(echo "$field_json" | jq -r --arg s "$status" '.options[] | select(.name==$s) | .id')

if [ -z "$option_id" ]; then
  echo "TaskStatus '${status}' does not exist. Available values:" >&2
  echo "$field_json" | jq -r '.options[].name' >&2
  exit 1
fi

item_id=$(gh project item-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
  | jq -r --argjson n "$issue_number" '.items[] | select(.content.number == $n) | .id')

if [ -z "$item_id" ]; then
  echo "No project item found for issue #${issue_number}" >&2
  exit 1
fi

gh project item-edit --id "$item_id" --field-id "$field_id" --project-id "$project_id" \
  --single-select-option-id "$option_id" >/dev/null

echo "Updated TaskStatus of issue #${issue_number} to '${status}'"
