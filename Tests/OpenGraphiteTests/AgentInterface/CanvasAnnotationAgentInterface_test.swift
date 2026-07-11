import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス注釈Agentインターフェーステストスイート
/// 概要: `.ogp` の付箋と手書きを core / CLI から参照する契約を確認します。
@Suite("キャンバス注釈Agentインターフェーステストスイート")
struct CanvasAnnotationAgentInterfaceTests {
    /// 論理名（日本語）: 注釈一覧とproject要約テスト
    /// 概要: Chapter / Collection の注釈要約と件数を、安定したtyped参照ID付きで返すことを確認します。
    @Test("coreはChapterとCollectionの注釈一覧を要約できる")
    func testCoreListsCanvasAnnotations() throws {
        // コンディション：付箋を持つ Chapter と手書きを持つ Collection を用意する（Given）
        let fixture = try CanvasAnnotationAgentInterfaceFixture()
        defer { fixture.cleanUp() }

        // 検証内容：表示 ID と typed Collection 参照で一覧を取得し、project 要約も取得する（When）
        let pageResult = try fixture.core.canvasAnnotations(
            projectURL: fixture.projectURL,
            chapterID: "main",
            collectionID: nil
        )
        let componentResult = try fixture.core.canvasAnnotations(
            projectURL: fixture.projectURL,
            chapterID: nil,
            collectionID: "ogref:collection:component-main"
        )
        let projectSummary = try fixture.core.inspectProject(at: fixture.projectURL)
        let pageAnnotation = try #require(pageResult.annotations.first)
        let componentAnnotation = try #require(componentResult.annotations.first)

        // 期待値：一覧は付箋本文と手書き件数を返し、点列本体は展開しない（Then）
        #expect(pageResult.segment == "pages")
        #expect(pageResult.containerInternalID == "a7f21c")
        #expect(pageResult.containerReferenceID == "ogref:chapter:a7f21c")
        #expect(pageResult.annotations.count == 1)
        #expect(pageAnnotation.referenceID == "ogref:annotation:pages:a7f21c:note-alpha")
        #expect(pageAnnotation.kind == .stickyNote)
        #expect(pageAnnotation.text == "リリース前に確認")
        #expect(pageAnnotation.strokeCount == 0)
        #expect(pageAnnotation.pointCount == 0)

        #expect(componentResult.segment == "components")
        #expect(componentResult.containerInternalID == "component-main")
        #expect(componentResult.annotations.count == 1)
        #expect(componentAnnotation.referenceID == "ogref:annotation:components:component-main:ink-beta")
        #expect(componentAnnotation.kind == .ink)
        #expect(componentAnnotation.text == nil)
        #expect(componentAnnotation.backgroundColor == nil)
        #expect(componentAnnotation.strokeCount == 1)
        #expect(componentAnnotation.pointCount == 2)

        #expect(projectSummary.chapters.first?.annotationCount == 1)
        #expect(projectSummary.collections.first?.annotationCount == 1)
    }

