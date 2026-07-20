#!/usr/bin/env bash
set -euo pipefail

# 役割: 現在のリポジトリ・ブランチから管理用issueを作成し、issue番号を返す
# 使い方: create-task.sh
#   （実行ディレクトリのrepo名・現在のブランチ名を自動検知する）

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

repo_name=$(gh repo view --json name --jq '.name')
branch=$(git branch --show-current)

issue_url=$(gh issue create --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
  --title "${repo_name}: ${branch}" \
  --body "")
issue_number=$(basename "$issue_url")
echo "$issue_number"
