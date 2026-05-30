import AppKit
import SwiftUI
import WebKit

/// 論理名（日本語）: Webスクロール方向
/// 概要: WKWebView 内外のスクロールルーティングで利用する主要なスクロール方向を表します。
///
/// 定義内容:
/// - `up`: 上方向。
/// - `down`: 下方向。
/// - `left`: 左方向。
/// - `right`: 右方向。
enum WebScrollDirection {
    case up
    case down
    case left
    case right
}

/// 論理名（日本語）: Webスクロール状態
/// 概要: ポインタ直下の DOM が各方向へスクロール可能かを Swift 側へ渡す状態モデルです。
///
/// プロパティ:
/// - `isInside`: ポインタが WebView 内にあるか。
/// - `canScrollUp`: DOM が上方向へスクロールできるか。
/// - `canScrollDown`: DOM が下方向へスクロールできるか。
/// - `canScrollLeft`: DOM が左方向へスクロールできるか。
/// - `canScrollRight`: DOM が右方向へスクロールできるか。
struct WebScrollState: Equatable {
    var isInside: Bool
    var canScrollUp: Bool
    var canScrollDown: Bool
    var canScrollLeft: Bool
    var canScrollRight: Bool

    static let outside = WebScrollState(
        isInside: false,
        canScrollUp: false,
        canScrollDown: false,
        canScrollLeft: false,
        canScrollRight: false
    )

    /// 論理名（日本語）: Webスクロール状態初期化関数
    /// 処理概要: WebView 内外と四方向のスクロール可否を明示値から構成します。
    ///
    /// - Parameters:
    ///   - isInside: ポインタが WebView 内にあるか。
    ///   - canScrollUp: 上方向へスクロールできるか。
    ///   - canScrollDown: 下方向へスクロールできるか。
    ///   - canScrollLeft: 左方向へスクロールできるか。
    ///   - canScrollRight: 右方向へスクロールできるか。
    init(
        isInside: Bool,
        canScrollUp: Bool,
        canScrollDown: Bool,
        canScrollLeft: Bool,
        canScrollRight: Bool
    ) {
        self.isInside = isInside
        self.canScrollUp = canScrollUp
        self.canScrollDown = canScrollDown
        self.canScrollLeft = canScrollLeft
        self.canScrollRight = canScrollRight
    }

    /// 論理名（日本語）: payload初期化関数
    /// 処理概要: JavaScript から届く辞書 payload を Web スクロール状態へ変換します。
    ///
    /// - Parameter payload: `inside`、`up`、`down`、`left`、`right` を持つ辞書。
    init(payload: [String: Any]) {
        self.init(
            isInside: payload["inside"] as? Bool ?? false,
            canScrollUp: payload["up"] as? Bool ?? false,
            canScrollDown: payload["down"] as? Bool ?? false,
            canScrollLeft: payload["left"] as? Bool ?? false,
            canScrollRight: payload["right"] as? Bool ?? false
        )
    }

    /// 論理名（日本語）: 方向別スクロール可否判定関数
    /// 処理概要: 指定方向に対する DOM のスクロール可否を返します。
    ///
    /// - Parameter direction: 判定するスクロール方向。
    /// - Returns: 指定方向へスクロールできる場合は `true`。
    func canScroll(_ direction: WebScrollDirection) -> Bool {
        switch direction {
        case .up:
            canScrollUp
        case .down:
            canScrollDown
        case .left:
            canScrollLeft
        case .right:
            canScrollRight
        }
    }

    var canScrollAnyDirection: Bool {
        canScrollUp || canScrollDown || canScrollLeft || canScrollRight
    }
}

/// 論理名（日本語）: Webスクロール状態レジストリ
/// 概要: 複数の WKWebView ごとに JavaScript 由来のスクロール状態を保持します。
///
/// メソッド:
/// - `update(_:for:)`: WebView の状態を更新します。
/// - `state(for:)`: WebView の最新状態を取得します。
/// - `remove(for:)`: WebView 破棄時に状態を削除します。
final class WebScrollStateRegistry {
    static let shared = WebScrollStateRegistry()

    private var states: [ObjectIdentifier: WebScrollState] = [:]

    private init() {}

    /// 論理名（日本語）: Webスクロール状態更新関数
    /// 処理概要: 指定された WKWebView に対応するスクロール状態を保存します。
    ///
    /// - Parameters:
    ///   - state: 保存するスクロール状態。
    ///   - webView: 状態の対象となる WebView。
    func update(_ state: WebScrollState, for webView: WKWebView) {
        states[ObjectIdentifier(webView)] = state
    }

    /// 論理名（日本語）: Webスクロール状態取得関数
    /// 処理概要: 指定された WKWebView の最新スクロール状態を返します。
    ///
    /// - Parameter webView: 状態を取得する WebView。
    /// - Returns: 保存済み状態。未登録の場合は `nil`。
    func state(for webView: WKWebView) -> WebScrollState? {
        states[ObjectIdentifier(webView)]
    }

    /// 論理名（日本語）: Webスクロール状態削除関数
    /// 処理概要: WebView 破棄時にレジストリから状態を削除します。
    ///
    /// - Parameter webView: 削除対象の WebView。
    func remove(for webView: WKWebView) {
        states.removeValue(forKey: ObjectIdentifier(webView))
    }
}

/// 論理名（日本語）: Webキャンバスビュー
/// 概要: HTML 正本を WKWebView で表示し、DOM 選択、Inspector 変更、コンテキストメニュー操作を SwiftUI へ接続します。
///
/// プロパティ:
/// - `store`: エディター状態を保持するストア。
struct WebCanvasView: NSViewRepresentable {
    @ObservedObject var store: EditorStore

