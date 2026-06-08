import AppKit
import Foundation
import WebKit

/// 論理名（日本語）: スクリーンショット種別
/// 概要: `ogkiln screenshot` が出力する画像の対象範囲を表します。
///
/// 定義内容:
/// - `canvas`: `.ogp` の先頭 Chapter に含まれるページ配置を含むキャンバス全体。
/// - `page`: 単一ページ。
/// - `node`: `data-og-internal-id` で指定した単一ノード。
enum OpenGraphiteScreenshotKind: String, Codable, Equatable {
    case canvas
    case page
    case node
}

/// 論理名（日本語）: スクリーンショット対象ページ
/// 概要: キャンバススクリーンショットに含まれたページと配置を JSON 出力向けに表します。
///
/// プロパティ:
/// - `chapterID`: 所属 Chapter ID。
/// - `id`: ページ ID。
/// - `path`: `htmlRoot` から見た HTML path。
/// - `htmlURL`: 解決済み HTML URL。
/// - `canvas`: `.ogp` 上のキャンバス配置。
struct OpenGraphiteScreenshotPage: Codable, Equatable {
    var chapterID: String
    var id: String
    var path: String
    var htmlURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: スクリーンショット結果
/// 概要: `ogkiln screenshot` の出力ファイルとレンダリング対象を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `kind`: スクリーンショット種別。
/// - `outputPath`: PNG 出力先。
/// - `width`: 出力 PNG の実ピクセル幅。
/// - `height`: 出力 PNG の実ピクセル高さ。
/// - `pageID`: 対象ページ ID。
/// - `pageURL`: 対象 HTML URL。
/// - `nodeID`: 対象 `data-og-internal-id`。
/// - `pages`: キャンバススクリーンショットに含めたページ一覧。
/// - `diagnostics`: 補助診断。
struct OpenGraphiteScreenshotResult: Codable, Equatable {
    var schemaVersion: String
    var kind: OpenGraphiteScreenshotKind
    var outputPath: String
    var width: Double
    var height: Double
    var pageID: String?
    var pageURL: String?
    var nodeID: String?
    var pages: [OpenGraphiteScreenshotPage]?
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: スクリーンショットレンダラー
/// 概要: WebKit で HTML をレンダリングし、ページ、ノード、`.ogp` キャンバスを PNG として保存します。
///
/// メソッド:
/// - `captureCanvas(projectURL:outputURL:)`: `.ogp` の先頭 Chapter に含まれるページを合成して保存します。
/// - `capturePage(targetURL:pageID:outputURL:readAccessURL:width:height:fullPage:)`: 単一ページを保存します。
/// - `captureNode(htmlURL:nodeID:outputURL:readAccessURL:width:height:padding:)`: 指定ノードを切り抜いて保存します。
struct OpenGraphiteScreenshotRenderer {
    private static let defaultViewportWidth: CGFloat = 1440
    private static let defaultViewportHeight: CGFloat = 1200
    private static let defaultCanvasBackground = NSColor(
        calibratedRed: 0.105,
        green: 0.105,
        blue: 0.098,
        alpha: 1
    )

    /// 論理名（日本語）: キャンバススクリーンショット関数
    /// 処理概要: `.ogp` の先頭 Chapter に含まれるページを各 canvas 座標へ配置し、単一 PNG として保存します。
    ///
    /// - Parameters:
    ///   - projectURL: 対象 `.ogp` URL。
    ///   - outputURL: PNG 出力先 URL。
    /// - Returns: スクリーンショット結果。
    func captureCanvas(projectURL: URL, outputURL: URL) throws -> OpenGraphiteScreenshotResult {
        try runWebKitSynchronously {
            try await captureCanvasOnMain(projectURL: projectURL, outputURL: outputURL)
        }
    }

    /// 論理名（日本語）: ページスクリーンショット関数
    /// 処理概要: `.ogp` の page 内部参照 ID または HTML ファイルを WebKit でレンダリングし、PNG として保存します。
    ///
    /// - Parameters:
    ///   - targetURL: `.ogp` または HTML URL。
    ///   - pageID: `.ogp` 内ページを指定する ID。HTML 直接指定時は `nil`。
    ///   - outputURL: PNG 出力先 URL。
    ///   - readAccessURL: HTML 直接指定時の読み取り許可ルート。
    ///   - width: viewport 幅。`.ogp` 指定時は省略すると page canvas 幅を使います。
    ///   - height: viewport 高さ。`.ogp` 指定時は省略すると page canvas 高さを使います。
    ///   - fullPage: document 全体を保存するか。
    /// - Returns: スクリーンショット結果。
    func capturePage(
        targetURL: URL,
        pageID: String?,
        outputURL: URL,
        readAccessURL: URL,
        width: Double?,
        height: Double?,
        fullPage: Bool
    ) throws -> OpenGraphiteScreenshotResult {
        try runWebKitSynchronously {
            try await capturePageOnMain(
                targetURL: targetURL,
                pageID: pageID,
                outputURL: outputURL,
                readAccessURL: readAccessURL,
                width: width,
                height: height,
                fullPage: fullPage
            )
        }
    }

