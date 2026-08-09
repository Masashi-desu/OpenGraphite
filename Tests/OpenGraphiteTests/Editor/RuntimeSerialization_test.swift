import Foundation
import Testing
import WebKit
@testable import OpenGraphite

/// 論理名（日本語）: runtimeシリアライズテストスイート
/// 概要: `OpenGraphite.runtime.js` の保存復元と、focus表示が対象外document scrollを露出させないことを確認します。
@MainActor
@Suite("runtimeシリアライズテストスイート")
struct RuntimeSerializationTests {
    /// 論理名（日本語）: WebCanvas選択収集分離テスト
    /// 概要: 初期Layers payloadを軽量化し、通常クリックでは全node再収集を起動せず選択node詳細だけを通知することを確認します。
    @Test("WebCanvas選択はLayers再収集せず選択node詳細だけを更新する")
    func testWebCanvasSelectionCollectsOnlySelectedNodeDetails() async throws {
        // コンディション：複数階層nodeとnodes/detail両message handlerを持つWebViewを用意する（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteNodeDetails", "openGraphiteSelection",
            "openGraphiteContextMenu", "openGraphiteScrollState", "openGraphiteDocumentChange",
            "openGraphiteTextEditing", "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 420),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            """
            <!doctype html><html><body>
              <main id="root" data-og-internal-id="root-node">
                <section id="card" data-og-internal-id="card-node">
                  <span id="label" data-og-internal-id="label-node">Label</span>
                </section>
              </main>
            </body></html>
            """,
            in: webView
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        try await Task.sleep(for: .milliseconds(80))

        // 検証内容：軽量Layers payloadを明示収集後、cardへの通常clickを配送する（When）
        let layerValue = try await webView.evaluateJavaScript("window.OpenGraphite.collectLayerNodes()")
        let layerPayload = try #require(layerValue as? [[String: Any]])
        try await Task.sleep(for: .milliseconds(50))
        let nodePayloadCountBeforeClick = messageHandler.nodePayloads.count
        let detailPayloadCountBeforeClick = messageHandler.nodeDetailPayloads.count
        _ = try await webView.evaluateJavaScript(
            "document.getElementById('card').dispatchEvent(new MouseEvent('click', { bubbles: true }))"
        )
        try await Task.sleep(for: .milliseconds(80))

        // 期待値：Layers payloadに重いcomputed詳細はなく、click後は全node messageが増えず1 node詳細だけが届く（Then）
        let cardLayer = try #require(layerPayload.first { $0["standardID"] as? String == "card" })
        let selectedDetail = try #require(messageHandler.nodeDetailPayloads.last)
        #expect(cardLayer["computedStyle"] == nil)
        #expect(cardLayer["capabilities"] == nil)
        #expect(cardLayer["renderingTargets"] == nil)
        #expect(messageHandler.nodePayloads.count == nodePayloadCountBeforeClick)
        #expect(messageHandler.nodeDetailPayloads.count == detailPayloadCountBeforeClick + 1)
        #expect(selectedDetail["computedStyle"] != nil)
        #expect(selectedDetail["capabilities"] != nil)
        #expect(selectedDetail["renderingTargets"] != nil)
    }

    /// 論理名（日本語）: Tutorial Objects選択収集性能テスト
    /// 概要: 実Tutorial pageでLayers一覧と選択node詳細を分離し、選択側が全node収集より十分小さい実行時間に収まることを確認します。
    @Test("Tutorial Objectsの選択詳細収集は全node収集より軽い")
    func testTutorialObjectsSelectionDetailCollectionIsCheaperThanFullCollection() async throws {
        // コンディション：利用者のbrowser sessionと分離したWKWebViewへ実Tutorial Objects pageを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in ["openGraphiteNodes", "openGraphiteNodeDetails"] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1180, height: 900),
            configuration: configuration
        )
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageURL = repositoryURL.appendingPathComponent("public/tutorial-objects.html")
        let waiter = WebViewNavigationWaiter()
        try await waiter.loadFile(pageURL, allowingReadAccessTo: repositoryURL, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        try await Task.sleep(for: .milliseconds(120))

        // 検証内容：軽量Layers、1 node詳細、互換用full payloadを同じdocumentで実測する（When）
        let rawMetrics = try await webView.evaluateJavaScript(
            """
            (() => {
              const layerStart = performance.now();
              const layers = window.OpenGraphite.collectLayerNodes();
              const layerMilliseconds = performance.now() - layerStart;
              const target = layers.find((node) => node.depth >= 2) || layers[0];
              const detailStart = performance.now();
              window.OpenGraphite.collectNodeDetails(target.id);
              const detailMilliseconds = performance.now() - detailStart;
              const fullStart = performance.now();
              window.OpenGraphite.collectNodes();
              const fullMilliseconds = performance.now() - fullStart;
              return { nodeCount: layers.length, layerMilliseconds, detailMilliseconds, fullMilliseconds };
            })()
            """
        )
        let metrics = try #require(rawMetrics as? [String: Any])
        let nodeCount = try #require(metrics["nodeCount"] as? NSNumber).intValue
        let layerMilliseconds = try #require(metrics["layerMilliseconds"] as? NSNumber).doubleValue
        let detailMilliseconds = try #require(metrics["detailMilliseconds"] as? NSNumber).doubleValue
        let fullMilliseconds = try #require(metrics["fullMilliseconds"] as? NSNumber).doubleValue
        print(
            "Tutorial Objects collection metrics: nodes=\(nodeCount), "
                + "layers=\(layerMilliseconds)ms, detail=\(detailMilliseconds)ms, full=\(fullMilliseconds)ms"
        )

        // 期待値：実ページ規模を保ち、選択処理は全node詳細収集より軽く実用的な上限内に収まる（Then）
        #expect(nodeCount >= 50)
        #expect(detailMilliseconds < fullMilliseconds)
        #expect(detailMilliseconds < 250)
        #expect(layerMilliseconds < 1_000)
    }

    /// 論理名（日本語）: 標準HTML readinessテスト
    /// 概要: OpenGraphite.cssやannotationを持たない通常文書もCanvas表示準備済みと判定することを確認します。
    @Test("annotationとOpenGraphite.cssのない標準HTMLも表示準備済みになる")
    func testStandardHTMLWithoutDistributedCSSBecomesPreviewReady() async throws {
        // コンディション：標準tagとbrowser既定marginだけを持つHTMLをWebViewへ読み込む（Given）
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            "<!doctype html><html><body><main id=\"article\"><h1>Standard page</h1></main></body></html>",
            in: webView
        )

        // 検証内容：Canvasと同じreadiness scriptを評価する（When）
        let ready = try await webView.evaluateJavaScript(WebCanvasView.Coordinator.previewReadinessScript)

        // 期待値：data-og-type、body reset、viewport fillを要求せず準備済みになる（Then）
        #expect(ready as? Bool == true)
    }

    /// 論理名（日本語）: WebKit UA display matrixテスト
    /// 概要: stateful HTML要素と標準tagのUA computed display/content-visibilityをheadless契約の比較基準として固定します。
    @Test("WebKitのstateful HTML UA display matrixを固定する")
    func testWebKitStatefulHTMLUADisplayMatrix() async throws {
        // コンディション：stateでUA displayが変わる要素と特殊な標準displayを持つtagを読み込む（Given）
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 700))
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head id="none-head">
            <base id="none-base" href="./">
            <link id="none-link" rel="stylesheet" href="data:text/css,%23unused%7Bcolor%3Ared%7D">
            <meta id="none-meta" name="fixture" content="ua-display">
            <style id="none-style">#unused { color: blue; }</style>
            <script id="none-script">void 0</script>
            <template id="none-template"><span>Template</span></template>
            <title id="none-title">UA matrix</title>
          </head>
          <body>
            <dialog id="dialog-closed">Closed</dialog>
            <dialog id="dialog-open" open>Open</dialog>
            <input id="input-hidden" type="hidden">
            <input id="input-hidden-case" type="HiDdEn">
            <input id="input-text" type="text">
            <details id="details-closed">
              <summary id="summary-first">First</summary>
              <summary id="summary-second">Second</summary>
              <div id="details-content">Content</div>
            </details>
            <summary id="summary-standalone">Standalone</summary>
            <section id="hidden-normal" hidden>Hidden</section>
            <section id="hidden-until" hidden="UnTiL-FoUnD">Findable</section>
            <section id="hidden-until-flex" hidden="until-found" style="display:flex">Findable flex</section>
            <embed id="embed-hidden" hidden src="about:blank">
            <div><slot id="slot">Fallback</slot></div>
            <search id="search">Search</search>
            <fieldset><legend id="legend">Legend</legend></fieldset>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)

        // 検証内容：各要素のWebKit computed displayとcontent-visibilityをDOM変更なしで収集する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const ids = [
                'dialog-closed', 'dialog-open',
                'input-hidden', 'input-hidden-case', 'input-text',
                'details-closed', 'summary-first', 'summary-second', 'details-content', 'summary-standalone',
                'hidden-normal', 'hidden-until', 'hidden-until-flex', 'embed-hidden',
                'slot', 'search', 'legend',
                'none-head', 'none-base', 'none-link', 'none-meta', 'none-style',
                'none-script', 'none-template', 'none-title'
              ];
              return Object.fromEntries(ids.map((id) => {
                const element = document.getElementById(id);
                const style = getComputedStyle(element);
                return [id, {
                  display: String(style.display || ''),
                  contentVisibility: String(style.contentVisibility || ''),
                  hiddenAttribute: element.hasAttribute('hidden'),
                  rectCount: element.getClientRects().length,
                  rectHeight: element.getBoundingClientRect().height
                }];
              }));
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：dialog/input state、details内のfirst summary、標準特殊tagをWebKitのUA値どおり返す（Then）
        let expectedDisplays: [String: String] = [
            "dialog-closed": "none",
            "dialog-open": "block",
            "input-hidden": "none",
            "input-hidden-case": "none",
            "input-text": "inline-block",
            "details-closed": "block",
            "summary-first": "list-item",
            "summary-second": "block",
            "details-content": "block",
            "summary-standalone": "block",
            "hidden-normal": "none",
            "hidden-until": "block",
            "hidden-until-flex": "flex",
            "embed-hidden": "inline",
            "slot": "contents",
            "search": "block",
            "legend": "block",
            "none-head": "none",
            "none-base": "none",
            "none-link": "none",
            "none-meta": "none",
            "none-style": "none",
            "none-script": "none",
            "none-template": "none",
            "none-title": "none"
        ]
        for (id, expectedDisplay) in expectedDisplays {
            let result = try #require(payload[id] as? [String: Any])
            #expect(result["display"] as? String == expectedDisplay)
        }

        // 期待値：通常hiddenとuntil-foundを分離し、embedではhidden属性がUA display:noneを意味しない（Then）
        let normalHidden = try #require(payload["hidden-normal"] as? [String: Any])
        let untilFound = try #require(payload["hidden-until"] as? [String: Any])
        let untilFoundFlex = try #require(payload["hidden-until-flex"] as? [String: Any])
        let hiddenEmbed = try #require(payload["embed-hidden"] as? [String: Any])
        let untilFoundFlexHeight = try #require(untilFoundFlex["rectHeight"] as? NSNumber)
        #expect(normalHidden["hiddenAttribute"] as? Bool == true)
        #expect(normalHidden["rectCount"] as? Int == 0)
        #expect(untilFound["hiddenAttribute"] as? Bool == true)
        #expect(untilFound["contentVisibility"] as? String == "hidden")
        #expect(untilFoundFlex["display"] as? String == "flex")
        #expect(untilFoundFlex["contentVisibility"] as? String == "hidden")
        #expect(untilFoundFlex["rectCount"] as? Int == 1)
        #expect(untilFoundFlexHeight.doubleValue == 0)
        #expect(hiddenEmbed["hiddenAttribute"] as? Bool == true)
        #expect(hiddenEmbed["display"] as? String == "inline")
    }

    /// 論理名（日本語）: WebKit author stylesheet境界テスト
    /// 概要: malformedな先行sheet、local style/link順、同一origin `@import`を独立sheetとして評価するWebKit境界を固定します。
    @Test("WebKitはmalformed sheetを隔離してlocal style link import順を保つ")
    func testWebKitPreservesAuthorStylesheetBoundariesAndOrder() async throws {
        // コンディション：malformed project相当style、前後local style、同一origin linkとimportを一時resourceへ用意する（Given）
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("OpenGraphite-WSCM9-Stylesheet-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let importedCSS = """
        @media (min-width: 1px) {
          #imported { border-top: 7px solid rgb(7, 8, 9); }
        }
        """
        let linkedCSS = """
        @import url("imported.css") (orientation: landscape);
        #local-order { display: grid; color: rgb(4, 5, 6); }
        #link-only { display: flex; }
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style id="project-style">
              #malformed-boundary { display: grid; color: rgb(1, 2, 3); }
              @media screen and (
            </style>
            <style id="local-before" media="(min-height: 200px)">
              #malformed-boundary { display: flex; }
              #local-order { display: block; color: rgb(2, 3, 4); }
            </style>
            <link id="local-link" rel="stylesheet" href="linked.css" media="(min-width: 300px)">
            <style id="local-after">
              #local-order { display: inline-flex; color: rgb(8, 9, 10); }
            </style>
          </head>
          <body>
            <main id="malformed-boundary">Malformed boundary</main>
            <main id="local-order">Ordered</main>
            <main id="link-only">Linked</main>
            <main id="imported">Imported</main>
          </body>
        </html>
        """
        let pageURL = rootURL.appendingPathComponent("index.html")
        try importedCSS.write(to: rootURL.appendingPathComponent("imported.css"), atomically: true, encoding: .utf8)
        try linkedCSS.write(to: rootURL.appendingPathComponent("linked.css"), atomically: true, encoding: .utf8)
        try pageHTML.write(to: pageURL, atomically: true, encoding: .utf8)
        let configuration = WKWebViewConfiguration()
        let schemeHandler = LocalFixtureURLSchemeHandler(rootURL: rootURL)
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "opengraphite-fixture")
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 420),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        let requestURL = try #require(URL(string: "opengraphite-fixture://local/index.html"))
        try await waiter.load(URLRequest(url: requestURL), in: webView)
        _ = try await webView.evaluateJavaScript(
            """
            (() => {
              const nativeMatchMedia = window.matchMedia.bind(window);
              const records = new Map();
              window.__openGraphiteStylesheetMediaQueries = records;
              window.matchMedia = function(condition) {
                if (records.has(condition)) { return records.get(condition); }
                const nativeQuery = nativeMatchMedia(condition);
                const listeners = new Set();
                const record = {
                  get media() { return nativeQuery.media; },
                  get matches() { return nativeQuery.matches; },
                  addEventListener: function(name, listener) {
                    if (name === 'change') { listeners.add(listener); }
                    nativeQuery.addEventListener(name, listener);
                  },
                  removeEventListener: function(name, listener) {
                    if (name === 'change') { listeners.delete(listener); }
                    nativeQuery.removeEventListener(name, listener);
                  },
                  addListener: function(listener) {
                    listeners.add(listener);
                    nativeQuery.addListener(listener);
                  },
                  removeListener: function(listener) {
                    listeners.delete(listener);
                    nativeQuery.removeListener(listener);
                  },
                  listenerCount: function() { return listeners.size; }
                };
                records.set(condition, record);
                return record;
              };
            })();
            """
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：computed winnerとtop-level stylesheet owner順を取得し、source fileを読み戻す（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              function style(id) {
                const computed = getComputedStyle(document.getElementById(id));
                return {
                  display: computed.display,
                  color: computed.color,
                  borderTopWidth: computed.borderTopWidth,
                  borderTopStyle: computed.borderTopStyle
                };
              }
              return {
                malformed: style('malformed-boundary'),
                localOrder: style('local-order'),
                linkOnly: style('link-only'),
                imported: style('imported'),
                importedNode: window.OpenGraphite.collectNodes().find((node) => node.standardID === 'imported'),
                sheetOwners: Array.from(document.styleSheets).map((sheet) => sheet.ownerNode?.id || '')
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let malformed = try #require(payload["malformed"] as? [String: Any])
        let localOrder = try #require(payload["localOrder"] as? [String: Any])
        let linkOnly = try #require(payload["linkOnly"] as? [String: Any])
        let imported = try #require(payload["imported"] as? [String: Any])
        let importedNode = try #require(payload["importedNode"] as? [String: Any])
        let sheetOwners = try #require(payload["sheetOwners"] as? [String])
        let mediaListenerCounts = try #require(
            try await webView.evaluateJavaScript(
                """
                Object.fromEntries(Array.from(window.__openGraphiteStylesheetMediaQueries).map(
                  ([condition, record]) => [condition, record.listenerCount()]
                ))
                """
            ) as? [String: Int]
        )
        let externallyUpdatedImportedCSS = importedCSS.replacingOccurrences(of: "7px", with: "11px")
        try externallyUpdatedImportedCSS.write(
            to: rootURL.appendingPathComponent("imported.css"),
            atomically: true,
            encoding: .utf8
        )
        try await waiter.reloadFromOrigin(in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        let importedBorderAfterExternalChange = try #require(
            try await webView.evaluateJavaScript(
                "getComputedStyle(document.getElementById('imported')).borderTopWidth"
            ) as? String
        )
        try importedCSS.write(
            to: rootURL.appendingPathComponent("imported.css"),
            atomically: true,
            encoding: .utf8
        )
        try await waiter.reloadFromOrigin(in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        let authoredDOMBeforeUnreadableImport = try #require(
            try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        )
        let unreadableImportedNode = try #require(
            try await webView.evaluateJavaScript(
                """
                (() => {
                  const linkedSheet = document.getElementById('local-link').sheet;
                  const importedSheet = linkedSheet.cssRules[0].styleSheet;
                  Object.defineProperty(importedSheet, 'cssRules', {
                    configurable: true,
                    get: function() { throw new DOMException('cross-origin import fixture', 'SecurityError'); }
                  });
                  return window.OpenGraphite.collectNodes().find((node) => node.standardID === 'imported');
                })();
                """
            ) as? [String: Any]
        )
        let authoredDOMAfterUnreadableImport = try #require(
            try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        )
        let afterHTML = try String(contentsOf: pageURL, encoding: .utf8)
        let afterLinkedCSS = try String(contentsOf: rootURL.appendingPathComponent("linked.css"), encoding: .utf8)
        let afterImportedCSS = try String(contentsOf: rootURL.appendingPathComponent("imported.css"), encoding: .utf8)

        // 期待値：malformed sheetは後続sheetを汚染せず、style/linkのdocument順とimported declarationがbrowser cascadeへ反映される（Then）
        #expect(malformed["display"] as? String == "flex")
        #expect(malformed["color"] as? String == "rgb(1, 2, 3)")
        #expect(localOrder["display"] as? String == "inline-flex")
        #expect(localOrder["color"] as? String == "rgb(8, 9, 10)")
        #expect(linkOnly["display"] as? String == "flex")
        #expect(imported["borderTopWidth"] as? String == "7px")
        #expect(imported["borderTopStyle"] as? String == "solid")
        #expect((importedNode["activeMediaQueries"] as? [String])?.contains("(min-width: 1px)") == true)
        #expect((importedNode["activeMediaQueries"] as? [String])?.contains("(min-height: 200px)") == true)
        #expect((importedNode["activeMediaQueries"] as? [String])?.contains("(min-width: 300px)") == true)
        #expect((importedNode["activeMediaQueries"] as? [String])?.contains("(orientation: landscape)") == true)
        #expect(mediaListenerCounts["(min-height: 200px)"] == 1)
        #expect(mediaListenerCounts["(min-width: 300px)"] == 1)
        #expect(mediaListenerCounts["(orientation: landscape)"] == 1)
        #expect(importedBorderAfterExternalChange == "11px")
        #expect(importedNode["unreadableStyleSheetCount"] as? Int == 0)
        #expect(unreadableImportedNode["unreadableStyleSheetCount"] as? Int == 1)
        #expect(sheetOwners == ["project-style", "local-before", "local-link", "local-after"])

        // 期待値：import先がSecurityErrorでも循環防止付き探索はsource DOM/CSS bytesを変更しない（Then）
        #expect(authoredDOMAfterUnreadableImport == authoredDOMBeforeUnreadableImport)
        #expect(afterHTML == pageHTML)
        #expect(afterLinkedCSS == linkedCSS)
        #expect(afterImportedCSS == importedCSS)
    }

    /// 論理名（日本語）: WebCanvas読み取り不能stylesheet inspectionテスト
    /// 概要: cross-origin相当の`cssRules` SecurityErrorを診断し、computed inspectionとDOM/CSS sourceを維持することを確認します。
    @Test("WebCanvasは読み取り不能stylesheetをcomputed inspectionのまま報告する")
    func testWebCanvasReportsUnreadableStylesheetWithoutMutatingSource() async throws {
        // コンディション：computed gridを適用するsheetをcross-origin相当のcssRules SecurityErrorへ置き換える（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html><html><head>
          <style id="unreadable-sheet">#target { display: grid; grid-template-columns: 1fr 2fr; }</style>
        </head><body>
          <main id="target" data-og-id="target" data-og-internal-id="target-node">Target</main>
        </body></html>
        """
        try await waiter.load(pageHTML, in: webView)
        let authoredDOM = try #require(
            try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        )
        let authoredCSS = try #require(
            try await webView.evaluateJavaScript("document.getElementById('unreadable-sheet').textContent") as? String
        )
        _ = try await webView.evaluateJavaScript(
            """
            (() => {
              const sheet = document.getElementById('unreadable-sheet').sheet;
              Object.defineProperty(sheet, 'cssRules', {
                configurable: true,
                get: function() { throw new DOMException('cross-origin fixture', 'SecurityError'); }
              });
              return true;
            })();
            """
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：node graphを再収集し、computed値、unreadable count、sourceを取得する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const nodes = window.OpenGraphite.collectNodes();
              return {
                target: nodes.find((node) => node.standardID === 'target'),
                html: document.documentElement.outerHTML,
                css: document.getElementById('unreadable-sheet').textContent
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let target = try #require(payload["target"] as? [String: Any])
        let computedStyle = try #require(target["computedStyle"] as? [String: Any])
        let resolvedGridColumns = try #require(computedStyle["gridTemplateColumns"] as? String)
            .split(whereSeparator: \Character.isWhitespace)

        // 期待値：source ruleが読めなくてもWebKit computed値を表示し、不完全provenanceを全nodeへ明示してsourceを変えない（Then）
        #expect(computedStyle["display"] as? String == "grid")
        #expect(resolvedGridColumns.count == 2)
        #expect(resolvedGridColumns.allSatisfy { $0.hasSuffix("px") })
        #expect(target["unreadableStyleSheetCount"] as? Int == 1)
        #expect(payload["html"] as? String == authoredDOM)
        #expect(payload["css"] as? String == authoredCSS)
    }

    /// 論理名（日本語）: Optional annotation WebCanvas収集テスト
    /// 概要: 未注釈・部分注釈・完全注釈nodeを同時にinspectionし、session referenceがDOMを変更せず同一sessionで安定することを確認します。
    @Test("WebCanvasはoptional annotationを非侵襲session referenceで収集する")
    func testWebCanvasCollectsOptionalAnnotationsWithoutAdoption() async throws {
        // コンディション：未注釈、標準id、部分注釈、完全注釈が共存する標準HTMLをWebViewへ読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        let messageNames = [
            "openGraphiteNodes",
            "openGraphiteSelection",
            "openGraphiteContextMenu",
            "openGraphiteScrollState",
            "openGraphiteDocumentChange",
            "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks",
            "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay",
            "openGraphiteNodeDragPreview"
        ]
        for name in messageNames {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 420),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <main id="article" class="unique-main">
              <h1 class="unique-title">Standard title</h1>
              <section class="shared-card" data-og-id="partial"><content-lead>Partially annotated</content-lead></section>
              <footer class="shared-card" data-og-id="complete" data-og-internal-id="complete-node">Complete without type</footer>
            </main>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        let authoredValue = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
        let authoredHTML = try #require(authoredValue as? String)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：node graphを2回収集し、未注釈nodeを選択・copy・通常mutation試行した後のDOMを取得する（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const first = window.OpenGraphite.collectNodes();
              const article = first.find((node) => node.standardID === 'article');
              window.OpenGraphite.selectNode(article.id);
              const copied = window.OpenGraphite.copyPayload();
              const mutation = window.OpenGraphite.runCommand('flipHorizontal', {});
              const second = window.OpenGraphite.collectNodes();
              return {
                first,
                second,
                copied,
                mutation,
                html: document.documentElement.outerHTML,
                openGraphiteAttributeCount: document.querySelectorAll(
                  '[data-og-id], [data-og-internal-id], [data-og-type]'
                ).length
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let first = try #require(payload["first"] as? [[String: Any]])
        let second = try #require(payload["second"] as? [[String: Any]])
        let article = try #require(first.first { $0["standardID"] as? String == "article" })
        let title = try #require(first.first { $0["tagName"] as? String == "h1" })
        let partial = try #require(first.first { $0["authoredID"] as? String == "partial" })
        let complete = try #require(first.first { $0["authoredID"] as? String == "complete" })
        let secondArticle = try #require(second.first { $0["standardID"] as? String == "article" })
        let articleLocator = try #require(article["locator"] as? [String: Any])
        let titleLocator = try #require(title["locator"] as? [String: Any])
        let partialLocator = try #require(partial["locator"] as? [String: Any])
        let customElement = try #require(first.first { $0["tagName"] as? String == "content-lead" })
        let customElementLocator = try #require(customElement["locator"] as? [String: Any])
        let copied = try #require(payload["copied"] as? [String: Any])
        let copiedHTML = try #require(copied["html"] as? String)
        let mutation = try #require(payload["mutation"] as? [String: Any])

        // 期待値：全nodeがinspection可能で、標準id selectorを優先し、session refとsource byte表現をadoptなしで保持する（Then）
        #expect(first.count == 5)
        #expect(article["annotationStatus"] as? String == "none")
        #expect(article["referenceStability"] as? String == "session")
        #expect((article["reference"] as? String)?.hasPrefix("ogref-session:node:") == true)
        #expect(articleLocator["selector"] as? String == "#article")
        #expect((articleLocator["domPath"] as? String)?.contains("main") == true)
        #expect(title["annotationStatus"] as? String == "none")
        #expect(titleLocator["selector"] as? String == ".unique-title")
        #expect(partial["annotationStatus"] as? String == "partial")
        #expect(partial["referenceStability"] as? String == "session")
        #expect(partialLocator["selector"] as? String == "section.shared-card")
        #expect(customElementLocator["selector"] as? String == "content-lead")
        #expect(complete["annotationStatus"] as? String == "complete")
        #expect(complete["referenceStability"] as? String == "stable")
        #expect(article["id"] as? String == secondArticle["id"] as? String)
        #expect(article["reference"] as? String == secondArticle["reference"] as? String)
        #expect(copiedHTML.hasPrefix("<main id=\"article\" class=\"unique-main\">"))
        #expect(!copiedHTML.hasPrefix("<main id=\"article\" data-og-"))
        #expect(mutation["requiresAdoption"] as? Bool == true)
        #expect(payload["openGraphiteAttributeCount"] as? Int == 2)
        #expect(payload["html"] as? String == authoredHTML)
    }

    /// 論理名（日本語）: WebCanvas operation capability matrixテスト
    /// 概要: 標準HTML、custom element、ARIA、legacy hint、SVG namespaceを単一typeでなくoperation別capabilityへ導出し、Shared graphとのparityと非侵襲guardを確認します。
    @Test("WebCanvasはDOM semanticsからoperation capabilityを導出する")
    func testWebCanvasDerivesOperationCapabilitiesFromDOMSemantics() async throws {
        // コンディション：link/control/media/text/custom/legacy/constrained contentとSVG namespaceが共存するHTMLを用意する（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 760, height: 720),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html><body>
          <main id="root" data-og-id="root" data-og-internal-id="root-node">
            <h1 id="heading" data-og-id="heading" data-og-internal-id="heading-node">Title <em>mixed</em></h1>
            <a id="empty-link" href="" data-og-id="empty-link" data-og-internal-id="empty-link-node">Empty href</a>
            <div id="role-link" role="foo LINK" data-og-id="role-link" data-og-internal-id="role-link-node">ARIA link</div>
            <button id="button" is="x-action" data-og-id="button" data-og-internal-id="button-node">Press</button>
            <button id="invalid-is" is="foo" data-og-id="invalid-is" data-og-internal-id="invalid-is-node">Plain button</button>
            <input id="input" data-og-id="input" data-og-internal-id="input-node" value="Original">
            <img id="media" data-og-id="media" data-og-internal-id="media-node" src="hero.png" alt="Hero">
            <media-card id="media-wrapper" data-og-id="media-wrapper" data-og-internal-id="media-wrapper-node"><img src="card.png" alt="Card"></media-card>
            <span id="svg-icon" data-og-id="svg-icon" data-og-internal-id="svg-icon-node"><svg viewBox="0 0 10 10"><path d="M0 0h10v10z"></path></svg></span>
            <br id="legacy" data-og-id="legacy" data-og-internal-id="legacy-node" data-og-type="image">
            <section id="editable-parent" contenteditable="plaintext-only" data-og-id="editable-parent" data-og-internal-id="editable-parent-node">
              <x-empty id="editable-child" data-og-id="editable-child" data-og-internal-id="editable-child-node"></x-empty>
              <x-empty id="editable-false" contenteditable="false" data-og-id="editable-false" data-og-internal-id="editable-false-node"></x-empty>
            </section>
            <output id="output" data-og-id="output" data-og-internal-id="output-node">Result</output>
            <data id="data-value" value="1" data-og-id="data-value" data-og-internal-id="data-value-node">One</data>
            <select><optgroup id="optgroup" data-og-id="optgroup" data-og-internal-id="optgroup-node">Direct<option>Option</option></optgroup></select>
            <div><span id="safe-span" data-og-id="safe-span" data-og-internal-id="safe-span-node"><em>Child</em></span></div>
            <p><span id="constrained-span" data-og-id="constrained-span" data-og-internal-id="constrained-span-node"><em>Child</em></span></p>
            <table id="table" data-og-id="table" data-og-internal-id="table-node"><tbody><tr id="row" data-og-id="row" data-og-internal-id="row-node"><td id="cell" data-og-id="cell" data-og-internal-id="cell-node">Cell</td></tr></tbody></table>
            <ul><li id="list-item" value="1" data-og-id="list-item" data-og-internal-id="list-item-node">Item</li></ul>
            <svg id="svg-root" data-og-id="svg-root" data-og-internal-id="svg-root-node" viewBox="0 0 20 20">
              <defs id="defs" data-og-id="defs" data-og-internal-id="defs-node"><symbol id="symbol" data-og-id="symbol" data-og-internal-id="symbol-node"></symbol></defs>
              <mask id="svg-mask" data-og-id="svg-mask" data-og-internal-id="svg-mask-node"><rect width="10" height="10"></rect></mask>
              <linearGradient id="svg-gradient" data-og-id="svg-gradient" data-og-internal-id="svg-gradient-node"><stop offset="1"></stop></linearGradient>
              <text id="svg-text" data-og-id="svg-text" data-og-internal-id="svg-text-node"><tspan>Icon text</tspan></text>
              <foreignObject width="20" height="20"><div xmlns="http://www.w3.org/1999/xhtml" id="foreign-html" data-og-id="foreign-html" data-og-internal-id="foreign-html-node"></div></foreignObject>
            </svg>
          </main>
        </body></html>
        """
        let sourceNodes = OpenGraphiteHTMLDocument(html: pageHTML).nodes()
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：capabilityを2回収集し、禁止attribute/text/group/insertを試した後、許可されたgroupを1回実行する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const first = window.OpenGraphite.collectNodes();
              const beforeGuards = document.getElementById('root').outerHTML;
              const select = (id) => window.OpenGraphite.selectNode(id);
              select('defs');
              const svgInsert = window.OpenGraphite.runCommand('pasteHere', { html: '<div>invalid</div>' });
              select('row');
              const rowGroup = window.OpenGraphite.runCommand('wrapFrame', {});
              select('media-wrapper');
              const invalidMediaSource = window.OpenGraphite.setAttributeValue('media-wrapper', 'src', 'wrong.png');
              const invalidRoleHref = window.OpenGraphite.setAttributeValue('role-link', 'href', '/wrong');
              const invalidOutputValue = window.OpenGraphite.setAttributeValue('output', 'value', 'wrong');
              const invalidInputText = window.OpenGraphite.setTextContent('input', 'wrong', 'fallback');
              window.OpenGraphite.setActiveTool('text');
              document.getElementById('constrained-span').dispatchEvent(new MouseEvent('click', { bubbles: true }));
              window.OpenGraphite.setActiveTool('select');
              const afterGuards = document.getElementById('root').outerHTML;
              const validDataValue = window.OpenGraphite.setAttributeValue('data-value', 'value', ' 42 ');
              const validListValue = window.OpenGraphite.setAttributeValue('list-item', 'value', '7');
              select('heading');
              const grouped = window.OpenGraphite.runCommand('wrapFrame', {});
              const wrapper = document.getElementById('heading').parentElement;
              const second = window.OpenGraphite.collectNodes();
              return {
                first,
                second,
                beforeGuards,
                afterGuards,
                svgInsert,
                rowGroup,
                invalidMediaSource,
                invalidRoleHref,
                invalidOutputValue,
                invalidInputText,
                validDataValue,
                validListValue,
                dataValue: document.getElementById('data-value').getAttribute('value'),
                listValue: document.getElementById('list-item').getAttribute('value'),
                grouped,
                wrapperTag: wrapper ? wrapper.tagName.toLowerCase() : '',
                wrapperType: wrapper ? wrapper.getAttribute('data-og-type') : null,
                typeCount: document.querySelectorAll('[data-og-type]').length
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let first = try #require(payload["first"] as? [[String: Any]])
        let byStandardID = Dictionary(
            uniqueKeysWithValues: first.compactMap { node -> (String, [String: Any])? in
                guard let id = node["standardID"] as? String, !id.isEmpty else { return nil }
                return (id, node)
            }
        )
        let sourceByStandardID = Dictionary(
            uniqueKeysWithValues: sourceNodes.compactMap { node -> (String, OpenGraphiteAgentNode)? in
                guard let id = node.attributes["id"], !id.isEmpty else { return nil }
                return (id, node)
            }
        )
        let capabilityIDs = [
            "heading", "empty-link", "role-link", "button", "invalid-is", "input", "media",
            "media-wrapper", "svg-icon", "legacy", "editable-child", "editable-false",
            "output", "data-value", "optgroup", "safe-span", "constrained-span", "row",
            "cell", "list-item", "defs", "symbol", "svg-mask", "svg-gradient", "svg-text",
            "foreign-html"
        ]

        // 期待値：Shared/WebKit capabilityが一致し、legacy hintは分類を強制せず、禁止操作はbyte不変になる（Then）
        for id in capabilityIDs {
            let webNode = try #require(byStandardID[id])
            let sourceNode = try #require(sourceByStandardID[id])
            let webCapabilities = Set(try #require(webNode["capabilities"] as? [String]))
            #expect(webCapabilities == Set(sourceNode.capabilities.map(\.rawValue)))
        }
        let root = try #require(byStandardID["root"])
        let rootEvidence = try #require(root["capabilityEvidence"] as? [String: Any])
        #expect(rootEvidence["isProjectResourceRoot"] as? Bool == true)
        #expect(Set(try #require(root["capabilities"] as? [String])).contains("edit-layout"))
        #expect(!Set(try #require(root["capabilities"] as? [String])).contains("group"))

        let emptyLinkCapabilities = Set(try #require(byStandardID["empty-link"]?["capabilities"] as? [String]))
        let roleLinkCapabilities = Set(try #require(byStandardID["role-link"]?["capabilities"] as? [String]))
        let legacyCapabilities = Set(try #require(byStandardID["legacy"]?["capabilities"] as? [String]))
        let buttonEvidence = try #require(byStandardID["button"]?["capabilityEvidence"] as? [String: Any])
        let invalidIsEvidence = try #require(byStandardID["invalid-is"]?["capabilityEvidence"] as? [String: Any])
        let roleEvidence = try #require(byStandardID["role-link"]?["capabilityEvidence"] as? [String: Any])
        #expect(emptyLinkCapabilities.contains("edit-link"))
        #expect(roleLinkCapabilities.contains("edit-control"))
        #expect(!roleLinkCapabilities.contains("edit-link"))
        #expect(!legacyCapabilities.contains("edit-media"))
        #expect(buttonEvidence["isNativeControl"] as? Bool == true)
        #expect(buttonEvidence["isCustomElement"] as? Bool == true)
        #expect(invalidIsEvidence["isCustomElement"] as? Bool == false)
        #expect(roleEvidence["ariaRole"] as? String == "link")
        #expect(Set(try #require(byStandardID["editable-child"]?["capabilities"] as? [String])).contains("edit-text"))
        #expect(!Set(try #require(byStandardID["editable-false"]?["capabilities"] as? [String])).contains("edit-text"))
        #expect(!Set(try #require(byStandardID["optgroup"]?["capabilities"] as? [String])).contains("edit-text"))
        #expect(Set(try #require(byStandardID["safe-span"]?["capabilities"] as? [String])).contains("ungroup"))
        #expect(!Set(try #require(byStandardID["constrained-span"]?["capabilities"] as? [String])).contains("ungroup"))
        #expect(!Set(try #require(byStandardID["defs"]?["capabilities"] as? [String])).contains("receive-children"))
        for id in ["defs", "symbol", "svg-mask", "svg-gradient", "svg-text"] {
            #expect(Set(try #require(byStandardID[id]?["capabilities"] as? [String])).contains("edit-icon"))
        }
        #expect(Set(try #require(byStandardID["foreign-html"]?["capabilities"] as? [String])).contains("receive-children"))
        #expect(payload["beforeGuards"] as? String == payload["afterGuards"] as? String)
        #expect(payload["invalidMediaSource"] as? Bool == false)
        #expect(payload["invalidRoleHref"] as? Bool == false)
        #expect(payload["invalidOutputValue"] as? Bool == false)
        #expect(payload["invalidInputText"] as? Bool == false)
        #expect(payload["validDataValue"] as? Bool == true)
        #expect(payload["validListValue"] as? Bool == true)
        #expect(payload["dataValue"] as? String == " 42 ")
        #expect(payload["listValue"] as? String == "7")
        #expect((payload["svgInsert"] as? [String: Any])?["success"] as? Bool == false)
        #expect((payload["rowGroup"] as? [String: Any])?["success"] as? Bool == false)
        #expect((payload["grouped"] as? [String: Any])?["success"] as? Bool == true)
        #expect(payload["wrapperTag"] as? String == "div")
        #expect(payload["wrapperType"] is NSNull)
        #expect(payload["typeCount"] as? Int == 1)
    }

    /// 論理名（日本語）: WebCanvas重複annotation inspectionテスト
    /// 概要: 重複internal IDをstable selection keyとして使わず、各nodeを別session referenceで非侵襲inspectionできることを確認します。
    @Test("WebCanvasは重複internal ID nodeを別session referenceで収集する")
    func testWebCanvasUsesSessionReferencesForDuplicateInternalIDs() async throws {
        // コンディション：同じinternal IDを持つ2つの標準要素をWebViewへ読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            "<!doctype html><html><body><div data-og-id=\"duplicate-display\" data-og-internal-id=\"duplicate\">First</div><div data-og-id=\"duplicate-display\" data-og-internal-id=\"duplicate\">Second</div></body></html>",
            in: webView
        )
        let authoredValue = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
        let authoredHTML = try #require(authoredValue as? String)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：両nodeを収集し、先頭nodeへの通常mutationを試す（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const nodes = window.OpenGraphite.collectNodes().filter((node) => node.tagName === 'div');
              const unsafeSelection = window.OpenGraphite.selectNode('duplicate-display');
              window.OpenGraphite.selectNode(nodes[0].id);
              return {
                nodes,
                unsafeSelection,
                mutation: window.OpenGraphite.runCommand('flipHorizontal', {}),
                html: document.documentElement.outerHTML
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let nodes = try #require(payload["nodes"] as? [[String: Any]])
        let mutation = try #require(payload["mutation"] as? [String: Any])

        // 期待値：duplicate annotationは診断対象のまま各session keyへ分離され、通常操作がsourceを変更しない（Then）
        #expect(nodes.count == 2)
        #expect(nodes.allSatisfy { $0["referenceStability"] as? String == "session" })
        #expect(Set(nodes.compactMap { $0["id"] as? String }).count == 2)
        #expect(Set(nodes.compactMap { $0["reference"] as? String }).count == 2)
        #expect(payload["unsafeSelection"] as? Bool == false)
        #expect(mutation["requiresAdoption"] as? Bool == true)
        #expect(payload["html"] as? String == authoredHTML)
    }

    /// 論理名（日本語）: WebCanvas文書全体annotation一意性テスト
    /// 概要: partial annotationを持つbodyを収集し、非表示source nodeと重複するIDをstable扱いしないことを確認します。
    @Test("WebCanvasはannotated bodyを収集して文書全体でannotation一意性を判定する")
    func testWebCanvasCollectsAnnotatedBodyAndChecksDocumentWideIdentityUniqueness() async throws {
        // コンディション：partial bodyと、headおよびtemplate内容内のnodeとinternal IDが重複する表示nodeを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            """
            <!doctype html><html><head>
              <meta data-og-internal-id="head-duplicate">
            </head><body data-og-internal-id="body-node">
              <main data-og-internal-id="head-duplicate">Head duplicate</main>
              <section id="shared-standard" class="template-shared" data-og-internal-id="template-duplicate">Template duplicate</section>
              <aside class="special:only">Special class</aside>
              <nav id="123" class="unique-nav">Numeric standard ID</nav>
              <template><section id="shared-standard" class="template-shared" data-og-internal-id="template-duplicate">Inert duplicate</section></template>
            </body></html>
            """,
            in: webView
        )
        let authoredValue = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
        let authoredHTML = try #require(authoredValue as? String)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：nodeを収集し、excluded source nodeとIDが重複する表示nodeへの通常mutationを試す（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const nodes = window.OpenGraphite.collectNodes();
              const main = nodes.find((node) => node.tagName === 'main');
              const section = nodes.find((node) => node.tagName === 'section');
              window.OpenGraphite.selectNode(main.id);
              const mainMutation = window.OpenGraphite.runCommand('flipHorizontal', {});
              window.OpenGraphite.selectNode(section.id);
              const sectionMutation = window.OpenGraphite.runCommand('flipHorizontal', {});
              return {
                nodes,
                mainMutation,
                sectionMutation,
                html: document.documentElement.outerHTML
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let nodes = try #require(payload["nodes"] as? [[String: Any]])
        let body = try #require(nodes.first { $0["tagName"] as? String == "body" })
        let main = try #require(nodes.first { $0["tagName"] as? String == "main" })
        let section = try #require(nodes.first { $0["tagName"] as? String == "section" })
        let sectionLocator = try #require(section["locator"] as? [String: Any])
        let specialClassNode = try #require(nodes.first { $0["tagName"] as? String == "aside" })
        let specialClassLocator = try #require(specialClassNode["locator"] as? [String: Any])
        let numericIDNode = try #require(nodes.first { $0["standardID"] as? String == "123" })
        let numericIDLocator = try #require(numericIDNode["locator"] as? [String: Any])
        let mainMutation = try #require(payload["mainMutation"] as? [String: Any])
        let sectionMutation = try #require(payload["sectionMutation"] as? [String: Any])

        // 期待値：bodyはpartial stable nodeとして表示され、excluded nodeとの重複はsession/DOM path扱いでsourceを変更しない（Then）
        #expect(nodes.count == 5)
        #expect(body["annotationStatus"] as? String == "partial")
        #expect(body["referenceStability"] as? String == "stable")
        #expect(main["referenceStability"] as? String == "session")
        #expect(section["referenceStability"] as? String == "session")
        #expect(sectionLocator["selector"] as? String == nil)
        #expect((sectionLocator["domPath"] as? String)?.contains("section") == true)
        #expect(specialClassLocator["selector"] as? String == nil)
        #expect((specialClassLocator["domPath"] as? String)?.contains("aside") == true)
        #expect(numericIDLocator["selector"] as? String == "[id=\"123\"]")
        #expect(mainMutation["requiresAdoption"] as? Bool == true)
        #expect(sectionMutation["requiresAdoption"] as? Bool == true)
        #expect(payload["html"] as? String == authoredHTML)
    }

    /// 論理名（日本語）: WebCanvas非adopt sibling移動防止テスト
    /// 概要: stable nodeのmove/reorder先が未注釈の場合、DOMを先行変更せず明示adoptionを要求することを確認します。
    @Test("WebCanvasは未注釈siblingをtargetにmoveまたはreorderしない")
    func testWebCanvasDoesNotMoveRelativeToUnannotatedSibling() async throws {
        // コンディション：stable nodeの前後を未注釈siblingで挟んだauto layoutを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            """
            <!doctype html><html><head><style>
              #parent { display:flex; flex-direction:column; }
              #parent > div { display:block; width:160px; height:40px; }
            </style></head><body>
              <section id="parent" data-og-id="parent" data-og-internal-id="parent-node">
                <div id="before">Before</div>
                <div id="stable" data-og-id="stable" data-og-internal-id="stable-node">Stable</div>
                <div id="after">After</div>
              </section>
            </body></html>
            """,
            in: webView
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：move front/back commandと未注釈sibling方向へのpointer reorderを試す（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const parent = document.getElementById('parent');
              const stable = document.getElementById('stable');
              const beforeHTML = parent.outerHTML;
              const beforeOrder = Array.from(parent.children).map((child) => child.id).join(',');
              window.OpenGraphite.selectNode('stable');
              const moveFront = window.OpenGraphite.runCommand('moveFront', {});
              const moveBack = window.OpenGraphite.runCommand('moveBack', {});
              const rect = stable.getBoundingClientRect();
              const pointer = (type, target, buttons, y) => target.dispatchEvent(new PointerEvent(type, {
                bubbles: true,
                cancelable: true,
                pointerId: 901,
                pointerType: 'mouse',
                button: type === 'pointerdown' ? 0 : -1,
                buttons,
                clientX: rect.left + 8,
                clientY: y
              }));
              pointer('pointerdown', stable, 1, rect.top + 8);
              pointer('pointermove', document, 1, rect.bottom + 100);
              pointer('pointerup', document, 0, rect.bottom + 100);
              return {
                moveFront,
                moveBack,
                beforeHTML,
                afterHTML: parent.outerHTML,
                beforeOrder,
                afterOrder: Array.from(parent.children).map((child) => child.id).join(',')
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let moveFront = try #require(payload["moveFront"] as? [String: Any])
        let moveBack = try #require(payload["moveBack"] as? [String: Any])

        // 期待値：commandはadoption要求を返し、dragを含めDOM order/source表現が完全に維持される（Then）
        #expect(moveFront["requiresAdoption"] as? Bool == true)
        #expect(moveBack["requiresAdoption"] as? Bool == true)
        #expect(payload["afterOrder"] as? String == payload["beforeOrder"] as? String)
        #expect(payload["afterHTML"] as? String == payload["beforeHTML"] as? String)
    }

    /// 論理名（日本語）: 標準locale typographyプレビューテスト
    /// 概要: previewの`lang`切替が標準`:lang()`とfont inheritanceを再評価し、保存用sourceには一時状態を残さないことを検証します。
    @Test("preview localeは標準langとCSS cascadeだけでfont-familyを解決する")
    func testPreviewLocaleUsesStandardLanguageCascadeWithoutSourceMutation() async throws {
        // コンディション：default、任意BCP 47 locale、element overrideの標準font-family ruleを持つHTMLを読み込む（Given）
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320))
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html lang="ja" dir="ltr" data-og-lang-source="binding" data-og-lang-field="selectedLanguage" data-og-dir-source="auto">
          <head>
            <style>
              #page { font-family: "Default Face", sans-serif; }
              #page:lang("fr-CA") { font-family: "Locale Face", serif; }
              #override { font-family: "Element Face", monospace; }
            </style>
          </head>
          <body>
            <main id="page">
              <p id="inherited">Inherited</p>
              <p id="override">Override</p>
            </main>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        let authoredValue = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
        let authoredHTML = try #require(authoredValue as? String)
        let previewContext = OpenGraphitePreviewContext(fieldMocks: ["selectedLanguage": "fr-CA"])

        // 検証内容：Canvasと同じpreview context scriptを適用してcomputed fontと保存用cloneを取得する（When）
        _ = try await webView.evaluateJavaScript(WebCanvasView.previewContextScript(for: previewContext))
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const page = document.querySelector('#page');
              const inherited = document.querySelector('#inherited');
              const override = document.querySelector('#override');
              const localeFont = window.getComputedStyle(page).fontFamily;
              const inheritedFont = window.getComputedStyle(inherited).fontFamily;
              const overrideFont = window.getComputedStyle(override).fontFamily;
              document.documentElement.lang = 'ja';
              const defaultFontAfterStandardSwitch = window.getComputedStyle(page).fontFamily;
              document.documentElement.lang = 'fr-CA';

              const clone = document.documentElement.cloneNode(true);
              const original = window.__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__;
              if (original.hasLang) {
                clone.setAttribute('lang', original.lang);
              } else {
                clone.removeAttribute('lang');
              }
              if (original.hasDir) {
                clone.setAttribute('dir', original.dir);
              } else {
                clone.removeAttribute('dir');
              }

              return {
                lang: document.documentElement.lang,
                dir: document.documentElement.dir,
                localeFont,
                inheritedFont,
                overrideFont,
                defaultFontAfterStandardSwitch,
                hasActiveFontHelper: Array.from(document.querySelectorAll('*')).some((element) =>
                  element.style.getPropertyValue('--og-active-font-family') !== ''
                ),
                hasLegacyReapplyHook: typeof window.__OPENGRAPHITE_APPLY_LOCALE_FONT__ === 'function',
                serializedHTML: clone.outerHTML
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：locale/inheritance/element overrideは標準cascadeに従い、旧helperもsource差分も生じない（Then）
        #expect(payload["lang"] as? String == "fr-CA")
        #expect(payload["dir"] as? String == "ltr")
        #expect((payload["localeFont"] as? String)?.contains("Locale Face") == true)
        #expect((payload["inheritedFont"] as? String)?.contains("Locale Face") == true)
        #expect((payload["overrideFont"] as? String)?.contains("Element Face") == true)
        #expect((payload["defaultFontAfterStandardSwitch"] as? String)?.contains("Default Face") == true)
        #expect(payload["hasActiveFontHelper"] as? Bool == false)
        #expect(payload["hasLegacyReapplyHook"] as? Bool == false)
        #expect(payload["serializedHTML"] as? String == authoredHTML)
    }

    /// 論理名（日本語）: Media/Icon描画実体収集テスト
    /// 概要: wrapperから実体media/SVG/maskのrelationとcomputed標準CSSを返し、nested annotated subtreeやsourceを暗黙変更しないことを検証します。
    @Test("WebCanvasはmedia/icon実体の標準CSSとDOM relationを収集する")
    func testWebCanvasCollectsStandardRenderingTargetsWithoutSourceMutation() async throws {
        // コンディション：media、inline SVG、mask、nested annotated wrapper、legacy inputを持つHTMLをWebViewへ読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        let messageNames = [
            "openGraphiteNodes",
            "openGraphiteSelection",
            "openGraphiteContextMenu",
            "openGraphiteScrollState",
            "openGraphiteDocumentChange",
            "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks",
            "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay",
            "openGraphiteNodeDragPreview"
        ]
        for name in messageNames {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style>
              #media-image { object-fit: cover; width: 120px; height: 80px; }
              #inline-icon > svg > circle { stroke-width: 2.5; }
              #mask-icon > span {
                -webkit-mask-image: url("https://cdn.example.test/icons/star.svg");
                mask-image: url("https://cdn.example.test/icons/star.svg");
              }
              #nested-image { object-fit: contain; }
            </style>
          </head>
          <body>
            <MediaFrame id="media-frame" data-og-id="media" data-og-internal-id="media-node" data-og-type="image">
              <img id="media-image" data-og-internal-id="media-image-node" src="about:blank" alt="">
            </MediaFrame>
            <InlineIcon id="inline-icon" data-og-id="inline-icon" data-og-internal-id="inline-icon-node" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline">
              <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
            </InlineIcon>
            <MaskIcon id="mask-icon" data-og-id="mask-icon" data-og-internal-id="mask-icon-node" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="cdn">
              <span aria-hidden="true"></span>
            </MaskIcon>
            <OuterFrame data-og-id="outer" data-og-internal-id="outer-node" data-og-type="frame">
              <NestedMedia data-og-id="nested" data-og-internal-id="nested-node" data-og-type="image">
                <img id="nested-image" src="about:blank" alt="">
              </NestedMedia>
            </OuterFrame>
            <LegacyMedia data-og-id="legacy" data-og-internal-id="legacy-node" data-og-type="image" style="mask-image:url(&quot;data:image/svg+xml;utf8,%3Csvg%3E%3C/svg%3E&quot;); --og-object-fit:scale-down; --og-stroke-width:8; --og-icon-url:url('legacy.svg');">
              <img src="about:blank" alt=""><span data-og-icon-mask="true"></span>
            </LegacyMedia>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        let authoredValue = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
        let authoredHTML = try #require(authoredValue as? String)

        // 検証内容：実アプリと同じWebCanvas bridgeでnode payloadと収集後sourceを取得する（When）
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        let result = try await webView.evaluateJavaScript(
            """
            (() => ({
              nodes: window.OpenGraphite.collectNodes(),
              html: document.documentElement.outerHTML
            }))();
            """
        )
        let payload = try #require(result as? [String: Any])
        let nodes = try #require(payload["nodes"] as? [[String: Any]])
        let mediaNode = try #require(nodes.first { $0["id"] as? String == "media" })
        let inlineIconNode = try #require(nodes.first { $0["id"] as? String == "inline-icon" })
        let maskIconNode = try #require(nodes.first { $0["id"] as? String == "mask-icon" })
        let outerNode = try #require(nodes.first { $0["id"] as? String == "outer" })
        let nestedNode = try #require(nodes.first { $0["id"] as? String == "nested" })
        let legacyNode = try #require(nodes.first { $0["id"] as? String == "legacy" })
        let mediaTarget = try #require(
            (mediaNode["renderingTargets"] as? [[String: Any]])?.first { $0["kind"] as? String == "media" }
        )
        let svgTarget = try #require(
            (inlineIconNode["renderingTargets"] as? [[String: Any]])?.first {
                $0["kind"] as? String == "svg"
                    && $0["relationSelector"] as? String == ":scope > svg > circle"
            }
        )
        let maskTarget = try #require(
            (maskIconNode["renderingTargets"] as? [[String: Any]])?.first { $0["kind"] as? String == "mask" }
        )
        let nestedTarget = try #require(
            (nestedNode["renderingTargets"] as? [[String: Any]])?.first { $0["kind"] as? String == "media" }
        )
        let mediaComputed = try #require(mediaTarget["computedValues"] as? [String: String])
        let svgComputed = try #require(svgTarget["computedValues"] as? [String: String])
        let maskComputed = try #require(maskTarget["computedValues"] as? [String: String])
        let legacyCSSValues = try #require(legacyNode["cssVariables"] as? [String: String])

        // 期待値：標準propertyと相対relationを返し、outerはnested targetを横取りせず、legacy source/annotationも変更しない（Then）
        #expect(mediaTarget["tagName"] as? String == "img")
        #expect(mediaTarget["relation"] as? String == "direct-child")
        #expect(mediaTarget["relationSelector"] as? String == ":scope > img")
        #expect(mediaTarget["targetStandardID"] as? String == "media-image")
        #expect(mediaTarget["targetInternalID"] as? String == "media-image-node")
        #expect(mediaComputed["object-fit"] == "cover")
        #expect(svgTarget["tagName"] as? String == "circle")
        #expect(svgTarget["relationSelector"] as? String == ":scope > svg > circle")
        #expect(svgComputed["stroke-width"]?.contains("2.5") == true)
        #expect(maskTarget["tagName"] as? String == "span")
        #expect(maskTarget["relationSelector"] as? String == ":scope > span")
        #expect(maskComputed["mask-image"]?.contains("star.svg") == true)
        #expect(maskComputed["-webkit-mask-image"]?.contains("star.svg") == true)
        #expect((outerNode["renderingTargets"] as? [[String: Any]])?.isEmpty == true)
        #expect(nestedTarget["relationSelector"] as? String == ":scope > img")
        #expect(legacyCSSValues["mask-image"]?.contains("svg+xml;utf8") == true)
        #expect(payload["html"] as? String == authoredHTML)
        #expect((payload["html"] as? String)?.contains("data-og-icon-mask=\"true\"") == true)
        #expect((payload["html"] as? String)?.contains("--og-object-fit:scale-down") == true)
        #expect((payload["html"] as? String)?.contains("--og-icon-url:url('legacy.svg')") == true)
    }

    /// 論理名（日本語）: WebCanvas標準scale反転テスト
    /// 概要: 1/2/3値、percentage、none、raw computed値を標準`scale`で反転し、既存transform/rotateと!importantを保持することを検証します。
    @Test("WebCanvasのflipは標準scaleを構文安全に反転して既存transformを保つ")
    func testWebCanvasFlipUsesStandardScaleAndPreservesTransformComposition() async throws {
        // コンディション：多様な標準scale値、外部/inline important、既存transform/rotateを持つnodeを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        let messageNames = [
            "openGraphiteNodes",
            "openGraphiteSelection",
            "openGraphiteContextMenu",
            "openGraphiteScrollState",
            "openGraphiteDocumentChange",
            "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks",
            "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay",
            "openGraphiteNodeDragPreview"
        ]
        for name in messageNames {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style id="design-rules">
              :root { --raw-scale: 1.4 0.6; }
              Card { display: block; width: 20px; height: 20px; }
              #external-important { scale: 1.5 0.75 !important; transform: skewX(3deg); rotate: 13deg; }
              #animated { scale: 1.1 0.9; animation: scale-pulse 10s linear -5s paused; }
              @keyframes scale-pulse { from { scale: 3 3; } to { scale: 5 5; } }
            </style>
          </head>
          <body>
            <Card id="one" data-og-id="one" data-og-internal-id="one-node" data-og-type="frame" style="scale:2; transform:translateX(7px) rotate(3deg); rotate:11deg;"></Card>
            <Card id="percentage" data-og-id="percentage" data-og-internal-id="percentage-node" data-og-type="frame" style="scale:120% 80%; transform:matrix(1, 0, 0, 1, 4, 5); rotate:-7deg;"></Card>
            <Card id="three" data-og-id="three" data-og-internal-id="three-node" data-og-type="frame" style="scale:2 3 4; transform:perspective(400px); rotate:4deg 1 0 25deg;"></Card>
            <Card id="none" data-og-id="none" data-og-internal-id="none-node" data-og-type="frame" style="scale:none; transform:translateY(2px); rotate:0deg;"></Card>
            <Card id="raw" data-og-id="raw" data-og-internal-id="raw-node" data-og-type="frame" style="scale:var(--raw-scale); transform:rotate(0.125turn); rotate:2deg;"></Card>
            <Card id="external-important" data-og-id="external-important" data-og-internal-id="external-node" data-og-type="frame"></Card>
            <Card id="inline-important" data-og-id="inline-important" data-og-internal-id="inline-node" data-og-type="frame" style="scale:1.6 0.5 !important; transform:translate3d(1px,2px,0); rotate:9deg;"></Card>
            <Card id="animated" data-og-id="animated" data-og-internal-id="animated-node" data-og-type="frame" style="transform:translateX(1px); rotate:6deg;"></Card>
            <Card id="absent" data-og-id="absent" data-og-internal-id="absent-node" data-og-type="frame" style="transform:translateY(1px); rotate:8deg;"></Card>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：各nodeを水平または垂直反転してから同じ反転を再実行する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              function parsedScale(value) {
                const normalized = String(value || '').trim().toLowerCase();
                if (!normalized || normalized === 'none') { return [1, 1, 1]; }
                const tokens = normalized.split(/\\s+/).filter((token) => token.length > 0);
                if (tokens.length < 1 || tokens.length > 3) { return null; }
                const values = tokens.map((token) => {
                  const number = Number.parseFloat(token);
                  if (!Number.isFinite(number)) { return null; }
                  return token.endsWith('%') ? number / 100 : number;
                });
                if (values.some((number) => number === null)) { return null; }
                if (values.length === 1) { return [values[0], values[0], 1]; }
                if (values.length === 2) { return [values[0], values[1], 1]; }
                return values;
              }
              function equivalentScale(first, second) {
                const firstValues = parsedScale(first);
                const secondValues = parsedScale(second);
                return !!firstValues && !!secondValues && firstValues.every((value, index) =>
                  Math.abs(value - secondValues[index]) < 0.000001
                );
              }
              function canonicalScale(value, priority) {
                const probe = document.createElement('div');
                probe.style.setProperty('scale', value, priority || '');
                return probe.style.getPropertyValue('scale');
              }
              const cases = [
                ['one', 'flipHorizontal', true, '2'],
                ['percentage', 'flipVertical', true, '120% 80%'],
                ['three', 'flipHorizontal', true, '2 3 4'],
                ['none', 'flipHorizontal', true, 'none'],
                ['raw', 'flipHorizontal', true, 'var(--raw-scale)'],
                ['external-important', 'flipHorizontal', true, '1.5 0.75'],
                ['inline-important', 'flipVertical', true, '1.6 0.5'],
                ['animated', 'flipHorizontal', true, '1.1 0.9'],
                ['absent', 'flipHorizontal', false, '']
              ];
              const results = {};
              cases.forEach(([id, command, hasAuthoredScale, authoredScale]) => {
                const element = document.getElementById(id);
                const before = {
                  html: element.outerHTML,
                  scale: element.style.getPropertyValue('scale'),
                  transform: element.style.getPropertyValue('transform'),
                  rotate: element.style.getPropertyValue('rotate'),
                  computedScale: getComputedStyle(element).getPropertyValue('scale') || 'none'
                };
                window.OpenGraphite.selectNode(id);
                const first = window.OpenGraphite.runCommand(command, { hasAuthoredScale, authoredScale });
                const firstScale = element.style.getPropertyValue('scale');
                const firstComputedScale = getComputedStyle(element).getPropertyValue('scale') || 'none';
                const firstPriority = element.style.getPropertyPriority('scale');
                const second = first && first.success
                  ? window.OpenGraphite.runCommand(command, {
                      hasAuthoredScale: true,
                      authoredScale: first.edit.value
                    })
                  : null;
                results[id] = {
                  firstScale,
                  firstComputedScale,
                  firstPriority,
                  firstEditValue: first && first.edit ? first.edit.value : '',
                  firstScaleMatchesEdit: !!(first && first.edit) &&
                    firstScale === canonicalScale(first.edit.value, firstPriority),
                  firstComputedMatchesEdit: !!(first && first.edit) &&
                    equivalentScale(firstComputedScale, first.edit.value),
                  secondScale: element.style.getPropertyValue('scale'),
                  secondComputedScale: getComputedStyle(element).getPropertyValue('scale') || 'none',
                  secondPriority: element.style.getPropertyPriority('scale'),
                  secondEditValue: second && second.edit ? second.edit.value : '',
                  secondScaleMatchesEdit: !!(second && second.edit) &&
                    element.style.getPropertyValue('scale') === canonicalScale(
                      second.edit.value,
                      element.style.getPropertyPriority('scale')
                    ),
                  secondComputedMatchesInitial: !!(second && second.edit) &&
                    equivalentScale(
                      getComputedStyle(element).getPropertyValue('scale') || 'none',
                      before.computedScale
                    ),
                  initialComputedScale: before.computedScale,
                  sourcePreservedOnFailure: !first || first.success ||
                    (element.outerHTML === before.html && element.style.getPropertyValue('scale') === before.scale),
                  transformPreserved: element.style.getPropertyValue('transform') === before.transform,
                  rotatePreserved: element.style.getPropertyValue('rotate') === before.rotate,
                  firstEditKey: first && first.edit ? first.edit.key : '',
                  secondEditKey: second && second.edit ? second.edit.key : '',
                  succeeded: !!(first && first.success && second && second.success),
                  rejected: !!(first && !first.success)
                };
              });
              return {
                results,
                designRuleSource: document.getElementById('design-rules').textContent
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let results = try #require(payload["results"] as? [String: Any])
        func result(_ id: String) throws -> [String: Any] {
            try #require(results[id] as? [String: Any])
        }
        let one = try result("one")
        let percentage = try result("percentage")
        let three = try result("three")
        let none = try result("none")
        let raw = try result("raw")
        let externalImportant = try result("external-important")
        let inlineImportant = try result("inline-important")
        let animated = try result("animated")
        let absent = try result("absent")

        // 期待値：全caseが単一scale propertyを使い、2回反転で元の視覚値へ戻り、他のtransform source bytesを変えない（Then）
        #expect(one["firstEditValue"] as? String == "-2 2")
        #expect(one["secondEditValue"] as? String == "2 2")
        #expect(percentage["firstEditValue"] as? String == "120% -80%")
        #expect(percentage["secondEditValue"] as? String == "120% 80%")
        #expect(three["firstEditValue"] as? String == "-2 3 4")
        #expect(three["secondEditValue"] as? String == "2 3 4")
        #expect(none["firstEditValue"] as? String == "-1 1")
        #expect(none["secondEditValue"] as? String == "1 1")
        #expect(raw["rejected"] as? Bool == true)
        #expect(raw["sourcePreservedOnFailure"] as? Bool == true)
        #expect(raw["firstScale"] as? String == "var(--raw-scale)")
        #expect(externalImportant["firstPriority"] as? String == "important")
        #expect(externalImportant["firstComputedMatchesEdit"] as? Bool == true)
        #expect(externalImportant["secondComputedMatchesInitial"] as? Bool == true)
        #expect(inlineImportant["firstPriority"] as? String == "important")
        #expect(inlineImportant["secondPriority"] as? String == "important")
        #expect(animated["firstEditValue"] as? String == "-1.1 0.9")
        #expect(animated["secondEditValue"] as? String == "1.1 0.9")
        #expect((animated["initialComputedScale"] as? String) != "1.1 0.9")
        #expect(absent["firstEditValue"] as? String == "-1 1")
        #expect(absent["secondEditValue"] as? String == "1 1")
        for id in ["one", "percentage", "three", "none", "external-important", "inline-important", "animated", "absent"] {
            let item = try result(id)
            #expect(item["succeeded"] as? Bool == true)
            #expect(item["firstScaleMatchesEdit"] as? Bool == true)
            #expect(item["secondScaleMatchesEdit"] as? Bool == true)
            #expect(item["firstEditKey"] as? String == "scale")
            #expect(item["secondEditKey"] as? String == "scale")
            #expect(item["transformPreserved"] as? Bool == true)
            #expect(item["rotatePreserved"] as? Bool == true)
        }
        #expect(raw["transformPreserved"] as? Bool == true)
        #expect(raw["rotatePreserved"] as? Bool == true)
        #expect((payload["designRuleSource"] as? String)?.contains("scale: 1.5 0.75 !important") == true)
        #expect((payload["designRuleSource"] as? String)?.contains("transform: skewX(3deg); rotate: 13deg;") == true)
    }

    /// 論理名（日本語）: WebCanvas drag/reorder一時移動テスト
    /// 概要: position dragをWAAPI additive translate、reorderを一時translate/WAAPIとして扱い、serializationへ混入させないことを検証します。
    @Test("dragとreorderの一時translateはdesign sourceへ混入しない")
    func testWebCanvasDragAndReorderKeepTransientTranslationsOutOfSerialization() async throws {
        // コンディション：authored translateとtransform familyを持つposition/reorder対象を読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        let messageNames = [
            "openGraphiteNodes",
            "openGraphiteSelection",
            "openGraphiteContextMenu",
            "openGraphiteScrollState",
            "openGraphiteDocumentChange",
            "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks",
            "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay",
            "openGraphiteNodeDragPreview"
        ]
        for name in messageNames {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 520), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style>
              html, body { margin: 0; width: 640px; min-height: 520px; }
              #position-parent { position: relative; width: 260px; height: 180px; }
              #position-card { width: 60px; height: 50px; }
              #reorder-parent { display: flex; flex-direction: column; position:relative; width: 220px; gap: 8px; }
              #reorder-parent > Card { display: block; width: 180px; height: 44px; }
            </style>
          </head>
          <body>
            <Section id="position-parent" data-og-id="position-parent" data-og-internal-id="position-parent-node" data-og-type="frame">
              <Card id="position-card" data-og-id="position-card" data-og-internal-id="position-card-node" data-og-type="frame" style="position:absolute; left:10px; top:15px; translate:3px 2px; transform:rotate(5deg); rotate:7deg; scale:1.2 0.8;"></Card>
            </Section>
            <Stack id="reorder-parent" data-og-id="reorder-parent" data-og-internal-id="reorder-parent-node" data-og-type="frame">
              <Card id="reorder-a" data-og-id="reorder-a" data-og-internal-id="reorder-a-node" data-og-type="frame" style="translate:4px 1px; transform:skewX(2deg); rotate:3deg; scale:0.9 1.1;">A</Card>
              <Card id="reorder-b" data-og-id="reorder-b" data-og-internal-id="reorder-b-node" data-og-type="frame">B</Card>
              <Card id="reorder-c" data-og-id="reorder-c" data-og-internal-id="reorder-c-node" data-og-type="frame">C</Card>
              <Card id="reorder-floating" data-og-id="reorder-floating" data-og-internal-id="reorder-floating-node" data-og-type="frame" style="position:absolute; left:200px; top:12px;">Floating</Card>
            </Stack>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(
            """
            window.__openGraphiteAnimationCalls = [];
            window.__openGraphiteOriginalAnimate = Element.prototype.animate;
            Element.prototype.animate = function(keyframes, options) {
              const frames = Array.isArray(keyframes) ? keyframes : [];
              window.__openGraphiteAnimationCalls.push({
                id: this.id || this.getAttribute('data-og-id') || '',
                hasTranslate: frames.some((frame) => frame && Object.prototype.hasOwnProperty.call(frame, 'translate')),
                composite: options && options.composite ? String(options.composite) : ''
              });
              return window.__openGraphiteOriginalAnimate.call(this, keyframes, options);
            };
            true;
            """
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：position dragとreorder dragの途中でserialization suspensionを実行し、終了状態まで観測する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              function pointer(type, target, pointerId, x, y, buttons) {
                const event = new PointerEvent(type, {
                  bubbles: true,
                  cancelable: true,
                  pointerId,
                  pointerType: 'mouse',
                  button: type === 'pointerdown' ? 0 : -1,
                  buttons,
                  clientX: x,
                  clientY: y
                });
                target.dispatchEvent(event);
              }

              const position = document.getElementById('position-card');
              const positionRect = position.getBoundingClientRect();
              const positionBeforeHTML = position.outerHTML;
              const positionBefore = {
                translate: position.style.getPropertyValue('translate'),
                transform: position.style.getPropertyValue('transform'),
                rotate: position.style.getPropertyValue('rotate'),
                scale: position.style.getPropertyValue('scale')
              };
              window.OpenGraphite.selectNode('position-card');
              window.__openGraphiteAnimationCalls = [];
              pointer('pointerdown', position, 101, positionRect.left + 8, positionRect.top + 8, 1);
              pointer('pointermove', document, 101, positionRect.left + 33, positionRect.top + 38, 1);
              const positionLiveHTML = position.outerHTML;
              const positionState = window.OpenGraphite.suspendTransientStateForSerialization();
              const positionSuspendedHTML = position.outerHTML;
              window.OpenGraphite.resumeTransientStateAfterSerialization(positionState);
              pointer('pointerup', document, 101, positionRect.left + 33, positionRect.top + 38, 0);
              const positionAnimationCalls = window.__openGraphiteAnimationCalls.slice();
              const positionAfter = {
                html: position.outerHTML,
                left: position.style.getPropertyValue('left'),
                top: position.style.getPropertyValue('top'),
                translate: position.style.getPropertyValue('translate'),
                transform: position.style.getPropertyValue('transform'),
                rotate: position.style.getPropertyValue('rotate'),
                scale: position.style.getPropertyValue('scale')
              };

              const reorderParent = document.getElementById('reorder-parent');
              const reorder = document.getElementById('reorder-a');
              const reorderRect = reorder.getBoundingClientRect();
              const reorderBeforeHTML = reorderParent.outerHTML;
              const reorderBeforeTargetHTML = reorder.outerHTML;
              const reorderBeforeOrder = Array.from(reorderParent.children).map((child) => child.id).join(',');
              const reorderDesign = {
                translate: reorder.style.getPropertyValue('translate'),
                transform: reorder.style.getPropertyValue('transform'),
                rotate: reorder.style.getPropertyValue('rotate'),
                scale: reorder.style.getPropertyValue('scale')
              };
              window.OpenGraphite.selectNode('reorder-a');
              window.__openGraphiteAnimationCalls = [];
              pointer('pointerdown', reorder, 202, reorderRect.left + 10, reorderRect.top + 10, 1);
              pointer('pointermove', document, 202, reorderRect.left + 10, reorderRect.top + 150, 1);
              const reorderLiveOrder = Array.from(reorderParent.children).map((child) => child.id).join(',');
              const reorderLiveTargetHTML = reorder.outerHTML;
              const reorderState = window.OpenGraphite.suspendTransientStateForSerialization();
              const reorderSuspendedHTML = reorderParent.outerHTML;
              const reorderSuspendedTargetHTML = reorder.outerHTML;
              const reorderSuspendedOrder = Array.from(reorderParent.children).map((child) => child.id).join(',');
              window.OpenGraphite.resumeTransientStateAfterSerialization(reorderState);
              const reorderResumedOrder = Array.from(reorderParent.children).map((child) => child.id).join(',');
              pointer('pointerup', document, 202, reorderRect.left + 10, reorderRect.top + 150, 0);
              const reorderAnimationCalls = window.__openGraphiteAnimationCalls.slice();
              const reorderAfterOrder = Array.from(reorderParent.children).map((child) => child.id).join(',');
              const reorderAfterTargetHTML = reorder.outerHTML;
              const reorderAfter = {
                translate: reorder.style.getPropertyValue('translate'),
                transform: reorder.style.getPropertyValue('transform'),
                rotate: reorder.style.getPropertyValue('rotate'),
                scale: reorder.style.getPropertyValue('scale')
              };

              return {
                positionBeforeHTML,
                positionLiveHTML,
                positionSuspendedHTML,
                positionBefore,
                positionAfter,
                positionAnimationCalls,
                reorderBeforeHTML,
                reorderBeforeTargetHTML,
                reorderLiveTargetHTML,
                reorderSuspendedHTML,
                reorderSuspendedTargetHTML,
                reorderBeforeOrder,
                reorderLiveOrder,
                reorderSuspendedOrder,
                reorderResumedOrder,
                reorderAfterOrder,
                reorderAfterTargetHTML,
                reorderDesign,
                reorderAfter,
                reorderAnimationCalls
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let positionBefore = try #require(payload["positionBefore"] as? [String: Any])
        let positionAfter = try #require(payload["positionAfter"] as? [String: Any])
        let reorderDesign = try #require(payload["reorderDesign"] as? [String: Any])
        let reorderAfter = try #require(payload["reorderAfter"] as? [String: Any])
        let positionAnimationCalls = try #require(payload["positionAnimationCalls"] as? [[String: Any]])
        let reorderAnimationCalls = try #require(payload["reorderAnimationCalls"] as? [[String: Any]])

        // 期待値：drag中sourceは無変更、終了時はleft/topだけ保存され、authored translate/transform/rotate/scaleを保つ（Then）
        #expect((payload["positionLiveHTML"] as? String) == (payload["positionBeforeHTML"] as? String))
        #expect((payload["positionSuspendedHTML"] as? String) == (payload["positionBeforeHTML"] as? String))
        #expect(positionAfter["left"] as? String == "35px")
        #expect(positionAfter["top"] as? String == "45px")
        for property in ["translate", "transform", "rotate", "scale"] {
            #expect((positionAfter[property] as? String) == (positionBefore[property] as? String))
        }
        #expect(positionAnimationCalls.contains { call in
            (call["hasTranslate"] as? Bool) == true && (call["composite"] as? String) == "add"
        })

        // 期待値：reorder serialization時だけ元order/design translateへ戻り、終了後はorderだけを永続化する（Then）
        #expect(payload["reorderBeforeOrder"] as? String == "reorder-a,reorder-b,reorder-c,reorder-floating")
        #expect((payload["reorderLiveOrder"] as? String) != (payload["reorderBeforeOrder"] as? String))
        #expect((payload["reorderSuspendedOrder"] as? String) == (payload["reorderBeforeOrder"] as? String))
        #expect((payload["reorderResumedOrder"] as? String) == (payload["reorderLiveOrder"] as? String))
        #expect((payload["reorderAfterOrder"] as? String) == (payload["reorderLiveOrder"] as? String))
        #expect((payload["reorderAfterOrder"] as? String)?.hasSuffix("reorder-floating") == true)
        #expect((payload["reorderSuspendedHTML"] as? String) == (payload["reorderBeforeHTML"] as? String))
        #expect((payload["reorderLiveTargetHTML"] as? String) == (payload["reorderBeforeTargetHTML"] as? String))
        #expect((payload["reorderSuspendedTargetHTML"] as? String) == (payload["reorderBeforeTargetHTML"] as? String))
        #expect((payload["reorderAfterTargetHTML"] as? String) == (payload["reorderBeforeTargetHTML"] as? String))
        for property in ["translate", "transform", "rotate", "scale"] {
            #expect((reorderAfter[property] as? String) == (reorderDesign[property] as? String))
        }
        #expect(reorderAnimationCalls.contains { call in
            (call["id"] as? String) == "reorder-a"
                && (call["hasTranslate"] as? Bool) == true
                && (call["composite"] as? String) == "add"
        })
    }

    /// 論理名（日本語）: WebCanvas実測visual order並べ替えテスト
    /// 概要: nowrap flexのnormal/reverse/RTLを実測中心順からDOM insertionへ変換し、wrapとexplicit gridは変更しないことを検証します。
    @Test("reorderはnowrap flexのvisual orderに従いwrapとexplicit gridを変更しない")
    func testWebCanvasReorderUsesMeasuredFlexOrderAndRejectsAmbiguousLayouts() async throws {
        // コンディション：normal/reverse/RTLの単一行flexと、安全に並べ替えられないwrap/explicit gridを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        let messageNames = [
            "openGraphiteNodes",
            "openGraphiteSelection",
            "openGraphiteContextMenu",
            "openGraphiteScrollState",
            "openGraphiteDocumentChange",
            "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks",
            "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay",
            "openGraphiteNodeDragPreview"
        ]
        for name in messageNames {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 720), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style>
              html, body { margin: 0; width: 900px; min-height: 720px; }
              body { display: grid; grid-template-columns: repeat(3, 250px); gap: 20px; padding: 12px; }
              .case { gap: 8px; padding: 4px; border: 1px solid transparent; }
              .case > Card { width: 54px; height: 30px; }
              .row { display: flex; flex-flow: row nowrap; }
              .row-reverse { display: flex; flex-flow: row-reverse nowrap; }
              .row-rtl { display: flex; flex-flow: row nowrap; direction: rtl; }
              .column { display: flex; flex-flow: column nowrap; height: 130px; }
              .column-reverse { display: flex; flex-flow: column-reverse nowrap; height: 130px; }
              .wrapped { display: flex; flex-flow: row wrap; width: 90px; }
              .auto-grid { display: grid; grid-template-columns: repeat(3, 54px); grid-auto-flow: row; }
              .explicit-grid { display: grid; grid-template-columns: repeat(3, 54px); }
              .explicit-grid > Card:first-child { grid-column: 2; }
            </style>
          </head>
          <body>
            <Stack id="row" class="case row" data-og-internal-id="row-node">
              <Card id="row-a" data-og-id="row-a" data-og-internal-id="row-a-node" style="translate:1px 2px; color:rgb(1, 2, 3);" data-vendor="row a">A</Card>
              <Card id="row-b" data-og-id="row-b" data-og-internal-id="row-b-node" style="translate:2px 3px;">B</Card>
              <Card id="row-c" data-og-id="row-c" data-og-internal-id="row-c-node" style="translate:3px 4px;">C</Card>
            </Stack>
            <Stack id="row-reverse" class="case row-reverse" data-og-internal-id="row-reverse-node">
              <Card id="row-reverse-a" data-og-id="row-reverse-a" data-og-internal-id="row-reverse-a-node" style="translate:1px 2px;">A</Card>
              <Card id="row-reverse-b" data-og-id="row-reverse-b" data-og-internal-id="row-reverse-b-node" style="translate:2px 3px;">B</Card>
              <Card id="row-reverse-c" data-og-id="row-reverse-c" data-og-internal-id="row-reverse-c-node" style="translate:3px 4px; color:rgb(4, 5, 6);" data-vendor="reverse c">C</Card>
            </Stack>
            <Stack id="row-rtl" class="case row-rtl" data-og-internal-id="row-rtl-node">
              <Card id="row-rtl-a" data-og-id="row-rtl-a" data-og-internal-id="row-rtl-a-node" style="translate:1px 2px;">A</Card>
              <Card id="row-rtl-b" data-og-id="row-rtl-b" data-og-internal-id="row-rtl-b-node" style="translate:2px 3px;">B</Card>
              <Card id="row-rtl-c" data-og-id="row-rtl-c" data-og-internal-id="row-rtl-c-node" style="translate:3px 4px;">C</Card>
            </Stack>
            <Stack id="column" class="case column" data-og-internal-id="column-node">
              <Card id="column-a" data-og-id="column-a" data-og-internal-id="column-a-node" style="translate:1px 2px;">A</Card>
              <Card id="column-b" data-og-id="column-b" data-og-internal-id="column-b-node" style="translate:2px 3px;">B</Card>
              <Card id="column-c" data-og-id="column-c" data-og-internal-id="column-c-node" style="translate:3px 4px;">C</Card>
            </Stack>
            <Stack id="column-reverse" class="case column-reverse" data-og-internal-id="column-reverse-node">
              <Card id="column-reverse-a" data-og-id="column-reverse-a" data-og-internal-id="column-reverse-a-node" style="translate:1px 2px;">A</Card>
              <Card id="column-reverse-b" data-og-id="column-reverse-b" data-og-internal-id="column-reverse-b-node" style="translate:2px 3px;">B</Card>
              <Card id="column-reverse-c" data-og-id="column-reverse-c" data-og-internal-id="column-reverse-c-node" style="translate:3px 4px;">C</Card>
            </Stack>
            <Stack id="wrapped" class="case wrapped" data-og-internal-id="wrapped-node">
              <Card id="wrapped-a" data-og-id="wrapped-a" data-og-internal-id="wrapped-a-node">A</Card>
              <Card id="wrapped-b" data-og-id="wrapped-b" data-og-internal-id="wrapped-b-node">B</Card>
              <Card id="wrapped-c" data-og-id="wrapped-c" data-og-internal-id="wrapped-c-node">C</Card>
            </Stack>
            <Stack id="auto-grid" class="case auto-grid" data-og-internal-id="auto-grid-node">
              <Card id="auto-grid-a" data-og-id="auto-grid-a" data-og-internal-id="auto-grid-a-node" style="translate:1px 2px;">A</Card>
              <Card id="auto-grid-b" data-og-id="auto-grid-b" data-og-internal-id="auto-grid-b-node" style="translate:2px 3px;">B</Card>
              <Card id="auto-grid-c" data-og-id="auto-grid-c" data-og-internal-id="auto-grid-c-node" style="translate:3px 4px;">C</Card>
            </Stack>
            <Stack id="explicit-grid" class="case explicit-grid" data-og-internal-id="explicit-grid-node">
              <Card id="explicit-grid-a" data-og-id="explicit-grid-a" data-og-internal-id="explicit-grid-a-node">A</Card>
              <Card id="explicit-grid-b" data-og-id="explicit-grid-b" data-og-internal-id="explicit-grid-b-node">B</Card>
              <Card id="explicit-grid-c" data-og-id="explicit-grid-c" data-og-internal-id="explicit-grid-c-node">C</Card>
            </Stack>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：各caseのvisual先頭を末尾へdragし、DOM orderと各childのauthored bytesを取得する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              function pointer(type, target, pointerId, x, y, buttons) {
                target.dispatchEvent(new PointerEvent(type, {
                  bubbles: true,
                  cancelable: true,
                  pointerId,
                  pointerType: 'mouse',
                  button: type === 'pointerdown' ? 0 : -1,
                  buttons,
                  clientX: x,
                  clientY: y
                }));
              }

              function axisFor(parent) {
                const style = getComputedStyle(parent);
                if (style.display.includes('flex')) {
                  return style.flexDirection.startsWith('row') ? 'x' : 'y';
                }
                if (style.display.includes('grid')) {
                  return style.gridAutoFlow.startsWith('column') ? 'y' : 'x';
                }
                return 'y';
              }

              function center(element, axis) {
                const rect = element.getBoundingClientRect();
                return axis === 'x' ? rect.left + rect.width / 2 : rect.top + rect.height / 2;
              }

              function childMarkup(parent) {
                return Object.fromEntries(Array.from(parent.children).map((child) => [child.id, child.outerHTML]));
              }

              function order(parent) {
                return Array.from(parent.children).map((child) => child.id).join(',');
              }

              function dragVisualFirstToEnd(parentID, pointerId) {
                const parent = document.getElementById(parentID);
                const axis = axisFor(parent);
                const beforeOrder = order(parent);
                const beforeMarkup = childMarkup(parent);
                const visual = Array.from(parent.children).sort((first, second) => center(first, axis) - center(second, axis));
                const dragged = visual[0];
                const target = visual[visual.length - 1];
                const draggedRect = dragged.getBoundingClientRect();
                const targetRect = target.getBoundingClientRect();
                const startX = draggedRect.left + draggedRect.width / 2;
                const startY = draggedRect.top + draggedRect.height / 2;
                const endX = axis === 'x' ? targetRect.right + 24 : startX;
                const endY = axis === 'y' ? targetRect.bottom + 24 : startY;
                window.OpenGraphite.selectNode(dragged.getAttribute('data-og-id'));
                pointer('pointerdown', dragged, pointerId, startX, startY, 1);
                pointer('pointermove', document, pointerId, endX, endY, 1);
                pointer('pointerup', document, pointerId, endX, endY, 0);
                const afterMarkup = childMarkup(parent);
                return {
                  beforeOrder,
                  beforeVisualOrder: visual.map((child) => child.id).join(','),
                  afterOrder: order(parent),
                  sourceBytesPreserved: Object.keys(beforeMarkup).every((id) => beforeMarkup[id] === afterMarkup[id]),
                  inlineTranslatePreserved: Object.keys(beforeMarkup).every((id) => {
                    const authoredStyle = beforeMarkup[id].match(/style="([^"]*)"/);
                    return !authoredStyle || afterMarkup[id].includes(authoredStyle[0]);
                  })
                };
              }

              return {
                row: dragVisualFirstToEnd('row', 301),
                rowReverse: dragVisualFirstToEnd('row-reverse', 302),
                rowRTL: dragVisualFirstToEnd('row-rtl', 303),
                column: dragVisualFirstToEnd('column', 304),
                columnReverse: dragVisualFirstToEnd('column-reverse', 305),
                wrapped: dragVisualFirstToEnd('wrapped', 306),
                autoGrid: dragVisualFirstToEnd('auto-grid', 307),
                explicitGrid: dragVisualFirstToEnd('explicit-grid', 308)
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：visual normal/reverse/RTLをDOM insertionへ正しく変換し、source属性とtranslateを変えない（Then）
        let expected: [String: (visual: String, order: String)] = [
            "row": ("row-a,row-b,row-c", "row-b,row-c,row-a"),
            "rowReverse": ("row-reverse-c,row-reverse-b,row-reverse-a", "row-reverse-c,row-reverse-a,row-reverse-b"),
            "rowRTL": ("row-rtl-c,row-rtl-b,row-rtl-a", "row-rtl-c,row-rtl-a,row-rtl-b"),
            "column": ("column-a,column-b,column-c", "column-b,column-c,column-a"),
            "columnReverse": ("column-reverse-c,column-reverse-b,column-reverse-a", "column-reverse-c,column-reverse-a,column-reverse-b"),
            "autoGrid": ("auto-grid-a,auto-grid-b,auto-grid-c", "auto-grid-b,auto-grid-c,auto-grid-a")
        ]
        for (key, expectation) in expected {
            let result = try #require(payload[key] as? [String: Any])
            #expect(result["beforeVisualOrder"] as? String == expectation.visual)
            #expect(result["afterOrder"] as? String == expectation.order)
            #expect(result["sourceBytesPreserved"] as? Bool == true)
            #expect(result["inlineTranslatePreserved"] as? Bool == true)
        }

        // 期待値：wrapとexplicit placement gridはambiguous layoutとしてDOMを変更しない（Then）
        for key in ["wrapped", "explicitGrid"] {
            let result = try #require(payload[key] as? [String: Any])
            #expect((result["afterOrder"] as? String) == (result["beforeOrder"] as? String))
            #expect(result["sourceBytesPreserved"] as? Bool == true)
        }
    }

    /// 論理名（日本語）: 選択オブジェクト単体表示復元テスト
    /// 概要: focus isolation が対象 subtree だけを表示し、layout geometry を変えず、解除時に元の表示へ戻すことを検証します。
    @Test("focus isolationは対象subtreeだけをgeometry不変で表示して解除できる")
    func testFocusIsolationShowsOnlyTargetSubtreeAndRestoresDocument() async throws {
        // コンディション：横並びの sibling、対象 frame、対象 child を持つ HTML を WebView に読み込む（Given）
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style>
              html, body { margin: 0; min-width: 640px; min-height: 1200px; }
              [data-og-id="page"] { display: flex; align-items: flex-start; gap: 24px; padding: 32px; }
              [data-og-id="leading-sibling"] { width: 96px; height: 72px; }
              [data-og-id="focus-target"] { width: 180px; height: 120px; padding: 12px; }
              [data-og-id="focus-child"] { display: block; width: 80px; height: 32px; overflow: auto; }
              [data-og-id="focus-child-content"] { display: block; height: 96px; }
              [data-og-id="trailing-sibling"] { width: 112px; height: 64px; }
            </style>
          </head>
          <body>
            <Page data-og-id="page" data-og-type="page">
              <LeadingSibling data-og-id="leading-sibling" data-og-type="frame">Leading</LeadingSibling>
              <FocusTarget data-og-id="focus-target" data-og-type="frame">
                <FocusChild data-og-id="focus-child" data-og-type="text">
                  <FocusChildContent data-og-id="focus-child-content">Focused child</FocusChildContent>
                </FocusChild>
              </FocusTarget>
              <TrailingSibling data-og-id="trailing-sibling" data-og-type="frame">Trailing</TrailingSibling>
            </Page>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasFocusIsolationScript.source)

        // 検証内容：対象 frame に focus isolation を適用し、表示状態と geometry を取得してから解除する（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const target = document.querySelector('[data-og-id="focus-target"]');
              const child = document.querySelector('[data-og-id="focus-child"]');
              const leadingSibling = document.querySelector('[data-og-id="leading-sibling"]');
              const trailingSibling = document.querySelector('[data-og-id="trailing-sibling"]');
              const rect = (element) => {
                const value = element.getBoundingClientRect();
                return [value.x, value.y, value.width, value.height];
              };
              const isVisible = (element) => {
                const style = window.getComputedStyle(element);
                return style.display !== 'none' &&
                  style.visibility !== 'hidden' &&
                  Number.parseFloat(style.opacity || '1') > 0;
              };
              const beforeRect = rect(target);
              const beforeHTML = document.documentElement.outerHTML;
              const documentScroller = document.scrollingElement || document.documentElement;
              documentScroller.scrollTop = 180;
              const documentScrollTopBeforeFocus = documentScroller.scrollTop;
              const applied = window.OpenGraphiteFocusIsolation.apply([target]);
              const focusedRect = rect(target);
              const focusedState = {
                active: window.OpenGraphiteFocusIsolation.isActive(),
                targetVisible: isVisible(target),
                childVisible: isVisible(child),
                leadingSiblingVisible: isVisible(leadingSibling),
                trailingSiblingVisible: isVisible(trailingSibling),
                documentScrollTop: documentScroller.scrollTop,
                documentOverflow: window.getComputedStyle(document.documentElement).overflow,
                bodyOverflow: window.getComputedStyle(document.body).overflow,
                childOverflow: window.getComputedStyle(child).overflow,
                childCanScroll: child.scrollHeight > child.clientHeight,
                temporaryEditorAttributes: document.querySelectorAll(
                  '[data-og-selected],[data-og-editing],[data-og-editor-focus-root],[data-og-editor-focus-visible]'
                ).length
              };
              window.OpenGraphiteFocusIsolation.clear();
              return {
                applied: applied,
                beforeRect: beforeRect,
                documentScrollTopBeforeFocus: documentScrollTopBeforeFocus,
                focusedRect: focusedRect,
                clearedRect: rect(target),
                focusedState: focusedState,
                activeAfterClear: window.OpenGraphiteFocusIsolation.isActive(),
                targetVisibleAfterClear: isVisible(target),
                childVisibleAfterClear: isVisible(child),
                leadingSiblingVisibleAfterClear: isVisible(leadingSibling),
                trailingSiblingVisibleAfterClear: isVisible(trailingSibling),
                documentOverflowAfterClear: window.getComputedStyle(document.documentElement).overflow,
                restoredHTML: document.documentElement.outerHTML,
                beforeHTML: beforeHTML
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let focusedState = try #require(payload["focusedState"] as? [String: Any])
        let beforeRect = try Self.numericArray(from: payload["beforeRect"])
        let focusedRect = try Self.numericArray(from: payload["focusedRect"])
        let clearedRect = try Self.numericArray(from: payload["clearedRect"])
        let beforeHTML = payload["beforeHTML"] as? String
        let restoredHTML = payload["restoredHTML"] as? String

        // 期待値：対象 subtree だけが表示され、geometry は不変で、clear 後は marker なしの元表示へ完全に戻る（Then）
        #expect(payload["applied"] as? Bool == true)
        #expect(focusedState["active"] as? Bool == true)
        #expect(focusedState["targetVisible"] as? Bool == true)
        #expect(focusedState["childVisible"] as? Bool == true)
        #expect(focusedState["leadingSiblingVisible"] as? Bool == false)
        #expect(focusedState["trailingSiblingVisible"] as? Bool == false)
        #expect(((payload["documentScrollTopBeforeFocus"] as? NSNumber)?.doubleValue ?? 0) > 0)
        #expect((focusedState["documentScrollTop"] as? NSNumber)?.doubleValue == 0)
        #expect(focusedState["documentOverflow"] as? String == "hidden")
        #expect(focusedState["bodyOverflow"] as? String == "hidden")
        #expect(focusedState["childOverflow"] as? String == "auto")
        #expect(focusedState["childCanScroll"] as? Bool == true)
        #expect((focusedState["temporaryEditorAttributes"] as? NSNumber)?.intValue == 0)
        #expect(Self.rectsAreEqual(beforeRect, focusedRect))
        #expect(Self.rectsAreEqual(beforeRect, clearedRect))
        #expect(payload["activeAfterClear"] as? Bool == false)
        #expect(payload["targetVisibleAfterClear"] as? Bool == true)
        #expect(payload["childVisibleAfterClear"] as? Bool == true)
        #expect(payload["leadingSiblingVisibleAfterClear"] as? Bool == true)
        #expect(payload["trailingSiblingVisibleAfterClear"] as? Bool == true)
        #expect(payload["documentOverflowAfterClear"] as? String != "hidden")
        #expect(restoredHTML == beforeHTML)
    }

    /// 論理名（日本語）: focus session styleシリアライズ隔離テスト
    /// 概要: focus isolation の実行時styleを一時解除した保存 HTML に混入せず、直後にfocus表示を復元することを検証します。
    @Test("runtimeはfocus session styleを保存HTMLから隔離する")
    func testSerializeDocumentIsolatesFocusSessionStyles() async throws {
        // コンディション：focus 対象と sibling を持つ HTML に runtime と focus isolation script を読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <Page data-og-id="page" data-og-type="page">
              <FocusTarget data-og-id="focus-target" data-og-type="frame">
                <FocusChild data-og-id="focus-child" data-og-type="text">Focused child</FocusChild>
              </FocusTarget>
              <Sibling data-og-id="sibling" data-og-type="frame">Sibling</Sibling>
            </Page>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)
        _ = try await webView.evaluateJavaScript(WebCanvasFocusIsolationScript.source)

        // 検証内容：focusをsuspendして runtime 保存 HTML を取得し、同じ対象をresumeする（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const target = document.querySelector('[data-og-id="focus-target"]');
              const sibling = document.querySelector('[data-og-id="sibling"]');
              const applied = window.OpenGraphiteFocusIsolation.apply([target]);
              const siblingVisibility = window.getComputedStyle(sibling).visibility;
              const rootOverflow = window.getComputedStyle(document.documentElement).overflow;
              const suspendedTargets = window.OpenGraphiteFocusIsolation.suspend();
              const serialized = window.OpenGraphiteRuntime.serializeDocument();
              const resumed = window.OpenGraphiteFocusIsolation.resume(suspendedTargets);
              return {
                applied: applied,
                resumed: resumed,
                activeAfterSerialize: window.OpenGraphiteFocusIsolation.isActive(),
                siblingVisibility: siblingVisibility,
                rootOverflow: rootOverflow,
                temporaryEditorAttributes: document.querySelectorAll(
                  '[data-og-selected],[data-og-editing],[data-og-editor-focus-root],[data-og-editor-focus-visible]'
                ).length,
                serialized: serialized
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：live DOM はfocus表示を維持し、保存 HTML は一時styleなしのsource subtreeを保持する（Then）
        #expect(payload["applied"] as? Bool == true)
        #expect(payload["resumed"] as? Bool == true)
        #expect(payload["activeAfterSerialize"] as? Bool == true)
        #expect(payload["siblingVisibility"] as? String == "hidden")
        #expect(payload["rootOverflow"] as? String == "hidden")
        #expect((payload["temporaryEditorAttributes"] as? NSNumber)?.intValue == 0)
        #expect(!serialized.contains("visibility: hidden"))
        #expect(!serialized.contains("overflow: hidden"))
        #expect(!serialized.contains("overscroll-behavior"))
        #expect(serialized.contains("data-og-id=\"focus-target\""))
        #expect(serialized.contains("data-og-id=\"focus-child\""))
        #expect(serialized.contains("data-og-id=\"sibling\""))
    }

    /// 論理名（日本語）: Focus反復適用と正規編集保持テスト
    /// 概要: Focusのsuspend/resumeを反復してもeffectがsourceへ残らず、Focus中の通常CSS編集を保持することを検証します。
    @Test("focus effectは反復後もsourceを汚さず通常CSS編集を保持する")
    func testFocusEffectsRemainPrivateAcrossRepeatedSuspendResume() async throws {
        // コンディション：authored inline colorを持つtargetとstyle属性を持たないsiblingがある（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html><html><body>
          <main id="target" style="color: red;"><span>Target</span></main>
          <aside id="sibling">Sibling</aside>
        </body></html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasFocusIsolationScript.source)

        // 検証内容：Focus中に正規color編集を行い、2回suspend/resume/clearする（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const target = document.getElementById('target');
              const sibling = document.getElementById('sibling');
              const controller = window.OpenGraphiteFocusIsolation;
              controller.apply([target]);
              target.style.color = 'blue';
              const firstState = controller.suspend();
              const serialized = document.documentElement.outerHTML;
              controller.resume(firstState);
              controller.clear();
              const afterFirst = document.documentElement.outerHTML;
              controller.apply([target]);
              const secondState = controller.suspend();
              controller.resume(secondState);
              controller.clear();
              return {
                serialized,
                afterFirst,
                afterSecond: document.documentElement.outerHTML,
                color: target.style.color,
                siblingHasStyle: sibling.hasAttribute('style')
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：正規color編集だけが残り、Focus effectや空style属性は反復後もsourceへ混入しない（Then）
        #expect(payload["color"] as? String == "blue")
        #expect(payload["siblingHasStyle"] as? Bool == false)
        #expect(payload["afterFirst"] as? String == payload["afterSecond"] as? String)
        #expect(serialized.contains("color: blue"))
        #expect(!serialized.contains("visibility: hidden"))
        #expect(!serialized.contains("overflow: hidden"))
        #expect(!serialized.contains("style=\"\""))
    }

    /// 論理名（日本語）: file component相対resource解決テスト
    /// 概要: Swift fallbackから渡したcomponent file URLを基準にShadow DOM内のstylesheetと画像URLを解決することを検証します。
    @Test("file component fallbackはcomponent自身のURLから相対resourceを解決する")
    func testFileComponentFallbackResolvesResourcesAgainstComponentURL() async throws {
        // コンディション：pageとは別directoryにあるstylesheetと画像を参照するcomponent masterを用意する（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html><body>
          <site-header data-og-id="site-header-master" data-og-component="site-header" part="root">
            <template>
              <link rel="stylesheet" href="./design-system.css">
              <img data-og-id="brandmark" src="../assets/OpenGraphite.png" alt="OpenGraphite">
            </template>
          </site-header>
        </body></html>
        """
        let pageHTML = """
        <!doctype html><html><body>
          <og-instance data-og-id="header" data-og-component="site-header"></og-instance>
        </body></html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：base URL付きcomponent documentをfallback APIで展開し、生成resource URLを取得する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              runtime.renderComponentHTMLDocuments([{
                html: \(Self.javaScriptLiteral(componentHTML)),
                baseURL: 'file:///workspace/public/_components/design-system.html'
              }]);
              const root = runtime.generatedRootFor(document.querySelector('og-instance'));
              return {
                stylesheet: root.shadowRoot.querySelector('link[rel="stylesheet"]').href,
                image: root.shadowRoot.querySelector('img').src
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：page URLではなくcomponent file URLを基準に両resourceが絶対URL化される（Then）
        #expect(payload["stylesheet"] as? String == "file:///workspace/public/_components/design-system.css")
        #expect(payload["image"] as? String == "file:///workspace/public/assets/OpenGraphite.png")
    }

    /// 論理名（日本語）: private component state付きtemplate slot復元テスト
    /// 概要: runtime provenanceをDOM属性へ出さず、slot編集とsource IDを保存して直後に展開表示を復元することを検証します。
    @Test("runtimeはprivate stateでtemplate slotを保存して展開表示を復元する")
    func testSerializeDocumentRestoresTemplateSlotSourceIDs() async throws {
        // コンディション：runtime JS と、template slot を持つ component instance / master を WebView に読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <site-header data-og-id="site-header-master" data-og-component="site-header" part="root">
              <template>
                <nav data-og-id="nav">
                  <slot name="nav"><a data-og-id="fallback-link">Fallback</a></slot>
                </nav>
              </template>
            </site-header>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance data-og-id="site-header" data-og-type="frame" data-og-component="site-header" data-og-internal-id="instance-internal">
              <a slot="nav" data-og-id="nav-home" data-og-internal-id="nav-home-internal">Home</a>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：runtime でcomponentを展開し、生成slotを編集してから保存用HTMLとprivate metadataを取得する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              runtime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
              const instance = document.querySelector('og-instance');
              const generatedRoot = runtime.generatedRootFor(instance);
              const generatedLink = generatedRoot.querySelector('[data-og-id="nav-home"]');
              generatedLink.textContent = 'Edited home';
              const metadata = runtime.metadataFor(generatedLink);
              const serialized = runtime.serializeDocument();
              return {
                apiFrozen: Object.isFrozen(runtime),
                metadataFrozen: Object.isFrozen(metadata),
                generated: runtime.isGenerated(generatedLink),
                sourceID: runtime.sourceIDFor(generatedLink),
                sourceComponent: metadata.sourceComponent,
                sourceInstance: metadata.sourceInstance,
                hostID: runtime.hostIDFor(instance),
                expandedAfterSerialize: runtime.isExpanded(instance),
                generatedConnectedAfterSerialize: runtime.generatedRootFor(instance).isConnected,
                generatedTextAfterSerialize: runtime.generatedRootFor(instance)
                  .querySelector('[data-og-id="nav-home"]').textContent,
                forbiddenLiveAttributes: document.querySelectorAll(
                  '[data-og-expanded],[data-og-generated],[data-og-component-error],[data-og-host-id],' +
                  '[data-og-instance-source],[data-og-source-id],[data-og-source-component],' +
                  '[data-og-source-instance],[data-og-slot-origin]'
                ).length,
                runtimeStyleUsesAttributeSelector: Array.from(document.head.querySelectorAll('style'))
                  .some((style) => style.textContent.includes('og-instance[')),
                serialized
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：provenanceはprivate APIから参照でき、source HTMLと再開済みlive DOMの両方にslot編集が残る（Then）
        #expect(payload["apiFrozen"] as? Bool == true)
        #expect(payload["metadataFrozen"] as? Bool == true)
        #expect(payload["generated"] as? Bool == false)
        #expect(payload["sourceID"] as? String == "nav-home")
        #expect(payload["sourceComponent"] as? String == "site-header")
        #expect(payload["sourceInstance"] as? String == "site-header")
        #expect(payload["hostID"] as? String == "site-header")
        #expect(payload["expandedAfterSerialize"] as? Bool == true)
        #expect(payload["generatedConnectedAfterSerialize"] as? Bool == true)
        #expect(payload["generatedTextAfterSerialize"] as? String == "Edited home")
        #expect((payload["forbiddenLiveAttributes"] as? NSNumber)?.intValue == 0)
        #expect(payload["runtimeStyleUsesAttributeSelector"] as? Bool == false)
        #expect(serialized.contains("data-og-id=\"nav-home\""))
        #expect(serialized.contains("data-og-internal-id=\"nav-home-internal\""))
        #expect(serialized.contains("Edited home"))
        #expect(!serialized.contains("site-header-nav-home"))
        #expect(!serialized.contains("data-og-expanded"))
        #expect(!serialized.contains("data-og-generated"))
        #expect(!serialized.contains("data-og-component-error"))
        #expect(!serialized.contains("data-og-host-id"))
        #expect(!serialized.contains("data-og-instance-source"))
        #expect(!serialized.contains("data-og-source-component"))
        #expect(!serialized.contains("data-og-source-instance"))
        #expect(!serialized.contains("data-og-source-id"))
        #expect(!serialized.contains("data-og-slot-origin"))
        #expect(!serialized.contains("og-instance{display:contents"))
    }

    /// 論理名（日本語）: native slot text binding metadata保持テスト
    /// 概要: component runtime が native slot source の i18n metadata を authored light DOM のまま保持することを検証します。
    @Test("runtimeはnative slot sourceのtext binding metadataを保持する")
    func testRuntimeCopiesSlotTextBindingMetadataToGeneratedSlot() async throws {
        // コンディション：i18n metadata を持つ slot source と、text slot を持つ component master を WebView に読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <card-element data-og-id="card-master" data-og-component="card" part="root">
              <template><slot name="title"><span data-og-id="card-title">Fallback title</span></slot></template>
            </card-element>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance data-og-id="card-instance" data-og-type="frame" data-og-component="card" data-og-internal-id="card-instance-internal">
              <span slot="title" data-og-text-source="binding" data-i18n-key="home.card.title" data-og-text-variant-eng="English slot title">日本語スロット</span>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：runtime で component を展開し、native slot に割り当てられた authored node の metadata を読む（When）
        let value = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            (() => {
              const root = window.OpenGraphiteRuntime.generatedRootFor(document.querySelector('og-instance'));
              const slotElement = root.shadowRoot.querySelector('slot[name="title"]');
              const slot = slotElement.assignedElements()[0];
              const metadata = window.OpenGraphiteRuntime.metadataFor(slot);
              return {
                text: slot ? slot.textContent : '',
                textSource: slot ? slot.getAttribute('data-og-text-source') || '' : '',
                i18nKey: slot ? slot.getAttribute('data-i18n-key') || '' : '',
                variant: slot ? slot.getAttribute('data-og-text-variant-eng') || '' : '',
                generated: window.OpenGraphiteRuntime.isGenerated(slot),
                slotOrigin: metadata ? metadata.slotOrigin : '',
                hasSlotOriginAttribute: slot ? slot.hasAttribute('data-og-slot-origin') : false
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：slot source は生成copyではなく authored light DOM のまま binding metadata を保持する（Then）
        #expect(payload["text"] as? String == "日本語スロット")
        #expect(payload["textSource"] as? String == "binding")
        #expect(payload["i18nKey"] as? String == "home.card.title")
        #expect(payload["variant"] as? String == "English slot title")
        #expect(payload["generated"] as? Bool == false)
        #expect(payload["slotOrigin"] as? String == "title")
        #expect(payload["hasSlotOriginAttribute"] as? Bool == false)
    }

    /// 論理名（日本語）: private runtime component error解除テスト
    /// 概要: 一度master未解決になったinstanceでも、private error stateを後続のcomponent HTML注入で解除できることを検証します。
    @Test("runtimeは後続のmaster解決でprivate missing-master errorを解除する")
    func testRuntimeClearsMissingMasterErrorAfterLaterResolution() async throws {
        // コンディション：master がまだ無い状態で component instance を含む page を WebView に読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <card-element data-og-id="card-master" data-og-component="card" part="root">
              <template><slot name="title"><span data-og-id="card-title">Fallback title</span></slot></template>
            </card-element>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance data-og-id="card-instance" data-og-type="frame" data-og-component="card" data-og-internal-id="card-instance-internal">
              <span slot="title">Resolved title</span>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：先に空 registry で未解決状態を作り、その後 master HTML を注入して再描画する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              const instance = document.querySelector('og-instance');
              runtime.renderComponentHTMLDocuments([]);
              const before = runtime.componentError(instance);
              const beforeMetadata = runtime.metadataFor(instance);
              runtime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
              const generated = runtime.generatedRootFor(instance);
              return {
                before,
                beforeMetadataError: beforeMetadata.componentError,
                after: runtime.componentError(instance),
                expanded: runtime.isExpanded(instance),
                generatedText: generated ? generated.textContent.trim() : '',
                hasErrorAttribute: instance.hasAttribute('data-og-component-error')
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：旧 error は残らず、生成 DOM が表示される（Then）
        #expect(payload["before"] as? String == "missing-master")
        #expect(payload["beforeMetadataError"] as? String == "missing-master")
        #expect(payload["after"] as? String == "")
        #expect(payload["expanded"] as? Bool == true)
        #expect(payload["generatedText"] as? String == "Resolved title")
        #expect(payload["hasErrorAttribute"] as? Bool == false)
    }

    /// 論理名（日本語）: 複数instanceのcomponent internal ID保持テスト
    /// 概要: component runtime が複数 instance の生成 DOM に master の `data-og-internal-id` を残すことを検証します。
    @Test("runtimeは複数instanceでmaster internal IDを保持する")
    func testRuntimePreservesMasterInternalIDsAcrossMultipleInstances() async throws {
        // コンディション：同じ component を参照する複数 instance と internal ID 付き master を WebView に読み込むとき（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <card-element data-og-id="card-master" data-og-internal-id="card-root-internal" data-og-component="card" part="root">
              <template>
                <slot name="title"><span data-og-id="card-title" data-og-internal-id="card-title-internal">Fallback title</span></slot>
              </template>
            </card-element>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance data-og-id="first-card" data-og-type="frame" data-og-component="card" data-og-internal-id="first-card-instance">
              <span slot="title">First</span>
            </og-instance>
            <og-instance data-og-id="second-card" data-og-type="frame" data-og-component="card" data-og-internal-id="second-card-instance">
              <span slot="title">Second</span>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：runtime で component を展開し、生成 root / child の ID と internal ID を読む（When）
        let value = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              const instances = Array.from(document.querySelectorAll('og-instance'));
              const roots = instances.map((instance) => runtime.generatedRootFor(instance));
              const titles = roots.map((root) => root.shadowRoot.querySelector('[data-og-id$="-card-title"]'));
              return {
                rootIDs: roots.map((node) => node.getAttribute('data-og-id') || ''),
                rootInternalIDs: roots.map((node) => node.getAttribute('data-og-internal-id') || ''),
                titleIDs: titles.map((node) => node.getAttribute('data-og-id') || ''),
                titleInternalIDs: titles.map((node) => node.getAttribute('data-og-internal-id') || ''),
                rootSourceIDs: roots.map((node) => runtime.sourceIDFor(node)),
                titleSourceIDs: titles.map((node) => runtime.metadataFor(node).sourceID),
                allGenerated: [...roots, ...titles].every((node) => runtime.isGenerated(node)),
                provenanceAttributeCount: document.querySelectorAll(
                  '[data-og-generated],[data-og-source-id],[data-og-source-component],[data-og-source-instance]'
                ).length
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // 期待値：表示用 data-og-id は instance ごとに一意になり、design CSS 用 internal ID は master と同じ値を保つ（Then）
        #expect(payload["rootIDs"] as? [String] == ["first-card", "second-card"])
        #expect(payload["rootInternalIDs"] as? [String] == ["card-root-internal", "card-root-internal"])
        #expect(payload["titleIDs"] as? [String] == ["first-card-card-title", "second-card-card-title"])
        #expect(payload["titleInternalIDs"] as? [String] == ["card-title-internal", "card-title-internal"])
        #expect(payload["rootSourceIDs"] as? [String] == ["card-master", "card-master"])
        #expect(payload["titleSourceIDs"] as? [String] == ["card-title", "card-title"])
        #expect(payload["allGenerated"] as? Bool == true)
        #expect((payload["provenanceAttributeCount"] as? NSNumber)?.intValue == 0)
    }

    /// 論理名（日本語）: authored component provenance非変換テスト
    /// 概要: legacy provenance属性や標準編集属性がsourceに存在する場合、通常renderとserializeが暗黙migrationしないことを検証します。
    @Test("runtimeはauthored component provenanceと標準属性を暗黙変換しない")
    func testRuntimePreservesAuthoredComponentProvenanceAndStandardAttributes() async throws {
        // コンディション：legacy provenance、標準contenteditable/spellcheck、未知属性を持つcomponent instanceがある（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <card-element data-og-id="card-master" data-og-component="card" part="root">
              <template><slot name="title"><span data-og-id="card-title">Fallback</span></slot></template>
            </card-element>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance
              data-og-id="authored-card"
              data-og-component="card"
              data-og-expanded="authored-expanded"
              data-og-generated="authored-generated"
              data-og-component-error="authored-error"
              data-og-host-id="authored-host"
              data-og-instance-source="authored-source"
              data-og-source-id="authored-source-id"
              data-og-source-component="authored-source-component"
              data-og-source-instance="authored-source-instance"
              data-og-slot-origin="authored-slot"
              contenteditable="true"
              spellcheck="false"
              data-vendor-state="keep-me">
              <span slot="title">Authored title</span>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：private stateで展開し、sourceを一時復元するserializeを実行する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              const instance = document.querySelector('og-instance');
              runtime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
              const serialized = runtime.serializeDocument();
              return {
                privateError: runtime.componentError(instance),
                expandedAfterSerialize: runtime.isExpanded(instance),
                generatedTextAfterSerialize: runtime.generatedRootFor(instance).textContent.trim(),
                serialized
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：private stateはsource属性と独立し、authored属性と未知属性が値を含めて保存される（Then）
        #expect(payload["privateError"] as? String == "")
        #expect(payload["expandedAfterSerialize"] as? Bool == true)
        #expect(payload["generatedTextAfterSerialize"] as? String == "Authored title")
        #expect(serialized.contains("data-og-id=\"authored-card\""))
        #expect(serialized.contains("data-og-expanded=\"authored-expanded\""))
        #expect(serialized.contains("data-og-generated=\"authored-generated\""))
        #expect(serialized.contains("data-og-component-error=\"authored-error\""))
        #expect(serialized.contains("data-og-host-id=\"authored-host\""))
        #expect(serialized.contains("data-og-instance-source=\"authored-source\""))
        #expect(serialized.contains("data-og-source-id=\"authored-source-id\""))
        #expect(serialized.contains("data-og-source-component=\"authored-source-component\""))
        #expect(serialized.contains("data-og-source-instance=\"authored-source-instance\""))
        #expect(serialized.contains("data-og-slot-origin=\"authored-slot\""))
        #expect(serialized.contains("contenteditable=\"true\""))
        #expect(serialized.contains("spellcheck=\"false\""))
        #expect(serialized.contains("data-vendor-state=\"keep-me\""))
    }

    /// 論理名（日本語）: 実装runtime一時HTML復元テスト
    /// 概要: 実装 i18n runtime が解決済み text を DOM へ反映しても、保存HTMLにはfallbackが残ることを検証します。
    @Test("runtimeは実装runtimeの一時text HTMLを保存時にfallbackへ戻す")
    func testRuntimeFallbackHTMLIsRestoredWithoutResolvingI18nText() async throws {
        // コンディション：runtime JS と、page内 text / component slot text を WebView に読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <card-element data-og-id="card-master" data-og-component="card" part="root">
              <template><slot name="title"><span data-og-id="card-title">Fallback slot</span></slot></template>
            </card-element>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html lang="ja" data-og-lang-source="binding" data-og-lang-field="selectedLanguage" dir="ltr" data-og-dir-source="auto">
          <body>
            <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語タイトル</Title>
            <og-instance data-og-id="card-instance" data-og-type="frame" data-og-component="card" data-og-internal-id="card-instance-internal">
              <span slot="title" data-og-text-source="binding" data-i18n-key="home.slot.title">スロット</span>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)
        _ = try await webView.evaluateJavaScript(try i18nJavaScriptSource())

        // 検証内容：実装 i18n runtime 相当の一時 text 置換後に保存用 HTML を取得する（When）
        let value = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            (() => {
              const title = document.querySelector('[data-i18n-key="home.title"]');
              window.OpenGraphiteI18n.setFallbackHTML(title, title.innerHTML);
              title.innerHTML = 'English title';
              const slot = document.querySelector('[data-i18n-key="home.slot.title"]');
              window.OpenGraphiteI18n.setFallbackHTML(slot, slot.innerHTML);
              slot.innerHTML = 'Slot English';
              return {
                title: title.innerHTML,
                slot: slot.innerHTML,
                serialized: window.OpenGraphiteRuntime.serializeDocument()
              };
            })();
            """
        )
        let values = try #require(value as? [String: Any])
        let serialized = try #require(values["serialized"] as? String)

        // 期待値：preview DOM は実装 runtime の解決済み text、serialize 結果は fallback source を保持する（Then）
        #expect(values["title"] as? String == "English title")
        #expect(values["slot"] as? String == "Slot English")
        #expect(serialized.contains("日本語タイトル"))
        #expect(serialized.contains(">スロット</span>"))
        #expect(!serialized.contains("data-og-runtime-fallback-html"))
    }

