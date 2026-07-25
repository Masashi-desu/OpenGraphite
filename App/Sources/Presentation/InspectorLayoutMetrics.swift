import SwiftUI

/// 論理名（日本語）: インスペクターレイアウトメトリクス
/// 概要: 右 Inspector が Canvas を過度に覆わないための幅と、入力欄が見切れない下限幅をまとめます。
///
/// 定義内容:
/// - `preferredWidth`: 余裕がある場合に使う Inspector 幅。
/// - `minimumWidth`: 入力欄が見切れない下限幅。
/// - `maximumRemainingWidthFraction`: 左カラムを除いた残り幅に対して割り当てる比率。
/// - `fieldGridMinimumWidth`: 複数列へ畳む入力欄の下限幅。
enum InspectorLayoutMetrics {
    static let preferredWidth: CGFloat = 292
    static let minimumWidth: CGFloat = 264
    static let maximumRemainingWidthFraction: CGFloat = 0.36
    static let fieldGridMinimumWidth: CGFloat = 152

    /// 論理名（日本語）: インスペクター幅解決関数
    /// 処理概要: 左カラムを除いた残り幅へ比率で割り当てつつ、入力欄が見切れない下限幅を確保します。残り幅自体が下限に満たない場合は残り幅をそのまま使います。
    ///
    /// - Parameters:
    ///   - availableWindowWidth: 現在のウインドウ幅。
    ///   - leadingColumnWidth: 表示中の左カラム幅。
    /// - Returns: ウインドウ幅に応じた Inspector 幅。
    static func resolvedWidth(availableWindowWidth: CGFloat, leadingColumnWidth: CGFloat) -> CGFloat {
        let remainingWidth = max(availableWindowWidth - leadingColumnWidth, 0)
        guard remainingWidth > 0 else { return 0 }

        let proportionalWidth = remainingWidth * maximumRemainingWidthFraction
        let requestedWidth = max(minimumWidth, proportionalWidth)
        return min(preferredWidth, requestedWidth, remainingWidth)
    }
}
