# Link Navigation Contract TODO

作成日: 2026-07-06
更新日: 2026-08-09
分類: WebAssets
状態: Active

## 目的

標準 `a[href]`、native control、ARIA と DOM capability からリンク / action を判定する方針に対して、`href` の編集契約、ページ間リンクの表現、破損リンクの validation、build 時の扱いが未定義。マルチページサイトの成果物として必要なリンク契約を確定し、spec 化する。

## スコープ

- 対象: `href` / `target` / `rel` の編集契約、`.ogp` 登録 page への内部リンク解決と validation、Inspector のリンク編集 UI、build 時のリンク扱い。
- 対象外: text 内 inline link の編集操作（[InlineTextMarkupContract TODO](InlineTextMarkupContract.md)）、SPA ルーティング等の実装 runtime 挙動。

## 人間側の意思決定

- 全体: 必要 - 内部リンクの表現方式を確定する。

## 草案（判断材料）

- 内部リンク表現の候補: (a) document-relative / root-relative の標準 `href` 直書き（例: `./docs.html`）、(b) `ogref` 参照を属性に置き build で path へ解決。思想（ブラウザ単独表示可能、生成 DOM は正本にしない）に照らすと (a) が有力で、(b) は source が単独で機能しなくなるため原則不採用。
- `href` は HTML 正本の標準属性として編集し、`OpenGraphite.contract.json` の `editableAttributes` に追加する。
- validation: 内部 path が `.ogp` 登録 page または htmlRoot 配下の実在ファイルへ解決できない場合に `unresolved-internal-link`（warning）を返す。anchor（`#fragment`）の解決範囲も決める。
- Inspector: 内部 page picker（`.ogp` の pages 一覧から選択）+ 外部 URL 入力の 2 系統。
- `target="_blank"` 時の `rel="noopener"` 推奨を契約に書くかどうか。
- build: path 構造を維持し、リンク書き換えは行わないことを原則とする。

## 直列タスク

1. LNK-001: 内部リンク表現と validation 方針を確定する
   - 人間判断: 必要 - 表現方式（相対 path 直書きの採否）、validation severity、anchor 解決範囲、`rel` 推奨の扱いを決める。blocking decision。
   - 内容: 草案の選択肢を比較し、採否と方式を決定して本文書へ反映する。
   - 完了条件: 表現方式と validation 方針の決定が記録されている。
   - 確認方法: 文書確認。
2. LNK-002: リンク契約を spec 化する
   - 人間判断: 不要
   - 内容: SourceOfTruthContract / AgentInterface / OgkilnCLI / OpenGraphiteMCP と `OpenGraphite.contract.json` へ `href` 編集と validation を反映する。
   - 完了条件: 編集対象属性・解決規則・診断 code が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. LNK-003: 実装 TODO を起票する
   - 人間判断: 不要
   - 内容: Inspector リンク編集 / validation / CLI / MCP の実装タスクを直列化した TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Source of Truth Contract](../../../specs/SourceOfTruthContract.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [InlineTextMarkupContract TODO](InlineTextMarkupContract.md)
- [Other/RefactoringIntegrity TODO](../Other/RefactoringIntegrity.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
