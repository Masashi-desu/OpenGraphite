# ogkiln CLI Specification

`ogkiln` は OpenGraphite project (`.ogp`) を headless に inspection / validation / edit する CLI である。HTML は構造と参照の正本、同名 companion CSS は新しいnode-scoped overrideの書き込み先であり、inspectionではproject / linked / embedded / inline CSSもauthor sourceとして扱う。CLI の編集対象は常に `.ogp` の `chapters[].pages[]` または `collections[].components[]` に明示された HTML と対応 CSS だけに限定する。Chapter / Collection の付箋・手書きは `.ogp` 専用 metadata として読み取る。

## Principles

- `.ogp` は編集対象資源の可視リストであり、`ogkiln` は `.ogp` を経由しない HTML 書き込みを行わない。
- `projectPath` には `.ogp` path または `current` を指定できる。`current` は OpenGraphite.app が現在開いている `.ogp` を Application Support のレコードから解決する。
- `.ogp` にない既存 HTML を編集したい場合は、先に `project page add` または `project component add` で可視リストに追加する。
- 新規 HTML を配置したい場合は、`project page create` または `project component create` で HTML 作成と `.ogp` 登録を一体で行う。
- page は `--page-id`、component は `--component-id` で指定する。一意な `data-og-internal-id` を持つ node は raw internal ID または stable `ogref:node` / `ogref:component-node`、internal IDのないnodeはgraphが返すsession reference / locatorでinspectionする。annotation statusとstabilityは独立しており、partial annotationでもinternal IDがあればstableである。stable typed node reference は対象 page / component canvas も解決できる。raw ID、session reference、selector、DOM path は `--page-id` / `--component-id` の一方を必要とし、両方の同時指定は invalid である。
- write operation は書き込み前に candidate HTML / companion CSS を validation し、`error` diagnostic がある場合はファイルを書き換えない。
- runtime-private state は正本 HTML / CSS に書き込まない。旧 runtime helper は明示 migration の legacy input であり、通常の open / inspection / 無編集保存では追加・変換しない。
- `data-og-id` / `data-og-internal-id` は inspection の必須条件ではない。`page graph`、`node query/get`、`validate`、`build` は標準 HTML をそのまま読み、annotation を自動追加しない。旧 `data-og-type` も任意のlegacy hintとして読むだけで、新規sourceへ生成しない。
- `annotation list|get` は `.ogp` 注釈の読み取り専用操作であり、HTML / CSS を更新しない。
- 出力は JSON を基本とし、MCP server はこの JSON をそのまま tool result として返せる。

## Project Commands

```bash
ogkiln contract get --json
ogkiln project current --json
ogkiln project create --root <project-root> --output <project.ogp> --json
ogkiln project inspect <project.ogp|current> --json
ogkiln migrate <project.ogp|current> [--target-version 1.0.0] [--proposal <proposal-reference> --apply] --json
ogkiln validate <project.ogp|current> --json
ogkiln build <project.ogp|current> --output <dir>
```

`project current` は OpenGraphite.app が最後に開いた `.ogp` の summary を返す。アプリを介さず CLI だけで作業する場合は明示的な `.ogp` path を指定する。

`project inspect` の Chapter / Collection summary は、各キャンバスに保存された `.ogp` 注釈数を `annotationCount`、Guide 数を `guideCount`、Canvas Object Reference 配置数を `referenceCount` として返す。参照配置の write command は提供しない。

`project create` は `--root` で指定した project root を HTML/CSS の解決基準とし、`--output` で指定した場所に新規 `.ogp` を作成する。`--output` に `.ogp` 拡張子がない場合は補完する。`.ogp` の配置ディレクトリと project root が異なる場合は、`.ogp` から見た相対 `repositoryRoot` を保存する。project root に `public` がない場合は `public/index.html`、`public/index.css`、`CSS/OpenGraphite.css` と `home` page entry を作る。既存 `public` がある場合は HTML を自動登録せず空 Chapter の manifest を作り、`CSS/OpenGraphite.css` がなければ CLI が解決した seed をコピーする。

`build`はPages HTML内の`<og-instance data-og-component>`を、Collection内component HTMLに登録された`data-og-component`付きhyphenated Custom Elementとその直下`template`から展開し、指定出力ディレクトリへ静的HTMLを生成する。templateには`shadowrootmode="open"` / `shadowrootclonable` / `shadowrootserializable`を付け、named/default slotのlight DOM、host `variant`、`part`、nested componentをbrowser runtimeと同じsourceからDeclarative Shadow DOMとして保持する。最大深さは32で、循環は`component-expansion-cycle` errorになる。同一入力の2回buildはbyte一致する。component CollectionのHTMLとruntime scriptは公開pageとして出力せず、OpenGraphite.css、companion CSS、`htmlRoot`配下の非HTML静的assetは出力先へコピーする。ただしeditor-onlyの入力`.ogp` manifestはassetとしてコピーしない。Pages HTMLのOpenGraphite.css参照は、出力先内のCSSを指す相対pathへ書き換える。`chapters[].annotations` / `collections[].annotations`はbuild入力として無視し、付箋本文、色、stroke、annotation IDを生成HTML / CSSへ注入しない。`references[]`も参照clone、typed ID、frameを生成物へ注入しない。

