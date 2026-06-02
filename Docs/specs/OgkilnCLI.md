# ogkiln CLI Specification

`ogkiln` は OpenGraphite project (`.ogp`) を headless に inspection / validation / edit する CLI である。HTML は正本だが、CLI の編集対象は常に `.ogp` の `chapters[].pages[]` または top-level `components[]` に明示された HTML だけに限定する。

## Principles

- `.ogp` は編集対象資源の可視リストであり、`ogkiln` は `.ogp` を経由しない HTML 書き込みを行わない。
- `projectPath` には `.ogp` path または `current` を指定できる。`current` は OpenGraphite.app が現在開いている `.ogp` を Application Support のレコードから解決する。
- `.ogp` にない既存 HTML を編集したい場合は、先に `project page add` または `project component add` で可視リストに追加する。
- 新規 HTML を配置したい場合は、`project page create` または `project component create` で HTML 作成と `.ogp` 登録を一体で行う。
- page は `--page-id`、component は `--component-id`、node は `--id` で指定する。コピーされた参照 ID は `ogref:<type>:...` 形式で、`ogref:node` / `ogref:component-node` を `--id` に渡した場合は対象 page / component canvas もそこから解決できる。raw `data-og-internal-id` を使う node edit 系コマンドは `--page-id` と `--component-id` のどちらも受け付けるが、同時指定は invalid である。
- write operation は書き込み前に candidate HTML を validation し、`error` diagnostic がある場合はファイルを書き換えない。
- runtime state は正本 HTML から取り除く。対象は `OpenGraphite.contract.json` の `runtimeAttributes` と `editable:false` の `--og-*` CSS variables。
- 出力は JSON を基本とし、MCP server はこの JSON をそのまま tool result として返せる。

## Project Commands

```bash
ogkiln contract get --json
ogkiln project current --json
ogkiln project inspect <project.ogp|current> --json
ogkiln validate <project.ogp|current> --json
ogkiln build <project.ogp|current> --output <dir>
```

`project current` は OpenGraphite.app が最後に開いた `.ogp` の summary を返す。アプリを介さず CLI だけで作業する場合は明示的な `.ogp` path を指定する。

`build` は Pages HTML 内の `<og-instance data-og-component>` を Components HTML の `data-og-component-kind="master"` subtree で展開し、指定出力ディレクトリへ静的 HTML を生成する。Components セグメントの HTML と runtime script は公開 page として出力せず、OpenGraphite.css と `htmlRoot` 配下の非HTML静的 asset は出力先へコピーする。Pages HTML の OpenGraphite.css 参照は、出力先内の CSS を指す相対 path へ書き換える。

## Page Management

```bash
ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page place <project.ogp|current> --page-id <page-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>]
```

`--path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は受け付けない。これにより、ユーザーが `.ogp` で認知できない資源が編集対象になることを避ける。

`project page add` は既存 HTML を `.ogp` の既定 Chapter `pages[]` に追加する。`project page create` は HTML ファイルを作成してから同じ操作内で既定 Chapter `pages[]` に登録する。`canvas` は `--x`、`--y`、`--width`、`--height` で指定し、省略時は `0,0,1440,1200` になる。`project page place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。

## Component Management

```bash
ogkiln project component add <project.ogp|current> --component-id <component-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project component create <project.ogp|current> --component-id <component-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component create <project.ogp|current> --component-id <component-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component place <project.ogp|current> --component-id <component-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project component remove <project.ogp|current> --component-id <component-id> [--delete-file]
```

