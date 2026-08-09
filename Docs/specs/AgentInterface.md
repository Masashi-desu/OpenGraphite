# OpenGraphite Agent Interface

OpenGraphite の AI 協業インターフェースは、リポジトリ上の HTML / companion CSS / `.ogp` を正本として扱う。AI、CLI、MCP は同じファイルを読み、同じ検証契約を通して、可能な限り node 単位の小さな編集操作として変更する。編集対象 HTML は必ず `.ogp` の `chapters[].pages[]` または `collections[].components[]` でユーザーが認知できる状態にしてから扱う。

参考にする先行事例は Pencil / OpenPencil だが、OpenGraphite は `.pen` の JSON IR ではなく HTML を編集対象にする。Pencil CLI は headless editor と interactive MCP tool shell を提供し、`batch_design` で insert / update / delete / move / copy / replace を扱う。OpenPencil も headless CLI、query、MCP server、export を同じ engine 上に置く。OpenGraphite ではこれを `ogkiln`、OpenGraphite MCP server、`OpenGraphiteHTMLDocument` core、`OpenGraphite.contract.json` の組み合わせへ読み替える。

- Pencil CLI: <https://docs.pencil.dev/for-developers/pencil-cli>
- Pencil `.pen` format: <https://docs.pencil.dev/for-developers/the-pen-format>
- OpenPencil repository: <https://github.com/open-pencil/open-pencil>

## Interface Roles

- `ogkiln`: 人間、CI、MCP server が同じ挙動を再現できる CLI。
- OpenGraphite MCP server: AI クライアントが構造化 resource / tool として OpenGraphite リポジトリを読むための stdio MCP server。
- `OpenGraphite.contract.json`: Web contract version `1.0.0`、source HTML に残せる optional `data-og-*`、編集対象 CSS 宣言、legacy migration input、operation capability の機械可読な契約。top-level `migrationPolicy` は `explicitOnly: true`、`dryRunRequired: true`、`supportedSourceVersions: ["0.1.0"]`、`targetVersion: "1.0.0"`、`legacyReaderRemovalConditions` を持つ。`capabilityPolicy` はraw value昇順の`operations`、`evidenceFields`、legacy reader用type hint、`generated: false`、`queryMatch: "all"`を持つ。runtime-private state は公開 contract に含めない。
- Design Tokens: `.ogp` の `cssLibrary` が指す CSS file の project-defined `:root` custom property。Project Inspector / CLI / MCP から一覧・依存関係を確認して編集でき、node の標準 CSS declaration から `var(--token)` として参照する。OpenGraphite は token 名や theme semantics を予約しない。
- OpenGraphite app: 正本ファイルを `WKWebView` に表示し、外部変更を検出して Canvas、Layers、Inspector へ同期する UI。

MCP の表向きの名前は OpenGraphite とする。`ogkiln` は CLI 名であり、MCP の write tool は `ogkiln` または同じ core 実装と同等の validation / diagnostics を必ず通す。

詳細仕様:

- [`OgkilnCLI.md`](OgkilnCLI.md): CLI command、JSON output、編集操作。
- [`OpenGraphiteMCP.md`](OpenGraphiteMCP.md): MCP resources / tools と `ogkiln` への対応。
- [`CanvasAnnotations.md`](CanvasAnnotations.md): `.ogp` 注釈の schema、座標、Sidecar、CLI/MCP、screenshot 契約。
- [`CanvasAids.md`](CanvasAids.md): `.ogp` Guide の schema、座標、表示設定、screenshot / build 除外契約。
- [`CanvasObjectReferences.md`](CanvasObjectReferences.md): `.ogp` 参照配置の schema、typed node 解決、トップレベル配置、編集同期契約。

## Project Summary

`ogkiln project inspect <project.ogp|current> --json` と MCP の project resource は次の構造を返す。

```json
{
  "schemaVersion": "0.1",
  "projectName": "OpenGraphite Sample",
  "projectURL": "/repo/SampleProject/OpenGraphiteSample.ogp",
  "rootURL": "/repo",
  "htmlRoot": "public",
  "cssURL": "/repo/CSS/OpenGraphite.css",
  "chapters": [
    {
      "id": "main",
      "internalID": "6q8zy7p2k1",
      "index": 0,
      "title": "Main",
      "isSidebarHidden": false,
      "annotationCount": 0,
      "guideCount": 0,
      "referenceCount": 0,
      "pages": [
        {
          "chapterID": "main",
          "chapterInternalID": "6q8zy7p2k1",
          "id": "home",
          "internalID": "d2t9n4x8ra",
          "referenceID": "ogref:page:6q8zy7p2k1:d2t9n4x8ra",
          "chapterIndex": 0,
          "pageIndex": 0,
          "path": "index.html",
          "htmlURL": "/repo/public/index.html",
          "isCanvasHidden": false,
          "canvas": {
            "name": "",
            "x": 0,
            "y": 0,
            "width": 1440,
            "height": 1200,
            "previewContext": {
              "fieldMocks": { "selectedLanguage": "ja" }
            }
          }
        }
      ]
    }
  ],
  "pages": [
    {
      "chapterID": "main",
      "chapterInternalID": "6q8zy7p2k1",
      "segment": "pages",
      "id": "home",
      "internalID": "d2t9n4x8ra",
      "referenceID": "ogref:page:6q8zy7p2k1:d2t9n4x8ra",
      "chapterIndex": 0,
      "pageIndex": 0,
      "path": "index.html",
      "htmlURL": "/repo/public/index.html",
      "isCanvasHidden": false,
      "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
    }
  ],
  "collections": [
    {
      "id": "main",
      "internalID": "component-main",
      "index": 0,
      "title": "Main",
      "annotationCount": 0,
      "guideCount": 0,
      "referenceCount": 0,
      "components": [
        {
          "collectionID": "main",
          "collectionInternalID": "component-main",
          "segment": "components",
          "id": "design-system",
          "internalID": "7m4wq0f5bc",
          "referenceID": "ogref:component:component-main:7m4wq0f5bc",
          "collectionIndex": 0,
          "pageIndex": 0,
          "path": "_components/design-system.html",
          "htmlURL": "/repo/public/_components/design-system.html",
          "canvas": {
            "name": "",
            "x": 1120,
            "y": 0,
            "width": 1180,
            "height": 1900,
            "previewContext": {
              "placementMocks": {
                "placement-code-internal": { "host.variant": "code" },
                "placement-preview-internal": { "host.variant": "preview" },
                "placement-loading-internal": {
                  "host.class": "is-loading",
                  "host.aria-busy": "true"
                },
                "placement-collapsed-internal": {
                  "host.variant": "collapsed",
                  "host.aria-expanded": "false"
                }
              }
            }
          }
        }
      ]
    }
  ],
  "components": [
    {
      "collectionID": "main",
      "collectionInternalID": "component-main",
      "segment": "components",
      "id": "design-system",
      "internalID": "7m4wq0f5bc",
      "referenceID": "ogref:component:component-main:7m4wq0f5bc",
      "collectionIndex": 0,
      "pageIndex": 0,
      "path": "_components/design-system.html",
      "htmlURL": "/repo/public/_components/design-system.html",
      "canvas": { "name": "", "x": 1120, "y": 0, "width": 1180, "height": 1900 }
    }
  ],
  "diagnostics": []
}
```

`internalID` は `.ogp` 内で一意な内部キーである。表示名や `id` を含まない不透明 ID として扱い、保存時には manifest に書き戻す。

Chapter の `isSidebarHidden` と Pages の `isCanvasHidden` は editor-only 表示状態である。project summary は両方を返すが、非表示 Chapter / Page も project の編集対象として解決できる。`screenshot canvas` は明示された Chapter では `isCanvasHidden == false` の Page card だけを合成し、Chapter selector 省略時は `isSidebarHidden == false` の先頭 Chapterを選ぶ。全 Chapter が非表示なら暗黙選択せず、明示的な Chapter / Collection selector を要求する。

