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

/// 論理名（日本語）: インスペクター入力スクラブ設定
/// 概要: 入力欄のアイコンをドラッグして数値を直接増減させるための接続情報です。
///
/// プロパティ:
/// - `profile`: ドラッグ編集の粒度と単位。
/// - `currentValue`: ドラッグ開始時に読み取る現在値。
/// - `onScrub`: ドラッグ中の値を UI 状態へ反映する処理。
/// - `onCommit`: ドラッグ終了時の確定処理。
struct InspectorInputScrubConfiguration {
    var profile: InspectorScrubProfile
    var currentValue: () -> String
    var onScrub: (String) -> Void
    var onCommit: () -> Void

    /// 論理名（日本語）: インスペクター入力スクラブ設定初期化関数
    /// 処理概要: ドラッグ編集に必要な粒度と値の読み書き処理を保持します。
    ///
    /// - Parameters:
    ///   - profile: ドラッグ編集の粒度と単位。
    ///   - currentValue: ドラッグ開始時に読み取る現在値。
    ///   - onScrub: ドラッグ中の値を反映する処理。
    ///   - onCommit: ドラッグ終了時の確定処理。
    init(
        profile: InspectorScrubProfile = .length,
        currentValue: @escaping () -> String,
        onScrub: @escaping (String) -> Void,
        onCommit: @escaping () -> Void = {}
    ) {
        self.profile = profile
        self.currentValue = currentValue
        self.onScrub = onScrub
        self.onCommit = onCommit
    }
}

/// 論理名（日本語）: インスペクター入力クローム
/// 概要: Inspector 内のテキスト入力欄へ共通背景、枠線、左側アイコンを付与し、アイコンを値のドラッグ操作面としても使えるようにします。
///
/// プロパティ:
/// - `icon`: 入力値の意味を示す左側アイコン。
/// - `iconHelp`: アイコンに付与する tooltip。
/// - `strokeColor`: 入力欄の枠線色。
/// - `scrub`: アイコンをドラッグして値を増減させる設定。
/// - `content`: 背景内に配置する入力要素。
struct InspectorInputChrome<Content: View>: View {
    var icon: InspectorInputIcon?
    var iconHelp: String
    var strokeColor: Color
    var scrub: InspectorInputScrubConfiguration?
    var content: Content

    /// 論理名（日本語）: インスペクター入力クローム初期化関数
    /// 処理概要: 任意の左側アイコンと入力要素を共通の入力背景へまとめます。
    ///
    /// - Parameters:
    ///   - icon: 入力値の意味を示す左側アイコン。
    ///   - iconHelp: アイコンに付与する tooltip。
    ///   - strokeColor: 入力欄の枠線色。
    ///   - scrub: アイコンをドラッグして値を増減させる設定。
    ///   - content: 背景内に配置する入力要素。
    init(
        icon: InspectorInputIcon? = nil,
        iconHelp: String = "",
        strokeColor: Color = .clear,
        scrub: InspectorInputScrubConfiguration? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconHelp = iconHelp
        self.strokeColor = strokeColor
        self.scrub = scrub
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                iconView(for: icon)
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

    /// 論理名（日本語）: 入力アイコン生成関数
    /// 処理概要: スクラブ設定がある場合はアイコンをドラッグハンドルとして構成します。
    ///
    /// - Parameter icon: 表示するアイコン記述子。
    /// - Returns: 入力欄左側のアイコン。
    @ViewBuilder
    private func iconView(for icon: InspectorInputIcon) -> some View {
        let iconImage = OpenGraphiteIconView(icon: icon.icon, size: 13, weight: .semibold)
            .rotationEffect(.degrees(icon.rotationDegrees))
            .foregroundStyle(scrub == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor.opacity(0.85)))
            .frame(width: 15, height: 16)

        if let scrub {
            InspectorScrubHandle(
                isEnabled: InspectorValueScrubber.isScrubbable(scrub.currentValue()),
                step: scrub.profile.step,
                fallbackUnit: scrub.profile.fallbackUnit,
                allowsNegative: scrub.profile.allowsNegative,
                currentValue: scrub.currentValue,
                onScrub: scrub.onScrub,
                onCommit: scrub.onCommit
            ) {
                iconImage
            }
            .help(iconHelp.isEmpty ? "左右ドラッグで値を変更" : "\(iconHelp) · 左右ドラッグで値を変更")
        } else {
            iconImage
                .help(iconHelp)
        }
    }
}

