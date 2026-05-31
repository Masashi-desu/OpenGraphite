import SwiftUI

/// 論理名（日本語）: CSS四辺変数フィールド
/// 概要: padding、margin、radius の CSS shorthand を四辺入力として編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `labels`: 四辺入力のラベル。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSBoxVariableField: View {
    var key: String
    var value: String
    var labels: [String]
    var onCommit: (String) -> Void

    @State private var boxValue: CSSBoxValue
    @State private var isLinked: Bool

    /// 論理名（日本語）: CSS四辺変数フィールド初期化関数
    /// 処理概要: CSS shorthand を UI 状態へ展開します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - labels: 四辺入力のラベル。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, labels: [String], onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.labels = labels
        self.onCommit = onCommit
        let parsedValue = CSSBoxValue(cssString: value)
        _boxValue = State(initialValue: parsedValue)
        _isLinked = State(initialValue: parsedValue.top == parsedValue.right && parsedValue.right == parsedValue.bottom && parsedValue.bottom == parsedValue.left)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: boxValue.cssString)

            if boxValue.isSupported {
                HStack(spacing: 6) {
                    CSSSmallTextField(label: labels[safe: 0] ?? "T", text: binding(\.top), onCommit: commitIfChanged)
                    CSSSmallTextField(label: labels[safe: 1] ?? "R", text: binding(\.right), onCommit: commitIfChanged)
                }

                HStack(spacing: 6) {
                    CSSSmallTextField(label: labels[safe: 2] ?? "B", text: binding(\.bottom), onCommit: commitIfChanged)
                    CSSSmallTextField(label: labels[safe: 3] ?? "L", text: binding(\.left), onCommit: commitIfChanged)
                }

                Toggle("連動", isOn: $isLinked)
                    .font(.caption2)
                    .toggleStyle(.checkbox)
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            let parsedValue = CSSBoxValue(cssString: newValue)
            boxValue = parsedValue
            isLinked = parsedValue.top == parsedValue.right && parsedValue.right == parsedValue.bottom && parsedValue.bottom == parsedValue.left
        }
    }

    private func binding(_ keyPath: WritableKeyPath<CSSBoxValue, String>) -> Binding<String> {
        Binding(
            get: {
                boxValue[keyPath: keyPath]
            },
            set: { newValue in
                boxValue[keyPath: keyPath] = newValue
                if isLinked {
                    boxValue = CSSBoxValue(top: newValue, right: newValue, bottom: newValue, left: newValue)
                }
            }
        )
    }

    /// 論理名（日本語）: CSS四辺値変更時適用関数
    /// 処理概要: 四辺 UI 状態を標準 CSS shorthand へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = boxValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        boxValue = CSSBoxValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS二軸変数フィールド
/// 概要: gap や transform-origin の 1 から 2 値 shorthand を二軸入力として編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `firstLabel`: 1 つ目の入力ラベル。
/// - `secondLabel`: 2 つ目の入力ラベル。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSPairVariableField: View {
    var key: String
    var value: String
    var firstLabel: String
    var secondLabel: String
    var onCommit: (String) -> Void

    @State private var pairValue: CSSPairValue

    /// 論理名（日本語）: CSS二軸変数フィールド初期化関数
    /// 処理概要: 現在値を二軸 UI 状態へ展開します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - firstLabel: 1 つ目の入力ラベル。
    ///   - secondLabel: 2 つ目の入力ラベル。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, firstLabel: String, secondLabel: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.firstLabel = firstLabel
        self.secondLabel = secondLabel
        self.onCommit = onCommit
        _pairValue = State(initialValue: CSSPairValue(cssString: value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: pairValue.cssString)
            if pairValue.isSupported {
                HStack(spacing: 6) {
                    CSSSmallTextField(label: firstLabel, text: $pairValue.first, onCommit: commitIfChanged)
                    CSSSmallTextField(label: secondLabel, text: $pairValue.second, onCommit: commitIfChanged)
                }
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            pairValue = CSSPairValue(cssString: newValue)
        }
    }

    /// 論理名（日本語）: CSS二軸値変更時適用関数
    /// 処理概要: 二軸 UI 状態を CSS shorthand へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = pairValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        pairValue = CSSPairValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS数値単位変数フィールド
