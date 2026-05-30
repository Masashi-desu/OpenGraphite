import Testing
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
}
