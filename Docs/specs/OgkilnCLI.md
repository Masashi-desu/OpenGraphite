# ogkiln CLI Specification

`ogkiln` は OpenGraphite project (`.ogp`) を headless に inspection / validation / edit する CLI である。HTML は正本だが、CLI の編集対象は常に `.ogp` の `chapters[].pages[]` に明示された HTML だけに限定する。

## Principles

- `.ogp` は編集対象資源の可視リストであり、`ogkiln` は `.ogp` を経由しない HTML 書き込みを行わない。
- `projectPath` には `.ogp` path または `current` を指定できる。`current` は OpenGraphite.app が現在開いている `.ogp` を Application Support のレコードから解決する。
- `.ogp` にない既存 HTML を編集したい場合は、先に `project page add` で既定 Chapter の `pages[]` に追加する。
- 新規 HTML を配置したい場合は、`project page create` で HTML 作成と既定 Chapter の `pages[]` 追加を一体で行う。
- page は `--page-id`、node は `--id` で指定する。
- write operation は書き込み前に candidate HTML を validation し、`error` diagnostic がある場合はファイルを書き換えない。
- runtime state は正本 HTML から取り除く。対象は `OpenGraphite.contract.json` の `runtimeAttributes` と `editable:false` の `--og-*` CSS variables。
- 出力は JSON を基本とし、MCP server はこの JSON をそのまま tool result として返せる。

## Project Commands

```bash
ogkiln contract get --json
ogkiln project current --json
ogkiln project inspect <project.ogp|current> --json
ogkiln validate <project.ogp|current> --json
```

`project current` は OpenGraphite.app が最後に開いた `.ogp` の summary を返す。アプリを介さず CLI だけで作業する場合は明示的な `.ogp` path を指定する。

## Page Management

```bash
ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page place <project.ogp|current> --page-id <page-id> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
```

`--path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は受け付けない。これにより、ユーザーが `.ogp` で認知できない資源が編集対象になることを避ける。

`project page add` は既存 HTML を `.ogp` の既定 Chapter `pages[]` に追加する。`project page create` は HTML ファイルを作成してから同じ操作内で既定 Chapter `pages[]` に登録する。`canvas` は `--x`、`--y`、`--width`、`--height` で指定し、省略時は `0,0,1440,1200` になる。

## Read Commands

```bash
ogkiln page graph <project.ogp|current> --page-id <page-id> --json
ogkiln node query <project.ogp|current> --page-id <page-id> [filters] --json
ogkiln node get <project.ogp|current> --page-id <page-id> --id <data-og-id> --json
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
ogkiln screenshot page <project.ogp|current> --page-id <page-id> --output <png> [--width <n>] [--height <n>] [--full-page]
ogkiln screenshot node <project.ogp|current> --page-id <page-id> --id <data-og-id> --output <png> [--width <n>] [--height <n>] [--padding <n>]
```

`screenshot canvas` は `.ogp` の先頭 Chapter の `pages[].canvas` 配置に従って各ページを WebKit でレンダリングし、キャンバス全体を 1 枚の PNG に合成する。

`screenshot page` は指定 page entry の `canvas.width` / `canvas.height` を既定 viewport として PNG を生成する。`--width` / `--height` を指定すると viewport を上書きできる。`--full-page` を付けると document 全体の scroll size に合わせて保存する。

`screenshot node` は指定 page 内の `[data-og-id="<id>"]` を WebKit でレンダリングし、`getBoundingClientRect()` に基づく範囲を切り抜く。`--padding` は切り抜き範囲へ加える余白であり、省略時は `0` である。

## Update Commands

```bash
ogkiln node style set <project.ogp|current> --page-id <page-id> --id <id> --var <--og-var> --value <css-value>
ogkiln node style remove <project.ogp|current> --page-id <page-id> --id <id> --var <--og-var>
ogkiln node attr set <project.ogp|current> --page-id <page-id> --id <id> --name <data-og-attr> --value <value>
ogkiln node attr remove <project.ogp|current> --page-id <page-id> --id <id> --name <data-og-attr>
ogkiln node text set <project.ogp|current> --page-id <page-id> --id <id> --value <text>
ogkiln node text set <project.ogp|current> --page-id <page-id> --id <id> --text-file <text-file>
```

`node style set/remove` は `--og-*` だけを扱う。`node attr set/remove` は `OpenGraphite.contract.json` の `editableAttributes` に含まれる属性だけを扱い、`data-og-id` は変更しない。

`node text set` は text として保存する。HTML 断片を入れる操作ではないため、`<`、`>`、`&` は escape する。

## Structure Commands

```bash
ogkiln node html insert <project.ogp|current> --page-id <page-id> --id <anchor-id> --position <before|after|prepend|append> --html <fragment-html>
ogkiln node html insert <project.ogp|current> --page-id <page-id> --id <anchor-id> --position <before|after|prepend|append> --html-file <fragment.html>
ogkiln node html replace <project.ogp|current> --page-id <page-id> --id <id> --html <replacement-html>
ogkiln node html replace <project.ogp|current> --page-id <page-id> --id <id> --html-file <replacement.html>
ogkiln node delete <project.ogp|current> --page-id <page-id> --id <id>
ogkiln node move <project.ogp|current> --page-id <page-id> --id <source-id> --target <target-id> --position <before|after|prepend|append>
ogkiln node copy <project.ogp|current> --page-id <page-id> --id <source-id> --target <target-id> --position <before|after|prepend|append> --id-prefix <prefix>
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
