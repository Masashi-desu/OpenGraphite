import Foundation

/// 論理名（日本語）: キャンバス注釈数値上限
/// 概要: 外部 `.ogp` の大きな有限値が加算・描画倍率で非有限値にならないよう、保存モデルの安全な数値範囲を定義します。
enum OpenGraphiteCanvasAnnotationLimits {
    static let maximumCoordinateMagnitude = 1_000_000.0
    static let maximumDimension = 1_000_000.0
    static let maximumLineWidth = 10_000.0
    static let maximumTiltMagnitude = 1.0

    /// 論理名（日本語）: 注釈座標補正関数
    /// 処理概要: 非有限値を0へ戻し、有限値を描画可能な座標範囲へ収めます。
    static func coordinate(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -maximumCoordinateMagnitude), maximumCoordinateMagnitude)
    }

    /// 論理名（日本語）: 注釈寸法補正関数
    /// 処理概要: 非有限値を最小値へ戻し、寸法を1以上かつ安全な上限以内へ収めます。
    static func dimension(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, 1), maximumDimension)
    }

    /// 論理名（日本語）: 手書き線幅補正関数
    /// 処理概要: 非有限値を既定値へ戻し、筆圧倍率後も有限となる線幅範囲へ収めます。
    static func lineWidth(_ value: Double) -> Double {
        guard value.isFinite else { return 3.5 }
        return min(max(value, 0.5), maximumLineWidth)
    }

    /// 論理名（日本語）: スタイラス傾き補正関数
    /// 処理概要: 非有限値を0へ戻し、AppKit tablet tilt の正規化範囲へ収めます。
    static func tilt(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -maximumTiltMagnitude), maximumTiltMagnitude)
    }
}

/// 論理名（日本語）: キャンバス注釈種別
/// 概要: `.ogp` のキャンバス前面にだけ表示し、HTML / CSS 成果物へ書き出さない注釈の種類を表します。
///
/// 定義内容:
/// - `stickyNote`: テキストを記入できる付箋。
/// - `ink`: マウスまたはスタイラスで記録した手書きストローク。
enum OpenGraphiteCanvasAnnotationKind: String, Codable, Equatable {
    case stickyNote
    case ink
}

/// 論理名（日本語）: 手書き入力デバイス種別
/// 概要: 手書きストロークを生成したポインティングデバイスを CLI / MCP から判別できるように表します。
///
/// 定義内容:
/// - `mouse`: マウスまたは通常ポインター入力。
/// - `pen`: Sidecar の Apple Pencil を含むペン先入力。
/// - `eraser`: スタイラスの消しゴム側入力。
/// - `unknown`: デバイス種別を判別できなかった入力。
enum OpenGraphiteInkInputDevice: String, Codable, Equatable {
    case mouse
    case pen
    case eraser
    case unknown
}

/// 論理名（日本語）: キャンバス注釈フレーム
/// 概要: Chapter / Collection のキャンバス座標系における注釈の配置矩形を表します。
///
/// プロパティ:
/// - `x`: キャンバス上の左端 X 座標。
/// - `y`: キャンバス上の上端 Y 座標。
/// - `width`: 注釈幅。
/// - `height`: 注釈高さ。
struct OpenGraphiteCanvasAnnotationFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
    }

    /// 論理名（日本語）: キャンバス注釈フレーム初期化関数
    /// 処理概要: 非有限値を補正し、座標と寸法を描画可能な安全範囲へ正規化します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の左端 X 座標。
    ///   - y: キャンバス上の上端 Y 座標。
    ///   - width: 注釈幅。
    ///   - height: 注釈高さ。
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = OpenGraphiteCanvasAnnotationLimits.coordinate(x)
        self.y = OpenGraphiteCanvasAnnotationLimits.coordinate(y)
        self.width = OpenGraphiteCanvasAnnotationLimits.dimension(width)
        self.height = OpenGraphiteCanvasAnnotationLimits.dimension(height)
    }

    /// 論理名（日本語）: キャンバス注釈フレームデコード初期化関数
    /// 処理概要: 外部 `.ogp` の数値も通常初期化関数と同じ規則で正規化します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y),
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
    }
}

