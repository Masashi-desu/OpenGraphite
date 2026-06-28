import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスページドラッグ解決関連のテストスイート
/// 概要: キャプションカードのドラッグ量を canvas 座標へ戻す計算を検証します。
@Suite("キャンバスページドラッグ解決関連のテストスイート")
struct CanvasPageDragResolverTests {
    /// 論理名（日本語）: ズーム適用ドラッグ量変換テスト
    /// 概要: 画面上のドラッグ量が現在倍率で割られ、未拡大の canvas 移動量になることを検証します。
    @Test("画面上のドラッグ量をcanvas座標へ変換できる")
    func testCanvasTranslationDividesByZoom() {
        // コンディション：72% 表示中に画面上で 72pt 横移動する状況を用意する（Given）
        let screenTranslation = CGSize(width: 72, height: -36)

        // 検証内容：canvas 座標の移動量へ変換する（When）
        let translation = CanvasPageDragResolver.canvasTranslation(
            screenTranslation: screenTranslation,
            zoom: 0.72
        )

        // 期待値：未拡大の canvas 上では 100pt / -50pt の移動量になる（Then）
        #expect(abs(translation.width - 100) < 0.0001)
        #expect(abs(translation.height + 50) < 0.0001)
    }

    /// 論理名（日本語）: ドラッグ確定位置丸めテスト
    /// 概要: ドラッグ終了時の保存座標が元座標と移動量の合算から整数へ丸められることを検証します。
    @Test("ドラッグ終了時のcanvas位置を整数へ丸めて確定できる")
    func testFinalizedPositionRoundsCanvasCoordinates() {
        // コンディション：小数座標を持つ page canvas と、2倍表示中の画面ドラッグ量を用意する（Given）
        let canvas = OpenGraphiteCanvas(x: 10.2, y: -4.4, width: 390, height: 844)

        // 検証内容：保存対象の canvas 左上座標を算出する（When）
        let position = CanvasPageDragResolver.finalizedPosition(
            for: canvas,
            screenTranslation: CGSize(width: 15, height: -5),
            zoom: 2
        )

        // 期待値：canvas 移動量 7.5 / -2.5 を加算した位置が整数に丸められる（Then）
        #expect(position == CGPoint(x: 18, y: -7))
    }

    /// 論理名（日本語）: キャプションヒット領域内包テスト
    /// 概要: 左上キャプションカードが document frame 内にあり、ドラッグ開始の hit-test 対象に含まれることを検証します。
    @Test("左上キャプションカードはdocument frame内に収まる")
    func testVisualLayoutContainsCaptionHitFrame() {
        // コンディション：標準的な desktop page の canvas サイズを用意する（Given）
        let layout = CanvasPageVisualLayout.resolve(pageWidth: 1440, pageHeight: 1200)
        let documentFrame = CGRect(origin: .zero, size: layout.documentSize)

        // 検証内容：キャプションカードと page 本体の表示矩形を確認する（When）
        let captionFrame = layout.captionHitFrame
        let pageBodyFrame = layout.pageBodyFrame

        // 期待値：カード全体が document frame 内にあり、page 本体はカード下に配置される（Then）
        #expect(documentFrame.contains(captionFrame))
        #expect(documentFrame.contains(pageBodyFrame))
        #expect(captionFrame.minY == 0)
        #expect(pageBodyFrame.minY >= captionFrame.maxY)
    }

    /// 論理名（日本語）: 狭幅キャプション幅確保テスト
    /// 概要: page 幅がカード最小幅より小さい場合でも、document frame がカードのドラッグ可能幅を確保することを検証します。
    @Test("狭いpageでもキャプションカード幅をdocument frameに含める")
    func testVisualLayoutExpandsDocumentWidthForNarrowPages() {
        // コンディション：カード最小幅より狭い component/page canvas を用意する（Given）
        let layout = CanvasPageVisualLayout.resolve(pageWidth: 120, pageHeight: 240)

        // 検証内容：document 幅と page 本体幅を比較する（When）
        let documentWidth = layout.documentSize.width
        let captionWidth = layout.captionHitFrame.width
        let pageBodyWidth = layout.pageBodyFrame.width

        // 期待値：document 幅は page 本体ではなくカード幅まで広がる（Then）
        #expect(pageBodyWidth == 120)
        #expect(captionWidth > pageBodyWidth)
        #expect(documentWidth == captionWidth)
    }
}

