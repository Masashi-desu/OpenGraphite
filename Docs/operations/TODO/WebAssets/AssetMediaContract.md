# Asset Media Contract TODO

作成日: 2026-07-06
更新日: 2026-08-09
分類: WebAssets
状態: Active

## 目的

標準 `img` / `picture` / `video` と CSS background から media capability を判定できる一方、画像・メディアのバイナリがリポジトリへ入る規則（取り込み先、命名、重複）、参照形式、`srcset`、companion CSS の背景画像の扱いが未定義。asset 契約を確定し、spec 化する。

## スコープ

- 対象: 画像 / 動画 asset の取り込み先ディレクトリと命名規則、`src` の参照形式、`srcset` / `sizes` / `poster` の編集範囲、companion CSS の `background-image: url()` の扱い、drag & drop / CLI からの取り込み操作。
- 対象外: `alt` などアクセシビリティ属性の意味論（[AccessibilitySemanticsContract TODO](AccessibilitySemanticsContract.md)）、icon（Icon Source Contract として契約済み）、画像最適化・変換パイプライン（将来判断）。

## 人間側の意思決定

- 全体: 必要 - 取り込み先と初期編集スコープを確定する。

## 草案（判断材料）

- 取り込み先: htmlRoot 配下の `assets/`（例: `public/assets/`）を既定とする。`.ogp` に assetsRoot を持たせるかは Project Metadata Principle（管理情報のみ）の範囲内で判断する。
- 参照: `src` / `url()` は HTML / CSS が単独表示できる標準 URL として保持する。相対 URL は source file の位置を基準に解決し、root-relative URL は project root / htmlRoot との関係を仕様化する。解決結果が project root / htmlRoot の許可範囲を外れる絶対パス・ユーザー固有パスは validation error（Design Constraints 準拠）。
- 命名 / 重複: 同名 file の取り込み時は hash suffix 付与か確認ダイアログか。取り込みは copy であり、元ファイルへの参照を正本に残さない。
- 編集スコープ: 初期は `src` + サイズ（companion CSS の `width` / `height` / `object-fit`）に限定し、`srcset` / `sizes` / `video` / `poster` は第二段階とする案。
- 背景画像: companion CSS の `background-image: url(相対path)` を編集対象 declaration に含めるか。
- 未参照 asset の検出（unused-asset warning）を diagnostics に含めるか。

## 直列タスク

1. AST-001: 取り込み先と初期スコープを確定する
   - 人間判断: 必要 - 既定取り込み先、命名・重複規則、初期編集スコープ（srcset / 背景画像を含めるか）を決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 取り込み規則と編集スコープの決定が記録されている。
   - 確認方法: 文書確認。
2. AST-002: asset 契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract / AgentInterface / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ asset 取り込み・参照・validation を反映する。`ogkiln build` の asset copy 規則（[RuntimeBuildContract TODO](RuntimeBuildContract.md)）と整合させる。
   - 完了条件: 取り込み先・参照形式・診断 code が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. AST-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: drag & drop 取り込み / Inspector / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [AccessibilitySemanticsContract TODO](AccessibilitySemanticsContract.md)
- [RuntimeBuildContract TODO](RuntimeBuildContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
