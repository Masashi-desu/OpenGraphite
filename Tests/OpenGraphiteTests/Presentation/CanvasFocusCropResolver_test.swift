import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: Focusプレビュー切り抜き矩形解決テストスイート
/// 概要: 右クリック時のobject実測矩形が、元page viewport内で安全な単体表示範囲へ変換されることを確認します。
@Suite("Focusプレビュー切り抜き矩形解決テストスイート")
struct CanvasFocusCropResolverTests {
    /// 論理名（日本語）: page全体切り抜き矩形テスト
    /// 概要: page cardから開始したFocusではcanvas全体のoriginal resolutionをそのまま使うことを検証します。
    @Test("page全体の矩形をそのまま返す")
    func testReturnsWholePageRect() {
        // コンディション：1440 x 1200のpage全体をFocus対象にするとき（Given）
        let pageSize = CGSize(width: 1440, height: 1200)

        // 検証内容：page全体に対するFocus切り抜き矩形を解決する（When）
        let cropRect = CanvasFocusCropResolver.cropRect(
            pageSize: pageSize,
            targetRect: CGRect(origin: .zero, size: pageSize)
        )

        // 期待値：page全体の矩形が変更されず返る（Then）
        #expect(cropRect == CGRect(origin: .zero, size: pageSize))
    }

    /// 論理名（日本語）: object実測矩形維持テスト
    /// 概要: page内に収まるobjectは実測document座標と寸法をそのまま使うことを検証します。
    @Test("page内のobject矩形をそのまま返す")
    func testReturnsMeasuredObjectRectInsidePage() {
        // コンディション：1440 x 1200のpage内に320 x 180のobjectがあるとき（Given）
        let targetRect = CGRect(x: 120, y: 240, width: 320, height: 180)

        // 検証内容：Focus切り抜き矩形を解決する（When）
        let cropRect = CanvasFocusCropResolver.cropRect(
            pageSize: CGSize(width: 1440, height: 1200),
            targetRect: targetRect
        )

        // 期待値：object実測矩形が変更されず返る（Then）
        #expect(cropRect == targetRect)
    }

    /// 論理名（日本語）: object切り抜き範囲制限テスト
    /// 概要: object実測矩形がpage外へ広がる場合でも、表示可能なviewport部分だけを返すことを検証します。
    @Test("object実測矩形をpage範囲内へ丸める")
    func testClampsObjectRectToPageViewport() {
        // コンディション：page右下から外へ広がるobject実測矩形があるとき（Given）
        let targetRect = CGRect(x: 900, y: 700, width: 300, height: 300)

        // 検証内容：1000 x 800のpageに対するFocus矩形を解決する（When）
        let cropRect = CanvasFocusCropResolver.cropRect(
            pageSize: CGSize(width: 1000, height: 800),
            targetRect: targetRect
        )

        // 期待値：page内に見える100 x 100の部分だけが返る（Then）
        #expect(cropRect == CGRect(x: 900, y: 700, width: 100, height: 100))
    }

    /// 論理名（日本語）: page外object除外テスト
    /// 概要: pageと交差しない古いobject矩形を単体表示へ使わないことを検証します。
    @Test("page外のobject矩形は使わない")
    func testRejectsObjectRectOutsidePage() {
        // コンディション：page外に完全に離れたobject矩形があるとき（Given）
        let targetRect = CGRect(x: 1600, y: 1400, width: 320, height: 180)

        // 検証内容：1440 x 1200のpageへ切り抜きを試みる（When）
        let cropRect = CanvasFocusCropResolver.cropRect(
            pageSize: CGSize(width: 1440, height: 1200),
            targetRect: targetRect
        )

        // 期待値：表示できない対象としてnilになる（Then）
        #expect(cropRect == nil)
    }

