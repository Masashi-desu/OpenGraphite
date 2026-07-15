# OpenGraphite Canvas Annotation Specification

この文書は、OpenGraphite のキャンバス前面へ配置する付箋と手書き注釈の正本仕様です。注釈はデザイン成果物ではなく、利用者のメモ、レビュー資料、AI へ渡すマルチモーダル指示として扱います。永続化先は `.ogp` だけであり、HTML、companion CSS、`OpenGraphite.css` の内容やブラウザ表示には影響させません。

## Scope

キャンバス注釈は次の 2 種類を扱います。

- `stickyNote`: プレーンテキスト、背景色、文字色を持つ付箋。
- `ink`: マウスまたはスタイラスから得た点列、筆圧、傾き、線色、基準線幅を持つ手書き。

注釈は個別 page / component HTML の一部ではありません。Pages セグメントでは Chapter 全体、Components セグメントでは Collection 全体に属し、そのグループの page / component card より前面へ重ねて表示します。

## Source Of Truth And Ownership

注釈の正本は `.ogp` の次の配列です。

- Pages キャンバス: `chapters[].annotations[]`
- Components キャンバス: `collections[].annotations[]`

`chapters[].pages[].canvas` と `collections[].components[].canvas` は各 HTML card の配置を担い、注釈本体は保持しません。注釈を page / component ごとに複製したり、DOM node、`data-og-*`、companion CSS rule として保存したりしてはいけません。

配列が存在しない既存 `.ogp` は空配列として読み込みます。空の `annotations` は保存時に省略できます。

## JSON Schema

### Sticky Note

```json
{
  "internalID": "note-alpha",
  "kind": "stickyNote",
  "frame": { "x": 40, "y": 60, "width": 240, "height": 160 },
  "text": "リリース前に確認",
  "backgroundColor": "#FFE88A",
  "textColor": "#231F14"
}
```

### Ink

```json
{
  "internalID": "ink-beta",
  "kind": "ink",
  "frame": { "x": 320, "y": 80, "width": 90, "height": 48 },
  "strokes": [
    {
      "points": [
        { "x": 0, "y": 1, "pressure": 0.4, "tiltX": 0.1, "tiltY": -0.1 },
        { "x": 36, "y": 24, "pressure": 0.75, "tiltX": 0.2, "tiltY": -0.2 }
      ],
      "color": "#FF4D67",
      "lineWidth": 3.5,
      "inputDevice": "pen"
    }
  ]
}
```

共通フィールド:

- `internalID`: project 内で一意な不透明 ID。表示文言や配列位置を識別子として使わない。空または重複する ID は、新しい OpenGraphite が project 正規化時に一意な値へ補完する。
- `kind`: `stickyNote` または `ink`。
- `frame`: Chapter / Collection の canonical world 座標における注釈の外接矩形。`x` / `y` は `-1,000,000...1,000,000`、`width` / `height` は `1...1,000,000` に正規化する。

`stickyNote` 固有フィールド:

- `text`: 付箋のプレーンテキスト。HTML として解釈しない。
- `backgroundColor`: 付箋背景色。既定値は `#FFE88A`。
- `textColor`: 付箋文字色。既定値は `#231F14`。

`ink` 固有フィールド:

- `strokes`: 手書きストローク配列。
- `points`: 注釈 `frame` の左上を原点とする点列。各 X / Y は `-1,000,000...1,000,000` に正規化する。
- `pressure`: 0 から 1 へ正規化した筆圧。未指定時は 1。
- `tiltX` / `tiltY`: AppKit tablet event から得た傾き成分。`-1...1` に正規化し、未指定時は 0。
- `color`: 線色。既定値は `#FF4D67`。
- `lineWidth`: 筆圧を適用する前の基準線幅。`0.5...10,000` に正規化し、既定値は 3.5。
- `inputDevice`: `mouse`、`pen`、`eraser`、`unknown`。Sidecar の Apple Pencil は `pen` として保存する。

