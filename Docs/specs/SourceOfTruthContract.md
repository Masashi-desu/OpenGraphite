# OpenGraphite Source-of-Truth Contract

この文書は、[DesignPhilosophy.md](DesignPhilosophy.md) の思想を実現するための技術契約を定義します。対象は HTML だけでも component だけでもありません。`data-og-*`、`--og-*`、CSS、runtime、build、locale resource、`.ogp` metadata など、OpenGraphite が正本として扱う境界を横断して記述します。

## Contract Scope

OpenGraphite の正本は、リポジトリ上の Web 標準ファイルと、それらを解決するための最小限の project metadata です。通常の page DOM は HTML、共通描画は CSS、text resource は locale JSON などの実装資源、component master は Collection 内の source file、canvas 配置や preview mock は `.ogp` metadata が担います。

この契約の目的は、次の境界を曖昧にしないことです。

- 編集可能な構造と session-only 状態の境界。
- デザイン値と描画規則の境界。
- 共有される master と instance 固有 content の境界。
- source file と runtime / build 生成物の境界。
- editor preview 用 mock と公開成果物の境界。

## Responsibility Model

OpenGraphite は、意味、編集情報、デザイン値、描画規則を分離します。

| 領域 | 責務 | 例 |
| --- | --- | --- |
| タグ名 | 意味、コンポーネント名 | `HeroSection`, `MainTitle`, `PrimaryButton` |
| `data-og-*` | エディタが扱う構造、種別、役割 | `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role` |
| CSS 変数 | デザイン値 | `--og-gap`, `--og-padding`, `--og-radius`, `--og-background` |
| `OpenGraphite.css` | アプリ内描画とブラウザ描画を一致させる規則 | `[data-og-layout="vertical"]` |
| `.ogp` | プロジェクト管理、Chapter / Collection、ページ参照、component canvas 参照、キャンバス配置 | `htmlRoot`, `chapters`, `collections`, `canvas` |

class 名はスタイルの正本にしません。class は Web 実装上の補助として将来使う余地を残しますが、OpenGraphite が編集対象として信頼する主な契約は `data-og-*` と `--og-*` です。

## In-App Cache Synchronization Contract

OpenGraphite app は、リポジトリ上の正本ファイルを読み込んで app 内 cache を作り、Canvas、Layers、Inspector、Project 依存性ビュー、preview runtime bridge などの表示経路をその cache へ接続します。app 内操作で値が変わった場合、同じ値を参照する表示経路は、永続化完了やファイル再読込を待たずに cache の現在値へ同期します。

この契約では、永続化は UI 同期の transport ではありません。HTML、CSS、locale resource、`.ogp` などへの保存は、cache 上の編集状態を正本ファイルへ確定する処理です。保存には validation、競合検出、undo / redo 履歴、debounce、外部変更との調停が関わるため、app 内の表示一致を「一度保存してから再読込する」経路に依存させてはいけません。

app 内で編集可能な項目は、種別に関わらずこの規約に従います。たとえば CSS 変数、`data-og-*` 属性、text fallback、resolved text、icon metadata、canvas 配置、preview mock、Project resource 設定は、同じ値が複数 surface に表示されるなら cache 上の単一の現在値を更新し、そこから各 surface へ fan out します。

永続化が未完了、失敗、または外部変更と競合した場合でも、surface ごとに別々の値を持たせません。必要な場合は pending、conflict、error の状態を cache に付随させ、ユーザーへ表示します。永続ファイルが最終的な正本であることと、app session 内の未確定編集を cache で一貫表示することは別の層として扱います。

## Project Metadata Contract

`.ogp` は source files の代替表現ではありません。DOM 構造、本文、主要なデザイン値を `.ogp` に複製しないことを原則とします。

`.ogp` が持つべき情報は次の範囲です。

- リポジトリルートなどのプロジェクト解決情報。
- `public` ルートへの相対参照。
- HTML ページ一覧。
- component master を置く Collection 内 source file 一覧。
- キャンバス上の配置、表示サイズ、ズーム初期値など、エディタ固有の情報。
- editor preview のためだけに注入する Mock State。

公開リポジトリで共有できるように、`.ogp` 内のパスは相対参照を基本とします。ユーザーのディスク上の絶対パスは、実行時に解決される表示情報として扱い、永続化される IR へ固定しません。

