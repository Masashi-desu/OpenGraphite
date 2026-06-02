# OpenGraphite Agent Interface

OpenGraphite の AI 協業インターフェースは、リポジトリ上の HTML / CSS / `.ogp` を正本として扱う。AI、CLI、MCP は同じファイルを読み、同じ検証契約を通して、可能な限り node 単位の小さな編集操作として変更する。編集対象 HTML は必ず `.ogp` の `chapters[].pages[]` または `collections[].components[]` でユーザーが認知できる状態にしてから扱う。

参考にする先行事例は Pencil / OpenPencil だが、OpenGraphite は `.pen` の JSON IR ではなく HTML を編集対象にする。Pencil CLI は headless editor と interactive MCP tool shell を提供し、`batch_design` で insert / update / delete / move / copy / replace を扱う。OpenPencil も headless CLI、query、MCP server、export を同じ engine 上に置く。OpenGraphite ではこれを `ogkiln`、OpenGraphite MCP server、`OpenGraphiteHTMLDocument` core、`OpenGraphite.contract.json` の組み合わせへ読み替える。

- Pencil CLI: <https://docs.pencil.dev/for-developers/pencil-cli>
- Pencil `.pen` format: <https://docs.pencil.dev/for-developers/the-pen-format>
- OpenPencil repository: <https://github.com/open-pencil/open-pencil>

## Interface Roles

- `ogkiln`: 人間、CI、MCP server が同じ挙動を再現できる CLI。
- OpenGraphite MCP server: AI クライアントが構造化 resource / tool として OpenGraphite リポジトリを読むための stdio MCP server。
- `OpenGraphite.contract.json`: `data-og-*`、`--og-*`、type、layout、role、runtime 属性の機械可読な契約。
- OpenGraphite app: 正本ファイルを `WKWebView` に表示し、外部変更を検出して Canvas、Layers、Inspector へ同期する UI。

MCP の表向きの名前は OpenGraphite とする。`ogkiln` は CLI 名であり、MCP の write tool は `ogkiln` または同じ core 実装と同等の validation / diagnostics を必ず通す。

詳細仕様:

- [`OgkilnCLI.md`](OgkilnCLI.md): CLI command、JSON output、編集操作。
- [`OpenGraphiteMCP.md`](OpenGraphiteMCP.md): MCP resources / tools と `ogkiln` への対応。

## Project Summary

`ogkiln project inspect <project.ogp|current> --json` と MCP の project resource は次の構造を返す。

```json
{
  "schemaVersion": "0.1",
  "projectName": "OpenGraphite Sample",
  "projectURL": "/repo/SampleProject/OpenGraphiteSample.ogp",
  "rootURL": "/repo",
  "htmlRoot": "public",
  "cssURL": "/repo/CSS/OpenGraphite.css",
  "chapters": [
    {
      "id": "main",
      "internalID": "6q8zy7p2k1",
      "index": 0,
      "title": "Main",
      "pages": [
        {
          "chapterID": "main",
          "chapterInternalID": "6q8zy7p2k1",
          "id": "home",
          "internalID": "d2t9n4x8ra",
          "referenceID": "ogref:page:6q8zy7p2k1:d2t9n4x8ra",
          "chapterIndex": 0,
          "pageIndex": 0,
          "path": "index.html",
          "htmlURL": "/repo/public/index.html",
          "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
        }
      ]
    }
  ],
  "pages": [
    {
      "chapterID": "main",
      "chapterInternalID": "6q8zy7p2k1",
      "segment": "pages",
      "id": "home",
      "internalID": "d2t9n4x8ra",
      "referenceID": "ogref:page:6q8zy7p2k1:d2t9n4x8ra",
      "chapterIndex": 0,
      "pageIndex": 0,
      "path": "index.html",
      "htmlURL": "/repo/public/index.html",
      "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
    }
  ],
  "collections": [
    {
      "id": "main",
      "internalID": "component-main",
      "index": 0,
      "title": "Main",
      "components": [
        {
          "collectionID": "main",
          "collectionInternalID": "component-main",
          "segment": "components",
          "id": "design-system",
          "internalID": "7m4wq0f5bc",
          "referenceID": "ogref:component:component-main:7m4wq0f5bc",
          "collectionIndex": 0,
          "pageIndex": 0,
          "path": "_components/design-system.html",
          "htmlURL": "/repo/public/_components/design-system.html",
          "canvas": { "name": "", "x": 1120, "y": 0, "width": 1180, "height": 1900 }
        }
      ]
    }
  ],
  "components": [
    {
      "collectionID": "main",
      "collectionInternalID": "component-main",
      "segment": "components",
      "id": "design-system",
      "internalID": "7m4wq0f5bc",
      "referenceID": "ogref:component:component-main:7m4wq0f5bc",
      "collectionIndex": 0,
      "pageIndex": 0,
      "path": "_components/design-system.html",
      "htmlURL": "/repo/public/_components/design-system.html",
      "canvas": { "name": "", "x": 1120, "y": 0, "width": 1180, "height": 1900 }
    }
  ],
  "diagnostics": []
}
```

