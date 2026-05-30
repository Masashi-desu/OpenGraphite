# OpenGraphite Design Philosophy

OpenGraphite は、HTML をエクスポート成果物ではなく編集可能な正本として扱うデザインアプリです。デザインツール内の独自 IR を最終成果物へ変換するのではなく、Web で配布される HTML そのものを開き、読み取り、編集し、保存します。

## Core Principle

HTML が唯一の正本です。

`OpenGraphite.app` が表示している HTML と、ブラウザで単独表示できる HTML は同じファイルです。編集結果は別の export ディレクトリや生成済みコピーへ書き出すのではなく、開いている `public/*.html` に直接反映されます。

この方針により、OpenGraphite の成果物はアプリに閉じません。HTML、CSS、画像などの Web 標準ファイルがそのまま成果物になり、リポジトリ上でレビュー、配布、ホスティングできます。

## Responsibility Model

OpenGraphite は、意味、編集情報、デザイン値、描画規則を分離します。

| 領域 | 責務 | 例 |
| --- | --- | --- |
| タグ名 | 意味、コンポーネント名 | `HeroSection`, `MainTitle`, `PrimaryButton` |
| `data-og-*` | エディタが扱う構造、種別、役割 | `data-og-id`, `data-og-type`, `data-og-layout`, `data-og-role` |
| CSS 変数 | デザイン値 | `--og-gap`, `--og-padding`, `--og-radius`, `--og-background` |
| `OpenGraphite.css` | アプリ内描画とブラウザ描画を一致させる規則 | `[data-og-layout="vertical"]` |
| `.ogp` | プロジェクト管理、ページ参照、キャンバス配置 | `htmlRoot`, `pages`, `canvas` |

class 名はスタイルの正本にしません。class は Web 実装上の補助として将来使う余地を残しますが、OpenGraphite が編集対象として信頼する主な契約は `data-og-*` と `--og-*` です。

## `.ogp` Is Project Metadata

`.ogp` は HTML の代替表現ではありません。DOM 構造、本文、主要なデザイン値を `.ogp` に複製しないことを原則とします。

`.ogp` が持つべき情報は次の範囲です。

- リポジトリルートなどのプロジェクト解決情報
- `public` ルートへの相対参照
- HTML ページ一覧
- キャンバス上の配置、表示サイズ、ズーム初期値など、エディタ固有の情報

公開リポジトリで共有できるように、`.ogp` 内のパスは相対参照を基本とします。ユーザーのディスク上の絶対パスは、実行時に解決される表示情報として扱い、永続化される IR へ固定しません。

## HTML Contract

OpenGraphite が編集可能な HTML ノードは、少なくとも安定した `data-og-id` を持ちます。

```html
<HeroSection
  data-og-id="hero"
  data-og-type="frame"
  data-og-layout="vertical"
  data-og-role="landing-hero"
  style="
    --og-gap:32px;
    --og-padding:64px;
    --og-radius:24px;
  ">
  <MainTitle data-og-id="title" data-og-type="text">
    OpenGraphite
  </MainTitle>
</HeroSection>
```

この契約では、タグ名は人間が読める意味を持ち、`data-og-*` はエディタが安全に解釈できるメタデータを持ち、CSS 変数はデザイン編集の入出力になります。

## Rendering Contract

`OpenGraphite.css` は app 内の `WKWebView` と通常ブラウザの両方で同じ見た目を作るための共有ライブラリです。

描画規則は class ではなく `data-og-*` と CSS 変数を中心に記述します。

```css
[data-og-layout="vertical"] {
  display: flex;
  flex-direction: column;
  gap: var(--og-gap, 0);
}
```

アプリは HTML を特殊なキャンバス形式へ変換してから描画しません。WebKit が HTML を描画し、OpenGraphite は選択、レイヤー抽出、インスペクタ編集、保存を担当します。

## Editor Behavior

OpenGraphite のエディタは、HTML の上に編集体験を重ねる薄いレイヤーです。

- `WKWebView` で対象 HTML を直接表示する
- `[data-og-id]` を持つノードを Layers に反映する
- 選択状態をキャンバス、Layers、Inspector で同期する
- Inspector の編集を DOM と HTML ファイルへ反映する
- HTML 内の自然なスクロールやブラウザ挙動をできるだけ尊重する

OpenGraphite 独自の機能を追加する場合も、最終的に HTML と CSS に説明可能な形で落ちることを優先します。

## Design Constraints

- HTML はブラウザで単独表示できること。
- `OpenGraphite.app` がなくても成果物を確認できること。
- `.xcodeproj` は生成物であり、`project.yml` を XcodeGen の正本とすること。
- 生成物、ユーザー固有の絶対パス、秘密情報を正本ファイルへ混ぜないこと。
- 独自 IR の肥大化で HTML 正本モデルを曖昧にしないこと。
- app 内描画とブラウザ描画の差分は `OpenGraphite.css` 側で説明できるようにすること。

## Decision Heuristics

実装判断で迷った場合は、次の順で優先します。

1. 編集後の HTML が、そのまま Web 成果物として読めるか。
2. デザイン値が CSS 変数として明示されているか。
3. エディタ用メタデータが `data-og-*` として HTML 上に保持されているか。
4. `.ogp` が HTML の複製ではなく、プロジェクト管理情報に留まっているか。
5. 公開リポジトリへ置いてもユーザー固有情報を含まないか。

この優先順位に反する機能は、短期的に便利でも OpenGraphite の設計思想から外れるものとして扱います。
