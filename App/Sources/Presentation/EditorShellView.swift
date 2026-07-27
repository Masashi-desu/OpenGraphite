import AppKit
import QuartzCore
import SwiftUI
import WebKit

/// 論理名（日本語）: エディター左カラム表示モード
/// 概要: 左カラムをオブジェクトナビゲーションまたは統合Undo / Redo履歴へ切り替えるモードを表します。
///
/// 定義内容:
/// - `objects`: Project / Pages / Components とそのオブジェクトを扱うナビゲーション表示。
/// - `history`: 操作時刻と対象プレビューを含む作業履歴表示。
enum EditorSidebarMode: String, CaseIterable, Identifiable {
    case objects
    case history

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .objects:
            return "オブジェクト"
        case .history:
            return "作業履歴"
        }
    }

    var help: String {
        switch self {
        case .objects:
            return "オブジェクトなどを表示"
        case .history:
            return "Undo / Redo 履歴を表示"
        }
    }

    var icon: OpenGraphiteIcon {
        switch self {
        case .objects:
            return .sidebarObjects
        case .history:
            return .historyPanel
        }
    }
}

/// 論理名（日本語）: エディターシェルビュー
/// 概要: 全面 Canvas の上に Sidebar と Inspector を重ねる編集画面のルートビューです。
struct EditorShellView: View {
    @SceneStorage("editorShell.isSidebarVisible") private var isSidebarVisible = true
    @SceneStorage("editorShell.isInspectorVisible") private var isInspectorVisible = true
    @SceneStorage("editorShell.sidebarMode.v2") private var selectedSidebarMode = EditorSidebarMode.objects.rawValue

    var body: some View {
        GeometryReader { geometry in
            let columnLayout = EditorShellColumnLayout(
                availableWidth: geometry.size.width,
                isSidebarVisible: isSidebarVisible,
                isInspectorVisible: isInspectorVisible
            )

            ZStack(alignment: .top) {
                CanvasPaneView(
                    isSidebarVisible: isSidebarVisible,
                    isInspectorVisible: isInspectorVisible,
                    sidebarWidth: columnLayout.sidebarWidth,
                    inspectorWidth: columnLayout.inspectorWidth
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                EditorCanvasSeparator(
                    sidebarWidth: columnLayout.visibleSidebarWidth,
                    inspectorWidth: columnLayout.visibleInspectorWidth
                )
                .padding(.top, EditorOverlayMetrics.topChromeHeight)
                .zIndex(5)

                if isSidebarVisible {
                    EditorOverlayColumn(
                        width: columnLayout.sidebarWidth,
                        edge: .leading
                    ) {
                        if resolvedSidebarMode == .history {
                            SidebarHistoryView()
                        } else {
                            SidebarView()
                        }
                    }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(10)
                }

                if isInspectorVisible {
                    EditorOverlayColumn(
                        width: columnLayout.inspectorWidth,
                        edge: .trailing
                    ) {
                        InspectorView()
                    }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(10)
                }

                EditorTopChromeView(
                    isSidebarVisible: isSidebarVisible,
                    isInspectorVisible: isInspectorVisible,
                    sidebarWidth: columnLayout.sidebarWidth,
                    inspectorWidth: columnLayout.inspectorWidth,
                    selectedSidebarMode: $selectedSidebarMode,
                    onToggleSidebar: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isSidebarVisible.toggle()
                        }
                    },
                    onToggleInspector: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isInspectorVisible.toggle()
                        }
                    }
                )
                .zIndex(30)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    private var resolvedSidebarMode: EditorSidebarMode {
        EditorSidebarMode(rawValue: selectedSidebarMode) ?? .objects
    }
}

/// 論理名（日本語）: エディターシェルカラムレイアウト
/// 概要: ウインドウ幅に応じた Sidebar / Inspector の実表示幅を解決します。
///
/// プロパティ:
/// - `sidebarWidth`: 左カラムの幅。
/// - `inspectorWidth`: 右 Inspector の幅。
private struct EditorShellColumnLayout {
    var sidebarWidth: CGFloat
    var inspectorWidth: CGFloat
    private var isSidebarVisible: Bool
    private var isInspectorVisible: Bool

    /// 論理名（日本語）: エディターシェルカラムレイアウト初期化関数
    /// 処理概要: 表示中の左カラム幅を考慮して Inspector の幅を決めます。
    ///
    /// - Parameters:
    ///   - availableWidth: 現在のウインドウ幅。
    ///   - isSidebarVisible: 左カラムが表示中か。
    ///   - isInspectorVisible: 右 Inspector が表示中か。
    init(availableWidth: CGFloat, isSidebarVisible: Bool, isInspectorVisible: Bool) {
        self.isSidebarVisible = isSidebarVisible
        self.isInspectorVisible = isInspectorVisible
        sidebarWidth = EditorOverlayMetrics.sidebarWidth
        let leadingWidth = isSidebarVisible ? sidebarWidth : 0
        inspectorWidth = isInspectorVisible
            ? InspectorLayoutMetrics.resolvedWidth(
                availableWindowWidth: availableWidth,
                leadingColumnWidth: leadingWidth
            )
            : 0
    }

    var visibleSidebarWidth: CGFloat {
        isSidebarVisible ? sidebarWidth : 0
    }

    var visibleInspectorWidth: CGFloat {
        isInspectorVisible ? inspectorWidth : 0
    }
}

/// 論理名（日本語）: エディターオーバーレイカラム
/// 概要: Sidebar/Inspector を指定幅の全高サーフェスとして Canvas 上に重ねます。
///
/// プロパティ:
/// - `width`: カラム幅。
/// - `edge`: カラムを寄せる画面端。
/// - `content`: カラム内部に表示するビュー。
private struct EditorOverlayColumn<Content: View>: View {
    var width: CGFloat
    var edge: HorizontalEdge
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            if edge == .trailing {
                Spacer(minLength: 0)
            }

            content
                .frame(width: width)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                .background(EditorColumnBackground())
                .overlay(alignment: dividerAlignment) {
                    Divider()
                }

            if edge == .leading {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dividerAlignment: Alignment {
        edge == .leading ? .trailing : .leading
    }
}

/// 論理名（日本語）: エディター上部クロームビュー
/// 概要: Pencil 風の薄い一段ヘッダーとして、左右カラム表示とプロジェクト情報を横一列に配置します。
///
/// プロパティ:
/// - `isSidebarVisible`: 左カラムが表示中か。
/// - `isInspectorVisible`: 右カラムが表示中か。
/// - `selectedSidebarMode`: 左カラムへ表示するオブジェクトナビゲーションまたは作業履歴。
/// - `onToggleSidebar`: 左カラム表示を切り替える処理。
/// - `onToggleInspector`: 右カラム表示を切り替える処理。
private struct EditorTopChromeView: View {
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool
    var sidebarWidth: CGFloat
    var inspectorWidth: CGFloat
    @Binding var selectedSidebarMode: EditorSidebarMode.RawValue
    var onToggleSidebar: () -> Void
    var onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                EditorChromeIconButton(
                    icon: .sidebarLeft,
                    isActive: isSidebarVisible,
                    help: isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                    action: onToggleSidebar
                )

                if isSidebarVisible {
                    EditorSidebarModeSwitcher(selection: $selectedSidebarMode)
                        .padding(.leading, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, EditorOverlayMetrics.trafficLightReservedWidth)
            .padding(.trailing, EditorOverlayMetrics.chromeControlInset)
            .frame(width: leadingChromeWidth, alignment: .leading)
            .clipped()

            HStack(spacing: 8) {
                EditorProjectSummaryView()
                    .layoutPriority(1)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                EditorChromeIconButton(
                    icon: .sidebarRight,
                    isActive: isInspectorVisible,
                    help: isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                    action: onToggleInspector
                )
            }
            .padding(.leading, EditorOverlayMetrics.chromeControlInset)
            .padding(.trailing, EditorOverlayMetrics.chromeControlInset)
            .frame(width: trailingChromeWidth, alignment: .trailing)
            .clipped()
        }
        .frame(height: EditorOverlayMetrics.topChromeHeight)
        .background {
            ZStack {
                EditorColumnBackground()
                WindowHeaderDragRegion()
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorColumnStyle.separatorColor)
                .frame(height: 1)
        }
    }

    private var leadingChromeWidth: CGFloat {
        isSidebarVisible ? sidebarWidth : EditorOverlayMetrics.collapsedLeadingChromeWidth
    }

    private var trailingChromeWidth: CGFloat {
        isInspectorVisible ? inspectorWidth : EditorOverlayMetrics.collapsedTrailingChromeWidth
    }
}

/// 論理名（日本語）: 左カラム表示モード切替ビュー
/// 概要: 左カラム表示時に生じる上部クロームの空き領域へ、オブジェクトと作業履歴のアイコンセグメントを並べます。
///
/// プロパティ:
/// - `selection`: 現在選択中の左カラム表示モード。
private struct EditorSidebarModeSwitcher: View {
    @Binding var selection: EditorSidebarMode.RawValue

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorSidebarMode.allCases) { mode in
                Button {
                    selection = mode.rawValue
                } label: {
                    OpenGraphiteIconView(icon: mode.icon, size: 13)
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection == mode.rawValue ? EditorColumnStyle.selectedRowFill : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode.rawValue ? .primary : .secondary)
                .help(mode.help)
                .accessibilityLabel(mode.accessibilityLabel)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(EditorColumnStyle.rowFill)
        )
    }
}

/// 論理名（日本語）: エディタークロームアイコンボタン
/// 概要: 上部クロームで使う薄型のアイコンボタンです。
///
/// プロパティ:
/// - `icon`: 表示するアイコン。
/// - `isActive`: 有効状態として背景を出すか。
/// - `help`: ヘルプとアクセシビリティラベル。
/// - `action`: 押下時に実行する処理。
private struct EditorChromeIconButton: View {
    var icon: OpenGraphiteIcon
    var isActive = false
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            OpenGraphiteIconView(icon: icon, size: 16)
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? .primary : .secondary)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(isActive ? EditorColumnStyle.selectedRowFill : Color.clear)
        )
        .help(help)
        .accessibilityLabel(help)
    }
}

/// 論理名（日本語）: エディタープロジェクト概要ビュー
/// 概要: 上部クローム内にプロジェクト名、参照ルート、選択ページを一行で表示します。
private struct EditorProjectSummaryView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        HStack(spacing: 8) {
            Text(store.loadedProject?.project.name ?? "OpenGraphite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let projectRootPath {
                PathBadge(title: "Project", path: projectRootPath)
            }

            if let publicRootPath {
                PathBadge(title: "Public", path: publicRootPath)
            }