/// 概要: 数値と単位を分けて CSS 値を編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `units`: 選択可能な単位。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSNumericUnitVariableField: View {
    var key: String
    var value: String
    var units: [String]
    var onCommit: (String) -> Void

    @State private var numericValue: CSSNumericUnitValue
    @FocusState private var isNumberFocused: Bool

    /// 論理名（日本語）: CSS数値単位変数フィールド初期化関数
    /// 処理概要: 現在値を数値と単位へ分解します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - units: 選択可能な単位。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, units: [String], onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.units = units
        self.onCommit = onCommit
        _numericValue = State(initialValue: CSSNumericUnitValue(cssString: value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: numericValue.cssString)
            if isEditable {
                HStack(spacing: 6) {
                    TextField("", text: numberBinding)
                        .textFieldStyle(.plain)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                        .focused($isNumberFocused)
                        .onSubmit(commitIfChanged)
                        .frame(minWidth: 0, maxWidth: .infinity)

                    Picker("", selection: unitBinding) {
                        ForEach(unitOptions, id: \.self) { unit in
                            Text(unitLabel(for: unit))
                                .tag(unit)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 82)
                }
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            numericValue = CSSNumericUnitValue(cssString: newValue)
        }
        .onChange(of: isNumberFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
    }

    private var numberBinding: Binding<String> {
        Binding(
            get: { numericValue.number },
            set: { newValue in
                applyNumberInput(newValue)
            }
        )
    }

    private var unitBinding: Binding<String> {
        Binding(
            get: { unitOptions.contains(numericValue.unit) ? numericValue.unit : "" },
            set: { newValue in
                if numericValue.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    numericValue.unit = ""
                } else {
                    numericValue.unit = unitOptions.contains(newValue) ? newValue : ""
                }
                commitIfChanged()
            }
        )
    }

    private var isEditable: Bool {
        numericValue.isSupported && unitOptions.contains(numericValue.unit)
    }

    private var unitOptions: [String] {
        var normalizedUnits = [""]
        for unit in units.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            where !normalizedUnits.contains(unit) {
            normalizedUnits.append(unit)
        }
        return normalizedUnits
    }

    private var allowsUnitlessValue: Bool {
        units.contains("")
    }

    private var defaultUnit: String {
        unitOptions.first { !$0.isEmpty } ?? ""
    }

    /// 論理名（日本語）: CSS数値単位表示名生成関数
    /// 処理概要: 単位 Picker に表示する空値、単位なし、単位名のラベルを返します。
    ///
    /// - Parameter unit: Picker option の単位文字列。
    /// - Returns: UI に表示する単位名。
    private func unitLabel(for unit: String) -> String {
        guard unit.isEmpty else { return unit }
        return numericValue.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "unset"
            : "unitless"
    }

    /// 論理名（日本語）: CSS数値入力反映関数
    /// 処理概要: テキスト入力から数値部分だけを保持し、単位が含まれる場合は Picker 側の状態へ分離します。
    ///
    /// - Parameter rawValue: TextField から受け取った入力文字列。
    private func applyNumberInput(_ rawValue: String) {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            numericValue.number = ""
            numericValue.unit = ""
            return
        }

        let parsedValue = CSSNumericUnitValue(cssString: trimmedValue)
        if parsedValue.isSupported, !parsedValue.number.isEmpty {
            numericValue.number = parsedValue.number
            if !parsedValue.unit.isEmpty, unitOptions.contains(parsedValue.unit) {
                numericValue.unit = parsedValue.unit
            } else if numericValue.unit.isEmpty, !allowsUnitlessValue {
                numericValue.unit = defaultUnit
            }
            return
        }

        numericValue.number = Self.numericCharacters(from: trimmedValue)
        if numericValue.number.isEmpty {
            numericValue.unit = ""
        } else if numericValue.unit.isEmpty, !allowsUnitlessValue {
            numericValue.unit = defaultUnit
        }
    }

    /// 論理名（日本語）: CSS数値文字抽出関数
    /// 処理概要: 入力文字列から数値入力に必要な文字だけを取り出します。
    ///
    /// - Parameter value: 抽出対象の入力文字列。
    /// - Returns: 数値欄に保持する文字列。
    private static func numericCharacters(from value: String) -> String {
        value.filter { character in
            character.isNumber || character == "." || character == "-" || character == "+"
        }
    }

    /// 論理名（日本語）: CSS数値単位値変更時適用関数
    /// 処理概要: 数値と単位を CSS 値へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        if numericValue.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            numericValue = CSSNumericUnitValue()
        } else if numericValue.unit.isEmpty, !allowsUnitlessValue {
            numericValue.unit = defaultUnit
        }

        guard numericValue.number.isEmpty || Double(numericValue.number) != nil else { return }
        let nextValue = numericValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        numericValue = CSSNumericUnitValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS寸法変数フィールド