/// 論理名（日本語）: Canvasノードリサイズ解決関連のテストスイート
/// 概要: 選択ノードの四辺・四隅ハンドル操作を page content 座標と CSS 値へ変換する計算を検証します。
@Suite("Canvasノードリサイズ解決関連のテストスイート")
struct CanvasNodeResizeResolverTests {
    /// 論理名（日本語）: 右辺リサイズズーム換算テスト
    /// 概要: 画面上のドラッグ量が現在倍率で割られ、右辺の width 変更になることを検証します。
    @Test("右辺ドラッグはzoom換算後のwidthへ変換できる")
    func testRightHandleDividesTranslationByZoom() {
        // コンディション：50% 表示中の選択矩形と右辺ドラッグ量を用意する（Given）
        let startRect = CGRect(x: 40, y: 50, width: 100, height: 80)

        // 検証内容：右辺ハンドルでリサイズ後矩形を算出する（When）
        let rect = CanvasNodeResizeResolver.resizedRect(
            startRect: startRect,
            handle: .right,
            screenTranslation: CGSize(width: 20, height: 0),
            zoom: 0.5,
            pageSize: CGSize(width: 320, height: 240)
        )

        // 期待値：canvas 座標では 40pt 広がり、位置と高さは変わらない（Then）
        #expect(rect == CGRect(x: 40, y: 50, width: 140, height: 80))
    }

    /// 論理名（日本語）: 左上角リサイズテスト
    /// 概要: 左上角のドラッグで left/top と width/height が同時に更新されることを検証します。
    @Test("左上角ドラッグは位置と寸法を同時に変更する")
    func testTopLeftHandleUpdatesOriginAndSize() {
        // コンディション：page 内にある選択矩形と内側へ向かう左上角ドラッグ量を用意する（Given）
        let startRect = CGRect(x: 50, y: 60, width: 100, height: 80)

        // 検証内容：左上角ハンドルでリサイズ後矩形を算出する（When）
        let rect = CanvasNodeResizeResolver.resizedRect(
            startRect: startRect,
            handle: .topLeft,
            screenTranslation: CGSize(width: 30, height: 20),
            zoom: 1,
            pageSize: CGSize(width: 320, height: 240)
        )
        let values = CanvasNodeResizeResolver.cssValues(
            for: rect,
            handle: .topLeft,
            originalRect: startRect
        )

        // 期待値：左上が移動し、その分だけ幅と高さが縮む（Then）
        #expect(rect == CGRect(x: 80, y: 80, width: 70, height: 60))
        #expect(values == ["left": "80px", "top": "80px", "width": "70px", "height": "60px"])
    }

    /// 論理名（日本語）: Page境界クランプテスト
    /// 概要: 左上方向へ大きくドラッグしても page の左上境界を超えないことを検証します。
    @Test("左上方向へのリサイズはpage境界で止まる")
    func testResizeClampsToPageBounds() {
        // コンディション：page 内の選択矩形と page 外へ向かう大きなドラッグ量を用意する（Given）
        let startRect = CGRect(x: 50, y: 60, width: 100, height: 80)

        // 検証内容：左上角ハンドルでリサイズ後矩形を算出する（When）
        let rect = CanvasNodeResizeResolver.resizedRect(
            startRect: startRect,
            handle: .topLeft,
            screenTranslation: CGSize(width: -120, height: -120),
            zoom: 1,
            pageSize: CGSize(width: 320, height: 240)
        )

        // 期待値：矩形の左上は page 原点で止まり、右下は開始時の位置を保つ（Then）
        #expect(rect == CGRect(x: 0, y: 0, width: 150, height: 140))
    }

    /// 論理名（日本語）: 最小サイズクランプテスト
    /// 概要: 辺を反対側へドラッグしすぎても最小サイズを下回らないことを検証します。
    @Test("辺リサイズは最小サイズで止まる")
    func testResizeClampsToMinimumSize() {
        // コンディション：幅 100pt の選択矩形と右端を越える左辺ドラッグ量を用意する（Given）
        let startRect = CGRect(x: 50, y: 60, width: 100, height: 80)

        // 検証内容：左辺ハンドルでリサイズ後矩形を算出する（When）
        let rect = CanvasNodeResizeResolver.resizedRect(
            startRect: startRect,
            handle: .left,
            screenTranslation: CGSize(width: 140, height: 0),
            zoom: 1,
            pageSize: CGSize(width: 320, height: 240)
        )

        // 期待値：右辺を保ったまま幅が最小サイズの 2pt で止まる（Then）
        #expect(rect == CGRect(x: 148, y: 60, width: 2, height: 80))
    }

