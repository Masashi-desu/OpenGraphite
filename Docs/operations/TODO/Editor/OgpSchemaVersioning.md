# Ogp Schema Versioning TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Editor
状態: Active

## 目的

`.ogp` は `schemaVersion: "0.1"` を持つが、フィールドの正本定義、未知キーの扱い、互換・migration 方針が仕様として存在せず、旧形式互換規則（`locale` / `direction` → `fieldMocks` など）が各文書に散在している。`.ogp` 最小主義（Project Metadata Principle)を守る根拠となるスキーマ仕様を確定する。

## スコープ

- 対象: `.ogp` の全フィールド定義（型、必須 / 任意、editor-only 区分）、schemaVersion の互換方針、未知キー保持、旧形式 decode 互換の一覧化、`htmlRoot` / `cssLibrary` など相対パス解決規則の正式化。
- 対象外: `.ogp` への新フィールド追加そのもの（各機能 TODO の範囲）、JSON 整形規則の詳細（[HtmlCssSerializationStability TODO](HtmlCssSerializationStability.md) と同じ原則を適用）。

## 人間側の意思決定

- 全体: 必要 - 未知キーの保持方針と、上位 schemaVersion を開いたときの挙動を確定する。

## 草案（判断材料）

- スキーマ表: fields、型、必須 / 任意、「editor preview 専用」区分を一覧化し、Project Metadata Principle との対応を明示する。
- 未知キー: 保存時に保持（forward compatibility、他ツール拡張を壊さない）か、破棄（最小主義の強制）か。
- schemaVersion 方針: minor 追加は後方互換読み込み、未知 major は read-only で開く / 拒否する、のいずれか。
- 旧形式 decode 互換: 現存する互換規則を一覧化し、削除条件（バージョン / 期日）を付ける。
- パス解決: 相対参照が正本、絶対パスは実行時解決という原則を解決アルゴリズムとして明文化する。

## 直列タスク

1. OGS-001: スキーマ互換方針を確定する
   - 人間判断: 必要 - 未知キー保持の可否、上位 version の open 挙動、旧形式互換の削除条件を決める。blocking decision。
   - 内容: 現行の encode / decode 実装から実効スキーマを棚卸しし、草案の選択肢を比較して決定を本文書へ反映する。
   - 完了条件: 互換方針の決定と実効スキーマ一覧が記録されている。
   - 確認方法: 文書確認。
2. OGS-002: `.ogp` スキーマを spec 化する
   - 人間判断: 不要
   - 内容: `Docs/specs/` に `.ogp` スキーマ仕様を新規作成し、SourceOfTruthContract / AgentInterface の Project Metadata 記述と整合させる。
   - 完了条件: `.ogp` の全フィールドと互換方針が単一文書で読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. OGS-003: decode 互換テストの実装 TODO を起票する
   - 人間判断: 不要
   - 内容: 旧形式 fixture の decode、未知キー roundtrip、上位 version 挙動の Swift Testing を整備する実装 TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [HtmlCssSerializationStability TODO](HtmlCssSerializationStability.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