`internalID` は `.ogp` 内で一意な内部キーである。表示名や `id` を含まない不透明 ID として扱い、保存時には manifest に書き戻す。

`referenceID` は AI が Chapter / Collection / page / component canvas / node を安定指定するためのキーであり、コピーされる文字列は `ogref:<type>:...` 形式である。Chapter は `ogref:chapter:<chapterInternalID>`、Collection は `ogref:collection:<collectionInternalID>`、Pages は `ogref:page:<chapterInternalID>:<pageInternalID>`、Components は `ogref:component:<collectionInternalID>:<componentInternalID>`、Pages 内 node は `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>`、component 内 node は `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を使う。

## Page Graph

`ogkiln page graph <project.ogp|current> --page-id <page-reference-id>|--component-id <component-reference-id> --json` と MCP の graph resource は、`.ogp` の対象 page または component canvas に含まれる `[data-og-id]` ノードを DOM 出現順に返す。Collection 内 component HTML は `--component-id <component-reference-id>` で同じ graph / node edit 経路を使う。`--page-id` / `--component-id` は `internalID`、`<groupInternalID>:<pageInternalID>`、または `referenceID` で解決する。

```json
{
  "schemaVersion": "0.1",
  "pageURL": "/repo/public/index.html",
  "nodes": [
    {
      "id": "hero",
      "internalID": "a4e19c02f6b8",
      "tagName": "herosection",
      "type": "frame",
      "layout": "horizontal",
      "role": "landing-hero",
      "cssVariables": {
        "--og-gap": "44px"
      },
      "hidden": false,
      "locked": false,
      "depth": 2,
      "parentID": "page",
      "textContent": "OpenGraphite",
      "attributes": {
        "data-og-id": "hero",
        "data-og-internal-id": "a4e19c02f6b8",
        "data-og-type": "frame"
      }
    }
  ],
  "diagnostics": []
}
```

`data-og-id` は UI 表示や従来の node edit operation に使うページ内 ID である。`data-og-internal-id` は名称変更から独立した内部不変 ID であり、コピーされる agent 向け参照IDの node 部分に使う。DOM の位置や tag name は同一性として使わない。

`parentID` は最も近い OpenGraphite ancestor の `data-og-id` である。HTML に通常の `div` や `span` が挟まっても、AI は OpenGraphite node graph 上の親子関係として扱える。`textContent` は node subtree 内のタグを除いたプレーンテキストであり、検索と確認に使う。

## Diagnostics

検証結果は severity、code、message、path、nodeID を持つ。

```json
{
  "severity": "error",
  "code": "duplicate-data-og-id",
  "message": "data-og-id \"hero\" が重複しています。",
  "path": "/repo/public/index.html",
  "nodeID": "hero"
}
```

`error` がある操作は write を行わない。`warning` は write を止めないが、AI はユーザーへ変更リスクとして報告できる必要がある。

## Edit Operations

AI と MCP は HTML 全体の置換より次の node 単位操作を優先する。

```bash
ogkiln contract get --json
ogkiln project current --json
ogkiln project page create SampleProject/OpenGraphiteSample.ogp --page-id tutorial --path tutorial.html --title Tutorial --body-file tutorial.body.html --x 2960 --y 0
ogkiln project page add SampleProject/OpenGraphiteSample.ogp --page-id archive --path archive.html --x 4440 --y 0
ogkiln project page place SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --name Desktop --x 3040 --y 0
ogkiln project component create SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id shared-ui --path _components/shared-ui.html --title 'Shared UI' --body-file shared-ui.body.html
ogkiln project component add SampleProject/OpenGraphiteSample.ogp --collection-id component-main --component-id aux-ui --path _components/aux-ui.html --width 960 --height 900
ogkiln project component place SampleProject/OpenGraphiteSample.ogp --component-id <shared-ui-internal-id> --name Desktop --width 1180 --height 1900
ogkiln project component remove SampleProject/OpenGraphiteSample.ogp --component-id <aux-ui-internal-id>
ogkiln screenshot canvas SampleProject/OpenGraphiteSample.ogp --output screenshots/canvas.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --output screenshots/docs.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --output screenshots/design-system.png
ogkiln screenshot page SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:2opic2blumreb --width 390 --height 900 --full-page --output screenshots/docs-mobile.png
ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:2opic2blumreb:fb1954bc9811 --output screenshots/doc-cli.png
ogkiln screenshot node SampleProject/OpenGraphiteSample.ogp --id ogref:component-node:component-main:3bgx6phkz3jv5:3af881fc5123 --output screenshots/feature-card.png
ogkiln build SampleProject/OpenGraphiteSample.ogp --output dist
ogkiln node query SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --type button --text-contains Docs --json
ogkiln node query SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --type frame --json
ogkiln node get SampleProject/OpenGraphiteSample.ogp --id ogref:node:1gibtxulofmr0:kl1xxsgkiuue:3aefceddb042 --json
ogkiln node style set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var --og-gap --value 32px
ogkiln node style set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 3af881fc5123 --var --og-padding --value 48px
ogkiln node style remove SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --var --og-gap
ogkiln node attr set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --name data-og-role --value card
ogkiln node attr set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 3af881fc5123 --name data-og-part --value root
ogkiln node attr remove SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --name data-og-role
ogkiln node text set SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id eace7f6a5b08 --value 'OpenGraphite'
ogkiln node text set SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 57d89af48b12 --value 'Reusable card'
ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 72222bd6f11e --position prepend --html '<Header data-og-id="site-header" data-og-type="frame"></Header>'
ogkiln node html insert SampleProject/OpenGraphiteSample.ogp --component-id ogref:component:component-main:3bgx6phkz3jv5 --id 42addef8c515 --position append --html '<FeatureCard data-og-id="feature-card-master" data-og-type="frame" data-og-component="feature-card" data-og-component-kind="master"></FeatureCard>'
ogkiln node html replace SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id 3aefceddb042 --html '<Hero data-og-id="hero" data-og-type="frame"></Hero>'
ogkiln node delete SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id <node-internal-id>
ogkiln node move SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id efeaffcc2273 --target 3aefceddb042 --position after
ogkiln node copy SampleProject/OpenGraphiteSample.ogp --page-id ogref:page:1gibtxulofmr0:kl1xxsgkiuue --id d9778be9a854 --target b01aee52375f --position append --id-prefix copy-
```

`.ogp` に登録されていない HTML は直接編集しない。既存 page HTML は `project page add`、新規 page HTML は `project page create` により既定 Chapter の `pages[]` に追加してから node operation の対象にする。component master を置く HTML は `project component add` または `project component create` により Collection の `components[]` に追加し、`--component-id` で同じ node operation の対象にする。

write operation は次の制約を持つ。

- 対象 node は一意な `data-og-internal-id` で解決できること。
- `data-og-id` が重複している場合は失敗すること。
- `data-og-internal-id` が重複している場合は失敗すること。
- `--og-*` 以外の CSS 変数を `node style set` で更新しないこと。
- `data-og-selected` と `data-og-editing` は正本 HTML へ残さないこと。
- `data-og-internal-id` は内部不変 ID のため、通常の `node attr set` では変更しないこと。
- 許可済み永続属性は `OpenGraphite.contract.json` の `editableAttributes` に従うこと。
- 子 HTML 挿入後の graph に validation error がある場合は、対象ファイルを書き換えないこと。
- `node text set` は HTML としてではなく text として保存し、`<`、`>`、`&` を escape すること。
- `node copy` は subtree 内の全 `data-og-id` に `--id-prefix` を付与し、複製側の `data-og-internal-id` は新しい不透明 ID にすること。
- `node move` は source subtree 内の node を target に指定できないこと。

HTML 全体を直接編集する fallback は `ogkiln` / MCP の通常 tool では提供しない。node 単位操作で表現できない構造変更は、`node html insert` / `replace` で明示的な subtree 操作として表現する。

## Pencil Mapping

Pencil / OpenPencil の design document 操作は OpenGraphite では次のように対応する。

| Pencil / OpenPencil | OpenGraphite |
| --- | --- |
| `.pen` JSON IR | HTML 正本 + `data-og-*` metadata + `--og-*` CSS variables |
| node `id` | `data-og-internal-id`（表示 ID は `data-og-id`） |
| `get_editor_state` | `project inspect` + `page graph --page-id` / `page graph --component-id` |
| `batch_get` / tree / find / query | `node query` / `node get` |
| `batch_design` insert | `node html insert` |
| `batch_design` update | `node style set` / `node attr set` / `node text set` |
| `batch_design` delete | `node delete` |
| `batch_design` move | `node move` |
| `batch_design` copy | `node copy --id-prefix` |
| `batch_design` replace | `node html replace` |
| `get_variables` / `set_variables` | `contract get` と `node style set/remove`。将来は page/theme scope の変数操作へ拡張する。 |
| `snapshot_layout` | 現時点では graph の構造情報。visual bounds は `screenshot_node` の切り抜き対象として WebKit から解決する。 |
| `get_screenshot` / `export_nodes` | `screenshot_canvas` / `screenshot_page` / `screenshot_node`。HTML を WebKit でレンダリングして PNG を保存する。 |

## MCP Resources

OpenGraphite MCP server は少なくとも次の resource を公開する。

- `opengraphite://contract/css`
- `opengraphite://project/sample`
- `opengraphite://project/current`
- `opengraphite://pages/sample`
- `opengraphite://pages/current`
- `opengraphite://components/sample`
- `opengraphite://components/current`
- `opengraphite://pages/sample/home/graph`
- `opengraphite://pages/sample/home/html`
- `opengraphite://components/sample/design-system/graph`
- `opengraphite://components/sample/design-system/html`