    /// 論理名（日本語）: CSS差分キー生成テスト
    /// 概要: 操作された辺に関係する CSS declaration だけが保存対象になることを検証します。
    @Test("操作辺に関係するCSS値だけを生成する")
    func testCSSValuesContainOnlyAffectedKeys() {
        // コンディション：下辺だけを伸ばした選択矩形を用意する（Given）
        let startRect = CGRect(x: 40, y: 50, width: 100, height: 80)
        let finalRect = CGRect(x: 40, y: 50, width: 100, height: 110)

        // 検証内容：下辺ハンドル用の CSS 値を生成する（When）
        let values = CanvasNodeResizeResolver.cssValues(
            for: finalRect,
            handle: .bottom,
            originalRect: startRect
        )

        // 期待値：保存対象は height だけになる（Then）
        #expect(values == ["height": "110px"])
    }
}

/// 論理名（日本語）: キャンバスドキュメント識別子解決関連のテストスイート
/// 概要: page 配置変更時に表示領域を維持しつつ、SwiftUI content だけが更新される ID 分離を検証します。
@Suite("キャンバスドキュメント識別子解決関連のテストスイート")
struct CanvasDocumentIdentityResolverTests {
    /// 論理名（日本語）: Page Geometry変更時Viewport ID維持テスト
    /// 概要: page の canvas 位置やサイズを変更しても、スクロール位置初期化用 ID が変わらないことを検証します。
    @Test("page配置変更ではviewport IDを変えずcontent revisionだけ変える")
    func testViewportIDIgnoresPageGeometry() {
        // コンディション：canvas 上に配置された page を用意し、初期 ID を取得する（Given）
        var page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(name: "Desktop", x: 0, y: 0, width: 1440, height: 1200)
        )
        let originalViewportID = CanvasDocumentIdentityResolver.viewportID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [page]
        )
        let originalRevisionID = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [page]
        )

        // 検証内容：drag release 後と同じように page の配置とサイズを更新する（When）
        page.canvas.x = 240
        page.canvas.y = -96
        page.canvas.width = 1280
        page.canvas.height = 960
        let movedViewportID = CanvasDocumentIdentityResolver.viewportID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [page]
        )
        let movedRevisionID = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [page]
        )

        // 期待値：表示領域の document ID は維持し、content revision だけを更新する（Then）
        #expect(movedViewportID == originalViewportID)
        #expect(movedRevisionID != originalRevisionID)
    }

    /// 論理名（日本語）: Preview Context変更時Revision更新テスト
    /// 概要: preview context だけの変更でも SwiftUI content の更新対象として検出できることを検証します。
    @Test("preview context変更ではcontent revisionを変える")
    func testContentRevisionTracksPreviewContext() {
        // コンディション：空の preview context を持つ component placement を用意する（Given）
        var page = OpenGraphitePage(
            id: "button-card",
            internalID: "component-button-card",
            path: "_components/button-card.html",
            canvas: OpenGraphiteCanvas(name: "Default", x: 200, y: 120, width: 520, height: 360)
        )
        let originalRevisionID = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .components,
            pages: [page]
        )

        // 検証内容：preview context に mock field を追加する（When）
        page.canvas.previewContext = OpenGraphitePreviewContext(
            fieldMocks: ["state": "active"],
            placementMocks: ["hero": ["title": "Preview"]]
        )
        let updatedRevisionID = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .components,
            pages: [page]
        )

        // 期待値：表示領域のリセットではなく content 更新で反映できるよう revision ID が変わる（Then）
        #expect(updatedRevisionID != originalRevisionID)
    }

    /// 論理名（日本語）: Page構成変更時Viewport ID更新テスト
    /// 概要: page の追加や表示順変更は別の canvas document として扱われることを検証します。
    @Test("page構成変更ではviewport IDを変える")
    func testViewportIDTracksPageMembershipAndOrder() {
        // コンディション：同じ project 内の二つの page を用意する（Given）
        let home = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
        )
        let docs = OpenGraphitePage(
            id: "docs",
            internalID: "page-docs",
            path: "docs.html",
            canvas: OpenGraphiteCanvas(x: 1520, y: 0, width: 1440, height: 1200)
        )

        // 検証内容：単一 page、追加後、順序入れ替え後の viewport ID を取得する（When）
        let singlePageID = CanvasDocumentIdentityResolver.viewportID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [home]
        )
        let appendedPageID = CanvasDocumentIdentityResolver.viewportID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [home, docs]
        )
        let reorderedPageID = CanvasDocumentIdentityResolver.viewportID(
            projectPath: "/project/OpenGraphiteSample.ogp",
            segment: .pages,
            pages: [docs, home]
        )

        // 期待値：表示対象の構成や順序が変わると viewport ID も変わる（Then）
        #expect(appendedPageID != singlePageID)
        #expect(reorderedPageID != appendedPageID)
    }
}