    /// 論理名（日本語）: 無効寸法除外テスト
    /// 概要: 非有限値や0寸法をFocus表示へ渡さないことを検証します。
    @Test("無効なpageまたはobject寸法は拒否する")
    func testRejectsInvalidDimensions() {
        // コンディション：無効なpage寸法とobject寸法を用意する（Given）
        let invalidInputs = [
            (CGSize(width: CGFloat.infinity, height: 1200), CGRect(x: 0, y: 0, width: 10, height: 10)),
            (CGSize(width: 1440, height: 1200), CGRect(x: 0, y: 0, width: 0, height: 10))
        ]

        // 検証内容：各入力でFocus矩形を解決する（When）
        let cropRects = invalidInputs.map { pageSize, targetRect in
            CanvasFocusCropResolver.cropRect(pageSize: pageSize, targetRect: targetRect)
        }

        // 期待値：どちらも無効としてnilになる（Then）
        #expect(cropRects.allSatisfy { $0 == nil })
    }
}

/// 論理名（日本語）: Focusプレビュー倍率解決テストスイート
/// 概要: Focus対象の原寸寸法へcanvas Zoomを適用し、100%が原寸になることを確認します。
@Suite("Focusプレビュー倍率解決テストスイート")
struct CanvasFocusedPreviewScaleResolverTests {
    /// 論理名（日本語）: Focus倍率適用テスト
    /// 概要: 50%、100%、200%が原寸に対して一貫した表示寸法になることを検証します。
    @Test("100%を原寸としてFocus対象を拡大縮小する")
    func testScalesFromOriginalSizeAtOneHundredPercent() {
        // コンディション：原寸320 x 180のFocus対象と3つの倍率があるとき（Given）
        let originalSize = CGSize(width: 320, height: 180)
        let zoomLevels = [0.5, 1.0, 2.0]

        // 検証内容：各倍率の表示寸法を解決する（When）
        let scaledSizes = zoomLevels.map { zoom in
            CanvasFocusedPreviewScaleResolver.scaledSize(
                originalSize: originalSize,
                zoom: zoom
            )
        }

        // 期待値：50%は半分、100%は原寸、200%は2倍になる（Then）
        #expect(scaledSizes == [
            CGSize(width: 160, height: 90),
            originalSize,
            CGSize(width: 640, height: 360)
        ])
    }

    /// 論理名（日本語）: 無効Focus倍率拒否テスト
    /// 概要: 0倍率や非有限な原寸から有限document寸法を生成しないことを検証します。
    @Test("無効な原寸またはZoom倍率を拒否する")
    func testRejectsInvalidScaleInputs() {
        // コンディション：0倍率と非有限幅の原寸を用意する（Given）
        let inputs = [
            (CGSize(width: 320, height: 180), 0.0),
            (CGSize(width: CGFloat.infinity, height: 180), 1.0)
        ]

        // 検証内容：各入力の表示寸法を解決する（When）
        let scaledSizes = inputs.map { originalSize, zoom in
            CanvasFocusedPreviewScaleResolver.scaledSize(
                originalSize: originalSize,
                zoom: zoom
            )
        }

        // 期待値：どちらも不正値としてnilになる（Then）
        #expect(scaledSizes.allSatisfy { $0 == nil })
    }
}

