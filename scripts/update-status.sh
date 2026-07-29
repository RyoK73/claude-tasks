#!/usr/bin/env bash
set -euo pipefail

# Role: recreate the TaskStatus field on an existing Project (to reflect added/removed/changed options)
# Usage: update-status.sh
#
# The default "Status" field (Todo/In Progress/Done) that GitHub auto-generates
# when a Project is created cannot be deleted, so claude-tasks creates a
# separate custom field named "TaskStatus" instead.
#
# To add, remove, or change options, edit the STATUS_OPTIONS array below and
# re-run this script. The Project itself is not recreated; only the existing
# TaskStatus field is deleted and recreated.
#
# Note: deleting the field also loses the current TaskStatus value of every
# item tied to it (values are not automatically carried over).
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

echo "This will recreate the TaskStatus field. The TaskStatus value currently set on every item will be lost."
read -r -p "Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
	echo "Aborted."
	exit 1
fi

status_csv=$(
	IFS=,
	echo "${STATUS_OPTIONS[*]}"
)

echo "Checking for an existing TaskStatus field..."
existing_field_id=$(gh project field-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
	--jq '.fields[] | select(.name=="TaskStatus") | .id')

if [ -n "$existing_field_id" ]; then
	echo "Deleting existing TaskStatus field..."
	gh project field-delete --id "$existing_field_id" >/dev/null
fi

echo "Creating TaskStatus field..."
create_success=true
gh project field-create "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" \
	--name "TaskStatus" \
	--data-type SINGLE_SELECT \
	--single-select-options "$status_csv" \
	>/dev/null || create_success=false

if [[ "$create_success" == false ]]; then
	echo "Failed to create TaskStatus field. The field remains deleted. Re-run update-status.sh" >&2
	exit 1
fi

echo "TaskStatus field has been recreated."
