import CoreGraphics
import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスZoom段階調整テストスイート
/// 概要: HUD操作で100%原寸倍率を飛び越えず、拡大縮小の途中で確実に選択できることを確認します。
@Suite("キャンバスZoom段階調整テストスイート")
struct CanvasZoomStepTests {
    /// 論理名（日本語）: 100%原寸スナップテスト
    /// 概要: 100%を跨ぐ拡大・縮小操作が一度原寸倍率へ揃うことを検証します。
    @Test("100%を跨ぐZoom操作は原寸倍率へスナップする")
    func testSnapsAcrossOriginalScale() {
        // コンディション：100%の直前と直後にある倍率を用意する（Given）
        let belowOriginal = 0.92
        let aboveOriginal = 1.08

        // 検証内容：10%ずつ拡大・縮小する（When）
        let zoomedIn = CanvasZoom.stepped(belowOriginal, by: CanvasZoom.buttonStep)
        let zoomedOut = CanvasZoom.stepped(aboveOriginal, by: -CanvasZoom.buttonStep)

        // 期待値：どちらも100%原寸倍率へ揃う（Then）
        #expect(zoomedIn == CanvasZoom.originalScale)
        #expect(zoomedOut == CanvasZoom.originalScale)
    }

    /// 論理名（日本語）: 100%から通常段階継続テスト
    /// 概要: 原寸倍率から次の操作では通常どおり10%拡大縮小できることを検証します。
    @Test("100%からは通常のZoom段階を継続する")
    func testContinuesStepAfterOriginalScale() {
        // コンディション：現在倍率が100%のとき（Given）
        let originalScale = CanvasZoom.originalScale

        // 検証内容：10%ずつ拡大・縮小する（When）
        let zoomedIn = CanvasZoom.stepped(originalScale, by: CanvasZoom.buttonStep)
        let zoomedOut = CanvasZoom.stepped(originalScale, by: -CanvasZoom.buttonStep)

        // 期待値：110%と90%へ進む（Then）
        #expect(abs(zoomedIn - 1.1) < 0.000_001)
        #expect(abs(zoomedOut - 0.9) < 0.000_001)
    }
}

/// 論理名（日本語）: キャンバスZoom入力解決テストスイート
/// 概要: 通常canvasとFocus表示が共有するCommandスクロールとピンチの倍率計算を確認します。
@Suite("キャンバスZoom入力解決テストスイート")
struct CanvasZoomInputResolverTests {
    /// 論理名（日本語）: precise差分優先テスト
    /// 概要: trackpad由来のprecise差分を優先し、値がない場合だけlegacy差分へfallbackすることを検証します。
    @Test("precise差分を優先してlegacy差分へfallbackする")
    func testSelectsPreciseDeltaWithLegacyFallback() {
        // コンディション：preciseとlegacyの両方を持つ入力、およびpreciseが0の入力がある（Given）
        let preciseInput = CanvasZoomInputResolver.scrollDelta(
            precise: 12,
            legacy: 3,
            hasPreciseScrollingDeltas: true
        )
        let fallbackInput = CanvasZoomInputResolver.scrollDelta(
            precise: 0,
            legacy: 3,
            hasPreciseScrollingDeltas: true
        )

        // 検証内容：共有resolverが採用した差分を取得する（When）
        let results = [preciseInput, fallbackInput]

        // 期待値：最初はprecise 12、次はlegacy 3を採用する（Then）
        #expect(results[0].value == 12)
        #expect(results[0].isPrecise)
        #expect(results[1].value == 3)
        #expect(!results[1].isPrecise)
    }

