import SwiftUI

/// 論理名（日本語）: サイドバービュー
/// 概要: Chapters、Pages、Components を切り替え、各 HTML カード内でページや component canvas とレイヤー階層を選択する左ペインです。
struct SidebarView: View {
    @EnvironmentObject private var store: EditorStore
    @SceneStorage("sidebar.selectedPanel") private var selectedPanel = SidebarPanel.chapters.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarPanelSwitcher(selectedPanel: $selectedPanel)
                .padding(.top, EditorOverlayMetrics.titlebarInset)
                .padding(.horizontal, EditorColumnStyle.outerPadding)
                .padding(.bottom, 10)

            Group {
                if resolvedPanel == .chapters {
                    ChapterListView()
                } else if resolvedPanel == .pages {
                    PageListView()
                } else {
                    ComponentPageListView()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            normalizeSelectedPanel()
        }
        .onChange(of: selectedPanel) { _, _ in
            normalizeSelectedPanel()
        }
        .onChange(of: store.selectedNodeID) { _, newValue in
            if newValue != nil {
                selectedPanel = store.selectedCanvasSegment == .components
                    ? SidebarPanel.components.rawValue
                    : SidebarPanel.pages.rawValue
            }
        }
    }

    private var resolvedPanel: SidebarPanel {
        SidebarPanel(rawValue: selectedPanel) ?? .pages
    }

    /// 論理名（日本語）: サイドバーパネル正規化関数
    /// 処理概要: 旧バージョンの SceneStorage に残った Layers などの無効値を現在のパネルへ置き換えます。
    private func normalizeSelectedPanel() {
        if SidebarPanel(rawValue: selectedPanel) == nil {
            selectedPanel = store.selectedCanvasSegment == .components
                ? SidebarPanel.components.rawValue
                : SidebarPanel.pages.rawValue
        }
    }
}

