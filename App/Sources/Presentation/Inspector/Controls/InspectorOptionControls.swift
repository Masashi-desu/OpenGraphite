import SwiftUI

/// 論理名（日本語）: インスペクターグリフ選択肢
/// 概要: 図やアイコンで意味を示す択一選択の 1 項目です。
///
/// プロパティ:
/// - `value`: 選択時に反映する CSS 値。
/// - `label`: tooltip とアクセシビリティに使う表示名。
struct InspectorGlyphOption: Identifiable {
    var value: String
    var label: String

    private let glyphBuilder: (Bool) -> AnyView

    var id: String { value }

    /// 論理名（日本語）: アイコン選択肢初期化関数
    /// 処理概要: 共通アイコン記述子を表示に使う選択肢を作ります。
    ///
    /// - Parameters:
    ///   - value: 反映する CSS 値。
    ///   - label: 表示名。
    ///   - icon: 表示するアイコン記述子。
    init(value: String, label: String, icon: OpenGraphiteIcon) {
        self.value = value
        self.label = label
        self.glyphBuilder = { _ in
            AnyView(OpenGraphiteIconView(icon: icon, size: 13, weight: .semibold))
        }
    }

    /// 論理名（日本語）: 図形選択肢初期化関数
    /// 処理概要: 選択状態に応じて描き分ける自作グリフを持つ選択肢を作ります。
    ///
    /// - Parameters:
    ///   - value: 反映する CSS 値。
    ///   - label: 表示名。
    ///   - glyph: 選択状態を受け取り、図を返すビルダー。
    init<Glyph: View>(value: String, label: String, @ViewBuilder glyph: @escaping (Bool) -> Glyph) {
        self.value = value
        self.label = label
        self.glyphBuilder = { isSelected in AnyView(glyph(isSelected)) }
    }

    /// 論理名（日本語）: 選択肢グリフ生成関数
    /// 処理概要: 選択状態に応じた表示要素を返します。
    ///
    /// - Parameter isSelected: 選択中かどうか。
    /// - Returns: 選択肢の表示要素。
    func glyphView(isSelected: Bool) -> AnyView {
        glyphBuilder(isSelected)
    }
}

