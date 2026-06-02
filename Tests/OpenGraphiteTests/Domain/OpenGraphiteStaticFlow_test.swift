import CoreGraphics
import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: 静的フロー解決関連のテストスイート
/// 概要: HTML の静的リンクと Pages の配置名から、フロー接続が正しく絞り込まれることを確認します。
@Suite("静的フロー解決関連のテストスイート")
struct OpenGraphiteStaticFlowTests {
    /// 論理名（日本語）: 同名配置フロー解決テスト
    /// 概要: 同じ HTML path を持つ複数配置がある場合、遷移元と同じ配置名の page だけを接続することを検証します。
    @Test("同じ配置名のPages同士だけで静的フローを解決する")
    func testConnectionsResolveOnlyMatchingCanvasName() throws {
        // コンディション：desktop/mobile の docs 配置を同じ path で持つ project を用意する（Given）
        let pages = [
            OpenGraphitePage(
                id: "home-desktop",
                path: "index.html",
                canvas: OpenGraphiteCanvas(name: "desktop", x: 0, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs-desktop",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(name: "desktop", x: 200, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs-mobile",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(name: "mobile", x: 400, y: 0, width: 100, height: 100)
            )
        ]
        let rootURL = URL(fileURLWithPath: "/tmp/OpenGraphiteStaticFlow", isDirectory: true)
        let project = OpenGraphiteProject(
            version: "1",
            name: "Static Flow",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: pages
        )
        let loadedProject = LoadedOpenGraphiteProject(
            project: project,
            fileURL: rootURL.appendingPathComponent("Project.ogp"),
            rootURL: rootURL
        )
        let link = OpenGraphiteStaticFlowLink(
            id: "home-docs",
            sourceNodeID: "docs-button",
            sourceLabel: "Docs",
            targetHref: "./docs.html",
            targetURL: "",
            sourceRect: CGRect(x: 12, y: 20, width: 36, height: 16)
        )

        // 検証内容：home desktop の静的リンクをフロー接続へ解決する（When）
        let connections = OpenGraphiteStaticFlowResolver.connections(
            pages: pages,
            loadedProject: loadedProject,
            linksByPageURL: [
                loadedProject.htmlURL(for: pages[0]).standardizedFileURL: [link]
            ]
        )

        // 期待値：desktop 名を持つ docs 配置だけへ接続され、mobile 配置は混在しない（Then）
        #expect(connections.count == 1)
        guard let connection = connections.first else {
            Issue.record("静的フロー接続が生成されませんでした。")
            return
        }
        #expect(connection.sourcePageID == "home-desktop")
        #expect(connection.targetPageID == "docs-desktop")
        #expect(connection.sourcePoint == CGPoint(x: 48, y: 28))
        #expect(connection.sourceSide == .right)
        #expect(connection.targetPoint == CGPoint(x: 200, y: 0))
        #expect(connection.targetSide == .left)
    }

    /// 論理名（日本語）: 左向きフロー接続テスト
    /// 概要: 遷移元が遷移先より右側にある場合、ボタン左端から遷移先プレビュー右上へ接続することを検証します。
    @Test("遷移元が右側にある場合はボタン左端から遷移先右上へ静的フローを接続する")
    func testConnectionsUseTargetRightSideWhenSourceIsRightOfTarget() throws {
        // コンディション：source が target の右側に配置された project を用意する（Given）
        let pages = [
            OpenGraphitePage(
                id: "home-desktop",
                path: "index.html",
                canvas: OpenGraphiteCanvas(name: "desktop", x: 300, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs-desktop",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(name: "desktop", x: 0, y: 0, width: 100, height: 100)
            )
        ]
        let rootURL = URL(fileURLWithPath: "/tmp/OpenGraphiteStaticFlow", isDirectory: true)
        let project = OpenGraphiteProject(
            version: "1",
            name: "Static Flow",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: pages
        )
        let loadedProject = LoadedOpenGraphiteProject(
            project: project,
            fileURL: rootURL.appendingPathComponent("Project.ogp"),
            rootURL: rootURL
        )
        let link = OpenGraphiteStaticFlowLink(
            id: "home-docs",
            sourceNodeID: "docs-button",
            sourceLabel: "Docs",
            targetHref: "./docs.html",
            targetURL: "",
            sourceRect: CGRect(x: 12, y: 20, width: 36, height: 16)
        )

        // 検証内容：右側配置の source から target page への静的リンクを解決する（When）
        let connections = OpenGraphiteStaticFlowResolver.connections(
            pages: pages,
            loadedProject: loadedProject,
            linksByPageURL: [
                loadedProject.htmlURL(for: pages[0]).standardizedFileURL: [link]
            ]
        )

        // 期待値：source ボタン左端から、target の左端ではなく source に近い右上へ接続される（Then）
        #expect(connections.count == 1)
        guard let connection = connections.first else {
            Issue.record("静的フロー接続が生成されませんでした。")
            return
        }
        #expect(connection.sourcePoint == CGPoint(x: 312, y: 28))
        #expect(connection.sourceSide == .left)
        #expect(connection.targetPoint == CGPoint(x: 100, y: 0))
        #expect(connection.targetSide == .right)
    }

    /// 論理名（日本語）: 配置名不一致フロー除外テスト
    /// 概要: 遷移先候補があっても配置名が一致しない場合、接続を生成しないことを検証します。
    @Test("配置名が一致しない遷移先は静的フローから除外する")
    func testConnectionsSkipDifferentCanvasName() {
        // コンディション：遷移元と異なる配置名の target page だけを持つ project を用意する（Given）
        let pages = [
            OpenGraphitePage(
                id: "home-desktop",
                path: "index.html",
                canvas: OpenGraphiteCanvas(name: "desktop", x: 0, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs-mobile",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(name: "mobile", x: 200, y: 0, width: 100, height: 100)
            )
        ]
        let rootURL = URL(fileURLWithPath: "/tmp/OpenGraphiteStaticFlow", isDirectory: true)
        let loadedProject = LoadedOpenGraphiteProject(
            project: OpenGraphiteProject(
                version: "1",
                name: "Static Flow",
                repositoryRoot: nil,
                htmlRoot: "public",
                cssLibrary: "CSS/OpenGraphite.css",
                pages: pages
            ),
            fileURL: rootURL.appendingPathComponent("Project.ogp"),
            rootURL: rootURL
        )
        let link = OpenGraphiteStaticFlowLink(
            id: "home-docs",
            sourceNodeID: "docs-button",
            sourceLabel: "Docs",
            targetHref: "./docs.html",
            targetURL: "",
            sourceRect: CGRect(x: 12, y: 20, width: 36, height: 16)
        )

        // 検証内容：home desktop の静的リンクをフロー接続へ解決する（When）
        let connections = OpenGraphiteStaticFlowResolver.connections(
            pages: pages,
            loadedProject: loadedProject,
            linksByPageURL: [
                loadedProject.htmlURL(for: pages[0]).standardizedFileURL: [link]
            ]
        )

        // 期待値：同名配置の target がないため接続は生成されない（Then）
        #expect(connections.isEmpty)
    }

    /// 論理名（日本語）: 空配置名フロー除外テスト
    /// 概要: 名前なしが空文字として明示されていても、空名同士ではフロー接続を生成しないことを検証します。
    @Test("空の配置名同士は静的フローから除外する")
    func testConnectionsSkipEmptyCanvasName() {
        // コンディション：名前なしを空文字で明示した source / target page を用意する（Given）
        let pages = [
            OpenGraphitePage(
                id: "home",
                path: "index.html",
                canvas: OpenGraphiteCanvas(name: "", x: 0, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(name: "", x: 200, y: 0, width: 100, height: 100)
            )
        ]
        let rootURL = URL(fileURLWithPath: "/tmp/OpenGraphiteStaticFlow", isDirectory: true)
        let loadedProject = LoadedOpenGraphiteProject(
            project: OpenGraphiteProject(
                version: "1",
                name: "Static Flow",
                repositoryRoot: nil,
                htmlRoot: "public",
                cssLibrary: "CSS/OpenGraphite.css",
                pages: pages
            ),
            fileURL: rootURL.appendingPathComponent("Project.ogp"),
            rootURL: rootURL
        )
        let link = OpenGraphiteStaticFlowLink(
            id: "home-docs",
            sourceNodeID: "docs-button",
            sourceLabel: "Docs",
            targetHref: "./docs.html",
            targetURL: "",
            sourceRect: CGRect(x: 12, y: 20, width: 36, height: 16)
        )

        // 検証内容：空の配置名を持つ page 同士で静的リンクを解決する（When）
        let connections = OpenGraphiteStaticFlowResolver.connections(
            pages: pages,
            loadedProject: loadedProject,
            linksByPageURL: [
                loadedProject.htmlURL(for: pages[0]).standardizedFileURL: [link]
            ]
        )

        // 期待値：名前なしは同名扱いせず、接続は生成されない（Then）
        #expect(connections.isEmpty)
    }
}
