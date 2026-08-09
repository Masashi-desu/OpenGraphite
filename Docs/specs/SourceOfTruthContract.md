# OpenGraphite Source-of-Truth Contract

この文書は、[DesignPhilosophy.md](DesignPhilosophy.md) の思想を実現するための技術契約を定義します。対象は HTML だけでも component だけでもありません。optional `data-og-*`、標準 CSS property、project-defined CSS custom property、legacy migration input、runtime、build、locale resource、`.ogp` metadata など、OpenGraphite が正本として扱う境界を横断して記述します。

## Contract Scope

OpenGraphite の正本は、リポジトリ上の Web 標準ファイルと、それらを解決するための最小限の project metadata です。通常の page DOM は HTML、共通描画は CSS、text resource は locale JSON などの実装資源、component master は Collection 内の source file、canvas 配置、preview mock、公開成果物に含めない協業用注釈と Guide は `.ogp` metadata が担います。

この契約の目的は、次の境界を曖昧にしないことです。

- 編集可能な構造と session-only 状態の境界。
- デザイン値と描画規則の境界。
- 共有される master と instance 固有 content の境界。
- source file と runtime / build 生成物の境界。
- editor preview 用 mock と公開成果物の境界。

## Web Standard Ownership Matrix

この節は Web contract version `1.0.0` の normative ownership を定義します。移行期間中に後続節や legacy fixture が旧契約を説明している場合も、新規 authoring、validation、inspection、migration の最終判定ではこの節を優先します。

| 区分 | 正本 | OpenGraphite の扱い |
| --- | --- | --- |
| 構造・意味・操作 | 標準 HTML DOM、native element、ARIA、Custom Elements | annotation の有無に関係なく読み取り、operation ごとの capability を算出する。 |
| authored design value | CSS source AST | selector、cascade、specificity、source order、inheritance、`!important`、custom property、shorthand、at-rule、未知 rule、コメントを保持し、既存 declaration provenance へ最小差分で書き戻す。 |
| 現在の描画値 | WebKit computed style | Canvas と Inspector の現在値として観測する。computed value を source declaration と同一視しない。 |
| component authoring | Custom Elements、`template`、`slot`、`part`、host attribute、project runtime | runtime と static build が同じ source semantics を決定的に評価する。 |
| project preview | `.ogp` `previewContext` と runtime への一時注入 | source HTML を変更せず、注入後の通常の DOM / CSS state を観測する。 |
| OpenGraphite metadata | optional identity、component / node reference、binding、編集 policy、provenance | 標準 Web から一意に復元できない情報だけを永続化する。 |

### 維持する source annotation

すべて optional です。属性を持たない resource や node も preview、Layers、Inspector、CLI、MCP、validation、build の対象になります。存在する identity の重複や、存在する reference の破損は診断しますが、annotation の欠落自体は error にしません。

| 属性 | ownership | 根拠 |
| --- | --- | --- |
| `data-og-id` | optional identity | 人と UI が読める協業用の安定名。 |
| `data-og-internal-id` | optional identity | rename や表示名から独立した stable `ogref` の node identity。 |
| `data-og-component` | component reference | generic `<og-instance>` と registry / master resource を結ぶ安定参照。 |
| `data-og-source-component-internal-id` | component reference | placement が参照する component canvas identity。 |
| `data-og-source-node-internal-id` | node reference | placement が参照する source node identity。 |
| `data-og-text-source`、`data-i18n-key`、`data-og-text-variant-*` | binding | 表示 text の外部 resource と fallback / sample provenance は DOM text だけから復元できない。 |
| `data-og-lang-source`、`data-og-lang-field`、`data-og-dir-source`、`data-og-dir-field` | binding policy | 標準 `lang` / `dir` fallback と runtime field の関係を表す。 |
| `data-og-locked` | editing policy | CSS や DOM semantics から復元できない editor write policy。 |
| `data-og-icon-library`、`data-og-icon-name`、`data-og-icon-source` | resource provenance | SVG / mask の出自と再取得方法を AI と人が追跡する。描画自体は標準 SVG / CSS が担う。 |

未注釈 node は、標準 `id`、安全な authored selector、document URL、DOM path、source range、content hash から session-scoped reference を得ます。永続的な mutation target が必要な場合だけ、明示 `adopt` が既存標準 selector を優先して optional identity を付与します。`adopt` は常に dry-run と unified diff を提供し、resource の open、load、preview、inspection、無編集保存から暗黙実行しません。

### 標準 Web へ移す legacy annotation

| legacy 属性 | 正本 | 最終扱い |
| --- | --- | --- |
| `data-og-type` | tag / DOM content / native control / ARIA / media・SVG・mask 実体 / computed display から算出する operation capability | `page` / `frame` / `text` / `button` / `image` / `icon` は既存 CSS の表示を保つ versioned class `.og-migrated-v1-type-*` へ移して属性を削除する。class は capability 根拠ではない。未知値は blocking。 |
| `data-og-layout` | `display`、`flex-direction`、grid property、child ごとの `position` / inset | `vertical` / `horizontal` / `absolute` は `.og-migrated-v1-layout-*` へ移して属性を削除する。未知値は blocking。 |
| `data-og-hidden` | 標準 `hidden`、`display`、`visibility` | `true` は present-empty `hidden`、`false` は legacy 属性除去へ移す。既存 `hidden="until-found"` または反対意味の既存 `hidden` との競合は blocking。 |
| `data-og-icon-mask` | `mask-image` / `-webkit-mask-image` と描画実体 | `true` は `.og-migrated-v1-icon-mask`、`false` は legacy 属性除去へ移す。非 boolean 値は blocking。 |
| `data-og-variant` | Custom Element host の通常の `variant` token attribute と authored selector | 値を保持して `variant` へ rename する。既存の異値 `variant` は blocking。 |
| `data-og-slot` | master template の `<slot name="…">` と light DOM の標準 `slot` | projection 方向と fallback 構造を属性だけから一意に決められないため自動変換しない。template / slot を手動標準化してから再 dry-run する。 |
| `data-og-part` | 標準 `part` attribute | token list を保持して `part` へ rename する。既存の異値 `part` は blocking。 |
| `data-og-component-kind="master"` | `.ogp` component registry、hyphenated Custom Element host、直下 `template` | legacy master 構造は自動削除せず blocking。registry / template / slot / placement を手動標準化してから再 dry-run する。 |
| `data-og-role="component-placement"` | `<og-placement>` tag | `<og-placement>` 上の完全一致属性だけ冗長 annotation として削除する。それ以外の tag/value と legacy CSS selector は構造を推測せず blocking。 |
| source HTML/CSS の `data-og-placement-mode`、`data-og-state-hidden`、`data-og-state-visible` | `.ogp` placement mock を生成 clone の project-defined host state へ投影し、authored `:host(...)` CSS で評価 | source placement と mock entry の対応や host scope を一意に確定できないため自動変換せず blocking。source HTMLへ `variant` を追加しない。手動で source CSS と `.ogp` を同じ standard host stateへ揃えてから再 dry-run する。 |

未知の `data-og-*` や標準 / framework 固有 attribute は、OpenGraphite が ownership を持たない限り保持して read-only とします。明示 migration は既知 legacy 名だけを対象にし、OpenGraphite を使用しない resource を書き換えません。

### runtime-private state

選択、編集、Focus、drag、reorder、frame preview、runtime 展開 provenance、error、generated / clone marker は source contract ではありません。旧形式の `data-og-selected`、`data-og-editing`、`data-og-editor-focus-*`、`data-og-dragging`、`data-og-reorder-*`、`data-og-frame-*`、`data-og-editor-artifact`、`data-og-expanded`、`data-og-generated`、`data-og-component-error`、`data-og-host-id`、`data-og-instance-source`、`data-og-source-component`、`data-og-source-instance`、`data-og-source-placement`、`data-og-slot-origin`、`data-og-preview-clone`、`data-og-placement-generated`、`data-og-preview-locale`、`data-og-preview-dir`、`data-og-runtime-fallback-html` は明示 migration の入力としてだけ認識します。現行 runtime は native overlay、`:focus`、`contenteditable`、WeakMap / JavaScript object、Web Animations API などの private state を使い、正本 HTML、companion CSS、contract の editable / runtime attribute list、agent graph、static build へ保存または出力しません。

### reserved `--og-*` の最終 ownership

contract version `1.0.0` は reserved `--og-*` custom property を持ちません。project-defined generic design token は `--color-*`、`--space-*` など任意の CSS custom property として利用できますが、OpenGraphite が名称や意味を予約しません。

