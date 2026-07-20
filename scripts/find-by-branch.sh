#!/usr/bin/env bash
set -euo pipefail

# 役割: 現在のブランチ名から対応する管理用issueを逆引きし、issue番号を返す
# 使い方: find-by-branch.sh
#   タイトルが "<repo名>: <ブランチ名>" 形式であることを前提に、
#   ": <ブランチ名>" で終わるissueを検索する

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

branch=$(git branch --show-current)

issue_number=$(gh issue list --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
  --state open \
  --search "in:title \"${branch}\"" \
  --json number,title \
  | jq -r --arg b "$branch" '[.[] | select(.title | endswith(": " + $b))][0].number // empty')

if [ -z "$issue_number" ]; then
  echo "ブランチ '${branch}' に対応するissueが見つからなかったのだ" >&2
  exit 1
fi

echo "$issue_number"
