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

# タスクが存在しない場合のみタスクを追加。
# find-by-branchの終了コードで「見つからなかった(2)」と「呼び出し自体の失敗」を
# 区別する。区別しないと、gh認証切れ等の一時的な障害時にも「issueなし」と
# 誤判定して重複issueを作成してしまうため。
if find-by-branch >/dev/null 2>&1; then
  exit
fi
find_rc=$?
if [ "$find_rc" -ne 2 ]; then
  echo "既存issueの確認に失敗しました（終了コード: ${find_rc}）。gh認証状態などを確認してください" >&2
  exit "$find_rc"
fi

issue_url=$(gh issue create --repo "${CLAUDE_TASKS_OWNER}/${CLAUDE_TASKS_REPO}" \
  --title "${repo_name}: ${branch}" \
  --body "")
issue_number=$(basename "$issue_url")
echo "$issue_number"
