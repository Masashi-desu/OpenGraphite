---
name: opengraphite-css-contract
description: "OpenGraphite.css、optional data-og-* annotation、標準HTML/CSS、operation capability、layout、component、再利用可能なデザイン断片を使うHTMLの作成、レビュー、デバッグ、変換を支援するときに使う。OpenGraphiteのsource契約、capability evidence、component runtimeの説明や検証観点が必要なときに使う。"
---

# OpenGraphite CSS 契約

一般ユーザーが `OpenGraphite.css` で描画される HTML を書く、修正する、または OpenGraphite HTML/CSS 契約を確認するときに、この skill を使う。

## 対象

これは `OpenGraphite.css` を HTML document で利用する人のための契約説明である。ユーザーが standalone HTML / CSS を authoring しているものとして扱う。

OpenGraphite リポジトリ内の `public/` page や component HTML を編集する作業手順は、`opengraphite-page-editing` skill の責務である。ページ編集中に optional annotation、標準CSS、operation capability、layout、component の契約確認が必要な場合だけ、この skill も併用する。

ユーザーが独自の `OpenGraphite.css` や特定バージョンを提示した場合は、そのファイルを確認し、実際のルールを優先する。stylesheet が提示されない場合は、下記の公開契約を使う。

リポジトリに `OpenGraphite.contract.json` がある場合は、source HTML に残せる optional `data-og-*`、role、layout、編集可能 CSS、legacy migration input、operation capabilityの機械可読な正本として扱う。top-level `capabilityPolicy`の`operations`、`evidenceFields`、`legacyTypeAttribute`、`legacyReadOnlyHint`、`generated`、`queryMatch`を検証し、capability arrayはraw value昇順、queryはall-match、legacy typeはread-only hint、新規生成なしであることを確認する。runtime-private state は公開 contract に含まれない。annotation の欠落を contract 違反とみなさず、存在する identity / reference だけを検証する。説明には本文の契約を使ってよいが、検証向けの判断では JSON を優先する。

通常は、属性、変数、例から CSS 契約を直接説明する。利用質問に答えるためだけに、実装ファイルやビルドツールを必須にしない。

キャンバス前面の付箋と手書きは `.ogp` にだけ保存する collaboration annotation であり、この HTML / CSS 契約の対象外である。注釈そのものを `data-og-*`、`--og-*`、class、DOM node へ変換しない。注釈から明示的な実装指示を受けた場合だけ、通常の source edit として HTML / CSS を更新する。

Ruler、Guide、Grid は OpenGraphite.app のプレビュー補助であり、この HTML / CSS 契約の対象外である。表示設定は app 側、Guide の方向と world 座標は `.ogp` の Chapter / Collection `guides[]` に保持する。いずれも HTML、CSS、`data-og-*`、`--og-*`、runtime、build、screenshot へ変換または出力しない。

Canvas Object Reference は typed `ogref:node` / `ogref:component-node` が指す任意階層 node を、Chapter / Collection canvas 直下へ置く editor viewport である。配置 metadata は `.ogp` の `references[]` にだけ保存し、参照先 subtree の clone や host node を HTML object 内へ挿入しない。参照 viewport からの編集は元 node の HTML / companion CSS へ保存する。HTML 内で永続的な再利用構造が必要なら component master と `<og-instance>` を使う。

## コアモデル

OpenGraphite document は通常の HTML である。Canvas、Layers、Inspector、CLI、MCP は、OpenGraphite annotation のない標準 DOM も読み取る。`OpenGraphite.css` を使う互換的な document は次の情報を必要に応じて組み合わせる。

- 作者が選ぶ semantic tag name。
- AI 協業 identity、参照、binding、policy、provenance を示す optional `data-og-*` 属性。
- design value を示す標準 CSS property と、projectが任意に定義するgeneric design token。
- project の `components` segment にある optional な component master HTML と、pages 内の `<og-instance>` 参照。
- length、color、shorthand、gradient、`min()`、`max()`、`clamp()` などの標準 CSS 値。

class、標準`id`、tag、ARIA、通常attributeはそのままWeb sourceであり、selector、semantics、operation capabilityの根拠に使う。OpenGraphite固有annotationを、標準Webで表現できる意味や描画値の代替にしない。

## 基本セットアップ

既存の標準 HTML は属性を追加せず、そのまま project page / component resource として登録して inspection できる。

```html
<main id="landing-page">
  <article class="hero-card">
    <h1>OpenGraphite</h1>
  </article>
</main>
```

`html` / `head` / `body`の省略や、`table`内のimplicit `tbody` / `colgroup`も標準HTMLとして扱う。Agent graph、parent reference、source rangeにはauthored elementだけを返し、browserが補うelementは`:root`、descendant/child selector、cascade、inheritanceの評価にだけ使う。inspection、無編集roundtrip、adoption dry-runを理由に省略tagをsourceへ追加しない。

