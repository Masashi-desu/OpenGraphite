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

                        if let componentSource = store.selectedComponentSource {
                            ComponentSourceSection(source: componentSource) {
                                store.revealComponentSource(componentSource)
                            }
                        }

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
                                    InspectorButtonOption(label: "L", icon: .alignHorizontalStart, value: "flex-start"),
                                    InspectorButtonOption(label: "C", icon: .alignHorizontalCenter, value: "center"),
                                    InspectorButtonOption(label: "R", icon: .alignHorizontalEnd, value: "flex-end")
                                ]
                            ) { value in
                                store.updateCSSVariable(key: "--og-align", value: value)
                            }

                            InspectorButtonStrip(
                                title: "Justify",
                                value: node.cssVariables["--og-justify"] ?? "",
                                options: [
                                    InspectorButtonOption(label: "T", icon: .alignVerticalStart, value: "flex-start"),
                                    InspectorButtonOption(label: "M", icon: .alignVerticalCenter, value: "center"),
                                    InspectorButtonOption(label: "B", icon: .alignVerticalEnd, value: "flex-end")
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
            } else if let page = store.selectedPage {
                PageInspectorView(page: page) { x, y, width, height, name in
                    store.updateSelectedPageCanvas(x: x, y: y, width: width, height: height, name: name)
                }
                .id(page.id)
            } else {
                InspectorEmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 論理名（日本語）: コンポーネント継承元セクション
/// 概要: 選択中 instance が参照する component master の名称、場所、移動操作を表示します。
///
/// プロパティ:
/// - `source`: 表示する component master 情報。
/// - `onReveal`: component master canvas へ移動する処理。
private struct ComponentSourceSection: View {
    var source: OpenGraphiteComponentSource
    var onReveal: () -> Void

    var body: some View {
        InspectorSection(title: "Component") {
            InspectorInfoRow(label: "name", value: source.componentID)
            InspectorInfoRow(label: "location", value: source.locationLabel)
            InspectorInfoRow(label: "path", value: source.componentPagePath)
            InspectorInfoRow(label: "canvas", value: source.canvasLabel)

            Button(action: onReveal) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.square")
                    Text("Go to Component")
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Component master を表示")
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

/// 論理名（日本語）: ページキャンバス入力値
/// 概要: Inspector で編集するページのキャンバス座標と解像度をまとめます。
///
/// プロパティ:
/// - `x`: キャンバス上の X 座標。
/// - `y`: キャンバス上の Y 座標。
/// - `width`: ページプレビュー幅。
/// - `height`: ページプレビュー高さ。
/// - `name`: フロー解決に使う配置名。名前なしは空文字です。
private struct PageCanvasInput: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var name: String

    /// 論理名（日本語）: ページキャンバス入力値初期化関数
    /// 処理概要: `OpenGraphiteCanvas` から Inspector 入力比較用の値を生成します。
    ///
    /// - Parameter canvas: 入力値へ変換するキャンバス定義。
    init(canvas: OpenGraphiteCanvas) {
        x = canvas.x
        y = canvas.y
        width = canvas.width
        height = canvas.height
        name = Self.normalizedName(canvas.name)
    }

    /// 論理名（日本語）: ページキャンバス入力値初期化関数
    /// 処理概要: パース済みの各数値から Inspector 入力値を生成します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。
    ///   - height: ページプレビュー高さ。
    ///   - name: フロー解決に使う配置名。
    init(x: Double, y: Double, width: Double, height: Double, name: String) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.name = Self.normalizedName(name)
    }

    /// 論理名（日本語）: ページキャンバス配置名正規化関数
    /// 処理概要: 入力された配置名の前後空白を除去し、空なら空文字へ変換します。
    ///
    /// - Parameter name: 正規化する配置名。
    /// - Returns: 比較・保存用の配置名。
    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 論理名（日本語）: ページインスペクタービュー
/// 概要: 選択ページの HTML 相対パス、解像度、キャンバス配置を表示・編集します。
///
/// プロパティ:
/// - `page`: 表示・編集対象のページ。
/// - `onCommit`: 有効なキャンバス入力を適用する処理。
private struct PageInspectorView: View {
    var page: OpenGraphitePage
    var onCommit: (Double, Double, Double, Double, String) -> Void

    @State private var nameDraft: String
    @State private var xDraft: String
    @State private var yDraft: String
    @State private var widthDraft: String
    @State private var heightDraft: String

    /// 論理名（日本語）: ページインスペクター初期化関数
    /// 処理概要: 選択ページの現在キャンバス値を入力欄の初期値として保持します。
    ///
    /// - Parameters:
    ///   - page: 表示・編集対象のページ。
    ///   - onCommit: 有効なキャンバス入力を適用する処理。
    init(page: OpenGraphitePage, onCommit: @escaping (Double, Double, Double, Double, String) -> Void) {
        self.page = page
        self.onCommit = onCommit
        _nameDraft = State(initialValue: page.canvas.displayName ?? "")
        _xDraft = State(initialValue: Self.draftText(for: page.canvas.x))
        _yDraft = State(initialValue: Self.draftText(for: page.canvas.y))
        _widthDraft = State(initialValue: Self.draftText(for: page.canvas.width))
        _heightDraft = State(initialValue: Self.draftText(for: page.canvas.height))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PageSummaryPanel(page: page)

                InspectorSection(title: "Context") {
                    InspectorInfoRow(label: "path", value: page.path)
                    InspectorInfoRow(label: "name", value: page.canvas.displayName ?? "-")
                    InspectorInfoRow(label: "resolution", value: page.canvas.resolutionLabel)
                    InspectorInfoRow(label: "position", value: page.canvas.positionLabel)
                }

                InspectorSection(title: "Canvas") {
                    OptionalCanvasNameField(
                        label: "Name",
                        text: $nameDraft,
                        onSubmit: commitIfValid
                    )

                    InspectorFieldGrid {
                        RequiredCanvasNumberField(
                            label: "X",
                            text: $xDraft,
                            isInvalid: isInvalidDraft(xDraft),
                            onSubmit: commitIfValid
                        )

                        RequiredCanvasNumberField(
                            label: "Y",
                            text: $yDraft,
                            isInvalid: isInvalidDraft(yDraft),
                            onSubmit: commitIfValid
                        )

                        RequiredCanvasNumberField(
                            label: "Width",
                            text: $widthDraft,
                            isInvalid: isInvalidDraft(widthDraft, requiresPositive: true),
                            onSubmit: commitIfValid
                        )

                        RequiredCanvasNumberField(
                            label: "Height",
                            text: $heightDraft,
                            isInvalid: isInvalidDraft(heightDraft, requiresPositive: true),
                            onSubmit: commitIfValid
                        )
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption2)
                            .foregroundStyle(Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: commitIfValid) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Apply")
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(canCommit ? Color.white : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                .fill(canCommit ? Color.accentColor : EditorColumnStyle.elevatedRowFill)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCommit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: page.canvas) { _, nextCanvas in
            resetDrafts(with: nextCanvas)
        }
    }

    private var normalizedDrafts: [String] {
        [
            xDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            yDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            widthDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            heightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private var normalizedNameDraft: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedInput: PageCanvasInput? {
        guard validationMessage == nil else { return nil }
        let values = normalizedDrafts
        guard let x = Double(values[0]),
              let y = Double(values[1]),
              let width = Double(values[2]),
              let height = Double(values[3])
        else {
            return nil
        }
        return PageCanvasInput(x: x, y: y, width: width, height: height, name: normalizedNameDraft)
    }

    private var validationMessage: String? {
        let values = normalizedDrafts
        guard !values.contains(where: \.isEmpty) else {
            return "X / Y / Width / Height はすべて入力必須です。"
        }
        guard let x = Double(values[0]),
              let y = Double(values[1]),
              let width = Double(values[2]),
              let height = Double(values[3])
        else {
            return "キャンバス配置には数値を入力してください。"
        }
        guard [x, y, width, height].allSatisfy(\.isFinite) else {
            return "キャンバス配置には有限の数値を入力してください。"
        }
        guard width > 0, height > 0 else {
            return "Width / Height は 0 より大きい数値が必要です。"
        }
        return nil
    }

    private var canCommit: Bool {
        guard let parsedInput else { return false }
        return parsedInput != PageCanvasInput(canvas: page.canvas)
    }

    /// 論理名（日本語）: ページキャンバス入力確定関数
    /// 処理概要: 必須入力と数値条件を満たす場合だけキャンバス配置を適用します。
    private func commitIfValid() {
        guard let parsedInput else { return }
        onCommit(parsedInput.x, parsedInput.y, parsedInput.width, parsedInput.height, parsedInput.name)
    }

    /// 論理名（日本語）: ページキャンバスdraftリセット関数
    /// 処理概要: Store 側で更新されたキャンバス値を入力欄へ反映します。
    ///
    /// - Parameter canvas: 入力欄へ反映するキャンバス定義。
    private func resetDrafts(with canvas: OpenGraphiteCanvas) {
        nameDraft = canvas.displayName ?? ""
        xDraft = Self.draftText(for: canvas.x)
        yDraft = Self.draftText(for: canvas.y)
        widthDraft = Self.draftText(for: canvas.width)
        heightDraft = Self.draftText(for: canvas.height)
    }

    /// 論理名（日本語）: ページキャンバスdraft検証関数
    /// 処理概要: 単一入力欄が必須・数値・正値条件を満たさない場合に invalid と判定します。
    ///
    /// - Parameters:
    ///   - draft: 検証する入力文字列。
    ///   - requiresPositive: 0 より大きい値が必要か。
    /// - Returns: 入力が不正な場合は `true`。
    private func isInvalidDraft(_ draft: String, requiresPositive: Bool = false) -> Bool {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let number = Double(value),
              number.isFinite
        else {
            return true
        }
        return requiresPositive && number <= 0
    }

    /// 論理名（日本語）: ページキャンバスdraft文字列生成関数
    /// 処理概要: 数値の編集しやすさを優先し、整数値は小数点なしで表示します。
    ///
    /// - Parameter value: 入力欄に表示する数値。
    /// - Returns: 入力欄向けの文字列。
    private static func draftText(for value: Double) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(value)
    }
}

/// 論理名（日本語）: ページ概要パネル
/// 概要: Inspector 上部に選択ページの識別子、HTML 相対パス、解像度を表示します。
///
/// プロパティ:
/// - `page`: 表示対象のページ。
private struct PageSummaryPanel: View {
    var page: OpenGraphitePage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.id)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(page.path) · \(page.canvas.resolutionLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
}

/// 論理名（日本語）: 任意キャンバス名フィールド
/// 概要: Page canvas のフロー解決用配置名を入力する任意テキスト欄です。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力文字列 binding。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct OptionalCanvasNameField: View {
    var label: String
    @Binding var text: String
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .lineLimit(1)
            }

            TextField("desktop", text: $text)
                .textFieldStyle(.plain)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .onSubmit(onSubmit)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: 必須キャンバス数値フィールド
/// 概要: ページキャンバス配置用の必須数値入力欄を表示します。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力文字列 binding。
/// - `isInvalid`: 入力欄を invalid 表示にするか。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct RequiredCanvasNumberField: View {
    var label: String
    @Binding var text: String
    var isInvalid: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("required")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(isInvalid ? Color.red.opacity(0.65) : Color.clear, lineWidth: 1)
                )
                .onSubmit(onSubmit)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
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

            Text("Pages / Components のカードまたは Canvas でページかノードを選択してください。")
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
                Image(systemName: "slash.circle")
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
/// - `icon`: 表示するアイコン。
/// - `value`: 適用する CSS 変数値。
private struct InspectorButtonOption: Identifiable {
    var label: String
    var icon: OpenGraphiteIcon
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
                        OpenGraphiteIconView(icon: option.icon, size: 13)
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