## Editable Node Contract

OpenGraphite が編集可能な node は、表示用の `data-og-id` と、内部参照用の `data-og-internal-id` を持ちます。

```html
<HeroSection
  data-og-id="hero"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-role="landing-hero"
  style="
    --og-gap:32px;
    --og-padding:64px;
    --og-radius:24px;
  ">
  <MainTitle data-og-id="title" data-og-type="text">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

この契約では、タグ名は人間が読める意味を持ち、`data-og-*` はエディタが安全に解釈できるメタデータを持ち、CSS 変数はデザイン編集の入出力になります。

## CSS Value Editing Contract

OpenGraphite は、編集可能なデザイン値を `--og-*` CSS 変数として source HTML の inline style に保持します。Inspector は複合値を UI 上で分解して表示しますが、正本としては標準的な CSS 値を保持します。

たとえば `--og-padding:14px 20px` は Inspector では top / right / bottom / left として編集できますが、保存時は `--og-padding` の CSS shorthand へ戻します。`--og-width:min(100%,560px)`、`--og-background:linear-gradient(...)`、`--og-border:1px solid rgba(...)`、`--og-shadow:0 18px 44px rgba(...)` も同様に、Inspector 側で parse / edit / serialize し、HTML には CSS として読める値を残します。

`--og-padding-top`、`--og-border-color`、`--og-shadow-blur` のような個別編集用の分解変数は、現行契約では正本にしません。CSS として特殊すぎる独自表現は避け、一般的な shorthand、長さ、色、`min()` / `max()` / `clamp()`、`linear-gradient()` などを優先して扱います。

Inspector が通常 UI として編集できない CSS 値は、無理に代替入力欄へ落とし込まず編集対象にしません。OpenGraphite はリポジトリの正本 HTML / CSS と同期してプレビューすることを目的にし、OpenGraphite 経由ではない編集や他ライブラリの CSS も許容します。OpenGraphite.css の編集契約に入らない値は、ブラウザ表示ではそのまま反映されますが、編集は別経路で行う前提です。

## `data-og-*` Attribute Contract

`data-og-*` は、source 上に保持される OpenGraphite の編集契約です。意味やコンポーネント名はタグ名へ置き、デザイン値は CSS 変数へ置き、`data-og-*` にはエディタが構造として解釈する情報だけを置きます。

| 属性 | 扱い | 意味 | 現在の主な値 |
| --- | --- | --- | --- |
| `data-og-id` | 必須 | ページ内で一意な表示ノード ID。Layers、Inspector、Canvas 選択などアプリ内の表示に使う。 | `hero`, `title`, `primary-action` |
| `data-og-internal-id` | 必須 | 表示名や役割から独立した内部不変 ID。AI 向け参照IDの node 部分に使う。 | `a4e19c02f6b8` |
| `data-og-type` | 必須 | OpenGraphite が扱うプリミティブ種別。タグ名の意味ではなく、編集・描画の基本カテゴリを表す。 | `page`, `frame`, `text`, `button`, `image`, `icon` |
| `data-og-layout` | 任意 | 子要素の配置方法。主に `page` と `frame` に付与し、`OpenGraphite.css` がレイアウト規則へ変換する。 | `vertical`, `horizontal`, `absolute` |
| `data-og-role` | 任意 | コンポーネントの役割や見た目のバリアント。ID ではなく、CSS ライブラリが解釈する意味上の役割として扱う。 | `page-preview`, `landing-hero`, `primary-button`, `secondary-button`, `card`, `eyebrow`, `muted`, `component-placement` |
| `data-og-component` | 任意 | component master または `<og-instance>` が参照する component ID。 | `site-header`, `feature-card` |
| `data-og-component-kind` | 任意 | Collection 内 component HTML で master subtree を示す印。通常は master root にだけ付ける。 | `master` |
| `data-og-source-component-internal-id` | 任意 | component placement が参照する component canvas の内部 ID。 | `3bgx6phkz3jv5` |
| `data-og-source-node-internal-id` | 任意 | component placement が参照する source node の内部 ID。 | `hrbifdygbcig` |
| `data-og-placement-mode` | 任意 | placement の代表的な状態名。runtime mock 値ではなく、人間とAIが別状態の表示意図を把握するための metadata として扱う。 | `preview`, `code`, `collapsed` |
| `data-og-state-hidden` | 任意 | 親 placement が同名 mode で表示されるときに、この node を hidden 扱いにする状態 token。複数値は空白区切りで保持する。 | `collapsed` |
| `data-og-state-visible` | 任意 | 親 placement が同名 mode で表示されるときに、この node の `data-og-hidden` を preview 上だけ上書きして表示する状態 token。複数値は空白区切りで保持する。 | `collapsed` |
| `data-og-icon-library` | 任意 | icon node が参照するアイコンライブラリ。現行のページ配置 UI は `lucide` を生成する。 | `lucide` |
| `data-og-icon-name` | 任意 | ライブラリ内の icon ID。Lucide では kebab-case 名を保持する。 | `circle`, `arrow-right` |
| `data-og-icon-source` | 任意 | icon をページ側に保持するか外部静的資源として参照するかを示す。現行の自動配置は `inline` SVG を保持する。 | `inline`, `cdn`, `library` |
| `data-og-variant` | 任意 | 同じ component の見た目や意味上のバリアント。 | `compact`, `availability` |
| `data-og-slot` | 任意 | master 内で instance から差し替え可能な slot 名。fallback content は要素内に残す。 | `title`, `body`, `actions` |
| `data-og-part` | 任意 | component 内の安定した part 名。runtime の ID 生成や人間向けの part 説明に使う。 | `root`, `title`, `body` |
| `data-og-text-source` | 任意 | text node の本文が HTML 直書きか外部 binding 由来かを示す。 | `binding` |
| `data-i18n-key` | 任意 | text binding 型 localization で翻訳リソースを参照する key。 | `home.hero.lead` |
| `data-og-text-variant-eng` | 任意 | `data-i18n-key` を持つ binding text の英語 fallback / sample variant。推奨正本は locale JSON。 | `Edit with AI` |
| `data-og-hidden` | 任意 | ノードを非表示にする永続的な編集状態。`true` のとき `OpenGraphite.css` は対象を表示しない。 | `true` |
| `data-og-locked` | 任意 | ノードの編集をロックする永続的な編集状態。`true` のとき選択表示と編集操作がロック状態として扱われる。 | `true` |
| `data-og-selected` | 一時 | Canvas 上の現在選択を示す実行時属性。保存前の HTML シリアライズで除去する。 | `true` |
| `data-og-editing` | 一時 | テキスト編集中のノードを示す実行時属性。`contenteditable` と同様に保存前の HTML シリアライズで除去する。 | `true` |
| `data-og-runtime-fallback-html` | 一時 | 実装 runtime が解決済み text を DOM へ反映する前の fallback HTML を保持するための属性。保存前に除去する。 | `日本語タイトル` |

永続化される `data-og-*` は、ブラウザ単独表示時にも意味が説明できる必要があります。一時属性は OpenGraphite の session 状態であり、正本 HTML へ残してはいけません。

### `data-og-id`

`data-og-id` は、OpenGraphite が HTML ノードを UI 上で扱うための表示 ID です。同じ HTML ページ内では一意である必要があります。

Layers の行、Inspector の表示、Canvas の選択は `data-og-id` を使います。Agent / CLI / MCP の対象解決と、コピーされる agent 向け参照IDは `data-og-internal-id` を使います。タグ名や DOM の位置はユーザーの編集で変わり得るため、編集対象の同一性として扱いません。

### `data-og-internal-id`

`data-og-internal-id` は、表示名や意味から切り離された内部不変 ID です。OpenGraphite は読み込み時に未設定または重複しているノードへ不透明 ID を補完し、正本 HTML に保存します。コピーされる agent 向け参照IDはこの値を使うため、`data-og-id` を表示・説明用に変更しても内部参照は追従できます。

### `data-og-type`

`data-og-type` は、ノードを OpenGraphite の編集プリミティブへ分類します。意味やコンポーネント名はタグ名が担い、`data-og-type` は editor/runtime が扱うカテゴリだけを表します。

- `page`: HTML ページのルートに近いプレビュー単位。
- `frame`: 子要素を持つコンテナ。
- `text`: テキスト編集の対象。
- `button`: ボタンまたはリンク型の操作要素。
- `image`: 画像、動画、プレビューなどのメディア枠。
- `icon`: Lucide などのアイコンを配置する軽量な図形ノード。

`OpenGraphite.css` は `data-og-type` ごとに基本 display、サイズ、余白、文字、画像の扱いを定義します。

### Icon Source Contract

`data-og-type="icon"` は、UI icon や装飾 icon を HTML 正本へ配置するためのプリミティブです。OpenGraphite は icon の意味をタグ名ではなく `data-og-icon-*` metadata と子要素の SVG / mask / image で表します。

初期対応ライブラリは Lucide です。Canvas の icon ツールは次のような inline SVG を生成し、ページ HTML 側にそのまま保持します。

```html
<Icon
  data-og-id="icon"
  data-og-type="icon"
  data-og-icon-library="lucide"
  data-og-icon-name="circle"
  data-og-icon-source="inline"
  style="--og-width:24px; --og-height:24px;">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
    <circle cx="12" cy="12" r="10"></circle>
  </svg>
