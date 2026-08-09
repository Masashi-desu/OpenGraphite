# OpenGraphite MCP Specification

OpenGraphite MCP server は stdio JSON-RPC server として動作し、AI client に OpenGraphite project (`.ogp`) の resources と tools を公開する。server 名は `OpenGraphite` とする。HTML は構造と参照の正本、同名 companion CSS は新しいnode-scoped overrideの書き込み先であり、project / linked / embedded / inline CSSもinspection対象のauthor sourceとして扱う。Chapter / Collection の付箋・手書きは `.ogp` 専用 metadata とする。

## Runtime

```bash
node MCP/OpenGraphite/server.mjs
```

write tool は OpenGraphite app に直接命令しない。すべて `Scripts/ogkiln` へ委譲し、CLI と MCP が同じ validation / diagnostics / HTML / companion CSS write path を共有する。

## Project Scope

MCP tool の対象 project は常に `projectPath` で指定する。`projectPath` は `.ogp` path または `current` を受け付ける。`current` は OpenGraphite.app が最後に開いた `.ogp` を Application Support のレコードから解決する。

page / component canvas / node を対象にする tool は、`pageID` または `componentID` のどちらか一方で対象 HTML を指定する。コピーされた値は `ogref:<type>:...` 形式で、`pageID` は `ogref:page:<chapterInternalID>:<pageInternalID>`、`componentID` は `ogref:component:<collectionInternalID>:<componentInternalID>` を指す。一意な `data-og-internal-id` を持つ node は raw internal ID または stable `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` で解決する。internal IDのないnodeはgraphが返すsession-scoped `reference` と `locator` でinspection / adoptionの対象にする。stable typed node 参照を使う場合は `pageID` / `componentID` を省略できる。session reference、selector、DOM pathはinspectionまたはadoption専用で、対象canvasを `pageID` / `componentID` の一方で指定する。両方を同時に渡す呼び出しは invalid である。

MCP は resource の open、resource read、`list_nodes`、`query_nodes`、`get_node`、validation、build を adoption とみなさない。これらの読み取りで source HTML に `data-og-id`、`data-og-internal-id`、`data-og-type` を追加しない。

MCP は HTML path を直接書き換える tool を提供しない。`.ogp` にない既存 HTML は `add_project_page` または `add_project_component` で可視リストへ追加し、新規 HTML は `create_project_page` または `create_project_component` で HTML と同名 companion CSS の作成と登録を同時に行う。配布用の静的 HTML が必要な場合は `build_project` で `<og-instance>` を、登録済みhyphenated Custom Elementの直下`template`からDeclarative Shadow DOMへ展開する。named/default `slot`、host `variant`、`part`、nested componentはbrowser runtimeと同じsource semanticsを使い、旧component表示属性を生成しない。

Canvas annotation tool は読み取り専用である。`list_canvas_annotations` / `get_canvas_annotation` は `.ogp` を読むだけで、HTML / CSS / runtime / build 成果物を更新しない。schema と座標の正本は [CanvasAnnotations.md](CanvasAnnotations.md) とする。

project summary resource は Chapter / Collection の `.ogp` Guide 数を `guideCount` として返す。個別 Guide の読み書き tool は提供せず、app が `guides[]` を編集する。schema と screenshot / build 除外契約は [CanvasAids.md](CanvasAids.md) を正本とする。

project summary resource は Chapter / Collection の Canvas Object Reference 配置数を `referenceCount` として返す。参照配置の読み書き tool は提供せず、app が `.ogp` の `references[]` を編集する。配置は HTML object 内へ挿入せず、build と MCP screenshot へ出力しない。schema と編集同期契約は [CanvasObjectReferences.md](CanvasObjectReferences.md) を正本とする。

## Resources

