import Foundation

/// 論理名（日本語）: Agent向けノード
/// 概要: CLI / MCP が返す OpenGraphite HTML ノードの JSON 表現です。
///
/// プロパティ:
/// - `id`: `data-og-id`。
/// - `tagName`: 小文字化した HTML タグ名。
/// - `type`: `data-og-type`。
/// - `layout`: `data-og-layout`。
/// - `role`: `data-og-role`。
/// - `cssVariables`: inline style 内の `--og-*` 変数。
/// - `hidden`: `data-og-hidden` 状態。
/// - `locked`: `data-og-locked` 状態。
/// - `depth`: DOM 階層深度。
/// - `parentID`: 最も近い OpenGraphite 親ノードの `data-og-id`。
/// - `textContent`: ノード配下のプレーンテキスト。
/// - `attributes`: 開始タグの属性辞書。
struct OpenGraphiteAgentNode: Codable, Equatable {
    var id: String
    var tagName: String
    var type: String
    var layout: String?
    var role: String?
    var cssVariables: [String: String]
    var hidden: Bool
    var locked: Bool
    var depth: Int
    var parentID: String?
    var textContent: String?
    var attributes: [String: String]
}

/// 論理名（日本語）: Agent診断
/// 概要: CLI / MCP / validation が返す問題、警告、情報メッセージを表します。
///
/// プロパティ:
/// - `severity`: error、warning、info。
/// - `code`: 機械判定用コード。
/// - `message`: 人間向け説明。
/// - `path`: 対象ファイルパス。
/// - `nodeID`: 関連する `data-og-id`。
struct OpenGraphiteDiagnostic: Codable, Equatable {
    var severity: OpenGraphiteDiagnosticSeverity
    var code: String
    var message: String
    var path: String?
    var nodeID: String?
}

/// 論理名（日本語）: Agent診断重要度
/// 概要: validation 結果の重要度を表します。
///
/// 定義内容:
/// - `error`: write を止める問題。
/// - `warning`: write は止めないが注意が必要な問題。
/// - `info`: 補助情報。
enum OpenGraphiteDiagnosticSeverity: String, Codable, Equatable {
    case error
    case warning
    case info
}

/// 論理名（日本語）: ページグラフ応答
/// 概要: HTML ページから抽出した node graph と diagnostics を保持します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `nodes`: 抽出された node 一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageGraph: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索応答
/// 概要: 条件に一致した OpenGraphite node 一覧を返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `query`: 適用した検索条件。
/// - `nodes`: 条件に一致した node。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteNodeQueryResult: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var query: OpenGraphiteNodeQuery
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索条件
/// 概要: CLI / MCP が `data-og-id`、type、role、tag、text で node を絞り込む条件です。
///
/// プロパティ:
/// - `idContains`: `data-og-id` に含まれる文字列。
/// - `type`: `data-og-type` の完全一致。
/// - `role`: `data-og-role` の完全一致。
/// - `tag`: tag name の完全一致。
/// - `textContains`: textContent に含まれる文字列。
struct OpenGraphiteNodeQuery: Codable, Equatable {
    var idContains: String?
    var type: String?
    var role: String?
    var tag: String?
    var textContains: String?
}

/// 論理名（日本語）: 検証応答
/// 概要: HTML または project の validation 結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `valid`: error がない場合は `true`。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteValidationResult: Codable, Equatable {
    var schemaVersion: String
    var valid: Bool
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ページ作成応答
/// 概要: HTML page file 作成結果と作成後 graph を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: ファイルを書き込んだ場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `graph`: 作成後 page graph。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageWriteResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var path: String
    var graph: OpenGraphitePageGraph?
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクト要約応答
/// 概要: `.ogp` と解決済み HTML / CSS 参照を CLI / MCP 向けに表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `projectName`: プロジェクト名。
/// - `projectURL`: `.ogp` の URL。
/// - `rootURL`: 解決済みリポジトリルート。
/// - `htmlRoot`: HTML root。
/// - `cssURL`: CSS library URL。
/// - `chapters`: Chapter 要約一覧。
/// - `pages`: 全 Chapter のページ要約一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectSummary: Codable, Equatable {
    var schemaVersion: String
    var projectName: String
    var projectURL: String
    var rootURL: String
    var htmlRoot: String
    var cssURL: String
    var chapters: [OpenGraphiteChapterSummary]
    var pages: [OpenGraphitePageSummary]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Chapter要約