## Web Contract Migration

```bash
ogkiln migrate <project.ogp|current> --target-version 1.0.0 --json
ogkiln migrate <project.ogp|current> --target-version 1.0.0 --proposal <proposal-reference> --apply --json
```

`migrate` はWeb contract `0.1.0`から`1.0.0`へのproject-scoped migrationです。.ogp manifestのschema/versionとAgent JSON `schemaVersion`は変更しません。project rootの`OpenGraphite.contract.json`はAppが読むtool configurationであり、proposal targetにもdiff/apply candidateにもせずbytesを維持します。`--target-version`省略時もrepository contractの`targetVersion`である`1.0.0`を使い、それ以外は`unsupported-migration-target-version`でno-writeにします。

`--apply`を付けない実行は常にdry-runです。固定options `legacyCatalogVersion: "1"` / `preserveUnknownDataAttributes: true`を使い、target/options/project manifestと、全対象resourceのcanonical relative pathおよびUTF-8 BOMを含むraw-byte SHA-256 content hashを束縛した`proposalReference`、resource別`diffs`、diagnosticsを返します。対象resourceはmanifest、project CSS library、登録HTML、存在するcompanion CSS、HTMLから辿れるproject内actual local stylesheet / executable script、actual linked/embedded CSSから再帰的に辿れるlocal `@import`です。source kindはcharacter-reference復号後のHTML属性値で決め、URL extensionでは補正しません。`<style>`は`type`省略/exact empty/ASCII-CI exact `text/css`、`<link rel~=stylesheet>`は`type`省略またはHTTP-whitespace-trim済みMIME essence `text/css`だけをCSSとし、present-empty link typeは非CSSです。`<script>`はexact empty、ASCII-CI exact `module`、またはexact JavaScript MIME typeだけをexecutableとし、`type`がobsolete `language`に優先します。style/script typeの前後空白・parameter、JSON/JSON-LD/import map/speculation rules/unknown data blockはopaqueです。HTML/CSS whitespaceはTAB/LF/FF/CR/SPACE、HTTP whitespaceはFFを除く4文字で、NBSP/vertical-tabはraw valueに残ります。HTML non-void `/>`は閉じずSVG/MathML self-closingは閉じ、semicolonなしdecimal/hex numeric referenceもsemantic decodeします。extensionless path、inline / embedded CSS、変更しないlocal dependencyもproposalへ束縛し、無関係なcase/entity/CRLF/BOM/triviaを保持します。未知の`data-*`、維持allowlistのoptional identity、component/source reference、binding、editing policy、icon provenanceも保持します。

applyにはdry-runが返したproposalを`--proposal`で必ず渡します。proposalなしは`migration-apply-requires-proposal`です。別project、target/options不一致、manifestまたは対象resourceの追加・削除・rename・raw-byte content変更は`stale-migration-proposal`となり、再dry-runを要求します。既知legacy HTML/CSSと既知`.ogp` preview fieldをすべて変換できた場合だけ全candidateをwriteします。`data-og-type` / layout / icon maskは`.og-migrated-v1-*` class、hiddenは標準`hidden`、variant / partは標準attribute、既知design `--og-*`は`--migrated-v1-*`へ移します。project CSS、executable inline/linked JavaScript、inline event handlerがlegacy inputを読む場合や、実際に新規生成するclass・標準attribute・custom propertyを観測する場合はblockingです。dot/bracket/alias/destructuringとborrowed `call`/`apply`を同じattribute evidenceへ正規化し、exact名は実際に生成するdestination、dynamic名はwhole-attribute変更とだけ交差します。whole `dataset` / `style` evidenceは実際に削除するdataset attribute、inline-style実変更、生成custom propertyとだけ交差します。whole attribute・dynamic DOM・AttributeNodeはHTML attribute変更、whole markupはembedded-style移行を含むHTML source変更、CSSOMはexternal/embedded CSS変更、actual style-textはembedded CSS変更とだけ交差します。ID-based style/link evidenceはruntime参照元HTMLのactual CSS ownerへ束縛します。manifest previewはglobal preview contextから追える`placementMocks` / whole-context alias chain、または新規生成するexact/static-concatenated `host.*` fieldとだけ交差し、fields/document-only accessや無関係objectの同名propertyはsafeです。clean observer projectと無関係なmutationはblockしません。semanticに同値のstandard destinationが既にある場合はgenerated conflictにせず、そのauthored raw spellingを維持してlegacy tokenだけを除去します。manifestは`codeViewerMode=preview`と`placementMode=collapsed`だけを`host.variant`へ変換し、source HTMLへstateを追加しません。

