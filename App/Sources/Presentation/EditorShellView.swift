import AppKit
import SwiftUI
import WebKit

/// 論理名（日本語）: エディターシェルビュー
/// 概要: 全面 Canvas の上に Sidebar と Inspector を重ねる編集画面のルートビューです。
struct EditorShellView: View {
    @SceneStorage("editorShell.isSidebarVisible") private var isSidebarVisible = true
    @SceneStorage("editorShell.isInspectorVisible") private var isInspectorVisible = true

    var body: some View {
        ZStack(alignment: .top) {
            CanvasPaneView(
                isSidebarVisible: isSidebarVisible,
                isInspectorVisible: isInspectorVisible
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            EditorCanvasSeparator(
                isSidebarVisible: isSidebarVisible,
                isInspectorVisible: isInspectorVisible
            )
            .padding(.top, EditorOverlayMetrics.topChromeHeight)
            .zIndex(5)

            if isSidebarVisible {
                EditorOverlayColumn(
                    width: EditorOverlayMetrics.sidebarWidth,
                    edge: .leading
                ) {
                    SidebarView()
                }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            }

            if isInspectorVisible {
                EditorOverlayColumn(
                    width: EditorOverlayMetrics.inspectorWidth,
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

/// 論理名（日本語）: エディターオーバーレイカラム
/// 概要: Sidebar/Inspector をウインドウ全高の固定幅サーフェスとして Canvas 上に重ねます。
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
/// - `onToggleSidebar`: 左カラム表示を切り替える処理。
/// - `onToggleInspector`: 右カラム表示を切り替える処理。
private struct EditorTopChromeView: View {
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool
    var onToggleSidebar: () -> Void
    var onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                EditorChromeIconButton(
                    systemImage: "sidebar.left",
                    isActive: isSidebarVisible,
                    help: isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                    action: onToggleSidebar
                )

                Spacer(minLength: 0)
            }
            .padding(.leading, EditorOverlayMetrics.trafficLightReservedWidth)
            .padding(.trailing, EditorOverlayMetrics.chromeControlInset)
            .frame(width: leadingChromeWidth, alignment: .leading)

            HStack(spacing: 8) {
                EditorProjectSummaryView()
                    .layoutPriority(1)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                EditorChromeIconButton(
                    systemImage: "sidebar.right",
                    isActive: isInspectorVisible,
                    help: isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                    action: onToggleInspector
                )
            }
            .padding(.leading, EditorOverlayMetrics.chromeControlInset)
            .padding(.trailing, EditorOverlayMetrics.chromeControlInset)
            .frame(width: trailingChromeWidth, alignment: .trailing)
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
        isSidebarVisible ? EditorOverlayMetrics.sidebarWidth : EditorOverlayMetrics.collapsedLeadingChromeWidth
    }

    private var trailingChromeWidth: CGFloat {
        isInspectorVisible ? EditorOverlayMetrics.inspectorWidth : EditorOverlayMetrics.collapsedTrailingChromeWidth
    }
}

/// 論理名（日本語）: エディタークロームアイコンボタン
/// 概要: 上部クロームで使う薄型のアイコンボタンです。
///
/// プロパティ:
/// - `systemImage`: SF Symbols 名。
/// - `isActive`: 有効状態として背景を出すか。
/// - `help`: ヘルプとアクセシビリティラベル。
/// - `action`: 押下時に実行する処理。
private struct EditorChromeIconButton: View {
    var systemImage: String
    var isActive = false
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
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
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool

    var body: some View {
        Rectangle()
            .fill(EditorColumnStyle.separatorColor)
            .frame(height: 1)
            .padding(.leading, isSidebarVisible ? EditorOverlayMetrics.sidebarWidth : 0)
            .padding(.trailing, isInspectorVisible ? EditorOverlayMetrics.inspectorWidth : 0)
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
    var isSidebarVisible: Bool
    var isInspectorVisible: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let loadedProject = store.loadedProject, !store.selectedCanvasPages.isEmpty {
                ZoomableCanvasScrollView(
                    zoom: $store.zoom,
                    documentID: canvasDocumentID(for: loadedProject, segment: store.selectedCanvasSegment, pages: store.selectedCanvasPages),
                    overlayAvoidance: overlayAvoidance,
                    onEmptyCanvasClick: {
                        store.selectPage(id: nil)
                    }
                ) {
                    CanvasProjectView(
                        store: store,
                        loadedProject: loadedProject,
                        pages: store.selectedCanvasPages,
                        zoom: store.zoom
                    )
                }

                CanvasToolPalette(activeTool: $store.activeTool)
                    .padding(.leading, overlayAvoidance.leading + 14)
                    .padding(.top, overlayAvoidance.top + 14)
                    .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.leading)
                    .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.top)

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
                .padding(.top, overlayAvoidance.top + 14)
                .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.trailing)
                .animation(.easeInOut(duration: 0.16), value: overlayAvoidance.top)
        }
    }

    private var overlayAvoidance: CanvasOverlayAvoidance {
        CanvasOverlayAvoidance(
            leading: isSidebarVisible ? EditorOverlayMetrics.sidebarWidth : 0,
            trailing: isInspectorVisible ? EditorOverlayMetrics.inspectorWidth : 0,
            top: EditorOverlayMetrics.topChromeHeight
        )
    }

    /// 論理名（日本語）: キャンバスドキュメントID生成関数
    /// 処理概要: 選択セグメントのページ構成と配置が変わったときにスクロール document を作り直す識別子を生成します。
    ///
    /// - Parameters:
    ///   - project: 表示中の読み込み済みプロジェクト。
    ///   - segment: 表示中の Pages / Components セグメント。
    ///   - pages: 表示対象ページ一覧。
    /// - Returns: キャンバス構成を表す安定 ID。
    private func canvasDocumentID(for project: LoadedOpenGraphiteProject, segment: OpenGraphiteCanvasSegment, pages: [OpenGraphitePage]) -> String {
        let pageID = pages
            .map { page in
                "\(page.internalID):\(page.id):\(page.canvas.x):\(page.canvas.y):\(page.canvas.width):\(page.canvas.height)"
            }
            .joined(separator: "|")
        return "\(project.fileURL.path)#\(segment.rawValue)#\(pageID)"
    }

    /// 論理名（日本語）: ズーム調整関数
    /// 処理概要: HUD ボタン操作に応じてズーム倍率を許容範囲内で増減します。
    ///
    /// - Parameter delta: 追加するズーム倍率差分。
    private func adjustZoom(by delta: Double) {
        withAnimation(.easeOut(duration: 0.12)) {
            store.zoom = CanvasZoom.clamped(store.zoom + delta)
        }
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
    @State private var hoveredFlowTargetPageID: String?

    var body: some View {
        let bounds = CanvasProjectBounds(pages: pages)
        let scale = CGFloat(zoom)
        let isFlowHoverEnabled = store.previewDisplayMode == .flow && store.selectedCanvasSegment == .pages
        let flowConnections = isFlowHoverEnabled ? OpenGraphiteStaticFlowResolver.connections(
            pages: pages,
            loadedProject: loadedProject,
            linksByPageURL: store.staticFlowLinksByPageURL
        ) : []

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    store.selectPage(id: nil)
                }

            ForEach(pages, id: \.internalID) { page in
                CanvasDocumentView(
                    store: store,
                    page: page,
                    pageURL: loadedProject.htmlURL(for: page),
                    isSelected: page.internalID == store.selectedPage?.internalID,
                    reloadToken: store.reloadToken(for: loadedProject.htmlURL(for: page)),
                    isFlowHoverEnabled: isFlowHoverEnabled,
                    onFlowTargetPageHover: handleFlowTargetPageHover
                )
                .offset(
                    x: CGFloat(page.canvas.x) - bounds.minX,
                    y: CGFloat(page.canvas.y) - bounds.minY
                )
            }

            if store.previewDisplayMode == .flow, store.selectedCanvasSegment == .pages {
                CanvasStaticFlowOverlay(
                    connections: flowConnections,
                    hoveredSource: store.hoveredStaticFlowSource,
                    hoveredTargetPageID: hoveredFlowTargetPageID,
                    selectedSourcePageURL: store.selectedCanvasSegment == .pages ? store.selectedPageURL?.standardizedFileURL : nil,
                    selectedSourceNodeID: store.selectedCanvasSegment == .pages ? store.selectedNodeID : nil,
                    selectedTargetPageID: store.selectedCanvasSegment == .pages && store.selectedNodeID == nil ? store.selectedPage?.id : nil
                )
                .allowsHitTesting(false)
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
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
        .frame(width: bounds.width * scale, height: bounds.height * scale, alignment: .topLeading)
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
            hoveredFlowTargetPageID = nil
            store.ingestStaticFlowSourceHoverPayload(
                [
                    "id": sourceConnection.link.id,
                    "sourceNodeID": sourceConnection.link.sourceNodeID
                ],
                pageURL: sourceConnection.sourcePageURL
            )
            return
        }

        store.clearStaticFlowSourceHover()
        hoveredFlowTargetPageID = pages.first { page in
            pageRect(for: page, in: bounds).contains(location)
        }?.id
    }

    /// 論理名（日本語）: フロー遷移先ページホバー処理関数
    /// 処理概要: ページプレビュー上の hover 状態を保持し、受け側 page に入る接続線の強調対象を更新します。
    ///
    /// - Parameters:
    ///   - pageID: hover 状態が変化した page ID。
    ///   - isHovering: ポインタが page 上にある場合は `true`。
    private func handleFlowTargetPageHover(pageID: String, isHovering: Bool) {
        guard store.previewDisplayMode == .flow, store.selectedCanvasSegment == .pages else {
            clearFlowHoverState()
            return
        }

        if isHovering {
            hoveredFlowTargetPageID = pageID
        } else if hoveredFlowTargetPageID == pageID {
            hoveredFlowTargetPageID = nil
        }
    }

    /// 論理名（日本語）: フローhover状態解除関数
    /// 処理概要: フロー表示から離れたときに source/target の hover 強調状態をまとめて解除します。
    private func clearFlowHoverState() {
        hoveredFlowTargetPageID = nil
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
            y: CGFloat(page.canvas.y) - bounds.minY,
            width: CGFloat(page.canvas.width),
            height: CGFloat(page.canvas.height)
        )
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
/// - `reloadToken`: 外部変更時に WebView を再読み込みするためのトークン。
/// - `isFlowHoverEnabled`: フロー表示用の受け側 page hover を通知するか。
/// - `onFlowTargetPageHover`: page hover 状態が変わったときに呼ぶ処理。
private struct CanvasDocumentView: View {
    @ObservedObject var store: EditorStore
    var page: OpenGraphitePage
    var pageURL: URL
    var isSelected: Bool
    var reloadToken: Int
    var isFlowHoverEnabled: Bool
    var onFlowTargetPageHover: (String, Bool) -> Void

    var body: some View {
        let width = max(CGFloat(page.canvas.width), 1)
        let height = max(CGFloat(page.canvas.height), 1)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .frame(width: width, height: height)

            WebCanvasView(
                store: store,
                pageURL: pageURL,
                syncTarget: store.htmlSyncTarget(for: page, segment: store.selectedCanvasSegment),
                isInteractive: isSelected,
                reloadToken: reloadToken
            )
                .frame(width: width, height: height)
                .allowsHitTesting(isSelected)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            CanvasPageNameCard(
                title: page.id,
                placementName: page.canvas.displayName,
                path: page.path,
                resolution: page.canvas.resolutionLabel,
                isSelected: isSelected,
                maxTextWidth: max(
                    min(width, CanvasMetrics.pageNameCardMaxTextWidth),
                    CanvasMetrics.pageNameCardMinTextWidth
                )
            )
            .onTapGesture {
                store.selectPage(internalID: page.internalID)
            }
            .contextMenu {
                Button("参照IDをコピー") {
                    store.selectPage(internalID: page.internalID)
                    store.copyPageReferenceIDToPasteboard(page, segment: store.selectedCanvasSegment)
                }
            }
            .onCopyCommand {
                guard isSelected, store.selectedNodeID == nil else { return [] }
                return OpenGraphiteReferenceCopy.itemProviders(
                    for: store.pageReferenceID(for: page, segment: store.selectedCanvasSegment)
                )
            }
            .offset(y: -CanvasMetrics.pageNameCardOutsideOffset)
        }
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 3 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectPage(internalID: page.internalID)
        }
        .contextMenu {
            Button("参照IDをコピー") {
                store.selectPage(internalID: page.internalID)
                store.copyPageReferenceIDToPasteboard(page, segment: store.selectedCanvasSegment)
            }
        }
        .onCopyCommand {
            guard isSelected, store.selectedNodeID == nil else { return [] }
            return OpenGraphiteReferenceCopy.itemProviders(
                for: store.pageReferenceID(for: page, segment: store.selectedCanvasSegment)
            )
        }
        .onHover { isHovering in
            guard isFlowHoverEnabled else { return }
            onFlowTargetPageHover(page.id, isHovering)
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
                        Image(systemName: option.systemImage)
                            .font(.system(size: 12, weight: .semibold))
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
/// - `hoveredTargetPageID`: ホバー中の遷移先 page ID。該当 page への接続を不透明にします。
/// - `selectedSourcePageURL`: 選択中ノードを含む HTML page の URL。
/// - `selectedSourceNodeID`: 選択中ノード ID。遷移元リンクと一致する接続を不透明にします。
/// - `selectedTargetPageID`: 選択中 page ID。受け側 page と一致する接続を不透明にします。
private struct CanvasStaticFlowOverlay: View {
    var connections: [OpenGraphiteStaticFlowConnection]
    var hoveredSource: OpenGraphiteStaticFlowSourceHover?
    var hoveredTargetPageID: String?
    var selectedSourcePageURL: URL?
    var selectedSourceNodeID: String?
    var selectedTargetPageID: String?

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
        .animation(.easeOut(duration: 0.12), value: hoveredTargetPageID)
        .animation(.easeOut(duration: 0.12), value: selectedSourcePageURL)
        .animation(.easeOut(duration: 0.12), value: selectedSourceNodeID)
        .animation(.easeOut(duration: 0.12), value: selectedTargetPageID)
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
           connection.link.id == hoveredSource.linkID {
            return true
        }

        if let hoveredTargetPageID, connection.targetPageID == hoveredTargetPageID {
            return true
        }

        if let selectedSourcePageURL,
           let selectedSourceNodeID,
           connection.sourcePageURL == selectedSourcePageURL,
           connection.link.sourceNodeID == selectedSourceNodeID {
            return true
        }

        if let selectedTargetPageID, connection.targetPageID == selectedTargetPageID {
            return true
        }

        return false
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
            .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
            .help("\(title) · \(detailText)")
            .accessibilityLabel("\(title), \(detailText)")
    }

    private var detailText: String {
        ([placementName, path, resolution].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }).joined(separator: " · ")
    }
}

/// 論理名（日本語）: キャンバスプロジェクト境界
/// 概要: 選択 Chapter 内のページ配置から表示対象ページを含む矩形を計算します。
///
/// プロパティ:
/// - `minX`: 最小 X 座標。
/// - `minY`: 最小 Y 座標。
/// - `width`: 表示対象ページを含む幅。
/// - `height`: 表示対象ページを含む高さ。
private struct CanvasProjectBounds {
    var minX: CGFloat
    var minY: CGFloat
    var width: CGFloat
    var height: CGFloat

