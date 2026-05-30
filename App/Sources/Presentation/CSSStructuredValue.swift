import Foundation

/// 論理名（日本語）: CSS値トークナイザー
/// 概要: CSS 関数や括弧内の空白・カンマを保ったまま、Inspector 用の簡易分割を行います。
enum CSSValueTokenizer {
    /// 論理名（日本語）: 空白区切り分割関数
    /// 処理概要: 括弧と引用符の内側を保持しながら、トップレベルの空白だけで CSS 値を分割します。
    ///
    /// - Parameter value: 分割対象の CSS 文字列。
    /// - Returns: トップレベル空白で分割された token 配列。
    static func splitWhitespace(_ value: String) -> [String] {
        split(value, separator: nil)
    }

    /// 論理名（日本語）: カンマ区切り分割関数
    /// 処理概要: 括弧と引用符の内側を保持しながら、トップレベルのカンマだけで CSS 値を分割します。
    ///
    /// - Parameter value: 分割対象の CSS 文字列。
    /// - Returns: トップレベルカンマで分割された token 配列。
    static func splitCommas(_ value: String) -> [String] {
        split(value, separator: ",")
    }

    /// 論理名（日本語）: CSS値分割関数
    /// 処理概要: 指定 separator または空白で CSS 値を分割します。
    ///
    /// - Parameters:
    ///   - value: 分割対象の CSS 文字列。
    ///   - separator: 分割文字。nil のときは空白区切りとして扱います。
    /// - Returns: 分割結果の token 配列。
    private static func split(_ value: String, separator: Character?) -> [String] {
        var tokens: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?

        func flush() {
            let token = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                tokens.append(token)
            }
            current = ""
        }

        for character in value {
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                current.append(character)
                continue
            }

            if character == "(" {
                depth += 1
                current.append(character)
                continue
            }

            if character == ")" {
                depth = max(depth - 1, 0)
                current.append(character)
                continue
            }

            if depth == 0 {
                if let separator, character == separator {
                    flush()
                    continue
                }

                if separator == nil && character.isWhitespace {
                    flush()
                    continue
                }
            }

            current.append(character)
        }

        flush()
        return tokens
    }
}

/// 論理名（日本語）: CSS四辺値
/// 概要: padding、margin、radius の CSS shorthand を 4 つの編集値として扱います。
///
/// プロパティ:
/// - `top`: 上または左上の値。
/// - `right`: 右または右上の値。
/// - `bottom`: 下または右下の値。
/// - `left`: 左または左下の値。
struct CSSBoxValue: Equatable {
    var top: String
    var right: String
    var bottom: String
    var left: String
    var unsupportedValue: String

