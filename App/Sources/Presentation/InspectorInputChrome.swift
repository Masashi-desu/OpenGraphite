import SwiftUI

/// 論理名（日本語）: インスペクター入力アイコン
/// 概要: Inspector の入力欄に表示するアイコンと回転角をまとめます。
///
/// プロパティ:
/// - `icon`: 描画するアイコン。
/// - `rotationDegrees`: 入力欄内で適用する回転角。
struct InspectorInputIcon: Hashable, Sendable {
    var icon: OpenGraphiteIcon
    var rotationDegrees: Double

    /// 論理名（日本語）: インスペクター入力アイコン初期化関数
    /// 処理概要: 共通アイコン記述子と必要な回転角を保持します。
    ///
    /// - Parameters:
    ///   - icon: 描画するアイコン。
    ///   - rotationDegrees: 入力欄内で適用する回転角。
    init(_ icon: OpenGraphiteIcon, rotationDegrees: Double = 0) {
        self.icon = icon
        self.rotationDegrees = rotationDegrees
    }
}

/// 論理名（日本語）: インスペクター入力クローム
/// 概要: Inspector 内のテキスト入力欄へ共通背景、枠線、左側アイコンを付与します。
///
/// プロパティ:
/// - `icon`: 入力値の意味を示す左側アイコン。
/// - `iconHelp`: アイコンに付与する tooltip。
/// - `strokeColor`: 入力欄の枠線色。
/// - `content`: 背景内に配置する入力要素。
struct InspectorInputChrome<Content: View>: View {
    var icon: InspectorInputIcon?
    var iconHelp: String
    var strokeColor: Color
    var content: Content