    /// 論理名（日本語）: 標準Web Components runtime統合テスト
    /// 概要: Shadow DOM、fallback、named/default slot、複数割り当て、variant、part、nested component、冪等再描画を同じsourceから検証します。
    @Test("runtimeは標準Web Components semanticsでcomponentを決定的に展開する")
    func testRuntimeExpandsStandardWebComponentsDeterministically() async throws {
        // コンディション：named/default slot、fallback、part、nested instanceを持つ2つのCustom Element masterを用意する（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html><body>
          <status-badge data-og-component="status-badge" part="root">
            <template>
              <span part="badge"><slot>Fallback badge</slot></span>
            </template>
          </status-badge>
          <profile-panel data-og-component="profile-panel" part="root" variant="default">
            <template>
              <style>
                :host([variant~="compact"]) [part~="surface"] { outline: 7px solid transparent; }
              </style>
              <section part="surface">
                <header part="heading"><slot name="title">Fallback title</slot></header>
                <div part="body"><slot>Fallback body</slot></div>
                <footer part="actions"><slot name="actions"><button part="fallback-action">Fallback action</button></slot></footer>
                <og-instance data-og-component="status-badge"><span>Nested badge</span></og-instance>
              </section>
            </template>
          </profile-panel>
        </body></html>
        """
        let pageHTML = """
        <!doctype html>
        <html><head>
          <style>profile-panel::part(surface) { border-top: 5px solid rgb(1, 2, 3); }</style>
        </head><body>
          <og-instance data-og-id="filled-panel" data-og-component="profile-panel" variant="compact">
            <strong slot="title">First title</strong><em slot="title">Second title</em>
            <p>First body</p><p>Second body</p>
          </og-instance>
          <og-instance data-og-id="fallback-panel" data-og-component="profile-panel"></og-instance>
        </body></html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：同じregistryで2回renderし、Shadow DOMとnative slot assignment、computed part styleを収集する（When）
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
              const runtime = window.OpenGraphiteRuntime;
              runtime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
              runtime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
              const instances = Array.from(document.querySelectorAll('body > og-instance'));
              const filled = runtime.generatedRootFor(instances[0]);
              const fallback = runtime.generatedRootFor(instances[1]);
              const filledShadow = filled.shadowRoot;
              const fallbackShadow = fallback.shadowRoot;
              const titleSlot = filledShadow.querySelector('slot[name="title"]');
              const bodySlot = filledShadow.querySelector('slot:not([name])');
              const actionSlot = filledShadow.querySelector('slot[name="actions"]');
              const nestedInstance = filledShadow.querySelector('og-instance[data-og-component="status-badge"]');
              const nestedRoot = runtime.generatedRootFor(nestedInstance);
              const surface = filledShadow.querySelector('[part~="surface"]');
              const payload = {
                hostTag: filled.localName,
                variant: filled.getAttribute('variant') || '',
                rootPart: filled.getAttribute('part') || '',
                titleTexts: titleSlot.assignedElements().map((element) => element.textContent.trim()),
                bodyTexts: bodySlot.assignedElements().map((element) => element.textContent.trim()),
                actionAssignedCount: actionSlot.assignedElements().length,
                actionFallback: actionSlot.textContent.trim(),
                fallbackTitle: fallbackShadow.querySelector('slot[name="title"]').textContent.trim(),
                fallbackBody: fallbackShadow.querySelector('slot:not([name])').textContent.trim(),
                nestedHostTag: nestedRoot ? nestedRoot.localName : '',
                nestedText: nestedRoot ? nestedRoot.textContent.trim() : '',
                outlineWidth: getComputedStyle(surface).outlineWidth,
                borderTopWidth: getComputedStyle(surface).borderTopWidth,
                generatedRootCount: instances.reduce((count, instance) => count + (runtime.generatedRootFor(instance) ? 1 : 0), 0),
                sourceInstanceCount: document.querySelectorAll('body > og-instance').length
              };
              payload.serialized = runtime.serializeDocument();
              return payload;
            })();
            """
        )
        let payload = try #require(value as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：runtime独自slot copyなしで標準assignmentとfallbackが働き、part/variant/nested展開とsource復元が一致する（Then）
        #expect(payload["hostTag"] as? String == "profile-panel")
        #expect(payload["variant"] as? String == "compact")
        #expect(payload["rootPart"] as? String == "root")
        #expect(payload["titleTexts"] as? [String] == ["First title", "Second title"])
        #expect(payload["bodyTexts"] as? [String] == ["First body", "Second body"])
        #expect((payload["actionAssignedCount"] as? NSNumber)?.intValue == 0)
        #expect(payload["actionFallback"] as? String == "Fallback action")
        #expect(payload["fallbackTitle"] as? String == "Fallback title")
        #expect(payload["fallbackBody"] as? String == "Fallback body")
        #expect(payload["nestedHostTag"] as? String == "status-badge")
        #expect(payload["nestedText"] as? String == "Nested badge")
        #expect(payload["outlineWidth"] as? String == "7px")
        #expect(payload["borderTopWidth"] as? String == "5px")
        #expect((payload["generatedRootCount"] as? NSNumber)?.intValue == 2)
        #expect((payload["sourceInstanceCount"] as? NSNumber)?.intValue == 2)
        #expect(serialized.contains("<og-instance"))
        #expect(serialized.contains("slot=\"title\""))
        #expect(!serialized.contains("<profile-panel"))
        #expect(!serialized.contains("data-og-slot"))
        #expect(!serialized.contains("data-og-part"))
        #expect(!serialized.contains("data-og-variant"))
    }

    /// 論理名（日本語）: legacy editor helper暗黙変換禁止テスト
    /// 概要: 明示migration前の旧helperと標準属性をruntime serializeが暗黙削除しないことを確認します。
    @Test("runtimeはlegacy editor helperと標準属性を暗黙変換しない")
    func testRuntimePreservesLegacyEditorHelpersUntilExplicitMigration() async throws {
        // コンディション：OpenGraphite.cssを持たず、標準属性と旧editor helperが共存するpageを読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <main
              id="standard-page"
              class="article"
              data-og-selected="true"
              data-og-editing="true"
              data-og-editor-focus-root="true"
              data-og-editor-focus-visible="target"
              data-og-dragging="true"
              data-og-reorder-preparing="true"
              data-og-reorder-dragging="true"
              data-og-reorder-animating="true"
              data-og-reorder-animation="move"
              data-og-frame-preview="true"
              data-og-editor-artifact="selection"
              contenteditable="true"
              spellcheck="false"
              style="width:320px; min-height:48px; translate:12px 4px; transform:rotate(2deg); --og-preview-locale:ja; --og-preview-dir:ltr; --og-edit-width:300px; --og-edit-min-height:44px; --og-drag-x:12px; --og-drag-y:4px; --og-reorder-x:8px; --og-reorder-y:2px;">
              <h1 id="title">Standard HTML</h1>
            </main>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // 検証内容：runtime sanitizer を通した保存用 HTML を取得する（When）
        let value = try await webView.evaluateJavaScript("window.OpenGraphiteRuntime.serializeDocument();")
        let serialized = try #require(value as? String)
        let legacyIdentifiers = [
            "--og-preview-locale",
            "--og-preview-dir",
            "--og-edit-width",
            "--og-edit-min-height",
            "--og-drag-",
            "--og-reorder-",
            "data-og-selected",
            "data-og-editing",
            "data-og-editor-focus-",
            "data-og-drag",
            "data-og-reorder-",
            "data-og-frame-preview",
            "data-og-editor-artifact"
        ]

        // 期待値：通常serializeはstandard DOM/CSS/属性とlegacy inputを保持し、明示migrationを代行しない（Then）
        #expect(serialized.contains("id=\"standard-page\""))
        #expect(serialized.contains("class=\"article\""))
        #expect(serialized.contains("id=\"title\""))
        #expect(serialized.contains("Standard HTML"))
        #expect(serialized.contains("width:320px"))
        #expect(serialized.contains("min-height:48px"))
        #expect(serialized.contains("translate:12px 4px"))
        #expect(serialized.contains("transform:rotate(2deg)"))
        #expect(serialized.contains("contenteditable=\"true\""))
        #expect(serialized.contains("spellcheck=\"false\""))
        #expect(!serialized.contains("opengraphite-runtime-style"))
        for identifier in legacyIdentifiers {
            #expect(serialized.contains(identifier))
        }
    }

    /// 論理名（日本語）: WebCanvas標準layout/visibility収集テスト
    /// 概要: responsive CSS、flex/grid/position、標準hiddenとcomputed visibilityをlegacy属性やbinding metadataから独立して扱うことを検証します。
    @Test("WebCanvasは標準CSSとhiddenからlayoutとvisibilityを導出する")
    func testWebCanvasDerivesLayoutAndVisibilityFromStandardWebState() async throws {
        // コンディション：legacy属性、responsive flex、grid、standard hidden、visibility override、binding metadataが共存するHTMLを読み込む（Given）
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), configuration: configuration)
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(
            """
            <!doctype html><html><head><style>
              #legacy { display:grid; grid-template-columns:1fr 1fr; overflow-wrap:anywhere; }
              #visibility-parent { visibility:hidden; }
              #visibility-child { visibility:visible; }
              #display-parent { display:none; }
              #until-found-flex { display:flex; }
              #content-hidden-parent { content-visibility:hidden; }
              force-box { display:block; }
              @media (min-width: 500px) {
                #responsive { display:flex; flex-direction:row; }
              }
            </style><style id="component-media-style" data-component-stylesheet="force-box">
              @media (orientation: landscape) {
                force-box { --component-media-state: active; }
              }
            </style></head><body>
              <main id="legacy" data-og-id="legacy" data-og-internal-id="legacy-node" data-og-layout="horizontal" data-og-hidden="true" data-og-text-source="binding">Legacy</main>
              <p id="binding-default" data-og-text-source="binding">Binding without wrap CSS</p>
              <section id="responsive" data-og-id="responsive" data-og-internal-id="responsive-node"></section>
              <div id="visibility-parent"><span id="visibility-child">Visible override</span></div>
              <div id="display-parent"><span id="display-child">Display hidden</span></div>
              <div id="ordinary-hidden" hidden>Hidden</div>
              <force-box id="standard-hidden" hidden>Hidden</force-box>
              <section id="until-found-flex" hidden="until-found">Findable flex</section>
              <section id="content-hidden-parent"><span id="content-hidden-child">Skipped child</span></section>
            </body></html>
            """,
            in: webView
        )
        _ = try await webView.evaluateJavaScript(
            """
            (() => {
              const nativeMatchMedia = window.matchMedia.bind(window);
              const records = new Map();
              window.__openGraphiteTestMediaQueries = records;
              window.matchMedia = function(condition) {
                if (records.has(condition)) { return records.get(condition); }
                const nativeQuery = nativeMatchMedia(condition);
                const listeners = new Set();
                const record = {
                  media: nativeQuery.media,
                  matches: nativeQuery.matches,
                  addEventListener: function(name, listener) {
                    if (name === 'change') { listeners.add(listener); }
                  },
                  addListener: function(listener) { listeners.add(listener); },
                  removeEventListener: function(name, listener) {
                    if (name === 'change') { listeners.delete(listener); }
                  },
                  removeListener: function(listener) { listeners.delete(listener); },
                  emit: function() {
                    listeners.forEach((listener) => listener({ matches: record.matches, media: record.media }));
                  },
                  listenerCount: function() { return listeners.size; }
                };
                records.set(condition, record);
                return record;
              };
            })();
            """
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)

        // 検証内容：初期node payloadを収集し、legacy nodeのlayoutと標準hiddenを標準編集commandで変更する（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const initial = window.OpenGraphite.collectNodes();
              window.OpenGraphite.selectNode('legacy');
              const layoutEdit = window.OpenGraphite.runCommand('setLayout', { layout: 'block' });
              const hiddenEdit = window.OpenGraphite.runCommand('toggleHidden', {});
              const finalNodes = window.OpenGraphite.collectNodes();
              return {
                initial,
                finalNodes,
                layoutEdit,
                hiddenEdit,
                legacyHTML: document.getElementById('legacy').outerHTML
              };
            })();
            """
        )
        let sourceBeforeMediaRefresh = try #require(
            try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        )
        let nodePayloadCountBeforeMediaRefresh = messageHandler.nodePayloads.count
        _ = try await webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'))")
        try await Task.sleep(for: .milliseconds(100))
        let nodePayloadCountAfterResize = messageHandler.nodePayloads.count
        let mediaListenerCount = try #require(
            try await webView.evaluateJavaScript(
                "window.__openGraphiteTestMediaQueries.get('(min-width: 500px)').listenerCount()"
            ) as? Int
        )
        let componentMediaListenerCount = try #require(
            try await webView.evaluateJavaScript(
                "window.__openGraphiteTestMediaQueries.get('(orientation: landscape)').listenerCount()"
            ) as? Int
        )
        _ = try await webView.evaluateJavaScript(
            "window.__openGraphiteTestMediaQueries.get('(min-width: 500px)').emit()"
        )
        try await Task.sleep(for: .milliseconds(100))
        let nodePayloadCountAfterMediaChange = messageHandler.nodePayloads.count
        let mediaLifecycle = try #require(
            try await webView.evaluateJavaScript(
                """
                (() => {
                  const style = document.getElementById('component-media-style');
                  const parent = style.parentNode;
                  style.remove();
                  window.OpenGraphite.collectNodes();
                  const removedListenerCount = window.__openGraphiteTestMediaQueries
                    .get('(orientation: landscape)').listenerCount();
                  parent.appendChild(style);
                  const finalNodes = window.OpenGraphite.collectNodes();
                  const restoredListenerCount = window.__openGraphiteTestMediaQueries
                    .get('(orientation: landscape)').listenerCount();
                  return { removedListenerCount, restoredListenerCount, finalNodes };
                })();
                """
            ) as? [String: Any]
        )
        let sourceAfterMediaRefresh = try #require(
            try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        )
        let payload = try #require(result as? [String: Any])
        let initial = try #require(payload["initial"] as? [[String: Any]])
        let finalNodes = try #require(payload["finalNodes"] as? [[String: Any]])
        func node(_ id: String, in nodes: [[String: Any]]) throws -> [String: Any] {
            try #require(nodes.first { $0["standardID"] as? String == id })
        }
        let legacy = try node("legacy", in: initial)
        let bindingDefault = try node("binding-default", in: initial)
        let responsive = try node("responsive", in: initial)
        let visibilityParent = try node("visibility-parent", in: initial)
        let visibilityChild = try node("visibility-child", in: initial)
        let displayChild = try node("display-child", in: initial)
        let ordinaryHidden = try node("ordinary-hidden", in: initial)
        let standardHidden = try node("standard-hidden", in: initial)
        let untilFoundFlex = try node("until-found-flex", in: initial)
        let contentHiddenChild = try node("content-hidden-child", in: initial)
        let finalLegacy = try node("legacy", in: finalNodes)
        let layoutCommand = try #require(payload["layoutEdit"] as? [String: Any])
        let hiddenCommand = try #require(payload["hiddenEdit"] as? [String: Any])
        let layoutEdit = try #require(layoutCommand["edit"] as? [String: Any])
        let hiddenEdit = try #require(hiddenCommand["edit"] as? [String: Any])
        let computedLegacy = try #require(legacy["computedStyle"] as? [String: Any])
        let computedBindingDefault = try #require(bindingDefault["computedStyle"] as? [String: Any])
        let computedResponsive = try #require(responsive["computedStyle"] as? [String: Any])
        let computedUntilFound = try #require(untilFoundFlex["computedStyle"] as? [String: Any])
        let computedContentHiddenChild = try #require(contentHiddenChild["computedStyle"] as? [String: Any])
        let refreshedNodes = try #require(mediaLifecycle["finalNodes"] as? [[String: Any]])
        let refreshedResponsive = try node("responsive", in: refreshedNodes)

        // 期待値：computed stateとsource intentは分離され、旧属性とbinding metadataは暗黙削除されず標準CSS/hidden editだけが返る（Then）
        #expect(legacy["layout"] as? String == "grid")
        #expect(legacy["hidden"] as? Bool == false)
        #expect(legacy["hasHiddenAttribute"] as? Bool == false)
        #expect(legacy["textSource"] as? String == "binding")
        #expect(computedLegacy["overflowWrap"] as? String == "anywhere")
        #expect(bindingDefault["textSource"] as? String == "binding")
        #expect(computedBindingDefault["overflowWrap"] as? String == "normal")
        #expect((legacy["cssVariables"] as? [String: String])?.isEmpty == true)
        #expect(responsive["layout"] as? String == "horizontal")
        #expect(computedResponsive["display"] as? String == "flex")
        #expect(computedResponsive["flexDirection"] as? String == "row")
        #expect((responsive["activeMediaQueries"] as? [String])?.contains("(min-width: 500px)") == true)
        #expect(nodePayloadCountAfterResize > nodePayloadCountBeforeMediaRefresh)
        #expect(nodePayloadCountAfterMediaChange > nodePayloadCountAfterResize)
        #expect(mediaListenerCount == 1)
        #expect(componentMediaListenerCount == 1)
        #expect(mediaLifecycle["removedListenerCount"] as? Int == 0)
        #expect(mediaLifecycle["restoredListenerCount"] as? Int == 1)
        #expect(refreshedResponsive["layout"] as? String == "horizontal")
        #expect((refreshedResponsive["activeMediaQueries"] as? [String])?.contains("(min-width: 500px)") == true)
        #expect((refreshedResponsive["activeMediaQueries"] as? [String])?.contains("(orientation: landscape)") == true)
        #expect(sourceAfterMediaRefresh == sourceBeforeMediaRefresh)
        #expect(visibilityParent["hidden"] as? Bool == true)
        #expect(visibilityChild["hidden"] as? Bool == false)
        #expect(displayChild["hidden"] as? Bool == true)
        #expect(ordinaryHidden["hasHiddenAttribute"] as? Bool == true)
        #expect(ordinaryHidden["hidden"] as? Bool == true)
        #expect(standardHidden["hasHiddenAttribute"] as? Bool == true)
        #expect(standardHidden["hidden"] as? Bool == false)
        #expect(untilFoundFlex["hasHiddenAttribute"] as? Bool == true)
        #expect(untilFoundFlex["hidden"] as? Bool == true)
        #expect(computedUntilFound["display"] as? String == "flex")
        #expect(computedUntilFound["contentVisibility"] as? String == "hidden")
        #expect(contentHiddenChild["hidden"] as? Bool == true)
        #expect(computedContentHiddenChild["contentVisibility"] as? String == "visible")
        #expect(layoutEdit["operation"] as? String == "setCSSVariables")
        #expect((layoutEdit["values"] as? [String: String])?["display"] == "block")
        #expect((layoutEdit["values"] as? [String: String])?["flex-direction"] == nil)
        #expect(hiddenEdit["operation"] as? String == "setAttribute")
        #expect(hiddenEdit["name"] as? String == "hidden")
        #expect(hiddenEdit["value"] as? String == "hidden")
        #expect(hiddenEdit["previousAttributePresent"] as? Bool == false)
        #expect(finalLegacy["layout"] as? String == "block")
        #expect(finalLegacy["hasHiddenAttribute"] as? Bool == true)
        #expect(finalLegacy["hidden"] as? Bool == false)
        #expect((payload["legacyHTML"] as? String)?.contains("data-og-layout=\"horizontal\"") == true)
        #expect((payload["legacyHTML"] as? String)?.contains("data-og-hidden=\"true\"") == true)
        #expect((payload["legacyHTML"] as? String)?.contains("data-og-text-source=\"binding\"") == true)
    }

    /// 論理名（日本語）: Responsive CSS保存後再読み込みテスト
    /// 概要: active media winner保存後に一時inline previewを破棄し、viewport変更でbase winnerへ戻ることを検証します。
    @Test("responsive CSS保存後はinline previewを残さずviewportごとのwinnerへ戻る")
    func testResponsiveCSSReloadClearsInlinePreviewAndRestoresBaseWinner() async throws {
        // コンディション：base blockとmobile media flexを持つ同一originのHTML/CSSを小さいviewportで読み込む（Given）
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("OpenGraphite-WSCM9-Responsive-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }
        let pageHTML = """
        <!doctype html><html><head><link rel="stylesheet" href="index.css"></head><body>
          <main id="responsive">Responsive</main>
        </body></html>
        """
        let originalCSS = """
        #responsive { display: block; }
        @media (max-width: 500px) { #responsive { display: flex; } }
        """
        let pageURL = rootURL.appendingPathComponent("index.html")
        let cssURL = rootURL.appendingPathComponent("index.css")
        try pageHTML.write(to: pageURL, atomically: true, encoding: .utf8)
        try originalCSS.write(to: cssURL, atomically: true, encoding: .utf8)
        let configuration = WKWebViewConfiguration()
        let messageHandler = DiscardingWebCanvasMessageHandler()
        for name in [
            "openGraphiteNodes", "openGraphiteSelection", "openGraphiteContextMenu",
            "openGraphiteScrollState", "openGraphiteDocumentChange", "openGraphiteTextEditing",
            "openGraphiteStaticFlowLinks", "openGraphiteStaticFlowHover",
            "openGraphiteSelectionOverlay", "openGraphiteNodeDragPreview"
        ] {
            configuration.userContentController.add(messageHandler, name: name)
        }
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 320),
            configuration: configuration
        )
        let waiter = WebViewNavigationWaiter()
        try await waiter.loadFile(pageURL, allowingReadAccessTo: rootURL, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasView.bridgeScript)
        let originalOuterHTML = try #require(
            try await webView.evaluateJavaScript("document.getElementById('responsive').outerHTML") as? String
        )
        let initialDisplay = try #require(
            try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('responsive')).display") as? String
        )

        // 検証内容：bridgeの一時inline previewを付け、mobile mediaのsource winnerを更新してoriginから再読み込んだ後、desktop幅へ戻す（When）
        let didApplyPreview = try await webView.evaluateJavaScript(
            """
            (() => {
              const node = window.OpenGraphite.collectNodes().find((candidate) => candidate.standardID === 'responsive');
              return !!node && window.OpenGraphite.setCSSVariable(node.id, 'display', 'grid');
            })()
            """
        )
        let previewOuterHTML = try #require(
            try await webView.evaluateJavaScript("document.getElementById('responsive').outerHTML") as? String
        )
        let updatedCSS = originalCSS.replacingOccurrences(of: "display: flex", with: "display: grid")
        try updatedCSS.write(to: cssURL, atomically: true, encoding: .utf8)
        try await waiter.reloadFromOrigin(in: webView)
        let mobileDisplayAfterReload = try #require(
            try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('responsive')).display") as? String
        )
        let outerHTMLAfterReload = try #require(
            try await webView.evaluateJavaScript("document.getElementById('responsive').outerHTML") as? String
        )
        webView.frame = CGRect(x: 0, y: 0, width: 800, height: 320)
        _ = try await webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'))")
        try await Task.sleep(for: .milliseconds(50))
        let desktopDisplay = try #require(
            try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('responsive')).display") as? String
        )
        let desktopOuterHTML = try #require(
            try await webView.evaluateJavaScript("document.getElementById('responsive').outerHTML") as? String
        )
        let unchangedHTMLSource = try String(contentsOf: pageURL, encoding: .utf8)

        // 期待値：一時previewだけがstyle属性を持ち、再読み込み後はmobile grid、desktop base blockとなりauthored element/source bytesは不変に戻る（Then）
        #expect(initialDisplay == "flex")
        #expect(didApplyPreview as? Bool == true)
        #expect(previewOuterHTML.contains("style=\"display: grid;\""))
        #expect(mobileDisplayAfterReload == "grid")
        #expect(desktopDisplay == "block")
        #expect(outerHTMLAfterReload == originalOuterHTML)
        #expect(desktopOuterHTML == originalOuterHTML)
        #expect(unchangedHTMLSource == pageHTML)
        #expect(try String(contentsOf: cssURL, encoding: .utf8) == updatedCSS)
    }

    /// 論理名（日本語）: runtime JS読み込み関数
    /// 処理概要: テストホストのアプリバンドルに含まれる `public/OpenGraphite.runtime.js` を読み込みます。
    ///
    /// - Returns: runtime JavaScript source。
    private func runtimeJavaScriptSource() throws -> String {
        let url = try #require(
            Bundle.main.url(
                forResource: "OpenGraphite.runtime",
                withExtension: "js",
                subdirectory: "public"
            )
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 論理名（日本語）: i18n JavaScript読み込み関数
    /// 処理概要: テストホストに同梱されたprivate state版`public/i18n.js`を読み込みます。
    ///
    /// - Returns: i18n JavaScript source。
    private func i18nJavaScriptSource() throws -> String {
        let url = try #require(
            Bundle.main.url(
                forResource: "i18n",
                withExtension: "js",
                subdirectory: "public"
            )
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 論理名（日本語）: JavaScript文字列リテラル化関数
    /// 処理概要: Swift の文字列を JavaScript 内で安全に埋め込める JSON 文字列へ変換します。
    ///
    /// - Parameter value: 変換する文字列。
    /// - Returns: JavaScript 文字列リテラル。
    private static func javaScriptLiteral(_ value: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [value]),
            let encoded = String(data: data, encoding: .utf8),
            encoded.count >= 2
        else {
            return "\"\""
        }
        return String(encoded.dropFirst().dropLast())
    }

    /// 論理名（日本語）: JavaScript数値配列変換関数
    /// 処理概要: WKWebView が返す JavaScript number 配列を geometry 比較用の Double 配列へ変換します。
    ///
    /// - Parameter value: JavaScript evaluation result に含まれる配列。
    /// - Returns: Double へ変換した配列。
    private static func numericArray(from value: Any?) throws -> [Double] {
        let values = try #require(value as? [Any])
        return try values.map { value in
            let number = try #require(value as? NSNumber)
            return number.doubleValue
        }
    }

    /// 論理名（日本語）: 矩形数値近似一致判定関数
    /// 処理概要: WebKit の小数誤差を許容しながら 2 つの geometry 配列が一致するか判定します。
    ///
    /// - Parameters:
    ///   - lhs: 比較元の x、y、width、height。
    ///   - rhs: 比較先の x、y、width、height。
    /// - Returns: 各値の差が許容範囲内の場合は `true`。
    private static func rectsAreEqual(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        guard lhs.count == 4, rhs.count == 4 else { return false }
        return zip(lhs, rhs).allSatisfy { abs($0 - $1) < 0.001 }
    }
}