            if let selectedProjectResource = store.selectedProjectResource {
                Text("Project")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(selectedProjectResource.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(store.selectedCanvasSegment.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let groupName = selectedGroupName {
                    Text(groupName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(store.selectedPage?.path ?? store.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var projectRootPath: String? {
        store.loadedProject?.rootURL.path
    }

    private var publicRootPath: String? {
        guard let loadedProject = store.loadedProject else { return nil }
        return loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .path
    }

    private var selectedGroupName: String? {
        switch store.selectedCanvasSegment {
        case .pages:
            return store.selectedChapter?.displayName
        case .components:
            return store.selectedComponentCollection?.displayName
        }
    }
}

/// 論理名（日本語）: エディターキャンバス区切り線ビュー
/// 概要: 上部クロームと Canvas の境界線を左右カラムへ重ねず、中央のプレビュー領域だけへ表示します。
///
/// プロパティ:
/// - `isSidebarVisible`: 左カラムが表示中か。
/// - `isInspectorVisible`: 右カラムが表示中か。
private struct EditorCanvasSeparator: View {
    var sidebarWidth: CGFloat
    var inspectorWidth: CGFloat

    var body: some View {
        Rectangle()
            .fill(EditorColumnStyle.separatorColor)
            .frame(height: 1)
            .padding(.leading, sidebarWidth)
            .padding(.trailing, inspectorWidth)
    }
}

/// 論理名（日本語）: パスバッジビュー
/// 概要: プロジェクトルートや public ルートをツールバー上で省略表示する小型ラベルです。
///
/// プロパティ:
/// - `title`: バッジの種別名。
/// - `path`: 表示するファイルシステムパス。
private struct PathBadge: View {
    var title: String
    var path: String
    @State private var isFullPathVisible = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .fontWeight(.semibold)
            Text(path)
                .truncationMode(.middle)
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: 180)
        .background(.quaternary, in: Capsule())
        .contentShape(Capsule())
        .overlay(alignment: .topLeading) {
            if isFullPathVisible {
                PathBadgeFullPathTip(title: title, path: path)
                    .offset(y: 28)
                    .zIndex(1)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { isHovering in
            isFullPathVisible = isHovering
        }
        .zIndex(isFullPathVisible ? 2 : 0)
        .animation(.easeOut(duration: 0.08), value: isFullPathVisible)
        .help(path)
    }
}

/// 論理名（日本語）: パスバッジフルパス表示
/// 概要: ヘッダー内の省略パスへ hover したとき、待ち時間なしで完全なファイルシステムパスを表示します。
///
/// プロパティ:
/// - `title`: パスの種別名。
/// - `path`: 表示する完全なファイルシステムパス。
private struct PathBadgeFullPathTip: View {
    var title: String
    var path: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(path)
                .foregroundStyle(.primary)
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

/// 論理名（日本語）: キャンバスペインビュー
/// 概要: HTML プレビュー、ツールパレット、ズーム HUD を重ねて表示する中央ペインです。
///
/// プロパティ:
/// - `isSidebarVisible`: 左カラムが表示中か。
/// - `isInspectorVisible`: 右カラムが表示中か。
private struct CanvasPaneView: View {
    @EnvironmentObject private var store: EditorStore
    @AppStorage(CanvasDisplayPreferences.showsRulersKey)
    private var showsRulers = CanvasDisplayPreferences.showsRulersByDefault
    @AppStorage(CanvasDisplayPreferences.showsGuidesKey)
    private var showsGuides = CanvasDisplayPreferences.showsGuidesByDefault
    @AppStorage(CanvasDisplayPreferences.showsGridKey)
    private var showsGrid = CanvasDisplayPreferences.showsGridByDefault
    @State private var canvasViewport = CanvasViewportState()
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool
    var sidebarWidth: CGFloat
    var inspectorWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let loadedProject = store.loadedProject,
               let focusedTarget = store.focusedPreviewTarget {
                CanvasFocusedObjectPreviewView(
                    store: store,
                    loadedProject: loadedProject,
                    target: focusedTarget
                )
                .padding(.leading, overlayAvoidance.leading)
                .padding(.trailing, overlayAvoidance.trailing)
                .padding(.top, overlayAvoidance.top + CanvasFocusedPreviewMetrics.modePickerClearance)
            } else if let loadedProject = store.loadedProject, hasSelectedCanvasContainer {
                let contentOrigin = canvasContentOrigin(
                    for: store.selectedCanvasPages,
                    annotations: store.selectedCanvasAnnotations,
                    references: store.selectedCanvasReferences
                )

                if showsGrid {
                    CanvasGridOverlay(
                        viewport: canvasViewport,
                        canvasOrigin: contentOrigin,
                        zoom: store.zoom,
                        overlayAvoidance: overlayAvoidance,
                        showsRulers: showsRulers
                    )
                }

                ZoomableCanvasScrollView(
                    zoom: $store.zoom,
                    viewport: $canvasViewport,
                    documentID: canvasDocumentID(for: loadedProject, segment: store.selectedCanvasSegment, pages: store.selectedCanvasPages),
                    contentRevisionID: canvasContentRevisionID(
                        for: loadedProject,
                        segment: store.selectedCanvasSegment,
                        pages: store.selectedCanvasPages,
                        annotations: store.selectedCanvasAnnotations,
                        references: store.selectedCanvasReferences
                    ),
                    contentCanvasOrigin: contentOrigin,
                    overlayAvoidance: overlayAvoidance,
                    onEmptyCanvasClick: {
                        store.clearCanvasSelection()
                    }
                ) {
                    canvasContent(for: loadedProject)
                }

                CanvasRulerGuideOverlay(
                    viewport: canvasViewport,
                    canvasOrigin: contentOrigin,
                    zoom: store.zoom,
                    overlayAvoidance: overlayAvoidance,
                    showsRulers: showsRulers,
                    showsGuides: showsGuides,
                    guides: store.selectedCanvasGuides,
                    onAddGuide: { orientation, position in
                        store.addCanvasGuide(orientation: orientation, position: position)
                    },
                    onUpdateGuide: { id, position in
                        store.updateCanvasGuide(id: id, position: position)
                    },
                    onDeleteGuide: { id in
                        store.deleteCanvasGuide(id: id)
                    }
                )

                CanvasToolPalette(activeTool: $store.activeTool)
                    .padding(.leading, overlayAvoidance.leading + rulerContentInset + 14)
                    .padding(.top, overlayAvoidance.top + rulerContentInset + 14)
                    .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.leading)
                    .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.top)
            } else {
                ContentUnavailableView(
                    store.selectedCanvasSegment == .components ? "No Components" : "No Page",
                    systemImage: store.selectedCanvasSegment == .components ? "shippingbox" : "doc",
                    description: Text(store.selectedCanvasSegment == .components ? "component を持つ Collection を選択してください。" : "pages を持つ Chapter を選択してください。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CanvasPreviewModePicker(mode: $store.previewDisplayMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, overlayAvoidance.trailing + 14)
                .padding(.top, overlayAvoidance.top + rulerContentInset + 14)
                .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.trailing)
                .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.top)

            if store.loadedProject != nil,
               store.focusedPreviewTarget != nil || hasSelectedCanvasContainer {
                CanvasZoomHUD(
                    zoom: store.zoom,
                    canZoomOut: store.zoom > CanvasZoom.range.lowerBound,
                    canZoomIn: store.zoom < CanvasZoom.range.upperBound,
                    onZoomOut: {
                        adjustZoom(by: -CanvasZoom.buttonStep)
                    },
                    onZoomIn: {
                        adjustZoom(by: CanvasZoom.buttonStep)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, overlayAvoidance.trailing + 16)
                .padding(.bottom, 14)
                .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.trailing)
            }
        }
    }

    private var overlayAvoidance: CanvasOverlayAvoidance {
        CanvasOverlayAvoidance(
            leading: isSidebarVisible ? sidebarWidth : 0,
            trailing: isInspectorVisible ? inspectorWidth : 0,
            top: EditorOverlayMetrics.topChromeHeight
        )
    }

    private var hasSelectedCanvasContainer: Bool {
        switch store.selectedCanvasSegment {
        case .pages:
            return store.selectedChapter != nil
        case .components:
            return store.selectedComponentCollection != nil
        }
    }

    private var rulerContentInset: CGFloat {
        guard showsRulers,
              store.focusedPreviewTarget == nil,
              store.loadedProject != nil,
              hasSelectedCanvasContainer
        else {
            return 0
        }
        return CanvasAidLayout.rulerThickness
    }

    /// 論理名（日本語）: キャンバス表示内容生成関数
    /// 処理概要: Normal / Flow のキャンバス全体を、現在の配置とズーム倍率で表示します。
    ///
    /// - Parameter project: 表示中の読み込み済みプロジェクト。
    /// - Returns: 現在のプレビュモードに対応するキャンバス内容。
    private func canvasContent(for project: LoadedOpenGraphiteProject) -> some View {
        CanvasProjectView(
            store: store,
            loadedProject: project,
            pages: store.selectedCanvasPages,
            zoom: store.zoom
        )
    }

    /// 論理名（日本語）: キャンバスドキュメントID生成関数
    /// 処理概要: 選択セグメントのページ構成が変わったときだけスクロール document を作り直す識別子を生成します。
    ///
    /// - Parameters:
    ///   - project: 表示中の読み込み済みプロジェクト。
    ///   - segment: 表示中の Pages / Components セグメント。
    ///   - pages: 表示対象ページ一覧。
    /// - Returns: キャンバス構成を表す安定 ID。
    private func canvasDocumentID(for project: LoadedOpenGraphiteProject, segment: OpenGraphiteCanvasSegment, pages: [OpenGraphitePage]) -> String {
        CanvasDocumentIdentityResolver.viewportID(
            projectPath: project.fileURL.path,
            segment: segment,
            pages: pages
        )
    }

    /// 論理名（日本語）: キャンバス内容Revision ID生成関数
    /// 処理概要: page 配置や preview context の変更時に、表示領域を維持したまま SwiftUI content を更新する識別子を生成します。
    ///
    /// - Parameters:
    ///   - project: 表示中の読み込み済みプロジェクト。
    ///   - segment: 表示中の Pages / Components セグメント。
    ///   - pages: 表示対象ページ一覧。
    /// - Returns: キャンバス内容を表す revision ID。
    private func canvasContentRevisionID(
        for project: LoadedOpenGraphiteProject,
        segment: OpenGraphiteCanvasSegment,
        pages: [OpenGraphitePage],
        annotations: [OpenGraphiteCanvasAnnotation],
        references: [OpenGraphiteCanvasReference]
    ) -> String {
        CanvasDocumentIdentityResolver.contentRevisionID(
            projectPath: project.fileURL.path,
            segment: segment,
            pages: pages,
            annotations: annotations,
            references: references
        )
    }

    /// 論理名（日本語）: キャンバス内容原点取得関数
    /// 処理概要: page 配置を document 座標へ写すときに使う canvas bounds 原点を取得します。
    ///
    /// - Parameter pages: 表示対象ページ一覧。
    /// - Returns: 現在の canvas content 原点。
    private func canvasContentOrigin(
        for pages: [OpenGraphitePage],
        annotations: [OpenGraphiteCanvasAnnotation],
        references: [OpenGraphiteCanvasReference]
    ) -> CGPoint {
        return CanvasProjectBounds(
            pages: pages,
            annotations: annotations,
            references: references,
            interactionMargin: CanvasMetrics.annotationInteractionMargin
        ).origin
    }

    /// 論理名（日本語）: ズーム調整関数
    /// 処理概要: HUD ボタン操作に応じてズーム倍率を許容範囲内で増減します。
    ///
    /// - Parameter delta: 追加するズーム倍率差分。
    private func adjustZoom(by delta: Double) {
        withAnimation(.easeOut(duration: 0.12)) {
            store.zoom = CanvasZoom.stepped(store.zoom, by: delta)
        }
    }

}

/// 論理名（日本語）: キャンバスドキュメント識別子解決器
/// 概要: スクロール位置の初期化に使う ID と、表示内容の再描画に使う revision ID を分けて生成します。
///
/// 定義内容:
/// - `viewportID(projectPath:segment:pages:)`: page 構成変更だけで変わる表示領域用 ID を生成します。
/// - `contentRevisionID(projectPath:segment:pages:annotations:references:)`: page、注釈、参照 viewport の表示変更で変わる描画更新用 ID を生成します。
enum CanvasDocumentIdentityResolver {
    /// 論理名（日本語）: 表示領域ID生成関数
    /// 処理概要: page の canvas 座標やサイズを含めず、表示領域を初期化すべき構成変更だけを ID 化します。
    ///
    /// - Parameters:
    ///   - projectPath: `.ogp` project path。
    ///   - segment: 表示中の Pages / Components セグメント。
    ///   - pages: 表示対象 page 一覧。
    /// - Returns: スクロール document を切り替えるための安定 ID。
    static func viewportID(projectPath: String, segment: OpenGraphiteCanvasSegment, pages: [OpenGraphitePage]) -> String {
        "\(projectPath)#\(segment.rawValue)#\(pageIdentitySignature(for: pages))"
    }

    /// 論理名（日本語）: 内容Revision ID生成関数
    /// 処理概要: 表示領域の初期化は避けつつ、page、注釈、参照 viewport の描画変更を伝える ID を生成します。
    ///
    /// - Parameters:
    ///   - projectPath: `.ogp` project path。
    ///   - segment: 表示中の Pages / Components セグメント。
    ///   - pages: 表示対象 page 一覧。
    ///   - annotations: 表示対象の `.ogp` 注釈一覧。
    ///   - references: 表示対象の Canvas Object Reference 一覧。
    /// - Returns: SwiftUI content の再適用要否を判定する revision ID。
    static func contentRevisionID(
        projectPath: String,
        segment: OpenGraphiteCanvasSegment,
        pages: [OpenGraphitePage],
        annotations: [OpenGraphiteCanvasAnnotation] = [],
        references: [OpenGraphiteCanvasReference] = []
    ) -> String {
        let pageRevision = pages
            .map { page in
                [
                    pageIdentity(for: page),
                    page.id,
                    page.canvas.name,
                    String(page.canvas.x),
                    String(page.canvas.y),
                    String(page.canvas.width),
                    String(page.canvas.height),
                    previewContextSignature(for: page.canvas.previewContext)
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        let annotationRevision = annotations.map(annotationSignature(for:)).joined(separator: "|")
        let referenceRevision = references.map { reference in
            [
                reference.internalID,
                reference.referenceID,
                String(reference.x),
                String(reference.y),
                String(reference.width),
                String(reference.height)
            ].joined(separator: ":")
        }.joined(separator: "|")
        return "\(viewportID(projectPath: projectPath, segment: segment, pages: pages))#revision#\(pageRevision)#annotations#\(annotationRevision)#references#\(referenceRevision)"
    }

    /// 論理名（日本語）: Page Identity Signature生成関数
    /// 処理概要: 表示対象 page の順序と参照先を表す、canvas geometry を含まない署名を生成します。
    ///
    /// - Parameter pages: 表示対象 page 一覧。
    /// - Returns: page 構成署名。
    private static func pageIdentitySignature(for pages: [OpenGraphitePage]) -> String {
        pages.map(pageIdentity(for:)).joined(separator: "|")
    }

    /// 論理名（日本語）: Page Identity生成関数
    /// 処理概要: `.ogp` 内の page を識別するため、内部 ID と HTML path をまとめます。
    ///
    /// - Parameter page: 署名対象 page。
    /// - Returns: page identity。
    private static func pageIdentity(for page: OpenGraphitePage) -> String {
        "\(page.internalID):\(page.path)"
    }

    /// 論理名（日本語）: Preview Context Signature生成関数
    /// 処理概要: Dictionary の順序に依存せず preview context の変更を revision ID へ反映します。
    ///
    /// - Parameter previewContext: 署名対象の preview context。
    /// - Returns: preview context の安定署名。
    private static func previewContextSignature(for previewContext: OpenGraphitePreviewContext) -> String {
        let fields = sortedPairs(previewContext.fieldMocks)
        let placements = previewContext.placementMocks
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=[\(sortedPairs($0.value))]" }
            .joined(separator: ",")
        return [
            previewContext.locale,
            previewContext.direction,
            fields,
            placements
        ].joined(separator: ":")
    }

    /// 論理名（日本語）: ソート済みDictionary署名生成関数
    /// 処理概要: 文字列 dictionary を key 順に直列化し、revision ID の揺れを防ぎます。
    ///
    /// - Parameter values: 署名対象 dictionary。
    /// - Returns: key 順に並べた `key=value` 署名。
    private static func sortedPairs(_ values: [String: String]) -> String {
        values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
    }

    /// 論理名（日本語）: キャンバス注釈配置署名生成関数
    /// 処理概要: document size と原点へ影響する注釈 identity・種別・frame だけを Canvas content revision へ反映します。
    ///
    /// - Parameter annotation: 署名対象注釈。
    /// - Returns: stroke 点列や付箋本文を展開しない、順序を維持した軽量配置署名。
    private static func annotationSignature(for annotation: OpenGraphiteCanvasAnnotation) -> String {
        return [
            annotation.internalID,
            annotation.kind.rawValue,
            "\(annotation.frame.x),\(annotation.frame.y),\(annotation.frame.width),\(annotation.frame.height)"
        ].joined(separator: ":")
    }
}

/// 論理名（日本語）: 静的フロー表示座標解決器
/// 概要: page 最小座標を原点とする静的フロー接続を、注釈用余白を含む CanvasProjectBounds の表示座標へ揃えます。
enum CanvasStaticFlowCoordinateResolver {
    /// 論理名（日本語）: 静的フロー表示オフセット関数
    /// 処理概要: flow resolver の page 原点と、実際の Canvas bounds 原点およびページ名カード分の差を返します。
    ///
    /// - Parameters:
    ///   - pages: flow resolver が座標計算に使った page 一覧。
    ///   - bounds: page / annotation / interaction margin を含む表示境界。
    ///   - visualYOffset: ページ名カードによる Y 表示オフセット。
    /// - Returns: flow 接続点へ加える表示座標差。
    static func visualOffset(
        pages: [OpenGraphitePage],
        bounds: CanvasProjectBounds,
        visualYOffset: CGFloat
    ) -> CGSize {
        let flowOriginX = pages.map { CGFloat($0.canvas.x) }.min() ?? 0
        let flowOriginY = pages.map { CGFloat($0.canvas.y) }.min() ?? 0
        return CGSize(
            width: flowOriginX - bounds.minX,
            height: flowOriginY - bounds.minY + visualYOffset
        )
    }

    /// 論理名（日本語）: 静的フロー接続表示変換関数
    /// 処理概要: source / target 接続点を Canvas 上の page card と同じ表示原点へ移します。
    ///
    /// - Parameters:
    ///   - connection: page 最小座標基準の静的フロー接続。
    ///   - pages: flow resolver が座標計算に使った page 一覧。
    ///   - bounds: 現在の Canvas 表示境界。
    ///   - visualYOffset: ページ名カードによる Y 表示オフセット。
    /// - Returns: Canvas 表示座標へ変換した接続。
    static func visualConnection(
        _ connection: OpenGraphiteStaticFlowConnection,
        pages: [OpenGraphitePage],
        bounds: CanvasProjectBounds,
        visualYOffset: CGFloat
    ) -> OpenGraphiteStaticFlowConnection {
        let offset = visualOffset(pages: pages, bounds: bounds, visualYOffset: visualYOffset)
        var adjusted = connection
        adjusted.sourcePoint.x += offset.width
        adjusted.sourcePoint.y += offset.height
        adjusted.targetPoint.x += offset.width
        adjusted.targetPoint.y += offset.height
        return adjusted
    }
}

/// 論理名（日本語）: キャンバスプロジェクト重なり順
/// 概要: HTML card と参照 viewport の選択・変形優先度を保ちつつ、`.ogp` 注釈レイヤーを常に前面へ配置します。
enum CanvasProjectLayerOrder {
    static let annotation = 3.0
    static let reference = 1.5
    static let selectedReference = 2.5

    /// 論理名（日本語）: HTMLカード重なり順解決関数
    /// 処理概要: 通常、選択中、ドラッグまたはリサイズ中の順で card の重なり優先度を返します。
    ///
    /// - Parameters:
    ///   - isSelected: HTML card が選択中か。
    ///   - isBeingTransformed: HTML card がドラッグまたはリサイズ中か。
    /// - Returns: 注釈レイヤーより低い card 用 z-index。
    static func page(isSelected: Bool, isBeingTransformed: Bool) -> Double {
        if isBeingTransformed {
            return 2
        }
        return isSelected ? 1 : 0
    }
}

/// 論理名（日本語）: Focusプレビュ切り抜き矩形解決器
/// 概要: 右クリック時に実測した object の document 座標矩形を、元page viewport内の安全な切り抜き矩形に変換します。
///
/// 定義内容:
/// - `cropRect(pageSize:targetRect:)`: Focus表示するpage座標矩形を返す。
enum CanvasFocusCropResolver {
    /// 論理名（日本語）: Focus切り抜き矩形生成関数
    /// 処理概要: object実測矩形を検証し、page viewportからはみ出す部分だけを切り落とします。
    ///
    /// - Parameters:
    ///   - pageSize: 元のWebView viewport寸法。
    ///   - targetRect: 右クリックした object の page document 座標矩形。
    /// - Returns: Focus表示用のpage座標矩形。無効値の場合は `nil`。
    static func cropRect(
        pageSize: CGSize,
        targetRect: CGRect
    ) -> CGRect? {
        guard pageSize.width.isFinite,
              pageSize.height.isFinite,
              pageSize.width > 0,
              pageSize.height > 0,
              targetRect.minX.isFinite,
              targetRect.minY.isFinite,
              targetRect.width.isFinite,
              targetRect.height.isFinite,
              targetRect.width > 0,
              targetRect.height > 0
        else {
            return nil
        }

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let visibleRect = targetRect.intersection(pageRect)
        guard !visibleRect.isNull,
              visibleRect.width.isFinite,
              visibleRect.height.isFinite,
              visibleRect.width > 0,
              visibleRect.height > 0
        else {
            return nil
        }
        return visibleRect
    }
}

/// 論理名（日本語）: フォーカス有限プレビューレイアウト
/// 概要: Zoom適用後のobjectを中央配置する有限document寸法と、中央から表示する初期scroll位置を保持します。
///
/// プロパティ:
/// - `documentSize`: viewportとobjectを収める有限document寸法。
/// - `contentFrame`: document内で中央配置したobject frame。
/// - `initialScrollOrigin`: object中心をviewport中心に合わせる初期scroll原点。
/// - `scrollRange`: 各軸で必要な最大scroll距離。
struct CanvasFocusedPreviewLayout: Equatable {
    var documentSize: CGSize
    var contentFrame: CGRect
    var initialScrollOrigin: CGPoint
    var scrollRange: CGSize
}

/// 論理名（日本語）: フォーカス有限プレビューレイアウト解決器
/// 概要: 指定倍率へ拡大縮小済みのobjectを中央へ置き、overflow分だけscroll可能な有限documentを計算します。
enum CanvasFocusedPreviewLayoutResolver {
    /// 論理名（日本語）: フォーカス有限レイアウト生成関数
    /// 処理概要: 小さいobjectはscrollなしで中央配置し、大きいobjectは中央から必要量だけscrollできる値を返します。
    ///
    /// - Parameters:
    ///   - viewportSize: フォーカスプレビューの表示領域寸法。
    ///   - contentSize: Zoom適用後に表示するobject寸法。
    ///   - retainedDocumentSize: Zoom連続入力中に縮小を遅延するdocument寸法。省略時は必要寸法へ即時収束する。
    /// - Returns: 有効寸法の有限レイアウト。不正値では `nil`。
    static func layout(
        viewportSize: CGSize,
        contentSize: CGSize,
        retainedDocumentSize: CGSize? = nil
    ) -> CanvasFocusedPreviewLayout? {
        guard viewportSize.width.isFinite,
              viewportSize.height.isFinite,
              contentSize.width.isFinite,
              contentSize.height.isFinite,
              viewportSize.width > 0,
              viewportSize.height > 0,
              contentSize.width > 0,
              contentSize.height > 0
        else {
            return nil
        }

        let retainedWidth = retainedDocumentSize?.width ?? 0
        let retainedHeight = retainedDocumentSize?.height ?? 0
        let documentSize = CGSize(
            width: max(max(viewportSize.width, contentSize.width), retainedWidth),
            height: max(max(viewportSize.height, contentSize.height), retainedHeight)
        )
        let contentOrigin = CGPoint(
            x: (documentSize.width - contentSize.width) / 2,
            y: (documentSize.height - contentSize.height) / 2
        )
        let scrollRange = CGSize(
            width: max(documentSize.width - viewportSize.width, 0),
            height: max(documentSize.height - viewportSize.height, 0)
        )
        return CanvasFocusedPreviewLayout(
            documentSize: documentSize,
            contentFrame: CGRect(origin: contentOrigin, size: contentSize),
            initialScrollOrigin: CGPoint(x: scrollRange.width / 2, y: scrollRange.height / 2),
            scrollRange: scrollRange
        )
    }
}

/// 論理名（日本語）: フォーカスプレビュー倍率解決器
/// 概要: Focus対象の原寸矩形へcanvas Zoomを適用し、有限レイアウトへ渡す表示寸法を計算します。
enum CanvasFocusedPreviewScaleResolver {
    /// 論理名（日本語）: フォーカス表示寸法生成関数
    /// 処理概要: 100%を原寸として、対象の幅と高さへ同一Zoom倍率を適用します。
    ///
    /// - Parameters:
    ///   - originalSize: Focus対象の原寸寸法。
    ///   - zoom: `1.0`を100%とするcanvas Zoom倍率。
    /// - Returns: 倍率適用後の有限な正の寸法。不正値では `nil`。
    static func scaledSize(originalSize: CGSize, zoom: Double) -> CGSize? {
        guard originalSize.width.isFinite,
              originalSize.height.isFinite,
              originalSize.width > 0,
              originalSize.height > 0,
              zoom.isFinite,
              zoom > 0
        else {
            return nil
        }

        let scaledSize = CGSize(
            width: originalSize.width * CGFloat(zoom),
            height: originalSize.height * CGFloat(zoom)
        )
        guard scaledSize.width.isFinite,
              scaledSize.height.isFinite,
              scaledSize.width > 0,
              scaledSize.height > 0
        else {
            return nil
        }
        return scaledSize
    }
}

/// 論理名（日本語）: フォーカスプレビュー表示メトリクス
/// 概要: Normal / Flow pickerと専用表示領域が重ならないための固定UI寸法を定義します。
private enum CanvasFocusedPreviewMetrics {
    static let modePickerClearance: CGFloat = 58
    static let zoomSettleDelay: TimeInterval = 0.12
}

/// 論理名（日本語）: フォーカス対象プレビュー
/// 概要: 右クリックで固定したobjectまたはpage全体を、通常キャンバスから独立したZoom可能な有限表示領域へ描画します。
private struct CanvasFocusedObjectPreviewView: View {
    @ObservedObject var store: EditorStore
    var loadedProject: LoadedOpenGraphiteProject
    var target: OpenGraphiteFocusedPreviewTarget

    var body: some View {
        let zoom = CanvasZoom.clamped(store.zoom)
        if let page = focusedPage,
           let cropRect = CanvasFocusCropResolver.cropRect(
               pageSize: CGSize(width: CGFloat(page.canvas.width), height: CGFloat(page.canvas.height)),
               targetRect: target.rect
           ),
           let scaledContentSize = CanvasFocusedPreviewScaleResolver.scaledSize(
               originalSize: cropRect.size,
               zoom: zoom
           ) {
            CanvasFocusedPreviewScrollView(
                zoom: $store.zoom,
                documentID: target.id,
                contentSize: scaledContentSize
            ) {
                CanvasFocusedObjectDocumentView(
                    store: store,
                    page: page,
                    pageURL: loadedProject.htmlURL(for: page),
                    cropRect: cropRect,
                    target: target
                )
                .scaleEffect(CGFloat(zoom), anchor: .topLeading)
                .frame(
                    width: scaledContentSize.width,
                    height: scaledContentSize.height,
                    alignment: .topLeading
                )
            }
        } else {
            ContentUnavailableView(
                "Focus Unavailable",
                systemImage: "viewfinder",
                description: Text("フォーカス対象のpageまたは表示サイズを解決できません。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                Button("フォーカス表示を解除") {
                    store.endFocusedPreview()
                }
            }
        }
    }

    private var focusedPage: OpenGraphitePage? {
        switch target.segment {
        case .pages:
            return loadedProject.project.chapters
                .flatMap(\.pages)
                .first { $0.internalID == target.pageInternalID }
        case .components:
            return loadedProject.project.collections
                .flatMap(\.components)
                .first { $0.internalID == target.pageInternalID }
        }
    }
}

/// 論理名（日本語）: フォーカス対象文書ビュー
/// 概要: 元page viewportのCSS文脈と原寸矩形を保ち、外側のcanvas Zoomで拡大縮小できるcontentを表示します。
private struct CanvasFocusedObjectDocumentView: View {
    @ObservedObject var store: EditorStore
    var page: OpenGraphitePage
    var pageURL: URL
    var cropRect: CGRect
    var target: OpenGraphiteFocusedPreviewTarget

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(nsColor: .textBackgroundColor))

            WebCanvasView(
                store: store,
                pageURL: pageURL,
                pageInternalID: page.internalID,
                syncTarget: store.htmlSyncTarget(for: page, segment: target.segment),
                isInteractive: false,
                reloadToken: store.reloadToken(for: pageURL),
                previewContext: page.canvas.previewContext,
                allowsComponentPlacements: target.segment == .components,
                focusedNodeIDs: target.nodeID.map { [$0] } ?? []
            )
            .frame(width: CGFloat(page.canvas.width), height: CGFloat(page.canvas.height))
            .offset(x: -cropRect.minX, y: -cropRect.minY)
            .allowsHitTesting(false)
        }
        .frame(width: cropRect.width, height: cropRect.height, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .contextMenu {
            Button("フォーカス表示を解除") {
                store.endFocusedPreview()
            }
        }
        .accessibilityLabel("フォーカス表示 \(target.nodeID ?? page.id)")
    }
}

/// 論理名（日本語）: キャンバスプロジェクトビュー
/// 概要: 選択 Chapter のページを canvas 座標に従って一つのスクロール可能な面へ配置します。
///
/// プロパティ:
/// - `store`: エディター状態ストア。
/// - `loadedProject`: 表示対象プロジェクト。
/// - `pages`: 表示対象 Chapter のページ一覧。
/// - `zoom`: 現在の表示倍率。
private struct CanvasProjectView: View {
    @ObservedObject var store: EditorStore
    var loadedProject: LoadedOpenGraphiteProject
    var pages: [OpenGraphitePage]
    var zoom: Double
    @State private var hoveredFlowTargetPageInternalID: String?

    var body: some View {
        let annotations = store.selectedCanvasAnnotations
        let references = store.selectedCanvasReferences
        let bounds = CanvasProjectBounds(
            pages: pages,
            annotations: annotations,
            references: references,
            interactionMargin: CanvasMetrics.annotationInteractionMargin
        )
        let scale = CGFloat(zoom)
        let visualHeight = bounds.height + CanvasMetrics.pageNameCardOutsideOffset
        let isFlowHoverEnabled = store.previewDisplayMode == .flow && store.selectedCanvasSegment == .pages
        let flowConnections = isFlowHoverEnabled
            ? OpenGraphiteStaticFlowResolver.connections(
                pages: pages,
                loadedProject: loadedProject,
                linksByPageInternalID: store.staticFlowLinksByPageInternalID,
                linksByPageURL: store.staticFlowLinksByPageURL
            ).map { connection in
                CanvasStaticFlowCoordinateResolver.visualConnection(
                    connection,
                    pages: pages,
                    bounds: bounds,
                    visualYOffset: CanvasMetrics.pageNameCardOutsideOffset
                )
            }
            : []

        ZStack(alignment: .topLeading) {
            CanvasBackgroundContextMenuView(
                store: store,
                canvasOrigin: bounds.origin,
                onPrimaryClick: {
                    store.clearCanvasSelection()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ForEach(pages, id: \.internalID) { page in
                CanvasDocumentView(
                    store: store,
                    page: page,
                    pageURL: loadedProject.htmlURL(for: page),
                    isSelected: store.selectedCanvasReferenceID == nil
                        && page.internalID == store.selectedPage?.internalID,
                    zoom: zoom,
                    reloadToken: store.reloadToken(for: loadedProject.htmlURL(for: page)),
                    isFlowHoverEnabled: isFlowHoverEnabled,
                    onFlowTargetPageHover: handleFlowTargetPageHover
                )
                .offset(
                    x: CGFloat(page.canvas.x) - bounds.minX,
                    y: CGFloat(page.canvas.y) - bounds.minY
                )
            }

            ForEach(references, id: \.internalID) { reference in
                if let target = try? store.resolveCanvasReferenceID(reference.referenceID) {
                    CanvasReferenceObjectView(
                        store: store,
                        reference: reference,
                        target: target,
                        zoom: zoom
                    )
                    .offset(
                        x: CGFloat(reference.x) - bounds.minX,
                        y: CGFloat(reference.y) - bounds.minY
                    )
                    .zIndex(
                        store.selectedCanvasReferenceID == reference.internalID
                            ? CanvasProjectLayerOrder.selectedReference
                            : CanvasProjectLayerOrder.reference
                    )
                } else {
                    CanvasBrokenReferenceView(
                        store: store,
                        reference: reference
                    )
                    .offset(
                        x: CGFloat(reference.x) - bounds.minX,
                        y: CGFloat(reference.y) - bounds.minY
                    )
                    .zIndex(CanvasProjectLayerOrder.reference)
                }
            }

            if store.previewDisplayMode == .flow, store.selectedCanvasSegment == .pages {
                let hasDirectPageSelection = store.selectedCanvasReferenceID == nil
                CanvasStaticFlowOverlay(
                    connections: flowConnections,
                    hoveredSource: store.hoveredStaticFlowSource,
                    hoveredTargetPageInternalID: hoveredFlowTargetPageInternalID,
                    selectedSourcePageURL: hasDirectPageSelection ? store.selectedPageURL?.standardizedFileURL : nil,
                    selectedSourcePageInternalID: hasDirectPageSelection ? store.selectedPage?.internalID : nil,
                    selectedSourceNodeID: hasDirectPageSelection ? store.selectedNodeID : nil,
                    selectedTargetPageInternalID: hasDirectPageSelection && store.selectedNodeID == nil ? store.selectedPage?.internalID : nil
                )
                .allowsHitTesting(false)
            }

            CanvasAnnotationLayerView(
                store: store,
                bounds: bounds,
                visualYOffset: CanvasMetrics.pageNameCardOutsideOffset,
                zoom: zoom
            )
            .zIndex(CanvasProjectLayerOrder.annotation)

        }
        .frame(width: bounds.width, height: visualHeight, alignment: .topLeading)
        .coordinateSpace(name: CanvasMetrics.projectCoordinateSpaceName)
        .onContinuousHover(coordinateSpace: .named(CanvasMetrics.projectCoordinateSpaceName)) { phase in
            switch phase {
            case .active(let location):
                updateFlowHover(location: location, connections: flowConnections, pages: pages, bounds: bounds)
            case .ended:
                clearFlowHoverState()
            }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: bounds.width * scale, height: visualHeight * scale, alignment: .topLeading)
        .padding(CanvasMetrics.documentPadding)
        .onChange(of: store.previewDisplayMode) { _, mode in
            if mode != .flow {
                clearFlowHoverState()
            }
        }
        .onChange(of: store.selectedCanvasSegment) { _, segment in
            if segment != .pages {
                clearFlowHoverState()
            }
        }
    }

    /// 論理名（日本語）: フローhover座標更新関数
    /// 処理概要: キャンバス上のポインタ座標から遷移元ボタンまたは受け側 page の hover 対象を解決します。
    ///
    /// - Parameters:
    ///   - location: キャンバス座標系のポインタ位置。
    ///   - connections: 表示中の静的フロー接続一覧。
    ///   - pages: 表示対象 page 一覧。
    ///   - bounds: page 配置から計算したキャンバス境界。
    private func updateFlowHover(
        location: CGPoint,
        connections: [OpenGraphiteStaticFlowConnection],
        pages: [OpenGraphitePage],
        bounds: CanvasProjectBounds
    ) {
        guard store.previewDisplayMode == .flow, store.selectedCanvasSegment == .pages else {
            clearFlowHoverState()
            return
        }

        if let sourceConnection = connections.first(where: { connection in
            sourceHoverRect(for: connection).insetBy(dx: -6, dy: -6).contains(location)
        }) {
            hoveredFlowTargetPageInternalID = nil
            store.ingestStaticFlowSourceHoverPayload(
                [
                    "id": sourceConnection.link.id,
                    "sourceNodeID": sourceConnection.link.sourceNodeID
                ],
                pageURL: sourceConnection.sourcePageURL,
                pageInternalID: sourceConnection.sourcePageInternalID
            )
            return
        }

        store.clearStaticFlowSourceHover()
        hoveredFlowTargetPageInternalID = pages.first { page in
            pageRect(for: page, in: bounds).contains(location)
        }?.internalID
    }

    /// 論理名（日本語）: フロー遷移先ページホバー処理関数
    /// 処理概要: ページプレビュー上の hover 状態を保持し、受け側 page に入る接続線の強調対象を更新します。
    ///
    /// - Parameters:
    ///   - pageInternalID: hover 状態が変化した page card 内部 ID。
    ///   - isHovering: ポインタが page 上にある場合は `true`。
    private func handleFlowTargetPageHover(pageInternalID: String, isHovering: Bool) {
        guard store.previewDisplayMode == .flow, store.selectedCanvasSegment == .pages else {
            clearFlowHoverState()
            return
        }

        if isHovering {
            hoveredFlowTargetPageInternalID = pageInternalID
        } else if hoveredFlowTargetPageInternalID == pageInternalID {
            hoveredFlowTargetPageInternalID = nil
        }
    }

    /// 論理名（日本語）: フローhover状態解除関数
    /// 処理概要: フロー表示から離れたときに source/target の hover 強調状態をまとめて解除します。
    private func clearFlowHoverState() {
        hoveredFlowTargetPageInternalID = nil
        store.clearStaticFlowSourceHover()
    }

    /// 論理名（日本語）: フロー元ボタンhover矩形生成関数
    /// 処理概要: 接続情報の sourcePoint と元リンク矩形からキャンバス上の hover 判定矩形を復元します。
    ///
    /// - Parameter connection: 判定矩形を作る静的フロー接続。
    /// - Returns: キャンバス座標上の元リンク矩形。
    private func sourceHoverRect(for connection: OpenGraphiteStaticFlowConnection) -> CGRect {
        let sourceRect = connection.link.sourceRect
        let x = connection.sourceSide == .right
            ? connection.sourcePoint.x - sourceRect.width
            : connection.sourcePoint.x
        return CGRect(
            x: x,
            y: connection.sourcePoint.y - sourceRect.height / 2,
            width: sourceRect.width,
            height: sourceRect.height
        )
    }

    /// 論理名（日本語）: キャンバスページ矩形生成関数
    /// 処理概要: `.ogp` の page canvas 配置を表示中キャンバス座標系の矩形へ変換します。
    ///
    /// - Parameters:
    ///   - page: 矩形化する page。
    ///   - bounds: page 配置から計算したキャンバス境界。
    /// - Returns: キャンバス座標上の page 矩形。
    private func pageRect(for page: OpenGraphitePage, in bounds: CanvasProjectBounds) -> CGRect {
        CGRect(
            x: CGFloat(page.canvas.x) - bounds.minX,
            y: CGFloat(page.canvas.y) - bounds.minY + CanvasMetrics.pageNameCardOutsideOffset,
            width: CGFloat(page.canvas.width),
            height: CGFloat(page.canvas.height)
        )
    }
}

/// 論理名（日本語）: 参照入力Popoverアンカー解決器
/// 概要: 右クリック点を中心とするnative source rectを生成し、吹き出しの矢印先端を挿入位置へ固定します。
enum CanvasReferencePopoverAnchorResolver {
    /// 論理名（日本語）: Popover source矩形生成関数
    /// 処理概要: AppKitが任意edgeへpopoverを再配置しても右クリック点からずれにくい1pt矩形を返します。
    ///
    /// - Parameter point: Canvas背景View内の右クリック座標。
    /// - Returns: 指定点を中心とする1pt四方のsource矩形。
    static func sourceRect(centeredAt point: CGPoint) -> CGRect {
        CGRect(x: point.x - 0.5, y: point.y - 0.5, width: 1, height: 1)
    }
}

/// 論理名（日本語）: キャンバス背景コンテキストメニューView
/// 概要: Canvas背景のnative右クリック点から直接popoverを提示し、矢印位置と参照配置座標を同じ点へ揃えます。
private struct CanvasBackgroundContextMenuView: NSViewRepresentable {
    var store: EditorStore
    var canvasOrigin: CGPoint
    var onPrimaryClick: () -> Void

    /// 論理名（日本語）: キャンバス背景Coordinator生成関数
    /// 処理概要: native popoverの表示期間と挿入world座標を管理するCoordinatorを生成します。
    ///
    /// - Returns: Canvas背景用Coordinator。
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 論理名（日本語）: キャンバス背景AppKit View生成関数
    /// 処理概要: 左クリックと右クリックのCanvas座標を通知する透明Viewを生成します。
    ///
    /// - Parameter context: SwiftUI representable文脈。
    /// - Returns: 背景入力を処理するAppKit View。
    func makeNSView(context: Context) -> CanvasBackgroundContextMenuNSView {
        let view = CanvasBackgroundContextMenuNSView()
        view.onPrimaryClick = onPrimaryClick
        context.coordinator.update(store: store, canvasOrigin: canvasOrigin)
        view.onAddReference = { [weak view, weak coordinator = context.coordinator] point in
            guard let view else { return }
            coordinator?.presentReferencePopover(at: point, from: view)
        }
        return view
    }

    /// 論理名（日本語）: キャンバス背景AppKit View更新関数
    /// 処理概要: SwiftUI再描画後の最新callbackを既存Viewへ反映します。
    ///
    /// - Parameters:
    ///   - nsView: 更新対象AppKit View。
    ///   - context: SwiftUI representable文脈。
    func updateNSView(_ nsView: CanvasBackgroundContextMenuNSView, context: Context) {
        nsView.onPrimaryClick = onPrimaryClick
        context.coordinator.update(store: store, canvasOrigin: canvasOrigin)
        nsView.onAddReference = { [weak nsView, weak coordinator = context.coordinator] point in
            guard let nsView else { return }
            coordinator?.presentReferencePopover(at: point, from: nsView)
        }
    }

    /// 論理名（日本語）: キャンバス背景AppKit View破棄関数
    /// 処理概要: Canvas切替やView破棄時に表示中popoverとcallbackを閉じます。
    ///
    /// - Parameters:
    ///   - nsView: 破棄対象AppKit View。
    ///   - coordinator: popoverを保持するCoordinator。
    static func dismantleNSView(_ nsView: CanvasBackgroundContextMenuNSView, coordinator: Coordinator) {
        nsView.onPrimaryClick = nil
        nsView.onAddReference = nil
        coordinator.closePopover()
    }

    /// 論理名（日本語）: キャンバス参照Popover Coordinator
    /// 概要: 右クリックを受けたnative Viewと同じ座標系でNSPopoverを提示し、確定時だけ`.ogp`へ参照を追加します。
    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        private weak var store: EditorStore?
        private var canvasOrigin = CGPoint.zero
        private var popover: NSPopover?

        /// 論理名（日本語）: Popover文脈更新関数
        /// 処理概要: SwiftUI再描画後のStoreとcanonical Canvas原点を保持します。
        ///
        /// - Parameters:
        ///   - store: 参照解決と保存を担当するEditorStore。
        ///   - canvasOrigin: native local座標をworld座標へ戻すCanvas原点。
        func update(store: EditorStore, canvasOrigin: CGPoint) {
            self.store = store
            self.canvasOrigin = canvasOrigin
        }

        /// 論理名（日本語）: 参照入力Popover表示関数
        /// 処理概要: 右クリックlocal座標をsource rectとworld挿入位置の両方に使用してnative popoverを表示します。
        ///
        /// - Parameters:
        ///   - point: Canvas背景View内の右クリック座標。
        ///   - sourceView: 右クリックeventを受けた同一AppKit View。
        func presentReferencePopover(
            at point: CGPoint,
            from sourceView: CanvasBackgroundContextMenuNSView
        ) {
            guard let store, sourceView.window != nil else { return }
            closePopover()

            let insertionPoint = CanvasAnnotationCoordinateResolver.worldPoint(
                localPoint: point,
                canvasOrigin: canvasOrigin
            )
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            let rootView = CanvasReferenceInputPopover(
                store: store,
                initialReferenceID: NSPasteboard.general.string(forType: .string) ?? "",
                onCancel: { [weak popover] in
                    popover?.close()
                },
                onCommit: { [weak popover, weak store] referenceID in
                    if store?.addCanvasReference(referenceID: referenceID, at: insertionPoint) != nil {
                        popover?.close()
                    }
                }
            )
            let hostingController = NSHostingController(rootView: rootView)
            popover.contentViewController = hostingController
            hostingController.view.layoutSubtreeIfNeeded()
            popover.contentSize = hostingController.view.fittingSize
            self.popover = popover
            popover.show(
                relativeTo: CanvasReferencePopoverAnchorResolver.sourceRect(centeredAt: point),
                of: sourceView,
                preferredEdge: .maxY
            )
        }

        /// 論理名（日本語）: 参照入力Popover終了関数
        /// 処理概要: 表示中のnative popoverを閉じ、保持を解除します。
        func closePopover() {
            popover?.close()
            popover = nil
        }

        /// 論理名（日本語）: Popover終了通知関数
        /// 処理概要: transient closeを含む終了後にCoordinatorの保持を解除します。
        ///
        /// - Parameter notification: NSPopover終了通知。
        func popoverDidClose(_ notification: Notification) {
            guard let closedPopover = notification.object as? NSPopover,
                  closedPopover === popover
            else {
                return
            }
            popover = nil
        }
    }
}

/// 論理名（日本語）: キャンバス背景コンテキストメニューAppKit View
/// 概要: Canvas面だけをヒット領域にし、右クリック位置から参照追加メニューを開きます。
private final class CanvasBackgroundContextMenuNSView: NSView {
    var onPrimaryClick: (() -> Void)?
    var onAddReference: ((CGPoint) -> Void)?
    private var contextPoint = CGPoint.zero

    override var isFlipped: Bool { true }

    /// 論理名（日本語）: キャンバス背景左クリック処理関数
    /// 処理概要: Canvas背景のprimary clickを選択解除として通知します。
    ///
    /// - Parameter event: AppKit mouse event。
    override func mouseDown(with event: NSEvent) {
        onPrimaryClick?()
    }

    /// 論理名（日本語）: キャンバス背景右クリック処理関数
    /// 処理概要: View内座標を保持し、「参照IDから追加」だけを持つcontext menuを表示します。
    ///
    /// - Parameter event: AppKit right mouse event。
    override func rightMouseDown(with event: NSEvent) {
        contextPoint = convert(event.locationInWindow, from: nil)
        let menu = NSMenu(title: "OpenGraphite Canvas")
        let item = NSMenuItem(
            title: "参照IDから追加",
            action: #selector(addReferenceFromContextMenu),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    /// 論理名（日本語）: 参照ID追加メニュー実行関数
    /// 処理概要: context menu表示時に固定したCanvas内座標をSwiftUIへ通知します。
    @objc private func addReferenceFromContextMenu() {
        onAddReference?(contextPoint)
    }
}

/// 論理名（日本語）: 参照ID入力ポップアップ
/// 概要: typed参照IDを入力中に随時解決し、対象オブジェクトの切り出しプレビューと確定操作を提供します。
private struct CanvasReferenceInputPopover: View {
    @ObservedObject var store: EditorStore
    @State private var referenceID: String
    @FocusState private var isReferenceFieldFocused: Bool
    var onCancel: () -> Void
    var onCommit: (String) -> Void

    /// 論理名（日本語）: 参照ID入力ポップアップ初期化関数
    /// 処理概要: clipboardがtyped node参照を含む場合だけ入力初期値として採用します。
    ///
    /// - Parameters:
    ///   - store: 参照解決を担当するEditorStore。
    ///   - initialReferenceID: clipboard由来の入力候補。
    ///   - onCancel: 入力取消callback。
    ///   - onCommit: 解決済み参照IDの確定callback。
    init(
        store: EditorStore,
        initialReferenceID: String,
        onCancel: @escaping () -> Void,
        onCommit: @escaping (String) -> Void
    ) {
        self.store = store
        let parsed = OpenGraphiteReferenceID(parsing: initialReferenceID)
        let acceptedInitialValue = parsed?.type == .node || parsed?.type == .componentNode
            ? initialReferenceID.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        _referenceID = State(initialValue: acceptedInitialValue)
        self.onCancel = onCancel
        self.onCommit = onCommit
    }

    var body: some View {
        let resolution = resolvedReference

        VStack(alignment: .leading, spacing: 12) {
            Text("参照IDからオブジェクトを追加")
                .font(.headline)

            TextField("ogref:node:… または ogref:component-node:…", text: $referenceID)
                .textFieldStyle(.roundedBorder)
                .focused($isReferenceFieldFocused)
                .onSubmit {
                    if let target = resolution.target {
                        onCommit(target.referenceID)
                    }
                }

            Group {
                if let target = resolution.target {
                    CanvasResolvedNodePreview(
                        store: store,
                        target: target,
                        viewportSize: CGSize(width: 380, height: 210),
                        isInteractive: false,
                        syncTarget: nil
                    )
                    .frame(width: 380, height: 210)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                    Text("\(target.page.path) · \(target.node.id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    ContentUnavailableView(
                        "プレビュー待機中",
                        systemImage: "link",
                        description: Text(resolution.errorMessage ?? "参照IDを入力してください。")
                    )
                    .frame(width: 380, height: 210)
                }
            }

            HStack {
                Spacer()
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("追加") {
                    if let target = resolution.target {
                        onCommit(target.referenceID)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(resolution.target == nil)
            }
        }
        .padding(16)
        .frame(width: 416)
        .onAppear {
            isReferenceFieldFocused = true
        }
    }

    /// 論理名（日本語）: 入力中参照解決結果
    /// 概要: SwiftUI描画時点の参照IDを解決し、プレビュー対象または利用者向けエラーを返します。
    private var resolvedReference: (target: OpenGraphiteResolvedCanvasReference?, errorMessage: String?) {
        let normalized = referenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return (nil, nil) }
        do {
            return (try store.resolveCanvasReferenceID(normalized), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}

/// 論理名（日本語）: キャンバス参照オブジェクトView
/// 概要: Chapter / Collection直下の参照枠へ元HTML nodeを表示し、選択時は同じ正本への直接編集を有効にします。
private struct CanvasReferenceObjectView: View {
    @ObservedObject var store: EditorStore
    var reference: OpenGraphiteCanvasReference
    var target: OpenGraphiteResolvedCanvasReference
    var zoom: Double
    @State private var dragTranslation = CGSize.zero
    @State private var renderedContentSize: CGSize?

    var body: some View {
        let isSelected = store.selectedCanvasReferenceID == reference.internalID
        let fitBounds = CGSize(
            width: CGFloat(reference.width),
            height: CGFloat(reference.height)
        )
        let displaySize = renderedContentSize ?? fitBounds
        let layout = CanvasPageVisualLayout.resolve(
            pageWidth: displaySize.width,
            pageHeight: displaySize.height
        )

        ZStack(alignment: .topLeading) {
            CanvasDocumentBody(size: displaySize) {
                CanvasResolvedNodePreview(
                    store: store,
                    target: target,
                    viewportSize: fitBounds,
                    isInteractive: isSelected,
                    syncTarget: store.htmlSyncTarget(for: target.page, segment: target.segment),
                    onRenderedSizeChange: { size in
                        guard renderedContentSize != size else { return }
                        renderedContentSize = size
                    }
                )

                if !isSelected {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectCanvasReference(id: reference.internalID)
                        }
                }
            }
            .offset(x: layout.pageBodyFrame.minX, y: layout.pageBodyFrame.minY)

            CanvasPageNameCard(
                title: target.node.id,
                placementName: "参照",
                path: target.page.path,
                resolution: CanvasReferenceVisualLayoutResolver.resolutionLabel(for: displaySize),
                isSelected: isSelected,
                maxTextWidth: layout.captionTextWidth
            )
            .onTapGesture {
                store.selectCanvasReference(id: reference.internalID)
            }
            .highPriorityGesture(dragGesture())
            .contextMenu {
                referenceContextMenu
            }
        }
        .frame(width: layout.documentSize.width, height: layout.documentSize.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if isSelected {
                CanvasSelectionChromeView(
                    rect: CGRect(origin: .zero, size: displaySize),
                    canvasSize: displaySize,
                    lineWidth: 3,
                    zoom: zoom,
                    showsHandles: false
                )
                .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
                .offset(x: layout.pageBodyFrame.minX, y: layout.pageBodyFrame.minY)
                .allowsHitTesting(false)
            } else {
                Rectangle()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(x: layout.pageBodyFrame.minX, y: layout.pageBodyFrame.minY)
            }
        }
        .offset(dragTranslation)
        .contentShape(
            CanvasReferenceHitShape(
                captionFrame: layout.captionHitFrame,
                bodyFrame: layout.pageBodyFrame
            )
        )
        .onTapGesture {
            guard !isSelected else { return }
            store.selectCanvasReference(id: reference.internalID)
        }
        .contextMenu {
            referenceContextMenu
        }
        .accessibilityLabel("参照オブジェクト \(target.node.id)")
        .onChange(of: target.referenceID) { _, _ in
            renderedContentSize = nil
        }
        .onChange(of: fitBounds) { _, _ in
            renderedContentSize = nil
        }
    }

    /// 論理名（日本語）: 参照配置ドラッグGesture生成関数
    /// 処理概要: 画面移動量をCanvas倍率で戻し、ドラッグ終了時だけworld座標を`.ogp`へ保存します。
    ///
    /// - Returns: 参照の左上情報カードへ適用するdrag gesture。
    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: CanvasMetrics.pageDragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                if store.selectedCanvasReferenceID != reference.internalID {
                    store.selectCanvasReference(id: reference.internalID)
                }
                dragTranslation = CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                )
            }
            .onEnded { value in
                let translation = CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                dragTranslation = .zero
                store.updateCanvasReferencePosition(
                    id: reference.internalID,
                    x: reference.x + Double(translation.width),
                    y: reference.y + Double(translation.height)
                )
            }
    }

    /// 論理名（日本語）: 参照配置コンテキストメニュー
    /// 概要: 参照元typed IDのコピーと、配置だけを削除する操作を提供します。
    @ViewBuilder
    private var referenceContextMenu: some View {
        Button("参照IDをコピー") {
            store.copyReferenceIDToPasteboard(reference.referenceID, label: "Canvas reference")
        }
        Divider()
        Button("参照配置を削除", role: .destructive) {
            store.deleteCanvasReference(id: reference.internalID)
        }
    }
}

/// 論理名（日本語）: キャンバス参照ヒット領域Shape
/// 概要: 実表示された参照本体と左上情報カードだけを操作対象にし、最大表示領域の未使用部分をヒット対象から除外します。
///
/// プロパティ:
/// - `captionFrame`: 参照情報カードの操作矩形。
/// - `bodyFrame`: 縮小後実寸へ一致した参照本体の操作矩形。
private struct CanvasReferenceHitShape: Shape {
    var captionFrame: CGRect
    var bodyFrame: CGRect

    /// 論理名（日本語）: キャンバス参照ヒットPath生成関数
    /// 処理概要: 情報カードと参照本体の矩形だけを一つのヒット領域Pathへ追加します。
    ///
    /// - Parameter rect: SwiftUIから渡される外接frame。各矩形は同じlocal座標で既に解決済みです。
    /// - Returns: 情報カードと参照本体のunion path。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(captionFrame)
        path.addRect(bodyFrame)
        return path
    }
}

/// 論理名（日本語）: キャンバス文書本体View
/// 概要: 通常pageと参照viewportで共通する背景、影、本文表示領域を構成します。
///
/// プロパティ:
/// - `size`: HTML本文を表示するviewport寸法。
/// - `content`: viewport内へ表示するWebKit描画または補助オーバーレイ。
private struct CanvasDocumentBody<Content: View>: View {
    var size: CGSize
    @ViewBuilder var content: Content

    /// 論理名（日本語）: キャンバス文書本体View初期化関数
    /// 処理概要: 指定viewport寸法とViewBuilderの本文から共通カード本体を構成します。
    ///
    /// - Parameters:
    ///   - size: HTML本文を表示するviewport寸法。
    ///   - content: viewport内へ表示する本文ViewBuilder。
    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .frame(width: size.width, height: size.height)

            content
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// 論理名（日本語）: 解決不能キャンバス参照View
/// 概要: 外部変更で参照元を失った配置をCanvas上に残し、typed ID確認と配置削除を可能にします。
private struct CanvasBrokenReferenceView: View {
    @ObservedObject var store: EditorStore
    var reference: OpenGraphiteCanvasReference

    var body: some View {
        ContentUnavailableView(
            "参照を解決できません",
            systemImage: "exclamationmark.link",
            description: Text(reference.referenceID)
        )
        .frame(width: CGFloat(reference.width), height: CGFloat(reference.height))
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .contextMenu {
            Button("参照IDをコピー") {
                store.copyReferenceIDToPasteboard(reference.referenceID, label: "Canvas reference")
            }
            Divider()
            Button("参照配置を削除", role: .destructive) {
                store.deleteCanvasReference(id: reference.internalID)
            }
        }
    }
}

/// 論理名（日本語）: 解決済みノード切り出しプレビュー
/// 概要: 元HTMLカードのWKWebViewを維持したまま対象nodeの実測矩形だけを切り出し、指定枠内へ縮小表示します。
private struct CanvasResolvedNodePreview: View {
    @ObservedObject var store: EditorStore
    var target: OpenGraphiteResolvedCanvasReference
    var viewportSize: CGSize
    var isInteractive: Bool
    var syncTarget: HTMLSyncTarget?
    var onRenderedSizeChange: ((CGSize) -> Void)? = nil
    @State private var nodeFrame: CGRect?

    var body: some View {
        let visualLayout = nodeFrame.flatMap {
            CanvasReferenceVisualLayoutResolver.layout(
                sourceSize: $0.size,
                fitBounds: viewportSize
            )
        }
        let displaySize = visualLayout?.renderedSize ?? viewportSize

        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let nodeFrame, let visualLayout {
                ZStack(alignment: .topLeading) {
                    WebCanvasView(
                        store: store,
                        pageURL: target.pageURL,
                        pageInternalID: target.page.internalID,
                        syncTarget: syncTarget,
                        isInteractive: isInteractive,
                        reloadToken: store.reloadToken(for: target.pageURL),
                        previewContext: target.page.canvas.previewContext,
                        allowsComponentPlacements: target.segment == .components,
                        focusedNodeIDs: [target.node.id],
                        onFocusedNodeFrame: { frame in
                            if let frame, frame != nodeFrame {
                                self.nodeFrame = frame
                            }
                        }
                    )
                    .frame(
                        width: max(CGFloat(target.page.canvas.width), nodeFrame.maxX),
                        height: max(CGFloat(target.page.canvas.height), nodeFrame.maxY)
                    )
                    .offset(x: -nodeFrame.minX, y: -nodeFrame.minY)
                }
                .frame(width: nodeFrame.width, height: nodeFrame.height, alignment: .topLeading)
                .clipped()
                .scaleEffect(visualLayout.scale, anchor: .topLeading)
                .frame(
                    width: visualLayout.renderedSize.width,
                    height: visualLayout.renderedSize.height,
                    alignment: .topLeading
                )
            } else {
                ProgressView()
                WebCanvasView(
                    store: store,
                    pageURL: target.pageURL,
                    pageInternalID: target.page.internalID,
                    syncTarget: syncTarget,
                    isInteractive: isInteractive,
                    reloadToken: store.reloadToken(for: target.pageURL),
                    previewContext: target.page.canvas.previewContext,
                    allowsComponentPlacements: target.segment == .components,
                    focusedNodeIDs: [target.node.id],
                    onFocusedNodeFrame: { frame in
                        nodeFrame = frame
                    }
                )
                .frame(
                    width: max(CGFloat(target.page.canvas.width), 1),
                    height: max(CGFloat(target.page.canvas.height), 1)
                )
                .opacity(0.001)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(isInteractive)
        .onAppear {
            if let renderedSize = visualLayout?.renderedSize {
                onRenderedSizeChange?(renderedSize)
            }
        }
        .onChange(of: visualLayout?.renderedSize) { _, renderedSize in
            if let renderedSize {
                onRenderedSizeChange?(renderedSize)
            }
        }
        .onChange(of: target.referenceID) { _, _ in
            nodeFrame = nil
        }
    }
}

/// 論理名（日本語）: キャンバスドキュメントビュー
/// 概要: 単一ページのキャンバスサイズを反映し、その上に WKWebView ベースの HTML プレビューを配置します。
///
/// プロパティ:
/// - `store`: エディター状態ストア。
/// - `page`: 表示対象ページ。
/// - `pageURL`: 表示対象 HTML URL。
/// - `isSelected`: 現在の編集対象ページか。
/// - `zoom`: 現在の表示倍率。
/// - `reloadToken`: 外部変更時に WebView を再読み込みするためのトークン。
/// - `isFlowHoverEnabled`: フロー表示用の受け側 page hover を通知するか。
/// - `onFlowTargetPageHover`: page hover 状態が変わったときに呼ぶ処理。
private struct CanvasDocumentView: View {
    @ObservedObject var store: EditorStore
    var page: OpenGraphitePage
    var pageURL: URL
    var isSelected: Bool
    var zoom: Double
    var reloadToken: Int
    var isFlowHoverEnabled: Bool
    var onFlowTargetPageHover: (String, Bool) -> Void
    @State private var pageDragTranslation: CGSize = .zero
    @State private var pageResizePreview: CanvasPageResizePreview?
    @State private var nodeResizePreview: CanvasNodeResizePreview?
    @State private var isPresentingPermanentDeleteConfirmation = false

    var body: some View {
        let displayedCanvas = pageResizePreview?.pageInternalID == page.internalID
            ? pageResizePreview?.canvas ?? page.canvas
            : page.canvas
        let width = max(CGFloat(displayedCanvas.width), 1)
        let height = max(CGFloat(displayedCanvas.height), 1)
        let layout = CanvasPageVisualLayout.resolve(pageWidth: width, pageHeight: height)
        let pageSize = CGSize(width: width, height: height)
        let pageResizeTranslation = CGSize(
            width: CGFloat(displayedCanvas.x - page.canvas.x),
            height: CGFloat(displayedCanvas.y - page.canvas.y)
        )
        let baseSelectedNodeOverlay = selectedNodeOverlayFrame(pageSize: pageSize)
        let selectedNodeOverlay = displayedSelectedNodeOverlayFrame(
            baseOverlay: baseSelectedNodeOverlay,
            pageSize: pageSize
        )
        let showsSelectedPageOverlay = isSelected && store.selectedNodeID == nil

        ZStack(alignment: .topLeading) {
            CanvasDocumentBody(size: pageSize) {
                WebCanvasView(
                    store: store,
                    pageURL: pageURL,
                    pageInternalID: page.internalID,
                    syncTarget: store.htmlSyncTarget(for: page, segment: store.selectedCanvasSegment),
                    isInteractive: isSelected,
                    reloadToken: reloadToken,
                    previewContext: page.canvas.previewContext,
                    allowsComponentPlacements: store.selectedCanvasSegment == .components
                )
                .frame(width: width, height: height)
                .allowsHitTesting(isSelected)

                if let selectedNodeOverlay {
                    CanvasSelectedNodeOverlay(
                        id: selectedNodeOverlay.id,
                        rect: selectedNodeOverlay.rect,
                        pageSize: pageSize,
                        zoom: zoom,
                        isMovable: selectedNodeOverlay.nodeIDs.count > 1 && canEditSelectedNodeIDs(selectedNodeOverlay.nodeIDs),
                        isResizable: canEditSelectedNodeIDs(selectedNodeOverlay.nodeIDs),
                        onMoveChanged: { rect in
                            handleNodeResizeChanged(id: selectedNodeOverlay.id, rect: rect)
                        },
                        onMoveEnded: { finalRect, originalRect in
                            handleNodeMoveEnded(
                                nodeIDs: selectedNodeOverlay.nodeIDs,
                                nodeRectsByID: selectedNodeOverlay.nodeRectsByID,
                                finalRect: finalRect,
                                originalRect: originalRect,
                                pageSize: pageSize
                            )
                        },
                        onResizeChanged: { rect in
                            handleNodeResizeChanged(id: selectedNodeOverlay.id, rect: rect)
                        },
                        onResizeEnded: { handle, finalRect, originalRect in
                            handleNodeResizeEnded(
                                nodeIDs: selectedNodeOverlay.nodeIDs,
                                nodeRectsByID: selectedNodeOverlay.nodeRectsByID,
                                handle: handle,
                                finalRect: finalRect,
                                originalRect: originalRect,
                                pageSize: pageSize
                            )
                        }
                    )
                }
            }
            .offset(x: layout.pageBodyFrame.minX, y: layout.pageBodyFrame.minY)

            CanvasPageNameCard(
                title: page.id,
                placementName: displayedCanvas.displayName,
                path: page.path,
                resolution: displayedCanvas.resolutionLabel,
                isSelected: isSelected,
                maxTextWidth: layout.captionTextWidth
            )
            .onTapGesture {
                store.selectPage(internalID: page.internalID)
            }
            .highPriorityGesture(pageCaptionDragGesture())
            .contextMenu {
                pageContextMenuItems
            }
            .onCopyCommand {
                guard isSelected, store.selectedNodeID == nil else { return [] }
                return OpenGraphiteReferenceCopy.itemProviders(
                    for: store.pageReferenceID(for: page, segment: store.selectedCanvasSegment)
                )
            }
        }
        .frame(width: layout.documentSize.width, height: layout.documentSize.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if showsSelectedPageOverlay {
                CanvasSelectedPageOverlay(
                    canvas: displayedCanvas,
                    rect: layout.pageBodyFrame,
                    documentSize: layout.documentSize,
                    zoom: zoom,
                    onResizeChanged: handlePageResizeChanged,
                    onResizeEnded: handlePageResizeEnded
                )
            } else {
                Rectangle()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .frame(width: layout.pageBodyFrame.width, height: layout.pageBodyFrame.height)
                    .offset(x: layout.pageBodyFrame.minX, y: layout.pageBodyFrame.minY)
            }
        }
        .offset(
            x: pageDragTranslation.width + pageResizeTranslation.width,
            y: pageDragTranslation.height + pageResizeTranslation.height
        )
        .zIndex(
            CanvasProjectLayerOrder.page(
                isSelected: isSelected,
                isBeingTransformed: pageDragTranslation != .zero || pageResizePreview != nil
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isSelected else { return }
            store.selectPage(internalID: page.internalID)
        }
        .contextMenu {
            pageContextMenuItems
        }
        .onCopyCommand {
            guard isSelected, store.selectedNodeID == nil else { return [] }
            return OpenGraphiteReferenceCopy.itemProviders(
                for: store.pageReferenceID(for: page, segment: store.selectedCanvasSegment)
            )
        }
        .onHover { isHovering in
            guard isFlowHoverEnabled else { return }
            onFlowTargetPageHover(page.internalID, isHovering)
        }
        .onChange(of: store.selectedNodeID) { _, _ in
            nodeResizePreview = nil
            pageResizePreview = nil
        }
        .onChange(of: store.selectedNodeIDs) { _, _ in
            nodeResizePreview = nil
        }
        .confirmationDialog(
            "\(page.displayName) を完全に削除しますか？",
            isPresented: $isPresentingPermanentDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("HTMLとCSSを完全に削除", role: .destructive) {
                store.permanentlyDeletePage(internalID: page.internalID)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この Page entry と HTML、同名 companion CSS は元に戻せません。")
        }
    }

    /// 論理名（日本語）: ページコンテキストメニュー項目
    /// 概要: page card 本体とcaptionの右クリックから、Focus表示、参照IDコピー、Pageの非表示と完全削除を提供します。
    @ViewBuilder
    private var pageContextMenuItems: some View {
        Button("フォーカス表示") {
            beginFocusedPagePreview()
        }

        Divider()

        Button("参照IDをコピー") {
            let segment = store.selectedCanvasSegment
            store.selectPage(internalID: page.internalID)
            store.copyPageReferenceIDToPasteboard(page, segment: segment)
        }

        if store.selectedCanvasSegment == .pages {
            Divider()

            Button("キャンバスから非表示") {
                store.setPageCanvasHidden(internalID: page.internalID, hidden: true)
            }

            Divider()

            Button("完全に削除", role: .destructive) {
                isPresentingPermanentDeleteConfirmation = true
            }
            .disabled(!store.canPermanentlyDeletePage(internalID: page.internalID))
        }
    }

    /// 論理名（日本語）: ページ全体フォーカス開始関数
    /// 処理概要: 右クリックしたpage cardを選択し、canvas寸法全体をoriginal resolutionのFocus対象として固定します。
    private func beginFocusedPagePreview() {
        let segment = store.selectedCanvasSegment
        store.selectPage(internalID: page.internalID)
        store.beginFocusedPagePreview(
            pageInternalID: page.internalID,
            segment: segment,
            size: CGSize(width: CGFloat(page.canvas.width), height: CGFloat(page.canvas.height))
        )
    }

    /// 論理名（日本語）: キャプションカードドラッグジェスチャ生成関数
    /// 処理概要: ページ左上カードのドラッグ量を現在倍率から canvas 座標へ戻し、終了時だけ manifest へ位置を保存します。
    ///
    /// - Returns: キャプションカードへ付与するドラッグジェスチャ。
    private func pageCaptionDragGesture() -> some Gesture {
        DragGesture(minimumDistance: CanvasMetrics.pageDragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                selectPageForCaptionInteraction()
                pageDragTranslation = CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                )
            }
            .onEnded { value in
                let position = CanvasPageDragResolver.finalizedPosition(
                    for: page.canvas,
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                pageDragTranslation = .zero
                selectPageForCaptionInteraction()
                store.updateSelectedPageCanvasPosition(
                    x: Double(position.x),
                    y: Double(position.y)
                )
            }
    }

    /// 論理名（日本語）: キャプション操作ページ選択関数
    /// 処理概要: キャプションカードの click / drag 操作対象を現在の編集対象 page として選択します。
    private func selectPageForCaptionInteraction() {
        guard store.selectedPage?.internalID != page.internalID else { return }
        store.selectPage(internalID: page.internalID)
    }

    /// 論理名（日本語）: ページリサイズpreview更新関数
    /// 処理概要: ページ枠ハンドルのドラッグ中に、`.ogp` 保存前の canvas 矩形をローカル state へ保持します。
    ///
    /// - Parameter canvas: ドラッグ中の page canvas 定義。
    private func handlePageResizeChanged(canvas: OpenGraphiteCanvas) {
        selectPageForCaptionInteraction()
        pageResizePreview = CanvasPageResizePreview(
            pageInternalID: page.internalID,
            canvas: canvas
        )
    }

    /// 論理名（日本語）: ページリサイズ確定関数
    /// 処理概要: ページ枠ハンドルのドラッグ終了時に、canvas 座標と解像度を `.ogp` へ保存します。
    ///
    /// - Parameter canvas: 保存する page canvas 定義。
    private func handlePageResizeEnded(canvas: OpenGraphiteCanvas) {
        pageResizePreview = nil
        selectPageForCaptionInteraction()
        store.updateSelectedPageCanvas(
            x: canvas.x,
            y: canvas.y,
            width: canvas.width,
            height: canvas.height
        )
    }

    /// 論理名（日本語）: 表示用選択ノードオーバーレイ矩形生成関数
    /// 処理概要: リサイズ中の preview 矩形があれば通常の選択矩形より優先して表示します。
    ///
    /// - Parameters:
    ///   - baseOverlay: WebView 実測値または drag preview から解決した基準オーバーレイ。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: 表示に使う選択 node overlay。対象外の場合は `nil`。
    private func displayedSelectedNodeOverlayFrame(
        baseOverlay: CanvasSelectedNodeOverlayFrame?,
        pageSize: CGSize
    ) -> CanvasSelectedNodeOverlayFrame? {
        guard let baseOverlay else { return nil }
        guard let nodeResizePreview,
              nodeResizePreview.pageInternalID == page.internalID,
              nodeResizePreview.nodeID == baseOverlay.id
        else {
            return baseOverlay
        }
        return CanvasSelectedNodeOverlayFrame(
            id: baseOverlay.id,
            nodeIDs: baseOverlay.nodeIDs,
            nodeRectsByID: baseOverlay.nodeRectsByID,
            rect: nodeResizePreview.rect,
            pageSize: pageSize
        ) ?? baseOverlay
    }

    /// 論理名（日本語）: 選択ノードオーバーレイ矩形生成関数
    /// 処理概要: drag preview または WebView 実測値から、選択中 object を page 内座標の矩形へ変換します。
    ///
    /// - Parameter pageSize: page canvas の表示サイズ。
    /// - Returns: Canvas 上で描画する選択 node overlay。対象外または寸法が不正な場合は `nil`。
    private func selectedNodeOverlayFrame(pageSize: CGSize) -> CanvasSelectedNodeOverlayFrame? {
        guard isSelected,
              let selectedNodeID = store.selectedNodeID
        else {
            return nil
        }

        if let dragPreview = store.nodeDragPreview,
           dragPreview.nodeID == selectedNodeID,
           dragPreview.pageInternalID == page.internalID {
            return CanvasSelectedNodeOverlayFrame(id: dragPreview.nodeID, rect: dragPreview.rect, pageSize: pageSize)
        }

        guard let selectionOverlayFrame = store.selectionOverlayFrame,
              selectionOverlayFrame.nodeIDs.contains(selectedNodeID),
              selectionOverlayFrame.pageInternalID == nil || selectionOverlayFrame.pageInternalID == page.internalID
        else {
            return nil
        }
        return CanvasSelectedNodeOverlayFrame(selectionOverlayFrame: selectionOverlayFrame, pageSize: pageSize)
    }

    /// 論理名（日本語）: 選択ノード編集可否判定関数
    /// 処理概要: 選択 node 群が page root やロック済み preview clone ではなく、CSS サイズ保存先を持つか判定します。
    ///
    /// - Parameter ids: 判定する選択 node ID 群。
    /// - Returns: 合成枠操作を可能にする場合は `true`。
    private func canEditSelectedNodeIDs(_ ids: [String]) -> Bool {
        guard !ids.isEmpty else { return false }
        return ids.allSatisfy { id in
            guard let selectedNode = store.nodes.first(where: { $0.id == id }) else { return false }
            return selectedNode.type != "page"
                && !selectedNode.isLocked
                && !selectedNode.isPlacementGenerated
                && !selectedNode.internalID.isEmpty
        }
    }

    /// 論理名（日本語）: ノードリサイズpreview更新関数
    /// 処理概要: ドラッグ中のリサイズ矩形をローカル state へ保持し、選択枠だけを即時更新します。
    ///
    /// - Parameters:
    ///   - id: リサイズ中 node ID。
    ///   - rect: page content 座標上の preview 矩形。
    private func handleNodeResizeChanged(id: String, rect: CGRect) {
        nodeResizePreview = CanvasNodeResizePreview(
            pageInternalID: page.internalID,
            nodeID: id,
            rect: rect
        )
    }

    /// 論理名（日本語）: ノードリサイズ確定関数
    /// 処理概要: ドラッグ終了時の矩形から変更対象 CSS declaration を生成し、ストア経由で正本へ保存します。
    ///
    /// - Parameters:
    ///   - nodeIDs: リサイズ対象 node ID 群。
    ///   - nodeRectsByID: node ID ごとの WebView 実測矩形。
    ///   - handle: 操作されたリサイズハンドル。
    ///   - finalRect: ドラッグ終了時の page content 座標上の矩形。
    ///   - originalRect: ドラッグ開始時の page content 座標上の矩形。
    ///   - pageSize: page canvas の表示サイズ。
    private func handleNodeResizeEnded(
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        handle: CanvasNodeResizeHandle,
        finalRect: CGRect,
        originalRect: CGRect,
        pageSize: CGSize
    ) {
        nodeResizePreview = nil
        if nodeIDs.count > 1 {
            let values = resizedCSSValuesByNodeID(
                nodeIDs: nodeIDs,
                nodeRectsByID: nodeRectsByID,
                finalRect: finalRect,
                originalRect: originalRect,
                pageSize: pageSize
            )
            store.updateSelectedLayerNodeCSSVariables(valuesByNodeID: values)
        } else {
            let values = CanvasNodeResizeResolver.cssValues(
                for: finalRect,
                handle: handle,
                originalRect: originalRect
            )
            store.updateSelectedNodeCSSVariables(values: values)
        }
    }

    /// 論理名（日本語）: ノード移動確定関数
    /// 処理概要: 合成選択枠の移動量を各 node の `left` / `top` に分配し、ストア経由で正本へ保存します。
    ///
    /// - Parameters:
    ///   - nodeIDs: 移動対象 node ID 群。
    ///   - nodeRectsByID: node ID ごとの WebView 実測矩形。
    ///   - finalRect: ドラッグ終了時の合成枠矩形。
    ///   - originalRect: ドラッグ開始時の合成枠矩形。
    ///   - pageSize: page canvas の表示サイズ。
    private func handleNodeMoveEnded(
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        finalRect: CGRect,
        originalRect: CGRect,
        pageSize: CGSize
    ) {
        nodeResizePreview = nil
        guard nodeIDs.count > 1 else { return }
        let translation = CGSize(
            width: finalRect.minX - originalRect.minX,
            height: finalRect.minY - originalRect.minY
        )
        let values = movedCSSValuesByNodeID(
            nodeIDs: nodeIDs,
            nodeRectsByID: nodeRectsByID,
            translation: translation,
            pageSize: pageSize
        )
        store.updateSelectedLayerNodeCSSVariables(valuesByNodeID: values)
    }

    /// 論理名（日本語）: 複数ノードリサイズCSS値生成関数
    /// 処理概要: 合成選択枠のリサイズ結果を各 node の相対位置と寸法へ変換します。
    ///
    /// - Parameters:
    ///   - nodeIDs: 対象 node ID 群。
    ///   - nodeRectsByID: node ID ごとの WebView 実測矩形。
    ///   - finalRect: リサイズ後の合成枠矩形。
    ///   - originalRect: リサイズ前の合成枠矩形。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: node ID ごとの保存対象 CSS declaration 値。
    private func resizedCSSValuesByNodeID(
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        finalRect: CGRect,
        originalRect: CGRect,
        pageSize: CGSize
    ) -> [String: [String: String]] {
        let nodeRects = measuredRectsByNodeID(nodeIDs: nodeIDs, nodeRectsByID: nodeRectsByID, pageSize: pageSize)
        return nodeRects.reduce(into: [String: [String: String]]()) { result, entry in
            let resizedRect = CanvasNodeResizeResolver.resizedRect(
                forNodeRect: entry.value,
                originalGroupRect: originalRect,
                resizedGroupRect: finalRect
            )
            let values = CanvasNodeResizeResolver.cssFrameValues(
                for: resizedRect,
                originalRect: entry.value
            )
            if !values.isEmpty {
                result[entry.key] = values
            }
        }
    }

    /// 論理名（日本語）: 複数ノード移動CSS値生成関数
    /// 処理概要: 合成選択枠の移動量を各 node の `left` / `top` CSS 値へ変換します。
    ///
    /// - Parameters:
    ///   - nodeIDs: 対象 node ID 群。
    ///   - nodeRectsByID: node ID ごとの WebView 実測矩形。
    ///   - translation: 合成枠の移動量。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: node ID ごとの保存対象 CSS declaration 値。
    private func movedCSSValuesByNodeID(
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        translation: CGSize,
        pageSize: CGSize
    ) -> [String: [String: String]] {
        return measuredRectsByNodeID(nodeIDs: nodeIDs, nodeRectsByID: nodeRectsByID, pageSize: pageSize)
            .reduce(into: [String: [String: String]]()) { result, entry in
                let movedRect = entry.value.offsetBy(dx: translation.width, dy: translation.height)
                let values = CanvasNodeResizeResolver.cssPositionValues(for: movedRect, originalRect: entry.value)
                if !values.isEmpty {
                    result[entry.key] = values
                }
            }
    }

    /// 論理名（日本語）: 実測ノード矩形辞書生成関数
    /// 処理概要: node ID 群に対応する WebView 実測矩形を page 範囲内へ丸めて返します。
    ///
    /// - Parameters:
    ///   - nodeIDs: 対象 node ID 群。
    ///   - nodeRectsByID: WebView から届いた node ID ごとの実測矩形。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: node ID ごとの Canvas 矩形。
    private func measuredRectsByNodeID(
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        pageSize: CGSize
    ) -> [String: CGRect] {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        return nodeIDs.reduce(into: [String: CGRect]()) { result, id in
            guard let rect = nodeRectsByID[id] else { return }
            let visibleRect = rect.intersection(pageRect)
            guard !visibleRect.isNull, visibleRect.width > 0, visibleRect.height > 0 else { return }
            result[id] = visibleRect
        }
    }
}

/// 論理名（日本語）: Canvasノードリサイズプレビュー
/// 概要: リサイズドラッグ中の選択ノード矩形を Canvas 側で一時表示するための状態です。
///
/// プロパティ:
/// - `pageInternalID`: preview を表示する page card の内部 ID。
/// - `nodeID`: リサイズ中の node ID。
/// - `rect`: page content 座標上の preview 矩形。
private struct CanvasNodeResizePreview: Equatable {
    var pageInternalID: String
    var nodeID: String
    var rect: CGRect
}

/// 論理名（日本語）: Canvasページリサイズプレビュー
/// 概要: ページ枠ドラッグ中の canvas 座標と解像度を一時表示するための状態です。
///
/// プロパティ:
/// - `pageInternalID`: preview を表示する page card の内部 ID。
/// - `canvas`: ドラッグ中の page canvas 定義。
private struct CanvasPageResizePreview: Equatable {
    var pageInternalID: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: Canvas選択ノードオーバーレイ矩形
/// 概要: WebView の DOM overlay に依存せず、Canvas 座標上で選択 object を可視化するための矩形です。
private struct CanvasSelectedNodeOverlayFrame: Equatable {
    var id: String
    var nodeIDs: [String]
    var nodeRectsByID: [String: CGRect]
    var rect: CGRect

    /// 論理名（日本語）: 実測選択枠由来初期化関数
    /// 処理概要: WebView から届いた実測選択枠を page 範囲内の Canvas 表示矩形へ丸めます。
    ///
    /// - Parameters:
    ///   - selectionOverlayFrame: WebView 実測値由来の選択枠。
    ///   - pageSize: page canvas の表示サイズ。
    init?(selectionOverlayFrame: OpenGraphiteSelectionOverlayFrame, pageSize: CGSize) {
        let displayID = selectionOverlayFrame.nodeIDs.count > 1
            ? "\(selectionOverlayFrame.nodeIDs.count) objects"
            : selectionOverlayFrame.primaryNodeID
        self.init(
            id: displayID,
            nodeIDs: selectionOverlayFrame.nodeIDs,
            nodeRectsByID: selectionOverlayFrame.nodeRectsByID,
            rect: selectionOverlayFrame.rect,
            pageSize: pageSize
        )
    }

    /// 論理名（日本語）: 矩形指定初期化関数
    /// 処理概要: WebView から届いたドラッグ中矩形を page 範囲内へ丸め、overlay 表示用に保持します。
    ///
    /// - Parameters:
    ///   - id: 選択中 node ID。
    ///   - rect: page content 座標上の矩形。
    ///   - pageSize: page canvas の表示サイズ。
    init?(id: String, rect: CGRect, pageSize: CGSize) {
        self.init(id: id, nodeIDs: [id], nodeRectsByID: [id: rect], rect: rect, pageSize: pageSize)
    }

    /// 論理名（日本語）: 複数ノード矩形指定初期化関数
    /// 処理概要: ドラッグ中の合成選択枠を page 範囲内へ丸め、元の編集対象 node ID 群を保持します。
    ///
    /// - Parameters:
    ///   - id: 選択枠の表示 ID。
    ///   - nodeIDs: 選択枠に含まれる編集対象 node ID 群。
    ///   - nodeRectsByID: node ID ごとの実測矩形。
    ///   - rect: page content 座標上の矩形。
    ///   - pageSize: page canvas の表示サイズ。
    init?(
        id: String,
        nodeIDs: [String],
        nodeRectsByID: [String: CGRect],
        rect: CGRect,
        pageSize: CGSize
    ) {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let visibleRect = rect.intersection(pageRect)
        guard !visibleRect.isNull, visibleRect.width > 0, visibleRect.height > 0 else {
            return nil
        }
        let visibleNodeRectsByID = nodeRectsByID.reduce(into: [String: CGRect]()) { result, entry in
            let visibleNodeRect = entry.value.intersection(pageRect)
            guard !visibleNodeRect.isNull, visibleNodeRect.width > 0, visibleNodeRect.height > 0 else { return }
            result[entry.key] = visibleNodeRect
        }
        let visibleNodeIDs = nodeIDs.filter { visibleNodeRectsByID[$0] != nil }
        guard !visibleNodeIDs.isEmpty else { return nil }
        self.id = id
        self.nodeIDs = visibleNodeIDs
        self.nodeRectsByID = visibleNodeRectsByID
        self.rect = visibleRect
    }
}

/// 論理名（日本語）: Canvasスクロール活動通知
/// 概要: AppKit scroll view から選択 chrome へ、wheel scroll 中かどうかを伝えます。
private extension Notification.Name {
    static let canvasScrollActivityDidChange = Notification.Name("dev.opengraphite.canvasScrollActivityDidChange")
}

/// 論理名（日本語）: Canvasスクロール活動通知キー
/// 概要: `canvasScrollActivityDidChange` の userInfo key を定義します。
private enum CanvasScrollActivityNotificationKey {
    static let isActive = "isActive"
}

/// 論理名（日本語）: Canvas選択Chromeレイヤー幾何
/// 概要: SwiftUI overlay 座標から Core Animation layer へ渡す選択枠とハンドル位置を計算します。
enum CanvasSelectionChromeLayerGeometry {
    /// 論理名（日本語）: ローカル選択矩形取得関数
    /// 処理概要: SwiftUI が選択 chrome view 自体を配置できるよう、layer 内部で使う矩形を原点ゼロへ正規化します。
    ///
    /// - Parameter rect: overlay 座標上の選択対象矩形。
    /// - Returns: layer 内部で使うローカル矩形。
    static func localRect(for rect: CGRect) -> CGRect {
        CGRect(origin: .zero, size: rect.size)
    }

    /// 論理名（日本語）: 選択枠レイヤー矩形取得関数
    /// 処理概要: SwiftUI と同じ上原点座標のまま、stroke 幅だけ内側に入れた CAShapeLayer path 矩形を返します。
    ///
    /// - Parameters:
    ///   - rect: 選択対象の overlay 座標矩形。
    ///   - lineWidth: stroke 幅。
    /// - Returns: CAShapeLayer path に使う矩形。
    static func borderRect(for rect: CGRect, lineWidth: CGFloat) -> CGRect {
        rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
    }

    /// 論理名（日本語）: ハンドルレイヤー位置取得関数
    /// 処理概要: SwiftUI hit area と同じ上原点座標で、指定ハンドルの中心位置を返します。
    ///
    /// - Parameters:
    ///   - handle: 位置を求める resize handle。
    ///   - rect: 選択対象の overlay 座標矩形。
    /// - Returns: CAShapeLayer の position。
    static func handlePosition(for handle: CanvasNodeResizeHandle, in rect: CGRect) -> CGPoint {
        handle.position(in: rect)
    }
}

/// 論理名（日本語）: Canvas選択ChromeView
/// 概要: 選択枠とリサイズハンドルの描画を Core Animation layer へ委譲します。
///
/// プロパティ:
/// - `rect`: 選択枠の content 座標矩形。
/// - `canvasSize`: overlay 全体の content 座標サイズ。
/// - `lineWidth`: 選択枠 stroke 幅。
/// - `zoom`: 現在の canvas 表示倍率。
/// - `showsHandles`: リサイズハンドルを描画するかどうか。
private struct CanvasSelectionChromeView: NSViewRepresentable {
    var rect: CGRect
    var canvasSize: CGSize
    var lineWidth: CGFloat
    var zoom: Double
    var showsHandles: Bool

    /// 論理名（日本語）: AppKit選択Chrome生成関数
    /// 処理概要: CAShapeLayer で選択枠を描画する NSView を生成します。
    ///
    /// - Parameter context: SwiftUI representable context。
    /// - Returns: 選択 chrome を描画する AppKit view。
    func makeNSView(context: Context) -> CanvasSelectionChromeNSView {
        CanvasSelectionChromeNSView()
    }

    /// 論理名（日本語）: AppKit選択Chrome更新関数
    /// 処理概要: SwiftUI から渡された選択矩形と表示設定を既存 layer へ反映します。
    ///
    /// - Parameters:
    ///   - nsView: 更新対象の AppKit view。
    ///   - context: SwiftUI representable context。
    func updateNSView(_ nsView: CanvasSelectionChromeNSView, context: Context) {
        nsView.update(
            rect: rect,
            canvasSize: canvasSize,
            lineWidth: lineWidth,
            zoom: zoom,
            showsHandles: showsHandles
        )
    }
}

/// 論理名（日本語）: Canvas選択Chrome AppKit View
/// 概要: 選択枠とリサイズハンドルを CAShapeLayer で保持し、scroll 中は handle shadow を落とします。
private final class CanvasSelectionChromeNSView: NSView {
    private let borderLayer = CAShapeLayer()
    private var handleLayers: [CanvasNodeResizeHandle: CAShapeLayer] = [:]
    private var scrollObserver: NSObjectProtocol?
    private var selectionRect = CGRect.zero
    private var canvasSize = CGSize.zero
    private var lineWidth: CGFloat = 2
    private var zoom: Double = 1
    private var showsHandles = true
    private var suppressesHandleShadow = false

    override var isFlipped: Bool { true }

    /// 論理名（日本語）: Canvas選択Chrome初期化関数
    /// 処理概要: Core Animation layer を構築し、scroll activity 通知を購読します。
    ///
    /// - Parameter frameRect: 初期 frame。
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isGeometryFlipped = true
        layer?.masksToBounds = false
        configureLayers()
        scrollObserver = NotificationCenter.default.addObserver(
            forName: .canvasScrollActivityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isActive = notification.userInfo?[CanvasScrollActivityNotificationKey.isActive] as? Bool ?? false
            self?.setSuppressesHandleShadow(isActive)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

    /// 論理名（日本語）: 選択Chrome更新関数
    /// 処理概要: 最新の選択矩形、倍率、ハンドル表示可否を layer に反映します。
    ///
    /// - Parameters:
    ///   - rect: 選択枠の content 座標矩形。
    ///   - canvasSize: overlay 全体の content 座標サイズ。
    ///   - lineWidth: 選択枠 stroke 幅。
    ///   - zoom: 現在の canvas 表示倍率。
    ///   - showsHandles: リサイズハンドルを描画するかどうか。
    func update(rect: CGRect, canvasSize: CGSize, lineWidth: CGFloat, zoom: Double, showsHandles: Bool) {
        self.selectionRect = rect
        self.canvasSize = canvasSize
        self.lineWidth = lineWidth
        self.zoom = zoom
        self.showsHandles = showsHandles
        updateLayers()
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: SwiftUI 側の frame 変更に合わせて既存 layer の path と位置を再計算します。
    override func layout() {
        super.layout()
        updateLayers()
    }

    private func configureLayers() {
        borderLayer.isGeometryFlipped = true
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.controlAccentColor.cgColor
        borderLayer.lineJoin = .round
        layer?.addSublayer(borderLayer)

        CanvasNodeResizeHandle.allCases.forEach { handle in
            let handleLayer = CAShapeLayer()
            handleLayer.fillColor = NSColor.controlBackgroundColor.cgColor
            handleLayer.strokeColor = NSColor.controlAccentColor.cgColor
            handleLayer.masksToBounds = false
            handleLayers[handle] = handleLayer
            layer?.addSublayer(handleLayer)
        }
    }

    private func setSuppressesHandleShadow(_ nextValue: Bool) {
        guard suppressesHandleShadow != nextValue else { return }
        suppressesHandleShadow = nextValue
        updateHandleShadows()
    }

    private func updateLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let resolvedBounds = CGRect(origin: .zero, size: resolvedCanvasSize())
        borderLayer.frame = resolvedBounds
        guard selectionRect.width > 0, selectionRect.height > 0 else {
            borderLayer.isHidden = true
            handleLayers.values.forEach { $0.isHidden = true }
            return
        }

        borderLayer.isHidden = false
        borderLayer.strokeColor = NSColor.controlAccentColor.cgColor
        borderLayer.lineWidth = lineWidth
        let borderRect = CanvasSelectionChromeLayerGeometry.borderRect(for: selectionRect, lineWidth: lineWidth)
        borderLayer.path = CGPath(rect: borderRect, transform: nil)

        updateHandles()
    }

    private func updateHandles() {
        let inverseZoomScale = inverseZoomScale
        let diameter = max(4, 8 * inverseZoomScale)
        let handleBounds = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        let handlePath = CGPath(ellipseIn: handleBounds, transform: nil)

        CanvasNodeResizeHandle.allCases.forEach { handle in
            guard let handleLayer = handleLayers[handle] else { return }
            handleLayer.isHidden = !showsHandles
            handleLayer.bounds = handleBounds
            handleLayer.path = handlePath
            handleLayer.position = CanvasSelectionChromeLayerGeometry.handlePosition(for: handle, in: selectionRect)
            handleLayer.lineWidth = max(0.75, 1.5 * inverseZoomScale)
            handleLayer.fillColor = NSColor.controlBackgroundColor.cgColor
            handleLayer.strokeColor = NSColor.controlAccentColor.cgColor
            handleLayer.shadowPath = handlePath
        }
        updateHandleShadows()
    }

    private func updateHandleShadows() {
        let inverseZoomScale = inverseZoomScale
        handleLayers.values.forEach { handleLayer in
            if suppressesHandleShadow || handleLayer.isHidden {
                handleLayer.shadowOpacity = 0
                return
            }
            handleLayer.shadowColor = NSColor.black.cgColor
            handleLayer.shadowOpacity = 0.2
            handleLayer.shadowRadius = 2 * inverseZoomScale
            handleLayer.shadowOffset = CGSize(width: 0, height: -1 * inverseZoomScale)
        }
    }

    private var inverseZoomScale: CGFloat {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return 1 / CGFloat(zoom)
    }

    private func resolvedCanvasSize() -> CGSize {
        CGSize(
            width: max(bounds.width, canvasSize.width, 1),
            height: max(bounds.height, canvasSize.height, 1)
        )
    }
}

/// 論理名（日本語）: Canvas選択ページオーバーレイ
/// 概要: 選択中ページの枠を Core Animation で描画し、SwiftUI 側にはリサイズ操作領域だけを置きます。
///
/// プロパティ:
/// - `canvas`: 表示中またはドラッグ中の page canvas 定義。
/// - `rect`: document 座標上の page 本体矩形。
/// - `documentSize`: キャプションを含む document view 全体サイズ。
/// - `zoom`: 現在の canvas 表示倍率。
/// - `onResizeChanged`: ドラッグ中 canvas が変わったときに呼ぶ処理。
/// - `onResizeEnded`: ドラッグ終了時 canvas を保存する処理。
private struct CanvasSelectedPageOverlay: View {
    var canvas: OpenGraphiteCanvas
    var rect: CGRect
    var documentSize: CGSize
    var zoom: Double
    var onResizeChanged: (OpenGraphiteCanvas) -> Void
    var onResizeEnded: (OpenGraphiteCanvas) -> Void
    @State private var resizeStartCanvas: OpenGraphiteCanvas?

    var body: some View {
        ZStack(alignment: .topLeading) {
            CanvasSelectionChromeView(
                rect: CanvasSelectionChromeLayerGeometry.localRect(for: rect),
                canvasSize: rect.size,
                lineWidth: 3,
                zoom: zoom,
                showsHandles: true
            )
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)

            ForEach(CanvasNodeResizeHandle.allCases) { handle in
                CanvasNodeResizeHandleHitArea(
                    handle: handle,
                    inverseZoomScale: inverseZoomScale
                )
                .position(handle.position(in: rect))
                .gesture(resizeGesture(for: handle))
            }
        }
        .frame(width: documentSize.width, height: documentSize.height, alignment: .topLeading)
    }

    private var inverseZoomScale: CGFloat {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return 1 / CGFloat(zoom)
    }

    /// 論理名（日本語）: ページリサイズジェスチャ生成関数
    /// 処理概要: 指定ハンドルのドラッグ量を page canvas 座標と解像度へ変換し、変更中と終了時の callback を呼びます。
    ///
    /// - Parameter handle: 操作対象のリサイズハンドル。
    /// - Returns: ハンドルへ付与するドラッグジェスチャ。
    private func resizeGesture(for handle: CanvasNodeResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let startCanvas = resizeStartCanvas ?? canvas
                if resizeStartCanvas == nil {
                    resizeStartCanvas = startCanvas
                }
                let resizedCanvas = CanvasPageResizeResolver.resizedCanvas(
                    for: startCanvas,
                    handle: handle,
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                onResizeChanged(resizedCanvas)
            }
            .onEnded { value in
                let startCanvas = resizeStartCanvas ?? canvas
                let resizedCanvas = CanvasPageResizeResolver.resizedCanvas(
                    for: startCanvas,
                    handle: handle,
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                resizeStartCanvas = nil
                onResizeEnded(resizedCanvas)
            }
    }
}

/// 論理名（日本語）: Canvas選択ノードオーバーレイ
/// 概要: page preview の上に、Core Animation の選択枠と SwiftUI の操作領域を重ねます。
private struct CanvasSelectedNodeOverlay: View {
    var id: String
    var rect: CGRect
    var pageSize: CGSize
    var zoom: Double
    var isMovable: Bool
    var isResizable: Bool
    var onMoveChanged: (CGRect) -> Void
    var onMoveEnded: (CGRect, CGRect) -> Void
    var onResizeChanged: (CGRect) -> Void
    var onResizeEnded: (CanvasNodeResizeHandle, CGRect, CGRect) -> Void
    @State private var moveStartRect: CGRect?
    @State private var resizeStartRect: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            CanvasSelectionChromeView(
                rect: CanvasSelectionChromeLayerGeometry.localRect(for: rect),
                canvasSize: rect.size,
                lineWidth: 2,
                zoom: zoom,
                showsHandles: isResizable
            )
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)

            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .contentShape(Rectangle())
                .gesture(moveGesture())
                .allowsHitTesting(isMovable)

            if !id.isEmpty {
                Text(id)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 36, minHeight: 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: rect.minX, y: rect.minY >= 20 ? rect.minY - 18 : rect.minY + 3)
                    .allowsHitTesting(false)
            }

            if isResizable {
                ForEach(CanvasNodeResizeHandle.allCases) { handle in
                    CanvasNodeResizeHandleHitArea(
                        handle: handle,
                        inverseZoomScale: inverseZoomScale
                    )
                    .position(handle.position(in: rect))
                    .gesture(resizeGesture(for: handle))
                }
            }
        }
        .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
    }

    private var inverseZoomScale: CGFloat {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return 1 / CGFloat(zoom)
    }

    /// 論理名（日本語）: 移動ジェスチャ生成関数
    /// 処理概要: 合成選択枠のドラッグ量を page content 座標上の移動後矩形へ変換します。
    ///
    /// - Returns: 合成選択枠へ付与するドラッグジェスチャ。
    private func moveGesture() -> some Gesture {
        DragGesture(minimumDistance: CanvasMetrics.pageDragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                let startRect = moveStartRect ?? rect
                if moveStartRect == nil {
                    moveStartRect = startRect
                }
                let movedRect = CanvasNodeResizeResolver.movedRect(
                    startRect: startRect,
                    screenTranslation: value.translation,
                    zoom: zoom,
                    pageSize: pageSize
                )
                onMoveChanged(movedRect)
            }
            .onEnded { value in
                let startRect = moveStartRect ?? rect
                let movedRect = CanvasNodeResizeResolver.movedRect(
                    startRect: startRect,
                    screenTranslation: value.translation,
                    zoom: zoom,
                    pageSize: pageSize
                )
                moveStartRect = nil
                onMoveEnded(movedRect, startRect)
            }
    }

    /// 論理名（日本語）: リサイズジェスチャ生成関数
    /// 処理概要: 指定ハンドルのドラッグ量を page content 座標上の矩形へ変換し、変更中と終了時の callback を呼びます。
    ///
    /// - Parameter handle: 操作対象のリサイズハンドル。
    /// - Returns: ハンドルへ付与するドラッグジェスチャ。
    private func resizeGesture(for handle: CanvasNodeResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let startRect = resizeStartRect ?? rect
                if resizeStartRect == nil {
                    resizeStartRect = startRect
                }
                let resizedRect = CanvasNodeResizeResolver.resizedRect(
                    startRect: startRect,
                    handle: handle,
                    screenTranslation: value.translation,
                    zoom: zoom,
                    pageSize: pageSize
                )
                onResizeChanged(resizedRect)
            }
            .onEnded { value in
                let startRect = resizeStartRect ?? rect
                let resizedRect = CanvasNodeResizeResolver.resizedRect(
                    startRect: startRect,
                    handle: handle,
                    screenTranslation: value.translation,
                    zoom: zoom,
                    pageSize: pageSize
                )
                resizeStartRect = nil
                onResizeEnded(handle, resizedRect, startRect)
            }
    }
}

/// 論理名（日本語）: Canvasノードリサイズハンドル操作領域
/// 概要: Core Animation が描画するハンドルの上に置く、ズームに依存しない透明な操作点です。
///
/// プロパティ:
/// - `handle`: 表示するハンドル種別。
/// - `inverseZoomScale`: 親 Canvas のズームを相殺する表示倍率。
private struct CanvasNodeResizeHandleHitArea: View {
    var handle: CanvasNodeResizeHandle
    var inverseZoomScale: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .scaleEffect(inverseZoomScale)
            .accessibilityLabel(handle.accessibilityLabel)
            .help(handle.accessibilityLabel)
    }
}

/// 論理名（日本語）: Canvasノードリサイズハンドル
/// 概要: 選択中オブジェクトの四辺と四隅に配置するリサイズ操作点を表します。
///
/// 定義内容:
/// - `topLeft`: 左上角。
/// - `top`: 上辺。
/// - `topRight`: 右上角。
/// - `right`: 右辺。
/// - `bottomRight`: 右下角。
/// - `bottom`: 下辺。
/// - `bottomLeft`: 左下角。
/// - `left`: 左辺。
enum CanvasNodeResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .topLeft:
            "Resize top left"
        case .top:
            "Resize top"
        case .topRight:
            "Resize top right"
        case .right:
            "Resize right"
        case .bottomRight:
            "Resize bottom right"
        case .bottom:
            "Resize bottom"
        case .bottomLeft:
            "Resize bottom left"
        case .left:
            "Resize left"
        }
    }

    var horizontalDirection: CGFloat {
        switch self {
        case .topLeft, .bottomLeft, .left:
            -1
        case .topRight, .right, .bottomRight:
            1
        case .top, .bottom:
            0
        }
    }

    var verticalDirection: CGFloat {
        switch self {
        case .topLeft, .top, .topRight:
            -1
        case .bottomRight, .bottom, .bottomLeft:
            1
        case .right, .left:
            0
        }
    }

    /// 論理名（日本語）: ハンドル位置生成関数
    /// 処理概要: 選択矩形上でこのハンドルを置く中心座標を返します。
    ///
    /// - Parameter rect: page content 座標上の選択矩形。
    /// - Returns: ハンドル中心座標。
    func position(in rect: CGRect) -> CGPoint {
        let x = horizontalDirection < 0
            ? rect.minX
            : (horizontalDirection > 0 ? rect.maxX : rect.midX)
        let y = verticalDirection < 0
            ? rect.minY
            : (verticalDirection > 0 ? rect.maxY : rect.midY)
        return CGPoint(x: x, y: y)
    }
}

/// 論理名（日本語）: Canvasノードリサイズ解決器
/// 概要: 画面上のハンドルドラッグ量を page content 座標の矩形と CSS declaration 値へ変換します。
///
/// 定義内容:
/// - `resizedRect(startRect:handle:screenTranslation:zoom:pageSize:)`: ドラッグ中または終了時の矩形を算出します。
/// - `cssValues(for:handle:originalRect:)`: 保存対象 CSS declaration を生成します。
enum CanvasNodeResizeResolver {
    static let minimumSize: CGFloat = 2

    /// 論理名（日本語）: 移動後矩形生成関数
    /// 処理概要: ズーム適用後の画面ドラッグ量を page content 座標へ戻し、page 範囲内へ収めた移動後矩形を返します。
    ///
    /// - Parameters:
    ///   - startRect: ドラッグ開始時の page content 座標上の矩形。
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: 補正済みの移動後矩形。
    static func movedRect(
        startRect: CGRect,
        screenTranslation: CGSize,
        zoom: Double,
        pageSize: CGSize
    ) -> CGRect {
        let translation = CanvasPageDragResolver.canvasTranslation(
            screenTranslation: screenTranslation,
            zoom: zoom
        )
        let bounds = CGRect(origin: .zero, size: pageSize)
        let minX = min(max(startRect.minX + translation.width, bounds.minX), max(bounds.maxX - startRect.width, bounds.minX))
        let minY = min(max(startRect.minY + translation.height, bounds.minY), max(bounds.maxY - startRect.height, bounds.minY))
        return CGRect(
            x: minX.rounded(),
            y: minY.rounded(),
            width: startRect.width,
            height: startRect.height
        )
    }

    /// 論理名（日本語）: リサイズ後矩形生成関数
    /// 処理概要: ズーム適用後の画面ドラッグ量を page content 座標へ戻し、page 範囲と最小サイズで矩形を補正します。
    ///
    /// - Parameters:
    ///   - startRect: ドラッグ開始時の page content 座標上の矩形。
    ///   - handle: 操作中のリサイズハンドル。
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    ///   - pageSize: page canvas の表示サイズ。
    /// - Returns: 補正済みのリサイズ後矩形。
    static func resizedRect(
        startRect: CGRect,
        handle: CanvasNodeResizeHandle,
        screenTranslation: CGSize,
        zoom: Double,
        pageSize: CGSize
    ) -> CGRect {
        let translation = CanvasPageDragResolver.canvasTranslation(
            screenTranslation: screenTranslation,
            zoom: zoom
        )
        let bounds = CGRect(origin: .zero, size: pageSize)
        var minX = startRect.minX
        var maxX = startRect.maxX
        var minY = startRect.minY
        var maxY = startRect.maxY

        if handle.horizontalDirection < 0 {
            minX = min(startRect.minX + translation.width, startRect.maxX - minimumSize)
            minX = max(bounds.minX, minX)
        } else if handle.horizontalDirection > 0 {
            maxX = max(startRect.maxX + translation.width, startRect.minX + minimumSize)
            maxX = min(bounds.maxX, maxX)
        }

        if handle.verticalDirection < 0 {
            minY = min(startRect.minY + translation.height, startRect.maxY - minimumSize)
            minY = max(bounds.minY, minY)
        } else if handle.verticalDirection > 0 {
            maxY = max(startRect.maxY + translation.height, startRect.minY + minimumSize)
            maxY = min(bounds.maxY, maxY)
        }

        return CGRect(
            x: minX.rounded(),
            y: minY.rounded(),
            width: max((maxX - minX).rounded(), minimumSize),
            height: max((maxY - minY).rounded(), minimumSize)
        )
    }

    /// 論理名（日本語）: グループリサイズ内ノード矩形生成関数
    /// 処理概要: 合成選択枠のリサイズ比率を個別 node の相対位置と寸法へ適用します。
    ///
    /// - Parameters:
    ///   - nodeRect: リサイズ前の個別 node 矩形。
    ///   - originalGroupRect: リサイズ前の合成選択枠矩形。
    ///   - resizedGroupRect: リサイズ後の合成選択枠矩形。
    /// - Returns: 合成枠リサイズ後の個別 node 矩形。
    static func resizedRect(
        forNodeRect nodeRect: CGRect,
        originalGroupRect: CGRect,
        resizedGroupRect: CGRect
    ) -> CGRect {
        let scaleX = originalGroupRect.width > 0 ? resizedGroupRect.width / originalGroupRect.width : 1
        let scaleY = originalGroupRect.height > 0 ? resizedGroupRect.height / originalGroupRect.height : 1
        let x = resizedGroupRect.minX + (nodeRect.minX - originalGroupRect.minX) * scaleX
        let y = resizedGroupRect.minY + (nodeRect.minY - originalGroupRect.minY) * scaleY
        let width = max(nodeRect.width * scaleX, minimumSize)
        let height = max(nodeRect.height * scaleY, minimumSize)
        return CGRect(
            x: x.rounded(),
            y: y.rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }

    /// 論理名（日本語）: CSS値生成関数
    /// 処理概要: 操作ハンドルに応じて保存が必要な `left`、`top`、`width`、`height` だけを CSS px 値として返します。
    ///
    /// - Parameters:
    ///   - rect: リサイズ後の page content 座標上の矩形。
    ///   - handle: 操作されたリサイズハンドル。
    ///   - originalRect: ドラッグ開始時の page content 座標上の矩形。
    /// - Returns: 保存対象 CSS declaration 値。
    static func cssValues(
        for rect: CGRect,
        handle: CanvasNodeResizeHandle,
        originalRect: CGRect
    ) -> [String: String] {
        var values: [String: String] = [:]

        if handle.horizontalDirection < 0 {
            values["left"] = cssPixelString(rect.minX)
            values["width"] = cssPixelString(rect.width)
        } else if handle.horizontalDirection > 0 {
            values["width"] = cssPixelString(rect.width)
        }

        if handle.verticalDirection < 0 {
            values["top"] = cssPixelString(rect.minY)
            values["height"] = cssPixelString(rect.height)
        } else if handle.verticalDirection > 0 {
            values["height"] = cssPixelString(rect.height)
        }

        return values.filter { key, value in
            originalCSSValue(for: key, rect: originalRect) != value
        }
    }

    /// 論理名（日本語）: CSS位置値生成関数
    /// 処理概要: 移動後の矩形から保存対象の `left` / `top` CSS px 値を返します。
    ///
    /// - Parameters:
    ///   - rect: 移動後の page content 座標上の矩形。
    ///   - originalRect: 移動前の page content 座標上の矩形。
    /// - Returns: 保存対象 CSS declaration 値。
    static func cssPositionValues(for rect: CGRect, originalRect: CGRect) -> [String: String] {
        [
            "left": cssPixelString(rect.minX),
            "top": cssPixelString(rect.minY)
        ].filter { key, value in
            originalCSSValue(for: key, rect: originalRect) != value
        }
    }

    /// 論理名（日本語）: CSS矩形値生成関数
    /// 処理概要: 合成選択枠の変形後に個別 node へ保存する `left` / `top` / `width` / `height` 差分を返します。
    ///
    /// - Parameters:
    ///   - rect: 変形後の page content 座標上の矩形。
    ///   - originalRect: 変形前の page content 座標上の矩形。
    /// - Returns: 保存対象 CSS declaration 値。
    static func cssFrameValues(for rect: CGRect, originalRect: CGRect) -> [String: String] {
        [
            "left": cssPixelString(rect.minX),
            "top": cssPixelString(rect.minY),
            "width": cssPixelString(rect.width),
            "height": cssPixelString(rect.height)
        ].filter { key, value in
            originalCSSValue(for: key, rect: originalRect) != value
        }
    }

    /// 論理名（日本語）: CSSピクセル文字列生成関数
    /// 処理概要: Canvas 座標値を小数 1 桁までの `px` 文字列へ変換します。
    ///
    /// - Parameter value: CSS 値へ変換する座標または寸法。
    /// - Returns: `px` 単位の CSS 文字列。
    static func cssPixelString(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 10).rounded() / 10
        let normalized = abs(rounded) < 0.05 ? 0 : rounded
        if normalized.rounded() == normalized {
            return "\(Int(normalized))px"
        }
        return "\(normalized)px"
    }

    /// 論理名（日本語）: 元矩形CSS値生成関数
    /// 処理概要: 変更判定用に元矩形から CSS property に対応する値を生成します。
    ///
    /// - Parameters:
    ///   - key: CSS property 名。
    ///   - rect: 変換元の page content 座標上の矩形。
    /// - Returns: 比較用 CSS 値。
    private static func originalCSSValue(for key: String, rect: CGRect) -> String {
        switch key {
        case "left":
            cssPixelString(rect.minX)
        case "top":
            cssPixelString(rect.minY)
        case "width":
            cssPixelString(rect.width)
        case "height":
            cssPixelString(rect.height)
        default:
            ""
        }
    }
}

/// 論理名（日本語）: キャンバスプレビュー表示モードピッカー
/// 概要: プレビュー右上で通常表示とフロー表示を切り替える小型セグメントボタンです。
///
/// プロパティ:
/// - `mode`: 現在のプレビュー表示モード。
private struct CanvasPreviewModePicker: View {
    @Binding var mode: OpenGraphitePreviewDisplayMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OpenGraphitePreviewDisplayMode.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        mode = option
                    }
                } label: {
                    HStack(spacing: 5) {
                        OpenGraphiteIconView(icon: .previewDisplayMode(option), size: 13, weight: .semibold)
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .foregroundStyle(mode == option ? Color.white : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .fill(mode == option ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .help(option.help)
                .accessibilityLabel(option.help)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }
}

/// 論理名（日本語）: キャンバス静的フローオーバーレイ
/// 概要: 静的リンクから解決した画面遷移を、キャンバス上のベジェ曲線と矢印として描画します。
///
/// プロパティ:
/// - `connections`: 描画対象の静的フロー接続一覧。
/// - `hoveredSource`: ホバー中の遷移元リンク。該当接続を不透明にします。
/// - `hoveredTargetPageInternalID`: ホバー中の遷移先 page card 内部 ID。該当 page への接続を不透明にします。
/// - `selectedSourcePageURL`: 選択中ノードを含む HTML page の URL。
/// - `selectedSourcePageInternalID`: 選択中ノードを含む page card 内部 ID。
/// - `selectedSourceNodeID`: 選択中ノード ID。遷移元リンクと一致する接続を不透明にします。
/// - `selectedTargetPageInternalID`: 選択中 page card 内部 ID。受け側 page と一致する接続を不透明にします。
private struct CanvasStaticFlowOverlay: View {
    var connections: [OpenGraphiteStaticFlowConnection]
    var hoveredSource: OpenGraphiteStaticFlowSourceHover?
    var hoveredTargetPageInternalID: String?
    var selectedSourcePageURL: URL?
    var selectedSourcePageInternalID: String?
    var selectedSourceNodeID: String?
    var selectedTargetPageInternalID: String?

    var body: some View {
        Canvas { context, _ in
            for connection in connections {
                if !isConnectionHighlighted(connection) {
                    draw(connection, isHighlighted: false, in: context)
                }
            }
            for connection in connections {
                if isConnectionHighlighted(connection) {
                    draw(connection, isHighlighted: true, in: context)
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredSource)
        .animation(.easeOut(duration: 0.12), value: hoveredTargetPageInternalID)
        .animation(.easeOut(duration: 0.12), value: selectedSourcePageURL)
        .animation(.easeOut(duration: 0.12), value: selectedSourcePageInternalID)
        .animation(.easeOut(duration: 0.12), value: selectedSourceNodeID)
        .animation(.easeOut(duration: 0.12), value: selectedTargetPageInternalID)
    }

    /// 論理名（日本語）: フロー接続描画関数
    /// 処理概要: 単一の接続を曲線、始点ドット、終点矢印として描画します。
    ///
    /// - Parameters:
    ///   - connection: 描画対象の静的フロー接続。
    ///   - isHighlighted: hover 対象として不透明表示する場合は `true`。
    ///   - context: SwiftUI Canvas の描画 context。
    private func draw(_ connection: OpenGraphiteStaticFlowConnection, isHighlighted: Bool, in context: GraphicsContext) {
        let source = connection.sourcePoint
        let target = connection.targetPoint
        let controlOffset = max(abs(target.x - source.x) * 0.35, 96)
        let sourceControlDirection: CGFloat = connection.sourceSide == .right ? 1 : -1
        let firstControl = CGPoint(x: source.x + controlOffset * sourceControlDirection, y: source.y)
        let targetControlDirection: CGFloat = connection.targetSide == .right ? 1 : -1
        let secondControl = CGPoint(x: target.x + controlOffset * targetControlDirection, y: target.y)
        let color = Color.accentColor.opacity(isHighlighted ? 1.0 : 0.28)

        var path = Path()
        path.move(to: source)
        path.addCurve(to: target, control1: firstControl, control2: secondControl)
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )

        let sourceDotRect = CGRect(x: source.x - 4, y: source.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: sourceDotRect), with: .color(color))
        context.fill(arrowHead(at: target, from: secondControl), with: .color(color))
    }

    /// 論理名（日本語）: フロー接続強調判定関数
    /// 処理概要: hover 中または選択中の遷移元リンク、受け側 page に該当する接続かを判定します。
    ///
    /// - Parameter connection: 判定対象の静的フロー接続。
    /// - Returns: 不透明で描画する接続の場合は `true`。
    private func isConnectionHighlighted(_ connection: OpenGraphiteStaticFlowConnection) -> Bool {
        if let hoveredSource,
           connection.sourcePageURL == hoveredSource.pageURL,
           isMatchingPageInternalID(connection.sourcePageInternalID, hoveredSource.pageInternalID),
           connection.link.id == hoveredSource.linkID {
            return true
        }

        if let hoveredTargetPageInternalID,
           connection.targetPageInternalID == hoveredTargetPageInternalID {
            return true
        }

        if let selectedSourcePageURL,
           let selectedSourcePageInternalID,
           let selectedSourceNodeID,
           connection.sourcePageURL == selectedSourcePageURL,
           connection.sourcePageInternalID == selectedSourcePageInternalID,
           connection.link.sourceNodeID == selectedSourceNodeID {
            return true
        }

        if let selectedTargetPageInternalID,
           connection.targetPageInternalID == selectedTargetPageInternalID {
            return true
        }

        return false
    }

    /// 論理名（日本語）: page内部ID一致判定関数
    /// 処理概要: 選択中 page 内部 ID がある場合だけ source hover 強調をその page card に限定します。
    ///
    /// - Parameters:
    ///   - connectionPageInternalID: 接続が持つ page card 内部 ID。
    ///   - selectedPageInternalID: 選択中 page card 内部 ID。
    /// - Returns: 強調対象として扱う場合は `true`。
    private func isMatchingPageInternalID(_ connectionPageInternalID: String, _ selectedPageInternalID: String?) -> Bool {
        guard let selectedPageInternalID, !selectedPageInternalID.isEmpty else { return true }
        return connectionPageInternalID == selectedPageInternalID
    }

    /// 論理名（日本語）: 矢印ヘッド生成関数
    /// 処理概要: 曲線終端の接線方向に合わせた三角形パスを生成します。
    ///
    /// - Parameters:
    ///   - point: 矢印先端座標。
    ///   - previousPoint: 終端接線を推定するための直前制御点。
    /// - Returns: 矢印ヘッドのパス。
    private func arrowHead(at point: CGPoint, from previousPoint: CGPoint) -> Path {
        let angle = atan2(point.y - previousPoint.y, point.x - previousPoint.x)
        let length: CGFloat = 14
        let spread = CGFloat.pi / 7
        let left = CGPoint(
            x: point.x - cos(angle - spread) * length,
            y: point.y - sin(angle - spread) * length
        )
        let right = CGPoint(
            x: point.x - cos(angle + spread) * length,
            y: point.y - sin(angle + spread) * length
        )

        var path = Path()
        path.move(to: point)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }
}

/// 論理名（日本語）: キャンバスページ名カード
/// 概要: キャンバス上のページ枠左上外側に表示するページ識別子カードです。
///
/// プロパティ:
/// - `title`: 表示するページ識別子。
/// - `placementName`: フロー解決に使う配置名。
/// - `path`: HTML root から見た相対パス。
/// - `resolution`: ページプレビューの解像度表示。
/// - `isSelected`: 対象ページが選択中か。
/// - `maxTextWidth`: ページ幅に応じたテキスト最大幅。
private struct CanvasPageNameCard: View {
    var title: String
    var placementName: String?
    var path: String
    var resolution: String
    var isSelected: Bool
    var maxTextWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(detailText)
                .font(.caption2.monospaced())
                .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
            .frame(maxWidth: maxTextWidth, alignment: .leading)
            .padding(.horizontal, CanvasMetrics.pageNameCardHorizontalInset)
            .frame(height: CanvasMetrics.pageNameCardHeight)
            .background(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .stroke(Color(nsColor: .separatorColor).opacity(isSelected ? 0 : 0.7), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
            .help("\(title) · \(detailText)")
            .accessibilityLabel("\(title), \(detailText)")
    }

    private var detailText: String {
        CanvasPageNameCardDetailResolver.detailText(
            placementName: placementName,
            path: path,
            resolution: resolution
        )
    }
}

/// 論理名（日本語）: キャンバス参照視覚レイアウト
/// 概要: 参照元nodeの実測border boxを縦横比どおり縮小し、Canvas上で実際に占有する寸法を保持します。
///
/// プロパティ:
/// - `sourceSize`: WebKitが実測した参照元nodeのborder box寸法。
/// - `fitBounds`: `.ogp`の`width` / `height`が定める最大表示領域。
/// - `scale`: 参照元を拡大せずfit bounds内へ収める等倍以下の共通倍率。
/// - `renderedSize`: editor由来の余白を含まない縮小後の表示寸法。
struct CanvasReferenceVisualLayout: Equatable {
    var sourceSize: CGSize
    var fitBounds: CGSize
    var scale: CGFloat
    var renderedSize: CGSize
}

/// 論理名（日本語）: キャンバス参照視覚レイアウト解決器
/// 概要: 参照元nodeを歪めず、切らず、拡大せずに最大表示領域へ収め、カード本体を対象nodeの縮小後実寸へ一致させます。
///
/// 定義内容:
/// - `layout(sourceSize:fitBounds:)`: 参照元実寸と最大表示領域から共通倍率と縮小後実寸を返す。
/// - `resolutionLabel(for:)`: 縮小後のカード本体寸法を情報カード用文字列へ変換する。
enum CanvasReferenceVisualLayoutResolver {
    /// 論理名（日本語）: キャンバス参照視覚レイアウト生成関数
    /// 処理概要: width / heightの小さい倍率を両軸へ等しく適用し、未使用軸の余りをカード本体へ含めない寸法を返します。
    ///
    /// - Parameters:
    ///   - sourceSize: WebKitが実測した参照元nodeのborder box寸法。
    ///   - fitBounds: `.ogp`が定める最大表示幅と高さ。
    /// - Returns: 有効寸法から解決した視覚レイアウト。不正寸法の場合は`nil`。
    static func layout(
        sourceSize: CGSize,
        fitBounds: CGSize
    ) -> CanvasReferenceVisualLayout? {
        guard sourceSize.width.isFinite,
              sourceSize.height.isFinite,
              fitBounds.width.isFinite,
              fitBounds.height.isFinite,
              sourceSize.width > 0,
              sourceSize.height > 0,
              fitBounds.width > 0,
              fitBounds.height > 0
        else {
            return nil
        }

        let scale = min(
            1,
            fitBounds.width / sourceSize.width,
            fitBounds.height / sourceSize.height
        )
        guard scale.isFinite, scale > 0 else { return nil }

        return CanvasReferenceVisualLayout(
            sourceSize: sourceSize,
            fitBounds: fitBounds,
            scale: scale,
            renderedSize: CGSize(
                width: min(sourceSize.width * scale, fitBounds.width),
                height: min(sourceSize.height * scale, fitBounds.height)
            )
        )
    }

    /// 論理名（日本語）: キャンバス参照表示寸法ラベル生成関数
    /// 処理概要: 実際のカード本体寸法を整数優先、小数1桁までの短い解像度表記へ変換します。
    ///
    /// - Parameter size: Canvas上で参照本体が実際に占有する寸法。
    /// - Returns: `幅 x 高さ`形式の表示文字列。
    static func resolutionLabel(for size: CGSize) -> String {
        "\(displayValue(size.width)) x \(displayValue(size.height))"
    }

    /// 論理名（日本語）: キャンバス参照寸法表示関数
    /// 処理概要: 寸法値を整数優先、小数1桁までの短いUI文字列へ変換します。
    ///
    /// - Parameter value: 表示対象の寸法値。
    /// - Returns: 整数に近い値は整数、それ以外は小数1桁の文字列。
    private static func displayValue(_ value: CGFloat) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", Double(value))
    }
}

/// 論理名（日本語）: キャンバス情報カード詳細解決器
/// 概要: 通常pageと参照viewportの左上カードに表示する詳細行を同じ順序で構成します。
enum CanvasPageNameCardDetailResolver {
    /// 論理名（日本語）: キャンバス情報カード詳細生成関数
    /// 処理概要: 配置種別または配置名、HTML path、viewport解像度を空値を除いて連結します。
    ///
    /// - Parameters:
    ///   - placementName: 通常pageの配置名または参照viewportを表すラベル。
    ///   - path: HTML rootから見た参照元path。
    ///   - resolution: viewportの解像度表示。
    /// - Returns: 左上情報カードの詳細行。
    static func detailText(placementName: String?, path: String, resolution: String) -> String {
        ([placementName, path, resolution].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }).joined(separator: " · ")
    }
}

/// 論理名（日本語）: キャンバスプロジェクト境界
/// 概要: 選択 Chapter / Collection 内のページ、参照オブジェクト、`.ogp` 注釈を含むworld矩形を計算します。
///
/// プロパティ:
/// - `minX`: 最小 X 座標。
/// - `minY`: 最小 Y 座標。
/// - `width`: 表示対象ページを含む幅。
/// - `height`: 表示対象ページを含む高さ。
/// - `origin`: document 座標へ写すときの canvas 原点。
struct CanvasProjectBounds {
    var minX: CGFloat
    var minY: CGFloat
    var width: CGFloat
    var height: CGFloat

    /// document 座標へ写すときの canvas 原点。
    var origin: CGPoint {
        CGPoint(x: minX, y: minY)
    }

    /// 論理名（日本語）: キャンバスプロジェクト境界初期化関数
    /// 処理概要: ページ、参照 viewport、注釈の world 矩形を union し、Canvas 表示範囲を計算します。
    ///
    /// - Parameters:
    ///   - pages: 境界計算対象のページ一覧。
    ///   - annotations: 境界計算対象の `.ogp` 注釈一覧。
    ///   - references: 境界計算対象の `.ogp` Canvas Object Reference 一覧。
    ///   - interactionMargin: 空き領域操作のために world 矩形の外側へ加える余白。
    init(
        pages: [OpenGraphitePage],
        annotations: [OpenGraphiteCanvasAnnotation] = [],
        references: [OpenGraphiteCanvasReference] = [],
        interactionMargin: CGFloat = 0
    ) {
        let margin = interactionMargin.isFinite ? max(interactionMargin, 0) : 0
        guard !pages.isEmpty || !annotations.isEmpty || !references.isEmpty else {
            minX = -margin
            minY = -margin
            width = 1440 + margin * 2
            height = 1200 + margin * 2
            return
        }

        let worldMinX = pages.map { CGFloat($0.canvas.x) }
            + annotations.map { CGFloat($0.frame.x) }
            + references.map { CGFloat($0.x) }
        let worldMinY = pages.map { CGFloat($0.canvas.y) }
            + annotations.map { CGFloat($0.frame.y) }
            + references.map { CGFloat($0.y) }
        let minX = min(worldMinX.min() ?? 0, 0)
        let minY = min(worldMinY.min() ?? 0, 0)
        let pageMaxX = pages.map { page in
            CGFloat(page.canvas.x) + CanvasPageVisualLayout.resolve(
                pageWidth: CGFloat(page.canvas.width),
                pageHeight: CGFloat(page.canvas.height)
            ).documentSize.width
        }.max() ?? 1
        let annotationMaxX = annotations.map { CGFloat($0.frame.x + $0.frame.width) }.max() ?? 1
        let referenceMaxX = references.map { reference in
            CGFloat(reference.x) + CanvasPageVisualLayout.resolve(
                pageWidth: CGFloat(reference.width),
                pageHeight: CGFloat(reference.height)
            ).documentSize.width
        }.max() ?? 1
        let pageMaxY = pages.map { CGFloat($0.canvas.y + $0.canvas.height) }.max() ?? 1
        let annotationMaxY = annotations.map { CGFloat($0.frame.y + $0.frame.height) }.max() ?? 1
        let referenceMaxY = references.map { CGFloat($0.y + $0.height) }.max() ?? 1
        let maxX = max(max(pageMaxX, annotationMaxX), referenceMaxX)
        let maxY = max(max(pageMaxY, annotationMaxY), referenceMaxY)

        self.minX = minX - margin
        self.minY = minY - margin
        self.width = max(maxX - minX + margin * 2, 1)
        self.height = max(maxY - minY + margin * 2, 1)
    }
}

/// 論理名（日本語）: キャンバスページ視覚レイアウト
/// 概要: page 本体と左上キャプションカードを含む、ヒットテスト可能な document frame を計算します。
///
/// プロパティ:
/// - `documentSize`: キャプションカードと page 本体を内包する view 全体サイズ。
/// - `pageBodyFrame`: document 内で page 本体を置く矩形。
/// - `captionHitFrame`: document 内でキャプションカードがドラッグ開始を受ける矩形。
/// - `captionTextWidth`: キャプションカード内テキストの最大幅。
struct CanvasPageVisualLayout: Equatable {
    let documentSize: CGSize
    let pageBodyFrame: CGRect
    let captionHitFrame: CGRect
    let captionTextWidth: CGFloat

    /// 論理名（日本語）: ページ視覚レイアウト解決関数
    /// 処理概要: page canvas サイズから、キャプションカードを含む document frame と page 本体位置を算出します。
    ///
    /// - Parameters:
    ///   - pageWidth: page canvas の幅。
    ///   - pageHeight: page canvas の高さ。
    /// - Returns: キャプションカードと page 本体の表示矩形。
    static func resolve(pageWidth: CGFloat, pageHeight: CGFloat) -> CanvasPageVisualLayout {
        let normalizedWidth = max(pageWidth, 1)
        let normalizedHeight = max(pageHeight, 1)
        let captionTextWidth = max(
            min(normalizedWidth, CanvasMetrics.pageNameCardMaxTextWidth),
            CanvasMetrics.pageNameCardMinTextWidth
        )
        let captionWidth = captionTextWidth + CanvasMetrics.pageNameCardHorizontalInset * 2
        let pageBodyFrame = CGRect(
            x: 0,
            y: CanvasMetrics.pageNameCardOutsideOffset,
            width: normalizedWidth,
            height: normalizedHeight
        )
        let captionHitFrame = CGRect(
            x: 0,
            y: 0,
            width: captionWidth,
            height: CanvasMetrics.pageNameCardHeight
        )
        return CanvasPageVisualLayout(
            documentSize: CGSize(
                width: max(normalizedWidth, captionWidth),
                height: normalizedHeight + CanvasMetrics.pageNameCardOutsideOffset
            ),
            pageBodyFrame: pageBodyFrame,
            captionHitFrame: captionHitFrame,
            captionTextWidth: captionTextWidth
        )
    }
}

/// 論理名（日本語）: キャンバスメトリクス
/// 概要: キャンバス表示で共有する余白などの静的寸法をまとめます。
///
/// 定義内容:
/// - `documentPadding`: ドキュメント周囲の余白。
/// - `pageNameCardHeight`: ページ名カードの固定高さ。
/// - `pageNameCardGap`: ページ枠とページ名カードの間隔。
/// - `pageNameCardHorizontalInset`: ページ名カード内の水平余白。
/// - `pageNameCardMinTextWidth`: ページ名カードの最小テキスト幅。
/// - `pageNameCardMaxTextWidth`: ページ名カードの最大テキスト幅。
/// - `pageNameCardOutsideOffset`: ページ名カードをページ枠外へ出す垂直オフセット。
/// - `pageDragMinimumDistance`: キャプションカードのドラッグ開始距離。
enum CanvasMetrics {
    static let documentPadding: CGFloat = 72
    static let projectCoordinateSpaceName = "OpenGraphiteCanvasProject"
    static let pageNameCardHeight: CGFloat = 44
    static let pageNameCardGap: CGFloat = 8
    static let pageNameCardHorizontalInset: CGFloat = 10
    static let pageNameCardMinTextWidth: CGFloat = 176
    static let pageNameCardMaxTextWidth: CGFloat = 280
    static let pageNameCardOutsideOffset = pageNameCardHeight + pageNameCardGap
    static let pageDragMinimumDistance: CGFloat = 2
    static let annotationInteractionMargin: CGFloat = 640
}

/// 論理名（日本語）: キャンバスページドラッグ解決器
/// 概要: 画面上のドラッグ量を OpenGraphite canvas 座標の移動量と確定位置へ変換します。
///
/// 定義内容:
/// - `canvasTranslation(screenTranslation:zoom:)`: 画面座標のドラッグ量を canvas 座標の移動量へ変換します。
/// - `finalizedPosition(for:screenTranslation:zoom:)`: ドラッグ終了時に保存する canvas 位置を算出します。
enum CanvasPageDragResolver {
    /// 論理名（日本語）: キャンバスドラッグ量変換関数
    /// 処理概要: ズーム適用後の画面上の移動量を、未拡大の canvas 座標系の移動量へ戻します。
    ///
    /// - Parameters:
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: canvas 座標系での移動量。倍率や移動量が不正な場合は `.zero`。
    static func canvasTranslation(screenTranslation: CGSize, zoom: Double) -> CGSize {
        normalizedCanvasTranslation(screenTranslation: screenTranslation, zoom: zoom) ?? .zero
    }

    /// 論理名（日本語）: ドラッグ確定位置算出関数
    /// 処理概要: 元の canvas 位置へドラッグ量を加算し、manifest に保存しやすい整数座標へ丸めます。
    ///
    /// - Parameters:
    ///   - canvas: ドラッグ開始時の page canvas 定義。
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: 保存対象の canvas 左上座標。
    static func finalizedPosition(for canvas: OpenGraphiteCanvas, screenTranslation: CGSize, zoom: Double) -> CGPoint {
        guard let translation = normalizedCanvasTranslation(screenTranslation: screenTranslation, zoom: zoom) else {
            return CGPoint(x: CGFloat(canvas.x), y: CGFloat(canvas.y))
        }

        return CGPoint(
            x: (CGFloat(canvas.x) + translation.width).rounded(),
            y: (CGFloat(canvas.y) + translation.height).rounded()
        )
    }

    /// 論理名（日本語）: 正規化済みキャンバスドラッグ量生成関数
    /// 処理概要: 不正な倍率や無限値を除外し、有効な場合だけ canvas 座標系の移動量を返します。
    ///
    /// - Parameters:
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: 有効な canvas 移動量。変換できない場合は `nil`。
    private static func normalizedCanvasTranslation(screenTranslation: CGSize, zoom: Double) -> CGSize? {
        guard zoom.isFinite, zoom > 0,
              screenTranslation.width.isFinite,
              screenTranslation.height.isFinite
        else {
            return nil
        }

        let scale = CGFloat(zoom)
        return CGSize(
            width: screenTranslation.width / scale,
            height: screenTranslation.height / scale
        )
    }
}

/// 論理名（日本語）: キャンバスページリサイズ解決器
/// 概要: ページ枠ハンドルの画面ドラッグ量を `.ogp` の canvas 座標と解像度へ変換します。
///
/// 定義内容:
/// - `resizedCanvas(for:handle:screenTranslation:zoom:)`: ドラッグ後に保存する page canvas 定義を生成します。
/// - `resizedRect(startRect:handle:screenTranslation:zoom:)`: ドラッグ後の canvas 矩形を算出します。
enum CanvasPageResizeResolver {
    static let minimumSize: CGFloat = 2

    /// 論理名（日本語）: リサイズ後Canvas生成関数
    /// 処理概要: 既存の配置名と preview Mock State を保持し、リサイズ後の座標と寸法だけを更新します。
    ///
    /// - Parameters:
    ///   - canvas: ドラッグ開始時の page canvas 定義。
    ///   - handle: 操作中のリサイズハンドル。
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: リサイズ後の page canvas 定義。
    static func resizedCanvas(
        for canvas: OpenGraphiteCanvas,
        handle: CanvasNodeResizeHandle,
        screenTranslation: CGSize,
        zoom: Double
    ) -> OpenGraphiteCanvas {
        let rect = resizedRect(
            startRect: CGRect(
                x: CGFloat(canvas.x),
                y: CGFloat(canvas.y),
                width: CGFloat(canvas.width),
                height: CGFloat(canvas.height)
            ),
            handle: handle,
            screenTranslation: screenTranslation,
            zoom: zoom
        )
        return OpenGraphiteCanvas(
            name: canvas.name,
            x: Double(rect.minX),
            y: Double(rect.minY),
            width: Double(rect.width),
            height: Double(rect.height),
            previewContext: canvas.previewContext
        )
    }

    /// 論理名（日本語）: リサイズ後矩形生成関数
    /// 処理概要: ズーム適用後の画面ドラッグ量を canvas 座標へ戻し、操作辺と最小サイズから page 矩形を補正します。
    ///
    /// - Parameters:
    ///   - startRect: ドラッグ開始時の canvas 座標上の page 矩形。
    ///   - handle: 操作中のリサイズハンドル。
    ///   - screenTranslation: `DragGesture` が返す画面上の移動量。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: 補正済みの page canvas 矩形。
    static func resizedRect(
        startRect: CGRect,
        handle: CanvasNodeResizeHandle,
        screenTranslation: CGSize,
        zoom: Double
    ) -> CGRect {
        let normalizedStartRect = normalizedRect(startRect)
        let translation = CanvasPageDragResolver.canvasTranslation(
            screenTranslation: screenTranslation,
            zoom: zoom
        )
        var minX = normalizedStartRect.minX
        var maxX = normalizedStartRect.maxX
        var minY = normalizedStartRect.minY
        var maxY = normalizedStartRect.maxY

        if handle.horizontalDirection < 0 {
            minX = min(normalizedStartRect.minX + translation.width, normalizedStartRect.maxX - minimumSize)
        } else if handle.horizontalDirection > 0 {
            maxX = max(normalizedStartRect.maxX + translation.width, normalizedStartRect.minX + minimumSize)
        }

        if handle.verticalDirection < 0 {
            minY = min(normalizedStartRect.minY + translation.height, normalizedStartRect.maxY - minimumSize)
        } else if handle.verticalDirection > 0 {
            maxY = max(normalizedStartRect.maxY + translation.height, normalizedStartRect.minY + minimumSize)
        }

        return CGRect(
            x: minX.rounded(),
            y: minY.rounded(),
            width: max((maxX - minX).rounded(), minimumSize),
            height: max((maxY - minY).rounded(), minimumSize)
        )
    }

    /// 論理名（日本語）: 正規化矩形生成関数
    /// 処理概要: 不正な矩形値を避け、最小サイズ以上の canvas 矩形へ補正します。
    ///
    /// - Parameter rect: ドラッグ開始時の page 矩形。
    /// - Returns: リサイズ計算に使える矩形。
    private static func normalizedRect(_ rect: CGRect) -> CGRect {
        guard rect.minX.isFinite,
              rect.minY.isFinite,
              rect.width.isFinite,
              rect.height.isFinite
        else {
            return CGRect(x: 0, y: 0, width: minimumSize, height: minimumSize)
        }
        return CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.width, minimumSize),
            height: max(rect.height, minimumSize)
        )
    }
}

/// 論理名（日本語）: キャンバスオーバーレイ回避値
/// 概要: Canvas の描画座標を保ったまま操作 UI だけ左右カラムを避けるための余白です。
///
/// プロパティ:
/// - `leading`: 左カラムに隠れないための左側回避幅。
/// - `trailing`: 右カラムに隠れないための右側回避幅。
/// - `top`: 上部クロームに隠れないための上側回避幅。
struct CanvasOverlayAvoidance: Equatable {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
    var top: CGFloat = 0
}

/// 論理名（日本語）: キャンバス入力領域ポリシー
/// 概要: 全面配置された Canvas scroll view のうち、左右カラムと上部クロームに覆われない入力可能領域を判定します。
///
/// 定義内容:
/// - `isPointInActiveCanvasRegion(_:bounds:overlayAvoidance:isFlipped:)`: window 入力座標を scroll view 内の有効 Canvas 領域へ限定します。
enum CanvasInputRegionPolicy {
    /// 論理名（日本語）: 有効キャンバス入力領域判定関数
    /// 処理概要: scroll view の bounds から overlay avoidance 分を除いた矩形を作り、入力点がその内側にあるかを返します。
    ///
    /// - Parameters:
    ///   - point: scroll view 座標へ変換済みの入力点。
    ///   - bounds: scroll view の bounds。
    ///   - overlayAvoidance: Sidebar、Inspector、上部クロームを避ける幅。
    ///   - isFlipped: scroll view 座標系が flipped か。
    /// - Returns: 入力点が中央の有効 Canvas 領域にある場合は `true`。
    static func isPointInActiveCanvasRegion(
        _ point: CGPoint,
        bounds: CGRect,
        overlayAvoidance: CanvasOverlayAvoidance,
        isFlipped: Bool
    ) -> Bool {
        guard bounds.width > 0,
              bounds.height > 0,
              bounds.contains(point)
        else {
            return false
        }

        let leading = sanitizedInset(overlayAvoidance.leading, maximum: bounds.width)
        let trailing = sanitizedInset(overlayAvoidance.trailing, maximum: bounds.width)
        let top = sanitizedInset(overlayAvoidance.top, maximum: bounds.height)
        let minX = bounds.minX + leading
        let maxX = bounds.maxX - trailing
        let minY: CGFloat
        let maxY: CGFloat
        if isFlipped {
            minY = bounds.minY + top
            maxY = bounds.maxY
        } else {
            minY = bounds.minY
            maxY = bounds.maxY - top
        }

        guard minX < maxX, minY < maxY else { return false }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        ).contains(point)
    }