legacy component master/slot、source placement mode/state、unsafe role、未知reserved property、destination collisionはblockingです。登録対象でlegacy inputを検出したprojectに限り、external / 解決不能なbase・stylesheet・runtime、曖昧な`@import`、JavaScript module dependency、runtime legacy reader、missing / project root外 / unreadableなdiscovered dependency、同一canonical URLのCSS/runtime kind conflict (`migration-resource-kind-conflict`) を推測せずblockingにします。legacy input がない clean standard projectは変更不要のno-opです。project load失敗は`migration-project-load-failed`、曖昧なimportは`unsupported-legacy-import-reference`、列挙不能なmodule closureは`unsupported-legacy-runtime-dependency`です。blocking dry-runは`changed: false`、空`diffs`、null proposalでHTML/CSS/.ogpを一切変更しません。applyは各candidateのcommit直前にproposal全closureのraw bytes・存在・canonical path解決を再検証し、staleなら先行commitをrollbackして`stale-migration-proposal`を返します。rollbackはmigration後bytes/modeとのcompare-and-swapで、commit後の外部編集を上書きせず`migration-rollback-failed`を返します。途中のwrite失敗は`migration-write-failed`としてrollbackします。

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

apply後に同じprojectを再dry-runすると`sourceContractVersion: "1.0.0"`、`changed: false`、`diffs: []`になります。source versionはlocal contract fileではなく登録対象sourceのlegacy token検出から決めるため、旧versionのtool configurationが残ってもこのidempotent結果は変わりません。互換readerは`migrationPolicy.legacyReaderRemovalConditions`の全条件が満たされるまでpre-migration inspectionとmigration入力にだけ残り、通常の`project inspect`、`page graph`、`validate`、`build`がsourceを暗黙変換することはありません。

## Page Management

```bash
ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page place <project.ogp|current> --page-id <page-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>]
ogkiln project page document <project.ogp|current> --page-id <page-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
```

`--path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は受け付けない。これにより、ユーザーが `.ogp` で認知できない資源が編集対象になることを避ける。

`project page add` は既存 HTML を `.ogp` の既定 Chapter `pages[]` に追加する。通常は同じ HTML path の重複登録を拒否するが、同じ正本 HTML を別 preview context で並べたい場合だけ `--allow-duplicate-path` を指定できる。`project page create` は HTML ファイルを作成してから同じ操作内で既定 Chapter `pages[]` に登録する。`canvas` は `--x`、`--y`、`--width`、`--height` で指定し、省略時は `0,0,1440,1200` になる。`project page place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。`--preview-mock key=value` は実装が参照する任意の runtime Mock State を `.ogp` の canvas metadata へ保存する。空文字 override は `--preview-mock key=` と指定する。component placement は Chapter / Pages に配置できないため、placement-local な標準 host state の更新は `project component place --preview-placement-mock <placement-id:host.attribute=value>` で行う。

`project page document` は HTML 正本の `<html>` attribute と OpenGraphite metadata を更新する。`--lang-source literal` は `lang` を literal 値として保存し、`--lang-source binding` は `lang` に fallback 値を残したまま `data-og-lang-source="binding"` と `data-og-lang-field` を保存する。`--dir-source literal` は `dir` を literal 値として保存し、`--dir-source auto` は `data-og-dir-source="auto"` を保存して preview/runtime で resolved lang から `ltr` / `rtl` を推定する。`--dir-source binding` は `dir` に fallback 値を残し、`data-og-dir-field` を保存する。変数名を `lang` / `dir` 属性へ直接保存してはならない。

## Component Management

```bash
ogkiln project component add <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component place <project.ogp|current> --component-id <component-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>] [--preview-placement-mock <placement-id:key=value>]
ogkiln project component document <project.ogp|current> --component-id <component-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
ogkiln project component remove <project.ogp|current> --component-id <component-id> [--delete-file]
```