</Icon>
```

`data-og-icon-source="inline"` は、配布 HTML が CDN や JavaScript runtime なしで icon を描画できる形です。`cdn` は `lucide-static` の SVG URL を CSS mask として保持し、`library` は実装側 icon loader など、静的に解決できる外部資源を使うための metadata として予約します。どの方式でも `data-og-icon-library` と `data-og-icon-name` は人間とAIが icon の出自を追跡するために残します。

Icon のサイズは既存の `--og-width` / `--og-height`、色は `--og-foreground`、Lucide 系の線幅は `--og-stroke-width` を使います。CDN source の mask 子要素は非編集の `--og-icon-url` に SVG URL を保持し、親 icon node の `--og-foreground` を `currentColor` として描画します。

### `data-og-layout`

`data-og-layout` は、子要素の並べ方を示します。現在の契約では次の値を扱います。

- `vertical`: 子要素を縦方向に並べる。
- `horizontal`: 子要素を横方向に並べる。
- `absolute`: 子要素を `--og-x` と `--og-y` で配置する。

`data-og-layout` は主に `page` と `frame` に付与します。layout を持つノードでは、`--og-gap`、`--og-align`、`--og-justify`、`--og-padding` などの CSS 変数が配置のデザイン値になります。

### `data-og-role`

`data-og-role` は、同じ `data-og-type` の中で役割や見た目のバリアントを示します。たとえば `data-og-type="button"` に `data-og-role="primary-button"` を付けることで、意味はボタンのまま主要ボタンとして描画できます。

`data-og-role` は一意 ID ではありません。複数ノードが同じ role を共有できます。現在の `OpenGraphite.css` は単一の role 文字列を前提にしています。

## Reference And Slot Contract

component master は Collection 内の source file に通常の OpenGraphite node として置き、root に `data-og-component` と `data-og-component-kind="master"` を付けます。Pages 側は `<og-instance data-og-component="...">` で参照し、子要素の標準 `slot` 属性で master 内の `data-og-slot` に内容を渡します。

```html
<FeatureCard
  data-og-id="feature-card-master"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-component="feature-card"
  data-og-component-kind="master"
  data-og-part="root">
  <FeatureCardTitle data-og-id="feature-card-title" data-og-type="text" data-og-slot="title">
    Fallback title
  </FeatureCardTitle>
