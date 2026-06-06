import Testing
@testable import OpenGraphite

/// 論理名（日本語）: ページキャンバスアスペクト比関連のテストスイート
/// 概要: Canvas の W/H ロックで使う比率計算を検証します。
@Suite("ページキャンバスアスペクト比関連のテストスイート")
struct PageCanvasAspectRatioTests {
    /// 論理名（日本語）: 幅基準高さ算出テスト
    /// 概要: 固定比率を保持したまま width から height を算出できることを検証します。
    @Test("widthからheightを比率通りに算出できる")
    func testHeightForWidthKeepsRatio() throws {
        // コンディション：16:9 のアスペクト比を用意する（Given）
        let ratio = try #require(PageCanvasAspectRatio(width: 1920, height: 1080))

        // 検証内容：width を半分にした場合の height を算出する（When）
        let height = ratio.height(forWidth: 960)

        // 期待値：height も同じ比率で半分になる（Then）
        #expect(height == 540)
    }

    /// 論理名（日本語）: 高さ基準幅算出テスト
    /// 概要: 固定比率を保持したまま height から width を算出できることを検証します。
    @Test("heightからwidthを比率通りに算出できる")
    func testWidthForHeightKeepsRatio() throws {
        // コンディション：4:3 のアスペクト比を用意する（Given）
        let ratio = try #require(PageCanvasAspectRatio(width: 1200, height: 900))

        // 検証内容：height を 450 にした場合の width を算出する（When）
        let width = ratio.width(forHeight: 450)

        // 期待値：width は 600 になる（Then）
        #expect(width == 600)
    }

    /// 論理名（日本語）: 無効キャンバス比率拒否テスト
    /// 概要: 0 以下や非有限値の寸法からアスペクト比を生成しないことを検証します。
    @Test("無効な寸法からアスペクト比を作らない")
    func testInvalidDimensionsDoNotCreateRatio() {
        // コンディション：0 や非有限値を含む寸法を用意する（Given）
        let zeroWidth = PageCanvasAspectRatio(width: 0, height: 800)
        let infiniteHeight = PageCanvasAspectRatio(width: 800, height: .infinity)

        // 検証内容：アスペクト比の生成結果を確認する（When）
        let ratios = [zeroWidth, infiniteHeight]

        // 期待値：いずれも生成されない（Then）
        #expect(ratios.allSatisfy { $0 == nil })
    }
}
