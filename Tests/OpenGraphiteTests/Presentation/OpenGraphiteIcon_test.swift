import Testing
@testable import OpenGraphite

/// 論理名（日本語）: OpenGraphiteアイコン関連のテストスイート
/// 概要: Lucide と SF Symbols を同じアイコン記述子で扱うための基本契約を確認します。
@Suite("OpenGraphiteアイコン関連のテストスイート")
struct OpenGraphiteIconTests {
    /// 論理名（日本語）: 選択可能アイコンライブラリテスト
    /// 概要: Asset Panel から Lucide と SF Symbols を選択できるライブラリ一覧であることを検証します。
    @Test("LucideとSF Symbolsを選択可能にする")
    func testSelectableLibrariesIncludeLucideAndSystemSymbols() {
        // コンディション：アイコンライブラリの選択肢を取得する（Given）
        let libraries = OpenGraphiteIconLibrary.selectableLibraries

        // 検証内容：選択肢の表示名と既定値を確認する（When）
        let titles = libraries.map(\.title)

        // 期待値：Lucide と SF Symbols が選べ、既定値は Lucide になる（Then）
        #expect(libraries == [.lucide, .systemSymbols])
        #expect(titles == ["Lucide", "SF Symbols"])
        #expect(OpenGraphiteIconLibrary.defaultLibrary == .lucide)
    }

    /// 論理名（日本語）: SF Symbolsアイコン記述子テスト
    /// 概要: SF Symbols 名が共通アイコン記述子として保持されることを検証します。
    @Test("SF Symbolsアイコン記述子を作れる")
    func testSystemIconDescriptorUsesSystemSymbolsLibrary() {
        // コンディション：SF Symbols 名からアイコン記述子を作成する（Given）
        let icon = OpenGraphiteIcon.system("folder")

        // 検証内容：供給元と fallback を確認する（When）
        let library = icon.library

        // 期待値：供給元と fallback の両方が SF Symbols 名を指す（Then）
        #expect(library == .systemSymbols)
        #expect(icon.name == "folder")
        #expect(icon.fallbackSystemName == "folder")
    }

    /// 論理名（日本語）: Lucideアイコン記述子テスト
    /// 概要: Lucide の icon ID と SF Symbols fallback が同じ記述子に保持されることを検証します。
    @Test("Lucideアイコン記述子にSF Symbols fallbackを持てる")
    func testLucideIconDescriptorKeepsFallbackSystemSymbol() {
        // コンディション：Lucide ID と SF Symbols fallback からアイコン記述子を作成する（Given）
        let icon = OpenGraphiteIcon.lucide("package", fallbackSystemName: "shippingbox")

        // 検証内容：供給元と fallback を確認する（When）
        let library = icon.library

        // 期待値：Lucide を優先しつつ SF Symbols fallback を保持する（Then）
        #expect(library == .lucide)
        #expect(icon.name == "package")
        #expect(icon.fallbackSystemName == "shippingbox")
    }

    /// 論理名（日本語）: キャンバスアイコンツール割り当てテスト
    /// 概要: アイコン配置ツールが Lucide の star icon で表示されることを検証します。
    @Test("キャンバスアイコンツールをLucideアイコンで表示する")
    func testCanvasIconToolUsesLucideIcon() {
        // コンディション：キャンバスツール一覧と icon ツールの表示 icon を取得する（Given）
        let tools = CanvasTool.allCases
        let icon = OpenGraphiteIcon.canvasTool(.icon)

        // 検証内容：ツール一覧と Lucide ID を確認する（When）
        let toolIDs = tools.map(\.rawValue)

        // 期待値：icon ツールが選択肢にあり、Lucide の star で表示される（Then）
        #expect(toolIDs == ["select", "rectangle", "text", "frame", "icon", "hand"])
        #expect(icon.library == .lucide)
        #expect(icon.name == "star")
    }

    /// 論理名（日本語）: パラメータ連動アイコン割り当てテスト
    /// 概要: Inspector の連動切替がリンク/解除のアイコンで表現されることを検証します。
    @Test("連動切替アイコンをリンクと解除にする")
    func testParameterLinkIconsUseLinkMetaphor() {
        // コンディション：連動切替用のアイコン記述子を取得する（Given）
        let linkIcon = OpenGraphiteIcon.parameterLink
        let unlinkIcon = OpenGraphiteIcon.parameterUnlink

        // 検証内容：Lucide ID と fallback を確認する（When）
        let iconNames = [linkIcon.name, unlinkIcon.name]
        let fallbackNames = [linkIcon.fallbackSystemName, unlinkIcon.fallbackSystemName]

        // 期待値：リンク状態と解除状態がそれぞれ明示的なアイコンを持つ（Then）
        #expect(iconNames == ["link", "unlink"])
        #expect(fallbackNames == ["link", "link.slash"])
    }

