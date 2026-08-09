import Testing
import Foundation
@testable import OpenGraphite

/// 論理名（日本語）: エディターストア関連のテストスイート
/// 概要: DOM payload の取り込み、選択解除、CSS declaration mutation の状態更新を確認します。
@MainActor
@Suite("エディターストア関連のテストスイート")
struct EditorStoreTests {
    /// 論理名（日本語）: DOM payload 取り込みテスト
    /// 概要: JavaScript から渡された辞書配列が OpenGraphiteNode に変換されることを検証します。
    @Test("DOM payloadをノード一覧へ変換できる")
    func testIngestNodePayloadCreatesNodes() {
        // コンディション：data-og-id を持つ DOM payload を用意する
        let store = EditorStore()
        let payload: [[String: Any]] = [
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "layout": "horizontal",
                "role": "component-placement",
                "componentID": "site-header",
                "componentMaster": false,
                "sourceComponentID": "site-header",
                "sourceInstanceID": "header-instance",
                "sourceNodeInternalID": "source-node",
                "textContent": "Active headline",
                "fallbackTextContent": "Fallback headline",
                "textSource": "binding",
                "i18nKey": "home.hero.title",
                "cssVariables": ["gap": "32px"],
                "hidden": false,
                "locked": true,
                "depth": 1
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：ノードの基本情報と CSS declaration が保持される
        #expect(store.nodes.count == 1)
        #expect(store.nodes[0].id == "hero")
        #expect(store.nodes[0].layout == "horizontal")
        #expect(store.nodes[0].role == "component-placement")
        #expect(store.nodes[0].componentID == "site-header")
        #expect(store.nodes[0].sourceComponentID == "site-header")
        #expect(store.nodes[0].sourceInstanceID == "header-instance")
        #expect(store.nodes[0].sourceNodeInternalID == "source-node")
        #expect(store.nodes[0].textContent == "Active headline")
        #expect(store.nodes[0].fallbackTextContent == "Fallback headline")
        #expect(store.nodes[0].textSource == "binding")
        #expect(store.nodes[0].i18nKey == "home.hero.title")
        #expect(store.nodes[0].cssVariables["gap"] == "32px")
        #expect(store.nodes[0].isLocked == true)
    }

    /// 論理名（日本語）: Optional annotation payload取り込みテスト
    /// 概要: `data-og-type`を含むannotationがなくてもsession referenceとsource locatorからLayers / Inspector nodeを生成できることを確認します。
    @Test("未注釈DOM payloadをsession nodeとして取り込める")
    func testIngestNodePayloadCreatesUnannotatedSessionNode() throws {
        // コンディション：標準idとsource locatorだけを持つ未注釈HTML node payloadを用意する（Given）
        let store = EditorStore()
        let sessionReference = "ogref-session:node:document:path:content"
        store.ingestNodePayload([
            [
                "id": sessionReference,
                "authoredID": "",
                "standardID": "article",
                "internalID": "",
                "reference": sessionReference,
                "annotationStatus": "none",
                "referenceStability": "session",
                "locator": [
                    "documentURL": "file:///tmp/article.html",
                    "selector": "#article",
                    "domPath": "html > body > main",
                    "sourceRange": ["start": 42, "end": 108],
                    "contentHash": "content"
                ],
                "parentReference": NSNull(),
                "tagName": "main",
                "capabilities": ["edit-layout", "receive-children"],
                "capabilityEvidence": [
                    "isProjectResourceRoot": true,
                    "resolvedDisplay": "block"
                ],
                "cssVariables": ["display": "block"],
                "hidden": false,
                "locked": false,
                "depth": 0
            ]
        ])

        // 検証内容：Storeがpayloadを選択可能なnodeへ変換する（When）
        store.selectNode(id: sessionReference)
        let node = try #require(store.selectedNode)
        let locator = try #require(node.locator)

        // 期待値：標準idが表示名になり、type不要のread-only session nodeとlocatorが保持される（Then）
        #expect(node.id == sessionReference)
        #expect(node.displayID == "article")
        #expect(node.legacyTypeHint == nil)
        #expect(node.supports(.editLayout))
        #expect(node.supports(.receiveChildren))
        #expect(node.detailLine == "main")
        #expect(node.annotationStatus == .none)
        #expect(node.referenceStability == .session)
        #expect(node.reference == sessionReference)
        #expect(!node.hasStableReference)
        #expect(locator.selector == "#article")
        #expect(locator.domPath == "html > body > main")
        #expect(locator.sourceStart == 42)
        #expect(locator.sourceEnd == 108)
    }

    /// 論理名（日本語）: Layers即時公開と正本索引cacheテスト
    /// 概要: 軽量Web payloadを先に表示し、source graphをbackgroundで補完した後は同一revisionの索引を再構築しないことを確認します。
    @Test("Layersを即時表示して同一revisionの正本索引を再利用する")
    func testLayerPayloadPublishesBeforeSourceEnrichmentAndReusesRevisionCache() async throws {
        // コンディション：stable internal IDを持つ標準HTML pageと軽量Layers payloadを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <main id="root" data-og-internal-id="root-node">
            <section id="card" data-og-internal-id="card-node">Card</section>
          </main>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let lightweightPayload: [[String: Any]] = [
            [
                "id": "card-browser",
                "standardID": "card",
                "internalID": "card-node",
                "reference": "ogref:node:card-node",
                "tagName": "section",
                "hidden": false,
                "locked": false,
                "depth": 1,
                "activeMediaQueries": []
            ]
        ]

        // 検証内容：軽量payloadを受信して即時状態を確認し、background補完後に同じpayloadをもう一度取り込む（When）
        store.ingestNodePayload(lightweightPayload)
        let immediateNode = try #require(store.nodes.first)
        #expect(immediateNode.attributes.isEmpty)
        #expect(store.nodeSourceIndexBuildCount == 1)
        await store.waitForNodeSourceEnrichment()
        let enrichedNode = try #require(store.nodes.first)
        store.ingestNodePayload(lightweightPayload)
        await store.waitForNodeSourceEnrichment()

        // 期待値：Layers行はgraph完了前から存在し、補完後はsource属性/capabilityを持ち、同一revisionの再構築は起きない（Then）
        #expect(enrichedNode.attributes["id"] == "card")
        #expect(enrichedNode.internalID == "card-node")
        #expect(!enrichedNode.capabilities.isEmpty)
        #expect(store.nodes.first?.attributes["id"] == "card")
        #expect(store.nodeSourceIndexBuildCount == 1)
    }

    /// 論理名（日本語）: Source/WebKit capability安全側mergeテスト
    /// 概要: runtime payloadがsourceで拒否されたcapabilityや未authored属性を主張しても、Appが権限を拡大せずsource属性だけを編集baselineに使うことを確認します。
    @Test("source-backed nodeはcapability共通部分とauthored属性だけを採用する")
    func testSourceBackedNodeUsesCapabilityIntersectionAndSourceAttributes() async throws {
        // コンディション：constrained table rowと空href hyperlinkを持つprojectへ過剰capability/runtime属性payloadを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html>
        <html><body><main id="root" data-og-internal-id="root-node"><table><tbody><tr id="row" data-og-internal-id="row-node"><td>Cell</td></tr></tbody></table><a id="link" href="/authored" data-og-internal-id="link-node">Link</a></main></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let graph = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
        let sourceRow = try #require(graph.nodes.first { $0.internalID == "row-node" })
        let sourceLink = try #require(graph.nodes.first { $0.internalID == "link-node" })
        let excessiveCapabilities = OpenGraphiteNodeCapability.allCases.map(\.rawValue)
        let unsafeEvidence: [String: Any] = [
            "isProjectResourceRoot": false,
            "isNativeControl": true,
            "isCustomElement": true,
            "isLink": true,
            "hasDirectText": true,
            "hasElementChildren": true,
            "hasMediaContent": true,
            "hasSVGContent": true,
            "hasMaskContent": true,
            "ariaRole": "button",
            "resolvedDisplay": "block"
        ]
        let payload: [[String: Any]] = [
            Self.browserPayload(
                id: "row-browser",
                sourceNode: sourceRow,
                capabilities: excessiveCapabilities,
                evidence: unsafeEvidence,
                attributes: ["href": "/runtime", "src": "runtime.png"],
                role: "button",
                hidden: true,
                locked: true
            ),
            Self.browserPayload(
                id: "link-browser",
                sourceNode: sourceLink,
                capabilities: excessiveCapabilities,
                evidence: unsafeEvidence,
                attributes: ["href": "/runtime", "target": "_blank"],
                role: "button",
                hidden: true,
                locked: true
            )
        ]

        // 検証内容：payloadをsource graphへmergeし、rowへの不正hrefとlinkへの正当href編集を順に試す（When）
        await store.ingestNodePayloadAndWait(payload)
        store.selectNode(id: "row-browser")
        let row = try #require(store.selectedNode)
        store.updateNodeAttribute(name: "href", value: "/forbidden")
        let afterRejectedEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.selectNode(id: "link-browser")
        let link = try #require(store.selectedNode)
        store.updateNodeAttribute(name: "href", value: "/saved")
        let afterLinkEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：rowの拒否capability/runtime属性は復活せず、linkはauthored値だけをbaselineに最小更新する（Then）
        #expect(row.capabilities == Set(sourceRow.capabilities))
        #expect(!row.supports(.receiveChildren))
        #expect(!row.supports(.group))
        #expect(row.attributes["href"] == nil)
        #expect(row.attributes["src"] == nil)
        #expect(row.role == nil)
        #expect(!row.hasHiddenAttribute)
        #expect(!row.isLocked)
        #expect(afterRejectedEdit == originalHTML)
        #expect(link.capabilities == Set(sourceLink.capabilities))
        #expect(link.attributes["href"] == "/authored")
        #expect(link.attributes["target"] == nil)
        #expect(link.role == nil)
        #expect(afterLinkEdit == originalHTML.replacingOccurrences(of: "href=\"/authored\"", with: "href=\"/saved\""))
    }

    /// 論理名（日本語）: 空値属性設定と明示削除テスト
    /// 概要: missing属性への空文字設定とpresent-empty属性tokenの削除を別operationとして保存し、Undo/Redoでもsource byte表現を復元することを確認します。
    @Test("alt空値設定と属性削除をpresence intentで区別する")
    func testEmptyAttributeSetAndExplicitRemovalPreservePresenceIntent() throws {
        // コンディション：altを持たず未知属性とsingle-quote srcを持つstable img nodeを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body><main data-og-internal-id="root-node"><img id="hero" data-vendor=/a/b src='hero.png' data-og-internal-id="hero-node"></main></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNode = try #require(
            try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
                .nodes.first { $0.internalID == "hero-node" }
        )
        store.ingestNodePayload([
            Self.browserPayload(
                id: "hero",
                sourceNode: sourceNode,
                capabilities: sourceNode.capabilities.map(\.rawValue),
                evidence: Self.capabilityEvidencePayload(sourceNode.capabilityEvidence),
                attributes: sourceNode.attributes,
                role: "",
                hidden: false,
                locked: false
            )
        ])
        store.selectNode(id: "hero")

        // 検証内容：missing altを空値で追加し、明示削除後にUndo/Redoする（When）
        store.updateNodeAttribute(name: "alt", value: "")
        let emptyAltHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let emptyAltNode = try #require(store.selectedNode)
        store.removeNodeAttribute(name: "alt")
        let removedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.undoDocumentChange()
        let undoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.redoDocumentChange()
        let redoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：emptyとabsentを区別し、対象token以外のquote/trivia/未知属性byteを保持する（Then）
        let expectedEmptyHTML = originalHTML.replacingOccurrences(
            of: " data-og-internal-id=\"hero-node\">",
            with: " data-og-internal-id=\"hero-node\" alt=\"\">"
        )
        #expect(emptyAltHTML == expectedEmptyHTML)
        #expect(emptyAltNode.hasAuthoredAttribute(named: "alt"))
        #expect(emptyAltNode.attributes["alt"] == "")
        #expect(removedHTML == originalHTML)
        #expect(undoHTML == expectedEmptyHTML)
        #expect(redoHTML == originalHTML)
        #expect(emptyAltHTML.contains("data-vendor=/a/b src='hero.png'"))
    }

