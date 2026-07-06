# Validation Diagnostics Catalog TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Other
状態: Active

## 目的

diagnostics code（`duplicate-data-og-id`、`component-placement-outside-collection` 等）が各文書に個別に出現しており、code の正本カタログと、app 保存 / `ogkiln` / MCP の 3 経路で同じ validation を通るというパリティ保証が仕様として存在しない。カタログの置き場所と規約を確定し、spec 化する。

## スコープ

- 対象: 診断 code の命名規約、severity 意味論、既存 code の棚卸し、カタログ正本の置き場所、3 経路のパリティ保証とテスト方針。
- 対象外: 個別の新規診断の追加（各機能 TODO の範囲。追加時にこのカタログ規約へ従う）。

## 人間側の意思決定

- 全体: 必要 - カタログ正本の置き場所と命名規約を確定する。

## 草案（判断材料）

- 命名規約: kebab-case、対象-問題の順（例: `duplicate-data-og-id`）。message は日本語、code は英語という現行慣行を明文化する。
- severity 意味論: `error` は write を行わない、`warning` は write を止めないが AI はユーザーへ報告できる必要がある（AgentInterface の既存記述を正本化）。`info` を追加するかどうか。
- カタログ正本の候補: (a) `OpenGraphite.contract.json` に `diagnostics` section を追加（機械可読、MCP から取得可能）、(b) spec 文書の表（人間可読）、(c) 両方（contract を正本、spec は参照）。
- パリティ: app 保存 / CLI / MCP が同じ validation core を通ることを契約として明記し、経路別の抜けをテストで検出する。
- 棚卸し: 実装内の全 code を列挙し、文書化されていない code を洗い出す。

## 直列タスク

1. VDC-001: カタログ正本の置き場所と規約を確定する
   - 人間判断: 必要 - 正本の置き場所（contract.json / spec / 両方)、命名規約、severity 一覧を決める。blocking decision。
   - 内容: 実装から既存 code を棚卸しし、草案の選択肢を比較して決定を本文書へ反映する。
   - 完了条件: 置き場所・規約の決定と既存 code 一覧が記録されている。
   - 確認方法: 文書確認。
2. VDC-002: 診断カタログを spec 化する
   - 人間判断: 不要
   - 内容: 決定した正本へ全 code を登録し、AgentInterface の Diagnostics 節をカタログ参照へ更新する。パリティ保証を契約として明記する。
   - 完了条件: 全 code が severity・発生条件つきで一覧でき、3 経路のパリティが仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. VDC-003: パリティテストの実装 TODO を起票する
   - 人間判断: 不要
   - 内容: 同一の invalid fixture に対して app 保存 / CLI / MCP が同じ診断を返すことを検証するテストを整備する実装 TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Agent Interface](../../../specs/AgentInterface.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [OpenGraphite MCP](../../../specs/OpenGraphiteMCP.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
