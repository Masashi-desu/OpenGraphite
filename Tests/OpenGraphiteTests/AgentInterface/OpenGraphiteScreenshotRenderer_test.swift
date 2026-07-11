import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバススクリーンショットレンダラー関連のテストスイート
/// 概要: page と `.ogp` 注釈の境界 union、および筆圧対応線幅の決定的な計算を確認します。
@Suite("キャンバススクリーンショットレンダラー関連のテストスイート")
struct OpenGraphiteScreenshotRendererTests {
    /// 論理名（日本語）: Pageと注釈の包含境界テスト
    /// 概要: Page 外の付箋と手書き注釈が screenshot bounds から切れないことを検証します。
    @Test("pageと注釈のunionをcanvas screenshot boundsにする")
    func testBoundsIncludesPagesAndAnnotations() throws {
        // コンディション：page の左上に付箋、右下に手書き注釈がはみ出す状態を用意する（Given）
        let page = OpenGraphitePage(
            id: "home",
            internalID: "page-home",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 100, y: 100, width: 200, height: 100)
        )
        let stickyNote = OpenGraphiteCanvasAnnotation(
            internalID: "note",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: -40, y: 50, width: 60, height: 80),
            text: "Review"
        )
        let ink = OpenGraphiteCanvasAnnotation(
            internalID: "ink",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 280, y: 190, width: 100, height: 70)
        )

        // 検証内容：page と注釈をまとめた screenshot bounds を解決する（When）
        let bounds = try #require(
            OpenGraphiteCanvasScreenshotBounds(
                pages: [page],
                annotations: [stickyNote, ink]
            )
        )

        // 期待値：すべての world frame を含む左上と右下から出力寸法が決まる（Then）
        #expect(bounds.minX == -40)
        #expect(bounds.minY == 50)
        #expect(bounds.maxX == 380)
        #expect(bounds.maxY == 260)
        #expect(bounds.width == 420)
        #expect(bounds.height == 210)
    }

    /// 論理名（日本語）: 注釈単独境界テスト
    /// 概要: page を持たない Chapter / Collection でも注釈のみから screenshot bounds を作れることを検証します。
    @Test("注釈のみのcanvasでもscreenshot boundsを作る")
    func testBoundsSupportsAnnotationOnlyCanvas() throws {
        // コンディション：page のない canvas に付箋を一つ用意する（Given）
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "note",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 12, y: -8, width: 240, height: 160),
            text: "Canvas-only note"
        )

        // 検証内容：注釈のみから screenshot bounds を解決する（When）
        let bounds = try #require(
            OpenGraphiteCanvasScreenshotBounds(pages: [], annotations: [annotation])
        )

        // 期待値：付箋 frame がそのまま screenshot の world 境界になる（Then）
        #expect(bounds.minX == 12)
        #expect(bounds.minY == -8)
        #expect(bounds.maxX == 252)
        #expect(bounds.maxY == 152)
        #expect(bounds.width == 240)
        #expect(bounds.height == 160)
    }

    /// 論理名（日本語）: キャンバスピクセル寸法検証テスト
    /// 概要: 安全上限内の境界は整数 pixel へ切り上げられることを検証します。
    @Test("安全上限内のcanvas寸法をpixelへ解決する")
    func testCanvasPixelSizeWithinLimits() throws {
        // コンディション：小数を含む実用範囲のcanvas boundsを用意する（Given）
        let bounds = OpenGraphiteCanvasScreenshotBounds(
            minX: -0.25,
            minY: 10,
            maxX: 2_047.01,
            maxY: 1_034.2
        )

        // 検証内容：bitmap確保前の寸法検証を実行する（When）
        let pixelSize = try OpenGraphiteCanvasScreenshotLimits.validatedPixelSize(for: bounds)

        // 期待値：幅と高さが切り上げられ、総pixel数が一致する（Then）
        #expect(pixelSize.width == 2_048)
        #expect(pixelSize.height == 1_025)
        #expect(pixelSize.pixelCount == 2_099_200)
    }

    /// 論理名（日本語）: キャンバス一辺過大テスト
    /// 概要: 一辺が安全上限を超える場合に bitmap を作る前明示エラーになることを検証します。
    @Test("過大なcanvas一辺をbitmap確保前に拒否する")
    func testCanvasDimensionLimitRejectsHugeBounds() {
        // コンディション：注釈数値の保存上限相当の巨大なboundsを用意する（Given）
        let bounds = OpenGraphiteCanvasScreenshotBounds(
            minX: -OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude,
            minY: 0,
            maxX: OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude,
            maxY: 100
        )

        // 検証内容：pixel寸法の検証を実行する（When）
        let error: Error?
        do {
            _ = try OpenGraphiteCanvasScreenshotLimits.validatedPixelSize(for: bounds)
            error = nil
        } catch let caughtError {
            error = caughtError
        }

        // 期待値：一辺の上限と対処を示すエラーで停止する（Then）
        #expect(error?.localizedDescription.contains("一辺の上限") == true)
        #expect(error?.localizedDescription.contains("Chapter / Collection") == true)
    }

    /// 論理名（日本語）: キャンバス総ピクセル過大テスト
    /// 概要: 各辺が上限内でも総 pixel 数が過大な場合に明示エラーになることを検証します。
    @Test("過大なcanvas総pixel数をbitmap確保前に拒否する")
    func testCanvasPixelCountLimitRejectsHugeArea() {
        // コンディション：一辺は上限内だが総pixel数が上限の2倍になるboundsを用意する（Given）
        let edge = 8_192.0
        let bounds = OpenGraphiteCanvasScreenshotBounds(minX: 0, minY: 0, maxX: edge, maxY: edge)

        // 検証内容：pixel寸法の検証を実行する（When）
        let error: Error?
        do {
            _ = try OpenGraphiteCanvasScreenshotLimits.validatedPixelSize(for: bounds)
            error = nil
        } catch let caughtError {
            error = caughtError
        }

        // 期待値：総pixel数の上限を示すエラーで停止する（Then）
        #expect(error?.localizedDescription.contains("総 pixel 数") == true)
        #expect(error?.localizedDescription.contains("\(OpenGraphiteCanvasScreenshotLimits.maximumPixelCount)") == true)
    }

    /// 論理名（日本語）: HTMLカードSnapshot累積上限テスト
    /// 概要: 出力boundsが上限内でも、重なったcard画像の累積が過大ならWebKit capture前に拒否することを検証します。
    @Test("重なったHTML cardの過大なsnapshot総量をcapture前に拒否する")
    func testCanvasSnapshotPixelCountRejectsOverlappingCards() throws {
        // コンディション：出力unionは上限内だが各33,554,432pxのcardが同じ位置に2枚重なる状態を用意する（Given）
        let pages = ["first", "second"].map { id in
            OpenGraphitePage(
                id: id,
                internalID: "page-\(id)",
                path: "\(id).html",
                canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 8_192, height: 4_096)
            )
        }
        let bounds = try #require(OpenGraphiteCanvasScreenshotBounds(pages: pages, annotations: []))

        // 検証内容：出力bitmap寸法とcard snapshot累積をそれぞれ事前検証する（When）
        let outputPixelSize = try OpenGraphiteCanvasScreenshotLimits.validatedPixelSize(for: bounds)
        let error: Error?
        do {
            _ = try OpenGraphiteCanvasScreenshotLimits.validatedSnapshotPixelCount(for: pages)
            error = nil
        } catch let caughtError {
            error = caughtError
        }

        // 期待値：出力自体は上限内でも、保持するsnapshot総量は明示エラーで拒否される（Then）
        #expect(outputPixelSize.pixelCount == OpenGraphiteCanvasScreenshotLimits.maximumPixelCount)
        #expect(error?.localizedDescription.contains("snapshot 総 pixel 数") == true)
        #expect(error?.localizedDescription.contains("\(OpenGraphiteCanvasScreenshotLimits.maximumSnapshotPixelCount)") == true)
    }

    /// 論理名（日本語）: HTMLカード不正Frame拒否テスト
    /// 概要: 有効な注釈がboundsを作れても、非正寸法のcardをWebKit viewportへ渡さないことを検証します。
    @Test("不正なHTML card frameをsnapshot前に拒否する")
    func testCanvasSnapshotRejectsInvalidCardFrame() {
        // コンディション：負の幅を持つcardと、単独でも有効なboundsを作れる付箋を用意する（Given）
        let invalidPage = OpenGraphitePage(
            id: "invalid-card",
            internalID: "page-invalid",
            path: "invalid.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: -320, height: 240)
        )
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "note",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 240, height: 160)
        )

        // 検証内容：従来boundsだけなら有効になる入力のcard snapshot事前検証を実行する（When）
        let bounds = OpenGraphiteCanvasScreenshotBounds(pages: [invalidPage], annotations: [annotation])
        let error: Error?
        do {
            _ = try OpenGraphiteCanvasScreenshotLimits.validatedSnapshotPixelCount(for: [invalidPage])
            error = nil
        } catch let caughtError {
            error = caughtError
        }

        // 期待値：付箋由来boundsの有無にかかわらず、不正card ID付きの明示エラーになる（Then）
        #expect(bounds != nil)
        #expect(error?.localizedDescription.contains("invalid-card") == true)
        #expect(error?.localizedDescription.contains("正の寸法") == true)
    }

    /// 論理名（日本語）: 注釈重なり順テスト
    /// 概要: manifest の種別混在順によらず App と同じ ink、sticky note の順に描画することを検証します。
    @Test("canvas screenshotでinkをsticky noteより背面に描画する")
    func testCanvasAnnotationDrawingOrderMatchesApp() {
        // コンディション：付箋とinkが交互に並ぶmanifest順を用意する（Given）
        let frame = OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 100)
        let annotations = [
            OpenGraphiteCanvasAnnotation(internalID: "sticky-1", kind: .stickyNote, frame: frame),
            OpenGraphiteCanvasAnnotation(internalID: "ink-1", kind: .ink, frame: frame),
            OpenGraphiteCanvasAnnotation(internalID: "sticky-2", kind: .stickyNote, frame: frame),
            OpenGraphiteCanvasAnnotation(internalID: "ink-2", kind: .ink, frame: frame)
        ]

        // 検証内容：screenshot描画契約で注釈を並べる（When）
        let orderedIDs = OpenGraphiteCanvasScreenshotDrawingContract
            .orderedAnnotations(annotations)
            .map(\.internalID)

        // 期待値：同種のmanifest順を保ったink、sticky noteの順になる（Then）
        #expect(orderedIDs == ["ink-1", "ink-2", "sticky-1", "sticky-2"])
    }

    /// 論理名（日本語）: Eraser入力元ストローク表示テスト
    /// 概要: `inputDevice` は入力元 metadata であり、App と同じく eraser 由来の保存ストロークも描画することを検証します。
    @Test("eraser入力元の保存ストロークもAppと同じく描画する")
    func testEraserInputDeviceStrokeUsesAppDrawingContract() {
        // コンディション：penとeraserの入力元を持つ保存ストロークを用意する（Given）
        let point = OpenGraphiteInkPoint(x: 0, y: 0)
        let strokes = [
            OpenGraphiteInkStroke(points: [point], inputDevice: .pen),
            OpenGraphiteInkStroke(points: [point], inputDevice: .eraser)
        ]
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "ink",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 10, height: 10),
            strokes: strokes
        )

        // 検証内容：screenshot描画契約から表示対象ストロークを解決する（When）
        let devices = OpenGraphiteCanvasScreenshotDrawingContract
            .drawableStrokes(in: annotation)
            .map(\.inputDevice)

        // 期待値：eraserを除外せず全ての保存ストロークを保持する（Then）
        #expect(devices == [.pen, .eraser])
    }

    /// 論理名（日本語）: 筆圧対応線幅テスト
    /// 概要: 保存筆圧が増えるほど screenshot 上の線幅が単調に太くなることを検証します。
    @Test("筆圧を決定的な可変線幅に変換する")
    func testInkLineWidthRespondsToPressure() {
        // コンディション：基準線幅 10 と弱・中・強の筆圧を用意する（Given）
        let baseLineWidth = 10.0

        // 検証内容：それぞれの筆圧を screenshot 線幅へ変換する（When）
        let light = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: baseLineWidth, pressure: 0)
        let medium = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: baseLineWidth, pressure: 0.25)
        let heavy = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: baseLineWidth, pressure: 1)

        // 期待値：画面描画と同じ 35%...150% の範囲で筆圧とともに増える（Then）
        #expect(abs(light - 3.5) < 0.0001)
        #expect(abs(medium - 6.375) < 0.0001)
        #expect(abs(heavy - 15) < 0.0001)
        #expect(light < medium)
        #expect(medium < heavy)
    }

    /// 論理名（日本語）: AppとScreenshot線幅一致テスト
    /// 概要: 部分消去の判定・画面表示・CLI PNGが同じsegment平均筆圧の線幅を使うことを検証します。
    @Test("画面表示とcanvas screenshotでsegment線幅を一致させる")
    func testInkSegmentWidthMatchesCanvasRenderer() {
        // コンディション：最小線幅を含む基準幅と複数のsegment平均筆圧を用意する（Given）
        let baseWidths = [0.5, 4.0, 12.0]
        let pressures = [0.0, 0.25, 0.5, 1.0]

        // 検証内容：画面とscreenshotの共通入力に対する描画幅をそれぞれ解決する（When）
        let comparisons = baseWidths.flatMap { baseWidth in
            pressures.map { pressure in
                (
                    CanvasInkLineWidthResolver.width(baseWidth: baseWidth, pressure: pressure),
                    OpenGraphiteInkScreenshotGeometry.lineWidth(
                        baseLineWidth: baseWidth,
                        pressure: pressure
                    )
                )
            }
        }

        // 期待値：線幅下限が作用する場合も全組み合わせで同じ直径になる（Then）
        #expect(comparisons.allSatisfy { abs($0.0 - $0.1) < 0.000_1 })
    }

    /// 論理名（日本語）: 筆圧入力補正テスト
    /// 概要: 範囲外と非数の筆圧・線幅が安全な描画値へ補正されることを検証します。
    @Test("不正な筆圧と線幅を安全な範囲へ補正する")
    func testInkLineWidthClampsInvalidInputs() {
        // コンディション：範囲外筆圧と NaN の基準線幅を用意する（Given）
        let baseLineWidth = 10.0

        // 検証内容：下限・上限超過と非数を線幅へ変換する（When）
        let belowRange = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: baseLineWidth, pressure: -3)
        let aboveRange = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: baseLineWidth, pressure: 4)
        let nonFinite = OpenGraphiteInkScreenshotGeometry.lineWidth(baseLineWidth: .nan, pressure: .nan)
        let hugeFinite = OpenGraphiteInkScreenshotGeometry.lineWidth(
            baseLineWidth: .greatestFiniteMagnitude,
            pressure: 1
        )

        // 期待値：筆圧は 0...1、基準線幅は 0.5 以上の有限値として扱われる（Then）
        #expect(abs(belowRange - 3.5) < 0.0001)
        #expect(abs(aboveRange - 15) < 0.0001)
        #expect(abs(nonFinite - 5.25) < 0.0001)
        #expect(hugeFinite.isFinite)
        #expect(hugeFinite <= OpenGraphiteCanvasAnnotationLimits.maximumLineWidth * 1.5)
    }
}
