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
                Image(systemName: "sidebar.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

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

                            InspectorFieldGrid {
                                CSSVariableField(key: "--og-gap", value: node.cssVariables["--og-gap"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-gap", value: value)
                                }
                                .id("\(node.id)-gap")

                                CSSVariableField(key: "--og-padding", value: node.cssVariables["--og-padding"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-padding", value: value)
                                }
                                .id("\(node.id)-padding")
                            }
                        }

                        InspectorSection(title: "Position") {
                            InspectorFieldGrid {
                                CSSVariableField(key: "--og-x", value: node.cssVariables["--og-x"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-x", value: value)
                                }
                                .id("\(node.id)-x")

                                CSSVariableField(key: "--og-y", value: node.cssVariables["--og-y"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-y", value: value)
                                }
                                .id("\(node.id)-y")
                            }
                        }

                        InspectorSection(title: "Dimensions") {
                            InspectorFieldGrid {
                                CSSVariableField(key: "--og-width", value: node.cssVariables["--og-width"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-width", value: value)
                                }
                                .id("\(node.id)-width")

                                CSSVariableField(key: "--og-height", value: node.cssVariables["--og-height"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-height", value: value)
                                }
                                .id("\(node.id)-height")

                                CSSVariableField(key: "--og-min-width", value: node.cssVariables["--og-min-width"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-min-width", value: value)
                                }
                                .id("\(node.id)-min-width")

                                CSSVariableField(key: "--og-min-height", value: node.cssVariables["--og-min-height"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-min-height", value: value)
                                }
                                .id("\(node.id)-min-height")
                            }
                        }

                        InspectorSection(title: "Appearance") {
                            InspectorFieldGrid {
                                CSSVariableField(key: "--og-radius", value: node.cssVariables["--og-radius"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-radius", value: value)
                                }
                                .id("\(node.id)-radius")

                                CSSVariableField(key: "--og-background", value: node.cssVariables["--og-background"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-background", value: value)
                                }
                                .id("\(node.id)-background")

                                CSSVariableField(key: "--og-foreground", value: node.cssVariables["--og-foreground"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-foreground", value: value)
                                }
                                .id("\(node.id)-foreground")

                                CSSVariableField(key: "--og-border", value: node.cssVariables["--og-border"] ?? "") { value in
                                    store.updateCSSVariable(key: "--og-border", value: value)
                                }
                                .id("\(node.id)-border")
                            }
                        }

                        if node.type == "text" {
                            InspectorSection(title: "Typography") {
                                InspectorFieldGrid {
                                    CSSVariableField(key: "--og-font-size", value: node.cssVariables["--og-font-size"] ?? "") { value in
                                        store.updateCSSVariable(key: "--og-font-size", value: value)
                                    }
                                    .id("\(node.id)-font-size")

                                    CSSVariableField(key: "--og-font-weight", value: node.cssVariables["--og-font-weight"] ?? "") { value in
                                        store.updateCSSVariable(key: "--og-font-weight", value: value)
                                    }
                                    .id("\(node.id)-font-weight")

                                    CSSVariableField(key: "--og-line-height", value: node.cssVariables["--og-line-height"] ?? "") { value in
                                        store.updateCSSVariable(key: "--og-line-height", value: value)
                                    }
                                    .id("\(node.id)-line-height")

                                    CSSVariableField(key: "--og-letter-spacing", value: node.cssVariables["--og-letter-spacing"] ?? "") { value in
                                        store.updateCSSVariable(key: "--og-letter-spacing", value: value)
                                    }
                                    .id("\(node.id)-letter-spacing")
                                }
                            }
                        }

                        InspectorSection(title: "Effects") {
                            CSSVariableField(key: "--og-shadow", value: node.cssVariables["--og-shadow"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-shadow", value: value)
                            }
                            .id("\(node.id)-shadow")
                        }
                    }
                    .padding(12)
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "scope",
                    description: Text("Layers または Canvas でノードを選択してください。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

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
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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

            VStack(spacing: 8) {
                content
            }
            .padding(10)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
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
/// 概要: `data-og-role` などの属性値をテキスト入力し、明示的に適用する入力行です。
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
                .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
                .onSubmit {
                    onCommit(draft)
                }

            ApplyButton {
                onCommit(draft)
            }
        }
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
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
                        RoundedRectangle(cornerRadius: 7)
                            .fill(value == option.0 ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(value == option.0 ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
    }
}

/// 論理名（日本語）: CSS変数フィールド
/// 概要: `--og-*` のキーと値入力欄、適用ボタンを表示します。
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
                    .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
                    .onSubmit {
                        onCommit(draft)
                    }

                ApplyButton {
                    onCommit(draft)
                }
            }
        }
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
    }
}

/// 論理名（日本語）: 適用ボタン
/// 概要: Inspector の入力欄で現在 draft を確定する小型チェックボタンです。
///
/// プロパティ:
/// - `action`: ボタン押下時の処理。
private struct ApplyButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
        .help("Apply")
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
                                    .fill(value == option.value ? Color.accentColor.opacity(0.2) : Color.clear)
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
