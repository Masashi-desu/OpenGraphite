import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: アイコンCDN依存性テストスイート
/// 概要: HTML の `data-og-icon-source="cdn"` を Project Dependencies 向けに集約できることを確認します。
@Suite("アイコンCDN依存性テストスイート")
struct OpenGraphiteIconCDNDependencyTests {
    /// 論理名（日本語）: CDNアイコン集約テスト
    /// 概要: Lucide CDN icon node だけを provider/package/version 単位で集約することを検証します。
    @Test("Lucide CDN iconを依存性として集約する")
    func testAggregatesLucideCDNIcons() throws {
        // Given: CDN / inline / library source が混在した HTML を用意する
        let html = """
        <Icon data-og-id="star" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="cdn">
          <span data-og-icon-mask="true" style="--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');" aria-hidden="true"></span>
        </Icon>
        <Icon data-og-id="open" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="panel-left-open" data-og-icon-source="cdn">
          <span data-og-icon-mask="true" style="--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/panel-left-open.svg');" aria-hidden="true"></span>
        </Icon>
        <Icon data-og-id="inline" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline"></Icon>
        <Icon data-og-id="runtime" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="square" data-og-icon-source="library"></Icon>
        """

        // When: HTML から CDN icon 依存性を検出する
        let dependencies = OpenGraphiteIconCDNDependencyScanner.dependencies(in: [html])
        let dependency = try #require(dependencies.first)

        // Then: CDN source だけが Lucide static CDN として 1 行に集約される
        #expect(dependencies.count == 1)
        #expect(dependency.library == "lucide")
        #expect(dependency.provider == "cdn.jsdelivr.net")
        #expect(dependency.package == "lucide-static")
        #expect(dependency.version == "latest")
        #expect(dependency.packageLabel == "lucide-static@latest")
        #expect(dependency.statusLabel == "Unpinned")
        #expect(dependency.usedCount == 2)
        #expect(dependency.usageLabel == "2 uses")
        #expect(dependency.iconNames == ["panel-left-open", "star"])
    }

    /// 論理名（日本語）: Component含有project検出テスト
    /// 概要: Project の通常 page だけでなく component master HTML からも CDN icon 依存性を検出することを確認します。
    @Test("Component master内のCDN iconもProject依存性に含める")
    func testLoadedProjectScanIncludesComponentMasters() throws {
        // Given: 通常 page と component master を持つ一時 project を用意する
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteIconCDNDependencyTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let publicURL = rootURL.appendingPathComponent("public")
        let componentDirectoryURL = publicURL.appendingPathComponent("_components")
        try FileManager.default.createDirectory(at: componentDirectoryURL, withIntermediateDirectories: true)
        try "<!doctype html><html><body><Title data-og-id=\"title\">Home</Title></body></html>".write(
            to: publicURL.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        try """
        <!doctype html>
        <html><body>
          <Icon data-og-id="close" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="panel-left-close" data-og-icon-source="cdn">
            <span data-og-icon-mask="true" style="--og-icon-url:url('https://cdn.jsdelivr.net/npm/lucide-static@0.468.0/icons/panel-left-close.svg');" aria-hidden="true"></span>
          </Icon>
        </body></html>
        """.write(
            to: componentDirectoryURL.appendingPathComponent("design-system.html"),
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Icon CDN Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ]
        )
        let loadedProject = LoadedOpenGraphiteProject(
            project: project,
            fileURL: rootURL.appendingPathComponent("fixture.ogp"),
            rootURL: rootURL
        )

        // When: project 全体から CDN icon 依存性を検出する
        let dependencies = OpenGraphiteIconCDNDependencyScanner.dependencies(for: loadedProject)
        let dependency = try #require(dependencies.first)

        // Then: component master 内の pinned CDN icon が依存性として表示できる
        #expect(dependencies.count == 1)
        #expect(dependency.version == "0.468.0")
        #expect(dependency.statusLabel == "External")
        #expect(dependency.usedCount == 1)
        #expect(dependency.iconNames == ["panel-left-close"])
    }
}
