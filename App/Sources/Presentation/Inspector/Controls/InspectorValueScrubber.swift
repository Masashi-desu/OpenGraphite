import AppKit
import SwiftUI

/// 論理名（日本語）: インスペクター値スクラブ計算
/// 概要: 数値付き CSS token を、Inspector 上の水平ドラッグ量から連続的に増減させる計算をまとめます。
///
/// 定義内容:
/// - `defaultPointsPerStep`: 1 段階変化させるために必要なドラッグ距離。
/// - `stepMultiplier(for:)`: 修飾キーによる 1 段階あたりの倍率。
/// - `isScrubbable(_:)`: 現在値がドラッグ編集の対象かどうか。
/// - `scrubbed(base:translation:step:pointsPerStep:fallbackUnit:allowsNegative:modifiers:)`: ドラッグ後の CSS token。
enum InspectorValueScrubber {
    static let defaultPointsPerStep: CGFloat = 3

    /// 論理名（日本語）: スクラブ倍率解決関数
    /// 処理概要: shift で 10 倍、option で 1/10 の粒度になるよう修飾キーから倍率を返します。
    ///
    /// - Parameter modifiers: ドラッグ中に押されている修飾キー。
    /// - Returns: 1 段階あたりの倍率。
    static func stepMultiplier(for modifiers: NSEvent.ModifierFlags) -> Double {
        if modifiers.contains(.shift) { return 10 }
        if modifiers.contains(.option) { return 0.1 }
        return 1
    }

    /// 論理名（日本語）: スクラブ可否判定関数
    /// 処理概要: 未設定または数値系 token だけをドラッグ編集の対象として扱います。
    ///
    /// - Parameter token: 判定対象の CSS token。
    /// - Returns: ドラッグ編集できる場合は true。
    static func isScrubbable(_ token: String) -> Bool {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return true }
        return CSSUnitSeparatedValue(cssString: normalizedToken).isNumericLike
    }

    /// 論理名（日本語）: スクラブ後CSS値生成関数
    /// 処理概要: ドラッグ開始時の値と水平移動量から次の数値を求め、単位を保ったまま CSS token へ戻します。
    ///
    /// - Parameters:
    ///   - base: ドラッグ開始時点の CSS token。
    ///   - translation: ドラッグ開始点からの水平移動量。
    ///   - step: 1 段階あたりの変化量。
    ///   - pointsPerStep: 1 段階変化させるために必要なドラッグ距離。
    ///   - fallbackUnit: 元の値が未設定または単位なしのときに補う単位。
    ///   - allowsNegative: 負値を許可するかどうか。
    ///   - modifiers: ドラッグ中に押されている修飾キー。
    /// - Returns: 次の CSS token。数値として扱えない場合は nil。
    static func scrubbed(
        base: String,
        translation: CGFloat,
        step: Double = 1,
        pointsPerStep: CGFloat = defaultPointsPerStep,
        fallbackUnit: String = "",
        allowsNegative: Bool = true,
        modifiers: NSEvent.ModifierFlags = []
    ) -> String? {
        guard pointsPerStep > 0, step > 0 else { return nil }

        let normalizedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseNumber: Double
        let unit: String

        if normalizedBase.isEmpty {
            baseNumber = 0
            unit = fallbackUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let parts = CSSUnitSeparatedValue(cssString: normalizedBase)
            guard parts.isNumericLike, let number = Double(parts.fieldValue) else { return nil }
            baseNumber = number
            unit = parts.unit.isEmpty
                ? fallbackUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                : parts.unit
        }

        let resolvedStep = step * stepMultiplier(for: modifiers)
        let stepCount = (translation / pointsPerStep).rounded(.towardZero)
        guard stepCount != 0 else { return normalizedBase }

        var nextNumber = baseNumber + Double(stepCount) * resolvedStep
        if !allowsNegative {
            nextNumber = max(0, nextNumber)
        }
        if normalizedBase.isEmpty, nextNumber == 0 {
            return normalizedBase
        }

        return "\(formattedNumber(nextNumber))\(unit)"
    }

    /// 論理名（日本語）: スクラブ数値整形関数
    /// 処理概要: 浮動小数点誤差を落とし、整数値は小数点なしの文字列として返します。
    ///
    /// - Parameter value: 整形対象の数値。
    /// - Returns: CSS token に使う数値文字列。
    static func formattedNumber(_ value: Double) -> String {
        let roundedValue = (value * 1000).rounded() / 1000
        guard roundedValue.isFinite else { return "0" }

        if roundedValue == roundedValue.rounded(), abs(roundedValue) < 1_000_000_000 {
            return String(Int(roundedValue))
        }

        var text = String(format: "%.3f", roundedValue)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }
}

/// 論理名（日本語）: インスペクター値スクラブハンドル
/// 概要: 入力欄のアイコンやラベルを掴んで左右にドラッグすることで、数値を直接増減させるハンドルです。
///
/// プロパティ:
/// - `isEnabled`: ドラッグ編集を有効にするか。
/// - `step`: 1 段階あたりの変化量。
/// - `fallbackUnit`: 未設定値をドラッグしたときに補う単位。
/// - `allowsNegative`: 負値を許可するかどうか。
/// - `currentValue`: ドラッグ開始時に読み取る現在値。
/// - `onScrub`: ドラッグ中の値を UI 状態へ反映する処理。
/// - `onCommit`: ドラッグ終了時の確定処理。
/// - `label`: ドラッグ対象として表示する内容。
struct InspectorScrubHandle<Label: View>: View {
    var isEnabled: Bool = true
    var step: Double = 1
    var fallbackUnit: String = ""
    var allowsNegative: Bool = true
    var currentValue: () -> String
    var onScrub: (String) -> Void
    var onCommit: () -> Void = {}
    @ViewBuilder var label: Label