    /// 論理名（日本語）: 入力領域余白正規化関数
    /// 処理概要: 不正値や負値を 0 にし、対象 bounds の長さを超えない値へ丸めます。
    ///
    /// - Parameters:
    ///   - value: 正規化前の余白値。
    ///   - maximum: 対象軸の最大長。
    /// - Returns: 入力領域計算に使える余白値。
    private static func sanitizedInset(_ value: CGFloat, maximum: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, max(maximum, 0))
    }
}

/// 論理名（日本語）: キャンバスズーム設定
/// 概要: キャンバス倍率の範囲、ボタン単位、表示文字列生成をまとめます。
///
/// 定義内容:
/// - `range`: 許容ズーム範囲。
/// - `buttonStep`: HUD ボタンのズーム差分。
/// - `originalScale`: Focus対象を原寸表示する100%倍率。
enum CanvasZoom {
    static let range: ClosedRange<Double> = 0.10...2.0
    static let buttonStep = 0.1
    static let originalScale = 1.0

    /// 論理名（日本語）: ズーム範囲補正関数
    /// 処理概要: 任意の倍率を OpenGraphite が許可する範囲に丸めます。
    ///
    /// - Parameter value: 補正前の倍率。
    /// - Returns: 許容範囲内へ補正された倍率。
    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// 論理名（日本語）: ズーム段階調整関数
    /// 処理概要: HUDの増減を許容範囲へ補正し、100%を跨ぐ操作では原寸倍率へ一度スナップします。
    ///
    /// - Parameters:
    ///   - value: 調整前の倍率。
    ///   - delta: HUD操作で加える倍率差分。
    /// - Returns: 許容範囲内で、必要に応じて100%へスナップした倍率。
    static func stepped(_ value: Double, by delta: Double) -> Double {
        let currentZoom = clamped(value)
        let nextZoom = clamped(currentZoom + delta)
        if currentZoom < originalScale, nextZoom > originalScale {
            return originalScale
        }
        if currentZoom > originalScale, nextZoom < originalScale {
            return originalScale
        }
        return nextZoom
    }

