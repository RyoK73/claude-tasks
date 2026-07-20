# claude-tasks

複数プロジェクトの開発タスクを、GitHub Projects上のStatusで一元管理するための仕組み。各プロジェクトのブランチ作業に対応するissueをこのリポジトリに作成し、Claude Codeの作業フローに合わせてStatusを遷移させていく。

## セットアップ

```bash
git clone https://github.com/<owner>/claude-tasks.git
cd claude-tasks
./install.sh              # .env生成、コマンドのPATH登録
source ~/.zshrc
gh auth refresh -s project  # 初回のみ。gh project系コマンドに read:project スコープが必要
./scripts/setup-project.sh <owner>  # Project作成・Statusフィールド作成
```

`setup-project.sh` 実行後、出力される案内に従ってGitHub UI上でbuilt-inワークフローを手動設定する（詳細は後述）。

## scriptsの役割

`install.sh` を実行すると、以下4つは拡張子なしのコマンドとして `~/.local/bin` に登録され、どのプロジェクトの作業ディレクトリからでも呼び出せる。

| コマンド | 引数 | 役割 |
|---|---|---|
| `create-task` | なし | 現在のリポジトリ名・ブランチ名を自動検知し、`<repo名>: <ブランチ名>` のタイトルで管理用issueを作成する |
| `set-status` | `"<Status値>"` | 現在のブランチに対応するissueのStatusを更新する。issue番号は内部で `find-by-branch` と同じロジックを使い自動解決する |
| `find-by-branch` | なし | 現在のブランチ名から対応するissue番号を逆引きする |
| `list-status` | なし | 全プロジェクト分のopen issueをStatus付きで一覧表示する |

`scripts/setup-project.sh` のみPATH登録されない。Project自体を作る初回セットアップ専用のため、claude-tasksリポジトリ内で直接実行する。

いずれのscriptsも `lib.sh` のような共通関数ファイルへは切り出さず、単体で完結させている（依存を持たせないことで、1ファイル読むだけで挙動を理解できるようにするため）。`set-status.sh` のみ、ブランチ→issue番号の解決を `find-by-branch.sh` の呼び出しに委譲している。

## Statusの設定方法・変更方法

Statusの選択肢は `scripts/setup-project.sh` 内の `STATUS_OPTIONS` 配列にのみハードコードされている。

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

選択肢を追加・削除・変更したい場合は、この配列を編集して `setup-project.sh` を再実行する（既存のStatusフィールドはスクリプトが自動で削除してから作り直すため、GitHub UI側での手動削除は不要）。

`set-status.sh` や `list-status.sh` はStatusの選択肢名をハードコードしていない。実行のたびに `gh project field-list` でfield-id/option-idを動的に解決するため、GitHub UI上で直接Statusの選択肢を編集した場合でもズレることなく追従する。

## Statusの対応イメージ

Claude Codeでの標準的な開発フローと、各Statusの対応関係。

1. `/grill-me` で実装内容を壁打ちする → **Discussion**
2. プランモードで実装計画をユーザーに提示し、承認待ちになる → **Plan Review**
3. Claudeが実装・コミットする → **In Progress**
4. コミット内容をユーザーがレビューする → **Commit Review**
5. 手動修正・修正依頼を行う → **In Fix**
6. 別セッションのClaudeが `/pr-review`（`/code-review` の観点を内包）でレビューする → **PR Review**
7. レビュー指摘を受けてコード修正する → **In Fix**（6と7を指摘がなくなるまでループ）
8. ClaudeがPR下書きを作成し、壁打ちする → **PR Review**（継続）
9. GitHub上で最終チェックし、mainブランチにマージする → PRマージでissueが自動close → **Done**（built-inワークフローによる自動遷移）

「Plan Review」「Commit Review」「PR Review」はいずれもレビュー待ち・承認待ちの状態を表し、「In Fix」は指摘を受けて実際に手を動かしている状態を表す。修正が発生した場合は常に「In Fix」に遷移し、直ったら元のレビュー系Statusへ戻る。

Status遷移の発火は、各プロジェクトの `CLAUDE.md` に記載したルール（下記テンプレ参照）をClaudeが文脈判断で読み取り、都度 `set-status` を呼ぶことで行う。Hooksによる自動発火は現時点では導入していない（`docs/todo/future-extensions.md` 参照）。

## built-inワークフローについて

GitHub Projectsのbuilt-inワークフローは `gh project` にサブコマンドが存在しないため、`setup-project.sh` 実行後にGitHub UI上で手動設定する必要がある。

1. Projectの画面右上の `...` メニューから `Workflows` を開く
2. `Item added to project` を有効化し、`Set status` の値を `Discussion` に設定する
3. `Item closed` を有効化し、`Set status` の値を `Done` に設定する

これにより、issue作成時は自動的に `Discussion`、PRマージ等でissueがcloseされたときは自動的に `Done` に遷移する。中間の5つのStatus（Plan Review / In Progress / Commit Review / In Fix / PR Review）はbuilt-inワークフローの対象外で、`set-status` コマンドによる手動（Claudeによる）更新が必要。

## 各プロジェクトのCLAUDE.mdへの追記テンプレート

このリポジトリのscriptsを使う各プロジェクトの `CLAUDE.md`（またはリポジトリ内CLAUDE.md）に、以下をコピーして追記する。

```markdown
## タスク管理（claude-tasks）

このプロジェクトではブランチ作業をclaude-tasksリポジトリのissueで管理する。

- 作業開始時、まだ対応issueがなければ `create-task` を実行する
- 以下のタイミングで `set-status "<Status値>"` を実行し、Statusを遷移させる
  - 実装計画を提示し承認待ちになったら: `set-status "Plan Review"`
  - 実装・コミットを開始したら: `set-status "In Progress"`
  - コミット内容のレビューを求めるタイミングになったら: `set-status "Commit Review"`
  - 修正が必要になったら（レビュー指摘・ユーザーからの修正依頼どちらも）: `set-status "In Fix"`
  - `/pr-review` によるレビューを開始する、またはPR下書きを作成したら: `set-status "PR Review"`
- Doneへの遷移はPRマージ時にbuilt-inワークフローで自動的に行われるため、手動で呼ぶ必要はない
```

## 将来拡張

Blockedフィールドの追加、Hooksによる一部自動発火、CLAUDE.mdへのルール自動追記コマンド化など、今回のスコープ外にした項目は `docs/todo/future-extensions.md` にまとめている。
