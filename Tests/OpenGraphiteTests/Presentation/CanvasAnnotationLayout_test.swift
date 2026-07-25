import AppKit
import SwiftUI
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス注釈座標関連のテストスイート
/// 概要: `.ogp` world 座標、ページ名カード表示オフセット、page / annotation / reference boundsとpopover anchorの整合性を確認します。
@Suite("キャンバス注釈座標関連のテストスイート")
struct CanvasAnnotationCoordinateResolverTests {
    /// 論理名（日本語）: 参照入力Popoverアンカーテスト
    /// 概要: native source rectの中心が右クリックした挿入local座標と一致することを検証します。
    @Test("参照入力Popoverの矢印アンカーを右クリック位置へ揃える")
    func testReferencePopoverAnchorCentersOnContextClick() {
        // コンディション：スクロール・ズーム対象Canvas内の右クリックlocal座標を用意する（Given）
        let contextPoint = CGPoint(x: 927.25, y: 318.75)

        // 検証内容：NSPopoverへ渡すnative source rectを生成する（When）
        let sourceRect = CanvasReferencePopoverAnchorResolver.sourceRect(centeredAt: contextPoint)

        // 期待値：source rect中心が右クリック位置と完全に一致する（Then）
        #expect(sourceRect.midX == contextPoint.x)
        #expect(sourceRect.midY == contextPoint.y)
        #expect(sourceRect.size == CGSize(width: 1, height: 1))
    }

    /// 論理名（日本語）: キャンバス注釈座標往復テスト
    /// 概要: 注釈入力と表示が同じ canonical world 座標へ揃うことを検証します。
    @Test("注釈入力と表示は同じworld座標を使う")
    func testWorldAndLocalCoordinatesShareCanonicalPlane() {
        // コンディション：負方向へ広がった Canvas 原点とページ名カードの表示オフセットを用意する（Given）
        let canvasOrigin = CGPoint(x: -640, y: -640)
        let localInput = CGPoint(x: 740, y: 720)

        // 検証内容：入力点を world 座標へ変換し、同じ位置の注釈表示 frame を生成する（When）
        let worldPoint = CanvasAnnotationCoordinateResolver.worldPoint(
            localPoint: localInput,
            canvasOrigin: canvasOrigin
        )
        let localFrame = CanvasAnnotationCoordinateResolver.localFrame(
            OpenGraphiteCanvasAnnotationFrame(x: 100, y: 80, width: 240, height: 160),
            canvasOrigin: canvasOrigin,
            visualYOffset: 52
        )

        // 期待値：world point と表示 frame はページ名カード分だけを除いて同じ位置を指す（Then）
        #expect(worldPoint == CGPoint(x: 100, y: 80))
        #expect(localFrame.origin == CGPoint(x: 740, y: 772))
    }

