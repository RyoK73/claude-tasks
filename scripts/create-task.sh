#!/usr/bin/env bash
set -euo pipefail

# Role: create a management issue for the current repository/branch and return the issue number
# Usage: create-task.sh
#   (auto-detects the repo name and current branch name from the working directory)

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

repo_name=$(gh repo view --json name --jq '.name')
branch=$(git branch --show-current)

# Only add a task if one doesn't already exist.
# We distinguish find-by-branch's exit codes for "not found (2)" vs. "the call itself
# failed". Without this distinction, transient failures (e.g. expired gh auth) would
# be misread as "no issue" and cause a duplicate issue to be created.

find_rc=0
find-by-branch >/dev/null 2>&1 || find_rc=$?

case "$find_rc" in
0)
	exit
	;;
2)
	;;
*)
	echo "Failed to check for an existing issue (exit code: ${find_rc}). Check your gh auth status, etc." >&2
	exit "$find_rc"
	;;
esac

issue_url=$(gh issue create --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
	--title "${repo_name}: ${branch}" \
	--body "")
issue_number=$(basename "$issue_url")
echo "$issue_number"
