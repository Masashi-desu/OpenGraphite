import Foundation
import Testing
import WebKit
@testable import OpenGraphite

/// 論理名（日本語）: Component Placement runtime stateテストスイート
/// 概要: placement preview cloneのprovenanceがDOM属性ではなくprivate registryに保持されることを検証します。
@MainActor
@Suite("Component Placement runtime stateテストスイート")
struct ComponentPlacementRuntimeStateTests {
    /// 論理名（日本語）: Web Canvas placement provenance私有化テスト
    /// 概要: Web Canvas用scriptがcloneのidentityとlifecycleをruntime registryだけで管理することを検証します。
    @Test("Web Canvasはplacement clone provenanceをprivate registryで管理する")
    func testWebCanvasPlacementProvenanceUsesPrivateRegistry() async throws {
        // コンディション：Web Canvasのproduction placement registry scriptを用意する（Given）
        let script = WebCanvasView.componentPlacementReferencesScript

        // 検証内容：共通fixtureでregistry lifecycleを実行する（When）
        // 期待結果：共通helperがprivate provenanceとDOM非汚染を検証する（Then）
        try await verifyPlacementRegistry(script: script)
    }

    /// 論理名（日本語）: Screenshot placement provenance私有化テスト
    /// 概要: Screenshot renderer用scriptがWeb Canvasと同じprivate registry APIとlifecycleを提供することを検証します。
    @Test("Screenshot rendererはplacement clone provenanceをprivate registryで管理する")
    func testScreenshotPlacementProvenanceUsesPrivateRegistry() async throws {
        // コンディション：Screenshot rendererのproduction placement registry scriptを用意する（Given）
        let script = OpenGraphiteScreenshotRenderer.componentPlacementReferencesScript

        // 検証内容：共通fixtureでregistry lifecycleを実行する（When）
        // 期待結果：共通helperがprivate provenanceとDOM非汚染を検証する（Then）
        try await verifyPlacementRegistry(script: script)
    }

    /// 論理名（日本語）: Web Canvas標準host stateプレビューテスト
    /// 概要: placement mockがclone hostの標準attribute/classへだけ注入され、Shadow DOM CSSとprovenanceが維持されることを検証します。
    @Test("Web Canvasは標準host stateとShadow DOM CSSでplacement previewを描画する")
    func testWebCanvasPlacementPreviewUsesStandardHostState() async throws {
        // コンディション：Web Canvasのproduction placement scriptと4種類のpreview mockを用意する（Given）
        let script = WebCanvasView.componentPlacementReferencesScript

        // 検証内容：open Shadow DOMを持つsourceからcode/preview/loading/collapsed cloneを生成する（When）
        // 期待値：computed state、private provenance、source不変を共通helperが検証する（Then）
        try await verifyStandardHostStatePreview(script: script)
    }

    /// 論理名（日本語）: Screenshot標準host stateプレビューテスト
    /// 概要: screenshot rendererがWeb Canvasと同じ標準host stateとShadow DOM CSSを評価することを検証します。
    @Test("Screenshot rendererは標準host stateとShadow DOM CSSでplacement previewを描画する")
    func testScreenshotPlacementPreviewUsesStandardHostState() async throws {
        // コンディション：Screenshot rendererのproduction placement scriptと4種類のpreview mockを用意する（Given）
        let script = OpenGraphiteScreenshotRenderer.componentPlacementReferencesScript

        // 検証内容：open Shadow DOMを持つsourceからcode/preview/loading/collapsed cloneを生成する（When）
        // 期待値：computed state、private provenance、source不変を共通helperが検証する（Then）
        try await verifyStandardHostStatePreview(script: script)
    }