長期のAI協業でstable node referenceが必要な箇所だけ、dry-runとsource diffを確認した明示adoptでoptional identityを付ける。描画はsemantic tag / classと標準CSSに置き、identity annotationから推測しない。

```html
<link rel="stylesheet" href="OpenGraphite.css">

<main
  id="landing-page"
  class="landing-page"
  data-og-id="page"
  data-og-internal-id="page-node">
  <HeroTitle
    class="hero-title"
    data-og-id="title"
    data-og-internal-id="title-node">
    OpenGraphite
  </HeroTitle>
</main>
```

```css
.landing-page {
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding: 48px;
}

.hero-title {
  font-size: 56px;
  font-weight: 760;
  line-height: 1;
}
```

component 参照では、master を component canvas HTML に置き、page 側から component source link と optional runtime で参照する。

```html
<link rel="stylesheet" href="OpenGraphite.css">
<link rel="opengraphite-components" href="_components/design-system-components.html">
<script src="OpenGraphite.runtime.js" defer></script>
```

## 属性

- `data-og-id`: 人間可読・page-localなoptional collaboration identifier。既存の標準`id`を優先し、存在する場合は一意にする。stable `ogref`の根拠は`data-og-internal-id`が担う。
- `data-og-internal-id`: renameから独立したstable `ogref`用のoptional identity。通常の読み込みでは自動追加しない。
- `data-og-type`: 旧sourceに存在する場合だけ`legacyTypeHint`として読むlegacy input。operation capabilityや描画selectorには使わず、新規source、adoption、runtime、buildへ生成しない。
- layoutは標準CSSの`display`、`flex-direction`、grid property、各childの`position` / insetから導出する。旧`data-og-layout`は明示migrationのlegacy inputに限り、新規sourceへ追加しない。
- `data-og-component`: master root または `<og-instance>` が使う component identifier。
- component master は `.ogp` の登録resource、hyphenを含むCustom Element host、その直下の標準`template`から判定する。hostの通常の`variant`、template内の`slot` / `part`、ARIAの`role`を使い、旧`data-og-component-kind` / `data-og-variant` / `data-og-slot` / `data-og-part` / `data-og-role`は新規sourceへ生成しない。
- component template内の相対`href` / `src`はpage URLではなくcomponent master source fileのURLを基準にする。HTTP runtime、`file://` Canvas preview、screenshotで同じcomponent stylesheet / asset URLへ解決されることを確認する。
- 永続的なHTML非表示は標準boolean `hidden`を使う。CSS stateは`display` / `visibility`へ保存する。旧`data-og-hidden`は明示migration inputに限る。
- `data-og-text-source`: locale/runtime bindingのoptional metadata。折返しは標準`overflow-wrap` / `word-break`へ保存し、この属性を描画selectorにしない。
- `data-og-locked="true"`: 要素を locked として扱い、cursor を変える。
- `data-og-icon-library`、`data-og-icon-name`、`data-og-icon-source`: icon の出自と再取得方法を残す optional provenance。描画値は子の標準 SVG / CSS property が担う。

選択、直接編集、Focus、drag、reorder、frame preview、runtime expansion provenance は属性契約ではない。editor / runtime は native overlay、`:focus`、session 中だけの `contenteditable`、JavaScript object / `WeakMap`、individual `translate`、Web Animations API で管理し、source HTML、companion CSS、static build へ state を残さない。この editor state は `OpenGraphite.css` の読み込みを前提にしない。

`data-og-id` / `data-og-internal-id` はresource読み込みの必須条件ではない。missing annotationはvalidation errorにせず、存在するIDの重複と存在するreferenceの破損だけを診断する。open、load、preview、inspection、validation、build、無編集保存はannotationを自動追加しない。旧`data-og-type`の欠落もerrorではなく、存在しても自動補完や描画defaultの根拠にしない。

## Placement preview state

component canvas の `<og-placement>` が別状態を表示するとき、状態値は source HTML ではなく `.ogp` の `canvas.previewContext.placementMocks` に置く。placement key は `data-og-internal-id` の entry を優先し、見つからない場合だけ `data-og-id` の entry へ fallbackする。両方のentryをmergeしない。canvas全体の`fieldMocks`を基底に、選択したplacement entryが同名fieldをoverrideする。

標準 host state は project-defined な汎用 field で表す。

- `host.variant=code` / `host.variant=preview` / `host.variant=collapsed`: clone host の通常の `variant` attributeへproject-defined tokenを投影する。
- `host.class=is-loading`: authored classを残し、空白区切りclass tokenを追加する。
- `host.aria-busy=true` / `host.aria-expanded=false`: 通常のARIA attributeへ投影する。
- 標準boolean attributeは`0` / `false` / `no` / `off`で不在、それ以外でpresent-emptyにする。

