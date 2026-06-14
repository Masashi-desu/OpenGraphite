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

/// 論理名（日本語）: OpenGraphiteコマンド対応WebView
/// 概要: `⌘C` と responder chain の `copy:` を OpenGraphite の選択ノードコピーへ接続する WKWebView です。
///
/// プロパティ:
/// - `copyCommandHandler`: OpenGraphite 専用コピーを実行し、処理できた場合に `true` を返す handler。
private final class OpenGraphiteCommandWebView: WKWebView {
    var copyCommandHandler: (() -> Bool)?

    /// 論理名（日本語）: WebView不透明判定
    /// 概要: WebKit の未描画期間に親キャンバス背景を透過表示するため、常に非不透明 view として扱います。
    override var isOpaque: Bool {
        false
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: WebKit が内部 scroll view を再構成した場合でも、読み込み中背景の透明化を維持します。
    override func layout() {
        super.layout()
        applyTransparentPreviewBackground()
    }

    /// 論理名（日本語）: ウィンドウ所属更新関数
    /// 処理概要: WebView が window 階層へ入ったタイミングで、読み込み前の背景を親キャンバスへ透過させます。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTransparentPreviewBackground()
    }

    /// 論理名（日本語）: キー相当処理関数
    /// 処理概要: `⌘C` を OpenGraphite 専用コピーへ流し、対象がない場合は標準 WebView 処理へ戻します。
    ///
    /// - Parameter event: 入力イベント。
    /// - Returns: OpenGraphite 側または WebView 側で処理できた場合は `true`。
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isCopyKeyEquivalent(event), copyCommandHandler?() == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// 論理名（日本語）: コピーアクション関数
    /// 処理概要: メニューなどから届く `copy:` action を OpenGraphite 専用コピーへ流します。
    ///
    /// - Parameter sender: action 送信元。
    @objc func copy(_ sender: Any?) {
        _ = copyCommandHandler?()
    }

    /// 論理名（日本語）: プレビュー背景透明化関数
    /// 処理概要: WKWebView と WebKit 内部の scroll / clip view 背景を透明にし、navigation 中の白背景露出を防ぎます。
    func applyTransparentPreviewBackground() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        underPageBackgroundColor = .clear
        makeScrollContainersTransparent(in: self)
    }

    /// 論理名（日本語）: プレビュー内容非表示関数
    /// 処理概要: CSS 未適用の provisional document が白く描画される期間、WebKit content を親キャンバスへ透過させます。
    func hidePreviewContentUntilStyled() {
        alphaValue = 0
    }

    /// 論理名（日本語）: プレビュー内容表示関数
    /// 処理概要: OpenGraphite CSS 適用後の document だけをユーザーへ表示します。
    func revealStyledPreviewContent() {
        alphaValue = 1
    }

    /// 論理名（日本語）: スクロールコンテナ透明化関数
    /// 処理概要: macOS 版 WKWebView の非公開 view 階層を型だけでたどり、公開 AppKit API で背景描画を無効化します。
    ///
    /// - Parameter root: 透明化対象の探索を開始する view。
    private func makeScrollContainersTransparent(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
        }

        if let clipView = root as? NSClipView {
            clipView.drawsBackground = false
            clipView.backgroundColor = .clear
        }

        root.subviews.forEach { subview in
            makeScrollContainersTransparent(in: subview)
        }
    }

    /// 論理名（日本語）: コピーショートカット判定関数
    /// 処理概要: 入力イベントが `⌘C` のキー相当かを判定します。
    ///
    /// - Parameter event: 入力イベント。
    /// - Returns: `⌘C` であれば `true`。
    private func isCopyKeyEquivalent(_ event: NSEvent) -> Bool {
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return relevantModifiers == .command
            && event.charactersIgnoringModifiers?.lowercased() == "c"
    }
}

/// 論理名（日本語）: Webキャンバスビュー
/// 概要: HTML 正本を WKWebView で表示し、DOM 選択、Inspector 変更、コンテキストメニュー操作を SwiftUI へ接続します。
///
/// プロパティ:
/// - `store`: エディター状態を保持するストア。
/// - `pageURL`: 表示する HTML ファイル URL。未指定時は選択中ページを使います。
/// - `pageInternalID`: 表示している page card の内部 ID。
/// - `syncTarget`: 保存対象 HTML の object identity と固定 URL。
/// - `isInteractive`: DOM 収集、選択、編集同期を有効にするか。
/// - `reloadToken`: 外部変更で同じ URL を再読み込みするためのトークン。
/// - `previewContext`: エディター内 preview に注入する runtime Mock State。
/// - `allowsComponentPlacements`: component placement の preview clone 展開を許可するか。
struct WebCanvasView: NSViewRepresentable {
    @ObservedObject var store: EditorStore
    var pageURL: URL?
    var pageInternalID: String?
    var syncTarget: HTMLSyncTarget?
    var isInteractive = true
    var reloadToken = 0
    var previewContext: OpenGraphitePreviewContext = .empty
    var allowsComponentPlacements = false

