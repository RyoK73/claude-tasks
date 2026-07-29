# claude-tasks

A mechanism for centrally managing development tasks across multiple projects using a TaskStatus field on GitHub Projects. Issues corresponding to branch work in each project are created in this repository, and TaskStatus is transitioned to match Claude Code's workflow.

## Setup

```bash
git clone https://github.com/<owner>/claude-tasks.git
cd claude-tasks
./install.sh              # generates .env, registers commands on PATH
source ~/.zshrc
gh auth refresh -s project  # first time only. gh project commands need the read:project scope
./scripts/setup-project.sh <owner>  # creates the Project and the TaskStatus field
```

`setup-project.sh` internally calls `update-status.sh` to create the TaskStatus field. Afterward, follow the printed instructions to manually configure the built-in workflow in the GitHub UI (details below).

## Role of each script

Running `install.sh` registers the following 4 commands (without file extensions) in `~/.local/bin`, so they can be called from any project's working directory.

| Command          | Arguments           | Role                                                                                                                    |
| ---------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `create-task`    | none                 | Auto-detects the current repo name and branch name, and creates a management issue titled `<repo name>: <branch name>` |
| `set-status`     | `"<TaskStatus value>"` | Updates the TaskStatus of the issue corresponding to the current branch. Resolves the issue number automatically using the same logic as `find-by-branch` |
| `find-by-branch` | none                 | Reverse-looks-up the issue number corresponding to the current branch name                                            |
| `list-status`    | none                 | Lists all open issues across all projects, along with their TaskStatus                                                |

`scripts/setup-project.sh` and `scripts/update-status.sh` are not registered on PATH. The former is only for the initial setup that creates the Project itself, and the latter is only for maintenance work when changing the TaskStatus options — both are run directly from within the claude-tasks repository.

None of the scripts are factored out into a shared function file like `lib.sh`; each is self-contained (so that reading a single file is enough to understand its behavior, with no dependencies). The one exception is `set-status.sh`, which delegates branch-to-issue-number resolution to `find-by-branch.sh`.

## How to configure/change TaskStatus

The default "Status" field (Todo/In Progress/Done) that's auto-generated when a GitHub Project is created cannot be deleted, so claude-tasks creates a separate custom field named "TaskStatus" instead. The default Status field remains on the Project, but claude-tasks' scripts never reference or update it.

The TaskStatus options are hardcoded only in the `STATUS_OPTIONS` array inside `scripts/update-status.sh`.

```bash
STATUS_OPTIONS=(
  "Discussion"
  "Plan Review"
  "In Progress"
  "Commit Review"
  "In Fix"
  "PR Review"
  "Done"
)
```

To add, remove, or change options, edit this array and run `scripts/update-status.sh`. The Project itself is not recreated — only the existing TaskStatus field is deleted and recreated (no manual deletion in the GitHub UI is needed). Note that deleting the field also loses the TaskStatus value currently set on every item. A confirmation prompt is shown before running, so be careful if the target Project has tasks in progress.

`set-status.sh` and `list-status.sh` don't hardcode TaskStatus option names. They resolve the field-id/option-id dynamically via `gh project field-list` on every run, so they stay in sync even if TaskStatus options are edited directly in the GitHub UI.

## TaskStatus workflow mapping

How the standard Claude Code development flow maps to each TaskStatus.

1. Talk through the implementation with `/grill-me` → **Discussion**
2. Present the implementation plan to the user in plan mode and wait for approval → **Plan Review**
3. Claude implements and commits → **In Progress**
4. The user reviews the commit → **Commit Review**
5. Manual fixes or fix requests happen → **In Fix**
6. A Claude session on another branch reviews with `/pr-review` (which incorporates `/code-review`'s perspective) → **PR Review**
7. Code is fixed in response to review feedback → **In Fix** (loop between 6 and 7 until there's no more feedback)
8. Claude drafts the PR and talks it through with the user → **PR Review** (continued)
9. Final check on GitHub, merge to main → the issue auto-closes on PR merge → **Done** (automatic transition via the built-in workflow)

"Plan Review", "Commit Review", and "PR Review" all represent a state of waiting for review/approval, while "In Fix" represents actively working on feedback. Whenever a fix is needed, the status always transitions to "In Fix", then back to the original review-type TaskStatus once it's resolved.

TaskStatus transitions are triggered when Claude reads the rules written in each project's `CLAUDE.md` (see the template below) and judges from context when to call `set-status`. Automatic triggering via Hooks has not been introduced yet (see `docs/todo/future-extensions.md`).

## About the built-in workflow

Since `gh project` has no subcommand for GitHub Projects' built-in workflow, it must be configured manually in the GitHub UI after running `setup-project.sh`.

1. Open `Workflows` from the `...` menu in the top right of the Project screen
2. Enable `Item added to project`, and under `Set value` set the field to `TaskStatus` and the value to `Discussion`
3. Enable `Item closed`, and under `Set value` set the field to `TaskStatus` and the value to `Done`

(Whether the built-in workflow's configuration options let you choose a custom field other than the default Status field depends on the GitHub UI's implementation, so this needs to be verified on the actual product. If it's not possible, unify issue-creation-time/close-time TaskStatus transitions to manual updates via `set-status` as well.)

With this in place, issues automatically transition to `Discussion` when created, and to `Done` when closed (e.g. via a PR merge). The 5 intermediate TaskStatus values (Plan Review / In Progress / Commit Review / In Fix / PR Review) are outside the scope of the built-in workflow and require manual updates (by Claude) via the `set-status` command.

## Template to append to each project's CLAUDE.md

Copy and append the following to the `CLAUDE.md` (or the in-repo CLAUDE.md) of each project that uses this repository's scripts.

```markdown
## Task management (claude-tasks)

This project manages branch work using issues in the claude-tasks repository.

- At the start of work, if there's no corresponding issue yet, run `create-task`
- Run `set-status "<TaskStatus value>"` at the following points to transition TaskStatus:
  - When the implementation plan is presented and awaiting approval: `set-status "Plan Review"`
  - When implementation/committing begins: `set-status "In Progress"`
  - When it's time to ask the user to review the commit: `set-status "Commit Review"`
  - When a fix is needed (whether from review feedback or a user fix request): `set-status "In Fix"`
  - When starting a `/pr-review` review, or once a PR draft is created: `set-status "PR Review"`
- The transition to Done happens automatically via the built-in workflow on PR merge, so there's no need to call it manually
```

## Future extensions

Items left out of scope for now — such as adding a Blocked field, automatic triggering via Hooks for some transitions, and a command to auto-append rules to CLAUDE.md — are collected in `docs/todo/future-extensions.md`.
