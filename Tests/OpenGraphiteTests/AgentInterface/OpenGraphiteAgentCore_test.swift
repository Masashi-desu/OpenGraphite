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
        let originalHTML = """
        <!doctype html>
        <html><body><Page data-og-id="page" data-og-type="page"><Hero data-og-id="hero" data-og-type="frame"></Hero></Page></body></html>
        """
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
        #expect(result.graph?.nodes.map(\.id) == ["page", "title"])
        #expect(result.diagnostics.isEmpty)
    }

    /// 論理名（日本語）: プロジェクトページ追加テスト
    /// 概要: `.ogp` の pages に新しい page entry を追加できることを確認します。
    @Test("project page addでページ定義を追加できる")
    func testAddProjectPageUpdatesManifest() throws {
        // コンディション：単一 page を持つ project manifest を用意する
        let fixture = try AgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Sample.ogp")
        try fixture.writeHTML("<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>")
        try "<!doctype html><html><body><Page data-og-id=\"page\" data-og-type=\"page\"></Page></body></html>"
            .write(to: fixture.rootURL.appendingPathComponent("downloads.html"), atomically: true, encoding: .utf8)
        try fixture.writeProject(to: projectURL)

        // 検証内容：downloads page を追加する
        let summary = try fixture.core.addProjectPage(
            projectURL: projectURL,
            id: "downloads",
            path: "downloads.html",
            canvas: OpenGraphiteCanvas(x: 1480, y: 0, width: 1440, height: 1200)
        )

        // 期待値：manifest と summary に追加 page が反映される
        #expect(summary.pages.map(\.id) == ["home", "downloads"])
        #expect(summary.pages[1].path == "downloads.html")
        #expect(summary.pages[1].canvas.x == 1480)
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

        // 検証内容：既存 home page の x/y だけを更新する
        let summary = try fixture.core.placeProjectPage(
            projectURL: projectURL,
            id: "home",
            x: 1520,
            y: 80,
            width: nil,
            height: nil
        )

        // 期待値：未指定の width/height は維持され、指定座標だけが更新される
        #expect(summary.pages[0].canvas.x == 1520)
        #expect(summary.pages[0].canvas.y == 80)
        #expect(summary.pages[0].canvas.width == 1440)
        #expect(summary.pages[0].canvas.height == 1200)
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
        let result = try fixture.core.setTextContent("New", nodeID: "title", projectURL: projectURL, pageID: "home")
        let html = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：`.ogp` に登録済みの home page だけが更新される
        #expect(result.updated == true)
        #expect(result.path == fixture.htmlURL.path)
        #expect(html.contains(">New<"))
    }

    /// 論理名（日本語）: プロジェクトページ作成テスト
    /// 概要: `.ogp` 経由で新規 HTML を作成し、同時に pages へ登録できることを確認します。
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
                "--page-id", "home",
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
                "--page-id", "home",
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
}

/// 論理名（日本語）: Agentインターフェーステストfixture
/// 概要: 一時ディレクトリに HTML と project を作り、core / CLI テストを分離します。
private struct AgentInterfaceFixture {
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
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
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
          "pages": [
            {
              "id": "home",
              "path": "index.html",
              "canvas": {
                "x": 0,
                "y": 0,
                "width": 1440,
                "height": 1200
              }
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