    /// 論理名（日本語）: ノードスクリーンショット関数
    /// 処理概要: HTML 内の `data-og-internal-id` ノードの bounding rect を取得し、その範囲だけを PNG として保存します。
    ///
    /// - Parameters:
    ///   - htmlURL: 対象 HTML URL。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - outputURL: PNG 出力先 URL。
    ///   - readAccessURL: HTML と関連アセットの読み取り許可ルート。
    ///   - width: 初期 viewport 幅。
    ///   - height: 初期 viewport 高さ。
    ///   - padding: 切り抜き範囲へ加える余白。
    ///   - previewContext: エディター preview と同じ条件で注入する runtime Mock State。
    /// - Returns: スクリーンショット結果。
    func captureNode(
        htmlURL: URL,
        nodeID: String,
        outputURL: URL,
        readAccessURL: URL,
        width: Double?,
        height: Double?,
        padding: Double?,
        previewContext: OpenGraphitePreviewContext = .empty
    ) throws -> OpenGraphiteScreenshotResult {
        let resolvedNodeID = OpenGraphiteReferenceID.nodeInternalID(from: nodeID) ?? nodeID
        return try runWebKitSynchronously {
            try await captureNodeOnMain(
                htmlURL: htmlURL,
                nodeID: resolvedNodeID,
                outputURL: outputURL,
                readAccessURL: readAccessURL,
                width: width,
                height: height,
                padding: padding,
                previewContext: previewContext
            )
        }
    }

    @MainActor
    private func captureCanvasOnMain(projectURL: URL, outputURL: URL) async throws -> OpenGraphiteScreenshotResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        guard let chapter = loadedProject.project.chapters.first else {
            throw OpenGraphiteScreenshotError(message: ".ogp に chapters がありません。")
        }
        let pages = chapter.pages
        guard !pages.isEmpty else {
            throw OpenGraphiteScreenshotError(message: ".ogp の Chapter に pages がありません。")
        }

        let minX = pages.map(\.canvas.x).min() ?? 0
        let minY = pages.map(\.canvas.y).min() ?? 0
        let maxX = pages.map { $0.canvas.x + $0.canvas.width }.max() ?? 1
        let maxY = pages.map { $0.canvas.y + $0.canvas.height }.max() ?? 1
        let width = CGFloat(max(maxX - minX, 1))
        let height = CGFloat(max(maxY - minY, 1))
        let snapshots = try await pages.mapAsync { page in
            let image = try await capturePageImage(
                htmlURL: loadedProject.htmlURL(for: page),
                readAccessURL: loadedProject.rootURL,
                viewport: CGSize(width: page.canvas.width, height: page.canvas.height),
                fullPage: false,
                previewContext: page.canvas.previewContext
            )
            return (page: page, image: image)
        }
        let canvasImage = try compositeCanvas(
            snapshots: snapshots,
            minX: minX,
            minY: minY,
            width: width,
            height: height
        )

        let pngSize = try writePNG(canvasImage, to: outputURL)
        return OpenGraphiteScreenshotResult(
            schemaVersion: OpenGraphiteAgentCore.schemaVersion,
            kind: .canvas,
            outputPath: outputURL.path,
            width: pngSize.width,
            height: pngSize.height,
            pageID: nil,
            pageURL: nil,
            nodeID: nil,
            pages: pages.map { page in
                OpenGraphiteScreenshotPage(
                    chapterID: chapter.id,
                    id: page.id,
                    path: page.path,
                    htmlURL: loadedProject.htmlURL(for: page).path,
                    canvas: page.canvas
                )
            },
            diagnostics: []
        )
    }