任意プロジェクト、任意ページ、任意 component canvas は tool の `projectPath` と `pageID` / `componentID` 引数で扱う。

## MCP Tools

OpenGraphite MCP server は少なくとも次の tool を公開する。

- `get_contract`
- `validate`
- `build_project`
- `add_project_page`
- `create_project_page`
- `place_project_page`
- `add_project_component`
- `create_project_component`
- `place_project_component`
- `remove_project_component`
- `list_nodes`
- `screenshot_canvas`
- `screenshot_page`
- `screenshot_node`
- `query_nodes`
- `get_node`
- `set_css_variable`
- `remove_css_variable`
- `set_node_attribute`
- `remove_node_attribute`
- `set_text_content`
- `insert_html`
- `replace_node_html`
- `delete_node`
- `move_node`
- `copy_node`

MCP の write tool は OpenGraphite app に直接命令しない。リポジトリ上の正本ファイルを更新し、app は外部ファイル変更同期で表示を追従する。

`pageID` と `componentID` は同時指定できない。Pages HTML を編集する場合は `pageID`、Collection 内 component master HTML を編集する場合は `componentID` を指定する。

## External Synchronization

OpenGraphite app は `.ogp` に含まれる全 HTML ファイルの外部変更を検出し、ディスク上の正本 HTML を WebView に反映する。選択中ページは WebView 置換要求として履歴と選択状態を保ち、非選択ページは reload token によりキャンバス上のプレビューを再読み込みする。app 内で未適用の mutation または document replacement がある場合、選択中ページの外部変更を破壊的に上書きせず、ユーザーへ衝突として見える状態にする。

`.ogp` project manifest も外部変更監視の対象にする。`ogkiln project page add`、`ogkiln project page create`、`ogkiln project page place`、`ogkiln project component add`、`ogkiln project component create`、`ogkiln project component place`、`ogkiln project component remove` が entry と canvas 配置を更新した場合、app は project manifest を再読み込みし、既存の選択 Chapter / Collection と選択ページ / component canvas を可能な限り維持したまま Canvas 上の配置を更新する。
