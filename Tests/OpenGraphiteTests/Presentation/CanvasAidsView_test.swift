import CoreGraphics
import SwiftUI
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス補助表示関連のテストスイート
/// 概要: ルーラー、ガイド、グリッドが共有する座標変換、刻み、表示領域の計算を確認します。
@Suite("キャンバス補助表示関連のテストスイート")
struct CanvasAidsViewTests {
    /// 論理名（日本語）: キャンバスホスティングセーフエリア無効化テスト
    /// 概要: AppKit scroll view 内の canvas content が window 上端の safe area で下へ移動しないことを検証します。
    @MainActor
    @Test("canvas hosting viewのsafe areaを座標原点へ含めない")
    func testCanvasHostingViewUsesZeroSafeAreaInsets() {
        // コンディション：SwiftUI canvas content を保持する専用 hosting view を用意する（Given）
        let hostingView = CanvasZeroSafeAreaHostingView(rootView: EmptyView())

        // 検証内容：hosting view が公開する各辺の safe area inset を取得する（When）
        let insets = hostingView.safeAreaInsets

        // 期待値：page、方眼、ruler、guideが共有するhosting原点に追加余白がない（Then）
        #expect(insets.top == 0)
        #expect(insets.left == 0)
        #expect(insets.bottom == 0)
        #expect(insets.right == 0)
    }

    /// 論理名（日本語）: ガイド前面描画順テスト
    /// 概要: ガイド線と三角マーカーがルーラーの Material に隠れない描画順を検証します。
    @Test("guideと三角markerをrulerより前面に描画する")
    func testGuideLayerAppearsAboveRulerLayer() {
        // コンディション：rulerとguideの描画layerを用意する（Given）
        let rulerLayer = CanvasRulerGuideLayer.ruler.rawValue
        let guideLayer = CanvasRulerGuideLayer.guide.rawValue

        // 検証内容：guide layerとruler layerを比較する（When）
        let guideAppearsAboveRuler = guideLayer > rulerLayer

        // 期待値：guide本体と同じlayerにある三角markerがrulerより前面になる（Then）
        #expect(guideAppearsAboveRuler)
    }

