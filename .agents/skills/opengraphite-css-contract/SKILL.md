---
name: opengraphite-css-contract
description: "OpenGraphite.css、data-og-* 属性、--og-* CSS 変数、layout、role、component、再利用可能なデザイン断片を使う HTML の作成、レビュー、デバッグ、変換を支援するときに使う。OpenGraphite HTML/CSS 契約、属性、変数、role、layout、component runtime の説明や検証観点が必要なときに使う。"
---

# OpenGraphite CSS 契約

一般ユーザーが `OpenGraphite.css` で描画される HTML を書く、修正する、または OpenGraphite HTML/CSS 契約を確認するときに、この skill を使う。

## 対象

これは `OpenGraphite.css` を HTML document で利用する人のための契約説明である。ユーザーが standalone HTML / CSS を authoring しているものとして扱う。

OpenGraphite リポジトリ内の `public/` page や component HTML を編集する作業手順は、`opengraphite-page-editing` skill の責務である。ページ編集中に `data-og-*`、`--og-*`、role、layout、component の契約確認が必要な場合だけ、この skill も併用する。

ユーザーが独自の `OpenGraphite.css` や特定バージョンを提示した場合は、そのファイルを確認し、実際のルールを優先する。stylesheet が提示されない場合は、下記の公開契約を使う。

リポジトリに `OpenGraphite.contract.json` がある場合は、既知の `data-og-*` 値、role、layout、`--og-*` 変数の機械可読な正本として扱う。説明には本文の契約を使ってよいが、検証向けの判断では JSON を優先する。

通常は、属性、変数、例から CSS 契約を直接説明する。利用質問に答えるためだけに、実装ファイルやビルドツールを必須にしない。

## コアモデル

OpenGraphite document は通常の HTML である。`OpenGraphite.css` は次を読み取って要素を描画する。

- 作者が選ぶ semantic tag name。
- OpenGraphite の構造と variant を示す `data-og-*` 属性。
- design value を示す inline の `--og-*` CSS 変数。
- project の `components` segment にある optional な component master HTML と、pages 内の `<og-instance>` 参照。
- length、color、shorthand、gradient、`min()`、`max()`、`clamp()` などの標準 CSS 値。

class 名は周辺の Web サイト実装で使ってよいが、OpenGraphite の編集契約にしない。OpenGraphite-aware tool が理解できる必要がある内容には、`data-og-*` と `--og-*` を優先する。

## 基本セットアップ

stylesheet を読み込み、編集・描画対象の要素に `data-og-type` を付ける。

```html
<link rel="stylesheet" href="OpenGraphite.css">

<main
  data-og-id="page"
  data-og-type="page"
  data-og-layout="vertical"
  data-og-role="page-preview"
  style="--og-gap:32px; --og-padding:48px;">
  <HeroTitle
    data-og-id="title"
    data-og-type="text"
    style="--og-font-size:56px; --og-font-weight:760; --og-line-height:1;">
    OpenGraphite
  </HeroTitle>
</main>
```

component 参照では、master を component canvas HTML に置き、page 側から component source link と optional runtime で参照する。

```html
<link rel="stylesheet" href="OpenGraphite.css">
<link rel="opengraphite-components" href="_components/design-system.html">
<script src="OpenGraphite.runtime.js" defer></script>
```

## 属性

