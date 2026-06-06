import Foundation

/// 論理名（日本語）: ページキャンバスアスペクト比
/// 概要: Canvas の width / height 比率を保持し、片方の寸法からもう片方を算出します。
///
/// プロパティ:
/// - `value`: `width / height` の比率。
struct PageCanvasAspectRatio: Equatable {
    var value: Double

    /// 論理名（日本語）: ページキャンバスアスペクト比初期化関数
    /// 処理概要: 正の有限値の width / height から比率を生成します。
    ///
    /// - Parameters:
    ///   - width: ページプレビュー幅。
    ///   - height: ページプレビュー高さ。
    init?(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }
        value = width / height
    }

    /// 論理名（日本語）: 幅基準高さ算出関数
    /// 処理概要: 固定されたアスペクト比を保つ高さを width から計算します。
    ///
    /// - Parameter width: 基準にする幅。
    /// - Returns: 算出できる場合は高さ。
    func height(forWidth width: Double) -> Double? {
        guard width.isFinite, width > 0, value.isFinite, value > 0 else {
            return nil
        }
        return width / value
    }

    /// 論理名（日本語）: 高さ基準幅算出関数
    /// 処理概要: 固定されたアスペクト比を保つ幅を height から計算します。
    ///
    /// - Parameter height: 基準にする高さ。
    /// - Returns: 算出できる場合は幅。
    func width(forHeight height: Double) -> Double? {
        guard height.isFinite, height > 0, value.isFinite, value > 0 else {
            return nil
        }
        return height * value
    }
}
