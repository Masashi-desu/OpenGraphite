# OpenGraphite MCP Specification

OpenGraphite MCP server は stdio JSON-RPC server として動作し、AI client に OpenGraphite project (`.ogp`) の resources と tools を公開する。server 名は `OpenGraphite` とする。HTML は構造と参照の正本、同名 companion CSS はデザイン値の正本、Chapter / Collection の付箋・手書きは `.ogp` 専用 metadata として扱う。

## Runtime

```bash
node MCP/OpenGraphite/server.mjs
```

write tool は OpenGraphite app に直接命令しない。すべて `Scripts/ogkiln` へ委譲し、CLI と MCP が同じ validation / diagnostics / HTML / companion CSS write path を共有する。

## Project Scope

MCP tool の対象 project は常に `projectPath` で指定する。`projectPath` は `.ogp` path または `current` を受け付ける。`current` は OpenGraphite.app が最後に開いた `.ogp` を Application Support のレコードから解決する。

page / component canvas / node を対象にする tool は、`pageID` または `componentID` のどちらか一方で対象 HTML を指定する。コピーされた値は `ogref:<type>:...` 形式で、`pageID` は `ogref:page:<chapterInternalID>:<pageInternalID>`、`componentID` は `ogref:component:<collectionInternalID>:<componentInternalID>` を指す。node 対象 tool の `id` は `data-og-internal-id` または `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を受け取る。typed node 参照を使う場合は `pageID` / `componentID` を省略でき、raw node ID の場合はどちらか一方が必要である。両方を同時に渡す呼び出しは invalid である。

MCP は HTML path を直接書き換える tool を提供しない。`.ogp` にない既存 HTML は `add_project_page` または `add_project_component` で可視リストへ追加し、新規 HTML は `create_project_page` または `create_project_component` で HTML と同名 companion CSS の作成と登録を同時に行う。配布用の静的 HTML が必要な場合は `build_project` で `<og-instance>` を component master から展開した出力を作る。

Canvas annotation tool は読み取り専用である。`list_canvas_annotations` / `get_canvas_annotation` は `.ogp` を読むだけで、HTML / CSS / runtime / build 成果物を更新しない。schema と座標の正本は [CanvasAnnotations.md](CanvasAnnotations.md) とする。

project summary resource は Chapter / Collection の `.ogp` Guide 数を `guideCount` として返す。個別 Guide の読み書き tool は提供せず、app が `guides[]` を編集する。schema と screenshot / build 除外契約は [CanvasAids.md](CanvasAids.md) を正本とする。

project summary resource は Chapter / Collection の Canvas Object Reference 配置数を `referenceCount` として返す。参照配置の読み書き tool は提供せず、app が `.ogp` の `references[]` を編集する。配置は HTML object 内へ挿入せず、build と MCP screenshot へ出力しない。schema と編集同期契約は [CanvasObjectReferences.md](CanvasObjectReferences.md) を正本とする。

## Resources

| URI | MIME | Description |
| --- | --- | --- |
| `opengraphite://contract/css` | `application/json` | `OpenGraphite.contract.json` |
| `opengraphite://project/sample` | `application/json` | sample `.ogp` の解決済み project summary |
| `opengraphite://project/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の project summary |
| `opengraphite://design-tokens/sample` | `application/json` | sample project の CSS library に保存された design tokens |
| `opengraphite://design-tokens/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の design tokens |
| `opengraphite://pages/sample` | `application/json` | sample project の pages |
| `opengraphite://pages/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の pages |
| `opengraphite://components/sample` | `application/json` | sample project の component collections |
| `opengraphite://components/current` | `application/json` | OpenGraphite.app が現在開いている `.ogp` の component collections |
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
| `list_canvas_annotations` | Chapter / Collection の注釈要約を返す | `annotation list` |
| `get_canvas_annotation` | stroke / point を含む単一注釈を返す | `annotation get` |
| `list_design_tokens` | Project CSS の `:root` design token を返す | `design-token list` |
| `set_design_token` | Project CSS の `:root` design token を設定する | `design-token set` |
| `remove_design_token` | Project CSS の `:root` design token を削除する | `design-token remove` |
| `add_project_page` | 既存 HTML を既定 Chapter の page entry として追加する | `project page add` |
| `create_project_page` | HTML を新規作成し既定 Chapter の page entry として追加する | `project page create` |
| `place_project_page` | 既存 page entry の canvas 配置を更新する | `project page place` |
| `set_project_page_document_context` | page HTML 正本の `<html>` attribute と binding metadata を更新する | `project page document` |
| `add_project_component` | 既存 HTML を Collection 内 component canvas として追加する | `project component add` |
| `create_project_component` | HTML を新規作成し Collection 内 component canvas として追加する | `project component create` |
| `place_project_component` | 既存 component canvas の配置を更新する | `project component place` |
| `set_project_component_document_context` | component HTML 正本の `<html>` attribute と binding metadata を更新する | `project component document` |
| `remove_project_component` | component canvas 登録を削除する | `project component remove` |
| `list_nodes` | page または component canvas の node graph を返す | `page graph` |
| `screenshot_canvas` | 選択 Chapter / Collection と前面注釈を PNG に保存する | `screenshot canvas` |
| `screenshot_page` | page または component canvas を PNG に保存する | `screenshot page` |
| `screenshot_node` | page または component canvas 内の node を切り抜いた PNG に保存する | `screenshot node` |
| `query_nodes` | id / type / role / tag / text で node を検索する | `node query` |
| `get_node` | `data-og-internal-id` で node を取得する | `node get` |
| `set_css_variable` | node の companion CSS declaration を設定する | `node style set` |
| `remove_css_variable` | node の companion CSS declaration を削除する | `node style remove` |
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

