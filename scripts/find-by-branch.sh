#!/usr/bin/env bash
set -euo pipefail

# 役割: 現在のリポジトリ・ブランチ名から対応する管理用issueを逆引きし、issue番号を返す
# 使い方: find-by-branch.sh
#   タイトルが "<repo名>: <ブランチ名>" 形式であることを前提に、
#   タイトルが "<repo名>: <ブランチ名>" と完全一致するissueを検索する
#   （ブランチ名のみでの部分一致は、別リポジトリの同名ブランチに誤って
#   マッチする可能性があるため使わない）

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"

repo_name=$(gh repo view --json name --jq '.name')
branch=$(git branch --show-current)
title="${repo_name}: ${branch}"

issue_number=$(gh issue list --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
  --state open \
  --search "in:title \"${branch}\"" \
  --json number,title \
  | jq -r --arg t "$title" '[.[] | select(.title == $t)][0].number // empty')

if [ -z "$issue_number" ]; then
  echo "ブランチ '${branch}' に対応するissueが見つかりませんでした" >&2
  exit 1
fi

echo "$issue_number"
