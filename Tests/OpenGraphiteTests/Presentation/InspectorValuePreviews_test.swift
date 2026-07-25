import AppKit
import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクター値プレビュー関連のテストスイート
/// 概要: 角丸、グラデーション、文字組みの読み取り専用プレビューが CSS 値を正しく表示寸法へ換算することを確認します。
@Suite("インスペクター値プレビュー関連のテストスイート")
struct InspectorValuePreviewsTests {
    /// 論理名（日本語）: 数値大きさ抽出テスト
    /// 概要: 単位付き値と編集対象外値から、プレビュー計算に使う数値が取り出せることを検証します。
    @Test("CSS値からプレビュー計算に使う数値を取り出せる")
    func testNumericMagnitude() {
        // コンディション：単位付き値、負値、関数値を用意する（Given）
        let lengthValue = "24px"
        let negativeValue = "-12px"
        let functionValue = "calc(100% - 8px)"

        // 検証内容：プレビューに使う数値の大きさを取り出す（When）
        let lengthMagnitude = InspectorValuePreviewGeometry.numericMagnitude(lengthValue)
        let negativeMagnitude = InspectorValuePreviewGeometry.numericMagnitude(negativeValue)
        let functionMagnitude = InspectorValuePreviewGeometry.numericMagnitude(functionValue)

        // 期待値：単位を除いた絶対値が得られ、関数値は 0 として扱われる（Then）
        #expect(lengthMagnitude == 24)
        #expect(negativeMagnitude == 12)
        #expect(functionMagnitude == 0)
    }

    /// 論理名（日本語）: 角丸プレビュー換算テスト
    /// 概要: px 指定と `%` 指定がプレビュー矩形に収まる半径へ換算されることを検証します。
    @Test("角丸値がプレビュー矩形に収まる半径へ換算される")
    func testPreviewRadii() {
        // コンディション：px 指定、大きすぎる px 指定、`%` 指定、未設定を用意する（Given）
        let previewSize = CGSize(width: 42, height: 26)

        // 検証内容：4 隅の表示半径を求める（When）
        let radii = InspectorValuePreviewGeometry.previewRadii(
            topLeading: "24px",
            topTrailing: "999px",
            bottomTrailing: "50%",
            bottomLeading: "",
            size: previewSize
        )

        // 期待値：上限は矩形の半分に収まり、未設定は 0、`50%` は上限まで丸まる（Then）
        let limit = min(previewSize.width, previewSize.height) / 2
        #expect(radii.topLeading > 0)
        #expect(radii.topLeading < limit)
        #expect(radii.topTrailing == limit)
        #expect(radii.bottomTrailing == limit)
        #expect(radii.bottomLeading == 0)
    }

    /// 論理名（日本語）: グラデーション停止位置テスト
    /// 概要: 位置未指定の color stop が等間隔へ割り当てられることを検証します。
    @Test("位置未指定のcolor stopは等間隔へ割り当てられる")
    func testGradientRampLocations() {
        // コンディション：位置指定ありと未指定の stop を混在させる（Given）
        let stops = [
            CSSGradientStopValue(color: "#000000", position: ""),
            CSSGradientStopValue(color: "#888888", position: "30%"),
            CSSGradientStopValue(color: "#ffffff", position: "")
        ]

        // 検証内容：プレビュー帯上の停止位置を求める（When）
        let locations = InspectorGradientRamp.normalizedLocations(stops)

        // 期待値：`%` 指定はその値、未指定は等間隔になる（Then）
        #expect(locations == [0, 0.3, 1])
    }

