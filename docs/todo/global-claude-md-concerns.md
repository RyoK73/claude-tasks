# userlocal CLAUDE.mdへの適用に関する懸念

README.mdの「各プロジェクトのCLAUDE.mdへの追記テンプレート」は、`~/.claude/CLAUDE.md`（userlocal、全プロジェクト共通で読み込まれる）ではなく、各プロジェクトのリポジトリ内CLAUDE.mdへの追記を前提にしている。もし同テンプレをuserlocalに追記し、claude-tasksの運用を全プロジェクトに一律適用した場合、以下の懸念がある。着手する際は本ファイルの該当項目を消し込み、実装後は`docs/log/`相当の記録に移すこと。

## repo名の衝突（owner違い）

- 内容：`create-task.sh`は`gh repo view --json name`でリポジトリの短縮名のみを取得しており、`nameWithOwner`を使っていない。`find-by-branch.sh`をタイトル完全一致に修正した後でも、異なるowner配下に同名リポジトリ（例: 個人の`dotfiles`と組織の`dotfiles`）が存在し、同じブランチ名で作業すると誤ったissueにマッチする
- 対応候補：issueタイトルおよび検索条件を`nameWithOwner`ベースに変更する

## GitHub以外のリポジトリ・非git環境でのエラー

- 内容：`create-task.sh`/`find-by-branch.sh`はどちらも`gh repo view`に依存しているため、GitHubリモートを持たないリポジトリ（ローカル専用、GitLab/Bitbucket管理、非git環境）で実行すると即座に失敗する。全プロジェクト適用にすると、無関係なエラーに頻繁に当たる
- 対応候補：`gh repo view`失敗時はタスク管理をスキップする分岐を各scriptに入れる

## detached HEAD・ブランチなし状態への非対応

- 内容：`git branch --show-current`はdetached HEAD時に空文字を返す。その場合issueタイトルが`"repo名: "`になったり、`find-by-branch`の検索が意図しない挙動になる
- 対応候補：ブランチ名取得が空文字の場合はエラー終了させる

## `create-task`に重複防止がない

- 内容：`create-task.sh`は既存issueの有無を確認せず、呼ぶたびに新規issueを作成する。全プロジェクトの`main`/`master`ブランチで作業するたびに実行されると、同一タイトルのissueが量産される
- 対応候補：作成前に`find-by-branch.sh`相当のロジックで既存issueをチェックし、あれば既存issue番号を返す

## GitHub Projectsのitem数上限

- 内容：全プロジェクト・全ブランチをissue化してProjectに載せ続けると、長期的にはProject側のitem数上限に近づくリスクがある
- 保留理由：初期実装では運用規模が小さく、上限に達する見込みが低いため未対応

## 機密プロジェクト名の露出

- 内容：社外秘・クライアント案件のリポジトリ名やブランチ名が、claude-tasksリポジトリのissueタイトルとして残る。claude-tasksリポジトリを他者と共有・公開する場合、情報漏えいの経路になり得る
- 対応候補：機密プロジェクトはCLAUDE.mdへのテンプレ追記自体を行わない運用ルールを明文化する

## 軽作業へのワークフロー強制

- 内容：README記載の標準フロー（Discussion→Plan Review→In Progress→Commit Review→In Fix→PR Review→Done）は機能開発向けの重めのフローであり、全プロジェクト一律適用すると些細な一発修正や個人メモ編集にもオーバーヘッドがかかる
- 保留理由：現状はオプトイン（プロジェクト単位でテンプレ追記を選択）で運用しており、この設計自体が本懸念への対応になっている
