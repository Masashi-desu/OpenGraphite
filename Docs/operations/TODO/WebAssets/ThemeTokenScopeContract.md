# Theme Token Scope Contract TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: WebAssets
状態: Active

## 目的

design token は `:root` 単一 scope のみで、dark mode / theme 切替の契約がない。AgentInterface は「将来は page / theme scope の変数操作へ拡張する」と言及済みだが仕様が存在しない。標準 CSS で表現できる theme scope の方式を確定し、spec 化する。

## スコープ

- 対象: design token の theme scope 表現、`OpenGraphite.contract.json` の `designTokens` 拡張、theme preview の注入方式、CLI / MCP / Project Inspector の theme 指定。
- 対象外: node 単位の companion CSS declaration（既存契約）、`@media` レイアウト分岐（[ResponsiveMediaQueryContract TODO](ResponsiveMediaQueryContract.md)）。

## 人間側の意思決定

- 全体: 必要 - theme scope の表現方式と preview 方式を確定する。

## 草案（判断材料）

- 表現候補:
  - (a) `@media (prefers-color-scheme: dark) { :root { ... } }`: OS 設定追従。ユーザー操作での切替は表現できない。
  - (b) `[data-theme="dark"] { ... }` 等の実装側属性 scope: 実装 runtime による切替が可能。OpenGraphite は selector を token scope として扱うが、公開ページのテーマ状態を `data-og-*` の構造・参照 metadata に混ぜない。`data-og-theme` を使う場合は editor preview 用の runtime-only 注入に限定し、保存 HTML には残さない。
  - (c) 併用: 既定は (a)、切替 UI を持つ実装は (b)。
- contract 拡張: `designTokens` に theme scope selector の列挙を追加し、token 一覧が base 値と theme override 値を対で返せるようにする。
- preview: theme を `fieldMocks`（実装 runtime への注入）と document attribute / media emulation のどちらで再現するか。prefers-color-scheme は WKWebView の appearance 連動も候補。
- CLI 候補: `design-token set --theme dark --name --color-accent --value ...`。

## 直列タスク

1. TTS-001: theme scope の表現方式を確定する
   - 人間判断: 必要 - (a) / (b) / (c) の採否、属性 scope を採る場合の属性名、preview 再現方式を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 表現方式と preview 方式の決定が記録されている。
   - 確認方法: 文書確認。
2. TTS-002: theme token 契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract の Design Token Contract / AgentInterface / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ theme scope を反映する。
   - 完了条件: 保存形・contract 拡張・CLI 引数が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. TTS-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: token 抽出 / Project Inspector / CLI / MCP / preview 注入の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [ResponsiveMediaQueryContract TODO](ResponsiveMediaQueryContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
