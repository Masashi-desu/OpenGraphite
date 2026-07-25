import SwiftUI

/// 論理名（日本語）: インスペクター角丸半径
/// 概要: 角丸プレビューに描く 4 隅の表示半径をまとめます。
///
/// プロパティ:
/// - `topLeading`: 左上の表示半径。
/// - `topTrailing`: 右上の表示半径。
/// - `bottomTrailing`: 右下の表示半径。
/// - `bottomLeading`: 左下の表示半径。
struct InspectorCornerRadii: Equatable {
    var topLeading: CGFloat
    var topTrailing: CGFloat
    var bottomTrailing: CGFloat
    var bottomLeading: CGFloat

    /// 論理名（日本語）: インスペクター角丸半径初期化関数
    /// 処理概要: 4 隅の表示半径を保持します。
    ///
    /// - Parameters:
    ///   - topLeading: 左上の表示半径。
    ///   - topTrailing: 右上の表示半径。
    ///   - bottomTrailing: 右下の表示半径。
    ///   - bottomLeading: 左下の表示半径。
    init(topLeading: CGFloat, topTrailing: CGFloat, bottomTrailing: CGFloat, bottomLeading: CGFloat) {
        self.topLeading = topLeading
        self.topTrailing = topTrailing
        self.bottomTrailing = bottomTrailing
        self.bottomLeading = bottomLeading
    }
}

/// 論理名（日本語）: インスペクタープレビュー形状計算
/// 概要: CSS 値から、Inspector の読み取り専用プレビューに描く寸法を求めます。
///
/// 定義内容:
/// - `numericMagnitude(_:)`: CSS token から表示計算に使う数値の大きさを取り出す。
/// - `previewRadii(topLeading:topTrailing:bottomTrailing:bottomLeading:size:)`: 4 隅の表示半径。
enum InspectorValuePreviewGeometry {
    static let cornerReferenceValue: CGFloat = 48

    /// 論理名（日本語）: CSS数値大きさ取得関数
    /// 処理概要: CSS token の数値部分を取り出し、プレビュー計算に使う絶対値へ変換します。
    ///
    /// - Parameter token: 対象の CSS token。
    /// - Returns: 数値として解釈できた場合はその絶対値。解釈できない場合は 0。
    static func numericMagnitude(_ token: String) -> CGFloat {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return 0 }
        let parts = CSSUnitSeparatedValue(cssString: normalizedToken)
        guard parts.isNumericLike, let number = Double(parts.fieldValue) else { return 0 }
        return CGFloat(abs(number))
    }

    /// 論理名（日本語）: 角丸表示半径計算関数
    /// 処理概要: CSS の角丸値をプレビュー矩形に収まる表示半径へ換算し、`%` 指定は半分の辺長を基準にします。
    ///
    /// - Parameters:
    ///   - topLeading: 左上の CSS 値。
    ///   - topTrailing: 右上の CSS 値。
    ///   - bottomTrailing: 右下の CSS 値。
    ///   - bottomLeading: 左下の CSS 値。
    ///   - size: プレビュー矩形のサイズ。
    /// - Returns: プレビューに描く 4 隅の表示半径。
    static func previewRadii(
        topLeading: String,
        topTrailing: String,
        bottomTrailing: String,
        bottomLeading: String,
        size: CGSize
    ) -> InspectorCornerRadii {
        let limit = min(size.width, size.height) / 2
        return InspectorCornerRadii(
            topLeading: previewRadius(topLeading, limit: limit),
            topTrailing: previewRadius(topTrailing, limit: limit),
            bottomTrailing: previewRadius(bottomTrailing, limit: limit),
            bottomLeading: previewRadius(bottomLeading, limit: limit)
        )
    }

    /// 論理名（日本語）: 単一角丸表示半径計算関数
    /// 処理概要: 1 隅分の CSS 値を、プレビュー矩形に収まる表示半径へ換算します。
    ///
    /// - Parameters:
    ///   - token: 角丸の CSS 値。
    ///   - limit: 描画できる最大半径。
    /// - Returns: プレビューに描く表示半径。
    private static func previewRadius(_ token: String, limit: CGFloat) -> CGFloat {
        guard limit > 0 else { return 0 }
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return 0 }

        let parts = CSSUnitSeparatedValue(cssString: normalizedToken)
        guard parts.isNumericLike, let number = Double(parts.fieldValue), number > 0 else { return 0 }

        if parts.unit == "%" {
            return min(limit, limit * CGFloat(number) / 50)
        }
        return min(limit, CGFloat(number) * limit / cornerReferenceValue)
    }
}

/// 論理名（日本語）: インスペクター角丸プレビュー
/// 概要: 現在の 4 隅の角丸指定を、実際に丸めた小さな見本として示す読み取り専用の表示です。
///
/// プロパティ:
/// - `topLeading`: 左上の CSS 値。
/// - `topTrailing`: 右上の CSS 値。
/// - `bottomTrailing`: 右下の CSS 値。
/// - `bottomLeading`: 左下の CSS 値。
struct InspectorCornerRadiusPreview: View {
    var topLeading: String
    var topTrailing: String
    var bottomTrailing: String
    var bottomLeading: String

    private let previewSize = CGSize(width: 42, height: 26)

    var body: some View {
        let radii = InspectorValuePreviewGeometry.previewRadii(
            topLeading: topLeading,
            topTrailing: topTrailing,
            bottomTrailing: bottomTrailing,
            bottomLeading: bottomLeading,
            size: previewSize
        )

        return shape(for: radii)
            .fill(Color.accentColor.opacity(0.20))
            .overlay(
                shape(for: radii)
                    .strokeBorder(Color.accentColor.opacity(0.72), lineWidth: 1.5)
            )
            .frame(width: previewSize.width, height: previewSize.height)
            .animation(.easeInOut(duration: 0.14), value: radii)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 論理名（日本語）: 角丸プレビュー形状生成関数
    /// 処理概要: 4 隅それぞれの表示半径を持つ角丸矩形を作ります。
    ///
    /// - Parameter radii: 4 隅の表示半径。
    /// - Returns: プレビューに描く角丸矩形。
    private func shape(for radii: InspectorCornerRadii) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: radii.topLeading,
            bottomLeadingRadius: radii.bottomLeading,
            bottomTrailingRadius: radii.bottomTrailing,
            topTrailingRadius: radii.topTrailing,
            style: .continuous
        )
    }
}
