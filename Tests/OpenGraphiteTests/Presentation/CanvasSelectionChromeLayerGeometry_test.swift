import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: Canvas選択Chromeレイヤー幾何テストスイート
/// 概要: SwiftUI overlay 座標から Core Animation layer へ渡す選択枠とハンドル位置を検証します。
@Suite("Canvas選択Chromeレイヤー幾何テストスイート")
struct CanvasSelectionChromeLayerGeometryTests {
    /// 論理名（日本語）: ローカル矩形正規化テスト
    /// 概要: 選択 chrome view 内部で使う矩形が document 座標の offset を持ち込まないことを検証します。
    @Test("選択chrome内部の矩形は原点ゼロへ正規化する")
    func testLocalRectNormalizesOrigin() {
        // コンディション：document 座標上で offset を持つ page body 矩形を用意する（Given）
        let rect = CGRect(x: 24, y: 32, width: 1440, height: 1200)

        // 検証内容：選択 chrome view 内部で使うローカル矩形へ変換する（When）
        let localRect = CanvasSelectionChromeLayerGeometry.localRect(for: rect)

        // 期待値：サイズだけを保持し、内部座標へ document offset を持ち込まない（Then）
        #expect(localRect.origin == .zero)
        #expect(localRect.size == rect.size)
    }

    /// 論理名（日本語）: 選択枠Y座標維持テスト
    /// 概要: 選択枠 path が SwiftUI overlay と同じ上原点座標を使い、Y 反転しないことを検証します。
    @Test("選択枠はSwiftUI overlayと同じY座標を使う")
    func testBorderRectKeepsTopOriginCoordinates() {
        // コンディション：document 内で上から 32pt 下がった page body 矩形を用意する（Given）
        let rect = CGRect(x: 24, y: 32, width: 1440, height: 1200)

        // 検証内容：layer path 用の選択枠矩形を計算する（When）
        let borderRect = CanvasSelectionChromeLayerGeometry.borderRect(for: rect, lineWidth: 2)

        // 期待値：stroke 分だけ内側へ入り、Y 座標は document 高さ由来で反転されない（Then）
        #expect(borderRect.minX == 25)
        #expect(borderRect.minY == 33)
        #expect(borderRect.width == 1438)
        #expect(borderRect.height == 1198)
    }

    /// 論理名（日本語）: ハンドルY座標維持テスト
    /// 概要: リサイズハンドル layer position が SwiftUI hit area と同じ座標になることを検証します。
    @Test("ハンドル位置はSwiftUI hit areaと同じY座標を使う")
    func testHandlePositionKeepsTopOriginCoordinates() {
        // コンディション：上端が 32pt の選択矩形を用意する（Given）
        let rect = CGRect(x: 24, y: 32, width: 1440, height: 1200)

        // 検証内容：左上と下辺中央の handle position を計算する（When）
        let topLeft = CanvasSelectionChromeLayerGeometry.handlePosition(for: .topLeft, in: rect)
        let bottom = CanvasSelectionChromeLayerGeometry.handlePosition(for: .bottom, in: rect)

        // 期待値：左上は rect.minY、下辺は rect.maxY を使い、document 高さで反転されない（Then）
        #expect(topLeft == CGPoint(x: 24, y: 32))
        #expect(bottom == CGPoint(x: 744, y: 1232))
    }
}