| URI | MIME | Description |
| --- | --- | --- |
| `opengraphite://contract/css` | `application/json` | `OpenGraphite.contract.json` |
| `opengraphite://project/sample` | `application/json` | sample `.ogp` の解決済み project summary |
| `opengraphite://project/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の project summary |
| `opengraphite://design-tokens/sample` | `application/json` | sample project の CSS library に保存された design tokens |
| `opengraphite://design-tokens/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の design tokens |
| `opengraphite://pages/sample` | `application/json` | sample project の pages |
| `opengraphite://pages/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の pages |
| `opengraphite://components/sample` | `application/json` | sample project の component collections |
| `opengraphite://components/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の component collections |
| `opengraphite://pages/sample/home/graph` | `application/json` | sample project `home` page の node graph |
| `opengraphite://pages/sample/home/html` | `text/html` | sample project `home` page の正本 HTML |
| `opengraphite://components/sample/design-system/graph` | `application/json` | sample project `design-system` component canvas の node graph |
| `opengraphite://components/sample/design-system/html` | `text/html` | sample project `design-system` component canvas の正本 HTML |

contract resourceはWeb contract version `1.0.0`を返す。top-level `migrationPolicy`は`explicitOnly: true`、`dryRunRequired: true`、`supportedSourceVersions: ["0.1.0"]`、`targetVersion: "1.0.0"`、`legacyReaderRemovalConditions`を持つ。`capabilityPolicy`はraw value昇順の`operations`、`evidenceFields`、pre-migration legacy hint policy、`generated: false`、`queryMatch: "all"`を返し、CLI / MCP / Appの判定境界を同じ機械可読値で固定する。

任意の project / page / component canvas は resource URI ではなく tool 引数の `projectPath` と `pageID` / `componentID` で扱う。

## Tools

| Tool | Purpose | ogkiln mapping |
| --- | --- | --- |
| `get_contract` | active contract を返す | `contract get` |
| `migrate_project` | legacy Web contractをdry-runし、同じproposalだけ明示applyする | `migrate <project>` |
| `validate` | `.ogp` を検証する | `validate <project>` |
| `build_project` | Pages の `<og-instance>` を component master で静的展開する | `build <project>` |
| `list_canvas_annotations` | Chapter / Collection の注釈要約を返す | `annotation list` |
| `get_canvas_annotation` | stroke / point を含む単一注釈を返す | `annotation get` |
| `list_design_tokens` | Project CSS の `:root` design token を返す | `design-token list` |
| `set_design_token` | Project CSS の `:root` design token を設定する | `design-token set` |
| `remove_design_token` | Project CSS の `:root` design token を削除する | `design-token remove` |
| `list_locale_typography` | default / locale 別の標準 `font-family` source rule を返す | `locale-typography list` |
| `set_locale_typography` | root または `:lang(<BCP47>)` の `font-family` を設定する | `locale-typography set` |
| `remove_locale_typography` | root または `:lang(<BCP47>)` の `font-family` を削除する | `locale-typography remove` |
| `add_project_page` | 既存 HTML を既定 Chapter の page entry として追加する | `project page add` |
| `create_project_page` | HTML を新規作成し既定 Chapter の page entry として追加する | `project page create` |
| `place_project_page` | 既存 page entry の canvas 配置を更新する | `project page place` |
| `set_project_page_document_context` | page HTML 正本の `<html>` attribute と binding metadata を更新する | `project page document` |
| `add_project_component` | 既存 HTML を Collection 内 component canvas として追加する | `project component add` |
| `create_project_component` | HTML を新規作成し Collection 内 component canvas として追加する | `project component create` |
| `place_project_component` | 既存 component canvas の配置を更新する | `project component place` |
| `set_project_component_document_context` | component HTML 正本の `<html>` attribute と binding metadata を更新する | `project component document` |
| `remove_project_component` | component canvas 登録を削除する | `project component remove` |
| `list_nodes` | annotation status、session/stable reference、source locator、標準CSS layout/visibility、`renderingTargets` を含む全DOM node graphを返す | `page graph` |
| `screenshot_canvas` | 選択 Chapter / Collection と前面注釈を PNG に保存する | `screenshot canvas` |
| `screenshot_page` | page または component canvas を PNG に保存する | `screenshot page` |
| `screenshot_node` | page または component canvas 内の node を切り抜いた PNG に保存する | `screenshot node` |
| `query_nodes` | id / capability / legacy type hint / role / tag / text で node を検索する | `node query` |
| `get_node` | stable internal ID / typed `ogref` またはsession referenceでnodeをinspectionする | `node get` |
| `adopt_node` | node / subtree の optional identity 追加をdry-runし、明示時だけ適用する | `node adopt` |
| `set_css_variable` | node または related rendering target の companion CSS declaration を設定する | `node style set` |
| `remove_css_variable` | node または related rendering target の companion CSS declaration を削除する | `node style remove` |
| `set_node_attribute` | capability-compatible targetへeditableな標準HTML / OpenGraphite metadata属性を設定する | `node attr set` |
| `remove_node_attribute` | capability-compatible targetからeditable属性tokenを明示削除する | `node attr remove` |
| `set_text_content` | node の中身を escaped text に置換する | `node text set` |
| `insert_html` | anchor node 基準で HTML 断片を挿入する | `node html insert` |
| `replace_node_html` | node subtree を HTML 断片で置換する | `node html replace` |
| `delete_node` | node subtree を削除する | `node delete` |
| `move_node` | node subtree を target node 基準位置へ移動する | `node move` |
| `copy_node` | node subtree を prefix 付き ID で複製する | `node copy` |

