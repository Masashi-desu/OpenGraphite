import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクターセクション開放関連のテストスイート
/// 概要: Preview 側編集の CSS key、属性、object edit が該当 Inspector カードへ分類されることを確認します。
@Suite("インスペクターセクション開放関連のテストスイート")
struct InspectorSectionExpansionTests {
    /// 論理名（日本語）: CSS宣言カード分類テスト
    /// 概要: 代表的な CSS property が対応する Inspector カードへ分類されることを検証します。
    @Test("CSS keyから該当Inspectorカードを解決できる")
    func testSectionsForCSSKeysResolveInspectorCards() {
        // コンディション：プレビュー操作で更新される代表的な CSS key を用意する（Given）
        let positionKeys = ["left", "top"]
        let typographyKey = "font-size"
        let timelineKey = "animation-timeline"

        // 検証内容：CSS key を Inspector section ID へ分類する（When）
        let positionSections = InspectorSectionID.sections(forCSSKeys: positionKeys)
        let typographySections = InspectorSectionID.sections(forCSSKey: typographyKey)
        let timelineSections = InspectorSectionID.sections(forCSSKey: timelineKey)

        // 期待値：それぞれ Position、Typography、Scroll Timeline カードに対応する（Then）
        #expect(positionSections == [.position])
        #expect(typographySections == [.typography])
        #expect(timelineSections == [.scrollTimeline])
    }

    /// 論理名（日本語）: 属性カード分類テスト
    /// 概要: `data-og-*` 属性が対応する Inspector カードへ分類されることを検証します。
    @Test("属性名から該当Inspectorカードを解決できる")
    func testSectionsForAttributeNamesResolveInspectorCards() {
        // コンディション：Preview の context menu などから変更される属性名を用意する（Given）
        let layoutAttribute = "data-og-layout"
        let iconAttribute = "data-og-icon-name"
        let roleAttribute = "data-og-role"

        // 検証内容：属性名を Inspector section ID へ分類する（When）
        let layoutSections = InspectorSectionID.sections(forAttributeName: layoutAttribute)
        let iconSections = InspectorSectionID.sections(forAttributeName: iconAttribute)
        let roleSections = InspectorSectionID.sections(forAttributeName: roleAttribute)

        // 期待値：Layout、Icon、Context カードに対応する（Then）
        #expect(layoutSections == [.layout])
        #expect(iconSections == [.icon])
        #expect(roleSections == [.context])
    }

    /// 論理名（日本語）: HTML編集操作カード分類テスト
    /// 概要: Web preview bridge の object edit が対応する Inspector カードへ分類されることを検証します。
    @Test("HTML object editから該当Inspectorカードを解決できる")
    func testSectionsForHTMLObjectEditOperationResolveInspectorCards() {
        // コンディション：テキスト編集、ドラッグ移動、layout 変更の object edit を用意する（Given）
        let textOperation = HTMLObjectEditOperation.setTextContent(
            nodeInternalID: "title-node",
            text: "Updated",
            expectedOldValue: "Old"
        )
        let dragOperation = HTMLObjectEditOperation.setCSSVariables(
            nodeInternalID: "card-node",
            values: ["left": "24px", "top": "48px"],
            expectedOldValues: ["left": "", "top": ""]
        )
        let layoutOperation = HTMLObjectEditOperation.setAttribute(
            nodeInternalID: "frame-node",
            name: "data-og-layout",
            value: "horizontal",
            expectedOldValue: "vertical"
        )

        // 検証内容：object edit を Inspector section ID へ分類する（When）
        let textSections = InspectorSectionID.sections(for: textOperation)
        let dragSections = InspectorSectionID.sections(for: dragOperation)
        let layoutSections = InspectorSectionID.sections(for: layoutOperation)

        // 期待値：Text、Position、Layout カードに対応する（Then）
        #expect(textSections == [.text])
        #expect(dragSections == [.position])
        #expect(layoutSections == [.layout])
    }
}