    /// 論理名（日本語）: 属性値stale preconditionテスト
    /// 概要: 属性presenceが同じでも外部変更されたsemantic値を古いInspector baselineで上書きしないことを確認します。
    @Test("外部変更された属性値をstale setで上書きしない")
    func testAttributeSetRejectsStaleValueWithSamePresence() throws {
        // コンディション：authored alt値を取り込んだ後、同じ属性tokenを外部processが別値へ更新する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body><main data-og-internal-id="root-node"><img id="hero" alt="old" src="hero.png" data-og-internal-id="hero-node"></main></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNode = try #require(
            try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
                .nodes.first { $0.internalID == "hero-node" }
        )
        store.ingestNodePayload([
            Self.browserPayload(
                id: "hero",
                sourceNode: sourceNode,
                capabilities: sourceNode.capabilities.map(\.rawValue),
                evidence: Self.capabilityEvidencePayload(sourceNode.capabilityEvidence),
                attributes: sourceNode.attributes,
                role: "",
                hidden: false,
                locked: false
            )
        ])
        store.selectNode(id: "hero")
        let externallyChangedHTML = originalHTML.replacingOccurrences(of: "alt=\"old\"", with: "alt=\"external\"")
        try externallyChangedHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：古いold baselineのまま新値を保存しようとする（When）
        store.updateNodeAttribute(name: "alt", value: "new")
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：presenceだけでなくsemantic値不一致を検出し、外部sourceをbyte単位で保持する（Then）
        #expect(finalHTML == externallyChangedHTML)
        #expect(store.lastError != nil)
        #expect(store.attributeMutation == nil)
    }

    /// 論理名（日本語）: 親Timeline文脈解決テスト
    /// 概要: 選択ノードの祖先にある view timeline declaration を Inspector 表示用 context として取得できることを確認します。
    @Test("親timeline contextをInspector用に解決できる")
    func testSelectedAppliedParentAnimationContextFindsNearestTimelineParent() throws {
        // コンディション：timeline provider の子に component instance がある DOM payload を用意する（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "principle-list",
                "internalID": "d3386fbce50b",
                "tagName": "principlelist",
                "type": "frame",
                "cssVariables": [
                    "view-timeline-name": "--home-principles",
                    "view-timeline-axis": "block"
                ],
                "depth": 0
            ],
            [
                "id": "principles-heading",
                "internalID": "9617db163b8c",
                "tagName": "og-instance",
                "type": "frame",
                "cssVariables": [String: String](),
                "depth": 1
            ]
        ])

        // 検証内容：子ノードを選択し、適用元の親 animation context を取得する（When）
        store.selectNode(id: "principles-heading")
        let context = try #require(store.selectedAppliedParentAnimationContext)

        // 期待値：子自身ではなく親の timeline declaration が表示用 context になる（Then）
        #expect(context.nodeID == "principle-list")
        #expect(context.nodeInternalID == "d3386fbce50b")
        #expect(context.declarations.map(\.key) == ["view-timeline-name", "view-timeline-axis"])
        #expect(context.declarations.map(\.value) == ["--home-principles", "block"])
    }

    /// 論理名（日本語）: NamedTimeline一致祖先優先テスト
    /// 概要: 選択ノードの `animation-timeline` が named timeline を参照している場合、一致する祖先 provider を優先することを確認します。
    @Test("named animation-timelineは一致する祖先timelineを優先する")
    func testSelectedAppliedParentAnimationContextPrioritizesMatchedTimelineProvider() throws {
        // コンディション：近い親には通常 animation、上位祖先には参照先 timeline provider がある（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "principles",
                "internalID": "principles-node",
                "tagName": "principlesection",
                "type": "frame",
                "cssVariables": [
                    "view-timeline-name": "--home-principles",
                    "view-timeline-axis": "block"
                ],
                "depth": 0
            ],
            [
                "id": "principle-item",
                "internalID": "principle-item-node",
                "tagName": "principleitem",
                "type": "frame",
                "cssVariables": [
                    "animation-name": "fade-up"
                ],
                "depth": 1
            ],
            [
                "id": "principle-title",
                "internalID": "principle-title-node",
                "tagName": "principletitle",
                "type": "text",
                "cssVariables": [
                    "animation-timeline": "--home-principles"
                ],
                "depth": 2
            ]
        ])

        // 検証内容：named timeline を参照する子ノードを選択する（When）
        store.selectNode(id: "principle-title")
        let context = try #require(store.selectedAppliedParentAnimationContext)

        // 期待値：近い通常 animation 親ではなく、参照名に一致する timeline provider が選ばれる（Then）
        #expect(context.nodeID == "principles")
        #expect(context.matchedTimelineNames == ["--home-principles"])
        #expect(context.declarations.map(\.key) == ["view-timeline-name", "view-timeline-axis"])
    }

    /// 論理名（日本語）: Placement選択維持テスト
    /// 概要: component placement host を選択した場合、参照元 component node へ解決せず placement 自体を選択状態にすることを確認します。
    @Test("placement選択はplacement node自体を維持する")
    func testSelectNodeKeepsComponentPlacementSelected() {
        // コンディション：source node と placement host の payload を取り込む（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "codeviewer",
                "internalID": "hrbifdygbcig",
                "tagName": "codeviewer",
                "type": "frame",
                "layout": "vertical",
                "role": "",
                "cssVariables": ["width": "440px"],
                "hidden": false,
                "locked": false,
                "depth": 1
            ],
            [
                "id": "placement-code-viewer-preview",
                "internalID": "67a2e12dbed8",
                "tagName": "og-placement",
                "type": "frame",
                "layout": "vertical",
                "role": "component-placement",
                "sourceNodeInternalID": "hrbifdygbcig",
                "cssVariables": [String: String](),
                "hidden": false,
                "locked": false,
                "depth": 1
            ]
        ])

        // 検証内容：placement host を選択する（When）
        store.selectNode(id: "placement-code-viewer-preview")

        // 期待値：選択 ID は placement host のまま保持される（Then）
        #expect(store.selectedNodeID == "placement-code-viewer-preview")
    }

    /// 論理名（日本語）: Placement内部ノード編集テスト
    /// 概要: placement clone 内の node を選択した場合、表示専用 ID を維持しつつ正本 component node を更新することを確認します。
    @Test("placement内部nodeの編集は参照元component nodeへ保存する")
    func testPlacementGeneratedNodeEditsSourceComponentNode() async throws {
        // コンディション：参照元 node を持つ HTML と、placement clone の payload を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <CodeViewer data-og-id="codeviewer" data-og-internal-id="hrbifdygbcig" data-og-type="frame"></CodeViewer>
          <og-placement data-og-id="placement-code-viewer-preview" data-og-internal-id="placement-node" data-og-type="frame" data-og-source-component-internal-id="component-main" data-og-source-node-internal-id="hrbifdygbcig"></og-placement>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hrbifdygbcig"] {
              gap: 9px;
            }
            """
        )
        let placementSelectionID = "ogpl:placement-code-viewer-preview:hrbifdygbcig"
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "codeviewer",
                "internalID": "hrbifdygbcig",
                "tagName": "codeviewer",
                "type": "frame",
                "cssVariables": ["gap": "9px"],
                "depth": 0
            ],
            [
                "id": "placement-code-viewer-preview",
                "internalID": "placement-node",
                "tagName": "og-placement",
                "type": "frame",
                "role": "component-placement",
                "sourceNodeInternalID": "hrbifdygbcig",
                "cssVariables": [String: String](),
                "depth": 0
            ],
            [
                "id": placementSelectionID,
                "internalID": "hrbifdygbcig",
                "tagName": "codeviewer",
                "type": "frame",
                "sourceNodeID": "codeviewer",
                "sourcePlacementID": "placement-code-viewer-preview",
                "placementGenerated": true,
                "cssVariables": ["gap": "9px"],
                "depth": 1
            ]
        ])
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：placement clone 内 node を選択して CSS declaration を更新する（When）
        store.selectNode(id: placementSelectionID)
        store.updateCSSVariable(key: "gap", value: "24px")

        // 期待値：選択 ID は clone 用のまま、保存先 HTML は同じ internalID の正本 node になる（Then）
        #expect(store.selectedNodeID == placementSelectionID)
        #expect(store.selectedNode?.displayID == "codeviewer")
        #expect(store.selectedNode?.editTargetNodeID == "codeviewer")
        #expect(store.selectedNode?.isPlacementGenerated == true)
        #expect(store.lastError == nil)
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()
        #expect(!diskHTML.contains("gap"))
        #expect(diskCSS.contains("gap: 24px;"))
    }

    /// 論理名（日本語）: DOM payload fallback補完テスト
    /// 概要: preview DOM の resolved text と HTML 正本の fallback text が異なる場合、両方を Inspector 用ノードへ保持することを検証します。
    @Test("DOM payloadのtext metadataをHTML正本fallbackで補完できる")
    func testIngestNodePayloadMergesSourceFallbackText() throws {
        // コンディション：binding text node を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <lead-text
            data-og-id="hero-lead"
            data-og-internal-id="lead-node"
            data-og-text-source="binding"
            data-i18n-key="home.hero.lead">日本語 fallback</lead-text>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：runtime 解決後の DOM から届く active text を取り込む
        store.ingestNodePayload([
            [
                "id": "hero-lead",
                "internalID": "lead-node",
                "tagName": "lead-text",
                "capabilities": [OpenGraphiteNodeCapability.editText.rawValue],
                "capabilityEvidence": [
                    "isProjectResourceRoot": false,
                    "isNativeControl": false,
                    "isCustomElement": true,
                    "isLink": false,
                    "hasDirectText": true,
                    "hasElementChildren": false,
                    "hasMediaContent": false,
                    "hasSVGContent": false,
                    "hasMaskContent": false,
                    "resolvedDisplay": "inline"
                ],
                "textContent": "English active",
                "fallbackTextContent": "日本語 fallback",
                "textSource": "binding",
                "i18nKey": "home.hero.lead",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])

        // 期待値：active resolved text は DOM、fallback と binding metadata は HTML 正本から保持される
        let node = try #require(store.nodes.first)
        #expect(node.textContent == "English active")
        #expect(node.fallbackTextContent == "日本語 fallback")
        #expect(node.textSource == "binding")
        #expect(node.i18nKey == "home.hero.lead")
    }

    /// 論理名（日本語）: 存在しない選択解除テスト
    /// 概要: 再取り込み後に選択中ノードが存在しない場合、選択が解除されることを検証します。
    @Test("再取り込み後に存在しない選択を解除する")
    func testIngestNodePayloadClearsMissingSelection() {
        // コンディション：選択済みノードとは別の DOM payload を用意する
        let store = EditorStore()
        store.selectNode(id: "old-node")
        let payload: [[String: Any]] = [
            [
                "id": "new-node",
                "tagName": "frame",
                "type": "frame",
                "depth": 0
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：存在しない old-node の選択が解除される
        #expect(store.selectedNodeID == nil)
        #expect(store.selectedNodeIDs.isEmpty)
    }

    /// 論理名（日本語）: 選択オーバーレイ実測矩形取り込みテスト
    /// 概要: 選択枠が companion CSS の位置推定ではなく WebView の実測 rect を保持することを検証します。
    @Test("選択overlayはWebView実測rectをsource of truthにする")
    func testIngestSelectionOverlayPayloadUsesMeasuredRect() throws {
        // コンディション：CSS 上は top を持たない flow child を選択している（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "frame",
                "tagName": "opengraphiteframe",
                "type": "frame",
                "cssVariables": ["width": "287px", "height": "54px"],
                "depth": 1
            ]
        ])
        store.selectNode(id: "frame")

        // 検証内容：WebView から flow 後の実測 rect payload を取り込む（When）
        store.ingestSelectionOverlayPayload(
            [
                "active": true,
                "id": "frame",
                "nodes": [
                    ["id": "frame", "x": 0.0, "y": 31.0, "width": 287.0, "height": 54.0]
                ]
            ],
            pageInternalID: "page-1"
        )

        // 期待値：CSS 推定の y=0 ではなく、実測された y=31 の矩形が保持される（Then）
        let overlay = try #require(store.selectionOverlayFrame)
        #expect(overlay.pageInternalID == "page-1")
        #expect(overlay.primaryNodeID == "frame")
        #expect(overlay.nodeIDs == ["frame"])
        #expect(overlay.rect == CGRect(x: 0, y: 31, width: 287, height: 54))
        #expect(overlay.nodeRectsByID["frame"] == CGRect(x: 0, y: 31, width: 287, height: 54))
    }

    /// 論理名（日本語）: 複数選択オーバーレイ実測矩形取り込みテスト
    /// 概要: 同時選択時に WebView 実測 rect の union と node 別 rect が保持されることを検証します。
    @Test("複数選択overlayは実測rectのunionと個別rectを保持する")
    func testIngestSelectionOverlayPayloadStoresMeasuredGroupRects() throws {
        // コンディション：Sidebar Layers で2つの node を同時選択している（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            ["id": "hero", "tagName": "hero", "type": "frame", "depth": 0],
            ["id": "card", "tagName": "card", "type": "frame", "depth": 1],
            ["id": "title", "tagName": "title", "type": "text", "depth": 2]
        ])
        store.selectNode(id: "hero")
        store.selectNodeRange(to: "card", visibleNodeIDs: ["hero", "card", "title"])

        // 検証内容：選択外 node も混じった WebView 実測 payload を取り込む（When）
        store.ingestSelectionOverlayPayload(
            [
                "active": true,
                "id": "card",
                "nodes": [
                    ["id": "hero", "x": 10.0, "y": 20.0, "width": 100.0, "height": 30.0],
                    ["id": "card", "x": 10.0, "y": 60.0, "width": 200.0, "height": 40.0],
                    ["id": "title", "x": 999.0, "y": 999.0, "width": 20.0, "height": 20.0]
                ]
            ],
            pageInternalID: "page-1"
        )

        // 期待値：選択中 node だけで union が作られ、個別 rect も実測値で保持される（Then）
        let overlay = try #require(store.selectionOverlayFrame)
        #expect(overlay.primaryNodeID == "card")
        #expect(overlay.nodeIDs == ["hero", "card"])
        #expect(overlay.rect == CGRect(x: 10, y: 20, width: 200, height: 80))
        #expect(overlay.nodeRectsByID["hero"] == CGRect(x: 10, y: 20, width: 100, height: 30))
        #expect(overlay.nodeRectsByID["card"] == CGRect(x: 10, y: 60, width: 200, height: 40))
        #expect(overlay.nodeRectsByID["title"] == nil)
    }

    /// 論理名（日本語）: Focus対象スナップショットテスト
    /// 概要: 右クリックで開始したFocus対象がNormal/Flow表示モードや通常selectionから独立して保持・解除されることを検証します。
    @Test("Focus対象を表示モードと通常selectionから独立して保持する")
    func testFocusedPreviewTargetIsIndependentFromDisplayModeAndSelection() throws {
        // コンディション：Flow表示中にhero objectを右クリックした相当の実測値がある（Given）
        let store = EditorStore()
        store.previewDisplayMode = .flow
        store.selectNode(id: "hero")
        let rect = CGRect(x: 120, y: 240, width: 320, height: 180)

        // 検証内容：heroのFocusを開始してから通常selectionを別nodeへ移し、Focusを解除する（When）
        let didBegin = store.beginFocusedPreview(
            nodeID: "hero",
            pageInternalID: "page-home",
            segment: .pages,
            rect: rect
        )
        store.selectNode(id: "card")
        let targetBeforeEnd = try #require(store.focusedPreviewTarget)
        store.endFocusedPreview()

        // 期待値：Focus対象はheroのsnapshotを保ち、解除後もFlowとcard selectionが維持される（Then）
        #expect(didBegin)
        #expect(targetBeforeEnd.nodeID == "hero")
        #expect(targetBeforeEnd.pageInternalID == "page-home")
        #expect(targetBeforeEnd.segment == .pages)
        #expect(targetBeforeEnd.rect == rect)
        #expect(store.focusedPreviewTarget == nil)
        #expect(store.previewDisplayMode == .flow)
        #expect(store.selectedNodeID == "card")
    }

    /// 論理名（日本語）: ページ全体Focus対象スナップショットテスト
    /// 概要: page cardの右クリック相当操作がnode隔離を使わず、page全体をoriginal resolutionのFocus対象として保持することを検証します。
    @Test("ページ全体をnode IDなしのFocus対象として保持する")
    func testFocusedPagePreviewTargetsWholeCanvas() throws {
        // コンディション：1440 x 1200のpage cardを右クリックした相当の入力がある（Given）
        let store = EditorStore()
        let pageSize = CGSize(width: 1440, height: 1200)

        // 検証内容：page全体のFocus表示を開始する（When）
        let didBegin = store.beginFocusedPagePreview(
            pageInternalID: "page-home",
            segment: .pages,
            size: pageSize
        )

        // 期待値：node IDを持たず、page canvas全体の矩形を保持する（Then）
        let target = try #require(store.focusedPreviewTarget)
        #expect(didBegin)
        #expect(target.nodeID == nil)
        #expect(target.pageInternalID == "page-home")
        #expect(target.segment == .pages)
        #expect(target.rect == CGRect(origin: .zero, size: pageSize))
    }

    /// 論理名（日本語）: 無効Focus対象拒否テスト
    /// 概要: 空IDや0寸法objectからFocus表示を開始しないことを検証します。
    @Test("無効なFocus対象を拒否する")
    func testBeginFocusedPreviewRejectsInvalidTarget() {
        // コンディション：空node IDと0幅のobject矩形を用意する（Given）
        let store = EditorStore()

        // 検証内容：無効なobjectとpageのFocus対象で開始を試みる（When）
        let didBeginObject = store.beginFocusedPreview(
            nodeID: "",
            pageInternalID: "page-home",
            segment: .pages,
            rect: CGRect(x: 0, y: 0, width: 0, height: 180)
        )
        let didBeginPage = store.beginFocusedPagePreview(
            pageInternalID: "page-home",
            segment: .pages,
            size: CGSize(width: 0, height: 1200)
        )

        // 期待値：どちらもFocus状態を作らずfalseを返す（Then）
        #expect(!didBeginObject)
        #expect(!didBeginPage)
        #expect(store.focusedPreviewTarget == nil)
    }

    /// 論理名（日本語）: Sidebar Layers範囲選択テスト
    /// 概要: Shift クリック相当の範囲選択で、アンカーから終端までの表示中ノードが同時選択されることを検証します。
    @Test("Sidebar Layersでアンカーから表示順範囲を同時選択する")
    func testSelectNodeRangeSelectsVisibleLayerRange() {
        // コンディション：Sidebar Layers に表示される複数ノードを取り込み、先頭ノードを通常選択する（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            ["id": "hero", "tagName": "hero", "type": "frame", "depth": 0],
            ["id": "card", "tagName": "card", "type": "frame", "depth": 1],
            ["id": "title", "tagName": "title", "type": "text", "depth": 2],
            ["id": "cta", "tagName": "button", "type": "button", "depth": 1]
        ])
        store.selectNode(id: "hero")

        // 検証内容：表示順で title までの範囲を選択する（When）
        store.selectNodeRange(to: "title", visibleNodeIDs: ["hero", "card", "title", "cta"])

        // 期待値：主選択は終端に移り、アンカーから終端までのノードが同時選択される（Then）
        #expect(store.selectedNodeID == "title")
        #expect(store.selectedNodeIDs == Set(["hero", "card", "title"]))
    }

    /// 論理名（日本語）: Sidebar Layers同時選択内主選択切替テスト
    /// 概要: 同時選択中の node を Preview 側でクリックしたとき、同時選択セットを維持したまま主選択だけ切り替わることを検証します。
    @Test("Sidebar Layers同時選択内のPreviewクリックは同時選択を維持する")
    func testSelectPrimaryNodeWithinCurrentSelectionKeepsRange() {
        // コンディション：Sidebar Layers の範囲選択で3つの node を同時選択する（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            ["id": "hero", "tagName": "hero", "type": "frame", "depth": 0],
            ["id": "card", "tagName": "card", "type": "frame", "depth": 1],
            ["id": "title", "tagName": "title", "type": "text", "depth": 2]
        ])
        store.selectNode(id: "hero")
        store.selectNodeRange(to: "title", visibleNodeIDs: ["hero", "card", "title"])

        // 検証内容：同時選択内の別 node を Preview クリック相当で主選択にする（When）
        let didSelect = store.selectPrimaryNodeWithinCurrentSelection(id: "card")

        // 期待値：主選択は切り替わり、同時選択セットは維持される（Then）
        #expect(didSelect)
        #expect(store.selectedNodeID == "card")
        #expect(store.selectedNodeIDs == Set(["hero", "card", "title"]))
    }

    /// 論理名（日本語）: Sidebar Layers通常選択復帰テスト
    /// 概要: 範囲選択後に通常選択した場合、同時選択が解除されて単一ノードだけが残ることを検証します。
    @Test("Sidebar Layersの通常選択で同時選択を解除する")
    func testSelectNodeResetsLayerRangeSelection() {
        // コンディション：範囲選択済みの Sidebar Layers 状態を用意する（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            ["id": "hero", "tagName": "hero", "type": "frame", "depth": 0],
            ["id": "card", "tagName": "card", "type": "frame", "depth": 1],
            ["id": "title", "tagName": "title", "type": "text", "depth": 2]
        ])
        store.selectNode(id: "hero")
        store.selectNodeRange(to: "title", visibleNodeIDs: ["hero", "card", "title"])

        // 検証内容：別ノードを通常選択する（When）
        store.selectNode(id: "card")

        // 期待値：主選択と同時選択セットが通常選択したノードだけになる（Then）
        #expect(store.selectedNodeID == "card")
        #expect(store.selectedNodeIDs == Set(["card"]))
    }

    /// 論理名（日本語）: Sidebar Layers同時選択CSS保存テスト
    /// 概要: 同時選択中のInspector相当CSS更新が各nodeのcompanion CSSへ分配され、表示をsourceから再読み込みすることを検証します。
    @Test("Sidebar Layers同時選択中のCSS更新は各nodeへ保存する")
    func testUpdateCSSVariableAppliesToSelectedLayerNodes() async throws {
        // コンディション：2つの frame node を持つ HTML と companion CSS を用意し、Sidebar Layers で同時選択する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero>
          <Card data-og-id="card" data-og-internal-id="card-node" data-og-type="frame"></Card>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 8px;
            }

            [data-og-internal-id="card-node"] {
              gap: 12px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            ["id": "hero", "internalID": "hero-node", "tagName": "hero", "type": "frame", "cssVariables": ["gap": "8px"], "depth": 0],
            ["id": "card", "internalID": "card-node", "tagName": "card", "type": "frame", "cssVariables": ["gap": "12px"], "depth": 0]
        ])
        store.selectNode(id: "hero")
        store.selectNodeRange(to: "card", visibleNodeIDs: ["hero", "card"])
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：Inspector 相当で gap を同じ値へ更新する（When）
        store.updateCSSVariable(key: "gap", value: "24px")
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：両nodeのCSSを保存し、inline batch mutationを残さず1回再読み込みする（Then）
        #expect(store.nodes.first(where: { $0.id == "hero" })?.cssVariables["gap"] == "24px")
        #expect(store.nodes.first(where: { $0.id == "card" })?.cssVariables["gap"] == "24px")
        #expect(store.cssVariablesBatchMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(diskCSS.contains(#"[data-og-internal-id="hero-node"]"#))
        #expect(diskCSS.contains(#"[data-og-internal-id="card-node"]"#))
        #expect(diskCSS.components(separatedBy: "gap: 24px;").count == 3)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: ページ選択解除テスト
    /// 概要: ページ選択を nil にすると先頭ページへ戻らず未選択状態になることを検証します。
    @Test("ページ選択を解除できる")
    func testSelectPageNilClearsPageSelection() throws {
        // コンディション：プロジェクトを開き、ページとノードが選択されている状態を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：ページ選択を解除する
        store.selectPage(id: nil)

        // 期待値：選択ページ、選択ノード、ページ由来のノード一覧が空になる
        #expect(store.selectedPageID == nil)
        #expect(store.selectedPage == nil)
        #expect(store.selectedPageURL == nil)
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.isEmpty)
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
        #expect(store.statusMessage == "ページ選択を解除しました。")
    }

    /// 論理名（日本語）: Project初期Chapter選択テスト
    /// 概要: Project を開いた直後は先頭 Chapter だけを表示対象にし、HTML カードを自動選択しないことを検証します。
    @Test("Projectを開いた直後はpageを自動選択しない")
    func testOpenProjectStartsWithChapterOnlySelection() throws {
        // コンディション：ページを持つ一時プロジェクトを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()

        // 検証内容：Project を開く（When）
        store.openProject(at: fixture.projectURL)

        // 期待値：Chapter は表示対象になるが、page / node は未選択になる（Then）
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.selectedChapterID == "main")
        #expect(store.selectedChapterPages.map(\.id) == ["home"])
        #expect(store.selectedPageID == nil)
        #expect(store.selectedPage == nil)
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.isEmpty)
    }

    /// 論理名（日本語）: Components初期選択抑止テスト
    /// 概要: Pages から Components へ切り替えても先頭 component を自動選択せず、明示選択まで重い編集準備を開始しないことを検証します。
    @Test("PagesからComponentsへ切り替えても先頭componentを自動選択しない")
    func testSelectComponentsSegmentKeepsComponentUnselected() throws {
        // コンディション：Page と2件の component を持つprojectでPageを選択し、DOM nodeを読み込む（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components", isDirectory: true)
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        let firstComponentURL = componentDirectory.appendingPathComponent("first.html")
        let secondComponentURL = componentDirectory.appendingPathComponent("second.html")
        try "<!doctype html><html><body>First</body></html>".write(to: firstComponentURL, atomically: true, encoding: .utf8)
        try "<!doctype html><html><body>Second</body></html>".write(to: secondComponentURL, atomically: true, encoding: .utf8)
        var project = try ProjectLoader().loadProject(at: fixture.projectURL).project
        project.collections = [
            OpenGraphiteComponentCollection(
                id: "components",
                internalID: "collection-components",
                components: [
                    OpenGraphitePage(
                        id: "first",
                        internalID: "component-first",
                        path: "_components/first.html",
                        canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                    ),
                    OpenGraphitePage(
                        id: "second",
                        internalID: "component-second",
                        path: "_components/second.html",
                        canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                    )
                ]
            )
        ]
        try JSONEncoder().encode(project).write(to: fixture.projectURL, options: .atomic)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            ["id": "page-node", "tagName": "main", "depth": 0]
        ])

        // 検証内容：Sidebar 相当の操作で Components セグメントへ切り替える（When）
        store.selectComponentsSegment()

        // 期待値：Collection と全component canvasは表示対象になるが、component・node・HTML履歴対象は未選択になる（Then）
        #expect(store.selectedCanvasSegment == .components)
        #expect(store.selectedComponentCollection?.id == "components")
        #expect(store.componentPages.map(\.id) == ["first", "second"])
        #expect(store.selectedComponentPageID == nil)
        #expect(store.selectedComponentPageInternalID == nil)
        #expect(store.selectedPage == nil)
        #expect(store.selectedPageURL == nil)
        #expect(store.nodes.isEmpty)
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: Chapter追加保存テスト
    /// 概要: Store から新しい Chapter を追加し、選択状態と `.ogp` の保存内容が更新されることを検証します。
    @Test("Chapterを追加してogpへ保存できる")
    func testAddChapterPersistsManifestAndSelectsNewChapter() throws {
        // コンディション：ページを持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：Chapter 追加操作を実行する（When）
        store.addChapter()

        // 期待値：Store とディスク上の `.ogp` に空の Chapter が追加され、その Chapter が選択される（Then）
        let addedChapter = try #require(store.selectedChapter)
        #expect(store.loadedProject?.project.chapters.count == 2)
        #expect(addedChapter.id == "chapter-1")
        #expect(addedChapter.displayName == "Chapter 2")
        #expect(!addedChapter.internalID.isEmpty)
        #expect(addedChapter.pages.isEmpty)
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.selectedPage == nil)
        #expect(store.lastError == nil)

        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedChapter = try #require(reloadedProject.project.chapters.last)
        #expect(reloadedProject.project.chapters.count == 2)
        #expect(persistedChapter.id == "chapter-1")
        #expect(persistedChapter.displayName == "Chapter 2")
        #expect(persistedChapter.pages.isEmpty)
        #expect(persistedChapter.internalID == addedChapter.internalID)
    }

    /// 論理名（日本語）: Chapter表示名更新テスト
    /// 概要: Sidebar のインライン編集から Chapter title を `.ogp` に保存できることを検証します。
    @Test("Chapter表示名をogpへ保存できる")
    func testUpdateChapterTitlePersistsManifest() throws {
        // コンディション：既存 Chapter を持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let chapterInternalID = try #require(store.selectedChapter?.internalID)

        // 検証内容：Chapter の表示名を更新する（When）
        store.updateChapterTitle(internalID: chapterInternalID, value: " Landing Pages ")
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedChapter = try #require(reloadedProject.project.chapters.first)

        // 期待値：title は前後空白を除いて保存され、選択状態は維持される（Then）
        #expect(store.selectedChapter?.displayName == "Landing Pages")
        #expect(persistedChapter.title == "Landing Pages")
        #expect(persistedChapter.internalID == chapterInternalID)
        #expect(store.selectedChapterInternalID == chapterInternalID)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: Pageキャンバス表示切替テスト
    /// 概要: Page entry と実ファイルを保持したまま、Chapter キャンバスでの表示だけを切り替えられることを確認します。
    @Test("PageをSidebarに残したままキャンバス表示を切り替えられる")
    func testSetPageCanvasHiddenPersistsWithoutDeletingSource() throws {
        // コンディション：Page と同名 companion CSS を持つ project を開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try fixture.writeCompanionCSS("body { color: red; }")
        let originalHTML = try Data(contentsOf: fixture.htmlURL)
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        let originalCSS = try Data(contentsOf: companionCSSURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try #require(store.selectedChapterPages.first)

        // 検証内容：Page をキャンバスから非表示にしてから再表示する（When）
        store.setPageCanvasHidden(internalID: page.internalID, hidden: true)
        let hiddenProject = try ProjectLoader().loadProject(at: fixture.projectURL)

        // 期待値：Sidebar 用 Page entry と実ファイルは維持され、Canvas 対象だけから外れる（Then）
        #expect(store.selectedChapterPages.map(\.internalID) == [page.internalID])
        #expect(store.selectedCanvasPages.isEmpty)
        #expect(hiddenProject.project.chapters[0].pages[0].isCanvasHidden)
        #expect(try Data(contentsOf: fixture.htmlURL) == originalHTML)
        #expect(try Data(contentsOf: companionCSSURL) == originalCSS)

        store.setPageCanvasHidden(internalID: page.internalID, hidden: false)
        #expect(store.selectedCanvasPages.map(\.internalID) == [page.internalID])
        #expect(store.loadedProject?.project.chapters[0].pages[0].isCanvasHidden == false)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: Chapter一覧非表示テスト
    /// 概要: Chapter を Sidebar の一覧から隠しても、Chapter と Page のキャンバス内容が `.ogp` に残ることを確認します。
    @Test("Chapterを一覧から隠してもキャンバス内容を保持する")
    func testHideChapterFromSidebarPreservesCanvasContents() throws {
        // コンディション：Page を持つ2つの Chapter を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html><html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Visibility Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapter-main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "page-home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    internalID: "chapter-docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "docs",
                            internalID: "page-docs",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 200, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let mainChapterInternalID = try #require(store.loadedProject?.project.chapters[0].internalID)
        let mainPageInternalID = try #require(store.loadedProject?.project.chapters[0].pages[0].internalID)
        let docsChapterInternalID = try #require(store.loadedProject?.project.chapters[1].internalID)
        let docsPageInternalID = try #require(store.loadedProject?.project.chapters[1].pages[0].internalID)

        // 検証内容：現在選択中の Main Chapter を一覧から非表示にする（When）
        store.hideChapterFromSidebar(internalID: mainChapterInternalID)
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project

        // 期待値：Main の内容は残り、表示対象だけが次の可視 Chapter へ切り替わる（Then）
        #expect(persistedProject.chapters.count == 2)
        #expect(persistedProject.chapters[0].isSidebarHidden)
        #expect(persistedProject.chapters[0].pages.map(\.internalID) == [mainPageInternalID])
        #expect(persistedProject.chapters[0].pages[0].canvas.width == 100)
        #expect(store.selectedChapterInternalID == docsChapterInternalID)
        #expect(store.selectedCanvasPages.map(\.internalID) == [docsPageInternalID])
        #expect(FileManager.default.fileExists(atPath: fixture.htmlURL.path))
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: Page完全削除安全条件テスト
    /// 概要: 同じ HTML path が `.ogp` 内の別配置でも使われている場合に完全削除を無効化することを確認します。
    @Test("別配置で使われるPageは完全削除できない")
    func testCanPermanentlyDeletePageRejectsDuplicatePlacement() throws {
        // コンディション：同じ index.html を2つの Page entry で配置した project を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let project = OpenGraphiteProject(
            version: "1",
            name: "Duplicate Placement Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapter-main",
                    pages: [
                        OpenGraphitePage(
                            id: "home-desktop",
                            internalID: "page-desktop",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        ),
                        OpenGraphitePage(
                            id: "home-mobile",
                            internalID: "page-mobile",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 200, y: 0, width: 50, height: 100)
                        )
                    ]
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let desktopPageInternalID = try #require(store.loadedProject?.project.chapters[0].pages[0].internalID)
        let mobilePageInternalID = try #require(store.loadedProject?.project.chapters[0].pages[1].internalID)

        // 検証内容：一方の Page について完全削除可否を判定し、削除も試行する（When）
        let canDelete = store.canPermanentlyDeletePage(internalID: desktopPageInternalID)
        store.permanentlyDeletePage(internalID: desktopPageInternalID)
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project

        // 期待値：完全削除は拒否され、両配置と HTML が維持される（Then）
        #expect(canDelete == false)
        #expect(
            persistedProject.chapters[0].pages.map(\.internalID)
                == [desktopPageInternalID, mobilePageInternalID]
        )
        #expect(FileManager.default.fileExists(atPath: fixture.htmlURL.path))
        #expect(store.lastError?.contains("別の配置でも使われている") == true)
    }

    /// 論理名（日本語）: Page完全削除テスト
    /// 概要: 他に配置されていない Page の entry、参照配置、HTML、同名 companion CSS を完全に削除できることを確認します。
    @Test("単独配置のPageをHTMLとCSSごと完全に削除できる")
    func testPermanentlyDeletePageRemovesManifestAndSourceFiles() throws {
        // コンディション：単独配置の Page と同名 companion CSS を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try fixture.writeCompanionCSS("body { color: red; }")
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        var project = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let pageInternalID = try #require(project.chapters[0].pages.first?.internalID)
        let chapterInternalID = project.chapters[0].internalID
        let pageNodeReference = OpenGraphiteCanvasReference(
            internalID: "page-node-reference",
            referenceID: OpenGraphiteReferenceID.node(
                chapterID: chapterInternalID,
                pageID: pageInternalID,
                nodeID: "page-root"
            ).stringValue,
            x: 10,
            y: 20
        )
        project.chapters[0].references = [pageNodeReference]
        project.collections = [
            OpenGraphiteComponentCollection(
                id: "main",
                internalID: "collection-main",
                components: [],
                references: [pageNodeReference]
            )
        ]
        try JSONEncoder().encode(project).write(to: fixture.projectURL, options: .atomic)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        #expect(store.canPermanentlyDeletePage(internalID: pageInternalID))

        // 検証内容：Page を完全削除する（When）
        store.permanentlyDeletePage(internalID: pageInternalID)
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project

        // 期待値：manifest と実ファイルから削除され、Chapter 自体は空で維持される（Then）
        #expect(persistedProject.chapters.count == 1)
        #expect(persistedProject.chapters[0].pages.isEmpty)
        #expect(persistedProject.chapters[0].references.isEmpty)
        #expect(persistedProject.collections[0].references.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.htmlURL.path))
        #expect(!FileManager.default.fileExists(atPath: companionCSSURL.path))
        #expect(store.selectedChapterPages.isEmpty)
        #expect(store.selectedPage == nil)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 空ChapterへのPage追加保存テスト
    /// 概要: 選択中の空 Chapter に新しい HTML page file と page entry を追加し、その page が選択されることを検証します。
    @Test("空ChapterにPageを追加してogpへ保存できる")
    func testAddPagePersistsHTMLAndManifestInSelectedEmptyChapter() throws {
        // コンディション：空 Chapter を追加して選択中にする（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.addChapter()

        // 検証内容：選択中 Chapter へ page を追加する（When）
        store.addPage()

        // 期待値：新規 HTML と空 companion CSS が作成され、空 Chapter だった場所に page entry が保存される（Then）
        let addedPage = try #require(store.selectedPage)
        let addedChapter = try #require(store.selectedChapter)
        let addedHTMLURL = fixture.publicURL.appendingPathComponent("page-1.html")
        let addedCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: addedHTMLURL)
        let addedHTML = try String(contentsOf: addedHTMLURL, encoding: .utf8)
        let addedCSS = try String(contentsOf: addedCompanionCSSURL, encoding: .utf8)

        #expect(addedChapter.id == "chapter-1")
        #expect(addedPage.id == "page-1")
        #expect(addedPage.displayName == "page-1.html")
        #expect(addedPage.path == "page-1.html")
        #expect(addedPage.title == nil)
        #expect(addedPage.canvas.x == 0)
        #expect(addedPage.canvas.y == 0)
        #expect(addedPage.canvas.width == 100)
        #expect(addedPage.canvas.height == 100)
        #expect(FileManager.default.fileExists(atPath: addedHTMLURL.path))
        #expect(FileManager.default.fileExists(atPath: addedCompanionCSSURL.path))
        #expect(addedHTML.contains("<title>page-1.html</title>"))
        #expect(addedHTML.contains(#"<main id="page-1-root""#))
        #expect(addedHTML.contains(#"data-og-internal-id=""#))
        #expect(!addedHTML.contains("data-og-type"))
        #expect(addedCSS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.lastError == nil)

        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        #expect(reloadedProject.project.chapters[0].pages.map(\.id) == ["home"])
        #expect(reloadedProject.project.chapters[1].pages.map(\.id) == ["page-1"])
        #expect(reloadedProject.project.chapters[1].pages[0].internalID == addedPage.internalID)
    }

    /// 論理名（日本語）: 新規Page root色保存テスト
    /// 概要: 新規追加した page の初期 companion CSS が空でも、ユーザー操作で page root の色だけを保存できることを検証します。
    @Test("新規Page rootはユーザー操作でcolorを保存できる")
    func testAddedPageRootPersistsColorByUserOperation() async throws {
        // コンディション：空 Chapter へ新規 page を追加し、生成直後の companion CSS が空であることを確認する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.addChapter()
        store.addPage()
        let addedHTMLURL = fixture.publicURL.appendingPathComponent("page-1.html")
        let addedCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: addedHTMLURL)
        let addedHTML = try String(contentsOf: addedHTMLURL, encoding: .utf8)
        let rootNode = try #require(
            OpenGraphiteHTMLDocument(html: addedHTML).nodes().first { $0.tagName == "main" }
        )
        let initialCSS = try String(contentsOf: addedCompanionCSSURL, encoding: .utf8)
        #expect(initialCSS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // 検証内容：Inspector 相当の操作で page root の color を更新する（When）
        await store.ingestNodePayloadAndWait([
            [
                "id": rootNode.internalID,
                "internalID": rootNode.internalID,
                "tagName": rootNode.tagName,
                "legacyTypeHint": rootNode.legacyTypeHint ?? "",
                "capabilities": rootNode.capabilities.map(\.rawValue),
                "capabilityEvidence": Self.capabilityEvidencePayload(rootNode.capabilityEvidence),
                "attributes": rootNode.attributes,
                "layout": rootNode.layout ?? "",
                "cssVariables": ["color": "rgb(244, 246, 247)"],
                "depth": rootNode.depth
            ]
        ])
        store.selectNode(id: rootNode.internalID)
        let initialReloadToken = store.reloadToken(for: addedHTMLURL)
        store.updateCSSVariable(key: "color", value: "#123456")
        store.updateCSSVariable(key: "color", value: "#654321")

        // 期待値：ユーザーが指定した color だけが companion CSS に保存される（Then）
        let updatedCSS = try String(contentsOf: addedCompanionCSSURL, encoding: .utf8)
        #expect(store.nodes.first?.cssVariables["color"] == "#654321")
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: addedHTMLURL) == initialReloadToken + 2)
        #expect(updatedCSS.contains("color: #654321;"))
        #expect(!updatedCSS.contains("color: #123456;"))
        #expect(!updatedCSS.contains("background:"))
        #expect(!updatedCSS.contains("min-height:"))
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 新規Page root CSSパラメータ保存テスト
    /// 概要: 新規追加した page root で、Inspector に表示される主要 CSS declaration を初期 CSS なしで保存できることを検証します。
    @Test("新規Page rootはInspectorの主要CSSパラメータを保存できる")
    func testAddedPageRootPersistsInspectorCSSParametersByUserOperation() async throws {
        // コンディション：空 Chapter へ新規 page を追加し、表示由来の既定 CSS 値を payload として取り込む（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.addChapter()
        store.addPage()
        let addedHTMLURL = fixture.publicURL.appendingPathComponent("page-1.html")
        let addedCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: addedHTMLURL)
        let addedHTML = try String(contentsOf: addedHTMLURL, encoding: .utf8)
        let rootNode = try #require(
            OpenGraphiteHTMLDocument(html: addedHTML).nodes().first { $0.tagName == "main" }
        )
        let cases: [(key: String, displayedValue: String, savedValue: String)] = [
            ("align-items", "stretch", "center"),
            ("justify-content", "flex-start", "center"),
            ("gap", "0px", "12px"),
            ("padding", "0px", "16px"),
            ("margin", "0px", "4px"),
            ("flex", "0 1 auto", "1 1 auto"),
            ("position", "static", "relative"),
            ("top", "auto", "10px"),
            ("right", "auto", "20px"),
            ("bottom", "auto", "30px"),
            ("left", "auto", "40px"),
            ("z-index", "auto", "2"),
            ("width", "auto", "720px"),
            ("height", "auto", "480px"),
            ("min-width", "0px", "320px"),
            ("min-height", "0px", "240px"),
            ("max-width", "none", "960px"),
            ("border-radius", "0px", "8px"),
            ("border", "0px solid transparent", "1px solid #123456"),
            ("background", "transparent", "#101820"),
            ("box-shadow", "none", "0 2px 8px rgba(0,0,0,0.2)"),
            ("transform-origin", "center center", "left top"),
            ("scale", "1 1", "1.2 0.8"),
            ("animation-name", "none", "fade-in"),
            ("animation-duration", "0s", "300ms"),
            ("animation-delay", "0s", "50ms"),
            ("animation-timing-function", "ease", "linear"),
            ("animation-iteration-count", "1", "2"),
            ("animation-fill-mode", "none", "both"),
            ("animation-direction", "normal", "alternate"),
            ("animation-play-state", "running", "paused"),
            ("animation", "none", "fade-in 300ms ease both"),
            ("animation-timeline", "auto", "view()"),
            ("animation-range-start", "normal", "entry 0%"),
            ("animation-range-end", "normal", "exit 100%"),
            ("animation-range", "normal", "entry 0% exit 100%"),
            ("timeline-scope", "none", "--page-scroll"),
            ("scroll-timeline-name", "none", "--page-scroll"),
            ("scroll-timeline-axis", "block", "y"),
            ("scroll-timeline", "none", "--page-scroll y"),
            ("view-timeline-name", "none", "--page-view"),
            ("view-timeline-axis", "block", "y"),
            ("view-timeline-inset", "auto", "10% 20%"),
            ("view-timeline", "none", "--page-view y")
        ]
        let displayedVariables = Dictionary(uniqueKeysWithValues: cases.map { ($0.key, $0.displayedValue) })
        await store.ingestNodePayloadAndWait([
            [
                "id": rootNode.internalID,
                "internalID": rootNode.internalID,
                "tagName": rootNode.tagName,
                "legacyTypeHint": rootNode.legacyTypeHint ?? "",
                "capabilities": rootNode.capabilities.map(\.rawValue),
                "capabilityEvidence": Self.capabilityEvidencePayload(rootNode.capabilityEvidence),
                "attributes": rootNode.attributes,
                "layout": rootNode.layout ?? "",
                "cssVariables": displayedVariables,
                "depth": rootNode.depth
            ]
        ])
        store.selectNode(id: rootNode.internalID)
        let initialReloadToken = store.reloadToken(for: addedHTMLURL)

        // 検証内容：Inspector 相当の操作で各 CSS declaration を順に更新する（When）
        for item in cases {
            store.updateCSSVariable(key: item.key, value: item.savedValue)
        }

        // 期待値：各 declaration が companion CSS へ保存され、未保存の表示値が競合扱いされない（Then）
        let updatedCSS = try String(contentsOf: addedCompanionCSSURL, encoding: .utf8)
        for item in cases {
            #expect(store.nodes.first?.cssVariables[item.key] == item.savedValue)
            #expect(updatedCSS.contains("\(item.key): \(item.savedValue);"))
        }
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: addedHTMLURL) == initialReloadToken + cases.count)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 既存HTMLのPage追加保存テスト
    /// 概要: `htmlRoot` 配下にある既存 HTML file を選択中 Chapter の page entry として追加できることを検証します。
    @Test("既存HTMLをPageとしてogpへ追加できる")
    func testAddExistingPagePersistsManifestInSelectedChapter() throws {
        // コンディション：空 Chapter を追加して選択中にし、public 配下に未登録 HTML を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let existingHTMLURL = fixture.publicURL.appendingPathComponent("landing.html")
        let existingCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: existingHTMLURL)
        try "<!doctype html>\n<html><body>landing</body></html>".write(
            to: existingHTMLURL,
            atomically: true,
            encoding: .utf8
        )
        try """
        body {
          color: rgb(20, 20, 20);
        }
        """.write(to: existingCompanionCSSURL, atomically: true, encoding: .utf8)
        let originalHTML = try String(contentsOf: existingHTMLURL, encoding: .utf8)
        let originalCSS = try String(contentsOf: existingCompanionCSSURL, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.addChapter()

        // 検証内容：既存 HTML を page entry として追加する（When）
        store.addExistingPage(at: existingHTMLURL)

        // 期待値：HTML file はそのまま、選択中 Chapter の `.ogp` pages に登録される（Then）
        let addedPage = try #require(store.selectedPage)
        let addedChapter = try #require(store.selectedChapter)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let finalHTML = try String(contentsOf: existingHTMLURL, encoding: .utf8)
        let finalCSS = try String(contentsOf: existingCompanionCSSURL, encoding: .utf8)

        #expect(addedChapter.id == "chapter-1")
        #expect(addedPage.id == "landing")
        #expect(addedPage.path == "landing.html")
        #expect(addedPage.displayName == "landing.html")
        #expect(addedPage.canvas.x == 0)
        #expect(addedPage.canvas.y == 0)
        #expect(addedPage.canvas.width == 100)
        #expect(addedPage.canvas.height == 100)
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
        #expect(!finalHTML.contains("--og-edit-width"))
        #expect(!finalHTML.contains("--og-edit-min-height"))
        #expect(!finalCSS.contains("--og-edit-width"))
        #expect(!finalCSS.contains("--og-edit-min-height"))
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.lastError == nil)
        #expect(reloadedProject.project.chapters[0].pages.map(\.id) == ["home"])
        #expect(reloadedProject.project.chapters[1].pages.map(\.id) == ["landing"])
        #expect(reloadedProject.project.chapters[1].pages[0].internalID == addedPage.internalID)
    }

    /// 論理名（日本語）: 既存HTML追加時のCSS非作成テスト
    /// 概要: OpenGraphite 導入前の既存 HTML を page entry として追加しても、同名 companion CSS を自動作成しないことを検証します。
    @Test("既存HTML追加はcompanion CSSを自動作成しない")
    func testAddExistingPageDoesNotCreateCompanionCSS() throws {
        // コンディション：companion CSS を持たない既存 HTML を public 配下に用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let existingHTMLURL = fixture.publicURL.appendingPathComponent("archive.html")
        let existingCompanionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: existingHTMLURL)
        let originalHTML = "<!doctype html>\n<html><body>archive</body></html>"
        try originalHTML.write(to: existingHTMLURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.addChapter()
        #expect(!FileManager.default.fileExists(atPath: existingCompanionCSSURL.path))

        // 検証内容：既存 HTML を page entry として追加する（When）
        store.addExistingPage(at: existingHTMLURL)

        // 期待値：manifest 追加だけが行われ、HTML と companion CSS は永続化されない（Then）
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        #expect(reloadedProject.project.chapters[1].pages.map(\.path) == ["archive.html"])
        #expect(try String(contentsOf: existingHTMLURL, encoding: .utf8) == originalHTML)
        #expect(!FileManager.default.fileExists(atPath: existingCompanionCSSURL.path))
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 既存HTML重複追加拒否テスト
    /// 概要: すでに登録済みの HTML path を既存 Page として追加しようとした場合に `.ogp` を変更しないことを検証します。
    @Test("既存HTML追加は登録済みpathを拒否する")
    func testAddExistingPageRejectsDuplicatePath() throws {
        // コンディション：index.html が既に登録済みの project を開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：登録済み HTML を再追加する（When）
        store.addExistingPage(at: fixture.htmlURL)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)

        // 期待値：エラーが表示され、manifest の pages は増えない（Then）
        #expect(store.lastError == "同じ HTML path が既に登録されています: index.html")
        #expect(reloadedProject.project.allPages.map(\.path) == ["index.html"])
    }

    /// 論理名（日本語）: Pageファイル名更新テスト
    /// 概要: Sidebar のインライン編集から Page HTML と同名 companion CSS を rename し、`.ogp` path へ保存できることを検証します。
    @Test("Pageファイル名を変更するとHTMLとcompanion CSSとogp pathが同期する")
    func testUpdatePageFilenameMovesHTMLAndCompanionCSSAndPersistsPath() throws {
        // コンディション：既存 Page と companion CSS を持つ一時プロジェクトを開き、先頭 Page を選択する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        try fixture.writeCompanionCSS("body { color: red; }")
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)

        // 検証内容：拡張子を省略して Page ファイル名を更新する（When）
        store.updatePageFilename(internalID: page.internalID, segment: .pages, value: " home-draft ")
        let renamedHTMLURL = fixture.publicURL.appendingPathComponent("home-draft.html")
        let renamedCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: renamedHTMLURL)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let renamedPage = try #require(reloadedProject.project.chapters.first?.pages.first)

        // 期待値：実ファイルと `.ogp` path が同時に更新され、表示名はファイル名と一致する（Then）
        #expect(store.selectedPage?.displayName == "home-draft.html")
        #expect(store.selectedPage?.path == "home-draft.html")
        #expect(renamedPage.path == "home-draft.html")
        #expect(renamedPage.title == nil)
        #expect(store.selectedPageInternalID == page.internalID)
        #expect(FileManager.default.fileExists(atPath: renamedHTMLURL.path))
        #expect(FileManager.default.fileExists(atPath: renamedCSSURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.htmlURL.path))
        #expect(!FileManager.default.fileExists(atPath: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL).path))
        #expect(try String(contentsOf: renamedHTMLURL, encoding: .utf8) == originalHTML)
        #expect(try String(contentsOf: renamedCSSURL, encoding: .utf8) == "body { color: red; }")
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: Pageファイル名重複拒否テスト
    /// 概要: Sidebar のインライン編集で既存 Page path と重複するファイル名を指定した場合、実ファイルも `.ogp` も変更しないことを検証します。
    @Test("Pageファイル名変更は既存pathとの重複を拒否する")
    func testUpdatePageFilenameRejectsDuplicatePath() throws {
        // コンディション：2つの Page HTML を持つ一時プロジェクトを開き、先頭 Page を選択する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsHTMLURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(to: docsHTMLURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(pages: [
            OpenGraphitePage(
                id: "home",
                path: "index.html",
                canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
            ),
            OpenGraphitePage(
                id: "docs",
                path: "docs.html",
                canvas: OpenGraphiteCanvas(x: 200, y: 0, width: 100, height: 100)
            )
        ])
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)

        // 検証内容：既存 path と同じファイル名へ変更しようとする（When）
        store.updatePageFilename(internalID: page.internalID, segment: .pages, value: "docs.html")
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let firstPage = try #require(reloadedProject.project.chapters.first?.pages.first)

        // 期待値：変更は拒否され、元 HTML と docs HTML はそのまま残る（Then）
        #expect(firstPage.path == "index.html")
        #expect(store.selectedPage?.displayName == "index.html")
        #expect(FileManager.default.fileExists(atPath: fixture.htmlURL.path))
        #expect(FileManager.default.fileExists(atPath: docsHTMLURL.path))
        #expect(store.lastError?.contains("既に登録されています") == true)
    }

    /// 論理名（日本語）: Componentファイル名参照更新テスト
    /// 概要: Component master の HTML ファイル名を変更した場合、参照元 Page の component link と同名 CSS link も更新されることを検証します。
    @Test("Componentファイル名変更は参照元HTMLのcomponent linkとCSS linkも更新する")
    func testUpdateComponentFilenameRewritesReferencingLinks() throws {
        // コンディション：component master と、それを link 参照する Page HTML を持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentHTMLURL = componentDirectory.appendingPathComponent("design-system.html")
        let componentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentHTMLURL)
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try "<!doctype html>\n<html><body>component</body></html>".write(to: componentHTMLURL, atomically: true, encoding: .utf8)
        try "body { color: blue; }".write(to: componentCSSURL, atomically: true, encoding: .utf8)
        try """
        <!doctype html>
        <html>
          <head>
            <link rel="stylesheet" href="./_components/design-system.css">
          </head>
          <body>
            <link rel="opengraphite-components" href="./_components/design-system.html">
            <og-instance data-og-component="site-header"></og-instance>
          </body>
        </html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(x: 200, y: 0, width: 100, height: 100)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.selectComponentsSegment()
        let component = try #require(store.componentPages.first)
        store.selectComponentPage(internalID: component.internalID)
        let initialPageReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：Component ファイル名を拡張子なしで変更する（When）
        store.updatePageFilename(internalID: component.internalID, segment: .components, value: "tokens")
        let renamedComponentHTMLURL = componentDirectory.appendingPathComponent("tokens.html")
        let renamedComponentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: renamedComponentHTMLURL)
        let updatedPageHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let renamedComponent = try #require(reloadedProject.project.components.first)

        // 期待値：component 実ファイル、同名 CSS、`.ogp` path、参照元 link が同時に更新される（Then）
        #expect(renamedComponent.path == "_components/tokens.html")
        #expect(renamedComponent.title == nil)
        #expect(store.selectedPage?.displayName == "tokens.html")
        #expect(FileManager.default.fileExists(atPath: renamedComponentHTMLURL.path))
        #expect(FileManager.default.fileExists(atPath: renamedComponentCSSURL.path))
        #expect(!FileManager.default.fileExists(atPath: componentHTMLURL.path))
        #expect(!FileManager.default.fileExists(atPath: componentCSSURL.path))
        #expect(updatedPageHTML.contains(#"href="_components/tokens.html""#))
        #expect(updatedPageHTML.contains(#"href="_components/tokens.css""#))
        #expect(!updatedPageHTML.contains("design-system.html"))
        #expect(!updatedPageHTML.contains("design-system.css"))
        #expect(store.reloadToken(for: fixture.htmlURL) == initialPageReloadToken + 1)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: Project資源選択テスト
    /// 概要: Project セグメントの実装資源選択が Canvas の表示対象を維持し、通常ページ選択へ戻ると解除されることを確認します。
    @Test("Project資源選択はCanvas選択と分離される")
    func testSelectProjectResourceKeepsCanvasSelectionAndClearsOnPageSelection() throws {
        // コンディション：プロジェクトを開き、先頭ページが選択されている状態を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let selectedPage = try selectFirstPage(in: store)
        let selectedPageInternalID = selectedPage.internalID

        // 検証内容：Project の i18n runtime を選択してからページを再選択する（When）
        store.selectProjectResource(.i18nRuntime)
        let selectedWhileProjectResource = store.selectedPageID
        store.selectPagesSegment()
        let projectResourceAfterSegmentSelection = store.selectedProjectResource
        store.selectProjectResource(.i18nRuntime)
        store.selectPage(internalID: selectedPageInternalID)

        // 期待値：Project 選択中も Canvas の page は維持され、ページ選択で Project 資源選択だけ解除される（Then）
        #expect(selectedWhileProjectResource == "home")
        #expect(projectResourceAfterSegmentSelection == nil)
        #expect(store.selectedCanvasSegment == .pages)
        #expect(store.selectedPageID == "home")
        #expect(store.selectedProjectResource == nil)
    }

    /// 論理名（日本語）: 同一ページ再選択時のノード保持テスト
    /// 概要: 左カラムで同じ HTML カードを再度開いたとき、収集済み DOM ノード一覧が空にならないことを検証します。
    @Test("同じページの再選択ではノード一覧を保持する")
    func testSelectPagePreservesNodesWhenSelectingSamePageAgain() throws {
        // コンディション：プロジェクトを開き、選択ページの DOM ノード一覧が収集済みの状態を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：左カラムで同じページカードを再選択する想定で内部 ID による selectPage を再実行する（When）
        let selectedPageInternalID = try #require(store.selectedPage?.internalID)
        store.selectPage(internalID: selectedPageInternalID)

        // 期待値：ページ内ノード一覧は保持され、ノード選択だけが解除される（Then）
        #expect(store.selectedPageID == "home")
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.map(\.id) == ["title"])
        #expect(store.statusMessage == "index.html を表示しています。")
    }

    /// 論理名（日本語）: 同一Chapter再選択時のページ選択解除テスト
    /// 概要: Chapters パネルで現在の Chapter を押すと、HTML カード未選択へ戻ることを検証します。
    @Test("同じChapterの再選択ではページ選択を解除する")
    func testSelectChapterClearsPageSelectionWhenSelectingSameChapter() throws {
        // コンディション：プロジェクトを開き、選択ページの DOM ノード一覧が収集済みの状態を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：Chapters パネルで現在の Chapter を再選択する想定で selectChapter を再実行する（When）
        let selectedChapterInternalID = try #require(store.selectedChapter?.internalID)
        store.selectChapter(internalID: selectedChapterInternalID)

        // 期待値：page と node の選択は解除され、Chapter 階層だけが表示対象になる（Then）
        #expect(store.selectedPageID == nil)
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.isEmpty)
        #expect(store.statusMessage == "Main を表示しています。")
    }

    /// 論理名（日本語）: 選択ページキャンバス配置保存テスト
    /// 概要: 選択中ページの座標と解像度が Store と `.ogp` に保存されることを検証します。
    @Test("選択ページのキャンバス配置をogpへ保存する")
    func testUpdateSelectedPageCanvasPersistsManifest() throws {
        // Given: 一時プロジェクトを開き、選択ページの新しい配置値を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let expectedCanvas = OpenGraphiteCanvas(x: 24, y: -12, width: 390, height: 844)

        // When: 選択ページのキャンバス配置を更新する
        store.updateSelectedPageCanvas(
            x: expectedCanvas.x,
            y: expectedCanvas.y,
            width: expectedCanvas.width,
            height: expectedCanvas.height
        )

        // Then: Store とディスク上の `.ogp` が同じ配置値になる
        #expect(store.selectedPage?.canvas == expectedCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas == expectedCanvas)
        #expect(store.statusMessage.contains("キャンバス配置を更新"))
    }

    /// 論理名（日本語）: 選択ページキャンバス配置名保存テスト
    /// 概要: 選択中ページの任意配置名が Store と `.ogp` に保存され、座標だけの更新では保持されることを検証します。
    @Test("選択ページのキャンバス配置名をogpへ保存する")
    func testUpdateSelectedPageCanvasPersistsName() throws {
        // Given: 一時プロジェクトを開き、フロー解決用の配置名を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)

        // When: 選択ページの配置名とキャンバス配置を更新する
        store.updateSelectedPageCanvas(x: 24, y: -12, width: 390, height: 844, name: " mobile ")

        // Then: Store とディスク上の `.ogp` が trim 済み配置名を保持する
        #expect(store.selectedPage?.canvas.name == "mobile")
        var reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        var persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.name == "mobile")

        // When: 従来の座標更新 API で配置だけを更新する
        store.updateSelectedPageCanvas(x: 40, y: 0, width: 414, height: 896)

        // Then: 既存の配置名は消えずに保持される
        #expect(store.selectedPage?.canvas.name == "mobile")
        reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.name == "mobile")
        #expect(persistedPage.canvas.width == 414)
    }

    /// 論理名（日本語）: 選択ページMock State保存テスト
    /// 概要: 選択中ページの preview Mock State が Store と `.ogp` に保存され、座標だけの更新では保持されることを検証します。
    @Test("選択ページのMock Stateをogpへ保存する")
    func testUpdateSelectedPageCanvasPersistsPreviewContext() throws {
        // コンディション：一時プロジェクトを開き、preview Mock State を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let expectedContext = OpenGraphitePreviewContext(fieldMocks: ["selectedLanguage": "ja"])

        // 検証内容：選択ページの Mock State とキャンバス配置を更新する（When）
        store.updateSelectedPageCanvas(
            x: 24,
            y: -12,
            width: 390,
            height: 844,
            name: "Desktop",
            previewContext: expectedContext
        )

        // 期待値：Store とディスク上の `.ogp` が同じ Mock State を保持する（Then）
        #expect(store.selectedPage?.canvas.previewContext == expectedContext)
        var reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        var persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.previewContext == expectedContext)

        // 検証内容：従来の座標更新 API で配置だけを更新する（When）
        store.updateSelectedPageCanvas(x: 40, y: 0, width: 414, height: 896)

        // 期待値：既存の Mock State は消えずに保持される（Then）
        reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.previewContext == expectedContext)
        #expect(persistedPage.canvas.width == 414)
    }

    /// 論理名（日本語）: 選択ページキャンバス位置保存テスト
    /// 概要: ドラッグ確定用の位置更新で、解像度、配置名、preview Mock State が維持されることを検証します。
    @Test("選択ページのキャンバス位置だけをogpへ保存する")
    func testUpdateSelectedPageCanvasPositionPreservesCanvasMetadata() throws {
        // コンディション：一時プロジェクトを開き、配置名と Mock State を含む canvas を保存しておく（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let previewContext = OpenGraphitePreviewContext(fieldMocks: ["selectedLanguage": "ja"])
        store.updateSelectedPageCanvas(
            x: 10,
            y: 20,
            width: 390,
            height: 844,
            name: "Desktop",
            previewContext: previewContext
        )

        // 検証内容：位置だけを更新する（When）
        store.updateSelectedPageCanvasPosition(x: 120, y: -32)

        // 期待値：x/y だけが更新され、既存 metadata は維持される（Then）
        let expectedCanvas = OpenGraphiteCanvas(
            name: "Desktop",
            x: 120,
            y: -32,
            width: 390,
            height: 844,
            previewContext: previewContext
        )
        #expect(store.selectedPage?.canvas == expectedCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas == expectedCanvas)
        #expect(store.statusMessage.contains("キャンバス位置を更新"))
    }

    /// 論理名（日本語）: Componentキャンバス位置保存テスト
    /// 概要: Components セグメントの component canvas でも、ドラッグ確定用の位置更新が `.ogp` に保存されることを検証します。
    @Test("Component canvasの位置だけをogpへ保存する")
    func testUpdateSelectedPageCanvasPositionPersistsComponentCanvas() throws {
        // コンディション：page と component canvas を持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let previewContext = OpenGraphitePreviewContext(fieldMocks: ["variant": "compact"])
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(
                        name: "Desktop",
                        x: 200,
                        y: 16,
                        width: 1180,
                        height: 900,
                        previewContext: previewContext
                    )
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.selectComponentsSegment()
        let component = try #require(store.componentPages.first)
        store.selectComponentPage(internalID: component.internalID)

        // 検証内容：Components セグメントで選択中の component canvas の位置だけを更新する（When）
        store.updateSelectedPageCanvasPosition(x: 320, y: -48)

        // 期待値：component canvas の x/y だけが更新され、page canvas と component metadata は維持される（Then）
        let expectedComponentCanvas = OpenGraphiteCanvas(
            name: "Desktop",
            x: 320,
            y: -48,
            width: 1180,
            height: 900,
            previewContext: previewContext
        )
        #expect(store.selectedCanvasSegment == .components)
        #expect(store.selectedPage?.canvas == expectedComponentCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.chapters.first?.pages.first)
        let persistedComponent = try #require(reloadedProject.project.components.first)
        #expect(persistedPage.canvas == OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100))
        #expect(persistedComponent.canvas == expectedComponentCanvas)
    }

    /// 論理名（日本語）: キャンバスガイド永続化テスト
    /// 概要: Pages / Components のガイド追加・移動・削除が `.ogp` だけへ保存されることを検証します。
    @Test("guideをChapterとCollectionのogpデータへ保存する")
    func testCanvasGuidesPersistToSelectedProjectContainers() throws {
        // コンディション：Chapter、Collection、HTML、companion CSSを持つprojectを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        var project = try ProjectLoader().loadProject(at: fixture.projectURL).project
        project.collections = [
            OpenGraphiteComponentCollection(
                id: "components",
                internalID: "collection-opaque",
                title: "Components",
                components: []
            )
        ]
        try JSONEncoder().encode(project).write(to: fixture.projectURL, options: .atomic)
        try fixture.writeCompanionCSS("body { color: #202020; }")
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        let originalHTML = try Data(contentsOf: fixture.htmlURL)
        let originalCSS = try Data(contentsOf: cssURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：Chapterでguideを追加・移動し、Collectionでは追加・移動・削除を行う（When）
        let chapterGuideID = try #require(store.addCanvasGuide(orientation: .vertical, position: 320))
        store.updateCanvasGuide(id: chapterGuideID, position: 640)
        #expect(store.addCanvasGuide(orientation: .vertical, position: .infinity) == nil)
        store.selectCollection(internalID: "collection-opaque")
        let collectionGuideID = try #require(store.addCanvasGuide(orientation: .horizontal, position: -48))
        store.updateCanvasGuide(id: collectionGuideID, position: -96)
        let deletedGuideID = try #require(store.addCanvasGuide(orientation: .vertical, position: 100))
        store.deleteCanvasGuide(id: deletedGuideID)
        let reloaded = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let chapterGuide = try #require(reloaded.chapters.first?.guides.first)
        let collectionGuide = try #require(reloaded.collections.first?.guides.first)

        // 期待値：containerごとのguideだけがogpへ残り、HTMLとCSSはbyte単位で維持される（Then）
        #expect(chapterGuide.internalID == chapterGuideID)
        #expect(chapterGuide.orientation == .vertical)
        #expect(chapterGuide.position == 640)
        #expect(reloaded.collections.first?.guides.count == 1)
        #expect(collectionGuide.internalID == collectionGuideID)
        #expect(collectionGuide.orientation == .horizontal)
        #expect(collectionGuide.position == -96)
        #expect(store.selectedCanvasGuides == [collectionGuide])
        #expect(try Data(contentsOf: fixture.htmlURL) == originalHTML)
        #expect(try Data(contentsOf: cssURL) == originalCSS)
    }

    /// 論理名（日本語）: キャンバスガイドUndo/Redoテスト
    /// 概要: ガイドの追加・移動・削除をそれぞれ一操作として取り消し、やり直せることを検証します。
    @Test("guideの追加移動削除を取り消してやり直せる")
    func testCanvasGuideChangesSupportUndoAndRedo() throws {
        // コンディション：ガイドのないChapterを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：追加・移動・削除の各操作後にUndoとRedoを実行する（When）
        let guideID = try #require(store.addCanvasGuide(orientation: .vertical, position: 120))
        store.undoDocumentChange()
        let guidesAfterAddUndo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.guides
        store.redoDocumentChange()
        let guideAfterAddRedo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.guides.first
        )

        store.updateCanvasGuide(id: guideID, position: 260)
        store.undoDocumentChange()
        let guideAfterMoveUndo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.guides.first
        )
        store.redoDocumentChange()
        let guideAfterMoveRedo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.guides.first
        )

        store.deleteCanvasGuide(id: guideID)
        store.undoDocumentChange()
        let guideAfterDeleteUndo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.guides.first
        )
        store.redoDocumentChange()
        let guidesAfterDeleteRedo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.guides

        // 期待値：各Undoで直前値、各Redoで確定値がcacheとogpへ復元される（Then）
        #expect(guidesAfterAddUndo?.isEmpty == true)
        #expect(guideAfterAddRedo.internalID == guideID)
        #expect(guideAfterAddRedo.position == 120)
        #expect(guideAfterMoveUndo.position == 120)
        #expect(guideAfterMoveRedo.position == 260)
        #expect(guideAfterDeleteUndo.position == 260)
        #expect(guidesAfterDeleteRedo?.isEmpty == true)
        #expect(store.selectedCanvasGuides.isEmpty)
        #expect(store.statusMessage == "キャンバスガイドの変更をやり直しました。")
        #expect(store.canUndo)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: ComponentキャンバスガイドUndo/Redoテスト
    /// 概要: Collectionのガイド履歴がChapterとは独立した対象へ適用されることを検証します。
    @Test("Component canvasのguideを取り消してやり直せる")
    func testComponentCanvasGuideSupportsUndoAndRedo() throws {
        // コンディション：空のCollectionを追加したprojectを開いてComponentsへ切り替える（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        var project = try ProjectLoader().loadProject(at: fixture.projectURL).project
        project.collections = [
            OpenGraphiteComponentCollection(
                id: "components",
                internalID: "collection-guide-history",
                components: []
            )
        ]
        try JSONEncoder().encode(project).write(to: fixture.projectURL, options: .atomic)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.selectCollection(internalID: "collection-guide-history")

        // 検証内容：Collectionへ水平ガイドを追加し、Undo後にRedoする（When）
        let guideID = try #require(store.addCanvasGuide(orientation: .horizontal, position: -96))
        store.undoDocumentChange()
        let guidesAfterUndo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.collections.first?.guides
        store.redoDocumentChange()
        let guideAfterRedo = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.collections.first?.guides.first
        )

        // 期待値：Chapterを変えずCollectionのguidesだけがUndoで消え、Redoで復元される（Then）
        #expect(guidesAfterUndo?.isEmpty == true)
        #expect(guideAfterRedo.internalID == guideID)
        #expect(guideAfterRedo.orientation == .horizontal)
        #expect(guideAfterRedo.position == -96)
        #expect(store.loadedProject?.project.chapters.first?.guides.isEmpty == true)
        #expect(store.selectedCanvasGuides == [guideAfterRedo])
    }

    /// 論理名（日本語）: ガイド・HTML統合履歴テスト
    /// 概要: ガイドとHTMLの変更が同じ時系列へ積まれ、確定順にUndo/Redoされることを検証します。
    @Test("guideとHTMLを同じ履歴時系列で取り消してやり直す")
    func testCanvasGuideAndHTMLUseUnifiedHistoryTimeline() throws {
        // コンディション：ガイド追加後に同じprojectのHTMLを同期する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let editedHTML = "<!doctype html>\n<html><body>guide timeline</body></html>"
        let guideID = try #require(store.addCanvasGuide(orientation: .horizontal, position: -48))
        store.syncCurrentHTML(editedHTML)

        // 検証内容：二回Undoした後に二回Redoする（When）
        store.undoDocumentChange()
        let htmlAfterFirstUndo = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let guidesAfterFirstUndo = store.selectedCanvasGuides
        store.undoDocumentChange()
        let guidesAfterSecondUndo = store.selectedCanvasGuides
        store.redoDocumentChange()
        store.redoDocumentChange()

        // 期待値：HTML、ガイドの逆順で戻り、Redoではガイド、HTMLの順で復元される（Then）
        #expect(htmlAfterFirstUndo == initialHTML)
        #expect(guidesAfterFirstUndo.map(\.internalID) == [guideID])
        #expect(guidesAfterSecondUndo.isEmpty)
        #expect(store.selectedCanvasGuides.map(\.internalID) == [guideID])
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == editedHTML)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: ガイド履歴外部競合拒否テスト
    /// 概要: 履歴記録後に同じcontainerのguidesが外部変更された場合、Undoで外部値を上書きしないことを検証します。
    @Test("外部更新されたguide配列へ古い履歴を適用しない")
    func testCanvasGuideUndoRejectsExternallyChangedGuides() throws {
        // コンディション：ガイド追加を履歴へ記録後、storeへ通知せず位置を外部変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let guideID = try #require(store.addCanvasGuide(orientation: .vertical, position: 120))
        var externalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let guideIndex = try #require(externalProject.chapters.first?.guides.firstIndex(where: {
            $0.internalID == guideID
        }))
        externalProject.chapters[0].guides[guideIndex].position = 777
        try JSONEncoder().encode(externalProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：staleなガイド追加履歴を取り消そうとする（When）
        store.undoDocumentChange()
        let persistedGuide = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.guides.first
        )

        // 期待値：外部位置を保持して最新manifestへ表示同期し、無効になった統合履歴を破棄する（Then）
        #expect(persistedGuide.position == 777)
        #expect(store.selectedCanvasGuides.first?.position == 777)
        #expect(store.statusMessage == ".ogp の外部変更を検出したため、キャンバスガイドの履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: キャンバス注釈永続化テスト
    /// 概要: 付箋の本文・フレームと手書きストロークが `.ogp` だけへ保存され、HTML / companion CSS を変更しないことを検証します。
    @Test("付箋と手書きをogpだけへ保存する")
    func testCanvasAnnotationsPersistWithoutChangingHTMLOrCSS() throws {
        // コンディション：HTML と companion CSS を持つ project を開き、保存前の byte 列を保持する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try fixture.writeCompanionCSS(
            """
            body {
              color: #202020;
            }
            """
        )
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        let originalHTML = try Data(contentsOf: fixture.htmlURL)
        let originalCSS = try Data(contentsOf: cssURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let expectedStickyFrame = OpenGraphiteCanvasAnnotationFrame(
            x: 48,
            y: -24,
            width: 300,
            height: 180
        )
        let inkFrame = OpenGraphiteCanvasAnnotationFrame(x: 360, y: 80, width: 120, height: 72)
        let inkStroke = OpenGraphiteInkStroke(
            points: [
                OpenGraphiteInkPoint(x: 0, y: 8, pressure: 0.2, tiltX: -0.1, tiltY: 0.3),
                OpenGraphiteInkPoint(x: 36, y: 20, pressure: 0.75, tiltX: 0.2, tiltY: 0.4)
            ],
            color: "#2458FF",
            lineWidth: 4.5,
            inputDevice: .pen
        )

        // 検証内容：付箋を追加して本文・フレームを更新し、手書き注釈も追加する（When）
        let stickyID = try #require(store.addStickyNote(at: CGPoint(x: 24, y: 12)))
        store.updateCanvasAnnotationText(id: stickyID, text: "この余白を広げる")
        store.updateCanvasAnnotationFrame(id: stickyID, frame: expectedStickyFrame)
        let pageInternalID = try #require(store.loadedProject?.project.chapters.first?.pages.first?.internalID)
        store.selectPage(internalID: pageInternalID)
        store.selectNode(id: "selected-before-ink")
        let inkID = try #require(store.addInkAnnotation(frame: inkFrame, strokes: [inkStroke]))
        let persistedAfterAdd = try ProjectLoader().loadProject(at: fixture.projectURL)
        let annotationsAfterAdd = try #require(persistedAfterAdd.project.chapters.first?.annotations)
        let persistedSticky = try #require(annotationsAfterAdd.first { $0.internalID == stickyID })
        let persistedInk = try #require(annotationsAfterAdd.first { $0.internalID == inkID })

        // 期待値：付箋と手書きの全 payload が追加順で `.ogp` に保存される（Then）
        #expect(annotationsAfterAdd.map(\.internalID) == [stickyID, inkID])
        #expect(persistedSticky.kind == .stickyNote)
        #expect(persistedSticky.text == "この余白を広げる")
        #expect(persistedSticky.frame == expectedStickyFrame)
        #expect(persistedInk.kind == .ink)
        #expect(persistedInk.frame == inkFrame)
        #expect(persistedInk.strokes == [inkStroke])
        #expect(store.selectedCanvasAnnotationID == inkID)
        #expect(store.selectedPage == nil)
        #expect(store.selectedNodeID == nil)

        // 検証内容：付箋だけを削除し、永続ファイルを再度読み込む（When）
        store.deleteCanvasAnnotation(id: stickyID)
        let persistedAfterDelete = try ProjectLoader().loadProject(at: fixture.projectURL)
        let annotationsAfterDelete = try #require(persistedAfterDelete.project.chapters.first?.annotations)
        let finalHTML = try Data(contentsOf: fixture.htmlURL)
        let finalCSS = try Data(contentsOf: cssURL)

        // 期待値：削除も `.ogp` 内だけへ反映され、HTML と CSS の byte 列は完全に維持される（Then）
        #expect(annotationsAfterDelete.map(\.internalID) == [inkID])
        #expect(annotationsAfterDelete.first?.strokes == [inkStroke])
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
    }

    /// 論理名（日本語）: なげわ複数選択操作テスト
    /// 概要: なげわ相当の複数 ID 選択を配列順へ正規化し、選択全体の移動と削除を一度の `.ogp` 更新へ反映することを検証します。
    @Test("なげわ選択した注釈をまとめて移動・削除する")
    func testCanvasAnnotationMultiSelectionMovesAndDeletesAsGroup() throws {
        // コンディション：2枚の付箋と1件の手書きを持つprojectを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try fixture.writeCompanionCSS("body { color: #202020; }")
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        let originalHTML = try Data(contentsOf: fixture.htmlURL)
        let originalCSS = try Data(contentsOf: cssURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let firstStickyID = try #require(store.addStickyNote(at: CGPoint(x: 10, y: 20)))
        let untouchedStickyID = try #require(store.addStickyNote(at: CGPoint(x: 500, y: 40)))
        let inkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: 300, y: 200, width: 80, height: 60),
                strokes: [
                    OpenGraphiteInkStroke(
                        points: [
                            OpenGraphiteInkPoint(x: 4, y: 4),
                            OpenGraphiteInkPoint(x: 72, y: 52)
                        ],
                        inputDevice: .pen
                    )
                ]
            )
        )
        let pageInternalID = try #require(store.loadedProject?.project.chapters.first?.pages.first?.internalID)
        store.selectPage(internalID: pageInternalID)
        store.selectNode(id: "node-before-lasso")

        // 検証内容：未知IDを含む逆順候補から2件を選択し、片方をanchorに同じ差分で移動する（When）
        store.selectCanvasAnnotations(ids: [inkID, "missing", firstStickyID])
        store.moveSelectedCanvasAnnotations(
            anchorID: firstStickyID,
            translation: CGSize(width: 25, height: -10)
        )
        let afterMove = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let movedAnnotations = try #require(afterMove.chapters.first?.annotations)
        let movedSticky = try #require(movedAnnotations.first { $0.internalID == firstStickyID })
        let untouchedSticky = try #require(movedAnnotations.first { $0.internalID == untouchedStickyID })
        let movedInk = try #require(movedAnnotations.first { $0.internalID == inkID })

        // 期待値：現在Canvasの配列順でprimaryと集合が決まり、HTML選択を解除して選択2件だけが移動する（Then）
        #expect(store.selectedCanvasAnnotationIDs == Set([firstStickyID, inkID]))
        #expect(store.selectedCanvasAnnotationID == inkID)
        #expect(store.selectedPage == nil)
        #expect(store.selectedNodeID == nil)
        #expect(movedSticky.frame == OpenGraphiteCanvasAnnotationFrame(x: 35, y: 10, width: 240, height: 160))
        #expect(untouchedSticky.frame == OpenGraphiteCanvasAnnotationFrame(x: 500, y: 40, width: 240, height: 160))
        #expect(movedInk.frame == OpenGraphiteCanvasAnnotationFrame(x: 325, y: 190, width: 80, height: 60))

        // 検証内容：同時選択中の2件をまとめて削除する（When）
        store.deleteSelectedCanvasAnnotations()
        let afterDelete = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let remainingAnnotations = try #require(afterDelete.chapters.first?.annotations)
        let finalHTML = try Data(contentsOf: fixture.htmlURL)
        let finalCSS = try Data(contentsOf: cssURL)

        // 期待値：未選択付箋だけを残して選択を解除し、HTML byte列には影響しない（Then）
        #expect(remainingAnnotations.map(\.internalID) == [untouchedStickyID])
        #expect(store.selectedCanvasAnnotationIDs.isEmpty)
        #expect(store.selectedCanvasAnnotationID == nil)
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
    }

    /// 論理名（日本語）: 手書き部分消去Atomic保存テスト
    /// 概要: ピクセル消し後の分割stroke更新と完全消去を一度に `.ogp` へ反映し、HTML / CSS と生存選択を維持することを検証します。
    @Test("手書きの部分消去と完全消去をogpだけへ一括保存する")
    func testCanvasInkPartialErasurePersistsReplacementsAndDeletionsAtomically() throws {
        // コンディション：付箋と2件のinkを作り、HTML/CSS byte列と3件の同時選択を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try fixture.writeCompanionCSS("body { color: #202020; }")
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL)
        let originalHTML = try Data(contentsOf: fixture.htmlURL)
        let originalCSS = try Data(contentsOf: cssURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let stickyID = try #require(store.addStickyNote(at: CGPoint(x: 10, y: 20)))
        let originalStroke = OpenGraphiteInkStroke(
            points: [
                OpenGraphiteInkPoint(x: 0, y: 10),
                OpenGraphiteInkPoint(x: 50, y: 10),
                OpenGraphiteInkPoint(x: 100, y: 10)
            ],
            lineWidth: 4,
            inputDevice: .pen
        )
        let updatedInkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: 100, y: 100, width: 110, height: 20),
                strokes: [originalStroke]
            )
        )
        let deletedInkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: 300, y: 100, width: 50, height: 40),
                strokes: [
                    OpenGraphiteInkStroke(
                        points: [
                            OpenGraphiteInkPoint(x: 5, y: 20),
                            OpenGraphiteInkPoint(x: 45, y: 20)
                        ],
                        lineWidth: 4,
                        inputDevice: .pen
                    )
                ]
            )
        )
        store.selectCanvasAnnotations(ids: [stickyID, updatedInkID, deletedInkID])
        let replacementFrame = OpenGraphiteCanvasAnnotationFrame(
            x: 98,
            y: 106,
            width: 104,
            height: 8
        )
        let expectedLeftFragmentPoints = [
            OpenGraphiteInkPoint(x: 2, y: 4),
            OpenGraphiteInkPoint(x: 42, y: 4)
        ]
        let expectedRightFragmentPoints = [
            OpenGraphiteInkPoint(x: 62, y: 4),
            OpenGraphiteInkPoint(x: 102, y: 4)
        ]
        let replacement = OpenGraphiteCanvasAnnotation(
            internalID: updatedInkID,
            kind: .ink,
            frame: replacementFrame,
            strokes: [
                OpenGraphiteInkStroke(
                    points: expectedLeftFragmentPoints,
                    lineWidth: 4,
                    inputDevice: .pen
                ),
                OpenGraphiteInkStroke(
                    points: expectedRightFragmentPoints,
                    lineWidth: 4,
                    inputDevice: .pen
                )
            ]
        )

        // 検証内容：片方を分割後payloadへ置換し、もう片方を完全消去として同時適用する（When）
        store.applyCanvasInkErasure(
            updatedAnnotations: [replacement],
            deletedIDs: [deletedInkID],
            expectedAnnotations: store.selectedCanvasAnnotations
        )
        let reloaded = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let annotations = try #require(reloaded.chapters.first?.annotations)
        let persistedInk = try #require(annotations.first { $0.internalID == updatedInkID })
        let finalHTML = try Data(contentsOf: fixture.htmlURL)
        let finalCSS = try Data(contentsOf: cssURL)

        // 期待値：同一IDのinkを左右2fragmentと再計算frameへ更新し、完全消去IDだけを除いて生存選択とHTML/CSS byte列を維持する（Then）
        #expect(annotations.map(\.internalID) == [stickyID, updatedInkID])
        #expect(persistedInk.internalID == updatedInkID)
        #expect(persistedInk.frame == replacementFrame)
        #expect(persistedInk.strokes.count == 2)
        #expect(persistedInk.strokes.map(\.points) == [
            expectedLeftFragmentPoints,
            expectedRightFragmentPoints
        ])
        #expect(!annotations.contains { $0.internalID == deletedInkID })
        #expect(store.selectedCanvasAnnotationIDs == Set([stickyID, updatedInkID]))
        #expect(store.selectedCanvasAnnotationID == updatedInkID)
        #expect(!store.selectedCanvasAnnotationIDs.contains(deletedInkID))
        #expect(store.statusMessage == "手書きの一部を消去しました。")
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
    }

    /// 論理名（日本語）: キャンバス注釈Undo/Redoテスト
    /// 概要: 付箋の追加、本文編集、移動、削除を⌘Z相当の履歴で順に取り消し、やり直せることを検証します。
    @Test("付箋操作を取り消してやり直せる")
    func testCanvasAnnotationOperationsSupportUndoAndRedo() throws {
        // コンディション：空の注釈Canvasへ付箋を1件追加する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        #expect(store.canUndo)

        // 検証内容：追加を取り消してやり直し、本文編集・移動・削除も順に確定する（When）
        store.undoDocumentChange()
        #expect(store.selectedCanvasAnnotations.isEmpty)
        #expect(store.canRedo)
        store.redoDocumentChange()
        #expect(store.selectedCanvasAnnotations.map(\.internalID) == [annotationID])
        store.selectCanvasAnnotation(id: annotationID)

        store.stageCanvasAnnotationText(id: annotationID, text: "undoable memo")
        store.updateCanvasAnnotationText(id: annotationID, text: "undoable memo")
        store.moveSelectedCanvasAnnotations(
            anchorID: annotationID,
            translation: CGSize(width: 40, height: 15)
        )
        store.deleteCanvasAnnotation(id: annotationID)
        #expect(store.selectedCanvasAnnotations.isEmpty)

        // 期待値：削除、移動、本文編集を逆順に戻し、同じ順でやり直すと最終的に再度削除される（Then）
        store.undoDocumentChange()
        let restoredAfterDelete = try #require(
            store.selectedCanvasAnnotations.first { $0.internalID == annotationID }
        )
        #expect(restoredAfterDelete.text == "undoable memo")
        #expect(restoredAfterDelete.frame.x == 60)
        #expect(restoredAfterDelete.frame.y == 45)

        store.undoDocumentChange()
        let restoredBeforeMove = try #require(
            store.selectedCanvasAnnotations.first { $0.internalID == annotationID }
        )
        #expect(restoredBeforeMove.frame.x == 20)
        #expect(restoredBeforeMove.frame.y == 30)

        store.undoDocumentChange()
        let restoredBeforeText = try #require(
            store.selectedCanvasAnnotations.first { $0.internalID == annotationID }
        )
        #expect(restoredBeforeText.text.isEmpty)

        store.redoDocumentChange()
        store.redoDocumentChange()
        store.redoDocumentChange()
        let finalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        #expect(store.selectedCanvasAnnotations.isEmpty)
        #expect(store.canRedo == false)
        #expect(finalProject.chapters.first?.annotations.isEmpty == true)
    }

    /// 論理名（日本語）: HTML注釈統合履歴順序テスト
    /// 概要: HTML 同期とキャンバス注釈追加を交互に行っても、⌘Z／やり直しが保存順の単一時系列で進むことを検証します。
    @Test("HTMLと注釈を保存順に取り消してやり直せる")
    func testDocumentAndCanvasAnnotationHistoryUsesOneTimeline() throws {
        // コンディション：HTML を同期した後に同じ project へ付箋を追加する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialHTML = "<!doctype html>\n<html><body>initial</body></html>"
        let editedHTML = "<!doctype html>\n<html><body>edited</body></html>"
        store.syncCurrentHTML(editedHTML)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))

        // 検証内容：二回取り消した後、二回やり直す（When）
        store.undoDocumentChange()
        let htmlAfterFirstUndo = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let annotationsAfterFirstUndo = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.annotations
        store.undoDocumentChange()
        let htmlAfterSecondUndo = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.redoDocumentChange()
        store.redoDocumentChange()
        let finalAnnotations = try ProjectLoader()
            .loadProject(at: fixture.projectURL)
            .project.chapters.first?.annotations

        // 期待値：最新の付箋追加、先行するHTML同期の順で戻り、redoでは同じ順序で双方を復元する（Then）
        #expect(htmlAfterFirstUndo == editedHTML)
        #expect(annotationsAfterFirstUndo?.isEmpty == true)
        #expect(htmlAfterSecondUndo == initialHTML)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == editedHTML)
        #expect(finalAnnotations?.map(\.internalID) == [annotationID])
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: Domain横断Redo分岐破棄テスト
    /// 概要: 注釈を取り消した後に HTML を新規保存すると、注釈domainに残っていたredo分岐も破棄されることを検証します。
    @Test("注釈Undo後のHTML保存でRedo分岐を破棄する")
    func testDocumentSaveClearsCanvasAnnotationRedoBranch() throws {
        // コンディション：HTML 同期後に付箋を追加し、その付箋追加だけを取り消す（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))
        let firstHTML = "<!doctype html>\n<html><body>first branch</body></html>"
        let nextHTML = "<!doctype html>\n<html><body>next branch</body></html>"
        store.syncCurrentHTML(firstHTML)
        _ = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        store.undoDocumentChange()
        #expect(store.canRedo)

        // 検証内容：注釈がない状態から別domainのHTMLを新規同期する（When）
        store.syncHTML(nextHTML, target: target)

        // 期待値：注釈redoを含む旧分岐が消え、次のundoは新しいHTML同期だけを戻す（Then）
        #expect(store.canRedo == false)
        store.undoDocumentChange()
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == firstHTML)
        #expect(store.selectedCanvasAnnotations.isEmpty)
    }

    /// 論理名（日本語）: 注釈履歴外部競合拒否テスト
    /// 概要: 履歴記録後に同じ container の annotations が CLI 相当で変わった場合、Undoで外部値を上書きしないことを検証します。
    @Test("外部更新された注釈配列へ古い履歴を適用しない")
    func testCanvasAnnotationUndoRejectsExternallyChangedAnnotations() throws {
        // コンディション：付箋追加を履歴へ記録後、storeへ通知せず本文を外部変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        var externalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let chapterIndex = try #require(externalProject.chapters.firstIndex(where: {
            $0.annotations.contains { $0.internalID == annotationID }
        }))
        let annotationIndex = try #require(externalProject.chapters[chapterIndex].annotations.firstIndex(where: {
            $0.internalID == annotationID
        }))
        externalProject.chapters[chapterIndex].annotations[annotationIndex].text = "CLI edit"
        try JSONEncoder().encode(externalProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：staleな付箋追加履歴を取り消そうとする（When）
        store.undoDocumentChange()
        let persistedAnnotation = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters[chapterIndex].annotations.first {
                $0.internalID == annotationID
            }
        )

        // 期待値：外部本文を保持して最新manifestへ表示同期し、無効になった履歴を破棄する（Then）
        #expect(persistedAnnotation.text == "CLI edit")
        #expect(store.selectedCanvasAnnotations.first { $0.internalID == annotationID }?.text == "CLI edit")
        #expect(store.statusMessage == ".ogp の外部変更を検出したため、キャンバス注釈の履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 手書き部分消去Undo/Redoテスト
    /// 概要: 一度の消しゴムgestureによるstroke分割を一履歴単位で取り消し、やり直せることを検証します。
    @Test("手書きの部分消去を一操作として取り消してやり直せる")
    func testCanvasInkPartialErasureSupportsUndoAndRedo() throws {
        // コンディション：一本のstrokeを持つinkと部分消去後の置換値を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let originalFrame = OpenGraphiteCanvasAnnotationFrame(x: 20, y: 30, width: 100, height: 20)
        let originalStroke = OpenGraphiteInkStroke(
            points: [
                OpenGraphiteInkPoint(x: 0, y: 10),
                OpenGraphiteInkPoint(x: 50, y: 10),
                OpenGraphiteInkPoint(x: 100, y: 10)
            ],
            lineWidth: 4,
            inputDevice: .pen
        )
        let inkID = try #require(store.addInkAnnotation(frame: originalFrame, strokes: [originalStroke]))
        let gestureSnapshot = store.selectedCanvasAnnotations
        var replacement = try #require(gestureSnapshot.first { $0.internalID == inkID })
        replacement.frame = OpenGraphiteCanvasAnnotationFrame(x: 18, y: 36, width: 104, height: 8)
        replacement.strokes = [
            OpenGraphiteInkStroke(
                points: [OpenGraphiteInkPoint(x: 2, y: 4), OpenGraphiteInkPoint(x: 42, y: 4)],
                lineWidth: 4,
                inputDevice: .pen
            ),
            OpenGraphiteInkStroke(
                points: [OpenGraphiteInkPoint(x: 62, y: 4), OpenGraphiteInkPoint(x: 102, y: 4)],
                lineWidth: 4,
                inputDevice: .pen
            )
        ]

        // 検証内容：部分消去を確定後、取り消してからやり直す（When）
        store.applyCanvasInkErasure(
            updatedAnnotations: [replacement],
            deletedIDs: [],
            expectedAnnotations: gestureSnapshot
        )
        store.undoDocumentChange()
        let undoneInk = try #require(store.selectedCanvasAnnotations.first { $0.internalID == inkID })
        store.redoDocumentChange()
        let redoneInk = try #require(store.selectedCanvasAnnotations.first { $0.internalID == inkID })

        // 期待値：undoでは元stroke全体、redoでは分割された2strokeがogpとcacheへ復元される（Then）
        #expect(undoneInk.frame == originalFrame)
        #expect(undoneInk.strokes == [originalStroke])
        #expect(redoneInk == replacement)
        let persistedInk = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters.first?.annotations.first {
                $0.internalID == inkID
            }
        )
        #expect(persistedInk == replacement)
    }

    /// 論理名（日本語）: 手書き消去外部競合拒否テスト
    /// 概要: gesture 開始後に対象 ink が CLI 相当の経路で更新された場合、古い部分消去で外部値を上書きせず最新 `.ogp` を表示へ同期することを検証します。
    @Test("外部更新されたinkへ古い消しゴム結果を保存しない")
    func testCanvasInkErasureRejectsExternallyChangedTargetInk() throws {
        // コンディション：1件のinkとgesture開始時snapshotを用意し、storeへ通知せずdisk上の同じinkを外部変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let inkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 30, width: 100, height: 20),
                strokes: [
                    OpenGraphiteInkStroke(
                        points: [
                            OpenGraphiteInkPoint(x: 0, y: 10),
                            OpenGraphiteInkPoint(x: 100, y: 10)
                        ],
                        lineWidth: 4,
                        inputDevice: .pen
                    )
                ]
            )
        )
        let gestureSnapshot = store.selectedCanvasAnnotations
        let originalInk = try #require(gestureSnapshot.first { $0.internalID == inkID })
        var staleReplacement = originalInk
        staleReplacement.frame.x = 40

        var externallyChangedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let chapterIndex = try #require(
            externallyChangedProject.chapters.firstIndex { $0.internalID == store.selectedChapterInternalID }
        )
        let inkIndex = try #require(
            externallyChangedProject.chapters[chapterIndex].annotations.firstIndex { $0.internalID == inkID }
        )
        externallyChangedProject.chapters[chapterIndex].annotations[inkIndex].frame.y = 88
        let externalInk = externallyChangedProject.chapters[chapterIndex].annotations[inkIndex]
        try JSONEncoder().encode(externallyChangedProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：monitorの遅延中に相当するstale storeから部分消去結果を確定する（When）
        store.applyCanvasInkErasure(
            updatedAnnotations: [staleReplacement],
            deletedIDs: [],
            expectedAnnotations: gestureSnapshot
        )
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let persistedInk = try #require(
            persistedProject.chapters[chapterIndex].annotations.first { $0.internalID == inkID }
        )

        // 期待値：diskとstoreは外部更新値を維持し、古いpreviewは保存されず競合が利用者へ通知される（Then）
        #expect(persistedInk == externalInk)
        #expect(store.selectedCanvasAnnotations.first { $0.internalID == inkID } == externalInk)
        #expect(store.statusMessage == ".ogp の外部変更を検出したため、手書きの消去を中止しました。もう一度操作してください。")
    }

    /// 論理名（日本語）: 手書き消去最新Manifest統合テスト
    /// 概要: 対象 ink 以外の外部更新がある場合、最新 `.ogp` を基準に部分消去を適用して双方の変更を保持することを検証します。
    @Test("対象外のogp外部更新を保ったまま手書きを部分消去する")
    func testCanvasInkErasureRebasesOntoLatestExternalManifest() throws {
        // コンディション：1件のinkとgesture開始時snapshotを用意し、diskだけへproject名変更と別付箋追加を行う（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let inkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 30, width: 100, height: 20),
                strokes: [
                    OpenGraphiteInkStroke(
                        points: [
                            OpenGraphiteInkPoint(x: 0, y: 10),
                            OpenGraphiteInkPoint(x: 100, y: 10)
                        ],
                        lineWidth: 4,
                        inputDevice: .pen
                    )
                ]
            )
        )
        let gestureSnapshot = store.selectedCanvasAnnotations
        var replacement = try #require(gestureSnapshot.first { $0.internalID == inkID })
        replacement.frame = OpenGraphiteCanvasAnnotationFrame(x: 18, y: 34, width: 84, height: 12)
        replacement.strokes = [
            OpenGraphiteInkStroke(
                points: [
                    OpenGraphiteInkPoint(x: 2, y: 6),
                    OpenGraphiteInkPoint(x: 82, y: 6)
                ],
                lineWidth: 4,
                inputDevice: .pen
            )
        ]

        var externallyChangedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        externallyChangedProject.name = "Externally Renamed"
        let chapterIndex = try #require(
            externallyChangedProject.chapters.firstIndex { $0.internalID == store.selectedChapterInternalID }
        )
        let externalSticky = OpenGraphiteCanvasAnnotation(
            internalID: "external-sticky",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 200, y: 60, width: 220, height: 140),
            text: "CLIから追加"
        )
        externallyChangedProject.chapters[chapterIndex].annotations.append(externalSticky)
        try JSONEncoder().encode(externallyChangedProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：monitorへ外部更新が届く前のstoreから、対象inkの部分消去を確定する（When）
        store.applyCanvasInkErasure(
            updatedAnnotations: [replacement],
            deletedIDs: [],
            expectedAnnotations: gestureSnapshot
        )
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let persistedAnnotations = persistedProject.chapters[chapterIndex].annotations

        // 期待値：外部project名と付箋を維持し、同じIDのinkだけを部分消去後payloadへ置き換える（Then）
        #expect(persistedProject.name == "Externally Renamed")
        #expect(persistedAnnotations.first { $0.internalID == "external-sticky" } == externalSticky)
        #expect(persistedAnnotations.first { $0.internalID == inkID } == replacement)
        #expect(store.loadedProject?.project.name == "Externally Renamed")
        #expect(store.statusMessage == "手書きの一部を消去しました。")
    }

    /// 論理名（日本語）: 注釈専用Collection外部同期テスト
    /// 概要: component HTML がない Collection でも Components segment と生存するなげわ選択を外部 `.ogp` 同期後に維持することを検証します。
    @Test("注釈だけのCollectionで外部ogp同期後も選択を維持する")
    func testExternalRefreshPreservesComponentAnnotationSelectionWithoutComponentPages() throws {
        // コンディション：HTML cardがなく2件の注釈だけを持つCollection projectを開いて両方を選択する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let firstAnnotation = OpenGraphiteCanvasAnnotation(
            internalID: "collection-note-first",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 20, y: 30, width: 240, height: 160),
            text: "first"
        )
        let secondAnnotation = OpenGraphiteCanvasAnnotation(
            internalID: "collection-note-second",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 300, y: 30, width: 240, height: 160),
            text: "second"
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Annotation-only Collection",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "empty-pages",
                    internalID: "empty-pages-container",
                    title: "Empty Pages",
                    pages: []
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "annotation-only",
                    internalID: "annotation-only-container",
                    title: "Annotation Only",
                    components: [],
                    annotations: [firstAnnotation, secondAnnotation]
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.selectCanvasAnnotations(ids: [firstAnnotation.internalID, secondAnnotation.internalID])

        // 検証内容：外部編集でCollection名を変え、primary注釈だけを削除してmanifestを再読込する（When）
        var externallyEditedProject = try #require(store.loadedProject?.project)
        externallyEditedProject.collections[0].title = "Externally Updated"
        externallyEditedProject.collections[0].annotations.removeAll {
            $0.internalID == secondAnnotation.internalID
        }
        try JSONEncoder().encode(externallyEditedProject).write(to: fixture.projectURL, options: .atomic)
        store.refreshProjectManifestFromDiskIfChanged()

        // 期待値：Components segmentを保ち、削除済みIDだけを除いて生存注釈をprimaryへ昇格する（Then）
        #expect(store.selectedCanvasSegment == .components)
        #expect(store.selectedComponentCollection?.internalID == "annotation-only-container")
        #expect(store.selectedComponentCollection?.title == "Externally Updated")
        #expect(store.selectedCanvasAnnotationIDs == Set([firstAnnotation.internalID]))
        #expect(store.selectedCanvasAnnotationID == firstAnnotation.internalID)
    }

    /// 論理名（日本語）: 注釈移動座標上限テスト
    /// 概要: 選択全体が座標上限にある場合、範囲外方向への移動を保存済み扱いにせず `.ogp` を書き換えないことを検証します。
    @Test("座標上限を越える注釈移動はogpを書き換えない")
    func testCanvasAnnotationMoveBeyondCoordinateLimitIsNoOp() throws {
        // コンディション：最大X/Y座標に付箋を追加し、保存直後のmanifestとstatusを保持する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let limit = OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: limit, y: limit)))
        let manifestBeforeMove = try Data(contentsOf: fixture.projectURL)
        let statusBeforeMove = store.statusMessage

        // 検証内容：両軸とも上限を越える方向へ移動を要求する（When）
        store.moveSelectedCanvasAnnotations(
            anchorID: annotationID,
            translation: CGSize(width: 100, height: 100)
        )

        // 期待値：実効移動量が0となり、frame、manifest byte列、statusを更新しない（Then）
        #expect(store.selectedCanvasAnnotation?.frame.x == limit)
        #expect(store.selectedCanvasAnnotation?.frame.y == limit)
        #expect(try Data(contentsOf: fixture.projectURL) == manifestBeforeMove)
        #expect(store.statusMessage == statusBeforeMove)
    }

    /// 論理名（日本語）: 注釈実削除件数テスト
    /// 概要: 不明 ID を含む削除要求でも、実際に現在 Canvas から削除した件数だけを status へ表示することを検証します。
    @Test("注釈削除statusには実削除件数を表示する")
    func testCanvasAnnotationDeleteReportsActualDeletionCount() throws {
        // コンディション：削除可能な付箋を1件だけ追加する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))

        // 検証内容：有効IDと不明IDを同じ削除要求へ渡す（When）
        store.deleteCanvasAnnotations(ids: [annotationID, "missing-annotation"])

        // 期待値：付箋1件だけを削除し、statusも実削除数の1件を示す（Then）
        #expect(store.selectedCanvasAnnotations.isEmpty)
        #expect(store.statusMessage == "キャンバス注釈を 1 件削除しました。")
    }

    /// 論理名（日本語）: 注釈キャンバス分離テスト
    /// 概要: 付箋と手書きが現在表示中の Chapter / Collection にだけ保存され、別キャンバスへ混入しないことを検証します。
    @Test("ChapterとCollectionごとにキャンバス注釈を分離する")
    func testCanvasAnnotationsAreIsolatedByChapterAndCollection() throws {
        // コンディション：2つの Chapter と1つの Collection を持つ project を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let project = OpenGraphiteProject(
            version: "1",
            name: "Annotation Isolation Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "first",
                    internalID: "firstopaque",
                    title: "First",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "homeopaque",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "second",
                    internalID: "secondopaque",
                    title: "Second",
                    pages: []
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collectionopaque",
                    title: "Main",
                    components: []
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let secondChapterID = try #require(
            store.loadedProject?.project.chapters.first(where: { $0.id == "second" })?.internalID
        )
        let inkStroke = OpenGraphiteInkStroke(
            points: [OpenGraphiteInkPoint(x: 0, y: 0, pressure: 0.6)],
            inputDevice: .pen
        )

        // 検証内容：先頭 Chapter の付箋を作成直後に別 Chapter へ移り、遅延した本文保存と残りの注釈追加を行う（When）
        let firstStickyID = try #require(store.addStickyNote(at: CGPoint(x: 10, y: 20)))
        store.stageCanvasAnnotationText(id: firstStickyID, text: "First note")
        #expect(store.selectedCanvasAnnotation?.text == "First note")
        store.selectChapter(internalID: secondChapterID)
        store.updateCanvasAnnotationText(id: firstStickyID, text: "First note")
        let secondStickyID = try #require(store.addStickyNote(at: CGPoint(x: 30, y: 40)))
        store.updateCanvasAnnotationText(id: secondStickyID, text: "Second note")
        store.selectComponentsSegment()
        let collectionInkID = try #require(
            store.addInkAnnotation(
                frame: OpenGraphiteCanvasAnnotationFrame(x: -12, y: 8, width: 32, height: 24),
                strokes: [inkStroke]
            )
        )
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project

        // 期待値：遅延本文も元の Chapter を ID から解決し、各注釈が正しい Chapter / Collection だけへ保存される（Then）
        #expect(reloadedProject.chapters[0].annotations.map(\.internalID) == [firstStickyID])
        #expect(reloadedProject.chapters[0].annotations.first?.text == "First note")
        #expect(reloadedProject.chapters[1].annotations.map(\.internalID) == [secondStickyID])
        #expect(reloadedProject.chapters[1].annotations.first?.text == "Second note")
        #expect(reloadedProject.collections[0].annotations.map(\.internalID) == [collectionInkID])
        #expect(reloadedProject.collections[0].annotations.first?.strokes == [inkStroke])
    }

    /// 論理名（日本語）: Project切替中付箋確定テスト
    /// 概要: debounce 中に別 project を開いても、付箋本文を入力開始時の `.ogp` へ保存することを検証します。
    @Test("Project切替後も未確定付箋本文を元のogpへ保存する")
    func testCanvasAnnotationTextCommitKeepsOriginalProjectTarget() throws {
        // コンディション：2つの独立projectを用意し、先頭projectの付箋本文をapp cacheへ即時反映する（Given）
        let firstFixture = try EditorStoreHistoryFixture()
        let secondFixture = try EditorStoreHistoryFixture()
        defer {
            firstFixture.cleanUp()
            secondFixture.cleanUp()
        }
        let store = EditorStore()
        store.openProject(at: firstFixture.projectURL)
        let stickyID = try #require(store.addStickyNote(at: CGPoint(x: 12, y: 18)))
        store.stageCanvasAnnotationText(id: stickyID, text: "元projectへ保存")

        // 検証内容：別projectへ切り替えて付箋を追加後、入力開始時のURLを指定してdebounce相当の確定を行う（When）
        store.openProject(at: secondFixture.projectURL)
        _ = try #require(store.addStickyNote(at: CGPoint(x: 30, y: 40)))
        store.updateCanvasAnnotationText(
            projectURL: firstFixture.projectURL,
            id: stickyID,
            text: "元projectへ保存"
        )
        store.undoDocumentChange()
        let firstReloaded = try ProjectLoader().loadProject(at: firstFixture.projectURL).project
        let secondReloaded = try ProjectLoader().loadProject(at: secondFixture.projectURL).project

        // 期待値：本文は元projectだけへ保存され、その遅延commitは現在projectの履歴へ混入せず直前の付箋追加をundoできる（Then）
        #expect(firstReloaded.chapters.first?.annotations.first?.text == "元projectへ保存")
        #expect(secondReloaded.chapters.first?.annotations.isEmpty == true)
        #expect(store.loadedProject?.fileURL.standardizedFileURL == secondFixture.projectURL.standardizedFileURL)
        #expect(store.canRedo)
    }

    /// 論理名（日本語）: 付箋Stage後操作履歴分離テスト
    /// 概要: debounce前の付箋本文をmanifestから分離し、先行する移動と本文確定を別々の履歴として連続Undoできることを検証します。
    @Test("付箋本文Stage後の移動と本文確定を別々に取り消せる")
    func testStagedCanvasAnnotationTextAndMoveCreateIndependentHistoryEntries() throws {
        // コンディション：空本文の付箋へ本文をstageするが、まだdebounce保存は確定しない（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        store.stageCanvasAnnotationText(id: annotationID, text: "draft memo")
        let diskBeforeMove = try ProjectLoader().loadProject(at: fixture.projectURL).project
        #expect(diskBeforeMove.chapters.first?.annotations.first?.text.isEmpty == true)
        #expect(store.selectedCanvasAnnotation?.text == "draft memo")

        // 検証内容：本文未確定のまま付箋を移動し、その後にdebounce相当の本文確定を行って二回取り消す（When）
        store.moveSelectedCanvasAnnotations(
            anchorID: annotationID,
            translation: CGSize(width: 40, height: 15)
        )
        store.updateCanvasAnnotationText(id: annotationID, text: "draft memo")
        store.undoDocumentChange()
        let afterTextUndo = try #require(
            store.selectedCanvasAnnotations.first { $0.internalID == annotationID }
        )
        store.undoDocumentChange()
        let afterMoveUndo = try #require(
            store.selectedCanvasAnnotations.first { $0.internalID == annotationID }
        )

        // 期待値：一回目は本文だけ、二回目は位置だけが戻り、履歴競合として破棄されない（Then）
        #expect(afterTextUndo.text.isEmpty)
        #expect(afterTextUndo.frame.x == 60)
        #expect(afterTextUndo.frame.y == 45)
        #expect(afterMoveUndo.text.isEmpty)
        #expect(afterMoveUndo.frame.x == 20)
        #expect(afterMoveUndo.frame.y == 30)
        #expect(store.canUndo)
        #expect(store.canRedo)
    }

    /// 論理名（日本語）: 注釈保存最新Manifest統合テスト
    /// 概要: 付箋本文stage中の通常操作と本文確定を最新diskへrebaseし、CLIによるproject属性と別注釈を維持することを検証します。
    @Test("付箋操作を最新ogpへ統合してCLI変更を維持する")
    func testCanvasAnnotationOperationsRebaseOntoLatestManifest() throws {
        // コンディション：付箋本文をstage後、diskだけへproject名変更と別付箋追加を行う（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        store.stageCanvasAnnotationText(id: annotationID, text: "local draft")
        var externalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        externalProject.name = "CLI Renamed"
        let externalAnnotation = OpenGraphiteCanvasAnnotation(
            internalID: "cli-added-note",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 300, y: 80, width: 220, height: 140),
            text: "CLI note"
        )
        externalProject.chapters[0].annotations.append(externalAnnotation)
        try JSONEncoder().encode(externalProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：monitorへ外部変更が届く前にlocal付箋を移動し、stage済み本文を確定する（When）
        store.moveSelectedCanvasAnnotations(
            anchorID: annotationID,
            translation: CGSize(width: 25, height: 10)
        )
        store.updateCanvasAnnotationText(id: annotationID, text: "local draft")
        let persistedProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let persistedLocal = try #require(
            persistedProject.chapters[0].annotations.first { $0.internalID == annotationID }
        )

        // 期待値：CLI変更を残したまま対象付箋の位置と本文だけが更新される（Then）
        #expect(persistedProject.name == "CLI Renamed")
        #expect(persistedProject.chapters[0].annotations.first {
            $0.internalID == externalAnnotation.internalID
        } == externalAnnotation)
        #expect(persistedLocal.text == "local draft")
        #expect(persistedLocal.frame.x == 45)
        #expect(persistedLocal.frame.y == 40)
        #expect(store.loadedProject?.project.name == "CLI Renamed")
    }

    /// 論理名（日本語）: 付箋本文外部競合拒否テスト
    /// 概要: 入力開始後に同じ付箋本文がCLI変更された場合、local draftで上書きせず最新本文へ同期することを検証します。
    @Test("外部変更された同じ付箋本文へdraftを保存しない")
    func testCanvasAnnotationTextCommitRejectsExternalTextConflict() throws {
        // コンディション：空本文の付箋へlocal本文をstage後、disk上の同じ本文だけをCLI相当で変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let annotationID = try #require(store.addStickyNote(at: CGPoint(x: 20, y: 30)))
        store.stageCanvasAnnotationText(id: annotationID, text: "local draft")
        var externalProject = try ProjectLoader().loadProject(at: fixture.projectURL).project
        let annotationIndex = try #require(
            externalProject.chapters[0].annotations.firstIndex { $0.internalID == annotationID }
        )
        externalProject.chapters[0].annotations[annotationIndex].text = "CLI text"
        try JSONEncoder().encode(externalProject).write(to: fixture.projectURL, options: .atomic)

        // 検証内容：monitorへ外部変更が届く前にlocal draftのdebounce保存を確定する（When）
        store.updateCanvasAnnotationText(id: annotationID, text: "local draft")
        let persistedAnnotation = try #require(
            ProjectLoader().loadProject(at: fixture.projectURL).project.chapters[0].annotations.first {
                $0.internalID == annotationID
            }
        )

        // 期待値：CLI本文を維持し、表示も最新本文へ戻して無効になった履歴を破棄する（Then）
        #expect(persistedAnnotation.text == "CLI text")
        #expect(store.selectedCanvasAnnotation?.text == "CLI text")
        #expect(store.statusMessage == ".ogp で同じ付箋本文が外部変更されたため、入力内容の保存を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 不正キャンバス配置拒否テスト
    /// 概要: 解像度が 0 以下の場合に Store と `.ogp` を更新しないことを検証します。
    @Test("不正な解像度ではキャンバス配置を更新しない")
    func testUpdateSelectedPageCanvasRejectsInvalidResolution() throws {
        // Given: 一時プロジェクトを開き、現在のキャンバス配置を保持する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let originalCanvas = try #require(store.selectedPage?.canvas)

        // When: width 0 の不正な配置を適用しようとする
        store.updateSelectedPageCanvas(x: 0, y: 0, width: 0, height: 844)

        // Then: Store とディスク上の `.ogp` は変更されず、エラーが残る
        #expect(store.selectedPage?.canvas == originalCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas == originalCanvas)
        #expect(store.lastError == "キャンバス配置の入力が不正です。")
    }

    /// 論理名（日本語）: CSS宣言更新テスト
    /// 概要: 選択中ノードのCSS declarationをsourceへ保存し、WebViewを再読み込みすることを検証します。
    @Test("CSS宣言更新でノードとsource reloadを更新する")
    func testUpdateCSSVariableMutatesSelectedNode() async throws {
        // コンディション：内部ID付きHTML nodeを持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 16px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：CSS declaration を空白付きの値で更新する（When）
        store.updateCSSVariable(key: "gap", value: " 32px ")

        // 期待値：値はtrimしてsourceへ保存し、inline previewを残さずWebViewを再読み込みする（Then）
        #expect(store.nodes[0].cssVariables["gap"] == "32px")
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()
        #expect(!diskHTML.contains("gap"))
        #expect(diskCSS.contains("gap: 32px;"))
    }

    /// 論理名（日本語）: フォント候補適用テスト
    /// 概要: フォントブラウザの候補適用で CSS declaration と stylesheet link が HTML 正本へ保存されることを検証します。
    @Test("フォント候補適用でCSS宣言とstylesheetを保存する")
    func testApplyFontCandidatePersistsCSSVariableAndStylesheet() throws {
        // コンディション：head と text node を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><head><title>Fixture</title></head><body><h1 data-og-id="title" data-og-internal-id="title-node">OpenGraphite</h1></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "internalID": "title-node",
                "tagName": "h1",
                "capabilities": [OpenGraphiteNodeCapability.editLayout.rawValue],
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")
        let candidate = try #require(
            OpenGraphiteFontLibrary.filteredCandidates(for: .external, query: "roboto")
                .first { $0.familyName == "Roboto" }
        )
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：Google Fonts 候補を適用する
        store.applyFontCandidate(candidate)
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：node の CSS declaration と head の stylesheet link が保存される
        #expect(store.nodes[0].cssVariables["font-family"] == "\"Roboto\", sans-serif")
        #expect(!diskHTML.contains("font-family"))
        #expect(diskCSS.contains("font-family: \"Roboto\", sans-serif;"))
        #expect(diskHTML.contains("<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Roboto&amp;display=swap\">"))
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 2)
    }

    /// 論理名（日本語）: 標準locale typography編集テスト
    /// 概要: Page InspectorがShared core経由でroot `font-family`と任意BCP 47 `:lang()`を最小差分保存することを検証します。
    @Test("標準locale typographyをselector scope保持で保存してWebViewを再読み込みする")
    func testLocaleTypographyPersistsStandardRulesAndStylesheet() throws {
        // コンディション：標準ID root、default / locale / element overrideと未移行legacy helperを持つpageを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html lang="fr-CA"><head><title>Fixture</title></head><body>
          <main id="page" data-og-id="page" data-og-internal-id="page-node" data-og-type="page">
            <h1 id="title" data-og-id="title" data-og-internal-id="title-node" data-og-type="text">Title</h1>
          </main>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            #page {
              font-family: system-ui, sans-serif;
              --og-font-family-default: "Legacy Default", fantasy;
            }

            #page:lang("fr-CA") {
              font-family: "Merriweather", serif !important;
            }

            #title {
              font-family: Georgia, serif;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialTypography = try #require(store.selectedLocaleTypography)
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：default、既存locale、任意localeを更新し、同値の再適用とfont候補選択も行う（When）
        store.updateSelectedLocaleTypography(locale: nil, fontFamily: "ui-sans-serif, sans-serif")
        store.updateSelectedLocaleTypography(locale: "fr-ca", fontFamily: "\"Merriweather Sans\", serif")
        store.updateSelectedLocaleTypography(locale: "sr_Latn_RS", fontFamily: "\"Noto Sans\", sans-serif")
        let reloadTokenAfterStandardEdits = store.reloadToken(for: fixture.htmlURL)
        store.updateSelectedLocaleTypography(locale: "sr-Latn-RS", fontFamily: "\"Noto Sans\", sans-serif")

        let candidate = try #require(
            OpenGraphiteFontLibrary.filteredCandidates(for: .external, query: "noto sans jp")
                .first { $0.familyName == "Noto Sans JP" }
        )
        store.applySelectedLocaleFontCandidate(locale: "ja", candidate: candidate)
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()
        let updatedTypography = try #require(store.selectedLocaleTypography)

        // 期待値：既存root selector scopeと!importantを保ち、任意localeを標準:lang()で追加する（Then）
        #expect(initialTypography.rootSelector == "#page")
        #expect(initialTypography.declarations.contains {
            $0.locale == "default" && $0.property == "font-family" && $0.value == "system-ui, sans-serif"
        })
        #expect(initialTypography.declarations.contains {
            $0.locale == "fr-CA" && $0.selector == "#page:lang(\"fr-CA\")" && $0.important
        })
        #expect(updatedTypography.rootSelector == "#page")
        #expect(updatedTypography.declarations.contains {
            $0.locale == "sr-Latn-RS" && $0.selector == "#page:lang(\"sr-Latn-RS\")"
                && $0.value == "\"Noto Sans\", sans-serif"
        })
        #expect(updatedTypography.declarations.contains {
            $0.locale == "ja" && $0.value == "\"Noto Sans JP\", sans-serif"
        })
        #expect(diskCSS.contains("font-family: ui-sans-serif, sans-serif;"))
        #expect(diskCSS.contains("#page:lang(\"fr-CA\")"))
        #expect(diskCSS.contains("font-family: \"Merriweather Sans\", serif !important;"))
        #expect(diskCSS.contains("#page:lang(\"sr-Latn-RS\")"))
        #expect(diskCSS.contains("#page:lang(\"ja\")"))
        #expect(diskCSS.contains("--og-font-family-default: \"Legacy Default\", fantasy;"))
        #expect(diskCSS.contains("#title {\n  font-family: Georgia, serif;"))
        #expect(!diskHTML.contains("--og-font-family"))
        #expect(diskHTML.contains("https://fonts.googleapis.com/css2?family=Noto+Sans+JP&amp;display=swap"))
        #expect(reloadTokenAfterStandardEdits == initialReloadToken + 3)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 5)
        #expect(store.cssMutation == nil)
    }

    /// 論理名（日本語）: Inspectorテキストfallback更新テスト
    /// 概要: binding text node の Inspector 更新が HTML 正本の fallback を保存し、WebView 反映 mutation を発行することを検証します。
    @Test("Inspectorのtext更新でfallbackとmutationを更新する")
    func testUpdateNodeTextContentPersistsFallbackAndMutation() async throws {
        // コンディション：binding text node を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <lead-text
            data-og-id="hero-lead"
            data-og-internal-id="lead-node"
            data-og-text-source="binding"
            data-i18n-key="home.hero.lead">日本語 fallback</lead-text>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "hero-lead",
                "internalID": "lead-node",
                "tagName": "lead-text",
                "capabilities": [OpenGraphiteNodeCapability.editText.rawValue],
                "capabilityEvidence": [
                    "isProjectResourceRoot": false,
                    "isNativeControl": false,
                    "isCustomElement": true,
                    "isLink": false,
                    "hasDirectText": true,
                    "hasElementChildren": false,
                    "hasMediaContent": false,
                    "hasSVGContent": false,
                    "hasMaskContent": false,
                    "resolvedDisplay": "inline"
                ],
                "textContent": "English active",
                "fallbackTextContent": "DOM fallback",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero-lead")

        // 検証内容：Inspector の Fallback 入力相当で text content を更新する
        store.updateNodeTextContent("更新 fallback")

        // 期待値：HTML 正本の fallback、Store の fallback、WebView 反映 mutation が更新される
        let node = try #require(store.nodes.first)
        #expect(node.textContent == "English active")
        #expect(node.fallbackTextContent == "更新 fallback")
        #expect(store.textMutation?.nodeID == "hero-lead")
        #expect(store.textMutation?.value == "更新 fallback")
        #expect(store.textMutation?.mode == .fallback)
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(diskHTML.contains("更新 fallback"))
        #expect(!diskHTML.contains("日本語 fallback"))
    }

    /// 論理名（日本語）: Inspectorテキストlive反映非永続化テスト
    /// 概要: Inspector 入力中の text 反映は app 内 cache と WebView mutation に留まり、確定保存まで HTML を更新しないことを検証します。
    @Test("Inspectorのtext live反映は確定までHTMLへ保存しない")
    func testPreviewNodeTextContentDoesNotPersistUntilCommit() async throws {
        // コンディション：literal text node を持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Lead data-og-id="lead" data-og-internal-id="lead-node" data-og-type="text">Original</Lead>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "lead",
                "internalID": "lead-node",
                "tagName": "lead",
                "type": "text",
                "textContent": "Original",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "lead")
        let initialDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 検証内容：Inspector 入力中の live 反映を app cache へ適用する（When）
        store.previewNodeTextContent("入力中", expectedNodeID: "lead", expectedPageURL: fixture.htmlURL)

        // 期待値：cache と WebView mutation は更新されるが、HTML 正本はまだ更新されない（Then）
        #expect(store.nodes[0].textContent == "入力中")
        #expect(store.nodes[0].fallbackTextContent == "入力中")
        #expect(store.textMutation?.nodeID == "lead")
        #expect(store.textMutation?.value == "入力中")
        #expect(store.textMutation?.mode == .fallback)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == initialDiskHTML)

        // 検証内容：編集開始時の保存済み値を基準に確定保存する（When）
        store.updateNodeTextContent(
            "入力中",
            expectedNodeID: "lead",
            expectedPageURL: fixture.htmlURL,
            expectedOldValue: "Original"
        )

        // 期待値：確定時だけ HTML 正本が更新される（Then）
        let committedDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(committedDiskHTML.contains(">入力中<"))
        #expect(!committedDiskHTML.contains(">Original<"))
    }

    /// 論理名（日本語）: プレビューテキスト編集中同期テスト
    /// 概要: contenteditable 入力中 payload が選択中 text node の Inspector 表示値へ即時反映されることを検証します。
    @Test("preview編集中text payloadで選択nodeのactive textを更新する")
    func testIngestTextEditingPayloadUpdatesSelectedTextNode() throws {
        // コンディション：binding text node の DOM payload を取り込み、対象 node を選択する（Given）
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "hero-lead",
                "internalID": "lead-node",
                "tagName": "lead-text",
                "capabilities": [OpenGraphiteNodeCapability.editText.rawValue],
                "capabilityEvidence": [
                    "isProjectResourceRoot": false,
                    "isNativeControl": false,
                    "isCustomElement": true,
                    "isLink": false,
                    "hasDirectText": true,
                    "hasElementChildren": false,
                    "hasMediaContent": false,
                    "hasSVGContent": false,
                    "hasMaskContent": false,
                    "resolvedDisplay": "inline"
                ],
                "textContent": "Active text",
                "fallbackTextContent": "Fallback text",
                "textSource": "binding",
                "i18nKey": "home.hero.lead",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero-lead")
        #expect(store.selectedNode?.supports(.editText) == true)

        // 検証内容：WebView の contenteditable 入力中 payload を取り込む（When）
        store.ingestTextEditingPayload([
            "id": "hero-lead",
            "text": "入力中のpreview text"
        ])

        // 期待値：active text だけが即時更新され、HTML fallback 表示値は維持される（Then）
        let node = try #require(store.nodes.first)
        #expect(node.textContent == "入力中のpreview text")
        #expect(node.fallbackTextContent == "Fallback text")
    }

    /// 論理名（日本語）: Inspectorテキスト保存対象ガードテスト
    /// 概要: 入力中の node から選択が移動した後に保存が発火しても、現在選択中の別 node を更新しないことを検証します。
    @Test("Inspectorのtext保存は別選択nodeへ流れない")
    func testUpdateNodeTextContentIgnoresStaleSelectionCommit() throws {
        // コンディション：2つの text node を持つ一時プロジェクトを開き、2つ目へ選択を移す
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Title data-og-id="title" data-og-internal-id="title-node" data-og-type="text">Title</Title>
          <Lead data-og-id="lead" data-og-internal-id="lead-node" data-og-type="text">Lead</Lead>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "internalID": "title-node",
                "tagName": "title",
                "type": "text",
                "textContent": "Title",
                "cssVariables": [String: String](),
                "depth": 0
            ],
            [
                "id": "lead",
                "internalID": "lead-node",
                "tagName": "lead",
                "type": "text",
                "textContent": "Lead",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "lead")

        // 検証内容：title 入力欄由来の古い保存が、lead 選択中に発火した状況を再現する
        store.updateNodeTextContent(
            "Stale title",
            expectedNodeID: "title",
            expectedPageURL: fixture.htmlURL
        )

        // 期待値：現在選択中の lead も HTML 正本も変更されない
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(store.nodes.first(where: { $0.id == "lead" })?.textContent == "Lead")
        #expect(store.textMutation == nil)
        #expect(diskHTML.contains(">Title<"))
        #expect(diskHTML.contains(">Lead<"))
        #expect(!diskHTML.contains("Stale title"))
    }

    /// 論理名（日本語）: Inspector Active Resolved更新テスト
    /// 概要: 表示中 locale の text resource を Inspector から更新でき、HTML fallback は変更しないことを検証します。
    @Test("InspectorのActive Resolved更新で表示中locale JSONを更新する")
    func testUpdateActiveResolvedTextContentPersistsCurrentLocaleResource() throws {
        // コンディション：selectedLanguage=ja の preview と editable locale JSON を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html lang="ja" data-og-lang-source="binding" data-og-lang-field="selectedLanguage"><head>
          <script src="./i18n.js" defer></script>
        </head><body>
          <LeadText
            data-og-id="hero-lead"
            data-og-internal-id="lead-node"
            data-og-type="text"
            data-og-text-source="binding"
            data-i18n-key="home.hero.lead">HTML fallback</LeadText>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try """
        function selectedLanguage() { return "ja"; }
        const i18n = { init(config) { return config; } };
        i18n.init({
          lng: selectedLanguage(),
          fallbackLng: "ja",
          backend: { loadPath: "/locales/{{lng}}.json" }
        });
        """.write(to: fixture.publicURL.appendingPathComponent("i18n.js"), atomically: true, encoding: .utf8)
        let localeDirectory = fixture.publicURL.appendingPathComponent("locales")
        try FileManager.default.createDirectory(at: localeDirectory, withIntermediateDirectories: true)
        try #"{"home.hero.lead":"現在 ja"}"#.write(
            to: localeDirectory.appendingPathComponent("ja.json"),
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(
                        x: 0,
                        y: 0,
                        width: 100,
                        height: 100,
                        previewContext: OpenGraphitePreviewContext(fieldMocks: ["selectedLanguage": "ja"])
                    )
                )
            ]
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero-lead",
                "internalID": "lead-node",
                "tagName": "leadtext",
                "type": "text",
                "textContent": "現在 ja",
                "fallbackTextContent": "HTML fallback",
                "textSource": "binding",
                "i18nKey": "home.hero.lead",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero-lead")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)
        let context = try #require(store.activeResolvedTextEditContext(for: store.nodes[0]))

        // 検証内容：Inspector 入力中の Active Resolved live 反映を app cache へ適用する
        store.previewActiveResolvedTextContent("入力中 ja", locale: context.locale)

        // 期待値：cache と WebView mutation は更新されるが、locale JSON はまだ更新されない
        let previewResource = try Self.localeJSON(at: localeDirectory.appendingPathComponent("ja.json"))
        #expect(previewResource["home.hero.lead"] as? String == "現在 ja")
        #expect(store.nodes[0].textContent == "入力中 ja")
        #expect(store.nodes[0].fallbackTextContent == "HTML fallback")
        #expect(store.textMutation?.nodeID == "hero-lead")
        #expect(store.textMutation?.value == "入力中 ja")
        #expect(store.textMutation?.mode == .resolved)

        // 検証内容：Inspector の Active Resolved 確定相当で表示中 locale の text を保存する
        store.updateActiveResolvedTextContent("更新 ja", locale: context.locale)

        // 期待値：確定時に ja resource だけが更新され、HTML fallback は維持され、resolved text mutation が発行される
        let updatedResource = try Self.localeJSON(at: localeDirectory.appendingPathComponent("ja.json"))
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(context.locale == "ja")
        #expect(context.isEditable == true)
        #expect(updatedResource["home.hero.lead"] as? String == "更新 ja")
        #expect(store.nodes[0].textContent == "更新 ja")
        #expect(store.nodes[0].fallbackTextContent == "HTML fallback")
        #expect(store.textMutation?.nodeID == "hero-lead")
        #expect(store.textMutation?.value == "更新 ja")
        #expect(store.textMutation?.mode == .resolved)
        #expect(diskHTML.contains("HTML fallback"))
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken)
    }

    /// 論理名（日本語）: Inspector別locale更新テスト
    /// 概要: preview 表示中ではない locale resource を保存しても現在の表示 cache と WebView mutation を変更しないことを検証します。
    @Test("Inspectorの別locale更新は対象locale JSONだけを更新する")
    func testUpdateInactiveResolvedTextContentPersistsOnlySelectedLocaleResource() throws {
        // コンディション：selectedLanguage=ja の preview と ja / eng locale JSON を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html lang="ja" data-og-lang-source="binding" data-og-lang-field="selectedLanguage"><head>
          <script src="./i18n.js" defer></script>
        </head><body>
          <LeadText
            data-og-id="hero-lead"
            data-og-internal-id="lead-node"
            data-og-type="text"
            data-og-text-source="binding"
            data-i18n-key="home.hero.lead">HTML fallback</LeadText>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try """
        function selectedLanguage() { return "ja"; }
        const i18n = { init(config) { return config; } };
        i18n.init({
          lng: selectedLanguage(),
          fallbackLng: "ja",
          backend: { loadPath: "/locales/{{lng}}.json" }
        });
        """.write(to: fixture.publicURL.appendingPathComponent("i18n.js"), atomically: true, encoding: .utf8)
        let localeDirectory = fixture.publicURL.appendingPathComponent("locales")
        try FileManager.default.createDirectory(at: localeDirectory, withIntermediateDirectories: true)
        try #"{"home.hero.lead":"現在 ja"}"#.write(
            to: localeDirectory.appendingPathComponent("ja.json"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"home.hero.lead":"Current English"}"#.write(
            to: localeDirectory.appendingPathComponent("eng.json"),
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(
                        x: 0,
                        y: 0,
                        width: 100,
                        height: 100,
                        previewContext: OpenGraphitePreviewContext(fieldMocks: ["selectedLanguage": "ja"])
                    )
                )
            ]
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero-lead",
                "internalID": "lead-node",
                "tagName": "leadtext",
                "type": "text",
                "textContent": "現在 ja",
                "fallbackTextContent": "HTML fallback",
                "textSource": "binding",
                "i18nKey": "home.hero.lead",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero-lead")
        let node = try #require(store.nodes.first)
        let inspection = try #require(store.selectedI18nRuntimeInspection)

        // 検証内容：別 locale の resource 値を読み取り、入力中 preview と確定保存を eng に対して行う
        let values = store.i18nTextResourceValues(for: node, inspection: inspection)
        let previewAccepted = store.previewActiveResolvedTextContent("Typing English", locale: "eng")
        let saveAccepted = store.updateActiveResolvedTextContent("Updated English", locale: "eng")

        // 期待値：eng resource だけが更新され、ja 表示中の cache と WebView mutation は変更されない
        let jaResource = try Self.localeJSON(at: localeDirectory.appendingPathComponent("ja.json"))
        let engResource = try Self.localeJSON(at: localeDirectory.appendingPathComponent("eng.json"))
        #expect(values["ja"] == "現在 ja")
        #expect(values["eng"] == "Current English")
        #expect(previewAccepted == true)
        #expect(saveAccepted == true)
        #expect(jaResource["home.hero.lead"] as? String == "現在 ja")
        #expect(engResource["home.hero.lead"] as? String == "Updated English")
        #expect(store.nodes[0].textContent == "現在 ja")
        #expect(store.textMutation == nil)
    }

    /// 論理名（日本語）: 固定HTML同期対象保存テスト
    /// 概要: 選択ページが切り替わっても、object edit は capture 済み HTML target へ保存されることを検証します。
    @Test("object editは選択切替後も固定targetへ保存する")
    func testObjectEditPersistsToCapturedTargetAfterSelectionChanges() throws {
        // コンディション：home と downloads を持つ一時プロジェクトを開き、home の同期対象を取得する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        try """
        <!doctype html>
        <html><body><Title data-og-id="home-title" data-og-internal-id="home-title-node" data-og-type="text">home</Title></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try """
        <!doctype html>
        <html><body><Title data-og-id="downloads-title" data-og-internal-id="downloads-title-node" data-og-type="text">downloads</Title></body></html>
        """.write(to: downloadsURL, atomically: true, encoding: .utf8)
        try fixture.writeProject(
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ]
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let homePage = try #require(store.loadedProject?.project.allPages.first)
        let homeTarget = try #require(store.htmlSyncTarget(for: homePage, segment: .pages))
        let downloadsInternalID = try #require(store.loadedProject?.project.allPages.last?.internalID)

        // 検証内容：選択を downloads へ切り替えた後、home target へ text object edit を保存する
        store.selectPage(internalID: downloadsInternalID)
        let result = store.applyHTMLObjectEditPayload(
            [
                "operation": "setTextContent",
                "nodeInternalID": "home-title-node",
                "value": "home edited",
                "previousValue": "home"
            ],
            target: homeTarget
        )
        let homeHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let downloadsHTML = try String(contentsOf: downloadsURL, encoding: .utf8)

        // 期待値：現在選択中の downloads ではなく、capture 済み home HTML だけが更新される
        #expect(result.updated == true)
        #expect(store.selectedPageURL == downloadsURL)
        #expect(homeHTML.contains("home edited"))
        #expect(downloadsHTML.contains("downloads"))
        #expect(!downloadsHTML.contains("home edited"))
    }

    /// 論理名（日本語）: オートレイアウト順序保存テスト
    /// 概要: drag reorder 相当の `moveNode` payload で同じ auto layout 内の sibling order が HTML に保存されることを検証します。
    @Test("moveNode payloadでauto layout内の順序を保存する")
    func testObjectEditMoveNodePayloadPersistsAutoLayoutOrder() throws {
        // コンディション：縦方向 auto layout に 3 つの sibling node を持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Stack data-og-id="stack" data-og-internal-id="stack-node" data-og-type="frame" style="display:flex; flex-direction:column;">
            <First data-og-id="first" data-og-internal-id="first-node" data-og-type="frame">First</First>
            <Second data-og-id="second" data-og-internal-id="second-node" data-og-type="frame">Second</Second>
            <Third data-og-id="third" data-og-internal-id="third-node" data-og-type="frame">Third</Third>
          </Stack>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try #require(store.loadedProject?.project.allPages.first)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))

        // 検証内容：drag drop 後の bridge と同じ形式で second を third の後ろへ移動する（When）
        let result = store.applyHTMLObjectEditPayload(
            [
                "operation": "moveNode",
                "nodeInternalID": "second-node",
                "targetInternalID": "third-node",
                "position": "after"
            ],
            target: target
        )
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let firstRange = try #require(diskHTML.range(of: "data-og-id=\"first\""))
        let thirdRange = try #require(diskHTML.range(of: "data-og-id=\"third\""))
        let secondRange = try #require(diskHTML.range(of: "data-og-id=\"second\""))

        // 期待値：HTML の sibling order が first, third, second になり、WebView reload なしで継続できる移動として扱われる（Then）
        #expect(result.updated == true)
        #expect(result.requiresReload == false)
        #expect(firstRange.lowerBound < thirdRange.lowerBound)
        #expect(thirdRange.lowerBound < secondRange.lowerBound)
    }

    /// 論理名（日本語）: フレーム配置payload保存テスト
    /// 概要: frame tool のドラッグ配置と同じ `insertHTML` payload で、選択中親の直下へ座標付き frame が保存されることを確認します。
    @Test("frame配置payloadで選択親直下へ座標付きframeを保存する")
    func testObjectEditInsertHTMLPayloadPersistsPlacedFrameUnderSelectedParent() throws {
        // コンディション：page root だけを持つ一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <OpenGraphitePage data-og-id="page" data-og-internal-id="page-node" data-og-type="page" style="display:flex; flex-direction:column;"></OpenGraphitePage>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try #require(store.loadedProject?.project.allPages.first)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))
        let frameHTML = """
        <OpenGraphiteFrame data-og-id="frame" data-og-internal-id="frame-node" data-og-type="frame" style="display: flex; flex-direction: column; gap: 0; padding: 0; position: absolute; left: 12px; top: 24px; width: 160px; height: 90px;"></OpenGraphiteFrame>
        """

        // 検証内容：WebView bridge 由来の insertHTML payload を保存する（When）
        let result = store.applyHTMLObjectEditPayload(
            [
                "operation": "insertHTML",
                "selectedID": "frame",
                "anchorInternalID": "page-node",
                "position": "append",
                "html": frameHTML
            ],
            target: target
        )
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()
        let insertedFrameNode = try #require(
            OpenGraphiteHTMLDocument(html: diskHTML).nodes().first { $0.id == "frame" }
        )
        let pageRange = try #require(diskHTML.range(of: "data-og-id=\"page\""))
        let frameRange = try #require(diskHTML.range(of: "data-og-id=\"frame\""))

        // 期待値：frame が page root の後続範囲へ保存され、ドラッグ矩形の座標とサイズを companion CSS に保持する（Then）
        #expect(result.updated == true)
        #expect(result.requiresReload == true)
        #expect(insertedFrameNode.parentID == "page")
        #expect(pageRange.lowerBound < frameRange.lowerBound)
        #expect(!diskHTML.contains("style="))
        #expect(diskCSS.contains(#"[data-og-internal-id="frame-node"]"#))
        #expect(diskCSS.contains("position: absolute;"))
        #expect(diskCSS.contains("left: 12px;"))
        #expect(diskCSS.contains("top: 24px;"))
        #expect(diskCSS.contains("width: 160px;"))
        #expect(diskCSS.contains("height: 90px;"))
    }

    /// 論理名（日本語）: 親標準layout変更時の子位置宣言保持テスト
    /// 概要: 親の標準displayをflowへ変更しても、各childが所有するposition/inset宣言とlegacy inputを暗黙変更しないことを確認します。
    @Test("親を標準flowへ変更してもchildごとのpositionを保持する")
    func testStandardLayoutChangePreservesPerChildPositionDeclarations() throws {
        // コンディション：legacy layout inputとabsolute配置childが共存する一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <OpenGraphitePage data-og-id="page" data-og-internal-id="page-node" data-og-type="page" data-og-layout="absolute">
            <OpenGraphiteFrame data-og-id="frame" data-og-internal-id="frame-node" data-og-type="frame"></OpenGraphiteFrame>
            <Wrapper data-og-id="wrapper" data-og-internal-id="wrapper-node" data-og-type="frame">
              <Nested data-og-id="nested" data-og-internal-id="nested-node" data-og-type="frame"></Nested>
            </Wrapper>
          </OpenGraphitePage>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="frame-node"] {
              position: absolute;
              left: 12px;
              top: 24px;
              width: 160px;
              height: 90px;
            }

            [data-og-internal-id="wrapper-node"] {
              position: absolute;
              left: 40px;
              top: 50px;
              width: 320px;
            }

            [data-og-internal-id="nested-node"] {
              position: absolute;
              left: 4px;
              top: 8px;
              width: 64px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)

        // 検証内容：WebView bridge由来の標準display/flex-direction変更payloadを保存する（When）
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))
        let result = store.applyHTMLObjectEditPayload(
            [
                "operation": "setCSSVariables",
                "nodeInternalID": "page-node",
                "values": ["display": "flex", "flex-direction": "column"],
                "previousValues": ["display": "", "flex-direction": ""]
            ],
            target: target
        )
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let cssDocument = OpenGraphiteCompanionCSSDocument(css: try fixture.readCompanionCSS())
        let frameCSS = cssDocument.cssVariables(forNodeInternalID: "frame-node")
        let wrapperCSS = cssDocument.cssVariables(forNodeInternalID: "wrapper-node")
        let nestedCSS = cssDocument.cssVariables(forNodeInternalID: "nested-node")
        let pageCSS = cssDocument.cssVariables(forNodeInternalID: "page-node")

        // 期待値：親だけが標準flowになり、legacy属性と全childのposition/insetはbyte-preservingに残る（Then）
        #expect(result.updated == true)
        #expect(result.requiresReload == true)
        #expect(diskHTML.contains(#"data-og-layout="absolute""#))
        #expect(pageCSS["display"] == "flex")
        #expect(pageCSS["flex-direction"] == "column")
        #expect(frameCSS["position"] == "absolute")
        #expect(frameCSS["left"] == "12px")
        #expect(frameCSS["top"] == "24px")
        #expect(frameCSS["width"] == "160px")
        #expect(wrapperCSS["position"] == "absolute")
        #expect(wrapperCSS["left"] == "40px")
        #expect(wrapperCSS["top"] == "50px")
        #expect(wrapperCSS["width"] == "320px")
        #expect(nestedCSS["position"] == "absolute")
        #expect(nestedCSS["left"] == "4px")
        #expect(nestedCSS["top"] == "8px")
    }

    /// 論理名（日本語）: Inspector標準layout編集cache分離テスト
    /// 概要: Inspectorのauthored display更新とWebKit computed layoutを分離し、child位置cacheを変更しないことを確認します。
    @Test("Inspectorの標準layout編集はcomputed値とchild positionを混同しない")
    func testInspectorStandardLayoutEditKeepsComputedStateAndChildPosition() async throws {
        // コンディション：computed block親とabsolute childのauthored declarationをApp cacheへ取り込む（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <OpenGraphitePage data-og-id="page" data-og-internal-id="page-node" data-og-type="page">
            <OpenGraphiteFrame data-og-id="frame" data-og-internal-id="frame-node" data-og-type="frame"></OpenGraphiteFrame>
          </OpenGraphitePage>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="frame-node"] {
              position: absolute;
              left: 12px;
              top: 24px;
              width: 160px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "page",
                "internalID": "page-node",
                "tagName": "opengraphitepage",
                "type": "page",
                "layout": "block",
                "computedStyle": ["display": "block", "position": "static", "visibility": "visible"],
                "cssVariables": [String: String](),
                "depth": 0
            ],
            [
                "id": "frame",
                "internalID": "frame-node",
                "tagName": "opengraphiteframe",
                "type": "frame",
                "layout": "block",
                "computedStyle": ["display": "block", "position": "absolute", "visibility": "visible"],
                "cssVariables": [
                    "position": "absolute",
                    "left": "12px",
                    "top": "24px",
                    "width": "160px"
                ],
                "depth": 1
            ]
        ])
        store.selectNode(id: "page")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：Inspector相当の標準CSS編集でhorizontal flexへ切り替える（When）
        store.updateSelectedNodeLayout(mode: "horizontal")
        let cssDocument = OpenGraphiteCompanionCSSDocument(css: try fixture.readCompanionCSS())
        let frameCSS = cssDocument.cssVariables(forNodeInternalID: "frame-node")
        let cachedFrame = try #require(store.nodes.first { $0.id == "frame" })

        let cachedPage = try #require(store.nodes.first { $0.id == "page" })

        // 期待値：authored値だけを更新してcomputed layoutは再収集までblockのまま、child positionとsourceは保持される（Then）
        #expect(cachedPage.layout == "block")
        #expect(cachedPage.computedStyle.display == "block")
        #expect(cachedPage.cssVariables["display"] == "flex")
        #expect(cachedPage.cssVariables["flex-direction"] == "row")
        #expect(frameCSS["position"] == "absolute")
        #expect(frameCSS["left"] == "12px")
        #expect(frameCSS["top"] == "24px")
        #expect(frameCSS["width"] == "160px")
        #expect(cachedFrame.cssVariables["position"] == "absolute")
        #expect(cachedFrame.cssVariables["left"] == "12px")
        #expect(cachedFrame.cssVariables["top"] == "24px")
        #expect(cachedFrame.cssVariables["width"] == "160px")
        #expect(store.cssVariablesMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(store.documentReplacementRequest == nil)
    }

    /// 論理名（日本語）: Responsive project CSS winner編集テスト
    /// 概要: WebKitがmatchしたproject CSS media winnerを同じat-rule scopeのcompanion overrideへ保存し、base viewportのproject winnerを保つことを確認します。
    @Test("Inspectorはactive project CSS winnerをmedia scoped companion overrideで編集する")
    func testInspectorUpdatesOnlyActiveMediaLayoutWinner() async throws {
        // コンディション：base blockとactive media内horizontal flexが同じnodeへ適用されるprojectを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html><html><body>
          <main id="responsive" data-og-id="responsive" data-og-internal-id="responsive-node"></main>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let projectCSS = """
        #responsive {
          display: block;
          flex-direction: column;
        }

        @media (max-width: 500px) {
          #responsive {
            display: flex;
            flex-direction: row;
          }
        }
        """
        let projectCSSURL = fixture.rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        try FileManager.default.createDirectory(
            at: projectCSSURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try projectCSS.write(to: projectCSSURL, atomically: true, encoding: .utf8)
        let originalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "responsive",
                "standardID": "responsive",
                "internalID": "responsive-node",
                "tagName": "main",
                "type": "",
                "layout": "horizontal",
                "computedStyle": [
                    "display": "flex",
                    "flexDirection": "row",
                    "position": "static",
                    "visibility": "visible"
                ],
                "activeMediaQueries": ["(max-width: 500px)"],
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "responsive")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：layout tile相当でmobile active mediaをgridへ変更してproject-aware保存経路を実行する（When）
        store.updateSelectedNodeLayout(mode: "grid")
        let updatedCompanionCSS = try fixture.readCompanionCSS()
        let unchangedProjectCSS = try String(contentsOf: projectCSSURL, encoding: .utf8)
        let unchangedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let node = try #require(store.nodes.first { $0.id == "responsive" })
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let baseGraph = try core.pageGraph(projectURL: fixture.projectURL, pageID: page.internalID)
        let mobileGraph = try core.pageGraph(
            projectURL: fixture.projectURL,
            pageID: page.internalID,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let baseResponsiveLayout = baseGraph.nodes.filter { $0.attributes["id"] == "responsive" }.first?.layout
        let mobileResponsiveLayout = mobileGraph.nodes.filter { $0.attributes["id"] == "responsive" }.first?.layout

        // 期待値：project CSS/HTMLを不変に保ち、mobileだけgrid、base viewportはblockとなるreload専用保存になる（Then）
        #expect(unchangedProjectCSS == projectCSS)
        #expect(unchangedHTML == originalHTML)
        #expect(updatedCompanionCSS.contains("#responsive"))
        #expect(updatedCompanionCSS.contains("@media (max-width: 500px)"))
        #expect(updatedCompanionCSS.contains("display: grid;"))
        #expect(!updatedCompanionCSS.contains("flex-direction"))
        #expect(node.layout == "horizontal")
        #expect(node.computedStyle.display == "flex")
        #expect(node.cssVariables["display"] == "grid")
        #expect(baseResponsiveLayout == "block")
        #expect(mobileResponsiveLayout == "grid")
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
    }

    /// 論理名（日本語）: Standard hidden属性最小差分テスト
    /// 概要: source intentの標準hiddenだけを明示toggleし、legacy属性と未知属性を暗黙変更しないことを確認します。
    @Test("standard hidden toggleはsource-aware最小差分でlegacy inputを保持する")
    func testStandardHiddenTogglePreservesLegacyAndUnknownAttributes() throws {
        // コンディション：bare hidden、legacy hidden metadata、未知属性と不規則triviaが共存するnodeを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body>
          <main data-vendor='/keep' hidden  data-og-hidden="true" data-og-id="target" data-og-internal-id="target-node">Target</main>
        </body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))

        // 検証内容：WebCanvas toggleと同じ標準hidden remove/add payloadを順に保存する（When）
        let removal = store.applyHTMLObjectEditPayload(
            [
                "operation": "setAttribute",
                "removeAttribute": true,
                "nodeInternalID": "target-node",
                "name": "hidden",
                "value": "",
                "previousValue": "",
                "previousAttributePresent": true
            ],
            target: target
        )
        let removedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let addition = store.applyHTMLObjectEditPayload(
            [
                "operation": "setAttribute",
                "nodeInternalID": "target-node",
                "name": "hidden",
                "value": "hidden",
                "previousValue": "",
                "previousAttributePresent": false
            ],
            target: target
        )
        let addedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：標準hiddenだけが変化し、legacy/未知属性と周辺source表現は保持される（Then）
        #expect(removal.updated)
        #expect(!removedHTML.contains(" hidden  data-og-hidden"))
        #expect(removedHTML.contains("data-vendor='/keep'"))
        #expect(removedHTML.contains("data-og-hidden=\"true\""))
        #expect(addition.updated)
        #expect(addedHTML.contains("hidden=\"hidden\""))
        #expect(addedHTML.contains("data-vendor='/keep'"))
        #expect(addedHTML.contains("data-og-hidden=\"true\""))
    }

    /// 論理名（日本語）: Standard hidden存在baseline履歴テスト
    /// 概要: mixed-case until-foundとbare hiddenを値ではなく属性存在で競合判定し、最小差分をUndo/Redoできることを確認します。
    @Test("mixed-case until-foundとbare hidden toggleは最小差分でundo redoできる")
    func testStandardHiddenToggleUsesPresenceBaselineAndSupportsHistory() async throws {
        // コンディション：値付きmixed-case hiddenとbare hiddenを不規則なtrivia付きで持つ2 nodeを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body>
          <main data-vendor=/keep HiDdEn = 'UnTiL-FoUnD' data-og-id="until" data-og-internal-id="until-node">Until</main>
          <section data-vendor="bare" hidden  data-og-id="bare" data-og-internal-id="bare-node">Bare</section>
        </body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "until",
                "internalID": "until-node",
                "tagName": "main",
                "type": "",
                "layout": "block",
                "cssVariables": [String: String](),
                "hasHiddenAttribute": true,
                "depth": 0
            ],
            [
                "id": "bare",
                "internalID": "bare-node",
                "tagName": "section",
                "type": "",
                "layout": "block",
                "cssVariables": [String: String](),
                "hasHiddenAttribute": true,
                "depth": 0
            ]
        ])

        // 検証内容：until-foundをInspector経路で解除してUndo/Redoし、続けてbare hiddenも解除してUndo/Redoする（When）
        store.selectNode(id: "until")
        store.removeNodeAttribute(name: "hidden")
        let untilRemovedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.undoDocumentChange()
        let untilUndoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.redoDocumentChange()
        let untilRedoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        store.selectNode(id: "bare")
        store.removeNodeAttribute(name: "hidden")
        let bothRemovedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.undoDocumentChange()
        let bareUndoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        store.redoDocumentChange()
        let bareRedoHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：until-foundのsemantic値に関係なく存在baselineが一致し、対象tokenだけを除去する（Then）
        let expectedUntilRemovedHTML = originalHTML.replacingOccurrences(
            of: " HiDdEn = 'UnTiL-FoUnD'",
            with: ""
        )
        #expect(untilRemovedHTML == expectedUntilRemovedHTML)
        #expect(untilUndoHTML == originalHTML)
        #expect(untilRedoHTML == expectedUntilRemovedHTML)

        // 期待値：bare属性も空値とabsentを区別して解除され、各履歴snapshotをbyte単位で復元する（Then）
        let expectedBothRemovedHTML = expectedUntilRemovedHTML.replacingOccurrences(of: " hidden", with: "")
        #expect(bothRemovedHTML == expectedBothRemovedHTML)
        #expect(bareUndoHTML == expectedUntilRemovedHTML)
        #expect(bareRedoHTML == expectedBothRemovedHTML)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 不完全CSS provenance編集拒否テスト
    /// 概要: 読み取り不能stylesheetを含むnodeはcomputed inspectionを維持しつつCSS set/removeをno-writeで拒否し、標準属性編集は許可します。
    @Test("不完全CSS provenance nodeはstyle変更だけをno-writeで拒否する")
    func testIncompleteCSSProvenanceRejectsStyleMutationsButAllowsAttributes() async throws {
        // コンディション：WebKitが読み取り不能sheetを報告したstable nodeとauthored companion CSSを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body>
          <main id="target" data-og-id="target" data-og-internal-id="target-node">Target</main>
        </body></html>
        """
        let originalCSS = """
        #target {
          display: grid;
          color: rgb(1, 2, 3);
        }
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(originalCSS)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))
        await store.ingestNodePayloadAndWait([
            [
                "id": "target",
                "standardID": "target",
                "internalID": "target-node",
                "tagName": "main",
                "type": "",
                "layout": "grid",
                "computedStyle": [
                    "display": "grid",
                    "flexDirection": "row",
                    "position": "static",
                    "visibility": "visible"
                ],
                "unreadableStyleSheetCount": 1,
                "cssVariables": ["display": "grid", "color": "rgb(1, 2, 3)"],
                "hasHiddenAttribute": false,
                "depth": 0
            ]
        ])
        store.selectNode(id: "target")

        // 検証内容：Inspector set/removeとWebCanvas payload経路でCSS変更を試し、その後standard hiddenだけを追加する（When）
        store.updateCSSVariable(key: "display", value: "flex")
        store.updateCSSVariable(key: "color", value: "")
        let payloadResult = store.applyHTMLObjectEditPayload(
            [
                "operation": "setCSSVariables",
                "nodeInternalID": "target-node",
                "values": ["position": "absolute"],
                "previousValues": ["position": ""]
            ],
            target: target
        )
        let htmlAfterCSSAttempts = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let cssAfterCSSAttempts = try fixture.readCompanionCSS()
        let inspectedNode = try #require(store.selectedNode)
        let cssError = store.lastError
        store.updateNodeAttribute(name: "hidden", value: "hidden")
        let htmlAfterAttributeEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：computed値と不完全provenance statusはinspection可能なまま全CSS経路が明示失敗し、source bytesを変えない（Then）
        #expect(inspectedNode.computedStyle.display == "grid")
        #expect(inspectedNode.hasIncompleteCSSProvenance)
        #expect(!payloadResult.updated)
        #expect(cssError?.contains("stylesheet") == true)
        #expect(htmlAfterCSSAttempts == originalHTML)
        #expect(cssAfterCSSAttempts == originalCSS)
        #expect(store.cssMutation == nil)
        #expect(store.cssVariablesMutation == nil)

        // 期待値：CSS provenanceに依存しない標準hidden source intentは別経路で最小追加できる（Then）
        #expect(htmlAfterAttributeEdit == originalHTML.replacingOccurrences(
            of: " data-og-internal-id=\"target-node\"",
            with: " data-og-internal-id=\"target-node\" hidden=\"hidden\""
        ))
        #expect(try fixture.readCompanionCSS() == originalCSS)
    }

    /// 論理名（日本語）: Shared source provenance統合テスト
    /// 概要: WebKit payloadが読取不能sheetを報告しない場合も、Shared source graphの不完全statusをOR統合してCSS保存を拒否します。
    @Test("Shared sourceが不完全なnodeはWebKit報告がなくてもCSS編集を拒否する")
    func testSourceIncompleteCSSProvenanceIsMergedWithoutWebKitReport() async throws {
        // コンディション：headless source resolverだけが読めない外部stylesheetと、読み取り可能なcompanion CSSを持つnodeを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><head>
          <link rel="stylesheet" href="https://cdn.example.test/unknown.css">
        </head><body>
          <main id="target" data-og-id="target" data-og-internal-id="target-node">Target</main>
        </body></html>
        """
        let originalCSS = "#target { display: block; }\n"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(originalCSS)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "target",
                "standardID": "target",
                "internalID": "target-node",
                "tagName": "main",
                "type": "",
                "computedStyle": [
                    "display": "block",
                    "position": "static",
                    "visibility": "visible"
                ],
                "unreadableStyleSheetCount": 0,
                "cssVariables": ["display": "block"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "target")
        let mergedNode = try #require(store.selectedNode)

        // 検証内容：WebKit由来countが0のまま標準displayを更新しようとする（When）
        store.updateCSSVariable(key: "display", value: "grid")
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let finalCSS = try fixture.readCompanionCSS()

        // 期待値：Shared source statusがnodeへOR統合され、computed inspectionを保ったままsourceはno-writeになる（Then）
        #expect(mergedNode.hasIncompleteCSSProvenance)
        #expect(mergedNode.computedStyle.display == "block")
        #expect(finalHTML == originalHTML)
        #expect(finalCSS == originalCSS)
        #expect(store.cssMutation == nil)
        #expect(store.lastError?.contains("stylesheet") == true)
    }

    /// 論理名（日本語）: 同時編集競合拒否テスト
    /// 概要: agent 相当の同一 node 更新が先に入った場合、Inspector 保存で上書きしないことを検証します。
    @Test("同一nodeが外部更新済みならobject editで上書きしない")
    func testObjectEditRejectsConflictingNodeUpdate() async throws {
        // コンディション：Store が把握した CSS 値と、ディスク上の最新 CSS 値がずれている状態を作る
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 16px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "hero",
                "type": "frame",
                "cssVariables": ["gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 24px;
            }
            """
        )

        // 検証内容：古い Store 状態をもとに CSS 値を更新しようとする
        store.updateCSSVariable(key: "gap", value: "32px")
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：agent 相当の 24px は上書きされず、再設定を促す簡易エラーが表示される
        #expect(diskCSS.contains("gap: 24px;"))
        #expect(!diskCSS.contains("gap: 32px;"))
        #expect(store.cssMutation == nil)
        #expect(store.lastError == "HTMLが別の編集で更新されています。ページを再読み込みしてからもう一度設定してください。")
    }

    /// 論理名（日本語）: 同時CSS削除競合拒否テスト
    /// 概要: agent 相当の同一 CSS declaration 削除が先に入った場合、Inspector 保存で復元上書きしないことを検証します。
    @Test("同一CSS declarationが外部削除済みならobject editで上書きしない")
    func testObjectEditRejectsConflictingCSSDeletion() async throws {
        // コンディション：Store が把握した CSS declaration を、別経路の編集で削除済みにする
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 16px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "hero",
                "type": "frame",
                "cssVariables": ["gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")
        try fixture.writeCompanionCSS("")

        // 検証内容：古い Store 状態をもとに削除済み CSS declaration を更新しようとする
        store.updateCSSVariable(key: "gap", value: "32px")
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：削除済み declaration は復元上書きされず、再設定を促す簡易エラーが表示される
        #expect(!diskCSS.contains("gap: 16px;"))
        #expect(!diskCSS.contains("gap: 32px;"))
        #expect(store.cssMutation == nil)
        #expect(store.lastError == "HTMLが別の編集で更新されています。ページを再読み込みしてからもう一度設定してください。")
    }

    /// 論理名（日本語）: CSS宣言同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ CSS 値の mutation が増えないことを検証します。
    @Test("同じCSS宣言値の再適用ではmutationを発行しない")
    func testUpdateCSSVariableSkipsUnchangedValue() throws {
        // コンディション：既存 CSS declaration を持つ選択中ノードを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="hero-node"] {
              gap: 16px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：同じ値を空白付きで再適用する
        store.updateCSSVariable(key: "gap", value: " 16px ")

        // 期待値：値は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].cssVariables["gap"] == "16px")
        #expect(store.cssMutation == nil)
    }

    /// 論理名（日本語）: ノード属性同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ属性値の mutation が増えないことを検証します。
    @Test("同じノード属性値の再適用ではmutationを発行しない")
    func testUpdateNodeAttributeSkipsUnchangedValue() throws {
        // コンディション：role を持つ選択中ノードを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><MainTitle data-og-id="title" data-og-internal-id="title-node" data-og-type="text" role="title">Title</MainTitle></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "internalID": "title-node",
                "tagName": "maintitle",
                "type": "text",
                "role": "title",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：同じ role を同じauthored値で再適用する
        store.updateNodeAttribute(name: "role", value: "title")

        // 期待値：属性は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].role == "title")
        #expect(store.attributeMutation == nil)
    }

    /// 論理名（日本語）: ノード表示ID更新テスト
    /// 概要: Layers のインライン編集が `data-og-id` を正規化して HTML 正本へ保存し、WebView 反映 mutation を発行することを検証します。
    @Test("Layersからノード表示IDを変更できる")
    func testUpdateNodeDisplayIDRenamesDataOGID() throws {
        // コンディション：表示 ID を持つ選択中ノードを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero>
          <Card data-og-id="card" data-og-internal-id="card-node" data-og-type="frame"></Card>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "hero",
                "type": "frame",
                "depth": 0
            ],
            [
                "id": "card",
                "internalID": "card-node",
                "tagName": "card",
                "type": "frame",
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：空白を含む名前を Layers 相当で確定する
        store.updateNodeDisplayID(value: "Hero Card")
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：正規化された data-og-id が保存され、WebView 反映用 mutation は旧選択 ID を対象にする
        #expect(diskHTML.contains(#"data-og-id="hero-card""#))
        #expect(!diskHTML.contains(#"data-og-id="hero""#))
        #expect(store.attributeMutation?.nodeID == "hero")
        #expect(store.attributeMutation?.name == "data-og-id")
        #expect(store.attributeMutation?.value == "hero-card")
    }

    /// 論理名（日本語）: ノード表示ID重複拒否テスト
    /// 概要: Layers のインライン編集で既存 `data-og-id` と重複する名前を指定しても HTML 正本を変更しないことを検証します。
    @Test("重複するノード表示IDは保存しない")
    func testUpdateNodeDisplayIDRejectsDuplicateDataOGID() throws {
        // コンディション：同一 HTML に複数ノードがある状態を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Hero data-og-id="hero" data-og-internal-id="hero-node" data-og-type="frame"></Hero>
          <Card data-og-id="card" data-og-internal-id="card-node" data-og-type="frame"></Card>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "hero",
                "type": "frame",
                "depth": 0
            ],
            [
                "id": "card",
                "internalID": "card-node",
                "tagName": "card",
                "type": "frame",
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：既存ノードと同じ表示 ID へ変更しようとする
        store.updateNodeDisplayID(value: "card")
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：HTML は元の ID のままで、WebView 反映用 mutation も発行されない
        #expect(diskHTML.contains(#"data-og-id="hero""#))
        #expect(diskHTML.contains(#"data-og-id="card""#))
        #expect(store.attributeMutation == nil)
    }

    /// 論理名（日本語）: Runtime展開ノード表示ID更新テスト
    /// 概要: runtime component 由来ノードの表示 ID 更新が、表示中 Page ではなく component master HTML へ保存されることを検証します。
    @Test("runtime展開ノードの表示ID変更はcomponent masterへ保存する")
    func testUpdateNodeDisplayIDForGeneratedComponentUsesSourcePageURL() throws {
        // コンディション：component master と page instance を持つ一時プロジェクトを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try """
        <!doctype html>
        <html><body>
        <site-header data-og-id="site-header" data-og-internal-id="site-header-node" data-og-component="site-header"><template></template></site-header>
        </body></html>
        """.write(to: componentURL, atomically: true, encoding: .utf8)
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(x: 200, y: 0, width: 100, height: 100)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "site-header",
                "internalID": "site-header-node",
                "tagName": "siteheader",
                "type": "frame",
                "sourceComponentID": "site-header",
                "sourceInstanceID": "site-header-instance",
                "depth": 0
            ]
        ])
        store.selectNode(id: "site-header")

        // 検証内容：runtime 展開ノードの表示 ID を変更する（When）
        store.updateNodeDisplayID(value: "global-header")
        let componentHTML = try String(contentsOf: componentURL, encoding: .utf8)
        let pageHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：component master HTML が更新され、DOM 反映 mutation も component URL を対象にする（Then）
        #expect(componentHTML.contains(#"data-og-id="global-header""#))
        #expect(!componentHTML.contains(#"data-og-id="site-header""#))
        #expect(pageHTML == "<!doctype html>\n<html><body>initial</body></html>")
        #expect(store.attributeMutation?.pageURL.standardizedFileURL == componentURL.standardizedFileURL)
        #expect(store.attributeMutation?.nodeID == "site-header")
        #expect(store.attributeMutation?.value == "global-header")
    }

    /// 論理名（日本語）: アイコンInspector更新テスト
    /// 概要: Storeのicon更新がprovenance metadata、標準mask描画HTML/CSS、置換要求を同時に更新することを検証します。
    @Test("Storeのicon更新はHTML置換要求を発行する")
    func testUpdateIconPersistsMarkupAndRequestsReplacement() async throws {
        // コンディション：icon node を含む一時プロジェクトを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <Icon data-og-id="decorative-icon" data-og-internal-id="decorative-icon-node" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline" style="--og-icon-url:url('legacy.svg');">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
          </Icon>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "decorative-icon",
                "internalID": "decorative-icon-node",
                "tagName": "icon",
                "type": "icon",
                "iconLibrary": "lucide",
                "iconName": "circle",
                "iconSource": "inline",
                "depth": 0
            ]
        ])
        store.selectNode(id: "decorative-icon")

        // 検証内容：Inspector 相当で source/name を更新する（When）
        store.updateIcon(library: "lucide", name: "star", source: "cdn")
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：ディスク HTML と Store node が更新され、WebView 置換要求が発行される（Then）
        #expect(store.nodes[0].iconName == "star")
        #expect(store.nodes[0].iconSource == "cdn")
        #expect(diskHTML.contains("data-og-icon-name=\"star\""))
        #expect(diskHTML.contains("<span aria-hidden=\"true\"></span>"))
        #expect(!diskHTML.contains("data-og-icon-mask"))
        #expect(diskHTML.contains("--og-icon-url:url('legacy.svg')"))
        #expect(!diskHTML.contains("https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg"))
        #expect(diskCSS.contains("[data-og-internal-id=\"decorative-icon-node\"] > span"))
        #expect(diskCSS.contains("\n  mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(diskCSS.contains("\n  -webkit-mask-image: url('https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/star.svg');"))
        #expect(!diskCSS.contains("--og-icon-url"))
        #expect(store.documentReplacementRequest?.html == diskHTML)
        #expect(store.documentReplacementRequest?.selectedNodeID == "decorative-icon")
    }

    /// 論理名（日本語）: 描画実体標準CSS編集テスト
    /// 概要: wrapper選択時にShared graphとWebCanvas computed payloadを統合し、media/SVG/mask実体のcascade winnerだけを標準propertyで編集することを検証します。
    @Test("wrapperからmedia/icon実体の標準CSSを最小差分編集する")
    func testUpdateRelatedStyleDeclarationsUsesRenderingTargetProvenance() async throws {
        // コンディション：標準id/cascadeを持つmedia、SVG、mask実体と未移行legacy inputを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let authoredHTML = """
        <!doctype html>
        <html><body>
          <MediaFrame id="media-wrapper" data-og-id="media" data-og-internal-id="media-node" data-og-type="image">
            <img id="hero-image" src="hero.png" alt="Hero">
          </MediaFrame>
          <InlineIcon id="inline-icon" data-og-id="inline-icon" data-og-internal-id="inline-icon-node" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="circle" data-og-icon-source="inline">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle></svg>
          </InlineIcon>
          <MaskIcon id="mask-icon" data-og-id="mask-icon" data-og-internal-id="mask-icon-node" data-og-type="icon" data-og-icon-library="lucide" data-og-icon-name="star" data-og-icon-source="cdn">
            <span id="mask-glyph" data-og-icon-mask="true" aria-hidden="true"></span>
          </MaskIcon>
        </body></html>
        """
        try authoredHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            /* preserve media cascade */
            MediaFrame > img {
              object-fit: contain;
            }

            #hero-image {
              object-fit: cover !important;
            }

            #inline-icon > svg {
              stroke-width: 1.5;
            }

            #mask-glyph {
              -webkit-mask-image: url('https://cdn.example.test/icons/old.svg');
              mask-image: url('https://cdn.example.test/icons/old.svg');
            }

            [data-og-internal-id="media-node"] {
              --og-object-fit: legacy-contain;
            }

            [data-og-internal-id="inline-icon-node"] {
              --og-stroke-width: 9;
            }

            [data-og-internal-id="mask-icon-node"] {
              --og-icon-url: url('legacy-mask.svg');
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "media",
                "internalID": "media-node",
                "tagName": "mediaframe",
                "type": "image",
                "renderingTargets": [[
                    "kind": "media",
                    "tagName": "img",
                    "relation": "direct-child",
                    "relationSelector": ":scope > img",
                    "targetStandardID": "hero-image",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": ["object-fit": "cover"]
                ]],
                "depth": 0
            ],
            [
                "id": "inline-icon",
                "internalID": "inline-icon-node",
                "tagName": "inlineicon",
                "type": "icon",
                "iconLibrary": "lucide",
                "iconName": "circle",
                "iconSource": "inline",
                "renderingTargets": [[
                    "kind": "svg",
                    "tagName": "svg",
                    "relation": "direct-child",
                    "relationSelector": ":scope > svg",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": ["stroke-width": "1.5px"]
                ]],
                "depth": 0
            ],
            [
                "id": "mask-icon",
                "internalID": "mask-icon-node",
                "tagName": "maskicon",
                "type": "icon",
                "iconLibrary": "lucide",
                "iconName": "star",
                "iconSource": "cdn",
                "renderingTargets": [[
                    "kind": "mask",
                    "tagName": "span",
                    "relation": "direct-child",
                    "relationSelector": ":scope > span",
                    "targetStandardID": "mask-glyph",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": [
                        "mask-image": "url(\"https://cdn.example.test/icons/old.svg\")",
                        "-webkit-mask-image": "url(\"https://cdn.example.test/icons/old.svg\")"
                    ]
                ]],
                "depth": 0
            ]
        ])
        let initialMediaTarget = try #require(store.nodes[0].renderTarget(for: "object-fit"))
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：各wrapperを選択して実体の標準propertyを更新する（When）
        store.selectNode(id: "media")
        store.updateRelatedStyleDeclaration(property: "object-fit", value: "scale-down")
        store.selectNode(id: "inline-icon")
        store.updateRelatedStyleDeclaration(property: "stroke-width", value: "3")
        store.selectNode(id: "mask-icon")
        store.updateRelatedStyleDeclaration(
            property: "mask-image",
            value: "url('https://cdn.example.test/icons/new.svg')"
        )
        store.updateRelatedStyleDeclaration(
            property: "-webkit-mask-image",
            value: "url('https://cdn.example.test/icons/new.svg')"
        )
        let diskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：winnerのselector/scopeを保つ最小差分となり、computed graph/reloadは同期するがlegacy inputやchild annotationは暗黙変換しない（Then）
        #expect(initialMediaTarget.writeSelector == "#hero-image")
        #expect(initialMediaTarget.authoredValue == "cover")
        #expect(initialMediaTarget.computedValue == "cover")
        #expect(initialMediaTarget.winnerTrace?.selector == "#hero-image")
        #expect(diskCSS.contains("/* preserve media cascade */"))
        #expect(diskCSS.contains("object-fit: contain;"))
        #expect(diskCSS.contains("object-fit: scale-down !important;"))
        #expect(diskCSS.contains("stroke-width: 3;"))
        #expect(diskCSS.contains("\n  mask-image: url('https://cdn.example.test/icons/new.svg');"))
        #expect(diskCSS.contains("\n  -webkit-mask-image: url('https://cdn.example.test/icons/new.svg');"))
        #expect(diskCSS.contains("--og-object-fit: legacy-contain;"))
        #expect(diskCSS.contains("--og-stroke-width: 9;"))
        #expect(diskCSS.contains("--og-icon-url: url('legacy-mask.svg');"))
        #expect(diskHTML == authoredHTML)
        #expect(diskHTML.contains("data-og-icon-mask=\"true\""))
        #expect(!diskHTML.contains("data-og-internal-id=\"\""))
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 4)
        #expect(store.cssMutation == nil)

        // 検証内容：最後のvendor mask編集を履歴から取り消し、同じ変更をやり直す（When）
        store.undoDocumentChange()
        let undoCSS = try fixture.readCompanionCSS()
        store.redoDocumentChange()
        let redoCSS = try fixture.readCompanionCSS()

        // 期待値：HTML snapshotを変えず、companion CSSの対象宣言だけが履歴前後で復元される（Then）
        #expect(undoCSS.contains("\n  -webkit-mask-image: url('https://cdn.example.test/icons/old.svg');"))
        #expect(undoCSS.contains("\n  mask-image: url('https://cdn.example.test/icons/new.svg');"))
        #expect(redoCSS.contains("\n  -webkit-mask-image: url('https://cdn.example.test/icons/new.svg');"))
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == authoredHTML)
    }

    /// 論理名（日本語）: Responsive project描画実体CSS編集テスト
    /// 概要: active media内のproject `object-fit` winnerをproject-aware経路でcompanion overrideへ保存・削除します。
    @Test("responsive project object-fit winnerをmedia scoped companionで編集する")
    func testUpdateRelatedStyleDeclarationUsesProjectActiveMediaContext() async throws {
        // コンディション：project CSSのbase/mediaに異なるobject-fitを持つ未注釈img wrapperをmobile条件で表示する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let authoredHTML = """
        <!doctype html><html><body>
          <figure id="media-wrapper" data-og-id="media" data-og-internal-id="media-node">
            <img id="hero-image" src="hero.png" alt="Hero">
          </figure>
        </body></html>
        """
        let projectCSS = """
        #hero-image {
          object-fit: contain;
        }

        @media (max-width: 500px) {
          #hero-image {
            object-fit: cover;
          }
        }
        """
        try authoredHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let projectCSSURL = fixture.rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        try projectCSS.write(to: projectCSSURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "media",
                "standardID": "media-wrapper",
                "internalID": "media-node",
                "tagName": "figure",
                "type": "",
                "computedStyle": [
                    "display": "block",
                    "position": "static",
                    "visibility": "visible"
                ],
                "activeMediaQueries": ["(max-width: 500px)"],
                "renderingTargets": [[
                    "kind": "media",
                    "tagName": "img",
                    "relation": "direct-child",
                    "relationSelector": ":scope > img",
                    "targetStandardID": "hero-image",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": ["object-fit": "cover"]
                ]],
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "media")
        let initialTarget = try #require(store.selectedNode?.renderTarget(for: "object-fit"))
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：mobile winnerをscale-downへ上書きし、そのcompanion winnerを同じproject-aware経路で削除する（When）
        store.updateRelatedStyleDeclaration(property: "object-fit", value: "scale-down")
        let overriddenCompanionCSS = try fixture.readCompanionCSS()
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let overriddenMobileGraph = try core.pageGraph(
            projectURL: fixture.projectURL,
            pageID: page.internalID,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let overriddenTarget = overriddenMobileGraph.nodes
            .first { $0.internalID == "media-node" }?
            .renderingTargets.first { $0.kind == "media" }
        store.updateRelatedStyleDeclaration(property: "object-fit", value: "")
        let removedCompanionCSS = try fixture.readCompanionCSS()
        let baseGraph = try core.pageGraph(projectURL: fixture.projectURL, pageID: page.internalID)
        let restoredMobileGraph = try core.pageGraph(
            projectURL: fixture.projectURL,
            pageID: page.internalID,
            activeMediaQueries: ["(max-width: 500px)"]
        )
        let baseTarget = baseGraph.nodes
            .first { $0.internalID == "media-node" }?
            .renderingTargets.first { $0.kind == "media" }
        let restoredMobileTarget = restoredMobileGraph.nodes
            .first { $0.internalID == "media-node" }?
            .renderingTargets.first { $0.kind == "media" }

        // 期待値：project/HTMLは不変で、overrideは同じmedia scopeだけに存在し、削除後はviewport別project winnerへ戻る（Then）
        #expect(initialTarget.authoredValue == "cover")
        #expect(initialTarget.computedValue == "cover")
        #expect(overriddenCompanionCSS.contains("@media (max-width: 500px)"))
        #expect(overriddenCompanionCSS.contains("#hero-image"))
        #expect(overriddenCompanionCSS.contains("object-fit: scale-down;"))
        #expect(overriddenTarget?.authoredValues["object-fit"] == "scale-down")
        #expect(!removedCompanionCSS.contains("object-fit: scale-down"))
        #expect(baseTarget?.resolvedValues["object-fit"] == "contain")
        #expect(restoredMobileTarget?.resolvedValues["object-fit"] == "cover")
        #expect(try String(contentsOf: projectCSSURL, encoding: .utf8) == projectCSS)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == authoredHTML)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 2)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 描画実体標準CSS同時選択編集テスト
    /// 概要: 複数wrapperの標準property編集を実体selectorへ保存し、wrapper DOM mutationではなく単一reloadで反映することを検証します。
    @Test("同時選択したmedia wrapperのobject-fitは実体へ保存してreloadする")
    func testUpdateRelatedStyleDeclarationsForMultipleSelectionReloadsCanvas() async throws {
        // コンディション：異なる標準idのimg実体を持つ2つのwrapperとcompanion CSSを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let authoredHTML = """
        <!doctype html>
        <html><body>
          <MediaFrame data-og-id="hero" data-og-internal-id="hero-node" data-og-type="image"><img id="hero-image" src="hero.png" alt="Hero"></MediaFrame>
          <MediaFrame data-og-id="card" data-og-internal-id="card-node" data-og-type="image"><img id="card-image" src="card.png" alt="Card"></MediaFrame>
        </body></html>
        """
        try authoredHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            #hero-image {
              object-fit: cover;
            }

            #card-image {
              object-fit: contain;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "hero",
                "internalID": "hero-node",
                "tagName": "mediaframe",
                "type": "image",
                "renderingTargets": [[
                    "kind": "media",
                    "tagName": "img",
                    "relation": "direct-child",
                    "relationSelector": ":scope > img",
                    "targetStandardID": "hero-image",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": ["object-fit": "cover"]
                ]],
                "depth": 0
            ],
            [
                "id": "card",
                "internalID": "card-node",
                "tagName": "mediaframe",
                "type": "image",
                "renderingTargets": [[
                    "kind": "media",
                    "tagName": "img",
                    "relation": "direct-child",
                    "relationSelector": ":scope > img",
                    "targetStandardID": "card-image",
                    "targetInternalID": "",
                    "authoredInlineValues": [String: String](),
                    "computedValues": ["object-fit": "contain"]
                ]],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")
        store.selectNodeRange(to: "card", visibleNodeIDs: ["hero", "card"])
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        #expect(store.selectedNodeIDs == Set(["hero", "card"]))
        #expect(store.selectedLayerNodes.count == 2)
        #expect(store.nodes.allSatisfy { $0.renderTarget(for: "object-fit") != nil })

        // 検証内容：同時選択状態から標準object-fitを一括更新する（When）
        store.updateCSSVariable(key: "object-fit", value: "scale-down")
        let diskCSS = try fixture.readCompanionCSS()

        // 期待値：両img selectorとrender target cacheを更新し、wrapper mutationを発行せず一度だけreloadする（Then）
        #expect(diskCSS.components(separatedBy: "object-fit: scale-down;").count == 3)
        #expect(store.nodes.first { $0.id == "hero" }?.renderTarget(for: "object-fit")?.authoredValue == "scale-down")
        #expect(store.nodes.first { $0.id == "card" }?.renderTarget(for: "object-fit")?.authoredValue == "scale-down")
        #expect(store.cssVariablesBatchMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == authoredHTML)
        #expect(store.canUndo)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 複合CSS宣言更新テスト
    /// 概要: CSS shorthand や関数値を分解せず、HTML 正本へ戻す値としてそのまま保持することを検証します。
    @Test("複合CSS値をStoreで正規化しすぎずsourceへ保存できる")
    func testUpdateCSSVariablePreservesStructuredCSSValues() async throws {
        // コンディション：選択中ノードと、Inspector UIがparse / edit / serializeするCSS値を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><EditorPreview data-og-id="preview-card" data-og-internal-id="preview-node" data-og-type="frame"></EditorPreview></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        await store.ingestNodePayloadAndWait([
            [
                "id": "preview-card",
                "internalID": "preview-node",
                "tagName": "editorpreview",
                "type": "frame",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "preview-card")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)
        let cases: [(key: String, value: String)] = [
            ("width", "min(100%,560px)"),
            ("padding", "14px 20px"),
            ("background", "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)"),
            ("flex", "1 1 0"),
            ("position", "sticky"),
            ("left", "clamp(12px,4vw,48px)"),
            ("z-index", "10"),
            ("animation-name", "reveal-card"),
            ("animation-duration", "1ms"),
            ("animation-timeline", "view(inline 20% 80%)"),
            ("animation-range-start", "entry 0%"),
            ("animation-range-end", "cover 70%"),
            ("timeline-scope", "--hero-scroll"),
            ("scroll-timeline-name", "--hero-scroll"),
            ("scroll-timeline-axis", "inline"),
            ("view-timeline-name", "--hero-view"),
            ("view-timeline-inset", "20% 80%")
        ]

        // 検証内容：各CSS値をStoreに適用する（When）
        for item in cases {
            store.updateCSSVariable(key: item.key, value: item.value)

            // 期待値：Store は CSS 値を分解・独自正規化せず、そのままノード状態へ保持する（Then）
            #expect(store.nodes[0].cssVariables[item.key] == item.value)
            #expect(store.cssMutation == nil)
        }
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + cases.count)
    }

    /// 論理名（日本語）: 標準scale履歴保存テスト
    /// 概要: Inspectorの標準`scale`編集が!importantと既存transform/rotateをbyte-exactに保ち、undo/redoできることを検証します。
    @Test("標準scale編集はimportantとtransform構成を保ってundo redoできる")
    func testStandardScaleEditPreservesTransformCompositionAcrossUndoRedo() async throws {
        // コンディション：scale、transform、rotateを同じ外部ruleに持ち、runtime DOMだけ異なるscaleへ変更された単一選択nodeを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Card data-og-id="card" data-og-internal-id="card-node" data-og-type="frame"></Card></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let initialCSS = """
        [data-og-internal-id="card-node"] {
          transform: translateX(7px) rotate(3deg);
          rotate: 11deg;
          scale: 1.25 0.8 !important;
        }
        """
        let editedCSS = initialCSS.replacingOccurrences(
            of: "scale: 1.25 0.8 !important;",
            with: "scale: -1.25 0.8 !important;"
        )
        try fixture.writeCompanionCSS(initialCSS)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)
        await store.ingestNodePayloadAndWait([
            [
                "id": "card",
                "internalID": "card-node",
                "tagName": "card",
                "type": "frame",
                "cssVariables": ["scale": "9 9"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "card")
        let initialAuthoredScale = store.selectedNode?.cssVariables["scale"]

        // 検証内容：X軸反転相当の標準scaleを書き込み、undo後にredoする（When）
        store.updateCSSVariable(key: "scale", value: "-1.25 0.8")
        let updatedCSS = try fixture.readCompanionCSS()
        let reloadTokenAfterEdit = store.reloadToken(for: fixture.htmlURL)
        let emittedInlineMutation = store.cssMutation
        store.undoDocumentChange()
        let undoCSS = try fixture.readCompanionCSS()
        store.redoDocumentChange()
        let redoCSS = try fixture.readCompanionCSS()

        // 期待値：scale値だけが変わり、priorityと既存transform/rotateのsource bytesを全履歴状態で保つ（Then）
        #expect(updatedCSS == editedCSS)
        #expect(undoCSS == initialCSS)
        #expect(redoCSS == editedCSS)
        #expect(reloadTokenAfterEdit == initialReloadToken + 1)
        #expect(emittedInlineMutation == nil)
        #expect(initialAuthoredScale == "1.25 0.8")
        #expect(store.nodes.first?.cssVariables["scale"] == "-1.25 0.8")
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 標準scale bridge再同期テスト
    /// 概要: flip bridgeが一時的に付けるinline `scale`を後続serializationへ残さず、companion/inlineのsource winnerだけを保存して再読み込みを要求することを検証します。
    @Test("標準scaleのbridge編集はsourceだけを最小差分保存してWebViewを再同期する")
    func testStandardScaleBridgeEditReloadsAfterCompanionAndInlineSourceUpdates() throws {
        // コンディション：companion CSS winnerとinline winnerを持ち、他のtransform family宣言も含む2 nodeを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let authoredHTML = """
        <!doctype html>
        <html><body>
          <CompanionCard data-og-id="companion" data-og-internal-id="companion-node" data-og-type="frame"></CompanionCard>
          <InlineCard data-og-id="inline" data-og-internal-id="inline-node" data-og-type="frame" style="transform:translateX(3px); scale : 1 1 /* keep */ !important ; rotate:7deg;"></InlineCard>
        </body></html>
        """
        let initialCSS = """
        [data-og-internal-id="companion-node"] {
          transform: skewX(2deg);
          scale: 1.25 0.8 !important;
          rotate: -4deg;
        }
        """
        try authoredHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(initialCSS)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        let target = try #require(store.htmlSyncTarget(for: page, segment: .pages))

        // 検証内容：WebCanvas flipと同じ単項payloadでcompanion winnerとinline winnerを順に更新する（When）
        let companionResult = store.applyHTMLObjectEditPayload(
            [
                "operation": "setCSSVariable",
                "nodeInternalID": "companion-node",
                "key": "scale",
                "value": "-1.25 0.8",
                "previousValue": "1.25 0.8"
            ],
            target: target
        )
        let htmlAfterCompanionEdit = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let inlineResult = store.applyHTMLObjectEditPayload(
            [
                "operation": "setCSSVariable",
                "nodeInternalID": "inline-node",
                "key": "scale",
                "value": "1 -1",
                "previousValue": "1 1"
            ],
            target: target
        )
        let finalHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        let finalCSS = try fixture.readCompanionCSS()

        // 期待値：どちらもreload契約でDOMの一時inline previewを破棄し、各source winnerのvalueだけを更新する（Then）
        #expect(companionResult.updated)
        #expect(companionResult.requiresReload)
        #expect(inlineResult.updated)
        #expect(inlineResult.requiresReload)
        #expect(htmlAfterCompanionEdit == authoredHTML)
        #expect(finalHTML == authoredHTML.replacingOccurrences(of: "scale : 1 1", with: "scale : 1 -1"))
        #expect(finalCSS == initialCSS.replacingOccurrences(of: "scale: 1.25 0.8", with: "scale: -1.25 0.8"))
        #expect(finalHTML.contains("transform:translateX(3px)"))
        #expect(finalHTML.contains("/* keep */ !important"))
        #expect(finalHTML.contains("rotate:7deg"))
        #expect(finalCSS.contains("transform: skewX(2deg)"))
        #expect(finalCSS.contains("rotate: -4deg"))
    }

    /// 論理名（日本語）: 複数選択標準scale保存テスト
    /// 概要: 複数選択Inspectorから単一の標準`scale`値を各nodeへ保存し、他のtransform family宣言を変更しないことを検証します。
    @Test("複数選択nodeへ標準scaleを一括保存できる")
    func testMultipleSelectionPersistsStandardScaleWithoutTouchingTransforms() async throws {
        // コンディション：異なるscaleとtransformを持つ兄弟nodeを複数選択する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <First data-og-id="first" data-og-internal-id="first-node" data-og-type="frame"></First>
          <Second data-og-id="second" data-og-internal-id="second-node" data-og-type="frame"></Second>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let initialCSS = """
        [data-og-internal-id="first-node"] {
          transform: rotate(2deg);
          scale: 1 1;
        }

        [data-og-internal-id="second-node"] {
          rotate: -4deg;
          scale: 0.9 1.1;
        }
        """
        try fixture.writeCompanionCSS(initialCSS)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)
        await store.ingestNodePayloadAndWait([
            [
                "id": "first",
                "internalID": "first-node",
                "tagName": "first",
                "type": "frame",
                "cssVariables": ["scale": "1 1", "transform": "rotate(2deg)"],
                "depth": 0
            ],
            [
                "id": "second",
                "internalID": "second-node",
                "tagName": "second",
                "type": "frame",
                "cssVariables": ["scale": "0.9 1.1", "rotate": "-4deg"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "first")
        store.selectNodeRange(to: "second", visibleNodeIDs: ["first", "second"])

        // 検証内容：Inspector相当の一括編集でpercentageの標準scaleを設定する（When）
        store.updateCSSVariable(key: "scale", value: "90% -110%")
        let updatedCSS = try fixture.readCompanionCSS()

        // 期待値：両scaleだけが変わり、既存transform/rotate bytesとbatch mutationを保持する（Then）
        let expectedCSS = initialCSS
            .replacingOccurrences(of: "scale: 1 1;", with: "scale: 90% -110%;")
            .replacingOccurrences(of: "scale: 0.9 1.1;", with: "scale: 90% -110%;")
        #expect(updatedCSS == expectedCSS)
        #expect(store.nodes.allSatisfy { $0.cssVariables["scale"] == "90% -110%" })
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(store.cssVariablesBatchMutation == nil)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 同期履歴ディスク反映テスト
    /// 概要: HTML 同期履歴の取り消し・やり直しがディスク内容と WebView 置換要求へ反映されることを検証します。
    @Test("同期履歴の取り消しとやり直しをディスクへ反映する")
    func testUndoRedoDocumentSyncReflectsDiskAndReplacementRequest() throws {
        // コンディション：一時プロジェクトを開き、HTML を二回同期する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)

        store.syncCurrentHTML("<!doctype html>\n<html><body>first</body></html>")
        store.syncCurrentHTML("<!doctype html>\n<html><body>second</body></html>")

        // 検証内容：取り消しを実行する
        store.undoDocumentChange()
        let undoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が一つ前の同期スナップショットになる
        #expect(undoDiskHTML == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.canRedo == true)

        guard let undoSequence = store.documentReplacementRequest?.sequence else {
            Issue.record("取り消し後の置換要求がありません。")
            return
        }
        store.markDocumentReplacementApplied(sequence: undoSequence)

        // 検証内容：やり直しを実行する
        store.redoDocumentChange()
        let redoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が取り消し前の同期スナップショットになる
        #expect(redoDiskHTML == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 作業履歴表示項目状態遷移テスト
    /// 概要: HTML編集の対象名、時刻、簡易プレビューが公開され、同じ項目がUndo / Redo状態間を移動することを検証します。
    @Test("作業履歴表示が対象オブジェクトとUndo Redo状態を保持する")
    func testHistoryListItemKeepsObjectMetadataAcrossUndoRedo() throws {
        // コンディション：一時projectのpageでtextオブジェクトを選択し、記録開始時刻を保持する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "hero-copy",
                "internalID": "hero-copy-node",
                "tagName": "h1",
                "capabilities": ["edit-layout", "edit-text"],
                "capabilityEvidence": [
                    "hasDirectText": true,
                    "resolvedDisplay": "block"
                ],
                "cssVariables": [String: String](),
                "depth": 1
            ]
        ])
        store.selectNode(id: "hero-copy")
        let recordedAfter = Date()

        // 検証内容：HTMLを同期し、同じ操作をUndoしてからRedoする（When）
        store.syncCurrentHTML("<!doctype html>\n<html><body><h1>edited</h1></body></html>")
        let undoableItem = try #require(store.historyItems.first)
        store.undoDocumentChange()
        let redoableItem = try #require(store.historyItems.first)
        store.redoDocumentChange()
        let restoredItem = try #require(store.historyItems.first)

        // 期待値：記録時の対象名、text preview、時刻、IDを維持してUndo / Redo状態だけが移動する（Then）
        #expect(undoableItem.objectName == "hero-copy")
        #expect(undoableItem.actionName == "HTMLを編集")
        #expect(undoableItem.timestamp >= recordedAfter)
        #expect(undoableItem.state == .undoable)
        #expect(undoableItem.previewKind == .node(hint: .text))
        #expect(redoableItem.id == undoableItem.id)
        #expect(redoableItem.state == .redoable)
        #expect(restoredItem.id == undoableItem.id)
        #expect(restoredItem.state == .undoable)
    }

    /// 論理名（日本語）: 外部HTML更新後Undo競合拒否テスト
    /// 概要: 履歴記録後に対象 HTML が外部更新された場合、Undo が最新ディスク値を古いsnapshotで上書きしないことを検証します。
    @Test("外部更新されたHTMLへ古いUndo履歴を適用しない")
    func testDocumentUndoRejectsExternallyChangedHTML() throws {
        // コンディション：HTML同期を履歴へ記録後、storeへ通知せず対象HTMLを外部変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.syncCurrentHTML("<!doctype html>\n<html><body>edited</body></html>")
        let externalHTML = "<!doctype html>\n<html><body>external before undo</body></html>"
        try externalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：staleなHTML履歴を取り消そうとする（When）
        store.undoDocumentChange()

        // 期待値：外部HTMLを保持して表示へ同期し、競合した統合履歴を破棄する（Then）
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == externalHTML)
        #expect(store.documentReplacementRequest?.html == externalHTML)
        #expect(store.statusMessage == "HTML の外部変更を検出したため、履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 外部HTML更新後Redo競合拒否テスト
    /// 概要: Undo後に対象 HTML が外部更新された場合、Redo が外部値を取り消し前snapshotで上書きしないことを検証します。
    @Test("外部更新されたHTMLへ古いRedo履歴を適用しない")
    func testDocumentRedoRejectsExternallyChangedHTML() throws {
        // コンディション：HTML同期を取り消してredo履歴を作り、その後対象HTMLを外部変更する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.syncCurrentHTML("<!doctype html>\n<html><body>edited</body></html>")
        store.undoDocumentChange()
        let undoSequence = try #require(store.documentReplacementRequest?.sequence)
        store.markDocumentReplacementApplied(sequence: undoSequence)
        let externalHTML = "<!doctype html>\n<html><body>external before redo</body></html>"
        try externalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：staleなHTML履歴をやり直そうとする（When）
        store.redoDocumentChange()

        // 期待値：外部HTMLを保持して表示へ同期し、undo/redo双方の統合履歴を破棄する（Then）
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == externalHTML)
        #expect(store.documentReplacementRequest?.html == externalHTML)
        #expect(store.statusMessage == "HTML の外部変更を検出したため、履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: Page登録削除後HTML履歴拒否テスト
    /// 概要: 外部manifest更新で履歴対象 Page が登録解除・削除された場合、Undo が旧 URL を再作成しないことを検証します。
    @Test("登録削除されたPageのHTML履歴で旧URLを再作成しない")
    func testDocumentUndoDoesNotRecreateRemovedProjectPage() throws {
        // コンディション：HTML同期後、外部処理がPage登録と対象HTMLファイルを削除する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.syncCurrentHTML("<!doctype html>\n<html><body>edited</body></html>")
        try fixture.writeProject(pages: [])
        try FileManager.default.removeItem(at: fixture.htmlURL)

        // 検証内容：削除済みPageを対象とするstaleなHTML履歴を取り消そうとする（When）
        store.undoDocumentChange()

        // 期待値：旧HTMLを再生成せず最新manifestを表示へ同期し、無効な履歴を破棄する（Then）
        #expect(FileManager.default.fileExists(atPath: fixture.htmlURL.path) == false)
        #expect(store.loadedProject?.project.allPages.isEmpty == true)
        #expect(store.statusMessage == "HTML の外部変更を検出したため、履歴適用を中止しました。")
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: Rename後HTML履歴移行テスト
    /// 概要: HTML 同期後に Page filename を変更しても、記録済み履歴が新しい URL へ追従して取り消せることを検証します。
    @Test("Page rename後もHTML履歴を取り消せる")
    func testDocumentHistoryMigratesPageURLAfterRename() throws {
        // コンディション：選択ページのHTMLを変更し、undo履歴を作る（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let page = try selectFirstPage(in: store)
        let initialHTML = "<!doctype html>\n<html><body>initial</body></html>"
        let firstHTML = "<!doctype html>\n<html><body>first renamed history</body></html>"
        let secondHTML = "<!doctype html>\n<html><body>second renamed history</body></html>"
        store.syncCurrentHTML(firstHTML)
        store.syncCurrentHTML(secondHTML)
        store.undoDocumentChange()
        let replacementSequence = try #require(store.documentReplacementRequest?.sequence)
        store.markDocumentReplacementApplied(sequence: replacementSequence)

        // 検証内容：undo/redo両側に履歴がある状態でPage filenameを変更し、残りをundo後に二回redoする（When）
        store.updatePageFilename(internalID: page.internalID, segment: .pages, value: "renamed.html")
        let renamedURL = fixture.publicURL.appendingPathComponent("renamed.html")
        store.undoDocumentChange()
        let htmlAfterUndo = try String(contentsOf: renamedURL, encoding: .utf8)
        store.redoDocumentChange()
        let htmlAfterFirstRedo = try String(contentsOf: renamedURL, encoding: .utf8)
        store.redoDocumentChange()

        // 期待値：旧URLを再生成せず、undo/redo両stackがrename後URLへ初期値、第一値、第二値の順で適用される（Then）
        #expect(FileManager.default.fileExists(atPath: fixture.htmlURL.path) == false)
        #expect(htmlAfterUndo == initialHTML)
        #expect(htmlAfterFirstRedo == firstHTML)
        #expect(try String(contentsOf: renamedURL, encoding: .utf8) == secondHTML)
        #expect(store.documentReplacementRequest?.pageURL.standardizedFileURL == renamedURL.standardizedFileURL)
        #expect(store.documentReplacementRequest?.html == secondHTML)
    }

    /// 論理名（日本語）: 外部HTML変更同期テスト
    /// 概要: ディスク上の HTML が外部変更された場合に WebView 置換要求へ変換されることを検証します。
    @Test("外部HTML変更を置換要求へ同期する")
    func testRefreshSelectedPageFromDiskCreatesReplacementRequest() throws {
        // コンディション：一時プロジェクトを開き、外部プロセス相当で HTML を書き換える
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let externalHTML = "<!doctype html>\n<html><body><Title data-og-id=\"title\" data-og-type=\"text\">external</Title></body></html>"
        try externalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：外部変更同期を実行する
        store.refreshSelectedPageFromDiskIfChanged()

        // 期待値：ディスク上の HTML が WebView 置換要求として保持される
        #expect(store.documentReplacementRequest?.html == externalHTML)
        #expect(store.documentReplacementRequest?.pageURL == fixture.htmlURL)
        #expect(store.statusMessage.contains("外部変更を同期"))
    }

    /// 論理名（日本語）: 非選択ページ外部HTML変更同期テスト
    /// 概要: キャンバス上の非選択ページが外部変更された場合に WebView reload token が更新されることを検証します。
    @Test("非選択ページの外部HTML変更でreload tokenを更新する")
    func testRefreshNonSelectedPageFromDiskUpdatesReloadToken() throws {
        // コンディション：home と downloads を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        try "<!doctype html>\n<html><body>downloads initial</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ]
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialToken = store.reloadToken(for: downloadsURL)

        // 検証内容：非選択ページの HTML を外部プロセス相当で書き換える
        try "<!doctype html>\n<html><body>downloads external</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        store.refreshPageFromDiskIfChanged(at: downloadsURL)

        // 期待値：選択中ページの置換要求ではなく、非選択 WebView 用 reload token が更新される
        #expect(store.selectedPageID == "home")
        #expect(store.documentReplacementRequest == nil)
        #expect(store.reloadToken(for: downloadsURL) == initialToken + 1)
        #expect(store.statusMessage.contains("表示へ同期"))
    }

    /// 論理名（日本語）: 依存ファイル外部変更同期テスト
    /// 概要: CSS や component master の変更時に全 WebView の reload token が更新されることを検証します。
    @Test("依存ファイル変更で全pageのreload tokenを更新する")
    func testRefreshProjectDependenciesUpdatesAllReloadTokens() throws {
        // Given: 複数 page と component canvas を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try "<!doctype html>\n<html><body>downloads</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        try "<!doctype html>\n<html><body>component</body></html>".write(
            to: componentURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 140, width: 100, height: 100)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let initialHomeToken = store.reloadToken(for: fixture.htmlURL)
        let initialDownloadsToken = store.reloadToken(for: downloadsURL)
        let initialComponentToken = store.reloadToken(for: componentURL)

        // When: CSS / component などの依存ファイル変更を同期する
        store.refreshProjectDependenciesFromDisk()

        // Then: 選択中 page、非選択 page、component canvas の表示が再読込対象になる
        #expect(store.reloadToken(for: fixture.htmlURL) == initialHomeToken + 1)
        #expect(store.reloadToken(for: downloadsURL) == initialDownloadsToken + 1)
        #expect(store.reloadToken(for: componentURL) == initialComponentToken + 1)
        #expect(store.statusMessage == "CSS / Components の外部変更を表示へ同期しました。")
    }

    /// 論理名（日本語）: Imported CSS外部変更同期テスト
    /// 概要: 複数token relから到達するlocal CSS `@import` graphをcycle-safeに監視し、実import変更だけをCanvas再読込へ反映します。
    @Test("local CSS importの外部変更でreload tokenを更新する")
    func testRefreshImportedCSSDependencyUpdatesReloadToken() throws {
        // コンディション：stylesheet複数token link、comment/string内decoy、循環するlocal import graphを持つpageを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let stylesURL = fixture.publicURL.appendingPathComponent("styles", isDirectory: true)
        let nestedURL = stylesURL.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        let baseCSSURL = stylesURL.appendingPathComponent("base.css")
        let themeCSSURL = nestedURL.appendingPathComponent("theme.css")
        let ignoredCSSURL = stylesURL.appendingPathComponent("ignored.css")
        let originalHTML = """
        <!doctype html><html><head>
          <link rel="stylesheet preload" href="styles/base.css">
        </head><body><main id="target">Target</main></body></html>
        """
        let originalBaseCSS = """
        /* @import "./ignored.css"; */
        #target::before { content: "@import './ignored.css'"; }
        @import "./nested/theme.css" screen;
        """
        let originalThemeCSS = """
        @import "../base.css";
        #target { display: grid; }
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try originalBaseCSS.write(to: baseCSSURL, atomically: true, encoding: .utf8)
        try originalThemeCSS.write(to: themeCSSURL, atomically: true, encoding: .utf8)
        try "#target { color: red; }\n".write(to: ignoredCSSURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：decoy CSS通知を無視した後、実import themeを外部変更してdependency callback相当を実行する（When）
        store.refreshProjectDependencyFromDiskIfChanged(at: ignoredCSSURL)
        let tokenAfterDecoy = store.reloadToken(for: fixture.htmlURL)
        let updatedThemeCSS = originalThemeCSS.replacingOccurrences(of: "display: grid", with: "display: flex")
        try updatedThemeCSS.write(to: themeCSSURL, atomically: true, encoding: .utf8)
        store.refreshProjectDependencyFromDiskIfChanged(at: themeCSSURL)

        // 期待値：comment/string内importは監視せず、cycle内の実theme変更だけがsource不変のCanvas reloadを一度要求する（Then）
        #expect(tokenAfterDecoy == initialReloadToken)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(try String(contentsOf: fixture.htmlURL, encoding: .utf8) == originalHTML)
        #expect(try String(contentsOf: baseCSSURL, encoding: .utf8) == originalBaseCSS)
        #expect(try String(contentsOf: themeCSSURL, encoding: .utf8) == updatedThemeCSS)
        #expect(store.statusMessage == "CSS / Components の外部変更を表示へ同期しました。")
    }

    /// 論理名（日本語）: 未適用属性編集との競合テスト
    /// 概要: 未適用の属性mutationがある場合に外部HTML変更でWebViewを破壊的に置換しないことを検証します。
    @Test("未適用編集がある場合は外部HTML変更同期を保留する")
    func testRefreshSelectedPageFromDiskDefersWhenMutationIsPending() throws {
        // コンディション：未適用の属性mutationを持つストアで外部変更を発生させる（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body><Title data-og-id="title" data-og-internal-id="title-node" data-og-type="text">title</Title></body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        try fixture.writeCompanionCSS(
            """
            [data-og-internal-id="title-node"] {
              gap: 8px;
            }
            """
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.ingestNodePayload([
            [
                "id": "title",
                "internalID": "title-node",
                "tagName": "title",
                "type": "text",
                "cssVariables": ["gap": "8px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")
        store.updateNodeAttribute(name: "role", value: "button")
        try "<!doctype html>\n<html><body>external</body></html>".write(
            to: fixture.htmlURL,
            atomically: true,
            encoding: .utf8
        )

        // 検証内容：外部変更同期を実行する（When）
        store.refreshSelectedPageFromDiskIfChanged()

        // 期待値：未適用mutationが優先され、置換要求は作られない（Then）
        #expect(store.documentReplacementRequest == nil)
        #expect(store.attributeMutation?.value == "button")
        #expect(store.statusMessage.contains("自動同期を保留"))
    }

    /// 論理名（日本語）: 外部プロジェクト変更同期テスト
    /// 概要: ディスク上の `.ogp` が外部変更された場合にページ一覧とキャンバス配置が再読み込みされることを検証します。
    @Test("外部ogp変更をページ一覧と配置へ同期する")
    func testRefreshProjectManifestReloadsPagesAndCanvas() throws {
        // コンディション：一時プロジェクトを開き、外部プロセス相当で `.ogp` にページを追加する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        try "<!doctype html>\n<html><body>downloads</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        let updatedProject = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 1520, y: 0, width: 1440, height: 1200)
                )
            ]
        )
        let data = try JSONEncoder().encode(updatedProject)
        try data.write(to: fixture.projectURL)

        // 検証内容：外部 `.ogp` 変更同期を実行する
        store.refreshProjectManifestFromDiskIfChanged()

        // 期待値：追加ページと canvas 配置がストアへ反映される
        #expect(store.loadedProject?.project.allPages.map(\.id) == ["home", "downloads"])
        #expect(store.loadedProject?.project.allPages[1].canvas.x == 1520)
        #expect(store.selectedPageID == "home")
        #expect(store.statusMessage.contains(".ogp 外部変更を同期"))
    }

    /// 論理名（日本語）: Chapter選択テスト
    /// 概要: Chapter を切り替えると Pages 表示対象だけが切り替わり、HTML カードは未選択になることを検証します。
    @Test("Chapter選択で表示対象ページ群を切り替える")
    func testSelectChapterSwitchesVisiblePages() throws {
        // コンディション：2つの Chapter を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "docs-home",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：プロジェクトを開き、docs Chapter を内部 ID で選択する
        store.openProject(at: fixture.projectURL)
        let docsChapterInternalID = try #require(store.loadedProject?.project.chapters[1].internalID)
        store.selectChapter(internalID: docsChapterInternalID)

        // 期待値：表示対象 Pages が docs Chapter 内へ切り替わり、page は未選択になる
        #expect(store.selectedChapterID == "docs")
        #expect(store.selectedChapterPages.map(\.id) == ["docs-home"])
        #expect(store.selectedPageID == nil)
        #expect(store.selectedPageURL == nil)
    }

    /// 論理名（日本語）: 複合ノード参照ID生成テスト
    /// 概要: Chapter と page の内部 ID を含む agent 向け node 参照 ID と pasteboard payload を生成できることを確認します。
    @Test("Chapter/Page内部IDを含むnode参照IDを生成する")
    func testNodeReferenceIDUsesInternalIDs() throws {
        // コンディション：Chapter 跨ぎで同じ page ID を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：docs Chapter を内部 ID で選択し、node 参照 payload を生成する
        store.openProject(at: fixture.projectURL)
        let docsChapterInternalID = try #require(store.loadedProject?.project.chapters[1].internalID)
        let docsPageInternalID = try #require(store.loadedProject?.project.chapters[1].pages.first?.internalID)
        store.selectChapter(internalID: docsChapterInternalID)
        store.selectPage(internalID: docsPageInternalID)
        let referenceID = store.nodeReferenceID(forNodeID: "hero", nodeInternalID: "node-opaque")
        let payload = try #require(store.nodeReferencePasteboardPayload(
            forNodeID: "hero",
            nodeInternalID: "node-opaque",
            html: "<Hero></Hero>"
        ))

        // 期待値：複合参照 ID は Chapter 内部 ID、page 内部 ID、node 内部 ID を含む
        #expect(store.selectedPageURL == docsURL)
        #expect(referenceID == "ogref:node:\(docsChapterInternalID):\(store.selectedPage?.internalID ?? ""):node-opaque")
        #expect(payload["referenceID"] as? String == referenceID)
        #expect(payload["nodeID"] as? String == "hero")
        #expect(payload["nodeInternalID"] as? String == "node-opaque")
        #expect(payload["chapterIndex"] as? Int == 1)
        #expect(payload["pageIndex"] as? Int == 0)
        #expect(payload["html"] as? String == "<Hero></Hero>")
    }

    /// 論理名（日本語）: App暗黙migration禁止テスト
    /// 概要: legacy HTML/manifest inputを含むProjectのopen/loadと同一HTML同期が、明示PreviewなしにWeb sourceやannotationを変更しないことを確認します。
    @Test("Appはopenと無編集saveで暗黙migrationしない")
    func testProjectMigrationDoesNotRunDuringOpenOrUneditedSave() throws {
        // コンディション：legacy属性/preview field、既存optional identity、未注釈標準nodeを持つProjectを用意する（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        let before = try fixture.sourceSnapshot()
        let originalHTML = try String(contentsOf: fixture.homeHTMLURL, encoding: .utf8)
        let store = EditorStore()

        // 検証内容：Projectを開き、同じHTMLを無編集のまま同期保存する（When）
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.syncCurrentHTML(originalHTML)
        let after = try fixture.sourceSnapshot()
        let contract = OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        let targetVersion = contract.migrationPolicy.targetVersion

        // 期待値：全source bytesとoptional annotationは不変で、migrationは未確認状態のまま開始されない（Then）
        #expect(after == before)
        #expect(originalHTML.contains("data-og-internal-id=\"kept-article\""))
        #expect(originalHTML.contains("<p>Standard child</p>"))
        #expect(contract.version == "0.1.0")
        #expect(targetVersion == "1.0.0")
        #expect(store.projectMigrationStatus == .notChecked(targetVersion: targetVersion))
        #expect(store.projectMigrationPreview == nil)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: App migration dry-run/cancelテスト
    /// 概要: Project InspectorのPreviewがmulti-file diffを返してもsourceを書かず、Cancelがproposal stateだけを破棄することを確認します。
    @Test("App migrationのdry-runとcancelはsourceを書き換えない")
    func testProjectMigrationDryRunAndCancelAreNoWrite() throws {
        // コンディション：manifestの既知legacy preview fieldと2つのpageに既知legacy runtime属性を持つProjectを開く（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        let before = try fixture.sourceSnapshot()
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：Project migrationをdry-runして差分を確認後、confirmationをキャンセルする（When）
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)
        let afterDryRun = try fixture.sourceSnapshot()
        store.cancelProjectMigrationPreview()
        let afterCancel = try fixture.sourceSnapshot()

        // 期待値：root相対path順のmanifest/2ページ差分とapply専用proposalを得るが、dry-run/cancel後も全source bytesは不変である（Then）
        #expect(preview.changed)
        #expect(preview.sourceContractVersion == "0.1.0")
        #expect(preview.targetContractVersion == "1.0.0")
        #expect(preview.proposalReference?.isEmpty == false)
        #expect(preview.canApply)
        #expect(preview.diffs.map(\.path) == [
            "Project.ogp",
            "public/index.html",
            "public/locked/secondary.html"
        ])
        #expect(preview.diffs.allSatisfy { !$0.unifiedDiff.isEmpty })
        #expect(afterDryRun == before)
        #expect(afterCancel == before)
        #expect(store.projectMigrationPreview == nil)
        #expect(store.projectMigrationStatus == .changesAvailable(
            sourceVersion: preview.sourceContractVersion,
            targetVersion: preview.targetContractVersion,
            fileCount: preview.diffs.count
        ))
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: App stale migration proposalテスト
    /// 概要: dry-run後に1 sourceだけ外部変更された場合、確認済みproposalを全体no-writeで拒否し、stale sheetを保持することを確認します。
    @Test("App migrationはstale proposalを全体no-writeで表示する")
    func testProjectMigrationStaleProposalKeepsEverySourceUnchanged() throws {
        // コンディション：2ページのdry-run proposalを作成後、片方のsourceだけを外部更新する（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)
        let externallyModified = try String(contentsOf: fixture.secondaryHTMLURL, encoding: .utf8)
            .replacingOccurrences(of: "Secondary child", with: "Externally changed child")
        try externallyModified.write(to: fixture.secondaryHTMLURL, atomically: true, encoding: .utf8)
        let beforeApply = try fixture.sourceSnapshot()

        // 検証内容：外部変更前のproposalを明示Applyする（When）
        store.applyProjectMigrationPreview()
        let afterApply = try fixture.sourceSnapshot()
        let stalePreview = try #require(store.projectMigrationPreview)

        // 期待値：全sourceはApply直前bytesを保ち、stale diagnosticと再Preview可能なsheetが表示される（Then）
        #expect(afterApply == beforeApply)
        #expect(stalePreview.isStale)
        #expect(!stalePreview.canApply)
        #expect(stalePreview.diagnostics.contains { $0.code == "stale-migration-proposal" })
        #expect(store.projectMigrationStatus == .stale(targetVersion: preview.targetContractVersion))
        #expect(store.lastError != nil)
    }

    /// 論理名（日本語）: App migration未適用DOM同期保留テスト
    /// 概要: WebViewへ未適用のdocument replacementがある間は、確認済みproposalを実行せずsourceとPreviewを保持することを確認します。
    @Test("App migrationは未適用のDOM同期がある間Applyを保留する")
    func testProjectMigrationWaitsForPendingDocumentReplacement() throws {
        // コンディション：migration proposal確認後、選択pageの外部変更を未適用document replacementとして保留する（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)
        let externallyModified = try String(contentsOf: fixture.homeHTMLURL, encoding: .utf8)
            .replacingOccurrences(of: "Standard child", with: "Pending canvas sync")
        try externallyModified.write(to: fixture.homeHTMLURL, atomically: true, encoding: .utf8)
        store.refreshSelectedPageFromDiskIfChanged()
        let pendingRequest = try #require(store.documentReplacementRequest)
        let beforeApply = try fixture.sourceSnapshot()

        // 検証内容：未適用document replacementを残したまま確認済みmigrationをApplyする（When）
        store.applyProjectMigrationPreview()
        let afterApply = try fixture.sourceSnapshot()
        let applyError = store.lastError
        store.cancelProjectMigrationPreview()
        store.previewProjectMigration()
        let afterRefreshRequest = try fixture.sourceSnapshot()

        // 期待値：Core apply/dry-runを開始せず全source・未適用要求を保持し、Canvas同期完了後の再実行を案内する（Then）
        #expect(afterApply == beforeApply)
        #expect(afterRefreshRequest == beforeApply)
        #expect(applyError == "未適用の編集があるため、Project migrationのApplyを保留しました。")
        #expect(store.projectMigrationPreview == nil)
        #expect(store.documentReplacementRequest == pendingRequest)
        #expect(preview.diagnostics.contains { $0.code == "stale-migration-proposal" } == false)
        #expect(store.lastError == "未適用の編集があるため、Project migrationのPreviewを保留しました。")
    }

    /// 論理名（日本語）: App migration preview field衝突テスト
    /// 概要: legacy fieldと変換先の標準host fieldが異なる値で共存する場合、blocking errorを表示して全sourceを変更しないことを確認します。
    @Test("App migrationはpreview field衝突をatomic no-writeで拒否する")
    func testProjectMigrationRejectsConflictingPreviewFieldsWithoutWriting() throws {
        // コンディション：legacy codeViewerModeと異なるhost.variantが同じplacementに共存するProjectを用意する（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        try fixture.addConflictingHostVariant()
        let before = try fixture.sourceSnapshot()
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // 検証内容：Project migrationをdry-runし、blocking Previewに対してApply処理も要求する（When）
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)
        let afterDryRun = try fixture.sourceSnapshot()
        store.applyProjectMigrationPreview()
        let afterApplyRequest = try fixture.sourceSnapshot()

        // 期待値：衝突diagnosticでApply不能となり、dry-runとApply要求のどちらも全source bytesを書き換えない（Then）
        #expect(preview.diagnostics.contains {
            $0.severity == .error && $0.code == "legacy-preview-context-conflict"
        })
        #expect(!preview.changed)
        #expect(preview.proposalReference == nil)
        #expect(preview.diffs.isEmpty)
        #expect(!preview.canApply)
        #expect(afterDryRun == before)
        #expect(afterApplyRequest == before)
        if case .failed(let targetVersion, _) = store.projectMigrationStatus {
            #expect(targetVersion == "1.0.0")
        } else {
            Issue.record("Project migration statusがfailedではありません。")
        }
        #expect(store.lastError != nil)
    }

    /// 論理名（日本語）: App migration適用後refreshテスト
    /// 概要: 確認済みproposalのatomic apply後、legacy runtime属性とpreview fieldを変換し、optional identity・未注釈標準HTMLとApp表示更新を維持します。
    @Test("App migrationは明示apply後に標準sourceとProject表示をrefreshする")
    func testProjectMigrationApplyPreservesOptionalAnnotationsAndRefreshesProject() throws {
        // コンディション：既知legacy属性/preview fieldとoptional/未注釈nodeが共存するProjectを表示する（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer { fixture.cleanUp() }
        let before = try fixture.sourceSnapshot()
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let homeReloadBefore = store.reloadToken(for: fixture.homeHTMLURL)
        let secondaryReloadBefore = store.reloadToken(for: fixture.secondaryHTMLURL)
        let componentReloadBefore = store.reloadToken(for: fixture.componentHTMLURL)
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)

        // 検証内容：dry-runで確認したproposalを明示Applyする（When）
        store.applyProjectMigrationPreview()
        let homeHTML = try String(contentsOf: fixture.homeHTMLURL, encoding: .utf8)
        let secondaryHTML = try String(contentsOf: fixture.secondaryHTMLURL, encoding: .utf8)
        let after = try fixture.sourceSnapshot()
        let placementMocks = store.loadedProject?.project.collections.first?.components.first?
            .canvas.previewContext.placementMocks["fixture-placement"]
        let collapsedPlacementMocks = store.loadedProject?.project.collections.first?.components.first?
            .canvas.previewContext.placementMocks["fixture-collapsed-placement"]

        // 期待値：legacy stateを標準host stateへ変換し、DOM/optional identityを維持してsheetを閉じ、manifest/dependency/page表示を再読込する（Then）
        #expect(!homeHTML.contains("data-og-selected"))
        #expect(!secondaryHTML.contains("data-og-editing"))
        #expect(homeHTML.contains("data-og-internal-id=\"kept-article\""))
        #expect(homeHTML.contains("<p>Standard child</p>"))
        #expect(!homeHTML.contains("<p data-og-"))
        #expect(secondaryHTML.contains("<span>Secondary child</span>"))
        #expect(after["Project.ogp"] != before["Project.ogp"])
        #expect(placementMocks?["host.variant"] == "preview")
        #expect(placementMocks?["selectedLanguage"] == "ja")
        #expect(placementMocks?["codeViewerMode"] == nil)
        #expect(collapsedPlacementMocks?["host.variant"] == "collapsible collapsed")
        #expect(collapsedPlacementMocks?["customState"] == "kept")
        #expect(collapsedPlacementMocks?["placementMode"] == nil)
        #expect(after["OpenGraphite.contract.json"] == before["OpenGraphite.contract.json"])
        #expect(after["CSS/OpenGraphite.css"] == before["CSS/OpenGraphite.css"])
        #expect(after["public/components.html"] == before["public/components.html"])
        #expect(after["public/index.css"] == before["public/index.css"])
        #expect(after["public/locked/secondary.css"] == before["public/locked/secondary.css"])
        #expect(after["public/components.css"] == before["public/components.css"])
        #expect(store.projectMigrationPreview == nil)
        #expect(store.projectMigrationStatus == .applied(
            version: preview.targetContractVersion,
            fileCount: preview.diffs.count
        ))
        #expect(store.documentReplacementRequest?.pageURL == fixture.homeHTMLURL)
        #expect(store.reloadToken(for: fixture.homeHTMLURL) > homeReloadBefore)
        #expect(store.reloadToken(for: fixture.secondaryHTMLURL) > secondaryReloadBefore)
        #expect(store.reloadToken(for: fixture.componentHTMLURL) > componentReloadBefore)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: App migration部分失敗rollbackテスト
    /// 概要: multi-file applyの途中で書込不能sourceがある場合、先行候補を含む全sourceを適用前bytesへ戻して失敗sheetを保持します。
    @Test("App migrationは部分書込失敗をrollbackして全sourceを保持する")
    func testProjectMigrationPartialWriteFailureRollsBackEverySource() throws {
        // コンディション：manifestと2ページのproposal作成後、path順で後方のHTMLだけをuser immutableにする（Given）
        let fixture = try EditorStoreMigrationFixture()
        defer {
            try? fixture.setSecondaryHTMLImmutable(false)
            fixture.cleanUp()
        }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.previewProjectMigration()
        let preview = try #require(store.projectMigrationPreview)
        let beforeApply = try fixture.sourceSnapshot()
        try fixture.setSecondaryHTMLImmutable(true)

        // 検証内容：確認済みmulti-file proposalを明示Applyし、完了後にfixtureのimmutable flagを解除する（When）
        store.applyProjectMigrationPreview()
        try fixture.setSecondaryHTMLImmutable(false)
        let afterApply = try fixture.sourceSnapshot()
        let failurePreview = try #require(store.projectMigrationPreview)

        // 期待値：migration-write-failedを表示し、先行pageを含む全source bytesがtransaction前状態へrollbackされる（Then）
        #expect(afterApply == beforeApply)
        #expect(failurePreview.diagnostics.contains { $0.code == "migration-write-failed" })
        #expect(!failurePreview.canApply)
        if case .failed(let targetVersion, _) = store.projectMigrationStatus {
            #expect(targetVersion == preview.targetContractVersion)
        } else {
            Issue.record("Project migration statusがfailedではありません。")
        }
        #expect(store.lastError != nil)
    }

    /// 論理名（日本語）: App明示adoption dry-run/applyテスト
    /// 概要: 標準id selectorで未注釈nodeをdry-runし、確認済みapply専用proposal tokenだけでapplyして最小annotationを追加することを確認します。
    @Test("App adoptionはdry-run差分確認後だけ標準id nodeを明示適用する")
    func testNodeAdoptionUsesDryRunProposalAndMinimalAnnotation() throws {
        // コンディション：標準idを持つがOpenGraphite annotationを持たないpageを開く（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html>
        <html><body><main id="article"><h1>Standard</h1></main></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let graph = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
        let sourceNode = try #require(graph.nodes.first { $0.tagName == "main" })
        store.ingestNodePayload([
            [
                "id": sourceNode.reference,
                "authoredID": sourceNode.id,
                "standardID": sourceNode.attributes["id"] ?? "",
                "internalID": sourceNode.internalID,
                "reference": sourceNode.reference,
                "annotationStatus": sourceNode.annotationStatus.rawValue,
                "referenceStability": sourceNode.referenceStability.rawValue,
                "locator": [
                    "documentURL": sourceNode.locator.documentURL,
                    "selector": sourceNode.locator.selector ?? "",
                    "domPath": sourceNode.locator.domPath,
                    "sourceRange": [
                        "start": sourceNode.locator.sourceRange.start,
                        "end": sourceNode.locator.sourceRange.end
                    ],
                    "contentHash": sourceNode.locator.contentHash
                ],
                "tagName": sourceNode.tagName,
                "legacyTypeHint": sourceNode.legacyTypeHint ?? "",
                "capabilities": sourceNode.capabilities.map(\.rawValue),
                "capabilityEvidence": Self.capabilityEvidencePayload(sourceNode.capabilityEvidence),
                "attributes": sourceNode.attributes,
                "cssVariables": sourceNode.cssVariables,
                "hidden": false,
                "locked": false,
                "depth": sourceNode.depth
            ]
        ])
        store.selectNode(id: sourceNode.reference)
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)

        // 検証内容：node adoptionをdry-runし、表示された差分を明示applyする（When）
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：dry-runはsourceを保持し、標準id selectorで解決したapply専用proposal tokenとinternal-idだけの差分を返す（Then）
        #expect(htmlAfterDryRun == originalHTML)
        #expect(preview.changed)
        #expect(preview.reference?.hasPrefix("ogref-session:adoption:") == true)
        #expect(preview.selector == nil)
        #expect(preview.domPath == nil)
        #expect(preview.unifiedDiff.contains("data-og-internal-id"))
        #expect(!preview.unifiedDiff.contains("data-og-id="))

        let externallyModifiedHTML = originalHTML.replacingOccurrences(
            of: "Standard",
            with: "Externally changed"
        )
        try externallyModifiedHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        store.applyNodeAdoptionPreview()
        let htmlAfterStaleApply = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(htmlAfterStaleApply == externallyModifiedHTML)
        #expect(store.nodeAdoptionPreview != nil)
        #expect(store.lastError != nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken)

        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        store.previewSelectedNodeAdoption(scope: .node)
        #expect(store.nodeAdoptionPreview?.reference?.hasPrefix("ogref-session:adoption:") == true)
        store.applyNodeAdoptionPreview()
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(appliedHTML.contains("<main id=\"article\" data-og-internal-id="))
        #expect(!appliedHTML.contains("data-og-id="))
        #expect(store.nodeAdoptionPreview == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 部分注釈stable node adoptionテスト
    /// 概要: internal IDだけを持つnodeをproject typed referenceで表示し、dry-run proposal tokenを経ても不要なdisplay annotationを追加しないことを確認します。
    @Test("App adoptionはpartial stable nodeにもdry-run proposalを要求する")
    func testNodeAdoptionUsesProposalReferenceForPartiallyAnnotatedStableNode() async throws {
        // コンディション：internal IDだけを持つ部分注釈nodeをproject page graphから取り込む（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html>
        <html><body><main data-og-internal-id="partial-main"><h1>Partial</h1></main></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNode = try #require(
            try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
                .nodes
                .first { $0.internalID == "partial-main" }
        )
        await store.ingestNodePayloadAndWait([
            [
                "id": "browser-partial-main",
                "authoredID": "",
                "standardID": "",
                "internalID": sourceNode.internalID,
                "reference": "ogref-dom:node:partial-main",
                "annotationStatus": "partial",
                "referenceStability": "stable",
                "locator": [
                    "documentURL": sourceNode.locator.documentURL,
                    "selector": sourceNode.locator.selector ?? "",
                    "domPath": sourceNode.locator.domPath,
                    "sourceRange": [
                        "start": sourceNode.locator.sourceRange.start,
                        "end": sourceNode.locator.sourceRange.end
                    ],
                    "contentHash": sourceNode.locator.contentHash
                ],
                "tagName": sourceNode.tagName,
                "legacyTypeHint": sourceNode.legacyTypeHint ?? "",
                "capabilities": sourceNode.capabilities.map(\.rawValue),
                "capabilityEvidence": Self.capabilityEvidencePayload(sourceNode.capabilityEvidence),
                "attributes": sourceNode.attributes,
                "cssVariables": sourceNode.cssVariables,
                "hidden": false,
                "locked": false,
                "depth": sourceNode.depth
            ]
        ])
        store.selectNode(id: "browser-partial-main")
        let inspectedNode = try #require(store.selectedNode)

        // 検証内容：project typed referenceを使ってdry-runし、返却されたapply専用proposal tokenだけでapplyする（When）
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：通常表示はtyped stable ref、apply targetはdocumentとparameterを固定したproposal tokenになり、既にstableなnodeへdisplay annotationを重複追加しない（Then）
        #expect(inspectedNode.reference.hasPrefix("ogref:node:"))
        #expect(inspectedNode.referenceStability == .stable)
        #expect(htmlAfterDryRun == originalHTML)
        #expect(!preview.changed)
        #expect(preview.reference?.hasPrefix("ogref-session:adoption:") == true)
        #expect(preview.selector == nil)
        #expect(preview.domPath == nil)
        #expect(preview.unifiedDiff.isEmpty)

        store.applyNodeAdoptionPreview()
        let appliedHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)
        #expect(appliedHTML == originalHTML)
        #expect(appliedHTML.contains("data-og-internal-id=\"partial-main\""))
        #expect(!appliedHTML.contains("data-og-id="))
        #expect(store.nodeAdoptionPreview == nil)
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 重複internal ID source mergeテスト
    /// 概要: WebKit payloadがstableと見なしても、Shared source graphの重複診断に従いDOM pathごとのsession referenceへ補正することを確認します。
    @Test("重複internal IDはDOM pathで別session nodeへmergeする")
    func testDuplicateInternalIDsMergeByDOMPathAsSessionReferences() async throws {
        // コンディション：同じinternal IDを持つ2つのsource nodeと、誤ってstableとされたWeb payloadを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        try """
        <!doctype html>
        <html><body>
          <div id="first" data-og-internal-id="duplicate">First</div>
          <div id="second" data-og-internal-id="duplicate">Second</div>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNodes = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
            .nodes
            .filter { $0.tagName == "div" }
        #expect(sourceNodes.count == 2)
        #expect(sourceNodes.allSatisfy { $0.referenceStability == .session })
        let payload = sourceNodes.enumerated().map { index, node -> [String: Any] in
            [
                "id": "browser-\(index)",
                "authoredID": "",
                "standardID": node.attributes["id"] ?? "",
                "internalID": "duplicate",
                "reference": "ogref-dom:node:duplicate",
                "annotationStatus": "partial",
                "referenceStability": "stable",
                "locator": [
                    "documentURL": node.locator.documentURL,
                    "selector": node.locator.selector ?? "",
                    "domPath": node.locator.domPath,
                    "sourceRange": [
                        "start": node.locator.sourceRange.start,
                        "end": node.locator.sourceRange.end
                    ],
                    "contentHash": node.locator.contentHash
                ],
                "tagName": "div",
                "type": "",
                "cssVariables": [String: String](),
                "depth": node.depth
            ]
        }

        // 検証内容：WebCanvas payloadをStoreへ取り込む（When）
        await store.ingestNodePayloadAndWait(payload)

        // 期待値：重複internal ID索引を使わず、各DOM pathのShared session referenceが別々に保持される（Then）
        #expect(store.nodes.count == 2)
        #expect(store.nodes.allSatisfy { $0.referenceStability == .session })
        #expect(store.nodes.map(\.reference) == sourceNodes.map(\.reference))
        #expect(Set(store.nodes.map(\.reference)).count == 2)
        for node in store.nodes {
            #expect(
                store.nodeReferenceID(forNodeID: node.id, nodeInternalID: node.internalID) == node.reference
            )
        }
    }

    /// 論理名（日本語）: Browser implicit DOM source mergeテスト
    /// 概要: 省略可能なHTML document tagとtable containerをWebKitが補完しても、未注釈nodeをauthored source locatorへ結びます。
    @Test("WebKitが補完したhtml body tbodyを越えて未注釈nodeをsourceへmergeする")
    func testImplicitBrowserDOMContainersMergeToAuthoredSourceLocator() async throws {
        // コンディション：html / body / tbodyを正当に省略したtableと、WebKit補完後のpayload pathを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = "<!doctype html><main><table><tr><td>Cell</td></tr></table></main>"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let graph = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
        let sourceCell = try #require(graph.nodes.first { $0.tagName == "td" })
        let browserContainerDOMPath = "html:nth-of-type(1) > body:nth-of-type(1) > main:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(1)"
        let browserDOMPath = "html:nth-of-type(1) > body:nth-of-type(1) > main:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(1) > tr:nth-of-type(1) > td:nth-of-type(1)"
        let browserContainerReference = "ogref-session:node:webkit:implicit-tbody"
        let browserReference = "ogref-session:node:webkit:cell:revision"

        // 検証内容：browser生成containerとauthored cellを取り込み、containerのadoptionを試してからcellをdry-runする（When）
        await store.ingestNodePayloadAndWait([
            Self.unannotatedBrowserNodePayload(
                id: browserContainerReference,
                standardID: "",
                selector: "",
                domPath: browserContainerDOMPath,
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "tbody"
            ),
            [
                "id": browserReference,
                "authoredID": "",
                "standardID": "",
                "internalID": "",
                "reference": browserReference,
                "annotationStatus": "none",
                "referenceStability": "session",
                "locator": [
                    "documentURL": fixture.htmlURL.standardizedFileURL.absoluteString,
                    "domPath": browserDOMPath,
                    "sourceRange": ["start": -1, "end": -1],
                    "contentHash": "webkit-outer-html"
                ],
                "tagName": "td",
                "type": "",
                "cssVariables": [String: String](),
                "hidden": false,
                "locked": false,
                "depth": 4
            ]
        ])
        store.selectNode(id: browserContainerReference)
        let inspectedContainer = try #require(store.selectedNode)
        store.previewSelectedNodeAdoption(scope: .node)
        let containerPreview = store.nodeAdoptionPreview
        let htmlAfterContainerAttempt = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        store.selectNode(id: browserReference)
        let inspectedCell = try #require(store.selectedNode)
        let sourceLocator = try #require(inspectedCell.locator)
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：browser-only tbodyはinspection-onlyで、cellにはShared source range/hash/parentが採用されdry-runも原文を変更しない（Then）
        #expect(inspectedContainer.tagName == "tbody")
        #expect(inspectedContainer.referenceStability == .session)
        #expect(inspectedContainer.locator?.sourceStart == -1)
        #expect(!inspectedContainer.canAdoptIdentity)
        #expect(containerPreview == nil)
        #expect(htmlAfterContainerAttempt == originalHTML)
        #expect(sourceCell.locator.domPath == "main:nth-of-type(1) > table:nth-of-type(1) > tr:nth-of-type(1) > td:nth-of-type(1)")
        #expect(inspectedCell.reference == sourceCell.reference)
        #expect(inspectedCell.referenceStability == .session)
        #expect(inspectedCell.parentReference == sourceCell.parentReference)
        #expect(sourceLocator.domPath == sourceCell.locator.domPath)
        #expect(sourceLocator.sourceStart == sourceCell.locator.sourceRange.start)
        #expect(sourceLocator.sourceEnd == sourceCell.locator.sourceRange.end)
        #expect(sourceLocator.contentHash == sourceCell.locator.contentHash)
        #expect(preview.changed)
        #expect(preview.reference?.hasPrefix("ogref-session:adoption:") == true)
        #expect(preview.unifiedDiff.contains("data-og-internal-id"))
        #expect(htmlAfterDryRun == originalHTML)
    }

    /// 論理名（日本語）: Browser implicit colgroup source mergeテスト
    /// 概要: WebKitが補完した`colgroup`はinspection-onlyに保ち、authored `col`だけをShared source locatorへ結びます。
    @Test("WebKitが補完したcolgroupを越えてauthored colをsourceへmergeする")
    func testImplicitBrowserColumnGroupMergesAuthoredColumnToSourceLocator() async throws {
        // コンディション：colgroupを省略したtable sourceと、WebKit補完後のcolgroup / col payloadを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = "<!doctype html><table><col><tr><td>Cell</td></tr></table>"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceColumn = try #require(
            try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
                .nodes
                .first { $0.tagName == "col" }
        )
        let browserColumnGroupReference = "ogref-session:node:webkit:implicit-colgroup"
        let browserColumnReference = "ogref-session:node:webkit:authored-col"
        let browserColumnGroupPath = "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > colgroup:nth-of-type(1)"
        let browserColumnPath = browserColumnGroupPath + " > col:nth-of-type(1)"

        // 検証内容：browser生成colgroupと、その配下へ移されたauthored colをStoreへ取り込む（When）
        await store.ingestNodePayloadAndWait([
            Self.unannotatedBrowserNodePayload(
                id: browserColumnGroupReference,
                standardID: "",
                selector: "",
                domPath: browserColumnGroupPath,
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "colgroup"
            ),
            Self.unannotatedBrowserNodePayload(
                id: browserColumnReference,
                standardID: "",
                selector: "",
                domPath: browserColumnPath,
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "col"
            )
        ])
        let inspectedColumnGroup = try #require(
            store.nodes.first { $0.id == browserColumnGroupReference }
        )
        store.selectNode(id: browserColumnReference)
        let inspectedColumn = try #require(store.selectedNode)
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：implicit colgroupはadopt不可で、authored colにはsource range/hashが戻りdry-runも原文を変更しない（Then）
        #expect(!inspectedColumnGroup.canAdoptIdentity)
        #expect(inspectedColumnGroup.locator?.sourceStart == -1)
        #expect(sourceColumn.locator.domPath == "table:nth-of-type(1) > col:nth-of-type(1)")
        #expect(inspectedColumn.reference == sourceColumn.reference)
        #expect(inspectedColumn.locator?.domPath == sourceColumn.locator.domPath)
        #expect(inspectedColumn.locator?.sourceStart == sourceColumn.locator.sourceRange.start)
        #expect(inspectedColumn.canAdoptIdentity)
        #expect(preview.changed)
        #expect(preview.unifiedDiff.contains("data-og-internal-id"))
        #expect(htmlAfterDryRun == originalHTML)
    }

    /// 論理名（日本語）: Browser implicit document container source mergeテスト
    /// 概要: `head` / `body`を省略したsource nodeをWebKitが各containerへ配置してもShared locatorへ結びます。
    @Test("WebKitが補完したhead bodyを越えてauthored nodeをsourceへmergeする")
    func testImplicitBrowserHeadAndBodyMergeToAuthoredSourceLocators() async throws {
        // コンディション：body開始前後に同tag metadataを置き、head/bodyを省略した標準HTMLを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = "<!doctype html><html><style>.head{color:red}</style><title>Page</title><main>Main</main><style>.body{color:blue}</style></html>"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNodes = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference).nodes
        let sourceTitle = try #require(sourceNodes.first { $0.tagName == "title" })
        let sourceMain = try #require(sourceNodes.first { $0.tagName == "main" })
        let sourceStyles = sourceNodes.filter { $0.tagName == "style" }
        let sourceHeadStyle = try #require(sourceStyles.first)
        let sourceBodyStyle = try #require(sourceStyles.last)
        let browserHeadStyleReference = "ogref-session:node:webkit:implicit-head-style"
        let browserTitleReference = "ogref-session:node:webkit:implicit-head-title"
        let browserMainReference = "ogref-session:node:webkit:implicit-body-main"
        let browserBodyStyleReference = "ogref-session:node:webkit:implicit-body-style"

        // 検証内容：WebKit補完後のhead/titleとbody/main pathを持つpayloadを取り込む（When）
        await store.ingestNodePayloadAndWait([
            Self.unannotatedBrowserNodePayload(
                id: browserHeadStyleReference,
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > head:nth-of-type(1) > style:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "style"
            ),
            Self.unannotatedBrowserNodePayload(
                id: browserTitleReference,
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > head:nth-of-type(1) > title:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "title"
            ),
            Self.unannotatedBrowserNodePayload(
                id: browserMainReference,
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > main:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "main"
            ),
            Self.unannotatedBrowserNodePayload(
                id: browserBodyStyleReference,
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > style:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "style"
            )
        ])
        let inspectedHeadStyle = try #require(store.nodes.first { $0.id == browserHeadStyleReference })
        let inspectedTitle = try #require(store.nodes.first { $0.id == browserTitleReference })
        let inspectedMain = try #require(store.nodes.first { $0.id == browserMainReference })
        let inspectedBodyStyle = try #require(store.nodes.first { $0.id == browserBodyStyleReference })
        store.selectNode(id: browserHeadStyleReference)
        store.previewSelectedNodeAdoption(scope: .node)
        let headPreview = try #require(store.nodeAdoptionPreview)
        store.selectNode(id: browserBodyStyleReference)
        store.previewSelectedNodeAdoption(scope: .node)
        let bodyPreview = try #require(store.nodeAdoptionPreview)
        let afterInspection = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：head/body双方のbrowser nodeへsource reference/rangeが戻り、inspectionだけではsourceを変更しない（Then）
        #expect(sourceTitle.locator.domPath == "html:nth-of-type(1) > title:nth-of-type(1)")
        #expect(sourceMain.locator.domPath == "html:nth-of-type(1) > main:nth-of-type(1)")
        #expect(sourceHeadStyle.locator.domPath == "html:nth-of-type(1) > style:nth-of-type(1)")
        #expect(sourceBodyStyle.locator.domPath == "html:nth-of-type(1) > style:nth-of-type(2)")
        #expect(inspectedHeadStyle.reference == sourceHeadStyle.reference)
        #expect(inspectedHeadStyle.locator?.sourceStart == sourceHeadStyle.locator.sourceRange.start)
        #expect(inspectedTitle.reference == sourceTitle.reference)
        #expect(inspectedTitle.locator?.sourceStart == sourceTitle.locator.sourceRange.start)
        #expect(inspectedMain.reference == sourceMain.reference)
        #expect(inspectedMain.locator?.sourceStart == sourceMain.locator.sourceRange.start)
        #expect(inspectedBodyStyle.reference == sourceBodyStyle.reference)
        #expect(inspectedBodyStyle.locator?.sourceStart == sourceBodyStyle.locator.sourceRange.start)
        #expect(inspectedHeadStyle.reference != inspectedBodyStyle.reference)
        #expect(headPreview.reference != bodyPreview.reference)
        #expect(headPreview.changed && bodyPreview.changed)
        #expect(afterInspection == originalHTML)
    }

    /// 論理名（日本語）: Implicit / authored table container順序投影テスト
    /// 概要: implicit/authored `tbody` / `colgroup`のbrowser sibling indexをsource順に投影し、selectorなしnodeを正しく結びます。
    @Test("implicitとauthored table groupをsource順browser pathでmergeしてadoptできる")
    func testImplicitAndAuthoredTableGroupsProjectBrowserSiblingIndexes() async throws {
        // コンディション：direct/authored colとtrを同じtableに置き、全nodeをsafe selectorなしにする（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = """
        <!doctype html><html><body><table>
          <col><colgroup><col></colgroup>
          <tr><td>Implicit</td></tr>
          <tbody><tr><td>Authored</td></tr></tbody>
        </table></body></html>
        """
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNodes = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference).nodes
        let sourceColumnGroup = try #require(sourceNodes.first { $0.tagName == "colgroup" })
        let sourceTableBody = try #require(sourceNodes.first { $0.tagName == "tbody" })
        let sourceColumns = sourceNodes.filter { $0.tagName == "col" }
        let sourceCells = sourceNodes.filter { $0.tagName == "td" }
        let directColumnSource = try #require(sourceColumns.first)
        let authoredColumnSource = try #require(sourceColumns.last)
        let directCellSource = try #require(sourceCells.first)
        let authoredCellSource = try #require(sourceCells.last)

        // 検証内容：WebKitでimplicit groupが先に数えられたbrowser pathをselectorなしで取り込む（When）
        await store.ingestNodePayloadAndWait([
            Self.unannotatedBrowserNodePayload(
                id: "browser-implicit-column-group",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > colgroup:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "colgroup"
            ),
            Self.unannotatedBrowserNodePayload(
                id: "browser-direct-column",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > colgroup:nth-of-type(1) > col:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "col"
            ),
            Self.unannotatedBrowserNodePayload(
                id: "browser-authored-column",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > colgroup:nth-of-type(2) > col:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "col"
            ),
            Self.unannotatedBrowserNodePayload(
                id: "browser-implicit-table-body",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "tbody"
            ),
            Self.unannotatedBrowserNodePayload(
                id: "browser-direct-cell",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(1) > tr:nth-of-type(1) > td:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "td"
            ),
            Self.unannotatedBrowserNodePayload(
                id: "browser-authored-cell",
                standardID: "",
                selector: "",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > table:nth-of-type(1) > tbody:nth-of-type(2) > tr:nth-of-type(1) > td:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "td"
            )
        ])
        let implicitColumnGroup = try #require(
            store.nodes.first { $0.id == "browser-implicit-column-group" }
        )
        let directColumn = try #require(store.nodes.first { $0.id == "browser-direct-column" })
        let authoredColumn = try #require(store.nodes.first { $0.id == "browser-authored-column" })
        let implicitTableBody = try #require(
            store.nodes.first { $0.id == "browser-implicit-table-body" }
        )
        let directCell = try #require(store.nodes.first { $0.id == "browser-direct-cell" })
        let authoredCell = try #require(store.nodes.first { $0.id == "browser-authored-cell" })
        store.selectNode(id: "browser-implicit-table-body")
        store.previewSelectedNodeAdoption(scope: .node)
        let implicitPreview = store.nodeAdoptionPreview
        store.selectNode(id: "browser-direct-column")
        store.previewSelectedNodeAdoption(scope: .node)
        let columnPreview = try #require(store.nodeAdoptionPreview)
        store.selectNode(id: "browser-direct-cell")
        store.previewSelectedNodeAdoption(scope: .node)
        let cellPreview = try #require(store.nodeAdoptionPreview)
        let afterDryRuns = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：implicit groupを含むbrowser indexごとに正しいsource rangeへ戻り、direct col/trもdry-run可能で無書込となる（Then）
        #expect(sourceColumns.allSatisfy { $0.locator.selector == nil })
        #expect(sourceCells.allSatisfy { $0.locator.selector == nil })
        #expect(sourceColumnGroup.locator.domPath.hasSuffix("colgroup:nth-of-type(1)"))
        #expect(sourceTableBody.locator.domPath.hasSuffix("tbody:nth-of-type(1)"))
        #expect(!implicitColumnGroup.canAdoptIdentity)
        #expect(!implicitTableBody.canAdoptIdentity)
        #expect(implicitColumnGroup.locator?.sourceStart == -1)
        #expect(implicitTableBody.locator?.sourceStart == -1)
        #expect(implicitColumnGroup.reference != sourceColumnGroup.reference)
        #expect(implicitTableBody.reference != sourceTableBody.reference)
        #expect(implicitPreview == nil)
        #expect(directColumn.reference == directColumnSource.reference)
        #expect(authoredColumn.reference == authoredColumnSource.reference)
        #expect(directCell.reference == directCellSource.reference)
        #expect(authoredCell.reference == authoredCellSource.reference)
        #expect(directColumn.locator?.sourceStart == directColumnSource.locator.sourceRange.start)
        #expect(authoredColumn.locator?.sourceStart == authoredColumnSource.locator.sourceRange.start)
        #expect(directCell.locator?.sourceStart == directCellSource.locator.sourceRange.start)
        #expect(authoredCell.locator?.sourceStart == authoredCellSource.locator.sourceRange.start)
        #expect(Set([directColumn.reference, authoredColumn.reference]).count == 2)
        #expect(Set([directCell.reference, authoredCell.reference]).count == 2)
        #expect(columnPreview.changed && cellPreview.changed)
        #expect(columnPreview.reference != cellPreview.reference)
        #expect(afterDryRuns == originalHTML)
    }

    /// 論理名（日本語）: Character reference標準ID source mergeテスト
    /// 概要: HTML character referenceを含む標準IDをWebKitと同じDOM値へ復号し、安全なselectorでsource locatorへmergeできることを確認します。
    @Test("character referenceを含む標準IDをdecoded selectorでmergeしてadopt previewできる")
    func testCharacterReferenceStandardIDMergesWithDecodedBrowserSelector() async throws {
        // コンディション：numeric character referenceで空白を表した標準IDと、WebKitが復号したselector payloadを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = "<!doctype html><main id=\"hero&#32;card\">Hero</main>"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let sourceNode = try #require(
            try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
                .nodes
                .first { $0.tagName == "main" }
        )
        let browserReference = "ogref-session:node:webkit:entity-standard-id"

        // 検証内容：WebKitのdecoded ID / selectorを持つ未注釈payloadを取り込み、adoptionをdry-runする（When）
        await store.ingestNodePayloadAndWait([
            Self.unannotatedBrowserNodePayload(
                id: browserReference,
                standardID: "hero card",
                selector: "[id=\"hero card\"]",
                domPath: "html:nth-of-type(1) > body:nth-of-type(1) > main:nth-of-type(1)",
                documentURL: fixture.htmlURL.standardizedFileURL.absoluteString,
                tagName: "main"
            )
        ])
        store.selectNode(id: browserReference)
        let inspectedNode = try #require(store.selectedNode)
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：decoded標準IDがShared sourceと一致し、既存selectorを再利用してinternal IDだけを提案しsourceは未変更になる（Then）
        #expect(sourceNode.attributes["id"] == "hero card")
        #expect(sourceNode.locator.selector == "[id=\"hero card\"]")
        #expect(inspectedNode.reference == sourceNode.reference)
        #expect(inspectedNode.standardID == "hero card")
        #expect(inspectedNode.locator?.sourceStart == sourceNode.locator.sourceRange.start)
        #expect(inspectedNode.canAdoptIdentity)
        #expect(preview.changed)
        #expect(preview.unifiedDiff.contains("data-og-internal-id"))
        #expect(!preview.unifiedDiff.contains("data-og-id="))
        #expect(htmlAfterDryRun == originalHTML)
    }

    /// 論理名（日本語）: Optional end tag App source mergeテスト
    /// 概要: 終了`li`を省略した標準HTMLでもbrowser sibling pathからShared source locatorを取得し、adoption dry-runを行えることを確認します。
    @Test("optional li end tagをbrowser sibling pathでmergeしてadopt previewできる")
    func testOptionalListItemEndTagsMergeAndPreviewAdoption() async throws {
        // コンディション：2つのliの終了tagを標準HTMLの規則で省略したpageを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let originalHTML = "<!doctype html><html><body><ul><li>First<li>Second</ul></body></html>"
        try originalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        _ = try selectFirstPage(in: store)
        let pageReference = try #require(store.selectedPageReferenceID())
        let core = OpenGraphiteAgentCore(
            contract: OpenGraphiteContract.loadDefault(startingAt: fixture.projectURL)
        )
        let listItems = try core.pageGraph(projectURL: fixture.projectURL, pageID: pageReference)
            .nodes
            .filter { $0.tagName == "li" }
        let secondSource = try #require(listItems.last)
        let browserReference = "ogref-session:node:webkit:second-li"
        let browserDOMPath = "html:nth-of-type(1) > body:nth-of-type(1) > ul:nth-of-type(1) > li:nth-of-type(2)"

        // 検証内容：browserで2番目のsiblingとなったli payloadを取り込み、adoptionをdry-runする（When）
        await store.ingestNodePayloadAndWait([
            [
                "id": browserReference,
                "authoredID": "",
                "standardID": "",
                "internalID": "",
                "reference": browserReference,
                "annotationStatus": "none",
                "referenceStability": "session",
                "locator": [
                    "documentURL": fixture.htmlURL.standardizedFileURL.absoluteString,
                    "domPath": browserDOMPath,
                    "sourceRange": ["start": -1, "end": -1],
                    "contentHash": "webkit-second-li"
                ],
                "tagName": "li",
                "type": "",
                "cssVariables": [String: String](),
                "hidden": false,
                "locked": false,
                "depth": 1
            ]
        ])
        store.selectNode(id: browserReference)
        let inspectedItem = try #require(store.selectedNode)
        store.previewSelectedNodeAdoption(scope: .node)
        let preview = try #require(store.nodeAdoptionPreview)
        let htmlAfterDryRun = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：2つのliはsibling pathを持ち、選択nodeは正確なsource range/hashでdry-runされ、source bytesは不変である（Then）
        #expect(listItems.count == 2)
        #expect(listItems.map(\.locator.domPath).allSatisfy { !$0.contains("li:nth-of-type(1) > li") })
        #expect(secondSource.locator.domPath == browserDOMPath)
        #expect(inspectedItem.reference == secondSource.reference)
        #expect(inspectedItem.locator?.sourceStart == secondSource.locator.sourceRange.start)
        #expect(inspectedItem.locator?.sourceEnd == secondSource.locator.sourceRange.end)
        #expect(preview.changed)
        #expect(preview.unifiedDiff.contains("data-og-internal-id"))
        #expect(htmlAfterDryRun == originalHTML)
    }

    /// 論理名（日本語）: コンポーネント継承元解決テスト
    /// 概要: 選択中 instance の継承元 master を Inspector 用情報へ解決し、component canvas へ移動できることを確認します。
    @Test("instance選択から継承元componentへ移動できる")
    func testComponentSourceResolutionAndReveal() throws {
        // コンディション：component master HTML と、その instance を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try """
        <!doctype html>
        <html><body>
        <feature-card data-og-id="feature-card-master" data-og-component="feature-card"><template></template></feature-card>
        </body></html>
        """.write(to: componentURL, atomically: true, encoding: .utf8)
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(name: "Desktop", x: 1120, y: 0, width: 1180, height: 1900)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "home-card-title",
                "tagName": "featurecardtitle",
                "type": "text",
                "sourceComponentID": "feature-card",
                "sourceInstanceID": "home-card",
                "depth": 1
            ]
        ])
        store.selectNode(id: "home-card-title")

        // 検証内容：選択ノードの継承元を解決し、Inspector の移動ボタン相当の処理を実行する
        let source = try #require(store.selectedComponentSource)
        store.revealComponentSource(source)

        // 期待値：master の名称と場所が解決され、Components 側の master root が選択される
        #expect(source.componentID == "feature-card")
        #expect(source.masterNodeID == "feature-card-master")
        #expect(source.locationLabel == "Main / design-system.html")
        #expect(source.componentPagePath == "_components/design-system.html")
        #expect(source.canvasLabel == "1120, 0 · 1180 x 1900")
        #expect(store.selectedCanvasSegment == .components)
        #expect(store.selectedComponentPageID == "design-system")
        #expect(store.selectedNodeID == "feature-card-master")
        #expect(store.statusMessage == "feature-card の component master を表示しています。")
    }

    /// 論理名（日本語）: Runtime展開Component CSS同期テスト
    /// 概要: ページ上の runtime 展開済み component node が、component source CSS を Inspector 表示値と保存先として使うことを確認します。
    @Test("展開component nodeはsource CSSをInspector値と保存先に使う")
    func testGeneratedComponentNodeUsesComponentSourceCSS() async throws {
        // コンディション：component master と page instance を持つ一時プロジェクトを用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try """
        <!doctype html>
        <html><body>
        <site-header data-og-id="site-header-master" data-og-component="site-header" data-og-internal-id="site-header-node"><template></template></site-header>
        </body></html>
        """.write(to: componentURL, atomically: true, encoding: .utf8)
        try """
        [data-og-internal-id="site-header-node"] {
          position: sticky;
          top: 0;
          padding: 24px 0 18px;
          background: #08090a;
          z-index: 30;
        }

        @media (min-width: 500px) {
          [data-og-internal-id="site-header-node"] {
            top: 24px;
          }
        }
        """.write(
            to: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentURL),
            atomically: true,
            encoding: .utf8
        )
        try """
        <!doctype html>
        <html><body>
        <Page data-og-id="page" data-og-type="page" data-og-internal-id="page-node">
          <og-instance data-og-id="site-header" data-og-type="frame" data-og-component="site-header" data-og-internal-id="site-header-instance"></og-instance>
        </Page>
        </body></html>
        """.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(name: "Desktop", x: 1120, y: 0, width: 1180, height: 1900)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let componentPage = try #require(store.loadedProject?.project.collections.first?.components.first)
        store.selectComponentPage(internalID: componentPage.internalID)
        await store.ingestNodePayloadAndWait([
            [
                "id": "site-header-master",
                "internalID": "site-header-node",
                "tagName": "siteheader",
                "activeMediaQueries": [String](),
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectPagesSegment()
        _ = try selectFirstPage(in: store)

        // 検証内容：runtime 展開後の component node payload を取り込み、CSS を更新する（When）
        await store.ingestNodePayloadAndWait([
            [
                "id": "site-header",
                "internalID": "site-header-node",
                "tagName": "siteheader",
                "type": "frame",
                "layout": "horizontal",
                "sourceComponentID": "site-header",
                "sourceInstanceID": "site-header",
                "activeMediaQueries": ["(min-width: 500px)"],
                "cssVariables": [String: String](),
                "depth": 1
            ]
        ])
        store.selectNode(id: "site-header")
        let initialReloadToken = store.reloadToken(for: fixture.htmlURL)
        let activeSourceTop = store.selectedNode?.cssVariables["top"]
        store.updateCSSVariable(key: "top", value: "12px")

        // 期待値：Inspector 用 node は component CSS を表示し、編集結果も component companion CSS へ保存される（Then）
        let selectedNode = try #require(store.selectedNode)
        let componentCSS = try String(
            contentsOf: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: componentURL),
            encoding: .utf8
        )
        #expect(selectedNode.cssVariables["position"] == "sticky")
        #expect(selectedNode.cssVariables["background"] == "#08090a")
        #expect(selectedNode.cssVariables["z-index"] == "30")
        #expect(activeSourceTop == "24px")
        #expect(store.selectedNode?.cssVariables["top"] == "12px")
        #expect(componentCSS.contains("top: 0;"))
        #expect(componentCSS.contains("top: 12px;"))
        #expect(!componentCSS.contains("top: 24px;"))
        #expect(store.cssMutation == nil)
        #expect(store.reloadToken(for: fixture.htmlURL) == initialReloadToken + 1)
        #expect(!FileManager.default.fileExists(atPath: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: fixture.htmlURL).path))
        #expect(store.lastError == nil)
    }

    /// 論理名（日本語）: 静的フロー元ホバー取り込みテスト
    /// 概要: WebView から届く hover 対象リンク ID が Store に保持され、空 ID で解除されることを検証します。
    @Test("静的フロー元hover payloadを保持して解除できる")
    func testIngestStaticFlowSourceHoverPayloadStoresAndClears() {
        // コンディション：静的フロー元リンクの hover payload と page URL を用意する（Given）
        let store = EditorStore()
        let pageURL = URL(fileURLWithPath: "/tmp/OpenGraphiteFlow/index.html")

        // 検証内容：hover payload を取り込み、別 page の解除要求と同一 page の解除要求を順に処理する（When）
        store.ingestStaticFlowSourceHoverPayload(
            [
                "id": "docs-button:./docs.html",
                "sourceNodeID": "docs-button"
            ],
            pageURL: pageURL,
            pageInternalID: "index-card"
        )
        store.clearStaticFlowSourceHover(pageURL: URL(fileURLWithPath: "/tmp/OpenGraphiteFlow/docs.html"), pageInternalID: "index-card")
        store.clearStaticFlowSourceHover(pageURL: pageURL, pageInternalID: "other-card")
        let retainedHover = store.hoveredStaticFlowSource
        store.ingestStaticFlowSourceHoverPayload(["id": ""], pageURL: pageURL, pageInternalID: "index-card")

        // 期待値：同一 URL かつ同一 page internalID の空 ID だけが hover 状態を解除する（Then）
        #expect(retainedHover?.pageURL == pageURL.standardizedFileURL)
        #expect(retainedHover?.pageInternalID == "index-card")
        #expect(retainedHover?.linkID == "docs-button:./docs.html")
        #expect(retainedHover?.sourceNodeID == "docs-button")
        #expect(store.hoveredStaticFlowSource == nil)
    }

    /// 論理名（日本語）: 静的フローリンク内部ID保持テスト
    /// 概要: 同じ HTML URL を共有する複数 page から届いたリンク payload が、page 内部 ID ごとに分離されることを検証します。
    @Test("静的フローリンクpayloadをpage内部IDごとに保持する")
    func testIngestStaticFlowLinkPayloadStoresByPageInternalID() throws {
        // コンディション：同じ HTML URL を共有する2つの page card から別々のリンク payload が届く（Given）
        let store = EditorStore()
        let pageURL = URL(fileURLWithPath: "/tmp/OpenGraphiteFlow/index.html")
        let firstPayload: [[String: Any]] = [
            [
                "id": "first-link:./docs.html",
                "sourceNodeID": "first-link",
                "targetHref": "./docs.html",
                "targetURL": "",
                "x": 10.0,
                "y": 20.0,
                "width": 30.0,
                "height": 12.0
            ]
        ]
        let secondPayload: [[String: Any]] = [
            [
                "id": "second-link:./downloads.html",
                "sourceNodeID": "second-link",
                "targetHref": "./downloads.html",
                "targetURL": "",
                "x": 40.0,
                "y": 50.0,
                "width": 60.0,
                "height": 14.0
            ]
        ]

        // 検証内容：同じ URL の payload を異なる page 内部 ID で取り込む（When）
        store.ingestStaticFlowLinkPayload(firstPayload, pageURL: pageURL, pageInternalID: "first-card")
        store.ingestStaticFlowLinkPayload(secondPayload, pageURL: pageURL, pageInternalID: "second-card")

        // 期待値：URL fallback は最新 payload を保持し、内部 ID 別の payload は互いに上書きされない（Then）
        #expect(store.staticFlowLinksByPageURL[pageURL.standardizedFileURL]?.first?.sourceNodeID == "second-link")
        #expect(store.staticFlowLinksByPageInternalID["first-card"]?.first?.sourceNodeID == "first-link")
        #expect(store.staticFlowLinksByPageInternalID["second-card"]?.first?.sourceNodeID == "second-link")
    }

    /// 論理名（日本語）: 階層参照ID生成テスト
    /// 概要: Chapter、page、component canvas が各階層で agent 向けの一意な参照 ID を生成できることを確認します。
    @Test("Chapter/Page/Componentの参照IDを階層ごとに生成する")
    func testHierarchyReferenceIDsUseInternalIDs() throws {
        // コンディション：Chapter、page、component が内部 ID 候補を共有する project を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        let componentURL = fixture.publicURL.appendingPathComponent("card.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        try "<!doctype html>\n<html><body>card</body></html>".write(
            to: componentURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "opaque",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "opaque",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    internalID: "opaque",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "opaque",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "card",
                    internalID: "opaque",
                    path: "card.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 320, height: 240)
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：読み込み後の正規化済み内部 ID から階層参照 ID を生成する
        store.openProject(at: fixture.projectURL)
        let loadedProject = try #require(store.loadedProject?.project)
        let docsChapter = loadedProject.chapters[1]
        let docsPage = try #require(docsChapter.pages.first)
        let componentCollection = try #require(loadedProject.collections.first)
        let componentPage = try #require(loadedProject.components.first)
        store.selectChapter(internalID: docsChapter.internalID)
        store.selectPage(internalID: docsPage.internalID)
        let docsPageReferenceID = store.selectedPageReferenceID()
        store.selectComponentPage(internalID: componentPage.internalID)
        let componentReferenceID = store.selectedPageReferenceID()
        let hierarchyInternalIDs = loadedProject.chapters.map(\.internalID)
            + loadedProject.chapters.flatMap(\.pages).map(\.internalID)
            + loadedProject.collections.map(\.internalID)
            + loadedProject.components.map(\.internalID)

        // 期待値：内部 ID は manifest 階層全体で一意になり、page は Chapter を含む複合参照になる
        #expect(Set(hierarchyInternalIDs).count == hierarchyInternalIDs.count)
        #expect(store.chapterReferenceID(for: docsChapter) == "ogref:chapter:\(docsChapter.internalID)")
        #expect(docsPageReferenceID == "ogref:page:\(docsChapter.internalID):\(docsPage.internalID)")
        #expect(componentReferenceID == "ogref:component:\(componentCollection.internalID):\(componentPage.internalID)")
    }

    /// 論理名（日本語）: 未注釈browser node payload生成関数
    /// 処理概要: source mergeテスト用に、safe selectorとbrowser DOM pathを持つ最小WebCanvas payloadを生成します。
    ///
    /// - Parameters:
    ///   - id: WebCanvas session selection key。
    ///   - standardID: authored標準`id`。
    ///   - selector: WebKitが確認した一意なsafe selector。
    ///   - domPath: WebKit補完後のDOM path。
    ///   - documentURL: 対象resource URL。
    ///   - tagName: 対象の標準tag名。
    /// - Returns: `ingestNodePayload` へ渡す辞書。
    private static func unannotatedBrowserNodePayload(
        id: String,
        standardID: String,
        selector: String,
        domPath: String,
        documentURL: String,
        tagName: String
    ) -> [String: Any] {
        [
            "id": id,
            "authoredID": "",
            "standardID": standardID,
            "internalID": "",
            "reference": id.hasPrefix("ogref-session:") ? id : "ogref-session:node:webkit:\(id)",
            "annotationStatus": "none",
            "referenceStability": "session",
            "locator": [
                "documentURL": documentURL,
                "selector": selector,
                "domPath": domPath,
                "sourceRange": ["start": -1, "end": -1],
                "contentHash": "webkit-\(id)"
            ],
            "tagName": tagName,
            "cssVariables": [String: String](),
            "hidden": false,
            "locked": false,
            "depth": 3
        ]
    }

    /// 論理名（日本語）: Capability evidence payload変換関数
    /// 処理概要: Shared nodeの標準DOM evidenceをWebCanvas payloadと同じ辞書表現へ変換します。
    ///
    /// - Parameter evidence: Shared inspectionが返したcapability evidence。
    /// - Returns: `ingestNodePayload`へ渡す辞書。
    private static func capabilityEvidencePayload(
        _ evidence: OpenGraphiteNodeCapabilityEvidence
    ) -> [String: Any] {
        [
            "isProjectResourceRoot": evidence.isProjectResourceRoot,
            "isNativeControl": evidence.isNativeControl,
            "isCustomElement": evidence.isCustomElement,
            "isLink": evidence.isLink,
            "hasDirectText": evidence.hasDirectText,
            "hasElementChildren": evidence.hasElementChildren,
            "hasMediaContent": evidence.hasMediaContent,
            "hasSVGContent": evidence.hasSVGContent,
            "hasMaskContent": evidence.hasMaskContent,
            "ariaRole": evidence.ariaRole ?? "",
            "resolvedDisplay": evidence.resolvedDisplay ?? ""
        ]
    }

    /// 論理名（日本語）: Source対応WebCanvas payload生成関数
    /// 処理概要: Shared source nodeへ意図的なruntime capability/evidence/属性差を重ねる安全側mergeテスト用payloadを生成します。
    ///
    /// - Parameters:
    ///   - id: WebCanvas selection key。
    ///   - sourceNode: locatorとstable internal IDを供給するShared node。
    ///   - capabilities: WebCanvasが主張するcapability raw value一覧。
    ///   - evidence: WebCanvasが主張するsemantic evidence。
    ///   - attributes: WebCanvas runtime属性辞書。
    ///   - role: WebCanvas runtime role。
    ///   - hidden: WebCanvas runtime hidden属性状態。
    ///   - locked: WebCanvas runtime lock状態。
    /// - Returns: `ingestNodePayload`へ渡す辞書。
    private static func browserPayload(
        id: String,
        sourceNode: OpenGraphiteAgentNode,
        capabilities: [String],
        evidence: [String: Any],
        attributes: [String: String],
        role: String,
        hidden: Bool,
        locked: Bool
    ) -> [String: Any] {
        [
            "id": id,
            "authoredID": sourceNode.id,
            "standardID": sourceNode.attributes["id"] ?? "",
            "internalID": sourceNode.internalID,
            "reference": sourceNode.reference,
            "annotationStatus": sourceNode.annotationStatus.rawValue,
            "referenceStability": sourceNode.referenceStability.rawValue,
            "locator": [
                "documentURL": sourceNode.locator.documentURL,
                "selector": sourceNode.locator.selector ?? "",
                "domPath": sourceNode.locator.domPath,
                "sourceRange": [
                    "start": sourceNode.locator.sourceRange.start,
                    "end": sourceNode.locator.sourceRange.end
                ],
                "contentHash": sourceNode.locator.contentHash
            ],
            "tagName": sourceNode.tagName,
            "capabilities": capabilities,
            "capabilityEvidence": evidence,
            "attributes": attributes,
            "role": role,
            "computedStyle": ["display": evidence["resolvedDisplay"] as? String ?? "block"],
            "cssVariables": sourceNode.cssVariables,
            "hasHiddenAttribute": hidden,
            "locked": locked,
            "depth": sourceNode.depth
        ]
    }

    /// 論理名（日本語）: 先頭ページ選択ヘルパー
    /// 概要: page 編集系テストで、Chapter 初期表示とは別に明示的な HTML カード選択を作ります。
    ///
    /// - Parameter store: page を選択する EditorStore。
    /// - Returns: 選択した先頭 page。
    private func selectFirstPage(in store: EditorStore) throws -> OpenGraphitePage {
        let page = try #require(store.loadedProject?.project.chapters.first?.pages.first)
        store.selectPage(internalID: page.internalID)
        return page
    }

    /// 論理名（日本語）: locale JSON読込ヘルパー
    /// 処理概要: テスト用 locale JSON を辞書として読み込みます。
    ///
    /// - Parameter url: 読み込む locale JSON の URL。
    /// - Returns: JSON object の辞書表現。
    private static func localeJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

@MainActor
private extension EditorStore {
    /// 論理名（日本語）: テスト用ノードpayload補完待機関数
    /// 処理概要: 軽量Layers payloadを取り込み、background source graphの補完完了まで待機します。
    ///
    /// - Parameter payload: DOMから収集されたノード辞書の配列。
    func ingestNodePayloadAndWait(_ payload: [[String: Any]]) async {
        ingestNodePayload(payload)
        await waitForNodeSourceEnrichment()
    }
}

/// 論理名（日本語）: エディターストア履歴テストfixture
/// 概要: 一時ディレクトリに `.ogp` と HTML を作成し、同期履歴テスト用のプロジェクトを提供します。
private struct EditorStoreHistoryFixture {
    let rootURL: URL
    let publicURL: URL
    let projectURL: URL
    let htmlURL: URL

    /// 論理名（日本語）: エディターストア履歴fixture初期化関数
    /// 処理概要: 一時ルート、public ディレクトリ、HTML、`.ogp` を作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteEditorStoreHistory-\(UUID().uuidString)")
        publicURL = rootURL.appendingPathComponent("public")
        projectURL = rootURL.appendingPathComponent("Project.ogp")
        htmlURL = publicURL.appendingPathComponent("index.html")

        try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
        let cssLibraryURL = rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        try FileManager.default.createDirectory(
            at: cssLibraryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "".write(to: cssLibraryURL, atomically: true, encoding: .utf8)
        try "<!doctype html>\n<html><body>initial</body></html>".write(
            to: htmlURL,
            atomically: true,
            encoding: .utf8
        )

        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL)
    }

    /// 論理名（日本語）: project fixture書き換え関数
    /// 処理概要: 指定ページ一覧を持つ `.ogp` を fixture の project URL へ保存します。
    ///
    /// - Parameter pages: 保存する page entry 一覧。
    func writeProject(pages: [OpenGraphitePage]) throws {
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: pages
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL)
    }

    /// 論理名（日本語）: Companion CSS書き込み関数
    /// 処理概要: fixture の HTML と同名の companion CSS へ指定文字列を書き込みます。
    ///
    /// - Parameter css: 書き込む CSS。
    func writeCompanionCSS(_ css: String) throws {
        try css.write(
            to: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            atomically: true,
            encoding: .utf8
        )
    }

    /// 論理名（日本語）: Companion CSS読込関数
    /// 処理概要: fixture の HTML と同名の companion CSS を読み込みます。
    ///
    /// - Returns: companion CSS の全文。
    func readCompanionCSS() throws -> String {
        try String(contentsOf: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL), encoding: .utf8)
    }

    /// 論理名（日本語）: fixture削除関数
    /// 処理概要: テストで作成した一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

/// 論理名（日本語）: Project migration統合テストfixture
/// 概要: legacy Web contract、preview field、複数page/component、companion CSSを持つ一時Projectとsource snapshotを提供します。
private struct EditorStoreMigrationFixture {
    let rootURL: URL
    let publicURL: URL
    let secondaryDirectoryURL: URL
    let projectURL: URL
    let contractURL: URL
    let cssLibraryURL: URL
    let homeHTMLURL: URL
    let homeCSSURL: URL
    let secondaryHTMLURL: URL
    let secondaryCSSURL: URL
    let componentHTMLURL: URL
    let componentCSSURL: URL

    /// 論理名（日本語）: Project migration fixture初期化関数
    /// 処理概要: Web contract 0.1.0、既知legacy runtime属性/preview fieldを持つ複数source Projectを一時領域へ作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteEditorStoreMigration-\(UUID().uuidString)")
        publicURL = rootURL.appendingPathComponent("public", isDirectory: true)
        secondaryDirectoryURL = publicURL.appendingPathComponent("locked", isDirectory: true)
        projectURL = rootURL.appendingPathComponent("Project.ogp")
        contractURL = rootURL.appendingPathComponent("OpenGraphite.contract.json")
        cssLibraryURL = rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        homeHTMLURL = publicURL.appendingPathComponent("index.html")
        homeCSSURL = publicURL.appendingPathComponent("index.css")
        secondaryHTMLURL = secondaryDirectoryURL.appendingPathComponent("secondary.html")
        secondaryCSSURL = secondaryDirectoryURL.appendingPathComponent("secondary.css")
        componentHTMLURL = publicURL.appendingPathComponent("components.html")
        componentCSSURL = publicURL.appendingPathComponent("components.css")

        try FileManager.default.createDirectory(at: secondaryDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: cssLibraryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let homeHTML = """
        <!doctype html>
        <html>
        <body>
          <main id="home">
            <article data-og-internal-id="kept-article" data-og-selected="true">
              <p>Standard child</p>
            </article>
          </main>
        </body>
        </html>
        """
        let secondaryHTML = """
        <!doctype html>
        <html>
        <body>
          <aside class="secondary" data-og-editing="true">
            <span>Secondary child</span>
          </aside>
        </body>
        </html>
        """
        let componentHTML = """
        <!doctype html>
        <html>
        <body>
          <fixture-card data-og-component="fixture-card" data-og-internal-id="fixture-source">
            <span>Component source</span>
          </fixture-card>
          <og-placement
            data-og-internal-id="fixture-placement"
            data-og-source-component-internal-id="fixture-component"
            data-og-source-node-internal-id="fixture-source"
          ></og-placement>
          <og-placement
            data-og-internal-id="fixture-collapsed-placement"
            data-og-source-component-internal-id="fixture-component"
            data-og-source-node-internal-id="fixture-source"
          ></og-placement>
        </body>
        </html>
        """
        try homeHTML.write(to: homeHTMLURL, atomically: true, encoding: .utf8)
        try secondaryHTML.write(to: secondaryHTMLURL, atomically: true, encoding: .utf8)
        try componentHTML.write(to: componentHTMLURL, atomically: true, encoding: .utf8)
        try ":root { --fixture-accent: #336699; }\n".write(
            to: cssLibraryURL,
            atomically: true,
            encoding: .utf8
        )
        try "#home { display: block; }\n".write(to: homeCSSURL, atomically: true, encoding: .utf8)
        try ".secondary { display: block; }\n".write(
            to: secondaryCSSURL,
            atomically: true,
            encoding: .utf8
        )
        try "fixture-card { display: block; }\n".write(
            to: componentCSSURL,
            atomically: true,
            encoding: .utf8
        )

        var legacyContract = OpenGraphiteContract.builtIn
        legacyContract.version = "0.1.0"
        let contractData = try JSONEncoder().encode(legacyContract)
        try contractData.write(to: contractURL)

        let project = OpenGraphiteProject(
            version: "1",
            name: "Migration Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 800, height: 600)
                ),
                OpenGraphitePage(
                    id: "secondary",
                    path: "locked/secondary.html",
                    canvas: OpenGraphiteCanvas(x: 840, y: 0, width: 800, height: 600)
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "components",
                    internalID: "fixture-collection",
                    components: [
                        OpenGraphitePage(
                            id: "fixture-component",
                            internalID: "fixture-component",
                            path: "components.html",
                            canvas: OpenGraphiteCanvas(
                                x: 0,
                                y: 0,
                                width: 800,
                                height: 600,
                                previewContext: OpenGraphitePreviewContext(
                                    fieldMocks: ["selectedLanguage": "ja"],
                                    placementMocks: [
                                        "fixture-placement": [
                                            "codeViewerMode": "preview",
                                            "selectedLanguage": "ja"
                                        ],
                                        "fixture-collapsed-placement": [
                                            "placementMode": "collapsed",
                                            "customState": "kept"
                                        ]
                                    ]
                                )
                            )
                        )
                    ]
                )
            ]
        )
        let projectData = try JSONEncoder().encode(project)
        try projectData.write(to: projectURL)
    }

    /// 論理名（日本語）: Project migration source snapshot取得関数
    /// 処理概要: migration前後で暗黙変更や部分書込を検出するため、fixtureの全source bytesを相対path別に読み込みます。
    ///
    /// - Returns: Project root相対pathをkey、file bytesをvalueとする辞書。
    func sourceSnapshot() throws -> [String: Data] {
        let sourceURLs = [
            "Project.ogp": projectURL,
            "OpenGraphite.contract.json": contractURL,
            "CSS/OpenGraphite.css": cssLibraryURL,
            "public/index.html": homeHTMLURL,
            "public/index.css": homeCSSURL,
            "public/locked/secondary.html": secondaryHTMLURL,
            "public/locked/secondary.css": secondaryCSSURL,
            "public/components.html": componentHTMLURL,
            "public/components.css": componentCSSURL
        ]
        return try sourceURLs.reduce(into: [String: Data]()) { snapshot, entry in
            snapshot[entry.key] = try Data(contentsOf: entry.value)
        }
    }

    /// 論理名（日本語）: Legacy/標準preview field衝突追加関数
    /// 処理概要: codeViewerModeの変換先と異なるhost.variantを同じplacement mockへ追加し、blocking migration fixtureを作ります。
    func addConflictingHostVariant() throws {
        let data = try Data(contentsOf: projectURL)
        var project = try JSONDecoder().decode(OpenGraphiteProject.self, from: data)
        project.collections[0].components[0].canvas.previewContext
            .placementMocks["fixture-placement", default: [:]]["host.variant"] = "code"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(project).write(to: projectURL, options: .atomic)
    }

    /// 論理名（日本語）: 後方page immutable設定関数
    /// 処理概要: stagingを許可したままpath順で後方のcommitだけを失敗させ、先行commitのrollbackを再現します。
    ///
    /// - Parameter immutable: 2番目のHTMLをuser immutableにする場合は`true`。
    func setSecondaryHTMLImmutable(_ immutable: Bool) throws {
        try FileManager.default.setAttributes(
            [.immutable: immutable],
            ofItemAtPath: secondaryHTMLURL.path
        )
    }

    /// 論理名（日本語）: Project migration fixture削除関数
    /// 処理概要: HTMLのimmutable flagを解除してからテスト用一時Projectを削除します。
    func cleanUp() {
        try? setSecondaryHTMLImmutable(false)
        try? FileManager.default.removeItem(at: rootURL)
    }
}