/// 概要: dimension 系 CSS 値を length、keyword、function の各モードで編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSDimensionVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var dimensionValue: CSSDimensionValue

    /// 論理名（日本語）: CSS寸法変数フィールド初期化関数
    /// 処理概要: 現在値を dimension UI 状態へ分類します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        _dimensionValue = State(initialValue: CSSDimensionValue(cssString: value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: dimensionValue.cssString)

            if dimensionValue.kind == .unsupported {
                CSSUnsupportedValueNotice()
            } else {
                Picker("", selection: kindBinding) {
                    Text("unset").tag(CSSDimensionKind.empty)
                    Text("length").tag(CSSDimensionKind.length)
                    Text("keyword").tag(CSSDimensionKind.keyword)
                    Text("function").tag(CSSDimensionKind.function)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

                switch dimensionValue.kind {
                case .empty:
                    EmptyView()
                case .length:
                    HStack(spacing: 6) {
                        CSSSmallTextField(label: "Value", text: $dimensionValue.primary, onCommit: commitIfChanged)
                        Picker("", selection: dimensionUnitBinding) {
                            ForEach(["px", "%", "rem", "em", "vw", "vh"], id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 72)
                    }
                case .keyword:
                    Picker("", selection: keywordBinding) {
                        ForEach(CSSDimensionValue.keywords, id: \.self) { keyword in
                            Text(keyword).tag(keyword)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                case .function:
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: functionNameBinding) {
                            ForEach(CSSDimensionValue.functionNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 118)

                        functionArgumentFields
                    }
                case .unsupported:
                    CSSUnsupportedValueNotice()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            dimensionValue = CSSDimensionValue(cssString: newValue)
        }
    }

    private var functionArgumentFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(dimensionValue.functionArgumentLabels.indices), id: \.self) { index in
                HStack(alignment: .bottom, spacing: 6) {
                    CSSSmallTextField(
                        label: dimensionValue.functionArgumentLabels[index],
                        text: functionArgumentBinding(at: index),
                        onCommit: commitIfChanged
                    )

                    if canRemoveFunctionArgument(at: index) {
                        Button {
                            removeFunctionArgument(at: index)
                        } label: {
                            Image(systemName: "minus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, height: 28)
                        .help("引数を削除")
                    }
                }
            }

            if dimensionValue.canAddFunctionArgument {
                Button {
                    addFunctionArgument()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("引数を追加")
            }
        }
    }

    /// 論理名（日本語）: CSS関数引数バインディング生成関数
    /// 処理概要: 指定 index の関数引数を個別入力欄へ接続します。
    ///
    /// - Parameter index: 引数配列の index。
    /// - Returns: 指定引数の文字列 binding。
    private func functionArgumentBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                let arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: dimensionValue.functionName)
                return arguments[safe: index] ?? ""
            },
            set: { newValue in
                var arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: dimensionValue.functionName)
                guard arguments.indices.contains(index) else { return }
                arguments[index] = newValue
                dimensionValue.arguments = arguments
            }
        )
    }

    /// 論理名（日本語）: CSS関数引数追加関数
    /// 処理概要: 可変長引数を持つ CSS 関数に空の引数欄を追加します。
    private func addFunctionArgument() {
        guard dimensionValue.canAddFunctionArgument else { return }
        dimensionValue.arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: dimensionValue.functionName)
        dimensionValue.arguments.append("")
    }

    /// 論理名（日本語）: CSS関数引数削除関数
    /// 処理概要: 可変長引数を持つ CSS 関数から指定 index の追加引数を削除し、変更を反映します。
    ///
    /// - Parameter index: 削除対象の引数 index。
    private func removeFunctionArgument(at index: Int) {
        var arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: dimensionValue.functionName)
        guard canRemoveFunctionArgument(at: index), arguments.indices.contains(index) else { return }
        arguments.remove(at: index)
        dimensionValue.arguments = arguments
        commitIfChanged()
    }

    /// 論理名（日本語）: CSS関数引数削除可否判定関数
    /// 処理概要: 指定 index の引数が UI から削除可能かを判定します。
    ///
    /// - Parameter index: 判定対象の引数 index。
    /// - Returns: 削除可能な場合は true。
    private func canRemoveFunctionArgument(at index: Int) -> Bool {
        guard dimensionValue.canAddFunctionArgument else { return false }
        let arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: dimensionValue.functionName)
        return index >= 2 && arguments.indices.contains(index)
    }

    private var kindBinding: Binding<CSSDimensionKind> {
        Binding(
            get: { dimensionValue.kind },
            set: { newValue in
                guard newValue != .unsupported else { return }
                dimensionValue.kind = newValue
                commitIfChanged()
            }
        )
    }

    private var dimensionUnitBinding: Binding<String> {
        Binding(
            get: { dimensionValue.unit },
            set: { newValue in
                dimensionValue.unit = newValue
                commitIfChanged()
            }
        )
    }

    private var keywordBinding: Binding<String> {
        Binding(
            get: { dimensionValue.primary },
            set: { newValue in
                dimensionValue.primary = newValue
                commitIfChanged()
            }
        )
    }

    private var functionNameBinding: Binding<String> {
        Binding(
            get: { dimensionValue.functionName },
            set: { newValue in
                dimensionValue.functionName = newValue
                dimensionValue.arguments = CSSDimensionValue.normalizedArguments(dimensionValue.arguments, for: newValue)
                commitIfChanged()
            }
        )
    }

    /// 論理名（日本語）: CSS寸法値変更時適用関数
    /// 処理概要: dimension UI 状態を CSS 値へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = dimensionValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        dimensionValue = CSSDimensionValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS罫線変数フィールド
