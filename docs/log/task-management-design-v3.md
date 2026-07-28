# タスク管理システム 実装TODO・scripts仕様（洗い出し v3）

`task-management-design.md`（v1）・`claude-tasks-details.md`（v2）の壁打ち結果と、現状のリポジトリ状態（`RyoK73/claude-tasks`、`scripts/`配下4ファイル）を突き合わせて、次回実装セッションで着手できる粒度までTODOとscripts仕様を洗い出したもの。**本ドキュメント自体は洗い出し・整理のみが目的で、実装はまだ行っていない。**

## 現状の棚卸し

- リポジトリ `RyoK73/claude-tasks` は作成済み
- `gh auth` トークンに `read:project` スコープがなく、`gh project` 系コマンドが一切実行できない状態を確認済み
- `.github/ISSUE_TEMPLATE/task.yml` は未作成
- `README.md` は空ファイル
- `scripts/` に4ファイル存在。中身は以下の状態
  - `create-task.sh`：ほぼ完成（`gh issue create --repo RyoK73/claude-tasks` で issue 作成し番号を返す）
  - `set-status.sh`：下書き。`$STATUS_FIELD_ID` 未定義、issue番号→project item ID解決のjqが未確定、第3引数（Blocked想定）が本体未実装
  - `find-by-branch.sh`：空ファイル
  - `list-status.sh`：空ファイル
- v2ドキュメント記載の `setup-project.sh` はまだ存在しない
- v2ドキュメント中の `gh issue list --json number,title,statusField` は **誤り**。`statusField` という `--json` フィールドは存在せず、Projectのカスタムフィールド値を取るには `projectItems`（`read:project` スコープ必須）を使う必要があることを実機確認済み

## next TODO（次回実装セッション）

1. **認証スコープの追加**：`gh auth refresh -s project` を実行し、`gh project` 系コマンドを使えるようにする（他の全項目の前提条件）
2. **`scripts/setup-project.sh` の新規作成**：`gh project` で自動化できる範囲のみをスクリプト化する
   - `gh project create --owner RyoK73 --title ...`
   - `gh project field-create ... --data-type SINGLE_SELECT --single-select-options "Todo,Plan Review,In Progress,In Review,Done"`（Status）
   - `gh project field-create ... --data-type SINGLE_SELECT --single-select-options "External,User Decision,Dependency"`（Blocked）
   - built-inワークフロー（`Item closed→Set status: Done`、`Item added→Set status: Todo`）は `gh project` にサブコマンドが存在しないため**手動UI設定**。スクリプトのコメント・READMEに手順を明記するに留める
3. **`.github/ISSUE_TEMPLATE/task.yml` の新規作成**：入力項目なしの極小テンプレート（title/bodyともにコマンド側で制御するため、フォーム項目は持たせない）
4. **`scripts/create-task.sh` の確認**：現状のままでほぼ完成。shebang追加・実行権限付与のみ確認
5. **`scripts/set-status.sh` の実装完成**
   - `setup-project.sh` 実行後に確定する `field-id` / `option-id` をスクリプト内に直接ハードコード
   - 第3引数でBlockedフィールドも同時に更新できるよう統合（Status専用スクリプトとBlocked専用スクリプトには分けない）
6. **`scripts/find-by-branch.sh` の実装**：`gh issue list --repo RyoK73/claude-tasks --state open --search "in:title \"$(git branch --show-current)\"" --json number,title` ベースで実装
7. **`scripts/list-status.sh` の実装**：`statusField` ではなく `projectItems` フィールドを使う形に修正して実装（`gh issue list --json number,title,projectItems --jq` で該当Projectのstatus値を抜き出す）
8. **`README.md` の作成**：`~/.claude/CLAUDE.md` に追記する運用ルールの要約を記載（内容重複可）
9. **グローバル `~/.claude/CLAUDE.md` への追記**：v2ドキュメントの「CLAUDE.md（確定版ドラフト）」をそのまま追記
10. **動作確認**
    - あるプロジェクトでブランチ作成 → claude-tasksにissue作成 → Status遷移（Todo → Plan Review → In Progress → In Review）
    - PR作成・マージ → 管理issue自動クローズ → Status: Done への自動遷移（built-inワークフロー動作確認）
    - 複数ブランチを並行させた状態で `list-status.sh` の一覧表示を確認

## 各scriptsの最終形（サマリ）

| ファイル                    | 役割                                                                          | 状態                                           |
| --------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------- |
| `scripts/setup-project.sh`  | Project作成・Status/Blockedフィールド作成（gh projectで自動化できる範囲のみ） | 新規作成                                       |
| `scripts/create-task.sh`    | `<repo名>: <ブランチ名>` のissue作成、番号を返す                              | ほぼ完成、shebang/実行権限のみ要確認           |
| `scripts/set-status.sh`     | issue番号→item ID解決＋Status（＋任意でBlocked）更新                          | 下書きを完成させる                             |
| `scripts/find-by-branch.sh` | 現在のブランチ名でissueを逆引き                                               | 新規実装                                       |
| `scripts/list-status.sh`    | 全open issueをStatus付きで一覧表示（`projectItems`使用）                      | 新規実装（v2ドキュメントの誤りを修正して実装） |

各スクリプトは共通関数ファイル（`lib.sh`）へは切り出さず、単体で完結させる方針（依存関係を持たせないことで、Claude Codeが個々のスクリプトを読むだけで完結して理解できるようにするため）。`field-id` / `option-id` 等のProject固有の値は都度検索せず、スクリプト内に直接ハードコードする（Projectを作り直さない前提のため）。
