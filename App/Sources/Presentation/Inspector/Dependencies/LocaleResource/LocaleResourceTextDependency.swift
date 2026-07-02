import SwiftUI

/// 論理名（日本語）: テキストlocale依存性モデル
/// 概要: Text section で locale resource 由来の解決済み text を表示・編集するための provider 固有モデルです。
///
/// プロパティ:
/// - `i18nKey`: locale resource の key。
/// - `activeLocale`: active preview が解決した locale。
/// - `initialLocale`: UI 初期選択に使う locale。
/// - `localeOptions`: 選択可能な locale resource 候補。
struct InspectorTextLocaleDependencyModel: Equatable {
    var i18nKey: String?
    var activeLocale: String?
    var initialLocale: String?
    var localeOptions: [InspectorTextLocaleOption]
}

/// 論理名（日本語）: テキストlocale選択肢
/// 概要: Text Inspector の Localization card で参照・編集できる locale ごとの状態と値を表します。
///
/// プロパティ:
/// - `locale`: locale 名。
/// - `valueLabel`: 値表示欄のラベル。
/// - `value`: locale resource 上の text 値。
/// - `status`: locale resource の状態。
/// - `detail`: 状態の補足文。
/// - `isValueEditable`: 値欄を編集可能にするか。
/// - `isActive`: preview 表示中 locale か。
struct InspectorTextLocaleOption: Identifiable, Equatable {
    var id: String { locale }
    var locale: String
    var valueLabel: String
    var value: String
    var status: InspectorDependencyStatus
    var detail: String?
    var isValueEditable: Bool
    var isActive: Bool
}

/// 論理名（日本語）: locale依存性action生成関数
/// 処理概要: locale resource が編集可能でない場合に Project i18n 設定へ移動する action を返します。
///
/// - Parameter status: locale resource の状態。
/// - Returns: 依存性カード action。編集可能な場合は `nil`。
private func localeDependencyAction(for status: InspectorDependencyStatus) -> InspectorDependencyCardAction? {
    guard status != .editable else { return nil }
    return InspectorDependencyCardAction(
        title: "Open Project Dependency",
        projectResource: .i18nRuntime
    )
}

/// 論理名（日本語）: Locale Resource Text依存性provider
/// 概要: `data-i18n-key` と i18n runtime 検出結果から Text section の locale resource カードを提供します。
enum LocaleResourceTextDependency {
    static let providerID = "text.locale-resource"

    /// 論理名（日本語）: Locale Resource Text依存性provider定義
    /// 処理概要: model 生成と custom UI 生成を registry へ渡す provider です。
    static var provider: InspectorTextDependencyProvider {
        InspectorTextDependencyProvider(
            id: providerID,
            makeModel: makeModel,
            makeView: makeView
        )
    }

    /// 論理名（日本語）: Locale Resource Text依存性モデル生成関数
    /// 処理概要: i18n metadata を持つ text node にだけ locale resource カードモデルを生成します。
    ///
    /// - Parameter context: Text 依存性 provider の入力文脈。
    /// - Returns: 表示対象の場合は locale resource 依存性カードモデル。
    private static func makeModel(
        context: InspectorTextDependencyContext
    ) -> InspectorTextDependencyCardModel? {
        guard shouldDisplay(for: context) else { return nil }

        let localeOptions = localeOptions(in: context)
        let initialLocale = initialLocale(in: context, options: localeOptions)
        let initialState = localeOptions.first { $0.locale == initialLocale }.map {
            (status: $0.status, detail: $0.detail, isValueEditable: $0.isValueEditable)
        } ?? localeDependencyState(in: context, locale: initialLocale)
        let card = InspectorDependencyCardModel(
            id: "text-locale-resource",
            title: "Localization",
            sourceLabel: "Locale JSON",
            status: initialState.status,
            detail: initialState.detail,
            action: localeDependencyAction(for: initialState.status)
        )
        let payload = InspectorTextLocaleDependencyModel(
            i18nKey: context.node.i18nKey,
            activeLocale: context.activeResolvedText?.locale,
            initialLocale: initialLocale,
            localeOptions: localeOptions
        )
        return InspectorTextDependencyCardModel(
            providerID: providerID,
            card: card,
            payload: payload
        )
    }