/// 概要: border shorthand を width、style、color として編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSBorderVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var borderValue: CSSBorderValue
    @State private var pickerColor: Color

    /// 論理名（日本語）: CSS罫線変数フィールド初期化関数
    /// 処理概要: border shorthand を構造化します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        let parsedValue = CSSBorderValue(cssString: value)
        _borderValue = State(initialValue: parsedValue)
        _pickerColor = State(initialValue: CSSColorValue(cssString: parsedValue.color)?.color ?? .black)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: borderValue.cssString)

            if borderValue.isSupported {
                HStack(spacing: 6) {
                    CSSSmallTextField(label: "Width", text: $borderValue.width, onCommit: commitIfChanged)
                    Picker("", selection: styleBinding) {
                        ForEach(CSSBorderValue.styles, id: \.self) { style in
                            Text(style).tag(style)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 96)
                }
                CSSColorTextField(
                    label: "Color",
                    text: $borderValue.color,
                    pickerColor: $pickerColor,
                    initialColor: .black,
                    onCommit: commitIfChanged
                )
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            let parsedValue = CSSBorderValue(cssString: newValue)
            borderValue = parsedValue
            pickerColor = CSSColorValue(cssString: parsedValue.color)?.color ?? .black
        }
    }

    private var styleBinding: Binding<String> {
        Binding(
            get: { borderValue.style },
            set: { newValue in
                borderValue.style = newValue
                commitIfChanged()
            }
        )
    }

    /// 論理名（日本語）: CSS罫線値変更時適用関数
    /// 処理概要: border UI 状態を CSS shorthand へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = borderValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        borderValue = CSSBorderValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS背景変数フィールド