    /// 論理名（日本語）: CSS四辺値初期化関数
    /// 処理概要: 4 つの値を trim して保持します。
    ///
    /// - Parameters:
    ///   - top: 上または左上の値。
    ///   - right: 右または右上の値。
    ///   - bottom: 下または右下の値。
    ///   - left: 左または左下の値。
    ///   - unsupportedValue: Inspector の編集対象外として保持する元の CSS 文字列。
    init(top: String = "", right: String = "", bottom: String = "", left: String = "", unsupportedValue: String = "") {
        self.top = top.trimmingCharacters(in: .whitespacesAndNewlines)
        self.right = right.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bottom = bottom.trimmingCharacters(in: .whitespacesAndNewlines)
        self.left = left.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: CSS shorthand 初期化関数
    /// 処理概要: CSS の 1 から 4 値 shorthand を四辺値へ展開します。
    ///
    /// - Parameter cssString: CSS shorthand 文字列。
    init(cssString: String) {
        let tokens = CSSValueTokenizer.splitWhitespace(cssString)
        guard tokens.allSatisfy(CSSEditingSupport.isSimpleToken) else {
            self.init(unsupportedValue: cssString)
            return
        }

        switch tokens.count {
        case 1:
            self.init(top: tokens[0], right: tokens[0], bottom: tokens[0], left: tokens[0])
        case 2:
            self.init(top: tokens[0], right: tokens[1], bottom: tokens[0], left: tokens[1])
        case 3:
            self.init(top: tokens[0], right: tokens[1], bottom: tokens[2], left: tokens[1])
        case 4:
            self.init(top: tokens[0], right: tokens[1], bottom: tokens[2], left: tokens[3])
        default:
            let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
            self.init(unsupportedValue: trimmed)
        }
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEmpty: Bool {
        [top, right, bottom, left].allSatisfy { $0.isEmpty }
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        guard !isEmpty else { return "" }
        if top == right, right == bottom, bottom == left {
            return top
        }
        if top == bottom, right == left {
            return "\(top) \(right)"
        }
        if right == left {
            return "\(top) \(right) \(bottom)"
        }
        return "\(top) \(right) \(bottom) \(left)"
    }
}

/// 論理名（日本語）: CSS二軸値
/// 概要: gap や transform-origin のような 1 から 2 値指定を編集状態として扱います。
///
/// プロパティ:
/// - `first`: 1 つ目の値。
/// - `second`: 2 つ目の値。
struct CSSPairValue: Equatable {
    var first: String
    var second: String
    var unsupportedValue: String

    /// 論理名（日本語）: CSS二軸値初期化関数
    /// 処理概要: 2 つの値を trim して保持します。
    ///
    /// - Parameters:
    ///   - first: 1 つ目の値。
    ///   - second: 2 つ目の値。
    ///   - unsupportedValue: Inspector の編集対象外として保持する元の CSS 文字列。
    init(first: String = "", second: String = "", unsupportedValue: String = "") {
        self.first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        self.second = second.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: CSS二軸値文字列初期化関数
    /// 処理概要: 1 値指定を両軸へ展開し、2 値指定をそのまま保持します。
    ///
    /// - Parameter cssString: CSS 文字列。
    init(cssString: String) {
        let tokens = CSSValueTokenizer.splitWhitespace(cssString)
        guard tokens.allSatisfy(CSSEditingSupport.isSimpleToken) else {
            self.init(unsupportedValue: cssString)
            return
        }

        switch tokens.count {
        case 1:
            self.init(first: tokens[0], second: tokens[0])
        case 2:
            self.init(first: tokens[0], second: tokens[1])
        default:
            let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
            self.init(unsupportedValue: trimmed)
        }
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEmpty: Bool {
        first.isEmpty && second.isEmpty
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        guard !isEmpty else { return "" }
        if second.isEmpty || first == second {
            return first
        }
        return "\(first) \(second)"
    }
}

/// 論理名（日本語）: CSS数値単位値
/// 概要: `72px` や `1.6` などを数値部と単位部へ分けます。
///
/// プロパティ:
/// - `number`: 数値文字列。
/// - `unit`: 単位文字列。
struct CSSNumericUnitValue: Equatable {
    var number: String
    var unit: String
    var unsupportedValue: String

    /// 論理名（日本語）: CSS数値単位値初期化関数
    /// 処理概要: 数値部と単位部を保持します。
    ///
    /// - Parameters:
    ///   - number: 数値文字列。
    ///   - unit: 単位文字列。
    ///   - unsupportedValue: Inspector の編集対象外として保持する元の CSS 文字列。
    init(number: String = "", unit: String = "", unsupportedValue: String = "") {
        self.number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: CSS数値単位値文字列初期化関数
    /// 処理概要: CSS の数値 + 単位を分解し、分解できない場合は全体を number として保持します。
    ///
    /// - Parameter cssString: CSS 文字列。
    init(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.init()
            return
        }

        guard CSSEditingSupport.isSimpleToken(trimmed), !trimmed.contains(where: { $0.isWhitespace }) else {
            self.init(unsupportedValue: trimmed)
            return
        }

        var number = ""
        var unit = ""
        var didFinishNumber = false

        for character in trimmed {
            if !didFinishNumber,
               character.isNumber || character == "." || character == "-" || character == "+" {
                number.append(character)
            } else {
                didFinishNumber = true
                unit.append(character)
            }
        }

        guard !number.isEmpty, Double(number) != nil else {
            self.init(unsupportedValue: trimmed)
            return
        }

        self.init(number: number, unit: unit)
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        return "\(number)\(unit)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 論理名（日本語）: CSS寸法値種別
/// 概要: dimension 系 CSS 値を Inspector で編集するための表示モードです。
///
/// 定義内容:
/// - `empty`: 未指定。
/// - `length`: 数値と単位。
/// - `keyword`: auto や none などのキーワード。
/// - `function`: `min()` / `max()` / `clamp()`。
/// - `unsupported`: Inspector 通常 UI の編集対象外 CSS 値。
enum CSSDimensionKind: String, CaseIterable {
    case empty
    case length
    case keyword
    case function
    case unsupported
}

/// 論理名（日本語）: CSS寸法値
/// 概要: width や height の CSS 値を、Inspector が通常 UI で編集できる範囲へ分類します。
///
/// プロパティ:
/// - `kind`: 値の種別。
/// - `primary`: 主値。
/// - `unit`: 長さ値の単位。
/// - `functionName`: CSS 関数名。
/// - `arguments`: CSS 関数引数。
/// - `unsupportedValue`: Inspector の編集対象外として保持する元の CSS 文字列。
struct CSSDimensionValue: Equatable {
    var kind: CSSDimensionKind
    var primary: String
    var unit: String
    var functionName: String
    var arguments: [String]
    var unsupportedValue: String

    /// 論理名（日本語）: CSS寸法値初期化関数
    /// 処理概要: CSS 文字列から寸法値の表示モードと編集値を決定します。
    ///
    /// - Parameter cssString: CSS 寸法文字列。
    init(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            kind = .empty
            primary = ""
            unit = "px"
            functionName = "min"
            arguments = ["", ""]
            unsupportedValue = ""
            return
        }

        if Self.keywords.contains(trimmed) {
            kind = .keyword
            primary = trimmed
            unit = "px"
            functionName = "min"
            arguments = ["", ""]
            unsupportedValue = ""
            return
        }

        if let functionValue = Self.functionParts(from: trimmed) {
            kind = .function
            primary = ""
            unit = "px"
            functionName = functionValue.name
            arguments = functionValue.arguments
            unsupportedValue = ""
            return
        }

        let numeric = CSSNumericUnitValue(cssString: trimmed)
        if numeric.isSupported, !numeric.number.isEmpty, Self.isNumericPrefix(numeric.number) {
            kind = .length
            primary = numeric.number
            unit = numeric.unit.isEmpty ? "px" : numeric.unit
            functionName = "min"
            arguments = ["", ""]
            unsupportedValue = ""
            return
        }

        kind = .unsupported
        primary = ""
        unit = "px"
        functionName = "min"
        arguments = ["", ""]
        unsupportedValue = trimmed
    }

    var cssString: String {
        switch kind {
        case .empty:
            return ""
        case .length:
            return "\(primary)\(unit)".trimmingCharacters(in: .whitespacesAndNewlines)
        case .keyword:
            return primary
        case .function:
            let args = arguments
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !args.isEmpty else { return "" }
            return "\(functionName)(\(args.joined(separator: ",")))"
        case .unsupported:
            return unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static let keywords = ["auto", "none", "inherit", "initial", "unset", "fit-content", "max-content", "min-content"]
    static let functionNames = ["min", "max", "clamp"]
    static let functionNamesWithVariableArgumentCount = ["min", "max"]

    var functionArgumentLabels: [String] {
        Self.argumentLabels(for: functionName, argumentCount: arguments.count)
    }

    var canAddFunctionArgument: Bool {
        Self.functionNamesWithVariableArgumentCount.contains(functionName)
    }

    /// 論理名（日本語）: CSS関数引数正規化関数
    /// 処理概要: CSS 関数名ごとの標準的な引数数に合わせて、Inspector 表示用の引数配列を補正します。
    ///
    /// - Parameters:
    ///   - arguments: 現在保持している引数配列。
    ///   - functionName: CSS 関数名。
    /// - Returns: Inspector 表示に必要な空欄を含む引数配列。
    static func normalizedArguments(_ arguments: [String], for functionName: String) -> [String] {
        let normalizedArguments = arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        switch functionName {
        case "clamp":
            return Array((normalizedArguments + Array(repeating: "", count: 3)).prefix(3))
        case "min", "max":
            let minimumArgumentCount = 2
            if normalizedArguments.count >= minimumArgumentCount {
                return normalizedArguments
            }
            return normalizedArguments + Array(repeating: "", count: minimumArgumentCount - normalizedArguments.count)
        default:
            return normalizedArguments.isEmpty ? [""] : normalizedArguments
        }
    }

    /// 論理名（日本語）: CSS関数引数ラベル生成関数
    /// 処理概要: CSS 関数名と引数数から Inspector の個別入力ラベルを生成します。
    ///
    /// - Parameters:
    ///   - functionName: CSS 関数名。
    ///   - argumentCount: 現在表示する引数数。
    /// - Returns: 引数入力欄に表示するラベル配列。
    static func argumentLabels(for functionName: String, argumentCount: Int) -> [String] {
        switch functionName {
        case "clamp":
            return ["Min", "Preferred", "Max"]
        default:
            let normalizedCount = max(argumentCount, 2)
            return (1...normalizedCount).map { "Arg \($0)" }
        }
    }

    /// 論理名（日本語）: CSS関数分解関数
    /// 処理概要: 対応する CSS 関数名と引数を抽出します。
    ///
    /// - Parameter value: CSS 関数文字列。
    /// - Returns: 関数名と引数。未対応の場合は nil。
    private static func functionParts(from value: String) -> (name: String, arguments: [String])? {
        guard let openIndex = value.firstIndex(of: "("),
              value.hasSuffix(")")
        else {
            return nil
        }

        let name = String(value[..<openIndex]).lowercased()
        guard functionNames.contains(name) else {
            return nil
        }

        let bodyStart = value.index(after: openIndex)
        let bodyEnd = value.index(before: value.endIndex)
        let body = String(value[bodyStart..<bodyEnd])
        return (name, CSSValueTokenizer.splitCommas(body))
    }

    /// 論理名（日本語）: 数値prefix判定関数
    /// 処理概要: CSS 長さ値の先頭が数値として扱えるかを確認します。
    ///
    /// - Parameter value: 数値候補文字列。
    /// - Returns: Double へ変換できる場合は true。
    private static func isNumericPrefix(_ value: String) -> Bool {
        Double(value) != nil
    }
}

/// 論理名（日本語）: CSS罫線値
/// 概要: border shorthand を width、style、color として扱い、対象外値は編集不可として保持します。
///
/// プロパティ:
/// - `width`: 線幅。
/// - `style`: 線種。
/// - `color`: 線色。
/// - `unsupportedValue`: Inspector の編集対象外として保持する元の CSS 文字列。
struct CSSBorderValue: Equatable {
    var width: String
    var style: String
    var color: String
    var unsupportedValue: String

    /// 論理名（日本語）: CSS罫線値初期化関数
    /// 処理概要: border shorthand を構造化します。
    ///
    /// - Parameter cssString: CSS border 文字列。
    init(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            width = ""
            style = "solid"
            color = ""
            unsupportedValue = ""
            return
        }

        var tokens = CSSValueTokenizer.splitWhitespace(trimmed)
        guard tokens.allSatisfy({ CSSEditingSupport.isSimpleToken($0) || CSSColorValue(cssString: $0) != nil }) else {
            width = ""
            style = "solid"
            color = ""
            unsupportedValue = trimmed
            return
        }

        if let styleIndex = tokens.firstIndex(where: { Self.styles.contains($0.lowercased()) }) {
            style = tokens.remove(at: styleIndex)
        } else {
            style = ""
        }

        if let firstToken = tokens.first, Self.looksLikeWidth(firstToken) {
            width = firstToken
            tokens.removeFirst()
        } else {
            width = ""
        }

        color = tokens.joined(separator: " ")
        unsupportedValue = ""

        if !color.isEmpty, CSSColorValue(cssString: color) == nil {
            unsupportedValue = trimmed
        }

        if width.isEmpty, color.isEmpty, style.isEmpty {
            unsupportedValue = trimmed
        }
    }

    /// 論理名（日本語）: 罫線幅トークン判定関数
    /// 処理概要: border shorthand の width として通常 UI で扱える token かを判定します。
    ///
    /// - Parameter token: 判定対象 token。
    /// - Returns: 数値単位または CSS の線幅キーワードであれば true。
    private static func looksLikeWidth(_ token: String) -> Bool {
        let lowercasedToken = token.lowercased()
        if widthKeywords.contains(lowercasedToken) {
            return true
        }

        let numericValue = CSSNumericUnitValue(cssString: token)
        return numericValue.isSupported && !numericValue.number.isEmpty
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        return [width, style, color]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static let styles = ["none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset"]
    private static let widthKeywords = ["thin", "medium", "thick"]
}

/// 論理名（日本語）: CSSグラデーション停止値
/// 概要: `linear-gradient()` の color stop を色と位置に分けて扱います。
///
/// プロパティ:
/// - `color`: stop の色値。
/// - `position`: stop の位置値。
struct CSSGradientStopValue: Equatable {
    var color: String
    var position: String

    /// 論理名（日本語）: CSSグラデーション停止値初期化関数
    /// 処理概要: 色と位置を trim して保持します。
    ///
    /// - Parameters:
    ///   - color: stop の色値。
    ///   - position: stop の位置値。
    init(color: String = "", position: String = "") {
        self.color = color.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: CSSグラデーション停止文字列初期化関数
    /// 処理概要: color stop 文字列を色と位置へ分割します。
    ///
    /// - Parameter cssString: color stop の CSS 文字列。
    init(cssString: String) {
        let tokens = CSSValueTokenizer.splitWhitespace(cssString)
        guard let color = tokens.first, tokens.count <= 2 else {
            self.init()
            return
        }

        self.init(color: color, position: tokens.dropFirst().joined(separator: " "))
    }

    var isSupported: Bool {
        guard !color.isEmpty, CSSColorValue(cssString: color) != nil else {
            return false
        }

        return position.isEmpty || CSSEditingSupport.isSimpleToken(position)
    }

    var cssString: String {
        [color, position]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// 論理名（日本語）: CSS線形グラデーション値
/// 概要: 一般的な `linear-gradient()` を角度と color stop 配列として扱います。
///
/// プロパティ:
/// - `angle`: 角度または方向。
/// - `stops`: color stop 配列。
struct CSSLinearGradientValue: Equatable {
    var angle: String
    var stops: [CSSGradientStopValue]

    /// 論理名（日本語）: CSS線形グラデーション値初期化関数
    /// 処理概要: angle と stop 配列を保持します。
    ///
    /// - Parameters:
    ///   - angle: 角度または方向。
    ///   - stops: gradient stop 配列。
    init(angle: String, stops: [CSSGradientStopValue]) {
        self.angle = angle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stops = stops
    }

    /// 論理名（日本語）: CSS線形グラデーション初期化関数
    /// 処理概要: `linear-gradient()` の引数を分解します。
    ///
    /// - Parameter cssString: CSS background 文字列。
    init?(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "linear-gradient("
        guard trimmed.lowercased().hasPrefix(prefix), trimmed.hasSuffix(")") else {
            return nil
        }

        let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
        let end = trimmed.index(before: trimmed.endIndex)
        let arguments = CSSValueTokenizer.splitCommas(String(trimmed[start..<end]))
        guard arguments.count >= 2 else { return nil }

        angle = arguments[0]
        let parsedStops = arguments.dropFirst().map { CSSGradientStopValue(cssString: $0) }
        guard parsedStops.allSatisfy(\.isSupported) else { return nil }
        stops = parsedStops
    }

    var cssString: String {
        let normalizedStops = stops
            .map(\.cssString)
            .filter { !$0.isEmpty }
        guard !normalizedStops.isEmpty else { return "" }
        return "linear-gradient(\(([angle] + normalizedStops).joined(separator: ",")))"
    }
}

/// 論理名（日本語）: CSS背景値種別
/// 概要: background 値の Inspector 表示モードです。
///
/// 定義内容:
/// - `empty`: 未指定。
/// - `color`: 単色。
/// - `linearGradient`: 線形グラデーション。
/// - `unsupported`: Inspector 通常 UI の編集対象外 CSS 値。
enum CSSBackgroundKind: String, CaseIterable {
    case empty
    case color
    case linearGradient
    case unsupported
}

/// 論理名（日本語）: CSS背景値
/// 概要: background 値を単色と線形グラデーションに分類し、対象外値は編集不可として保持します。
///
/// プロパティ:
/// - `kind`: 背景値種別。
/// - `color`: 単色文字列。
/// - `gradient`: 線形グラデーション値。
/// - `unsupportedValue`: Inspector の編集対象外として保持する元の CSS 文字列。
struct CSSBackgroundValue: Equatable {
    var kind: CSSBackgroundKind
    var color: String
    var gradient: CSSLinearGradientValue
    var unsupportedValue: String

    /// 論理名（日本語）: CSS背景値初期化関数
    /// 処理概要: background 文字列を単色、線形グラデーション、編集対象外値へ分類します。
    ///
    /// - Parameter cssString: CSS background 文字列。
    init(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            kind = .empty
            color = ""
            gradient = CSSLinearGradientValue(angle: "180deg", stops: Self.defaultGradientStops)
            unsupportedValue = ""
            return
        }

        if CSSColorValue(cssString: trimmed) != nil {
            kind = .color
            color = trimmed
            gradient = CSSLinearGradientValue(angle: "180deg", stops: Self.defaultGradientStops)
            unsupportedValue = ""
            return
        }

        if let parsedGradient = CSSLinearGradientValue(cssString: trimmed) {
            kind = .linearGradient
            color = ""
            gradient = parsedGradient
            unsupportedValue = ""
            return
        }

        kind = .unsupported
        color = ""
        gradient = CSSLinearGradientValue(angle: "180deg", stops: Self.defaultGradientStops)
        unsupportedValue = trimmed
    }

    var cssString: String {
        switch kind {
        case .empty:
            return ""
        case .color:
            return color.trimmingCharacters(in: .whitespacesAndNewlines)
        case .linearGradient:
            return gradient.cssString
        case .unsupported:
            return unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static let defaultGradientStops = [
        CSSGradientStopValue(color: "#ffffff", position: "0%"),
        CSSGradientStopValue(color: "#000000", position: "100%")
    ]
}

/// 論理名（日本語）: CSS shadow 値
/// 概要: 単一 box-shadow を x、y、blur、spread、color、inset として扱います。
///
/// プロパティ:
/// - `x`: X offset。
/// - `y`: Y offset。
/// - `blur`: blur radius。
/// - `spread`: spread radius。
/// - `color`: 色。
/// - `isInset`: inset 指定。
/// - `unsupportedValue`: Inspector の編集対象外として保持する元の CSS 文字列。
struct CSSShadowValue: Equatable {
    var x: String
    var y: String
    var blur: String
    var spread: String
    var color: String
    var isInset: Bool
    var unsupportedValue: String

    /// 論理名（日本語）: CSS shadow 値初期化関数
    /// 処理概要: 単一 shadow を構造化します。複数 shadow は編集対象外値として保持します。
    ///
    /// - Parameter cssString: CSS shadow 文字列。
    init(cssString: String) {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            x = ""
            y = ""
            blur = ""
            spread = ""
            color = ""
            isInset = false
            unsupportedValue = ""
            return
        }

        let shadowLayers = CSSValueTokenizer.splitCommas(trimmed)
        guard shadowLayers.count == 1 else {
            x = ""
            y = ""
            blur = ""
            spread = ""
            color = ""
            isInset = false
            unsupportedValue = trimmed
            return
        }

        var tokens = CSSValueTokenizer.splitWhitespace(trimmed)
        isInset = tokens.contains { $0.lowercased() == "inset" }
        tokens.removeAll { $0.lowercased() == "inset" }

        if let colorIndex = tokens.firstIndex(where: Self.looksLikeColor) {
            color = tokens.remove(at: colorIndex)
        } else {
            color = ""
        }

        x = tokens[safe: 0] ?? ""
        y = tokens[safe: 1] ?? ""
        blur = tokens[safe: 2] ?? ""
        spread = tokens[safe: 3] ?? ""
        let hasEditableOffsets = tokens.count >= 2 && tokens.count <= 4 && tokens.allSatisfy(CSSEditingSupport.isSimpleToken)
        let hasEditableColor = color.isEmpty || CSSColorValue(cssString: color) != nil
        unsupportedValue = hasEditableOffsets && hasEditableColor ? "" : trimmed
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        var parts = [x, y, blur, spread, color]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if isInset {
            parts.insert("inset", at: 0)
        }
        return parts.joined(separator: " ")
    }

    /// 論理名（日本語）: 色らしさ判定関数
    /// 処理概要: CSS shadow token が色指定として扱えるかを判定します。
    ///
    /// - Parameter token: CSS token。
    /// - Returns: 色指定として扱う場合は true。
    private static func looksLikeColor(_ token: String) -> Bool {
        let lowercasedToken = token.lowercased()
        return CSSColorValue(cssString: token) != nil ||
            lowercasedToken.hasPrefix("rgb(") ||
            lowercasedToken.hasPrefix("rgba(") ||
            lowercasedToken.hasPrefix("hsl(") ||
            lowercasedToken.hasPrefix("hsla(") ||
            lowercasedToken.hasPrefix("var(") ||
            lowercasedToken.hasPrefix("color(") ||
            lowercasedToken.hasPrefix("#")
    }
}

/// 論理名（日本語）: CSS flex 値
/// 概要: flex shorthand を grow、shrink、basis として扱います。
///
/// プロパティ:
/// - `grow`: flex-grow。
/// - `shrink`: flex-shrink。
/// - `basis`: flex-basis。
struct CSSFlexValue: Equatable {
    var grow: String
    var shrink: String
    var basis: String
    var unsupportedValue: String

    /// 論理名（日本語）: CSS flex 値初期化関数
    /// 処理概要: flex shorthand を最大 3 値へ分解します。
    ///
    /// - Parameter cssString: CSS flex 文字列。
    init(cssString: String) {
        let tokens = CSSValueTokenizer.splitWhitespace(cssString)
        guard tokens.count <= 3,
              tokens.allSatisfy(CSSEditingSupport.isSimpleToken),
              tokens.prefix(2).allSatisfy({ Double($0) != nil })
        else {
            let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
            grow = ""
            shrink = ""
            basis = ""
            unsupportedValue = trimmed
            return
        }

        grow = tokens[safe: 0] ?? ""
        shrink = tokens[safe: 1] ?? ""
        basis = tokens[safe: 2] ?? ""
        unsupportedValue = ""
    }

    var isSupported: Bool {
        unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cssString: String {
        let normalizedUnsupportedValue = unsupportedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUnsupportedValue.isEmpty {
            return normalizedUnsupportedValue
        }

        return [grow, shrink, basis]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private enum CSSEditingSupport {
    /// 論理名（日本語）: 単純CSSトークン判定関数
    /// 処理概要: Inspector の通常 UI で 1 欄として安全に扱える CSS token か判定します。
    ///
    /// - Parameter token: 判定対象 token。
    /// - Returns: 関数、カンマ、空白を含まない場合は true。
    static func isSimpleToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return !trimmed.contains("(") &&
            !trimmed.contains(")") &&
            !trimmed.contains(",") &&
            !trimmed.contains(where: { $0.isWhitespace })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