    /// 論理名（日本語）: コーディネーター生成関数
    /// 処理概要: WKWebView の navigation、script message、context menu を処理するコーディネーターを生成します。
    ///
    /// - Returns: WebCanvasView 用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, isInteractive: isInteractive, pageInternalID: pageInternalID)
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
        userContentController.add(context.coordinator, name: "openGraphiteTextEditing")
        userContentController.add(context.coordinator, name: "openGraphiteStaticFlowLinks")
        userContentController.add(context.coordinator, name: "openGraphiteStaticFlowHover")
        Self.installUserScripts(
            on: userContentController,
            previewContext: previewContext,
            allowsComponentPlacements: allowsComponentPlacements
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        let webView = OpenGraphiteCommandWebView(frame: .zero, configuration: configuration)
        webView.applyTransparentPreviewBackground()
        webView.hidePreviewContentUntilStyled()
        webView.copyCommandHandler = { [weak coordinator = context.coordinator] in
            coordinator?.copySelectionForCommand() ?? false
        }
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.lastPreviewContext = previewContext
        context.coordinator.lastAllowsComponentPlacements = allowsComponentPlacements
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
        let becameInteractive = !context.coordinator.isInteractive && isInteractive
        context.coordinator.store = store
        context.coordinator.isInteractive = isInteractive
        context.coordinator.pageInternalID = pageInternalID
        context.coordinator.syncTarget = syncTarget

        let previewContextChanged = context.coordinator.lastPreviewContext != previewContext
        let componentPlacementModeChanged = context.coordinator.lastAllowsComponentPlacements != allowsComponentPlacements
        if previewContextChanged || componentPlacementModeChanged {
            Self.installUserScripts(
                on: webView.configuration.userContentController,
                previewContext: previewContext,
                allowsComponentPlacements: allowsComponentPlacements
            )
            context.coordinator.lastPreviewContext = previewContext
            context.coordinator.lastAllowsComponentPlacements = allowsComponentPlacements
        }

        let targetPageURL = syncTarget?.htmlURL ?? pageURL ?? store.selectedPageURL
        if let targetPageURL {
            let loadedURLChanged = context.coordinator.loadedURL != targetPageURL
            let reloadTokenChanged = context.coordinator.lastReloadToken != reloadToken
            if loadedURLChanged || reloadTokenChanged || previewContextChanged || componentPlacementModeChanged {
                context.coordinator.loadedURL = targetPageURL
                context.coordinator.lastReloadToken = reloadToken
                context.coordinator.lastSelectedNodeID = nil
                context.coordinator.hidePreviewUntilStyled()
                if loadedURLChanged || webView.url == nil {
                    let readAccessURL = store.projectRootURL ?? targetPageURL.deletingLastPathComponent()
                    webView.loadFileURL(targetPageURL, allowingReadAccessTo: readAccessURL)
                } else {
                    webView.reloadFromOrigin()
                }
            }
        }

        if pageURL == nil, targetPageURL == nil {
            context.coordinator.loadedURL = nil
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.lastSelectedNodeID = nil
        }

        guard isInteractive else {
            if context.coordinator.lastSelectedNodeID != nil {
                context.coordinator.lastSelectedNodeID = nil
                context.coordinator.selectNode(nil)
            }
            return
        }

        if becameInteractive {
            context.coordinator.collectNodes()
            context.coordinator.lastSelectedNodeID = nil
            context.coordinator.lastActiveTool = nil
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
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedMutationSequence != mutation.sequence {
            context.coordinator.applyMutation(mutation)
        }

        if let mutation = store.attributeMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedAttributeMutationSequence != mutation.sequence {
            context.coordinator.applyAttributeMutation(mutation)
        }

        if let mutation = store.textMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedTextMutationSequence != mutation.sequence {
            context.coordinator.applyTextMutation(mutation)
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
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteTextEditing")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteStaticFlowLinks")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteStaticFlowHover")
        WebScrollStateRegistry.shared.remove(for: nsView)
    }

    /// 論理名（日本語）: WebViewユーザースクリプト設定関数
    /// 処理概要: preview Mock State 注入 script と編集 bridge script を読み込み順に登録します。
    ///
    /// - Parameters:
    ///   - userContentController: script を保持する WKUserContentController。
    ///   - previewContext: preview に注入する runtime Mock State。
    private static func installUserScripts(
        on userContentController: WKUserContentController,
        previewContext: OpenGraphitePreviewContext,
        allowsComponentPlacements: Bool
    ) {
        userContentController.removeAllUserScripts()
        userContentController.addUserScript(
            WKUserScript(
                source: previewContextScript(for: previewContext),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        if allowsComponentPlacements {
            userContentController.addUserScript(
                WKUserScript(
                    source: componentPlacementReferencesScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
        }
        userContentController.addUserScript(
            WKUserScript(
                source: bridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
    }

    /// 論理名（日本語）: プレビューContext注入スクリプト生成関数
    /// 処理概要: HTML document metadata と `.ogp` の Mock State を preview 用 JS と HTML 属性へ反映します。
    ///
    /// - Parameter previewContext: preview に注入する runtime Mock State。
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
          if (!Object.prototype.hasOwnProperty.call(window, '__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__')) {
            Object.defineProperty(window, '__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__', {
              configurable: false,
              enumerable: false,
              value: Object.freeze({
                hasLang: document.documentElement.hasAttribute('lang'),
                lang: document.documentElement.getAttribute('lang') || '',
                hasDir: document.documentElement.hasAttribute('dir'),
                dir: document.documentElement.getAttribute('dir') || ''
              })
            });
          }
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

          function applyPlacementModeState(root, host, fields) {
            const mode = String((fields && fields.placementMode) || host.getAttribute('data-og-placement-mode') || '').trim();
            if (!mode) { return; }
            const stateTokens = mode.split(/\\s+/).filter((token) => /^[A-Za-z0-9_-]+$/.test(token));
            stateTokens.forEach((token) => {
              root.querySelectorAll('[data-og-state-hidden~="' + token + '"]').forEach((node) => {
                node.setAttribute('data-og-hidden', 'true');
              });
              root.querySelectorAll('[data-og-state-visible~="' + token + '"]').forEach((node) => {
                node.setAttribute('data-og-hidden', 'false');
              });
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

          function renderComponentPlacementReferences() {
            const hosts = placementHosts();
            hosts.forEach(clearGeneratedPlacementContent);
            hosts.forEach((host) => {
              const source = sourceNodeFor(host);
              if (!source) { return; }
              const clone = source.cloneNode(true);
              const fields = mockFieldsFor(host);
              applyPlacementFrameSizing(clone, host);
              applyCodeViewerMode(clone, fields);
              applyPlacementModeState(clone, host, fields);
              markGenerated(clone, host);
              host.appendChild(clone);
            });
          }

          window.OpenGraphiteComponentPlacementReferences = Object.freeze({
            render: renderComponentPlacementReferences
          });
          renderComponentPlacementReferences();
        })();
        """

    /// 論理名（日本語）: Webキャンバスコーディネーター
    /// 概要: WKWebView と SwiftUI ストアの間で JavaScript bridge、HTML 永続化、context menu を仲介します。
    ///
    /// プロパティ:
    /// - `store`: エディター状態ストア。
    /// - `webView`: 管理対象の WKWebView。
    /// - `loadedURL`: 現在読み込み済みの HTML URL。
    /// - `pageInternalID`: 現在の WebView が対応する page card 内部 ID。
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        @MainActor var store: EditorStore
        weak var webView: WKWebView?
        var isInteractive: Bool
        var pageInternalID: String?
        var syncTarget: HTMLSyncTarget?
        var loadedURL: URL?
        var lastReloadToken = 0
        var lastSelectedNodeID: String?
        var lastActiveTool: CanvasTool?
        var lastPreviewContext = OpenGraphitePreviewContext.empty
        var lastAllowsComponentPlacements = false
        var lastAppliedMutationSequence = 0
        var lastAppliedAttributeMutationSequence = 0
        var lastAppliedTextMutationSequence = 0
        var lastAppliedDocumentReplacementSequence = 0
        private var previewReadinessGeneration = 0
        private static let htmlPasteboardType = NSPasteboard.PasteboardType("public.html")
        private static let nodeReferencePasteboardType = NSPasteboard.PasteboardType("dev.opengraphite.node-reference+json")
        private static let cssVariablesPasteboardType = NSPasteboard.PasteboardType("dev.opengraphite.css-variables")
        private static let webKitErrorDomain = "WebKitErrorDomain"
        private static let frameLoadInterruptedErrorCode = 102

        /// 論理名（日本語）: コーディネーター初期化関数
        /// 処理概要: WebView ブリッジで更新するエディター状態ストアを保持します。
        ///
        /// - Parameters:
        ///   - store: 連携対象のエディター状態ストア。
        ///   - isInteractive: DOM 収集、選択、編集同期を有効にするか。
        ///   - pageInternalID: WebView が表示する page card の内部 ID。
        init(store: EditorStore, isInteractive: Bool, pageInternalID: String?) {
            self.store = store
            self.isInteractive = isInteractive
            self.pageInternalID = pageInternalID
        }

        /// 論理名（日本語）: Navigationエラー抑止判定関数
        /// 処理概要: 外部変更同期や同一URL再読み込みで発生する正常な中断をユーザー表示から除外します。
        ///
        /// - Parameter error: WebKit から渡された navigation error。
        /// - Returns: 一時的な navigation 中断として無視できる場合は true。
        static func shouldSuppressNavigationError(_ error: Error) -> Bool {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return true
            }

            if nsError.domain == webKitErrorDomain, nsError.code == frameLoadInterruptedErrorCode {
                return true
            }

            return false
        }

        /// 論理名（日本語）: 暫定プレビュー非表示関数
        /// 処理概要: navigation または document 全体置換の開始時に WebKit content を隠し、古い readiness 判定を無効化します。
        func hidePreviewUntilStyled() {
            previewReadinessGeneration += 1
            (webView as? OpenGraphiteCommandWebView)?.hidePreviewContentUntilStyled()
        }

        /// 論理名（日本語）: Script Message受信関数
        /// 処理概要: JavaScript から届くノード一覧、選択、context menu、スクロール状態、ドキュメント変更通知をストアへ反映します。
        ///
        /// - Parameters:
        ///   - userContentController: メッセージ送信元の user content controller。
        ///   - message: JavaScript bridge から届いたメッセージ。
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard isInteractive
                    || message.name == "openGraphiteScrollState"
                    || message.name == "openGraphiteStaticFlowLinks"
                    || message.name == "openGraphiteStaticFlowHover"
            else {
                return
            }

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

            if message.name == "openGraphiteDocumentChange", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    guard let target = syncTarget else { return }
                    let result = store.applyHTMLObjectEditPayload(payload, target: target)
                    if result.updated {
                        if let selectedID = payload["selectedID"] as? String, !selectedID.isEmpty {
                            store.selectNode(id: selectedID)
                        }
                        if result.requiresReload {
                            reloadCurrentPageFromDisk()
                        } else {
                            collectNodes()
                        }
                    } else {
                        reloadCurrentPageFromDisk()
                    }
                }
            }

            if message.name == "openGraphiteTextEditing", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    store.ingestTextEditingPayload(payload)
                }
            }

            if message.name == "openGraphiteStaticFlowLinks", let payload = message.body as? [[String: Any]] {
                Task { @MainActor in
                    guard let loadedURL else { return }
                    store.ingestStaticFlowLinkPayload(payload, pageURL: loadedURL, pageInternalID: pageInternalID)
                }
            }

            if message.name == "openGraphiteStaticFlowHover", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    guard let loadedURL else { return }
                    store.ingestStaticFlowSourceHoverPayload(payload, pageURL: loadedURL, pageInternalID: pageInternalID)
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
            renderLocalComponentReferences(in: webView)
            renderComponentPlacements(in: webView) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.finishPreviewLoad(in: webView)
            }
        }

        /// 論理名（日本語）: Preview読み込み後処理関数
        /// 処理概要: 生成DOMの反映後に preview 表示、静的リンク収集、編集状態の再適用を行います。
        ///
        /// - Parameter webView: 読み込み完了後の WebView。
        private func finishPreviewLoad(in webView: WKWebView) {
            revealPreviewWhenDocumentIsStyled(in: webView)
            collectStaticFlowLinks()
            guard isInteractive else { return }
            ensureInternalIDsAndCollectNodes()
            Task { @MainActor in
                setActiveTool(store.activeTool)
                selectNode(store.selectedNodeID)
            }
        }

        /// 論理名（日本語）: ローカルcomponent参照レンダリング関数
        /// 処理概要: `file://` の component master を Swift 側で読み、runtime に渡して WKWebView の file URL 制約を補完します。
        ///
        /// - Parameter webView: component 参照を展開する WebView。
        private func renderLocalComponentReferences(in webView: WKWebView) {
            let discoveryScript = """
            (function() {
              return {
                componentHrefs: Array.from(document.querySelectorAll('link[rel="opengraphite-components"][href]')).map((link) => link.href),
                runtimeLoaded: !!(window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function'),
                runtimeHrefs: Array.from(document.querySelectorAll('script[src*="OpenGraphite.runtime.js"]')).map((script) => script.src)
              };
            })();
            """

            webView.evaluateJavaScript(discoveryScript) { [weak self, weak webView] result, _ in
                guard let self, let webView, let payload = result as? [String: Any] else { return }
                let componentHrefs = payload["componentHrefs"] as? [String] ?? []
                let componentHTMLs = self.localTextDocuments(from: componentHrefs)
                guard !componentHTMLs.isEmpty else { return }

                let runtimeLoaded = payload["runtimeLoaded"] as? Bool ?? false
                let runtimeHrefs = payload["runtimeHrefs"] as? [String] ?? []
                let runtimeSource = self.localTextDocuments(from: runtimeHrefs).first
                guard runtimeLoaded || runtimeSource != nil else { return }

                let htmlArray = componentHTMLs
                    .map(Self.javaScriptLiteral)
                    .joined(separator: ",")
                let renderScript = """
                (function() {
                  \(runtimeSource ?? "")
                  if (window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function') {
                    window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(htmlArray)]);
                    return true;
                  }
                  return false;
                })();
                """

                webView.evaluateJavaScript(renderScript) { [weak self] result, _ in
                    guard let self, (result as? Bool) == true else { return }
                    self.renderComponentPlacements(in: webView) { [weak self, weak webView] in
                        guard let self, let webView else { return }
                        self.finishPreviewLoad(in: webView)
                    }
                }
            }
        }

        /// 論理名（日本語）: Component Placement再描画関数
        /// 処理概要: WebView 内の placement host へ source node clone と placement-local state を反映します。
        ///
        /// - Parameters:
        ///   - webView: placement を展開する WebView。
        ///   - completion: 展開試行後に main thread で実行する処理。
        private func renderComponentPlacements(in webView: WKWebView, completion: (() -> Void)? = nil) {
            let script = """
            (function() {
              if (window.OpenGraphiteComponentPlacementReferences &&
                  typeof window.OpenGraphiteComponentPlacementReferences.render === 'function') {
                window.OpenGraphiteComponentPlacementReferences.render();
                return true;
              }
              return false;
            })();
            """
            webView.evaluateJavaScript(script) { _, _ in
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }

        /// 論理名（日本語）: ローカルtext文書読み込み関数
        /// 処理概要: JS から得た href のうち `file://` URL だけを UTF-8 text として読み込みます。
        ///
        /// - Parameter hrefs: component link や runtime script の href 一覧。
        /// - Returns: 読み込みに成功した text document 一覧。
        private func localTextDocuments(from hrefs: [String]) -> [String] {
            hrefs.compactMap { href -> String? in
                guard let url = URL(string: href), url.isFileURL else { return nil }
                return try? String(contentsOf: url, encoding: .utf8)
            }
        }

        /// 論理名（日本語）: WebViewノード収集関数
        /// 処理概要: 表示中 DOM から OpenGraphite node graph を JavaScript bridge 経由で再収集します。
        func collectNodes() {
            webView?.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.collectNodes();")
        }

        /// 論理名（日本語）: 内部ID補完後ノード収集関数
        /// 処理概要: HTML ノード内部 ID を補完し、補完が発生した場合は正本 HTML へ同期してからノード一覧を収集します。
        private func ensureInternalIDsAndCollectNodes() {
            guard let webView else { return }
            webView.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.ensureInternalIDs();") { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("内部IDの補完に失敗しました: \(error.localizedDescription)")
                        self.collectNodes()
                        return
                    }

                    if (result as? Bool) == true {
                        self.serializeAndSyncHTML {
                            self.collectNodes()
                        }
                    } else {
                        self.collectNodes()
                    }
                }
            }
        }

        /// 論理名（日本語）: WebView静的フローリンク収集関数
        /// 処理概要: 表示中 DOM の静的リンク要素と viewport 矩形を JavaScript bridge 経由で再収集します。
        func collectStaticFlowLinks() {
            webView?.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.collectStaticFlowLinks();")
        }

        /// 論理名（日本語）: WebView暫定読み込み開始関数
        /// 処理概要: WebKit が provisional document を描画する前に content を隠し、白背景の露出を抑止します。
        ///
        /// - Parameters:
        ///   - webView: 読み込み開始対象の WebView。
        ///   - navigation: 開始した provisional navigation。
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            hidePreviewUntilStyled()
        }

        /// 論理名（日本語）: WebViewコミット開始関数
        /// 処理概要: レスポンスが main frame に反映される境界でも content を隠した状態を維持します。
        ///
        /// - Parameters:
        ///   - webView: 読み込み中の WebView。
        ///   - navigation: コミットされた navigation。
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            (webView as? OpenGraphiteCommandWebView)?.hidePreviewContentUntilStyled()
        }

        /// 論理名（日本語）: WebView読み込み失敗関数
        /// 処理概要: 確定後 navigation の失敗をエディターのエラー表示へ転送します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みに失敗した WebView。
        ///   - navigation: 失敗した navigation。
        ///   - error: WebKit から渡されたエラー。
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !Self.shouldSuppressNavigationError(error) else { return }
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
            guard !Self.shouldSuppressNavigationError(error) else { return }
            Task { @MainActor in
                store.reportWebError("HTMLの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }

        /// 論理名（日本語）: スタイル適用後プレビュー表示関数
        /// 処理概要: OpenGraphite CSS が page root へ適用されたことを確認してから WebKit content を表示します。
        ///
        /// - Parameters:
        ///   - webView: 表示判定対象の WebView。
        ///   - generation: 判定開始時点の readiness 世代。省略時は現在世代を使います。
        ///   - attempt: 再試行回数。
        private func revealPreviewWhenDocumentIsStyled(
            in webView: WKWebView,
            generation: Int? = nil,
            attempt: Int = 0
        ) {
            let generation = generation ?? previewReadinessGeneration
            webView.evaluateJavaScript(Self.previewReadinessScript) { [weak self, weak webView] result, _ in
                guard let self, let webView else { return }
                let isReady = (result as? Bool) == true
                DispatchQueue.main.async {
                    guard self.previewReadinessGeneration == generation else { return }
                    if isReady {
                        (webView as? OpenGraphiteCommandWebView)?.revealStyledPreviewContent()
                    } else if attempt < Self.previewReadinessMaximumAttempts {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewReadinessRetryInterval) { [weak self, weak webView] in
                            guard let self, let webView else { return }
                            self.revealPreviewWhenDocumentIsStyled(
                                in: webView,
                                generation: generation,
                                attempt: attempt + 1
                            )
                        }
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: WebViewノード選択関数
        /// 処理概要: Swift 側の選択 ID を JavaScript bridge 経由で DOM の選択表示へ反映します。
        ///
        /// - Parameter id: 選択する node ID。placement clone 内では表示専用の合成 ID、選択解除時は `nil`。
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
                        self.store.markMutationApplied(sequence: mutation.sequence)
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
                        self.store.markAttributeMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: テキストmutation反映関数
        /// 処理概要: Inspector で更新された text content を DOM へ適用し、成功時に mutation を完了扱いにします。
        ///
        /// - Parameter mutation: 反映対象の text mutation。
        func applyTextMutation(_ mutation: NodeTextContentMutation) {
            guard let webView else { return }
            lastAppliedTextMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setTextContent(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.value)),
              \(Self.javaScriptLiteral(mutation.mode.rawValue))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("テキストの反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markTextMutationApplied(sequence: mutation.sequence)
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
            hidePreviewUntilStyled()

            let script = """
            window.OpenGraphite && window.OpenGraphite.replaceDocumentHTML(
              \(Self.javaScriptLiteral(request.html)),
              \(Self.javaScriptLiteral(request.selectedNodeID ?? ""))
            );
            """

            webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました: \(error.localizedDescription)")
                        self.reloadCurrentPageFromDisk()
                    } else if (result as? Bool) != true {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました。")
                        self.reloadCurrentPageFromDisk()
                    } else if let webView {
                        self.renderLocalComponentReferences(in: webView)
                        self.renderComponentPlacements(in: webView) { [weak self, weak webView] in
                            guard let self, let webView else { return }
                            self.finishPreviewLoad(in: webView)
                        }
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
            guard let webView, let target = syncTarget else { return }

            let script = """
            (function() {
              const editorStyleSelector = '#opengraphite-editor-selection-style';
              function removeEditorStyles(root) {
                if (!root || typeof root.querySelectorAll !== 'function') { return; }
                root.querySelectorAll(editorStyleSelector).forEach((element) => {
                  element.remove();
                });
              }
              function removePreviewContextAttributes(root) {
                if (!root || typeof root.removeAttribute !== 'function') { return; }
                root.removeAttribute('data-og-preview-locale');
                root.removeAttribute('data-og-preview-dir');
              }
              function removePlacementGeneratedNodes(root) {
                if (!root || typeof root.querySelectorAll !== 'function') { return; }
                root.querySelectorAll('[data-og-placement-generated="true"]').forEach((element) => {
                  element.remove();
                });
              }
              function restorePreviewDocumentAttributes(root) {
                if (!root || typeof root.removeAttribute !== 'function') { return; }
                const original = window.__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__;
                if (!original || typeof original !== 'object') { return; }
                if (original.hasLang === true) {
                  root.setAttribute('lang', typeof original.lang === 'string' ? original.lang : '');
                } else {
                  root.removeAttribute('lang');
                }
                if (original.hasDir === true) {
                  root.setAttribute('dir', typeof original.dir === 'string' ? original.dir : '');
                } else {
                  root.removeAttribute('dir');
                }
              }
              if (window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.serializeDocument === 'function') {
                const html = window.OpenGraphiteRuntime.serializeDocument();
                const parsedDocument = new DOMParser().parseFromString(html || '', 'text/html');
                removeEditorStyles(parsedDocument);
                if (!parsedDocument.documentElement) { return html; }
                removePlacementGeneratedNodes(parsedDocument);
                removePreviewContextAttributes(parsedDocument.documentElement);
                restorePreviewDocumentAttributes(parsedDocument.documentElement);
                return '<!doctype html>\\n' + parsedDocument.documentElement.outerHTML;
              }
              const clone = document.documentElement.cloneNode(true);
              removeEditorStyles(clone);
              removePlacementGeneratedNodes(clone);
              removePreviewContextAttributes(clone);
              restorePreviewDocumentAttributes(clone);
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
                        if self.store.syncHTML(html, target: target) {
                            onSuccess()
                        } else {
                            self.reloadCurrentPageFromDisk()
                        }
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
            hidePreviewUntilStyled()
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

        private static let previewReadinessMaximumAttempts = 120
        private static let previewReadinessRetryInterval: TimeInterval = 1.0 / 60.0
        private static let previewReadinessScript = """
        (function() {
          const page = document.querySelector('[data-og-role="page-preview"], [data-og-type="page"]');
          if (!document.body || !page) { return false; }
          const bodyStyle = window.getComputedStyle(document.body);
          const pageStyle = window.getComputedStyle(page);
          const rect = page.getBoundingClientRect();
          const viewportWidth = document.documentElement.clientWidth || window.innerWidth || 0;
          const viewportHeight = document.documentElement.clientHeight || window.innerHeight || 0;
          const hasResetBodyMargin =
            bodyStyle.marginTop === '0px' &&
            bodyStyle.marginRight === '0px' &&
            bodyStyle.marginBottom === '0px' &&
            bodyStyle.marginLeft === '0px';
          const hasStyledPageDisplay = pageStyle.display !== 'inline';
          const fillsViewport =
            rect.width >= Math.max(1, viewportWidth - 1) &&
            rect.height >= Math.max(1, viewportHeight - 1);
          return hasResetBodyMargin && hasStyledPageDisplay && fillsViewport;
        })();
        """

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
            addMenuItem("参照IDをコピー", command: "copyReferenceID", to: copyOptions, enabled: selectedID != nil)
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
                copySelection(includeHTML: true, includeText: command == "copyHTML", includeReferenceID: command == "copy")
            case "copyReferenceID":
                copySelection(includeHTML: true, includeText: false, includeReferenceID: true)
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
        /// 論理名（日本語）: コマンドコピー処理関数
        /// 処理概要: `⌘C` や responder chain の `copy:` から通常コピーと同じ参照 ID 付き payload を作ります。
        /// 選択 node がない場合は選択 HTML カードの参照 ID をコピーします。
        ///
        /// - Returns: OpenGraphite の選択対象コピーとして処理できた場合は `true`。
        func copySelectionForCommand() -> Bool {
            guard isInteractive else { return false }
            guard store.selectedNodeID != nil else {
                return store.copySelectedReferenceIDToPasteboard()
            }
            copySelection(includeHTML: true, includeText: false, includeReferenceID: true)
            return true
        }

        @MainActor
        /// 論理名（日本語）: 選択内容コピー関数
        /// 処理概要: 選択中 DOM の HTML、テキスト、参照 ID、CSS 変数を pasteboard へ書き込みます。
        ///
        /// - Parameters:
        ///   - includeHTML: HTML をコピー対象に含めるか。
        ///   - includeText: テキストをコピー対象に含めるか。
        ///   - includeReferenceID: テキスト欄貼り付け用に複合参照 ID をコピー対象に含めるか。
        ///   - includeCSSVariables: CSS 変数をコピー対象に含めるか。
        private func copySelection(
            includeHTML: Bool,
            includeText: Bool,
            includeReferenceID: Bool = false,
            includeCSSVariables: Bool = false
        ) {
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
                    let nodeID = payload["id"] as? String ?? ""
                    let nodeInternalID = payload["internalID"] as? String ?? ""
                    let cssVariables = (payload["cssVariables"] as? [String: Any] ?? [:])
                        .compactMapValues { $0 as? String }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let referenceID = includeReferenceID
                        ? self.store.nodeReferenceID(forNodeID: nodeID, nodeInternalID: nodeInternalID)
                        : nil

                    if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: Self.htmlPasteboardType)
                    }

                    if let referenceID, !referenceID.isEmpty {
                        pasteboard.setString(referenceID, forType: .string)
                    } else if includeText, !text.isEmpty {
                        pasteboard.setString(text, forType: .string)
                    } else if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: .string)
                    }

                    if includeReferenceID,
                       let referencePayload = self.store.nodeReferencePasteboardPayload(
                        forNodeID: nodeID,
                        nodeInternalID: nodeInternalID,
                        html: html
                       ),
                       let data = try? JSONSerialization.data(withJSONObject: referencePayload),
                       let json = String(data: data, encoding: .utf8) {
                        pasteboard.setString(json, forType: Self.nodeReferencePasteboardType)
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

                    guard let target = self.syncTarget,
                          let editPayload = response["edit"] as? [String: Any]
                    else {
                        self.store.reportWebError("HTMLの保存形式が不正です。ページを再読み込みしてからもう一度設定してください。")
                        self.reloadCurrentPageFromDisk()
                        return
                    }

                    let editResult = self.store.applyHTMLObjectEditPayload(editPayload, target: target)
                    guard editResult.updated else {
                        self.reloadCurrentPageFromDisk()
                        return
                    }

                    if let selectedID = response["selectedID"] as? String, !selectedID.isEmpty {
                        self.store.selectNode(id: selectedID)
                    }

                    if editResult.requiresReload {
                        self.reloadCurrentPageFromDisk()
                    } else {
                        self.collectNodes()
                    }
                }
            }
        }

        /// 論理名（日本語）: pasteboard payload取得関数
        /// 処理概要: pasteboard から HTML またはテキストを読み取り、DOM コマンド用 payload に変換します。
        ///
        /// - Returns: 貼り付け可能な payload。空の場合は `nil`。
        private func pasteboardPayload() -> [String: String]? {
            let pasteboard = NSPasteboard.general
            if let json = pasteboard.string(forType: Self.nodeReferencePasteboardType),
               let data = json.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let html = object["html"] as? String,
               !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["html": html]
            }

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
          if (typeof window.OpenGraphite.installEditorSelectionStyle === 'function') {
            window.OpenGraphite.installEditorSelectionStyle();
          }
          window.OpenGraphite.collectNodes();
          return;
        }

        let currentSelectedID = '';
        let dragStartThreshold = 3;
        let pointerDragButtons = 1;
        let primaryPointerButton = 0;
        let selectionRevealPadding = 24;
        let passivePointerOptions = { capture: true, passive: true };
        let activePointerOptions = { capture: true, passive: false };
        var activeTool = 'select';
        var pendingDrag = null;
        var activeDrag = null;
        var reorderAnimationToken = 0;
        var editingTextElement = null;
        var editingOriginalText = '';
        var suppressNextClick = false;
        var clickSequenceStartSelectedID = '';

        function installEditorSelectionStyle() {
          if (document.getElementById('opengraphite-editor-selection-style')) { return; }
          const style = document.createElement('style');
          style.id = 'opengraphite-editor-selection-style';
          style.textContent = [
            'html,body{scroll-padding:24px;}',
            '[data-og-selected="true"]{scroll-margin:24px;}',
            '[data-og-selected="true"][data-og-component],',
            '[data-og-selected="true"][data-og-component-kind="master"]{outline-color:#8b5cf6!important;}',
            '[data-og-dragging="true"]{cursor:grabbing!important;filter:drop-shadow(0 14px 24px rgba(0,0,0,.28));position:relative;z-index:2147483647;}',
            '[data-og-reorder-dragging="true"]{pointer-events:none;transform:translate3d(var(--og-drag-x,0),var(--og-drag-y,0),0) scale(var(--og-scale-x,1),var(--og-scale-y,1))!important;transition:none!important;will-change:transform;}',
            '[data-og-reorder-animating="true"]{transform:translate3d(var(--og-reorder-x,0),var(--og-reorder-y,0),0) scale(var(--og-scale-x,1),var(--og-scale-y,1))!important;transition:transform 160ms cubic-bezier(.2,0,.2,1)!important;will-change:transform;}',
            '[data-og-reorder-preparing="true"]{transition:none!important;}'
          ].join('');
          (document.head || document.documentElement).appendChild(style);
        }

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
          if (parent.hasAttribute && parent.hasAttribute('data-og-id')) {
            count += 1;
          }
          parent = parent.parentElement;
        }
        return count;
      }

      function isPlacementGeneratedElement(element) {
        return !!(element && element.closest && element.closest('[data-og-placement-generated="true"]'));
      }

      function placementGeneratedRootForElement(element) {
        return element && element.closest ?
          element.closest('[data-og-placement-generated="true"][data-og-source-placement]') :
          null;
      }

      function allEditableNodes() {
        return Array.from(document.querySelectorAll('[data-og-id]')).filter((element) => {
          if (isPlacementGeneratedElement(element)) {
            return true;
          }
          const persistentPlacementRoot = element.closest('[data-og-role="component-placement"]');
          if (persistentPlacementRoot && persistentPlacementRoot !== element) {
            return false;
          }
          return !(element.tagName && element.tagName.toLowerCase() === 'og-instance' && element.hasAttribute('data-og-expanded'));
        });
      }

        function randomInternalID(used) {
          const bytes = new Uint8Array(6);
          let candidate = '';
          do {
            if (window.crypto && typeof window.crypto.getRandomValues === 'function') {
              window.crypto.getRandomValues(bytes);
              candidate = Array.from(bytes).map((byte) => byte.toString(16).padStart(2, '0')).join('');
            } else {
              candidate = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER).toString(36);
            }
          } while (!candidate || used.has(candidate));
          used.add(candidate);
          return candidate;
        }

