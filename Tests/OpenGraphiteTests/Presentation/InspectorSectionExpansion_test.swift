import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクターセクション開放関連のテストスイート
/// 概要: Preview 側編集の CSS key、属性、object edit が該当 Inspector カードへ分類されることを確認します。
@Suite("インスペクターセクション開放関連のテストスイート")
struct InspectorSectionExpansionTests {
    /// 論理名（日本語）: Project migrationセクション識別子分離テスト
    /// 概要: Project概要とWeb contract migrationが別の開放対象として識別されることを検証します。
    @Test("Project概要とmigrationカードは別のsection IDを使う")
    func testProjectMigrationSectionIDIsIndependentFromProjectOverview() {
        // コンディション：Project Inspectorに並ぶ概要カードとmigrationカードのsection IDを用意する（Given）
        let projectOverview = InspectorSectionID.project
        let projectMigration = InspectorSectionID.projectMigration

        // 検証内容：両section IDを開放対象の集合へ追加する（When）
        let expansionTargets = Set([projectOverview, projectMigration])

        // 期待値：2つのカードは独立した安定IDとして保持され、開放要求が衝突しない（Then）
        #expect(expansionTargets.count == 2)
        #expect(projectMigration.rawValue == "projectMigration")
    }

    /// 論理名（日本語）: CSS宣言カード分類テスト
    /// 概要: 代表的な CSS property が対応する Inspector カードへ分類されることを検証します。
    @Test("CSS keyから該当Inspectorカードを解決できる")
    func testSectionsForCSSKeysResolveInspectorCards() {
        // コンディション：プレビュー操作で更新される代表的な CSS key を用意する（Given）
        let positionKeys = ["left", "top"]
        let typographyKey = "font-size"
        let layoutKeys = ["display", "flex-direction", "grid-template-columns", "grid-auto-flow"]
        let visibilityKey = "visibility"
        let overflowWrapKey = "overflow-wrap"
        let timelineKey = "animation-timeline"
        let scaleKey = "scale"

        // 検証内容：CSS key を Inspector section ID へ分類する（When）
        let positionSections = InspectorSectionID.sections(forCSSKeys: positionKeys)
        let typographySections = InspectorSectionID.sections(forCSSKey: typographyKey)
        let layoutSections = InspectorSectionID.sections(forCSSKeys: layoutKeys)
        let visibilitySections = InspectorSectionID.sections(forCSSKey: visibilityKey)
        let overflowWrapSections = InspectorSectionID.sections(forCSSKey: overflowWrapKey)
        let timelineSections = InspectorSectionID.sections(forCSSKey: timelineKey)
        let scaleSections = InspectorSectionID.sections(forCSSKey: scaleKey)

        // 期待値：それぞれ Position、Typography、Scroll Timeline カードに対応する（Then）
        #expect(positionSections == [.position])
        #expect(typographySections == [.typography])
        #expect(layoutSections == [.layout])
        #expect(visibilitySections == [.context, .layout])
        #expect(overflowWrapSections == [.typography])
        #expect(timelineSections == [.scrollTimeline])
        #expect(scaleSections == [.effects])
    }

    /// 論理名（日本語）: scale helper特殊分類解除テスト
    /// 概要: 廃止した軸別custom propertyをEffectsへ分類せず、標準`scale`だけを分類することを検証します。
    @Test("旧scale helperをEffects特殊分類にしない")
    func testLegacyScaleHelpersDoNotResolveEffectsCard() {
        // コンディション：旧軸別helperと標準scale propertyを用意する（Given）
        let legacyKeys = ["--og-scale-x", "--og-scale-y"]

        // 検証内容：各CSS keyをInspector section IDへ分類する（When）
        let legacySections = legacyKeys.map { InspectorSectionID.sections(forCSSKey: $0) }
        let standardSections = InspectorSectionID.sections(forCSSKey: "scale")

        // 期待値：旧helperは分類されず、標準scaleだけがEffectsへ対応する（Then）
        #expect(legacySections.allSatisfy { $0.isEmpty })
        #expect(standardSections == [.effects])
    }

