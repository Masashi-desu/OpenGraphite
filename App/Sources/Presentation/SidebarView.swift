import Foundation
import SwiftUI

/// 論理名（日本語）: サイドバービュー
/// 概要: Project、Pages、Components を切り替え、実装資源または HTML カード内レイヤー階層を選択する左ペインです。
struct SidebarView: View {
    @EnvironmentObject private var store: EditorStore
    @SceneStorage("sidebar.selectedPanel") private var selectedPanel = SidebarPanel.pages.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarPanelSwitcher(selectedPanel: $selectedPanel)
                .padding(.top, EditorOverlayMetrics.titlebarInset)
                .padding(.horizontal, EditorColumnStyle.outerPadding)
                .padding(.bottom, 10)

            Group {
                if resolvedPanel == .project {
                    ProjectDependencyListView()
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
            synchronizeSelectedPanelWithStore()
        }
        .onChange(of: selectedPanel) { _, _ in
            normalizeSelectedPanel()
            synchronizeSelectedPanelWithStore()
        }
        .onChange(of: store.selectedNodeID) { _, newValue in
            if newValue != nil {
                selectedPanel = store.selectedCanvasSegment == .components
                    ? SidebarPanel.components.rawValue
                    : SidebarPanel.pages.rawValue
            }
        }
        .onChange(of: store.selectedProjectResource) { _, newValue in
            if newValue != nil {
                selectedPanel = SidebarPanel.project.rawValue
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

    /// 論理名（日本語）: サイドバーパネル選択同期関数
    /// 処理概要: Project 以外のパネルへ移動したとき、Inspector の Project 資源選択を解除して Canvas 選択へ戻します。
    private func synchronizeSelectedPanelWithStore() {
        switch resolvedPanel {
        case .project:
            break
        case .pages:
            store.selectPagesSegment()
        case .components:
            store.selectComponentsSegment()
        }
    }
}

/// 論理名（日本語）: サイドバーパネル切替ビュー
/// 概要: タイトルバー領域の下に Project、Pages、Components の切替ボタンを表示します。
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
                    HStack(spacing: 6) {
                        OpenGraphiteIconView(icon: panel.icon, size: 13)
                        Text(panel.title)
                    }
                        .font(.system(size: 12, weight: .semibold))
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

/// 論理名（日本語）: サイドバーグループ行ビュー
/// 概要: Chapter または Collection 名と保持 HTML 数を Sidebar 向けの軽量行として表示します。
///
/// プロパティ:
/// - `title`: 表示名。
/// - `detail`: 補助表示する ID。
/// - `count`: グループ内 HTML 数。
/// - `icon`: グループ種別アイコン。
/// - `isSelected`: 現在選択中のグループか。
/// - `onSelect`: 行選択時に呼び出す処理。
/// - `onCopyReferenceID`: 参照 ID コピー時に呼び出す処理。
private struct SidebarGroupRow: View {
    var title: String
    var detail: String
    var count: Int
    var icon: OpenGraphiteIcon
    var isSelected: Bool
    var onSelect: () -> Void
    var onCopyReferenceID: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                OpenGraphiteIconView(icon: icon, size: 14)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(count)")
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
        .contextMenu {
            Button("参照IDをコピー", action: onCopyReferenceID)
        }
        .help(detail.isEmpty ? title : "\(title) (\(detail))")
    }
}

/// 論理名（日本語）: サイドバー空状態行ビュー
/// 概要: Chapter / Collection または HTML がない状態をコンパクトに表示します。
///
/// プロパティ:
/// - `text`: 表示する空状態文言。
private struct SidebarEmptyStateRow: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .fill(EditorColumnStyle.rowFill)
            )
    }
}

/// 論理名（日本語）: サイドバー分割セクション寸法
/// 概要: Chapter / Collection と所属 HTML ペインを標準分割表示するための高さ制約をまとめます。
///
/// 定義内容:
/// - `collapsedHeight`: 最小化時に残すヘッダー高さ。
/// - `groupMinHeight`: Chapter / Collection ペインの展開時最小高さ。
/// - `contentMinHeight`: 所属 HTML ペインの展開時最小高さ。
private enum SidebarSplitMetrics {
    static let collapsedHeight: CGFloat = 34
    static let groupMinHeight: CGFloat = 92
    static let contentMinHeight: CGFloat = 120
}

/// 論理名（日本語）: サイドバー分割セクションビュー
/// 概要: `VSplitView` 内で使う折りたたみ可能な標準ペインを表します。
///
/// プロパティ:
/// - `title`: セクション名。
/// - `count`: セクション内の項目数。
/// - `isCollapsed`: 最小化状態。
/// - `content`: 展開時に表示する本文。
private struct SidebarSplitSection<Content: View>: View {
    var title: String
    var count: Int
    @Binding var isCollapsed: Bool
    var content: Content