        function isRuntimeGeneratedNode(element) {
          return element && (
            element.getAttribute('data-og-generated') === 'true' ||
            element.hasAttribute('data-og-source-component') ||
            !!element.closest('[data-og-generated="true"]')
          );
        }

        function ensureInternalIDs() {
          const used = new Set();
          let changed = false;
          allEditableNodes().forEach((element) => {
            if (isPlacementGeneratedElement(element)) { return; }
            const current = (element.getAttribute('data-og-internal-id') || '').trim();
            if (!current || used.has(current)) {
              element.setAttribute('data-og-internal-id', randomInternalID(used));
              if (!isRuntimeGeneratedNode(element)) {
                changed = true;
              }
            } else {
              used.add(current);
            }
          });
          return changed;
        }

        function nodeWithID(id) {
          return allEditableNodes().find((element) => {
            return selectionIDForElement(element) === id ||
              (!isPlacementGeneratedElement(element) && elementID(element) === id);
          });
        }

        function canScrollForSelection(element) {
          if (!element || typeof window.getComputedStyle !== 'function') { return false; }
          const style = window.getComputedStyle(element);
          const scrollableY = /(auto|scroll|overlay)/.test(style.overflowY || '');
          const scrollableX = /(auto|scroll|overlay)/.test(style.overflowX || '');
          const epsilon = 1;
          return (scrollableY && element.scrollHeight - element.clientHeight > epsilon) ||
            (scrollableX && element.scrollWidth - element.clientWidth > epsilon);
        }