/// 論理名（日本語）: インスペクターグリフ選択ストリップ
/// 概要: 図やアイコンだけで意味が伝わる択一選択を、等幅のセグメントとして並べます。
///
/// プロパティ:
/// - `options`: 表示する選択肢。
/// - `selectedValue`: 現在の CSS 値。
/// - `allowsDeselection`: 選択中の項目を再度押して未設定へ戻せるか。
/// - `onSelect`: 選択された CSS 値を反映する処理。
struct InspectorGlyphOptionStrip: View {
    var options: [InspectorGlyphOption]
    var selectedValue: String
    var allowsDeselection: Bool = true
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { entry in
                segment(for: entry.element)

                if entry.offset < options.count - 1 {
                    Rectangle()
                        .fill(EditorColumnStyle.separatorColor)
                        .frame(width: 1, height: 14)
                }
            }
        }
        .padding(1)
        .frame(maxWidth: .infinity)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .strokeBorder(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
    }

    /// 論理名（日本語）: グリフセグメント生成関数
    /// 処理概要: 1 つの選択肢を等幅のセグメントボタンとして生成します。
    ///
    /// - Parameter option: 対象の選択肢。
    /// - Returns: セグメントボタン。
    private func segment(for option: InspectorGlyphOption) -> some View {
        let isSelected = normalizedSelection == option.value

        return Button {
            if isSelected, allowsDeselection {
                onSelect("")
            } else {
                onSelect(option.value)
            }
        } label: {
            option.glyphView(isSelected: isSelected)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.82))
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius - 1)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(option.label)
        .accessibilityLabel(option.label)
        .accessibilityValue(isSelected ? "selected" : "")
    }

    private var normalizedSelection: String {
        selectedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 論理名（日本語）: インスペクター文字セグメントコントロール
/// 概要: 図では表せない列挙値を、Inspector の親幅に収まる等幅セグメントとして切り替えます。
///
/// プロパティ:
/// - `options`: 表示する値と表示名の組。
/// - `selectedValue`: 現在の値。
/// - `columnLimit`: 1 行に並べる最大セグメント数。
/// - `onSelect`: 選択された値を反映する処理。
struct InspectorSegmentedTextControl: View {
    var options: [(value: String, title: String)]
    var selectedValue: String
    var columnLimit: Int = 4
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(optionRows.enumerated()), id: \.offset) { rowEntry in
                HStack(spacing: 0) {
                    ForEach(Array(rowEntry.element.enumerated()), id: \.offset) { entry in
                        segment(value: entry.element.value, title: entry.element.title)

                        if entry.offset < rowEntry.element.count - 1 {
                            Rectangle()
                                .fill(EditorColumnStyle.separatorColor)
                                .frame(width: 1, height: 14)
                        }
                    }
                }
            }
        }
        .padding(1)
        .frame(maxWidth: .infinity)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .strokeBorder(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
    }

    /// 論理名（日本語）: 文字セグメント行分割
    /// 処理概要: 1 行あたりの上限を超える選択肢を、行ごとの数がそろうように分割します。
    private var optionRows: [[(value: String, title: String)]] {
        guard columnLimit > 0, options.count > columnLimit else { return [options] }

        let rowCount = Int(ceil(Double(options.count) / Double(columnLimit)))
        let perRow = Int(ceil(Double(options.count) / Double(rowCount)))
        return stride(from: 0, to: options.count, by: perRow).map { startIndex in
            Array(options[startIndex..<min(startIndex + perRow, options.count)])
        }
    }

    /// 論理名（日本語）: 文字セグメント生成関数
    /// 処理概要: 1 つの列挙値を等幅のセグメントボタンとして生成します。
    ///
    /// - Parameters:
    ///   - value: 反映する値。
    ///   - title: 表示名。
    /// - Returns: セグメントボタン。
    private func segment(value: String, title: String) -> some View {
        let isSelected = selectedValue.trimmingCharacters(in: .whitespacesAndNewlines) == value

        return Button {
            guard !isSelected else { return }
            onSelect(value)
        } label: {
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.82))
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 22)
                .background(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius - 1)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "selected" : "")
    }
}

/// 論理名（日本語）: インスペクターオブジェクトフィットグリフ
/// 概要: `object-fit` の各モードで画像が枠へどう収まるかを、枠と画像の図として描きます。
///
/// プロパティ:
/// - `mode`: 描画対象の object-fit 値。
/// - `isSelected`: 選択中かどうか。
struct InspectorObjectFitGlyph: View {
    var mode: String
    var isSelected: Bool

    private let frameSize = CGSize(width: 20, height: 15)

    var body: some View {
        Color.clear
            .frame(width: frameSize.width, height: frameSize.height)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(imageFill)
                    .frame(width: imageSize.width, height: imageSize.height)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2.5))
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var imageSize: CGSize {
        switch mode {
        case "contain":
            return CGSize(width: frameSize.width * 0.62, height: frameSize.height)
        case "fill":
            return frameSize
        case "none":
            return CGSize(width: frameSize.width * 1.5, height: frameSize.height * 1.5)
        case "scale-down":
            return CGSize(width: frameSize.width * 0.45, height: frameSize.height * 0.72)
        default:
            return CGSize(width: frameSize.width * 1.35, height: frameSize.height * 1.35)
        }
    }

    private var imageFill: Color {
        isSelected ? Color.white.opacity(0.85) : Color.accentColor.opacity(0.55)
    }

    private var strokeColor: Color {
        isSelected ? Color.white.opacity(0.9) : Color.secondary.opacity(0.7)
    }
}