    /// 論理名（日本語）: ワールド座標往復変換テスト
    /// 概要: Scroll、無限余白、content padding、Zoom を含む変換が可逆であることを検証します。
    @Test("viewport座標とworld座標を往復変換できる")
    func testCoordinateResolverRoundTrip() throws {
        // コンディション：scroll済みviewport、無限余白、負のcanvas原点、50% Zoomを用意する（Given）
        let viewportPosition: CGFloat = 123

        // 検証内容：viewport位置をworld座標へ変換し、同じ条件でviewportへ戻す（When）
        let worldPosition = try #require(
            CanvasAidCoordinateResolver.worldPosition(
                viewportPosition: viewportPosition,
                visibleOrigin: 320,
                hostingOrigin: 80,
                canvasOrigin: -640,
                zoom: 0.5,
                contentPadding: 72
            )
        )
        let restoredPosition = try #require(
            CanvasAidCoordinateResolver.viewportPosition(
                worldPosition: worldPosition,
                visibleOrigin: 320,
                hostingOrigin: 80,
                canvasOrigin: -640,
                zoom: 0.5,
                contentPadding: 72
            )
        )

        // 期待値：world座標は-58になり、画面位置は元の123へ戻る（Then）
        #expect(abs(worldPosition - (-58)) < 0.000_001)
        #expect(abs(restoredPosition - viewportPosition) < 0.000_001)
    }

    /// 論理名（日本語）: ページ本体原点整合テスト
    /// 概要: page 情報カードの描画領域を持つ場合も、`.ogp` の position 0,0 が page 本体左上の方眼とルーラーへ一致することを検証します。
    @Test("position 0,0をpage本体左上の方眼とrulerへ揃える")
    func testWorldOriginMatchesRenderedPageBodyOrigin() throws {
        // コンディション：上側にpage情報cardを描画する72% Zoomのcontentを用意する（Given）
        let zoom = 0.72
        let canvasOrigin: CGFloat = -640
        let pageLayout = CanvasPageVisualLayout.resolve(pageWidth: 1_440, pageHeight: 1_200)
        let contentOffset = CanvasAidCoordinateResolver.contentOffset(for: .horizontal)
        let renderedPageBodyPosition = CanvasMetrics.documentPadding
            + (abs(canvasOrigin) + pageLayout.pageBodyFrame.minY) * CGFloat(zoom)

        // 検証内容：world座標0をviewportへ変換し、page本体上端からworld座標へ戻す（When）
        let viewportPosition = try #require(
            CanvasAidCoordinateResolver.viewportPosition(
                worldPosition: 0,
                visibleOrigin: 0,
                hostingOrigin: 0,
                canvasOrigin: canvasOrigin,
                zoom: zoom,
                contentPadding: CanvasMetrics.documentPadding,
                contentOffset: contentOffset
            )
        )
        let restoredWorldPosition = try #require(
            CanvasAidCoordinateResolver.worldPosition(
                viewportPosition: renderedPageBodyPosition,
                visibleOrigin: 0,
                hostingOrigin: 0,
                canvasOrigin: canvasOrigin,
                zoom: zoom,
                contentPadding: CanvasMetrics.documentPadding,
                contentOffset: contentOffset
            )
        )

        // 期待値：0目盛りはpage本体上端へ一致し、同じ位置をworld座標0へ戻せる（Then）
        #expect(contentOffset == pageLayout.pageBodyFrame.minY)
        #expect(abs(viewportPosition - renderedPageBodyPosition) < 0.000_001)
        #expect(abs(restoredWorldPosition) < 0.000_001)
    }

    /// 論理名（日本語）: ルーラー数値中心整合テスト
    /// 概要: 上・左ルーラーの数値ラベル中心が、対応する主目盛り座標から固定値でずれないことを検証します。
    @Test("ruler数値の中心を対応する主目盛りへ揃える")
    func testRulerLabelCentersOnMajorTick() {
        // コンディション：上ルーラーのX主目盛りと左ルーラーのY主目盛りを用意する（Given）
        let horizontalRulerTick: CGFloat = 240
        let verticalRulerTick: CGFloat = 360

        // 検証内容：各主目盛りに対する数値ラベルの位置とanchorを解決する（When）
        let topLabel = CanvasRulerLabelLayout.resolve(
            orientation: .vertical,
            tickPosition: horizontalRulerTick
        )
        let leftLabel = CanvasRulerLabelLayout.resolve(
            orientation: .horizontal,
            tickPosition: verticalRulerTick
        )

        // 期待値：上は水平中心、左は垂直中心が主目盛り座標へ一致する（Then）
        #expect(topLabel.position.x == horizontalRulerTick)
        #expect(topLabel.anchor == .top)
        #expect(leftLabel.position.y == verticalRulerTick)
        #expect(leftLabel.anchor == .leading)
    }

    /// 論理名（日本語）: 補助表示レイアウトテスト
    /// 概要: Sidebar、Inspector、上部クローム、上・左ルーラーがキャンバス領域から正しく除かれることを検証します。
    @Test("overlayとrulerを避けたcontent矩形を解決する")
    func testAidLayoutResolvesOverlayAvoidanceAndRulers() {
        // コンディション：1000x800のpaneと左右column、44pt chromeを用意する（Given）
        let avoidance = CanvasOverlayAvoidance(leading: 240, trailing: 300, top: 44)

        // 検証内容：30pt rulerを表示する補助表示レイアウトを解決する（When）
        let layout = CanvasAidLayout.resolve(
            size: CGSize(width: 1_000, height: 800),
            avoidance: avoidance,
            showsRulers: true
        )

        // 期待値：active領域から上・左30ptが予約され、各ruler矩形も一致する（Then）
        #expect(layout.activeRect == CGRect(x: 240, y: 44, width: 460, height: 756))
        #expect(layout.contentRect == CGRect(x: 270, y: 74, width: 430, height: 726))
        #expect(layout.horizontalRulerRect == CGRect(x: 270, y: 44, width: 430, height: 30))
        #expect(layout.verticalRulerRect == CGRect(x: 240, y: 74, width: 30, height: 726))
    }

    /// 論理名（日本語）: ガイドルーラーマーカーレイアウトテスト
    /// 概要: 三角マーカーの操作領域が上・左ルーラー内に収まり、先端がガイドへ接することを検証します。
    @Test("guide markerを対応するruler端へ配置する")
    func testGuideMarkerFramesTouchRulerEdges() {
        // コンディション：上・左ルーラーを除いたcontent矩形と2本のguide位置を用意する（Given）
        let contentRect = CGRect(x: 270, y: 74, width: 430, height: 726)

        // 検証内容：垂直・水平guideのmarker操作領域を解決する（When）
        let verticalFrame = CanvasGuideRulerMarkerLayout.interactionFrame(
            guidePosition: 420,
            orientation: .vertical,
            contentRect: contentRect
        )
        let horizontalFrame = CanvasGuideRulerMarkerLayout.interactionFrame(
            guidePosition: 360,
            orientation: .horizontal,
            contentRect: contentRect
        )

        // 期待値：垂直marker下端はcontent上端、水平marker右端はcontent左端へ一致する（Then）
        #expect(verticalFrame == CGRect(x: 411, y: 56, width: 18, height: 18))
        #expect(verticalFrame.maxY == contentRect.minY)
        #expect(horizontalFrame == CGRect(x: 252, y: 351, width: 18, height: 18))
        #expect(horizontalFrame.maxX == contentRect.minX)
    }

    /// 論理名（日本語）: ガイドルーラー戻し判定テスト
    /// 概要: 垂直ガイドは上、水平ガイドは左へ戻した場合だけ削除対象になることを検証します。
    @Test("guide方向に対応するrulerへ戻したときだけ削除する")
    func testGuideDragBackUsesMatchingRulerAxis() {
        // コンディション：上端74、左端270のcontent矩形を用意する（Given）
        let contentRect = CGRect(x: 270, y: 74, width: 430, height: 726)

        // 検証内容：各guideを上・左・content内で終了した場合を判定する（When）
        let verticalAtTop = CanvasGuideInteractionResolver.isDraggedBackToRuler(
            location: CGPoint(x: 420, y: 73),
            orientation: .vertical,
            contentRect: contentRect
        )
        let verticalAtLeft = CanvasGuideInteractionResolver.isDraggedBackToRuler(
            location: CGPoint(x: 269, y: 360),
            orientation: .vertical,
            contentRect: contentRect
        )
        let horizontalAtLeft = CanvasGuideInteractionResolver.isDraggedBackToRuler(
            location: CGPoint(x: 269, y: 360),
            orientation: .horizontal,
            contentRect: contentRect
        )
        let horizontalAtTop = CanvasGuideInteractionResolver.isDraggedBackToRuler(
            location: CGPoint(x: 420, y: 73),
            orientation: .horizontal,
            contentRect: contentRect
        )

        // 期待値：垂直は上だけ、水平は左だけを削除対象にする（Then）
        #expect(verticalAtTop)
        #expect(!verticalAtLeft)
        #expect(horizontalAtLeft)
        #expect(!horizontalAtTop)
    }

    /// 論理名（日本語）: Zoom別目盛り刻みテスト
    /// 概要: Zoomに応じて小目盛りが過密にならず、大目盛りも安定した間隔になることを検証します。
    @Test("zoomに応じてgridとrulerの刻みを選ぶ")
    func testStepResolverAdaptsToZoom() {
        // コンディション：10%、72%、200%のZoomを用意する（Given）
        let zooms = [0.1, 0.72, 2.0]

        // 検証内容：各Zoomの小目盛りと大目盛りを解決する（When）
        let minorSteps = zooms.map { CanvasAidStepResolver.minorStep(zoom: $0) }
        let majorSteps = minorSteps.map(CanvasAidStepResolver.majorStep(for:))

        // 期待値：縮小時は粗く、拡大時は細かい読みやすい刻みになる（Then）
        #expect(minorSteps == [100, 20, 10])
        #expect(majorSteps == [500, 100, 100])
    }
}