    /// 論理名（日本語）: Locale Resource Text依存性view生成関数
    /// 処理概要: 型消去された payload を locale resource UI に戻して描画します。
    ///
    /// - Parameters:
    ///   - model: Text 依存性カードモデル。
    ///   - context: store action を呼び出すための描画文脈。
    /// - Returns: locale resource 依存性の custom UI。
    private static func makeView(
        model: InspectorTextDependencyCardModel,
        context: InspectorTextDependencyRenderContext
    ) -> AnyView {
        guard let payload = model.payload(as: InspectorTextLocaleDependencyModel.self) else {
            return AnyView(
                InspectorDependencyCard(model: model.card, onAction: context.handle) {
                    InspectorInfoRow(label: "provider", value: model.providerID)
                }
            )
        }
        return AnyView(
            LocaleResourceTextDependencyCard(
                card: model.card,
                model: payload,
                renderContext: context
            )
        )
    }

    /// 論理名（日本語）: Locale Resource表示判定関数
    /// 処理概要: i18n key または検出済み i18n runtime と binding source がある場合に locale resource カードを許可します。
    ///
    /// - Parameter context: Text 依存性 provider の入力文脈。
    /// - Returns: locale resource 依存性カードを表示する場合は `true`。
    private static func shouldDisplay(for context: InspectorTextDependencyContext) -> Bool {
        if let i18nKey = context.node.i18nKey, !i18nKey.isEmpty {
            return true
        }
        return context.node.textSource == "binding" && context.projectDependencies.i18nRuntime != nil
    }

    /// 論理名（日本語）: locale依存性状態判定関数
    /// 処理概要: locale resource の検出状態と編集可能性を共通 status と補足文へ変換します。
    ///
    /// - Parameter context: Text 依存性 provider の入力文脈。
    /// - Returns: 依存性 status、補足文、値編集可否。
    private static func localeOptions(
        in context: InspectorTextDependencyContext
    ) -> [InspectorTextLocaleOption] {
        guard let i18nInspection = context.projectDependencies.i18nRuntime else {
            return []
        }

        let activeLocale = context.activeResolvedText?.locale
        let locales = availableLocales(in: context, inspection: i18nInspection)
        return locales.map { locale in
            let state = localeDependencyState(in: context, locale: locale)
            return InspectorTextLocaleOption(
                locale: locale,
                valueLabel: resolvedLabel(for: locale, activeLocale: activeLocale),
                value: resolvedValue(for: locale, context: context),
                status: state.status,
                detail: state.detail,
                isValueEditable: state.isValueEditable,
                isActive: locale == activeLocale && context.activeResolvedText != nil
            )
        }
    }

    /// 論理名（日本語）: locale選択初期値取得関数
    /// 処理概要: preview 表示中 locale を優先し、候補がない場合だけ先頭 locale を返します。
    ///
    /// - Parameters:
    ///   - context: Text 依存性 provider の入力文脈。
    ///   - options: 表示可能な locale 候補。
    /// - Returns: UI 初期選択に使う locale。
    private static func initialLocale(
        in context: InspectorTextDependencyContext,
        options: [InspectorTextLocaleOption]
    ) -> String? {
        if let activeLocale = context.activeResolvedText?.locale,
           options.contains(where: { $0.locale == activeLocale }) {
            return activeLocale
        }
        return options.first?.locale ?? context.activeResolvedText?.locale
    }

    /// 論理名（日本語）: locale候補生成関数
    /// 処理概要: active locale、runtime literal、検出済み resource を重複なしで並べます。
    ///
    /// - Parameters:
    ///   - context: Text 依存性 provider の入力文脈。
    ///   - inspection: i18n runtime 検査結果。
    /// - Returns: Text card の locale picker に出す locale 一覧。
    private static func availableLocales(
        in context: InspectorTextDependencyContext,
        inspection: OpenGraphiteI18nRuntimeInspection
    ) -> [String] {
        var locales: [String] = []
        appendLocale(context.activeResolvedText?.locale, to: &locales)
        appendLocale(inspection.lng.value, to: &locales)
        appendLocale(inspection.fallbackLng.value, to: &locales)
        for resource in inspection.resources {
            appendLocale(resource.locale, to: &locales)
        }
        return locales
    }

