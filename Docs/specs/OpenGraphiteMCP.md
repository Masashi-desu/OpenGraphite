# OpenGraphite MCP Specification

OpenGraphite MCP server は stdio JSON-RPC server として動作し、AI client に OpenGraphite project (`.ogp`) の resources と tools を公開する。server 名は `OpenGraphite` とする。

## Runtime

```bash
node MCP/OpenGraphite/server.mjs
```

write tool は OpenGraphite app に直接命令しない。すべて `Scripts/ogkiln` へ委譲し、CLI と MCP が同じ validation / diagnostics / write path を共有する。

## Project Scope

MCP tool の編集対象は常に `projectPath` と `pageID` で指定する。`projectPath` は `.ogp` path または `current` を受け付ける。`current` は OpenGraphite.app が最後に開いた `.ogp` を Application Support のレコードから解決する。

MCP は HTML path を直接書き換える tool を提供しない。`.ogp` にない既存 HTML は `add_project_page` で `pages[]` に追加し、新規 HTML は `create_project_page` で作成と登録を同時に行う。

## Resources

| URI | MIME | Description |
| --- | --- | --- |
| `opengraphite://contract/css` | `application/json` | `OpenGraphite.contract.json` |
| `opengraphite://project/sample` | `application/json` | sample `.ogp` の解決済み project summary |
| `opengraphite://project/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の project summary |
| `opengraphite://pages/sample` | `application/json` | sample project の pages |
| `opengraphite://pages/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の pages |
| `opengraphite://pages/sample/home/graph` | `application/json` | sample project `home` page の node graph |
| `opengraphite://pages/sample/home/html` | `text/html` | sample project `home` page の正本 HTML |

任意の project / page は resource URI ではなく tool 引数の `projectPath` / `pageID` で扱う。

## Tools

| Tool | Purpose | ogkiln mapping |
| --- | --- | --- |
| `get_contract` | active contract を返す | `contract get` |
| `validate` | `.ogp` を検証する | `validate <project>` |
| `add_project_page` | 既存 HTML を `.ogp` の page entry として追加する | `project page add` |
| `create_project_page` | HTML を新規作成し `.ogp` の page entry として追加する | `project page create` |
| `place_project_page` | 既存 page entry の canvas 配置を更新する | `project page place` |
| `list_nodes` | project page の node graph を返す | `page graph` |
| `screenshot_canvas` | `.ogp` のキャンバス全体を PNG に保存する | `screenshot canvas` |
| `screenshot_page` | project page を PNG に保存する | `screenshot page` |
| `screenshot_node` | project page 内の `data-og-id` node を切り抜いた PNG に保存する | `screenshot node` |
| `query_nodes` | id / type / role / tag / text で node を検索する | `node query` |
| `get_node` | `data-og-id` で node を取得する | `node get` |
| `set_css_variable` | node の `--og-*` CSS variable を設定する | `node style set` |
| `remove_css_variable` | node の `--og-*` CSS variable を削除する | `node style remove` |
| `set_node_attribute` | editable `data-og-*` 属性を設定する | `node attr set` |
| `remove_node_attribute` | editable `data-og-*` 属性を削除する | `node attr remove` |
| `set_text_content` | node の中身を escaped text に置換する | `node text set` |
| `insert_html` | anchor node 基準で HTML 断片を挿入する | `node html insert` |
| `replace_node_html` | node subtree を HTML 断片で置換する | `node html replace` |
| `delete_node` | node subtree を削除する | `node delete` |
| `move_node` | node subtree を target node 基準位置へ移動する | `node move` |
| `copy_node` | node subtree を prefix 付き ID で複製する | `node copy` |

## Tool Arguments

すべての tool は、対象 project を `projectPath` で受け取る。`projectPath` は repository root 相対 path、絶対 path、または `current` である。

page を対象にする tool は `pageID` を必須にする。node を対象にする tool は `id` を `data-og-id` として扱う。

`add_project_page.path` と `create_project_page.path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は invalid である。

`place_project_page` の `x`、`y`、`width`、`height` は任意であり、省略した値は `.ogp` 内の現在値を維持する。

`screenshot_page` の `width`、`height` は任意であり、省略時は `.ogp` page entry の `canvas.width`、`canvas.height` を viewport として使う。`fullPage:true` の場合は document 全体を保存する。

`position` は `before`、`after`、`prepend`、`append` のいずれかである。

`copy_node.idPrefix` は複製 subtree 内の全 `data-og-id` に付与される。空文字は invalid である。

## Error Handling

MCP server は `ogkiln` の exit status が non-zero の場合、tool result の `isError` を `true` にする。diagnostics の本文は `content[].text` に JSON として返す。JSON-RPC protocol error は、未知の method や未知の resource / tool など server 自体で処理できない場合だけに使う。

## Pencil Compatibility Reading

Pencil の `batch_design` は `.pen` の object tree を insert / update / delete / move / copy / replace する。OpenGraphite MCP は同じ編集意図を、`.ogp` に登録された HTML page の element subtree と `data-og-id` による操作へ分解する。`get_screenshot` / `export_nodes` に相当する visual operation は、`screenshot_canvas` / `screenshot_page` / `screenshot_node` として WebKit rendering pipeline から PNG を生成する。