    /// 論理名（日本語）: Theme予約custom property分類解除テスト
    /// 概要: 旧theme名をAppearance特殊分類から外し、標準propertyだけをAppearanceへ分類することを検証します。
    @Test("旧theme custom propertyをAppearance特殊分類にしない")
    func testLegacyThemeCustomPropertiesDoNotResolveAppearanceCard() {
        // コンディション：旧reserved theme名、project-defined token、標準appearance propertyを用意する（Given）
        let legacyThemeKeys = [
            "--og-page-background",
            "--og-text-color",
            "--og-muted-color",
            "--og-accent",
            "--og-accent-foreground"
        ]
        let projectToken = "--color-accent"

        // 検証内容：各CSS keyをInspector section IDへ分類する（When）
        let legacySections = legacyThemeKeys.map { InspectorSectionID.sections(forCSSKey: $0) }
        let projectTokenSections = InspectorSectionID.sections(forCSSKey: projectToken)
        let standardSections = InspectorSectionID.sections(forCSSKeys: ["background", "color"])

        // 期待値：custom property名へ意味を予約せず、標準background/colorだけがAppearanceに対応する（Then）
        #expect(legacySections.allSatisfy { $0.isEmpty })
        #expect(projectTokenSections.isEmpty)
        #expect(standardSections == [.appearance])
    }

    /// 論理名（日本語）: Locale font helper特殊分類解除テスト
    /// 概要: 廃止したlocale font custom propertyをInspectorのLocale Typographyへ暗黙分類しないことを検証します。
    @Test("旧locale font helperをLocale Typography特殊分類にしない")
    func testLegacyLocaleFontHelpersDoNotResolveLocaleTypographyCard() {
        // コンディション：default、固定locale、任意localeの旧font helper名を用意する（Given）
        let legacyKeys = [
            "--og-font-family-default",
            "--og-font-family-ja",
            "--og-font-family-eng",
            "--og-font-family-fr-CA"
        ]

        // 検証内容：各CSS keyをInspector section IDへ分類する（When）
        let legacySections = legacyKeys.map { InspectorSectionID.sections(forCSSKey: $0) }
        let standardSections = InspectorSectionID.sections(forCSSKey: "font-family")

        // 期待値：旧helperは特殊分類されず、標準font-familyだけがTypographyへ対応する（Then）
        #expect(legacySections.allSatisfy { $0.isEmpty })
        #expect(standardSections == [.typography])
    }

    /// 論理名（日本語）: Media/Icon標準property分類テスト
    /// 概要: 実描画elementの標準propertyだけをMedia/Iconへ分類し、旧helperとmask属性を特殊扱いしないことを検証します。
    @Test("Media/Iconは実体の標準CSS propertyから分類する")
    func testMediaIconStandardPropertiesResolveInspectorCards() {
        // コンディション：標準media/icon propertyと廃止済みhelper/属性を用意する（Given）
        let legacyKeys = ["--og-object-fit", "--og-stroke-width", "--og-icon-url"]
        let standardMediaKey = "object-fit"
        let standardIconKeys = ["stroke-width", "mask-image", "-webkit-mask-image"]

        // 検証内容：CSS keyと属性をInspector section IDへ分類する（When）
        let legacySections = legacyKeys.map { InspectorSectionID.sections(forCSSKey: $0) }
        let mediaSections = InspectorSectionID.sections(forCSSKey: standardMediaKey)
        let iconSections = InspectorSectionID.sections(forCSSKeys: standardIconKeys)
        let legacyAttributeSections = InspectorSectionID.sections(forAttributeName: "data-og-icon-mask")

        // 期待値：標準propertyだけが該当カードを開き、旧契約は分類されない（Then）
        #expect(legacySections.allSatisfy { $0.isEmpty })
        #expect(mediaSections == [.media])
        #expect(iconSections == [.icon])
        #expect(legacyAttributeSections.isEmpty)
    }

    /// 論理名（日本語）: 描画実体control形式判定テスト
    /// 概要: 専用controlで表せない標準CSS値をread-onlyにせずraw fieldへ送ることを検証します。
    @Test("Media/Iconの関数値と汎用単位はraw controlで編集する")
    func testRenderingTargetControlStylePreservesGeneralCSSValues() {
        // コンディション：専用control対応keyword/数値とcustom property、関数、汎用単位を用意する（Given）
        let simpleObjectFit = "cover"
        let variableObjectFit = "var(--media-fit)"
        let simpleStrokeWidth = "2.5px"
        let generalStrokeWidths = ["var(--icon-stroke)", "calc(1px + 0.1em)", "10%", "0.25em"]

        // 検証内容：描画実体control形式を判定する（When）
        let objectFitUsesGlyph = RenderTargetInspectorControlStyle.supportsObjectFitGlyph(simpleObjectFit)
        let variableObjectFitUsesGlyph = RenderTargetInspectorControlStyle.supportsObjectFitGlyph(variableObjectFit)
        let simpleStrokeUsesNumeric = RenderTargetInspectorControlStyle.supportsStrokeWidthNumeric(simpleStrokeWidth)
        let generalStrokeUsesNumeric = generalStrokeWidths.map(
            RenderTargetInspectorControlStyle.supportsStrokeWidthNumeric
        )

        // 期待値：単純値だけ専用controlを使い、一般CSS値は元文字列を編集できるraw controlへ送る（Then）
        #expect(objectFitUsesGlyph)
        #expect(!variableObjectFitUsesGlyph)
        #expect(simpleStrokeUsesNumeric)
        #expect(generalStrokeUsesNumeric.allSatisfy { !$0 })
    }