    /// 論理名（日本語）: locale候補追加関数
    /// 処理概要: 空白を除去し、空値と重複を除いて locale を候補配列へ追加します。
    ///
    /// - Parameters:
    ///   - locale: 追加候補 locale。
    ///   - locales: 追加先 locale 配列。
    private static func appendLocale(_ locale: String?, to locales: inout [String]) {
        guard let locale = locale?.trimmingCharacters(in: .whitespacesAndNewlines),
              !locale.isEmpty,
              !locales.contains(locale)
        else {
            return
        }
        locales.append(locale)
    }

    /// 論理名（日本語）: locale値取得関数
    /// 処理概要: active locale では現在表示値を優先し、それ以外は locale JSON 値を返します。
    ///
    /// - Parameters:
    ///   - locale: 対象 locale。
    ///   - context: Text 依存性 provider の入力文脈。
    /// - Returns: Inspector に表示する text 値。
    private static func resolvedValue(
        for locale: String,
        context: InspectorTextDependencyContext
    ) -> String {
        if locale == context.activeResolvedText?.locale,
           let textContent = context.node.textContent {
            return textContent
        }
        if let resourceValue = context.projectDependencies.i18nTextResourceValues[locale] {
            return resourceValue
        }
        return context.node.fallbackTextContent ?? context.node.textContent ?? ""
    }

    /// 論理名（日本語）: locale依存性状態判定関数
    /// 処理概要: locale resource の検出状態と編集可能性を共通 status と補足文へ変換します。
    ///
    /// - Parameters:
    ///   - context: Text 依存性 provider の入力文脈。
    ///   - locale: 対象 locale。
    /// - Returns: 依存性 status、補足文、値編集可否。
    private static func localeDependencyState(
        in context: InspectorTextDependencyContext,
        locale: String?
    ) -> (status: InspectorDependencyStatus, detail: String?, isValueEditable: Bool) {
        guard let i18nKey = context.node.i18nKey, !i18nKey.isEmpty else {
            return (.notConfigured, "data-i18n-key is not set.", false)
        }

        guard let i18nInspection = context.projectDependencies.i18nRuntime else {
            return (.notConfigured, "\(i18nKey) has no detected i18n runtime.", false)
        }

        guard i18nInspection.adapter != .unknown else {
            return (.external, "\(i18nKey) is resolved by an unsupported runtime.", false)
        }

        guard let locale, !locale.isEmpty else {
            return (.missing, "\(i18nKey) has no active locale.", false)
        }

        let resource = i18nInspection.resources.first { $0.locale == locale }
        let resourceLabel = "\(i18nKey) · \(locale)"
        let isEditable = resource?.editable ?? (i18nInspection.loadPath.source != .external)
        guard isEditable else {
            if i18nInspection.loadPath.source == .external {
                return (.external, "\(resourceLabel) uses an external load path.", false)
            }
            return (.readOnly, "\(resourceLabel) is read only.", false)
        }

        if let resource, !resource.exists {
            return (.missing, "\(resourceLabel) will be created when saved.", true)
        }

        return (.editable, resourceLabel, true)
    }

    /// 論理名（日本語）: resolvedラベル生成関数
    /// 処理概要: active locale では Active Resolved、それ以外は Resolved として locale 付きラベルを返します。
    ///
    /// - Parameters:
    ///   - locale: 対象 locale。
    ///   - activeLocale: active preview で解決された locale。
    /// - Returns: Inspector 値欄のラベル。
    private static func resolvedLabel(for locale: String, activeLocale: String?) -> String {
        guard !locale.isEmpty else {
            return "Active Resolved"
        }
        if locale == activeLocale {
            return "Active Resolved (\(locale))"
        }
        return "Resolved (\(locale))"
    }
}

/// 論理名（日本語）: Locale Resource Text依存性カード
/// 概要: Text section 内で locale resource 依存性の状態と解決済み text を表示します。
///
/// プロパティ:
/// - `card`: 共通 chrome が参照する表示モデル。
/// - `model`: locale resource 依存性の表示モデル。
/// - `renderContext`: store action を呼び出すための描画文脈。
private struct LocaleResourceTextDependencyCard: View {
    var card: InspectorDependencyCardModel
    var model: InspectorTextLocaleDependencyModel
    var renderContext: InspectorTextDependencyRenderContext

    @State private var selectedLocale: String