`list_canvas_annotations` は `chapterID` または `collectionID` のどちらか一方を必須とし、手書き point 列を展開しない要約を返す。`get_canvas_annotation.id` は raw annotation internal ID または `ogref:annotation:<pages|components>:<containerInternalID>:<annotationInternalID>` を受け取る。raw ID には `chapterID` / `collectionID` のどちらか一方が必要であり、typed ID は単独でコンテナを解決できる。typed ID と selector を併記する場合は同じ Chapter / Collection を指す必要がある。

`add_project_page.path`、`create_project_page.path`、`add_project_component.path`、`create_project_component.path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は invalid である。`add_project_component.collectionID` と `create_project_component.collectionID` は Collection ID / 内部 ID / `ogref:collection` を受け取り、省略時は先頭または既定 Collection を使う。

`create_project_page` は page 登録と初期 canvas 配置を同時に扱える。`create_project_component` は component HTML の作成と Collection 登録を行い、配置変更は `place_project_component` で行う。

`place_project_page` と `place_project_component` の `name`、`x`、`y`、`width`、`height` は任意であり、省略した値は `.ogp` 内の現在値を維持する。`name` はフロー解決用の canvas 配置名として保存され、空文字または空白だけを指定すると名前なしとして保存する。`previewMocks` は `.ogp` の canvas metadata に保存する canvas 全体の runtime Mock State であり、空文字値も有効な override として扱う。`previewPlacementMocks` は `place_project_component` のみで受け取り、component canvas 内 placement ID ごとの runtime Mock State を `previewContext.placementMocks` へ部分更新する。

component placement の状態差分は HTML 正本ではなく、`.ogp` canvas metadata の `previewContext.placementMocks` に保存する。MCP の `set_node_attribute` は `OpenGraphite.contract.json` の editable attributes だけを扱い、placement mock injection は HTML 属性として保存しない。

`set_project_page_document_context` と `set_project_component_document_context` は HTML 正本の `<html>` attribute を編集する。`langSource` は `literal` / `binding`、`dirSource` は `literal` / `auto` / `binding` を受け取る。Binding の場合も `lang` / `dir` 属性には fallback 値を残し、field 名は `data-og-lang-field` / `data-og-dir-field` metadata として保存する。

`set_text_content` は MCP / CLI 経由の source operation であり、App preview の Mock State を暗黙に推測しない。variant context が明示されていない場合は HTML fallback content を編集する。App の Canvas / preview から直接 text を編集する場合は、現在描画されている resolved text resource を対象にし、別 variant の text は Inspector から明示的に編集する。

`list_design_tokens` / `set_design_token` / `remove_design_token` は project-level CSS resource を扱うため、`pageID` / `componentID` / `id` を受け取らない。token 名は `OpenGraphite.contract.json` の `designTokens.namePattern` に一致する CSS custom property 名である必要がある。node から token を参照する場合は `set_css_variable` の `value` に `var(--token-name)` を保存する。

`remove_project_component.deleteFile` は既定で `false` である。`true` の場合のみ、`.ogp` からの登録削除に加えて component HTML file も削除する。

`build_project.outputPath` は build 出力ディレクトリである。build は Pages HTML を対象にし、component Collection の HTML、runtime script、editor-only の入力 `.ogp` manifest は公開 asset として出力しない。`.ogp` 注釈は component 展開へ使わず、生成 HTML / CSS へ付箋本文、色、stroke、annotation ID を注入しない。Canvas Object Reference も参照 clone、typed ID、frame を生成物へ注入しない。

`screenshot_canvas.chapterID` / `collectionID` は任意かつ相互排他で、表示 ID、内部 ID、`ogref:chapter` / `ogref:collection` を受け取る。両方を省略した場合は先頭 Chapter を使う。対象 Chapter の WebKit page snapshot または Collection の component snapshot と `annotations[]` を canonical world 座標で合成し、App と同じ ink、sticky note の順で注釈を前面へ描画する。Canvas Object Reference は editor viewport のため `references[]` を描画しない。全cardは有限座標と正の寸法を必須とし、出力が一辺16,384 pxまたは総33,554,432 pixel、もしくはcard snapshot累積が33,554,432 pixelの安全上限を超える場合はcaptureやbitmap確保を行わず明示エラーを返す。`screenshot_page` の `width`、`height` は任意であり、省略時は `.ogp` entry の `canvas.width`、`canvas.height` を viewport として使う。`fullPage:true` の場合は document 全体を保存する。個別 HTML を対象にする `screenshot_page` / `screenshot_node` は Chapter / Collection 注釈を含めない。

`position` は `before`、`after`、`prepend`、`append` のいずれかである。

`copy_node.idPrefix` は複製 subtree 内の全 `data-og-id` に付与される。空文字は invalid である。

## Error Handling

MCP server は `ogkiln` の exit status が non-zero の場合、tool result の `isError` を `true` にする。diagnostics の本文は `content[].text` に JSON として返す。JSON-RPC protocol error は、未知の method や未知の resource / tool など server 自体で処理できない場合だけに使う。

## Pencil Compatibility Reading

Pencil の `batch_design` は `.pen` の object tree を insert / update / delete / move / copy / replace する。OpenGraphite MCP は同じ編集意図を、`.ogp` に登録された HTML page または component canvas の element subtree と node ID による操作へ分解する。Collection 内 component master の編集は `componentID` を指定した node operation、Pages 上の instance 編集は `pageID` を指定した `<og-instance>` または展開後 DOM への操作として扱う。`get_screenshot` / `export_nodes` に相当する visual operation は、`screenshot_canvas` / `screenshot_page` / `screenshot_node` として WebKit rendering pipeline から PNG を生成する。