/// 概要: background 値を単色または線形グラデーションとして編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSBackgroundVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var backgroundValue: CSSBackgroundValue
    @State private var pickerColor: Color

    /// 論理名（日本語）: CSS背景変数フィールド初期化関数
    /// 処理概要: background 値を表示モードへ分類します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        let parsedValue = CSSBackgroundValue(cssString: value)
        _backgroundValue = State(initialValue: parsedValue)
        _pickerColor = State(initialValue: CSSColorValue(cssString: parsedValue.color)?.color ?? .white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: backgroundValue.cssString)

            if backgroundValue.kind == .unsupported {
                CSSUnsupportedValueNotice()
            } else {
                Picker("", selection: kindBinding) {
                    Text("unset").tag(CSSBackgroundKind.empty)
                    Text("color").tag(CSSBackgroundKind.color)
                    Text("gradient").tag(CSSBackgroundKind.linearGradient)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

                switch backgroundValue.kind {
                case .empty:
                    EmptyView()
                case .color:
                    CSSColorTextField(
                        label: "Color",
                        text: $backgroundValue.color,
                        pickerColor: $pickerColor,
                        initialColor: .white,
                        onCommit: commitIfChanged
                    )
                case .linearGradient:
                    CSSSmallTextField(label: "Angle", text: $backgroundValue.gradient.angle, onCommit: commitIfChanged)
                    ForEach(Array(backgroundValue.gradient.stops.indices), id: \.self) { index in
                        CSSGradientStopField(
                            index: index,
                            stop: gradientStopBinding(at: index),
                            canRemove: backgroundValue.gradient.stops.count > 2,
                            onRemove: {
                                backgroundValue.gradient.stops.remove(at: index)
                                commitIfChanged()
                            },
                            onCommit: commitIfChanged
                        )
                    }
                    Button {
                        backgroundValue.gradient.stops.append(CSSGradientStopValue(color: "#ffffff", position: "100%"))
                        commitIfChanged()
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Stop を追加")
                case .unsupported:
                    CSSUnsupportedValueNotice()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            let parsedValue = CSSBackgroundValue(cssString: newValue)
            backgroundValue = parsedValue
            pickerColor = CSSColorValue(cssString: parsedValue.color)?.color ?? .white
        }
    }

    /// 論理名（日本語）: CSSグラデーション停止バインディング生成関数
    /// 処理概要: 指定 index の color stop を個別編集 UI へ接続します。
    ///
    /// - Parameter index: color stop 配列の index。
    /// - Returns: 指定 color stop の binding。
    private func gradientStopBinding(at index: Int) -> Binding<CSSGradientStopValue> {
        Binding(
            get: {
                backgroundValue.gradient.stops[safe: index] ?? CSSGradientStopValue()
            },
            set: { newValue in
                guard backgroundValue.gradient.stops.indices.contains(index) else { return }
                backgroundValue.gradient.stops[index] = newValue
            }
        )
    }

    private var kindBinding: Binding<CSSBackgroundKind> {
        Binding(
            get: { backgroundValue.kind },
            set: { newValue in
                guard newValue != .unsupported else { return }
                backgroundValue.kind = newValue
                commitIfChanged()
            }
        )
    }

    /// 論理名（日本語）: CSS背景値変更時適用関数
    /// 処理概要: background UI 状態を CSS 値へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = backgroundValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        backgroundValue = CSSBackgroundValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS shadow 変数フィールド
/// 概要: 単一 shadow を offset、blur、spread、color、inset として編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSShadowVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var shadowValue: CSSShadowValue
    @State private var pickerColor: Color

    /// 論理名（日本語）: CSS shadow 変数フィールド初期化関数
    /// 処理概要: shadow 値を構造化します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        let parsedValue = CSSShadowValue(cssString: value)
        _shadowValue = State(initialValue: parsedValue)
        _pickerColor = State(initialValue: CSSColorValue(cssString: parsedValue.color)?.color ?? .black)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: shadowValue.cssString)

            if shadowValue.isSupported {
                HStack(spacing: 6) {
                    CSSSmallTextField(label: "X", text: $shadowValue.x, onCommit: commitIfChanged)
                    CSSSmallTextField(label: "Y", text: $shadowValue.y, onCommit: commitIfChanged)
                }
                HStack(spacing: 6) {
                    CSSSmallTextField(label: "Blur", text: $shadowValue.blur, onCommit: commitIfChanged)
                    CSSSmallTextField(label: "Spread", text: $shadowValue.spread, onCommit: commitIfChanged)
                }
                CSSColorTextField(
                    label: "Color",
                    text: $shadowValue.color,
                    pickerColor: $pickerColor,
                    initialColor: .black,
                    onCommit: commitIfChanged
                )
                Toggle("inset", isOn: insetBinding)
                    .font(.caption2)
                    .toggleStyle(.checkbox)
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            let parsedValue = CSSShadowValue(cssString: newValue)
            shadowValue = parsedValue
            pickerColor = CSSColorValue(cssString: parsedValue.color)?.color ?? .black
        }
    }

    private var insetBinding: Binding<Bool> {
        Binding(
            get: { shadowValue.isInset },
            set: { newValue in
                shadowValue.isInset = newValue
                commitIfChanged()
            }
        )
    }

    /// 論理名（日本語）: CSS shadow 値変更時適用関数
    /// 処理概要: shadow UI 状態を CSS 値へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = shadowValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        shadowValue = CSSShadowValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS flex 変数フィールド