    @State private var dragBaseValue: String?
    @State private var didPushCursor = false

    var body: some View {
        label
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onHover(perform: updateCursor)
            .onDisappear(perform: popCursorIfNeeded)
            .accessibilityHint(isEnabled ? "左右ドラッグで値を変更できます" : "")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gestureValue in
                guard isEnabled else { return }
                let baseValue = dragBaseValue ?? currentValue()
                if dragBaseValue == nil {
                    dragBaseValue = baseValue
                }

                guard let nextValue = InspectorValueScrubber.scrubbed(
                    base: baseValue,
                    translation: gestureValue.translation.width,
                    step: step,
                    fallbackUnit: fallbackUnit,
                    allowsNegative: allowsNegative,
                    modifiers: NSEvent.modifierFlags
                ) else {
                    return
                }
                onScrub(nextValue)
            }
            .onEnded { _ in
                guard dragBaseValue != nil else { return }
                dragBaseValue = nil
                onCommit()
            }
    }

    /// 論理名（日本語）: スクラブカーソル更新関数
    /// 処理概要: ハンドル上にポインタがある間だけ左右リサイズカーソルへ切り替えます。
    ///
    /// - Parameter isHovering: ポインタがハンドル上にあるかどうか。
    private func updateCursor(_ isHovering: Bool) {
        guard isEnabled else {
            popCursorIfNeeded()
            return
        }

        if isHovering {
            guard !didPushCursor else { return }
            NSCursor.resizeLeftRight.push()
            didPushCursor = true
        } else {
            popCursorIfNeeded()
        }
    }

    /// 論理名（日本語）: スクラブカーソル復帰関数
    /// 処理概要: 自身が積んだカーソルだけを取り除き、カーソルスタックの不整合を防ぎます。
    private func popCursorIfNeeded() {
        guard didPushCursor else { return }
        NSCursor.pop()
        didPushCursor = false
    }
}

/// 論理名（日本語）: インスペクタースクラブ設定
/// 概要: CSS property ごとに適した 1 段階あたりの変化量、補完単位、負値許可を解決します。
///
/// プロパティ:
/// - `step`: 1 段階あたりの変化量。
/// - `fallbackUnit`: 未設定値をドラッグしたときに補う単位。
/// - `allowsNegative`: 負値を許可するかどうか。
struct InspectorScrubProfile: Equatable {
    var step: Double
    var fallbackUnit: String
    var allowsNegative: Bool

    /// 論理名（日本語）: インスペクタースクラブ設定初期化関数
    /// 処理概要: 変化量、補完単位、負値許可をまとめて保持します。
    ///
    /// - Parameters:
    ///   - step: 1 段階あたりの変化量。
    ///   - fallbackUnit: 未設定値に補う単位。
    ///   - allowsNegative: 負値を許可するかどうか。
    init(step: Double = 1, fallbackUnit: String = "px", allowsNegative: Bool = true) {
        self.step = step
        self.fallbackUnit = fallbackUnit
        self.allowsNegative = allowsNegative
    }

    static let length = InspectorScrubProfile()
    static let unsignedLength = InspectorScrubProfile(allowsNegative: false)
    static let count = InspectorScrubProfile(step: 1, fallbackUnit: "", allowsNegative: true)
    static let angle = InspectorScrubProfile(step: 1, fallbackUnit: "deg", allowsNegative: true)
    static let percentage = InspectorScrubProfile(step: 1, fallbackUnit: "%", allowsNegative: true)

    /// 論理名（日本語）: CSSプロパティ別スクラブ設定解決関数
    /// 処理概要: CSS property 名から、その値をドラッグ編集するときの粒度と単位を決めます。
    ///
    /// - Parameter key: CSS property または OpenGraphite 予約 custom property 名。
    /// - Returns: 対象 property に適したスクラブ設定。
    static func forCSSKey(_ key: String) -> InspectorScrubProfile {
        switch key {
        case "padding", "gap", "border-radius", "border":
            return .unsignedLength
        case "margin":
            return .length
        case "width", "height", "min-width", "min-height", "max-width", "max-height":
            return .unsignedLength
        case "font-size":
            return .unsignedLength
        case "letter-spacing":
            return .length
        case "font-weight":
            return InspectorScrubProfile(step: 10, fallbackUnit: "", allowsNegative: false)
        case "line-height":
            return InspectorScrubProfile(step: 0.05, fallbackUnit: "", allowsNegative: false)
        case "z-index":
            return .count
        case "scale":
            return InspectorScrubProfile(step: 0.05, fallbackUnit: "", allowsNegative: true)
        case "stroke-width":
            return InspectorScrubProfile(step: 0.25, fallbackUnit: "", allowsNegative: false)
        case "transform-origin":
            return .percentage
        default:
            return .length
        }
    }
}