保存時は種別固有 payload だけを出力します。`stickyNote` に `strokes` を、`ink` に `text` / `backgroundColor` / `textColor` を書き出しません。

## Canonical World Coordinates

Chapter / Collection のキャンバスは左上原点です。X は右方向、Y は下方向へ増え、page / component の `canvas.x` / `canvas.y` と注釈の `frame.x` / `frame.y` は同じ world 座標系を共有します。キャンバス左上より外側へ置けるため、負の座標も有効です。

注釈 `frame` は world 座標、ink の各 point は frame-local 座標です。点の world 座標は次で求めます。

```text
worldX = annotation.frame.x + point.x
worldY = annotation.frame.y + point.y
```

pan、zoom、ウィンドウ位置、SwiftUI の local 座標、page title card の表示オフセットは表示上の変換にすぎず、`.ogp` へ保存しません。入力時は表示 local 座標を canonical world 座標へ戻し、描画時は world 座標から現在の Canvas local 座標へ変換します。

## Front Layer Rendering

OpenGraphite app は HTML / CSS を描画する `WKWebView` card 群の前面に、Chapter / Collection 単位の annotation layer を重ねます。注釈は WebView DOM に挿入せず、Layers の HTML node graph にも含めません。

この前面レイヤーは次のツール入力を受けます。

- Select: 付箋または手書きの実線を一件選択し、移動、削除、typed reference のコピーを行う。
- Sticky Note: クリックした world 座標へテキスト編集可能な付箋を追加する。
- Pen: マウスまたは Sidecar の Apple Pencil で手書きを追加する。
- Eraser: マウスまたは Sidecar の Apple Pencil で、丸端の消しゴム軌跡に触れた手書きの可視部分だけを消去する。付箋と HTML card は削除しない。
- Lasso: 自由曲線を閉じた多角形として扱い、交差する付箋と手書きを複数選択する。

Lasso は付箋を表示矩形、手書きを保存済みの実点・実線分と筆圧込みの表示線幅で判定します。手書きの外接矩形に空白が含まれていても、表示される実線と交差しない限り選択しません。自己交差する自由曲線も、3点以上の非共線な閉多角形として奇偶規則で扱いますが、クリック時の微小な手ぶれは選択操作として受理しません。複数選択状態は editor の一時状態であり `.ogp` へ保存しません。選択集合の移動または削除を実行したときだけ、対象 Chapter / Collection の `annotations` を一度の atomic write で更新します。選択集合の typed reference は Canvas 配列順の改行区切りでコピーできます。

付箋の入力中本文は manifest cache から分離した draft overlay として即時表示し、移動、追加、削除など別の注釈操作の保存値や履歴境界へ混ぜません。注釈を確定するたびに最新 `.ogp` を再読込し、対象 Chapter / Collection の変更だけを最新 manifest へ rebase して atomic write します。CLI などによる project metadata、page / component、別の注釈の更新は保持し、入力開始後に同じ付箋本文が外部変更されていた場合は local draft で上書きせず保存を中止して最新値へ同期します。

## Undo And Redo

注釈の追加、付箋本文の確定、移動、リサイズ、部分消去、全消去、削除は、既存の「取り消す」`⌘Z` と「やり直す」`⇧⌘Z` の対象です。HTML編集、注釈編集、Guide編集は同じ時系列 operation timeline へ積み、操作種別にかかわらず最後に確定した操作から順に適用します。なげわによる選択そのものは一時的な editor 状態なので履歴へ積まず、選択集合を移動または削除して `.ogp` を atomic write した単位を一操作として記録します。消しゴムは drag 中の各 sample ではなく、pen-up で確定した一回の gesture 全体を一履歴単位とします。Guide 履歴の詳細は [CanvasAids.md](CanvasAids.md) を正本とします。