Guide は Pages では `chapters[].guides[]`、Components では `collections[].guides[]` に `internalID`、`orientation`、`position` を保存する。project summary は各 container の `guideCount` を返すが、Guide は HTML graph、canvas / page / node screenshot、build 出力には含めない。詳細は [CanvasAids.md](CanvasAids.md) を正本とする。

Canvas Object Reference は Pages では `chapters[].references[]`、Components では `collections[].references[]` に保存する。各配置は typed node `referenceID` と world frame だけを持ち、参照元 subtree は複製しない。project summary は各 container の `referenceCount` を返す。配置は App のキャンバス直下にだけ表示し、HTML graph、browser runtime、build、CLI/MCP screenshot には含めない。詳細は [CanvasObjectReferences.md](CanvasObjectReferences.md) を正本とする。

HTML document context は `.ogp` ではなく HTML 正本の `<html>` attribute と OpenGraphite metadata に保存する。`lang` / `dir` は常に HTML 仕様上の fallback 値であり、変数名を直接入れない。実装側 state に bind する場合は `data-og-lang-source="binding"` / `data-og-lang-field="<fieldName>"`、`data-og-dir-source="binding"` / `data-og-dir-field="<fieldName>"` を使う。`dir` を resolved lang から推定する場合は `data-og-dir-source="auto"` を使う。

```html
<html
  lang="ja"
  dir="ltr"
  data-og-lang-source="binding"
  data-og-lang-field="selectedLanguage"
  data-og-dir-source="auto">
```

`canvas.previewContext` は OpenGraphite app の editor preview にだけ注入する Mock State である。`fieldMocks` は言語切替だけでなく、タブ状態、ログイン状態、選択状態など、実装が参照する任意の初期値を表す。旧形式の `locale` / `direction` は decode 互換として扱うが、新規保存では使わない。

Inspector の Mock State は HTML document binding metadata と保存済み `fieldMocks` から注入可能 field を列挙する。field 自体の作成 UI ではなく、各 field を preview に mock inject するかを ON/OFF と値で制御する。

component placement の Mock State は HTML 正本ではなく、`.ogp` canvas metadata の `previewContext.placementMocks` へ保存する。HTML host は component/node 参照と配置デザインを持ち、`.ogp` は preview のためだけに注入する parameter を持つ。field は `host.<attribute>` または `host.class` とし、project runtime が生成 clone の標準 host attribute、class、ARIA へ一時投影する。`host.class` は既存 class へ token を追加し、`data-og-*`、`on*`、`id`、`style`、`slot`、`part` は注入しない。component の authored `:host(...)` CSS と browser computed style が最終表示を決め、source HTML と static build は変化しない。これは同じ component canvas 内で code / preview / loading / collapsed など複数状態を並べるための placement-local injection であり、page または component canvas 全体へ注入する `canvas.previewContext.fieldMocks` とは分離する。Sample project もこの4状態を標準 host state で保持する。

Text binding の HTML fallback は要素本文に残し、`data-i18n-key` で実装側 locale resource を参照する。推奨正本は `public/locales/<locale>.json` の flat key JSON であり、`.ogp` は i18n 設定や locale text の正本ではない。HTML 側の `data-og-text-variant-<locale>` は lightweight fallback / sample として残せるが、推奨運用では JSON resource へ移行する。`selectedLanguage=eng` のような Mock State は実装 runtime に初期状態を与える入力であり、Mock State 自体を text resource として扱わない。

OpenGraphite は HTML の `script` / `type="module"` script と辿れる import から `i18n.init({...})` を検出する。`lng`、`fallbackLng`、`backend.loadPath` の literal を表示し、`backend.loadPath: "/locales/{{lng}}.json"` は editable resource path として扱う。`import.meta.env.VITE_I18N_LOAD_PATH`、関数式、識別子などは external / readonly とし、OpenGraphite が動的式を書き換えない。

`window.__OPENGRAPHITE_PREVIEW_CONTEXT__` では HTML document context を `document`、mock state を `fields` として分離して公開する。単純な識別子 key の field は top-level alias としても参照できる。Mock state の空文字は有効な override 値として扱い、未指定とは区別する。

```js
window.__OPENGRAPHITE_PREVIEW_CONTEXT__ = {
  document: {
    lang: "ja",
    locale: "ja",
    langSource: "binding",
    langField: "selectedLanguage",
    langFallback: "ja",
    dir: "ltr",
    dirSource: "auto",
    dirFallback: "ltr"
  },
  fields: { selectedLanguage: "ja", activeTab: "overview" },
  selectedLanguage: "ja",
  activeTab: "overview"
}
```

preview で解決した一時的な locale / direction は preview clone の標準 `lang` / `dir` と runtime-private context にだけ反映する。永続値として保存するのは `<html>` 上の `lang` / `dir` fallback と `data-og-lang-*` / `data-og-dir-*` metadata だけである。旧 `data-og-preview-locale` / `data-og-preview-dir` は明示 migration の入力であり、agent graph や新規 source へ出力しない。

locale typography の default は document / page root selector の標準 `font-family`、locale override は同じ selector scope の `:lang(<BCP47>)` rule である。任意の妥当な BCP 47 tag を固定 allowlist なしで扱う。agent は CSS source の selector / at-rule / specificity / source order / `!important` provenance と、WebKit computed `font-family` を別情報として扱い、computed value を source declaration の代わりに書き戻さない。

