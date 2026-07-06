# Standard CSS Second Candidates TODO

作成日: 2026-06-18
更新日: 2026-06-18
分類: WebAssets
状態: Active

## 目的

OpenGraphite 固有 CSS custom property のうち、標準 CSS property へ寄せられる可能性があるが写像や編集モデルの判断が残るものを、互換性前提なしで順に移行できる状態にする。

## スコープ

- 対象: `--og-scale-x` / `--og-scale-y`、`--og-object-fit`、`--og-stroke-width` の標準 CSS 化。
- 対象外: `data-og-*` による構造参照、component instance 参照、runtime-only helper、locale font custom property、icon URL helper。

## 人間側の意思決定

- 全体: 必要 - 標準 CSS property へ写したときに、Inspector 表現、DOM 反映、runtime preview、静的 build のどれを正本 semantics として優先するかを候補ごとに決める。

## 直列タスク

1. CSS-STANDARD-SECOND-002: scale helper の標準 CSS 化
   - 人間判断: 必要 - `--og-scale-x` / `--og-scale-y` を CSS `scale` property へ写すか、既存 `transform` 合成の一部として扱うかを決める。
   - 内容: flip / reorder / drag animation が依存する scale helper と、永続化される design value を分離または統合する。
   - 完了条件: ユーザー編集の scale と runtime animation の一時 transform が衝突せず、永続値が標準 CSS として保存される。
   - 確認方法: `./Scripts/quality_gate.sh`、flip 操作、reorder animation、sample project の preview 確認。

2. CSS-STANDARD-SECOND-003: media と icon helper の標準 CSS 化
   - 人間判断: 必要 - `--og-object-fit` を親 node の `object-fit` に置くか子 media selector に置くか、`--og-stroke-width` を SVG `stroke-width` と CSS cascade のどちらで扱うかを決める。
   - 内容: image / icon の描画実体と編集対象 node の境界を保ったまま、保存先を標準 CSS property へ移す。
   - 完了条件: image object-fit、Lucide icon stroke width、CDN icon mask の表示が標準 CSS property から再現され、agent graph と Inspector が同じ値を扱う。
   - 確認方法: `./Scripts/quality_gate.sh`、image node と icon node の Inspector 操作、browser preview、OpenGraphite.app の UI 確認。

## 参照

- [SourceOfTruthContract.md](../../../specs/SourceOfTruthContract.md)
- [DesignPhilosophy.md](../../../specs/DesignPhilosophy.md)
- [OpenGraphite.css](../../../../CSS/OpenGraphite.css)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
