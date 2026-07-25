import Foundation

/// 論理名（日本語）: キャンバスオブジェクト参照
/// 概要: Chapter / Collection キャンバス直下へ配置する、HTMLノード正本への編集可能な参照を表します。
///
/// プロパティ:
/// - `internalID`: `.ogp` 内で参照配置を一意に指す内部 ID。
/// - `referenceID`: 参照元ノードを指す `ogref:node` または `ogref:component-node`。
/// - `x`: キャンバス world 座標の X 位置。
/// - `y`: キャンバス world 座標の Y 位置。
/// - `width`: 参照元nodeを等倍以下で収める最大表示幅。
/// - `height`: 参照元nodeを等倍以下で収める最大表示高さ。
struct OpenGraphiteCanvasReference: Codable, Equatable, Identifiable {
    static let defaultWidth = 360.0
    static let defaultHeight = 240.0
    static let minimumDimension = 40.0
    static let maximumDimension = 16_384.0
    static let maximumCoordinateMagnitude = 1_000_000.0

    var internalID: String
    var referenceID: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var id: String { internalID }

    /// UI表示向けの参照最大表示領域。
    var resolutionLabel: String {
        "\(Self.displayValue(width)) x \(Self.displayValue(height))"
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照初期化関数
    /// 処理概要: 参照元IDとworld座標、最大表示領域を正規化して参照配置を構成します。
    ///
    /// - Parameters:
    ///   - internalID: `.ogp` 内で一意な配置 ID。
    ///   - referenceID: 参照元ノードの typed 参照 ID。
    ///   - x: キャンバス world X 座標。
    ///   - y: キャンバス world Y 座標。
    ///   - width: 参照元nodeを収める最大表示幅。
    ///   - height: 参照元nodeを収める最大表示高さ。
    init(
        internalID: String = "",
        referenceID: String,
        x: Double,
        y: Double,
        width: Double = OpenGraphiteCanvasReference.defaultWidth,
        height: Double = OpenGraphiteCanvasReference.defaultHeight
    ) {
        self.internalID = internalID
        self.referenceID = referenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.x = Self.normalizedCoordinate(x)
        self.y = Self.normalizedCoordinate(y)
        self.width = Self.normalizedDimension(width, fallback: Self.defaultWidth)
        self.height = Self.normalizedDimension(height, fallback: Self.defaultHeight)
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照正規化関数
    /// 処理概要: 外部編集された参照配置の文字列と座標、寸法を安全な保存値へ揃えます。
    ///
    /// - Returns: 正規化済み参照配置。
    func normalized() -> OpenGraphiteCanvasReference {
        OpenGraphiteCanvasReference(
            internalID: internalID,
            referenceID: referenceID,
            x: x,
            y: y,
            width: width,
            height: height
        )
    }

    /// 論理名（日本語）: キャンバス参照座標正規化関数
    /// 処理概要: 非有限値を0へ戻し、world座標を安全範囲へ収めます。
    ///
    /// - Parameter value: 正規化する座標。
    /// - Returns: 有限で安全範囲内の座標。
    private static func normalizedCoordinate(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -maximumCoordinateMagnitude), maximumCoordinateMagnitude)
    }

    /// 論理名（日本語）: キャンバス参照寸法正規化関数
    /// 処理概要: 非有限値を既定値へ戻し、参照の最大表示寸法を正の安全範囲へ収めます。
    ///
    /// - Parameters:
    ///   - value: 正規化する寸法。
    ///   - fallback: 非有限値で使う既定寸法。
    /// - Returns: 正の安全範囲内の寸法。
    private static func normalizedDimension(_ value: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, minimumDimension), maximumDimension)
    }

    /// 論理名（日本語）: 参照寸法表示関数
    /// 処理概要: 参照最大表示領域の寸法を整数優先の短いUI表示へ変換します。
    ///
    /// - Parameter value: 表示する参照最大表示領域の寸法。
    /// - Returns: 整数に近い値は整数、それ以外は小数1桁の文字列。
    private static func displayValue(_ value: Double) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", value)
    }
}
