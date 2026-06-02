import Foundation

/// 論理名（日本語）: プロジェクト読み込みエラー
/// 概要: `.ogp` 読み込み時にアプリ側で扱う検証エラーを表します。
///
/// 定義内容:
/// - `missingChapters`: `.ogp` に chapters も collections も定義されていない状態。
/// - `missingPages`: `.ogp` の chapters と collections に表示対象 HTML が定義されていない状態。
/// - `missingHTML`: 先頭ページの HTML ファイルが存在しない状態。
enum ProjectLoadError: LocalizedError {
    case missingChapters
    case missingPages
    case missingHTML(URL)

    var errorDescription: String? {
        switch self {
        case .missingChapters:
            return ".ogp に chapters または collections がありません。"
        case .missingPages:
            return ".ogp の chapters または collections に表示対象 HTML がありません。"
        case .missingHTML(let url):
            return "HTMLが見つかりません: \(url.path)"
        }
    }
}

/// 論理名（日本語）: プロジェクトローダー
/// 概要: `.ogp` JSON を読み込み、HTML/CSS 参照の基準となるルート URL を解決します。
///
/// メソッド:
/// - `loadProject(at:)`: `.ogp` を読み込んで検証済みプロジェクトを返します。
struct ProjectLoader {
    /// 論理名（日本語）: プロジェクト読み込み関数
    /// 処理概要: `.ogp` をデコードし、pages/collections、先頭 HTML の存在を検証して読み込み済みモデルを返します。
    ///
    /// - Parameter fileURL: 読み込む `.ogp` ファイルの URL。
    /// - Returns: HTML 参照ルートを解決した読み込み済みプロジェクト。
    func loadProject(at fileURL: URL) throws -> LoadedOpenGraphiteProject {
        let data = try Data(contentsOf: fileURL)
        let project = try JSONDecoder().decode(OpenGraphiteProject.self, from: data).normalizedInternalIDs()

        guard !project.chapters.isEmpty || !project.collections.isEmpty else {
            throw ProjectLoadError.missingChapters
        }
        guard !project.allPages.isEmpty else {
            throw ProjectLoadError.missingPages
        }

        let projectDirectory = fileURL.deletingLastPathComponent()
        let rootURL = resolvedRootURL(from: project.repositoryRoot, relativeTo: projectDirectory)
        let loadedProject = LoadedOpenGraphiteProject(
            project: project,
            fileURL: fileURL,
            rootURL: rootURL
        )

        let firstHTML = loadedProject.htmlURL(for: project.allPages[0])
        guard FileManager.default.fileExists(atPath: firstHTML.path) else {
            throw ProjectLoadError.missingHTML(firstHTML)
        }

        return loadedProject
    }

    /// 論理名（日本語）: リポジトリルート解決関数
    /// 処理概要: `.ogp` に記録された絶対または相対の repositoryRoot を標準化済み URL に変換します。
    ///
    /// - Parameters:
    ///   - repositoryRoot: `.ogp` に記録されたリポジトリルート。未指定時は `.ogp` の配置ディレクトリを使います。
    ///   - projectDirectory: `.ogp` が置かれているディレクトリ。
    /// - Returns: 標準化済みのリポジトリルート URL。
    private func resolvedRootURL(from repositoryRoot: String?, relativeTo projectDirectory: URL) -> URL {
        guard let repositoryRoot, !repositoryRoot.isEmpty else {
            return projectDirectory.standardizedFileURL
        }

        if repositoryRoot.hasPrefix("/") {
            return URL(fileURLWithPath: repositoryRoot).standardizedFileURL
        }

        return projectDirectory
            .appendingPathComponent(repositoryRoot)
            .standardizedFileURL
    }
}