/// 論理名（日本語）: WebCanvas message破棄handler
/// 概要: WKWebView上で実アプリbridgeを評価するとき、node収集等のmessageを副作用なく受け取ります。
private final class DiscardingWebCanvasMessageHandler: NSObject, WKScriptMessageHandler {
    /// `openGraphiteNodes`から受信したnode payload履歴。
    private(set) var nodePayloads: [[[String: Any]]] = []
    /// `openGraphiteNodeDetails`から受信した選択node詳細payload履歴。
    private(set) var nodeDetailPayloads: [[String: Any]] = []

    /// 論理名（日本語）: WebCanvas message受信関数
    /// 処理概要: focused testではmessage bodyを検証せず、JavaScript bridgeの同期戻り値だけを利用します。
    ///
    /// - Parameters:
    ///   - userContentController: messageを配送したWebKit controller。
    ///   - message: 破棄するscript message。
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "openGraphiteNodes",
           let nodes = message.body as? [[String: Any]] {
            nodePayloads.append(nodes)
        }
        if message.name == "openGraphiteNodeDetails",
           let node = message.body as? [String: Any] {
            nodeDetailPayloads.append(node)
        }
    }
}

/// 論理名（日本語）: 同一origin WebKit fixture scheme handler
/// 概要: 一時directoryのHTML/CSSを隔離custom schemeで配信し、linked/imported stylesheetを同一origin CSSOMとして検証可能にします。
private final class LocalFixtureURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let rootURL: URL

    /// 論理名（日本語）: fixture scheme handler初期化関数
    /// 処理概要: 配信を許可する一時resource rootを固定します。
    ///
    /// - Parameter rootURL: HTML/CSS fixtureを含むdirectory URL。
    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    /// 論理名（日本語）: fixture resource配信開始関数
    /// 処理概要: custom scheme pathを許可root内のfileへ安全に解決し、HTML/CSS MIME type付きで返します。
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let relativePath = requestURL.path.drop(while: { $0 == "/" })
        let resourceURL = rootURL.appendingPathComponent(String(relativePath)).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard resourceURL.path.hasPrefix(rootPath) else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        do {
            let data = try Data(contentsOf: resourceURL)
            let mimeType = resourceURL.pathExtension.lowercased() == "css" ? "text/css" : "text/html"
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: "utf-8"
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    /// 論理名（日本語）: fixture resource配信停止関数
    /// 処理概要: 同期的に完了するfile配信の取消通知を受け取ります。
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

/// 論理名（日本語）: WebView読み込み待機ヘルパー
/// 概要: `WKWebView` の HTML 読み込み完了を async/await で待機します。
@MainActor
private final class WebViewNavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    /// 論理名（日本語）: HTML読み込み関数
    /// 処理概要: 指定 HTML を WebView へ読み込み、navigation 完了まで待機します。
    ///
    /// - Parameters:
    ///   - html: 読み込む HTML。
    ///   - webView: 読み込み先の WebView。
    func load(_ html: String, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// 論理名（日本語）: URL request読み込み関数
    /// 処理概要: custom schemeを含む指定requestをWebViewへ読み込み、navigation完了まで待機します。
    ///
    /// - Parameters:
    ///   - request: 読み込むURL request。
    ///   - webView: 読み込み先のWebView。
    func load(_ request: URLRequest, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.load(request)
        }
    }

    /// 論理名（日本語）: ローカルHTML resource読み込み関数
    /// 処理概要: 同一directoryのstylesheetとimportを許可した隔離file navigationの完了まで待機します。
    ///
    /// - Parameters:
    ///   - fileURL: 読み込むHTML file URL。
    ///   - readAccessURL: WebKitへ読み取りを許可するresource root URL。
    ///   - webView: 読み込み先のWebView。
    func loadFile(_ fileURL: URL, allowingReadAccessTo readAccessURL: URL, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        }
    }

    /// 論理名（日本語）: origin再読み込み関数
    /// 処理概要: cacheではなく保存済みsourceかorigin reloadし、navigation完了まで待機します。
    ///
    /// - Parameter webView: 再読み込み対象のWebView。
    func reloadFromOrigin(in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.reloadFromOrigin()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
