import Foundation

/// 論理名（日本語）: OpenGraphiteプロジェクト定義
/// 概要: `.ogp` ファイルに保存されるプロジェクト管理情報とページ一覧を表します。
///
/// プロパティ:
/// - `version`: `.ogp` 形式のバージョン。
/// - `name`: プロジェクト表示名。
/// - `repositoryRoot`: `.ogp` から見たリポジトリルート。
/// - `htmlRoot`: HTML 成果物を置く public ルート。
/// - `cssLibrary`: OpenGraphite.css の参照パス。
/// - `pages`: 編集対象 HTML ページ一覧。
struct OpenGraphiteProject: Codable, Equatable {
    var version: String
    var name: String
    var repositoryRoot: String?
    var htmlRoot: String
    var cssLibrary: String
    var pages: [OpenGraphitePage]
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