/// 論理名（日本語）: 手書きストローク点
/// 概要: 注釈フレーム左上を原点とする座標と、スタイラスの筆圧・傾きを保持します。
///
/// プロパティ:
/// - `x`: 注釈フレーム内の X 座標。
/// - `y`: 注釈フレーム内の Y 座標。
/// - `pressure`: 0 から 1 の正規化済み筆圧。
/// - `tiltX`: スタイラス傾きの X 成分。
/// - `tiltY`: スタイラス傾きの Y 成分。
struct OpenGraphiteInkPoint: Codable, Equatable {
    var x: Double
    var y: Double
    var pressure: Double
    var tiltX: Double
    var tiltY: Double

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case pressure
        case tiltX
        case tiltY
    }

    /// 論理名（日本語）: 手書きストローク点初期化関数
    /// 処理概要: 座標と傾きを安全範囲へ補正し、筆圧を 0 から 1 の範囲へ収めます。
    ///
    /// - Parameters:
    ///   - x: 注釈フレーム内の X 座標。
    ///   - y: 注釈フレーム内の Y 座標。
    ///   - pressure: 入力デバイスから得た筆圧。
    ///   - tiltX: スタイラス傾きの X 成分。
    ///   - tiltY: スタイラス傾きの Y 成分。
    init(x: Double, y: Double, pressure: Double = 1, tiltX: Double = 0, tiltY: Double = 0) {
        self.x = OpenGraphiteCanvasAnnotationLimits.coordinate(x)
        self.y = OpenGraphiteCanvasAnnotationLimits.coordinate(y)
        self.pressure = pressure.isFinite ? min(max(pressure, 0), 1) : 1
        self.tiltX = OpenGraphiteCanvasAnnotationLimits.tilt(tiltX)
        self.tiltY = OpenGraphiteCanvasAnnotationLimits.tilt(tiltY)
    }

    /// 論理名（日本語）: 手書きストローク点デコード初期化関数
    /// 処理概要: 外部 `.ogp` の筆圧と座標を通常初期化関数と同じ規則で正規化します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y),
            pressure: try container.decodeIfPresent(Double.self, forKey: .pressure) ?? 1,
            tiltX: try container.decodeIfPresent(Double.self, forKey: .tiltX) ?? 0,
            tiltY: try container.decodeIfPresent(Double.self, forKey: .tiltY) ?? 0
        )
    }
}

/// 論理名（日本語）: 手書きストローク
/// 概要: 連続する入力点と表示色、基準線幅、入力デバイスを `.ogp` に保存します。
///
/// プロパティ:
/// - `points`: 注釈フレーム内の入力点列。
/// - `color`: CSS hex 形式を基本とする線色。
/// - `lineWidth`: 筆圧を掛ける前の基準線幅。
/// - `inputDevice`: ストロークを生成した入力デバイス。
struct OpenGraphiteInkStroke: Codable, Equatable {
    var points: [OpenGraphiteInkPoint]
    var color: String
    var lineWidth: Double
    var inputDevice: OpenGraphiteInkInputDevice

    private enum CodingKeys: String, CodingKey {
        case points
        case color
        case lineWidth
        case inputDevice
    }

    /// 論理名（日本語）: 手書きストローク初期化関数
    /// 処理概要: 空の色と不正または過大な線幅を安全範囲へ補正してストロークを構成します。
    ///
    /// - Parameters:
    ///   - points: 注釈フレーム内の入力点列。
    ///   - color: ストロークの線色。
    ///   - lineWidth: 筆圧を掛ける前の基準線幅。
    ///   - inputDevice: 入力デバイス種別。
    init(
        points: [OpenGraphiteInkPoint],
        color: String = "#FF4D67",
        lineWidth: Double = 3.5,
        inputDevice: OpenGraphiteInkInputDevice = .unknown
    ) {
        self.points = points
        let normalizedColor = color.trimmingCharacters(in: .whitespacesAndNewlines)
        self.color = normalizedColor.isEmpty ? "#FF4D67" : normalizedColor
        self.lineWidth = OpenGraphiteCanvasAnnotationLimits.lineWidth(lineWidth)
        self.inputDevice = inputDevice
    }