    /// 論理名（日本語）: 共通Zoom係数テスト
    /// 概要: preciseとlegacyのscroll差分が通常canvasとFocusで共有する指数係数へ変換されることを検証します。
    @Test("preciseとlegacy差分を共通Zoom係数へ変換する")
    func testCreatesSharedZoomScaleFactors() {
        // コンディション：同じ垂直差分をpreciseとlegacy入力として用意する（Given）
        let delta: CGFloat = 2

        // 検証内容：それぞれのZoom係数を生成する（When）
        let preciseFactor = CanvasZoomInputResolver.scaleFactor(for: delta, isPrecise: true)
        let legacyFactor = CanvasZoomInputResolver.scaleFactor(for: delta, isPrecise: false)

        // 期待値：通常canvasとFocusが使う係数式に一致する（Then）
        #expect(abs(preciseFactor - exp(0.004)) < 0.000_001)
        #expect(abs(legacyFactor - exp(0.16)) < 0.000_001)
    }

    /// 論理名（日本語）: 共通入力倍率適用テスト
    /// 概要: Commandスクロールとピンチが表示方式に依存しない同一の倍率更新経路へ入ることを検証します。
    @Test("Commandスクロールとピンチを共通倍率更新へ適用する")
    func testAppliesScrollAndPinchThroughSharedUpdate() {
        // コンディション：100%にprecise scrollと20%のpinchを適用する入力を用意する（Given）
        let scrollInput = CanvasZoomInput.commandScroll(delta: 10, isPrecise: true)
        let pinchInput = CanvasZoomInput.magnification(0.2)

        // 検証内容：共通resolverでそれぞれの次倍率を算出する（When）
        let scrollZoom = CanvasZoomInputResolver.targetZoom(currentZoom: 1, input: scrollInput)
        let pinchZoom = CanvasZoomInputResolver.targetZoom(currentZoom: 1, input: pinchInput)

        // 期待値：scrollは共有指数係数、pinchはAppKit magnification比率で更新される（Then）
        #expect(abs(scrollZoom - exp(0.02)) < 0.000_001)
        #expect(abs(pinchZoom - 1.2) < 0.000_001)
    }

    /// 論理名（日本語）: 共通Zoom上限下限補正テスト
    /// 概要: 有限Focusと通常canvasのどちらも共通の許容倍率範囲で停止することを確認します。
    @Test("共通Zoom入力を許容倍率範囲へ補正する")
    func testClampsSharedZoomInputToRange() {
        // コンディション：範囲上限と下限を越えるpinch入力を用意する（Given）
        let zoomIn = CanvasZoomInput.magnification(10)
        let zoomOut = CanvasZoomInput.magnification(-10)

        // 検証内容：共通resolverへ両入力を適用する（When）
        let upper = CanvasZoomInputResolver.targetZoom(currentZoom: CanvasZoom.range.upperBound, input: zoomIn)
        let lower = CanvasZoomInputResolver.targetZoom(currentZoom: CanvasZoom.range.lowerBound, input: zoomOut)

        // 期待値：表示方式に関係なく共通rangeの上下限に留まる（Then）
        #expect(upper == CanvasZoom.range.upperBound)
        #expect(lower == CanvasZoom.range.lowerBound)
    }
}

/// 論理名（日本語）: キャンバスズーム基準点解決関連のテストスイート
/// 概要: ズーム前後で画面上の基準点を維持する座標計算を検証します。
@Suite("キャンバスズーム基準点解決関連のテストスイート")
struct CanvasZoomAnchorResolverTests {
    /// 論理名（日本語）: viewport基準点補正テスト
    /// 概要: 通常canvasとFocusが共有するイベント位置変換を表示範囲内へ補正できることを検証します。
    @Test("イベント位置をviewport基準の範囲内へ補正する")
    func testClampsViewportPoint() {
        // コンディション：原点を持つvisible rectと範囲外のclip view座標を用意する（Given）
        let visibleRect = CGRect(x: 100, y: 200, width: 300, height: 180)

        // 検証内容：共通resolverでviewport相対位置へ変換する（When）
        let before = CanvasZoomAnchorResolver.viewportPoint(CGPoint(x: 80, y: 190), visibleRect: visibleRect)
        let after = CanvasZoomAnchorResolver.viewportPoint(CGPoint(x: 450, y: 410), visibleRect: visibleRect)

        // 期待値：左上より前は0、右下より後はviewport寸法へ補正される（Then）
        #expect(before == .zero)
        #expect(after == CGPoint(x: 300, y: 180))
    }