        function selectionScrollContainers(element) {
          const containers = [];
          let current = element.parentElement;
          while (current && current !== document.documentElement) {
            if (canScrollForSelection(current)) {
              containers.push(current);
            }
            current = current.parentElement;
          }

          const root = document.scrollingElement || document.documentElement;
          if (root) {
            containers.push(root);
          }

          return Array.from(new Set(containers));
        }

        function viewportRectForSelectionContainer(container) {
          const root = document.scrollingElement || document.documentElement;
          if (container === root || container === document.documentElement || container === document.body) {
            return {
              top: 0,
              left: 0,
              right: document.documentElement.clientWidth || window.innerWidth || 0,
              bottom: document.documentElement.clientHeight || window.innerHeight || 0
            };
          }
          return container.getBoundingClientRect();
        }

        function revealDeltaForAxis(start, end, viewportStart, viewportEnd) {
          const paddedStart = viewportStart + selectionRevealPadding;
          const paddedEnd = viewportEnd - selectionRevealPadding;
          const available = Math.max(paddedEnd - paddedStart, 0);
          const size = Math.max(end - start, 0);

          if (size > available) {
            if (start < paddedStart) {
              return start - paddedStart;
            }
            if (end > paddedEnd && start > paddedStart) {
              return start - paddedStart;
            }
            return 0;
          }

          if (start < paddedStart) {
            return start - paddedStart;
          }
          if (end > paddedEnd) {
            return end - paddedEnd;
          }
          return 0;
        }

        function scrollSelectionContainer(container, deltaX, deltaY) {
          if (deltaX === 0 && deltaY === 0) { return; }
          const root = document.scrollingElement || document.documentElement;
          if (container === root || container === document.documentElement || container === document.body) {
            window.scrollBy(deltaX, deltaY);
            return;
          }
          container.scrollLeft += deltaX;
          container.scrollTop += deltaY;
        }

        function revealElementForSelection(element) {
          if (!element || typeof element.getBoundingClientRect !== 'function') { return; }
          selectionScrollContainers(element).forEach((container) => {
            const rect = element.getBoundingClientRect();
            const viewport = viewportRectForSelectionContainer(container);
            const deltaX = revealDeltaForAxis(rect.left, rect.right, viewport.left, viewport.right);
            const deltaY = revealDeltaForAxis(rect.top, rect.bottom, viewport.top, viewport.bottom);
            scrollSelectionContainer(container, deltaX, deltaY);
          });
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
          if (activeDrag) {
            finishActiveDrag(true);
          }
          activeTool = tool || 'select';
          pendingDrag = null;
        }

        function elementID(element) {
          return element ? element.getAttribute('data-og-id') || element.getAttribute('data-og-host-id') || '' : '';
        }

        function sourcePlacementIDForElement(element) {
          const generated = placementGeneratedRootForElement(element);
          if (!generated) { return ''; }
          const placementID = generated.getAttribute('data-og-source-placement') || '';
          return placementID;
        }

        function selectionIDForElement(element) {
          if (!element) { return ''; }
          const sourceID = elementID(element);
          if (!isPlacementGeneratedElement(element)) { return sourceID; }
          const placementID = sourcePlacementIDForElement(element);
          const stableNodeID = nodeInternalID(element) || sourceID;
          if (!placementID || !stableNodeID) { return sourceID; }
          return 'ogpl:' + encodeURIComponent(placementID) + ':' + encodeURIComponent(stableNodeID);
        }

