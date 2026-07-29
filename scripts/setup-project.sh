#!/usr/bin/env bash
set -euo pipefail

# Role: initial setup for the claude-tasks GitHub Project (create the Project, create the TaskStatus field)
# Usage: setup-project.sh <owner> [project title]
#
# Creating the TaskStatus field itself is delegated to update-status.sh.
# To add, remove, or change TaskStatus options, edit the STATUS_OPTIONS array
# in update-status.sh and re-run it directly (no need to recreate the Project).

owner="${1:?Usage: setup-project.sh <owner> [project title]}"
title="${2:-claude-tasks}"

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="$SCRIPT_DIR/.env"

create_project() {
	local project_url
	echo "Creating Project..."
	project_url=$(gh project create --owner "$owner" --title "$title" --format json --jq '.url')
	project_number=$(basename "$project_url")
	echo "Created Project #${project_number}."
}

echo "Checking whether the Project already exists"
project_list_json=$(gh project list --owner "$owner" --format json)
existing_number=$(jq -r --arg title "$title" '.projects[] | select(.title == $title) | .number' <<<"$project_list_json")

if [[ -n "$existing_number" ]]; then
	echo "A Project named ${title} already exists (#${existing_number})."
	echo "Link it to the current repository? Y/n"
	read -r answer
	if [[ "$answer" == "Y" ]]; then
		project_number="$existing_number"
	else
		create_project
	fi
else
	create_project
fi

if [ -f "$ENV_FILE" ] && grep -q '^CLAUDE_TASKS_PROJECT_NUMBER=' "$ENV_FILE"; then
	sed -i "s/^CLAUDE_TASKS_PROJECT_NUMBER=.*/CLAUDE_TASKS_PROJECT_NUMBER=${project_number}/" "$ENV_FILE"
else
	echo "CLAUDE_TASKS_PROJECT_NUMBER=${project_number}" >>"$ENV_FILE"
fi
echo "Wrote CLAUDE_TASKS_PROJECT_NUMBER=${project_number} to .env."

"$SCRIPT_DIR/scripts/update-status.sh"

cat <<'EOF'

The remaining setup requires manual configuration in the GitHub UI (built-in workflows).
From the "..." menu in the top right of the Project screen, go to Workflows and set up the following:

  1. Enable "Item added to project" and set its Set value to "TaskStatus: Discussion"
  2. Enable "Item closed" and set its Set value to "TaskStatus: Done"

(Whether the built-in workflow lets you target the custom TaskStatus field needs to be
verified in the GitHub UI. If it doesn't, the setting will remain targeted at the default
Status field instead — see README.md for the fallback procedure in that case.)

See the "About built-in workflows" section of README.md for details.
EOF