`referenceID` は AI が Chapter / Collection / page / component canvas / node / annotation を安定指定するためのキーであり、コピーされる文字列は `ogref:<type>:...` 形式である。Chapter は `ogref:chapter:<chapterInternalID>`、Collection は `ogref:collection:<collectionInternalID>`、Pages は `ogref:page:<chapterInternalID>:<pageInternalID>`、Components は `ogref:component:<collectionInternalID>:<componentInternalID>`、Pages 内 node は `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>`、component 内 node は `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を使う。Chapter 注釈は `ogref:annotation:pages:<chapterInternalID>:<annotationInternalID>`、Collection 注釈は `ogref:annotation:components:<collectionInternalID>:<annotationInternalID>` を使う。

App の `参照IDから追加` は typed node reference だけを受け取り、任意階層の node を現在の Chapter / Collection キャンバス直下へ配置する。配置先と参照元の segment は一致しなくてよい。配置 viewport 上の編集は typed ID が指す元 HTML / companion CSS に保存され、配置を HTML object の子へ挿入しない。

## Canvas Annotations

付箋と手書きは HTML node graph ではなく、`.ogp` の `chapters[].annotations[]` または `collections[].annotations[]` に属する editor-only metadata である。`project inspect` は各 Chapter / Collection の `annotationCount` を返す。詳細な schema と canonical world 座標は [CanvasAnnotations.md](CanvasAnnotations.md) を正本とする。

```bash
ogkiln annotation list SampleProject/OpenGraphiteSample.ogp --chapter-id <chapter-id> --json
ogkiln annotation list SampleProject/OpenGraphiteSample.ogp --collection-id <collection-id> --json
ogkiln annotation get SampleProject/OpenGraphiteSample.ogp --chapter-id <chapter-id> --id <annotation-internal-id> --json
ogkiln annotation get SampleProject/OpenGraphiteSample.ogp --id ogref:annotation:pages:<chapter-internal-id>:<annotation-internal-id> --json
```

`annotation list` は手書き点列を展開せず、付箋本文、frame、色、stroke / point count を返す。`annotation get` は typed annotation reference と完全な stroke / point payload を返す。CLI と MCP の annotation interface は読み取り専用であり、HTML / CSS を変更しない。

`screenshot canvas` は `--chapter-id` / `chapterID` または `--collection-id` / `collectionID` で対象を排他的に選び、省略時は Sidebar 表示中の先頭 Chapter を使う。全 Chapter が Sidebar 非表示なら selector を要求する。WebKit で描画した対象 Chapter の `isCanvasHidden == false` の page card 群または Collection の component card 群へ、App と同じ ink、sticky note の順で `.ogp` 注釈を前面合成し、card と annotation の world frame の union を出力範囲にする。capture 前に全 card が有限座標と正の寸法であることを確認し、出力の一辺 16,384 px、総 33,554,432 pixel、またはcard snapshot累積33,554,432 pixelの安全上限を超える場合は明示エラーを返す。Canvas Object Reference は editor viewport のため `screenshot canvas` に含めない。個別 HTML を対象にする `screenshot page` / `screenshot node` には Chapter / Collection 注釈を含めない。

## Page Graph

`ogkiln page graph <project.ogp|current> --page-id <page-reference-id>|--component-id <component-reference-id> [--active-media <condition>]... --json` と MCP の graph resource は、`.ogp` の対象 page または component canvas に含まれる通常の DOM element を OpenGraphite annotation の有無にかかわらず DOM 出現順に返す。Collection 内 component HTML は `--component-id <component-reference-id>` で同じ graph / node edit 経路を使う。`--page-id` / `--component-id` は `internalID`、`<groupInternalID>:<pageInternalID>`、または `referenceID` で解決する。

graph inspection は source を変更しない。resource の open、load、preview、graph、query/get、validation、build、無編集保存を adoption とみなさず、`data-og-id`、`data-og-internal-id`、`data-og-type` を自動追加しない。同一 project では未注釈、部分注釈、完全注釈の page / component resource と、OpenGraphite を使わない登録済み resource が共存できる。

`<og-placement>` host は要素名から判定してcomponent canvasのgraphに通常nodeとして含める。`parentID`はDOM上の親OpenGraphite nodeを返し、`.ogp`のpage / component cardとしては扱わない。placementが表示のために生成したcloneとそのdescendantsはruntime-private registryで識別し、graph / Layers / node editの対象から除外する。clone markerや`data-og-role`をsource attributeまたはgraph fieldとして要求しない。Chapter / Pages HTMLにplacement hostが存在する場合、project validationは`component-placement-outside-collection` errorを返す。

component masterは登録済みcomponent resource内の、`data-og-component`と直下`template`を持つhyphenated Custom Element hostである。runtimeはtemplateをopen Shadow DOMへcloneし、instanceの通常の`slot`付きlight DOM、host `variant`、shadow内部の`part`をbrowser semanticsのまま扱う。Appのnode収集はopen shadow treeを含め、generated nodeの編集はprivate provenanceからmaster source nodeへ解決する。static buildは同じtemplateをDeclarative Shadow DOMへ変換し、最大32段のnested instanceをdocument orderで展開する。inspection、runtime render、serialize、buildは旧`data-og-component-kind` / `data-og-slot` / `data-og-part` / `data-og-variant`を生成しない。

`cssVariables` は互換フィールド名であり、source HTML の inline style だけを意味しない。project-aware graph は `.ogp` の `cssLibrary`、同名 companion CSS、HTML の各 `<style>`、project root 内で読める各 local `<link rel="stylesheet">` を raw 連結せず別々の lossless AST として保持し、HTML document order で cascade する。project / companion が HTML から link されていればその位置を使い、link がない project library は先頭、link がない companion CSS は末尾の fallback source とする。element の `style` attribute は `sourceKind: "inline"` の HTML source として author stylesheet より高い通常の inline specificity で合成する。

`cssSourceTrace` は property ごとの既知 candidate について `authoredProperty`、selector、specificity、at-rule scope、`!important`、`sourceID`、`sourceKind`、`sourceEditable`、`stylesheetOrder`、source 内の `sourceOrder`、`inherited` を返す。`sourceKind` は現在 `project` / `companion` / `linked` / `embedded` / `inline` である。file source の `sourceID` は file URL（同じ file の複数 link は link source offset も含む）、embedded source は document URL と `<style>` source offset、inline source は `<inline style>` で識別する。共通 node style mutation が元 source を直接変更できるのは direct winner の companion declaration と inline declarationであり、project library、一般 local linked CSS、embedded `<style>` は read-only source として inspection する。

`cssResolvedValues` は既知 source だけで決定できる inheritance、custom property、対応 shorthand、CSS-wide keyword 解決後の headless 値である。各stylesheetではcandidate抽出だけを行い、全sourceのcascade candidateと親からの継承値を合成した後に一度だけcustom property / `var()`を解決するため、別sheetや祖先で定義された参照を暫定的な未解決値として残さない。対応 shorthand は `margin` / `padding` / `inset`、border各辺、`gap`、`flex-flow`、`grid-template` / `grid`、mask image 抽出を含む。shorthand値が`var()`を含む場合もtraceの`authoredProperty`とraw valueは元shorthandのまま保持し、全source/親継承を含むcustom property置換後にだけ対象longhand componentへ展開する。展開後のgrammarを断定できないlonghandはnode-level incompleteとしてwrite-blockする。`inherit` / `initial` / `unset` は `\69nherit` のようなCSS identifier escapeもsemanticに復号するが、authored value spellingは変更しない。browser origin/layer計算を必要とする `revert` / `revert-layer` は同じauthor origin内の直前candidateへ戻さず、継承propertyでは親computed値を保持し、非継承propertyではauthor resolved値を除外してHTML UA fallbackへ委ね、該当propertyをnode-level incompleteにする。

外部・root外・読取不能 stylesheet、未解決 `@import`、malformed CSS、`@layer` / `@property` などsource全体で未対応の at-rule、headless matcherが安全に評価できない selectorがある場合、既知 candidate と WebKit computed inspection は維持する一方、page と各 node の `hasIncompleteCSSProvenance` を `true` にし、warning `incomplete-css-provenance` を返す。現在 `@import` を別 source として解決したとは主張せず、importを含む sheet 自体のidentity/orderを保持したまま不完全とする。このsource-wide incomplete状態のCSS set/removeは error `incomplete-css-provenance-write-blocked` でatomic no-writeになり、CSS provenanceに依存しないattribute/text/DOM operationはこの理由だけでは禁止しない。

matching `@supports` / `@container` / `@scope` / `@document` / `@starting-style` は真偽をheadlessで断定しないconditional contextとして、該当propertyを持つnode/targetだけをincompleteにする。`@keyframes` / `@-webkit-keyframes` 定義だけでもstylesheet全体を未対応at-rule扱いにせず、graph内にkeyframes sourceがあり、対象nodeまたは関連rendering targetのresolved `animation-name` / `animation` がactiveな場合だけ時間依存computed値としてguardする。未知initial valueを必要とする `initial` / `unset` / `inherit`、browser origin/layer計算を必要とする `revert` / `revert-layer`、またはheadlessの対応CSS値grammarで無効・未対応と判断したauthored source値もproperty単位の同じnode guardになる。対応grammarはkeywordに加え、box / inset geometry、標準length unit / percentage / unitless zero、typed `calc()` / `min()` / `max()` / `clamp()`、grid track、数値propertyを検証する。math resultはnumber / percentage / length / length-percentageを区別し、たとえば`line-height`はnumberの`calc()`を受理する一方、`scale`はnumber / percentageだけを受理してlengthや混在型を拒否する。無効なraw declarationは保持してwinnerを断定しない。構文上有効な`env()` / `anchor()` / `anchor-size()`もraw authored valueを保持するが、environment / layout依存値をheadlessで確定しないためresolved winnerを返さず同じnode guardになる。明示set入力が対応grammarで無効、top-level `;`で別declarationへ到達、またはvalue payloadからtop-level `!important`を注入する場合はerror `invalid-css-property-value`でatomic no-writeにする。environment依存値のsetはsyntax errorとはせず、node provenanceとpostconditionを安全に確定できないため`incomplete-css-node-provenance` / `incomplete-css-provenance-write-blocked`でatomic no-writeにする。pageのflagは一つでも該当nodeがあれば集約して`true`になるが、source-wide incompleteでない限り、完全な別nodeまでwrite-blockする意味ではない。該当targetへのCSS mutationはwarning `incomplete-css-node-provenance` とerror `incomplete-css-provenance-write-blocked`を返してatomic no-writeにする。

WebKit の computed style は Canvas の現在viewport・実 runtime・全 browser stylesheetを反映する別payloadであり、authored traceへ逆算して混ぜない。App は computed `display` / `position` / `visibility` / `content-visibility` と現在の rendered hidden 判定を表示し、標準 `hidden` attribute のsource有無も別表示する。CLI の repeatable `--active-media <condition>` と MCP の `activeMediaQueries: string[]` は、呼び出し側が実描画環境でactiveと確認した authored `CSSMediaRule.conditionText`を渡す。省略時は条件ruleを勝手にactiveとみなさない。`<style media>` / `<link media>` の外側scopeとstylesheet内の `@media` は同じactive集合で評価し、graph responseの`activeMediaQueries`は正規化後に実際に使った条件を返す。

nodeの互換`layout`表示値はattributeではなくresolved `display` / `flex-direction`とHTML UA既定から導出する。Flexは`vertical` / `horizontal`、Gridは`grid`、Blockやtableなどはresolved `display`文字列を返す。absolute positioningは親enumにせず、各childのresolved `position` / insetでinspectionする。`hidden`はsourceに標準`hidden` attributeが存在するかを示し、CSSの`display:none` / `visibility:hidden`は`cssSourceTrace` / `cssResolvedValues`へ分離する。`hidden="until-found"`はdeclarationがない場合だけheadless UA fallbackとして`content-visibility:hidden`を返し、author originの`content-visibility:initial` / `unset` / `visible`はいずれもresolved `visible`としてそのfallbackを上書きするが、sourceの`hidden` intentは`true`のまま保持する。

`node style set/remove`も同じactive media集合を受け取る。responsive candidateがwinnerなら、そのcandidateのselector / at-rule / `!important` / source orderを保持してvalue rangeだけを更新する。direct companion / inline winnerのremoveは対象declarationだけを削除するが、longhandがshorthandから解決されているremoveは他subpropertyを安全に保持できないため `shorthand-css-removal-unsupported` でno-writeになる。

node style mutationはproject CSSをcascade candidateとして読むが、`.ogp`の`cssLibrary`を直接変更しない。read-only project / linked / embedded winnerへのsetは、そのwinnerのactive media scopeと`!important`を引き継ぎ、winnerより高いspecificityを安全に構成できる場合だけcompanion CSSへnode-scoped overrideを追加する。安全なspecificityを構成できなければ `css-specificity-override-unsafe`、postconditionで要求値がcompanion / inline winnerにならなければ `css-mutation-postcondition-failed` でno-writeになる。read-only winnerしかないremoveはproject/linked sourceを変更せず、`read-only-css-winner` でno-writeになるため、「removeでproject値も消える」とは扱わない。CSS libraryを変更するのは`design-token set/remove`と同名MCP toolだけである。

media / icon wrapper の inspection は DOM relation から実際の描画 element を解決する。image fit は descendant `img` / `video` の `object-fit`、inline icon の線幅は `svg` / SVG descendant の `stroke-width`、CDN mask は child の `mask-image` / `-webkit-mask-image` を source trace と computed style の対象にする。wrapper に存在する `data-og-icon-library` / `data-og-icon-name` / `data-og-icon-source` は optional provenance として graph に保持するが、描画値の代替にはしない。旧 media / icon helper は明示 migration input に限り、通常 graph や style write で生成しない。

`scale` は選択 node 自身の source-aware CSS property として通常の style set / remove 経路を使う。たとえば水平 flip は `ogkiln node style set <project> --page-id <page> --id <node> --var scale --value '-1 1'`、垂直 flip は値 `1 -1` で設定でき、MCP の `set_css_variable` も同じ Core 経路を使う。書き戻しは `scale` declaration だけを更新し、source に既にある独立した `rotate` / `transform` を合成・上書きしない。この移行は `rotate` / `transform` 用の専用 agent allowlist や編集 command を追加しない。drag / reorder は agent graph に独自 helper を公開せず、session-only `translate` / Web Animations API として source write の対象外にする。

Agent node はこの解決結果を `renderingTargets: [OpenGraphiteAgentRenderingTarget]` で返す。各 target は `kind`、`tagName`、`relation`、`relationSelector`、`writeSelector`、`targetInternalID`、`authoredValues`、`resolvedValues`、`sourceTrace` を持つ。`kind` は `media` / `svg` / `mask`、`relation` は `self` / `direct-child` / `descendant` である。`relationSelector` は `:scope`、`:scope > img`、必要時の `:nth-of-type(n)` を含む selector など、wrapper から対象を再解決する query 用の相対 selector である。`writeSelector` は companion CSS への安全な書き込み先であり、対象の標準 `id`、既存 `data-og-internal-id`、wrapper の selector と相対 path の順に優先する。対象 child が未注釈なら `targetInternalID` は `null` のままであり、inspection や style write のために annotation を追加しない。`authoredValues` / `resolvedValues` / `sourceTrace` は wrapper ではなく実際の target の値と provenance を返す。

各 node は `reference`、`annotationStatus` (`none` / `partial` / `complete`)、`referenceStability` (`session` / `stable`)、`locator`、optional `parentReference` を返す。`locator` は `documentURL`、既存の標準 `id` を優先する optional `selector`、`domPath`、`sourceRange.start/end`、`contentHash` を持つ。annotation status と stability は独立しており、一意な `data-og-internal-id` があればpartialでもstable typed `ogref:node` / `ogref:component-node`、それ以外は現在のsource revisionに限るsession referenceである。互換フィールドの `id` / `internalID` はannotationがなければ空になり得る。

nodeの操作可能性は単一の`type`ではなく、raw value昇順でdeterministicな`capabilities`として返す。値は`drag-position`、`edit-control`、`edit-icon`、`edit-layout`、`edit-link`、`edit-media`、`edit-text`、`group`、`receive-children`、`reorder-flow`、`ungroup`である。`capabilityEvidence`は`isProjectResourceRoot`、`isNativeControl`、`isCustomElement`、`isLink`、`hasDirectText`、`hasElementChildren`、`hasMediaContent`、`hasSVGContent`、`hasMaskContent`、optional `ariaRole`、optional `resolvedDisplay`を返す。旧sourceに属性が存在する場合だけ`legacyTypeHint`へraw `data-og-type`値を返し、旧node JSONの`type` keyは返さない。

Core の related-target write 入口は `OpenGraphiteAgentCore.setRelatedStyleDeclaration(property:value:wrapperNodeID:...)` である。既存の node style set / remove は `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image` のみこの resolver へ透過 route し、その他の property は選択 node 自身の declaration を扱う。CLI と MCP は新しい command / tool を追加せず、この同じ Core 経路を使う。

```json
{
  "schemaVersion": "0.1",
  "pageURL": "/repo/public/index.html",
  "activeMediaQueries": ["(max-width: 760px)"],
  "hasIncompleteCSSProvenance": false,
  "nodes": [
    {
      "id": "hero",
      "internalID": "a4e19c02f6b8",
      "reference": "ogref:node:1gibtxulofmr0:kl1xxsgkiuue:a4e19c02f6b8",
      "annotationStatus": "complete",
      "referenceStability": "stable",
      "locator": {
        "documentURL": "file:///repo/public/index.html",
        "selector": "#hero-card",
        "domPath": "html:nth-of-type(1) > body:nth-of-type(1) > main:nth-of-type(1) > herosection:nth-of-type(1)",
        "sourceRange": { "start": 184, "end": 486 },
        "contentHash": "3e9c8af3c91d8c4f"
      },
      "parentReference": "ogref:node:1gibtxulofmr0:kl1xxsgkiuue:page-node",
      "tagName": "herosection",
      "legacyTypeHint": null,
      "capabilities": [
        "drag-position",
        "edit-layout",
        "group",
        "receive-children",
        "reorder-flow",
        "ungroup"
      ],
      "capabilityEvidence": {
        "isProjectResourceRoot": false,
        "isNativeControl": false,
        "isCustomElement": true,
        "isLink": false,
        "hasDirectText": false,
        "hasElementChildren": true,
        "hasMediaContent": false,
        "hasSVGContent": false,
        "hasMaskContent": false,
        "ariaRole": null,
        "resolvedDisplay": "flex"
      },
      "layout": "horizontal",
      "role": null,
      "cssVariables": {
        "gap": "44px"
      },
      "cssSourceTrace": {
        "gap": [
          {
            "property": "gap",
            "authoredProperty": "gap",
            "selector": "hero-section.featured",
            "specificity": { "ids": 0, "classes": 1, "types": 1 },
            "atRules": [],
            "value": "44px",
            "important": false,
            "sourceID": "file:///repo/public/index.css#link-96",
            "sourceKind": "companion",
            "sourceEditable": true,
            "stylesheetOrder": 1,
            "sourceOrder": 12,
            "inherited": false
          }
        ]
      },
      "cssResolvedValues": {
        "display": "flex",
        "flex-direction": "row",
        "gap": "44px",
        "position": "static",
        "visibility": "visible"
      },
      "hasIncompleteCSSProvenance": false,
      "hidden": false,
      "locked": false,
      "depth": 2,
      "parentID": "page",
      "textContent": "OpenGraphite",
      "attributes": {
        "data-og-id": "hero",
        "data-og-internal-id": "a4e19c02f6b8"
      }
    }
  ],
  "diagnostics": []
}
```

`data-og-id` は存在する場合に UI と人が使える optional なページ内 ID である。`data-og-internal-id` は名称変更から独立した optional identity であり、stable agent reference の node 部分に使う。欠落 node は DOM position だけを永続 identity にせず、document URL、safe selector、source range、content hash を束ねた session locator として扱う。

`parentReference` は直接のinspectable DOM parentをstableまたはsession referenceで返す。`parentID` は互換フィールドとして、利用可能な最も近いOpenGraphite ancestorの `data-og-id` を返し得る。`textContent` は node subtree 内のタグを除いたプレーンテキストであり、検索と確認に使う。

Shared source parserはApp/WebKitと同じscripting-enabled HTML semanticsでauthored elementのparent、optional end tag、source rangeを解釈する。したがって`noscript`本文はraw textとしてinspectionし、そのfallback markupをdescendant nodeとしてgraphへ追加しない。

Agent graph、`parentReference`、locatorのDOM path、source rangeはsource HTMLに実在するauthored elementだけを返す。一方、CSS selector/cascadeとinheritanceの評価では、browserのHTML tree constructionが補う`html` / `head` / `body`、`table`直下の`tr`に対する`tbody`、`col`に対する`colgroup`を評価専用DOMとして投影する。これにより`:root`、`html > body > ...`、`table > tbody > tr`などはWebKitと同じtreeへ一致するが、implicit elementをnodeとして追加したり、無編集sourceへ開始tagを保存したりしない。

### Progressive Adoption

安定したAI mutation targetが必要な場合だけ、graphが返したlocatorを明示adoptする。

```bash
ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference <session-reference> --scope node --json
ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference <target-reference-from-dry-run> --scope node --apply --json
```

`node adopt` のdry-runは `--reference` / `--selector` / `--dom-path` の正確に一つを受け付ける。入力nodeが既にstableかどうかにかかわらず、結果の `targetReference` は現在のsource range/content hash、document全体のbefore hash、正規化済み `--scope` / `--display-id` を固定したapply専用proposal snapshot referenceへ正規化される。`--scope` は `node`（既定）または `subtree`、`--display-id` は対象rootへのoptionalな人間可読IDである。`--apply` なしはdry-runで、sourceを書かず `schemaVersion`、`applied`、`changed`、`dryRun`、`path`、`scope`、`targetReference`、`adoptedReferences`、optional `diff`、候補 `graph`、`diagnostics` を返す。`diff` は `path`、`beforeHash`、`afterHash`、`unifiedDiff` を持つ。

`--apply` は直前のdry-runが返したproposal `targetReference` を `--reference` とし、同じ `--scope` と正規化後に同じ `--display-id` を渡す場合だけ受け付ける。graphが通常返すsession referenceをapplyへ直接渡すことはできない。同じ共有Coreでsource range/content hash、document全体hash、proposal parameterを再検証し、sourceまたはproposalが変化していればstale proposal errorとして一切書き込まない。既存の標準 `id` または安全なselectorで十分な対象はそれを優先し、必要なoptional identityだけを追加する。semantic valueを確定できないcharacter referenceを含む既存OpenGraphite identityはstable selector/referenceへ使わずvalidation errorにし、対象nodeまたはsubtreeのadoptionも既存参照を上書きせずatomicに拒否する。apply後のnodeはstable referenceを返し、同じadoptionの再dry-runは差分なしになる。

component placement は `data-og-source-component-internal-id` と `data-og-source-node-internal-id` で参照元を保持する。project validation は source component が現在の component canvas と一致し、source node が同じ component HTML 内に存在することを検証する。AI が placement の preview 状態を変える場合は `.ogp` の `canvas.previewContext.placementMocks[placementInternalID]` を編集する。internal ID の entry がなければ display ID の entry へ fallback するが、両方の entry は merge せず internal ID 側が優先する。canvas の `fieldMocks` を基底に、選択された placement entry を同名 field の override として重ねる。placement host は開閉可能な参照表示であり、内部に表示される clone node は実体を持たない。clone node を選択して編集する場合、保存対象は同じ `data-og-internal-id` を持つ参照元 component node であり、agent 向け参照 ID も `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を指す。placement host の companion CSS declaration は、その placement 側の表示枠 override として編集する。