- `data-og-id`: 安定した element identifier。tool や人が特定 node を参照する必要がある場合は一意にする。
- `data-og-type`: primitive rendering type。既知の値は `page`、`frame`、`text`、`button`、`image`。
- `data-og-layout`: 子要素の layout mode。既知の値は `vertical`、`horizontal`、`absolute`。
- `data-og-role`: 再利用可能な visual / semantic variant。既知の role には `page-preview`、`landing-hero`、`primary-button`、`secondary-button`、`card`、`eyebrow`、`muted` がある。
- `data-og-component`: master root または `<og-instance>` が使う component identifier。
- `data-og-component-kind="master"`: Components segment 内の component master subtree を示す。
- `data-og-variant`: optional な component / role variant。
- `data-og-slot`: component master 内の slot target。要素の既存 contents は fallback content になる。
- `data-og-part`: component 内の安定した part name。runtime ID mapping で instance ID を保持したい場合は master root に `root` を使う。
- `data-og-hidden="true"`: 要素を非表示にする。
- `data-og-locked="true"`: 要素を locked として扱い、cursor を変える。
- `data-og-selected="true"` と `data-og-editing="true"` は UI/session state。runtime expansion は `data-og-expanded`、`data-og-generated`、`data-og-component-error`、`data-og-host-id`、`data-og-instance-source`、`data-og-source-component`、`data-og-source-instance`、`data-og-slot-origin` も追加できる。runtime output を明示的に debug している場合を除き、hand-authored source HTML には runtime 属性を含めない。

## 型

- `page` と `frame`: relative positioning を持つ block container。
- `text`: `--og-font-size`、`--og-font-weight`、`--og-line-height`、`--og-letter-spacing`、`--og-text-align` を持つ block text。
- `button`: centered content、default gap、padding、radius、pointer cursor を持つ inline-flex action element。
- `image`: overflow hidden の media frame。直接の `img` / `video` child は frame を埋め、`--og-object-fit` を使う。

## レイアウト

- `vertical`: `display:flex`、column direction、`--og-align` default `stretch`、`--og-justify` default `flex-start`、`--og-gap` default `0`。
- `horizontal`: `display:flex`、row direction、`--og-align` default `center`、`--og-justify` default `flex-start`、`--og-gap` default `0`。
- `absolute`: parent が positioned block になり、直接の `data-og-type` child は `--og-x` と `--og-y` で absolutely positioned になる。

inline の `--og-x` または `--og-y` を持つ要素には、`OpenGraphite.css` が relative positioning と `left` / `top` offset も付ける。

画面幅 760px 以下では、horizontal layout は vertical に積まれ、button は full width になり、`page-preview` は `--og-padding:24px` を使う。

## CSS 変数

global theme variable は通常 `:root` に置く。

- `--og-page-background`
- `--og-text-color`
- `--og-muted-color`
- `--og-accent`
- `--og-accent-foreground`

box / layout の共通 variable:

- `--og-width`, `--og-height`
- `--og-min-width`, `--og-min-height`, `--og-max-width`
- `--og-flex`
- `--og-margin`, `--og-padding`
- `--og-gap`, `--og-align`, `--og-justify`
- `--og-x`, `--og-y`

appearance variable:

- `--og-foreground`
- `--og-background`
- `--og-border`
- `--og-radius`
- `--og-shadow`

text variable:

- `--og-font-size`
- `--og-font-weight`
- `--og-line-height`
- `--og-letter-spacing`
- `--og-text-align`

media / transform variable:

- `--og-object-fit`
- `--og-scale-x`, `--og-scale-y`
- `--og-transform-origin`

editing helper variable:

- `--og-edit-width`
- `--og-edit-min-height`

## ロール

- `page-preview`: theme fallback と `--og-background` / `--og-foreground` を使い、page-like な full viewport preview を作る。
- `landing-hero`: hero composition 用に overflow を clip する。
- `primary-button`: accent color default と colored shadow を使う。
- `secondary-button`: light background と subtle border default を使う。
- `card`: light background、subtle border、default shadow を使う。
- `eyebrow`: accent color の uppercase small text。
- `muted`: muted theme color を使う。

role は再利用可能な variant であり、一意な identifier ではない。複数要素が同じ role を共有してよい。

## オーサリングルール