/// 概要: flex shorthand を grow、shrink、basis として編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `onCommit`: serialize 後の CSS 値を反映する処理。
struct CSSFlexVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var flexValue: CSSFlexValue

    /// 論理名（日本語）: CSS flex 変数フィールド初期化関数
    /// 処理概要: flex shorthand を UI 状態へ分解します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - onCommit: serialize 後の CSS 値を反映する処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        _flexValue = State(initialValue: CSSFlexValue(cssString: value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSSControlHeader(key: key, valuePreview: flexValue.cssString)
            if flexValue.isSupported {
                HStack(spacing: 6) {
                    CSSSmallTextField(label: "Grow", text: $flexValue.grow, onCommit: commitIfChanged)
                    CSSSmallTextField(label: "Shrink", text: $flexValue.shrink, onCommit: commitIfChanged)
                }
                CSSSmallTextField(label: "Basis", text: $flexValue.basis, onCommit: commitIfChanged)
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            flexValue = CSSFlexValue(cssString: newValue)
        }
    }

    /// 論理名（日本語）: CSS flex 値変更時適用関数
    /// 処理概要: flex UI 状態を CSS shorthand へ serialize し、変更がある場合だけ反映します。
    private func commitIfChanged() {
        let nextValue = flexValue.cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        flexValue = CSSFlexValue(cssString: nextValue)
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS列挙値変数フィールド
/// 概要: object-fit や text-align のような列挙値を Picker で編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在の CSS 値。
/// - `options`: 選択肢。
/// - `onCommit`: 選択後の CSS 値を反映する処理。
struct CSSEnumVariableField: View {
    var key: String
    var value: String
    var options: [String]
    var onCommit: (String) -> Void

    @State private var selectedValue: String

    /// 論理名（日本語）: CSS列挙値変数フィールド初期化関数
    /// 処理概要: 現在値を Picker 状態へコピーします。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在の CSS 値。
    ///   - options: 選択肢。
    ///   - onCommit: 選択後の CSS 値を反映する処理。
    init(key: String, value: String, options: [String], onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.options = options
        self.onCommit = onCommit
        _selectedValue = State(initialValue: value)
    }

    var body: some View {
        if isEditable {
            HStack(spacing: 8) {
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 112, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Picker("", selection: selectedBinding) {
                    Text("unset").tag("")
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(minWidth: 0, maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .onChange(of: value) { _, newValue in
                selectedValue = newValue
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CSSControlHeader(key: key, valuePreview: value)
                CSSUnsupportedValueNotice()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selectedBinding: Binding<String> {
        Binding(
            get: { selectedValue },
            set: { newValue in
                selectedValue = newValue
                onCommit(newValue)
            }
        )
    }

    private var isEditable: Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty || options.contains(normalizedValue)
    }
}

/// 論理名（日本語）: CSSコントロールヘッダー
/// 概要: CSS 変数名と現在の serialize preview を表示します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `valuePreview`: serialize preview。
private struct CSSControlHeader: View {
    var key: String
    var valuePreview: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer()
            Text(valuePreview.isEmpty ? "unset" : valuePreview)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 130, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: CSS小型テキストフィールド
/// 概要: 構造化 CSS コントロール内の短いラベル付き入力欄です。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力値 binding。
/// - `onCommit`: Enter またはフォーカスアウト時の確定処理。
private struct CSSSmallTextField: View {
    var label: String
    @Binding var text: String
    var onCommit: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .focused($isFocused)
                .onSubmit(onCommit)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            onCommit()
        }
    }
}

/// 論理名（日本語）: CSS編集対象外値表示
/// 概要: Inspector 通常 UI の編集対象外 CSS 値であることを読み取り専用で示します。
struct CSSUnsupportedValueNotice: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.caption2.weight(.semibold))
            Text("External CSS")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .help("Inspector の編集対象外です")
    }
}

/// 論理名（日本語）: CSSグラデーション停止フィールド
/// 概要: linear-gradient の 1 つの color stop を色と位置の個別入力として編集します。
///
/// プロパティ:
/// - `index`: stop の表示順。
/// - `stop`: 編集対象の color stop binding。
/// - `canRemove`: 削除操作を表示するかどうか。
/// - `onRemove`: 削除時の処理。
/// - `onCommit`: Enter またはフォーカスアウト時の確定処理。
private struct CSSGradientStopField: View {
    var index: Int
    @Binding var stop: CSSGradientStopValue
    var canRemove: Bool
    var onRemove: () -> Void
    var onCommit: () -> Void

    @State private var pickerColor: Color

    /// 論理名（日本語）: CSSグラデーション停止フィールド初期化関数
    /// 処理概要: stop binding と初期 ColorPicker 色を受け取り、編集行を構成します。
    ///
    /// - Parameters:
    ///   - index: stop の表示順。
    ///   - stop: 編集対象の color stop binding。
    ///   - canRemove: 削除操作を表示するかどうか。
    ///   - onRemove: 削除時の処理。
    ///   - onCommit: Enter またはフォーカスアウト時の確定処理。
    init(
        index: Int,
        stop: Binding<CSSGradientStopValue>,
        canRemove: Bool,
        onRemove: @escaping () -> Void,
        onCommit: @escaping () -> Void
    ) {
        self.index = index
        _stop = stop
        self.canRemove = canRemove
        self.onRemove = onRemove
        self.onCommit = onCommit
        _pickerColor = State(initialValue: CSSColorValue(cssString: stop.wrappedValue.color)?.color ?? .white)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Stop \(index + 1)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20, height: 20)
                    .help("Stop を削除")
                }
            }

            HStack(alignment: .top, spacing: 6) {
                CSSColorTextField(
                    label: "Color",
                    text: colorBinding,
                    pickerColor: $pickerColor,
                    initialColor: .white,
                    onCommit: onCommit
                )
                CSSSmallTextField(label: "Position", text: positionBinding, onCommit: onCommit)
                    .frame(width: 88)
            }
        }
        .onChange(of: stop.color) { _, newValue in
            guard let cssColor = CSSColorValue(cssString: newValue) else { return }
            pickerColor = cssColor.color
        }
    }

    private var colorBinding: Binding<String> {
        Binding(
            get: { stop.color },
            set: { newValue in
                stop.color = newValue
            }
        )
    }

    private var positionBinding: Binding<String> {
        Binding(
            get: { stop.position },
            set: { newValue in
                stop.position = newValue
            }
        )
    }
}

