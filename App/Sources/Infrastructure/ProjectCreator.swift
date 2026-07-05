import Foundation

/// 論理名（日本語）: プロジェクト作成エラー
/// 概要: 新規 `.ogp` project seed の作成時に発生する検証エラーを表します。
///
/// 定義内容:
/// - `projectAlreadyExists`: 作成先 `.ogp` が既に存在する状態。
/// - `missingCSSLibrarySource`: seed としてコピーする OpenGraphite.css が見つからない状態。
/// - `pageCreationFailed`: 初期 HTML の生成に失敗した状態。
enum ProjectCreationError: LocalizedError, Equatable {
    case projectAlreadyExists(URL)
    case missingCSSLibrarySource(URL?)
    case pageCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .projectAlreadyExists(let url):
            return "作成先の .ogp が既に存在します: \(url.path)"
        case .missingCSSLibrarySource(let url):
            if let url {
                return "OpenGraphite.css の seed が見つかりません: \(url.path)"
            }
            return "OpenGraphite.css の seed を解決できません。"
        case .pageCreationFailed(let message):
            return "初期ページ HTML の作成に失敗しました: \(message)"
        }
    }
}

/// 論理名（日本語）: プロジェクト作成器
/// 概要: 新規 `.ogp` を作成し、既存 `public` がない場合だけ初期 HTML/CSS seed も生成します。
///
/// プロパティ:
/// - `cssLibrarySourceURL`: 新規 project へコピーする OpenGraphite.css の provider。
/// - `fileManager`: ファイル作成と存在確認に使う FileManager。
struct ProjectCreator {
    private static let htmlRoot = "public"
    private static let cssLibraryPath = "CSS/OpenGraphite.css"
    private static let initialPagePath = "index.html"

    private let cssLibrarySourceURL: () -> URL?
    private let fileManager: FileManager

    /// 論理名（日本語）: プロジェクト作成器初期化関数
    /// 処理概要: CSS seed provider と FileManager を注入可能な形で保持します。
    ///
    /// - Parameters:
    ///   - cssLibrarySourceURL: 新規 project へコピーする OpenGraphite.css の URL を返す provider。
    ///   - fileManager: ファイル操作に使う FileManager。
    init(
        cssLibrarySourceURL: @escaping () -> URL? = { Self.bundledCSSLibraryURL() },
        fileManager: FileManager = .default
    ) {
        self.cssLibrarySourceURL = cssLibrarySourceURL
        self.fileManager = fileManager
    }

    /// 論理名（日本語）: プロジェクト作成関数
    /// 処理概要: 指定 URL に `.ogp` 拡張子を補完し、`.ogp` の親ディレクトリを project root として seed または空 manifest を作成します。
    ///
    /// - Parameter requestedURL: ユーザーが指定した `.ogp` 作成先 URL。
    /// - Returns: 実際に作成した `.ogp` URL。
    @discardableResult
    func createProject(at requestedURL: URL) throws -> URL {
        try createProject(
            at: requestedURL,
            projectRootURL: requestedURL.deletingLastPathComponent(),
            copyCSSLibraryWhenPublicExists: false
        )
    }