    /// 論理名（日本語）: CLI注釈取得テスト
    /// 概要: `annotation list|get` が raw ID と typed ID を扱い、手書き点列を JSON で返すことを確認します。
    @Test("CLIは注釈一覧と手書き点列をJSONで返す")
    func testCLIListsAndGetsCanvasAnnotations() throws {
        // コンディション：付箋と Apple Pencil 由来の手書きを持つ project を用意する（Given）
        let fixture = try CanvasAnnotationAgentInterfaceFixture()
        defer { fixture.cleanUp() }
        let cli = OgkilnCLI()
        var stdout = ""
        var stderr = ""

        // 検証内容：Chapter 一覧と typed 注釈参照を CLI から取得する（When）
        let listCode = cli.run(
            arguments: ["annotation", "list", "Sample.ogp", "--chapter-id", "main", "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let listResult = try JSONDecoder().decode(
            OpenGraphiteCanvasAnnotationListResult.self,
            from: Data(stdout.utf8)
        )

        stdout = ""
        stderr = ""
        let getCode = cli.run(
            arguments: [
                "annotation", "get", "Sample.ogp",
                "--id", "ogref:annotation:components:component-main:ink-beta",
                "--json"
            ],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )
        let getResult = try JSONDecoder().decode(
            OpenGraphiteCanvasAnnotationGetResult.self,
            from: Data(stdout.utf8)
        )
        let stroke = try #require(getResult.annotation.annotation.strokes.first)
        let secondPoint = try #require(stroke.points.dropFirst().first)

        stdout = ""
        stderr = ""
        let rejectedCode = cli.run(
            arguments: ["annotation", "get", "Sample.ogp", "--id", "note-alpha", "--json"],
            currentDirectory: fixture.rootURL,
            stdout: { stdout += $0 },
            stderr: { stderr += $0 }
        )

        // 期待値：一覧と完全 payload は取得でき、raw ID のコンテナ省略は拒否される（Then）
        #expect(listCode == 0)
        #expect(listResult.annotations.map(\.internalID) == ["note-alpha"])
        #expect(getCode == 0)
        #expect(getResult.annotation.referenceID == "ogref:annotation:components:component-main:ink-beta")
        #expect(getResult.annotation.annotation.kind == .ink)
        #expect(getResult.annotation.annotation.strokes.count == 1)
        #expect(stroke.inputDevice == .pen)
        #expect(stroke.points.count == 2)
        #expect(secondPoint.pressure == 0.75)
        #expect(rejectedCode != 0)
        #expect(stderr.contains("--chapter-id"))
        #expect(stderr.contains("--collection-id"))
    }
}

/// 論理名（日本語）: キャンバス注釈Agent fixture
/// 概要: Chapter / Collection 注釈を持つ最小 project を一時ディレクトリに作ります。
private struct CanvasAnnotationAgentInterfaceFixture {
    let rootURL: URL
    let projectURL: URL
    let core: OpenGraphiteAgentCore

    /// 論理名（日本語）: キャンバス注釈fixture初期化関数
    /// 処理概要: HTML / CSS と注釈付き `.ogp` を一時ディレクトリへ書き込みます。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteCanvasAnnotationAgent-\(UUID().uuidString)")
        projectURL = rootURL.appendingPathComponent("Sample.ogp")
        core = OpenGraphiteAgentCore(contract: .builtIn)

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "<!doctype html><html><body><Page data-og-id=\"page\" data-og-internal-id=\"page-main\" data-og-type=\"page\"></Page></body></html>"
            .write(to: rootURL.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "<!doctype html><html><body><Card data-og-id=\"card\" data-og-internal-id=\"card-main\" data-og-type=\"frame\"></Card></body></html>"
            .write(to: rootURL.appendingPathComponent("cards.html"), atomically: true, encoding: .utf8)
        try ":root {}\n".write(
            to: rootURL.appendingPathComponent("OpenGraphite.css"),
            atomically: true,
            encoding: .utf8
        )

        let project = """
        {
          "version": "0.1.0",
          "name": "Canvas Annotation Fixture",
          "repositoryRoot": ".",
          "htmlRoot": ".",
          "cssLibrary": "OpenGraphite.css",
          "chapters": [
            {
              "id": "main",
              "internalID": "a7f21c",
              "title": "Main",
              "annotations": [
                {
                  "internalID": "note-alpha",
                  "kind": "stickyNote",
                  "frame": { "x": 40, "y": 60, "width": 240, "height": 160 },
                  "text": "リリース前に確認",
                  "backgroundColor": "#FFE88A",
                  "textColor": "#231F14"
                }
              ],
              "pages": [
                {
                  "id": "home",
                  "internalID": "page-main",
                  "path": "index.html",
                  "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
                }
              ]
            }
          ],
          "collections": [
            {
              "id": "main",
              "internalID": "component-main",
              "title": "Main",
              "annotations": [
                {
                  "internalID": "ink-beta",
                  "kind": "ink",
                  "frame": { "x": 320, "y": 80, "width": 90, "height": 48 },
                  "strokes": [
                    {
                      "points": [
                        { "x": 0, "y": 1, "pressure": 0.4, "tiltX": 0.1, "tiltY": -0.1 },
                        { "x": 36, "y": 24, "pressure": 0.75, "tiltX": 0.2, "tiltY": -0.2 }
                      ],
                      "color": "#FF4D67",
                      "lineWidth": 3.5,
                      "inputDevice": "pen"
                    }
                  ]
                }
              ],
              "components": [
                {
                  "id": "cards",
                  "internalID": "card-main",
                  "path": "cards.html",
                  "canvas": { "name": "", "x": 0, "y": 0, "width": 960, "height": 900 }
                }
              ]
            }
          ]
        }
        """
        try project.write(to: projectURL, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: キャンバス注釈fixture削除関数
    /// 処理概要: テスト用一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