/// 論理名（日本語）: サイドバーパネル切替ビュー
/// 概要: タイトルバー領域の下に Chapters、Pages、Components の切替ボタンを表示します。
///
/// プロパティ:
/// - `selectedPanel`: 現在選択中のパネル種別。
private struct SidebarPanelSwitcher: View {
    @Binding var selectedPanel: SidebarPanel.RawValue

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SidebarPanel.allCases) { panel in
                Button {
                    selectedPanel = panel.rawValue
                } label: {
                    Label(panel.title, systemImage: panel.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                .fill(selectedPanel == panel.rawValue ? EditorColumnStyle.selectedRowFill : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedPanel == panel.rawValue ? .primary : .secondary)
                .help(panel.title)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .fill(EditorColumnStyle.rowFill)
        )
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: Chapter一覧ビュー
/// 概要: 左カラムの Chapters パネルでプロジェクト内 Chapter を軽量なカスタム行として表示します。
private struct ChapterListView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                ForEach(store.loadedProject?.project.chapters ?? []) { chapter in
                    ChapterRow(
                        chapter: chapter,
                        isSelected: chapter.id == store.selectedChapter?.id,
                        onSelect: {
                            store.selectChapter(id: chapter.id)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, EditorColumnStyle.outerPadding)
            .padding(.vertical, 10)
        }
        .frame(minHeight: 140)
    }
}

/// 論理名（日本語）: Chapter行ビュー
/// 概要: Chapter 名と保持ページ数を Sidebar 向けの軽量行として表示します。
///
/// プロパティ:
/// - `chapter`: 表示する Chapter 定義。
/// - `isSelected`: 現在選択中の Chapter か。
/// - `onSelect`: 行選択時に呼び出す処理。
private struct ChapterRow: View {
    var chapter: OpenGraphiteChapter
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: "book.closed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(chapter.id)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text("\(chapter.pages.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .fill(isSelected ? EditorColumnStyle.selectedRowFill : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        }
        .buttonStyle(.plain)
        .help(chapter.displayName)
    }
}

/// 論理名（日本語）: ページ一覧ビュー
/// 概要: 左カラムの Pages パネルで選択 Chapter 内ページを開閉可能な HTML カードとして表示します。
private struct PageListView: View {
    var body: some View {
        PageLayerListView(segment: .pages)
    }
}

/// 論理名（日本語）: Componentページ一覧ビュー
/// 概要: 左カラムの Components パネルで component master を格納する HTML canvas を開閉可能なカードとして表示します。
private struct ComponentPageListView: View {
    var body: some View {
        PageLayerListView(segment: .components)
    }
}

/// 論理名（日本語）: HTMLレイヤーカード一覧ビュー
/// 概要: Pages または Components の各 HTML を開閉可能なカードとして並べ、選択中 HTML の Layers をカード内へ表示します。
///
/// プロパティ:
/// - `segment`: 表示対象の Pages / Components セグメント。
private struct PageLayerListView: View {
    @EnvironmentObject private var store: EditorStore
    @State private var expansionState = SidebarPageExpansionState()
    var segment: OpenGraphiteCanvasSegment

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(pages) { page in
                    PageLayerCard(
                        page: page,
                        isSelected: isSelected(page),
                        isExpanded: expansionState.isExpanded(pageID: page.id),
                        nodes: isSelected(page) ? store.nodes : [],
                        selectedNodeID: $store.selectedNodeID,
                        systemImage: segment == .components ? "shippingbox" : "doc.text",
                        onSelect: {
                            select(page)
                            expansionState.expand(pageID: page.id)
                        },
                        onToggle: {
                            toggle(page)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, EditorColumnStyle.outerPadding)
            .padding(.vertical, 10)
        }
        .frame(minHeight: 140)
        .onAppear {
            selectSegmentIfNeeded()
            expandSelectedPage()
        }
        .onChange(of: store.selectedCanvasSegment) { _, newValue in
            if newValue == segment {
                expandSelectedPage()
            }
        }
        .onChange(of: selectedPageID) { _, _ in
            expandSelectedPage()
        }
    }

    private var pages: [OpenGraphitePage] {
        switch segment {
        case .pages:
            return store.selectedChapterPages
        case .components:
            return store.componentPages
        }
    }

    private var selectedPageID: String? {
        switch segment {
        case .pages:
            return store.selectedCanvasSegment == .pages ? store.selectedPageID : nil
        case .components:
            return store.selectedCanvasSegment == .components ? store.selectedComponentPageID : nil
        }
    }

    /// 論理名（日本語）: HTML選択判定関数
    /// 処理概要: 対象カードが現在の編集 HTML と一致するかを返します。
    ///
    /// - Parameter page: 判定対象の HTML page。
    /// - Returns: 選択中であれば `true`。
    private func isSelected(_ page: OpenGraphitePage) -> Bool {
        store.selectedCanvasSegment == segment && selectedPageID == page.id
    }

    /// 論理名（日本語）: HTMLカード選択関数
    /// 処理概要: セグメントに応じて通常 page または component master を選択します。
    ///
    /// - Parameter page: 選択する HTML page。
    private func select(_ page: OpenGraphitePage) {
        switch segment {
        case .pages:
            if store.selectedCanvasSegment != .pages {
                store.selectPagesSegment()
            }
            store.selectPage(id: page.id)
        case .components:
            store.selectComponentPage(id: page.id)
        }
    }

    /// 論理名（日本語）: セグメント選択関数
    /// 処理概要: パネル表示時に中央 canvas の表示対象を現在の sidebar パネルへ合わせます。
    private func selectSegmentIfNeeded() {
        switch segment {
        case .pages:
            if store.selectedCanvasSegment != .pages {
                store.selectPagesSegment()
            }
        case .components:
            if store.selectedCanvasSegment != .components {
                store.selectComponentsSegment()
            }
        }
    }

    /// 論理名（日本語）: HTMLカード開閉関数
    /// 処理概要: カードを閉じるか、対象 HTML を選択してそのカードだけを展開します。
    ///
    /// - Parameter page: 開閉対象の HTML page。
    private func toggle(_ page: OpenGraphitePage) {
        if expansionState.isExpanded(pageID: page.id) {
            expansionState.toggle(pageID: page.id)
        } else {
            select(page)
            expansionState.expand(pageID: page.id)
        }
    }

    /// 論理名（日本語）: 選択HTML展開関数
    /// 処理概要: 選択中 HTML が現在パネルに属するときは展開し、選択解除時は残った展開表示を消します。
    private func expandSelectedPage() {
        expansionState.synchronizeSelection(
            selectedPageID: selectedPageID,
            validPageIDs: Set(pages.map(\.id))
        )
    }
}

/// 論理名（日本語）: HTMLレイヤーカードビュー
/// 概要: HTML page の見出しと、展開時のレイヤー階層を一つの Sidebar カードとして表示します。
///
/// プロパティ:
/// - `page`: 表示するページ定義。
/// - `isSelected`: 現在選択中のページか。
/// - `isExpanded`: レイヤー階層を展開中か。
/// - `nodes`: 選択中 HTML から収集された DOM ノード一覧。
/// - `selectedNodeID`: 選択中ノード ID のバインディング。
/// - `systemImage`: 見出しに表示する SF Symbols 名。
/// - `onSelect`: 行選択時に呼び出す処理。
/// - `onToggle`: 展開切替時に呼び出す処理。
private struct PageLayerCard: View {
    var page: OpenGraphitePage
    var isSelected: Bool
    var isExpanded: Bool
    var nodes: [OpenGraphiteNode]
    @Binding var selectedNodeID: String?
    var systemImage: String
    var onSelect: () -> Void
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 16, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(isExpanded ? "Collapse" : "Expand")

                Button(action: onSelect) {
                    HStack(spacing: 9) {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .frame(width: 18, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(page.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(page.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(page.path)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .fill(isSelected ? EditorColumnStyle.selectedRowFill : Color.clear)
            )

            if isExpanded {
                LayerOutlineContentView(
                    nodes: nodes,
                    selectedNodeID: $selectedNodeID
                )
                .padding(.leading, 8)
                .padding(.trailing, 6)
                .padding(.bottom, 7)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .fill(isSelected || isExpanded ? EditorColumnStyle.rowFill.opacity(0.92) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(isSelected || isExpanded ? Color(nsColor: .separatorColor).opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

/// 論理名（日本語）: レイヤーアウトライン内容ビュー
/// 概要: DOM ノード一覧を階層ツリーへ変換し、HTML カード内の Layers として表示します。
///
/// プロパティ:
/// - `nodes`: WebView から抽出されたノード一覧。
/// - `selectedNodeID`: 選択中ノード ID のバインディング。
private struct LayerOutlineContentView: View {
    var nodes: [OpenGraphiteNode]
    @Binding var selectedNodeID: String?
    @State private var expandedNodeIDs: Set<String> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(visibleRows) { row in
                LayerRow(
                    row: row,
                    isCollapsed: !expandedNodeIDs.contains(row.id),
                    isSelected: row.id == selectedNodeID,
                    onToggle: {
                        toggle(row.id)
                    },
                    onSelect: {
                        selectedNodeID = row.id
                    }
                )
            }
        }
        .padding(.top, 2)
        .onAppear {
            revealSelection(selectedNodeID)
        }
        .onChange(of: selectedNodeID) { _, newValue in
            revealSelection(newValue)
        }
        .onChange(of: nodes) { _, newValue in
            if newValue.isEmpty {
                expandedNodeIDs = []
            } else {
                revealSelection(selectedNodeID)
            }
        }
    }

    private var visibleRows: [VisibleLayerRow] {
        let tree = LayerTreeNode.makeTree(from: nodes)
        var rows: [VisibleLayerRow] = []

        /// 論理名（日本語）: 表示行追加関数
        /// 処理概要: 展開状態を確認しながらツリーノードを List 表示用の flat な行配列へ追加します。
        ///
        /// - Parameters:
        ///   - items: 追加するツリーノード一覧。
        ///   - level: 表示上の階層レベル。
        func append(_ items: [LayerTreeNode], level: Int) {
            for item in items {
                rows.append(
                    VisibleLayerRow(
                        id: item.id,
                        node: item.node,
                        level: level,
                        hasChildren: !item.children.isEmpty
                    )
                )

                if expandedNodeIDs.contains(item.id) {
                    append(item.children, level: level + 1)
                }
            }
        }

        append(tree, level: 0)
        return rows
    }

    /// 論理名（日本語）: レイヤー展開切替関数
    /// 処理概要: 指定ノード ID の折りたたみ状態を反転します。
    ///
    /// - Parameter id: 展開状態を切り替えるノード ID。
    private func toggle(_ id: String) {
        if expandedNodeIDs.contains(id) {
            expandedNodeIDs.remove(id)
        } else {
            expandedNodeIDs.insert(id)
        }
    }

    /// 論理名（日本語）: 選択レイヤー表示関数
    /// 処理概要: 選択ノードの祖先を展開して、カード内の階層を見える状態にします。
    ///
    /// - Parameter id: 表示する選択ノード ID。
    private func revealSelection(_ id: String?) {
        guard let id else { return }
        expandAncestors(of: id)
    }

    /// 論理名（日本語）: 祖先レイヤー展開関数
    /// 処理概要: flat な DOM ノード一覧の depth を逆方向にたどり、選択ノードの祖先を展開状態にします。
    ///
    /// - Parameter id: 祖先を展開する対象ノード ID。
    private func expandAncestors(of id: String) {
        guard let selectedIndex = nodes.firstIndex(where: { $0.id == id }) else { return }
        var requiredDepth = nodes[selectedIndex].depth - 1
        guard requiredDepth >= 0 else { return }

        for index in stride(from: selectedIndex - 1, through: 0, by: -1) {
            let candidate = nodes[index]
            if candidate.depth == requiredDepth {
                expandedNodeIDs.insert(candidate.id)
                requiredDepth -= 1

                if requiredDepth < 0 {
                    break
                }
            }
        }
    }
}

/// 論理名（日本語）: レイヤーツリーノード
/// 概要: flat な DOM ノード一覧を Layers 用の階層構造へ変換する内部モデルです。
///
/// プロパティ:
/// - `node`: 対応する OpenGraphite ノード。
/// - `children`: 子レイヤー一覧。
private struct LayerTreeNode: Identifiable {
    var node: OpenGraphiteNode
    var children: [LayerTreeNode]

    var id: String { node.id }

    /// 論理名（日本語）: レイヤーツリー生成関数
    /// 処理概要: depth 付きノード配列からルート階層のツリーノード一覧を生成します。
    ///
    /// - Parameter nodes: WebView から収集された depth 付きノード一覧。
    /// - Returns: ルート階層のレイヤーツリーノード一覧。
    static func makeTree(from nodes: [OpenGraphiteNode]) -> [LayerTreeNode] {
        var index = 0
        return makeChildren(from: nodes, index: &index, parentDepth: -1)
    }

    /// 論理名（日本語）: 子レイヤー生成関数
    /// 処理概要: 現在の index から parentDepth より深いノードを再帰的に子として収集します。
    ///
    /// - Parameters:
    ///   - nodes: depth 付きノード一覧。
    ///   - index: 現在の読み取り位置。
    ///   - parentDepth: 親ノードの depth。
    /// - Returns: 収集した子レイヤーツリーノード一覧。
    private static func makeChildren(
        from nodes: [OpenGraphiteNode],
        index: inout Int,
        parentDepth: Int
    ) -> [LayerTreeNode] {
        var result: [LayerTreeNode] = []

        while index < nodes.count {
            let node = nodes[index]
            guard node.depth > parentDepth else {
                break
            }

            index += 1
            let children = makeChildren(from: nodes, index: &index, parentDepth: node.depth)
            result.append(LayerTreeNode(node: node, children: children))
        }

        return result
    }
}

/// 論理名（日本語）: 表示レイヤー行
/// 概要: 折りたたみ状態を反映した List 表示用のレイヤー行モデルです。
///
/// プロパティ:
/// - `id`: 行のノード ID。
/// - `node`: 表示する OpenGraphite ノード。
/// - `level`: List 上のインデント階層。
/// - `hasChildren`: 子レイヤーを持つか。
private struct VisibleLayerRow: Identifiable {
    var id: String
    var node: OpenGraphiteNode
    var level: Int
    var hasChildren: Bool
}

/// 論理名（日本語）: サイドバーパネル
/// 概要: 左ペインで表示する Chapters、Pages、Components のセグメント種別を表します。
///
/// 定義内容:
/// - `chapters`: Chapter 一覧。
/// - `pages`: ページ一覧。
/// - `components`: Component master canvas 一覧。
private enum SidebarPanel: String, CaseIterable, Identifiable {
    case chapters
    case pages
    case components

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chapters:
            return "Chapters"
        case .pages:
            return "Pages"
        case .components:
            return "Components"
        }
    }

    var systemImage: String {
        switch self {
        case .chapters:
            return "book.closed"
        case .pages:
            return "rectangle.stack"
        case .components:
            return "shippingbox"
        }
    }
}

/// 論理名（日本語）: レイヤー行ビュー
/// 概要: レイヤーの展開ボタン、種別アイコン、タグ名、詳細行を一行に表示します。
///
/// プロパティ:
/// - `row`: 表示するレイヤー行モデル。
/// - `isCollapsed`: 子レイヤーが折りたたまれているか。
/// - `isSelected`: 現在選択中の行か。
/// - `onToggle`: 展開切替処理。
/// - `onSelect`: 選択処理。
private struct LayerRow: View {
    var row: VisibleLayerRow
    var isCollapsed: Bool
    var isSelected: Bool
    var onToggle: () -> Void
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if row.hasChildren {
                    Button(action: onToggle) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 12, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(isCollapsed ? "Expand" : "Collapse")
                } else {
                    Color.clear
                        .frame(width: 12, height: 18)
                }
            }

            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.node.tagName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("\(row.node.id) · \(row.node.detailLine)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(row.level) * 15 + 2)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(isSelected ? EditorColumnStyle.selectedRowFill : Color.clear)
        )
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch row.node.type {
        case "text":
            return "textformat"
        case "button":
            return "button.programmable"
        case "image":
            return "photo"
        default:
            return "rectangle.3.group"
        }
    }
}
