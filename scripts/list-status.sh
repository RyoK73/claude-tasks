#!/usr/bin/env bash
set -euo pipefail

# Role: list open issues across all repos, along with their TaskStatus
# Usage: list-status.sh

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

{
  printf '%s\t%s\t%s\n' "ISSUE" "STATUS" "TITLE"
  gh project item-list "$CLAUDE_TASKS_PROJECT_NUMBER" --owner "$CLAUDE_TASKS_OWNER" --format json \
    | jq -r '.items[] | select(.content.number != null) | [("#" + (.content.number|tostring)), (.taskStatus // "-"), .content.title] | @tsv'
} | column -t -s "$(printf '\t')"
