# Responsive Media Query Contract TODO

作成日: 2026-07-06
更新日: 2026-08-09
分類: WebAssets
状態: Active

## 目的

レスポンシブ編集の契約がない。`@media` は標準 CSS であり思想（標準 CSS property 優先）に整合するが、companion CSS 内の media rule の編集モデル、breakpoint 定義の置き場所、canvas プレビューとの対応が未定義。採否と方式を確定し、spec 化する。

## スコープ

- 対象: companion CSS 内 `@media` block の編集契約、breakpoint preset の保存場所、viewport 別 canvas preview との対応、`node style set` / graph / Inspector の media scope 表現。
- 対象外: container query・`clamp()` 等による fluid design（採用済み標準 CSS 値の範囲）、theme 切替（[ThemeTokenScopeContract TODO](ThemeTokenScopeContract.md)）。

## 人間側の意思決定

- 全体: 必要 - breakpoint 定義の置き場所と media rule 編集モデルを確定する。

## 草案（判断材料）

- 保存形: companion CSS に標準 `@media (min-width: ...)` / `(max-width: ...)` block を置き、その中では既存の authored selector を維持する。OpenGraphite annotation がある node は `[data-og-internal-id="..."]` を利用できるが必須とせず、未注釈 node は既存の標準 `id` / class / custom-element selector、または明示 adopt 後の安定 selector を使う。独自 IR は作らない。
- breakpoint preset: デザイン値ではなく editor preview metadata として `.ogp` に置く案（Project Metadata Principle と整合）。CSS 側に非標準表現（@custom-media 等）を持ち込まない。
- viewport preview: 既存の `project page place --allow-duplicate-path` + 配置名（Desktop / Mobile）を viewport preview として位置づけ、placement の canvas 幅と active media の対応規則を決める。
- CLI: `node style set --media '(max-width: 768px)'` のような media 条件指定。graph の `cssVariables` に media scope をどう表現するか（base と override の区別）。
- Inspector: active breakpoint 切替と、base 値 + override 値の cascade 表示。

## 直列タスク

1. RMQ-001: breakpoint 定義場所と編集モデルを確定する
   - 人間判断: 必要 - breakpoint preset の保存場所（`.ogp` / 慣習のみ）、media 条件の正規化（min-width 統一か自由か）、canvas 配置との対応規則を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 保存形、preset 置き場所、preview 対応の決定が記録されている。
   - 確認方法: 文書確認。
2. RMQ-002: media query 契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract / AgentInterface / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ media scope の契約を反映する。
   - 完了条件: 保存形・CLI 引数・graph 表現・validation が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. RMQ-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: serializer / Inspector / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [ThemeTokenScopeContract TODO](ThemeTokenScopeContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