    @MainActor
    private func capturePageOnMain(
        targetURL: URL,
        pageID: String?,
        outputURL: URL,
        readAccessURL: URL,
        width: Double?,
        height: Double?,
        fullPage: Bool
    ) async throws -> OpenGraphiteScreenshotResult {
        let pageURL: URL
        let accessURL: URL
        let viewport: CGSize
        let resolvedPageID: String?
        let previewContext: OpenGraphitePreviewContext

        if targetURL.pathExtension == "ogp" {
            let loadedProject = try ProjectLoader().loadProject(at: targetURL)
            guard let pageID else {
                throw OpenGraphiteScreenshotError(message: ".ogp の page screenshot には --id が必要です。")
            }
            guard let page = page(in: loadedProject.project, matching: pageID) else {
                throw OpenGraphiteScreenshotError(message: "page id \"\(pageID)\" が見つかりません。")
            }
            pageURL = loadedProject.htmlURL(for: page)
            accessURL = loadedProject.rootURL
            viewport = CGSize(
                width: try positiveSize(width, fallback: page.canvas.width, label: "--width"),
                height: try positiveSize(height, fallback: page.canvas.height, label: "--height")
            )
            resolvedPageID = page.id
            previewContext = page.canvas.previewContext
        } else {
            pageURL = targetURL
            accessURL = readAccessURL
            viewport = CGSize(
                width: try positiveSize(width, fallback: Self.defaultViewportWidth, label: "--width"),
                height: try positiveSize(height, fallback: Self.defaultViewportHeight, label: "--height")
            )
            resolvedPageID = nil
            previewContext = .empty
        }

        let image = try await capturePageImage(
            htmlURL: pageURL,
            readAccessURL: accessURL,
            viewport: viewport,
            fullPage: fullPage,
            previewContext: previewContext
        )
        let pngSize = try writePNG(image, to: outputURL)
        return OpenGraphiteScreenshotResult(
            schemaVersion: OpenGraphiteAgentCore.schemaVersion,
            kind: .page,
            outputPath: outputURL.path,
            width: pngSize.width,
            height: pngSize.height,
            pageID: resolvedPageID,
            pageURL: pageURL.path,
            nodeID: nil,
            pages: nil,
            diagnostics: []
        )
    }

