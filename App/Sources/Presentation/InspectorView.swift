import Foundation
import SwiftUI

/// 論理名（日本語）: インスペクタービュー
/// 概要: 選択ノードの `data-og-*` と `--og-*` を表示・編集する右ペインです。
struct InspectorView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, EditorOverlayMetrics.titlebarInset)
            .padding(.horizontal, EditorColumnStyle.outerPadding + 4)
            .padding(.bottom, 14)

            if let projectResource = store.selectedProjectResource {
                ProjectResourceInspectorView(
                    resource: projectResource,
                    loadedProject: store.loadedProject,
                    i18nInspection: store.projectI18nRuntimeInspection,
                    onRecommendI18n: store.recommendI18nForProject,
                    onUpdateI18nRuntime: store.updateProjectI18nRuntime
                )
            } else if let node = store.selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        NodeSummaryPanel(node: node)

                        if let componentSource = store.selectedComponentSource {
                            ComponentSourceSection(source: componentSource) {
                                store.revealComponentSource(componentSource)
                            }
                        }

                        InspectorSection(title: "Context") {
                            InspectorInfoRow(label: "tag", value: node.tagName)
                            InspectorInfoRow(label: "data-og-id", value: node.displayID)
                            InspectorInfoRow(label: "data-og-type", value: node.type)
                            EditableAttributeField(
                                label: "data-og-role",
                                value: node.role ?? ""
                            ) { value in
                                store.updateNodeAttribute(name: "data-og-role", value: value)
                            }
                            .id("\(node.id)-role")
                        }

                        InspectorSection(title: "Alignment") {
                            InspectorButtonStrip(
                                title: "Align",
                                value: node.cssVariables["--og-align"] ?? "",
                                options: [
                                    InspectorButtonOption(label: "L", icon: .alignHorizontalStart, value: "flex-start"),
                                    InspectorButtonOption(label: "C", icon: .alignHorizontalCenter, value: "center"),
                                    InspectorButtonOption(label: "R", icon: .alignHorizontalEnd, value: "flex-end")
                                ]
                            ) { value in
                                store.updateCSSVariable(key: "--og-align", value: value)
                            }

                            InspectorButtonStrip(
                                title: "Justify",
                                value: node.cssVariables["--og-justify"] ?? "",
                                options: [
                                    InspectorButtonOption(label: "T", icon: .alignVerticalStart, value: "flex-start"),
                                    InspectorButtonOption(label: "M", icon: .alignVerticalCenter, value: "center"),
                                    InspectorButtonOption(label: "B", icon: .alignVerticalEnd, value: "flex-end")
                                ]
                            ) { value in
                                store.updateCSSVariable(key: "--og-justify", value: value)
                            }
                        }

                        InspectorSection(title: "Layout") {
                            LayoutModePicker(value: node.layout ?? "") { value in
                                store.updateNodeAttribute(name: "data-og-layout", value: value)
                            }

                            CSSPairVariableField(
                                key: "--og-gap",
                                value: node.cssVariables["--og-gap"] ?? "",
                                firstLabel: "Row",
                                secondLabel: "Column"
                            ) { value in
                                store.updateCSSVariable(key: "--og-gap", value: value)
                            }
                            .id("\(node.id)-gap")

                            CSSBoxVariableField(
                                key: "--og-padding",
                                value: node.cssVariables["--og-padding"] ?? "",
                                labels: ["T", "R", "B", "L"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-padding", value: value)
                            }
                            .id("\(node.id)-padding")

                            CSSBoxVariableField(
                                key: "--og-margin",
                                value: node.cssVariables["--og-margin"] ?? "",
                                labels: ["T", "R", "B", "L"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-margin", value: value)
                            }
                            .id("\(node.id)-margin")

                            CSSFlexVariableField(key: "--og-flex", value: node.cssVariables["--og-flex"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-flex", value: value)
                            }
                            .id("\(node.id)-flex")
                        }

                        InspectorSection(title: "Position") {
                            InspectorFieldGrid {
                                CSSNumericUnitVariableField(key: "--og-x", value: node.cssVariables["--og-x"] ?? "", units: ["px", "%", "rem", "em"]) { value in
                                    store.updateCSSVariable(key: "--og-x", value: value)
                                }
                                .id("\(node.id)-x")

                                CSSNumericUnitVariableField(key: "--og-y", value: node.cssVariables["--og-y"] ?? "", units: ["px", "%", "rem", "em"]) { value in
                                    store.updateCSSVariable(key: "--og-y", value: value)
                                }
                                .id("\(node.id)-y")
                            }
                        }

                        InspectorSection(title: "Dimensions") {
                            CSSDimensionVariableField(key: "--og-width", value: node.cssVariables["--og-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-width", value: value)
                            }
                            .id("\(node.id)-width")

                            CSSDimensionVariableField(key: "--og-height", value: node.cssVariables["--og-height"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-height", value: value)
                            }
                            .id("\(node.id)-height")

                            CSSDimensionVariableField(key: "--og-min-width", value: node.cssVariables["--og-min-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-min-width", value: value)
                            }
                            .id("\(node.id)-min-width")

                            CSSDimensionVariableField(key: "--og-min-height", value: node.cssVariables["--og-min-height"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-min-height", value: value)
                            }
                            .id("\(node.id)-min-height")

                            CSSDimensionVariableField(key: "--og-max-width", value: node.cssVariables["--og-max-width"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-max-width", value: value)
                            }
                            .id("\(node.id)-max-width")
                        }

                        InspectorSection(title: "Appearance") {
                            CSSBoxVariableField(
                                key: "--og-radius",
                                value: node.cssVariables["--og-radius"] ?? "",
                                labels: ["TL", "TR", "BR", "BL"]
                            ) { value in
                                store.updateCSSVariable(key: "--og-radius", value: value)
                            }
                            .id("\(node.id)-radius")

                            CSSBorderVariableField(key: "--og-border", value: node.cssVariables["--og-border"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-border", value: value)
                            }
                            .id("\(node.id)-border")

                            CSSBackgroundVariableField(
                                key: "--og-background",
                                value: node.cssVariables["--og-background"] ?? ""
                            ) { value in
                                store.updateCSSVariable(key: "--og-background", value: value)
                            }
                            .id("\(node.id)-background")

                            if node.type != "icon" {
                                CSSColorVariableField(
                                    key: "--og-foreground",
                                    value: node.cssVariables["--og-foreground"] ?? "",
                                    initialColor: .black
                                ) { value in
                                    store.updateCSSVariable(key: "--og-foreground", value: value)
                                }
                                .id("\(node.id)-foreground")
                            }
                        }

                        if node.type == "text" {
                            TextContentSection(node: node)

                            InspectorSection(title: "Typography") {
                                CSSFontFamilyVariableField(
                                    key: "--og-font-family",
                                    value: node.cssVariables["--og-font-family"] ?? "",
                                    resolvedValue: node.resolvedFontFamily ?? "",
                                    sampleText: fontPreviewText(for: node)
                                ) { value in
                                    store.updateCSSVariable(key: "--og-font-family", value: value)
                                } onSelectCandidate: { candidate in
                                    store.applyFontCandidate(candidate)
                                }
                                .id("\(node.id)-font-family")

                                InspectorFieldGrid {
                                    CSSNumericUnitVariableField(key: "--og-font-size", value: node.cssVariables["--og-font-size"] ?? "", units: ["px", "rem", "em", "%"]) { value in
                                        store.updateCSSVariable(key: "--og-font-size", value: value)
                                    }
                                    .id("\(node.id)-font-size")

                                    CSSNumericUnitVariableField(key: "--og-font-weight", value: node.cssVariables["--og-font-weight"] ?? "", units: [""]) { value in
                                        store.updateCSSVariable(key: "--og-font-weight", value: value)
                                    }
                                    .id("\(node.id)-font-weight")

                                    CSSNumericUnitVariableField(key: "--og-line-height", value: node.cssVariables["--og-line-height"] ?? "", units: ["", "px", "%", "em"]) { value in
                                        store.updateCSSVariable(key: "--og-line-height", value: value)
                                    }
                                    .id("\(node.id)-line-height")

                                    CSSNumericUnitVariableField(key: "--og-letter-spacing", value: node.cssVariables["--og-letter-spacing"] ?? "", units: ["px", "em", "rem", ""]) { value in
                                        store.updateCSSVariable(key: "--og-letter-spacing", value: value)
                                    }
                                    .id("\(node.id)-letter-spacing")
                                }

                                CSSEnumVariableField(
                                    key: "--og-text-align",
                                    value: node.cssVariables["--og-text-align"] ?? "",
                                    options: ["left", "center", "right", "justify", "start", "end"]
                                ) { value in
                                    store.updateCSSVariable(key: "--og-text-align", value: value)
                                }
                                .id("\(node.id)-text-align")
                            }
                        }

                        if node.type == "image" {
                            InspectorSection(title: "Media") {
                                CSSEnumVariableField(
                                    key: "--og-object-fit",
                                    value: node.cssVariables["--og-object-fit"] ?? "",
                                    options: ["cover", "contain", "fill", "none", "scale-down"]
                                ) { value in
                                    store.updateCSSVariable(key: "--og-object-fit", value: value)
                                }
                                .id("\(node.id)-object-fit")
                            }
                        }

                        if node.type == "icon" {
                            InspectorSection(title: "Icon") {
                                IconAttributeOptionPicker(
                                    label: "data-og-icon-library",
                                    value: node.iconLibrary ?? "lucide",
                                    options: ["lucide"]
                                ) { value in
                                    store.updateIcon(
                                        library: value,
                                        name: node.iconName ?? "circle",
                                        source: node.iconSource ?? "inline"
                                    )
                                }
                                .id("\(node.id)-icon-library")

                                IconAttributeOptionPicker(
                                    label: "data-og-icon-source",
                                    value: node.iconSource ?? "inline",
                                    options: ["inline", "cdn", "library"]
                                ) { value in
                                    store.updateIcon(
                                        library: node.iconLibrary ?? "lucide",
                                        name: node.iconName ?? "circle",
                                        source: value
                                    )
                                }
                                .id("\(node.id)-icon-source")

                                EditableAttributeField(
                                    label: "data-og-icon-name",
                                    value: node.iconName ?? ""
                                ) { value in
                                    store.updateIcon(
                                        library: node.iconLibrary ?? "lucide",
                                        name: value,
                                        source: node.iconSource ?? "inline"
                                    )
                                }
                                .id("\(node.id)-icon-name")

                                CSSColorVariableField(
                                    key: "--og-foreground",
                                    value: node.cssVariables["--og-foreground"] ?? "",
                                    initialColor: .white
                                ) { value in
                                    store.updateCSSVariable(key: "--og-foreground", value: value)
                                }
                                .id("\(node.id)-icon-foreground")

                                CSSNumericUnitVariableField(key: "--og-stroke-width", value: node.cssVariables["--og-stroke-width"] ?? "", units: ["", "px"]) { value in
                                    store.updateCSSVariable(key: "--og-stroke-width", value: value)
                                }
                                .id("\(node.id)-stroke-width")
                            }
                        }

                        InspectorSection(title: "Effects") {
                            CSSShadowVariableField(key: "--og-shadow", value: node.cssVariables["--og-shadow"] ?? "") { value in
                                store.updateCSSVariable(key: "--og-shadow", value: value)
                            }
                            .id("\(node.id)-shadow")

                            CSSPairVariableField(
                                key: "--og-transform-origin",
                                value: node.cssVariables["--og-transform-origin"] ?? "",
                                firstLabel: "X",
                                secondLabel: "Y"
                            ) { value in
                                store.updateCSSVariable(key: "--og-transform-origin", value: value)
                            }
                            .id("\(node.id)-transform-origin")

                            InspectorFieldGrid {
                                CSSNumericUnitVariableField(key: "--og-scale-x", value: node.cssVariables["--og-scale-x"] ?? "", units: [""]) { value in
                                    store.updateCSSVariable(key: "--og-scale-x", value: value)
                                }
                                .id("\(node.id)-scale-x")

                                CSSNumericUnitVariableField(key: "--og-scale-y", value: node.cssVariables["--og-scale-y"] ?? "", units: [""]) { value in
                                    store.updateCSSVariable(key: "--og-scale-y", value: value)
                                }
                                .id("\(node.id)-scale-y")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity)
            } else if let page = store.selectedPage {
                PageInspectorView(
                    page: page,
                    htmlDocumentContext: store.selectedHTMLDocumentContext,
                    i18nInspection: store.selectedI18nRuntimeInspection,
                    pageFontVariables: store.selectedPageRootCSSVariables,
                    onOpenI18nRuntime: {
                        store.selectProjectResource(.i18nRuntime)
                    },
                    onUpdatePageFontVariable: { key, value in
                        store.updateSelectedPageRootCSSVariable(key: key, value: value)
                    },
                    onSelectPageFontCandidate: { key, candidate in
                        store.applySelectedPageRootFontCandidate(variableKey: key, candidate: candidate)
                    }
                ) { x, y, width, height, name, previewContext, htmlDocumentContext in
                    store.updateSelectedHTMLDocumentContext(htmlDocumentContext)
                    store.updateSelectedPageCanvas(
                        x: x,
                        y: y,
                        width: width,
                        height: height,
                        name: name,
                        previewContext: previewContext
                    )
                }
                .id(page.id)
            } else if store.selectedCanvasSegment == .pages, let chapter = store.selectedChapter {
                ChapterInspectorView(
                    chapter: chapter,
                    referenceID: store.chapterReferenceID(for: chapter)
                )
                .id(chapter.internalID)
            } else {
                InspectorEmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func fontPreviewText(for node: OpenGraphiteNode) -> String {
        let candidateText = node.textContent ?? node.fallbackTextContent ?? ""
        let normalizedText = candidateText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedText.isEmpty {
            return OpenGraphiteFontLibrary.defaultSampleText
        }
        return normalizedText
    }
}

/// 論理名（日本語）: Chapterインスペクタービュー
/// 概要: HTML カード未選択時に、選択中 Chapter の階層情報を表示します。
///
/// プロパティ:
/// - `chapter`: 表示対象 Chapter。
/// - `referenceID`: agent 向け Chapter 参照 ID。
private struct ChapterInspectorView: View {
    var chapter: OpenGraphiteChapter
    var referenceID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ChapterSummaryPanel(chapter: chapter)

                InspectorSection(title: "Context") {
                    InspectorInfoRow(label: "id", value: chapter.id)
                    InspectorInfoRow(label: "title", value: chapter.title ?? "-")
                    InspectorInfoRow(label: "pages", value: "\(chapter.pages.count)")
                    InspectorInfoRow(label: "reference", value: referenceID ?? "-")
                }

                InspectorSection(title: "Pages") {
                    if chapter.pages.isEmpty {
                        Text("No pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(chapter.pages, id: \.internalID) { page in
                                ChapterPageHierarchyRow(page: page)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: Chapter概要パネル
/// 概要: Inspector 上部に選択 Chapter のアイコン、表示名、配下 page 数を表示します。
///
/// プロパティ:
/// - `chapter`: 表示対象 Chapter。
private struct ChapterSummaryPanel: View {
    var chapter: OpenGraphiteChapter

    var body: some View {
        HStack(spacing: 10) {
            OpenGraphiteIconView(icon: .chapterGroup, size: 16)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(chapter.pages.count) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }
}

/// 論理名（日本語）: Chapter配下ページ行
/// 概要: Chapter Inspector の Pages セクションで HTML カードの基本配置を表示します。
///
/// プロパティ:
/// - `page`: 表示する HTML page 定義。
private struct ChapterPageHierarchyRow: View {
    var page: OpenGraphitePage

    var body: some View {
        HStack(spacing: 9) {
            OpenGraphiteIconView(icon: .pageDocument, size: 14)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(page.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(pageDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
    }

    private var pageDetail: String {
        "\(page.path) · \(page.canvas.resolutionLabel) · \(page.canvas.positionLabel)"
    }
}

/// 論理名（日本語）: アイコン属性選択ピッカー
/// 概要: icon node の library/source など、候補が固定される metadata をボタン群で編集します。
///
/// プロパティ:
/// - `label`: 表示する属性名。
/// - `value`: 現在の属性値。
/// - `options`: 選択可能な属性値。
/// - `onChange`: 値選択時に呼び出す処理。
private struct IconAttributeOptionPicker: View {
    var label: String
    var value: String
    var options: [String]
    var onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 86, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    Button {
                        guard option != value else { return }
                        onChange(option)
                    } label: {
                        Text(option)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                    .fill(value == option ? EditorColumnStyle.selectedRowFill : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                    .stroke(value == option ? Color.accentColor.opacity(0.45) : EditorColumnStyle.separatorColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: コンポーネント継承元セクション
/// 概要: 選択中 instance が参照する component master の名称、場所、移動操作を表示します。
///
/// プロパティ:
/// - `source`: 表示する component master 情報。
/// - `onReveal`: component master canvas へ移動する処理。
private struct ComponentSourceSection: View {
    var source: OpenGraphiteComponentSource
    var onReveal: () -> Void

    var body: some View {
        InspectorSection(title: "Component") {
            InspectorInfoRow(label: "name", value: source.componentID)
            InspectorInfoRow(label: "location", value: source.locationLabel)
            InspectorInfoRow(label: "path", value: source.componentPagePath)
            InspectorInfoRow(label: "canvas", value: source.canvasLabel)

            Button(action: onReveal) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.square")
                    Text("Go to Component")
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Component master を表示")
        }
    }
}

/// 論理名（日本語）: ノード概要パネル
/// 概要: Inspector 上部に選択ノードのアイコン、タグ名、詳細行を表示します。
///
/// プロパティ:
/// - `node`: 表示対象の選択ノード。
private struct NodeSummaryPanel: View {
    var node: OpenGraphiteNode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(node.tagName)
                    .font(.headline)
                    .lineLimit(1)
                Text(node.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch node.type {
        case "text":
            return "textformat"
        case "button":
            return "button.programmable"
        case "image":
            return "photo"
        default:
            return "number.square"
        }
    }
}

/// 論理名（日本語）: テキスト内容セクション
/// 概要: 選択中 text node の binding metadata、HTML fallback、preview 上の resolved text を Inspector に表示します。
///
/// プロパティ:
/// - `node`: 表示対象の選択 text node。
private struct TextContentSection: View {
    @EnvironmentObject private var store: EditorStore

    var node: OpenGraphiteNode

    var body: some View {
        InspectorSection(title: "Text") {
            InspectorInfoRow(label: "source", value: node.textSourceLabel)

            if node.isTextBinding {
                InspectorInfoRow(label: "i18n key", value: node.i18nKey ?? "-")
                InspectorEditableTextValueBlock(
                    label: "Fallback",
                    value: fallbackText,
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
                .id("\(node.id)-text-fallback")

                if let activeEditContext = store.activeResolvedTextEditContext(for: node),
                   activeEditContext.isEditable {
                    InspectorEditableTextValueBlock(
                        label: "Active Resolved (\(activeEditContext.locale))",
                        value: activeText,
                        onPreview: { [nodeID = node.id, pageURL = store.selectedPageURL] value in
                            store.previewActiveResolvedTextContent(
                                value,
                                locale: activeEditContext.locale,
                                expectedNodeID: nodeID,
                                expectedPageURL: pageURL
                            )
                        },
                        onCommit: { [nodeID = node.id, pageURL = store.selectedPageURL] value, _ in
                            store.updateActiveResolvedTextContent(
                                value,
                                locale: activeEditContext.locale,
                                expectedNodeID: nodeID,
                                expectedPageURL: pageURL
                            )
                        }
                    )
                    .id("\(node.id)-text-active-\(activeEditContext.locale)")
                } else {
                    InspectorTextValueBlock(label: activeResolvedLabel, value: activeText)
                }
            } else {
                InspectorEditableTextValueBlock(
                    label: "Content",
                    value: activeText,
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
                .id("\(node.id)-text-content")
            }
        }
    }

    private var fallbackText: String {
        node.fallbackTextContent ?? node.textContent ?? ""
    }

    private var activeText: String {
        node.textContent ?? node.fallbackTextContent ?? ""
    }

    private var activeResolvedLabel: String {
        if let locale = store.activeResolvedTextEditContext(for: node)?.locale {
            return "Active Resolved (\(locale))"
        }
        return "Active Resolved"
    }
}

/// 論理名（日本語）: インスペクターテキスト値編集
/// 概要: 複数行になり得る text content を編集し、入力中は live 反映、フォーカスアウトと適用ボタンで保存します。
///
/// プロパティ:
/// - `label`: 値の種類。
/// - `value`: 現在の text content。
/// - `onPreview`: 入力中の app 内 cache 反映時に呼び出す処理。
/// - `onCommit`: 確定保存時に呼び出す処理。
private struct InspectorEditableTextValueBlock: View {
    var label: String
    var value: String
    var onPreview: (String) -> Void
    var onCommit: (String, String) -> Bool

    @State private var draft: String
    @State private var committedValue: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: インスペクターテキスト値編集初期化関数
    /// 処理概要: 現在値を draft / 確定済み基準値へコピーし、live 反映処理と保存処理を保持します。
    ///
    /// - Parameters:
    ///   - label: 値の種類。
    ///   - value: 現在の text content。
    ///   - onPreview: 入力中の app 内 cache 反映時に呼び出す処理。
    ///   - onCommit: 保存時に呼び出す処理。
    init(
        label: String,
        value: String,
        onPreview: @escaping (String) -> Void,
        onCommit: @escaping (String, String) -> Bool
    ) {
        self.label = label
        self.value = value
        self.onPreview = onPreview
        self.onCommit = onCommit
        _draft = State(initialValue: value)
        _committedValue = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: commitIfChanged) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasChanges ? Color.accentColor : Color.secondary)
                .disabled(!hasChanges)
                .help("Apply text")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft)
                    .font(.caption)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(minHeight: 72, maxHeight: 132)
                    .focused($isFocused)

                if draft.isEmpty {
                    Text("empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .stroke(isFocused ? Color.accentColor.opacity(0.55) : EditorColumnStyle.separatorColor, lineWidth: 1)
            )
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            draft = newValue
            committedValue = newValue
        }
        .onChange(of: draft) { _, _ in
            guard isFocused else { return }
            onPreview(draft)
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
        .onDisappear {
            commitIfChanged()
        }
    }

    private var hasChanges: Bool {
        draft != committedValue
    }

    /// 論理名（日本語）: インスペクターテキスト値変更時適用関数
    /// 処理概要: draft が最後に保存できた値と異なる場合だけ text content を確定保存します。
    private func commitIfChanged() {
        guard hasChanges else { return }
        if onCommit(draft, committedValue) {
            committedValue = draft
        }
    }
}

/// 論理名（日本語）: インスペクターテキスト値表示
/// 概要: 複数行になり得る text content を読み取り専用で表示します。
///
/// プロパティ:
/// - `label`: 値の種類。
/// - `value`: 表示する text content。
private struct InspectorTextValueBlock: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(displayValue)
                .font(.caption)
                .textSelection(.enabled)
                .foregroundStyle(isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
                )
        }
    }

    private var displayValue: String {
        isEmpty ? "empty" : value
    }

    private var isEmpty: Bool {
        value.isEmpty
    }
}

/// 論理名（日本語）: ページキャンバス入力値
/// 概要: Inspector で編集するページのキャンバス座標と解像度をまとめます。
///
/// プロパティ:
/// - `x`: キャンバス上の X 座標。
/// - `y`: キャンバス上の Y 座標。
/// - `width`: ページプレビュー幅。
/// - `height`: ページプレビュー高さ。
/// - `name`: フロー解決に使う配置名。名前なしは空文字です。
/// - `previewContext`: エディター内 preview に注入する runtime Mock State。
private struct PageCanvasInput: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var name: String
    var previewContext: OpenGraphitePreviewContext

    /// 論理名（日本語）: ページキャンバス入力値初期化関数
    /// 処理概要: `OpenGraphiteCanvas` から Inspector 入力比較用の値を生成します。
    ///
    /// - Parameter canvas: 入力値へ変換するキャンバス定義。
    init(canvas: OpenGraphiteCanvas) {
        x = canvas.x
        y = canvas.y
        width = canvas.width
        height = canvas.height
        name = Self.normalizedName(canvas.name)
        previewContext = canvas.previewContext
    }

    /// 論理名（日本語）: ページキャンバス入力値初期化関数
    /// 処理概要: パース済みの各数値と preview Mock State から Inspector 入力値を生成します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。
    ///   - height: ページプレビュー高さ。
    ///   - name: フロー解決に使う配置名。
    ///   - previewContext: エディター内 preview に注入する runtime Mock State。
    init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String,
        previewContext: OpenGraphitePreviewContext
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.name = Self.normalizedName(name)
        self.previewContext = previewContext
    }

    /// 論理名（日本語）: ページキャンバス配置名正規化関数
    /// 処理概要: 入力された配置名の前後空白を除去し、空なら空文字へ変換します。
    ///
    /// - Parameter name: 正規化する配置名。
    /// - Returns: 比較・保存用の配置名。
    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 論理名（日本語）: ページキャンバス寸法軸
/// 概要: アスペクト比ロック時に編集された寸法の軸を表します。
///
/// 定義内容:
/// - `width`: 幅を編集した状態。
/// - `height`: 高さを編集した状態。
private enum PageCanvasDimension {
    case width
    case height
}

/// 論理名（日本語）: Preview mock state draft
/// 概要: Inspector 上で編集中の runtime mock state override 1 行を表します。
///
/// プロパティ:
/// - `id`: SwiftUI の行識別子。
/// - `name`: runtime が参照する parameter 名。
/// - `value`: override 値。空文字も有効な注入値です。
/// - `isOverrideEnabled`: preview へ注入するか。
private struct PreviewMockFieldDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var value: String
    var isOverrideEnabled: Bool
}

/// 論理名（日本語）: ページインスペクタービュー
/// 概要: 選択ページの HTML 相対パス、解像度、キャンバス配置を表示・編集します。
///
/// プロパティ:
/// - `page`: 表示・編集対象のページ。
/// - `htmlDocumentContext`: HTML 正本の `<html>` attribute と binding metadata。
/// - `i18nInspection`: 実装資源から検出した i18n runtime 設定。
/// - `pageFontVariables`: ページ root node に保存されている locale font-family 変数。
/// - `onOpenI18nRuntime`: Project 依存性の i18n runtime 選択へ移動する処理。
/// - `onUpdatePageFontVariable`: ページ root node の font-family 変数を保存する処理。
/// - `onSelectPageFontCandidate`: フォントブラウザの候補をページ root node へ保存する処理。
/// - `onCommit`: 有効なキャンバス入力を適用する処理。
private struct PageInspectorView: View {
    var page: OpenGraphitePage
    var htmlDocumentContext: OpenGraphiteHTMLDocumentContext
    var i18nInspection: OpenGraphiteI18nRuntimeInspection?
    var pageFontVariables: [String: String]
    var onOpenI18nRuntime: () -> Void
    var onUpdatePageFontVariable: (String, String) -> Void
    var onSelectPageFontCandidate: (String, OpenGraphiteFontCandidate) -> Void
    var onCommit: (Double, Double, Double, Double, String, OpenGraphitePreviewContext, OpenGraphiteHTMLDocumentContext) -> Void

    @State private var nameDraft: String
    @State private var xDraft: String
    @State private var yDraft: String
    @State private var widthDraft: String
    @State private var heightDraft: String
    @State private var langSourceDraft: OpenGraphiteHTMLLangSource
    @State private var langValueDraft: String
    @State private var langFieldDraft: String
    @State private var dirSourceDraft: OpenGraphiteHTMLDirSource
    @State private var dirValueDraft: String
    @State private var dirFieldDraft: String
    @State private var mockFieldDrafts: [PreviewMockFieldDraft]
    @State private var isAspectRatioLocked: Bool
    @State private var lockedAspectRatio: PageCanvasAspectRatio?

    /// 論理名（日本語）: ページインスペクター初期化関数
    /// 処理概要: 選択ページの現在キャンバス値を入力欄の初期値として保持します。
    ///
    /// - Parameters:
    ///   - page: 表示・編集対象のページ。
    ///   - htmlDocumentContext: HTML 正本の `<html>` attribute と binding metadata。
    ///   - i18nInspection: 実装資源から検出した i18n runtime 設定。
    ///   - pageFontVariables: ページ root node に保存されている locale font-family 変数。
    ///   - onOpenI18nRuntime: Project 依存性の i18n runtime 選択へ移動する処理。
    ///   - onUpdatePageFontVariable: ページ root node の font-family 変数を保存する処理。
    ///   - onSelectPageFontCandidate: フォントブラウザの候補をページ root node へ保存する処理。
    ///   - onCommit: 有効なキャンバス入力を適用する処理。
    init(
        page: OpenGraphitePage,
        htmlDocumentContext: OpenGraphiteHTMLDocumentContext,
        i18nInspection: OpenGraphiteI18nRuntimeInspection?,
        pageFontVariables: [String: String],
        onOpenI18nRuntime: @escaping () -> Void,
        onUpdatePageFontVariable: @escaping (String, String) -> Void,
        onSelectPageFontCandidate: @escaping (String, OpenGraphiteFontCandidate) -> Void,
        onCommit: @escaping (Double, Double, Double, Double, String, OpenGraphitePreviewContext, OpenGraphiteHTMLDocumentContext) -> Void
    ) {
        self.page = page
        self.htmlDocumentContext = htmlDocumentContext
        self.i18nInspection = i18nInspection
        self.pageFontVariables = pageFontVariables
        self.onOpenI18nRuntime = onOpenI18nRuntime
        self.onUpdatePageFontVariable = onUpdatePageFontVariable
        self.onSelectPageFontCandidate = onSelectPageFontCandidate
        self.onCommit = onCommit
        _nameDraft = State(initialValue: page.canvas.displayName ?? "")
        _xDraft = State(initialValue: Self.draftText(for: page.canvas.x))
        _yDraft = State(initialValue: Self.draftText(for: page.canvas.y))
        _widthDraft = State(initialValue: Self.draftText(for: page.canvas.width))
        _heightDraft = State(initialValue: Self.draftText(for: page.canvas.height))
        _langSourceDraft = State(initialValue: htmlDocumentContext.langSource)
        _langValueDraft = State(initialValue: htmlDocumentContext.langValue)
        _langFieldDraft = State(initialValue: htmlDocumentContext.langField)
        _dirSourceDraft = State(initialValue: htmlDocumentContext.dirSource)
        _dirValueDraft = State(initialValue: htmlDocumentContext.dirValue)
        _dirFieldDraft = State(initialValue: htmlDocumentContext.dirField)
        let injectableMockFieldNames = Self.injectableMockFieldNames(
            langSource: htmlDocumentContext.langSource,
            langField: htmlDocumentContext.langField,
            dirSource: htmlDocumentContext.dirSource,
            dirField: htmlDocumentContext.dirField,
            i18nLocaleField: i18nInspection?.localeField,
            fieldMocks: page.canvas.previewContext.fieldMocks
        )
        _mockFieldDrafts = State(initialValue: Self.mockFieldDrafts(
            for: page.canvas.previewContext.fieldMocks,
            injectableFieldNames: injectableMockFieldNames
        ))
        _isAspectRatioLocked = State(initialValue: false)
        _lockedAspectRatio = State(initialValue: PageCanvasAspectRatio(width: page.canvas.width, height: page.canvas.height))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PageSummaryPanel(page: page)

                InspectorSection(title: "Context") {
                    InspectorInfoRow(label: "path", value: page.path)
                    InspectorInfoRow(label: "name", value: page.canvas.displayName ?? "-")
                    InspectorInfoRow(label: "resolution", value: page.canvas.resolutionLabel)
                    InspectorInfoRow(label: "position", value: page.canvas.positionLabel)
                    InspectorInfoRow(label: "html lang", value: htmlDocumentContext.langValue.isEmpty ? "-" : htmlDocumentContext.langValue)
                    InspectorInfoRow(label: "text dir", value: htmlDocumentContext.dirValue.isEmpty ? "-" : htmlDocumentContext.dirValue)
                }

                InspectorSection(title: "HTML Document") {
                    HTMLLangDocumentEditor(
                        source: $langSourceDraft,
                        value: $langValueDraft,
                        field: $langFieldDraft,
                        onSubmit: commitIfValid
                    )

                    HTMLDirDocumentEditor(
                        source: $dirSourceDraft,
                        value: $dirValueDraft,
                        field: $dirFieldDraft,
                        isInvalidValue: isInvalidDirectionDraft,
                        onSubmit: commitIfValid
                    )
                }

                InspectorSection(title: "I18n Runtime") {
                    I18nRuntimeSummarySection(
                        inspection: i18nInspection,
                        onOpenProjectResource: onOpenI18nRuntime
                    )
                }

                InspectorSection(title: "Locale Typography") {
                    LocaleTypographyFontSection(
                        variables: pageFontVariables,
                        htmlDocumentContext: htmlDocumentContext,
                        previewContext: page.canvas.previewContext,
                        i18nInspection: i18nInspection,
                        onCommit: onUpdatePageFontVariable,
                        onSelectCandidate: onSelectPageFontCandidate
                    )
                }

                InspectorSection(title: "Mock State") {
                    PreviewMockStateEditor(entries: $mockFieldDrafts, onSubmit: commitIfValid)
                }

                InspectorSection(title: "Canvas") {
                    OptionalCanvasNameField(
                        label: "Name",
                        text: $nameDraft,
                        onSubmit: commitIfValid
                    )

                    InspectorFieldGrid {
                        RequiredCanvasNumberField(
                            label: "X",
                            text: $xDraft,
                            isInvalid: isInvalidDraft(xDraft),
                            onSubmit: commitIfValid
                        )

                        RequiredCanvasNumberField(
                            label: "Y",
                            text: $yDraft,
                            isInvalid: isInvalidDraft(yDraft),
                            onSubmit: commitIfValid
                        )
                    }

                    InspectorLinkedParameterGroup(isActive: isAspectRatioLocked) {
                        HStack(alignment: .bottom, spacing: 8) {
                            RequiredCanvasNumberField(
                                label: "W",
                                text: widthBinding,
                                isInvalid: isInvalidDraft(widthDraft, requiresPositive: true),
                                showsRelationship: isAspectRatioLocked,
                                onSubmit: commitIfValid
                            )

                            InspectorLinkedParameterButton(
                                isOn: isAspectRatioLocked,
                                label: "Canvas のアスペクト比ロック",
                                activeHelp: "アスペクト比ロックを解除",
                                inactiveHelp: "アスペクト比をロック",
                                action: toggleAspectRatioLock
                            )
                            .padding(.bottom, 1)

                            RequiredCanvasNumberField(
                                label: "H",
                                text: heightBinding,
                                isInvalid: isInvalidDraft(heightDraft, requiresPositive: true),
                                showsRelationship: isAspectRatioLocked,
                                onSubmit: commitIfValid
                            )
                        }
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption2)
                            .foregroundStyle(Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: commitIfValid) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Apply")
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(canCommit ? Color.white : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                .fill(canCommit ? Color.accentColor : EditorColumnStyle.elevatedRowFill)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCommit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: page.canvas) { _, nextCanvas in
            resetDrafts(with: nextCanvas)
        }
        .onChange(of: htmlDocumentContext) { _, nextContext in
            resetHTMLDocumentDrafts(with: nextContext)
        }
        .onChange(of: i18nInspection) { _, _ in
            synchronizeMockFieldDrafts()
        }
        .onChange(of: langSourceDraft) { _, _ in
            synchronizeMockFieldDrafts()
        }
        .onChange(of: langFieldDraft) { _, _ in
            synchronizeMockFieldDrafts()
        }
        .onChange(of: dirSourceDraft) { _, _ in
            synchronizeMockFieldDrafts()
        }
        .onChange(of: dirFieldDraft) { _, _ in
            synchronizeMockFieldDrafts()
        }
    }

    private var widthBinding: Binding<String> {
        Binding(
            get: { widthDraft },
            set: { newValue in
                applyDimensionDraft(newValue, editedDimension: .width)
            }
        )
    }

    private var heightBinding: Binding<String> {
        Binding(
            get: { heightDraft },
            set: { newValue in
                applyDimensionDraft(newValue, editedDimension: .height)
            }
        )
    }

    private var normalizedDrafts: [String] {
        [
            xDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            yDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            widthDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            heightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private var normalizedNameDraft: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedInput: PageCanvasInput? {
        guard validationMessage == nil else { return nil }
        let values = normalizedDrafts
        guard let x = Double(values[0]),
              let y = Double(values[1]),
              let width = Double(values[2]),
              let height = Double(values[3])
        else {
            return nil
        }
        guard let previewContext = parsedPreviewContext else {
            return nil
        }
        return PageCanvasInput(
            x: x,
            y: y,
            width: width,
            height: height,
            name: normalizedNameDraft,
            previewContext: previewContext
        )
    }

    private var validationMessage: String? {
        let values = normalizedDrafts
        guard !values.contains(where: \.isEmpty) else {
            return "X / Y / Width / Height はすべて入力必須です。"
        }
        guard let x = Double(values[0]),
              let y = Double(values[1]),
              let width = Double(values[2]),
              let height = Double(values[3])
        else {
            return "キャンバス配置には数値を入力してください。"
        }
        guard [x, y, width, height].allSatisfy(\.isFinite) else {
            return "キャンバス配置には有限の数値を入力してください。"
        }
        guard width > 0, height > 0 else {
            return "Width / Height は 0 より大きい数値が必要です。"
        }
        guard parsedHTMLDocumentContext != nil else {
            if langSourceDraft == .binding && normalizedLangFieldDraft.isEmpty {
                return "HTML Lang の Binding には Field が必要です。"
            }
            if dirSourceDraft == .binding && normalizedDirFieldDraft.isEmpty {
                return "Text Dir の Binding には Field が必要です。"
            }
            return "HTML Document の入力が不正です。"
        }
        if isInvalidDirectionDraft {
            return "Text Dir は ltr / rtl / auto のいずれか、または空にしてください。"
        }
        if parsedFieldMocks == nil {
            return "Mock State は ON の行に一意な parameter 名が必要です。"
        }
        return nil
    }

    private var canCommit: Bool {
        guard let parsedInput,
              let parsedHTMLDocumentContext
        else {
            return false
        }
        return parsedInput != PageCanvasInput(canvas: page.canvas)
            || parsedHTMLDocumentContext != htmlDocumentContext
    }

    private var currentDraftAspectRatio: PageCanvasAspectRatio? {
        let widthValue = widthDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let heightValue = heightDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let width = Double(widthValue),
              let height = Double(heightValue)
        else {
            return nil
        }
        return PageCanvasAspectRatio(width: width, height: height)
    }

    private var parsedPreviewContext: OpenGraphitePreviewContext? {
        guard let fieldMocks = parsedFieldMocks else {
            return nil
        }
        return OpenGraphitePreviewContext(
            fieldMocks: fieldMocks,
            placementMocks: page.canvas.previewContext.placementMocks
        )
    }

    private var parsedHTMLDocumentContext: OpenGraphiteHTMLDocumentContext? {
        guard !isInvalidDirectionDraft else { return nil }
        guard langSourceDraft != .binding || !normalizedLangFieldDraft.isEmpty else { return nil }
        guard dirSourceDraft != .binding || !normalizedDirFieldDraft.isEmpty else { return nil }
        return OpenGraphiteHTMLDocumentContext(
            langSource: langSourceDraft,
            langValue: langValueDraft,
            langField: langFieldDraft,
            dirSource: dirSourceDraft,
            dirValue: dirValueDraft,
            dirField: dirFieldDraft
        )
    }

    private var parsedFieldMocks: [String: String]? {
        var result: [String: String] = [:]
        for entry in mockFieldDrafts {
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard entry.isOverrideEnabled else { continue }
            guard !name.isEmpty, result[name] == nil else { return nil }
            result[name] = value
        }
        return result
    }

    private var isInvalidDirectionDraft: Bool {
        let direction = dirValueDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !direction.isEmpty && !["ltr", "rtl", "auto"].contains(direction)
    }

    private var normalizedLangFieldDraft: String {
        langFieldDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDirFieldDraft: String {
        dirFieldDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentInjectableMockFieldNames: [String] {
        Self.injectableMockFieldNames(
            langSource: langSourceDraft,
            langField: langFieldDraft,
            dirSource: dirSourceDraft,
            dirField: dirFieldDraft,
            i18nLocaleField: i18nInspection?.localeField,
            fieldMocks: page.canvas.previewContext.fieldMocks
        )
    }

    /// 論理名（日本語）: ページキャンバス寸法入力反映関数
    /// 処理概要: W/H の一方が編集されたとき、アスペクト比ロック中なら他方を同じ比率で更新します。
    ///
    /// - Parameters:
    ///   - newValue: 編集された入力文字列。
    ///   - editedDimension: 編集元の寸法軸。
    private func applyDimensionDraft(_ newValue: String, editedDimension: PageCanvasDimension) {
        switch editedDimension {
        case .width:
            widthDraft = newValue
        case .height:
            heightDraft = newValue
        }

        guard isAspectRatioLocked,
              let ratio = lockedAspectRatio ?? currentDraftAspectRatio,
              let editedValue = Double(newValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              editedValue.isFinite,
              editedValue > 0
        else {
            return
        }

        switch editedDimension {
        case .width:
            guard let height = ratio.height(forWidth: editedValue) else { return }
            heightDraft = Self.draftText(for: height)
        case .height:
            guard let width = ratio.width(forHeight: editedValue) else { return }
            widthDraft = Self.draftText(for: width)
        }
    }

    /// 論理名（日本語）: ページキャンバスアスペクト比ロック切替関数
    /// 処理概要: W/H の連動状態を切り替え、有効化時は現在の入力値から固定比率を取得します。
    private func toggleAspectRatioLock() {
        isAspectRatioLocked.toggle()
        guard isAspectRatioLocked else { return }
        lockedAspectRatio = currentDraftAspectRatio ?? PageCanvasAspectRatio(width: page.canvas.width, height: page.canvas.height)
    }

    /// 論理名（日本語）: ページキャンバス入力確定関数
    /// 処理概要: 必須入力と数値条件を満たす場合だけキャンバス配置を適用します。
    private func commitIfValid() {
        guard let parsedInput,
              let parsedHTMLDocumentContext
        else {
            return
        }
        onCommit(
            parsedInput.x,
            parsedInput.y,
            parsedInput.width,
            parsedInput.height,
            parsedInput.name,
            parsedInput.previewContext,
            parsedHTMLDocumentContext
        )
    }

    /// 論理名（日本語）: ページキャンバスdraftリセット関数
    /// 処理概要: Store 側で更新されたキャンバス値を入力欄へ反映します。
    ///
    /// - Parameter canvas: 入力欄へ反映するキャンバス定義。
    private func resetDrafts(with canvas: OpenGraphiteCanvas) {
        nameDraft = canvas.displayName ?? ""
        xDraft = Self.draftText(for: canvas.x)
        yDraft = Self.draftText(for: canvas.y)
        widthDraft = Self.draftText(for: canvas.width)
        heightDraft = Self.draftText(for: canvas.height)
        mockFieldDrafts = Self.mockFieldDrafts(
            for: canvas.previewContext.fieldMocks,
            injectableFieldNames: Self.injectableMockFieldNames(
                langSource: langSourceDraft,
                langField: langFieldDraft,
                dirSource: dirSourceDraft,
                dirField: dirFieldDraft,
                i18nLocaleField: i18nInspection?.localeField,
                fieldMocks: canvas.previewContext.fieldMocks
            )
        )
        if isAspectRatioLocked {
            lockedAspectRatio = PageCanvasAspectRatio(width: canvas.width, height: canvas.height)
        }
    }

    /// 論理名（日本語）: HTML Document draftリセット関数
    /// 処理概要: Store 側で更新された HTML document context を入力欄へ反映します。
    ///
    /// - Parameter context: 入力欄へ反映する HTML document context。
    private func resetHTMLDocumentDrafts(with context: OpenGraphiteHTMLDocumentContext) {
        langSourceDraft = context.langSource
        langValueDraft = context.langValue
        langFieldDraft = context.langField
        dirSourceDraft = context.dirSource
        dirValueDraft = context.dirValue
        dirFieldDraft = context.dirField
        mockFieldDrafts = Self.mockFieldDrafts(
            for: page.canvas.previewContext.fieldMocks,
            injectableFieldNames: Self.injectableMockFieldNames(
                langSource: context.langSource,
                langField: context.langField,
                dirSource: context.dirSource,
                dirField: context.dirField,
                i18nLocaleField: i18nInspection?.localeField,
                fieldMocks: page.canvas.previewContext.fieldMocks
            ),
            preserving: mockFieldDrafts
        )
    }

    /// 論理名（日本語）: Mock State draft同期関数
    /// 処理概要: HTML Document の binding metadata と保存済み Mock State から注入可能フィールド行を再構成します。
    private func synchronizeMockFieldDrafts() {
        mockFieldDrafts = Self.mockFieldDrafts(
            for: page.canvas.previewContext.fieldMocks,
            injectableFieldNames: currentInjectableMockFieldNames,
            preserving: mockFieldDrafts
        )
    }

    /// 論理名（日本語）: ページキャンバスdraft検証関数
    /// 処理概要: 単一入力欄が必須・数値・正値条件を満たさない場合に invalid と判定します。
    ///
    /// - Parameters:
    ///   - draft: 検証する入力文字列。
    ///   - requiresPositive: 0 より大きい値が必要か。
    /// - Returns: 入力が不正な場合は `true`。
    private func isInvalidDraft(_ draft: String, requiresPositive: Bool = false) -> Bool {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let number = Double(value),
              number.isFinite
        else {
            return true
        }
        return requiresPositive && number <= 0
    }

    /// 論理名（日本語）: ページキャンバスdraft文字列生成関数
    /// 処理概要: 数値の編集しやすさを優先し、整数値は小数点なしで表示します。
    ///
    /// - Parameter value: 入力欄に表示する数値。
    /// - Returns: 入力欄向けの文字列。
    private static func draftText(for value: Double) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(value)
    }

    /// 論理名（日本語）: 注入可能Mock Stateフィールド名生成関数
    /// 処理概要: HTML Document binding field と保存済み Mock State key から Inspector に表示する field 名を生成します。
    ///
    /// - Parameters:
    ///   - langSource: HTML Lang の source mode。
    ///   - langField: HTML Lang binding の field 名。
    ///   - dirSource: Text Dir の source mode。
    ///   - dirField: Text Dir binding の field 名。
    ///   - i18nLocaleField: 実装 runtime が言語解決に使う field 名。
    ///   - fieldMocks: `.ogp` に保存済みの runtime mock state 辞書。
    /// - Returns: 重複と空白名を除いた field 名。
    private static func injectableMockFieldNames(
        langSource: OpenGraphiteHTMLLangSource,
        langField: String,
        dirSource: OpenGraphiteHTMLDirSource,
        dirField: String,
        i18nLocaleField: String?,
        fieldMocks: [String: String]
    ) -> [String] {
        var names: [String] = []

        func appendUnique(_ rawName: String) {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !names.contains(name) else { return }
            names.append(name)
        }

        if langSource == .binding {
            appendUnique(langField)
        }
        if dirSource == .binding {
            appendUnique(dirField)
        }
        if let i18nLocaleField {
            appendUnique(i18nLocaleField)
        }
        for name in fieldMocks.keys.sorted() {
            appendUnique(name)
        }

        return names
    }

    /// 論理名（日本語）: mock state draft生成関数
    /// 処理概要: 注入可能 field 名と runtime mock state 辞書を Inspector の行 draft へ変換します。
    ///
    /// - Parameter fieldMocks: runtime mock state 辞書。
    /// - Parameter injectableFieldNames: Inspector に表示する注入可能 field 名。
    /// - Parameter currentDrafts: 編集中の値と ON/OFF を保持したい既存行。
    /// - Returns: 入力欄向けの行 draft。
    private static func mockFieldDrafts(
        for fieldMocks: [String: String],
        injectableFieldNames: [String],
        preserving currentDrafts: [PreviewMockFieldDraft] = []
    ) -> [PreviewMockFieldDraft] {
        let preservedDrafts = currentDrafts.reduce(into: [String: PreviewMockFieldDraft]()) { result, draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, result[name] == nil else { return }
            var normalizedDraft = draft
            normalizedDraft.name = name
            result[name] = normalizedDraft
        }

        return injectableFieldNames.compactMap { rawName in
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            if let preservedDraft = preservedDrafts[name] {
                return preservedDraft
            }
            if let savedValue = fieldMocks[name] {
                return PreviewMockFieldDraft(name: name, value: savedValue, isOverrideEnabled: true)
            }
            return PreviewMockFieldDraft(name: name, value: "", isOverrideEnabled: false)
        }
    }
}

/// 論理名（日本語）: Locale別フォント行
/// 概要: Page Inspector の Locale Typography セクションに表示する font-family 変数行を表します。
///
/// プロパティ:
/// - `id`: SwiftUI の行識別子。
/// - `title`: 表示名。
/// - `detail`: 補助情報。
/// - `variable`: 保存対象の CSS 変数名。
private struct LocaleTypographyFontEntry: Identifiable, Equatable {
    var id: String { variable }
    var title: String
    var detail: String
    var variable: String
}

/// 論理名（日本語）: Locale別タイポグラフィセクション
/// 概要: ページ root node の default / locale 別 font-family 変数を編集します。
///
/// プロパティ:
/// - `variables`: ページ root node の CSS 変数。
/// - `htmlDocumentContext`: HTML 正本の `<html>` attribute と binding metadata。
/// - `previewContext`: Page canvas の preview mock state。
/// - `i18nInspection`: 実装資源から検出した i18n runtime 設定。
/// - `onCommit`: CSS 値の直接編集を保存する処理。
/// - `onSelectCandidate`: フォントブラウザの候補を保存する処理。
private struct LocaleTypographyFontSection: View {
    var variables: [String: String]
    var htmlDocumentContext: OpenGraphiteHTMLDocumentContext
    var previewContext: OpenGraphitePreviewContext
    var i18nInspection: OpenGraphiteI18nRuntimeInspection?
    var onCommit: (String, String) -> Void
    var onSelectCandidate: (String, OpenGraphiteFontCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let activeLocaleLabel {
                InspectorInfoRow(label: "Active", value: activeLocaleLabel)
            }

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(entry.detail)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    CSSFontFamilyVariableField(
                        key: entry.variable,
                        value: variables[entry.variable] ?? ""
                    ) { value in
                        onCommit(entry.variable, value)
                    } onSelectCandidate: { candidate in
                        onSelectCandidate(entry.variable, candidate)
                    }
                }
                .padding(8)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(EditorColumnStyle.separatorColor.opacity(0.7), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entries: [LocaleTypographyFontEntry] {
        var result = [
            LocaleTypographyFontEntry(
                title: "Default",
                detail: "--og-font-family-default",
                variable: "--og-font-family-default"
            )
        ]
        var seenVariables = Set(result.map(\.variable))

        for locale in localeCandidates {
            guard let entry = Self.entry(forLocale: locale),
                  !seenVariables.contains(entry.variable)
            else {
                continue
            }
            result.append(entry)
            seenVariables.insert(entry.variable)
        }

        return result
    }

    private var localeCandidates: [String] {
        var locales: [String] = []

        func appendLocale(_ value: String?) {
            guard let normalized = Self.normalizedLocale(value),
                  !locales.contains(normalized)
            else {
                return
            }
            locales.append(normalized)
        }

        appendLocale(htmlDocumentContext.langValue)
        if htmlDocumentContext.langSource == .binding {
            appendLocale(previewContext.fieldMocks[htmlDocumentContext.langField])
        }
        if let localeField = i18nInspection?.localeField {
            appendLocale(previewContext.fieldMocks[localeField])
        }
        appendLocale(i18nInspection?.lng.value)
        appendLocale(i18nInspection?.fallbackLng.value)
        for resource in i18nInspection?.resources ?? [] {
            appendLocale(resource.locale)
        }

        return locales
    }

    private var activeLocaleLabel: String? {
        if htmlDocumentContext.langSource == .binding,
           let normalized = Self.normalizedLocale(previewContext.fieldMocks[htmlDocumentContext.langField]) {
            return normalized
        }
        return Self.normalizedLocale(htmlDocumentContext.langValue)
            ?? i18nInspection?.localeField.flatMap { Self.normalizedLocale(previewContext.fieldMocks[$0]) }
    }

    /// 論理名（日本語）: Localeフォント行生成関数
    /// 処理概要: locale 名を対応する `--og-font-family-<locale>` 変数行へ変換します。
    ///
    /// - Parameter locale: locale 名。
    /// - Returns: 表示行。locale 名が不正な場合は `nil`。
    private static func entry(forLocale locale: String) -> LocaleTypographyFontEntry? {
        guard let normalized = normalizedLocale(locale) else { return nil }
        return LocaleTypographyFontEntry(
            title: localizedLocaleName(for: normalized),
            detail: "--og-font-family-\(normalized)",
            variable: "--og-font-family-\(normalized)"
        )
    }

    /// 論理名（日本語）: Locale名正規化関数
    /// 処理概要: CSS 変数 suffix に使える lowercase locale token へ変換します。
    ///
    /// - Parameter locale: 入力 locale 名。
    /// - Returns: 正規化済み locale。空または不正な場合は `nil`。
    private static func normalizedLocale(_ locale: String?) -> String? {
        guard let locale else { return nil }
        let lowered = locale
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            let value = scalar.value
            if (48...57).contains(value) || (97...122).contains(value) {
                return Character(String(scalar))
            }
            return "-"
        }
        let normalized = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return normalized.isEmpty ? nil : normalized
    }

    /// 論理名（日本語）: Locale表示名生成関数
    /// 処理概要: システムの locale 表示名を使い、取得できない場合は token を表示します。
    ///
    /// - Parameter locale: 正規化済み locale token。
    /// - Returns: Inspector 表示用 locale 名。
    private static func localizedLocaleName(for locale: String) -> String {
        if let name = Locale.current.localizedString(forIdentifier: locale), !name.isEmpty {
            return "\(name) (\(locale))"
        }
        return locale
    }
}

/// 論理名（日本語）: Project資源インスペクター
/// 概要: Project セグメントで選択した実装資源と依存性の詳細を表示・編集します。
///
/// プロパティ:
/// - `resource`: 選択中の Project 資源。
/// - `loadedProject`: 読み込み済み `.ogp`。
/// - `inspection`: i18n runtime 検査結果。
/// - `onRecommendI18n`: 推奨 runtime / locale JSON を実装資源へ作成する処理。
/// - `onUpdateI18nRuntime`: literal i18n runtime 設定を実装資源へ保存する処理。
private struct ProjectResourceInspectorView: View {
    var resource: OpenGraphiteProjectResourceSelection
    var loadedProject: LoadedOpenGraphiteProject?
    var i18nInspection: OpenGraphiteI18nRuntimeInspection?
    var onRecommendI18n: () -> Void
    var onUpdateI18nRuntime: (_ loadPath: String?, _ fallbackLocale: String?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ProjectResourceSummaryPanel(resource: resource)

                switch resource {
                case .overview:
                    projectOverview
                case .htmlRoot:
                    pathResourceSection(title: "HTML Root", path: htmlRootPath)
                case .cssLibrary:
                    pathResourceSection(title: "CSS", path: loadedProject?.project.cssLibrary ?? "-")
                case .runtime(let path):
                    pathResourceSection(title: "Runtime", path: path)
                case .iconCDN(let library, let provider, let package, let version, let usedCount, let iconNames):
                    iconCDNResourceSection(
                        library: library,
                        provider: provider,
                        package: package,
                        version: version,
                        usedCount: usedCount,
                        iconNames: iconNames
                    )
                case .i18nRuntime:
                    InspectorSection(title: "I18n Runtime") {
                        I18nRuntimeEditorSection(
                            inspection: i18nInspection,
                            onRecommend: onRecommendI18n,
                            onCommit: onUpdateI18nRuntime
                        )
                    }
                case .localeResource(let locale, let path):
                    InspectorSection(title: "Locale Resource") {
                        LocaleResourceInspectorSection(
                            locale: locale,
                            path: path,
                            status: localeStatus(locale: locale, path: path),
                            onCreate: onRecommendI18n
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var projectOverview: some View {
        InspectorSection(title: "Project") {
            InspectorInfoRow(label: "name", value: loadedProject?.project.name ?? "-")
            InspectorInfoRow(label: "manifest", value: loadedProject?.fileURL.lastPathComponent ?? "-")
            InspectorInfoRow(label: "repository", value: loadedProject?.rootURL.path ?? "-")
            InspectorInfoRow(label: "html root", value: loadedProject?.project.htmlRoot ?? "-")
            InspectorInfoRow(label: "css", value: loadedProject?.project.cssLibrary ?? "-")
        }

        InspectorSection(title: "I18n Runtime") {
            I18nRuntimeSummaryContent(inspection: i18nInspection)
        }
    }

    @ViewBuilder
    private func iconCDNResourceSection(
        library: String,
        provider: String,
        package: String,
        version: String,
        usedCount: Int,
        iconNames: [String]
    ) -> some View {
        InspectorSection(title: "Icon CDN") {
            InspectorInfoRow(label: "Library", value: library)
            InspectorInfoRow(label: "Provider", value: provider)
            InspectorInfoRow(label: "Package", value: package)
            InspectorInfoRow(label: "Version", value: version.isEmpty ? "-" : version)
            InspectorInfoRow(label: "Status", value: version.lowercased() == "latest" ? "Unpinned" : "External")
            InspectorInfoRow(label: "Used Count", value: "\(usedCount)")
            InspectorInfoRow(label: "Icons", value: iconNames.isEmpty ? "-" : iconNames.joined(separator: ", "))
        }
    }

    @ViewBuilder
    private func pathResourceSection(title: String, path: String) -> some View {
        InspectorSection(title: title) {
            InspectorInfoRow(label: "path", value: path)
            InspectorInfoRow(label: "status", value: resolvedURL(for: path).map { FileManager.default.fileExists(atPath: $0.path) ? "Found" : "Missing" } ?? "-")
            if let url = resolvedURL(for: path) {
                InspectorInfoRow(label: "resolved", value: url.path)
            }
        }
    }

    private var htmlRootPath: String {
        loadedProject?.project.htmlRoot ?? "-"
    }

    private func resolvedURL(for path: String) -> URL? {
        guard let loadedProject, !path.isEmpty, path != "-" else { return nil }
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return loadedProject.rootURL.appendingPathComponent(path).standardizedFileURL
    }

    private func localeStatus(locale: String, path: String) -> OpenGraphiteI18nResourceStatus {
        if let resource = i18nInspection?.resources.first(where: { $0.locale == locale }) {
            return resource
        }
        return OpenGraphiteI18nResourceStatus(
            locale: locale,
            path: path,
            exists: FileManager.default.fileExists(atPath: path),
            editable: true
        )
    }
}

/// 論理名（日本語）: Project資源概要パネル
/// 概要: Project Inspector 上部に選択中実装資源の種類と補助情報を表示します。
///
/// プロパティ:
/// - `resource`: 選択中の Project 資源。
private struct ProjectResourceSummaryPanel: View {
    var resource: OpenGraphiteProjectResourceSelection

    var body: some View {
        HStack(spacing: 10) {
            OpenGraphiteIconView(icon: icon, size: 17)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(resource.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(EditorColumnStyle.rowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }

    private var icon: OpenGraphiteIcon {
        switch resource {
        case .overview:
            return .projectPanel
        case .i18nRuntime:
            return .i18nResource
        case .localeResource:
            return .localeResource
        case .iconCDN:
            return .iconCDNResource
        case .htmlRoot, .cssLibrary, .runtime:
            return .dependencyResource
        }
    }
}

/// 論理名（日本語）: Page用i18n runtime概要セクション
/// 概要: Page Inspector で共有 i18n runtime の検出状態を read-only で表示し、Project 依存性へ移動します。
///
/// プロパティ:
/// - `inspection`: i18n runtime 検査結果。
/// - `onOpenProjectResource`: Project セグメントの i18n runtime へ移動する処理。
private struct I18nRuntimeSummarySection: View {
    var inspection: OpenGraphiteI18nRuntimeInspection?
    var onOpenProjectResource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            I18nRuntimeSummaryContent(inspection: inspection)

            Button(action: onOpenProjectResource) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.square")
                    Text("Open Project Dependency")
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

/// 論理名（日本語）: i18n runtime概要内容
/// 概要: Project / Page 双方で使う i18n runtime の read-only 検出情報を表示します。
///
/// プロパティ:
/// - `inspection`: i18n runtime 検査結果。
private struct I18nRuntimeSummaryContent: View {
    var inspection: OpenGraphiteI18nRuntimeInspection?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let inspection {
                InspectorInfoRow(label: "Adapter", value: adapterLabel(inspection.adapter))
                InspectorInfoRow(label: "Config Source", value: shortPath(inspection.configSource))
                InspectorInfoRow(label: "Load Path", value: propertyLabel(inspection.loadPath))
                InspectorInfoRow(label: "Fallback Locale", value: propertyLabel(inspection.fallbackLng))
                InspectorInfoRow(label: "Locale Field", value: inspection.localeField ?? "-")

                I18nResourceStatusList(resources: inspection.resources)
            } else {
                Text("Not detected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func adapterLabel(_ adapter: OpenGraphiteI18nAdapter) -> String {
        switch adapter {
        case .i18next:
            return "i18next"
        case .unknown:
            return "unknown"
        }
    }

    private func propertyLabel(_ property: OpenGraphiteI18nConfigProperty) -> String {
        switch property.source {
        case .literal:
            return "\(property.value ?? "-") · Project"
        case .external:
            return "\(property.expression ?? "External") · Read only"
        case .missing:
            return "-"
        }
    }

    private func shortPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "-" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

/// 論理名（日本語）: i18n runtime編集セクション
/// 概要: Project Inspector で literal な i18n runtime 設定を編集します。
///
/// プロパティ:
/// - `inspection`: i18n runtime 検査結果。
/// - `onRecommend`: 推奨 runtime / locale JSON を実装資源へ作成する処理。
/// - `onCommit`: literal 設定を実装資源へ保存する処理。
private struct I18nRuntimeEditorSection: View {
    var inspection: OpenGraphiteI18nRuntimeInspection?
    var onRecommend: () -> Void
    var onCommit: (_ loadPath: String?, _ fallbackLocale: String?) -> Void
    @State private var loadPathDraft = ""
    @State private var fallbackLocaleDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let inspection {
                InspectorInfoRow(label: "Adapter", value: adapterLabel(inspection.adapter))
                InspectorInfoRow(label: "Config Source", value: shortPath(inspection.configSource))
                InspectorInfoRow(label: "Locale Field", value: inspection.localeField ?? "-")

                I18nRuntimeLiteralField(
                    label: "Load Path",
                    value: $loadPathDraft,
                    placeholder: "/locales/{{lng}}.json",
                    isEditable: inspection.loadPath.source == .literal,
                    readOnlyValue: propertyLabel(inspection.loadPath),
                    isInvalid: loadPathDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onSubmit: commitIfValid
                )

                I18nRuntimeLiteralField(
                    label: "Fallback Locale",
                    value: $fallbackLocaleDraft,
                    placeholder: "ja",
                    isEditable: inspection.fallbackLng.source == .literal,
                    readOnlyValue: propertyLabel(inspection.fallbackLng),
                    isInvalid: fallbackLocaleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onSubmit: commitIfValid
                )

                I18nResourceStatusList(resources: inspection.resources)

                HStack(spacing: 8) {
                    Button(action: commitIfValid) {
                        Text("Apply")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .foregroundStyle(canCommit ? Color.white : Color.secondary)
                            .background(
                                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                                    .fill(canCommit ? Color.accentColor : EditorColumnStyle.elevatedRowFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCommit)

                    Button(action: onRecommend) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                            .frame(width: 32, height: 28)
                            .foregroundStyle(Color.accentColor)
                            .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                    }
                    .buttonStyle(.plain)
                    .help("Use recommended locale JSON")
                }
            } else {
                Text("Not detected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onRecommend) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Use recommended locale JSON")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(Color.accentColor)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: resetDrafts)
        .onChange(of: inspection) { _, _ in
            resetDrafts()
        }
    }

    private var canCommit: Bool {
        guard let inspection else { return false }
        let loadPath = loadPathDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLocale = fallbackLocaleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let canEditLoadPath = inspection.loadPath.source == .literal && !loadPath.isEmpty
        let canEditFallback = inspection.fallbackLng.source == .literal && !fallbackLocale.isEmpty
        let loadPathChanged = canEditLoadPath && loadPath != (inspection.loadPath.value ?? "")
        let fallbackChanged = canEditFallback && fallbackLocale != (inspection.fallbackLng.value ?? "")
        return loadPathChanged || fallbackChanged
    }

    private func commitIfValid() {
        guard let inspection, canCommit else { return }
        let loadPath = loadPathDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLocale = fallbackLocaleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        onCommit(
            inspection.loadPath.source == .literal && loadPath != (inspection.loadPath.value ?? "") ? loadPath : nil,
            inspection.fallbackLng.source == .literal && fallbackLocale != (inspection.fallbackLng.value ?? "") ? fallbackLocale : nil
        )
    }

    private func resetDrafts() {
        loadPathDraft = inspection?.loadPath.value ?? ""
        fallbackLocaleDraft = inspection?.fallbackLng.value ?? ""
    }

    private func adapterLabel(_ adapter: OpenGraphiteI18nAdapter) -> String {
        switch adapter {
        case .i18next:
            return "i18next"
        case .unknown:
            return "unknown"
        }
    }

    private func propertyLabel(_ property: OpenGraphiteI18nConfigProperty) -> String {
        switch property.source {
        case .literal:
            return property.value ?? "-"
        case .external:
            return property.expression ?? "External"
        case .missing:
            return "-"
        }
    }

    private func shortPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "-" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

/// 論理名（日本語）: i18n runtime literal入力欄
/// 概要: literal 設定は入力欄、external / missing 設定は read-only 表示として描画します。
///
/// プロパティ:
/// - `label`: 項目名。
/// - `value`: literal 編集値。
/// - `placeholder`: placeholder。
/// - `isEditable`: 入力可能か。
/// - `readOnlyValue`: read-only 時の表示値。
/// - `isInvalid`: invalid 表示を出すか。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct I18nRuntimeLiteralField: View {
    var label: String
    @Binding var value: String
    var placeholder: String
    var isEditable: Bool
    var readOnlyValue: String
    var isInvalid: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if isEditable {
                InspectorInputChrome(
                    icon: InspectorParameterIcon.attribute(label),
                    iconHelp: label,
                    strokeColor: isInvalid ? Color.red.opacity(0.65) : Color.clear
                ) {
                    TextField(placeholder, text: $value)
                        .textFieldStyle(.plain)
                        .font(.caption.monospaced())
                        .onSubmit(onSubmit)
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
            } else {
                Text(readOnlyValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: i18n resource状態一覧
/// 概要: locale JSON resource の存在有無と編集可否を表示します。
///
/// プロパティ:
/// - `resources`: locale JSON の状態一覧。
private struct I18nResourceStatusList: View {
    var resources: [OpenGraphiteI18nResourceStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resource Status")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            ForEach(resources, id: \.locale) { resource in
                HStack(spacing: 6) {
                    Text(resource.locale)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    Text(resource.exists ? "Found" : "Missing")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                    Spacer(minLength: 6)
                    Text(resource.editable ? "Editable" : "Read only")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            }
        }
    }
}

/// 論理名（日本語）: Locale resourceインスペクターセクション
/// 概要: Project 依存性で選択された locale JSON の状態を表示し、未作成時の作成導線を出します。
///
/// プロパティ:
/// - `locale`: locale 名。
/// - `path`: JSON resource path。
/// - `status`: resource 状態。
/// - `onCreate`: 推奨 locale JSON 作成処理。
private struct LocaleResourceInspectorSection: View {
    var locale: String
    var path: String
    var status: OpenGraphiteI18nResourceStatus
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            InspectorInfoRow(label: "Locale", value: locale)
            InspectorInfoRow(label: "Path", value: path)
            InspectorInfoRow(label: "Status", value: status.exists ? "Found" : "Missing")
            InspectorInfoRow(label: "Write", value: status.editable ? "Editable" : "Read only")
            InspectorInfoRow(label: "Keys", value: keyCountLabel)

            if !status.exists && status.editable {
                Button(action: onCreate) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Create Resource")
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(Color.accentColor)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var keyCountLabel: String {
        guard status.exists,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "-"
        }
        return "\(object.count)"
    }
}

/// 論理名（日本語）: ページ概要パネル
/// 概要: Inspector 上部に選択ページの識別子、HTML 相対パス、解像度を表示します。
///
/// プロパティ:
/// - `page`: 表示対象のページ。
private struct PageSummaryPanel: View {
    var page: OpenGraphitePage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.accentColor)
                .background(EditorColumnStyle.accentFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.id)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(page.path) · \(page.canvas.resolutionLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }
}

/// 論理名（日本語）: 任意キャンバス名フィールド
/// 概要: Page canvas のフロー解決用配置名を入力する任意テキスト欄です。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力文字列 binding。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct OptionalCanvasNameField: View {
    var label: String
    @Binding var text: String
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .lineLimit(1)
            }

            InspectorInputChrome(
                icon: InspectorParameterIcon.attribute(label),
                iconHelp: label
            ) {
                TextField("desktop", text: $text)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .onSubmit(onSubmit)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: HTML Langエディター
/// 概要: `<html lang>` の source mode、fallback、binding field を編集します。
///
/// プロパティ:
/// - `source`: `lang` の解決方式。
/// - `value`: `lang` 属性へ保存する literal / fallback 値。
/// - `field`: binding 時に参照する runtime field 名。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct HTMLLangDocumentEditor: View {
    @Binding var source: OpenGraphiteHTMLLangSource
    @Binding var value: String
    @Binding var field: String
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HTML Lang")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("HTML Lang Source", selection: $source) {
                ForEach(OpenGraphiteHTMLLangSource.allCases, id: \.self) { item in
                    Text(label(for: item)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            PreviewContextTextField(
                label: source == .binding ? "Fallback" : "Value",
                text: $value,
                placeholder: "ja",
                isInvalid: false,
                onSubmit: onSubmit
            )

            if source == .binding {
                PreviewContextTextField(
                    label: "Field",
                    text: $field,
                    placeholder: "selectedLanguage",
                    isInvalid: field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onSubmit: onSubmit
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for source: OpenGraphiteHTMLLangSource) -> String {
        switch source {
        case .literal:
            return "Literal"
        case .binding:
            return "Binding"
        }
    }
}

/// 論理名（日本語）: HTML Dirエディター
/// 概要: `<html dir>` の source mode、fallback、binding field を編集します。
///
/// プロパティ:
/// - `source`: `dir` の解決方式。
/// - `value`: `dir` 属性へ保存する literal / fallback 値。
/// - `field`: binding 時に参照する runtime field 名。
/// - `isInvalidValue`: fallback 値が HTML dir として不正か。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct HTMLDirDocumentEditor: View {
    @Binding var source: OpenGraphiteHTMLDirSource
    @Binding var value: String
    @Binding var field: String
    var isInvalidValue: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Dir")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("Text Dir Source", selection: $source) {
                ForEach(OpenGraphiteHTMLDirSource.allCases, id: \.self) { item in
                    Text(label(for: item)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            PreviewContextTextField(
                label: source == .literal ? "Value" : "Fallback",
                text: $value,
                placeholder: "ltr",
                isInvalid: isInvalidValue,
                onSubmit: onSubmit
            )

            if source == .binding {
                PreviewContextTextField(
                    label: "Field",
                    text: $field,
                    placeholder: "selectedDirection",
                    isInvalid: field.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onSubmit: onSubmit
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for source: OpenGraphiteHTMLDirSource) -> String {
        switch source {
        case .literal:
            return "Literal"
        case .auto:
            return "Auto"
        case .binding:
            return "Binding"
        }
    }
}

/// 論理名（日本語）: HTML Documentテキストフィールド
/// 概要: Page Inspector の HTML document context を編集する単一行入力欄です。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力文字列 binding。
/// - `placeholder`: 未入力時の表示例。
/// - `isInvalid`: 入力欄を invalid 表示にするか。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct PreviewContextTextField: View {
    var label: String
    @Binding var text: String
    var placeholder: String
    var isInvalid: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            InspectorInputChrome(
                icon: InspectorParameterIcon.attribute(label),
                iconHelp: label,
                strokeColor: isInvalid ? Color.red.opacity(0.65) : Color.clear
            ) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .onSubmit(onSubmit)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: Mock Stateエディター
/// 概要: 注入可能な JavaScript runtime mock state field ごとの override 行を編集します。
///
/// プロパティ:
/// - `entries`: 編集中の注入可能 field override 行。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct PreviewMockStateEditor: View {
    @Binding var entries: [PreviewMockFieldDraft]
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($entries) { $entry in
                PreviewMockStateRow(
                    entry: $entry,
                    onSubmit: onSubmit
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: Mock State行
/// 概要: 1 つの runtime parameter に対する override の ON/OFF と値を編集します。
///
/// プロパティ:
/// - `entry`: 編集中の override 行。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct PreviewMockStateRow: View {
    @Binding var entry: PreviewMockFieldDraft
    var onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: toggleOverride) {
                Image(systemName: entry.isOverrideEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 28)
                    .foregroundStyle(entry.isOverrideEnabled ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(entry.isOverrideEnabled ? "Override を無効化" : "Override を有効化")
            .padding(.bottom, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                InspectorInputChrome(
                    icon: InspectorParameterIcon.parameterValue,
                    iconHelp: entry.name,
                    strokeColor: entry.isOverrideEnabled ? Color.clear : EditorColumnStyle.separatorColor.opacity(0.7)
                ) {
                    TextField("value", text: $entry.value)
                        .textFieldStyle(.plain)
                        .font(.caption.monospaced())
                        .onSubmit(onSubmit)
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
                .opacity(entry.isOverrideEnabled ? 1 : 0.56)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(EditorColumnStyle.rowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(EditorColumnStyle.separatorColor.opacity(0.5), lineWidth: 1)
        )
    }

    /// 論理名（日本語）: Mock State override切替関数
    /// 処理概要: この parameter 行を preview へ注入するかどうかを切り替えます。
    private func toggleOverride() {
        entry.isOverrideEnabled.toggle()
    }
}

/// 論理名（日本語）: 必須キャンバス数値フィールド
/// 概要: ページキャンバス配置用の必須数値入力欄を表示します。
///
/// プロパティ:
/// - `label`: 入力欄ラベル。
/// - `text`: 入力文字列 binding。
/// - `isInvalid`: 入力欄を invalid 表示にするか。
/// - `showsRelationship`: 他入力欄と連動していることを示す枠線を表示するか。
/// - `onSubmit`: Enter 確定時に実行する処理。
private struct RequiredCanvasNumberField: View {
    var label: String
    @Binding var text: String
    var isInvalid: Bool
    var showsRelationship: Bool = false
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("required")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            InspectorInputChrome(
                icon: InspectorParameterIcon.canvasMetric(label),
                iconHelp: label,
                strokeColor: fieldStrokeColor
            ) {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .onSubmit(onSubmit)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fieldStrokeColor: Color {
        if isInvalid {
            return Color.red.opacity(0.65)
        }
        if showsRelationship {
            return Color.accentColor.opacity(0.54)
        }
        return Color.clear
    }
}

/// 論理名（日本語）: インスペクターセクション
/// 概要: Inspector 内の見出し付きパネルを共通化する汎用コンテナです。
///
/// プロパティ:
/// - `title`: セクション見出し。
/// - `content`: セクション内に表示する SwiftUI content。
private struct InspectorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EditorColumnStyle.rowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                    .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 論理名（日本語）: インスペクター空状態ビュー
/// 概要: ノード未選択時に右カラムの新しい軽量スタイルで選択案内を表示します。
private struct InspectorEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No Selection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Pages / Components のカードまたは Canvas でページかノードを選択してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 28)
        }
    }
}

/// 論理名（日本語）: インスペクター情報行
/// 概要: 編集不可のラベルと値を左右に並べて表示します。
///
/// プロパティ:
/// - `label`: 項目名。
/// - `value`: 表示値。
private struct InspectorInfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

/// 論理名（日本語）: 編集可能属性フィールド
/// 概要: `data-og-role` などの属性値をテキスト入力し、Enter またはフォーカスアウトで確定する入力行です。
///
/// プロパティ:
/// - `label`: 属性名。
/// - `value`: 現在値。
/// - `onCommit`: 適用時に呼び出す処理。
private struct EditableAttributeField: View {
    var label: String
    var value: String
    var onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: 編集可能属性フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、適用処理を保持します。
    ///
    /// - Parameters:
    ///   - label: 属性名。
    ///   - value: 現在値。
    ///   - onCommit: 適用時に呼び出す処理。
    init(label: String, value: String, onCommit: @escaping (String) -> Void) {
        self.label = label
        self.value = value
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 86, alignment: .leading)

            InspectorInputChrome(
                icon: InspectorParameterIcon.attribute(label),
                iconHelp: label
            ) {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .focused($isFocused)
                    .onSubmit(commitIfChanged)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
    }

    /// 論理名（日本語）: 編集可能属性変更時適用関数
    /// 処理概要: 入力値を trim し、変更がある場合だけ属性更新を反映します。
    private func commitIfChanged() {
        let nextValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = nextValue
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: レイアウトモードピッカー
/// 概要: `data-og-layout` を vertical、horizontal、absolute から選択するボタン群です。
///
/// プロパティ:
/// - `value`: 現在の layout 値。
/// - `onChange`: layout 選択時に呼び出す処理。
private struct LayoutModePicker: View {
    var value: String
    var onChange: (String) -> Void

    private let options = [
        ("vertical", "arrow.down"),
        ("horizontal", "arrow.right"),
        ("absolute", "scope")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option in
                Button {
                    onChange(option.0)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.1)
                        Text(option.0)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .fill(value == option.0 ? EditorColumnStyle.selectedRowFill : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .stroke(value == option.0 ? Color.accentColor.opacity(0.45) : EditorColumnStyle.separatorColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: インスペクターフィールドグリッド
/// 概要: CSS 変数入力欄を二列グリッドで配置する汎用コンテナです。
///
/// プロパティ:
/// - `content`: グリッド内に表示する SwiftUI content。
private struct InspectorFieldGrid<Content: View>: View {
    @ViewBuilder var content: Content

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity)
    }
}

/// 論理名（日本語）: CSS変数フィールド
/// 概要: `--og-*` のキーと値入力欄を表示し、Enter またはフォーカスアウトで確定します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在値。
/// - `onCommit`: 適用時に呼び出す処理。
private struct CSSVariableField: View {
    var key: String
    var value: String
    var onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: CSS変数フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、適用処理を保持します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在値。
    ///   - onCommit: 適用時に呼び出す処理。
    init(key: String, value: String, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(key)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 6) {
                InspectorInputChrome(
                    icon: InspectorParameterIcon.cssVariable(key),
                    iconHelp: key
                ) {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.caption.monospaced())
                        .focused($isFocused)
                        .onSubmit(commitIfChanged)
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: value) { _, newValue in
            draft = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
    }

    /// 論理名（日本語）: CSS変数変更時適用関数
    /// 処理概要: 入力値を trim し、変更がある場合だけ CSS 変数更新を反映します。
    private func commitIfChanged() {
        let nextValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = nextValue
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }
}

/// 論理名（日本語）: CSS色変数フィールド
/// 概要: `--og-background` などの色系 CSS 変数をスウォッチ、ColorPicker、CSS 文字列で編集します。
///
/// プロパティ:
/// - `key`: CSS 変数名。
/// - `value`: 現在値。
/// - `initialColor`: 現在値が CSS 色として解釈できないときの ColorPicker 初期色。
/// - `onCommit`: 色または CSS 文字列の適用時に呼び出す処理。
private struct CSSColorVariableField: View {
    var key: String
    var value: String
    var initialColor: Color
    var onCommit: (String) -> Void

    @State private var draft: String
    @State private var pickerColor: Color
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: CSS色変数フィールド初期化関数
    /// 処理概要: 現在値を draft state へコピーし、ColorPicker の初期色を決定します。
    ///
    /// - Parameters:
    ///   - key: CSS 変数名。
    ///   - value: 現在値。
    ///   - initialColor: CSS 色として解釈できない場合に使う初期色。
    ///   - onCommit: 適用時に呼び出す処理。
    init(key: String, value: String, initialColor: Color, onCommit: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.initialColor = initialColor
        self.onCommit = onCommit
        _draft = State(initialValue: value)
        _pickerColor = State(initialValue: CSSColorValue(cssString: value)?.color ?? initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()

                CSSColorSwatch(colorValue: parsedDraft)
            }

            if isEditable {
                HStack(spacing: 6) {
                    CSSColorPickerPreview(
                        text: $draft,
                        pickerColor: $pickerColor,
                        initialColor: initialColor,
                        onPick: commitPickedColor
                    )

                    InspectorInputChrome(
                        icon: InspectorParameterIcon.cssVariable(key),
                        iconHelp: key
                    ) {
                        TextField("", text: $draft)
                            .textFieldStyle(.plain)
                            .font(.caption.monospaced())
                            .focused($isFocused)
                            .onSubmit(commitDraftIfChanged)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
            } else {
                CSSUnsupportedValueNotice(value: value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: value) { _, newValue in
            draft = newValue
            pickerColor = CSSColorValue(cssString: newValue)?.color ?? initialColor
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitDraftIfChanged()
        }
    }

    private var parsedDraft: CSSColorValue? {
        CSSColorValue(cssString: draft)
    }

    private var isEditable: Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty || CSSColorValue(cssString: normalizedValue) != nil
    }

    /// 論理名（日本語）: 色選択変更時適用関数
    /// 処理概要: ColorPicker が生成した CSS 色文字列を変更がある場合だけ反映します。
    private func commitPickedColor(_ nextValue: String) {
        guard nextValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        onCommit(nextValue)
    }

    /// 論理名（日本語）: draft変更時適用関数
    /// 処理概要: テキスト入力中の CSS 色文字列を確定し、有効な値か未設定なら変更時だけ反映します。
    private func commitDraftIfChanged() {
        let normalizedValue = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty || CSSColorValue(cssString: normalizedValue) != nil else { return }
        draft = normalizedValue
        guard normalizedValue != value.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if let cssColor = CSSColorValue(cssString: normalizedValue) {
            pickerColor = cssColor.color
        }
        onCommit(normalizedValue)
    }
}

/// 論理名（日本語）: CSS色スウォッチ
/// 概要: CSS 色として解釈できる値を小さなプレビューとして表示します。
///
/// プロパティ:
/// - `colorValue`: 表示対象の CSS 色値。nil の場合は未解析状態を示します。
private struct CSSColorSwatch: View {
    var colorValue: CSSColorValue?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(EditorColumnStyle.elevatedRowFill)

            if let colorValue {
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorValue.color)
            } else {
                Image(systemName: "slash.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .help(colorValue?.cssHexString ?? "CSS色として解析できない値")
    }
}

/// 論理名（日本語）: インスペクターボタン選択肢
/// 概要: alignment や justify のアイコンボタンに使う選択肢モデルです。
///
/// プロパティ:
/// - `label`: tooltip 用の短いラベル。
/// - `icon`: 表示するアイコン。
/// - `value`: 適用する CSS 変数値。
private struct InspectorButtonOption: Identifiable {
    var label: String
    var icon: OpenGraphiteIcon
    var value: String

    var id: String { value }
}

/// 論理名（日本語）: インスペクターボタンストリップ
/// 概要: alignment や justify をアイコンボタン群として表示し、選択値を CSS 変数へ反映します。
///
/// プロパティ:
/// - `title`: 行タイトル。
/// - `value`: 現在選択値。
/// - `options`: 表示する選択肢。
/// - `onChange`: 選択時に呼び出す処理。
private struct InspectorButtonStrip: View {
    var title: String
    var value: String
    var options: [InspectorButtonOption]
    var onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(options) { option in
                    Button {
                        onChange(option.value)
                    } label: {
                        OpenGraphiteIconView(icon: option.icon, size: 13)
                            .frame(width: 28, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(value == option.value ? EditorColumnStyle.selectedRowFill : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(option.label)
                }
            }

            Spacer()
        }
    }
}