Components は Collection ごとに component master を置く asset canvas として扱う。`project component add/create` は `.ogp` の `collections[].components[]` を更新し、`--collection-id` で登録先 Collection を指定できる。未指定時は先頭または既定 Collection を使う。node edit 系コマンドは `--component-id` で Components HTML を直接編集できる。`canvas` の省略値は `0,0,960,900` である。`project component place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。`--preview-mock key=value` は canvas 全体の runtime Mock State を更新する。空文字 override は `--preview-mock key=` と指定する。`--preview-placement-mock placement-id:key=value` は component canvas 内の placement preview 用に `.ogp` の `previewContext.placementMocks` を部分更新する。placement ID は `data-og-internal-id` を指定するのが正本で、runtime はその entry がなければ `data-og-id` へ fallback し、両方を merge しない。標準状態は `host.variant=preview`、`host.class=is-loading`、`host.aria-busy=true` のような汎用 field で表し、HTML 正本へ状態属性を書かない。`project component document` は page と同じルールで component HTML 正本の document attribute と metadata を更新する。`remove` は既定では `.ogp` の登録だけを削除し、`--delete-file` を付けた場合のみ HTML file も削除する。

## Annotation Read Commands

```bash
ogkiln annotation list <project.ogp|current> --chapter-id <chapter-id> --json
ogkiln annotation list <project.ogp|current> --collection-id <collection-id> --json
ogkiln annotation get <project.ogp|current> --chapter-id <chapter-id> --id <annotation-id> --json
ogkiln annotation get <project.ogp|current> --collection-id <collection-id> --id <annotation-id> --json
ogkiln annotation get <project.ogp|current> --id <ogref-annotation-id> --json
```

`annotation list` は `--chapter-id` または `--collection-id` のどちらか一方を必須とする。selector は表示 ID、内部 ID、`ogref:chapter` / `ogref:collection` を受け付ける。返す一覧は `internalID`、`referenceID`、`kind`、canonical world `frame`、付箋の text / color、`strokeCount`、`pointCount` を持ち、ink の point 列は展開しない。

`annotation get` は raw annotation internal ID と明示した Chapter / Collection、または `ogref:annotation:<pages|components>:<containerInternalID>:<annotationInternalID>` を受け付ける。typed ID だけでコンテナを解決でき、完全な `strokes[].points[]`、筆圧、傾き、入力デバイスを返す。typed ID と selector を併記する場合は同じコンテナを指す必要がある。

この interface は読み取り専用である。schema、座標、成果物との境界は [CanvasAnnotations.md](CanvasAnnotations.md) を正本とする。

## Read Commands

```bash
ogkiln page graph <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--active-media <condition>]... --json
ogkiln node query <project.ogp|current> --page-id <page-id>|--component-id <component-id> [filters] [--active-media <condition>]... --json
ogkiln node get <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <node-id|ogref-node-id> [--active-media <condition>]... --json
```

`node query` filters:

- `--id-contains <text>`
- `--capability <capability>`（反復可、all-match）
- `--type <legacy-data-og-type-hint>`（legacy exact-matchのみ）
- `--role <standard-role>`
- `--tag <tag-name>`
- `--text-contains <text>`

`page graph` / `node query` / `node get` はpage/nodeの `hasIncompleteCSSProvenance` と、nodeの `cssSourceTrace` / `cssResolvedValues` / `renderingTargets` を返す。nodeは単一`type` keyを持たず、raw value昇順の`capabilities`、standard-Web上の根拠を示す`capabilityEvidence`、旧属性が実在するときだけoptional `legacyTypeHint`を返す。capability値は`drag-position`、`edit-control`、`edit-icon`、`edit-layout`、`edit-link`、`edit-media`、`edit-text`、`group`、`receive-children`、`reorder-flow`、`ungroup`である。`capabilityEvidence`は`isProjectResourceRoot`、`isNativeControl`、`isCustomElement`、`isLink`、`hasDirectText`、`hasElementChildren`、`hasMediaContent`、`hasSVGContent`、`hasMaskContent`、`ariaRole`、`resolvedDisplay`を持つ。`--capability`を複数指定したqueryはすべてを持つnodeだけを返し、`--type`は`legacyTypeHint`のexact-matchに限る。

各trace candidateは `sourceID`、`sourceKind` (`project` / `companion` / `linked` / `embedded` / `inline`)、`sourceEditable`、`stylesheetOrder`、source内 `sourceOrder`、`inherited` を含む。project CSS、companion CSS、各local link、各`<style>`はraw連結しない個別ASTとして評価する。linked/embedded sourceはdocument orderに従い、unlinked project libraryは先頭、unlinked companionは末尾のfallback sourceとなる。既存inline styleはHTML sourceとして別に合成する。custom property / `var()`の未解決判定は各sheet単体では確定せず、全candidateと親継承値を合成した最終cascadeでだけ行う。`var()`を含む対応shorthandもraw `authoredProperty` / valueをtraceに保持し、その最終置換後にlonghand componentへ展開する。展開不能なcomponentは該当node/propertyだけをincompleteにしてwrite-blockする。CSS-wideの単一identifierはescapeをsemantic復号するが、traceとsourceのauthored spellingを変更しない。各 rendering target は `kind` (`media` / `svg` / `mask`)、`tagName`、`relation` (`self` / `direct-child` / `descendant`)、wrapper 相対の `relationSelector`、companion CSS の `writeSelector`、optional な `targetInternalID`、`authoredValues`、`resolvedValues`、`sourceTrace` を持つ。未注釈の描画 child も DOM relation で解決し、そのために OpenGraphite annotation を追加しない。

`--active-media` はrepeatableで、headless cascadeでactiveとみなすauthored media conditionを指定する。値はstylesheetの`CSSMediaRule.conditionText`相当を正規化して照合する。省略時はviewportを推測せず、`<link media>` / `<style media>` とstylesheet内 `@media` をactiveとみなさない。responseの`activeMediaQueries`は評価に使った条件を返す。nodeの`layout`はresolved `display` / `flex-direction`とHTML UA既定から導出し、`hidden`は標準`hidden` source state、CSSの`display` / `visibility` / `overflow-wrap`はtraceとresolved valuesで分離する。`hidden="until-found"`のheadless fallbackは`content-visibility:hidden`で、author `initial` / `unset` / `visible`はresolved `visible`として上書きするが、`hidden` source stateは維持する。AppのWebKit computed `content-visibility`とancestorを含むrendered hidden判定はCLIのauthored source traceとは別である。

local filesystemで解決できない外部/root外/読取不能 stylesheet、未解決`@import`、malformed CSS、`@layer` / `@property`等のsource-wide未対応at-rule、未対応selectorがある場合は、既知sourceのinspectionを返しつつpageと各nodeの `hasIncompleteCSSProvenance: true` とwarning `incomplete-css-provenance` を返す。このsource-wide incomplete状態で `node style set/remove` はerror `incomplete-css-provenance-write-blocked`となり、HTML/CSSを一切書き換えない。`@import`先を読んだ、またはlayer orderを解決したとは扱わない。

matching `@supports` / `@container` / `@scope` / `@document` / `@starting-style`、graph内にkeyframes sourceがあるactive `animation-name` / `animation`、unknown initial値、`revert` / `revert-layer`、headlessの対応CSS値grammarで無効・未対応なauthored source値は、該当node/targetだけを `hasIncompleteCSSProvenance: true` にする。`revert`系は同じauthor originの直前candidateへ戻さず、継承propertyでは親computed値を保持し、非継承propertyではauthor resolved値を省いてHTML UA fallbackへ委ねる。対応grammarはkeywordだけでなく、geometry、標準length unit、percentage、unitless zero、typed math、grid track、数値propertyを検証し、number / percentage / length / length-percentageを混同しない。invalid declarationはraw sourceを保持してwinnerを断定しない。構文上有効な`env()` / `anchor()` / `anchor-size()`もraw保持するが、headlessではresolved winnerを返さずnode/property incompleteにする。`node style set`へ明示された無効値、top-level `;`による別declaration、またはtop-level `!important`のvalue注入はerror `invalid-css-property-value`でatomic no-writeにする。environment依存値のsetはsyntax errorにはせず、safeなpostconditionを確定できないため`incomplete-css-node-provenance` / `incomplete-css-provenance-write-blocked`でatomic no-writeにする。`@keyframes`定義だけではsource-wide incompleteにしない。page flagは該当nodeの存在を集約するが、完全な別nodeまでread-onlyにはしない。該当targetへのmutationはwarning `incomplete-css-node-provenance` とerror `incomplete-css-provenance-write-blocked`を返してatomic no-writeにする。

responsive winnerを編集する`node style set/remove`にも、inspectionで確認した同じ`--active-media`条件をrepeatして渡す。Coreはactive scopeを含むcascade winnerのsource provenanceへ最小差分で書き戻し、base ruleや別media ruleへ値を複製しない。

```bash
ogkiln node style set Project.ogp --page-id home --id panel --var flex-direction --value column --active-media '(max-width: 720px)'
ogkiln node style remove Project.ogp --page-id home --id panel --var flex-direction --active-media '(max-width: 720px)'
```

node payload 自体は通常の DOM element を annotation の有無にかかわらず返し、`reference`、`annotationStatus` (`none` / `partial` / `complete`)、`referenceStability` (`session` / `stable`)、`locator`、optional `parentReference` を持つ。`locator` は `documentURL`、既存の標準 `id` を優先した optional `selector`、`domPath`、`sourceRange.start/end`、`contentHash` からなる。互換フィールドの `id` / `internalID` は annotation がなければ空になり得る。session reference はその source revision 内の inspection / selection 用であり、永続 mutation target ではない。

## Progressive Adoption Command

```bash
ogkiln node adopt <project.ogp|current> --page-id <page-id> --reference <graph-reference> [--scope node|subtree] [--display-id <id>] --json
ogkiln node adopt <project.ogp|current> --component-id <component-id> --selector <locator-selector> [--scope node|subtree] [--display-id <id>] --json
ogkiln node adopt <project.ogp|current> --page-id <page-id> --reference <target-reference-from-dry-run> [--scope node|subtree] [--display-id <id>] --apply --json
```

`--reference`、`--selector`、`--dom-path` は graph / `node get` が返した locator のうち正確に一つを指定する。`--scope` の既定値は `node` であり、`subtree` は対象配下の未注釈 node も候補にする。`--display-id` は対象rootへ提案する optional な人間可読 `data-og-id` である。

`--apply` を付けない実行は常に dry-run で、HTMLを書き換えずに `schemaVersion`、`applied:false`、`changed`、`dryRun:true`、`path`、`scope`、`targetReference`、`adoptedReferences`、候補 `graph`、`diagnostics` と、変更がある場合の `diff.path/beforeHash/afterHash/unifiedDiff` を返す。入力nodeが既にstableかどうかにかかわらず、`targetReference` は現在のsource range/content hash、document全体のbefore hash、正規化済みscope/display IDを固定したapply専用proposal snapshot referenceへ正規化される。`--apply` はその `targetReference` を `--reference` で渡し、dry-runと同じ `--scope` / `--display-id` を指定する場合だけ受け付ける。通常graphのsession referenceを直接applyへ渡すことはできない。同じ共有Coreでsource range/content hash、document全体hash、proposal parameterを再検証し、いずれかが変わっていればstale proposalとして拒否する。成功時は必要なoptional identityだけを追加し、更新後のstable referenceを返す。返されたstable referenceで再度dry-runしたときに差分がなくなるため、adoptionはidempotentである。

既存の標準 `id` や安全な authored selector で対象を一意に扱える場合はそれをlocator/write selectorとして優先する。semantic valueを確定できないcharacter referenceを含むOpenGraphite identityはstable参照に使わずvalidation errorとし、そのnodeを含むadoptionは既存identityを上書きせず無変更で拒否する。open、load、preview、inspection、validation、build、無編集保存はadoptionを暗黙実行しない。

`node style/attr/icon/text/html/delete/move/copy` など通常のmutation commandは、一意な `data-og-internal-id` またはstable typed `ogref` を要求する。session reference / selector / DOM pathはinspectionと `node adopt` 専用であり、通常mutationへ直接渡さない。

## Screenshot Commands

```bash
ogkiln screenshot canvas <project.ogp|current> --output <png> [--chapter-id <chapter-id>|--collection-id <collection-id>]
ogkiln screenshot page <project.ogp|current> --page-id <page-id>|--component-id <component-id> --output <png> [--width <n>] [--height <n>] [--full-page]
ogkiln screenshot node <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <node-id|ogref-node-id> --output <png> [--width <n>] [--height <n>] [--padding <n>]
```

`screenshot canvas` は `--chapter-id` または `--collection-id` のどちらか一方で対象を選べる。selector は表示 ID、内部 ID、`ogref:chapter` / `ogref:collection` を受け付け、両方の同時指定は invalid である。どちらも省略した場合は先頭 Chapter を使う。対象の `pages[].canvas` / `components[].canvas` 配置に従って各 HTML card を WebKit でレンダリングし、同じ Chapter / Collection の `annotations[]` を App と同じ ink、sticky note の順で重ねてキャンバス全体を 1 枚の PNG に合成する。`inputDevice` は入力元 metadata なので `eraser` の保存 stroke も描画対象である。出力範囲は card frame と annotation frame の union であり、注釈だけの Chapter / Collection も出力できる。cardの座標・寸法が不正な場合、出力が一辺16,384 pxまたは総33,554,432 pixelを超える場合、card snapshot累積が33,554,432 pixelを超える場合はWebKit captureやbitmap確保を行わず、配置範囲または重なったcardを減らすよう明示エラーを返す。

`screenshot page` は指定 page entry の `canvas.width` / `canvas.height` を既定 viewport として PNG を生成する。`--width` / `--height` を指定すると viewport を上書きできる。`--full-page` を付けると document 全体の scroll size に合わせて保存する。

`node-id` は `data-og-internal-id` または `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を指定する。typed node 参照を使う場合、`--page-id` / `--component-id` は省略できる。`screenshot node` は指定 page 内の対象 node を WebKit でレンダリングし、`getBoundingClientRect()` に基づく範囲を切り抜く。`--padding` は切り抜き範囲へ加える余白であり、省略時は `0` である。