`data-og-*`、event handlerの`on*`、`id`、`style`、`slot`、`part`はpreviewから注入しない。project runtime、App Canvas、CLI/MCP screenshotは値を生成cloneにだけ一時投影し、component companion CSSの`:host([variant~="preview"])`、`:host(.is-loading)`などとbrowser computed styleへ表示判断を委ねる。source master、placement host、serialization、static buildへstateを残さない。code / preview / loading / collapsedの状態例を変える場合は、Sample `.ogp`、component HTML、同名companion CSS、Tutorial登録を同じ変更単位で同期する。

## Progressive adoption

agent graph は各nodeに `annotationStatus` (`none` / `partial` / `complete`) と `referenceStability` (`session` / `stable`) を返す。両者は独立し、一意な `data-og-internal-id` があればpartialでもstable、それ以外はsessionになる。session referenceにはdocument URL、既存標準 `id` を優先した安全なselector、DOM path、source range、content hashからなるlocatorが付く。

stable referenceが必要なnodeだけ、inspectionで得たlocatorを明示adoptする。

```bash
ogkiln node adopt Project.ogp --page-id home --reference <session-reference> --scope node --json
ogkiln node adopt Project.ogp --page-id home --reference <target-reference-from-dry-run> --scope node --apply --json
```

最初のcommandはdry-runでsourceを書かず、候補のstable reference一覧、unified diff、apply専用proposal `targetReference`を返す。proposalは現在のsource range/content hash、document全体のbefore hash、正規化済みscope/display IDを束縛する。applyではその `targetReference` と同じscope/display IDを渡し、すべてを再検証してからだけoptional identityを保存する。通常graphのsession referenceを直接applyへ渡すことや、stale source / parameter変更は拒否する。`--scope subtree` は対象subtreeをまとめて候補にできる。既存標準 `id` や安全なauthored selectorが使える場合はそれを優先し、不要なannotationを増やさない。標準 `id` とは別の人間可読annotationを明示的に必要とする場合だけ `--display-id` を追加する。

旧 source にある `data-og-selected`、`data-og-editing`、`data-og-editor-focus-*`、drag / reorder / frame preview / editor artifact / runtime provenance 系の `data-og-*` は、明示 migration が認識する legacy input に限る。通常の authoring では追加せず、open、preview、inspection、無編集保存を migration とみなさない。

## Explicit Web contract migration

Web contract `0.1.0` のprojectを標準sourceへ移すときだけ、project-scoped migrationを明示実行する。新規projectと生成resourceは最初からWeb contract `1.0.0`を使い、`.ogp`のschema versionとAgent JSON `schemaVersion`自体は変更しない。

```bash
ogkiln migrate Project.ogp --target-version 1.0.0 --json
ogkiln migrate Project.ogp --target-version 1.0.0 --proposal <proposal-reference-from-dry-run> --apply --json
```

1回目は必ずno-writeのdry-runにする。`legacyCatalogVersion: "1"` / `preserveUnknownDataAttributes: true`の固定options、target version、project manifest、全対象resourceのcanonical relative pathとUTF-8 BOMを含むraw-byte SHA-256 content hashを束縛した`proposalReference`と全`diffs`をreviewする。対象closureはmanifest、project CSS library、登録HTML、存在するcompanion CSS、project内actual local linked stylesheet / executable script、actual linked/embedded CSSから再帰的に辿るlocal `@import`であり、inline / embedded CSSはHTML candidate内で扱う。source kindはcharacter-reference復号後のHTML属性値で決め、URL extensionでは補正しない。`<style>`は`type`省略/exact empty/ASCII-CI exact `text/css`、`<link rel~=stylesheet>`は`type`省略またはHTTP-whitespace-trim済みMIME essence `text/css`だけをCSSとし、present-empty link typeは非CSSである。`<script>`はexact empty、ASCII-CI exact `module`、またはexact JavaScript MIME typeだけをexecutableとし、`type`がobsolete `language`に優先する。style/script typeの前後空白・parameter、JSON/JSON-LD/import map/speculation rules/unknown data blockはopaqueである。HTML/CSS whitespaceはTAB/LF/FF/CR/SPACE、HTTP whitespaceはFFを除く4文字で、NBSP/vertical-tabはraw valueに残す。HTML non-void `/>`はelementを閉じず、SVG/MathML foreign self-closingは閉じる。semicolonなしdecimal/hex numeric character referenceもsemantic decodeし、無関係なcase/entity/CRLF/BOM/triviaを保持する。actual kindのextensionless pathと変更しないlocal dependencyもproposal hashへ含める。2回目のapplyは同じtarget/optionsとproposalを要求し、proposalなしは`migration-apply-requires-proposal`、別project、parameter変更、manifestまたはresourceの追加・削除・rename・raw-byte content変更は`stale-migration-proposal`としてproject全体をatomic no-writeにする。project rootの`OpenGraphite.contract.json`はApp用tool configurationであり、proposal targetにもdiff/apply candidateにもせずbytesを維持する。MCPでは`migrate_project {project,targetVersion?,proposalReference?,apply?}`を同じcore経路へ渡す。

