import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバススクロール配送ポリシーテストスイート
/// 概要: 選択中 WebView 上の wheel 入力が Canvas と DOM scroll のどちらへ配送されるかを検証します。
@Suite("キャンバススクロール配送ポリシーテストスイート")
struct CanvasScrollRoutePolicyTests {
    /// 論理名（日本語）: Document rootスクロール配送テスト
    /// 概要: page document 自体だけがスクロール可能な場合は外側 Canvas へ wheel 入力を渡すことを検証します。
    @Test("document rootだけがスクロール可能ならCanvasへ配送する")
    func testRoutesDocumentRootScrollToCanvas() {
        // コンディション：WebView 内にはいるが、明示的な overflow 要素ではなく document root だけが下方向へスクロールできる（Given）
        let state = WebScrollState(
            isInside: true,
            canScrollUp: false,
            canScrollDown: true,
            canScrollLeft: false,
            canScrollRight: false,
            canScrollElementUp: false,
            canScrollElementDown: false,
            canScrollElementLeft: false,
            canScrollElementRight: false
        )

        // 検証内容：下方向スクロールの配送先を判定する（When）
        let shouldRoute = CanvasScrollRoutePolicy.shouldRouteToCanvas(
            scrollState: state,
            direction: .down
        )

        // 期待値：page document のスクロールに吸われず、外側 Canvas へ配送される（Then）
        #expect(shouldRoute == true)
    }

    /// 論理名（日本語）: Overflow要素スクロール維持テスト
    /// 概要: ポインタ直下の overflow 要素がスクロール可能な場合は WebView 側へ wheel 入力を残すことを検証します。
    @Test("overflow要素がスクロール可能ならWebViewに残す")
    func testKeepsOverflowElementScrollInWebView() {
        // コンディション：ポインタ直下の DOM overflow 要素が下方向へスクロールできる（Given）
        let state = WebScrollState(
            isInside: true,
            canScrollUp: false,
            canScrollDown: true,
            canScrollLeft: false,
            canScrollRight: false,
            canScrollElementUp: false,
            canScrollElementDown: true,
            canScrollElementLeft: false,
            canScrollElementRight: false
        )

        // 検証内容：下方向スクロールの配送先を判定する（When）
        let shouldRoute = CanvasScrollRoutePolicy.shouldRouteToCanvas(
            scrollState: state,
            direction: .down
        )

        // 期待値：DOM 内の明示的な scroll 操作として WebView 側に残る（Then）
        #expect(shouldRoute == false)
    }

    /// 論理名（日本語）: 未同期スクロール状態配送テスト
    /// 概要: WebView の scroll state がまだ届いていない初回 wheel は Canvas へ渡すことを検証します。
    @Test("scroll state未同期ならCanvasへ配送する")
    func testRoutesWhenScrollStateIsUnavailable() {
        // コンディション：WebView hit-test は済んでいるが JavaScript 由来の scroll state がまだない（Given）
        let state: WebScrollState? = nil

        // 検証内容：下方向スクロールの配送先を判定する（When）
        let shouldRoute = CanvasScrollRoutePolicy.shouldRouteToCanvas(
            scrollState: state,
            direction: .down
        )

        // 期待値：初回 wheel が document root scroll に吸われず、外側 Canvas へ配送される（Then）
        #expect(shouldRoute == true)
    }

    /// 論理名（日本語）: Webスクロールpayload要素フラグテスト
    /// 概要: JavaScript payload の element 系フラグが document root と独立して保持されることを検証します。
    @Test("payloadからoverflow要素のスクロール可否を保持する")
    func testPayloadStoresElementScrollFlags() {
        // コンディション：document root と overflow 要素のスクロール可否が異なる payload を用意する（Given）
        let state = WebScrollState(
            payload: [
                "inside": true,
                "up": true,
                "down": true,
                "left": false,
                "right": false,
                "elementUp": false,
                "elementDown": true,
                "elementLeft": false,
                "elementRight": false
            ]
        )

        // 検証内容：payload を WebScrollState へ変換する（When）
        let canScrollDocumentUp = state.canScroll(.up)
        let canScrollElementUp = state.canScrollElement(.up)
        let canScrollElementDown = state.canScrollElement(.down)

        // 期待値：document root と overflow 要素の可否が独立して保持される（Then）
        #expect(canScrollDocumentUp == true)
        #expect(canScrollElementUp == false)
        #expect(canScrollElementDown == true)
    }
}

/// 論理名（日本語）: キャンバス入力領域ポリシーテストスイート
/// 概要: 全面配置された Canvas scroll view が左右カラムと上部クローム上の入力を消費しないことを検証します。
@Suite("キャンバス入力領域ポリシーテストスイート")
struct CanvasInputRegionPolicyTests {
    /// 論理名（日本語）: 左右カラム入力除外テスト
    /// 概要: Sidebar と Inspector に覆われた座標が Canvas の有効入力領域から外れることを検証します。
    @Test("左右カラム上の入力はCanvas領域外として扱う")
    func testExcludesOverlayColumnsFromCanvasInputRegion() {
        // コンディション：全面 Canvas bounds と左右カラム分の overlay avoidance を用意する（Given）
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let overlayAvoidance = CanvasOverlayAvoidance(leading: 280, trailing: 300, top: 50)

        // 検証内容：左カラム、右カラム、中央プレビューの点を判定する（When）
        let leftColumnPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 120, y: 400),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: true
        )
        let rightColumnPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 1040, y: 400),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: true
        )
        let centerPreviewPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 600, y: 400),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: true
        )

        // 期待値：左右カラムは Canvas 入力から除外され、中央プレビューだけが有効になる（Then）
        #expect(leftColumnPoint == false)
        #expect(rightColumnPoint == false)
        #expect(centerPreviewPoint == true)
    }

    /// 論理名（日本語）: 上部クローム入力除外テスト
    /// 概要: flipped / non-flipped のどちらの座標系でも上部クローム領域が Canvas 入力から外れることを検証します。
    @Test("上部クローム上の入力は座標系に応じてCanvas領域外として扱う")
    func testExcludesTopChromeFromCanvasInputRegion() {
        // コンディション：上部クローム分の overlay avoidance を持つ Canvas bounds を用意する（Given）
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let overlayAvoidance = CanvasOverlayAvoidance(leading: 0, trailing: 0, top: 50)

        // 検証内容：flipped / non-flipped それぞれの上部座標と本文座標を判定する（When）
        let flippedTopPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 600, y: 20),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: true
        )
        let nonFlippedTopPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 600, y: 780),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: false
        )
        let flippedBodyPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 600, y: 80),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: true
        )
        let nonFlippedBodyPoint = CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
            CGPoint(x: 600, y: 720),
            bounds: bounds,
            overlayAvoidance: overlayAvoidance,
            isFlipped: false
        )

        // 期待値：上部クロームは Canvas 入力から除外され、本文側の点だけが有効になる（Then）
        #expect(flippedTopPoint == false)
        #expect(nonFlippedTopPoint == false)
        #expect(flippedBodyPoint == true)
        #expect(nonFlippedBodyPoint == true)
    }
}
