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
    static let sidebarObjects = OpenGraphiteIcon.lucide("layers-3", fallbackSystemName: "square.3.layers.3d")
    static let historyPanel = OpenGraphiteIcon.lucide("history", fallbackSystemName: "clock.arrow.circlepath")
    static let undoHistory = OpenGraphiteIcon.lucide("undo-2", fallbackSystemName: "arrow.uturn.backward")
    static let redoHistory = OpenGraphiteIcon.lucide("redo-2", fallbackSystemName: "arrow.uturn.forward")
    static let projectPanel = OpenGraphiteIcon.lucide("folder-tree", fallbackSystemName: "folder")
    static let pagesPanel = OpenGraphiteIcon.lucide("file-stack", fallbackSystemName: "rectangle.stack")
    static let componentsPanel = OpenGraphiteIcon.lucide("component", fallbackSystemName: "shippingbox")
    static let chapterGroup = OpenGraphiteIcon.lucide("folder-code", fallbackSystemName: "folder")
    static let addChapter = OpenGraphiteIcon.lucide("plus", fallbackSystemName: "plus")
    static let collectionGroup = OpenGraphiteIcon.lucide("blocks", fallbackSystemName: "square.grid.2x2")
    static let pageDocument = OpenGraphiteIcon.lucide("file-code", fallbackSystemName: "doc.text")
    static let addPage = OpenGraphiteIcon.lucide("file-plus", fallbackSystemName: "doc.badge.plus")
    static let addExistingPage = OpenGraphiteIcon.lucide("file-input", fallbackSystemName: "square.and.arrow.down")
    static let componentDocument = OpenGraphiteIcon.lucide("component", fallbackSystemName: "shippingbox")
    static let componentInstance = OpenGraphiteIcon.lucide("replace", fallbackSystemName: "arrow.triangle.2.circlepath")
    static let componentPlacement = OpenGraphiteIcon.lucide("copy", fallbackSystemName: "square.on.square")
    static let dependencyResource = OpenGraphiteIcon.lucide("git-branch", fallbackSystemName: "point.3.connected.trianglepath.dotted")
    static let designTokenResource = OpenGraphiteIcon.lucide("swatch-book", fallbackSystemName: "paintpalette")
    static let iconCDNResource = OpenGraphiteIcon.lucide("cloud", fallbackSystemName: "cloud")
    static let i18nResource = OpenGraphiteIcon.lucide("languages", fallbackSystemName: "character.book.closed")
    static let localeResource = OpenGraphiteIcon.lucide("braces", fallbackSystemName: "curlybraces")
    static let parameterLink = OpenGraphiteIcon.lucide("link", fallbackSystemName: "link")
    static let parameterUnlink = OpenGraphiteIcon.lucide("unlink", fallbackSystemName: "link.slash")
    static let alignHorizontalStart = OpenGraphiteIcon.lucide("align-horizontal-justify-start", fallbackSystemName: "align.horizontal.left")
    static let alignHorizontalCenter = OpenGraphiteIcon.lucide("align-horizontal-justify-center", fallbackSystemName: "align.horizontal.center")
    static let alignHorizontalEnd = OpenGraphiteIcon.lucide("align-horizontal-justify-end", fallbackSystemName: "align.horizontal.right")
    static let alignVerticalStart = OpenGraphiteIcon.lucide("align-vertical-justify-start", fallbackSystemName: "align.vertical.top")
    static let alignVerticalCenter = OpenGraphiteIcon.lucide("align-vertical-justify-center", fallbackSystemName: "align.vertical.center")
    static let alignVerticalEnd = OpenGraphiteIcon.lucide("align-vertical-justify-end", fallbackSystemName: "align.vertical.bottom")

    /// 論理名（日本語）: インスペクターセクションアイコン生成関数
    /// 処理概要: Inspector の折りたたみカード種別を Lucide 優先のアイコン記述子へ変換します。
    ///
    /// - Parameter sectionID: 対象の Inspector セクション ID。
    /// - Returns: セクションの意味を表すアイコン記述子。
    static func inspectorSection(_ sectionID: InspectorSectionID) -> OpenGraphiteIcon {
        switch sectionID {
        case .context:
            return .lucide("info", fallbackSystemName: "info.circle")
        case .component:
            return .componentDocument
        case .pages:
            return .pagesPanel
        case .alignment:
            return .alignHorizontalCenter
        case .layout:
            return .lucide("layout-template", fallbackSystemName: "rectangle.3.group")
        case .position:
            return .lucide("move", fallbackSystemName: "arrow.up.and.down.and.arrow.left.and.right")
        case .dimensions:
            return .lucide("ruler", fallbackSystemName: "ruler")
        case .appearance:
            return .lucide("palette", fallbackSystemName: "paintpalette")
        case .text:
            return .lucide("type", fallbackSystemName: "textformat")
        case .typography, .localeTypography:
            return .lucide("case-sensitive", fallbackSystemName: "textformat.size")
        case .media:
            return .lucide("image", fallbackSystemName: "photo")
        case .icon:
            return .lucide("star", fallbackSystemName: "star")
        case .effects:
            return .lucide("sparkles", fallbackSystemName: "sparkles")
        case .animation:
            return .lucide("play", fallbackSystemName: "play")
        case .scrollTimeline:
            return .lucide("timer", fallbackSystemName: "timer")
        case .htmlDocument:
            return .lucide("file-code", fallbackSystemName: "doc.text")
        case .i18nRuntime:
            return .i18nResource
        case .mockState:
            return .lucide("sliders-horizontal", fallbackSystemName: "slider.horizontal.3")
        case .canvas:
            return .lucide("frame", fallbackSystemName: "square.dashed")
        case .project:
            return .projectPanel
        case .projectMigration:
            return .lucide("file-diff", fallbackSystemName: "arrow.triangle.2.circlepath")
        case .designTokens:
            return .designTokenResource
        case .iconCDN:
            return .iconCDNResource
        case .localeResource:
            return .localeResource
        case .resourcePath:
            return .dependencyResource
        }
    }

    /// 論理名（日本語）: キャンバスツールアイコン生成関数
    /// 処理概要: キャンバス操作ツールを Lucide 優先のアイコン記述子へ変換します。
    ///
    /// - Parameter tool: 対象のキャンバス操作ツール。
    /// - Returns: ツールを表すアイコン記述子。
    static func canvasTool(_ tool: CanvasTool) -> OpenGraphiteIcon {
        switch tool {
        case .select:
            return .lucide("mouse-pointer-2", fallbackSystemName: "cursorarrow")
        case .text:
            return .lucide("type", fallbackSystemName: "textformat")
        case .frame:
            return .lucide("frame", fallbackSystemName: "square.dashed")
        case .icon:
            return .lucide("star", fallbackSystemName: "star")
        case .stickyNote:
            return .lucide("sticky-note", fallbackSystemName: "note.text")
        case .pen:
            return .lucide("pen-tool", fallbackSystemName: "pencil.tip")
        case .eraser:
            return .lucide("eraser", fallbackSystemName: "eraser")
        case .lasso:
            return .lucide("lasso-select", fallbackSystemName: "lasso")
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

    /// 論理名（日本語）: レイヤー表示ヒントアイコン生成関数
    /// 処理概要: DOM capabilityから導出済みの表示専用hintをLucide優先のアイコン記述子へ変換します。
    ///
    /// - Parameter hint: operation認可とは独立したノード表示hint。
    /// - Returns: レイヤー種別を表すアイコン記述子。
    static func layerPresentationHint(_ hint: OpenGraphiteNodePresentationHint) -> OpenGraphiteIcon {
        switch hint {
        case .page:
            return .lucide("file-code", fallbackSystemName: "doc.text")
        case .container:
            return .lucide("code", fallbackSystemName: "chevron.left.forwardslash.chevron.right")
        case .text:
            return .lucide("type", fallbackSystemName: "textformat")
        case .control:
            return .lucide("square-mouse-pointer", fallbackSystemName: "button.programmable")
        case .media:
            return .lucide("image", fallbackSystemName: "photo")
        case .icon:
            return .lucide("star", fallbackSystemName: "star")
        case .generic:
            return .lucide("code-xml", fallbackSystemName: "curlybraces")
        }
    }

    /// 論理名（日本語）: レイヤーノードアイコン生成関数
    /// 処理概要: component masterとcomponent instanceを優先し、それ以外はDOM capabilityから得た表示hintでアイコンを決定します。
    ///
    /// - Parameter node: 左カラムの Layers に表示する OpenGraphite ノード。
    /// - Returns: ノードの意味を表すアイコン記述子。
    static func layerNode(_ node: OpenGraphiteNode) -> OpenGraphiteIcon {
        if node.tagName == "og-placement" {
            return .componentPlacement
        }
        if node.isComponentMaster {
            return .componentDocument
        }
        if node.tagName == "og-instance" || node.id == node.sourceInstanceID {
            return .componentInstance
        }
        return .layerPresentationHint(node.presentationHint)
    }
}
