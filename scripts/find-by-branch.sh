#!/usr/bin/env bash
set -euo pipefail

# Role: reverse-lookup the management issue for the current repository/branch name and return the issue number
# Usage: find-by-branch.sh
#   Assumes titles follow the "<repo name>: <branch name>" format, and searches
#   for an issue whose title exactly matches "<repo name>: <branch name>"
#   (we don't do a partial match on branch name alone, since that could
#   incorrectly match a same-named branch in a different repository)
#
# Exit codes:
#   0 = a matching issue was found
#   2 = no matching issue was found (normal case; callers may treat only this
#       as "issue not yet created")
#   anything else = the gh call itself failed (expired auth, API failure, missing
#       .env, etc.). set -euo pipefail causes the script to exit with this code
#       automatically. Callers must not confuse this with "issue not yet created".

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

repo_name=$(gh repo view --json name --jq '.name')
branch=$(git branch --show-current)
title="${repo_name}: ${branch}"

issue_number=$(gh issue list --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
	--state open \
	--search "in:title \"${branch}\"" \
	--json number,title |
	jq -r --arg t "$title" '[.[] | select(.title == $t)][0].number // empty')

if [ -z "$issue_number" ]; then
	echo "No issue found matching branch '${branch}'" >&2
	exit 2
fi

echo "$issue_number"