## Tool Arguments

すべての tool は、対象 project を `projectPath` で受け取る。`projectPath` は repository root 相対 path、絶対 path、または `current` である。

`migrate_project`は`project`、optional `targetVersion`、optional `proposalReference`、optional `apply`を受け取る。`apply`の既定値は`false`であり、MCP serverは次のCLIへ同じ値を渡す。

```text
ogkiln migrate <project> [--target-version <version>] [--proposal <token>] [--apply] --json
```

dry-runは固定options `legacyCatalogVersion: "1"` / `preserveUnknownDataAttributes: true`、target、project manifest、全対象canonical relative pathとUTF-8 BOMを含むraw-byte SHA-256 hashを束縛した`proposalReference`とresource別`diffs`を返す。対象closureはmanifest、project CSS library、登録HTML、存在するcompanion CSS、actual local linked stylesheet / executable script、actual linked/embedded CSSから再帰的に辿るlocal `@import`であり、inline / embedded CSSもHTML candidateとして扱う。source kindはcharacter-reference復号後のHTML属性値で決め、URL extensionでは補正しない。`<style>`は`type`省略/exact empty/ASCII-CI exact `text/css`、`<link rel~=stylesheet>`は`type`省略またはHTTP-whitespace-trim済みMIME essence `text/css`だけをCSSとし、present-empty link typeは非CSSである。`<script>`はexact empty、ASCII-CI exact `module`、またはexact JavaScript MIME typeだけをexecutableとし、`type`がobsolete `language`に優先する。style/script typeの前後空白・parameter、JSON/JSON-LD/import map/speculation rules/unknown data blockはopaqueである。HTML/CSS whitespaceはTAB/LF/FF/CR/SPACE、HTTP whitespaceはFFを除く4文字で、NBSP/vertical-tabはraw valueに残す。HTML non-void `/>`は閉じずSVG/MathML self-closingは閉じ、semicolonなしdecimal/hex numeric referenceもsemantic decodeする。actual kindのextensionless pathをclosureへ含め、無関係なcase/entity/CRLF/BOM/triviaを保持する。project rootの`OpenGraphite.contract.json`はApp用tool configurationであり、proposal targetにもdiff/apply candidateにも含めずbytesを維持する。

`apply: true`は同じtarget/optionsと`proposalReference`を必須とし、proposalなしは`migration-apply-requires-proposal`、source/manifest/parameterまたはraw-byte content変更は`stale-migration-proposal`、未対応targetは`unsupported-migration-target-version`でatomic no-writeになる。catalog v1はtype/layout/icon-maskをversioned class、hidden/variant/partを標準attribute、既知design custom propertyを`--migrated-v1-*`へ移し、strictなplacement mockのpreview/collapsedだけを`host.variant`へ変換する。project CSS、executable inline/linked JavaScript、inline event handlerがlegacy inputを読む場合や、実際に新規生成するclass・標準attribute・custom propertyを観測する場合はblockingである。dot/bracket/alias/destructuringとborrowed `call`/`apply`を同じattribute evidenceへ正規化し、exact名は実際に生成するdestination、dynamic名はwhole-attribute変更とだけ交差する。whole `dataset` / `style` evidenceは実際に削除するdataset attribute、inline-style実変更、生成custom propertyとだけ交差する。whole attribute・dynamic DOM・AttributeNodeはHTML attribute変更、whole markupはembedded-style移行を含むHTML source変更、CSSOMはexternal/embedded CSS変更、actual style-textはembedded CSS変更とだけ交差する。ID-based style/link evidenceはruntime参照元HTMLのactual CSS ownerへ束縛し、別pageの同名非style要素やgeneric property accessを誤衝突させない。manifest previewはglobal preview contextから追える`placementMocks` / whole-context alias chain、または新規生成するexact/static-concatenated `host.*` fieldとだけ交差し、fields/document-only accessや無関係objectの同名propertyはsafeである。clean observer projectと無関係なmutationはblockしない。semanticに同値のstandard destinationが既にある場合はgenerated conflictにせず、case・quote・character referenceと周辺raw bytesを維持してlegacy tokenだけを除去する。component master/slot、source placement state、unsafe role、未知reserved property、destination conflictもblockingであり、source HTMLへpreview stateを追加しない。

