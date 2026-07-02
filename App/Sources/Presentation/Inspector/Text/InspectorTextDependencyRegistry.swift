import SwiftUI

/// 論理名（日本語）: インスペクタープロジェクト依存性スナップショット
/// 概要: Text 依存性 provider が参照する Project 側の検出済み依存性をまとめます。
///
/// プロパティ:
/// - `i18nRuntime`: i18n runtime と locale resource の検出結果。
/// - `i18nTextResourceValues`: 選択中 text node の i18n key に対応する locale ごとの resource 値。
struct InspectorProjectDependencySnapshot {
    var i18nRuntime: OpenGraphiteI18nRuntimeInspection?
    var i18nTextResourceValues: [String: String] = [:]
}

/// 論理名（日本語）: インスペクターText解決済み文脈
/// 概要: Preview 上で解決された text resource の locale と編集可能性を表します。
///
/// プロパティ:
/// - `locale`: 表示中 text resource の locale。
/// - `isEditable`: OpenGraphite から正本へ書き戻せるか。
struct InspectorTextActiveResolvedContext: Equatable {
    var locale: String
    var isEditable: Bool
}

/// 論理名（日本語）: インスペクターText依存性文脈
/// 概要: Text section の依存性 provider が追加カードを構成するための入力をまとめます。
///
/// プロパティ:
/// - `node`: 表示対象の text node。
/// - `activeResolvedText`: Preview 上の解決済み text 文脈。
/// - `projectDependencies`: Project 側の依存性検出結果。
struct InspectorTextDependencyContext {
    var node: OpenGraphiteNode
    var activeResolvedText: InspectorTextActiveResolvedContext?
    var projectDependencies: InspectorProjectDependencySnapshot
}

/// 論理名（日本語）: インスペクターText依存性描画文脈
/// 概要: Text 依存性 provider の custom UI が store action を呼び出すための文脈です。
///
/// プロパティ:
/// - `node`: 表示対象の text node。
/// - `store`: Preview 反映や保存を担当する editor store。
struct InspectorTextDependencyRenderContext {
    var node: OpenGraphiteNode
    var store: EditorStore

    /// 論理名（日本語）: 依存性カードアクション処理関数
    /// 処理概要: card model が持つ遷移先を Project resource selection へ反映します。
    ///
    /// - Parameter action: 依存性カードから送られた action。
    @MainActor
    func handle(_ action: InspectorDependencyCardAction) {
        guard let projectResource = action.projectResource else { return }
        store.selectProjectResource(projectResource)
    }
}

/// 論理名（日本語）: インスペクターText依存性カードモデル
/// 概要: provider ID、共通 card model、provider 固有 payload を保持する type-erased モデルです。
///
/// プロパティ:
/// - `id`: SwiftUI のカード識別子。
/// - `providerID`: custom UI を描画する provider の識別子。
/// - `card`: 共通 chrome が参照する表示モデル。
struct InspectorTextDependencyCardModel: Identifiable {
    var id: String { card.id }
    var providerID: String
    var card: InspectorDependencyCardModel

    private var payloadStorage: Any

    /// 論理名（日本語）: Text依存性カードモデル初期化関数
    /// 処理概要: provider 固有 payload を型消去して保持します。
    ///
    /// - Parameters:
    ///   - providerID: custom UI を描画する provider の識別子。
    ///   - card: 共通 chrome が参照する表示モデル。
    ///   - payload: provider 固有の表示・編集モデル。
    init<Payload>(
        providerID: String,
        card: InspectorDependencyCardModel,
        payload: Payload
    ) {
        self.providerID = providerID
        self.card = card
        self.payloadStorage = payload
    }

    /// 論理名（日本語）: Text依存性payload取得関数
    /// 処理概要: provider 固有 payload を期待型で取り出します。
    ///
    /// - Parameter type: 期待する payload 型。
    /// - Returns: 型が一致する場合は payload、それ以外は `nil`。
    func payload<Payload>(as type: Payload.Type = Payload.self) -> Payload? {
        payloadStorage as? Payload
    }
}

/// 論理名（日本語）: インスペクターText依存性provider
/// 概要: Text node と Project 依存性から、条件付き card model と custom UI を提供します。
///
/// プロパティ:
/// - `id`: provider 識別子。
/// - `makeModel`: Text 文脈から表示対象 card model を作る処理。
/// - `makeView`: card model と描画文脈から custom UI を作る処理。
struct InspectorTextDependencyProvider {
    var id: String
    var makeModel: (InspectorTextDependencyContext) -> InspectorTextDependencyCardModel?
    var makeView: (InspectorTextDependencyCardModel, InspectorTextDependencyRenderContext) -> AnyView
}

/// 論理名（日本語）: インスペクターText依存性registry
/// 概要: Text section へ追加する依存性 provider の登録点です。
///
/// プロパティ:
/// - `providers`: 依存性ごとの provider 一覧。
struct InspectorTextDependencyRegistry {
    var providers: [InspectorTextDependencyProvider]

    /// 論理名（日本語）: 標準Text依存性registry
    /// 処理概要: OpenGraphite が標準で提供する Text 依存性 provider を返します。
    static var standard: InspectorTextDependencyRegistry {
        InspectorTextDependencyRegistry(
            providers: [
                LocaleResourceTextDependency.provider
            ]
        )
    }

    /// 論理名（日本語）: Text依存性モデル生成関数
    /// 処理概要: 登録済み provider から表示対象の依存性カードだけを集めます。
    ///
    /// - Parameter context: Text 依存性 provider の入力文脈。
    /// - Returns: Text section に表示する依存性カード一覧。
    func models(for context: InspectorTextDependencyContext) -> [InspectorTextDependencyCardModel] {
        providers.compactMap { provider in
            provider.makeModel(context)
        }
    }

    /// 論理名（日本語）: Text依存性view生成関数
    /// 処理概要: card model の provider ID に対応する custom UI を生成します。
    ///
    /// - Parameters:
    ///   - model: 表示対象の依存性カードモデル。
    ///   - context: store action を呼び出すための描画文脈。
    /// - Returns: provider 固有 UI。provider が見つからない場合は fallback UI。
    func view(
        for model: InspectorTextDependencyCardModel,
        context: InspectorTextDependencyRenderContext
    ) -> AnyView {
        guard let provider = providers.first(where: { $0.id == model.providerID }) else {
            return AnyView(
                InspectorDependencyCard(model: model.card, onAction: context.handle) {
                    InspectorInfoRow(label: "provider", value: model.providerID)
                }
            )
        }
        return provider.makeView(model, context)
    }
}