| legacy property | 標準の正本 |
| --- | --- |
| `--og-page-background`、`--og-text-color` | page / document root の `background` / `color` |
| `--og-muted-color`、`--og-accent`、`--og-accent-foreground` | project-defined generic design token と、それを参照する通常の declaration |
| `--og-font-family-default`、`--og-font-family-<locale>`、`--og-active-font-family` | root の `font-family`、`:lang(...)` rule、inheritance、computed `font-family` |
| `--og-object-fit` | 実体 `img` / `video` の `object-fit` |
| `--og-stroke-width` | SVG / SVG descendant の `stroke-width` |
| `--og-icon-url` | mask 実体の `mask-image` / `-webkit-mask-image` |
| `--og-scale-x`、`--og-scale-y` | 新規・手動標準化では individual transform property `scale: <x> <y>`。catalog v1 migrationはvisual/cascade parityのため既存`transform: scale(var(...), var(...))`の構造を保持し、参照名だけversioned generic custom propertyへrenameする。 |
| `--og-edit-width`、`--og-edit-min-height` | runtime overlay の標準 `width` / `min-height` |
| `--og-preview-locale`、`--og-preview-dir` | preview clone の標準 `lang` / `dir` |
| `--og-drag-x`、`--og-drag-y`、`--og-reorder-x`、`--og-reorder-y` | runtime-only `translate` または Web Animations API |

legacy `--og-*` は compatibility reader と明示 migration の入力に限り、新規 source、Inspector special case、built-in allowlist、distributed CSS、runtime、sample、Tutorials へ生成しません。

catalog version `1` は既存 cascade と参照関係を lossless に保つため、既知 design custom property の declaration 名と `var()` 参照を次の project-defined versioned namespaceへ同時変換します。この namespace は migration output の衝突回避用であり、Web contract `1.0.0` が意味を予約する新しい `--og-*` ではありません。新規 authoring は標準 propertyまたはproject自身のgeneric tokenを使います。

| legacy property | catalog v1 destination |
| --- | --- |
| `--og-page-background` | `--migrated-v1-page-background` |
| `--og-text-color` | `--migrated-v1-text-color` |
| `--og-muted-color` | `--migrated-v1-muted-color` |
| `--og-accent` | `--migrated-v1-accent` |
| `--og-accent-foreground` | `--migrated-v1-accent-foreground` |
| `--og-font-family-default` | `--migrated-v1-font-family-default` |
| `--og-font-family-<locale>` | `--migrated-v1-font-family-<locale>` |
| `--og-active-font-family` | `--migrated-v1-font-family-active` |
| `--og-object-fit` | `--migrated-v1-object-fit` |
| `--og-stroke-width` | `--migrated-v1-stroke-width` |
| `--og-icon-url` | `--migrated-v1-icon-url` |
| `--og-scale-x`、`--og-scale-y` | `--migrated-v1-scale-x`、`--migrated-v1-scale-y` |

catalog v1は既存`transform: scale(var(--og-scale-x), var(--og-scale-y))`を無条件にindividual `scale`へ組み替えません。cascade、transform function order、visual resultを保持するため、declaration構造をそのまま残して`var()`参照だけを`--migrated-v1-scale-*`へrenameします。新規sourceまたは人が意味を確認した手動標準化ではindividual `scale`を使います。

runtime-only `--og-edit-*`、`--og-preview-*`、`--og-drag-*`、`--og-reorder-*` の declaration は削除します。通常 property の `var(--og-runtime-name, fallback)` は fallback を再帰的に移行して materialize し、fallback がない場合は `unset` にします。custom property 内で fallback のない runtime参照、catalog外の `--og-*`、legacy `@property` / `@supports`、一意にpatchできないselector、移行先custom propertyやgenerated classとのauthored collisionはblocking/no-writeです。project全体でCSS、executableなinline/linked JavaScript、またはinline event handlerがlegacy inputを読む場合や、migrationが実際に新規生成するclass・標準attribute・custom propertyをaccessor / mutatorのどちらかで観測する場合もblockingです。attribute observerはdot/bracket/optional access、method alias、destructuring、`getAttribute.call(node, ...)` / `setAttribute.apply(node, [...])`等のborrowed callを同じsemantic evidenceとして扱いますが、exact名はそのdestinationを実際に新規生成するときだけ交差し、動的名だけをwhole-attribute evidenceにします。JavaScriptのdestructuring / spread / alias / enumerationを含む`dataset`列全体の観測は実際に削除するlegacy dataset attribute集合、同じ`style`列全体のaccess/mutationとCSSの`style` value selector / `attr(style)`はinline `style`の実変更または実際に生成するcustom property集合と交差するときだけblockingにし、observerだけを持つclean standard projectはno-opです。`attributes` / `getAttributeNames()`、名前を静的確定できないDOM attribute accessor、dynamic selector、computed DOM property、AttributeNode APIはHTML attributeが実際に変わる場合だけ、`innerHTML` / `outerHTML` / XML serializationはembedded `<style>`内の移行を含めHTML sourceが実際に変わる場合だけblockingにします。external CSS sourceの実変更はCSSOM observer、embedded CSSの実変更はCSSOMまたはactual `<style>`本文observerとだけ交差します。style本文や`.sheet`のID-based evidenceは、そのinline/linked runtimeを参照するHTMLに実在するCSS `<style>` / `<link>` owner IDへ束縛し、別pageの同名非style要素、runtime生成style、通常要素の`textContent`、`CSSStyleDeclaration.cssText`、generic objectの`.sheet` / computed propertyをCSS whole-source observerへ誤分類しません。manifest previewの実変更はglobal preview contextからprovenanceを追えるwhole `placementMocks`、context alias chainのspread・列挙・serialization・clone・dynamic access、または実際に新規生成するexact/静的連結可能な`host.*` fieldだけと交差し、`fields` / `document`だけのaccessや無関係objectの同名`placementMocks`はblockingにしません。semanticに同値の標準destinationが既に存在してlegacy tokenだけを除去する場合はgenerated evidenceに含めず、既存destinationのcase、quote、character reference、周辺raw bytesを保持してobserverとの誤衝突を起こしません。JavaScript commentとCSSのcomment / string / `url()`にある見かけ上のtokenはobserverやlegacy tokenにしません。

## Explicit Web Contract Migration

repository の正本 `OpenGraphite.contract.json` が示す Web contract version は `1.0.0` です。project root に置かれた同名 file は App の `loadDefault` が読む tool configuration ですが、proposal の snapshot target にも migration の diff/apply candidate にもせず、bytes を変更しません。`.ogp` の manifest schema/version と Agent JSON `schemaVersion` もこの migration の version 更新対象ではなく、既存値を維持します。新規 `project create`、新規 page/component、runtime、static build、Sample、Tutorials は最初から `1.0.0` の標準 Web source だけを生成します。`0.1.0` resource の互換読み取りと source 変換は別責務であり、resource の open、load、preview、inspection、validation、build、無編集保存から暗黙実行しません。

機械可読な `migrationPolicy` は次を正本とします。

```json
{
  "explicitOnly": true,
  "dryRunRequired": true,
  "supportedSourceVersions": ["0.1.0"],
  "targetVersion": "1.0.0",
  "legacyReaderRemovalConditions": [
    "minimum-supported-web-contract-version-is-greater-than-0.1.0",
    "official-and-generated-assets-contain-no-known-legacy-tokens",
    "legacy-fixtures-and-release-notes-are-retired-by-an-explicit-major-release"
  ]
}
```

現行 migration options は `legacyCatalogVersion: "1"` と `preserveUnknownDataAttributes: true` で固定します。後者は OpenGraphite が ownership を持たない未知の `data-*` を推測削除しないための境界です。既知 denylist だけを標準 HTML / CSS / host state へ変換し、optional identity、component/source reference、binding、editing policy、icon provenance は保持します。未知の reserved legacy CSS property、意味を一意に変換できない値、変換不能な既知 legacy preview field が一つでもある場合は blocking diagnostic を返し、HTML、CSS、`.ogp` のどれも書きません。

HTML source kindはURL拡張子ではなく、HTML character referenceを復号した属性のsemantic valueで決めます。`<style>`は`type`省略、exact empty、またはASCII case-insensitive exact `text/css`だけをCSSとし、前後空白やparameterをtrimしません。`<link>`は`rel`をHTML ASCII whitespaceでtokenizeして`stylesheet`を要求し、`type`省略または両端のHTTP whitespaceを除いたMIME essenceが`text/css`の場合だけCSSとします。present-emptyのlink `type`は非CSSです。`<script>`は`type`のexact empty、ASCII case-insensitive exact `module`、またはHTMLのJavaScript MIME type集合へのexact matchだけをexecutableとし、前後空白やparameterを除去しません。`type`があれば`language`より優先し、`type`省略時だけempty `language`をclassic、非empty `language`を`text/<raw language>`のexact JavaScript MIME matchとして扱います。JSON / JSON-LD / import map / speculation rules / unknown data blockはopaqueであり、本文のlegacyらしい文字列や存在しない`src` / `@import`をmigration source/dependencyにしません。

