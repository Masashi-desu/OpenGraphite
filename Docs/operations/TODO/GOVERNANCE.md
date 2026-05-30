# TODO Document Governance

更新日: 2026-05-30

## 適用範囲

この規約は `Docs/operations/TODO/` 配下の TODO 文書すべてに適用する。TODO 文書は残作業を進めるための運用文書であり、履歴保存や実装メモの保管場所ではない。

## 基本原則

- TODO 文書には未完了の作業だけを残す。
- 完了したタスクは、監査・移行判断・障害対応など残す理由が明確な場合を除き削除する。
- 残タスクがなくなった TODO 文書は削除し、親 index からリンクを外す。
- タスクはすべて直列化し、実行順が一意に読める番号付きリストで管理する。
- 各タスクには人間側の意思決定が必要かどうかを明示する。
- 完了条件と確認方法を各タスクに持たせ、1 タスクずつ完了判定できる粒度にする。

## 分類

TODO 文書は次の分類に置く。

1. `Editor/`: SwiftUI editor、`.ogp` project loading、WKWebView canvas bridge、layers、selection、inspector、HTML write-back など editor 実行経路の TODO。
2. `WebAssets/`: `CSS/OpenGraphite.css`、`public/index.html`、`SampleProject`、`data-og-*` / `--og-*` rendering contract など web deliverable と sample の TODO。
3. `Release/`: `project.yml` / XcodeGen、build/test scripts、DMG/notarization、配布手順など release と project operation の TODO。
4. `Other/`: 上記 3 分類に直接属さない運用 TODO。

複数分類にまたがる場合は主責務の分類に文書を置き、関連文書への参照を `参照` に追加する。

## 文書ライフサイクル

1. 新しい TODO を作る前に既存文書へ統合できないか確認する。
2. 新規作成時は [TEMPLATE.md](TEMPLATE.md) を複製した構成に合わせる。
3. タスクを追加するときは既存の直列順へ挿入し、依存関係が前後から読めるようにする。
4. タスクを完了したら、そのタスクを文書から削除する。
5. 完了タスクを残す必要がある場合は、文書内に `完了記録を残す理由` を置き、残す範囲と削除予定を明記する。
6. 残タスクがなくなったら TODO 文書を削除し、分類 index と root index を更新する。

## 直列化ルール

- `直列タスク` は番号付きリスト 1 本だけにする。
- 優先度別、短期/中期/長期、並行可能、カテゴリ別などのタスク節を作らない。
- 並行実行できる内容でも、文書上は実施順に並べる。
- 別文書との依存がある場合は、参照先ではなく現在の文書で次に行うタスクとして書く。
- 分類 index は文書単位の実行順を示す。文書内の実行順は各文書の `直列タスク` が示す。

## 人間判断の書き方

各タスクには次のどちらかを必ず書く。

- `人間判断: 不要`
- `人間判断: 必要 - <決める内容>`

人間判断が必要な場合は、何を決める必要があるか、実装を止める blocking decision かどうかを `内容` または `完了条件` に含める。

## 完了記録の例外

完了タスクや実装メモを残せるのは、次のような理由がある場合だけにする。

- リリース監査のため、一定期間だけ判断履歴を残す必要がある。
- 破壊的移行の根拠として、作業済み範囲を明示する必要がある。
- 障害対応やセキュリティ対応で、事後検証の証跡が必要である。

例外として残す場合も、TODO 本文とは分けて `完了記録を残す理由` に理由と削除条件を書く。

## OpenGraphite 固有の確認

- `project.yml` を XcodeGen の正本として扱い、`OpenGraphite.xcodeproj` は直接編集しない。
- Swift コードを追加・変更する TODO では、`Docs/rules/DocumentCommentStandards.md` に従い主要な型と関数へ `///` ドキュメントコメントを付与する。
- テストを追加・変更する TODO では、`Docs/rules/TestingStandards.md` に従い Swift Testing の `@Suite` / `@Test` と Given/When/Then コメントを用いる。
- 作業完了前の確認方法には、原則として `./Scripts/quality_gate.sh` を含める。外部要因で実行できない場合は、理由と未確認範囲を TODO または作業報告へ明記する。

## 更新チェックリスト

- 新規・更新した TODO 文書が [TEMPLATE.md](TEMPLATE.md) の構成に沿っている。
- 残タスクだけが記載されている。
- タスクが 1 本の番号付きリストで直列化されている。
- 各タスクに `人間判断`、`完了条件`、`確認方法` がある。
- 残タスクがない文書を削除し、index からリンクを外した。
- 分類 index と root index のリンク・実行順が現在の TODO 文書と一致している。