## Web Contract Migration

legacy Web contract の変換は project-scoped な明示操作です。CLI は次の2段階を使い、MCP の `migrate_project` も同じ Shared Core と result contractへ委譲します。

```bash
ogkiln migrate <project.ogp|current> --target-version 1.0.0 --json
ogkiln migrate <project.ogp|current> --target-version 1.0.0 --proposal <proposal-reference> --apply --json
```

1回目は必ずdry-runで、`legacyCatalogVersion: "1"` / `preserveUnknownDataAttributes: true` の固定options、target、project manifest、全対象canonical relative pathとUTF-8 BOMを含むraw-byte SHA-256 hashを束縛したproposalを返します。2回目だけがwrite候補であり、同じtarget/optionsと `proposalReference` を要求します。resourceまたはmanifestが変化したproposal、別projectのproposal、parameterが異なるproposalは `stale-migration-proposal` としてatomic no-writeになります。applyだけを直接要求すると `migration-apply-requires-proposal` です。

```json
{
  "schemaVersion": "0.1",
  "sourceContractVersion": "0.1.0",
  "targetContractVersion": "1.0.0",
  "dryRun": true,
  "applied": false,
  "changed": true,
  "proposalReference": "<opaque-proposal-reference>",
  "diffs": [
    {
      "path": "public/legacy.html",
      "beforeHash": "…",
      "afterHash": "…",
      "unifiedDiff": "…"
    }
  ],
  "diagnostics": []
}
```