    /// 論理名（日本語）: ズームパーセント文字列生成関数
    /// 処理概要: 倍率を UI 表示用の百分率文字列に変換します。
    ///
    /// - Parameter zoom: 表示する倍率。
    /// - Returns: `100%` 形式の文字列。
    static func percent(_ zoom: Double) -> String {
        "\(Int((zoom * 100).rounded()))%"
    }
}

/// 論理名（日本語）: キャンバスZoom入力
/// 概要: Commandスクロールまたはピンチ由来の、表示方式に依存しないZoom入力を表します。
enum CanvasZoomInput: Equatable {
    case commandScroll(delta: CGFloat, isPrecise: Bool)
    case magnification(CGFloat)
}

/// 論理名（日本語）: キャンバスZoom入力解決器
/// 概要: 通常canvasとFocus表示で共有する入力イベント判定、差分選択、倍率計算を定義します。
///
/// 定義内容:
/// - `eventMask`: 共通して監視するAppKitイベント種別。
/// - `input(for:)`: AppKitイベントを共通Zoom入力へ変換する。
/// - `scrollDelta(...)`: preciseまたはlegacyの有効な垂直差分を返す。
/// - `scaleFactor(for:isPrecise:)`: scroll差分を現在倍率へ掛ける指数係数へ変換する。
/// - `targetZoom(currentZoom:input:)`: 入力を現在倍率へ適用し、許容範囲内の倍率を返す。
enum CanvasZoomInputResolver {
    /// 通常canvasとFocus表示で共通して監視するAppKitイベントです。
    static let eventMask: NSEvent.EventTypeMask = [.scrollWheel, .magnify, .gesture]

