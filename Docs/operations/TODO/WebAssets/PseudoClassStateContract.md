# Pseudo Class State Contract TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: WebAssets
状態: Active

## 目的

`:hover` / `:focus` / `:active` 等の状態スタイルの編集契約がない。疑似クラスは標準 CSS であり思想に整合するが、編集対象 rule の形、許可 allowlist、editor preview での状態再現方式が未定義。採否と方式を確定し、spec 化する。

## スコープ

- 対象: companion CSS 上の `[data-og-internal-id="..."]:<pseudo>` rule の編集契約、許可疑似クラス allowlist、Inspector / Canvas の状態 preview、CLI / MCP の state 指定。
- 対象外: placement の `data-og-placement-mode`（構造状態。既存契約を維持し、CSS 疑似状態とは役割分離する）、`@media`（[ResponsiveMediaQueryContract TODO](ResponsiveMediaQueryContract.md)）。

## 人間側の意思決定

- 全体: 必要 - 許可疑似クラスの範囲と preview 再現方式を確定する。

## 草案（判断材料）

- 保存形: companion CSS の `[data-og-internal-id="x"]:hover { ... }` を編集対象 rule にする。
- allowlist 候補: `:hover`, `:focus`, `:focus-visible`, `:active`, `:disabled`。`OpenGraphite.contract.json` に追加し、対象外の疑似クラス・複合 selector は read-only として扱う。
- preview 再現: WebKit の forced pseudo-class 相当が使えない場合、runtime-only の状態 class / 属性注入で再現し、保存 HTML には残さない（Runtime-Only Attribute Contract と同じ扱い）。
- CLI: `node style set --state hover --var background --value ...`。graph には state scope 付き declaration として表現する。
- `data-og-placement-mode`（表示状態の構造切替）と CSS 疑似状態（インタラクション状態）の役割分離を spec に明記する。

## 直列タスク

1. PCS-001: allowlist と preview 方式を確定する
   - 人間判断: 必要 - 許可疑似クラスの範囲、preview の状態強制方式、対象外 selector の扱いを決める。blocking decision。
   - 内容: WebKit 上での状態強制の実現手段を調査し、草案を確定して本文書へ反映する。
   - 完了条件: allowlist と preview 方式の決定が記録されている。
   - 確認方法: 文書確認と調査結果の記録先（`Docs/investigations/`）確認。
2. PCS-002: 疑似クラス契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ state scope の契約を反映する。
   - 完了条件: 保存形・allowlist・CLI 引数・preview 属性の扱いが仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. PCS-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: serializer / Inspector / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [ResponsiveMediaQueryContract TODO](ResponsiveMediaQueryContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