    /// 論理名（日本語）: 注釈包含Boundsテスト
    /// 概要: Page 外の付箋も CanvasProjectBounds に含まれることを検証します。
    @Test("Page外の注釈までCanvas boundsを広げる")
    func testProjectBoundsIncludesAnnotationsOutsidePages() {
        // コンディション：640pt page の右外側に付箋を置く（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 640, height: 480)
        )
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "note-1",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 800, y: 100, width: 240, height: 160),
            text: "outside"
        )

        // 検証内容：page と annotation の union bounds を計算する（When）
        let bounds = CanvasProjectBounds(pages: [page], annotations: [annotation])

        // 期待値：右端は付箋の 1040pt まで広がり、原点はゼロを維持する（Then）
        #expect(bounds.origin == .zero)
        #expect(bounds.width == 1040)
        #expect(bounds.height == 480)
    }

    /// 論理名（日本語）: 参照配置包含Boundsテスト
    /// 概要: 負座標またはPage外にあるCanvas Object ReferenceもCanvasProjectBoundsに含まれることを検証します。
    @Test("Page外の参照配置までCanvas boundsを広げる")
    func testProjectBoundsIncludesCanvasObjectReferences() {
        // コンディション：Page左上の負座標へ参照viewportを配置する（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 640, height: 480)
        )
        let reference = OpenGraphiteCanvasReference(
            internalID: "reference-opaque",
            referenceID: "ogref:node:chapter-opaque:page-home:node-opaque",
            x: -420,
            y: -260,
            width: 360,
            height: 240
        )

        // 検証内容：Pageと参照viewportのunion boundsを計算する（When）
        let bounds = CanvasProjectBounds(pages: [page], references: [reference])

        // 期待値：参照の左上をworld原点に含み、Page右下までの寸法を確保する（Then）
        #expect(bounds.origin == CGPoint(x: -420, y: -260))
        #expect(bounds.width == 1060)
        #expect(bounds.height == 740)
    }

    /// 論理名（日本語）: 狭幅参照情報カード包含Boundsテスト
    /// 概要: 参照viewport本体より広い共通情報カードもCanvasProjectBoundsに含まれることを検証します。
    @Test("狭い参照viewportの左上情報カードまでCanvas boundsへ含める")
    func testProjectBoundsIncludesReferenceCaptionWidth() {
        // コンディション：Page右側へ最小幅の参照viewportを配置する（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 640, height: 480)
        )
        let reference = OpenGraphiteCanvasReference(
            internalID: "reference-narrow",
            referenceID: "ogref:node:chapter-opaque:page-home:node-opaque",
            x: 700,
            y: 0,
            width: 40,
            height: 40
        )

        // 検証内容：通常pageと共通の情報カードを含むCanvas boundsを計算する（When）
        let bounds = CanvasProjectBounds(pages: [page], references: [reference])

        // 期待値：40ptの参照本体ではなく196ptの情報カード右端まで表示範囲を確保する（Then）
        #expect(bounds.width == 896)
        #expect(bounds.height == 480)
    }

    /// 論理名（日本語）: 参照配置Content Revisionテスト
    /// 概要: 参照IDまたはworld frameの変更がCanvas content revisionへ反映されることを検証します。
    @Test("参照配置変更をcontent revisionへ反映する")
    func testContentRevisionTracksCanvasObjectReferences() {
        // コンディション：同じ配置IDで位置だけが異なる参照viewportを用意する（Given）
        let original = OpenGraphiteCanvasReference(
            internalID: "reference-revision",
            referenceID: "ogref:node:chapter-opaque:page-opaque:node-opaque",
            x: 40,
            y: 60
        )
        var moved = original
        moved.x = 80

        // 検証内容：変更前後のcontent revisionを生成する（When）
        let originalRevision = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/Sample.ogp",
            segment: .pages,
            pages: [],
            references: [original]
        )
        let movedRevision = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/Sample.ogp",
            segment: .pages,
            pages: [],
            references: [moved]
        )

        // 期待値：参照viewportの位置変更で描画revisionが変わる（Then）
        #expect(movedRevision != originalRevision)
    }

    /// 論理名（日本語）: 注釈Content Revision軽量化テスト
    /// 概要: 付箋本文や大量のstroke点変更ではscroll documentを再構築せず、配置変更だけをrevisionへ反映することを検証します。
    @Test("注釈payloadを展開せず配置変更だけをcontent revisionへ反映する")
    func testContentRevisionTracksAnnotationGeometryWithoutPayloadExpansion() {
        // コンディション：同じidentityとframeを持つ付箋および手書きpayload変更を用意する（Given）
        let frame = OpenGraphiteCanvasAnnotationFrame(x: 40, y: 60, width: 240, height: 160)
        let original = OpenGraphiteCanvasAnnotation(
            internalID: "annotation-revision",
            kind: .stickyNote,
            frame: frame,
            text: "before"
        )
        var payloadChanged = original
        payloadChanged.text = "after"
        var frameChanged = original
        frameChanged.frame.x = 80

        // 検証内容：本文変更とframe変更それぞれのcontent revisionを比較する（When）
        let originalRevision = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/Sample.ogp",
            segment: .pages,
            pages: [],
            annotations: [original]
        )
        let payloadRevision = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/Sample.ogp",
            segment: .pages,
            pages: [],
            annotations: [payloadChanged]
        )
        let frameRevision = CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: "/project/Sample.ogp",
            segment: .pages,
            pages: [],
            annotations: [frameChanged]
        )

        // 期待値：本文だけでは再構築せず、document boundsへ影響するframe変更ではrevisionが変わる（Then）
        #expect(payloadRevision == originalRevision)
        #expect(frameRevision != originalRevision)
    }

    /// 論理名（日本語）: 注釈余白フロー座標テスト
    /// 概要: 注釈作成用の interaction margin を加えても静的フロー線が page card と同じ位置へ移ることを検証します。
    @Test("注釈用余白を加えても静的フロー座標をpageへ揃える")
    func testStaticFlowOffsetIncludesAnnotationInteractionMargin() {
        // コンディション：world原点にpageを置き、その周囲へ640ptの注釈操作余白を持つboundsを用意する（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 640, height: 480)
        )
        let bounds = CanvasProjectBounds(pages: [page], interactionMargin: 640)

        // 検証内容：page最小座標基準のflowからCanvas表示座標への差を解決する（When）
        let offset = CanvasStaticFlowCoordinateResolver.visualOffset(
            pages: [page],
            bounds: bounds,
            visualYOffset: 52
        )

        // 期待値：X/Yの640pt余白とYのページ名カード52ptが接続点へ反映される（Then）
        #expect(offset == CGSize(width: 640, height: 692))
    }

    /// 論理名（日本語）: キャンバス注釈前面順テスト
    /// 概要: 選択中または変形中の HTML card よりも注釈レイヤーが常に前面になることを検証します。
    @Test("注釈レイヤーを全HTML cardより前面に保つ")
    func testAnnotationLayerRemainsAboveEveryPageState() {
        // コンディション：通常、選択中、変形中の HTML card 重なり順を用意する（Given）
        let pageOrders = [
            CanvasProjectLayerOrder.page(isSelected: false, isBeingTransformed: false),
            CanvasProjectLayerOrder.page(isSelected: true, isBeingTransformed: false),
            CanvasProjectLayerOrder.page(isSelected: true, isBeingTransformed: true)
        ]

        // 検証内容：各 card の最大重なり順と注釈レイヤーを比較する（When）
        let maximumPageOrder = pageOrders.max() ?? 0

        // 期待値：注釈レイヤーは card の選択・変形状態にかかわらず前面になる（Then）
        #expect(CanvasProjectLayerOrder.annotation > maximumPageOrder)
    }

    /// 論理名（日本語）: 手書き実線ヒット領域テスト
    /// 概要: 長い斜線の外接矩形内でも、実線から離れた場所はHTML cardへ入力を通すことを検証します。
    @Test("手書き選択領域を実線周辺だけに限定する")
    func testInkHitShapeFollowsStrokeInsteadOfBoundingBox() {
        // コンディション：120pt四方の外接矩形を横切る細い斜線を用意する（Given）
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "ink-hit",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 120, height: 120),
            strokes: [
                OpenGraphiteInkStroke(
                    points: [
                        OpenGraphiteInkPoint(x: 8, y: 8, pressure: 0.5),
                        OpenGraphiteInkPoint(x: 112, y: 112, pressure: 0.5)
                    ],
                    lineWidth: 3.5,
                    inputDevice: .pen
                )
            ]
        )

        // 検証内容：実線近傍と、同じ外接矩形内だが線から離れた点をhit testする（When）
        let path = CanvasInkHitShape(annotation: annotation).path(
            in: CGRect(x: 0, y: 0, width: 120, height: 120)
        )
        let hitsStroke = path.contains(CGPoint(x: 60, y: 62))
        let hitsEmptyBoundingBoxArea = path.contains(CGPoint(x: 24, y: 96))

        // 期待値：実線には選択余白があり、空の外接矩形領域はhit targetにならない（Then）
        #expect(hitsStroke)
        #expect(!hitsEmptyBoundingBoxArea)
    }
}