    /// 論理名（日本語）: 手書きストロークデコード初期化関数
    /// 処理概要: 外部 `.ogp` の色と線幅を通常初期化関数と同じ規則で正規化します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            points: try container.decodeIfPresent([OpenGraphiteInkPoint].self, forKey: .points) ?? [],
            color: try container.decodeIfPresent(String.self, forKey: .color) ?? "#FF4D67",
            lineWidth: try container.decodeIfPresent(Double.self, forKey: .lineWidth) ?? 3.5,
            inputDevice: try container.decodeIfPresent(OpenGraphiteInkInputDevice.self, forKey: .inputDevice) ?? .unknown
        )
    }
}

/// 論理名（日本語）: OpenGraphiteキャンバス注釈
/// 概要: Chapter / Collection の前面へ表示する付箋または手書きを `.ogp` metadata として保持します。
///
/// プロパティ:
/// - `internalID`: `.ogp` 内で注釈を一意に指す不透明 ID。
/// - `kind`: 付箋または手書きの種別。
/// - `frame`: キャンバス座標系の配置矩形。
/// - `text`: 付箋のプレーンテキスト。
/// - `backgroundColor`: 付箋背景色。
/// - `textColor`: 付箋文字色。
/// - `strokes`: 手書き注釈に含まれるストローク一覧。
struct OpenGraphiteCanvasAnnotation: Codable, Equatable, Identifiable {
    var internalID: String
    var kind: OpenGraphiteCanvasAnnotationKind
    var frame: OpenGraphiteCanvasAnnotationFrame
    var text: String
    var backgroundColor: String
    var textColor: String
    var strokes: [OpenGraphiteInkStroke]

    var id: String { internalID }

    private enum CodingKeys: String, CodingKey {
        case internalID
        case kind
        case frame
        case text
        case backgroundColor
        case textColor
        case strokes
    }

    /// 論理名（日本語）: キャンバス注釈初期化関数
    /// 処理概要: 付箋と手書きで共有する保存モデルを明示値から構成します。
    ///
    /// - Parameters:
    ///   - internalID: `.ogp` 内部 ID。空の場合は project 正規化時に補完されます。
    ///   - kind: 注釈種別。
    ///   - frame: キャンバス上の配置矩形。
    ///   - text: 付箋テキスト。
    ///   - backgroundColor: 付箋背景色。
    ///   - textColor: 付箋文字色。
    ///   - strokes: 手書きストローク一覧。
    init(
        internalID: String = "",
        kind: OpenGraphiteCanvasAnnotationKind,
        frame: OpenGraphiteCanvasAnnotationFrame,
        text: String = "",
        backgroundColor: String = "#FFE88A",
        textColor: String = "#231F14",
        strokes: [OpenGraphiteInkStroke] = []
    ) {
        self.internalID = internalID
        self.kind = kind
        self.frame = frame
        self.text = text
        self.backgroundColor = backgroundColor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.textColor = textColor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.strokes = strokes
    }

    /// 論理名（日本語）: キャンバス注釈デコード初期化関数
    /// 処理概要: 種別固有フィールドが省略された場合に安全な既定値を補います。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            internalID: try container.decodeIfPresent(String.self, forKey: .internalID) ?? "",
            kind: try container.decode(OpenGraphiteCanvasAnnotationKind.self, forKey: .kind),
            frame: try container.decode(OpenGraphiteCanvasAnnotationFrame.self, forKey: .frame),
            text: try container.decodeIfPresent(String.self, forKey: .text) ?? "",
            backgroundColor: try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "#FFE88A",
            textColor: try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#231F14",
            strokes: try container.decodeIfPresent([OpenGraphiteInkStroke].self, forKey: .strokes) ?? []
        )
    }

    /// 論理名（日本語）: キャンバス注釈エンコード関数
    /// 処理概要: 共通フィールドと種別に必要な payload だけを `.ogp` JSON へ保存します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !internalID.isEmpty {
            try container.encode(internalID, forKey: .internalID)
        }
        try container.encode(kind, forKey: .kind)
        try container.encode(frame, forKey: .frame)

        switch kind {
        case .stickyNote:
            try container.encode(text, forKey: .text)
            if !backgroundColor.isEmpty {
                try container.encode(backgroundColor, forKey: .backgroundColor)
            }
            if !textColor.isEmpty {
                try container.encode(textColor, forKey: .textColor)
            }
        case .ink:
            try container.encode(strokes, forKey: .strokes)
        }
    }
}
