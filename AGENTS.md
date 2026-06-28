# Codex グローバルカスタムプロンプト

- 返信は特段の指示がない限りすべて自然な日本語で行うこと。
- 技術用語やコマンド名は必要に応じて原語（英語）を併記してよい。
- ユーザーが別言語での回答を明示的に求めた場合のみ、その指示に従う。
- ログやコード片など引用部分は原文を尊重しつつ、必要があれば簡潔な日本語の補足を加える。
- リポジトリ直下の `README.md` を参照し、プロジェクトの規約について記述があった場合は厳守する。

## OpenGraphite 作業ルール

- `project.yml` を XcodeGen の正本として扱い、`OpenGraphite.xcodeproj` は生成物として直接編集しない。
- Swift コードを追加・変更する場合は `Docs/rules/DocumentCommentStandards.md` に従い、主要な型と関数へ `///` ドキュメントコメントを付与する。
- テストを追加・変更する場合は `Docs/rules/TestingStandards.md` に従い、Swift Testing の `@Suite` / `@Test` と Given/When/Then コメントを用いる。
- TODO 文書を追加・更新する場合は `Docs/operations/TODO/GOVERNANCE.md` と `Docs/operations/TODO/TEMPLATE.md` に従い、残タスクだけを直列化して管理する。
- 作業指示、利用者向け説明、エージェント向け知識、仕様、開発規約、運用手順、リリース手順、自動化定義、検証入口は、実装と同じリポジトリ資源として扱う。
- 挙動、正本モデル、ディレクトリ責務、検証ハーネス、リリース手順を変える場合は、関連する実装、テスト、資料、skill、workflow を同じ変更単位で更新する。
- 1つの挙動変更に必要な資源を、理由なく別々のコミットへ分断しない。
- コード、設定、ドキュメント生成に関わる変更を完了する前に、品質ゲート `./Scripts/quality_gate.sh` を必ず完走させる。
- 品質ゲートが失敗した状態で作業を完了してはならない。外部要因で実行できない場合のみ、理由と未確認範囲を明記してユーザーへ報告する。

## ディレクトリ責務

```text
.
├── App/                         # macOS SwiftUI アプリ本体
│   ├── Sources/
│   │   ├── Domain/              # プロジェクト、ノード、参照 ID などのドメイン
│   │   ├── Editor/              # 編集状態、HTML 同期、Web canvas 連携
│   │   ├── Infrastructure/      # プロジェクト作成、読み込み、ダイアログなどの入出力
│   │   └── Presentation/        # SwiftUI の画面、Inspector、Sidebar、Window chrome
│   └── Resources/               # Info.plist、アイコンなどのアプリ資源
├── Shared/
│   └── Sources/                 # アプリ、ogkiln、MCP が共有する Agent Interface と HTML/CSS 操作
├── Tools/
│   └── ogkiln/                  # ogkiln CLI のエントリポイント
├── Scripts/                     # build、test、quality gate、署名、release、ogkiln wrapper
│   └── release/                 # GitHub Release と release policy 関連の補助 script
├── script/                      # ローカル app build/run/debug/log 確認用の補助入口
├── MCP/
│   └── OpenGraphite/            # Scripts/ogkiln を呼び出す MCP server と README
├── CSS/                         # 配布対象の OpenGraphite.css と共有描画規約
├── public/                      # OpenGraphite で編集される Web 正本
│   ├── _components/             # component master、component CSS、component asset
│   ├── assets/                  # 公開ページで使う画像などの静的 asset
│   ├── locales/                 # i18n 用 locale JSON
│   └── *.html / *.css           # ページ HTML と同名 companion CSS
├── SampleProject/               # public/ と CSS/ を参照するサンプル .ogp
├── Tests/
│   └── OpenGraphiteTests/       # Swift Testing の単体・統合寄りテスト
├── Docs/                        # 設計、仕様、ルール、TODO 運用、リリース手順、調査記録
│   ├── specs/                   # source-of-truth、CLI、MCP、設計思想などの仕様
│   ├── rules/                   # ドキュメントコメントとテスト記述の規約
│   ├── operations/              # TODO governance と運用 TODO
│   ├── release/                 # DMG、notarization、dev/main release 手順
│   └── investigations/          # 調査記録
├── .agents/
│   └── skills/                  # Codex が参照する OpenGraphite 固有 skill
├── .github/
│   └── workflows/               # GitHub Actions の CI / release 検証
├── Configs/                     # Xcode build 用 xcconfig
├── OpenGraphite.xcodeproj/      # project.yml から生成される成果物。直接編集しない
├── .build/                      # ローカル CLI build 出力
├── build/                       # Xcode / release 検証のローカル build 出力
├── dist/                        # 配布物や export の出力先
└── .temp/                       # 一時検証、スクリーンショット、作業用出力
```

