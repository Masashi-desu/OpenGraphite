# Document Head Metadata Contract TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: WebAssets
状態: Active

## 目的

`<head>` の編集契約が stylesheet link と `lang` / `dir` に限られており、title、meta description、OGP、favicon、viewport の扱いが未定義。standalone な Web 成果物という思想上、head は成果物品質に直結するため、編集対象の範囲と方式を確定し spec 化する。

## スコープ

- 対象: `<head>` 内の編集対象要素 allowlist、Inspector の page メタデータ編集、CLI / MCP の head 操作、i18n binding との関係。
- 対象外: stylesheet link の契約（SourceOfTruthContract の既存範囲）、`lang` / `dir`（Document Attributes として契約済み）、SEO 用構造化データ（JSON-LD 等は将来判断）。

## 人間側の意思決定

- 全体: 必要 - 編集対象 allowlist と i18n binding 対応範囲を確定する。

## 草案（判断材料）

- allowlist 候補: `<title>`、`meta[name="description"]`、`meta[property^="og:"]`、`meta[name="viewport"]`、`link[rel="icon"]`。それ以外の head 要素（script、外部 font link 等）は read-only として保持する。
- viewport: `project page create` の既定 head に含める値と、canvas 幅との関係を明記する。
- CLI 候補: `project page head set --title ... --description ... --og-image ...`。
- i18n: title / description を `data-i18n-key` 相当の binding 対象にするかどうか。初期スコープでは literal のみとし、binding は Text Binding Contract の拡張として別判断にする案。
- favicon: asset 取り込みは [AssetMediaContract TODO](AssetMediaContract.md) の取り込み規則へ委譲する。

## 直列タスク

1. DHM-001: head 編集の allowlist と binding 範囲を確定する
   - 人間判断: 必要 - 編集対象要素の範囲、i18n binding を初期スコープに含めるか、OGP tag の対象 property を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: allowlist と binding 方針の決定が記録されている。
   - 確認方法: 文書確認。
2. DHM-002: Document Head 契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract に Document Head Contract 節を追加し、OgkilnCLI / OpenGraphiteMCP / AgentInterface へ操作を反映する。
   - 完了条件: 編集対象・保存形・read-only 境界が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. DHM-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: Inspector page セグメント / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [AssetMediaContract TODO](AssetMediaContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