</FeatureCard>

<og-instance data-og-id="availability-card" data-og-type="frame" data-og-component="feature-card">
  <span slot="title">Availability-ready card</span>
</og-instance>
```

`data-og-slot` は `text` に限りません。`frame` を含む、`data-og-slot` を持つ master node は instance 側の同名 `slot` content で置換できます。instance が固有に持つのは slot content であり、slot target node 自体の `data-og-layout`、`data-og-role`、`--og-*` などは master 由来です。slot target node の構造や style を instance ごとに分岐させたい場合は、root の instance style override、別 variant、別 master、または slot 内に置く子構造で表現します。

instance 側の slot content は、軽い text の場合は `<span slot="title">...</span>` のように直接渡せます。複数 node や OpenGraphite node を渡す場合は、標準 `template` を使って source content を保持します。

```html
<og-instance data-og-id="code-viewer-a" data-og-type="frame" data-og-component="code-viewer">
  <template slot="preview">
    <PreviewCard data-og-id="preview-card" data-og-type="frame">
      <PreviewText data-og-id="preview-text" data-og-type="text">
        Instance specific preview
      </PreviewText>
    </PreviewCard>
  </template>
</og-instance>
```

`data-og-part="root"` は、runtime 展開時に instance の `data-og-id` を master root へ対応させるための安定した目印です。その他の part 名は、component 内部の意味ある部品を人間とAIが説明しやすくするために使えます。

## Placement Contract

component placement は、Collection 内の component canvas にある既存 component node を、同じ component canvas 上へ別状態で並べるための永続 HTML node です。Chapter / Pages には配置できず、公開 page の構造ではなく編集用の表示です。`.ogp` の page / component card ではなく、通常の OpenGraphite node と同じ DOM 階層に置きます。表示用に生成された clone は直接編集対象にしません。

placement host は `data-og-role="component-placement"` を持つ `frame` として表します。`data-og-source-component-internal-id` は参照元 component canvas、`data-og-source-node-internal-id` は参照元 node を指します。現在の実装では、参照元 component は placement が置かれている component canvas と一致し、参照元 node は同じ component HTML 内に存在する必要があります。placement host は Layers 上で開閉できる参照表示として扱い、内部に表示される clone node は選択できますが実体を持ちません。clone node への Inspector / Canvas 編集は同じ `data-og-internal-id` を持つ参照元 component node に保存され、全 placement に同期されます。placement 側に明示した `--og-*` は、その placement だけの表示枠 override として扱います。

`data-og-placement-mode` は、placement host が表示したい代表状態を source HTML 上で説明する metadata です。clone 内の node は `data-og-state-hidden` / `data-og-state-visible` に空白区切りの mode token を持てます。たとえば `collapsed` mode の placement では、`data-og-state-hidden="collapsed"` を持つ node は非表示になり、通常は `data-og-hidden="true"` の `data-og-state-visible="collapsed"` node は preview 上だけ表示されます。これは editor preview と `ogkiln screenshot` が同じ HTML / CSS 契約から別状態を再現するための永続 metadata であり、公開 page runtime の一時状態ではありません。

```html
<og-placement
  data-og-id="code-viewer-preview-placement"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-role="component-placement"
  data-og-source-component-internal-id="3bgx6phkz3jv5"
  data-og-source-node-internal-id="hrbifdygbcig"
  data-og-placement-mode="preview">