/// 論理名（日本語）: Focus有限プレビューレイアウトテストスイート
/// 概要: Zoom適用後のobjectを中央表示し、overflow分だけ有限scrollできるレイアウト計算を確認します。
@Suite("Focus有限プレビューレイアウトテストスイート")
struct CanvasFocusedPreviewLayoutResolverTests {
    /// 論理名（日本語）: 小object中央配置テスト
    /// 概要: viewportより小さいobjectは中央配置され、scroll rangeを持たないことを検証します。
    @Test("小さいobjectをscrollなしで中央表示する")
    func testCentersSmallObjectWithoutScrollRange() throws {
        // コンディション：1000 x 700 viewportへ320 x 180 objectを表示するとき（Given）
        let viewportSize = CGSize(width: 1000, height: 700)
        let contentSize = CGSize(width: 320, height: 180)

        // 検証内容：有限Focusレイアウトを解決する（When）
        let layout = try #require(
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize
            )
        )

        // 期待値：documentはviewportと同寸でobjectだけが中央へ置かれる（Then）
        #expect(layout.documentSize == viewportSize)
        #expect(layout.contentFrame == CGRect(x: 340, y: 260, width: 320, height: 180))
        #expect(layout.initialScrollOrigin == .zero)
        #expect(layout.scrollRange == .zero)
    }

    /// 論理名（日本語）: 大object有限scrollテスト
    /// 概要: viewportより大きいobjectは等倍を保ち、overflow分だけscroll可能で初期表示が中央になることを検証します。
    @Test("大きいobjectを等倍の中央から有限scrollする")
    func testCentersLargeObjectWithFiniteScrollRange() throws {
        // コンディション：1000 x 700 viewportへ1440 x 1200 objectを表示するとき（Given）
        let viewportSize = CGSize(width: 1000, height: 700)
        let contentSize = CGSize(width: 1440, height: 1200)

        // 検証内容：有限Focusレイアウトを解決する（When）
        let layout = try #require(
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize
            )
        )

        // 期待値：object寸法がdocumentとなり、overflowの半分から表示を始める（Then）
        #expect(layout.documentSize == contentSize)
        #expect(layout.contentFrame == CGRect(origin: .zero, size: contentSize))
        #expect(layout.scrollRange == CGSize(width: 440, height: 500))
        #expect(layout.initialScrollOrigin == CGPoint(x: 220, y: 250))
    }

    /// 論理名（日本語）: 片軸overflowテスト
    /// 概要: 横方向だけ大きいobjectでは横だけscroll可能になることを検証します。
    @Test("overflowした軸だけscroll可能にする")
    func testAllowsScrollOnlyOnOverflowingAxis() throws {
        // コンディション：横だけviewportを超えるobjectを表示するとき（Given）
        let viewportSize = CGSize(width: 900, height: 700)
        let contentSize = CGSize(width: 1200, height: 240)

        // 検証内容：有限Focusレイアウトを解決する（When）
        let layout = try #require(
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize
            )
        )

        // 期待値：横300だけscrollでき、縦は中央配置でscrollしない（Then）
        #expect(layout.scrollRange == CGSize(width: 300, height: 0))
        #expect(layout.contentFrame.origin == CGPoint(x: 0, y: 230))
        #expect(layout.initialScrollOrigin == CGPoint(x: 150, y: 0))
    }

    /// 論理名（日本語）: Zoom中document縮小遅延テスト
    /// 概要: 連続Zoom中は直前の有限document外形を保持し、scroll上限の毎入力クランプを避けることを検証します。
    @Test("Zoom中は有限documentの縮小を遅延する")
    func testRetainsDocumentExtentDuringContinuousZoom() throws {
        // コンディション：1000 x 700 viewportで、直前の1440 x 1200 documentからobjectを縮小した状況を用意する（Given）
        let viewportSize = CGSize(width: 1000, height: 700)
        let contentSize = CGSize(width: 900, height: 600)
        let retainedSize = CGSize(width: 1440, height: 1200)

        // 検証内容：連続Zoom用の保持寸法を指定して有限Focusレイアウトを解決する（When）
        let activeLayout = try #require(
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize,
                retainedDocumentSize: retainedSize
            )
        )
        let settledLayout = try #require(
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize
            )
        )

        // 期待値：操作中は外形を保持し、入力終了後は必要なviewport寸法へ収束できる（Then）
        #expect(activeLayout.documentSize == retainedSize)
        #expect(activeLayout.contentFrame == CGRect(x: 270, y: 300, width: 900, height: 600))
        #expect(settledLayout.documentSize == viewportSize)
        #expect(settledLayout.scrollRange == .zero)
    }

    /// 論理名（日本語）: 無効Focusレイアウト寸法テスト
    /// 概要: 0または非有限寸法から有限documentを生成しないことを検証します。
    @Test("無効なviewportまたはobject寸法を拒否する")
    func testRejectsInvalidLayoutDimensions() {
        // コンディション：0 viewportと非有限objectを用意する（Given）
        let inputs = [
            (CGSize(width: 0, height: 700), CGSize(width: 320, height: 180)),
            (CGSize(width: 1000, height: 700), CGSize(width: CGFloat.infinity, height: 180))
        ]

        // 検証内容：各入力の有限Focusレイアウトを解決する（When）
        let layouts = inputs.map { viewportSize, contentSize in
            CanvasFocusedPreviewLayoutResolver.layout(
                viewportSize: viewportSize,
                contentSize: contentSize
            )
        }

        // 期待値：どちらもnilになる（Then）
        #expect(layouts.allSatisfy { $0 == nil })
    }
}
