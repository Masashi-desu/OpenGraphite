import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス手書き部分消去関連のテストスイート
/// 概要: 実描画幅に沿う部分消去、stroke分割、payload保持、tight frame再構築、極端な疎線分の安全性を確認します。
@Suite("キャンバス手書き部分消去関連のテストスイート")
struct CanvasInkPartialEraserTests {
    /// 論理名（日本語）: 線中央部分消去テスト
    /// 概要: 横線の中央だけを横切る消しゴムが左右2本のfragmentを生成することを検証します。
    @Test("線の中央だけを消して左右のfragmentへ分割する")
    func testMiddleCutSplitsStrokeAndPreservesPayload() throws {
        // コンディション：world上の横線と、その中央を縦に横切る同程度の細い消しゴムを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-middle",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 100, y: 200, width: 100, height: 20),
            strokes: [
                OpenGraphiteInkStroke(
                    points: [
                        OpenGraphiteInkPoint(x: 10, y: 10, pressure: 0.2, tiltX: 0.1, tiltY: -0.2),
                        OpenGraphiteInkPoint(x: 90, y: 10, pressure: 0.8, tiltX: 0.5, tiltY: 0.2)
                    ],
                    color: "#123456",
                    lineWidth: 4,
                    inputDevice: .pen
                )
            ]
        )
        let eraser = gesture(
            worldPoints: [(150, 195), (150, 225)],
            lineWidth: 4,
            pressure: 0.5
        )