project load失敗は`migration-project-load-failed`です。登録対象でlegacy inputを検出したprojectに限り、曖昧なCSS importは`unsupported-legacy-import-reference`、列挙不能なruntime module closureは`unsupported-legacy-runtime-dependency`とし、external / 解決不能なbase・stylesheet・runtime、local legacy reader、missing / project root外 / unreadableなdiscovered dependency、同一canonical URLのCSS/runtime kind conflict (`migration-resource-kind-conflict`) も推測せずblockingにする。legacy input がない clean standard projectは変更不要のno-opとする。blocking dry-runはpartial proposal/diffを返さず、CLI non-zeroとMCP `isError: true`で全resourceをno-writeにする。applyは各candidateのcommit直前に変更しないdependencyを含むproposal全closureのraw bytes・存在・canonical path解決を再検証し、staleなら先行commitをrollbackして`stale-migration-proposal`を返す。rollbackはmigration後bytes/modeとのcompare-and-swapで、commit後の外部編集を上書きせず`migration-rollback-failed`を返す。write途中の失敗は`migration-write-failed`としてrollbackする。

resultは据え置きのAgent `schemaVersion`と、`sourceContractVersion`、`targetContractVersion`、`dryRun`、`applied`、`changed`、`proposalReference`、`diffs`、`diagnostics`を持つ。`.ogp` schema versionは変更せず、既知legacy preview fieldがある場合だけmanifestをdiff/apply対象にしてproject-defined `host.<attribute>` / `host.class`へ移す。source versionはlocal contractのversionではなく登録対象sourceのlegacy token検出から決めるため、旧tool configurationを残したapply後の再dry-runもtarget version / `changed: false`となる。

page / component canvas を対象にする tool は `pageID` または `componentID` のどちらか一方を受け取る。`get_node` は一意なraw internal ID、stable typed `ogref:node` / `ogref:component-node`、またはgraphが返したsession referenceを `id` に受け取る。raw internal IDとsession referenceには対象canvasが必要で、stable typed referenceは単独で対象HTMLと `data-og-internal-id` へ解決する。通常のnode mutation toolは一意なraw `data-og-internal-id` またはstable typed referenceだけを受け付け、session referenceを直接受け付けない。

`list_nodes` / `query_nodes` / `get_node` は OpenGraphite annotation のない標準 HTML element も返す。各 node は `reference`、`annotationStatus` (`none` / `partial` / `complete`)、`referenceStability` (`session` / `stable`)、`locator`、optional `parentReference` を持つ。`locator` は `documentURL`、既存標準 `id` を優先した optional `selector`、`domPath`、`sourceRange.start/end`、`contentHash` を持つ。互換フィールドの `id` / `internalID` は annotation がなければ空になり得る。annotation status と stability は独立しており、一意なinternal IDがあればpartialでもstable、それ以外はsessionである。session reference は現在の source revision を inspect するための参照であり、長期 mutation の identity にはしない。

各nodeはraw value昇順の`capabilities`と、`isProjectResourceRoot`、`isNativeControl`、`isCustomElement`、`isLink`、`hasDirectText`、`hasElementChildren`、`hasMediaContent`、`hasSVGContent`、`hasMaskContent`、optional `ariaRole`、optional `resolvedDisplay`からなる`capabilityEvidence`を返す。capability値は`drag-position`、`edit-control`、`edit-icon`、`edit-layout`、`edit-link`、`edit-media`、`edit-text`、`group`、`receive-children`、`reorder-flow`、`ungroup`である。旧属性が実在するときだけoptional `legacyTypeHint`を返し、旧node `type` keyは返さない。`query_nodes.capabilities`はstring arrayをCLIのrepeatable `--capability`へ渡し、全指定値を持つnodeだけを返す。互換`query_nodes.type`は`legacyTypeHint` exact-matchにだけ使い、capabilityを推測しない。