履歴はproject URL、対象 Chapter / Collection、変更前後の `annotations` 配列を保持します。undo/redo 直前に対象 `.ogp` の最新manifestを再読込し、対象配列が履歴の期待する現在値と一致する場合だけ、その最新manifestへ履歴値をrebaseしてatomic writeします。外部変更と競合する場合は古いsnapshotで上書きせず、履歴適用を中止して最新manifestを表示へ同期します。HTML、companion CSS、runtime、ほかの Chapter / Collection、project metadata は巻き戻しません。

付箋本文は入力中の app cache ではなく、debounce または編集終了で `.ogp` へ確定した本文を履歴境界にします。ただしTextEditorがfirst responderで未確定入力を持つ間の `⌘Z` / `⇧⌘Z` は、editor全体の履歴より先にnative text undo managerへ渡します。履歴や外部同期によるcanonical本文変更はfocus中でも未確定保存をcancelし、表示中draftへ反映します。

新しいHTML、注釈、Guide操作を確定した場合は種別をまたいでredo分岐を破棄し、projectを開き直した場合はそのeditor sessionの履歴を初期化します。非表示projectへ遅延確定した付箋本文を、現在projectの履歴へ混入させてはいけません。履歴適用後は、存在しなくなった注釈IDだけを選択集合から除外します。

## Sidecar And Tablet Events

Sidecar で接続した iPad 上の Apple Pencil 入力は、macOS が OpenGraphite の AppKit view へ配送する `NSEvent` tablet event として受けます。OpenGraphite が iPad と独自通信することはありません。

入力レイヤーは次の経路を扱います。

- `mouseDown` / `mouseDragged` / `mouseUp`: mouse fallback と、mouse event の tablet subtype として届く Pencil 入力。
- `tabletPoint`: 筆圧と傾きを持つ tablet sample。
- `tabletProximity`: `pen` / `eraser` / `cursor` のデバイス追跡。
- `changeMode`: Apple Pencil の mode change を pen と部分消去 eraser の切替として扱う。

Pencil sample は `NSEvent.pressure` を 0...1 に clamp し、tablet point の `NSEvent.tilt` を `tiltX` / `tiltY` へ保存します。同時刻・同位置・同一 device ID で mouse subtype と `tabletPoint` の両方から届いた sample は重複除去します。proximity 情報は `NSEvent.deviceID` ごとに保持し、pen-down の device ID と異なる native tablet sample を同じ stroke へ混在させません。event 自身が tablet point / tablet subtype ではない通常 mouse は、Pencil が proximity 内でも常に `inputDevice: "mouse"`、`pressure: 1` として記録します。

eraser は GoodNotes と同様の部分消去として扱います。消しゴム径は筆圧に依存しない画面上 8 pt 固定とし、現在の zoom に応じて world 座標上の径へ変換します。判定には不可視の余白や追加 tolerance を設けず、丸端の消しゴム軌跡と保存済み stroke の筆圧込みの可視 ink が重なる部分だけを取り除きます。線の中央を横切った場合は、消去されずに残った前後を同じ ink annotation、同じ `internalID` 内の別 fragment として分割し、全 fragment がなくなった場合だけ annotation 自体を削除します。生成する切断境界は座標と傾きを線形補間し、筆圧は消去前 segment の実描画幅が残線上で変化しない値へ補正します。frame と frame-local payload は小数3桁へ正規化します。1回の gesture が複数の ink annotation と重なった場合は、最前面の1件に限定せず重なった全 ink を同じ規則で部分消去します。

独立した Eraser tool と Pen tool 中の Pencil mode change / eraser 入力は同じ径、判定、分割規則を使います。Sidecar の高頻度入力は画面上 0.75 pt 間隔で空間的に整え、最大 60 Hz の区間ごとに、その間の point 列をメモリ上の結果へ累積して preview します。これにより高速な折り返しの形を保ちながら全履歴の再計算を避けます。pen-up 時は未反映区間をflushしたうえでpreviewを再計算せず、対象 Chapter / Collection の `annotations` を1回の atomic write で `.ogp` へ保存します。保存直前には最新 `.ogp` を再読込し、今回消す ink が gesture 開始時から変わっていない場合だけ最新 manifest へ結果を統合します。CLI などが同じ ink を先に更新または削除していた場合は古い preview の保存を中止して外部変更を表示へ同期し、別の注釈や project metadata だけが更新されていた場合はその外部変更を保持します。外接矩形内で可視 ink から離れた空白だけをなぞった場合は変更せず、付箋、HTML card、HTML、CSS には作用しません。

