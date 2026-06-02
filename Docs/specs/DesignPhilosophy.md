# OpenGraphite Design Philosophy

OpenGraphite は、HTML をエクスポート成果物ではなく編集可能な正本として扱うデザインアプリです。デザインツール内の独自 IR を最終成果物へ変換するのではなく、Web で配布される HTML そのものを開き、読み取り、編集し、保存します。

## Core Principle

Web 標準の source files が正本です。通常の page DOM は HTML が正本であり、component master は Components セグメント内の HTML、共通描画は CSS、参照展開は必要に応じて `OpenGraphite.runtime.js` または `ogkiln build` が担います。

`OpenGraphite.app` が表示している source HTML と、ブラウザで表示する HTML/CSS/JS は同じリポジトリ内の Web 標準ファイルです。編集結果は独自デザイン IR へ複製せず、開いている `public/*.html`、Components HTML、CSS へ直接反映されます。

component 参照を使う場合、Pages の source HTML は `<og-instance>` を保持できます。小規模なプロジェクトは `OpenGraphite.runtime.js` で表示時に展開し、性能や SEO を重視する場合は `ogkiln build` で `dist` 相当の静的 HTML を生成できます。これは `.fig` や `.pen` のような別正本を作るものではなく、Web 標準 source files から決定的に生成される配布形態です。

この方針により、OpenGraphite の成果物はアプリに閉じません。HTML、CSS、画像などの Web 標準ファイルがそのまま成果物になり、リポジトリ上でレビュー、配布、ホスティングできます。

## Repository-Synchronized Interface

OpenGraphite は、リポジトリに置かれた HTML、CSS、画像、プロジェクトメタデータを正本として読み取り、その内容をアプリ内の表示と編集状態へ完全に同期します。Canvas、Layers、Inspector は独自のコピーではなく、リポジトリ上のファイル構造と DOM / CSS の現在値を反映するインターフェースです。

この同期モデルにより、ユーザーと AI は同じリポジトリ内容を見ながら協業できます。AI がコードやドキュメントとして変更した内容は OpenGraphite 上の表示に反映され、OpenGraphite で行った編集はリポジトリの正本ファイルへ戻ります。OpenGraphite は、デザインツール、コードエディタ、AI エージェントが同じ成果物を扱うための新しいインターフェース体験を提供します。

## Responsibility Model

OpenGraphite は、意味、編集情報、デザイン値、描画規則を分離します。

| 領域 | 責務 | 例 |
| --- | --- | --- |
| タグ名 | 意味、コンポーネント名 | `HeroSection`, `MainTitle`, `PrimaryButton` |
| `data-og-*` | エディタが扱う構造、種別、役割 | `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role` |
| CSS 変数 | デザイン値 | `--og-gap`, `--og-padding`, `--og-radius`, `--og-background` |
| `OpenGraphite.css` | アプリ内描画とブラウザ描画を一致させる規則 | `[data-og-layout="vertical"]` |
| `.ogp` | プロジェクト管理、ページ参照、component canvas 参照、キャンバス配置 | `htmlRoot`, `pages`, `components`, `canvas` |

class 名はスタイルの正本にしません。class は Web 実装上の補助として将来使う余地を残しますが、OpenGraphite が編集対象として信頼する主な契約は `data-og-*` と `--og-*` です。

## `.ogp` Is Project Metadata

`.ogp` は HTML の代替表現ではありません。DOM 構造、本文、主要なデザイン値を `.ogp` に複製しないことを原則とします。

`.ogp` が持つべき情報は次の範囲です。

- リポジトリルートなどのプロジェクト解決情報
- `public` ルートへの相対参照
- HTML ページ一覧
- component master を置く Components セグメントの HTML 一覧
- キャンバス上の配置、表示サイズ、ズーム初期値など、エディタ固有の情報

公開リポジトリで共有できるように、`.ogp` 内のパスは相対参照を基本とします。ユーザーのディスク上の絶対パスは、実行時に解決される表示情報として扱い、永続化される IR へ固定しません。

## HTML Contract

OpenGraphite が編集可能な HTML ノードは、表示用の `data-og-id` と、内部参照用の `data-og-internal-id` を持ちます。

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

### CSS Value Editing Contract

OpenGraphite は、編集可能なデザイン値を `--og-*` CSS 変数として HTML の inline style に保持します。Inspector は複合値を UI 上で分解して表示しますが、HTML の正本としては標準的な CSS 値を保持します。