known legacy HTML/CSSはcatalogに従って標準HTML/CSSへ変換する。optional identity (`data-og-id` / `data-og-internal-id`)、component/source reference、binding、editing policy、icon provenanceは維持し、OpenGraphiteがownershipを持たない未知の`data-*`も保持する。HTMLのexact safe mappingは次のとおり。

- `data-og-type=page|frame|text|button|image|icon` → `.og-migrated-v1-type-*`
- `data-og-layout=vertical|horizontal|absolute` → `.og-migrated-v1-layout-*`
- `data-og-hidden=true|false` → 標準`hidden`の追加またはlegacy属性除去。`hidden="until-found"`や反対意味の既存destinationはblocking
- `data-og-icon-mask=true|false` → `.og-migrated-v1-icon-mask`の追加またはlegacy属性除去
- `data-og-variant` / `data-og-part` → `variant` / `part`。異値destinationはblocking
- `<og-placement data-og-role="component-placement">`の冗長roleだけ除去

legacy component master、`data-og-slot`、sourceのplacement mode/state、unsafe roleは構造を推測せずblockingにし、registry / template / slot / placement sourceと`.ogp`を手動で同じstandard host stateへ揃えてから再dry-runする。source placementへ`variant`を追加しない。

CSS selectorは上記class / standard attributeへraw token patchし、hidden selectorは`[hidden]:not(:where([hidden="until-found" i]))`へ移す。既知design custom propertyは`--migrated-v1-*`へrenameし、対象はpage-background、text-color、muted-color、accent、accent-foreground、font-family-default、dynamic font-family-<locale>、active-font-family→font-family-active、object-fit、stroke-width、icon-url、scale-x、scale-yである。visual/cascade parityのため、catalog v1は既存`transform: scale(var(--og-scale-x), var(--og-scale-y))`のdeclaration構造を保持してvar名だけrenameし、無条件にindividual`scale`へ組み替えない。新規・手動標準化sourceではindividual`scale`を使う。runtime-only `--og-edit-*` / preview / drag / reorder declarationは除去し、通常propertyの`var()`はfallbackまたは`unset`へmaterializeする。project CSS、executable inline/linked JavaScript、inline event handlerがlegacy inputを読む場合や、実際に新規生成するclass・標準attribute・custom propertyを観測する場合はblockingとする。dot/bracket/optional access、method alias、destructuring、borrowed `getAttribute.call(node, ...)` / `setAttribute.apply(node, [...])`は同じattribute evidenceとして扱うが、exact名は実際に新規生成するdestinationとだけ交差し、dynamic名だけをwhole-attribute evidenceにする。whole `dataset` / `style` observerとCSSの`style` value selector / `attr(style)`は、実際に削除するdataset attribute、inline style実変更、生成custom propertyとだけ交差する。whole attribute、dynamic selector/computed DOM、AttributeNode observerはHTML attribute変更、whole markup observerはembedded-style移行を含むHTML source変更とだけ交差する。external CSS変更はCSSOM observer、embedded CSS変更はCSSOMまたはactual style-text observerとだけ交差する。ID-based style/link evidenceはinline/linked runtimeの参照元HTMLに実在するCSS ownerへ束縛し、別pageの同名非style要素、runtime生成style、通常要素のtext、`CSSStyleDeclaration.cssText`、generic `.sheet` / computed accessを誤衝突させない。manifest preview変更はglobal preview contextからprovenanceを追える`placementMocks` / whole-context alias chain、または実際に新規生成するexact/static-concatenated `host.*` fieldとだけ交差し、fields/document-only accessや無関係objectの同名propertyはsafeとする。observerだけのclean projectや無関係なactual mutationはblockしない。semanticに同値のstandard destinationが既にある場合はgenerated conflictにせず、case・quote・character referenceと周辺raw bytesを維持してlegacy tokenだけを除去する。JavaScript comment、CSS comment/string/`url()`の一致文字列、偽`@import`もraw保持する。