HTML/CSS tokenizationのwhitespaceはTAB、LF、FF、CR、SPACEだけで、CRLFもdelimiterとして機能します。link MIME essenceのHTTP whitespaceはTAB、LF、CR、SPACEだけでFFを含みません。NBSPとvertical tabはattribute delimiter、token separator、keyword trim、CSS whitespaceのいずれにも読み替えず、raw valueの一部として保持します。HTML namespaceのnon-void `/>`はlexical slashを保持してもelementを閉じず、raw-text/content modelを通常どおり継続します。一方、SVG / MathML foreign contentのself-closing flagは実際にelementを閉じ、後続HTMLをscript/style本文へ誤包含しません。decimal / hexadecimal numeric character referenceはsemicolonがなくてもsemantic decodeし、NUL、surrogate、range外、C1 replacementもHTML規則に従います。migrationはこのsemantic valueとtokenizer namespaceでknown token/source kindを判定して対応raw rangeだけをpatchし、無関係なcase、quote、character reference、CRLF、BOM、triviaを保持します。

dry-run は対象 project、target version、options、manifest、および全対象 resource の canonical relative path と、UTF-8 BOMを含むraw bytesのSHA-256 content hashを束縛した `proposalReference` と `diffs` を返します。対象 closure は `.ogp` manifest、`cssLibrary`、登録 page/component HTML、存在する同名 companion CSS、HTML が参照するproject内local stylesheetとlocal script、linked stylesheetまたはembedded `<style>`の先頭 import phaseから再帰的に辿れるlocal `@import`です。HTML dependencyはURL拡張子ではなく`link` / `script` relationとsource kindでdispatchするため、extensionless pathもCSS/runtimeとして同じclosureに含めます。HTMLのinline `style`とembedded `<style>`はHTML candidate内で移行し、同じclosure内の変更しないlocal scriptもproposal hashへ束縛します。comment/string内の偽`@import`はdependencyにしません。外部または解決不能な`base` / stylesheet / runtime、曖昧な`@import`、JavaScript module/static/dynamic import・re-export・template interpolationを含むruntime dependencyに加え、missing / project root外 / unreadableなdiscovered dependencyと、同一canonical URLがCSS/runtimeの異なるkindで参照される`migration-resource-kind-conflict`は、登録対象sourceでlegacy入力を検出したprojectだけをblockingにします。legacy入力がないclean standard projectは変更不要のno-opです。

apply は同じ target/options と proposal を必須とし、対象 file の追加・削除・rename・raw-byte content変更、manifest変更、parameter変更を再検証します。一つでも一致しなければ `stale-migration-proposal` で project 全体を atomic no-write にし、新しい dry-run を要求します。proposal なしの apply は `migration-apply-requires-proposal`、未対応 target は `unsupported-migration-target-version` です。projectをmigration用に読み込めない場合は`migration-project-load-failed`、曖昧なCSS importは`unsupported-legacy-import-reference`、列挙できないruntime module closureは`unsupported-legacy-runtime-dependency`を返します。blocking dry-runはpartial diffやproposalを返さず、`changed: false` / 空`diffs` / `proposalReference: null`で全sourceをno-writeにします。

apply は全 candidate を memory 上で作成・検証してから書き込み、各candidateのcommit直前にも変更しないdependencyを含むproposal全closureのraw bytes・存在・canonical path解決を再検証します。先行commit後にstaleを検出した場合はそのcommitをrollbackし、`stale-migration-proposal`で停止します。途中の `migration-write-failed` でも変更済み file を rollback します。rollbackはcompare-and-swapとし、migration後のraw bytesと、commitで復元した場合のPOSIX modeが現在値と一致するresourceだけをbefore snapshotへ戻します。commit後の外部編集とは競合として現在値を保持し、`migration-rollback-failed`を追加して復旧が必要なpathを明示します。正常終了では既存 Agent `schemaVersion` と、`sourceContractVersion`、`targetContractVersion`、`dryRun`、`applied`、`changed`、`proposalReference`、`diffs`、`diagnostics` を返します。`diffs` は resource ごとの `path`、raw-byte SHA-256の`beforeHash` / `afterHash`、`unifiedDiff` を持ちます。`sourceContractVersion` は project-local contract file の version ではなく、登録対象 source で legacy token を検出したかから決定します。このため旧 version を記した tool configuration を bytes 不変で残しても、apply 後の再 dry-run は target version、`changed: false` / 空 `diffs` になる idempotent contract です。

