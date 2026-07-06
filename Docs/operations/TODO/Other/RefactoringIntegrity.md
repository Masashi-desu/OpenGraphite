# Refactoring Integrity TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Other
状態: Active

## 目的

component ID の rename、page path の移動、component 削除に伴う参照整合（`og-instance` 参照、stylesheet link、`.ogp` path、内部リンク、placement source 参照）を一括更新する操作と orphan 診断が存在しない。現行は `component remove` のみで、rename / move は手作業になり参照切れを作りやすい。リファクタリング操作の範囲を確定し、spec 化する。

## スコープ

- 対象: page path 移動 / rename、component ID rename、削除時の orphan 検出、参照一括更新の transactional 実行、CLI / MCP / app の操作面。
- 対象外: バッチ編集基盤そのもの（[AgentInterfaceBatchEditing TODO](AgentInterfaceBatchEditing.md) AIBE-003 の transactional apply を前提として共有）、Git の rename 検出。

## 人間側の意思決定

- 全体: 必要 - 対象操作の範囲と orphan 診断の severity を確定する。

## 草案（判断材料）

- `project page move --path <new>`: HTML と companion CSS の file 移動、`.ogp` の `path` 更新、他 page からの内部 href / stylesheet link の更新を 1 操作で行う。
- `project component rename --component-id <ref> --new-id <id>`: master の `data-og-component` と全 page の `<og-instance data-og-component>` 参照を更新する。
- orphan 診断候補: `unresolved-component-reference`（`og-instance` が master へ解決できない）、`unresolved-placement-source`（placement の source 参照切れ）、`unresolved-internal-link`（[LinkNavigationContract TODO](../WebAssets/LinkNavigationContract.md) と共有）。severity は error / warning のどちらにするかを決める。
- 実行: 参照更新は事前検証 → 複数ファイル書き込みの transactional 経路（AIBE-003）で行い、部分適用を残さない。
- app: rename / move を Inspector / sidebar から行った場合も同じ core 操作を通す。

## 直列タスク

1. RFI-001: 対象操作と診断 severity を確定する
   - 人間判断: 必要 - 初期スコープに含める操作（page move / component rename / その他）、orphan 診断の severity、`--delete-file` 系の既定挙動を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 操作一覧と診断方針の決定が記録されている。
   - 確認方法: 文書確認。
2. RFI-002: リファクタリング操作を spec 化する
   - 人間判断: 不要
   - 内容: AgentInterface / OgkilnCLI / OpenGraphiteMCP へ操作・引数・更新対象・診断を反映する。診断 code は [ValidationDiagnosticsCatalog TODO](ValidationDiagnosticsCatalog.md) の規約に従う。
   - 完了条件: 各操作の更新対象と失敗時挙動が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. RFI-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: core 参照更新 / CLI / MCP / app 操作面の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Agent Interface](../../../specs/AgentInterface.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [Agent Interface Batch Editing TODO](AgentInterfaceBatchEditing.md)
- [ValidationDiagnosticsCatalog TODO](ValidationDiagnosticsCatalog.md)
- [LinkNavigationContract TODO](../WebAssets/LinkNavigationContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
