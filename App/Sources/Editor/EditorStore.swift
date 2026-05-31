import Foundation

/// 論理名（日本語）: エディター状態ストア
/// 概要: 読み込み済みプロジェクト、ページ選択、DOM ノード一覧、Inspector 変更要求を保持するメイン状態管理クラスです。
///
/// プロパティ:
/// - `loadedProject`: 現在開いている `.ogp`。
/// - `selectedPageID`: 選択中ページの ID。
/// - `nodes`: WebView から抽出された編集ノード一覧。
/// - `selectedNodeID`: 選択中ノードの `data-og-id`。
/// - `zoom`: キャンバス表示倍率。
/// - `activeTool`: キャンバス上の選択ツール。
/// - `cssMutation`: WebView へ反映待ちの CSS 変数変更。
/// - `attributeMutation`: WebView へ反映待ちの属性変更。
/// - `documentReplacementRequest`: undo/redo で WebView へ適用する HTML 置換要求。
@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var loadedProject: LoadedOpenGraphiteProject?
    @Published var selectedPageID: String?
    @Published private(set) var nodes: [OpenGraphiteNode] = []
    @Published var selectedNodeID: String?
    @Published var zoom: Double = 0.72
    @Published var statusMessage = "HTMLを正本として開きます。"
    @Published var lastError: String?
    @Published var activeTool: CanvasTool = .select
    @Published private(set) var cssMutation: CSSVariableMutation?
    @Published private(set) var attributeMutation: NodeAttributeMutation?
    @Published private(set) var documentReplacementRequest: DocumentReplacementRequest?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var pageReloadTokensByURL: [URL: Int] = [:]

    private let loader: ProjectLoader
    private let sampleProjectLocator: SampleProjectLocator
    private let currentProjectStore: OpenGraphiteCurrentProjectStore?
    private var mutationSequence = 0
    private var attributeMutationSequence = 0
    private var documentReplacementSequence = 0
    private var syncHistories: [URL: DocumentSyncHistory] = [:]
    private var lastKnownPageHTMLByURL: [URL: String] = [:]
    private var pageChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
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
        projectChangeMonitor.cancel()
    }

    var selectedPage: OpenGraphitePage? {
        guard let loadedProject else { return nil }
        return loadedProject.project.pages.first { $0.id == selectedPageID }
            ?? loadedProject.project.pages.first
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
            selectedPageID = project.project.pages.first?.id
            selectedNodeID = nil
            nodes = []
            cssMutation = nil
            attributeMutation = nil
            documentReplacementRequest = nil
            syncHistories = [:]
            lastKnownPageHTMLByURL = [:]
            pageReloadTokensByURL = [:]
            do {
                try currentProjectStore?.write(projectURL: project.fileURL)
            } catch {
                lastError = error.localizedDescription
            }
            seedKnownHTMLForProject(project)
            prepareHistoryForSelectedPage()
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            statusMessage = "\(project.project.name) を開きました。"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: ページ選択関数
    /// 処理概要: 選択ページを切り替え、ページ変更時にノード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: 選択するページ ID。`nil` の場合は先頭ページが表示対象になります。
    func selectPage(id: String?) {
        selectedPageID = id
        selectedNodeID = nil
        nodes = []
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
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
            let previousSelectedPageURL = selectedPageURL
            loadedProject = reloadedProject
            seedKnownHTMLForProject(reloadedProject)

            if let previousSelectedPageID,
               reloadedProject.project.pages.contains(where: { $0.id == previousSelectedPageID }) {
                selectedPageID = previousSelectedPageID
            } else {
                selectedPageID = reloadedProject.project.pages.first?.id
            }

            if selectedPageURL != previousSelectedPageURL {
                selectedNodeID = nil
                nodes = []
                prepareHistoryForSelectedPage()
            }

            restartExternalPageMonitoring(force: true)
            statusMessage = "\(reloadedProject.project.name) の .ogp 外部変更を同期しました。"
        } catch {
            lastError = ".ogp の再読み込みに失敗しました: \(error.localizedDescription)"
        }
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

    /// 論理名（日本語）: プロジェクトHTML既知状態初期化関数
    /// 処理概要: project 内の全ページ HTML を読み、外部変更検出の比較基準として保存します。
    ///
    /// - Parameter project: 比較基準を初期化する読み込み済み project。
    private func seedKnownHTMLForProject(_ project: LoadedOpenGraphiteProject) {
        for page in project.project.pages {
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

        let pageURLs = Set(loadedProject.project.pages.map { loadedProject.htmlURL(for: $0) })
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

    /// 論理名（日本語）: ページ変更監視停止関数
    /// 処理概要: 登録済みの全 HTML ファイル監視を停止します。
    private func cancelPageChangeMonitors() {
        for monitor in pageChangeMonitorsByURL.values {
            monitor.cancel()
        }
        pageChangeMonitorsByURL = [:]
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