    /// 論理名（日本語）: AppKitイベントZoom入力変換関数
    /// 処理概要: Commandスクロール、trackpad pinch、互換gestureを共通Zoom入力へ変換します。
    ///
    /// - Parameter event: 変換するAppKitイベント。
    /// - Returns: Zoom入力として扱える場合は共通入力。通常scrollなどでは`nil`。
    static func input(for event: NSEvent) -> CanvasZoomInput? {
        switch event.type {
        case .scrollWheel:
            guard event.modifierFlags.contains(.command) else { return nil }
            let delta = scrollDelta(
                precise: event.scrollingDeltaY,
                legacy: event.deltaY,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
            )
            guard delta.value != 0 else { return nil }
            return .commandScroll(delta: delta.value, isPrecise: delta.isPrecise)
        case .magnify:
            return .magnification(event.magnification)
        case .gesture:
            guard let cgEvent = event.cgEvent,
                  let subtypeField = CGEventField(rawValue: 110),
                  let magnificationField = CGEventField(rawValue: 113),
                  cgEvent.getIntegerValueField(subtypeField) == 8
            else {
                return nil
            }
            return .magnification(CGFloat(cgEvent.getDoubleValueField(magnificationField)))
        default:
            return nil
        }
    }

    /// 論理名（日本語）: Commandスクロール差分選択関数
    /// 処理概要: precise deltaが有効なら優先し、値がなければlegacy deltaへfallbackします。
    ///
    /// - Parameters:
    ///   - precise: trackpadなどのprecise垂直差分。
    ///   - legacy: mouse wheelなどのlegacy垂直差分。
    ///   - hasPreciseScrollingDeltas: precise差分を持つイベントか。
    /// - Returns: 採用した差分値とprecise判定。
    static func scrollDelta(
        precise: CGFloat,
        legacy: CGFloat,
        hasPreciseScrollingDeltas: Bool
    ) -> (value: CGFloat, isPrecise: Bool) {
        if hasPreciseScrollingDeltas, precise != 0 {
            return (precise, true)
        }
        if legacy != 0 {
            return (legacy, false)
        }
        return (precise, hasPreciseScrollingDeltas)
    }