/// 概要: `.ogp` 内の Chapter と、その Chapter に属する page summary を JSON 出力向けに表します。
///
/// プロパティ:
/// - `id`: Chapter ID。
/// - `title`: Chapter 表示名。
/// - `pages`: Chapter 内のページ要約一覧。
struct OpenGraphiteChapterSummary: Codable, Equatable {
    var id: String
    var title: String?
    var pages: [OpenGraphitePageSummary]
}

/// 論理名（日本語）: ページ要約
/// 概要: `.ogp` 内のページと解決済み HTML URL を JSON 出力向けに表します。
///
/// プロパティ:
/// - `chapterID`: 所属 Chapter ID。
/// - `id`: ページ ID。
/// - `path`: `htmlRoot` からの相対パス。
/// - `htmlURL`: 解決済み HTML URL。
/// - `canvas`: キャンバス定義。
struct OpenGraphitePageSummary: Codable, Equatable {
    var chapterID: String
    var id: String
    var path: String
    var htmlURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ参照
/// 概要: `.ogp` の `chapters[].pages[]` から解決された編集対象 HTML と読み取り許可範囲を表します。
///
/// プロパティ:
/// - `projectURL`: 参照元 `.ogp` の URL。
/// - `chapterID`: `.ogp` 内の Chapter ID。
/// - `pageID`: `.ogp` 内の page ID。
/// - `path`: `htmlRoot` から見た HTML path。
/// - `htmlURL`: 解決済み HTML URL。
/// - `rootURL`: HTML / CSS / assets の読み取り許可ルート。
/// - `canvas`: `.ogp` 上の canvas 配置。
struct OpenGraphiteProjectPageReference: Codable, Equatable {
    var projectURL: String
    var chapterID: String
    var pageID: String
    var path: String
    var htmlURL: String
    var rootURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ作成応答
/// 概要: `.ogp` を経由した HTML 作成と page entry 登録の結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: HTML と `.ogp` の両方が更新された場合は `true`。
/// - `project`: 更新後 project summary。
/// - `page`: 追加された page summary。
/// - `htmlPath`: 作成対象 HTML パス。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectPageCreateResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var project: OpenGraphiteProjectSummary?
    var page: OpenGraphitePageSummary?
    var htmlPath: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクトページ内部ターゲット
/// 概要: core 内部で `.ogp` page と解決済み HTML URL をまとめて渡すための値です。
///
/// プロパティ:
/// - `loadedProject`: 読み込み済み `.ogp`。
/// - `chapter`: 対象 page entry を含む Chapter。
/// - `page`: 対象 page entry。
/// - `htmlURL`: 解決済み HTML URL。
private struct OpenGraphiteProjectPageTarget {
    var loadedProject: LoadedOpenGraphiteProject
    var chapter: OpenGraphiteChapter
    var page: OpenGraphitePage
    var htmlURL: URL
}

/// 論理名（日本語）: プロジェクトページ位置
/// 概要: `.ogp` 内で対象 page が属する Chapter index と page index を表します。
///
/// プロパティ:
/// - `chapterIndex`: Chapter 配列内の位置。
/// - `pageIndex`: Chapter 内 pages 配列の位置。
private struct OpenGraphiteProjectPageLocation {
    var chapterIndex: Int
    var pageIndex: Int
}

/// 論理名（日本語）: HTML変更応答
/// 概要: node 単位編集の結果 HTML と diagnostics を保持します。
///
/// プロパティ:
/// - `html`: 更新済み HTML。
/// - `diagnostics`: 変更時に発生した diagnostics。
struct OpenGraphiteHTMLMutationResult: Equatable {
    var html: String
    var diagnostics: [OpenGraphiteDiagnostic]