    @MainActor
    private func captureNodeOnMain(
        htmlURL: URL,
        nodeID: String,
        outputURL: URL,
        readAccessURL: URL,
        width: Double?,
        height: Double?,
        padding: Double?,
        previewContext: OpenGraphitePreviewContext
    ) async throws -> OpenGraphiteScreenshotResult {
        let viewport = CGSize(
            width: try positiveSize(width, fallback: Self.defaultViewportWidth, label: "--width"),
            height: try positiveSize(height, fallback: Self.defaultViewportHeight, label: "--height")
        )
        let snapshotter = OpenGraphitePageSnapshotter(viewport: viewport, previewContext: previewContext)
        try await snapshotter.load(htmlURL: htmlURL, readAccessURL: readAccessURL)
        try await snapshotter.renderLocalComponentReferences()
        try await snapshotter.renderComponentPlacementReferences()
        try await snapshotter.applyImplementationI18nRuntimeIfAvailable()
        let documentSize = try await snapshotter.documentSize()
        snapshotter.resize(to: documentSize)
        try await snapshotter.waitForLayout()
        let nodeRect = try await snapshotter.nodeRect(id: nodeID)
        let paddedRect = padded(nodeRect, by: CGFloat(padding ?? 0), within: CGRect(origin: .zero, size: documentSize))
        guard paddedRect.width > 0, paddedRect.height > 0 else {
            throw OpenGraphiteScreenshotError(message: "node \"\(nodeID)\" の表示範囲が空です。")
        }

        let image = try await snapshotter.snapshot(rect: paddedRect)
        let pngSize = try writePNG(image, to: outputURL)
        return OpenGraphiteScreenshotResult(
            schemaVersion: OpenGraphiteAgentCore.schemaVersion,
            kind: .node,
            outputPath: outputURL.path,
            width: pngSize.width,
            height: pngSize.height,
            pageID: nil,
            pageURL: htmlURL.path,
            nodeID: nodeID,
            pages: nil,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: スクリーンショット対象ページ解決関数
    /// 処理概要: 内部 ID または複合参照 ID で `.ogp` 内 page entry を解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` project。
    ///   - reference: `--page-id` / `--component-id` で指定された値。
    /// - Returns: 一致した page entry。見つからない場合は `nil`。
    private func page(in project: OpenGraphiteProject, matching reference: String) -> OpenGraphitePage? {
        let normalizedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let page = typedPage(in: project, matching: normalizedReference) {
            return page
        }
        if let page = compoundPage(in: project, matching: normalizedReference) {
            return page
        }

        return project.allPages.first { $0.internalID == normalizedReference }
    }

    /// 論理名（日本語）: typedスクリーンショットページ解決関数
    /// 処理概要: `ogref` 参照 ID を `.ogp` 内 page entry へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` project。
    ///   - reference: typed agent 参照 ID。
    /// - Returns: 一致した page entry。見つからない場合は `nil`。
    private func typedPage(in project: OpenGraphiteProject, matching reference: String) -> OpenGraphitePage? {
        guard let referenceID = OpenGraphiteReferenceID(parsing: reference) else {
            return nil
        }

        switch referenceID.type {
        case .page, .node:
            let chapterID = referenceID.parts[0]
            let pageID = referenceID.parts[1]
            return project.chapters
                .first { $0.internalID == chapterID }?
                .pages
                .first { $0.internalID == pageID }
        case .component, .componentNode:
            let collectionID = referenceID.parts[0]
            let componentID = referenceID.parts[1]
            return project.collections
                .first { $0.internalID == collectionID }?
                .components
                .first { $0.internalID == componentID }
        case .chapter, .collection:
            return nil
        }
    }

    /// 論理名（日本語）: 複合スクリーンショットページ解決関数
    /// 処理概要: raw `<chapterInternalID>:<pageInternalID>` または `<collectionInternalID>:<componentInternalID>` を page entry へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` project。
    ///   - reference: agent 向け page または node 参照 ID。
    /// - Returns: 一致した page entry。見つからない場合は `nil`。
    private func compoundPage(in project: OpenGraphiteProject, matching reference: String) -> OpenGraphitePage? {
        let parts = reference.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        if parts.count >= 2,
           let chapter = project.chapters.first(where: { $0.internalID == parts[0] }),
           let page = chapter.pages.first(where: { $0.internalID == parts[1] }) {
            return page
        }

        if parts.count >= 2,
           let collection = project.collections.first(where: { $0.internalID == parts[0] }),
           let page = collection.components.first(where: { $0.internalID == parts[1] }) {
            return page
        }

        return nil
    }

    @MainActor
    private func capturePageImage(
        htmlURL: URL,
        readAccessURL: URL,
        viewport: CGSize,
        fullPage: Bool,
        previewContext: OpenGraphitePreviewContext = .empty
    ) async throws -> NSImage {
        let snapshotter = OpenGraphitePageSnapshotter(viewport: viewport, previewContext: previewContext)
        try await snapshotter.load(htmlURL: htmlURL, readAccessURL: readAccessURL)
        try await snapshotter.renderLocalComponentReferences()
        try await snapshotter.renderComponentPlacementReferences()
        try await snapshotter.applyImplementationI18nRuntimeIfAvailable()
        if fullPage {
            let documentSize = try await snapshotter.documentSize()
            snapshotter.resize(to: documentSize)
        }
        try await snapshotter.waitForLayout()
        return try await snapshotter.snapshot()
    }

    private func compositeCanvas(
        snapshots: [(page: OpenGraphitePage, image: NSImage)],
        minX: Double,
        minY: Double,
        width: CGFloat,
        height: CGFloat
    ) throws -> NSImage {
        let pixelWidth = Int(ceil(width))
        let pixelHeight = Int(ceil(height))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw OpenGraphiteScreenshotError(message: "canvas bitmap を作成できません。")
        }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw OpenGraphiteScreenshotError(message: "canvas drawing context を作成できません。")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        Self.defaultCanvasBackground.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        for item in snapshots {
            let targetRect = NSRect(
                x: item.page.canvas.x - minX,
                y: Double(height) - (item.page.canvas.y - minY) - item.page.canvas.height,
                width: item.page.canvas.width,
                height: item.page.canvas.height
            )
            item.image.draw(in: targetRect)
        }

        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmap)
        return image
    }

    private func writePNG(_ image: NSImage, to outputURL: URL) throws -> OpenGraphitePNGSize {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw OpenGraphiteScreenshotError(message: "PNG データを作成できません。")
        }
        try pngData.write(to: outputURL, options: .atomic)
        return OpenGraphitePNGSize(width: Double(bitmap.pixelsWide), height: Double(bitmap.pixelsHigh))
    }

    private func positiveSize(_ value: Double?, fallback: CGFloat, label: String) throws -> CGFloat {
        let size = CGFloat(value ?? Double(fallback))
        guard size > 0 else {
            throw OpenGraphiteScreenshotError(message: "\(label) は正の数値で指定してください。")
        }
        return size
    }

    private func padded(_ rect: CGRect, by padding: CGFloat, within bounds: CGRect) -> CGRect {
        rect
            .insetBy(dx: -max(padding, 0), dy: -max(padding, 0))
            .intersection(bounds)
            .integral
    }

