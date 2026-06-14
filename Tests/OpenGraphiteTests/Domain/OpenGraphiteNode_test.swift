import Testing
@testable import OpenGraphite

/// 論理名（日本語）: OpenGraphiteノード関連のテストスイート
/// 概要: HTML DOM から抽出された編集ノードの表示用メタ情報を確認します。
@Suite("OpenGraphiteノード関連のテストスイート")
struct OpenGraphiteNodeTests {
    /// 論理名（日本語）: ノード詳細行の基本表示テスト
    /// 概要: 種別、レイアウト、ロールが順番通りに表示されることを検証します。
    @Test("ノード詳細行を構成できる")
    func testDetailLineWithLayoutAndRole() {
        // コンディション：layout と role を持つフレームノードを用意する
        let node = OpenGraphiteNode(
            id: "hero",
            tagName: "herosection",
            type: "frame",
            layout: "vertical",
            role: "landing-hero",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：詳細行を取得する
        let detailLine = node.detailLine

        // 期待値：type、layout、role が区切り文字付きで並ぶ
        #expect(detailLine == "frame · vertical · landing-hero")
    }

    /// 論理名（日本語）: ノード状態表示テスト
    /// 概要: hidden と locked の状態が詳細行へ含まれることを検証します。
    @Test("ノード状態を詳細行へ含める")
    func testDetailLineIncludesHiddenAndLockedState() {
        // コンディション：非表示かつロックされたテキストノードを用意する
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

        // 検証内容：詳細行を取得する
        let detailLine = node.detailLine

        // 期待値：type に続いて hidden と locked が表示される
        #expect(detailLine == "text · hidden · locked")
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
            componentKind: "master",
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
}
