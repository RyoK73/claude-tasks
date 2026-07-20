#!/usr/bin/env bash
set -euo pipefail

# 役割: claude-tasks用GitHub Projectの初回セットアップ（Status用フィールド作成）
# 使い方: setup-project.sh <owner> [project title]
#
# Statusの選択肢を追加・削除・変更したい場合は、下のSTATUS_OPTIONS配列を編集して
# 再実行すればよい（既存のStatusフィールドはスクリプト内で自動削除してから
# 作り直すため、手動での削除は不要）。
STATUS_OPTIONS=(
  "Discussion"
  "Plan Review"
  "In Progress"
  "Commit Review"
  "In Fix"
  "PR Review"
  "Done"
)

owner="${1:?使い方: setup-project.sh <owner> [project title]}"
title="${2:-claude-tasks}"

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="$SCRIPT_DIR/.env"

echo "Project作成中..."
project_url=$(gh project create --owner "$owner" --title "$title" --format json --jq '.url')
project_number=$(basename "$project_url")
echo "Project #${project_number} を作成したのだ"

echo "Statusフィールド作成中..."
status_csv=$(IFS=,; echo "${STATUS_OPTIONS[*]}")

# gh project createで新規作成した直後は、GitHubがデフォルトで
# Todo/In Progress/Doneの3択を持つ"Status"フィールドを自動生成する。
# field-createは同名フィールドの上書きができないため、既存のものを
# 一度削除してから独自の選択肢で作り直す。
default_status_id=$(gh project field-list "$project_number" --owner "$owner" --format json \
  --jq '.fields[] | select(.name=="Status") | .id')
if [ -n "$default_status_id" ]; then
  gh project field-delete --id "$default_status_id" >/dev/null
fi

gh project field-create "$project_number" --owner "$owner" \
  --name "Status" \
  --data-type SINGLE_SELECT \
  --single-select-options "$status_csv" \
  >/dev/null

if [ -f "$ENV_FILE" ] && grep -q '^CLAUDE_TASKS_PROJECT_NUMBER=' "$ENV_FILE"; then
  sed -i "s/^CLAUDE_TASKS_PROJECT_NUMBER=.*/CLAUDE_TASKS_PROJECT_NUMBER=${project_number}/" "$ENV_FILE"
else
  echo "CLAUDE_TASKS_PROJECT_NUMBER=${project_number}" >> "$ENV_FILE"
fi
echo ".env に CLAUDE_TASKS_PROJECT_NUMBER=${project_number} を書き込んだのだ"

cat <<'EOF'

残りはGitHub UI上での手動設定が必要なのだ（built-inワークフロー）。
Projectの画面右上の "..." > Workflows から以下を設定するのだ:

  1. "Item added to project" を有効化し、Set status を "Discussion" に設定
  2. "Item closed" を有効化し、Set status を "Done" に設定

詳細はREADME.mdの「built-inワークフローについて」を参照するのだ。
EOF
