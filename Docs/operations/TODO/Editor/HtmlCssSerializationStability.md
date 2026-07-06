# HTML CSS Serialization Stability TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Editor
状態: Active

## 目的

「成果物をリポジトリ上でレビュー・配布できる」という思想の前提となる、書き戻し時の diff 安定性（シリアライズ規則）が未定義。app と `ogkiln` が共有する HTML / companion CSS serializer の正規化・保存規則を確定し、spec 化する。

## スコープ

- 対象: HTML / companion CSS の書き戻し時の属性順、空白・インデント、コメント、未知属性、非 OG ノード、他ライブラリ CSS の保存規則。roundtrip（無編集で開いて保存）の保証。
- 対象外: 断片整形 CLI の新設（[AgentInterfaceBatchEditing TODO](../Other/AgentInterfaceBatchEditing.md) AIBE-005 と連携）、`.ogp` の JSON 整形（[OgpSchemaVersioning TODO](OgpSchemaVersioning.md)）。

## 人間側の意思決定

- 全体: 必要 - roundtrip identity を必須保証にするか、初回保存時の整形正規化を許容するかを確定する。

## 草案（判断材料）

- 不変条件候補: 無編集で開いて保存した場合に byte diff を出さない（roundtrip identity）。
- 編集時: 変更した node / rule だけを書き換え、既存の属性順・インデント・コメント・未知属性・非 OG ノード・他ライブラリ CSS declaration を byte 保持する。
- 新規生成 node の整形規則: インデント幅、属性の記述順（contract の属性順に従う）。
- CSS: 1 declaration 1 行、既存 rule 順の維持、新規 rule の挿入位置（selector 出現順 / 末尾追記）。
- escape 規則: `node text set` の `<` `>` `&` escape と Canvas 直接編集の保存を同一規則にする。

## 直列タスク

1. SER-001: シリアライズ保証の方針を確定する
   - 人間判断: 必要 - roundtrip identity を必須にするか、初回のみ正規化整形を許すか、新規 node の整形規則を決める。blocking decision。
   - 内容: 現行 serializer の roundtrip 実測を行い、草案の選択肢を比較して決定を本文書へ反映する。
   - 完了条件: 保証範囲（不変条件）と整形規則の決定が記録されている。
   - 確認方法: 文書確認と実測結果の記録先（`Docs/investigations/`）確認。
2. SER-002: シリアライズ契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract への追記または新規 spec として、HTML / CSS 保存規則と roundtrip 保証を明文化する。
   - 完了条件: app / `ogkiln` / MCP が同じ保存規則を参照できる仕様になっている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. SER-003: roundtrip テスト整備の実装 TODO を起票する
   - 人間判断: 不要
   - 内容: 無編集 roundtrip と部分編集 diff 最小性の Swift Testing を整備する実装 TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [Agent Interface Batch Editing TODO](../Other/AgentInterfaceBatchEditing.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
