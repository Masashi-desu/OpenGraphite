import AppKit
import LucideIcons
import SwiftUI

/// 論理名（日本語）: OpenGraphiteアイコンライブラリ
/// 概要: Lucide や SF Symbols など、アプリ内アイコンの供給元を識別する値です。
///
/// プロパティ:
/// - `id`: アイコン供給元を表す安定 ID。
struct OpenGraphiteIconLibrary: Hashable, Sendable {
    var id: String

    /// 論理名（日本語）: OpenGraphiteアイコンライブラリ初期化関数
    /// 処理概要: 将来追加する SVG ライブラリも同じ ID 形式で扱える供給元値を作ります。
    ///
    /// - Parameter id: アイコン供給元を表す安定 ID。
    init(_ id: String) {
        self.id = id
    }

    static let systemSymbols = OpenGraphiteIconLibrary("system-symbols")
    static let lucide = OpenGraphiteIconLibrary("lucide")
    static let defaultLibrary = OpenGraphiteIconLibrary.lucide
    static let selectableLibraries: [OpenGraphiteIconLibrary] = [
        .lucide,
        .systemSymbols
    ]

    var title: String {
        switch self {
        case .lucide:
            return "Lucide"
        case .systemSymbols:
            return "SF Symbols"
        default:
            return id
        }
    }
}

/// 論理名（日本語）: OpenGraphiteアイコン記述子
/// 概要: UI が参照するアイコン名、供給元、fallback を一つにまとめる軽量モデルです。
///
/// プロパティ:
/// - `library`: アイコン供給元。
/// - `name`: 供給元内のアイコン名。
/// - `fallbackSystemName`: 供給元で解決できない場合に使う SF Symbols 名。
struct OpenGraphiteIcon: Hashable, Sendable {
    var library: OpenGraphiteIconLibrary
    var name: String
    var fallbackSystemName: String

    /// 論理名（日本語）: SF Symbolsアイコン生成関数
    /// 処理概要: 既存 UI と同じ SF Symbols 名を共通アイコン記述子へ変換します。
    ///
    /// - Parameter name: SF Symbols 名。
    /// - Returns: SF Symbols を供給元に持つアイコン記述子。
    static func system(_ name: String) -> OpenGraphiteIcon {
        OpenGraphiteIcon(
            library: .systemSymbols,
            name: name,
            fallbackSystemName: name
        )
    }

    /// 論理名（日本語）: Lucideアイコン生成関数
    /// 処理概要: Lucide の kebab-case ID と SF Symbols fallback を共通アイコン記述子へ変換します。
    ///
    /// - Parameters:
    ///   - name: Lucide の kebab-case アイコン ID。
    ///   - fallbackSystemName: Lucide が解決できない場合の SF Symbols 名。
    /// - Returns: Lucide を供給元に持つアイコン記述子。
    static func lucide(_ name: String, fallbackSystemName: String = "questionmark.circle") -> OpenGraphiteIcon {
        OpenGraphiteIcon(
            library: .lucide,
            name: name,
            fallbackSystemName: fallbackSystemName
        )
    }
}

/// 論理名（日本語）: OpenGraphiteアイコンビュー
/// 概要: アイコン記述子を SwiftUI のテンプレート画像として描画する共通ビューです。
///
/// プロパティ:
/// - `icon`: 描画するアイコン記述子。
/// - `size`: アイコンの表示サイズ。
/// - `weight`: SF Symbols fallback に適用する太さ。
struct OpenGraphiteIconView: View {
    var icon: OpenGraphiteIcon
    var size: CGFloat = 16
    var weight: Font.Weight = .medium

    var body: some View {
        renderedIcon
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var renderedIcon: some View {
        if icon.library == .lucide, let image = Self.lucideTemplateImage(named: icon.name) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size, weight: weight))
        }
    }

    private var fallbackSystemName: String {
        icon.library == .systemSymbols ? icon.name : icon.fallbackSystemName
    }

    /// 論理名（日本語）: Lucideテンプレート画像生成関数
    /// 処理概要: LucideIcons の asset から NSImage を読み込み、foregroundStyle に追従するテンプレート画像へ変換します。
    ///
    /// - Parameter name: Lucide の kebab-case アイコン ID。
    /// - Returns: テンプレート化した NSImage。見つからない場合は nil。
    private static func lucideTemplateImage(named name: String) -> NSImage? {
        guard let image = NSImage.image(lucideId: name)?.copy() as? NSImage else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}

/// 論理名（日本語）: OpenGraphiteアイコンライブラリ選択ビュー
/// 概要: Asset Panel などで Lucide と SF Symbols の供給元を選択するための小型 Picker です。
///
/// プロパティ:
/// - `selection`: 現在選択中のアイコン供給元。
struct OpenGraphiteIconLibraryPicker: View {
    @Binding var selection: OpenGraphiteIconLibrary

    var body: some View {
        Picker("Icon Library", selection: $selection) {
            ForEach(OpenGraphiteIconLibrary.selectableLibraries, id: \.self) { library in
                Text(library.title)
                    .tag(library)
            }
        }
        .pickerStyle(.segmented)
    }
}