既知legacy HTML/CSSはcatalog v1のversioned class/custom propertyと標準attributeへlosslessに変換し、維持allowlistのoptional identity、component/source reference、binding、editing policy、icon provenanceと未知の`data-*`は保持します。`data-og-type` / `data-og-layout` / `data-og-icon-mask`は`.og-migrated-v1-*` class、`data-og-hidden`は標準`hidden`、`data-og-variant` / `data-og-part`は`variant` / `part`へ移します。既知design `--og-*`は`--migrated-v1-*`へrenameし、runtime-only custom propertyはdeclaration除去または`var()` fallback / `unset`へmaterializeします。project CSS、executableなinline/linked JavaScript、inline event handlerがlegacy inputを読む場合や、実際に新規生成するclass・標準attribute・custom propertyを観測する場合はproject-wide conflictです。dot/bracket/optional access、method alias、destructuring、borrowed `getAttribute.call(node, ...)` / `setAttribute.apply(node, [...])`は同じattribute evidenceへ正規化しますが、exact名は実際に生成するdestinationとだけ交差し、dynamic名だけをwhole-attribute observerにします。whole `dataset` / `style` observerとCSSの`style` value selector / `attr(style)`は、実際に削除するdataset attribute、inline `style`の実変更、または生成するcustom propertyとだけ交差します。whole attribute、dynamic selector/computed DOM、AttributeNode observerは実際のHTML attribute変更、whole markup observerはembedded `<style>`移行を含む実際のHTML source変更とだけ交差します。external CSS変更はCSSOM、embedded CSS変更はCSSOMまたはactual style-text observerとだけ交差します。ID-based style/link evidenceはそのruntimeを参照するHTMLのactual CSS ownerへ束縛し、別pageの同名非style要素、runtime生成styleや通常要素のtext、`CSSStyleDeclaration.cssText`、generic `.sheet` / computed accessをwhole-source evidenceにしません。manifest preview変更はglobal preview contextから追跡できる`placementMocks` / whole-context alias chain、または新規生成するexact/static-concatenated `host.*` fieldとだけ交差し、`fields` / `document`や無関係objectの同名propertyはsafeです。clean observer projectと無関係なactual mutationはblockしません。semanticに同値のstandard destinationが既にある場合はgenerated evidenceに含めず、case・quote・character referenceと周辺raw bytesを維持してlegacy tokenだけを除去します。JavaScript commentとCSS comment/string/`url()`の見かけ上のtokenは変更・observer判定しません。

