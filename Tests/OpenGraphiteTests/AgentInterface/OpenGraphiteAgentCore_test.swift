import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: Agentインターフェース関連のテストスイート
/// 概要: `ogkiln` core の graph、validation、node 単位編集、CLI 実行を確認します。
@Suite("Agentインターフェース関連のテストスイート")
struct OpenGraphiteAgentCoreTests {
    /// 論理名（日本語）: ページグラフ抽出テスト
    /// 概要: HTML から `data-og-id` ノードと CSS 変数を抽出できることを検証します。
    @Test("HTMLからpage graphを抽出できる")
    func testPageGraphExtractsNodes() throws {
        // コンディション：OpenGraphite 契約に沿った HTML を一時ファイルへ用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Hero data-og-id="hero" data-og-type="frame" data-og-layout="horizontal" style="--og-gap:24px;">
                <Title data-og-id="title" data-og-type="text">OpenGraphite</Title>
              </Hero>
            </body></html>
            """
        )

        // 検証内容：page graph を生成する
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：DOM 出現順のノードと CSS 変数が取得できる
        #expect(graph.nodes.map(\.id) == ["hero", "title"])
        #expect(graph.nodes[0].cssVariables["--og-gap"] == "24px")
        #expect(graph.nodes[0].textContent == "OpenGraphite")
        #expect(graph.nodes[1].parentID == "hero")
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: 重複ID検証テスト
    /// 概要: `data-og-id` が重複する HTML を validation error として扱うことを確認します。
    @Test("重複data-og-idを検証エラーにする")
    func testValidateReportsDuplicateIDs() throws {
        // コンディション：同じ data-og-id を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Frame data-og-id="hero" data-og-type="frame"></Frame>
              <Frame data-og-id="hero" data-og-type="frame"></Frame>
            </body></html>
            """
        )

        // 検証内容：HTML を検証する
        let result = try fixture.core.validateHTML(at: fixture.htmlURL)

