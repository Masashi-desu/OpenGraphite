# Operations TODO Index

更新日: 2026-08-09

OpenGraphite の運用 TODO は、残タスクだけを直列化して管理する。作成・更新・削除の正本は [TODO Document Governance](GOVERNANCE.md)、新規文書の雛形は [TEMPLATE.md](TEMPLATE.md) とする。

実測や調査で仕様判断する項目は、必要に応じて [Docs/investigations](../../investigations/) や該当する仕様・設計文書に判断材料を置き、決まった結果だけを TODO と仕様へ戻す。TODO 文書は履歴や実装メモの保管場所にしない。

## 運用規約

- TODO 文書には未完了タスクだけを残す。
- 完了したタスクは、明確な理由がなければ削除する。
- 残タスクがなくなった TODO 文書は削除し、index からリンクを外す。
- タスクはすべて直列化し、各タスクに人間判断の要否を明示する。

## 分類順

1. [Editor](Editor/): SwiftUI editor、`.ogp` project loading、WKWebView canvas bridge、layers、selection、inspector、HTML write-back など editor 実行経路の TODO。
2. [WebAssets](WebAssets/): `CSS/OpenGraphite.css`、`public/index.html`、`SampleProject`、`data-og-*` / CSS rendering contract など web deliverable と sample の TODO。
3. [Release](Release/): `project.yml` / XcodeGen、build/test scripts、DMG/notarization、配布手順など release と project operation の TODO。
4. [Other](Other/): 上記 3 分類に直接属さない運用 TODO。

## 現在の直列ドキュメント

1. [Agent Interface Batch Editing TODO](Other/AgentInterfaceBatchEditing.md): `ogkiln` と OpenGraphite MCP のバッチ編集、dry-run、diff、整形、テンプレート適用を整備する。
2. [Persistence Conflict Undo TODO](Editor/PersistenceConflictUndo.md): 保存パイプライン、外部変更との競合解決、複数ファイル横断の undo / redo 単位の方針を確定して spec 化する。
3. [HTML CSS Serialization Stability TODO](Editor/HtmlCssSerializationStability.md): 書き戻し時の diff 安定性（roundtrip、非編集領域の byte 保持、整形規則）の方針を確定して spec 化する。
4. [Ogp Schema Versioning TODO](Editor/OgpSchemaVersioning.md): `.ogp` スキーマの正本定義、未知キー保持、schemaVersion 互換・migration 方針を確定して spec 化する。
5. [Validation Diagnostics Catalog TODO](Other/ValidationDiagnosticsCatalog.md): 診断 code の正本カタログ、命名規約、app / CLI / MCP のパリティ保証を確定して spec 化する。
6. [Responsive Media Query Contract TODO](WebAssets/ResponsiveMediaQueryContract.md): companion CSS の `@media` 編集モデルと breakpoint 定義場所を確定して spec 化する。
7. [Pseudo Class State Contract TODO](WebAssets/PseudoClassStateContract.md): `:hover` / `:focus` 等の状態スタイル編集契約と preview 再現方式を確定して spec 化する。
8. [Document Head Metadata Contract TODO](WebAssets/DocumentHeadMetadataContract.md): title / meta / OGP / favicon など `<head>` 編集の allowlist を確定して spec 化する。
9. [Inline Text Markup Contract TODO](WebAssets/InlineTextMarkupContract.md): text node 内の inline 要素（`a` / `strong` 等）の編集・保存契約を確定して spec 化する。
10. [Link Navigation Contract TODO](WebAssets/LinkNavigationContract.md): `href` 編集、内部リンク解決、破損リンク validation の契約を確定して spec 化する。
11. [Asset Media Contract TODO](WebAssets/AssetMediaContract.md): 画像・メディア asset の取り込み先、命名、参照形式の契約を確定して spec 化する。
12. [Accessibility Semantics Contract TODO](WebAssets/AccessibilitySemanticsContract.md): カスタムタグと標準セマンティクス（heading / landmark / aria）の表現方式を確定して spec 化する。
13. [Runtime Build Contract TODO](WebAssets/RuntimeBuildContract.md): `OpenGraphite.runtime.js` の展開契約と `ogkiln build` の出力・決定性保証を確定して spec 化する。
14. [Theme Token Scope Contract TODO](WebAssets/ThemeTokenScopeContract.md): design token の theme scope（dark mode 等）の表現方式を確定して spec 化する。
15. [Refactoring Integrity TODO](Other/RefactoringIntegrity.md): page path 移動・component rename に伴う参照一括更新と orphan 診断を確定して spec 化する。
16. [Security Trust Model TODO](Other/SecurityTrustModel.md): preview の JS / network 方針と `ogkiln` / MCP の path containment を信頼モデルとして確定して spec 化する。
