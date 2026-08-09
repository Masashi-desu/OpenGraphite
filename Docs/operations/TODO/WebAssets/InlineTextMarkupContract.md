# Inline Text Markup Contract TODO

作成日: 2026-07-06
更新日: 2026-08-09
分類: WebAssets
状態: Active

## 目的

text node 内の inline 要素（`a`、`strong`、`em`、`br`、`code` 等）の編集・保存契約がない。`node text set` は plain text のみで、リンクや強調を含む本文が表現できない。Web ページ編集ツールとして必要な範囲を確定し、spec 化する。

## スコープ

- 対象: DOM / content から text-edit capability を持つと判定された node 内の inline 要素 allowlist、保存・escape 規則、Canvas の text 編集セッションでの inline 生成、CLI / MCP / graph の表現、i18n binding との併用。`data-og-type="text"` は必須条件にしない。
- 対象外: block 要素の入れ子（frame 構造の範囲）、rich text 独自フォーマットの導入（HTML 標準の範囲に限定する）。

## 人間側の意思決定

- 全体: 必要 - inline allowlist と i18n binding 併用範囲を確定する。

## 草案（判断材料）

- allowlist 候補: `a`、`strong`、`em`、`br`、`code`、`span`。`data-og-id` を持たない inline 要素は「text content の一部」であり、node graph / Layers に載せない。
- 保存: `node text set --format inline` のような明示 mode で allowlist ベースの sanitize を通す。既定は現行の plain text escape を維持する。
- graph: `textContent` はタグ除去の現状維持。必要なら inline markup を含む field（例: `textHTML`）を追加する。
- Canvas 編集: `contenteditable` セッションで許す操作（リンク挿入、強調）と、貼り付け時の sanitize 規則。
- i18n: locale JSON の値に inline markup を許すか。許す場合の sanitize 境界と、fallback content との整合。

## 直列タスク

1. ITM-001: inline allowlist と i18n 併用範囲を確定する
   - 人間判断: 必要 - allowlist の範囲、locale JSON への markup 許可、Canvas 編集で許す操作を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: allowlist・sanitize 境界・i18n 方針の決定が記録されている。
   - 確認方法: 文書確認。
2. ITM-002: inline markup 契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract / AgentInterface / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ inline 契約を反映する。
   - 完了条件: 保存形・sanitize 規則・graph 表現が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. ITM-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: sanitizer / Canvas text 編集 / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [LinkNavigationContract TODO](LinkNavigationContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