/// 論理名（日本語）: キャンバス手書き正規化関連のテストスイート
/// 概要: Sidecar / mouse の draft samples が差分確認可能な frame-local point 列へ変換されることを確認します。
@Suite("キャンバス手書き正規化関連のテストスイート")
struct CanvasInkStrokeNormalizerTests {
    /// 論理名（日本語）: Tabletイベントデバイス分離テスト
    /// 概要: proximity 内の Pencil / eraser が通常 mouse event の種別へ漏れないことを検証します。
    @Test("通常mouseをproximity中のPencilやeraserと混同しない")
    func testStylusResolverUsesCurrentEventTabletDataAndDeviceID() {
        // コンディション：device 7 の eraser が proximity 内にあり、eraser mode も有効な状態を用意する（Given）
        let proximityDevices: [Int: OpenGraphiteInkInputDevice] = [7: .eraser]

        // 検証内容：通常mouse event、同じdeviceのtablet event、未知deviceのtablet event、独立消しゴムツールをそれぞれ解決する（When）
        let mouse = CanvasStylusEventResolver.inputDevice(
            hasTabletPointData: false,
            deviceID: 1,
            proximityDevices: proximityDevices,
            isEraserMode: true
        )
        let eraser = CanvasStylusEventResolver.inputDevice(
            hasTabletPointData: true,
            deviceID: 7,
            proximityDevices: proximityDevices,
            isEraserMode: false
        )
        let fallbackPen = CanvasStylusEventResolver.inputDevice(
            hasTabletPointData: true,
            deviceID: 8,
            proximityDevices: proximityDevices,
            isEraserMode: false
        )
        let forcedMouseEraser = CanvasStylusEventResolver.inputDevice(
            hasTabletPointData: false,
            deviceID: 0,
            proximityDevices: [:],
            isEraserMode: false,
            forcedInputDevice: .eraser
        )

        // 期待値：通常eventはmouse、tablet eventはproximity種別またはpen、独立ツールはmouseでもeraserになる（Then）
        #expect(mouse == .mouse)
        #expect(eraser == .eraser)
        #expect(fallbackPen == .pen)
        #expect(forcedMouseEraser == .eraser)
    }

