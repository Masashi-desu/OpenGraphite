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
