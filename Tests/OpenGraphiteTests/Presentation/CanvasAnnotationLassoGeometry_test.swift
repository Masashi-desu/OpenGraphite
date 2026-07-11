import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス注釈なげわ選択関連のテストスイート
/// 概要: canonical world 座標のなげわが付箋矩形と手書き実線を正しく選択することを確認します。
@Suite("キャンバス注釈なげわ選択関連のテストスイート")
struct CanvasAnnotationLassoSelectionResolverTests {
    /// 論理名（日本語）: 付箋包含選択テスト
    /// 概要: なげわが付箋矩形全体を囲む場合に選択されることを検証します。
    @Test("付箋全体を囲むなげわで選択する")
    func testLassoEnclosesStickyNote() {
        // コンディション：world座標の付箋を囲む四角形のなげわを用意する（Given）
        let annotation = stickyNote(id: "inside", x: 100, y: 80, width: 120, height: 90)
        let polygon = rectanglePolygon(x: 60, y: 40, width: 220, height: 180)

        // 検証内容：付箋となげわの包含を判定する（When）
        let isSelected = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: polygon)

        // 期待値：付箋がなげわ選択対象になる（Then）
        #expect(isSelected)
    }

    /// 論理名（日本語）: 付箋境界交差選択テスト
    /// 概要: なげわが付箋の一部だけを横切る場合にも選択されることを検証します。
    @Test("付箋境界を横切るなげわで選択する")
    func testLassoIntersectsStickyNoteBoundary() {
        // コンディション：付箋右端だけと重なる細長いなげわを用意する（Given）
        let annotation = stickyNote(id: "crossed", x: 100, y: 100, width: 100, height: 80)
        let polygon = rectanglePolygon(x: 190, y: 80, width: 40, height: 120)

        // 検証内容：付箋となげわの境界交差を判定する（When）
        let isSelected = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: polygon)

        // 期待値：一部だけの交差でも付箋が選択対象になる（Then）
        #expect(isSelected)
    }

    /// 論理名（日本語）: 手書き実線外空白除外テスト
    /// 概要: ink frame 内でも実点・実線分から離れた空白だけを囲むなげわでは選択されないことを検証します。
    @Test("ink外接矩形内の空白だけでは選択しない")
    func testLassoDoesNotSelectEmptyInkBoundingBoxArea() {
        // コンディション：大きなframeを対角に横切るinkと、線から離れた右上のなげわを用意する（Given）
        let annotation = ink(
            id: "diagonal",
            frameX: 100,
            frameY: 100,
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 190, y: 190)]
        )
        let polygon = rectanglePolygon(x: 245, y: 115, width: 40, height: 40)

        // 検証内容：inkとなげわの実線交差を判定する（When）
        let isSelected = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: polygon)

        // 期待値：外接矩形は重なっても実線が無いため選択されない（Then）
        #expect(!isSelected)
    }

    /// 論理名（日本語）: 手書き線分横断選択テスト
    /// 概要: 両端点がなげわ外でも手書き線分が多角形を横切る場合に選択されることを検証します。
    @Test("ink線分がなげわを横切れば選択する")
    func testLassoSelectsCrossingInkSegment() {
        // コンディション：なげわの左右外側に端点を持つ水平inkを用意する（Given）
        let annotation = ink(
            id: "crossing-line",
            frameX: 0,
            frameY: 0,
            points: [CGPoint(x: 20, y: 100), CGPoint(x: 220, y: 100)]
        )
        let polygon = rectanglePolygon(x: 80, y: 70, width: 80, height: 60)

        // 検証内容：端点包含ではなく線分と多角形辺の交差を判定する（When）
        let isSelected = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: polygon)

        // 期待値：実線がなげわを横切るため選択される（Then）
        #expect(isSelected)
    }

    /// 論理名（日本語）: 手書き表示線幅交差選択テスト
    /// 概要: なげわが中心線へ届かなくても、筆圧込みの太い表示線と交差すれば選択されることを検証します。
    @Test("ink中心線ではなく表示線幅との交差で選択する")
    func testLassoSelectsVisibleWidthOfThickInk() {
        // コンディション：中心Y=100、表示半径15ptの水平inkと、中心線外の内外2つのなげわを用意する（Given）
        let annotation = ink(
            id: "thick-line",
            frameX: 0,
            frameY: 0,
            points: [CGPoint(x: 20, y: 100), CGPoint(x: 220, y: 100)],
            lineWidth: 20,
            pressure: 1
        )
        let touchesVisibleInk = rectanglePolygon(x: 80, y: 84, width: 80, height: 4)
        let missesVisibleInk = rectanglePolygon(x: 80, y: 65, width: 80, height: 10)

        // 検証内容：同じ中心線に対して表示領域へ触れる場合と離れる場合を判定する（When）
        let touchingSelection = CanvasAnnotationLassoSelectionResolver.isSelected(
            annotation,
            by: touchesVisibleInk
        )
        let missingSelection = CanvasAnnotationLassoSelectionResolver.isSelected(
            annotation,
            by: missesVisibleInk
        )

        // 期待値：表示線幅に触れるなげわだけがinkを選択する（Then）
        #expect(touchingSelection)
        #expect(!missingSelection)
    }

    /// 論理名（日本語）: 筆圧平均表示線幅一致テスト
    /// 概要: 端点の筆圧差が大きい線分でも、描画と同じ平均筆圧の線幅を使い、最大端点幅まで選択領域を広げないことを検証します。
    @Test("筆圧差のあるinkは描画と同じ平均線幅で選択する")
    func testLassoUsesRenderedAveragePressureForInkSegment() {
        // コンディション：筆圧0から1へ変化し、描画半径が約9.25ptになる水平inkを用意する（Given）
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "pressure-ramp",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 240, height: 200),
            strokes: [
                OpenGraphiteInkStroke(
                    points: [
                        OpenGraphiteInkPoint(x: 20, y: 100, pressure: 0),
                        OpenGraphiteInkPoint(x: 220, y: 100, pressure: 1)
                    ],
                    lineWidth: 20,
                    inputDevice: .pen
                )
            ]
        )
        let touchesRenderedWidth = rectanglePolygon(x: 80, y: 88, width: 80, height: 4)
        let onlyTouchesMaximumEndpointWidth = rectanglePolygon(x: 80, y: 84, width: 80, height: 3)

        // 検証内容：平均筆圧の表示幅内と、最大端点幅だけなら届く位置をそれぞれ判定する（When）
        let renderedWidthSelection = CanvasAnnotationLassoSelectionResolver.isSelected(
            annotation,
            by: touchesRenderedWidth
        )
        let maximumWidthOnlySelection = CanvasAnnotationLassoSelectionResolver.isSelected(
            annotation,
            by: onlyTouchesMaximumEndpointWidth
        )

        // 期待値：実描画へ触れるなげわだけを選択する（Then）
        #expect(renderedWidthSelection)
        #expect(!maximumWidthOnlySelection)
    }

    /// 論理名（日本語）: 手書き単一点包含選択テスト
    /// 概要: 一点だけのink strokeも点がなげわ内なら選択されることを検証します。
    @Test("単一点inkをなげわ内なら選択する")
    func testLassoSelectsSinglePointInk() {
        // コンディション：world座標へframe原点を加えると(125, 135)になる単一点inkを用意する（Given）
        let annotation = ink(
            id: "dot",
            frameX: 100,
            frameY: 100,
            points: [CGPoint(x: 25, y: 35)]
        )
        let polygon = rectanglePolygon(x: 120, y: 130, width: 20, height: 20)

        // 検証内容：frame-local点をworld座標へ戻して包含を判定する（When）
        let isSelected = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: polygon)

        // 期待値：単一点inkも選択対象になる（Then）
        #expect(isSelected)
    }

    /// 論理名（日本語）: 複数注釈選択順序テスト
    /// 概要: 選択ID列が対象だけを抽出し、注釈の入力順を維持することを検証します。
    @Test("選択対象のIDを入力順で返す")
    func testSelectedAnnotationIDsPreserveInputOrder() {
        // コンディション：なげわ内・外・境界上にある3注釈を入力順に並べる（Given）
        let annotations = [
            stickyNote(id: "first", x: 20, y: 20, width: 20, height: 20),
            stickyNote(id: "outside", x: 200, y: 200, width: 20, height: 20),
            ink(id: "third", frameX: 0, frameY: 0, points: [CGPoint(x: 80, y: 50)])
        ]
        let polygon = rectanglePolygon(x: 0, y: 0, width: 80, height: 80)

        // 検証内容：複数注釈からなげわ選択ID列を取得する（When）
        let selectedIDs = CanvasAnnotationLassoSelectionResolver.selectedAnnotationIDs(
            in: annotations,
            by: polygon
        )

        // 期待値：内側と境界上の注釈だけが入力順で返る（Then）
        #expect(selectedIDs == ["first", "third"])
    }

    /// 論理名（日本語）: 無効なげわ非選択テスト
    /// 概要: 2点以下、同一直線上、または微小な手ぶれの点列を閉多角形として扱わないことを検証します。
    @Test("面を持たないなげわでは選択しない")
    func testInvalidLassoSelectsNothing() {
        // コンディション：付箋と、2点だけ・3点が同一直線上・2pt四方の微小ななげわ候補を用意する（Given）
        let annotation = stickyNote(id: "note", x: 0, y: 0, width: 100, height: 100)
        let twoPoints = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]
        let collinear = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100)]
        let tinyJitter = rectanglePolygon(x: 0, y: 0, width: 2, height: 2)

        // 検証内容：それぞれをなげわとして選択判定する（When）
        let twoPointResult = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: twoPoints)
        let collinearResult = CanvasAnnotationLassoSelectionResolver.isSelected(annotation, by: collinear)
        let tinyJitterIsValid = CanvasAnnotationLassoSelectionResolver.isValidPolygon(tinyJitter)

        // 期待値：面を持たない点列と操作面積未満の手ぶれは選択に使わない（Then）
        #expect(!twoPointResult)
        #expect(!collinearResult)
        #expect(!tinyJitterIsValid)
    }

    /// 論理名（日本語）: 自己交差なげわ有効性テスト
    /// 概要: 符号付き面積が相殺される8の字の自由曲線も、非共線な選択多角形としてUIと解決器で共有できることを検証します。
    @Test("自己交差するなげわも有効な自由曲線として扱う")
    func testSelfIntersectingLassoIsValid() {
        // コンディション：左右の符号付き面積が相殺される8の字の頂点列を用意する（Given）
        let figureEight = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100),
            CGPoint(x: 100, y: 0)
        ]

        // 検証内容：UIと同じ共通有効性判定へ渡す（When）
        let isValid = CanvasAnnotationLassoSelectionResolver.isValidPolygon(figureEight)

        // 期待値：3点以上の非共線自由曲線として受理する（Then）
        #expect(isValid)
    }

    /// 論理名（日本語）: テスト用付箋生成関数
    /// 処理概要: 指定したworld frameを持つ付箋注釈を生成します。
    ///
    /// - Parameters:
    ///   - id: 注釈内部ID。
    ///   - x: frame左端X座標。
    ///   - y: frame上端Y座標。
    ///   - width: frame幅。
    ///   - height: frame高さ。
    /// - Returns: テスト用付箋注釈。
    private func stickyNote(
        id: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> OpenGraphiteCanvasAnnotation {
        OpenGraphiteCanvasAnnotation(
            internalID: id,
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: x, y: y, width: width, height: height),
            text: id
        )
    }

    /// 論理名（日本語）: テスト用手書き生成関数
    /// 処理概要: 指定したworld frame原点とframe-local点列から手書き注釈を生成します。
    ///
    /// - Parameters:
    ///   - id: 注釈内部ID。
    ///   - frameX: frame左端X座標。
    ///   - frameY: frame上端Y座標。
    ///   - points: frame-local点列。
    ///   - lineWidth: strokeの基準線幅。
    ///   - pressure: 全点へ設定する筆圧。
    /// - Returns: テスト用手書き注釈。
    private func ink(
        id: String,
        frameX: Double,
        frameY: Double,
        points: [CGPoint],
        lineWidth: Double = 4,
        pressure: Double = 1
    ) -> OpenGraphiteCanvasAnnotation {
        OpenGraphiteCanvasAnnotation(
            internalID: id,
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: frameX, y: frameY, width: 240, height: 240),
            strokes: [
                OpenGraphiteInkStroke(
                    points: points.map {
                        OpenGraphiteInkPoint(x: $0.x, y: $0.y, pressure: pressure)
                    },
                    lineWidth: lineWidth,
                    inputDevice: .pen
                )
            ]
        )
    }

    /// 論理名（日本語）: テスト用矩形多角形生成関数
    /// 処理概要: 左上・右上・右下・左下の順で閉じる4点を生成します。
    ///
    /// - Parameters:
    ///   - x: 左端X座標。
    ///   - y: 上端Y座標。
    ///   - width: 幅。
    ///   - height: 高さ。
    /// - Returns: 暗黙に閉じる矩形多角形の頂点列。
    private func rectanglePolygon(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> [CGPoint] {
        [
            CGPoint(x: x, y: y),
            CGPoint(x: x + width, y: y),
            CGPoint(x: x + width, y: y + height),
            CGPoint(x: x, y: y + height)
        ]
    }
}