    /// 論理名（日本語）: 手書きストローク正規化テスト
    /// 概要: tabletPoint と mouse subtype の重複を除き、world bounds と相対座標を生成できることを検証します。
    @Test("重複入力を除いてframe-local strokeを作る")
    func testNormalizerDeduplicatesAndLocalizesSamples() throws {
        // コンディション：同一時刻・同一位置の重複を含む Sidecar pen samples を用意する（Given）
        let samples = [
            CanvasInkDraftSample(
                point: CGPoint(x: 10, y: 20),
                pressure: 0,
                tiltX: 0.1,
                tiltY: -0.1,
                inputDevice: .pen,
                timestamp: 1
            ),
            CanvasInkDraftSample(
                point: CGPoint(x: 10, y: 20),
                pressure: 0,
                tiltX: 0.1,
                tiltY: -0.1,
                inputDevice: .pen,
                timestamp: 1
            ),
            CanvasInkDraftSample(
                point: CGPoint(x: 20, y: 30),
                pressure: 1,
                tiltX: 0.2,
                tiltY: -0.2,
                inputDevice: .pen,
                timestamp: 2
            )
        ]

        // 検証内容：4pt の保存ストロークへ正規化する（When）
        let result = try #require(
            CanvasInkStrokeNormalizer.normalizedStroke(
                samples: samples,
                color: "#112233",
                lineWidth: 4
            )
        )

