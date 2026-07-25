import AppKit
import SwiftUI

/// 論理名（日本語）: インスペクターグラデーションランプ計算
/// 概要: color stop の位置指定から、プレビュー帯へ描く 0 から 1 の停止位置を求めます。
///
/// 定義内容:
/// - `normalizedLocations(_:)`: stop 配列に対応する 0 から 1 の位置配列。
enum InspectorGradientRamp {
    /// 論理名（日本語）: グラデーション停止位置正規化関数
    /// 処理概要: `%` 指定はその値を使い、未指定の stop は等間隔へ割り当てます。
    ///
    /// - Parameter stops: 対象の color stop 配列。
    /// - Returns: 各 stop に対応する 0 から 1 の位置。
    static func normalizedLocations(_ stops: [CSSGradientStopValue]) -> [Double] {
        guard !stops.isEmpty else { return [] }
        guard stops.count > 1 else {
            return [percentageLocation(from: stops[0]) ?? 0]
        }

        var locations = stops.map(percentageLocation(from:))
        if locations[0] == nil {
            locations[0] = 0
        }
        if locations[locations.count - 1] == nil {
            locations[locations.count - 1] = 1
        }

        var previousResolvedIndex = 0
        var previousResolvedLocation = locations[0] ?? 0
        for index in locations.indices.dropFirst() {
            guard let explicitLocation = locations[index] else { continue }

            let resolvedLocation = max(previousResolvedLocation, explicitLocation)
            locations[index] = resolvedLocation
            let unresolvedCount = index - previousResolvedIndex - 1
            if unresolvedCount > 0 {
                let interval = (resolvedLocation - previousResolvedLocation) / Double(unresolvedCount + 1)
                for unresolvedIndex in (previousResolvedIndex + 1)..<index {
                    locations[unresolvedIndex] = previousResolvedLocation
                        + interval * Double(unresolvedIndex - previousResolvedIndex)
                }
            }

            previousResolvedIndex = index
            previousResolvedLocation = resolvedLocation
        }

        return locations.map { $0 ?? previousResolvedLocation }
    }

    /// 論理名（日本語）: グラデーション百分率位置解決関数
    /// 処理概要: `%` 指定の color stop をプレビュー用の 0 から 1 の位置へ丸めます。
    ///
    /// - Parameter stop: 対象の color stop。
    /// - Returns: 百分率位置。位置未指定または対象外単位の場合は nil。
    private static func percentageLocation(from stop: CSSGradientStopValue) -> Double? {
        let parts = CSSUnitSeparatedValue(cssString: stop.position)
        guard parts.isNumericLike, parts.unit == "%", let number = Double(parts.fieldValue) else {
            return nil
        }
        return min(max(number / 100, 0), 1)
    }
}

/// 論理名（日本語）: インスペクターグラデーションプレビュー帯
/// 概要: 現在の color stop をそのまま帯として描き、停止位置を目印で示す読み取り専用の表示です。
///
/// プロパティ:
/// - `stops`: 描画対象の color stop 配列。
struct InspectorGradientPreviewBar: View {
    var stops: [CSSGradientStopValue]

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(EditorColumnStyle.elevatedRowFill)

            LinearGradient(
                stops: gradientStops,
                startPoint: .leading,
                endPoint: .trailing
            )

            GeometryReader { proxy in
                ForEach(Array(locations.enumerated()), id: \.offset) { entry in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.45), lineWidth: 1))
                        .frame(width: 6, height: 6)
                        .position(x: proxy.size.width * entry.element, y: proxy.size.height - 4)
                }
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .strokeBorder(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var locations: [Double] {
        InspectorGradientRamp.normalizedLocations(stops)
    }

    private var gradientStops: [Gradient.Stop] {
        let resolvedLocations = locations
        guard !resolvedLocations.isEmpty else {
            return [
                Gradient.Stop(color: .clear, location: 0),
                Gradient.Stop(color: .clear, location: 1)
            ]
        }

        return stops.enumerated().map { index, stop in
            Gradient.Stop(
                color: CSSColorValue(cssString: stop.color)?.color ?? .clear,
                location: resolvedLocations[index]
            )
        }
    }
}

/// 論理名（日本語）: インスペクター影プレビュー
/// 概要: 現在の box-shadow 指定をそのまま適用した見本として、影の見え方を示す読み取り専用の表示です。
///
/// プロパティ:
/// - `shadow`: 描画対象の shadow 値。
struct InspectorShadowPreview: View {
    var shadow: CSSShadowValue

    private let cardSize = CGSize(width: 48, height: 26)
    private let cornerRadius: CGFloat = 6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(EditorColumnStyle.elevatedRowFill)

