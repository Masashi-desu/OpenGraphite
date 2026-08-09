import SwiftUI

/// 論理名（日本語）: インスペクター整列モデル
/// 概要: WebKit computed `display` / `flex-direction`から導出したlayoutを踏まえ、標準CSS整列の軸と適用可否を判断します。
///
/// 定義内容:
/// - `isVerticalLayout(_:)`: layout 値が縦並びかどうか。
/// - `supportsAlignment(_:)`: layout 値が flex 整列を効かせられるかどうか。
/// - `resolvedAlignItems(_:computedValue:)`: authored未指定時のcomputed `align-items`。
/// - `resolvedJustifyContent(_:computedValue:)`: authored未指定時のcomputed `justify-content`。
enum InspectorAlignmentModel {
    /// 論理名（日本語）: 縦並び判定関数
    /// 処理概要: computed flex方向から導出済みのlayoutが縦並びかどうかを返します。
    ///
    /// - Parameter layout: WebKit computed styleから導出したlayout分類。
    /// - Returns: 縦並びの場合は true。
    static func isVerticalLayout(_ layout: String) -> Bool {
        layout.trimmingCharacters(in: .whitespacesAndNewlines) != "horizontal"
    }

    /// 論理名（日本語）: 整列適用可否判定関数
    /// 処理概要: 現在のcomputed formatting contextがflexまたはgridの場合だけ整列が効くと判定します。
    ///
    /// - Parameter layout: WebKit computed styleから導出したlayout分類。
    /// - Returns: 整列指定が描画へ反映される場合は true。
    static func supportsAlignment(_ layout: String) -> Bool {
        ["vertical", "horizontal", "grid"].contains(
            layout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    /// 論理名（日本語）: 実効align-items解決関数
    /// 処理概要: authored値を優先し、未指定時はWebKit computed値を返します。
    ///
    /// - Parameters:
    ///   - value: `align-items` の CSS 値。
    ///   - computedValue: WebKit computed `align-items`。
    /// - Returns: 実際に効いている `align-items` の値。
    static func resolvedAlignItems(_ value: String, computedValue: String) -> String {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty else { return normalizedValue }
        return computedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: 実効justify-content解決関数
    /// 処理概要: authored値を優先し、未指定時はWebKit computed値を返します。
    ///
    /// - Parameters:
    ///   - value: authored `justify-content` の CSS 値。
    ///   - computedValue: WebKit computed `justify-content`。
    /// - Returns: 実際に効いている `justify-content` の値。
    static func resolvedJustifyContent(_ value: String, computedValue: String) -> String {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty
            ? computedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            : normalizedValue
    }
}

/// 論理名（日本語）: インスペクター整列軸ストリップ
/// 概要: 主軸または交差軸の寄せ方を、レイアウト方向に合わせたアイコンで選択します。
///
/// プロパティ:
/// - `title`: 軸の表示名。
/// - `options`: 表示する選択肢。
/// - `selectedValue`: 現在の CSS 値。
/// - `effectiveValue`: 未指定時に効いている既定値。
/// - `onSelect`: 選択された CSS 値を反映する処理。
struct InspectorAlignmentAxisStrip: View {
    var title: String
    var options: [InspectorGlyphOption]
    var selectedValue: String
    var effectiveValue: String
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                if isUnset {
                    Text("既定: \(effectiveValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
            }

            InspectorGlyphOptionStrip(
                options: options,
                selectedValue: selectedValue,
                onSelect: onSelect
            )
        }
    }

    private var isUnset: Bool {
        selectedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 論理名（日本語）: インスペクター整列軸選択肢生成
/// 概要: レイアウト方向に応じて、主軸と交差軸それぞれのアイコン選択肢を組み立てます。
///
/// 定義内容:
/// - `mainAxisOptions(isVerticalLayout:)`: 主軸の寄せと分配の選択肢。
/// - `crossAxisOptions(isVerticalLayout:)`: 交差軸の寄せと stretch の選択肢。
enum InspectorAlignmentAxisOptions {
    /// 論理名（日本語）: 主軸選択肢生成関数
    /// 処理概要: 主軸方向のアイコンで、開始・中央・終了・均等配置の選択肢を返します。
    ///
    /// - Parameter isVerticalLayout: 縦並びかどうか。
    /// - Returns: 主軸の選択肢。
    static func mainAxisOptions(isVerticalLayout: Bool) -> [InspectorGlyphOption] {
        let axis = isVerticalLayout ? "vertical" : "horizontal"
        return [
            InspectorGlyphOption(
                value: "flex-start",
                label: isVerticalLayout ? "上寄せ" : "左寄せ",
                icon: .lucide(
                    "align-\(axis)-justify-start",
                    fallbackSystemName: isVerticalLayout ? "align.vertical.top" : "align.horizontal.left"
                )
            ),
            InspectorGlyphOption(
                value: "center",
                label: "中央",
                icon: .lucide(
                    "align-\(axis)-justify-center",
                    fallbackSystemName: isVerticalLayout ? "align.vertical.center" : "align.horizontal.center"
                )
            ),
            InspectorGlyphOption(
                value: "flex-end",
                label: isVerticalLayout ? "下寄せ" : "右寄せ",
                icon: .lucide(
                    "align-\(axis)-justify-end",
                    fallbackSystemName: isVerticalLayout ? "align.vertical.bottom" : "align.horizontal.right"
                )
            ),
            InspectorGlyphOption(
                value: "space-between",
                label: "両端",
                icon: .lucide(
                    "align-\(axis)-space-between",
                    fallbackSystemName: "rectangle.split.3x1"
                )
            ),
            InspectorGlyphOption(
                value: "space-around",
                label: "均等",
                icon: .lucide(
                    "align-\(axis)-space-around",
                    fallbackSystemName: "rectangle.split.3x1.fill"
                )
            )
        ]
    }

    /// 論理名（日本語）: 交差軸選択肢生成関数
    /// 処理概要: 交差軸方向のアイコンで、開始・中央・終了・伸長の選択肢を返します。
    ///
    /// - Parameter isVerticalLayout: 縦並びかどうか。
    /// - Returns: 交差軸の選択肢。
    static func crossAxisOptions(isVerticalLayout: Bool) -> [InspectorGlyphOption] {
        let axis = isVerticalLayout ? "horizontal" : "vertical"
        return [
            InspectorGlyphOption(
                value: "flex-start",
                label: isVerticalLayout ? "左寄せ" : "上寄せ",
                icon: .lucide(
                    "align-\(axis)-justify-start",
                    fallbackSystemName: isVerticalLayout ? "align.horizontal.left" : "align.vertical.top"
                )
            ),
            InspectorGlyphOption(
                value: "center",
                label: "中央",
                icon: .lucide(
                    "align-\(axis)-justify-center",
                    fallbackSystemName: isVerticalLayout ? "align.horizontal.center" : "align.vertical.center"
                )
            ),
            InspectorGlyphOption(
                value: "flex-end",
                label: isVerticalLayout ? "右寄せ" : "下寄せ",
                icon: .lucide(
                    "align-\(axis)-justify-end",
                    fallbackSystemName: isVerticalLayout ? "align.horizontal.right" : "align.vertical.bottom"
                )
            ),
            InspectorGlyphOption(
                value: "stretch",
                label: "伸長",
                icon: .lucide(
                    "stretch-\(axis)",
                    fallbackSystemName: "arrow.up.and.down.and.arrow.left.and.right"
                )
            )
        ]
    }
}

/// 論理名（日本語）: インスペクターレイアウトモードタイル
/// 概要: 標準`display` / `flex-direction`を、子要素の並び方を示す選択タイルで切り替えます。
///
/// プロパティ:
/// - `value`: 現在の layout 値。
/// - `onChange`: layout 選択時に呼び出す処理。
struct InspectorLayoutModeTiles: View {
    var value: String
    var onChange: (String) -> Void

    private let modes = ["vertical", "horizontal", "grid", "block"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(modes, id: \.self) { mode in
                tile(for: mode)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 論理名（日本語）: レイアウトモードタイル生成関数
    /// 処理概要: 並び方のアイコンと名称を持つ選択タイルを生成します。
    ///
    /// - Parameter mode: 対象の layout 値。
    /// - Returns: レイアウトモードタイル。
    private func tile(for mode: String) -> some View {
        let isSelected = value == mode
        return Button {
            onChange(mode)
        } label: {
            VStack(spacing: 4) {
                InspectorLayoutGlyph(mode: mode, isSelected: isSelected)
                    .frame(width: 30, height: 22)

                Text(mode)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .fill(isSelected ? EditorColumnStyle.accentFill : EditorColumnStyle.elevatedRowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.6) : EditorColumnStyle.separatorColor,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("標準CSSレイアウト: \(mode)")
        .accessibilityLabel(mode)
        .accessibilityValue(isSelected ? "selected" : "")
    }
}

/// 論理名（日本語）: インスペクターレイアウトアイコン
/// 概要: flex縦横、grid、標準block flowの子要素の並び方を選択タイル用アイコンとして描きます。
///
/// プロパティ:
/// - `mode`: 描画対象の layout 値。
/// - `isSelected`: 選択中かどうか。
struct InspectorLayoutGlyph: View {
    var mode: String
    var isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    strokeColor,
                    style: StrokeStyle(lineWidth: 1, dash: mode == "block" ? [2, 2] : [])
                )

            content
                .padding(3)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case "horizontal":
            HStack(spacing: 2) {
                bar(width: 4, height: nil)
                bar(width: 4, height: nil)
                bar(width: 4, height: nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case "grid":
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    bar(width: 7, height: 5)
                    bar(width: 7, height: 5)
                }
                GridRow {
                    bar(width: 7, height: 5)
                    bar(width: 7, height: 5)
                }
            }
        default:
            VStack(spacing: 2) {
                bar(width: nil, height: 3)
                bar(width: nil, height: 3)
                bar(width: nil, height: 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// 論理名（日本語）: レイアウトアイコン子要素生成関数
    /// 処理概要: アイコン内で子要素を表す小さな矩形を生成します。
    ///
    /// - Parameters:
    ///   - width: 固定幅。可変の場合は nil。
    ///   - height: 固定高さ。可変の場合は nil。
    /// - Returns: 子要素を表す矩形。
    private func bar(width: CGFloat?, height: CGFloat?) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(fillColor)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil)
    }

    private var fillColor: Color {
        isSelected ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.65)
    }

    private var strokeColor: Color {
        isSelected ? Color.accentColor.opacity(0.55) : EditorColumnStyle.separatorColor
    }
}
