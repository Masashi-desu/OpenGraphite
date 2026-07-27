# OpenGraphite Canvas Aids Specification

この文書は、OpenGraphite.app のキャンバスに表示する Ruler、Guide、Grid の仕様です。3機能はデザイン成果物ではなく editor preview 補助として扱い、Guide の配置だけを共有可能な project metadata として `.ogp` に保存します。

## Scope

- Ruler: 有効なキャンバス領域の上端と左端へ固定表示する目盛り。
- Guide: 上または左の Ruler からキャンバスへドラッグして配置する補助線。
- Grid: キャンバス背景全体へ表示する格子。

これらは Normal / Flow キャンバスで使用します。単一 object または page card を表示する Focus preview には表示しません。

## Ownership And Persistence

Ruler、Guide、Grid の表示可否は OpenGraphite.app の `UserDefaults` に保存します。Guide の方向と位置は `.ogp` に保存します。HTML、companion CSS、`OpenGraphite.css`、locale resource、runtime script、build 出力には保存しません。

表示設定の key と既定値は次の通りです。

| Key | 対象 | 既定値 |
| --- | --- | --- |
| `canvas.display.showsRulers` | Ruler | `true` |
| `canvas.display.showsGuides` | Guide | `true` |
| `canvas.display.showsGrid` | Grid | `false` |

Guide は Pages では `chapters[].guides[]`、Components では `collections[].guides[]` に保存します。同じ project 内でも別 Chapter / Collection の Guide は共有しません。各要素は次の値を持ちます。

| Field | 内容 |
| --- | --- |
| `internalID` | `.ogp` 内で Guide を一意に指す不透明 ID |
| `orientation` | `vertical` または `horizontal` |
| `position` | 垂直 Guide の X または水平 Guide の Y world 座標 |

空の `guides[]` は JSON から省略し、`guides` key がない旧 `.ogp` は空配列として読み込みます。project file を移動・共有した場合も Guide は `.ogp` と一緒に移送され、外部 manifest 更新も app の project monitor から再読込されます。

CLI / MCP の project summary は Chapter / Collection ごとの `guideCount` を返します。個別 Guide の typed reference、canvas screenshot、page screenshot、node screenshot、standalone browser、static build の対象にはしません。

## Coordinates

Guide の `position` は page / component の `canvas.x` / `canvas.y` と同じ左上原点の world 座標です。垂直 Guide は X、水平 Guide は Y を保持します。表示時は次を考慮して viewport 座標へ変換します。

- 外側 `NSScrollView` の visible origin。
- 無限キャンバスが追加した hosting view の leading / top margin。
- SwiftUI content の固定 document padding。
- 現在の Canvas Zoom。
- page / annotation 群から解決した canvas content origin。
- page 情報カードを page 本体の上へ描画するための visual offset。`.ogp` の `canvas.x` / `canvas.y` は情報カードではなく page 本体左上を指す。
- AppKit scroll view 内の SwiftUI hosting view は window の safe area を再適用しない。hosting view の実座標原点と canvas content 左上を一致させる。

Ruler の数値、Grid、Guide は同じ変換器と world origin を使います。Scroll、Zoom、page / annotation 移動によって content bounds の原点が変わっても、同じ world 座標を表示し続けます。
上 Ruler の数値は水平中心、左 Ruler の数値は垂直中心を対応する大目盛り座標へ揃え、ラベル用の固定オフセットで座標位置をずらしません。

## Ruler And Grid Density

Ruler と Grid は同じ小目盛りと大目盛りを使います。小目盛りは 10 / 20 / 50 / 100 / 200 / 500 / 1000 以降の候補から、画面上で原則 8pt 以上の間隔になる最小値を選びます。大目盛りは通常小目盛り 5 本ごととし、10px 小目盛りでは 100px ごとに数値を表示します。

Grid は WebView card より背面に描画します。Guide は位置合わせ対象を横断して確認できるよう card より前面に描画します。Ruler は Sidebar、Inspector、上部 window chrome を避けて固定し、canvas scroll には参加しません。

## Interaction

- 上 Ruler からドラッグすると垂直 Guide を作成します。
- 左 Ruler からドラッグすると水平 Guide を作成します。
- 上 Ruler のコンテキストメニューから「ここに垂直ガイドを追加」、左 Ruler から「ここに水平ガイドを追加」を選ぶと、右クリックした目盛りの world 座標へ Guide を作成します。
- 配置済み Guide と Ruler の接点には、垂直 Guide で下向き、水平 Guide で右向きの小さな三角マーカーを表示します。
- Guide はドラッグで同じ方向の world 座標へ移動できます。
- Guide または三角マーカーのコンテキストメニューから「位置を変更…」を選ぶと、現在位置を初期値にした数値入力で垂直 Guide の X または水平 Guide の Y world 座標を直接変更できます。空文字、数値以外、非有限値は確定できません。
- Guide を対応する Ruler 側へ戻すか、コンテキストメニューの「ガイドを削除」で削除できます。
- 三角マーカーは Guide 本体と同じドラッグ移動、Ruler 戻し削除、右クリックコンテキストメニューを提供します。
- Settings の「ガイドを表示」が無効な間は Guide を描画せず、Ruler から新規作成もしません。保存済み Guide 位置は保持します。
- Ruler、Guide、Grid の表示切替は独立しています。

Guide の追加、移動、削除は最新 `.ogp` を再読込して対象 Chapter / Collection の `guides[]` だけへ atomic write し、「取り消す」`⌘Z` と「やり直す」`⇧⌘Z` の対象にします。Ruler からの追加、1回のドラッグ移動または数値入力による位置変更、Ruler 戻しまたはコンテキストメニューによる削除を、それぞれ1履歴単位として記録します。

Guide 履歴は project URL、対象 Chapter / Collection、変更前後の `guides[]` を保持し、HTML編集・キャンバス注釈と同じ統合時系列へ積みます。Undo / Redo 直前に最新 `.ogp` を再読込し、対象 `guides[]` が履歴の期待値と一致する場合だけ履歴値へ差し替えて atomic write します。同じ配列が外部変更されている場合は古い履歴で上書きせず、最新 manifest を表示へ同期して統合履歴を破棄します。別の Chapter / Collection、注釈、page / component metadata、HTML、CSS は巻き戻しません。

## Verification

- 座標変換は viewport → world → viewport の往復で一致すること。
- Zoom ごとの目盛り間隔が過密にならないこと。
- Sidebar / Inspector / window chrome / Ruler の回避矩形が一致すること。
- Guide の追加・更新・削除が選択中 Chapter / Collection の `.ogp` `guides[]` だけへ反映されること。
- Ruler のコンテキストメニューから右クリックした目盛り位置へ Guide を追加できること。
- Guide のコンテキストメニューから現在位置を直接入力でき、不正値を確定できないこと。
- Guide の追加・移動・削除を1操作ずつ Undo / Redo でき、HTML・注釈と同じ確定順で統合履歴が進むこと。
- 履歴対象の `guides[]` が外部変更されていた場合は、古い履歴を適用せず最新値を保持すること。
- Guide を保存しても HTML と CSS が更新されないこと。
- app または別環境で同じ `.ogp` を開いて Guide が復元されること。
