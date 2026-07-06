# Accessibility Semantics Contract TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: WebAssets
状態: Active

## 目的

`<MainTitle>` のようなカスタムタグは h1 / nav / main の暗黙セマンティクスを持たず、スクリーンリーダー・SEO と「Web 標準の成果物」思想の間に緊張がある。また `alt` / `aria-*` / `role` / 見出しレベルの編集契約がない。セマンティクスの表現方式を確定し、spec 化する。

## スコープ

- 対象: landmark / heading セマンティクスの表現方式、`alt` / `aria-label` / `aria-hidden` / `role` 等の編集対象属性、アクセシビリティ validation。
- 対象外: `lang` / `dir`（Document Attributes として契約済み）、WCAG 監査機能の網羅（将来判断）、コントラスト検査等のデザイン支援。

## 人間側の意思決定

- 全体: 必要 - セマンティクス表現方式を確定する。思想（タグ名 = 意味、source = 成果物）との整合が論点。

## 草案（判断材料）

- 表現方式の候補:
  - (a) landmark / heading には標準タグ名（`h1`〜`h6`、`nav`、`main`、`header`、`footer`）をタグ名として使うことを推奨する。「タグ名は人間が読める意味を担う」原則と両立する。
  - (b) カスタムタグを維持し、`role` / `aria-level` を editableAttributes に追加して明示する（`role="heading" aria-level="1"` 等）。
  - (c) build 時に標準タグへ書き換える。source と成果物の同一性を壊すため思想に反し、原則不採用。
  - 有力案は (a) + (b) の併用。spec には推奨順位を明記する。
- 編集対象属性の追加候補: `alt`（image）、`aria-label`（button / icon）、`aria-hidden`（装飾 icon）、`role`。
- validation 候補: image の `alt` 欠落（warning）、heading レベルの飛び（warning）。診断 code は [ValidationDiagnosticsCatalog TODO](../Other/ValidationDiagnosticsCatalog.md) の規約に従う。
- `ogkiln build` の出力がそのまま公開されるため、成果物側での補正は行わず source 側で完結させる。

## 直列タスク

1. ACC-001: セマンティクス表現方式を確定する
   - 人間判断: 必要 - (a) / (b) の採否と推奨順位、editableAttributes へ追加する属性範囲、validation の severity を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 表現方式と属性範囲の決定が記録されている。
   - 確認方法: 文書確認。
2. ACC-002: アクセシビリティ契約を spec 化する
   - 人間判断: 不要
   - 内容: DesignPhilosophy（タグ名原則への補足）/ SourceOfTruthContract / `OpenGraphite.contract.json` へセマンティクス表現と編集対象属性を反映する。
   - 完了条件: タグ名と aria / role の使い分け、編集対象属性、診断が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. ACC-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: Inspector 属性編集 / validation / sample project 更新の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [AssetMediaContract TODO](AssetMediaContract.md)
- [ValidationDiagnosticsCatalog TODO](../Other/ValidationDiagnosticsCatalog.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