## ハーネス対応

このリポジトリのハーネスは `Scripts/quality_gate.sh` を実行入口にし、実装、仕様、規約、skill、アプリ、CLI、MCP、サンプルプロジェクト、Web 資源を同じ正本モデルで同期・検証する。

```mermaid
flowchart TD
    subgraph gate["品質ゲート実行"]
        quality["Scripts/quality_gate.sh<br/>最終確認の実行入口"]
        stopApp["Scripts/open_graphite_process.sh<br/>実行中アプリを止めて検証前提を揃える"]
        xcodegen["xcodegen generate<br/>project.yml から Xcode project を再生成"]
        xctest["xcodebuild test<br/>OpenGraphite scheme の Swift Testing 実行"]
        cliBuild["xcodebuild build ogkiln<br/>CLI target を Xcode 経由でビルド"]
        validate["ogkiln validate<br/>サンプル .ogp と参照資源の整合性検証"]
    end

    subgraph generated["生成物"]
        xcodeproj["OpenGraphite.xcodeproj<br/>XcodeGen 生成物。直接編集しない"]
        appTarget["OpenGraphite.app<br/>アプリ、Web 資源、サンプルを束ねた検証対象"]
        cli["ogkiln CLI<br/>リポジトリ上の HTML / CSS / .ogp を操作する検証入口"]
    end

    subgraph source["実装・プロジェクト正本"]
        project["project.yml<br/>Xcode target と build 設定の正本"]
        appSrc["App/Sources / App/Resources<br/>macOS アプリの実装と同梱資源"]
        shared["Shared/Sources<br/>アプリ、CLI、MCP が共有する編集ロジック"]
        domain["App/Sources/Domain + ProjectLoader<br/>ogkiln が使う project / node 読み書きモデル"]
        toolEntry["Tools/ogkiln/main.swift<br/>CLI process のエントリポイント"]
        scriptsOgkiln["Scripts/ogkiln<br/>必要時に CLI をビルドして実行する wrapper"]
    end

    subgraph webResources["Web・サンプル正本"]
        css["CSS/OpenGraphite.css<br/>data-og-* と --og-* の共有描画規約"]
        web["public/<br/>HTML / companion CSS / runtime / components / assets / locales"]
        sample["SampleProject/OpenGraphiteSample.ogp<br/>public と CSS を参照する実プロジェクト"]
    end

    subgraph knowledge["資料・知識同期"]
        implementation["実装編集<br/>App / Shared / Tools / CSS / public / SampleProject の変更"]
        specs["仕様<br/>Source-of-truth / CLI / MCP / design philosophy の説明"]
        rules["規約<br/>開発規約 / 運用規約 / リリース方針"]
        skills["Skills<br/>Codex が参照する OpenGraphite 作業知識"]
    end

    subgraph tests["テスト資源"]
        testSources["Tests/OpenGraphiteTests<br/>挙動と契約を固定する Swift Testing suite"]
    end

    subgraph mcpHarness["MCP ハーネス"]
        mcp["MCP/OpenGraphite/server.mjs<br/>ogkiln と同じ経路を MCP tool として公開"]
    end

    quality --> stopApp
    quality --> xcodegen
    quality --> xctest
    quality --> cliBuild
    quality --> validate

    project --> xcodegen
    xcodegen --> xcodeproj
    xcodeproj --> appTarget
    xcodeproj --> cliBuild

    appSrc --> appTarget
    shared --> appTarget
    css --> appTarget
    web --> appTarget
    sample --> appTarget

    implementation <--> specs
    rules <--> skills
    specs --> skills

    testSources --> xctest
    appTarget --> xctest

    domain --> cli
    shared --> cli
    toolEntry --> cli
    scriptsOgkiln --> cli
    cliBuild --> cli

    mcp --> scriptsOgkiln
    cli --> validate
    sample --> validate
    web --> validate
    css --> validate
```
