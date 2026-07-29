#!/usr/bin/env bash
set -euo pipefail

# Role: initial setup for claude-tasks
#   1. Generate .env from .env.example, auto-detecting and writing owner/repo
#   2. Create symlinks for the 4 everyday commands in ~/.local/bin
#   3. Append CLAUDE_TASKS_HOME / PATH to ~/.zshrc
# Usage: ./install.sh
#   (run this from the root of the claude-tasks repository)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
ENV_FILE="$REPO_ROOT/.env"

echo "1. Preparing .env..."
if [ ! -f "$ENV_FILE" ]; then
  cp "$REPO_ROOT/.env.example" "$ENV_FILE"
fi

owner=$(gh api user --jq '.login')
repo=$(gh repo view --json name --jq '.name')

sed -i "s/^CLAUDE_TASKS_OWNER=.*/CLAUDE_TASKS_OWNER=${owner}/" "$ENV_FILE"
sed -i "s/^CLAUDE_TASKS_REPO=.*/CLAUDE_TASKS_REPO=${repo}/" "$ENV_FILE"
echo "   Wrote CLAUDE_TASKS_OWNER=${owner} / CLAUDE_TASKS_REPO=${repo}"
echo "   Note: CLAUDE_TASKS_PROJECT_NUMBER will be written automatically after running scripts/setup-project.sh"

echo "2. Creating symlinks in ~/.local/bin..."
mkdir -p "$BIN_DIR"
for cmd in create-task set-status find-by-branch list-status; do
  ln -sf "$REPO_ROOT/scripts/${cmd}.sh" "$BIN_DIR/${cmd}"
  echo "   ${BIN_DIR}/${cmd} -> ${REPO_ROOT}/scripts/${cmd}.sh"
done

echo "3. Appending CLAUDE_TASKS_HOME/PATH to ~/.zshrc..."

# Only ZSH or BASH are supported
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ] && ! grep -q '^# claude-tasks$' "$rc" 2>/dev/null; then
    {
      echo ""
      echo "# claude-tasks"
      echo "export CLAUDE_TASKS_HOME=\"${REPO_ROOT}\""
      echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    } >>"$rc"
    echo "   Appended to ${rc}. Run 'source ${rc}' or open a new shell to apply changes"
  fi
done
cat <<'EOF'

Installation complete. Next steps:

  1. Reload your shell (or open a new terminal)
  2. gh auth refresh -s project  (if you haven't already)
  3. ./scripts/setup-project.sh <owner>  (run from inside the claude-tasks repository)

See README.md for details.
EOF