    /// 論理名（日本語）: コーディネーター生成関数
    /// 処理概要: WKWebView の navigation、script message、context menu を処理するコーディネーターを生成します。
    ///
    /// - Returns: WebCanvasView 用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    /// 論理名（日本語）: WKWebView生成関数
    /// 処理概要: OpenGraphite ブリッジスクリプトとメッセージハンドラを設定した WKWebView を作成します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: HTML プレビュー用 WKWebView。
    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "openGraphiteNodes")
        userContentController.add(context.coordinator, name: "openGraphiteSelection")
        userContentController.add(context.coordinator, name: "openGraphiteContextMenu")
        userContentController.add(context.coordinator, name: "openGraphiteScrollState")
        userContentController.add(context.coordinator, name: "openGraphiteDocumentChange")
        userContentController.addUserScript(
            WKUserScript(
                source: Self.bridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        WebScrollStateRegistry.shared.update(.outside, for: webView)
        return webView
    }

    /// 論理名（日本語）: WKWebView更新関数
    /// 処理概要: 選択ページ、選択ノード、Inspector mutation の変化を WKWebView に反映します。
    ///
    /// - Parameters:
    ///   - webView: 更新対象の WKWebView。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.store = store

        if let pageURL = store.selectedPageURL, context.coordinator.loadedURL != pageURL {
            context.coordinator.loadedURL = pageURL
            context.coordinator.lastSelectedNodeID = nil
            let readAccessURL = store.projectRootURL ?? pageURL.deletingLastPathComponent()
            webView.loadFileURL(pageURL, allowingReadAccessTo: readAccessURL)
        }

        if context.coordinator.lastSelectedNodeID != store.selectedNodeID {
            context.coordinator.lastSelectedNodeID = store.selectedNodeID
            context.coordinator.selectNode(store.selectedNodeID)
        }

        if context.coordinator.lastActiveTool != store.activeTool {
            context.coordinator.lastActiveTool = store.activeTool
            context.coordinator.setActiveTool(store.activeTool)
        }

        if let mutation = store.cssMutation,
           context.coordinator.lastAppliedMutationSequence != mutation.sequence {
            context.coordinator.applyMutation(mutation)
        }

        if let mutation = store.attributeMutation,
           context.coordinator.lastAppliedAttributeMutationSequence != mutation.sequence {
            context.coordinator.applyAttributeMutation(mutation)
        }

        if let request = store.documentReplacementRequest,
           request.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedDocumentReplacementSequence != request.sequence {
            context.coordinator.applyDocumentReplacement(request)
        }
    }

    /// 論理名（日本語）: WKWebView解体関数
    /// 処理概要: script message handler とスクロール状態登録を破棄します。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象の WKWebView。
    ///   - coordinator: WKWebView に紐づくコーディネーター。
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteNodes")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteSelection")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteContextMenu")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteScrollState")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteDocumentChange")
        WebScrollStateRegistry.shared.remove(for: nsView)
    }

    /// 論理名（日本語）: Webキャンバスコーディネーター
    /// 概要: WKWebView と SwiftUI ストアの間で JavaScript bridge、HTML 永続化、context menu を仲介します。
    ///
    /// プロパティ:
    /// - `store`: エディター状態ストア。
    /// - `webView`: 管理対象の WKWebView。
    /// - `loadedURL`: 現在読み込み済みの HTML URL。
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        @MainActor var store: EditorStore
        weak var webView: WKWebView?
        var loadedURL: URL?
        var lastSelectedNodeID: String?
        var lastActiveTool: CanvasTool?
        var lastAppliedMutationSequence = 0
        var lastAppliedAttributeMutationSequence = 0
        var lastAppliedDocumentReplacementSequence = 0
        private static let htmlPasteboardType = NSPasteboard.PasteboardType("public.html")
        private static let cssVariablesPasteboardType = NSPasteboard.PasteboardType("dev.opengraphite.css-variables")

        /// 論理名（日本語）: コーディネーター初期化関数
        /// 処理概要: WebView ブリッジで更新するエディター状態ストアを保持します。
        ///
        /// - Parameter store: 連携対象のエディター状態ストア。
        init(store: EditorStore) {
            self.store = store
        }

        /// 論理名（日本語）: Script Message受信関数
        /// 処理概要: JavaScript から届くノード一覧、選択、context menu、スクロール状態、ドキュメント変更通知をストアへ反映します。
        ///
        /// - Parameters:
        ///   - userContentController: メッセージ送信元の user content controller。
        ///   - message: JavaScript bridge から届いたメッセージ。
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "openGraphiteNodes", let payload = message.body as? [[String: Any]] {
                Task { @MainActor in
                    store.ingestNodePayload(payload)
                }
            }

            if message.name == "openGraphiteSelection", let id = message.body as? String {
                Task { @MainActor in
                    store.selectNode(id: id.isEmpty ? nil : id)
                }
            }

            if message.name == "openGraphiteContextMenu", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    if let id = payload["id"] as? String, !id.isEmpty {
                        store.selectNode(id: id)
                    }
                    showContextMenu(payload: payload)
                }
            }

            if message.name == "openGraphiteScrollState", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    updateScrollState(payload: payload)
                }
            }

            if message.name == "openGraphiteDocumentChange" {
                Task { @MainActor in
                    serializeAndSyncHTML {}
                }
            }
        }

        /// 論理名（日本語）: WebView読み込み完了関数
        /// 処理概要: HTML 読み込み完了後に DOM ノード一覧を収集し、選択状態を再適用します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みが完了した WebView。
        ///   - navigation: 完了した navigation。
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.collectNodes();")
            Task { @MainActor in
                setActiveTool(store.activeTool)
                selectNode(store.selectedNodeID)
            }
        }

        /// 論理名（日本語）: WebView読み込み失敗関数
        /// 処理概要: 確定後 navigation の失敗をエディターのエラー表示へ転送します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みに失敗した WebView。
        ///   - navigation: 失敗した navigation。
        ///   - error: WebKit から渡されたエラー。
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store.reportWebError("HTMLの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }

        /// 論理名（日本語）: WebView暫定読み込み失敗関数
        /// 処理概要: provisional navigation の失敗をエディターのエラー表示へ転送します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みに失敗した WebView。
        ///   - navigation: 失敗した provisional navigation。
        ///   - error: WebKit から渡されたエラー。
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store.reportWebError("HTMLの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }

        @MainActor
        /// 論理名（日本語）: WebViewノード選択関数
        /// 処理概要: Swift 側の選択 ID を JavaScript bridge 経由で DOM の選択表示へ反映します。
        ///
        /// - Parameter id: 選択する `data-og-id`。選択解除時は `nil`。
        func selectNode(_ id: String?) {
            guard let webView else { return }
            let idLiteral = Self.javaScriptLiteral(id ?? "")
            webView.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.selectNode(\(idLiteral));")
        }

        @MainActor
        /// 論理名（日本語）: アクティブツール反映関数
        /// 処理概要: SwiftUI 側のキャンバスツール状態を JavaScript bridge へ反映します。
        ///
        /// - Parameter tool: 現在選択されているキャンバスツール。
        func setActiveTool(_ tool: CanvasTool) {
            guard let webView else { return }
            webView.evaluateJavaScript(
                "window.OpenGraphite && window.OpenGraphite.setActiveTool(\(Self.javaScriptLiteral(tool.rawValue)));"
            )
        }

        @MainActor
        /// 論理名（日本語）: CSS変数mutation反映関数
        /// 処理概要: CSS 変数 mutation を DOM へ適用し、成功時に HTML をディスクへ同期します。
        ///
        /// - Parameter mutation: 反映対象の CSS 変数 mutation。
        func applyMutation(_ mutation: CSSVariableMutation) {
            guard let webView else { return }
            lastAppliedMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setCSSVariable(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.key)),
              \(Self.javaScriptLiteral(mutation.value))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("CSS変数の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.serializeAndSyncHTML {
                            self.store.markMutationApplied(sequence: mutation.sequence)
                        }
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 属性mutation反映関数
        /// 処理概要: `data-og-*` 属性 mutation を DOM へ適用し、成功時に HTML をディスクへ同期します。
        ///
        /// - Parameter mutation: 反映対象の属性 mutation。
        func applyAttributeMutation(_ mutation: NodeAttributeMutation) {
            guard let webView else { return }
            lastAppliedAttributeMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setAttributeValue(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.name)),
              \(Self.javaScriptLiteral(mutation.value))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("属性の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.serializeAndSyncHTML {
                            self.store.markAttributeMutationApplied(sequence: mutation.sequence)
                        }
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: ドキュメント置換適用関数
        /// 処理概要: undo/redo で選ばれた HTML スナップショットを DOM へ反映し、失敗時はディスクから再読み込みします。
        ///
        /// - Parameter request: WebView へ適用する HTML 置換要求。
        func applyDocumentReplacement(_ request: DocumentReplacementRequest) {
            guard let webView else { return }
            lastAppliedDocumentReplacementSequence = request.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.replaceDocumentHTML(
              \(Self.javaScriptLiteral(request.html)),
              \(Self.javaScriptLiteral(request.selectedNodeID ?? ""))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました: \(error.localizedDescription)")
                        self.reloadCurrentPageFromDisk()
                    } else if (result as? Bool) != true {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました。")
                        self.reloadCurrentPageFromDisk()
                    }

                    self.store.markDocumentReplacementApplied(sequence: request.sequence)
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: HTMLシリアライズ同期関数
        /// 処理概要: DOM から編集用選択属性を除いた HTML を生成し、現在ページへ同期します。
        ///
        /// - Parameter onSuccess: 同期成功後に実行する処理。
        private func serializeAndSyncHTML(onSuccess: @escaping @MainActor () -> Void) {
            guard let webView else { return }

            let script = """
            (function() {
              const clone = document.documentElement.cloneNode(true);
              clone.querySelectorAll('[data-og-selected]').forEach((element) => {
                element.removeAttribute('data-og-selected');
              });
              clone.querySelectorAll('[data-og-editing]').forEach((element) => {
                element.removeAttribute('data-og-editing');
                element.removeAttribute('contenteditable');
                element.removeAttribute('spellcheck');
                element.style.removeProperty('--og-edit-width');
                element.style.removeProperty('--og-edit-min-height');
              });
              return '<!doctype html>\\n' + clone.outerHTML;
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("HTMLのシリアライズに失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if let html = result as? String {
                        self.store.syncCurrentHTML(html)
                        onSuccess()
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 現在ページディスク再読み込み関数
        /// 処理概要: WebView 側 DOM 更新に失敗した場合、同期済みディスク内容を再読み込みして表示を戻します。
        private func reloadCurrentPageFromDisk() {
            guard let webView, let loadedURL else { return }
            let readAccessURL = store.projectRootURL ?? loadedURL.deletingLastPathComponent()
            webView.loadFileURL(loadedURL, allowingReadAccessTo: readAccessURL)
        }

        /// 論理名（日本語）: JavaScript文字列リテラル生成関数
        /// 処理概要: Swift 文字列を JSON エンコードし、JavaScript へ安全に埋め込める文字列へ変換します。
        ///
        /// - Parameter string: JavaScript に渡す Swift 文字列。
        /// - Returns: JavaScript 文字列リテラル。
        private static func javaScriptLiteral(_ string: String) -> String {
            let data = (try? JSONEncoder().encode(string)) ?? Data("\"\"".utf8)
            return String(data: data, encoding: .utf8) ?? "\"\""
        }

        @MainActor
        /// 論理名（日本語）: スクロール状態更新関数
        /// 処理概要: JavaScript 由来のスクロール状態 payload を registry に保存します。
        ///
        /// - Parameter payload: WebView 内のスクロール可否 payload。
        private func updateScrollState(payload: [String: Any]) {
            guard let webView else { return }
            WebScrollStateRegistry.shared.update(WebScrollState(payload: payload), for: webView)
        }

        @MainActor
        /// 論理名（日本語）: コンテキストメニュー表示関数
        /// 処理概要: JavaScript から渡されたクリック位置と候補レイヤーをもとに編集メニューを表示します。
        ///
        /// - Parameter payload: 選択 ID、座標、候補レイヤーを含む payload。
        private func showContextMenu(payload: [String: Any]) {
            guard let webView else { return }

            let selectedID = payload["id"] as? String
            let selectedNode = selectedID.flatMap { id in store.nodes.first { $0.id == id } }
            let isPageNode = selectedNode?.type == "page"
            let isHidden = selectedNode?.isHidden == true
            let isLocked = selectedNode?.isLocked == true
            let canMutateSelection = selectedID != nil && !isPageNode && !isLocked
            let canSetLayout = (selectedNode?.type == "frame" || selectedNode?.type == "page") && !isLocked
            let hasPasteContent = pasteboardPayload() != nil
            let hasCSSVariableContent = cssVariablesPasteboardPayload() != nil
            let menu = NSMenu(title: "OpenGraphite")
            menu.autoenablesItems = false

            addMenuItem("コピー", command: "copy", to: menu, enabled: selectedID != nil, keyEquivalent: "c", modifiers: [.command])
            addMenuItem("ここに貼り付け", command: "pasteHere", to: menu, enabled: selectedID != nil && hasPasteContent)
            addMenuItem("貼り付けて置換", command: "pasteReplace", to: menu, enabled: canMutateSelection && hasPasteContent, keyEquivalent: "r", modifiers: [.command, .shift])

            let copyOptions = NSMenu(title: "コピー/貼り付けオプション")
            addMenuItem("HTMLとしてコピー", command: "copyHTML", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("テキストとしてコピー", command: "copyText", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("CSS変数としてコピー", command: "copyCSSVariables", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("HTMLをここに貼り付け", command: "pasteHere", to: copyOptions, enabled: selectedID != nil && hasPasteContent)
            addMenuItem("CSS変数を貼り付け", command: "pasteCSSVariables", to: copyOptions, enabled: canMutateSelection && hasCSSVariableContent)
            let copyOptionsItem = NSMenuItem(title: "コピー/貼り付けオプション", action: nil, keyEquivalent: "")
            copyOptionsItem.submenu = copyOptions
            menu.addItem(copyOptionsItem)

            menu.addItem(.separator())

            if let candidates = layerCandidates(from: payload), !candidates.isEmpty {
                let layerMenu = NSMenu(title: "レイヤーを選択")
                for candidate in candidates {
                    let item = NSMenuItem(title: candidate.title, action: #selector(performContextMenuAction(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = "select:\(candidate.id)"
                    item.state = candidate.id == selectedID ? .on : .off
                    layerMenu.addItem(item)
                }

                let layerItem = NSMenuItem(title: "レイヤーを選択", action: nil, keyEquivalent: "")
                layerItem.submenu = layerMenu
                menu.addItem(layerItem)
            }

            addMenuItem("最前面へ移動", command: "moveFront", to: menu, enabled: canMutateSelection, keyEquivalent: "]")
            addMenuItem("最背面へ移動", command: "moveBack", to: menu, enabled: canMutateSelection, keyEquivalent: "[")

            menu.addItem(.separator())

            addMenuItem("選択範囲のフレーム化", command: "wrapFrame", to: menu, enabled: canMutateSelection, keyEquivalent: "g", modifiers: [.command, .option])
            addMenuItem("グループ解除", command: "ungroup", to: menu, enabled: selectedNode?.type == "frame" && !isPageNode, keyEquivalent: "\u{8}", modifiers: [.command])

            menu.addItem(.separator())

            addMenuItem("オートレイアウトを追加", command: "layoutVertical", to: menu, enabled: canSetLayout, keyEquivalent: "a", modifiers: [.shift])

            let layoutMenu = NSMenu(title: "その他のレイアウトオプション")
            addMenuItem("縦方向レイアウト", command: "layoutVertical", to: layoutMenu, enabled: canSetLayout)
            addMenuItem("横方向レイアウト", command: "layoutHorizontal", to: layoutMenu, enabled: canSetLayout)
            addMenuItem("絶対配置レイアウト", command: "layoutAbsolute", to: layoutMenu, enabled: canSetLayout)
            let layoutItem = NSMenuItem(title: "その他のレイアウトオプション", action: nil, keyEquivalent: "")
            layoutItem.submenu = layoutMenu
            menu.addItem(layoutItem)

            menu.addItem(.separator())

            addMenuItem(isHidden ? "表示" : "非表示", command: "toggleHidden", to: menu, enabled: canMutateSelection, keyEquivalent: "h", modifiers: [.command, .shift])
            addMenuItem(isLocked ? "ロック解除" : "ロック", command: "toggleLocked", to: menu, enabled: selectedID != nil && !isPageNode, keyEquivalent: "l", modifiers: [.command, .shift])
            addMenuItem("左右反転", command: "flipHorizontal", to: menu, enabled: canMutateSelection, keyEquivalent: "h", modifiers: [.shift])
            addMenuItem("上下反転", command: "flipVertical", to: menu, enabled: canMutateSelection, keyEquivalent: "v", modifiers: [.shift])

            menu.addItem(.separator())

            addMenuItem("削除", command: "delete", to: menu, enabled: canMutateSelection, keyEquivalent: "\u{8}")

            let x = payload["x"] as? Double ?? Double(webView.bounds.midX)
            let y = payload["y"] as? Double ?? Double(webView.bounds.midY)
            let point = NSPoint(x: x, y: y)
            DispatchQueue.main.async { [weak webView] in
                guard let webView else { return }
                menu.popUp(positioning: nil, at: point, in: webView)
            }
        }

        /// 論理名（日本語）: メニュー項目追加関数
        /// 処理概要: context menu に実行コマンド付きの `NSMenuItem` を追加します。
        ///
        /// - Parameters:
        ///   - title: 表示タイトル。
        ///   - command: 実行する OpenGraphite コマンド。
        ///   - menu: 追加先メニュー。
        ///   - enabled: 項目を有効にするか。
        ///   - keyEquivalent: キーボードショートカット文字。
        ///   - modifiers: キーボードショートカットの修飾キー。
        private func addMenuItem(
            _ title: String,
            command: String,
            to menu: NSMenu,
            enabled: Bool,
            keyEquivalent: String = "",
            modifiers: NSEvent.ModifierFlags = []
        ) {
            let item = NSMenuItem(title: title, action: #selector(performContextMenuAction(_:)), keyEquivalent: keyEquivalent)
            item.target = self
            item.representedObject = command
            item.isEnabled = enabled
            item.keyEquivalentModifierMask = modifiers
            menu.addItem(item)
        }

        /// 論理名（日本語）: コンテキストメニューアクション実行関数
        /// 処理概要: `NSMenuItem` に保持されたコマンド文字列を取得し、メインアクター上で処理します。
        ///
        /// - Parameter sender: 選択されたメニュー項目。
        @objc private func performContextMenuAction(_ sender: NSMenuItem) {
            guard let command = sender.representedObject as? String else { return }
            Task { @MainActor in
                handleContextMenuAction(command)
            }
        }

        @MainActor
        /// 論理名（日本語）: コンテキストメニューコマンド処理関数
        /// 処理概要: コピー、貼り付け、レイアウト変更、表示状態変更などのメニューコマンドを実行します。
        ///
        /// - Parameter command: 実行するコマンド名。
        private func handleContextMenuAction(_ command: String) {
            if command.hasPrefix("select:") {
                let id = String(command.dropFirst("select:".count))
                store.selectNode(id: id)
                selectNode(id)
                return
            }

            switch command {
            case "copy", "copyHTML":
                copySelection(includeHTML: true, includeText: true)
            case "copyText":
                copySelection(includeHTML: false, includeText: true)
            case "copyCSSVariables":
                copySelection(includeHTML: false, includeText: false, includeCSSVariables: true)
            case "pasteHere", "pasteReplace":
                guard let payload = pasteboardPayload() else { return }
                performDOMCommand(command, payload: payload)
            case "pasteCSSVariables":
                guard let payload = cssVariablesPasteboardPayload() else { return }
                performDOMCommand(command, payload: payload)
            case "layoutVertical":
                performDOMCommand("setLayout", payload: ["layout": "vertical"])
            case "layoutHorizontal":
                performDOMCommand("setLayout", payload: ["layout": "horizontal"])
            case "layoutAbsolute":
                performDOMCommand("setLayout", payload: ["layout": "absolute"])
            default:
                performDOMCommand(command, payload: [:])
            }
        }

        @MainActor
        /// 論理名（日本語）: 選択内容コピー関数
        /// 処理概要: 選択中 DOM の HTML、テキスト、CSS 変数を pasteboard へ書き込みます。
        ///
        /// - Parameters:
        ///   - includeHTML: HTML をコピー対象に含めるか。
        ///   - includeText: テキストをコピー対象に含めるか。
        ///   - includeCSSVariables: CSS 変数をコピー対象に含めるか。
        private func copySelection(includeHTML: Bool, includeText: Bool, includeCSSVariables: Bool = false) {
            guard let webView else { return }

            webView.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.copyPayload();") { result, error in
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("コピーに失敗しました: \(error.localizedDescription)")
                        return
                    }

                    guard let payload = result as? [String: Any] else { return }
                    let html = payload["html"] as? String ?? ""
                    let text = payload["text"] as? String ?? ""
                    let cssVariables = (payload["cssVariables"] as? [String: Any] ?? [:])
                        .compactMapValues { $0 as? String }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()

                    if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: Self.htmlPasteboardType)
                    }

                    if includeText, !text.isEmpty {
                        pasteboard.setString(text, forType: .string)
                    } else if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: .string)
                    }

                    if includeCSSVariables, !cssVariables.isEmpty,
                       let data = try? JSONSerialization.data(withJSONObject: cssVariables),
                       let json = String(data: data, encoding: .utf8) {
                        pasteboard.setString(json, forType: Self.cssVariablesPasteboardType)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: DOMコマンド実行関数
        /// 処理概要: JavaScript bridge の `runCommand` を呼び出し、成功時に HTML をディスクへ同期します。
        ///
        /// - Parameters:
        ///   - command: DOM に対して実行するコマンド名。
        ///   - payload: コマンドに渡す文字列 payload。
        private func performDOMCommand(_ command: String, payload: [String: String]) {
            guard let webView else { return }
            let payloadLiteral = Self.jsonLiteral(payload)
            let script = """
            window.OpenGraphite && window.OpenGraphite.runCommand(
              \(Self.javaScriptLiteral(command)),
              \(payloadLiteral)
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("コンテキストメニュー操作に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    guard let response = result as? [String: Any],
                          (response["success"] as? Bool) == true
                    else {
                        return
                    }

                    if let selectedID = response["selectedID"] as? String, !selectedID.isEmpty {
                        self.store.selectNode(id: selectedID)
                    }

                    self.serializeAndSyncHTML {}
                }
            }
        }

        /// 論理名（日本語）: pasteboard payload取得関数
        /// 処理概要: pasteboard から HTML またはテキストを読み取り、DOM コマンド用 payload に変換します。
        ///
        /// - Returns: 貼り付け可能な payload。空の場合は `nil`。
        private func pasteboardPayload() -> [String: String]? {
            let pasteboard = NSPasteboard.general
            if let html = pasteboard.string(forType: Self.htmlPasteboardType),
               !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["html": html]
            }

            if let string = pasteboard.string(forType: .string),
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["text": string]
            }

            return nil
        }

        /// 論理名（日本語）: CSS変数pasteboard payload取得関数
        /// 処理概要: pasteboard から OpenGraphite 専用形式の CSS 変数 JSON を読み取ります。
        ///
        /// - Returns: `--og-*` だけを含む CSS 変数 payload。空の場合は `nil`。
        private func cssVariablesPasteboardPayload() -> [String: String]? {
            let pasteboard = NSPasteboard.general
            guard let json = pasteboard.string(forType: Self.cssVariablesPasteboardType),
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            else {
                return nil
            }

            let variables = object.filter { key, value in
                key.hasPrefix("--og-") && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return variables.isEmpty ? nil : variables
        }

        /// 論理名（日本語）: レイヤー候補
        /// 概要: 右クリック位置の DOM 祖先から選択候補として表示するレイヤー情報です。
        ///
        /// プロパティ:
        /// - `id`: 対象ノードの `data-og-id`。
        /// - `title`: メニューに表示するタイトル。
        private struct LayerCandidate {
            var id: String
            var title: String
        }

        /// 論理名（日本語）: レイヤー候補変換関数
        /// 処理概要: JavaScript payload の候補配列を context menu 表示用モデルへ変換します。
        ///
        /// - Parameter payload: JavaScript から渡された context menu payload。
        /// - Returns: レイヤー候補一覧。候補がない場合は `nil`。
        private func layerCandidates(from payload: [String: Any]) -> [LayerCandidate]? {
            guard let rawCandidates = payload["candidates"] as? [[String: Any]] else { return nil }
            return rawCandidates.compactMap { candidate in
                guard let id = candidate["id"] as? String, !id.isEmpty else { return nil }
                let tagName = candidate["tagName"] as? String ?? id
                let detail = [candidate["type"] as? String, candidate["role"] as? String]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                let title = detail.isEmpty ? tagName : "\(tagName)  \(detail)"
                return LayerCandidate(id: id, title: title)
            }
        }

        /// 論理名（日本語）: JavaScript辞書リテラル生成関数
        /// 処理概要: Swift の文字列辞書を JSON 化し、JavaScript へ安全に渡せるリテラルへ変換します。
        ///
        /// - Parameter dictionary: JavaScript に渡す文字列辞書。
        /// - Returns: JavaScript オブジェクトリテラルとして利用できる JSON 文字列。
        private static func jsonLiteral(_ dictionary: [String: String]) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data("{}".utf8)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    private static let bridgeScript = """
    (function() {
        if (window.OpenGraphite) {
          window.OpenGraphite.collectNodes();
          return;
        }

        let currentSelectedID = '';
        let dragStartThreshold = 3;
        let pointerDragButtons = 1;
        let primaryPointerButton = 0;
        let passivePointerOptions = { capture: true, passive: true };
        let activePointerOptions = { capture: true, passive: false };
        var activeTool = 'select';
        var pendingDrag = null;
        var activeDrag = null;
        var editingTextElement = null;
        var editingOriginalText = '';
        var suppressNextClick = false;

      function cssVariables(element) {
        const style = element.getAttribute('style') || '';
        const variables = {};
        style.split(';').forEach((part) => {
          const index = part.indexOf(':');
          if (index <= 0) { return; }
          const key = part.slice(0, index).trim();
          const value = part.slice(index + 1).trim();
          if (key.indexOf('--og-') === 0 && value.length > 0) {
            variables[key] = value;
          }
        });
        return variables;
      }

      function depth(element) {
        let count = 0;
        let parent = element.parentElement;
        while (parent && parent !== document.body && parent !== document.documentElement) {
          count += 1;
          parent = parent.parentElement;
        }
        return count;
      }

      function allEditableNodes() {
        return Array.from(document.querySelectorAll('[data-og-id]'));
      }

        function nodeWithID(id) {
          return allEditableNodes().find((element) => element.getAttribute('data-og-id') === id);
        }

        function selectedElement() {
          if (currentSelectedID) {
            const element = nodeWithID(currentSelectedID);
            if (element) { return element; }
          }
          return document.querySelector('[data-og-selected="true"]');
        }

        function setActiveTool(tool) {
          if (editingTextElement) {
            finishTextEditing(false);
          }
          activeTool = tool || 'select';
          pendingDrag = null;
        }

        function elementID(element) {
          return element ? element.getAttribute('data-og-id') || '' : '';
        }

        function editableElementFromTarget(target) {
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }
          return element ? element.closest('[data-og-id]') : null;
        }

        function selectableChainFor(element) {
          const chain = [];
          let current = element;
          while (current && current !== document.documentElement) {
            if (current.hasAttribute && current.hasAttribute('data-og-id')) {
              chain.push(current);
            }
            current = current.parentElement;
          }

          const rootToLeaf = chain.reverse();
          const withoutPage = rootToLeaf.filter((candidate) => {
            return (candidate.getAttribute('data-og-type') || '') !== 'page';
          });
          return withoutPage.length > 0 ? withoutPage : rootToLeaf;
        }

        function nextSelectionIDForClick(element) {
          const chain = selectableChainFor(element);
          if (chain.length === 0) { return ''; }

          const currentIndex = chain.findIndex((candidate) => elementID(candidate) === currentSelectedID);
          if (currentIndex < 0) {
            return elementID(chain[0]);
          }

          const nextIndex = Math.min(currentIndex + 1, chain.length - 1);
          return elementID(chain[nextIndex]);
        }

        function elementInChain(chain, id) {
          if (!id) { return null; }
          return chain.find((candidate) => elementID(candidate) === id) || null;
        }

        function hasLockedAncestor(element) {
          let current = element;
          while (current && current !== document.documentElement) {
            if (current.getAttribute && current.getAttribute('data-og-locked') === 'true') {
              return true;
            }
            current = current.parentElement;
          }
          return false;
        }

        function canDragElement(element) {
          if (!element) { return false; }
          const type = element.getAttribute('data-og-type') || '';
          return type !== 'page' && !hasLockedAncestor(element);
        }

        function isTextElement(element) {
          return element && (element.getAttribute('data-og-type') || '') === 'text';
        }

        function draggableElementForChain(chain) {
          const selected = elementInChain(chain, currentSelectedID);
          if (canDragElement(selected)) {
            return selected;
          }
          return chain.find(canDragElement) || null;
        }

        function textElementForEditing(element) {
          const chain = selectableChainFor(element);
          const selected = elementInChain(chain, currentSelectedID);
          if (isTextElement(selected) && !hasLockedAncestor(selected)) {
            return selected;
          }

          const deepestText = chain.slice().reverse().find((candidate) => isTextElement(candidate));
          return deepestText && !hasLockedAncestor(deepestText) ? deepestText : null;
        }

      function collectNodes() {
        const nodes = allEditableNodes().map((element) => ({
          id: element.getAttribute('data-og-id') || '',
          tagName: element.tagName.toLowerCase(),
          type: element.getAttribute('data-og-type') || '',
          layout: element.getAttribute('data-og-layout') || '',
          role: element.getAttribute('data-og-role') || '',
          cssVariables: cssVariables(element),
          hidden: element.getAttribute('data-og-hidden') === 'true',
          locked: element.getAttribute('data-og-locked') === 'true',
          depth: depth(element)
        }));
        window.webkit.messageHandlers.openGraphiteNodes.postMessage(nodes);
        return nodes;
      }

        function clearSelection() {
        document.querySelectorAll('[data-og-selected]').forEach((element) => {
          element.removeAttribute('data-og-selected');
        });
      }

        function selectNode(id) {
          if (editingTextElement && elementID(editingTextElement) !== id) {
            finishTextEditing(false, false);
          }
          clearSelection();
          currentSelectedID = '';
          if (!id) { return false; }
          const element = nodeWithID(id);
          if (!element) { return false; }
          currentSelectedID = id;
          element.setAttribute('data-og-selected', 'true');
          element.scrollIntoView({ block: 'nearest', inline: 'nearest' });
          return true;
        }

        function notifySelection(id) {
          window.webkit.messageHandlers.openGraphiteSelection.postMessage(id || '');
        }

        function notifyDocumentChange(selectedID) {
          window.webkit.messageHandlers.openGraphiteDocumentChange.postMessage({
            selectedID: selectedID || currentSelectedID || ''
          });
        }

        function editablePlainText(element) {
          if (!element) { return ''; }
          const value = typeof element.innerText === 'string' ? element.innerText : element.textContent || '';
          return value.replace(/\\n+$/, '');
        }

        function selectTextContents(element) {
          const selection = window.getSelection();
          if (!selection) { return; }
          const range = document.createRange();
          range.selectNodeContents(element);
          selection.removeAllRanges();
          selection.addRange(range);
        }

        function applyTextEditingMetrics(element) {
          const rect = element.getBoundingClientRect();
          element.style.setProperty('--og-edit-width', pixelString(rect.width));
          element.style.setProperty('--og-edit-min-height', pixelString(rect.height));
        }

        function removeTextEditingMetrics(element) {
          element.style.removeProperty('--og-edit-width');
          element.style.removeProperty('--og-edit-min-height');
        }

        function removeTextEditingAttributes(element) {
          element.removeAttribute('data-og-editing');
          element.removeAttribute('contenteditable');
          element.removeAttribute('spellcheck');
          removeTextEditingMetrics(element);
        }

        function replaceTextContents(element, text) {
          element.replaceChildren();
          const lines = (text || '').split('\\n');
          lines.forEach((line, index) => {
            if (index > 0) {
              element.append(document.createElement('br'));
            }
            if (line.length > 0) {
              element.append(document.createTextNode(line));
            }
          });
        }

        function beginTextEditing(element, shouldSelectText) {
          if (activeTool !== 'select' || !isTextElement(element) || hasLockedAncestor(element)) {
            return false;
          }

          if (editingTextElement && editingTextElement !== element) {
            finishTextEditing(false, false);
          }

          const id = elementID(element);
          selectNode(id);
          notifySelection(id);
          editingTextElement = element;
          editingOriginalText = editablePlainText(element);
          applyTextEditingMetrics(element);
          element.setAttribute('contenteditable', 'plaintext-only');
          element.setAttribute('spellcheck', 'true');
          element.setAttribute('data-og-editing', 'true');
          element.focus({ preventScroll: true });

          if (shouldSelectText) {
            selectTextContents(element);
          }
          return true;
        }

        function finishTextEditing(cancelled, shouldRestoreSelection) {
          const element = editingTextElement;
          if (!element) { return; }
          const selectedID = elementID(element);
          const originalText = editingOriginalText;
          const nextText = cancelled ? originalText : editablePlainText(element);

          editingTextElement = null;
          editingOriginalText = '';
          replaceTextContents(element, nextText);
          removeTextEditingAttributes(element);

          if (shouldRestoreSelection !== false) {
            selectNode(selectedID);
            notifySelection(selectedID);
          }

          if (!cancelled && nextText !== originalText) {
            collectNodes();
            notifyDocumentChange(selectedID);
          }
        }

      function setCSSVariable(id, key, value) {
        const element = nodeWithID(id);
        if (!element) { return false; }
        if ((value || '').trim().length === 0) {
          element.style.removeProperty(key);
        } else {
          element.style.setProperty(key, value);
        }
        collectNodes();
        return true;
      }

        function setAttributeValue(id, name, value) {
          const element = nodeWithID(id);
          if (!element) { return false; }
        if ((value || '').trim().length === 0) {
          element.removeAttribute(name);
        } else {
          element.setAttribute(name, value);
        }
        collectNodes();
          return true;
        }

        function slug(value) {
          const allowed = 'abcdefghijklmnopqrstuvwxyz0123456789_-';
          let result = '';
          Array.from((value || 'node').toLowerCase()).forEach((character) => {
            result += allowed.indexOf(character) >= 0 ? character : '-';
          });
          while (result.indexOf('--') >= 0) {
            result = result.replaceAll('--', '-');
          }
          result = result.replaceAll('_-', '_').replaceAll('-_', '_');
          if (result.startsWith('-')) { result = result.slice(1); }
          if (result.endsWith('-')) { result = result.slice(0, -1); }
          return result || 'node';
        }

        function uniqueID(base) {
          const existing = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-id') || ''));
          const cleanBase = slug(base);
          let candidate = cleanBase;
          let index = 2;
          while (existing.has(candidate)) {
            candidate = cleanBase + '-' + index;
            index += 1;
          }
          return candidate;
        }

        function editableElementsInside(root) {
          const result = [];
          function visit(node) {
            if (node.nodeType !== Node.ELEMENT_NODE) { return; }
            if (node.hasAttribute('data-og-id') || node.hasAttribute('data-og-type')) {
              result.push(node);
            }
            Array.from(node.children).forEach(visit);
          }
          Array.from(root.childNodes).forEach(visit);
          return result;
        }

        function normalizeEditableIDs(fragment) {
          const used = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-id') || ''));
          editableElementsInside(fragment).forEach((element) => {
            if (!element.hasAttribute('data-og-type')) {
              element.setAttribute('data-og-type', 'frame');
            }
            const current = element.getAttribute('data-og-id') || element.tagName.toLowerCase();
            let candidate = slug(current);
            let index = 2;
            while (used.has(candidate)) {
              candidate = slug(current) + '-' + index;
              index += 1;
            }
            element.setAttribute('data-og-id', candidate);
            used.add(candidate);
          });
        }

        function textElementFromString(text) {
          const element = document.createElement('TextBlock');
          element.setAttribute('data-og-id', uniqueID('text'));
          element.setAttribute('data-og-type', 'text');
          element.textContent = text || '';
          return element;
        }

        function fragmentFromPayload(payload) {
          const fragment = document.createDocumentFragment();
          const html = payload && payload.html ? payload.html : '';
          const text = payload && payload.text ? payload.text : '';
          if (html.trim().length > 0) {
            const template = document.createElement('template');
            template.innerHTML = html;
            fragment.append(template.content.cloneNode(true));
          } else {
            fragment.append(textElementFromString(text));
          }

          if (editableElementsInside(fragment).length === 0) {
            const textContent = fragment.textContent || text || html;
            fragment.replaceChildren(textElementFromString(textContent));
          }

          normalizeEditableIDs(fragment);
          return fragment;
        }

        function firstEditableID(root) {
          const editable = editableElementsInside(root)[0];
          return editable ? editable.getAttribute('data-og-id') || '' : '';
        }

        function canReceiveChildren(element) {
          const type = element.getAttribute('data-og-type') || '';
          return type === 'frame' || type === 'page' || element.hasAttribute('data-og-layout');
        }

        function createFrameID() {
          return uniqueID('frame');
        }

        function setLayout(layout) {
          const element = selectedElement();
          if (!element) { return ''; }
          element.setAttribute('data-og-layout', layout);
          return element.getAttribute('data-og-id') || '';
        }

        function toggleScaleVariable(element, key) {
          const current = element.style.getPropertyValue(key).trim();
          if (current === '-1') {
            element.style.removeProperty(key);
          } else {
            element.style.setProperty(key, '-1');
          }
        }

        function layerCandidatesFor(element) {
          const result = [];
          let current = element;
          while (current && current !== document.documentElement) {
            if (current.hasAttribute && current.hasAttribute('data-og-id')) {
              result.push({
                id: current.getAttribute('data-og-id') || '',
                tagName: current.tagName.toLowerCase(),
                type: current.getAttribute('data-og-type') || '',
                role: current.getAttribute('data-og-role') || ''
              });
            }
            current = current.parentElement;
          }
          return result;
        }

        function allowsOverflowScroll(value) {
          return value === 'auto' || value === 'scroll' || value === 'overlay';
        }

        let lastPointer = null;
        let lastScrollStateSignature = '';

        function emptyScrollState(isInside) {
          return { inside: !!isInside, up: false, down: false, left: false, right: false };
        }

        function scrollStateForElement(element, includeDocument) {
          if (!element || element.nodeType !== Node.ELEMENT_NODE) {
            return emptyScrollState(true);
          }

          const style = window.getComputedStyle(element);
          const epsilon = 0;
          const canScrollY = (includeDocument || allowsOverflowScroll(style.overflowY)) &&
            element.scrollHeight > element.clientHeight + epsilon;
          const canScrollX = (includeDocument || allowsOverflowScroll(style.overflowX)) &&
            element.scrollWidth > element.clientWidth + epsilon;

          return {
            inside: true,
            up: canScrollY && element.scrollTop > epsilon,
            down: canScrollY && element.scrollTop + element.clientHeight < element.scrollHeight - epsilon,
            left: canScrollX && element.scrollLeft > epsilon,
            right: canScrollX && element.scrollLeft + element.clientWidth < element.scrollWidth - epsilon
          };
        }

        function mergeScrollState(into, state) {
          into.up = into.up || state.up;
          into.down = into.down || state.down;
          into.left = into.left || state.left;
          into.right = into.right || state.right;
          return into;
        }

        function scrollStateForTarget(target) {
          const result = emptyScrollState(!!target);
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }

          while (element && element !== document.documentElement) {
            mergeScrollState(result, scrollStateForElement(element, false));
            element = element.parentElement;
          }

          const scrollingElement = document.scrollingElement || document.documentElement;
          mergeScrollState(result, scrollStateForElement(scrollingElement, true));
          return result;
        }

        function postScrollState(state) {
          const signature = [
            state.inside,
            state.up,
            state.down,
            state.left,
            state.right
          ].join(':');
          if (signature === lastScrollStateSignature) { return; }
          lastScrollStateSignature = signature;
          window.webkit.messageHandlers.openGraphiteScrollState.postMessage(state);
        }

        function updateScrollStateAt(clientX, clientY) {
          lastPointer = { x: clientX, y: clientY };
          postScrollState(scrollStateForTarget(document.elementFromPoint(clientX, clientY)));
        }

        function updateLastPointerScrollState() {
          if (!lastPointer) { return; }
          updateScrollStateAt(lastPointer.x, lastPointer.y);
        }

        function markPointerOutside() {
          lastPointer = null;
          postScrollState(emptyScrollState(false));
        }

        function numericPixelValue(value, fallback) {
          const trimmed = (value || '').trim();
          if (trimmed.length === 0) { return fallback; }
          if (/^-?\\d+(\\.\\d+)?(px)?$/.test(trimmed)) {
            return Number.parseFloat(trimmed);
          }
          return fallback;
        }

        function stylePixelValue(element, key, fallback) {
          return numericPixelValue(element.style.getPropertyValue(key), fallback);
        }

        function isAbsoluteChild(element) {
          return element.parentElement &&
            element.parentElement.getAttribute('data-og-layout') === 'absolute';
        }

        function dragStartValue(element, key, absoluteFallback) {
          return stylePixelValue(element, key, isAbsoluteChild(element) ? absoluteFallback : 0);
        }

        function pixelString(value) {
          const rounded = Math.round(value * 10) / 10;
          const normalized = Math.abs(rounded) < 0.05 ? 0 : rounded;
          return normalized + 'px';
        }

        function updateDraggedElementPosition(drag, event) {
          const deltaX = event.clientX - drag.startClientX;
          const deltaY = event.clientY - drag.startClientY;
          const nextX = drag.startX + deltaX;
          const nextY = drag.startY + deltaY;
          drag.element.style.setProperty('--og-x', pixelString(nextX));
          drag.element.style.setProperty('--og-y', pixelString(nextY));
          drag.didMove = true;
        }

        function beginPendingDrag(event) {
          if (activeTool !== 'select' || event.button !== primaryPointerButton) { return; }
          const element = editableElementFromTarget(event.target);
          if (!element) { return; }

          const chain = selectableChainFor(element);
          const dragElement = draggableElementForChain(chain);
          if (!dragElement) { return; }

          pendingDrag = {
            pointerID: event.pointerId,
            element: dragElement,
            selectedID: elementID(dragElement),
            startClientX: event.clientX,
            startClientY: event.clientY
          };
          event.preventDefault();
          event.stopPropagation();
        }

        function startActiveDragIfNeeded(event) {
          if (!pendingDrag || pendingDrag.pointerID !== event.pointerId) { return false; }
          const deltaX = event.clientX - pendingDrag.startClientX;
          const deltaY = event.clientY - pendingDrag.startClientY;
          if (Math.hypot(deltaX, deltaY) < dragStartThreshold) { return false; }

          const element = pendingDrag.element;
          const selectedID = pendingDrag.selectedID;
          activeDrag = {
            pointerID: pendingDrag.pointerID,
            element: element,
            selectedID: selectedID,
            startClientX: pendingDrag.startClientX,
            startClientY: pendingDrag.startClientY,
            startX: dragStartValue(element, '--og-x', element.offsetLeft || 0),
            startY: dragStartValue(element, '--og-y', element.offsetTop || 0),
            didMove: false
          };
          pendingDrag = null;
          suppressNextClick = true;
          selectNode(selectedID);
          notifySelection(selectedID);
          return true;
        }

        function updateActiveDrag(event) {
          if (!activeDrag || activeDrag.pointerID !== event.pointerId) { return false; }
          if ((event.buttons & pointerDragButtons) === 0) {
            finishActiveDrag(false);
            return false;
          }

          updateDraggedElementPosition(activeDrag, event);
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function finishActiveDrag(cancelled) {
          pendingDrag = null;
          const drag = activeDrag;
          activeDrag = null;
          if (!drag || !drag.didMove || cancelled) { return; }
          collectNodes();
          notifyDocumentChange(drag.selectedID);
        }

        function copyPayload() {
          const element = selectedElement();
          if (!element) {
            return { html: '', text: '' };
          }
        return {
          html: element.outerHTML,
          text: (element.textContent || '').trim(),
          cssVariables: cssVariables(element)
        };
      }

        function replaceDocumentHTML(html, selectedID) {
          const parsedDocument = new DOMParser().parseFromString(html || '', 'text/html');
          if (!parsedDocument || !parsedDocument.documentElement) {
            return false;
          }

          pendingDrag = null;
          activeDrag = null;
          editingTextElement = null;
          editingOriginalText = '';
          const nextRoot = document.importNode(parsedDocument.documentElement, true);
          document.documentElement.replaceWith(nextRoot);
          currentSelectedID = '';
          collectNodes();

          if (selectedID && nodeWithID(selectedID)) {
            selectNode(selectedID);
            notifySelection(selectedID);
          } else {
            notifySelection('');
          }

          postScrollState(emptyScrollState(false));
          return true;
        }

        function runCommand(command, payload) {
          const element = selectedElement();
          if (!element && command !== 'pasteHere') {
            return { success: false, selectedID: '' };
        }

        let selectedID = element ? element.getAttribute('data-og-id') || '' : '';
        const isLocked = element && element.getAttribute('data-og-locked') === 'true';
        if (isLocked && command !== 'toggleLocked') {
          return { success: false, selectedID: selectedID };
        }

        if (command === 'pasteHere') {
          if (!element) { return { success: false, selectedID: '' }; }
            const fragment = fragmentFromPayload(payload || {});
            selectedID = firstEditableID(fragment);
            if (canReceiveChildren(element)) {
              element.append(fragment);
            } else {
              element.after(fragment);
            }
          } else if (command === 'pasteReplace') {
            const fragment = fragmentFromPayload(payload || {});
            selectedID = firstEditableID(fragment);
            element.replaceWith(fragment);
          } else if (command === 'delete') {
            const parentEditable = element.parentElement ? element.parentElement.closest('[data-og-id]') : null;
            selectedID = parentEditable ? parentEditable.getAttribute('data-og-id') || '' : '';
            element.remove();
          } else if (command === 'moveFront') {
            element.parentElement.appendChild(element);
          } else if (command === 'moveBack') {
            element.parentElement.insertBefore(element, element.parentElement.firstChild);
          } else if (command === 'wrapFrame') {
            const frame = document.createElement('Frame');
            selectedID = createFrameID();
            frame.setAttribute('data-og-id', selectedID);
            frame.setAttribute('data-og-type', 'frame');
            frame.setAttribute('data-og-layout', 'vertical');
            frame.style.setProperty('--og-gap', '0');
            frame.style.setProperty('--og-padding', '0');
            element.before(frame);
            frame.append(element);
          } else if (command === 'ungroup') {
            const children = Array.from(element.childNodes);
            if (children.length === 0) { return { success: false, selectedID: selectedID }; }
            const firstChild = children.find((child) => child.nodeType === Node.ELEMENT_NODE && child.hasAttribute('data-og-id'));
            selectedID = firstChild ? firstChild.getAttribute('data-og-id') || '' : '';
            children.forEach((child) => element.parentElement.insertBefore(child, element));
            element.remove();
        } else if (command === 'setLayout') {
          selectedID = setLayout((payload && payload.layout) || 'vertical');
        } else if (command === 'pasteCSSVariables') {
          Object.entries(payload || {}).forEach(([key, value]) => {
            if (key.indexOf('--og-') !== 0) { return; }
            if ((value || '').trim().length === 0) {
              element.style.removeProperty(key);
            } else {
              element.style.setProperty(key, value);
            }
          });
        } else if (command === 'toggleHidden') {
          if (element.getAttribute('data-og-hidden') === 'true') {
            element.removeAttribute('data-og-hidden');
          } else {
            element.setAttribute('data-og-hidden', 'true');
          }
        } else if (command === 'toggleLocked') {
          if (element.getAttribute('data-og-locked') === 'true') {
            element.removeAttribute('data-og-locked');
          } else {
            element.setAttribute('data-og-locked', 'true');
          }
        } else if (command === 'flipHorizontal') {
          toggleScaleVariable(element, '--og-scale-x');
          } else if (command === 'flipVertical') {
            toggleScaleVariable(element, '--og-scale-y');
          } else {
            return { success: false, selectedID: selectedID };
          }

          collectNodes();
          if (selectedID) {
            selectNode(selectedID);
            notifySelection(selectedID);
          }
          return { success: true, selectedID: selectedID };
        }

        window.OpenGraphite = {
          collectNodes: collectNodes,
          selectNode: selectNode,
          setActiveTool: setActiveTool,
          setCSSVariable: setCSSVariable,
          setAttributeValue: setAttributeValue,
          copyPayload: copyPayload,
          replaceDocumentHTML: replaceDocumentHTML,
          runCommand: runCommand
        };

        document.addEventListener('pointerdown', function(event) {
          if (editingTextElement) {
            if (editingTextElement.contains(event.target)) { return; }
            finishTextEditing(false);
          }
          beginPendingDrag(event);
        }, activePointerOptions);

        document.addEventListener('pointermove', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
          if (!editingTextElement && (activeDrag || startActiveDragIfNeeded(event))) {
            updateActiveDrag(event);
          }
        }, activePointerOptions);

        document.addEventListener('pointerup', function(event) {
          if (activeDrag && activeDrag.pointerID === event.pointerId) {
            event.preventDefault();
            event.stopPropagation();
            finishActiveDrag(false);
            return;
          }
          if (pendingDrag && pendingDrag.pointerID === event.pointerId) {
            pendingDrag = null;
          }
        }, activePointerOptions);

        document.addEventListener('pointercancel', function(event) {
          if (activeDrag && activeDrag.pointerID === event.pointerId) {
            event.preventDefault();
            event.stopPropagation();
            finishActiveDrag(true);
          }
          if (pendingDrag && pendingDrag.pointerID === event.pointerId) {
            pendingDrag = null;
          }
        }, activePointerOptions);

        document.addEventListener('dragstart', function(event) {
          if (editingTextElement && editingTextElement.contains(event.target)) { return; }
          if (activeTool !== 'select' || !editableElementFromTarget(event.target)) { return; }
          event.preventDefault();
          event.stopPropagation();
        }, activePointerOptions);

        document.addEventListener('keydown', function(event) {
          const isReturnKey = event.key === 'Enter' || event.key === 'Return';
          const isComposing = event.isComposing || event.keyCode === 229;

          if (editingTextElement) {
            if (isComposing) { return; }

            if (event.key === 'Escape') {
              event.preventDefault();
              event.stopPropagation();
              finishTextEditing(true);
              return;
            }

            if (isReturnKey && !event.shiftKey && !event.altKey && !event.metaKey && !event.ctrlKey) {
              event.preventDefault();
              event.stopPropagation();
              finishTextEditing(false);
            }
            return;
          }

          if (activeTool !== 'select' || !isReturnKey) { return; }
          const element = selectedElement();
          if (!isTextElement(element) || hasLockedAncestor(element)) { return; }
          event.preventDefault();
          event.stopPropagation();
          beginTextEditing(element, true);
        }, { capture: true });

        document.addEventListener('focusout', function(event) {
          if (!editingTextElement || event.target !== editingTextElement) { return; }
          finishTextEditing(false);
        }, true);

        document.addEventListener('paste', function(event) {
          if (!editingTextElement || event.target !== editingTextElement) { return; }
          const text = event.clipboardData ? event.clipboardData.getData('text/plain') : '';
          if (text.length === 0) { return; }
          event.preventDefault();
          document.execCommand('insertText', false, text);
        }, true);

        document.addEventListener('mousemove', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
        }, passivePointerOptions);

        document.addEventListener('mouseleave', markPointerOutside, { capture: true });

        document.addEventListener('scroll', updateLastPointerScrollState, true);

        document.addEventListener('wheel', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
        }, passivePointerOptions);

        document.addEventListener('click', function(event) {
          if (suppressNextClick) {
            suppressNextClick = false;
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          if (editingTextElement && editingTextElement.contains(event.target)) { return; }
          if (activeTool !== 'select') { return; }
          const element = editableElementFromTarget(event.target);
          if (!element) { return; }
          event.preventDefault();
          event.stopPropagation();
          const id = nextSelectionIDForClick(element);
          selectNode(id);
          notifySelection(id);
          collectNodes();
        }, true);

        document.addEventListener('dblclick', function(event) {
          if (editingTextElement && editingTextElement.contains(event.target)) { return; }
          if (activeTool !== 'select') { return; }
          const element = editableElementFromTarget(event.target);
          if (!element) { return; }
          const textElement = textElementForEditing(element);
          if (!textElement) { return; }
          event.preventDefault();
          event.stopPropagation();
          suppressNextClick = false;
          beginTextEditing(textElement, true);
        }, true);

        document.addEventListener('contextmenu', function(event) {
          if (editingTextElement && editingTextElement.contains(event.target)) { return; }
          const element = editableElementFromTarget(event.target);
          if (!element) { return; }
          event.preventDefault();
          event.stopPropagation();
          const id = activeTool === 'select' ? nextSelectionIDForClick(element) : elementID(element);
          selectNode(id);
          notifySelection(id);
          collectNodes();
          window.webkit.messageHandlers.openGraphiteContextMenu.postMessage({
            id: id,
            x: event.clientX,
            y: event.clientY,
            candidates: layerCandidatesFor(element)
          });
        }, true);

      setTimeout(function() {
        collectNodes();
        postScrollState(emptyScrollState(false));
      }, 0);
    })();
    """
}
