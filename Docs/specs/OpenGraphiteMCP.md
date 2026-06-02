# OpenGraphite MCP Specification

OpenGraphite MCP server は stdio JSON-RPC server として動作し、AI client に OpenGraphite project (`.ogp`) の resources と tools を公開する。server 名は `OpenGraphite` とする。

## Runtime

```bash
node MCP/OpenGraphite/server.mjs
```

write tool は OpenGraphite app に直接命令しない。すべて `Scripts/ogkiln` へ委譲し、CLI と MCP が同じ validation / diagnostics / write path を共有する。

## Project Scope

MCP tool の対象 project は常に `projectPath` で指定する。`projectPath` は `.ogp` path または `current` を受け付ける。`current` は OpenGraphite.app が最後に開いた `.ogp` を Application Support のレコードから解決する。

page / component canvas / node を対象にする tool は、`pageID` または `componentID` のどちらか一方で対象 HTML を指定する。コピーされた値は `ogref:<type>:...` 形式で、`pageID` は `ogref:page:<chapterInternalID>:<pageInternalID>`、`componentID` は `ogref:component:<componentInternalID>` を指す。node 対象 tool の `id` は `data-og-internal-id` または `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<componentInternalID>:<nodeInternalID>` を受け取る。typed node 参照を使う場合は `pageID` / `componentID` を省略でき、raw node ID の場合はどちらか一方が必要である。両方を同時に渡す呼び出しは invalid である。

MCP は HTML path を直接書き換える tool を提供しない。`.ogp` にない既存 HTML は `add_project_page` または `add_project_component` で可視リストへ追加し、新規 HTML は `create_project_page` または `create_project_component` で作成と登録を同時に行う。配布用の静的 HTML が必要な場合は `build_project` で `<og-instance>` を component master から展開した出力を作る。

## Resources

| URI | MIME | Description |
| --- | --- | --- |
| `opengraphite://contract/css` | `application/json` | `OpenGraphite.contract.json` |
| `opengraphite://project/sample` | `application/json` | sample `.ogp` の解決済み project summary |
| `opengraphite://project/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の project summary |
| `opengraphite://pages/sample` | `application/json` | sample project の pages |
| `opengraphite://pages/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の pages |
| `opengraphite://components/sample` | `application/json` | sample project の component canvases |
| `opengraphite://components/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の component canvases |
| `opengraphite://pages/sample/home/graph` | `application/json` | sample project `home` page の node graph |
| `opengraphite://pages/sample/home/html` | `text/html` | sample project `home` page の正本 HTML |
| `opengraphite://components/sample/design-system/graph` | `application/json` | sample project `design-system` component canvas の node graph |
| `opengraphite://components/sample/design-system/html` | `text/html` | sample project `design-system` component canvas の正本 HTML |

任意の project / page / component canvas は resource URI ではなく tool 引数の `projectPath` と `pageID` / `componentID` で扱う。

## Tools

| Tool | Purpose | ogkiln mapping |
| --- | --- | --- |
| `get_contract` | active contract を返す | `contract get` |
| `validate` | `.ogp` を検証する | `validate <project>` |
| `build_project` | Pages の `<og-instance>` を component master で静的展開する | `build <project>` |
| `add_project_page` | 既存 HTML を既定 Chapter の page entry として追加する | `project page add` |
| `create_project_page` | HTML を新規作成し既定 Chapter の page entry として追加する | `project page create` |
| `place_project_page` | 既存 page entry の canvas 配置を更新する | `project page place` |
| `add_project_component` | 既存 HTML を Components segment の component canvas として追加する | `project component add` |
| `create_project_component` | HTML を新規作成し Components segment の component canvas として追加する | `project component create` |
| `place_project_component` | 既存 component canvas の配置を更新する | `project component place` |
| `remove_project_component` | component canvas 登録を削除する | `project component remove` |
| `list_nodes` | page または component canvas の node graph を返す | `page graph` |
| `screenshot_canvas` | `.ogp` の先頭 Chapter キャンバスを PNG に保存する | `screenshot canvas` |
| `screenshot_page` | page または component canvas を PNG に保存する | `screenshot page` |
| `screenshot_node` | page または component canvas 内の node を切り抜いた PNG に保存する | `screenshot node` |
| `query_nodes` | id / type / role / tag / text で node を検索する | `node query` |
| `get_node` | `data-og-internal-id` で node を取得する | `node get` |
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

page / component canvas を対象にする tool は `pageID` または `componentID` のどちらか一方を受け取る。node を対象にする tool は `id` を受け取り、raw node ID の場合は `pageID` / `componentID` も必要である。typed `ogref:node` / `ogref:component-node` の場合は `id` だけで対象 HTML と `data-og-internal-id` へ解決する。

`add_project_page.path`、`create_project_page.path`、`add_project_component.path`、`create_project_component.path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は invalid である。

`create_project_page` は page 登録と初期 canvas 配置を同時に扱える。`create_project_component` は component HTML の作成と登録を行い、配置変更は `place_project_component` で行う。

`place_project_page` と `place_project_component` の `name`、`x`、`y`、`width`、`height` は任意であり、省略した値は `.ogp` 内の現在値を維持する。`name` はフロー解決用の canvas 配置名として保存され、空文字または空白だけを指定すると名前なしとして保存する。

`remove_project_component.deleteFile` は既定で `false` である。`true` の場合のみ、`.ogp` からの登録削除に加えて component HTML file も削除する。

`build_project.outputPath` は build 出力ディレクトリである。build は Pages HTML を対象にし、Components segment の HTML と runtime script は公開 page としては出力しない。

`screenshot_page` の `width`、`height` は任意であり、省略時は `.ogp` entry の `canvas.width`、`canvas.height` を viewport として使う。`fullPage:true` の場合は document 全体を保存する。

`position` は `before`、`after`、`prepend`、`append` のいずれかである。

`copy_node.idPrefix` は複製 subtree 内の全 `data-og-id` に付与される。空文字は invalid である。

## Error Handling

MCP server は `ogkiln` の exit status が non-zero の場合、tool result の `isError` を `true` にする。diagnostics の本文は `content[].text` に JSON として返す。JSON-RPC protocol error は、未知の method や未知の resource / tool など server 自体で処理できない場合だけに使う。

## Pencil Compatibility Reading

Pencil の `batch_design` は `.pen` の object tree を insert / update / delete / move / copy / replace する。OpenGraphite MCP は同じ編集意図を、`.ogp` に登録された HTML page または component canvas の element subtree と node ID による操作へ分解する。Components segment の master 編集は `componentID` を指定した node operation、Pages 上の instance 編集は `pageID` を指定した `<og-instance>` または展開後 DOM への操作として扱う。`get_screenshot` / `export_nodes` に相当する visual operation は、`screenshot_canvas` / `screenshot_page` / `screenshot_node` として WebKit rendering pipeline から PNG を生成する。