`.ogp` は通常 proposal hash の束縛対象に留まり、`chapters[].pages[].canvas`または`collections[].components[].canvas`の`previewContext.placementMocks`に既知 legacy preview field が存在するときだけ migration diff / apply の対象になります。`codeViewerMode: "preview"` は `host.variant: "preview"`、`placementMode: "collapsed"` は `host.variant: "collapsible collapsed"` へ変換し、同じplacement objectの未知fieldとmanifestのraw formattingを保持します。既存 `host.variant` が同じならlegacy keyだけを削除し、異値、未対応mode、重複keyはblockingです。source HTML へ state attribute を追加しません。変換後は [Placement Contract](#placement-contract) と同じ internal-ID precedence、standard host state、authored `:host(...)` CSS を使います。

compatibility reader は `legacyReaderRemovalConditions` の全条件を満たすまで `0.1.0` のinspectionとmigration入力にだけ残します。一部条件の達成、一定期間の経過、新規sourceがcleanであることだけを理由に削除しません。削除時はcontract、Shared reader、App、CLI、MCP、fixture、docs/skillを同じ変更単位で更新します。

## Responsibility Model

OpenGraphite は、意味、編集情報、デザイン値、描画規則を分離します。

| 領域 | 責務 | 例 |
| --- | --- | --- |
| タグ名 | 意味、コンポーネント名 | `HeroSection`, `MainTitle`, `PrimaryButton` |
| optional `data-og-*` | 標準 Web から復元できない identity、参照、binding、編集 policy、provenance | `data-og-id`, `data-og-internal-id`, `data-og-component`, `data-i18n-key` |
| companion CSS | ページ / component 固有のデザイン値 | `[data-og-internal-id="hero"] { gap: 32px; }` |
| `OpenGraphite.css` | project token と、標準 Web から復元できない低詳細度の限定 affordance | `[data-og-icon-source="cdn"] > span` |
| `.ogp` | プロジェクト管理、Chapter / Collection、ページ参照、component canvas 参照、キャンバス配置、editor-only 表示状態・注釈・ガイド | `htmlRoot`, `chapters`, `collections`, `canvas`, `isSidebarHidden`, `isCanvasHidden`, `annotations`, `guides` |

class、標準 `id`、tag、ARIA、通常の attribute は Web source の一部として読み取ります。OpenGraphite annotation の有無で DOM を二種類に分けず、既存 selector と CSS source provenance を優先します。OpenGraphite 固有 metadata は標準 Web から復元できない情報に限定します。

## In-App Cache Synchronization Contract

OpenGraphite app は、リポジトリ上の正本ファイルを読み込んで app 内 cache を作り、Canvas、Layers、Inspector、Project 依存性ビュー、preview runtime bridge などの表示経路をその cache へ接続します。app 内操作で値が変わった場合、同じ値を参照する表示経路は、永続化完了やファイル再読込を待たずに cache の現在値へ同期します。

この契約では、永続化は UI 同期の transport ではありません。HTML、CSS、locale resource、`.ogp` などへの保存は、cache 上の編集状態を正本ファイルへ確定する処理です。保存には validation、競合検出、undo / redo 履歴、debounce、外部変更との調停が関わるため、app 内の表示一致を「一度保存してから再読込する」経路に依存させてはいけません。

app 内で編集可能な項目は、種別に関わらずこの規約に従います。たとえば companion CSS declaration、`data-og-*` 属性、text fallback、resolved text、icon metadata、canvas 配置、preview mock、Project resource 設定は、同じ値が複数 surface に表示されるなら cache 上の単一の現在値を更新し、そこから各 surface へ fan out します。

永続化が未完了、失敗、または外部変更と競合した場合でも、surface ごとに別々の値を持たせません。必要な場合は pending、conflict、error の状態を cache に付随させ、ユーザーへ表示します。永続ファイルが最終的な正本であることと、app session 内の未確定編集を cache で一貫表示することは別の層として扱います。

## Session History Presentation Contract

左カラムは上部 window chrome の Objects / History アイコンセグメントで、Project / Pages / Components とそのオブジェクトを扱うナビゲーション表示と、editor 全体の統合 Undo / Redo 時系列を切り替えます。History は操作の確定時刻、対象オブジェクト名、操作種別、対象種別から生成した簡易プレビューを表示し、Undo 済み項目と現在適用済み項目を区別します。同じ操作が Undo / Redo 間を移動しても、記録時刻と対象情報は同じ履歴項目として維持します。

履歴表示情報と Objects / History の選択は editor session の UI 状態です。HTML、companion CSS、locale JSON、`.ogp`、runtime、build 出力へ操作ログやサムネイルを永続化しません。project を開き直した場合、または外部変更との競合によって統合履歴を無効化した場合は表示一覧も同じ時系列とともに初期化します。簡易プレビューは履歴対象の種別・代表色・表示名から描画する識別用 UI であり、過去の WebKit render や source file の複製を新しい正本として保持しません。

## Project Metadata Contract

`.ogp` は source files の代替表現ではありません。DOM 構造、本文、主要なデザイン値を `.ogp` に複製しないことを原則とします。

`.ogp` が持つべき情報は次の範囲です。

- リポジトリルートなどのプロジェクト解決情報。
- `public` ルートへの相対参照。
- HTML ページ一覧。
- component master を置く Collection 内 source file 一覧。
- キャンバス上の配置、表示サイズ、ズーム初期値など、エディタ固有の情報。
- Chapter の Sidebar 表示状態と、Page card の Chapter キャンバス表示状態。
- editor preview のためだけに注入する Mock State。
- Chapter / Collection のキャンバス前面へ置く付箋・手書き注釈。
- Chapter / Collection で共有するキャンバスガイドの方向と world 座標。

公開リポジトリで共有できるように、`.ogp` 内のパスは相対参照を基本とします。ユーザーのディスク上の絶対パスは、実行時に解決される表示情報として扱い、永続化される IR へ固定しません。

`chapters[].isSidebarHidden` は Chapter を Sidebar の一覧から隠す editor-only metadata であり、Chapter の `pages`、注釈、ガイド、参照配置を削除しません。`chapters[].pages[].isCanvasHidden` は Page entry を Sidebar と build 対象に残したまま、Chapter キャンバスと canvas screenshot の card 合成対象から外します。どちらも未指定時は `false` として読み込み、公開 HTML、companion CSS、runtime、build 出力へ書き込みません。CLI / MCP の project summary はそれぞれ `isSidebarHidden` と `isCanvasHidden` を返します。

Page の「完全に削除」は表示状態の変更ではありません。同じ解決済み HTML path を使う Page / Component 配置が `.ogp` 内に一つだけの場合に限り、Page entry、対象 Page node を指す canvas object reference、HTML、同名 companion CSS を削除します。別配置が同じ HTML を使う場合は source file を共有しているため、この操作を無効にします。

## Canvas Annotation Contract

キャンバス注釈は Pages では `chapters[].annotations[]`、Components では `collections[].annotations[]` を正本とします。個別 page / component の HTML card に属さず、同じ Chapter / Collection 内の card 群より前面へ描画します。

注釈の `frame` は page / component の `canvas` と同じ左上原点の canonical world 座標、ink point は annotation frame 左上を原点とする frame-local 座標です。pan、zoom、page title card の表示オフセットを永続値へ混ぜません。

注釈の追加、本文編集、移動、手書き、消しゴム、なげわ選択後の一括操作は `.ogp` だけを更新します。なげわの複数選択状態自体は editor の一時状態であり、永続化しません。HTML、companion CSS、`OpenGraphite.css`、locale resource、runtime script を変更せず、DOM node、`data-og-*`、CSS rule、build 展開結果として出力しません。`screenshot canvas` はマルチモーダル確認用に WebKit snapshot の前面へ注釈を合成しますが、`screenshot page` / `screenshot node` は個別 HTML の画像として注釈を含めません。

保存 schema、入力デバイス、Sidecar、CLI/MCP、後方互換、実機受入の詳細は [CanvasAnnotations.md](CanvasAnnotations.md) を正本とします。

## Canvas Aids Contract

Ruler、Guide、Grid は design source ではなく editor preview 補助です。3機能の表示可否は app の `UserDefaults` に保存します。Guide の方向と位置だけは Pages の `chapters[].guides[]`、Components の `collections[].guides[]` を project 正本とし、HTML、companion CSS、`OpenGraphite.css`、runtime、locale resource、build 出力へ書き込みません。

Guide は `internalID`、`orientation`、`position` を持ちます。位置は page / component canvas と同じ world 座標で保持し、project file の移動、共有、外部編集でも `.ogp` と一緒に移送します。CLI / MCP の project summary は Chapter / Collection ごとの `guideCount` を返しますが、canvas / page / node screenshot には Guide を描画しません。

Ruler、Guide、Grid は scroll、無限余白、document padding、Zoom、canvas content origin を共有座標変換へ通します。Grid は WebView card の背面、Guide は前面、Ruler は有効 Canvas 領域の上・左へ固定表示します。詳細は [CanvasAids.md](CanvasAids.md) を正本とします。

## Editable Node Contract

OpenGraphite は、page / component resource の通常の DOM element を annotation の有無にかかわらず inspection 対象にします。`data-og-id` と `data-og-internal-id` は AI と人が長期に同じ node を指す場合の optional identity であり、読み込みの前提ではありません。

```html
<HeroSection
  data-og-id="hero"
  data-og-internal-id="hero-node">
  <MainTitle data-og-id="title">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

```css
[data-og-internal-id="hero-node"] {
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding: 64px;
  border-radius: 24px;
}
```

一意な `data-og-internal-id` を持つ node は、annotation statusがpartialでもcompleteでもstable `ogref` を返します。それ以外のnodeは、document URL、既存の標準 `id` または安全な selector、DOM path、source range、content hash を組み合わせた session-scoped reference を返します。この reference は inspection とsession内の選択に使えますが、source revisionをまたぐ安定mutation targetとはみなしません。

stable reference が必要な場合だけ明示 `adopt` を使います。adopt は候補 identity、対象 source、変更前後の reference、unified diff を dry-run で返し、明示 apply 時だけ optional ID を source へ追加します。dry-runが返すapply専用proposal referenceは、対象のcontent hash/source rangeに加えてdocument全体のbefore hashと正規化済みscope/display IDを束縛します。applyは同じproposal parameterだけを受理し、sourceまたはproposalが変わっていれば適用せず再dry-runを要求します。open、load、preview、graph、validation、build、無編集保存は adopt を暗黙実行しません。

## CSS Value Editing Contract

OpenGraphite は、編集可能なデザイン値を標準 CSS property として authored CSS source に保持します。project library、HTML と同名の companion CSS、各local linked stylesheet、各embedded `<style>`、inline `style`は別々のsource identityとlossless ASTを持ちます。linked/embedded sourceはbrowser document orderに従い、unlinked project libraryは先頭、unlinked companionは末尾のfallback sourceとしてcascadeします。`public/index.html` の companion は `public/index.css`、`public/docs.html` の companion は `public/docs.css`、component canvas の companion は `_components/<name>.css` です。companionは新しいnode-scoped overrideの書き込み先ですが、inspectionは他sourceをcompanionへraw連結しません。

CSS source parser は stylesheet、selector list、nested at-rule、declaration、comment / whitespace の source range を索引化しますが、無編集時に source を再serializeしません。selector の specificity、source order、inheritance、`!important`、custom property、shorthand、active `@media` scope を cascade trace として評価し、未対応 selector、CSS nesting、未知 at-rule / declaration、comment は opaque source として byte 保持します。

各stylesheetではcandidateだけを抽出し、全source candidateと親computed値を合成した後にcustom property / `var()`を一度だけ解決します。`var()`を含む対応shorthandはraw shorthandと`authoredProperty`を保持し、最終置換後にlonghand componentへ展開します。展開不能なcomponentは該当node/propertyをincompleteにしてwrite-blockします。CSS-wide単一identifierはescapeをsemantic復号しますが、source spellingは変更しません。`revert` / `revert-layer`は同一author origin内の前candidateへ戻さず、継承propertyは親computed値を維持し、非継承propertyはauthor値を除いてUA fallbackへ委ね、該当propertyをincompleteにします。共有headless validatorは対応propertyのkeyword、box / inset geometry、標準length unit / percentage / unitless zero、typed `calc()` / `min()` / `max()` / `clamp()`、grid track、数値grammarを検証します。math resultはnumber / percentage / length / length-percentageを区別し、propertyが受け付ける型だけをresolved winnerにします。無効・未対応なauthored sourceはraw保持してwinnerを断定せず、該当node/propertyをincompleteにします。構文上有効な`env()` / `anchor()` / `anchor-size()`もraw authored valueを保持しますが、environment / layout依存値をheadlessで確定しないためresolved winnerを返しません。明示setの無効値、top-level `;`による別declaration、またはtop-level `!important`のvalue注入は`invalid-css-property-value`でatomicに書込前拒否します。environment依存値のsetはsyntax errorとはせず、node provenanceとpostconditionを安全に確定できないため`incomplete-css-node-provenance` / `incomplete-css-provenance-write-blocked`でatomic no-writeにします。`hidden="until-found"`はdeclaration不在時だけ`content-visibility:hidden`をheadless fallbackとし、authored `initial` / `unset` / `visible`はresolved `visible`として上書きしても標準`hidden` source intentを保ちます。

headless の `page graph` / `node query` / `node get` は media condition を推測しません。呼び出し側が repeatable `--active-media <condition>`（MCP は `activeMediaQueries: string[]`）で明示した条件だけを active candidate として解決し、指定されない `@media` rule も source trace から削除しません。App / WebKit は現在の viewport と environment で computed style を評価し、同じ source candidate と別の観測値として保持します。

responsive winnerの`node style set/remove`（MCPは`set_css_variable` / `remove_css_variable`）にはinspectionと同じactive media集合を渡します。mutationはreview済みwinnerのat-rule provenanceへ書き戻し、base ruleや別conditionへ値を複製しません。

node style mutation は `.ogp` の `cssLibrary` を直接変更しません。trace candidateは`sourceID` / `sourceKind` / `sourceEditable` / `stylesheetOrder` / source内`sourceOrder` / `inherited`を保持します。direct companion / inline winnerは既存declarationだけを最小差分更新できます。read-only project / linked / embedded winnerへのsetは、active media scope、`!important`、specificityを満たす安全なnode-scoped companion overrideを構成できる場合だけ許可します。安全なspecificityを構成できなければ`css-specificity-override-unsafe`、read-only winnerだけのremoveは`read-only-css-winner`、shorthand由来longhandのremoveは`shorthand-css-removal-unsupported`、set後のwinner postconditionを満たせない場合は`css-mutation-postcondition-failed`でno-writeになります。CSS libraryを変更するのは明示的なproject-level design token操作だけです。

外部・root外・読取不能stylesheet、未解決`@import`、malformed CSS、未対応layer/property/selectorはsource-wide incomplete provenanceとしてwarning `incomplete-css-provenance` と既知source inspectionを返し、すべてのCSS mutationを`incomplete-css-provenance-write-blocked`でatomic no-writeにします。`@import`先を独立sourceとして解決したとは扱いません。matching `@supports` / `@container` / `@scope`等の未評価conditional、keyframes sourceとactive animation指定、headlessで確定できないCSS-wide値は、該当node/targetだけをread-onlyにし、mutation時は`incomplete-css-node-provenance`も返します。`@keyframes`定義だけはsource-wide incompleteにしません。pageの`hasIncompleteCSSProvenance`は該当nodeを集約しますが、完全な別nodeまでwrite-blockする意味ではありません。

WebKit computed style は現在の描画値、CSS source AST は authored value と書き戻し provenance です。Appはcomputed `display` / `position` / `visibility` / `content-visibility`とancestorを含むrendered hiddenを観測し、標準`hidden` attributeのauthored有無とは別に扱います。Inspector はcomputedとauthoredを別々に保持し、computed value を見ただけで source declaration を上書きしません。編集時は勝者の authored declaration が安全ならその value range だけを置換し、shorthand / longhand や条件scopeを暗黙に変えず、provenance がない場合だけ既存の安全な selector または明示した新規 rule へ declaration を追加します。

たとえば `padding:14px 20px` は Inspector では top / right / bottom / left として解決できますが、保存時は実際に勝った authored selector の `padding` shorthand provenance を尊重します。`width:min(100%,560px)`、`background:linear-gradient(...)`、`border:1px solid rgba(...)`、`box-shadow:0 18px 44px rgba(...)` も同様に、標準 CSS source のまま保持します。

### Transform Composition Contract

永続的な変形は標準 CSS の individual transform property `scale` / `rotate` と、`transform` / `transform-origin` に保持します。水平 flip は `scale: -1 1`、垂直 flip は `scale: 1 -1` です。これらはブラウザの標準 transform model に従って合成され、OpenGraphite は flip のために `transform` 文字列を合成したり、`scale` の編集で sibling declaration の `rotate` / `transform` を上書きしたりしません。書き戻しは要求された property の authored provenance だけを最小差分で更新します。

drag は session 中だけ individual `translate` を適用し、終了時に元の runtime value へ戻します。reorder の補間は Web Animations API を使います。どちらも project-authored transform property を一時 state の保存先にせず、HTML、companion CSS、static build へ serialize しません。

locale typography は翻訳 resource ではなく標準 CSS の正本です。default font は document / page root selector の `font-family`、locale override は同じ selector scope の `:lang(<BCP47>)` rule、子要素固有 font は通常の `font-family` override として保存します。cascade と inheritance が最終値を決め、既知 locale の固定 allowlist は設けません。外部 Web font が必要な場合、読み込みは HTML `<head>` の stylesheet link に残します。

Inspector と agent interface は CSS source 上の selector、at-rule scope、specificity、source order、inheritance、`!important`、declaration provenance と、WebKit computed `font-family` を分離します。locale rule の編集は既存 declaration の value range を優先して最小差分で書き戻し、別 selector や default scope へ暗黙移動しません。

`--og-padding-top`、`--og-border-color`、`--og-shadow-blur` のような個別編集用の分解変数は、現行契約では正本にしません。CSS として特殊すぎる独自表現は避け、標準 property の shorthand、長さ、色、`min()` / `max()` / `clamp()`、`linear-gradient()` などを優先して扱います。

Inspector が通常 UI として編集できない CSS 値は、無理に代替入力欄へ落とし込まず編集対象にしません。OpenGraphite はリポジトリの正本 HTML / CSS と同期してプレビューすることを目的にし、OpenGraphite 経由ではない編集や他ライブラリの CSS も許容します。`OpenGraphite.css` の編集契約に入らない値は、ブラウザ表示ではそのまま反映されますが、編集は別経路で行う前提です。HTML の inline `style` に editable design value を残すことは、companion CSS が存在する source では validation error です。

## Design Token Contract

page / document theme の正本は root selector に置く標準 `background` / `color` declaration です。muted、accent、foreground などの共有値が必要な project は、通常の CSS custom property を任意に定義し、それを標準 declaration から参照します。OpenGraphite は theme token の名前、カテゴリ、意味、fallback を予約しません。

Project 全体で共有する design token は、`.ogp` の `cssLibrary` が指す CSS file の `:root` rule に CSS custom property として保存します。token は `--color-accent`、`--space-medium`、`--radius-small` のような project-defined の原子的な値であり、OpenGraphite は `OpenGraphite.contract.json` の `designTokens.selector` と `designTokens.namePattern` に従って抽出・編集します。

```css
:root {
  --color-accent: #f5f7f8;
  --space-medium: 16px;
}
```

Design token は node-scoped な companion CSS declaration ではありません。node の見た目は既存の標準 `#id`、安全な authored selector、または注釈済みnodeの `[data-og-internal-id="..."]` rule に標準 CSS property として保存し、その値として `var(--color-accent)` や `var(--space-medium)` を参照できます。このため token の変更は、参照している複数 page / component preview へ CSS cascade として反映されます。

CLI / MCP / Project Inspector は、design token の一覧、依存 selector、追加、値変更、削除を CSS library に対する project-level resource 操作として扱います。token 名は CSS custom property 名でなければならず、現行契約では ASCII の `^--[A-Za-z_][A-Za-z0-9_-]*$` を保存対象にします。token 値は標準 CSS の declaration value として保存し、色、長さ、font stack、shadow、`clamp()`、`color-mix()` などを独自 IR へ分解しません。名前から OpenGraphite 固有の theme semantics を推測したり、特定 token だけを Inspector special case にしたりしません。

## `data-og-*` Attribute Contract

`data-og-*` は、source 上に必要な場合だけ保持する optional OpenGraphite annotation です。意味やコンポーネント名は標準 DOM へ、デザイン値は authored CSS の標準 property へ置き、`data-og-*` には標準 Web から一意に復元できない identity、参照、binding、編集 policy、provenance だけを残します。annotation を一つも持たない HTML も有効です。

| 属性 | 扱い | 意味 | 現在の主な値 |
| --- | --- | --- | --- |
| `data-og-id` | 任意 | ページ内で一意な、人と UI が読める協業用 identity。欠落は error ではない。 | `hero`, `title`, `primary-action` |
| `data-og-internal-id` | 任意 | 表示名や役割から独立した stable `ogref` 用 identity。欠落時は session reference を使う。 | `a4e19c02f6b8` |
| `data-og-type` | legacy inputのみ | 旧分類 hint を `legacyTypeHint` として読めるが、capability の根拠、描画 selector、新規生成には使わない。 | `page`, `frame`, `text`, `button`, `image`, `icon` |
| `data-og-component` | 任意 | component master または `<og-instance>` が参照する component ID。 | `site-header`, `feature-card` |
| `data-og-source-component-internal-id` | 任意 | component placement が参照する component canvas の内部 ID。 | `3bgx6phkz3jv5` |
| `data-og-source-node-internal-id` | 任意 | component placement が参照する source node の内部 ID。 | `hrbifdygbcig` |
| `data-og-icon-library` | 任意 | icon node が参照するアイコンライブラリ。現行のページ配置 UI は `lucide` を生成する。 | `lucide` |
| `data-og-icon-name` | 任意 | ライブラリ内の icon ID。Lucide では kebab-case 名を保持する。 | `circle`, `arrow-right` |
| `data-og-icon-source` | 任意 | icon をページ側に保持するか外部静的資源として参照するかを示す。現行の自動配置は `inline` SVG を保持する。 | `inline`, `cdn`, `library` |
| `data-og-text-source` | 任意 | text node の本文が HTML 直書きか外部 binding 由来かを示す。 | `binding` |
| `data-i18n-key` | 任意 | text binding 型 localization で翻訳リソースを参照する key。 | `home.hero.lead` |
| `data-og-text-variant-eng` | 任意 | `data-i18n-key` を持つ binding text の英語 fallback / sample variant。推奨正本は locale JSON。 | `Edit with AI` |
| `data-og-locked` | 任意 | ノードの編集をロックする永続的な編集状態。`true` のとき選択表示と編集操作がロック状態として扱われる。 | `true` |

この表は source に永続化できる annotation だけを列挙します。component の variant、slot assignment、公開 styling hook、ARIA role は標準 `variant` / `slot` / `part` / `role` 属性です。editor / runtime の一時状態は `data-og-*` attribute として公開 contract に加えず、[Runtime-Private Editor State Contract](#runtime-private-editor-state-contract) に従います。

### `data-og-id`

`data-og-id` は、長期の協業で役立つ optional な表示 ID です。存在する場合は同じ HTML ページ内で一意である必要があります。欠落 node も標準 `id`、tag、accessible name、DOM path などから Layers / Inspector の session label を得ます。

Layers、Inspector、Canvas は annotation status と reference stability を表示できます。Agent / CLI / MCP は stable annotation がある場合は typed `ogref`、ない場合は locator と content hash を伴う session-scoped reference を返します。

### `data-og-internal-id`

`data-og-internal-id` は、表示名や意味から切り離された optional な内部不変 ID です。存在する場合は typed agent reference の node 部分に使います。OpenGraphite は読み込み時、inspection、validation、無編集保存を理由にこの属性を補完しません。明示 adopt の apply だけが、dry-runで提示したsource revisionと同じscope/display IDを持つproposal targetへ新しい不透明 ID を保存できます。

### Operation Capability と legacy `data-og-type`

OpenGraphite は node を単一の編集プリミティブへ分類しません。標準 tag、DOM の direct text / children、native control、link、ARIA role、media / SVG / mask 実体、project root、resolved `display` などを evidence として、操作ごとに次の capability を複数返します。

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

同じ node が、たとえば direct text を持つ native button として `edit-text` と `edit-control` の両方を持てます。未知の標準 element や Custom Element も evidence のある操作だけを受け取り、曖昧な `page` / `frame` / `text` enum へ強制しません。Agent graph はraw value昇順のdeterministicな `capabilities` 配列と、`isProjectResourceRoot`、`isNativeControl`、`isCustomElement`、`isLink`、`hasDirectText`、`hasElementChildren`、`hasMediaContent`、`hasSVGContent`、`hasMaskContent`、optional `ariaRole`、optional `resolvedDisplay` を持つ `capabilityEvidence` を返します。

機械可読な正本は`OpenGraphite.contract.json`のtop-level `capabilityPolicy`です。`operations`は上記11 raw valueの昇順配列、`evidenceFields`は上記11 field、`legacyTypeAttribute`は`data-og-type`、`legacyReadOnlyHint`は`true`、`generated`は`false`、`queryMatch`は`all`です。Swift built-in contractとJSON resourceは同じ内容を返します。

App、CLI、MCP は同じ配列をoperation gateに使います。child insertion / receptionは`receive-children`、inline text sessionは`edit-text`、link / media / icon / native control Inspectorは対応する`edit-*`、layout Inspectorは`edit-layout`、Canvas dragは`drag-position`、flow reorderは`reorder-flow`、group操作は`group` / `ungroup`を要求します。legacy hintから不足capabilityを補ったり、単一capabilityだけを選んで他を捨てたりしません。

旧 source に `data-og-type` が存在する場合だけ、その raw valueを `legacyTypeHint` として保持します。既知の旧値 `page`、`frame`、`text`、`button`、`image`、`icon` は migration / compatibility の参考にできますが、操作許可や描画結果を上書きしません。OpenGraphite はこの属性を新規 HTML、adoption、node insert / replace、runtime、static buildへ生成せず、`OpenGraphite.css` もtype selectorやtype別既定値を持ちません。

### Media Rendering Contract

media wrapper は選択、サイズ、overflow などの frame を持ち、描画値は実体 element に保存します。`img` / `video` の fit は実体 selector の標準 `object-fit`、inline SVG の線幅は `svg` または SVG descendant selector の標準 `stroke-width`、CSS mask は mask child の `mask-image` / `-webkit-mask-image` が正本です。

Inspector で wrapper を選択した場合も DOM relation から実体 `img` / `video` / `svg` / mask child を解決し、その element に適用された CSS source trace と WebKit computed style を表示します。書き戻しは実体 declaration の selector / at-rule / specificity / `!important` provenance を維持し、wrapper に OpenGraphite helper を作りません。

### Icon Source Contract

UI icon や装飾 icon の描画実体は標準 SVG / mask / image です。OpenGraphite は DOM relation と実体から `edit-icon` capabilityを算出し、`data-og-icon-*` metadataは出自の追跡にだけ使います。

初期対応ライブラリは Lucide です。Canvas の icon ツールは次のような inline SVG を生成し、ページ HTML 側にそのまま保持します。

```html
<Icon
  data-og-id="icon"
  data-og-icon-library="lucide"
  data-og-icon-name="circle"
  data-og-icon-source="inline"
  data-og-internal-id="icon-node">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
    <circle cx="12" cy="12" r="10"></circle>
  </svg>
</Icon>
```

```css
[data-og-internal-id="icon-node"] {
  width: 24px;
  height: 24px;
}

[data-og-internal-id="icon-node"] > svg {
  stroke-width: 1.75;
}
```

`data-og-icon-source="inline"` は、配布 HTML が CDN や JavaScript runtime なしで icon を描画できる形です。`cdn` は `lucide-static` の SVG URL を CSS mask として保持し、`library` は実装側 icon loader など、静的に解決できる外部資源を使うための metadata として予約します。どの方式でも `data-og-icon-library` と `data-og-icon-name` は人間とAIが icon の出自を追跡するために残します。

CDN mask の source は通常の child と標準 CSS で表します。mask かどうかは `mask-image` / `-webkit-mask-image` の authored / computed value から導出し、専用 attribute を要求しません。

```html
<Icon
  data-og-icon-library="lucide"
  data-og-icon-name="sparkles"
  data-og-icon-source="cdn">
  <span aria-hidden="true" class="sparkles-mask"></span>
</Icon>
```

```css
.sparkles-mask {
  background-color: currentColor;
  -webkit-mask-image: url("https://cdn.example/icons/sparkles.svg");
  mask-image: url("https://cdn.example/icons/sparkles.svg");
}
```

Icon wrapper のサイズは companion CSS 上の `width` / `height`、色は `color` です。inline SVG の線幅は実体の `stroke-width`、CDN mask URL は child の両 mask property に保存します。`data-og-icon-library` / `data-og-icon-name` / `data-og-icon-source` は描画に使う switch ではなく、AI と人が icon の出自と再取得方法を追跡する optional provenance として維持します。

### Standard Layout And Positioning

layout の正本は authored CSS と browser の computed style です。OpenGraphite は `display`、`flex-direction`、`grid-template-*`、`grid-auto-*`、`gap`、alignment、各 child の `position` / inset を読み、Flex、Grid、Block、absolute、flow と positioned child の混在、project-defined layoutをそのまま扱います。単一の親 enumへ縮約しません。

Inspector の layout operation は DOM semantics と現在の computed `display` から capability を決めます。Flex方向の変更は勝者である `display` / `flex-direction` declaration、Grid編集はgrid declaration、位置編集は対象child自身の `position` / inset provenanceへ書き戻します。親をflowへ変える操作でchildのauthored absolute declarationを削除する必要がある場合は、対象となる各childのdiffを明示し、無関係なnested declarationや寸法を変更しません。

responsive layout は authored `@media` の selector / condition / source orderを保持します。headless inspectionは明示されたactive media conditionだけを解決へ反映し、WebKit previewは実viewportでcomputed resultを観測します。未知rule、inactive rule、commentを再serializeや削除の対象にしません。

### Standard `role` と visual variant

ARIA semantics は標準 `role`、component variant は Custom Element host の通常の `variant` token attributeで表します。`page-preview`、`landing-hero`、`primary-button`、`card`、`eyebrow`、`muted` のように見た目だけを選ぶ値はARIA roleへ流用せず、class、component selector、host attribute、またはpage-local selectorで表します。旧`data-og-role`は明示migrationの入力に限り、新規source、contract、runtime、buildへ生成しません。component placementは要素名`og-placement`から判定します。

## Reference And Slot Contract

component master は Collection 内の source file に、hyphenを含む標準Custom Element hostとその直下の`<template>`として置きます。hostの`data-og-component`は`.ogp` component registryと`<og-instance>`を結ぶOpenGraphite固有の安定参照です。master判定は登録resource、hyphenated host、template ownershipから行い、種別attributeを要求しません。Pages側は`<og-instance data-og-component="...">`で参照し、子要素の標準`slot`属性でtemplate内の`<slot name="...">`へ内容を渡します。template内の相対`href` / `src`はpageではなくcomponent master source fileのURLを基準に解決し、HTTP runtime、`file://` Canvas preview、screenshotで同じstylesheetとassetを参照します。

```html
<feature-card
  data-og-id="feature-card-master"
  data-og-component="feature-card"
  part="root"
  variant="availability">
  <template>
    <article part="surface">
      <slot name="title"><h2>Fallback title</h2></slot>
      <slot>Fallback body</slot>
    </article>
  </template>
</feature-card>

<og-instance data-og-id="availability-card" data-og-component="feature-card">
  <span slot="title">Availability-ready card</span>
  <p>First body node</p>
  <p>Second body node</p>
</og-instance>
```

```css
feature-card {
  display: flex;
  flex-direction: column;
}

feature-card[variant~="availability"]::part(surface) {
  border-color: currentColor;
}
```

named slotは`<slot name="title">fallback</slot>`、default slotは`<slot>fallback</slot>`で表します。instance側で同じ`slot`名を持つ複数elementはdocument orderのまま同じslotへ割り当てられ、割り当てがない場合だけslot内部のfallbackが表示されます。instance固有なのはlight DOM contentと通常のhost attributeであり、shadow treeの構造と内部CSSはmaster由来です。分岐はhostの`variant` token、class、別master、またはslotへ渡す子構造で表します。

instance側のslot contentは`<span slot="title">...</span>`のように直接渡します。複数nodeは同じslot属性をそれぞれに付けます。`<template slot="...">`はtemplate要素自身が割り当てられるだけでcontentを表示しないため、複数node wrapperが必要なら`<div slot="..." style="display: contents">`など通常のlight DOM elementを使います。

```html
<og-instance data-og-id="code-viewer-a" data-og-component="code-viewer">
  <div slot="preview" style="display: contents">
    <PreviewCard data-og-id="preview-card">
      <PreviewText data-og-id="preview-text">
        Instance specific preview
      </PreviewText>
    </PreviewCard>
  </div>
</og-instance>
```

標準`part`はshadow tree内部の公開styling hookです。page CSSは`feature-card::part(surface)`のように利用し、runtimeとstatic buildの両方でbrowserの`::part()` semanticsへ委ねます。runtimeはmaster templateをopen Shadow DOMへcloneし、static buildは同じtemplateへ`shadowrootmode="open"`、`shadowrootclonable`、`shadowrootserializable`を付けたDeclarative Shadow DOMを出力します。document orderで最大32段まで再帰展開し、循環参照は`component-expansion-cycle`として失敗します。再renderは既存展開を置換して増殖せず、serialize時はauthored`<og-instance>` sourceを復元します。

## Placement Contract

component placement は、Collection 内の component canvas にある既存 component node を、同じ component canvas 上へ別状態で並べるための永続 HTML node です。Chapter / Pages には配置できず、公開 page の構造ではなく編集用の表示です。`.ogp` の page / component card ではなく、通常の OpenGraphite node と同じ DOM 階層に置きます。表示用に生成された clone は直接編集対象にしません。

placement hostは要素名だけで判定できる`<og-placement>`として表します。`data-og-source-component-internal-id`は参照元component canvas、`data-og-source-node-internal-id`は参照元nodeを指します。現在の実装では、参照元componentはplacementが置かれているcomponent canvasと一致し、参照元nodeは同じcomponent HTML内に存在する必要があります。placement hostはLayers上で開閉できる参照表示として扱い、内部に表示されるclone nodeは選択できますが実体を持ちません。clone nodeへのInspector / Canvas編集は同じ`data-og-internal-id`を持つ参照元component nodeに保存され、全placementに同期されます。placement側に明示した標準CSS propertyは、component companion CSS上のplacement host ruleとして保存し、そのplacementだけの表示枠overrideとして扱います。

```html
<og-placement
  data-og-id="code-viewer-preview-placement"
  data-og-internal-id="67a2e12dbed8"
  data-og-source-component-internal-id="3bgx6phkz3jv5"
  data-og-source-node-internal-id="hrbifdygbcig">
</og-placement>
```

```css
[data-og-id="code-viewer-preview-placement"] {
  display: flex;
  flex-direction: column;
}
```

placement に `width` / `height` などの明示 override がない場合、表示フレームは参照先 component node の標準サイズ、companion CSS declaration、内容の自然な bounds に従います。placement に同名 CSS property を明示した場合は、その placement だけが参照先 root の標準サイズを上書きします。component master の `width` は component CSS の標準サイズであり、instance override は page CSS、placement override は component CSS の placement host rule に保存します。

placement 単位の mock injection は HTML ではなく、`.ogp` の canvas `previewContext.placementMocks` へ保存します。HTML は component / placement が持つ構造、参照、標準サイズ、個別デザイン override を正本として持ち、`.ogp` は preview のためだけに注入する runtime parameter を持ちます。`placementMocks` の key は placement host の `data-og-internal-id` を第一候補、`data-og-id` を fallback として解決します。両方の key が存在するときは internal ID 側だけを使い、display ID 側の field を merge しません。

```json
{
  "previewContext": {
    "fieldMocks": {
      "selectedLanguage": "ja"
    },
    "placementMocks": {
      "placement-code-internal": {
        "host.variant": "code"
      },
      "placement-preview-internal": {
        "host.variant": "preview"
      },
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
```

`previewContext.fieldMocks` は canvas 全体へ注入する mock state です。`previewContext.placementMocks` は指定 placement の clone を表示するときだけ追加で注入し、同名 field では placement 側を優先します。state field は `host.<attribute>` を使い、通常の host attribute、`aria-*`、`variant` などへ投影します。attribute 名は lowercase に正規化し、`^[a-z_:][a-z0-9_.:-]*$` に一致する名前だけを受理します。`host.class` は source の class を置換せず、空白区切り token を追加します。標準 boolean attribute は `0` / `false` / `no` / `off` を不在、それ以外を present-empty として扱います。`data-og-*`、event handler の `on*`、`id`、`style`、`slot`、`part` は identity、provenance、code 実行、projection、styling hook を壊すため注入できません。`host.*` 以外の project-defined field は runtime context / preview-state event には残せますが、clone の DOM state へは投影しません。

project runtime、App Canvas、CLI / MCP screenshot はこの一時 state を生成 clone にだけ適用し、component の authored `:host([variant~="preview"])`、`:host(.is-loading)` などの CSS と browser computed style に表示判断を委ねます。source master、placement host、serialized HTML は変更せず、static build にも `.ogp` preview state を出力しません。Sample project は `host.variant`、`host.class`、`host.aria-busy`、`host.aria-expanded` を使った code / preview / loading / collapsed の状態例を同期します。

## Canvas Object Reference Contract

Canvas Object Reference は `ogref:node` / `ogref:component-node` が指す任意階層 node を、Chapter / Collection キャンバス直下へ別 viewport として配置する `.ogp` 専用 metadata です。component placement と異なり、HTML 内に host node や clone を作らず、配置先 segment と参照元 segment が異なっていても構いません。

Pages canvas は `chapters[].references[]`、Components canvas は `collections[].references[]` に、配置 ID、typed node reference ID、canonical world frame だけを保存します。配置 viewport からの編集は参照元 HTML / companion CSS へ反映し、参照表示を page card や HTML object の子へ格納しません。詳細は [CanvasObjectReferences.md](CanvasObjectReferences.md) を正本とします。

## Text Binding Contract

`data-og-text-source="binding"` は、text node の表示テキストが HTML 本文だけでなく locale resource や runtime state から差し替えられることを示します。`data-i18n-key` はその翻訳単位を識別する標準的な key です。fallback content は HTML 内に残し、JavaScript や build 処理が使えない場合にもページ単体で読める状態を保ちます。

このbinding metadataは描画selectorではありません。長い語やURLの折返しは、対象selectorまたは継承元へ置く標準 `overflow-wrap` / `word-break` declarationが正本です。`data-og-text-source`の有無だけでdistributed CSSがwrapを変更しません。

locale text の推奨正本は実装側の resource、標準構成では `public/locales/<locale>.json` の flat key JSON です。HTML に同梱する `data-og-text-variant-<locale>` は lightweight fallback / sample として残せますが、OpenGraphite runtime がこの属性を正本として解決することはありません。実装 runtime が表示のために作る一時 DOM 変更と fallback provenance は runtime-private object に保持し、保存 HTML へ残しません。

### I18n Runtime Resources

i18n 設定の正本は `.ogp` ではなく実装ファイルです。OpenGraphite は page HTML の `script` / `type="module"` script から辿れる範囲で `i18n.init({...})` を検出し、`lng`、`fallbackLng`、`backend.loadPath` を表示します。`backend.loadPath: "/locales/{{lng}}.json"` のような literal は editable resource path として扱い、`import.meta.env.VITE_I18N_LOAD_PATH` や関数式などの dynamic expression は external / read only として扱います。

OpenGraphite preview は `selectedLanguage=eng` などの Mock State を注入するだけです。実際の text 解決、locale JSON の読み込み、DOM 反映は HTML 側の実装 runtime が担当します。推奨 runtime を作成する導線は `public/i18n.js` と `/locales/{{lng}}.json` を生成できますが、生成後も正本はそれらの実装資源です。

locale 別 font-family の保存先は locale JSON ではなく、root の `font-family` と同じ scope にある標準 `:lang(<BCP47>)` rule です。runtime / preview は clone の標準 `lang` / `dir` だけを一時変更し、解決結果は WebKit computed `font-family` から読みます。旧 `--og-font-family-default`、`--og-font-family-<locale>`、`--og-active-font-family` は compatibility reader と明示 migration の入力に限り、新規 source や runtime state へ生成しません。

Project セグメントは `.ogp` が参照している実装資源と依存性を選択する仮想階層です。`I18n Runtime`、`Locale Resources`、CSS、runtime script など page をまたぐ資源は Project セグメントで選択し、Inspector から実装ファイルへ書き戻します。Page Inspector の i18n 表示は、その page が解決した共有 runtime の read-only summary と Project セグメントへの導線に留めます。

### Resolved Text Editing

Canvas / preview 上でユーザーが表示済みの text を直接編集した場合、OpenGraphite はその時点で解決されて表示されている text resource を編集対象とみなします。たとえば `selectedLanguage=ja` の Mock State と実装 runtime から `data-i18n-key="home.hero.title"` の `ja` text が描画されているなら、その直接編集は locale JSON などの該当 resource へ保存します。field 名や binding metadata そのものを text content として書き換えません。

HTML fallback だけで表示されている text node、または明示的な locale / runtime resource へ解決できない text node は、HTML 本文の fallback content が編集対象です。fallback content は引き続き正本 HTML の readable default として残します。

Inspector は active preview で解決された variant だけでなく、解決に使える field/value の variation ごとの text を表示し、現在 preview していない variant も編集できるようにします。たとえば `selectedLanguage` が `ja` / `eng` を取り得る場合、Canvas 上の直接編集は現在解決中の `ja` text を更新し、Inspector では `ja` と `eng` の text を個別に編集できます。

Preview Mock State は「どの variant を表示するか」を決める editor preview 用の一時 state です。Mock State の値そのものは text resource ではなく、HTML document attribute / metadata や locale resource の保存先とも分離します。

### Document Attributes

`<html lang>` と `<html dir>` は preview mock ではなく HTML 正本の document attribute です。Literal の場合は `lang` / `dir` 属性へそのまま保存します。実装側の state に bind する場合でも `lang="selectedLanguage"` のように変数名を HTML 属性へ直接入れず、`lang` / `dir` には fallback 値を残し、OpenGraphite metadata で参照 field を保存します。

- `data-og-lang-source="literal|binding"`: `lang` の解決方式。
- `data-og-lang-field`: `data-og-lang-source="binding"` のとき参照する runtime field 名。
- `data-og-dir-source="literal|auto|binding"`: `dir` の解決方式。`auto` は resolved lang から `ltr` / `rtl` を推定する。
- `data-og-dir-field`: `data-og-dir-source="binding"` のとき参照する runtime field 名。

```html
<html
  lang="ja"
  dir="ltr"
  data-og-lang-source="binding"
  data-og-lang-field="selectedLanguage"
  data-og-dir-source="auto">
```

## Visibility And Lock Contract

永続的なHTML非表示は標準boolean `hidden` attributeです。通常の`hidden`の非表示はbrowserのUA stylesheetへ委ね、`OpenGraphite.css`にglobal hidden selectorや`display: none !important`を重ねません。CSSによる表示状態はauthored `display` / `visibility` declarationとして保持し、両者を同じ値へ潰しません。graphのsource stateは`hidden` attributeを、source traceは`display` / `visibility`の候補と勝者を、WebKit computed styleは現在の描画結果をそれぞれ分離して返します。`hidden="until-found"`は通常のboolean hiddenへ正規化せず、標準semanticsを保持します。

`data-og-locked="true"` は、ノードを編集ロック状態として扱う永続状態です。ロックされたノードは通常の編集操作を拒否し、選択表示はロック状態として区別します。

## Runtime-Private Editor State Contract

選択、直接編集、Focus preview、drag、reorder、frame preview は app session の state です。選択枠と frame preview は native overlay、keyboard focus は `:focus`、直接編集は session 中だけの `contenteditable`、対象 node と original value は JavaScript object / `WeakMap` で管理します。編集時の寸法補助は overlay または標準 `width` / `min-height` の一時値を使い、drag は individual `translate`、reorder の補間は Web Animations API を使います。project が authoring した `transform` / `rotate` / `scale` は session state の保存先にしません。

Focus preview は Normal / Flow の canvas mode とは独立した session-only preview です。Canvas 上の HTML object または page card を右クリックして開始し、対象を preview 領域の中央へ表示します。通常 canvas と同じ Zoom 値・入力解決器を使い、object isolation は runtime-private object reference と overlay state で解決します。Focus、選択、編集、drag、reorder のいずれも `OpenGraphite.css` の読み込みを前提にしません。

component runtime の展開済み判定、生成 node と source の対応、slot provenance、clone / error state も JavaScript object / `WeakMap` などの runtime-private registry に保持します。必要な provenance は runtime API 内で参照できても source attribute ではなく、agent graph、serialization、static build へ露出しません。

旧 runtime helper 属性と `--og-preview-*` / `--og-edit-*` / `--og-drag-*` / `--og-reorder-*` は compatibility reader と明示 migration の入力に限ります。通常の open、preview、inspection、無編集保存はそれらを追加・変換せず、明示 migration は dry-run / diff を提示して既知 helper だけを除去します。

## Rendering Contract

`OpenGraphite.css` は app 内の `WKWebView` と通常ブラウザの両方で共有するproject tokenと、標準Webから復元できない限定的affordanceだけを提供します。標準elementや未知のHTMLを広域selectorでtheme化せず、type reset / type別既定値も持ちません。ページ固有のdisplay、spacing、色、typography、media sizing、icon描画、border、shadowはsemantic tag、class、ARIA、実体selector、同名companion CSSが担います。editor の選択、直接編集、Focus、drag、reorder、frame preview は native overlay と runtime-private state が担い、配布 CSS に session selector や helper custom property を要求しません。

共有描画規則は標準HTMLの既定表示を破壊しない低詳細度の限定affordanceに留めます。page / componentのlayout、responsive rule、visibility、text wrapはproject-authored stylesheetが担います。Custom Elementなどtype-specificなdisplay baselineが必要な場合も同名companion CSSで対象typeへ限定し、通常の`hidden`をauthor ruleで上書きしないguardを付けます。`hidden="until-found"`だけはbrowserがreveal可能なboxを保てる側へ含め、UAの`content-visibility` semanticsへ委ねます。

```css
:where(feature-card):where(:not([hidden]), [hidden="until-found" i]) {
  display: block;
}

.feature-stack {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
```

アプリは HTML を特殊なキャンバス形式へ変換してから描画しません。WebKit が HTML を描画し、OpenGraphite は選択、レイヤー抽出、インスペクタ編集、保存を担当します。`.ogp` 専用注釈と Canvas Object Reference viewport は WebKit card の外側にある editor layer として描画し、HTML の描画規則や DOM 親子関係には参加させません。

## Editor Behavior Contract

OpenGraphite のエディタは、HTML / companion CSS の上に編集体験を重ねる薄いレイヤーです。

- `WKWebView` で対象 HTML と companion CSS を直接表示する。
- resource の通常の DOM node を annotation の有無にかかわらず Layers に反映し、annotation status と reference stability を区別する。
- 選択状態をキャンバス、Layers、Inspector で同期する。
- app 内編集を cache の現在値へ反映し、同じ値を表示する複数 surface へ永続化前に同期する。
- Inspector の design value 編集を companion CSS へ、構造・参照編集を HTML へ反映する。
- Chapter / Collection の注釈を WebView card 群の前面へ重ね、`.ogp` だけへ保存する。
- typed node reference を Chapter / Collection canvas 直下の viewport として表示し、配置 frame は `.ogp`、編集内容は参照元 HTML / companion CSS へ保存する。
- HTML 内の自然なスクロールやブラウザ挙動をできるだけ尊重する。

公開ページへ影響する OpenGraphite 機能は、最終的に HTML と CSS に説明可能な形で落ちることを優先します。公開成果物へ影響しない注釈と参照 viewport の配置情報は `.ogp` に明示的に隔離し、この境界を越えて HTML / CSS / runtime / build へ漏らしません。
