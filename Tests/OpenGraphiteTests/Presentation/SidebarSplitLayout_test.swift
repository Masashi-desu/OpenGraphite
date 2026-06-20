import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: サイドバー分割レイアウト関連のテストスイート
/// 概要: 左カラムの Chapter / Collection と HTML ペインの初期比率、保存比率、折りたたみ時の高さ解決を確認します。
@Suite("サイドバー分割レイアウト関連のテストスイート")
struct SidebarSplitLayoutTests {
    /// 論理名（日本語）: サイドバー初期分割比率テスト
    /// 概要: 初期表示時に上段と下段が 3:7 に近い高さへ解決されることを検証します。
    @Test("初期分割比率は3対7になる")
    func testResolveUsesThreeToSevenInitialRatio() {
        // コンディション：divider を除いた展開領域が 600pt になる高さを用意する（Given）
        let availableHeight: CGFloat = 610

        // 検証内容：初期比率 0.3 で展開中の上下ペイン高さを解決する（When）
        let layout = SidebarSplitLayout.resolve(
            availableHeight: availableHeight,
            isGroupCollapsed: false,
            isContentCollapsed: false,
            groupFraction: 0.3
        )

        // 期待値：上段が 180pt、下段が 420pt になり、3:7 の初期表示になる（Then）
        #expect(layout.showsDivider)
        #expect(layout.groupHeight == 180)
        #expect(layout.contentHeight == 420)
    }

    /// 論理名（日本語）: サイドバー分割比率保存テスト
    /// 概要: drag 後の上段高さが比率化され、再解決時に同じ高さへ戻ることを検証します。
    @Test("ユーザーが動かした分割比率を再利用できる")
    func testFractionForGroupHeightRestoresDraggedHeight() {
        // コンディション：divider を除いた展開領域 600pt のうち上段 300pt へ drag した状態を用意する（Given）
        let availableHeight: CGFloat = 610

        // 検証内容：上段高さを保存比率へ変換し、その比率で再度レイアウトを解決する（When）
        let fraction = SidebarSplitLayout.fraction(forGroupHeight: 300, availableHeight: availableHeight)
        let layout = SidebarSplitLayout.resolve(
            availableHeight: availableHeight,
            isGroupCollapsed: false,
            isContentCollapsed: false,
            groupFraction: fraction
        )

        // 期待値：保存比率から上段 300pt / 下段 300pt のユーザー設定が復元される（Then）
        #expect(fraction == 0.5)
        #expect(layout.groupHeight == 300)
        #expect(layout.contentHeight == 300)
    }

    /// 論理名（日本語）: サイドバー折りたたみ高さテスト
    /// 概要: 上段が折りたたまれた場合にヘッダー高さだけを残し、下段が残りを使うことを検証します。
    @Test("上段折りたたみ時は下段が残り高さを使う")
    func testResolveCollapsedGroupUsesRemainingHeightForContent() {
        // コンディション：上段だけを折りたたみ、下段は展開した状態を用意する（Given）
        let availableHeight: CGFloat = 610

        // 検証内容：折りたたみ状態を含めて上下ペイン高さを解決する（When）
        let layout = SidebarSplitLayout.resolve(
            availableHeight: availableHeight,
            isGroupCollapsed: true,
            isContentCollapsed: false,
            groupFraction: 0.3
        )

        // 期待値：上段はヘッダー高さ 34pt、下段は divider を除いた残り 566pt になる（Then）
        #expect(layout.showsDivider)
        #expect(layout.groupHeight == 34)
        #expect(layout.contentHeight == 566)
    }

    /// 論理名（日本語）: サイドバー分割比率制限テスト
    /// 概要: 保存済み比率が異常値や極端な値でも安全な範囲へ丸められることを検証します。
    @Test("分割比率は安全な範囲へ丸められる")
    func testClampedFractionHandlesInvalidAndExtremeValues() {
        // コンディション：非数値、下限未満、上限超過の比率を用意する（Given）
        let invalidFraction = Double.nan
        let tooSmallFraction = 0.02
        let tooLargeFraction = 1.2

        // 検証内容：それぞれ保存可能な分割比率へ丸める（When）
        let invalidResult = SidebarSplitLayout.clampedFraction(invalidFraction)
        let tooSmallResult = SidebarSplitLayout.clampedFraction(tooSmallFraction)
        let tooLargeResult = SidebarSplitLayout.clampedFraction(tooLargeFraction)

        // 期待値：異常値は初期値、極端な値は下限または上限へ補正される（Then）
        #expect(invalidResult == 0.3)
        #expect(tooSmallResult == 0.1)
        #expect(tooLargeResult == 0.9)
    }
}