    private func runWebKitSynchronously<T>(
        _ operation: @escaping @MainActor () async throws -> T
    ) throws -> T {
        let box = OpenGraphiteSynchronousResultBox<T>()
        Task { @MainActor in
            do {
                box.result = .success(try await operation())
            } catch {
                box.result = .failure(error)
            }
        }

        if Thread.isMainThread {
            while box.result == nil {
                RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            }
        } else {
            while box.result == nil {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        return try box.result!.get()
    }
}

/// 論理名（日本語）: ページスナップショット補助
/// 概要: 単一 `WKWebView` の読み込み、JavaScript 評価、画像化を扱います。
@MainActor
private final class OpenGraphitePageSnapshotter: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<Void, Error>?

    /// 論理名（日本語）: ページスナップショット補助初期化関数
    /// 処理概要: 指定 viewport の offscreen WKWebView を作成します。
    ///
    /// - Parameters:
    ///   - viewport: 初期 viewport サイズ。
    ///   - previewContext: ページ読み込み前に注入する runtime Mock State。
    init(viewport: CGSize, previewContext: OpenGraphitePreviewContext = .empty) {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.previewContextScript(for: previewContext),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        webView = WKWebView(frame: CGRect(origin: .zero, size: viewport), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    /// 論理名（日本語）: HTML読み込み関数
    /// 処理概要: ローカル HTML を指定 read access root で読み込み、navigation 完了まで待機します。
    ///
    /// - Parameters:
    ///   - htmlURL: 読み込む HTML URL。
    ///   - readAccessURL: 関連アセット読み取り許可ルート。
    func load(htmlURL: URL, readAccessURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadFileURL(htmlURL, allowingReadAccessTo: readAccessURL)
        }
    }

    /// 論理名（日本語）: ローカルcomponent参照レンダリング関数
    /// 処理概要: `file://` component master を Swift 側で読み込み、runtime に渡して screenshot の表示を Pages と揃えます。
    func renderLocalComponentReferences() async throws {
        let discoveryValue = try await evaluateJavaScript(
            """
            (function() {
              return {
                componentHrefs: Array.from(document.querySelectorAll('link[rel="opengraphite-components"][href]')).map((link) => link.href),
                runtimeLoaded: !!(window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function'),
                runtimeHrefs: Array.from(document.querySelectorAll('script[src*="OpenGraphite.runtime.js"]')).map((script) => script.src)
              };
            })()
            """
        )
        let payload = try dictionaryValue(discoveryValue, description: "component reference discovery")
        let componentHTMLs = localTextDocuments(from: payload["componentHrefs"] as? [String] ?? [])
        guard !componentHTMLs.isEmpty else { return }

        let runtimeLoaded = payload["runtimeLoaded"] as? Bool ?? false
        let runtimeSource = runtimeLoaded ? nil : localTextDocuments(from: payload["runtimeHrefs"] as? [String] ?? []).first
        guard runtimeLoaded || runtimeSource != nil else { return }

        let renderScript = """
        (function() {
          \(runtimeSource ?? "")
          if (window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function') {
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments(\(try javaScriptArrayLiteral(componentHTMLs)));
            return true;
          }
          return false;
        })()
        """
        _ = try await evaluateJavaScript(renderScript)
    }

    /// 論理名（日本語）: Component Placement参照レンダリング関数
    /// 処理概要: screenshot 用 WebView で component placement host へ参照元 node の clone を展開します。
    func renderComponentPlacementReferences() async throws {
        _ = try await evaluateJavaScript(Self.componentPlacementReferencesScript)
    }

    /// 論理名（日本語）: 実装i18n runtime適用関数
    /// 処理概要: ページ側 runtime が `window.OpenGraphiteI18n.apply` を公開している場合だけ、その runtime に locale 適用を再実行させます。
    func applyImplementationI18nRuntimeIfAvailable() async throws {
        _ = try await evaluateJavaScript(
            """
            (function() {
              const runtime = window.OpenGraphiteI18n;
              if (!runtime || typeof runtime.apply !== 'function') {
                return false;
              }
              Promise.resolve(runtime.apply())
                .catch(() => {});
              return true;
            })()
            """
        )
        try await Task.sleep(nanoseconds: 220_000_000)
    }

    /// 論理名（日本語）: ローカルtext文書読み込み関数
    /// 処理概要: JavaScript から得た href のうち `file://` URL だけを UTF-8 text として読み込みます。
    ///
    /// - Parameter hrefs: component link や runtime script の href 一覧。
    /// - Returns: 読み込みに成功した text document 一覧。
    private func localTextDocuments(from hrefs: [String]) -> [String] {
        hrefs.compactMap { href -> String? in
            guard let url = URL(string: href), url.isFileURL else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }
    }

    /// 論理名（日本語）: プレビューContext注入スクリプト生成関数
    /// 処理概要: screenshot 用 WebView に HTML document metadata と mock state を注入する JavaScript を生成します。
    ///
    /// - Parameter previewContext: 注入する runtime Mock State。
    /// - Returns: document start で実行する JavaScript。
    private static func previewContextScript(for previewContext: OpenGraphitePreviewContext) -> String {
        let payload: [String: Any] = [
            "fields": previewContext.fieldMocks,
            "placementMocks": previewContext.placementMocks
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data("{}".utf8)
        let literal = String(data: data, encoding: .utf8) ?? "{}"
        return """
        (function() {
          const payload = \(literal);
          const rawFields = payload && typeof payload.fields === 'object' && payload.fields ? payload.fields : {};
          const rawPlacementMocks = payload && typeof payload.placementMocks === 'object' && payload.placementMocks ? payload.placementMocks : {};
          const fields = {};
          Object.keys(rawFields).forEach((key) => {
            fields[key] = rawFields[key];
          });
          Object.freeze(fields);
          const placementMocks = {};
          Object.keys(rawPlacementMocks).forEach((placementID) => {
            const rawPlacementFields = rawPlacementMocks[placementID];
            if (!rawPlacementFields || typeof rawPlacementFields !== 'object') { return; }
            const placementFields = {};
            Object.keys(rawPlacementFields).forEach((key) => {
              placementFields[key] = rawPlacementFields[key];
            });
            placementMocks[placementID] = Object.freeze(placementFields);
          });
          Object.freeze(placementMocks);
          const root = document.documentElement;
          function fieldOverride(name) {
            if (!name || !Object.prototype.hasOwnProperty.call(fields, name)) {
              return { found: false, value: '' };
            }
            return { found: true, value: String(fields[name]) };
          }
          function primaryLanguageSubtag(lang) {
            return String(lang || '').trim().split(/[-_]/)[0].toLowerCase();
          }
          function directionForLanguage(lang) {
            const rtlLanguages = new Set(['ar', 'arc', 'dv', 'fa', 'ha', 'he', 'khw', 'ks', 'ku', 'ps', 'ur', 'yi']);
            return rtlLanguages.has(primaryLanguageSubtag(lang)) ? 'rtl' : 'ltr';
          }
          const fallbackLang = root.getAttribute('lang') || '';
          const langSource = root.getAttribute('data-og-lang-source') || 'literal';
          const langField = root.getAttribute('data-og-lang-field') || '';
          let resolvedLang = fallbackLang;
          if (langSource === 'binding') {
            const binding = fieldOverride(langField);
            if (binding.found) {
              resolvedLang = binding.value;
            }
          }
          const fallbackDir = root.getAttribute('dir') || '';
          const dirSource = root.getAttribute('data-og-dir-source') || 'literal';
          const dirField = root.getAttribute('data-og-dir-field') || '';
          let resolvedDir = fallbackDir;
          if (dirSource === 'binding') {
            const binding = fieldOverride(dirField);
            if (binding.found) {
              resolvedDir = binding.value;
            }
          } else if (dirSource === 'auto') {
            resolvedDir = resolvedLang ? directionForLanguage(resolvedLang) : fallbackDir;
          }
          const documentContext = Object.freeze({
            lang: resolvedLang,
            locale: resolvedLang,
            langSource: langSource,
            langField: langField,
            langFallback: fallbackLang,
            dir: resolvedDir,
            dirSource: dirSource,
            dirField: dirField,
            dirFallback: fallbackDir
          });
          const context = {
            document: documentContext,
            fields: fields,
            placementMocks: placementMocks
          };
          const blockedKeys = new Set(['__proto__', 'constructor', 'prototype']);
          Object.keys(fields).forEach((key) => {
            if (/^[A-Za-z_$][0-9A-Za-z_$]*$/.test(key) && !blockedKeys.has(key) && !(key in context)) {
              context[key] = fields[key];
            }
          });
          if (documentContext.lang) {
            document.documentElement.lang = documentContext.lang;
            document.documentElement.dataset.ogPreviewLocale = documentContext.lang;
          } else {
            document.documentElement.removeAttribute('lang');
            delete document.documentElement.dataset.ogPreviewLocale;
          }
          if (documentContext.dir) {
            document.documentElement.dir = documentContext.dir;
            document.documentElement.dataset.ogPreviewDir = documentContext.dir;
          } else {
            document.documentElement.removeAttribute('dir');
            delete document.documentElement.dataset.ogPreviewDir;
          }
          window.__OPENGRAPHITE_PREVIEW_CONTEXT__ = Object.freeze(context);
        })();
        """
    }

    /// 論理名（日本語）: Component Placement参照レンダリングスクリプト
    /// 処理概要: HTML 内の placement host へ参照元 component node の clone を展開します。
    private static let componentPlacementReferencesScript = """
        (function() {
          function placementHosts() {
            return Array.from(document.querySelectorAll('[data-og-role="component-placement"][data-og-source-node-internal-id]'));
          }

          function sourceNodeFor(host) {
            const nodeInternalID = String(host.getAttribute('data-og-source-node-internal-id') || '').trim();
            if (!nodeInternalID) { return null; }
            return Array.from(document.querySelectorAll('[data-og-internal-id]')).find((element) => {
              if (element === host) { return false; }
              if (element.getAttribute('data-og-generated') === 'true') { return false; }
              if (element.closest('[data-og-placement-generated="true"]')) { return false; }
              return element.getAttribute('data-og-internal-id') === nodeInternalID;
            }) || null;
          }

          function clearGeneratedPlacementContent(host) {
            Array.from(host.children).forEach((child) => {
              if (child.getAttribute('data-og-generated') === 'true' ||
                  child.getAttribute('data-og-placement-generated') === 'true') {
                child.remove();
              }
            });
          }

          function mockFieldsFor(host) {
            const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {};
            const fields = Object.assign({}, context.fields || {});
            const placementMocks = context.placementMocks || {};
            [
              host.getAttribute('data-og-internal-id'),
              host.getAttribute('data-og-id')
            ].forEach((placementID) => {
              const key = String(placementID || '').trim();
              if (!key || !placementMocks[key]) { return; }
              Object.assign(fields, placementMocks[key]);
            });
            return fields;
          }

          function applyCodeViewerMode(root, fields) {
            const mode = String((fields && fields.codeViewerMode) || '').trim();
            if (!mode) { return; }
            root.querySelectorAll('[data-code-viewer-panel]').forEach((panel) => {
              panel.setAttribute('data-og-hidden', panel.getAttribute('data-code-viewer-panel') === mode ? 'false' : 'true');
            });
            root.querySelectorAll('[data-code-viewer-tab]').forEach((button) => {
              const active = button.getAttribute('data-code-viewer-tab') === mode;
              button.setAttribute('aria-pressed', active ? 'true' : 'false');
              button.style.setProperty('--og-background', active ? '#858892' : '#343438');
              button.style.setProperty('--og-border', active ? '1px solid #858892' : '1px solid transparent');
            });
          }

          function markGenerated(root, host) {
            const placementID = host.getAttribute('data-og-id') || '';
            root.setAttribute('data-og-generated', 'true');
            root.setAttribute('data-og-placement-generated', 'true');
            root.setAttribute('data-og-source-placement', placementID);
            root.setAttribute('data-og-preview-clone', 'true');
            root.querySelectorAll('[data-og-id]').forEach((element) => {
              element.setAttribute('data-og-generated', 'true');
              element.setAttribute('data-og-placement-generated', 'true');
              element.setAttribute('data-og-source-placement', placementID);
              element.setAttribute('data-og-preview-clone', 'true');
            });
          }

          function inlinePlacementVariable(host, name) {
            return String((host && host.style && host.style.getPropertyValue(name)) || '').trim();
          }

          function applyPlacementFrameSizing(clone, host) {
            clone.style.setProperty('--og-margin', '0');
            if (inlinePlacementVariable(host, '--og-width')) {
              clone.style.setProperty('--og-width', '100%');
              clone.style.setProperty('--og-max-width', 'none');
            }
            if (inlinePlacementVariable(host, '--og-height')) {
              clone.style.setProperty('--og-height', '100%');
            }
          }

          const hosts = placementHosts();
          hosts.forEach(clearGeneratedPlacementContent);
          hosts.forEach((host) => {
            const source = sourceNodeFor(host);
            if (!source) { return; }
            const clone = source.cloneNode(true);
            applyPlacementFrameSizing(clone, host);
            clone.style.pointerEvents = 'none';
            applyCodeViewerMode(clone, mockFieldsFor(host));
            markGenerated(clone, host);
            host.appendChild(clone);
          });
        })();
        """

    /// 論理名（日本語）: WebViewリサイズ関数
    /// 処理概要: document 全体や canvas サイズに合わせて offscreen WKWebView をリサイズします。
    ///
    /// - Parameter size: 新しい viewport サイズ。
    func resize(to size: CGSize) {
        webView.frame = CGRect(origin: .zero, size: size)
        webView.layoutSubtreeIfNeeded()
    }

    /// 論理名（日本語）: レイアウト待機関数
    /// 処理概要: WebKit の非同期レイアウトが落ち着くまで短時間待機します。
    func waitForLayout() async throws {
        try await Task.sleep(nanoseconds: 120_000_000)
    }

    /// 論理名（日本語）: ドキュメントサイズ取得関数
    /// 処理概要: JavaScript で document の scroll / offset サイズを取得します。
    ///
    /// - Returns: document 全体を含むサイズ。
    func documentSize() async throws -> CGSize {
        let value = try await evaluateJavaScript(
            """
            (() => {
              const body = document.body;
              const element = document.documentElement;
              return {
                width: Math.ceil(Math.max(
                  element ? element.scrollWidth : 0,
                  element ? element.offsetWidth : 0,
                  body ? body.scrollWidth : 0,
                  body ? body.offsetWidth : 0,
                  window.innerWidth
                )),
                height: Math.ceil(Math.max(
                  element ? element.scrollHeight : 0,
                  element ? element.offsetHeight : 0,
                  body ? body.scrollHeight : 0,
                  body ? body.offsetHeight : 0,
                  window.innerHeight
                ))
              };
            })()
            """
        )
        let dictionary = try dictionaryValue(value, description: "document size")
        return CGSize(
            width: try cgFloatValue(dictionary["width"], description: "document width"),
            height: try cgFloatValue(dictionary["height"], description: "document height")
        )
    }

    /// 論理名（日本語）: ノード矩形取得関数
    /// 処理概要: `data-og-internal-id` に一致する要素の bounding rect を JavaScript で取得します。
    ///
    /// - Parameter id: 対象 node ID。
    /// - Returns: 対象 node の矩形。
    func nodeRect(id: String) async throws -> CGRect {
        let idLiteral = try javaScriptStringLiteral(id)
        let value = try await evaluateJavaScript(
            """
            (() => {
              const id = \(idLiteral);
              const node = document.querySelector(`[data-og-internal-id="${CSS.escape(id)}"]`);
              if (!node) { return null; }
              const rect = node.getBoundingClientRect();
              return {
                x: rect.left + window.scrollX,
                y: rect.top + window.scrollY,
                width: rect.width,
                height: rect.height
              };
            })()
            """
        )
        guard let value else {
            throw OpenGraphiteScreenshotError(message: "node id \"\(id)\" が見つかりません。")
        }
        let dictionary = try dictionaryValue(value, description: "node rect")
        return CGRect(
            x: try cgFloatValue(dictionary["x"], description: "node x"),
            y: try cgFloatValue(dictionary["y"], description: "node y"),
            width: try cgFloatValue(dictionary["width"], description: "node width"),
            height: try cgFloatValue(dictionary["height"], description: "node height")
        )
    }

    /// 論理名（日本語）: スナップショット取得関数
    /// 処理概要: 現在の WebView 全体または指定矩形を NSImage として取得します。
    ///
    /// - Parameter rect: 切り抜く矩形。未指定時は WebView 全体。
    /// - Returns: レンダリング済み画像。
    func snapshot(rect: CGRect? = nil) async throws -> NSImage {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = rect ?? CGRect(origin: .zero, size: webView.frame.size)
        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: OpenGraphiteScreenshotError(message: "WebKit snapshot を取得できません。"))
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func evaluateJavaScript(_ javaScript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: value)
            }
        }
    }