    /// 論理名（日本語）: サイドバー分割セクション初期化関数
    /// 処理概要: セクション見出しと折りたたみ状態、本文 view を受け取ります。
    ///
    /// - Parameters:
    ///   - title: セクション名。
    ///   - count: セクション内の項目数。
    ///   - isCollapsed: 最小化状態。
    ///   - content: 展開時に表示する本文。
    init(
        title: String,
        count: Int,
        isCollapsed: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        _isCollapsed = isCollapsed
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.14)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 18)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand" : "Collapse")

            if !isCollapsed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// 論理名（日本語）: Project依存性一覧ビュー
/// 概要: `.ogp` 全体を Project カードとして表示し、依存性と i18n 資源を内包した階層として選択可能にします。
private struct ProjectDependencyListView: View {
    @EnvironmentObject private var store: EditorStore
    @SceneStorage("sidebar.projectCardCollapsed") private var isProjectCardCollapsed = false
    @SceneStorage("sidebar.projectDependenciesCollapsed") private var isProjectDependenciesCollapsed = false
    @SceneStorage("sidebar.projectI18nCollapsed") private var isProjectI18nCollapsed = false
    @SceneStorage("sidebar.projectLocaleResourcesCollapsed") private var isProjectLocaleResourcesCollapsed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let projectItem, let i18nItem {
                    ProjectDependencyCard(
                        projectItem: projectItem,
                        dependencyItems: dependencyItems,
                        i18nItem: i18nItem,
                        localeItems: localeItems,
                        selectedResource: selectedResource,
                        isProjectCollapsed: $isProjectCardCollapsed,
                        isDependenciesCollapsed: $isProjectDependenciesCollapsed,
                        isI18nCollapsed: $isProjectI18nCollapsed,
                        isLocaleResourcesCollapsed: $isProjectLocaleResourcesCollapsed,
                        onSelect: { selection in
                            store.selectProjectResource(selection)
                        }
                    )
                } else {
                    SidebarEmptyStateRow(text: "No project")
                }
            }
            .padding(.horizontal, EditorColumnStyle.outerPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if store.selectedProjectResource == nil {
                store.selectProjectResource(.overview)
            }
        }
    }

    private var selectedResource: OpenGraphiteProjectResourceSelection? {
        store.selectedProjectResource
    }

    private var projectItem: ProjectDependencyItem? {
        guard let loadedProject = store.loadedProject else { return nil }
        let project = loadedProject.project
        return ProjectDependencyItem(
            title: "Project",
            detail: loadedProject.fileURL.lastPathComponent,
            status: project.name,
            icon: .projectPanel,
            selection: .overview
        )
    }

    private var dependencyItems: [ProjectDependencyItem] {
        guard let loadedProject = store.loadedProject else { return [] }
        let project = loadedProject.project
        var items: [ProjectDependencyItem] = [
            ProjectDependencyItem(
                title: "HTML Root",
                detail: project.htmlRoot,
                status: FileManager.default.fileExists(atPath: loadedProject.rootURL.appendingPathComponent(project.htmlRoot).path) ? "Found" : "Missing",
                icon: .dependencyResource,
                selection: .htmlRoot
            ),
            ProjectDependencyItem(
                title: "CSS",
                detail: project.cssLibrary,
                status: FileManager.default.fileExists(atPath: loadedProject.cssURL.path) ? "Found" : "Missing",
                icon: .dependencyResource,
                selection: .cssLibrary
            )
        ]

        let runtimePath = "\(project.htmlRoot)/OpenGraphite.runtime.js"
        let runtimeURL = loadedProject.rootURL.appendingPathComponent(runtimePath)
        items.append(
            ProjectDependencyItem(
                title: "Runtime",
                detail: runtimePath,
                status: FileManager.default.fileExists(atPath: runtimeURL.path) ? "Found" : "Missing",
                icon: .dependencyResource,
                selection: .runtime(path: runtimePath)
            )
        )
        return items
    }

    private var i18nItem: ProjectDependencyItem? {
        guard store.loadedProject != nil else { return nil }
        let i18nInspection = store.projectI18nRuntimeInspection
        return ProjectDependencyItem(
            title: "Runtime",
            detail: shortPath(i18nInspection?.configSource) ?? "not detected",
            status: adapterStatus(i18nInspection?.adapter),
            icon: .i18nResource,
            selection: .i18nRuntime
        )
    }

    private var localeItems: [ProjectDependencyItem] {
        guard let loadedProject = store.loadedProject else { return [] }
        let resources = store.projectI18nRuntimeInspection?.resources ?? [
            OpenGraphiteI18nResourceStatus(
                locale: "ja",
                path: loadedProject.rootURL
                    .appendingPathComponent(loadedProject.project.htmlRoot)
                    .appendingPathComponent("locales/ja.json")
                    .path,
                exists: false,
                editable: true
            ),
            OpenGraphiteI18nResourceStatus(
                locale: "eng",
                path: loadedProject.rootURL
                    .appendingPathComponent(loadedProject.project.htmlRoot)
                    .appendingPathComponent("locales/eng.json")
                    .path,
                exists: false,
                editable: true
            )
        ]
        return resources.map { resource in
            ProjectDependencyItem(
                title: "\(resource.locale).json",
                detail: shortPath(resource.path) ?? resource.path,
                status: resource.exists ? "Found" : "Missing",
                icon: .localeResource,
                selection: .localeResource(locale: resource.locale, path: resource.path)
            )
        }
    }

    private func adapterStatus(_ adapter: OpenGraphiteI18nAdapter?) -> String {
        switch adapter {
        case .i18next:
            return "i18next"
        case .unknown:
            return "Unknown"
        case nil:
            return "Unknown"
        }
    }

    private func shortPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