        // 期待値：duplicate-data-og-id が error として返る
        #expect(result.valid == false)
        #expect(result.diagnostics.contains { $0.code == "duplicate-data-og-id" && $0.severity == .error })
    }

    /// 論理名（日本語）: CSS変数編集テスト
    /// 概要: node 単位 CSS 変数編集が runtime 属性を正本 HTML へ残さず保存されることを確認します。
    @Test("CSS変数編集でruntime状態を除去して保存する")
    func testSetCSSVariableStripsRuntimeState() throws {
        // コンディション：runtime 属性と編集補助 CSS 変数を含む HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Hero data-og-id="hero" data-og-type="frame" data-og-selected="true" style="--og-gap:24px; --og-edit-width:100px;"></Hero>
            </body></html>
            """
        )

        // 検証内容：hero の --og-gap を更新する
        let result = try fixture.core.setCSSVariable("--og-gap", value: "32px", nodeID: "hero", htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：CSS 変数は更新され、runtime 状態は削除される
        #expect(result.updated == true)
        #expect(result.node?.cssVariables["--og-gap"] == "32px")
        #expect(html.contains("--og-gap:32px;"))
        #expect(!html.contains("data-og-selected"))
        #expect(!html.contains("--og-edit-width"))
    }

    /// 論理名（日本語）: 不許可属性編集テスト
    /// 概要: `data-og-id` 変更など安定キーを壊す属性編集が拒否されることを確認します。
    @Test("不許可属性編集を拒否する")
    func testSetAttributeRejectsDisallowedAttribute() throws {
        // コンディション：編集対象 HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Hero data-og-id="hero" data-og-type="frame"></Hero></body></html>
            """
        )

        // 検証内容：data-og-id の変更を試みる
        let result = try fixture.core.setAttribute("data-og-id", value: "renamed", nodeID: "hero", htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：編集は失敗し、元 HTML は変更されない
        #expect(result.updated == false)
        #expect(result.diagnostics.contains { $0.code == "disallowed-attribute" })
        #expect(html.contains("data-og-id=\"hero\""))
        #expect(!html.contains("renamed"))
    }

    /// 論理名（日本語）: Mock属性編集拒否テスト
    /// 概要: preview 専用 mock injection を HTML 属性として保存しないことを確認します。
    @Test("data-og-mock属性をHTML編集対象にしない")
    func testSetAttributeRejectsMockInjectionAttribute() throws {
        // コンディション：placement host を含む HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <og-placement data-og-id="placement" data-og-type="frame" data-og-role="component-placement"></og-placement>
            </body></html>
            """
        )

        // 検証内容：mock injection 用の任意パラメータ属性を設定しようとする
        let result = try fixture.core.setAttribute(
            "data-og-mock-code-viewer-mode",
            value: "preview",
            nodeID: "placement",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：属性は拒否され、正本 HTML へ保存されない
        #expect(result.updated == false)
        #expect(result.diagnostics.contains { $0.code == "disallowed-attribute" })
        #expect(!html.contains("data-og-mock-code-viewer-mode"))
    }

    /// 論理名（日本語）: Lucideアイコンノード契約テスト
    /// 概要: `data-og-type="icon"` と Lucide の page-side metadata が contract validation を通ることを確認します。
    @Test("LucideアイコンノードをHTML契約として扱える")
    func testValidateAcceptsLucideIconNode() throws {
        // コンディション：inline Lucide SVG を保持する icon node を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="decorative-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline" style="--og-width:24px; --og-height:24px; --og-stroke-width:2;">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
              </Icon>
            </body></html>
            """
        )

        // 検証内容：page graph と validation を実行する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let result = try fixture.core.validateHTML(at: fixture.htmlURL)

        // 期待値：icon primitive と Lucide metadata が既知の契約として扱われる（Then）
        #expect(result.valid == true)
        #expect(graph.nodes.map(\.type) == ["icon"])
        #expect(graph.nodes[0].attributes["data-og-icon-library"] == "lucide")
        #expect(graph.nodes[0].attributes["data-og-icon-name"] == "circle")
        #expect(graph.nodes[0].attributes["data-og-icon-source"] == "inline")
        #expect(graph.nodes[0].cssVariables["--og-stroke-width"] == "2")
    }

    /// 論理名（日本語）: アイコン更新テスト
    /// 概要: icon node の metadata と page-side inline SVG が同時に保存されることを確認します。
    @Test("Lucideアイコン更新でmetadataとinline SVGを保存する")
    func testSetIconUpdatesMetadataAndInlineSVG() throws {
        // コンディション：circle の icon node を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="decorative-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
              </Icon>
            </body></html>
            """
        )

        // 検証内容：icon name を star に更新する（When）
        let result = try fixture.core.setIcon(
            library: "lucide",
            name: "star",
            source: "inline",
            nodeID: "decorative-icon",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：metadata と inline SVG body が star に更新される（Then）
        #expect(result.updated == true)
        #expect(result.node?.attributes["data-og-icon-name"] == "star")
        #expect(html.contains("data-og-icon-name=\"star\""))
        #expect(html.contains("11.525 2.295"))
        #expect(!html.contains("<circle cx=\"12\" cy=\"12\" r=\"10\"></circle>"))
    }

    /// 論理名（日本語）: アイコン挿入テスト
    /// 概要: anchor node 基準で Lucide CDN icon node を挿入できることを確認します。
    @Test("Lucide CDNアイコンをnodeとして挿入できる")
    func testInsertIconCreatesCDNIconNode() throws {
        // コンディション：挿入先 frame を持つ HTML を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Frame data-og-id="hero" data-og-type="frame"></Frame></body></html>
            """
        )

        // 検証内容：hero の子として star アイコンを CDN source で挿入する（When）
        let result = try fixture.core.insertIcon(
            library: "lucide",
            name: "star",
            source: "cdn",
            iconID: nil,
            anchorNodeID: "hero",
            position: .append,
            width: nil,
            height: nil,
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：新規 icon node が挿入され、Lucide static CDN 参照を保持する（Then）
        #expect(result.updated == true)
        #expect(result.insertedNodes?.map(\.id) == ["icon-star"])
        #expect(result.insertedNodes?.first?.internalID.isEmpty == false)
        #expect(result.insertedNodes?.first?.internalID != "hero")
        #expect(result.insertedNodes?.first?.attributes["data-og-icon-source"] == "cdn")
        #expect(html.contains("data-og-internal-id="))
        #expect(html.contains("data-og-icon-mask=\"true\""))
        #expect(html.contains("https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg"))
        #expect(html.contains("--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(html.contains("--og-width:24px; --og-height:24px;"))
    }

    /// 論理名（日本語）: Placement Mock Stateデコードテスト
    /// 概要: `.ogp` previewContext が placement 単位の mock injection を保持できることを確認します。
    @Test("previewContextはplacementMocksを保持できる")
    func testPreviewContextDecodesPlacementMocks() throws {
        // コンディション：canvas 全体と placement 単位の Mock State を持つ JSON を用意する（Given）
        let json = """
        {
          "locale": "ja-JP",
          "direction": "ltr",
          "fieldMocks": {
            "selectedLanguage": "ja"
          },
          "placementMocks": {
            "67a2e12dbed8": {
              "codeViewerMode": "preview",
              "selectedLanguage": "ja"
            }
          }
        }
        """
        let context = try JSONDecoder().decode(OpenGraphitePreviewContext.self, from: Data(json.utf8))

        // 検証内容：再エンコードする（When）
        let encodedData = try JSONEncoder().encode(context)
        let encoded = String(data: encodedData, encoding: .utf8) ?? ""

        // 期待値：旧形式 locale / direction は読み込み互換だけで、placementMocks は保存対象になる（Then）
        #expect(context.locale == "ja-JP")
        #expect(context.direction == "ltr")
        #expect(context.fieldMocks["selectedLanguage"] == "ja")
        #expect(context.placementMocks["67a2e12dbed8"]?["codeViewerMode"] == "preview")
        #expect(encoded.contains("placementMocks"))
        #expect(!encoded.contains("locale"))
        #expect(!encoded.contains("direction"))
    }

    /// 論理名（日本語）: ノード検索テスト
    /// 概要: type、role、text を組み合わせて node graph を検索できることを確認します。
    @Test("node queryで条件に一致するノードを検索できる")
    func testQueryNodesFiltersGraph() throws {
        // コンディション：role と text を持つ複数 node の HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Page data-og-id="page" data-og-type="page">
                <Button data-og-id="download-button" data-og-type="button" data-og-role="primary-button">Download</Button>
                <Button data-og-id="docs-button" data-og-type="button" data-og-role="secondary-button">Docs</Button>
              </Page>
            </body></html>
            """
        )

        // 検証内容：button type と Download text で検索する
        let result = try fixture.core.queryNodes(
            at: fixture.htmlURL,
            query: OpenGraphiteNodeQuery(idContains: nil, type: "button", role: nil, tag: nil, textContains: "download")
        )

        // 期待値：条件に一致する node だけが返る
        #expect(result.nodes.map(\.id) == ["download-button"])
        #expect(result.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: テキスト内容編集テスト
    /// 概要: text content 更新が HTML としてではなくプレーンテキストとして保存されることを確認します。
    @Test("text contentをHTML escapeして更新できる")
    func testSetTextContentEscapesHTML() throws {
        // コンディション：テキスト node を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Title data-og-id="title" data-og-type="text">Old</Title></body></html>
            """
        )

        // 検証内容：HTML 記号を含む text content を設定する
        let result = try fixture.core.setTextContent("Open <Graphite> & AI", nodeID: "title", htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：HTML として解釈されない形で保存される
        #expect(result.updated == true)
        #expect(html.contains("Open &lt;Graphite&gt; &amp; AI"))
        #expect(result.node?.textContent == "Open <Graphite> & AI")
    }

    /// 論理名（日本語）: テキストvariant編集テスト
    /// 概要: `data-i18n-key` を指定して、node ID を持たない slot text にも locale variant を保存できることを確認します。
    @Test("data-i18n-keyでtext variantを更新できる")
    func testSetTextVariantByI18nKey() throws {
        // コンディション：通常 text node と slot 用 text binding を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語タイトル</Title>
              <span slot="title" data-og-text-source="binding" data-i18n-key="home.slot.title">スロット</span>
            </body></html>
            """
        )

        // 検証内容：i18n key を指定して英語 variant を保存する
        let titleResult = try fixture.core.setTextVariant(
            "English title",
            locale: "eng",
            i18nKey: "home.title",
            htmlURL: fixture.htmlURL
        )
        let slotResult = try fixture.core.setTextVariant(
            "Slot <br> English",
            locale: "eng",
            i18nKey: "home.slot.title",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：node id の有無に関わらず variant 属性へ保存される
        #expect(titleResult.updated == true)
        #expect(slotResult.updated == true)
        #expect(html.contains("data-i18n-key=\"home.title\""))
        #expect(html.contains("data-og-text-variant-eng=\"English title\""))
        #expect(html.contains("data-i18n-key=\"home.slot.title\""))
        #expect(html.contains("data-og-text-variant-eng=\"Slot &lt;br> English\""))
    }

    /// 論理名（日本語）: i18n literal loadPath検出テスト
    /// 概要: module import 先の `i18n.init` から literal loadPath を検出し、editable として扱うことを確認します。
    @Test("i18n inspectはmodule import先のliteral loadPathをeditableとして検出する")
    func testI18nInspectDetectsLiteralLoadPathThroughModuleImport() throws {
        // コンディション：module script から import される i18n 設定ファイルを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><script type="module" src="./app.js"></script></head><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語</Title>
            </body></html>
            """
        )
        try """
        import "./i18n-config.js";
        """.write(to: fixture.rootURL.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)
        try """
        i18n.init({
          lng: selectedLanguage(),
          fallbackLng: "ja",
          backend: { loadPath: "/locales/{{lng}}.json" }
        });
        """.write(to: fixture.rootURL.appendingPathComponent("i18n-config.js"), atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：i18n runtime を検査する（When）
        let result = try fixture.core.inspectI18n(projectURL: projectURL, pageID: "home")

        // 期待値：i18next adapter と literal loadPath が編集可能として検出される（Then）
        #expect(result.adapter == .i18next)
        #expect(result.configSource?.hasSuffix("i18n-config.js") == true)
        #expect(result.loadPath.source == .literal)
        #expect(result.loadPath.value == "/locales/{{lng}}.json")
        #expect(result.loadPath.editable == true)
        #expect(result.localeField == "selectedLanguage")
    }

    /// 論理名（日本語）: i18n external loadPath検出テスト
    /// 概要: env 参照などの動的 loadPath を external readonly として扱うことを確認します。
    @Test("i18n inspectはenv参照loadPathをexternal readonlyとして検出する")
    func testI18nInspectMarksEnvLoadPathExternalReadOnly() throws {
        // コンディション：env 参照の loadPath を持つ i18n 設定を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><script type="module" src="./i18n.js"></script></head><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語</Title>
            </body></html>
            """
        )
        try """
        i18n.init({
          lng: "ja",
          fallbackLng: "ja",
          backend: { loadPath: import.meta.env.VITE_I18N_LOAD_PATH }
        });
        """.write(to: fixture.rootURL.appendingPathComponent("i18n.js"), atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：i18n runtime を検査する（When）
        let result = try fixture.core.inspectI18n(projectURL: projectURL, pageID: "home")

        // 期待値：dynamic loadPath は external / readonly として表示される（Then）
        #expect(result.adapter == .i18next)
        #expect(result.loadPath.source == .external)
        #expect(result.loadPath.editable == false)
        #expect(result.loadPath.expression?.contains("import.meta.env.VITE_I18N_LOAD_PATH") == true)
        #expect(result.resources.allSatisfy { $0.editable == false })
        #expect(result.diagnostics.contains { $0.code == "external-i18n-load-path" })
    }

    /// 論理名（日本語）: i18n runtime literal更新テスト
    /// 概要: Project Dependencies から編集する想定で、literal の loadPath と fallbackLng だけを実装設定へ書き戻せることを確認します。
    @Test("i18n runtime literal設定を書き戻せる")
    func testUpdateI18nRuntimeLiteralsUpdatesConfigFile() throws {
        // コンディション：literal loadPath / fallbackLng と external lng を持つ i18n 設定を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><script src="./i18n.js" defer></script></head><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語</Title>
            </body></html>
            """
        )
        try """
        i18n.init({
          lng: selectedLanguage(),
          fallbackLng: "ja",
          backend: { loadPath: "/locales/{{lng}}.json" }
        });
        """.write(to: fixture.rootURL.appendingPathComponent("i18n.js"), atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：literal 設定だけを更新する（When）
        let result = try fixture.core.updateI18nRuntimeLiterals(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            loadPath: "/assets/i18n/{{lng}}.json",
            fallbackLocale: "eng"
        )
        let source = try String(contentsOf: fixture.rootURL.appendingPathComponent("i18n.js"), encoding: .utf8)

        // 期待値：loadPath / fallbackLng は更新され、lng の実装式は保持される（Then）
        #expect(result.updated == true)
        #expect(result.inspection.loadPath.value == "/assets/i18n/{{lng}}.json")
        #expect(result.inspection.fallbackLng.value == "eng")
        #expect(source.contains("lng: selectedLanguage()"))
        #expect(source.contains(#"fallbackLng: "eng""#))
        #expect(source.contains(#"loadPath: "/assets/i18n/{{lng}}.json""#))
    }

    /// 論理名（日本語）: 子HTML先頭挿入テスト
    /// 概要: `data-og-id` で指定した親ノードの先頭へ子 HTML を挿入できることを確認します。
    @Test("指定ノードの先頭へ子HTMLを挿入できる")
    func testPrependChildHTMLInsertsNodes() throws {
        // コンディション：page ノードを持つ HTML と、挿入する header 断片を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"></Hero></Page></body></html>
            """
        )
        let headerHTML = """
              <Header data-og-id="site-header" data-og-type="frame" data-og-layout="horizontal">
                <Button data-og-id="nav-home" data-og-type="button" data-og-role="secondary-button">Home</Button>
              </Header>
            """

        // 検証内容：page の先頭へ header を挿入する
        let result = try fixture.core.prependChildHTML(headerHTML, parentNodeID: "page", htmlURL: fixture.htmlURL)
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：挿入 node が page 直下で hero より前に現れる
        #expect(result.updated == true)
        #expect(result.insertedNodes?.map(\.id) == ["site-header", "nav-home"])
        #expect(graph.nodes.map(\.id).prefix(4) == ["page", "site-header", "nav-home", "hero"])
    }

    /// 論理名（日本語）: 子HTML重複ID拒否テスト
    /// 概要: 子 HTML 挿入で `data-og-id` が重複する場合にファイルを書き換えないことを確認します。
    @Test("子HTML挿入で重複data-og-idを拒否する")
    func testPrependChildHTMLRejectsDuplicateID() throws {
        // コンディション：既存 hero と同じ ID を持つ子 HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let originalHTML = AgentInterfaceFixture.htmlWithInternalIDs(
            """
        <!doctype html>
        <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"></Hero></Page></body></html>
        """
        )
        try fixture.writeHTML(originalHTML)

        // 検証内容：重複 ID の断片を挿入する
        let result = try fixture.core.prependChildHTML(
            "<Other data-og-id=\"hero\" data-og-type=\"frame\"></Other>",
            parentNodeID: "page",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：validation error になり、ファイルは元のまま残る
        #expect(result.updated == false)
        #expect(result.diagnostics.contains { $0.code == "duplicate-data-og-id" && $0.severity == .error })
        #expect(html == originalHTML)
    }

    /// 論理名（日本語）: HTML挿入位置テスト
    /// 概要: before / after / append の HTML 断片挿入が node graph に反映されることを確認します。
    @Test("HTML断片を指定位置へ挿入できる")
    func testInsertHTMLAtPositions() throws {
        // コンディション：page、hero、footer を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"></Hero><Footer data-og-id="footer" data-og-type="frame"></Footer></Page></body></html>
            """
        )

        // 検証内容：hero の前後と footer の子へ HTML 断片を挿入する
        _ = try fixture.core.insertHTML(
            "<Eyebrow data-og-id=\"eyebrow\" data-og-type=\"text\" data-og-role=\"eyebrow\">Intro</Eyebrow>",
            anchorNodeID: "hero",
            position: .before,
            htmlURL: fixture.htmlURL
        )
        _ = try fixture.core.insertHTML(
            "<CTA data-og-id=\"cta\" data-og-type=\"button\" data-og-role=\"primary-button\">Start</CTA>",
            anchorNodeID: "hero",
            position: .after,
            htmlURL: fixture.htmlURL
        )
        _ = try fixture.core.insertHTML(
            "<FooterText data-og-id=\"footer-text\" data-og-type=\"text\">End</FooterText>",
            anchorNodeID: "footer",
            position: .append,
            htmlURL: fixture.htmlURL
        )
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：挿入した node が指定位置に現れる
        #expect(graph.nodes.map(\.id) == ["page", "eyebrow", "hero", "cta", "footer", "footer-text"])
        #expect(graph.nodes.first { $0.id == "footer-text" }?.parentID == "footer")
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: HTML置換削除テスト
    /// 概要: node subtree の置換と削除が validation を通して保存されることを確認します。
    @Test("node subtreeを置換して削除できる")
    func testReplaceAndDeleteNodeHTML() throws {
        // コンディション：置換対象と削除対象を含む HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"></Hero><Footer data-og-id="footer" data-og-type="frame"></Footer></Page></body></html>
            """
        )

        // 検証内容：hero を title 付きに置換し、footer を削除する
        _ = try fixture.core.replaceNodeHTML(
            "<Hero data-og-id=\"hero\" data-og-type=\"frame\"><Title data-og-id=\"title\" data-og-type=\"text\">New</Title></Hero>",
            nodeID: "hero",
            htmlURL: fixture.htmlURL
        )
        let deleteResult = try fixture.core.deleteNode(nodeID: "footer", htmlURL: fixture.htmlURL)
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：置換後 node が残り、削除対象は graph から消える
        #expect(deleteResult.updated == true)
        #expect(graph.nodes.map(\.id) == ["page", "hero", "title"])
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: ノード移動複製テスト
    /// 概要: 既存 node の移動と subtree 複製で `data-og-id` の一意性が保たれることを確認します。
    @Test("node subtreeを移動してprefix付きで複製できる")
    func testMoveAndCopyNode() throws {
        // コンディション：hero、title、footer を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"><Title data-og-id="title" data-og-type="text">Hero</Title></Hero><Footer data-og-id="footer" data-og-type="frame"></Footer></Page></body></html>
            """
        )

        // 検証内容：footer を hero の前へ移動し、hero subtree を prefix 付きで複製する
        _ = try fixture.core.moveNode(nodeID: "footer", targetNodeID: "hero", position: .before, htmlURL: fixture.htmlURL)
        let copyResult = try fixture.core.copyNode(
            nodeID: "hero",
            targetNodeID: "footer",
            position: .after,
            idPrefix: "copy-",
            htmlURL: fixture.htmlURL
        )
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：移動と複製後も ID は一意で validation error がない
        #expect(copyResult.updated == true)
        #expect(copyResult.insertedNodes?.map(\.id) == ["copy-hero", "copy-title"])
        #expect(graph.nodes.map(\.id) == ["page", "footer", "copy-hero", "copy-title", "hero", "title"])
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: ノード移動整形保持テスト
    /// 概要: sibling node を移動して元に戻しても、行頭空白だけの差分が残らないことを確認します。
    @Test("node subtreeを移動して元に戻してもHTML整形を保持する")
    func testMoveNodeRoundTripPreservesWhitespace() throws {
        // コンディション：改行と indentation を持つ sibling node の HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let originalHTML = AgentInterfaceFixture.htmlWithInternalIDs(
            """
            <!doctype html>
            <html><body>
              <Stack data-og-id="stack" data-og-type="frame" data-og-layout="vertical">
                <First data-og-id="first" data-og-type="frame">First</First>
                <Second data-og-id="second" data-og-type="frame">Second</Second>
              </Stack>
            </body></html>
            """
        )
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：second を first の前へ移動し、その後 first の後ろへ戻す（When）
        _ = try fixture.core.moveNode(nodeID: "second", targetNodeID: "first", position: .before, htmlURL: fixture.htmlURL)
        _ = try fixture.core.moveNode(nodeID: "second", targetNodeID: "first", position: .after, htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：意味的な順序だけでなく、不要な空行や trailing whitespace も残らず元の HTML と一致する（Then）
        #expect(html == originalHTML)
    }

    /// 論理名（日本語）: ページ作成テスト
    /// 概要: body HTML から standalone OpenGraphite page を作成して検証できることを確認します。
    @Test("body HTMLからOpenGraphiteページを作成できる")
    func testCreatePageWritesStandaloneHTML() throws {
        // コンディション：作成先 HTML と body HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let bodyHTML = """
            <OpenGraphitePage data-og-id="page" data-og-type="page" data-og-layout="vertical">
              <Title data-og-id="title" data-og-type="text">Created</Title>
            </OpenGraphitePage>
        """

        // 検証内容：standalone HTML を作成する
        let result = try fixture.core.createPage(
            at: fixture.htmlURL,
            title: "Created Page",
            lang: "ja",
            stylesheetPath: "../CSS/OpenGraphite.css",
            bodyHTML: bodyHTML,
            overwrite: false
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：HTML file が保存され、page graph も取得できる
        #expect(result.created == true)
        #expect(html.contains("<title>Created Page</title>"))
        #expect(html.contains("data-og-internal-id="))
        #expect(result.graph?.nodes.map(\.id) == ["page", "title"])
        #expect(result.graph?.nodes.allSatisfy { !$0.internalID.isEmpty } == true)
        #expect(result.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: プロジェクトページ追加テスト
    /// 概要: `.ogp` の既定 Chapter pages に新しい page entry を追加できることを確認します。
    @Test("project page addでページ定義を追加できる")
    func testAddProjectPageUpdatesManifest() throws {
        // コンディション：単一 page を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>",
            to: fixture.rootURL.appendingPathComponent("downloads.html")
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：downloads page を追加する
        let summary = try fixture.core.addProjectPage(
            projectURL: projectURL,
            id: "downloads",
            path: "downloads.html",
            canvas: OpenGraphiteCanvas(x: 1480, y: 0, width: 1440, height: 1200)
        )

        // 期待値：manifest と summary に追加 page が反映される
        #expect(summary.chapters.map(\.id) == ["main"])
        #expect(summary.chapters[0].pages.map(\.id) == ["home", "downloads"])
        #expect(summary.pages.map(\.id) == ["home", "downloads"])
        #expect(summary.pages[1].path == "downloads.html")
        #expect(summary.pages[1].canvas.x == 1480)
    }

    /// 論理名（日本語）: プロジェクトページ同一path追加テスト
    /// 概要: 明示許可した場合だけ、同じ HTML path を別 preview canvas として追加できることを確認します。
    @Test("project page addは明示許可時だけ同一pathを追加できる")
    func testAddProjectPageAllowsDuplicatePathWhenExplicit() throws {
        // コンディション：単一 page を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)

        // 検証内容：同じ path を別 ID で preview canvas として追加する
        let summary = try fixture.core.addProjectPage(
            projectURL: projectURL,
            id: "home-eng",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 1280, width: 1440, height: 1200),
            allowDuplicatePath: true
        )

        // 期待値：同じ HTML path を参照する page entry が追加される
        #expect(summary.pages.map(\.id) == ["home", "home-eng"])
        #expect(summary.pages.map(\.path) == ["index.html", "index.html"])
        #expect(summary.pages[1].canvas.y == 1280)
    }

    /// 論理名（日本語）: プロジェクトページ配置テスト
    /// 概要: `.ogp` 内の既存 page entry の canvas 配置を部分更新できることを確認します。
    @Test("project page placeで既存ページの配置を更新できる")
    func testPlaceProjectPageUpdatesCanvas() throws {
        // コンディション：単一 page を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)

        // 検証内容：既存 home page の x/y だけを外部 page ID 指定で更新する
        let summary = try fixture.core.placeProjectPage(
            projectURL: projectURL,
            id: "home",
            name: " Desktop ",
            x: 1520,
            y: 80,
            width: nil,
            height: nil
        )

        // 期待値：未指定の width/height は維持され、指定座標だけが更新される
        #expect(summary.pages[0].canvas.name == "Desktop")
        #expect(summary.pages[0].canvas.x == 1520)
        #expect(summary.pages[0].canvas.y == 80)
        #expect(summary.pages[0].canvas.width == 1440)
        #expect(summary.pages[0].canvas.height == 1200)
    }

    /// 論理名（日本語）: 複合ページ参照解決テスト
    /// 概要: Chapter と page の内部 ID を含む参照 ID で、重複 page ID の片方を一意に解決できることを確認します。
    @Test("複合page参照IDでChapter跨ぎ重複pageを解決できる")
    func testCompoundPageReferenceResolvesDuplicatePageIDs() throws {
        // コンディション：Chapter 跨ぎで同じ page ID を持つ project manifest と HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("DuplicatePages.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="home-page" data-og-type="page"></Page></body></html>
            """
        )
        try fixture.writeHTML(
            """
        <!doctype html>
        <html><body><Page data-og-id="docs-page" data-og-internal-id="node-opaque" data-og-type="page"></Page></body></html>
        """,
            to: fixture.rootURL.appendingPathComponent("docs.html")
        )
        let project = OpenGraphiteProject(
            version: "0.1.0",
            name: "Duplicate Pages",
            repositoryRoot: ".",
            htmlRoot: ".",
            cssLibrary: "OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 1520, y: 0, width: 1440, height: 1200)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: projectURL)
        let summary = try fixture.core.inspectProject(at: projectURL)
        let docsReferenceID = try #require(summary.pages.last?.referenceID)
        let docsNodeReferenceID = "ogref:node:\(summary.chapters[1].internalID):\(summary.pages[1].internalID):node-opaque"

        // 検証内容：複合 page 参照 ID と node ID 付き参照 ID で graph / node を取得する
        let graph = try fixture.core.pageGraph(projectURL: projectURL, pageID: docsReferenceID)
        let nodeResult = try fixture.core.node(
            id: docsNodeReferenceID,
            projectURL: projectURL,
            pageID: docsNodeReferenceID
        )

        // 期待値：従来の page ID が重複していても docs 側 HTML が解決される
        #expect(summary.pages.map(\.id) == ["home", "home"])
        #expect(docsReferenceID == "ogref:page:\(summary.chapters[1].internalID):\(summary.pages[1].internalID)")
        #expect(docsReferenceID.hasPrefix("ogref:page:"))
        #expect(graph.nodes.map(\.id) == ["docs-page"])
        #expect(graph.nodes.map(\.internalID) == ["node-opaque"])
        #expect(nodeResult.node?.id == "docs-page")
        #expect(nodeResult.node?.internalID == "node-opaque")
    }

    /// 論理名（日本語）: typed node参照ページ不一致拒否テスト
    /// 概要: node 操作に渡した `ogref` が異なる page を指す場合に拒否されることを確認します。
    @Test("project node editは異なるpageを指すogrefを拒否する")
    func testProjectNodeEditRejectsConflictingTypedReferences() throws {
        // コンディション：Chapter 跨ぎで source と target を持つ project manifest と HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("ConflictingReferences.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="home-page" data-og-type="page"><Card data-og-id="source" data-og-type="frame"></Card></Page></body></html>
            """
        )
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="docs-page" data-og-type="page"><Card data-og-id="target" data-og-type="frame"></Card></Page></body></html>
            """,
            to: fixture.rootURL.appendingPathComponent("docs.html")
        )
        let project = OpenGraphiteProject(
            version: "0.1.0",
            name: "Conflicting References",
            repositoryRoot: ".",
            htmlRoot: ".",
            cssLibrary: "OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "docs",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 1520, y: 0, width: 1440, height: 1200)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: projectURL)
        let summary = try fixture.core.inspectProject(at: projectURL)
        let homeChapter = try #require(summary.chapters.first)
        let docsChapter = try #require(summary.chapters.dropFirst().first)
        let homePage = try #require(homeChapter.pages.first)
        let docsPage = try #require(docsChapter.pages.first)
        let sourceReferenceID = "ogref:node:\(homeChapter.internalID):\(homePage.internalID):source"
        let targetReferenceID = "ogref:node:\(docsChapter.internalID):\(docsPage.internalID):target"

        // 検証内容：異なる page を指す typed node 参照同士で move を実行する
        do {
            _ = try fixture.core.moveNode(
                nodeID: sourceReferenceID,
                targetNodeID: targetReferenceID,
                position: .after,
                projectURL: projectURL,
                pageID: homePage.referenceID
            )
            Issue.record("異なる page を指す ogref が拒否されませんでした。")
        } catch {
            // 期待値：片方の page へ暗黙に寄せず、参照不整合として失敗する
            #expect(error.localizedDescription.contains("異なる page"))
        }
    }

    /// 論理名（日本語）: プロジェクトコンポーネント作成テスト
    /// 概要: `.ogp` 経由で新規 component HTML を作成し、Components セグメントへ登録できることを確認します。
    @Test("project component createでHTML作成とcomponent登録を一体で実行できる")
    func testCreateProjectComponentWritesHTMLAndManifest() throws {
        // コンディション：home page を持つ project manifest と新規 component body を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let bodyHTML = """
            <ComponentLibrary data-og-id="component-page" data-og-type="page" data-og-layout="vertical">
              <FeatureCard data-og-id="feature-card-master" data-og-type="frame" data-og-component="feature-card" data-og-component-kind="master">
                <FeatureTitle data-og-id="title" data-og-type="text" data-og-slot="title">Feature</FeatureTitle>
              </FeatureCard>
            </ComponentLibrary>
        """

        // 検証内容：component HTML を作成して Components セグメントに登録する
        let result = try fixture.core.createProjectComponent(
            projectURL: projectURL,
            collectionID: nil,
            id: "cards",
            path: "_components/cards.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 960, height: 900),
            title: "Cards",
            lang: "ja",
            stylesheetPath: nil,
            bodyHTML: bodyHTML,
            overwrite: false
        )
        let componentURL = fixture.rootURL.appendingPathComponent("_components/cards.html")
        let componentHTML = try String(contentsOf: componentURL, encoding: .utf8)
        let summary = try fixture.core.inspectProject(at: projectURL)

        // 期待値：HTML file と `.ogp` の component entry が両方作成される
        #expect(result.created == true)
        #expect(FileManager.default.fileExists(atPath: componentURL.path))
        #expect(componentHTML.contains("<title>Cards</title>"))
        #expect(summary.pages.map(\.id) == ["home"])
        #expect(summary.components.map(\.id) == ["cards"])
        #expect(result.page?.segment == "components")
    }

    /// 論理名（日本語）: プロジェクトコンポーネント配置テスト
    /// 概要: `.ogp` 内の既存 component entry の canvas 配置を部分更新できることを確認します。
    @Test("project component placeで既存componentの配置を更新できる")
    func testPlaceProjectComponentUpdatesCanvas() throws {
        // コンディション：Components セグメントを持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：既存 cards component の width/height だけを更新する
        var summary = try fixture.core.placeProjectComponent(
            projectURL: projectURL,
            id: fixture.componentPageInternalID,
            name: " Components ",
            x: nil,
            y: nil,
            width: 1040,
            height: 960
        )

        // 期待値：未指定の x/y は維持され、指定サイズと配置名だけが更新される
        #expect(summary.components[0].canvas.name == "Components")
        #expect(summary.components[0].canvas.x == 0)
        #expect(summary.components[0].canvas.y == 0)
        #expect(summary.components[0].canvas.width == 1040)
        #expect(summary.components[0].canvas.height == 960)

        // 検証内容：配置名を空白で指定して名前なしへ戻す（When）
        summary = try fixture.core.placeProjectComponent(
            projectURL: projectURL,
            id: fixture.componentPageInternalID,
            name: "   ",
            x: nil,
            y: nil,
            width: nil,
            height: nil
        )

        // 期待値：空白だけの配置名は空文字として保存される（Then）
        #expect(summary.components[0].canvas.name == "")
    }

    /// 論理名（日本語）: プロジェクトコンポーネント削除テスト
    /// 概要: `.ogp` 内の component entry を削除し、指定時は HTML file も削除できることを確認します。
    @Test("project component removeでcomponent登録とHTMLを削除できる")
    func testRemoveProjectComponentDeletesManifestEntryAndHTML() throws {
        // コンディション：Components セグメントを持つ project manifest と component HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：既存 cards component を manifest と file system から削除する
        let summary = try fixture.core.removeProjectComponent(
            projectURL: projectURL,
            id: fixture.componentPageInternalID,
            deleteFile: true
        )

        // 期待値：Components セグメントから cards が消え、HTML file も削除される
        #expect(summary.components.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: componentURL.path))
    }

    /// 論理名（日本語）: プロジェクト経由ノード編集テスト
    /// 概要: `.ogp` の page ID から解決した HTML だけを node 編集対象にできることを確認します。
    @Test(".ogpのpage ID経由でnodeを編集できる")
    func testProjectScopedNodeEditUpdatesRegisteredPage() throws {
        // コンディション：単一 page を持つ project manifest と編集対象 HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-type="page"><Title data-og-id="title" data-og-type="text">Old</Title></Page></body></html>
            """
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：project URL と page ID を通して title を更新する
        let result = try fixture.core.setTextContent(
            "New",
            nodeID: "title",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：`.ogp` に登録済みの home page だけが更新される
        #expect(result.updated == true)
        #expect(result.path == fixture.htmlURL.path)
        #expect(html.contains(">New<"))
    }

    /// 論理名（日本語）: プロジェクトページ作成テスト
    /// 概要: `.ogp` 経由で新規 HTML を作成し、同時に既定 Chapter pages へ登録できることを確認します。
    @Test("project page createでHTML作成とpage登録を一体で実行できる")
    func testCreateProjectPageWritesHTMLAndManifest() throws {
        // コンディション：home page を持つ project manifest と新規 page body を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let bodyHTML = """
            <OpenGraphitePage data-og-id="docs-page" data-og-type="page" data-og-layout="vertical">
              <Title data-og-id="docs-title" data-og-type="text">Docs</Title>
            </OpenGraphitePage>
        """

        // 検証内容：docs.html を作成して docs page として登録する
        let result = try fixture.core.createProjectPage(
            projectURL: projectURL,
            id: "docs",
            path: "docs.html",
            canvas: OpenGraphiteCanvas(x: 1480, y: 0, width: 1440, height: 1200),
            title: "Docs",
            lang: "ja",
            stylesheetPath: nil,
            bodyHTML: bodyHTML,
            overwrite: false
        )
        let docsURL = fixture.rootURL.appendingPathComponent("docs.html")
        let docsHTML = try String(contentsOf: docsURL, encoding: .utf8)
        let summary = try fixture.core.inspectProject(at: projectURL)

        // 期待値：HTML file と `.ogp` の page entry が両方作成される
        #expect(result.created == true)
        #expect(FileManager.default.fileExists(atPath: docsURL.path))
        #expect(docsHTML.contains("<title>Docs</title>"))
        #expect(summary.pages.map(\.id) == ["home", "docs"])
        #expect(result.page?.path == "docs.html")
    }

    /// 論理名（日本語）: プロジェクトページパス制約テスト
    /// 概要: `.ogp` の `htmlRoot` 外へ出る page path を拒否することを確認します。
    @Test("project page addはhtmlRoot外のpathを拒否する")
    func testAddProjectPageRejectsPathOutsideHTMLRoot() throws {
        // コンディション：単一 page を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)

        // 検証内容：`..` を含む page path を追加しようとする
        do {
            _ = try fixture.core.addProjectPage(
                projectURL: projectURL,
                id: "secret",
                path: "../secret.html",
                canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
            )
            Issue.record("htmlRoot 外の page path が拒否されませんでした。")
        } catch {
            // 期待値：path validation により処理が失敗する
            #expect(error.localizedDescription.contains("htmlRoot"))
        }
    }

    /// 論理名（日本語）: CLIプロジェクトスコープ編集テスト
    /// 概要: `ogkiln` が `.ogp` と page ID を経由して編集し、HTML path 直接指定を拒否することを確認します。
    @Test("CLIは.ogp経由で編集しHTML直接編集を拒否する")
    func testCLIEditsThroughProjectAndRejectsDirectHTML() throws {
        // コンディション：単一 page を持つ project manifest と CLI 出力受け取り先を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Hero data-og-id="hero" data-og-type="frame" style="--og-gap:24px;"></Hero></body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：`.ogp` 経由の編集を実行し、続けて HTML path 直接指定の編集を試す
        let successCode = cli.run(
            arguments: [
                "node", "style", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "hero",
                "--var", "--og-gap",
                "--value", "32px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let rejectedCode = cli.run(
            arguments: [
                "node", "style", "set", "index.html",
                "--page-id", fixture.homePageInternalID,
                "--id", "hero",
                "--var", "--og-gap",
                "--value", "40px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：`.ogp` 経由の編集だけが成功し、直接 HTML 指定はエラーになる
        #expect(successCode == 0)
        #expect(rejectedCode == 2)
        #expect(html.contains("--og-gap:32px;"))
        #expect(stderr.contains(".ogp"))
    }

    /// 論理名（日本語）: CLIアイコン編集テスト
    /// 概要: `ogkiln node icon set` から icon node の metadata と保存 HTML を更新できることを確認します。
    @Test("CLIでLucideアイコンnodeを更新できる")
    func testCLISetIconUpdatesPageSideMarkup() throws {
        // コンディション：単一 page project と circle icon node を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="decorative-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
              </Icon>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で library source の star へ更新する（When）
        let code = cli.run(
            arguments: [
                "node", "icon", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "decorative-icon",
                "--name", "star",
                "--source", "library"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：CLI が成功し、runtime library 用の data-lucide が保存される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(html.contains("data-og-icon-name=\"star\""))
        #expect(html.contains("<i data-lucide=\"star\" aria-hidden=\"true\"></i>"))
        #expect(!html.contains("<circle cx=\"12\" cy=\"12\" r=\"10\"></circle>"))
    }

    /// 論理名（日本語）: CLIアイコンCDN URL保持テスト
    /// 概要: `ogkiln node icon set` が対象外 CDN icon の mask URL を削除しないことを確認します。
    @Test("CLIは対象外CDNアイコンのmask URLを保持する")
    func testCLISetIconPreservesSiblingCDNMaskURL() throws {
        // コンディション：CDN source の icon node を2つ持つ page project を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="target-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn">
                <span data-og-icon-mask="true" style="--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/circle.svg');" aria-hidden="true"></span>
              </Icon>
              <Icon data-og-id="sibling-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="panel-left-open" data-og-icon-source="cdn">
                <span data-og-icon-mask="true" style="--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');" aria-hidden="true"></span>
              </Icon>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：片方の icon node だけを CDN source の star へ更新する（When）
        let code = cli.run(
            arguments: [
                "node", "icon", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "target-icon",
                "--name", "star",
                "--source", "cdn"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：対象 icon は更新され、対象外 icon の CDN mask URL は保持される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(html.contains("--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(html.contains("--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');"))
    }

    /// 論理名（日本語）: CLI typed node参照解決テスト
    /// 概要: `ogkiln` が `ogref:node` から対象 page と node 内部 ID を復元できることを確認します。
    @Test("CLIはogref node参照だけで対象pageを解決する")
    func testCLIResolvesTypedNodeReferenceWithoutPageID() throws {
        // コンディション：単一 page を持つ project manifest と typed node 参照 ID を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Hero data-og-id="hero" data-og-type="frame" style="--og-gap:24px;"></Hero></body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let nodeReferenceID = "ogref:node:\(fixture.chapterInternalID):\(fixture.homePageInternalID):hero"
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：`--page-id` を渡さず、`--id` の typed node 参照だけで編集する
        let code = cli.run(
            arguments: [
                "node", "style", "set", "Sample.ogp",
                "--id", nodeReferenceID,
                "--var", "--og-gap",
                "--value", "40px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：typed node 参照から page と node が解決され、対象 HTML が更新される
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(html.contains("--og-gap:40px;"))
    }

    /// 論理名（日本語）: CLIページ配置名更新テスト
    /// 概要: `ogkiln project page place` が canvas 配置名を更新できることを確認します。
    @Test("CLIはproject page placeでcanvas配置名を更新できる")
    func testCLIPlaceProjectPageUpdatesCanvasName() throws {
        // コンディション：単一 page を持つ project manifest と CLI 出力受け取り先を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で home page の canvas 配置名を更新する（When）
        let code = cli.run(
            arguments: [
                "project", "page", "place", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--name", " Desktop "
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)

        // 期待値：CLI は成功し、配置名は trim されて JSON と manifest の両方へ反映される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"name\" : \"Desktop\""))
        #expect(loadedProject.project.allPages[0].canvas.name == "Desktop")
    }

    /// 論理名（日本語）: CLIページMock State更新テスト
    /// 概要: `ogkiln project page place` が page canvas の preview Mock State を更新できることを確認します。
    @Test("CLIはproject page placeでMock Stateを更新できる")
    func testCLIPlaceProjectPageUpdatesPreviewContext() throws {
        // コンディション：単一 page を持つ project manifest と CLI 出力受け取り先を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で home page の preview Mock State を更新する（When）
        let code = cli.run(
            arguments: [
                "project", "page", "place", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--preview-mock", "selectedLanguage=ja",
                "--preview-mock", "emptyState="
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let previewContext = loadedProject.project.allPages[0].canvas.previewContext

        // 期待値：CLI は成功し、Mock State が JSON と manifest の両方へ反映される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"selectedLanguage\" : \"ja\""))
        #expect(previewContext.locale.isEmpty)
        #expect(previewContext.direction.isEmpty)
        #expect(previewContext.fieldMocks["selectedLanguage"] == "ja")
        #expect(previewContext.fieldMocks["emptyState"] == "")
    }

    /// 論理名（日本語）: CLIコンポーネントPlacement Mock更新テスト
    /// 概要: `ogkiln project component place` が component canvas の placement mock state を `.ogp` へ保存できることを確認します。
    @Test("CLIはcomponent canvasのplacement mock stateを更新できる")
    func testCLIProjectComponentPlaceUpdatesPlacementMocks() throws {
        // コンディション：component を持つ project manifest を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：component canvas の placement mock を CLI で更新する（When）
        let code = cli.run(
            arguments: [
                "project", "component", "place", "Sample.ogp",
                "--component-id", fixture.componentPageInternalID,
                "--preview-placement-mock", "67a2e12dbed8:codeViewerMode=preview",
                "--preview-placement-mock", "67a2e12dbed8:emptyState="
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let previewContext = loadedProject.project.collections[0].components[0].canvas.previewContext

        // 期待値：placementMocks は component canvas の previewContext に保存される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"placementMocks\""))
        #expect(previewContext.placementMocks["67a2e12dbed8"]?["codeViewerMode"] == "preview")
        #expect(previewContext.placementMocks["67a2e12dbed8"]?["emptyState"] == "")
    }

    /// 論理名（日本語）: CLIページHTML Document Context更新テスト
    /// 概要: `ogkiln project page document` が HTML 正本の document attribute と binding metadata を更新できることを確認します。
    @Test("CLIはproject page documentでHTML document contextを更新できる")
    func testCLIProjectPageDocumentUpdatesHTMLDocumentContext() throws {
        // コンディション：単一 page を持つ project manifest と HTML 正本を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html lang=\"en\" dir=\"ltr\"><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で home page の HTML document context を更新する（When）
        let code = cli.run(
            arguments: [
                "project", "page", "document", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--lang-source", "binding",
                "--lang", "ja",
                "--lang-field", "selectedLanguage",
                "--dir-source", "auto",
                "--dir", "ltr"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let context = OpenGraphiteHTMLDocument(html: html).htmlDocumentContext()

        // 期待値：CLI は成功し、変数名は HTML 属性ではなく metadata として保存される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"langField\" : \"selectedLanguage\""))
        #expect(context.langSource == .binding)
        #expect(context.langValue == "ja")
        #expect(context.langField == "selectedLanguage")
        #expect(context.dirSource == .auto)
        #expect(context.dirValue == "ltr")
        #expect(!html.contains("lang=\"selectedLanguage\""))
        #expect(html.contains("data-og-lang-source=\"binding\""))
        #expect(html.contains("data-og-lang-field=\"selectedLanguage\""))
        #expect(html.contains("data-og-dir-source=\"auto\""))
    }

    /// 論理名（日本語）: CLIテキストvariant更新テスト
    /// 概要: `ogkiln text variant set` が `data-i18n-key` 指定で text binding variant を更新できることを確認します。
    @Test("CLIはdata-i18n-keyでtext variantを更新できる")
    func testCLITextVariantSetUpdatesI18nKeyTarget() throws {
        // コンディション：単一 page を持つ project manifest と slot text binding を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <span slot="title" data-og-text-source="binding" data-i18n-key="home.slot.title">スロット</span>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で英語 variant を保存する（When）
        let code = cli.run(
            arguments: [
                "text", "variant", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--key", "home.slot.title",
                "--locale", "eng",
                "--value", "Slot English"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：CLI は成功し、node id がない text binding へ variant 属性が保存される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(html.contains("data-og-text-variant-eng=\"Slot English\""))
    }

    /// 論理名（日本語）: CLI i18n推奨設定テスト
    /// 概要: `ogkiln i18n inspect / recommend / resource set` が実装資源の JS と locale JSON を扱えることを確認します。
    @Test("CLIはi18n runtimeを検査し推奨locale JSONへ書き戻せる")
    func testCLII18nInspectRecommendAndResourceSet() throws {
        // コンディション：i18n key と HTML 同梱英語 fallback を持つ page を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><title>Fixture</title></head><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title" data-og-text-variant-eng="English title">日本語タイトル</Title>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：検査、推奨設定適用、resource set を順番に実行する（When）
        let inspectCode = cli.run(
            arguments: ["i18n", "inspect", "Sample.ogp", "--page-id", fixture.homePageInternalID, "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        #expect(inspectCode == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"adapter\" : \"unknown\""))

        stdout = ""
        stderr = ""
        let recommendCode = cli.run(
            arguments: ["i18n", "recommend", "Sample.ogp", "--page-id", fixture.homePageInternalID, "--locales", "ja,eng"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let jaURL = fixture.rootURL.appendingPathComponent("locales/ja.json")
        let engURL = fixture.rootURL.appendingPathComponent("locales/eng.json")
        let jaResource = try Self.localeJSON(at: jaURL)
        let engResource = try Self.localeJSON(at: engURL)

        stdout = ""
        stderr = ""
        let resourceCode = cli.run(
            arguments: [
                "i18n", "resource", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--locale", "eng",
                "--key", "home.title",
                "--value", "Edited English"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let updatedEngResource = try Self.localeJSON(at: engURL)

        // 期待値：設定と JSON は .ogp ではなく実装資源へ保存される（Then）
        #expect(recommendCode == 0)
        #expect(resourceCode == 0)
        #expect(stderr.isEmpty)
        #expect(html.contains("src=\"./i18n.js\" defer"))
        #expect(FileManager.default.fileExists(atPath: fixture.rootURL.appendingPathComponent("i18n.js").path))
        #expect(jaResource["home.title"] as? String == "日本語タイトル")
        #expect(engResource["home.title"] as? String == "English title")
        #expect(updatedEngResource["home.title"] as? String == "Edited English")
        #expect(stdout.contains("\"updated\" : true"))
    }

    /// 論理名（日本語）: CLIコンポーネント編集テスト
    /// 概要: `ogkiln` が `--component-id` 経由で Components セグメントの HTML を編集できることを確認します。
    @Test("CLIはcomponent ID経由でComponents HTMLを編集できる")
    func testCLIEditsComponentByComponentID() throws {
        // コンディション：通常 page と component canvas を持つ project manifest と CLI 出力受け取り先を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"><Title data-og-id=\"title\" data-og-type=\"text\">Old</Title></Cards></body></html>",
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：`--component-id` 経由で component master 側の text を更新する
        let code = cli.run(
            arguments: [
                "node", "text", "set", "Sample.ogp",
                "--component-id", fixture.componentPageInternalID,
                "--id", "title",
                "--value", "New"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let componentHTML = try String(contentsOf: componentURL, encoding: .utf8)

        // 期待値：Components HTML だけが更新され、CLI は成功する
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(componentHTML.contains(">New<"))
    }

    /// 論理名（日本語）: CLI対象ID相互排他テスト
    /// 概要: `--page-id` と `--component-id` を同時指定した node 操作を拒否することを確認します。
    @Test("CLIはpage IDとcomponent IDの同時指定を拒否する")
    func testCLIRejectsBothPageIDAndComponentID() throws {
        // コンディション：通常 page と component canvas を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：node query に `--page-id` と `--component-id` を同時に渡す
        let code = cli.run(
            arguments: [
                "node", "query", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--component-id", fixture.componentPageInternalID,
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )

        // 期待値：曖昧な対象指定は拒否される
        #expect(code == 2)
        #expect(stdout.isEmpty)
        #expect(stderr.contains("--page-id と --component-id は同時に指定できません"))
    }

    /// 論理名（日本語）: 現在プロジェクトストアテスト
    /// 概要: OpenGraphite.app が開いた `.ogp` を CLI が読めるレコードとして保存できることを確認します。
    @Test("現在開いているprojectをApplication Support形式のレコードへ保存できる")
    func testCurrentProjectStoreRoundTripsProjectURL() throws {
        // コンディション：project manifest と一時 current-project レコード URL を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let recordURL = fixture.rootURL.appendingPathComponent("current-project.json")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        let store = OpenGraphiteCurrentProjectStore(recordURL: recordURL)

        // 検証内容：project URL を保存して読み戻す
        try store.write(projectURL: projectURL)
        let resolvedURL = try store.readProjectURL()

        // 期待値：保存済み `.ogp` の絶対 URL が復元される
        #expect(resolvedURL == projectURL.standardizedFileURL)
    }

    /// 論理名（日本語）: 契約ファイル読み込みテスト
    /// 概要: リポジトリの `OpenGraphite.contract.json` を探索して読み込めることを確認します。
    @Test("OpenGraphite.contract.jsonを読み込める")
    func testLoadRepositoryContract() throws {
        // コンディション：テストファイル位置からリポジトリルート方向へ契約ファイルを探索する
        let testURL = URL(fileURLWithPath: #filePath)

        // 検証内容：契約ファイルを読み込む
        guard let contractURL = OpenGraphiteContract.findContractURL(startingAt: testURL) else {
            Issue.record("OpenGraphite.contract.json が見つかりません。")
            return
        }
        let contract = try OpenGraphiteContract.load(from: contractURL)

        // 期待値：主要な type、layout、CSS 変数が契約に含まれる
        #expect(contract.types.contains("frame"))
        #expect(contract.layouts.contains("horizontal"))
        #expect(contract.cssVariables.contains { $0.name == "--og-gap" && $0.editable })
    }

    /// 論理名（日本語）: Componentsセグメント要約テスト
    /// 概要: `.ogp` の Collection 内 components が project summary と page graph 対象として扱われることを確認します。
    @Test("project inspectがComponentsセグメントを返す")
    func testInspectProjectIncludesComponentsSegment() throws {
        // コンディション：通常 page と component canvas を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：project summary と component page graph を取得する
        let summary = try fixture.core.inspectProject(at: projectURL)
        let graph = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.componentPageInternalID)

        // 期待値：components が通常 pages とは別配列として返り、page ID 経由で graph 化できる
        #expect(summary.pages.map(\.id) == ["home"])
        #expect(summary.components.map(\.id) == ["cards"])
        #expect(summary.components[0].segment == "components")
        #expect(graph.nodes.map(\.id) == ["cards"])
    }

    /// 論理名（日本語）: Componentsセグメント検証テスト
    /// 概要: project validation が Components セグメントの HTML も検証対象に含めることを確認します。
    @Test("project validateはComponents HTMLも検証する")
    func testValidateProjectIncludesComponentsSegment() throws {
        // コンディション：不正な data-og-type を持つ component HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"unknown\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：project 全体を validate する
        let result = try fixture.core.validateProject(at: projectURL)

        // 期待値：components 側の validation error により project validation が失敗する
        #expect(result.valid == false)
        #expect(result.diagnostics.contains { $0.nodeID == "cards" })
    }

    /// 論理名（日本語）: Placement配置文脈検証テスト
    /// 概要: component placement は Components / Collection canvas にだけ配置できることを確認します。
    @Test("project validateはPages上のcomponent placementを禁止する")
    func testValidateProjectRejectsComponentPlacementInPages() throws {
        // コンディション：Pages 側に placement、Components 側に同じ placement role を持つ HTML を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Page data-og-id="page" data-og-type="page">
                <og-placement data-og-id="page-placement" data-og-type="frame" data-og-role="component-placement" data-og-source-component-internal-id="c9a63f" data-og-source-node-internal-id="cards-internal"></og-placement>
              </Page>
            </body></html>
            """
        )
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Cards data-og-id="cards" data-og-internal-id="cards-internal" data-og-type="frame"></Cards>
              <og-placement data-og-id="component-placement" data-og-type="frame" data-og-role="component-placement" data-og-source-component-internal-id="c9a63f" data-og-source-node-internal-id="cards-internal"></og-placement>
            </body></html>
            """,
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：project 全体を validate する（When）
        let result = try fixture.core.validateProject(at: projectURL)

        // 期待値：Pages 側の placement だけが文脈エラーになる（Then）
        #expect(result.valid == false)
        #expect(result.diagnostics.contains {
            $0.code == "component-placement-outside-collection" && $0.nodeID == "page-placement"
        })
        #expect(!result.diagnostics.contains {
            $0.code == "component-placement-outside-collection" && $0.nodeID == "component-placement"
        })
    }

    /// 論理名（日本語）: component buildテスト
    /// 概要: `ogkiln build` と同じ builder が `<og-instance>` を静的 HTML へ展開できることを確認します。
    @Test("component参照を静的HTMLへbuildできる")
    func testComponentBuilderExpandsInstances() throws {
        // コンディション：component link、runtime script、og-instance を持つ page と master HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentDirectory = fixture.rootURL.appendingPathComponent("_components")
        let assetDirectory = fixture.rootURL.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        try "body{margin:0}".write(to: fixture.rootURL.appendingPathComponent("OpenGraphite.css"), atomically: true, encoding: .utf8)
        try "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
            .write(to: assetDirectory.appendingPathComponent("preview.svg"), atomically: true, encoding: .utf8)
        try """
        <!doctype html>
        <html><body>
          <FeatureCard data-og-id="feature-card-master" data-og-type="frame" data-og-component="feature-card" data-og-component-kind="master">
            <FeatureTitle data-og-id="title" data-og-type="text" data-og-slot="title">Fallback</FeatureTitle>
          </FeatureCard>
        </body></html>
        """.write(to: componentDirectory.appendingPathComponent("cards.html"), atomically: true, encoding: .utf8)
        try """
        <!doctype html>
        <html><head>
          <link rel="stylesheet" href="./OpenGraphite.css">
          <link rel="opengraphite-components" href="./_components/cards.html">
          <script src="./OpenGraphite.runtime.js" defer></script>
        </head><body>
          <Page data-og-id="page" data-og-type="page">
            <Preview data-og-id="preview" data-og-type="image"><img src="./assets/preview.svg" alt=""></Preview>
            <og-instance data-og-id="home-card" data-og-component="feature-card">
              <span slot="title">Built Title</span>
            </og-instance>
          </Page>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：builder で dist 相当のディレクトリへ出力する
        let outputURL = fixture.rootURL.appendingPathComponent("dist")
        let result = try OpenGraphiteComponentBuilder().buildProject(projectURL: projectURL, outputURL: outputURL)
        let builtHTML = try String(contentsOf: outputURL.appendingPathComponent("index.html"), encoding: .utf8)

        // 期待値：og-instance と runtime 参照は残らず、component master が instance ID で展開される
        #expect(result.built == true)
        #expect(result.pages.map(\.id) == ["home"])
        #expect(builtHTML.contains("<FeatureCard"))
        #expect(builtHTML.contains("data-og-id=\"home-card\""))
        #expect(builtHTML.contains("Built Title"))
        #expect(!builtHTML.contains("<og-instance"))
        #expect(!builtHTML.contains("OpenGraphite.runtime.js"))
        #expect(result.assets.map(\.outputPath).contains(outputURL.appendingPathComponent("OpenGraphite.css").path))
        #expect(result.assets.map(\.outputPath).contains(outputURL.appendingPathComponent("assets/preview.svg").path))
        #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("OpenGraphite.css").path))
        #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("assets/preview.svg").path))
    }

    /// 論理名（日本語）: locale JSON読込ヘルパー
    /// 概要: テスト用 locale JSON を辞書として読み込みます。
    ///
    /// - Parameter url: JSON ファイル URL。
    /// - Returns: JSON object 辞書。
    private static func localeJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

