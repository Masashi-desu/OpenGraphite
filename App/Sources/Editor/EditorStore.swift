import Foundation

/// 論理名（日本語）: エディター状態ストア
/// 概要: 読み込み済みプロジェクト、Pages/Components 選択、DOM ノード一覧、Inspector 変更要求を保持するメイン状態管理クラスです。
///
/// プロパティ:
/// - `loadedProject`: 現在開いている `.ogp`。
/// - `selectedCanvasSegment`: 中央キャンバスに表示する Pages / Components セグメント。
/// - `selectedChapterID`: 選択中 Chapter の ID。
/// - `selectedPageID`: 選択中ページの ID。
/// - `selectedComponentPageID`: 選択中 component canvas の ID。
/// - `nodes`: WebView から抽出された編集ノード一覧。
/// - `selectedNodeID`: 選択中ノードの `data-og-id`。
/// - `zoom`: キャンバス表示倍率。
/// - `activeTool`: キャンバス上の選択ツール。
/// - `previewDisplayMode`: 中央プレビューの通常/フロー表示モード。
/// - `cssMutation`: WebView へ反映待ちの CSS 変数変更。
/// - `attributeMutation`: WebView へ反映待ちの属性変更。
/// - `documentReplacementRequest`: undo/redo で WebView へ適用する HTML 置換要求。
@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var loadedProject: LoadedOpenGraphiteProject?
    @Published var selectedCanvasSegment: OpenGraphiteCanvasSegment = .pages
    @Published var selectedChapterID: String?
    @Published var selectedPageID: String?
    @Published var selectedComponentPageID: String?
    @Published private(set) var nodes: [OpenGraphiteNode] = []
    @Published var selectedNodeID: String?
    @Published var zoom: Double = 0.72
    @Published var statusMessage = "HTMLを正本として開きます。"
    @Published var lastError: String?
    @Published var activeTool: CanvasTool = .select
    @Published var previewDisplayMode: OpenGraphitePreviewDisplayMode = .normal
    @Published private(set) var cssMutation: CSSVariableMutation?
    @Published private(set) var attributeMutation: NodeAttributeMutation?
    @Published private(set) var documentReplacementRequest: DocumentReplacementRequest?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var pageReloadTokensByURL: [URL: Int] = [:]
    @Published private(set) var staticFlowLinksByPageURL: [URL: [OpenGraphiteStaticFlowLink]] = [:]

    private let loader: ProjectLoader
    private let sampleProjectLocator: SampleProjectLocator
    private let currentProjectStore: OpenGraphiteCurrentProjectStore?
    private var mutationSequence = 0
    private var attributeMutationSequence = 0
    private var documentReplacementSequence = 0
    private var syncHistories: [URL: DocumentSyncHistory] = [:]
    private var lastKnownPageHTMLByURL: [URL: String] = [:]
    private var pageChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private var dependencyChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private let projectChangeMonitor = OpenGraphiteFileChangeMonitor()
    private var monitoredProjectURL: URL?
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 論理名（日本語）: エディターストア初期化関数
    /// 処理概要: project loader と sample project locator を保持し、通常利用時は既定実装を使います。
    ///
    /// - Parameters:
    ///   - loader: `.ogp` 読み込みに使う loader。
    ///   - sampleProjectLocator: Open Sample Project の解決に使う locator。
    init(
        loader: ProjectLoader = ProjectLoader(),
        sampleProjectLocator: SampleProjectLocator = SampleProjectLocator(),
        currentProjectStore: OpenGraphiteCurrentProjectStore? = nil
    ) {
        self.loader = loader
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
        return loadedProject.project.chapters.first { $0.id == selectedChapterID }
            ?? loadedProject.project.chapters.first
    }

    var selectedChapterPages: [OpenGraphitePage] {
        selectedChapter?.pages ?? []
    }

    var componentPages: [OpenGraphitePage] {
        loadedProject?.project.components ?? []
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
            return "Components"
        }
    }

    var selectedPage: OpenGraphitePage? {
        switch selectedCanvasSegment {
        case .pages:
            guard let selectedPageID else { return nil }
            return selectedChapterPages.first { $0.id == selectedPageID }
        case .components:
            guard let selectedComponentPageID else { return nil }
            return componentPages.first { $0.id == selectedComponentPageID }
        }
    }

    var selectedPageURL: URL? {
        guard let loadedProject, let selectedPage else { return nil }
        return loadedProject.htmlURL(for: selectedPage)
    }

    var projectRootURL: URL? {
        loadedProject?.rootURL
    }

    var selectedNode: OpenGraphiteNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    /// 論理名（日本語）: ページ再読み込みトークン取得関数
    /// 処理概要: 指定 HTML URL の外部変更を WebView へ通知するための単調増加トークンを返します。
    ///
    /// - Parameter pageURL: reload token を取得する HTML URL。
    /// - Returns: WebView が比較する reload token。
    func reloadToken(for pageURL: URL) -> Int {
        pageReloadTokensByURL[pageURL] ?? 0
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
    /// 処理概要: 指定された `.ogp` を読み込み、ページ選択とノード状態を初期化します。
    ///
    /// - Parameter url: 読み込む `.ogp` の URL。
    func openProject(at url: URL) {
        do {
            let project = try loader.loadProject(at: url)
            loadedProject = project
            selectedCanvasSegment = project.project.chapters.flatMap(\.pages).isEmpty && !project.project.components.isEmpty ? .components : .pages
            selectedChapterID = project.project.chapters.first?.id
            selectedPageID = project.project.chapters.first?.pages.first?.id
            selectedComponentPageID = project.project.components.first?.id
            selectedNodeID = nil
            nodes = []
            cssMutation = nil
            attributeMutation = nil
            documentReplacementRequest = nil
            syncHistories = [:]
            lastKnownPageHTMLByURL = [:]
            pageReloadTokensByURL = [:]
            staticFlowLinksByPageURL = [:]
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

    /// 論理名（日本語）: ページ選択関数
    /// 処理概要: 選択ページを切り替え、ページ変更時にノード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: 選択するページ ID。`nil` の場合はページ選択を解除します。
    func selectPage(id: String?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        switch selectedCanvasSegment {
        case .pages:
            selectedPageID = id
        case .components:
            selectedComponentPageID = id
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        } else {
            statusMessage = "ページ選択を解除しました。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Chapter選択関数
    /// 処理概要: 選択 Chapter を切り替え、ページ選択と DOM ノード一覧を Chapter 内の先頭ページへリセットします。
    ///
    /// - Parameter id: 選択する Chapter ID。`nil` の場合は先頭 Chapter が表示対象になります。
    func selectChapter(id: String?) {
        guard let loadedProject else { return }
        let chapter = loadedProject.project.chapters.first { $0.id == id }
            ?? loadedProject.project.chapters.first
        selectedCanvasSegment = .pages
        selectedChapterID = chapter?.id
        selectedPageID = chapter?.pages.first?.id
        selectedNodeID = nil
        nodes = []

        if let chapter {
            statusMessage = "\(chapter.displayName) を表示しています。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Pagesセグメント選択関数
    /// 処理概要: 通常 Pages canvas を表示し、必要に応じて選択 Chapter 内の先頭ページを選択します。
    func selectPagesSegment() {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedCanvasSegment = .pages
        if selectedPageID == nil || !selectedChapterPages.contains(where: { $0.id == selectedPageID }) {
            selectedPageID = selectedChapterPages.first?.id
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
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
        selectedCanvasSegment = .components
        if selectedComponentPageID == nil || !componentPages.contains(where: { $0.id == selectedComponentPageID }) {
            selectedComponentPageID = componentPages.first?.id
        }
        selectedNodeID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        statusMessage = "Components を表示しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Componentページ選択関数
    /// 処理概要: Components セグメント内の HTML canvas を選択します。
    ///
    /// - Parameter id: 選択する component page ID。
    func selectComponentPage(id: String?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        selectedCanvasSegment = .components
        selectedComponentPageID = id
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
    /// - Parameter id: 選択するノード ID。選択解除時は `nil`。
    func selectNode(id: String?) {
        selectedNodeID = id
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
            name: selectedPage?.canvas.name ?? ""
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 選択中ページのキャンバス配置名、座標、解像度を `.ogp` へ保存し、表示中 project state へ反映します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    func updateSelectedPageCanvas(x: Double, y: Double, width: Double, height: Double, name: String) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite, width > 0, height > 0 else {
            lastError = "キャンバス配置の入力が不正です。"
            return
        }
        guard var loadedProject else { return }

        let normalizedName = Self.normalizedCanvasName(name)
        let nextCanvas = OpenGraphiteCanvas(name: normalizedName, x: x, y: y, width: width, height: height)
        let updatedPage: OpenGraphitePage
        switch selectedCanvasSegment {
        case .pages:
            guard let selectedPageID else { return }
            var chapterIndex: Array<OpenGraphiteChapter>.Index?
            if let selectedChapterID,
               let selectedChapterIndex = loadedProject.project.chapters.firstIndex(where: { $0.id == selectedChapterID }),
               loadedProject.project.chapters[selectedChapterIndex].pages.contains(where: { $0.id == selectedPageID }) {
                chapterIndex = selectedChapterIndex
            }
            if chapterIndex == nil {
                chapterIndex = loadedProject.project.chapters.firstIndex { chapter in
                    chapter.pages.contains { $0.id == selectedPageID }
                }
            }
            guard let chapterIndex,
                  let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: { $0.id == selectedPageID })
            else {
                return
            }
            guard loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
        case .components:
            guard let selectedComponentPageID,
                  let pageIndex = loadedProject.project.components.firstIndex(where: { $0.id == selectedComponentPageID })
            else {
                return
            }
            guard loadedProject.project.components[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.components[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.components[pageIndex]
        }

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = "\(updatedPage.path) のキャンバス配置を更新しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: 静的フローリンクpayload取り込み関数
    /// 処理概要: WebView から届いた静的リンク一覧を page URL ごとに保持し、フロー表示オーバーレイの入力へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から受け取ったリンク辞書配列。
    ///   - pageURL: payload を収集した HTML page URL。
    func ingestStaticFlowLinkPayload(_ payload: [[String: Any]], pageURL: URL) {
        let links = payload.compactMap(OpenGraphiteStaticFlowLink.init(payload:))
        staticFlowLinksByPageURL[pageURL.standardizedFileURL] = links
    }

    /// 論理名（日本語）: ノードpayload取り込み関数
    /// 処理概要: WebView の JavaScript から受け取った辞書配列を `OpenGraphiteNode` 配列へ変換します。
    ///
    /// - Parameter payload: DOM から収集されたノード辞書の配列。
    func ingestNodePayload(_ payload: [[String: Any]]) {
        nodes = payload.compactMap(Self.node(from:))

        if let selectedNodeID, !nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = nil
        }
    }

    /// 論理名（日本語）: CSS変数更新関数
    /// 処理概要: 選択中ノードの CSS 変数を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - key: 更新する `--og-*` 変数名。
    ///   - value: Inspector から入力された値。前後空白は除去します。
    func updateCSSVariable(key: String, value: String) {
        guard let selectedNodeID else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let currentValue = nodes[index].cssVariables[key] ?? ""
            guard currentValue != normalizedValue else { return }

            if normalizedValue.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: key)
            } else {
                nodes[index].cssVariables[key] = normalizedValue
            }
        }

        mutationSequence += 1
        cssMutation = CSSVariableMutation(
            sequence: mutationSequence,
            nodeID: selectedNodeID,
            key: key,
            value: normalizedValue
        )
        statusMessage = "\(selectedNodeID) の \(key) を更新しました。"
    }

    /// 論理名（日本語）: ノード属性更新関数
    /// 処理概要: 選択中ノードの編集対象属性を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: Inspector から入力された値。空の場合は属性削除として扱います。
    func updateNodeAttribute(name: String, value: String) {
        guard let selectedNodeID else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let currentValue: String
            switch name {
            case "data-og-layout":
                currentValue = nodes[index].layout ?? ""
            case "data-og-role":
                currentValue = nodes[index].role ?? ""
            default:
                currentValue = ""
            }
            guard currentValue != normalizedValue else { return }

            switch name {
            case "data-og-layout":
                nodes[index].layout = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-role":
                nodes[index].role = normalizedValue.isEmpty ? nil : normalizedValue
            default:
                break
            }
        }

        attributeMutationSequence += 1
        attributeMutation = NodeAttributeMutation(
            sequence: attributeMutationSequence,
            nodeID: selectedNodeID,
            name: name,
            value: normalizedValue
        )
        statusMessage = "\(selectedNodeID) の \(name) を更新しました。"
    }

    /// 論理名（日本語）: CSS変数mutation適用完了関数
    /// 処理概要: WebView への反映が完了した CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markMutationApplied(sequence: Int) {
        guard cssMutation?.sequence == sequence else { return }
        cssMutation = nil
    }

    /// 論理名（日本語）: 属性mutation適用完了関数
    /// 処理概要: WebView への反映が完了した属性 mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markAttributeMutationApplied(sequence: Int) {
        guard attributeMutation?.sequence == sequence else { return }
        attributeMutation = nil
    }

    /// 論理名（日本語）: 現在HTML同期関数
    /// 処理概要: WebView からシリアライズされた HTML を現在選択中ページのファイルへ同期し、同期単位で履歴へ記録します。
    ///
    /// - Parameter html: 同期する HTML 文字列。
    func syncCurrentHTML(_ html: String) {
        guard let selectedPageURL else { return }
        var history = historyForPage(at: selectedPageURL, fallbackHTML: html)

        do {
            try html.write(to: selectedPageURL, atomically: true, encoding: .utf8)
            lastKnownPageHTMLByURL[selectedPageURL] = html
            history.recordSync(html: html)
            syncHistories[selectedPageURL] = history
            updateHistoryAvailability()
            statusMessage = "\(selectedPageURL.lastPathComponent) と同期しました。"
        } catch {
            lastError = "HTMLの同期に失敗しました: \(error.localizedDescription)"
        }
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
              attributeMutation == nil,
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

            let previousSelectedPageID = selectedPageID
            let previousSelectedComponentPageID = selectedComponentPageID
            let previousSelectedChapterID = selectedChapterID
            let previousSelectedCanvasSegment = selectedCanvasSegment
            let previousSelectedPageURL = selectedPageURL
            loadedProject = reloadedProject
            seedKnownHTMLForProject(reloadedProject)

            if let previousSelectedChapterID,
               reloadedProject.project.chapters.contains(where: { $0.id == previousSelectedChapterID }) {
                selectedChapterID = previousSelectedChapterID
            } else {
                selectedChapterID = reloadedProject.project.chapters.first?.id
            }

            let currentChapterPages = selectedChapter?.pages ?? []
            if let previousSelectedPageID,
               currentChapterPages.contains(where: { $0.id == previousSelectedPageID }) {
                selectedPageID = previousSelectedPageID
            } else if previousSelectedPageID != nil {
                selectedPageID = currentChapterPages.first?.id
            } else {
                selectedPageID = nil
            }

            if let previousSelectedComponentPageID,
               reloadedProject.project.components.contains(where: { $0.id == previousSelectedComponentPageID }) {
                selectedComponentPageID = previousSelectedComponentPageID
            } else {
                selectedComponentPageID = reloadedProject.project.components.first?.id
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

    /// 論理名（日本語）: HTMLディスク読み込み関数
    /// 処理概要: 指定 URL の HTML を UTF-8 文字列として読み込みます。
    ///
    /// - Parameter pageURL: 読み込み対象の HTML ファイル URL。
    /// - Returns: 読み込めた HTML。失敗時は `nil`。
    private func readHTMLFromDisk(at pageURL: URL) -> String? {
        try? String(contentsOf: pageURL, encoding: .utf8)
    }

    /// 論理名（日本語）: キャンバス配置名正規化関数
    /// 処理概要: Inspector 入力の前後空白を除去し、空白のみの名前を空文字に変換します。
    ///
    /// - Parameter name: 正規化する配置名。
    /// - Returns: 保存用の配置名。名前なしの場合は空文字。
    private static func normalizedCanvasName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let data = try encoder.encode(project)
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

    /// 論理名（日本語）: ノード辞書変換関数
    /// 処理概要: JavaScript 由来の辞書から必須項目を検証し、`OpenGraphiteNode` を生成します。
    ///
    /// - Parameter dictionary: DOM ノードから収集した辞書。
    /// - Returns: 必須値がそろっている場合はノード、欠けている場合は `nil`。
    private static func node(from dictionary: [String: Any]) -> OpenGraphiteNode? {
        guard
            let id = dictionary["id"] as? String,
            !id.isEmpty,
            let tagName = dictionary["tagName"] as? String,
            let type = dictionary["type"] as? String
        else {
            return nil
        }

        let cssVariables = dictionary["cssVariables"] as? [String: String] ?? [:]
        return OpenGraphiteNode(
            id: id,
            tagName: tagName,
            type: type,
            layout: dictionary["layout"] as? String,
            role: dictionary["role"] as? String,
            cssVariables: cssVariables,
            isHidden: dictionary["hidden"] as? Bool ?? false,
            isLocked: dictionary["locked"] as? Bool ?? false,
            depth: dictionary["depth"] as? Int ?? 0
        )
    }
}
