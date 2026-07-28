#!/usr/bin/env bash
set -euo pipefail

# 役割: claude-tasks用GitHub Projectの初回セットアップ（Project作成・TaskStatusフィールド作成）
# 使い方: setup-project.sh <owner> [project title]
#
# TaskStatusフィールドの作成自体はupdate-status.shに委譲する。
# TaskStatusの選択肢を追加・削除・変更したい場合は、update-status.sh内の
# STATUS_OPTIONS配列を編集してupdate-status.shを直接再実行すればよい
# （Projectを作り直す必要はない）。

owner="${1:?使い方: setup-project.sh <owner> [project title]}"
title="${2:-claude-tasks}"

SCRIPT_DIR="${CLAUDE_TASKS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="$SCRIPT_DIR/.env"

create_project() {
	local project_url
	echo "Project作成中..."
	project_url=$(gh project create --owner "$owner" --title "$title" --format json --jq '.url')
	project_number=$(basename "$project_url")
	echo "Project #${project_number} を作成しました。"
}

echo "Projectの有無を確認します"
project_list_json=$(gh project list --owner "$owner" --format json)
existing_number=$(jq -r --arg title "$title" '.projects[] | select(.title == $title) | .number' <<<"$project_list_json")

if [[ -n "$existing_number" ]]; then
	echo "${title}という名前のProjectが存在します（#${existing_number}）。"
	echo "現在のリポジトリと連携しますか？ Y/n"
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
echo ".env に CLAUDE_TASKS_PROJECT_NUMBER=${project_number} を書き込みました。"

"$SCRIPT_DIR/scripts/update-status.sh"

cat <<'EOF'

残りはGitHub UI上での手動設定が必要です（built-inワークフロー）。
Projectの画面右上の "..." > Workflows から以下を設定してください:

  1. "Item added to project" を有効化し、Set value を "TaskStatus: Discussion" に設定
  2. "Item closed" を有効化し、Set value を "TaskStatus: Done" に設定

（built-inワークフローがカスタムフィールドTaskStatusを設定対象に選べるかは
GitHub UI側で要確認。選べない場合はデフォルトのStatusフィールド向けの
設定のまま残るので、その場合はREADME.mdの代替手順を参照してください）

詳細はREADME.mdの「built-inワークフローについて」を参照してください。
EOF