graphはproject library、companion CSS、HTML document orderの各local linked stylesheetと各`<style>`を別ASTとしてcascadeし、既存inline styleもHTML sourceとして合成する。unlinked project libraryは先頭、unlinked companionは末尾のfallback sourceになる。`cssSourceTrace` candidateは `sourceID`、`sourceKind` (`project` / `companion` / `linked` / `embedded` / `inline`)、`sourceEditable`、`stylesheetOrder`、source内 `sourceOrder`、`inherited` を返す。`cssResolvedValues`は全source candidateと親継承値を合成した後に一度だけcustom property / `var()`を最終解決し、既知source内のinheritance、対応shorthand、CSS-wide keywordを反映する。`var()`を含む対応shorthandはraw `authoredProperty` / valueをtraceへ残し、最終置換後にlonghand componentを展開する。展開不能なcomponentは該当node/propertyだけをincompleteにしてwrite-blockする。CSS-wideの単一identifier escapeはsemantic復号するがauthored spellingは保持し、AppのWebKit computed styleとは混ぜない。

これら3 toolのoptional `activeMediaQueries`はstring arrayで、呼び出し側がactiveと確認したauthored media conditionをCLIのrepeatable `--active-media`へそのまま委譲する。省略時はheadless実行がviewportを推測せず、`<link media>` / `<style media>` とstylesheet内 `@media` をactiveとみなさない。responseの`activeMediaQueries`は正規化後に評価へ使った条件を返す。nodeの`layout`はresolved `display` / `flex-direction`とHTML UA既定から導出し、`hidden`は標準`hidden` source state、CSSの`display` / `visibility` / `overflow-wrap`は`cssSourceTrace` / `cssResolvedValues`へ分離する。`hidden="until-found"`はdeclaration不在時だけheadless `content-visibility:hidden` fallbackを持ち、author `initial` / `unset` / `visible`はresolved `visible`として上書きするが、sourceの`hidden` intentは維持する。Appのcomputed `content-visibility`とrendered hidden判定は別payloadである。

外部・root外・読取不能 stylesheet、未解決`@import`、malformed CSS、`@layer` / `@property`等のsource-wide未対応at-rule、未対応selectorがある場合は、既知candidateをinspectionできてもpageと各nodeの `hasIncompleteCSSProvenance` が `true` になり、warning `incomplete-css-provenance` が付く。MCPはimport先やlayer orderを推測しない。このsource-wide incomplete状態の `set_css_variable` / `remove_css_variable` はerror `incomplete-css-provenance-write-blocked`を返し、HTML/CSSをatomic no-writeにする。

matching `@supports` / `@container` / `@scope` / `@document` / `@starting-style`、graph内にkeyframes sourceがあるactive `animation-name` / `animation`、unknown initial値、`revert` / `revert-layer`、headlessの対応CSS値grammarで無効・未対応なauthored source値は、該当node/targetだけを `hasIncompleteCSSProvenance: true` にする。`revert`系は同じauthor origin内の前candidateを使わず、継承propertyでは親computed値を保持し、非継承propertyではHTML UA fallbackへ委ねる。対応grammarはkeywordに加えてgeometry、標準length unit、percentage、unitless zero、typed math、grid track、数値propertyを検証し、number / percentage / length / length-percentageを区別する。invalid sourceはraw保持してwinnerを断定しない。構文上有効な`env()` / `anchor()` / `anchor-size()`もraw保持するが、headlessではresolved winnerを返さずnode/property incompleteにする。`set_css_variable`の明示invalid入力、top-level `;`による別declaration、またはtop-level `!important`のvalue注入は共有CLI/Coreのerror `invalid-css-property-value`でatomic no-writeになる。environment依存値のsetはsyntax errorにはせず、safeなpostconditionを確定できないため`incomplete-css-node-provenance` / `incomplete-css-provenance-write-blocked`でatomic no-writeにする。`@keyframes`定義だけではsource-wide incompleteにしない。page flagは該当nodeの存在を集約するが、完全な別nodeまでread-onlyにはしない。該当targetへのmutationはwarning `incomplete-css-node-provenance` とerror `incomplete-css-provenance-write-blocked`を返してatomic no-writeにする。