reserved legacy CSS propertyの未知名は`unknown-legacy-css-property`、未対応targetは`unsupported-migration-target-version`でblocking/no-writeにし、値やselectorを推測変換しない。登録対象でlegacy inputを検出したprojectに限り、external / 解決不能なbase・stylesheet・runtime、曖昧なimport、runtime module dependency、local legacy reader、missing / project root外 / unreadableなdiscovered dependency、同一canonical URLのCSS/runtime kind conflict (`migration-resource-kind-conflict`) をblockingにする。legacy input がない clean standard projectは変更不要のno-opとする。project loadは`migration-project-load-failed`、importは`unsupported-legacy-import-reference`、module closureは`unsupported-legacy-runtime-dependency`で報告する。blocking dry-runはpartial diff/proposalを返さない。applyは各candidateのcommit直前に変更しないdependencyを含むproposal全closureのraw bytes・存在・canonical path解決を再検証し、staleなら先行commitをrollbackして`stale-migration-proposal`を返す。rollbackはmigration後bytes/modeとのcompare-and-swapで、commit後の外部編集を上書きせず`migration-rollback-failed`を返す。write失敗は`migration-write-failed`としてrollbackする。

`.ogp`は通常proposal hashの束縛対象だけであり、strictなpages/components canvasの`previewContext.placementMocks`にknown legacy fieldが存在する場合だけdiff/apply対象にする。`codeViewerMode: "preview"`は`host.variant: "preview"`、`placementMode: "collapsed"`は`host.variant: "collapsible collapsed"`へ変換し、未知fieldとraw formattingを保持する。既存destinationの異値、未対応mode、重複keyはblocking/no-writeにする。generated cloneのstandard host attribute/class/ARIAとauthored `:host(...)` CSSからcomputed stateを得て、source HTMLへpreview stateを追加しない。`sourceContractVersion`はlocal contractではなく登録対象sourceのlegacy token検出から決定し、旧tool configurationが残ってもapply後の再dry-runがtarget version / `changed: false` / 空`diffs`になることを確認する。

compatibility readerは次の`migrationPolicy.legacyReaderRemovalConditions`をすべて満たすまで、pre-migration inspectionと明示migration入力にだけ残す。

- `minimum-supported-web-contract-version-is-greater-than-0.1.0`
- `official-and-generated-assets-contain-no-known-legacy-tokens`
- `legacy-fixtures-and-release-notes-are-retired-by-an-explicit-major-release`

reader削除では一部条件だけを根拠にせず、contract、reader、App、CLI、MCP、legacy fixture、docs/skillを同じ変更単位で同期する。

## Operation capability

nodeを`page` / `frame` / `text` / `button` / `image` / `icon`の単一分類へ縮約しない。Agent graphはstandard-Web evidenceから、次のcapabilityをraw value昇順のdeterministicな`capabilities`配列として返す。

- `drag-position`
- `edit-control`
- `edit-icon`
- `edit-layout`
- `edit-link`
- `edit-media`
- `edit-text`
- `group`
- `receive-children`
- `reorder-flow`
- `ungroup`

`capabilityEvidence`は`isProjectResourceRoot`、`isNativeControl`、`isCustomElement`、`isLink`、`hasDirectText`、`hasElementChildren`、`hasMediaContent`、`hasSVGContent`、`hasMaskContent`、optional `ariaRole`、optional `resolvedDisplay`を返す。同じnative buttonが`edit-control`と`edit-text`を同時に持つように、capabilityは複数になり得る。未知の標準elementやCustom Elementにも根拠のある操作だけを付与し、曖昧なenumへ強制しない。

child insertion / receptionは`receive-children`、inline text sessionは`edit-text`、link / media / icon / native control Inspectorは対応する`edit-*`、layout Inspectorは`edit-layout`、Canvas dragは`drag-position`、flow reorderは`reorder-flow`、group commandは`group` / `ungroup`を要求する。legacy hintからcapabilityを補完しない。

`node attr set/remove`とMCPの対応toolは、contractの`editableAttributes`に含まれる標準HTML属性と保持対象OpenGraphite metadataを扱う。標準`hidden` / `href` / `target` / `aria-label` / `value` / `src` / `alt`は、対象tag/content modelとoperation capabilityが対応するときだけ編集し、`data-og-*`専用interfaceとして説明しない。contract外は`disallowed-attribute`、対象不適合は`unsupported-node-capability`でatomic no-writeにする。空文字のsetはpresent-empty attributeを保持し、tokenを削除するのは明示removeだけである。存在しないtokenのremoveはsourceを変更しない。

CLIの`node query --capability <name>`は反復指定でき、all-matchで絞り込む。MCPは`query_nodes.capabilities: string[]`を同じ経路へ渡す。互換`--type` / `query_nodes.type`はsourceに実在する`legacyTypeHint`のexact-matchだけであり、capability filterではない。

## レイアウト