    /// 論理名（日本語）: CommandスクロールZoom係数生成関数
    /// 処理概要: scroll差分を指数関数の倍率係数へ変換し、小さなprecise入力も連続的に反映します。
    ///
    /// - Parameters:
    ///   - rawDelta: 採用した垂直scroll差分。
    ///   - isPrecise: precise delta由来か。
    /// - Returns: 現在Zoomへ掛ける倍率係数。
    static func scaleFactor(for rawDelta: CGFloat, isPrecise: Bool) -> Double {
        exp(Double(rawDelta) * (isPrecise ? 0.002 : 0.08))
    }

    /// 論理名（日本語）: Zoom入力適用関数
    /// 処理概要: Commandスクロールとピンチを同じ倍率更新経路へ通し、canvasの許容範囲へ補正します。
    ///
    /// - Parameters:
    ///   - currentZoom: 入力適用前のZoom倍率。
    ///   - input: 適用する共通Zoom入力。
    /// - Returns: 入力適用後のZoom倍率。
    static func targetZoom(currentZoom: Double, input: CanvasZoomInput) -> Double {
        let currentZoom = CanvasZoom.clamped(currentZoom)
        let target: Double
        switch input {
        case .commandScroll(let delta, let isPrecise):
            target = currentZoom * scaleFactor(for: delta, isPrecise: isPrecise)
        case .magnification(let magnification):
            target = currentZoom * (1 + Double(magnification))
        }
        guard target.isFinite else { return currentZoom }
        return CanvasZoom.clamped(target)
    }
}

/// 論理名（日本語）: キャンバスズーム基準点スナップショット
/// 概要: ズーム前に画面上の基準点と対応するキャンバス内容座標を保存します。
///
/// プロパティ:
/// - `viewportPoint`: viewport 左上から見た画面上の基準点。
/// - `unscaledContentPoint`: ズームを除いたキャンバス内容上の基準点。
struct CanvasZoomAnchorSnapshot: Equatable {
    var viewportPoint: CGPoint
    var unscaledContentPoint: CGPoint
}

/// 論理名（日本語）: キャンバスズーム基準点解決器
/// 概要: ズーム前の基準点を保存し、ズーム後に必要な scroll origin を計算します。
///
/// 定義内容:
/// - `snapshot(...)`: ズーム前の基準点を保存する。
/// - `documentOrigin(...)`: ズーム後の scroll origin を算出する。
/// - `clampedDocumentOrigin(...)`: scroll origin を documentView 内へ制限する。
enum CanvasZoomAnchorResolver {
    /// 論理名（日本語）: viewport基準点変換関数
    /// 処理概要: clip view座標の点を、表示中viewport左上からの相対位置へ変換して範囲内へ丸めます。
    ///
    /// - Parameters:
    ///   - point: clip view座標の入力位置。
    ///   - visibleRect: 現在表示中のclip view bounds。
    /// - Returns: viewport左上を原点とする範囲内の基準点。
    static func viewportPoint(_ point: CGPoint, visibleRect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x - visibleRect.minX, 0), visibleRect.width),
            y: min(max(point.y - visibleRect.minY, 0), visibleRect.height)
        )
    }

    /// 論理名（日本語）: ズーム基準点保存関数
    /// 処理概要: viewport 上の点を、現在の表示倍率を除いたキャンバス内容座標へ変換します。
    ///
    /// - Parameters:
    ///   - viewportPoint: viewport 左上から見た画面上の基準点。
    ///   - visibleOrigin: 現在の clip view 表示原点。
    ///   - hostingOrigin: documentView 内の hosting view 原点。
    ///   - renderedZoom: 現在描画されているキャンバス倍率。
    ///   - contentPadding: hosting view 内でキャンバス周囲に置かれる固定余白。
    /// - Returns: ズーム後の scroll origin 計算に使う基準点。倍率が無効な場合は `nil`。
    static func snapshot(
        viewportPoint: CGPoint,
        visibleOrigin: CGPoint,
        hostingOrigin: CGPoint,
        renderedZoom: Double,
        contentPadding: CGFloat
    ) -> CanvasZoomAnchorSnapshot? {
        guard renderedZoom.isFinite, renderedZoom > 0 else { return nil }

        let anchorDocumentPoint = CGPoint(
            x: visibleOrigin.x + viewportPoint.x,
            y: visibleOrigin.y + viewportPoint.y
        )
        let scaledContentPoint = CGPoint(
            x: anchorDocumentPoint.x - hostingOrigin.x - contentPadding,
            y: anchorDocumentPoint.y - hostingOrigin.y - contentPadding
        )
        return CanvasZoomAnchorSnapshot(
            viewportPoint: viewportPoint,
            unscaledContentPoint: CGPoint(
                x: scaledContentPoint.x / CGFloat(renderedZoom),
                y: scaledContentPoint.y / CGFloat(renderedZoom)
            )
        )
    }

    /// 論理名（日本語）: ズーム後ドキュメント原点計算関数
    /// 処理概要: 保存した基準点がズーム後も同じ viewport 位置へ来るように clip origin を計算します。
    ///
    /// - Parameters:
    ///   - snapshot: ズーム前に保存した基準点。
    ///   - hostingOrigin: documentView 内の hosting view 原点。
    ///   - targetZoom: ズーム後のキャンバス倍率。
    ///   - contentPadding: hosting view 内でキャンバス周囲に置かれる固定余白。
    ///   - documentSize: documentView の現在サイズ。
    ///   - viewportSize: clip view の表示サイズ。
    /// - Returns: documentView 内に収まるよう補正した clip origin。倍率が無効な場合は `nil`。
    static func documentOrigin(
        for snapshot: CanvasZoomAnchorSnapshot,
        hostingOrigin: CGPoint,
        targetZoom: Double,
        contentPadding: CGFloat,
        documentSize: CGSize,
        viewportSize: CGSize
    ) -> CGPoint? {
        guard targetZoom.isFinite, targetZoom > 0 else { return nil }

        let anchorDocumentPoint = CGPoint(
            x: hostingOrigin.x + contentPadding + snapshot.unscaledContentPoint.x * CGFloat(targetZoom),
            y: hostingOrigin.y + contentPadding + snapshot.unscaledContentPoint.y * CGFloat(targetZoom)
        )
        return clampedDocumentOrigin(
            CGPoint(
                x: anchorDocumentPoint.x - snapshot.viewportPoint.x,
                y: anchorDocumentPoint.y - snapshot.viewportPoint.y
            ),
            documentSize: documentSize,
            viewportSize: viewportSize
        )
    }

    /// 論理名（日本語）: ドキュメント原点補正関数
    /// 処理概要: clip origin を documentView のスクロール可能範囲内へ丸めます。
    ///
    /// - Parameters:
    ///   - origin: 補正前の clip origin。
    ///   - documentSize: documentView の現在サイズ。
    ///   - viewportSize: clip view の表示サイズ。
    /// - Returns: スクロール可能範囲内へ補正した clip origin。
    static func clampedDocumentOrigin(
        _ origin: CGPoint,
        documentSize: CGSize,
        viewportSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, 0), max(documentSize.width - viewportSize.width, 0)),
            y: min(max(origin.y, 0), max(documentSize.height - viewportSize.height, 0))
        )
    }
}

/// 論理名（日本語）: キャンバス原点変化補正解決器
/// 概要: canvas bounds の原点が変化したとき、同じ表示領域を保つための scroll origin 補正量を計算します。
///
/// 定義内容:
/// - `scrollAdjustment(previousOrigin:newOrigin:zoom:)`: bounds 原点差分を document 座標の scroll 補正量へ変換します。
enum CanvasViewportOriginAdjustmentResolver {
    /// 論理名（日本語）: スクロール補正量算出関数
    /// 処理概要: 旧 canvas 原点と新 canvas 原点の差分に現在倍率を掛け、clip origin に加算する補正量を返します。
    ///
    /// - Parameters:
    ///   - previousOrigin: 更新前の canvas bounds 原点。
    ///   - newOrigin: 更新後の canvas bounds 原点。
    ///   - zoom: 現在の canvas 表示倍率。
    /// - Returns: document 座標上の scroll origin 補正量。不正な倍率や値の場合は `.zero`。
    static func scrollAdjustment(previousOrigin: CGPoint, newOrigin: CGPoint, zoom: Double) -> CGPoint {
        guard zoom.isFinite, zoom > 0 else { return .zero }

        let adjustment = CGPoint(
            x: (previousOrigin.x - newOrigin.x) * CGFloat(zoom),
            y: (previousOrigin.y - newOrigin.y) * CGFloat(zoom)
        )
        guard adjustment.x.isFinite, adjustment.y.isFinite else { return .zero }
        return adjustment
    }
}

/// 論理名（日本語）: キャンバスズームHUD
/// 概要: キャンバス右下に現在倍率とズームイン/アウトボタンを表示します。
///
/// プロパティ:
/// - `zoom`: 現在倍率。
/// - `canZoomOut`: 縮小操作が可能か。
/// - `canZoomIn`: 拡大操作が可能か。
/// - `onZoomOut`: 縮小ボタン押下時の処理。
/// - `onZoomIn`: 拡大ボタン押下時の処理。
private struct CanvasZoomHUD: View {
    var zoom: Double
    var canZoomOut: Bool
    var canZoomIn: Bool
    var onZoomOut: () -> Void
    var onZoomIn: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onZoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .disabled(!canZoomOut)
            .buttonStyle(.plain)
            .help("Zoom Out")

            Text(CanvasZoom.percent(zoom))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .frame(minWidth: 46)
                .contentTransition(.numericText(value: zoom))

            Button(action: onZoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .disabled(!canZoomIn)
            .buttonStyle(.plain)
            .help("Zoom In")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zoom \(CanvasZoom.percent(zoom))")
    }
}

/// 論理名（日本語）: キャンバスゼロセーフエリアホスティングビュー
/// 概要: AppKit scroll view 内の SwiftUI canvas content が window 上端の safe area を再適用しないようにします。
///
/// プロパティ:
/// - `safeAreaInsets`: canvas content の左上を hosting view の実座標原点へ一致させるゼロ余白。
final class CanvasZeroSafeAreaHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

/// 論理名（日本語）: フォーカス有限スクロールビュー
/// 概要: Zoom適用後のFocus対象だけを載せた有限documentをAppKit scroll viewで表示し、初期位置を対象中心へ合わせます。
///
/// プロパティ:
/// - `zoom`: 通常canvasと共有するZoom倍率。
/// - `documentID`: フォーカス対象を識別し、変更時だけ中央へ戻すID。
/// - `contentSize`: Zoom適用後のFocus対象寸法。
/// - `content`: Focus対象単体のSwiftUI content。
private struct CanvasFocusedPreviewScrollView<Content: View>: NSViewRepresentable {
    @Binding var zoom: Double
    var documentID: String
    var contentSize: CGSize
    var content: () -> Content

    /// 論理名（日本語）: フォーカス有限スクロールビュー初期化関数
    /// 処理概要: 対象ID、Zoom適用後の寸法、表示contentを保持します。
    ///
    /// - Parameters:
    ///   - zoom: 通常canvasと共有するZoom倍率binding。
    ///   - documentID: フォーカス対象ID。
    ///   - contentSize: Focus対象のZoom適用後寸法。
    ///   - content: Focus対象単体のSwiftUI content。
    init(
        zoom: Binding<Double>,
        documentID: String,
        contentSize: CGSize,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _zoom = zoom
        self.documentID = documentID
        self.contentSize = contentSize
        self.content = content
    }

    /// 論理名（日本語）: フォーカススクロールコーディネーター生成関数
    /// 処理概要: SwiftUI contentと有限documentレイアウトを管理するコーディネーターを生成します。
    ///
    /// - Returns: フォーカス有限スクロール用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(
            zoom: $zoom,
            documentID: documentID,
            contentSize: contentSize,
            content: content
        )
    }

    /// 論理名（日本語）: フォーカス有限NSScrollView生成関数
    /// 処理概要: elastic overscrollを無効化した有限scroll viewへdocument viewを設定し、Zoom入力は共通monitorで処理します。
    ///
    /// - Parameter context: SwiftUI representable context。
    /// - Returns: object overflow分だけscrollできるNSScrollView。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CanvasFinitePreviewScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.allowsMagnification = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = context.coordinator.documentView
        context.coordinator.attach(to: scrollView)
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            coordinator?.refreshLayout(centerContent: true)
        }
        return scrollView
    }

    /// 論理名（日本語）: フォーカス有限NSScrollView更新関数
    /// 処理概要: 対象またはobject寸法の変更を反映し、対象変更時だけ中央表示へ戻します。
    ///
    /// - Parameters:
    ///   - scrollView: 更新対象scroll view。
    ///   - context: SwiftUI representable context。
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.zoom = $zoom
        let shouldCenter = context.coordinator.updateContent(
            documentID: documentID,
            contentSize: contentSize,
            content: content
        )
        context.coordinator.refreshLayout(centerContent: shouldCenter)
    }

    /// 論理名（日本語）: フォーカス有限NSScrollView解体関数
    /// 処理概要: viewport変更callbackを解除してretainを防ぎます。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象scroll view。
    ///   - coordinator: 紐づくコーディネーター。
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        (nsView as? CanvasFinitePreviewScrollView)?.viewportSizeDidChange = nil
        coordinator.dismantle()
    }

    /// 論理名（日本語）: フォーカス有限スクロールコーディネーター
    /// 概要: viewportとobject寸法から有限documentを更新し、対象中心へ初期scrollします。
    final class Coordinator: NSObject {
        var zoom: Binding<Double>
        let hostingView: CanvasZeroSafeAreaHostingView<Content>
        let documentView: CanvasFocusedPreviewDocumentView<Content>

        private weak var scrollView: NSScrollView?
        private var monitor: Any?
        private var renderedDocumentID: String
        private var renderedContentSize: CGSize
        private var content: () -> Content
        private var lastViewportSize = CGSize.zero
        private var lastZoom: Double
        private var lastLayout: CanvasFocusedPreviewLayout?
        private var pendingZoomAnchor: CanvasZoomAnchorSnapshot?
        private var retainedDocumentSizeDuringZoom: CGSize?
        private var zoomSettleWorkItem: DispatchWorkItem?

        /// 論理名（日本語）: フォーカス有限スクロールコーディネーター初期化関数
        /// 処理概要: 初期contentをhosting viewへ設定し、有限document viewを生成します。
        ///
        /// - Parameters:
        ///   - zoom: 通常canvasと共有するZoom倍率binding。
        ///   - documentID: 初期フォーカス対象ID。
        ///   - contentSize: 初期object寸法。
        ///   - content: 初期SwiftUI content。
        init(
            zoom: Binding<Double>,
            documentID: String,
            contentSize: CGSize,
            content: @escaping () -> Content
        ) {
            self.zoom = zoom
            self.renderedDocumentID = documentID
            self.renderedContentSize = contentSize
            self.content = content
            self.lastZoom = CanvasZoom.clamped(zoom.wrappedValue)
            self.hostingView = CanvasZeroSafeAreaHostingView(rootView: content())
            self.hostingView.isFlipped = true
            self.documentView = CanvasFocusedPreviewDocumentView(hostingView: hostingView)
        }

        /// 論理名（日本語）: フォーカスscroll view接続関数
        /// 処理概要: viewport寸法変更を受け取り、有限documentを再計算し、共通のscroll・pinch・gesture入力を監視します。
        ///
        /// - Parameter scrollView: 接続対象の有限scroll view。
        func attach(to scrollView: CanvasFinitePreviewScrollView) {
            self.scrollView = scrollView
            scrollView.viewportSizeDidChange = { [weak self] _ in
                self?.refreshLayout(centerContent: true)
            }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: CanvasZoomInputResolver.eventMask) { [weak self] event in
                guard let self, self.handleZoomInput(event) else {
                    return event
                }
                return nil
            }
        }

        /// 論理名（日本語）: フォーカスcontent更新関数
        /// 処理概要: 対象IDまたはZoom適用後寸法が変わった場合だけhosting rootを更新します。
        ///
        /// - Parameters:
        ///   - documentID: 最新フォーカス対象ID。
        ///   - contentSize: 最新のZoom適用後寸法。
        ///   - content: 最新SwiftUI content。
        /// - Returns: 新しい対象として中央へ戻す必要がある場合は `true`。
        func updateContent(
            documentID: String,
            contentSize: CGSize,
            content: @escaping () -> Content
        ) -> Bool {
            self.content = content
            let currentZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let didChangeDocument = renderedDocumentID != documentID
            let didChangeSize = renderedContentSize != contentSize
            let didChangeZoom = abs(lastZoom - currentZoom) > 0.0005
            guard didChangeDocument || didChangeSize || didChangeZoom else { return false }
            if didChangeDocument {
                pendingZoomAnchor = nil
                retainedDocumentSizeDuringZoom = nil
                cancelZoomSettle()
            } else if didChangeZoom, pendingZoomAnchor == nil {
                pendingZoomAnchor = centeredZoomAnchor(renderedZoom: lastZoom)
            }
            renderedDocumentID = documentID
            renderedContentSize = contentSize
            lastZoom = currentZoom
            hostingView.rootView = content()
            return didChangeDocument
        }

        /// 論理名（日本語）: フォーカス有限レイアウト更新関数
        /// 処理概要: viewportへ合うdocumentとobject frameを適用し、初回・対象変更・viewport変更時はobject中心へscrollします。
        ///
        /// - Parameter centerContent: 更新後にobject中心へscrollするか。
        func refreshLayout(centerContent: Bool) {
            guard let scrollView,
                  let layout = CanvasFocusedPreviewLayoutResolver.layout(
                      viewportSize: scrollView.contentSize,
                      contentSize: renderedContentSize,
                      retainedDocumentSize: retainedDocumentSizeDuringZoom
                  )
            else {
                return
            }

            let viewportChanged = lastViewportSize != scrollView.contentSize
            lastViewportSize = scrollView.contentSize
            documentView.apply(layout: layout)
            lastLayout = layout
            if retainedDocumentSizeDuringZoom != nil {
                retainedDocumentSizeDuringZoom = layout.documentSize
            }
            if let zoomAnchor = pendingZoomAnchor {
                pendingZoomAnchor = nil
                applyZoomAnchor(zoomAnchor, targetZoom: lastZoom, layout: layout)
            } else if centerContent || viewportChanged {
                scrollView.contentView.scroll(to: layout.initialScrollOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        /// 論理名（日本語）: フォーカスZoom入力処理関数
        /// 処理概要: Focus表示領域内のCommandスクロールとピンチを通常canvasと同じ解決器でZoomへ変換します。
        ///
        /// - Parameter event: 監視対象のscroll、magnify、gestureイベント。
        /// - Returns: Focus Zoomとして消費した場合は`true`。
        private func handleZoomInput(_ event: NSEvent) -> Bool {
            guard let scrollView,
                  event.window === scrollView.window,
                  scrollView.bounds.contains(scrollView.convert(event.locationInWindow, from: nil)),
                  let input = CanvasZoomInputResolver.input(for: event)
            else {
                return false
            }

            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let newZoom = CanvasZoomInputResolver.targetZoom(currentZoom: oldZoom, input: input)
            guard newZoom != oldZoom else { return true }

            retainedDocumentSizeDuringZoom = lastLayout?.documentSize
            pendingZoomAnchor = pointerZoomAnchor(for: event, renderedZoom: lastZoom)
            zoom.wrappedValue = newZoom
            scheduleFiniteDocumentSettle()
            return true
        }

        /// 論理名（日本語）: フォーカス有限document収束予約関数
        /// 処理概要: 連続Zoom中のdocument縮小を遅延し、入力が止まった後に必要なscroll範囲へ一度だけ収束させます。
        private func scheduleFiniteDocumentSettle() {
            cancelZoomSettle()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.retainedDocumentSizeDuringZoom != nil else { return }
                self.zoomSettleWorkItem = nil
                self.pendingZoomAnchor = self.centeredZoomAnchor(renderedZoom: self.lastZoom)
                self.retainedDocumentSizeDuringZoom = nil
                self.refreshLayout(centerContent: false)
            }
            zoomSettleWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + CanvasFocusedPreviewMetrics.zoomSettleDelay,
                execute: workItem
            )
        }

        /// 論理名（日本語）: フォーカス有限document収束取消関数
        /// 処理概要: 対象切替または次のZoom入力前に、予約済みの有限document縮小を取り消します。
        private func cancelZoomSettle() {
            zoomSettleWorkItem?.cancel()
            zoomSettleWorkItem = nil
        }

        /// 論理名（日本語）: フォーカスポインタZoom基準点生成関数
        /// 処理概要: Commandスクロール位置をviewport座標へ変換し、Focus対象上の未拡大座標として保存します。
        ///
        /// - Parameters:
        ///   - event: ポインタ位置を持つscroll wheelイベント。
        ///   - renderedZoom: 現在描画中のZoom倍率。
        /// - Returns: Zoom後の有限scroll原点復元に使う基準点。
        private func pointerZoomAnchor(for event: NSEvent, renderedZoom: Double) -> CanvasZoomAnchorSnapshot? {
            guard let scrollView else { return nil }
            return zoomAnchor(
                at: viewportPoint(for: event, in: scrollView),
                renderedZoom: renderedZoom,
                in: scrollView
            )
        }

        /// 論理名（日本語）: フォーカス中央Zoom基準点生成関数
        /// 処理概要: HUD操作では現在viewportの中央をFocus Zoom基準点として保存します。
        ///
        /// - Parameter renderedZoom: 現在描画中のZoom倍率。
        /// - Returns: Zoom後の有限scroll原点復元に使う基準点。
        private func centeredZoomAnchor(renderedZoom: Double) -> CanvasZoomAnchorSnapshot? {
            guard let scrollView else { return nil }
            let visibleRect = scrollView.contentView.bounds
            return zoomAnchor(
                at: CGPoint(x: visibleRect.width / 2, y: visibleRect.height / 2),
                renderedZoom: renderedZoom,
                in: scrollView
            )
        }

        /// 論理名（日本語）: フォーカスZoom基準点生成関数
        /// 処理概要: 有限document内のFocus対象原点を使い、共通Zoom基準点解決器へ座標を渡します。
        ///
        /// - Parameters:
        ///   - viewportPoint: viewport左上から見た基準点。
        ///   - renderedZoom: 現在描画中のZoom倍率。
        ///   - scrollView: Focus有限scroll view。
        /// - Returns: Zoom後のscroll原点計算に使う基準点。
        private func zoomAnchor(
            at viewportPoint: CGPoint,
            renderedZoom: Double,
            in scrollView: NSScrollView
        ) -> CanvasZoomAnchorSnapshot? {
            guard let lastLayout else { return nil }
            return CanvasZoomAnchorResolver.snapshot(
                viewportPoint: viewportPoint,
                visibleOrigin: scrollView.contentView.bounds.origin,
                hostingOrigin: lastLayout.contentFrame.origin,
                renderedZoom: renderedZoom,
                contentPadding: 0
            )
        }

        /// 論理名（日本語）: フォーカスイベント座標変換関数
        /// 処理概要: window座標のイベント位置をFocus viewport左上基準へ変換します。
        ///
        /// - Parameters:
        ///   - event: 変換対象イベント。
        ///   - scrollView: Focus有限scroll view。
        /// - Returns: viewport内へ丸めた相対座標。
        private func viewportPoint(for event: NSEvent, in scrollView: NSScrollView) -> CGPoint {
            let point = scrollView.contentView.convert(event.locationInWindow, from: nil)
            return CanvasZoomAnchorResolver.viewportPoint(point, visibleRect: scrollView.contentView.bounds)
        }

        /// 論理名（日本語）: フォーカスZoom基準点復元関数
        /// 処理概要: Zoom後の対象frameと有限document寸法から、保存した基準点が同じviewport位置に残るscroll原点を適用します。
        ///
        /// - Parameters:
        ///   - anchor: Zoom前に保存した基準点。
        ///   - targetZoom: Zoom後の倍率。
        ///   - layout: Zoom後の有限レイアウト。
        private func applyZoomAnchor(
            _ anchor: CanvasZoomAnchorSnapshot,
            targetZoom: Double,
            layout: CanvasFocusedPreviewLayout
        ) {
            guard let scrollView,
                  let origin = CanvasZoomAnchorResolver.documentOrigin(
                    for: anchor,
                    hostingOrigin: layout.contentFrame.origin,
                    targetZoom: targetZoom,
                    contentPadding: 0,
                    documentSize: layout.documentSize,
                    viewportSize: scrollView.contentView.bounds.size
                  )
            else {
                return
            }

            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        /// 論理名（日本語）: フォーカス入力監視破棄関数
        /// 処理概要: 共通Zoom入力用local event monitorを解除します。
        func dismantle() {
            cancelZoomSettle()
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            dismantle()
        }
    }
}

