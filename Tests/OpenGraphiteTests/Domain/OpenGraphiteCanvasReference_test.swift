import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスオブジェクト参照関連テストスイート
/// 概要: `.ogp`の参照配置schema、旧project互換、任意階層nodeのtyped参照解決を確認します。
@Suite("キャンバスオブジェクト参照関連テストスイート")
struct OpenGraphiteCanvasReferenceTests {
    /// 論理名（日本語）: 参照配置Codableテスト
    /// 概要: Chapter / Collection直下のreferencesがworld座標とtyped参照IDを保ってJSONを往復することを確認します。
    @Test("ChapterとCollectionの参照配置をogp JSONで往復できる")
    func testCanvasReferencesRoundTripInProjectJSON() throws {
        // コンディション：Pages nodeとComponent nodeを指す参照配置を用意する（Given）
        let pageReference = OpenGraphiteCanvasReference(
            internalID: "page-reference-opaque",
            referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
            x: 128,
            y: -64,
            width: 420,
            height: 260
        )
        let componentReference = OpenGraphiteCanvasReference(
            internalID: "component-reference-opaque",
            referenceID: "ogref:component-node:colopaque:cmpopaque:control-opaque",
            x: 640,
            y: 96
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Reference Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chopaque",
                    pages: [],
                    references: [pageReference]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "colopaque",
                    components: [],
                    references: [componentReference]
                )
            ]
        )

        // 検証内容：projectをJSONへencodeしてmodelへdecodeする（When）
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(OpenGraphiteProject.self, from: data)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let chapters = try #require(json["chapters"] as? [[String: Any]])
        let references = try #require(chapters.first?["references"] as? [[String: Any]])

        // 期待値：typed参照ID、world座標、枠寸法が維持される（Then）
        #expect(decoded == project)
        #expect(references.first?["referenceID"] as? String == pageReference.referenceID)
        #expect(references.first?["x"] as? Double == 128)
        #expect(references.first?["y"] as? Double == -64)
        #expect(decoded.collections.first?.references.first == componentReference)
    }

    /// 論理名（日本語）: 空参照配置互換テスト
    /// 概要: references keyがない旧`.ogp`を空配列として読み、空keyを再保存しないことを確認します。
    @Test("空referencesを省略して旧projectを読み込める")
    func testEmptyCanvasReferencesAreOmittedAndDecodeAsEmpty() throws {
        // コンディション：referencesを持たないmodelと旧形式JSONを用意する（Given）
        let project = OpenGraphiteProject(
            version: "1",
            name: "Empty Reference Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [OpenGraphiteChapter(id: "main", pages: [])],
            collections: [OpenGraphiteComponentCollection(id: "main", components: [])]
        )
        let legacyJSON = Data(
            """
            {
              "version": "1",
              "name": "Legacy",
              "htmlRoot": "public",
              "cssLibrary": "CSS/OpenGraphite.css",
              "chapters": [{ "id": "main", "pages": [] }],
              "collections": [{ "id": "main", "components": [] }]
            }
            """.utf8
        )

        // 検証内容：空modelをencodeし、旧JSONをdecodeする（When）
        let encoded = try JSONEncoder().encode(project)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let chapters = try #require(json["chapters"] as? [[String: Any]])
        let collections = try #require(json["collections"] as? [[String: Any]])
        let decoded = try JSONDecoder().decode(OpenGraphiteProject.self, from: legacyJSON)

        // 期待値：空keyは出力されず、旧projectは空referencesとして扱われる（Then）
        #expect(chapters.first?["references"] == nil)
        #expect(collections.first?["references"] == nil)
        #expect(decoded.chapters.first?.references.isEmpty == true)
        #expect(decoded.collections.first?.references.isEmpty == true)
    }

    /// 論理名（日本語）: 任意階層参照解決テスト
    /// 概要: PagesとComponentsの深いnodeを内部不変IDで解決し、Page root参照は拒否することを確認します。
    @Test("PagesとComponentsの任意階層node参照を解決する")
    func testResolverFindsNestedPageAndComponentNodes() throws {
        // コンディション：入れ子nodeを持つPage / Component projectを作成する（Given）
        let fixture = try CanvasReferenceTestFixture.make()
        defer { fixture.remove() }
        let loadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)

        // 検証内容：Page内nodeとComponent内nodeのtyped参照を解決する（When）
        let pageTarget = try OpenGraphiteCanvasReferenceResolver.resolve(
            "ogref:node:chopaque:pgopaque:nested-opaque",
            in: loadedProject
        )
        let componentTarget = try OpenGraphiteCanvasReferenceResolver.resolve(
            "ogref:component-node:colopaque:cmpopaque:control-opaque",
            in: loadedProject
        )

        // 期待値：任意深度の元nodeと所属segmentが解決され、Page rootは専用配置へ誘導される（Then）
        #expect(pageTarget.node.id == "nested-object")
        #expect(pageTarget.node.depth >= 2)
        #expect(pageTarget.segment == .pages)
        #expect(componentTarget.node.id == "component-control")
        #expect(componentTarget.segment == .components)
        #expect(throws: OpenGraphiteCanvasReferenceResolutionError.pageRootNotSupported) {
            _ = try OpenGraphiteCanvasReferenceResolver.resolve(
                "ogref:node:chopaque:pgopaque:page-root-opaque",
                in: loadedProject
            )
        }
    }

    /// 論理名（日本語）: 軽量HTML参照対象解決テスト
    /// 概要: 全Agent graphを生成しない参照専用APIが、任意階層nodeとproject rootを1回のtree走査で区別することを確認します。
    @Test("参照専用HTML APIは任意階層nodeとPage rootを区別する")
    func testLightweightReferenceTargetDistinguishesNestedNodeAndPageRoot() throws {
        // コンディション：Page rootと深い参照nodeを持つHTMLを用意する（Given）
        let fixture = try CanvasReferenceTestFixture.make()
        defer { fixture.remove() }
        let html = try String(contentsOf: fixture.pageHTMLURL, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)

        // 検証内容：参照専用APIでnested node、Page root、重複IDを解決する（When）
        let nested = document.referenceTarget(
            internalID: "nested-opaque",
            isProjectRegisteredResource: true
        )
        let root = document.referenceTarget(
            internalID: "page-root-opaque",
            isProjectRegisteredResource: true
        )
        let duplicateDocument = OpenGraphiteHTMLDocument(
            html: "<main><span data-og-internal-id=\"duplicate\"></span><i data-og-internal-id=\"duplicate\"></i></main>"
        )

        // 期待値：nested nodeは表示用情報を返し、rootはguard可能、重複identityは曖昧解決しない（Then）
        #expect(nested?.id == "nested-object")
        #expect(nested?.internalID == "nested-opaque")
        #expect(nested?.tagName == "label")
        #expect((nested?.depth ?? 0) >= 2)
        #expect(nested?.isProjectResourceRoot == false)
        #expect(root?.isProjectResourceRoot == true)
        #expect(duplicateDocument.referenceTarget(internalID: "duplicate") == nil)
    }

    /// 論理名（日本語）: Main参照解決性能計測テスト
    /// 概要: Main chapterの実HTMLで全Agent graph生成と参照専用tree走査を同一process内で計測し、対象nodeの同値性を確認します。
    @Test("Main実HTMLの参照専用解決時間を計測する")
    func testMainSampleReferenceResolutionPerformance() throws {
        // コンディション：Main chapterのhero-copy参照元HTMLをrepository正本から読み込む（Given）
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let html = try String(
            contentsOf: repositoryURL.appendingPathComponent("public/index.html"),
            encoding: .utf8
        )
        let targetInternalID = "1rl4q0jsthuim"

        // 検証内容：旧参照経路相当の全graph生成と、新しい参照専用解決を個別に計測する（When）
        let graphStart = DispatchTime.now().uptimeNanoseconds
        let graphNodes = OpenGraphiteHTMLDocument(html: html).nodes(
            isProjectRegisteredResource: true
        )
        let graphElapsed = DispatchTime.now().uptimeNanoseconds - graphStart

        let targetStart = DispatchTime.now().uptimeNanoseconds
        let target = OpenGraphiteHTMLDocument(html: html).referenceTarget(
            internalID: targetInternalID,
            isProjectRegisteredResource: true
        )
        let targetElapsed = DispatchTime.now().uptimeNanoseconds - targetStart

        let graphMilliseconds = Double(graphElapsed) / 1_000_000
        let targetMilliseconds = Double(targetElapsed) / 1_000_000
        let speedup = targetElapsed == 0 ? 0 : Double(graphElapsed) / Double(targetElapsed)
        print(
            String(
                format: "CANVAS_REFERENCE_PERF fullGraph=%.3fms targeted=%.3fms ratio=%.1fx",
                graphMilliseconds,
                targetMilliseconds,
                speedup
            )
        )

        // 期待値：両経路は同じhero-copyを返し、参照専用結果はPage rootではない（Then）
        #expect(graphNodes.first { $0.internalID == targetInternalID }?.id == "hero-copy")
        #expect(target?.id == "hero-copy")
        #expect(target?.isProjectResourceRoot == false)
    }
}

