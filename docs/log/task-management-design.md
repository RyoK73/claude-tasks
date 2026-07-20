# タスク管理システム設計（壁打ちメモ）

`/think` セッションで、Claude Codeと共有可能なタスク可視化ツールについて検討した結果をまとめる。次回セッションではこのドキュメントを起点に実装へ着手する。

## 背景・経緯

当初はNotionをUIとして使う案を検討したが、以下の理由で見送った。

- Notionはブロックベースのため、1ページ分のレスポンスでも`rich_text`のネスト構造で容易に数百〜数千トークンに膨れる
- 単純な操作でも search → ブロック取得 → 更新、と複数往復のツールコールが必要になりがち
- 本ユースケースは「Claude Codeがタスク発生・完了のたびに書き込む」高頻度書き込みが前提であり、1回あたりの重さが頻度倍で効いてくる

要件は以下の通り。

- 可視化ツールは自分だけが後から進捗を眺める用途（リアルタイム共有は不要）
- フラットなToDoリストで、階層構造とステータス管理がほしい
- GitHub issueとの連携（できればissueそのものを使いたい）

## 採用方針：GitHub Projects (v2) + gh CLI

- Projects v2はGraphQL API専用だが、`gh project`サブコマンド（`item-list` / `item-create` / `item-edit` 等）がラップしてくれている
- MCPサーバーを介さず、Bashツールから`gh`を直接叩く構成にする
  - 認証はgh CLIが既に保持
  - `--format json --jq '...'`でレスポンスを絞り込め、コンテキスト消費を自分で制御できる
  - コマンドが単純なためClaude Codeによる生成ミスが少なく、エラー→リトライの往復コストも抑えられる
- 複雑なフィルタや一括操作などCLIが対応しない操作のみ、生GraphQL APIに降りる。頻度が高い場面では「1回の理論効率」より「構築コスト・失敗率の低さ」を優先する

## リポジトリ構成

- `taruroma/claude-tasks` を管理用リポジトリとして新設し、個人開発の全プロジェクトのタスクをここに集約する
- 理由：各プロジェクトの実issueトラッカーを、頻度の高いタスクログで汚染しないため
- Project自体はuser-levelで作成し、`claude-tasks`のissueを集約する。将来的に他リポジトリのissueも同じProjectに混ぜることも可能

## 階層構造

- GitHub Issueのsub-issues機能を使う
- draft item（リポジトリに紐付かない軽量アイテム）ではsub-issuesが使えないため、必ず実issueとして作成する

## クロスリポジトリでの「解決」の表現

管理リポジトリのissueと、実際の作業が行われる各プロジェクトリポジトリとの関連付けは、以下の方式を採用する。

- **各プロジェクトリポジトリ側のPR本文に `Closes taruroma/claude-tasks#N` を記載する**
- 同一アカウント内であれば、別リポジトリのPRマージで管理リポジトリ側issueが自動クローズされる
- 管理リポジトリ側には別途「解決issue」を作らない。実装の実体は各プロジェクトのコミット/PRであり、管理issueはあくまでログという位置づけ

検討した他の方式：
- 単純な相互参照（`owner/repo#123`と書くだけ）：自動クローズしないため見送り
- クロスリポジトリのsub-issue（親子関係）：両リポジトリにissueが必要になり手間が増えるため、今回は不採用（必要になれば再検討）

## ステータス管理

新規issueを都度作らず、Projectのカスタムフィールド（Status）の遷移で状態を表現する。

```
Todo → In Progress → In Review → Done
```

- タスク発生：`gh issue create` でissue作成、Status=Todo
- 実装開始：`gh project item-edit` でStatus=In Progress
- PR作成時：Status=In Reviewに変更（同時にPR本文へClosesキーワードを仕込む）
- PRマージ→issue自動クローズ→built-inワークフロー（「Item closed → Set status: Done」）でStatus=Doneへ自動遷移

「レビュー待ち」も新規issueを作らず、既存issueのステータス変化として表現する。実装とレビューを別issueに分離する必要が生じた場合のみ、sub-issueとして切り出す。

## issue番号の持ち越し

状態ファイル（JSON等）は持たない方針とする。

- 同一セッション内で完結する場合：issue作成時の番号はそのまま会話コンテキストに残っているため、それを使う
- セッションを跨ぐ場合：PR作成の直前にのみ、`gh issue search --repo taruroma/claude-tasks ...` 等で1回だけ検索して番号を引き当てる

検索が必要になるのは「PRを書く瞬間、かつ番号がコンテキストにない場合」のみであり、実装中のループには一切絡まない。

### 検討した代替案（不採用）

| 案 | 内容 | 不採用の理由 |
|---|---|---|
| 共有JSON＋ロック | `~/.claude/task-state.json`等に番号を記録 | 複数worktreeの並行セッションで書き込み競合が起きうる。ロック実装・保守コストが乗る。GitHub側の実状態とのズレ（セカンドソース問題）も発生しうる |
| worktree-local git config | `git config --worktree`でworktree固有に保存 | 競合は起きないが、GitHub側とは別に状態を持つ点はJSON案と同じ |

いずれも「状態を持つ」ことに起因する複雑さがあるため、まずは状態を持たない検索方式で運用し、検索コストが問題になった場合にworktree-local config等を再検討する。

## 設定のコード化の限界

- **issue_template**（`.github/ISSUE_TEMPLATE/*.yml`）：リポジトリ内でファイルとして完全にバージョン管理できる
- **Projectのフィールド定義・built-inワークフロー**：リポジトリのファイルとしては存在せず、UIまたはGraphQL API経由での都度設定が必要。issue_templateのような「置けば自動適用される」宣言的な仕組みは無い
- 対応策として、フィールド・ワークフローを構築するセットアップスクリプト（`gh api graphql`呼び出し等）をリポジトリに置くことはできるが、これは1回実行すれば反映される命令的なものであり、UIから手動変更された場合はスクリプトとの乖離が起こりうる点に注意

## 次回実装セッションでのTODO

1. `taruroma/claude-tasks` リポジトリにProjectを作成し、Statusフィールド（Todo/In Progress/In Review/Done）とbuilt-inワークフロー（Item closed → Set status: Done）を設定する
2. `.github/ISSUE_TEMPLATE/` でタスクissueのテンプレートを整備する
3. グローバルCLAUDE.md（`~/.claude/CLAUDE.md`）にタスク管理運用ルールを追記する
   - 管理issueの作成タイミング・作成先（`taruroma/claude-tasks`）
   - Statusフィールドの遷移ルール
   - 各プロジェクトのPRに`Closes taruroma/claude-tasks#N`を付与するルール
   - セッションを跨ぐ際の番号引き当て方法（`gh issue search`）
4. 動作確認：実際にissue作成 → 別リポジトリでのPR作成・マージ → 管理issue自動クローズ、の一連の流れをテストする
