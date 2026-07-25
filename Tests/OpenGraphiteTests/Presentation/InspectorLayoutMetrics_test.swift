import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクターレイアウトメトリクス関連のテストスイート
/// 概要: Inspector 幅が入力欄の見切れない下限を確保しつつ、Canvas を過度に覆わないことを確認します。
@Suite("インスペクターレイアウトメトリクス関連のテストスイート")
struct InspectorLayoutMetricsTests {
    /// 論理名（日本語）: 最小ウインドウ幅下限確保テスト
    /// 概要: ウインドウ最小幅と左カラム表示時でも、Inspector が下限幅を下回らないことを検証します。
    @Test("ウインドウ最小幅でもInspectorは下限幅を下回らない")
    func testResolvedWidthKeepsMinimumWidth() {
        // コンディション：ウインドウ最小幅 960 で左カラム 296 が表示されている状態を用意する（Given）
        let availableWindowWidth: CGFloat = 960
        let leadingColumnWidth: CGFloat = 296

        // 検証内容：Inspector 幅を解決する（When）
        let resolvedWidth = InspectorLayoutMetrics.resolvedWidth(
            availableWindowWidth: availableWindowWidth,
            leadingColumnWidth: leadingColumnWidth
        )

        // 期待値：比率だけで決めた幅より広く、下限幅と一致する（Then）
        let proportionalWidth = (availableWindowWidth - leadingColumnWidth) * InspectorLayoutMetrics.maximumRemainingWidthFraction
        #expect(proportionalWidth < InspectorLayoutMetrics.minimumWidth)
        #expect(resolvedWidth == InspectorLayoutMetrics.minimumWidth)
    }

    /// 論理名（日本語）: 広いウインドウ幅上限テスト
    /// 概要: 十分に広いウインドウでも Inspector が推奨幅を超えないことを検証します。
    @Test("広いウインドウでもInspectorは推奨幅を超えない")
    func testResolvedWidthKeepsPreferredWidthAsUpperBound() {
        // コンディション：左カラムを隠した広いウインドウを用意する（Given）
        let availableWindowWidth: CGFloat = 2400

        // 検証内容：Inspector 幅を解決する（When）
        let resolvedWidth = InspectorLayoutMetrics.resolvedWidth(
            availableWindowWidth: availableWindowWidth,
            leadingColumnWidth: 0
        )

        // 期待値：推奨幅で頭打ちになる（Then）
        #expect(resolvedWidth == InspectorLayoutMetrics.preferredWidth)
    }

    /// 論理名（日本語）: 残り幅不足時テスト
    /// 概要: 残り幅が下限幅に満たない場合、残り幅を超えて広がらないことを検証します。
    @Test("残り幅が下限に満たない場合は残り幅を超えて広がらない")
    func testResolvedWidthNeverExceedsRemainingWidth() {
        // コンディション：左カラムでほとんどの幅が埋まった状態を用意する（Given）
        let availableWindowWidth: CGFloat = 400
        let leadingColumnWidth: CGFloat = 296

        // 検証内容：Inspector 幅を解決する（When）
        let resolvedWidth = InspectorLayoutMetrics.resolvedWidth(
            availableWindowWidth: availableWindowWidth,
            leadingColumnWidth: leadingColumnWidth
        )

        // 期待値：残り幅と一致し、下限幅を超えて広がらない（Then）
        #expect(resolvedWidth == availableWindowWidth - leadingColumnWidth)
        #expect(resolvedWidth < InspectorLayoutMetrics.minimumWidth)
    }

    /// 論理名（日本語）: 幅ゼロ時テスト
    /// 概要: 残り幅がない場合に 0 を返すことを検証します。
    @Test("残り幅がない場合はInspector幅が0になる")
    func testResolvedWidthWithoutRemainingWidth() {
        // コンディション：左カラムがウインドウ幅を埋め切った状態を用意する（Given）
        let availableWindowWidth: CGFloat = 296

        // 検証内容：Inspector 幅を解決する（When）
        let resolvedWidth = InspectorLayoutMetrics.resolvedWidth(
            availableWindowWidth: availableWindowWidth,
            leadingColumnWidth: 296
        )

        // 期待値：0 になる（Then）
        #expect(resolvedWidth == 0)
    }
}