/// 論理名（日本語）: CSS色テキストフィールド
/// 概要: CSS 色文字列と ColorPicker プレビューを同じ入力行として表示し、未設定時は色を表示しません。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: CSS 色文字列 binding。
/// - `pickerColor`: ColorPicker 内部状態。
/// - `initialColor`: 未設定時に ColorPicker を開くための初期色。
/// - `onCommit`: Enter、フォーカスアウト、または色選択時の確定処理。
private struct CSSColorTextField: View {
    var label: String
    @Binding var text: String
    @Binding var pickerColor: Color
    var initialColor: Color
    var onCommit: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 6) {
                CSSColorPickerPreview(
                    text: $text,
                    pickerColor: $pickerColor,
                    initialColor: initialColor,
                    onPick: { _ in commitIfValid() }
                )

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                    .focused($isFocused)
                    .onSubmit(commitIfValid)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .onChange(of: text) { _, newValue in
            guard let cssColor = CSSColorValue(cssString: newValue) else { return }
            pickerColor = cssColor.color
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfValid()
        }
    }

    /// 論理名（日本語）: CSS色変更時適用関数
    /// 処理概要: ColorPicker が扱える色値または未設定だけを確定します。
    private func commitIfValid() {
        let normalizedValue = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty || CSSColorValue(cssString: normalizedValue) != nil else { return }
        text = normalizedValue
        onCommit()
    }
}