/// 論理名（日本語）: Agentインターフェーステストfixture
/// 概要: 一時ディレクトリに HTML と project を作り、core / CLI テストを分離します。
private struct AgentInterfaceFixture {
    let chapterInternalID = "a7f21c"
    let homePageInternalID = "b8e42d"
    let componentCollectionInternalID = "component-main"
    let componentPageInternalID = "c9a63f"
    let rootURL: URL
    let htmlURL: URL
    let core: OpenGraphiteAgentCore

    /// 論理名（日本語）: Agent fixture初期化関数
    /// 処理概要: 一時ディレクトリと OpenGraphite agent core を作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteAgentInterface-\(UUID().uuidString)")
        htmlURL = rootURL.appendingPathComponent("index.html")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        core = OpenGraphiteAgentCore(contract: .builtIn)
    }

    /// 論理名（日本語）: HTML書き込み関数
    /// 処理概要: fixture の HTML ファイルへ指定文字列を書き込みます。
    ///
    /// - Parameter html: 書き込む HTML。
    func writeHTML(_ html: String) throws {
        try Self.htmlWithInternalIDs(html).write(to: htmlURL, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: HTML書き込み関数
    /// 処理概要: 指定 URL へ内部 ID を補完した HTML を書き込みます。
    ///
    /// - Parameters:
    ///   - html: 書き込む HTML。
    ///   - url: 書き込み先 URL。
    func writeHTML(_ html: String, to url: URL) throws {
        try Self.htmlWithInternalIDs(html).write(to: url, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: テストHTML内部ID補完関数
    /// 処理概要: fixture HTML の `data-og-id` 要素に `data-og-internal-id` がなければ同じ値を補完します。
    ///
    /// - Parameter html: 入力 HTML。
    /// - Returns: 内部 ID を補完した HTML。
    static func htmlWithInternalIDs(_ html: String) -> String {
        let pattern = #"<[^>]*\bdata-og-id=(["'])(.*?)\1[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        var result = html
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed()
        for match in matches {
            guard let tagRange = Range(match.range, in: result),
                  let idRange = Range(match.range(at: 2), in: result)
            else {
                continue
            }
            let tag = String(result[tagRange])
            guard !tag.contains("data-og-internal-id") else { continue }
            let id = String(result[idRange])
            guard let closeIndex = result[tagRange].lastIndex(of: ">") else { continue }
            result.insert(contentsOf: " data-og-internal-id=\"\(id)\"", at: closeIndex)
        }
        return result
    }

    /// 論理名（日本語）: project manifest書き込み関数
    /// 処理概要: fixture 用の最小 `.ogp` を指定 URL へ書き込みます。
    ///
    /// - Parameter url: 書き込み先 `.ogp` URL。
    func writeProject(to url: URL) throws {
        let project = """
        {
          "version": "0.1.0",
          "name": "Fixture",
          "repositoryRoot": ".",
          "htmlRoot": ".",
          "cssLibrary": "OpenGraphite.css",
          "chapters": [
            {
              "id": "main",
              "internalID": "\(chapterInternalID)",
              "title": "Main",
              "pages": [
                {
                  "id": "home",
                  "internalID": "\(homePageInternalID)",
                  "path": "index.html",
                  "canvas": {
                    "name": "",
                    "x": 0,
                    "y": 0,
                    "width": 1440,
                    "height": 1200
                  }
                }
              ]
            }
          ]
        }
        """
        try project.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: component付きproject manifest書き込み関数
    /// 処理概要: fixture 用に通常 page と component Collection を持つ `.ogp` を作成します。
    ///
    /// - Parameter url: 書き込み先 `.ogp` URL。
    func writeProjectWithComponents(to url: URL) throws {
        let project = """
        {
          "version": "0.1.0",
          "name": "Fixture",
          "repositoryRoot": ".",
          "htmlRoot": ".",
          "cssLibrary": "OpenGraphite.css",
          "chapters": [
            {
              "id": "main",
              "internalID": "\(chapterInternalID)",
              "title": "Main",
              "pages": [
                {
                  "id": "home",
                  "internalID": "\(homePageInternalID)",
                  "path": "index.html",
                  "canvas": {
                    "name": "",
                    "x": 0,
                    "y": 0,
                    "width": 1440,
                    "height": 1200
                  }
                }
              ]
            }
          ],
          "collections": [
            {
              "id": "main",
              "internalID": "\(componentCollectionInternalID)",
              "title": "Main",
              "components": [
                {
                  "id": "cards",
                  "internalID": "\(componentPageInternalID)",
                  "title": "Cards",
                  "path": "cards.html",
                  "canvas": {
                    "name": "",
                    "x": 0,
                    "y": 0,
                    "width": 960,
                    "height": 900
                  }
                }
              ]
            }
          ]
        }
        """
        try project.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: fixture削除関数
    /// 処理概要: テスト用一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