        function sourceElementForPlacementGeneratedElement(element) {
          if (!isPlacementGeneratedElement(element)) { return element; }
          const internalID = nodeInternalID(element);
          const sourceID = elementID(element);
          return Array.from(document.querySelectorAll('[data-og-id]')).find((candidate) => {
            if (candidate === element || isPlacementGeneratedElement(candidate)) { return false; }
            if (internalID) {
              return nodeInternalID(candidate) === internalID;
            }
            return sourceID && elementID(candidate) === sourceID;
          }) || null;
        }

        function editElementForSelectionID(id) {
          const element = nodeWithID(id);
          if (!element) { return null; }
          return sourceElementForPlacementGeneratedElement(element) || element;
        }

        function editableElementFromTarget(target) {
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }
          if (!element) { return null; }
          return element.closest('[data-og-id]');
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

          const currentIndex = chain.findIndex((candidate) => selectionIDForElement(candidate) === currentSelectedID);
          if (currentIndex < 0) {
            return selectionIDForElement(chain[0]);
          }

          const nextIndex = Math.min(currentIndex + 1, chain.length - 1);
          return selectionIDForElement(chain[nextIndex]);
        }

        function elementInChain(chain, id) {
          if (!id) { return null; }
          return chain.find((candidate) => selectionIDForElement(candidate) === id) || null;
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
          return type !== 'page' && !isRuntimeGeneratedNode(element) && !hasLockedAncestor(element);
        }

        function isTextElement(element) {
          return element && (element.getAttribute('data-og-type') || '') === 'text';
        }

        function draggableElementForChain(chain) {
          const selected = elementInChain(chain, currentSelectedID);
          if (canDragElement(selected)) {
            return selected;
          }
          const reorderCandidate = reorderCandidateForChain(chain);
          if (reorderCandidate) {
            return reorderCandidate;
          }
          return chain.find(canDragElement) || null;
        }

        function textElementForEditing(element, selectedID) {
          const selectionBaselineID = typeof selectedID === 'string' ? selectedID : currentSelectedID;
          const chain = selectableChainFor(element);
          const selected = elementInChain(chain, selectionBaselineID);
          if (isTextElement(selected) && !hasLockedAncestor(selected)) {
            return selected;
          }
          return null;
        }

        function editingSelectionBaselineForClick(event) {
          if (!event || event.detail <= 1) {
            clickSequenceStartSelectedID = currentSelectedID;
            return currentSelectedID;
          }
          return clickSequenceStartSelectedID;
        }

        var staticFlowCollectionFrame = null;
        var currentStaticFlowHoverID = '';

        function staticFlowSelector() {
          return [
            'a[href]',
            '[data-og-type="button"][href]',
            '[data-og-type="button"][data-og-target]',
            '[data-og-type="button"][data-og-href]',
            '[data-og-type="button"][data-og-link]'
          ].join(',');
        }

        function staticFlowElements() {
          return Array.from(new Set(Array.from(document.querySelectorAll(staticFlowSelector()))));
        }

        function staticFlowTargetFor(element) {
          const rawTarget = [
            element.getAttribute('href'),
            element.getAttribute('data-og-target'),
            element.getAttribute('data-og-href'),
            element.getAttribute('data-og-link')
          ].find((value) => value && value.trim().length > 0) || '';
          if (!rawTarget) { return null; }

          let resolvedTarget = '';
          if (typeof element.href === 'string' && element.href.trim().length > 0) {
            resolvedTarget = element.href;
          } else {
            try {
              resolvedTarget = new URL(rawTarget, window.location.href).href;
            } catch (_) {
              resolvedTarget = rawTarget;
            }
          }

          return {
            raw: rawTarget,
            resolved: resolvedTarget
          };
        }

        function sourceLabelForStaticFlow(element, fallback) {
          const text = (element.innerText || element.textContent || '').trim().replace(/\\s+/g, ' ');
          if (text.length > 0) { return text; }
          return fallback || '';
        }

        function staticFlowPayloadItems() {
          return staticFlowElements().flatMap((element, index) => {
            const target = staticFlowTargetFor(element);
            if (!target) { return []; }

            const rect = element.getBoundingClientRect();
            if (!Number.isFinite(rect.x) || !Number.isFinite(rect.y) || rect.width <= 0 || rect.height <= 0) {
              return [];
            }

            const sourceNodeID = element.getAttribute('data-og-id') || element.id || '';
            const fallbackID = 'static-flow-' + index + '-' + target.raw;
            const id = (sourceNodeID || fallbackID) + ':' + target.raw;
            return [{
              element: element,
              payload: {
                id: id,
                sourceNodeID: sourceNodeID,
                sourceLabel: sourceLabelForStaticFlow(element, sourceNodeID),
                targetHref: target.raw,
                targetURL: target.resolved,
                x: rect.x,
                y: rect.y,
                width: rect.width,
                height: rect.height
              }
            }];
          });
        }

        function collectStaticFlowLinks() {
          const links = staticFlowPayloadItems().map((item) => item.payload);
          if (currentStaticFlowHoverID && !links.some((link) => link.id === currentStaticFlowHoverID)) {
            postStaticFlowHover(null);
          }
          window.webkit.messageHandlers.openGraphiteStaticFlowLinks.postMessage(links);
          return links;
        }

        function scheduleStaticFlowLinkCollection() {
          if (staticFlowCollectionFrame !== null) { return; }
          staticFlowCollectionFrame = window.requestAnimationFrame(function() {
            staticFlowCollectionFrame = null;
            collectStaticFlowLinks();
          });
        }

        function staticFlowElementFromTarget(target) {
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }
          return element ? element.closest(staticFlowSelector()) : null;
        }

        function staticFlowPayloadForElement(element) {
          if (!element) { return null; }
          const item = staticFlowPayloadItems().find((candidate) => candidate.element === element);
          return item ? item.payload : null;
        }

        function postStaticFlowHover(payload) {
          const id = payload ? payload.id || '' : '';
          if (id === currentStaticFlowHoverID) { return; }
          currentStaticFlowHoverID = id;
          window.webkit.messageHandlers.openGraphiteStaticFlowHover.postMessage(payload || {
            id: '',
            sourceNodeID: ''
          });
        }

        function updateStaticFlowHoverFromTarget(target) {
          const payload = staticFlowPayloadForElement(staticFlowElementFromTarget(target));
          postStaticFlowHover(payload);
        }

      function collectNodes() {
        if (window.OpenGraphiteComponentPlacementReferences && typeof window.OpenGraphiteComponentPlacementReferences.render === 'function') {
          window.OpenGraphiteComponentPlacementReferences.render();
          if (currentSelectedID) {
            selectNode(currentSelectedID);
          }
        }
        ensureInternalIDs();
        const nodes = allEditableNodes().map((element) => ({
          id: selectionIDForElement(element),
          internalID: element.getAttribute('data-og-internal-id') || '',
          tagName: element.tagName.toLowerCase(),
          type: element.getAttribute('data-og-type') || '',
          layout: element.getAttribute('data-og-layout') || '',
          role: element.getAttribute('data-og-role') || '',
          componentID: element.getAttribute('data-og-component') || '',
          componentKind: element.getAttribute('data-og-component-kind') || '',
          sourceComponentID: element.getAttribute('data-og-source-component') || '',
          sourceInstanceID: element.getAttribute('data-og-source-instance') || '',
          sourceNodeInternalID: element.getAttribute('data-og-source-node-internal-id') || '',
          sourceNodeID: isPlacementGeneratedElement(element) ? elementID(element) : '',
          sourcePlacementID: sourcePlacementIDForElement(element),
          placementGenerated: isPlacementGeneratedElement(element),
          textContent: editablePlainText(element),
          fallbackTextContent: fallbackPlainText(element),
          textSource: element.getAttribute('data-og-text-source') || '',
          i18nKey: element.getAttribute('data-i18n-key') || '',
          iconLibrary: element.getAttribute('data-og-icon-library') || '',
          iconName: element.getAttribute('data-og-icon-name') || '',
          iconSource: element.getAttribute('data-og-icon-source') || '',
          cssVariables: cssVariables(element),
          hidden: element.getAttribute('data-og-hidden') === 'true',
          locked: element.getAttribute('data-og-locked') === 'true',
          depth: depth(element)
        }));
        window.webkit.messageHandlers.openGraphiteNodes.postMessage(nodes);
        scheduleStaticFlowLinkCollection();
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
          revealElementForSelection(element);
          return true;
        }

        function notifySelection(id) {
          window.webkit.messageHandlers.openGraphiteSelection.postMessage(id || '');
        }

        function nodeInternalID(element) {
          return element ? element.getAttribute('data-og-internal-id') || '' : '';
        }

        function escapeHTMLText(value) {
          return (value || '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        }

        function htmlForNodeList(nodes) {
          return Array.from(nodes).map((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              if (node.getAttribute('data-og-placement-generated') === 'true' ||
                  node.closest('[data-og-placement-generated="true"]')) {
                return '';
              }
              return node.outerHTML;
            }
            if (node.nodeType === Node.TEXT_NODE) { return escapeHTMLText(node.textContent || ''); }
            return '';
          }).join('');
        }

        function fragmentHTML(fragment) {
          return htmlForNodeList(fragment ? fragment.childNodes : []);
        }

        function notifyDocumentChange(edit) {
          if (!edit || !edit.operation) { return; }
          window.webkit.messageHandlers.openGraphiteDocumentChange.postMessage(edit);
        }

        function notifyTextEditingChange(element) {
          if (!element) { return; }
          window.webkit.messageHandlers.openGraphiteTextEditing.postMessage({
            id: selectionIDForElement(element),
            text: editablePlainText(element)
          });
        }

        function editablePlainText(element) {
          if (!element) { return ''; }
          const value = typeof element.innerText === 'string' ? element.innerText : element.textContent || '';
          return value.replace(/\\n+$/, '');
        }

        function fallbackPlainText(element) {
          if (!element) { return ''; }
          const fallbackHTML = element.getAttribute('data-og-runtime-fallback-html') ?? element.getAttribute('data-og-fallback-text');
          if (fallbackHTML === null) {
            return editablePlainText(element);
          }
          const container = document.createElement('span');
          container.innerHTML = fallbackHTML;
          return editablePlainText(container);
        }

        function selectTextContents(element) {
          const selection = window.getSelection();
          if (!selection) { return; }
          const range = document.createRange();
          range.selectNodeContents(element);
          selection.removeAllRanges();
          selection.addRange(range);
        }

        function caretRangeFromPoint(clientX, clientY) {
          if (typeof document.caretRangeFromPoint === 'function') {
            return document.caretRangeFromPoint(clientX, clientY);
          }
          if (typeof document.caretPositionFromPoint === 'function') {
            const position = document.caretPositionFromPoint(clientX, clientY);
            if (!position) { return null; }
            const range = document.createRange();
            range.setStart(position.offsetNode, position.offset);
            range.collapse(true);
            return range;
          }
          return null;
        }

        function applyCaretRange(range) {
          const selection = window.getSelection();
          if (!selection || !range) { return false; }
          selection.removeAllRanges();
          selection.addRange(range);
          return true;
        }

        function placeCaretAtEnd(element) {
          const range = document.createRange();
          range.selectNodeContents(element);
          range.collapse(false);
          return applyCaretRange(range);
        }

        function placeCaretAtPoint(element, clientX, clientY) {
          const range = caretRangeFromPoint(clientX, clientY);
          if (range && element.contains(range.startContainer)) {
            return applyCaretRange(range);
          }
          return placeCaretAtEnd(element);
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

        function htmlForPlainText(text) {
          const container = document.createElement('span');
          replaceTextContents(container, text);
          return htmlForNodeList(container.childNodes);
        }

        function setTextContent(id, text, mode) {
          const element = editElementForSelectionID(id);
          if (!element) { return false; }

          if (mode === 'resolved') {
            replaceTextContents(element, text);
            collectNodes();
            return true;
          }

          const previousActiveText = editablePlainText(element);
          const previousFallbackText = fallbackPlainText(element);
          const hasRuntimeFallback = element.hasAttribute('data-og-runtime-fallback-html');
          const hasFallbackText = element.hasAttribute('data-og-fallback-text');
          if (hasRuntimeFallback || hasFallbackText) {
            const fallbackHTML = htmlForPlainText(text);
            if (hasRuntimeFallback) {
              element.setAttribute('data-og-runtime-fallback-html', fallbackHTML);
            }
            if (hasFallbackText) {
              element.setAttribute('data-og-fallback-text', fallbackHTML);
            }
            if (previousActiveText === previousFallbackText) {
              replaceTextContents(element, text);
            }
          } else {
            replaceTextContents(element, text);
          }

          collectNodes();
          return true;
        }

        function beginTextEditing(element, options) {
          if (activeTool !== 'select' || !isTextElement(element) || hasLockedAncestor(element)) {
            return false;
          }

          if (editingTextElement && editingTextElement !== element) {
            finishTextEditing(false, false);
          }

          const shouldSelectText = typeof options === 'boolean' ? options : !!(options && options.selectText);
          const shouldPlaceCaret = !shouldSelectText &&
            options &&
            Number.isFinite(options.clientX) &&
            Number.isFinite(options.clientY);
          const id = selectionIDForElement(element);
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
          } else if (shouldPlaceCaret) {
            placeCaretAtPoint(element, options.clientX, options.clientY);
          } else {
            placeCaretAtEnd(element);
          }
          return true;
        }

        function finishTextEditing(cancelled, shouldRestoreSelection) {
          const element = editingTextElement;
          if (!element) { return; }
          const selectedID = selectionIDForElement(element);
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
            const editElement = editElementForSelectionID(selectedID) || element;
            if (editElement !== element) {
              replaceTextContents(editElement, nextText);
            }
            collectNodes();
            notifyDocumentChange({
              operation: 'setTextContent',
              nodeID: selectedID,
              nodeInternalID: nodeInternalID(editElement),
              value: nextText,
              previousValue: originalText
            });
          }
        }

      function setCSSVariable(id, key, value) {
        const element = editElementForSelectionID(id);
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
          const element = editElementForSelectionID(id);
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
          const usedInternalIDs = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-internal-id') || ''));
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
            element.setAttribute('data-og-internal-id', randomInternalID(usedInternalIDs));
            used.add(candidate);
          });
        }

        function textElementFromString(text) {
          const element = document.createElement('TextBlock');
          element.setAttribute('data-og-id', uniqueID('text'));
          element.setAttribute('data-og-internal-id', randomInternalID(new Set(allEditableNodes().map((node) => node.getAttribute('data-og-internal-id') || ''))));
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

        function newInternalID() {
          return randomInternalID(new Set(allEditableNodes().map((node) => nodeInternalID(node))));
        }

        function createFrameID() {
          return uniqueID('frame');
        }

        function applyDefaultBoxStyles(element, width, height) {
          element.style.setProperty('--og-width', width);
          element.style.setProperty('--og-height', height);
        }

        function lucideInlineSVG(name) {
          if (name === 'circle') {
            return [
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">',
              '<circle cx="12" cy="12" r="10"></circle>',
              '</svg>'
            ].join('');
          }
          return [
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">',
            '<circle cx="12" cy="12" r="10"></circle>',
            '</svg>'
          ].join('');
        }

        function createIconElement() {
          const element = document.createElement('Icon');
          const iconName = 'circle';
          element.setAttribute('data-og-id', uniqueID('icon'));
          element.setAttribute('data-og-internal-id', newInternalID());
          element.setAttribute('data-og-type', 'icon');
          element.setAttribute('data-og-icon-library', 'lucide');
          element.setAttribute('data-og-icon-name', iconName);
          element.setAttribute('data-og-icon-source', 'inline');
          element.innerHTML = lucideInlineSVG(iconName);
          applyDefaultBoxStyles(element, '24px', '24px');
          return element;
        }

        function createFrameElement() {
          const element = document.createElement('Frame');
          element.setAttribute('data-og-id', createFrameID());
          element.setAttribute('data-og-internal-id', newInternalID());
          element.setAttribute('data-og-type', 'frame');
          element.setAttribute('data-og-layout', 'vertical');
          element.style.setProperty('--og-gap', '0');
          element.style.setProperty('--og-padding', '0');
          return element;
        }

        function createTextElement() {
          const element = textElementFromString('Text');
          element.style.setProperty('--og-font-size', '16px');
          return element;
        }

        function createRectangleElement() {
          const element = document.createElement('Rectangle');
          element.setAttribute('data-og-id', uniqueID('rectangle'));
          element.setAttribute('data-og-internal-id', newInternalID());
          element.setAttribute('data-og-type', 'frame');
          applyDefaultBoxStyles(element, '120px', '80px');
          element.style.setProperty('--og-background', 'color-mix(in srgb, currentColor 12%, transparent)');
          element.style.setProperty('--og-border', '1px solid color-mix(in srgb, currentColor 28%, transparent)');
          return element;
        }

        function createdElementForTool(tool) {
          if (tool === 'rectangle') { return createRectangleElement(); }
          if (tool === 'text') { return createTextElement(); }
          if (tool === 'frame') { return createFrameElement(); }
          if (tool === 'icon') { return createIconElement(); }
          return null;
        }

        function applyClickPositionIfNeeded(element, parent, event) {
          if (!parent || parent.getAttribute('data-og-layout') !== 'absolute') { return; }
          const parentRect = parent.getBoundingClientRect();
          element.style.setProperty('--og-x', pixelString(event.clientX - parentRect.left));
          element.style.setProperty('--og-y', pixelString(event.clientY - parentRect.top));
        }

        function placeCreatedElement(event) {
          const created = createdElementForTool(activeTool);
          if (!created) { return false; }

          const anchor = editableElementFromTarget(event.target) || selectedElement();
          if (!anchor || hasLockedAncestor(anchor)) { return false; }

          const appendToAnchor = canReceiveChildren(anchor);
          const parent = appendToAnchor ? anchor : anchor.parentElement;
          if (!parent || hasLockedAncestor(parent)) { return false; }

          applyClickPositionIfNeeded(created, parent, event);
          const position = appendToAnchor ? 'append' : 'after';
          const anchorInternalID = nodeInternalID(anchor);
          if (!anchorInternalID) { return false; }

          const html = created.outerHTML;
          if (appendToAnchor) {
            anchor.append(created);
          } else {
            anchor.after(created);
          }

          const selectedID = elementID(created);
          collectNodes();
          selectNode(selectedID);
          notifySelection(selectedID);
          collectStaticFlowLinks();
          notifyDocumentChange({
            operation: 'insertHTML',
            selectedID: selectedID,
            anchorInternalID: anchorInternalID,
            position: position,
            html: html
          });
          return true;
        }

        function setLayout(layout) {
          const element = editElementForSelectionID(currentSelectedID) || selectedElement();
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
                id: selectionIDForElement(current),
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

        function autoLayoutMode(parent) {
          const layout = parent ? parent.getAttribute('data-og-layout') || '' : '';
          return layout === 'vertical' || layout === 'horizontal' ? layout : '';
        }

        function canReorderElement(element) {
          const parent = element ? element.parentElement : null;
          return canDragElement(element) &&
            !!autoLayoutMode(parent) &&
            editableElementChildren(parent).length > 1;
        }

        function runtimeHostForGeneratedElement(element) {
          const generated = element && element.closest ?
            element.closest('[data-og-generated="true"][data-og-source-instance]') :
            null;
          if (!generated) { return null; }

          const host = generated.closest('og-instance[data-og-expanded]');
          if (!host) { return null; }

          const sourceInstanceID = generated.getAttribute('data-og-source-instance') || '';
          const hostID = elementID(host);
          return !sourceInstanceID || sourceInstanceID === hostID ? host : null;
        }

        function visualElementForDragElement(element) {
          if (!element) { return null; }
          if (element.matches && element.matches('og-instance[data-og-expanded]')) {
            return Array.from(element.children).find((child) => {
              return child.getAttribute('data-og-generated') === 'true';
            }) || element;
          }
          return element;
        }

        function reorderElementForChainElement(element) {
          if (canReorderElement(element)) { return element; }
          const runtimeHost = runtimeHostForGeneratedElement(element);
          return canReorderElement(runtimeHost) ? runtimeHost : null;
        }

        function reorderCandidateForChain(chain) {
          for (const candidate of chain.slice().reverse()) {
            const reorderElement = reorderElementForChainElement(candidate);
            if (reorderElement) { return reorderElement; }
          }
          return null;
        }

        function reorderAxisForLayout(layout) {
          return layout === 'horizontal' ? 'x' : 'y';
        }

        function reorderAxisValue(axis, rect) {
          return axis === 'x' ? rect.left + rect.width / 2 : rect.top + rect.height / 2;
        }

        function reorderPositionAlreadyApplied(drag, target, position) {
          const siblings = editableElementChildren(drag.parent);
          const sourceIndex = siblings.indexOf(drag.element);
          const targetIndex = siblings.indexOf(target);
          if (sourceIndex < 0 || targetIndex < 0) { return true; }
          if (position === 'before') {
            return sourceIndex === targetIndex - 1;
          }
          return sourceIndex === targetIndex + 1;
        }

        function cleanupReorderAnimationStyles(element) {
          if (!element) { return; }
          element.removeAttribute('data-og-reorder-animating');
          element.removeAttribute('data-og-reorder-preparing');
          element.removeAttribute('data-og-reorder-animation');
          element.style.removeProperty('--og-reorder-x');
          element.style.removeProperty('--og-reorder-y');
        }

        function animateReorderSiblings(parent, draggedElement, mutate) {
          const siblings = editableElementChildren(parent).filter((child) => child !== draggedElement);
          const previousRects = new Map();
          siblings.forEach((child) => {
            const visualChild = visualElementForDragElement(child);
            previousRects.set(child, visualChild.getBoundingClientRect());
          });

          mutate();

          const token = String(++reorderAnimationToken);
          const animated = [];
          siblings.forEach((child) => {
            const previousRect = previousRects.get(child);
            if (!previousRect) { return; }
            const visualChild = visualElementForDragElement(child);
            const nextRect = visualChild.getBoundingClientRect();
            const deltaX = previousRect.left - nextRect.left;
            const deltaY = previousRect.top - nextRect.top;
            if (Math.abs(deltaX) < 0.5 && Math.abs(deltaY) < 0.5) { return; }

            visualChild.setAttribute('data-og-reorder-animation', token);
            visualChild.setAttribute('data-og-reorder-preparing', 'true');
            visualChild.setAttribute('data-og-reorder-animating', 'true');
            visualChild.style.setProperty('--og-reorder-x', pixelString(deltaX));
            visualChild.style.setProperty('--og-reorder-y', pixelString(deltaY));
            animated.push(visualChild);
          });

          if (animated.length === 0) { return; }

          window.requestAnimationFrame(function() {
            animated.forEach((child) => {
              if (child.getAttribute('data-og-reorder-animation') !== token) { return; }
              child.removeAttribute('data-og-reorder-preparing');
              child.style.setProperty('--og-reorder-x', '0px');
              child.style.setProperty('--og-reorder-y', '0px');
            });
          });

          window.setTimeout(function() {
            animated.forEach((child) => {
              if (child.getAttribute('data-og-reorder-animation') === token) {
                cleanupReorderAnimationStyles(child);
              }
            });
          }, 190);
        }

        function reorderPlacementForDrag(drag) {
          const siblings = editableElementChildren(drag.parent).filter((child) => child !== drag.element);
          if (siblings.length === 0) { return null; }

          const dragRect = drag.visualElement.getBoundingClientRect();
          const dragCenter = reorderAxisValue(drag.axis, dragRect);
          for (const sibling of siblings) {
            const rect = visualElementForDragElement(sibling).getBoundingClientRect();
            const siblingCenter = reorderAxisValue(drag.axis, rect);
            if (dragCenter < siblingCenter) {
              return { target: sibling, position: 'before' };
            }
          }

          return { target: siblings[siblings.length - 1], position: 'after' };
        }

        function applyReorderPlacement(drag, placement) {
          if (!placement || !placement.target || placement.target === drag.element) { return; }
          if (reorderPositionAlreadyApplied(drag, placement.target, placement.position)) { return; }

          animateReorderSiblings(drag.parent, drag.element, function() {
            if (placement.position === 'before') {
              placement.target.before(drag.element);
            } else {
              placement.target.after(drag.element);
            }
          });
          drag.didReorder = true;
        }

        function draggedBaseRect(drag) {
          const element = drag.visualElement || drag.element;
          const previousX = element.style.getPropertyValue('--og-drag-x') || '';
          const previousY = element.style.getPropertyValue('--og-drag-y') || '';
          element.style.setProperty('--og-drag-x', '0px');
          element.style.setProperty('--og-drag-y', '0px');
          const rect = element.getBoundingClientRect();
          if (previousX) {
            element.style.setProperty('--og-drag-x', previousX);
          } else {
            element.style.removeProperty('--og-drag-x');
          }
          if (previousY) {
            element.style.setProperty('--og-drag-y', previousY);
          } else {
            element.style.removeProperty('--og-drag-y');
          }
          return rect;
        }

        function updateReorderDraggedElementPosition(drag, event) {
          const baseRect = draggedBaseRect(drag);
          const nextX = event.clientX - drag.pointerOffsetX - baseRect.left;
          const nextY = event.clientY - drag.pointerOffsetY - baseRect.top;
          drag.visualElement.style.setProperty('--og-drag-x', pixelString(nextX));
          drag.visualElement.style.setProperty('--og-drag-y', pixelString(nextY));
          drag.didMove = true;
        }

        function updateReorderDrag(drag, event) {
          updateReorderDraggedElementPosition(drag, event);
          applyReorderPlacement(drag, reorderPlacementForDrag(drag));
          updateReorderDraggedElementPosition(drag, event);
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

        function cleanupActiveDragStyles(drag) {
          if (!drag || !drag.element) { return; }
          Array.from(new Set([drag.element, drag.visualElement].filter(Boolean))).forEach((element) => {
            element.removeAttribute('data-og-dragging');
            element.removeAttribute('data-og-reorder-dragging');
            element.style.removeProperty('--og-drag-x');
            element.style.removeProperty('--og-drag-y');
          });
        }

        function restoreReorderOrigin(drag) {
          if (!drag || !drag.parent || drag.element.parentElement !== drag.parent) { return; }
          animateReorderSiblings(drag.parent, drag.element, function() {
            if (drag.originalNextSibling &&
                drag.originalNextSibling.parentNode === drag.parent &&
                drag.originalNextSibling !== drag.element) {
              drag.parent.insertBefore(drag.element, drag.originalNextSibling);
            } else {
              drag.parent.appendChild(drag.element);
            }
          });
        }

        function reorderEditPayload(drag) {
          const siblings = editableElementChildren(drag.parent);
          const finalIndex = siblings.indexOf(drag.element);
          if (finalIndex < 0 || finalIndex === drag.startIndex) { return null; }

          const previousSibling = finalIndex > 0 ? siblings[finalIndex - 1] : null;
          const nextSibling = finalIndex < siblings.length - 1 ? siblings[finalIndex + 1] : null;
          if (previousSibling) {
            return {
              operation: 'moveNode',
              nodeID: drag.selectedID,
              nodeInternalID: nodeInternalID(drag.element),
              targetInternalID: nodeInternalID(previousSibling),
              position: 'after'
            };
          }
          if (nextSibling) {
            return {
              operation: 'moveNode',
              nodeID: drag.selectedID,
              nodeInternalID: nodeInternalID(drag.element),
              targetInternalID: nodeInternalID(nextSibling),
              position: 'before'
            };
          }
          return null;
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
          const visualElement = visualElementForDragElement(element);
          const startRect = visualElement.getBoundingClientRect();
          const layout = autoLayoutMode(element.parentElement);
          if (canReorderElement(element)) {
            activeDrag = {
              mode: 'reorder',
              pointerID: pendingDrag.pointerID,
              element: element,
              visualElement: visualElement,
              parent: element.parentElement,
              selectedID: selectedID,
              startClientX: pendingDrag.startClientX,
              startClientY: pendingDrag.startClientY,
              pointerOffsetX: pendingDrag.startClientX - startRect.left,
              pointerOffsetY: pendingDrag.startClientY - startRect.top,
              axis: reorderAxisForLayout(layout),
              originalNextSibling: element.nextSibling,
              startIndex: editableElementChildren(element.parentElement).indexOf(element),
              didMove: false,
              didReorder: false
            };
            visualElement.setAttribute('data-og-reorder-dragging', 'true');
            visualElement.style.setProperty('--og-drag-x', '0px');
            visualElement.style.setProperty('--og-drag-y', '0px');
          } else {
            activeDrag = {
              mode: 'position',
              pointerID: pendingDrag.pointerID,
              element: element,
              selectedID: selectedID,
              startClientX: pendingDrag.startClientX,
              startClientY: pendingDrag.startClientY,
              startX: dragStartValue(element, '--og-x', element.offsetLeft || 0),
              startY: dragStartValue(element, '--og-y', element.offsetTop || 0),
              previousValues: {
                '--og-x': element.style.getPropertyValue('--og-x') || '',
                '--og-y': element.style.getPropertyValue('--og-y') || ''
              },
              didMove: false
            };
          }
          (activeDrag.visualElement || element).setAttribute('data-og-dragging', 'true');
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

          if (activeDrag.mode === 'reorder') {
            updateReorderDrag(activeDrag, event);
          } else {
            updateDraggedElementPosition(activeDrag, event);
          }
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function restorePositionDragValues(drag) {
          Object.entries(drag.previousValues || {}).forEach(([key, value]) => {
            if ((value || '').trim().length === 0) {
              drag.element.style.removeProperty(key);
            } else {
              drag.element.style.setProperty(key, value);
            }
          });
        }

        function finishReorderDrag(drag, cancelled) {
          let edit = null;
          if (cancelled) {
            restoreReorderOrigin(drag);
          } else if (drag.didMove && drag.didReorder) {
            edit = reorderEditPayload(drag);
          }

          cleanupActiveDragStyles(drag);
          if (!edit) {
            collectNodes();
            return;
          }

          collectNodes();
          notifyDocumentChange(edit);
        }

        function finishActiveDrag(cancelled) {
          pendingDrag = null;
          const drag = activeDrag;
          activeDrag = null;
          if (!drag) { return; }
          if (drag.mode === 'reorder') {
            finishReorderDrag(drag, cancelled);
            return;
          }
          cleanupActiveDragStyles(drag);
          if (cancelled) {
            restorePositionDragValues(drag);
            collectNodes();
            return;
          }
          if (!drag.didMove) { return; }
          collectNodes();
          notifyDocumentChange({
            operation: 'setCSSVariables',
            nodeID: drag.selectedID,
            nodeInternalID: nodeInternalID(drag.element),
            values: {
              '--og-x': drag.element.style.getPropertyValue('--og-x') || '',
              '--og-y': drag.element.style.getPropertyValue('--og-y') || ''
            },
            previousValues: drag.previousValues || {}
          });
        }

        function copyPayload() {
          ensureInternalIDs();
          const visualElement = selectedElement();
          if (!visualElement) {
            return { id: '', internalID: '', html: '', text: '' };
          }
          const element = editElementForSelectionID(currentSelectedID) || visualElement;
          const clone = element.cloneNode(true);
          clone.querySelectorAll('[data-og-placement-generated="true"]').forEach((generated) => {
            generated.remove();
          });
        return {
          id: elementID(element),
          internalID: element.getAttribute('data-og-internal-id') || '',
          html: clone.outerHTML,
          text: (clone.textContent || '').trim(),
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
          installEditorSelectionStyle();
          collectNodes();

          if (selectedID && nodeWithID(selectedID)) {
            selectNode(selectedID);
            notifySelection(selectedID);
          } else {
            notifySelection('');
          }

          postScrollState(emptyScrollState(false));
          collectStaticFlowLinks();
          return true;
        }

        function editableElementChildren(parent) {
          return Array.from(parent ? parent.children : []).filter((child) => {
            return child.hasAttribute('data-og-id') || child.hasAttribute('data-og-host-id');
          });
        }

        function runCommand(command, payload) {
          const visualElement = selectedElement();
          const element = editElementForSelectionID(currentSelectedID) || visualElement;
          if (!element && command !== 'pasteHere') {
            return { success: false, selectedID: '' };
          }

          let selectedID = visualElement ? selectionIDForElement(visualElement) : '';
          const selectedInternalID = nodeInternalID(element);
          let edit = null;
          const isLocked = element && element.getAttribute('data-og-locked') === 'true';
          if (isLocked && command !== 'toggleLocked') {
            return { success: false, selectedID: selectedID };
          }

          if (command === 'pasteHere') {
            if (!element) { return { success: false, selectedID: '' }; }
            const fragment = fragmentFromPayload(payload || {});
            const html = fragmentHTML(fragment);
            selectedID = firstEditableID(fragment);
            const position = canReceiveChildren(element) ? 'append' : 'after';
            edit = {
              operation: 'insertHTML',
              anchorInternalID: selectedInternalID,
              position: position,
              html: html
            };
            if (position === 'append') {
              element.append(fragment);
            } else {
              element.after(fragment);
            }
          } else if (command === 'pasteReplace') {
            const fragment = fragmentFromPayload(payload || {});
            const html = fragmentHTML(fragment);
            selectedID = firstEditableID(fragment);
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: html
            };
            element.replaceWith(fragment);
          } else if (command === 'delete') {
            const parentEditable = element.parentElement ? element.parentElement.closest('[data-og-id]') : null;
            selectedID = parentEditable ? elementID(parentEditable) : '';
            edit = {
              operation: 'deleteNode',
              nodeInternalID: selectedInternalID
            };
            element.remove();
          } else if (command === 'moveFront') {
            const siblings = editableElementChildren(element.parentElement).filter((child) => child !== element);
            const target = siblings[siblings.length - 1];
            if (!target) { return { success: false, selectedID: selectedID }; }
            edit = {
              operation: 'moveNode',
              nodeInternalID: selectedInternalID,
              targetInternalID: nodeInternalID(target),
              position: 'after'
            };
            element.parentElement.appendChild(element);
          } else if (command === 'moveBack') {
            const siblings = editableElementChildren(element.parentElement).filter((child) => child !== element);
            const target = siblings[0];
            if (!target) { return { success: false, selectedID: selectedID }; }
            edit = {
              operation: 'moveNode',
              nodeInternalID: selectedInternalID,
              targetInternalID: nodeInternalID(target),
              position: 'before'
            };
            element.parentElement.insertBefore(element, element.parentElement.firstChild);
          } else if (command === 'wrapFrame') {
            const frame = document.createElement('Frame');
            selectedID = createFrameID();
            frame.setAttribute('data-og-id', selectedID);
            frame.setAttribute('data-og-internal-id', randomInternalID(new Set(allEditableNodes().map((node) => nodeInternalID(node)))));
            frame.setAttribute('data-og-type', 'frame');
            frame.setAttribute('data-og-layout', 'vertical');
            frame.style.setProperty('--og-gap', '0');
            frame.style.setProperty('--og-padding', '0');
            element.before(frame);
            frame.append(element);
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: frame.outerHTML
            };
          } else if (command === 'ungroup') {
            const children = Array.from(element.childNodes);
            if (children.length === 0) { return { success: false, selectedID: selectedID }; }
            const html = htmlForNodeList(children);
            const firstChild = children.find((child) => child.nodeType === Node.ELEMENT_NODE && child.hasAttribute('data-og-id'));
            selectedID = firstChild ? elementID(firstChild) : '';
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: html
            };
            children.forEach((child) => element.parentElement.insertBefore(child, element));
            element.remove();
          } else if (command === 'setLayout') {
            const nextLayout = (payload && payload.layout) || 'vertical';
            const previousValue = element.getAttribute('data-og-layout') || '';
            element.setAttribute('data-og-layout', nextLayout);
            selectedID = elementID(element);
            edit = {
              operation: 'setAttribute',
              nodeInternalID: selectedInternalID,
              name: 'data-og-layout',
              value: nextLayout,
              previousValue: previousValue
            };
          } else if (command === 'pasteCSSVariables') {
            const values = {};
            const previousValues = {};
            Object.entries(payload || {}).forEach(([key, value]) => {
              if (key.indexOf('--og-') !== 0) { return; }
              previousValues[key] = element.style.getPropertyValue(key) || '';
              values[key] = value || '';
              if ((value || '').trim().length === 0) {
                element.style.removeProperty(key);
              } else {
                element.style.setProperty(key, value);
              }
            });
            edit = {
              operation: 'setCSSVariables',
              nodeInternalID: selectedInternalID,
              values: values,
              previousValues: previousValues
            };
          } else if (command === 'toggleHidden') {
            const previousValue = element.getAttribute('data-og-hidden') || '';
            const nextValue = previousValue === 'true' ? '' : 'true';
            if (nextValue) {
              element.setAttribute('data-og-hidden', nextValue);
            } else {
              element.removeAttribute('data-og-hidden');
            }
            edit = {
              operation: 'setAttribute',
              nodeInternalID: selectedInternalID,
              name: 'data-og-hidden',
              value: nextValue,
              previousValue: previousValue
            };
          } else if (command === 'toggleLocked') {
            const previousValue = element.getAttribute('data-og-locked') || '';
            const nextValue = previousValue === 'true' ? '' : 'true';
            if (nextValue) {
              element.setAttribute('data-og-locked', nextValue);
            } else {
              element.removeAttribute('data-og-locked');
            }
            edit = {
              operation: 'setAttribute',
              nodeInternalID: selectedInternalID,
              name: 'data-og-locked',
              value: nextValue,
              previousValue: previousValue
            };
          } else if (command === 'flipHorizontal') {
            const previousValue = element.style.getPropertyValue('--og-scale-x') || '';
            toggleScaleVariable(element, '--og-scale-x');
            edit = {
              operation: 'setCSSVariable',
              nodeInternalID: selectedInternalID,
              key: '--og-scale-x',
              value: element.style.getPropertyValue('--og-scale-x') || '',
              previousValue: previousValue
            };
          } else if (command === 'flipVertical') {
            const previousValue = element.style.getPropertyValue('--og-scale-y') || '';
            toggleScaleVariable(element, '--og-scale-y');
            edit = {
              operation: 'setCSSVariable',
              nodeInternalID: selectedInternalID,
              key: '--og-scale-y',
              value: element.style.getPropertyValue('--og-scale-y') || '',
              previousValue: previousValue
            };
          } else {
            return { success: false, selectedID: selectedID };
          }

          collectNodes();
          if (selectedID) {
            selectNode(selectedID);
            notifySelection(selectedID);
          }
          collectStaticFlowLinks();
          return { success: true, selectedID: selectedID, edit: edit };
        }

        window.OpenGraphite = {
          collectNodes: collectNodes,
          collectStaticFlowLinks: collectStaticFlowLinks,
          ensureInternalIDs: ensureInternalIDs,
          installEditorSelectionStyle: installEditorSelectionStyle,
          selectNode: selectNode,
          setActiveTool: setActiveTool,
          setCSSVariable: setCSSVariable,
          setAttributeValue: setAttributeValue,
          setTextContent: setTextContent,
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
          updateStaticFlowHoverFromTarget(event.target);
          updateScrollStateAt(event.clientX, event.clientY);
          if (!editingTextElement && (activeDrag || startActiveDragIfNeeded(event))) {
            updateActiveDrag(event);
          }
        }, activePointerOptions);

        document.addEventListener('pointerover', function(event) {
          updateStaticFlowHoverFromTarget(event.target);
        }, passivePointerOptions);

        document.addEventListener('pointerout', function(event) {
          updateStaticFlowHoverFromTarget(event.relatedTarget);
        }, passivePointerOptions);

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

        document.addEventListener('input', function(event) {
          if (!editingTextElement || event.target !== editingTextElement) { return; }
          notifyTextEditingChange(editingTextElement);
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

        document.addEventListener('mouseleave', function() {
          markPointerOutside();
          postStaticFlowHover(null);
        }, { capture: true });

        document.addEventListener('scroll', function() {
          updateLastPointerScrollState();
          scheduleStaticFlowLinkCollection();
        }, true);

        document.addEventListener('wheel', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
        }, passivePointerOptions);

        window.addEventListener('resize', scheduleStaticFlowLinkCollection, passivePointerOptions);

        if (window.ResizeObserver) {
          const staticFlowResizeObserver = new ResizeObserver(scheduleStaticFlowLinkCollection);
          staticFlowResizeObserver.observe(document.documentElement);
          if (document.body) {
            staticFlowResizeObserver.observe(document.body);
          }
          window.__openGraphiteStaticFlowResizeObserver = staticFlowResizeObserver;
        }

        document.addEventListener('click', function(event) {
          if (suppressNextClick) {
            suppressNextClick = false;
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          if (editingTextElement && editingTextElement.contains(event.target)) { return; }
          if (activeTool !== 'select') {
            if (placeCreatedElement(event)) {
              event.preventDefault();
              event.stopPropagation();
            }
            return;
          }
          const element = editableElementFromTarget(event.target);
          if (!element) { return; }
          event.preventDefault();
          event.stopPropagation();
          const textElement = textElementForEditing(element, editingSelectionBaselineForClick(event));
          if (textElement) {
            suppressNextClick = false;
            beginTextEditing(textElement, {
              selectText: false,
              clientX: event.clientX,
              clientY: event.clientY
            });
            return;
          }
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
          const textElement = textElementForEditing(element, clickSequenceStartSelectedID);
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

        document.addEventListener('opengraphite:components-ready', function() {
          collectNodes();
          collectStaticFlowLinks();
          if (currentSelectedID) {
            selectNode(currentSelectedID);
          }
        });

      installEditorSelectionStyle();

      setTimeout(function() {
        collectNodes();
        collectStaticFlowLinks();
        postScrollState(emptyScrollState(false));
      }, 0);
    })();
    """
}