- design value は標準 CSS string として `--og-*` variable に保持する。
- `--og-padding:14px 20px`、`--og-border:1px solid rgba(...)`、`--og-shadow:0 18px 44px rgba(...)` のような shorthand value を優先する。
- 有用な場合は `--og-width:min(100%,560px)` や `--og-background:linear-gradient(...)` のように CSS function を直接使う。
- ユーザーの stylesheet が明示的に対応している場合を除き、`--og-padding-top`、`--og-border-color`、`--og-shadow-blur` のような独自の分解 variable を作らない。
- OpenGraphite 契約を class で置き換えない。class は共存してよいが、`data-og-*` と `--og-*` だけでも理解できる状態を保つ。
- snippet を生成する場合は、構造を inspect / edit しやすいだけの `data-og-id` を含める。
- 再利用する multi-node component は `.ogp` の `components[]` に登録された component canvas HTML に置く。runtime または build expansion が必要な場合、page は `<og-instance>` 参照で軽量に保つ。
- 軽量な source-first project には `OpenGraphite.runtime.js` を使う。static deployment、SEO、no-JS delivery が重要な場合は `ogkiln build` を使う。
- page 側の slot override には標準の `slot` 属性を使い、master target には `data-og-slot` を使う。

## よく使うパターン

vertical section:

```html
<Section
  data-og-id="features"
  data-og-type="frame"
  data-og-layout="vertical"
  style="--og-gap:20px; --og-padding:32px;">
  ...
</Section>
```

horizontal action row:

```html
<Actions
  data-og-id="actions"
  data-og-type="frame"
  data-og-layout="horizontal"
  style="--og-gap:12px; --og-align:center;">
  <a data-og-id="primary" data-og-type="button" data-og-role="primary-button">Start</a>
  <a data-og-id="secondary" data-og-type="button" data-og-role="secondary-button">Learn more</a>
</Actions>
```

image frame:

```html
<Preview
  data-og-id="preview"
  data-og-type="image"
  data-og-role="card"
  style="--og-width:min(100%,640px); --og-height:360px; --og-radius:18px;">
  <img src="preview.png" alt="Preview" style="--og-object-fit:cover;">
</Preview>
```

absolute placement:

```html
<Canvas data-og-id="canvas" data-og-type="frame" data-og-layout="absolute">
  <Badge
    data-og-id="badge"
    data-og-type="text"
    style="--og-x:24px; --og-y:32px;">
    New
  </Badge>
</Canvas>
```

component master:

```html
<FeatureCard
  data-og-id="feature-card-master"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-component="feature-card"
  data-og-component-kind="master"
  data-og-part="root"
  style="--og-gap:16px; --og-padding:28px; --og-radius:6px;">
  <FeatureCardTitle
    data-og-id="feature-card-title"
    data-og-type="text"
    data-og-slot="title"
    style="--og-font-size:28px; --og-font-weight:800;">
    Fallback title
  </FeatureCardTitle>
  <FeatureCardBody
    data-og-id="feature-card-body"
    data-og-type="text"
    data-og-role="muted"
    data-og-slot="body">
    Fallback body
  </FeatureCardBody>
</FeatureCard>
```

component instance:

```html
<og-instance
  data-og-id="availability-card"
  data-og-type="frame"
  data-og-component="feature-card">
  <span slot="title">Availability-ready card</span>
  <span slot="body">Pages keep references while the master stays reusable.</span>
</og-instance>
```

## デバッグ

描画がおかしい場合は次を確認する。

1. `OpenGraphite.css` が期待した URL で読み込まれているか確認する。
2. 要素に `data-og-type` があるか確認する。多くの基本ルールはこれに依存する。
3. layout が child だけでなく parent の `data-og-layout` に付いているか確認する。
4. inline variable が valid な CSS declaration で、semicolon で終わっているか確認する。
5. image / video sizing では、media element を `data-og-type="image"` wrapper の直接 child に置く。
6. absolute layout では、parent に `data-og-layout="absolute"` を付け、直接 child element に `--og-x` / `--og-y` を設定する。
7. horizontal layout や button の形が変わる場合は、760px 以下の responsive behavior を確認する。
8. `<og-instance>` では、page に valid な `rel="opengraphite-components"` link があり、runtime expansion を使う場合は `OpenGraphite.runtime.js` が読み込まれ、master 側に一致する `data-og-component` と `data-og-component-kind="master"` があることを確認する。
9. runtime preview は正しいが deployment output が違う場合は、`ogkiln build <project.ogp|current> --output <dir>` を確認し、生成された static HTML を inspect する。
