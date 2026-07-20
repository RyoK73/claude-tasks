# タスク管理システム設計（壁打ちメモ v2）

前回の `/think` セッションのメモを起点に、Claude Codeとの壁打ちでブランチ単位の状態可視化について詳細化した結果をまとめる。次回セッションではこのドキュメントを起点に実装へ着手する。

## 位置づけ（最重要・前回からの変更点）

- **各プロジェクトの機能実装・バグ修正は、そのプロジェクト自身のissueで管理する**（変更なし）
- **`taruroma/claude-tasks` はそれとは独立した「Claudeの作業ログ・状態可視化」専用リポジトリ**
- 両者は直接リンクしない。**ブランチ名のみを共通のkeyとして間接的に対応づく**

```
プロジェクト側issue  ⇄  ブランチ  ⇄  claude-tasks側issue
   （機能・バグ管理）      (key)        （作業ログ・状態管理）
```

claude-tasksはプロジェクト側issueの「転記先」ではない。目的は、ブランチを切ってからPRを出すまでの間（＝どのプロジェクトのどのブランチが今どの段階にあるか）が、複数ブランチ・複数worktree並行時に見えなくなる問題を解消すること。

## 背景・経緯（前回セッションから）

当初はNotionをUIとして使う案を検討したが、以下の理由で見送った。

- Notionはブロックベースのため、1ページ分のレスポンスでも`rich_text`のネスト構造で容易に数百〜数千トークンに膨れる
- 単純な操作でも search → ブロック取得 → 更新、と複数往復のツールコールが必要になりがち
- 本ユースケースは「Claude Codeがタスク発生・完了のたびに書き込む」高頻度書き込みが前提であり、1回あたりの重さが頻度倍で効いてくる

要件は以下の通り。

- 可視化ツールは自分だけが後から進捗を眺める用途（リアルタイム共有は不要）
- フラットなToDoリストで、階層構造とステータス管理がほしい
- 複数ブランチ・複数worktreeの並行状態を一覧で把握したい

## 採用方針：GitHub Projects (v2) + gh CLI

- Projects v2はGraphQL API専用だが、`gh project`サブコマンド（`item-list` / `item-create` / `item-edit` 等）がラップしてくれている
- MCPサーバーを介さず、Bashツールから`gh`を直接叩く構成にする
  - 認証はgh CLIが既に保持
  - `--format json --jq '...'`でレスポンスを絞り込め、コンテキスト消費を自分で制御できる
  - コマンドが単純なためClaude Codeによる生成ミスが少なく、エラー→リトライの往復コストも抑えられる
- 複雑なフィルタや一括操作などCLIが対応しない操作のみ、生GraphQL APIに降りる。頻度が高い場面では「1回の理論効率」より「構築コスト・失敗率の低さ」を優先する

## ディレクトリ構成

```
taruroma/claude-tasks/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── task.yml          # 作業ログissue作成用テンプレート
│   └── workflows/
│       └── (Projectの自動化はUI/GraphQL側なのでここは空 or 補助的なCI程度)
├── scripts/
│   ├── setup-project.sh      # Project作成・フィールド定義・ワークフロー設定（gh api graphql）
│   └── find-issue.sh         # ブランチ名からのissue逆引きラッパー
└── README.md                 # 運用ルールの人間向け説明（CLAUDE.mdと内容重複可）
```

「状態を持たない」方針通り、リポジトリ自体は薄く保つ。`scripts/`は再実行可能な**宣言の再適用**という位置づけで、Project側がUIから乖離した時の復旧手段として置いておく。

## ステータス管理

新規issueを都度作らず、Projectのカスタムフィールドの遷移で状態を表現する。フィールドを2つに分離するのがポイント。

### Status（Single select・直線的な進行）

```
Todo → Plan Review → In Progress → In Review → Done
```

| 値 | 意味 | 遷移トリガー |
|---|---|---|
| `Todo` | 未着手 | issue作成時（built-inワークフロー「Item added」で自動化可） |
| `Plan Review` | planモードで計画作成済み、ユーザーの承認待ち | Claude Codeが手動で`item-edit` |
| `In Progress` | 承認後、実装中 | ユーザー承認をトリガーにClaude Codeが手動で`item-edit` |
| `In Review` | PR作成済み、レビュー待ち | PR作成コマンドと同時にClaude Codeが手動で`item-edit` |
| `Done` | 完了 | built-inワークフロー「Item closed → Done」で自動 |

### Blocked（Single select・独立フィールド、通常は空）

```
(空) / External / User Decision / Dependency
```

- どのStatusの上にも重ねられる「注記」として使う
- 例：`In Progress` かつ `Blocked: Dependency`（他タスク完了待ちで実装中断中）
- Claude Codeが手を止めるときに設定し、再開時にクリアする運用

## ブランチとの接続

