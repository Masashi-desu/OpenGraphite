# Editor Column Horizontal Line Investigation

## Symptom

OpenGraphite の Sidebar と Inspector の中央付近に、不要な水平線が左右それぞれ残って見える。

## Investigation

- `SidebarView` と `InspectorView` にあった明示的な horizontal `Divider` は削除後も同じ高さの線が残ったため、カラム内セクション区切り線ではなかった。
- Inspector の空状態で使っていた `scope` シンボルを外しても右カラムの線は残ったため、空状態アイコン由来ではなかった。
- `EditorColumnBackground` に不透明な system color を重ねても線が残ったため、単純な material 透過や背面プレビューの色だけが原因ではなかった。
- 問題の線は、`EditorShellView` で `SidebarView` / `InspectorView` に背景を付けた後、さらに外側の `.frame(maxWidth:maxHeight:alignment:)` で画面端へ寄せていたことにより発生していた。背景がカラムの理想高さ側に付き、外側の全高フレームとの境界が水平の seam として見えていた。

## Root Cause

カラム背景の modifier が、最終的なウインドウ全高の固定幅サーフェスではなく、その内側の content-sized view に適用されていた。

## Fix

Sidebar と Inspector を `EditorOverlayColumn` で包み、固定幅カラム自体を `maxHeight: .infinity` にした上で `EditorColumnBackground` を適用する。これにより背景面の途中終端がなくなり、水平 seam は発生しない。