    /// 論理名（日本語）: グラデーション連続未指定位置補間テスト
    /// 概要: 連続する位置未指定 stop が、前後の明示位置の間へ均等に補間されることを検証します。
    @Test("連続する未指定color stopは前後の明示位置間へ均等配置される")
    func testGradientRampInterpolatesUnspecifiedRuns() {
        // コンディション：20% と 80% の間に 2 つの位置未指定 stop を置く（Given）
        let stops = [
            CSSGradientStopValue(color: "#000000", position: "20%"),
            CSSGradientStopValue(color: "#333333", position: ""),
            CSSGradientStopValue(color: "#666666", position: ""),
            CSSGradientStopValue(color: "#999999", position: "80%"),
            CSSGradientStopValue(color: "#ffffff", position: "")
        ]

        // 検証内容：プレビュー帯上の停止位置を求める（When）
        let locations = InspectorGradientRamp.normalizedLocations(stops)

        // 期待値：中間 stop は 40% と 60%、末尾未指定は 100% になる（Then）
        let expectedLocations = [0.2, 0.4, 0.6, 0.8, 1.0]
        #expect(locations.count == expectedLocations.count)
        for (location, expectedLocation) in zip(locations, expectedLocations) {
            #expect(abs(location - expectedLocation) < 0.000_001)
        }
    }

    /// 論理名（日本語）: 文字組みプレビュー換算テスト
    /// 概要: font-size、font-weight、letter-spacing が見本描画用の値へ換算されることを検証します。
    @Test("文字組みの指定が見本描画用の値へ換算される")
    func testTypographyPreviewModel() {
        // コンディション：rem 指定の文字サイズと数値指定の太さ、em 指定の字送りを用意する（Given）
        let fontSize = "1.5rem"
        let hugeFontSize = "120px"
        let fontWeight = "700"
        let letterSpacing = "0.1em"

        // 検証内容：見本描画用の値へ換算する（When）
        let previewFontSize = InspectorTypographyPreviewModel.previewFontSize(from: fontSize)
        let clampedFontSize = InspectorTypographyPreviewModel.previewFontSize(from: hugeFontSize)
        let previewWeight = InspectorTypographyPreviewModel.nsFontWeight(from: fontWeight)
        let previewTracking = InspectorTypographyPreviewModel.tracking(from: letterSpacing, fontSize: 20)

        // 期待値：rem は px 換算、大きすぎる値は上限で止まり、太さと字送りが対応する（Then）
        #expect(previewFontSize == 24)
        #expect(clampedFontSize == InspectorTypographyPreviewModel.maximumPreviewFontSize)
        #expect(previewWeight == NSFont.Weight.bold)
        #expect(previewTracking == 2)
    }

    /// 論理名（日本語）: 行間換算テスト
    /// 概要: 倍率指定と px 指定の `line-height` が見本の行間へ換算されることを検証します。
    @Test("line-heightが見本の行間へ換算される")
    func testTypographyLineSpacing() {
        // コンディション：倍率指定と px 指定、文字サイズより小さい指定を用意する（Given）
        let ratioValue = "1.5"
        let pixelValue = "30px"
        let tightValue = "10px"

        // 検証内容：文字サイズ 20 の見本に対する行間を求める（When）
        let ratioSpacing = InspectorTypographyPreviewModel.lineSpacing(from: ratioValue, fontSize: 20)
        let pixelSpacing = InspectorTypographyPreviewModel.lineSpacing(from: pixelValue, fontSize: 20)
        let tightSpacing = InspectorTypographyPreviewModel.lineSpacing(from: tightValue, fontSize: 20)

        // 期待値：行高から文字サイズを引いた値になり、負にはならない（Then）
        #expect(ratioSpacing == 10)
        #expect(pixelSpacing == 10)
        #expect(tightSpacing == 0)
    }

    /// 論理名（日本語）: rem文字組み換算テスト
    /// 概要: `letter-spacing` と `line-height` の rem が現在の文字サイズではなく root 基準で換算されることを検証します。
    @Test("文字組みのrem指定はroot文字サイズを基準に換算される")
    func testTypographyRemValuesUseRootFontSize() {
        // コンディション：見本文字サイズ 20pt に rem 指定の字送りと行高を用意する（Given）
        let fontSize: CGFloat = 20

        // 検証内容：字送りと行間を見本描画用の値へ換算する（When）
        let tracking = InspectorTypographyPreviewModel.tracking(from: "0.125rem", fontSize: fontSize)
        let lineSpacing = InspectorTypographyPreviewModel.lineSpacing(from: "1.5rem", fontSize: fontSize)

        // 期待値：root 16pt を基準に 2pt の字送りと 4pt の行間になる（Then）
        #expect(tracking == 2)
        #expect(lineSpacing == 4)
    }
}