/// 論理名（日本語）: インスペクター罫線スタイルプレビュー
/// 概要: `border-style` の見え方を、実際の線種で引いた 1 本の線として示します。
///
/// プロパティ:
/// - `style`: 描画対象の border-style 値。
/// - `width`: 線の太さ。
/// - `color`: 線の色。
struct InspectorBorderStylePreview: View {
    var style: String
    var width: CGFloat
    var color: Color

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            guard style != "none", style != "hidden", width > 0 else { return }

            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))

            if style == "double" {
                let offset = max(width, 1)
                var upper = Path()
                upper.move(to: CGPoint(x: 0, y: midY - offset))
                upper.addLine(to: CGPoint(x: size.width, y: midY - offset))
                var lower = Path()
                lower.move(to: CGPoint(x: 0, y: midY + offset))
                lower.addLine(to: CGPoint(x: size.width, y: midY + offset))
                context.stroke(upper, with: .color(color), lineWidth: max(1, width / 2))
                context.stroke(lower, with: .color(color), lineWidth: max(1, width / 2))
                return
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: max(1, width),
                    lineCap: style == "dotted" ? .round : .butt,
                    dash: dashPattern
                )
            )
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private var dashPattern: [CGFloat] {
        switch style {
        case "dashed":
            return [5, 3]
        case "dotted":
            return [0.5, max(2, width * 2)]
        default:
            return []
        }
    }
}

/// 論理名（日本語）: インスペクター選択肢定義
/// 概要: 図で意味が伝わる CSS 列挙値について、Inspector が使う選択肢一覧をまとめます。
///
/// 定義内容:
/// - `textAlign`: `text-align` の選択肢。
/// - `objectFit`: `object-fit` の選択肢。
/// - `position`: `position` の選択肢。
/// - `dimensionKind`: 寸法値の入力方式。
enum InspectorOptionCatalog {
    static let textAlign: [InspectorGlyphOption] = [
        InspectorGlyphOption(
            value: "left",
            label: "左揃え",
            icon: .lucide("align-left", fallbackSystemName: "text.alignleft")
        ),
        InspectorGlyphOption(
            value: "center",
            label: "中央揃え",
            icon: .lucide("align-center", fallbackSystemName: "text.aligncenter")
        ),
        InspectorGlyphOption(
            value: "right",
            label: "右揃え",
            icon: .lucide("align-right", fallbackSystemName: "text.alignright")
        ),
        InspectorGlyphOption(
            value: "justify",
            label: "両端揃え",
            icon: .lucide("align-justify", fallbackSystemName: "text.justify")
        ),
        InspectorGlyphOption(
            value: "start",
            label: "書字方向の開始側",
            icon: .lucide("align-start-horizontal", fallbackSystemName: "text.alignleft")
        ),
        InspectorGlyphOption(
            value: "end",
            label: "書字方向の終了側",
            icon: .lucide("align-end-horizontal", fallbackSystemName: "text.alignright")
        )
    ]

    static let objectFit: [InspectorGlyphOption] = [
        "cover",
        "contain",
        "fill",
        "none",
        "scale-down"
    ].map { mode in
        InspectorGlyphOption(value: mode, label: mode) { isSelected in
            InspectorObjectFitGlyph(mode: mode, isSelected: isSelected)
        }
    }

    static let position: [(value: String, title: String)] = [
        ("", "unset"),
        ("static", "static"),
        ("relative", "relative"),
        ("absolute", "absolute"),
        ("fixed", "fixed"),
        ("sticky", "sticky")
    ]

    static let dimensionKind: [(value: String, title: String)] = [
        (CSSDimensionKind.empty.rawValue, "unset"),
        (CSSDimensionKind.length.rawValue, "length"),
        (CSSDimensionKind.keyword.rawValue, "keyword"),
        (CSSDimensionKind.function.rawValue, "function")
    ]
}