extension OpenGraphiteIcon {
    static let sidebarLeft = OpenGraphiteIcon.lucide("panel-left", fallbackSystemName: "sidebar.left")
    static let sidebarRight = OpenGraphiteIcon.lucide("panel-right", fallbackSystemName: "sidebar.right")
    static let pagesPanel = OpenGraphiteIcon.lucide("file-stack", fallbackSystemName: "rectangle.stack")
    static let componentsPanel = OpenGraphiteIcon.lucide("component", fallbackSystemName: "shippingbox")
    static let chapterGroup = OpenGraphiteIcon.lucide("folder-code", fallbackSystemName: "folder")
    static let collectionGroup = OpenGraphiteIcon.lucide("blocks", fallbackSystemName: "square.grid.2x2")
    static let pageDocument = OpenGraphiteIcon.lucide("file-code", fallbackSystemName: "doc.text")
    static let componentDocument = OpenGraphiteIcon.lucide("component", fallbackSystemName: "shippingbox")
    static let componentInstance = OpenGraphiteIcon.lucide("copy", fallbackSystemName: "square.on.square")
    static let alignHorizontalStart = OpenGraphiteIcon.lucide("align-horizontal-justify-start", fallbackSystemName: "align.horizontal.left")
    static let alignHorizontalCenter = OpenGraphiteIcon.lucide("align-horizontal-justify-center", fallbackSystemName: "align.horizontal.center")
    static let alignHorizontalEnd = OpenGraphiteIcon.lucide("align-horizontal-justify-end", fallbackSystemName: "align.horizontal.right")
    static let alignVerticalStart = OpenGraphiteIcon.lucide("align-vertical-justify-start", fallbackSystemName: "align.vertical.top")
    static let alignVerticalCenter = OpenGraphiteIcon.lucide("align-vertical-justify-center", fallbackSystemName: "align.vertical.center")
    static let alignVerticalEnd = OpenGraphiteIcon.lucide("align-vertical-justify-end", fallbackSystemName: "align.vertical.bottom")

    /// 論理名（日本語）: キャンバスツールアイコン生成関数
    /// 処理概要: キャンバス操作ツールを Lucide 優先のアイコン記述子へ変換します。
    ///
    /// - Parameter tool: 対象のキャンバス操作ツール。
    /// - Returns: ツールを表すアイコン記述子。
    static func canvasTool(_ tool: CanvasTool) -> OpenGraphiteIcon {
        switch tool {
        case .select:
            return .lucide("mouse-pointer-2", fallbackSystemName: "cursorarrow")
        case .rectangle:
            return .lucide("square", fallbackSystemName: "rectangle")
        case .text:
            return .lucide("type", fallbackSystemName: "textformat")
        case .frame:
            return .lucide("frame", fallbackSystemName: "square.dashed")
        case .hand:
            return .lucide("hand", fallbackSystemName: "hand.raised")
        }
    }

    /// 論理名（日本語）: プレビュー表示モードアイコン生成関数
    /// 処理概要: プレビュー表示モードを Lucide 優先のアイコン記述子へ変換します。
    ///
    /// - Parameter mode: 対象のプレビュー表示モード。
    /// - Returns: 表示モードを表すアイコン記述子。
    static func previewDisplayMode(_ mode: OpenGraphitePreviewDisplayMode) -> OpenGraphiteIcon {
        switch mode {
        case .normal:
            return .lucide("eye", fallbackSystemName: "eye")
        case .flow:
            return .lucide("arrow-right", fallbackSystemName: "arrow.right")
        }
    }

    /// 論理名（日本語）: レイヤー種別アイコン生成関数
    /// 処理概要: HTML node の `data-og-type` を Lucide 優先のアイコン記述子へ変換します。
    ///
    /// - Parameter type: HTML node の `data-og-type`。
    /// - Returns: レイヤー種別を表すアイコン記述子。
    static func layerType(_ type: String) -> OpenGraphiteIcon {
        switch type {
        case "page":
            return .lucide("file-code", fallbackSystemName: "doc.text")
        case "frame":
            return .lucide("code", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
        case "text":
            return .lucide("type", fallbackSystemName: "textformat")
        case "button":
            return .lucide("square-mouse-pointer", fallbackSystemName: "button.programmable")
        case "image":
            return .lucide("image", fallbackSystemName: "photo")
        default:
            return .lucide("code-xml", fallbackSystemName: "curlybraces")
        }
    }

    /// 論理名（日本語）: レイヤーノードアイコン生成関数
    /// 処理概要: component master と component instance を優先し、それ以外は `data-og-type` からアイコンを決定します。
    ///
    /// - Parameter node: 左カラムの Layers に表示する OpenGraphite ノード。
    /// - Returns: ノードの意味を表すアイコン記述子。
    static func layerNode(_ node: OpenGraphiteNode) -> OpenGraphiteIcon {
        if node.componentKind == "master" {
            return .componentDocument
        }
        if node.tagName == "og-instance" || node.id == node.sourceInstanceID {
            return .componentInstance
        }
        return .layerType(node.type)
    }
}
