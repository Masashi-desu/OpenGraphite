# WebAssets TODO Index

更新日: 2026-08-09

`CSS/OpenGraphite.css`、`public/index.html`、`SampleProject`、`data-og-*` / CSS rendering contract など、web deliverable と sample の残タスクを管理する。この index の順序は文書単位の直列実行順を示す。

## 直列ドキュメント

1. [Responsive Media Query Contract TODO](ResponsiveMediaQueryContract.md): companion CSS の `@media` 編集モデルと breakpoint 定義場所を確定して spec 化する。
2. [Pseudo Class State Contract TODO](PseudoClassStateContract.md): `:hover` / `:focus` 等の状態スタイル編集契約と preview 再現方式を確定して spec 化する。
3. [Document Head Metadata Contract TODO](DocumentHeadMetadataContract.md): title / meta / OGP / favicon など `<head>` 編集の allowlist を確定して spec 化する。
4. [Inline Text Markup Contract TODO](InlineTextMarkupContract.md): text node 内の inline 要素（`a` / `strong` 等）の編集・保存契約を確定して spec 化する。
5. [Link Navigation Contract TODO](LinkNavigationContract.md): `href` 編集、内部リンク解決、破損リンク validation の契約を確定して spec 化する。
6. [Asset Media Contract TODO](AssetMediaContract.md): 画像・メディア asset の取り込み先、命名、参照形式の契約を確定して spec 化する。
7. [Accessibility Semantics Contract TODO](AccessibilitySemanticsContract.md): カスタムタグと標準セマンティクス（heading / landmark / aria）の表現方式を確定して spec 化する。
8. [Runtime Build Contract TODO](RuntimeBuildContract.md): `OpenGraphite.runtime.js` の展開契約と `ogkiln build` の出力・決定性保証を確定して spec 化する。
9. [Theme Token Scope Contract TODO](ThemeTokenScopeContract.md): design token の theme scope（dark mode 等）の表現方式を確定して spec 化する。