## Update Commands

```bash
ogkiln design-token list <project.ogp|current> --json
ogkiln design-token set <project.ogp|current> --name <css-custom-property> --value <css-value>
ogkiln design-token remove <project.ogp|current> --name <css-custom-property>
ogkiln node style set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --var <css-property> --value <css-value>
ogkiln node style remove <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --var <css-property>
ogkiln node attr set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --name <editable-html-attr> --value <value>
ogkiln node attr remove <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --name <editable-html-attr>
ogkiln node text set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --value <text>
ogkiln node text set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --text-file <text-file>
```

`node style set/remove` は `OpenGraphite.contract.json` の編集対象 CSS 宣言だけを扱う。通常は選択 node 自身の selector を書き込み先とするが、wrapper に対する `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image` は node payload の `renderingTargets` と同じ resolver で実際の media / SVG / mask target へ透過 route する。新しい command は設けない。書き込み先は target の標準 `#id`、既存 `data-og-internal-id`、wrapper selector + relative path の順で安全な `writeSelector` を選び、未注釈 target に OpenGraphite ID を自動追加しない。direct inline winnerは既存`style` declarationだけを最小差分更新できるが、新しいinline `style`は作らない。

`node attr set/remove` は `OpenGraphite.contract.json` の `editableAttributes` に含まれる標準HTML属性と保持対象OpenGraphite metadataだけを扱い、`data-og-*`専用ではない。標準`hidden` / `href` / `target` / `aria-label` / `value` / `src` / `alt`は、対象tag/content modelとoperation capabilityが対応するときだけ編集できる。contract外の名前は`disallowed-attribute`、対象不適合は`unsupported-node-capability`でatomic no-writeにする。`set --value ''`はpresent-empty attributeを保存し、tokenを削除するのは明示的な`remove`だけである。既に存在しないtokenのremoveはno-opになる。`data-og-id` / `data-og-internal-id`はこの汎用経路では変更しない。component placement の mock injection は HTML 属性ではなく `.ogp` の `previewContext.placementMocks` に保存するため、`node attr set/remove` では扱わない。runtime は `host.<attribute>` を生成 clone の通常 attribute / ARIA に投影し、`host.class` は authored class へ token を追加する。標準 boolean attribute は false-like value (`0` / `false` / `no` / `off`) で不在、それ以外で present-empty になる。`data-og-*`、`on*`、`id`、`style`、`slot`、`part` は protected で注入されず、project の `:host(...)` CSS が computed state を決める。App Canvas と screenshot はこの state を評価するが、source HTML と static build へは保存しない。

