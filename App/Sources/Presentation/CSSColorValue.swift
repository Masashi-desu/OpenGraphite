import AppKit
import Foundation
import SwiftUI

/// 論理名（日本語）: CSS色値
/// 概要: Inspector の ColorPicker と HTML inline style の CSS 色文字列を相互変換する値です。
///
/// プロパティ:
/// - `red`: sRGB の赤成分。0.0 から 1.0 の範囲で保持します。
/// - `green`: sRGB の緑成分。0.0 から 1.0 の範囲で保持します。
/// - `blue`: sRGB の青成分。0.0 から 1.0 の範囲で保持します。
/// - `alpha`: 不透明度。0.0 から 1.0 の範囲で保持します。
struct CSSColorValue: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    /// 論理名（日本語）: CSS色値初期化関数
    /// 処理概要: sRGB の各成分を 0.0 から 1.0 に正規化して保持します。
    ///
    /// - Parameters:
    ///   - red: 赤成分。
    ///   - green: 緑成分。
    ///   - blue: 青成分。
    ///   - alpha: 不透明度。
    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
        self.alpha = Self.clamped(alpha)
    }

    /// 論理名（日本語）: CSS文字列初期化関数
    /// 処理概要: HEX、rgb()、rgba() の CSS 色文字列を sRGB 成分へ変換します。
    ///
    /// - Parameter cssString: HTML inline style から取得した CSS 色文字列。
    init?(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let hexColor = Self.hexColor(from: trimmed) {
            self = hexColor
            return
        }

        if let rgbColor = Self.rgbFunctionColor(from: trimmed) {
            self = rgbColor
            return
        }

        return nil
    }

    /// 論理名（日本語）: SwiftUI色初期化関数
    /// 処理概要: SwiftUI の ColorPicker から受け取った色を sRGB 成分へ変換します。
    ///
    /// - Parameter color: ColorPicker で選択された色。
    init?(color: Color) {
        let nsColor = NSColor(color)
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            return nil
        }

        self.init(
            red: Double(srgbColor.redComponent),
            green: Double(srgbColor.greenComponent),
            blue: Double(srgbColor.blueComponent),
            alpha: Double(srgbColor.alphaComponent)
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var cssHexString: String {
        let redByte = Self.byteValue(red)
        let greenByte = Self.byteValue(green)
        let blueByte = Self.byteValue(blue)
        let alphaByte = Self.byteValue(alpha)

        if alphaByte < 255 {
            return String(format: "#%02X%02X%02X%02X", redByte, greenByte, blueByte, alphaByte)
        }

        return String(format: "#%02X%02X%02X", redByte, greenByte, blueByte)
    }

    /// 論理名（日本語）: HEX色解析関数
    /// 処理概要: `#RGB`、`#RGBA`、`#RRGGBB`、`#RRGGBBAA` の CSS HEX 色を解析します。
    ///
    /// - Parameter value: 解析対象の CSS 文字列。
    /// - Returns: 解析できた CSS 色値。対象外の文字列では nil を返します。
    private static func hexColor(from value: String) -> CSSColorValue? {
        guard value.hasPrefix("#") else { return nil }

        let digits = String(value.dropFirst())
        let expandedDigits: String
        switch digits.count {
        case 3, 4:
            expandedDigits = digits.reduce(into: "") { result, character in
                result.append(character)
                result.append(character)
            }
        case 6, 8:
            expandedDigits = digits
        default:
            return nil
        }

        guard let rawValue = UInt64(expandedDigits, radix: 16) else {
            return nil
        }

        if expandedDigits.count == 6 {
            return CSSColorValue(
                red: Double((rawValue >> 16) & 0xff) / 255,
                green: Double((rawValue >> 8) & 0xff) / 255,
                blue: Double(rawValue & 0xff) / 255
            )
        }

        return CSSColorValue(
            red: Double((rawValue >> 24) & 0xff) / 255,
            green: Double((rawValue >> 16) & 0xff) / 255,
            blue: Double((rawValue >> 8) & 0xff) / 255,
            alpha: Double(rawValue & 0xff) / 255
        )
    }

    /// 論理名（日本語）: RGB関数色解析関数
    /// 処理概要: カンマ区切りの `rgb()` と `rgba()` を CSS 色値へ変換します。
    ///
    /// - Parameter value: 解析対象の CSS 文字列。
    /// - Returns: 解析できた CSS 色値。対象外の文字列では nil を返します。
    private static func rgbFunctionColor(from value: String) -> CSSColorValue? {
        let lowercasedValue = value.lowercased()
        let isRGB = lowercasedValue.hasPrefix("rgb(")
        let isRGBA = lowercasedValue.hasPrefix("rgba(")
        guard (isRGB || isRGBA), lowercasedValue.hasSuffix(")") else {
            return nil
        }

        let prefixLength = isRGBA ? "rgba(".count : "rgb(".count
        let start = value.index(value.startIndex, offsetBy: prefixLength)
        let end = value.index(before: value.endIndex)
        let body = value[start..<end]
        let parts = body.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard (isRGB && parts.count == 3) || (isRGBA && parts.count == 4),
              let red = channelValue(from: parts[0]),
              let green = channelValue(from: parts[1]),
              let blue = channelValue(from: parts[2])
        else {
            return nil
        }

        let alpha = parts.count == 4 ? alphaValue(from: parts[3]) : 1
        guard let alpha else { return nil }

        return CSSColorValue(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// 論理名（日本語）: 色チャンネル解析関数
    /// 処理概要: RGB チャンネルの数値またはパーセント表記を 0.0 から 1.0 へ変換します。
    ///
    /// - Parameter value: RGB チャンネル文字列。
    /// - Returns: 正規化されたチャンネル値。
    private static func channelValue(from value: String) -> Double? {
        if value.hasSuffix("%") {
            let percentString = String(value.dropLast())
            guard let percent = Double(percentString) else { return nil }
            return clamped(percent / 100)
        }

        guard let component = Double(value) else { return nil }
        return clamped(component / 255)
    }

    /// 論理名（日本語）: アルファ値解析関数
    /// 処理概要: alpha チャンネルの数値またはパーセント表記を 0.0 から 1.0 へ変換します。
    ///
    /// - Parameter value: alpha チャンネル文字列。
    /// - Returns: 正規化された alpha 値。
    private static func alphaValue(from value: String) -> Double? {
        if value.hasSuffix("%") {
            let percentString = String(value.dropLast())
            guard let percent = Double(percentString) else { return nil }
            return clamped(percent / 100)
        }

        guard let alpha = Double(value) else { return nil }
        return clamped(alpha)
    }

    /// 論理名（日本語）: バイト値変換関数
    /// 処理概要: 0.0 から 1.0 の成分値を 0 から 255 の整数へ変換します。
    ///
    /// - Parameter value: 正規化された色成分。
    /// - Returns: 8bit 色成分。
    private static func byteValue(_ value: Double) -> Int {
        Int((clamped(value) * 255).rounded())
    }

    /// 論理名（日本語）: 範囲制限関数
    /// 処理概要: 色成分値を 0.0 から 1.0 の範囲へ丸めます。
    ///
    /// - Parameter value: 入力された色成分。
    /// - Returns: 範囲制限後の値。
    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