- Flexは`display:flex|inline-flex`と`flex-direction`、Gridは`display:grid|inline-grid`とtrack property、Blockは通常の`display:block`を正本にする。
- absolute placementは親enumにせず、containing blockの標準`position`と各child自身の`position:absolute` / insetで表す。flow childとpositioned childを同じ親に混在できる。
- layout inspectionはCSS source traceとWebKit computed styleを分離する。source traceはselector、cascade、specificity、inheritance、`!important`、custom property、shorthand、at-rule、commentを保持し、computed `display`からoperation capabilityを決める。
- project-aware source traceはproject library、same-named companion CSS、HTML document orderの各local linked stylesheetと各`<style>`をraw連結せず別ASTとして扱い、既存inline `style`はHTML sourceとして合成する。unlinked project libraryは先頭、unlinked companionは末尾のfallback sourceになる。candidateの`sourceID`、`sourceKind` (`project` / `companion` / `linked` / `embedded` / `inline`)、`sourceEditable`、`stylesheetOrder`、source内`sourceOrder`、`inherited`を確認し、別sourceの同名selectorを同一fileとみなさない。
- responsive layoutはprojectのauthored `@media`を使う。CLIの`page graph` / `node query` / `node get`ではactiveと確認したconditionをrepeatable `--active-media <condition>`、MCPでは`activeMediaQueries: string[]`として渡す。省略時にviewportを推測しない。
- responsive winnerを編集・削除する`node style set/remove`とMCPの`set_css_variable` / `remove_css_variable`にもinspectionと同じactive media集合を渡す。`<link media>` / `<style media>` とstylesheet内`@media`を同じ集合で評価し、省略時はactiveと推測しない。
- node style mutationはproject CSSをcascade解決には含めるが、`.ogp`の`cssLibrary`を直接変更しない。direct inline / companion winnerは既存declarationを最小差分更新できる。read-only project / linked / embedded winnerへのsetはactive media scopeとpriorityを保つ安全なcompanion overrideだけを許可する。安全なspecificityを構成できなければ`css-specificity-override-unsafe`、read-only winnerだけのremoveは`read-only-css-winner`でno-writeにする。longhandがshorthandから解決されるremoveは`shorthand-css-removal-unsupported`、set後のwinnerを確認できない場合は`css-mutation-postcondition-failed`でno-writeにする。
- 全stylesheet candidateと親computed値を合成してからcustom property / `var()`を一度だけ最終解決する。`var()`を含む対応shorthandはraw shorthand provenanceを維持し、置換後にlonghand componentへ展開する。展開不能なcomponentは該当node/propertyをincompleteにしてwrite-blockする。
- CSS-wide `inherit` / `initial` / `unset`はCSS identifier escapeもsemantic復号し、authored spellingは保持する。`revert` / `revert-layer`は同じauthor origin内の前candidateを再利用せず、継承propertyは親computed値、非継承propertyはHTML UA fallbackへ委ねてnode-level incompleteにする。共有headless validatorは対応propertyのkeyword、geometry、標準unit、typed math、grid track、数値grammarを検証し、number / percentage / length / length-percentageを区別する。無効・未対応なauthored sourceはraw保持して該当node/propertyをincompleteにし、resolved winnerを断定しない。構文上有効な`env()` / `anchor()` / `anchor-size()`もraw保持するが、headlessではenvironment依存のため同じnode guardにする。明示invalid値、top-level `;`による別declaration、top-level `!important`のvalue注入は`invalid-css-property-value`でatomic no-writeとし、environment依存値のsetはincomplete provenanceとしてatomic no-writeにする。実`@layer`順序は対応済みとみなさない。
- `hidden="until-found"`はdeclaration不在時だけheadless `content-visibility:hidden` fallbackを持ち、author `initial` / `unset` / `visible`はresolved `visible`として上書きしても標準`hidden` source intentを変更しない。
- 外部・root外・読取不能stylesheet、未解決`@import`、malformed CSS、未対応layer/property/selectorを含むgraphはsource-wide incompleteであり、warning `incomplete-css-provenance` と既知candidate inspection、page/各nodeの`hasIncompleteCSSProvenance: true`を返す。全CSS set/removeは`incomplete-css-provenance-write-blocked`でatomic no-writeとし、import先やlayer orderを推測しない。
- matching `@supports` / `@container` / `@scope` / `@document` / `@starting-style`、graph内にkeyframes sourceがありactive `animation-name` / `animation`を持つnode/target、unknown initial値や`revert` / `revert-layer`等は該当node/targetだけをnode-level incompleteにする。`@keyframes` / `@-webkit-keyframes`定義だけをsource-wide incompleteにしない。該当targetへのwriteは`incomplete-css-node-provenance`と`incomplete-css-provenance-write-blocked`でno-writeにする。page集約flagだけを理由に完全な別nodeをblockしない。
- `hidden` source state、authored CSSの`display` / `visibility`、WebKit computed `display` / `visibility` / `content-visibility`、ancestorを含むrendered hidden判定を別々に扱い、inspectionや無編集保存で相互変換しない。

## 標準CSSとdesign token

nodeのdesign valueは`width`、`height`、`padding`、`gap`、`background`、`border`、`font-size`、`object-fit`、`stroke-width`、`scale`などの標準CSS propertyへ保存する。page / document themeの正本もroot selectorの標準`background` / `color`と通常のcascadeである。

