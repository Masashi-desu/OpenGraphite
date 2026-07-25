# Canvas Object References

## Purpose

Canvas Object Reference は、project 内の page / component HTML にある任意階層の OpenGraphite node を、別の Chapter / Collection キャンバス直下へ編集可能な参照として配置する機能である。参照表示は新しい HTML subtree や component instance を作らず、元 node の正本 HTML / companion CSS を表示・編集する別 viewport として扱う。

## Source of Truth

配置情報は `.ogp` の選択中 container に保存する。

- Pages canvas: `chapters[].references[]`
- Components canvas: `collections[].references[]`

```json
{
  "references": [
    {
      "internalID": "4s7m2p9xk1",
      "referenceID": "ogref:component-node:collection-internal-id:component-internal-id:node-internal-id",
      "x": 640,
      "y": 320,
      "width": 360,
      "height": 240
    }
  ]
}
```

各 field の契約は次のとおりである。

- `internalID`: `.ogp` 内で配置自体を一意に識別する不透明 ID。
- `referenceID`: `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` または `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>`。
- `x` / `y`: container canvas の canonical world 座標。右クリック位置を配置原点として保存する。
- `width` / `height`: 参照元 node 全体を等倍以下で収める最大表示領域。新規配置は `360 x 240`、最小 `40`、最大 `16,384` とする。対象 node と縦横比が異なる場合も、この領域の余りを参照カード本体へ含めない。

旧 `.ogp` で `references` が欠けている場合は空配列として decode し、空配列は encode 時に省略する。座標は有限値かつ絶対値 `1,000,000` 以下へ、寸法は上記範囲へ正規化する。

## Resolution and Editing

参照 ID は container、page / component、`data-og-internal-id` の順に厳密一致で解決する。DOM の深さ、tag name、親 node の種類には依存せず、page root を除く任意階層の `[data-og-internal-id]` node を対象にできる。`ogref:page`、`ogref:component`、Chapter、Collection、annotation の参照 ID は受け付けない。page 全体は既存の page / component card 配置を使う。

配置先 segment と参照元 segment は独立している。Pages canvas から component node を参照することも、Components canvas から page node を参照することもできる。配置を選択して Canvas / Layers / Inspector から node を編集した場合、保存先は常に参照元 HTML と同名 companion CSS であり、同じ参照元を表示するすべての viewport に同期される。

`references[]` が保持するのは参照 ID と editor 上の frame だけである。参照先 subtree の複製、上書き、子 node は `.ogp` に保存しない。参照元が外部変更で消えた場合も配置 metadata は保持し、App は解決不能な参照として表示する。参照先が復旧すれば同じ配置が再解決される。

## Visual Fidelity Contract

配置済み参照の本体は、固定サイズの preview stage ではなく「対象 node 自体の WebKit 描画」として扱う。利用者が参照本体の空間を対象 node の margin、padding、背景、またはレイアウトとして読めるよう、App は次の契約に従う。

1. 寸法の基準は、参照元 page の viewport、computed CSS、親 layout の制約を適用した対象 node の `getBoundingClientRect()` とする。対象の子 subtree は同じ WebKit 文書から描画し、別の HTML clone や簡略化した native viewへ置き換えない。
2. CSS `margin` は border box の外側にあるため参照本体へ含めない。`padding`、`border`、`background`、子 content など border box 内の見た目は参照元どおり保持する。
3. 対象 node が `width x height` の最大表示領域を超える場合は、`min(1, maxWidth / sourceWidth, maxHeight / sourceHeight)` の共通倍率を両軸へ適用する。拡大、縦横別倍率による歪み、対象の一部を落とす crop は行わない。
4. 参照カード本体、背景、境界線、選択枠、ヒット領域の寸法は `sourceBorderBox x scale` と一致させる。最大表示領域の未使用部分を背景で埋めず、letterbox状の空白を対象 node の見た目へ混入させない。
5. 左上情報カードの寸法表示は `.ogp` の最大表示領域ではなく、現在Canvas上に描画している縮小後実寸を示す。参照元のHTML / CSS編集、locale、component展開などでnode実寸が変わった場合は再計測して本体と寸法表示を追従させる。
6. 読み込み中は最大表示領域内に進捗表示を出してよいが、node解決後の正常表示へ読み込み用背景を残さない。解決不能時は実物表示ではなくエラー状態であることを明示する。
7. 参照元page全体のdocument scrollは対象nodeの見た目ではないため、focus表示中のroot `html` / `body`はscroll位置を原点へ固定し、overflowとWKWebViewのroot scroll indicatorを参照本体へ露出させない。対象nodeまたはその子がcomputed CSSで`overflow: auto | scroll | overlay`を持つ場合、その要素自身のscroll内容とindicatorは参照元に存在する見た目・操作として維持する。