Components は component master を置く asset canvas として扱う。`project component add/create/place/remove` は `.ogp` の top-level `components[]` を更新し、node edit 系コマンドは `--component-id` で Components HTML を直接編集できる。`canvas` の省略値は `0,0,960,900` である。`project component place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。`remove` は既定では `.ogp` の登録だけを削除し、`--delete-file` を付けた場合のみ HTML file も削除する。

## Read Commands

```bash
ogkiln page graph <project.ogp|current> --page-id <page-id>|--component-id <component-id> --json
ogkiln node query <project.ogp|current> --page-id <page-id>|--component-id <component-id> [filters] --json
ogkiln node get <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <node-id|ogref-node-id> --json
```

`node query` filters:

- `--id-contains <text>`
- `--type <data-og-type>`
- `--role <data-og-role>`
- `--tag <tag-name>`
- `--text-contains <text>`

## Screenshot Commands

```bash
ogkiln screenshot canvas <project.ogp|current> --output <png>
ogkiln screenshot page <project.ogp|current> --page-id <page-id>|--component-id <component-id> --output <png> [--width <n>] [--height <n>] [--full-page]
ogkiln screenshot node <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <node-id|ogref-node-id> --output <png> [--width <n>] [--height <n>] [--padding <n>]
```

`screenshot canvas` は `.ogp` の先頭 Chapter の `pages[].canvas` 配置に従って各ページを WebKit でレンダリングし、キャンバス全体を 1 枚の PNG に合成する。

`screenshot page` は指定 page entry の `canvas.width` / `canvas.height` を既定 viewport として PNG を生成する。`--width` / `--height` を指定すると viewport を上書きできる。`--full-page` を付けると document 全体の scroll size に合わせて保存する。

`node-id` は `data-og-internal-id` または `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<componentInternalID>:<nodeInternalID>` を指定する。typed node 参照を使う場合、`--page-id` / `--component-id` は省略できる。`screenshot node` は指定 page 内の対象 node を WebKit でレンダリングし、`getBoundingClientRect()` に基づく範囲を切り抜く。`--padding` は切り抜き範囲へ加える余白であり、省略時は `0` である。

## Update Commands

```bash
ogkiln node style set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --var <--og-var> --value <css-value>
ogkiln node style remove <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --var <--og-var>
ogkiln node attr set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --name <data-og-attr> --value <value>
ogkiln node attr remove <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --name <data-og-attr>
ogkiln node text set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --value <text>
ogkiln node text set <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --text-file <text-file>
```

`node style set/remove` は `--og-*` だけを扱う。`node attr set/remove` は `OpenGraphite.contract.json` の `editableAttributes` に含まれる属性だけを扱い、`data-og-internal-id` は変更しない。

`node text set` は text として保存する。HTML 断片を入れる操作ではないため、`<`、`>`、`&` は escape する。

## Structure Commands

```bash
ogkiln node html insert <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <anchor-id> --position <before|after|prepend|append> --html <fragment-html>
ogkiln node html insert <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <anchor-id> --position <before|after|prepend|append> --html-file <fragment.html>
ogkiln node html replace <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --html <replacement-html>
ogkiln node html replace <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id> --html-file <replacement.html>
ogkiln node delete <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <id>
ogkiln node move <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <source-id> --target <target-id> --position <before|after|prepend|append>
ogkiln node copy <project.ogp|current> [--page-id <page-id>|--component-id <component-id>] --id <source-id> --target <target-id> --position <before|after|prepend|append> --id-prefix <prefix>
```

`position` の意味:

- `before`: anchor / target node の直前。
- `after`: anchor / target node の直後。
- `prepend`: anchor / target node の最初の子。
- `append`: anchor / target node の最後の子。

`node copy` は複製 subtree 内の全 `data-og-id` に `--id-prefix` を付与する。例えば `--id-prefix copy-` で `card` と `title` を含む subtree を複製すると、`copy-card` と `copy-title` になる。

## JSON Result Contracts

Read operation は `schemaVersion`、対象 path / URL、node list、diagnostics を返す。write operation は次の形を返す。

```json
{
  "schemaVersion": "0.1",
  "updated": true,
  "path": "/repo/public/index.html",
  "node": {
    "id": "hero",
    "tagName": "herosection",
    "type": "frame"
  },
  "diagnostics": [],
  "insertedNodes": []
}
```

`updated:false` かつ `diagnostics[].severity == "error"` の場合、ファイルは変更されていない。