`node style set/remove` はproject CSSをcascade解決には含めるが、`.ogp`の`cssLibrary`を直接変更しない。read-only project / linked / embedded winnerへのsetは、active media scope、`!important`、specificityを満たす安全なnode-scoped overrideをcompanion CSSへ追加する。direct companion / inline winnerは同じdeclarationを更新・削除する。安全なspecificityを構成できないsetは `css-specificity-override-unsafe`、read-only winnerだけのremoveは `read-only-css-winner`、shorthand由来longhandのremoveは `shorthand-css-removal-unsupported`、set後も要求値がcompanion/inline winnerにならない場合は `css-mutation-postcondition-failed` でno-writeになる。CSS libraryを書き換えるのは次項の`design-token set/remove`だけである。

`design-token list/set/remove` は `.ogp` の `cssLibrary` が指す CSS file の `:root` custom property を扱う。token は project-level resource であり、HTML と companion CSS は変更しない。node 側から token を使う場合は `node style set ... --var background --value 'var(--color-accent)'` のように、通常の CSS 値として `var(...)` 参照を保存する。

`node text set` は text として保存する。HTML 断片を入れる操作ではないため、`<`、`>`、`&` は escape する。

`node text set` は CLI の headless source operation であり、App preview の Mock State を暗黙に推測しない。variant context が明示されていない場合、対象は HTML fallback content である。App の Canvas / preview からの直接編集は、現在描画されている resolved text resource を編集対象にし、非 active variant は Inspector から明示的に編集する。

