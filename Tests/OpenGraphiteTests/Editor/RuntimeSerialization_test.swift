import Foundation
import Testing
import WebKit

/// 論理名（日本語）: runtimeシリアライズテストスイート
/// 概要: `OpenGraphite.runtime.js` が component 展開後 DOM を source HTML として保存可能な形へ戻すことを確認します。
@MainActor
@Suite("runtimeシリアライズテストスイート")
struct RuntimeSerializationTests {
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
