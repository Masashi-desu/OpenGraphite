import SwiftUI

/// 論理名（日本語）: テキスト内容セクション
/// 概要: 選択中 text node の HTML 標準編集カードと registry 由来の条件付き依存性カードを表示します。
///
/// プロパティ:
/// - `node`: 表示対象の選択 text node。
/// - `registry`: Text section に追加依存性を提供する registry。
struct TextContentSection: View {
    @EnvironmentObject private var store: EditorStore

    var node: OpenGraphiteNode
    var registry: InspectorTextDependencyRegistry = .standard

    var body: some View {
        InspectorSection(title: "Text", sectionID: .text) {
            TextPrimaryContentCard(model: model) {
                InspectorEditableTextValueBlock(
                    label: "Value",
                    value: model.primaryValue,
                    onPreview: { [nodeID = node.id, pageURL = store.selectedPageURL] value in
                        store.previewNodeTextContent(value, expectedNodeID: nodeID, expectedPageURL: pageURL)
                    },
                    onCommit: { [nodeID = node.id, pageURL = store.selectedPageURL] value, previousValue in
                        store.updateNodeTextContent(
                            value,
                            expectedNodeID: nodeID,
                            expectedPageURL: pageURL,
                            expectedOldValue: previousValue
                        )
                    }
                )
                .id("\(node.id)-text-primary")
            }

            ForEach(model.dependencies) { dependency in
                registry.view(for: dependency, context: renderContext)
                    .id("\(node.id)-\(dependency.id)")
            }
        }
    }

    private var model: InspectorTextSectionModel {
        let activeEditContext = store.activeResolvedTextEditContext(for: node)
        let i18nInspection = store.selectedI18nRuntimeInspection
        return InspectorTextSectionModel(
            node: node,
            activeLocale: activeEditContext?.locale,
            activeResolvedEditable: activeEditContext?.isEditable ?? false,
            i18nInspection: i18nInspection,
            i18nTextResourceValues: store.i18nTextResourceValues(for: node, inspection: i18nInspection),
            registry: registry
        )
    }

    private var renderContext: InspectorTextDependencyRenderContext {
        InspectorTextDependencyRenderContext(node: node, store: store)
    }
}

/// 論理名（日本語）: テキスト標準内容カード
/// 概要: Text section 内で HTML 本文または fallback を編集する標準カードを表示します。
///
/// プロパティ:
/// - `model`: Text section の表示モデル。
/// - `content`: 標準 text 編集 UI。
private struct TextPrimaryContentCard<Content: View>: View {
    var model: InspectorTextSectionModel
    var content: Content

    /// 論理名（日本語）: テキスト標準内容カード初期化関数
    /// 処理概要: 表示モデルと編集 UI を保持します。
    ///
    /// - Parameters:
    ///   - model: Text section の表示モデル。
    ///   - content: 標準 text 編集 UI。
    init(model: InspectorTextSectionModel, @ViewBuilder content: () -> Content) {
        self.model = model
        self.content = content()
    }

    var body: some View {
        InspectorSubsectionCard {
            InspectorCardHeader(
                title: model.primaryTitle,
                leadingSystemImage: "text.alignleft",
                pills: [
                    InspectorCardPill(label: model.primarySourceLabel, tone: .neutral),
                    InspectorCardPill(label: model.sourceLabel, tone: .neutral)
                ]
            )

            content
        }
    }
}
