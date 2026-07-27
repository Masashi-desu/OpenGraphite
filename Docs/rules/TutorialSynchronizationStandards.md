# チュートリアル同期規約

本規約は、OpenGraphite の機能追加・改修・削除と、`SampleProject/OpenGraphiteSample.ogp` の `Tutorials` Chapter / Collection に置く教材を同じ変更単位で同期するための基準を定めます。

## 適用対象

次のいずれかを変える場合は、実装着手時にチュートリアルへの影響を確認し、完了前に同期します。

- OpenGraphite.app でユーザーが操作または確認できる機能、導線、状態、表示。
- HTML / CSS / component / runtime / `.ogp` の authoring contract。
- Canvas、Layers、Inspector、Sidebar、Project、preview、Undo / Redo のワークフロー。
- CLI / MCP から変更し、OpenGraphite.app または Sample Project で結果を確認できる操作。
- 既存チュートリアルが説明している機能の名称、手順、制約、保存先、表示結果。

内部リファクタリング、性能改善、テスト整理など、利用者が観察できる挙動や操作契約を変えない変更は教材本文の更新対象外です。ただし、既存チュートリアルが変更後も正しいことを確認します。

## 必須ルール

1. ユーザーが観察できる機能を追加・改修・削除した変更は、対応するチュートリアルを同期するまで完了としません。
2. 既存教材で自然に説明できる場合は、その教材を更新します。独立した操作目的またはワークフローが増える場合は、新しい教材を追加します。
3. 機能削除、名称変更、導線変更では、古い手順や表示を教材へ残しません。不要になった教材資源と `.ogp` 登録も同じ変更で整理します。
4. 実装、テスト、仕様、チュートリアル、Sample `.ogp`、skill、検証入口を理由なく別コミットへ分断しません。
5. チュートリアルを更新しない判断が許されるのは、利用者が観察できる挙動を変えない場合だけです。変更完了時に、その判断理由と確認した既存教材を説明できる状態にします。

## 正本と更新先

| 変更対象 | 同期先 |
| --- | --- |
| Pages の操作・Canvasワークフロー | `public/tutorial-*.html`、同名 companion CSS、Sample `.ogp` の `Tutorials` Chapter |
| Components、master、slot、placement | `public/_components/tutorial-components-*.html`、同名 companion CSS、Sample `.ogp` の `Tutorials` Collection |
| 付箋・手書き | 教材HTML/CSSに説明を置き、実物例は `chapters[].annotations[]` または `collections[].annotations[]` |
| Ruler・Guide・Grid | 教材HTML/CSSに説明を置き、Guideの実物例だけを `guides[]` に置く。表示設定は `.ogp` へ固定しない |
| preview mock・placement mock | 教材の対象canvasに必要な `previewContext` をSample `.ogp`へ置く |
| HTML / CSS authoring contract | 対象ノードを選択・編集できる教材HTMLと同名CSSを更新する |

HTML、CSS、component master、annotation、Guide、preview metadataの責務境界は `Docs/specs/SourceOfTruthContract.md` を優先します。付箋・手書き・Guideを教材DOMへ複製して別正本を作りません。

## 同期手順

1. 変更する機能が、既存のどの教材と利用者ワークフローに対応するかを特定します。
2. 既存教材の更新または新規教材の追加を選びます。似た教材を重複して増やしません。
3. 教材の手順、文言、状態、保存先、制約を実装後の挙動へ合わせます。
4. 必要なHTML、同名CSS、component master、annotation、Guide、preview metadataを責務別の正本へ保存します。
5. `SampleProject/OpenGraphiteSample.ogp` の `Tutorials` Chapter / Collectionへ教材を登録・配置します。
6. 変更した教材をOpenGraphiteまたは非侵襲スクリーンショットで確認し、操作対象、文字切れ、重なり、annotation位置を確認します。
7. `./Scripts/validate_tutorial_sync.sh` と `./Scripts/quality_gate.sh` を完走します。

## 完了条件

- 新機能または変更後のワークフローを、対応教材だけで再現できます。
- 古い名称、導線、制約、保存先、表示結果が教材に残っていません。
- 教材HTMLと同名CSS、Sample `.ogp` 登録、必要なannotation / Guide / mockが揃っています。
- 公開HTML / CSSへeditor-only metadataを混ぜていません。
- チュートリアルを更新しなかった場合は、利用者が観察できる変更ではないことと、確認した既存教材を説明できます。
- 品質ゲートが成功しています。
