# ogkiln CLI Specification

`ogkiln` は OpenGraphite project (`.ogp`) を headless に inspection / validation / edit する CLI である。HTML は正本だが、CLI の編集対象は常に `.ogp` の `chapters[].pages[]` または `collections[].components[]` に明示された HTML だけに限定する。

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

`build` は Pages HTML 内の `<og-instance data-og-component>` を Collection 内 component HTML の `data-og-component-kind="master"` subtree で展開し、指定出力ディレクトリへ静的 HTML を生成する。component Collection の HTML と runtime script は公開 page として出力せず、OpenGraphite.css と `htmlRoot` 配下の非HTML静的 asset は出力先へコピーする。Pages HTML の OpenGraphite.css 参照は、出力先内の CSS を指す相対 path へ書き換える。

## Page Management

```bash
ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project page place <project.ogp|current> --page-id <page-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>]
ogkiln project page document <project.ogp|current> --page-id <page-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
```

`--path` は `.ogp` の `htmlRoot` から見た相対 HTML path であり、絶対 path、`..`、HTML 以外の拡張子は受け付けない。これにより、ユーザーが `.ogp` で認知できない資源が編集対象になることを避ける。

`project page add` は既存 HTML を `.ogp` の既定 Chapter `pages[]` に追加する。通常は同じ HTML path の重複登録を拒否するが、同じ正本 HTML を別 preview context で並べたい場合だけ `--allow-duplicate-path` を指定できる。`project page create` は HTML ファイルを作成してから同じ操作内で既定 Chapter `pages[]` に登録する。`canvas` は `--x`、`--y`、`--width`、`--height` で指定し、省略時は `0,0,1440,1200` になる。`project page place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。`--preview-mock key=value` は実装が参照する任意の runtime Mock State を `.ogp` の canvas metadata へ保存する。空文字 override は `--preview-mock key=` と指定する。

`project page document` は HTML 正本の `<html>` attribute と OpenGraphite metadata を更新する。`--lang-source literal` は `lang` を literal 値として保存し、`--lang-source binding` は `lang` に fallback 値を残したまま `data-og-lang-source="binding"` と `data-og-lang-field` を保存する。`--dir-source literal` は `dir` を literal 値として保存し、`--dir-source auto` は `data-og-dir-source="auto"` を保存して preview/runtime で resolved lang から `ltr` / `rtl` を推定する。`--dir-source binding` は `dir` に fallback 値を残し、`data-og-dir-field` を保存する。変数名を `lang` / `dir` 属性へ直接保存してはならない。

## Component Management

```bash
ogkiln project component add <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
ogkiln project component place <project.ogp|current> --component-id <component-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>]
ogkiln project component document <project.ogp|current> --component-id <component-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
ogkiln project component remove <project.ogp|current> --component-id <component-id> [--delete-file]
```

Components は Collection ごとに component master を置く asset canvas として扱う。`project component add/create` は `.ogp` の `collections[].components[]` を更新し、`--collection-id` で登録先 Collection を指定できる。未指定時は先頭または既定 Collection を使う。node edit 系コマンドは `--component-id` で Components HTML を直接編集できる。`canvas` の省略値は `0,0,960,900` である。`project component place` の `--name` はフロー解決用の canvas 配置名を更新し、省略時は既存値を維持する。空文字または空白だけを指定すると名前なしとして保存する。`--preview-mock key=value` は runtime Mock State を更新する。空文字 override は `--preview-mock key=` と指定する。`project component document` は page と同じルールで component HTML 正本の document attribute と metadata を更新する。`remove` は既定では `.ogp` の登録だけを削除し、`--delete-file` を付けた場合のみ HTML file も削除する。

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

`node-id` は `data-og-internal-id` または `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` / `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>` を指定する。typed node 参照を使う場合、`--page-id` / `--component-id` は省略できる。`screenshot node` は指定 page 内の対象 node を WebKit でレンダリングし、`getBoundingClientRect()` に基づく範囲を切り抜く。`--padding` は切り抜き範囲へ加える余白であり、省略時は `0` である。

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

`node text set` は CLI の headless source operation であり、App preview の Mock State を暗黙に推測しない。variant context が明示されていない場合、対象は HTML fallback content である。App の Canvas / preview からの直接編集は、現在描画されている resolved text resource を編集対象にし、非 active variant は Inspector から明示的に編集する。

`text variant set` は `data-i18n-key` で text binding を指定し、`--locale eng` の場合は `data-og-text-variant-eng` を保存する。node id を持たない slot 用 text も対象にできる。これは HTML 同梱 fallback / sample 用の互換操作であり、推奨の locale text 正本は `i18n resource set` が更新する locale JSON である。Mock State は保存先ではなく、preview/runtime がどの resource を解決するかを決める入力である。

## I18n Runtime Commands

```bash
ogkiln i18n inspect <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales ja,eng] --json
ogkiln i18n recommend <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales ja,eng]
ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <data-i18n-key> --value <text>
ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <data-i18n-key> --text-file <text-file>
```

`i18n inspect` は page HTML の `script` / `type="module"` script と辿れる import から `i18n.init({...})` を検出する。検出対象は `lng`、`fallbackLng`、`backend.loadPath` である。`loadPath: "/locales/{{lng}}.json"` のような literal は editable として返し、`loadPath: import.meta.env.VITE_I18N_LOAD_PATH` のような env / dynamic expression は external / readonly として返す。

`i18n recommend` は自動検出できない page に推奨 runtime を挿入し、`public/locales/<locale>.json` を作成・更新する。推奨 loadPath は `/locales/{{lng}}.json`、resource は flat key JSON である。`.ogp` は i18n 設定の正本にならず、preview Mock State と canvas 配置だけを保持する。

`i18n resource set` は検出済み literal loadPath または推奨 loadPath から locale JSON を解決し、flat key の値を書き戻す。external loadPath の場合は OpenGraphite が env / dynamic expression を勝手に書き換えないため readonly error を返す。

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
