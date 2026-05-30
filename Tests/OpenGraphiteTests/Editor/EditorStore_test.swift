import Testing
import Foundation
@testable import OpenGraphite

/// 論理名（日本語）: エディターストア関連のテストスイート
/// 概要: DOM payload の取り込み、選択解除、CSS 変数 mutation の状態更新を確認します。
@MainActor
@Suite("エディターストア関連のテストスイート")
struct EditorStoreTests {
    /// 論理名（日本語）: DOM payload 取り込みテスト
    /// 概要: JavaScript から渡された辞書配列が OpenGraphiteNode に変換されることを検証します。
    @Test("DOM payloadをノード一覧へ変換できる")
    func testIngestNodePayloadCreatesNodes() {
        // コンディション：data-og-id を持つ DOM payload を用意する
        let store = EditorStore()
        let payload: [[String: Any]] = [
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "layout": "horizontal",
                "role": "landing-hero",
                "cssVariables": ["--og-gap": "32px"],
                "hidden": false,
                "locked": true,
                "depth": 1
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：ノードの基本情報と CSS 変数が保持される
        #expect(store.nodes.count == 1)
        #expect(store.nodes[0].id == "hero")
        #expect(store.nodes[0].layout == "horizontal")
        #expect(store.nodes[0].role == "landing-hero")
        #expect(store.nodes[0].cssVariables["--og-gap"] == "32px")
        #expect(store.nodes[0].isLocked == true)
    }

    /// 論理名（日本語）: 存在しない選択解除テスト
    /// 概要: 再取り込み後に選択中ノードが存在しない場合、選択が解除されることを検証します。
    @Test("再取り込み後に存在しない選択を解除する")
    func testIngestNodePayloadClearsMissingSelection() {
        // コンディション：選択済みノードとは別の DOM payload を用意する
        let store = EditorStore()
        store.selectNode(id: "old-node")
        let payload: [[String: Any]] = [
            [
                "id": "new-node",
                "tagName": "frame",
                "type": "frame",
                "depth": 0
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：存在しない old-node の選択が解除される
        #expect(store.selectedNodeID == nil)
    }

    /// 論理名（日本語）: CSS変数更新テスト
    /// 概要: 選択中ノードの CSS 変数更新と mutation 発行を検証します。
    @Test("CSS変数更新でノードとmutationを更新する")
    func testUpdateCSSVariableMutatesSelectedNode() {
        // コンディション：選択中ノードを持つストアを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["--og-gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：CSS 変数を空白付きの値で更新する
        store.updateCSSVariable(key: "--og-gap", value: " 32px ")

        // 期待値：値は trim され、WebView 反映用 mutation が発行される
        #expect(store.nodes[0].cssVariables["--og-gap"] == "32px")
        #expect(store.cssMutation?.nodeID == "hero")
        #expect(store.cssMutation?.key == "--og-gap")
        #expect(store.cssMutation?.value == "32px")
    }

    /// 論理名（日本語）: CSS変数同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ CSS 値の mutation が増えないことを検証します。
    @Test("同じCSS変数値の再適用ではmutationを発行しない")
    func testUpdateCSSVariableSkipsUnchangedValue() {
        // コンディション：既存 CSS 変数を持つ選択中ノードを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["--og-gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：同じ値を空白付きで再適用する
        store.updateCSSVariable(key: "--og-gap", value: " 16px ")

        // 期待値：値は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].cssVariables["--og-gap"] == "16px")
        #expect(store.cssMutation == nil)
    }

    /// 論理名（日本語）: ノード属性同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ属性値の mutation が増えないことを検証します。
    @Test("同じノード属性値の再適用ではmutationを発行しない")
    func testUpdateNodeAttributeSkipsUnchangedValue() {
        // コンディション：role を持つ選択中ノードを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "maintitle",
                "type": "text",
                "role": "title",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：同じ role を空白付きで再適用する
        store.updateNodeAttribute(name: "data-og-role", value: " title ")

        // 期待値：属性は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].role == "title")
        #expect(store.attributeMutation == nil)
    }

    /// 論理名（日本語）: 複合CSS変数更新テスト
    /// 概要: CSS shorthand や関数値を分解せず、HTML 正本へ戻す値としてそのまま保持することを検証します。
    @Test("複合CSS値をStoreで正規化しすぎずmutationへ渡せる")
    func testUpdateCSSVariablePreservesStructuredCSSValues() {
        // コンディション：選択中ノードと、Inspector UI が parse / edit / serialize する CSS 値を用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "preview-card",
                "tagName": "editorpreview",
                "type": "frame",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "preview-card")
        let cases: [(key: String, value: String)] = [
            ("--og-width", "min(100%,560px)"),
            ("--og-padding", "14px 20px"),
            ("--og-background", "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)"),
            ("--og-flex", "1 1 0")
        ]

        // 検証内容：各 CSS 値を Store に適用する
        for item in cases {
            store.updateCSSVariable(key: item.key, value: item.value)

            // 期待値：Store は CSS 値を分解・独自正規化せず、そのまま mutation とノード状態へ保持する
            #expect(store.nodes[0].cssVariables[item.key] == item.value)
            #expect(store.cssMutation?.nodeID == "preview-card")
            #expect(store.cssMutation?.key == item.key)
            #expect(store.cssMutation?.value == item.value)
        }
    }

    /// 論理名（日本語）: 同期履歴ディスク反映テスト
    /// 概要: HTML 同期履歴の取り消し・やり直しがディスク内容と WebView 置換要求へ反映されることを検証します。
    @Test("同期履歴の取り消しとやり直しをディスクへ反映する")
    func testUndoRedoDocumentSyncReflectsDiskAndReplacementRequest() throws {
        // コンディション：一時プロジェクトを開き、HTML を二回同期する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        store.syncCurrentHTML("<!doctype html>\n<html><body>first</body></html>")
        store.syncCurrentHTML("<!doctype html>\n<html><body>second</body></html>")

        // 検証内容：取り消しを実行する
        store.undoDocumentChange()
        let undoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が一つ前の同期スナップショットになる
        #expect(undoDiskHTML == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.canRedo == true)

        guard let undoSequence = store.documentReplacementRequest?.sequence else {
            Issue.record("取り消し後の置換要求がありません。")
            return
        }
        store.markDocumentReplacementApplied(sequence: undoSequence)

        // 検証内容：やり直しを実行する
        store.redoDocumentChange()
        let redoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が取り消し前の同期スナップショットになる
        #expect(redoDiskHTML == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.canRedo == false)
    }
}

/// 論理名（日本語）: エディターストア履歴テストfixture
/// 概要: 一時ディレクトリに `.ogp` と HTML を作成し、同期履歴テスト用のプロジェクトを提供します。
private struct EditorStoreHistoryFixture {
    let rootURL: URL
    let projectURL: URL
    let htmlURL: URL

    /// 論理名（日本語）: エディターストア履歴fixture初期化関数
    /// 処理概要: 一時ルート、public ディレクトリ、HTML、`.ogp` を作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteEditorStoreHistory-\(UUID().uuidString)")
        let publicURL = rootURL.appendingPathComponent("public")
        projectURL = rootURL.appendingPathComponent("Project.ogp")
        htmlURL = publicURL.appendingPathComponent("index.html")

        try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
        try "<!doctype html>\n<html><body>initial</body></html>".write(
            to: htmlURL,
            atomically: true,
            encoding: .utf8
        )

        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL)
    }

    /// 論理名（日本語）: fixture削除関数
    /// 処理概要: テストで作成した一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