        // 期待値：重複が除かれ、線幅余白を含む frame と相対点列になる（Then）
        #expect(result.frame == OpenGraphiteCanvasAnnotationFrame(x: 7, y: 17, width: 16, height: 16))
        #expect(result.stroke.points.count == 2)
        #expect(result.stroke.points[0].x == 3)
        #expect(result.stroke.points[0].y == 3)
        #expect(result.stroke.points[1].x == 13)
        #expect(result.stroke.points[1].y == 13)
        #expect(result.stroke.inputDevice == .pen)
    }

    /// 論理名（日本語）: 筆圧線幅テスト
    /// 概要: Apple Pencil の筆圧差が画面上の線幅差へ反映されることを検証します。
    @Test("筆圧が高いほど線を太くする")
    func testPressureChangesRenderedLineWidth() {
        // コンディション：同じ基準線幅に最小・最大筆圧を与える（Given）
        let light = CanvasInkLineWidthResolver.width(baseWidth: 4, pressure: 0)
        let heavy = CanvasInkLineWidthResolver.width(baseWidth: 4, pressure: 1)
        let hugeFinite = CanvasInkLineWidthResolver.width(baseWidth: .greatestFiniteMagnitude, pressure: 1)

        // 検証内容：解決された実描画線幅を比較する（When）
        let isHeavyWider = heavy > light

        // 期待値：最大筆圧の線が最小筆圧より太い（Then）
        #expect(isHeavyWider)
        #expect(light >= 0.5)
        #expect(hugeFinite.isFinite)
        #expect(hugeFinite <= OpenGraphiteCanvasAnnotationLimits.maximumLineWidth * 1.5)
    }

    /// 論理名（日本語）: 消しゴム画面径一定テスト
    /// 概要: zoom が変わっても部分消去の可視径と判定径が画面上8ptに保たれることを検証します。
    @Test("消しゴム径をzoomに依存せず画面上8ptに保つ")
    func testEraserKeepsConstantScreenDiameterAcrossZoomLevels() {
        // コンディション：縮小、等倍、拡大のCanvas表示倍率を用意する（Given）
        let zoomLevels = [0.25, 1.0, 2.0]

        // 検証内容：各倍率向けworld基準線幅を実描画幅へ解決し、画面座標へ換算する（When）
        let screenDiameters = zoomLevels.map { zoom in
            CanvasInkLineWidthResolver.width(
                baseWidth: CanvasEraserMetrics.baseLineWidth(zoom: zoom),
                pressure: CanvasEraserMetrics.pressure
            ) * CGFloat(zoom)
        }
        let screenSampleDistances = zoomLevels.map { zoom in
            CanvasEraserMetrics.minimumWorldSampleDistance(zoom: zoom) * CGFloat(zoom)
        }

        // 期待値：全倍率で筆圧非依存の規定画面径と入力間引き距離が一致する（Then）
        for diameter in screenDiameters {
            #expect(abs(diameter - CanvasEraserMetrics.screenDiameter) < 0.001)
        }
        for distance in screenSampleDistances {
            #expect(abs(distance - CanvasEraserMetrics.minimumScreenSampleDistance) < 0.001)
        }
    }

    /// 論理名（日本語）: 消しゴムGesture保存文脈テスト
    /// 概要: drag中のCanvas切替や外部注釈更新を検出し、開始時snapshotを別containerへ保存しないことを検証します。
    @Test("消しゴムgesture中のCanvas切替と外部注釈更新を拒否する")
    func testEraserGestureContextRejectsChangedSaveTarget() {
        // コンディション：Pages Chapterのprojectと1件のinkをgesture開始文脈として固定する（Given）
        let originalInk = OpenGraphiteCanvasAnnotation(
            internalID: "ink-original",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 40, height: 20),
            strokes: [OpenGraphiteInkStroke(points: [OpenGraphiteInkPoint(x: 10, y: 10)])]
        )
        let context = CanvasEraserGestureContext(
            projectPath: "/tmp/project.ogp",
            segment: .pages,
            containerInternalID: "chapter-a",
            annotations: [originalInk]
        )
        let externallyAddedInk = OpenGraphiteCanvasAnnotation(
            internalID: "ink-external",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 50, y: 0, width: 40, height: 20),
            strokes: [OpenGraphiteInkStroke(points: [OpenGraphiteInkPoint(x: 10, y: 10)])]
        )

        // 検証内容：同一文脈、別Collection、外部追加後の注釈配列を照合する（When）
        let unchangedMatches = context.matches(
            projectPath: "/tmp/project.ogp",
            segment: .pages,
            containerInternalID: "chapter-a",
            annotations: [originalInk]
        )
        let switchedCanvasMatches = context.matches(
            projectPath: "/tmp/project.ogp",
            segment: .components,
            containerInternalID: "collection-b",
            annotations: [originalInk]
        )
        let externallyChangedMatches = context.matches(
            projectPath: "/tmp/project.ogp",
            segment: .pages,
            containerInternalID: "chapter-a",
            annotations: [originalInk, externallyAddedInk]
        )

        // 期待値：開始時と完全一致する場合だけ保存可能とし、切替・外部変更は不一致になる（Then）
        #expect(unchangedMatches)
        #expect(!switchedCanvasMatches)
        #expect(!externallyChangedMatches)
    }
}
