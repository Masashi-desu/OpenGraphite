import Foundation
import Testing
import WebKit
@testable import OpenGraphite

/// 論理名（日本語）: runtimeシリアライズテストスイート
/// 概要: `OpenGraphite.runtime.js` が component 展開後 DOM を source HTML として保存可能な形へ戻すことを確認します。
@MainActor
@Suite("runtimeシリアライズテストスイート")
struct RuntimeSerializationTests {
    /// 論理名（日本語）: 選択オブジェクト単体表示復元テスト
    /// 概要: focus isolation が対象 subtree だけを表示し、layout geometry を変えず、解除時に元の表示へ戻すことを検証します。
    @Test("focus isolationは対象subtreeだけをgeometry不変で表示して解除できる")
    func testFocusIsolationShowsOnlyTargetSubtreeAndRestoresDocument() async throws {
        // コンディション：横並びの sibling、対象 frame、対象 child を持つ HTML を WebView に読み込む（Given）
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let pageHTML = """
        <!doctype html>
        <html>
          <head>
            <style>
              html, body { margin: 0; min-width: 640px; min-height: 360px; }
              [data-og-id="page"] { display: flex; align-items: flex-start; gap: 24px; padding: 32px; }
              [data-og-id="leading-sibling"] { width: 96px; height: 72px; }
              [data-og-id="focus-target"] { width: 180px; height: 120px; padding: 12px; }
              [data-og-id="focus-child"] { width: 80px; height: 32px; }
              [data-og-id="trailing-sibling"] { width: 112px; height: 64px; }
            </style>
          </head>
          <body>
            <Page data-og-id="page" data-og-type="page">
              <LeadingSibling data-og-id="leading-sibling" data-og-type="frame">Leading</LeadingSibling>
              <FocusTarget data-og-id="focus-target" data-og-type="frame">
                <FocusChild data-og-id="focus-child" data-og-type="text">Focused child</FocusChild>
              </FocusTarget>
              <TrailingSibling data-og-id="trailing-sibling" data-og-type="frame">Trailing</TrailingSibling>
            </Page>
          </body>
        </html>
        """
        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(WebCanvasFocusIsolationScript.source)
        let rootAttributeLiteral = Self.javaScriptLiteral(WebCanvasFocusIsolationScript.rootAttributeName)
        let visibleAttributeLiteral = Self.javaScriptLiteral(WebCanvasFocusIsolationScript.visibleAttributeName)

        // 検証内容：対象 frame に focus isolation を適用し、表示状態と geometry を取得してから解除する（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const rootAttribute = \(rootAttributeLiteral);
              const visibleAttribute = \(visibleAttributeLiteral);
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
              const applied = window.OpenGraphiteFocusIsolation.apply([target]);
              const focusedRect = rect(target);
              const focusedState = {
                active: window.OpenGraphiteFocusIsolation.isActive(),
                targetVisible: isVisible(target),
                childVisible: isVisible(child),
                leadingSiblingVisible: isVisible(leadingSibling),
                trailingSiblingVisible: isVisible(trailingSibling),
                rootMarkers: document.querySelectorAll('[' + rootAttribute + ']').length,
                visibleMarkers: document.querySelectorAll('[' + visibleAttribute + ']').length
              };
              window.OpenGraphiteFocusIsolation.clear();
              return {
                applied: applied,
                beforeRect: beforeRect,
                focusedRect: focusedRect,
                clearedRect: rect(target),
                focusedState: focusedState,
                activeAfterClear: window.OpenGraphiteFocusIsolation.isActive(),
                targetVisibleAfterClear: isVisible(target),
                childVisibleAfterClear: isVisible(child),
                leadingSiblingVisibleAfterClear: isVisible(leadingSibling),
                trailingSiblingVisibleAfterClear: isVisible(trailingSibling),
                rootMarkersAfterClear: document.querySelectorAll('[' + rootAttribute + ']').length,
                visibleMarkersAfterClear: document.querySelectorAll('[' + visibleAttribute + ']').length
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let focusedState = try #require(payload["focusedState"] as? [String: Any])
        let beforeRect = try Self.numericArray(from: payload["beforeRect"])
        let focusedRect = try Self.numericArray(from: payload["focusedRect"])
        let clearedRect = try Self.numericArray(from: payload["clearedRect"])

        // 期待値：対象 subtree だけが表示され、geometry は不変で、clear 後は marker なしの元表示へ完全に戻る（Then）
        #expect(payload["applied"] as? Bool == true)
        #expect(focusedState["active"] as? Bool == true)
        #expect(focusedState["targetVisible"] as? Bool == true)
        #expect(focusedState["childVisible"] as? Bool == true)
        #expect(focusedState["leadingSiblingVisible"] as? Bool == false)
        #expect(focusedState["trailingSiblingVisible"] as? Bool == false)
        #expect(((focusedState["rootMarkers"] as? NSNumber)?.intValue ?? 0) > 0)
        #expect(((focusedState["visibleMarkers"] as? NSNumber)?.intValue ?? 0) > 0)
        #expect(Self.rectsAreEqual(beforeRect, focusedRect))
        #expect(Self.rectsAreEqual(beforeRect, clearedRect))
        #expect(payload["activeAfterClear"] as? Bool == false)
        #expect(payload["targetVisibleAfterClear"] as? Bool == true)
        #expect(payload["childVisibleAfterClear"] as? Bool == true)
        #expect(payload["leadingSiblingVisibleAfterClear"] as? Bool == true)
        #expect(payload["trailingSiblingVisibleAfterClear"] as? Bool == true)
        #expect((payload["rootMarkersAfterClear"] as? NSNumber)?.intValue == 0)
        #expect((payload["visibleMarkersAfterClear"] as? NSNumber)?.intValue == 0)
    }

    /// 論理名（日本語）: focus一時属性シリアライズ除去テスト
    /// 概要: focus isolation の実行時属性が runtime の保存用 HTML に混入しないことを検証します。
    @Test("runtimeはfocus isolation一時属性を保存HTMLから除去する")
    func testSerializeDocumentRemovesFocusIsolationAttributes() async throws {
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
        let rootAttributeLiteral = Self.javaScriptLiteral(WebCanvasFocusIsolationScript.rootAttributeName)
        let visibleAttributeLiteral = Self.javaScriptLiteral(WebCanvasFocusIsolationScript.visibleAttributeName)
        let focusStyleElementIDLiteral = Self.javaScriptLiteral(WebCanvasFocusIsolationScript.styleElementID)

        // 検証内容：focus 適用中の document を OpenGraphite runtime で保存用 HTML へシリアライズする（When）
        let result = try await webView.evaluateJavaScript(
            """
            (() => {
              const rootAttribute = \(rootAttributeLiteral);
              const visibleAttribute = \(visibleAttributeLiteral);
              const focusStyleElementID = \(focusStyleElementIDLiteral);
              const target = document.querySelector('[data-og-id="focus-target"]');
              const applied = window.OpenGraphiteFocusIsolation.apply([target]);
              return {
                applied: applied,
                liveRootMarkers: document.querySelectorAll('[' + rootAttribute + ']').length,
                liveVisibleMarkers: document.querySelectorAll('[' + visibleAttribute + ']').length,
                liveFocusStyle: !!document.getElementById(focusStyleElementID),
                serialized: window.OpenGraphiteRuntime.serializeDocument()
              };
            })();
            """
        )
        let payload = try #require(result as? [String: Any])
        let serialized = try #require(payload["serialized"] as? String)

        // 期待値：live DOM には一時 marker がある一方、保存 HTML は marker を除去して source subtree と sibling を保持する（Then）
        #expect(payload["applied"] as? Bool == true)
        #expect(((payload["liveRootMarkers"] as? NSNumber)?.intValue ?? 0) > 0)
        #expect(((payload["liveVisibleMarkers"] as? NSNumber)?.intValue ?? 0) > 0)
        #expect(payload["liveFocusStyle"] as? Bool == true)
        #expect(!serialized.contains(WebCanvasFocusIsolationScript.rootAttributeName))
        #expect(!serialized.contains(WebCanvasFocusIsolationScript.visibleAttributeName))
        #expect(!serialized.contains(WebCanvasFocusIsolationScript.styleElementID))
        #expect(serialized.contains("data-og-id=\"focus-target\""))
        #expect(serialized.contains("data-og-id=\"focus-child\""))
        #expect(serialized.contains("data-og-id=\"sibling\""))
    }

    /// 論理名（日本語）: template slot復元テスト
    /// 概要: runtime 展開で書き換えられた slot 内ノード ID と runtime 属性が、保存用 HTML に残らないことを検証します。
    @Test("template slot内のruntime生成属性を保存HTMLから除去する")
    func testSerializeDocumentRestoresTemplateSlotSourceIDs() async throws {
        // Given: runtime JS と、template slot を持つ component instance / master を WebView に読み込む
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <SiteHeader data-og-id="site-header-master" data-og-type="frame" data-og-component="site-header" data-og-component-kind="master" data-og-part="root">
              <Nav data-og-id="nav" data-og-type="frame" data-og-slot="nav">
                <a data-og-id="fallback-link" data-og-type="button">Fallback</a>
              </Nav>
            </SiteHeader>
          </body>
        </html>
        """
        let pageHTML = """
        <!doctype html>
        <html>
          <body>
            <og-instance data-og-id="site-header" data-og-type="frame" data-og-component="site-header" data-og-internal-id="instance-internal">
              <template slot="nav">
                <a data-og-id="nav-home" data-og-type="button" data-og-internal-id="nav-home-internal">Home</a>
              </template>
            </og-instance>
          </body>
        </html>
        """

        try await waiter.load(pageHTML, in: webView)
        _ = try await webView.evaluateJavaScript(runtimeSource)

        // When: runtime で component を展開してから保存用 HTML を生成する
        let serializedResult = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            window.OpenGraphiteRuntime.serializeDocument();
            """
        )
        let serialized = try #require(serializedResult as? String)

        // Then: template slot の source ID は元へ戻り、runtime 専用属性と style は保存HTMLへ残らない
        #expect(serialized.contains("data-og-id=\"nav-home\""))
        #expect(serialized.contains("data-og-internal-id=\"nav-home-internal\""))
        #expect(!serialized.contains("site-header-nav-home"))
        #expect(!serialized.contains("data-og-generated"))
        #expect(!serialized.contains("data-og-source-component"))
        #expect(!serialized.contains("data-og-source-instance"))
        #expect(!serialized.contains("data-og-source-id"))
        #expect(!serialized.contains("opengraphite-runtime-style"))
    }

