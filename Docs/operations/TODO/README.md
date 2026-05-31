# Operations TODO Index

更新日: 2026-05-31

OpenGraphite の運用 TODO は、残タスクだけを直列化して管理する。作成・更新・削除の正本は [TODO Document Governance](GOVERNANCE.md)、新規文書の雛形は [TEMPLATE.md](TEMPLATE.md) とする。

実測や調査で仕様判断する項目は、必要に応じて [Docs/investigations](../../investigations/) や該当する仕様・設計文書に判断材料を置き、決まった結果だけを TODO と仕様へ戻す。TODO 文書は履歴や実装メモの保管場所にしない。

## 運用規約

- TODO 文書には未完了タスクだけを残す。
- 完了したタスクは、明確な理由がなければ削除する。
- 残タスクがなくなった TODO 文書は削除し、index からリンクを外す。
- タスクはすべて直列化し、各タスクに人間判断の要否を明示する。

## 分類順

1. [Editor](Editor/): SwiftUI editor、`.ogp` project loading、WKWebView canvas bridge、layers、selection、inspector、HTML write-back など editor 実行経路の TODO。
2. [WebAssets](WebAssets/): `CSS/OpenGraphite.css`、`public/index.html`、`SampleProject`、`data-og-*` / `--og-*` rendering contract など web deliverable と sample の TODO。
3. [Release](Release/): `project.yml` / XcodeGen、build/test scripts、DMG/notarization、配布手順など release と project operation の TODO。
4. [Other](Other/): 上記 3 分類に直接属さない運用 TODO。

## 現在の直列ドキュメント

1. [Agent Interface Batch Editing TODO](Other/AgentInterfaceBatchEditing.md): `ogkiln` と OpenGraphite MCP のバッチ編集、dry-run、diff、整形、テンプレート適用を整備する。
