import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: EditorStoreキャンバス参照テストスイート
/// 概要: 参照配置の正確なworld座標保存、Canvas直下所属、cross-segment編集対象解決、配置と参照元編集のUndo/Redoを確認します。
@MainActor
@Suite("EditorStoreキャンバス参照テストスイート")
struct EditorStoreCanvasReferenceTests {
    /// 論理名（日本語）: Canvas参照非同期キャッシュテスト
    /// 概要: SwiftUI描画前はidleを返し、background解決後は同じproject / page revisionの結果を同期的に再利用することを確認します。
    @Test("Canvas参照はbackground解決後にrevisionキャッシュを再利用する")
    func testCanvasReferenceResolutionUsesBackgroundRevisionCache() async throws {
        // コンディション：任意階層nodeを持つprojectを開き、参照をまだ解決していない（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let referenceID = "ogref:node:chopaque:pgopaque:nested-opaque"
        #expect(store.canvasReferenceResolutionState(for: referenceID) == .idle)

        // 検証内容：参照をbackgroundで準備し、同じrevisionでもう一度準備する（When）
        await store.prepareCanvasReferenceResolution(for: referenceID)
        let firstResult = store.canvasReferenceResolutionState(for: referenceID)
        await store.prepareCanvasReferenceResolution(for: referenceID)
        let cachedResult = store.canvasReferenceResolutionState(for: referenceID)

        // 期待値：解決済み対象が公開され、2回目は同じrevisionキャッシュ値を維持する（Then）
        #expect(firstResult.target?.node.id == "nested-object")
        #expect(firstResult.target?.node.internalID == "nested-opaque")
        #expect(cachedResult == firstResult)
    }

    /// 論理名（日本語）: キャンバス直下参照追加テスト
    /// 概要: node参照がPage HTML内ではなくChapter直下へ右クリックworld座標どおり保存されることを確認します。
    @Test("参照配置はPage内ではなくChapter Canvas直下へ保存する")
    func testAddCanvasReferencePersistsAtCanvasRoot() throws {
        // コンディション：入れ子Page nodeを持つprojectを開く（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let originalHTML = try String(contentsOf: fixture.pageHTMLURL, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：Page内node参照をCanvas world座標へ追加する（When）
        let addedID = store.addCanvasReference(
            referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
            at: CGPoint(x: 512.5, y: -96.25)
        )

        // 期待値：Chapter.referencesだけが更新され、HTMLは不変で参照元nodeが編集対象になる（Then）
        let persisted = try JSONDecoder().decode(
            OpenGraphiteProject.self,
            from: Data(contentsOf: fixture.projectURL)
        )
        let reference = try #require(persisted.chapters.first?.references.first)
        #expect(addedID == reference.internalID)
        #expect(reference.x == 512.5)
        #expect(reference.y == -96.25)
        #expect(persisted.chapters.first?.pages.first?.path == "index.html")
        #expect(try String(contentsOf: fixture.pageHTMLURL, encoding: .utf8) == originalHTML)
        #expect(store.selectedCanvasReferenceTarget?.node.id == "nested-object")
        #expect(store.selectedDocumentSegment == .pages)
    }

