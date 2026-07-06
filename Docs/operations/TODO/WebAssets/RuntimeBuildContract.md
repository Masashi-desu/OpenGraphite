# Runtime Build Contract TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: WebAssets
状態: Active

## 目的

DesignPhilosophy は「Web 標準 source files から決定的に生成される配布形態」を掲げるが、`OpenGraphite.runtime.js` の展開挙動と `ogkiln build` の出力契約・決定性保証は README の断片記述のみで spec がない。runtime / build の契約を確定し、spec 化する。

## スコープ

- 対象: `OpenGraphite.runtime.js` の `<og-instance>` 展開契約（順序、入れ子、失敗時挙動、冪等性）、`ogkiln build` の出力契約（含める / 除外する資産、書き換え規則、決定性保証）、contract version と runtime の互換表明。
- 対象外: 実装側 runtime（i18n runtime 等。Text Binding Contract の範囲）、hosting・デプロイ手順。

## 人間側の意思決定

- 全体: 必要 - 決定性保証の範囲と build 出力の除外規則を確定する。

## 草案（判断材料）

- runtime 展開: document order で展開し、入れ子 master の深さ制限と循環参照検出を定義する。失敗時は `data-og-component-error`（既存 runtime-only 属性）で理由を表示する。展開は冪等で、再実行しても DOM が増殖しない。
- build 出力: component source HTML と placement host は公開 page として出力せず、runtime / component source link の除去（README 記載）を正式契約にする。component companion CSS と component が参照する asset は、page が展開後 DOM を描画するために必要な静的資源として copy / link 書き換え対象に含める。asset copy 規則は [AssetMediaContract TODO](AssetMediaContract.md) と整合させる。locale JSON は成果物に含める。
- 決定性: 同一入力から byte 一致の出力を保証する。タイムスタンプ・環境依存値を出力へ混入させない。検証は build を 2 回実行して比較する。
- 互換表明: `OpenGraphite.contract.json` の version と runtime / build の対応（どの契約 version の HTML を処理できるか）を宣言する。

## 直列タスク

1. RBC-001: 決定性保証の範囲と除外規則を確定する
   - 人間判断: 必要 - byte 一致保証の採否、build 出力に含める / 除外する資産の一覧、入れ子展開の深さ制限を決める。blocking decision。
   - 内容: 現行 runtime / build の挙動を棚卸しし、草案を確定して本文書へ反映する。
   - 完了条件: 保証範囲と出力規則の決定が記録されている。
   - 確認方法: 文書確認。
2. RBC-002: runtime / build 契約を spec 化する
   - 人間判断: 不要
   - 内容: `Docs/specs/` に runtime / build の契約を新規作成または AgentInterface へ統合し、README の断片記述を spec 参照へ置き換える。
   - 完了条件: 展開規則・出力契約・決定性保証・互換表明が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. RBC-003: 決定性テストの実装 TODO を起票する
   - 人間判断: 不要
   - 内容: build 2 回実行の byte 比較、runtime 展開の冪等性・循環検出の自動テストを整備する実装 TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [AssetMediaContract TODO](AssetMediaContract.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
