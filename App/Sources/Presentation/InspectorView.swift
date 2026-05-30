import SwiftUI

/// 論理名（日本語）: インスペクタービュー
/// 概要: 選択ノードの `data-og-*` と `--og-*` を表示・編集する右ペインです。
struct InspectorView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, EditorOverlayMetrics.titlebarInset)
            .padding(.horizontal, EditorColumnStyle.outerPadding + 4)
            .padding(.bottom, 14)

            if let node = store.selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        NodeSummaryPanel(node: node)

                        InspectorSection(title: "Context") {
                            InspectorInfoRow(label: "tag", value: node.tagName)
                            InspectorInfoRow(label: "data-og-id", value: node.id)
                            InspectorInfoRow(label: "data-og-type", value: node.type)
                            EditableAttributeField(
                                label: "data-og-role",
                                value: node.role ?? ""
                            ) { value in
                                store.updateNodeAttribute(name: "data-og-role", value: value)
                            }
                            .id("\(node.id)-role")
                        }

                        InspectorSection(title: "Alignment") {
                            InspectorButtonStrip(
                                title: "Align",
                                value: node.cssVariables["--og-align"] ?? "",
                                options: [
                                    InspectorButtonOption(label: "L", systemImage: "align.horizontal.left", value: "flex-start"),
                                    InspectorButtonOption(label: "C", systemImage: "align.horizontal.center", value: "center"),
                                    InspectorButtonOption(label: "R", systemImage: "align.horizontal.right", value: "flex-end")
                                ]
                            ) { value in
                                store.updateCSSVariable(key: "--og-align", value: value)
                            }

                            InspectorButtonStrip(
                                title: "Justify",
                                value: node.cssVariables["--og-justify"] ?? "",
                                options: [
                                    InspectorButtonOption(label: "T", systemImage: "align.vertical.top", value: "flex-start"),
                                    InspectorButtonOption(label: "M", systemImage: "align.vertical.center", value: "center"),
                                    InspectorButtonOption(label: "B", systemImage: "align.vertical.bottom", value: "flex-end")
                                ]
                            ) { value in
                                store.updateCSSVariable(key: "--og-justify", value: value)
                            }
                        }

                        InspectorSection(title: "Layout") {
                            LayoutModePicker(value: node.layout ?? "") { value in
                                store.updateNodeAttribute(name: "data-og-layout", value: value)
                            }

                            CSSPairVariableField(
                                key: "--og-gap",
                                value: node.cssVariables["--og-gap"] ?? "",
                                firstLabel: "Row",
                                secondLabel: "Column"
                            ) { value in
                                store.updateCSSVariable(key: "--og-gap", value: value)
                            }
                            .id("\(node.id)-gap")

                            CSSBoxVariableField(
                                key: "--og-padding",
                                value: node.cssVariables["--og-padding"] ?? "",
                                labels: ["T", "R", "B", "L"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-padding", value: value)
                            }
                            .id("\(node.id)-padding")

                            CSSBoxVariableField(
                                key: "--og-margin",
                                value: node.cssVariables["--og-margin"] ?? "",
                                labels: ["T", "R", "B", "L"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-margin", value: value)
                            }
                            .id("\(node.id)-margin")

                            CSSFlexVariableField(key: "--og-flex", value: node.cssVariables["--og-flex"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-flex", value: value)
                            }
                            .id("\(node.id)-flex")
                        }

                        InspectorSection(title: "Position") {
                            InspectorFieldGrid {
                                CSSNumericUnitVariableField(key: "--og-x", value: node.cssVariables["--og-x"] ?? "", units: ["px", "%", "rem", "em"]) { value in
                                    store.updateCSSVariable(key: "--og-x", value: value)
                                }
                                .id("\(node.id)-x")

                                CSSNumericUnitVariableField(key: "--og-y", value: node.cssVariables["--og-y"] ?? "", units: ["px", "%", "rem", "em"]) { value in
                                    store.updateCSSVariable(key: "--og-y", value: value)
                                }
                                .id("\(node.id)-y")
                            }
                        }

                        InspectorSection(title: "Dimensions") {
                            CSSDimensionVariableField(key: "--og-width", value: node.cssVariables["--og-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-width", value: value)
                            }
                            .id("\(node.id)-width")

                            CSSDimensionVariableField(key: "--og-height", value: node.cssVariables["--og-height"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-height", value: value)
                            }
                            .id("\(node.id)-height")

                            CSSDimensionVariableField(key: "--og-min-width", value: node.cssVariables["--og-min-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-min-width", value: value)
                            }
                            .id("\(node.id)-min-width")

                            CSSDimensionVariableField(key: "--og-min-height", value: node.cssVariables["--og-min-height"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-min-height", value: value)
                            }
                            .id("\(node.id)-min-height")

                            CSSDimensionVariableField(key: "--og-max-width", value: node.cssVariables["--og-max-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-max-width", value: value)
                            }
                            .id("\(node.id)-max-width")
                        }

                        InspectorSection(title: "Appearance") {
                            CSSBoxVariableField(
                                key: "--og-radius",
                                value: node.cssVariables["--og-radius"] ?? "",
                                labels: ["TL", "TR", "BR", "BL"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-radius", value: value)
                            }
                            .id("\(node.id)-radius")

                            CSSBorderVariableField(key: "--og-border", value: node.cssVariables["--og-border"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-border", value: value)
                            }
                            .id("\(node.id)-border")

                            CSSBackgroundVariableField(
                                key: "--og-background",
                                value: node.cssVariables["--og-background"] ?? ""
                            ) { value in
                                store.updateCSSVariable(key: "--og-background", value: value)
                            }
                            .id("\(node.id)-background")

                            CSSColorVariableField(
                                key: "--og-foreground",
                                value: node.cssVariables["--og-foreground"] ?? "",
                                initialColor: .black
                            ) { value in
                                store.updateCSSVariable(key: "--og-foreground", value: value)
                            }
                            .id("\(node.id)-foreground")
                        }

                        if node.type == "text" {
                            InspectorSection(title: "Typography") {
                                InspectorFieldGrid {
                                    CSSNumericUnitVariableField(key: "--og-font-size", value: node.cssVariables["--og-font-size"] ?? "", units: ["px", "rem", "em", "%"]) { value in
                                        store.updateCSSVariable(key: "--og-font-size", value: value)
                                    }
                                    .id("\(node.id)-font-size")

                                    CSSNumericUnitVariableField(key: "--og-font-weight", value: node.cssVariables["--og-font-weight"] ?? "", units: [""]) { value in
                                        store.updateCSSVariable(key: "--og-font-weight", value: value)
                                    }
                                    .id("\(node.id)-font-weight")

                                    CSSNumericUnitVariableField(key: "--og-line-height", value: node.cssVariables["--og-line-height"] ?? "", units: ["", "px", "%", "em"]) { value in
                                        store.updateCSSVariable(key: "--og-line-height", value: value)
                                    }
                                    .id("\(node.id)-line-height")

                                    CSSNumericUnitVariableField(key: "--og-letter-spacing", value: node.cssVariables["--og-letter-spacing"] ?? "", units: ["px", "em", "rem", ""]) { value in
                                        store.updateCSSVariable(key: "--og-letter-spacing", value: value)
                                    }
                                    .id("\(node.id)-letter-spacing")
                                }

                                CSSEnumVariableField(
                                    key: "--og-text-align",
                                    value: node.cssVariables["--og-text-align"] ?? "",
                                    options: ["left", "center", "right", "justify", "start", "end"]
                                ) { value in
                                    store.updateCSSVariable(key: "--og-text-align", value: value)
                                }
                                .id("\(node.id)-text-align")
                            }
                        }

                        if node.type == "image" {
                            InspectorSection(title: "Media") {
                                CSSEnumVariableField(
                                    key: "--og-object-fit",
                                    value: node.cssVariables["--og-object-fit"] ?? "",
                                    options: ["cover", "contain", "fill", "none", "scale-down"]
                                ) { value in
                                    store.updateCSSVariable(key: "--og-object-fit", value: value)
                                }
                                .id("\(node.id)-object-fit")
                            }
                        }

                        InspectorSection(title: "Effects") {
                            CSSShadowVariableField(key: "--og-shadow", value: node.cssVariables["--og-shadow"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-shadow", value: value)
                            }
                            .id("\(node.id)-shadow")

                            CSSPairVariableField(
                                key: "--og-transform-origin",
                                value: node.cssVariables["--og-transform-origin"] ?? "",
                                firstLabel: "X",
                                secondLabel: "Y"
                            ) { value in
                                store.updateCSSVariable(key: "--og-transform-origin", value: value)
                            }
                            .id("\(node.id)-transform-origin")

                            InspectorFieldGrid {
                                CSSNumericUnitVariableField(key: "--og-scale-x", value: node.cssVariables["--og-scale-x"] ?? "", units: [""]) { value in
                                    store.updateCSSVariable(key: "--og-scale-x", value: value)
                                }
                                .id("\(node.id)-scale-x")

                                CSSNumericUnitVariableField(key: "--og-scale-y", value: node.cssVariables["--og-scale-y"] ?? "", units: [""]) { value in
                                    store.updateCSSVariable(key: "--og-scale-y", value: value)
                                }
                                .id("\(node.id)-scale-y")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity)
            } else {
                InspectorEmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 論理名（日本語）: ノード概要パネル
/// 概要: Inspector 上部に選択ノードのアイコン、タグ名、詳細行を表示します。
///
/// プロパティ:
/// - `node`: 表示対象の選択ノード。
private struct NodeSummaryPanel: View {
    var node: OpenGraphiteNode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(node.tagName)
                    .font(.headline)
                    .lineLimit(1)
                Text(node.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch node.type {
        case "text":
            return "textformat"
        case "button":
            return "button.programmable"
        case "image":
            return "photo"
        default:
            return "number.square"
        }
    }
}

/// 論理名（日本語）: インスペクターセクション
/// 概要: Inspector 内の見出し付きパネルを共通化する汎用コンテナです。
///
/// プロパティ:
/// - `title`: セクション見出し。
/// - `content`: セクション内に表示する SwiftUI content。
private struct InspectorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EditorColumnStyle.rowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                    .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 論理名（日本語）: インスペクター空状態ビュー
/// 概要: ノード未選択時に右カラムの新しい軽量スタイルで選択案内を表示します。
private struct InspectorEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No Selection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Layers または Canvas でノードを選択してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 28)
        }
    }
}

/// 論理名（日本語）: インスペクター情報行
/// 概要: 編集不可のラベルと値を左右に並べて表示します。
///
/// プロパティ:
/// - `label`: 項目名。
/// - `value`: 表示値。
private struct InspectorInfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

/// 論理名（日本語）: 編集可能属性フィールド
/// 概要: `data-og-role` などの属性値をテキスト入力し、Enter またはフォーカスアウトで確定する入力行です。
///
/// プロパティ:
/// - `label`: 属性名。
/// - `value`: 現在値。
/// - `onCommit`: 適用時に呼び出す処理。
private struct EditableAttributeField: View {
    var label: String
    var value: String
    var onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: 編集可能属性フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、適用処理を保持します。
    ///
    /// - Parameters:
    ///   - label: 属性名。
    ///   - value: 現在値。
    ///   - onCommit: 適用時に呼び出す処理。
    init(label: String, value: String, onCommit: @escaping (String) -> Void) {
        self.label = label
        self.value = value
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 86, alignment: .leading)

            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .focused($isFocused)
                .onSubmit(commitIfChanged)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
    }

    /// 論理名（日本語）: 編集可能属性変更時適用関数
    /// 処理概要: 入力値を trim し、変更がある場合だけ属性更新を反映します。
    private func commitIfChanged() {
        let nextValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = nextValue
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: レイアウトモードピッカー
/// 概要: `data-og-layout` を vertical、horizontal、absolute から選択するボタン群です。
///
/// プロパティ:
/// - `value`: 現在の layout 値。
/// - `onChange`: layout 選択時に呼び出す処理。
private struct LayoutModePicker: View {
    var value: String
    var onChange: (String) -> Void

    private let options = [
        ("vertical", "arrow.down"),
        ("horizontal", "arrow.right"),
        ("absolute", "scope")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option in
                Button {
                    onChange(option.0)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.1)
                        Text(option.0)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .fill(value == option.0 ? EditorColumnStyle.selectedRowFill : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .stroke(value == option.0 ? Color.accentColor.opacity(0.45) : EditorColumnStyle.separatorColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: インスペクターフィールドグリッド
/// 概要: CSS 変数入力欄を二列グリッドで配置する汎用コンテナです。
///
/// プロパティ:
/// - `content`: グリッド内に表示する SwiftUI content。
private struct InspectorFieldGrid<Content: View>: View {
    @ViewBuilder var content: Content

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: CSS変数フィールド
/// 概要: `--og-*` のキーと値入力欄を表示し、Enter またはフォーカスアウトで確定します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在値。
/// - `onCommit`: 適用時に呼び出す処理。
private struct CSSVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: CSS変数フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、適用処理を保持します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在値。
    ///   - onCommit: 適用時に呼び出す処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(key)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 6) {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                    .focused($isFocused)
                    .onSubmit(commitIfChanged)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
    }

    /// 論理名（日本語）: CSS変数変更時適用関数
    /// 処理概要: 入力値を trim し、変更がある場合だけ CSS 変数更新を反映します。
    private func commitIfChanged() {
        let nextValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = nextValue
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS色変数フィールド
/// 概要: `--og-background` などの色系 CSS 変数をスウォッチ、ColorPicker、CSS 文字列で編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在値。
/// - `initialColor`: 現在値が CSS 色として解釈できないときの ColorPicker 初期色。
/// - `onCommit`: 色または CSS 文字列の適用時に呼び出す処理。
private struct CSSColorVariableField: View {
    var key: String
    var value: String
    var initialColor: Color
    var onCommit: (String) -> Void

    @State private var draft: String
    @State private var pickerColor: Color
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: CSS色変数フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、ColorPicker の初期色を決定します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在値。
    ///   - initialColor: CSS 色として解釈できない場合に使う初期色。
    ///   - onCommit: 適用時に呼び出す処理。
    init(key: String, value: String, initialColor: Color, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.initialColor = initialColor
        self.onCommit = onCommit
        _draft = State(initialValue: value)
        _pickerColor = State(initialValue: CSSColorValue(cssString: value)?.color ?? initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()

                CSSColorSwatch(colorValue: parsedDraft)
            }

            if isEditable {
                HStack(spacing: 6) {
                    CSSColorPickerPreview(
                        text: $draft,
                        pickerColor: $pickerColor,
                        initialColor: initialColor,
                        onPick: commitPickedColor
                    )

                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                        .focused($isFocused)
                        .onSubmit(commitDraftIfChanged)
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
            } else {
                CSSUnsupportedValueNotice()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            draft = newValue
            pickerColor = CSSColorValue(cssString: newValue)?.color ?? initialColor
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitDraftIfChanged()
        }
    }

    private var parsedDraft: CSSColorValue? {
        CSSColorValue(cssString: draft)
    }

    private var isEditable: Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty || CSSColorValue(cssString: normalizedValue) != nil
    }

    /// 論理名（日本語）: 色選択変更時適用関数
    /// 処理概要: ColorPicker が生成した CSS 色文字列を変更がある場合だけ反映します。
    private func commitPickedColor(_ nextValue: String) {
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }

    /// 論理名（日本語）: draft変更時適用関数
    /// 処理概要: テキスト入力中の CSS 色文字列を確定し、有効な値か未設定なら変更時だけ反映します。
    private func commitDraftIfChanged() {
        let normalizedValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty || CSSColorValue(cssString: normalizedValue) != nil else { return }
        draft = normalizedValue
        guard normalizedValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if let cssColor = CSSColorValue(cssString: normalizedValue) {
            pickerColor = cssColor.color
        }
        onCommit(normalizedValue)
    }
}

/// 論理名（日本語）: CSS色スウォッチ
/// 概要: CSS 色として解釈できる値を小さなプレビューとして表示します。
///
/// プロパティ:
/// - `colorValue`: 表示対象の CSS 色値。nil の場合は未解析状態を示します。
private struct CSSColorSwatch: View {
    var colorValue: CSSColorValue?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(EditorColumnStyle.elevatedRowFill)

            if let colorValue {
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorValue.color)
            } else {
                Image(systemName: "slash")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .help(colorValue?.cssHexString ?? "CSS色として解析できない値")
    }
}

/// 論理名（日本語）: インスペクターボタン選択肢
/// 概要: alignment や justify のアイコンボタンに使う選択肢モデルです。
///
/// プロパティ:
/// - `label`: tooltip 用の短いラベル。
/// - `systemImage`: SF Symbols 名。
/// - `value`: 適用する CSS 変数値。
private struct InspectorButtonOption: Identifiable {
    var label: String
    var systemImage: String
    var value: String

    var id: String { value }
}

/// 論理名（日本語）: インスペクターボタンストリップ
/// 概要: alignment や justify をアイコンボタン群として表示し、選択値を CSS 変数へ反映します。
///
/// プロパティ:
/// - `title`: 行タイトル。
/// - `value`: 現在選択値。
/// - `options`: 表示する選択肢。
/// - `onChange`: 選択時に呼び出す処理。
private struct InspectorButtonStrip: View {
    var title: String
    var value: String
    var options: [InspectorButtonOption]
    var onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(options) { option in
                    Button {
                        onChange(option.value)
                    } label: {
                        Image(systemName: option.systemImage)
                            .font(.caption)
                            .frame(width: 28, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(value == option.value ? EditorColumnStyle.selectedRowFill : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(option.label)
                }
            }

            Spacer()
        }
    }
}