`text variant set` は `data-i18n-key` で text binding を指定し、`--locale eng` の場合は `data-og-text-variant-eng` を保存する。node id を持たない slot 用 text も対象にできる。これは HTML 同梱 fallback / sample 用の互換操作であり、推奨の locale text 正本は `i18n resource set` が更新する locale JSON である。Mock State は保存先ではなく、preview/runtime がどの resource を解決するかを決める入力である。

## Locale Typography Commands

```bash
ogkiln locale-typography list <project.ogp|current> (--page-id <page-id>|--component-id <component-id>) --json
ogkiln locale-typography set <project.ogp|current> (--page-id <page-id>|--component-id <component-id>) [--locale <default|BCP47>] --value <font-family> --json
ogkiln locale-typography remove <project.ogp|current> (--page-id <page-id>|--component-id <component-id>) [--locale <default|BCP47>] --json
```

`--locale` を省略するか `default` を指定すると document / page root selector の標準 `font-family` を扱う。任意の妥当な BCP 47 tag を指定すると、同じ root selector scope の `:lang(<locale>)` rule を扱う。固定 locale allowlist は設けない。`--value` は CSS の font-family value 全体なので、空白や comma を含む場合は shell quote する。

`list` は `schemaVersion`、`path`、`segment`、`resourceID`、`rootSelector`、`declarations`、`diagnostics` を返す。各 declaration は `locale`（`default` を含む）、`selector`、`property`（`font-family`）、`value`、`important`、`atRules`、`sourceOrder` を持つ。App の preview は clone の標準 `lang` / `dir` を一時変更して WebKit computed style を表示するが、CLI は computed value を authored declaration として返したり保存したりしない。

