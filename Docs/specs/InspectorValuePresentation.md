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

## Capability-Gated Sections

Inspector sectionは保存済みの単一node typeではなく、選択nodeのoperation capabilityで表示可否を決めます。標準tag、native control、ARIA、direct text、children、media / SVG / mask実体、resolved `display`などから共有Coreが算出したraw value昇順の`drag-position`、`edit-control`、`edit-icon`、`edit-layout`、`edit-link`、`edit-media`、`edit-text`、`group`、`receive-children`、`reorder-flow`、`ungroup`を使います。同じnodeに複数sectionが同時に現れ得ます。

child insertion / receptionは`receive-children`、text / link / media / icon / native control sectionは対応する`edit-*`、layout sectionは`edit-layout`、Canvas dragは`drag-position`、flow reorderは`reorder-flow`、group commandは`group` / `ungroup`をそれぞれ要求します。App独自のtype switchやfallback enumは持ちません。

Agent payloadの`capabilityEvidence`はUI判断の根拠を説明するために保持し、pre-migration `0.1.0` sourceの旧`data-og-type`値はcompatibility readerがoptional `legacyTypeHint`としてだけ表示できます。legacy hintの欠落や値をsection gate、挿入markup、描画defaultに使わず、通常のopenやInspector操作で削除・変換しません。標準sourceへの変換はproject migrationの明示dry-run / applyだけが担います。未知の標準HTMLとCustom Elementはevidenceのあるsectionだけを受け取り、曖昧な単一分類へ強制しません。

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

- アイコン: `text-align`、実体 `img` / `video` の `object-fit`、`background` の種別、resolved `display` / `flex-direction` に応じた整列の各軸。
- 文字: `position`、寸法値の入力方式（unset / length / keyword / function）。

アイコンセグメントは選択中の項目を再度押すと未設定へ戻せます。未設定は継承や既定値へ戻す操作として扱います。

## Media And Icon Targets

media / icon wrapper を選択しても、Inspector の描画 property は DOM relation から求めた実体 element を対象にします。`object-fit` は descendant `img` / `video`、`stroke-width` は inline `svg` または SVG descendant、`mask-image` / `-webkit-mask-image` は mask child の authored declaration と computed style を表示します。wrapper 自身の `width` / `height` / `color` と、child の描画 property は別行・別 provenance として扱います。

書き戻しは CSS source trace が指す selector と declaration を使います。direct inline / companion winnerは既存declarationを最小差分更新し、read-only project / linked / embedded winnerへのsetはactive media scopeとpriorityを保つ安全なcompanion overrideに限定します。安全なspecificityを構成できない場合は `css-specificity-override-unsafe`、winner再評価が要求値にならない場合は `css-mutation-postcondition-failed` でno-writeにします。read-only winnerだけのremoveは `read-only-css-winner`、longhandがshorthandから解決されているremoveは `shorthand-css-removal-unsupported` になり、元sourceや他subpropertyを変更しません。computed value を wrapper の新規 custom propertyへ複製しません。icon の library / name / source metadata は再取得用 provenance であり、値入力 UI の描画 switch にはしません。

## Authored And Computed CSS

Inspector の authored source はproject library、companion CSS、local linked stylesheet、embedded `<style>`、inline `style`を別sourceとして追跡します。source candidateのidentity/kind/editability/orderはAgent graphの `sourceID` / `sourceKind` / `sourceEditable` / `stylesheetOrder` / `sourceOrder` / `inherited` に従います。AppがWebKitから取得する `computedStyle` は現在viewportと実runtimeの表示結果であり、authored valueや書き戻し先へ逆算しません。

Sharedのheadless値は全stylesheet candidateと親の継承値を合成した後にcustom property / `var()`を一度だけ解決します。`var()`を含む対応shorthandはraw shorthand provenanceを維持し、最終置換後にlonghand componentを解決するため、Inspectorはcomputed componentを別declarationへ暗黙コピーしません。CSS-wide単一identifierのescapeはsemanticに復号しますが、authored spellingは表示・保存用traceに保持します。

