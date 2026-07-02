import AppKit
import Foundation

/// 論理名（日本語）: ノードドラッグプレビュー
/// 概要: WebView 内でドラッグ中の選択ノード矩形を、Canvas 側の選択枠へ一時反映するための状態です。
///
/// プロパティ:
/// - `pageInternalID`: preview を送信した page card の内部 ID。
/// - `nodeID`: ドラッグ中の node ID。
/// - `rect`: page content 座標上のドラッグ中矩形。
struct OpenGraphiteNodeDragPreview: Equatable {
    var pageInternalID: String?
    var nodeID: String
    var rect: CGRect
}

/// 論理名（日本語）: 選択オーバーレイ矩形
/// 概要: WebView の `getBoundingClientRect()` 由来の実測矩形を、Canvas 側の選択枠へ渡すための状態です。
///
/// プロパティ:
/// - `pageInternalID`: rect を送信した page card の内部 ID。
/// - `primaryNodeID`: Inspector が扱う主選択 node ID。
/// - `nodeIDs`: 実測 rect を持つ選択 node ID 一覧。
/// - `nodeRectsByID`: node ID ごとの WebView viewport 座標上の実測矩形。
/// - `rect`: 選択 node 群全体を覆う union 矩形。
struct OpenGraphiteSelectionOverlayFrame: Equatable {
    var pageInternalID: String?
    var primaryNodeID: String
    var nodeIDs: [String]
    var nodeRectsByID: [String: CGRect]
    var rect: CGRect
}