    /// 論理名（日本語）: Locale Resource Text依存性カード初期化関数
    /// 処理概要: preview 表示中 locale を優先して locale picker の初期選択を保持します。
    ///
    /// - Parameters:
    ///   - card: 共通 chrome が参照する表示モデル。
    ///   - model: locale resource 依存性の表示モデル。
    ///   - renderContext: store action を呼び出すための描画文脈。
    init(
        card: InspectorDependencyCardModel,
        model: InspectorTextLocaleDependencyModel,
        renderContext: InspectorTextDependencyRenderContext
    ) {
        self.card = card
        self.model = model
        self.renderContext = renderContext
        _selectedLocale = State(initialValue: model.initialLocale ?? model.localeOptions.first?.locale ?? "")
    }

    var body: some View {
        InspectorDependencyCard(model: selectedCard, onAction: renderContext.handle) {
            InspectorInfoRow(label: "i18n key", value: model.i18nKey ?? "-")
            localeSelection
            content
        }
        .onChange(of: localeIDs) { _, localeIDs in
            guard !localeIDs.contains(selectedLocale) else { return }
            selectedLocale = model.initialLocale ?? localeIDs.first ?? ""
        }
        .onChange(of: model.activeLocale) { _, activeLocale in
            guard let activeLocale, localeIDs.contains(activeLocale) else { return }
            selectedLocale = activeLocale
        }
    }

    private var localeIDs: [String] {
        model.localeOptions.map(\.locale)
    }

    private var selectedOption: InspectorTextLocaleOption? {
        model.localeOptions.first { $0.locale == selectedLocale }
            ?? model.initialLocale.flatMap { initialLocale in
                model.localeOptions.first { $0.locale == initialLocale }
            }
            ?? model.localeOptions.first
    }

    private var selectedCard: InspectorDependencyCardModel {
        guard let selectedOption else {
            return card
        }
        var selectedCard = card
        selectedCard.status = selectedOption.status
        selectedCard.detail = selectedOption.detail
        selectedCard.action = localeDependencyAction(for: selectedOption.status)
        return selectedCard
    }

    @ViewBuilder
    private var localeSelection: some View {
        if model.localeOptions.isEmpty {
            InspectorInfoRow(label: "locale", value: "-")
        } else {
            HStack(spacing: 8) {
                Text("locale")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Picker("locale", selection: $selectedLocale) {
                    ForEach(model.localeOptions) { option in
                        Text(localeOptionLabel(option))
                            .tag(option.locale)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 140, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let selectedOption, selectedOption.isValueEditable {
            InspectorEditableTextValueBlock(
                label: selectedOption.valueLabel,
                value: selectedOption.value,
                onPreview: { [selectedOption, nodeID = renderContext.node.id, pageURL = renderContext.store.selectedPageURL, store = renderContext.store] value in
                    guard selectedOption.isActive else { return }
                    store.previewActiveResolvedTextContent(value, locale: selectedOption.locale, expectedNodeID: nodeID, expectedPageURL: pageURL)
                },
                onCommit: { [selectedOption, nodeID = renderContext.node.id, pageURL = renderContext.store.selectedPageURL, store = renderContext.store] value, _ in
                    store.updateActiveResolvedTextContent(
                        value,
                        locale: selectedOption.locale,
                        expectedNodeID: nodeID,
                        expectedPageURL: pageURL
                    )
                }
            )
            .id("\(renderContext.node.id)-text-locale-\(selectedOption.locale)")
        } else if let selectedOption {
            InspectorTextValueBlock(label: selectedOption.valueLabel, value: selectedOption.value)
                .id("\(renderContext.node.id)-text-locale-readonly-\(selectedOption.locale)")
        } else {
            InspectorTextValueBlock(label: "Resolved", value: renderContext.node.textContent ?? renderContext.node.fallbackTextContent ?? "")
        }
    }

    /// 論理名（日本語）: locale選択肢ラベル生成関数
    /// 処理概要: active preview locale が分かるように picker 表示名を作ります。
    ///
    /// - Parameter option: 表示する locale 選択肢。
    /// - Returns: picker 内の表示名。
    private func localeOptionLabel(_ option: InspectorTextLocaleOption) -> String {
        option.isActive ? "\(option.locale) · Preview" : option.locale
    }
}