複数ruleで同じ値を共有するときだけ、projectが自由に命名するgeneric design tokenを使う。project-wide tokenは`.ogp`の`cssLibrary`が指すCSS fileの`:root`へ`--color-accent`、`--space-medium`、`--radius-small`のようなCSS custom propertyとして置く。Project Inspector、`ogkiln design-token`、MCP design-token toolsがこのproject-level resourceを編集し、node側はcompanion CSSの標準property値から`var(--color-accent)`のように参照する。OpenGraphiteはtoken名やtheme上の意味を予約しない。

reserved `--og-*`と`data-og-icon-mask`は明示migrationのlegacy inputに限る。新規source、snippet、runtime、buildへ生成しない。default / locale fontはrootの標準`font-family`と同じscopeの`:lang(<BCP47>)` rule、media fitは実体`img` / `video`の`object-fit`、inline SVGは実体の`stroke-width`、mask URLはmask childの`mask-image` / `-webkit-mask-image`、永続flipは標準`scale`へ移す。

`scale` / `rotate` / `transform`はブラウザの標準transform modelに従って独立に合成し、一つのproperty編集で別propertyを書き換えない。dragはsession中だけindividual `translate`、reorderはWeb Animations APIを使い、authored transformやsourceへ操作stateを残さない。editor-only寸法、locale preview、drag、reorderもreserved variable contractにはしない。

## 標準roleとvisual variant

ARIA semanticsは標準`role`、component variantはCustom Element hostの通常の`variant` token attributeで表す。`page-preview`、`landing-hero`、`primary-button`、`secondary-button`、`card`、`eyebrow`、`muted`のようなvisual roleは生成せず、semantic tag、class、標準role、component host attributeとcompanion CSS selectorで表す。component placementは`og-placement`要素名から判定し、旧`data-og-role="component-placement"`を要求しない。

## オーサリングルール

- design value は標準 CSS propertyへ保持し、共有が必要な値だけgeneric design tokenを参照する。
- Google Fonts など外部 Web font を使う場合、読み込みは通常の `<link rel="stylesheet" href="...">` として HTML `<head>` に残し、選択値は標準 `font-family` declaration に保持する。
- i18n の翻訳文は locale resource に置くが、locale typography は root の `font-family` と同じ scope の `:lang(...)` rule に置く。text node 側の `font-family` はその要素だけの明示 override として扱う。
- preview は clone の標準 `lang` / `dir` だけを一時変更し、表示 font は computed style から確認する。source rule の編集では selector、at-rule scope、specificity、source order、`!important` と declaration provenance を保持する。
- `padding:14px 20px`、`border:1px solid rgba(...)`、`box-shadow:0 18px 44px rgba(...)` のような標準shorthandを保持する。
- 有用な場合は`width:min(100%,560px)`や`background:linear-gradient(...)`のようにCSS functionを標準propertyで直接使う。
- sourceにあるshorthand、custom property、comment、unknown ruleを独自IRへ分解せず、selector / at-rule / cascade provenanceとraw spellingを保持する。
- class、標準 `id`、tag、ARIA、通常のattributeを通常のWeb sourceとして保持する。inspectionやCSS書き戻しでは既存の安全なselectorを優先し、OpenGraphite都合でclassをannotationへ変換しない。
- snippet を生成する場合もannotationを必須にしない。長期のAI協業用stable identityが要件なら、明示adopt相当の合意と差分を経て必要なnodeだけへ `data-og-id` / `data-og-internal-id` を付ける。
- 再利用する multi-node component は `.ogp` の `components[]` に登録された component canvas HTML に置く。runtime または build expansion が必要な場合、page は `<og-instance>` 参照で軽量に保つ。
- 軽量な source-first project には `OpenGraphite.runtime.js` を使う。static deployment、SEO、no-JS delivery が重要な場合は `ogkiln build` を使う。
- masterはhyphenated Custom Elementの直下に`template`を置き、その中の標準`slot`をnamed/default outletとして使う。page側はlight DOM childの標準`slot`属性で割り当て、複数nodeは同じ名前をそれぞれに付ける。公開styling hookは標準`part`、variantはhostの通常の`variant`を使う。

## よく使うパターン

vertical section:

```html
<section class="features">
  ...
</section>
```

```css
.features {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 32px;
}
```

horizontal action row:

```html
<nav class="actions" aria-label="Primary actions">
  <a href="/start">Start</a>
  <a href="/learn">Learn more</a>
</nav>
```

```css
.actions {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 12px;
}
```

image frame:

```html
<figure class="preview" data-og-id="preview">
  <img class="preview-media" src="preview.png" alt="Preview">
</figure>
```