/// 論理名（日本語）: エディター状態ストア
/// 概要: 読み込み済みプロジェクト、Pages/Components 選択、DOM ノード一覧、Inspector 変更要求を保持するメイン状態管理クラスです。
///
/// プロパティ:
/// - `loadedProject`: 現在開いている `.ogp`。
/// - `selectedCanvasSegment`: 中央キャンバスに表示する Pages / Components セグメント。
/// - `selectedChapterID`: 選択中 Chapter の ID。
/// - `selectedChapterInternalID`: 選択中 Chapter の内部 ID。
/// - `selectedPageID`: 選択中ページの ID。
/// - `selectedPageInternalID`: 選択中ページカードの内部 ID。
/// - `selectedCollectionID`: 選択中 Component Collection の ID。
/// - `selectedCollectionInternalID`: 選択中 Component Collection の内部 ID。
/// - `selectedComponentPageID`: 選択中 component canvas の ID。
/// - `selectedComponentPageInternalID`: 選択中 component canvas カードの内部 ID。
/// - `nodes`: WebView から抽出された編集ノード一覧。
/// - `selectedNodeID`: 選択中ノード ID。通常は `data-og-id`、placement clone 内では表示専用の合成 ID。
/// - `selectedNodeIDs`: Sidebar Layers 上で同時選択されている node ID 一覧。
/// - `zoom`: キャンバス表示倍率。
/// - `activeTool`: キャンバス上の選択ツール。
/// - `previewDisplayMode`: 中央プレビューの通常/フロー表示モード。
/// - `selectionOverlayFrame`: WebView 実測値から作る選択ノード表示枠。
/// - `nodeDragPreview`: ドラッグ中だけ使う選択ノード矩形 preview。
/// - `hoveredStaticFlowSource`: HTML プレビュー内でホバー中の静的フロー遷移元リンク。
/// - `staticFlowLinksByPageInternalID`: page card 内部 ID ごとに収集した静的フローリンク。
/// - `cssMutation`: WebView へ反映待ちの CSS declaration 変更。
/// - `cssVariablesMutation`: WebView へ反映待ちの複数 CSS declaration 変更。
/// - `attributeMutation`: WebView へ反映待ちの属性変更。
/// - `textMutation`: WebView へ反映待ちの text content 変更。
/// - `documentReplacementRequest`: undo/redo で WebView へ適用する HTML 置換要求。
/// - `inspectorSectionOpenRequest`: Preview 側編集に応じて Inspector カードを開く one-shot 要求。
@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var loadedProject: LoadedOpenGraphiteProject?
    @Published var selectedCanvasSegment: OpenGraphiteCanvasSegment = .pages
    @Published var selectedChapterID: String?
    @Published var selectedChapterInternalID: String?
    @Published var selectedPageID: String?
    @Published var selectedPageInternalID: String?
    @Published var selectedCollectionID: String?
    @Published var selectedCollectionInternalID: String?
    @Published var selectedComponentPageID: String?
    @Published var selectedComponentPageInternalID: String?
    @Published var selectedProjectResource: OpenGraphiteProjectResourceSelection? {
        didSet {
            guard oldValue != selectedProjectResource else { return }
            inspectorSectionOpenRequest = nil
        }
    }
    @Published private(set) var nodes: [OpenGraphiteNode] = [] {
        didSet {
            if nodes.isEmpty {
                cssVariableBaselinesByInternalID = [:]
                selectionOverlayFrame = nil
            }
        }
    }
    @Published var selectedNodeID: String? {
        didSet {
            guard oldValue != selectedNodeID else { return }
            synchronizeLayerNodeSelectionForPrimarySelection()
            inspectorSectionOpenRequest = nil
            selectionOverlayFrame = nil
            nodeDragPreview = nil
        }
    }
    @Published private(set) var selectedNodeIDs: Set<String> = []
    @Published var zoom: Double = 0.72
    @Published var statusMessage = "HTMLを正本として開きます。"
    @Published var lastError: String?
    @Published var activeTool: CanvasTool = .select
    @Published var previewDisplayMode: OpenGraphitePreviewDisplayMode = .normal
    @Published private(set) var selectionOverlayFrame: OpenGraphiteSelectionOverlayFrame?
    @Published private(set) var nodeDragPreview: OpenGraphiteNodeDragPreview?
    @Published private(set) var hoveredStaticFlowSource: OpenGraphiteStaticFlowSourceHover?
    @Published private(set) var cssMutation: CSSVariableMutation?
    @Published private(set) var cssVariablesMutation: CSSVariablesMutation?
    @Published private(set) var cssVariablesBatchMutation: CSSVariablesBatchMutation?
    @Published private(set) var attributeMutation: NodeAttributeMutation?
    @Published private(set) var textMutation: NodeTextContentMutation?
    @Published private(set) var documentReplacementRequest: DocumentReplacementRequest?
    @Published private(set) var inspectorSectionOpenRequest: InspectorSectionOpenRequest?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var pageReloadTokensByURL: [URL: Int] = [:]
    @Published private(set) var staticFlowLinksByPageInternalID: [String: [OpenGraphiteStaticFlowLink]] = [:]
    @Published private(set) var staticFlowLinksByPageURL: [URL: [OpenGraphiteStaticFlowLink]] = [:]

    private let loader: ProjectLoader
    private let projectCreator: ProjectCreator
    private let sampleProjectLocator: SampleProjectLocator
    private let currentProjectStore: OpenGraphiteCurrentProjectStore?
    private var mutationSequence = 0
    private var attributeMutationSequence = 0
    private var textMutationSequence = 0
    private var documentReplacementSequence = 0
    private var inspectorSectionOpenRequestSequence = 0
    private var syncHistories: [URL: DocumentSyncHistory] = [:]
    private var lastKnownPageHTMLByURL: [URL: String] = [:]
    private var cssVariableBaselinesByInternalID: [String: [String: String]] = [:]
    private var selectedNodeSelectionAnchorID: String?
    private var isApplyingNodeRangeSelection = false
    private var pageChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private var dependencyChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private let projectChangeMonitor = OpenGraphiteFileChangeMonitor()
    private var monitoredProjectURL: URL?
    private static let absoluteLayoutChildPositionCSSKeys = ["position", "left", "top", "right", "bottom"]
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 論理名（日本語）: エディターストア初期化関数
    /// 処理概要: project loader と sample project locator を保持し、通常利用時は既定実装を使います。
    ///
    /// - Parameters:
    ///   - loader: `.ogp` 読み込みに使う loader。
    ///   - projectCreator: 新規 `.ogp` 作成に使う creator。
    ///   - sampleProjectLocator: Open Sample Project の解決に使う locator。
    ///   - currentProjectStore: 現在開いている `.ogp` の共有状態保存先。
    init(
        loader: ProjectLoader = ProjectLoader(),
        projectCreator: ProjectCreator = ProjectCreator(),
        sampleProjectLocator: SampleProjectLocator = SampleProjectLocator(),
        currentProjectStore: OpenGraphiteCurrentProjectStore? = nil
    ) {
        self.loader = loader
        self.projectCreator = projectCreator
        self.sampleProjectLocator = sampleProjectLocator
        self.currentProjectStore = currentProjectStore ?? (Self.isRunningTests ? nil : OpenGraphiteCurrentProjectStore())
    }

    deinit {
        for monitor in pageChangeMonitorsByURL.values {
            monitor.cancel()
        }
        for monitor in dependencyChangeMonitorsByURL.values {
            monitor.cancel()
        }
        projectChangeMonitor.cancel()
    }

    var selectedChapter: OpenGraphiteChapter? {
        guard let loadedProject else { return nil }
        return loadedProject.project.chapters.first { $0.internalID == selectedChapterInternalID }
            ?? loadedProject.project.chapters.first
    }

    var selectedChapterPages: [OpenGraphitePage] {
        selectedChapter?.pages ?? []
    }

    var selectedComponentCollection: OpenGraphiteComponentCollection? {
        guard let loadedProject else { return nil }
        return loadedProject.project.collections.first { $0.internalID == selectedCollectionInternalID }
            ?? loadedProject.project.collections.first
    }

    var componentPages: [OpenGraphitePage] {
        selectedComponentCollection?.components ?? []
    }

    var selectedCanvasPages: [OpenGraphitePage] {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapterPages
        case .components:
            return componentPages
        }
    }

    var selectedCanvasTitle: String {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapter?.displayName ?? "Pages"
        case .components:
            return selectedComponentCollection?.displayName ?? "Components"
        }
    }

    var inspectorExpansionScopeIdentifier: String {
        if let selectedProjectResource {
            return "project-resource:\(selectedProjectResource)"
        }
        if let selectedNodeID {
            return [
                "node",
                selectedCanvasSegment.rawValue,
                selectedPage?.internalID ?? "",
                selectedNodeID
            ].joined(separator: ":")
        }
        if let selectedPage {
            return [
                "page",
                selectedCanvasSegment.rawValue,
                selectedPage.internalID
            ].joined(separator: ":")
        }
        switch selectedCanvasSegment {
        case .pages:
            return "chapter:\(selectedChapter?.internalID ?? "")"
        case .components:
            return "collection:\(selectedComponentCollection?.internalID ?? "")"
        }
    }

    var selectedPage: OpenGraphitePage? {
        switch selectedCanvasSegment {
        case .pages:
            guard selectedPageInternalID != nil else { return nil }
            return selectedChapterPages.first { $0.internalID == selectedPageInternalID }
        case .components:
            guard selectedComponentPageInternalID != nil else { return nil }
            return componentPages.first { $0.internalID == selectedComponentPageInternalID }
        }
    }

    var selectedPageURL: URL? {
        guard let loadedProject, let selectedPage else { return nil }
        return loadedProject.htmlURL(for: selectedPage)
    }

    var selectedHTMLDocumentContext: OpenGraphiteHTMLDocumentContext {
        guard let selectedPageURL,
              let html = readHTMLFromDisk(at: selectedPageURL)
        else {
            return .empty
        }
        return OpenGraphiteHTMLDocument(html: html).htmlDocumentContext()
    }

    var selectedI18nRuntimeInspection: OpenGraphiteI18nRuntimeInspection? {
        guard let loadedProject,
              let pageID = selectedPageReferenceID()
        else {
            return nil
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return try? core.inspectI18n(projectURL: loadedProject.fileURL, pageID: pageID)
    }

    var selectedPageRootCSSVariables: [String: String] {
        guard let target = currentHTMLSyncTarget(),
              let html = readHTMLFromDisk(at: target.htmlURL)
        else {
            return [:]
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        guard let rootNode = Self.pageRootNode(
            in: html,
            companionCSS: try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: target.htmlURL),
            contract: contract
        ) else {
            return [:]
        }
        return rootNode.cssVariables
    }

    var projectI18nRuntimeInspection: OpenGraphiteI18nRuntimeInspection? {
        guard let loadedProject,
              let pageID = projectI18nReferencePageID()
        else {
            return nil
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return try? core.inspectI18n(projectURL: loadedProject.fileURL, pageID: pageID)
    }

    var projectDesignTokens: [OpenGraphiteDesignToken] {
        guard let loadedProject else { return [] }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return (try? core.designTokens(at: loadedProject.cssURL).tokens) ?? []
    }

    /// 論理名（日本語）: HTML同期対象生成関数
    /// 処理概要: 指定 HTML カードの object identity と現在解決済み URL を保存対象としてまとめます。
    ///
    /// - Parameters:
    ///   - page: 対象 HTML カード。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: 保存先固定 URL を含む同期対象。project 内で解決できない場合は `nil`。
    func htmlSyncTarget(for page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> HTMLSyncTarget? {
        guard let loadedProject else { return nil }

        switch segment {
        case .pages:
            guard let chapter = loadedProject.project.chapters.first(where: { chapter in
                chapter.pages.contains { $0.internalID == page.internalID }
            }) else {
                return nil
            }
            return HTMLSyncTarget(
                identity: HTMLDocumentIdentity(
                    projectURL: loadedProject.fileURL,
                    segment: .pages,
                    containerInternalID: chapter.internalID,
                    pageInternalID: page.internalID
                ),
                path: page.path,
                htmlURL: loadedProject.htmlURL(for: page)
            )
        case .components:
            guard let collection = loadedProject.project.collections.first(where: { collection in
                collection.components.contains { $0.internalID == page.internalID }
            }) else {
                return nil
            }
            return HTMLSyncTarget(
                identity: HTMLDocumentIdentity(
                    projectURL: loadedProject.fileURL,
                    segment: .components,
                    containerInternalID: collection.internalID,
                    pageInternalID: page.internalID
                ),
                path: page.path,
                htmlURL: loadedProject.htmlURL(for: page)
            )
        }
    }

    var projectRootURL: URL? {
        loadedProject?.rootURL
    }

    var selectedNode: OpenGraphiteNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    var selectedLayerNodes: [OpenGraphiteNode] {
        guard !selectedNodeIDs.isEmpty else {
            return selectedNode.map { [$0] } ?? []
        }

        return nodes.filter { selectedNodeIDs.contains($0.id) }
    }

    var selectedLayerNodeIDsInNodeOrder: [String] {
        selectedLayerNodes.map(\.id)
    }

    var selectedComponentSource: OpenGraphiteComponentSource? {
        guard let selectedNode else { return nil }
        return componentSource(for: selectedNode)
    }

    var selectedAppliedParentAnimationContext: OpenGraphiteAppliedAnimationContext? {
        guard let selectedNode else { return nil }
        return appliedParentAnimationContext(for: selectedNode)
    }

    /// 論理名（日本語）: Chapter参照ID生成関数
    /// 処理概要: `.ogp` 内で Chapter を一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameter chapter: 参照する Chapter。
    /// - Returns: `ogref:chapter:<chapterInternalID>`。現在の project に含まれない場合は `nil`。
    func chapterReferenceID(for chapter: OpenGraphiteChapter) -> String? {
        guard loadedProject?.project.chapters.contains(where: { $0.internalID == chapter.internalID }) == true,
              !chapter.internalID.isEmpty
        else {
            return nil
        }
        return OpenGraphiteReferenceID.chapter(chapter.internalID).stringValue
    }

    /// 論理名（日本語）: Component Collection参照ID生成関数
    /// 処理概要: `.ogp` 内で Component Collection を一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameter collection: 参照する Component Collection。
    /// - Returns: `ogref:collection:<collectionInternalID>`。現在の project に含まれない場合は `nil`。
    func collectionReferenceID(for collection: OpenGraphiteComponentCollection) -> String? {
        guard loadedProject?.project.collections.contains(where: { $0.internalID == collection.internalID }) == true,
              !collection.internalID.isEmpty
        else {
            return nil
        }
        return OpenGraphiteReferenceID.collection(collection.internalID).stringValue
    }

    /// 論理名（日本語）: ページ参照ID生成関数
    /// 処理概要: Pages / Components の HTML カードを `.ogp` 内で一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameters:
    ///   - page: 参照する page entry。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: Pages は `ogref:page:<chapterInternalID>:<pageInternalID>`、Components は `ogref:component:<collectionInternalID>:<componentInternalID>`。
    func pageReferenceID(for page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> String? {
        let pageInternalID = page.internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pageInternalID.isEmpty, let loadedProject else { return nil }

        switch segment {
        case .pages:
            guard let chapter = loadedProject.project.chapters.first(where: { chapter in
                chapter.pages.contains { $0.internalID == pageInternalID }
            }), !chapter.internalID.isEmpty else {
                return nil
            }
            return OpenGraphiteReferenceID
                .page(chapterID: chapter.internalID, pageID: pageInternalID)
                .stringValue
        case .components:
            guard let collection = loadedProject.project.collections.first(where: { collection in
                collection.components.contains { $0.internalID == pageInternalID }
            }), !collection.internalID.isEmpty else {
                return nil
            }
            return OpenGraphiteReferenceID
                .component(collectionID: collection.internalID, componentID: pageInternalID)
                .stringValue
        }
    }

    /// 論理名（日本語）: 選択ページ参照ID生成関数
    /// 処理概要: 現在選択中の HTML カードを `.ogp` 内で一意に指す agent 向け参照 ID を返します。
    ///
    /// - Returns: 選択ページの参照 ID。未選択の場合は `nil`。
    func selectedPageReferenceID() -> String? {
        guard let selectedPage else { return nil }
        return pageReferenceID(for: selectedPage, segment: selectedCanvasSegment)
    }

    /// 論理名（日本語）: Project i18n代表ページ参照ID生成関数
    /// 処理概要: Project 依存性として共有 i18n runtime を検出・編集する入口になる代表 page 参照 ID を返します。
    ///
    /// - Returns: 先頭 Pages HTML の参照 ID。Pages がない場合は先頭 Component HTML を返します。
    func projectI18nReferencePageID() -> String? {
        guard let loadedProject else { return nil }
        if let page = loadedProject.project.chapters.flatMap(\.pages).first,
           let referenceID = pageReferenceID(for: page, segment: .pages) {
            return referenceID
        }
        if let component = loadedProject.project.components.first {
            return pageReferenceID(for: component, segment: .components)
        }
        return nil
    }

    /// 論理名（日本語）: 参照ID pasteboardコピー関数
    /// 処理概要: agent 向け参照 ID をテキストとして pasteboard に保存し、ステータスを更新します。
    ///
    /// - Parameters:
    ///   - referenceID: コピーする参照 ID。
    ///   - label: ステータスメッセージに使う対象名。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyReferenceIDToPasteboard(_ referenceID: String?, label: String) -> Bool {
        guard let referenceID = referenceID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !referenceID.isEmpty else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(referenceID, forType: .string)
        statusMessage = "\(label)の参照IDをコピーしました。"
        return true
    }

    /// 論理名（日本語）: Chapter参照IDコピー関数
    /// 処理概要: 指定 Chapter の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter chapter: コピー対象 Chapter。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyChapterReferenceIDToPasteboard(_ chapter: OpenGraphiteChapter) -> Bool {
        copyReferenceIDToPasteboard(chapterReferenceID(for: chapter), label: "Chapter \(chapter.displayName)")
    }

    /// 論理名（日本語）: ページ参照IDコピー関数
    /// 処理概要: 指定 HTML カードの agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameters:
    ///   - page: コピー対象 page entry。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyPageReferenceIDToPasteboard(_ page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> Bool {
        copyReferenceIDToPasteboard(pageReferenceID(for: page, segment: segment), label: "Page \(page.displayName)")
    }

    /// 論理名（日本語）: ノード参照IDコピー関数
    /// 処理概要: 指定 DOM node の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter node: コピー対象 DOM node。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyNodeReferenceIDToPasteboard(_ node: OpenGraphiteNode) -> Bool {
        copyReferenceIDToPasteboard(
            nodeReferenceID(forNodeID: node.editTargetNodeID, nodeInternalID: node.internalID),
            label: "Node \(node.displayID)"
        )
    }

    /// 論理名（日本語）: 選択階層参照IDコピー関数
    /// 処理概要: 選択 node、選択 HTML カード、選択 Chapter の順に agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copySelectedReferenceIDToPasteboard() -> Bool {
        if let selectedNode, copyNodeReferenceIDToPasteboard(selectedNode) {
            return true
        }
        if let selectedPage, copyPageReferenceIDToPasteboard(selectedPage, segment: selectedCanvasSegment) {
            return true
        }
        if selectedCanvasSegment == .components,
           let selectedComponentCollection,
           copyReferenceIDToPasteboard(collectionReferenceID(for: selectedComponentCollection), label: "Collection \(selectedComponentCollection.displayName)") {
            return true
        }
        if selectedCanvasSegment == .pages,
           let selectedChapter,
           copyChapterReferenceIDToPasteboard(selectedChapter) {
            return true
        }
        return false
    }

    /// 論理名（日本語）: Project資源選択関数
    /// 処理概要: Pages / Components の HTML 選択を維持したまま、Inspector 表示対象を Project 依存性へ切り替えます。
    ///
    /// - Parameter resource: 選択する Project 資源。`nil` の場合は Project 資源選択を解除します。
    func selectProjectResource(_ resource: OpenGraphiteProjectResourceSelection?) {
        selectedProjectResource = resource
        selectedNodeID = nil
        if let resource {
            statusMessage = "\(resource.title) を表示しています。"
        } else {
            statusMessage = "Project 資源選択を解除しました。"
        }
    }

    /// 論理名（日本語）: Chapter追加関数
    /// 処理概要: 現在の `.ogp` に空の Chapter を追加保存し、追加した Chapter を Pages セグメントで選択します。
    func addChapter() {
        guard var loadedProject else { return }

        let chapterNumber = loadedProject.project.chapters.count + 1
        let chapter = OpenGraphiteChapter(
            id: nextChapterID(in: loadedProject.project),
            internalID: nextChapterInternalID(in: loadedProject.project),
            title: "Chapter \(chapterNumber)",
            pages: []
        )
        loadedProject.project.chapters.append(chapter)

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            let addedChapter = reloadedProject.project.chapters.first { $0.id == chapter.id }
                ?? reloadedProject.project.chapters.last
            self.loadedProject = reloadedProject
            selectedProjectResource = nil
            selectChapter(addedChapter)
            lastError = nil
            statusMessage = "\(addedChapter?.displayName ?? chapter.displayName) を追加しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Page追加関数
    /// 処理概要: 現在選択中の Chapter に新しい HTML page file を作成し、`.ogp` へ page entry を追加保存します。
    func addPage() {
        guard var loadedProject else { return }

        let targetChapterIndex = writableChapterIndex(in: &loadedProject.project)
        let previousProject = loadedProject.project
        let pageID = nextPageID(in: loadedProject.project)
        let pagePath = nextPagePath(in: loadedProject, idPrefix: "page")
        let pageFileName = URL(fileURLWithPath: pagePath).lastPathComponent
        let pageCanvas = nextPageCanvas(
            in: loadedProject.project.chapters[targetChapterIndex],
            fallbackProject: loadedProject.project
        )
        let page = OpenGraphitePage(
            id: pageID,
            path: pagePath,
            canvas: pageCanvas
        )
        let htmlURL = loadedProject
            .rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(pagePath)
            .standardizedFileURL
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
        let stylesheetPath = Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let bodyHTML = """
            <OpenGraphitePage data-og-id="\(pageID)-root" data-og-type="page" data-og-layout="vertical"></OpenGraphitePage>
        """
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)

        do {
            let writeResult = try core.createPage(
                at: htmlURL,
                title: pageFileName,
                lang: "ja",
                stylesheetPath: stylesheetPath,
                bodyHTML: bodyHTML,
                overwrite: false
            )
            guard writeResult.created else {
                lastError = writeResult.diagnostics.first(where: { $0.severity == .error })?.message
                    ?? "ページHTMLの作成に失敗しました。"
                return
            }

            loadedProject.project.chapters[targetChapterIndex].pages.append(page)
            do {
                try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
                let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
                self.loadedProject = reloadedProject
                let addedPage = reloadedProject.project.chapters
                    .flatMap(\.pages)
                    .first { $0.id == pageID }
                if let addedPage {
                    selectPage(internalID: addedPage.internalID)
                }
                lastError = nil
                statusMessage = "\(addedPage?.displayName ?? page.displayName) を追加しました。"
                restartExternalProjectMonitoring(force: true)
                restartExternalPageMonitoring(force: true)
            } catch {
                try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
                try? FileManager.default.removeItem(at: htmlURL)
                try? FileManager.default.removeItem(at: companionCSSURL)
                lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            }
        } catch {
            lastError = "ページHTMLの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: 既存Page追加関数
    /// 処理概要: `htmlRoot` 配下に存在する HTML file を、現在選択中の Chapter の page entry として `.ogp` へ追加保存します。
    ///
    /// - Parameter htmlURL: 追加する既存 HTML file の URL。
    func addExistingPage(at htmlURL: URL) {
        guard var loadedProject else { return }

        let pathResult = Self.existingHTMLPath(for: htmlURL, in: loadedProject)
        guard let pagePath = pathResult.path else {
            lastError = pathResult.error ?? "追加する HTML file を確認できませんでした。"
            return
        }
        guard !loadedProject.project.allPages.contains(where: { $0.path == pagePath }) else {
            lastError = "同じ HTML path が既に登録されています: \(pagePath)"
            return
        }

        let targetChapterIndex = writableChapterIndex(in: &loadedProject.project)
        let previousProject = loadedProject.project
        let pageID = Self.existingPageID(forHTMLPath: pagePath, in: loadedProject.project)
        let pageCanvas = nextPageCanvas(
            in: loadedProject.project.chapters[targetChapterIndex],
            fallbackProject: loadedProject.project
        )
        let page = OpenGraphitePage(
            id: pageID,
            path: pagePath,
            canvas: pageCanvas
        )
        loadedProject.project.chapters[targetChapterIndex].pages.append(page)
        let targetChapter = loadedProject.project.chapters[targetChapterIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            let addedChapter = Self.reloadedChapter(
                in: reloadedProject.project,
                matching: targetChapter,
                fallbackIndex: targetChapterIndex
            )
            let addedPage = addedChapter?.pages.first { candidate in
                candidate.id == pageID && candidate.path == pagePath
            }
            guard let addedChapter, let addedPage else {
                throw NSError(
                    domain: "OpenGraphite.EditorStore",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "追加した page を再読み込みできませんでした。"]
                )
            }

            self.loadedProject = reloadedProject
            selectedProjectResource = nil
            selectedCanvasSegment = .pages
            selectedChapterID = addedChapter.id
            selectedChapterInternalID = addedChapter.internalID
            selectPage(internalID: addedPage.internalID)
            lastError = nil
            statusMessage = "\(addedPage.displayName) を追加しました。"
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
        } catch {
            try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Chapter表示名更新関数
    /// 処理概要: 指定 Chapter の UI 表示タイトルを `.ogp` に保存し、選択状態を維持したまま反映します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 Chapter の内部 ID。
    ///   - value: Sidebar で入力された表示名。空の場合は title を解除して ID 表示へ戻します。
    func updateChapterTitle(internalID: String, value: String) {
        guard var loadedProject,
              let chapterIndex = loadedProject.project.chapters.firstIndex(where: { $0.internalID == internalID })
        else {
            return
        }

        let normalizedTitle = Self.normalizedManifestTitle(value)
        guard loadedProject.project.chapters[chapterIndex].title != normalizedTitle else { return }
        loadedProject.project.chapters[chapterIndex].title = normalizedTitle
        let updatedChapter = loadedProject.project.chapters[chapterIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = "\(updatedChapter.displayName) に変更しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Collection表示名更新関数
    /// 処理概要: 指定 Component Collection の UI 表示タイトルを `.ogp` に保存し、選択状態を維持したまま反映します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 Collection の内部 ID。
    ///   - value: Sidebar で入力された表示名。空の場合は title を解除して ID 表示へ戻します。
    func updateCollectionTitle(internalID: String, value: String) {
        guard var loadedProject,
              let collectionIndex = loadedProject.project.collections.firstIndex(where: { $0.internalID == internalID })
        else {
            return
        }

        let normalizedTitle = Self.normalizedManifestTitle(value)
        guard loadedProject.project.collections[collectionIndex].title != normalizedTitle else { return }
        loadedProject.project.collections[collectionIndex].title = normalizedTitle
        let updatedCollection = loadedProject.project.collections[collectionIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = "\(updatedCollection.displayName) に変更しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: HTMLカードファイル名更新関数
    /// 処理概要: 指定 Page または Component canvas の HTML ファイル名を変更し、`.ogp` の path と同名 companion CSS を同期します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 HTML カードの内部 ID。
    ///   - segment: Pages / Components のどちらを更新するか。
    ///   - value: Sidebar で入力された新しい HTML ファイル名。拡張子省略時は `.html` を補います。
    func updatePageFilename(internalID: String, segment: OpenGraphiteCanvasSegment, value: String) {
        guard var loadedProject else { return }

        guard cssMutation == nil,
              cssVariablesMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            lastError = "未適用の編集があるため、ファイル名変更を保留しました。"
            return
        }

        let originalPage: OpenGraphitePage
        let updatePagePath: (String) -> Void
        switch segment {
        case .pages:
            guard let chapterIndex = loadedProject.project.chapters.firstIndex(where: { chapter in
                chapter.pages.contains { $0.internalID == internalID }
            }),
                  let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == internalID })
            else {
                return
            }
            originalPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
            updatePagePath = { nextPath in
                loadedProject.project.chapters[chapterIndex].pages[pageIndex].path = nextPath
                loadedProject.project.chapters[chapterIndex].pages[pageIndex].title = nil
            }
        case .components:
            guard let collectionIndex = loadedProject.project.collections.firstIndex(where: { collection in
                collection.components.contains { $0.internalID == internalID }
            }),
                  let pageIndex = loadedProject.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == internalID })
            else {
                return
            }
            originalPage = loadedProject.project.collections[collectionIndex].components[pageIndex]
            updatePagePath = { nextPath in
                loadedProject.project.collections[collectionIndex].components[pageIndex].path = nextPath
                loadedProject.project.collections[collectionIndex].components[pageIndex].title = nil
            }
        }

        let renamePath = Self.renamedHTMLPath(currentPath: originalPage.path, value: value)
        guard let nextPath = renamePath.path else {
            lastError = renamePath.error ?? "ファイル名が正しくありません。"
            return
        }
        guard nextPath != originalPage.path else { return }
        guard !loadedProject.project.allPages.contains(where: { page in
            page.internalID != originalPage.internalID && page.path == nextPath
        }) else {
            lastError = "同じ HTML path が既に登録されています: \(nextPath)"
            return
        }

        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .standardizedFileURL
        let currentHTMLURL = htmlRootURL
            .appendingPathComponent(originalPage.path)
            .standardizedFileURL
        let nextHTMLURL = htmlRootURL
            .appendingPathComponent(nextPath)
            .standardizedFileURL
        let currentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: currentHTMLURL).standardizedFileURL
        let nextCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: nextHTMLURL).standardizedFileURL
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: currentHTMLURL.path) else {
            lastError = "変更元の HTML が見つかりません: \(currentHTMLURL.path)"
            return
        }
        guard !fileManager.fileExists(atPath: nextHTMLURL.path) else {
            lastError = "変更先の HTML が既に存在します: \(nextHTMLURL.path)"
            return
        }
        if currentCSSURL != nextCSSURL,
           fileManager.fileExists(atPath: nextCSSURL.path) {
            lastError = "変更先の companion CSS が既に存在します: \(nextCSSURL.path)"
            return
        }

        let previousProject = loadedProject.project
        let movedCSS = currentCSSURL != nextCSSURL && fileManager.fileExists(atPath: currentCSSURL.path)
        var dependencyBackups: [HTMLDependencyRewriteBackup] = []
        var didMoveHTML = false
        var didMoveCSS = false

        do {
            if segment == .components {
                dependencyBackups = try rewriteComponentDependencyReferences(
                    in: loadedProject,
                    from: currentHTMLURL,
                    to: nextHTMLURL,
                    excludingPageInternalID: originalPage.internalID
                )
            }
            try fileManager.createDirectory(at: nextHTMLURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: currentHTMLURL, to: nextHTMLURL)
            didMoveHTML = true
            if movedCSS {
                try fileManager.moveItem(at: currentCSSURL, to: nextCSSURL)
                didMoveCSS = true
            }

            updatePagePath(nextPath)
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            self.loadedProject = reloadedProject
            migratePageRuntimeState(from: currentHTMLURL, to: nextHTMLURL)
            seedKnownHTMLForProject(reloadedProject)
            if selectedCanvasSegment == segment {
                switch segment {
                case .pages:
                    selectedPageInternalID = originalPage.internalID
                    selectedPageID = originalPage.id
                case .components:
                    selectedComponentPageInternalID = originalPage.internalID
                    selectedComponentPageID = originalPage.id
                }
                selectedNodeID = nil
                nodes = []
                prepareHistoryForSelectedPage()
            }
            lastError = nil
            statusMessage = "\(URL(fileURLWithPath: nextPath).lastPathComponent) に変更しました。"
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
        } catch {
            if didMoveCSS {
                try? fileManager.moveItem(at: nextCSSURL, to: currentCSSURL)
            }
            if didMoveHTML {
                try? fileManager.moveItem(at: nextHTMLURL, to: currentHTMLURL)
            }
            for backup in dependencyBackups {
                try? backup.data.write(to: backup.url, options: .atomic)
            }
            try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
            lastError = "ファイル名の変更に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: ノード複合参照ID生成関数
    /// 処理概要: 選択中 HTML 文脈と node 内部 ID から `.ogp` 内で一意な agent 向け参照 ID を作ります。
    ///
    /// - Parameter nodeID: 参照する DOM node の `data-og-id`。
    /// - Parameter nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    /// - Returns: `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` 形式の参照 ID。
    func nodeReferenceID(forNodeID nodeID: String) -> String? {
        nodeReferenceID(forNodeID: nodeID, nodeInternalID: nil)
    }

    /// 論理名（日本語）: ノード複合参照ID生成関数
    /// 処理概要: 選択中 HTML 文脈と明示された node 内部 ID から `.ogp` 内で一意な agent 向け参照 ID を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照する DOM node の `data-og-id`。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    /// - Returns: Pages は `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>`、Components は `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>`。
    func nodeReferenceID(forNodeID nodeID: String, nodeInternalID: String?) -> String? {
        guard !nodeID.isEmpty, let page = selectedPage else { return nil }
        let pageInternalID = page.internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNodeInternalID = nodeInternalID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? nodes.first { $0.id == nodeID }?.internalID
            ?? ""
        guard !pageInternalID.isEmpty, !resolvedNodeInternalID.isEmpty else { return nil }

        switch selectedCanvasSegment {
        case .pages:
            guard let chapter = selectedChapter, !chapter.internalID.isEmpty else { return nil }
            return OpenGraphiteReferenceID
                .node(chapterID: chapter.internalID, pageID: pageInternalID, nodeID: resolvedNodeInternalID)
                .stringValue
        case .components:
            guard let collection = selectedComponentCollection, !collection.internalID.isEmpty else { return nil }
            return OpenGraphiteReferenceID
                .componentNode(collectionID: collection.internalID, componentID: pageInternalID, nodeID: resolvedNodeInternalID)
                .stringValue
        }
    }

    /// 論理名（日本語）: ノード参照pasteboard payload生成関数
    /// 処理概要: OpenGraphite 内貼り付けとテキスト欄 ID 貼り付けの両方で使う node 参照情報を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照する DOM node の `data-og-id`。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    ///   - html: OpenGraphite 内貼り付け用の HTML subtree。
    /// - Returns: pasteboard 専用 JSON に変換できる辞書。
    func nodeReferencePasteboardPayload(forNodeID nodeID: String, html: String) -> [String: Any]? {
        nodeReferencePasteboardPayload(forNodeID: nodeID, nodeInternalID: nil, html: html)
    }

    /// 論理名（日本語）: ノード参照pasteboard payload生成関数
    /// 処理概要: 明示された node 内部 ID を含む pasteboard 専用 JSON payload を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照する DOM node の `data-og-id`。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    ///   - html: OpenGraphite 内貼り付け用の HTML subtree。
    /// - Returns: pasteboard 専用 JSON に変換できる辞書。
    func nodeReferencePasteboardPayload(
        forNodeID nodeID: String,
        nodeInternalID: String?,
        html: String
    ) -> [String: Any]? {
        let resolvedNodeInternalID = nodeInternalID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? nodes.first { $0.id == nodeID }?.internalID
            ?? ""
        guard let referenceID = nodeReferenceID(forNodeID: nodeID, nodeInternalID: resolvedNodeInternalID),
              let page = selectedPage
        else {
            return nil
        }

        var payload: [String: Any] = [
            "schemaVersion": "1",
            "kind": "opengraphite-node",
            "referenceID": referenceID,
            "segment": selectedCanvasSegment.rawValue,
            "pageID": page.id,
            "pageInternalID": page.internalID,
            "path": page.path,
            "nodeID": nodeID,
            "nodeInternalID": resolvedNodeInternalID,
            "html": html
        ]

        if let projectURL = loadedProject?.fileURL.path {
            payload["projectURL"] = projectURL
        }

        switch selectedCanvasSegment {
        case .pages:
            if let chapter = selectedChapter {
                payload["chapterID"] = chapter.id
                payload["chapterInternalID"] = chapter.internalID
                if let chapterIndex = loadedProject?.project.chapters.firstIndex(where: { $0.internalID == chapter.internalID }) {
                    payload["chapterIndex"] = chapterIndex
                    if let pageIndex = loadedProject?.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == page.internalID }) {
                        payload["pageIndex"] = pageIndex
                    }
                }
            }
        case .components:
            if let collection = selectedComponentCollection {
                payload["collectionID"] = collection.id
                payload["collectionInternalID"] = collection.internalID
                if let collectionIndex = loadedProject?.project.collections.firstIndex(where: { $0.internalID == collection.internalID }) {
                    payload["collectionIndex"] = collectionIndex
                    if let componentIndex = loadedProject?.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == page.internalID }) {
                        payload["componentIndex"] = componentIndex
                    }
                }
            }
        }

        return payload
    }

    /// 論理名（日本語）: ページ再読み込みトークン取得関数
    /// 処理概要: 指定 HTML URL の外部変更を WebView へ通知するための単調増加トークンを返します。
    ///
    /// - Parameter pageURL: reload token を取得する HTML URL。
    /// - Returns: WebView が比較する reload token。
    func reloadToken(for pageURL: URL) -> Int {
        pageReloadTokensByURL[pageURL] ?? 0
    }

    /// 論理名（日本語）: パネル経由プロジェクト作成関数
    /// 処理概要: 保存パネルから新規 `.ogp` の作成先を選ばせ、作成後に読み込みます。
    func createProjectWithPanel() {
        guard let url = ProjectDialogs.createProjectURL() else { return }
        createProject(at: url)
    }

    /// 論理名（日本語）: プロジェクト作成関数
    /// 処理概要: 指定された URL に新規 `.ogp` と初期 HTML/CSS を作成し、作成した project を開きます。
    ///
    /// - Parameter url: 新規 `.ogp` の作成先 URL。
    func createProject(at url: URL) {
        do {
            let projectURL = try projectCreator.createProject(at: url)
            openProject(at: projectURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: サンプルプロジェクトオープン関数
    /// 処理概要: Debug 実行時は指定 sample `.ogp`、Release/no-env 時は Application Support の編集用 sample を読み込みます。
    func openSampleProject() {
        do {
            let url = try sampleProjectLocator.sampleProjectURL()
            openProject(at: url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: パネル経由プロジェクトオープン関数
    /// 処理概要: ファイル選択パネルから `.ogp` を選ばせ、選択された URL を読み込みます。
    func openProjectWithPanel() {
        guard let url = ProjectDialogs.openProjectURL() else { return }
        openProject(at: url)
    }

    /// 論理名（日本語）: プロジェクトオープン関数
    /// 処理概要: 指定された `.ogp` を読み込み、Chapter 表示対象とノード状態を初期化します。
    ///
    /// - Parameter url: 読み込む `.ogp` の URL。
    func openProject(at url: URL) {
        do {
            let project = try loader.loadProject(at: url)
            let initialCollection = Self.preferredCollection(in: project.project)
            loadedProject = project
            selectedCanvasSegment = project.project.chapters.flatMap(\.pages).isEmpty && !project.project.components.isEmpty ? .components : .pages
            selectedChapterID = project.project.chapters.first?.id
            selectedChapterInternalID = project.project.chapters.first?.internalID
            selectedPageID = nil
            selectedPageInternalID = nil
            selectedCollectionID = initialCollection?.id
            selectedCollectionInternalID = initialCollection?.internalID
            selectedComponentPageID = initialCollection?.components.first?.id
            selectedComponentPageInternalID = initialCollection?.components.first?.internalID
            selectedProjectResource = nil
            selectedNodeID = nil
            nodes = []
            cssMutation = nil
            cssVariablesMutation = nil
            cssVariablesBatchMutation = nil
            attributeMutation = nil
            textMutation = nil
            documentReplacementRequest = nil
            syncHistories = [:]
            lastKnownPageHTMLByURL = [:]
            pageReloadTokensByURL = [:]
            staticFlowLinksByPageInternalID = [:]
            staticFlowLinksByPageURL = [:]
            hoveredStaticFlowSource = nil
            do {
                try currentProjectStore?.write(projectURL: project.fileURL)
            } catch {
                lastError = error.localizedDescription
            }
            seedKnownHTMLForProject(project)
            prepareHistoryForSelectedPage()
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
            statusMessage = "\(project.project.name) を開きました。"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: ページ選択解除関数
    /// 処理概要: `nil` 指定時に選択ページを解除し、ノード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみページ選択を解除します。
    func selectPage(id: String?) {
        guard id == nil else { return }
        selectPage(internalID: nil)
    }

    /// 論理名（日本語）: 内部IDページ選択関数
    /// 処理概要: HTML カードの内部 ID で選択ページを切り替えます。
    ///
    /// - Parameter internalID: 選択するページカード内部 ID。`nil` の場合はページ選択を解除します。
    func selectPage(internalID: String?) {
        selectPage(matching: { page in page.internalID == internalID })
    }

    /// 論理名（日本語）: ページ選択共通関数
    /// 処理概要: 指定条件でページを解決し、表示対象と履歴状態を更新します。
    ///
    /// - Parameter predicate: 選択対象ページの判定。
    private func selectPage(matching predicate: (OpenGraphitePage) -> Bool) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        switch selectedCanvasSegment {
        case .pages:
            let page = selectedChapterPages.first(where: predicate)
            selectedPageID = page?.id
            selectedPageInternalID = page?.internalID
        case .components:
            let page = componentPages.first(where: predicate)
            selectedComponentPageID = page?.id
            selectedComponentPageInternalID = page?.internalID
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        } else {
            statusMessage = "ページ選択を解除しました。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Chapter選択解除関数
    /// 処理概要: `nil` 指定時に先頭 Chapter を表示し、HTML カード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみ先頭 Chapter が表示対象になります。
    func selectChapter(id: String?) {
        guard id == nil else { return }
        guard let loadedProject else { return }
        selectChapter(loadedProject.project.chapters.first)
    }

    /// 論理名（日本語）: 内部ID Chapter選択関数
    /// 処理概要: Chapter 内部 ID で Pages セグメントの表示対象を切り替え、HTML カード選択を解除します。
    ///
    /// - Parameter internalID: 選択する Chapter 内部 ID。`nil` の場合は先頭 Chapter が表示対象になります。
    func selectChapter(internalID: String?) {
        guard let loadedProject else { return }
        let chapter = loadedProject.project.chapters.first { $0.internalID == internalID }
            ?? loadedProject.project.chapters.first
        selectChapter(chapter)
    }

    /// 論理名（日本語）: Chapter選択共通関数
    /// 処理概要: 指定 Chapter を Pages セグメントへ反映し、HTML カードを未選択にします。
    ///
    /// - Parameter chapter: 選択する Chapter。`nil` の場合は未選択状態にします。
    private func selectChapter(_ chapter: OpenGraphiteChapter?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        selectedCanvasSegment = .pages
        selectedChapterID = chapter?.id
        selectedChapterInternalID = chapter?.internalID
        selectedPageID = nil
        selectedPageInternalID = nil
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }

        if let chapter {
            statusMessage = "\(chapter.displayName) を表示しています。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Collection選択解除関数
    /// 処理概要: `nil` 指定時に先頭 Collection を表示し、component canvas 選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみ先頭 Collection が表示対象になります。
    func selectCollection(id: String?) {
        guard id == nil else { return }
        guard let loadedProject else { return }
        selectCollection(Self.preferredCollection(in: loadedProject.project))
    }

    /// 論理名（日本語）: 内部ID Collection選択関数
    /// 処理概要: Collection 内部 ID で Components セグメントの表示対象を切り替えます。
    ///
    /// - Parameter internalID: 選択する Collection 内部 ID。`nil` の場合は先頭 Collection が表示対象になります。
    func selectCollection(internalID: String?) {
        guard let loadedProject else { return }
        let collection = Self.preferredCollection(in: loadedProject.project, internalID: internalID)
        selectCollection(collection)
    }

    /// 論理名（日本語）: Collection選択共通関数
    /// 処理概要: 指定 Collection を Components セグメントへ反映し、先頭 component canvas を選択します。
    ///
    /// - Parameter collection: 選択する Collection。`nil` の場合は未選択状態にします。
    private func selectCollection(_ collection: OpenGraphiteComponentCollection?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        selectedCanvasSegment = .components
        selectedCollectionID = collection?.id
        selectedCollectionInternalID = collection?.internalID
        selectedComponentPageID = collection?.components.first?.id
        selectedComponentPageInternalID = collection?.components.first?.internalID
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }

        if let collection {
            statusMessage = "\(collection.displayName) を表示しています。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Pagesセグメント選択関数
    /// 処理概要: Pages canvas を表示し、HTML カードが未選択なら Chapter 階層を維持します。
    func selectPagesSegment() {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        selectedCanvasSegment = .pages
        if selectedChapterInternalID == nil
            || loadedProject?.project.chapters.contains(where: { $0.internalID == selectedChapterInternalID }) != true {
            let chapter = loadedProject?.project.chapters.first
            selectedChapterID = chapter?.id
            selectedChapterInternalID = chapter?.internalID
        }
        if let selectedPageInternalID,
           !selectedChapterPages.contains(where: { $0.internalID == selectedPageInternalID }) {
            selectedPageID = nil
            self.selectedPageInternalID = nil
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }
        statusMessage = "Pages を表示しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Componentsセグメント選択関数
    /// 処理概要: Components canvas を表示し、必要に応じて先頭 component page を選択します。
    func selectComponentsSegment() {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        selectedCanvasSegment = .components
        if selectedCollectionInternalID == nil
            || loadedProject?.project.collections.contains(where: { $0.internalID == selectedCollectionInternalID }) != true {
            let collection = loadedProject.flatMap { Self.preferredCollection(in: $0.project) }
            selectedCollectionID = collection?.id
            selectedCollectionInternalID = collection?.internalID
        }
        if selectedComponentPageInternalID == nil || !componentPages.contains(where: { $0.internalID == selectedComponentPageInternalID }) {
            selectedComponentPageID = componentPages.first?.id
            selectedComponentPageInternalID = componentPages.first?.internalID
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        statusMessage = "Components を表示しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Componentページ選択解除関数
    /// 処理概要: `nil` 指定時に Components セグメント内の HTML canvas 選択を解除します。
    ///
    /// - Parameter id: `nil` の場合のみ選択解除します。
    func selectComponentPage(id: String?) {
        guard id == nil else { return }
        selectComponentPage(internalID: nil)
    }

    /// 論理名（日本語）: 内部ID Componentページ選択関数
    /// 処理概要: Component canvas カードの内部 ID で選択対象を切り替えます。
    ///
    /// - Parameter internalID: 選択する component page 内部 ID。`nil` の場合は選択解除します。
    func selectComponentPage(internalID: String?) {
        selectComponentPage(matching: { page in page.internalID == internalID })
    }

    /// 論理名（日本語）: Componentページ選択共通関数
    /// 処理概要: 指定条件で component page を解決し、選択状態を更新します。
    ///
    /// - Parameter predicate: 選択対象 component page の判定。
    private func selectComponentPage(matching predicate: (OpenGraphitePage) -> Bool) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedProjectResource = nil
        var collection = selectedComponentCollection
        var page = collection?.components.first(where: predicate)
        if page == nil, let loadedProject {
            for candidateCollection in loadedProject.project.collections {
                if let candidatePage = candidateCollection.components.first(where: predicate) {
                    collection = candidateCollection
                    page = candidatePage
                    break
                }
            }
        }
        selectedCanvasSegment = .components
        selectedCollectionID = collection?.id
        selectedCollectionInternalID = collection?.internalID
        selectedComponentPageID = page?.id
        selectedComponentPageInternalID = page?.internalID
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        } else {
            statusMessage = "Component ページ選択を解除しました。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: ノード選択関数
    /// 処理概要: Layers、Canvas、Context Menu から渡された `data-og-id` を選択状態として保存します。
    ///
    /// - Parameter id: 選択するノード ID。placement clone 内では表示専用の合成 ID、選択解除時は `nil`。
    func selectNode(id: String?) {
        if id != nil {
            selectedProjectResource = nil
        }
        selectedNodeSelectionAnchorID = id
        selectedNodeIDs = id.map { Set([$0]) } ?? []
        selectedNodeID = id
    }

    /// 論理名（日本語）: ノード範囲選択関数
    /// 処理概要: Sidebar Layers の表示順を基準に、選択アンカーから指定ノードまでを同時選択状態にします。
    ///
    /// - Parameters:
    ///   - id: 範囲選択の終端にするノード ID。
    ///   - visibleNodeIDs: 現在 Sidebar Layers に表示されているノード ID の順序付き一覧。
    func selectNodeRange(to id: String, visibleNodeIDs: [String]) {
        let orderedIDs = visibleNodeIDs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let targetIndex = orderedIDs.firstIndex(of: id) else {
            selectNode(id: id)
            return
        }

        let anchorID = selectedNodeSelectionAnchorID ?? selectedNodeID
        guard let anchorID,
              let anchorIndex = orderedIDs.firstIndex(of: anchorID)
        else {
            selectNode(id: id)
            return
        }

        selectedProjectResource = nil
        let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedNodeIDs = Set(orderedIDs[bounds])
        selectedNodeSelectionAnchorID = anchorID
        isApplyingNodeRangeSelection = true
        selectedNodeID = id
        isApplyingNodeRangeSelection = false
    }

    /// 論理名（日本語）: 同時選択内主ノード選択関数
    /// 処理概要: Sidebar Layers の同時選択セットを維持したまま、Inspector が扱う主選択 node だけを切り替えます。
    ///
    /// - Parameter id: 主選択へ切り替える node ID。
    /// - Returns: 同時選択内の主選択として処理できた場合は `true`。
    @discardableResult
    func selectPrimaryNodeWithinCurrentSelection(id: String) -> Bool {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty,
              selectedNodeIDs.count > 1,
              selectedNodeIDs.contains(normalizedID)
        else {
            return false
        }

        selectedProjectResource = nil
        isApplyingNodeRangeSelection = true
        defer { isApplyingNodeRangeSelection = false }
        selectedNodeID = normalizedID
        return true
    }

    /// 論理名（日本語）: 主ノード選択同期関数
    /// 処理概要: 単一選択系の更新では Sidebar Layers の同時選択を単一行へ戻し、範囲選択中のみ既存セットを維持します。
    private func synchronizeLayerNodeSelectionForPrimarySelection() {
        guard let selectedNodeID else {
            selectedNodeIDs = []
            selectedNodeSelectionAnchorID = nil
            return
        }

        guard isApplyingNodeRangeSelection else {
            selectedNodeIDs = Set([selectedNodeID])
            selectedNodeSelectionAnchorID = selectedNodeID
            return
        }

        if !selectedNodeIDs.contains(selectedNodeID) {
            selectedNodeIDs.insert(selectedNodeID)
        }
        if selectedNodeSelectionAnchorID == nil {
            selectedNodeSelectionAnchorID = selectedNodeID
        }
    }

    /// 論理名（日本語）: ノード一覧同期後選択整理関数
    /// 処理概要: WebView から再取得したノード一覧に存在しない Sidebar Layers の同時選択を破棄します。
    private func synchronizeLayerNodeSelectionWithAvailableNodes() {
        guard let selectedNodeID else {
            selectedNodeIDs = []
            selectedNodeSelectionAnchorID = nil
            return
        }

        let availableNodeIDs = Set(nodes.map(\.id))
        guard availableNodeIDs.contains(selectedNodeID) else {
            self.selectedNodeID = nil
            return
        }

        selectedNodeIDs.formIntersection(availableNodeIDs)
        selectedNodeIDs.insert(selectedNodeID)
        if let selectedNodeSelectionAnchorID,
           !availableNodeIDs.contains(selectedNodeSelectionAnchorID) {
            self.selectedNodeSelectionAnchorID = selectedNodeID
        } else if selectedNodeSelectionAnchorID == nil {
            selectedNodeSelectionAnchorID = selectedNodeID
        }
    }

    /// 論理名（日本語）: 選択オーバーレイpayload取り込み関数
    /// 処理概要: WebView 実測 rect payload を検証し、Canvas 側の選択枠 source of truth として保存します。
    ///
    /// - Parameters:
    ///   - payload: `active`、`id`、`nodes`、`x`、`y`、`width`、`height` を含む JavaScript bridge payload。
    ///   - pageInternalID: payload を送信した page card の内部 ID。
    func ingestSelectionOverlayPayload(_ payload: [String: Any]?, pageInternalID: String?) {
        let normalizedPageInternalID = Self.normalizedOptionalString(pageInternalID)
        guard let payload,
              payload["active"] as? Bool == true
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let selectedNodeIDsInOrder = selectedLayerNodeIDsInNodeOrder
        guard let selectedNodeID,
              !selectedNodeIDsInOrder.isEmpty
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let rawNodePayloads = payload["nodes"] as? [[String: Any]] ?? [payload]
        let selectedNodeIDSet = Set(selectedNodeIDsInOrder)
        var nodeRectsByID: [String: CGRect] = [:]
        for rawNodePayload in rawNodePayloads {
            guard let nodeFrame = Self.selectionOverlayNodeFrame(from: rawNodePayload),
                  selectedNodeIDSet.contains(nodeFrame.id)
            else {
                continue
            }
            nodeRectsByID[nodeFrame.id] = nodeFrame.rect
        }

        let measuredNodeIDs = selectedNodeIDsInOrder.filter { nodeRectsByID[$0] != nil }
        guard !measuredNodeIDs.isEmpty,
              let unionRect = Self.unionRect(measuredNodeIDs.compactMap { nodeRectsByID[$0] })
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let payloadPrimaryID = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryNodeID = selectedNodeIDSet.contains(payloadPrimaryID) ? payloadPrimaryID : selectedNodeID
        selectionOverlayFrame = OpenGraphiteSelectionOverlayFrame(
            pageInternalID: normalizedPageInternalID,
            primaryNodeID: primaryNodeID,
            nodeIDs: measuredNodeIDs,
            nodeRectsByID: nodeRectsByID,
            rect: unionRect
        )
    }

    /// 論理名（日本語）: 選択オーバーレイ解除関数
    /// 処理概要: 選択解除や対象 page 切り替え時に実測選択枠を破棄します。
    ///
    /// - Parameter pageInternalID: 解除対象を page card 内部 ID で限定します。`nil` の場合は無条件で解除します。
    func clearSelectionOverlayFrame(pageInternalID: String? = nil) {
        guard let pageInternalID else {
            selectionOverlayFrame = nil
            return
        }
        if selectionOverlayFrame?.pageInternalID == pageInternalID {
            selectionOverlayFrame = nil
        }
    }

    /// 論理名（日本語）: ノードドラッグpreview payload取り込み関数
    /// 処理概要: WebView でドラッグ中の選択 node 矩形を受け取り、Canvas 側の選択枠を一時的に追従させます。
    ///
    /// - Parameters:
    ///   - payload: `active`、`id`、`x`、`y`、`width`、`height` を含む JavaScript bridge payload。
    ///   - pageInternalID: payload を送信した page card の内部 ID。
    func ingestNodeDragPreviewPayload(_ payload: [String: Any], pageInternalID: String?) {
        guard payload["active"] as? Bool == true else {
            clearNodeDragPreview(pageInternalID: pageInternalID)
            return
        }

        let id = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              id == selectedNodeID,
              let x = Self.cgFloatValue(payload["x"]),
              let y = Self.cgFloatValue(payload["y"]),
              let width = Self.cgFloatValue(payload["width"]),
              let height = Self.cgFloatValue(payload["height"]),
              width > 0,
              height > 0
        else {
            return
        }

        nodeDragPreview = OpenGraphiteNodeDragPreview(
            pageInternalID: pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines),
            nodeID: id,
            rect: CGRect(x: x, y: y, width: width, height: height)
        )
    }

    /// 論理名（日本語）: ノードドラッグpreview解除関数
    /// 処理概要: ドラッグ終了や対象 page 切り替え時に一時 preview を破棄します。
    ///
    /// - Parameter pageInternalID: 解除対象を page card 内部 ID で限定します。`nil` の場合は無条件で解除します。
    func clearNodeDragPreview(pageInternalID: String? = nil) {
        guard let pageInternalID else {
            nodeDragPreview = nil
            return
        }
        if nodeDragPreview?.pageInternalID == pageInternalID {
            nodeDragPreview = nil
        }
    }

    /// 論理名（日本語）: プレビューテキスト編集中payload取り込み関数
    /// 処理概要: WebView の contenteditable 入力中に届く text payload を選択中 node へ反映し、Inspector 表示を即時同期します。
    ///
    /// - Parameter payload: `id` と `text` を含む JavaScript bridge payload。
    func ingestTextEditingPayload(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              !id.isEmpty,
              id == selectedNodeID,
              let index = nodes.firstIndex(where: { $0.id == id }),
              nodes[index].type == "text"
        else {
            return
        }

        let text = payload["text"] as? String ?? ""
        let previousText = nodes[index].textContent ?? ""
        nodes[index].textContent = text
        if !nodes[index].isTextBinding {
            nodes[index].fallbackTextContent = text
        }
        if previousText != text {
            requestInspectorSections([.text])
        }
    }

    /// 論理名（日本語）: コンポーネント継承元解決関数
    /// 処理概要: 選択ノードの `data-og-component` または `data-og-source-component` から project 内の master 配置を解決します。
    ///
    /// - Parameter node: 継承元を調べる OpenGraphite ノード。
    /// - Returns: project 内で見つかった component master の表示情報。未解決の場合は `nil`。
    func componentSource(for node: OpenGraphiteNode) -> OpenGraphiteComponentSource? {
        guard let componentID = node.inheritedComponentID,
              let loadedProject
        else {
            return nil
        }
        return componentSource(componentID: componentID, in: loadedProject)
    }

    /// 論理名（日本語）: 適用親アニメーション文脈解決関数
    /// 処理概要: 選択ノードの祖先を近い順にたどり、Inspector に表示する親側 animation / timeline declaration を取得します。
    ///
    /// - Parameter node: 表示中の選択ノード。
    /// - Returns: 親側の animation / timeline context。該当する祖先がない場合は `nil`。
    private func appliedParentAnimationContext(for node: OpenGraphiteNode) -> OpenGraphiteAppliedAnimationContext? {
        guard let selectedIndex = nodes.firstIndex(where: { $0.id == node.id }) else {
            return nil
        }

        let ancestors = Self.ancestorNodes(in: nodes, selectedIndex: selectedIndex)
        let requestedTimelineNames = Self.dashedIdentifiers(in: node.cssVariables["animation-timeline"] ?? "")
        if !requestedTimelineNames.isEmpty,
           let matchedAncestor = ancestors.first(where: { ancestor in
               !Self.timelineProviderNames(in: ancestor.cssVariables).isDisjoint(with: requestedTimelineNames)
           }) {
            let matchedNames = Self.timelineProviderNames(in: matchedAncestor.cssVariables)
                .intersection(requestedTimelineNames)
                .sorted()
            return Self.animationContext(for: matchedAncestor, matchedTimelineNames: matchedNames)
        }

        return ancestors.lazy.compactMap { ancestor in
            Self.animationContext(for: ancestor)
        }.first
    }

    /// 論理名（日本語）: コンポーネント継承元表示関数
    /// 処理概要: Inspector から指定された component master の canvas へ表示対象を切り替え、master root を再選択します。
    ///
    /// - Parameter source: 移動先 component master の表示情報。
    func revealComponentSource(_ source: OpenGraphiteComponentSource) {
        guard loadedProject?.project.collections.contains(where: { collection in
            collection.internalID == source.collectionInternalID
                && collection.components.contains { $0.internalID == source.componentPageInternalID }
        }) == true else {
            return
        }

        selectComponentPage(internalID: source.componentPageInternalID)
        selectedNodeID = source.masterNodeID
        statusMessage = "\(source.componentID) の component master を表示しています。"
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 既存の配置名を保持したまま、選択中ページのキャンバス座標と解像度を `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    func updateSelectedPageCanvas(x: Double, y: Double, width: Double, height: Double) {
        updateSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: selectedPage?.canvas.name ?? "",
            previewContext: selectedPage?.canvas.previewContext ?? .empty
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス位置更新関数
    /// 処理概要: 選択中ページの既存の配置名、解像度、preview Mock State を維持したまま、canvas 座標だけを `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    func updateSelectedPageCanvasPosition(x: Double, y: Double) {
        guard let canvas = selectedPage?.canvas else { return }
        persistSelectedPageCanvas(
            x: x,
            y: y,
            width: canvas.width,
            height: canvas.height,
            name: canvas.name,
            previewContext: canvas.previewContext,
            statusMessageBuilder: { page in
                "\(page.path) のキャンバス位置を更新しました。"
            }
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 選択中ページのキャンバス配置名、座標、解像度、preview Mock State を `.ogp` へ保存し、表示中 project state へ反映します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    ///   - previewContext: エディター内 preview へ注入する runtime Mock State。
    func updateSelectedPageCanvas(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String,
        previewContext: OpenGraphitePreviewContext
    ) {
        persistSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: name,
            previewContext: previewContext,
            statusMessageBuilder: nil
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス保存関数
    /// 処理概要: 選択中 page / component canvas の配置情報を検証し、`.ogp` と表示中 project state へ反映します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    ///   - previewContext: エディター内 preview へ注入する runtime Mock State。
    ///   - statusMessageBuilder: 保存成功時のステータス文言を作る任意クロージャ。
    private func persistSelectedPageCanvas(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String,
        previewContext: OpenGraphitePreviewContext,
        statusMessageBuilder: ((OpenGraphitePage) -> String)?
    ) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite, width > 0, height > 0 else {
            lastError = "キャンバス配置の入力が不正です。"
            return
        }
        guard var loadedProject else { return }

        let normalizedName = Self.normalizedCanvasName(name)
        let nextCanvas = OpenGraphiteCanvas(
            name: normalizedName,
            x: x,
            y: y,
            width: width,
            height: height,
            previewContext: previewContext
        )
        let updatedPage: OpenGraphitePage
        switch selectedCanvasSegment {
        case .pages:
            guard let selectedPageInternalID else { return }
            var chapterIndex: Array<OpenGraphiteChapter>.Index?
            if let selectedChapterInternalID,
               let selectedChapterIndex = loadedProject.project.chapters.firstIndex(where: { $0.internalID == selectedChapterInternalID }),
               loadedProject.project.chapters[selectedChapterIndex].pages.contains(where: { $0.internalID == selectedPageInternalID }) {
                chapterIndex = selectedChapterIndex
            }
            if chapterIndex == nil {
                chapterIndex = loadedProject.project.chapters.firstIndex { chapter in
                    chapter.pages.contains { $0.internalID == selectedPageInternalID }
                }
            }
            guard let chapterIndex,
                  let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == selectedPageInternalID })
            else {
                return
            }
            guard loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
        case .components:
            guard let selectedComponentPageInternalID else {
                return
            }
            var collectionIndex: Array<OpenGraphiteComponentCollection>.Index?
            if let selectedCollectionInternalID,
               let selectedCollectionIndex = loadedProject.project.collections.firstIndex(where: { $0.internalID == selectedCollectionInternalID }),
               loadedProject.project.collections[selectedCollectionIndex].components.contains(where: { $0.internalID == selectedComponentPageInternalID }) {
                collectionIndex = selectedCollectionIndex
            }
            if collectionIndex == nil {
                collectionIndex = loadedProject.project.collections.firstIndex { collection in
                    collection.components.contains { $0.internalID == selectedComponentPageInternalID }
                }
            }
            guard let collectionIndex,
                  let pageIndex = loadedProject.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == selectedComponentPageInternalID })
            else {
                return
            }
            guard loadedProject.project.collections[collectionIndex].components[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.collections[collectionIndex].components[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.collections[collectionIndex].components[pageIndex]
        }

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = statusMessageBuilder?(updatedPage)
                ?? "\(updatedPage.path) のキャンバス配置を更新しました。Mock State も保存しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 既存 preview Mock State を維持し、キャンバス配置だけを `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    func updateSelectedPageCanvas(x: Double, y: Double, width: Double, height: Double, name: String) {
        updateSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: name,
            previewContext: selectedPage?.canvas.previewContext ?? .empty
        )
    }

    /// 論理名（日本語）: HTML Document Context更新関数
    /// 処理概要: 選択中 HTML の `<html>` document attribute と binding metadata を正本 HTML へ保存します。
    ///
    /// - Parameter context: 保存する HTML document context。
    func updateSelectedHTMLDocumentContext(_ context: OpenGraphiteHTMLDocumentContext) {
        guard let target = currentHTMLSyncTarget() else { return }
        guard let diskHTML = readHTMLFromDisk(at: target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let mutation = OpenGraphiteHTMLDocument(html: diskHTML)
            .settingHTMLDocumentContext(context, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = mutation.diagnostics.first(where: { $0.severity == .error })?.message
                ?? "HTML document attributes の保存に失敗しました。"
            return
        }
        guard mutation.html != diskHTML else { return }
        guard syncHTML(mutation.html, target: target) else { return }
        incrementReloadToken(for: target.htmlURL)
        lastError = nil
        statusMessage = "\(target.htmlURL.lastPathComponent) の HTML document attributes を更新しました。"
    }

    /// 論理名（日本語）: 選択ページi18n推奨設定適用関数
    /// 処理概要: 選択中 HTML の実装資源へ推奨 i18n runtime と locale JSON を作成・更新します。
    func recommendI18nForSelectedPage() {
        guard let loadedProject,
              let pageID = selectedPageReferenceID()
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.recommendI18n(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                locales: ["ja", "eng"]
            )
            if let selectedPageURL {
                incrementReloadToken(for: selectedPageURL)
                refreshPageFromDiskIfChanged(at: selectedPageURL)
            }
            lastError = nil
            statusMessage = result.updated
                ? "i18n runtime と locale JSON を実装資源へ更新しました。"
                : "i18n runtime と locale JSON は既に推奨設定です。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = "i18n 推奨設定の適用に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Project i18n推奨設定適用関数
    /// 処理概要: Project 内の Pages HTML へ推奨 i18n runtime 参照を用意し、共有 locale JSON を実装資源へ作成・更新します。
    func recommendI18nForProject() {
        guard let loadedProject else { return }
        let pages = loadedProject.project.chapters.flatMap(\.pages)
        let targetPages = pages.isEmpty ? loadedProject.project.components : pages
        guard !targetPages.isEmpty else { return }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        var updated = false

        do {
            for page in targetPages {
                let segment: OpenGraphiteCanvasSegment = pages.isEmpty ? .components : .pages
                guard let pageID = pageReferenceID(for: page, segment: segment) else { continue }
                let result = try core.recommendI18n(
                    projectURL: loadedProject.fileURL,
                    pageID: pageID,
                    locales: ["ja", "eng"]
                )
                updated = updated || result.updated
            }
            refreshProjectDependenciesFromDisk()
            for page in targetPages {
                refreshPageFromDiskIfChanged(at: loadedProject.htmlURL(for: page))
            }
            lastError = nil
            statusMessage = updated
                ? "Project の i18n runtime と locale JSON を実装資源へ更新しました。"
                : "Project の i18n runtime と locale JSON は既に推奨設定です。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = "Project i18n 推奨設定の適用に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Project i18n runtime literal更新関数
    /// 処理概要: Project 依存性で選択された共有 i18n 設定ファイルへ literal の loadPath / fallbackLng を保存します。
    ///
    /// - Parameters:
    ///   - loadPath: 更新する `backend.loadPath`。`nil` の場合は更新しません。
    ///   - fallbackLocale: 更新する `fallbackLng`。`nil` の場合は更新しません。
    func updateProjectI18nRuntime(loadPath: String?, fallbackLocale: String?) {
        guard let loadedProject,
              let pageID = projectI18nReferencePageID()
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.updateI18nRuntimeLiterals(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                loadPath: loadPath,
                fallbackLocale: fallbackLocale
            )
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return
            }
            refreshProjectDependenciesFromDisk()
            lastError = nil
            statusMessage = result.updated
                ? "Project の i18n runtime 設定を更新しました。"
                : "Project の i18n runtime 設定は変更されていません。"
        } catch {
            lastError = "Project i18n runtime 設定の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Projectデザイントークン更新関数
    /// 処理概要: CSS library の `:root` に design token を保存し、開いている preview を再読み込みします。
    ///
    /// - Parameters:
    ///   - name: CSS custom property 名。
    ///   - value: CSS 値。
    func updateProjectDesignToken(name: String, value: String) {
        guard let loadedProject else { return }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.setDesignToken(name, value: value, projectURL: loadedProject.fileURL)
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return
            }
            refreshProjectDependenciesFromDisk()
            lastError = nil
            statusMessage = result.updated
                ? "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) を Design Tokens に保存しました。"
                : "Design Tokens は変更されていません。"
        } catch {
            lastError = "Design Tokens の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Projectデザイントークン削除関数
    /// 処理概要: CSS library の `:root` から design token を削除し、開いている preview を再読み込みします。
    ///
    /// - Parameter name: 削除する CSS custom property 名。
    func removeProjectDesignToken(name: String) {
        updateProjectDesignToken(name: name, value: "")
    }

    /// 論理名（日本語）: 静的フローリンクpayload取り込み関数
    /// 処理概要: WebView から届いた静的リンク一覧を page card 内部 ID と page URL ごとに保持し、フロー表示オーバーレイの入力へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から受け取ったリンク辞書配列。
    ///   - pageURL: payload を収集した HTML page URL。
    ///   - pageInternalID: payload を収集した page card の内部 ID。
    func ingestStaticFlowLinkPayload(_ payload: [[String: Any]], pageURL: URL, pageInternalID: String? = nil) {
        let links = payload.compactMap(OpenGraphiteStaticFlowLink.init(payload:))
        staticFlowLinksByPageURL[pageURL.standardizedFileURL] = links
        let normalizedPageInternalID = pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedPageInternalID.isEmpty {
            staticFlowLinksByPageInternalID[normalizedPageInternalID] = links
        }
    }

    /// 論理名（日本語）: 静的フロー元ホバーpayload取り込み関数
    /// 処理概要: WebView から届いたホバー中リンク ID を保持し、フロー線の強調表示入力へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から受け取った hover 対象リンク辞書。
    ///   - pageURL: payload を収集した HTML page URL。
    ///   - pageInternalID: payload を収集した page card の内部 ID。
    func ingestStaticFlowSourceHoverPayload(_ payload: [String: Any], pageURL: URL, pageInternalID: String? = nil) {
        let linkID = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !linkID.isEmpty else {
            clearStaticFlowSourceHover(pageURL: pageURL, pageInternalID: pageInternalID)
            return
        }

        hoveredStaticFlowSource = OpenGraphiteStaticFlowSourceHover(
            pageURL: pageURL.standardizedFileURL,
            pageInternalID: pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines),
            linkID: linkID,
            sourceNodeID: payload["sourceNodeID"] as? String ?? ""
        )
    }

    /// 論理名（日本語）: 静的フロー元ホバー解除関数
    /// 処理概要: 指定 page または現在保持中の静的フロー遷移元 hover 状態を解除します。
    ///
    /// - Parameters:
    ///   - pageURL: 解除対象を限定する HTML page URL。`nil` の場合は無条件で解除します。
    ///   - pageInternalID: 解除対象を限定する page card 内部 ID。
    func clearStaticFlowSourceHover(pageURL: URL? = nil, pageInternalID: String? = nil) {
        guard let pageURL else {
            hoveredStaticFlowSource = nil
            return
        }

        guard hoveredStaticFlowSource?.pageURL == pageURL.standardizedFileURL else {
            return
        }

        let normalizedPageInternalID = pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedPageInternalID.isEmpty,
           hoveredStaticFlowSource?.pageInternalID != normalizedPageInternalID {
            return
        }

        if hoveredStaticFlowSource?.pageURL == pageURL.standardizedFileURL {
            hoveredStaticFlowSource = nil
        }
    }

    /// 論理名（日本語）: ノードpayload取り込み関数
    /// 処理概要: WebView の JavaScript から受け取った辞書配列を `OpenGraphiteNode` 配列へ変換します。
    ///
    /// - Parameter payload: DOM から収集されたノード辞書の配列。
    func ingestNodePayload(_ payload: [[String: Any]]) {
        let sourceNodes = sourceNodesByInternalIDForCurrentTarget()
        var nextCSSVariableBaselines: [String: [String: String]] = [:]
        nodes = payload.compactMap { dictionary in
            let internalID = dictionary["internalID"] as? String ?? ""
            let sourceNode = sourceNodes[internalID]
            if !internalID.isEmpty, let sourceNode {
                nextCSSVariableBaselines[internalID] = sourceNode.cssVariables
            }
            return Self.node(from: dictionary, sourceNode: sourceNode)
        }
        cssVariableBaselinesByInternalID = nextCSSVariableBaselines

        synchronizeLayerNodeSelectionWithAvailableNodes()
    }

    /// 論理名（日本語）: CSS宣言更新関数
    /// 処理概要: 選択中ノードの編集対象 CSS declaration を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - key: 更新する CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: Inspector から入力された値。前後空白は除去します。
    func updateCSSVariable(key: String, value: String) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedLayerNodes.count > 1, !normalizedKey.isEmpty {
            let valuesByNodeID = Dictionary(
                uniqueKeysWithValues: selectedLayerNodes.map { node in
                    (node.id, [normalizedKey: value])
                }
            )
            updateSelectedLayerNodeCSSVariables(valuesByNodeID: valuesByNodeID)
            return
        }

        guard let selectedNodeID,
              let selectedNode,
              let displayTarget = currentHTMLSyncTarget(),
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedOldValue = selectedNode.cssVariables[normalizedKey] ?? ""
        let expectedOldValue = expectedOldCSSVariableValue(
            for: selectedNode,
            key: normalizedKey,
            fallback: selectedOldValue
        )

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let currentValue = nodes[index].cssVariables[normalizedKey] ?? ""
            guard currentValue != normalizedValue else { return }
        }

        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .setCSSVariable(
                nodeInternalID: selectedNode.internalID,
                key: normalizedKey,
                value: normalizedValue,
                expectedOldValue: expectedOldValue
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            if normalizedValue.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: normalizedKey)
            } else {
                nodes[index].cssVariables[normalizedKey] = normalizedValue
            }
        }

        mutationSequence += 1
        cssMutation = CSSVariableMutation(
            sequence: mutationSequence,
            pageURL: displayTarget.htmlURL,
            nodeID: selectedNode.id,
            key: normalizedKey,
            value: normalizedValue
        )
        statusMessage = "\(selectedNode.displayID) の \(normalizedKey) を更新しました。"
    }

    /// 論理名（日本語）: 選択ノード複数CSS宣言更新関数
    /// 処理概要: 選択中ノードの複数 CSS declaration を一括更新し、WebView へまとめて反映する mutation を発行します。
    ///
    /// - Parameter values: 更新する CSS property または OpenGraphite 予約 custom property 名と値の組。
    func updateSelectedNodeCSSVariables(values: [String: String]) {
        if selectedLayerNodes.count > 1 {
            let valuesByNodeID = Dictionary(
                uniqueKeysWithValues: selectedLayerNodes.map { node in
                    (node.id, values)
                }
            )
            updateSelectedLayerNodeCSSVariables(valuesByNodeID: valuesByNodeID)
            return
        }

        guard let selectedNodeID,
              let selectedNode,
              let displayTarget = currentHTMLSyncTarget(),
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let normalizedValues = values.reduce(into: [String: String]()) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            result[key] = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !normalizedValues.isEmpty,
              let index = nodes.firstIndex(where: { $0.id == selectedNodeID })
        else {
            return
        }

        let changedValues = normalizedValues.filter { key, value in
            (nodes[index].cssVariables[key] ?? "") != value
        }
        guard !changedValues.isEmpty else { return }

        let expectedOldValues = changedValues.reduce(into: [String: String]()) { result, entry in
            result[entry.key] = expectedOldCSSVariableValue(
                for: selectedNode,
                key: entry.key,
                fallback: selectedNode.cssVariables[entry.key] ?? ""
            )
        }
        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .setCSSVariables(
                nodeInternalID: selectedNode.internalID,
                values: changedValues,
                expectedOldValues: expectedOldValues
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return }

        for (key, value) in changedValues {
            if value.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: key)
            } else {
                nodes[index].cssVariables[key] = value
            }
        }

        mutationSequence += 1
        cssVariablesMutation = CSSVariablesMutation(
            sequence: mutationSequence,
            pageURL: displayTarget.htmlURL,
            nodeID: selectedNode.id,
            values: changedValues
        )
        statusMessage = "\(selectedNode.displayID) のサイズを更新しました。"
    }

    /// 論理名（日本語）: 選択レイヤー群CSS宣言更新関数
    /// 処理概要: 同時選択中ノードそれぞれの CSS declaration を保存し、WebView へ node ごとの mutation として反映します。
    ///
    /// - Parameter valuesByNodeID: ノード ID ごとの CSS property または OpenGraphite 予約 custom property 名と値の組。
    func updateSelectedLayerNodeCSSVariables(valuesByNodeID: [String: [String: String]]) {
        guard let displayTarget = currentHTMLSyncTarget() else { return }
        var changedValuesByNodeID: [String: [String: String]] = [:]

        for node in selectedLayerNodes {
            guard let requestedValues = valuesByNodeID[node.id],
                  !node.internalID.isEmpty,
                  let editTarget = cssEditTarget(for: node)
            else {
                continue
            }

            let normalizedValues = requestedValues.reduce(into: [String: String]()) { result, entry in
                let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }
                result[key] = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !normalizedValues.isEmpty,
                  let index = nodes.firstIndex(where: { $0.id == node.id })
            else {
                continue
            }

            let changedValues = normalizedValues.filter { key, value in
                (nodes[index].cssVariables[key] ?? "") != value
            }
            guard !changedValues.isEmpty else { continue }

            let expectedOldValues = changedValues.reduce(into: [String: String]()) { result, entry in
                result[entry.key] = expectedOldCSSVariableValue(
                    for: node,
                    key: entry.key,
                    fallback: node.cssVariables[entry.key] ?? ""
                )
            }
            let edit = HTMLObjectEdit(
                target: editTarget,
                operation: .setCSSVariables(
                    nodeInternalID: node.internalID,
                    values: changedValues,
                    expectedOldValues: expectedOldValues
                )
            )
            guard applyHTMLObjectEdit(edit).updated else { continue }

            for (key, value) in changedValues {
                if value.isEmpty {
                    nodes[index].cssVariables.removeValue(forKey: key)
                } else {
                    nodes[index].cssVariables[key] = value
                }
            }
            changedValuesByNodeID[node.id] = changedValues
        }

        guard !changedValuesByNodeID.isEmpty else { return }
        mutationSequence += 1
        cssVariablesBatchMutation = CSSVariablesBatchMutation(
            sequence: mutationSequence,
            pageURL: displayTarget.htmlURL,
            nodeValues: changedValuesByNodeID
        )
        statusMessage = "\(changedValuesByNodeID.count)個のオブジェクトを更新しました。"
    }

    /// 論理名（日本語）: 選択ページルートCSS宣言更新関数
    /// 処理概要: Page Inspector からページ root node の編集対象 CSS declaration を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - key: 更新する CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: Inspector から入力された値。前後空白は除去します。
    func updateSelectedPageRootCSSVariable(key: String, value: String) {
        guard let target = currentHTMLSyncTarget(),
              let diskHTML = readHTMLFromDisk(at: target.htmlURL)
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        guard let rootNode = Self.pageRootNode(
            in: diskHTML,
            companionCSS: try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: target.htmlURL),
            contract: contract
        ) else {
            return
        }
        guard !rootNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedOldValue = rootNode.cssVariables[key] ?? ""
        guard expectedOldValue != normalizedValue else { return }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setCSSVariable(
                nodeInternalID: rootNode.internalID,
                key: key,
                value: normalizedValue,
                expectedOldValue: expectedOldValue
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return }

        if let index = nodes.firstIndex(where: { $0.internalID == rootNode.internalID }) {
            if normalizedValue.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: key)
            } else {
                nodes[index].cssVariables[key] = normalizedValue
            }
        }

        mutationSequence += 1
        cssMutation = CSSVariableMutation(
            sequence: mutationSequence,
            pageURL: target.htmlURL,
            nodeID: rootNode.id,
            key: key,
            value: normalizedValue
        )
        statusMessage = "Page root の \(key) を更新しました。"
    }

    /// 論理名（日本語）: フォント候補適用関数
    /// 処理概要: 選択中ノードへ `font-family` を保存し、必要な stylesheet link を HTML 正本へ追加します。
    ///
    /// - Parameter candidate: フォントブラウザで選択された候補。
    func applyFontCandidate(_ candidate: OpenGraphiteFontCandidate) {
        guard selectedNode?.internalID.isEmpty == false,
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        let normalizedCSSFamily = candidate.cssFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        updateCSSVariable(key: "font-family", value: normalizedCSSFamily)

        ensureFontStylesheet(for: candidate, target: target)
    }

    /// 論理名（日本語）: 選択ページルートフォント候補適用関数
    /// 処理概要: Page Inspector で選んだフォント候補を locale 用 CSS 変数へ保存し、必要な stylesheet link を追加します。
    ///
    /// - Parameters:
    ///   - variableKey: 保存先の locale font-family 変数名。
    ///   - candidate: フォントブラウザで選択された候補。
    func applySelectedPageRootFontCandidate(variableKey: String, candidate: OpenGraphiteFontCandidate) {
        guard let target = currentHTMLSyncTarget() else { return }
        let normalizedCSSFamily = candidate.cssFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSelectedPageRootCSSVariable(key: variableKey, value: normalizedCSSFamily)
        ensureFontStylesheet(for: candidate, target: target)
    }

    /// 論理名（日本語）: フォントstylesheet保証関数
    /// 処理概要: 外部フォント候補が要求する stylesheet link を HTML `<head>` へ重複なく保存します。
    ///
    /// - Parameters:
    ///   - candidate: stylesheet URL を持つ可能性があるフォント候補。
    ///   - target: 保存対象 HTML。
    private func ensureFontStylesheet(for candidate: OpenGraphiteFontCandidate, target: HTMLSyncTarget) {
        guard let stylesheetHref = candidate.stylesheetHref?.trimmingCharacters(in: .whitespacesAndNewlines),
              !stylesheetHref.isEmpty
        else {
            return
        }
        guard let diskHTML = readHTMLFromDisk(at: target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let mutation = OpenGraphiteHTMLDocument(html: diskHTML)
            .ensuringStylesheetLink(href: stylesheetHref, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = mutation.diagnostics.first(where: { $0.severity == .error })?.message
                ?? "font stylesheet の保存に失敗しました。"
            return
        }
        guard mutation.html != diskHTML else { return }
        guard syncHTML(mutation.html, target: target) else { return }
        incrementReloadToken(for: target.htmlURL)
        lastError = nil
        statusMessage = "\(candidate.familyName) の font stylesheet を追加しました。"
    }

    /// 論理名（日本語）: ノード属性更新関数
    /// 処理概要: 選択中ノードの編集対象属性を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: Inspector から入力された値。空の場合は属性削除として扱います。
    func updateNodeAttribute(name: String, value: String) {
        guard let selectedNodeID,
              let selectedNode,
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedOldValue: String

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            switch name {
            case "data-og-layout":
                expectedOldValue = nodes[index].layout ?? ""
            case "data-og-role":
                expectedOldValue = nodes[index].role ?? ""
            case "data-og-icon-library":
                expectedOldValue = nodes[index].iconLibrary ?? ""
            case "data-og-icon-name":
                expectedOldValue = nodes[index].iconName ?? ""
            case "data-og-icon-source":
                expectedOldValue = nodes[index].iconSource ?? ""
            default:
                expectedOldValue = ""
            }
            guard expectedOldValue != normalizedValue else { return }
        } else {
            switch name {
            case "data-og-layout":
                expectedOldValue = selectedNode.layout ?? ""
            case "data-og-role":
                expectedOldValue = selectedNode.role ?? ""
            case "data-og-icon-library":
                expectedOldValue = selectedNode.iconLibrary ?? ""
            case "data-og-icon-name":
                expectedOldValue = selectedNode.iconName ?? ""
            case "data-og-icon-source":
                expectedOldValue = selectedNode.iconSource ?? ""
            default:
                expectedOldValue = ""
            }
        }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setAttribute(
                nodeInternalID: selectedNode.internalID,
                name: name,
                value: normalizedValue,
                expectedOldValue: expectedOldValue
            )
        )
        let editResult = applyHTMLObjectEdit(edit)
        guard editResult.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            switch name {
            case "data-og-layout":
                nodes[index].layout = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-role":
                nodes[index].role = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-icon-library":
                nodes[index].iconLibrary = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-icon-name":
                nodes[index].iconName = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-icon-source":
                nodes[index].iconSource = normalizedValue.isEmpty ? nil : normalizedValue
            default:
                break
            }
        }

        if edit.operation.removesAbsoluteLayoutChildPositionDeclarations {
            removeCachedDirectChildPositionDeclarations(parentNodeID: selectedNodeID)
        }

        if editResult.requiresReload {
            requestDocumentReplacementFromDisk(for: target, selectedNodeID: selectedNode.id)
        } else {
            attributeMutationSequence += 1
            attributeMutation = NodeAttributeMutation(
                sequence: attributeMutationSequence,
                pageURL: target.htmlURL,
                nodeID: selectedNode.id,
                name: name,
                value: normalizedValue
            )
        }
        statusMessage = "\(selectedNode.displayID) の \(name) を更新しました。"
    }

    /// 論理名（日本語）: Cached direct child位置宣言削除関数
    /// 処理概要: 親 layout が absolute から flow へ変わった際、直下 child の位置指定を app 内 cache から削除します。
    ///
    /// - Parameter parentNodeID: 直下 child を更新する親 node の選択 ID。
    private func removeCachedDirectChildPositionDeclarations(parentNodeID: String) {
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentNodeID }) else { return }
        let parentDepth = nodes[parentIndex].depth
        let directChildDepth = parentDepth + 1
        var index = nodes.index(after: parentIndex)
        while index < nodes.endIndex {
            guard nodes[index].depth > parentDepth else { break }
            if nodes[index].depth == directChildDepth {
                for key in Self.absoluteLayoutChildPositionCSSKeys {
                    nodes[index].cssVariables.removeValue(forKey: key)
                    recordCSSVariableBaseline(nodeInternalID: nodes[index].internalID, key: key, value: "")
                }
            }
            index = nodes.index(after: index)
        }
    }

    /// 論理名（日本語）: ノード表示ID更新関数
    /// 処理概要: Layers のインライン編集から選択中ノードの `data-og-id` を正規化して更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameter value: Layers で入力された新しいオブジェクト名。
    func updateNodeDisplayID(value: String) {
        guard let selectedNodeID,
              let selectedNode,
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let normalizedValue = Self.normalizedNodeDisplayID(value)
        guard selectedNode.displayID != normalizedValue else { return }

        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .renameNodeID(
                nodeInternalID: selectedNode.internalID,
                value: normalizedValue,
                expectedOldValue: selectedNode.displayID
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return }

        attributeMutationSequence += 1
        attributeMutation = NodeAttributeMutation(
            sequence: attributeMutationSequence,
            pageURL: editTarget.htmlURL,
            nodeID: selectedNodeID,
            name: "data-og-id",
            value: normalizedValue
        )
        statusMessage = "\(selectedNode.displayID) を \(normalizedValue) に変更しました。"
    }

    /// 論理名（日本語）: ノードテキスト内容プレビュー関数
    /// 処理概要: 選択中 text node の app 内 cache を更新し、永続化せず WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から入力中のプレーンテキスト。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ反映します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ反映します。
    /// - Returns: live 反映対象として受理できた場合は `true`。
    @discardableResult
    func previewNodeTextContent(_ value: String, expectedNodeID: String? = nil, expectedPageURL: URL? = nil) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.type == "text",
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }
        guard let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) else {
            return false
        }

        let previousActiveValue = nodes[index].textContent ?? ""
        let previousFallbackValue = selectedNodeTextFallbackValue(nodes[index])
        let shouldUpdateActiveValue = !nodes[index].isTextBinding || previousActiveValue == previousFallbackValue
        guard previousFallbackValue != value || (shouldUpdateActiveValue && previousActiveValue != value) else {
            return true
        }

        nodes[index].fallbackTextContent = value
        if shouldUpdateActiveValue {
            nodes[index].textContent = value
        }

        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .fallback
        )
        return true
    }

    /// 論理名（日本語）: ノードテキスト内容更新関数
    /// 処理概要: 選択中 text node の HTML 正本 fallback を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から確定されたプレーンテキスト。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedOldValue: 入力開始時の保存済み fallback。live cache 更新後の確定保存で競合判定に使います。
    /// - Returns: 保存が成功した、または保存不要だった場合は `true`。
    @discardableResult
    func updateNodeTextContent(
        _ value: String,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil,
        expectedOldValue: String? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.type == "text",
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return false
        }

        let resolvedExpectedOldValue = expectedOldValue ?? selectedNodeTextFallbackValue(selectedNode)
        guard resolvedExpectedOldValue != value else { return true }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setTextContent(
                nodeInternalID: selectedNode.internalID,
                text: value,
                expectedOldValue: resolvedExpectedOldValue
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return false }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let previousActiveValue = nodes[index].textContent ?? ""
            let previousFallbackValue = selectedNodeTextFallbackValue(nodes[index])
            nodes[index].fallbackTextContent = value
            if !nodes[index].isTextBinding || previousActiveValue == previousFallbackValue {
                nodes[index].textContent = value
            }
        }

        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .fallback
        )
        statusMessage = "\(selectedNode.displayID) の text を更新しました。"
        return true
    }

    /// 論理名（日本語）: i18nテキストresource値一覧取得関数
    /// 処理概要: 選択中 text node の i18n key に対応する locale JSON 値を読み取ります。
    ///
    /// - Parameters:
    ///   - node: 値を読み取る binding text node。
    ///   - inspection: i18n runtime 検査結果。
    /// - Returns: locale を key、resource 内 text を value とする辞書。
    func i18nTextResourceValues(
        for node: OpenGraphiteNode,
        inspection: OpenGraphiteI18nRuntimeInspection?
    ) -> [String: String] {
        guard node.isTextBinding,
              let i18nKey = Self.nonEmptyTrimmed(node.i18nKey),
              let inspection
        else {
            return [:]
        }

        var values: [String: String] = [:]
        for resource in inspection.resources {
            let resourceURL = URL(fileURLWithPath: resource.path)
            guard let value = Self.i18nTextResourceValue(at: resourceURL, key: i18nKey) else {
                continue
            }
            values[resource.locale] = value
        }
        return values
    }

    /// 論理名（日本語）: Active Resolvedテキスト編集文脈取得関数
    /// 処理概要: 選択中 binding text の表示 locale と locale JSON への書き戻し可否を返します。
    ///
    /// - Parameter node: 文脈を取得する text node。
    /// - Returns: 表示 locale と編集可否。binding text ではない場合や locale を解決できない場合は `nil`。
    func activeResolvedTextEditContext(for node: OpenGraphiteNode) -> (locale: String, isEditable: Bool)? {
        resolvedTextEditContext(for: node, locale: nil)
    }

    /// 論理名（日本語）: Resolvedテキスト編集文脈取得関数
    /// 処理概要: 指定 locale の locale JSON へ書き戻せるかを返します。locale 未指定時は preview 表示中 locale を使います。
    ///
    /// - Parameters:
    ///   - node: 文脈を取得する text node。
    ///   - locale: 対象 locale。`nil` の場合は active preview locale。
    /// - Returns: 対象 locale と編集可否。binding text ではない場合や locale を解決できない場合は `nil`。
    func resolvedTextEditContext(
        for node: OpenGraphiteNode,
        locale: String?
    ) -> (locale: String, isEditable: Bool)? {
        guard node.isTextBinding,
              node.i18nKey != nil,
              let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale()
        else {
            return nil
        }

        guard let inspection = selectedI18nRuntimeInspection,
              inspection.adapter != .unknown
        else {
            return (locale: resolvedLocale, isEditable: false)
        }

        let resource = inspection.resources.first { $0.locale == resolvedLocale }
        let isEditable = resource?.editable ?? (inspection.loadPath.source != .external)
        return (locale: resolvedLocale, isEditable: isEditable)
    }

    /// 論理名（日本語）: Active Resolvedテキスト内容プレビュー関数
    /// 処理概要: 表示中 locale の解決済み text を app 内 cache と WebView へ反映します。locale resource は保存しません。
    ///
    /// - Parameters:
    ///   - value: Inspector から入力中の表示中 locale のプレーンテキスト。
    ///   - locale: 更新対象 locale。省略時は現在の preview context から解決します。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ反映します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ反映します。
    /// - Returns: live 反映対象として受理できた場合は `true`。
    @discardableResult
    func previewActiveResolvedTextContent(
        _ value: String,
        locale: String? = nil,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.isTextBinding,
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }

        guard let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale() else {
            lastError = "表示中 locale を解決できないため Active Resolved を反映できません。"
            return false
        }
        guard resolvedTextEditContext(for: selectedNode, locale: resolvedLocale)?.isEditable == true else {
            lastError = "\(resolvedLocale) の text resource は編集できません。Project の i18n 設定を確認してください。"
            return false
        }
        guard isActiveResolvedLocale(resolvedLocale) else {
            lastError = nil
            return true
        }
        guard let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) else {
            return false
        }
        guard nodes[index].textContent != value else {
            return true
        }

        nodes[index].textContent = value
        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .resolved
        )
        lastError = nil
        return true
    }

    /// 論理名（日本語）: Active Resolvedテキスト内容更新関数
    /// 処理概要: 表示中 locale の i18n resource 値を更新し、WebView へ解決済み表示値の mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から確定された表示中 locale のプレーンテキスト。
    ///   - locale: 更新対象 locale。省略時は現在の preview context から解決します。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ保存します。
    /// - Returns: 保存が成功した、または保存不要だった場合は `true`。
    @discardableResult
    func updateActiveResolvedTextContent(
        _ value: String,
        locale: String? = nil,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.isTextBinding,
              let i18nKey = selectedNode.i18nKey,
              let loadedProject,
              let pageID = selectedPageReferenceID(),
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }

        let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale()
        guard let resolvedLocale else {
            lastError = "表示中 locale を解決できないため Active Resolved を保存できません。"
            return false
        }
        guard resolvedTextEditContext(for: selectedNode, locale: resolvedLocale)?.isEditable == true else {
            lastError = "\(resolvedLocale) の locale JSON は編集できません。Project の i18n 設定を確認してください。"
            return false
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.setI18nResourceValue(
                value,
                locale: resolvedLocale,
                key: i18nKey,
                projectURL: loadedProject.fileURL,
                pageID: pageID
            )
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return false
            }

            if isActiveResolvedLocale(resolvedLocale),
               let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                nodes[index].textContent = value
                publishTextMutation(
                    pageURL: target.htmlURL,
                    nodeID: selectedNode.id,
                    value: value,
                    mode: .resolved
                )
            }
            lastError = nil
            statusMessage = result.updated
                ? "\(selectedNode.displayID) の \(resolvedLocale) text resource を更新しました。"
                : "\(selectedNode.displayID) の \(resolvedLocale) text resource は変更されていません。"
            return true
        } catch {
            lastError = "Active Resolved の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: アイコン属性更新関数
    /// 処理概要: 選択中 icon node の metadata と保存済み描画 HTML を更新し、WebView へ置換要求を発行します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide として保存します。
    ///   - name: icon name。空の場合は circle として保存します。
    ///   - source: icon source。空の場合は inline として保存します。
    func updateIcon(library: String, name: String, source: String) {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.type == "icon",
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let currentLibrary = selectedNode.iconLibrary ?? OpenGraphiteIconMarkup.defaultLibrary
        let currentName = selectedNode.iconName ?? OpenGraphiteIconMarkup.defaultName
        let currentSource = selectedNode.iconSource ?? OpenGraphiteIconMarkup.defaultSource
        let normalizedLibrary = Self.normalizedIconValue(library, defaultValue: OpenGraphiteIconMarkup.defaultLibrary)
        let normalizedName = Self.normalizedIconValue(name, defaultValue: OpenGraphiteIconMarkup.defaultName)
        let normalizedSource = Self.normalizedIconValue(source, defaultValue: OpenGraphiteIconMarkup.defaultSource)

        guard currentLibrary != normalizedLibrary
                || currentName != normalizedName
                || currentSource != normalizedSource
        else {
            return
        }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setIcon(
                nodeInternalID: selectedNode.internalID,
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                expectedOldValues: [
                    "data-og-icon-library": selectedNode.iconLibrary ?? "",
                    "data-og-icon-name": selectedNode.iconName ?? "",
                    "data-og-icon-source": selectedNode.iconSource ?? ""
                ]
            )
        )
        let result = applyHTMLObjectEdit(edit)
        guard result.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            nodes[index].iconLibrary = normalizedLibrary
            nodes[index].iconName = normalizedName
            nodes[index].iconSource = normalizedSource
        }

        if result.requiresReload {
            requestDocumentReplacementFromDisk(for: target, selectedNodeID: selectedNodeID)
        }
        statusMessage = "\(selectedNode.displayID) の icon を更新しました。"
    }

    /// 論理名（日本語）: CSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markMutationApplied(sequence: Int) {
        guard cssMutation?.sequence == sequence else { return }
        cssMutation = nil
    }

    /// 論理名（日本語）: 複数CSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した複数 CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markVariablesMutationApplied(sequence: Int) {
        guard cssVariablesMutation?.sequence == sequence else { return }
        cssVariablesMutation = nil
    }

    /// 論理名（日本語）: 複数ノードCSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した複数ノード CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markVariablesBatchMutationApplied(sequence: Int) {
        guard cssVariablesBatchMutation?.sequence == sequence else { return }
        cssVariablesBatchMutation = nil
    }

    /// 論理名（日本語）: 属性mutation適用完了関数
    /// 処理概要: WebView への反映が完了した属性 mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markAttributeMutationApplied(sequence: Int) {
        guard attributeMutation?.sequence == sequence else { return }
        attributeMutation = nil
    }

    /// 論理名（日本語）: テキストmutation適用完了関数
    /// 処理概要: WebView への反映が完了した text mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markTextMutationApplied(sequence: Int) {
        guard textMutation?.sequence == sequence else { return }
        textMutation = nil
    }

    /// 論理名（日本語）: 現在HTML同期関数
    /// 処理概要: 互換用に現在選択中 HTML へ全文同期します。WebView callback では URL 固定の `syncHTML(_:target:)` を使います。
    ///
    /// - Parameter html: 同期する HTML 文字列。
    func syncCurrentHTML(_ html: String) {
        guard let target = currentHTMLSyncTarget() else { return }
        syncHTML(html, target: target)
    }

    /// 論理名（日本語）: HTML全文同期関数
    /// 処理概要: 固定済み保存対象へ HTML 全文を同期します。ディスクが別編集で更新済みの場合は上書きしません。
    ///
    /// - Parameters:
    ///   - html: 同期する HTML 文字列。
    ///   - target: 保存対象 HTML。
    /// - Returns: 同期できた場合は `true`。
    @discardableResult
    func syncHTML(_ html: String, target: HTMLSyncTarget) -> Bool {
        guard validateHTMLSyncTarget(target) != nil else { return false }
        guard diskHTMLMatchesKnownBaseline(at: target.htmlURL) else {
            reportHTMLObjectEditConflict()
            return false
        }
        var history = historyForPage(at: target.htmlURL, fallbackHTML: html)

        do {
            try html.write(to: target.htmlURL, atomically: true, encoding: .utf8)
            lastKnownPageHTMLByURL[target.htmlURL] = html
            history.recordSync(html: html)
            syncHistories[target.htmlURL] = history
            updateHistoryAvailability()
            statusMessage = "\(target.htmlURL.lastPathComponent) と同期しました。"
            return true
        } catch {
            lastError = "HTMLの同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集payload適用関数
    /// 処理概要: JavaScript 由来の object edit payload を固定済み HTML 対象へ保存します。
    ///
    /// - Parameters:
    ///   - payload: `operation` を含む JavaScript bridge payload。
    ///   - target: 保存対象 HTML。
    /// - Returns: 保存結果。
    func applyHTMLObjectEditPayload(_ payload: [String: Any], target: HTMLSyncTarget) -> HTMLObjectEditResult {
        guard let edit = htmlObjectEdit(from: payload, target: target) else {
            lastError = "HTMLの保存形式が不正です。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }
        let result = applyHTMLObjectEdit(edit)
        if result.updated {
            requestInspectorSections(for: edit.operation)
        }
        return result
    }

    /// 論理名（日本語）: Inspectorセクション開放要求関数
    /// 処理概要: Preview 側編集で変更されたパラメータに対応する Inspector カードを現在選択スコープ内で開く要求を発行します。
    ///
    /// - Parameter sectionIDs: 開く対象の Inspector セクション ID 集合。
    private func requestInspectorSections(_ sectionIDs: Set<InspectorSectionID>) {
        guard !sectionIDs.isEmpty else { return }
        inspectorSectionOpenRequestSequence += 1
        inspectorSectionOpenRequest = InspectorSectionOpenRequest(
            sequence: inspectorSectionOpenRequestSequence,
            scopeIdentifier: inspectorExpansionScopeIdentifier,
            sectionIDs: sectionIDs
        )
    }

    /// 論理名（日本語）: HTML編集操作対応Inspectorセクション開放要求関数
    /// 処理概要: Web preview 由来の object edit 操作を Inspector セクションへ分類し、該当カードを開く要求を発行します。
    ///
    /// - Parameter operation: 保存に成功した HTML object edit 操作。
    private func requestInspectorSections(for operation: HTMLObjectEditOperation) {
        requestInspectorSections(InspectorSectionID.sections(for: operation))
    }

    /// 論理名（日本語）: ドキュメント変更取り消し関数
    /// 処理概要: 現在ページの同期履歴を一段戻し、HTML ファイルと WebView へ同じスナップショットを適用します。
    func undoDocumentChange() {
        applyHistoryNavigation(direction: .undo)
    }

    /// 論理名（日本語）: ドキュメント変更やり直し関数
    /// 処理概要: 現在ページの redo 履歴を一段進め、HTML ファイルと WebView へ同じスナップショットを適用します。
    func redoDocumentChange() {
        applyHistoryNavigation(direction: .redo)
    }

    /// 論理名（日本語）: ドキュメント置換要求適用完了関数
    /// 処理概要: WebView で適用済みになった HTML 置換要求を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した置換要求の順序番号。
    func markDocumentReplacementApplied(sequence: Int) {
        guard documentReplacementRequest?.sequence == sequence else { return }
        documentReplacementRequest = nil
    }

    /// 論理名（日本語）: 外部HTML変更同期関数
    /// 処理概要: ディスク上の現在ページ HTML が最後に把握した内容から変わっていれば WebView 置換要求へ変換します。
    func refreshSelectedPageFromDiskIfChanged() {
        guard let selectedPageURL else { return }
        refreshPageFromDiskIfChanged(at: selectedPageURL)
    }

    /// 論理名（日本語）: ページHTML外部変更同期関数
    /// 処理概要: 指定 HTML の外部変更を検出し、選択中ページは置換要求へ、非選択ページは WebView reload token へ反映します。
    ///
    /// - Parameter pageURL: 外部変更を確認する HTML URL。
    func refreshPageFromDiskIfChanged(at pageURL: URL) {
        guard let diskHTML = readHTMLFromDisk(at: pageURL) else { return }

        defer {
            restartExternalPageMonitoring(force: true)
        }

        let lastKnownHTML = lastKnownPageHTMLByURL[pageURL]
        guard lastKnownHTML != diskHTML else { return }

        if pageURL != selectedPageURL {
            lastKnownPageHTMLByURL[pageURL] = diskHTML
            incrementReloadToken(for: pageURL)
            statusMessage = "\(pageURL.lastPathComponent) の外部変更を表示へ同期しました。"
            return
        }

        guard cssMutation == nil,
              cssVariablesMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            statusMessage = "\(pageURL.lastPathComponent) の外部変更を検出しました。未適用の編集があるため自動同期を保留しています。"
            return
        }

        var history = historyForPage(at: pageURL, fallbackHTML: diskHTML)
        history.recordSync(html: diskHTML)
        syncHistories[pageURL] = history
        lastKnownPageHTMLByURL[pageURL] = diskHTML
        documentReplacementSequence += 1
        documentReplacementRequest = DocumentReplacementRequest(
            sequence: documentReplacementSequence,
            pageURL: pageURL,
            html: diskHTML,
            selectedNodeID: selectedNodeID
        )
        updateHistoryAvailability()
        statusMessage = "\(pageURL.lastPathComponent) の外部変更を同期しました。"
    }

    /// 論理名（日本語）: 外部プロジェクト変更同期関数
    /// 処理概要: ディスク上の `.ogp` が変わっていれば再読込し、ページ一覧とキャンバス配置を表示へ反映します。
    func refreshProjectManifestFromDiskIfChanged() {
        guard let currentProject = loadedProject else { return }

        defer {
            restartExternalProjectMonitoring(force: true)
        }

        do {
            let reloadedProject = try loader.loadProject(at: currentProject.fileURL)
            guard reloadedProject.project != currentProject.project
                    || reloadedProject.rootURL != currentProject.rootURL
            else {
                return
            }

            let previousSelectedPageInternalID = selectedPageInternalID
            let previousSelectedComponentPageInternalID = selectedComponentPageInternalID
            let previousSelectedChapterInternalID = selectedChapterInternalID
            let previousSelectedCollectionInternalID = selectedCollectionInternalID
            let previousSelectedCanvasSegment = selectedCanvasSegment
            let previousSelectedPageURL = selectedPageURL
            loadedProject = reloadedProject
            seedKnownHTMLForProject(reloadedProject)

            if let chapter = reloadedProject.project.chapters.first(where: {
                $0.internalID == previousSelectedChapterInternalID
            }) {
                selectedChapterID = chapter.id
                selectedChapterInternalID = chapter.internalID
            } else {
                selectedChapterID = reloadedProject.project.chapters.first?.id
                selectedChapterInternalID = reloadedProject.project.chapters.first?.internalID
            }

            let currentChapterPages = selectedChapter?.pages ?? []
            if let page = currentChapterPages.first(where: {
                $0.internalID == previousSelectedPageInternalID
            }) {
                selectedPageID = page.id
                selectedPageInternalID = page.internalID
            } else if previousSelectedPageInternalID != nil {
                selectedPageID = currentChapterPages.first?.id
                selectedPageInternalID = currentChapterPages.first?.internalID
            } else {
                selectedPageID = nil
                selectedPageInternalID = nil
            }

            if let collection = Self.preferredCollection(in: reloadedProject.project, internalID: previousSelectedCollectionInternalID) {
                selectedCollectionID = collection.id
                selectedCollectionInternalID = collection.internalID
            } else {
                selectedCollectionID = nil
                selectedCollectionInternalID = nil
            }

            let currentCollectionComponents = selectedComponentCollection?.components ?? []
            if let componentPage = currentCollectionComponents.first(where: {
                $0.internalID == previousSelectedComponentPageInternalID
            }) {
                selectedComponentPageID = componentPage.id
                selectedComponentPageInternalID = componentPage.internalID
            } else if previousSelectedComponentPageInternalID != nil,
                      let containingCollection = reloadedProject.project.collections.first(where: { collection in
                          collection.components.contains { $0.internalID == previousSelectedComponentPageInternalID }
                      }),
                      let componentPage = containingCollection.components.first(where: {
                          $0.internalID == previousSelectedComponentPageInternalID
                      }) {
                selectedCollectionID = containingCollection.id
                selectedCollectionInternalID = containingCollection.internalID
                selectedComponentPageID = componentPage.id
                selectedComponentPageInternalID = componentPage.internalID
            } else {
                let fallbackCollection = Self.preferredCollection(in: reloadedProject.project, internalID: selectedCollectionInternalID)
                selectedCollectionID = fallbackCollection?.id
                selectedCollectionInternalID = fallbackCollection?.internalID
                selectedComponentPageID = fallbackCollection?.components.first?.id
                selectedComponentPageInternalID = fallbackCollection?.components.first?.internalID
            }

            if previousSelectedCanvasSegment == .components, !reloadedProject.project.components.isEmpty {
                selectedCanvasSegment = .components
            } else {
                selectedCanvasSegment = .pages
            }

            if selectedPageURL != previousSelectedPageURL {
                selectedNodeID = nil
                nodes = []
                prepareHistoryForSelectedPage()
            }

            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
            statusMessage = "\(reloadedProject.project.name) の .ogp 外部変更を同期しました。"
        } catch {
            lastError = ".ogp の再読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: project依存ファイル外部変更同期関数
    /// 処理概要: CSS、runtime、component master など HTML 以外の依存変更を全 WebView の reload token へ反映します。
    func refreshProjectDependenciesFromDisk() {
        guard let loadedProject else { return }

        for page in loadedProject.project.allPages {
            incrementReloadToken(for: loadedProject.htmlURL(for: page))
        }
        restartExternalDependencyMonitoring(force: true)
        statusMessage = "CSS / Components の外部変更を表示へ同期しました。"
    }

    /// 論理名（日本語）: WebViewエラー報告関数
    /// 処理概要: WebView や JavaScript ブリッジで発生したエラー文を画面表示用に保存します。
    ///
    /// - Parameter message: 表示するエラーメッセージ。
    func reportWebError(_ message: String) {
        lastError = message
    }

    /// 論理名（日本語）: 履歴ナビゲーション方向
    /// 概要: undo/redo のどちらの履歴移動を行うかを表します。
    ///
    /// 定義内容:
    /// - `undo`: 取り消し方向。
    /// - `redo`: やり直し方向。
    private enum HistoryNavigationDirection {
        case undo
        case redo
    }

    /// 論理名（日本語）: HTML依存参照復元情報
    /// 概要: Component ファイル名変更時に書き換えた参照元 HTML を、失敗時に元へ戻すための最小情報を保持します。
    ///
    /// プロパティ:
    /// - `url`: 復元対象 HTML URL。
    /// - `data`: 変更前 HTML data。
    private struct HTMLDependencyRewriteBackup {
        var url: URL
        var data: Data
    }

    /// 論理名（日本語）: 選択ページ履歴準備関数
    /// 処理概要: 選択ページの HTML をディスクから読み込み、未登録であれば履歴の初期値にします。
    private func prepareHistoryForSelectedPage() {
        guard let selectedPageURL else {
            updateHistoryAvailability()
            return
        }

        if syncHistories[selectedPageURL] == nil,
           let html = readHTMLFromDisk(at: selectedPageURL) {
            syncHistories[selectedPageURL] = DocumentSyncHistory(initialHTML: html)
            lastKnownPageHTMLByURL[selectedPageURL] = html
        }
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: ページ履歴取得関数
    /// 処理概要: 指定ページの同期履歴を返し、未登録の場合はディスク上の HTML または fallback で初期化します。
    ///
    /// - Parameters:
    ///   - pageURL: 履歴を取得するページ URL。
    ///   - fallbackHTML: ディスク読み込みに失敗した場合の初期 HTML。
    /// - Returns: 指定ページの同期履歴。
    private func historyForPage(at pageURL: URL, fallbackHTML: String) -> DocumentSyncHistory {
        if let history = syncHistories[pageURL] {
            return history
        }

        let initialHTML = readHTMLFromDisk(at: pageURL) ?? fallbackHTML
        let history = DocumentSyncHistory(initialHTML: initialHTML)
        syncHistories[pageURL] = history
        return history
    }

    /// 論理名（日本語）: 現在HTML同期対象取得関数
    /// 処理概要: 現在選択中の HTML カードを object edit 用同期対象に変換します。
    private func currentHTMLSyncTarget() -> HTMLSyncTarget? {
        guard let selectedPage else { return nil }
        return htmlSyncTarget(for: selectedPage, segment: selectedCanvasSegment)
    }

    /// 論理名（日本語）: CSS編集対象HTML同期先取得関数
    /// 処理概要: runtime 展開された component instance 内 node は component master の HTML/CSS を保存先にし、それ以外は現在表示中 HTML を保存先にします。
    ///
    /// - Parameter node: CSS declaration を編集する選択ノード。
    /// - Returns: CSS declaration の保存対象。解決できない場合は `nil`。
    private func cssEditTarget(for node: OpenGraphiteNode) -> HTMLSyncTarget? {
        if node.isRuntimeComponentGenerated,
           let source = componentSource(for: node),
           let componentTarget = htmlSyncTarget(forComponentSource: source) {
            return componentTarget
        }
        return currentHTMLSyncTarget()
    }

    /// 論理名（日本語）: Component source同期先取得関数
    /// 処理概要: Inspector が解決した component master 情報から、該当 component canvas の HTML 同期対象を取得します。
    ///
    /// - Parameter source: component master の場所を表す情報。
    /// - Returns: component canvas の同期対象。project から解決できない場合は `nil`。
    private func htmlSyncTarget(forComponentSource source: OpenGraphiteComponentSource) -> HTMLSyncTarget? {
        guard let loadedProject,
              let collection = loadedProject.project.collections.first(where: { $0.internalID == source.collectionInternalID }),
              let componentPage = collection.components.first(where: { $0.internalID == source.componentPageInternalID })
        else {
            return nil
        }
        return htmlSyncTarget(for: componentPage, segment: .components)
    }

    /// 論理名（日本語）: HTML同期対象検証関数
    /// 処理概要: object identity が現在の `.ogp` に残っており、解決 URL が固定済み URL と一致するか確認します。
    ///
    /// - Parameter target: 検証する同期対象。
    /// - Returns: 現在の project から解決した page。検証できない場合は `nil`。
    private func validateHTMLSyncTarget(_ target: HTMLSyncTarget) -> OpenGraphitePage? {
        guard let loadedProject,
              loadedProject.fileURL == target.identity.projectURL,
              let page = page(for: target.identity, in: loadedProject)
        else {
            reportHTMLObjectEditConflict()
            return nil
        }

        let resolvedURL = loadedProject.htmlURL(for: page).standardizedFileURL
        let fixedURL = target.htmlURL.standardizedFileURL
        guard resolvedURL == fixedURL, page.path == target.path else {
            reportHTMLObjectEditConflict()
            return nil
        }
        return page
    }

    /// 論理名（日本語）: HTMLカード解決関数
    /// 処理概要: HTML document identity から現在 project 内の page entry を解決します。
    ///
    /// - Parameters:
    ///   - identity: 解決する document identity。
    ///   - loadedProject: 検索対象 project。
    /// - Returns: 対応する page entry。見つからない場合は `nil`。
    private func page(for identity: HTMLDocumentIdentity, in loadedProject: LoadedOpenGraphiteProject) -> OpenGraphitePage? {
        switch identity.segment {
        case .pages:
            return loadedProject.project.chapters
                .first { $0.internalID == identity.containerInternalID }?
                .pages
                .first { $0.internalID == identity.pageInternalID }
        case .components:
            return loadedProject.project.collections
                .first { $0.internalID == identity.containerInternalID }?
                .components
                .first { $0.internalID == identity.pageInternalID }
        }
    }

    /// 論理名（日本語）: 既知HTML基準一致判定関数
    /// 処理概要: ディスク上の HTML が最後に把握した内容から変わっていないかを確認します。
    ///
    /// - Parameter pageURL: 確認する HTML URL。
    /// - Returns: 既知基準と一致する場合は `true`。
    private func diskHTMLMatchesKnownBaseline(at pageURL: URL) -> Bool {
        guard let baselineHTML = lastKnownPageHTMLByURL[pageURL] else { return true }
        guard let diskHTML = readHTMLFromDisk(at: pageURL) else { return false }
        return baselineHTML == diskHTML
    }

    /// 論理名（日本語）: HTMLオブジェクト編集適用関数
    /// 処理概要: 最新ディスク HTML に node 単位 mutation を適用し、同一 object の競合があれば上書きせず中止します。
    ///
    /// - Parameter edit: 適用する object edit。
    /// - Returns: 保存結果。
    @discardableResult
    private func applyHTMLObjectEdit(_ edit: HTMLObjectEdit) -> HTMLObjectEditResult {
        guard validateHTMLSyncTarget(edit.target) != nil else { return .failed }
        guard let diskHTML = readHTMLFromDisk(at: edit.target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? edit.target.htmlURL)
        let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: edit.target.htmlURL)
        let document = OpenGraphiteHTMLDocument(html: diskHTML)
        guard objectEditBaselineMatches(edit.operation, in: document, companionCSS: companionCSS, contract: contract) else {
            reportHTMLObjectEditConflict()
            return .failed
        }

        if let cssResult = applyCompanionCSSObjectEditIfNeeded(edit, diskHTML: diskHTML, contract: contract) {
            return cssResult
        }

        let mutation = mutationResult(for: edit.operation, html: diskHTML, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = "HTMLの保存に失敗しました。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }
        if mutation.html == diskHTML {
            return .noChange
        }

        do {
            let persisted = try htmlObjectEditPersistencePayload(
                for: edit,
                mutationHTML: mutation.html,
                contract: contract
            )
            let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: edit.target.htmlURL)
            let previousCompanionCSS = (try? String(contentsOf: companionCSSURL, encoding: .utf8)) ?? ""
            let companionCSSChanged = persisted.companionCSS.map { $0.css != previousCompanionCSS } ?? false
            if persisted.html == diskHTML && !companionCSSChanged {
                return .noChange
            }

            try persisted.html.write(to: edit.target.htmlURL, atomically: true, encoding: .utf8)
            if companionCSSChanged, let companionCSS = persisted.companionCSS {
                try companionCSS.write(forHTMLURL: edit.target.htmlURL)
            }
            lastKnownPageHTMLByURL[edit.target.htmlURL] = persisted.html
            var history = historyForPage(at: edit.target.htmlURL, fallbackHTML: diskHTML)
            history.recordSync(html: persisted.html)
            syncHistories[edit.target.htmlURL] = history
            updateHistoryAvailability()
            statusMessage = "\(edit.target.htmlURL.lastPathComponent) と同期しました。"
            return HTMLObjectEditResult(updated: true, requiresReload: edit.operation.requiresWebViewReload)
        } catch {
            lastError = "HTMLの同期に失敗しました: \(error.localizedDescription)"
            return .failed
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集永続化payload生成関数
    /// 処理概要: HTML mutation の保存内容を整え、挿入HTML内の editable design value を companion CSS へ移します。
    ///
    /// - Parameters:
    ///   - edit: 適用中の object edit。
    ///   - mutationHTML: HTML mutation 後の候補HTML。
    ///   - contract: CSS declaration の判定に使う OpenGraphite 契約。
    /// - Returns: 保存する HTML と、更新が必要な companion CSS。
    private func htmlObjectEditPersistencePayload(
        for edit: HTMLObjectEdit,
        mutationHTML: String,
        contract: OpenGraphiteContract
    ) throws -> (html: String, companionCSS: OpenGraphiteCompanionCSSDocument?) {
        if edit.operation.removesAbsoluteLayoutChildPositionDeclarations,
           case let .setAttribute(parentInternalID, _, _, _) = edit.operation {
            return try removingAbsoluteLayoutChildPositionDeclarations(
                parentInternalID: parentInternalID,
                html: mutationHTML,
                htmlURL: edit.target.htmlURL,
                contract: contract
            )
        }

        guard case .insertHTML = edit.operation else {
            return (mutationHTML, nil)
        }

        let runtimeSanitizedHTML = OpenGraphiteHTMLDocument(html: mutationHTML)
            .removingRuntimeState(contract: contract)
        let legacyDocument = OpenGraphiteHTMLDocument(html: runtimeSanitizedHTML)
        let sanitizedHTML = legacyDocument.removingOpenGraphiteStyleVariables(contract: contract)
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: edit.target.htmlURL)
        migrateInlineOpenGraphiteCSSVariables(from: legacyDocument, into: &companionCSS, contract: contract)
        return (sanitizedHTML, companionCSS)
    }

    /// 論理名（日本語）: Absolute layout child位置宣言削除関数
    /// 処理概要: absolute 親から flow layout へ戻す際、直下 child の position / inset 宣言を正本 HTML/CSS から削除します。
    ///
    /// - Parameters:
    ///   - parentInternalID: layout を変更した親 node の `data-og-internal-id`。
    ///   - html: layout 属性変更後の HTML。
    ///   - htmlURL: companion CSS を解決する HTML URL。
    ///   - contract: CSS declaration の判定に使う OpenGraphite 契約。
    /// - Returns: cleanup 後の HTML と、変更された companion CSS。
    private func removingAbsoluteLayoutChildPositionDeclarations(
        parentInternalID: String,
        html: String,
        htmlURL: URL,
        contract: OpenGraphiteContract
    ) throws -> (html: String, companionCSS: OpenGraphiteCompanionCSSDocument?) {
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let originalCompanionCSS = companionCSS.css
        let document = OpenGraphiteHTMLDocument(html: html)
        let nodes = document.nodes(companionCSS: companionCSS, contract: contract)
        guard let parentNode = nodes.first(where: { $0.internalID == parentInternalID }) else {
            return (html, nil)
        }

        let childInternalIDs = nodes
            .filter { $0.parentID == parentNode.id && !$0.internalID.isEmpty }
            .map(\.internalID)
        guard !childInternalIDs.isEmpty else {
            return (html, nil)
        }

        var cleanedHTML = html
        for childInternalID in childInternalIDs {
            for key in Self.absoluteLayoutChildPositionCSSKeys {
                companionCSS.setCSSVariable(key, value: "", forNodeInternalID: childInternalID)
                let mutation = OpenGraphiteHTMLDocument(html: cleanedHTML)
                    .settingCSSVariable(key, value: "", forNodeID: childInternalID, contract: contract)
                if mutation.diagnostics.filter({ $0.severity == .error }).isEmpty {
                    cleanedHTML = mutation.html
                }
            }
        }

        let changedCompanionCSS = companionCSS.css == originalCompanionCSS ? nil : companionCSS
        return (cleanedHTML, changedCompanionCSS)
    }

    /// 論理名（日本語）: Inline design value移行関数
    /// 処理概要: HTML inline style に残る OpenGraphite 編集対象 CSS declaration を companion CSS へ移します。
    ///
    /// - Parameters:
    ///   - document: inline style を含み得る HTML 文書。
    ///   - companionCSS: 移行先の companion CSS 文書。
    ///   - contract: CSS declaration の判定に使う OpenGraphite 契約。
    private func migrateInlineOpenGraphiteCSSVariables(
        from document: OpenGraphiteHTMLDocument,
        into companionCSS: inout OpenGraphiteCompanionCSSDocument,
        contract: OpenGraphiteContract
    ) {
        for node in document.nodes(contract: contract) {
            guard !node.internalID.isEmpty else { continue }
            let existingVariables = companionCSS.cssVariables(forNodeInternalID: node.internalID, contract: contract)
            for key in node.cssVariables.keys.sorted()
                where !contract.runtimeCSSVariableSet.contains(key) && existingVariables[key] == nil {
                companionCSS.setCSSVariable(key, value: node.cssVariables[key] ?? "", forNodeInternalID: node.internalID)
            }
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集payload変換関数
    /// 処理概要: JavaScript bridge payload を Swift の object edit へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から届いた辞書。
    ///   - target: 保存対象 HTML。
    /// - Returns: 変換済み object edit。形式不正の場合は `nil`。
    private func htmlObjectEdit(from payload: [String: Any], target: HTMLSyncTarget) -> HTMLObjectEdit? {
        guard let operation = payload["operation"] as? String else { return nil }

        switch operation {
        case "setCSSVariable":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let key = payload["key"] as? String
            else {
                return nil
            }
            let expectedOldValue = cssVariableBaselineValues(
                for: nodeInternalID,
                keys: [key],
                target: target,
                fallback: [key: payload["previousValue"] as? String ?? ""]
            )[key] ?? ""
            return HTMLObjectEdit(
                target: target,
                operation: .setCSSVariable(
                    nodeInternalID: nodeInternalID,
                    key: key,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: expectedOldValue
                )
            )
        case "setCSSVariables":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let values = payload["values"] as? [String: String]
            else {
                return nil
            }
            let expectedOldValues = cssVariableBaselineValues(
                for: nodeInternalID,
                keys: Array(values.keys),
                target: target,
                fallback: payload["previousValues"] as? [String: String] ?? [:]
            )
            return HTMLObjectEdit(
                target: target,
                operation: .setCSSVariables(
                    nodeInternalID: nodeInternalID,
                    values: values,
                    expectedOldValues: expectedOldValues
                )
            )
        case "setAttribute":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let name = payload["name"] as? String
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .setAttribute(
                    nodeInternalID: nodeInternalID,
                    name: name,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? ""
                )
            )
        case "renameNodeID":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .renameNodeID(
                    nodeInternalID: nodeInternalID,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? ""
                )
            )
        case "setIcon":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .setIcon(
                    nodeInternalID: nodeInternalID,
                    library: payload["library"] as? String ?? OpenGraphiteIconMarkup.defaultLibrary,
                    name: payload["name"] as? String ?? OpenGraphiteIconMarkup.defaultName,
                    source: payload["source"] as? String ?? OpenGraphiteIconMarkup.defaultSource,
                    expectedOldValues: payload["previousValues"] as? [String: String] ?? [:]
                )
            )
        case "setTextContent":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .setTextContent(
                    nodeInternalID: nodeInternalID,
                    text: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? ""
                )
            )
        case "insertHTML":
            guard let anchorInternalID = payload["anchorInternalID"] as? String,
                  let positionValue = payload["position"] as? String,
                  let position = OpenGraphiteHTMLInsertionPosition(rawValue: positionValue),
                  let html = payload["html"] as? String
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .insertHTML(
                    anchorInternalID: anchorInternalID,
                    position: position,
                    html: html,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: anchorInternalID)
                )
            )
        case "replaceNodeHTML":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let html = payload["html"] as? String
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .replaceNodeHTML(
                    nodeInternalID: nodeInternalID,
                    html: html,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        case "deleteNode":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .deleteNode(
                    nodeInternalID: nodeInternalID,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        case "moveNode":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let targetInternalID = payload["targetInternalID"] as? String,
                  let positionValue = payload["position"] as? String,
                  let position = OpenGraphiteHTMLInsertionPosition(rawValue: positionValue)
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .moveNode(
                    nodeInternalID: nodeInternalID,
                    targetInternalID: targetInternalID,
                    position: position,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        default:
            return nil
        }
    }

    /// 論理名（日本語）: CSS宣言baseline値取得関数
    /// 処理概要: DOM payload の inline style 旧値ではなく、ディスク上 HTML と companion CSS の正本値を編集基準にします。
    ///
    /// - Parameters:
    ///   - nodeInternalID: 対象 node の `data-og-internal-id`。
    ///   - keys: 取得する CSS property または OpenGraphite 予約 custom property 名。
    ///   - target: 保存対象 HTML。
    ///   - fallback: 正本から読めない場合に使う payload 由来の旧値。
    /// - Returns: CSS property または OpenGraphite 予約 custom property 名ごとの baseline 値。
    private func cssVariableBaselineValues(
        for nodeInternalID: String,
        keys: [String],
        target: HTMLSyncTarget,
        fallback: [String: String]
    ) -> [String: String] {
        guard let html = readHTMLFromDisk(at: target.htmlURL) else { return fallback }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: target.htmlURL)
        let sourceNode = OpenGraphiteHTMLDocument(html: html)
            .nodes(companionCSS: companionCSS, contract: contract)
            .first { $0.internalID == nodeInternalID }
        return keys.reduce(into: [String: String]()) { result, key in
            result[key] = sourceNode?.cssVariables[key] ?? fallback[key] ?? ""
        }
    }

    /// 論理名（日本語）: CSS宣言期待旧値取得関数
    /// 処理概要: Inspector 表示由来の既定値ではなく、payload 取り込み時に正本 CSS に存在した値を編集基準として返します。
    ///
    /// - Parameters:
    ///   - node: 対象 node。
    ///   - key: 更新する CSS property または OpenGraphite 予約 custom property 名。
    ///   - fallback: 正本 baseline がない場合に使う旧値。
    /// - Returns: object edit に渡す期待旧値。
    private func expectedOldCSSVariableValue(
        for node: OpenGraphiteNode,
        key: String,
        fallback: String
    ) -> String {
        guard let baseline = cssVariableBaselinesByInternalID[node.internalID] else {
            return fallback
        }
        return baseline[key] ?? ""
    }

    /// 論理名（日本語）: CSS宣言baseline更新関数
    /// 処理概要: companion CSS への保存成功後、次回編集の競合判定に使う正本 baseline を更新します。
    ///
    /// - Parameter operation: 保存に成功した object edit operation。
    private func recordCSSVariableBaselineUpdate(for operation: HTMLObjectEditOperation) {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, value, _):
            recordCSSVariableBaseline(nodeInternalID: nodeInternalID, key: key, value: value)
        case let .setCSSVariables(nodeInternalID, values, _):
            for (key, value) in values {
                recordCSSVariableBaseline(nodeInternalID: nodeInternalID, key: key, value: value)
            }
        default:
            break
        }
    }

    /// 論理名（日本語）: CSS宣言baseline単項更新関数
    /// 処理概要: 指定 node の CSS declaration について、保存済み baseline 値を追加・更新・削除します。
    ///
    /// - Parameters:
    ///   - nodeInternalID: 対象 node の `data-og-internal-id`。
    ///   - key: CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: 保存後の値。空文字列の場合は declaration 削除として扱います。
    private func recordCSSVariableBaseline(nodeInternalID: String, key: String, value: String) {
        guard !nodeInternalID.isEmpty else { return }
        var baseline = cssVariableBaselinesByInternalID[nodeInternalID] ?? [:]
        if value.isEmpty {
            baseline.removeValue(forKey: key)
        } else {
            baseline[key] = value
        }
        cssVariableBaselinesByInternalID[nodeInternalID] = baseline
    }

    /// 論理名（日本語）: オブジェクト編集基準一致判定関数
    /// 処理概要: 対象 node の旧値または subtree hash が最新ディスク HTML と一致するか確認します。
    ///
    /// - Parameters:
    ///   - operation: 検証する編集操作。
    ///   - document: 最新ディスク HTML document。
    /// - Returns: 競合がない場合は `true`。
    private func objectEditBaselineMatches(
        _ operation: HTMLObjectEditOperation,
        in document: OpenGraphiteHTMLDocument,
        companionCSS: OpenGraphiteCompanionCSSDocument?,
        contract: OpenGraphiteContract
    ) -> Bool {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, _, expectedOldValue):
            guard let node = document.nodes(companionCSS: companionCSS, contract: contract).first(where: { $0.internalID == nodeInternalID }) else { return false }
            return (node.cssVariables[key] ?? "") == expectedOldValue
        case let .setCSSVariables(nodeInternalID, _, expectedOldValues):
            guard let node = document.nodes(companionCSS: companionCSS, contract: contract).first(where: { $0.internalID == nodeInternalID }) else { return false }
            return expectedOldValues.allSatisfy { key, value in
                (node.cssVariables[key] ?? "") == value
            }
        case let .setAttribute(nodeInternalID, name, _, expectedOldValue):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return (node.attributes[name] ?? "") == expectedOldValue
        case let .renameNodeID(nodeInternalID, _, expectedOldValue):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return node.id == expectedOldValue
        case let .setIcon(nodeInternalID, _, _, _, expectedOldValues):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return expectedOldValues.allSatisfy { key, value in
                (node.attributes[key] ?? "") == value
            }
        case let .setTextContent(nodeInternalID, _, expectedOldValue):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return (node.textContent ?? "") == expectedOldValue
        case let .insertHTML(anchorInternalID, _, _, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: anchorInternalID, in: document)
        case let .replaceNodeHTML(nodeInternalID, _, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        case let .deleteNode(nodeInternalID, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        case let .moveNode(nodeInternalID, targetInternalID, _, baselineNodeHash):
            guard document.elementHTMLHash(forNodeID: targetInternalID) != nil else { return false }
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        }
    }

    /// 論理名（日本語）: Agent coreオブジェクト編集適用関数
    /// 処理概要: CSS declaration や icon 更新を Editor 専用 HTML mutation ではなく AgentCore の正本保存経路へ通します。
    ///
    /// - Parameters:
    ///   - edit: 適用する object edit。
    ///   - diskHTML: 編集前の最新ディスク HTML。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: CSS 編集として処理した場合は保存結果。それ以外は `nil`。
    private func applyCompanionCSSObjectEditIfNeeded(
        _ edit: HTMLObjectEdit,
        diskHTML: String,
        contract: OpenGraphiteContract
    ) -> HTMLObjectEditResult? {
        do {
            let core = OpenGraphiteAgentCore(contract: contract)
            var lastResult: OpenGraphiteEditResult?
            switch edit.operation {
            case let .setCSSVariable(nodeInternalID, key, value, _):
                lastResult = try core.setCSSVariable(
                    key,
                    value: value,
                    nodeID: nodeInternalID,
                    htmlURL: edit.target.htmlURL
                )
            case let .setCSSVariables(nodeInternalID, values, _):
                for key in values.keys.sorted() {
                    lastResult = try core.setCSSVariable(
                        key,
                        value: values[key] ?? "",
                        nodeID: nodeInternalID,
                        htmlURL: edit.target.htmlURL
                    )
                }
            case let .setIcon(nodeInternalID, library, name, source, _):
                lastResult = try core.setIcon(
                    library: library,
                    name: name,
                    source: source,
                    nodeID: nodeInternalID,
                    htmlURL: edit.target.htmlURL
                )
            default:
                return nil
            }

            if lastResult?.diagnostics.contains(where: { $0.severity == .error }) == true {
                lastError = "変更の保存に失敗しました。ページを再読み込みしてからもう一度設定してください。"
                return .failed
            }

            if let html = readHTMLFromDisk(at: edit.target.htmlURL) {
                lastKnownPageHTMLByURL[edit.target.htmlURL] = html
                var history = historyForPage(at: edit.target.htmlURL, fallbackHTML: diskHTML)
                history.recordSync(html: html)
                syncHistories[edit.target.htmlURL] = history
                updateHistoryAvailability()
            }

            statusMessage = "\(OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: edit.target.htmlURL).lastPathComponent) と同期しました。"
            let result = HTMLObjectEditResult(
                updated: lastResult?.updated ?? false,
                requiresReload: edit.operation.requiresWebViewReload
            )
            if result.updated {
                recordCSSVariableBaselineUpdate(for: edit.operation)
            }
            return result
        } catch {
            lastError = "CSSの同期に失敗しました: \(error.localizedDescription)"
            return .failed
        }
    }

    /// 論理名（日本語）: ノードhash一致判定関数
    /// 処理概要: baseline がある場合に最新ディスク HTML の node subtree hash と比較します。
    private func nodeHashMatches(_ baselineNodeHash: String?, nodeInternalID: String, in document: OpenGraphiteHTMLDocument) -> Bool {
        guard let currentHash = document.elementHTMLHash(forNodeID: nodeInternalID) else { return false }
        guard let baselineNodeHash else { return true }
        return currentHash == baselineNodeHash
    }

    /// 論理名（日本語）: HTMLオブジェクトmutation生成関数
    /// 処理概要: object edit operation を既存の HTML document mutation API へ変換します。
    private func mutationResult(
        for operation: HTMLObjectEditOperation,
        html: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, value, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingCSSVariable(key, value: value, forNodeID: nodeInternalID, contract: contract)
        case let .setCSSVariables(nodeInternalID, values, _):
            var currentHTML = html
            for key in values.keys.sorted() {
                let mutation = OpenGraphiteHTMLDocument(html: currentHTML)
                    .settingCSSVariable(key, value: values[key] ?? "", forNodeID: nodeInternalID, contract: contract)
                guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
                    return mutation
                }
                currentHTML = mutation.html
            }
            return OpenGraphiteHTMLMutationResult(html: currentHTML, diagnostics: [])
        case let .setAttribute(nodeInternalID, name, value, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingAttribute(name: name, value: value, forNodeID: nodeInternalID, contract: contract)
        case let .renameNodeID(nodeInternalID, value, _):
            return OpenGraphiteHTMLDocument(html: html)
                .renamingNodeID(value: value, forNodeID: nodeInternalID, contract: contract)
        case let .setIcon(nodeInternalID, library, name, source, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingIcon(library: library, name: name, source: source, forNodeID: nodeInternalID, contract: contract)
        case let .setTextContent(nodeInternalID, text, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingTextContent(text, forNodeID: nodeInternalID, contract: contract)
        case let .insertHTML(anchorInternalID, position, fragmentHTML, _):
            return OpenGraphiteHTMLDocument(html: html)
                .insertingHTML(fragmentHTML, relativeToNodeID: anchorInternalID, position: position, contract: contract)
        case let .replaceNodeHTML(nodeInternalID, replacementHTML, _):
            return OpenGraphiteHTMLDocument(html: html)
                .replacingNodeHTML(replacementHTML, nodeID: nodeInternalID, contract: contract)
        case let .deleteNode(nodeInternalID, _):
            return OpenGraphiteHTMLDocument(html: html)
                .deletingNode(nodeID: nodeInternalID, contract: contract)
        case let .moveNode(nodeInternalID, targetInternalID, position, _):
            return OpenGraphiteHTMLDocument(html: html)
                .movingNode(nodeID: nodeInternalID, relativeToNodeID: targetInternalID, position: position, contract: contract)
        }
    }

    /// 論理名（日本語）: baselineノードhash取得関数
    /// 処理概要: 最後に把握した HTML から対象 node subtree の hash を取得します。
    private func baselineNodeHash(for target: HTMLSyncTarget, nodeInternalID: String) -> String? {
        guard let baselineHTML = lastKnownPageHTMLByURL[target.htmlURL] else { return nil }
        return OpenGraphiteHTMLDocument(html: baselineHTML).elementHTMLHash(forNodeID: nodeInternalID)
    }

    /// 論理名（日本語）: テキストmutation発行関数
    /// 処理概要: app 内 cache 上の text 変更を WebView へ反映するための mutation を発行します。
    ///
    /// - Parameters:
    ///   - pageURL: 反映対象 HTML の URL。
    ///   - nodeID: 反映対象 node の表示 ID。
    ///   - value: WebView へ渡す text 値。
    ///   - mode: fallback / resolved の反映モード。
    private func publishTextMutation(
        pageURL: URL,
        nodeID: String,
        value: String,
        mode: NodeTextContentMutationMode
    ) {
        textMutationSequence += 1
        textMutation = NodeTextContentMutation(
            sequence: textMutationSequence,
            pageURL: pageURL,
            nodeID: nodeID,
            value: value,
            mode: mode
        )
    }

    /// 論理名（日本語）: HTMLオブジェクト編集競合報告関数
    /// 処理概要: 同時編集や path 変更を検出したときに、上書きせず再設定を促す簡易エラーを表示します。
    private func reportHTMLObjectEditConflict() {
        lastError = "HTMLが別の編集で更新されています。ページを再読み込みしてからもう一度設定してください。"
    }

    /// 論理名（日本語）: 選択ノードテキストfallback値取得関数
    /// 処理概要: binding text では HTML 正本の fallback、literal text では現在の本文を編集基準値として返します。
    ///
    /// - Parameter node: 基準値を取得する text node。
    /// - Returns: Inspector から保存する text content の現在値。
    private func selectedNodeTextFallbackValue(_ node: OpenGraphiteNode) -> String {
        node.fallbackTextContent ?? node.textContent ?? ""
    }

    /// 論理名（日本語）: Active Resolved locale解決関数
    /// 処理概要: i18n runtime の locale field、preview mock state、HTML lang fallback から表示中 locale を解決します。
    ///
    /// - Returns: 表示中 text resource の locale。解決できない場合は `nil`。
    private func activeResolvedTextLocale() -> String? {
        let inspection = selectedI18nRuntimeInspection
        let previewContext = selectedPage?.canvas.previewContext ?? .empty
        if let localeField = Self.nonEmptyTrimmed(inspection?.localeField),
           let locale = Self.nonEmptyTrimmed(previewContext.fieldMocks[localeField]) {
            return locale
        }

        let htmlContext = selectedHTMLDocumentContext
        if htmlContext.langSource == .binding,
           let locale = Self.nonEmptyTrimmed(previewContext.fieldMocks[htmlContext.langField]) {
            return locale
        }

        if let locale = Self.nonEmptyTrimmed(previewContext.locale) {
            return locale
        }
        return Self.nonEmptyTrimmed(htmlContext.langValue)
    }

    /// 論理名（日本語）: Active Resolved locale一致判定関数
    /// 処理概要: 指定 locale が現在 preview 表示中の locale と一致するかを判定します。
    ///
    /// - Parameter locale: 判定対象 locale。
    /// - Returns: active preview locale と一致する場合は `true`。
    private func isActiveResolvedLocale(_ locale: String) -> Bool {
        activeResolvedTextLocale() == locale
    }

    /// 論理名（日本語）: i18nテキストresource値読込関数
    /// 処理概要: flat locale JSON から指定 key の文字列値だけを読み取ります。
    ///
    /// - Parameters:
    ///   - url: locale JSON URL。
    ///   - key: 読み取る i18n key。
    /// - Returns: resource に保存された文字列値。未作成、非文字列、読込失敗時は `nil`。
    private static func i18nTextResourceValue(at url: URL, key: String) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let resource = object as? [String: Any]
        else {
            return nil
        }
        return resource[key] as? String
    }

    /// 論理名（日本語）: 空でないtrim済み文字列取得関数
    /// 処理概要: 前後空白と改行を除去し、空文字の場合は `nil` にします。
    ///
    /// - Parameter value: 正規化する文字列。
    /// - Returns: 空でない trim 済み文字列。
    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }

    /// 論理名（日本語）: HTMLディスク読み込み関数
    /// 処理概要: 指定 URL の HTML を UTF-8 文字列として読み込みます。
    ///
    /// - Parameter pageURL: 読み込み対象の HTML ファイル URL。
    /// - Returns: 読み込めた HTML。失敗時は `nil`。
    private func readHTMLFromDisk(at pageURL: URL) -> String? {
        try? String(contentsOf: pageURL, encoding: .utf8)
    }

    /// 論理名（日本語）: ディスクHTML置換要求発行関数
    /// 処理概要: 保存済み HTML を読み直し、選択中 WebView へ document replacement として反映します。
    ///
    /// - Parameters:
    ///   - target: 置換対象 HTML。
    ///   - selectedNodeID: 置換後に維持する選択 node ID。
    private func requestDocumentReplacementFromDisk(for target: HTMLSyncTarget, selectedNodeID: String?) {
        guard let html = readHTMLFromDisk(at: target.htmlURL) else { return }
        documentReplacementSequence += 1
        documentReplacementRequest = DocumentReplacementRequest(
            sequence: documentReplacementSequence,
            pageURL: target.htmlURL,
            html: html,
            selectedNodeID: selectedNodeID
        )
    }

    /// 論理名（日本語）: 次Chapter ID生成関数
    /// 処理概要: 既存 Chapter の ID と重複しない `chapter-N` 形式の ID を返します。
    ///
    /// - Parameter project: Chapter を追加する project manifest。
    /// - Returns: 重複しない Chapter ID。
    private func nextChapterID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(project.chapters.map(\.id))
        return Self.nextSequencedID(prefix: "chapter", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 次Chapter内部ID生成関数
    /// 処理概要: 既存 manifest 内部 ID と重複しない `chapter-N` 形式の内部 ID を返します。
    ///
    /// - Parameter project: Chapter を追加する project manifest。
    /// - Returns: 重複しない Chapter 内部 ID。
    private func nextChapterInternalID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(
            project.chapters.map(\.internalID)
                + project.chapters.flatMap { $0.pages.map(\.internalID) }
                + project.collections.map(\.internalID)
                + project.collections.flatMap { $0.components.map(\.internalID) }
        )
        return Self.nextSequencedID(prefix: "chapter", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 書き込み対象Chapter位置取得関数
    /// 処理概要: 選択中 Chapter を優先し、未選択または Chapter がない場合は page 追加先を確保して index を返します。
    ///
    /// - Parameter project: page を追加する project manifest。
    /// - Returns: page 追加先 Chapter の index。
    private func writableChapterIndex(in project: inout OpenGraphiteProject) -> Int {
        if let selectedChapterInternalID,
           let index = project.chapters.firstIndex(where: { $0.internalID == selectedChapterInternalID }) {
            return index
        }
        if project.chapters.isEmpty {
            project.chapters.append(
                OpenGraphiteChapter(
                    id: OpenGraphiteChapter.defaultID,
                    title: OpenGraphiteChapter.defaultTitle,
                    pages: []
                )
            )
        }
        return project.chapters.startIndex
    }

    /// 論理名（日本語）: 既存HTML path検証関数
    /// 処理概要: 選択された file URL が project の `htmlRoot` 配下にある HTML file かを確認し、manifest 用の相対 path を返します。
    ///
    /// - Parameters:
    ///   - htmlURL: ユーザーが選択した HTML file URL。
    ///   - loadedProject: path 解決の基準になる読み込み済み project。
    /// - Returns: 正常時は `htmlRoot` 相対 path、異常時は error メッセージ。
    private static func existingHTMLPath(
        for htmlURL: URL,
        in loadedProject: LoadedOpenGraphiteProject
    ) -> (path: String?, error: String?) {
        guard htmlURL.isFileURL else {
            return (nil, "追加する HTML は local file である必要があります。")
        }

        let htmlURL = htmlURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: htmlURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return (nil, "追加する HTML が見つかりません: \(htmlURL.path)")
        }
        guard htmlURL.pathExtension.lowercased() == "html" else {
            return (nil, "追加するファイルは .html で終わる必要があります。")
        }

        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot, isDirectory: true)
            .standardizedFileURL
        let rootPath = htmlRootURL.path
        let htmlPath = htmlURL.path
        guard htmlPath.hasPrefix(rootPath + "/") else {
            return (nil, "追加する HTML は htmlRoot 配下に配置してください: \(htmlPath)")
        }

        let relativePath = String(htmlPath.dropFirst(rootPath.count + 1))
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasSuffix("/"),
              !components.contains(""),
              !components.contains("."),
              !components.contains(".."),
              URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "html"
        else {
            return (nil, "HTML path は htmlRoot 配下の相対 path である必要があります。")
        }

        return (relativePath, nil)
    }

    /// 論理名（日本語）: 次Page ID生成関数
    /// 処理概要: 既存 page / component の ID と重複しない `page-N` 形式の ID を返します。
    ///
    /// - Parameter project: page を追加する project manifest。
    /// - Returns: 重複しない page ID。
    private func nextPageID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(project.allPages.map(\.id))
        return Self.nextSequencedID(prefix: "page", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 既存HTML用Page ID生成関数
    /// 処理概要: HTML file 名から manifest 用 ID を生成し、既存 page / component ID と重複する場合は連番 suffix を付けます。
    ///
    /// - Parameters:
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - project: ID の重複を確認する project manifest。
    /// - Returns: 既存 HTML 登録に使う page ID。
    private static func existingPageID(forHTMLPath path: String, in project: OpenGraphiteProject) -> String {
        let fileStem = URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
        let preferredID = manifestIDSlug(from: fileStem, fallback: "page")
        let usedIDs = Set(project.allPages.map(\.id))
        guard usedIDs.contains(preferredID) else { return preferredID }
        return nextSequencedID(prefix: preferredID, usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 次Page path生成関数
    /// 処理概要: manifest と実ファイルの双方で重複しない `page-N.html` path を返します。
    ///
    /// - Parameters:
    ///   - loadedProject: path と HTML root を確認する読み込み済み project。
    ///   - idPrefix: path の接頭辞。
    /// - Returns: 新規 page HTML path。
    private func nextPagePath(in loadedProject: LoadedOpenGraphiteProject, idPrefix: String) -> String {
        let usedPaths = Set(loadedProject.project.allPages.map(\.path))
        let htmlRootURL = loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot)
        var index = 1
        while true {
            let candidate = "\(idPrefix)-\(index).html"
            let htmlURL = htmlRootURL.appendingPathComponent(candidate)
            let companionURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
            if !usedPaths.contains(candidate),
               !FileManager.default.fileExists(atPath: htmlURL.path),
               !FileManager.default.fileExists(atPath: companionURL.path) {
                return candidate
            }
            index += 1
        }
    }

    /// 論理名（日本語）: 次Pageキャンバス生成関数
    /// 処理概要: Chapter 末尾 page の右隣、または既存 project page の寸法を使った原点配置を返します。
    ///
    /// - Parameters:
    ///   - chapter: page を追加する Chapter。
    ///   - fallbackProject: Chapter が空の場合に寸法を参照する project manifest。
    /// - Returns: 新規 page の canvas 配置。
    private func nextPageCanvas(in chapter: OpenGraphiteChapter, fallbackProject: OpenGraphiteProject) -> OpenGraphiteCanvas {
        let spacing: Double = 80
        if let lastCanvas = chapter.pages.last?.canvas {
            return OpenGraphiteCanvas(
                name: lastCanvas.name,
                x: lastCanvas.x + lastCanvas.width + spacing,
                y: lastCanvas.y,
                width: lastCanvas.width,
                height: lastCanvas.height,
                previewContext: lastCanvas.previewContext
            )
        }

        if let fallbackCanvas = fallbackProject.allPages.first?.canvas {
            return OpenGraphiteCanvas(
                name: fallbackCanvas.name,
                x: 0,
                y: 0,
                width: fallbackCanvas.width,
                height: fallbackCanvas.height,
                previewContext: fallbackCanvas.previewContext
            )
        }

        return OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
    }

    /// 論理名（日本語）: 再読込Chapter解決関数
    /// 処理概要: `.ogp` 保存後に再読み込みされた project から、追加先だった Chapter を内部 ID または index で復元します。
    ///
    /// - Parameters:
    ///   - project: 再読み込み後の project manifest。
    ///   - chapter: 保存前に追加先だった Chapter。
    ///   - fallbackIndex: 保存前の Chapter index。
    /// - Returns: 再読み込み後の Chapter。見つからない場合は `nil`。
    private static func reloadedChapter(
        in project: OpenGraphiteProject,
        matching chapter: OpenGraphiteChapter,
        fallbackIndex: Int
    ) -> OpenGraphiteChapter? {
        if !chapter.internalID.isEmpty,
           let matchedChapter = project.chapters.first(where: { $0.internalID == chapter.internalID }) {
            return matchedChapter
        }
        if project.chapters.indices.contains(fallbackIndex) {
            return project.chapters[fallbackIndex]
        }
        return project.chapters.first { $0.id == chapter.id }
    }

    /// 論理名（日本語）: 連番ID生成関数
    /// 処理概要: 指定 prefix に数値 suffix を付け、既存 ID と衝突しない最初の値を返します。
    ///
    /// - Parameters:
    ///   - prefix: ID の接頭辞。
    ///   - usedIDs: 既に使われている ID。
    /// - Returns: 未使用の連番 ID。
    private static func nextSequencedID(prefix: String, usedIDs: Set<String>) -> String {
        var index = 1
        while true {
            let candidate = "\(prefix)-\(index)"
            if !usedIDs.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }

    /// 論理名（日本語）: Manifest ID slug生成関数
    /// 処理概要: ファイル名などの任意文字列から page ID として扱いやすい英数字 hyphen 形式の値を生成します。
    ///
    /// - Parameters:
    ///   - value: slug 化する文字列。
    ///   - fallback: slug が空になった場合に使う値。
    /// - Returns: manifest ID として使う slug。
    private static func manifestIDSlug(from value: String, fallback: String) -> String {
        var slug = ""
        var previousWasSeparator = false

        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.append(String(scalar))
                previousWasSeparator = false
            } else if !previousWasSeparator {
                slug.append("-")
                previousWasSeparator = true
            }
        }

        let normalized = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return normalized.isEmpty ? fallback : normalized
    }

    /// 論理名（日本語）: Manifest表示名正規化関数
    /// 処理概要: `.ogp` の title 欄に保存する人間向け表示名として前後空白を除去し、空文字は未指定に戻します。
    ///
    /// - Parameter title: Sidebar から入力された表示名。
    /// - Returns: 保存する title。空の場合は `nil`。
    private static func normalizedManifestTitle(_ title: String) -> String? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedTitle.isEmpty ? nil : normalizedTitle
    }

    /// 論理名（日本語）: HTMLファイル名変更path生成関数
    /// 処理概要: 現在の HTML path のディレクトリを保ったまま、入力値から `.html` ファイル名を生成します。
    ///
    /// - Parameters:
    ///   - currentPath: 変更前の `htmlRoot` 相対 HTML path。
    ///   - value: Sidebar から入力されたファイル名。
    /// - Returns: 更新後 path。入力が無効な場合は error に理由を返します。
    private static func renamedHTMLPath(currentPath: String, value: String) -> (path: String?, error: String?) {
        let rawFileName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawFileName.isEmpty else {
            return (nil, "ファイル名を入力してください。")
        }
        guard rawFileName.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) == nil else {
            return (nil, "ファイル名にはディレクトリ区切りを含められません。")
        }
        guard rawFileName.rangeOfCharacter(from: .newlines) == nil else {
            return (nil, "ファイル名には改行を含められません。")
        }

        var fileName = rawFileName
        if URL(fileURLWithPath: fileName).pathExtension.isEmpty {
            fileName += ".html"
        }
        guard URL(fileURLWithPath: fileName).pathExtension.lowercased() == "html" else {
            return (nil, "HTML ファイル名は .html で終わる必要があります。")
        }

        let fileStem = String(fileName.dropLast(".html".count))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !fileStem.isEmpty, fileName != ".", fileName != ".." else {
            return (nil, "ファイル名が正しくありません。")
        }

        let directory = (currentPath as NSString).deletingLastPathComponent
        let nextPath = directory.isEmpty || directory == "."
            ? fileName
            : "\(directory)/\(fileName)"
        let components = nextPath.split(separator: "/", omittingEmptySubsequences: false)
        guard !nextPath.isEmpty,
              !nextPath.hasPrefix("/"),
              !nextPath.hasSuffix("/"),
              !components.contains(""),
              !components.contains("."),
              !components.contains("..")
        else {
            return (nil, "HTML path は htmlRoot 配下の相対 path である必要があります。")
        }

        return (nextPath, nil)
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

    /// 論理名（日本語）: キャンバス配置名正規化関数
    /// 処理概要: Inspector 入力の前後空白を除去し、空白のみの名前を空文字に変換します。
    ///
    /// - Parameter name: 正規化する配置名。
    /// - Returns: 保存用の配置名。名前なしの場合は空文字。
    private static func normalizedCanvasName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: アイコン値正規化関数
    /// 処理概要: Inspector 入力の前後空白を除去し、空の場合は既定値へ置き換えます。
    ///
    /// - Parameters:
    ///   - value: Inspector 入力値。
    ///   - defaultValue: 空入力時の既定値。
    /// - Returns: 保存用の icon metadata。
    private static func normalizedIconValue(_ value: String, defaultValue: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? defaultValue : normalized
    }

    /// 論理名（日本語）: 優先Collection解決関数
    /// 処理概要: 指定内部 ID の Collection、component を持つ先頭 Collection、先頭 Collection の順に選択対象を解決します。
    ///
    /// - Parameters:
    ///   - project: Collection を保持する project manifest。
    ///   - internalID: 優先して選択する Collection 内部 ID。
    /// - Returns: 選択候補の Collection。Collection が存在しない場合は `nil`。
    private static func preferredCollection(in project: OpenGraphiteProject, internalID: String? = nil) -> OpenGraphiteComponentCollection? {
        if let internalID,
           let collection = project.collections.first(where: { $0.internalID == internalID }) {
            return collection
        }
        return project.collections.first { !$0.components.isEmpty } ?? project.collections.first
    }

    /// 論理名（日本語）: コンポーネントmaster探索関数
    /// 処理概要: project の component canvas HTML を走査し、指定 `data-og-component` の master 情報を返します。
    ///
    /// - Parameters:
    ///   - componentID: 探索する `data-og-component`。
    ///   - loadedProject: 探索対象 project。
    /// - Returns: component master の表示情報。見つからない場合は `nil`。
    private func componentSource(
        componentID: String,
        in loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphiteComponentSource? {
        for collection in loadedProject.project.collections {
            for componentPage in collection.components {
                let pageURL = loadedProject.htmlURL(for: componentPage)
                guard let html = readHTMLFromDisk(at: pageURL) else { continue }
                let masterNode = OpenGraphiteHTMLDocument(html: html).nodes().first { node in
                    node.attributes["data-og-component"] == componentID
                        && node.attributes["data-og-component-kind"] == "master"
                }
                guard let masterNode else { continue }

                return OpenGraphiteComponentSource(
                    componentID: componentID,
                    masterNodeID: masterNode.id,
                    collectionInternalID: collection.internalID,
                    collectionName: collection.displayName,
                    componentPageID: componentPage.id,
                    componentPageInternalID: componentPage.internalID,
                    componentPageName: componentPage.displayName,
                    componentPagePath: componentPage.path,
                    canvas: componentPage.canvas
                )
            }
        }

        return nil
    }

    /// 論理名（日本語）: プロジェクトmanifest保存関数
    /// 処理概要: 更新済み project manifest を `.ogp` ファイルへ atomic write で保存します。
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

    /// 論理名（日本語）: プロジェクトHTML既知状態初期化関数
    /// 処理概要: project 内の全 Chapter の HTML を読み、外部変更検出の比較基準として保存します。
    ///
    /// - Parameter project: 比較基準を初期化する読み込み済み project。
    private func seedKnownHTMLForProject(_ project: LoadedOpenGraphiteProject) {
        for page in project.project.allPages {
            let pageURL = project.htmlURL(for: page)
            if let html = readHTMLFromDisk(at: pageURL) {
                lastKnownPageHTMLByURL[pageURL] = html
            }
        }
    }

    /// 論理名（日本語）: ページ実行時状態移行関数
    /// 処理概要: HTML ファイル名変更に伴い、履歴、既知 HTML、reload token、静的フロー cache を新 URL へ移します。
    ///
    /// - Parameters:
    ///   - currentHTMLURL: 変更前 HTML URL。
    ///   - nextHTMLURL: 変更後 HTML URL。
    private func migratePageRuntimeState(from currentHTMLURL: URL, to nextHTMLURL: URL) {
        let currentURL = currentHTMLURL.standardizedFileURL
        let nextURL = nextHTMLURL.standardizedFileURL

        if let key = matchingURLKey(in: syncHistories, for: currentURL),
           let history = syncHistories.removeValue(forKey: key) {
            syncHistories[nextURL] = history
        }
        if let key = matchingURLKey(in: lastKnownPageHTMLByURL, for: currentURL),
           let html = lastKnownPageHTMLByURL.removeValue(forKey: key) {
            lastKnownPageHTMLByURL[nextURL] = html
        }
        if let key = matchingURLKey(in: staticFlowLinksByPageURL, for: currentURL),
           let links = staticFlowLinksByPageURL.removeValue(forKey: key) {
            staticFlowLinksByPageURL[nextURL] = links
        }
        if let key = matchingURLKey(in: pageReloadTokensByURL, for: currentURL),
           let token = pageReloadTokensByURL.removeValue(forKey: key) {
            pageReloadTokensByURL[nextURL] = token + 1
        } else {
            pageReloadTokensByURL[nextURL, default: 0] += 1
        }
        if let key = matchingURLKey(in: pageChangeMonitorsByURL, for: currentURL) {
            pageChangeMonitorsByURL[key]?.cancel()
            pageChangeMonitorsByURL.removeValue(forKey: key)
        }
    }

    /// 論理名（日本語）: URL辞書key照合関数
    /// 処理概要: URL を key に持つ cache から、標準化後に一致する既存 key を探します。
    ///
    /// - Parameters:
    ///   - dictionary: URL key を持つ辞書。
    ///   - url: 探索する URL。
    /// - Returns: 一致した既存 key。見つからない場合は `nil`。
    private func matchingURLKey<Value>(in dictionary: [URL: Value], for url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        return dictionary.keys.first { key in
            key == url || key.standardizedFileURL == standardizedURL
        }
    }

    /// 論理名（日本語）: ページ再読み込みトークン更新関数
    /// 処理概要: 指定 HTML URL の reload token を進め、対応する非選択 WebView に再読み込みを促します。
    ///
    /// - Parameter pageURL: reload token を進める HTML URL。
    private func incrementReloadToken(for pageURL: URL) {
        var tokens = pageReloadTokensByURL
        tokens[pageURL, default: 0] += 1
        pageReloadTokensByURL = tokens
    }

    /// 論理名（日本語）: 履歴可用性更新関数
    /// 処理概要: 現在ページの undo/redo 可否をメニュー表示用 Published 値へ反映します。
    private func updateHistoryAvailability() {
        guard let selectedPageURL, let history = syncHistories[selectedPageURL] else {
            canUndo = false
            canRedo = false
            return
        }

        canUndo = history.canUndo
        canRedo = history.canRedo
    }

    /// 論理名（日本語）: 履歴移動適用関数
    /// 処理概要: undo/redo スタックから HTML を取り出し、ディスク同期と WebView 置換要求を発行します。
    ///
    /// - Parameter direction: 適用する履歴移動方向。
    private func applyHistoryNavigation(direction: HistoryNavigationDirection) {
        guard let selectedPageURL,
              var history = syncHistories[selectedPageURL]
        else {
            updateHistoryAvailability()
            return
        }

        let html: String?
        switch direction {
        case .undo:
            html = history.undo()
        case .redo:
            html = history.redo()
        }

        guard let html else {
            updateHistoryAvailability()
            return
        }

        do {
            try html.write(to: selectedPageURL, atomically: true, encoding: .utf8)
            lastKnownPageHTMLByURL[selectedPageURL] = html
            syncHistories[selectedPageURL] = history
            documentReplacementSequence += 1
            documentReplacementRequest = DocumentReplacementRequest(
                sequence: documentReplacementSequence,
                pageURL: selectedPageURL,
                html: html,
                selectedNodeID: selectedNodeID
            )
            updateHistoryAvailability()
            statusMessage = historyStatusMessage(for: direction, pageURL: selectedPageURL)
        } catch {
            lastError = "履歴の同期に失敗しました: \(error.localizedDescription)"
            updateHistoryAvailability()
        }
    }

    /// 論理名（日本語）: 外部ページ監視再起動関数
    /// 処理概要: project 内の全 HTML ファイルを監視し、外部変更時にページ単位の同期を試みます。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalPageMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            cancelPageChangeMonitors()
            return
        }

        guard let loadedProject else {
            cancelPageChangeMonitors()
            return
        }

        let pageURLs = Set(loadedProject.project.allPages.map { loadedProject.htmlURL(for: $0) })
        for monitoredURL in Array(pageChangeMonitorsByURL.keys) where !pageURLs.contains(monitoredURL) {
            pageChangeMonitorsByURL[monitoredURL]?.cancel()
            pageChangeMonitorsByURL.removeValue(forKey: monitoredURL)
        }

        for pageURL in pageURLs where force || pageChangeMonitorsByURL[pageURL] == nil {
            pageChangeMonitorsByURL[pageURL]?.cancel()
            let monitor = OpenGraphiteFileChangeMonitor()
            monitor.start(url: pageURL) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { @MainActor [weak self] in
                        self?.refreshPageFromDiskIfChanged(at: pageURL)
                    }
                }
            }
            pageChangeMonitorsByURL[pageURL] = monitor
        }
    }

    /// 論理名（日本語）: 外部依存ファイル監視再起動関数
    /// 処理概要: CSS、component master、runtime script など page 表示に影響するファイルを監視します。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalDependencyMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            cancelDependencyChangeMonitors()
            return
        }

        guard let loadedProject else {
            cancelDependencyChangeMonitors()
            return
        }

        let dependencyURLs = projectDependencyURLs(for: loadedProject)
        for monitoredURL in Array(dependencyChangeMonitorsByURL.keys) where !dependencyURLs.contains(monitoredURL) {
            dependencyChangeMonitorsByURL[monitoredURL]?.cancel()
            dependencyChangeMonitorsByURL.removeValue(forKey: monitoredURL)
        }

        for dependencyURL in dependencyURLs where force || dependencyChangeMonitorsByURL[dependencyURL] == nil {
            dependencyChangeMonitorsByURL[dependencyURL]?.cancel()
            let monitor = OpenGraphiteFileChangeMonitor()
            monitor.start(url: dependencyURL) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { @MainActor [weak self] in
                        self?.refreshProjectDependenciesFromDisk()
                    }
                }
            }
            dependencyChangeMonitorsByURL[dependencyURL] = monitor
        }
    }

    /// 論理名（日本語）: ページ変更監視停止関数
    /// 処理概要: 登録済みの全 HTML ファイル監視を停止します。
    private func cancelPageChangeMonitors() {
        for monitor in pageChangeMonitorsByURL.values {
            monitor.cancel()
        }
        pageChangeMonitorsByURL = [:]
    }

    /// 論理名（日本語）: 依存ファイル監視停止関数
    /// 処理概要: 登録済みの CSS / component / runtime file 監視を停止します。
    private func cancelDependencyChangeMonitors() {
        for monitor in dependencyChangeMonitorsByURL.values {
            monitor.cancel()
        }
        dependencyChangeMonitorsByURL = [:]
    }

    /// 論理名（日本語）: 外部プロジェクト監視再起動関数
    /// 処理概要: 現在開いている `.ogp` ファイルを監視し、外部変更時に project manifest を再読み込みします。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalProjectMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            projectChangeMonitor.cancel()
            monitoredProjectURL = nil
            return
        }

        guard let projectURL = loadedProject?.fileURL else {
            projectChangeMonitor.cancel()
            monitoredProjectURL = nil
            return
        }

        guard force || monitoredProjectURL != projectURL else { return }
        monitoredProjectURL = projectURL
        projectChangeMonitor.start(url: projectURL) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task { @MainActor [weak self] in
                    self?.refreshProjectManifestFromDiskIfChanged()
                }
            }
        }
    }

    /// 論理名（日本語）: project依存URL抽出関数
    /// 処理概要: project の HTML から local stylesheet、component link、runtime script の URL を収集します。
    private func projectDependencyURLs(for loadedProject: LoadedOpenGraphiteProject) -> Set<URL> {
        var urls: Set<URL> = []
        let fileManager = FileManager.default

        let cssURL = loadedProject.cssURL.standardizedFileURL
        if fileManager.fileExists(atPath: cssURL.path) {
            urls.insert(cssURL)
        }

        for component in loadedProject.project.components {
            let componentURL = loadedProject.htmlURL(for: component).standardizedFileURL
            if fileManager.fileExists(atPath: componentURL.path) {
                urls.insert(componentURL)
            }
        }

        for page in loadedProject.project.allPages {
            let pageURL = loadedProject.htmlURL(for: page).standardizedFileURL
            guard let html = readHTMLFromDisk(at: pageURL) else { continue }
            for href in dependencyHrefs(in: html) {
                let dependencyURL = resolveDependencyURL(href, relativeTo: pageURL).standardizedFileURL
                if dependencyURL.isFileURL, fileManager.fileExists(atPath: dependencyURL.path) {
                    urls.insert(dependencyURL)
                }
            }
        }

        let pageURLs = Set(loadedProject.project.chapters.flatMap(\.pages).map { loadedProject.htmlURL(for: $0).standardizedFileURL })
        return urls.subtracting(pageURLs)
    }

    /// 論理名（日本語）: Component依存参照書き換え関数
    /// 処理概要: Component HTML ファイル名変更時に、参照元 HTML の component link と同名 CSS link を新しい相対 path へ更新します。
    ///
    /// - Parameters:
    ///   - loadedProject: 変更前の project。
    ///   - currentHTMLURL: 変更前 component HTML URL。
    ///   - nextHTMLURL: 変更後 component HTML URL。
    ///   - excludingPageInternalID: rename 対象自身の page 内部 ID。
    /// - Returns: 失敗時 rollback に使う変更前 HTML data 一覧。
    private func rewriteComponentDependencyReferences(
        in loadedProject: LoadedOpenGraphiteProject,
        from currentHTMLURL: URL,
        to nextHTMLURL: URL,
        excludingPageInternalID: String
    ) throws -> [HTMLDependencyRewriteBackup] {
        var backups: [HTMLDependencyRewriteBackup] = []
        do {
            for page in loadedProject.project.allPages where page.internalID != excludingPageInternalID {
                let pageURL = loadedProject.htmlURL(for: page).standardizedFileURL
                guard let data = try? Data(contentsOf: pageURL),
                      let html = String(data: data, encoding: .utf8)
                else {
                    continue
                }
                let rewrittenHTML = rewriteComponentDependencyReferences(
                    in: html,
                    pageURL: pageURL,
                    currentHTMLURL: currentHTMLURL,
                    nextHTMLURL: nextHTMLURL
                )
                guard rewrittenHTML != html else { continue }
                backups.append(HTMLDependencyRewriteBackup(url: pageURL, data: data))
                try rewrittenHTML.write(to: pageURL, atomically: true, encoding: .utf8)
                lastKnownPageHTMLByURL[pageURL] = rewrittenHTML
                incrementReloadToken(for: pageURL)
            }
            return backups
        } catch {
            for backup in backups {
                try? backup.data.write(to: backup.url, options: .atomic)
            }
            throw error
        }
    }

    /// 論理名（日本語）: Component依存参照HTML書き換え関数
    /// 処理概要: HTML 文字列内の `opengraphite-components` と同名 stylesheet 参照を、新しい component ファイル名へ差し替えます。
    ///
    /// - Parameters:
    ///   - html: 書き換え対象 HTML。
    ///   - pageURL: HTML の URL。
    ///   - currentHTMLURL: 変更前 component HTML URL。
    ///   - nextHTMLURL: 変更後 component HTML URL。
    /// - Returns: 必要な href を置換した HTML。
    private func rewriteComponentDependencyReferences(
        in html: String,
        pageURL: URL,
        currentHTMLURL: URL,
        nextHTMLURL: URL
    ) -> String {
        let currentComponentURL = currentHTMLURL.standardizedFileURL
        let nextComponentURL = nextHTMLURL.standardizedFileURL
        let currentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: currentHTMLURL).standardizedFileURL
        let nextCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: nextHTMLURL).standardizedFileURL
        var result = html
        for tag in matches(pattern: #"<link\b[^>]*>"#, in: html).reversed() {
            guard let href = attribute("href", in: tag) else { continue }
            let rel = attribute("rel", in: tag)?.lowercased() ?? ""
            let resolvedURL = resolveDependencyURL(href, relativeTo: pageURL).standardizedFileURL
            let replacementHref: String?
            if rel == "opengraphite-components", resolvedURL == currentComponentURL {
                replacementHref = Self.relativePath(from: pageURL.deletingLastPathComponent(), to: nextComponentURL)
            } else if rel == "stylesheet", resolvedURL == currentCSSURL {
                replacementHref = Self.relativePath(from: pageURL.deletingLastPathComponent(), to: nextCSSURL)
            } else {
                replacementHref = nil
            }
            guard let replacementHref,
                  let rewrittenTag = replacingAttribute("href", in: tag, with: replacementHref),
                  let range = result.range(of: tag)
            else {
                continue
            }
            result.replaceSubrange(range, with: rewrittenTag)
        }
        return result
    }

    /// 論理名（日本語）: HTML属性値置換関数
    /// 処理概要: 開始タグ文字列に含まれる指定属性の値だけを置き換え、引用符や他属性を維持します。
    ///
    /// - Parameters:
    ///   - name: 置換する属性名。
    ///   - tag: 対象開始タグ文字列。
    ///   - value: 新しい属性値。
    /// - Returns: 属性値を置換したタグ。属性が見つからない場合は `nil`。
    private func replacingAttribute(_ name: String, in tag: String, with value: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }
        var rewrittenTag = tag
        rewrittenTag.replaceSubrange(range, with: htmlAttributeEscapedValue(value))
        return rewrittenTag
    }

    /// 論理名（日本語）: HTML属性値エスケープ関数
    /// 処理概要: href 属性へ保存する相対 path の最小 HTML entity escape を行います。
    ///
    /// - Parameter value: 属性へ保存する値。
    /// - Returns: HTML 属性値として安全な文字列。
    private func htmlAttributeEscapedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// 論理名（日本語）: HTML依存href抽出関数
    /// 処理概要: stylesheet、component link、script src の local 依存候補を HTML から取り出します。
    private func dependencyHrefs(in html: String) -> [String] {
        var hrefs: [String] = []
        for tag in matches(pattern: #"<link\b[^>]*>"#, in: html) {
            let rel = attribute("rel", in: tag)?.lowercased() ?? ""
            guard rel == "stylesheet" || rel == "opengraphite-components" else { continue }
            if let href = attribute("href", in: tag) {
                hrefs.append(href)
            }
        }
        for tag in matches(pattern: #"<script\b[^>]*>"#, in: html) {
            if let src = attribute("src", in: tag) {
                hrefs.append(src)
            }
        }
        return hrefs
    }

    /// 論理名（日本語）: HTML属性値抽出関数
    /// 処理概要: 開始タグ文字列から指定属性の値を単純抽出します。
    private func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }
        return String(tag[range])
    }

    /// 論理名（日本語）: HTML正規表現一致抽出関数
    /// 処理概要: 指定 pattern に一致する部分文字列を順序通りに返します。
    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let swiftRange = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    /// 論理名（日本語）: 依存URL解決関数
    /// 処理概要: HTML 内の相対 URL を HTML ファイル位置から file URL へ解決します。
    private func resolveDependencyURL(_ href: String, relativeTo pageURL: URL) -> URL {
        let hrefWithoutFragment = href
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? href
        let hrefWithoutQuery = hrefWithoutFragment
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? hrefWithoutFragment

        if hrefWithoutQuery.hasPrefix("/") {
            return URL(fileURLWithPath: hrefWithoutQuery)
        }
        if hrefWithoutQuery.contains("://") {
            return URL(string: hrefWithoutQuery) ?? pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutQuery)
        }
        return pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutQuery)
    }

    /// 論理名（日本語）: 履歴ステータスメッセージ生成関数
    /// 処理概要: undo/redo 適用後に表示する短い同期結果メッセージを生成します。
    ///
    /// - Parameters:
    ///   - direction: 適用した履歴移動方向。
    ///   - pageURL: 対象ページ URL。
    /// - Returns: 画面表示用のステータスメッセージ。
    private func historyStatusMessage(for direction: HistoryNavigationDirection, pageURL: URL) -> String {
        switch direction {
        case .undo:
            return "\(pageURL.lastPathComponent) の変更を取り消して同期しました。"
        case .redo:
            return "\(pageURL.lastPathComponent) の変更をやり直して同期しました。"
        }
    }

    private static let animationContextPropertyOrder = [
        "animation-name",
        "animation-duration",
        "animation-delay",
        "animation-timing-function",
        "animation-iteration-count",
        "animation-fill-mode",
        "animation-direction",
        "animation-play-state",
        "animation",
        "animation-timeline",
        "animation-range-start",
        "animation-range-end",
        "animation-range",
        "timeline-scope",
        "scroll-timeline-name",
        "scroll-timeline-axis",
        "scroll-timeline",
        "view-timeline-name",
        "view-timeline-axis",
        "view-timeline-inset",
        "view-timeline"
    ]

    private static let timelineProviderPropertyKeys = [
        "timeline-scope",
        "scroll-timeline-name",
        "scroll-timeline",
        "view-timeline-name",
        "view-timeline"
    ]

    /// 論理名（日本語）: 祖先ノード一覧生成関数
    /// 処理概要: WebView 由来の DOM 順 `nodes` と `depth` から、選択ノードの祖先を近い順に復元します。
    ///
    /// - Parameters:
    ///   - nodes: DOM 順に並んだ編集ノード一覧。
    ///   - selectedIndex: 選択ノードの index。
    /// - Returns: 選択ノードの祖先一覧。親から root に向かう順序です。
    private static func ancestorNodes(in nodes: [OpenGraphiteNode], selectedIndex: Int) -> [OpenGraphiteNode] {
        guard nodes.indices.contains(selectedIndex) else { return [] }
        var requiredDepth = nodes[selectedIndex].depth - 1
        guard requiredDepth >= 0 else { return [] }

        var ancestors: [OpenGraphiteNode] = []
        for index in stride(from: selectedIndex - 1, through: 0, by: -1) {
            let candidate = nodes[index]
            if candidate.depth == requiredDepth {
                ancestors.append(candidate)
                requiredDepth -= 1

                if requiredDepth < 0 {
                    break
                }
            }
        }
        return ancestors
    }

    /// 論理名（日本語）: アニメーション文脈生成関数
    /// 処理概要: 対象ノードが持つ animation / timeline declaration を Inspector 表示用 context へ変換します。
    ///
    /// - Parameters:
    ///   - node: 表示元になる祖先ノード。
    ///   - matchedTimelineNames: 選択ノードの `animation-timeline` と一致した named timeline。
    /// - Returns: 表示する CSS declaration がある場合は context。空の場合は `nil`。
    private static func animationContext(
        for node: OpenGraphiteNode,
        matchedTimelineNames: [String] = []
    ) -> OpenGraphiteAppliedAnimationContext? {
        let declarations = animationContextPropertyOrder.compactMap { key -> OpenGraphiteAppliedAnimationDeclaration? in
            guard let value = node.cssVariables[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                return nil
            }
            return OpenGraphiteAppliedAnimationDeclaration(key: key, value: value)
        }
        guard !declarations.isEmpty else { return nil }
        return OpenGraphiteAppliedAnimationContext(
            nodeID: node.id,
            nodeInternalID: node.internalID,
            displayID: node.displayID,
            tagName: node.tagName,
            declarations: declarations,
            matchedTimelineNames: matchedTimelineNames
        )
    }

    /// 論理名（日本語）: Timeline提供名抽出関数
    /// 処理概要: named scroll / view timeline を提供する CSS declaration から dashed ident を抽出します。
    ///
    /// - Parameter cssVariables: ノードが持つ CSS declaration。
    /// - Returns: `--name` 形式の timeline 名一覧。
    private static func timelineProviderNames(in cssVariables: [String: String]) -> Set<String> {
        timelineProviderPropertyKeys.reduce(into: Set<String>()) { names, key in
            names.formUnion(dashedIdentifiers(in: cssVariables[key] ?? ""))
        }
    }

    /// 論理名（日本語）: 選択オーバーレイnode frame変換関数
    /// 処理概要: JavaScript bridge payload の単一 node rect を Swift の選択枠用 tuple へ変換します。
    ///
    /// - Parameter payload: `id`、`x`、`y`、`width`、`height` を含む辞書。
    /// - Returns: node ID と有効な矩形。変換できない場合は `nil`。
    private static func selectionOverlayNodeFrame(from payload: [String: Any]) -> (id: String, rect: CGRect)? {
        let id = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              let x = cgFloatValue(payload["x"]),
              let y = cgFloatValue(payload["y"]),
              let width = cgFloatValue(payload["width"]),
              let height = cgFloatValue(payload["height"]),
              width > 0,
              height > 0
        else {
            return nil
        }
        return (id, CGRect(x: x, y: y, width: width, height: height))
    }

    /// 論理名（日本語）: 矩形Union生成関数
    /// 処理概要: 複数の実測矩形をすべて覆う単一矩形へまとめます。
    ///
    /// - Parameter rects: 対象矩形一覧。
    /// - Returns: すべての矩形を覆う union 矩形。空の場合は `nil`。
    private static func unionRect(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { partialResult, rect in
            partialResult.union(rect)
        }
    }

    /// 論理名（日本語）: 任意文字列正規化関数
    /// 処理概要: 前後空白を除去し、空文字を `nil` に変換します。
    ///
    /// - Parameter value: 正規化する任意文字列。
    /// - Returns: 空でない正規化済み文字列。
    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    /// 論理名（日本語）: CGFloat payload変換関数
    /// 処理概要: JavaScript bridge 由来の数値を Canvas preview に使う有限な `CGFloat` へ変換します。
    ///
    /// - Parameter value: JavaScript payload の数値候補。
    /// - Returns: 有限な数値。変換できない場合は `nil`。
    private static func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let value = value as? Double, value.isFinite {
            return CGFloat(value)
        }
        if let value = value as? NSNumber {
            let doubleValue = value.doubleValue
            return doubleValue.isFinite ? CGFloat(doubleValue) : nil
        }
        return nil
    }

    /// 論理名（日本語）: CSS dashed ident抽出関数
    /// 処理概要: CSS 値から `--timeline-name` のような dashed ident を抽出します。
    ///
    /// - Parameter value: CSS property の文字列表現。
    /// - Returns: 見つかった dashed ident の集合。
    private static func dashedIdentifiers(in value: String) -> Set<String> {
        var identifiers = Set<String>()
        var index = value.startIndex

        while index < value.endIndex {
            let nextIndex = value.index(after: index)
            guard value[index] == "-", nextIndex < value.endIndex, value[nextIndex] == "-" else {
                index = nextIndex
                continue
            }

            var endIndex = value.index(after: nextIndex)
            while endIndex < value.endIndex, isCSSIdentifierCharacter(value[endIndex]) {
                endIndex = value.index(after: endIndex)
            }

            let identifier = String(value[index..<endIndex])
            if identifier.count > 2 {
                identifiers.insert(identifier)
            }
            index = endIndex
        }

        return identifiers
    }

    /// 論理名（日本語）: CSS識別子文字判定関数
    /// 処理概要: timeline 名の簡易抽出で、英数字、hyphen、underscore を識別子の構成文字として扱います。
    ///
    /// - Parameter character: 判定する 1 文字。
    /// - Returns: CSS dashed ident の一部として扱う場合は `true`。
    private static func isCSSIdentifierCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first
        else {
            return false
        }
        return CharacterSet.alphanumerics.contains(scalar)
            || character == "-"
            || character == "_"
    }

    /// 論理名（日本語）: ノード辞書変換関数
    /// 処理概要: JavaScript 由来の辞書から必須項目を検証し、`OpenGraphiteNode` を生成します。
    ///
    /// - Parameter dictionary: DOM ノードから収集した辞書。
    /// - Returns: 必須値がそろっている場合はノード、欠けている場合は `nil`。
    private static func node(from dictionary: [String: Any], sourceNode: OpenGraphiteAgentNode? = nil) -> OpenGraphiteNode? {
        guard
            let id = dictionary["id"] as? String,
            !id.isEmpty,
            let tagName = dictionary["tagName"] as? String,
            let type = dictionary["type"] as? String
        else {
            return nil
        }

        var cssVariables = sourceNode?.cssVariables ?? [:]
        for (key, value) in dictionary["cssVariables"] as? [String: String] ?? [:] {
            cssVariables[key] = value
        }
        var node = OpenGraphiteNode(
            id: id,
            internalID: dictionary["internalID"] as? String ?? "",
            tagName: tagName,
            type: type,
            layout: dictionary["layout"] as? String,
            role: dictionary["role"] as? String,
            componentID: dictionary["componentID"] as? String,
            componentKind: dictionary["componentKind"] as? String,
            sourceComponentID: dictionary["sourceComponentID"] as? String,
            sourceInstanceID: dictionary["sourceInstanceID"] as? String,
            sourceNodeInternalID: dictionary["sourceNodeInternalID"] as? String,
            sourceNodeID: dictionary["sourceNodeID"] as? String,
            sourcePlacementID: dictionary["sourcePlacementID"] as? String,
            isPlacementGenerated: dictionary["placementGenerated"] as? Bool ?? false,
            textContent: dictionary["textContent"] as? String,
            fallbackTextContent: sourceNode?.textContent ?? dictionary["fallbackTextContent"] as? String,
            textSource: sourceNode?.attributes["data-og-text-source"] ?? dictionary["textSource"] as? String,
            i18nKey: sourceNode?.attributes["data-i18n-key"] ?? dictionary["i18nKey"] as? String,
            iconLibrary: sourceNode?.attributes["data-og-icon-library"] ?? dictionary["iconLibrary"] as? String,
            iconName: sourceNode?.attributes["data-og-icon-name"] ?? dictionary["iconName"] as? String,
            iconSource: sourceNode?.attributes["data-og-icon-source"] ?? dictionary["iconSource"] as? String,
            cssVariables: cssVariables,
            isHidden: dictionary["hidden"] as? Bool ?? false,
            isLocked: dictionary["locked"] as? Bool ?? false,
            depth: dictionary["depth"] as? Int ?? 0
        )
        if let resolvedFontFamily = dictionary["resolvedFontFamily"] as? String {
            let normalizedFontFamily = resolvedFontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedFontFamily.isEmpty {
                node.resolvedFontFamily = normalizedFontFamily
            }
        }
        return node
    }

    /// 論理名（日本語）: ノード表示ID正規化関数
    /// 処理概要: Layers の入力値を `data-og-id` として扱いやすい小文字英数字、ハイフン、アンダースコアの ID へ変換します。
    ///
    /// - Parameter value: 正規化する入力値。
    /// - Returns: 空になった場合は `node` を返します。
    private static func normalizedNodeDisplayID(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_-")
        var result = ""
        for character in value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            result.append(allowed.contains(character) ? character : "-")
        }
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result
            .replacingOccurrences(of: "_-", with: "_")
            .replacingOccurrences(of: "-_", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "node" : result
    }

    /// 論理名（日本語）: ページルートノード抽出関数
    /// 処理概要: HTML 正本から page root として扱う `data-og-type="page"` の node を取得します。
    ///
    /// - Parameters:
    ///   - html: 対象 HTML 文字列。
    ///   - companionCSS: HTML と同名の design value 正本 CSS。
    /// - Returns: ページ root node。見つからない場合は `nil`。
    private static func pageRootNode(
        in html: String,
        companionCSS: OpenGraphiteCompanionCSSDocument? = nil,
        contract: OpenGraphiteContract = .builtIn
    ) -> OpenGraphiteAgentNode? {
        OpenGraphiteHTMLDocument(html: html)
            .nodes(companionCSS: companionCSS, contract: contract)
            .first { node in
                node.type == "page"
            }
    }

    /// 論理名（日本語）: 現在HTML正本ノード索引生成関数
    /// 処理概要: Inspector の fallback text と CSS 表示に使うため、表示中 HTML と component source HTML の正本 node を `data-og-internal-id` で引ける辞書へ変換します。
    ///
    /// - Returns: 現在の HTML と component source HTML に含まれるノードの内部 ID 索引。
    private func sourceNodesByInternalIDForCurrentTarget() -> [String: OpenGraphiteAgentNode] {
        guard let target = currentHTMLSyncTarget(),
              let html = readHTMLFromDisk(at: target.htmlURL)
        else {
            return [:]
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: target.htmlURL)
        var sourceNodes = componentSourceNodesByInternalID(contract: contract)
        OpenGraphiteHTMLDocument(html: html)
            .nodes(companionCSS: companionCSS, contract: contract)
            .forEach { node in
                guard !node.internalID.isEmpty else { return }
                sourceNodes[node.internalID] = node
            }
        return sourceNodes
    }

    /// 論理名（日本語）: Component sourceノード索引生成関数
    /// 処理概要: project に登録された component canvas HTML と companion CSS を読み、runtime 展開後 node の Inspector 表示に使う正本 node 索引を作ります。
    ///
    /// - Parameter contract: CSS declaration の編集契約。
    /// - Returns: component source に含まれる node の内部 ID 索引。
    private func componentSourceNodesByInternalID(contract: OpenGraphiteContract) -> [String: OpenGraphiteAgentNode] {
        guard let loadedProject else { return [:] }
        var sourceNodes: [String: OpenGraphiteAgentNode] = [:]
        for collection in loadedProject.project.collections {
            for componentPage in collection.components {
                let componentURL = loadedProject.htmlURL(for: componentPage)
                guard let html = readHTMLFromDisk(at: componentURL) else { continue }
                let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: componentURL)
                OpenGraphiteHTMLDocument(html: html)
                    .nodes(companionCSS: companionCSS, contract: contract)
                    .forEach { node in
                        guard !node.internalID.isEmpty else { return }
                        sourceNodes[node.internalID] = node
                    }
            }
        }
        return sourceNodes
    }
}