/// 論理名（日本語）: フォーカス有限ドキュメントビュー
/// 概要: Zoom適用後のFocus対象hosting viewを有限document内の中央frameへ配置します。
private final class CanvasFocusedPreviewDocumentView<Content: View>: NSView {
    let hostingView: NSHostingView<Content>
    private var contentFrame = CGRect.zero

    override var isFlipped: Bool { true }

    /// 論理名（日本語）: フォーカス有限ドキュメント初期化関数
    /// 処理概要: object contentのhosting viewをsubviewとして保持します。
    ///
    /// - Parameter hostingView: Zoom適用後のFocus対象を表示するhosting view。
    init(hostingView: NSHostingView<Content>) {
        self.hostingView = hostingView
        super.init(frame: .zero)
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// 論理名（日本語）: フォーカス有限ドキュメントレイアウト関数
    /// 処理概要: document resize後もobject frameを中央位置へ維持します。
    override func layout() {
        super.layout()
        hostingView.frame = contentFrame
    }

    /// 論理名（日本語）: フォーカス有限レイアウト適用関数
    /// 処理概要: 有限document寸法とobject中央frameをAppKit viewへ反映します。
    ///
    /// - Parameter layout: 適用する有限プレビューレイアウト。
    func apply(layout: CanvasFocusedPreviewLayout) {
        contentFrame = layout.contentFrame
        setFrameSize(layout.documentSize)
        hostingView.frame = layout.contentFrame
    }
}

/// 論理名（日本語）: フォーカス有限AppKitスクロールビュー
/// 概要: viewport resizeをコーディネーターへ通知し、標準scroll rangeを有限document内に限定します。
private final class CanvasFinitePreviewScrollView: NSScrollView {
    var viewportSizeDidChange: ((CGSize) -> Void)?
    private var lastViewportSize = CGSize.zero

    /// 論理名（日本語）: フォーカス有限scrollレイアウト関数
    /// 処理概要: clip viewport寸法が変わったときだけdocument再計算を通知します。
    override func layout() {
        super.layout()
        let viewportSize = contentSize
        guard viewportSize != lastViewportSize else { return }
        lastViewportSize = viewportSize
        viewportSizeDidChange?(viewportSize)
    }
}

/// 論理名（日本語）: ズーム可能キャンバススクロールビュー
/// 概要: SwiftUI のキャンバス内容を `NSScrollView` へ載せ、スクロールとズーム入力を AppKit 側で制御します。
///
/// プロパティ:
/// - `zoom`: 双方向バインディングされたキャンバス倍率。
/// - `viewport`: ルーラー、ガイド、グリッドへ渡す現在の表示領域状態。
/// - `documentID`: 表示中ドキュメントの識別子。
/// - `contentRevisionID`: 表示内容の更新要否を表す識別子。
/// - `contentCanvasOrigin`: canvas content を document 座標へ写すときの原点。
/// - `onEmptyCanvasClick`: ページ群の外側がクリックされたときの処理。
/// - `content`: スクロールビュー内に表示する SwiftUI content。
private struct ZoomableCanvasScrollView<Content: View>: NSViewRepresentable {
    @Binding var zoom: Double
    @Binding var viewport: CanvasViewportState
    var documentID: String
    var contentRevisionID: String
    var contentCanvasOrigin: CGPoint
    var overlayAvoidance: CanvasOverlayAvoidance
    var onEmptyCanvasClick: () -> Void
    var content: () -> Content

    /// 論理名（日本語）: ズーム可能スクロールビュー初期化関数
    /// 処理概要: ズームバインディング、ドキュメント ID、表示 content を保持します。
    ///
    /// - Parameters:
    ///   - zoom: キャンバス倍率のバインディング。
    ///   - viewport: 補助表示と同期する viewport 状態のバインディング。
    ///   - documentID: 表示中ドキュメントの識別子。
    ///   - contentRevisionID: 表示内容の更新要否を表す識別子。
    ///   - contentCanvasOrigin: canvas content を document 座標へ写すときの原点。
    ///   - overlayAvoidance: 左右カラムを避ける操作 UI 用余白。
    ///   - onEmptyCanvasClick: ページ群の外側がクリックされたときの処理。
    ///   - content: スクロールビュー内に表示する SwiftUI content。
    init(
        zoom: Binding<Double>,
        viewport: Binding<CanvasViewportState>,
        documentID: String,
        contentRevisionID: String,
        contentCanvasOrigin: CGPoint,
        overlayAvoidance: CanvasOverlayAvoidance = CanvasOverlayAvoidance(),
        onEmptyCanvasClick: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._zoom = zoom
        self._viewport = viewport
        self.documentID = documentID
        self.contentRevisionID = contentRevisionID
        self.contentCanvasOrigin = contentCanvasOrigin
        self.overlayAvoidance = overlayAvoidance
        self.onEmptyCanvasClick = onEmptyCanvasClick
        self.content = content
    }

    /// 論理名（日本語）: スクロールビューコーディネーター生成関数
    /// 処理概要: AppKit 入力イベントを処理するコーディネーターを生成します。
    ///
    /// - Returns: ズーム可能スクロールビュー用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(
            zoom: $zoom,
            viewport: $viewport,
            documentID: documentID,
            contentRevisionID: contentRevisionID,
            contentCanvasOrigin: contentCanvasOrigin,
            onEmptyCanvasClick: onEmptyCanvasClick,
            content: content
        )
    }

    /// 論理名（日本語）: NSScrollView生成関数
    /// 処理概要: HTML キャンバス用のスクロールビューを生成し、hosting view を documentView として設定します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: キャンバス用 NSScrollView。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CanvasOverlayScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.allowsMagnification = false
        scrollView.overlayAvoidance = overlayAvoidance

        scrollView.documentView = context.coordinator.documentView
        context.coordinator.attach(to: scrollView)
        context.coordinator.refreshDocumentSize()
        scrollView.refreshScrollIndicators()
        context.coordinator.publishViewportState()

        return scrollView
    }

    /// 論理名（日本語）: NSScrollView更新関数
    /// 処理概要: SwiftUI content、ドキュメント ID、documentView サイズを最新状態へ更新します。
    ///
    /// - Parameters:
    ///   - scrollView: 更新対象の NSScrollView。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.zoom = $zoom
        context.coordinator.viewport = $viewport
        context.coordinator.onEmptyCanvasClick = onEmptyCanvasClick
        context.coordinator.updateContent(
            documentID: documentID,
            contentRevisionID: contentRevisionID,
            contentCanvasOrigin: contentCanvasOrigin,
            content: content
        )
        context.coordinator.refreshDocumentSizeIfNeeded()
        if let scrollView = scrollView as? CanvasOverlayScrollView {
            scrollView.overlayAvoidance = overlayAvoidance
            scrollView.refreshScrollIndicators()
        }
        context.coordinator.publishViewportState()
    }

    /// 論理名（日本語）: NSScrollView解体関数
    /// 処理概要: local event monitor を破棄して AppKit 入力監視を終了します。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象の NSScrollView。
    ///   - coordinator: 紐づくコーディネーター。
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        (nsView as? CanvasOverlayScrollView)?.viewportDidChange = nil
        coordinator.dismantle()
    }

    /// 論理名（日本語）: キャンバススクロールコーディネーター
    /// 概要: AppKit のスクロール、magnify、gesture イベントを処理し、ズームとスクロールルーティングを制御します。
    ///
    /// プロパティ:
    /// - `zoom`: キャンバス倍率のバインディング。
    /// - `content`: 表示する SwiftUI content。
    /// - `onEmptyCanvasClick`: ページ群の外側がクリックされたときの処理。
    /// - `hostingView`: NSScrollView に載せる hosting view。
    /// - `documentView`: 無限キャンバス用の documentView。
    /// - `pendingZoomAnchor`: 次のズーム反映時に使う基準点。
    final class Coordinator: NSObject {
        var zoom: Binding<Double>
        var viewport: Binding<CanvasViewportState>
        var content: () -> Content
        var onEmptyCanvasClick: () -> Void
        let hostingView: CanvasZeroSafeAreaHostingView<Content>
        let documentView: CanvasInfiniteDocumentView<Content>

        private weak var scrollView: NSScrollView?
        private var monitor: Any?
        private var renderedDocumentID: String
        private var renderedContentRevisionID: String
        private var renderedContentCanvasOrigin: CGPoint
        private var lastViewportSize: NSSize = .zero
        private var lastZoom: Double
        private var pendingZoomAnchor: CanvasZoomAnchorSnapshot?
        private weak var cachedScrollRoutingWebView: WKWebView?
        private var isViewportPublishScheduled = false

        /// 論理名（日本語）: キャンバススクロールコーディネーター初期化関数
        /// 処理概要: ズームバインディング、ドキュメント ID、初期 content を hosting view に保持します。
        ///
        /// - Parameters:
        ///   - zoom: キャンバス倍率のバインディング。
        ///   - viewport: 補助表示と同期する viewport 状態のバインディング。
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - contentRevisionID: 表示内容の更新要否を表す識別子。
        ///   - contentCanvasOrigin: canvas content を document 座標へ写すときの原点。
        ///   - onEmptyCanvasClick: ページ群の外側がクリックされたときの処理。
        ///   - content: 初期表示する SwiftUI content。
        init(
            zoom: Binding<Double>,
            viewport: Binding<CanvasViewportState>,
            documentID: String,
            contentRevisionID: String,
            contentCanvasOrigin: CGPoint,
            onEmptyCanvasClick: @escaping () -> Void,
            content: @escaping () -> Content
        ) {
            self.zoom = zoom
            self.viewport = viewport
            self.content = content
            self.onEmptyCanvasClick = onEmptyCanvasClick
            self.renderedDocumentID = documentID
            self.renderedContentRevisionID = contentRevisionID
            self.renderedContentCanvasOrigin = contentCanvasOrigin
            self.lastZoom = CanvasZoom.clamped(zoom.wrappedValue)
            self.hostingView = CanvasZeroSafeAreaHostingView(rootView: content())
            self.hostingView.isFlipped = true
            self.documentView = CanvasInfiniteDocumentView(hostingView: hostingView)
            super.init()
            self.documentView.emptyClickHandler = { [weak self] in
                self?.onEmptyCanvasClick()
            }
        }

        /// 論理名（日本語）: スクロールビュー接続関数
        /// 処理概要: NSScrollView を保持し、スクロールとズームの local event monitor を登録します。
        ///
        /// - Parameter scrollView: 接続対象の NSScrollView。
        func attach(to scrollView: NSScrollView) {
            self.scrollView = scrollView
            (scrollView as? CanvasOverlayScrollView)?.viewportDidChange = { [weak self] in
                self?.publishViewportState()
            }
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: CanvasZoomInputResolver.eventMask) { [weak self] event in
                guard let self, self.handleInputEvent(event) else {
                    return event
                }
                return nil
            }
        }

        /// 論理名（日本語）: Content更新関数
        /// 処理概要: ドキュメント ID、content revision、ズームの変化に応じて rootView とサイズを更新します。
        ///
        /// - Parameters:
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - contentRevisionID: 表示内容の更新要否を表す識別子。
        ///   - contentCanvasOrigin: canvas content を document 座標へ写すときの原点。
        ///   - content: 新しい SwiftUI content。
        func updateContent(
            documentID: String,
            contentRevisionID: String,
            contentCanvasOrigin: CGPoint,
            content: @escaping () -> Content
        ) {
            self.content = content
            let currentZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let didChangeDocument = renderedDocumentID != documentID
            let didChangeContent = renderedContentRevisionID != contentRevisionID
            let previousContentCanvasOrigin = renderedContentCanvasOrigin
            let didChangeCanvasOrigin = renderedContentCanvasOrigin != contentCanvasOrigin
            let previousRenderedZoom = lastZoom
            let didChangeZoom = abs(lastZoom - currentZoom) > 0.0005
            guard didChangeDocument || didChangeContent || didChangeCanvasOrigin || didChangeZoom else { return }

            let zoomAnchor = didChangeZoom && !didChangeDocument
                ? pendingZoomAnchor ?? centeredZoomAnchor(renderedZoom: previousRenderedZoom)
                : nil
            let canvasOriginAdjustment = didChangeDocument || didChangeZoom
                ? .zero
                : CanvasViewportOriginAdjustmentResolver.scrollAdjustment(
                    previousOrigin: previousContentCanvasOrigin,
                    newOrigin: contentCanvasOrigin,
                    zoom: currentZoom
                )
            pendingZoomAnchor = nil

            renderedDocumentID = documentID
            renderedContentRevisionID = contentRevisionID
            renderedContentCanvasOrigin = contentCanvasOrigin
            lastZoom = currentZoom
            hostingView.rootView = content()
            cachedScrollRoutingWebView = nil
            if didChangeDocument {
                resetDocumentViewPosition()
            }
            refreshDocumentSize(force: true)
            applyCanvasOriginAdjustment(canvasOriginAdjustment)
            if let zoomAnchor {
                applyZoomAnchor(zoomAnchor, targetZoom: currentZoom)
            }
        }

        /// 論理名（日本語）: ドキュメントサイズ更新関数
        /// 処理概要: hosting view の fittingSize と viewport をもとに documentView サイズを強制更新します。
        func refreshDocumentSize() {
            refreshDocumentSize(force: true)
        }

        /// 論理名（日本語）: 必要時ドキュメントサイズ更新関数
        /// 処理概要: viewport サイズが変わった場合だけ documentView サイズを更新します。
        func refreshDocumentSizeIfNeeded() {
            guard let scrollView else { return }
            let viewportSize = scrollView.contentView.bounds.size
            guard viewportSize != lastViewportSize else { return }
            refreshDocumentSize(force: true)
        }

        /// 論理名（日本語）: キャンバス表示領域公開関数
        /// 処理概要: AppKit の clip 原点と hosting view 原点を次の main run loop で SwiftUI 補助表示へ反映します。
        func publishViewportState() {
            guard !isViewportPublishScheduled else { return }
            isViewportPublishScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isViewportPublishScheduled = false
                guard let scrollView else { return }
                let nextState = CanvasViewportState(
                    visibleOrigin: scrollView.contentView.bounds.origin,
                    hostingOrigin: documentView.hostingView.frame.origin,
                    viewportSize: scrollView.contentView.bounds.size
                )
                if viewport.wrappedValue != nextState {
                    viewport.wrappedValue = nextState
                }
            }
        }

        /// 論理名（日本語）: ドキュメント表示位置リセット関数
        /// 処理概要: 表示ページが切り替わったときに無限キャンバスの余白とスクロール位置を初期化します。
        private func resetDocumentViewPosition() {
            documentView.resetCanvasState()
            guard let scrollView else { return }

            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        /// 論理名（日本語）: キャンバス原点変化補正関数
        /// 処理概要: content の bounds 原点が変わっても、ユーザーの表示領域が配置先へ追従しないよう clip origin を補正します。
        ///
        /// - Parameter adjustment: document 座標上で加算する scroll origin 補正量。
        private func applyCanvasOriginAdjustment(_ adjustment: CGPoint) {
            guard adjustment != .zero,
                  let scrollView,
                  let documentSize = scrollView.documentView?.frame.size
            else {
                return
            }

            let visibleOrigin = scrollView.contentView.bounds.origin
            let origin = CanvasZoomAnchorResolver.clampedDocumentOrigin(
                CGPoint(
                    x: visibleOrigin.x + adjustment.x,
                    y: visibleOrigin.y + adjustment.y
                ),
                documentSize: documentSize,
                viewportSize: scrollView.contentView.bounds.size
            )
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            (scrollView as? CanvasOverlayScrollView)?.refreshScrollIndicators()
        }

        /// 論理名（日本語）: ドキュメントサイズ内部更新関数
        /// 処理概要: hosting view の実サイズが viewport より小さくならないように frame を調整します。
        ///
        /// - Parameter force: viewport 変化がなくても更新するか。
        private func refreshDocumentSize(force: Bool) {
            guard let scrollView else { return }
            let viewportSize = scrollView.contentView.bounds.size
            guard force || viewportSize != lastViewportSize else { return }

            hostingView.layoutSubtreeIfNeeded()
            let fittingSize = hostingView.fittingSize
            documentView.updateContentSize(fittingSize, viewportSize: viewportSize)
            lastViewportSize = viewportSize
            (scrollView as? CanvasOverlayScrollView)?.refreshScrollIndicators()
        }

        /// 論理名（日本語）: イベント監視破棄関数
        /// 処理概要: 登録済み local event monitor を削除します。
        func dismantle() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            cachedScrollRoutingWebView = nil
            isViewportPublishScheduled = false
        }

        /// 論理名（日本語）: 入力イベント処理関数
        /// 処理概要: 対象 scroll view 内の scroll、magnify、gesture をズームまたはスクロールルーティングへ振り分けます。
        ///
        /// - Parameter event: AppKit から届いた入力イベント。
        /// - Returns: OpenGraphite 側で消費した場合は `true`。
        private func handleInputEvent(_ event: NSEvent) -> Bool {
            guard let scrollView,
                  event.window === scrollView.window,
                  isEventInsideScrollView(event, scrollView: scrollView)
            else {
                return false
            }

            if CanvasZoomInputResolver.input(for: event) != nil {
                return handleZoomInput(event)
            }

            return routeCanvasScrollIfNeeded(event, in: scrollView)
        }

        /// 論理名（日本語）: キャンバスZoom入力処理関数
        /// 処理概要: Commandスクロール、trackpad pinch、互換gestureを共通解決器でZoomへ変換します。
        ///
        /// - Parameter event: scroll、magnify、gestureイベント。
        /// - Returns: ズーム操作として消費した場合は `true`。
        private func handleZoomInput(_ event: NSEvent) -> Bool {
            guard let input = CanvasZoomInputResolver.input(for: event) else { return false }
            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let newZoom = CanvasZoomInputResolver.targetZoom(currentZoom: oldZoom, input: input)
            guard newZoom != oldZoom else { return true }

            pendingZoomAnchor = pointerZoomAnchor(for: event, renderedZoom: lastZoom)
            zoom.wrappedValue = newZoom
            return true
        }

        /// 論理名（日本語）: ポインタズーム基準点生成関数
        /// 処理概要: 入力イベントの位置を viewport 基準の点へ変換し、ズーム前のキャンバス内容座標として保存します。
        ///
        /// - Parameters:
        ///   - event: 基準点に使う入力イベント。
        ///   - renderedZoom: 現在描画されているキャンバス倍率。
        /// - Returns: ズーム後の scroll origin 補正に使う基準点。
        private func pointerZoomAnchor(for event: NSEvent, renderedZoom: Double) -> CanvasZoomAnchorSnapshot? {
            guard let scrollView else { return nil }

            return zoomAnchor(
                at: viewportPoint(for: event, in: scrollView),
                renderedZoom: renderedZoom,
                in: scrollView
            )
        }

        /// 論理名（日本語）: 中央ズーム基準点生成関数
        /// 処理概要: HUD ボタンなどイベント位置を持たないズーム操作用に viewport 中央を基準点として保存します。
        ///
        /// - Parameter renderedZoom: 現在描画されているキャンバス倍率。
        /// - Returns: ズーム後の scroll origin 補正に使う基準点。
        private func centeredZoomAnchor(renderedZoom: Double) -> CanvasZoomAnchorSnapshot? {
            guard let scrollView else { return nil }

            let visibleRect = scrollView.contentView.bounds
            return zoomAnchor(
                at: CGPoint(x: visibleRect.width / 2, y: visibleRect.height / 2),
                renderedZoom: renderedZoom,
                in: scrollView
            )
        }

        /// 論理名（日本語）: ズーム基準点生成関数
        /// 処理概要: viewport 上の点を `CanvasZoomAnchorResolver` へ渡して保存可能な基準点へ変換します。
        ///
        /// - Parameters:
        ///   - viewportPoint: viewport 左上から見た基準点。
        ///   - renderedZoom: 現在描画されているキャンバス倍率。
        ///   - scrollView: 対象のキャンバス scroll view。
        /// - Returns: ズーム後の scroll origin 補正に使う基準点。
        private func zoomAnchor(
            at viewportPoint: CGPoint,
            renderedZoom: Double,
            in scrollView: NSScrollView
        ) -> CanvasZoomAnchorSnapshot? {
            CanvasZoomAnchorResolver.snapshot(
                viewportPoint: viewportPoint,
                visibleOrigin: scrollView.contentView.bounds.origin,
                hostingOrigin: documentView.hostingView.frame.origin,
                renderedZoom: renderedZoom,
                contentPadding: CanvasMetrics.documentPadding
            )
        }

        /// 論理名（日本語）: イベントviewport座標変換関数
        /// 処理概要: window 座標のイベント位置を clip view の表示領域左上からの相対座標へ変換します。
        ///
        /// - Parameters:
        ///   - event: 変換対象の入力イベント。
        ///   - scrollView: 対象のキャンバス scroll view。
        /// - Returns: viewport 左上から見たイベント位置。
        private func viewportPoint(for event: NSEvent, in scrollView: NSScrollView) -> CGPoint {
            let point = scrollView.contentView.convert(event.locationInWindow, from: nil)
            return CanvasZoomAnchorResolver.viewportPoint(point, visibleRect: scrollView.contentView.bounds)
        }

        /// 論理名（日本語）: ズーム基準点復元関数
        /// 処理概要: ズーム後の documentView サイズをもとに、保存した基準点が元の viewport 位置へ来るようにスクロールします。
        ///
        /// - Parameters:
        ///   - anchor: ズーム前に保存した基準点。
        ///   - targetZoom: ズーム後のキャンバス倍率。
        private func applyZoomAnchor(_ anchor: CanvasZoomAnchorSnapshot, targetZoom: Double) {
            guard let scrollView,
                  let documentSize = scrollView.documentView?.frame.size,
                  let origin = CanvasZoomAnchorResolver.documentOrigin(
                    for: anchor,
                    hostingOrigin: documentView.hostingView.frame.origin,
                    targetZoom: targetZoom,
                    contentPadding: CanvasMetrics.documentPadding,
                    documentSize: documentSize,
                    viewportSize: scrollView.contentView.bounds.size
                  )
            else {
                return
            }

            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            (scrollView as? CanvasOverlayScrollView)?.refreshScrollIndicators()
        }

        /// 論理名（日本語）: キャンバススクロールルーティング関数
        /// 処理概要: Canvas 内の通常 wheel を、ポインタ直下が WebView なら Page 側へ直接渡し、それ以外は外側 NSScrollView へ渡します。
        ///
        /// - Parameters:
        ///   - event: scroll wheel イベント。
        ///   - scrollView: 外側のキャンバス NSScrollView。
        /// - Returns: Page または外側 scroll view へルーティングして消費した場合は `true`。
        private func routeCanvasScrollIfNeeded(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
            let webView = webViewUnderEvent(event, in: scrollView)
            if CanvasScrollRoutePolicy.shouldRouteToCanvas(isPointerOverWebView: webView != nil) {
                scrollView.scrollWheel(with: event)
            } else {
                webView?.scrollWheel(with: event)
            }

            return true
        }

        /// 論理名（日本語）: キャンバス有効入力イベント判定関数
        /// 処理概要: 入力イベントの window 座標が左右カラムと上部クロームを除いた Canvas 領域内か判定します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 対象 NSScrollView。
        /// - Returns: イベント位置が有効 Canvas 領域内なら `true`。
        private func isEventInsideScrollView(_ event: NSEvent, scrollView: NSScrollView) -> Bool {
            CanvasInputRegionPolicy.isPointInActiveCanvasRegion(
                scrollView.convert(event.locationInWindow, from: nil),
                bounds: scrollView.bounds,
                overlayAvoidance: (scrollView as? CanvasOverlayScrollView)?.overlayAvoidance ?? CanvasOverlayAvoidance(),
                isFlipped: scrollView.isFlipped
            )
        }

        /// 論理名（日本語）: イベント直下WebView取得関数
        /// 処理概要: 選択用 SwiftUI overlay の hit-test 経路を避け、WKWebView の window frame から入力位置を判定します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 探索の基準となる NSScrollView。
        /// - Returns: ポインタ直下にある WKWebView。存在しない場合は `nil`。
        private func webViewUnderEvent(_ event: NSEvent, in scrollView: NSScrollView) -> WKWebView? {
            let windowPoint = event.locationInWindow
            if let webView = cachedWebView(containing: windowPoint, in: scrollView) {
                return webView
            }

            let webViews = containedWebViews(in: scrollView.documentView ?? scrollView)
            let frames = webViews.map { $0.convert($0.bounds, to: nil) }
            guard let index = CanvasWindowFrameResolver.topmostFrameIndex(
                containing: windowPoint,
                frames: frames
            ) else {
                cachedScrollRoutingWebView = nil
                return nil
            }

            let webView = webViews[index]
            cachedScrollRoutingWebView = webView
            return webView
        }

        /// 論理名（日本語）: キャッシュ済みWebView取得関数
        /// 処理概要: 連続 wheel 入力では直前の WKWebView の window frame だけを再評価し、view tree 探索を避けます。
        ///
        /// - Parameters:
        ///   - windowPoint: window 座標上の入力位置。
        ///   - scrollView: 対象キャンバス scroll view。
        /// - Returns: 入力位置を含むキャッシュ済み WebView。無効な場合は `nil`。
        private func cachedWebView(containing windowPoint: CGPoint, in scrollView: NSScrollView) -> WKWebView? {
            guard let webView = cachedScrollRoutingWebView,
                  webView.window === scrollView.window,
                  !webView.isHidden,
                  CanvasWindowFrameResolver.contains(windowPoint, in: webView.convert(webView.bounds, to: nil))
            else {
                cachedScrollRoutingWebView = nil
                return nil
            }

            return webView
        }

        /// 論理名（日本語）: 内包WebView一覧取得関数
        /// 処理概要: Canvas document view 配下の WKWebView を描画順で収集します。
        ///
        /// - Parameter rootView: 探索を開始する AppKit view。
        /// - Returns: 配下にある WKWebView の一覧。
        private func containedWebViews(in rootView: NSView) -> [WKWebView] {
            var webViews: [WKWebView] = []
            appendContainedWebViews(in: rootView, to: &webViews)
            return webViews
        }

        /// 論理名（日本語）: 内包WebView再帰収集関数
        /// 処理概要: SwiftUI hosting 階層をたどり、表示中の WKWebView を描画順の配列へ追加します。
        ///
        /// - Parameters:
        ///   - rootView: 探索対象の AppKit view。
        ///   - webViews: 見つかった WKWebView を追加する配列。
        private func appendContainedWebViews(in rootView: NSView, to webViews: inout [WKWebView]) {
            if let webView = rootView as? WKWebView, !webView.isHidden {
                webViews.append(webView)
                return
            }

            for subview in rootView.subviews {
                appendContainedWebViews(in: subview, to: &webViews)
            }
        }

        deinit {
            dismantle()
        }
    }
}

/// 論理名（日本語）: キャンバススクロール配送ポリシー
/// 概要: 表示中 WebView 上の wheel 入力を内側 DOM へ渡すか、外側 Canvas へ渡すかを判定します。
///
/// 定義内容:
/// - `shouldRouteToCanvas(isPointerOverWebView:)`: ポインタが WebView 上かどうかから WebView 側優先にするかを決めます。
enum CanvasScrollRoutePolicy {
    /// 論理名（日本語）: キャンバス配送判定関数
    /// 処理概要: ポインタが WebView 上なら Page へ wheel 入力を渡し、それ以外は Canvas へ渡します。
    ///
    /// - Parameter isPointerOverWebView: ポインタが WKWebView の表示領域上にあるか。
    /// - Returns: 外側 Canvas の scroll view へ入力を渡す場合は `true`。
    static func shouldRouteToCanvas(isPointerOverWebView: Bool) -> Bool {
        !isPointerOverWebView
    }
}

/// 論理名（日本語）: キャンバスwindow frame解決
/// 概要: Canvas 上の AppKit view frame 群から、window 座標の入力位置に対応する最前面候補を解決します。
///
/// 定義内容:
/// - `contains(_:in:)`: 入力点が指定 frame 内にあるかを判定します。
/// - `topmostFrameIndex(containing:frames:)`: 入力点を含む最前面 frame の index を返します。
enum CanvasWindowFrameResolver {
    /// 論理名（日本語）: frame包含判定関数
    /// 処理概要: window 座標の入力点が view の window frame に含まれるか判定します。
    ///
    /// - Parameters:
    ///   - windowPoint: window 座標上の入力点。
    ///   - frame: 判定対象の window frame。
    /// - Returns: 入力点が frame 内にあれば `true`。
    static func contains(_ windowPoint: CGPoint, in frame: CGRect) -> Bool {
        frame.contains(windowPoint)
    }

    /// 論理名（日本語）: 最前面frame index取得関数
    /// 処理概要: 描画順に並んだ frame 群を後方から調べ、入力点を含む最前面候補を返します。
    ///
    /// - Parameters:
    ///   - windowPoint: window 座標上の入力点。
    ///   - frames: 背面から前面の順に並んだ window frame 群。
    /// - Returns: 入力点を含む最前面 frame の index。該当しない場合は `nil`。
    static func topmostFrameIndex(containing windowPoint: CGPoint, frames: [CGRect]) -> Int? {
        frames.indices.reversed().first { index in
            contains(windowPoint, in: frames[index])
        }
    }
}

/// 論理名（日本語）: キャンバス無限ドキュメントコンテナ
/// 概要: `NSScrollView` が無限キャンバス用 documentView として扱うための最小インターフェースです。
///
/// 要件:
    /// - `updateContentSize(_:viewportSize:)`: SwiftUI content の実寸と viewport を反映する。
    /// - `resetCanvasState()`: ページ切り替え時に一時的な余白を初期化する。
    /// - `adjustCanvasIfNeeded(visibleRect:scrollIntent:allowsExpansion:allowsContraction:)`: スクロール位置に応じてキャンバス余白を調整する。
private protocol CanvasInfiniteDocumentContainer: AnyObject {
    /// 論理名（日本語）: コンテンツサイズ更新関数
    /// 処理概要: SwiftUI content の fitting size と viewport をもとに documentView を再配置します。
    ///
    /// - Parameters:
    ///   - contentSize: SwiftUI content の fitting size。
    ///   - viewportSize: `NSScrollView` の表示領域サイズ。
    func updateContentSize(_ contentSize: NSSize, viewportSize: NSSize)

    /// 論理名（日本語）: キャンバス状態リセット関数
    /// 処理概要: スクロールで追加された余白と content origin を初期状態へ戻します。
    func resetCanvasState()