    /// 論理名（日本語）: ルート指定プロジェクト作成関数
    /// 処理概要: `.ogp` の作成先と HTML/CSS を解決する project root を分けて、seed または空 manifest を作成します。
    ///
    /// - Parameters:
    ///   - requestedURL: ユーザーが指定した `.ogp` 作成先 URL。
    ///   - requestedRootURL: `.ogp` の `repositoryRoot` として使う project root URL。
    ///   - copyCSSLibraryWhenPublicExists: 既存 `public` がある場合にも CSS library がなければコピーするか。
    /// - Returns: 実際に作成した `.ogp` URL。
    @discardableResult
    func createProject(
        at requestedURL: URL,
        projectRootURL requestedRootURL: URL,
        copyCSSLibraryWhenPublicExists: Bool
    ) throws -> URL {
        let projectURL = Self.normalizedProjectURL(requestedURL)
        let projectDirectoryURL = projectURL.deletingLastPathComponent()
        let projectRootURL = requestedRootURL.standardizedFileURL
        let publicDirectoryURL = projectRootURL
            .appendingPathComponent(Self.htmlRoot, isDirectory: true)
            .standardizedFileURL
        let htmlURL = projectRootURL
            .appendingPathComponent(Self.htmlRoot, isDirectory: true)
            .appendingPathComponent(Self.initialPagePath)
            .standardizedFileURL
        let companionCSSURL = OpenGraphiteCompanionCSSDocument
            .companionURL(forHTMLURL: htmlURL)
            .standardizedFileURL
        let cssURL = projectRootURL
            .appendingPathComponent(Self.cssLibraryPath)
            .standardizedFileURL

        guard !fileManager.fileExists(atPath: projectURL.path) else {
            throw ProjectCreationError.projectAlreadyExists(projectURL)
        }

        let publicAlreadyExists = fileManager.fileExists(atPath: publicDirectoryURL.path)
        let cssAlreadyExists = fileManager.fileExists(atPath: cssURL.path)
        let projectName = Self.projectName(from: projectURL)
        let repositoryRoot = Self.repositoryRoot(from: projectDirectoryURL, to: projectRootURL)
        let shouldCopyCSSLibrary = !cssAlreadyExists && (!publicAlreadyExists || copyCSSLibraryWhenPublicExists)

        do {
            try fileManager.createDirectory(
                at: projectDirectoryURL,
                withIntermediateDirectories: true
            )
            let project: OpenGraphiteProject
            if publicAlreadyExists {
                if shouldCopyCSSLibrary {
                    try copyCSSLibrary(to: cssURL)
                }
                project = Self.emptyProject(name: projectName, repositoryRoot: repositoryRoot)
            } else {
                if shouldCopyCSSLibrary {
                    try copyCSSLibrary(to: cssURL)
                }
                project = try createSeedProject(
                    name: projectName,
                    repositoryRoot: repositoryRoot,
                    projectURL: projectURL,
                    htmlURL: htmlURL,
                    cssURL: cssURL
                )
            }

            try writeProjectManifest(project, to: projectURL)
            return projectURL
        } catch {
            try? fileManager.removeItem(at: projectURL)
            if !publicAlreadyExists {
                try? fileManager.removeItem(at: htmlURL)
                try? fileManager.removeItem(at: companionCSSURL)
            }
            if shouldCopyCSSLibrary {
                try? fileManager.removeItem(at: cssURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: 初期seedプロジェクト作成関数
    /// 処理概要: 初期 HTML と companion CSS を作成し、その page entry を持つ project manifest を返します。
    ///
    /// - Parameters:
    ///   - name: project 表示名。
    ///   - repositoryRoot: `.ogp` から見た project root。
    ///   - projectURL: 作成中 `.ogp` URL。
    ///   - htmlURL: 初期 HTML の作成先 URL。
    ///   - cssURL: OpenGraphite.css の URL。
    /// - Returns: 初期 page を持つ project manifest。
    private func createSeedProject(
        name: String,
        repositoryRoot: String?,
        projectURL: URL,
        htmlURL: URL,
        cssURL: URL
    ) throws -> OpenGraphiteProject {
        let page = OpenGraphitePage(
            id: "home",
            path: Self.initialPagePath,
            canvas: OpenGraphiteCanvas(
                name: "Desktop",
                x: 0,
                y: 0,
                width: 1440,
                height: 1200
            )
        )
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: projectURL)
        )
        let pageResult = try core.createPage(
            at: htmlURL,
            title: name,
            lang: "ja",
            stylesheetPath: Self.relativePath(
                from: htmlURL.deletingLastPathComponent(),
                to: cssURL
            ),
            bodyHTML: Self.initialBodyHTML(projectName: name),
            overwrite: false
        )
        guard pageResult.created else {
            throw ProjectCreationError.pageCreationFailed(
                pageResult.diagnostics.first(where: { $0.severity == .error })?.message
                    ?? "原因不明のエラーです。"
            )
        }

        return OpenGraphiteProject(
            version: "0.1.0",
            name: name,
            repositoryRoot: repositoryRoot,
            htmlRoot: Self.htmlRoot,
            cssLibrary: Self.cssLibraryPath,
            pages: [page]
        )
    }

    /// 論理名（日本語）: 空プロジェクトmanifest生成関数
    /// 処理概要: 既存 `public` へ自動 page 登録せず、ユーザーが後で参照を追加できる空 Chapter の `.ogp` を作ります。
    ///
    /// - Parameters:
    ///   - name: project 表示名。
    ///   - repositoryRoot: `.ogp` から見た project root。
    /// - Returns: page 未登録の project manifest。
    private static func emptyProject(name: String, repositoryRoot: String?) -> OpenGraphiteProject {
        OpenGraphiteProject(
            version: "0.1.0",
            name: name,
            repositoryRoot: repositoryRoot,
            htmlRoot: Self.htmlRoot,
            cssLibrary: Self.cssLibraryPath,
            chapters: [
                OpenGraphiteChapter(
                    id: OpenGraphiteChapter.defaultID,
                    title: OpenGraphiteChapter.defaultTitle,
                    pages: []
                )
            ]
        )
    }

    /// 論理名（日本語）: CSSライブラリコピー関数
    /// 処理概要: bundle などから解決した OpenGraphite.css を新規 project の CSS ディレクトリへコピーします。
    ///
    /// - Parameter destinationURL: コピー先の OpenGraphite.css URL。
    private func copyCSSLibrary(to destinationURL: URL) throws {
        let sourceURL = cssLibrarySourceURL()?.standardizedFileURL
        guard let sourceURL, fileManager.fileExists(atPath: sourceURL.path) else {
            throw ProjectCreationError.missingCSSLibrarySource(sourceURL)
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    /// 論理名（日本語）: プロジェクトmanifest保存関数
    /// 処理概要: 新規 project manifest を現行 `.ogp` schema で保存します。
    ///
    /// - Parameters:
    ///   - project: 保存する project 定義。
    ///   - projectURL: 保存先 `.ogp` URL。
    private func writeProjectManifest(_ project: OpenGraphiteProject, to projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(project.normalizedInternalIDs())
        try data.write(to: projectURL, options: .atomic)
    }

    /// 論理名（日本語）: 初期HTML本文生成関数
    /// 処理概要: 新規 project の最初の編集対象になる OpenGraphite HTML body を返します。
    ///
    /// - Parameter projectName: `<Heading>` に表示する project 名。
    /// - Returns: standalone HTML の body に入れる OpenGraphite markup。
    private static func initialBodyHTML(projectName: String) -> String {
        """
            <OpenGraphitePage data-og-id="home-root" data-og-type="page" data-og-layout="vertical">
              <Heading data-og-id="headline" data-og-type="text">\(escapeText(projectName))</Heading>
            </OpenGraphitePage>
        """
    }

    /// 論理名（日本語）: project URL正規化関数
    /// 処理概要: `.ogp` 拡張子がない作成先に `.ogp` を補完します。
    ///
    /// - Parameter url: ユーザー指定 URL。
    /// - Returns: `.ogp` 拡張子を持つ標準化済み URL。
    private static func normalizedProjectURL(_ url: URL) -> URL {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.pathExtension.lowercased() != "ogp" else {
            return standardizedURL
        }
        return standardizedURL.appendingPathExtension("ogp")
    }

    /// 論理名（日本語）: リポジトリルート相対パス生成関数
    /// 処理概要: `.ogp` 配置ディレクトリから project root への相対 path を返し、同一ディレクトリの場合は未指定にします。
    ///
    /// - Parameters:
    ///   - projectDirectoryURL: `.ogp` を配置するディレクトリ。
    ///   - projectRootURL: HTML/CSS を解決する project root。
    /// - Returns: `.ogp` に保存する `repositoryRoot`。同一ディレクトリの場合は `nil`。
    private static func repositoryRoot(from projectDirectoryURL: URL, to projectRootURL: URL) -> String? {
        let path = relativePath(from: projectDirectoryURL, to: projectRootURL)
        return path == "." ? nil : path
    }

    /// 論理名（日本語）: project名解決関数
    /// 処理概要: `.ogp` ファイル名から表示名を作り、空の場合は既定名へ戻します。
    ///
    /// - Parameter projectURL: 新規 `.ogp` URL。
    /// - Returns: `.ogp` に保存する project 表示名。
    private static func projectName(from projectURL: URL) -> String {
        let name = projectURL
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled" : name
    }

    /// 論理名（日本語）: bundled CSS解決関数
    /// 処理概要: アプリバンドル resources 内の `CSS/OpenGraphite.css` を探します。
    ///
    /// - Returns: 見つかった OpenGraphite.css URL。見つからない場合は `nil`。
    private static func bundledCSSLibraryURL() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(Self.cssLibraryPath),
            Bundle.main.url(forResource: "OpenGraphite", withExtension: "css", subdirectory: "CSS")
        ]

        return candidates
            .compactMap { $0?.standardizedFileURL }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// 論理名（日本語）: 相対path生成関数
    /// 処理概要: 基準ディレクトリから対象 URL への相対 path を POSIX 区切りで返します。
    ///
    /// - Parameters:
    ///   - directoryURL: 基準ディレクトリ URL。
    ///   - targetURL: 参照先 URL。
    /// - Returns: 相対 path。算出できない場合は対象 URL の path。
    private static func relativePath(from directoryURL: URL, to targetURL: URL) -> String {
        let baseComponents = directoryURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0
        while sharedCount < baseComponents.count,
              sharedCount < targetComponents.count,
              baseComponents[sharedCount] == targetComponents[sharedCount] {
            sharedCount += 1
        }
        guard sharedCount > 0 else {
            return targetURL.path
        }
        let up = Array(repeating: "..", count: baseComponents.count - sharedCount)
        let down = Array(targetComponents.dropFirst(sharedCount))
        let path = (up + down).joined(separator: "/")
        return path.isEmpty ? "." : path
    }

    /// 論理名（日本語）: HTMLテキストescape関数
    /// 処理概要: 初期 HTML body に埋め込むテキストを最小限 escape します。
    ///
    /// - Parameter value: HTML text として埋め込む値。
    /// - Returns: HTML text 向けに escape した文字列。
    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