    /// 論理名（日本語）: 標準host state preview共通検証関数
    /// 処理概要: runtime host-state API、Shadow DOM clone、computed style、serialization境界を同一fixtureで検証します。
    ///
    /// - Parameter script: 検証対象のplacement reference JavaScript。
    private func verifyStandardHostStatePreview(script: String) async throws {
        // コンディション：通常host属性とShadow DOM内のproject CSSだけで4状態を表すcomponent sourceを読み込む（Given）
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 960, height: 640))
        let waiter = ComponentPlacementNavigationWaiter()
        let html = """
        <!doctype html>
        <html>
          <body>
            <preview-card
              class="authored-card"
              variant="base"
              data-og-component="preview-card"
              data-og-id="source-card"
              data-og-internal-id="source-card-internal"></preview-card>
            <og-placement data-og-id="placement-code" data-og-internal-id="placement-code-internal" data-og-source-node-internal-id="source-card-internal"></og-placement>
            <og-placement data-og-id="placement-preview" data-og-internal-id="placement-preview-internal" data-og-source-node-internal-id="source-card-internal"></og-placement>
            <og-placement data-og-id="placement-loading" data-og-internal-id="placement-loading-internal" data-og-source-node-internal-id="source-card-internal"></og-placement>
            <og-placement data-og-id="placement-collapsed" data-og-internal-id="placement-collapsed-internal" data-og-source-node-internal-id="source-card-internal"></og-placement>
          </body>
        </html>
        """
        try await waiter.load(html, in: webView)
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let runtimeScript = try String(
            contentsOf: repositoryURL.appendingPathComponent("public/OpenGraphite.runtime.js"),
            encoding: .utf8
        )
        _ = try await webView.evaluateJavaScript(
            """
            (() => {
              const source = document.querySelector('[data-og-id="source-card"]');
              const shadow = source.attachShadow({ mode: 'open' });
              shadow.innerHTML = `
                <style>
                  [data-panel] { display: none; }
                  [data-panel="code"], [part~="body"] { display: block; }
                  :host([variant~="preview"]) [data-panel="code"] { display: none; }
                  :host([variant~="preview"]) [data-panel="preview"] { display: block; }
                  :host(.is-loading) [part~="body"] { visibility: hidden; }
                  :host(.is-loading) [data-panel="loading"] { display: block; visibility: visible; }
                  :host([variant~="collapsed"]) [part~="body"] { display: none; }
                  :host([variant~="collapsed"]) [data-panel="summary"] { display: block; }
                </style>
                <h2 data-og-id="source-title" data-og-internal-id="source-title-internal">Title</h2>
                <section part="body" data-og-id="source-body">Body</section>
                <section data-panel="code">Code</section>
                <section data-panel="preview">Preview</section>
                <section data-panel="loading">Loading</section>
                <section data-panel="summary">Summary</section>`;
            })();
            """
        )
        _ = try await webView.evaluateJavaScript(runtimeScript)
        let previewContext = OpenGraphitePreviewContext(
            fieldMocks: ["unknownProjectField": "preserved"],
            placementMocks: [
                "placement-code-internal": ["host.variant": "code"],
                "placement-preview-internal": [
                    "host.variant": "preview",
                    "host.data-og-id": "forbidden",
                    "host.onclick": "forbidden()",
                    "host.style": "color:red"
                ],
                "placement-preview": ["host.variant": "wrong-display-id-value"],
                "placement-loading-internal": [
                    "host.aria-busy": "true",
                    "host.class": "is-loading"
                ],
                "placement-collapsed-internal": [
                    "host.aria-expanded": "false",
                    "host.variant": "collapsed"
                ]
            ]
        )
        _ = try await webView.evaluateJavaScript(WebCanvasView.previewContextScript(for: previewContext))
        let authoredSource = try #require(
            try await webView.evaluateJavaScript("document.querySelector('[data-og-id=source-card]').outerHTML") as? String
        )
        let authoredShadow = try #require(
            try await webView.evaluateJavaScript("document.querySelector('[data-og-id=source-card]').shadowRoot.innerHTML") as? String
        )

        // 検証内容：placement rendererを実行して各cloneのhost state、computed style、provenance、suspend serializationを取得する（When）
        _ = try await webView.evaluateJavaScript(script)
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const api = window.OpenGraphiteComponentPlacementReferences;
              const source = document.querySelector('[data-og-id="source-card"]');
              const sourceTitle = source.shadowRoot.querySelector('[data-og-id="source-title"]');
              function root(id) {
                const host = document.querySelector('[data-og-internal-id="' + id + '"]');
                return Array.from(host.children).find((child) => api.isGenerated(child));
              }
              function state(id) {
                const generated = root(id);
                const shadow = generated.shadowRoot;
                const style = (selector) => {
                  const computed = getComputedStyle(shadow.querySelector(selector));
                  return { display: computed.display, visibility: computed.visibility };
                };
                return {
                  ariaBusy: generated.getAttribute('aria-busy'),
                  ariaExpanded: generated.getAttribute('aria-expanded'),
                  classes: Array.from(generated.classList).sort().join(' '),
                  code: style('[data-panel="code"]'),
                  preview: style('[data-panel="preview"]'),
                  loading: style('[data-panel="loading"]'),
                  body: style('[part~="body"]'),
                  summary: style('[data-panel="summary"]'),
                  hasShadow: !!shadow,
                  variant: generated.getAttribute('variant'),
                  forbiddenID: generated.getAttribute('data-og-id'),
                  forbiddenOnclick: generated.getAttribute('onclick'),
                  forbiddenStyle: generated.getAttribute('style')
                };
              }
              const previewRoot = root('placement-preview-internal');
              const previewTitle = previewRoot.shadowRoot.querySelector('[data-og-id="source-title"]');
              const metadata = api.metadataFor(previewTitle);
              const previewTitleGeneratedBeforeRerender = api.isGenerated(previewTitle);
              const code = state('placement-code-internal');
              const preview = state('placement-preview-internal');
              const loading = state('placement-loading-internal');
              const collapsed = state('placement-collapsed-internal');
              const suspended = api.suspend();
              const serialized = document.documentElement.outerHTML;
              api.resume(suspended);
              api.render();
              const rerenderedPreview = state('placement-preview-internal');
              return {
                code,
                preview,
                loading,
                collapsed,
                rerenderedPreview,
                sourceHTML: source.outerHTML,
                sourceShadow: source.shadowRoot.innerHTML,
                sourceVariant: source.getAttribute('variant'),
                sourceClasses: Array.from(source.classList).sort().join(' '),
                sourceTitleGenerated: api.isGenerated(sourceTitle),
                previewTitleGenerated: previewTitleGeneratedBeforeRerender,
                metadataSourceMatches: metadata ? metadata.source === sourceTitle : false,
                metadataHostID: metadata ? metadata.host.getAttribute('data-og-internal-id') : '',
                serializedHasPreviewVariant: serialized.includes('variant="preview"'),
                serializedHasLoadingClass: serialized.includes('is-loading'),
                serializedHasLegacyState: /data-og-(placement-mode|state-hidden|state-visible)/.test(serialized),
                generatedCountAfterRender: Array.from(document.querySelectorAll('og-placement')).filter((host) =>
                  Array.from(host.children).some((child) => api.isGenerated(child))
                ).length
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let code = try #require(payload["code"] as? [String: Any])
        let preview = try #require(payload["preview"] as? [String: Any])
        let loading = try #require(payload["loading"] as? [String: Any])
        let collapsed = try #require(payload["collapsed"] as? [String: Any])
        let rerenderedPreview = try #require(payload["rerenderedPreview"] as? [String: Any])
        let codePanel = try #require(code["code"] as? [String: Any])
        let codePreview = try #require(code["preview"] as? [String: Any])
        let previewCode = try #require(preview["code"] as? [String: Any])
        let previewPanel = try #require(preview["preview"] as? [String: Any])
        let loadingBody = try #require(loading["body"] as? [String: Any])
        let loadingPanel = try #require(loading["loading"] as? [String: Any])
        let collapsedBody = try #require(collapsed["body"] as? [String: Any])
        let collapsedSummary = try #require(collapsed["summary"] as? [String: Any])

        // 期待値：4状態は標準host stateとproject CSSだけで決まり、clone stateとlegacy属性はsource/serializationへ残らない（Then）
        #expect(code["variant"] as? String == "code")
        #expect(codePanel["display"] as? String == "block")
        #expect(codePreview["display"] as? String == "none")
        #expect(preview["variant"] as? String == "preview")
        #expect(previewCode["display"] as? String == "none")
        #expect(previewPanel["display"] as? String == "block")
        #expect(preview["forbiddenID"] as? String == "source-card")
        #expect(preview["forbiddenOnclick"] is NSNull)
        #expect((preview["forbiddenStyle"] as? String)?.contains("color") == false)
        #expect(loading["ariaBusy"] as? String == "true")
        #expect((loading["classes"] as? String)?.contains("authored-card") == true)
        #expect((loading["classes"] as? String)?.contains("is-loading") == true)
        #expect(loadingBody["visibility"] as? String == "hidden")
        #expect(loadingPanel["display"] as? String == "block")
        #expect(loadingPanel["visibility"] as? String == "visible")
        #expect(collapsed["variant"] as? String == "collapsed")
        #expect(collapsed["ariaExpanded"] as? String == "false")
        #expect(collapsedBody["display"] as? String == "none")
        #expect(collapsedSummary["display"] as? String == "block")
        #expect(code["hasShadow"] as? Bool == true)
        #expect(preview["hasShadow"] as? Bool == true)
        #expect(payload["sourceHTML"] as? String == authoredSource)
        #expect(payload["sourceShadow"] as? String == authoredShadow)
        #expect(payload["sourceVariant"] as? String == "base")
        #expect(payload["sourceClasses"] as? String == "authored-card")
        #expect(payload["sourceTitleGenerated"] as? Bool == false)
        #expect(payload["previewTitleGenerated"] as? Bool == true)
        #expect(payload["metadataSourceMatches"] as? Bool == true)
        #expect(payload["metadataHostID"] as? String == "placement-preview-internal")
        #expect(payload["serializedHasPreviewVariant"] as? Bool == false)
        #expect(payload["serializedHasLoadingClass"] as? Bool == false)
        #expect(payload["serializedHasLegacyState"] as? Bool == false)
        #expect((payload["generatedCountAfterRender"] as? NSNumber)?.intValue == 4)
        #expect(rerenderedPreview["variant"] as? String == "preview")
        #expect((rerenderedPreview["preview"] as? [String: Any])?["display"] as? String == "block")
    }

    /// 論理名（日本語）: Placement registry共通検証関数
    /// 処理概要: 同一fixtureでclone属性、metadata routing、render、clear、suspend/resumeを検証します。
    ///
    /// - Parameter script: 検証対象のplacement reference JavaScript。
    private func verifyPlacementRegistry(script: String) async throws {
        // コンディション：source component、既存child付きplacement host、legacy属性付きsource nodeを読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = ComponentPlacementNavigationWaiter()
        let html = """
        <!doctype html>
        <html>
          <body>
            <article data-og-id="source-card" data-og-internal-id="source-card-internal">
              <h2 data-og-id="source-title" data-og-internal-id="source-title-internal">Title</h2>
            </article>
            <aside
              id="legacy-source"
              data-og-placement-generated="true"
              data-og-source-placement="authored-value"
              data-og-preview-clone="authored-value">Legacy source</aside>
            <og-placement
              data-og-id="placement-card"
              data-og-internal-id="placement-card-internal"
              data-og-source-node-internal-id="source-card-internal"
              style="width:320px;height:180px">
              <span id="authored-host-child">Keep me</span>
            </og-placement>
          </body>
        </html>
        """
        try await waiter.load(html, in: webView)

        // 検証内容：scriptを実行し、再描画とsuspend/resume後のregistryとDOMを取得する（When）
        _ = try await webView.evaluateJavaScript(script)
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const api = window.OpenGraphiteComponentPlacementReferences;
              const host = document.querySelector('[data-og-id="placement-card"]');
              const source = document.querySelector('[data-og-id="source-card"]');
              const sourceTitle = document.querySelector('[data-og-id="source-title"]');
              const generatedChild = () => Array.from(host.children).find((child) => api.isGenerated(child));
              const firstRoot = generatedChild();
              const firstTitle = firstRoot ? firstRoot.querySelector('[data-og-id="source-title"]') : null;
              const metadata = firstTitle ? api.metadataFor(firstTitle) : null;
              const forbiddenNames = new Set([
                'data-og-generated',
                'data-og-placement-generated',
                'data-og-source-placement',
                'data-og-preview-clone'
              ]);
              const generatedAttributeCount = firstRoot
                ? [firstRoot].concat(Array.from(firstRoot.querySelectorAll('*'))).reduce((count, element) => {
                    return count + element.getAttributeNames().filter((name) => forbiddenNames.has(name)).length;
                  }, 0)
                : -1;
              const hostForMatches = firstTitle ? api.hostFor(firstTitle) === host : false;
              const rootForMatches = firstTitle ? api.rootFor(firstTitle) === firstRoot : false;
              const sourceForMatches = firstTitle ? api.sourceFor(firstTitle) === sourceTitle : false;
              const placementID = firstTitle ? api.placementIDFor(firstTitle) : '';

              api.render();
              const secondRoot = generatedChild();
              const oldRootStillGenerated = firstRoot ? api.isGenerated(firstRoot) : true;
              const suspended = api.suspend();
              const generatedCountWhileSuspended = Array.from(host.children).filter((child) => api.isGenerated(child)).length;
              const resumed = api.resume(suspended);
              const generatedCountAfterResume = Array.from(host.children).filter((child) => api.isGenerated(child)).length;
              api.clear();
              const generatedCountAfterClear = Array.from(host.children).filter((child) => api.isGenerated(child)).length;
              api.render();

              const legacy = document.getElementById('legacy-source');
              return {
                firstRootExists: !!firstRoot,
                firstTitleExists: !!firstTitle,
                generatedAttributeCount: generatedAttributeCount,
                metadataPreviewClone: metadata ? metadata.previewClone : false,
                metadataHostMatches: metadata ? metadata.host === host : false,
                metadataRootMatches: metadata ? metadata.root === firstRoot : false,
                metadataSourceMatches: metadata ? metadata.source === sourceTitle : false,
                hostForMatches: hostForMatches,
                rootForMatches: rootForMatches,
                sourceForMatches: sourceForMatches,
                placementID: placementID,
                sourceIsGenerated: api.isGenerated(source),
                oldRootStillGenerated: oldRootStillGenerated,
                rerenderReplacedRoot: !!secondRoot && secondRoot !== firstRoot,
                generatedCountWhileSuspended: generatedCountWhileSuspended,
                resumed: resumed,
                generatedCountAfterResume: generatedCountAfterResume,
                generatedCountAfterClear: generatedCountAfterClear,
                generatedCountAfterRender: Array.from(host.children).filter((child) => api.isGenerated(child)).length,
                authoredHostChildPreserved: !!document.getElementById('authored-host-child'),
                legacyPlacementGenerated: legacy.getAttribute('data-og-placement-generated'),
                legacySourcePlacement: legacy.getAttribute('data-og-source-placement'),
                legacyPreviewClone: legacy.getAttribute('data-og-preview-clone')
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])

        // 期待値：provenance属性はcloneに増えず、private APIはsource/host/placementを解決し、source DOMを保持する（Then）
        #expect(payload["firstRootExists"] as? Bool == true)
        #expect(payload["firstTitleExists"] as? Bool == true)
        #expect((payload["generatedAttributeCount"] as? NSNumber)?.intValue == 0)
        #expect(payload["metadataPreviewClone"] as? Bool == true)
        #expect(payload["metadataHostMatches"] as? Bool == true)
        #expect(payload["metadataRootMatches"] as? Bool == true)
        #expect(payload["metadataSourceMatches"] as? Bool == true)
        #expect(payload["hostForMatches"] as? Bool == true)
        #expect(payload["rootForMatches"] as? Bool == true)
        #expect(payload["sourceForMatches"] as? Bool == true)
        #expect(payload["placementID"] as? String == "placement-card")
        #expect(payload["sourceIsGenerated"] as? Bool == false)
        #expect(payload["oldRootStillGenerated"] as? Bool == false)
        #expect(payload["rerenderReplacedRoot"] as? Bool == true)
        #expect((payload["generatedCountWhileSuspended"] as? NSNumber)?.intValue == 0)
        #expect(payload["resumed"] as? Bool == true)
        #expect((payload["generatedCountAfterResume"] as? NSNumber)?.intValue == 1)
        #expect((payload["generatedCountAfterClear"] as? NSNumber)?.intValue == 0)
        #expect((payload["generatedCountAfterRender"] as? NSNumber)?.intValue == 1)
        #expect(payload["authoredHostChildPreserved"] as? Bool == true)
        #expect(payload["legacyPlacementGenerated"] as? String == "true")
        #expect(payload["legacySourcePlacement"] as? String == "authored-value")
        #expect(payload["legacyPreviewClone"] as? String == "authored-value")
    }
}

/// 論理名（日本語）: Component Placement WebView読み込み待機ヘルパー
/// 概要: placement runtime stateテスのHTML読み込み完了をasync/awaitで待機します。
@MainActor
private final class ComponentPlacementNavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    /// 論理名（日本語）: Component Placement HTML読み込み関数
    /// 処理概要: HTMLをWebViewへ読み込み、navigation完了まで待機します。
    ///
    /// - Parameters:
    ///   - html: 読み込むHTML。
    ///   - webView: 読み込み先WebView。
    func load(_ html: String, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
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

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