/// 論理名（日本語）: インスペクターパラメータアイコン
/// 概要: Inspector の編集可能パラメータ名や入力ラベルから意味を示すアイコンを選びます。
enum InspectorParameterIcon {
    /// 論理名（日本語）: CSSパラメータアイコン判定関数
    /// 処理概要: CSS property 名または OpenGraphite 予約 custom property 名に対応する入力アイコンを返します。
    ///
    /// - Parameter key: CSS property または OpenGraphite 予約 custom property 名。
    /// - Returns: パラメータの意味を表すアイコン。
    static func cssVariable(_ key: String) -> InspectorInputIcon {
        switch key {
        case "left", "right", "--og-scale-x":
            return InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "top", "bottom", "--og-scale-y":
            return InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
        case "position":
            return InspectorInputIcon(.lucide("map-pin", fallbackSystemName: "mappin"))
        case "z-index":
            return InspectorInputIcon(.lucide("layers", fallbackSystemName: "square.3.layers.3d"))
        case "width", "min-width", "max-width":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "height", "min-height":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "font-family":
            return InspectorInputIcon(.lucide("type", fallbackSystemName: "textformat"))
        case "font-size":
            return InspectorInputIcon(.lucide("text-cursor-input", fallbackSystemName: "textformat.size"))
        case "font-weight":
            return InspectorInputIcon(.lucide("bold", fallbackSystemName: "bold"))
        case "line-height":
            return InspectorInputIcon(.lucide("list-collapse", fallbackSystemName: "line.3.horizontal"))
        case "letter-spacing":
            return InspectorInputIcon(.lucide("case-sensitive", fallbackSystemName: "textformat.abc"))
        case "--og-stroke-width":
            return InspectorInputIcon(.lucide("circle", fallbackSystemName: "circle"))
        case "color":
            return InspectorInputIcon(.lucide("palette", fallbackSystemName: "paintpalette"))
        case "background":
            return InspectorInputIcon(.lucide("paint-bucket", fallbackSystemName: "paintbrush"))
        case "border":
            return InspectorInputIcon(.lucide("square", fallbackSystemName: "square"))
        case "box-shadow":
            return InspectorInputIcon(.lucide("sun", fallbackSystemName: "sun.min"))
        case "flex":
            return InspectorInputIcon(.lucide("stretch-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "transform-origin":
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
        case "gap":
            return normalizedLabel == "row"
                ? InspectorInputIcon(.lucide("move-vertical", fallbackSystemName: "arrow.up.and.down"))
                : InspectorInputIcon(.lucide("move-horizontal", fallbackSystemName: "arrow.left.and.right"))
        case "padding", "margin":
            return edgeIcon(for: normalizedLabel)
        case "border-radius":
            return cornerIcon(for: normalizedLabel)
        case "border":
            return InspectorInputIcon(.lucide("circle", fallbackSystemName: "circle"))
        case "background":
            return normalizedLabel == "angle"
                ? InspectorInputIcon(.lucide("rotate-cw", fallbackSystemName: "arrow.clockwise"))
                : colorValue
        case "box-shadow":
            return shadowIcon(for: normalizedLabel)
        case "flex":
            return flexIcon(for: normalizedLabel)
        case "transform-origin":
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
        case "w", "width":
            return InspectorInputIcon(.lucide("ruler", fallbackSystemName: "ruler"))
        case "h", "height":
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