    /// 論理名（日本語）: インスペクター入力クローム初期化関数
    /// 処理概要: 任意の左側アイコンと入力要素を共通の入力背景へまとめます。
    ///
    /// - Parameters:
    ///   - icon: 入力値の意味を示す左側アイコン。
    ///   - iconHelp: アイコンに付与する tooltip。
    ///   - strokeColor: 入力欄の枠線色。
    ///   - content: 背景内に配置する入力要素。
    init(
        icon: InspectorInputIcon? = nil,
        iconHelp: String = "",
        strokeColor: Color = .clear,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconHelp = iconHelp
        self.strokeColor = strokeColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                OpenGraphiteIconView(icon: icon.icon, size: 13, weight: .semibold)
                    .rotationEffect(.degrees(icon.rotationDegrees))
                    .foregroundStyle(.secondary)
                    .frame(width: 15, height: 16)
                    .help(iconHelp)
            }

            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

/// 論理名（日本語）: インスペクターパラメータアイコン
/// 概要: Inspector の編集可能パラメータ名や入力ラベルから意味を示すアイコンを選びます。
enum InspectorParameterIcon {
    /// 論理名（日本語）: CSS変数アイコン判定関数
    /// 処理概要: `--og-*` CSS 変数名に対応する入力アイコンを返します。
    ///
    /// - Parameter key: CSS 変数名。
    /// - Returns: 変数の意味を表すアイコン。
    static func cssVariable(_ key: String) -> InspectorInputIcon {
        switch key {
        case "--og-x", "--og-scale-x":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "--og-y", "--og-scale-y":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        case "--og-width", "--og-min-width", "--og-max-width":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "--og-height", "--og-min-height":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "--og-font-family":
            return InspectorInputIcon(.lucide("type", fallbackSystemName: "textformat"))
        case "--og-font-size":
            return InspectorInputIcon(.lucide("text-cursor-input", fallbackSystemName: "textformat.size"))
        case "--og-font-weight":
            return InspectorInputIcon(.lucide("bold", fallbackSystemName: "bold"))
        case "--og-line-height":
            return InspectorInputIcon(.lucide("list-collapse", fallbackSystemName: "line.3.horizontal"))
        case "--og-letter-spacing":
            return InspectorInputIcon(.lucide("case-sensitive", fallbackSystemName: "textformat.abc"))
        case "--og-stroke-width":
            return InspectorInputIcon(.lucide("circle", fallbackSystemName: "circle"))
        case "--og-foreground":
            return InspectorInputIcon(.lucide("palette", fallbackSystemName: "paintpalette"))
        case "--og-background":
            return InspectorInputIcon(.lucide("paint-bucket", fallbackSystemName: "paintbrush"))
        case "--og-border":
            return InspectorInputIcon(.lucide("square", fallbackSystemName: "square"))
        case "--og-shadow":
            return InspectorInputIcon(.lucide("sun", fallbackSystemName: "sun.min"))
        case "--og-flex":
            return InspectorInputIcon(.lucide("stretch-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "--og-transform-origin":
            return InspectorInputIcon(.lucide("crosshair", fallbackSystemName: "scope"))
        default:
            return InspectorInputIcon(.lucide("settings-2", fallbackSystemName: "slider.horizontal.3"))
        }
    }

    /// 論理名（日本語）: CSS小型入力アイコン判定関数
    /// 処理概要: CSS shorthand の部分ラベルと変数名に対応する入力アイコンを返します。
    ///
    /// - Parameters:
    ///   - label: 入力欄ラベル。
    ///   - key: 関連する CSS 変数名。
    /// - Returns: 入力欄の意味を表すアイコン。
    static func cssSubfield(label: String, key: String) -> InspectorInputIcon {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "--og-gap":
            return normalizedLabel == "row"
                ? InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
                : InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "--og-padding", "--og-margin":
            return edgeIcon(for: normalizedLabel)
        case "--og-radius":
            return cornerIcon(for: normalizedLabel)
        case "--og-border":
            return InspectorInputIcon(.lucide("circle", fallbackSystemName: "circle"))
        case "--og-background":
            return normalizedLabel == "angle"
                ? InspectorInputIcon(.lucide("rotate-cw", fallbackSystemName: "arrow.clockwise"))
                : colorValue
        case "--og-shadow":
            return shadowIcon(for: normalizedLabel)
        case "--og-flex":
            return flexIcon(for: normalizedLabel)
        case "--og-transform-origin":
            return axisIcon(for: normalizedLabel)
        default:
            return labelIcon(normalizedLabel)
        }
    }

    /// 論理名（日本語）: ラベルアイコン判定関数
    /// 処理概要: 一般的な入力ラベルから対応する入力アイコンを返します。
    ///
    /// - Parameter label: 入力欄ラベル。
    /// - Returns: 入力欄の意味を表すアイコン。
    static func label(_ label: String) -> InspectorInputIcon {
        labelIcon(label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// 論理名（日本語）: 属性アイコン判定関数
    /// 処理概要: `data-og-*` や HTML document context の属性名に対応する入力アイコンを返します。
    ///
    /// - Parameter label: 属性または設定の表示名。
    /// - Returns: 属性値の意味を表すアイコン。
    static func attribute(_ label: String) -> InspectorInputIcon {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedLabel.contains("icon") {
            return InspectorInputIcon(.lucide("star", fallbackSystemName: "star"))
        }
        if normalizedLabel.contains("path") {
            return InspectorInputIcon(.lucide("folder", fallbackSystemName: "folder"))
        }
        if normalizedLabel.contains("locale") || normalizedLabel.contains("lang") {
            return InspectorInputIcon(.lucide("languages", fallbackSystemName: "character.book.closed"))
        }
        if normalizedLabel.contains("dir") {
            return InspectorInputIcon(.lucide("pilcrow", fallbackSystemName: "text.alignleft"))
        }
        if normalizedLabel.contains("field") || normalizedLabel.contains("binding") {
            return InspectorInputIcon(.lucide("braces", fallbackSystemName: "curlybraces"))
        }
        if normalizedLabel.contains("name") {
            return InspectorInputIcon(.lucide("tag", fallbackSystemName: "tag"))
        }
        if normalizedLabel.contains("role") {
            return InspectorInputIcon(.lucide("badge", fallbackSystemName: "tag"))
        }
        return InspectorInputIcon(.lucide("tag", fallbackSystemName: "tag"))
    }

    /// 論理名（日本語）: キャンバスメトリックアイコン判定関数
    /// 処理概要: Page canvas の位置やサイズラベルに対応する入力アイコンを返します。
    ///
    /// - Parameter label: キャンバスメトリックの表示名。
    /// - Returns: メトリックの意味を表すアイコン。
    static func canvasMetric(_ label: String) -> InspectorInputIcon {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedLabel {
        case "x":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "y":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        case "width":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "height":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        default:
            return InspectorInputIcon(.lucide("frame", fallbackSystemName: "square.dashed"))
        }
    }

    static let colorValue = InspectorInputIcon(.lucide("palette", fallbackSystemName: "paintpalette"))
    static let parameterValue = InspectorInputIcon(.lucide("sliders-horizontal", fallbackSystemName: "slider.horizontal.3"))

    private static func edgeIcon(for label: String) -> InspectorInputIcon {
        switch label {
        case "t", "top":
            return InspectorInputIcon(.lucide("arrow-up-to-line", fallbackSystemName: "arrow.up"))
        case "r", "right":
            return InspectorInputIcon(.lucide("arrow-right-to-line", fallbackSystemName: "arrow.right"))
        case "b", "bottom":
            return InspectorInputIcon(.lucide("arrow-down-to-line", fallbackSystemName: "arrow.down"))
        case "l", "left":
            return InspectorInputIcon(.lucide("arrow-left-to-line", fallbackSystemName: "arrow.left"))
        default:
            return InspectorInputIcon(.lucide("box", fallbackSystemName: "square"))
        }
    }

    private static func cornerIcon(for label: String) -> InspectorInputIcon {
        let icon = OpenGraphiteIcon.lucide("square-round-corner", fallbackSystemName: "square")
        switch label {
        case "tl":
            return InspectorInputIcon(icon, rotationDegrees: -90)
        case "tr":
            return InspectorInputIcon(icon)
        case "br":
            return InspectorInputIcon(icon, rotationDegrees: 90)
        case "bl":
            return InspectorInputIcon(icon, rotationDegrees: 180)
        default:
            return InspectorInputIcon(icon)
        }
    }

    private static func shadowIcon(for label: String) -> InspectorInputIcon {
        switch label {
        case "x":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "y":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        case "blur":
            return InspectorInputIcon(.lucide("sun", fallbackSystemName: "sun.min"))
        case "spread":
            return InspectorInputIcon(.lucide("expand", fallbackSystemName: "arrow.up.left.and.arrow.down.right"))
        default:
            return InspectorInputIcon(.lucide("sun", fallbackSystemName: "sun.min"))
        }
    }

    private static func flexIcon(for label: String) -> InspectorInputIcon {
        switch label {
        case "grow":
            return InspectorInputIcon(.lucide("plus", fallbackSystemName: "plus"))
        case "shrink":
            return InspectorInputIcon(.lucide("minus", fallbackSystemName: "minus"))
        case "basis":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        default:
            return InspectorInputIcon(.lucide("stretch-horizontal", fallbackSystemName: "arrow.left.and.right"))
        }
    }

    private static func axisIcon(for label: String) -> InspectorInputIcon {
        switch label {
        case "x", "column":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "y", "row":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        default:
            return InspectorInputIcon(.lucide("crosshair", fallbackSystemName: "scope"))
        }
    }

    private static func labelIcon(_ label: String) -> InspectorInputIcon {
        switch label {
        case "x":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "y":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        case "width", "value", "basis":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "height":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "position":
            return InspectorInputIcon(.lucide("map-pin", fallbackSystemName: "mappin"))
        case "color":
            return colorValue
        default:
            return parameterValue
        }
    }
}