Context section はcomputed `display` / `position` / `visibility` / `content-visibility` と、ancestor状態を含む現在の `rendered` hidden判定を表示します。Layersのdetail lineもcomputed layout、非`static`のcomputed position、rendered hiddenを表示します。標準 `hidden` attribute のsource有無はInspectorの別行で表示し、computed hidden状態からHTML attributeを追加・削除しません。

WebKitが読み取れないstylesheet、またはSharedが未解決`@import`、malformed CSS、未対応layer/property/selectorを検出した場合はsource-wide incompleteとなり、warning `incomplete-css-provenance` と各nodeの `hasIncompleteCSSProvenance: true` を返します。matching `@supports` / `@container` / `@scope`等の未評価conditional、keyframes sourceとactive animation指定、headlessで確定できないCSS-wide値は、該当node/targetだけをnode-level incompleteにします。`@keyframes`定義だけではsource-wide incompleteにせず、pageの集約flagが`true`でも完全な別nodeまでread-onlyとは扱いません。

`revert` / `revert-layer`は同じauthor origin内の前candidateへ戻さず、継承propertyでは親computed値を表示し、非継承propertyではauthor値を除いてUA fallbackへ委ねたうえで該当propertyをread-onlyにします。Sharedの対応CSS値grammarはkeywordだけでなくgeometry、標準unit、typed math、grid track、数値propertyも検証します。無効・未対応なauthored sourceはraw表示を保ったままnode-level incompleteにし、明示した無効値、top-level `;`による別declaration、またはtop-level `!important`のvalue注入は`invalid-css-property-value`でatomicに書込前拒否します。構文上有効な`env()` / `anchor()` / `anchor-size()`はraw authored valueを表示しますが、headlessで安全なresolved winnerを確定できないため該当CSS controlをread-onlyにします。`hidden="until-found"`のheadless fallbackは`content-visibility:hidden`ですが、authored `initial` / `unset` / `visible`はresolved `visible`として表示し、標準`hidden` source intentは変更しません。

不完全な対象もcomputed値と既知authored candidateは表示しますが、該当node/targetのInspector CSS set/remove、複数node CSS編集、Canvas layout CSS操作はread-onlyにし、source bytesを変更しません。Shared mutation routeへ到達した場合も `incomplete-css-provenance-write-blocked` でatomic no-writeになり、node-level guardでは `incomplete-css-node-provenance` も返します。標準`hidden`等のCSS provenanceに依存しないattribute編集は別経路のため維持します。

## Transform Composition

Effects section は標準 CSS の `scale`（2軸値）と `transform-origin` を編集対象として扱います。水平 flip は `scale: -1 1`、垂直 flip は `scale: 1 -1` を保存します。`scale` の編集は source trace が指す `scale` declaration だけを更新し、source に既にある独立した `rotate` や `transform` を書き換えません。この移行では `rotate` / `transform` の専用 Inspector control を追加しません。WebKit computed value は現在の描画結果、authored value は書き戻し元として分離します。

drag の individual `translate` と reorder の Web Animations API による補間は session-only preview です。これらは authored transform value として Inspector に取り込まず、無編集保存や操作終了で source に残しません。

## Alignment Axes

`align-items` と `justify-content` は、resolved `display` / `flex-direction` によって主軸と交差軸が入れ替わります。Inspector は単一の独自layout enumをsourceに要求せず、CSS source traceとWebKit computed styleからoperation capabilityを決めます。

- `vertical`（`flex-direction: column`）: `justify-content` が縦、`align-items` が横。
- `horizontal`（`flex-direction: row`）: `justify-content` が横、`align-items` が縦。
- `grid`: grid alignment と track propertyを表示し、flex方向controlは出さない。
- `block` / `inline` / table display: flex整列は描画へ反映されないため、その旨を注記する。
- positioned child: 親modeではなくchild自身の`position` / insetをPosition sectionで編集する。

未指定の軸は、CSS cascadeとUA defaultから得たcomputed値を「計算値: …」として軸ラベル横に表示します。セグメント側は未選択のままにし、明示したauthored declarationとcomputed defaultを取り違えないようにします。responsive ruleは現在activeなmedia scopeの結果を表示し、書き戻しでは勝者のat-rule provenanceを保持します。

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
