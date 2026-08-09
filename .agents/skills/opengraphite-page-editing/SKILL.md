---
name: opengraphite-page-editing
description: "OpenGraphite リポジトリまたは OpenGraphite project の page / component HTML を編集するとき、またはOpenGraphiteの機能追加・改修・削除に合わせてTutorials教材を同期するときに使う。特に public/、public/_components/、public/locales/、.ogp に登録されたpages/components、tutorial HTML/CSS、annotation、Guide、preview metadataを更新するときに、ページ編集の思想と判断原則を確認するために使う。"
---

# OpenGraphite ページ編集

OpenGraphite 管理下の page / component HTML を編集するときの思想を示す skill である。ここには実装上の契約や操作手順を置かない。ページ編集時の判断が OpenGraphite の設計思想から外れないようにするためだけに使う。

## 責務の委譲

具体的な契約、操作、検証方法はこの skill では定義しない。必要に応じて次の資料へ委譲する。

- HTML / CSS / runtime / preview / resource の契約: `Docs/specs/SourceOfTruthContract.md`
- CLI / MCP / graph / node edit / diagnostics の契約: `Docs/specs/AgentInterface.md`
- OpenGraphite の設計思想と判断基準: `Docs/specs/DesignPhilosophy.md`
- 機能変更と `Tutorials` 教材の同期規約: `Docs/rules/TutorialSynchronizationStandards.md`
- リポジトリの build / test / quality gate / sample project の扱い: `README.md`
- `OpenGraphite.css`、optional `data-og-*`、標準 HTML/CSS、legacy migration input、operation capability、component の説明: `opengraphite-css-contract`

この skill と詳細資料が食い違う場合は、詳細資料を優先する。この skill は方針を思い出すための入口であり、正本の代替ではない。

## 編集思想

- Web 標準の source files を正本として扱う。OpenGraphite のページ編集は、独自の中間表現を作るためではなく、最終成果物になり得る source を直接整えるために行う。
- `public/` のページ編集は、OpenGraphite が実際の Web deliverable を扱えることの自己検証でもある。ホームページやドキュメントページを例外的な手作業の成果物として扱わない。
- OpenGraphite.app、CLI、MCP、browser、AI agent は、同じリポジトリ上の source を見て協業するための入口である。どの入口を使っても、最終的な説明は source files に戻るべきである。
- ページの見た目、構造、文言、preview state、project metadata の責務を混ぜない。便利さのために正本の境界を曖昧にしない。
- キャンバス前面の付箋と手書きは `.ogp` の collaboration annotation であり、page content ではない。注釈を実装指示として扱う場合も、明示的に source edit を実行するまでは HTML / CSS / build output へ混ぜず、実装結果は通常の Web source として保存する。
- 既存機能で自然に編集できない場合は、ページを迂回して壊れやすい例外運用を増やすのではなく、OpenGraphite 側の不足として捉える。
- 不足機能を追加するときは、短期的な作業効率よりも、source-of-truth model、Web 標準としての可読性、リポジトリ上でのレビュー可能性を優先する。
- ユーザーが観察できる機能を追加・改修・削除するときは、最も近い既存教材を更新するか独立した教材を追加し、実装、仕様、テスト、Sample `.ogp` と同じ変更単位で同期する。教材を更新しない判断は、利用者が観察できる挙動を変えない場合に限る。
- `public/`、Tutorial HTML/CSS、Sampleの新規resourceは現行Web contractの標準sourceだけで作る。legacy tokenそのものを公開教材へ埋め込まず、移行手順は明示dry-run、全diff review、snapshot-bound proposal、atomic apply、再validateとして説明する。実legacy inputの受入確認はrepository外の一時fixtureで行う。
- 旧projectを変換する場合も通常のopen、inspection、preview、無編集保存をmigrationとみなさない。`ogkiln migrate` / `migrate_project`のdry-runを先に行い、manifest、登録HTML、project/companion/linked/import CSS、local runtimeのclosureと全diffをreviewする。未知reserved CSS、解決不能dependency、legacy component master/slot、source placement mode/stateのように一意に変換できない構造があれば、公開sourceへ推測patchせずproject全体をno-writeにし、template / slot / placement sourceと`.ogp`のstandard host stateを手動で揃えて再dry-runする。migration教材を更新するときは`.ogp` / Agent schema据え置き、optional identity / reference / binding / editing policy / icon provenanceの維持、project-local `OpenGraphite.contract.json`をproposal/diff/apply対象にせずbytes不変にする境界、registered-source token検出に基づくapply後idempotencyも同期する。
- class や生成物や editor-only state を、OpenGraphite が信頼する主要な編集正本へ昇格させない。
- ページ編集の完了判断は、見た目が一度整ったかではなく、OpenGraphite の正本モデルに沿って継続的に編集、検証、配布できる状態になっているかで行う。

## 判断基準

迷った場合は次の順に考える。

1. 編集後の source files は、そのまま Web 成果物として読めるか。
2. 変更理由と責務境界は、リポジトリ上の資料と source から説明できるか。
3. OpenGraphite の UI、CLI、MCP、AI agent が同じ正本を扱う協業モデルを保てているか。
4. 例外的な手作業ではなく、次回以降も OpenGraphite の経路で自然に編集できるか。
5. 公開リポジトリへ置いても、ユーザー固有情報、生成物の混入、別正本化を招かないか。
6. 変更後のユーザーワークフロー、名称、制約、保存先、表示結果が対応する `Tutorials` 教材にも反映されているか。