    /// 論理名（日本語）: 失敗結果生成関数
    /// 処理概要: 単一 diagnostic を持つ HTML 変更失敗結果を作ります。
    ///
    /// - Parameters:
    ///   - html: 元の HTML。
    ///   - diagnostic: 失敗理由。
    /// - Returns: 失敗結果。
    static func failure(html: String, diagnostic: OpenGraphiteDiagnostic) -> OpenGraphiteHTMLMutationResult {
        OpenGraphiteHTMLMutationResult(html: html, diagnostics: [diagnostic])
    }
}

/// 論理名（日本語）: Agent編集応答
/// 概要: CLI / MCP の write operation が返す対象 node と diagnostics を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: ファイルを書き換えた場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `node`: 更新後 node。
/// - `diagnostics`: 検証結果。
/// - `insertedNodes`: 挿入操作で新たに増えた node。
struct OpenGraphiteEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var node: OpenGraphiteAgentNode?
    var diagnostics: [OpenGraphiteDiagnostic]
    var insertedNodes: [OpenGraphiteAgentNode]?
}

/// 論理名（日本語）: HTML挿入位置
/// 概要: HTML 断片または既存 node をどこへ配置するかを表します。
///
/// 定義内容:
/// - `before`: 対象 node の直前。
/// - `after`: 対象 node の直後。
/// - `prepend`: 対象 node の最初の子。
/// - `append`: 対象 node の最後の子。
enum OpenGraphiteHTMLInsertionPosition: String, Codable, Equatable {
    case before
    case after
    case prepend
    case append
}

/// 論理名（日本語）: Agent core
/// 概要: `ogkiln` CLI と OpenGraphite MCP server が共有する project / HTML graph / validation / edit 処理です。
///
/// メソッド:
/// - `inspectProject(at:)`: `.ogp` を解決して要約する。
/// - `addProjectPage(projectURL:id:path:canvas:)`: `.ogp` に page entry を追加する。
/// - `createProjectPage(projectURL:id:path:canvas:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML 作成と page entry 登録を一体で行う。
/// - `projectPageReference(projectURL:pageID:)`: `.ogp` の page ID から HTML を解決する。
/// - `placeProjectPage(projectURL:id:x:y:width:height:)`: 既存 page entry の canvas 配置を更新する。
/// - `createPage(at:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML page file を作成する。
/// - `pageGraph(at:)`: HTML から node graph を抽出する。
/// - `validateHTML(at:)`: HTML を契約に対して検証する。
/// - `setCSSVariable(_:value:nodeID:htmlURL:)`: node 単位で CSS 変数を更新する。
/// - `setAttribute(_:value:nodeID:htmlURL:)`: node 単位で属性を更新する。
/// - `setTextContent(_:nodeID:htmlURL:)`: node の text content を更新する。
/// - `insertHTML(_:anchorNodeID:position:htmlURL:)`: anchor node 基準で HTML 断片を挿入する。
/// - `replaceNodeHTML(_:nodeID:htmlURL:)`: node 全体を HTML 断片で置換する。
/// - `deleteNode(nodeID:htmlURL:)`: node 全体を削除する。
/// - `moveNode(nodeID:targetNodeID:position:htmlURL:)`: 既存 node を移動する。
/// - `copyNode(nodeID:targetNodeID:position:idPrefix:htmlURL:)`: node subtree を複製する。
struct OpenGraphiteAgentCore {
    static let schemaVersion = "0.1"

    var contract: OpenGraphiteContract

    /// 論理名（日本語）: Agent core初期化関数
    /// 処理概要: CLI / MCP で共有する契約を保持します。
    ///
    /// - Parameter contract: 検証に使う OpenGraphite 契約。
    init(contract: OpenGraphiteContract) {
        self.contract = contract
    }