/// 論理名（日本語）: Project依存性カードビュー
/// 概要: Project セグメントで `.ogp` 全体を最上位カードとして表示し、依存性と i18n 資源を階層化します。
///
/// プロパティ:
/// - `projectItem`: 最上位 Project 行。
/// - `dependencyItems`: HTML root、CSS、runtime など Dependencies 直下の依存性。
/// - `i18nItem`: Dependencies 配下の i18n runtime 行。
/// - `localeItems`: i18n 配下の locale JSON。
/// - `selectedResource`: 現在選択中の Project 資源。
/// - `isProjectCollapsed`: Project カード本文の折りたたみ状態。
/// - `isDependenciesCollapsed`: Dependencies 配下の折りたたみ状態。
/// - `isI18nCollapsed`: I18n 配下の折りたたみ状態。
/// - `isLocaleResourcesCollapsed`: Locale Resources 配下の折りたたみ状態。
/// - `onSelect`: 資源選択時に呼び出す処理。
private struct ProjectDependencyCard: View {
    var projectItem: ProjectDependencyItem
    var dependencyItems: [ProjectDependencyItem]
    var i18nItem: ProjectDependencyItem
    var localeItems: [ProjectDependencyItem]
    var selectedResource: OpenGraphiteProjectResourceSelection?
    @Binding var isProjectCollapsed: Bool
    @Binding var isDependenciesCollapsed: Bool
    @Binding var isI18nCollapsed: Bool
    @Binding var isLocaleResourcesCollapsed: Bool
    var onSelect: (OpenGraphiteProjectResourceSelection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectDependencyRow(
                item: projectItem,
                isSelected: projectItem.selection == selectedResource,
                depth: 0,
                isCollapsed: isProjectCollapsed,
                onToggle: {
                    toggle($isProjectCollapsed)
                },
                onSelect: {
                    onSelect(projectItem.selection)
                }
            )

            if !isProjectCollapsed {
                VStack(alignment: .leading, spacing: 5) {
                    ProjectDependencyHierarchyHeader(
                        title: "Dependencies",
                        count: dependencyGroupCount,
                        depth: 0,
                        isCollapsed: isDependenciesCollapsed,
                        onToggle: {
                            toggle($isDependenciesCollapsed)
                        }
                    )

                    if !isDependenciesCollapsed {
                        ForEach(dependencyItems) { item in
                            ProjectDependencyRow(
                                item: item,
                                isSelected: item.selection == selectedResource,
                                depth: 1,
                                onSelect: {
                                    onSelect(item.selection)
                                }
                            )
                        }

                        ProjectDependencyHierarchyHeader(
                            title: "I18n",
                            count: i18nGroupCount,
                            depth: 1,
                            isCollapsed: isI18nCollapsed,
                            onToggle: {
                                toggle($isI18nCollapsed)
                            }
                        )
                        .padding(.top, 4)

                        if !isI18nCollapsed {
                            ProjectDependencyRow(
                                item: i18nItem,
                                isSelected: i18nItem.selection == selectedResource,
                                depth: 2,
                                onSelect: {
                                    onSelect(i18nItem.selection)
                                }
                            )

                            ProjectDependencyHierarchyHeader(
                                title: "Locale Resources",
                                count: localeItems.count,
                                depth: 2,
                                isCollapsed: isLocaleResourcesCollapsed,
                                onToggle: {
                                    toggle($isLocaleResourcesCollapsed)
                                }
                            )

                            if !isLocaleResourcesCollapsed {
                                if localeItems.isEmpty {
                                    SidebarEmptyStateRow(text: "No locale resources")
                                        .padding(.leading, ProjectDependencyHierarchyMetrics.indent(for: 3))
                                } else {
                                    ForEach(localeItems) { item in
                                        ProjectDependencyRow(
                                            item: item,
                                            isSelected: item.selection == selectedResource,
                                            depth: 3,
                                            onSelect: {
                                                onSelect(item.selection)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 3)
                .padding(.bottom, 7)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .fill(EditorColumnStyle.rowFill.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }

    private var dependencyGroupCount: Int {
        dependencyItems.count + 1
    }

    private var i18nGroupCount: Int {
        2
    }

    /// 論理名（日本語）: Project依存性折りたたみ切替関数
    /// 処理概要: Project カード内の指定階層を短いアニメーション付きで開閉します。
    ///
    /// - Parameter isCollapsed: 切り替える折りたたみ状態。
    private func toggle(_ isCollapsed: Binding<Bool>) {
        withAnimation(.easeInOut(duration: 0.14)) {
            isCollapsed.wrappedValue.toggle()
        }
    }
}

/// 論理名（日本語）: Project依存性階層ヘッダービュー
/// 概要: Project カード内の Dependencies、I18n、Locale Resources の階層見出しを表示します。
///
/// プロパティ:
/// - `title`: 見出し名。
/// - `count`: 見出し配下の項目数。
/// - `depth`: Project カード内の階層深度。
/// - `isCollapsed`: 見出し配下の折りたたみ状態。
/// - `onToggle`: 折りたたみ切替時に呼び出す処理。
private struct ProjectDependencyHierarchyHeader: View {
    var title: String
    var count: Int
    var depth: Int
    var isCollapsed: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Spacer()
                    .frame(width: ProjectDependencyHierarchyMetrics.indent(for: depth))

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: ProjectDependencyHierarchyMetrics.disclosureWidth, height: 16)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .help(isCollapsed ? "Expand" : "Collapse")
    }
}

/// 論理名（日本語）: Project依存性階層寸法
/// 概要: Project カード内で親子関係を示すインデント量を定義します。
private enum ProjectDependencyHierarchyMetrics {
    static let depthIndent: CGFloat = 16
    static let disclosureWidth: CGFloat = 16

    /// 論理名（日本語）: Project依存性インデント計算関数
    /// 処理概要: 指定階層の左インデント幅を返します。
    ///
    /// - Parameter depth: Project カード内の階層深度。
    /// - Returns: 左インデント幅。
    static func indent(for depth: Int) -> CGFloat {
        CGFloat(max(depth, 0)) * depthIndent
    }
}

/// 論理名（日本語）: Project依存性行モデル
/// 概要: Project セグメントで表示する実装資源の行情報です。
///
/// プロパティ:
/// - `id`: 安定識別子。
/// - `title`: 表示名。
/// - `detail`: 補助表示。
/// - `status`: 検出状態。
/// - `icon`: 表示アイコン。
/// - `selection`: 行選択時の Project 資源。
private struct ProjectDependencyItem: Identifiable {
    var title: String
    var detail: String
    var status: String
    var icon: OpenGraphiteIcon
    var selection: OpenGraphiteProjectResourceSelection

    var id: String {
        "\(title)#\(detail)#\(status)"
    }
}

/// 論理名（日本語）: Project依存性行ビュー
/// 概要: 実装資源の種類、path、検出状態を Sidebar 向けの軽量行として表示します。
///
/// プロパティ:
/// - `item`: 表示する依存性。
/// - `isSelected`: 現在選択中か。
/// - `depth`: Project カード内の階層深度。
/// - `isCollapsed`: 行配下の折りたたみ状態。
/// - `onToggle`: 折りたたみ切替時に呼び出す処理。
/// - `onSelect`: 行選択時に呼び出す処理。
private struct ProjectDependencyRow: View {
    var item: ProjectDependencyItem
    var isSelected: Bool
    var depth: Int = 0
    var isCollapsed: Bool?
    var onToggle: (() -> Void)?
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: ProjectDependencyHierarchyMetrics.indent(for: depth))

            if let isCollapsed, let onToggle {
                Button(action: onToggle) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: ProjectDependencyHierarchyMetrics.disclosureWidth, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(isCollapsed ? "Expand" : "Collapse")
            } else {
                Spacer()
                    .frame(width: ProjectDependencyHierarchyMetrics.disclosureWidth)
            }

            Button(action: onSelect) {
                HStack(spacing: 9) {
                    OpenGraphiteIconView(icon: item.icon, size: 14)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 0)

                    Text(item.status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(isSelected ? EditorColumnStyle.selectedRowFill : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .help(item.detail)
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

/// 論理名（日本語）: サイドバーページグループ
/// 概要: Pages タブの Chapter または Components タブの Collection と、その配下 HTML をまとめる表示モデルです。
///
/// プロパティ:
/// - `internalID`: `.ogp` 内のグループ内部 ID。
/// - `title`: グループ表示名。
/// - `detail`: 補助表示する ID。
/// - `icon`: グループ種別アイコン。
/// - `pages`: グループ配下の HTML 定義。
private struct SidebarPageGroup: Identifiable {
    var internalID: String
    var title: String
    var detail: String
    var icon: OpenGraphiteIcon
    var pages: [OpenGraphitePage]

    var id: String { internalID }
}

/// 論理名（日本語）: HTMLレイヤーカード一覧ビュー
/// 概要: 上段に Chapter / Collection を並べ、下段に選択グループ内 HTML カードと Layers を表示します。
///
/// プロパティ:
/// - `segment`: 表示対象の Pages / Components セグメント。
private struct PageLayerListView: View {
    @EnvironmentObject private var store: EditorStore
    @SceneStorage("sidebar.pagesGroupSectionCollapsed") private var isPagesGroupSectionCollapsed = false
    @SceneStorage("sidebar.pagesContentSectionCollapsed") private var isPagesContentSectionCollapsed = false
    @SceneStorage("sidebar.componentsGroupSectionCollapsed") private var isComponentsGroupSectionCollapsed = false
    @SceneStorage("sidebar.componentsContentSectionCollapsed") private var isComponentsContentSectionCollapsed = false
    @State private var expansionState = SidebarPageExpansionState()
    var segment: OpenGraphiteCanvasSegment

    var body: some View {
        Group {
            if areBothSectionsCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    sidebarSplitSections

                    Spacer(minLength: 0)
                }
            } else {
                VSplitView {
                    sidebarSplitSections
                }
            }
        }
        .padding(.horizontal, EditorColumnStyle.outerPadding)
        .padding(.vertical, 10)
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
        .onChange(of: selectedGroupID) { _, _ in
            expandSelectedPage()
        }
        .onChange(of: selectedPageID) { _, _ in
            expandSelectedPage()
        }
    }

    @ViewBuilder
    private var sidebarSplitSections: some View {
        SidebarSplitSection(
            title: groupSectionTitle,
            count: groups.count,
            isCollapsed: groupSectionCollapsedBinding
        ) {
            groupSectionContent
        }
        .frame(
            minHeight: groupSectionMinHeight,
            idealHeight: groupSectionIdealHeight,
            maxHeight: groupSectionMaxHeight
        )

        SidebarSplitSection(
            title: contentSectionTitle,
            count: visiblePages.count,
            isCollapsed: contentSectionCollapsedBinding
        ) {
            contentSectionContent
        }
        .frame(
            minHeight: contentSectionMinHeight,
            idealHeight: contentSectionIdealHeight,
            maxHeight: contentSectionMaxHeight
        )
    }

    @ViewBuilder
    private var groupSectionContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                if groups.isEmpty {
                    SidebarEmptyStateRow(text: emptyGroupMessage)
                } else {
                    ForEach(groups) { group in
                        SidebarGroupRow(
                            title: group.title,
                            detail: group.detail,
                            count: group.pages.count,
                            icon: group.icon,
                            isSelected: isGroupSelected(group),
                            onSelect: {
                                select(group)
                            },
                            onCopyReferenceID: {
                                copyGroupReferenceID(group)
                            }
                        )
                        .onCopyCommand {
                            guard isGroupSelected(group), selectedPageID == nil else { return [] }
                            return OpenGraphiteReferenceCopy.itemProviders(for: groupReferenceID(group))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var contentSectionContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if let group = selectedDisplayGroup {
                    if group.pages.isEmpty {
                        SidebarEmptyStateRow(text: emptyPageMessage)
                    } else {
                        ForEach(group.pages, id: \.internalID) { page in
                            PageLayerCard(
                                page: page,
                                isSelected: isSelected(page, in: group),
                                isExpanded: expansionState.isExpanded(pageID: page.internalID),
                                nodes: isSelected(page, in: group) ? store.nodes : [],
                                selectedNodeID: $store.selectedNodeID,
                                icon: segment == .components ? .componentDocument : .pageDocument,
                                onSelect: {
                                    select(page, in: group)
                                    expansionState.expand(pageID: page.internalID)
                                },
                                onToggle: {
                                    toggle(page, in: group)
                                },
                                onCopyReferenceID: {
                                    select(page, in: group)
                                    store.copyPageReferenceIDToPasteboard(page, segment: segment)
                                },
                                onCopyNodeReferenceID: { node in
                                    if !isSelected(page, in: group) {
                                        select(page, in: group)
                                    }
                                    store.selectNode(id: node.id)
                                    store.copyNodeReferenceIDToPasteboard(node)
                                },
                                nodeReferenceID: { node in
                                    store.nodeReferenceID(forNodeID: node.id, nodeInternalID: node.internalID)
                                }
                            )
                            .onCopyCommand {
                                guard isSelected(page, in: group), store.selectedNodeID == nil else { return [] }
                                return OpenGraphiteReferenceCopy.itemProviders(
                                    for: store.pageReferenceID(for: page, segment: segment)
                                )
                            }
                        }
                    }
                } else {
                    SidebarEmptyStateRow(text: emptyPageMessage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 2)
        }
    }

    private var groups: [SidebarPageGroup] {
        guard let project = store.loadedProject?.project else { return [] }
        switch segment {
        case .pages:
            return project.chapters.map { chapter in
                SidebarPageGroup(
                    internalID: chapter.internalID,
                    title: chapter.displayName,
                    detail: chapter.id,
                    icon: .chapterGroup,
                    pages: chapter.pages
                )
            }
        case .components:
            return project.collections.map { collection in
                SidebarPageGroup(
                    internalID: collection.internalID,
                    title: collection.displayName,
                    detail: collection.id,
                    icon: .collectionGroup,
                    pages: collection.components
                )
            }
        }
    }

    private var isGroupSectionCollapsed: Bool {
        switch segment {
        case .pages:
            return isPagesGroupSectionCollapsed
        case .components:
            return isComponentsGroupSectionCollapsed
        }
    }

    private var isContentSectionCollapsed: Bool {
        switch segment {
        case .pages:
            return isPagesContentSectionCollapsed
        case .components:
            return isComponentsContentSectionCollapsed
        }
    }

    private var areBothSectionsCollapsed: Bool {
        isGroupSectionCollapsed && isContentSectionCollapsed
    }

    private var groupSectionCollapsedBinding: Binding<Bool> {
        Binding {
            isGroupSectionCollapsed
        } set: { newValue in
            switch segment {
            case .pages:
                isPagesGroupSectionCollapsed = newValue
            case .components:
                isComponentsGroupSectionCollapsed = newValue
            }
        }
    }

    private var contentSectionCollapsedBinding: Binding<Bool> {
        Binding {
            isContentSectionCollapsed
        } set: { newValue in
            switch segment {
            case .pages:
                isPagesContentSectionCollapsed = newValue
            case .components:
                isComponentsContentSectionCollapsed = newValue
            }
        }
    }

    private var groupSectionMinHeight: CGFloat {
        isGroupSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : SidebarSplitMetrics.groupMinHeight
    }

    private var groupSectionIdealHeight: CGFloat {
        isGroupSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : 160
    }

    private var groupSectionMaxHeight: CGFloat {
        isGroupSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : .infinity
    }

    private var contentSectionMinHeight: CGFloat {
        isContentSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : SidebarSplitMetrics.contentMinHeight
    }

    private var contentSectionIdealHeight: CGFloat {
        isContentSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : 360
    }

    private var contentSectionMaxHeight: CGFloat {
        isContentSectionCollapsed ? SidebarSplitMetrics.collapsedHeight : .infinity
    }

    private var selectedDisplayGroup: SidebarPageGroup? {
        if let selectedGroupID,
           let group = groups.first(where: { $0.internalID == selectedGroupID }) {
            return group
        }

        return groups.first
    }

    private var visiblePages: [OpenGraphitePage] {
        selectedDisplayGroup?.pages ?? []
    }

    private var groupSectionTitle: String {
        switch segment {
        case .pages:
            return "Chapters"
        case .components:
            return "Collections"
        }
    }

    private var contentSectionTitle: String {
        switch segment {
        case .pages:
            return "Pages"
        case .components:
            return "Components"
        }
    }

    private var emptyGroupMessage: String {
        switch segment {
        case .pages:
            return "No chapters"
        case .components:
            return "No collections"
        }
    }

    private var emptyPageMessage: String {
        switch segment {
        case .pages:
            return "No pages in this chapter"
        case .components:
            return "No components in this collection"
        }
    }

    private var selectedGroupID: String? {
        switch segment {
        case .pages:
            return store.selectedCanvasSegment == .pages ? store.selectedChapterInternalID : nil
        case .components:
            return store.selectedCanvasSegment == .components ? store.selectedCollectionInternalID : nil
        }
    }

    private var selectedPageID: String? {
        switch segment {
        case .pages:
            return store.selectedCanvasSegment == .pages ? store.selectedPageInternalID : nil
        case .components:
            return store.selectedCanvasSegment == .components ? store.selectedComponentPageInternalID : nil
        }
    }

    /// 論理名（日本語）: グループ選択判定関数
    /// 処理概要: 対象 Chapter / Collection が現在の表示グループと一致するかを返します。
    ///
    /// - Parameter group: 判定対象グループ。
    /// - Returns: 選択中であれば `true`。
    private func isGroupSelected(_ group: SidebarPageGroup) -> Bool {
        store.selectedCanvasSegment == segment && selectedGroupID == group.internalID
    }

    /// 論理名（日本語）: HTML選択判定関数
    /// 処理概要: 対象カードが現在の編集 HTML と一致するかを返します。
    ///
    /// - Parameters:
    ///   - page: 判定対象の HTML page。
    ///   - group: page が属する Chapter / Collection。
    /// - Returns: 選択中であれば `true`。
    private func isSelected(_ page: OpenGraphitePage, in group: SidebarPageGroup) -> Bool {
        isGroupSelected(group) && selectedPageID == page.internalID
    }

    /// 論理名（日本語）: グループ選択関数
    /// 処理概要: セグメントに応じて Chapter または Collection を選択します。
    ///
    /// - Parameter group: 選択する Chapter / Collection。
    private func select(_ group: SidebarPageGroup) {
        switch segment {
        case .pages:
            store.selectChapter(internalID: group.internalID)
        case .components:
            store.selectCollection(internalID: group.internalID)
        }
    }

    /// 論理名（日本語）: HTMLカード選択関数
    /// 処理概要: 所属 Chapter / Collection を選択してから通常 page または component master を選択します。
    ///
    /// - Parameters:
    ///   - page: 選択する HTML page。
    ///   - group: page が属する Chapter / Collection。
    private func select(_ page: OpenGraphitePage, in group: SidebarPageGroup) {
        switch segment {
        case .pages:
            if store.selectedChapterInternalID != group.internalID || store.selectedCanvasSegment != .pages {
                store.selectChapter(internalID: group.internalID)
            }
            store.selectPage(internalID: page.internalID)
        case .components:
            if store.selectedCollectionInternalID != group.internalID || store.selectedCanvasSegment != .components {
                store.selectCollection(internalID: group.internalID)
            }
            store.selectComponentPage(internalID: page.internalID)
        }
    }

    /// 論理名（日本語）: グループ参照ID取得関数
    /// 処理概要: Chapter / Collection の agent 向け参照 ID を返します。
    ///
    /// - Parameter group: 参照 ID を取得するグループ。
    /// - Returns: 参照 ID。該当グループがない場合は `nil`。
    private func groupReferenceID(_ group: SidebarPageGroup) -> String? {
        switch segment {
        case .pages:
            guard let chapter = store.loadedProject?.project.chapters.first(where: { $0.internalID == group.internalID }) else {
                return nil
            }
            return store.chapterReferenceID(for: chapter)
        case .components:
            guard let collection = store.loadedProject?.project.collections.first(where: { $0.internalID == group.internalID }) else {
                return nil
            }
            return store.collectionReferenceID(for: collection)
        }
    }

    /// 論理名（日本語）: グループ参照IDコピー関数
    /// 処理概要: Chapter / Collection の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter group: コピー対象グループ。
    private func copyGroupReferenceID(_ group: SidebarPageGroup) {
        switch segment {
        case .pages:
            guard let chapter = store.loadedProject?.project.chapters.first(where: { $0.internalID == group.internalID }) else {
                return
            }
            store.copyChapterReferenceIDToPasteboard(chapter)
        case .components:
            guard let collection = store.loadedProject?.project.collections.first(where: { $0.internalID == group.internalID }) else {
                return
            }
            store.copyReferenceIDToPasteboard(store.collectionReferenceID(for: collection), label: "Collection \(collection.displayName)")
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
    /// - Parameters:
    ///   - page: 開閉対象の HTML page。
    ///   - group: page が属する Chapter / Collection。
    private func toggle(_ page: OpenGraphitePage, in group: SidebarPageGroup) {
        if expansionState.isExpanded(pageID: page.internalID) {
            expansionState.toggle(pageID: page.internalID)
        } else {
            select(page, in: group)
            expansionState.expand(pageID: page.internalID)
        }
    }

    /// 論理名（日本語）: 選択HTML展開関数
    /// 処理概要: 選択中 HTML が表示中グループに属するときは展開し、選択解除時は残った展開表示を消します。
    private func expandSelectedPage() {
        expansionState.synchronizeSelection(
            selectedPageID: selectedPageID,
            validPageIDs: Set(visiblePages.map(\.internalID))
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
/// - `icon`: 見出しに表示するアイコン。
/// - `onSelect`: 行選択時に呼び出す処理。
/// - `onToggle`: 展開切替時に呼び出す処理。
/// - `onCopyReferenceID`: HTML カード参照 ID コピー時に呼び出す処理。
/// - `onCopyNodeReferenceID`: DOM node 参照 ID コピー時に呼び出す処理。
/// - `nodeReferenceID`: DOM node の agent 向け参照 ID を返す処理。
private struct PageLayerCard: View {
    var page: OpenGraphitePage
    var isSelected: Bool
    var isExpanded: Bool
    var nodes: [OpenGraphiteNode]
    @Binding var selectedNodeID: String?
    var icon: OpenGraphiteIcon
    var onSelect: () -> Void
    var onToggle: () -> Void
    var onCopyReferenceID: () -> Void
    var onCopyNodeReferenceID: (OpenGraphiteNode) -> Void
    var nodeReferenceID: (OpenGraphiteNode) -> String?

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
                        OpenGraphiteIconView(icon: icon, size: 14)
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
                .contextMenu {
                    Button("参照IDをコピー", action: onCopyReferenceID)
                }
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
                    selectedNodeID: $selectedNodeID,
                    onCopyNodeReferenceID: onCopyNodeReferenceID,
                    nodeReferenceID: nodeReferenceID
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
        .contextMenu {
            Button("参照IDをコピー", action: onCopyReferenceID)
        }
    }
}

/// 論理名（日本語）: レイヤーアウトライン内容ビュー
/// 概要: DOM ノード一覧を階層ツリーへ変換し、HTML カード内の Layers として表示します。
///
/// プロパティ:
/// - `nodes`: WebView から抽出されたノード一覧。
/// - `selectedNodeID`: 選択中ノード ID のバインディング。
/// - `onCopyNodeReferenceID`: DOM node 参照 ID コピー時に呼び出す処理。
/// - `nodeReferenceID`: DOM node の agent 向け参照 ID を返す処理。
private struct LayerOutlineContentView: View {
    var nodes: [OpenGraphiteNode]
    @Binding var selectedNodeID: String?
    @State private var expandedNodeIDs: Set<String> = []
    var onCopyNodeReferenceID: (OpenGraphiteNode) -> Void
    var nodeReferenceID: (OpenGraphiteNode) -> String?

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
                    },
                    onCopyReferenceID: {
                        selectedNodeID = row.id
                        onCopyNodeReferenceID(row.node)
                    }
                )
                .onCopyCommand {
                    guard row.id == selectedNodeID else { return [] }
                    return OpenGraphiteReferenceCopy.itemProviders(for: nodeReferenceID(row.node))
                }
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
/// 概要: 左ペインで表示する Project、Pages、Components のセグメント種別を表します。
///
/// 定義内容:
/// - `project`: `.ogp` が参照する実装資源と依存性。
/// - `pages`: Chapter ごとのページ一覧。
/// - `components`: Collection ごとの component master canvas 一覧。
private enum SidebarPanel: String, CaseIterable, Identifiable {
    case project
    case pages
    case components

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            return "Project"
        case .pages:
            return "Pages"
        case .components:
            return "Components"
        }
    }

    var icon: OpenGraphiteIcon {
        switch self {
        case .project:
            return .projectPanel
        case .pages:
            return .pagesPanel
        case .components:
            return .componentsPanel
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
/// - `onCopyReferenceID`: 参照 ID コピー処理。
private struct LayerRow: View {
    var row: VisibleLayerRow
    var isCollapsed: Bool
    var isSelected: Bool
    var onToggle: () -> Void
    var onSelect: () -> Void
    var onCopyReferenceID: () -> Void

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

            OpenGraphiteIconView(icon: .layerNode(row.node), size: 14)
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
        .contextMenu {
            Button("参照IDをコピー", action: onCopyReferenceID)
        }
        .accessibilityElement(children: .combine)
    }

}
