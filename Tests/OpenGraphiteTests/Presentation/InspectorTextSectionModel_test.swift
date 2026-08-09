import Testing
import SwiftUI
@testable import OpenGraphite

/// 論理名（日本語）: インスペクターテキストセクションモデルテストスイート
/// 概要: Text Inspector が標準 HTML 編集カードと依存性カードを状態ごとに分けて構成することを確認します。
@Suite("インスペクターテキストセクションモデルテストスイート")
struct InspectorTextSectionModelTests {
    /// 論理名（日本語）: literal text表示モデルテスト
    /// 概要: i18n に依存しない text node では標準カードだけを表示することを確認します。
    @Test("literal textは標準カードだけを持つ")
    func testLiteralTextUsesOnlyPrimaryCard() {
        // コンディション：binding metadata を持たない text node を用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "OpenGraphite",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: nil,
            activeResolvedEditable: false,
            i18nInspection: nil
        )

        // 期待値：HTML Content の標準カードだけが表示対象になる（Then）
        #expect(model.primaryTitle == "Content")
        #expect(model.primarySourceLabel == "HTML")
        #expect(model.primaryValue == "OpenGraphite")
        #expect(model.dependencies.isEmpty)
    }

    /// 論理名（日本語）: 未設定i18n依存性表示モデルテスト
    /// 概要: binding metadata があるが runtime 未検出の場合、依存性カードを未設定状態で表示することを確認します。
    @Test("binding textでruntime未検出なら未設定依存性カードを持つ")
    func testBindingTextWithoutRuntimeShowsNotConfiguredDependencyCard() throws {
        // コンディション：i18n key を持つ binding text node だけを用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "OpenGraphite",
            fallbackTextContent: "HTML fallback",
            textSource: "binding",
            i18nKey: "home.hero.title",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：i18n runtime なしで Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: nil,
            activeResolvedEditable: false,
            i18nInspection: nil
        )
        let dependency = try #require(model.onlyLocaleDependency)

        // 期待値：標準カードは HTML fallback、追加カードは未設定の locale 依存性になる（Then）
        #expect(model.primaryTitle == "HTML Fallback")
        #expect(model.primaryValue == "HTML fallback")
        #expect(dependency.model.card.status == .notConfigured)
        #expect(dependency.model.card.action?.title == "Open Project Dependency")
        #expect(dependency.payload.localeOptions.isEmpty)
    }

    /// 論理名（日本語）: 編集可能locale依存性表示モデルテスト
    /// 概要: locale JSON が検出済みで編集可能な場合、依存性カードを editable として構成することを確認します。
    @Test("編集可能locale resourceはeditable依存性カードになる")
    func testEditableLocaleResourceShowsEditableDependencyCard() throws {
        // コンディション：ja locale resource で解決済みの binding text node と検出結果を用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "現在 ja",
            fallbackTextContent: "HTML fallback",
            textSource: "binding",
            i18nKey: "home.hero.title",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let inspection = Self.i18nInspection(
            resources: [
                OpenGraphiteI18nResourceStatus(
                    locale: "ja",
                    path: "/project/public/locales/ja.json",
                    exists: true,
                    editable: true
                )
            ]
        )

        // 検証内容：active locale を ja として Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: "ja",
            activeResolvedEditable: true,
            i18nInspection: inspection,
            i18nTextResourceValues: ["ja": "現在 ja"]
        )
        let dependency = try #require(model.onlyLocaleDependency)
        let option = try #require(dependency.payload.localeOptions.first { $0.locale == "ja" })

        // 期待値：HTML fallback と locale JSON 編集カードが別カードとして表示対象になる（Then）
        #expect(model.primaryTitle == "HTML Fallback")
        #expect(dependency.model.card.status == .editable)
        #expect(dependency.model.card.action == nil)
        #expect(dependency.payload.initialLocale == "ja")
        #expect(option.valueLabel == "Active Resolved (ja)")
        #expect(option.value == "現在 ja")
        #expect(option.isValueEditable == true)
    }

    /// 論理名（日本語）: 複数locale依存性表示モデルテスト
    /// 概要: preview locale を初期選択にしつつ、別 locale の resource 値も候補に含めることを確認します。
    @Test("複数locale resourceはactive localeを初期選択にして候補化される")
    func testLocaleResourceShowsAvailableLocaleOptions() throws {
        // コンディション：ja を active preview、eng を別 resource とする binding text node を用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "現在 ja",
            fallbackTextContent: "HTML fallback",
            textSource: "binding",
            i18nKey: "home.hero.title",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let inspection = Self.i18nInspection(
            resources: [
                OpenGraphiteI18nResourceStatus(
                    locale: "ja",
                    path: "/project/public/locales/ja.json",
                    exists: true,
                    editable: true
                ),
                OpenGraphiteI18nResourceStatus(
                    locale: "eng",
                    path: "/project/public/locales/eng.json",
                    exists: true,
                    editable: true
                )
            ]
        )

        // 検証内容：locale JSON 値を渡して Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: "ja",
            activeResolvedEditable: true,
            i18nInspection: inspection,
            i18nTextResourceValues: [
                "ja": "保存済み ja",
                "eng": "English title"
            ]
        )
        let dependency = try #require(model.onlyLocaleDependency)
        let jaOption = try #require(dependency.payload.localeOptions.first { $0.locale == "ja" })
        let engOption = try #require(dependency.payload.localeOptions.first { $0.locale == "eng" })

        // 期待値：active locale が初期選択になり、別 locale は JSON 値を表示する（Then）
        #expect(dependency.payload.initialLocale == "ja")
        #expect(dependency.payload.localeOptions.map(\.locale) == ["ja", "eng"])
        #expect(jaOption.value == "現在 ja")
        #expect(jaOption.isActive == true)
        #expect(engOption.valueLabel == "Resolved (eng)")
        #expect(engOption.value == "English title")
        #expect(engOption.isValueEditable == true)
    }

    /// 論理名（日本語）: 外部管理locale依存性表示モデルテスト
    /// 概要: loadPath が external の場合、依存性カードを external read-only として構成することを確認します。
    @Test("external loadPathはexternal依存性カードになる")
    func testExternalLoadPathShowsExternalDependencyCard() throws {
        // コンディション：binding text node と external loadPath の i18n 検出結果を用意する（Given）
        let node = OpenGraphiteNode(
            id: "title",
            tagName: "maintitle",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "Resolved",
            fallbackTextContent: "HTML fallback",
            textSource: "binding",
            i18nKey: "home.hero.title",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let inspection = Self.i18nInspection(
            loadPath: OpenGraphiteI18nConfigProperty(
                source: .external,
                value: nil,
                expression: "import.meta.env.VITE_I18N_LOAD_PATH",
                editable: false
            ),
            resources: []
        )

        // 検証内容：編集不可 context として Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: "ja",
            activeResolvedEditable: false,
            i18nInspection: inspection
        )
        let dependency = try #require(model.onlyLocaleDependency)
        let option = try #require(dependency.payload.localeOptions.first { $0.locale == "ja" })

        // 期待値：locale 依存性は external として表示され、値欄は編集不可になる（Then）
        #expect(dependency.model.card.status == .external)
        #expect(dependency.model.card.action?.title == "Open Project Dependency")
        #expect(option.isValueEditable == false)
    }

    /// 論理名（日本語）: 非i18n text source表示モデルテスト
    /// 概要: i18n key を持たない独自 text source では locale resource card を出さないことを確認します。
    @Test("非i18n text sourceはlocale依存性カードを持たない")
    func testNonI18nTextSourceDoesNotShowLocaleDependencyCard() {
        // コンディション：将来の依存性を想定した cms source の text node を用意する（Given）
        let node = OpenGraphiteNode(
            id: "headline",
            tagName: "headline",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "Resolved CMS title",
            fallbackTextContent: "Fallback CMS title",
            textSource: "cms",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )

        // 検証内容：標準 registry で Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: nil,
            activeResolvedEditable: false,
            i18nInspection: nil
        )

        // 期待値：標準カードは fallback を扱い、locale resource 依存性は出ない（Then）
        #expect(model.primaryTitle == "HTML Fallback")
        #expect(model.dependencies.isEmpty)
    }

    /// 論理名（日本語）: custom provider拡張表示モデルテスト
    /// 概要: Text dependency registry へ custom provider を追加すると既存モデル改造なしに card を追加できることを確認します。
    @Test("custom providerでText依存性カードを追加できる")
    func testCustomProviderCanAddTextDependencyCard() throws {
        // コンディション：cms source の text node と custom provider registry を用意する（Given）
        let node = OpenGraphiteNode(
            id: "headline",
            tagName: "headline",
            type: "text",
            layout: nil,
            role: nil,
            textContent: "Resolved CMS title",
            fallbackTextContent: "Fallback CMS title",
            textSource: "cms",
            cssVariables: [:],
            isHidden: false,
            isLocked: false,
            depth: 0
        )
        let registry = InspectorTextDependencyRegistry(
            providers: [
                InspectorTextDependencyProvider(
                    id: "text.cms",
                    makeModel: { context in
                        guard context.node.textSource == "cms" else { return nil }
                        let card = InspectorDependencyCardModel(
                            id: "text-cms-resource",
                            title: "CMS Content",
                            sourceLabel: "CMS",
                            status: .external,
                            detail: "headline is resolved by a CMS source.",
                            action: nil
                        )
                        return InspectorTextDependencyCardModel(
                            providerID: "text.cms",
                            card: card,
                            payload: "cms-payload"
                        )
                    },
                    makeView: { _, _ in
                        AnyView(EmptyView())
                    }
                )
            ]
        )

        // 検証内容：custom registry で Text section 表示モデルを構成する（When）
        let model = InspectorTextSectionModel(
            node: node,
            activeLocale: nil,
            activeResolvedEditable: false,
            i18nInspection: nil,
            registry: registry
        )
        let dependency = try #require(model.dependencies.first)
        let payload = try #require(dependency.payload(as: String.self))

        // 期待値：custom provider が生成した card と payload が保持される（Then）
        #expect(dependency.providerID == "text.cms")
        #expect(dependency.card.title == "CMS Content")
        #expect(dependency.card.status == .external)
        #expect(payload == "cms-payload")
    }

    /// 論理名（日本語）: 属性presence操作アクセシビリティテスト
    /// 概要: missing属性への空値追加とpresent属性の明示削除が、異なる表示とVoiceOverラベルを持つことを確認します。
    @Test("属性presenceの追加と削除を別actionとして案内する")
    func testAttributePresenceActionsExposeDistinctAccessibilityLabels() {
        // コンディション：missing属性とpresent-empty属性に対応するpresence actionを用意する（Given）
        let addAction = InspectorAttributePresenceAction(isPresent: false)
        let removeAction = InspectorAttributePresenceAction(isPresent: true)

        // 検証内容：各actionのsystem image名とaccessibility labelを取得する（When）
        let addLabel = addAction.accessibilityLabel(attributeName: "alt")
        let removeLabel = removeAction.accessibilityLabel(attributeName: "alt")

        // 期待値：空値の追加と属性tokenの削除を視覚・音声の両方で区別できる（Then）
        #expect(addAction == .addEmpty)
        #expect(addAction.systemImageName == "plus.circle")
        #expect(addLabel == "alt属性を追加")
        #expect(removeAction == .remove)
        #expect(removeAction.systemImageName == "minus.circle")
        #expect(removeLabel == "alt属性を削除")
    }

    /// 論理名（日本語）: i18n検査結果生成関数
    /// 処理概要: Text section model テストで使う最小 i18n runtime 検査結果を構成します。
    ///
    /// - Parameters:
    ///   - loadPath: backend.loadPath の検出結果。
    ///   - resources: locale JSON resource の状態一覧。
    /// - Returns: i18n runtime 検査結果。
    private static func i18nInspection(
        loadPath: OpenGraphiteI18nConfigProperty = OpenGraphiteI18nConfigProperty(
            source: .literal,
            value: "/locales/{{lng}}.json",
            expression: nil,
            editable: true
        ),
        resources: [OpenGraphiteI18nResourceStatus]
    ) -> OpenGraphiteI18nRuntimeInspection {
        OpenGraphiteI18nRuntimeInspection(
            schemaVersion: "1.0",
            pageURL: "/project/public/index.html",
            adapter: .i18next,
            configSource: "/project/public/i18n.js",
            lng: OpenGraphiteI18nConfigProperty(
                source: .literal,
                value: "ja",
                expression: nil,
                editable: true
            ),
            fallbackLng: OpenGraphiteI18nConfigProperty(
                source: .literal,
                value: "ja",
                expression: nil,
                editable: true
            ),
            loadPath: loadPath,
            localeField: "selectedLanguage",
            resources: resources,
            diagnostics: []
        )
    }
}

private extension InspectorTextSectionModel {
    var onlyLocaleDependency: (model: InspectorTextDependencyCardModel, payload: InspectorTextLocaleDependencyModel)? {
        guard dependencies.count == 1 else { return nil }
        let dependency = dependencies[0]
        guard dependency.providerID == LocaleResourceTextDependency.providerID,
              let payload = dependency.payload(as: InspectorTextLocaleDependencyModel.self)
        else {
            return nil
        }
        return (dependency, payload)
    }
}