## Placement Boundary

参照配置は Chapter / Collection キャンバス直下の sibling であり、page card、component card、任意の HTML object、annotation の内部には入らない。右クリック開始点として有効なのは、HTML card や参照 object ではないキャンバス背景だけである。

この境界により、参照配置操作は source HTML の DOM、親子関係、layout、`data-og-*`、companion CSS を変更しない。HTML 内で再利用可能な実装構造が必要な場合は、従来どおり component master と `<og-instance>` を使う。

## App Interaction

1. Canvas の空き領域を右クリックし、`参照IDから追加` を選ぶ。
2. 右クリックを受けた native Canvas view の同じ local 座標を source rect として popover を表示し、吹き出しの矢印先端を挿入位置へ向ける。popover に typed node reference ID を入力すると随時解決し、対象 node を元 HTML の WebKit 描画から切り出して preview する。
3. 解決済みの場合だけ追加を確定できる。確定後、右クリックした canonical world 座標へ参照 viewport を配置する。
4. 確定後の参照viewportは通常のpage cardと同じ本文背景、影、境界線、左上情報カードを使い、本体寸法はVisual Fidelity Contractに従って対象nodeの縮小後実寸へ一致させる。参照固有のheaderや角丸container、最大表示領域の余白は本文へ重ねず、左上情報カードの詳細行にだけ`参照`と実表示寸法を表示する。
5. 配置は左上情報カードの drag で移動でき、context menu から参照 ID のコピーまたは配置 metadata の削除ができる。削除しても参照元 HTML / CSS は削除しない。

貼り付け候補が clipboard にある場合、App は `ogref:node` / `ogref:component-node` だけを入力初期値として利用できる。popover の preview は入力確認用であり、確定前に `.ogp` や参照元を変更しない。

## Undo and Redo

参照配置の追加、移動、削除は、それぞれ一回の `.ogp` 保存を一つの操作として editor 全体の統合 Undo / Redo 時系列へ記録する。`⌘Z` とやり直しは Chapter / Collection の `references[]` だけを変更前後の配列へ戻し、参照元 HTML / companion CSS や、同じ manifest にある無関係な metadata を巻き戻さない。

履歴適用時は最新の `.ogp` を再読込し、対象 container の現在の `references[]` が履歴の期待値と一致する場合だけ差し替える。履歴記録後に同じ参照配列が外部変更されていた場合は適用を中止し、外部値を表示へ同期して無効になった統合履歴を破棄する。

参照 viewport から行った node 編集は通常 card からの編集と同じ文書履歴へ記録する。HTML と同名 companion CSS の両方を一操作の前後状態として扱い、CSS-only 編集もファイル未作成状態を含めて `⌘Z` / やり直しで復元する。履歴は表示 viewport の clone を保持せず、常に参照元ファイルへ適用して同じ正本を表示するすべての viewport を再同期する。HTML または companion CSS が外部変更されて履歴の期待値と一致しない場合も、外部値を上書きせず履歴適用を中止する。

## Agent, Build, and Screenshot Boundary

`ogkiln project inspect` と MCP project summary は、各 Chapter / Collection の配置数を `referenceCount` として返す。現時点で参照配置専用の CLI / MCP write operation は提供せず、App が `references[]` を編集する。

Canvas Object Reference は editor composition metadata である。`ogkiln build` は `.ogp` 自体を公開物へコピーせず、参照 node の clone、参照 ID、frame を生成 HTML / CSS / runtime へ注入しない。`screenshot canvas`、`screenshot page`、`screenshot node` も `references[]` を描画対象に含めない。元 node 自体の capture は既存の `screenshot node --id <typed-node-reference>` を使う。