    /// 論理名（日本語）: 左カラムアイコン割り当てテスト
    /// 概要: Layers と HTML カードのアイコンが OpenGraphite の source-of-truth 思想に沿うことを検証します。
    @Test("左カラムのアイコンを実装とデザインの工程に沿わせる")
    func testLeftColumnIconsFollowSourceOfTruthMeaning() {
        // コンディション：左カラムで使う代表的なアイコン記述子を取得する（Given）
        let frameIcon = OpenGraphiteIcon.layerType("frame")
        let pageIcon = OpenGraphiteIcon.pageDocument
        let componentIcon = OpenGraphiteIcon.componentDocument
        let collectionIcon = OpenGraphiteIcon.collectionGroup

        // 検証内容：Lucide ID の割り当てを確認する（When）
        let iconNames = [
            frameIcon.name,
            pageIcon.name,
            componentIcon.name,
            collectionIcon.name
        ]

        // 期待値：frame は code、HTML page は file-code、component 系は component / blocks になる（Then）
        #expect(iconNames == ["code", "file-code", "component", "blocks"])
        #expect(frameIcon.fallbackSystemName == "chevron.left.forwardslash.chevron.right")
    }

    /// 論理名（日本語）: iconレイヤーアイコン割り当てテスト
    /// 概要: HTML の icon primitive が Lucide の star で表示されることを検証します。
    @Test("icon primitiveをレイヤー上でアイコン表示する")
    func testLayerTypeIconUsesStar() {
        // コンディション：icon primitive のレイヤーアイコンを取得する（Given）
        let icon = OpenGraphiteIcon.layerType("icon")

        // 検証内容：Lucide ID を確認する（When）
        let iconName = icon.name

        // 期待値：icon primitive は star で表現される（Then）
        #expect(icon.library == .lucide)
        #expect(iconName == "star")
        #expect(icon.fallbackSystemName == "star")
    }

    /// 論理名（日本語）: componentとinstanceのレイヤーアイコン判定テスト
    /// 概要: component master と component instance が Lucide の専用アイコンを優先することを検証します。
    @Test("componentとinstanceは専用アイコンを優先する")
    func testLayerNodeUsesComponentAndInstanceIcons() {
        // コンディション：component master、instance本体、runtime生成root、runtime生成子要素、preview placementを用意する（Given）
        let masterNode = OpenGraphiteNode(
            id: "feature-card-master",
            tagName: "featurecard",
            type: "frame",
            layout: nil,
            role: nil,
            componentID: "feature-card",
            componentKind: "master",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let instanceNode = OpenGraphiteNode(
            id: "home-card",
            tagName: "og-instance",
            type: "frame",
            layout: nil,
            role: nil,
            componentID: "feature-card",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let generatedRootNode = OpenGraphiteNode(
            id: "home-card",
            tagName: "featurecard",
            type: "frame",
            layout: nil,
            role: nil,
            sourceComponentID: "feature-card",
            sourceInstanceID: "home-card",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let generatedChildNode = OpenGraphiteNode(
            id: "home-card-title",
            tagName: "featuretitle",
            type: "text",
            layout: nil,
            role: nil,
            sourceComponentID: "feature-card",
            sourceInstanceID: "home-card",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let placementNode = OpenGraphiteNode(
            id: "placement-code-viewer-preview",
            tagName: "og-placement",
            type: "frame",
            layout: nil,
            role: "component-placement",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )

        // 検証内容：レイヤー行用アイコン名を取得する（When）
        let iconNames = [
            OpenGraphiteIcon.layerNode(masterNode).name,
            OpenGraphiteIcon.layerNode(instanceNode).name,
            OpenGraphiteIcon.layerNode(generatedRootNode).name,
            OpenGraphiteIcon.layerNode(generatedChildNode).name,
            OpenGraphiteIcon.layerNode(placementNode).name
        ]

        // 期待値：master は component、instance root は replace、placement は copy、子要素は本来の text アイコンになる（Then）
        #expect(iconNames == ["component", "replace", "replace", "type", "copy"])
    }
}