対象closureはmanifest、project CSS library、登録HTML、存在するcompanion CSS、actual local linked stylesheet / executable script、actual linked/embedded CSSから再帰的に辿るlocal `@import`です。inline styleとembedded styleもHTML candidate内で処理し、変更しないlocal dependencyもproposal hashへ束縛します。source kindはHTML character reference復号後のsemantic valueで決め、URL extensionでは補正しません。`<style>`は`type`省略/exact empty/ASCII-CI exact `text/css`、`<link rel~=stylesheet>`は`type`省略またはHTTP-whitespace-trim済みMIME essence `text/css`だけをCSSとし、present-empty link typeは非CSSです。`<script>`はexact empty、ASCII-CI exact `module`、またはexact JavaScript MIME typeだけをexecutableとし、`type`がobsolete `language`に優先します。style/scriptのtypeはtrimもparameter除去もせず、JSON/JSON-LD/import map/speculation rules/unknown data blockはopaqueです。HTML/CSS whitespaceはTAB/LF/FF/CR/SPACE、HTTP whitespaceはFFを除く4文字で、NBSP/vertical-tabはraw valueに残します。HTML non-void `/>`はelementを閉じず、SVG/MathML self-closingは閉じます。semicolonなしdecimal/hex numeric referenceもsemantic decodeし、raw range外のcase/entity/CRLF/BOM/triviaを保持します。このactual kindでextensionless pathもclosureへ含めます。登録対象でlegacy inputを検出したprojectに限り、external / 解決不能なbase・stylesheet・runtime、曖昧なimport、module dependency、local runtimeのlegacy reader、missing / project root外 / unreadableなdiscovered dependency、または同一canonical URLのCSS/runtime kind conflict (`migration-resource-kind-conflict`) は安全にclosureを確定できないためblockingです。legacy input がない clean standard projectは変更不要のno-opとして扱います。`migration-project-load-failed`、`unsupported-legacy-import-reference`、`unsupported-legacy-runtime-dependency`を含むerror dry-runはpartial proposal/diffを返さず、全resourceをno-writeにします。

legacy component master/slot、source placement mode/state、unsafe role、既存standard destinationとの競合は構造を推測せずblockingです。手動でregistry / template / slot / placement sourceと`.ogp` host stateを同じ標準表現へ揃えてから再dry-runします。project rootの`OpenGraphite.contract.json`はAppが読むtool configurationであり、proposal targetにもdiff/apply candidateにもせずbytesを維持します。`.ogp` schema versionは変更せず、strictな`previewContext.placementMocks`内の`codeViewerMode: "preview"`だけを`host.variant: "preview"`、`placementMode: "collapsed"`だけを`host.variant: "collapsible collapsed"`へ変換します。source HTMLへpreview stateを追加しません。

applyは全candidateをstageし、各commit直前に変更しないdependencyを含むproposal全closureのraw bytes・存在・canonical path解決を再検証してから書きます。staleを検出した場合は先行commitをrollbackして`stale-migration-proposal`、write失敗では`migration-write-failed`とrollbackを実行します。rollbackはmigration後bytesと復元済みmodeが一致するsourceだけをcompare-and-swapで戻し、commit後の外部編集は上書きせず`migration-rollback-failed`を追加します。未対応targetは`unsupported-migration-target-version`です。`sourceContractVersion`はlocal contractのversionではなく登録対象sourceのlegacy token検出から決めるため、旧tool configurationが残ってもapply後の再dry-runはtarget version / `changed: false`になります。compatibility readerはcontractの`legacyReaderRemovalConditions`をすべて満たすまでmigration入力とpre-migration inspectionにだけ残します。

## Diagnostics

検証結果は severity、code、message、path、nodeID を持つ。

```json
{
  "severity": "error",
  "code": "duplicate-data-og-id",
  "message": "data-og-id \"hero\" が重複しています。",
  "path": "/repo/public/index.html",
  "nodeID": "hero"
}
```

`error` がある操作は write を行わない。`warning` は write を止めないが、AI はユーザーへ変更リスクとして報告できる必要がある。

missing `data-og-id` / `data-og-internal-id` / `data-og-type` は error ではない。存在する `data-og-id` / `data-og-internal-id` の重複、存在するcomponent/node referenceの破損、adoption locatorのhash不一致は引き続きerrorである。

## Edit Operations

AI と MCP は HTML 全体の置換より次の node 単位操作を優先する。

