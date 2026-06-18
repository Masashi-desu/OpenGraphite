import SwiftUI

/// 論理名（日本語）: インスペクターレイアウトメトリクス
/// 概要: 右 Inspector が Canvas を過度に覆わないための幅と、狭幅用の入力欄寸法をまとめます。
enum InspectorLayoutMetrics {
    static let preferredWidth: CGFloat = 292
    static let maximumRemainingWidthFraction: CGFloat = 0.36
    static let fieldGridMinimumWidth: CGFloat = 152
    static let compactPickerWidth: CGFloat = 72

    /// 論理名（日本語）: インスペクター幅解決関数
    /// 処理概要: 左カラムを除いた残り幅に対して、下限を持たない Inspector 幅を返します。
    ///
    /// - Parameters:
    ///   - availableWindowWidth: 現在のウインドウ幅。
    ///   - leadingColumnWidth: 表示中の左カラム幅。
    /// - Returns: ウインドウ幅に応じた Inspector 幅。
    static func resolvedWidth(availableWindowWidth: CGFloat, leadingColumnWidth: CGFloat) -> CGFloat {
        let remainingWidth = max(availableWindowWidth - leadingColumnWidth, 0)
        guard remainingWidth > 0 else { return 0 }

        let proportionalWidth = remainingWidth * maximumRemainingWidthFraction
        return min(preferredWidth, proportionalWidth, remainingWidth)
    }
}
