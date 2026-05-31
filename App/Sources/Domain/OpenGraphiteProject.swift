import Foundation

/// 論理名（日本語）: OpenGraphiteプロジェクト定義
/// 概要: `.ogp` ファイルに保存されるプロジェクト管理情報、Chapter、ページ一覧を表します。
///
/// プロパティ:
/// - `version`: `.ogp` 形式のバージョン。
/// - `name`: プロジェクト表示名。
/// - `repositoryRoot`: `.ogp` から見たリポジトリルート。
/// - `htmlRoot`: HTML 成果物を置く public ルート。
/// - `cssLibrary`: OpenGraphite.css の参照パス。
/// - `chapters`: Chapter ごとのキャンバス定義。
struct OpenGraphiteProject: Codable, Equatable {
    var version: String
    var name: String
    var repositoryRoot: String?
    var htmlRoot: String
    var cssLibrary: String
    var chapters: [OpenGraphiteChapter]

    var allPages: [OpenGraphitePage] {
        chapters.flatMap(\.pages)
    }

    /// 論理名（日本語）: 既定Chapterプロジェクト初期化関数
    /// 処理概要: 指定 pages を既定 Chapter に格納してプロジェクトを作成します。
    ///
    /// - Parameters:
    ///   - version: `.ogp` 形式のバージョン。
    ///   - name: プロジェクト表示名。
    ///   - repositoryRoot: `.ogp` から見たリポジトリルート。
    ///   - htmlRoot: HTML 成果物を置く public ルート。
    ///   - cssLibrary: OpenGraphite.css の参照パス。
    ///   - pages: 既定 Chapter に入れるページ一覧。
    init(
        version: String,
        name: String,
        repositoryRoot: String?,
        htmlRoot: String,
        cssLibrary: String,
        pages: [OpenGraphitePage]
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.chapters = [
            OpenGraphiteChapter(
                id: OpenGraphiteChapter.defaultID,
                title: OpenGraphiteChapter.defaultTitle,
                pages: pages
            )
        ]
    }

    /// 論理名（日本語）: Chapterプロジェクト初期化関数
    /// 処理概要: Chapter 配列を正本としてプロジェクトを作成します。
    ///
    /// - Parameters:
    ///   - version: `.ogp` 形式のバージョン。
    ///   - name: プロジェクト表示名。
    ///   - repositoryRoot: `.ogp` から見たリポジトリルート。
    ///   - htmlRoot: HTML 成果物を置く public ルート。
    ///   - cssLibrary: OpenGraphite.css の参照パス。
    ///   - chapters: プロジェクトが保持する Chapter 一覧。
    init(
        version: String,
        name: String,
        repositoryRoot: String?,
        htmlRoot: String,
        cssLibrary: String,
        chapters: [OpenGraphiteChapter]
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.chapters = chapters
    }
}

/// 論理名（日本語）: OpenGraphite Chapter定義
/// 概要: Pages の上位概念として、独立したキャンバスに配置されるページ群を表します。
///
/// プロパティ:
/// - `id`: Chapter 識別子。
/// - `title`: UI 表示用タイトル。未指定時は `id` を表示名として使います。
/// - `pages`: Chapter 内の HTML ページ一覧。
struct OpenGraphiteChapter: Codable, Equatable, Identifiable {
    static let defaultID = "main"
    static let defaultTitle = "Main"

    var id: String
    var title: String?
    var pages: [OpenGraphitePage]

    var displayName: String {
        guard let title, !title.isEmpty else { return id }
        return title
    }
}

/// 論理名（日本語）: OpenGraphiteページ定義
/// 概要: `.ogp` 内の単一 HTML ページとキャンバス配置情報を表します。
///
/// プロパティ:
/// - `id`: ページ識別子。
/// - `path`: `htmlRoot` から見た HTML ファイルパス。
/// - `canvas`: キャンバス上の配置とサイズ。
struct OpenGraphitePage: Codable, Equatable, Identifiable {
    var id: String
    var path: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: OpenGraphiteキャンバス定義
/// 概要: ページプレビューをキャンバスへ配置するための座標とサイズを表します。
///
/// プロパティ:
/// - `x`: キャンバス上の X 座標。
/// - `y`: キャンバス上の Y 座標。
/// - `width`: プレビュー幅。
/// - `height`: プレビュー高さ。
struct OpenGraphiteCanvas: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

/// 論理名（日本語）: 読み込み済みOpenGraphiteプロジェクト
/// 概要: `.ogp` の内容に加えて、ファイル URL と解決済みリポジトリルートを保持します。
///
/// プロパティ:
/// - `project`: デコード済みプロジェクト定義。
/// - `fileURL`: 読み込んだ `.ogp` の URL。
/// - `rootURL`: HTML と CSS を解決するリポジトリルート URL。
struct LoadedOpenGraphiteProject: Identifiable, Equatable {
    let id = UUID()
    var project: OpenGraphiteProject
    var fileURL: URL
    var rootURL: URL

    var cssURL: URL {
        rootURL.appendingPathComponent(project.cssLibrary)
    }

    /// 論理名（日本語）: HTMLページURL解決関数
    /// 処理概要: `rootURL`、`htmlRoot`、ページパスを連結して表示対象 HTML の URL を返します。
    ///
    /// - Parameter page: URL を解決するページ定義。
    /// - Returns: 対象 HTML ファイルの URL。
    func htmlURL(for page: OpenGraphitePage) -> URL {
        rootURL
            .appendingPathComponent(project.htmlRoot)
            .appendingPathComponent(page.path)
    }
}