- ブランチは各プロジェクトの命名規則のまま切ってよい（claude-tasks側が番号を強制しない）
- Claude Codeがそのブランチでの作業を開始する時点で、claude-tasksにissueを作成する
  - title: `<repo名>: <ブランチ名>`
  - body: プロジェクト側issueへのリンクは持たせない（空でよい）
- セッション再開時は `git branch --show-current` の値でtitleを検索して状態を特定する

```bash
gh issue list --repo taruroma/claude-tasks \
  --state open \
  --search "in:title \"$(git branch --show-current)\"" \
  --json number,title
```

## クロスリポジトリでの「解決」の表現

- 各プロジェクトリポジトリ側のPR本文に `Closes taruroma/claude-tasks#N` を記載する
- 同一アカウント内であれば、別リポジトリのPRマージで管理リポジトリ側issueが自動クローズされる
- 管理リポジトリ側には別途「解決issue」を作らない。実装の実体は各プロジェクトのコミット/PRであり、管理issueはあくまでログという位置づけ

検討した他の方式（不採用）：

| 案 | 不採用の理由 |
|---|---|
| 単純な相互参照（`owner/repo#123`のみ） | 自動クローズしない |
| クロスリポジトリのsub-issue（親子関係） | 両リポジトリにissueが必要になり手間が増える |

## 並行状態の確認（本リポジトリの主目的）

```bash
gh issue list --repo taruroma/claude-tasks --state open \
  --json number,title,statusField --jq '.[] | "\(.title): \(.status)"'
```

これで「どのプロジェクトのどのブランチが今どの段階か」を一覧で見られる。

## CLAUDE.md（確定版ドラフト）

```markdown
## タスク管理ルール（taruroma/claude-tasks）

### 位置づけ
- 各プロジェクトの機能実装・バグ修正は、そのプロジェクト自身のissueで管理する（変更なし）
- taruroma/claude-tasks はそれとは独立した「Claudeの作業ログ・状態可視化」専用リポジトリ
- 両者は直接リンクしない。ブランチ名のみを共通のkeyとして間接的に対応づく

### ブランチでの作業開始時
1. taruroma/claude-tasks に作業ログ用issueを作成する
   - title: "<repo名>: <ブランチ名>"
   - Status: Todo
2. プロジェクト側issueへのリンクは持たせない（bodyも空で良い）

### 状態遷移
- plan提示時 → Status: Plan Review
- ユーザー承認・実装開始 → Status: In Progress
- PR作成時 → Status: In Review（PR本文に "Closes taruroma/claude-tasks#N" を含める）
- PRマージ → 自動close → built-inワークフローで Status: Done

### 中断時
- 外部要因・判断待ちで手が止まる場合は Blocked フィールドを設定し、再開時にクリアする

### セッション再開時のissue特定
- git branch --show-current の値でtitleを検索する
  gh issue list --repo taruroma/claude-tasks --state open --search "in:title \"$(git branch --show-current)\""

### 並行状態の確認（ユーザー依頼時）
- gh issue list --repo taruroma/claude-tasks --state open --json number,title でStatus付き一覧を出す
```

## 設定のコード化の限界

- **issue_template**（`.github/ISSUE_TEMPLATE/*.yml`）：リポジトリ内でファイルとして完全にバージョン管理できる
- **Projectのフィールド定義・built-inワークフロー**：リポジトリのファイルとしては存在せず、UIまたはGraphQL API経由での都度設定が必要
- 対応策として、フィールド・ワークフローを構築するセットアップスクリプト（`gh api graphql`呼び出し等）をリポジトリに置くが、これは1回実行すれば反映される命令的なものであり、UIから手動変更された場合はスクリプトとの乖離が起こりうる点に注意

## 次回実装セッションでのTODO

1. `taruroma/claude-tasks` リポジトリを作成し、Projectを作成する
   - カスタムフィールド：`Status`（Single select: Todo / Plan Review / In Progress / In Review / Done）、`Blocked`（Single select: 空 / External / User Decision / Dependency）
   - built-inワークフロー：`Item closed → Set status: Done`（可能であれば `Item added → Set status: Todo` も）
2. `.github/ISSUE_TEMPLATE/task.yml` を作成する（作業ログissue作成用）
3. `scripts/setup-project.sh` を作成する（Project作成・フィールド定義・ワークフロー設定をコード化）
4. `scripts/find-issue.sh` を作成する（ブランチ名からのissue逆引きラッパー）
5. グローバルCLAUDE.md（`~/.claude/CLAUDE.md`）に上記ルールを追記する
6. 動作確認：
   - あるプロジェクトでブランチ作成 → claude-tasksにissue作成 → Status遷移（Todo → Plan Review → In Progress → In Review）
   - PR作成・マージ → 管理issue自動クローズ → Status: Done への自動遷移
   - 複数ブランチを並行させた状態で `gh issue list` による一覧表示を確認

## 未決事項（次回以降で詰める）

- `task.yml` の具体的な項目設計
- `scripts/setup-project.sh` の実際のGraphQL mutation内容
- 1ブランチで複数のプロジェクト側issueを跨ぐ場合の例外運用
