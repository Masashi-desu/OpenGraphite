import Testing
@testable import OpenGraphite

/// 論理名（日本語）: サイドバーHTML展開状態関連のテストスイート
/// 概要: 左カラムの HTML カード展開状態がキャンバス側のページ選択と同期されることを確認します。
@Suite("サイドバーHTML展開状態関連のテストスイート")
struct SidebarPageExpansionStateTests {
    /// 論理名（日本語）: 選択解除時の展開状態解除テスト
    /// 概要: キャンバス側でページ選択を解除したとき、左カラムの展開状態も解除されることを検証します。
    @Test("ページ選択解除で展開状態も解除する")
    func testSynchronizeSelectionClearsExpandedPageWhenSelectionIsNil() {
        // コンディション：home カードが展開中の状態を用意する（Given）
        var state = SidebarPageExpansionState(expandedPageID: "home")

        // 検証内容：キャンバス側の選択解除を同期する（When）
        state.synchronizeSelection(selectedPageID: nil, validPageIDs: Set(["home", "docs"]))

        // 期待値：展開中 page ID も nil になる（Then）
        #expect(state.expandedPageID == nil)
    }

    /// 論理名（日本語）: 選択HTML展開同期テスト
    /// 概要: 有効な選択 page ID が渡されたとき、対応するカードが展開対象になることを検証します。
    @Test("選択ページに展開状態を同期する")
    func testSynchronizeSelectionExpandsSelectedPage() {
        // コンディション：未展開のサイドバー状態を用意する（Given）
        var state = SidebarPageExpansionState()

        // 検証内容：docs ページの選択を同期する（When）
        state.synchronizeSelection(selectedPageID: "docs", validPageIDs: Set(["home", "docs"]))

        // 期待値：docs カードが展開対象として保存される（Then）
        #expect(state.expandedPageID == "docs")
        #expect(state.isExpanded(pageID: "docs") == true)
    }

    /// 論理名（日本語）: 無効HTML選択の展開状態解除テスト
    /// 概要: 現在のパネルに存在しない page ID が選択として渡されたとき、残った展開状態が解除されることを検証します。
    @Test("現在パネルにない選択では展開状態を解除する")
    func testSynchronizeSelectionClearsExpandedPageWhenSelectionIsInvalid() {
        // コンディション：home カードが展開中で、別パネルの page ID が選択された状態を想定する（Given）
        var state = SidebarPageExpansionState(expandedPageID: "home")

        // 検証内容：現在のパネルに存在しない component-card の選択を同期する（When）
        state.synchronizeSelection(selectedPageID: "component-card", validPageIDs: Set(["home", "docs"]))

        // 期待値：左カラムには対応カードがないため展開状態が解除される（Then）
        #expect(state.expandedPageID == nil)
    }
}