            card
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .strokeBorder(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var card: some View {
        if shadow.isInset {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.primary.opacity(0.16))
                .overlay(innerShadow)
                .frame(width: cardSize.width, height: cardSize.height)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.primary.opacity(0.16))
                .frame(width: cardSize.width, height: cardSize.height)
                .shadow(color: shadowColor, radius: blurRadius, x: offsetX, y: offsetY)
        }
    }

    private var innerShadow: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .inset(by: -max(blurRadius, 1))
            .stroke(shadowColor, lineWidth: max(blurRadius, 1) * 2)
            .offset(x: offsetX, y: offsetY)
            .blur(radius: max(blurRadius, 1) / 2)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var shadowColor: Color {
        CSSColorValue(cssString: shadow.color)?.color ?? Color.black.opacity(0.35)
    }

    private var offsetX: CGFloat {
        previewLength(shadow.x, limit: 10)
    }

    private var offsetY: CGFloat {
        previewLength(shadow.y, limit: 10)
    }

    private var blurRadius: CGFloat {
        max(0, previewLength(shadow.blur, limit: 12))
    }

    /// 論理名（日本語）: 影プレビュー長さ換算関数
    /// 処理概要: CSS の長さをプレビュー内に収まる範囲へ丸めます。
    ///
    /// - Parameters:
    ///   - token: 対象の CSS 長さ。
    ///   - limit: プレビューで許す最大値。
    /// - Returns: プレビューに使う長さ。
    private func previewLength(_ token: String, limit: CGFloat) -> CGFloat {
        let parts = CSSUnitSeparatedValue(cssString: token.trimmingCharacters(in: .whitespacesAndNewlines))
        guard parts.isNumericLike, let number = Double(parts.fieldValue) else { return 0 }
        return min(max(CGFloat(number), -limit), limit)
    }
}

/// 論理名（日本語）: インスペクター文字組みプレビュー計算
/// 概要: Typography セクションの見本描画に必要な font 情報を CSS 値から求めます。
///
/// 定義内容:
/// - `previewFontSize(from:)`: 見本に使う文字サイズ。
/// - `nsFontWeight(from:)`: `font-weight` に対応する太さ。
/// - `tracking(from:fontSize:)`: `letter-spacing` に対応する字送り。
/// - `lineSpacing(from:fontSize:)`: `line-height` に対応する行間。
/// - `textAlignment(from:)`: `text-align` に対応する揃え方。
enum InspectorTypographyPreviewModel {
    static let minimumPreviewFontSize: CGFloat = 11
    static let maximumPreviewFontSize: CGFloat = 30

    /// 論理名（日本語）: 見本文字サイズ解決関数
    /// 処理概要: CSS の font-size を、Inspector の見本欄へ収まる範囲へ丸めます。
    ///
    /// - Parameter token: `font-size` の CSS 値。
    /// - Returns: 見本描画に使う文字サイズ。
    static func previewFontSize(from token: String) -> CGFloat {
        let parts = CSSUnitSeparatedValue(cssString: token.trimmingCharacters(in: .whitespacesAndNewlines))
        guard parts.isNumericLike, let number = Double(parts.fieldValue), number > 0 else {
            return 15
        }

        let pixels: Double
        switch parts.unit {
        case "rem", "em":
            pixels = number * 16
        case "%":
            pixels = number * 16 / 100
        default:
            pixels = number
        }
        return min(max(CGFloat(pixels), minimumPreviewFontSize), maximumPreviewFontSize)
    }

    /// 論理名（日本語）: 見本フォント太さ解決関数
    /// 処理概要: 数値およびキーワードの `font-weight` を macOS のフォント太さへ対応付けます。
    ///
    /// - Parameter token: `font-weight` の CSS 値。
    /// - Returns: 見本描画に使うフォント太さ。
    static func nsFontWeight(from token: String) -> NSFont.Weight {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedToken {
        case "bold", "bolder":
            return .bold
        case "lighter":
            return .light
        case "normal", "":
            return .regular
        default:
            break
        }

        guard let numericWeight = Double(normalizedToken) else { return .regular }
        switch numericWeight {
        case ..<150:
            return .ultraLight
        case ..<250:
            return .thin
        case ..<350:
            return .light
        case ..<450:
            return .regular
        case ..<550:
            return .medium
        case ..<650:
            return .semibold
        case ..<750:
            return .bold
        case ..<850:
            return .heavy
        default:
            return .black
        }
    }