たとえば `--og-padding:14px 20px` は Inspector では top / right / bottom / left として編集できますが、保存時は `--og-padding` の CSS shorthand へ戻します。`--og-width:min(100%,560px)`、`--og-background:linear-gradient(...)`、`--og-border:1px solid rgba(...)`、`--og-shadow:0 18px 44px rgba(...)` も同様に、Inspector 側で parse / edit / serialize し、HTML には CSS として読める値を残します。

`--og-padding-top`、`--og-border-color`、`--og-shadow-blur` のような個別編集用の分解変数は、現行契約では正本にしません。CSS として特殊すぎる独自表現は避け、一般的な shorthand、長さ、色、`min()` / `max()` / `clamp()`、`linear-gradient()` などを優先して扱います。

Inspector が通常 UI として編集できない CSS 値は、無理に代替入力欄へ落とし込まず編集対象にしません。OpenGraphite はリポジトリの正本 HTML / CSS と同期してプレビューすることを目的にし、OpenGraphite 経由ではない編集や他ライブラリの CSS も許容します。OpenGraphite.css の編集契約に入らない値は、ブラウザ表示ではそのまま反映されますが、編集は別経路で行う前提です。

### `data-og-*` Attribute Contract

`data-og-*` は、HTML 上に保持される OpenGraphite の編集契約です。意味やコンポーネント名はタグ名へ置き、デザイン値は CSS 変数へ置き、`data-og-*` にはエディタが構造として解釈する情報だけを置きます。

| 属性 | 扱い | 意味 | 現在の主な値 |
| --- | --- | --- | --- |
| `data-og-id` | 必須 | ページ内で一意な表示ノード ID。Layers、Inspector、Canvas 選択などアプリ内の表示に使う。 | `hero`, `title`, `primary-action` |
| `data-og-internal-id` | 必須 | 表示名や役割から独立した内部不変 ID。AI 向け参照IDの node 部分に使う。 | `a4e19c02f6b8` |
| `data-og-type` | 必須 | OpenGraphite が扱うプリミティブ種別。タグ名の意味ではなく、編集・描画の基本カテゴリを表す。 | `page`, `frame`, `text`, `button`, `image` |
| `data-og-layout` | 任意 | 子要素の配置方法。主に `page` と `frame` に付与し、`OpenGraphite.css` がレイアウト規則へ変換する。 | `vertical`, `horizontal`, `absolute` |
| `data-og-role` | 任意 | コンポーネントの役割や見た目のバリアント。ID ではなく、CSS ライブラリが解釈する意味上の役割として扱う。 | `page-preview`, `landing-hero`, `primary-button`, `secondary-button`, `card`, `eyebrow`, `muted` |
| `data-og-component` | 任意 | component master または `<og-instance>` が参照する component ID。 | `site-header`, `feature-card` |
| `data-og-component-kind` | 任意 | Components セグメント内で master subtree を示す印。通常は master root にだけ付ける。 | `master` |
| `data-og-variant` | 任意 | 同じ component の見た目や意味上のバリアント。 | `compact`, `availability` |
| `data-og-slot` | 任意 | master 内で instance から差し替え可能な slot 名。fallback content は要素内に残す。 | `title`, `body`, `actions` |
| `data-og-part` | 任意 | component 内の安定した part 名。runtime の ID 生成や人間向けの part 説明に使う。 | `root`, `title`, `body` |
| `data-og-hidden` | 任意 | ノードを非表示にする永続的な編集状態。`true` のとき `OpenGraphite.css` は対象を表示しない。 | `true` |
| `data-og-locked` | 任意 | ノードの編集をロックする永続的な編集状態。`true` のとき選択表示と編集操作がロック状態として扱われる。 | `true` |
| `data-og-selected` | 一時 | Canvas 上の現在選択を示す実行時属性。保存前の HTML シリアライズで除去する。 | `true` |
| `data-og-editing` | 一時 | テキスト編集中のノードを示す実行時属性。`contenteditable` と同様に保存前の HTML シリアライズで除去する。 | `true` |

永続化される `data-og-*` は、ブラウザ単独表示時にも意味が説明できる必要があります。一時属性は OpenGraphite のセッション状態であり、正本 HTML へ残してはいけません。

#### `data-og-id`

`data-og-id` は、OpenGraphite が HTML ノードを UI 上で扱うための表示 ID です。同じ HTML ページ内では一意である必要があります。

Layers の行、Inspector の表示、Canvas の選択は `data-og-id` を使います。Agent / CLI / MCP の対象解決と、コピーされる agent 向け参照IDは `data-og-internal-id` を使います。タグ名や DOM の位置はユーザーの編集で変わり得るため、編集対象の同一性として扱いません。

#### `data-og-internal-id`