    /// 論理名（日本語）: キャンバスプロジェクト境界初期化関数
    /// 処理概要: ページ一覧の canvas 矩形から包含境界を計算します。
    ///
    /// - Parameter pages: 境界計算対象のページ一覧。
    init(pages: [OpenGraphitePage]) {
        guard !pages.isEmpty else {
            minX = 0
            minY = 0
            width = 1
            height = 1
            return
        }

        let minX = pages.map { CGFloat($0.canvas.x) }.min() ?? 0
        let minY = pages.map { CGFloat($0.canvas.y) }.min() ?? 0
        let maxX = pages.map { CGFloat($0.canvas.x + $0.canvas.width) }.max() ?? 1
        let maxY = pages.map { CGFloat($0.canvas.y + $0.canvas.height) }.max() ?? 1

        self.minX = minX
        self.minY = minY
        self.width = max(maxX - minX, 1)
        self.height = max(maxY - minY, 1)
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
private enum CanvasMetrics {
    static let documentPadding: CGFloat = 72
    static let projectCoordinateSpaceName = "OpenGraphiteCanvasProject"
    static let pageNameCardHeight: CGFloat = 44
    static let pageNameCardGap: CGFloat = 8
    static let pageNameCardHorizontalInset: CGFloat = 10
    static let pageNameCardMinTextWidth: CGFloat = 176
    static let pageNameCardMaxTextWidth: CGFloat = 280
    static let pageNameCardOutsideOffset = pageNameCardHeight + pageNameCardGap
}

/// 論理名（日本語）: キャンバスオーバーレイ回避値
/// 概要: Canvas の描画座標を保ったまま操作 UI だけ左右カラムを避けるための余白です。
///
/// プロパティ:
/// - `leading`: 左カラムに隠れないための左側回避幅。
/// - `trailing`: 右カラムに隠れないための右側回避幅。
/// - `top`: 上部クロームに隠れないための上側回避幅。
private struct CanvasOverlayAvoidance: Equatable {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
    var top: CGFloat = 0
}

/// 論理名（日本語）: キャンバスズーム設定
/// 概要: キャンバス倍率の範囲、ボタン単位、表示文字列生成をまとめます。
///
/// 定義内容:
/// - `range`: 許容ズーム範囲。
/// - `buttonStep`: HUD ボタンのズーム差分。
private enum CanvasZoom {
    static let range: ClosedRange<Double> = 0.10...2.0
    static let buttonStep = 0.1

    /// 論理名（日本語）: ズーム範囲補正関数
    /// 処理概要: 任意の倍率を OpenGraphite が許可する範囲に丸めます。
    ///
    /// - Parameter value: 補正前の倍率。
    /// - Returns: 許容範囲内へ補正された倍率。
    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
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

/// 論理名（日本語）: ズーム可能キャンバススクロールビュー
/// 概要: SwiftUI のキャンバス内容を `NSScrollView` へ載せ、スクロールとズーム入力を AppKit 側で制御します。
///
/// プロパティ:
/// - `zoom`: 双方向バインディングされたキャンバス倍率。
/// - `documentID`: 表示中ドキュメントの識別子。
/// - `onEmptyCanvasClick`: ページ群の外側がクリックされたときの処理。
/// - `content`: スクロールビュー内に表示する SwiftUI content。
private struct ZoomableCanvasScrollView<Content: View>: NSViewRepresentable {
    @Binding var zoom: Double
    var documentID: String
    var overlayAvoidance: CanvasOverlayAvoidance
    var onEmptyCanvasClick: () -> Void
    var content: () -> Content

    /// 論理名（日本語）: ズーム可能スクロールビュー初期化関数
    /// 処理概要: ズームバインディング、ドキュメント ID、表示 content を保持します。
    ///
    /// - Parameters:
    ///   - zoom: キャンバス倍率のバインディング。
    ///   - documentID: 表示中ドキュメントの識別子。
    ///   - overlayAvoidance: 左右カラムを避ける操作 UI 用余白。
    ///   - onEmptyCanvasClick: ページ群の外側がクリックされたときの処理。
    ///   - content: スクロールビュー内に表示する SwiftUI content。
    init(
        zoom: Binding<Double>,
        documentID: String,
        overlayAvoidance: CanvasOverlayAvoidance = CanvasOverlayAvoidance(),
        onEmptyCanvasClick: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._zoom = zoom
        self.documentID = documentID
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
            documentID: documentID,
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
        context.coordinator.onEmptyCanvasClick = onEmptyCanvasClick
        context.coordinator.updateContent(documentID: documentID, content: content)
        context.coordinator.refreshDocumentSizeIfNeeded()
        if let scrollView = scrollView as? CanvasOverlayScrollView {
            scrollView.overlayAvoidance = overlayAvoidance
            scrollView.refreshScrollIndicators()
        }
    }

    /// 論理名（日本語）: NSScrollView解体関数
    /// 処理概要: local event monitor を破棄して AppKit 入力監視を終了します。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象の NSScrollView。
    ///   - coordinator: 紐づくコーディネーター。
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
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
    final class Coordinator: NSObject {
        var zoom: Binding<Double>
        var content: () -> Content
        var onEmptyCanvasClick: () -> Void
        let hostingView: NSHostingView<Content>
        let documentView: CanvasInfiniteDocumentView<Content>

        private weak var scrollView: NSScrollView?
        private var monitor: Any?
        private var renderedDocumentID: String
        private var lastViewportSize: NSSize = .zero
        private var lastZoom: Double

        /// 論理名（日本語）: キャンバススクロールコーディネーター初期化関数
        /// 処理概要: ズームバインディング、ドキュメント ID、初期 content を hosting view に保持します。
        ///
        /// - Parameters:
        ///   - zoom: キャンバス倍率のバインディング。
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - onEmptyCanvasClick: ページ群の外側がクリックされたときの処理。
        ///   - content: 初期表示する SwiftUI content。
        init(
            zoom: Binding<Double>,
            documentID: String,
            onEmptyCanvasClick: @escaping () -> Void,
            content: @escaping () -> Content
        ) {
            self.zoom = zoom
            self.content = content
            self.onEmptyCanvasClick = onEmptyCanvasClick
            self.renderedDocumentID = documentID
            self.lastZoom = CanvasZoom.clamped(zoom.wrappedValue)
            self.hostingView = NSHostingView(rootView: content())
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
            guard monitor == nil else { return }

            let eventMask: NSEvent.EventTypeMask = [.scrollWheel, .magnify, .gesture]
            monitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
                guard let self, self.handleInputEvent(event) else {
                    return event
                }
                return nil
            }
        }

        /// 論理名（日本語）: content更新関数
        /// 処理概要: ドキュメント ID またはズームが変化したときに hosting view の rootView とサイズを更新します。
        ///
        /// - Parameters:
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - content: 新しい SwiftUI content。
        func updateContent(documentID: String, content: @escaping () -> Content) {
            self.content = content
            let currentZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let didChangeDocument = renderedDocumentID != documentID
            guard didChangeDocument || abs(lastZoom - currentZoom) > 0.0005 else { return }

            renderedDocumentID = documentID
            lastZoom = currentZoom
            hostingView.rootView = content()
            if didChangeDocument {
                resetDocumentViewPosition()
            }
            refreshDocumentSize(force: true)
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

        /// 論理名（日本語）: ドキュメント表示位置リセット関数
        /// 処理概要: 表示ページが切り替わったときに無限キャンバスの余白とスクロール位置を初期化します。
        private func resetDocumentViewPosition() {
            documentView.resetCanvasState()
            guard let scrollView else { return }

            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
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

            if event.type == .magnify {
                return handleMagnify(event)
            }

            if event.type == .gesture {
                return handleGesture(event)
            }

            if event.modifierFlags.contains(.command) {
                return handleCommandScroll(event)
            }

            return routeCanvasScrollIfNeeded(event, in: scrollView)
        }

        /// 論理名（日本語）: Commandスクロール処理関数
        /// 処理概要: `⌘ + scroll` をキャンバスズームへ変換します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: ズーム操作として消費した場合は `true`。
        private func handleCommandScroll(_ event: NSEvent) -> Bool {
            let verticalDelta = verticalScrollDelta(for: event)
            guard verticalDelta.value != 0 else { return false }

            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let scale = scaleFactor(for: verticalDelta.value, isPrecise: verticalDelta.isPrecise)
            let newZoom = CanvasZoom.clamped(oldZoom * scale)
            guard newZoom.isFinite, newZoom != oldZoom else { return true }

            zoom.wrappedValue = newZoom
            return true
        }

        /// 論理名（日本語）: magnifyイベント処理関数
        /// 処理概要: トラックパッドなどの magnify 値をキャンバスズームへ反映します。
        ///
        /// - Parameter event: magnify イベント。
        /// - Returns: ズーム操作として消費した場合は `true`。
        private func handleMagnify(_ event: NSEvent) -> Bool {
            applyMagnification(event.magnification)
        }

        /// 論理名（日本語）: gestureイベント処理関数
        /// 処理概要: Mac Mouse Fix などが発行する gesture subtype の magnification をズームへ反映します。
        ///
        /// - Parameter event: gesture イベント。
        /// - Returns: 対応する magnification を消費した場合は `true`。
        private func handleGesture(_ event: NSEvent) -> Bool {
            guard let cgEvent = event.cgEvent,
                  let subtypeField = CGEventField(rawValue: 110),
                  let magnificationField = CGEventField(rawValue: 113),
                  cgEvent.getIntegerValueField(subtypeField) == 8
            else {
                return false
            }

            return applyMagnification(CGFloat(cgEvent.getDoubleValueField(magnificationField)))
        }

        /// 論理名（日本語）: magnification適用関数
        /// 処理概要: 入力された magnification を倍率へ掛け合わせ、許容範囲内へ補正します。
        ///
        /// - Parameter magnification: AppKit または CGEvent 由来の拡大率差分。
        /// - Returns: OpenGraphite 側で処理した場合は `true`。
        private func applyMagnification(_ magnification: CGFloat) -> Bool {
            guard magnification != 0 else { return true }

            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let newZoom = CanvasZoom.clamped(oldZoom * (1 + Double(magnification)))
            guard newZoom.isFinite, newZoom != oldZoom else { return true }

            zoom.wrappedValue = newZoom
            return true
        }

        /// 論理名（日本語）: キャンバススクロールルーティング関数
        /// 処理概要: ポインタ直下の WebView がスクロールできない場合だけ外側 NSScrollView へイベントを渡します。
        ///
        /// - Parameters:
        ///   - event: scroll wheel イベント。
        ///   - scrollView: 外側のキャンバス NSScrollView。
        /// - Returns: 外側 scroll view へルーティングして消費した場合は `true`。
        private func routeCanvasScrollIfNeeded(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
            guard let webView = webViewUnderEvent(event, in: scrollView),
                  let scrollState = WebScrollStateRegistry.shared.state(for: webView),
                  scrollState.isInside
            else {
                return false
            }

            if let direction = dominantScrollDirection(for: event),
               scrollState.canScroll(direction) {
                return false
            }

            if dominantScrollDirection(for: event) == nil,
               scrollState.canScrollAnyDirection {
                return false
            }

            scrollView.scrollWheel(with: event)
            return true
        }

        /// 論理名（日本語）: スクロールビュー内イベント判定関数
        /// 処理概要: 入力イベントの window 座標が対象 NSScrollView の bounds 内か判定します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 対象 NSScrollView。
        /// - Returns: イベント位置が scroll view 内なら `true`。
        private func isEventInsideScrollView(_ event: NSEvent, scrollView: NSScrollView) -> Bool {
            scrollView.bounds.contains(scrollView.convert(event.locationInWindow, from: nil))
        }

        /// 論理名（日本語）: イベント直下WebView取得関数
        /// 処理概要: 入力イベント位置を hitTest し、祖先をたどって WKWebView を探します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 探索の基準となる NSScrollView。
        /// - Returns: ポインタ直下にある WKWebView。存在しない場合は `nil`。
        private func webViewUnderEvent(_ event: NSEvent, in scrollView: NSScrollView) -> WKWebView? {
            let point = scrollView.convert(event.locationInWindow, from: nil)
            var view = scrollView.hitTest(point)
            while let current = view {
                if let webView = current as? WKWebView {
                    return webView
                }
                view = current.superview
            }
            return nil
        }

        /// 論理名（日本語）: 主スクロール方向判定関数
        /// 処理概要: X/Y のスクロール差分から支配的なスクロール方向を決定します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: 主方向。差分がない場合は `nil`。
        private func dominantScrollDirection(for event: NSEvent) -> WebScrollDirection? {
            let delta = scrollDelta(for: event)
            let deltaX = delta.x
            let deltaY = delta.y
            guard deltaX != 0 || deltaY != 0 else { return nil }

            if abs(deltaX) > abs(deltaY) {
                return deltaX < 0 ? .right : .left
            }

            return deltaY < 0 ? .down : .up
        }

        /// 論理名（日本語）: スクロール差分取得関数
        /// 処理概要: precise delta と legacy delta を統合し、X/Y のスクロール差分を返します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: X/Y のスクロール差分。
        private func scrollDelta(for event: NSEvent) -> CGPoint {
            CGPoint(
                x: axisScrollDelta(precise: event.scrollingDeltaX, legacy: event.deltaX).value,
                y: axisScrollDelta(precise: event.scrollingDeltaY, legacy: event.deltaY).value
            )
        }

        /// 論理名（日本語）: 垂直スクロール差分取得関数
        /// 処理概要: ズーム計算に使う垂直方向のスクロール差分と precise 判定を返します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: 差分値と precise delta かどうか。
        private func verticalScrollDelta(for event: NSEvent) -> (value: CGFloat, isPrecise: Bool) {
            axisScrollDelta(
                precise: event.scrollingDeltaY,
                legacy: event.deltaY,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
            )
        }

        /// 論理名（日本語）: 軸別スクロール差分選択関数
        /// 処理概要: precise delta が有効なら優先し、なければ legacy delta を使用します。
        ///
        /// - Parameters:
        ///   - precise: precise scrolling delta。
        ///   - legacy: legacy delta。
        ///   - hasPreciseScrollingDeltas: precise delta が有効なイベントか。
        /// - Returns: 採用した差分値と precise 判定。
        private func axisScrollDelta(
            precise: CGFloat,
            legacy: CGFloat,
            hasPreciseScrollingDeltas: Bool = true
        ) -> (value: CGFloat, isPrecise: Bool) {
            if hasPreciseScrollingDeltas, precise != 0 {
                return (precise, true)
            }

            if legacy != 0 {
                return (legacy, false)
            }

            return (precise, hasPreciseScrollingDeltas)
        }

        /// 論理名（日本語）: ズーム倍率係数生成関数
        /// 処理概要: スクロール差分を指数関数の倍率係数へ変換し、小さな入力も捨てずに反映します。
        ///
        /// - Parameters:
        ///   - rawDelta: スクロール差分。
        ///   - isPrecise: precise delta 由来か。
        /// - Returns: 現在倍率へ掛ける倍率係数。
        private func scaleFactor(for rawDelta: CGFloat, isPrecise: Bool) -> Double {
            exp(Double(rawDelta) * (isPrecise ? 0.002 : 0.08))
        }

        deinit {
            dismantle()
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

/// 論理名（日本語）: キャンバス無限ドキュメントビュー
/// 概要: SwiftUI のキャンバス内容を保持し、スクロール方向に応じて documentView の余白を調整します。
///
/// プロパティ:
/// - `hostingView`: 実際の SwiftUI キャンバス内容。
/// - `emptyClickHandler`: SwiftUI content 外側の余白がクリックされたときの処理。
private final class CanvasInfiniteDocumentView<Content: View>: NSView, CanvasInfiniteDocumentContainer {
    private static var edgeExpansionTolerance: CGFloat { 4 }
    private static var minimumExpansionStep: CGFloat { 24 }
    private static var maximumExpansionStep: CGFloat { 320 }
    private static var contractionPadding: CGFloat { 160 }

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
            if scrollIntent.x < 0, visibleRect.minX <= Self.edgeExpansionTolerance {
                contentOrigin.x += horizontalExpansion
                newSize.width += horizontalExpansion
                adjustment.originAdjustment.x += horizontalExpansion
                shouldLayoutContent = true
            }

            if scrollIntent.x > 0, visibleRect.maxX >= frame.width - Self.edgeExpansionTolerance {
                newSize.width += horizontalExpansion
                adjustment.originAdjustment.x += horizontalExpansion
            }

            let verticalExpansion = expansionAmount(for: scrollIntent.y)
            if scrollIntent.y < 0, visibleRect.minY <= Self.edgeExpansionTolerance {
                contentOrigin.y += verticalExpansion
                newSize.height += verticalExpansion
                adjustment.originAdjustment.y += verticalExpansion
                shouldLayoutContent = true
            }

            if scrollIntent.y > 0, visibleRect.maxY >= frame.height - Self.edgeExpansionTolerance {
                newSize.height += verticalExpansion
                adjustment.originAdjustment.y += verticalExpansion
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
        min(max(abs(scrollDelta), Self.minimumExpansionStep), Self.maximumExpansionStep)
    }

    /// 論理名（日本語）: 先頭余白縮小量取得関数
    /// 処理概要: 表示範囲から外れた左または上の未使用余白量を計算します。
    ///
    /// - Parameters:
    ///   - currentLeadingInset: 現在の左または上の余白量。
    ///   - visibleStart: 対象軸の表示開始位置。
    /// - Returns: 削除できる余白量。
    private func leadingContractionAmount(currentLeadingInset: CGFloat, visibleStart: CGFloat) -> CGFloat {
        min(currentLeadingInset, max(visibleStart - Self.contractionPadding, 0))
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
        min(currentSize, max(minimumSize, visibleEnd + Self.contractionPadding))
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

    private let verticalIndicator = CanvasScrollIndicatorView(axis: .vertical)
    private let horizontalIndicator = CanvasScrollIndicatorView(axis: .horizontal)

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

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: scrollView のサイズ変更に合わせて独自 indicator の位置を更新します。
    override func layout() {
        super.layout()
        refreshScrollIndicators()
    }

    /// 論理名（日本語）: クリップビュー反映関数
    /// 処理概要: documentView のスクロール位置変更後に独自 indicator を追従させます。
    ///
    /// - Parameter clipView: スクロール位置が変化した clip view。
    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        refreshScrollIndicators()
    }

    /// 論理名（日本語）: スクロールホイール処理関数
    /// 処理概要: スクロール前に必要な余白を追加し、標準処理後に未使用余白と indicator を更新します。
    ///
    /// - Parameter event: scroll wheel イベント。
    override func scrollWheel(with event: NSEvent) {
        let scrollIntent = scrollIntent(for: event)
        applyInfiniteCanvasAdjustment(
            scrollIntent: scrollIntent,
            allowsExpansion: true,
            allowsContraction: true
        )
        super.scrollWheel(with: event)
        applyInfiniteCanvasAdjustment(
            scrollIntent: scrollIntent,
            allowsExpansion: false,
            allowsContraction: true
        )
        refreshScrollIndicators()
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
            indicator.isHidden = true
            return
        }

        indicator.isHidden = false
        indicator.frame = placement.frame.integral
        indicator.layer?.cornerRadius = min(indicator.bounds.width, indicator.bounds.height) / 2
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
/// 概要: 編集カーソル、レクトアングル、テキスト、フレーム、ハンドのツールを縦型ツールバーとして表示します。
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
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 15, weight: .medium))
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
