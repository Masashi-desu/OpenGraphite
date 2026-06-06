import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスズーム基準点解決関連のテストスイート
/// 概要: ズーム前後で画面上の基準点を維持する座標計算を検証します。
@Suite("キャンバスズーム基準点解決関連のテストスイート")
struct CanvasZoomAnchorResolverTests {
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