/// 論理名（日本語）: CSS色ピッカープレビュー
/// 概要: CSS 色文字列がある場合だけ色を見せ、未設定時は空プレビューとして ColorPicker のクリック領域を提供します。
///
/// プロパティ:
/// - `text`: CSS 色文字列 binding。
/// - `pickerColor`: ColorPicker 内部状態。
/// - `initialColor`: 未設定時に ColorPicker を開くための初期色。
/// - `onPick`: ColorPicker で色を選択した直後に呼び出す任意処理。
struct CSSColorPickerPreview: View {
    @Binding var text: String
    @Binding var pickerColor: Color
    var initialColor: Color
    var onPick: ((String) -> Void)?

    var body: some View {
        ZStack {
            ColorPicker("", selection: pickerBinding, supportsOpacity: true)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 28, height: 24)
                .opacity(parsedColor == nil ? 0.02 : 1)
                .accessibilityHidden(parsedColor == nil)
                .accessibilityValue(parsedColor?.cssHexString ?? "unset")

            if parsedColor == nil {
                CSSUnsetColorPreview()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 28, height: 24)
        .help(parsedColor?.cssHexString ?? "CSS色を選択")
    }

    private var parsedColor: CSSColorValue? {
        CSSColorValue(cssString: text)
    }

    private var pickerBinding: Binding<Color> {
        Binding(
            get: {
                parsedColor?.color ?? pickerColor
            },
            set: { newColor in
                pickerColor = newColor
                guard let cssColor = CSSColorValue(color: newColor) else { return }
                let nextValue = cssColor.cssHexString
                text = nextValue
                onPick?(nextValue)
            }
        )
    }
}

/// 論理名（日本語）: CSS未設定色プレビュー
/// 概要: CSS 色文字列が存在しない場合に、色が未設定であることを示す小さなプレビューです。
private struct CSSUnsetColorPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(EditorColumnStyle.elevatedRowFill)

            Image(systemName: "slash.circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 28, height: 24)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("unset")
        .accessibilityValue("CSS色未設定")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
