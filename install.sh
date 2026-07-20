#!/usr/bin/env bash
set -euo pipefail

# 役割: claude-tasksの初回セットアップ
#   1. .env.example から .env を生成し、owner/repoを自動検知して書き込む
#   2. ~/.local/bin に日常使用4コマンドのsymlinkを作成する
#   3. CLAUDE_TASKS_HOME / PATH を ~/.zshrc に追記する
# 使い方: ./install.sh
#   （claude-tasksリポジトリのルートで実行すること）

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
ENV_FILE="$REPO_ROOT/.env"

echo "1. .env を準備中..."
if [ ! -f "$ENV_FILE" ]; then
  cp "$REPO_ROOT/.env.example" "$ENV_FILE"
fi

owner=$(gh api user --jq '.login')
repo=$(gh repo view --json name --jq '.name')

sed -i "s/^CLAUDE_TASKS_OWNER=.*/CLAUDE_TASKS_OWNER=${owner}/" "$ENV_FILE"
sed -i "s/^CLAUDE_TASKS_REPO=.*/CLAUDE_TASKS_REPO=${repo}/" "$ENV_FILE"
echo "   CLAUDE_TASKS_OWNER=${owner} / CLAUDE_TASKS_REPO=${repo} を書き込みました"
echo "   ※ CLAUDE_TASKS_PROJECT_NUMBER は scripts/setup-project.sh 実行後に自動で書き込まれます"

echo "2. ~/.local/bin にsymlinkを作成中..."
mkdir -p "$BIN_DIR"
for cmd in create-task set-status find-by-branch list-status; do
  ln -sf "$REPO_ROOT/scripts/${cmd}.sh" "$BIN_DIR/${cmd}"
  echo "   ${BIN_DIR}/${cmd} -> ${REPO_ROOT}/scripts/${cmd}.sh"
done

echo "3. ~/.zshrc にCLAUDE_TASKS_HOME/PATHを追記中..."

# ZSH or BASHにのみ対応
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ] && ! grep -q '^# claude-tasks$' "$rc" 2>/dev/null; then
    {
      echo ""
      echo "# claude-tasks"
      echo "export CLAUDE_TASKS_HOME=\"${REPO_ROOT}\""
      echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    } >>"$rc"
    echo "   ${rc} に追記しました。反映には 'source ${rc}' か新しいシェルの起動が必要です"
  fi
done
cat <<'EOF'

インストール完了です。次にやること:

  1. シェルのリロード  (または新しいターミナルを開く)
  2. gh auth refresh -s project  (まだ実行していなければ)
  3. ./scripts/setup-project.sh <owner>  (claude-tasksリポジトリ内で実行)

詳細はREADME.mdを参照してください。
EOF
