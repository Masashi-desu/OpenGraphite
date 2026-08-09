import Testing
@testable import OpenGraphite

/// 論理名（日本語）: OpenGraphiteノード関連のテストスイート
/// 概要: HTML DOM から抽出された編集ノードの表示用メタ情報を確認します。
@Suite("OpenGraphiteノード関連のテストスイート")
struct OpenGraphiteNodeTests {
    /// 論理名（日本語）: 標準HTMLノード表示テスト
    /// 概要: OpenGraphite annotationとtypeを持たないnodeも標準idとtag semanticsで表示できることを確認します。
    @Test("未注釈の標準HTMLノードをsession referenceで表示できる")
    func testUnannotatedStandardHTMLNodePresentation() {
        // コンディション：標準idとnon-invasive locatorだけを持つ未注釈article nodeを用意する（Given）
        let node = OpenGraphiteNode(
            id: "ogref-session:node:document:article:hash",
            standardID: "article",
            reference: "ogref-session:node:document:article:hash",
            annotationStatus: OpenGraphiteNodeAnnotationStatus.none,
            referenceStability: .session,
            locator: OpenGraphiteNodeSourceLocator(
                documentURL: "file:///project/public/index.html",
                selector: "#article",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > article:nth-of-type(1)",
                sourceStart: 42,
                sourceEnd: 84,
                contentHash: "abc123"
            ),
            tagName: "article",
            type: "",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：LayersとInspector向けの表示情報と編集安定性を取得する（When）
        let displayID = node.displayID
        let detailLine = node.detailLine
        let hasStableReference = node.hasStableReference

        // 期待値：標準idとarticle semanticsを表示し、明示adoption前はsession-onlyとして扱う（Then）
        #expect(displayID == "article")
        #expect(detailLine == "article")
        #expect(hasStableReference == false)
    }

    /// 論理名（日本語）: Source-backed adoption可否テスト
    /// 概要: authored source rangeを持つ未注釈nodeだけがadoption可能で、browser生成nodeと完全注釈nodeはinspection-onlyになることを確認します。
    @Test("adoptionはsource-backedな未完了annotation nodeだけに許可する")
    func testAdoptionRequiresSourceBackedIncompleteNode() {
        // コンディション：Shared source range、browser-only range、完全annotationを持つ3 nodeを用意する（Given）
        let sourceLocator = OpenGraphiteNodeSourceLocator(
            documentURL: "file:///project/public/index.html",
            selector: "#article",
            domPath: "html:nth-of-type(1) > body:nth-of-type(1) > article:nth-of-type(1)",
            sourceStart: 42,
            sourceEnd: 84,
            contentHash: "source-hash"
        )
        let browserLocator = OpenGraphiteNodeSourceLocator(
            documentURL: "file:///project/public/index.html",
            selector: nil,
            domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(1)",
            sourceStart: -1,
            sourceEnd: -1,
            contentHash: "browser-hash"
        )
        let sourceNode = OpenGraphiteNode(
            id: "source-node",
            reference: "ogref-session:node:source",
            annotationStatus: OpenGraphiteNodeAnnotationStatus.none,
            referenceStability: .session,
            locator: sourceLocator,
            tagName: "article",
            type: "",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let browserNode = OpenGraphiteNode(
            id: "browser-tbody",
            reference: "ogref-session:node:browser",
            annotationStatus: OpenGraphiteNodeAnnotationStatus.none,
            referenceStability: .session,
            locator: browserLocator,
            tagName: "tbody",
            type: "",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let completeNode = OpenGraphiteNode(
            id: "complete",
            internalID: "complete-node",
            reference: "ogref:node:chapter:page:complete-node",
            annotationStatus: .complete,
            referenceStability: .stable,
            locator: sourceLocator,
            tagName: "article",
            type: "",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：各nodeのadoption affordance判定を取得する（When）
        let eligibility = [
            sourceNode.canAdoptIdentity,
            browserNode.canAdoptIdentity,
            completeNode.canAdoptIdentity
        ]

        // 期待値：authored sourceへ解決済みの未注釈nodeだけが明示adoption可能である（Then）
        #expect(sourceLocator.isSourceBacked)
        #expect(!browserLocator.isSourceBacked)
        #expect(eligibility == [true, false, false])
    }

    /// 論理名（日本語）: ノード詳細行の基本表示テスト
    /// 概要: 標準tag、レイアウト、ロールが順番通りに表示されることを検証します。
    @Test("ノード詳細行を構成できる")
    func testDetailLineWithLayoutAndRole() {
        // コンディション：layout と role を持つ標準HTMLノードを用意する（Given）
        let node = OpenGraphiteNode(
            id: "hero",
            tagName: "herosection",
            type: "frame",
            layout: "vertical",
            role: "component-placement",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：詳細行を取得する（When）
        let detailLine = node.detailLine

        // 期待値：tag、layout、role が区切り文字付きで並ぶ（Then）
        #expect(detailLine == "herosection · vertical · component-placement")
    }

    /// 論理名（日本語）: ノード状態表示テスト
    /// 概要: hidden と locked の状態が詳細行へ含まれることを検証します。
    @Test("ノード状態を詳細行へ含める")
    func testDetailLineIncludesHiddenAndLockedState() {
        // コンディション：非表示かつロックされたテキストノードを用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: true,
            isLocked: true,
            depth: 1
        )

        // 検証内容：詳細行を取得する（When）
        let detailLine = node.detailLine

        // 期待値：tag に続いて hidden と locked が表示される（Then）
        #expect(detailLine == "maintitle · hidden · locked")
    }

    /// 論理名（日本語）: Authored/computed style分離テスト
    /// 概要: source declaration、responsive WebKit computed state、標準hidden intentを別々に保持してLayers表示を導出できることを確認します。
    @Test("authored CSSとcomputed layoutとhidden intentを分離できる")
    func testAuthoredAndComputedStyleStateRemainSeparated() {
        // コンディション：authored block値に対してresponsive flexがcomputedされ、標準hidden属性はないがCSSで非表示のnodeを用意する（Given）
        let computedStyle = OpenGraphiteNodeComputedStyle(
            display: "flex",
            flexDirection: "row-reverse",
            gridTemplateColumns: "none",
            gridTemplateRows: "none",
            gridAutoFlow: "row",
            position: "absolute",
            visibility: "hidden",
            contentVisibility: "hidden",
            overflowWrap: "anywhere",
            alignItems: "center",
            justifyContent: "space-between"
        )
        let node = OpenGraphiteNode(
            id: "responsive-card",
            tagName: "article",
            type: "",
            layout: computedStyle.layoutMode,
            role: nil,
            cssVariables: ["display": "block", "visibility": "visible"],
            computedStyle: computedStyle,
            isHidden: true,
            hasHiddenAttribute: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：Layers分類、source値、computed値、hidden source intentを取得する（When）
        let detailLine = node.detailLine
        let authoredDisplay = node.cssVariables["display"]
        let computedDisplay = node.computedStyle.display

        // 期待値：layoutはcomputed flex方向、Inspector入力はauthored値、hidden表示と属性intentは独立する（Then）
        #expect(node.layout == "horizontal")
        #expect(detailLine == "article · horizontal · absolute · hidden")
        #expect(authoredDisplay == "block")
        #expect(computedDisplay == "flex")
        #expect(node.computedStyle.position == "absolute")
        #expect(node.computedStyle.contentVisibility == "hidden")
        #expect(node.computedStyle.overflowWrap == "anywhere")
        #expect(node.computedStyle.supportsAlignment)
        #expect(node.isHidden)
        #expect(node.hasHiddenAttribute == false)
    }

    /// 論理名（日本語）: コンポーネント継承元ID判定テスト
    /// 概要: instance 本体と runtime 展開済みノードから継承元 component ID を取得できることを検証します。
    @Test("instance由来のcomponent IDを判定できる")
    func testInheritedComponentIDUsesInstanceAndRuntimeAttributes() {
        // コンディション：instance 本体、runtime 展開ノード、master 本体を用意する
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
        let generatedNode = OpenGraphiteNode(
            id: "home-card-title",
            tagName: "featurecardtitle",
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
        let masterNode = OpenGraphiteNode(
            id: "feature-card-master",
            tagName: "featurecard",
            type: "frame",
            layout: nil,
            role: nil,
            componentID: "feature-card",
            isComponentMaster: true,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：それぞれの継承元 component ID を取得する
        let instanceComponentID = instanceNode.inheritedComponentID
        let generatedComponentID = generatedNode.inheritedComponentID
        let masterComponentID = masterNode.inheritedComponentID

        // 期待値：instance と生成ノードだけが component ID を返す
        #expect(instanceComponentID == "feature-card")
        #expect(generatedComponentID == "feature-card")
        #expect(masterComponentID == nil)
    }

    /// 論理名（日本語）: テキストbinding表示メタデータテスト
    /// 概要: text source と i18n key から binding node と表示ラベルを判定できることを確認します。
    @Test("text binding metadataを表示用に判定できる")
    func testTextBindingMetadataDisplay() {
        // コンディション：binding metadata を持つテキストノードを用意する
        let node = OpenGraphiteNode(
            id: "hero-lead",
            tagName: "leadtext",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "表示中の本文",
            fallbackTextContent: "fallback本文",
            textSource: "binding",
            i18nKey: "home.hero.lead",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )

        // 検証内容：Inspector 表示用の binding 判定を取得する
        let isBinding = node.isTextBinding
        let sourceLabel = node.textSourceLabel

        // 期待値：binding node として扱われ、source label は metadata の値を表示する
        #expect(isBinding == true)
        #expect(sourceLabel == "binding")
    }

    /// 論理名（日本語）: 解決済みフォント保持テスト
    /// 概要: preview DOM の computed style から得た font-family をノードに保持できることを確認します。
    @Test("resolved font-familyを保持できる")
    func testResolvedFontFamily() {
        // コンディション：inline font-family は未設定だが、computed style でフォントが解決済みのノードを用意する
        var node = OpenGraphiteNode(
            id: "hero-lead",
            tagName: "leadtext",
            type: "text",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        node.resolvedFontFamily = "\"Noto Sans JP\", Inter, sans-serif"

        // 検証内容：解決済み font-family を取得する
        let resolvedFontFamily = node.resolvedFontFamily

        // 期待値：computed style 由来の font-family が保持される
        #expect(resolvedFontFamily == "\"Noto Sans JP\", Inter, sans-serif")
    }

    /// 論理名（日本語）: 描画実体cascade表示モデルテスト
    /// 概要: wrapper nodeが実体selector、computed値、`!important`/specificity winnerを保持し、保存後cacheを同期できることを検証します。
    @Test("描画実体のcascade winnerと表示値を保持できる")
    func testRenderingTargetCascadePresentation() throws {
        // コンディション：詳細度と!importantが異なるobject-fit候補を持つmedia targetを用意する（Given）
        let target = OpenGraphiteRenderTarget(
            kind: "media",
            property: "object-fit",
            targetTagName: "img",
            relation: "direct-child",
            writeSelector: "#hero-image",
            targetInternalID: "",
            authoredValue: "cover",
            resolvedValue: "cover",
            computedValue: "cover",
            relationSelector: ":scope > img",
            sourceTrace: [
                OpenGraphiteRenderTargetSourceTrace(
                    authoredProperty: "object-fit",
                    selector: "MediaFrame > img",
                    atRuleScope: [],
                    value: "contain",
                    important: false,
                    specificityIDs: 0,
                    specificityClasses: 0,
                    specificityTypes: 2,
                    sourceOrder: 1
                ),
                OpenGraphiteRenderTargetSourceTrace(
                    authoredProperty: "object-fit",
                    selector: "#hero-image",
                    atRuleScope: [],
                    value: "cover",
                    important: true,
                    specificityIDs: 1,
                    specificityClasses: 0,
                    specificityTypes: 0,
                    sourceOrder: 2
                )
            ]
        )
        var node = OpenGraphiteNode(
            id: "media",
            tagName: "mediaframe",
            type: "image",
            layout: nil,
            role: nil,
            cssVariables: [:],
            renderTargets: [target],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：property target/winnerを取得し、保存後valueへcacheを更新する（When）
        let initial = try #require(node.renderTarget(for: "object-fit"))
        node.updateRenderTargetValue(property: "object-fit", value: "scale-down")
        let updated = try #require(node.renderTarget(for: "object-fit"))

        // 期待値：保存selectorと!important winnerを表示し、標準property値だけを同期する（Then）
        #expect(initial.targetLabel == "#hero-image")
        #expect(initial.displayValue == "cover")
        #expect(initial.winnerTrace?.selector == "#hero-image")
        #expect(updated.authoredValue == "scale-down")
        #expect(updated.computedValue == "scale-down")
    }

    /// 論理名（日本語）: Operation capability集合テスト
    /// 概要: 1つの標準HTML nodeが複数operation capabilityを同時に保持し、legacy typeが認可を上書きしないことを確認します。
    @Test("nodeは単一typeでなく複数operation capabilityを保持する")
    func testNodeKeepsIndependentOperationCapabilities() {
        // コンディション：link、text、layoutの根拠と競合するlegacy image hintを持つanchor nodeを用意する（Given）
        let evidence = OpenGraphiteNodeCapabilityEvidence(
            isProjectResourceRoot: false,
            isNativeControl: false,
            isCustomElement: false,
            isLink: true,
            hasDirectText: true,
            hasElementChildren: false,
            hasMediaContent: false,
            hasSVGContent: false,
            hasMaskContent: false,
            ariaRole: nil,
            resolvedDisplay: "inline"
        )
        let node = OpenGraphiteNode(
            id: "documentation-link",
            tagName: "a",
            legacyTypeHint: "image",
            capabilities: [.editLayout, .editLink, .editText, .reorderFlow],
            capabilityEvidence: evidence,
            attributes: ["href": ""],
            layout: "inline",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )

        // 検証内容：各operationの認可とLayers表示hintを取得する（When）
        let supported = OpenGraphiteNodeCapability.allCases.filter(node.supports)
        let presentationHint = node.presentationHint

        // 期待値：根拠のある複数operationだけが有効で、legacy image hintは表示分類も上書きしない（Then）
        #expect(Set(supported) == [.editLayout, .editLink, .editText, .reorderFlow])
        #expect(!node.supports(.editMedia))
        #expect(!node.supports(.editIcon))
        #expect(presentationHint == .control)
        #expect(node.attributes["href"] == "")
    }

    /// 論理名（日本語）: Legacy type表示fallbackテスト
    /// 概要: capability根拠がないlegacy nodeを旧typeで単一分類せず、operation認可にも利用しないことを確認します。
    @Test("legacy data-og-typeは曖昧nodeを単一分類しない")
    func testLegacyTypeDoesNotClassifyAmbiguousNode() {
        // コンディション：operation capabilityを持たずlegacy icon hintだけを持つ未知nodeを用意する（Given）
        let node = OpenGraphiteNode(
            id: "legacy-icon",
            tagName: "legacyicon",
            legacyTypeHint: "icon",
            layout: nil,
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：表示hintとicon編集認可を別々に取得する（When）
        let presentationHint = node.presentationHint
        let canEditIcon = node.supports(.editIcon)

        // 期待値：曖昧nodeはgeneric表示のままで、legacy type単独ではicon編集を許可しない（Then）
        #expect(presentationHint == .generic)
        #expect(!canEditIcon)
    }

    /// 論理名（日本語）: 標準content attribute適用先matrixテスト
    /// 概要: operation capabilityとtag固有のHTML content attribute規則を組み合わせ、link、media、valueの編集先を限定することを確認します。
    @Test("標準content attributeはcapabilityと適用可能tagの両方で認可する")
    func testStandardContentAttributeEditingRequiresCapabilityAndValidTag() {
        // コンディション：空href link、ARIA link、value対応要素、media実体とwrapperを用意する（Given）
        let emptyEvidence = OpenGraphiteNodeCapabilityEvidence(
            isProjectResourceRoot: false,
            isNativeControl: false,
            isCustomElement: false,
            isLink: false,
            hasDirectText: false,
            hasElementChildren: false,
            hasMediaContent: false,
            hasSVGContent: false,
            hasMaskContent: false,
            ariaRole: nil,
            resolvedDisplay: "block"
        )
        let anchor = OpenGraphiteNode(
            id: "anchor",
            tagName: "a",
            capabilities: [.editLayout, .editLink],
            capabilityEvidence: emptyEvidence,
            attributes: ["href": ""],
            layout: "inline",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        var roleEvidence = emptyEvidence
        roleEvidence.ariaRole = "link"
        let roleLink = OpenGraphiteNode(
            id: "role-link",
            tagName: "div",
            capabilities: [.editControl, .editLayout],
            capabilityEvidence: roleEvidence,
            attributes: ["role": "link"],
            layout: "block",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let data = OpenGraphiteNode(
            id: "data",
            tagName: "data",
            capabilities: [.editLayout],
            capabilityEvidence: emptyEvidence,
            layout: "inline",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let listItem = OpenGraphiteNode(
            id: "list-item",
            tagName: "li",
            capabilities: [.editLayout],
            capabilityEvidence: emptyEvidence,
            layout: "list-item",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let output = OpenGraphiteNode(
            id: "output",
            tagName: "output",
            capabilities: [.editControl, .editLayout],
            capabilityEvidence: emptyEvidence,
            layout: "inline",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let image = OpenGraphiteNode(
            id: "image",
            tagName: "img",
            capabilities: [.editLayout, .editMedia],
            capabilityEvidence: emptyEvidence,
            layout: "inline",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )
        let mediaWrapper = OpenGraphiteNode(
            id: "media-wrapper",
            tagName: "figure",
            capabilities: [.editLayout, .editMedia],
            capabilityEvidence: emptyEvidence,
            layout: "block",
            role: nil,
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 1
        )

        // 検証内容：各nodeでInspectorが公開できる標準content attributeを判定する（When）
        let anchorCanEdit = (anchor.supportsEditingAttribute("href"), anchor.supportsEditingAttribute("target"))
        let roleLinkCanEdit = (
            roleLink.supportsEditingAttribute("href"),
            roleLink.supportsEditingAttribute("aria-label")
        )

        // 期待値：empty hrefのpresence、data/li value、img実体だけを許可し、ARIA linkやwrapperへ不正属性を追加しない（Then）
        #expect(anchorCanEdit.0)
        #expect(anchorCanEdit.1)
        #expect(!roleLinkCanEdit.0)
        #expect(roleLinkCanEdit.1)
        #expect(data.supportsEditingAttribute("value"))
        #expect(listItem.supportsEditingAttribute("value"))
        #expect(!output.supportsEditingAttribute("value"))
        #expect(image.supportsEditingAttribute("src"))
        #expect(image.supportsEditingAttribute("alt"))
        #expect(!mediaWrapper.supportsEditingAttribute("src"))
        #expect(!mediaWrapper.supportsEditingAttribute("alt"))
    }
}