    /// 論理名（日本語）: キャンバス必要時調整関数
    /// 処理概要: スクロール方向と現在の表示領域に応じて documentView の余白を追加または削除します。
    ///
    /// - Parameters:
    ///   - visibleRect: 現在表示されている clip bounds。
    ///   - scrollIntent: スクロールしたい方向。正の X/Y は右/下、負の X/Y は左/上。
    ///   - allowsExpansion: 端方向への余白追加を許可するか。
    ///   - allowsContraction: 戻り方向で未使用余白の削除を許可するか。
    /// - Returns: documentView 調整後に必要な clip origin 補正と変更有無。
    func adjustCanvasIfNeeded(
        visibleRect: CGRect,
        scrollIntent: CGPoint,
        allowsExpansion: Bool,
        allowsContraction: Bool
    ) -> CanvasInfiniteAdjustment
}

/// 論理名（日本語）: キャンバス無限調整結果
/// 概要: 無限キャンバスのサイズ調整後、スクロールビュー側で反映すべき補正値を表します。
///
/// プロパティ:
/// - `originAdjustment`: documentView の挿入または削除に合わせる clip origin 補正。
/// - `didResize`: documentView の frame size が変化したか。
private struct CanvasInfiniteAdjustment {
    var originAdjustment: CGPoint = .zero
    var didResize = false
}

/// 論理名（日本語）: キャンバス無限余白解決
/// 概要: wheel 入力中に追加・削除する無限キャンバス余白量を計算します。
///
/// 定義内容:
/// - `edgeExpansionTolerance`: 表示領域が端へ到達したとみなす許容値。
/// - `expansionAmount(for:)`: 端方向へ追加する余白量。
/// - `leadingContractionAmount(currentLeadingInset:visibleStart:)`: 左上側から削除できる余白量。
/// - `trailingContractionSize(currentSize:minimumSize:visibleEnd:)`: 右下側の未使用余白を削った documentView サイズ。
enum CanvasInfiniteMarginResolver {
    static var edgeExpansionTolerance: CGFloat { 120 }
    static var minimumExpansionStep: CGFloat { 320 }
    static var maximumExpansionStep: CGFloat { 640 }
    static var contractionPadding: CGFloat { 160 }
    static var minimumContractionStep: CGFloat { 256 }

    /// 論理名（日本語）: 拡張量取得関数
    /// 処理概要: 細かい trackpad delta ごとの frame resize を避けるため、端到達時の余白をまとまった単位で追加します。
    ///
    /// - Parameter scrollDelta: 対象軸のスクロール意図値。
    /// - Returns: 追加する余白量。
    static func expansionAmount(for scrollDelta: CGFloat) -> CGFloat {
        min(max(abs(scrollDelta), minimumExpansionStep), maximumExpansionStep)
    }

    /// 論理名（日本語）: 先頭余白縮小量取得関数
    /// 処理概要: 左上側の未使用余白が一定量以上たまった場合だけ削除量を返します。
    ///
    /// - Parameters:
    ///   - currentLeadingInset: 現在の左または上の余白量。
    ///   - visibleStart: 対象軸の表示開始位置。
    /// - Returns: 削除できる余白量。小さすぎる場合は `0`。
    static func leadingContractionAmount(currentLeadingInset: CGFloat, visibleStart: CGFloat) -> CGFloat {
        let contraction = min(currentLeadingInset, max(visibleStart - contractionPadding, 0))
        return contraction >= minimumContractionStep ? contraction : 0
    }

    /// 論理名（日本語）: 末尾余白縮小サイズ取得関数
    /// 処理概要: 右下側の未使用余白が一定量以上たまった場合だけ documentView を縮小します。
    ///
    /// - Parameters:
    ///   - currentSize: 対象軸の現在の documentView サイズ。
    ///   - minimumSize: 実コンテンツと viewport を含む対象軸の最小サイズ。
    ///   - visibleEnd: 対象軸の表示終了位置。
    /// - Returns: 縮小後の対象軸サイズ。小さすぎる場合は現在値。
    static func trailingContractionSize(
        currentSize: CGFloat,
        minimumSize: CGFloat,
        visibleEnd: CGFloat
    ) -> CGFloat {
        let targetSize = min(currentSize, max(minimumSize, visibleEnd + contractionPadding))
        let contraction = currentSize - targetSize
        return contraction >= minimumContractionStep ? targetSize : currentSize
    }
}

/// 論理名（日本語）: キャンバス無限ドキュメントビュー
/// 概要: SwiftUI のキャンバス内容を保持し、スクロール方向に応じて documentView の余白を調整します。
///
/// プロパティ:
/// - `hostingView`: 実際の SwiftUI キャンバス内容。
/// - `emptyClickHandler`: SwiftUI content 外側の余白がクリックされたときの処理。
private final class CanvasInfiniteDocumentView<Content: View>: NSView, CanvasInfiniteDocumentContainer {
    let hostingView: NSHostingView<Content>
    var emptyClickHandler: (() -> Void)?

    private var contentSize: NSSize = .zero
    private var contentOrigin: CGPoint = .zero
    private var viewportSize: NSSize = .zero

    override var isFlipped: Bool {
        true
    }

    /// 論理名（日本語）: キャンバス無限ドキュメントビュー初期化関数
    /// 処理概要: SwiftUI content を描画する hosting view を subview として保持します。
    ///
    /// - Parameter hostingView: キャンバス内容を表示する hosting view。
    init(hostingView: NSHostingView<Content>) {
        self.hostingView = hostingView
        super.init(frame: .zero)
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: documentView 内の現在の content origin と content size を hosting view へ反映します。
    override func layout() {
        super.layout()
        layoutHostingView()
    }

    /// 論理名（日本語）: マウスダウン処理関数
    /// 処理概要: SwiftUI content の外側にある無限キャンバス余白をクリックしたとき、ページ選択解除を通知します。
    ///
    /// - Parameter event: AppKit から届いたマウスダウンイベント。
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !hostingView.frame.contains(point) else {
            super.mouseDown(with: event)
            return
        }

        emptyClickHandler?()
    }

    /// 論理名（日本語）: コンテンツサイズ更新関数
    /// 処理概要: SwiftUI content の fitting size と viewport をもとに documentView の最小サイズを更新します。
    ///
    /// - Parameters:
    ///   - contentSize: SwiftUI content の fitting size。
    ///   - viewportSize: `NSScrollView` の表示領域サイズ。
    func updateContentSize(_ contentSize: NSSize, viewportSize: NSSize) {
        self.contentSize = contentSize
        self.viewportSize = viewportSize
        let minimumSize = minimumDocumentSize()
        setFrameSize(
            NSSize(
                width: max(frame.width, minimumSize.width),
                height: max(frame.height, minimumSize.height)
            )
        )
        layoutHostingView()
    }

    /// 論理名（日本語）: キャンバス状態リセット関数
    /// 処理概要: ページ切り替え時にスクロールで追加された余白と content origin を破棄します。
    func resetCanvasState() {
        contentOrigin = .zero
        let minimumSize = minimumDocumentSize()
        setFrameSize(minimumSize)
        layoutHostingView()
    }

    /// 論理名（日本語）: キャンバス必要時調整関数
    /// 処理概要: 表示領域が端へ到達したときは余白を追加し、戻ったときは未使用余白を削除します。
    ///
    /// - Parameters:
    ///   - visibleRect: 現在表示されている clip bounds。
    ///   - scrollIntent: スクロールしたい方向。正の X/Y は右/下、負の X/Y は左/上。
    ///   - allowsExpansion: 端方向への余白追加を許可するか。
    ///   - allowsContraction: 戻り方向で未使用余白の削除を許可するか。
    /// - Returns: documentView 調整後に必要な clip origin 補正と変更有無。
    func adjustCanvasIfNeeded(
        visibleRect: CGRect,
        scrollIntent: CGPoint,
        allowsExpansion: Bool,
        allowsContraction: Bool
    ) -> CanvasInfiniteAdjustment {
        var adjustment = CanvasInfiniteAdjustment()
        var newSize = frame.size
        var shouldLayoutContent = false

        if allowsExpansion {
            let horizontalExpansion = expansionAmount(for: scrollIntent.x)
            if scrollIntent.x < 0, visibleRect.minX <= CanvasInfiniteMarginResolver.edgeExpansionTolerance {
                contentOrigin.x += horizontalExpansion
                newSize.width += horizontalExpansion
                adjustment.originAdjustment.x += horizontalExpansion
                shouldLayoutContent = true
            }

            if scrollIntent.x > 0,
               visibleRect.maxX >= frame.width - CanvasInfiniteMarginResolver.edgeExpansionTolerance {
                newSize.width += horizontalExpansion
            }

            let verticalExpansion = expansionAmount(for: scrollIntent.y)
            if scrollIntent.y < 0, visibleRect.minY <= CanvasInfiniteMarginResolver.edgeExpansionTolerance {
                contentOrigin.y += verticalExpansion
                newSize.height += verticalExpansion
                adjustment.originAdjustment.y += verticalExpansion
                shouldLayoutContent = true
            }

            if scrollIntent.y > 0,
               visibleRect.maxY >= frame.height - CanvasInfiniteMarginResolver.edgeExpansionTolerance {
                newSize.height += verticalExpansion
            }
        }

        if allowsContraction {
            if scrollIntent.x > 0 {
                let contraction = leadingContractionAmount(
                    currentLeadingInset: contentOrigin.x,
                    visibleStart: visibleRect.minX
                )
                if contraction > 0 {
                    contentOrigin.x -= contraction
                    newSize.width -= contraction
                    adjustment.originAdjustment.x -= contraction
                    shouldLayoutContent = true
                }
            } else if scrollIntent.x < 0 {
                newSize.width = trailingContractionSize(
                    currentSize: newSize.width,
                    minimumSize: minimumDocumentSize().width,
                    visibleEnd: visibleRect.maxX
                )
            }

            if scrollIntent.y > 0 {
                let contraction = leadingContractionAmount(
                    currentLeadingInset: contentOrigin.y,
                    visibleStart: visibleRect.minY
                )
                if contraction > 0 {
                    contentOrigin.y -= contraction
                    newSize.height -= contraction
                    adjustment.originAdjustment.y -= contraction
                    shouldLayoutContent = true
                }
            } else if scrollIntent.y < 0 {
                newSize.height = trailingContractionSize(
                    currentSize: newSize.height,
                    minimumSize: minimumDocumentSize().height,
                    visibleEnd: visibleRect.maxY
                )
            }
        }

        if newSize != frame.size {
            setFrameSize(newSize)
            adjustment.didResize = true
        }

        if shouldLayoutContent {
            layoutHostingView()
        }

        return adjustment
    }

    /// 論理名（日本語）: ホスティングビューレイアウト関数
    /// 処理概要: SwiftUI content を無限 documentView 内の現在位置へ配置します。
    private func layoutHostingView() {
        hostingView.frame = CGRect(origin: contentOrigin, size: contentSize)
    }

    /// 論理名（日本語）: 最小ドキュメントサイズ取得関数
    /// 処理概要: 実コンテンツと viewport を必ず含む documentView の最小サイズを返します。
    ///
    /// - Returns: 余白を除いた基準 documentView サイズ。
    private func minimumDocumentSize() -> NSSize {
        NSSize(
            width: max(contentOrigin.x + contentSize.width, viewportSize.width),
            height: max(contentOrigin.y + contentSize.height, viewportSize.height)
        )
    }

    /// 論理名（日本語）: 拡張量取得関数
    /// 処理概要: スクロール入力に近い量で余白を追加し、thumb が端に残ったまま短くなるようにします。
    ///
    /// - Parameter scrollDelta: 対象軸のスクロール意図値。
    /// - Returns: 追加する余白量。
    private func expansionAmount(for scrollDelta: CGFloat) -> CGFloat {
        CanvasInfiniteMarginResolver.expansionAmount(for: scrollDelta)
    }

    /// 論理名（日本語）: 先頭余白縮小量取得関数
    /// 処理概要: 表示範囲から外れた左または上の未使用余白量を計算します。
    ///
    /// - Parameters:
    ///   - currentLeadingInset: 現在の左または上の余白量。
    ///   - visibleStart: 対象軸の表示開始位置。
    /// - Returns: 削除できる余白量。
    private func leadingContractionAmount(currentLeadingInset: CGFloat, visibleStart: CGFloat) -> CGFloat {
        CanvasInfiniteMarginResolver.leadingContractionAmount(
            currentLeadingInset: currentLeadingInset,
            visibleStart: visibleStart
        )
    }

    /// 論理名（日本語）: 末尾余白縮小サイズ取得関数
    /// 処理概要: 表示範囲から外れた右または下の未使用余白を削った documentView サイズを返します。
    ///
    /// - Parameters:
    ///   - currentSize: 対象軸の現在の documentView サイズ。
    ///   - minimumSize: 実コンテンツと viewport を含む対象軸の最小サイズ。
    ///   - visibleEnd: 対象軸の表示終了位置。
    /// - Returns: 縮小後の対象軸サイズ。
    private func trailingContractionSize(
        currentSize: CGFloat,
        minimumSize: CGFloat,
        visibleEnd: CGFloat
    ) -> CGFloat {
        CanvasInfiniteMarginResolver.trailingContractionSize(
            currentSize: currentSize,
            minimumSize: minimumSize,
            visibleEnd: visibleEnd
        )
    }
}

/// 論理名（日本語）: キャンバススクロールインジケータ軸
/// 概要: 独自 overlay scroll indicator が表すスクロール方向を定義します。
///
/// 定義内容:
/// - `vertical`: 縦方向のスクロール位置。
/// - `horizontal`: 横方向のスクロール位置。
private enum CanvasScrollIndicatorAxis {
    case vertical
    case horizontal
}

/// 論理名（日本語）: キャンバススクロールインジケータ配置
/// 概要: thumb の表示位置、表示長、drag 換算に必要な距離をまとめます。
///
/// プロパティ:
/// - `frame`: indicator view を置く frame。
/// - `indicatorTravel`: indicator が track 上を移動できる距離。
/// - `contentTravel`: documentView がスクロールできる距離。
private struct CanvasScrollIndicatorPlacement {
    var frame: CGRect
    var indicatorTravel: CGFloat
    var contentTravel: CGFloat
}

/// 論理名（日本語）: キャンバススクロールインジケータビュー
/// 概要: `NSScrollView` 上に重ねる薄い独自スクロール thumb です。
///
/// プロパティ:
/// - `axis`: indicator が担当するスクロール方向。
/// - `owningScrollView`: drag 操作を処理する親スクロールビュー。
private final class CanvasScrollIndicatorView: NSView {
    let axis: CanvasScrollIndicatorAxis
    weak var owningScrollView: CanvasOverlayScrollView?

    override var isOpaque: Bool {
        false
    }

    /// 論理名（日本語）: キャンバススクロールインジケータ初期化関数
    /// 処理概要: 表示軸を保持し、薄い rounded thumb として layer を設定します。
    ///
    /// - Parameter axis: indicator が担当するスクロール方向。
    init(axis: CanvasScrollIndicatorAxis) {
        self.axis = axis
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.72, alpha: 0.78).cgColor
        layer?.borderColor = NSColor.black.withAlphaComponent(0.16).cgColor
        layer?.borderWidth = 0.5
        layer?.cornerRadius = CanvasOverlayScrollView.indicatorThickness / 2
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// 論理名（日本語）: 初回クリック許可関数
    /// 処理概要: 非アクティブウインドウ上でも indicator の drag 開始を受け取れるようにします。
    ///
    /// - Parameter event: クリックイベント。
    /// - Returns: 常に `true`。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// 論理名（日本語）: マウスドラッグ開始関数
    /// 処理概要: indicator の drag を親スクロールビューへ委譲します。
    ///
    /// - Parameter event: drag 開始イベント。
    override func mouseDown(with event: NSEvent) {
        owningScrollView?.dragIndicator(axis, starting: event)
    }
}

/// 論理名（日本語）: キャンバスオーバーレイスクロールビュー
/// 概要: 標準 scroller を隠し、スクロール挙動を保ったまま薄い独自 indicator だけを表示します。
///
/// プロパティ:
/// - `verticalIndicator`: 縦スクロール位置を示す overlay thumb。
/// - `horizontalIndicator`: 横スクロール位置を示す overlay thumb。
private final class CanvasOverlayScrollView: NSScrollView {
    static let indicatorThickness: CGFloat = 5

    private static let indicatorInset: CGFloat = 5
    private static let minimumIndicatorLength: CGFloat = 42

    var overlayAvoidance = CanvasOverlayAvoidance() {
        didSet {
            guard overlayAvoidance != oldValue else { return }
            refreshScrollIndicators()
        }
    }

    var viewportDidChange: (() -> Void)?

    private let verticalIndicator = CanvasScrollIndicatorView(axis: .vertical)
    private let horizontalIndicator = CanvasScrollIndicatorView(axis: .horizontal)
    private var scrollActivityGeneration = 0
    private var isScrollActivityActive = false

    /// 論理名（日本語）: キャンバスオーバーレイスクロールビュー初期化関数
    /// 処理概要: overlay indicator を subview として追加し、初期表示を非表示にします。
    ///
    /// - Parameter frameRect: 初期 frame。
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureIndicators()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        setScrollActivityActive(false)
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: scrollView のサイズ変更に合わせて独自 indicator の位置を更新します。
    override func layout() {
        super.layout()
        refreshScrollIndicators()
        viewportDidChange?()
    }

    /// 論理名（日本語）: クリップビュー反映関数
    /// 処理概要: documentView のスクロール位置変更後に独自 indicator を追従させます。
    ///
    /// - Parameter clipView: スクロール位置が変化した clip view。
    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        refreshScrollIndicators()
        viewportDidChange?()
    }

    /// 論理名（日本語）: スクロールホイール処理関数
    /// 処理概要: スクロール前に必要な余白を追加し、wheel 中は戻り方向の余白縮小を行わず indicator を更新します。
    ///
    /// - Parameter event: scroll wheel イベント。
    override func scrollWheel(with event: NSEvent) {
        setScrollActivityActive(true)
        let scrollIntent = scrollIntent(for: event)
        applyInfiniteCanvasAdjustment(
            scrollIntent: scrollIntent,
            allowsExpansion: true,
            allowsContraction: false
        )
        super.scrollWheel(with: event)
        refreshScrollIndicators()
        scheduleScrollActivityReset()
    }

    /// 論理名（日本語）: スクロール活動状態更新関数
    /// 処理概要: wheel scroll が開始または終了したことを selection chrome へ通知します。
    ///
    /// - Parameter isActive: scroll 中の場合は `true`。
    private func setScrollActivityActive(_ isActive: Bool) {
        guard isScrollActivityActive != isActive else { return }
        isScrollActivityActive = isActive
        NotificationCenter.default.post(
            name: .canvasScrollActivityDidChange,
            object: self,
            userInfo: [CanvasScrollActivityNotificationKey.isActive: isActive]
        )
    }

    /// 論理名（日本語）: スクロール活動終了予約関数
    /// 処理概要: 連続 wheel event の最後から短時間後に scroll 中状態を解除します。
    private func scheduleScrollActivityReset() {
        scrollActivityGeneration += 1
        let generation = scrollActivityGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(140)) { [weak self] in
            guard let self, scrollActivityGeneration == generation else { return }
            setScrollActivityActive(false)
        }
    }

    /// 論理名（日本語）: スクロールインジケータ更新関数
    /// 処理概要: 現在の viewport と documentView サイズから thin overlay thumb の frame を再計算します。
    func refreshScrollIndicators() {
        updateIndicator(verticalIndicator, placement: indicatorPlacement(for: .vertical))
        updateIndicator(horizontalIndicator, placement: indicatorPlacement(for: .horizontal))
    }

    /// 論理名（日本語）: インジケータドラッグ関数
    /// 処理概要: 独自 indicator の drag 量を documentView のスクロール位置へ変換します。
    ///
    /// - Parameters:
    ///   - axis: drag された indicator の軸。
    ///   - event: drag 開始イベント。
    fileprivate func dragIndicator(_ axis: CanvasScrollIndicatorAxis, starting event: NSEvent) {
        guard let window,
              let placement = indicatorPlacement(for: axis),
              placement.indicatorTravel > 0,
              placement.contentTravel > 0
        else {
            return
        }

        let startLocation = convert(event.locationInWindow, from: nil)
        let startOrigin = contentView.bounds.origin

        while let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if nextEvent.type == .leftMouseUp {
                break
            }

            let currentLocation = convert(nextEvent.locationInWindow, from: nil)
            let dragDelta = CGPoint(
                x: currentLocation.x - startLocation.x,
                y: currentLocation.y - startLocation.y
            )
            scrollDocument(axis, from: startOrigin, dragDelta: dragDelta, placement: placement)
        }
    }

    /// 論理名（日本語）: インジケータ初期設定関数
    /// 処理概要: overlay indicator の親参照と subview 順序を設定します。
    private func configureIndicators() {
        verticalIndicator.owningScrollView = self
        horizontalIndicator.owningScrollView = self
        verticalIndicator.isHidden = true
        horizontalIndicator.isHidden = true
        addSubview(verticalIndicator, positioned: .above, relativeTo: nil)
        addSubview(horizontalIndicator, positioned: .above, relativeTo: nil)
    }

    /// 論理名（日本語）: 無限キャンバス調整適用関数
    /// 処理概要: documentView へスクロール方向を渡し、余白の追加・削除に合わせて clip origin を補正します。
    ///
    /// - Parameters:
    ///   - scrollIntent: スクロールしたい方向。正の X/Y は右/下、負の X/Y は左/上。
    ///   - allowsExpansion: 端方向への余白追加を許可するか。
    ///   - allowsContraction: 戻り方向で未使用余白の削除を許可するか。
    private func applyInfiniteCanvasAdjustment(
        scrollIntent: CGPoint,
        allowsExpansion: Bool,
        allowsContraction: Bool
    ) {
        guard scrollIntent != .zero,
              let documentView = documentView as? CanvasInfiniteDocumentContainer
        else {
            return
        }

        let adjustment = documentView.adjustCanvasIfNeeded(
            visibleRect: contentView.bounds,
            scrollIntent: scrollIntent,
            allowsExpansion: allowsExpansion,
            allowsContraction: allowsContraction
        )

        if adjustment.originAdjustment != .zero {
            contentView.scroll(
                to: clampedDocumentOrigin(
                    CGPoint(
                        x: contentView.bounds.origin.x + adjustment.originAdjustment.x,
                        y: contentView.bounds.origin.y + adjustment.originAdjustment.y
                    )
                )
            )
            reflectScrolledClipView(contentView)
        } else if adjustment.didResize {
            reflectScrolledClipView(contentView)
        }
    }

    /// 論理名（日本語）: スクロール意図取得関数
    /// 処理概要: AppKit の wheel delta をキャンバス content origin の移動方向へ変換します。
    ///
    /// - Parameter event: scroll wheel イベント。
    /// - Returns: 正の X/Y を右/下、負の X/Y を左/上とする方向ベクトル。
    private func scrollIntent(for event: NSEvent) -> CGPoint {
        CGPoint(
            x: -axisScrollDelta(
                precise: event.scrollingDeltaX,
                legacy: event.deltaX,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
            ),
            y: -axisScrollDelta(
                precise: event.scrollingDeltaY,
                legacy: event.deltaY,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
            )
        )
    }

    /// 論理名（日本語）: 軸別スクロール差分取得関数
    /// 処理概要: precise delta が有効なら優先し、なければ legacy delta を利用します。
    ///
    /// - Parameters:
    ///   - precise: precise scrolling delta。
    ///   - legacy: legacy delta。
    ///   - hasPreciseScrollingDeltas: precise delta が有効なイベントか。
    /// - Returns: 採用した差分値。
    private func axisScrollDelta(
        precise: CGFloat,
        legacy: CGFloat,
        hasPreciseScrollingDeltas: Bool
    ) -> CGFloat {
        if hasPreciseScrollingDeltas, precise != 0 {
            return precise
        }

        if legacy != 0 {
            return legacy
        }

        return precise
    }

    /// 論理名（日本語）: ドキュメント原点制限関数
    /// 処理概要: documentView サイズを超えない範囲へ clip origin を丸めます。
    ///
    /// - Parameter origin: 補正前の clip origin。
    /// - Returns: documentView 内に収まる clip origin。
    private func clampedDocumentOrigin(_ origin: CGPoint) -> CGPoint {
        guard let documentView else { return origin }

        return CGPoint(
            x: min(max(origin.x, 0), max(documentView.frame.width - contentView.bounds.width, 0)),
            y: min(max(origin.y, 0), max(documentView.frame.height - contentView.bounds.height, 0))
        )
    }

    /// 論理名（日本語）: インジケータ表示更新関数
    /// 処理概要: placement が存在する場合だけ indicator を表示し、frame と corner radius を反映します。
    ///
    /// - Parameters:
    ///   - indicator: 更新対象の indicator view。
    ///   - placement: 表示位置。スクロール不要な軸では `nil`。
    private func updateIndicator(
        _ indicator: CanvasScrollIndicatorView,
        placement: CanvasScrollIndicatorPlacement?
    ) {
        guard let placement else {
            if !indicator.isHidden {
                indicator.isHidden = true
            }
            return
        }

        let nextFrame = placement.frame.integral
        if indicator.isHidden {
            indicator.isHidden = false
        }
        if indicator.frame != nextFrame {
            indicator.frame = nextFrame
        }

        let nextCornerRadius = min(indicator.bounds.width, indicator.bounds.height) / 2
        if indicator.layer?.cornerRadius != nextCornerRadius {
            indicator.layer?.cornerRadius = nextCornerRadius
        }
    }

    /// 論理名（日本語）: インジケータ配置計算関数
    /// 処理概要: 指定軸のスクロール可能量と viewport 比率から thin thumb の位置を計算します。
    ///
    /// - Parameter axis: 計算対象の indicator 軸。
    /// - Returns: 表示する配置情報。スクロール不要な場合は `nil`。
    private func indicatorPlacement(for axis: CanvasScrollIndicatorAxis) -> CanvasScrollIndicatorPlacement? {
        guard let documentView else { return nil }

        let viewportSize = contentView.bounds.size
        let documentSize = documentView.frame.size
        let horizontalContentTravel = max(documentSize.width - viewportSize.width, 0)
        let verticalContentTravel = max(documentSize.height - viewportSize.height, 0)
        let showsHorizontalIndicator = horizontalContentTravel > 1
        let showsVerticalIndicator = verticalContentTravel > 1

        switch axis {
        case .vertical:
            guard showsVerticalIndicator else { return nil }
            let horizontalReservedLength = showsHorizontalIndicator ? Self.indicatorThickness + Self.indicatorInset : 0
            let trackStartY = isFlipped ? overlayAvoidance.top + Self.indicatorInset : Self.indicatorInset + horizontalReservedLength
            let trackEndY = isFlipped ? bounds.height - Self.indicatorInset - horizontalReservedLength : bounds.height - overlayAvoidance.top - Self.indicatorInset
            let trackLength = max(trackEndY - trackStartY, 1)
            let indicatorLength = min(
                trackLength,
                max(Self.minimumIndicatorLength, trackLength * viewportSize.height / max(documentSize.height, 1))
            )
            let indicatorTravel = max(trackLength - indicatorLength, 0)
            let scrollOffset = min(max(contentView.bounds.origin.y, 0), verticalContentTravel)
            let progress = verticalContentTravel > 0 ? scrollOffset / verticalContentTravel : 0
            let originY: CGFloat
            if isFlipped {
                originY = trackStartY + progress * indicatorTravel
            } else {
                originY = trackEndY - indicatorLength - progress * indicatorTravel
            }

            return CanvasScrollIndicatorPlacement(
                frame: CGRect(
                    x: bounds.width - overlayAvoidance.trailing - Self.indicatorInset - Self.indicatorThickness,
                    y: originY,
                    width: Self.indicatorThickness,
                    height: indicatorLength
                ),
                indicatorTravel: indicatorTravel,
                contentTravel: verticalContentTravel
            )

        case .horizontal:
            guard showsHorizontalIndicator else { return nil }
            let trackMinX = overlayAvoidance.leading + Self.indicatorInset
            let trackMaxX = bounds.width - overlayAvoidance.trailing - Self.indicatorInset - (showsVerticalIndicator ? Self.indicatorThickness + Self.indicatorInset : 0)
            let trackLength = max(trackMaxX - trackMinX, 1)
            let indicatorLength = min(
                trackLength,
                max(Self.minimumIndicatorLength, trackLength * viewportSize.width / max(documentSize.width, 1))
            )
            let indicatorTravel = max(trackLength - indicatorLength, 0)
            let scrollOffset = min(max(contentView.bounds.origin.x, 0), horizontalContentTravel)
            let progress = horizontalContentTravel > 0 ? scrollOffset / horizontalContentTravel : 0
            let originX = trackMinX + progress * indicatorTravel

            return CanvasScrollIndicatorPlacement(
                frame: CGRect(
                    x: originX,
                    y: isFlipped ? bounds.height - Self.indicatorInset - Self.indicatorThickness : Self.indicatorInset,
                    width: indicatorLength,
                    height: Self.indicatorThickness
                ),
                indicatorTravel: indicatorTravel,
                contentTravel: horizontalContentTravel
            )
        }
    }

    /// 論理名（日本語）: ドキュメントスクロール反映関数
    /// 処理概要: indicator の drag 差分を documentView の clip 原点へ反映します。
    ///
    /// - Parameters:
    ///   - axis: 反映対象のスクロール軸。
    ///   - startOrigin: drag 開始時点の clip 原点。
    ///   - dragDelta: indicator の drag 差分。
    ///   - placement: drag 換算用の配置情報。
    private func scrollDocument(
        _ axis: CanvasScrollIndicatorAxis,
        from startOrigin: CGPoint,
        dragDelta: CGPoint,
        placement: CanvasScrollIndicatorPlacement
    ) {
        var newOrigin = contentView.bounds.origin

        switch axis {
        case .vertical:
            let contentDelta = -(dragDelta.y / placement.indicatorTravel) * placement.contentTravel
            newOrigin.y = min(max(startOrigin.y + contentDelta, 0), placement.contentTravel)
        case .horizontal:
            let contentDelta = (dragDelta.x / placement.indicatorTravel) * placement.contentTravel
            newOrigin.x = min(max(startOrigin.x + contentDelta, 0), placement.contentTravel)
        }

        contentView.scroll(to: newOrigin)
        reflectScrolledClipView(contentView)
        refreshScrollIndicators()
    }
}

/// 論理名（日本語）: キャンバスツールパレット
/// 概要: HTML 編集ツール、`.ogp` 専用の付箋・ペン・消しゴム・なげわ、ハンドを縦型ツールバーとして表示します。
///
/// プロパティ:
/// - `activeTool`: 現在選択中のキャンバスツール。
private struct CanvasToolPalette: View {
    @Binding var activeTool: CanvasTool

    var body: some View {
        VStack(spacing: 6) {
            ForEach(CanvasTool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    OpenGraphiteIconView(icon: .canvasTool(tool), size: 16)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(activeTool == tool ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(activeTool == tool ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(activeTool == tool ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .help(tool.title)
                .accessibilityLabel(tool.title)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}
