import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスwindow frame解決テストスイート
/// 概要: Canvas の window 座標 frame 群から入力位置に対応する最前面候補を選ぶ挙動を検証します。
@Suite("キャンバスwindow frame解決テストスイート")
struct CanvasWindowFrameResolverTests {
    /// 論理名（日本語）: 最前面frame優先テスト
    /// 概要: 複数 frame が重なる場合は描画順で最前面の index を返すことを検証します。
    @Test("重なったframeでは最前面のindexを返す")
    func testTopmostFrameIndexUsesLastMatchingFrame() {
        // コンディション：同じ入力点を含む背面と前面の frame を用意する（Given）
        let frames = [
            CGRect(x: 0, y: 0, width: 120, height: 120),
            CGRect(x: 40, y: 40, width: 120, height: 120)
        ]
        let windowPoint = CGPoint(x: 80, y: 80)

        // 検証内容：入力点に対応する frame index を解決する（When）
        let index = CanvasWindowFrameResolver.topmostFrameIndex(
            containing: windowPoint,
            frames: frames
        )

        // 期待値：描画順で後ろにある前面 frame が選ばれる（Then）
        #expect(index == 1)
    }

    /// 論理名（日本語）: frame非包含テスト
    /// 概要: 入力点を含む frame がない場合は候補なしになることを検証します。
    @Test("入力点を含むframeがなければnilを返す")
    func testTopmostFrameIndexReturnsNilOutsideFrames() {
        // コンディション：入力点から離れた frame 群を用意する（Given）
        let frames = [
            CGRect(x: 0, y: 0, width: 120, height: 120),
            CGRect(x: 160, y: 160, width: 120, height: 120)
        ]
        let windowPoint = CGPoint(x: 140, y: 140)

        // 検証内容：入力点に対応する frame index を解決する（When）
        let index = CanvasWindowFrameResolver.topmostFrameIndex(
            containing: windowPoint,
            frames: frames
        )

        // 期待値：どの frame にも含まれないため候補なしになる（Then）
        #expect(index == nil)
    }
}