        // 検証内容：消しゴムの swept capsule を注釈へ適用する（When）
        let updated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        ))
        let left = try #require(updated.strokes.first)
        let right = try #require(updated.strokes.last)
        let leftFirst = try #require(left.points.first)
        let leftLast = try #require(left.points.last)
        let rightFirst = try #require(right.points.first)
        let rightLast = try #require(right.points.last)
        let leftWorldEnd = worldPoint(leftLast, frame: updated.frame)
        let rightWorldStart = worldPoint(rightFirst, frame: updated.frame)
        let originalRenderedWidth = CanvasInkLineWidthResolver.width(baseWidth: 4, pressure: 0.5)
        let leftRenderedWidth = CanvasInkLineWidthResolver.width(
            baseWidth: 4,
            pressure: (leftFirst.pressure + leftLast.pressure) / 2
        )
        let rightRenderedWidth = CanvasInkLineWidthResolver.width(
            baseWidth: 4,
            pressure: (rightFirst.pressure + rightLast.pressure) / 2
        )
        let canonicalNumbers = [
            updated.frame.x,
            updated.frame.y,
            updated.frame.width,
            updated.frame.height
        ] + updated.strokes.flatMap { stroke in
            stroke.points.flatMap { [$0.x, $0.y, $0.pressure, $0.tiltX, $0.tiltY] }
        }

        // 期待値：中央だけに実幅相当の隙間が生じ、ID・payload・残線の描画幅・補間された傾きを保持する（Then）
        #expect(updated.internalID == annotation.internalID)
        #expect(updated.strokes.count == 2)
        #expect(leftWorldEnd.x < 150)
        #expect(rightWorldStart.x > 150)
        #expect(rightWorldStart.x - leftWorldEnd.x > 7)
        #expect(updated.strokes.allSatisfy { $0.color == "#123456" })
        #expect(updated.strokes.allSatisfy { $0.lineWidth == 4 })
        #expect(updated.strokes.allSatisfy { $0.inputDevice == .pen })
        #expect(abs(leftRenderedWidth - originalRenderedWidth) < 0.001)
        #expect(abs(rightRenderedWidth - originalRenderedWidth) < 0.001)
        #expect((0.1...0.5).contains(leftLast.tiltX))
        #expect(canonicalNumbers.allSatisfy {
            abs($0 * 1_000 - ($0 * 1_000).rounded()) < 0.000_001
        })
    }

    /// 論理名（日本語）: 実描画幅直外保持テスト
    /// 概要: inkとeraserの描画半径合計をわずかに外れる軌跡に不可視toleranceを加えないことを検証します。
    @Test("描画幅をわずかに外れる軌跡では消さない")
    func testSmallMissReturnsUnchanged() {
        // コンディション：両方の実描画半径合計3.7ptより0.1ptだけ離れた平行線を用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-miss",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 30),
            strokes: [stroke(points: [(10, 10), (90, 10)], lineWidth: 4, pressure: 0.5)]
        )
        let eraser = gesture(
            worldPoints: [(10, 13.8), (90, 13.8)],
            lineWidth: 4,
            pressure: 0.5
        )

        // 検証内容：平行な消しゴム軌跡を適用する（When）
        let result = CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        )

        // 期待値：隠れた3pt余白を使わず保存変更も発生しない（Then）
        #expect(result == .unchanged)
    }

    /// 論理名（日本語）: 複数ストローク選択部分消去テスト
    /// 概要: 同じ注釈内で交差したstrokeだけを分割し、非交差strokeを保持して共通frameへrebaseすることを検証します。
    @Test("複数strokeのうち交差した線だけを分割する")
    func testMultipleStrokesKeepUncrossedStroke() throws {
        // コンディション：上下2本の横線と、上側だけを横切る短い縦eraserを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-multiple",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 30, width: 120, height: 60),
            strokes: [
                stroke(points: [(10, 10), (110, 10)], color: "#AA0000"),
                stroke(points: [(10, 40), (110, 40)], color: "#0000AA")
            ]
        )
        let eraser = gesture(worldPoints: [(80, 25), (80, 55)], lineWidth: 4, pressure: 0.5)

        // 検証内容：2本を含む注釈へ部分消去を適用する（When）
        let updated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        ))
        let blueStroke = try #require(updated.strokes.first { $0.color == "#0000AA" })
        let blueWorldPoints = blueStroke.points.map { worldPoint($0, frame: updated.frame) }

        // 期待値：赤線が2fragment、青線が1strokeとして残り、青線のworld座標は変わらない（Then）
        #expect(updated.strokes.count == 3)
        #expect(updated.strokes.filter { $0.color == "#AA0000" }.count == 2)
        #expect(updated.strokes.filter { $0.color == "#0000AA" }.count == 1)
        #expect(blueWorldPoints.map(\.x) == [30, 130])
        #expect(blueWorldPoints.map(\.y) == [70, 70])
    }

    /// 論理名（日本語）: 全線消去結果テスト
    /// 概要: 消しゴムが全strokeの全長を覆う場合に空の更新注釈ではなく削除結果を返すことを検証します。
    @Test("全ての線が消えたら注釈削除を返す")
    func testFullEraseReturnsDeleted() {
        // コンディション：同じ位置に重なるinkと十分長いeraserを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-delete",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 20),
            strokes: [stroke(points: [(10, 10), (90, 10)])]
        )
        let eraser = gesture(worldPoints: [(0, 10), (100, 10)], lineWidth: 8, pressure: 0.5)

        // 検証内容：線全長へ消しゴムを適用する（When）
        let result = CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        )

        // 期待値：表示可能なfragmentが残らず削除結果になる（Then）
        #expect(result == .deleted)
    }

    /// 論理名（日本語）: 単一点インク消去テスト
    /// 概要: tapで生成した単一点strokeも双方の実描画半径で消去できることを検証します。
    @Test("単一点のinkを実描画円として消す")
    func testSingleDotUsesRenderedRadius() {
        // コンディション：world座標50,50の単一点と、その表示円へ触れる単一点eraserを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-dot",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 40, y: 40, width: 20, height: 20),
            strokes: [OpenGraphiteInkStroke(
                points: [OpenGraphiteInkPoint(x: 10, y: 10, pressure: 1)],
                lineWidth: 4,
                inputDevice: .pen
            )]
        )
        let eraser = gesture(worldPoints: [(53.5, 50)], lineWidth: 4, pressure: 0)

        // 検証内容：単一点gestureを単一点inkへ適用する（When）
        let result = CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        )

        // 期待値：ink円とeraser円が触れるため削除結果になる（Then）
        #expect(result == .deleted)
    }

    /// 論理名（日本語）: 筆圧反映ヒット幅テスト
    /// 概要: 同じ基準線幅とcenterlineでも高筆圧の実描画線だけが離れたeraserへ届くことを検証します。
    @Test("線分両端の平均筆圧を消去判定幅へ反映する")
    func testPressureControlsPartialEraseWidth() throws {
        // コンディション：低筆圧・高筆圧の横線と、centerlineから4pt離れた細いeraserを用意する（Given）
        let lowPressure = inkAnnotation(
            id: "ink-light",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 30),
            strokes: [stroke(points: [(10, 10), (90, 10)], lineWidth: 10, pressure: 0)]
        )
        let highPressure = inkAnnotation(
            id: "ink-heavy",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 30),
            strokes: [stroke(points: [(10, 10), (90, 10)], lineWidth: 10, pressure: 1)]
        )
        let eraser = gesture(worldPoints: [(40, 14), (60, 14)], lineWidth: 0.5, pressure: 0)

        // 検証内容：同じeraserを筆圧だけが異なる2つの注釈へ適用する（When）
        let lightResult = CanvasInkPartialEraser.erase(
            annotation: lowPressure,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        )
        let heavyResult = CanvasInkPartialEraser.erase(
            annotation: highPressure,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        )
        let heavyUpdated = try requireUpdated(heavyResult)

        // 期待値：低筆圧線は非交差、高筆圧線は中央が2fragmentへ分かれる（Then）
        #expect(lightResult == .unchanged)
        #expect(heavyUpdated.strokes.count == 2)
    }

    /// 論理名（日本語）: 複数消しゴム線分統合テスト
    /// 概要: 1gesture内の複数eraser segmentが同じinkを複数箇所で切断できることを検証します。
    @Test("複数segmentのeraserで1本の線を3fragmentへ分ける")
    func testMultipleEraserSegmentsCreateMultipleCuts() throws {
        // コンディション：長い横線と、x30・x70を縦に横切る連続gestureを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-two-cuts",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 100),
            strokes: [stroke(points: [(0, 50), (100, 50)])]
        )
        let eraser = gesture(
            worldPoints: [(30, 40), (30, 60), (70, 60), (70, 40)],
            lineWidth: 4,
            pressure: 0.5
        )

        // 検証内容：全eraser capsuleを1本のinkへ適用する（When）
        let updated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        ))

        // 期待値：2つの非連続な消去区間により3fragmentが残る（Then）
        #expect(updated.strokes.count == 3)
        let worldRanges = updated.strokes.map { stroke -> ClosedRange<Double> in
            let values = stroke.points.map { worldPoint($0, frame: updated.frame).x }
            return (values.min() ?? 0)...(values.max() ?? 0)
        }
        #expect(worldRanges[0].upperBound < 30)
        #expect(worldRanges[1].lowerBound > 30)
        #expect(worldRanges[1].upperBound < 70)
        #expect(worldRanges[2].lowerBound > 70)
    }

    /// 論理名（日本語）: 極長疎線分有限性テスト
    /// 概要: 最大座標規模の2点線を微小eraserで切っても無制限再サンプリングせず有限かつ少数のfragmentを返すことを検証します。
    @Test("極長の疎な2点線も有限かつboundedに部分消去する")
    func testSparseLongSegmentRemainsFiniteAndBounded() throws {
        // コンディション：900,000pt離れた2点だけの線と中央を横切る細いeraserを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-long",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 900_000, height: 10),
            strokes: [stroke(points: [(0, 5), (900_000, 5)], lineWidth: 0.5, pressure: 0)]
        )
        let eraser = gesture(
            worldPoints: [(450_000, 4), (450_000, 6)],
            lineWidth: 0.5,
            pressure: 0
        )

        // 検証内容：疎な長線へ部分消去を適用する（When）
        let updated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        ))
        let allPoints = updated.strokes.flatMap(\.points)

        // 期待値：中央の微小交差を見落とさず2fragment・4点以内で、frameと全payloadが有限範囲に収まる（Then）
        #expect(updated.strokes.count == 2)
        #expect(allPoints.count <= 4)
        #expect(updated.frame.x.isFinite)
        #expect(updated.frame.y.isFinite)
        #expect(updated.frame.width.isFinite)
        #expect(updated.frame.height.isFinite)
        #expect(updated.frame.width <= OpenGraphiteCanvasAnnotationLimits.maximumDimension)
        #expect(allPoints.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.pressure.isFinite && $0.tiltX.isFinite && $0.tiltY.isFinite
        })
    }

    /// 論理名（日本語）: 線始端トリムテスト
    /// 概要: endpointを覆う消しゴムが残線の始端を切り詰め、孤立したghost dotを生成しないことを検証します。
    @Test("線の始端だけを消して1fragmentへtrimする")
    func testEndpointEraseTrimsSingleFragmentWithoutGhostDot() throws {
        // コンディション：world座標10から90の横線と、始端だけを縦に覆う消しゴムを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-endpoint",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 20),
            strokes: [stroke(points: [(10, 10), (90, 10)])]
        )
        let eraser = gesture(worldPoints: [(10, 0), (10, 20)], lineWidth: 4, pressure: 0.5)

        // 検証内容：始端を横切る消しゴムを適用する（When）
        let updated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: eraser.frame,
            eraserStroke: eraser.stroke
        ))
        let retainedStroke = try #require(updated.strokes.first)
        let retainedWorldPoints = retainedStroke.points.map { worldPoint($0, frame: updated.frame) }

        // 期待値：始端が右へtrimされた2点以上の1fragmentだけが残り、終端world座標は維持される（Then）
        #expect(updated.strokes.count == 1)
        #expect(retainedStroke.points.count >= 2)
        #expect(try #require(retainedWorldPoints.first).x > 10)
        #expect(try #require(retainedWorldPoints.last).x == 90)
    }

    /// 論理名（日本語）: 部分消去反復適用テスト
    /// 概要: 一度rebase・分割した更新注釈へ別位置の消しゴムを再適用してもworld座標とpayloadが有限に保たれることを検証します。
    @Test("更新済み注釈へ別位置の部分消去を繰り返せる")
    func testRepeatedEraseSplitsUpdatedAnnotationAgain() throws {
        // コンディション：長い横線とx30・x70を別々に横切る2回分の消しゴムを用意する（Given）
        let annotation = inkAnnotation(
            id: "ink-repeat",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 100),
            strokes: [stroke(points: [(0, 50), (100, 50)], color: "#778899")]
        )
        let firstEraser = gesture(worldPoints: [(30, 40), (30, 60)], lineWidth: 4, pressure: 0.5)
        let secondEraser = gesture(worldPoints: [(70, 40), (70, 60)], lineWidth: 4, pressure: 0.5)

        // 検証内容：1回目のupdated注釈を、そのまま2回目の部分消去入力へ渡す（When）
        let firstUpdated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: annotation,
            eraserFrame: firstEraser.frame,
            eraserStroke: firstEraser.stroke
        ))
        let secondUpdated = try requireUpdated(CanvasInkPartialEraser.erase(
            annotation: firstUpdated,
            eraserFrame: secondEraser.frame,
            eraserStroke: secondEraser.stroke
        ))
        let allPoints = secondUpdated.strokes.flatMap(\.points)

        // 期待値：同じ注釈ID・色の3fragmentとなり、再rebase後のframeと全pointが有限になる（Then）
        #expect(firstUpdated.strokes.count == 2)
        #expect(secondUpdated.internalID == annotation.internalID)
        #expect(secondUpdated.strokes.count == 3)
        #expect(secondUpdated.strokes.allSatisfy { $0.color == "#778899" })
        #expect(secondUpdated.frame.x.isFinite && secondUpdated.frame.y.isFinite)
        #expect(secondUpdated.frame.width.isFinite && secondUpdated.frame.height.isFinite)
        #expect(allPoints.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.pressure.isFinite && $0.tiltX.isFinite && $0.tiltY.isFinite
        })
    }

    /// 論理名（日本語）: 消しゴム保存文脈競合テスト
    /// 概要: gesture開始後に現在Canvasの注釈が外部更新された場合、古いpreviewから更新・削除payloadを作らないことを検証します。
    @Test("外部更新後は古い部分消去previewを保存しない")
    func testCommitResolverRejectsChangedCurrentAnnotations() throws {
        // コンディション：付箋と2件のinkを開始snapshotに持ち、片方の更新・片方の全消去を表すpreviewを用意する（Given）
        let sticky = OpenGraphiteCanvasAnnotation(
            internalID: "note-context",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 20, height: 20)
        )
        let firstInk = inkAnnotation(
            id: "ink-context-first",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 20, width: 100, height: 20),
            strokes: [stroke(points: [(0, 10), (100, 10)])]
        )
        let secondInk = inkAnnotation(
            id: "ink-context-second",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 60, width: 100, height: 20),
            strokes: [stroke(points: [(0, 10), (100, 10)])]
        )
        let original = [sticky, firstInk, secondInk]
        var updatedFirstInk = firstInk
        updatedFirstInk.strokes = [stroke(points: [(0, 10), (35, 10)])]
        let preview = [sticky, updatedFirstInk]

        // 検証内容：未変更currentと、外部追加を受けたcurrentの両方から保存payloadを解決する（When）
        let safePayload = try #require(CanvasInkErasureCommitResolver.resolve(
            originalAnnotations: original,
            previewAnnotations: preview,
            currentAnnotations: original
        ))
        let externallyAddedInk = inkAnnotation(
            id: "ink-context-external",
            frame: OpenGraphiteCanvasAnnotationFrame(x: 200, y: 20, width: 40, height: 20),
            strokes: [stroke(points: [(0, 10), (40, 10)])]
        )
        let conflictedPayload = CanvasInkErasureCommitResolver.resolve(
            originalAnnotations: original,
            previewAnnotations: preview,
            currentAnnotations: original + [externallyAddedInk]
        )

        // 期待値：元IDだけを更新・削除し、外部更新後は古いpreview全体を破棄する（Then）
        #expect(safePayload.updatedAnnotations == [updatedFirstInk])
        #expect(safePayload.deletedIDs == [secondInk.internalID])
        #expect(conflictedPayload == nil)
    }

    /// 論理名（日本語）: Ink注釈テストデータ生成関数
    /// 処理概要: 指定frameとstroke列を持つink注釈を生成します。
    ///
    /// - Parameters:
    ///   - id: 内部ID。
    ///   - frame: world frame。
    ///   - strokes: frame-local stroke列。
    /// - Returns: テスト用ink注釈。
    private func inkAnnotation(
        id: String,
        frame: OpenGraphiteCanvasAnnotationFrame,
        strokes: [OpenGraphiteInkStroke]
    ) -> OpenGraphiteCanvasAnnotation {
        OpenGraphiteCanvasAnnotation(
            internalID: id,
            kind: .ink,
            frame: frame,
            text: "preserved",
            backgroundColor: "#ABCDEF",
            textColor: "#102030",
            strokes: strokes
        )
    }

    /// 論理名（日本語）: Inkストロークテストデータ生成関数
    /// 処理概要: 座標タプル列へ同じ筆圧を設定し、frame-local strokeを生成します。
    ///
    /// - Parameters:
    ///   - points: frame-local座標列。
    ///   - color: stroke色。
    ///   - lineWidth: 基準線幅。
    ///   - pressure: 全点へ設定する筆圧。
    /// - Returns: テスト用stroke。
    private func stroke(
        points: [(Double, Double)],
        color: String = "#111111",
        lineWidth: Double = 4,
        pressure: Double = 0.5
    ) -> OpenGraphiteInkStroke {
        OpenGraphiteInkStroke(
            points: points.map { OpenGraphiteInkPoint(x: $0.0, y: $0.1, pressure: pressure) },
            color: color,
            lineWidth: lineWidth,
            inputDevice: .pen
        )
    }

    /// 論理名（日本語）: 消しゴムGestureテストデータ生成関数
    /// 処理概要: world座標列をtightなgesture frameとframe-local eraser strokeへ変換します。
    ///
    /// - Parameters:
    ///   - worldPoints: canonical world座標列。
    ///   - lineWidth: 消しゴム基準線幅。
    ///   - pressure: 全gesture pointへ設定する筆圧。
    /// - Returns: gesture frameとstroke。
    private func gesture(
        worldPoints: [(Double, Double)],
        lineWidth: Double,
        pressure: Double
    ) -> (frame: OpenGraphiteCanvasAnnotationFrame, stroke: OpenGraphiteInkStroke) {
        let minimumX = worldPoints.map(\.0).min() ?? 0
        let minimumY = worldPoints.map(\.1).min() ?? 0
        let maximumX = worldPoints.map(\.0).max() ?? minimumX
        let maximumY = worldPoints.map(\.1).max() ?? minimumY
        let frame = OpenGraphiteCanvasAnnotationFrame(
            x: minimumX,
            y: minimumY,
            width: max(maximumX - minimumX, 1),
            height: max(maximumY - minimumY, 1)
        )
        return (
            frame,
            OpenGraphiteInkStroke(
                points: worldPoints.map {
                    OpenGraphiteInkPoint(
                        x: $0.0 - frame.x,
                        y: $0.1 - frame.y,
                        pressure: pressure
                    )
                },
                lineWidth: lineWidth,
                inputDevice: .eraser
            )
        )
    }

    /// 論理名（日本語）: 更新結果必須化関数
    /// 処理概要: 部分消去結果から更新注釈を取り出し、それ以外をテスト失敗として扱います。
    ///
    /// - Parameter result: 検証対象の部分消去結果。
    /// - Returns: associated valueの更新注釈。
    private func requireUpdated(
        _ result: CanvasInkPartialEraseResult
    ) throws -> OpenGraphiteCanvasAnnotation {
        guard case let .updated(annotation) = result else {
            Issue.record("updated結果を期待しましたが、\(result)でした")
            throw PartialEraserTestError.expectedUpdated
        }
        return annotation
    }

    /// 論理名（日本語）: World点復元関数
    /// 処理概要: 更新後のframe-local pointへframe原点を加え、比較用world座標へ戻します。
    ///
    /// - Parameters:
    ///   - point: frame-local point。
    ///   - frame: 更新後のworld frame。
    /// - Returns: world座標。
    private func worldPoint(
        _ point: OpenGraphiteInkPoint,
        frame: OpenGraphiteCanvasAnnotationFrame
    ) -> (x: Double, y: Double) {
        (frame.x + point.x, frame.y + point.y)
    }
}

/// 論理名（日本語）: 部分消去テストエラー
/// 概要: 更新結果のassociated valueを安全に必須化するためのテスト専用エラーです。
private enum PartialEraserTestError: Error {
    case expectedUpdated
}