```bash
ogkiln contract get --json
ogkiln project current --json
ogkiln project create --root ../MySite --output ../MySite/OpenGraphiteProject.ogp --json
ogkiln design-token list SampleProject/OpenGraphiteSample.ogp --json
ogkiln design-token set SampleProject/OpenGraphiteSample.ogp --name --color-accent --value '#f5f7f8'
ogkiln design-token remove SampleProject/OpenGraphiteSample.ogp --name --space-medium
ogkiln locale-typography list SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --json
ogkiln locale-typography set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --locale ja-JP --value '"Noto Sans JP", sans-serif' --json
ogkiln locale-typography remove SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --locale ja-JP --json
ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id tutorial --path tutorial.html --title Tutorial --body-file tutorial.body.html --x 2960 --y 0
ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id archive --path archive.html --x 4440 --y 0
ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --name Desktop --x 3040 --y 0
ogkiln project page document SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --lang-source binding --lang ja --lang-field selectedLanguage --dir-source auto --dir ltr
ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --preview-mock selectedLanguage=ja
ogkiln project component create SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id shared-ui --path _components/shared-ui.html --title 'Shared UI' --body-file shared-ui.body.html
ogkiln project component add SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id aux-ui --path _components/aux-ui.html --width 960 --height 900
ogkiln project component place SampleProject/OpenGraphiteSample.ogp --component-id <shared-ui-internal-id> --name Desktop --width 1180 --height 1900
ogkiln project component remove SampleProject/OpenGraphiteSample.ogp --component-id <aux-ui-internal-id>
ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --chapter-id main --output screenshots/canvas.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --output screenshots/docs.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --output screenshots/design-system.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --width 390 --height 900 --full-page --output screenshots/docs-mobile.png
ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:2opic2blumreb:fb1954bc9811 --output screenshots/doc-cli.png
ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:component-node:component-main:3bgx6phkz3jv5:3af881fc5123 --output screenshots/feature-card.png
ogkiln build SampleProject/OpenGraphiteSample.ogp --output dist
ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --capability edit-link --capability edit-text --text-contains Docs --json
ogkiln node query SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --capability receive-children --capability edit-layout --json
ogkiln node get SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:kl1xxsgkiuue:3aefceddb042 --json
ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference <session-reference> --scope node --json
ogkiln node adopt SampleProject/OpenGraphiteSample.ogp --page-id tutorial-objects --reference <target-reference-from-dry-run> --scope node --apply --json
ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var gap --value 32px
ogkiln node style set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 3af881fc5123 --var padding --value 48px
ogkiln node style remove SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var gap
ogkiln node attr set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 121eafb2db25 --name href --value './index.html'
ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id eace7f6a5b08 --value 'OpenGraphite'
ogkiln node text set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 57d89af48b12 --value 'Reusable card'
ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 72222bd6f11e --position prepend --html '<Header data-og-id="site-header"></Header>'
ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 42addef8c515 --position append --html '<feature-card data-og-id="feature-card-master" data-og-component="feature-card" part="root"><template><slot>Fallback</slot></template></feature-card>'
ogkiln node html replace SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --html '<Hero data-og-id="hero"></Hero>'
ogkiln node delete SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id <node-internal-id>
ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id efeaffcc2273 --target 3aefceddb042 --position after
ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id d9778be9a854 --target b01aee52375f --position append --id-prefix copy-
```

`.ogp` に登録されていない HTML は直接編集しない。既存 page HTML は `project page add`、新規 page HTML は `project page create` により既定 Chapter の `pages[]` に追加してから node operation の対象にする。component master を置く HTML は `project component add` または `project component create` により Collection の `components[]` に追加し、`--component-id` で同じ node operation の対象にする。

`node query --capability`は反復指定でき、指定したcapabilityをすべて持つnodeだけを返す。互換`--type`は、sourceに実在する`legacyTypeHint`のexact-matchに限る。typeからcapabilityを推測したり、新規sourceへtype annotationを生成したりしない。

write operation は次の制約を持つ。

- stable mutation の対象 node は一意な `data-og-internal-id` または stable typed `ogref` で解決できること。未注釈nodeは先に明示adoptすること。
- `node adopt` のdry-runだけがinspection済みreference / selector / DOM pathを受け取り、applyはdry-runが返したproposal snapshot referenceと同じscope/display IDに限定してsource range/content hash、document全体hash、proposal parameterを再検証し、optional identityを追加できること。
- `data-og-id` が重複している場合は失敗すること。
- `data-og-internal-id` が重複している場合は失敗すること。
- `node style set/remove` は既存 direct inline winner または対象 HTML と同名の companion CSS だけを直接更新し、新しい HTML inline `style` を作らないこと。
- `node style set` は `OpenGraphite.contract.json` にある編集対象 CSS 宣言だけを更新すること。
- source-wide `hasIncompleteCSSProvenance == true` では source inspection と WebKit computed 表示を維持するが、すべての node CSS set/remove は `incomplete-css-provenance-write-blocked` で atomic no-write にすること。keyframes/active animationや未確定CSS-wide値によるnode単位のflagは該当targetだけを同errorでblockし、page集約flagだけを理由に完全な別nodeをblockしないこと。
- direct inline winner は既存 HTML `style` declaration のvalue rangeだけを更新できるが、新規 inline styleは作らないこと。direct companion winnerは同じsource rangeを更新し、project / linked / embedded winnerへのsetは安全なcompanion overrideだけを許可すること。安全なspecificityを構成できなければ `css-specificity-override-unsafe` でno-writeにすること。
- read-only winnerだけが存在するremoveは `read-only-css-winner`、shorthand由来longhandのremoveは `shorthand-css-removal-unsupported` とし、元sourceや他subpropertyを推測で変更しないこと。
- editor の選択、直接編集、Focus、drag、reorder、frame preview、生成 provenance を表す runtime helper attribute / custom property を正本 HTML、companion CSS、agent graph へ保存しないこと。旧 helper 名は明示 migration の入力としてだけ受け付けること。
- `data-og-internal-id` は内部不変 ID のため、通常の `node attr set` では変更しないこと。
- 許可済み永続属性は `OpenGraphite.contract.json` の `editableAttributes` に従い、標準`hidden` / `href` / `target` / `aria-label` / `value` / `src` / `alt`と保持対象OpenGraphite metadataのどちらも、対象tag/content modelとoperation capabilityが対応するnodeだけで編集すること。contract外は`disallowed-attribute`、対象不適合は`unsupported-node-capability`としてatomic no-writeにすること。
- `node attr set --value ''` はpresent-empty attributeを保持し、attribute tokenを削除するのは明示的な`node attr remove`だけとすること。既に存在しないtokenのremoveはsourceを変更しないこと。
- 子 HTML 挿入後の graph に validation error がある場合は、対象ファイルを書き換えないこと。
- `node text set` は HTML としてではなく text として保存し、`<`、`>`、`&` を escape すること。
- `node copy` は subtree 内の全 `data-og-id` に `--id-prefix` を付与し、複製側の `data-og-internal-id` は新しい不透明 ID にすること。
- `node move` は source subtree 内の node を target に指定できないこと。

### Resolved Text Editing

App の Canvas / preview で直接 text を編集する操作は、現在の preview context と実装 runtime で解決済みの text resource を対象にする。たとえば `selectedLanguage=ja` が inject され、`data-i18n-key` を持つ node が `public/locales/ja.json` から描画されている場合、その編集は HTML fallback ではなく該当 key の `ja` resource に保存する。binding metadata、field 名、Mock State の値を text content として書き換えない。

Inspector は同じ node について、現在描画中の resolved variant と、解決に使える field/value variation ごとの variant を列挙して編集できる。Canvas からの直接編集は active variant に限定し、非 active variant は Inspector から明示的に編集する。

Agent / CLI の `node text set` は headless な source operation であり、preview context を暗黙に推測しない。variant context が明示されていない場合は HTML fallback content を編集対象にする。locale JSON を CLI で編集する場合は `i18n resource set --key <data-i18n-key> --locale <locale>` のように対象 key と locale を明示し、Mock State の保存値を resource 保存先として流用しない。`text variant set` は HTML 同梱 fallback / sample 用の互換操作として残る。

HTML 全体を直接編集する fallback は `ogkiln` / MCP の通常 tool では提供しない。node 単位操作で表現できない構造変更は、`node html insert` / `replace` で明示的な subtree 操作として表現する。

### Design Tokens

