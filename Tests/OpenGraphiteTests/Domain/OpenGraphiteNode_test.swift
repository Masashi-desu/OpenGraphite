import Testing
@testable import OpenGraphite

/// 論理名（日本語）: OpenGraphiteノード関連のテストスイート
/// 概要: HTML DOM から抽出された編集ノードの表示用メタ情報を確認します。
@Suite("OpenGraphiteノード関連のテストスイート")
struct OpenGraphiteNodeTests {
    /// 論理名（日本語）: ノード詳細行の基本表示テスト
    /// 概要: 種別、レイアウト、ロールが順番通りに表示されることを検証します。
    @Test("ノード詳細行を構成できる")
    func testDetailLineWithLayoutAndRole() {
        // コンディション：layout と role を持つフレームノードを用意する
        let node = OpenGraphiteNode(
            id: "hero",
            tagName: "herosection",
            type: "frame",
            layout: "vertical",
            role: "landing-hero",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：詳細行を取得する
        let detailLine = node.detailLine

        // 期待値：type、layout、role が区切り文字付きで並ぶ
        #expect(detailLine == "frame · vertical · landing-hero")
    }

    /// 論理名（日本語）: ノード状態表示テスト
    /// 概要: hidden と locked の状態が詳細行へ含まれることを検証します。
    @Test("ノード状態を詳細行へ含める")
    func testDetailLineIncludesHiddenAndLockedState() {
        // コンディション：非表示かつロックされたテキストノードを用意する
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: true,
            isLocked: true,
            depth: 1
        )

        // 検証内容：詳細行を取得する
        let detailLine = node.detailLine

        // 期待値：type に続いて hidden と locked が表示される
        #expect(detailLine == "text · hidden · locked")
    }
}
