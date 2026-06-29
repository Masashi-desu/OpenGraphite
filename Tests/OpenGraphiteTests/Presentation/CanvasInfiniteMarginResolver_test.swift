import CoreGraphics
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス無限余白解決関連のテストスイート
/// 概要: wheel 入力中に無限キャンバスの余白を伸縮する量を検証します。
@Suite("キャンバス無限余白解決関連のテストスイート")
struct CanvasInfiniteMarginResolverTests {
    /// 論理名（日本語）: 小さい拡張量の丸めテスト
    /// 概要: trackpad の細かい delta でも余白追加が小刻みにならないことを検証します。
    @Test("小さいwheel入力でもまとまった余白を追加する")
    func testExpansionAmountUsesMinimumChunkForSmallDelta() {
        // コンディション：trackpad 由来の小さいスクロール入力を用意する（Given）
        let smallDelta: CGFloat = 6

        // 検証内容：無限キャンバスの拡張量を計算する（When）
        let amount = CanvasInfiniteMarginResolver.expansionAmount(for: smallDelta)

        // 期待値：小刻みな documentView resize を避けるため最小チャンク量へ丸められる（Then）
        #expect(amount == CanvasInfiniteMarginResolver.minimumExpansionStep)
    }

    /// 論理名（日本語）: 大きい拡張量の上限テスト
    /// 概要: 大きな wheel 入力でも一度の余白追加が過大にならないことを検証します。
    @Test("大きいwheel入力は最大余白量に制限する")
    func testExpansionAmountCapsLargeDelta() {
        // コンディション：大きなスクロール入力を用意する（Given）
        let largeDelta: CGFloat = 2_000

        // 検証内容：無限キャンバスの拡張量を計算する（When）
        let amount = CanvasInfiniteMarginResolver.expansionAmount(for: largeDelta)

        // 期待値：一度に増える documentView サイズが最大チャンク量へ制限される（Then）
        #expect(amount == CanvasInfiniteMarginResolver.maximumExpansionStep)
    }

    /// 論理名（日本語）: 小さい先頭余白縮小抑止テスト
    /// 概要: 左上側の余白削除が細かいスクロールごとに発生しないことを検証します。
    @Test("小さい先頭余白縮小は抑止する")
    func testLeadingContractionIgnoresSmallReclaimableMargin() {
        // コンディション：削除できる余白が最小縮小量に満たない状態を用意する（Given）
        let visibleStart = CanvasInfiniteMarginResolver.contractionPadding + 40

        // 検証内容：先頭余白の削除量を計算する（When）
        let contraction = CanvasInfiniteMarginResolver.leadingContractionAmount(
            currentLeadingInset: 500,
            visibleStart: visibleStart
        )

        // 期待値：小刻みな documentView resize を避けるため削除しない（Then）
        #expect(contraction == 0)
    }

    /// 論理名（日本語）: 末尾余白縮小チャンクテスト
    /// 概要: 右下側の未使用余白が十分大きいときだけ documentView を縮小することを検証します。
    @Test("末尾余白は十分大きい場合だけ縮小する")
    func testTrailingContractionUsesMinimumChunk() {
        // コンディション：削除候補が小さい場合と十分大きい場合の documentView サイズを用意する（Given）
        let minimumSize: CGFloat = 1_000
        let visibleEnd: CGFloat = 1_200
        let smallCurrentSize: CGFloat = visibleEnd + CanvasInfiniteMarginResolver.contractionPadding + 40
        let largeCurrentSize: CGFloat = visibleEnd + CanvasInfiniteMarginResolver.contractionPadding + 400

        // 検証内容：末尾余白を削った documentView サイズを計算する（When）
        let smallResult = CanvasInfiniteMarginResolver.trailingContractionSize(
            currentSize: smallCurrentSize,
            minimumSize: minimumSize,
            visibleEnd: visibleEnd
        )
        let largeResult = CanvasInfiniteMarginResolver.trailingContractionSize(
            currentSize: largeCurrentSize,
            minimumSize: minimumSize,
            visibleEnd: visibleEnd
        )

        // 期待値：小さい余白は残し、十分大きい余白だけ padding 境界まで縮小する（Then）
        #expect(smallResult == smallCurrentSize)
        #expect(largeResult == visibleEnd + CanvasInfiniteMarginResolver.contractionPadding)
    }
}