</og-placement>
```

placement に `--og-width` / `--og-height` などの明示 override がない場合、表示フレームは参照先 component node の標準サイズ、CSS 変数、内容の自然な bounds に従います。placement に同名 CSS 変数を明示した場合は、`<og-instance>` の `style` override と同じく、その placement だけが参照先 root の標準サイズを上書きします。component master の `--og-width` は標準サイズであり、instance または placement 側の `--og-width` は個別配置の override です。

placement 単位の mock injection は HTML ではなく、`.ogp` の canvas `previewContext.placementMocks` へ保存します。HTML は component / placement が持つ構造、参照、標準サイズ、個別デザイン override を正本として持ち、`.ogp` は preview のためだけに注入する runtime parameter を持ちます。`placementMocks` の key は placement host の `data-og-internal-id` を推奨し、互換的に `data-og-id` でも解決できます。

```json
{
  "previewContext": {
    "fieldMocks": {
      "selectedLanguage": "ja"
    },
    "placementMocks": {
      "67a2e12dbed8": {
        "codeViewerMode": "preview"
      }
    }
  }
}
```

`previewContext.fieldMocks` は canvas 全体へ注入する mock state です。`previewContext.placementMocks` は指定 placement の clone を表示するときだけ追加で注入する mock state で、同じ component canvas 内に code / preview / loading など複数状態を並べるために使います。placement mock はコンポーネントの性質ではなく、表示確認のための注入値なので HTML へ保存しません。

## Text Binding Contract

`data-og-text-source="binding"` は、text node の表示テキストが HTML 本文だけでなく locale resource や runtime state から差し替えられることを示します。`data-i18n-key` はその翻訳単位を識別する標準的な key です。fallback content は HTML 内に残し、JavaScript や build 処理が使えない場合にもページ単体で読める状態を保ちます。

locale text の推奨正本は実装側の resource、標準構成では `public/locales/<locale>.json` の flat key JSON です。HTML に同梱する `data-og-text-variant-<locale>` は lightweight fallback / sample として残せますが、OpenGraphite runtime がこの属性を正本として解決することはありません。実装 runtime が表示のために作る一時 DOM 変更や `data-og-runtime-fallback-html` は保存HTMLへ残しません。

### I18n Runtime Resources

i18n 設定の正本は `.ogp` ではなく実装ファイルです。OpenGraphite は page HTML の `script` / `type="module"` script から辿れる範囲で `i18n.init({...})` を検出し、`lng`、`fallbackLng`、`backend.loadPath` を表示します。`backend.loadPath: "/locales/{{lng}}.json"` のような literal は editable resource path として扱い、`import.meta.env.VITE_I18N_LOAD_PATH` や関数式などの dynamic expression は external / read only として扱います。

OpenGraphite preview は `selectedLanguage=eng` などの Mock State を注入するだけです。実際の text 解決、locale JSON の読み込み、DOM 反映は HTML 側の実装 runtime が担当します。推奨 runtime を作成する導線は `public/i18n.js` と `/locales/{{lng}}.json` を生成できますが、生成後も正本はそれらの実装資源です。

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

`data-og-hidden="true"` は、ノードを非表示にする永続状態です。`OpenGraphite.css` は対象を `display: none` として扱います。

`data-og-locked="true"` は、ノードを編集ロック状態として扱う永続状態です。ロックされたノードは通常の編集操作を拒否し、選択表示はロック状態として区別します。

## Runtime-Only Attribute Contract

`data-og-selected` と `data-og-editing` は、OpenGraphite が app 内で状態表示するためだけに付与する一時属性です。

- `data-og-selected="true"`: 現在選択中のノードを Canvas 上でハイライトする。
- `data-og-editing="true"`: テキスト編集セッション中のノードを示す。

component runtime は `<og-instance>` を表示時に展開するため、次の一時属性を付与できます。

- `data-og-expanded`: `<og-instance>` が展開済みであることを示す。
- `data-og-generated`: master から生成された DOM であることを示す。
- `data-og-component-error`: master が見つからないなど、runtime 展開に失敗した理由を示す。
- `data-og-host-id`: 展開元 instance の安定 ID。
- `data-og-instance-source`: instance 側の slot source を一時的に退避した template。
- `data-og-source-component`: 生成 DOM の元 component ID。
- `data-og-source-instance`: 生成 DOM の元 instance ID。
- `data-og-source-placement`: 生成 DOM の元 component placement ID。
- `data-og-slot-origin`: 生成 DOM が対応する master slot 名。
- `data-og-preview-clone`: component placement の表示 clone であることを示す。
- `data-og-placement-generated`: component placement から生成された DOM であることを示す。
- `data-og-preview-locale`: editor preview が HTML document metadata と Mock State から解決した一時的な `lang` 相当値。正本 HTML へ残さない。
- `data-og-preview-dir`: editor preview が HTML document metadata と Mock State から解決した一時的な `dir` 相当値。正本 HTML へ残さない。
- `contenteditable` / `spellcheck`: テキスト編集セッション中のブラウザ属性。

これらはユーザーが配布する HTML の意味ではありません。HTML を保存する前に必ず取り除き、正本 HTML には残さないことを契約とします。

## Rendering Contract

`OpenGraphite.css` は app 内の `WKWebView` と通常ブラウザの両方で同じ見た目を作るための共有ライブラリです。

描画規則は class ではなく `data-og-*` と CSS 変数を中心に記述します。

```css
[data-og-layout="vertical"] {
  display: flex;
  flex-direction: column;
  gap: var(--og-gap, 0);
}
```

アプリは HTML を特殊なキャンバス形式へ変換してから描画しません。WebKit が HTML を描画し、OpenGraphite は選択、レイヤー抽出、インスペクタ編集、保存を担当します。

## Editor Behavior Contract

OpenGraphite のエディタは、HTML の上に編集体験を重ねる薄いレイヤーです。

- `WKWebView` で対象 HTML を直接表示する。
- `[data-og-id]` を持つノードを Layers に反映する。
- 選択状態をキャンバス、Layers、Inspector で同期する。
- app 内編集を cache の現在値へ反映し、同じ値を表示する複数 surface へ永続化前に同期する。
- Inspector の編集を DOM と source file へ反映する。
- HTML 内の自然なスクロールやブラウザ挙動をできるだけ尊重する。

OpenGraphite 独自の機能を追加する場合も、最終的に HTML と CSS に説明可能な形で落ちることを優先します。
