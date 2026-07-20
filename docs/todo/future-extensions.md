# 将来拡張想定

`docs/log/task-management-design-v3.md` の壁打ちを踏まえた初期実装（Status 7段階・env/PATH運用）では扱わず、将来の拡張候補として保留した項目の一覧。着手する際は本ファイルの該当項目を消し込み、実装後は `docs/log/` 相当の記録に移すこと。

## Blockedフィールドの追加

- 内容：Status（Discussion〜Done）とは別軸で、作業が外部要因で止まっている状態を表す単一選択フィールド（`External` / `User Decision` / `Dependency`）を追加する
- 保留理由：初期実装では運用実績がないままフィールドを増やすと形骸化するリスクがあるため、Statusのみでの運用を試してから要否を判断する
- 実装時の論点：`set-status.sh` の第2引数として統合するか、`set-blocked.sh` として独立させるか（`docs/log/task-management-design-v3.md` では前者の方針だった）

## Statusの一部自動遷移（Hooks活用）

- 内容：現状はCLAUDE.mdに書いたルールをClaudeが文脈判断で読み取り `set-status` を呼ぶ運用。将来的にはPreToolUse/PostToolUseなどのHooksで、特定のツール呼び出し（例：`gh pr create` の実行）を検知して確実に自動発火させる
- 保留理由：まずはHooksなしのワークフロー自体の妥当性を検証したい。Hooksは検知条件の設計や誤発火対策の実装コストが高い
- 候補：PR作成検知→PR Reviewへ自動遷移、PRマージ検知はbuilt-inワークフローで既に自動化済み

## 各プロジェクトCLAUDE.mdへのルール自動追記コマンド化

- 内容：README.mdに掲載したワークフロールールのテンプレ文を、各プロジェクトの `CLAUDE.md` に手動コピペする運用を、`install-claude-tasks-rules` のようなコマンドで自動追記・重複チェックできるようにする
- 保留理由：初期実装では配布対象・配布先CLAUDE.mdの数が少なく、手動コピペで十分。運用が広がってから自動化の要否を判断する