    /// 論理名（日本語）: 属性カード分類テスト
    /// 概要: 標準hidden／roleと維持対象`data-og-*`属性が対応するInspectorカードへ分類されることを検証します。
    @Test("属性名から該当Inspectorカードを解決できる")
    func testSectionsForAttributeNamesResolveInspectorCards() {
        // コンディション：Preview の context menu などから変更される属性名を用意する（Given）
        let hiddenAttribute = "hidden"
        let legacyLayoutAttribute = "data-og-layout"
        let iconAttribute = "data-og-icon-name"
        let roleAttribute = "role"

        // 検証内容：属性名を Inspector section ID へ分類する（When）
        let hiddenSections = InspectorSectionID.sections(forAttributeName: hiddenAttribute)
        let legacyLayoutSections = InspectorSectionID.sections(forAttributeName: legacyLayoutAttribute)
        let iconSections = InspectorSectionID.sections(forAttributeName: iconAttribute)
        let roleSections = InspectorSectionID.sections(forAttributeName: roleAttribute)

        // 期待値：標準hiddenだけがContextへ対応し、legacy layoutは特殊分類されない（Then）
        #expect(hiddenSections == [.context])
        #expect(legacyLayoutSections.isEmpty)
        #expect(iconSections == [.icon])
        #expect(roleSections == [.context])
    }

    /// 論理名（日本語）: HTML編集操作カード分類テスト
    /// 概要: Web preview bridge の object edit が対応する Inspector カードへ分類されることを検証します。
    @Test("HTML object editから該当Inspectorカードを解決できる")
    func testSectionsForHTMLObjectEditOperationResolveInspectorCards() {
        // コンディション：テキスト編集、ドラッグ移動、layout 変更、表示 ID 変更の object edit を用意する（Given）
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
        let layoutOperation = HTMLObjectEditOperation.setCSSVariables(
            nodeInternalID: "frame-node",
            values: ["display": "flex", "flex-direction": "row"],
            expectedOldValues: ["display": "block", "flex-direction": ""]
        )
        let renameOperation = HTMLObjectEditOperation.renameNodeID(
            nodeInternalID: "frame-node",
            value: "hero-card",
            expectedOldValue: "hero"
        )
        let mediaOperation = HTMLObjectEditOperation.setCSSVariable(
            nodeInternalID: "media-node",
            key: "object-fit",
            value: "cover",
            expectedOldValue: "contain"
        )
        let iconOperation = HTMLObjectEditOperation.setCSSVariables(
            nodeInternalID: "icon-node",
            values: ["stroke-width": "2", "mask-image": "url('icon.svg')"],
            expectedOldValues: ["stroke-width": "1", "mask-image": ""]
        )

        // 検証内容：object edit を Inspector section ID へ分類する（When）
        let textSections = InspectorSectionID.sections(for: textOperation)
        let dragSections = InspectorSectionID.sections(for: dragOperation)
        let layoutSections = InspectorSectionID.sections(for: layoutOperation)
        let renameSections = InspectorSectionID.sections(for: renameOperation)
        let mediaSections = InspectorSectionID.sections(for: mediaOperation)
        let iconSections = InspectorSectionID.sections(for: iconOperation)

        // 期待値：Text、Position、Layout、Context カードに対応する（Then）
        #expect(textSections == [.text])
        #expect(dragSections == [.position])
        #expect(layoutSections == [.layout])
        #expect(renameSections == [.context])
        #expect(mediaSections == [.media])
        #expect(iconSections == [.icon])
        #expect(mediaOperation.requiresWebViewReload)
        #expect(iconOperation.requiresWebViewReload)
    }
}