## CLI And MCP Access

注釈の agent interface は読み取り専用です。書き換えは OpenGraphite app の Canvas 操作が担います。

```bash
ogkiln annotation list <project.ogp|current> --chapter-id <chapter-id> --json
ogkiln annotation list <project.ogp|current> --collection-id <collection-id> --json
ogkiln annotation get <project.ogp|current> --chapter-id <chapter-id> --id <annotation-internal-id> --json
ogkiln annotation get <project.ogp|current> --id ogref:annotation:<pages|components>:<container-internal-id>:<annotation-internal-id> --json
```

`annotation list` は `--chapter-id` または `--collection-id` のどちらか一方を必須とし、点列を展開しない `frame`、付箋本文、色、`strokeCount`、`pointCount` を返します。`annotation get` は raw `internalID` の場合にコンテナ selector を必要とし、typed annotation reference の場合は selector を省略して完全な stroke / point payload を取得できます。

typed reference は次の形式です。

```text
ogref:annotation:pages:<chapterInternalID>:<annotationInternalID>
ogref:annotation:components:<collectionInternalID>:<annotationInternalID>
```

`project inspect` の Chapter / Collection summary は `annotationCount` を返します。

MCP は同じ `ogkiln` 経路を次の tool として公開します。

- `list_canvas_annotations` → `annotation list`
- `get_canvas_annotation` → `annotation get`

MCP の `chapterID` / `collectionID` 排他規則、raw / typed ID の解決規則、JSON payload は CLI と同一です。

## Screenshots

```bash
ogkiln screenshot canvas <project.ogp|current> --output <png> [--chapter-id <chapter-id>|--collection-id <collection-id>]
```

`ogkiln screenshot canvas` と MCP の `screenshot_canvas` は、`--chapter-id` / `chapterID` または `--collection-id` / `collectionID` のどちらか一方で Chapter / Collection を選択できます。selector は表示 ID、内部 ID、`ogref:chapter` / `ogref:collection` を受け付け、両方の同時指定は invalid です。どちらも省略した場合は先頭 Chapter を対象にします。

WebKit で描画した対象 Chapter の page card または Collection の component card を world 座標へ配置した後、同じコンテナの付箋と ink を前面へ合成します。出力 bounds は card frame と annotation frame の union であり、card がなく注釈だけの Chapter / Collection も PNG にできます。

canvas PNG はappと同じく、page / component card、全ink、全付箋の順で合成します。`inputDevice` は入力由来metadataであり、`eraser` を含む保存済みink strokeもほかのstrokeと同じように描画します。全 card は有限座標と正の寸法を必須とし、boundsが一辺16,384 pxまたは総33,554,432 pixelを超える場合、およびWebKit card snapshotの累積が33,554,432 pixelを超える場合はcaptureやbitmap確保を試みず、CLI / MCPへ明示エラーを返します。

`screenshot page` / `screenshot node` は個別 HTML source の画像であり、Chapter / Collection 全体に属する注釈を含めません。マルチモーダル指示として HTML と注釈を同時に渡す場合は `screenshot canvas` を使います。

## HTML, CSS, Runtime, And Build Isolation

注釈の追加、編集、移動、削除は `.ogp` だけを更新し、対象 HTML、同名 companion CSS、`OpenGraphite.css`、locale resource、runtime script の byte 列を変更しません。