`data-og-internal-id` は、表示名や意味から切り離された内部不変 ID です。OpenGraphite は読み込み時に未設定または重複しているノードへ不透明 ID を補完し、正本 HTML に保存します。コピーされる agent 向け参照IDはこの値を使うため、`data-og-id` を表示・説明用に変更しても内部参照は追従できます。

#### `data-og-type`

`data-og-type` は、ノードを OpenGraphite の編集プリミティブへ分類します。意味やコンポーネント名はタグ名が担い、`data-og-type` は editor/runtime が扱うカテゴリだけを表します。

- `page`: HTML ページのルートに近いプレビュー単位。
- `frame`: 子要素を持つコンテナ。
- `text`: テキスト編集の対象。
- `button`: ボタンまたはリンク型の操作要素。
- `image`: 画像、動画、プレビューなどのメディア枠。

`OpenGraphite.css` は `data-og-type` ごとに基本 display、サイズ、余白、文字、画像の扱いを定義します。

#### `data-og-layout`

`data-og-layout` は、子要素の並べ方を示します。現在の契約では次の値を扱います。

- `vertical`: 子要素を縦方向に並べる。
- `horizontal`: 子要素を横方向に並べる。
- `absolute`: 子要素を `--og-x` と `--og-y` で配置する。

`data-og-layout` は主に `page` と `frame` に付与します。layout を持つノードでは、`--og-gap`、`--og-align`、`--og-justify`、`--og-padding` などの CSS 変数が配置のデザイン値になります。

#### `data-og-role`

`data-og-role` は、同じ `data-og-type` の中で役割や見た目のバリアントを示します。たとえば `data-og-type="button"` に `data-og-role="primary-button"` を付けることで、意味はボタンのまま主要ボタンとして描画できます。

`data-og-role` は一意 ID ではありません。複数ノードが同じ role を共有できます。現在の `OpenGraphite.css` は単一の role 文字列を前提にしています。

#### Component Reference Attributes

component master は Components セグメント内の HTML に通常の OpenGraphite node として置き、root に `data-og-component` と `data-og-component-kind="master"` を付けます。Pages 側は `<og-instance data-og-component="...">` で参照し、子要素の標準 `slot` 属性で master 内の `data-og-slot` に内容を渡します。

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

`data-og-part="root"` は、runtime 展開時に instance の `data-og-id` を master root へ対応させるための安定した目印です。その他の part 名は、component 内部の意味ある部品を人間とAIが説明しやすくするために使えます。

#### `data-og-hidden` and `data-og-locked`

`data-og-hidden="true"` は、ノードを非表示にする永続状態です。`OpenGraphite.css` は対象を `display: none` として扱います。

`data-og-locked="true"` は、ノードを編集ロック状態として扱う永続状態です。ロックされたノードは通常の編集操作を拒否し、選択表示はロック状態として区別します。

#### Runtime-only Attributes

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
- `data-og-slot-origin`: 生成 DOM が対応する master slot 名。
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

## Editor Behavior

OpenGraphite のエディタは、HTML の上に編集体験を重ねる薄いレイヤーです。

- `WKWebView` で対象 HTML を直接表示する
- `[data-og-id]` を持つノードを Layers に反映する
- 選択状態をキャンバス、Layers、Inspector で同期する
- Inspector の編集を DOM と HTML ファイルへ反映する
- HTML 内の自然なスクロールやブラウザ挙動をできるだけ尊重する

OpenGraphite 独自の機能を追加する場合も、最終的に HTML と CSS に説明可能な形で落ちることを優先します。

## Design Constraints

- HTML はブラウザで単独表示できること。
- `OpenGraphite.app` がなくても成果物を確認できること。
- `.xcodeproj` は生成物であり、`project.yml` を XcodeGen の正本とすること。
- 生成物、ユーザー固有の絶対パス、秘密情報を正本ファイルへ混ぜないこと。
- 独自 IR の肥大化で HTML 正本モデルを曖昧にしないこと。
- app 内描画とブラウザ描画の差分は `OpenGraphite.css` 側で説明できるようにすること。

## Decision Heuristics

実装判断で迷った場合は、次の順で優先します。

1. 編集後の HTML が、そのまま Web 成果物として読めるか。
2. デザイン値が CSS 変数として明示されているか。
3. エディタ用メタデータが `data-og-*` として HTML 上に保持されているか。
4. `.ogp` が HTML の複製ではなく、プロジェクト管理情報に留まっているか。
5. 公開リポジトリへ置いてもユーザー固有情報を含まないか。

この優先順位に反する機能は、短期的に便利でも OpenGraphite の設計思想から外れるものとして扱います。