`ogkiln design-token list <project.ogp|current> --json` は `.ogp` の `cssLibrary` から `:root` の CSS custom property を抽出し、`name`、`value`、`category`、`reference` を返す。`reference` は node の CSS declaration に入れられる `var(--token-name)` 形式である。`category` は UI のための非 normative な表示 grouping であり、token 名の意味や利用可能な CSS property を制約しない。

`ogkiln design-token set/remove` は `cssLibrary` を直接更新する project-level 操作であり、HTML や同名 companion CSS を書き換えない。token を使う node 側の値は、通常の `node style set` で `background: var(--color-accent)` のように保存する。

page / document theme の背景色と文字色は root selector の標準 `background` / `color` から inspection・編集する。CLI / MCP は project-defined token とその `var(...)` 参照を通常の CSS dependency として扱い、token 名から accent / muted などの意味を決めない。

write operation は次の制約を持つ。

- token は `OpenGraphite.contract.json` の `designTokens.namePattern` に一致する CSS custom property 名であること。
- token は `designTokens.selector`（現行は `:root`）の rule に保存すること。
- token 値は CSS declaration value としてそのまま保存し、OpenGraphite 独自 IR へ分解しないこと。
- token 削除は空値として扱い、該当 custom property declaration だけを削除すること。

### Locale Typography

`locale-typography list/set/remove` は page または component canvas の authored CSS から、default root `font-family` と同じ scope の `:lang(<BCP47>)` override を inspection・編集する。`list` は全 declaration を返す。`set` / `remove` の `--locale` 省略または `default` は root declaration、任意の BCP 47 tag は locale rule を表す。

`list` は `rootSelector` と、各 declaration の `locale`、`selector`、`property`、`value`、`important`、`atRules`、`sourceOrder` を返す。`set` / `remove` は CSS source trace が示す既存 selector と declaration provenance を維持し、対象 value または declaration だけを最小差分で更新する。locale tag の固定 allowlist を持たず、未知 rule、comment、他 locale、element-level `font-family` override を変更しない。preview は標準 `lang` / `dir` を設定した WebKit の computed font を表示するが、CLI / MCP の source operation は preview state を暗黙に書き戻さない。

旧 `--og-font-family-default`、`--og-font-family-<locale>`、`--og-active-font-family` は明示 migration の入力としてだけ認識し、通常の list / set / remove から新規生成しない。

### Project Dependencies

App の Project セグメントは `.ogp` の新しい正本設定ではなく、project が参照している実装資源を選択する virtual surface である。CSS、runtime script、i18n runtime、locale JSON のように page をまたぐ依存性は Project セグメントで選択し、Inspector は可能な範囲で正本ファイルへ書き戻す。

`I18n Runtime` の `backend.loadPath` と `fallbackLng` が literal の場合は Project Inspector から編集できる。`lng: selectedLanguage()` や `loadPath: import.meta.env...` のような実装式は external / read only として扱い、OpenGraphite は変数名や env 参照を勝手に書き換えない。Page Inspector では共有 i18n runtime を read-only summary として表示し、編集は Project Dependencies へ移動して行う。

## Pencil Mapping

Pencil / OpenPencil の design document 操作は OpenGraphite では次のように対応する。

| Pencil / OpenPencil | OpenGraphite |
| --- | --- |
| `.pen` JSON IR | HTML 構造正本 + `data-og-*` metadata + companion CSS の node-scoped CSS declarations |
| node `id` | stable nodeは `data-og-internal-id` / typed `ogref`、未注釈nodeはinspection payloadのsession `reference` / `locator` |
| `get_editor_state` | `project inspect` + `page graph --page-id` / `page graph --component-id` |
| `batch_get` / tree / find / query | `node query` / `node get` |
| stable identity adoption | `node adopt` dry-run / explicit apply |
| `batch_design` insert | `node html insert` |
| `batch_design` update | `node style set` / `node attr set` / `node text set` |
| `batch_design` delete | `node delete` |
| `batch_design` move | `node move` |
| `batch_design` copy | `node copy --id-prefix` |
| `batch_design` replace | `node html replace` |
| `get_variables` / `set_variables` | project-defined token は `design-token list/set/remove`、利用箇所の標準 declaration は `node style set/remove`。 |
| `snapshot_layout` | 現時点では graph の構造情報。visual bounds は `screenshot_node` の切り抜き対象として WebKit から解決する。 |
| `get_screenshot` / `export_nodes` | `screenshot_canvas` / `screenshot_page` / `screenshot_node`。HTML を WebKit でレンダリングして PNG を保存する。 |

## MCP Resources

OpenGraphite MCP server は少なくとも次の resource を公開する。

- `opengraphite://contract/css`
- `opengraphite://project/sample`
- `opengraphite://project/current`
- `opengraphite://pages/sample`
- `opengraphite://pages/current`
- `opengraphite://components/sample`
- `opengraphite://components/current`
- `opengraphite://pages/sample/home/graph`
- `opengraphite://pages/sample/home/html`
- `opengraphite://components/sample/design-system/graph`
- `opengraphite://components/sample/design-system/html`

任意プロジェクト、任意ページ、任意 component canvas は tool の `projectPath` と `pageID` / `componentID` 引数で扱う。

## MCP Tools

OpenGraphite MCP server は少なくとも次の tool を公開する。

- `get_contract`
- `migrate_project`
- `validate`
- `build_project`
- `list_canvas_annotations`
- `get_canvas_annotation`
- `list_locale_typography`
- `set_locale_typography`
- `remove_locale_typography`
- `add_project_page`
- `create_project_page`
- `place_project_page`
- `set_project_page_document_context`
- `add_project_component`
- `create_project_component`
- `place_project_component`
- `set_project_component_document_context`
- `remove_project_component`
- `list_nodes`
- `screenshot_canvas`
- `screenshot_page`
- `screenshot_node`
- `query_nodes`
- `get_node`
- `adopt_node`
- `set_css_variable`
- `remove_css_variable`
- `set_node_attribute`
- `remove_node_attribute`
- `set_text_content`
- `insert_html`
- `replace_node_html`
- `delete_node`
- `move_node`
- `copy_node`

MCP の write tool は OpenGraphite app に直接命令しない。リポジトリ上の正本ファイルを更新し、app は外部ファイル変更同期で表示を追従する。

これは app 内操作の同期経路とは別の境界である。OpenGraphite app 内で発生した編集は、保存完了や外部ファイル変更通知を待たず、app cache の現在値として Canvas、Layers、Inspector、Project 依存性ビューなどの複数 surface へ即時同期する。永続化は cache 上の編集を正本ファイルへ確定する処理であり、app 内表示を一致させるための transport として扱わない。

`pageID` と `componentID` は同時指定できない。Pages HTML を編集する場合は `pageID`、Collection 内 component master HTML を編集する場合は `componentID` を指定する。

## External Synchronization

OpenGraphite app は `.ogp` に含まれる全 HTML ファイルの外部変更を検出し、ディスク上の正本 HTML を WebView に反映する。選択中ページは WebView 置換要求として履歴と選択状態を保ち、非選択ページは reload token によりキャンバス上のプレビューを再読み込みする。app 内で未適用の mutation または document replacement がある場合、選択中ページの外部変更を破壊的に上書きせず、ユーザーへ衝突として見える状態にする。

`.ogp` project manifest も外部変更監視の対象にする。`ogkiln project page add`、`ogkiln project page create`、`ogkiln project page place`、`ogkiln project component add`、`ogkiln project component create`、`ogkiln project component place`、`ogkiln project component remove` が entry と canvas 配置を更新した場合、または外部編集で `annotations` / `guides` が変わった場合、app は project manifest を再読み込みし、既存の選択 Chapter / Collection と選択ページ / component canvas を可能な限り維持したまま Canvas 上の配置、注釈、Guide を更新する。