/// 論理名（日本語）: キャンバス参照テストFixture
/// 概要: Page / Componentのtyped node参照を同じ`.ogp`で検証する一時projectを構成します。
private struct CanvasReferenceTestFixture {
    var rootURL: URL
    var projectURL: URL
    var pageHTMLURL: URL
    var componentHTMLURL: URL

    /// 論理名（日本語）: キャンバス参照Fixture生成関数
    /// 処理概要: HTML、CSS、manifestを一時directoryへ作成して参照解決可能なprojectを返します。
    ///
    /// - Returns: 作成済み一時project Fixture。
    static func make() throws -> CanvasReferenceTestFixture {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("OpenGraphiteCanvasReferenceTests-\(UUID().uuidString)", isDirectory: true)
        let publicURL = rootURL.appendingPathComponent("public", isDirectory: true)
        let componentsURL = publicURL.appendingPathComponent("_components", isDirectory: true)
        let cssURL = rootURL.appendingPathComponent("CSS", isDirectory: true)
        try fileManager.createDirectory(at: componentsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cssURL, withIntermediateDirectories: true)

        let pageHTMLURL = publicURL.appendingPathComponent("index.html")
        let componentHTMLURL = componentsURL.appendingPathComponent("controls.html")
        let projectURL = rootURL.appendingPathComponent("ReferenceFixture.ogp")
        try Data(
            """
            <html><body>
              <Page data-og-id="page" data-og-internal-id="page-root-opaque" data-og-type="page">
                <Section data-og-id="section" data-og-internal-id="section-opaque" data-og-type="frame">
                  <Group data-og-id="group" data-og-internal-id="group-opaque" data-og-type="frame">
                    <Label data-og-id="nested-object" data-og-internal-id="nested-opaque" data-og-type="text">Nested</Label>
                  </Group>
                </Section>
              </Page>
            </body></html>
            """.utf8
        ).write(to: pageHTMLURL)
        try Data(
            """
            <html><body>
              <Canvas data-og-id="component-root" data-og-internal-id="component-root-opaque" data-og-type="page">
                <Panel data-og-id="panel" data-og-internal-id="panel-opaque" data-og-type="frame">
                  <Control data-og-id="component-control" data-og-internal-id="control-opaque" data-og-type="button">Control</Control>
                </Panel>
              </Canvas>
            </body></html>
            """.utf8
        ).write(to: componentHTMLURL)
        try Data("/* fixture */".utf8).write(to: cssURL.appendingPathComponent("OpenGraphite.css"))

        let project = OpenGraphiteProject(
            version: "1",
            name: "Reference Fixture",
            repositoryRoot: ".",
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chopaque",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "pgopaque",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 800, height: 600)
                        )
                    ]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "components",
                    internalID: "colopaque",
                    components: [
                        OpenGraphitePage(
                            id: "controls",
                            internalID: "cmpopaque",
                            path: "_components/controls.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 600, height: 400)
                        )
                    ]
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(project).write(to: projectURL)
        return CanvasReferenceTestFixture(
            rootURL: rootURL,
            projectURL: projectURL,
            pageHTMLURL: pageHTMLURL,
            componentHTMLURL: componentHTMLURL
        )
    }

    /// 論理名（日本語）: キャンバス参照Fixture削除関数
    /// 処理概要: テスト用一時project directoryを削除します。
    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