`set_css_variable` / `remove_css_variable`も同じoptional `activeMediaQueries`を受け取り、各値をrepeatable `--active-media`として同名CLI commandへ渡す。responsive winnerをreviewした条件集合をmutationにも渡すことで、そのmedia ruleのauthored declarationを最小差分で更新し、base ruleや別conditionへ値を移さない。

これらのnode style toolはproject CSSをcascade解決には含めるが、`.ogp`の`cssLibrary`を直接変更しない。direct inline / companion winnerは既存declarationだけを更新・削除する。read-only project / linked / embedded winnerへのsetはactive media scopeとpriorityを満たす安全なnode-scoped companion overrideだけを許可する。安全なspecificityを構成できないsetは `css-specificity-override-unsafe`、read-only winnerだけのremoveは `read-only-css-winner`、shorthand由来longhandのremoveは `shorthand-css-removal-unsupported`、set postconditionを満たせない場合は `css-mutation-postcondition-failed` でno-writeになる。CSS libraryを変更するのはproject-levelの`set_design_token` / `remove_design_token`だけである。

node payload はさらに `renderingTargets: [OpenGraphiteAgentRenderingTarget]` を返す。各 target は `kind`、`tagName`、`relation`、`relationSelector`、`writeSelector`、`targetInternalID`、`authoredValues`、`resolvedValues`、`sourceTrace` を持つ。`kind` は `media` / `svg` / `mask`、`relation` は `self` / `direct-child` / `descendant` である。`targetInternalID` は未注釈 target で `null` になり得る。MCP は inspection のために annotation を追加しない。

`adopt_node` は `pageID` / `componentID` の一方と、inspection payload から得た `reference` / `selector` / `domPath` の正確に一つを受け取る。`scope` は `node`（既定）または `subtree`、`displayID` は対象rootに提案する optional な人間可読 ID である。`apply` を省略または `false` にした呼び出しは dry-run で、sourceを書かずに `targetReference`、`adoptedReferences`、候補graph、diagnostics、`diff.path/beforeHash/afterHash/unifiedDiff` を返す。入力nodeが既にstableかどうかにかかわらず、`targetReference` は現在のsource range/content hash、document全体のbefore hash、正規化済みscope/display IDを固定したapply専用proposal snapshot referenceへ正規化される。`apply:true` は直前dry-runの `targetReference` を `reference` とし、同じ `scope` / `displayID` を渡す場合だけ受け付ける。通常graphのsession referenceを直接applyへ渡すことはできない。同じ共有Core経路でsource range/content hash、document全体hash、proposal parameterを再検証し、変化していれば stale proposal として拒否する。semantic valueを確定できないcharacter referenceを含む既存OpenGraphite identityはvalidation errorとし、対象node/subtreeのadoptionを無変更で拒否する。結果は `schemaVersion`、`applied`、`changed`、`dryRun`、`path`、`scope`、`targetReference`、`adoptedReferences`、optional `diff`、`graph`、`diagnostics` を返す。既存の標準 `id` / 安全な selector が十分な場合はそれを再利用し、必要な optional identity だけを追加する。

`set_css_variable`、`remove_css_variable`、attribute/icon/text/HTML編集、delete/move/copyなどのnode mutation toolは、一意な `data-og-internal-id` またはstable typed `ogref` を要求する。session reference / selector / DOM pathを通常mutationへ直接渡してはならず、stable targetが必要なら先に `adopt_node` のdry-runを確認して明示applyする。

`set_css_variable` / `remove_css_variable` に `variable` として `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image` を指定した場合、wrapper node を `id` で指定しても、server は既存 `node style set/remove` と共通 Core resolver で実際の media / SVG / mask target の `writeSelector` へ透過 route する。対象の標準 `#id`、既存 `data-og-internal-id`、wrapper selector + relative path の順で安全な selector を優先し、未注釈 target に ID を自動追加しない。その他の property は従来通り選択 node 自身の declaration を扱う。この parity のための新規 MCP tool は追加しない。