    /// 論理名（日本語）: プロジェクト要約関数
    /// 処理概要: `.ogp` を読み込み、解決済み URL と diagnostics を返します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: project summary。
    func inspectProject(at url: URL) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: url)
        var diagnostics: [OpenGraphiteDiagnostic] = []
        if !FileManager.default.fileExists(atPath: loadedProject.cssURL.path) {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .warning,
                    code: "missing-css-library",
                    message: "CSS library が見つかりません: \(loadedProject.cssURL.path)",
                    path: loadedProject.cssURL.path,
                    nodeID: nil
                )
            )
        }

        let chapters = loadedProject.project.chapters.map { chapter in
            let pages = chapter.pages.map { page in
                pageSummary(for: page, chapterID: chapter.id, loadedProject: loadedProject)
            }
            return OpenGraphiteChapterSummary(
                id: chapter.id,
                title: chapter.title,
                pages: pages
            )
        }
        let pages = chapters.flatMap(\.pages)

        return OpenGraphiteProjectSummary(
            schemaVersion: Self.schemaVersion,
            projectName: loadedProject.project.name,
            projectURL: loadedProject.fileURL.path,
            rootURL: loadedProject.rootURL.path,
            htmlRoot: loadedProject.project.htmlRoot,
            cssURL: loadedProject.cssURL.path,
            chapters: chapters,
            pages: pages,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページ参照解決関数
    /// 処理概要: `.ogp` の page ID から編集対象 HTML と読み取り許可ルートを解決します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 解決済み page reference。
    func projectPageReference(projectURL: URL, pageID: String) throws -> OpenGraphiteProjectPageReference {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let target = try projectPageTarget(loadedProject: loadedProject, pageID: pageID)
        return OpenGraphiteProjectPageReference(
            projectURL: loadedProject.fileURL.path,
            chapterID: target.chapter.id,
            pageID: target.page.id,
            path: target.page.path,
            htmlURL: target.htmlURL.path,
            rootURL: loadedProject.rootURL.path,
            canvas: target.page.canvas
        )
    }

    /// 論理名（日本語）: プロジェクトページグラフ生成関数
    /// 処理概要: `.ogp` の page ID で明示された HTML だけを対象に node graph を生成します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: page graph。
    func pageGraph(projectURL: URL, pageID: String) throws -> OpenGraphitePageGraph {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try pageGraph(at: target.htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ追加関数
    /// 処理概要: `.ogp` の既定 Chapter pages に新しい HTML ページ定義を追加し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    /// - Returns: 更新後 project summary。
    func addProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        var project = loadedProject.project
        let targetChapterIndex = try defaultChapterIndex(in: project)
        if project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }
        let htmlURL = loadedProject.rootURL.appendingPathComponent(project.htmlRoot).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: "追加する page HTML が見つかりません: \(htmlURL.path)")
        }

        project.chapters[targetChapterIndex].pages.append(OpenGraphitePage(id: id, path: path, canvas: canvas))
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトページ作成関数
    /// 処理概要: `.ogp` の `htmlRoot` 配下へ HTML を作成し、同じ処理で既定 Chapter pages に登録します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: stylesheet href。`nil` の場合は `.ogp` の CSS 参照から相対 path を計算します。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存 HTML を上書きするか。
    /// - Returns: 作成と登録の結果。
    func createProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        title: String,
        lang: String,
        stylesheetPath: String?,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphiteProjectPageCreateResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        if loadedProject.project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if loadedProject.project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }

        let htmlURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(path)
            .standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))

        let fileManager = FileManager.default
        let previousData = fileManager.fileExists(atPath: htmlURL.path) ? try Data(contentsOf: htmlURL) : nil
        let stylesheet = stylesheetPath ?? Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let writeResult = try createPage(
            at: htmlURL,
            title: title,
            lang: lang,
            stylesheetPath: stylesheet,
            bodyHTML: bodyHTML,
            overwrite: overwrite
        )
        guard writeResult.created else {
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                project: try? inspectProject(at: projectURL),
                page: nil,
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics
            )
        }

        do {
            let summary = try addProjectPage(projectURL: projectURL, id: id, path: path, canvas: canvas)
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: true,
                project: summary,
                page: summary.pages.first { $0.id == id },
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics + summary.diagnostics
            )
        } catch {
            if let previousData {
                try? previousData.write(to: htmlURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: htmlURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: プロジェクトページ配置関数
    /// 処理概要: `.ogp` の既存 page entry に対して canvas 座標とサイズを部分更新し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新する page ID。
    ///   - x: 更新後 X 座標。`nil` の場合は既存値を維持します。
    ///   - y: 更新後 Y 座標。`nil` の場合は既存値を維持します。
    ///   - width: 更新後プレビュー幅。`nil` の場合は既存値を維持します。
    ///   - height: 更新後プレビュー高さ。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 project summary。
    func placeProjectPage(
        projectURL: URL,
        id: String,
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let pageLocation = pageLocation(in: project, pageID: id) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" が見つかりません。")
        }
        if let width, width <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--width は 0 より大きい数値で指定してください。")
        }
        if let height, height <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--height は 0 より大きい数値で指定してください。")
        }

        let currentCanvas = project.chapters[pageLocation.chapterIndex].pages[pageLocation.pageIndex].canvas
        project.chapters[pageLocation.chapterIndex].pages[pageLocation.pageIndex].canvas = OpenGraphiteCanvas(
            x: x ?? currentCanvas.x,
            y: y ?? currentCanvas.y,
            width: width ?? currentCanvas.width,
            height: height ?? currentCanvas.height
        )
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: HTMLページ作成関数
    /// 処理概要: 指定 body HTML を含む standalone HTML を作成し、OpenGraphite contract で検証して保存します。
    ///
    /// - Parameters:
    ///   - url: 作成する HTML ファイル URL。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: OpenGraphite.css への相対または絶対参照。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存ファイルを上書きするか。
    /// - Returns: 作成結果。
    func createPage(
        at url: URL,
        title: String,
        lang: String,
        stylesheetPath: String,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphitePageWriteResult {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path), !overwrite {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "page-file-exists",
                        message: "\(url.path) は既に存在します。上書きする場合は --overwrite を指定してください。",
                        path: url.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let html = """
        <!doctype html>
        <html lang="\(Self.escapeAttribute(lang))">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(Self.escapeText(title))</title>
            <link rel="stylesheet" href="\(Self.escapeAttribute(stylesheetPath))">
          </head>
          <body>
        \(bodyHTML.trimmingCharacters(in: .newlines))
          </body>
        </html>
        """

        let document = OpenGraphiteHTMLDocument(html: html)
        let diagnostics = validate(nodes: document.nodes(), tags: document.parsedTags(), path: url.path)
        guard !diagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: diagnostics
            )
        }

        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try html.write(to: url, atomically: true, encoding: .utf8)
        let graph = try pageGraph(at: url)
        return OpenGraphitePageWriteResult(
            schemaVersion: Self.schemaVersion,
            created: true,
            path: url.path,
            graph: graph,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: ページグラフ生成関数
    /// 処理概要: 指定 HTML から node graph と validation diagnostics を生成します。
    ///
    /// - Parameter url: HTML ファイル URL。
    /// - Returns: page graph。
    func pageGraph(at url: URL) throws -> OpenGraphitePageGraph {
        let html = try String(contentsOf: url, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)
        let nodes = document.nodes()
        return OpenGraphitePageGraph(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            nodes: nodes,
            diagnostics: validate(nodes: nodes, tags: document.parsedTags(), path: url.path)
        )
    }

    /// 論理名（日本語）: ノード検索関数
    /// 処理概要: HTML page graph から指定条件に一致する OpenGraphite node を抽出します。
    ///
    /// - Parameters:
    ///   - url: HTML ファイル URL。
    ///   - query: 絞り込み条件。
    /// - Returns: node query result。
    func queryNodes(at url: URL, query: OpenGraphiteNodeQuery) throws -> OpenGraphiteNodeQueryResult {
        let graph = try pageGraph(at: url)
        let nodes = graph.nodes.filter { node in
            if let idContains = query.idContains, !node.id.localizedCaseInsensitiveContains(idContains) {
                return false
            }
            if let type = query.type, node.type != type {
                return false
            }
            if let role = query.role, node.role != role {
                return false
            }
            if let tag = query.tag, node.tagName != tag.lowercased() {
                return false
            }
            if let textContains = query.textContains,
               !(node.textContent ?? "").localizedCaseInsensitiveContains(textContains) {
                return false
            }
            return true
        }
        return OpenGraphiteNodeQueryResult(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            query: query,
            nodes: nodes,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: HTML検証関数
    /// 処理概要: 指定 HTML を OpenGraphite 契約に対して検証します。
    ///
    /// - Parameter url: HTML ファイル URL。
    /// - Returns: validation result。
    func validateHTML(at url: URL) throws -> OpenGraphiteValidationResult {
        let graph = try pageGraph(at: url)
        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !graph.diagnostics.contains { $0.severity == .error },
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクト検証関数
    /// 処理概要: `.ogp` と参照 HTML / CSS をまとめて検証します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: validation result。
    func validateProject(at url: URL) throws -> OpenGraphiteValidationResult {
        let summary = try inspectProject(at: url)
        var diagnostics = summary.diagnostics
        for page in summary.pages {
            diagnostics.append(contentsOf: try validateHTML(at: URL(fileURLWithPath: page.htmlURL)).diagnostics)
        }

        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !diagnostics.contains { $0.severity == .error },
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページノード検索関数
    /// 処理概要: `.ogp` の page ID で明示された HTML から node を検索します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    ///   - query: 絞り込み条件。
    /// - Returns: node query result。
    func queryNodes(
        projectURL: URL,
        pageID: String,
        query: OpenGraphiteNodeQuery
    ) throws -> OpenGraphiteNodeQueryResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try queryNodes(at: target.htmlURL, query: query)
    }

    /// 論理名（日本語）: ノード取得関数
    /// 処理概要: HTML から一意な `data-og-id` に一致する node を取得します。
    ///
    /// - Parameters:
    ///   - id: 対象 `data-og-id`。
    ///   - url: HTML ファイル URL。
    /// - Returns: edit result 形式の node 取得結果。
    func node(id: String, at url: URL) throws -> OpenGraphiteEditResult {
        let graph = try pageGraph(at: url)
        let matches = graph.nodes.filter { $0.id == id }
        let diagnostics = uniqueNodeDiagnostics(matches: matches, id: id, path: url.path)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: url.path,
            node: matches.count == 1 ? matches[0] : nil,
            diagnostics: diagnostics,
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: プロジェクトページノード取得関数
    /// 処理概要: `.ogp` の page ID で明示された HTML から `data-og-id` に一致する node を取得します。
    ///
    /// - Parameters:
    ///   - id: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: edit result 形式の node 取得結果。
    func node(id: String, projectURL: URL, pageID: String) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try node(id: id, at: target.htmlURL)
    }

    /// 論理名（日本語）: CSS変数ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node に CSS 変数を設定し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS 変数。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setCSSVariable(_ variable: String, value: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingCSSVariable(
            variable,
            value: value,
            forNodeID: nodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: nodeID)
    }

    /// 論理名（日本語）: プロジェクトページCSS変数更新関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node の CSS 変数を更新します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS 変数。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func setCSSVariable(
        _ variable: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try setCSSVariable(variable, value: value, nodeID: nodeID, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード属性ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node に許可済み属性を設定し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setAttribute(_ name: String, value: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingAttribute(
            name: name,
            value: value,
            forNodeID: nodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: nodeID)
    }

    /// 論理名（日本語）: プロジェクトページ属性更新関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node の編集可能属性を更新します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func setAttribute(
        _ name: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try setAttribute(name, value: value, nodeID: nodeID, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: テキスト内容ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の text content を更新し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。HTML としてではなく text として escape されます。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setTextContent(_ text: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingTextContent(
            text,
            forNodeID: nodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: nodeID)
    }

    /// 論理名（日本語）: プロジェクトページテキスト更新関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node の text content を更新します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func setTextContent(
        _ text: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try setTextContent(text, nodeID: nodeID, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: HTML断片挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の anchor node を基準に HTML 断片を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-id`。
    ///   - position: 挿入位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).insertingHTML(
            fragmentHTML,
            relativeToNodeID: anchorNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: anchorNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページHTML挿入関数
    /// 処理概要: `.ogp` の page ID で明示された HTML に対して anchor node 基準で HTML 断片を挿入します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-id`。
    ///   - position: 挿入位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try insertHTML(fragmentHTML, anchorNodeID: anchorNodeID, position: position, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: 子HTML先頭挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の先頭へ子 HTML を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func prependChildHTML(_ childHTML: String, parentNodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, htmlURL: htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ子HTML先頭挿入関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node の先頭へ子 HTML を挿入します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func prependChildHTML(
        _ childHTML: String,
        parentNodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, projectURL: projectURL, pageID: pageID)
    }

    /// 論理名（日本語）: ノードHTML置換ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node 全体を HTML 断片で置換し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func replaceNodeHTML(_ replacementHTML: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).replacingNodeHTML(
            replacementHTML,
            nodeID: nodeID,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: nodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノードHTML置換関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node subtree を HTML 断片で置換します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func replaceNodeHTML(
        _ replacementHTML: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try replaceNodeHTML(replacementHTML, nodeID: nodeID, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード削除ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node subtree を削除し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).deletingNode(
            nodeID: nodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: nodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード削除関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node subtree を削除します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, projectURL: URL, pageID: String) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try deleteNode(nodeID: nodeID, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード移動ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を別 node 基準位置へ移動し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-id`。
    ///   - targetNodeID: 移動先基準 `data-og-id`。
    ///   - position: 移動先位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).movingNode(
            nodeID: nodeID,
            relativeToNodeID: targetNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: nodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード移動関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node subtree を移動します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-id`。
    ///   - targetNodeID: 移動先基準 `data-og-id`。
    ///   - position: 移動先位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try moveNode(nodeID: nodeID, targetNodeID: targetNodeID, position: position, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード複製ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を `data-og-id` prefix 付きで複製し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-id`。
    ///   - targetNodeID: 複製先基準 `data-og-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).copyingNode(
            nodeID: nodeID,
            relativeToNodeID: targetNodeID,
            position: position,
            idPrefix: idPrefix,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: "\(idPrefix)\(nodeID)",
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノード複製関数
    /// 処理概要: `.ogp` の page ID で明示された HTML 内 node subtree を prefix 付きで複製します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-id`。
    ///   - targetNodeID: 複製先基準 `data-og-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try copyNode(
            nodeID: nodeID,
            targetNodeID: targetNodeID,
            position: position,
            idPrefix: idPrefix,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: プロジェクトページターゲット解決関数
    /// 処理概要: `.ogp` を読み込み、page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(projectURL: URL, pageID: String) throws -> OpenGraphiteProjectPageTarget {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        return try projectPageTarget(loadedProject: loadedProject, pageID: pageID)
    }

    /// 論理名（日本語）: 読み込み済みプロジェクトページターゲット解決関数
    /// 処理概要: 既に読み込んだ `.ogp` から page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - loadedProject: 読み込み済み `.ogp`。
    ///   - pageID: `.ogp` 内の page ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(
        loadedProject: LoadedOpenGraphiteProject,
        pageID: String
    ) throws -> OpenGraphiteProjectPageTarget {
        guard let location = pageLocation(in: loadedProject.project, pageID: pageID) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(pageID)\" が .ogp に存在しません。")
        }
        let chapter = loadedProject.project.chapters[location.chapterIndex]
        let page = chapter.pages[location.pageIndex]
        try validateProjectPagePath(page.path)
        let htmlURL = loadedProject.htmlURL(for: page).standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: ".ogp page \"\(pageID)\" の HTML が見つかりません: \(htmlURL.path)")
        }
        return OpenGraphiteProjectPageTarget(
            loadedProject: loadedProject,
            chapter: chapter,
            page: page,
            htmlURL: htmlURL
        )
    }

    /// 論理名（日本語）: 既定Chapter位置取得関数
    /// 処理概要: page 追加先として使う先頭 Chapter の index を返します。
    ///
    /// - Parameter project: 対象 `.ogp` プロジェクト。
    /// - Returns: 先頭 Chapter の index。
    private func defaultChapterIndex(in project: OpenGraphiteProject) throws -> Int {
        guard !project.chapters.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: ".ogp に chapters がありません。")
        }
        return 0
    }

    /// 論理名（日本語）: ページ位置検索関数
    /// 処理概要: Chapter 配列を横断し、指定 page ID の Chapter index と page index を返します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - pageID: 検索する page ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func pageLocation(in project: OpenGraphiteProject, pageID: String) -> OpenGraphiteProjectPageLocation? {
        for chapterIndex in project.chapters.indices {
            if let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: { $0.id == pageID }) {
                return OpenGraphiteProjectPageLocation(chapterIndex: chapterIndex, pageIndex: pageIndex)
            }
        }
        return nil
    }

    /// 論理名（日本語）: ページ要約生成関数
    /// 処理概要: Chapter ID と page 定義から、解決済み HTML URL を含む summary を生成します。
    ///
    /// - Parameters:
    ///   - page: 要約する page 定義。
    ///   - chapterID: 所属 Chapter ID。
    ///   - loadedProject: 読み込み済み `.ogp`。
    /// - Returns: JSON 出力用 page summary。
    private func pageSummary(
        for page: OpenGraphitePage,
        chapterID: String,
        loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphitePageSummary {
        OpenGraphitePageSummary(
            chapterID: chapterID,
            id: page.id,
            path: page.path,
            htmlURL: loadedProject.htmlURL(for: page).path,
            canvas: page.canvas
        )
    }

    /// 論理名（日本語）: プロジェクトページパス検証関数
    /// 処理概要: `chapters[].pages[].path` が `htmlRoot` 相対の明示的な HTML path として安全かを検証します。
    ///
    /// - Parameter path: `htmlRoot` から見た HTML path。
    private func validateProjectPagePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if path.isEmpty
            || path.hasPrefix("/")
            || path.hasSuffix("/")
            || components.contains("")
            || components.contains("..")
            || components.contains(".")
            || URL(fileURLWithPath: path).pathExtension.lowercased() != "html" {
            throw OpenGraphiteAgentCoreError(message: "page path は htmlRoot 配下の相対 HTML path で指定してください: \(path)")
        }
    }

    /// 論理名（日本語）: HTML配置範囲検証関数
    /// 処理概要: 解決済み HTML URL が `.ogp` の `htmlRoot` 配下に残っていることを確認します。
    ///
    /// - Parameters:
    ///   - htmlURL: 解決済み HTML URL。
    ///   - htmlRootURL: `.ogp` から解決した HTML root URL。
    private func ensureHTMLURL(_ htmlURL: URL, staysInside htmlRootURL: URL) throws {
        let rootPath = htmlRootURL.standardizedFileURL.path
        let htmlPath = htmlURL.standardizedFileURL.path
        guard htmlPath == rootPath || htmlPath.hasPrefix(rootPath + "/") else {
            throw OpenGraphiteAgentCoreError(message: "page HTML は htmlRoot 配下に配置してください: \(htmlPath)")
        }
    }

    /// 論理名（日本語）: 相対パス生成関数
    /// 処理概要: HTML 配置ディレクトリから CSS library への相対 path を生成します。
    ///
    /// - Parameters:
    ///   - directoryURL: 参照元ディレクトリ URL。
    ///   - targetURL: 参照先ファイル URL。
    /// - Returns: 相対 path。
    private static func relativePath(from directoryURL: URL, to targetURL: URL) -> String {
        let sourceComponents = directoryURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0
        while sharedCount < sourceComponents.count,
              sharedCount < targetComponents.count,
              sourceComponents[sharedCount] == targetComponents[sharedCount] {
            sharedCount += 1
        }

        let upward = Array(repeating: "..", count: max(sourceComponents.count - sharedCount, 0))
        let downward = Array(targetComponents.dropFirst(sharedCount))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    private func persistMutation(
        _ mutation: OpenGraphiteHTMLMutationResult,
        htmlURL: URL,
        nodeID: String,
        insertedNodeIDsBeforeMutation: Set<String>? = nil
    ) throws -> OpenGraphiteEditResult {
        let blockingDiagnostics = mutation.diagnostics.filter { $0.severity == .error }
        guard blockingDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) },
                insertedNodes: nil
            )
        }

        let candidateDocument = OpenGraphiteHTMLDocument(html: mutation.html)
        let candidateDiagnostics = validate(
            nodes: candidateDocument.nodes(),
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path
        )
        let allDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + candidateDiagnostics
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: allDiagnostics,
                insertedNodes: nil
            )
        }

        try mutation.html.write(to: htmlURL, atomically: true, encoding: .utf8)
        let graph = try pageGraph(at: htmlURL)
        let node = graph.nodes.first { $0.id == nodeID }
        let insertedNodes = insertedNodeIDsBeforeMutation.map { beforeIDs in
            graph.nodes.filter { !beforeIDs.contains($0.id) }
        }
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: true,
            path: htmlURL.path,
            node: node,
            diagnostics: graph.diagnostics,
            insertedNodes: insertedNodes
        )
    }

    private func writeProject(_ project: OpenGraphiteProject, to projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(project)
        data.append(0x0A)
        try data.write(to: projectURL, options: .atomic)
    }

    private func validate(
        nodes: [OpenGraphiteAgentNode],
        tags: [OpenGraphiteHTMLTag],
        path: String
    ) -> [OpenGraphiteDiagnostic] {
        var diagnostics: [OpenGraphiteDiagnostic] = []
        let groupedIDs = Dictionary(grouping: nodes, by: \.id)

        for (id, matches) in groupedIDs where matches.count > 1 {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-id",
                    message: "data-og-id \"\(id)\" が重複しています。",
                    path: path,
                    nodeID: id
                )
            )
        }

        for tag in tags {
            for attribute in tag.attributes where contract.runtimeAttributeSet.contains(attribute.name) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-attribute-persisted",
                        message: "\(attribute.name) は正本 HTML に残せない実行時属性です。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    )
                )
            }
        }

        for node in nodes {
            if node.type.isEmpty {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-data-og-type",
                        message: "\(node.id) に data-og-type がありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            } else if !contract.typeSet.contains(node.type) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unknown-data-og-type",
                        message: "\(node.type) は既知の data-og-type ではありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            if let layout = node.layout, !contract.layoutSet.contains(layout) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unknown-data-og-layout",
                        message: "\(layout) は既知の data-og-layout ではありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            if let role = node.role, !contract.roleSet.contains(role) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-data-og-role",
                        message: "\(role) は OpenGraphite.contract.json に定義されていない role です。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            for key in node.cssVariables.keys.sorted() where !contract.cssVariableSet.contains(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-css-variable",
                        message: "\(key) は OpenGraphite.contract.json に定義されていません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            for key in node.cssVariables.keys.sorted() where contract.runtimeCSSVariableSet.contains(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-css-variable-persisted",
                        message: "\(key) は正本 HTML に残せない実行時 CSS 変数です。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }
        }

        return diagnostics
    }

    private func uniqueNodeDiagnostics(
        matches: [OpenGraphiteAgentNode],
        id: String,
        path: String
    ) -> [OpenGraphiteDiagnostic] {
        if matches.count == 1 {
            return []
        }

        if matches.isEmpty {
            return [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-node",
                    message: "data-og-id \"\(id)\" を持つノードが見つかりません。",
                    path: path,
                    nodeID: id
                )
            ]
        }

        return [
            OpenGraphiteDiagnostic(
                severity: .error,
                code: "duplicate-data-og-id",
                message: "data-og-id \"\(id)\" が \(matches.count) 件あります。",
                path: path,
                nodeID: id
            )
        ]
    }

    private func withPath(_ diagnostic: OpenGraphiteDiagnostic, path: String) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(
            severity: diagnostic.severity,
            code: diagnostic.code,
            message: diagnostic.message,
            path: diagnostic.path ?? path,
            nodeID: diagnostic.nodeID
        )
    }

    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeText(value).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// 論理名（日本語）: Agent coreエラー
/// 概要: project file 更新など、diagnostics ではなく処理自体を止めるエラーです。
///
/// プロパティ:
/// - `message`: エラー説明。
struct OpenGraphiteAgentCoreError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}