    /// 論理名（日本語）: ポインタ基準ズーム原点算出テスト
    /// 概要: ズーム後も保存したキャンバス内容座標が同じ viewport 位置に残ることを検証します。
    @Test("ポインタ位置を基準にズーム後の原点を算出できる")
    func testDocumentOriginKeepsPointerAnchor() throws {
        // コンディション：表示中の原点、ポインタ位置、hosting view 原点を用意する（Given）
        let snapshot = try #require(CanvasZoomAnchorResolver.snapshot(
            viewportPoint: CGPoint(x: 50, y: 80),
            visibleOrigin: CGPoint(x: 100, y: 200),
            hostingOrigin: CGPoint(x: 20, y: 40),
            renderedZoom: 1,
            contentPadding: 72
        ))

        // 検証内容：倍率を 2 倍にした後の clip origin を算出する（When）
        let origin = try #require(CanvasZoomAnchorResolver.documentOrigin(
            for: snapshot,
            hostingOrigin: CGPoint(x: 20, y: 40),
            targetZoom: 2,
            contentPadding: 72,
            documentSize: CGSize(width: 1200, height: 1200),
            viewportSize: CGSize(width: 300, height: 300)
        ))

        // 期待値：同じキャンバス内容座標が元の viewport 位置へ来る原点になる（Then）
        #expect(snapshot.unscaledContentPoint == CGPoint(x: 58, y: 168))
        #expect(origin == CGPoint(x: 158, y: 368))
    }

    /// 論理名（日本語）: 中央基準ズーム原点算出テスト
    /// 概要: viewport 中央を基準点にした場合のズーム後原点を検証します。
    @Test("viewport中央を基準にズーム後の原点を算出できる")
    func testDocumentOriginKeepsCenterAnchor() throws {
        // コンディション：viewport 中央を基準点として保存する（Given）
        let snapshot = try #require(CanvasZoomAnchorResolver.snapshot(
            viewportPoint: CGPoint(x: 150, y: 100),
            visibleOrigin: CGPoint(x: 320, y: 240),
            hostingOrigin: .zero,
            renderedZoom: 0.5,
            contentPadding: 72
        ))

        // 検証内容：倍率を 1 倍にした後の clip origin を算出する（When）
        let origin = try #require(CanvasZoomAnchorResolver.documentOrigin(
            for: snapshot,
            hostingOrigin: .zero,
            targetZoom: 1,
            contentPadding: 72,
            documentSize: CGSize(width: 1600, height: 1400),
            viewportSize: CGSize(width: 300, height: 200)
        ))

        // 期待値：viewport 中央が同じキャンバス内容座標に留まる（Then）
        #expect(snapshot.unscaledContentPoint == CGPoint(x: 796, y: 536))
        #expect(origin == CGPoint(x: 718, y: 508))
    }

    /// 論理名（日本語）: ズーム原点制限テスト
    /// 概要: 算出された原点が documentView のスクロール可能範囲へ丸められることを検証します。
    @Test("ズーム後の原点をスクロール可能範囲に制限する")
    func testDocumentOriginIsClampedToScrollableRange() {
        // コンディション：documentView より外側を指す原点候補を用意する（Given）
        let negativeOrigin = CanvasZoomAnchorResolver.clampedDocumentOrigin(
            CGPoint(x: -40, y: -90),
            documentSize: CGSize(width: 800, height: 700),
            viewportSize: CGSize(width: 300, height: 200)
        )
        let overflowingOrigin = CanvasZoomAnchorResolver.clampedDocumentOrigin(
            CGPoint(x: 900, y: 850),
            documentSize: CGSize(width: 800, height: 700),
            viewportSize: CGSize(width: 300, height: 200)
        )

        // 検証内容：上下限を超えた原点を補正する（When）
        let origins = [negativeOrigin, overflowingOrigin]

        // 期待値：下限は 0、上限は documentView と viewport の差分になる（Then）
        #expect(origins[0] == .zero)
        #expect(origins[1] == CGPoint(x: 500, y: 500))
    }
}
