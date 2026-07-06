# Persistence Conflict Undo TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Editor
状態: Active

## 目的

DesignPhilosophy / SourceOfTruthContract は永続化境界に validation、競合検出、debounce、失敗回復、undo / redo 履歴が関わると宣言しているが、その仕様が存在しない。保存パイプライン、競合解決、undo 単位の方針を確定し、spec 化する。

## スコープ

- 対象: app 内 cache から HTML / companion CSS / locale JSON / `.ogp` への保存パイプライン、外部変更および CLI / MCP 書き込みとの競合検出・解決 UX、複数ファイルにまたがる undo / redo 単位。
- 対象外: `ogkiln batch` の transactional apply（[AgentInterfaceBatchEditing TODO](../Other/AgentInterfaceBatchEditing.md) AIBE-003 の範囲）、Git 操作の自動化。

## 人間側の意思決定

- 全体: 必要 - 保存トリガ、競合解決 UX、undo 単位を安定仕様として確定する。

## 草案（判断材料）

- 保存トリガ候補: (a) 編集後 debounce 自動保存、(b) 明示保存 + dirty 表示、(c) 併用（自動保存 + 明示 flush）。
- 原子性: temp file + rename による atomic write。1 ユーザー操作が HTML + CSS + locale JSON + `.ogp` を同時に変える場合の書き込み順と、部分失敗時の rollback 方針。
- 競合検出: 読み込み時の mtime / content hash を保持し、保存直前に再検証する。cache 状態は SourceOfTruthContract の pending / conflict / error に対応させる。
- 競合解決 UX 候補: 外部優先で cache 破棄、cache 優先で上書き、diff 提示して選択。選択中ページの外部変更を破壊的に上書きしない原則（AgentInterface の External Synchronization）は維持する。
- undo 単位: 1 ユーザー操作 = 1 undo 単位とし、複数ファイルへ fan out した変更を 1 単位で戻す。外部変更検出後の undo stack の扱い（全無効化 / 対象ファイルのみ無効化）を決める。

## 直列タスク

1. PCU-001: 保存・競合・undo の方針を確定する
   - 人間判断: 必要 - 保存トリガ方式、競合解決 UX、undo 単位と外部変更後の undo stack の扱いを決める。spec 化を止める blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 各判断項目の決定が記録され、spec 化する範囲が確定している。
   - 確認方法: 文書確認。
2. PCU-002: 永続化契約を spec 化する
   - 人間判断: 不要
   - 内容: `Docs/specs/` に永続化・競合・undo の契約を追加し、DesignPhilosophy / SourceOfTruthContract / AgentInterface の該当記述と用語・状態名を整合させる。
   - 完了条件: 保存パイプライン、競合状態遷移、undo 単位が仕様として一意に読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. PCU-003: 実装 TODO を分割起票する
   - 人間判断: 不要
   - 内容: 確定した仕様から Editor 実装タスクを直列化した TODO 文書を起票し、index に登録する。
   - 完了条件: 実装 TODO が Editor index に登録され、本文書は仕様確定の残タスクを持たない。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [Agent Interface Batch Editing TODO](../Other/AgentInterfaceBatchEditing.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
