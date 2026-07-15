import Foundation

/// 論理名（日本語）: キャンバスガイド方向
/// 概要: `.ogp` の Chapter / Collection キャンバスへ保存する補助線の方向を表します。
///
/// 定義内容:
/// - `horizontal`: Y 座標へ配置する水平ガイド。
/// - `vertical`: X 座標へ配置する垂直ガイド。
enum OpenGraphiteCanvasGuideOrientation: String, Codable, Equatable {
    case horizontal
    case vertical
}

/// 論理名（日本語）: キャンバスガイド
/// 概要: Chapter / Collection のキャンバス座標系に配置し、`.ogp` へ保存する補助線を表します。
///
/// プロパティ:
/// - `internalID`: `.ogp` 内でガイドを一意に指す内部識別子。
/// - `orientation`: 水平または垂直の方向。
/// - `position`: 垂直ガイドでは X、水平ガイドでは Y の world 座標。
struct OpenGraphiteCanvasGuide: Codable, Equatable, Identifiable {
    static let maximumCoordinateMagnitude = 1_000_000.0

    var internalID: String
    var orientation: OpenGraphiteCanvasGuideOrientation
    var position: Double

    var id: String { internalID }

    private enum CodingKeys: String, CodingKey {
        case internalID
        case orientation
        case position
    }

    /// 論理名（日本語）: キャンバスガイド初期化関数
    /// 処理概要: ガイド方向と有限な world 座標を安全範囲へ正規化して構成します。
    ///
    /// - Parameters:
    ///   - internalID: `.ogp` 内部 ID。空の場合は project 正規化時に補完されます。
    ///   - orientation: 水平または垂直の方向。
    ///   - position: 垂直なら X、水平なら Y の world 座標。
    init(
        internalID: String = "",
        orientation: OpenGraphiteCanvasGuideOrientation,
        position: Double
    ) {
        self.internalID = internalID
        self.orientation = orientation
        self.position = Self.normalizedPosition(position) ?? 0
    }

    /// 論理名（日本語）: キャンバスガイドデコード初期化関数
    /// 処理概要: 旧 project の未指定内部 ID を許容し、座標を通常初期化と同じ規則で正規化します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            internalID: try container.decodeIfPresent(String.self, forKey: .internalID) ?? "",
            orientation: try container.decode(OpenGraphiteCanvasGuideOrientation.self, forKey: .orientation),
            position: try container.decode(Double.self, forKey: .position)
        )
    }

    /// 論理名（日本語）: キャンバスガイドエンコード関数
    /// 処理概要: 未補完の内部 ID を省略し、方向と正規化済み座標を `.ogp` JSON へ保存します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !internalID.isEmpty {
            try container.encode(internalID, forKey: .internalID)
        }
        try container.encode(orientation, forKey: .orientation)
        try container.encode(position, forKey: .position)
    }

    /// 論理名（日本語）: ガイド座標正規化関数
    /// 処理概要: 非有限値を拒否し、有限値をキャンバス描画の安全範囲へ収めます。
    ///
    /// - Parameter value: 正規化前の world 座標。
    /// - Returns: 保存可能な有限座標。非有限値は `nil`。
    static func normalizedPosition(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, -maximumCoordinateMagnitude), maximumCoordinateMagnitude)
    }
}