ブラウザで直接開く HTML と runtime 展開結果には注釈を表示しません。`ogkiln build` も annotation payload を component 展開や asset 生成の入力に使わず、入力 `.ogp` manifest 自体を公開 asset としてコピーせず、生成 HTML / CSS へ付箋本文、色、stroke、annotation ID を注入しません。同じ Web source からは、注釈の有無にかかわらず同じ公開 HTML / CSS が生成されます。

`OpenGraphite.contract.json` は HTML / CSS 編集契約であるため、`.ogp` 専用 annotation schema を追加しません。

## Compatibility

新しい OpenGraphite は `annotations` key がない既存 `.ogp` を空の注釈配列として読み込めます。種別固有の任意フィールドがない場合は既定値を補い、空配列は保存時に省略するため、注釈を使わない project の JSON 差分を増やしません。

注釈対応前の OpenGraphite は、JSON decoder が未知の `annotations` key を無視して project を開ける場合があります。ただし、その旧 app が `.ogp` を再保存すると、認識できない annotation payload を保持せず削除する可能性があります。注釈を含む project は対応版で編集し、旧版で開く必要がある場合は再保存せず、事前に version control またはファイルコピーで `.ogp` を保護してください。

## Manual Sidecar Acceptance

自動テストは schema、座標変換、筆圧線幅、永続化、CLI/MCP、PNG 合成を検証できますが、Sidecar と実機 Apple Pencil の event delivery は検証できません。リリース前に対応 Mac / iPad / Apple Pencil を使い、少なくとも次を手動確認します。

1. iPad を Sidecar で接続し、iPad 側に表示した OpenGraphite で Pen tool を選ぶ。
2. Chapter と Collection の各 Canvas で Pencil 描画が pointer 移動ではなく ink として追従し、pen-up 後も残る。
3. 強弱を付けた線で描画幅が変わり、Pencil を傾けた sample を `annotation get` すると `inputDevice: "pen"`、0...1 の `pressure`、`tiltX` / `tiltY` が得られる。
4. Pen tool の mode change または eraser 入力が Eraser tool と同じ部分消去として働き、付箋や HTML card を誤って削除しない。Pencil を proximity 内に置いたまま Mac の mouse / trackpad で Pen tool を使った場合は `inputDevice: "mouse"` になり、eraser mode 中でも既存 ink を削除しない。
5. Eraser tool を Mac の mouse / trackpad と Sidecar の Pencil の両方で使い、筆圧や zoom を変えても画面上 8 pt の丸端軌跡で、不可視余白を伴わず可視 ink に触れた部分だけが消える。線の中央を横切ると同じ annotation / `internalID` 内の前後 fragment に分かれ、重なった複数 ink はすべて部分消去され、全消去した ink だけ annotation 自体が削除される。drag 中は結果が preview され、pen-up で `.ogp` が1回だけ保存される一方、実線から離れた外接矩形内の空白、付箋、HTML card は保持する。
6. Lasso tool で複数の付箋と手書きを囲み、選択枠が表示され、Select tool へ切り替えた後も選択全体を同じ差分で移動・削除できる。手書きの外接矩形内の空白だけを囲んだ場合は選択しない。
7. `.ogp` を閉じて開き直しても注釈が同じ world 位置に残り、pan / zoom 後にも page / component card との相対位置が変わらない。
8. `annotation list|get` と `screenshot canvas` で同じ内容を確認できる。
9. 操作前後の HTML / CSS が変更されず、`ogkiln build` の公開 HTML / CSS に注釈内容が現れない。
10. 付箋の追加・本文編集・移動・削除、手書き追加、消しゴムによる部分消去をそれぞれ `⌘Z` で戻し、`⇧⌘Z` で同じ `.ogp` 状態へ進められる。消しゴムの一筆は途中の sample 数によらず一回で戻る。

OS、Sidecar、Apple Pencil の設定によって pressure / tilt / mode-change event の配送差があるため、未配送の場合は OpenGraphite の保存値だけでなく macOS の Sidecar 接続状態と Pencil 設定も切り分けます。