```css
.preview {
  width: min(100%, 640px);
  height: 360px;
  margin: 0;
  overflow: hidden;
  border-radius: 18px;
}

.preview-media {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

CDN mask icon:

```html
<Icon
  class="sparkles-icon"
  data-og-icon-library="lucide"
  data-og-icon-name="sparkles"
  data-og-icon-source="cdn">
  <span class="sparkles-mask" aria-hidden="true"></span>
</Icon>
```

```css
.sparkles-icon {
  display: inline-flex;
  width: 24px;
  height: 24px;
  color: currentColor;
}

.sparkles-mask {
  display: block;
  width: 100%;
  height: 100%;
  background-color: currentColor;
  -webkit-mask-image: url("https://cdn.example/icons/sparkles.svg");
  mask-image: url("https://cdn.example/icons/sparkles.svg");
}
```

absolute placement:

```html
<section class="canvas">
  <span class="badge">New</span>
</section>
```

```css
.canvas { position: relative; }
.badge {
  position: absolute;
  left: 24px;
  top: 32px;
}
```

component master:

```html
<feature-card
  class="feature-card"
  data-og-id="feature-card-master"
  data-og-component="feature-card">
  <template>
    <article class="feature-card__surface" part="surface">
      <header class="feature-card__title">
        <slot name="title">Fallback title</slot>
      </header>
      <div class="feature-card__body">
        <slot>Fallback body</slot>
      </div>
    </article>
  </template>
</feature-card>
```

```css
.feature-card__surface {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 28px;
  border-radius: 6px;
}

.feature-card__title {
  font-size: 28px;
  font-weight: 800;
}

.feature-card__body {
  color: var(--color-text-muted);
}
```

component instance:

```html
<og-instance
  data-og-id="availability-card"
  data-og-component="feature-card"
  variant="featured">
  <span slot="title">Availability-ready card</span>
  <span>Pages keep references while the master stays reusable.</span>
</og-instance>
```

## デバッグ

描画がおかしい場合は次を確認する。

1. `OpenGraphite.css` とpage/componentの同名companion CSSが期待したURLで読み込まれているか確認する。
2. 標準HTMLやCustom Elementのinspectionにannotationは不要である。期待する操作が見えない場合は`capabilities`と`capabilityEvidence`を確認し、`data-og-type`を追加して回避しない。
3. 対象nodeのWebKit computed `display` / `flex-direction` / grid propertyと、authored traceのwinnerを別々に確認する。traceでは`sourceID` / `sourceKind` / `sourceEditable` / `stylesheetOrder` / `sourceOrder` / `inherited`も確認する。
4. design valueがvalidな標準CSS declarationで、selector / at-rule scope / priorityが意図どおりか確認する。
5. image / video sizingではwrapperのsemantic tag / classと、実体elementの標準`width` / `height` / `object-fit`を確認する。iconは実体SVG / mask / imageとDOM relationを確認する。
6. absolute placementでは、containing blockの`position`と対象child自身の`position:absolute` / insetを確認する。flowへ戻す操作は対象childのposition declarationだけを明示diffで変更し、nested childや寸法を暗黙変更しない。
7. responsiveで形が変わる場合は、実viewportのcomputed styleと、headless inspectionへ渡した`--active-media` / `activeMediaQueries`が同じauthored conditionを指すか確認する。
8. `<og-instance>` では、page に valid な `rel="opengraphite-components"` link があり、runtime expansion を使う場合は `OpenGraphite.runtime.js` が読み込まれ、master側に一致する`data-og-component`を持つhyphenated Custom Elementと直下`template`があることを確認する。named/default slot assignment、fallback、`variant`、`part`は標準DOM semanticsとして確認する。
9. placement previewが期待と違う場合は、`.ogp`のinternal-ID entry、fallbackのdisplay-ID entry、`host.*` field、clone hostのstandard attribute/class/ARIA、shadow tree内の`:host(...)` rule、最終computed `display` / `visibility`の順に確認する。source HTMLへpreview stateを追加して回避しない。
10. runtime preview は正しいが deployment output が違う場合は、`ogkiln build <project.ogp|current> --output <dir>` を確認し、同じtemplateがDeclarative Shadow DOMへ展開され、nested componentとslot順序が一致するか生成HTMLをinspectする。`.ogp`のpreview stateはdeployment outputへ注入されない。
11. 未注釈nodeがLayersやagent graphに見えない場合は、annotationを追加する前に通常DOM enumerationを確認する。stable mutationが必要ならgraphのsession locatorを使ってadopt dry-runを行い、diffを確認してからapplyする。
12. `hasIncompleteCSSProvenance`が`true`ならwarningを確認し、外部/root外/読取不能stylesheet、未解決`@import`、malformed source、未対応at-rule/selectorを解消するまでCSS mutationを行わない。computed値が表示されてもauthored winnerを完全に特定できたとはみなさない。