    /// 論理名（日本語）: slot text binding metadata伝播テスト
    /// 概要: component runtime が slot source の i18n metadata を生成済み text node へコピーすることを検証します。
    @Test("runtimeはslot sourceのtext binding metadataを生成slotへ伝播する")
    func testRuntimeCopiesSlotTextBindingMetadataToGeneratedSlot() async throws {
        // Given: i18n metadata を持つ slot source と、text slot を持つ component master を WebView に読み込む
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <Card data-og-id="card-master" data-og-type="frame" data-og-component="card" data-og-component-kind="master" data-og-part="root">
              <CardTitle data-og-id="card-title" data-og-type="text" data-og-slot="title">Fallback title</CardTitle>
            </Card>
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

        // When: runtime で component を展開し、生成済み slot node の metadata を読む
        let value = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            (() => {
              const slot = document.querySelector('[data-og-id="card-instance-card-title"]');
              return {
                text: slot ? slot.textContent : '',
                textSource: slot ? slot.getAttribute('data-og-text-source') || '' : '',
                i18nKey: slot ? slot.getAttribute('data-i18n-key') || '' : '',
                variant: slot ? slot.getAttribute('data-og-text-variant-eng') || '' : ''
              };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // Then: 生成済み text node でも binding node として扱える metadata が保持される
        #expect(payload["text"] as? String == "日本語スロット")
        #expect(payload["textSource"] as? String == "binding")
        #expect(payload["i18nKey"] as? String == "home.card.title")
        #expect(payload["variant"] as? String == "English slot title")
    }

    /// 論理名（日本語）: runtime component error解除テスト
    /// 概要: 一度 master 未解決になった instance でも、後続の component HTML 注入で error 属性が解除されることを検証します。
    @Test("runtimeは後続のmaster解決でmissing-master errorを解除する")
    func testRuntimeClearsMissingMasterErrorAfterLaterResolution() async throws {
        // Given: master がまだ無い状態で component instance を含む page を WebView に読み込む
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <Card data-og-id="card-master" data-og-type="frame" data-og-component="card" data-og-component-kind="master" data-og-part="root">
              <CardTitle data-og-id="card-title" data-og-type="text" data-og-slot="title">Fallback title</CardTitle>
            </Card>
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

        // When: 先に空 registry で未解決状態を作り、その後 master HTML を注入して再描画する
        let value = try await webView.evaluateJavaScript(
            """
            (() => {
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([]);
            const before = document.querySelector('og-instance').getAttribute('data-og-component-error') || '';
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            const instance = document.querySelector('og-instance');
            const generated = document.querySelector('[data-og-generated="true"]');
            return {
              before: before,
              after: instance.getAttribute('data-og-component-error') || '',
              generatedText: generated ? generated.textContent.trim() : ''
            };
            })();
            """
        )
        let payload = try #require(value as? [String: Any])

        // Then: 旧 error は残らず、生成 DOM が表示される
        #expect(payload["before"] as? String == "missing-master")
        #expect(payload["after"] as? String == "")
        #expect(payload["generatedText"] as? String == "Resolved title")
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
            <Card data-og-id="card-master" data-og-internal-id="card-root-internal" data-og-type="frame" data-og-component="card" data-og-component-kind="master" data-og-part="root">
              <CardTitle data-og-id="card-title" data-og-internal-id="card-title-internal" data-og-type="text" data-og-slot="title">Fallback title</CardTitle>
            </Card>
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
              const roots = Array.from(document.querySelectorAll('[data-og-generated="true"][data-og-source-id="card-master"]'));
              const titles = Array.from(document.querySelectorAll('[data-og-generated="true"][data-og-source-id="card-title"]'));
              return {
                rootIDs: roots.map((node) => node.getAttribute('data-og-id') || ''),
                rootInternalIDs: roots.map((node) => node.getAttribute('data-og-internal-id') || ''),
                titleIDs: titles.map((node) => node.getAttribute('data-og-id') || ''),
                titleInternalIDs: titles.map((node) => node.getAttribute('data-og-internal-id') || '')
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
    }

    /// 論理名（日本語）: 実装runtime一時HTML復元テスト
    /// 概要: 実装 i18n runtime が解決済み text を DOM へ反映しても、保存HTMLにはfallbackが残ることを検証します。
    @Test("runtimeは実装runtimeの一時text HTMLを保存時にfallbackへ戻す")
    func testRuntimeFallbackHTMLIsRestoredWithoutResolvingI18nText() async throws {
        // Given: runtime JS と、page内 text / component slot text を WebView に読み込む
        let webView = WKWebView(frame: .zero)
        let waiter = WebViewNavigationWaiter()
        let runtimeSource = try runtimeJavaScriptSource()
        let componentHTML = """
        <!doctype html>
        <html>
          <body>
            <Card data-og-id="card-master" data-og-type="frame" data-og-component="card" data-og-component-kind="master" data-og-part="root">
              <CardTitle data-og-id="card-title" data-og-type="text" data-og-slot="title">Fallback slot</CardTitle>
            </Card>
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

        // When: 実装 i18n runtime 相当の一時 text 置換後に保存用 HTML を取得する
        let value = try await webView.evaluateJavaScript(
            """
            window.OpenGraphiteRuntime.renderComponentHTMLDocuments([\(Self.javaScriptLiteral(componentHTML))]);
            (() => {
              const title = document.querySelector('[data-i18n-key="home.title"]');
              title.setAttribute('data-og-runtime-fallback-html', title.innerHTML);
              title.innerHTML = 'English title';
              const slot = document.querySelector('[data-og-id="card-instance-card-title"]');
              slot.setAttribute('data-og-runtime-fallback-html', slot.innerHTML);
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

        // Then: preview DOM は実装 runtime の解決済み text、serialize 結果は fallback source を保持する
        #expect(values["title"] as? String == "English title")
        #expect(values["slot"] as? String == "Slot English")
        #expect(serialized.contains("日本語タイトル"))
        #expect(serialized.contains(">スロット</span>"))
        #expect(!serialized.contains("data-og-runtime-fallback-html"))
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