`set` / `remove` は CSS source trace で特定した既存 declaration の value range または declaration だけを更新する。selector、at-rule scope、specificity、source order、`!important`、comment、他 locale rule、element-level override を保持し、安全な書き戻し先がない場合だけ同じ root scope に標準 rule を追加する。edit result は `schemaVersion`、`updated`、`path`、`segment`、`resourceID`、`locale`、`selector`、`property`、`value`、`declarations`、`diagnostics` を返す。旧 `--og-font-family-default`、`--og-font-family-<locale>`、`--og-active-font-family` は明示 migration の入力に限り、この command は生成しない。

## I18n Runtime Commands

```bash
ogkiln i18n inspect <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales ja,eng] --json
ogkiln i18n recommend <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales ja,eng]
ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <data-i18n-key> --value <text>
ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <data-i18n-key> --text-file <text-file>
```

`i18n inspect` は page HTML の `script` / `type="module"` script と辿れる import から `i18n.init({...})` を検出する。検出対象は `lng`、`fallbackLng`、`backend.loadPath` である。`loadPath: "/locales/{{lng}}.json"` のような literal は editable として返し、`loadPath: import.meta.env.VITE_I18N_LOAD_PATH` のような env / dynamic expression は external / readonly として返す。

`i18n recommend` は自動検出できない page に推奨 runtime を挿入し、`public/locales/<locale>.json` を作成・更新する。推奨 loadPath は `/locales/{{lng}}.json`、resource は flat key JSON である。`.ogp` は i18n 設定の正本にならず、preview Mock State と canvas 配置だけを保持する。

`i18n resource set` は検出済み literal loadPath または推奨 loadPath から locale JSON を解決し、flat key の値を書き戻す。external loadPath の場合は OpenGraphite が env / dynamic expression を勝手に書き換えないため readonly error を返す。

## Structure Commands

```bash
ogkiln node html insert <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <anchor-id> --position <before|after|prepend|append> --html <fragment-html>
ogkiln node html insert <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <anchor-id> --position <before|after|prepend|append> --html-file <fragment.html>
ogkiln node html replace <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --html <replacement-html>
ogkiln node html replace <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --html-file <replacement.html>
ogkiln node delete <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id>
ogkiln node move <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <source-id> --target <target-id> --position <before|after|prepend|append>
ogkiln node copy <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <source-id> --target <target-id> --position <before|after|prepend|append> --id-prefix <prefix>
```

`position` の意味:

- `before`: anchor / target node の直前。
- `after`: anchor / target node の直後。
- `prepend`: anchor / target node の最初の子。
- `append`: anchor / target node の最後の子。

`node copy` は複製 subtree 内の全 `data-og-id` に `--id-prefix` を付与する。例えば `--id-prefix copy-` で `card` と `title` を含む subtree を複製すると、`copy-card` と `copy-title` になる。

## JSON Result Contracts

Read operation は `schemaVersion`、対象 path / URL、payload、diagnostics を返す。`annotation list` は対象 segment / container と注釈要約配列、`annotation get` は typed `referenceID` と完全な注釈 payload を返す。write operation は次の形を返す。

```json
{
  "schemaVersion": "0.1",
  "updated": true,
  "path": "/repo/public/index.html",
  "node": {
    "id": "hero",
    "tagName": "herosection",
    "legacyTypeHint": null,
    "capabilities": ["drag-position", "edit-layout", "group", "receive-children", "reorder-flow", "ungroup"]
  },
  "diagnostics": [],
  "insertedNodes": []
}
```

`updated:false` かつ `diagnostics[].severity == "error"` の場合、ファイルは変更されていない。