    /// 論理名（日本語）: Cross-segment参照編集対象テスト
    /// 概要: Pages Canvas上のComponent node参照を選択してもCanvasを切り替えず、編集文脈だけをComponents正本へ接続することを確認します。
    @Test("Pages Canvas上のComponent node参照は元Componentを編集対象にする")
    func testComponentNodeReferenceKeepsCanvasAndUsesComponentEditContext() throws {
        // コンディション：Page ChapterとComponent Collectionを持つprojectをPages表示で開く（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        #expect(store.selectedCanvasSegment == .pages)

        // 検証内容：Component内node参照をPages Canvas直下へ追加して選択する（When）
        let addedID = store.addCanvasReference(
            referenceID: "ogref:component-node:colopaque:cmpopaque:control-opaque",
            at: CGPoint(x: 120, y: 80)
        )
        let selectedNodeReferenceID = store.nodeReferenceID(
            forNodeID: "component-control",
            nodeInternalID: "control-opaque"
        )

        // 期待値：配置先CanvasはPagesのまま、選択documentとnode参照はComponents正本を指す（Then）
        #expect(addedID != nil)
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.selectedDocumentSegment == .components)
        #expect(store.selectedPageURL?.standardizedFileURL == fixture.componentHTMLURL.standardizedFileURL)
        #expect(selectedNodeReferenceID == "ogref:component-node:colopaque:cmpopaque:control-opaque")
        let persisted = try JSONDecoder().decode(
            OpenGraphiteProject.self,
            from: Data(contentsOf: fixture.projectURL)
        )
        #expect(persisted.chapters.first?.references.count == 1)
        #expect(persisted.collections.first?.references.isEmpty == true)
    }

    /// 論理名（日本語）: 参照配置操作Undo/Redoテスト
    /// 概要: 参照配置の追加、移動、削除をそれぞれ一操作として取り消し、やり直せることを確認します。
    @Test("参照配置の追加移動削除を取り消してやり直せる")
    func testCanvasReferenceOperationsSupportUndoAndRedo() throws {
        // コンディション：参照配置のないChapter Canvasを開く（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：追加、移動、削除の各操作後にUndoとRedoを実行する（When）
        let referenceID = try #require(
            store.addCanvasReference(
                referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
                at: CGPoint(x: 80, y: 120)
            )
        )
        store.undoDocumentChange()
        let referencesAfterAddUndo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.references
        store.redoDocumentChange()
        let referenceAfterAddRedo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL)
                .project.chapters.first?.references.first
        )

        store.updateCanvasReferencePosition(id: referenceID, x: 280, y: -40)
        store.undoDocumentChange()
        let referenceAfterMoveUndo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL)
                .project.chapters.first?.references.first
        )
        store.redoDocumentChange()
        let referenceAfterMoveRedo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL)
                .project.chapters.first?.references.first
        )

        store.deleteCanvasReference(id: referenceID)
        store.undoDocumentChange()
        let referenceAfterDeleteUndo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL)
                .project.chapters.first?.references.first
        )
        store.redoDocumentChange()
        let referencesAfterDeleteRedo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.references

        // 期待値：各Undoで直前値、各Redoで確定値がcacheと`.ogp`へ復元される（Then）
        #expect(referencesAfterAddUndo?.isEmpty == true)
        #expect(referenceAfterAddRedo.internalID == referenceID)
        #expect(referenceAfterAddRedo.x == 80)
        #expect(referenceAfterAddRedo.y == 120)
        #expect(referenceAfterMoveUndo.x == 80)
        #expect(referenceAfterMoveUndo.y == 120)
        #expect(referenceAfterMoveRedo.x == 280)
        #expect(referenceAfterMoveRedo.y == -40)
        #expect(referenceAfterDeleteUndo.x == 280)
        #expect(referenceAfterDeleteUndo.y == -40)
        #expect(referencesAfterDeleteRedo?.isEmpty == true)
        #expect(store.selectedCanvasReferences.isEmpty)
        #expect(store.statusMessage == "参照配置の変更をやり直しました。")
        #expect(store.canUndo)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 参照元編集Undo/Redoテスト
    /// 概要: 参照viewportから行ったHTML text編集とcompanion CSS編集が統合履歴へ記録されることを確認します。
    @Test("参照経由のHTMLとCSS編集を取り消してやり直せる")
    func testReferencedObjectEditsSupportUndoAndRedo() async throws {
        // コンディション：Page内text nodeの参照配置を選択し、WebView相当のnode payloadを取り込む（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try #require(
            store.addCanvasReference(
                referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
                at: CGPoint(x: 80, y: 120)
            )
        )
        store.ingestNodePayload([
            [
                "id": "nested-object",
                "internalID": "nested-opaque",
                "tagName": "label",
                "type": "text",
                "textContent": "Nested",
                "fallbackTextContent": "Nested",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        await store.waitForNodeSourceEnrichment()
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(
            forHTMLURL: fixture.pageHTMLURL
        )

        // 検証内容：参照経由でtextを更新してUndo/Redoし、続けてCSS更新もUndo/Redoする（When）
        #expect(store.updateNodeTextContent("Edited through reference"))
        store.undoDocumentChange()
        let htmlAfterTextUndo = try String(contentsOf: fixture.pageHTMLURL, encoding: .utf8)
        store.redoDocumentChange()
        let htmlAfterTextRedo = try String(contentsOf: fixture.pageHTMLURL, encoding: .utf8)

        store.updateCSSVariable(key: "color", value: "#123456")
        let cssAfterEdit = try String(contentsOf: companionCSSURL, encoding: .utf8)
        store.undoDocumentChange()
        let cssExistsAfterUndo = FileManager.default.fileExists(atPath: companionCSSURL.path)
        store.redoDocumentChange()
        let cssAfterRedo = try String(contentsOf: companionCSSURL, encoding: .utf8)

        // 期待値：HTMLとCSSの正本が参照元URLで戻り、Redoで同じ編集結果へ復元される（Then）
        #expect(htmlAfterTextUndo.contains(">Nested</Label>"))
        #expect(htmlAfterTextRedo.contains(">Edited through reference</Label>"))
        #expect(cssAfterEdit.contains("color: #123456;"))
        #expect(cssExistsAfterUndo == false)
        #expect(cssAfterRedo.contains("color: #123456;"))
        #expect(store.selectedPageURL?.standardizedFileURL == fixture.pageHTMLURL.standardizedFileURL)
        #expect(store.selectedCanvasReferences.count == 1)
        #expect(store.canUndo)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 参照配置履歴外部競合拒否テスト
    /// 概要: 履歴記録後に同じcontainerの参照配置が外部変更された場合、Undoで外部値を上書きしないことを確認します。
    @Test("外部更新された参照配置へ古い履歴を適用しない")
    func testCanvasReferenceUndoRejectsExternallyChangedReferences() throws {
        // コンディション：参照追加を履歴へ記録後、storeへ通知せず位置を外部変更する（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try #require(
            store.addCanvasReference(
                referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
                at: CGPoint(x: 80, y: 120)
            )
        )
        var externalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        externalProject.chapters[0].references[0].x = 999
        try JSONEncoder().encode(externalProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：staleな参照追加履歴を取り消そうとする（When）
        store.undoDocumentChange()
        let persistedReference = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL)
                .project.chapters.first?.references.first
        )

        // 期待値：外部位置を保持して最新manifestへ同期し、無効になった統合履歴を破棄する（Then）
        #expect(persistedReference.x == 999)
        #expect(store.selectedCanvasReferences.first?.x == 999)
        #expect(store.statusMessage == ".ogp の外部変更を検出したため、参照配置の履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 参照元CSS履歴外部競合拒否テスト
    /// 概要: 参照経由のCSS編集後にcompanion CSSが外部変更された場合、Undoで外部値を上書きしないことを確認します。
    @Test("外部更新された参照元CSSへ古い履歴を適用しない")
    func testReferencedCSSUndoRejectsExternalChange() async throws {
        // コンディション：参照viewportからCSSを編集した後、同じcompanion CSSを外部変更する（Given）
        let fixture = try CanvasReferenceStoreFixture.make()
        defer { fixture.remove() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try #require(
            store.addCanvasReference(
                referenceID: "ogref:node:chopaque:pgopaque:nested-opaque",
                at: CGPoint(x: 80, y: 120)
            )
        )
        store.ingestNodePayload([
            [
                "id": "nested-object",
                "internalID": "nested-opaque",
                "tagName": "label",
                "type": "text",
                "textContent": "Nested",
                "fallbackTextContent": "Nested",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        await store.waitForNodeSourceEnrichment()
        store.updateCSSVariable(key: "color", value: "#123456")
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(
            forHTMLURL: fixture.pageHTMLURL
        )
        let externalCSS = "[data-og-internal-id=\"nested-opaque\"] { color: #abcdef; }\n"
        try externalCSS.write(to: companionCSSURL, atomically: true, encoding: .utf8)

        // 検証内容：staleな参照元CSS編集履歴を取り消そうとする（When）
        store.undoDocumentChange()
        let persistedCSS = try String(contentsOf: companionCSSURL, encoding: .utf8)

        // 期待値：外部CSSを保持し、競合した統合履歴を破棄する（Then）
        #expect(persistedCSS == externalCSS)
        #expect(store.statusMessage == "HTML / companion CSS の外部変更を検出したため、履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }
}

/// 論理名（日本語）: EditorStoreキャンバス参照Fixture
/// 概要: Storeのmanifest保存とcross-segment参照選択を検証する一時projectを構成します。
private struct CanvasReferenceStoreFixture {
    var rootURL: URL
    var projectURL: URL
    var pageHTMLURL: URL
    var componentHTMLURL: URL

    /// 論理名（日本語）: EditorStoreキャンバス参照Fixture生成関数
    /// 処理概要: Page / Component HTMLとmanifestを一時directoryへ作成します。
    ///
    /// - Returns: 作成済み一時project Fixture。
    static func make() throws -> CanvasReferenceStoreFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorStoreCanvasReferenceTests-\(UUID().uuidString)", isDirectory: true)
        let publicURL = rootURL.appendingPathComponent("public", isDirectory: true)
        let componentDirectory = publicURL.appendingPathComponent("_components", isDirectory: true)
        let cssDirectory = rootURL.appendingPathComponent("CSS", isDirectory: true)
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cssDirectory, withIntermediateDirectories: true)

        let pageHTMLURL = publicURL.appendingPathComponent("index.html")
        let componentHTMLURL = componentDirectory.appendingPathComponent("controls.html")
        let projectURL = rootURL.appendingPathComponent("StoreReferenceFixture.ogp")
        try Data(
            """
            <html><body><Page data-og-id="page" data-og-internal-id="page-root-opaque" data-og-type="page"><Group data-og-id="group" data-og-internal-id="group-opaque" data-og-type="frame"><Label data-og-id="nested-object" data-og-internal-id="nested-opaque" data-og-type="text">Nested</Label></Group></Page></body></html>
            """.utf8
        ).write(to: pageHTMLURL)
        try Data(
            """
            <html><body><Canvas data-og-id="component-root" data-og-internal-id="component-root-opaque" data-og-type="page"><Control data-og-id="component-control" data-og-internal-id="control-opaque" data-og-type="button">Control</Control></Canvas></body></html>
            """.utf8
        ).write(to: componentHTMLURL)
        try Data("/* fixture */".utf8).write(to: cssDirectory.appendingPathComponent("OpenGraphite.css"))

        let project = OpenGraphiteProject(
            version: "1",
            name: "Store Reference Fixture",
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
        return CanvasReferenceStoreFixture(
            rootURL: rootURL,
            projectURL: projectURL,
            pageHTMLURL: pageHTMLURL,
            componentHTMLURL: componentHTMLURL
        )
    }

    /// 論理名（日本語）: EditorStoreキャンバス参照Fixture削除関数
    /// 処理概要: テスト用一時project directoryを削除します。
    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
