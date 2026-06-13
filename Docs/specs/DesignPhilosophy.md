# OpenGraphite Design Philosophy

OpenGraphite は、Web 標準ファイルを編集可能な正本として扱うデザインアプリです。デザインツール内の独自 IR を最終成果物へ変換するのではなく、Web で配布される source files そのものを開き、読み取り、編集し、保存します。

## Core Principle

Web 標準の source files が正本です。通常の page DOM は HTML が担い、共通描画は CSS、参照展開は必要に応じて runtime または build、キャンバス配置や preview state は project metadata が担います。

`OpenGraphite.app` が表示している source files と、ブラウザで表示する HTML/CSS/JS は同じリポジトリ内の Web 標準ファイルです。編集結果は独自デザイン IR へ複製せず、開いている source files へ直接反映されます。

component 参照を使う場合、Pages の source HTML は軽い参照を保持できます。小規模なプロジェクトは runtime で表示時に展開し、性能や SEO を重視する場合は build で静的 HTML を生成できます。これは `.fig` や `.pen` のような別正本を作るものではなく、Web 標準 source files から決定的に生成される配布形態です。

この方針により、OpenGraphite の成果物はアプリに閉じません。HTML、CSS、画像、locale resource などの Web 標準ファイルがそのまま成果物になり、リポジトリ上でレビュー、配布、ホスティングできます。

## Repository-Synchronized Interface

OpenGraphite は、リポジトリに置かれた HTML、CSS、画像、実装 runtime、project metadata を正本として読み取り、その内容をアプリ内の表示と編集状態へ同期します。Canvas、Layers、Inspector は独自のコピーではなく、リポジトリ上のファイル構造と現在値を反映するインターフェースです。

この同期モデルにより、ユーザーと AI は同じリポジトリ内容を見ながら協業できます。AI がコードやドキュメントとして変更した内容は OpenGraphite 上の表示に反映され、OpenGraphite で行った編集はリポジトリの正本ファイルへ戻ります。OpenGraphite は、デザインツール、コードエディタ、AI エージェントが同じ成果物を扱うためのインターフェース体験を提供します。

## Responsibility Principles

OpenGraphite は、意味、編集情報、デザイン値、描画規則、project metadata を分離します。

- タグ名は、人間が読める意味やコンポーネント名を担う。
- `data-og-*` は、エディタが安全に解釈する構造、種別、役割を担う。
- `--og-*` は、編集可能なデザイン値を担う。
- CSS は、app 内描画とブラウザ描画を一致させる規則を担う。
- `.ogp` は、source files の複製ではなく、プロジェクト解決、一覧、キャンバス配置、preview metadata を担う。

class 名はスタイルの正本にしません。class は Web 実装上の補助として将来使う余地を残しますが、OpenGraphite が編集対象として信頼する主な契約は `data-og-*` と `--og-*` です。

詳細な属性、CSS 値、runtime、build、preview mock、text resource の境界は [SourceOfTruthContract.md](SourceOfTruthContract.md) に定義します。

## Project Metadata Principle

`.ogp` は source files の代替表現ではありません。DOM 構造、本文、主要なデザイン値を `.ogp` に複製しないことを原則とします。

`.ogp` が持つべき情報は、リポジトリ解決、ページや Collection の一覧、キャンバス配置、表示サイズ、zoom 初期値、editor preview 用 metadata の範囲に留めます。公開リポジトリで共有できるように、永続化する path は相対参照を基本とし、ユーザー固有の絶対パスを正本へ固定しません。

## Reference Principle

component instance は master の構造を共有し、差分は明示された slot、配置 override、または runtime / locale resource として source に保持します。生成 DOM は正本ではありません。

同じ考え方で、component placement の表示 clone も正本ではありません。clone を直接分岐編集するのではなく、保存対象を参照元 node、placement host の表示枠 override、または preview mock metadata へ分けます。

この原則により、再利用と個別差分の境界が file 上で説明可能になります。instance や placement の見た目が異なる場合でも、何が共有で何が個別差分なのかを source files から追跡できます。

## Rendering Principle

OpenGraphite は HTML を特殊なキャンバス形式へ変換してから描画しません。WebKit が source HTML / CSS / JS を描画し、OpenGraphite は選択、レイヤー抽出、インスペクタ編集、保存を担当します。

描画規則は class ではなく `data-og-*` と CSS 変数を中心に記述します。app 内描画とブラウザ描画の差分は、できるだけ CSS と runtime contract 側で説明できるようにします。

## Editor Principle

OpenGraphite のエディタは、source files の上に編集体験を重ねる薄いレイヤーです。

- `WKWebView` で対象 source を直接表示する。
- `[data-og-id]` を持つ node を Layers に反映する。
- 選択状態を Canvas、Layers、Inspector で同期する。
- Inspector の編集を DOM と source file へ反映する。
- HTML 内の自然なスクロールやブラウザ挙動をできるだけ尊重する。

OpenGraphite 独自の機能を追加する場合も、最終的に Web 標準ファイルに説明可能な形で落ちることを優先します。

## Design Constraints

- Source files はブラウザで単独表示できること。
- `OpenGraphite.app` がなくても成果物を確認できること。
- `.xcodeproj` は生成物であり、`project.yml` を XcodeGen の正本とすること。
- 生成物、ユーザー固有の絶対パス、秘密情報を正本ファイルへ混ぜないこと。
- 独自 IR の肥大化で source-of-truth model を曖昧にしないこと。
- app 内描画とブラウザ描画の差分は CSS / runtime / contract 側で説明できるようにすること。

## Decision Heuristics

実装判断で迷った場合は、次の順で優先します。

1. 編集後の source files が、そのまま Web 成果物として読めるか。
2. デザイン値が CSS 変数として明示されているか。
3. エディタ用メタデータが `data-og-*` として source 上に保持されているか。
4. `.ogp` が source の複製ではなく、プロジェクト管理情報に留まっているか。
5. 公開リポジトリへ置いてもユーザー固有情報を含まないか。

この優先順位に反する機能は、短期的に便利でも OpenGraphite の設計思想から外れるものとして扱います。