    /// 論理名（日本語）: 見本字送り解決関数
    /// 処理概要: `letter-spacing` を見本描画用の字送りへ換算します。
    ///
    /// - Parameters:
    ///   - token: `letter-spacing` の CSS 値。
    ///   - fontSize: 見本の文字サイズ。
    /// - Returns: 見本描画に使う字送り。
    static func tracking(from token: String, fontSize: CGFloat) -> CGFloat {
        let parts = CSSUnitSeparatedValue(cssString: token.trimmingCharacters(in: .whitespacesAndNewlines))
        guard parts.isNumericLike, let number = Double(parts.fieldValue) else { return 0 }

        switch parts.unit {
        case "em":
            return fontSize * CGFloat(number)
        case "rem":
            return 16 * CGFloat(number)
        case "%":
            return fontSize * CGFloat(number) / 100
        default:
            return CGFloat(number)
        }
    }

    /// 論理名（日本語）: 見本行間解決関数
    /// 処理概要: `line-height` を見本描画用の行間へ換算します。
    ///
    /// - Parameters:
    ///   - token: `line-height` の CSS 値。
    ///   - fontSize: 見本の文字サイズ。
    /// - Returns: 見本描画に使う行間。
    static func lineSpacing(from token: String, fontSize: CGFloat) -> CGFloat {
        let parts = CSSUnitSeparatedValue(cssString: token.trimmingCharacters(in: .whitespacesAndNewlines))
        guard parts.isNumericLike, let number = Double(parts.fieldValue), number > 0 else { return 0 }

        let lineHeight: CGFloat
        switch parts.unit {
        case "", "em":
            lineHeight = fontSize * CGFloat(number)
        case "rem":
            lineHeight = 16 * CGFloat(number)
        case "%":
            lineHeight = fontSize * CGFloat(number) / 100
        default:
            lineHeight = CGFloat(number)
        }
        return max(0, lineHeight - fontSize)
    }

    /// 論理名（日本語）: 見本文字揃え解決関数
    /// 処理概要: `text-align` を見本描画用の揃え方へ対応付けます。
    ///
    /// - Parameter token: `text-align` の CSS 値。
    /// - Returns: 見本描画に使う揃え方。
    static func textAlignment(from token: String) -> TextAlignment {
        switch token.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "center":
            return .center
        case "right", "end":
            return .trailing
        default:
            return .leading
        }
    }
}

/// 論理名（日本語）: インスペクター文字組みプレビュー
/// 概要: Typography セクションの指定をそのまま反映した見本を表示する、読み取り専用の表示です。
///
/// プロパティ:
/// - `sampleText`: 見本に表示する文言。
/// - `cssFontFamily`: 反映する `font-family` の CSS 値。
/// - `fontSize`: `font-size` の CSS 値。
/// - `fontWeight`: `font-weight` の CSS 値。
/// - `lineHeight`: `line-height` の CSS 値。
/// - `letterSpacing`: `letter-spacing` の CSS 値。
/// - `textAlign`: `text-align` の CSS 値。
struct InspectorTypographyPreview: View {
    var sampleText: String
    var cssFontFamily: String
    var fontSize: String
    var fontWeight: String
    var lineHeight: String
    var letterSpacing: String
    var textAlign: String

    var body: some View {
        Text(sampleText.isEmpty ? OpenGraphiteFontLibrary.defaultSampleText : sampleText)
            .font(Font(previewFont as CTFont))
            .tracking(InspectorTypographyPreviewModel.tracking(from: letterSpacing, fontSize: previewFontSize))
            .lineSpacing(InspectorTypographyPreviewModel.lineSpacing(from: lineHeight, fontSize: previewFontSize))
            .multilineTextAlignment(InspectorTypographyPreviewModel.textAlignment(from: textAlign))
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: previewAlignment)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .strokeBorder(EditorColumnStyle.separatorColor, lineWidth: 1)
            )
            .allowsHitTesting(false)
            .accessibilityLabel("文字組みプレビュー")
    }

    private var previewFontSize: CGFloat {
        InspectorTypographyPreviewModel.previewFontSize(from: fontSize)
    }

    private var previewAlignment: Alignment {
        switch InspectorTypographyPreviewModel.textAlignment(from: textAlign) {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }

    private var previewFont: NSFont {
        let candidate = OpenGraphiteFontLibrary.candidate(matching: cssFontFamily)
            ?? OpenGraphiteFontLibrary.customCandidate(cssFamily: cssFontFamily)
        return OpenGraphiteFontPreviewResolver.nsFont(
            for: candidate,
            size: previewFontSize,
            weight: InspectorTypographyPreviewModel.nsFontWeight(from: fontWeight)
        )
    }
}