`list_canvas_annotations` は `chapterID` または `collectionID` のどちらか一方を必須とし、手書き point 列を展開しない要約を返す。`get_canvas_annotation.id` は raw annotation internal ID または `ogref:annotation:<pages|components>:<containerInternalID>:<annotationInternalID>` を受け取る。raw ID には `chapterID` / `collectionID` のどちらか一方が必要であり、typed ID は単独でコンテナを解決できる。typed ID と selector を併記する場合は同じ Chapter / Collection を指す必要がある。

`add_project_page.path`、`create_project_page.path`、`add_project_component.path`、`create_project_component.path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は invalid である。`add_project_component.collectionID` と `create_project_component.collectionID` は Collection ID / 内部 ID / `ogref:collection` を受け取り、省略時は先頭または既定 Collection を使う。

`create_project_page` は page 登録と初期 canvas 配置を同時に扱える。`create_project_component` は component HTML の作成と Collection 登録を行い、配置変更は `place_project_component` で行う。

`place_project_page` と `place_project_component` の `name`、`x`、`y`、`width`、`height` は任意であり、省略した値は `.ogp` 内の現在値を維持する。`name` はフロー解決用の canvas 配置名として保存され、空文字または空白だけを指定すると名前なしとして保存する。`previewMocks` は `.ogp` の canvas metadata に保存する canvas 全体の runtime Mock State であり、空文字値も有効な override として扱う。`previewPlacementMocks` は `place_project_component` のみで受け取り、component canvas 内 placement ID ごとの runtime Mock State を `previewContext.placementMocks` へ部分更新する。placement ID は internal ID を正本とし、その entry がなければ display ID へ fallback する。両方の entry がある場合は internal ID 側だけを使い、field を merge しない。

component placement の状態差分は HTML 正本ではなく、`.ogp` canvas metadata の `previewContext.placementMocks` に保存する。汎用 field の `host.<attribute>` は project runtime が生成 preview clone の通常 host attribute、ARIA、`variant` などへ一時投影し、`host.class` は authored class を残して token を追加する。標準 boolean attribute は `0` / `false` / `no` / `off` だけを不在として扱う。`data-og-*`、event handler の `on*`、`id`、`style`、`slot`、`part` は protected で注入しない。project の authored `:host(...)` CSS と browser computed style が code / preview / loading / collapsed などの表示を決め、App Canvas と screenshot は同じ state を評価する。source HTML と static build には preview state を保存しない。MCP の`set_node_attribute` / `remove_node_attribute`は`OpenGraphite.contract.json`のeditable attributesに含まれる標準HTML属性と保持対象OpenGraphite metadataだけを扱い、対象tag/content modelとoperation capabilityも検証する。contract外は`disallowed-attribute`、対象不適合は`unsupported-node-capability`としてatomic no-writeにする。`set_node_attribute`の空文字はpresent-empty attributeとして保持し、attribute tokenを削除するのは明示的な`remove_node_attribute`だけである。placement mock injection は HTML 属性として保存しない。

`set_project_page_document_context` と `set_project_component_document_context` は HTML 正本の `<html>` attribute を編集する。`langSource` は `literal` / `binding`、`dirSource` は `literal` / `auto` / `binding` を受け取る。Binding の場合も `lang` / `dir` 属性には fallback 値を残し、field 名は `data-og-lang-field` / `data-og-dir-field` metadata として保存する。

`set_text_content` は MCP / CLI 経由の source operation であり、App preview の Mock State を暗黙に推測しない。variant context が明示されていない場合は HTML fallback content を編集する。App の Canvas / preview から直接 text を編集する場合は、現在描画されている resolved text resource を対象にし、別 variant の text は Inspector から明示的に編集する。

`list_design_tokens` / `set_design_token` / `remove_design_token` は project-level CSS resource を扱うため、`pageID` / `componentID` / `id` を受け取らない。token 名は `OpenGraphite.contract.json` の `designTokens.namePattern` に一致する CSS custom property 名である必要がある。node から token を参照する場合は `set_css_variable` の `value` に `var(--token-name)` を保存する。

`list_locale_typography` / `set_locale_typography` / `remove_locale_typography` は `pageID` または `componentID` のどちらか一方を必須とする。`set` / `remove` の `locale` は省略または `default` で root の標準 `font-family`、任意の妥当な BCP 47 tag で同じ root scope の `:lang(<locale>)` rule を表す。`set_locale_typography.value` は CSS font-family value 全体である。MCP は selector / at-rule / declaration provenance を保持する同名 CLI command へ委譲し、computed style や preview state を source へ書き戻さない。

`list_locale_typography` は `rootSelector` と `declarations` を返し、各 declaration は `locale`、`selector`、`property`、`value`、`important`、`atRules`、`sourceOrder` を持つ。preview は clone の標準 `lang` / `dir` だけを一時変更し、現在描画中の font は WebKit computed style から観測する。旧 `--og-font-family-default`、`--og-font-family-<locale>`、`--og-active-font-family` は明示 migration の legacy input であり、locale typography tools の output / write target にはしない。

`remove_project_component.deleteFile` は既定で `false` である。`true` の場合のみ、`.ogp` からの登録削除に加えて component HTML file も削除する。

`build_project.outputPath` は build 出力ディレクトリである。build は Pages HTML を対象にし、component Collection の HTML、runtime script、editor-only の入力 `.ogp` manifest は公開 asset として出力しない。`.ogp` 注釈は component 展開へ使わず、生成 HTML / CSS へ付箋本文、色、stroke、annotation ID を注入しない。Canvas Object Reference も参照 clone、typed ID、frame を生成物へ注入しない。

`screenshot_canvas.chapterID` / `collectionID` は任意かつ相互排他で、表示 ID、内部 ID、`ogref:chapter` / `ogref:collection` を受け取る。両方を省略した場合は先頭 Chapter を使う。対象 Chapter の WebKit page snapshot または Collection の component snapshot と `annotations[]` を canonical world 座標で合成し、App と同じ ink、sticky note の順で注釈を前面へ描画する。Canvas Object Reference は editor viewport のため `references[]` を描画しない。全cardは有限座標と正の寸法を必須とし、出力が一辺16,384 pxまたは総33,554,432 pixel、もしくはcard snapshot累積が33,554,432 pixelの安全上限を超える場合はcaptureやbitmap確保を行わず明示エラーを返す。`screenshot_page` の `width`、`height` は任意であり、省略時は `.ogp` entry の `canvas.width`、`canvas.height` を viewport として使う。`fullPage:true` の場合は document 全体を保存する。個別 HTML を対象にする `screenshot_page` / `screenshot_node` は Chapter / Collection 注釈を含めない。

`position` は `before`、`after`、`prepend`、`append` のいずれかである。

`copy_node.idPrefix` は複製 subtree 内の全 `data-og-id` に付与される。空文字は invalid である。

## Error Handling

MCP server は `ogkiln` の exit status が non-zero の場合、tool result の `isError` を `true` にする。diagnostics の本文は `content[].text` に JSON として返す。JSON-RPC protocol error は、未知の method や未知の resource / tool など server 自体で処理できない場合だけに使う。

`migrate_project`も同じruleに従い、errorのないdry-runだけを`isError: false`で返す。blocking diagnosticを含むdry-runまたはapply/no-write、stale proposal、write/rollback failureはCLIのnon-zero exitをそのまま`isError: true`として返し、MCP独自の部分writeやretryを行わない。

`data-og-id`、`data-og-internal-id`、`data-og-type` の欠落は diagnostic error ではない。存在する `data-og-id` / `data-og-internal-id` の重複、存在する component/node reference の破損、adoption locator のhash不一致は引き続き error としてwriteを止める。

## Pencil Compatibility Reading

Pencil の `batch_design` は `.pen` の object tree を insert / update / delete / move / copy / replace する。OpenGraphite MCP は同じ編集意図を、`.ogp` に登録された HTML page または component canvas の element subtree と node ID による操作へ分解する。Collection 内 component master の編集は `componentID` を指定した node operation、Pages 上の instance 編集は `pageID` を指定した `<og-instance>` または展開後 DOM への操作として扱う。`get_screenshot` / `export_nodes` に相当する visual operation は、`screenshot_canvas` / `screenshot_page` / `screenshot_node` として WebKit rendering pipeline から PNG を生成する。
