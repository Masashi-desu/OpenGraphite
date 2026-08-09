import Foundation
import CryptoKit
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: Agentインターフェース関連のテストスイート
/// 概要: `ogkiln` core の graph、validation、node 単位編集、CLI 実行を確認します。
@Suite("Agentインターフェース関連のテストスイート")
struct OpenGraphiteAgentCoreTests {
    /// 論理名（日本語）: ページグラフ抽出テスト
    /// 概要: HTML と companion CSS から `data-og-id` ノードと CSS declaration を抽出できることを検証します。
    @Test("HTMLとcompanion CSSからpage graphを抽出できる")
    func testPageGraphExtractsNodes() throws {
        // コンディション：OpenGraphite 契約に沿った HTML と companion CSS を一時ファイルへ用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Hero data-og-id="hero" data-og-type="frame" data-og-layout="horizontal">
                <Title data-og-id="title" data-og-type="text">OpenGraphite</Title>
              </Hero>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero"] {
              gap: 24px;
            }
            """
        )

        // 検証内容：page graph を生成する
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let hero = try #require(graph.nodes.first { $0.id == "hero" })
        let title = try #require(graph.nodes.first { $0.id == "title" })

        // 期待値：標準要素を含むDOM順とannotation nodeのCSS declarationが取得できる
        #expect(graph.nodes.map(\.tagName).prefix(2) == ["html", "body"])
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["hero", "title"])
        #expect(hero.cssVariables["gap"] == "24px")
        #expect(hero.textContent == "OpenGraphite")
        #expect(title.parentID == "hero")
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: 標準CSS layout・visibility inspectionテスト
    /// 概要: annotationやlegacy描画属性に依存せず、UA既定と標準CSSからlayout、position、hidden、text wrapを解決します。
    @Test("標準CSSからlayout visibility text wrapを非破壊inspectionする")
    func testStandardCSSDerivesLayoutVisibilityAndTextWrapWithoutLegacyAttributes() throws {
        // コンディション：標準layout、mixed flow、hidden、binding metadata、legacy属性が共存する未注釈HTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html>
        <html><body>
          <main id="root">
            <section id="flow" class="flow">
              <div id="normal">Flow</div>
              <div id="absolute" class="absolute">Absolute</div>
            </section>
            <section id="grid" class="grid"><span>Grid item</span></section>
            <section id="hidden-source" hidden>Hidden attribute <span id="hidden-visible-child" class="visible-child">Visible value</span></section>
            <force-box id="hidden-author-display" class="hidden-author-display" hidden>Author display override</force-box>
            <section id="hidden-until-found" hidden="until-found">Findable hidden content</section>
            <section id="css-hidden" class="css-hidden">CSS hidden <span id="css-visible-child" class="visible-child">Visible child</span></section>
            <span id="binding-only" data-og-text-source="binding">Binding metadata only</span>
            <span id="wrapped" class="wrapped">Wrapped</span>
            <section id="legacy" data-og-layout="absolute" data-og-hidden="true">Legacy input</section>
          </main>
        </body></html>
        """
        let originalCSS = """
        .flow { display: flex; flex-direction: column; }
        .absolute { position: absolute; left: 12px; top: 8px; }
        .grid {
          display: grid;
          grid-template-columns: 1fr 2fr;
          grid-auto-flow: column;
        }
        .css-hidden { visibility: hidden; }
        .hidden-author-display { display: block; }
        .visible-child { display: block; visibility: visible; }
        .wrapped { overflow-wrap: anywhere; }
        """
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeCompanionCSS(originalCSS)

        // 検証内容：graphとvalidationを生成し、source bytesを読み戻す（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let afterCSS = try fixture.readCompanionCSS()
        func node(_ id: String) throws -> OpenGraphiteAgentNode {
            try #require(graph.nodes.first { $0.attributes["id"] == id })
        }

        // 期待値：parent enumにabsoluteを持たず、各nodeの標準resolved値とsource hidden intentを分離して返す（Then）
        #expect(try node("root").layout == "block")
        #expect(try node("flow").layout == "vertical")
        #expect(try node("normal").cssResolvedValues["position"] == "static")
        #expect(try node("absolute").cssResolvedValues["position"] == "absolute")
        #expect(try node("grid").layout == "grid")
        #expect(try node("grid").cssResolvedValues["grid-template-columns"] == "1fr 2fr")
        #expect(try node("grid").cssResolvedValues["grid-auto-flow"] == "column")
        #expect(try node("hidden-source").hidden == true)
        #expect(try node("hidden-source").cssResolvedValues["display"] == "none")
        #expect(try node("hidden-author-display").hidden == true)
        #expect(try node("hidden-author-display").cssResolvedValues["display"] == "block")
        #expect(try node("hidden-until-found").hidden == true)
        #expect(try node("hidden-until-found").cssResolvedValues["display"] == "block")
        #expect(try node("hidden-visible-child").hidden == false)
        #expect(try node("hidden-visible-child").cssResolvedValues["display"] == "block")
        #expect(try node("hidden-visible-child").cssResolvedValues["visibility"] == "visible")
        #expect(try node("hidden-source").cssResolvedValues["display"] == "none")
        #expect(try node("css-hidden").hidden == false)
        #expect(try node("css-hidden").cssResolvedValues["visibility"] == "hidden")
        #expect(try node("css-visible-child").hidden == false)
        #expect(try node("css-visible-child").cssResolvedValues["visibility"] == "visible")
        #expect(try node("binding-only").layout == "inline")
        #expect(try node("binding-only").cssResolvedValues["overflow-wrap"] == "normal")
        #expect(try node("wrapped").cssResolvedValues["overflow-wrap"] == "anywhere")
        #expect(try node("legacy").layout == "block")
        #expect(try node("legacy").hidden == false)
        #expect(try node("legacy").attributes["data-og-layout"] == "absolute")
        #expect(try node("legacy").attributes["data-og-hidden"] == "true")
        #expect(!validation.diagnostics.contains { $0.code == "unknown-data-og-layout" })
        #expect(afterHTML == originalHTML)
        #expect(afterCSS == originalCSS)
    }

    /// 論理名（日本語）: Until-found content visibility編集境界テスト
    /// 概要: UA fallbackとauthor CSS-wide値を分離し、確定済みnodeの他CSS編集を誤ってblockしません。
    @Test("until-found content-visibilityのinitialとunsetはcompleteなvisibleとしてinspectionする")
    func testUntilFoundContentVisibilityInitialAndUnsetRemainEditable() throws {
        // コンディション：bareとauthor initial/unset/visibleを持つuntil-found nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <section data-og-id="bare" hidden="until-found">Bare</section>
              <section data-og-id="initial" hidden="until-found" style="content-visibility: initial">Initial</section>
              <section data-og-id="unset" hidden="until-found" style="content-visibility: unset">Unset</section>
              <section data-og-id="visible" hidden="until-found" style="content-visibility: visible">Visible</section>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS("/* keep */\n")

        // 検証内容：graphを取得し、initial nodeへ独立した標準display編集を適用する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let edit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "initial", htmlURL: fixture.htmlURL
        )
        let updated = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：bareだけUA hidden、author CSS-wide値はvisibleでcompleteとなり、他property編集も成功する（Then）
        #expect(graph.nodes.first { $0.id == "bare" }?.cssResolvedValues["content-visibility"] == "hidden")
        for identifier in ["initial", "unset", "visible"] {
            let node = try #require(graph.nodes.first { $0.id == identifier })
            #expect(node.hidden == true)
            #expect(node.cssResolvedValues["content-visibility"] == "visible")
            #expect(node.hasIncompleteCSSProvenance == false)
        }
        #expect(edit.updated == true)
        #expect(!edit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(updated.nodes.first { $0.id == "initial" }?.cssResolvedValues["display"] == "flex")
        #expect(updated.nodes.first { $0.id == "initial" }?.cssResolvedValues["content-visibility"] == "visible")
    }

    /// 論理名（日本語）: Invalid standard CSS mutationテスト
    /// 概要: browserが破棄するkeyword、geometry、track、priority injectionをproject-aware routeでもatomic no-writeとして拒否します。
    @Test("invalid標準CSS値はproject overrideを作らず全sourceを保持する")
    func testInvalidStandardCSSValuesDoNotCreateProjectOverrides() throws {
        // コンディション：importantなproject standard-property winner群と空のcompanion override sourceを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><section class=\"panel\" data-og-id=\"panel\">Panel</section></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = """
        .panel {
          display: grid !important;
          gap: 10px !important;
          width: 100px !important;
          top: 0 !important;
          grid-template-columns: 1fr !important;
          stroke-width: 1 !important;
          z-index: 1 !important;
          scale: 1 !important;
        }
        """
        let companionCSS = "/* keep companion */\n"
        try fixture.writeCSSLibrary(projectCSS)
        try fixture.writeCompanionCSS(companionCSS)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 検証内容：propertyごとのinvalid値とdeclaration injectionをproject-aware setterへ渡す（When）
        let before = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let invalidValues = [
            ("display", "not-a-display"),
            ("gap", "nonsense"),
            ("width", "min()"),
            ("top", "nonsense"),
            ("grid-template-columns", "repeat(nonsense)"),
            ("stroke-width", "calc(nonsense)"),
            ("z-index", "1.5"),
            ("scale", "1 1 1 1"),
            ("scale", "calc(1px)"),
            ("scale", "calc(100% - 1px)"),
            ("scale", "calc(100% - .2)"),
            ("line-height", "calc(1 + 1px)"),
            ("gap", "8px; color: red"),
            ("gap", "8px !important")
        ]
        let edits = try invalidValues.map { property, value in
            try fixture.core.setCSSVariable(
                property,
                value: value,
                nodeID: "panel",
                projectURL: projectURL,
                pageID: fixture.homePageInternalID
            )
        }
        let environmentEdit = try fixture.core.setCSSVariable(
            "width",
            value: "env(safe-area-inset-left)",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let after = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )

        // 期待値：各入力へexplicit diagnosticを返し、HTML/project/companion bytesとcomputed winnerを変えない（Then）
        #expect(before.nodes.first { $0.id == "panel" }?.cssResolvedValues["display"] == "grid")
        #expect(edits.count == invalidValues.count)
        for edit in edits {
            #expect(edit.updated == false)
            #expect(edit.diagnostics.contains { $0.code == "invalid-css-property-value" })
        }
        #expect(environmentEdit.updated == false)
        #expect(environmentEdit.diagnostics.contains { diagnostic in
            diagnostic.code == "incomplete-css-node-provenance"
                || diagnostic.code == "incomplete-css-provenance-write-blocked"
        })
        #expect(after.nodes.first { $0.id == "panel" }?.cssResolvedValues["display"] == "grid")
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == originalHTML)
        #expect(try fixture.readCSSLibrary() == projectCSS)
        #expect(try fixture.readCompanionCSS() == companionCSS)
    }

    /// 論理名（日本語）: Project CSS・responsive winner編集テスト
    /// 概要: project CSSとcompanion CSSを標準cascade順で評価し、active media winnerだけを最小差分更新します。
    @Test("project CSSとactive media layoutをgraphと編集で共有する")
    func testProjectCSSAndActiveMediaLayoutShareGraphAndWinnerEditing() throws {
        // コンディション：project CSSにbase grid、companion CSSにresponsive flex overrideを持つpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <section id="panel" class="panel" data-og-id="panel">Panel</section>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        try fixture.writeCSSLibrary(
            ".panel { display: grid; grid-template-columns: 1fr 1fr; }\n"
        )
        let originalCompanionCSS = """
        /* preserve-before */
        @media   (max-width:720px) {
          .panel { display: flex; flex-direction: column; /* preserve-after */ }
        }
        .future-card { future-layout-mode: preserve-me; }
        """
        try fixture.writeCompanionCSS(originalCompanionCSS)

        // 検証内容：base/mobile graphを比較し、mobile winnerのflex-directionだけを更新する（When）
        let base = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.homePageInternalID)
        let mobile = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["  (MAX-WIDTH:720px)  ", "(max-width: 720px)"]
        )
        let edit = try fixture.core.setCSSVariable(
            "flex-direction",
            value: "row",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(max-width: 720px)"]
        )
        let updatedCompanionCSS = try fixture.readCompanionCSS()
        let baseAfterEdit = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )

        // 期待値：baseではproject grid、mobileではmedia flexを使い、active条件と未知rule/triviaを保持する（Then）
        let basePanel = try #require(base.nodes.first { $0.id == "panel" })
        let mobilePanel = try #require(mobile.nodes.first { $0.id == "panel" })
        #expect(base.activeMediaQueries.isEmpty)
        #expect(basePanel.layout == "grid")
        #expect(basePanel.cssResolvedValues["grid-template-columns"] == "1fr 1fr")
        #expect(mobile.activeMediaQueries == ["(max-width: 720px)"])
        #expect(mobilePanel.layout == "vertical")
        #expect(mobilePanel.cssSourceTrace["display"]?.last?.atRules.first?.prelude == "(max-width:720px)")
        #expect(edit.updated == true)
        #expect(edit.node?.layout == "horizontal")
        #expect(edit.node?.cssVariables["grid-template-columns"] == "1fr 1fr")
        #expect(edit.node?.cssResolvedValues["grid-template-columns"] == "1fr 1fr")
        #expect(updatedCompanionCSS == originalCompanionCSS.replacingOccurrences(of: "flex-direction: column", with: "flex-direction: row"))
        #expect(updatedCompanionCSS.contains("future-layout-mode: preserve-me"))
        #expect(baseAfterEdit.nodes.first { $0.id == "panel" }?.layout == "grid")
    }

    /// 論理名（日本語）: Project CSS node override境界テスト
    /// 概要: project library winnerは直接編集せず、node固有companion overrideを最小差分・冪等にset/removeします。
    @Test("project CSS winnerはcompanion node overrideとして冪等編集する")
    func testProjectCSSWinnerUsesIdempotentCompanionNodeOverride() throws {
        // コンディション：project CSSだけがdisplay winnerを持ち、空でないcompanion commentを持つpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><section id=\"panel\" class=\"panel\" data-og-id=\"panel\">Panel</section></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = ".panel { display: grid; grid-template-columns: 1fr 1fr; }\n"
        let originalCompanionCSS = "/* keep companion */\n"
        try fixture.writeCSSLibrary(projectCSS)
        try fixture.writeCompanionCSS(originalCompanionCSS)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let htmlHash = OpenGraphiteHTMLDocument.contentHash(originalHTML)
        let projectCSSHash = OpenGraphiteHTMLDocument.contentHash(projectCSS)

        // 検証内容：project-aware routeで同じsetを2回、同じremoveを2回実行する（When）
        let firstSet = try fixture.core.setCSSVariable(
            "display",
            value: "flex",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let companionAfterSet = try fixture.readCompanionCSS()
        let secondSet = try fixture.core.setCSSVariable(
            "display",
            value: "flex",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let companionAfterSecondSet = try fixture.readCompanionCSS()
        let firstRemove = try fixture.core.setCSSVariable(
            "display",
            value: "",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let companionAfterRemove = try fixture.readCompanionCSS()
        let secondRemove = try fixture.core.setCSSVariable(
            "display",
            value: "",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let companionAfterSecondRemove = try fixture.readCompanionCSS()
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let finalProjectCSS = try fixture.readCSSLibrary()

        // 期待値：project/HTML hashは不変で、#id overrideだけが追加・削除され、same operationはno-opとなる（Then）
        #expect(firstSet.updated == true)
        #expect(firstSet.node?.layout == "horizontal")
        #expect(firstSet.node?.cssVariables["grid-template-columns"] == "1fr 1fr")
        #expect(companionAfterSet == "/* keep companion */\n\n#panel {\n  display: flex;\n}\n")
        #expect(secondSet.updated == false)
        #expect(companionAfterSecondSet == companionAfterSet)
        #expect(firstRemove.updated == true)
        #expect(firstRemove.node?.layout == "grid")
        #expect(firstRemove.node?.cssVariables["display"] == "grid")
        #expect(companionAfterRemove.contains("/* keep companion */"))
        #expect(!companionAfterRemove.contains("display:"))
        #expect(secondRemove.updated == false)
        #expect(companionAfterSecondRemove == companionAfterRemove)
        #expect(OpenGraphiteHTMLDocument.contentHash(finalHTML) == htmlHash)
        #expect(OpenGraphiteHTMLDocument.contentHash(finalProjectCSS) == projectCSSHash)
        #expect(finalHTML == originalHTML)
        #expect(finalProjectCSS == projectCSS)
    }

    /// 論理名（日本語）: Active project CSS同値更新テスト
    /// 概要: active media内のproject winnerと同じ値はcompanion overrideを追加せず、差分propertyだけを保存します。
    @Test("active project CSSと同値の設定はcompanionを変更しない")
    func testActiveProjectCSSSameValueDoesNotCreateCompanionOverride() throws {
        // コンディション：base gridとactive media内のflex winnerをproject CSSだけに持つpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><section id=\"panel\" class=\"panel\" data-og-id=\"panel\">Panel</section></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = """
        .panel { display: grid; grid-template-columns: 1fr 1fr; }
        @media (max-width: 720px) { .panel { display: flex; } }
        """
        let originalCompanionCSS = "/* keep companion */\n"
        try fixture.writeCSSLibrary(projectCSS)
        try fixture.writeCompanionCSS(originalCompanionCSS)

        // 検証内容：active winnerと同じdisplayを設定した後、差分のflex-directionだけを設定する（When）
        let sameDisplay = try fixture.core.setCSSVariable(
            "display",
            value: "  flex  ",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(max-width: 720px)"]
        )
        let companionAfterSameDisplay = try fixture.readCompanionCSS()
        let directionEdit = try fixture.core.setCSSVariable(
            "flex-direction",
            value: "column",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(max-width: 720px)"]
        )
        let companionAfterDirection = try fixture.readCompanionCSS()
        let finalProjectCSS = try fixture.readCSSLibrary()

        // 期待値：displayはno-opで、companionにはflex-directionだけが追加され、active graphはverticalになる（Then）
        #expect(sameDisplay.updated == false)
        #expect(sameDisplay.node?.layout == "horizontal")
        #expect(companionAfterSameDisplay == originalCompanionCSS)
        #expect(directionEdit.updated == true)
        #expect(directionEdit.node?.layout == "vertical")
        #expect(companionAfterDirection == "/* keep companion */\n\n#panel {\n  flex-direction: column;\n}\n")
        #expect(!companionAfterDirection.contains("display:"))
        #expect(finalProjectCSS == projectCSS)
    }

    /// 論理名（日本語）: Component active media winner編集テスト
    /// 概要: component companion CSSでもactive media winnerだけを最小変更し、base・他media・project libraryを保持します。
    @Test("component active media winnerは同じscopeだけを編集する")
    func testComponentActiveMediaWinnerEditsOnlyMatchingScope() throws {
        // コンディション：component companionにbaseと2つのmedia scope、project libraryに無関係なruleを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML("<!doctype html><html><body><main data-og-id=\"page\">Page</main></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><article class=\"card\" data-og-id=\"card\">Card</article></body></html>",
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        let projectCSS = ":root { --space-card: 24px; }\n"
        try fixture.writeCSSLibrary(projectCSS)
        let originalComponentCSS = """
        .card { top: 0; left: 1px; }
        @media (min-width: 500px) { .card { top: 24px; right: 2px; } }
        @media (min-width: 900px) { .card { top: 48px; } }
        """
        let componentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentURL)
        try originalComponentCSS.write(to: componentCSSURL, atomically: true, encoding: .utf8)
        let originalComponentHTML = try String(contentsOf: componentURL, encoding: .utf8)

        // 検証内容：component graphとmutationへ同じactive media集合を渡してtopだけを更新する（When）
        let active = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID,
            activeMediaQueries: ["(min-width: 500px)"]
        )
        let componentDocument = OpenGraphiteHTMLDocument(html: originalComponentHTML)
        let componentCSS = OpenGraphiteCompanionCSSDocument(css: originalComponentCSS)
        let styleTarget = try #require(componentDocument.styleTarget(
            forNodeID: "card",
            properties: ["top"],
            companionCSS: componentCSS,
            activeMediaQueries: ["(min-width: 500px)"]
        ))
        let directWinner = OpenGraphiteCSSSourceDocument.parse(originalComponentCSS).cascadeTrace(
            for: styleTarget.element,
            environment: .inspection(activeMediaQueries: ["(min-width: 500px)"])
        ).winners["top"]
        var directMutation = componentCSS
        directMutation.setCSSProperty(
            "top",
            value: "12px",
            for: styleTarget.element,
            fallbackSelector: styleTarget.value.writeSelector,
            activeMediaQueries: ["(min-width: 500px)"]
        )
        let result = try fixture.core.setCSSVariable(
            "top",
            value: "12px",
            nodeID: "card",
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID,
            activeMediaQueries: ["(min-width: 500px)"]
        )
        let updatedComponentCSS = try String(contentsOf: componentCSSURL, encoding: .utf8)
        let updatedComponentHTML = try String(contentsOf: componentURL, encoding: .utf8)

        // 期待値：active 24pxだけが12pxになり、base・他media・HTML・project libraryはbyte不変になる（Then）
        #expect(active.nodes.first { $0.id == "card" }?.cssResolvedValues["top"] == "24px")
        #expect(styleTarget.value.resolvedValues["top"] == "24px")
        #expect(directWinner?.declaration.value == "24px")
        #expect(directMutation.css == originalComponentCSS.replacingOccurrences(of: "top: 24px", with: "top: 12px"))
        #expect(result.updated == true)
        #expect(result.node?.cssResolvedValues["top"] == "12px")
        #expect(updatedComponentCSS == originalComponentCSS.replacingOccurrences(of: "top: 24px", with: "top: 12px"))
        #expect(updatedComponentCSS.contains("top: 0"))
        #expect(updatedComponentCSS.contains("top: 48px"))
        #expect(updatedComponentHTML == originalComponentHTML)
        #expect(try fixture.readCSSLibrary() == projectCSS)
    }

    /// 論理名（日本語）: CLI標準layout responsive parityテスト
    /// 概要: `page graph`と`node style set`がproject CSS、active media、source最小差分をShared Coreと同じJSON契約で扱います。
    @Test("CLIはproject CSSとactive mediaの標準layoutを共有する")
    func testCLIStandardLayoutAndActiveMediaParity() throws {
        // コンディション：project gridとcompanion responsive flexを持つannotation付きpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><section class=\"panel\" data-og-id=\"panel\">Panel</section></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        try fixture.writeCSSLibrary(".panel { display: grid; grid-template-columns: 2fr 1fr; }\n")
        let originalCompanionCSS = """
        /* preserve */
        @media (max-width: 720px) {
          .panel { display: flex; flex-direction: column; }
        }
        .future-card { future-layout-mode: preserve-me; }
        """
        try fixture.writeCompanionCSS(originalCompanionCSS)
        let cli = OgkilnCLI()
        var graphOutput = ""
        var graphError = ""

        // 検証内容：active条件付きgraphを取得し、同じ条件のwinnerだけをCLIから更新する（When）
        let graphCode = cli.run(
            arguments: [
                "page", "graph", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--active-media", " (max-width:   720px) ",
                "--active-media", "(max-width: 720px)",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { graphOutput += $0 },
            stderr: { graphError += $0 }
        )
        let graph = try JSONDecoder().decode(OpenGraphitePageGraph.self, from: Data(graphOutput.utf8))
        var editOutput = ""
        var editError = ""
        let editCode = cli.run(
            arguments: [
                "node", "style", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "panel",
                "--var", "flex-direction",
                "--value", "row",
                "--active-media", "(max-width: 720px)"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { editOutput += $0 },
            stderr: { editError += $0 }
        )
        let edit = try JSONDecoder().decode(OpenGraphiteEditResult.self, from: Data(editOutput.utf8))
        let updatedCompanionCSS = try fixture.readCompanionCSS()

        // 期待値：JSONはactive条件とproject authored値を返し、編集はmedia value range以外を保持する（Then）
        let panel = try #require(graph.nodes.first { $0.id == "panel" })
        #expect(graphCode == 0)
        #expect(graphError.isEmpty)
        #expect(graph.activeMediaQueries == ["(max-width: 720px)"])
        #expect(panel.layout == "vertical")
        #expect(panel.cssVariables["grid-template-columns"] == "2fr 1fr")
        #expect(editCode == 0)
        #expect(editError.isEmpty)
        #expect(edit.updated == true)
        #expect(edit.node?.layout == "horizontal")
        #expect(updatedCompanionCSS == originalCompanionCSS.replacingOccurrences(
            of: "flex-direction: column",
            with: "flex-direction: row"
        ))
        #expect(updatedCompanionCSS.contains("future-layout-mode: preserve-me"))
    }

    /// 論理名（日本語）: 独立stylesheet provenance境界テスト
    /// 概要: malformed project CSSが後続stylesheetを飲み込まず、既知winnerをinspectionしつつmutationをatomicに止めます。
    @Test("独立stylesheetはsource identity順で評価して不完全provenanceの書込を止める")
    func testIndependentStylesheetsPreserveKnownTraceAndBlockIncompleteWrites() throws {
        // コンディション：malformed project、embedded、local linked、companionをdocument orderで参照するpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html><html><head>
              <link rel="stylesheet" href="./OpenGraphite.css">
              <style>.panel { display: block; }</style>
              <link rel="stylesheet" href="./local.css">
              <link rel="stylesheet" href="./index.css">
            </head><body><section id="panel" class="panel" data-og-id="panel">Panel</section></body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = ".panel { display: grid; /* malformed project source"
        let localCSS = ".panel { display: inline-flex; }\n"
        let companionCSS = ".panel { display: flex; flex-direction: column; }\n"
        try fixture.writeCSSLibrary(projectCSS)
        try localCSS.write(
            to: fixture.rootURL.appendingPathComponent("local.css"),
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeCompanionCSS(companionCSS)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 検証内容：graphをinspectionし、winnerが既知でも同じnodeへmutationを試みる（When）
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let panel = try #require(graph.nodes.first { $0.id == "panel" })
        let trace = try #require(panel.cssSourceTrace["display"])
        let edit = try fixture.core.setCSSVariable(
            "display",
            value: "grid",
            nodeID: "panel",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )

        // 期待値：sourceは個別ASTとして後続winnerまで返り、incomplete診断付きで全bytesを変更しない（Then）
        #expect(panel.cssResolvedValues["display"] == "flex")
        #expect(graph.hasIncompleteCSSProvenance == true)
        #expect(panel.hasIncompleteCSSProvenance == true)
        #expect(graph.diagnostics.contains { $0.code == "incomplete-css-provenance" })
        #expect(trace.contains { $0.sourceKind == "embedded" && $0.sourceID.contains("#style-") })
        #expect(trace.contains { $0.sourceKind == "linked" && $0.sourceID.contains("local.css#link-") })
        #expect(trace.last?.sourceKind == "companion")
        #expect(trace.map(\.stylesheetOrder) == trace.map(\.stylesheetOrder).sorted())
        #expect(Set(trace.map(\.sourceID)).count == trace.count)
        #expect(edit.updated == false)
        #expect(edit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == originalHTML)
        #expect(try fixture.readCSSLibrary() == projectCSS)
        #expect(try String(contentsOf: fixture.rootURL.appendingPathComponent("local.css"), encoding: .utf8) == localCSS)
        #expect(try fixture.readCompanionCSS() == companionCSS)
    }

    /// 論理名（日本語）: Project read-only winner共通overrideテスト
    /// 概要: important/specificity/shorthand/active mediaを保ったnode-scoped companion overrideとproject-only remove拒否を検証します。
    @Test("project winnerはimportantとactive scopeを保つcompanion overrideでのみ更新する")
    func testProjectWinnerCreatesScopedWinningOverrideAndRejectsReadOnlyRemoval() throws {
        // コンディション：important ID winner、flex-flow shorthand、responsive project winnerだけを持つ2 nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <section id="important" class="card" data-og-id="important">Important</section>
              <section id="responsive" class="responsive" data-og-id="responsive">Responsive</section>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = """
        #important.card { display: grid !important; flex-flow: column wrap !important; gap: 12px; }
        .responsive { display: grid; }
        @media (max-width: 500px) { .responsive { display: flex; } }
        """
        let companionCSS = "/* keep companion */\n"
        try fixture.writeCSSLibrary(projectCSS)
        try fixture.writeCompanionCSS(companionCSS)

        // 検証内容：project-only remove、important longhand set、active media setを同じproject-aware routeで実行する（When）
        let removal = try fixture.core.setCSSVariable(
            "gap",
            value: "",
            nodeID: "important",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let displayEdit = try fixture.core.setCSSVariable(
            "display",
            value: "flex",
            nodeID: "important",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let directionEdit = try fixture.core.setCSSVariable(
            "flex-direction",
            value: "row",
            nodeID: "important",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let responsiveEdit = try fixture.core.setCSSVariable(
            "display",
            value: "block",
            nodeID: "responsive",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let base = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.homePageInternalID)
        let mobile = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let updatedCompanionCSS = try fixture.readCompanionCSS()

        // 期待値：libraryは不変で、requested propertyだけがwinning companion sourceへ同じscope/priorityで保存される（Then）
        #expect(removal.updated == false)
        #expect(removal.diagnostics.contains { $0.code == "read-only-css-winner" })
        #expect(displayEdit.updated == true)
        #expect(directionEdit.updated == true)
        #expect(directionEdit.node?.cssResolvedValues["flex-direction"] == "row")
        #expect(directionEdit.node?.cssResolvedValues["flex-wrap"] == "wrap")
        #expect(responsiveEdit.updated == true)
        #expect(base.nodes.first { $0.id == "responsive" }?.cssResolvedValues["display"] == "grid")
        #expect(mobile.nodes.first { $0.id == "responsive" }?.cssResolvedValues["display"] == "block")
        #expect(updatedCompanionCSS.contains("display: flex !important"))
        #expect(updatedCompanionCSS.contains("flex-direction: row !important"))
        #expect(updatedCompanionCSS.contains("@media (max-width: 500px)"))
        #expect(updatedCompanionCSS.contains("display: block"))
        #expect(try fixture.readCSSLibrary() == projectCSS)
    }

    /// 論理名（日本語）: Related rendering active media overrideテスト
    /// 概要: projectのmedia内object-fit winnerをwrapper選択から同scopeのcompanion overrideへ保存します。
    @Test("related rendering propertyもproject active winnerと共通mutation境界を使う")
    func testRelatedRenderingPropertyUsesProjectActiveWinnerOverride() throws {
        // コンディション：image targetのbase/active object-fitをproject CSSだけに持つpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><figure id=\"media\" data-og-id=\"media\"><img src=\"hero.png\" alt=\"Hero\"></figure></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        let projectCSS = """
        #media > img { object-fit: contain; }
        @media (min-width: 600px) { #media > img { object-fit: cover; } }
        """
        try fixture.writeCSSLibrary(projectCSS)
        try fixture.writeCompanionCSS("/* keep */\n")

        // 検証内容：project-only active winnerのremoveを試した後、同じactive環境でfillへ設定する（When）
        let removal = try fixture.core.setCSSVariable(
            "object-fit",
            value: "",
            nodeID: "media",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(min-width: 600px)"]
        )
        let edit = try fixture.core.setCSSVariable(
            "object-fit",
            value: "fill",
            nodeID: "media",
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(min-width: 600px)"]
        )
        let base = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.homePageInternalID)
        let active = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            activeMediaQueries: ["(min-width: 600px)"]
        )
        let baseTarget = try #require(base.nodes.first { $0.id == "media" }?.renderingTargets.first { $0.kind == "media" })
        let activeTarget = try #require(active.nodes.first { $0.id == "media" }?.renderingTargets.first { $0.kind == "media" })
        let updatedCompanionCSS = try fixture.readCompanionCSS()

        // 期待値：removeはno-write、setはmedia scopeだけへ保存され、base/project sourceを変えない（Then）
        #expect(removal.updated == false)
        #expect(removal.diagnostics.contains { $0.code == "read-only-css-winner" })
        #expect(edit.updated == true)
        #expect(baseTarget.resolvedValues["object-fit"] == "contain")
        #expect(activeTarget.resolvedValues["object-fit"] == "fill")
        #expect(updatedCompanionCSS.contains("@media (min-width: 600px)"))
        #expect(updatedCompanionCSS.contains("object-fit: fill"))
        #expect(try fixture.readCSSLibrary() == projectCSS)
    }

    /// 論理名（日本語）: Node単位incomplete CSS mutation guardテスト
    /// 概要: unsupported conditional、active animation、CSS-wide revert、invalid finite値の該当nodeだけをinspection-onlyにします。
    @Test("node単位の不完全CSS provenanceは該当nodeだけatomic no-writeにする")
    func testNodeScopedIncompleteCSSProvenanceBlocksOnlyAffectedNodes() throws {
        // コンディション：complete nodeとsupports/keyframes/revert/invalid finite値でwinner不確実な4 nodeを同じcompanionへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <section class="safe" data-og-id="safe">Safe</section>
              <section class="uncertain" data-og-id="uncertain">Conditional</section>
              <section class="animated" data-og-id="animated">Animated</section>
              <section class="revert-parent"><section class="revert" data-og-id="revert">Revert</section></section>
              <section class="invalid" data-og-id="invalid">Invalid</section>
              <section data-og-id="invalid-inline" style="display: not-a-display">Invalid inline</section>
            </body></html>
            """
        )
        let css = """
        .safe { display: block; }
        .uncertain { display: block; }
        @supports (display: grid) { .uncertain { display: grid; } }
        @keyframes pulse { from { opacity: 0; } to { opacity: 1; } }
        .animated { display: block; animation-name: pulse; }
        .revert-parent { visibility: hidden; overflow-wrap: anywhere; }
        .revert { display: block; display: revert; visibility: revert; overflow-wrap: revert-layer; }
        .invalid { display: not-a-display; }
        """
        try fixture.writeCompanionCSS(css)

        // 検証内容：graph flagを取得し、complete nodeの編集後に各incomplete nodeへ同じproperty mutationを試みる（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let safeEdit = try fixture.core.setCSSVariable("display", value: "flex", nodeID: "safe", htmlURL: fixture.htmlURL)
        let afterSafeEdit = try fixture.readCompanionCSS()
        let conditionalEdit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "uncertain", htmlURL: fixture.htmlURL
        )
        let animationEdit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "animated", htmlURL: fixture.htmlURL
        )
        let revertEdit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "revert", htmlURL: fixture.htmlURL
        )
        let invalidEdit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "invalid", htmlURL: fixture.htmlURL
        )
        let invalidInlineEdit = try fixture.core.setCSSVariable(
            "display", value: "flex", nodeID: "invalid-inline", htmlURL: fixture.htmlURL
        )

        // 期待値：pageは不完全を明示しつつsafe nodeだけ更新し、3つのblocked writeはbytesを変えない（Then）
        #expect(graph.hasIncompleteCSSProvenance == true)
        #expect(graph.nodes.first { $0.id == "safe" }?.hasIncompleteCSSProvenance == false)
        #expect(graph.nodes.first { $0.id == "uncertain" }?.hasIncompleteCSSProvenance == true)
        #expect(graph.nodes.first { $0.id == "animated" }?.hasIncompleteCSSProvenance == true)
        #expect(graph.nodes.first { $0.id == "revert" }?.hasIncompleteCSSProvenance == true)
        #expect(graph.nodes.first { $0.id == "revert" }?.cssResolvedValues["visibility"] == "hidden")
        #expect(graph.nodes.first { $0.id == "revert" }?.cssResolvedValues["overflow-wrap"] == "anywhere")
        #expect(graph.nodes.first { $0.id == "invalid" }?.hasIncompleteCSSProvenance == true)
        #expect(graph.nodes.first { $0.id == "invalid-inline" }?.hasIncompleteCSSProvenance == true)
        #expect(safeEdit.updated == true)
        for result in [conditionalEdit, animationEdit, revertEdit, invalidEdit, invalidInlineEdit] {
            #expect(result.updated == false)
            #expect(result.diagnostics.contains { $0.code == "incomplete-css-node-provenance" })
            #expect(result.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        }
        #expect(try fixture.readCompanionCSS() == afterSafeEdit)
    }

    /// 論理名（日本語）: 重複editable stylesheet scope guardテスト
    /// 概要: 同じcompanion fileを異なるlink media scopeで参照する場合にsingle range mutationを拒否します。
    @Test("同一editable stylesheetの異なるlink scopeはatomic no-writeにする")
    func testDuplicateEditableStylesheetScopesBlockMutation() throws {
        // コンディション：同じcompanionをmobile/desktopの異なるouter mediaで2回linkするHTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html><html><head>
              <link rel="stylesheet" href="./index.css" media="(max-width: 500px)">
              <link rel="stylesheet" href="./index.css" media="(min-width: 501px)">
            </head><body><section class="panel" data-og-id="panel">Panel</section></body></html>
            """
        )
        let companionCSS = ".panel { display: flex; }\n"
        try fixture.writeCompanionCSS(companionCSS)

        // 検証内容：mobile scopeでgraph inspection後にdisplay mutationを試みる（When）
        let graph = try fixture.core.pageGraph(
            at: fixture.htmlURL,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let edit = try fixture.core.setCSSVariable(
            "display",
            value: "grid",
            nodeID: "panel",
            htmlURL: fixture.htmlURL,
            activeMediaQueries: ["(max-width: 500px)"]
        )

        // 期待値：duplicate instance/orderはinspectionできるが単一file rangeへscopeを漏らす書込は拒否する（Then）
        #expect(graph.nodes.first { $0.id == "panel" }?.cssResolvedValues["display"] == "flex")
        #expect(graph.hasIncompleteCSSProvenance == true)
        #expect(graph.diagnostics.contains {
            $0.code == "incomplete-css-provenance" && $0.message.contains("異なるlink media scope")
        })
        #expect(edit.updated == false)
        #expect(edit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(try fixture.readCompanionCSS() == companionCSS)
    }

    /// 論理名（日本語）: Import/layer provenance境界テスト
    /// 概要: local `@import`と未評価`@layer`をlossless保持し、既知winnerのinspection後もsource-wide mutationを拒否します。
    @Test("importとlayerを含むstylesheetはinspection-onlyでatomic no-writeにする")
    func testImportAndLayerStylesheetProvenanceBlocksWrites() throws {
        // コンディション：読み込み可能なimport先とlayer、通常ruleを同じcompanion CSSに持つpageを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            "<!doctype html><html><body><section class=\"panel\" data-og-id=\"panel\">Panel</section></body></html>"
        )
        try ".panel { color: rgb(1, 2, 3); }\n".write(
            to: fixture.rootURL.appendingPathComponent("theme.css"),
            atomically: true,
            encoding: .utf8
        )
        let companionCSS = """
        @import "./theme.css" screen;
        @layer theme { .panel { display: grid; } }
        .panel { display: flex; }
        """
        try fixture.writeCompanionCSS(companionCSS)

        // 検証内容：known base ruleをinspectionしてdisplay mutationを試みる（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let edit = try fixture.core.setCSSVariable(
            "display", value: "block", nodeID: "panel", htmlURL: fixture.htmlURL
        )

        // 期待値：import/layerの未評価境界を診断し、known trace/source bytesを保持して書込を止める（Then）
        #expect(graph.nodes.first { $0.id == "panel" }?.cssResolvedValues["display"] == "flex")
        #expect(graph.hasIncompleteCSSProvenance == true)
        #expect(graph.diagnostics.contains {
            $0.code == "incomplete-css-provenance" && $0.message.contains("@import")
        })
        #expect(graph.diagnostics.contains {
            $0.code == "incomplete-css-provenance" && $0.message.contains("@layer")
        })
        #expect(edit.updated == false)
        #expect(edit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(try fixture.readCompanionCSS() == companionCSS)
    }

    /// 論理名（日本語）: 継承CSS provenance traceテスト
    /// 概要: 継承可能property/custom propertyの祖先candidateを`inherited=true`で子nodeへ伝播し、local winnerと区別します。
    @Test("継承CSS winnerはsource identity付きinherited traceとして子nodeへ返る")
    func testInheritedCSSWinnerCarriesSourceIdentityIntoChildTrace() throws {
        // コンディション：親visibility/custom property、解決済み参照、真に未解決な参照を持つ3 childを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html><html><body><section class="parent" data-og-id="parent">
              <span data-og-id="inherited">Inherited</span>
              <span class="local" data-og-id="local">Local</span>
              <span class="missing" data-og-id="missing">Missing</span>
            </section></body></html>
            """
        )
        let companionCSS = """
        .parent { visibility: hidden; --tone: rgb(12, 34, 56); }
        .local { visibility: visible; color: var(--tone); }
        .missing { color: var(--absent); }
        """
        try fixture.writeCompanionCSS(companionCSS)

        // 検証内容：Agent graphとsource traceを取得し、解決済み／未解決nodeへ同じcolor mutationを試みる（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let inherited = try #require(graph.nodes.first { $0.id == "inherited" })
        let local = try #require(graph.nodes.first { $0.id == "local" })
        let missing = try #require(graph.nodes.first { $0.id == "missing" })
        let inheritedTrace = try #require(inherited.cssSourceTrace["visibility"]?.last)
        let localTrace = try #require(local.cssSourceTrace["visibility"]?.last)
        let localEdit = try fixture.core.setCSSVariable(
            "color", value: "rgb(1, 2, 3)", nodeID: "local", htmlURL: fixture.htmlURL
        )
        let afterLocalEdit = try fixture.readCompanionCSS()
        let missingEdit = try fixture.core.setCSSVariable(
            "color", value: "rgb(4, 5, 6)", nodeID: "missing", htmlURL: fixture.htmlURL
        )

        // 期待値：computed値は継承し、祖先sourceだけinherited=true、local winnerはfalseとして同じorigin identityを持つ（Then）
        #expect(inherited.cssResolvedValues["visibility"] == "hidden")
        #expect(inheritedTrace.inherited == true)
        #expect(inheritedTrace.selector == ".parent")
        #expect(inheritedTrace.sourceKind == "companion")
        #expect(inheritedTrace.sourceID.contains("index.css"))
        #expect(local.cssResolvedValues["visibility"] == "visible")
        #expect(local.cssResolvedValues["color"] == "rgb(12, 34, 56)")
        #expect(local.hasIncompleteCSSProvenance == false)
        #expect(localTrace.inherited == false)
        #expect(localTrace.selector == ".local")
        #expect(missing.cssResolvedValues["color"] == nil)
        #expect(missing.hasIncompleteCSSProvenance == true)
        #expect(localEdit.updated == true)
        #expect(missingEdit.updated == false)
        #expect(missingEdit.diagnostics.contains { $0.code == "incomplete-css-node-provenance" })
        #expect(missingEdit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(try fixture.readCompanionCSS() == afterLocalEdit)
    }

    /// 論理名（日本語）: Var-backed shorthand mutation安全性テスト
    /// 概要: 最終解決longhandのsame-valueをno-opにし、変更時はraw shorthandを壊さない独立overrideを保存します。
    @Test("var-backed shorthandのsame-valueとsetはresolved longhandで安全に判定する")
    func testVariableBackedShorthandMutationUsesResolvedLonghands() throws {
        // コンディション：valid/invalidなcustom-property backed shorthandを持つ2 nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <section class="panel" data-og-id="panel">Panel</section>
              <section class="invalid" data-og-id="invalid">Invalid</section>
            </body></html>
            """
        )
        let originalCSS = """
        .panel {
          --flow: column wrap;
          --space: 8px 12px;
          --edges: 1px 2px 3px 4px;
          display: flex;
          flex-flow: var(--flow);
          gap: var(--space);
          margin: var(--edges);
        }
        .invalid { --flow: column nonsense; display: flex; flex-flow: var(--flow); }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // 検証内容：resolved値と同じ3 longhandをsetし、directionだけ変更後にinvalid nodeも編集する（When）
        let before = try fixture.core.pageGraph(at: fixture.htmlURL)
        let directionNoOp = try fixture.core.setCSSVariable(
            "flex-direction", value: "column", nodeID: "panel", htmlURL: fixture.htmlURL
        )
        let gapNoOp = try fixture.core.setCSSVariable(
            "gap", value: "8px 12px", nodeID: "panel", htmlURL: fixture.htmlURL
        )
        let marginNoOp = try fixture.core.setCSSVariable(
            "margin", value: "1px 2px 3px 4px", nodeID: "panel", htmlURL: fixture.htmlURL
        )
        let afterNoOps = try fixture.readCompanionCSS()
        let edit = try fixture.core.setCSSVariable(
            "flex-direction", value: "row", nodeID: "panel", htmlURL: fixture.htmlURL
        )
        let afterEdit = try fixture.readCompanionCSS()
        let invalidEdit = try fixture.core.setCSSVariable(
            "flex-direction", value: "row", nodeID: "invalid", htmlURL: fixture.htmlURL
        )
        let updated = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：same-valueはbyte保持し、setはwrapを維持するlonghand override、invalidはatomic no-writeになる（Then）
        let panelBefore = try #require(before.nodes.first { $0.id == "panel" })
        #expect(panelBefore.cssResolvedValues["flex-direction"] == "column")
        #expect(panelBefore.cssResolvedValues["flex-wrap"] == "wrap")
        #expect(panelBefore.cssResolvedValues["gap"] == "8px 12px")
        #expect(panelBefore.cssResolvedValues["margin"] == "1px 2px 3px 4px")
        #expect(panelBefore.cssSourceTrace["flex-direction"]?.last?.authoredProperty == "flex-flow")
        #expect(before.nodes.first { $0.id == "invalid" }?.hasIncompleteCSSProvenance == true)
        for result in [directionNoOp, gapNoOp, marginNoOp] {
            #expect(result.updated == false)
            #expect(result.diagnostics.isEmpty)
        }
        #expect(afterNoOps == originalCSS)
        #expect(edit.updated == true)
        #expect(afterEdit.contains("flex-flow: var(--flow);"))
        #expect(afterEdit.contains("flex-direction: row"))
        #expect(updated.nodes.first { $0.id == "panel" }?.cssResolvedValues["flex-direction"] == "row")
        #expect(updated.nodes.first { $0.id == "panel" }?.cssResolvedValues["flex-wrap"] == "wrap")
        #expect(invalidEdit.updated == false)
        #expect(invalidEdit.diagnostics.contains { $0.code == "incomplete-css-node-provenance" })
        #expect(invalidEdit.diagnostics.contains { $0.code == "incomplete-css-provenance-write-blocked" })
        #expect(try fixture.readCompanionCSS() == afterEdit)
    }

    /// 論理名（日本語）: Shorthand由来longhand削除境界テスト
    /// 概要: flex-flow/insetの一部だけを意味保存して削除できない場合にexplicit errorで全sourceを保持します。
    @Test("shorthand由来longhandの削除はsilent no-opにせずatomic errorにする")
    func testShorthandDerivedLonghandRemovalReturnsAtomicError() throws {
        // コンディション：flex-flowとinsetだけからlonghandが解決されるcompanion CSSを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            "<!doctype html><html><body><section class=\"card\" data-og-id=\"card\">Card</section></body></html>"
        )
        let companionCSS = ".card { display: flex; flex-flow: column wrap; inset: 10px 20px; }\n"
        try fixture.writeCompanionCSS(companionCSS)

        // 検証内容：shorthand subpropertyのflex-directionとtopだけを削除する（When）
        let directionRemoval = try fixture.core.setCSSVariable(
            "flex-direction", value: "", nodeID: "card", htmlURL: fixture.htmlURL
        )
        let topRemoval = try fixture.core.setCSSVariable(
            "top", value: "", nodeID: "card", htmlURL: fixture.htmlURL
        )

        // 期待値：両操作ともexplicit diagnosticを返し、shorthandと他subpropertyのbytesを変更しない（Then）
        for result in [directionRemoval, topRemoval] {
            #expect(result.updated == false)
            #expect(result.diagnostics.contains { $0.code == "shorthand-css-removal-unsupported" })
        }
        #expect(try fixture.readCompanionCSS() == companionCSS)
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

    /// 論理名（日本語）: Optional annotation標準HTML inspectionテスト
    /// 概要: 未注釈、部分注釈、完全注釈、legacy、非管理要素を同じgraphへ返しread/validateでsourceを変更しないことを確認します。
    @Test("標準HTMLをannotationなしでinspectionしてsourceを変更しない")
    func testStandardHTMLInspectionUsesOptionalAnnotationsWithoutMutation() throws {
        // コンディション：raw text、template content、各annotation状態を含む標準HTMLを補完せず用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let html = """
        <!doctype html>
        <html lang="ja"><head>
          <title>Literal &lt;fake-title&gt;</title>
          <style>.card::before { content: "<fake-style>"; }</style>
          <script>const markup = "<fake-script data-og-id='ghost'>"; const again = "<script>";</script>
        </head><body>
          <main id="app">
            <h1>Standard heading</h1>
            <section data-og-id="partial">Partial</section>
            <button data-og-id="save" data-og-internal-id="save-node">Save</button>
            <legacy-card data-og-type="frame">Legacy hint</legacy-card>
            <vendor-card data-vendor-state="ready">Unknown resource</vendor-card>
            <template id="card-template"><article>Template body</article></template>
          </main>
        </body></html>
        """
        try fixture.writeRawHTML(html)
        try fixture.writeProject(to: projectURL)

        // 検証内容：graph/query/validationを繰り返し実行する（When）
        let firstGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let secondGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let projectGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：phantom raw-text nodeを作らず全実要素とreference根拠を返し、bytesは不変である（Then）
        #expect(firstGraph.nodes.map(\.tagName) == [
            "html", "head", "title", "style", "script", "body", "main", "h1", "section",
            "button", "legacy-card", "vendor-card", "template", "article"
        ])
        #expect(!firstGraph.nodes.contains { $0.tagName.hasPrefix("fake-") || $0.id == "ghost" })
        let main = try #require(firstGraph.nodes.first { $0.tagName == "main" })
        let partial = try #require(firstGraph.nodes.first { $0.id == "partial" })
        let complete = try #require(firstGraph.nodes.first { $0.id == "save" })
        let legacy = try #require(firstGraph.nodes.first { $0.tagName == "legacy-card" })
        let unmanaged = try #require(firstGraph.nodes.first { $0.tagName == "vendor-card" })
        let script = try #require(firstGraph.nodes.first { $0.tagName == "script" })
        let scriptClosingEnd = try #require(html.range(of: "</script>")?.upperBound)
        let plaintextHTML = "<plaintext>Literal <div>not-a-node</div>"
        let plaintextNodes = OpenGraphiteHTMLDocument(html: plaintextHTML).nodes()
        #expect(main.annotationStatus == .none)
        #expect(main.referenceStability == .session)
        #expect(main.locator.selector == "#app")
        #expect(main.reference.contains("\(main.locator.sourceRange.start)-\(main.locator.sourceRange.end)"))
        #expect(partial.annotationStatus == .partial)
        #expect(partial.referenceStability == .session)
        #expect(complete.annotationStatus == .complete)
        #expect(complete.referenceStability == .stable)
        #expect(legacy.annotationStatus == .none)
        #expect(legacy.legacyTypeHint == "frame")
        #expect(legacy.referenceStability == .session)
        #expect(unmanaged.annotationStatus == .none)
        #expect(script.locator.sourceRange.end == html.distance(from: html.startIndex, to: scriptClosingEnd))
        #expect(plaintextNodes.map(\.tagName) == ["plaintext"])
        #expect(plaintextNodes.first?.locator.sourceRange.end == plaintextHTML.count)
        #expect(secondGraph.nodes.map(\.reference) == firstGraph.nodes.map(\.reference))
        #expect(projectGraph.nodes.first { $0.id == "save" }?.reference == "ogref:node:\(fixture.chapterInternalID):\(fixture.homePageInternalID):save-node")
        #expect(validation.valid == true)
        #expect(!validation.diagnostics.contains { ["missing-data-og-id", "missing-data-og-internal-id", "missing-data-og-type"].contains($0.code) })
        #expect(afterHTML == html)
    }

    /// 論理名（日本語）: Optional annotation component inspectionテスト
    /// 概要: 注釈済みpageと共存する未注釈custom-element componentをproject経由でinspection/validationしてもsourceを変更しません。
    @Test("未注釈componentをproject graphでinspectionしてsourceを変更しない")
    func testUnannotatedComponentInspectionCoexistsWithAnnotatedPageWithoutMutation() throws {
        // コンディション：全nodeにidentityを持つpageと、annotationのない標準custom-element componentを同じprojectへ登録する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let annotatedPageHTML = """
        <!doctype html><html data-og-id="page-document" data-og-internal-id="page-document-node"><body data-og-id="page-body" data-og-internal-id="page-body-node"><main data-og-id="page-root" data-og-internal-id="page-root-node">Page</main></body></html>
        """
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        let unannotatedComponentHTML = """
        <!doctype html><html><body><product-card id="primary-card" class="card"><h2>Standard component</h2></product-card><vendor-badge>Ready</vendor-badge></body></html>
        """
        try fixture.writeRawHTML(annotatedPageHTML)
        try fixture.writeRawHTML(unannotatedComponentHTML, to: componentURL)
        try fixture.writeProjectWithComponents(to: projectURL)
        let beforeHash = OpenGraphiteHTMLDocument.contentHash(unannotatedComponentHTML)

        // 検証内容：component/page graph、project open summary、validationを繰り返し共有Coreから取得する（When）
        let componentGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID
        )
        let repeatedComponentGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID
        )
        let pageGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let summary = try fixture.core.inspectProject(at: projectURL)
        let validation = try fixture.core.validateProject(at: projectURL)
        let afterHTML = try String(contentsOf: componentURL, encoding: .utf8)
        let productCard = try #require(componentGraph.nodes.first { $0.tagName == "product-card" })
        let vendorBadge = try #require(componentGraph.nodes.first { $0.tagName == "vendor-badge" })
        let annotatedPageRoot = try #require(pageGraph.nodes.first { $0.id == "page-root" })

        // 期待値：component全elementはnone/session locatorでinspectでき、annotated pageはstableのままsource bytes/hashも不変である（Then）
        #expect(componentGraph.nodes.allSatisfy { $0.annotationStatus == .none })
        #expect(componentGraph.nodes.allSatisfy { $0.referenceStability == .session })
        #expect(productCard.locator.selector == "#primary-card")
        #expect(vendorBadge.locator.selector == "vendor-badge")
        #expect(productCard.locator.documentURL == componentURL.standardizedFileURL.absoluteString)
        #expect(repeatedComponentGraph.nodes.map(\.reference) == componentGraph.nodes.map(\.reference))
        #expect(annotatedPageRoot.annotationStatus == .complete)
        #expect(annotatedPageRoot.referenceStability == .stable)
        #expect(summary.components.map(\.id) == ["cards"])
        #expect(validation.valid == true)
        #expect(componentGraph.diagnostics.isEmpty)
        #expect(afterHTML == unannotatedComponentHTML)
        #expect(OpenGraphiteHTMLDocument.contentHash(afterHTML) == beforeHash)
    }

    /// 論理名（日本語）: HTML optional end tag DOM inspectionテスト
    /// 概要: 標準HTMLで終了タグを省略できる要素をbrowser同等のsibling/parent構造へ解釈し、inspectionでsourceを変更しません。
    @Test("optional end tagを標準DOM siblingとしてinspectionする")
    func testOptionalEndTagsProduceStandardDOMRelationshipsWithoutMutation() throws {
        // コンディション：list、description、paragraph、ruby、select、tableで標準のoptional end tagを省略したHTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><body>
        <ul><li id="li-a">A<li id="li-b">B</ul>
        <dl><dt id="term-a">A<dd id="definition-a">Alpha<dt id="term-b">B</dl>
        <p id="paragraph">Text<div id="block">Block</div>
        <ruby><rt id="rt-a">A<rp id="rp-a">(<rt id="rt-b">B</ruby>
        <select><optgroup label="A"><option id="option-a">A<option id="option-b">B<optgroup label="B"><option id="option-c">C</select>
        <table><caption id="caption">Caption<thead><tr><th id="heading-a">A<th id="heading-b">B<tbody><tr id="row-a"><td id="cell-a">A<td id="cell-b">B<tr id="row-b"><td id="cell-c">C<tfoot><tr><td id="footer-cell">F</table>
        </body></html>
        """
        try fixture.writeRawHTML(html)

        // 検証内容：source graphとvalidationを読み取り、保存済みbytesを再取得する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let node = { (id: String) throws -> OpenGraphiteAgentNode in
            try #require(graph.nodes.first { $0.locator.selector == "#\(id)" })
        }
        let list = try #require(graph.nodes.first { $0.tagName == "ul" })
        let descriptionList = try #require(graph.nodes.first { $0.tagName == "dl" })
        let body = try #require(graph.nodes.first { $0.tagName == "body" })
        let ruby = try #require(graph.nodes.first { $0.tagName == "ruby" })
        let select = try #require(graph.nodes.first { $0.tagName == "select" })
        let optionGroups = graph.nodes.filter { $0.tagName == "optgroup" }
        let table = try #require(graph.nodes.first { $0.tagName == "table" })
        let caption = try node("caption")
        let tableSections = graph.nodes.filter { ["thead", "tbody", "tfoot"].contains($0.tagName) }
        let tbody = try #require(tableSections.first { $0.tagName == "tbody" })
        let listItemA = try node("li-a")
        let listItemB = try node("li-b")
        let headingA = try node("heading-a")
        let headingB = try node("heading-b")
        let cellA = try node("cell-a")
        let cellB = try node("cell-b")
        let cellC = try node("cell-c")
        let rowB = try node("row-b")
        let sourceHTML = { (node: OpenGraphiteAgentNode) -> String in
            let start = html.index(html.startIndex, offsetBy: node.locator.sourceRange.start)
            let end = html.index(html.startIndex, offsetBy: node.locator.sourceRange.end)
            return String(html[start..<end])
        }

        // 期待値：implied close対象は互いのdescendantにならず、browser DOM相当のparent/path/rangeと入力bytesを保持する（Then）
        #expect(listItemA.parentReference == list.reference)
        #expect(listItemB.parentReference == list.reference)
        #expect(listItemA.locator.domPath.hasSuffix("li:nth-of-type(1)"))
        #expect(listItemB.locator.domPath.hasSuffix("li:nth-of-type(2)"))
        #expect(listItemA.textContent == "A")
        #expect(listItemB.textContent == "B")
        #expect(sourceHTML(listItemA) == #"<li id="li-a">A"#)
        #expect(sourceHTML(listItemB) == #"<li id="li-b">B"#)
        #expect(listItemA.locator.contentHash != listItemB.locator.contentHash)
        #expect(listItemA.reference != listItemB.reference)
        #expect(try node("term-a").parentReference == descriptionList.reference)
        #expect(try node("definition-a").parentReference == descriptionList.reference)
        #expect(try node("term-b").parentReference == descriptionList.reference)
        #expect(try node("paragraph").parentReference == body.reference)
        #expect(try node("block").parentReference == body.reference)
        #expect(sourceHTML(try node("paragraph")) == #"<p id="paragraph">Text"#)
        #expect(try node("rt-a").parentReference == ruby.reference)
        #expect(try node("rp-a").parentReference == ruby.reference)
        #expect(try node("rt-b").parentReference == ruby.reference)
        #expect(optionGroups.count == 2)
        #expect(optionGroups.allSatisfy { $0.parentReference == select.reference })
        #expect(try node("option-a").parentReference == optionGroups[0].reference)
        #expect(try node("option-b").parentReference == optionGroups[0].reference)
        #expect(try node("option-c").parentReference == optionGroups[1].reference)
        #expect(caption.parentReference == table.reference)
        #expect(sourceHTML(caption) == #"<caption id="caption">Caption"#)
        #expect(tableSections.count == 3)
        #expect(tableSections.allSatisfy { $0.parentReference == table.reference })
        #expect(headingA.parentReference == headingB.parentReference)
        #expect(try node("row-a").parentReference == tbody.reference)
        #expect(rowB.parentReference == tbody.reference)
        #expect(cellA.parentReference == cellB.parentReference)
        #expect(cellC.parentReference == rowB.reference)
        #expect(sourceHTML(headingA) == #"<th id="heading-a">A"#)
        #expect(sourceHTML(cellA) == #"<td id="cell-a">A"#)
        #expect(validation.valid == true)
        #expect(afterHTML == html)
    }

    /// 論理名（日本語）: HTML implicit container境界とmarkup skipテスト
    /// 概要: 省略head終端、colgroup終端、comment、CDATA、EOF終端をsource-backed graphへ安全に反映します。
    @Test("implicit container境界とcomment CDATAをsource変更なしでinspectionする")
    func testImplicitContainerBoundariesAndMarkupSectionsDoNotCreatePhantomNodes() throws {
        // コンディション：head/colgroupの終了tag省略と、tag風文字列を含むcomment/CDATAを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><head><title>Title</title><!-- > <fake-comment> x <fake-tail> -->
        <main id="content"><svg><![CDATA[ <fake-cdata>vector</fake-cdata> ]]><text>Icon</text></svg><table><colgroup id="columns"><col><tbody id="rows"><tr><td id="cell">Cell</table></main></html>
        """
        try fixture.writeRawHTML(html)

        // 検証内容：graph/validationを読み、別fixtureではp/body/htmlのEOF implied closeを読む（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let htmlNode = try #require(graph.nodes.first { $0.tagName == "html" })
        let head = try #require(graph.nodes.first { $0.tagName == "head" })
        let main = try #require(graph.nodes.first { $0.tagName == "main" })
        let table = try #require(graph.nodes.first { $0.tagName == "table" })
        let colgroup = try #require(graph.nodes.first { $0.tagName == "colgroup" })
        let tbody = try #require(graph.nodes.first { $0.tagName == "tbody" })
        let cell = try #require(graph.nodes.first { $0.tagName == "td" })
        let sourceHTML = { (node: OpenGraphiteAgentNode) -> String in
            let start = html.index(html.startIndex, offsetBy: node.locator.sourceRange.start)
            let end = html.index(html.startIndex, offsetBy: node.locator.sourceRange.end)
            return String(html[start..<end])
        }
        let eofHTML = #"<!doctype html><html><body><p id="tail">Tail"#
        let eofNodes = OpenGraphiteHTMLDocument(html: eofHTML).nodes()
        let eofHTMLNode = try #require(eofNodes.first { $0.tagName == "html" })
        let eofBody = try #require(eofNodes.first { $0.tagName == "body" })
        let eofParagraph = try #require(eofNodes.first { $0.tagName == "p" })

        // 期待値：authored elementだけを返し、browser境界と同じsource range/textを保持する（Then）
        #expect(!graph.nodes.contains { $0.tagName.hasPrefix("fake-") })
        #expect(head.parentReference == htmlNode.reference)
        #expect(main.parentReference == htmlNode.reference)
        #expect(head.locator.sourceRange.end == main.locator.sourceRange.start)
        #expect(colgroup.parentReference == table.reference)
        #expect(tbody.parentReference == table.reference)
        #expect(sourceHTML(colgroup) == #"<colgroup id="columns"><col>"#)
        #expect(cell.textContent == "Cell")
        #expect(sourceHTML(cell) == #"<td id="cell">Cell"#)
        #expect(eofHTMLNode.locator.sourceRange.end == eofHTML.count)
        #expect(eofBody.locator.sourceRange.end == eofHTML.count)
        #expect(eofParagraph.locator.sourceRange.end == eofHTML.count)
        #expect(eofParagraph.textContent == "Tail")
        #expect(validation.valid == true)
        #expect(afterHTML == html)
    }

    /// 論理名（日本語）: HTML tokenizer migration境界テスト
    /// 概要: non-void slash、raw-text closing、comment close、HTML namespace CDATAをbrowser DOM境界どおり解析します。
    @Test("migration parserはHTML tokenizerのslash comment CDATA境界を保持する")
    func testMigrationParserPreservesHTMLTokenizerBoundarySemantics() throws {
        // コンディション：non-void `/>`、slash付きraw close、2種comment close、HTML/SVG CDATAを同じsourceへ用意する（Given）
        let source = #"""
        <script />const text = "<fake-script>";</script/>
        <style>/* <fake-style> */</style/>
        <div id="container"/><span id="child">Child</span></div>
        <!-- <fake-comment> --!><main id="bang" data-og-type="frame">Bang</main>
        <!--><aside id="abrupt" data-og-layout="vertical">Abrupt</aside>
        <![CDATA[<fake-cdata data-vendor="opaque">phantom</fake-cdata>]]><section id="cdata" data-og-type="text">CDATA</section>
        <svg><![CDATA[<fake-svg>vector</fake-svg>]]><text id="svg-text">Icon</text></svg>
        <svg><script/></svg><main id="foreign-script-real" data-og-type="frame">SVG script boundary</main>
        <svg><style/></svg><article id="foreign-style-real" data-og-layout="horizontal">SVG style boundary</article>
        <math><mrow/></math><footer id="foreign-math-real" data-og-type="text">Math boundary</footer>
        """#
        let document = OpenGraphiteHTMLDocument(html: source)

        // 検証内容：source-backed tag treeとdirect migration candidateを取得する（When）
        let tags = document.parsedTags()
        let migration = document.migratingLegacyWebContract(path: "index.html")
        let migratedTags = OpenGraphiteHTMLDocument(html: migration.source).parsedTags()
        let container = try #require(tags.first { $0.attributeValue(named: "id") == "container" })
        let child = try #require(tags.first { $0.attributeValue(named: "id") == "child" })
        let foreignScript = try #require(tags.first { $0.tagName == "script" && $0.selfClosing })
        let foreignStyle = try #require(tags.first { $0.tagName == "style" && $0.selfClosing })
        let foreignMathRow = try #require(tags.first { $0.tagName == "mrow" })

        // 期待値：raw/comment/HTML CDATA内の見かけ上tagを採用せず、real nodeだけをlossless変換する（Then）
        #expect(!tags.contains { $0.tagName.hasPrefix("fake-") })
        #expect(container.lexicalSelfClosing)
        #expect(!container.selfClosing)
        #expect(child.depth == container.depth + 1)
        #expect(foreignScript.lexicalSelfClosing)
        #expect(foreignStyle.lexicalSelfClosing)
        #expect(foreignMathRow.lexicalSelfClosing && foreignMathRow.selfClosing)
        #expect(tags.contains { $0.attributeValue(named: "id") == "svg-text" })
        #expect(migration.diagnostics.isEmpty)
        #expect(migration.source.contains(#"<script />const text = "<fake-script>";</script/>"#))
        #expect(migration.source.contains(#"<style>/* <fake-style> */</style/>"#))
        #expect(migration.source.contains(#"<![CDATA[<fake-cdata data-vendor="opaque">phantom</fake-cdata>]]>"#))
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "bang" }?.attributeValue(named: "class") == "og-migrated-v1-type-frame")
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "abrupt" }?.attributeValue(named: "class") == "og-migrated-v1-layout-vertical")
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "cdata" }?.attributeValue(named: "class") == "og-migrated-v1-type-text")
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "foreign-script-real" }?.attributeValue(named: "class") == "og-migrated-v1-type-frame")
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "foreign-style-real" }?.attributeValue(named: "class") == "og-migrated-v1-layout-horizontal")
        #expect(migratedTags.first { $0.attributeValue(named: "id") == "foreign-math-real" }?.attributeValue(named: "class") == "og-migrated-v1-type-text")
    }

    /// 論理名（日本語）: HTML DOM textContent抽出テスト
    /// 概要: comment/markupを除外しつつdata、RCDATA、raw text、CDATAの文字解釈を区別します。
    @Test("source textContentはcommentを除外してraw RCDATA entity semanticsを保つ")
    func testSourceTextContentUsesHTMLTextStateSemantics() throws {
        // コンディション：comment、基本entity、RCDATA、raw text、SVG CDATAを同じ通常要素内へ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><head><title>Title &lt;literal&gt; &#84;</title></head><body>
        <div id="text">A<!-- x > y -->B &amp; &lt; &gt; &quot; &apos; &nbsp; &#65; &#x42;
        <textarea>R &lt;fake-textarea&gt; &#67;</textarea>
        <script>raw &amp; <fake-script></script>
        <style>style &amp; <fake-style></style>
        <noscript>fallback &amp; <fake-noscript></noscript>
        <svg><![CDATA[cdata &amp; <fake-cdata>]]></svg></div>
        </body></html>
        """
        try fixture.writeRawHTML(html)

        // 検証内容：source graphを読み、保存bytesを再取得する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let title = try #require(graph.nodes.first { $0.tagName == "title" })
        let text = try #require(graph.nodes.first { $0.locator.selector == "#text" })
        let textarea = try #require(graph.nodes.first { $0.tagName == "textarea" })
        let script = try #require(graph.nodes.first { $0.tagName == "script" })
        let noscript = try #require(graph.nodes.first { $0.tagName == "noscript" })
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ordinary/RCDATAだけentityをdecodeし、raw/CDATA本文はliteralのままsource順へ連結する（Then）
        #expect(!graph.nodes.contains { $0.tagName.hasPrefix("fake-") })
        #expect(title.textContent == "Title <literal> T")
        #expect(textarea.textContent == "R <fake-textarea> C")
        #expect(script.textContent == "raw &amp; <fake-script>")
        #expect(noscript.textContent == "fallback &amp; <fake-noscript>")
        #expect(text.textContent == "AB & < > \" '   A B R <fake-textarea> C raw &amp; <fake-script> style &amp; <fake-style> fallback &amp; <fake-noscript> cdata &amp; <fake-cdata>")
        #expect(afterHTML == html)
    }

    /// 論理名（日本語）: Optional end tag subtree adoptionテスト
    /// 概要: siblingとして解釈した省略liへidentityだけを追加し、終了tagを補完せず冪等に適用します。
    @Test("optional end tag subtree adoptionは開始tagだけを最小変更する")
    func testOptionalEndTagSubtreeAdoptionPreservesOmittedClosings() throws {
        // コンディション：li終了tagを省略した標準listをproject resourceへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = #"<!doctype html><html><body><ul id="items"><li>A<li>B</ul></body></html>"#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：list subtreeをdry-run、snapshot apply、再dry-run/applyする（When）
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#items",
            scope: .subtree
        )
        let afterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .subtree,
            apply: true
        )
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let stableList = try #require(applied.graph.nodes.first { $0.tagName == "ul" })
        let listItems = applied.graph.nodes.filter { $0.tagName == "li" }
        let idempotentDryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: stableList.reference,
            scope: .subtree
        )
        let idempotent = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: idempotentDryRun.targetReference,
            scope: .subtree,
            apply: true
        )

        // 期待値：dry-runは無書込で、3つの開始tagだけをadoptし省略終了tagを生成しない（Then）
        #expect(afterDryRun == originalHTML)
        #expect(dryRun.diff?.unifiedDiff.contains("data-og-internal-id") == true)
        #expect(applied.applied == true)
        #expect(applied.adoptedReferences.count == 3)
        #expect(listItems.count == 2)
        #expect(listItems.allSatisfy { $0.parentReference == stableList.reference })
        #expect(listItems.map(\.textContent) == ["A", "B"])
        #expect(listItems[0].locator.domPath.hasSuffix("li:nth-of-type(1)"))
        #expect(listItems[1].locator.domPath.hasSuffix("li:nth-of-type(2)"))
        #expect(!appliedHTML.contains("</li>"))
        #expect(appliedHTML.components(separatedBy: "data-og-internal-id").count - 1 == 3)
        #expect(idempotentDryRun.changed == false)
        #expect(idempotent.changed == false)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == appliedHTML)
    }

    /// 論理名（日本語）: 既存annotation重複診断テスト
    /// 概要: missing annotationは許可しつつ、存在するinternal IDの重複はstable referenceとして扱わず診断することを確認します。
    @Test("optional annotationでも既存internal ID重複は診断する")
    func testOptionalAnnotationsStillDiagnoseDuplicateInternalIDs() throws {
        // コンディション：whitespace差だけの重複display/internal IDと多数の未注釈要素を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeRawHTML(
            "<!doctype html><html><body><main><p data-og-internal-id=\"dup\">A</p><p data-og-internal-id=\" dup \">B</p><aside data-og-id=\"label\">C</aside><aside data-og-id=\" label \">D</aside><section>Free</section></main></body></html>"
        )

        // 検証内容：validationとgraph inspectionを実行する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let result = try fixture.core.validateHTML(at: fixture.htmlURL)

        // 期待値：normalized duplicateだけがerrorで、重複nodeはsessionへ降格し誤target selectorを公開しない（Then）
        #expect(result.valid == false)
        #expect(result.diagnostics.contains { $0.code == "duplicate-data-og-internal-id" && $0.severity == .error })
        #expect(result.diagnostics.contains { $0.code == "duplicate-data-og-id" && $0.severity == .error })
        #expect(!result.diagnostics.contains { $0.code.hasPrefix("missing-data-og-") })
        #expect(graph.nodes.filter { $0.internalID == "dup" }.allSatisfy { $0.referenceStability == .session })
        #expect(graph.nodes.filter { $0.internalID == "dup" }.allSatisfy { $0.locator.selector == nil })
        #expect(graph.nodes.filter { $0.id == "label" }.allSatisfy { $0.locator.selector == nil })
    }

    /// 論理名（日本語）: HTML attribute name case-insensitive inspectionテスト
    /// 概要: authored caseを保持したままHTML属性名をcase-insensitiveかつduplicate first-winsで解釈します。
    @Test("HTML属性名はcase-insensitiveかつ同一tag duplicate first-winsでinspectionする")
    func testHTMLAttributeNamesUseCaseInsensitiveFirstWinsSemantics() throws {
        // コンディション：uppercase standard/OG/runtime属性、case違いduplicate属性、normalized duplicate identityを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><body>
        <main ID="Primary" id="ignored" CLASS="unique-shell" class="ignored" DATA-OG-ID="Display" DATA-OG-INTERNAL-ID="Stable">Main</main>
        <section DATA-OG-INTERNAL-ID="dup">A</section><section data-og-internal-id=" dup ">B</section>
        <aside DATA-OG-RUNTIME-TEST="persisted">Runtime</aside>
        </body></html>
        """
        try fixture.writeRawHTML(html)
        var runtimeContract = OpenGraphiteContract.builtIn
        runtimeContract.runtimeAttributes = ["data-og-runtime-test"]
        let runtimeCore = OpenGraphiteAgentCore(contract: runtimeContract)

        // 検証内容：graphとruntime-aware validationを実行する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try runtimeCore.validateHTML(at: fixture.htmlURL)
        let main = try #require(graph.nodes.first { $0.tagName == "main" })

        // 期待値：first-authored値がsemantic dictionary/referenceへ入り、case違いも重複/runtime診断される（Then）
        #expect(main.locator.selector == "#Primary")
        #expect(main.id == "Display")
        #expect(main.internalID == "Stable")
        #expect(main.annotationStatus == .complete)
        #expect(main.referenceStability == .stable)
        #expect(main.attributes["id"] == "Primary")
        #expect(main.attributes["class"] == "unique-shell")
        #expect(main.attributes["data-og-id"] == "Display")
        #expect(main.attributes["data-og-internal-id"] == "Stable")
        #expect(graph.nodes.filter { $0.internalID == "dup" }.allSatisfy { $0.referenceStability == .session })
        #expect(validation.diagnostics.contains { $0.code == "duplicate-data-og-internal-id" })
        #expect(validation.diagnostics.contains {
            $0.code == "runtime-attribute-persisted" && $0.message.contains("DATA-OG-RUNTIME-TEST")
        })
    }

    /// 論理名（日本語）: HTML attribute character reference inspectionテスト
    /// 概要: numeric/basic named referenceをDOM semantic値へ復号し、identity判定と部分編集でauthored entity表記を保持します。
    @Test("HTML属性character referenceをsemanticに解釈してauthored表記を保持する")
    func testHTMLAttributeCharacterReferencesUseDOMSemanticsWithoutRewritingSource() throws {
        // コンディション：numeric referenceを使う標準/OG identity、semantic duplicate、未編集のnamed entity属性を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><body>
        <main id="hero&#32;card" class="hero&#45;shell" data-og-id="display&#45;node" data-og-internal-id="stable&#45;node" title="Keep &#169; &copy;">Body</main>
        <section data-og-id="dup&#45;display" data-og-internal-id="dup&#45;internal">A</section>
        <aside data-og-id="dup-display" data-og-internal-id="dup-internal">B</aside>
        </body></html>
        """
        try fixture.writeRawHTML(html)

        // 検証内容：graph/validationを実行し、対象display IDだけを変更して開始tagを再直列化する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let mutation = OpenGraphiteHTMLDocument(html: html).renamingNodeID(
            value: "renamed",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let main = try #require(graph.nodes.first { $0.tagName == "main" })

        // 期待値：browser相当のsemantic値でinspection/duplicate判定し、変更しない属性のsource entity表記は正規化しない（Then）
        #expect(main.locator.selector == #"[id="hero card"]"#)
        #expect(main.attributes["id"] == "hero card")
        #expect(main.attributes["class"] == "hero-shell")
        #expect(main.id == "display-node")
        #expect(main.internalID == "stable-node")
        #expect(main.referenceStability == .stable)
        #expect(graph.nodes.filter { $0.id == "dup-display" }.allSatisfy { $0.referenceStability == .session })
        #expect(graph.nodes.filter { $0.internalID == "dup-internal" }.allSatisfy { $0.locator.selector == nil })
        #expect(validation.diagnostics.contains { $0.code == "duplicate-data-og-id" })
        #expect(validation.diagnostics.contains { $0.code == "duplicate-data-og-internal-id" })
        #expect(!validation.diagnostics.contains { $0.code.hasPrefix("unresolved-data-og-") })
        #expect(mutation.diagnostics.isEmpty)
        #expect(mutation.html.contains(#"id="hero&#32;card""#))
        #expect(mutation.html.contains(#"class="hero&#45;shell""#))
        #expect(mutation.html.contains(#"data-og-internal-id="stable&#45;node""#))
        #expect(mutation.html.contains(#"title="Keep &#169; &copy;""#))
        #expect(!mutation.html.contains("&amp;copy;"))
    }

    /// 論理名（日本語）: 既知amp identity character referenceテスト
    /// 概要: authored `&amp;`を復号したliteral ampersandを未解決referenceと誤認せず、参照とadoptionに利用します。
    @Test("既知amp referenceを含むidentityはstable参照とsafe selectorを維持する")
    func testKnownAmpCharacterReferencesRemainStableAndAdoptable() throws {
        // コンディション：standard/OG identityのすべてに既知`&amp;`を含むnodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = #"<!doctype html><html><body><main id="AT&amp;T" data-og-id="display&amp;T" data-og-internal-id="node&amp;T">Body</main></body></html>"#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：graph/validationを取得し、stable referenceでdry-runとno-op applyを行う（When）
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let main = try #require(graph.nodes.first { $0.tagName == "main" })
        let internalAnnotationNode = try #require(
            OpenGraphiteHTMLDocument(
                html: #"<main data-og-internal-id="node&amp;T">Body</main>"#
            ).nodes().first
        )
        let displayAnnotationNode = try #require(
            OpenGraphiteHTMLDocument(
                html: #"<main data-og-id="display&amp;T">Body</main>"#
            ).nodes().first
        )
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: main.reference
        )
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            apply: true
        )
        let afterAdoption = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：known entityだけをsemantic復号し、selector/reference/validation/adoptionで安全に再利用する（Then）
        #expect(main.attributes["id"] == "AT&T")
        #expect(main.id == "display&T")
        #expect(main.internalID == "node&T")
        #expect(main.referenceStability == .stable)
        #expect(main.reference.hasSuffix(":node&T"))
        #expect(main.locator.selector == #"[id="AT&T"]"#)
        #expect(internalAnnotationNode.referenceStability == .stable)
        #expect(internalAnnotationNode.locator.selector == #"[data-og-internal-id="node&T"]"#)
        #expect(displayAnnotationNode.referenceStability == .session)
        #expect(displayAnnotationNode.locator.selector == #"[data-og-id="display&T"]"#)
        #expect(validation.valid)
        #expect(!validation.diagnostics.contains { $0.code.hasPrefix("unresolved-data-og-") })
        #expect(dryRun.changed == false)
        #expect(dryRun.diff == nil)
        #expect(dryRun.diagnostics.isEmpty)
        #expect(dryRun.adoptedReferences.contains(main.reference))
        #expect(applied.changed == false)
        #expect(applied.applied == false)
        #expect(applied.diagnostics.isEmpty)
        #expect(afterAdoption == originalHTML)
    }

    /// 論理名（日本語）: Safe authored selector降格テスト
    /// 概要: CSS文字列へ安全に直書きできないcontrol文字と特殊custom tagをselectorにせずDOM pathへ降格します。
    @Test("CSS selectorへ安全に表現できないauthored locatorはDOM pathへ降格する")
    func testUnsafeAuthoredSelectorsFallBackToDOMPaths() throws {
        // コンディション：numeric referenceで改行を含むstandard IDと、CSS identifier特殊文字を含む一意custom tagを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let html = """
        <!doctype html><html><body>
        <main id="line&#10;break">Line</main>
        <x.card class="shared">Card</x.card><div class="shared">Peer</div>
        <safe-card>Safe</safe-card>
        </body></html>
        """
        try fixture.writeRawHTML(html)

        // 検証内容：source graphのlocatorを生成する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let lineBreakID = try #require(graph.nodes.first { $0.tagName == "main" })
        let specialCustomTag = try #require(graph.nodes.first { $0.tagName == "x.card" })
        let safeCustomTag = try #require(graph.nodes.first { $0.tagName == "safe-card" })

        // 期待値：invalid selectorは公開せずsource DOM pathを維持し、安全なcustom tagだけをselectorとして返す（Then）
        #expect(lineBreakID.attributes["id"] == "line\nbreak")
        #expect(lineBreakID.locator.selector == nil)
        #expect(!lineBreakID.locator.domPath.isEmpty)
        #expect(specialCustomTag.locator.selector == nil)
        #expect(!specialCustomTag.locator.domPath.isEmpty)
        #expect(safeCustomTag.locator.selector == "safe-card")
    }

    /// 論理名（日本語）: HTML開始tag lossless部分編集テスト
    /// 概要: 属性とinline styleの対象rangeだけを変更し、unknown属性、entity、quote、trivia、comment、self-closing表記を保持します。
    @Test("HTML属性とinline styleをraw source最小差分で部分編集する")
    func testHTMLAttributeAndInlineStyleMutationsPreserveUnrelatedRawSource() throws {
        // コンディション：slash入りunquoted属性、bare属性、case違いduplicate、entity、quote、comment、data URLを同じ開始tagへ用意する（Given）
        let originalHTML = #"<main  data-vendor=/a/b disabled DATA-OG-INTERNAL-ID = 'stable-node' ROLE = 'old' hidden = 'hidden' data-og-locked='true' DATA-OG-LOCKED = "false" title="Keep &#169; &copy;" style = 'background-image:url("data:image/svg+xml;utf8,<svg></svg>"); /* keep ; */ color : red'>Body</main>"#
        let document = OpenGraphiteHTMLDocument(html: originalHTML)

        // 検証内容：single/double quote属性を更新し、case違いduplicateを削除し、inline declarationを追加・更新・削除する（When）
        let roleMutation = document.settingAttribute(
            name: "role",
            value: "next&role",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let hiddenMutation = document.settingAttribute(
            name: "hidden",
            value: "until-found",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let lockedRemoval = document.removingAttribute(
            name: "data-og-locked",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let styleAddition = document.settingCSSVariable(
            "gap",
            value: "12px",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let styleUpdate = OpenGraphiteHTMLDocument(html: styleAddition.html).settingCSSVariable(
            "gap",
            value: "calc(10px + 2px)",
            forNodeID: "stable-node",
            contract: .builtIn
        )
        let styleRemoval = OpenGraphiteHTMLDocument(html: styleAddition.html).settingCSSVariable(
            "gap",
            value: "",
            forNodeID: "stable-node",
            contract: .builtIn
        )

        // 期待値：対象value/token以外のbytesは変わらず、duplicate removeだけは同名case-insensitive属性を全件除去する（Then）
        #expect(
            roleMutation.html == originalHTML.replacingOccurrences(
                of: "ROLE = 'old'",
                with: "ROLE = 'next&amp;role'"
            )
        )
        #expect(
            hiddenMutation.html == originalHTML.replacingOccurrences(
                of: "hidden = 'hidden'",
                with: "hidden = 'until-found'"
            )
        )
        let expectedLockedRemoval = originalHTML
            .replacingOccurrences(of: " data-og-locked='true'", with: "")
            .replacingOccurrences(of: " DATA-OG-LOCKED = \"false\"", with: "")
        #expect(lockedRemoval.html == expectedLockedRemoval)
        let expectedStyleAddition = originalHTML.replacingOccurrences(
            of: #"style = 'background-image"#,
            with: #"style = 'gap:12px;background-image"#
        )
        #expect(styleAddition.html == expectedStyleAddition)
        #expect(
            styleUpdate.html == expectedStyleAddition.replacingOccurrences(
                of: "gap:12px",
                with: "gap:calc(10px + 2px)"
            )
        )
        #expect(styleRemoval.html == originalHTML)
        #expect(styleAddition.html.contains(#"data-vendor=/a/b disabled"#))
        #expect(styleAddition.html.contains(#"title="Keep &#169; &copy;""#))
        #expect(styleAddition.html.contains(#"url("data:image/svg+xml;utf8,<svg></svg>")"#))
        #expect(styleAddition.html.contains("/* keep ; */"))
    }

    /// 論理名（日本語）: Unquoted属性とself-closing開始tag保持テスト
    /// 概要: safeなunquoted targetはquote化せず、spaceを含むstyleだけをquote化し、self-closing suffixを保持します。
    @Test("unquoted属性とself-closing spacingを部分編集時に保持する")
    func testUnquotedAndSelfClosingAttributeMutationsPreserveAuthoredForm() throws {
        // コンディション：unquoted target/styleと、slash入りunknown属性・bare属性・spaced self-closing suffixを用意する（Given）
        let unquotedHTML = #"<main data-og-internal-id=stable data-vendor=/a/b role=old style=color:red;></main>"#
        let selfClosingHTML = #"<widget-card data-og-internal-id=widget data-vendor=/a/b disabled />"#

        // 検証内容：safeなrole、spaceを含むCSS値、self-closing custom elementの新規属性をそれぞれ更新する（When）
        let roleMutation = OpenGraphiteHTMLDocument(html: unquotedHTML).settingAttribute(
            name: "role",
            value: "new-role",
            forNodeID: "stable",
            contract: .builtIn
        )
        let styleMutation = OpenGraphiteHTMLDocument(html: unquotedHTML).settingCSSVariable(
            "color",
            value: "rgb(1, 2, 3)",
            forNodeID: "stable",
            contract: .builtIn
        )
        let selfClosingMutation = OpenGraphiteHTMLDocument(html: selfClosingHTML).settingAttribute(
            name: "role",
            value: "card",
            forNodeID: "widget",
            contract: .builtIn
        )

        // 期待値：unquoted safe値とunknown bytesは維持し、必要なstyle quoteと新規属性だけが追加される（Then）
        #expect(
            roleMutation.html
                == #"<main data-og-internal-id=stable data-vendor=/a/b role=new-role style=color:red;></main>"#
        )
        #expect(
            styleMutation.html
                == #"<main data-og-internal-id=stable data-vendor=/a/b role=old style="color:rgb(1, 2, 3);"></main>"#
        )
        #expect(
            selfClosingMutation.html
                == #"<widget-card data-og-internal-id=widget data-vendor=/a/b disabled role="card" />"#
        )
    }

    /// 論理名（日本語）: Trailing slash attribute value保持テスト
    /// 概要: start tag末尾のslashをunquoted値とself-closing markerで区別し、adopt後の部分編集でも値を保持します。
    @Test("start tag末尾slashのattribute値をadoptと部分編集で保持する")
    func testTrailingSlashAttributeValuesRemainDistinctFromSelfClosingMarkers() throws {
        // コンディション：slashで終わるURL値とslash単独値を持つ未注釈subtreeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><a href=https://example.test/>Link</a><main data-vendor=/ >Body</main></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let beforeGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let body = try #require(beforeGraph.nodes.first { $0.tagName == "body" })
        let beforeAnchor = try #require(beforeGraph.nodes.first { $0.tagName == "a" })
        let beforeMain = try #require(beforeGraph.nodes.first { $0.tagName == "main" })

        // 検証内容：subtreeを明示adoptし、stable nodeへattributeとinline styleをそれぞれ部分編集する（When）
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: body.reference,
            scope: .subtree
        )
        let afterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .subtree,
            apply: true
        )
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let anchor = try #require(applied.graph.nodes.first { $0.tagName == "a" })
        let main = try #require(applied.graph.nodes.first { $0.tagName == "main" })
        let attributeMutation = OpenGraphiteHTMLDocument(html: appliedHTML).settingAttribute(
            name: "role",
            value: "link",
            forNodeID: anchor.internalID,
            contract: .builtIn
        )
        let styleMutation = OpenGraphiteHTMLDocument(html: appliedHTML).settingCSSVariable(
            "color",
            value: "blue",
            forNodeID: main.internalID,
            contract: .builtIn
        )

        // 期待値：slashはDOM semantic値とraw byteの双方で残り、anchor内容/終了tagとdry-run無書込も維持される（Then）
        #expect(beforeAnchor.attributes["href"] == "https://example.test/")
        #expect(beforeAnchor.textContent == "Link")
        #expect(beforeMain.attributes["data-vendor"] == "/")
        #expect(anchor.attributes["href"] == "https://example.test/")
        #expect(main.attributes["data-vendor"] == "/")
        #expect(afterDryRun == originalHTML)
        #expect(applied.applied)
        #expect(appliedHTML.contains("href=https://example.test/ data-og-"))
        #expect(appliedHTML.contains(">Link</a>"))
        #expect(appliedHTML.contains("data-vendor=/ data-og-"))
        #expect(attributeMutation.diagnostics.isEmpty)
        #expect(attributeMutation.html.contains("href=https://example.test/ data-og-"))
        #expect(styleMutation.diagnostics.isEmpty)
        #expect(styleMutation.html.contains("data-vendor=/ data-og-"))
        #expect(styleMutation.html.contains("style=\"color:blue;\" >"))
    }

    /// 論理名（日本語）: Entity encoded inline CSS quote保持テスト
    /// 概要: HTML entityで表したCSS quoteとbackslash escape内のsemicolonを宣言境界にせず、対象宣言だけを更新します。
    @Test("entity encoded CSS quoteとbackslash escapeを保持してinline styleを部分編集する")
    func testEntityEncodedInlineCSSQuotesPreserveDeclarationBoundaries() throws {
        // コンディション：double-quoted style内へnamed/numeric quote、escaped quote、quoted URL、二重escapeした非quote entityを用意する（Given）
        let originalHTML = #"<main data-og-internal-id="stable" style="content:&quot;a\&quot;;b&quot;; background-image:url(&quot;c\&quot;;d&quot;); --single:&apos;e;f&apos;; --decimal:&#34;g;h&#34;; --hex:&#x27;i;j&#x27;; --literal:&amp;quot;; --unknown:&vendor &quot;k;l&quot;; color:red">Body</main>"#
        let document = OpenGraphiteHTMLDocument(html: originalHTML)

        // 検証内容：encoded quote宣言より後ろの既存propertyを更新し、別propertyを追加してから削除する（When）
        let colorMutation = document.settingCSSVariable(
            "color",
            value: "blue",
            forNodeID: "stable",
            contract: .builtIn
        )
        let addition = document.settingCSSVariable(
            "gap",
            value: "12px",
            forNodeID: "stable",
            contract: .builtIn
        )
        let removal = OpenGraphiteHTMLDocument(html: addition.html).settingCSSVariable(
            "gap",
            value: "",
            forNodeID: "stable",
            contract: .builtIn
        )

        // 期待値：quote内semicolonを越えて既存colorだけを更新し、追加削除はentity表記を含む原文へexactに戻る（Then）
        #expect(colorMutation.html == originalHTML.replacingOccurrences(of: "color:red", with: "color:blue"))
        #expect(colorMutation.html.components(separatedBy: "color:").count - 1 == 1)
        #expect(colorMutation.html.contains(#"content:&quot;a\&quot;;b&quot;"#))
        #expect(colorMutation.html.contains(#"url(&quot;c\&quot;;d&quot;)"#))
        #expect(colorMutation.html.contains(#"--literal:&amp;quot;"#))
        #expect(removal.html == originalHTML)
    }

    /// 論理名（日本語）: Inline CSS semantic token source mappingテスト
    /// 概要: HTML entityとCSS escape由来のdelimiter、comment、simple block、property、priorityをraw range保持で解釈します。
    @Test("HTML entityとCSS escapeをsemantic inline CSS tokenとして部分編集する")
    func testInlineCSSSemanticTokensPreserveRawSourceRanges() throws {
        // コンディション：entity由来の構文token、nested simple block、escaped property、複数形式のimportantを用意する（Given）
        let entityHTML = #"<main data-og-internal-id="entity" style="content&#58;&quot;a&#92;&quot;;b&quot;&#59;background-image:url&#40;&quot;c;d&quot;&#41;&#59;&#47;&#42;keep &#42;&#92;&#47; ; --phantom:bad; &#42;&#47;--list:&#91;a;b&#93;&#59;--map:&#123;x:y;z:w&#125;&#59;color:red&#59;background:blue">Body</main>"#
        let escapedDelimiterHTML = #"<main data-og-internal-id="escaped-delimiter" style="--raw:before&#92;&#59;after&#59;color:red">Body</main>"#
        let blockHTML = #"<main data-og-internal-id="block" style="--theme:{color:red; background:blue}; color:black">Body</main>"#
        let propertyHTML = #"<main data-og-internal-id="property" style="&#32;co\lor&#32;&#58;&#32;red&#32;&#59;">Body</main>"#
        let entityPropertyHTML = #"<main data-og-internal-id="entity-property" style="&#32;c&#111;lor&#32;&#58;&#32;red&#32;&#59;">Body</main>"#
        let priorityCases = [
            #"<main data-og-internal-id="priority" style="color:red&#33;important;color:blue">Body</main>"#,
            #"<main data-og-internal-id="priority" style="color:red!&#105;mportant">Body</main>"#,
            #"<main data-og-internal-id="priority" style="color:red ! important">Body</main>"#,
            #"<main data-og-internal-id="priority" style="color:red !/**/important">Body</main>"#,
            #"<main data-og-internal-id="priority" style="color:red !\69mportant">Body</main>"#
        ]

        // 検証内容：encoded構文より後ろのproperty更新/削除と一時追加、escaped property/priority更新を行う（When）
        let entityColor = OpenGraphiteHTMLDocument(html: entityHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "entity", contract: .builtIn
        )
        let entityValuesBefore = OpenGraphiteHTMLDocument(html: entityHTML).nodes().first?.cssVariables
        let entityBackgroundRemoval = OpenGraphiteHTMLDocument(html: entityHTML).settingCSSVariable(
            "background", value: "", forNodeID: "entity", contract: .builtIn
        )
        let entityAddition = OpenGraphiteHTMLDocument(html: entityHTML).settingCSSVariable(
            "gap", value: "12px", forNodeID: "entity", contract: .builtIn
        )
        let entityRestored = OpenGraphiteHTMLDocument(html: entityAddition.html).settingCSSVariable(
            "gap", value: "", forNodeID: "entity", contract: .builtIn
        )
        let escapedDelimiterColor = OpenGraphiteHTMLDocument(html: escapedDelimiterHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "escaped-delimiter", contract: .builtIn
        )
        let blockColor = OpenGraphiteHTMLDocument(html: blockHTML).settingCSSVariable(
            "color", value: "white", forNodeID: "block", contract: .builtIn
        )
        let blockRemoval = OpenGraphiteHTMLDocument(html: blockHTML).settingCSSVariable(
            "color", value: "", forNodeID: "block", contract: .builtIn
        )
        let blockAddition = OpenGraphiteHTMLDocument(html: blockHTML).settingCSSVariable(
            "gap", value: "12px", forNodeID: "block", contract: .builtIn
        )
        let blockRestored = OpenGraphiteHTMLDocument(html: blockAddition.html).settingCSSVariable(
            "gap", value: "", forNodeID: "block", contract: .builtIn
        )
        let propertyMutation = OpenGraphiteHTMLDocument(html: propertyHTML).settingCSSVariable(
            "color", value: "blue", forNodeID: "property", contract: .builtIn
        )
        let entityPropertyMutation = OpenGraphiteHTMLDocument(html: entityPropertyHTML).settingCSSVariable(
            "color", value: "blue", forNodeID: "entity-property", contract: .builtIn
        )
        let priorityColorsBefore = priorityCases.map {
            OpenGraphiteHTMLDocument(html: $0).nodes().first?.cssVariables["color"]
        }
        let priorityMutations = priorityCases.map {
            OpenGraphiteHTMLDocument(html: $0).settingCSSVariable(
                "color", value: "green", forNodeID: "priority", contract: .builtIn
            )
        }
        let priorityColorsAfter = priorityMutations.map {
            OpenGraphiteHTMLDocument(html: $0.html).nodes().first?.cssVariables["color"]
        }
        let priorityRemoval = OpenGraphiteHTMLDocument(html: priorityCases[0]).settingCSSVariable(
            "color", value: "", forNodeID: "priority", contract: .builtIn
        )
        let escapedBang = #"<main data-og-internal-id="escaped" style="--flag:\!important;color:red">Body</main>"#
        let escapedBangColor = OpenGraphiteHTMLDocument(html: escapedBang).settingCSSVariable(
            "color", value: "green", forNodeID: "escaped", contract: .builtIn
        )

        // 期待値：target value/rangeだけが変わり、block内semicolon、raw entity/escape/triviaとpriority cascadeを保持する（Then）
        #expect(entityColor.html == entityHTML.replacingOccurrences(of: "color:red", with: "color:green"))
        #expect(entityValuesBefore?["--phantom"] == nil)
        #expect(OpenGraphiteHTMLDocument(html: entityColor.html).nodes().first?.cssVariables["color"] == "green")
        #expect(entityBackgroundRemoval.html == entityHTML.replacingOccurrences(of: "background:blue", with: ""))
        #expect(entityRestored.html == entityHTML)
        #expect(
            escapedDelimiterColor.html
                == escapedDelimiterHTML.replacingOccurrences(of: "color:red", with: "color:green")
        )
        #expect(blockColor.html == blockHTML.replacingOccurrences(of: "color:black", with: "color:white"))
        #expect(blockRemoval.html == blockHTML.replacingOccurrences(of: "color:black", with: ""))
        #expect(blockRestored.html == blockHTML)
        #expect(propertyMutation.html == propertyHTML.replacingOccurrences(of: "red", with: "blue"))
        #expect(!propertyMutation.html.contains("color:blue"))
        #expect(entityPropertyMutation.html == entityPropertyHTML.replacingOccurrences(of: "red", with: "blue"))
        #expect(!entityPropertyMutation.html.contains("color:blue"))
        #expect(priorityColorsBefore == Array(repeating: "red", count: priorityCases.count))
        #expect(priorityColorsAfter == Array(repeating: "green", count: priorityCases.count))
        for (source, mutation) in zip(priorityCases, priorityMutations) {
            #expect(mutation.html == source.replacingOccurrences(of: "red", with: "green"))
            #expect(mutation.html.components(separatedBy: "color:").count - 1 <= 2)
        }
        #expect(OpenGraphiteHTMLDocument(html: priorityRemoval.html).nodes().first?.cssVariables["color"] == nil)
        #expect(!priorityRemoval.html.contains("color:"))
        #expect(escapedBangColor.html == escapedBang.replacingOccurrences(of: "color:red", with: "color:green"))
    }

    /// 論理名（日本語）: Named reference inline CSS semantic tokenテスト
    /// 概要: 標準named character reference由来のCSS delimiter、block、comment、escape、priority、triviaをraw range付きで編集します。
    @Test("標準named referenceをsemantic inline CSS tokenとして部分編集する")
    func testNamedCharacterReferencesDriveInlineCSSSemantics() throws {
        // コンディション：named referenceでCSS構文とtriviaを表したinline style群を用意する（Given）
        let simpleHTML = #"<main data-og-internal-id="named" style="color&colon;red&semi;background:blue">Body</main>"#
        let grammarHTML = #"<main data-og-internal-id="named-grammar" style="content&colon;&quot;a&semi;b&quot;&semi;background-image&colon;url&lpar;&quot;c;d&quot;&rpar;&semi;&sol;&ast;keep&semi;&ast;&sol;--list&colon;&lsqb;a&semi;b&rsqb;&semi;--map&colon;&lcub;x:y&semi;z:w&rcub;&semi;--raw&colon;before&bsol;&semi;after&semi;color:red">Body</main>"#
        let priorityHTML = #"<main data-og-internal-id="named-priority" style="color:red&excl;important;color:blue">Body</main>"#
        let triviaHTML = #"<main data-og-internal-id="named-trivia" style="&Tab;color&Tab;&colon;&Tab;red&NewLine;&semi;">Body</main>"#

        // 検証内容：対象colorを更新/削除し、別propertyを追加後削除してcomputed winnerを再inspectionする（When）
        let simpleBefore = OpenGraphiteHTMLDocument(html: simpleHTML).nodes().first?.cssVariables["color"]
        let simpleUpdate = OpenGraphiteHTMLDocument(html: simpleHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "named", contract: .builtIn
        )
        let simpleRemoval = OpenGraphiteHTMLDocument(html: simpleHTML).settingCSSVariable(
            "color", value: "", forNodeID: "named", contract: .builtIn
        )
        let simpleAddition = OpenGraphiteHTMLDocument(html: simpleHTML).settingCSSVariable(
            "gap", value: "12px", forNodeID: "named", contract: .builtIn
        )
        let simpleRestored = OpenGraphiteHTMLDocument(html: simpleAddition.html).settingCSSVariable(
            "gap", value: "", forNodeID: "named", contract: .builtIn
        )
        let grammarUpdate = OpenGraphiteHTMLDocument(html: grammarHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "named-grammar", contract: .builtIn
        )
        let priorityBefore = OpenGraphiteHTMLDocument(html: priorityHTML).nodes().first?.cssVariables["color"]
        let priorityUpdate = OpenGraphiteHTMLDocument(html: priorityHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "named-priority", contract: .builtIn
        )
        let priorityAfter = OpenGraphiteHTMLDocument(html: priorityUpdate.html).nodes().first?.cssVariables["color"]
        let triviaUpdate = OpenGraphiteHTMLDocument(html: triviaHTML).settingCSSVariable(
            "color", value: "green", forNodeID: "named-trivia", contract: .builtIn
        )

        // 期待値：named syntaxをbrowser同等に解釈し、target raw range以外とnamed表記をbyte相当で保持する（Then）
        #expect(simpleBefore == "red")
        #expect(simpleUpdate.html == simpleHTML.replacingOccurrences(of: "red", with: "green"))
        #expect(
            simpleRemoval.html
                == simpleHTML.replacingOccurrences(of: "color&colon;red&semi;", with: "")
        )
        #expect(simpleRestored.html == simpleHTML)
        #expect(grammarUpdate.html == grammarHTML.replacingOccurrences(of: "color:red", with: "color:green"))
        #expect(priorityBefore == "red")
        #expect(priorityUpdate.html == priorityHTML.replacingOccurrences(of: "red", with: "green"))
        #expect(priorityAfter == "green")
        #expect(triviaUpdate.html == triviaHTML.replacingOccurrences(of: "red", with: "green"))
    }

    /// 論理名（日本語）: Unresolved identity局所降格テスト
    /// 概要: unresolved identityを持つsiblingだけをsession/pathへ降格し、正常nodeのstable referenceとsafe selectorを維持します。
    @Test("unresolved identityは当該nodeだけをsession pathへ降格する")
    func testUnresolvedIdentityOnlyDegradesItsOwningNode() throws {
        // コンディション：正常なstandard ID/class/annotation nodeとunresolved identity siblingを同居させる（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = #"<!doctype html><html><body><main id="good" data-og-internal-id="good-internal">ID</main><section class="good-class">Class</section><article data-og-internal-id="good-annotation">Internal</article><nav data-og-id="good-display">Display</nav><aside id="bad&copy" class="bad&copy" data-og-id="bad&copy" data-og-internal-id="bad&copy">Bad</aside></body></html>"#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：project graphとvalidationを取得し、resource bytesを再読込する（When）
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let validation = try fixture.core.validateProject(at: projectURL)
        let goodID = try #require(graph.nodes.first { $0.attributes["id"] == "good" })
        let goodClass = try #require(graph.nodes.first { $0.attributes["class"] == "good-class" })
        let goodInternal = try #require(graph.nodes.first { $0.internalID == "good-annotation" })
        let goodDisplay = try #require(graph.nodes.first { $0.id == "good-display" })
        let bad = try #require(graph.nodes.first { $0.tagName == "aside" })
        let afterInspection = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：正常nodeの参照/selectorは維持し、bad nodeだけを診断付きsession DOM pathへ降格する（Then）
        #expect(goodID.referenceStability == .stable)
        #expect(goodID.reference.hasPrefix("ogref:node:"))
        #expect(goodID.locator.selector == "#good")
        #expect(goodClass.locator.selector == ".good-class")
        #expect(goodInternal.referenceStability == .stable)
        #expect(goodInternal.locator.selector == #"[data-og-internal-id="good-annotation"]"#)
        #expect(goodDisplay.locator.selector == #"[data-og-id="good-display"]"#)
        #expect(bad.referenceStability == .session)
        #expect(bad.reference.hasPrefix("ogref-session:node:"))
        #expect(bad.locator.selector == nil)
        #expect(validation.diagnostics.contains { $0.code == "unresolved-data-og-internal-id-character-reference" })
        #expect(validation.diagnostics.contains { $0.code == "unresolved-data-og-id-character-reference" })
        #expect(afterInspection == originalHTML)
    }

    /// 論理名（日本語）: 未解決identity character reference保護テスト
    /// 概要: semantic値を確定できないidentityをsession/pathへ降格し、node/subtree adoptionをatomicに拒否します。
    @Test("未解決identity character referenceはvalidationとadoptで安全に拒否する")
    func testUnresolvedIdentityCharacterReferencesBlockAdoptionWithoutMutation() throws {
        // コンディション：semicolonなしのunknown named referenceを持つ既存identityを未注釈rootのdescendantへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = #"<!doctype html><html><body><main id="app"><section id="unsafe&copy" class="card&copy" data-og-id="display&copy" data-og-internal-id="node&copy">Body</section></main></body></html>"#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let unsafe = try #require(graph.nodes.first { $0.tagName == "section" })

        // 検証内容：unsafe node単体と、それを含むsubtreeをdry-runし、失敗結果をapplyへ渡す（When）
        let validation = try fixture.core.validateProject(at: projectURL)
        let nodeDryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: unsafe.reference
        )
        let subtreeDryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#app",
            scope: .subtree
        )
        let rejectedApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: subtreeDryRun.targetReference,
            scope: .subtree,
            apply: true
        )
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：identityはstable/selectableと誤認せず、validation/dry-run/applyの全経路がsourceを書き換えない（Then）
        #expect(unsafe.annotationStatus == .complete)
        #expect(unsafe.referenceStability == .session)
        #expect(unsafe.locator.selector == nil)
        #expect(validation.valid == false)
        #expect(validation.diagnostics.contains {
            $0.code == "unresolved-data-og-internal-id-character-reference" && $0.severity == .error
        })
        #expect(validation.diagnostics.contains {
            $0.code == "unresolved-data-og-id-character-reference" && $0.severity == .error
        })
        #expect(nodeDryRun.changed == false)
        #expect(nodeDryRun.diff == nil)
        #expect(nodeDryRun.diagnostics.contains { $0.code == "unresolved-data-og-internal-id-character-reference" })
        #expect(subtreeDryRun.changed == false)
        #expect(subtreeDryRun.adoptedReferences.isEmpty)
        #expect(subtreeDryRun.diagnostics.contains { $0.code == "unresolved-data-og-internal-id-character-reference" })
        #expect(rejectedApply.applied == false)
        #expect(rejectedApply.diagnostics.contains { $0.code == "adoption-apply-requires-snapshot-reference" })
        #expect(afterHTML == originalHTML)
    }

    /// 論理名（日本語）: Uppercase identity adoption最小差分テスト
    /// 概要: case違いの既存identity属性を同名として更新し、lowercase duplicateを追加しません。
    @Test("adoptはuppercase既存identityのcaseとtriviaを保って値だけ補完する")
    func testAdoptionReusesUppercaseIdentityAttributesWithoutDuplicates() throws {
        // コンディション：standard IDと空のuppercase identity属性を持つ部分注釈nodeをprojectへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = #"<!doctype html><html><body><main ID="adopt-me" DATA-OG-ID  aria-label="Keep" DATA-OG-INTERNAL-ID = "  "  data-vendor="safe">Body</main></body></html>"#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let beforeGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let before = try #require(beforeGraph.nodes.first { $0.tagName == "main" })

        // 検証内容：uppercase standard ID selectorから明示display ID付きdry-run/applyを行う（When）
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#adopt-me",
            displayID: "Adopted"
        )
        let afterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            displayID: "Adopted",
            apply: true
        )
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let after = try #require(applied.graph.nodes.first { $0.tagName == "main" })

        // 期待値：dry-runは無書込で、既存属性位置/case/spacingを保ち各identityを1つだけ持つ（Then）
        #expect(before.locator.selector == "#adopt-me")
        #expect(before.annotationStatus == .none)
        #expect(afterDryRun == originalHTML)
        #expect(applied.applied == true)
        #expect(appliedHTML.contains("DATA-OG-ID=\"Adopted\"  aria-label=\"Keep\""))
        #expect(appliedHTML.contains("DATA-OG-INTERNAL-ID = \""))
        #expect(appliedHTML.contains("  data-vendor=\"safe\""))
        #expect(appliedHTML.lowercased().components(separatedBy: "data-og-id").count - 1 == 1)
        #expect(appliedHTML.lowercased().components(separatedBy: "data-og-internal-id").count - 1 == 1)
        #expect(!appliedHTML.contains(" data-og-id="))
        #expect(!appliedHTML.contains(" data-og-internal-id="))
        #expect(after.id == "Adopted")
        #expect(after.annotationStatus == .complete)
        #expect(after.referenceStability == .stable)
    }

    /// 論理名（日本語）: Explicit subtree adoptionテスト
    /// 概要: selector dry-run、proposal reference apply、stable reference idempotencyをsource diffと標準ID再利用付きで確認します。
    @Test("明示adoptはdry-run diff後だけidentityを追加して冪等適用する")
    func testExplicitAdoptionDryRunApplyAndIdempotency() throws {
        // コンディション：標準idを持つrootと未注釈subtreeをproject resourceとして用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = """
        <!doctype html>
        <html><body>
          <!-- preserve adoption context -->
          <main id="app" class="shell"><article class="card"><h2>Title</h2></article></main>
        </body></html>
        """
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：selectorでsubtree dry-runし、返されたapply専用proposal referenceだけでapplyしてstable referenceを再適用する（When）
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#app",
            scope: .subtree
        )
        let afterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .subtree,
            apply: true
        )
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let stableMain = try #require(applied.graph.nodes.first { $0.tagName == "main" })
        let idempotentDryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: stableMain.reference,
            scope: .subtree
        )
        let idempotent = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: idempotentDryRun.targetReference,
            scope: .subtree,
            apply: true
        )

        // 期待値：dry-runは無書込、標準idは複製せずinternalだけを足し、subtreeはstableかつ2回目は無差分（Then）
        #expect(dryRun.dryRun == true)
        #expect(dryRun.changed == true)
        #expect(dryRun.applied == false)
        #expect(dryRun.targetReference.hasPrefix("ogref-session:adoption:"))
        #expect(dryRun.diff?.unifiedDiff.contains("data-og-internal-id") == true)
        #expect(afterDryRun == originalHTML)
        #expect(applied.applied == true)
        #expect(applied.changed == true)
        #expect(applied.diagnostics.isEmpty)
        #expect(appliedHTML.contains("<!-- preserve adoption context -->"))
        #expect(appliedHTML.contains("<main id=\"app\" class=\"shell\" data-og-internal-id="))
        #expect(!appliedHTML.contains("<main id=\"app\" class=\"shell\" data-og-id="))
        #expect(!appliedHTML.contains("data-og-type="))
        #expect(applied.adoptedReferences.count == 3)
        #expect(applied.graph.nodes.filter { ["main", "article", "h2"].contains($0.tagName) }.allSatisfy {
            $0.referenceStability == .stable
        })
        #expect(idempotentDryRun.targetReference.hasPrefix("ogref-session:adoption:"))
        #expect(idempotentDryRun.changed == false)
        #expect(idempotent.applied == false)
        #expect(idempotent.changed == false)
        #expect(idempotent.diff == nil)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == appliedHTML)
    }

    /// 論理名（日本語）: Adoption stale guardテスト
    /// 概要: selector applyを拒否し、dry-run後にsource rangeが変わったproposal snapshotをstaleとして無書込にします。
    @Test("adopt applyはdry-run proposalとsource range hash一致を必須にする")
    func testAdoptionApplyRequiresFreshDryRunReference() throws {
        // コンディション：selectorで一意に解決できる未注釈nodeをprojectへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><main id=\"app\"><p>Body</p></main></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：selector直接applyを試し、dry-run後にはtarget前方のsourceだけを変更して古いreferenceをapplyする（When）
        let directApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#app",
            apply: true
        )
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#app"
        )
        let shiftedHTML = originalHTML.replacingOccurrences(of: "<main", with: "\n<main")
        try fixture.writeRawHTML(shiftedHTML)
        let staleApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            apply: true
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：両applyともsourceを書き換えず、古いrange/hash proposalはstaleになる（Then）
        #expect(directApply.diagnostics.contains { $0.code == "adoption-apply-requires-snapshot-reference" })
        #expect(directApply.applied == false)
        #expect(staleApply.diagnostics.contains { $0.code == "stale-adoption-proposal" })
        #expect(staleApply.applied == false)
        #expect(!finalHTML.contains("data-og-"))
        #expect(finalHTML == shiftedHTML)
    }

    /// 論理名（日本語）: Adoption proposal parameter bindingテスト
    /// 概要: apply専用proposalが正規化済みscope/display IDを束縛し、graph session referenceや別proposal parameterでの書込を拒否します。
    @Test("adopt proposalはscopeとdisplay IDを束縛する")
    func testAdoptionProposalBindsScopeAndDisplayID() throws {
        // コンディション：graph session referenceを返す未注釈nodeと変更前sourceを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><main id=\"app\"><p>Body</p></main><aside>Other</aside></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let main = try #require(graph.nodes.first { $0.tagName == "main" })

        // 検証内容：graph reference直接applyと、review済みproposalのscope/display ID差し替えを試してから同じ正規化parameterでapplyする（When）
        let directGraphApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: main.reference,
            scope: .node,
            displayID: "reviewed",
            apply: true
        )
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: main.reference,
            scope: .node,
            displayID: "  reviewed  "
        )
        let scopeMismatch = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .subtree,
            displayID: "reviewed",
            apply: true
        )
        let displayIDMismatch = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .node,
            displayID: "different",
            apply: true
        )
        let afterRejectedApplies = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let matchingApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            scope: .node,
            displayID: "reviewed",
            apply: true
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：proposal以外とparameter mismatchは無書込で、trim後に一致するreview済みproposalだけが適用される（Then）
        #expect(main.reference.hasPrefix("ogref-session:node:"))
        #expect(directGraphApply.diagnostics.contains { $0.code == "adoption-apply-requires-snapshot-reference" })
        #expect(directGraphApply.applied == false)
        #expect(dryRun.targetReference.hasPrefix("ogref-session:adoption:"))
        #expect(scopeMismatch.diagnostics.contains { $0.code == "stale-adoption-proposal" })
        #expect(scopeMismatch.applied == false)
        #expect(displayIDMismatch.diagnostics.contains { $0.code == "stale-adoption-proposal" })
        #expect(displayIDMismatch.applied == false)
        #expect(afterRejectedApplies == originalHTML)
        #expect(matchingApply.applied == true)
        #expect(matchingApply.diagnostics.isEmpty)
        #expect(finalHTML.contains("<main id=\"app\" data-og-id=\"reviewed\" data-og-internal-id="))
        #expect(finalHTML.contains("<p>Body</p>"))
        #expect(!finalHTML.contains("<p data-og-"))
    }

    /// 論理名（日本語）: Adoption proposal document bindingテスト
    /// 概要: target外のidentity変更でgenerated ID候補が変わる場合も、document全体hashにより未レビューdiffのapplyを拒否します。
    @Test("adopt proposalはdocument全体のcandidate条件を束縛する")
    func testAdoptionProposalBindsWholeDocumentCandidateConditions() throws {
        // コンディション：safe selectorを持たずgenerated display IDが必要なtargetと後続nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><main><p>Body</p></main><aside>Other</aside></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let beforeGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let mainBefore = try #require(beforeGraph.nodes.first { $0.tagName == "main" })
        let generatedDisplayID = "main-\(mainBefore.locator.contentHash.prefix(7))"
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            domPath: mainBefore.locator.domPath
        )

        // 検証内容：target range/contentを変えず、後続nodeへdry-run時のgenerated ID候補を追加して古いproposalをapplyする（When）
        let externallyChangedHTML = originalHTML.replacingOccurrences(
            of: "<aside>",
            with: "<aside data-og-id=\"\(generatedDisplayID)\">"
        )
        try fixture.writeRawHTML(externallyChangedHTML)
        let changedGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let mainAfterExternalChange = try #require(changedGraph.nodes.first { $0.tagName == "main" })
        let staleApply = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            apply: true
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：locator局所値が同じでもdocument proposal hash不一致として拒否し、外部変更以外を書き込まない（Then）
        #expect(mainAfterExternalChange.locator.sourceRange == mainBefore.locator.sourceRange)
        #expect(mainAfterExternalChange.locator.contentHash == mainBefore.locator.contentHash)
        #expect(staleApply.diagnostics.contains { $0.code == "stale-adoption-proposal" })
        #expect(staleApply.applied == false)
        #expect(finalHTML == externallyChangedHTML)
        #expect(!finalHTML.contains("<main data-og-"))
    }

    /// 論理名（日本語）: Partial stable annotation snapshot adoptionテスト
    /// 概要: internal IDだけを持つstable graph nodeでもdry-runがrevision snapshotを返し、そのtokenだけで明示display IDを適用できることを確認します。
    @Test("internal IDだけのpartial nodeもproposal referenceでadoptする")
    func testPartialInternalIDAdoptionRequiresSnapshotReference() throws {
        // コンディション：標準idと一意なinternal IDだけを持つpartial nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeRawHTML(
            "<!doctype html><html><body><main id=\"app\" data-og-internal-id=\"existing-node\">Body</main></body></html>"
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：stable referenceの直接applyを拒否し、selector dry-runのproposal tokenで適用する（When）
        let typedReference = "ogref:node:\(fixture.chapterInternalID):\(fixture.homePageInternalID):existing-node"
        let bypass = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: typedReference,
            displayID: "main-node",
            apply: true
        )
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: "#app",
            displayID: "main-node"
        )
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            displayID: "main-node",
            apply: true
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：graphはstableでもadoption apply tokenはrevision-scopedで、既存internal IDは保持される（Then）
        #expect(bypass.diagnostics.contains { $0.code == "adoption-apply-requires-snapshot-reference" })
        #expect(bypass.applied == false)
        #expect(dryRun.targetReference.hasPrefix("ogref-session:adoption:"))
        #expect(dryRun.changed == true)
        #expect(applied.applied == true)
        #expect(applied.diagnostics.isEmpty)
        #expect(html.contains("id=\"app\" data-og-internal-id=\"existing-node\" data-og-id=\"main-node\""))
    }

    /// 論理名（日本語）: Safe authored selector adoptionテスト
    /// 概要: 一意な標準class selectorをlocatorへ優先し、明示adoptでも不要なdisplay annotationを追加しないことを確認します。
    @Test("adoptは既存safe class selectorを再利用する")
    func testAdoptionReusesSafeAuthoredClassSelector() throws {
        // コンディション：一意なauthored classを持つ未注釈nodeをproject resourceへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeRawHTML(
            "<!doctype html><html><body><section class=\"card featured\"><p>Vendor body</p></section><aside id=\" padded \" aria-label=\"Spaced\"></aside><div id=\"padded\"></div></body></html>"
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：graphが返すclass selectorでdry-runし、そのapply専用proposal tokenだけをapplyする（When）
        let beforeGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let sectionBefore = try #require(beforeGraph.nodes.first { $0.tagName == "section" })
        let spacedIDNode = try #require(beforeGraph.nodes.first { $0.tagName == "aside" })
        let normalizedIDNode = try #require(beforeGraph.nodes.first { $0.tagName == "div" })
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            selector: try #require(sectionBefore.locator.selector)
        )
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            apply: true
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let sectionAfter = try #require(applied.graph.nodes.first { $0.tagName == "section" })
        let childAfter = try #require(applied.graph.nodes.first { $0.tagName == "p" })

        // 期待値：class selectorと標準sourceを保持し、対象にinternal identityだけを追加する（Then）
        #expect(sectionBefore.locator.selector == ".card")
        #expect(spacedIDNode.locator.selector == #"[id=" padded "]"#)
        #expect(normalizedIDNode.locator.selector == "#padded")
        #expect(dryRun.diff?.unifiedDiff.contains(" data-og-id=\"") != true)
        #expect(applied.applied == true)
        #expect(html.contains("<section class=\"card featured\" data-og-internal-id="))
        #expect(!html.contains("<section class=\"card featured\" data-og-id="))
        #expect(sectionAfter.annotationStatus == .partial)
        #expect(sectionAfter.referenceStability == .stable)
        #expect(childAfter.annotationStatus == .none)
        #expect(childAfter.referenceStability == .session)
    }

    /// 論理名（日本語）: Empty annotation adoptionテスト
    /// 概要: 空または空白だけのidentity値をmissing annotationとして扱い、同名属性を重複せず値だけ置換します。
    @Test("adoptは空identity属性を最小置換する")
    func testAdoptionReplacesEmptyIdentityAttributeValues() throws {
        // コンディション：quoteとattribute triviaを含む空identity属性の未注釈nodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><main  data-og-id  aria-label=\"Keep\" data-og-internal-id = \"  \"  data-vendor=\"safe\">Body</main></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let beforeGraph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let mainBefore = try #require(beforeGraph.nodes.first { $0.tagName == "main" })

        // 検証内容：DOM pathからdry-runし、そのapply専用proposal tokenをapplyする（When）
        let dryRun = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            domPath: mainBefore.locator.domPath
        )
        let applied = try fixture.core.adoptNode(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            reference: dryRun.targetReference,
            apply: true
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let mainAfter = try #require(applied.graph.nodes.first { $0.tagName == "main" })

        // 期待値：missing annotationはvalidで、既存attribute位置とtriviaを保ちながら各identityを1つだけ持つ（Then）
        #expect(mainBefore.annotationStatus == .none)
        #expect(mainBefore.referenceStability == .session)
        #expect(beforeGraph.diagnostics.isEmpty)
        #expect(applied.applied == true)
        #expect(html.components(separatedBy: "data-og-id").count - 1 == 1)
        #expect(html.components(separatedBy: "data-og-internal-id").count - 1 == 1)
        #expect(html.contains("<main  data-og-id=\"") && html.contains(" data-og-internal-id = \""))
        #expect(html.contains("  aria-label=\"Keep\" data-og-internal-id"))
        #expect(html.contains("  data-vendor=\"safe\""))
        #expect(!html.contains("data-og-id  aria-label"))
        #expect(!html.contains("data-og-internal-id = \"  \""))
        #expect(mainAfter.annotationStatus == .complete)
        #expect(mainAfter.referenceStability == .stable)
    }

    /// 論理名（日本語）: CLI progressive adoption parityテスト
    /// 概要: `ogkiln node adopt`がselector dry-runを既定にし、返却proposal referenceでのみ同じdiffを適用することを確認します。
    @Test("CLI node adoptはdry-run referenceでだけsourceを更新する")
    func testCLIExplicitAdoptionDryRunAndApply() throws {
        // コンディション：CLIから参照できる未注釈project resourceを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = "<!doctype html><html><body><main id=\"app\">Body</main></body></html>"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var dryOutput = ""
        var dryError = ""

        // 検証内容：selector dry-runをJSON取得し、そのtargetReferenceを別CLI invocationへ渡す（When）
        let dryCode = cli.run(
            arguments: [
                "node", "adopt", "Sample.ogp", "--page-id", fixture.homePageInternalID,
                "--selector", "#app", "--scope", "node", "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { dryOutput += $0 },
            stderr: { dryError += $0 }
        )
        let dryResult = try JSONDecoder().decode(OpenGraphiteNodeAdoptionResult.self, from: Data(dryOutput.utf8))
        let afterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        var applyOutput = ""
        var applyError = ""
        let applyCode = cli.run(
            arguments: [
                "node", "adopt", "Sample.ogp", "--page-id", fixture.homePageInternalID,
                "--reference", dryResult.targetReference, "--scope", "node", "--apply", "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { applyOutput += $0 },
            stderr: { applyError += $0 }
        )
        let applyResult = try JSONDecoder().decode(OpenGraphiteNodeAdoptionResult.self, from: Data(applyOutput.utf8))
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：dry-runはbytes不変、applyは同一candidateを保存し標準idをdata-og-idへ複製しない（Then）
        #expect(dryCode == 0)
        #expect(dryError.isEmpty)
        #expect(dryResult.dryRun == true)
        #expect(dryResult.diff != nil)
        #expect(afterDryRun == originalHTML)
        #expect(applyCode == 0)
        #expect(applyError.isEmpty)
        #expect(applyResult.applied == true)
        #expect(finalHTML.contains("<main id=\"app\" data-og-internal-id="))
        #expect(!finalHTML.contains("data-og-id="))
    }

    /// 論理名（日本語）: CSS宣言編集legacy保持テスト
    /// 概要: 通常のCSS編集が明示migration前のlegacy helperを暗黙削除しないことを確認します。
    @Test("CSS宣言編集はlegacy helperを暗黙変換しない")
    func testSetCSSVariablePreservesLegacyStateUntilMigration() throws {
        // コンディション：legacy editor属性とinline標準propertyを含むHTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Hero data-og-id="hero" data-og-type="frame" data-og-selected="true" style="gap:24px; --og-edit-width:100px;"></Hero>
            </body></html>
            """
        )

        // 検証内容：heroのgapだけを更新する（When）
        let result = try fixture.core.setCSSVariable("gap", value: "32px", nodeID: "hero", htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let companionURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)

        // 期待値：authored inline winnerだけを最小変更し、無関係なlegacy inputは明示migrationまで保持される（Then）
        #expect(result.updated == true)
        #expect(result.node?.cssVariables["gap"] == "32px")
        #expect(html.contains("gap:32px"))
        #expect(html.contains("data-og-selected=\"true\""))
        #expect(html.contains("--og-edit-width:100px"))
        #expect(!FileManager.default.fileExists(atPath: companionURL.path))
    }

    /// 論理名（日本語）: Inline scale最小差分編集テスト
    /// 概要: 標準`scale`のinline winnerだけを更新・削除し、legacy scale helperと他のtransform宣言を保持します。
    @Test("inline scaleだけを最小差分編集してlegacy transform stateを保持する")
    func testScaleEditingPreservesInlineLegacyAndTransformState() throws {
        // コンディション：標準scaleとlegacy helper、transform、rotateを同じinline styleに持つnodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <div id="flip-card" data-og-id="flip" data-og-type="frame" style=" --og-scale-x: -1; transform: rotate(8deg) translateX(2px); /* scale reason */ scale : 1 1 /* keep */ !important ; rotate: 3deg; --og-scale-y: 1; "></div>
            </body></html>
            """
        )
        let originalCSS = "#flip-card { scale: 9 9 !important; unknown-scale-context: keep; }\n"
        try fixture.writeCompanionCSS(originalCSS)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 検証内容：inline winnerを更新し、同値を再設定してから削除する（When）
        let initialGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let initialFlip = try #require(initialGraph.nodes.first { $0.id == "flip" })
        let update = try fixture.core.setCSSVariable(
            "scale",
            value: "-1 1",
            nodeID: "flip",
            htmlURL: fixture.htmlURL
        )
        let updatedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let idempotent = try fixture.core.setCSSVariable(
            "scale",
            value: "-1 1",
            nodeID: "flip",
            htmlURL: fixture.htmlURL
        )
        let removal = try fixture.core.setCSSVariable(
            "scale",
            value: "",
            nodeID: "flip",
            htmlURL: fixture.htmlURL
        )
        let removedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let finalCSS = try fixture.readCompanionCSS()

        // 期待値：inline source value/declarationだけが変わり、既存のlegacy helperとtransform compositionは不変である（Then）
        #expect(initialFlip.cssVariables["scale"] == "1 1")
        #expect(initialFlip.cssSourceTrace["scale"]?.last?.selector == "<inline style>")
        #expect(initialFlip.cssSourceTrace["scale"]?.last?.important == true)
        #expect(update.updated == true)
        #expect(update.node?.cssVariables["scale"] == "-1 1")
        #expect(updatedHTML == originalHTML.replacingOccurrences(of: "scale : 1 1", with: "scale : -1 1"))
        #expect(idempotent.updated == false)
        #expect(removal.updated == true)
        #expect(removal.node?.cssVariables["scale"] == "9 9")
        #expect(!removedHTML.contains("scale :"))
        #expect(removedHTML.contains("--og-scale-x: -1"))
        #expect(removedHTML.contains("--og-scale-y: 1"))
        #expect(removedHTML.contains("transform: rotate(8deg) translateX(2px)"))
        #expect(removedHTML.contains("rotate: 3deg"))
        #expect(removedHTML.contains("/* scale reason */"))
        #expect(finalCSS == originalCSS)
    }

    /// 論理名（日本語）: Companion CSS scale最小差分編集テスト
    /// 概要: source provenanceを持つ標準`scale`だけを更新・削除し、コメントと他のindividual transform propertyを保持します。
    @Test("companion CSSのscaleだけを更新削除してtransform compositionを保持する")
    func testScaleEditingPreservesCompanionTransformComposition() throws {
        // コンディション：legacy inline helperと標準scale sourceを分離したnodeを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <div id="flip-card" data-og-id="flip" data-og-type="frame" style="--og-scale-x:-1; --og-scale-y:1;"></div>
            </body></html>
            """
        )
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let originalCSS = """
        .flip-context { unknown-before: keep; }

        #flip-card {
          transform: rotate(8deg) translateX(2px);
          rotate: 3deg;
          scale: /* rationale */ 1 1 /* keep */ !important /* after-important */;
          unknown-transform-context: keep-me;
        }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // 検証内容：scale source valueを更新し、そのdeclarationだけを削除する（When）
        let update = try fixture.core.setCSSVariable(
            "scale",
            value: "-1 1",
            nodeID: "flip",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()
        let removal = try fixture.core.setCSSVariable(
            "scale",
            value: "",
            nodeID: "flip",
            htmlURL: fixture.htmlURL
        )
        let removedCSS = try fixture.readCompanionCSS()
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：scale以外のsource textとHTMLはbyte-stableで、legacy helperは暗黙migrationされない（Then）
        #expect(update.updated == true)
        #expect(update.node?.cssVariables["scale"] == "-1 1")
        #expect(updatedCSS == originalCSS.replacingOccurrences(of: "1 1 /* keep */", with: "-1 1 /* keep */"))
        #expect(removal.updated == true)
        #expect(removal.node?.cssVariables["scale"] == nil)
        #expect(!removedCSS.contains("scale:"))
        #expect(removedCSS.contains("transform: rotate(8deg) translateX(2px);"))
        #expect(removedCSS.contains("rotate: 3deg;"))
        #expect(removedCSS.contains("unknown-transform-context: keep-me;"))
        #expect(removedCSS.contains(".flip-context { unknown-before: keep; }"))
        #expect(finalHTML == originalHTML)
        #expect(finalHTML.contains("--og-scale-x:-1"))
        #expect(finalHTML.contains("--og-scale-y:1"))
    }

    /// 論理名（日本語）: CSSフォントファミリー宣言編集テスト
    /// 概要: node 単位 CSS declaration 編集で `font-family` を正本 HTML へ保存できることを確認します。
    @Test("font-family CSS宣言を保存できる")
    func testSetFontFamilyCSSVariable() throws {
        // コンディション：標準text nodeを持つHTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <p data-og-id="title" data-og-type="text">OpenGraphite</p>
            </body></html>
            """
        )
        let fontStack = "\"Noto Sans JP\", \"Hiragino Sans\", sans-serif"

        // 検証内容：text nodeのfont-familyを更新する（When）
        let result = try fixture.core.setCSSVariable(
            "font-family",
            value: fontStack,
            nodeID: "title",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：font-family値がcompanion CSS declarationとして保存される（Then）
        #expect(result.updated == true)
        #expect(result.node?.cssVariables["font-family"] == fontStack)
        #expect(!html.contains("font-family"))
        #expect(css.contains("font-family: \"Noto Sans JP\", \"Hiragino Sans\", sans-serif;"))
    }

    /// 論理名（日本語）: デザイントークン編集テスト
    /// 概要: Project CSS の `:root` custom property を design token として一覧・更新・削除できることを確認します。
    @Test("Project CSSのdesign tokenを一覧更新削除できる")
    func testDesignTokensListSetAndRemove() throws {
        // コンディション：CSS library に :root token を持つ project を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        try fixture.writeCSSLibrary(
            """
            :root {
              --color-primary: #2563eb;
              --space-medium: 16px;
            }

            [data-og-type] {
              box-sizing: border-box;
            }
            """
        )

        // 検証内容：token 一覧を読み、値更新と削除を行う（When）
        let initial = try fixture.core.designTokens(projectURL: projectURL)
        let update = try fixture.core.setDesignToken("--space-medium", value: "20px", projectURL: projectURL)
        let remove = try fixture.core.setDesignToken("--color-primary", value: "", projectURL: projectURL)
        let invalid = try fixture.core.setDesignToken("color-primary", value: "#111111", projectURL: projectURL)
        let css = try fixture.readCSSLibrary()

        // 期待値：token は :root から抽出され、参照文字列を持ち、CSS library だけが更新される（Then）
        #expect(initial.tokens.map(\.name) == ["--color-primary", "--space-medium"])
        #expect(initial.tokens.first?.reference == "var(--color-primary)")
        #expect(update.updated == true)
        #expect(update.token?.value == "20px")
        #expect(remove.updated == true)
        #expect(remove.token == nil)
        #expect(invalid.updated == false)
        #expect(invalid.diagnostics.contains { $0.code == "invalid-design-token-name" })
        #expect(css.contains("--space-medium: 20px;"))
        #expect(!css.contains("--color-primary"))
    }

    /// 論理名（日本語）: Theme generic design token依存解析テスト
    /// 概要: 旧reserved theme名に依存せず、project-defined tokenを標準CSS propertyからAgent graphへ公開することを確認します。
    @Test("標準appearance宣言からgeneric design token依存を解析できる")
    func testGenericThemeDesignTokenDependenciesUseStandardProperties() throws {
        // コンディション：generic color tokenと、それを標準appearance宣言から参照するpage/buttonを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <main data-og-id="page" data-og-type="page">
                <button data-og-id="cta" data-og-type="button">Continue</button>
              </main>
            </body></html>
            """
        )
        try fixture.writeProject(to: projectURL)
        let tokenSource = """
        :root {
          --color-page-background: #f8fafc;
          --color-text: #111827;
          --color-muted: #64748b;
          --color-accent: #2563eb;
          --color-on-accent: #ffffff;
        }
        """
        try fixture.writeCSSLibrary(tokenSource)
        try fixture.writeCompanionCSS(
            tokenSource +
            """

            [data-og-internal-id="page"] {
              background: var(--color-page-background);
              color: var(--color-text);
              border: 1px solid var(--color-muted);
            }

            [data-og-internal-id="cta"] {
              background: var(--color-accent);
              color: var(--color-on-accent);
            }
            """
        )

        // 検証内容：Agent Coreでtoken一覧とpage graphを取得し、旧reserved名のnode編集を試す（When）
        let tokens = try fixture.core.designTokens(projectURL: projectURL).tokens
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let page = try #require(graph.nodes.first { $0.id == "page" })
        let cta = try #require(graph.nodes.first { $0.id == "cta" })
        let rejectedLegacyEdit = try fixture.core.setCSSVariable(
            "--og-accent",
            value: "#0f172a",
            nodeID: "cta",
            htmlURL: fixture.htmlURL
        )

        // 期待値：generic tokenとvar参照を表示でき、旧theme名はnode用reserved propertyとして受理しない（Then）
        #expect(tokens.map(\.name) == [
            "--color-page-background",
            "--color-text",
            "--color-muted",
            "--color-accent",
            "--color-on-accent"
        ])
        #expect(tokens.map(\.reference) == tokens.map { "var(\($0.name))" })
        #expect(page.cssVariables["background"] == "var(--color-page-background)")
        #expect(page.cssVariables["color"] == "var(--color-text)")
        #expect(page.cssVariables["border"] == "1px solid var(--color-muted)")
        #expect(cta.cssVariables["background"] == "var(--color-accent)")
        #expect(cta.cssVariables["color"] == "var(--color-on-accent)")
        #expect(page.cssSourceTrace["background"]?.last?.value == "var(--color-page-background)")
        #expect(cta.cssSourceTrace["background"]?.last?.value == "var(--color-accent)")
        #expect(rejectedLegacyEdit.updated == false)
        #expect(rejectedLegacyEdit.diagnostics.contains { $0.code == "unknown-css-variable" })
    }

    /// 論理名（日本語）: CLIデザイントークン編集テスト
    /// 概要: `ogkiln design-token` が project CSS library の token を編集できることを確認します。
    @Test("CLIはdesign tokenをCSS libraryへ保存できる")
    func testCLIDesignTokenSetListAndRemove() throws {
        // コンディション：最小 project と CSS library を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        try fixture.writeCSSLibrary(":root {\n  --color-primary: #2563eb;\n}\n")
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLI で token を追加、一覧取得、削除する（When）
        let setCode = cli.run(
            arguments: [
                "design-token", "set", "Sample.ogp",
                "--name", "--space-medium",
                "--value", "16px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        stdout = ""
        stderr = ""
        let listCode = cli.run(
            arguments: ["design-token", "list", "Sample.ogp", "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let listOutput = stdout
        stdout = ""
        stderr = ""
        let removeCode = cli.run(
            arguments: [
                "design-token", "remove", "Sample.ogp",
                "--name", "--color-primary"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let css = try fixture.readCSSLibrary()

        // 期待値：CLI は成功し、JSON に参照文字列が出力され、削除後の CSS に対象 token が残らない（Then）
        #expect(setCode == 0)
        #expect(listCode == 0)
        #expect(removeCode == 0)
        #expect(stderr.isEmpty)
        #expect(listOutput.contains("\"name\" : \"--space-medium\""))
        #expect(listOutput.contains("\"reference\" : \"var(--space-medium)\""))
        #expect(css.contains("--space-medium: 16px;"))
        #expect(!css.contains("--color-primary"))
    }

    /// 論理名（日本語）: Locale typography Agent Core編集テスト
    /// 概要: page/component companion CSSの標準font-familyを同じ共有実装で一覧・更新・削除します。
    @Test("Agent Coreはpageとcomponentのlocale typographyをlosslessに編集する")
    func testLocaleTypographyListSetRemoveForPageAndComponent() throws {
        // コンディション：標準ID root、任意locale、media scope、element overrideを持つpage/componentを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <main id="app" data-og-id="page" data-og-type="page">
                <p class="brand" data-og-id="brand">Brand</p>
              </main>
            </body></html>
            """
        )
        try fixture.writeHTML(
            "<!doctype html><html><body><article id=\"component-root\" data-og-id=\"cards\" data-og-type=\"page\"></article></body></html>",
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        let pageCSS = """
        /* keep-before */
        #app { font-family: Inter, sans-serif; color: black; }
        @media (min-width: 40rem) {
          #app:lang('fr_CA') { font-family: Old, sans-serif !important; }
        }
        #app .brand { font-family: Display, serif; }
        @future typography { raw { untouched: yes; } }
        """
        try fixture.writeCompanionCSS(pageCSS)
        try "#component-root { font-family: System, sans-serif; }\n".write(
            to: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentURL),
            atomically: true,
            encoding: .utf8
        )
        let pageHTMLBefore = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let componentHTMLBefore = try String(contentsOf: componentURL, encoding: .utf8)

        // 検証内容：pageを一覧・既存locale更新・default削除し、componentへ新localeを追加する（When）
        let initial = try fixture.core.localeTypography(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID
        )
        let pageUpdate = try fixture.core.setLocaleTypography(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            locale: "FR-ca",
            fontFamily: "Marianne, sans-serif"
        )
        let pageNoOp = try fixture.core.setLocaleTypography(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            locale: "fr_CA",
            fontFamily: "Marianne, sans-serif"
        )
        let pageRemove = try fixture.core.setLocaleTypography(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            locale: nil,
            fontFamily: ""
        )
        let componentUpdate = try fixture.core.setLocaleTypography(
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID,
            locale: "de_Latn_DE",
            fontFamily: "\"Noto Sans\", sans-serif"
        )
        let pageCSSAfter = try fixture.readCompanionCSS()
        let componentCSSAfter = try String(
            contentsOf: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentURL),
            encoding: .utf8
        )

        // 期待値：root scope/provenanceを維持し、element overrideとHTML/未知sourceを変更しない（Then）
        #expect(initial.rootSelector == "#app")
        #expect(initial.declarations.map(\.locale) == ["default", "fr-CA"])
        #expect(!initial.declarations.contains { $0.selector.contains(".brand") })
        #expect(pageUpdate.updated)
        #expect(pageUpdate.locale == "fr-CA")
        #expect(pageUpdate.selector == "#app:lang('fr_CA')")
        #expect(pageNoOp.updated == false)
        #expect(pageRemove.updated)
        #expect(!pageRemove.declarations.contains { $0.locale == "default" })
        #expect(componentUpdate.segment == "components")
        #expect(componentUpdate.locale == "de-Latn-DE")
        #expect(componentUpdate.selector == "#component-root:lang(\"de-Latn-DE\")")
        #expect(pageCSSAfter.contains("font-family: Marianne, sans-serif !important"))
        #expect(pageCSSAfter.contains("#app .brand { font-family: Display, serif; }"))
        #expect(pageCSSAfter.contains("@future typography { raw { untouched: yes; } }"))
        #expect(componentCSSAfter.contains("#component-root:lang(\"de-Latn-DE\")"))
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == pageHTMLBefore)
        #expect(try String(contentsOf: componentURL, encoding: .utf8) == componentHTMLBefore)
    }

    /// 論理名（日本語）: Locale typography CLI parityテスト
    /// 概要: `ogkiln locale-typography` list/set/removeがAgent Coreと同じ標準CSS結果を返します。
    @Test("CLIはlocale typographyをpage companion CSSへ一覧更新削除する")
    func testCLILocaleTypographyListSetAndRemove() throws {
        // コンディション：標準ID rootとdefault font-familyを持つ最小projectを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><main id=\"app\" data-og-id=\"page\" data-og-type=\"page\"></main></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        try fixture.writeCompanionCSS("#app {\n  font-family: Inter, sans-serif;\n}\n")
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：CLIで一覧、任意locale設定、同値再設定、削除を順に行う（When）
        let listCode = cli.run(
            arguments: [
                "locale-typography", "list", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let listOutput = stdout
        stdout = ""
        stderr = ""
        let setCode = cli.run(
            arguments: [
                "locale-typography", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--locale", "fr_CA",
                "--value", "Marianne, sans-serif",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let setOutput = stdout
        stdout = ""
        stderr = ""
        let noOpCode = cli.run(
            arguments: [
                "locale-typography", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--locale", "FR-ca",
                "--value", "Marianne, sans-serif",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let noOpOutput = stdout
        stdout = ""
        stderr = ""
        let removeCode = cli.run(
            arguments: [
                "locale-typography", "remove", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--locale", "fr-CA",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let css = try fixture.readCompanionCSS()

        // 期待値：全commandが成功し、canonical localeと冪等性をJSONへ返して対象宣言だけを削除する（Then）
        #expect(listCode == 0)
        #expect(setCode == 0)
        #expect(noOpCode == 0)
        #expect(removeCode == 0)
        #expect(stderr.isEmpty)
        #expect(listOutput.contains("\"rootSelector\" : \"#app\""))
        #expect(setOutput.contains("\"locale\" : \"fr-CA\""))
        #expect(setOutput.contains("\"updated\" : true"))
        #expect(noOpOutput.contains("\"updated\" : false"))
        #expect(!css.contains(":lang"))
        #expect(css.contains("font-family: Inter, sans-serif"))
    }

    /// 論理名（日本語）: CLIプロジェクト作成テスト
    /// 概要: `ogkiln project create` が project root と `.ogp` 作成先を分けて初期 project を作成できることを確認します。
    @Test("CLIはrootとogp作成先を指定してprojectを作成できる")
    func testCLIProjectCreateWritesRootedProject() throws {
        // コンディション：CLI の current directory に OpenGraphite.css seed を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let seedCSSURL = fixture.rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        try FileManager.default.createDirectory(
            at: seedCSSURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "body { margin: 0; }\n".write(to: seedCSSURL, atomically: true, encoding: .utf8)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：project root と `.ogp` 出力先を指定して CLI を実行する（When）
        let exitCode = cli.run(
            arguments: [
                "project", "create",
                "--root", "WebRoot",
                "--output", "Metadata/Created.ogp",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let summary = try JSONDecoder().decode(OpenGraphiteProjectSummary.self, from: Data(stdout.utf8))
        let projectURL = fixture.rootURL.appendingPathComponent("Metadata/Created.ogp")
        let webRootURL = fixture.rootURL.appendingPathComponent("WebRoot")
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)

        // 期待値：`.ogp` は output に、初期 HTML/CSS は root 配下に作成される（Then）
        #expect(exitCode == 0)
        #expect(stderr.isEmpty)
        #expect(summary.projectURL == projectURL.path)
        #expect(summary.rootURL == webRootURL.standardizedFileURL.path)
        #expect(summary.pages.map(\.id) == ["home"])
        #expect(loadedProject.project.repositoryRoot == "../WebRoot")
        #expect(FileManager.default.fileExists(atPath: webRootURL.appendingPathComponent("public/index.html").path))
        #expect(FileManager.default.fileExists(atPath: webRootURL.appendingPathComponent("CSS/OpenGraphite.css").path))
    }

    /// 論理名（日本語）: CSS位置宣言編集テスト
    /// 概要: position と inset 系の標準 CSS property を node 単位で保存できることを確認します。
    @Test("標準CSSのpositionとinsetを保存できる")
    func testSetStandardPositionCSSVariables() throws {
        // コンディション：absolute layout の child node を持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Canvas data-og-id="canvas" data-og-type="frame" data-og-layout="absolute">
                <Badge data-og-id="badge" data-og-type="text">New</Badge>
              </Canvas>
            </body></html>
            """
        )

        // 検証内容：badge の position と left / top / z-index を更新する
        let positionResult = try fixture.core.setCSSVariable(
            "position",
            value: "absolute",
            nodeID: "badge",
            htmlURL: fixture.htmlURL
        )
        let leftResult = try fixture.core.setCSSVariable("left", value: "24px", nodeID: "badge", htmlURL: fixture.htmlURL)
        let topResult = try fixture.core.setCSSVariable("top", value: "32px", nodeID: "badge", htmlURL: fixture.htmlURL)
        let zIndexResult = try fixture.core.setCSSVariable("z-index", value: "3", nodeID: "badge", htmlURL: fixture.htmlURL)
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：位置指定が標準 CSS declaration として companion CSS に保存される
        #expect(positionResult.updated == true)
        #expect(positionResult.node?.cssVariables["position"] == "absolute")
        #expect(leftResult.node?.cssVariables["left"] == "24px")
        #expect(topResult.node?.cssVariables["top"] == "32px")
        #expect(zIndexResult.node?.cssVariables["z-index"] == "3")
        #expect(!html.contains("position"))
        #expect(!html.contains("left"))
        #expect(!html.contains("top"))
        #expect(!html.contains("z-index"))
        #expect(css.contains("position: absolute;"))
        #expect(css.contains("left: 24px;"))
        #expect(css.contains("top: 32px;"))
        #expect(css.contains("z-index: 3;"))
    }

    /// 論理名（日本語）: Stylesheet link追加テスト
    /// 概要: HTML `<head>` に font stylesheet link を重複なく追加できることを確認します。
    @Test("font stylesheet linkをheadへ重複なく追加できる")
    func testEnsureStylesheetLinkAddsUniqueLink() throws {
        // コンディション：head を持つ HTML と Google Fonts CSS API の href を用意する
        let contract = OpenGraphiteContract.loadDefault(startingAt: URL(fileURLWithPath: #filePath))
        let href = "https://fonts.googleapis.com/css2?family=Roboto&display=swap"
        let html = """
        <!doctype html>
        <html><head><title>Fixture</title></head><body></body></html>
        """

        // 検証内容：stylesheet link を 2 回追加する
        let first = OpenGraphiteHTMLDocument(html: html)
            .ensuringStylesheetLink(href: href, contract: contract)
        let second = OpenGraphiteHTMLDocument(html: first.html)
            .ensuringStylesheetLink(href: href, contract: contract)

        // 期待値：link は head 内に 1 回だけ追加され、URL は HTML 属性として escape される
        #expect(first.diagnostics.isEmpty)
        #expect(first.html.contains("<title>Fixture</title>"))
        #expect(first.html.contains("<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Roboto&amp;display=swap\">"))
        #expect(second.html == first.html)
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

    /// 論理名（日本語）: CLI標準hidden属性編集テスト
    /// 概要: `node attr set/remove`がOpenGraphite固有属性を生成せず、標準`hidden` source intentとderived displayを更新します。
    @Test("CLIは標準hidden属性を設定して削除できる")
    func testCLISetAndRemoveStandardHiddenAttribute() throws {
        // コンディション：stable annotationだけを持つ標準main nodeとproject manifestを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            "<!doctype html><html><body><main data-og-id=\"panel\">Panel</main></body></html>"
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var setOutput = ""
        var setError = ""

        // 検証内容：標準hiddenを設定し、その後同じCLI routeから削除する（When）
        let setCode = cli.run(
            arguments: [
                "node", "attr", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "panel",
                "--name", "hidden",
                "--value", "hidden"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { setOutput += $0 },
            stderr: { setError += $0 }
        )
        let setResult = try JSONDecoder().decode(OpenGraphiteEditResult.self, from: Data(setOutput.utf8))
        let hiddenHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        var removeOutput = ""
        var removeError = ""
        let removeCode = cli.run(
            arguments: [
                "node", "attr", "remove", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "panel",
                "--name", "hidden"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { removeOutput += $0 },
            stderr: { removeError += $0 }
        )
        let removeResult = try JSONDecoder().decode(OpenGraphiteEditResult.self, from: Data(removeOutput.utf8))
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：graphはsource hiddenとresolved displayを返し、remove後はUA blockへ戻ってlegacy属性を生成しない（Then）
        #expect(setCode == 0)
        #expect(setError.isEmpty)
        #expect(setResult.node?.hidden == true)
        #expect(setResult.node?.cssResolvedValues["display"] == "none")
        #expect(hiddenHTML.contains("hidden=\"hidden\""))
        #expect(removeCode == 0)
        #expect(removeError.isEmpty)
        #expect(removeResult.node?.hidden == false)
        #expect(removeResult.node?.layout == "block")
        #expect(!finalHTML.contains(" hidden="))
        #expect(!finalHTML.contains("data-og-layout"))
        #expect(!finalHTML.contains("data-og-hidden"))
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
              <og-placement data-og-id="placement" data-og-type="frame"></og-placement>
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
        // コンディション：inline Lucide SVG と companion CSS を保持する icon node を用意する（Given）
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
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="decorative-icon"] {
              width: 24px;
              height: 24px;
            }

            [data-og-internal-id="decorative-icon"] > svg {
              stroke-width: 2;
            }
            """
        )

        // 検証内容：page graph と validation を実行する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let result = try fixture.core.validateHTML(at: fixture.htmlURL)
        let icon = try #require(graph.nodes.first { $0.id == "decorative-icon" })

        // 期待値：icon primitive と Lucide metadata が既知の契約として扱われる（Then）
        #expect(result.valid == true)
        #expect(graph.nodes.compactMap(\.legacyTypeHint) == ["icon"])
        #expect(icon.capabilities.contains(.editIcon))
        #expect(icon.attributes["data-og-icon-library"] == "lucide")
        #expect(icon.attributes["data-og-icon-name"] == "circle")
        #expect(icon.attributes["data-og-icon-source"] == "inline")
        let svgTarget = icon.renderingTargets.first { $0.kind == "svg" }
        #expect(svgTarget?.tagName == "svg")
        #expect(svgTarget?.relation == "direct-child")
        #expect(svgTarget?.authoredValues["stroke-width"] == "2")
        #expect(svgTarget?.sourceTrace["stroke-width"]?.first?.selector == #"[data-og-internal-id="decorative-icon"] > svg"#)
    }

    /// 論理名（日本語）: Wrapper実描画target解決テスト
    /// 概要: 未注釈media childのDOM relation、nth-of-type selector、source traceを返し、nested annotation境界を越えないことを確認します。
    @Test("wrapperから標準media描画targetを安全に解決できる")
    func testRenderingTargetsResolveMediaWithoutCrossingNestedAnnotations() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <figure id="hero-media" data-og-id="hero" data-og-type="image">
                <picture>
                  <img src="fallback.png" alt="">
                  <img class="preferred" src="hero.png" alt="Hero">
                </picture>
                <Icon data-og-id="nested-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline">
                  <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle></svg>
                </Icon>
              </figure>
            </body></html>
            """
        )
        let originalCSS = """
        /* authored selector and unknown declaration stay byte-stable */
        .preferred {
          object-fit: contain !important;
          unknown-media-property: keep-me;
        }

        @media (min-width: 80rem) {
          .preferred { object-fit: scale-down; }
        }
        """
        try fixture.writeCompanionCSS(originalCSS)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let outerNode = try #require(graph.nodes.first { $0.internalID == "hero" })
        let innerNode = try #require(graph.nodes.first { $0.internalID == "nested-icon" })
        let mediaTarget = try #require(outerNode.renderingTargets.first { $0.kind == "media" })
        let result = try fixture.core.setRelatedStyleDeclaration(
            "object-fit",
            value: "cover",
            wrapperNodeID: "hero",
            htmlURL: fixture.htmlURL
        )
        let updatedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(outerNode.renderingTargets.map(\.kind) == ["media"])
        #expect(innerNode.renderingTargets.map(\.kind) == ["svg"])
        #expect(mediaTarget.tagName == "img")
        #expect(mediaTarget.relation == "descendant")
        #expect(mediaTarget.relationSelector == ":scope > picture > img:nth-of-type(2)")
        #expect(mediaTarget.writeSelector == "#hero-media > picture > img:nth-of-type(2)")
        #expect(mediaTarget.targetInternalID == nil)
        #expect(mediaTarget.authoredValues["object-fit"] == "contain")
        #expect(mediaTarget.sourceTrace["object-fit"]?.first?.selector == ".preferred")
        #expect(mediaTarget.sourceTrace["object-fit"]?.first?.important == true)
        #expect(result.node?.renderingTargets.first { $0.kind == "media" }?.authoredValues["object-fit"] == "cover")
        #expect(updatedHTML == originalHTML)
        #expect(updatedCSS == originalCSS.replacingOccurrences(of: "object-fit: contain", with: "object-fit: cover"))
    }

    /// 論理名（日本語）: 外部CSS値trivia保持テスト
    /// 概要: property値の前後commentと`!important`後commentを保持し、semantic value tokenだけを更新します。
    @Test("外部CSSの前後commentとimportantを保持して値だけを更新する")
    func testRelatedStyleEditingPreservesExternalValueComments() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <figure data-og-id="media" data-og-type="image"><img class="commented-media" src="hero.png" alt=""></figure>
            </body></html>
            """
        )
        let originalCSS = """
        .commented-media {
          object-fit: /* rationale */ contain /* keep */ !important /* after-important */;
          unknown-media-property: keep-me;
        }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let mediaNode = try #require(graph.nodes.first { $0.id == "media" })
        let initialTarget = try #require(mediaNode.renderingTargets.first { $0.kind == "media" })
        let result = try fixture.core.setRelatedStyleDeclaration(
            "object-fit",
            value: "cover",
            wrapperNodeID: "media",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(initialTarget.authoredValues["object-fit"] == "contain")
        #expect(initialTarget.sourceTrace["object-fit"]?.first?.important == true)
        #expect(result.updated == true)
        #expect(updatedCSS == originalCSS.replacingOccurrences(of: "contain", with: "cover"))
    }

    /// 論理名（日本語）: Inline描画CSS cascade編集テスト
    /// 概要: stylesheet importantとinline priorityを正しく比較し、inline winnerではvalue rangeだけを更新します。
    @Test("inlineとstylesheetのcascadeを保って実描画CSSを最小差分編集する")
    func testRelatedStyleEditingHonorsInlineCascadeAndPreservesTrivia() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let normalInlineHTML = """
        <!doctype html>
        <html><body>
          <figure data-og-id="media" data-og-type="image">
            <img id="media-image" style=" color: red; /* before */ object-fit : contain /* keep */ ; --unknown-inline: calc(1 + 2); " src="hero.png" alt="">
          </figure>
        </body></html>
        """
        try fixture.writeHTML(normalInlineHTML)
        let importantCSS = """
        #media-image {
          object-fit: cover !important;
          unknown-source-property: keep-me;
        }
        """
        try fixture.writeCompanionCSS(importantCSS)
        let firstHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // When
        let firstGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let firstMediaNode = try #require(firstGraph.nodes.first { $0.id == "media" })
        let firstTarget = try #require(firstMediaNode.renderingTargets.first { $0.kind == "media" })
        _ = try fixture.core.setRelatedStyleDeclaration(
            "object-fit",
            value: "none",
            wrapperNodeID: "media",
            htmlURL: fixture.htmlURL
        )
        let htmlAfterExternalEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let cssAfterExternalEdit = try fixture.readCompanionCSS()

        let importantInlineHTML = normalInlineHTML.replacingOccurrences(
            of: "contain /* keep */ ;",
            with: "contain /* keep */ !important ;"
        )
        try fixture.writeHTML(importantInlineHTML)
        try fixture.writeCompanionCSS(importantCSS)
        let beforeInlineEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let secondGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let secondMediaNode = try #require(secondGraph.nodes.first { $0.id == "media" })
        let secondTarget = try #require(secondMediaNode.renderingTargets.first { $0.kind == "media" })
        let inlineResult = try fixture.core.setRelatedStyleDeclaration(
            "object-fit",
            value: "scale-down",
            wrapperNodeID: "media",
            htmlURL: fixture.htmlURL
        )
        let htmlAfterInlineEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let cssAfterInlineEdit = try fixture.readCompanionCSS()

        // Then
        #expect(firstTarget.authoredValues["object-fit"] == "cover")
        #expect(firstTarget.sourceTrace["object-fit"]?.contains { $0.selector == "<inline style>" && !$0.important } == true)
        #expect(htmlAfterExternalEdit == firstHTML)
        #expect(cssAfterExternalEdit == importantCSS.replacingOccurrences(of: "object-fit: cover", with: "object-fit: none"))
        #expect(secondTarget.authoredValues["object-fit"] == "contain")
        #expect(secondTarget.sourceTrace["object-fit"]?.last?.selector == "<inline style>")
        #expect(secondTarget.sourceTrace["object-fit"]?.last?.important == true)
        #expect(inlineResult.updated == true)
        #expect(htmlAfterInlineEdit == beforeInlineEdit.replacingOccurrences(of: "object-fit : contain", with: "object-fit : scale-down"))
        #expect(htmlAfterInlineEdit.contains("/* before */"))
        #expect(htmlAfterInlineEdit.contains("/* keep */ !important"))
        #expect(htmlAfterInlineEdit.contains("--unknown-inline: calc(1 + 2)"))
        #expect(cssAfterInlineEdit == importantCSS)
    }

    /// 論理名（日本語）: Unquoted inline描画CSS安全更新テスト
    /// 概要: unquoted `style`へ空白を含む有効な値を保存するとき、属性全体をquote化してHTML構造を保持します。
    @Test("unquoted inline描画CSSへ複合値を安全に保存する")
    func testRelatedStyleEditingQuotesUnsafeUnquotedInlineValues() throws {
        // コンディション：unquoted inline styleを持つ標準media descendantを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let originalHTML = #"<!doctype html><html><body><figure data-og-id="media" data-og-internal-id="media" data-og-type="image"><img style=object-fit:contain src="hero.png" alt=""></figure></body></html>"#
        try fixture.writeHTML(originalHTML)
        try fixture.writeCompanionCSS("")

        // 検証内容：空白を含む有効なsemantic CSS値へinline winnerを更新する（When）
        let result = try fixture.core.setRelatedStyleDeclaration(
            "object-fit",
            value: "var(--fit, contain)",
            wrapperNodeID: "media",
            htmlURL: fixture.htmlURL
        )
        let updatedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let updatedImage = try #require(
            try fixture.core.pageGraph(at: fixture.htmlURL).nodes.first { $0.tagName == "img" }
        )

        // 期待値：style以外のbytesを変えず属性をquote化し、再inspectionでもsemantic値を取得できる（Then）
        #expect(result.updated)
        #expect(
            updatedHTML
                == originalHTML.replacingOccurrences(
                    of: "style=object-fit:contain",
                    with: #"style="object-fit:var(--fit, contain)""#
                )
        )
        #expect(updatedImage.attributes["style"] == "object-fit:var(--fit, contain)")
    }

    /// 論理名（日本語）: SVG実描画target編集テスト
    /// 概要: wrapper選択からstroke-widthを持つSVG descendantへ到達し、authored source valueだけを更新します。
    @Test("wrapperからSVG descendantのstroke-widthを編集できる")
    func testRelatedStyleEditingTargetsSVGDescendant() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="glyph" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="inline">
                <svg viewBox="0 0 24 24"><path id="star-path" d="M1 1"></path></svg>
              </Icon>
            </body></html>
            """
        )
        let originalCSS = """
        #star-path {
          /* retain stroke context */
          stroke-width: 1.5;
          vector-effect: non-scaling-stroke;
        }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let result = try fixture.core.setRelatedStyleDeclaration(
            "stroke-width",
            value: "2",
            wrapperNodeID: "glyph",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()
        let target = try #require(result.node?.renderingTargets.first { $0.kind == "svg" })

        // Then
        #expect(result.updated == true)
        #expect(target.tagName == "path")
        #expect(target.relation == "descendant")
        #expect(target.writeSelector == "#star-path")
        #expect(target.authoredValues["stroke-width"] == "2")
        #expect(updatedCSS == originalCSS.replacingOccurrences(of: "stroke-width: 1.5", with: "stroke-width: 2"))
    }

    /// 論理名（日本語）: SVG descendant winner選択テスト
    /// 概要: SVG rootとshapeの両方にstroke-widthがある場合、最深のown winnerを持つshapeだけを編集します。
    @Test("SVG rootより最深shapeのstroke-width winnerを優先する")
    func testRelatedSVGEditingPrefersDeepestAuthoredShape() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="glyph" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="inline">
                <svg id="svg-root" viewBox="0 0 24 24"><path id="stroke-leaf" d="M1 1"></path></svg>
              </Icon>
            </body></html>
            """
        )
        let originalCSS = """
        #svg-root { stroke-width: 1; }
        #stroke-leaf { stroke-width: 2; }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let glyphNode = try #require(graph.nodes.first { $0.id == "glyph" })
        let initialTarget = try #require(glyphNode.renderingTargets.first { $0.kind == "svg" })
        _ = try fixture.core.setRelatedStyleDeclaration(
            "stroke-width",
            value: "3",
            wrapperNodeID: "glyph",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(initialTarget.tagName == "path")
        #expect(initialTarget.writeSelector == "#stroke-leaf")
        #expect(updatedCSS.contains("#svg-root { stroke-width: 1; }"))
        #expect(updatedCSS.contains("#stroke-leaf { stroke-width: 3; }"))
    }

    /// 論理名（日本語）: 複数path SVG新規stroke保存テスト
    /// 概要: stroke-width未指定のinline SVGではrootへ保存し、複数pathが同じ継承値を受け取れるようにします。
    @Test("stroke未指定の複数path SVGはrootへstroke-widthを保存する")
    func testRelatedSVGEditingWritesNewStrokeToSVGRoot() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="glyph" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="menu" data-og-icon-source="inline">
                <svg id="multi-path-svg" viewBox="0 0 24 24"><path d="M1 4h22"></path><path d="M1 20h22"></path></svg>
              </Icon>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS("/* keep empty authored context */\n")

        // When
        let result = try fixture.core.setRelatedStyleDeclaration(
            "stroke-width",
            value: "2",
            wrapperNodeID: "glyph",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()
        let target = try #require(result.node?.renderingTargets.first { $0.kind == "svg" })

        // Then
        #expect(target.tagName == "svg")
        #expect(target.writeSelector == "#multi-path-svg")
        #expect(updatedCSS.contains("#multi-path-svg {"))
        #expect(updatedCSS.contains("stroke-width: 2;"))
        #expect(!updatedCSS.contains(":nth-of-type"))
    }

    /// 論理名（日本語）: SVG stroke-width継承編集テスト
    /// 概要: 祖先sourceのstroke-widthをresolved値と継承traceで示し、編集時はshape側longhand overrideを追加します。
    @Test("SVG shapeは祖先stroke-widthを継承し編集時にchild overrideを保存する")
    func testRelatedSVGEditingReportsInheritedStrokeAndWritesChildOverride() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon class="stroke-source" data-og-id="glyph" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="inline">
                <svg viewBox="0 0 24 24"><path id="stroke-leaf" d="M1 1"></path></svg>
              </Icon>
            </body></html>
            """
        )
        let originalCSS = """
        .stroke-source {
          stroke-width: 2;
          unknown-wrapper-property: keep-me;
        }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let glyphNode = try #require(graph.nodes.first { $0.id == "glyph" })
        let inheritedTarget = try #require(glyphNode.renderingTargets.first { $0.kind == "svg" })
        let result = try fixture.core.setRelatedStyleDeclaration(
            "stroke-width",
            value: "3",
            wrapperNodeID: "glyph",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()
        let updatedTarget = try #require(result.node?.renderingTargets.first { $0.kind == "svg" })

        // Then
        #expect(inheritedTarget.tagName == "path")
        #expect(inheritedTarget.authoredValues["stroke-width"] == nil)
        #expect(inheritedTarget.resolvedValues["stroke-width"] == "2")
        #expect(inheritedTarget.sourceTrace["stroke-width"]?.first?.selector == ".stroke-source")
        #expect(inheritedTarget.sourceTrace["stroke-width"]?.first?.inherited == true)
        #expect(updatedCSS.contains(originalCSS))
        #expect(updatedCSS.contains("#stroke-leaf {"))
        #expect(updatedCSS.contains("stroke-width: 3;"))
        #expect(updatedTarget.authoredValues["stroke-width"] == "3")
        #expect(updatedTarget.sourceTrace["stroke-width"]?.first?.inherited == false)
    }

    /// 論理名（日本語）: 祖先inline cascade継承テスト
    /// 概要: wrapper inlineのstroke-widthとcustom propertyを子のresolved値へ渡し、inline provenanceを重複なく返します。
    @Test("祖先inline strokeとcustom propertyを実描画childへ継承する")
    func testRenderingTargetsInheritAncestorInlineCascade() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon class="inline-ancestor" data-og-id="glyph" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="cdn" style="stroke-width: 2; --Icon-URL: url('inline-mask.svg');">
                <svg viewBox="0 0 24 24"><path id="inline-stroke-leaf" d="M1 1"></path></svg>
                <span class="inline-mask-leaf" aria-hidden="true"></span>
              </Icon>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            .inline-mask-leaf {
              mask-image: var(--Icon-URL);
              -webkit-mask-image: var(--Icon-URL);
            }
            """
        )

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let node = try #require(graph.nodes.first { $0.id == "glyph" })
        let strokeTarget = try #require(node.renderingTargets.first { $0.kind == "svg" })
        let maskTarget = try #require(node.renderingTargets.first { $0.kind == "mask" })

        // Then
        #expect(strokeTarget.tagName == "path")
        #expect(strokeTarget.authoredValues["stroke-width"] == nil)
        #expect(strokeTarget.resolvedValues["stroke-width"] == "2")
        #expect(strokeTarget.sourceTrace["stroke-width"]?.count == 1)
        #expect(strokeTarget.sourceTrace["stroke-width"]?.first?.selector == "<inline style>")
        #expect(strokeTarget.sourceTrace["stroke-width"]?.first?.inherited == true)
        #expect(maskTarget.resolvedValues["mask-image"] == "url('inline-mask.svg')")
        #expect(node.cssSourceTrace["stroke-width"]?.filter { $0.selector == "<inline style>" }.count == 1)

        // Given/When: author stylesheet importantはancestor inline normalより優先する
        try fixture.writeCompanionCSS(
            """
            .inline-ancestor {
              stroke-width: 4 !important;
              --icon-url: url('important-mask.svg') !important;
            }
            .inline-mask-leaf { mask-image: var(--icon-url); }
            """
        )
        let importantGraph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let importantNode = try #require(importantGraph.nodes.first { $0.id == "glyph" })

        // Then
        #expect(importantNode.renderingTargets.first { $0.kind == "svg" }?.resolvedValues["stroke-width"] == "4")
        #expect(importantNode.renderingTargets.first { $0.kind == "mask" }?.resolvedValues["mask-image"] == "url('important-mask.svg')")
    }

    /// 論理名（日本語）: Mask shorthand provenance編集テスト
    /// 概要: mask shorthandから実targetを検出し、shorthandを壊さず同selectorへlonghand overrideを追記します。
    @Test("mask shorthandを保持してmask-image longhandを追記できる")
    func testRelatedMaskEditingPreservesShorthandSource() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="cdn-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn"><span class="mask-shorthand" aria-hidden="true"></span></Icon>
            </body></html>
            """
        )
        let originalCSS = """
        .mask-shorthand {
          /* shorthand source must remain */
          mask: url('old.svg') center / contain no-repeat;
          -webkit-mask: url('old-webkit.svg') center / contain no-repeat;
          unknown-mask-property: keep-me;
        }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let iconNode = try #require(graph.nodes.first { $0.id == "cdn-icon" })
        let initialTarget = try #require(iconNode.renderingTargets.first { $0.kind == "mask" })
        _ = try fixture.core.setRelatedStyleDeclaration(
            "mask-image",
            value: "url('new.svg')",
            wrapperNodeID: "cdn-icon",
            htmlURL: fixture.htmlURL
        )
        let result = try fixture.core.setRelatedStyleDeclaration(
            "-webkit-mask-image",
            value: "url('new-webkit.svg')",
            wrapperNodeID: "cdn-icon",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(initialTarget.authoredValues["mask-image"] == "url('old.svg')")
        #expect(initialTarget.authoredValues["-webkit-mask-image"] == "url('old-webkit.svg')")
        #expect(initialTarget.sourceTrace["mask-image"]?.first?.authoredProperty == "mask")
        #expect(initialTarget.sourceTrace["-webkit-mask-image"]?.first?.authoredProperty == "-webkit-mask")
        #expect(result.updated == true)
        #expect(updatedCSS.contains("mask: url('old.svg') center / contain no-repeat;"))
        #expect(updatedCSS.contains("-webkit-mask: url('old-webkit.svg') center / contain no-repeat;"))
        #expect(updatedCSS.contains("/* shorthand source must remain */"))
        #expect(updatedCSS.contains("unknown-mask-property: keep-me;"))
        #expect(updatedCSS.contains("mask-image: url('new.svg');"))
        #expect(updatedCSS.contains("-webkit-mask-image: url('new-webkit.svg');"))
    }

    /// 論理名（日本語）: Mask child正本選択テスト
    /// 概要: wrapper自身のmask ruleを描画targetにせず、生成形のdirect childへ新しいmask-imageを保存します。
    @Test("wrapper maskを保持してdirect mask childへ保存する")
    func testRelatedMaskEditingExcludesWrapperTarget() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon id="mask-wrapper" data-og-id="cdn-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn"><span id="mask-child" aria-hidden="true"></span></Icon>
            </body></html>
            """
        )
        let originalCSS = "#mask-wrapper { mask-image: url('wrapper.svg'); }\n"
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let iconNode = try #require(graph.nodes.first { $0.id == "cdn-icon" })
        let initialTarget = try #require(iconNode.renderingTargets.first { $0.kind == "mask" })
        _ = try fixture.core.setRelatedStyleDeclaration(
            "mask-image",
            value: "url('child.svg')",
            wrapperNodeID: "cdn-icon",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(initialTarget.tagName == "span")
        #expect(initialTarget.writeSelector == "#mask-child")
        #expect(initialTarget.authoredValues["mask-image"] == nil)
        #expect(updatedCSS.contains(originalCSS))
        #expect(updatedCSS.contains("#mask-child {"))
        #expect(updatedCSS.contains("mask-image: url('child.svg');"))
    }

    /// 論理名（日本語）: Mask最深winner選択テスト
    /// 概要: 複数descendantにmask sourceがある場合、最深の実描画winnerを安定して編集します。
    @Test("maskは最深のauthored descendantを編集する")
    func testRelatedMaskEditingPrefersDeepestAuthoredDescendant() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="cdn-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn">
                <span id="mask-parent" aria-hidden="true"><i id="mask-leaf" aria-hidden="true"></i></span>
              </Icon>
            </body></html>
            """
        )
        let originalCSS = """
        #mask-parent { mask-image: url('parent.svg'); }
        #mask-leaf { mask-image: url('leaf.svg'); }
        """
        try fixture.writeCompanionCSS(originalCSS)

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let iconNode = try #require(graph.nodes.first { $0.id == "cdn-icon" })
        let initialTarget = try #require(iconNode.renderingTargets.first { $0.kind == "mask" })
        _ = try fixture.core.setRelatedStyleDeclaration(
            "mask-image",
            value: "url('updated.svg')",
            wrapperNodeID: "cdn-icon",
            htmlURL: fixture.htmlURL
        )
        let updatedCSS = try fixture.readCompanionCSS()

        // Then
        #expect(initialTarget.writeSelector == "#mask-leaf")
        #expect(updatedCSS.contains("#mask-parent { mask-image: url('parent.svg'); }"))
        #expect(updatedCSS.contains("#mask-leaf { mask-image: url('updated.svg'); }"))
    }

    /// 論理名（日本語）: Mask custom property解決テスト
    /// 概要: `:root`から継承したcustom propertyを実描画targetのresolved mask URLへ展開します。
    @Test("mask targetは継承custom propertyをresolved URLへ展開する")
    func testRenderingTargetResolvesInheritedMaskCustomProperty() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="cdn-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn"><span class="custom-mask" aria-hidden="true"></span></Icon>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            :root {
              --icon-url: url('https://cdn.jsdelivr.net/npm/lucide-static@0.468.0/icons/circle.svg');
            }

            .custom-mask {
              mask-image: var(--icon-url);
              -webkit-mask-image: var(--icon-url);
            }
            """
        )

        // When
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let iconNode = try #require(graph.nodes.first { $0.id == "cdn-icon" })
        let target = try #require(iconNode.renderingTargets.first { $0.kind == "mask" })

        // Then
        #expect(target.authoredValues["mask-image"] == "var(--icon-url)")
        #expect(target.resolvedValues["mask-image"] == "url('https://cdn.jsdelivr.net/npm/lucide-static@0.468.0/icons/circle.svg')")
        #expect(target.resolvedValues["-webkit-mask-image"] == "url('https://cdn.jsdelivr.net/npm/lucide-static@0.468.0/icons/circle.svg')")
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

    /// 論理名（日本語）: CDNからinlineへのアイコンsource移行テスト
    /// 概要: 旧mask sourceだけを削除し、対象外nodeと未知CSSおよびlegacy inputを暗黙変換しないことを確認します。
    @Test("CDNからinlineへの更新は旧maskだけを削除して無関係sourceを保持する")
    func testSetIconFromCDNToInlineCleansMaskWithoutImplicitMigration() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let untouchedFrame = #"<Frame data-og-id="untouched" data-og-internal-id="untouched" data-og-type="frame" style="gap: 7px; --og-icon-url: url('legacy.svg');" data-extra="keep"></Frame>"#
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Icon data-og-id="target-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn">
                <span aria-hidden="true"></span>
              </Icon>
              <Icon data-og-id="sibling-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="cdn">
                <span aria-hidden="true"></span>
              </Icon>
              \(untouchedFrame)
            </body></html>
            """
        )
        let siblingRule = """
        [data-og-internal-id="sibling-icon"] > span {
          mask-image: url('sibling.svg');
          -webkit-mask-image: url('sibling.svg');
        }
        """
        let unrelatedRule = """
        .legacy-input {
          --og-icon-url: url('legacy-only.svg');
          unknown-property: keep-me;
        }
        """
        try fixture.writeCompanionCSS(
            """
            /* target source comment */
            [data-og-internal-id="target-icon"] > span {
              mask-image: url('target.svg');
              -webkit-mask-image: url('target.svg');
              target-only-unknown: keep-target-rule;
            }

            \(siblingRule)

            \(unrelatedRule)
            """
        )

        // When
        let result = try fixture.core.setIcon(
            library: "lucide",
            name: "star",
            source: "inline",
            nodeID: "target-icon",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // Then
        #expect(result.updated == true)
        #expect(result.node?.renderingTargets.map(\.kind) == ["svg"])
        #expect(html.contains("data-og-icon-name=\"star\""))
        #expect(html.contains("<svg xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(!html.contains("data-og-icon-mask"))
        #expect(html.contains(untouchedFrame))
        #expect(css.contains("/* target source comment */"))
        #expect(css.contains("target-only-unknown: keep-target-rule;"))
        #expect(!css.contains("url('target.svg')"))
        #expect(css.contains(siblingRule))
        #expect(css.contains(unrelatedRule))
        #expect(css.contains("--og-icon-url: url('legacy-only.svg');"))
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
            <html><body><div data-og-id="hero" data-og-type="frame"></div></body></html>
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
        let css = try fixture.readCompanionCSS()

        // 期待値：新規 icon node が挿入され、Lucide static CDN 参照を保持する（Then）
        #expect(result.updated == true)
        #expect(result.insertedNodes?.map(\.id) == ["icon-star"])
        #expect(result.insertedNodes?.first?.internalID.isEmpty == false)
        #expect(result.insertedNodes?.first?.internalID != "hero")
        #expect(result.insertedNodes?.first?.attributes["data-og-icon-source"] == "cdn")
        #expect(html.contains("data-og-internal-id="))
        #expect(html.contains("<span aria-hidden=\"true\"></span>"))
        #expect(!html.contains("data-og-icon-mask"))
        #expect(!html.contains("https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg"))
        #expect(!html.contains("--og-"))
        #expect(css.contains("> span"))
        #expect(css.contains("mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(css.contains("-webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(!css.contains("--og-icon-url"))
        #expect(css.contains("width: 24px;"))
        #expect(css.contains("height: 24px;"))
        if let internalID = result.insertedNodes?.first?.internalID,
           let wrapperRuleStart = css.range(of: #"[data-og-internal-id="\#(internalID)"] {"#),
           let wrapperRuleEnd = css[wrapperRuleStart.upperBound...].firstIndex(of: "}") {
            let wrapperBody = String(css[wrapperRuleStart.upperBound..<wrapperRuleEnd])
            #expect(wrapperBody.contains("width: 24px;"))
            #expect(wrapperBody.contains("height: 24px;"))
            #expect(!wrapperBody.contains("mask-image"))
            #expect(css.contains(#"[data-og-internal-id="\#(internalID)"] > span {"#))
        } else {
            Issue.record("inserted iconのwrapper/child CSS ruleを解決できません。")
        }
    }

    /// 論理名（日本語）: Placement Mock Stateラウンドトリップテスト
    /// 概要: `.ogp` previewContext が内部 ID ごとの汎用 host field を正規化して保持できることを確認します。
    @Test("previewContextは汎用host fieldのplacementMocksをラウンドトリップできる")
    func testPreviewContextDecodesPlacementMocks() throws {
        // コンディション：code・preview・loading・collapsedを内部ID単位の汎用host fieldで表したJSONを用意する（Given）
        let json = """
        {
          "locale": "ja-JP",
          "direction": "ltr",
          "fieldMocks": {
            "selectedLanguage": "ja"
          },
          "placementMocks": {
            " code-placement-internal ": {
              " host.variant ": "code"
            },
            "preview-placement-internal": {
              "host.variant": "preview"
            },
            "loading-placement-internal": {
              "host.class": "is-loading",
              "host.aria-busy": "true"
            },
            "collapsed-placement-internal": {
              "host.variant": "collapsed"
            }
          }
        }
        """
        let context = try JSONDecoder().decode(OpenGraphitePreviewContext.self, from: Data(json.utf8))

        // 検証内容：contextを再エンコードし、そのJSONをもう一度デコードする（When）
        let encodedData = try JSONEncoder().encode(context)
        let encoded = String(data: encodedData, encoding: .utf8) ?? ""
        let roundTripped = try JSONDecoder().decode(OpenGraphitePreviewContext.self, from: encodedData)

        // 期待値：内部IDと汎用fieldは正規化後も保たれ、旧locale・directionと旧状態属性は再保存されない（Then）
        #expect(context.locale == "ja-JP")
        #expect(context.direction == "ltr")
        #expect(context.fieldMocks["selectedLanguage"] == "ja")
        #expect(context.placementMocks["code-placement-internal"]?["host.variant"] == "code")
        #expect(context.placementMocks["preview-placement-internal"]?["host.variant"] == "preview")
        #expect(context.placementMocks["loading-placement-internal"]?["host.class"] == "is-loading")
        #expect(context.placementMocks["loading-placement-internal"]?["host.aria-busy"] == "true")
        #expect(context.placementMocks["collapsed-placement-internal"]?["host.variant"] == "collapsed")
        #expect(context.placementMocks[" code-placement-internal "] == nil)
        #expect(roundTripped == OpenGraphitePreviewContext(
            fieldMocks: ["selectedLanguage": "ja"],
            placementMocks: context.placementMocks
        ))
        #expect(encoded.contains("placementMocks"))
        #expect(!encoded.contains("locale"))
        #expect(!encoded.contains("direction"))
        #expect(!encoded.contains("data-og-placement-mode"))
        #expect(!encoded.contains("data-og-state-hidden"))
        #expect(!encoded.contains("data-og-state-visible"))
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
                <Button data-og-id="download-button" data-og-type="button">Download</Button>
                <Button data-og-id="docs-button" data-og-type="button">Docs</Button>
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

    /// 論理名（日本語）: i18n locale resource自動検出テスト
    /// 概要: literal loadPath から実在する追加 locale JSON を検出することを確認します。
    @Test("i18n inspectはliteral loadPath配下の追加locale JSONを検出する")
    func testI18nInspectDiscoversExistingLocaleResources() throws {
        // コンディション：loadPath 配下に default 以外の locale JSON を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><script src="./i18n.js"></script></head><body>
              <Title data-og-id="title" data-og-type="text" data-og-text-source="binding" data-i18n-key="home.title">日本語</Title>
            </body></html>
            """
        )
        try """
        i18n.init({
          lng: "ja",
          fallbackLng: "ja",
          backend: { loadPath: "/locales/{{lng}}.json" }
        });
        """.write(to: fixture.rootURL.appendingPathComponent("i18n.js"), atomically: true, encoding: .utf8)
        let localeDirectory = fixture.rootURL.appendingPathComponent("locales")
        try FileManager.default.createDirectory(at: localeDirectory, withIntermediateDirectories: true)
        try #"{"home.title":"Titre"}"#.write(
            to: localeDirectory.appendingPathComponent("fr.json"),
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：i18n runtime を検査する（When）
        let result = try fixture.core.inspectI18n(projectURL: projectURL, pageID: "home")

        // 期待値：明示指定していない fr locale resource も候補として返る（Then）
        #expect(result.resources.contains { $0.locale == "fr" && $0.exists && $0.editable })
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
                <Button data-og-id="nav-home" data-og-type="button">Home</Button>
              </Header>
            """

        // 検証内容：page の先頭へ header を挿入する
        let result = try fixture.core.prependChildHTML(headerHTML, parentNodeID: "page", htmlURL: fixture.htmlURL)
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：挿入 node が page 直下で hero より前に現れる
        #expect(result.updated == true)
        #expect(result.insertedNodes?.map(\.id) == ["site-header", "nav-home"])
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id).prefix(4) == ["page", "site-header", "nav-home", "hero"])
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
            "<Eyebrow data-og-id=\"eyebrow\" data-og-type=\"text\">Intro</Eyebrow>",
            anchorNodeID: "hero",
            position: .before,
            htmlURL: fixture.htmlURL
        )
        _ = try fixture.core.insertHTML(
            "<CTA data-og-id=\"cta\" data-og-type=\"button\">Start</CTA>",
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
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["page", "eyebrow", "hero", "cta", "footer", "footer-text"])
        #expect(graph.nodes.first { $0.id == "footer-text" }?.parentID == "footer")
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: 未注釈fragment保持テスト
    /// 概要: insert/replaceの明示編集でも標準HTML fragmentへOpenGraphite identityを暗黙追加しないことを確認します。
    @Test("HTML fragmentのinsertとreplaceは暗黙adoptしない")
    func testInsertAndReplacePreserveUnannotatedFragments() throws {
        // コンディション：mutation anchorだけがstable identityを持つHTMLを補完せず用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeRawHTML(
            "<!doctype html><html><body><main data-og-id=\"page\" data-og-internal-id=\"page-node\"><div data-og-id=\"target\" data-og-internal-id=\"target-node\"></div></main></body></html>"
        )

        // 検証内容：未注釈のvendor fragmentをinsertし、既存targetも未注釈fragmentへreplaceする（When）
        let inserted = try fixture.core.insertHTML(
            "<section id=\"vendor\"><p>Raw insert</p></section>",
            anchorNodeID: "page-node",
            position: .append,
            htmlURL: fixture.htmlURL
        )
        let replaced = try fixture.core.replaceNodeHTML(
            "<article class=\"replacement\"><em>Raw replacement</em></article>",
            nodeID: "target-node",
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // 期待値：authored fragment bytesにannotationを足さず、全nodeはsession inspection可能である（Then）
        #expect(inserted.updated == true)
        #expect(replaced.updated == true)
        #expect(html.contains("<section id=\"vendor\"><p>Raw insert</p></section>"))
        #expect(html.contains("<article class=\"replacement\"><em>Raw replacement</em></article>"))
        #expect(graph.nodes.first { $0.tagName == "section" }?.annotationStatus == OpenGraphiteNodeAnnotationStatus.none)
        #expect(graph.nodes.first { $0.tagName == "article" }?.annotationStatus == OpenGraphiteNodeAnnotationStatus.none)
        #expect(graph.nodes.first { $0.tagName == "em" }?.referenceStability == .session)
        #expect(graph.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: HTML挿入inline style移行テスト
    /// 概要: HTML断片挿入時の editable design value が inline style ではなく companion CSS に保存されることを検証します。
    @Test("HTML断片挿入時のinline design valueをcompanion CSSへ保存する")
    func testInsertHTMLMigratesInlineDesignValuesToCompanionCSS() throws {
        // コンディション：page root だけを持つ HTML を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body><Page data-og-id="page" data-og-internal-id="page-node" data-og-type="page"></Page></body></html>
            """
        )

        // 検証内容：style 属性付き frame HTML を page 直下へ挿入する
        let result = try fixture.core.insertHTML(
            #"<Frame data-og-id="frame" data-og-internal-id="frame-node" data-og-type="frame" style="position:absolute; left:12px; top:24px; width:160px; height:90px;"></Frame>"#,
            anchorNodeID: "page-node",
            position: .append,
            htmlURL: fixture.htmlURL
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：HTML には構造だけが残り、配置値は companion CSS に保存される
        #expect(result.updated == true)
        #expect(result.insertedNodes?.first?.internalID == "frame-node")
        #expect(!html.contains("style="))
        #expect(css.contains(#"[data-og-internal-id="frame-node"]"#))
        #expect(css.contains("position: absolute;"))
        #expect(css.contains("left: 12px;"))
        #expect(css.contains("top: 24px;"))
        #expect(css.contains("width: 160px;"))
        #expect(css.contains("height: 90px;"))
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
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["page", "hero", "title"])
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
            <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"><Title data-og-id="title" data-og-type="text">Hero</Title><AuxData data-og-internal-id="metadata-node"><em>Loose</em></AuxData></Hero><Footer data-og-id="footer" data-og-type="frame"></Footer></Page></body></html>
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
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["page", "footer", "copy-hero", "copy-title", "hero", "title"])
        let partialCopies = graph.nodes.filter { $0.tagName == "auxdata" }
        #expect(partialCopies.count == 2)
        #expect(Set(partialCopies.map(\.internalID)).count == 2)
        #expect(partialCopies.contains { $0.internalID == "metadata-node" })
        #expect(partialCopies.allSatisfy { $0.annotationStatus == .partial && $0.referenceStability == .stable })
        #expect(graph.nodes.filter { $0.tagName == "em" }.allSatisfy {
            $0.annotationStatus == .none && $0.referenceStability == .session
        })
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
        try fixture.writeCSSLibrary("")

        // 検証内容：standalone HTML を作成する
        let result = try fixture.core.createPage(
            at: fixture.htmlURL,
            title: "Created Page",
            lang: "ja",
            stylesheetPath: "./OpenGraphite.css",
            bodyHTML: bodyHTML,
            overwrite: false
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：入力annotationを暗黙補完せずHTML fileと空companion CSSが保存される
        #expect(result.created == true)
        #expect(html.contains("<title>Created Page</title>"))
        #expect(!html.contains("data-og-internal-id="))
        #expect(css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.graph?.nodes.first?.cssVariables["background"] == nil)
        #expect(result.graph?.nodes.first?.cssVariables["color"] == nil)
        #expect(result.graph?.nodes.first?.cssVariables["min-height"] == nil)
        #expect(result.graph?.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["page", "title"])
        #expect(result.graph?.nodes.filter { !$0.id.isEmpty }.allSatisfy {
            $0.internalID.isEmpty && $0.annotationStatus == .partial && $0.referenceStability == .session
        } == true)
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
        let downloadsHTMLURL = fixture.rootURL.appendingPathComponent("downloads.html")
        let downloadsCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: downloadsHTMLURL)
        try """
        [data-og-internal-id="page"] {
          color: rgb(12, 12, 12);
        }
        """.write(to: downloadsCSSURL, atomically: true, encoding: .utf8)
        let originalDownloadsHTML = try String(contentsOf: downloadsHTMLURL, encoding: .utf8)
        let originalDownloadsCSS = try String(contentsOf: downloadsCSSURL, encoding: .utf8)
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
        let finalDownloadsHTML = try String(contentsOf: downloadsHTMLURL, encoding: .utf8)
        let finalDownloadsCSS = try String(contentsOf: downloadsCSSURL, encoding: .utf8)
        #expect(finalDownloadsHTML == originalDownloadsHTML)
        #expect(finalDownloadsCSS == originalDownloadsCSS)
        #expect(!finalDownloadsHTML.contains("--og-edit-width"))
        #expect(!finalDownloadsHTML.contains("--og-edit-min-height"))
        #expect(!finalDownloadsCSS.contains("--og-edit-width"))
        #expect(!finalDownloadsCSS.contains("--og-edit-min-height"))
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
        let homeCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        #expect(!FileManager.default.fileExists(atPath: homeCompanionCSSURL.path))
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
        #expect(!FileManager.default.fileExists(atPath: homeCompanionCSSURL.path))
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
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="page"] {
              background: white;
            }
            """
        )
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let originalCSS = try fixture.readCompanionCSS()
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
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let finalCSS = try fixture.readCompanionCSS()
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
        #expect(!finalHTML.contains("--og-edit-width"))
        #expect(!finalHTML.contains("--og-edit-min-height"))
        #expect(!finalCSS.contains("--og-edit-width"))
        #expect(!finalCSS.contains("--og-edit-min-height"))
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
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["docs-page"])
        #expect(graph.nodes.filter { !$0.internalID.isEmpty }.map(\.internalID) == ["node-opaque"])
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
              <feature-card data-og-id="feature-card-master" data-og-component="feature-card" part="root">
                <template><slot name="title"><span data-og-id="title">Feature</span></slot></template>
              </feature-card>
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
            <html><body><Hero data-og-id="hero" data-og-type="frame"></Hero></body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero"] {
              gap: 24px;
            }
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
                "--var", "gap",
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
                "--var", "gap",
                "--value", "40px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：`.ogp` 経由の編集だけが成功し、直接 HTML 指定はエラーになり、値は companion CSS に残る
        #expect(successCode == 0)
        #expect(rejectedCode == 2)
        #expect(!html.contains("gap"))
        #expect(css.contains("gap: 32px;"))
        #expect(!css.contains("40px"))
        #expect(stderr.contains(".ogp"))
    }

    /// 論理名（日本語）: CLI実描画CSS透過routeテスト
    /// 概要: 既存`node style set`がwrapper IDを保ったまま未注釈imgの標準object-fitへ到達することを確認します。
    @Test("CLI node style setは実描画childへ標準CSSを保存する")
    func testCLIStyleSetRoutesStandardMediaPropertyToRenderingTarget() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <figure id="media-wrapper" data-og-id="media" data-og-type="image"><img src="hero.png" alt=""></figure>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS("/* keep CLI source */\n")
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // When
        let code = cli.run(
            arguments: [
                "node", "style", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "media",
                "--var", "object-fit",
                "--value", "cover"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let css = try fixture.readCompanionCSS()
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)

        // Then
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(css.contains("#media-wrapper > img"))
        #expect(css.contains("object-fit: cover;"))
        #expect(!css.contains("--og-object-fit"))
        #expect(graph.nodes.first { $0.id == "media" }?.renderingTargets.first { $0.kind == "media" }?.authoredValues["object-fit"] == "cover")
    }

    /// 論理名（日本語）: CLI標準scale編集テスト
    /// 概要: `node style set/remove`が標準`scale` sourceだけを編集し、legacy helperとtransform compositionを保持します。
    @Test("CLI node style setとremoveは標準scaleだけを編集する")
    func testCLIStyleSetAndRemoveEditOnlyStandardScale() throws {
        // コンディション：legacy helperをHTML、標準scaleと他のtransformをcompanion CSSに持つprojectを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <div id="flip-card" data-og-id="flip" data-og-type="frame" style="--og-scale-x:-1; --og-scale-y:1;"></div>
            </body></html>
            """
        )
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            #flip-card {
              transform: rotate(12deg);
              rotate: 3deg;
            }
            """
        )
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var setStdout = ""
        var setStderr = ""

        // 検証内容：CLIでscaleを設定し、同じrouteから削除する（When）
        let setCode = cli.run(
            arguments: [
                "node", "style", "set", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "flip",
                "--var", "scale",
                "--value", "-1 1"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { setStdout += $0 },
            stderr: { setStderr += $0 }
        )
        let setCSS = try fixture.readCompanionCSS()
        var removeStdout = ""
        var removeStderr = ""
        let removeCode = cli.run(
            arguments: [
                "node", "style", "remove", "Sample.ogp",
                "--page-id", fixture.homePageInternalID,
                "--id", "flip",
                "--var", "scale"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { removeStdout += $0 },
            stderr: { removeStderr += $0 }
        )
        let removedCSS = try fixture.readCompanionCSS()
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：set/removeは成功し、標準scale以外のsourceとlegacy HTMLは変化しない（Then）
        #expect(setCode == 0)
        #expect(setStderr.isEmpty)
        #expect(setStdout.contains("\"updated\" : true"))
        #expect(setCSS.contains("scale: -1 1;"))
        #expect(removeCode == 0)
        #expect(removeStderr.isEmpty)
        #expect(removeStdout.contains("\"updated\" : true"))
        #expect(!removedCSS.contains("scale:"))
        #expect(removedCSS.contains("transform: rotate(12deg);"))
        #expect(removedCSS.contains("rotate: 3deg;"))
        #expect(finalHTML == originalHTML)
        #expect(finalHTML.contains("--og-scale-x:-1"))
        #expect(finalHTML.contains("--og-scale-y:1"))
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
                <span aria-hidden="true"></span>
              </Icon>
              <Icon data-og-id="sibling-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="panel-left-open" data-og-icon-source="cdn">
                <span aria-hidden="true"></span>
              </Icon>
            </body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="target-icon"] > span {
              mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/circle.svg');
              -webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/circle.svg');
            }

            [data-og-internal-id="sibling-icon"] > span {
              mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');
              -webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');
            }
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
        let css = try fixture.readCompanionCSS()

        // 期待値：対象 icon は更新され、対象外 icon の CDN mask URL は companion CSS に保持される（Then）
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(!html.contains("--og-icon-url"))
        #expect(!html.contains("data-og-icon-mask"))
        #expect(css.contains("mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(css.contains("-webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(css.contains("mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');"))
        #expect(css.contains("-webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');"))
        #expect(!css.contains("--og-icon-url"))
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
            <html><body><Hero data-og-id="hero" data-og-type="frame"></Hero></body></html>
            """
        )
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero"] {
              gap: 24px;
            }
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
                "--var", "gap",
                "--value", "40px"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let css = try fixture.readCompanionCSS()

        // 期待値：typed node 参照から page と node が解決され、companion CSS が更新される
        #expect(code == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"updated\" : true"))
        #expect(!html.contains("gap"))
        #expect(css.contains("gap: 40px;"))
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

    /// 論理名（日本語）: CLIコンポーネントPlacement Mock部分更新テスト
    /// 概要: `ogkiln project component place` が内部 ID ごとの汎用 host field を部分更新し、空値とHTML正本を保持することを確認します。
    @Test("CLIはcomponent placementの汎用host fieldだけを部分更新できる")
    func testCLIProjectComponentPlaceUpdatesPlacementMocks() throws {
        // コンディション：4状態のplacement hostを持つcomponent HTMLとproject manifestを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            """
            <!doctype html><html><body><Cards data-og-id="cards" data-og-type="page">
              <og-placement data-og-id="code" data-og-internal-id="code-placement-internal"></og-placement>
              <og-placement data-og-id="preview" data-og-internal-id="preview-placement-internal"></og-placement>
              <og-placement data-og-id="loading" data-og-internal-id="loading-placement-internal"></og-placement>
              <og-placement data-og-id="collapsed" data-og-internal-id="collapsed-placement-internal"></og-placement>
            </Cards></body></html>
            """,
            to: componentURL
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        let componentCSSURL = fixture.rootURL.appendingPathComponent("cards.css")
        try fixture.writeCSSLibrary("/* shared source must remain byte-identical */\n")
        try "/* component source must remain byte-identical */\n".write(
            to: componentCSSURL,
            atomically: true,
            encoding: .utf8
        )
        let originalPageHTML = try Data(contentsOf: fixture.htmlURL)
        let originalComponentHTML = try Data(contentsOf: componentURL)
        let originalLibraryCSS = try fixture.readCSSLibrary()
        let originalComponentCSS = try Data(contentsOf: componentCSSURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：汎用fieldを初期保存後、別fieldを維持したままvariant・ariaと空classを更新する（When）
        let initialCode = cli.run(
            arguments: [
                "project", "component", "place", "Sample.ogp",
                "--component-id", fixture.componentPageInternalID,
                "--preview-placement-mock", "code-placement-internal:host.variant=code",
                "--preview-placement-mock", "preview-placement-internal:host.variant=code",
                "--preview-placement-mock", "preview-placement-internal:host.class=is-preview",
                "--preview-placement-mock", "loading-placement-internal:host.class=is-loading",
                "--preview-placement-mock", "loading-placement-internal:host.aria-busy=false",
                "--preview-placement-mock", "collapsed-placement-internal:host.variant=collapsed",
                "--preview-placement-mock", "empty-placement-internal:host.class=is-temporary"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let updateCode = cli.run(
            arguments: [
                "project", "component", "place", "Sample.ogp",
                "--component-id", fixture.componentPageInternalID,
                "--preview-placement-mock", "preview-placement-internal:host.variant=preview",
                "--preview-placement-mock", "preview-placement-internal:host.class=",
                "--preview-placement-mock", "loading-placement-internal:host.aria-busy=true",
                "--preview-placement-mock", "empty-placement-internal:host.class="
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let previewContext = loadedProject.project.collections[0].components[0].canvas.previewContext

        // 期待値：内部IDごとの4状態と部分更新・有効な空値がmanifestへ反映され、HTML bytesは不変である（Then）
        #expect(initialCode == 0)
        #expect(updateCode == 0)
        #expect(stderr.isEmpty)
        #expect(stdout.contains("\"placementMocks\""))
        #expect(previewContext.placementMocks["code-placement-internal"] == ["host.variant": "code"])
        #expect(previewContext.placementMocks["preview-placement-internal"] == [
            "host.variant": "preview",
            "host.class": ""
        ])
        #expect(previewContext.placementMocks["loading-placement-internal"] == [
            "host.class": "is-loading",
            "host.aria-busy": "true"
        ])
        #expect(previewContext.placementMocks["collapsed-placement-internal"] == ["host.variant": "collapsed"])
        #expect(previewContext.placementMocks["empty-placement-internal"] == ["host.class": ""])
        #expect(previewContext.placementMocks["code"] == nil)
        #expect(try Data(contentsOf: fixture.htmlURL) == originalPageHTML)
        #expect(try Data(contentsOf: componentURL) == originalComponentHTML)
        #expect(try fixture.readCSSLibrary() == originalLibraryCSS)
        #expect(try Data(contentsOf: componentCSSURL) == originalComponentCSS)
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
        let contractObject = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: contractURL)) as? [String: Any]
        )

        // 期待値：legacy type enum/edit属性はなく、標準layout・visibility・wrap宣言が契約に含まれる
        #expect(contractObject["types"] == nil)
        #expect(contract.layouts.isEmpty)
        #expect(contract.editableAttributeSet.contains("hidden"))
        for attribute in ["href", "target", "aria-label", "value", "src", "alt"] {
            #expect(contract.editableAttributeSet.contains(attribute))
        }
        #expect(!contract.editableAttributeSet.contains("data-og-type"))
        #expect(!contract.editableAttributeSet.contains("data-og-layout"))
        #expect(!contract.editableAttributeSet.contains("data-og-hidden"))
        for property in [
            "display", "flex-direction",
            "grid-template-columns", "grid-template-rows",
            "grid-auto-columns", "grid-auto-rows", "grid-auto-flow",
            "grid-column", "grid-row", "visibility", "overflow-wrap"
        ] {
            #expect(contract.cssVariables.contains { $0.name == property && $0.editable })
        }
        #expect(contract.cssVariables.contains {
            $0.name == "display"
                && $0.syntax.contains("<display-outside> || <display-inside>")
                && $0.editable
        })
        #expect(contract.capabilityPolicy == .builtIn)
        #expect(contract.capabilityPolicy.operations == OpenGraphiteNodeCapability.allCases.map(\.rawValue).sorted())
        #expect(contract.capabilityPolicy.operations.count == 11)
        #expect(contract.capabilityPolicy.evidenceFields == [
            "isProjectResourceRoot", "isNativeControl", "isCustomElement", "isLink",
            "hasDirectText", "hasElementChildren", "hasMediaContent", "hasSVGContent",
            "hasMaskContent", "ariaRole", "resolvedDisplay"
        ])
        #expect(contract.capabilityPolicy.legacyTypeAttribute == "data-og-type")
        #expect(contract.capabilityPolicy.legacyReadOnlyHint == true)
        #expect(contract.capabilityPolicy.generated == false)
        #expect(contract.capabilityPolicy.queryMatch == "all")
        #expect(contract.cssVariables.contains { $0.name == "gap" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "position" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "left" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "top" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "right" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "bottom" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "z-index" && $0.category == "position" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "font-family" && $0.category == "text" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "object-fit" && $0.category == "media" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "stroke-width" && $0.category == "icon" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "mask-image" && $0.category == "icon" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "-webkit-mask-image" && $0.category == "icon" && $0.editable })
        #expect(contract.cssVariables.contains {
            $0.name == "scale"
                && $0.category == "transform"
                && $0.syntax == "none|[<number>|<percentage>]{1,3}"
                && $0.editable
        })
        #expect(!contract.cssVariableSet.contains("--og-object-fit"))
        #expect(!contract.cssVariableSet.contains("--og-stroke-width"))
        #expect(!contract.cssVariableSet.contains("--og-icon-url"))
        #expect(!contract.cssVariableSet.contains("--og-scale-x"))
        #expect(!contract.cssVariableSet.contains("--og-scale-y"))
        #expect(!contract.editableAttributeSet.contains("data-og-icon-mask"))
        #expect(!contract.cssVariables.contains { $0.name == "--og-font-family-default" })
        #expect(!contract.cssVariables.contains { $0.name == "--og-active-font-family" })
        #expect(contract.cssVariables.contains { $0.name == "animation-name" && $0.category == "animation" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "animation-timeline" && $0.category == "scroll-animation" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "animation-range-start" && $0.category == "scroll-animation" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "timeline-scope" && $0.category == "scroll-animation" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "scroll-timeline-name" && $0.category == "scroll-animation" && $0.editable })
        #expect(contract.cssVariables.contains { $0.name == "view-timeline-name" && $0.category == "scroll-animation" && $0.editable })
        #expect(!contract.isKnownCSSVariable("--og-font-family-fr"))
        #expect(contract.cssVariablePatterns.isEmpty)
    }

    /// 論理名（日本語）: Optional annotation policy契約同期テスト
    /// 概要: repository JSONとbuilt-in定義がinspection非破壊性、状態値、明示adoption guardを同じ値で公開することを確認します。
    @Test("optional annotationと明示adoption policyをcontractで同期する")
    func testOptionalAnnotationPolicyContractParity() throws {
        // コンディション：repository contractとbuilt-in contractを読み込む（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryPolicy = try OpenGraphiteContract.load(from: contractURL).annotationPolicy
        let builtInPolicy = OpenGraphiteContract.builtIn.annotationPolicy

        // 検証内容：optional identity、inspection、reference、adoption policyを比較する（When）
        let adoption = repositoryPolicy.adoption

        // 期待値：source mutationなしのinspectionとreviewed diff経由だけのadoptionが機械可読に固定される（Then）
        #expect(repositoryPolicy == builtInPolicy)
        #expect(repositoryPolicy.identityAttributes == ["data-og-id", "data-og-internal-id"])
        #expect(repositoryPolicy.requiredForInspection == false)
        #expect(repositoryPolicy.missingIsValidationError == false)
        #expect(repositoryPolicy.inspectionMutatesSource == false)
        #expect(repositoryPolicy.annotationStatuses == ["none", "partial", "complete"])
        #expect(repositoryPolicy.referenceStabilities == ["session", "stable"])
        #expect(adoption.explicit == true)
        #expect(adoption.dryRunDefault == true)
        #expect(adoption.diffRequired == true)
        #expect(adoption.locatorPreference == ["standard-id", "safe-selector", "dom-path"])
        #expect(adoption.staleGuards == ["source-range", "content-hash", "document-content-hash", "proposal-parameters"])
    }

    /// 論理名（日本語）: 標準scale契約同期テスト
    /// 概要: repository JSONとbuilt-in contractが標準`scale`を公開し、legacy scale helperを予約しないことを確認します。
    @Test("標準scale contractを同期してlegacy scale helperを予約しない")
    func testStandardScaleContractReplacesLegacyScaleHelpers() throws {
        // コンディション：repository contractとbuilt-in contractを読み込む（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryContract = try OpenGraphiteContract.load(from: contractURL)
        let builtInContract = OpenGraphiteContract.builtIn

        // 検証内容：scale定義とlegacy helperの既知判定を比較する（When）
        let repositoryScale = repositoryContract.cssVariables.first { $0.name == "scale" }
        let builtInScale = builtInContract.cssVariables.first { $0.name == "scale" }

        // 期待値：両contractは一致し、標準scaleだけが編集可能なtransform契約として残る（Then）
        #expect(repositoryContract == builtInContract)
        #expect(repositoryScale == builtInScale)
        #expect(repositoryScale?.category == "transform")
        #expect(repositoryScale?.syntax == "none|[<number>|<percentage>]{1,3}")
        #expect(repositoryScale?.editable == true)
        #expect(repositoryContract.isKnownCSSVariable("scale"))
        #expect(!repositoryContract.isKnownCSSVariable("--og-scale-x"))
        #expect(!repositoryContract.isKnownCSSVariable("--og-scale-y"))
    }

    /// 論理名（日本語）: Theme reserved property契約同期テスト
    /// 概要: repository JSONとbuilt-in定義を同期し、旧theme custom propertyを予約契約とCanvas固定集合から除外します。
    @Test("旧theme propertyを予約せずcontractとbuilt-inを同期する")
    func testLegacyThemePropertiesAreNotReservedAndContractsRemainInParity() throws {
        // コンディション：repository contract、built-in contract、WebCanvas sourceと旧theme名を用意する（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryRootURL = contractURL.deletingLastPathComponent()
        let repositoryContract = try OpenGraphiteContract.load(from: contractURL)
        let builtInContract = OpenGraphiteContract.builtIn
        let webCanvasSource = try String(
            contentsOf: repositoryRootURL.appendingPathComponent("App/Sources/Editor/WebCanvasView.swift"),
            encoding: .utf8
        )
        let legacyThemeNames = [
            "--og-page-background",
            "--og-text-color",
            "--og-muted-color",
            "--og-accent",
            "--og-accent-foreground"
        ]

        // 検証内容：JSON/built-in parity、reserved判定、Canvas固定集合への混入を調べる（When）
        let repositoryNames = repositoryContract.cssVariableSet
        let builtInNames = builtInContract.cssVariableSet

        // 期待値：両contractは一致し、標準propertyとgeneric token契約だけがtheme表現を担う（Then）
        #expect(repositoryContract == builtInContract)
        #expect(repositoryNames == builtInNames)
        #expect(repositoryContract.isKnownCSSVariable("background"))
        #expect(repositoryContract.isKnownCSSVariable("color"))
        #expect(repositoryContract.isValidDesignTokenName("--color-page-background"))
        #expect(repositoryContract.isValidDesignTokenName("--color-accent"))
        #expect(!repositoryContract.cssVariables.contains { $0.category == "theme" })
        for name in legacyThemeNames {
            #expect(!repositoryNames.contains(name))
            #expect(!builtInNames.contains(name))
            #expect(!repositoryContract.isKnownCSSVariable(name))
            #expect(!webCanvasSource.contains(name))
        }
    }

    /// 論理名（日本語）: editor helper公開契約除外テスト
    /// 概要: runtime-only の editor helper が機械可読契約と配布 CSS へ再混入しないことを検証します。
    @Test("editor helperを公開contractと配布CSSへ含めない")
    func testDistributedContractExcludesLegacyEditorHelpers() throws {
        // コンディション：repository contract と配布 OpenGraphite.css を読み込む（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryRootURL = contractURL.deletingLastPathComponent()
        let contractSource = try String(contentsOf: contractURL, encoding: .utf8)
        let distributedCSS = try String(
            contentsOf: repositoryRootURL.appendingPathComponent("CSS/OpenGraphite.css"),
            encoding: .utf8
        )
        let contract = try OpenGraphiteContract.load(from: contractURL)
        let forbiddenIdentifiers = [
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

        // 検証内容：禁止識別子の公開 source と decoded contract への混入を調べる（When）
        let persistedRuntimeAttributes = Set(contract.runtimeAttributes)
        let declaredCSSProperties = Set(contract.cssVariables.map(\.name))
        let builtInRuntimeAttributes = Set(OpenGraphiteContract.builtIn.runtimeAttributes)
        let builtInCSSProperties = Set(OpenGraphiteContract.builtIn.cssVariables.map(\.name))

        // 期待値：legacy helper は JSON / built-in 相当の公開列挙と配布 CSS に存在しない（Then）
        for identifier in forbiddenIdentifiers {
            #expect(!contractSource.contains(identifier))
            #expect(!distributedCSS.contains(identifier))
        }
        #expect(!persistedRuntimeAttributes.contains("data-og-selected"))
        #expect(!persistedRuntimeAttributes.contains("data-og-editing"))
        #expect(persistedRuntimeAttributes.isEmpty)
        #expect(!declaredCSSProperties.contains("--og-edit-width"))
        #expect(!declaredCSSProperties.contains("--og-edit-min-height"))
        #expect(!builtInRuntimeAttributes.contains("data-og-selected"))
        #expect(!builtInRuntimeAttributes.contains("data-og-editing"))
        #expect(builtInRuntimeAttributes.isEmpty)
        #expect(!builtInCSSProperties.contains("--og-edit-width"))
        #expect(!builtInCSSProperties.contains("--og-edit-min-height"))
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
        #expect(graph.nodes.filter { !$0.id.isEmpty }.map(\.id) == ["cards"])
    }

    /// 論理名（日本語）: Project要約キャンバスメタデータ件数テスト
    /// 概要: `.ogp` のChapter / Collectionガイドとオブジェクト参照件数がproject inspectへ反映されることを確認します。
    @Test("project inspectがguideCountとreferenceCountを返す")
    func testInspectProjectIncludesCanvasGuideCounts() throws {
        // コンディション：ChapterとCollectionにguideと参照配置を1件ずつ保存したprojectを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"page\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)
        var project = try ProjectLoader().loadProject(at: projectURL).project
        project.chapters[0].guides = [
            OpenGraphiteCanvasGuide(internalID: "page-guide", orientation: .vertical, position: 320)
        ]
        project.collections[0].guides = [
            OpenGraphiteCanvasGuide(internalID: "component-guide", orientation: .horizontal, position: -48)
        ]
        project.chapters[0].references = [
            OpenGraphiteCanvasReference(
                internalID: "page-reference",
                referenceID: "ogref:node:\(project.chapters[0].internalID):\(project.chapters[0].pages[0].internalID):page-node",
                x: 120,
                y: 80
            )
        ]
        project.collections[0].references = [
            OpenGraphiteCanvasReference(
                internalID: "component-reference",
                referenceID: "ogref:component-node:\(project.collections[0].internalID):\(project.collections[0].components[0].internalID):cards-node",
                x: 320,
                y: 40
            )
        ]
        try JSONEncoder().encode(project).write(to: projectURL, options: .atomic)

        // 検証内容：project summaryを取得する（When）
        let summary = try fixture.core.inspectProject(at: projectURL)

        // 期待値：各containerのguideCountとreferenceCountが保存件数と一致する（Then）
        #expect(summary.chapters.first?.guideCount == 1)
        #expect(summary.collections.first?.guideCount == 1)
        #expect(summary.chapters.first?.referenceCount == 1)
        #expect(summary.collections.first?.referenceCount == 1)
    }

    /// 論理名（日本語）: Project要約表示状態テスト
    /// 概要: `.ogp` の Chapter / Page editor-only 表示状態が project inspect へ反映されることを確認します。
    @Test("project inspectがChapterとPageの表示状態を返す")
    func testInspectProjectIncludesVisibilityState() throws {
        // コンディション：Chapter と Page を非表示にした project を用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeProject(to: projectURL)
        var project = try ProjectLoader().loadProject(at: projectURL).project
        project.chapters[0].isSidebarHidden = true
        project.chapters[0].pages[0].isCanvasHidden = true
        try JSONEncoder().encode(project).write(to: projectURL, options: .atomic)

        // 検証内容：project summary を取得する（When）
        let summary = try fixture.core.inspectProject(at: projectURL)

        // 期待値：Chapter と Page の表示状態が editor-only metadata として返る（Then）
        #expect(summary.chapters.first?.isSidebarHidden == true)
        #expect(summary.pages.first?.isCanvasHidden == true)
    }

    /// 論理名（日本語）: Componentsセグメント検証テスト
    /// 概要: project validationがComponentsの未知legacy type hintを保持しつつvalidation errorにしないことを確認します。
    @Test("project validateはComponentsの未知legacy type hintを許容する")
    func testValidateProjectIncludesComponentsSegment() throws {
        // コンディション：未知のlegacy data-og-type hintを持つcomponent HTMLを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try fixture.writeHTML(
            "<!doctype html><html><body><Cards data-og-id=\"cards\" data-og-type=\"unknown\"></Cards></body></html>",
            to: fixture.rootURL.appendingPathComponent("cards.html")
        )
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：project全体をvalidateする（When）
        let result = try fixture.core.validateProject(at: projectURL)

        // 期待値：legacy hintはcapability契約やvalidation enumに使わずsourceを許容する（Then）
        #expect(result.valid == true)
        #expect(!result.diagnostics.contains { $0.code == "unknown-data-og-type" })
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
                <og-placement data-og-id="page-placement" data-og-type="frame" data-og-source-component-internal-id="c9a63f" data-og-source-node-internal-id="cards-internal"></og-placement>
              </Page>
            </body></html>
            """
        )
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><body>
              <Cards data-og-id="cards" data-og-internal-id="cards-internal" data-og-type="frame"></Cards>
              <og-placement data-og-id="component-placement" data-og-type="frame" data-og-source-component-internal-id="c9a63f" data-og-source-node-internal-id="cards-internal"></og-placement>
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

    /// 論理名（日本語）: Component Placement参照整合性検証テスト
    /// 概要: component canvas内placementの参照元component不一致と参照元node欠落を、optional annotationとは独立して診断します。
    @Test("project validateはcomponent placementの参照元componentとnodeを検証する")
    func testValidateProjectReportsBrokenComponentPlacementReferencesWithoutRequiringAnnotations() throws {
        // コンディション：未注釈page/component要素と、参照元component不一致・参照元node欠落を持つ2つのplacementを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let pageHTML = "<!doctype html><html><body><main><p>Standard page</p></main></body></html>"
        let componentURL = fixture.rootURL.appendingPathComponent("cards.html")
        let componentHTML = """
        <!doctype html><html><body><main>
          <article data-og-internal-id="cards-source">Source</article>
          <og-placement data-og-id="wrong-component" data-og-source-component-internal-id="another-component" data-og-source-node-internal-id="cards-source"></og-placement>
          <og-placement data-og-id="missing-node" data-og-source-component-internal-id="c9a63f" data-og-source-node-internal-id="absent-source"></og-placement>
          <section>Unannotated component content</section>
        </main></body></html>
        """
        try fixture.writeRawHTML(pageHTML)
        try fixture.writeRawHTML(componentHTML, to: componentURL)
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：project全体をvalidateし、同じcomponentをgraph inspectionしてsource bytesを再取得する（When）
        let result = try fixture.core.validateProject(at: projectURL)
        let graph = try fixture.core.pageGraph(
            projectURL: projectURL,
            pageID: fixture.componentPageInternalID
        )
        let afterHTML = try String(contentsOf: componentURL, encoding: .utf8)
        let unannotated = try #require(graph.nodes.first { $0.tagName == "section" })

        // 期待値：既存参照破損だけをerrorにし、missing annotationは有効なsession inspectionとしてsourceを変更しない（Then）
        #expect(result.valid == false)
        #expect(result.diagnostics.contains {
            $0.code == "component-placement-source-component-mismatch" && $0.nodeID == "wrong-component"
        })
        #expect(result.diagnostics.contains {
            $0.code == "component-placement-source-node-missing" && $0.nodeID == "missing-node"
        })
        #expect(!result.diagnostics.contains {
            ["component-placement-missing-source-component", "component-placement-missing-source-node"].contains($0.code)
        })
        #expect(!result.diagnostics.contains { $0.code.hasPrefix("missing-data-og-") })
        #expect(unannotated.annotationStatus == OpenGraphiteNodeAnnotationStatus.none)
        #expect(unannotated.referenceStability == .session)
        #expect(afterHTML == componentHTML)
    }

    /// 論理名（日本語）: component buildテスト
    /// 概要: `ogkiln build` と同じ builder が `<og-instance>` を静的 HTML へ展開できることを確認します。
    @Test("component参照を静的HTMLへbuildできる")
    func testComponentBuilderExpandsInstances() throws {
        // コンディション：component link、runtime script、og-instance と `.ogp` 専用注釈を持つ project を用意する（Given）
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
          <status-badge data-og-component="status-badge" part="root">
            <template><span part="badge"><slot>Fallback badge</slot></span></template>
          </status-badge>
          <feature-card data-og-id="feature-card-master" data-og-component="feature-card" part="root" variant="default">
            <template>
              <article part="surface">
                <slot name="title"><span data-og-id="title" part="title">Fallback title</span></slot>
                <slot>Fallback body</slot>
                <slot name="actions"><button part="fallback-action">Fallback action</button></slot>
              </article>
            </template>
          </feature-card>
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
            <og-instance data-og-id="home-card" data-og-component="feature-card" variant="compact">
              <span slot="title">Built Title</span><strong slot="title">Built Subtitle</strong>
              <p>First body</p><p>Second body</p>
              <og-instance data-og-component="status-badge" slot="actions"><em>Nested badge</em></og-instance>
            </og-instance>
          </Page>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)
        var annotatedProject = try ProjectLoader().loadProject(at: projectURL).project
        annotatedProject.chapters[0].annotations = [
            OpenGraphiteCanvasAnnotation(
                internalID: "build-note-opaque",
                kind: .stickyNote,
                frame: OpenGraphiteCanvasAnnotationFrame(x: 40, y: 60, width: 240, height: 160),
                text: "ANNOTATION_MUST_NOT_SHIP"
            ),
            OpenGraphiteCanvasAnnotation(
                internalID: "build-ink-opaque",
                kind: .ink,
                frame: OpenGraphiteCanvasAnnotationFrame(x: 320, y: 80, width: 80, height: 40),
                strokes: [
                    OpenGraphiteInkStroke(
                        points: [OpenGraphiteInkPoint(x: 0, y: 0, pressure: 0.7)],
                        color: "#ABCDEF",
                        inputDevice: .pen
                    )
                ]
            )
        ]
        annotatedProject.chapters[0].guides = [
            OpenGraphiteCanvasGuide(
                internalID: "build-guide-opaque",
                orientation: .vertical,
                position: 777
            )
        ]
        try JSONEncoder().encode(annotatedProject).write(to: projectURL)

        // 検証内容：builder で dist 相当のディレクトリへ出力する（When）
        let outputURL = fixture.rootURL.appendingPathComponent("dist-a")
        let secondOutputURL = fixture.rootURL.appendingPathComponent("dist-b")
        let builder = OpenGraphiteComponentBuilder()
        let result = try builder.buildProject(projectURL: projectURL, outputURL: outputURL)
        let secondResult = try builder.buildProject(projectURL: projectURL, outputURL: secondOutputURL)
        let builtHTML = try String(contentsOf: outputURL.appendingPathComponent("index.html"), encoding: .utf8)
        let secondBuiltHTML = try String(contentsOf: secondOutputURL.appendingPathComponent("index.html"), encoding: .utf8)
        let builtCSS = try String(contentsOf: outputURL.appendingPathComponent("OpenGraphite.css"), encoding: .utf8)
        let secondBuiltCSS = try String(contentsOf: secondOutputURL.appendingPathComponent("OpenGraphite.css"), encoding: .utf8)

        // 期待値：component は展開される一方、`.ogp` 専用注釈・guide・manifestは公開 build 成果物へ混入しない（Then）
        #expect(result.built == true)
        #expect(secondResult.built == true)
        #expect(result.pages.map(\.id) == ["home"])
        #expect(builtHTML.contains("<feature-card"))
        #expect(builtHTML.contains("shadowrootmode=\"open\""))
        #expect(builtHTML.components(separatedBy: "shadowrootmode=\"open\"").count - 1 == 2)
        #expect(builtHTML.contains("<slot name=\"title\""))
        #expect(builtHTML.contains("part=\"title\""))
        #expect(builtHTML.contains("part=\"surface\""))
        #expect(builtHTML.contains("part=\"fallback-action\""))
        #expect(builtHTML.contains("variant=\"compact\""))
        #expect(builtHTML.contains("data-og-id=\"home-card\""))
        #expect(builtHTML.contains("Built Title"))
        #expect(builtHTML.contains("Built Subtitle"))
        #expect(builtHTML.contains("First body"))
        #expect(builtHTML.contains("Second body"))
        #expect(builtHTML.contains("Nested badge"))
        #expect(builtHTML.contains("<status-badge data-og-component=\"status-badge\" part=\"root\" slot=\"actions\""))
        #expect(builtHTML.contains("Fallback action"))
        #expect(!builtHTML.contains("<og-instance"))
        #expect(!builtHTML.contains("OpenGraphite.runtime.js"))
        #expect(!builtHTML.contains("ANNOTATION_MUST_NOT_SHIP"))
        #expect(!builtHTML.contains("#ABCDEF"))
        #expect(!builtCSS.contains("ANNOTATION_MUST_NOT_SHIP"))
        #expect(!builtCSS.contains("#ABCDEF"))
        #expect(!builtHTML.contains("build-guide-opaque"))
        #expect(!builtHTML.contains("data-og-component-kind"))
        #expect(!builtHTML.contains("data-og-slot"))
        #expect(!builtHTML.contains("data-og-part"))
        #expect(!builtHTML.contains("data-og-variant"))
        #expect(builtHTML == secondBuiltHTML)
        #expect(builtCSS == secondBuiltCSS)
        #expect(!builtCSS.contains("build-guide-opaque"))
        #expect(!FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("Sample.ogp").path))
        #expect(!result.assets.map(\.outputPath).contains(outputURL.appendingPathComponent("Sample.ogp").path))
        #expect(result.assets.map(\.outputPath).contains(outputURL.appendingPathComponent("OpenGraphite.css").path))
        #expect(result.assets.map(\.outputPath).contains(outputURL.appendingPathComponent("assets/preview.svg").path))
        #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("OpenGraphite.css").path))
        #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent("assets/preview.svg").path))
    }

    /// 論理名（日本語）: 標準media/icon/scale静的build決定性テスト
    /// 概要: 標準object-fit、stroke-width、mask-image、scaleだけを持つfixtureを2回buildし、同一成果物を得ることを確認します。
    @Test("標準mediaとiconとscale契約を決定的にstatic buildできる")
    func testStaticBuildPreservesStandardMediaIconAndScaleContractDeterministically() throws {
        // Given
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeCSSLibrary("body { margin: 0; }\n")
        try fixture.writeHTML(
            """
            <!doctype html>
            <html><head><link rel="stylesheet" href="./index.css"></head><body>
              <figure data-og-id="media" data-og-type="image"><img src="hero.png" alt="Hero"></figure>
              <Icon data-og-id="inline-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="inline"><svg viewBox="0 0 24 24"><path d="M1 1"></path></svg></Icon>
              <Icon data-og-id="cdn-icon" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn"><span aria-hidden="true"></span></Icon>
              <div id="flip-card" data-og-id="flip" data-og-type="frame"></div>
            </body></html>
            """
        )
        let companionCSS = """
        [data-og-internal-id="media"] > img {
          object-fit: cover;
        }

        [data-og-internal-id="inline-icon"] > svg {
          stroke-width: 2;
        }

        [data-og-internal-id="cdn-icon"] > span {
          mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/circle.svg');
          -webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/circle.svg');
        }

        #flip-card {
          transform: rotate(8deg) translateX(2px);
          rotate: 2deg;
          scale: -1 1;
        }
        """
        try fixture.writeCompanionCSS(companionCSS)
        try fixture.writeProject(to: projectURL)
        let firstOutputURL = fixture.rootURL.appendingPathComponent(".dist-first")
        let secondOutputURL = fixture.rootURL.appendingPathComponent(".dist-second")

        // When
        let firstResult = try OpenGraphiteComponentBuilder().buildProject(
            projectURL: projectURL,
            outputURL: firstOutputURL
        )
        let secondResult = try OpenGraphiteComponentBuilder().buildProject(
            projectURL: projectURL,
            outputURL: secondOutputURL
        )
        let firstHTML = try Data(contentsOf: firstOutputURL.appendingPathComponent("index.html"))
        let secondHTML = try Data(contentsOf: secondOutputURL.appendingPathComponent("index.html"))
        let firstCSS = try Data(contentsOf: firstOutputURL.appendingPathComponent("index.css"))
        let secondCSS = try Data(contentsOf: secondOutputURL.appendingPathComponent("index.css"))
        let builtHTML = String(decoding: firstHTML, as: UTF8.self)
        let builtCSS = String(decoding: firstCSS, as: UTF8.self)

        // Then
        #expect(firstResult.built == true)
        #expect(secondResult.built == true)
        #expect(firstHTML == secondHTML)
        #expect(firstCSS == secondCSS)
        #expect(builtHTML.contains("<span aria-hidden=\"true\"></span>"))
        #expect(!builtHTML.contains("data-og-icon-mask"))
        #expect(builtCSS.contains("object-fit: cover;"))
        #expect(builtCSS.contains("stroke-width: 2;"))
        #expect(builtCSS.contains("mask-image: url("))
        #expect(builtCSS.contains("-webkit-mask-image: url("))
        #expect(builtCSS.contains("transform: rotate(8deg) translateX(2px);"))
        #expect(builtCSS.contains("rotate: 2deg;"))
        #expect(builtCSS.contains("scale: -1 1;"))
        #expect(!builtCSS.contains("--og-object-fit"))
        #expect(!builtCSS.contains("--og-stroke-width"))
        #expect(!builtCSS.contains("--og-icon-url"))
        #expect(!builtCSS.contains("--og-scale-x"))
        #expect(!builtCSS.contains("--og-scale-y"))
    }

    /// 論理名（日本語）: 標準layout静的build決定性テスト
    /// 概要: 標準layout/visibility/wrap sourceを2回同一buildし、legacy入力は暗黙migrationせず配布CSSの旧描画selectorだけを除外します。
    @Test("標準layout契約をlegacy入力非変換のまま決定的にstatic buildできる")
    func testStaticBuildPreservesStandardLayoutAndLegacyInputDeterministically() throws {
        // コンディション：標準CSSと明示migrationまで読み続けるlegacy属性・binding metadataを併存させる（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeCSSLibrary(".layout-root { display: block; }\n")
        try fixture.writeHTML(
            """
            <!doctype html><html><body>
              <main class="layout-root" data-og-id="root" data-og-layout="horizontal" data-og-hidden="true">
                <span data-og-id="copy" data-og-text-source="binding">Copy</span>
              </main>
            </body></html>
            """
        )
        let companionCSS = """
        .layout-root { display: grid; grid-template-columns: 1fr 2fr; visibility: visible; }
        .layout-root > span { overflow-wrap: anywhere; }
        """
        try fixture.writeCompanionCSS(companionCSS)
        try fixture.writeProject(to: projectURL)
        let firstOutputURL = fixture.rootURL.appendingPathComponent(".layout-dist-first")
        let secondOutputURL = fixture.rootURL.appendingPathComponent(".layout-dist-second")

        // 検証内容：同じprojectを独立した2出力先へstatic buildする（When）
        let firstResult = try OpenGraphiteComponentBuilder().buildProject(
            projectURL: projectURL,
            outputURL: firstOutputURL
        )
        let secondResult = try OpenGraphiteComponentBuilder().buildProject(
            projectURL: projectURL,
            outputURL: secondOutputURL
        )
        let firstHTML = try Data(contentsOf: firstOutputURL.appendingPathComponent("index.html"))
        let secondHTML = try Data(contentsOf: secondOutputURL.appendingPathComponent("index.html"))
        let firstCSS = try Data(contentsOf: firstOutputURL.appendingPathComponent("index.css"))
        let secondCSS = try Data(contentsOf: secondOutputURL.appendingPathComponent("index.css"))
        let distributedCSS = try String(
            contentsOf: firstOutputURL.appendingPathComponent("OpenGraphite.css"),
            encoding: .utf8
        )
        let builtHTML = String(decoding: firstHTML, as: UTF8.self)
        let builtCSS = String(decoding: firstCSS, as: UTF8.self)

        // 期待値：bytesは決定的で標準sourceを維持し、legacy入力は保持するが旧描画selectorとして配布しない（Then）
        #expect(firstResult.built == true)
        #expect(secondResult.built == true)
        #expect(firstHTML == secondHTML)
        #expect(firstCSS == secondCSS)
        #expect(builtHTML.contains("data-og-layout=\"horizontal\""))
        #expect(builtHTML.contains("data-og-hidden=\"true\""))
        #expect(builtHTML.contains("data-og-text-source=\"binding\""))
        #expect(builtCSS == companionCSS)
        #expect(!distributedCSS.contains("data-og-layout"))
        #expect(!distributedCSS.contains("data-og-hidden"))
        #expect(!distributedCSS.contains("data-og-text-source"))
    }

    /// 論理名（日本語）: 標準DOM capability導出テスト
    /// 概要: legacy type hintを権限根拠にせず、text/link/control/media/SVG/mask/custom/constrained contentのoperation setを複数同時に導出します。
    @Test("標準DOMとCSS実体からoperation capabilityを複数導出する")
    func testStandardDOMDerivesOperationCapabilitiesWithoutLegacyTypeAuthority() throws {
        // コンディション：標準semantic要素、custom element、矛盾するlegacy hint、constrained contentを同じraw HTMLへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body><main id="root">
          <a id="link" HREF="" role="foo LINK">Link <span id="link-label">label</span></a>
          <button id="button">Save</button>
          <input id="input" type="text" value="Value">
          <div id="aria-control" role="foo BUTTON">ARIA</div>
          <div id="aria-switch" role="switch checkbox">Switch</div>
          <div id="aria-link-control" role="foo link">ARIA link without destination</div>
          <x-editor id="editor" contenteditable><x-inherited id="inherited"></x-inherited><x-disabled id="disabled" contenteditable="false"></x-disabled></x-editor>
          <figure id="media"><img id="image" src="hero.png" alt="Hero"></figure>
          <span id="mask" style="mask-image:url(mask.svg)"></span>
          <svg id="glyph" viewBox="0 0 24 24"><defs id="svg-defs"><symbol id="svg-symbol"></symbol></defs><foreignObject><div id="foreign-html"><span>HTML</span></div></foreignObject><path d="M0 0"></path></svg>
          <math id="math"><mrow id="math-row"><mi>x</mi></mrow></math>
          <x-ambiguous id="custom" data-og-type="image" role="link">Direct <span>child</span></x-ambiguous>
          <x-linked id="custom-link" role="link" href="">Linked</x-linked>
          <button id="customized-button" is="x-action">Customized</button>
          <LegacyWidget id="legacy-widget"><span>Legacy</span></LegacyWidget>
          <div id="generic"><span>Child</span></div>
          <div id="ungroup-parent"><span id="ungroup-span"><em>Child</em></span></div>
          <p id="paragraph"><span id="phrasing">Text</span></p>
          <ul id="list"><li id="item">Item</li></ul>
          <table id="table"><tbody><tr id="row"><td id="cell">Cell</td></tr></tbody></table>
        </main></body></html>
        """
        try fixture.writeRawHTML(originalHTML)

        // 検証内容：graphとvalidationを生成し、operation capability/evidenceを標準IDで取得する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let validation = try fixture.core.validateHTML(at: fixture.htmlURL)
        let afterHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        func node(_ id: String) throws -> OpenGraphiteAgentNode {
            try #require(graph.nodes.first { $0.attributes["id"] == id })
        }

        // 期待値：1 nodeが複数operationを持ち、legacy hintはinspection専用でcapabilityを追加しない（Then）
        let link = try node("link")
        #expect(link.capabilities.contains(.editLink))
        #expect(link.capabilities.contains(.editText))
        #expect(!link.capabilities.contains(.receiveChildren))
        #expect(link.capabilityEvidence.isLink == true)
        #expect(link.capabilityEvidence.hasDirectText == true)
        #expect(link.capabilityEvidence.hasElementChildren == true)
        #expect(link.capabilityEvidence.ariaRole == "link")
        #expect(try node("button").capabilities.contains(.editControl))
        #expect(try node("button").capabilities.contains(.editText))
        #expect(!(try node("button")).capabilities.contains(.receiveChildren))
        #expect(try node("input").capabilities.contains(.editControl))
        #expect(!(try node("input")).capabilities.contains(.editText))
        #expect(try node("aria-control").capabilityEvidence.ariaRole == "button")
        #expect(try node("aria-control").capabilities.contains(.editControl))
        #expect(try node("aria-switch").capabilityEvidence.ariaRole == "switch")
        #expect(try node("aria-switch").capabilities.contains(.editControl))
        #expect(try node("aria-link-control").capabilityEvidence.isLink == true)
        #expect(try node("aria-link-control").capabilities.contains(.editControl))
        #expect(!(try node("aria-link-control")).capabilities.contains(.editLink))
        #expect(try node("inherited").capabilities.contains(.editText))
        #expect(!(try node("disabled")).capabilities.contains(.editText))
        #expect(try node("media").capabilities.contains(.editMedia))
        #expect(try node("image").capabilities.contains(.editMedia))
        #expect(try node("image").capabilities.contains(.editLayout))
        #expect(try node("mask").capabilities.contains(.editIcon))
        #expect(try node("glyph").capabilities.contains(.editIcon))
        #expect(!(try node("svg-defs")).capabilities.contains(.receiveChildren))
        #expect(!(try node("svg-defs")).capabilities.contains(.group))
        #expect(!(try node("svg-symbol")).capabilities.contains(.receiveChildren))
        #expect(try node("foreign-html").capabilities.contains(.receiveChildren))
        #expect(!(try node("math")).capabilities.contains(.receiveChildren))
        #expect(!(try node("math-row")).capabilities.contains(.receiveChildren))
        let custom = try node("custom")
        #expect(custom.legacyTypeHint == "image")
        #expect(custom.annotationStatus == .none)
        #expect(custom.capabilityEvidence.isCustomElement == true)
        #expect(!custom.capabilities.contains(.editLink))
        #expect(custom.capabilities.contains(.editControl))
        #expect(custom.capabilities.contains(.editText))
        #expect(custom.capabilities.contains(.receiveChildren))
        #expect(!custom.capabilities.contains(.editMedia))
        #expect(!custom.capabilities.contains(.ungroup))
        #expect(try node("custom-link").capabilities.contains(.editLink))
        #expect(!(try node("custom-link")).capabilities.contains(.editControl))
        #expect(try node("customized-button").capabilityEvidence.isCustomElement == true)
        #expect(try node("customized-button").capabilityEvidence.isNativeControl == true)
        #expect(try node("legacy-widget").capabilityEvidence.isCustomElement == false)
        #expect(try node("legacy-widget").capabilities.contains(.receiveChildren))
        #expect(try node("generic").capabilities.contains(.ungroup))
        #expect(!(try node("ungroup-span")).capabilities.contains(.receiveChildren))
        #expect(try node("ungroup-span").capabilities.contains(.ungroup))
        #expect(!(try node("paragraph")).capabilities.contains(.receiveChildren))
        #expect(!(try node("phrasing")).capabilities.contains(.receiveChildren))
        #expect(!(try node("glyph")).capabilities.contains(.receiveChildren))
        #expect(!(try node("list")).capabilities.contains(.receiveChildren))
        #expect(try node("item").capabilities.contains(.receiveChildren))
        #expect(try node("item").capabilities.contains(.reorderFlow))
        #expect(!(try node("table")).capabilities.contains(.receiveChildren))
        #expect(try node("row").capabilities.contains(.reorderFlow))
        #expect(try node("cell").capabilities.contains(.receiveChildren))
        #expect(graph.nodes.allSatisfy { node in
            node.capabilities == node.capabilities.sorted { $0.rawValue < $1.rawValue }
        })
        #expect(validation.valid == true)
        #expect(!validation.diagnostics.contains { $0.code == "unknown-data-og-type" })
        #expect(afterHTML == originalHTML)
    }

    /// 論理名（日本語）: Project resource root capability境界テスト
    /// 概要: page/componentの一意なbody直下要素だけをroot evidenceにし、複数top-levelやlegacy page hintへroot操作権限を誤付与しません。
    @Test("project登録rootと複数top-levelの操作境界を保守的に導出する")
    func testProjectResourceRootCapabilityBoundaryDoesNotUseLegacyPageHint() throws {
        // コンディション：single-root page/componentを登録し、root自身はabsolute配置とlegacy hintを持たせる（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let pageHTML = "<!doctype html><html><body><main id=\"page-root\" data-og-type=\"frame\" style=\"position:absolute\"><p>Page</p></main></body></html>"
        let componentHTML = "<!doctype html><html><body><product-card id=\"component-root\" data-og-type=\"page\"><span>Card</span></product-card></body></html>"
        try fixture.writeRawHTML(pageHTML)
        try fixture.writeRawHTML(componentHTML, to: fixture.rootURL.appendingPathComponent("cards.html"))
        try fixture.writeProjectWithComponents(to: projectURL)

        // 検証内容：page/component graphを取得後、pageを複数top-levelへ置換して再inspectionする（When）
        let pageGraph = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.homePageInternalID)
        let componentGraph = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.componentPageInternalID)
        let multipleHTML = "<!doctype html><html><body><main id=\"first\" data-og-type=\"page\" style=\"position:absolute\">A</main><aside id=\"second\" style=\"position:absolute\">B</aside></body></html>"
        try fixture.writeRawHTML(multipleHTML)
        let multipleGraph = try fixture.core.pageGraph(projectURL: projectURL, pageID: fixture.homePageInternalID)

        // 期待値：一意rootだけevidence true、複数境界は偽root化せずdrag/group/reorder/ungroupを全拒否する（Then）
        let pageRoot = try #require(pageGraph.nodes.first { $0.attributes["id"] == "page-root" })
        let componentRoot = try #require(componentGraph.nodes.first { $0.attributes["id"] == "component-root" })
        #expect(pageRoot.capabilityEvidence.isProjectResourceRoot == true)
        #expect(componentRoot.capabilityEvidence.isProjectResourceRoot == true)
        #expect(pageRoot.legacyTypeHint == "frame")
        #expect(componentRoot.legacyTypeHint == "page")
        for root in [pageRoot, componentRoot] {
            #expect(!root.capabilities.contains(.dragPosition))
            #expect(!root.capabilities.contains(.reorderFlow))
            #expect(!root.capabilities.contains(.group))
            #expect(!root.capabilities.contains(.ungroup))
        }
        let topLevelNodes = multipleGraph.nodes.filter {
            ["first", "second"].contains($0.attributes["id"] ?? "")
        }
        #expect(topLevelNodes.count == 2)
        #expect(topLevelNodes.allSatisfy { !$0.capabilityEvidence.isProjectResourceRoot })
        #expect(topLevelNodes.allSatisfy {
            !$0.capabilities.contains(.dragPosition)
                && !$0.capabilities.contains(.reorderFlow)
                && !$0.capabilities.contains(.group)
                && !$0.capabilities.contains(.ungroup)
        })
        #expect(try String(contentsOf: fixture.rootURL.appendingPathComponent("cards.html"), encoding: .utf8) == componentHTML)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == multipleHTML)
    }

    /// 論理名（日本語）: Capability query・mutation guard parityテスト
    /// 概要: Core/CLI queryがcapability AND条件とlegacy hint条件を分離し、text/icon/child mutationがcapability不足でatomic no-writeになります。
    @Test("CoreとCLIはcapability queryとoperation guardを共有する")
    func testCapabilityQueryAndMutationGuardsKeepCoreCLIParity() throws {
        // コンディション：同じlegacy hintで異なるstandard semanticsを持つnodeとconstrained parentをprojectへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = """
        <!doctype html><html><body><main id="root">
          <a id="link" data-og-internal-id="link-node" data-og-type="button" href="/docs">Docs</a>
          <img id="media" data-og-internal-id="media-node" data-og-type="button" src="hero.png" alt="Hero">
          <div id="legacy-icon" data-og-internal-id="legacy-icon-node" data-og-type="icon"></div>
          <div id="legacy-text" data-og-internal-id="legacy-text-node" data-og-type="text"></div>
          <script id="legacy-layout" data-og-internal-id="legacy-layout-node" data-og-type="frame">window.keep = true;</script>
          <table id="table" data-og-internal-id="table-node"><tbody><tr><td>Cell</td></tr></tbody></table>
          <span id="mask" data-og-internal-id="mask-node" style="mask-image:url(mask.svg)"></span>
          <svg id="plain-svg" data-og-internal-id="plain-svg-node" viewBox="0 0 24 24"><path d="M0 0"></path></svg>
          <og-icon id="metadata-icon" data-og-internal-id="metadata-icon-node" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline"><svg viewBox="0 0 24 24"></svg></og-icon>
        </main></body></html>
        """
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)
        let query = OpenGraphiteNodeQuery(
            idContains: nil,
            type: "button",
            capabilities: [.editLayout, .editLink],
            role: nil,
            tag: nil,
            textContains: nil
        )
        let cli = OgkilnCLI()
        var output = ""
        var error = ""

        // 検証内容：Core/CLIで同じAND queryを実行し、legacy-only text/iconとtable child insertを直接mutationする（When）
        let coreResult = try fixture.core.queryNodes(
            projectURL: projectURL,
            pageID: fixture.homePageInternalID,
            query: query
        )
        let cliCode = cli.run(
            arguments: [
                "node", "query", "Sample.ogp", "--page-id", fixture.homePageInternalID,
                "--type", "button", "--capability", "edit-layout", "--capability", "edit-link", "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { output += $0 },
            stderr: { error += $0 }
        )
        let cliResult = try JSONDecoder().decode(OpenGraphiteNodeQueryResult.self, from: Data(output.utf8))
        let document = OpenGraphiteHTMLDocument(html: originalHTML)
        let textMutation = document.settingTextContent("New", forNodeID: "legacy-text-node", contract: .builtIn)
        let iconMutation = document.settingIcon(
            library: "lucide", name: "star", source: "inline",
            forNodeID: "legacy-icon-node", contract: .builtIn
        )
        let childMutation = document.insertingHTML(
            "<div>Invalid child</div>", relativeToNodeID: "table-node", position: .append, contract: .builtIn
        )
        let maskMutation = document.settingIcon(
            library: "lucide", name: "star", source: "inline",
            forNodeID: "mask-node", contract: .builtIn
        )
        let plainSVGMutation = document.settingIcon(
            library: "lucide", name: "star", source: "inline",
            forNodeID: "plain-svg-node", contract: .builtIn
        )
        let metadataIconMutation = document.settingIcon(
            library: "lucide", name: "star", source: "inline",
            forNodeID: "metadata-icon-node", contract: .builtIn
        )
        let legacyLayoutMutation = try fixture.core.setCSSVariable(
            "display",
            value: "block",
            nodeID: "legacy-layout-node",
            htmlURL: fixture.htmlURL
        )
        let generatedIcon = OpenGraphiteIconMarkup.elementHTML(
            id: "generated-icon", internalID: "generated-icon-node", library: "lucide",
            name: "circle", source: "inline", width: "24px", height: "24px", nodeID: nil
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：query結果は一致し、legacy hintだけでは権限を得ず、実maskと新規iconはtype生成なしで編集できる（Then）
        #expect(coreResult.nodes.map { $0.attributes["id"] } == ["link"])
        #expect(cliCode == 0)
        #expect(error.isEmpty)
        #expect(cliResult.nodes.map { $0.attributes["id"] } == ["link"])
        #expect(cliResult.query.capabilities == [.editLayout, .editLink])
        for mutation in [textMutation, iconMutation, childMutation, maskMutation, plainSVGMutation] {
            #expect(mutation.html == originalHTML)
            #expect(mutation.diagnostics.contains { $0.code == "unsupported-node-capability" })
        }
        #expect(metadataIconMutation.diagnostics.isEmpty)
        #expect(metadataIconMutation.html.contains("data-og-icon-name=\"star\""))
        #expect(legacyLayoutMutation.updated == false)
        #expect(legacyLayoutMutation.diagnostics.contains { $0.code == "unsupported-node-capability" })
        #expect(!generatedIcon.html.contains("data-og-type"))
        #expect(finalHTML == originalHTML)
    }

    /// 論理名（日本語）: 標準属性Capability・空値操作テスト
    /// 概要: link/control/media属性を適合するDOM targetだけへ許可し、present-empty setと明示removeをCore/CLIで分離します。
    @Test("標準属性はcapabilityとtagに従い空値setとremoveを分離する")
    func testStandardAttributeTargetsPreserveEmptyValuesAndRejectInvalidNodes() throws {
        // コンディション：native link/control/media、ARIA link、既存href custom host、任意divを同じprojectへ用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        let originalHTML = """
        <!doctype html><html><body><main data-og-internal-id="root-node">
          <a id="link" data-og-internal-id="link-node" href="/docs" target="_self">Docs</a>
          <div id="aria-link" data-og-internal-id="aria-link-node" role="link">ARIA</div>
          <x-route id="custom-link" data-og-internal-id="custom-link-node" role="link" href="/old" target="_self">Custom</x-route>
          <button id="control" data-og-internal-id="control-node" value="old">Save</button>
          <data id="data-value" data-og-internal-id="data-node" value="sku-old">SKU</data>
          <ol><li id="list-value" data-og-internal-id="list-value-node" value="1">One</li></ol>
          <output id="output-value" data-og-internal-id="output-node">Result</output>
          <img id="media" data-og-internal-id="media-node" src="old.png" alt="Hero">
          <span id="mask-target" data-og-internal-id="mask-target-node" style="mask-image:url(mask.svg)"></span>
          <svg id="plain-svg" data-og-internal-id="plain-svg-node"><path d="M0 0"></path></svg>
          <span id="metadata-icon" data-og-internal-id="metadata-icon-node" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="cdn"></span>
          <div id="plain" data-og-internal-id="plain-node" hidden>Plain</div>
        </main></body></html>
        """
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeProject(to: projectURL)

        // 検証内容：空/空白値set、明示remove、適合しないtargetへの属性set、CLI空alt set/removeを実行する（When）
        let emptyHref = try fixture.core.setAttribute(
            "href", value: "", nodeID: "link-node", htmlURL: fixture.htmlURL
        )
        let spacedTarget = try fixture.core.setAttribute(
            "target", value: "  ", nodeID: "link-node", htmlURL: fixture.htmlURL
        )
        let emptyValue = try fixture.core.setAttribute(
            "value", value: "", nodeID: "control-node", htmlURL: fixture.htmlURL
        )
        let dataValue = try fixture.core.setAttribute(
            "value", value: "sku-new", nodeID: "data-node", htmlURL: fixture.htmlURL
        )
        let listValue = try fixture.core.setAttribute(
            "value", value: "2", nodeID: "list-value-node", htmlURL: fixture.htmlURL
        )
        let controlLabel = try fixture.core.setAttribute(
            "aria-label", value: "Save action", nodeID: "aria-link-node", htmlURL: fixture.htmlURL
        )
        let customHref = try fixture.core.setAttribute(
            "href", value: "", nodeID: "custom-link-node", htmlURL: fixture.htmlURL
        )
        let beforeBareHidden = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let bareHiddenNoOp = try fixture.core.setAttribute(
            "hidden", value: "", nodeID: "plain-node", htmlURL: fixture.htmlURL
        )
        let afterBareHidden = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let metadataIconSet = try fixture.core.setAttribute(
            "data-og-icon-name", value: "star", nodeID: "metadata-icon-node", htmlURL: fixture.htmlURL
        )
        let validAbsentAltRemoval = try fixture.core.removeAttribute(
            "alt", nodeID: "media-node", htmlURL: fixture.htmlURL
        )
        let validAbsentAltRemovalAgain = try fixture.core.removeAttribute(
            "alt", nodeID: "media-node", htmlURL: fixture.htmlURL
        )
        let beforeInvalid = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let invalidResults = try [
            fixture.core.setAttribute("href", value: "/bad", nodeID: "plain-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("value", value: "bad", nodeID: "plain-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("value", value: "bad", nodeID: "output-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("src", value: "bad.png", nodeID: "plain-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("href", value: "/unsafe", nodeID: "aria-link-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("data-og-icon-name", value: "unsafe", nodeID: "plain-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("data-og-icon-name", value: "unsafe", nodeID: "plain-svg-node", htmlURL: fixture.htmlURL),
            fixture.core.setAttribute("data-og-icon-name", value: "unsafe", nodeID: "mask-target-node", htmlURL: fixture.htmlURL),
            fixture.core.removeAttribute("href", nodeID: "plain-node", htmlURL: fixture.htmlURL),
            fixture.core.removeAttribute("value", nodeID: "output-node", htmlURL: fixture.htmlURL)
        ]
        let afterInvalid = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let removedHref = try fixture.core.removeAttribute("href", nodeID: "link-node", htmlURL: fixture.htmlURL)
        var setOutput = ""
        var setError = ""
        let cli = OgkilnCLI()
        let setCode = cli.run(
            arguments: [
                "node", "attr", "set", "Sample.ogp", "--page-id", fixture.homePageInternalID,
                "--id", "media-node", "--name", "alt", "--value", ""
            ],
            currentDirectory: fixture.rootURL,
            stdout: { setOutput += $0 },
            stderr: { setError += $0 }
        )
        let afterCLISet = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        var removeOutput = ""
        var removeError = ""
        let removeCode = cli.run(
            arguments: [
                "node", "attr", "remove", "Sample.ogp", "--page-id", fixture.homePageInternalID,
                "--id", "media-node", "--name", "alt"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { removeOutput += $0 },
            stderr: { removeError += $0 }
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：空文字/空白bytesを保持し、removeだけtokenを消し、不適合targetはatomic no-writeになる（Then）
        for result in [
            emptyHref, spacedTarget, emptyValue, dataValue, listValue,
            controlLabel, customHref, bareHiddenNoOp, metadataIconSet,
            validAbsentAltRemoval, validAbsentAltRemovalAgain, removedHref
        ] {
            #expect(result.diagnostics.contains { $0.severity == .error } == false)
        }
        #expect(bareHiddenNoOp.updated == false)
        #expect(beforeBareHidden == afterBareHidden)
        #expect(validAbsentAltRemoval.updated == true)
        #expect(validAbsentAltRemovalAgain.updated == false)
        #expect(beforeInvalid == afterInvalid)
        #expect(invalidResults.allSatisfy {
            !$0.updated && $0.diagnostics.contains { $0.code == "unsupported-node-capability" }
        })
        #expect(afterInvalid.contains("target=\"  \""))
        #expect(afterInvalid.contains("value=\"\""))
        #expect(afterInvalid.contains("value=\"sku-new\""))
        #expect(afterInvalid.contains("value=\"2\""))
        #expect(afterInvalid.contains("aria-label=\"Save action\""))
        #expect(afterInvalid.contains("data-og-icon-name=\"star\""))
        #expect(afterInvalid.contains("<x-route id=\"custom-link\" data-og-internal-id=\"custom-link-node\" role=\"link\" href=\"\""))
        #expect(!finalHTML.contains("<a id=\"link\" data-og-internal-id=\"link-node\" href="))
        #expect(setCode == 0)
        #expect(removeCode == 0)
        #expect(setError.isEmpty)
        #expect(removeError.isEmpty)
        #expect(!setOutput.isEmpty)
        #expect(!removeOutput.isEmpty)
        #expect(afterCLISet.contains("alt=\"\""))
        #expect(!finalHTML.contains(" alt="))
    }

    /// 論理名（日本語）: Generic child reception・semantic reorder安全境界テスト
    /// 概要: generic div断片の挿入先と既存semantic siblingのreorderを分け、constrained/foreign namespaceを破壊しません。
    @Test("generic child insertionとsemantic sibling reorderをcontent modelで分離する")
    func testGenericChildReceptionAndSemanticReorderPreserveContentModels() throws {
        // コンディション：flow/custom/unknown/constrained/SVG/foreignObject containerとsemantic siblingを用意する（Given）
        let originalHTML = """
        <!doctype html><html><body><main data-og-internal-id="root-node">
          <p data-og-internal-id="paragraph-node"><span data-og-internal-id="span-node">Text</span></p>
          <x-panel data-og-internal-id="custom-node"></x-panel>
          <LegacyWidget data-og-internal-id="unknown-node"></LegacyWidget>
          <ul data-og-internal-id="list-node"><li data-og-internal-id="item-a">A</li><li data-og-internal-id="item-b">B</li></ul>
          <table data-og-internal-id="table-node"><tbody><tr data-og-internal-id="row-a"><td>A</td></tr><tr data-og-internal-id="row-b"><td>B</td></tr></tbody></table>
          <svg data-og-internal-id="svg-node"><defs data-og-internal-id="defs-node"><symbol></symbol></defs><foreignObject><div data-og-internal-id="foreign-html-node"></div></foreignObject></svg>
        </main></body></html>
        """
        let document = OpenGraphiteHTMLDocument(html: originalHTML)

        // 検証内容：generic fragmentを各containerへ挿入し、li/trは既存semantic親内だけでreorderする（When）
        let rejectedMutations = [
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "paragraph-node", position: .append, contract: .builtIn),
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "span-node", position: .append, contract: .builtIn),
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "list-node", position: .append, contract: .builtIn),
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "table-node", position: .append, contract: .builtIn),
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "row-a", position: .append, contract: .builtIn),
            document.insertingHTML("<div>Invalid</div>", relativeToNodeID: "defs-node", position: .append, contract: .builtIn)
        ]
        let customInsertion = document.insertingHTML(
            "<div>Custom child</div>", relativeToNodeID: "custom-node", position: .append, contract: .builtIn
        )
        let unknownInsertion = document.insertingHTML(
            "<div>Unknown child</div>", relativeToNodeID: "unknown-node", position: .append, contract: .builtIn
        )
        let foreignHTMLInsertion = document.insertingHTML(
            "<div>HTML child</div>", relativeToNodeID: "foreign-html-node", position: .append, contract: .builtIn
        )
        let listReorder = document.movingNode(
            nodeID: "item-b", relativeToNodeID: "item-a", position: .before, contract: .builtIn
        )
        let rowReorder = document.movingNode(
            nodeID: "row-b", relativeToNodeID: "row-a", position: .before, contract: .builtIn
        )

        // 期待値：generic insertionはHTML flow hostだけ、semantic reorderはli/trだけ成功し、拒否時bytesは不変（Then）
        #expect(rejectedMutations.allSatisfy {
            $0.html == originalHTML && $0.diagnostics.contains { $0.code == "unsupported-node-capability" }
        })
        #expect(customInsertion.diagnostics.isEmpty)
        #expect(customInsertion.html.replacingOccurrences(of: "\n", with: "")
            .contains("<x-panel data-og-internal-id=\"custom-node\"><div>Custom child</div></x-panel>"))
        #expect(unknownInsertion.diagnostics.isEmpty)
        #expect(unknownInsertion.html.replacingOccurrences(of: "\n", with: "")
            .contains("<LegacyWidget data-og-internal-id=\"unknown-node\"><div>Unknown child</div></LegacyWidget>"))
        #expect(foreignHTMLInsertion.diagnostics.isEmpty)
        #expect(foreignHTMLInsertion.html.replacingOccurrences(of: "\n", with: "")
            .contains("data-og-internal-id=\"foreign-html-node\"><div>HTML child</div>"))
        #expect(listReorder.diagnostics.isEmpty)
        #expect(listReorder.html.range(of: "item-b")?.lowerBound ?? listReorder.html.endIndex
            < listReorder.html.range(of: "item-a")?.lowerBound ?? listReorder.html.endIndex)
        #expect(rowReorder.diagnostics.isEmpty)
        #expect(rowReorder.html.range(of: "row-b")?.lowerBound ?? rowReorder.html.endIndex
            < rowReorder.html.range(of: "row-a")?.lowerBound ?? rowReorder.html.endIndex)
    }

    /// 論理名（日本語）: Project Web契約atomic migrationテスト
    /// 概要: dry-run proposal、lossless multi-source apply、SHA-256 diff、idempotencyを同じ登録projectで確認します。
    @Test("project migrationはdry-run proposalに束縛してlosslessかつ冪等にapplyする")
    func testProjectMigrationDryRunApplyAndIdempotency() throws {
        // コンディション：case/entity/triviaを含むlegacy HTMLと、comment/string/urlを含む登録CSSを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let crlf = "\r\n"
        let originalHTML = #"""
        <!doctype html>
        <html><body><main class='foo&#x20;bar' DATA-OG-TYPE="FRAME" DATA-OG-LAYOUT="vert&#105;cal" DATA-OG-HIDDEN="TRUE" data-og-selected-extension="keep">Hello</main>
        <section class=alpha&#x20;beta data-og-type=frame data-keep='x'></section><aside CLASS data-og-layout=vertical data-keep=raw></aside>
        <article\#(crlf)class="tail " data-og-type=frame data-keep=crlf>CRLF</article>
        <p style=--og-edit-width:320px data-next=keep aria-label='A'>Runtime</p><b data-next=keep style=--og-edit-width:1px>Last</b><i style=--og-edit-width:1px  data-next=keep>NBSP</i>
        <style TYPE=" text/less ">@import "missing.less"; [class] { --og-accent:red }</style><style type="TeXt/CsS">:root { --og-muted-color: gray; color: var(--og-muted-color); }</style><script>// data-og-type in a comment is inert
        console.log("clean")</script></body></html>
        """#
        let originalCSS = #"""
        /* --og-not-a-token; @import "missing.css"; */
        [DATA-OG-TYPE="FRAME" i] { display: block; content: "--og-not-a-token"; background-image: url("data:image/svg+xml,--og-not-a-token"); }
        [data-og-layout="vertical"] { display: flex; flex-direction: column; }
        [style] { outline: 0; }
        """#
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeCSSLibrary(originalCSS)
        try fixture.writeProject(to: projectURL)

        // 検証内容：direct candidateと既定dry-runを取得し、同じproposalだけを使ってapplyした後に再dry-runする（When）
        let directMigration = OpenGraphiteHTMLDocument(html: originalHTML)
            .migratingLegacyWebContract(path: "index.html")
        let originalDocument = OpenGraphiteHTMLDocument(html: originalHTML)
        let originalParagraph = try #require(originalDocument.parsedTags().first { $0.tagName == "p" })
        let originalBold = try #require(originalDocument.parsedTags().first { $0.tagName == "b" })
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let cssAfterDryRun = try fixture.readCSSLibrary()
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        let migratedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let migratedDocument = OpenGraphiteHTMLDocument(html: migratedHTML)
        let migratedParagraph = try #require(migratedDocument.parsedTags().first { $0.tagName == "p" })
        let migratedBold = try #require(migratedDocument.parsedTags().first { $0.tagName == "b" })
        let migratedCSS = try fixture.readCSSLibrary()
        let repeated = try fixture.core.migrateProject(projectURL: projectURL)

        // 期待値：dry-runは無書込、diffはpath順/SHA-256で、apply後もunrelated raw bytesを保持して再実行はno-opになる（Then）
        #expect(dryRun.dryRun)
        #expect(dryRun.changed)
        #expect(dryRun.diagnostics.isEmpty)
        #expect(dryRun.diffs.map(\.path) == dryRun.diffs.map(\.path).sorted())
        #expect(dryRun.diffs.allSatisfy { $0.beforeHash.count == 64 && $0.afterHash.count == 64 })
        #expect(htmlAfterDryRun == originalHTML)
        #expect(cssAfterDryRun == originalCSS)
        #expect(applied.applied)
        #expect(applied.changed)
        #expect(applied.diagnostics.isEmpty)
        #expect(directMigration.diagnostics.isEmpty)
        #expect(directMigration.hasHTMLAttributeMutation)
        #expect(directMigration.hasEmbeddedStyleMutation)
        #expect(directMigration.source.contains(#"class="alpha&#x20;beta og-migrated-v1-type-frame""#))
        #expect(directMigration.source.contains(#"CLASS="og-migrated-v1-layout-vertical""#))
        #expect(originalParagraph.attributeValue(named: "style") != nil)
        #expect(originalBold.attributeValue(named: "style") != nil)
        #expect(migratedHTML.contains("class='foo&#x20;bar og-migrated-v1-type-frame og-migrated-v1-layout-vertical'"))
        #expect(migratedHTML.contains(#"class="alpha&#x20;beta og-migrated-v1-type-frame" data-keep='x'"#))
        #expect(migratedHTML.contains(#"CLASS="og-migrated-v1-layout-vertical" data-keep=raw"#))
        #expect(migratedHTML.contains("<article\r\nclass=\"tail  og-migrated-v1-type-frame\" data-keep=crlf>CRLF</article>"))
        #expect(migratedHTML.contains(#"<p style="" data-next=keep aria-label='A'>Runtime</p>"#))
        #expect(migratedHTML.contains(#"<b data-next=keep style="">Last</b>"#))
        #expect(migratedHTML.contains(#"<i style="" data-next=keep>NBSP</i>"#))
        #expect(migratedParagraph.attributeValue(named: "style") == "")
        #expect(migratedBold.attributeValue(named: "style") == "")
        #expect(!migratedHTML.contains("style=>"))
        #expect(migratedHTML.contains(#"<style TYPE=" text/less ">@import "missing.less"; [class] { --og-accent:red }</style>"#))
        #expect(migratedHTML.contains(#"<style type="TeXt/CsS">:root { --migrated-v1-muted-color: gray; color: var(--migrated-v1-muted-color); }</style>"#))
        #expect(migratedHTML.contains(" hidden"))
        #expect(migratedHTML.contains("data-og-selected-extension=\"keep\""))
        #expect(!migratedHTML.lowercased().contains("data-og-type=\""))
        #expect(migratedCSS.contains("/* --og-not-a-token; @import \"missing.css\"; */"))
        #expect(migratedCSS.contains("content: \"--og-not-a-token\""))
        #expect(migratedCSS.contains(".og-migrated-v1-type-frame"))
        #expect(!repeated.changed)
        #expect(repeated.diffs.isEmpty)
        #expect(repeated.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: Project migration whole-project blockテスト
    /// 概要: unknown reserved tokenとstandard destination conflictが一件でもあればcandidate diffを公開せず全sourceを保持します。
    @Test("project migrationはblocking diagnosticで全candidateをno-writeにする")
    func testProjectMigrationBlockingDiagnosticIsWholeProjectNoWrite() throws {
        // コンディション：変換可能HTMLとuntil-found conflict、catalog外custom propertyを同じ登録projectへ置く（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let originalHTML = "<main data-og-type=\"frame\" data-og-hidden=\"true\" hidden=\"UNTIL-FOUND\">Hello</main><aside data-og-type=\" frame \" variant=\"pre view\" data-og-variant=\"pre view\">NBSP</aside>"
        let originalCSS = ":root { --og-project-private: red; }\n[data-og-type=\"frame\"] { color: var(--og-project-private); }\n"
        try fixture.writeRawHTML(originalHTML)
        try fixture.writeCSSLibrary(originalCSS)
        try fixture.writeProject(to: projectURL)

        // 検証内容：project migrationをdry-runする（When）
        let result = try fixture.core.migrateProject(projectURL: projectURL)

        // 期待値：diagnosticを返してproposal/diffを破棄し、全登録source bytesを変更しない（Then）
        #expect(!result.changed)
        #expect(result.proposalReference == nil)
        #expect(result.diffs.isEmpty)
        #expect(result.diagnostics.contains { $0.code == "legacy-html-destination-conflict" })
        #expect(result.diagnostics.contains { $0.code == "unsupported-legacy-data-og-type" })
        #expect(result.diagnostics.contains { $0.code == "unknown-legacy-css-property" })
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == originalHTML)
        #expect(try fixture.readCSSLibrary() == originalCSS)
    }

    /// 論理名（日本語）: Migration ASCII whitespace・numeric reference境界テスト
    /// 概要: HTML/CSSのASCII whitespaceとsemicolonなしnumeric referenceをbrowser semanticsどおりlosslessに扱います。
    @Test("migrationはASCII whitespaceとsemicolonなしnumeric referenceを区別する")
    func testMigrationDistinguishesASCIIWhitespaceAndSemicolonlessNumericReferences() throws {
        // コンディション：NBSP tag/property/keywordとsemicolonなしnumeric referenceを同じsourceへ用意する（Given）
        let nbsp = "\u{00A0}"
        let source = "<\(nbsp)main data-og-type=frame>Opaque</\(nbsp)main>"
            + "<main data-og-id=\"node&#49\" style=\"--og&#45text-color:red\" "
            + "data-og-hidden=true hidden=\"\(nbsp)until-found\">Known</main>"
            + "<aside style=\"--og-text-color\(nbsp):red\">Token</aside>"
            + "<section data-og-id=\"nul&#0;\">NUL</section>"
            + "<nav data-og-id=\"c1&#128;\">C1</nav>"
            + "<footer data-og-id=\"\(nbsp)stable\(nbsp)\">Identity</footer>"
        let document = OpenGraphiteHTMLDocument(html: source)

        // 検証内容：direct migrationと移行後HTMLの再parseを実行する（When）
        let migration = document.migratingLegacyWebContract(path: "index.html")
        let migratedTags = OpenGraphiteHTMLDocument(html: migration.source).parsedTags()

        // 期待値：phantom tagを作らずnumeric参照だけをrange移行し、NBSPをkeyword/triviaへ誤分類しない（Then）
        #expect(migration.diagnostics.isEmpty)
        #expect(migration.source.contains("<\(nbsp)main data-og-type=frame>Opaque</\(nbsp)main>"))
        #expect(migration.source.contains(#"data-og-id="node&#49" style="--migrated-v1-text-color:red""#))
        #expect(migration.source.contains("hidden=\"\(nbsp)until-found\""))
        #expect(!migration.source.contains("data-og-hidden"))
        #expect(migration.source.contains("style=\"--og-text-color\(nbsp):red\""))
        #expect(migration.source.contains(#"data-og-id="nul&#0;""#))
        #expect(migration.source.contains(#"data-og-id="c1&#128;""#))
        #expect(migratedTags.map(\.tagName) == ["main", "aside", "section", "nav", "footer"])
        #expect(migratedTags.first?.attributeValue(named: "data-og-id") == "node1")
        #expect(migratedTags.first { $0.tagName == "section" }?.attributeValue(named: "data-og-id") == "nul�")
        #expect(migratedTags.first { $0.tagName == "nav" }?.attributeValue(named: "data-og-id") == "c1€")
        #expect(migratedTags.first { $0.tagName == "footer" }?.emptyNilAttribute(named: "data-og-id") == "\(nbsp)stable\(nbsp)")

        // コンディション：enumerated値とmedia条件の先頭へASCII外whitespaceを置く（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        try fixture.writeRawHTML(
            "<style media=\"\(nbsp)all\(nbsp)\">#media{display:none}</style>"
                + "<div id=media>Media</div><input id=input-space type=\" hidden\">"
                + "<div id=display-nbsp style=\"display:\(nbsp)flex\">Display</div>"
                + "<div contenteditable=\" true\"><div id=invalid-child></div></div>"
                + "<div contenteditable=true><div id=valid-child></div></div>"
        )
        try fixture.writeCompanionCSS("")

        // 検証内容：標準source graphのUA/capability semanticsを取得する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        func node(_ id: String) throws -> OpenGraphiteAgentNode {
            try #require(graph.nodes.first { $0.attributes["id"] == id })
        }

        // 期待値：NBSP media/typeと空白付きcontenteditableをASCII keywordへ誤正規化しない（Then）
        #expect(try node("media").cssResolvedValues["display"] == "block")
        #expect(try node("display-nbsp").cssResolvedValues["display"] == "block")
        #expect(try node("input-space").cssResolvedValues["display"] == "inline-block")
        #expect(!(try node("invalid-child")).capabilities.contains(.editText))
        #expect(try node("valid-child").capabilities.contains(.editText))
    }

    /// 論理名（日本語）: CLI project migration routeテスト
    /// 概要: `ogkiln migrate`がdry-runを既定とし、proposalなしApplyをCoreのstructured diagnosticで返します。
    @Test("CLI migrateはdry-runを既定にしてproposalなしApplyをstructured拒否する")
    func testCLIMigrationDefaultsToDryRunAndRequiresProposal() throws {
        // コンディション：単一legacy pageを持つ登録projectとCLIを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        try fixture.writeRawHTML("<main data-og-type=\"frame\">Legacy</main>")
        try fixture.writeCSSLibrary("[data-og-type=\"frame\"] { display: block; }\n")
        try fixture.writeProject(to: projectURL)
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：既定routeとproposalなし--applyを順に実行する（When）
        let dryRunCode = cli.run(
            arguments: ["migrate", "Project.ogp", "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let dryRun = try JSONDecoder().decode(
            OpenGraphiteProjectMigrationResult.self,
            from: try #require(stdout.data(using: .utf8))
        )
        stdout = ""
        stderr = ""
        let applyCode = cli.run(
            arguments: ["migrate", "Project.ogp", "--apply", "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let rejected = try JSONDecoder().decode(
            OpenGraphiteProjectMigrationResult.self,
            from: try #require(stdout.data(using: .utf8))
        )

        // 期待値：dry-runはproposalを返し、apply preconditionはthrowせず同じresult schemaのerrorになる（Then）
        #expect(dryRunCode == 0)
        #expect(dryRun.dryRun)
        #expect(dryRun.proposalReference != nil)
        #expect(applyCode == 1)
        #expect(!rejected.dryRun)
        #expect(rejected.diagnostics.contains { $0.code == "migration-apply-requires-proposal" })
        #expect(stderr.isEmpty)
    }

    /// 論理名（日本語）: CSS migration token境界テスト
    /// 概要: mixed selector、functional runtime、namespace/operator/modifierを安全変換またはblockingへ分類します。
    @Test("CSS migrationはtoken境界外を保持して曖昧selectorをblockingする")
    func testCSSMigrationSelectorSafetyBoundary() {
        // コンディション：safe mixed selectorとfunctional/namespace/operatorのunsafe selectorを個別に用意する（Given）
        let safe = #"""
        .keep, [data-og-selected="true"] { color: red; }
        [DATA-OG-TYPE="FRAME" i] { display: block; }
        .foo\,bar[data-og-layout="vertical"] { display: flex; }
        """#
        let unsafe = #"""
        .card:is([data-og-selected], .featured) { color: red; }
        [*|data-og-type="frame"] { display: block; }
        [data-og-type^="frame"] { display: block; }
        """#

        // 検証内容：safe/unsafe sourceをそれぞれ明示migrationする（When）
        let safeResult = OpenGraphiteLegacyCSSMigrator.migrate(safe)
        let unsafeResult = OpenGraphiteLegacyCSSMigrator.migrate(unsafe)

        // 期待値：safe branchとescaped commaを保持し、曖昧構文はsource全体を不変にしてblocking理由を返す（Then）
        #expect(safeResult.unsupportedLegacyConstructs.isEmpty)
        #expect(safeResult.source.contains(".keep { color: red; }"))
        #expect(safeResult.source.contains(#".foo\,bar.og-migrated-v1-layout-vertical"#))
        #expect(safeResult.source.contains(".og-migrated-v1-type-frame"))
        #expect(!unsafeResult.unsupportedLegacyConstructs.isEmpty)
        #expect(unsafeResult.source == unsafe)
    }

    /// 論理名（日本語）: Canonical 0.1 CSS contract migrationテスト
    /// 概要: 0.1配布CSSのtheme、locale、type/layout、media/icon、transform patternを1.0標準declarationへ変換します。
    @Test("canonical 0.1 CSS patternを標準propertyとgeneric tokenへ移行する")
    func testCanonicalLegacyCSSMigrationUsesStandardProperties() {
        // コンディション：HEAD 0.1 CSSのroot/type/locale/media/icon/scale patternと無関係なproject tokenを用意する（Given）
        let legacy = #"""
        :root {
          --color-canvas: #fff;
          --color-text: #111;
          --og-page-background: var(--color-canvas);
          --og-text-color: var(--color-text);
          --og-muted-color: var(--color-muted);
          --og-accent: var(--color-accent);
          --og-accent-foreground: var(--color-accent-foreground);
        }
        html {
          background: var(--og-page-background);
          color: var(--og-text-color);
          font-family: var(--og-font-family-default, sans-serif);
        }
        [data-og-type] {
          --og-scale-x: 1;
          --og-scale-y: 1;
          --og-object-fit: cover;
          --og-stroke-width: 2;
          transform: scale(var(--og-scale-x), var(--og-scale-y));
        }
        [data-og-type="page"] { --og-active-font-family: var(--og-font-family-default, inherit); }
        :where(html:lang(ja), html[data-og-preview-locale|="ja"]) [data-og-type="page"] {
          --og-active-font-family: var(--og-font-family-ja, var(--og-font-family-default, inherit));
        }
        [data-og-type="text"] { font-family: var(--og-active-font-family, inherit); }
        [data-og-type="image"] > img { object-fit: var(--og-object-fit); }
        [data-og-type="icon"] > svg { stroke-width: var(--og-stroke-width); }
        [data-og-type="icon"] > [data-og-icon-mask="true"] {
          -webkit-mask-image: var(--og-icon-url);
          mask-image: var(--og-icon-url);
        }
        [data-og-layout="vertical"] { display: flex; flex-direction: column; }
        """#

        // 検証内容：lossless CSS migratorを一回実行する（When）
        let result = OpenGraphiteLegacyCSSMigrator.migrate(legacy)

        // 期待値：reserved prefixを残さず、standard property、generic token、zero-specificity locale、transform compositionを保つ（Then）
        #expect(result.detectedLegacy)
        #expect(result.unknownReservedProperties.isEmpty)
        #expect(result.unsupportedLegacyConstructs.isEmpty)
        #expect(result.destinationConflicts.isEmpty)
        #expect(!result.source.contains("--og-"))
        #expect(result.source.contains("--color-canvas: #fff"))
        #expect(result.source.contains("background: var(--migrated-v1-page-background)"))
        #expect(result.source.contains("object-fit: var(--migrated-v1-object-fit)"))
        #expect(result.source.contains("stroke-width: var(--migrated-v1-stroke-width)"))
        #expect(result.source.contains("mask-image: var(--migrated-v1-icon-url)"))
        #expect(result.source.contains("transform: scale(var(--migrated-v1-scale-x), var(--migrated-v1-scale-y))"))
        #expect(result.source.contains(":where(html:lang(ja)) .og-migrated-v1-type-page"))
        #expect(result.source.contains(".og-migrated-v1-layout-vertical"))
    }

    /// 論理名（日本語）: Project migration proposal project identity・staleテスト
    /// 概要: byte-identical clone間のproposal再利用と、proposal後のsource変更をwhole-project staleとして拒否します。
    @Test("migration proposalはproject identityと全source snapshotへ束縛される")
    func testMigrationProposalBindsProjectIdentityAndSourceSnapshot() throws {
        // コンディション：別rootにbyte-identicalな2 projectを用意し、一方でdry-run proposalを作る（Given）
        let first = try AgentInterfaceFixture()
        let second = try AgentInterfaceFixture()
        defer { first.cleanUp(); second.cleanUp() }
        let firstProjectURL = first.rootURL.appendingPathComponent("Project.ogp")
        let secondProjectURL = second.rootURL.appendingPathComponent("Project.ogp")
        let html = "<main data-og-type=\"frame\">Hello</main>"
        let css = "[data-og-type=\"frame\"] { display: block; }\n"
        for (fixture, projectURL) in [(first, firstProjectURL), (second, secondProjectURL)] {
            try fixture.writeRawHTML(html)
            try fixture.writeCSSLibrary(css)
            try fixture.writeProject(to: projectURL)
        }
        let firstDryRun = try first.core.migrateProject(projectURL: firstProjectURL)
        let firstProposal = try #require(firstDryRun.proposalReference)

        // 検証内容：AのtokenをBへ渡し、さらにAの登録HTML変更後にも同tokenをApplyする（When）
        let cloneApply = try second.core.migrateProject(
            projectURL: secondProjectURL,
            proposalReference: firstProposal,
            apply: true
        )
        try (html + "<!-- external edit -->").write(to: first.htmlURL, atomically: true, encoding: .utf8)
        let changedSnapshot = try String(contentsOf: first.htmlURL, encoding: .utf8)
        let staleApply = try first.core.migrateProject(
            projectURL: firstProjectURL,
            proposalReference: firstProposal,
            apply: true
        )

        // 期待値：双方をstaleとして拒否し、candidate diffを返さずApply直前bytesを保持する（Then）
        #expect(cloneApply.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!cloneApply.changed)
        #expect(cloneApply.diffs.isEmpty)
        #expect(try String(contentsOf: second.htmlURL, encoding: .utf8) == html)
        #expect(staleApply.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!staleApply.changed)
        #expect(staleApply.diffs.isEmpty)
        #expect(try String(contentsOf: first.htmlURL, encoding: .utf8) == changedSnapshot)

        // コンディション：別projectでproposal作成後に登録HTMLそのものを削除する（Given）
        let missing = try AgentInterfaceFixture()
        defer { missing.cleanUp() }
        let missingProjectURL = missing.rootURL.appendingPathComponent("Project.ogp")
        try missing.writeRawHTML(html)
        try missing.writeCSSLibrary(css)
        try missing.writeProject(to: missingProjectURL)
        let missingInitial = try missing.core.migrateProject(projectURL: missingProjectURL)
        let missingProposal = try #require(missingInitial.proposalReference)
        try FileManager.default.removeItem(at: missing.htmlURL)

        // 検証内容：存在bitが変わったsnapshotへ旧proposalをApplyする（When）
        let missingApply = try missing.core.migrateProject(
            projectURL: missingProjectURL,
            proposalReference: missingProposal,
            apply: true
        )
        let missingAfterRemoval = try missing.core.migrateProject(projectURL: missingProjectURL)

        // 期待値：missing sourceを作り直さずstale/registered-resource diagnosticで全体拒否する（Then）
        #expect(missingApply.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(missingApply.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(!missingApply.dryRun)
        #expect(missingAfterRemoval.dryRun)
        #expect(missingAfterRemoval.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(!missingAfterRemoval.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!missingAfterRemoval.changed)
        #expect(missingAfterRemoval.diffs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: missing.htmlURL.path))
    }

    /// 論理名（日本語）: Migration symlink containment・identityテスト
    /// 概要: symlink解決後root外resourceと、proposal後のauthored symlink repointをatomicに拒否します。
    @Test("migrationはsymlink root escapeとrepointを拒否する")
    func testMigrationRejectsSymlinkEscapeAndRepoint() throws {
        // コンディション：root内2 targetへ向くauthored page symlinkと、root外targetへ向く別projectを用意する（Given）
        let repoint = try AgentInterfaceFixture()
        let escape = try AgentInterfaceFixture()
        let outsideDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteMigrationOutside-\(UUID().uuidString)")
        defer {
            repoint.cleanUp()
            escape.cleanUp()
            try? FileManager.default.removeItem(at: outsideDirectory)
        }
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        let repointProjectURL = repoint.rootURL.appendingPathComponent("Project.ogp")
        let targetsURL = repoint.rootURL.appendingPathComponent("targets", isDirectory: true)
        try FileManager.default.createDirectory(at: targetsURL, withIntermediateDirectories: true)
        let firstTarget = targetsURL.appendingPathComponent("first.html")
        let secondTarget = targetsURL.appendingPathComponent("second.html")
        let legacyHTML = "<main data-og-type=\"frame\">Legacy</main>"
        try legacyHTML.write(to: firstTarget, atomically: true, encoding: .utf8)
        try legacyHTML.write(to: secondTarget, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: repoint.htmlURL, withDestinationURL: firstTarget)
        try repoint.writeCSSLibrary("")
        try repoint.writeProject(to: repointProjectURL)
        let dryRun = try repoint.core.migrateProject(projectURL: repointProjectURL)
        let proposal = try #require(dryRun.proposalReference)
        try FileManager.default.removeItem(at: repoint.htmlURL)
        try FileManager.default.createSymbolicLink(at: repoint.htmlURL, withDestinationURL: secondTarget)

        let escapeProjectURL = escape.rootURL.appendingPathComponent("Project.ogp")
        let outsideHTML = outsideDirectory.appendingPathComponent("outside.html")
        try legacyHTML.write(to: outsideHTML, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: escape.htmlURL, withDestinationURL: outsideHTML)
        try escape.writeCSSLibrary("")
        try escape.writeProject(to: escapeProjectURL)

        // 検証内容：repoint後Applyとroot escape projectのdry-runを実行する（When）
        let repointed = try repoint.core.migrateProject(
            projectURL: repointProjectURL,
            proposalReference: proposal,
            apply: true
        )
        let escaped = try escape.core.migrateProject(projectURL: escapeProjectURL)

        // 期待値：authored symlink identity変更はstale、root外targetはcontainment errorとなり両target bytesを保持する（Then）
        #expect(repointed.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(try String(contentsOf: firstTarget, encoding: .utf8) == legacyHTML)
        #expect(try String(contentsOf: secondTarget, encoding: .utf8) == legacyHTML)
        #expect(escaped.diagnostics.contains { $0.code == "migration-resource-outside-project-root" })
        #expect(escaped.proposalReference == nil)
        #expect(try String(contentsOf: outsideHTML, encoding: .utf8) == legacyHTML)
    }

    /// 論理名（日本語）: Manifest raw previewContext migrationテスト
    /// 概要: schema path内のknown preview fieldだけをraw range patchし、未知field/triviaを保持します。
    @Test("manifest migrationはknown preview fieldだけをraw range patchする")
    func testManifestMigrationPatchesKnownPreviewFieldsLosslessly() throws {
        // コンディション：page canvas placementMocksにknown legacy fieldと未知fieldを持つraw manifestを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        try fixture.writeRawHTML("<main>Standard</main>")
        try fixture.writeCSSLibrary("")
        try fixture.writeProject(to: projectURL)
        let original = try String(contentsOf: projectURL, encoding: .utf8)
        let needle = """
                    "height": 1200
        """
        let replacement = """
                    "height": 1200,
                    "previewContext": {
                      "placementMocks": {
                        "fixture-preview": { "codeViewerMode" : "preview", "customState" : "kept" },
                        "fixture-collapsed": { "placementMode" : "collapsed", "customState" : "also-kept" }
                      }
                    }
        """
        let legacyManifest = original.replacingOccurrences(of: needle, with: replacement)
        try legacyManifest.write(to: projectURL, atomically: true, encoding: .utf8)

        // 検証内容：dry-run proposalを明示Applyする（When）
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        let migrated = try String(contentsOf: projectURL, encoding: .utf8)

        // 期待値：known key/valueだけがhost.variantへ変わり、schema version、未知field、authored formattingを保持する（Then）
        #expect(dryRun.diffs.map(\.path) == ["Project.ogp"])
        #expect(applied.applied)
        #expect(migrated.contains(#""host.variant" : "preview""#))
        #expect(migrated.contains(#""host.variant" : "collapsible collapsed""#))
        #expect(migrated.contains(#""customState" : "kept""#))
        #expect(migrated.contains(#""customState" : "also-kept""#))
        #expect(migrated.contains(#""version": "0.1.0""#))
        #expect(!migrated.contains("codeViewerMode"))
        #expect(!migrated.contains("placementMode"))
    }

    /// 論理名（日本語）: Manifest preview conflict・duplicate keyテスト
    /// 概要: legacy/new field異値とplacement key重複をstructured diagnosticでatomic blockします。
    @Test("manifest migrationはpreview conflictとduplicate keyをatomic blockする")
    func testManifestMigrationBlocksConflictAndDuplicateKeys() throws {
        // コンディション：host.variant異値衝突とduplicate placement keyを持つ2つのraw manifestを用意する（Given）
        let conflictFixture = try AgentInterfaceFixture()
        let duplicateFixture = try AgentInterfaceFixture()
        defer { conflictFixture.cleanUp(); duplicateFixture.cleanUp() }
        let conflictProjectURL = conflictFixture.rootURL.appendingPathComponent("Project.ogp")
        let duplicateProjectURL = duplicateFixture.rootURL.appendingPathComponent("Project.ogp")
        let canvasNeedle = """
                    "height": 1200
        """
        let conflictCanvas = """
                    "height": 1200,
                    "previewContext": { "placementMocks": {
                      "fixture": { "codeViewerMode": "preview", "host.variant": "code" }
                    } }
        """
        let duplicateCanvas = """
                    "height": 1200,
                    "previewContext": { "placementMocks": {
                      "fixture": { "codeViewerMode": "preview" },
                      "fixture": { "codeViewerMode": "preview" }
                    } }
        """
        for (fixture, projectURL, replacement) in [
            (conflictFixture, conflictProjectURL, conflictCanvas),
            (duplicateFixture, duplicateProjectURL, duplicateCanvas)
        ] {
            try fixture.writeRawHTML("<main>Standard</main>")
            try fixture.writeCSSLibrary("")
            try fixture.writeProject(to: projectURL)
            let raw = try String(contentsOf: projectURL, encoding: .utf8)
                .replacingOccurrences(of: canvasNeedle, with: replacement)
            try raw.write(to: projectURL, atomically: true, encoding: .utf8)
        }
        let conflictBefore = try String(contentsOf: conflictProjectURL, encoding: .utf8)
        let duplicateBefore = try String(contentsOf: duplicateProjectURL, encoding: .utf8)

        // 検証内容：両projectをdry-runする（When）
        let conflict = try conflictFixture.core.migrateProject(projectURL: conflictProjectURL)
        let duplicate = try duplicateFixture.core.migrateProject(projectURL: duplicateProjectURL)

        // 期待値：固有diagnosticとempty candidateを返し、raw manifest bytesを変更しない（Then）
        #expect(conflict.diagnostics.contains { $0.code == "legacy-preview-context-conflict" })
        #expect(!conflict.changed)
        #expect(conflict.diffs.isEmpty)
        #expect(conflict.proposalReference == nil)
        #expect(duplicate.diagnostics.contains { $0.code == "migration-manifest-duplicate-key" })
        #expect(!duplicate.changed)
        #expect(duplicate.diffs.isEmpty)
        #expect(duplicate.proposalReference == nil)
        #expect(try String(contentsOf: conflictProjectURL, encoding: .utf8) == conflictBefore)
        #expect(try String(contentsOf: duplicateProjectURL, encoding: .utf8) == duplicateBefore)
    }

    /// 論理名（日本語）: Linked stylesheet closure migrationテスト
    /// 概要: registered HTMLのlocal linkとtop-level real importを再帰列挙し、comment内fake importを無視してsnapshotへ束縛します。
    @Test("migrationはlocal stylesheet closureだけを再帰列挙する")
    func testMigrationEnumeratesLocalStylesheetClosure() throws {
        // コンディション：HTML link、real nested import、comment内fake import、末端legacy selectorを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        let malformedFixture = try AgentInterfaceFixture()
        let lateFixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp(); malformedFixture.cleanUp(); lateFixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let stylesURL = fixture.rootURL.appendingPathComponent("styles", isDirectory: true)
        try FileManager.default.createDirectory(at: stylesURL, withIntermediateDirectories: true)
        let pageCSSURL = stylesURL.appendingPathComponent("page.css")
        let themeCSSURL = stylesURL.appendingPathComponent("theme.css")
        try fixture.writeRawHTML(#"<link rel="stylesheet" href="styles/page.css"><main data-og-type="frame">Hello</main>"#)
        try fixture.writeCSSLibrary("")
        try #"@import "theme\2e css" layer(theme) screen; /* @import "missing.css"; */"#.write(to: pageCSSURL, atomically: true, encoding: .utf8)
        try "[data-og-type=\"frame\"] { display: block; }\n".write(to: themeCSSURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)
        let malformedProjectURL = malformedFixture.rootURL.appendingPathComponent("Project.ogp")
        let malformedCSSURL = malformedFixture.rootURL.appendingPathComponent("malformed.css")
        try malformedFixture.writeRawHTML(#"<link rel="stylesheet" href="malformed.css"><main data-og-type="frame">Legacy</main>"#)
        try malformedFixture.writeCSSLibrary("")
        try #"@import "theme.css" garbage???; [data-og-type="frame"] { display: block; }"#.write(
            to: malformedCSSURL,
            atomically: true,
            encoding: .utf8
        )
        try malformedFixture.writeProject(to: malformedProjectURL)
        let lateProjectURL = lateFixture.rootURL.appendingPathComponent("Project.ogp")
        let lateCSSURL = lateFixture.rootURL.appendingPathComponent("late.css")
        try lateFixture.writeRawHTML(#"<link rel="stylesheet" href="late.css"><main data-og-type="frame">Legacy</main>"#)
        try lateFixture.writeCSSLibrary("")
        try #".authored { color: red; } @import "ignored.css"; [data-og-type="frame"] { display: block; }"#.write(
            to: lateCSSURL,
            atomically: true,
            encoding: .utf8
        )
        try lateFixture.writeProject(to: lateProjectURL)

        // 検証内容：dry-run後にunchanged dependencyを変更してstaleを確認し、新proposalをApplyする（When）
        let initial = try fixture.core.migrateProject(projectURL: projectURL)
        let initialProposal = try #require(initial.proposalReference)
        try #"@import "theme\2e css" layer(theme) screen; /* changed dependency; @import "missing.css"; */"#.write(
            to: pageCSSURL,
            atomically: true,
            encoding: .utf8
        )
        let stale = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: initialProposal,
            apply: true
        )
        let refreshed = try fixture.core.migrateProject(projectURL: projectURL)
        let refreshedProposal = try #require(refreshed.proposalReference)
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: refreshedProposal,
            apply: true
        )
        let malformed = try malformedFixture.core.migrateProject(projectURL: malformedProjectURL)
        let late = try lateFixture.core.migrateProject(projectURL: lateProjectURL)

        // 期待値：fake importはmissing扱いせず、unchanged dependencyもproposal staleへ参加し、real import末端だけを変換する（Then）
        #expect(!initial.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(stale.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!stale.changed)
        #expect(applied.applied)
        #expect(try String(contentsOf: themeCSSURL, encoding: .utf8).contains(".og-migrated-v1-type-frame"))
        #expect(try String(contentsOf: pageCSSURL, encoding: .utf8).contains("missing.css"))
        #expect(malformed.diagnostics.contains { $0.code == "unsupported-legacy-import-reference" })
        #expect(malformed.proposalReference == nil)
        #expect(malformed.diffs.isEmpty)
        #expect(late.diagnostics.contains { $0.code == "unsupported-legacy-import-reference" })
        #expect(late.proposalReference == nil)
        #expect(late.diffs.isEmpty)
    }

    /// 論理名（日本語）: Base href・CSS at-keyword境界テスト
    /// 概要: 最初のbase[href]をstylesheet正本に使い、NBSP/escapeを含むat-keywordを実importへ誤分類しません。
    @Test("migrationはfirst base hrefとCSS at-keyword境界でdependencyを列挙する")
    func testMigrationUsesFirstBaseHrefAndCSSAtKeywordBoundaries() throws {
        // コンディション：hrefなしbaseの後にsub baseと同名CSSを置き、NBSP/escaped importの別projectを作る（Given）
        let fixture = try AgentInterfaceFixture()
        let escapedFixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp(); escapedFixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let subURL = fixture.rootURL.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subURL, withIntermediateDirectories: true)
        let rootThemeURL = fixture.rootURL.appendingPathComponent("theme.css")
        let subThemeURL = subURL.appendingPathComponent("theme.css")
        let html = #"<base target="_blank"><base href="sub/"><link rel="stylesheet" href="theme.css"><main id="target" data-og-type="frame">Legacy</main>"#
        let rootTheme = "#target { display: grid; }\n:root { --og-project-private: red; }\n"
        let subTheme = "@import\u{00A0}\"missing.css\"; #target { display: flex; } [data-og-type=\"frame\"] { color: red; }\n"
        try fixture.writeRawHTML(html)
        try fixture.writeCSSLibrary("")
        try rootTheme.write(to: rootThemeURL, atomically: true, encoding: .utf8)
        try subTheme.write(to: subThemeURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        let escapedProjectURL = escapedFixture.rootURL.appendingPathComponent("Project.ogp")
        let escapedCSSURL = escapedFixture.rootURL.appendingPathComponent("page.css")
        let escapedDependencyURL = escapedFixture.rootURL.appendingPathComponent("legacy.css")
        let escapedHTML = #"<link rel="stylesheet" href="page.css"><main data-og-type="frame">Legacy</main>"#
        let escapedCSS = #"@\69mport "legacy.css"; .authored { display: block; }"#
        try escapedFixture.writeRawHTML(escapedHTML)
        try escapedFixture.writeCSSLibrary("")
        try escapedCSS.write(to: escapedCSSURL, atomically: true, encoding: .utf8)
        try #"[data-og-type="frame"] { display: block; }"#.write(
            to: escapedDependencyURL,
            atomically: true,
            encoding: .utf8
        )
        try escapedFixture.writeProject(to: escapedProjectURL)

        // 検証内容：browser-facing graph、dry-run/apply/idempotency、escaped importのsafe blockを確認する（When）
        let graph = try fixture.core.pageGraph(at: fixture.htmlURL)
        let target = try #require(graph.nodes.first { $0.attributes["id"] == "target" })
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: try #require(dryRun.proposalReference),
            apply: true
        )
        let repeated = try fixture.core.migrateProject(projectURL: projectURL)
        let escaped = try escapedFixture.core.migrateProject(projectURL: escapedProjectURL)

        // 期待値：sub正本だけを変換し、NBSP at-keywordはmissing依存にせず、escaped importはsilent missせずblockする（Then）
        #expect(target.cssResolvedValues["display"] == "flex")
        #expect(dryRun.diagnostics.isEmpty)
        #expect(dryRun.diffs.map(\.path) == ["index.html", "sub/theme.css"])
        #expect(!dryRun.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(applied.applied)
        #expect(applied.diagnostics.isEmpty)
        #expect(try String(contentsOf: rootThemeURL, encoding: .utf8) == rootTheme)
        #expect(try String(contentsOf: subThemeURL, encoding: .utf8).contains(".og-migrated-v1-type-frame"))
        #expect(!repeated.changed)
        #expect(repeated.diffs.isEmpty)
        #expect(escaped.diagnostics.contains { $0.code == "unsupported-legacy-import-reference" })
        #expect(!escaped.changed)
        #expect(escaped.diffs.isEmpty)
        #expect(escaped.proposalReference == nil)
        #expect(try String(contentsOf: escapedDependencyURL, encoding: .utf8).contains("data-og-type"))
    }

    /// 論理名（日本語）: Extensionless・embedded migration dependencyテスト
    /// 概要: HTML由来source kind、document base、embedded style import、kind conflict、optional missing dependency境界を固定します。
    @Test("migrationはHTML由来kindでextensionlessとembedded dependencyを列挙する")
    func testMigrationEnumeratesExtensionlessAndEmbeddedDependenciesBySourceKind() throws {
        // コンディション：base相対のextensionless link/scriptと、embedded styleからimportするextensionless CSSを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        let conflictFixture = try AgentInterfaceFixture()
        let missingFixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp(); conflictFixture.cleanUp(); missingFixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let assetsURL = fixture.rootURL.appendingPathComponent("assets", isDirectory: true)
        let stylesURL = fixture.rootURL.appendingPathComponent("styles", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stylesURL, withIntermediateDirectories: true)
        let linkedCSSURL = stylesURL.appendingPathComponent("page")
        let embeddedImportURL = assetsURL.appendingPathComponent("theme")
        let runtimeURL = fixture.rootURL.appendingPathComponent("runtime")
        try fixture.writeRawHTML(#"<base href="assets/"><link rel="stylesheet" href="../styles/page"><style>@import "theme";</style><main data-og-type="frame" data-og-layout="vertical">Legacy</main><script src="../runtime"></script>"#)
        try fixture.writeCSSLibrary("")
        try #"[data-og-layout="vertical"] { display: flex; }"#.write(
            to: linkedCSSURL,
            atomically: true,
            encoding: .utf8
        )
        try #"[data-og-type="frame"] { display: block; }"#.write(
            to: embeddedImportURL,
            atomically: true,
            encoding: .utf8
        )
        try #"console.log("clean extensionless runtime");"#.write(
            to: runtimeURL,
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(to: projectURL)

        let conflictProjectURL = conflictFixture.rootURL.appendingPathComponent("Project.ogp")
        let sharedURL = conflictFixture.rootURL.appendingPathComponent("shared")
        try conflictFixture.writeRawHTML(#"<link rel="stylesheet" href="shared"><script src="shared"></script><main data-og-type="frame">Legacy</main>"#)
        try conflictFixture.writeCSSLibrary("")
        try #"[data-og-type="frame"] { display: block; }"#.write(
            to: sharedURL,
            atomically: true,
            encoding: .utf8
        )
        try conflictFixture.writeProject(to: conflictProjectURL)

        let missingProjectURL = missingFixture.rootURL.appendingPathComponent("Project.ogp")
        let invalidCSSURL = missingFixture.rootURL.appendingPathComponent("invalid-css")
        let invalidRuntimeURL = missingFixture.rootURL.appendingPathComponent("invalid-runtime")
        let outsideReference = "../outside-\(UUID().uuidString)"
        let cleanDependencyHTML = """
        <link rel="stylesheet" href="missing"><link rel="stylesheet" href="invalid-css"><link rel="stylesheet" href="\(outsideReference)"><script src="invalid-runtime"></script><p>Clean</p>
        """
        try missingFixture.writeRawHTML(cleanDependencyHTML)
        try missingFixture.writeCSSLibrary("")
        try Data([0xFF]).write(to: invalidCSSURL)
        try Data([0xFE]).write(to: invalidRuntimeURL)
        try missingFixture.writeProject(to: missingProjectURL)

        // 検証内容：安全projectをdry-run/applyし、runtime legacy・kind conflict・clean/legacy missingを順に検査する（When）
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        try #"document.querySelector("[data-og-type]");"#.write(
            to: runtimeURL,
            atomically: true,
            encoding: .utf8
        )
        let runtimeBlocked = try fixture.core.migrateProject(projectURL: projectURL)
        let kindConflict = try conflictFixture.core.migrateProject(projectURL: conflictProjectURL)
        try conflictFixture.writeRawHTML(#"<link rel="stylesheet" href="shared"><script src="shared"></script><p>Clean</p>"#)
        try #".clean { display: block; }"#.write(to: sharedURL, atomically: true, encoding: .utf8)
        let cleanKindConflict = try conflictFixture.core.migrateProject(projectURL: conflictProjectURL)
        let cleanMissing = try missingFixture.core.migrateProject(projectURL: missingProjectURL)
        try missingFixture.writeRawHTML(
            cleanDependencyHTML.replacingOccurrences(
                of: "<p>Clean</p>",
                with: #"<main data-og-type="frame">Legacy</main>"#
            )
        )
        let legacyMissing = try missingFixture.core.migrateProject(projectURL: missingProjectURL)

        // 期待値：extensionに依存せず全CSSを変換し、unsafe source kind/missing dependencyはlegacy projectだけatomic blockする（Then）
        #expect(dryRun.diagnostics.isEmpty)
        #expect(dryRun.diffs.map(\.path).contains("assets/theme"))
        #expect(dryRun.diffs.map(\.path).contains("styles/page"))
        #expect(applied.applied)
        #expect(try String(contentsOf: linkedCSSURL, encoding: .utf8).contains(".og-migrated-v1-layout-vertical"))
        #expect(try String(contentsOf: embeddedImportURL, encoding: .utf8).contains(".og-migrated-v1-type-frame"))
        #expect(runtimeBlocked.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(kindConflict.diagnostics.contains { $0.code == "migration-resource-kind-conflict" })
        #expect(kindConflict.diffs.isEmpty)
        #expect(!cleanKindConflict.changed)
        #expect(!cleanKindConflict.diagnostics.contains { $0.code == "migration-resource-kind-conflict" })
        #expect(!cleanMissing.changed)
        #expect(!cleanMissing.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(!cleanMissing.diagnostics.contains { $0.code == "migration-resource-outside-project-root" })
        #expect(!cleanMissing.diagnostics.contains { $0.code == "migration-source-unreadable" })
        #expect(legacyMissing.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(legacyMissing.diagnostics.contains { $0.code == "migration-resource-outside-project-root" })
        #expect(legacyMissing.diagnostics.filter { $0.code == "migration-source-unreadable" }.count == 2)
        #expect(legacyMissing.diffs.isEmpty)
    }

    /// 論理名（日本語）: Migration UTF-8 BOM snapshotテスト
    /// 概要: raw BOM bytesをdiff/proposalへ束縛し、applyで維持してBOMだけの外部変更もstaleにします。
    @Test("migrationはUTF-8 BOMをraw snapshotとして維持する")
    func testMigrationPreservesUTF8BOMAndDetectsBOMOnlyStaleChange() throws {
        // コンディション：同じlegacy HTMLへUTF-8 BOMを付けたapply用とstale用projectを用意する（Given）
        let appliedFixture = try AgentInterfaceFixture()
        let staleFixture = try AgentInterfaceFixture()
        defer { appliedFixture.cleanUp(); staleFixture.cleanUp() }
        let html = #"<main data-og-type="frame">Legacy</main>"#
        var bomHTML = Data([0xEF, 0xBB, 0xBF])
        bomHTML.append(contentsOf: html.utf8)
        let appliedProjectURL = appliedFixture.rootURL.appendingPathComponent("Project.ogp")
        let staleProjectURL = staleFixture.rootURL.appendingPathComponent("Project.ogp")
        for (fixture, projectURL) in [(appliedFixture, appliedProjectURL), (staleFixture, staleProjectURL)] {
            try bomHTML.write(to: fixture.htmlURL)
            try fixture.writeCSSLibrary("")
            try fixture.writeProject(to: projectURL)
        }

        // 検証内容：raw hashを持つproposalをapplyし、別projectではBOMだけを除去して旧proposalをapplyする（When）
        let dryRun = try appliedFixture.core.migrateProject(projectURL: appliedProjectURL)
        let proposal = try #require(dryRun.proposalReference)
        let applied = try appliedFixture.core.migrateProject(
            projectURL: appliedProjectURL,
            proposalReference: proposal,
            apply: true
        )
        let staleDryRun = try staleFixture.core.migrateProject(projectURL: staleProjectURL)
        let staleProposal = try #require(staleDryRun.proposalReference)
        let withoutBOM = Data(html.utf8)
        try withoutBOM.write(to: staleFixture.htmlURL)
        let stale = try staleFixture.core.migrateProject(
            projectURL: staleProjectURL,
            proposalReference: staleProposal,
            apply: true
        )
        let rawApplied = try Data(contentsOf: appliedFixture.htmlURL)
        let expectedBeforeHash = SHA256.hash(data: bomHTML).map { String(format: "%02x", $0) }.joined()
        let htmlDiff = try #require(dryRun.diffs.first { $0.path == "index.html" })

        // 期待値：before hashはBOM込みで、migration後もBOMを保持し、BOM-only変更は全source stale/no-writeになる（Then）
        #expect(htmlDiff.beforeHash == expectedBeforeHash)
        #expect(applied.applied)
        #expect(rawApplied.starts(with: [0xEF, 0xBB, 0xBF]))
        #expect(String(data: Data(rawApplied.dropFirst(3)), encoding: .utf8)?.contains("og-migrated-v1-type-frame") == true)
        #expect(stale.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!stale.changed)
        #expect(stale.diffs.isEmpty)
        #expect(try Data(contentsOf: staleFixture.htmlURL) == withoutBOM)
    }

    /// 論理名（日本語）: Runtime・structural legacy safe-boundaryテスト
    /// 概要: 自動変換対象外のinline/external runtime、entity inline CSS、component slot/placementをatomic blockします。
    @Test("migrationはruntimeとstructural legacyのunsafe境界をno-writeにする")
    func testMigrationBlocksUnsafeRuntimeAndStructuralLegacy() throws {
        // コンディション：raw rangeへ対応不能なinline CSSとcomponent構造、legacy readerを含むHTML候補を用意する（Given）
        let unsafeHTMLSources = [
            #"<main data-og-type="frame" style="color&colon;var(&#45;&#45;og-accent)">Entity style</main>"#,
            #"<legacy-card data-og-component-kind="master"><span data-og-slot="title">Fallback</span></legacy-card>"#,
            #"<og-placement data-og-placement-mode="collapsed">Placement</og-placement>"#,
            #"<main data-og-type="frame">Runtime</main><script>document.querySelector("[data-og-type]")</script>"#
        ]

        // 検証内容：各HTMLを独立に明示migrationする（When）
        let migrations = unsafeHTMLSources.map {
            OpenGraphiteHTMLDocument(html: $0).migratingLegacyWebContract(path: "index.html")
        }

        // 期待値：全caseがsource不変かつ固有blocking diagnosticを返す（Then）
        #expect(zip(migrations, unsafeHTMLSources).allSatisfy { $0.source == $1 })
        #expect(migrations[0].diagnostics.contains { $0.code == "unsupported-legacy-inline-style" })
        #expect(migrations[1].diagnostics.contains { $0.code == "unsupported-legacy-component-slot" })
        #expect(migrations[2].diagnostics.contains { $0.code == "unsupported-legacy-placement-context" })
        #expect(migrations[3].diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })

        // コンディション：external runtimeとexternal baseを持つ別々のregistered projectを用意する（Given）
        let runtimeFixture = try AgentInterfaceFixture()
        let baseFixture = try AgentInterfaceFixture()
        let moduleFixture = try AgentInterfaceFixture()
        let inlineModuleFixture = try AgentInterfaceFixture()
        let cleanInlineFixture = try AgentInterfaceFixture()
        let cleanExternalFixture = try AgentInterfaceFixture()
        defer {
            runtimeFixture.cleanUp()
            baseFixture.cleanUp()
            moduleFixture.cleanUp()
            inlineModuleFixture.cleanUp()
            cleanInlineFixture.cleanUp()
            cleanExternalFixture.cleanUp()
        }
        let runtimeProjectURL = runtimeFixture.rootURL.appendingPathComponent("Project.ogp")
        let baseProjectURL = baseFixture.rootURL.appendingPathComponent("Project.ogp")
        let moduleProjectURL = moduleFixture.rootURL.appendingPathComponent("Project.ogp")
        let inlineModuleProjectURL = inlineModuleFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanInlineProjectURL = cleanInlineFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanExternalProjectURL = cleanExternalFixture.rootURL.appendingPathComponent("Project.ogp")
        try runtimeFixture.writeRawHTML(#"<main data-og-type="frame">Legacy</main><script src="https://example.invalid/runtime.js"></script>"#)
        try runtimeFixture.writeCSSLibrary("")
        try runtimeFixture.writeProject(to: runtimeProjectURL)
        try baseFixture.writeRawHTML(#"<base href="assets&fjlig;/"><main data-og-type="frame">Legacy</main>"#)
        try baseFixture.writeCSSLibrary("")
        try baseFixture.writeProject(to: baseProjectURL)
        try moduleFixture.writeRawHTML(#"<main data-og-type="frame">Legacy</main><script type="module" src="runtime.js"></script>"#)
        try moduleFixture.writeCSSLibrary("")
        try "// clean comment\rconst pattern = /[//]/; import \"./legacy-reader.js\"; console.log(\"clean direct module\");".write(
            to: moduleFixture.rootURL.appendingPathComponent("runtime.js"),
            atomically: true,
            encoding: .utf8
        )
        try moduleFixture.writeProject(to: moduleProjectURL)
        try inlineModuleFixture.writeRawHTML(
            "<main data-og-type=\"frame\">Legacy</main><script type=\"module\">"
                + "const value = `${(()=>{// clean\u{2028}const pattern = /[/*]/; return import(\"./legacy-reader.js\")})()}`"
                + "</script>"
        )
        try inlineModuleFixture.writeCSSLibrary("")
        try inlineModuleFixture.writeProject(to: inlineModuleProjectURL)
        let cleanCommentDependencies = "// import('./fake-cr.js')\r// import('./fake-ls.js')\u{2028}// import('./fake-ps.js')\u{2029}"
            + "console.log(import\u{FEFF}.meta); const value = `${(()=>{// import('./fake-template.js')\rreturn 1})()}`"
        try cleanInlineFixture.writeRawHTML(
            "<main data-og-type=\"frame\">Legacy</main><script type=\"module\">\(cleanCommentDependencies)</script>"
        )
        try cleanInlineFixture.writeCSSLibrary("")
        try cleanInlineFixture.writeProject(to: cleanInlineProjectURL)
        try cleanExternalFixture.writeRawHTML(#"<main data-og-type="frame">Legacy</main><script type="module" src="runtime.js"></script>"#)
        try cleanCommentDependencies.write(
            to: cleanExternalFixture.rootURL.appendingPathComponent("runtime.js"),
            atomically: true,
            encoding: .utf8
        )
        try cleanExternalFixture.writeCSSLibrary("")
        try cleanExternalFixture.writeProject(to: cleanExternalProjectURL)

        // 検証内容：external/module dependencyとclean inline scriptを持つprojectをdry-runする（When）
        let runtimeResult = try runtimeFixture.core.migrateProject(projectURL: runtimeProjectURL)
        let baseResult = try baseFixture.core.migrateProject(projectURL: baseProjectURL)
        let moduleResult = try moduleFixture.core.migrateProject(projectURL: moduleProjectURL)
        let inlineModuleResult = try inlineModuleFixture.core.migrateProject(projectURL: inlineModuleProjectURL)
        let cleanInlineResult = try cleanInlineFixture.core.migrateProject(projectURL: cleanInlineProjectURL)
        let cleanExternalResult = try cleanExternalFixture.core.migrateProject(projectURL: cleanExternalProjectURL)

        // 期待値：検証不能なexternal/module dependencyはwhole-project error、clean inline scriptは候補化する（Then）
        #expect(runtimeResult.diagnostics.contains { $0.code == "unsupported-legacy-external-runtime" })
        #expect(runtimeResult.proposalReference == nil)
        #expect(runtimeResult.diffs.isEmpty)
        #expect(baseResult.diagnostics.contains { $0.code == "unsupported-legacy-external-base" })
        #expect(baseResult.proposalReference == nil)
        #expect(baseResult.diffs.isEmpty)
        #expect(moduleResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-dependency" })
        #expect(moduleResult.proposalReference == nil)
        #expect(moduleResult.diffs.isEmpty)
        #expect(inlineModuleResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-dependency" })
        #expect(inlineModuleResult.proposalReference == nil)
        #expect(inlineModuleResult.diffs.isEmpty)
        #expect(!cleanInlineResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-dependency" })
        #expect(cleanInlineResult.proposalReference != nil)
        #expect(!cleanExternalResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-dependency" })
        #expect(cleanExternalResult.proposalReference != nil)
    }

    /// 論理名（日本語）: Cross-source migration destination collisionテスト
    /// 概要: generated class/custom-property destinationが別登録sourceのauthored tokenと競合すると全projectを拒否します。
    @Test("migrationはcross-source generated destination collisionを拒否する")
    func testMigrationRejectsCrossSourceGeneratedDestinationCollisions() throws {
        // コンディション：HTMLが生成するclassとCSSが生成するcustom propertyの各destinationを別linked CSSが先取りする（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let authoredURL = fixture.rootURL.appendingPathComponent("authored.css")
        try fixture.writeRawHTML(#"<link rel="stylesheet" href="authored.css"><main data-og-type="frame">Legacy</main>"#)
        try fixture.writeCSSLibrary(":root { --og-accent: red; }\n")
        try #"""
.og\-migrated-v1-type-frame { display: inline; }
.card { color: var(--migrated-v1-accent); }
"""#.write(
            to: authoredURL,
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：project migrationをdry-runする（When）
        let result = try fixture.core.migrateProject(projectURL: projectURL)

        // 期待値：classとcustom propertyのcross-source collisionを両方診断してcandidateを破棄する（Then）
        #expect(result.diagnostics.contains { $0.code == "migration-generated-class-conflict" })
        #expect(result.diagnostics.contains { $0.code == "legacy-css-destination-conflict" })
        #expect(!result.changed)
        #expect(result.diffs.isEmpty)
        #expect(result.proposalReference == nil)
    }

    /// 論理名（日本語）: Generated class collision精度テスト
    /// 概要: legacy replacementが実際に生成しないmigration namespace classはcollisionへ誤分類しません。
    @Test("migrationは実際に生成するclassだけをcollision判定する")
    func testMigrationGeneratedClassCollisionAvoidsUnrelatedNamespaceClass() throws {
        // コンディション：既存type namespace classと、別のlayout legacy selector/HTMLだけを同じprojectへ置く（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        try fixture.writeRawHTML(#"<main data-og-layout="vertical">Legacy</main>"#)
        try fixture.writeCSSLibrary(
            ".og-migrated-v1-type-frame, [data-og-layout=\"vertical\"] { display: flex; }\n"
        )
        try fixture.writeProject(to: projectURL)

        // 検証内容：project migrationをdry-runする（When）
        let result = try fixture.core.migrateProject(projectURL: projectURL)

        // 期待値：生成対象layout classだけを追跡し、無関係な既存type classではblockしない（Then）
        #expect(!result.diagnostics.contains { $0.code == "migration-generated-class-conflict" })
        #expect(result.diagnostics.isEmpty)
        #expect(result.changed)
        #expect(result.proposalReference != nil)
    }

    /// 論理名（日本語）: Legacy JavaScript reader catalogテスト
    /// 概要: inline/linked runtimeが共有するdataset accessとgenerated destination observerのsemantic境界を固定します。
    @Test("migration runtime inspectorはdatasetとdestination observerを検出する")
    func testMigrationRuntimeInspectorDetectsDatasetAndDestinationObservers() {
        // コンディション：exact reader、dataset/style列取得、destination observerとcomment-only textを用意する（Given）
        let readers = [
            "node.dataset.ogType",
            "node?.dataset?.ogLayout",
            "node.dataset['ogHidden']",
            "node.dataset?.[\"ogVariant\"]"
        ]
        let classObservers = [
            "node.className",
            "node?.classList.values()",
            "node['className']",
            "node[\"classList\"]",
            "const { className, classList } = node",
            "node.getAttribute('class')",
            "node.setAttribute('class', 'updated')",
            "node.removeAttribute('class')",
            "node.toggleAttribute('class')",
            "node['getAttribute']('class')",
            "const readClass = node.getAttribute; readClass('class')",
            "getAttribute.call(node, 'class')",
            "hasAttribute.apply(node, ['class'])",
            "node.matches('[class$=frame]')",
            "node.querySelector('.og-migrated-v1-type-frame')"
        ]
        let destinationObservers = [
            "node.hidden",
            "node?.variant",
            "node['part']",
            "const { hidden, variant, part } = node",
            "node.hasAttribute('hidden')",
            "node.setAttribute('variant', 'preview')",
            "node.removeAttribute('part')",
            "node.toggleAttribute('hidden')",
            "node['toggleAttribute']?.('variant')",
            "const readPart = node.getAttribute; readPart('part')",
            "hasAttribute.call(node, 'hidden')",
            "setAttribute.apply(node, ['variant', 'preview'])",
            "removeAttribute.call(node, 'part')",
            "node.matches('[variant~=preview]')",
            "node.querySelector('[part]')"
        ]
        let wholeDatasetObservers = [
            "const { ogType } = node.dataset",
            "const copy = { ...node.dataset }",
            "const ds = node.dataset; JSON.stringify(ds)",
            "const { dataset } = node; Object.keys(dataset)",
            "const ds = node['dataset']; Reflect.ownKeys(ds)"
        ]
        let wholeStyleObservers = [
            "node.style.cssText",
            "const style = node.style; style.getPropertyValue(name)",
            "const { style } = node; style.setProperty(name, value)",
            "node['style'].removeProperty(name)",
            "node.getAttribute('style')",
            "node.toggleAttribute('style')"
        ]
        let wholeAttributeObservers = [
            "Array.from(node.attributes)",
            "const { attributes } = node; Object.values(attributes)",
            "node.getAttributeNames()",
            "node.hasAttributes()",
            "node.getAttribute(attributeName)",
            "node.setAttribute(dynamicName, value)",
            "node['getAttribute'](attributeName)",
            "getAttribute.call(node, attributeName)",
            "node[attributeName]",
            "Reflect.get(node, propertyName)"
        ]
        let wholeMarkupObservers = [
            "const markup = node.outerHTML",
            "const { innerHTML } = node; render(innerHTML)",
            "node['outerHTML']",
            "serializer.serializeToString(node)",
            "new XMLSerializer().serializeToString(node.cloneNode(true))"
        ]
        let cssOMObservers = [
            "Array.from(document.styleSheets)",
            "Array.from(sheet.cssRules)",
            "const { cssRules } = sheet",
            "Reflect.get(sheet, propertyName)",
            "console.log(rule.cssText)",
            "console.log(styleRule.selectorText)",
            "document.querySelector('style').sheet",
            "const styleElement = document.querySelector('style'); const { sheet } = styleElement",
            "sheet.insertRule(rule)",
            "sheet['insertRule'](rule)",
            "deleteRule.call(sheet, index)",
            "new CSSStyleSheet().replaceSync(source)"
        ]
        let styleTextObservers = [
            "const text = style.textContent",
            "const { innerText } = style",
            "style['textContent']",
            "document.querySelector('style').textContent",
            "style.firstChild.data",
            "style.firstChild.nodeValue += suffix",
            "style['firstChild']['data']",
            "const { data } = style.firstChild",
            "style.textContent += suffix"
        ]
        let previewContextObservers = [
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; const mocks = context.placementMocks; JSON.stringify(mocks)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; const { placementMocks } = context; Object.keys(placementMocks)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; JSON.stringify(context)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; const copy = { ...context }",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; const { fields, ...rest } = context",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; structuredClone(context)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; Object.assign({}, context)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; for (const key in context) consume(key)",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; Reflect.get(context, 'placementMocks')",
            "const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; Reflect.get(context, dynamicKey)"
            ,"const first = __OPENGRAPHITE_PREVIEW_CONTEXT__; const second = first; JSON.stringify(second)",
            "JSON.stringify(globalThis['__OPENGRAPHITE_PREVIEW_CONTEXT__'])"
        ]
        let dynamicSelectorObservers = [
            "node.querySelector(selector)",
            "node.querySelectorAll?.(selector)",
            "node['querySelector'](selector)",
            "node['querySelector']?.(selector)",
            "const select = node.querySelector; select(selector)",
            "querySelector.call(node, selector)",
            "node.matches(dynamicSelector)",
            "node.closest(selectorName)"
        ]
        let attributeNodeObservers = [
            "node.getAttributeNode('class')",
            "node['getAttributeNode']('class')",
            "node['getAttributeNode']?.('class')",
            "const attributeNode = node.getAttributeNode; attributeNode('class')",
            "getAttributeNode.call(node, 'class')",
            "node.getAttributeNodeNS(namespace, name)",
            "node.setAttributeNode(attribute)",
            "node.setAttributeNodeNS(attribute)",
            "node.removeAttributeNode(attribute)"
        ]
        let commentOnly = "/* node.dataset.ogType; const { dataset, style, attributes, innerText, placementMocks } = node; node.style.cssText; node.getAttributeNames(); node.outerHTML; style.textContent; document.styleSheets; __OPENGRAPHITE_PREVIEW_CONTEXT__; node.querySelector(selector); node.getAttributeNode('class'); Reflect.get(node, propertyName); new XMLSerializer().serializeToString(node); node.className; node.hidden; node.setAttribute('variant', 'preview'); --migrated-v1-accent */\nconsole.log('clean')"
        let commentLineTerminators = ["\r", "\u{2028}", "\u{2029}"]
        let commentOnlyByTerminator = commentLineTerminators.map {
            "// node.dataset.ogType; node.className; document.querySelector('style').textContent\($0)console.log('clean')"
        }
        let codeAfterTerminator = commentLineTerminators.map {
            "// clean\($0)node.dataset.ogType; node.className"
        }

        // 検証内容：共通JavaScript inspectorで各sourceを分類する（When）
        let readerResults = readers.map(OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader)
        let classResults = classObservers.map(OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver)
        let observedDestinations = destinationObservers.reduce(into: Set<String>()) { result, source in
            result.formUnion(
                OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(source)
            )
        }
        let wholeDatasetResults = wholeDatasetObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasWholeDatasetObserver
        )
        let wholeStyleResults = wholeStyleObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasWholeStyleObserver
        )
        let wholeAttributeResults = wholeAttributeObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver
        )
        let wholeMarkupResults = wholeMarkupObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasWholeMarkupObserver
        )
        let cssOMResults = cssOMObservers.map {
            OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver($0)
        }
        let styleTextResults = styleTextObservers.map {
            OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver($0)
        }
        let previewContextResults = previewContextObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver
        )
        let dynamicSelectorResults = dynamicSelectorObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasDynamicSelectorObserver
        )
        let attributeNodeResults = attributeNodeObservers.map(
            OpenGraphiteLegacyJavaScriptInspector.hasAttributeNodeObserver
        )

        // 期待値：実code/string observerだけを検出し、comment-only tokenは全分類で無視する（Then）
        #expect(readerResults.allSatisfy { $0 })
        #expect(classResults.allSatisfy { $0 })
        #expect(observedDestinations == Set(["hidden", "variant", "part"]))
        #expect(wholeDatasetResults.allSatisfy { $0 })
        #expect(wholeStyleResults.allSatisfy { $0 })
        #expect(wholeAttributeResults.allSatisfy { $0 })
        #expect(wholeMarkupResults.allSatisfy { $0 })
        #expect(cssOMResults.allSatisfy { $0 })
        #expect(styleTextResults.allSatisfy { $0 })
        #expect(previewContextResults.allSatisfy { $0 })
        #expect(dynamicSelectorResults.allSatisfy { $0 })
        #expect(attributeNodeResults.allSatisfy { $0 })
        #expect(OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(
            #"const variant = mock["host.variant"]"#
        ) == Set(["host.variant"]))
        #expect(OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(
            #"const variant = mock["host." + "variant"]"#
        ) == Set(["host.variant"]))
        #expect(OpenGraphiteLegacyJavaScriptInspector.containsGeneratedCustomPropertyObserver(
            "getComputedStyle(node).getPropertyValue('--migrated-v1-accent')"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver(commentOnly))
        #expect(OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(commentOnly).isEmpty)
        #expect(!OpenGraphiteLegacyJavaScriptInspector.containsGeneratedCustomPropertyObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeDatasetObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeStyleObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeMarkupObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(commentOnly))
        #expect(OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(commentOnly).isEmpty)
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasDynamicSelectorObserver(commentOnly))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasAttributeNodeObserver(commentOnly))
        #expect(commentOnlyByTerminator.allSatisfy {
            !OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader($0)
                && !OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver($0)
                && !OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver($0)
        })
        #expect(codeAfterTerminator.allSatisfy {
            OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader($0)
                && OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver($0)
        })
        #expect(OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader(
            "const pattern = /[//]/; node.dataset.ogType"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(
            "const value = fields[name]; const item = items[index]; Reflect.get(config, key);"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(
            "setAttribute.apply(node, ['variant', 'preview']);"
        ))
        #expect(OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(
            "setAttribute.apply(node, ['variant' + suffix, 'preview']);"
        ))
        #expect(OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(
            "setAttribute.apply(node, ['variant' + suffix, 'preview']);"
        ).isEmpty)
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(
            "const page = workbook.sheet; const value = text.replace(pattern, replacement); root.style.cssText = value;"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
            "runtimeStyleElement.textContent = 'generated';"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(
            "const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {}; const fields = context.fields || {}; return fields[name];"
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(
            "const appConfig = { placementMocks: {} }; return appConfig.placementMocks;"
        ))
        #expect(OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(
            "const owner = document.getElementById('s'); const { sheet } = owner;",
            authoredCSSOwnerIDs: ["s"]
        ))
        #expect(OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
            "document.querySelector('#s').textContent",
            authoredStyleIDs: ["s"]
        ))
        #expect(!OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
            "document.querySelector('h1').textContent",
            authoredStyleIDs: ["s"]
        ))
    }

    /// 論理名（日本語）: HTML whole-observer交差テスト
    /// 概要: attribute/markup全体のruntime observerは実際にHTML sourceが変わるprojectだけをatomic blockingします。
    @Test("migrationはactual HTML mutationとwhole attribute・markup observerだけを交差する")
    func testMigrationIntersectsWholeHTMLObserversWithActualMutation() throws {
        // コンディション：inline/linked observer、embedded style、clean observer、CSS-only migrationの5境界projectを作る（Given）
        let inlineFixture = try AgentInterfaceFixture()
        defer { inlineFixture.cleanUp() }
        let inlineProjectURL = inlineFixture.rootURL.appendingPathComponent("Project.ogp")
        let inlineHTML = #"""
        <main data-og-type="frame">Legacy</main>
        <script>const attrs = Array.from(document.body.attributes); const markup = document.body.outerHTML; console.log(attrs, markup);</script>
        """#
        try inlineFixture.writeRawHTML(inlineHTML)
        try inlineFixture.writeCSSLibrary("")
        try inlineFixture.writeProject(to: inlineProjectURL)
        let inlineEvidence = OpenGraphiteHTMLDocument(html: inlineHTML)
            .migratingLegacyWebContract(path: "index.html")

        let linkedFixture = try AgentInterfaceFixture()
        defer { linkedFixture.cleanUp() }
        let linkedProjectURL = linkedFixture.rootURL.appendingPathComponent("Project.ogp")
        let linkedRuntimeURL = linkedFixture.rootURL.appendingPathComponent("runtime.js")
        let linkedHTML = #"<main data-og-layout="vertical">Legacy</main><script src="runtime.js"></script>"#
        let linkedRuntime = #"const names = node.getAttributeNames(); const { innerHTML } = node; const value = node.getAttribute(attributeName); new XMLSerializer().serializeToString(node.cloneNode(true));"#
        try linkedFixture.writeRawHTML(linkedHTML)
        try linkedFixture.writeCSSLibrary("")
        try linkedRuntime.write(to: linkedRuntimeURL, atomically: true, encoding: .utf8)
        try linkedFixture.writeProject(to: linkedProjectURL)
        let linkedEvidence = OpenGraphiteHTMLDocument(html: linkedHTML)
            .migratingLegacyWebContract(path: "index.html")

        let embeddedFixture = try AgentInterfaceFixture()
        defer { embeddedFixture.cleanUp() }
        let embeddedProjectURL = embeddedFixture.rootURL.appendingPathComponent("Project.ogp")
        let embeddedHTML = #"<style>:root { --og-accent: red; color: var(--og-accent); }</style><main>Embedded style</main><script>document.body.innerHTML;</script>"#
        try embeddedFixture.writeRawHTML(embeddedHTML)
        try embeddedFixture.writeCSSLibrary("")
        try embeddedFixture.writeProject(to: embeddedProjectURL)
        let embeddedEvidence = OpenGraphiteHTMLDocument(html: embeddedHTML)
            .migratingLegacyWebContract(path: "index.html")

        let cleanFixture = try AgentInterfaceFixture()
        defer { cleanFixture.cleanUp() }
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanRuntimeURL = cleanFixture.rootURL.appendingPathComponent("runtime.js")
        let cleanHTML = #"<main data-user-state="ready">Clean</main><script>Array.from(document.body.attributes); document.body.outerHTML;</script><script src="runtime.js"></script>"#
        let cleanRuntime = #"node.getAttributeNames(); const { innerHTML } = node; new XMLSerializer().serializeToString(node);"#
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary("")
        try cleanRuntime.write(to: cleanRuntimeURL, atomically: true, encoding: .utf8)
        try cleanFixture.writeProject(to: cleanProjectURL)

        let cssOnlyFixture = try AgentInterfaceFixture()
        defer { cssOnlyFixture.cleanUp() }
        let cssOnlyProjectURL = cssOnlyFixture.rootURL.appendingPathComponent("Project.ogp")
        let cssOnlyRuntimeURL = cssOnlyFixture.rootURL.appendingPathComponent("runtime.js")
        let cssOnlyHTML = #"<main>CSS only</main><script src="runtime.js"></script>"#
        let cssOnlyCSS = ":root { --og-accent: red; color: var(--og-accent); }\n"
        let cssOnlyRuntime = #"Array.from(node.attributes); const markup = node.innerHTML; node.getAttribute(dynamicName);"#
        try cssOnlyFixture.writeRawHTML(cssOnlyHTML)
        try cssOnlyFixture.writeCSSLibrary(cssOnlyCSS)
        try cssOnlyRuntime.write(to: cssOnlyRuntimeURL, atomically: true, encoding: .utf8)
        try cssOnlyFixture.writeProject(to: cssOnlyProjectURL)

        // 検証内容：5projectをdry-runしてinline/linked scannerとactual mutation evidenceを交差する（When）
        let inlineResult = try inlineFixture.core.migrateProject(projectURL: inlineProjectURL)
        let linkedResult = try linkedFixture.core.migrateProject(projectURL: linkedProjectURL)
        let embeddedResult = try embeddedFixture.core.migrateProject(projectURL: embeddedProjectURL)
        let cleanResult = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)
        let cssOnlyResult = try cssOnlyFixture.core.migrateProject(projectURL: cssOnlyProjectURL)

        // 期待値：HTML変更projectだけをblockingし、clean no-opとexternal CSS-only candidateは許可する（Then）
        #expect(inlineEvidence.hasHTMLSourceMutation)
        #expect(inlineEvidence.hasWholeAttributeRuntimeObserver)
        #expect(inlineEvidence.hasWholeMarkupRuntimeObserver)
        #expect(inlineResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!inlineResult.changed)
        #expect(inlineResult.diffs.isEmpty)
        #expect(inlineResult.proposalReference == nil)
        #expect(try String(contentsOf: inlineFixture.htmlURL, encoding: .utf8) == inlineHTML)
        #expect(linkedEvidence.hasHTMLSourceMutation)
        #expect(!linkedEvidence.hasWholeAttributeRuntimeObserver)
        #expect(!linkedEvidence.hasWholeMarkupRuntimeObserver)
        #expect(linkedResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!linkedResult.changed)
        #expect(linkedResult.diffs.isEmpty)
        #expect(linkedResult.proposalReference == nil)
        #expect(try String(contentsOf: linkedFixture.htmlURL, encoding: .utf8) == linkedHTML)
        #expect(try String(contentsOf: linkedRuntimeURL, encoding: .utf8) == linkedRuntime)
        #expect(embeddedEvidence.hasHTMLSourceMutation)
        #expect(!embeddedEvidence.hasInlineStyleMutation)
        #expect(embeddedEvidence.hasWholeMarkupRuntimeObserver)
        #expect(embeddedResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!embeddedResult.changed)
        #expect(embeddedResult.diffs.isEmpty)
        #expect(embeddedResult.proposalReference == nil)
        #expect(try String(contentsOf: embeddedFixture.htmlURL, encoding: .utf8) == embeddedHTML)
        #expect(cleanResult.diagnostics.isEmpty)
        #expect(!cleanResult.changed)
        #expect(cleanResult.diffs.isEmpty)
        #expect(cleanResult.proposalReference != nil)
        #expect(try String(contentsOf: cleanFixture.htmlURL, encoding: .utf8) == cleanHTML)
        #expect(try String(contentsOf: cleanRuntimeURL, encoding: .utf8) == cleanRuntime)
        #expect(!cssOnlyResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(cssOnlyResult.diagnostics.isEmpty)
        #expect(cssOnlyResult.changed)
        #expect(cssOnlyResult.diffs.map(\.path) == ["OpenGraphite.css"])
        #expect(cssOnlyResult.proposalReference != nil)
        #expect(try String(contentsOf: cssOnlyFixture.htmlURL, encoding: .utf8) == cssOnlyHTML)
        #expect(try cssOnlyFixture.readCSSLibrary() == cssOnlyCSS)
        #expect(try String(contentsOf: cssOnlyRuntimeURL, encoding: .utf8) == cssOnlyRuntime)
    }

    /// 論理名（日本語）: CSS whole-source observer交差テスト
    /// 概要: external/embeddedのactual CSS mutationだけをCSSOMとstyle本文observerへそれぞれ交差します。
    @Test("migrationはactual external・embedded CSS mutationとwhole-source observerだけを交差する")
    func testMigrationIntersectsCSSSourceMutationWithWholeObservers() throws {
        // コンディション：external CSSOM、embedded style text、external text-only、clean no-opの4projectを作る（Given）
        let externalFixture = try AgentInterfaceFixture()
        defer { externalFixture.cleanUp() }
        let externalProjectURL = externalFixture.rootURL.appendingPathComponent("Project.ogp")
        let externalRuntimeURL = externalFixture.rootURL.appendingPathComponent("runtime.js")
        let externalHTML = #"<style id="authored-probe"></style><main>External</main><script src="runtime.js"></script>"#
        let externalCSS = ":root { --og-accent: red; color: var(--og-accent); }\n"
        let externalRuntime = #"const authoredStyle = document.getElementById('authored-probe'); const sheet = authoredStyle.sheet; const { cssRules } = sheet; sheet['insertRule']('.x{}'); deleteRule.call(sheet, 0); console.log(cssRules[0].cssText, cssRules[0].selectorText);"#
        try externalFixture.writeRawHTML(externalHTML)
        try externalFixture.writeCSSLibrary(externalCSS)
        try externalRuntime.write(to: externalRuntimeURL, atomically: true, encoding: .utf8)
        try externalFixture.writeProject(to: externalProjectURL)

        let embeddedFixture = try AgentInterfaceFixture()
        defer { embeddedFixture.cleanUp() }
        let embeddedProjectURL = embeddedFixture.rootURL.appendingPathComponent("Project.ogp")
        let embeddedHTML = #"<style id="s">:root { --og-accent: blue; color: var(--og-accent); }</style><main>Embedded</main><script>const style = document.querySelector('#s'); const { data } = style.firstChild; console.log(document.querySelector('#s').textContent, style.innerText, style['firstChild']['nodeValue'], data); style.textContent += '';</script>"#
        try embeddedFixture.writeRawHTML(embeddedHTML)
        try embeddedFixture.writeCSSLibrary("")
        try embeddedFixture.writeProject(to: embeddedProjectURL)

        let externalTextFixture = try AgentInterfaceFixture()
        defer { externalTextFixture.cleanUp() }
        let externalTextProjectURL = externalTextFixture.rootURL.appendingPathComponent("Project.ogp")
        let externalTextRuntimeURL = externalTextFixture.rootURL.appendingPathComponent("runtime.js")
        let externalTextHTML = #"<main>Canonical safe observers</main><script src="runtime.js"></script>"#
        let contractURL = try #require(OpenGraphiteContract.findContractURL(
            startingAt: URL(fileURLWithPath: #filePath)
        ))
        let repositoryRootURL = contractURL.deletingLastPathComponent()
        let externalTextRuntime = try String(
            contentsOf: repositoryRootURL.appendingPathComponent("public/i18n.js"),
            encoding: .utf8
        ) + "\n" + String(
            contentsOf: repositoryRootURL.appendingPathComponent("public/OpenGraphite.runtime.js"),
            encoding: .utf8
        )
        try externalTextFixture.writeRawHTML(externalTextHTML)
        try externalTextFixture.writeCSSLibrary(externalCSS)
        try externalTextRuntime.write(to: externalTextRuntimeURL, atomically: true, encoding: .utf8)
        try externalTextFixture.writeProject(to: externalTextProjectURL)

        let cleanFixture = try AgentInterfaceFixture()
        defer { cleanFixture.cleanUp() }
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanRuntimeURL = cleanFixture.rootURL.appendingPathComponent("runtime.js")
        let cleanHTML = #"<style>.clean { color: red; }</style><main>Clean</main><script src="runtime.js"></script>"#
        let cleanRuntime = #"const { cssRules } = document.styleSheets[0]; const style = document.querySelector('style'); console.log(cssRules, style.textContent);"#
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary(".clean { display: block; }\n")
        try cleanRuntime.write(to: cleanRuntimeURL, atomically: true, encoding: .utf8)
        try cleanFixture.writeProject(to: cleanProjectURL)

        // 検証内容：4projectをdry-runする（When）
        let external = try externalFixture.core.migrateProject(projectURL: externalProjectURL)
        let embedded = try embeddedFixture.core.migrateProject(projectURL: embeddedProjectURL)
        let externalText = try externalTextFixture.core.migrateProject(projectURL: externalTextProjectURL)
        let clean = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)
        let externalTextApplied = try externalTextFixture.core.migrateProject(
            projectURL: externalTextProjectURL,
            proposalReference: try #require(externalText.proposalReference),
            apply: true
        )
        let externalTextRepeated = try externalTextFixture.core.migrateProject(projectURL: externalTextProjectURL)

        // 期待値：source種別に対応するwhole observerだけをblockし、CSS非変更とexternal text-onlyを許可する（Then）
        #expect(external.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!external.changed)
        #expect(external.diffs.isEmpty)
        #expect(external.proposalReference == nil)
        #expect(try String(contentsOf: externalFixture.htmlURL, encoding: .utf8) == externalHTML)
        #expect(try externalFixture.readCSSLibrary() == externalCSS)
        #expect(try String(contentsOf: externalRuntimeURL, encoding: .utf8) == externalRuntime)
        #expect(embedded.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!embedded.changed)
        #expect(embedded.diffs.isEmpty)
        #expect(embedded.proposalReference == nil)
        #expect(try String(contentsOf: embeddedFixture.htmlURL, encoding: .utf8) == embeddedHTML)
        #expect(externalText.diagnostics.isEmpty)
        #expect(externalText.changed)
        #expect(externalText.diffs.map(\.path) == ["OpenGraphite.css"])
        #expect(externalTextApplied.applied)
        #expect(externalTextApplied.diagnostics.isEmpty)
        #expect(!externalTextRepeated.changed)
        #expect(externalTextRepeated.diffs.isEmpty)
        #expect(try String(contentsOf: externalTextRuntimeURL, encoding: .utf8) == externalTextRuntime)
        #expect(clean.diagnostics.isEmpty)
        #expect(!clean.changed)
        #expect(clean.diffs.isEmpty)
        #expect(clean.proposalReference != nil)
        #expect(try String(contentsOf: cleanFixture.htmlURL, encoding: .utf8) == cleanHTML)
        #expect(try String(contentsOf: cleanRuntimeURL, encoding: .utf8) == cleanRuntime)
    }

    /// 論理名（日本語）: Manifest preview observer交差テスト
    /// 概要: actual preview migrationをwhole placement contextと新規生成host fieldのexact observerだけへ交差します。
    @Test("migrationはactual manifest preview mutationとwhole・generated host observerだけを交差する")
    func testMigrationIntersectsManifestMutationWithPreviewObservers() throws {
        // コンディション：generated exact、existing exact、whole object、fields-only、clean no-opの5projectを作る（Given）
        let contractURL = try #require(OpenGraphiteContract.findContractURL(
            startingAt: URL(fileURLWithPath: #filePath)
        ))
        let publicI18nRuntime = try String(
            contentsOf: contractURL.deletingLastPathComponent().appendingPathComponent("public/i18n.js"),
            encoding: .utf8
        )
        func prepare(
            fixture: AgentInterfaceFixture,
            previewObject: String?,
            runtime: String
        ) throws -> (projectURL: URL, manifest: String, runtimeURL: URL) {
            let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
            let runtimeURL = fixture.rootURL.appendingPathComponent("runtime.js")
            try fixture.writeRawHTML(#"<main>Preview</main><script src="runtime.js"></script>"#)
            try fixture.writeCSSLibrary("")
            try fixture.writeProject(to: projectURL)
            var manifest = try String(contentsOf: projectURL, encoding: .utf8)
            if let previewObject {
                manifest = manifest.replacingOccurrences(
                    of: """
                                "height": 1200
                    """,
                    with: """
                                "height": 1200,
                                "previewContext": { "placementMocks": {
                                  "fixture": { \(previewObject) }
                                } }
                    """
                )
                try manifest.write(to: projectURL, atomically: true, encoding: .utf8)
            }
            try runtime.write(to: runtimeURL, atomically: true, encoding: .utf8)
            return (projectURL, manifest, runtimeURL)
        }

        let generatedFixture = try AgentInterfaceFixture()
        let existingFixture = try AgentInterfaceFixture()
        let wholeFixture = try AgentInterfaceFixture()
        let fieldsFixture = try AgentInterfaceFixture()
        let cleanFixture = try AgentInterfaceFixture()
        defer {
            generatedFixture.cleanUp(); existingFixture.cleanUp(); wholeFixture.cleanUp()
            fieldsFixture.cleanUp(); cleanFixture.cleanUp()
        }
        let generated = try prepare(
            fixture: generatedFixture,
            previewObject: #""codeViewerMode": "preview""#,
            runtime: #"console.log(mock["host." + "variant"]);"#
        )
        let existing = try prepare(
            fixture: existingFixture,
            previewObject: #""codeViewerMode": "preview", "host.variant": "preview""#,
            runtime: #"console.log(mock["host.variant"]);"#
        )
        let whole = try prepare(
            fixture: wholeFixture,
            previewObject: #""codeViewerMode": "preview", "host.variant": "preview""#,
            runtime: #"JSON.stringify(globalThis['__OPENGRAPHITE_PREVIEW_CONTEXT__']);"#
        )
        let fields = try prepare(
            fixture: fieldsFixture,
            previewObject: #""codeViewerMode": "preview""#,
            runtime: publicI18nRuntime
                + "\nconst appConfig = { placementMocks: {} }; console.log(appConfig.placementMocks);"
        )
        let clean = try prepare(
            fixture: cleanFixture,
            previewObject: nil,
            runtime: #"const context = __OPENGRAPHITE_PREVIEW_CONTEXT__; const { placementMocks } = context; console.log(mock["host.variant"], placementMocks);"#
        )

        // 検証内容：4projectをdry-runする（When）
        let generatedResult = try generatedFixture.core.migrateProject(projectURL: generated.projectURL)
        let existingResult = try existingFixture.core.migrateProject(projectURL: existing.projectURL)
        let wholeResult = try wholeFixture.core.migrateProject(projectURL: whole.projectURL)
        let fieldsResult = try fieldsFixture.core.migrateProject(projectURL: fields.projectURL)
        let cleanResult = try cleanFixture.core.migrateProject(projectURL: clean.projectURL)
        let existingApplied = try existingFixture.core.migrateProject(
            projectURL: existing.projectURL,
            proposalReference: try #require(existingResult.proposalReference),
            apply: true
        )
        let existingRepeated = try existingFixture.core.migrateProject(projectURL: existing.projectURL)
        let fieldsApplied = try fieldsFixture.core.migrateProject(
            projectURL: fields.projectURL,
            proposalReference: try #require(fieldsResult.proposalReference),
            apply: true
        )
        let fieldsRepeated = try fieldsFixture.core.migrateProject(projectURL: fields.projectURL)

        // 期待値：generated exact/whole observerだけをblockし、同値existing exact migrationとclean no-opを許可する（Then）
        #expect(generatedResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!generatedResult.changed)
        #expect(generatedResult.diffs.isEmpty)
        #expect(generatedResult.proposalReference == nil)
        #expect(try String(contentsOf: generated.projectURL, encoding: .utf8) == generated.manifest)
        #expect(wholeResult.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!wholeResult.changed)
        #expect(wholeResult.diffs.isEmpty)
        #expect(wholeResult.proposalReference == nil)
        #expect(try String(contentsOf: whole.projectURL, encoding: .utf8) == whole.manifest)
        #expect(existingResult.diagnostics.isEmpty)
        #expect(existingResult.changed)
        #expect(existingResult.diffs.map(\.path) == ["Project.ogp"])
        #expect(existingResult.proposalReference != nil)
        #expect(existingApplied.applied)
        #expect(existingApplied.diagnostics.isEmpty)
        #expect(!existingRepeated.changed)
        #expect(existingRepeated.diffs.isEmpty)
        #expect(fieldsResult.diagnostics.isEmpty)
        #expect(fieldsResult.changed)
        #expect(fieldsResult.diffs.map(\.path) == ["Project.ogp"])
        #expect(fieldsApplied.applied)
        #expect(fieldsApplied.diagnostics.isEmpty)
        #expect(!fieldsRepeated.changed)
        #expect(fieldsRepeated.diffs.isEmpty)
        #expect(cleanResult.diagnostics.isEmpty)
        #expect(!cleanResult.changed)
        #expect(cleanResult.diffs.isEmpty)
        #expect(cleanResult.proposalReference != nil)
    }

    /// 論理名（日本語）: Dynamic DOM observer交差テスト
    /// 概要: dynamic selector・AttributeNode・computed/Reflect observerをselector-affecting HTML mutationだけへ交差します。
    @Test("migrationはactual selector-affecting HTML mutationとdynamic DOM observerだけを交差する")
    func testMigrationIntersectsDynamicDOMObserversWithAttributeMutation() throws {
        // コンディション：legacy attribute、inline style、embedded style、unrelated computed、clean no-opの5projectを作る（Given）
        let attributeFixture = try AgentInterfaceFixture()
        defer { attributeFixture.cleanUp() }
        let attributeProjectURL = attributeFixture.rootURL.appendingPathComponent("Project.ogp")
        let attributeHTML = #"<main data-og-type="frame">Legacy</main><script>node['querySelector']?.(selector); const select = node.querySelector; select(selector); querySelector.call(node, selector); node['getAttribute'](attributeName); node['getAttributeNode']?.('class'); const attributeNode = node.getAttributeNode; attributeNode('class'); getAttributeNode.call(node, 'class'); Reflect.get(node, propertyName); node[attributeName];</script>"#
        try attributeFixture.writeRawHTML(attributeHTML)
        try attributeFixture.writeCSSLibrary("")
        try attributeFixture.writeProject(to: attributeProjectURL)

        let inlineStyleFixture = try AgentInterfaceFixture()
        defer { inlineStyleFixture.cleanUp() }
        let inlineStyleProjectURL = inlineStyleFixture.rootURL.appendingPathComponent("Project.ogp")
        let inlineStyleHTML = #"<main style=--og-edit-width:320px data-next=keep>Inline</main><script>node.matches(dynamicSelector);</script>"#
        try inlineStyleFixture.writeRawHTML(inlineStyleHTML)
        try inlineStyleFixture.writeCSSLibrary("")
        try inlineStyleFixture.writeProject(to: inlineStyleProjectURL)

        let embeddedFixture = try AgentInterfaceFixture()
        defer { embeddedFixture.cleanUp() }
        let embeddedProjectURL = embeddedFixture.rootURL.appendingPathComponent("Project.ogp")
        let embeddedHTML = #"<style>:root { --og-accent: red; color: var(--og-accent); }</style><main>Embedded</main><script>node.closest(selectorName); node.getAttributeNode('class');</script>"#
        try embeddedFixture.writeRawHTML(embeddedHTML)
        try embeddedFixture.writeCSSLibrary("")
        try embeddedFixture.writeProject(to: embeddedProjectURL)

        let unrelatedFixture = try AgentInterfaceFixture()
        defer { unrelatedFixture.cleanUp() }
        let unrelatedProjectURL = unrelatedFixture.rootURL.appendingPathComponent("Project.ogp")
        let unrelatedHTML = #"<main data-og-type="frame">Maps</main><script>const translated = fields[name]; const selected = items[index]; const configured = Reflect.get(config, key); console.log(translated, selected, configured);</script>"#
        try unrelatedFixture.writeRawHTML(unrelatedHTML)
        try unrelatedFixture.writeCSSLibrary("")
        try unrelatedFixture.writeProject(to: unrelatedProjectURL)

        let cleanFixture = try AgentInterfaceFixture()
        defer { cleanFixture.cleanUp() }
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanHTML = #"<main>Clean</main><script>node.querySelectorAll(selector); node.setAttributeNode(attribute); Reflect.ownKeys(node); node[propertyName];</script>"#
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary("")
        try cleanFixture.writeProject(to: cleanProjectURL)

        // 検証内容：4projectをdry-runする（When）
        let attribute = try attributeFixture.core.migrateProject(projectURL: attributeProjectURL)
        let inlineStyle = try inlineStyleFixture.core.migrateProject(projectURL: inlineStyleProjectURL)
        let embedded = try embeddedFixture.core.migrateProject(projectURL: embeddedProjectURL)
        let unrelated = try unrelatedFixture.core.migrateProject(projectURL: unrelatedProjectURL)
        let clean = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)
        let embeddedApplied = try embeddedFixture.core.migrateProject(
            projectURL: embeddedProjectURL,
            proposalReference: try #require(embedded.proposalReference),
            apply: true
        )
        let embeddedRepeated = try embeddedFixture.core.migrateProject(projectURL: embeddedProjectURL)
        let unrelatedApplied = try unrelatedFixture.core.migrateProject(
            projectURL: unrelatedProjectURL,
            proposalReference: try #require(unrelated.proposalReference),
            apply: true
        )
        let unrelatedRepeated = try unrelatedFixture.core.migrateProject(projectURL: unrelatedProjectURL)

        // 期待値：attribute/class/style属性変更だけをblockし、embedded text-only mutationとclean no-opは許可する（Then）
        #expect(attribute.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!attribute.changed)
        #expect(attribute.diffs.isEmpty)
        #expect(attribute.proposalReference == nil)
        #expect(try String(contentsOf: attributeFixture.htmlURL, encoding: .utf8) == attributeHTML)
        #expect(inlineStyle.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!inlineStyle.changed)
        #expect(inlineStyle.diffs.isEmpty)
        #expect(inlineStyle.proposalReference == nil)
        #expect(try String(contentsOf: inlineStyleFixture.htmlURL, encoding: .utf8) == inlineStyleHTML)
        #expect(embedded.diagnostics.isEmpty)
        #expect(embedded.changed)
        #expect(embedded.diffs.map(\.path) == ["index.html"])
        #expect(embedded.proposalReference != nil)
        #expect(embeddedApplied.applied)
        #expect(embeddedApplied.diagnostics.isEmpty)
        #expect(!embeddedRepeated.changed)
        #expect(embeddedRepeated.diffs.isEmpty)
        #expect(unrelated.diagnostics.isEmpty)
        #expect(unrelated.changed)
        #expect(unrelated.diffs.map(\.path) == ["index.html"])
        #expect(unrelatedApplied.applied)
        #expect(unrelatedApplied.diagnostics.isEmpty)
        #expect(!unrelatedRepeated.changed)
        #expect(unrelatedRepeated.diffs.isEmpty)
        #expect(clean.diagnostics.isEmpty)
        #expect(!clean.changed)
        #expect(clean.diffs.isEmpty)
        #expect(clean.proposalReference != nil)
    }

    /// 論理名（日本語）: Migration HTML MIME境界テスト
    /// 概要: CSS/JavaScriptとして実行されるtypeだけをmigration source・dependency closure・runtime scanへ含めます。
    @Test("migrationはstyle・link・scriptのactual MIME typeだけをsourceとして扱う")
    func testMigrationUsesActualHTMLMIMEKinds() throws {
        // コンディション：type essence/keyword/data blockを網羅するdirect documentと4projectを作る（Given）
        let formFeed = "\u{000C}"
        let directHTML = #"""
        <style id="style-default"></style><style id="style-empty" type=""></style><style id="style-css" type="TeXt/CsS"></style><style id="style-numeric" type="text&#47css"></style><style id="style-space" type=" text/css "></style><style id="style-whitespace" type=" "></style><style id="style-param" type="text/css; charset=utf-8"></style><style id="style-nbsp" type=" text/css "></style><style id="style-unquoted-nbsp" type=text/css  ></style><style id="style-less" type="text/less"></style><style id="style-invalid" type=";charset=utf-8"></style>
        <link id="link-default" rel="stylesheet"><link id="link-empty" rel="stylesheet" type=""><link id="link-css" rel="stylesheet" type=" text/css; charset=utf-8 "><link id="link-numeric" rel="stylesheet" type="text&#47css"><link id="link-space" rel="stylesheet" type=" "><link id="link-nbsp" rel="stylesheet" type=" "><link id="link-ff" rel="stylesheet" type="\#(formFeed)text/css\#(formFeed)"><link id="link-unquoted-nbsp" rel="stylesheet" type=text/css  href="unused.css"><link id="link-rel-nbsp" rel="stylesheet alternate" type="text/css"><link id="link-less" rel="stylesheet" type="text/less"><link id="link-invalid" rel="stylesheet" type=";charset=utf-8">
        <script id="classic"></script><script id="empty-type" type=""></script><script id="module" type="MoDuLe"></script><script id="module-space" type=" module "></script><script id="bad-module" type="module;foo"></script>
        <script id="js-numeric" type="text&#47javascript"></script><script id="js-hex-numeric" type="text&#x2fjavascript"></script><script id="js-param" type="text/javascript; charset=utf-8"></script><script id="js-space" type=" text/javascript "></script><script id="js-nbsp" type=" text/javascript "></script><script id="js-unquoted-nbsp" type=text/javascript  src="unused.js"></script><script id="legacy-js" type="application/x-ecmascript"></script>
        <script id="app-js" type="application/javascript"></script><script id="text-ecma" type="text/ecmascript"></script><script id="app-ecma" type="application/ecmascript"></script>
        <script id="x-js" type="text/x-javascript"></script><script id="x-ecma" type="text/x-ecmascript"></script><script id="app-x-js" type="application/x-javascript"></script>
        <script id="jscript" type="text/jscript"></script><script id="livescript" type="text/livescript"></script>
        <script id="js10" type="text/javascript1.0"></script><script id="js11" type="text/javascript1.1"></script><script id="js12" type="text/javascript1.2"></script>
        <script id="js13" type="text/javascript1.3"></script><script id="js14" type="text/javascript1.4"></script><script id="js15" type="text/javascript1.5"></script>
        <script id="js-period" type="text/javascript1&period;0"></script><script id="js-unknown-entity" type="text/javascript1&unknown;0"></script>
        <script id="language-empty" language=""></script><script id="language-js" language="javascript"></script><script id="language-ecma" language="EcMaScRiPt"></script><script id="language-vb" language="vbscript"></script><script id="language-json" language="json"></script><script id="language-space" language=" javascript "></script><script id="language-nbsp" language=" javascript "></script>
        <script id="type-overrides-language" type="application/json" language="javascript"></script><script id="type-js-overrides-language" type="text/javascript" language="vbscript"></script>
        <script id="json" type="application/json"></script><script id="jsonld" type="application/ld+json"></script><script id="invalid-type" type=";charset=utf-8"></script>
        <script id="importmap" type="importmap"></script><script id="speculation" type="speculationrules"></script><script id="unknown" type="application/x-data"></script>
        """#
        let directDocument = OpenGraphiteHTMLDocument(html: directHTML)
        let directTags = Dictionary(uniqueKeysWithValues: directDocument.parsedTags().compactMap { tag in
            tag.attributeValue(named: "id").map { ($0, tag) }
        })

        let opaqueFixture = try AgentInterfaceFixture()
        defer { opaqueFixture.cleanUp() }
        let opaqueProjectURL = opaqueFixture.rootURL.appendingPathComponent("Project.ogp")
        let themeURL = opaqueFixture.rootURL.appendingPathComponent("theme")
        let numericThemeURL = opaqueFixture.rootURL.appendingPathComponent("numeric-theme")
        let opaqueHTML = #"""
        <link rel="stylesheet" type="text/less" href="missing.less"><link rel="stylesheet" type=" TEXT/CSS ; charset=utf-8" href="theme"><link rel="stylesheet" type="text&#47css" href="numeric-theme"><link rel="stylesheet" type="" href="missing-empty.css"><link rel="stylesheet" type=" " href="missing-space.css"><link rel="stylesheet" type=" " href="missing-nbsp.css"><link rel="stylesheet" type=text/css  href="missing-unquoted-nbsp.css">
        <style type="text/less">@import "missing.less"; :root { --og-accent: red; }</style>
        <style type="text/css; charset=utf-8">@import "missing-param.css"; :root { --og-page-background: pink; }</style>
        <style type=" text/css ">@import "missing-space.css"; :root { --og-page-background: orange; }</style>
        <style type=text/css  >@import "missing-unquoted-nbsp.css"; :root { --og-page-background: purple; }</style>
        <style type="text&#47css">:root { --og-muted-color: black; color: var(--og-muted-color); }</style>
        <style type="TeXt/CsS">:root { --og-muted-color: gray; color: var(--og-muted-color); }</style>
        <main data-og-type="frame">Legacy</main>
        <script type="application/json" src="missing-json">{"reader":"data-og-type --og-accent"}</script>
        <script type="application/ld+json">{"reader":"data-og-layout"}</script><script type="importmap">{"imports":{"x":"data-og-hidden"}}</script>
        <script type="speculationrules">{"prefetch":[{"source":"data-og-part"}]}</script><script type="module;foo" src="missing-bad-module">data-og-type</script>
        <script type="application/x-data" src="missing-data">--og-accent</script><script type="text/javascript; charset=utf-8" src="missing-param-js">data-og-type</script>
        <script type=" text/javascript " src="missing-space-js">data-og-type</script><script type=" text/javascript " src="missing-nbsp-js">data-og-type</script><script type=text/javascript  src="missing-unquoted-nbsp-js">data-og-type</script>
        <script language="vbscript" src="missing-vb">data-og-type</script><script type="application/json" language="javascript" src="missing-language-override">data-og-type</script>
        """#
        let themeCSS = ":root { --og-accent: blue; color: var(--og-accent); }\n"
        let numericThemeCSS = ":root { --og-muted-color: silver; color: var(--og-muted-color); }\n"
        try opaqueFixture.writeRawHTML(opaqueHTML)
        try opaqueFixture.writeCSSLibrary("")
        try themeCSS.write(to: themeURL, atomically: true, encoding: .utf8)
        try numericThemeCSS.write(to: numericThemeURL, atomically: true, encoding: .utf8)
        try opaqueFixture.writeProject(to: opaqueProjectURL)

        let cleanFixture = try AgentInterfaceFixture()
        defer { cleanFixture.cleanUp() }
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanHTML = #"<main>Clean</main><style type="text/less">@import "missing.less"; --og-accent</style><style type="text/css; charset=utf-8">@import "missing-param.css"; --og-text-color</style><style type=" text/css ">@import "missing-space.css"; --og-accent</style><script type="application/json">{"legacy":"data-og-type"}</script><script type="importmap">{"imports":{"x":"--og-accent"}}</script>"#
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary("")
        try cleanFixture.writeProject(to: cleanProjectURL)

        let classicFixture = try AgentInterfaceFixture()
        defer { classicFixture.cleanUp() }
        let classicProjectURL = classicFixture.rootURL.appendingPathComponent("Project.ogp")
        let classicHTML = #"<main data-og-type="frame">Classic</main><script type="text&#47javascript">node.dataset.ogType;</script><script language="javascript">console.log('classic');</script>"#
        try classicFixture.writeRawHTML(classicHTML)
        try classicFixture.writeCSSLibrary("")
        try classicFixture.writeProject(to: classicProjectURL)

        let moduleFixture = try AgentInterfaceFixture()
        defer { moduleFixture.cleanUp() }
        let moduleProjectURL = moduleFixture.rootURL.appendingPathComponent("Project.ogp")
        let moduleHTML = #"<main data-og-type="frame">Module</main><script type="module">node.dataset.ogType;</script>"#
        try moduleFixture.writeRawHTML(moduleHTML)
        try moduleFixture.writeCSSLibrary("")
        try moduleFixture.writeProject(to: moduleProjectURL)

        let periodFixture = try AgentInterfaceFixture()
        defer { periodFixture.cleanUp() }
        let periodProjectURL = periodFixture.rootURL.appendingPathComponent("Project.ogp")
        let periodRuntimeURL = periodFixture.rootURL.appendingPathComponent("runtime-period.js")
        let periodHTML = #"<main data-og-type="frame">Period</main><script type="text/javascript1&period;0" src="runtime-period.js"></script>"#
        try periodFixture.writeRawHTML(periodHTML)
        try periodFixture.writeCSSLibrary("")
        try "node.dataset.ogType;".write(to: periodRuntimeURL, atomically: true, encoding: .utf8)
        try periodFixture.writeProject(to: periodProjectURL)

        let unresolvedFixture = try AgentInterfaceFixture()
        defer { unresolvedFixture.cleanUp() }
        let unresolvedProjectURL = unresolvedFixture.rootURL.appendingPathComponent("Project.ogp")
        let unresolvedHTML = #"<link rel="stylesheet" href="theme&fjlig;.css"><main data-og-type="frame">Unknown entity</main><script src="runtime&fjlig;.js"></script><script type="text&fjlig;/javascript">node.dataset.ogType</script><script language="java&fjlig;script">node.dataset.ogType</script>"#
        try unresolvedFixture.writeRawHTML(unresolvedHTML)
        try unresolvedFixture.writeCSSLibrary("")
        try unresolvedFixture.writeProject(to: unresolvedProjectURL)

        // 検証内容：direct kind判定と4project dry-runを実行する（When）
        let opaque = try opaqueFixture.core.migrateProject(projectURL: opaqueProjectURL)
        let clean = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)
        let classic = try classicFixture.core.migrateProject(projectURL: classicProjectURL)
        let module = try moduleFixture.core.migrateProject(projectURL: moduleProjectURL)
        let period = try periodFixture.core.migrateProject(projectURL: periodProjectURL)
        let unresolved = try unresolvedFixture.core.migrateProject(projectURL: unresolvedProjectURL)
        let opaqueApplied = try opaqueFixture.core.migrateProject(
            projectURL: opaqueProjectURL,
            proposalReference: try #require(opaque.proposalReference),
            apply: true
        )
        let opaqueRepeated = try opaqueFixture.core.migrateProject(projectURL: opaqueProjectURL)

        // 期待値：CSS/classic/moduleだけを処理し、non-CSS/JSON/importmap/speculationrules/unknownはopaqueに保つ（Then）
        #expect(directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-default"])))
        #expect(directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-empty"])))
        #expect(directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-css"])))
        #expect(directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-numeric"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-space"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-whitespace"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-param"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-nbsp"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-unquoted-nbsp"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-less"])))
        #expect(!directDocument.isCSSEmbeddedStyleTag(try #require(directTags["style-invalid"])))
        #expect(directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-default"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-empty"])))
        #expect(directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-css"])))
        #expect(directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-numeric"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-space"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-nbsp"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-ff"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-unquoted-nbsp"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-rel-nbsp"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-less"])))
        #expect(!directDocument.isCSSStylesheetLinkTag(try #require(directTags["link-invalid"])))
        for id in [
            "classic", "empty-type", "module", "js-numeric", "js-hex-numeric", "language-empty", "language-js", "language-ecma",
            "type-js-overrides-language", "legacy-js", "app-js", "text-ecma", "app-ecma",
            "x-js", "x-ecma", "app-x-js", "jscript", "livescript",
            "js10", "js11", "js12", "js13", "js14", "js15", "js-period"
        ] {
            #expect(directDocument.isExecutableScriptTag(try #require(directTags[id])))
        }
        for id in [
            "module-space", "bad-module", "js-param", "js-space", "js-nbsp", "js-unquoted-nbsp", "language-vb",
            "language-json", "language-space", "language-nbsp", "type-overrides-language",
            "json", "jsonld", "invalid-type", "importmap", "speculation", "unknown", "js-unknown-entity"
        ] {
            #expect(!directDocument.isExecutableScriptTag(try #require(directTags[id])))
        }
        #expect(opaque.diagnostics.isEmpty)
        #expect(opaque.changed)
        #expect(opaque.diffs.map(\.path) == ["index.html", "numeric-theme", "theme"])
        #expect(opaque.proposalReference != nil)
        let opaqueDiff = try #require(opaque.diffs.first { $0.path == "index.html" })
        #expect(opaqueDiff.unifiedDiff.contains(#"<style type="text/less">@import "missing.less"; :root { --og-accent: red; }</style>"#))
        #expect(opaqueDiff.unifiedDiff.contains(#"<style type="text/css; charset=utf-8">@import "missing-param.css"; :root { --og-page-background: pink; }</style>"#))
        #expect(opaqueDiff.unifiedDiff.contains(#"<style type=" text/css ">@import "missing-space.css"; :root { --og-page-background: orange; }</style>"#))
        #expect(opaqueDiff.unifiedDiff.contains(#"<style type=text/css  >@import "missing-unquoted-nbsp.css"; :root { --og-page-background: purple; }</style>"#))
        #expect(!opaque.diagnostics.contains { $0.code == "migration-registered-resource-missing" })
        #expect(opaqueApplied.applied)
        #expect(opaqueApplied.diagnostics.isEmpty)
        #expect(!opaqueRepeated.changed)
        #expect(opaqueRepeated.diffs.isEmpty)
        #expect(clean.diagnostics.isEmpty)
        #expect(!clean.changed)
        #expect(clean.diffs.isEmpty)
        #expect(clean.proposalReference != nil)
        #expect(classic.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!classic.changed)
        #expect(classic.diffs.isEmpty)
        #expect(classic.proposalReference == nil)
        #expect(try String(contentsOf: classicFixture.htmlURL, encoding: .utf8) == classicHTML)
        #expect(module.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!module.changed)
        #expect(module.diffs.isEmpty)
        #expect(module.proposalReference == nil)
        #expect(try String(contentsOf: moduleFixture.htmlURL, encoding: .utf8) == moduleHTML)
        #expect(period.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!period.changed)
        #expect(period.diffs.isEmpty)
        #expect(period.proposalReference == nil)
        #expect(try String(contentsOf: periodFixture.htmlURL, encoding: .utf8) == periodHTML)
        #expect(unresolved.diagnostics.contains { $0.code == "unsupported-legacy-external-stylesheet" })
        #expect(unresolved.diagnostics.contains { $0.code == "unsupported-legacy-external-runtime" })
        #expect(!unresolved.changed)
        #expect(unresolved.diffs.isEmpty)
        #expect(unresolved.proposalReference == nil)
        #expect(try String(contentsOf: unresolvedFixture.htmlURL, encoding: .utf8) == unresolvedHTML)
    }

    /// 論理名（日本語）: Runtime whole-column observer交差テスト
    /// 概要: 実際に削除・生成するmigration evidenceがあるprojectだけdataset/style列observerをatomic blockingします。
    @Test("migrationは実変更evidenceとruntime whole-column observerだけを交差する")
    func testMigrationIntersectsWholeColumnObserversWithGeneratedEvidence() throws {
        // コンディション：legacy attr/custom propertyとinline/linked whole-column observerを持つprojectを作る（Given）
        let legacyFixture = try AgentInterfaceFixture()
        defer { legacyFixture.cleanUp() }
        let legacyProjectURL = legacyFixture.rootURL.appendingPathComponent("Project.ogp")
        let legacyRuntimeURL = legacyFixture.rootURL.appendingPathComponent("runtime.js")
        let legacyHTML = #"""
        <main data-og-type="frame" style="--og-edit-width: 320px">Legacy</main>
        <script>const { ogType } = document.body.dataset; const inlineStyle = document.body.style; console.log(inlineStyle.cssText, document.body.getAttribute('style'));</script>
        <script src="runtime.js"></script>
        """#
        let legacyCSS = #"""
        [style*="--brand"] { outline: 0; }
        .reader { content: attr(style); }
        """#
        let legacyRuntime = #"const ds = document.body.dataset; JSON.stringify(ds); const style = document.body.style; console.log(style.cssText, document.body.getAttribute('style'));"#
        try legacyFixture.writeRawHTML(legacyHTML)
        try legacyFixture.writeCSSLibrary(legacyCSS)
        try legacyRuntime.write(to: legacyRuntimeURL, atomically: true, encoding: .utf8)
        try legacyFixture.writeProject(to: legacyProjectURL)
        let htmlEvidence = OpenGraphiteHTMLDocument(html: legacyHTML)
            .migratingLegacyWebContract(path: "index.html")

        // 検証内容：legacy projectをdry-runし、同じobserverを持つclean projectも別途dry-runする（When）
        let blocked = try legacyFixture.core.migrateProject(projectURL: legacyProjectURL)
        let cleanFixture = try AgentInterfaceFixture()
        defer { cleanFixture.cleanUp() }
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanRuntimeURL = cleanFixture.rootURL.appendingPathComponent("runtime.js")
        let cleanHTML = #"""
        <main data-user-state="ready" style="--brand: red">Clean</main>
        <script>const { dataset, style } = document.body; JSON.stringify(dataset); style.cssText;</script>
        <script src="runtime.js"></script>
        """#
        let cleanCSS = #"[style*="--brand"] { outline: 0; } .reader { content: attr(style); }"#
        let cleanRuntime = #"const ds = document.body.dataset; Object.keys(ds); const style = document.body.style; style.setProperty(name, value);"#
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary(cleanCSS)
        try cleanRuntime.write(to: cleanRuntimeURL, atomically: true, encoding: .utf8)
        try cleanFixture.writeProject(to: cleanProjectURL)
        let cleanEvidence = OpenGraphiteHTMLDocument(html: cleanHTML)
            .migratingLegacyWebContract(path: "index.html")
        let clean = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)

        // 期待値：実変更集合と交差するlegacy projectだけを診断し、clean observer projectはbytes不変のno-opにする（Then）
        #expect(htmlEvidence.removedLegacyDatasetAttributeNames == Set(["data-og-type"]))
        #expect(htmlEvidence.hasWholeDatasetRuntimeObserver)
        #expect(htmlEvidence.hasWholeStyleRuntimeObserver)
        #expect(htmlEvidence.hasInlineStyleMutation)
        #expect(htmlEvidence.hasHTMLSourceMutation)
        #expect(htmlEvidence.generatedCustomPropertyNames.isEmpty)
        #expect(htmlEvidence.source != legacyHTML)
        #expect(blocked.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(blocked.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!blocked.changed)
        #expect(blocked.diffs.isEmpty)
        #expect(blocked.proposalReference == nil)
        #expect(try String(contentsOf: legacyFixture.htmlURL, encoding: .utf8) == legacyHTML)
        #expect(try legacyFixture.readCSSLibrary() == legacyCSS)
        #expect(try String(contentsOf: legacyRuntimeURL, encoding: .utf8) == legacyRuntime)
        #expect(clean.diagnostics.isEmpty)
        #expect(!cleanEvidence.hasInlineStyleMutation)
        #expect(!clean.changed)
        #expect(clean.diffs.isEmpty)
        #expect(clean.proposalReference != nil)
        #expect(try String(contentsOf: cleanFixture.htmlURL, encoding: .utf8) == cleanHTML)
        #expect(try cleanFixture.readCSSLibrary() == cleanCSS)
        #expect(try String(contentsOf: cleanRuntimeURL, encoding: .utf8) == cleanRuntime)
    }

    /// 論理名（日本語）: Migration observer project-wide collisionテスト
    /// 概要: CSS/inline/linked runtime observerとgenerated HTML/CSS destinationの交差をatomic no-writeへ固定します。
    @Test("migrationはdestination observerとlegacy readerをproject全体でblockingする")
    func testMigrationBlocksProjectWideDestinationObserversAndLegacyReaders() throws {
        // コンディション：class/standard attr/style observer、attr() reader、inline/linked dataset readerを持つlegacy projectを作る（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let runtimeURL = fixture.rootURL.appendingPathComponent("runtime.js")
        let html = #"""
        <main data-og-type="frame" data-og-hidden="true" data-og-variant="preview" data-og-part="body" style="--og-accent: red">Legacy</main>
        <script>const layout = document.body?.dataset?.ogLayout; const { className, classList, hidden, variant, part } = document.body; document.body['className']; console.log(className, classList, hidden, variant, part);</script>
        <script src="runtime.js"></script>
        """#
        let css = #"""
        .card:is([class$="frame"], .featured) { color: red; }
        [hidden], [variant~="preview"], [part~="body"] { outline: 0; }
        [style*="--migrated-v1-accent"] { color: blue; }
        [style*="--og-accent"] { color: green; }
        .reader { content: attr(data-og-type); }
        [|class], [*|hidden], [ns|variant], [|part] { outline-color: transparent; }
        """#
        let runtime = #"document.body.dataset["ogHidden"]; document.body['toggleAttribute']?.("hidden"); const readPart = document.body.getAttribute; readPart("part"); const readClass = document.body.getAttribute; readClass("class"); document.body.setAttribute("class", "runtime"); document.body['classList']; const { variant } = document.body; document.querySelector(".og-migrated-v1-type-frame"); getComputedStyle(document.body).getPropertyValue("--migrated-v1-accent");"#
        try fixture.writeRawHTML(html)
        try fixture.writeCSSLibrary(css)
        try runtime.write(to: runtimeURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：project migrationをdry-runする（When）
        let result = try fixture.core.migrateProject(projectURL: projectURL)
        let namespaceObservers = OpenGraphiteLegacyCSSMigrator.migrate(
            #"[|class], [*|hidden], [ns|variant], [|part] { outline: 0; }"#
        )

        // 期待値：全observer/readerをstructured診断し、candidate diff/proposalを公開せず全source bytesを保持する（Then）
        #expect(result.diagnostics.contains { $0.code == "migration-generated-class-conflict" })
        #expect(result.diagnostics.contains { $0.code == "legacy-html-destination-conflict" })
        #expect(result.diagnostics.contains { $0.code == "legacy-css-destination-conflict" })
        #expect(result.diagnostics.contains { $0.code == "unsupported-legacy-css-construct" })
        #expect(result.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(namespaceObservers.hasGeneratedClassObserver)
        #expect(namespaceObservers.observedDestinationAttributes == Set(["class", "hidden", "variant", "part"]))
        #expect(!result.changed)
        #expect(result.diffs.isEmpty)
        #expect(result.proposalReference == nil)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == html)
        #expect(try fixture.readCSSLibrary() == css)
        #expect(try String(contentsOf: runtimeURL, encoding: .utf8) == runtime)
    }

    /// 論理名（日本語）: Borrowed attribute observer交差テスト
    /// 概要: `call`/`apply`で借用した標準attribute accessorをactual generated evidenceとだけ交差します。
    @Test("migrationはborrowed attribute observerをactual generated evidenceとだけ交差する")
    func testMigrationIntersectsBorrowedAttributeObserversWithGeneratedEvidence() throws {
        // コンディション：generated class/destinationを持つlegacy projectと同じobserverだけを持つclean projectを用意する（Given）
        let blockedFixture = try AgentInterfaceFixture()
        let cleanFixture = try AgentInterfaceFixture()
        let unrelatedFixture = try AgentInterfaceFixture()
        defer { blockedFixture.cleanUp(); cleanFixture.cleanUp(); unrelatedFixture.cleanUp() }
        let blockedProjectURL = blockedFixture.rootURL.appendingPathComponent("Project.ogp")
        let cleanProjectURL = cleanFixture.rootURL.appendingPathComponent("Project.ogp")
        let unrelatedProjectURL = unrelatedFixture.rootURL.appendingPathComponent("Project.ogp")
        let observer = #"getAttribute.call(node, 'class'); hasAttribute.call(node, 'hidden'); setAttribute.apply(node, ['variant', 'preview']); removeAttribute.call(node, 'part');"#
        let blockedHTML = #"<main data-og-type="frame" data-og-hidden="true" data-og-variant="preview" data-og-part="body">Legacy</main><script>"#
            + observer + "</script>"
        let cleanHTML = #"<main class="frame" hidden variant="preview" part="body">Clean</main><script>"#
            + observer + "</script>"
        try blockedFixture.writeRawHTML(blockedHTML)
        try blockedFixture.writeCSSLibrary("")
        try blockedFixture.writeProject(to: blockedProjectURL)
        try cleanFixture.writeRawHTML(cleanHTML)
        try cleanFixture.writeCSSLibrary("")
        try cleanFixture.writeProject(to: cleanProjectURL)
        let unrelatedHTML = #"<main data-og-type="frame">Legacy</main><script>setAttribute.apply(node, ['variant', 'preview']);</script>"#
        try unrelatedFixture.writeRawHTML(unrelatedHTML)
        try unrelatedFixture.writeCSSLibrary("")
        try unrelatedFixture.writeProject(to: unrelatedProjectURL)

        // 検証内容：両projectをdry-runする（When）
        let blocked = try blockedFixture.core.migrateProject(projectURL: blockedProjectURL)
        let clean = try cleanFixture.core.migrateProject(projectURL: cleanProjectURL)
        let unrelated = try unrelatedFixture.core.migrateProject(projectURL: unrelatedProjectURL)

        // 期待値：actual generated evidenceがあるprojectだけをatomic blockし、clean observerはno-opにする（Then）
        #expect(blocked.diagnostics.contains { $0.code == "migration-generated-class-conflict" })
        #expect(blocked.diagnostics.contains { $0.code == "legacy-html-destination-conflict" })
        #expect(!blocked.changed)
        #expect(blocked.diffs.isEmpty)
        #expect(blocked.proposalReference == nil)
        #expect(try String(contentsOf: blockedFixture.htmlURL, encoding: .utf8) == blockedHTML)
        #expect(clean.diagnostics.isEmpty)
        #expect(!clean.changed)
        #expect(clean.diffs.isEmpty)
        #expect(clean.proposalReference != nil)
        #expect(try String(contentsOf: cleanFixture.htmlURL, encoding: .utf8) == cleanHTML)
        #expect(unrelated.diagnostics.isEmpty)
        #expect(unrelated.changed)
        #expect(unrelated.proposalReference != nil)
        #expect(try String(contentsOf: unrelatedFixture.htmlURL, encoding: .utf8) == unrelatedHTML)
    }

    /// 論理名（日本語）: Existing standard destination observer境界テスト
    /// 概要: legacy値と同じstandard属性が既にある場合は生成evidenceへ含めず、authored observerとの誤衝突を防ぎます。
    @Test("migrationは既存standard属性をgenerated destinationへ誤分類しない")
    func testMigrationDoesNotGenerateExistingStandardDestinationEvidence() throws {
        // コンディション：同値のhidden/variant/partと、それらを観測するstandard CSSを持つlegacy projectを作る（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let html = #"<main hidden data-og-hidden='TRUE' variant='pre&#118;iew' data-og-variant="preview" part="bo&#100;y" data-og-part='body'>Legacy</main>"#
        let expectedHTML = #"<main hidden  variant='pre&#118;iew' part="bo&#100;y">Legacy</main>"#
        let css = #"[hidden], [variant~="preview"], [part~="body"] { outline: 0; }"#
        try fixture.writeRawHTML(html)
        try fixture.writeCSSLibrary(css)
        try fixture.writeProject(to: projectURL)
        let htmlMigration = OpenGraphiteHTMLDocument(html: html).migratingLegacyWebContract(path: "index.html")

        // 検証内容：HTML単体evidence、project-wide candidate、確認済みproposalのapplyを実行する（When）
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        let htmlDiff = try #require(dryRun.diffs.first { $0.path == "index.html" })
        let applied = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )

        // 期待値：既存standard属性をgenerated集合へ入れず、observerがあってもconflictなしでlegacy属性だけを除去する（Then）
        #expect(htmlMigration.generatedDestinationAttributes.isEmpty)
        #expect(htmlMigration.diagnostics.isEmpty)
        #expect(htmlMigration.source == expectedHTML)
        #expect(!dryRun.diagnostics.contains { $0.code == "legacy-html-destination-conflict" })
        #expect(dryRun.diagnostics.isEmpty)
        #expect(dryRun.changed)
        #expect(htmlDiff.unifiedDiff.contains(expectedHTML))
        #expect(applied.applied)
        #expect(applied.diagnostics.isEmpty)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == expectedHTML)
        #expect(try fixture.readCSSLibrary() == css)
    }

    /// 論理名（日本語）: Linked runtime CSS owner provenanceテスト
    /// 概要: linked runtimeのstyle owner observerを実際に参照するHTML集合だけへ束縛し、別page同名IDとの誤衝突を防ぎます。
    @Test("migrationはlinked runtime observerを参照pageのCSS ownerへ束縛する")
    func testMigrationBindsLinkedRuntimeObserverToReferringHTMLCSSOwners() throws {
        // コンディション：別page同名h1を読むsafe projectと、同一page styleを読むblocking projectを用意する（Given）
        let safeFixture = try AgentInterfaceFixture()
        let blockedFixture = try AgentInterfaceFixture()
        defer { safeFixture.cleanUp(); blockedFixture.cleanUp() }
        let safeProjectURL = safeFixture.rootURL.appendingPathComponent("Project.ogp")
        let safeSecondaryURL = safeFixture.rootURL.appendingPathComponent("secondary.html")
        let safeRuntimeURL = safeFixture.rootURL.appendingPathComponent("b.js")
        let safeFirstHTML = #"<style id="theme">:root{--og-accent:red;color:var(--og-accent)}</style><main>A</main>"#
        let safeSecondHTML = #"<h1 id="theme">B</h1><script src="b.js"></script>"#
        let observer = #"document.getElementById('theme').textContent"#
        try safeFixture.writeRawHTML(safeFirstHTML)
        try safeFixture.writeRawHTML(safeSecondHTML, to: safeSecondaryURL)
        try safeFixture.writeCSSLibrary("")
        try observer.write(to: safeRuntimeURL, atomically: true, encoding: .utf8)
        try safeFixture.writeProjectWithTwoPages(to: safeProjectURL)

        let blockedProjectURL = blockedFixture.rootURL.appendingPathComponent("Project.ogp")
        let blockedRuntimeURL = blockedFixture.rootURL.appendingPathComponent("b.js")
        let blockedHTML = #"<style id="theme">:root{--og-accent:red;color:var(--og-accent)}</style><script src="b.js"></script>"#
        try blockedFixture.writeRawHTML(blockedHTML)
        try blockedFixture.writeCSSLibrary("")
        try observer.write(to: blockedRuntimeURL, atomically: true, encoding: .utf8)
        try blockedFixture.writeProject(to: blockedProjectURL)

        // 検証内容：両projectをdry-runし、safe proposalだけApplyして冪等性を確認する（When）
        let safe = try safeFixture.core.migrateProject(projectURL: safeProjectURL)
        let safeApplied = try safeFixture.core.migrateProject(
            projectURL: safeProjectURL,
            proposalReference: try #require(safe.proposalReference),
            apply: true
        )
        let safeRepeated = try safeFixture.core.migrateProject(projectURL: safeProjectURL)
        let blocked = try blockedFixture.core.migrateProject(projectURL: blockedProjectURL)

        // 期待値：別pageの同名非style要素は許可し、同一pageのactual style observerだけをatomic blockする（Then）
        #expect(safe.diagnostics.isEmpty)
        #expect(safe.changed)
        #expect(safe.diffs.map(\.path) == ["index.html"])
        #expect(safeApplied.applied)
        #expect(safeApplied.diagnostics.isEmpty)
        #expect(!safeRepeated.changed)
        #expect(safeRepeated.diffs.isEmpty)
        #expect(try String(contentsOf: safeSecondaryURL, encoding: .utf8) == safeSecondHTML)
        #expect(blocked.diagnostics.contains { $0.code == "unsupported-legacy-runtime-source" })
        #expect(!blocked.changed)
        #expect(blocked.diffs.isEmpty)
        #expect(blocked.proposalReference == nil)
        #expect(try String(contentsOf: blockedFixture.htmlURL, encoding: .utf8) == blockedHTML)
    }

    /// 論理名（日本語）: Multi-file migration rollbackテスト
    /// 概要: 後方candidateのcommit失敗時に先行source bytesとmodeを復元し、stage/backup artifactを残しません。
    @Test("migrationは途中commit失敗時にbytesとmodeをrollbackする")
    func testMigrationCommitFailureRollsBackBytesModeAndArtifacts() throws {
        // コンディション：path順で2つのlegacy HTMLを登録し、先行fileへ非default modeを設定してdry-runする（Given）
        let fixture = try AgentInterfaceFixture()
        defer {
            try? FileManager.default.setAttributes(
                [.immutable: false],
                ofItemAtPath: fixture.rootURL.appendingPathComponent("secondary.html").path
            )
            fixture.cleanUp()
        }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let secondaryURL = fixture.rootURL.appendingPathComponent("secondary.html")
        let firstHTML = "<main data-og-type=\"frame\">First</main>"
        let secondHTML = "<main data-og-layout=\"vertical\">Second</main>"
        try fixture.writeRawHTML(firstHTML)
        try fixture.writeRawHTML(secondHTML, to: secondaryURL)
        try fixture.writeCSSLibrary("")
        try fixture.writeProjectWithTwoPages(to: projectURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: fixture.htmlURL.path)
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        let firstModeBefore = try #require(
            FileManager.default.attributesOfItem(atPath: fixture.htmlURL.path)[.posixPermissions] as? NSNumber
        )
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: secondaryURL.path)

        // 検証内容：後方fileだけcommit不能な状態で確認済みproposalをApplyする（When）
        let result = try fixture.core.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: secondaryURL.path)
        let firstModeAfter = try #require(
            FileManager.default.attributesOfItem(atPath: fixture.htmlURL.path)[.posixPermissions] as? NSNumber
        )
        let artifacts = try FileManager.default.contentsOfDirectory(
            at: fixture.rootURL,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(".og-migration-") }

        // 期待値：write failureを返し、先行/失敗fileのbytesと先行modeを復元して一時artifactを全削除する（Then）
        #expect(!result.applied)
        #expect(result.diagnostics.contains { $0.code == "migration-write-failed" })
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == firstHTML)
        #expect(try String(contentsOf: secondaryURL, encoding: .utf8) == secondHTML)
        #expect(firstModeAfter == firstModeBefore)
        #expect(artifacts.isEmpty)
    }

    /// 論理名（日本語）: Per-source commit snapshot再検証テスト
    /// 概要: all-file preflight後の外部変更を次source commit直前に検出し、先行commitだけをrollbackします。
    @Test("migrationは各commit直前に全source raw snapshotを再検証する")
    func testMigrationRevalidatesAllSnapshotsBeforeEveryCommit() throws {
        // コンディション：2つの変更対象pageを持つprojectと、2件目commit直前に外部編集するhookを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let secondaryURL = fixture.rootURL.appendingPathComponent("secondary.html")
        let runtimeURL = fixture.rootURL.appendingPathComponent("runtime")
        let firstHTML = #"<main data-og-type="frame">First</main><script src="runtime"></script>"#
        let secondHTML = #"<main data-og-layout="vertical">Second</main>"#
        let runtime = #"console.log("snapshot");"#
        let externalRuntimeEdit = runtime + "// concurrent edit"
        try fixture.writeRawHTML(firstHTML)
        try fixture.writeRawHTML(secondHTML, to: secondaryURL)
        try runtime.write(to: runtimeURL, atomically: true, encoding: .utf8)
        try fixture.writeCSSLibrary("")
        try fixture.writeProjectWithTwoPages(to: projectURL)
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        var mutationAttempted = false
        let racingCore = OpenGraphiteAgentCore(
            contract: .builtIn,
            migrationWillCommitSource: { index, _ in
                guard index == 1 else { return }
                mutationAttempted = true
                try? externalRuntimeEdit.write(to: runtimeURL, atomically: true, encoding: .utf8)
            }
        )

        // 検証内容：先頭page commit後、diffを持たないruntime dependencyを外部変更した状態でapplyを継続する（When）
        let result = try racingCore.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        let artifacts = try FileManager.default.contentsOfDirectory(
            at: fixture.rootURL,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(".og-migration-") }

        // 期待値：staleをstructured返却し、先行pageはbefore bytesへ戻し、unchanged dependencyの外部編集を保持する（Then）
        #expect(mutationAttempted)
        #expect(result.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(!result.applied)
        #expect(!result.changed)
        #expect(result.diffs.isEmpty)
        #expect(result.proposalReference == nil)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == firstHTML)
        #expect(try String(contentsOf: secondaryURL, encoding: .utf8) == secondHTML)
        #expect(try String(contentsOf: runtimeURL, encoding: .utf8) == externalRuntimeEdit)
        #expect(artifacts.isEmpty)
    }

    /// 論理名（日本語）: Rollback concurrent edit CASテスト
    /// 概要: stale検出前に外部変更されたcommit済みsourceをrollbackが上書きせず、競合をstructured診断します。
    @Test("migration rollbackはcommit済みsourceの外部編集を保持する")
    func testMigrationRollbackPreservesConcurrentEditToCommittedSource() throws {
        // コンディション：2つの変更対象pageと、2件目commit直前にcommit済み先頭pageを外部編集するhookを用意する（Given）
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Project.ogp")
        let secondaryURL = fixture.rootURL.appendingPathComponent("secondary.html")
        let firstHTML = #"<main data-og-type="frame">First</main>"#
        let secondHTML = #"<main data-og-layout="vertical">Second</main>"#
        let concurrentFirstHTML = #"<main class="external-edit">Concurrent</main>"#
        try fixture.writeRawHTML(firstHTML)
        try fixture.writeRawHTML(secondHTML, to: secondaryURL)
        try fixture.writeCSSLibrary("")
        try fixture.writeProjectWithTwoPages(to: projectURL)
        let dryRun = try fixture.core.migrateProject(projectURL: projectURL)
        let proposal = try #require(dryRun.proposalReference)
        var mutationAttempted = false
        let racingCore = OpenGraphiteAgentCore(
            contract: .builtIn,
            migrationWillCommitSource: { index, _ in
                guard index == 1 else { return }
                mutationAttempted = true
                try? concurrentFirstHTML.write(
                    to: fixture.htmlURL,
                    atomically: true,
                    encoding: .utf8
                )
            }
        )

        // 検証内容：先頭page commit後に同fileへ外部変更を入れ、2件目commit直前の全snapshot検証を走らせる（When）
        let result = try racingCore.migrateProject(
            projectURL: projectURL,
            proposalReference: proposal,
            apply: true
        )
        let artifacts = try FileManager.default.contentsOfDirectory(
            at: fixture.rootURL,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(".og-migration-") }

        // 期待値：staleとrollback競合を返し、Aの外部bytesと未commit Bのbefore bytesを保持してartifactを残さない（Then）
        #expect(mutationAttempted)
        #expect(result.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(result.diagnostics.contains { $0.code == "migration-rollback-failed" })
        #expect(!result.applied)
        #expect(!result.changed)
        #expect(result.diffs.isEmpty)
        #expect(result.proposalReference == nil)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == concurrentFirstHTML)
        #expect(try String(contentsOf: secondaryURL, encoding: .utf8) == secondHTML)
        #expect(artifacts.isEmpty)
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

    /// 論理名（日本語）: Raw HTML書き込み関数
    /// 処理概要: optional annotation/no-op roundtrip test用に入力bytesを補完せずfixture HTMLへ保存します。
    ///
    /// - Parameter html: annotationを含めて一切変換しない入力HTML。
    func writeRawHTML(_ html: String) throws {
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: Raw HTML指定先書き込み関数
    /// 処理概要: optional annotation/no-op roundtrip test用に入力bytesを補完せず指定fixture URLへ保存します。
    ///
    /// - Parameters:
    ///   - html: annotationを含めて一切変換しない入力HTML。
    ///   - url: 書き込み先fixture URL。
    func writeRawHTML(_ html: String, to url: URL) throws {
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: Companion CSS書き込み関数
    /// 処理概要: fixture の HTML と同名の companion CSS へ指定文字列を書き込みます。
    ///
    /// - Parameter css: 書き込む CSS。
    func writeCompanionCSS(_ css: String) throws {
        try css.write(
            to: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            atomically: true,
            encoding: .utf8
        )
    }

    /// 論理名（日本語）: Companion CSS読込関数
    /// 処理概要: fixture の HTML と同名の companion CSS を読み込みます。
    ///
    /// - Returns: companion CSS の全文。
    func readCompanionCSS() throws -> String {
        try String(contentsOf: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL), encoding: .utf8)
    }

    /// 論理名（日本語）: CSS library書き込み関数
    /// 処理概要: fixture project が参照する `OpenGraphite.css` へ指定 CSS を書き込みます。
    ///
    /// - Parameter css: 書き込む CSS。
    func writeCSSLibrary(_ css: String) throws {
        try css.write(to: rootURL.appendingPathComponent("OpenGraphite.css"), atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: CSS library読込関数
    /// 処理概要: fixture project が参照する `OpenGraphite.css` を読み込みます。
    ///
    /// - Returns: CSS library の全文。
    func readCSSLibrary() throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent("OpenGraphite.css"), encoding: .utf8)
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

    /// 論理名（日本語）: 2ページproject manifest書き込み関数
    /// 処理概要: atomic migrationのmulti-file commit/rollbackを再現する2つの登録pageを作成します。
    ///
    /// - Parameter url: 書き込み先 `.ogp` URL。
    func writeProjectWithTwoPages(to url: URL) throws {
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
                  "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
                },
                {
                  "id": "secondary",
                  "internalID": "secondary-page",
                  "path": "secondary.html",
                  "canvas": { "name": "", "x": 0, "y": 1240, "width": 1440, "height": 1200 }
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
