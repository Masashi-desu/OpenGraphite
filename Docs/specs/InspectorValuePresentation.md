# Inspector Value Presentation

この文書は、Inspector（右カラム）の値編集 UI が、編集対象の意味をどこまで見せ、どこから先をプレビュー（Canvas）へ委ねるかを定義します。表示階層（section カード、CSS property 名、依存性カード）は [InspectorDependencyUI.md](InspectorDependencyUI.md) の構造をそのまま維持し、各 property の値をどう見せて、どう入力させるかだけを扱います。

## Responsibility Boundary

編集操作面の責務は、Canvas と Inspector で分けます。

| 面 | 責務 |
| --- | --- |
| プレビュー（Canvas） | 対象そのものを掴んで動かす直接操作。選択枠、ハンドル、ドラッグによる配置とサイズ変更。 |
| Inspector（右カラム） | 値の一覧、値の意味の説明、値の入力。 |

Inspector には、編集対象を模した操作可能な面を置きません。具体的には、要素や包含ブロックを表す枠を描いてその上をクリック・ドラッグさせる UI（ボックスモデル図、整列パッド、XY パッド、角度ダイヤルなど）を作りません。同じ操作が Canvas 側にも存在するため、どちらが正しい操作面なのかが曖昧になり、選択枠との見分けもつかなくなるためです。

Inspector の図は **読み取り専用の見本** に限ります。見本は「いま何を編集していて、その値がどう効くか」を伝えるためだけに置き、`allowsHitTesting(false)` で操作を受けません。

## Width and Overflow

Inspector の幅は `InspectorLayoutMetrics.resolvedWidth(availableWindowWidth:leadingColumnWidth:)` が決めます。

- 左カラムを除いた残り幅の `maximumRemainingWidthFraction` を基準にする。
- ただし `minimumWidth` を下回らない。ウインドウ最小幅（960）で左カラム（296）を表示していても、入力欄が見切れない幅を確保するため。
- `preferredWidth` を上限とし、残り幅そのものを超えない。

カラム内のコントロールは、この幅の範囲で見切れないことを前提に組みます。

- 固定幅を持つのはアイコンボタンなど、内容が幅に依存しない要素だけにする。Picker やラベルは `minWidth` / `maxWidth` の範囲で指定し、幅が足りないときは縮む余地を残す。
- 単位選択は入力欄の外に別コントロールとして並べず、入力欄の内側に文字だけの小型メニュー（`CSSInlineUnitMenu`)として置く。外付けの Picker は狭い列で入力欄の表示幅を奪い、値が読めなくなるため。
- 四辺・四隅のような 4 値指定は、横に並べず 1 値 1 行の全幅で並べる。連動切り替えと現在値の要約は property 見出しの行に置く。
- 幅が足りない可能性のあるラベルには `lineLimit(1)` と `minimumScaleFactor` を付け、`clipped()` で隠して済ませない。

## Input Controls

Inspector が使う入力手段は次の 3 つに限定します。

1. **ラベル付きテキスト入力**: CSS 値をそのまま扱う既定の手段。左側アイコンが対象（辺、隅、軸、色など）を示す。
2. **セグメント選択**: 列挙値を等幅セグメントで切り替える。図で意味が伝わる値はアイコン、語で区別する値は文字。
3. **数値スクラブ**: 入力欄の左アイコンを左右ドラッグして数値だけを増減する。

数値スクラブは入力欄そのものに付く補助操作であり、編集対象を模した面ではないため、この境界の例外にはあたりません。

### Numeric Scrubbing

- ドラッグ距離 `InspectorValueScrubber.defaultPointsPerStep`（3pt）ごとに 1 段階変化する。
- 修飾キーで粒度が変わる。shift で 10 倍、option で 1/10。
- 単位はドラッグ前の値から引き継ぐ。未設定の場合だけ `InspectorScrubProfile.fallbackUnit` を補う。
- `calc()` や keyword など数値として解釈できない値はドラッグ対象外とし、値を書き換えない。
- 粒度、補完単位、負値許可は `InspectorScrubProfile.forCSSKey(_:)` が CSS property 名から決める。
- ドラッグ中は UI 状態だけを更新し、確定は操作終了時に 1 回だけ行う。書き戻しと undo 履歴が操作単位と一致する。

## Read-only Previews

| 対象 | 見本 |
| --- | --- |
| `border-radius` | 4 隅の指定どおりに丸めた小さな矩形。 |
| `border` | 幅・線種・色をそのまま引いた 1 本の線。 |
| `background`（gradient） | 停止位置の目印を持つグラデーション帯。 |
| `box-shadow` | 影を適用した小さなカード。`inset` も反映する。 |
| Typography | `font-family` / `font-size` / `font-weight` / `line-height` / `letter-spacing` / `text-align` を反映した文字見本。 |

`InspectorValuePreviewGeometry` が、CSS 値から見本の表示寸法を求めます。角丸は `%` 指定を辺長基準、長さ指定を `cornerReferenceValue` 基準で換算し、いずれも矩形の半分を超えないよう丸めます。

## Option Controls

結果を図で示せる列挙値はアイコンセグメント（`InspectorGlyphOptionStrip`）、語で区別する列挙値は折り返し文字セグメント（`InspectorSegmentedTextControl`）を使います。

- アイコン: `text-align`、`--og-object-fit`、`background` の種別、整列の各軸、`data-og-layout`。
- 文字: `position`、寸法値の入力方式（unset / length / keyword / function）。

アイコンセグメントは選択中の項目を再度押すと未設定へ戻せます。未設定は継承や既定値へ戻す操作として扱います。

## Alignment Axes

`align-items` と `justify-content` は、`data-og-layout` の方向によって主軸と交差軸が入れ替わります。`InspectorAlignmentModel` がこの入れ替えを一元的に扱い、`InspectorAlignmentAxisOptions` が方向に合ったアイコンの選択肢を返します。

- `vertical`（`flex-direction: column`）: `justify-content` が縦、`align-items` が横。
- `horizontal`（`flex-direction: row`）: `justify-content` が横、`align-items` が縦。
- `absolute`（`display: block`）: flex 整列は描画へ反映されないため、その旨を注記する。

未指定の軸は、`OpenGraphite.css` の既定値（`vertical` は `stretch` / `flex-start`、`horizontal` は `center` / `flex-start`）を「既定: …」として軸ラベル横に表示します。セグメント側は未選択のままにし、明示指定と既定値を取り違えないようにします。

## Directory Responsibilities

```text
App/Sources/Presentation/Inspector/Controls/
├── InspectorValueScrubber.swift      # 数値ドラッグ編集の計算とハンドル
├── InspectorGeometryPreviews.swift   # 角丸の読み取り専用見本と表示寸法計算
├── InspectorAlignmentControls.swift  # 整列軸ストリップ、レイアウトアイコン
├── InspectorValuePreviews.swift      # 影・グラデーション・字組みの読み取り専用見本
└── InspectorOptionControls.swift     # アイコン選択と折り返しセグメント
```

`Controls/` には、特定 section に依存しない汎用の入力手段と見本だけを置きます。どの CSS property にどれを割り当てるかは、従来どおり `InspectorCSSControlViews.swift` と `InspectorView.swift` が決めます。

## Verification

- `Tests/OpenGraphiteTests/Presentation/InspectorValueScrubber_test.swift`
- `Tests/OpenGraphiteTests/Presentation/InspectorAlignmentModel_test.swift`
- `Tests/OpenGraphiteTests/Presentation/InspectorLayoutMetrics_test.swift`
- `Tests/OpenGraphiteTests/Presentation/InspectorValuePreviews_test.swift`