    private func javaScriptStringLiteral(_ value: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [value])
        let json = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(json.dropFirst().dropLast())
    }

    private func javaScriptArrayLiteral(_ values: [String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: values)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func dictionaryValue(_ value: Any?, description: String) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw OpenGraphiteScreenshotError(message: "\(description) を取得できません。")
        }
        return dictionary
    }

    private func cgFloatValue(_ value: Any?, description: String) throws -> CGFloat {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        throw OpenGraphiteScreenshotError(message: "\(description) を数値として取得できません。")
    }
}

/// 論理名（日本語）: スクリーンショットエラー
/// 概要: screenshot command の入力やレンダリング失敗を表します。
///
/// プロパティ:
/// - `message`: 表示するエラーメッセージ。
struct OpenGraphiteScreenshotError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}

/// 論理名（日本語）: 同期結果ボックス
/// 概要: async WebKit 処理を CLI の同期実行へ橋渡しするための結果置き場です。
private final class OpenGraphiteSynchronousResultBox<T> {
    var result: Result<T, Error>?
}

/// 論理名（日本語）: PNGサイズ
/// 概要: 書き出した PNG の実ピクセル寸法を保持します。
private struct OpenGraphitePNGSize {
    var width: Double
    var height: Double
}

private extension Array {
    /// 論理名（日本語）: 非同期map関数
    /// 処理概要: 要素順を維持して async transform を適用します。
    ///
    /// - Parameter transform: 各要素へ適用する非同期変換。
    /// - Returns: 変換結果配列。
    func mapAsync<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for item in self {
            let value = try await transform(item)
            values.append(value)
        }
        return values
    }
}