/// 論理名（日本語）: キャンバスプロジェクト境界関連のテストスイート
/// 概要: page 配置変更時に canvas bounds 原点が表示領域を不要に追従させないことを検証します。
@Suite("キャンバスプロジェクト境界関連のテストスイート")
struct CanvasProjectBoundsTests {
    /// 論理名（日本語）: 正方向配置時原点固定テスト
    /// 概要: page が正方向に配置されている場合でも、bounds 原点が page 位置へ追従しないことを検証します。
    @Test("正方向のpage配置ではbounds原点をゼロに保つ")
    func testBoundsKeepsZeroOriginForPositivePagePositions() {
        // コンディション：canvas 原点より右下にある page を用意する（Given）
        let page = OpenGraphitePage(
            id: "component-card",
            internalID: "component-card",
            path: "_components/card.html",
            canvas: OpenGraphiteCanvas(x: 320, y: 180, width: 640, height: 480)
        )

        // 検証内容：page を含む canvas bounds を計算する（When）
        let bounds = CanvasProjectBounds(pages: [page])

        // 期待値：bounds 原点は page の配置先ではなく canvas 原点に留まる（Then）
        #expect(bounds.origin == .zero)
        #expect(bounds.width == 960)
        #expect(bounds.height == 660)
    }

    /// 論理名（日本語）: 負方向配置時原点拡張テスト
    /// 概要: page が canvas 原点より左上へ出る場合だけ、bounds 原点を負方向へ広げることを検証します。
    @Test("負方向のpage配置ではbounds原点を必要分だけ広げる")
    func testBoundsExpandsOriginForNegativePagePositions() {
        // コンディション：canvas 原点より左上へ出た page を用意する（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: -120, y: -80, width: 1440, height: 1200)
        )

        // 検証内容：page を含む canvas bounds を計算する（When）
        let bounds = CanvasProjectBounds(pages: [page])

        // 期待値：page を含めるため、bounds 原点は負方向へ広がる（Then）
        #expect(bounds.origin == CGPoint(x: -120, y: -80))
        #expect(bounds.width == 1440)
        #expect(bounds.height == 1200)
    }
}

/// 論理名（日本語）: キャンバス原点変化補正関連のテストスイート
/// 概要: bounds 原点が変わったとき、表示領域を維持する scroll 補正量を検証します。
@Suite("キャンバス原点変化補正関連のテストスイート")
struct CanvasViewportOriginAdjustmentResolverTests {
    /// 論理名（日本語）: 負方向原点変化補正テスト
    /// 概要: bounds 原点が負方向へ広がった場合、同じ canvas 領域を表示するため正方向の scroll 補正を返すことを検証します。
    @Test("bounds原点が負方向へ動く場合は表示領域維持用の補正を返す")
    func testScrollAdjustmentCompensatesNegativeOriginExpansion() {
        // コンディション：bounds 原点が 0,0 から -80,-40 へ広がる状況を用意する（Given）
        let previousOrigin = CGPoint.zero
        let newOrigin = CGPoint(x: -80, y: -40)

        // 検証内容：72% 表示時の scroll 補正量を計算する（When）
        let adjustment = CanvasViewportOriginAdjustmentResolver.scrollAdjustment(
            previousOrigin: previousOrigin,
            newOrigin: newOrigin,
            zoom: 0.72
        )

        // 期待値：bounds 原点差分に倍率を掛けた分だけ、clip origin を補正できる（Then）
        #expect(abs(adjustment.x - 57.6) < 0.0001)
        #expect(abs(adjustment.y - 28.8) < 0.0001)
    }

    /// 論理名（日本語）: 不正倍率補正抑止テスト
    /// 概要: 無効な zoom では scroll 補正を行わないことを検証します。
    @Test("不正なzoomではscroll補正を行わない")
    func testScrollAdjustmentIgnoresInvalidZoom() {
        // コンディション：bounds 原点が変わるが zoom が 0 の状況を用意する（Given）
        let previousOrigin = CGPoint.zero
        let newOrigin = CGPoint(x: -80, y: -40)

        // 検証内容：不正倍率で scroll 補正量を計算する（When）
        let adjustment = CanvasViewportOriginAdjustmentResolver.scrollAdjustment(
            previousOrigin: previousOrigin,
            newOrigin: newOrigin,
            zoom: 0
        )

        // 期待値：表示領域を壊さないため補正しない（Then）
        #expect(adjustment == .zero)
    }
}
