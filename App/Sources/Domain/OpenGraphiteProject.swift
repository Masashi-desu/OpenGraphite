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
/// - `components`: Component master を格納する HTML キャンバス一覧。
struct OpenGraphiteProject: Codable, Equatable {
    var version: String
    var name: String
    var repositoryRoot: String?
    var htmlRoot: String
    var cssLibrary: String
    var chapters: [OpenGraphiteChapter]
    var components: [OpenGraphitePage]

    var allPages: [OpenGraphitePage] {
        chapters.flatMap(\.pages) + components
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case name
        case repositoryRoot
        case htmlRoot
        case cssLibrary
        case chapters
        case pages
        case components
    }

    /// 論理名（日本語）: project JSONデコード関数
    /// 処理概要: 旧 top-level `pages` 形式と互換性を保ち、未指定の `components` を空配列として扱います。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        name = try container.decode(String.self, forKey: .name)
        repositoryRoot = try container.decodeIfPresent(String.self, forKey: .repositoryRoot)
        htmlRoot = try container.decode(String.self, forKey: .htmlRoot)
        cssLibrary = try container.decode(String.self, forKey: .cssLibrary)
        if let decodedChapters = try container.decodeIfPresent([OpenGraphiteChapter].self, forKey: .chapters) {
            chapters = decodedChapters
        } else {
            let legacyPages = try container.decodeIfPresent([OpenGraphitePage].self, forKey: .pages) ?? []
            chapters = [
                OpenGraphiteChapter(
                    id: OpenGraphiteChapter.defaultID,
                    title: OpenGraphiteChapter.defaultTitle,
                    pages: legacyPages
                )
            ]
        }
        components = try container.decodeIfPresent([OpenGraphitePage].self, forKey: .components) ?? []
    }

    /// 論理名（日本語）: project JSONエンコード関数
    /// 処理概要: `components` を含む現行 `.ogp` 形式として project manifest を保存します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(repositoryRoot, forKey: .repositoryRoot)
        try container.encode(htmlRoot, forKey: .htmlRoot)
        try container.encode(cssLibrary, forKey: .cssLibrary)
        try container.encode(chapters, forKey: .chapters)
        if !components.isEmpty {
            try container.encode(components, forKey: .components)
        }
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
        pages: [OpenGraphitePage],
        components: [OpenGraphitePage] = []
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.components = components
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
        chapters: [OpenGraphiteChapter],
        components: [OpenGraphitePage] = []
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.chapters = chapters
        self.components = components
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
/// - `title`: UI 表示用タイトル。未指定時は `id` を使います。
/// - `path`: `htmlRoot` から見た HTML ファイルパス。
/// - `canvas`: キャンバス上の配置とサイズ。
struct OpenGraphitePage: Codable, Equatable, Identifiable {
    var id: String
    var title: String?
    var path: String
    var canvas: OpenGraphiteCanvas

    var displayName: String {
        guard let title, !title.isEmpty else { return id }
        return title
    }
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

    /// 解像度を UI 表示向けに短く整形した文字列。
    var resolutionLabel: String {
        "\(Self.displayValue(width)) x \(Self.displayValue(height))"
    }

    /// キャンバス座標を UI 表示向けに短く整形した文字列。
    var positionLabel: String {
        "\(Self.displayValue(x)), \(Self.displayValue(y))"
    }

    /// 論理名（日本語）: キャンバス値表示関数
    /// 処理概要: キャンバス座標や解像度を UI 表示向けに整数優先の短い文字列へ変換します。
    ///
    /// - Parameter value: 表示するキャンバス数値。
    /// - Returns: 整数に近い値は整数、それ以外は小数1桁の文字列。
    private static func displayValue(_ value: Double) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", value)
    }
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

/// 論理名（日本語）: キャンバス表示セグメント
/// 概要: エディタ中央キャンバスが通常 Pages と Components のどちらを表示しているかを表します。
///
/// 定義内容:
/// - `pages`: `.ogp` の `chapters[].pages[]` を表示する通常ページ編集セグメント。
/// - `components`: `.ogp` の top-level `components[]` を表示する component master 編集セグメント。
enum OpenGraphiteCanvasSegment: String, Equatable {
    case pages
    case components

    var title: String {
        switch self {
        case .pages:
            return "Pages"
        case .components:
            return "Components"
        }
    }
}
