import CryptoKit
import Foundation

/// 論理名（日本語）: Agent向けノード
/// 概要: CLI / MCP が返す OpenGraphite HTML ノードの JSON 表現です。
///
/// プロパティ:
/// - `id`: optional な `data-og-id`。未注釈要素では空文字。
/// - `internalID`: `data-og-internal-id`。
/// - `reference`: stable `ogref` または source revision に限定された session reference。
/// - `annotationStatus`: optional identity annotation の充足状態。
/// - `referenceStability`: reference が永続 identity か source revision 限定か。
/// - `locator`: annotation に依存せず要素を再検出する source locator。
/// - `tagName`: 小文字化した HTML タグ名。
/// - `legacyTypeHint`: migration入力として保持するoptionalなlegacy `data-og-type`。
/// - `capabilities`: DOM semanticsとoperation要件から導出した編集能力。
/// - `capabilityEvidence`: capability判定を説明する標準DOM/CSS evidence。
/// - `layout`: 標準`display` / `flex-direction`とHTML UA既定から導出したlayout表示値。
/// - `role`: authored standard `role` 属性。
/// - `cssVariables`: companion CSS または legacy inline style 内の編集対象 CSS declaration。
/// - `cssSourceTrace`: property ごとの authored selector / scope / specificity / source order provenance。
/// - `cssResolvedValues`: source cascade、inheritance、custom property、shorthand解決後のheadless値。
/// - `hasIncompleteCSSProvenance`: unreadable/import/layer/malformed sourceによりwinnerを完全確定できない場合は`true`。
/// - `renderingTargets`: wrapper 選択時に標準 CSS を評価・編集する実描画要素との DOM 関係。
/// - `hidden`: sourceに標準`hidden`属性が存在する状態。CSS表示状態は`cssSourceTrace` / `cssResolvedValues`で分離します。
/// - `locked`: `data-og-locked` 状態。
/// - `depth`: DOM 階層深度。
/// - `parentID`: 最も近い OpenGraphite 親ノードの `data-og-id`。
/// - `parentReference`: 直近 DOM 親要素の stable / session reference。
/// - `textContent`: ノード配下のプレーンテキスト。
/// - `attributes`: 開始タグの属性辞書。
struct OpenGraphiteAgentNode: Codable, Equatable {
    var id: String
    var internalID: String
    var reference: String
    var annotationStatus: OpenGraphiteNodeAnnotationStatus
    var referenceStability: OpenGraphiteNodeReferenceStability
    var locator: OpenGraphiteNodeLocator
    var tagName: String
    var legacyTypeHint: String?
    var capabilities: [OpenGraphiteNodeCapability]
    var capabilityEvidence: OpenGraphiteNodeCapabilityEvidence
    var layout: String?
    var role: String?
    var cssVariables: [String: String]
    var cssSourceTrace: [String: [OpenGraphiteAgentCSSDeclarationTrace]]
    var cssResolvedValues: [String: String]
    var hasIncompleteCSSProvenance: Bool
    var renderingTargets: [OpenGraphiteAgentRenderingTarget]
    var hidden: Bool
    var locked: Bool
    var depth: Int
    var parentID: String?
    var parentReference: String?
    var textContent: String?
    var attributes: [String: String]
}

/// 論理名（日本語）: ノード操作能力
/// 概要: 単一type分類ではなく、標準DOM semanticsとcomputed CSSから独立に導出する編集operationを表します。
enum OpenGraphiteNodeCapability: String, Codable, Equatable, Hashable, CaseIterable {
    case receiveChildren = "receive-children"
    case editText = "edit-text"
    case editLink = "edit-link"
    case editMedia = "edit-media"
    case editIcon = "edit-icon"
    case editControl = "edit-control"
    case editLayout = "edit-layout"
    case dragPosition = "drag-position"
    case reorderFlow = "reorder-flow"
    case group
    case ungroup
}

/// 論理名（日本語）: ノード操作能力根拠
/// 概要: capability setの説明に使う標準HTML、ARIA、DOM実体、computed CSS、project登録rootの根拠を保持します。
///
/// プロパティ:
/// - `isProjectResourceRoot`: project登録resourceの論理rootとして一意に確定した要素か。
/// - `isNativeControl`: 標準HTMLのnative control要素か。
/// - `isCustomElement`: tag nameがcustom element名か。
/// - `isLink`: 標準linkまたはARIA link semanticsを持つか。
/// - `hasDirectText`: descendant要素の外側に直接text nodeを持つか。
/// - `hasElementChildren`: authored DOMの直接子要素を持つか。
/// - `hasMediaContent`: 自身またはsubtreeに標準media実体を持つか。
/// - `hasSVGContent`: 自身またはsubtreeにSVG実体を持つか。
/// - `hasMaskContent`: 自身またはsubtreeにCSS mask実体を持つか。
/// - `ariaRole`: authored標準`role`属性。OpenGraphite固有`data-og-role`とは分離します。
/// - `resolvedDisplay`: source cascadeとUA fallbackから解決した標準`display`値。
struct OpenGraphiteNodeCapabilityEvidence: Codable, Equatable, Hashable {
    var isProjectResourceRoot: Bool
    var isNativeControl: Bool
    var isCustomElement: Bool
    var isLink: Bool
    var hasDirectText: Bool
    var hasElementChildren: Bool
    var hasMediaContent: Bool
    var hasSVGContent: Bool
    var hasMaskContent: Bool
    var ariaRole: String?
    var resolvedDisplay: String?
}

extension OpenGraphiteAgentNode {
    /// 論理名（日本語）: ノード操作能力判定関数
    /// 処理概要: inspectionで導出済みのcapability setだけをmutation authorizationの根拠として評価します。
    ///
    /// - Parameter capability: 実行前に要求するoperation能力。
    /// - Returns: capability setに含まれる場合は`true`。
    func supports(_ capability: OpenGraphiteNodeCapability) -> Bool {
        capabilities.contains(capability)
    }
}

/// 論理名（日本語）: Node annotation状態
/// 概要: 標準HTML要素にoptionalなOpenGraphite identity annotationがどこまで存在するかを表します。
enum OpenGraphiteNodeAnnotationStatus: String, Codable, Equatable, Hashable, CaseIterable {
    /// OpenGraphite identity annotationを持たない標準HTML要素です。
    case none
    /// `data-og-id`または`data-og-internal-id`の片方だけを持つ要素です。
    case partial
    /// `data-og-id`と`data-og-internal-id`の両方を持つ要素です。
    case complete
}

/// 論理名（日本語）: Node参照安定性
/// 概要: Agent node referenceが永続annotationに基づくかsource revision限定かを表します。
enum OpenGraphiteNodeReferenceStability: String, Codable, Equatable, Hashable, CaseIterable {
    /// source rangeとcontent hashが一致する間だけ再解決できる参照です。
    case session
    /// 一意な`data-og-internal-id`に基づく永続参照です。
    case stable
}

/// 論理名（日本語）: HTML source範囲
/// 概要: UTF-8ではなくSwift `String` character offsetで開始・終了位置を保持します。
struct OpenGraphiteSourceRange: Codable, Equatable {
    var start: Int
    var end: Int
}

/// 論理名（日本語）: Node source locator
/// 概要: optional annotationを持たない標準HTML要素をsource revision内で再検出する根拠を保持します。
///
/// プロパティ:
/// - `documentURL`: 対象HTMLの標準化済みfile URL。
/// - `selector`: 一意な標準`id`、authored class/custom-element、既存annotationの順で選ぶ安全なselector。
/// - `domPath`: tagと`:nth-of-type()`で構成した決定的DOM path。
/// - `sourceRange`: source上の要素全体、または閉じtag不明時の開始tag範囲。
/// - `contentHash`: sourceRange内HTMLの安定hash。
struct OpenGraphiteNodeLocator: Codable, Equatable {
    var documentURL: String
    var selector: String?
    var domPath: String
    var sourceRange: OpenGraphiteSourceRange
    var contentHash: String
}

/// 論理名（日本語）: Agent向け実描画target
/// 概要: 選択 wrapper と media / SVG / mask の実描画要素を結び、標準 CSS の source provenance を公開します。
///
/// プロパティ:
/// - `kind`: `media`、`svg`、`mask` の描画分類。
/// - `tagName`: 実描画要素の小文字 tag name。
/// - `relation`: wrapper から見た `self`、`direct-child`、`descendant` の関係。
/// - `relationSelector`: `:scope` を起点にした wrapper 相対 selector。
/// - `writeSelector`: 新規 declaration の保存先として使う安全な selector。
/// - `targetInternalID`: 実描画要素に既存 annotation がある場合だけ返す internal ID。
/// - `authoredValues`: source または inline style に記載された対象標準 CSS 値。
/// - `resolvedValues`: cascade、inheritance、custom property 解決後の headless 値。
/// - `sourceTrace`: property ごとの selector / scope / specificity / source order provenance。
struct OpenGraphiteAgentRenderingTarget: Codable, Equatable {
    var kind: String
    var tagName: String
    var relation: String
    var relationSelector: String
    var writeSelector: String
    var targetInternalID: String?
    var authoredValues: [String: String]
    var resolvedValues: [String: String]
    var sourceTrace: [String: [OpenGraphiteAgentCSSDeclarationTrace]]
}

/// 論理名（日本語）: Agent向けCSS宣言trace
/// 概要: CSS source AST上のdeclaration provenanceをCLI / MCP JSONへ公開します。
///
/// プロパティ:
/// - `property`: shorthand展開後の対象property。
/// - `authoredProperty`: sourceに記載されたproperty。
/// - `selector`: 一致したauthored selector。
/// - `specificity`: selector詳細度。
/// - `atRules`: 外側から内側のat-rule scope。
/// - `value`: authored declaration value。
/// - `important`: `!important`の有無。
/// - `sourceID`: declarationを保持する独立stylesheetまたはHTML source ID。
/// - `sourceKind`: project / companion / linked / embedded / inlineのorigin種別。
/// - `sourceEditable`: 共通mutationが元sourceを安全に更新できる場合は`true`。
/// - `stylesheetOrder`: browser document内のstylesheet順。
/// - `sourceOrder`: declarationのsource順。
/// - `inherited`: 実描画target自身ではなく祖先sourceから継承したcandidateの場合は`true`。
struct OpenGraphiteAgentCSSDeclarationTrace: Codable, Equatable {
    var property: String
    var authoredProperty: String
    var selector: String
    var specificity: OpenGraphiteCSSSpecificity
    var atRules: [OpenGraphiteCSSAtRuleContext]
    var value: String
    var important: Bool
    var sourceID: String
    var sourceKind: String
    var sourceEditable: Bool
    var stylesheetOrder: Int
    var sourceOrder: Int
    var inherited: Bool
}

/// 論理名（日本語）: Agent診断
/// 概要: CLI / MCP / validation が返す問題、警告、情報メッセージを表します。
///
/// プロパティ:
/// - `severity`: error、warning、info。
/// - `code`: 機械判定用コード。
/// - `message`: 人間向け説明。
/// - `path`: 対象ファイルパス。
/// - `nodeID`: 関連する `data-og-id`。
struct OpenGraphiteDiagnostic: Codable, Equatable {
    var severity: OpenGraphiteDiagnosticSeverity
    var code: String
    var message: String
    var path: String?
    var nodeID: String?
}

/// 論理名（日本語）: Agent診断重要度
/// 概要: validation 結果の重要度を表します。
///
/// 定義内容:
/// - `error`: write を止める問題。
/// - `warning`: write は止めないが注意が必要な問題。
/// - `info`: 補助情報。
enum OpenGraphiteDiagnosticSeverity: String, Codable, Equatable {
    case error
    case warning
    case info
}

/// 論理名（日本語）: ページグラフ応答
/// 概要: HTML ページから抽出した node graph と diagnostics を保持します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `activeMediaQueries`: headless cascadeでactiveとみなした標準`@media`条件。
/// - `hasIncompleteCSSProvenance`: stylesheet sourceを完全に解決できなかった場合は`true`。
/// - `nodes`: 抽出された node 一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageGraph: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var activeMediaQueries: [String]
    var hasIncompleteCSSProvenance: Bool
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索応答
/// 概要: 条件に一致した OpenGraphite node 一覧を返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `query`: 適用した検索条件。
/// - `nodes`: 条件に一致した node。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteNodeQueryResult: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var query: OpenGraphiteNodeQuery
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索条件
/// 概要: CLI / MCP がoptional identity、legacy type hint、operation capability、role、tag、textでnodeを絞り込みます。
///
/// プロパティ:
/// - `idContains`: `data-og-id` に含まれる文字列。
/// - `type`: legacy `data-og-type` hintの完全一致。capability判定には使いません。
/// - `capabilities`: nodeがすべて満たす必要があるoperation capability。
/// - `role`: authored standard `role` 属性の完全一致。
/// - `tag`: tag name の完全一致。
/// - `textContains`: textContent に含まれる文字列。
struct OpenGraphiteNodeQuery: Codable, Equatable {
    var idContains: String?
    var type: String?
    var capabilities: [OpenGraphiteNodeCapability]
    var role: String?
    var tag: String?
    var textContains: String?

    /// 論理名（日本語）: ノード検索条件初期化関数
    /// 処理概要: legacy type hintを独立条件として残し、複数capabilityをAND条件で保持します。
    ///
    /// - Parameters:
    ///   - idContains: optional identity、標準ID、referenceに含む文字列。
    ///   - type: legacy `data-og-type` hintの完全一致値。
    ///   - capabilities: nodeがすべて満たす必要があるoperation capability。
    ///   - role: authored standard `role`属性の完全一致値。
    ///   - tag: 標準化済みtag nameの完全一致値。
    ///   - textContains: text contentに含む文字列。
    init(
        idContains: String?,
        type: String?,
        capabilities: [OpenGraphiteNodeCapability] = [],
        role: String?,
        tag: String?,
        textContains: String?
    ) {
        self.idContains = idContains
        self.type = type
        self.capabilities = capabilities.sorted { $0.rawValue < $1.rawValue }
        self.role = role
        self.tag = tag
        self.textContains = textContains
    }

    private enum CodingKeys: String, CodingKey {
        case idContains
        case type
        case capabilities
        case role
        case tag
        case textContains
    }

    /// 論理名（日本語）: ノード検索条件デコード関数
    /// 処理概要: capability未指定の旧query JSONを空条件として互換読込します。
    ///
    /// - Parameter decoder: query JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idContains = try container.decodeIfPresent(String.self, forKey: .idContains)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        capabilities = try container.decodeIfPresent([OpenGraphiteNodeCapability].self, forKey: .capabilities)?
            .sorted { $0.rawValue < $1.rawValue } ?? []
        role = try container.decodeIfPresent(String.self, forKey: .role)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        textContains = try container.decodeIfPresent(String.self, forKey: .textContains)
    }
}

/// 論理名（日本語）: 検証応答
/// 概要: HTML または project の validation 結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `valid`: error がない場合は `true`。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteValidationResult: Codable, Equatable {
    var schemaVersion: String
    var valid: Bool
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Node adoption範囲
/// 概要: 明示adoptで対象要素だけ、またはそのsubtree全体へoptional identityを追加するかを表します。
enum OpenGraphiteNodeAdoptionScope: String, Codable, Equatable {
    case node
    case subtree
}

/// 論理名（日本語）: Source差分
/// 概要: 明示migration/adoptionの変更前後hashとhuman-readable unified diffを保持します。
struct OpenGraphiteSourceDiff: Codable, Equatable {
    var path: String
    var beforeHash: String
    var afterHash: String
    var unifiedDiff: String
}

/// 論理名（日本語）: Project Web契約移行option
/// 概要: 明示migration proposalへ束縛するlegacy catalogと未知metadata保持方針を表します。
///
/// プロパティ:
/// - `legacyCatalogVersion`: 適用する既知legacy mapping catalogのversion。
/// - `preserveUnknownDataAttributes`: OpenGraphiteがownershipを持たない未知`data-*`を保持する場合は`true`。
struct OpenGraphiteProjectMigrationOptions: Codable, Equatable {
    var legacyCatalogVersion: String
    var preserveUnknownDataAttributes: Bool

    static let standard = OpenGraphiteProjectMigrationOptions(
        legacyCatalogVersion: "1",
        preserveUnknownDataAttributes: true
    )
}

/// 論理名（日本語）: Project Web契約移行応答
/// 概要: project登録sourceのdry-runまたはatomic apply結果を複数file diffとdiagnostics付きで返します。
///
/// プロパティ:
/// - `schemaVersion`: Agent JSON schema version。
/// - `sourceContractVersion`: legacy token検出から判定した入力Web contract version。
/// - `targetContractVersion`: 明示migrationの出力Web contract version。
/// - `dryRun`: sourceへ書き込まないpreviewの場合は`true`。
/// - `applied`: 全candidateをatomic staged applyできた場合だけ`true`。
/// - `changed`: 1件以上のcandidate diffがある場合は`true`。
/// - `proposalReference`: target/options/project hash/全source hashを束縛したapply専用token。
/// - `diffs`: root相対path昇順のsource diff。
/// - `diagnostics`: unsupported legacy、stale proposal、write/rollback失敗の診断。
struct OpenGraphiteProjectMigrationResult: Codable, Equatable {
    var schemaVersion: String
    var sourceContractVersion: String
    var targetContractVersion: String
    var dryRun: Bool
    var applied: Bool
    var changed: Bool
    var proposalReference: String?
    var diffs: [OpenGraphiteSourceDiff]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Node adoption応答
/// 概要: optional identityのdry-runまたは明示適用結果をgraphとsource diff付きで返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema version。
/// - `applied`: sourceへ書き込んだ場合だけ`true`。
/// - `changed`: candidate sourceが変更前と異なる場合は`true`。
/// - `dryRun`: sourceへ書き込まないpreviewなら`true`。
/// - `path`: 対象HTML path。
/// - `scope`: nodeまたはsubtree。
/// - `targetReference`: dry-run時点のdocument/sourceと正規化済みscope/display IDを固定したapply専用proposal snapshot reference。
/// - `adoptedReferences`: candidate graph上でstableになった対象reference。
/// - `diff`: 変更がある場合のsource diff。
/// - `graph`: candidate sourceをinspectionしたgraph。
/// - `diagnostics`: stale locator、重複ID、参照破損などの診断。
struct OpenGraphiteNodeAdoptionResult: Codable, Equatable {
    var schemaVersion: String
    var applied: Bool
    var changed: Bool
    var dryRun: Bool
    var path: String
    var scope: OpenGraphiteNodeAdoptionScope
    var targetReference: String
    var adoptedReferences: [String]
    var diff: OpenGraphiteSourceDiff?
    var graph: OpenGraphitePageGraph
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: デザイントークン
/// 概要: Project CSS の `:root` に保存された CSS custom property を Inspector / CLI / MCP 向けに表します。
///
/// プロパティ:
/// - `name`: CSS custom property 名。
/// - `value`: CSS 値。
/// - `category`: token 名から推定した分類。
/// - `reference`: CSS declaration から参照する `var(...)` 形式の文字列。
struct OpenGraphiteDesignToken: Codable, Equatable, Identifiable {
    var name: String
    var value: String
    var category: String
    var reference: String

    var id: String { name }
}

/// 論理名（日本語）: デザイントークン一覧応答
/// 概要: Project CSS から抽出した design token 一覧と診断を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `path`: 対象 CSS file path。
/// - `tokens`: 抽出された design token。
/// - `diagnostics`: 検出時の診断。
struct OpenGraphiteDesignTokenListResult: Codable, Equatable {
    var schemaVersion: String
    var path: String
    var tokens: [OpenGraphiteDesignToken]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: デザイントークン編集応答
/// 概要: Project CSS の design token 更新結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: CSS file を書き換えた場合は `true`。
/// - `path`: 対象 CSS file path。
/// - `token`: 更新後 token。削除時は `nil`。
/// - `tokens`: 更新後の token 一覧。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteDesignTokenEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var token: OpenGraphiteDesignToken?
    var tokens: [OpenGraphiteDesignToken]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Locale typography 一覧応答
/// 概要: page / component companion CSS の root `font-family` と locale override を source provenance 付きで返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `path`: 対象 companion CSS path。
/// - `segment`: Pages / Components の区分。
/// - `resourceID`: 対象 page / component の内部 ID。
/// - `rootSelector`: default と locale override が共有する root selector。
/// - `declarations`: authored locale typography 宣言。
/// - `diagnostics`: inspection 時の診断。
struct OpenGraphiteLocaleTypographyListResult: Codable, Equatable {
    var schemaVersion: String
    var path: String
    var segment: String
    var resourceID: String
    var rootSelector: String
    var declarations: [OpenGraphiteLocaleTypographyDeclaration]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Locale typography 編集応答
/// 概要: root または `:lang()` の標準 `font-family` 更新結果と更新後一覧を返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: companion CSS を書き換えた場合は `true`。
/// - `path`: 対象 companion CSS path。
/// - `segment`: Pages / Components の区分。
/// - `resourceID`: 対象 page / component の内部 ID。
/// - `locale`: `default` または正規化済み BCP 47 tag。
/// - `selector`: 更新対象の authored selector。
/// - `property`: 常に標準 CSS property の `font-family`。
/// - `value`: 設定値。削除時は空文字。
/// - `declarations`: 更新後の locale typography 宣言。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteLocaleTypographyEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var segment: String
    var resourceID: String
    var locale: String
    var selector: String
    var property: String
    var value: String
    var declarations: [OpenGraphiteLocaleTypographyDeclaration]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ページ作成応答
/// 概要: HTML page file 作成結果と作成後 graph を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: ファイルを書き込んだ場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `graph`: 作成後 page graph。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageWriteResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var path: String
    var graph: OpenGraphitePageGraph?
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクト要約応答
/// 概要: `.ogp` と解決済み HTML / CSS 参照を CLI / MCP 向けに表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `projectName`: プロジェクト名。
/// - `projectURL`: `.ogp` の URL。
/// - `rootURL`: 解決済みリポジトリルート。
/// - `htmlRoot`: HTML root。
/// - `cssURL`: CSS library URL。
/// - `chapters`: Chapter 要約一覧。
/// - `collections`: Collection 要約一覧。
/// - `pages`: 全 Chapter のページ要約一覧。
/// - `components`: 全 Collection の component canvas 要約一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectSummary: Codable, Equatable {
    var schemaVersion: String
    var projectName: String
    var projectURL: String
    var rootURL: String
    var htmlRoot: String
    var cssURL: String
    var chapters: [OpenGraphiteChapterSummary]
    var collections: [OpenGraphiteComponentCollectionSummary]
    var pages: [OpenGraphitePageSummary]
    var components: [OpenGraphitePageSummary]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Chapter要約
/// 概要: `.ogp` 内の Chapter と、その Chapter に属する page summary を JSON 出力向けに表します。
///
/// プロパティ:
/// - `id`: Chapter ID。
/// - `internalID`: `.ogp` 内で一意な Chapter 内部 ID。
/// - `index`: `.ogp` 内の Chapter index。
/// - `title`: Chapter 表示名。
/// - `isSidebarHidden`: Editor の Chapter 一覧から非表示か。
/// - `annotationCount`: Chapter キャンバスに保存された注釈数。
/// - `guideCount`: Chapter キャンバスに保存されたガイド数。
/// - `referenceCount`: Chapter キャンバス直下に保存されたオブジェクト参照数。
/// - `pages`: Chapter 内のページ要約一覧。
struct OpenGraphiteChapterSummary: Codable, Equatable {
    var id: String
    var internalID: String
    var index: Int
    var title: String?
    var isSidebarHidden: Bool
    var annotationCount: Int
    var guideCount: Int
    var referenceCount: Int
    var pages: [OpenGraphitePageSummary]
}

/// 論理名（日本語）: Component Collection要約
/// 概要: `.ogp` 内の Collection と、その Collection に属する component summary を JSON 出力向けに表します。
///
/// プロパティ:
/// - `id`: Collection ID。
/// - `internalID`: `.ogp` 内で一意な Collection 内部 ID。
/// - `index`: `.ogp` 内の Collection index。
/// - `title`: Collection 表示名。
/// - `annotationCount`: Collection キャンバスに保存された注釈数。
/// - `guideCount`: Collection キャンバスに保存されたガイド数。
/// - `referenceCount`: Collection キャンバス直下に保存されたオブジェクト参照数。
/// - `components`: Collection 内の component canvas 要約一覧。
struct OpenGraphiteComponentCollectionSummary: Codable, Equatable {
    var id: String
    var internalID: String
    var index: Int
    var title: String?
    var annotationCount: Int
    var guideCount: Int
    var referenceCount: Int
    var components: [OpenGraphitePageSummary]
}

/// 論理名（日本語）: キャンバス注釈要約
/// 概要: `.ogp` 注釈を、手書き点列を展開しない一覧表示向け JSON として表します。
///
/// プロパティ:
/// - `internalID`: `.ogp` 内で注釈を一意に指す内部 ID。
/// - `referenceID`: segment、Chapter / Collection、注釈を含む typed 参照 ID。
/// - `kind`: 付箋または手書きの種別。
/// - `frame`: キャンバス world 座標上の配置矩形。
/// - `text`: 付箋のプレーンテキスト。手書きでは `nil`。
/// - `backgroundColor`: 付箋背景色。手書きでは `nil`。
/// - `textColor`: 付箋文字色。手書きでは `nil`。
/// - `strokeCount`: 手書きストローク数。
/// - `pointCount`: 全手書きストロークの点数。
struct OpenGraphiteCanvasAnnotationSummary: Codable, Equatable {
    var internalID: String
    var referenceID: String
    var kind: OpenGraphiteCanvasAnnotationKind
    var frame: OpenGraphiteCanvasAnnotationFrame
    var text: String?
    var backgroundColor: String?
    var textColor: String?
    var strokeCount: Int
    var pointCount: Int
}

/// 論理名（日本語）: キャンバス注釈詳細
/// 概要: typed 参照 ID と、点列を含む `.ogp` 注釈 payload をまとめます。
///
/// プロパティ:
/// - `referenceID`: segment、Chapter / Collection、注釈を含む typed 参照 ID。
/// - `annotation`: `.ogp` に保存された注釈本体。
struct OpenGraphiteCanvasAnnotationDetail: Codable, Equatable {
    var referenceID: String
    var annotation: OpenGraphiteCanvasAnnotation
}

/// 論理名（日本語）: キャンバス注釈一覧応答
/// 概要: Chapter または Collection キャンバスに保存された注釈要約を CLI / MCP 向けに返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `projectURL`: 読み込んだ `.ogp` URL。
/// - `segment`: `pages` または `components`。
/// - `containerID`: Chapter または Collection の表示 ID。
/// - `containerInternalID`: Chapter または Collection の内部 ID。
/// - `containerReferenceID`: 対象 Chapter または Collection の typed 参照 ID。
/// - `annotations`: 点列を展開しない注釈要約一覧。
/// - `diagnostics`: 読み取り時の診断。
struct OpenGraphiteCanvasAnnotationListResult: Codable, Equatable {
    var schemaVersion: String
    var projectURL: String
    var segment: String
    var containerID: String
    var containerInternalID: String
    var containerReferenceID: String
    var annotations: [OpenGraphiteCanvasAnnotationSummary]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: キャンバス注釈取得応答
/// 概要: Chapter または Collection キャンバスの単一注釈を、手書き点列を含む完全な JSON として返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `projectURL`: 読み込んだ `.ogp` URL。
/// - `segment`: `pages` または `components`。
/// - `containerID`: Chapter または Collection の表示 ID。
/// - `containerInternalID`: Chapter または Collection の内部 ID。
/// - `containerReferenceID`: 対象 Chapter または Collection の typed 参照 ID。
/// - `annotation`: typed 参照 ID と完全な注釈 payload。
/// - `diagnostics`: 読み取り時の診断。
struct OpenGraphiteCanvasAnnotationGetResult: Codable, Equatable {
    var schemaVersion: String
    var projectURL: String
    var segment: String
    var containerID: String
    var containerInternalID: String
    var containerReferenceID: String
    var annotation: OpenGraphiteCanvasAnnotationDetail
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ページ要約
/// 概要: `.ogp` 内のページと解決済み HTML URL を JSON 出力向けに表します。
///
/// プロパティ:
/// - `chapterID`: 所属 Chapter ID。Components では `nil`。
/// - `chapterInternalID`: 所属 Chapter 内部 ID。Components では `nil`。
/// - `collectionID`: 所属 Collection ID。Pages セグメントでは `nil`。
/// - `collectionInternalID`: 所属 Collection 内部 ID。Pages セグメントでは `nil`。
/// - `segment`: `pages` または `components`。
/// - `id`: ページ ID。
/// - `internalID`: `.ogp` 内で一意な HTML カード内部 ID。
/// - `referenceID`: `segment` と内部 ID を組み合わせた agent 向け page 参照 ID。
/// - `chapterIndex`: Pages セグメント内の Chapter index。
/// - `collectionIndex`: Components 内の Collection index。
/// - `pageIndex`: Chapter または Collection 配列内の page index。
/// - `path`: `htmlRoot` からの相対パス。
/// - `htmlURL`: 解決済み HTML URL。
/// - `isCanvasHidden`: Chapter キャンバスから非表示か。Components では常に `false`。
/// - `canvas`: キャンバス定義。
struct OpenGraphitePageSummary: Codable, Equatable {
    var chapterID: String?
    var chapterInternalID: String?
    var collectionID: String?
    var collectionInternalID: String?
    var segment: String
    var id: String
    var internalID: String
    var referenceID: String
    var chapterIndex: Int?
    var collectionIndex: Int?
    var pageIndex: Int
    var path: String
    var htmlURL: String
    var isCanvasHidden: Bool
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ参照
/// 概要: `.ogp` の page / component canvas から解決された編集対象 HTML と読み取り許可範囲を表します。
///
/// プロパティ:
/// - `projectURL`: 参照元 `.ogp` の URL。
/// - `segment`: 対象が Pages / Components のどちらに属するか。
/// - `chapterID`: `.ogp` 内の Chapter ID。Components では `nil`。
/// - `chapterInternalID`: `.ogp` 内で一意な Chapter 内部 ID。Components では `nil`。
/// - `collectionID`: `.ogp` 内の Collection ID。Pages セグメントでは `nil`。
/// - `collectionInternalID`: `.ogp` 内で一意な Collection 内部 ID。Pages セグメントでは `nil`。
/// - `pageID`: ``.ogp` 内の page 参照 ID。
/// - `pageInternalID`: `.ogp` 内で一意な HTML カード内部 ID。
/// - `referenceID`: agent 向け page 参照 ID。
/// - `path`: `htmlRoot` から見た HTML path。
/// - `htmlURL`: 解決済み HTML URL。
/// - `rootURL`: HTML / CSS / assets の読み取り許可ルート。
/// - `canvas`: `.ogp` 上の canvas 配置。
struct OpenGraphiteProjectPageReference: Codable, Equatable {
    var projectURL: String
    var segment: String
    var chapterID: String?
    var chapterInternalID: String?
    var collectionID: String?
    var collectionInternalID: String?
    var pageID: String
    var pageInternalID: String
    var referenceID: String
    var path: String
    var htmlURL: String
    var rootURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ作成応答
/// 概要: `.ogp` を経由した HTML 作成と page entry 登録の結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: HTML と `.ogp` の両方が更新された場合は `true`。
/// - `project`: 更新後 project summary。
/// - `page`: 追加された page summary。
/// - `htmlPath`: 作成対象 HTML パス。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectPageCreateResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var project: OpenGraphiteProjectSummary?
    var page: OpenGraphitePageSummary?
    var htmlPath: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクトページ内部ターゲット
/// 概要: core 内部で `.ogp` page と解決済み HTML URL をまとめて渡すための値です。
///
/// プロパティ:
/// - `loadedProject`: 読み込み済み `.ogp`。
/// - `segment`: 対象が Pages / Components のどちらに属するか。
/// - `chapter`: 対象 page entry を含む Chapter。Components では `nil`。
/// - `collection`: 対象 component entry を含む Collection。Pages セグメントでは `nil`。
/// - `page`: 対象 page entry。
/// - `htmlURL`: 解決済み HTML URL。
private struct OpenGraphiteProjectPageTarget {
    var loadedProject: LoadedOpenGraphiteProject
    var segment: String
    var chapter: OpenGraphiteChapter?
    var collection: OpenGraphiteComponentCollection?
    var page: OpenGraphitePage
    var htmlURL: URL
}

/// 論理名（日本語）: キャンバス注釈コンテナ内部ターゲット
/// 概要: 注釈を保持する Chapter / Collection と agent 向け参照情報を core 内部でまとめます。
///
/// プロパティ:
/// - `segment`: Pages / Components の区分。
/// - `id`: Chapter または Collection の表示 ID。
/// - `internalID`: Chapter または Collection の内部 ID。
/// - `referenceID`: Chapter または Collection の typed 参照 ID。
/// - `annotations`: 対象キャンバスに保存された注釈一覧。
private struct OpenGraphiteCanvasAnnotationContainerTarget {
    var segment: OpenGraphiteCanvasSegment
    var id: String
    var internalID: String
    var referenceID: String
    var annotations: [OpenGraphiteCanvasAnnotation]
}

/// 論理名（日本語）: プロジェクトページ位置
/// 概要: `.ogp` 内で対象 HTML が属するセグメント、グループ index、page index を表します。
///
/// プロパティ:
/// - `segment`: Pages / Components の区分。
/// - `groupIndex`: Chapter または Collection 配列内の位置。
/// - `pageIndex`: Chapter 内 pages または Collection 内 components 配列の位置。
private struct OpenGraphiteProjectPageLocation: Equatable {
    var segment: OpenGraphiteCanvasSegment
    var groupIndex: Int
    var pageIndex: Int
}

/// 論理名（日本語）: i18n検出用script source
/// 概要: HTML inline script と解決済み外部 script を同じ形で検査するための内部値です。
///
/// プロパティ:
/// - `url`: 外部 script の file URL。inline script の場合は HTML URL。
/// - `displayPath`: Inspector / CLI に表示する path。
/// - `source`: script 本文。
/// - `isInline`: HTML inline script か。
private struct OpenGraphiteI18nScriptSource {
    var url: URL
    var displayPath: String
    var source: String
    var isInline: Bool
}

/// 論理名（日本語）: HTML変更応答
/// 概要: node 単位編集の結果 HTML と diagnostics を保持します。
///
/// プロパティ:
/// - `html`: 更新済み HTML。
/// - `diagnostics`: 変更時に発生した diagnostics。
struct OpenGraphiteHTMLMutationResult: Equatable {
    var html: String
    var diagnostics: [OpenGraphiteDiagnostic]

    /// 論理名（日本語）: 失敗結果生成関数
    /// 処理概要: 単一 diagnostic を持つ HTML 変更失敗結果を作ります。
    ///
    /// - Parameters:
    ///   - html: 元の HTML。
    ///   - diagnostic: 失敗理由。
    /// - Returns: 失敗結果。
    static func failure(html: String, diagnostic: OpenGraphiteDiagnostic) -> OpenGraphiteHTMLMutationResult {
        OpenGraphiteHTMLMutationResult(html: html, diagnostics: [diagnostic])
    }
}

/// 論理名（日本語）: Agent編集応答
/// 概要: CLI / MCP の write operation が返す対象 node と diagnostics を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: ファイルを書き換えた場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `node`: 更新後 node。
/// - `diagnostics`: 検証結果。
/// - `insertedNodes`: 挿入操作で新たに増えた node。
struct OpenGraphiteEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var node: OpenGraphiteAgentNode?
    var diagnostics: [OpenGraphiteDiagnostic]
    var insertedNodes: [OpenGraphiteAgentNode]?
}

/// 論理名（日本語）: HTML Document Context編集応答
/// 概要: `<html>` の document attribute と binding metadata の更新結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: HTML ファイルを書き換えた場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `context`: 保存後の HTML document context。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteHTMLDocumentContextResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var context: OpenGraphiteHTMLDocumentContext
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n adapter種別
/// 概要: HTML 実装 runtime から検出した i18n adapter の種類を表します。
///
/// 定義内容:
/// - `i18next`: `i18n.init({...})` 形式の i18next 系設定。
/// - `unknown`: 自動検出できない、または未対応の設定。
enum OpenGraphiteI18nAdapter: String, Codable, Equatable {
    case i18next
    case unknown
}

/// 論理名（日本語）: i18n設定値source
/// 概要: i18n 設定値が literal として編集可能か、外部式として readonly かを表します。
///
/// 定義内容:
/// - `literal`: 文字列 literal として検出でき、OpenGraphite から正本へ書き戻せる可能性がある値。
/// - `external`: env 参照、関数式、識別子など、OpenGraphite が勝手に書き換えない値。
/// - `missing`: 設定が見つからない値。
enum OpenGraphiteI18nConfigSource: String, Codable, Equatable {
    case literal
    case external
    case missing
}

/// 論理名（日本語）: i18n設定プロパティ
/// 概要: `lng`、`fallbackLng`、`backend.loadPath` など検出対象の値と編集可否を表します。
///
/// プロパティ:
/// - `source`: literal / external / missing。
/// - `value`: literal の値。
/// - `expression`: external と判定した式の短い表示値。
/// - `editable`: OpenGraphite から書き戻せるか。
struct OpenGraphiteI18nConfigProperty: Codable, Equatable {
    var source: OpenGraphiteI18nConfigSource
    var value: String?
    var expression: String?
    var editable: Bool
}

/// 論理名（日本語）: i18n locale resource状態
/// 概要: locale JSON の解決先、存在有無、編集可否を Inspector / CLI へ返します。
///
/// プロパティ:
/// - `locale`: locale 名。
/// - `path`: 解決済みファイル path。
/// - `exists`: ファイルが存在するか。
/// - `editable`: literal loadPath または推奨 path として OpenGraphite が書き戻せるか。
struct OpenGraphiteI18nResourceStatus: Codable, Equatable {
    var locale: String
    var path: String
    var exists: Bool
    var editable: Bool
}

/// 論理名（日本語）: i18n runtime検査結果
/// 概要: HTML 実装資源から検出した i18n runtime 設定と locale JSON 状態を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 検査対象 HTML。
/// - `adapter`: 検出した i18n adapter。
/// - `configSource`: 設定を検出した HTML / JS / TS ファイル path。
/// - `lng`: `lng` 設定値。
/// - `fallbackLng`: `fallbackLng` 設定値。
/// - `loadPath`: `backend.loadPath` 設定値。
/// - `localeField`: preview mock として注入できる言語 field 名。
/// - `resources`: locale JSON の状態。
/// - `diagnostics`: 検出時の補助診断。
struct OpenGraphiteI18nRuntimeInspection: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var adapter: OpenGraphiteI18nAdapter
    var configSource: String?
    var lng: OpenGraphiteI18nConfigProperty
    var fallbackLng: OpenGraphiteI18nConfigProperty
    var loadPath: OpenGraphiteI18nConfigProperty
    var localeField: String?
    var resources: [OpenGraphiteI18nResourceStatus]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n推奨設定適用結果
/// 概要: 推奨 runtime script と locale JSON を実装資源へ作成・更新した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: 実装ファイルを書き換えたか。
/// - `pageURL`: 対象 HTML。
/// - `configPath`: 作成または検出した i18n 設定ファイル。
/// - `loadPath`: 推奨 loadPath。
/// - `resources`: locale JSON の状態。
/// - `diagnostics`: 適用時の診断。
struct OpenGraphiteI18nRecommendResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var pageURL: String
    var configPath: String?
    var loadPath: String
    var resources: [OpenGraphiteI18nResourceStatus]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n resource編集結果
/// 概要: locale JSON の flat key に値を書き戻した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: JSON ファイルを書き換えたか。
/// - `path`: 対象 locale JSON path。
/// - `locale`: 更新 locale。
/// - `key`: 更新 key。
/// - `value`: 保存値。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteI18nResourceEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var locale: String
    var key: String
    var value: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n runtime編集結果
/// 概要: 実装側 i18n 設定ファイルの literal 値を更新した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: 実装ファイルを書き換えたか。
/// - `configPath`: 更新対象 i18n 設定ファイル。
/// - `inspection`: 更新後の i18n runtime 検査結果。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteI18nRuntimeEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var configPath: String?
    var inspection: OpenGraphiteI18nRuntimeInspection
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: HTML挿入位置
/// 概要: HTML 断片または既存 node をどこへ配置するかを表します。
///
/// 定義内容:
/// - `before`: 対象 node の直前。
/// - `after`: 対象 node の直後。
/// - `prepend`: 対象 node の最初の子。
/// - `append`: 対象 node の最後の子。
enum OpenGraphiteHTMLInsertionPosition: String, Codable, Equatable {
    case before
    case after
    case prepend
    case append
}

/// 論理名（日本語）: Agent core
/// 概要: `ogkiln` CLI と OpenGraphite MCP server が共有する project / HTML graph / validation / edit 処理です。
///
/// メソッド:
/// - `inspectProject(at:)`: `.ogp` を解決して要約する。
/// - `canvasAnnotations(projectURL:chapterID:collectionID:)`: Chapter / Collection キャンバスの注釈要約一覧を取得する。
/// - `canvasAnnotation(projectURL:id:chapterID:collectionID:)`: 付箋または手書き注釈の完全 payload を取得する。
/// - `addProjectPage(projectURL:id:path:canvas:allowDuplicatePath:)`: `.ogp` に page entry を追加する。
/// - `addProjectComponent(projectURL:collectionID:id:path:canvas:)`: `.ogp` に component entry を追加する。
/// - `removeProjectComponent(projectURL:id:deleteFile:)`: `.ogp` から component entry を削除する。
/// - `createProjectPage(projectURL:id:path:canvas:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML 作成と page entry 登録を一体で行う。
/// - `createProjectComponent(projectURL:collectionID:id:path:canvas:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML 作成と component entry 登録を一体で行う。
/// - `projectPageReference(projectURL:pageID:)`: ``.ogp` の page 参照 ID から HTML を解決する。
/// - `placeProjectPage(projectURL:id:name:x:y:width:height:previewFieldMocks:)`: 既存 page entry の canvas 配置と preview mock state を更新する。
/// - `placeProjectComponent(projectURL:id:name:x:y:width:height:previewFieldMocks:previewPlacementMocks:)`: 既存 component entry の canvas 配置と preview mock state を更新する。
/// - `setProjectPageHTMLDocumentContext(projectURL:id:context:)`: page HTML 正本の document attribute を更新する。
/// - `setProjectComponentHTMLDocumentContext(projectURL:id:context:)`: component HTML 正本の document attribute を更新する。
/// - `createPage(at:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML page file を作成する。
/// - `pageGraph(at:)`: HTML から node graph を抽出する。
/// - `validateHTML(at:)`: HTML を契約に対して検証する。
/// - `setCSSVariable(_:value:nodeID:htmlURL:)`: node 単位で CSS declaration を更新する。
/// - `setRelatedStyleDeclaration(_:value:wrapperNodeID:htmlURL:)`: wrapper配下の実描画要素へ標準CSS declarationを更新する。
/// - `setAttribute(_:value:nodeID:htmlURL:)`: node 単位で属性を更新する。
/// - `setIcon(library:name:source:nodeID:htmlURL:)`: icon node の metadata と描画 HTML を更新する。
/// - `setTextContent(_:nodeID:htmlURL:)`: node の text content を更新する。
/// - `insertIcon(library:name:source:iconID:anchorNodeID:position:width:height:htmlURL:)`: anchor node 基準で icon node を挿入する。
/// - `insertHTML(_:anchorNodeID:position:htmlURL:)`: anchor node 基準で HTML 断片を挿入する。
/// - `replaceNodeHTML(_:nodeID:htmlURL:)`: node 全体を HTML 断片で置換する。
/// - `deleteNode(nodeID:htmlURL:)`: node 全体を削除する。
/// - `moveNode(nodeID:targetNodeID:position:htmlURL:)`: 既存 node を移動する。
/// - `copyNode(nodeID:targetNodeID:position:idPrefix:htmlURL:)`: node subtree を複製する。
struct OpenGraphiteAgentCore {
    static let schemaVersion = "0.1"
    private static let relatedRenderingProperties: Set<String> = [
        "object-fit", "stroke-width", "mask-image", "-webkit-mask-image"
    ]
    var contract: OpenGraphiteContract
    private var migrationWillCommitSource: ((Int, URL) -> Void)?

    /// 論理名（日本語）: Agent core初期化関数
    /// 処理概要: CLI / MCP で共有する契約を保持します。
    ///
    /// - Parameters:
    ///   - contract: 検証に使う OpenGraphite 契約。
    ///   - migrationWillCommitSource: transaction race fixtureがsourceごとのcommit直前へ変更を注入するoptional hook。productionは`nil`。
    init(
        contract: OpenGraphiteContract,
        migrationWillCommitSource: ((Int, URL) -> Void)? = nil
    ) {
        self.contract = contract
        self.migrationWillCommitSource = migrationWillCommitSource
    }

    /// 論理名（日本語）: Project Web契約明示移行関数
    /// 処理概要: project登録sourceだけを列挙し、SHA-256 snapshot proposalに束縛したdry-runまたはatomic applyを実行します。
    ///
    /// - Parameters:
    ///   - projectURL: 対象`.ogp` file URL。
    ///   - targetVersion: 明示するWeb contract target version。
    ///   - options: proposalへ束縛するmigration option。
    ///   - proposalReference: apply時に必須の直前dry-run proposal token。
    ///   - apply: `true`の場合だけ全candidateをstaging後にcommitします。
    /// - Returns: root相対pathで整列したdiff、proposal、diagnostics。
    func migrateProject(
        projectURL: URL,
        targetVersion: String = OpenGraphiteContract.builtIn.migrationPolicy.targetVersion,
        options: OpenGraphiteProjectMigrationOptions = .standard,
        proposalReference: String? = nil,
        apply: Bool = false
    ) throws -> OpenGraphiteProjectMigrationResult {
        try OpenGraphiteProjectMigrationEngine(
            willCommitSource: migrationWillCommitSource
        ).migrate(
            projectURL: projectURL,
            targetVersion: targetVersion,
            options: options,
            proposalReference: proposalReference,
            apply: apply,
            contract: contract
        )
    }

    /// 論理名（日本語）: プロジェクト要約関数
    /// 処理概要: `.ogp` を読み込み、解決済み URL と diagnostics を返します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: project summary。
    func inspectProject(at url: URL) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: url)
        var diagnostics: [OpenGraphiteDiagnostic] = []
        if !FileManager.default.fileExists(atPath: loadedProject.cssURL.path) {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .warning,
                    code: "missing-css-library",
                    message: "CSS library が見つかりません: \(loadedProject.cssURL.path)",
                    path: loadedProject.cssURL.path,
                    nodeID: nil
                )
            )
        }

        let chapters = loadedProject.project.chapters.enumerated().map { chapterIndex, chapter in
            let pages = chapter.pages.enumerated().map { pageIndex, page in
                pageSummary(
                    for: page,
                    chapter: chapter,
                    collection: nil,
                    chapterIndex: chapterIndex,
                    collectionIndex: nil,
                    pageIndex: pageIndex,
                    segment: "pages",
                    loadedProject: loadedProject
                )
            }
            return OpenGraphiteChapterSummary(
                id: chapter.id,
                internalID: chapter.internalID,
                index: chapterIndex,
                title: chapter.title,
                isSidebarHidden: chapter.isSidebarHidden,
                annotationCount: chapter.annotations.count,
                guideCount: chapter.guides.count,
                referenceCount: chapter.references.count,
                pages: pages
            )
        }
        let pages = chapters.flatMap(\.pages)
        let collections = loadedProject.project.collections.enumerated().map { collectionIndex, collection in
            let components = collection.components.enumerated().map { pageIndex, page in
                pageSummary(
                    for: page,
                    chapter: nil,
                    collection: collection,
                    chapterIndex: nil,
                    collectionIndex: collectionIndex,
                    pageIndex: pageIndex,
                    segment: "components",
                    loadedProject: loadedProject
                )
            }
            return OpenGraphiteComponentCollectionSummary(
                id: collection.id,
                internalID: collection.internalID,
                index: collectionIndex,
                title: collection.title,
                annotationCount: collection.annotations.count,
                guideCount: collection.guides.count,
                referenceCount: collection.references.count,
                components: components
            )
        }
        let components = collections.flatMap(\.components)

        return OpenGraphiteProjectSummary(
            schemaVersion: Self.schemaVersion,
            projectName: loadedProject.project.name,
            projectURL: loadedProject.fileURL.path,
            rootURL: loadedProject.rootURL.path,
            htmlRoot: loadedProject.project.htmlRoot,
            cssURL: loadedProject.cssURL.path,
            chapters: chapters,
            collections: collections,
            pages: pages,
            components: components,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: キャンバス注釈一覧関数
    /// 処理概要: Chapter または Collection を一つだけ解決し、手書き点列を展開しない注釈要約を返します。
    ///
    /// - Parameters:
    ///   - projectURL: 読み込む `.ogp` URL。
    ///   - chapterID: Chapter の表示 ID、内部 ID、または `ogref:chapter`。Collection と同時指定できません。
    ///   - collectionID: Collection の表示 ID、内部 ID、または `ogref:collection`。Chapter と同時指定できません。
    /// - Returns: 対象キャンバスと注釈要約一覧。
    func canvasAnnotations(
        projectURL: URL,
        chapterID: String?,
        collectionID: String?
    ) throws -> OpenGraphiteCanvasAnnotationListResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let target = try annotationContainerTarget(
            in: loadedProject.project,
            chapterID: chapterID,
            collectionID: collectionID
        )
        return OpenGraphiteCanvasAnnotationListResult(
            schemaVersion: Self.schemaVersion,
            projectURL: loadedProject.fileURL.path,
            segment: target.segment.rawValue,
            containerID: target.id,
            containerInternalID: target.internalID,
            containerReferenceID: target.referenceID,
            annotations: target.annotations.map { annotationSummary($0, target: target) },
            diagnostics: []
        )
    }

    /// 論理名（日本語）: キャンバス注釈取得関数
    /// 処理概要: raw 注釈 ID と明示コンテナ、または `ogref:annotation` から単一注釈を解決し、点列を含む完全 payload を返します。
    ///
    /// - Parameters:
    ///   - projectURL: 読み込む `.ogp` URL。
    ///   - id: 注釈内部 ID または `ogref:annotation:<segment>:<container>:<annotation>`。
    ///   - chapterID: raw ID と組み合わせる Chapter selector。typed 注釈参照では省略できます。
    ///   - collectionID: raw ID と組み合わせる Collection selector。typed 注釈参照では省略できます。
    /// - Returns: 対象キャンバスと完全な注釈 payload。
    func canvasAnnotation(
        projectURL: URL,
        id: String,
        chapterID: String?,
        collectionID: String?
    ) throws -> OpenGraphiteCanvasAnnotationGetResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: "annotation id は空にできません。")
        }

        let target: OpenGraphiteCanvasAnnotationContainerTarget
        let annotationInternalID: String
        if let reference = OpenGraphiteReferenceID(parsing: normalizedID) {
            guard reference.type == .annotation,
                  let segment = OpenGraphiteCanvasSegment(rawValue: reference.parts[0])
            else {
                throw OpenGraphiteAgentCoreError(
                    message: "annotation get の typed id は ogref:annotation:<pages|components>:<container>:<annotation> で指定してください。"
                )
            }
            let referenceTarget = try annotationContainerTarget(
                in: loadedProject.project,
                segment: segment,
                internalID: reference.parts[1]
            )
            if chapterID != nil || collectionID != nil {
                let explicitTarget = try annotationContainerTarget(
                    in: loadedProject.project,
                    chapterID: chapterID,
                    collectionID: collectionID
                )
                guard explicitTarget.segment == referenceTarget.segment,
                      explicitTarget.internalID == referenceTarget.internalID
                else {
                    throw OpenGraphiteAgentCoreError(
                        message: "annotation id と Chapter / Collection selector が異なるキャンバスを指しています。"
                    )
                }
            }
            target = referenceTarget
            annotationInternalID = reference.parts[2]
        } else {
            if normalizedID.lowercased().hasPrefix("\(OpenGraphiteReferenceID.scheme):") {
                throw OpenGraphiteAgentCoreError(
                    message: "annotation typed id の形式が不正です: \(normalizedID)"
                )
            }
            target = try annotationContainerTarget(
                in: loadedProject.project,
                chapterID: chapterID,
                collectionID: collectionID
            )
            annotationInternalID = normalizedID
        }

        guard let annotation = target.annotations.first(where: { $0.internalID == annotationInternalID }) else {
            throw OpenGraphiteAgentCoreError(
                message: "annotation id \"\(annotationInternalID)\" が対象キャンバスに存在しません。"
            )
        }
        return OpenGraphiteCanvasAnnotationGetResult(
            schemaVersion: Self.schemaVersion,
            projectURL: loadedProject.fileURL.path,
            segment: target.segment.rawValue,
            containerID: target.id,
            containerInternalID: target.internalID,
            containerReferenceID: target.referenceID,
            annotation: OpenGraphiteCanvasAnnotationDetail(
                referenceID: annotationReferenceID(for: annotation, target: target),
                annotation: annotation
            ),
            diagnostics: []
        )
    }

    /// 論理名（日本語）: Projectデザイントークン一覧関数
    /// 処理概要: `.ogp` が参照する CSS library の `:root` から design token を抽出します。
    ///
    /// - Parameter projectURL: `.ogp` ファイル URL。
    /// - Returns: design token 一覧。
    func designTokens(projectURL: URL) throws -> OpenGraphiteDesignTokenListResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        return try designTokens(at: loadedProject.cssURL)
    }

    /// 論理名（日本語）: CSSデザイントークン一覧関数
    /// 処理概要: 指定 CSS file の `:root` から CSS custom property を design token として抽出します。
    ///
    /// - Parameter cssURL: 対象 CSS file URL。
    /// - Returns: design token 一覧。
    func designTokens(at cssURL: URL) throws -> OpenGraphiteDesignTokenListResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: cssURL.path) else {
            return OpenGraphiteDesignTokenListResult(
                schemaVersion: Self.schemaVersion,
                path: cssURL.path,
                tokens: [],
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "missing-design-token-css",
                        message: "design token を読み取る CSS file が見つかりません: \(cssURL.path)",
                        path: cssURL.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let document = OpenGraphiteCompanionCSSDocument(
            css: try String(contentsOf: cssURL, encoding: .utf8)
        )
        return OpenGraphiteDesignTokenListResult(
            schemaVersion: Self.schemaVersion,
            path: cssURL.path,
            tokens: document.designTokens(contract: contract),
            diagnostics: []
        )
    }

    /// 論理名（日本語）: Projectデザイントークン設定関数
    /// 処理概要: `.ogp` が参照する CSS library の `:root` に design token を保存し、空値なら削除します。
    ///
    /// - Parameters:
    ///   - name: CSS custom property 名。
    ///   - value: CSS 値。空の場合は削除。
    ///   - projectURL: `.ogp` ファイル URL。
    /// - Returns: design token 編集結果。
    func setDesignToken(
        _ name: String,
        value: String,
        projectURL: URL
    ) throws -> OpenGraphiteDesignTokenEditResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        return try setDesignToken(name, value: value, cssURL: loadedProject.cssURL)
    }

    /// 論理名（日本語）: CSSデザイントークン設定関数
    /// 処理概要: 指定 CSS file の `:root` に design token を保存し、空値なら削除します。
    ///
    /// - Parameters:
    ///   - name: CSS custom property 名。
    ///   - value: CSS 値。空の場合は削除。
    ///   - cssURL: 対象 CSS file URL。
    /// - Returns: design token 編集結果。
    func setDesignToken(
        _ name: String,
        value: String,
        cssURL: URL
    ) throws -> OpenGraphiteDesignTokenEditResult {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentCSS = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
        var document = OpenGraphiteCompanionCSSDocument(css: currentCSS)
        guard contract.isValidDesignTokenName(normalizedName) else {
            return OpenGraphiteDesignTokenEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: cssURL.path,
                token: nil,
                tokens: document.designTokens(contract: contract),
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "invalid-design-token-name",
                        message: "\(name) は design token として保存できる CSS custom property 名ではありません。",
                        path: cssURL.path,
                        nodeID: nil
                    )
                ]
            )
        }

        document.setDesignToken(normalizedName, value: value, contract: contract)
        let updated = document.css != currentCSS
        if updated {
            try FileManager.default.createDirectory(at: cssURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try document.css.write(to: cssURL, atomically: true, encoding: .utf8)
        }

        let tokens = document.designTokens(contract: contract)
        return OpenGraphiteDesignTokenEditResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            path: cssURL.path,
            token: tokens.first { $0.name == normalizedName },
            tokens: tokens,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: Project locale typography 一覧関数
    /// 処理概要: page / component HTML と同名の companion CSS から標準 `font-family` source rule を抽出します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: page / component ID または typed reference ID。
    /// - Returns: root selector と default / locale 別 declaration 一覧。
    func localeTypography(
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteLocaleTypographyListResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: target.htmlURL)
        let document = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: target.htmlURL)
        let root = try localeTypographyRoot(for: target, document: document)
        return OpenGraphiteLocaleTypographyListResult(
            schemaVersion: Self.schemaVersion,
            path: cssURL.path,
            segment: target.segment,
            resourceID: target.page.internalID,
            rootSelector: root.selector,
            declarations: sortedLocaleTypography(document.localeTypography(rootSelector: root.selector)),
            diagnostics: []
        )
    }

    /// 論理名（日本語）: Project locale typography 設定関数
    /// 処理概要: page / component root または同じ selector scope の `:lang()` rule を provenance 付きで最小差分更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: page / component ID または typed reference ID。
    ///   - locale: 省略 / `default` または任意の妥当な BCP 47 tag。
    ///   - fontFamily: 標準 `font-family` value。空の場合は宣言削除。
    /// - Returns: 更新有無、対象 selector、更新後 declaration 一覧。
    func setLocaleTypography(
        projectURL: URL,
        pageID: String,
        locale: String?,
        fontFamily: String
    ) throws -> OpenGraphiteLocaleTypographyEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: target.htmlURL)
        let currentCSS = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
        var document = OpenGraphiteCompanionCSSDocument(css: currentCSS)
        let root = try localeTypographyRoot(for: target, document: document)
        guard let mutation = document.setLocaleTypography(
            locale: locale,
            fontFamily: fontFamily,
            rootSelector: root.selector
        ) else {
            return OpenGraphiteLocaleTypographyEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: cssURL.path,
                segment: target.segment,
                resourceID: target.page.internalID,
                locale: locale ?? "default",
                selector: root.selector,
                property: "font-family",
                value: fontFamily,
                declarations: sortedLocaleTypography(document.localeTypography(rootSelector: root.selector)),
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "invalid-locale-typography-locale",
                        message: "\(locale ?? "") は selector-safe な BCP 47 locale tag ではありません。",
                        path: cssURL.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let updated = document.css != currentCSS
        if updated {
            try document.write(forHTMLURL: target.htmlURL)
        }
        return OpenGraphiteLocaleTypographyEditResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            path: cssURL.path,
            segment: target.segment,
            resourceID: target.page.internalID,
            locale: mutation.locale,
            selector: mutation.selector,
            property: "font-family",
            value: mutation.declaration?.value ?? "",
            declarations: sortedLocaleTypography(document.localeTypography(rootSelector: root.selector)),
            diagnostics: []
        )
    }

    /// 論理名（日本語）: プロジェクトページ参照解決関数
    /// 処理概要: ``.ogp` の page 参照 ID から編集対象 HTML と読み取り許可ルートを解決します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 解決済み page reference。
    func projectPageReference(projectURL: URL, pageID: String) throws -> OpenGraphiteProjectPageReference {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let target = try projectPageTarget(loadedProject: loadedProject, pageID: pageID)
        return OpenGraphiteProjectPageReference(
            projectURL: loadedProject.fileURL.path,
            segment: target.segment,
            chapterID: target.chapter?.id,
            chapterInternalID: target.chapter?.internalID,
            collectionID: target.collection?.id,
            collectionInternalID: target.collection?.internalID,
            pageID: target.page.id,
            pageInternalID: target.page.internalID,
            referenceID: pageReferenceID(segment: target.segment, chapter: target.chapter, collection: target.collection, page: target.page),
            path: target.page.path,
            htmlURL: target.htmlURL.path,
            rootURL: loadedProject.rootURL.path,
            canvas: target.page.canvas
        )
    }

    /// 論理名（日本語）: プロジェクトページグラフ生成関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML だけを対象に node graph を生成します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。省略時はconditional ruleを暗黙有効化しません。
    /// - Returns: page graph。
    func pageGraph(
        projectURL: URL,
        pageID: String,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphitePageGraph {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        let projectCSS = FileManager.default.fileExists(atPath: target.loadedProject.cssURL.path)
            ? try String(contentsOf: target.loadedProject.cssURL, encoding: .utf8)
            : nil
        return enrichStableNodeReferences(
            in: try pageGraph(
                html: html,
                at: target.htmlURL,
                projectCSS: projectCSS,
                projectCSSURL: target.loadedProject.cssURL,
                allowedRootURL: target.loadedProject.rootURL,
                activeMediaQueries: activeMediaQueries,
                isProjectRegisteredResource: true
            ),
            target: target
        )
    }

    /// 論理名（日本語）: Project node明示adoption関数
    /// 処理概要: project resource内のnode/subtreeへoptional identityだけをdry-runまたは明示適用し、diffとcandidate graphを返します。
    ///
    /// - Parameters:
    ///   - projectURL: 対象`.ogp` URL。
    ///   - pageID: page / component IDまたはtyped reference。
    ///   - reference: dry-runではgraphが返したstable/session node reference、applyではdry-runが返したproposal snapshot reference。
    ///   - selector: locatorが返した安全なselector。
    ///   - domPath: locatorが返したDOM path。
    ///   - scope: nodeまたはsubtree。
    ///   - displayID: targetへ明示するoptional `data-og-id`。
    ///   - apply: `true`の場合だけvalidation成功後にsourceを書き込みます。
    /// - Returns: dry-run/apply結果、source diff、candidate graph。
    func adoptNode(
        projectURL: URL,
        pageID: String,
        reference: String? = nil,
        selector: String? = nil,
        domPath: String? = nil,
        scope: OpenGraphiteNodeAdoptionScope = .node,
        displayID: String? = nil,
        apply: Bool = false
    ) throws -> OpenGraphiteNodeAdoptionResult {
        let nodeReferences = reference.map { [$0] } ?? []
        let target = try projectPageTarget(
            projectURL: projectURL,
            pageID: pageID,
            nodeReferenceIDs: nodeReferences
        )
        let beforeHTML = try String(contentsOf: target.htmlURL, encoding: .utf8)
        let normalizedApplyReference = reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if apply, !normalizedApplyReference.hasPrefix("ogref-session:adoption:") {
            var graph = enrichStableNodeReferences(
                in: try pageGraph(
                    html: beforeHTML,
                    at: target.htmlURL,
                    isProjectRegisteredResource: true
                ),
                target: target
            )
            let diagnostic = OpenGraphiteDiagnostic(
                severity: .error,
                code: "adoption-apply-requires-snapshot-reference",
                message: "applyには同じscope/display IDで実行した直前のdry-runが返すadoption proposal targetReferenceを--referenceで指定してください。",
                path: target.htmlURL.path,
                nodeID: nil
            )
            graph.diagnostics.insert(diagnostic, at: 0)
            return OpenGraphiteNodeAdoptionResult(
                schemaVersion: Self.schemaVersion,
                applied: false,
                changed: false,
                dryRun: false,
                path: target.htmlURL.path,
                scope: scope,
                targetReference: normalizedApplyReference,
                adoptedReferences: [],
                diff: nil,
                graph: graph,
                diagnostics: graph.diagnostics
            )
        }
        let documentURL = target.htmlURL.standardizedFileURL.absoluteString
        let adoption = OpenGraphiteHTMLDocument(html: beforeHTML).adoptingNode(
            reference: reference,
            selector: selector,
            domPath: domPath,
            scope: scope,
            displayID: displayID,
            documentURL: documentURL
        )
        let candidateHTML = adoption.mutation.html
        let changed = candidateHTML != beforeHTML
        var graph = enrichStableNodeReferences(
            in: try pageGraph(
                html: candidateHTML,
                at: target.htmlURL,
                isProjectRegisteredResource: true
            ),
            target: target
        )
        let adoptionDiagnostics = adoption.mutation.diagnostics.map { diagnostic in
            withPath(diagnostic, path: target.htmlURL.path)
        }
        if !adoptionDiagnostics.isEmpty {
            graph.diagnostics = adoptionDiagnostics + graph.diagnostics
        }
        let blocksApply = graph.diagnostics.contains { $0.severity == .error }
        let shouldWrite = apply && changed && !blocksApply
        if shouldWrite {
            try candidateHTML.write(to: target.htmlURL, atomically: true, encoding: .utf8)
        }
        let adoptedPathSet = Set(adoption.adoptedDomPaths)
        let adoptedReferences = graph.nodes
            .filter { adoptedPathSet.contains($0.locator.domPath) && $0.referenceStability == .stable }
            .map(\.reference)
        let diff = changed ? OpenGraphiteSourceDiff(
            path: target.htmlURL.path,
            beforeHash: OpenGraphiteHTMLDocument.contentHash(beforeHTML),
            afterHash: OpenGraphiteHTMLDocument.contentHash(candidateHTML),
            unifiedDiff: Self.unifiedDiff(
                before: beforeHTML,
                after: candidateHTML,
                path: target.htmlURL.path
            )
        ) : nil
        return OpenGraphiteNodeAdoptionResult(
            schemaVersion: Self.schemaVersion,
            applied: shouldWrite,
            changed: changed,
            dryRun: !apply,
            path: target.htmlURL.path,
            scope: scope,
            targetReference: adoption.targetReference,
            adoptedReferences: adoptedReferences,
            diff: diff,
            graph: graph,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページ追加関数
    /// 処理概要: `.ogp` の既定 Chapter pages に新しい HTML ページ定義を追加し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - allowDuplicatePath: 同じ HTML path を別 preview canvas として再登録するか。
    /// - Returns: 更新後 project summary。
    func addProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas
    ) throws -> OpenGraphiteProjectSummary {
        try addProjectPage(
            projectURL: projectURL,
            id: id,
            path: path,
            canvas: canvas,
            allowDuplicatePath: false
        )
    }

    /// 論理名（日本語）: プロジェクトページ追加関数
    /// 処理概要: `.ogp` の既定 Chapter pages に新しい HTML ページ定義を追加し、必要な場合は同じ HTML path の再登録を許可します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - allowDuplicatePath: 同じ HTML path を別 preview canvas として再登録するか。
    /// - Returns: 更新後 project summary。
    func addProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        allowDuplicatePath: Bool
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        var project = loadedProject.project
        let targetChapterIndex = try defaultChapterIndex(in: project)
        if project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if !allowDuplicatePath, project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }
        let htmlURL = loadedProject.rootURL.appendingPathComponent(project.htmlRoot).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: "追加する page HTML が見つかりません: \(htmlURL.path)")
        }

        project.chapters[targetChapterIndex].pages.append(OpenGraphitePage(id: id, path: path, canvas: canvas))
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント追加関数
    /// 処理概要: `.ogp` の Collection に既存 HTML component canvas 定義を追加し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - collectionID: 追加先 Collection の ID / 内部 ID / `ogref:collection`。`nil` の場合は既定 Collection。
    ///   - id: 追加する component ID。
    ///   - path: `htmlRoot` から見た component HTML path。
    ///   - canvas: キャンバス配置。
    /// - Returns: 更新後 project summary。
    func addProjectComponent(
        projectURL: URL,
        collectionID: String?,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        var project = loadedProject.project
        if project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page or component id \"\(id)\" は既に存在します。")
        }
        if project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page or component path \"\(path)\" は既に存在します。")
        }
        let htmlURL = loadedProject.rootURL.appendingPathComponent(project.htmlRoot).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: "追加する component HTML が見つかりません: \(htmlURL.path)")
        }

        let collectionIndex = try writableComponentCollectionIndex(in: &project, collectionID: collectionID)
        project.collections[collectionIndex].components.append(OpenGraphitePage(id: id, path: path, canvas: canvas))
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント削除関数
    /// 処理概要: `.ogp` の Collection から component entry を削除し、指定時は HTML file も削除します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 削除する component ID。
    ///   - deleteFile: component HTML file も削除するか。
    /// - Returns: 更新後 project summary。
    func removeProjectComponent(
        projectURL: URL,
        id: String,
        deleteFile: Bool
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let componentLocation = pageLocation(in: project, pageID: id),
              componentLocation.segment == .components
        else {
            throw OpenGraphiteAgentCoreError(message: "component internalID \"\(id)\" が見つかりません。")
        }

        let removedComponent = project.collections[componentLocation.groupIndex].components.remove(at: componentLocation.pageIndex)
        if deleteFile {
            let htmlRootURL = loadedProject.rootURL
                .appendingPathComponent(project.htmlRoot)
                .standardizedFileURL
            let htmlURL = htmlRootURL
                .appendingPathComponent(removedComponent.path)
                .standardizedFileURL
            try ensureHTMLURL(htmlURL, staysInside: htmlRootURL)
            if FileManager.default.fileExists(atPath: htmlURL.path) {
                try FileManager.default.removeItem(at: htmlURL)
            }
        }

        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトページ作成関数
    /// 処理概要: `.ogp` の `htmlRoot` 配下へ HTML を作成し、同じ処理で既定 Chapter pages に登録します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: stylesheet href。`nil` の場合は `.ogp` の CSS 参照から相対 path を計算します。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存 HTML を上書きするか。
    /// - Returns: 作成と登録の結果。
    func createProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        title: String,
        lang: String,
        stylesheetPath: String?,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphiteProjectPageCreateResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        if loadedProject.project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if loadedProject.project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }

        let htmlURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(path)
            .standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))

        let fileManager = FileManager.default
        let previousData = fileManager.fileExists(atPath: htmlURL.path) ? try Data(contentsOf: htmlURL) : nil
        let stylesheet = stylesheetPath ?? Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let writeResult = try createPage(
            at: htmlURL,
            title: title,
            lang: lang,
            stylesheetPath: stylesheet,
            bodyHTML: bodyHTML,
            overwrite: overwrite
        )
        guard writeResult.created else {
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                project: try? inspectProject(at: projectURL),
                page: nil,
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics
            )
        }

        do {
            let summary = try addProjectPage(projectURL: projectURL, id: id, path: path, canvas: canvas)
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: true,
                project: summary,
                page: summary.pages.first { $0.id == id },
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics + summary.diagnostics
            )
        } catch {
            if let previousData {
                try? previousData.write(to: htmlURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: htmlURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: プロジェクトコンポーネント作成関数
    /// 処理概要: `.ogp` の `htmlRoot` 配下へ component HTML を作成し、同じ処理で Collection に登録します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - collectionID: 登録先 Collection の ID / 内部 ID / `ogref:collection`。`nil` の場合は既定 Collection。
    ///   - id: 追加する component ID。
    ///   - path: `htmlRoot` から見た component HTML path。
    ///   - canvas: キャンバス配置。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: stylesheet href。`nil` の場合は `.ogp` の CSS 参照から相対 path を計算します。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存 HTML を上書きするか。
    /// - Returns: 作成と登録の結果。
    func createProjectComponent(
        projectURL: URL,
        collectionID: String?,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        title: String,
        lang: String,
        stylesheetPath: String?,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphiteProjectPageCreateResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        if loadedProject.project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page or component id \"\(id)\" は既に存在します。")
        }
        if loadedProject.project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page or component path \"\(path)\" は既に存在します。")
        }

        let htmlURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(path)
            .standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))

        let fileManager = FileManager.default
        let previousData = fileManager.fileExists(atPath: htmlURL.path) ? try Data(contentsOf: htmlURL) : nil
        let stylesheet = stylesheetPath ?? Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let writeResult = try createPage(
            at: htmlURL,
            title: title,
            lang: lang,
            stylesheetPath: stylesheet,
            bodyHTML: bodyHTML,
            overwrite: overwrite
        )
        guard writeResult.created else {
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                project: try? inspectProject(at: projectURL),
                page: nil,
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics
            )
        }

        do {
            let summary = try addProjectComponent(projectURL: projectURL, collectionID: collectionID, id: id, path: path, canvas: canvas)
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: true,
                project: summary,
                page: summary.components.first { $0.id == id },
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics + summary.diagnostics
            )
        } catch {
            if let previousData {
                try? previousData.write(to: htmlURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: htmlURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: プロジェクトページ配置関数
    /// 処理概要: `.ogp` の既存 page entry に対して canvas 座標、サイズ、preview mock state を部分更新し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新する page ID。
    ///   - name: 更新後の配置名。`nil` の場合は既存値を維持します。
    ///   - x: 更新後 X 座標。`nil` の場合は既存値を維持します。
    ///   - y: 更新後 Y 座標。`nil` の場合は既存値を維持します。
    ///   - width: 更新後プレビュー幅。`nil` の場合は既存値を維持します。
    ///   - height: 更新後プレビュー高さ。`nil` の場合は既存値を維持します。
    ///   - previewFieldMocks: 更新する canvas 全体の runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 project summary。
    func placeProjectPage(
        projectURL: URL,
        id: String,
        name: String?,
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        previewFieldMocks: [String: String]? = nil
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let pageLocation = pageLocation(in: project, pageID: id) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" が見つかりません。")
        }
        if let width, width <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--width は 0 より大きい数値で指定してください。")
        }
        if let height, height <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--height は 0 より大きい数値で指定してください。")
        }

        if pageLocation.segment == .components {
            let currentCanvas = project.collections[pageLocation.groupIndex].components[pageLocation.pageIndex].canvas
            project.collections[pageLocation.groupIndex].components[pageLocation.pageIndex].canvas = OpenGraphiteCanvas(
                name: normalizedCanvasName(name) ?? currentCanvas.name,
                x: x ?? currentCanvas.x,
                y: y ?? currentCanvas.y,
                width: width ?? currentCanvas.width,
                height: height ?? currentCanvas.height,
                previewContext: try updatedPreviewContext(
                    currentCanvas.previewContext,
                    fieldMocks: previewFieldMocks
                )
            )
        } else {
            let currentCanvas = project.chapters[pageLocation.groupIndex].pages[pageLocation.pageIndex].canvas
            project.chapters[pageLocation.groupIndex].pages[pageLocation.pageIndex].canvas = OpenGraphiteCanvas(
                name: normalizedCanvasName(name) ?? currentCanvas.name,
                x: x ?? currentCanvas.x,
                y: y ?? currentCanvas.y,
                width: width ?? currentCanvas.width,
                height: height ?? currentCanvas.height,
                previewContext: try updatedPreviewContext(
                    currentCanvas.previewContext,
                    fieldMocks: previewFieldMocks
                )
            )
        }
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント配置関数
    /// 処理概要: `.ogp` の既存 component entry に対して canvas 座標、サイズ、preview mock state を部分更新し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新する component page 内部 ID。
    ///   - name: 更新後の配置名。`nil` の場合は既存値を維持します。
    ///   - x: 更新後 X 座標。`nil` の場合は既存値を維持します。
    ///   - y: 更新後 Y 座標。`nil` の場合は既存値を維持します。
    ///   - width: 更新後プレビュー幅。`nil` の場合は既存値を維持します。
    ///   - height: 更新後プレビュー高さ。`nil` の場合は既存値を維持します。
    ///   - previewFieldMocks: 更新する canvas 全体の runtime mock state。`nil` の場合は既存値を維持します。
    ///   - previewPlacementMocks: 更新する placement 単位の runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 project summary。
    func placeProjectComponent(
        projectURL: URL,
        id: String,
        name: String?,
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        previewFieldMocks: [String: String]? = nil,
        previewPlacementMocks: [String: [String: String]]? = nil
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let componentLocation = pageLocation(in: project, pageID: id),
              componentLocation.segment == .components
        else {
            throw OpenGraphiteAgentCoreError(message: "component internalID \"\(id)\" が見つかりません。")
        }
        if let width, width <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--width は 0 より大きい数値で指定してください。")
        }
        if let height, height <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--height は 0 より大きい数値で指定してください。")
        }

        let currentCanvas = project.collections[componentLocation.groupIndex].components[componentLocation.pageIndex].canvas
        project.collections[componentLocation.groupIndex].components[componentLocation.pageIndex].canvas = OpenGraphiteCanvas(
            name: normalizedCanvasName(name) ?? currentCanvas.name,
            x: x ?? currentCanvas.x,
            y: y ?? currentCanvas.y,
            width: width ?? currentCanvas.width,
            height: height ?? currentCanvas.height,
            previewContext: try updatedPreviewContext(
                currentCanvas.previewContext,
                fieldMocks: previewFieldMocks,
                placementMocks: previewPlacementMocks
            )
        )
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: HTMLページ作成関数
    /// 処理概要: 指定 body HTML を含む standalone HTML を作成し、OpenGraphite contract で検証して保存します。
    ///
    /// - Parameters:
    ///   - url: 作成する HTML ファイル URL。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: OpenGraphite.css への相対または絶対参照。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存ファイルを上書きするか。
    /// - Returns: 作成結果。
    func createPage(
        at url: URL,
        title: String,
        lang: String,
        stylesheetPath: String,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphitePageWriteResult {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path), !overwrite {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "page-file-exists",
                        message: "\(url.path) は既に存在します。上書きする場合は --overwrite を指定してください。",
                        path: url.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: url)
        if fileManager.fileExists(atPath: companionCSSURL.path), !overwrite {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "companion-css-file-exists",
                        message: "\(companionCSSURL.path) は既に存在します。上書きする場合は --overwrite を指定してください。",
                        path: companionCSSURL.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let companionStylesheetPath = Self.relativePath(
            from: url.deletingLastPathComponent(),
            to: companionCSSURL
        )
        let rawHTML = """
        <!doctype html>
        <html lang="\(Self.escapeAttribute(lang))">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(Self.escapeText(title))</title>
            <link rel="stylesheet" href="\(Self.escapeAttribute(stylesheetPath))">
            <link rel="stylesheet" href="\(Self.escapeAttribute(companionStylesheetPath))">
          </head>
          <body>
        \(bodyHTML.trimmingCharacters(in: .newlines))
          </body>
        </html>
        """
        // Standard HTML input remains unannotated until the caller explicitly runs adoption.
        let html = rawHTML

        let document = OpenGraphiteHTMLDocument(html: html)
        let companionCSS = OpenGraphiteCompanionCSSDocument(css: "")
        let diagnostics = validate(
            nodes: document.nodes(
                companionCSS: companionCSS,
                contract: contract,
                documentURL: url.standardizedFileURL.absoluteString
            ),
            tags: document.parsedTags(),
            path: url.path,
            companionCSSURL: companionCSSURL,
            companionCSSExists: true
        )
        guard !diagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: diagnostics
            )
        }

        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try html.write(to: url, atomically: true, encoding: .utf8)
        try companionCSS.write(forHTMLURL: url)
        let graph = try pageGraph(at: url)
        return OpenGraphitePageWriteResult(
            schemaVersion: Self.schemaVersion,
            created: true,
            path: url.path,
            graph: graph,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: ページグラフ生成関数
    /// 処理概要: 指定 HTML から node graph と validation diagnostics を生成します。
    ///
    /// - Parameters:
    ///   - url: HTML ファイル URL。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: page graph。
    func pageGraph(
        at url: URL,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphitePageGraph {
        let html = try String(contentsOf: url, encoding: .utf8)
        return try pageGraph(html: html, at: url, activeMediaQueries: activeMediaQueries)
    }

    /// In-memory HTML candidateをsourceへ書き込まずgraph/validationへ変換します。
    private func pageGraph(
        html: String,
        at url: URL,
        projectCSS: String? = nil,
        projectCSSURL: URL? = nil,
        allowedRootURL: URL? = nil,
        activeMediaQueries: [String] = [],
        isProjectRegisteredResource: Bool = false
    ) throws -> OpenGraphitePageGraph {
        let document = OpenGraphiteHTMLDocument(html: html)
        let companionCSS = try OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: url)
        let stylesheetResolution = document.stylesheetResolution(
            documentURL: url,
            allowedRootURL: allowedRootURL,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            companionCSS: companionCSS
        )
        let normalizedMediaQueries = OpenGraphiteCSSCascadeEnvironment
            .normalizedActiveMediaQueries(activeMediaQueries)
        let nodes = document.nodes(
            companionCSS: companionCSS,
            projectCSS: projectCSS,
            stylesheetSources: stylesheetResolution.sources,
            hasIncompleteCSSProvenance: stylesheetResolution.hasIncompleteProvenance,
            activeMediaQueries: normalizedMediaQueries,
            contract: contract,
            documentURL: url.standardizedFileURL.absoluteString,
            isProjectRegisteredResource: isProjectRegisteredResource || allowedRootURL != nil
        )
        let validationDiagnostics = validate(
            nodes: nodes,
            tags: document.parsedTags(),
            path: url.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: url),
            companionCSSExists: companionCSS != nil
        )
        return OpenGraphitePageGraph(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            activeMediaQueries: normalizedMediaQueries,
            hasIncompleteCSSProvenance: stylesheetResolution.hasIncompleteProvenance
                || nodes.contains(where: \.hasIncompleteCSSProvenance),
            nodes: nodes,
            diagnostics: stylesheetResolution.diagnostics + validationDiagnostics
        )
    }

    /// Project文脈で一意なinternal IDを既存typed `ogref`へ置き換えます。
    private func enrichStableNodeReferences(
        in graph: OpenGraphitePageGraph,
        target: OpenGraphiteProjectPageTarget
    ) -> OpenGraphitePageGraph {
        var graph = graph
        var replacements: [String: String] = [:]
        for node in graph.nodes where node.referenceStability == .stable {
            let typedReference: String?
            if target.segment == OpenGraphiteCanvasSegment.pages.rawValue,
               let chapterID = target.chapter?.internalID {
                typedReference = OpenGraphiteReferenceID.node(
                    chapterID: chapterID,
                    pageID: target.page.internalID,
                    nodeID: node.internalID
                ).stringValue
            } else if target.segment == OpenGraphiteCanvasSegment.components.rawValue,
                      let collectionID = target.collection?.internalID {
                typedReference = OpenGraphiteReferenceID.componentNode(
                    collectionID: collectionID,
                    componentID: target.page.internalID,
                    nodeID: node.internalID
                ).stringValue
            } else {
                typedReference = nil
            }
            if let typedReference {
                replacements[node.reference] = typedReference
            }
        }
        for index in graph.nodes.indices {
            if let reference = replacements[graph.nodes[index].reference] {
                graph.nodes[index].reference = reference
            }
            if let parentReference = graph.nodes[index].parentReference,
               let replacement = replacements[parentReference] {
                graph.nodes[index].parentReference = replacement
            }
        }
        return graph
    }

    /// 論理名（日本語）: ノード検索関数
    /// 処理概要: HTML page graph から指定条件に一致する OpenGraphite node を抽出します。
    ///
    /// - Parameters:
    ///   - url: HTML ファイル URL。
    ///   - query: 絞り込み条件。
    /// - Returns: node query result。
    func queryNodes(at url: URL, query: OpenGraphiteNodeQuery) throws -> OpenGraphiteNodeQueryResult {
        let graph = try pageGraph(at: url)
        let nodes = graph.nodes.filter { matchesNodeQuery($0, query: query) }
        return OpenGraphiteNodeQueryResult(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            query: query,
            nodes: nodes,
            diagnostics: graph.diagnostics
        )
    }

    /// Node queryのoptional条件をannotationの有無に依存せず評価します。
    private func matchesNodeQuery(_ node: OpenGraphiteAgentNode, query: OpenGraphiteNodeQuery) -> Bool {
        if let idContains = query.idContains,
           !node.id.localizedCaseInsensitiveContains(idContains),
           !(node.attributes["id"] ?? "").localizedCaseInsensitiveContains(idContains),
           !node.reference.localizedCaseInsensitiveContains(idContains) {
            return false
        }
        if let type = query.type, node.legacyTypeHint != type { return false }
        let nodeCapabilities = Set(node.capabilities)
        if query.capabilities.contains(where: { !nodeCapabilities.contains($0) }) { return false }
        if let role = query.role, node.role != role { return false }
        if let tag = query.tag, node.tagName != tag.lowercased() { return false }
        if let textContains = query.textContains,
           !(node.textContent ?? "").localizedCaseInsensitiveContains(textContains) {
            return false
        }
        return true
    }

    /// 論理名（日本語）: HTML検証関数
    /// 処理概要: 指定 HTML を OpenGraphite 契約に対して検証します。
    ///
    /// - Parameter url: HTML ファイル URL。
    /// - Returns: validation result。
    func validateHTML(at url: URL) throws -> OpenGraphiteValidationResult {
        let graph = try pageGraph(at: url)
        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !graph.diagnostics.contains { $0.severity == .error },
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: HTML Document Contextファイル更新関数
    /// 処理概要: HTML 正本の `<html>` attribute と OpenGraphite binding metadata を更新します。
    ///
    /// - Parameters:
    ///   - context: 保存する HTML document context。
    ///   - htmlURL: 対象 HTML ファイル URL。
    /// - Returns: 更新結果。
    func setHTMLDocumentContext(
        _ context: OpenGraphiteHTMLDocumentContext,
        htmlURL: URL
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingHTMLDocumentContext(context, contract: contract)
        return try persistHTMLDocumentContextMutation(
            mutation,
            htmlURL: htmlURL,
            didChange: mutation.html != html
        )
    }

    /// 論理名（日本語）: プロジェクトページHTML Document Context更新関数
    /// 処理概要: `.ogp` の page 参照 ID から HTML 正本を解決し、document attribute を更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新対象 page ID。
    ///   - context: 保存する HTML document context。
    /// - Returns: 更新結果。
    func setProjectPageHTMLDocumentContext(
        projectURL: URL,
        id: String,
        context: OpenGraphiteHTMLDocumentContext
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: id)
        guard target.segment == OpenGraphiteCanvasSegment.pages.rawValue else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は Pages ではありません。component は project component document を使ってください。")
        }
        return try setHTMLDocumentContext(context, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: プロジェクトComponent HTML Document Context更新関数
    /// 処理概要: `.ogp` の component ID から HTML 正本を解決し、document attribute を更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新対象 component ID。
    ///   - context: 保存する HTML document context。
    /// - Returns: 更新結果。
    func setProjectComponentHTMLDocumentContext(
        projectURL: URL,
        id: String,
        context: OpenGraphiteHTMLDocumentContext
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: id)
        guard target.segment == OpenGraphiteCanvasSegment.components.rawValue else {
            throw OpenGraphiteAgentCoreError(message: "component id \"\(id)\" は Components ではありません。page は project page document を使ってください。")
        }
        return try setHTMLDocumentContext(context, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: i18n runtime検査関数
    /// 処理概要: `.ogp` の page 参照から HTML 実装資源を辿り、i18next 系 `i18n.init` と locale JSON 状態を検出します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - locales: 状態を確認する locale。未指定時は `ja` と `eng`。
    /// - Returns: i18n runtime 検査結果。
    func inspectI18n(
        projectURL: URL,
        pageID: String,
        locales: [String] = ["ja", "eng"]
    ) throws -> OpenGraphiteI18nRuntimeInspection {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try inspectI18n(target: target, locales: locales)
    }

    /// 論理名（日本語）: i18n推奨設定適用関数
    /// 処理概要: 自動検出できないページへ推奨 runtime を追加し、`public/locales/<locale>.json` を実装資源として作成・更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - locales: 作成・更新する locale 一覧。
    /// - Returns: 推奨設定適用結果。
    func recommendI18n(
        projectURL: URL,
        pageID: String,
        locales: [String]
    ) throws -> OpenGraphiteI18nRecommendResult {
        let requestedLocales = normalizedLocales(locales.isEmpty ? ["ja", "eng"] : locales)
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let beforeInspection = try inspectI18n(target: target, locales: requestedLocales)
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        var nextHTML = html
        var updated = false
        var configURL: URL?

        if beforeInspection.adapter == .unknown {
            let i18nURL = htmlRootURL.appendingPathComponent("i18n.js").standardizedFileURL
            configURL = i18nURL
            if !FileManager.default.fileExists(atPath: i18nURL.path) {
                try FileManager.default.createDirectory(at: i18nURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Self.recommendedI18nRuntimeSource.write(to: i18nURL, atomically: true, encoding: .utf8)
                updated = true
            }
            let scriptPath = Self.relativePath(from: target.htmlURL.deletingLastPathComponent(), to: i18nURL)
            nextHTML = Self.insertingRecommendedI18nScriptIfNeeded(in: nextHTML, scriptPath: scriptPath)
            if nextHTML != html {
                try nextHTML.write(to: target.htmlURL, atomically: true, encoding: .utf8)
                updated = true
            }
        } else if let configSource = beforeInspection.configSource {
            configURL = URL(fileURLWithPath: configSource)
        }

        let resourceLoadPath = beforeInspection.loadPath.source == .literal
            ? beforeInspection.loadPath.value ?? Self.recommendedI18nLoadPath
            : Self.recommendedI18nLoadPath
        let textBindings = OpenGraphiteHTMLDocument(html: nextHTML).textBindingResources()
        var resourceStatuses: [OpenGraphiteI18nResourceStatus] = []
        for locale in requestedLocales {
            let resourceURL = localeResourceURL(
                loadPath: resourceLoadPath,
                locale: locale,
                htmlRootURL: htmlRootURL,
                pageURL: target.htmlURL,
                configURL: configURL
            )
            let didUpdateResource = try mergeLocaleResource(
                at: resourceURL,
                locale: locale,
                bindings: textBindings,
                fallbackLocale: fallbackLocale(from: beforeInspection) ?? "ja"
            )
            updated = updated || didUpdateResource
            resourceStatuses.append(
                OpenGraphiteI18nResourceStatus(
                    locale: locale,
                    path: resourceURL.path,
                    exists: FileManager.default.fileExists(atPath: resourceURL.path),
                    editable: true
                )
            )
        }

        return OpenGraphiteI18nRecommendResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            pageURL: target.htmlURL.path,
            configPath: configURL?.path,
            loadPath: resourceLoadPath,
            resources: resourceStatuses,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: i18n runtime literal更新関数
    /// 処理概要: 実装側 `i18n.init({...})` の literal 設定だけを正本 JS/TS ファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - loadPath: 更新する `backend.loadPath`。`nil` の場合は更新しません。
    ///   - fallbackLocale: 更新する `fallbackLng`。`nil` の場合は更新しません。
    /// - Returns: 更新後の i18n runtime 検査結果を含む編集結果。
    func updateI18nRuntimeLiterals(
        projectURL: URL,
        pageID: String,
        loadPath: String?,
        fallbackLocale: String?
    ) throws -> OpenGraphiteI18nRuntimeEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let inspection = try inspectI18n(target: target, locales: ["ja", "eng"])
        var diagnostics: [OpenGraphiteDiagnostic] = []

        guard inspection.adapter != .unknown else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-i18n-runtime",
                    message: "i18n.init({...}) を検出できないため runtime 設定を編集できません。",
                    path: target.htmlURL.path,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: inspection.configSource,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        guard let configSource = inspection.configSource,
              !configSource.contains("#inline-script")
        else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "inline-i18n-config",
                    message: "inline script の i18n 設定は Project Dependencies から直接編集できません。",
                    path: inspection.configSource,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: inspection.configSource,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        let configURL = URL(fileURLWithPath: configSource)
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-i18n-config-file",
                    message: "i18n 設定ファイルが見つかりません: \(configURL.path)",
                    path: configURL.path,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: configURL.path,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        var source = try String(contentsOf: configURL, encoding: .utf8)
        let before = source

        if let loadPath {
            if inspection.loadPath.source == .literal {
                source = Self.replacingI18nLiteralProperty(named: "loadPath", value: loadPath, in: source) ?? source
            } else {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-load-path",
                        message: "backend.loadPath は external / readonly のため Project Dependencies から編集できません。",
                        path: configURL.path,
                        nodeID: nil
                    )
                )
            }
        }

        if let fallbackLocale {
            if inspection.fallbackLng.source == .literal {
                source = Self.replacingI18nLiteralProperty(named: "fallbackLng", value: fallbackLocale, in: source) ?? source
            } else {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-fallback",
                        message: "fallbackLng は external / readonly のため Project Dependencies から編集できません。",
                        path: configURL.path,
                        nodeID: nil
                    )
                )
            }
        }

        guard diagnostics.filter({ $0.severity == .error }).isEmpty else {
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: configURL.path,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        let updated = source != before
        if updated {
            try source.write(to: configURL, atomically: true, encoding: .utf8)
        }
        let nextInspection = try inspectI18n(target: target, locales: ["ja", "eng"])
        return OpenGraphiteI18nRuntimeEditResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            configPath: configURL.path,
            inspection: nextInspection,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: i18n resource値設定関数
    /// 処理概要: 検出済みまたは推奨 loadPath から locale JSON を解決し、flat key の値を正本 JSON へ保存します。
    ///
    /// - Parameters:
    ///   - value: 保存する HTML/text 値。空文字も有効です。
    ///   - locale: 更新 locale。
    ///   - key: 更新する flat i18n key。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    /// - Returns: resource 編集結果。
    func setI18nResourceValue(
        _ value: String,
        locale: String,
        key: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteI18nResourceEditResult {
        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLocale.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: "locale は空にできません。")
        }
        guard !normalizedKey.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: "i18n resource key は空にできません。")
        }

        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let inspection = try inspectI18n(target: target, locales: [normalizedLocale])
        guard inspection.loadPath.source != .external else {
            return OpenGraphiteI18nResourceEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: "",
                locale: normalizedLocale,
                key: normalizedKey,
                value: value,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-load-path",
                        message: "backend.loadPath は external / readonly のため、対象 resource path を自動更新できません。",
                        path: inspection.configSource,
                        nodeID: nil
                    )
                ]
            )
        }

        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let resourceURL = localeResourceURL(
            loadPath: inspection.loadPath.value ?? Self.recommendedI18nLoadPath,
            locale: normalizedLocale,
            htmlRootURL: htmlRootURL,
            pageURL: target.htmlURL,
            configURL: inspection.configSource.map { URL(fileURLWithPath: $0) }
        )
        var resource = try readLocaleResource(at: resourceURL)
        let didChange = resource[normalizedKey] as? String != value
        resource[normalizedKey] = value
        if didChange {
            try writeLocaleResource(resource, to: resourceURL)
        }
        return OpenGraphiteI18nResourceEditResult(
            schemaVersion: Self.schemaVersion,
            updated: didChange,
            path: resourceURL.path,
            locale: normalizedLocale,
            key: normalizedKey,
            value: value,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: プロジェクト検証関数
    /// 処理概要: `.ogp` と参照 HTML / CSS をまとめて検証します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: validation result。
    func validateProject(at url: URL) throws -> OpenGraphiteValidationResult {
        let summary = try inspectProject(at: url)
        var diagnostics = summary.diagnostics
        for page in summary.pages {
            let graph = try pageGraph(at: URL(fileURLWithPath: page.htmlURL))
            diagnostics.append(contentsOf: graph.diagnostics)
            diagnostics.append(contentsOf: componentPlacementUsageDiagnostics(
                nodes: graph.nodes,
                path: page.htmlURL,
                allowsComponentPlacements: false
            ))
        }
        for component in summary.components {
            let graph = try pageGraph(at: URL(fileURLWithPath: component.htmlURL))
            diagnostics.append(contentsOf: graph.diagnostics)
            diagnostics.append(contentsOf: componentPlacementReferenceDiagnostics(
                nodes: graph.nodes,
                path: component.htmlURL,
                componentInternalID: component.internalID
            ))
        }

        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !diagnostics.contains { $0.severity == .error },
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページノード検索関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML から node を検索します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    ///   - query: 絞り込み条件。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: node query result。
    func queryNodes(
        projectURL: URL,
        pageID: String,
        query: OpenGraphiteNodeQuery,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphiteNodeQueryResult {
        let graph = try pageGraph(
            projectURL: projectURL,
            pageID: pageID,
            activeMediaQueries: activeMediaQueries
        )
        return OpenGraphiteNodeQueryResult(
            schemaVersion: Self.schemaVersion,
            pageURL: graph.pageURL,
            query: query,
            nodes: graph.nodes.filter { matchesNodeQuery($0, query: query) },
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: ノード取得関数
    /// 処理概要: HTML graphからsession/stable reference、内部ID、または一意な表示IDに一致するinspectable nodeを取得します。
    ///
    /// - Parameters:
    ///   - id: 対象session/stable reference、`data-og-internal-id`、または一意な`data-og-id`。
    ///   - url: HTML ファイル URL。
    /// - Returns: edit result 形式の node 取得結果。
    func node(id: String, at url: URL) throws -> OpenGraphiteEditResult {
        let resolvedID = resolvedNodeID(id)
        let graph = try pageGraph(at: url)
        let matches = graph.nodes.filter {
            $0.internalID == resolvedID || $0.reference == id || (!$0.id.isEmpty && $0.id == id)
        }
        let diagnostics = uniqueNodeDiagnostics(matches: matches, id: resolvedID, path: url.path)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: url.path,
            node: matches.count == 1 ? matches[0] : nil,
            diagnostics: diagnostics,
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: プロジェクトページノード取得関数
    /// 処理概要: `.ogp` のpage参照で明示されたHTML graphからsession/stable reference、内部ID、または一意な表示IDに一致するnodeを取得します。
    ///
    /// - Parameters:
    ///   - id: 対象session/stable reference、`data-og-internal-id`、または一意な`data-og-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: edit result 形式の node 取得結果。
    func node(
        id: String,
        projectURL: URL,
        pageID: String,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphiteEditResult {
        _ = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [id])
        let graph = try pageGraph(
            projectURL: projectURL,
            pageID: pageID,
            activeMediaQueries: activeMediaQueries
        )
        let resolvedID = resolvedNodeID(id)
        let matches = graph.nodes.filter {
            $0.internalID == resolvedID || $0.reference == id || (!$0.id.isEmpty && $0.id == id)
        }
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: graph.pageURL,
            node: matches.count == 1 ? matches[0] : nil,
            diagnostics: uniqueNodeDiagnostics(matches: matches, id: id, path: graph.pageURL),
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: CSS宣言ファイル更新関数
    /// 処理概要: 指定 node の CSS 宣言を companion CSS へ保存し、HTML から runtime / design style を除去します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS property または custom property。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: 編集結果。
    func setCSSVariable(
        _ variable: String,
        value: String,
        nodeID: String,
        htmlURL: URL,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedProperty = variable.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if Self.relatedRenderingProperties.contains(normalizedProperty) {
            return try setRelatedStyleDeclaration(
                normalizedProperty,
                value: value,
                wrapperNodeID: normalizedNodeID,
                htmlURL: htmlURL,
                activeMediaQueries: activeMediaQueries
            )
        }
        if contract.isKnownCSSVariable(normalizedProperty),
           !contract.runtimeCSSVariableSet.contains(normalizedProperty) {
            return try setNodeStyleDeclaration(
                normalizedProperty,
                value: value,
                nodeID: normalizedNodeID,
                htmlURL: htmlURL,
                activeMediaQueries: activeMediaQueries
            )
        }
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        return try persistCompanionCSSVariable(
            variable,
            value: value,
            nodeID: normalizedNodeID,
            html: html,
            htmlURL: htmlURL
        )
    }

    /// 論理名（日本語）: プロジェクトページCSS宣言更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示されたnodeのcompanion CSSを更新し、project CSS libraryはdesign-token正本として変更しません。
    /// Project graphのwinnerが要求値と同じ場合はsourceを変更せず、libraryだけに異なwinnerがある場合は安全なnode selectorのcompanion overrideを追加します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS property または custom property。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: 編集結果。
    func setCSSVariable(
        _ variable: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedProperty = variable.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let projectCSS = FileManager.default.fileExists(atPath: target.loadedProject.cssURL.path)
            ? try String(contentsOf: target.loadedProject.cssURL, encoding: .utf8)
            : nil
        var result: OpenGraphiteEditResult
        if Self.relatedRenderingProperties.contains(normalizedProperty) {
            result = try setRelatedStyleDeclaration(
                normalizedProperty,
                value: value,
                wrapperNodeID: normalizedNodeID,
                htmlURL: target.htmlURL,
                activeMediaQueries: activeMediaQueries,
                projectCSSURL: target.loadedProject.cssURL,
                projectCSS: projectCSS,
                allowedRootURL: target.loadedProject.rootURL
            )
        } else if contract.isKnownCSSVariable(normalizedProperty),
                  !contract.runtimeCSSVariableSet.contains(normalizedProperty) {
            result = try setNodeStyleDeclaration(
                normalizedProperty,
                value: value,
                nodeID: normalizedNodeID,
                htmlURL: target.htmlURL,
                activeMediaQueries: activeMediaQueries,
                projectCSSURL: target.loadedProject.cssURL,
                projectCSS: projectCSS,
                allowedRootURL: target.loadedProject.rootURL
            )
        } else {
            result = try setCSSVariable(
                variable,
                value: value,
                nodeID: normalizedNodeID,
                htmlURL: target.htmlURL,
                activeMediaQueries: activeMediaQueries
            )
        }
        guard !result.diagnostics.contains(where: { $0.severity == .error }) else {
            return result
        }
        let graph = try pageGraph(
            projectURL: projectURL,
            pageID: pageID,
            activeMediaQueries: activeMediaQueries
        )
        result.node = graph.nodes.first { $0.internalID == normalizedNodeID }
        result.diagnostics = graph.diagnostics
        return result
    }

    /// 論理名（日本語）: ノード自身標準CSS宣言更新関数
    /// 処理概要: node自身の標準CSS propertyをsource cascadeに従って最小差分更新し、legacy helperや他のtransform propertyを保持します。
    ///
    /// - Parameters:
    ///   - property: node自身へ保存するsource-aware標準CSS property。
    ///   - value: CSS値。空の場合はwinner declarationを削除。
    ///   - nodeID: 対象`data-og-internal-id`。
    ///   - htmlURL: HTMLファイルURL。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    ///   - projectCSSURL: project文脈でだけ渡すread-only cssLibrary URL。
    ///   - projectCSS: project文脈で既に読み込んだcssLibrary source。
    ///   - allowedRootURL: linked stylesheetの読込を許可するproject root。
    /// - Returns: 更新後nodeとsource diagnosticsを含む編集結果。
    func setNodeStyleDeclaration(
        _ property: String,
        value: String,
        nodeID: String,
        htmlURL: URL,
        activeMediaQueries: [String] = [],
        projectCSSURL: URL? = nil,
        projectCSS: String? = nil,
        allowedRootURL: URL? = nil
    ) throws -> OpenGraphiteEditResult {
        let normalizedProperty = property.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedNodeID = resolvedNodeID(nodeID)
        guard contract.isKnownCSSVariable(normalizedProperty),
              !contract.runtimeCSSVariableSet.contains(normalizedProperty)
        else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-node-style-property",
                        message: "\(property) はnode自身へsource-aware保存できる編集可能CSS propertyではありません。",
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ],
                insertedNodes: nil
            )
        }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedValue.isEmpty,
           !OpenGraphiteCSSSourceDocument.isValidCSSPropertyValue(
            normalizedValue,
            for: normalizedProperty
           ) {
            return invalidCSSPropertyValueResult(
                property: normalizedProperty,
                value: normalizedValue,
                path: htmlURL.path,
                nodeID: normalizedNodeID
            )
        }

        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)
        let graph = try pageGraph(
            html: html,
            at: htmlURL,
            projectCSS: projectCSS,
            projectCSSURL: projectCSSURL,
            allowedRootURL: allowedRootURL,
            activeMediaQueries: activeMediaQueries
        )
        let matches = graph.nodes.filter { $0.internalID == normalizedNodeID }
        let nodeDiagnostics = uniqueNodeDiagnostics(matches: matches, id: normalizedNodeID, path: htmlURL.path)
        guard nodeDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: nodeDiagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.editLayout) else {
            return unsupportedCapabilityResult(
                capability: .editLayout,
                operation: "node style edit",
                path: htmlURL.path,
                node: matches[0]
            )
        }
        if matches[0].hasIncompleteCSSProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: graph.diagnostics + [
                    incompleteCSSNodeDiagnostic(
                        property: normalizedProperty,
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ]
            )
        }

        let companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let stylesheetResolution = document.stylesheetResolution(
            documentURL: htmlURL,
            allowedRootURL: allowedRootURL,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            companionCSS: companionCSS
        )
        if stylesheetResolution.hasIncompleteProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: stylesheetResolution.diagnostics
            )
        }
        guard let target = document.styleTarget(
            forNodeID: normalizedNodeID,
            properties: [normalizedProperty],
            stylesheetSources: stylesheetResolution.sources,
            activeMediaQueries: activeMediaQueries
        ), !target.value.writeSelector.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: matches[0],
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-node-style-target",
                        message: "\(normalizedProperty) の保存先node selectorを安全に解決できません。",
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ],
                insertedNodes: nil
            )
        }
        if target.hasIncompleteCSSProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: graph.diagnostics + [
                    incompleteCSSNodeDiagnostic(
                        property: normalizedProperty,
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ]
            )
        }
        return try persistResolvedStyleDeclaration(
            normalizedProperty,
            value: value,
            nodeID: normalizedNodeID,
            htmlURL: htmlURL,
            html: html,
            document: document,
            target: target,
            companionCSS: companionCSS,
            fallbackNode: matches[0],
            activeMediaQueries: activeMediaQueries,
            stylesheetResolution: stylesheetResolution,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            allowedRootURL: allowedRootURL
        )
    }

    /// 論理名（日本語）: 関連実描画要素CSS宣言更新関数
    /// 処理概要: wrapperを選択したままDOM関係を解決し、media、SVG、maskの実要素へ標準CSSを最小差分保存します。
    ///
    /// - Parameters:
    ///   - property: `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image`のいずれか。
    ///   - value: CSS値。空の場合は対象source declarationを削除。
    ///   - wrapperNodeID: 選択wrapperの`data-og-internal-id`。
    ///   - htmlURL: HTMLファイルURL。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    ///   - projectCSSURL: project文脈でだけ渡すread-only cssLibrary URL。
    ///   - projectCSS: project文脈で既に読み込んだcssLibrary source。
    ///   - allowedRootURL: linked stylesheetの読込を許可するproject root。
    /// - Returns: wrapper nodeと更新後provenanceを含む編集結果。
    func setRelatedStyleDeclaration(
        _ property: String,
        value: String,
        wrapperNodeID: String,
        htmlURL: URL,
        activeMediaQueries: [String] = [],
        projectCSSURL: URL? = nil,
        projectCSS: String? = nil,
        allowedRootURL: URL? = nil
    ) throws -> OpenGraphiteEditResult {
        let normalizedProperty = property.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedNodeID = resolvedNodeID(wrapperNodeID)
        guard Self.relatedRenderingProperties.contains(normalizedProperty),
              contract.isKnownCSSVariable(normalizedProperty)
        else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-related-style-property",
                        message: "\(property) は実描画要素へ保存できる標準CSS propertyではありません。",
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ],
                insertedNodes: nil
            )
        }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedValue.isEmpty,
           !OpenGraphiteCSSSourceDocument.isValidCSSPropertyValue(
            normalizedValue,
            for: normalizedProperty
           ) {
            return invalidCSSPropertyValueResult(
                property: normalizedProperty,
                value: normalizedValue,
                path: htmlURL.path,
                nodeID: normalizedNodeID
            )
        }

        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)
        let graph = try pageGraph(
            html: html,
            at: htmlURL,
            projectCSS: projectCSS,
            projectCSSURL: projectCSSURL,
            allowedRootURL: allowedRootURL,
            activeMediaQueries: activeMediaQueries
        )
        let matches = graph.nodes.filter { $0.internalID == normalizedNodeID }
        let nodeDiagnostics = uniqueNodeDiagnostics(matches: matches, id: normalizedNodeID, path: htmlURL.path)
        guard nodeDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: nodeDiagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.editLayout) else {
            return unsupportedCapabilityResult(
                capability: .editLayout,
                operation: "rendering style edit",
                path: htmlURL.path,
                node: matches[0]
            )
        }
        if matches[0].hasIncompleteCSSProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: graph.diagnostics + [
                    incompleteCSSNodeDiagnostic(
                        property: normalizedProperty,
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ]
            )
        }

        let companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let stylesheetResolution = document.stylesheetResolution(
            documentURL: htmlURL,
            allowedRootURL: allowedRootURL,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            companionCSS: companionCSS
        )
        if stylesheetResolution.hasIncompleteProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: stylesheetResolution.diagnostics
            )
        }
        let targets = document.renderingTargets(
            forNodeID: normalizedNodeID,
            stylesheetSources: stylesheetResolution.sources,
            activeMediaQueries: activeMediaQueries
        )
        let expectedKind: String
        switch normalizedProperty {
        case "object-fit": expectedKind = "media"
        case "stroke-width": expectedKind = "svg"
        default: expectedKind = "mask"
        }
        let requiredCapability: OpenGraphiteNodeCapability = expectedKind == "media"
            ? .editMedia
            : .editIcon
        guard matches[0].supports(requiredCapability) else {
            return unsupportedCapabilityResult(
                capability: requiredCapability,
                operation: "\(normalizedProperty) rendering style edit",
                path: htmlURL.path,
                node: matches[0]
            )
        }
        guard let target = targets.first(where: { $0.value.kind == expectedKind }),
              !target.value.writeSelector.isEmpty
        else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: matches[0],
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-rendering-target",
                        message: "\(normalizedProperty) の実描画要素をwrapper配下から安全に解決できません。",
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ],
                insertedNodes: nil
            )
        }
        if target.hasIncompleteCSSProvenance {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: matches[0],
                nodeID: normalizedNodeID,
                diagnostics: graph.diagnostics + [
                    incompleteCSSNodeDiagnostic(
                        property: normalizedProperty,
                        path: htmlURL.path,
                        nodeID: normalizedNodeID
                    )
                ]
            )
        }

        return try persistResolvedStyleDeclaration(
            normalizedProperty,
            value: value,
            nodeID: normalizedNodeID,
            htmlURL: htmlURL,
            html: html,
            document: document,
            target: target,
            companionCSS: companionCSS,
            fallbackNode: matches[0],
            activeMediaQueries: activeMediaQueries,
            stylesheetResolution: stylesheetResolution,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            allowedRootURL: allowedRootURL,
            relatedTargetKind: expectedKind
        )
    }

    /// 論理名（日本語）: プロジェクト関連実描画要素CSS宣言更新関数
    /// 処理概要: `.ogp` page参照を解決し、wrapper配下の実DOM要素へ標準CSSを保存します。
    ///
    /// - Parameters:
    ///   - property: 対象標準CSS property。
    ///   - value: CSS値。空の場合は削除。
    ///   - wrapperNodeID: 選択wrapperの参照ID。
    ///   - projectURL: `.ogp`ファイルURL。
    ///   - pageID: pageまたはcomponent参照ID。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: 更新後wrapper nodeを含む編集結果。
    func setRelatedStyleDeclaration(
        _ property: String,
        value: String,
        wrapperNodeID: String,
        projectURL: URL,
        pageID: String,
        activeMediaQueries: [String] = []
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(
            projectURL: projectURL,
            pageID: pageID,
            nodeReferenceIDs: [wrapperNodeID]
        )
        let projectCSS = FileManager.default.fileExists(atPath: target.loadedProject.cssURL.path)
            ? try String(contentsOf: target.loadedProject.cssURL, encoding: .utf8)
            : nil
        var result = try setRelatedStyleDeclaration(
            property,
            value: value,
            wrapperNodeID: resolvedNodeID(wrapperNodeID),
            htmlURL: target.htmlURL,
            activeMediaQueries: activeMediaQueries,
            projectCSSURL: target.loadedProject.cssURL,
            projectCSS: projectCSS,
            allowedRootURL: target.loadedProject.rootURL
        )
        guard !result.diagnostics.contains(where: { $0.severity == .error }) else { return result }
        let graph = try pageGraph(
            projectURL: projectURL,
            pageID: pageID,
            activeMediaQueries: activeMediaQueries
        )
        result.node = graph.nodes.first { $0.internalID == resolvedNodeID(wrapperNodeID) }
        result.diagnostics = graph.diagnostics
        return result
    }

    /// 論理名（日本語）: 解決済みCSS target保存関数
    /// 処理概要: full cascade provenanceに従いinline/companion winnerを最小差分更新し、read-only sourceは同scopeのwinning companion overrideだけを許可します。
    ///
    /// - Parameters:
    ///   - property: 正規化済み標準CSS property。
    ///   - value: CSS値。空の場合はwinner declarationを削除。
    ///   - nodeID: 結果で返すannotation付きnodeのinternal ID。
    ///   - htmlURL: HTMLファイルURL。
    ///   - html: 更新前HTML source。
    ///   - document: 更新前HTML文書。
    ///   - target: source cascadeと保存先selectorを解決済みのtarget。
    ///   - companionCSS: 更新前companion CSS。
    ///   - fallbackNode: 書き込み前のnode表現。
    ///   - activeMediaQueries: winner解決に使った標準`@media`条件。
    ///   - stylesheetResolution: source identity/orderと完全性を確定済みのstylesheet集合。
    ///   - projectCSSURL: project文脈のread-only cssLibrary URL。
    ///   - projectCSS: 読込済みproject cssLibrary source。
    ///   - allowedRootURL: local stylesheet読込許可root。
    ///   - relatedTargetKind: wrapper配下targetの場合の`media`/`svg`/`mask`種別。
    /// - Returns: 更新後nodeとdiagnosticsを含む編集結果。
    private func persistResolvedStyleDeclaration(
        _ property: String,
        value: String,
        nodeID: String,
        htmlURL: URL,
        html: String,
        document: OpenGraphiteHTMLDocument,
        target: OpenGraphiteHTMLRenderingTarget,
        companionCSS: OpenGraphiteCompanionCSSDocument,
        fallbackNode: OpenGraphiteAgentNode,
        activeMediaQueries: [String] = [],
        stylesheetResolution: OpenGraphiteHTMLStylesheetResolution,
        projectCSSURL: URL? = nil,
        projectCSS: String? = nil,
        allowedRootURL: URL? = nil,
        relatedTargetKind: String? = nil
    ) throws -> OpenGraphiteEditResult {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let winner = target.winnerProvenance[property]
        if !normalizedValue.isEmpty,
           (target.value.resolvedValues[property] ?? target.value.authoredValues[property])?
            .trimmingCharacters(in: .whitespacesAndNewlines) == normalizedValue {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: fallbackNode,
                diagnostics: [],
                insertedNodes: nil
            )
        }

        var candidateHTML = html
        var candidateCompanionCSS = companionCSS
        var mutationDiagnostics: [OpenGraphiteDiagnostic] = []
        let isDirectWinner = winner?.authoredProperty == property
        if winner?.sourceKind == "inline", isDirectWinner {
            let mutation = document.settingInlineRenderingStyleProperty(
                property,
                value: normalizedValue,
                target: target
            )
            mutationDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) }
            guard !mutationDiagnostics.contains(where: { $0.severity == .error }) else {
                return OpenGraphiteEditResult(
                    schemaVersion: Self.schemaVersion,
                    updated: false,
                    path: htmlURL.path,
                    node: fallbackNode,
                    diagnostics: mutationDiagnostics,
                    insertedNodes: nil
                )
            }
            candidateHTML = mutation.html
        } else if winner?.sourceKind == "companion",
                  winner?.sourceEditable == true,
                  isDirectWinner,
                  let winner {
            let sourceDocument = OpenGraphiteCSSSourceDocument.parse(companionCSS.css)
            candidateCompanionCSS.css = sourceDocument.setting(
                property: property,
                value: normalizedValue,
                provenance: winner,
                fallbackSelector: target.value.writeSelector
            )
        } else if normalizedValue.isEmpty {
            if winner == nil {
                return OpenGraphiteEditResult(
                    schemaVersion: Self.schemaVersion,
                    updated: false,
                    path: htmlURL.path,
                    node: fallbackNode,
                    diagnostics: [],
                    insertedNodes: nil
                )
            }
            let diagnosticCode = isDirectWinner
                ? "read-only-css-winner"
                : "shorthand-css-removal-unsupported"
            let diagnosticMessage = isDirectWinner
                ? "\(property) のwinnerはread-only \(winner?.sourceKind ?? "source")にあるため、project/linked sourceを変更せず削除できません。"
                : "\(property) は\(winner?.authoredProperty ?? "shorthand")から解決されており、他subpropertyを保持した安全な削除を断定できません。"
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: fallbackNode,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: diagnosticCode,
                        message: diagnosticMessage,
                        path: htmlURL.path,
                        nodeID: nodeID
                    )
                ],
                insertedNodes: nil
            )
        } else {
            guard let selector = winningOverrideSelector(
                baseSelector: target.value.writeSelector,
                winnerSpecificity: winner?.specificity
            ) else {
                return OpenGraphiteEditResult(
                    schemaVersion: Self.schemaVersion,
                    updated: false,
                    path: htmlURL.path,
                    node: fallbackNode,
                    diagnostics: [
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "css-specificity-override-unsafe",
                            message: "\(property) の既存winnerを安全なnode-scoped selectorで上書きできません。",
                            path: htmlURL.path,
                            nodeID: nodeID
                        )
                    ],
                    insertedNodes: nil
                )
            }
            let sourceDocument = OpenGraphiteCSSSourceDocument.parse(companionCSS.css)
            candidateCompanionCSS.css = sourceDocument.setting(
                property: property,
                value: normalizedValue,
                provenance: nil,
                fallbackSelector: selector,
                fallbackAtRules: winner?.atRules,
                important: winner?.declaration.important == true
            )
        }

        let didChangeHTML = candidateHTML != html
        let didChangeCSS = candidateCompanionCSS.css != companionCSS.css
        guard didChangeHTML || didChangeCSS else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: fallbackNode,
                diagnostics: mutationDiagnostics,
                insertedNodes: nil
            )
        }

        let candidateDocument = OpenGraphiteHTMLDocument(html: candidateHTML)
        let candidateResolution = candidateDocument.stylesheetResolution(
            documentURL: htmlURL,
            allowedRootURL: allowedRootURL,
            projectCSSURL: projectCSSURL,
            projectCSS: projectCSS,
            companionCSS: candidateCompanionCSS
        )
        guard !candidateResolution.hasIncompleteProvenance else {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: fallbackNode,
                nodeID: nodeID,
                diagnostics: candidateResolution.diagnostics
            )
        }
        let candidateTarget = resolvedStyleTarget(
            in: candidateDocument,
            nodeID: nodeID,
            property: property,
            relatedTargetKind: relatedTargetKind,
            stylesheetSources: candidateResolution.sources,
            activeMediaQueries: activeMediaQueries
        )
        if candidateTarget?.hasIncompleteCSSProvenance == true {
            return incompleteCSSMutationResult(
                path: htmlURL.path,
                node: fallbackNode,
                nodeID: nodeID,
                diagnostics: [
                    incompleteCSSNodeDiagnostic(
                        property: property,
                        path: htmlURL.path,
                        nodeID: nodeID
                    )
                ]
            )
        }
        if !normalizedValue.isEmpty {
            guard let candidateWinner = candidateTarget?.winnerProvenance[property],
                  candidateWinner.authoredProperty == property,
                  candidateWinner.declaration.value
                    .trimmingCharacters(in: .whitespacesAndNewlines) == normalizedValue,
                  candidateWinner.sourceKind == "companion" || candidateWinner.sourceKind == "inline"
            else {
                return OpenGraphiteEditResult(
                    schemaVersion: Self.schemaVersion,
                    updated: false,
                    path: htmlURL.path,
                    node: fallbackNode,
                    diagnostics: [
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "css-mutation-postcondition-failed",
                            message: "\(property) のcandidate winnerが要求値にならなかったためsourceを書き込みません。",
                            path: htmlURL.path,
                            nodeID: nodeID
                        )
                    ],
                    insertedNodes: nil
                )
            }
        }
        let candidateNodes = candidateDocument.nodes(
            companionCSS: candidateCompanionCSS,
            projectCSS: projectCSS,
            stylesheetSources: candidateResolution.sources,
            hasIncompleteCSSProvenance: false,
            activeMediaQueries: activeMediaQueries,
            contract: contract,
            documentURL: htmlURL.standardizedFileURL.absoluteString
        )
        let candidateDiagnostics = mutationDiagnostics + validate(
            nodes: candidateNodes,
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            companionCSSExists: didChangeCSS || !companionCSS.css.isEmpty
        )
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: candidateNodes.first { $0.internalID == nodeID },
                diagnostics: candidateDiagnostics,
                insertedNodes: nil
            )
        }

        if didChangeHTML {
            try candidateHTML.write(to: htmlURL, atomically: true, encoding: .utf8)
        }
        if didChangeCSS {
            try candidateCompanionCSS.write(forHTMLURL: htmlURL)
        }
        let updatedGraph = try pageGraph(
            html: candidateHTML,
            at: htmlURL,
            projectCSS: projectCSS,
            projectCSSURL: projectCSSURL,
            allowedRootURL: allowedRootURL,
            activeMediaQueries: activeMediaQueries
        )
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: true,
            path: htmlURL.path,
            node: updatedGraph.nodes.first { $0.internalID == nodeID },
            diagnostics: updatedGraph.diagnostics,
            insertedNodes: nil
        )
    }

    /// Full cascadeからnode自身または関連実描画targetを同じmutation経路へ解決します。
    private func resolvedStyleTarget(
        in document: OpenGraphiteHTMLDocument,
        nodeID: String,
        property: String,
        relatedTargetKind: String?,
        stylesheetSources: [OpenGraphiteCSSStylesheetSource],
        activeMediaQueries: [String]
    ) -> OpenGraphiteHTMLRenderingTarget? {
        if let relatedTargetKind {
            return document.renderingTargets(
                forNodeID: nodeID,
                stylesheetSources: stylesheetSources,
                activeMediaQueries: activeMediaQueries
            ).first { $0.value.kind == relatedTargetKind }
        }
        return document.styleTarget(
            forNodeID: nodeID,
            properties: [property],
            stylesheetSources: stylesheetSources,
            activeMediaQueries: activeMediaQueries
        )
    }

    /// Read-only winnerより高いspecificityを持つnode-scoped companion selectorを生成します。
    private func winningOverrideSelector(
        baseSelector: String,
        winnerSpecificity: OpenGraphiteCSSSpecificity?
    ) -> String? {
        let normalized = baseSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard let winnerSpecificity else { return normalized }
        var selector = normalized
        for index in 0..<32 {
            if OpenGraphiteCSSSelector.specificity(of: selector) > winnerSpecificity {
                return selector
            }
            selector += ":is(#og-specificity-guard-\(index), \(normalized))"
        }
        return OpenGraphiteCSSSelector.specificity(of: selector) > winnerSpecificity
            ? selector
            : nil
    }

    /// Incomplete stylesheet provenanceに対する共通atomic no-write結果を返します。
    private func incompleteCSSMutationResult(
        path: String,
        node: OpenGraphiteAgentNode?,
        nodeID: String,
        diagnostics: [OpenGraphiteDiagnostic]
    ) -> OpenGraphiteEditResult {
        OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: path,
            node: node,
            diagnostics: diagnostics + [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "incomplete-css-provenance-write-blocked",
                    message: "stylesheet winner provenanceを完全に解決できないためCSS mutationを適用しません。",
                    path: path,
                    nodeID: nodeID
                )
            ],
            insertedNodes: nil
        )
    }

    /// Browserが破棄する標準CSS property値に対する共通atomic no-write結果を返します。
    private func invalidCSSPropertyValueResult(
        property: String,
        value: String,
        path: String,
        nodeID: String
    ) -> OpenGraphiteEditResult {
        OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: path,
            node: nil,
            diagnostics: [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "invalid-css-property-value",
                    message: "\(property): \(value) はbrowserが受理する標準CSS値ではありません。",
                    path: path,
                    nodeID: nodeID
                )
            ],
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: Capability不足mutation結果生成関数
    /// 処理概要: legacy type hintではなくinspection済みoperation capabilityが不足する場合にatomic no-write結果を返します。
    ///
    /// - Parameters:
    ///   - capability: mutationが要求するoperation capability。
    ///   - operation: diagnosticへ表示する操作名。
    ///   - path: 対象HTML path。
    ///   - node: capability判定対象node。
    /// - Returns: `unsupported-node-capability` errorを持つ未更新結果。
    private func unsupportedCapabilityResult(
        capability: OpenGraphiteNodeCapability,
        operation: String,
        path: String,
        node: OpenGraphiteAgentNode
    ) -> OpenGraphiteEditResult {
        OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: path,
            node: node,
            diagnostics: [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(operation)には\(capability.rawValue) capabilityが必要です。legacy data-og-type hintは権限根拠になりません。",
                    path: path,
                    nodeID: node.internalID.isEmpty ? node.id : node.internalID
                )
            ],
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: 代替Capability不足mutation結果生成関数
    /// 処理概要: 複数の代替operation capabilityを1つも持たないnodeへatomic no-write診断を返します。
    ///
    /// - Parameters:
    ///   - capabilities: mutationを許可する代替capability一覧。
    ///   - operation: diagnosticへ表示する操作名。
    ///   - path: 対象HTML path。
    ///   - node: capability判定対象node。
    /// - Returns: `unsupported-node-capability` errorを持つ未更新結果。
    private func unsupportedCapabilityResult(
        capabilities: [OpenGraphiteNodeCapability],
        operation: String,
        path: String,
        node: OpenGraphiteAgentNode
    ) -> OpenGraphiteEditResult {
        let required = capabilities.map(\.rawValue).sorted().joined(separator: "または")
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: path,
            node: node,
            diagnostics: [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(operation)には\(required) capabilityのいずれかが必要です。legacy data-og-type hintは権限根拠になりません。",
                    path: path,
                    nodeID: node.internalID.isEmpty ? node.id : node.internalID
                )
            ],
            insertedNodes: nil
        )
    }

    /// Node単位の時間依存・CSS-wide unresolved computed provenanceを説明する診断を返します。
    private func incompleteCSSNodeDiagnostic(
        property: String,
        path: String,
        nodeID: String
    ) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(
            severity: .warning,
            code: "incomplete-css-node-provenance",
            message: "\(property) の対象nodeは未評価conditional、animation、または未確定CSS-wide値を含み、headless winnerを断定できません。",
            path: path,
            nodeID: nodeID
        )
    }

    /// 論理名（日本語）: ノード属性ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node に許可済み属性を設定し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setAttribute(_ name: String, value: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingAttribute(
            name: name,
            value: value,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: normalizedNodeID,
            originalHTMLForNoOp: html
        )
    }

    /// 論理名（日本語）: ノード属性ファイル削除関数
    /// 処理概要: 空文字属性を保持するset操作と区別し、指定した永続属性tokenだけを削除します。
    ///
    /// - Parameters:
    ///   - name: 削除する属性名。
    ///   - nodeID: 対象`data-og-internal-id`。
    ///   - htmlURL: HTMLファイルURL。
    /// - Returns: 編集結果。
    func removeAttribute(_ name: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).removingAttribute(
            name: name,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: normalizedNodeID,
            originalHTMLForNoOp: html
        )
    }

    /// 論理名（日本語）: プロジェクトページ属性更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の編集可能属性を更新します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setAttribute(
        _ name: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setAttribute(name, value: value, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ属性削除関数
    /// 処理概要: `.ogp` resourceを解決し、対象nodeの許可済み属性tokenだけを削除します。
    ///
    /// - Parameters:
    ///   - name: 削除する属性名。
    ///   - nodeID: 対象`data-og-internal-id`。
    ///   - projectURL: `.ogp`ファイルURL。
    ///   - pageID: `.ogp`内のpage/component参照ID。
    /// - Returns: 編集結果。
    func removeAttribute(
        _ name: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try removeAttribute(name, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: アイコンファイル更新関数
    /// 処理概要: HTML ファイル内の icon node metadata と保存済み描画 HTML を更新します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide。
    ///   - name: icon name。空の場合は circle。
    ///   - source: icon source。空の場合は inline。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setIcon(
        library: String,
        name: String,
        source: String,
        nodeID: String,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let graph = try pageGraph(at: htmlURL)
        let matches = graph.nodes.filter { $0.internalID == normalizedNodeID }
        let nodeDiagnostics = uniqueNodeDiagnostics(matches: matches, id: normalizedNodeID, path: htmlURL.path)
        guard nodeDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: nodeDiagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.editIcon),
              matches[0].attributes.keys.contains(where: {
                  ["data-og-icon-library", "data-og-icon-name", "data-og-icon-source"].contains($0.lowercased())
              })
        else {
            return unsupportedCapabilityResult(
                capability: .editIcon,
                operation: "icon metadata/content edit",
                path: htmlURL.path,
                node: matches[0]
            )
        }
        let originalDocument = OpenGraphiteHTMLDocument(html: html)
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let previousCSS = companionCSS.css
        removeRelatedStyleDeclarations(
            ["mask-image", "-webkit-mask-image"],
            wrapperNodeID: normalizedNodeID,
            document: originalDocument,
            companionCSS: &companionCSS
        )
        let mutation = OpenGraphiteHTMLDocument(html: html).settingIcon(
            library: library,
            name: name,
            source: source,
            forNodeID: normalizedNodeID,
            contract: contract,
            capabilityConfirmed: true
        )
        let result = try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
        guard !result.diagnostics.contains(where: { $0.severity == .error }) else {
            return result
        }
        let cleanupChanged = companionCSS.css != previousCSS
        if cleanupChanged {
            try companionCSS.write(forHTMLURL: htmlURL)
        }
        let declarations = OpenGraphiteIconMarkup.renderingStyleDeclarations(
            library: result.node?.attributes["data-og-icon-library"] ?? library,
            name: result.node?.attributes["data-og-icon-name"] ?? name,
            source: result.node?.attributes["data-og-icon-source"] ?? source
        )
        return try persistRelatedStyleDeclarations(
            declarations,
            wrapperNodeID: normalizedNodeID,
            htmlURL: htmlURL,
            baseResult: OpenGraphiteEditResult(
                schemaVersion: result.schemaVersion,
                updated: result.updated || cleanupChanged,
                path: result.path,
                node: result.node,
                diagnostics: result.diagnostics,
                insertedNodes: result.insertedNodes
            )
        )
    }

    /// 論理名（日本語）: プロジェクトページアイコン更新関数
    /// 処理概要: `.ogp` の page 参照 ID で明示された HTML 内 icon node を更新します。
    ///
    /// - Parameters:
    ///   - library: icon library。
    ///   - name: icon name。
    ///   - source: icon source。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setIcon(
        library: String,
        name: String,
        source: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setIcon(library: library, name: name, source: source, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: テキスト内容ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の text content を更新し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。HTML としてではなく text として escape されます。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setTextContent(_ text: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingTextContent(
            text,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページテキスト更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の text content を更新します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setTextContent(
        _ text: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setTextContent(text, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: テキストvariantファイル更新関数
    /// 処理概要: HTML ファイル内の `data-i18n-key` に一致する text binding へ locale variant を保存します。
    ///
    /// - Parameters:
    ///   - text: 保存する variant HTML。空文字も有効な値として保持されます。
    ///   - locale: variant の locale 名。
    ///   - i18nKey: 対象 `data-i18n-key`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setTextVariant(_ text: String, locale: String, i18nKey: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingTextVariant(
            text,
            locale: locale,
            i18nKey: i18nKey,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: "")
    }

    /// 論理名（日本語）: プロジェクトページテキストvariant更新関数
    /// 処理概要: `.ogp` の page 参照 ID で明示された HTML 内の text binding variant を更新します。
    ///
    /// - Parameters:
    ///   - text: 保存する variant HTML。空文字も有効な値として保持されます。
    ///   - locale: variant の locale 名。
    ///   - i18nKey: 対象 `data-i18n-key`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setTextVariant(
        _ text: String,
        locale: String,
        i18nKey: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try setTextVariant(text, locale: locale, i18nKey: i18nKey, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: アイコンHTML挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の anchor node を基準に icon node を挿入します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide。
    ///   - name: icon name。空の場合は circle。
    ///   - source: icon source。空の場合は inline。
    ///   - iconID: 新規 icon の `data-og-id`。`nil` の場合は icon name から一意化します。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - width: `width`。`nil` の場合は 24px。
    ///   - height: `height`。`nil` の場合は 24px。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func insertIcon(
        library: String,
        name: String,
        source: String,
        iconID: String?,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        width: String?,
        height: String?,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let resolvedAnchorNodeID = resolvedNodeID(anchorNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let existingIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let displayID: String
        if let explicitIconID = iconID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitIconID.isEmpty {
            displayID = explicitIconID
        } else {
            displayID = uniqueDisplayID(base: OpenGraphiteIconMarkup.defaultDisplayIDBase(name: name), existingIDs: existingIDs)
        }
        let iconInternalID = uniqueInternalID(existingIDs: Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.internalID)))
        let icon = OpenGraphiteIconMarkup.elementHTML(
            id: displayID,
            internalID: iconInternalID,
            library: library,
            name: name,
            source: source,
            width: width ?? "24px",
            height: height ?? "24px",
            nodeID: displayID
        )
        guard icon.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: icon.diagnostics.map { withPath($0, path: htmlURL.path) },
                insertedNodes: nil
            )
        }

        let beforeIDs = existingIDs
        let mutation = OpenGraphiteHTMLDocument(html: html).insertingHTML(
            icon.html,
            relativeToNodeID: resolvedAnchorNodeID,
            position: position,
            contract: contract
        )
        let result = try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: resolvedAnchorNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
        guard !result.diagnostics.contains(where: { $0.severity == .error }) else {
            return result
        }
        let declarations = OpenGraphiteIconMarkup.renderingStyleDeclarations(
            library: icon.library,
            name: icon.name,
            source: icon.source
        )
        let sizedResult = try persistWrapperStyleDeclarations(
            ["width": width ?? "24px", "height": height ?? "24px"],
            nodeID: iconInternalID,
            htmlURL: htmlURL,
            baseResult: result
        )
        return try persistRelatedStyleDeclarations(
            declarations,
            wrapperNodeID: iconInternalID,
            htmlURL: htmlURL,
            baseResult: sizedResult
        )
    }

    /// 論理名（日本語）: プロジェクトページアイコン挿入関数
    /// 処理概要: `.ogp` の page 参照 ID で明示された HTML へ icon node を挿入します。
    ///
    /// - Parameters:
    ///   - library: icon library。
    ///   - name: icon name。
    ///   - source: icon source。
    ///   - iconID: 新規 icon の `data-og-id`。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - width: `width`。
    ///   - height: `height`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func insertIcon(
        library: String,
        name: String,
        source: String,
        iconID: String?,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        width: String?,
        height: String?,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [anchorNodeID])
        return try insertIcon(
            library: library,
            name: name,
            source: source,
            iconID: iconID,
            anchorNodeID: resolvedNodeID(anchorNodeID),
            position: position,
            width: width,
            height: height,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: HTML断片挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の anchor node を基準に HTML 断片を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let resolvedAnchorNodeID = resolvedNodeID(anchorNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).insertingHTML(
            fragmentHTML,
            relativeToNodeID: resolvedAnchorNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: resolvedAnchorNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs,
            migrateInlineDesignValues: true
        )
    }

    /// 論理名（日本語）: プロジェクトページHTML挿入関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML に対して anchor node 基準で HTML 断片を挿入します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [anchorNodeID])
        return try insertHTML(fragmentHTML, anchorNodeID: resolvedNodeID(anchorNodeID), position: position, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: 子HTML先頭挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の先頭へ子 HTML を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func prependChildHTML(_ childHTML: String, parentNodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, htmlURL: htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ子HTML先頭挿入関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の先頭へ子 HTML を挿入します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func prependChildHTML(
        _ childHTML: String,
        parentNodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, projectURL: projectURL, pageID: pageID)
    }

    /// 論理名（日本語）: ノードHTML置換ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node 全体を HTML 断片で置換し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func replaceNodeHTML(_ replacementHTML: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).replacingNodeHTML(
            replacementHTML,
            nodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: normalizedNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノードHTML置換関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を HTML 断片で置換します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func replaceNodeHTML(
        _ replacementHTML: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try replaceNodeHTML(replacementHTML, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード削除ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node subtree を削除し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).deletingNode(
            nodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード削除関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を削除します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, projectURL: URL, pageID: String) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try deleteNode(nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード移動ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を別 node 基準位置へ移動し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-internal-id`。
    ///   - targetNodeID: 移動先基準 `data-og-internal-id`。
    ///   - position: 移動先位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedTargetNodeID = resolvedNodeID(targetNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).movingNode(
            nodeID: normalizedNodeID,
            relativeToNodeID: normalizedTargetNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード移動関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を移動します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-internal-id`。
    ///   - targetNodeID: 移動先基準 `data-og-internal-id`。
    ///   - position: 移動先位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID, targetNodeID])
        let normalizedNodeID = resolvedNodeID(nodeID)
        let graph = try pageGraph(projectURL: projectURL, pageID: pageID)
        let matches = graph.nodes.filter { $0.internalID == normalizedNodeID }
        let diagnostics = uniqueNodeDiagnostics(matches: matches, id: normalizedNodeID, path: target.htmlURL.path)
        guard diagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: target.htmlURL.path,
                node: nil,
                diagnostics: diagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.dragPosition) || matches[0].supports(.reorderFlow) else {
            return unsupportedCapabilityResult(
                capabilities: [.dragPosition, .reorderFlow],
                operation: "node move",
                path: target.htmlURL.path,
                node: matches[0]
            )
        }
        return try moveNode(
            nodeID: normalizedNodeID,
            targetNodeID: resolvedNodeID(targetNodeID),
            position: position,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: ノード複製ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を `data-og-id` prefix 付きで複製し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-internal-id`。
    ///   - targetNodeID: 複製先基準 `data-og-internal-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedTargetNodeID = resolvedNodeID(targetNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).copyingNode(
            nodeID: normalizedNodeID,
            relativeToNodeID: normalizedTargetNodeID,
            position: position,
            idPrefix: idPrefix,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: "\(idPrefix)\(normalizedNodeID)",
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノード複製関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を prefix 付きで複製します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-internal-id`。
    ///   - targetNodeID: 複製先基準 `data-og-internal-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID, targetNodeID])
        let normalizedNodeID = resolvedNodeID(nodeID)
        let graph = try pageGraph(projectURL: projectURL, pageID: pageID)
        let matches = graph.nodes.filter { $0.internalID == normalizedNodeID }
        let diagnostics = uniqueNodeDiagnostics(matches: matches, id: normalizedNodeID, path: target.htmlURL.path)
        guard diagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: target.htmlURL.path,
                node: nil,
                diagnostics: diagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.group) else {
            return unsupportedCapabilityResult(
                capability: .group,
                operation: "node copy",
                path: target.htmlURL.path,
                node: matches[0]
            )
        }
        return try copyNode(
            nodeID: normalizedNodeID,
            targetNodeID: resolvedNodeID(targetNodeID),
            position: position,
            idPrefix: idPrefix,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: i18n runtime内部検査関数
    /// 処理概要: 解決済み page target から HTML と script / module import を読み、i18n 設定と resource 状態を構成します。
    private func inspectI18n(
        target: OpenGraphiteProjectPageTarget,
        locales: [String]
    ) throws -> OpenGraphiteI18nRuntimeInspection {
        let requestedLocales = normalizedLocales(locales.isEmpty ? ["ja", "eng"] : locales)
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        let htmlDocument = OpenGraphiteHTMLDocument(html: html)
        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let scriptSources = try i18nScriptSources(
            htmlDocument: htmlDocument,
            pageURL: target.htmlURL,
            htmlRootURL: htmlRootURL
        )
        let detected = detectedI18nConfig(in: scriptSources)
        let localeField = detected.localeField
            ?? htmlDocument.htmlDocumentContext().langField.nonEmptyTrimmed
            ?? target.page.canvas.previewContext.fieldMocks.keys.sorted().first(where: { $0 == "selectedLanguage" })
        let resourceLoadPath = detected.loadPath.value ?? Self.recommendedI18nLoadPath
        let configURL = detected.configSource.map { URL(fileURLWithPath: $0) }
        let resourceEditable = detected.loadPath.source != .external
        let discoveredLocales = resourceEditable
            ? discoveredLocaleResourceLocales(
                loadPath: resourceLoadPath,
                htmlRootURL: htmlRootURL,
                pageURL: target.htmlURL,
                configURL: configURL
            )
            : []
        let localeCandidates = normalizedLocales(
            requestedLocales + discoveredLocales
        )
        let resources = localeCandidates.map { locale in
            let resourceURL = localeResourceURL(
                loadPath: resourceLoadPath,
                locale: locale,
                htmlRootURL: htmlRootURL,
                pageURL: target.htmlURL,
                configURL: configURL
            )
            return OpenGraphiteI18nResourceStatus(
                locale: locale,
                path: resourceURL.path,
                exists: FileManager.default.fileExists(atPath: resourceURL.path),
                editable: resourceEditable
            )
        }

        let diagnostics: [OpenGraphiteDiagnostic]
        if detected.adapter == .unknown {
            diagnostics = [
                OpenGraphiteDiagnostic(
                    severity: .info,
                    code: "missing-i18n-runtime",
                    message: "i18n.init({...}) を検出できませんでした。推奨設定を作成できます。",
                    path: target.htmlURL.path,
                    nodeID: nil
                )
            ]
        } else if detected.loadPath.source == .external {
            diagnostics = [
                OpenGraphiteDiagnostic(
                    severity: .info,
                    code: "external-i18n-load-path",
                    message: "backend.loadPath は external / readonly です。OpenGraphite は動的式を自動で書き換えません。",
                    path: detected.configSource,
                    nodeID: nil
                )
            ]
        } else {
            diagnostics = []
        }

        return OpenGraphiteI18nRuntimeInspection(
            schemaVersion: Self.schemaVersion,
            pageURL: target.htmlURL.path,
            adapter: detected.adapter,
            configSource: detected.configSource,
            lng: detected.lng,
            fallbackLng: detected.fallbackLng,
            loadPath: detected.loadPath,
            localeField: localeField,
            resources: resources,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: i18n script source収集関数
    /// 処理概要: HTML script と辿れる module import を読み、i18n 設定検出の入力へ変換します。
    private func i18nScriptSources(
        htmlDocument: OpenGraphiteHTMLDocument,
        pageURL: URL,
        htmlRootURL: URL
    ) throws -> [OpenGraphiteI18nScriptSource] {
        var sources: [OpenGraphiteI18nScriptSource] = []
        var visited = Set<String>()

        func appendExternalScript(_ url: URL, depth: Int) throws {
            guard depth <= 12 else { return }
            let standardized = url.standardizedFileURL
            let key = standardized.path
            guard !visited.contains(key) else { return }
            visited.insert(key)
            guard FileManager.default.fileExists(atPath: standardized.path) else { return }
            let source = try String(contentsOf: standardized, encoding: .utf8)
            sources.append(
                OpenGraphiteI18nScriptSource(
                    url: standardized,
                    displayPath: standardized.path,
                    source: source,
                    isInline: false
                )
            )
            for specifier in Self.importSpecifiers(in: source) {
                guard let importURL = Self.resolvedImplementationURL(
                    specifier,
                    relativeTo: standardized,
                    htmlRootURL: htmlRootURL
                ) else {
                    continue
                }
                try appendExternalScript(importURL, depth: depth + 1)
            }
        }

        for script in htmlDocument.scriptReferences() {
            if let src = script.src,
               let scriptURL = Self.resolvedImplementationURL(src, relativeTo: pageURL, htmlRootURL: htmlRootURL) {
                try appendExternalScript(scriptURL, depth: 0)
            } else if !script.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sources.append(
                    OpenGraphiteI18nScriptSource(
                        url: pageURL,
                        displayPath: "\(pageURL.path)#inline-script",
                        source: script.content,
                        isInline: true
                    )
                )
            }
        }

        return sources
    }

    /// 論理名（日本語）: i18n config検出関数
    /// 処理概要: script source 内の `i18n.init({...})` から検出対象 literal / external 値を抽出します。
    private func detectedI18nConfig(
        in sources: [OpenGraphiteI18nScriptSource]
    ) -> (
        adapter: OpenGraphiteI18nAdapter,
        configSource: String?,
        lng: OpenGraphiteI18nConfigProperty,
        fallbackLng: OpenGraphiteI18nConfigProperty,
        loadPath: OpenGraphiteI18nConfigProperty,
        localeField: String?
    ) {
        for source in sources {
            guard let objectSource = Self.i18nInitObjectSource(in: source.source) else { continue }
            let lngExpression = Self.objectPropertyExpression(named: "lng", in: objectSource)
            let fallbackExpression = Self.objectPropertyExpression(named: "fallbackLng", in: objectSource)
            let loadPathExpression = Self.objectPropertyExpression(named: "loadPath", in: objectSource)
            return (
                adapter: .i18next,
                configSource: source.displayPath,
                lng: Self.configProperty(from: lngExpression),
                fallbackLng: Self.configProperty(from: fallbackExpression),
                loadPath: Self.configProperty(from: loadPathExpression),
                localeField: Self.localeFieldName(from: lngExpression)
            )
        }

        return (
            adapter: .unknown,
            configSource: nil,
            lng: Self.missingI18nConfigProperty(),
            fallbackLng: Self.missingI18nConfigProperty(),
            loadPath: Self.missingI18nConfigProperty(),
            localeField: nil
        )
    }

    /// 論理名（日本語）: locale resource URL解決関数
    /// 処理概要: literal loadPath または推奨 loadPath から locale JSON の file URL を求めます。
    private func localeResourceURL(
        loadPath: String,
        locale: String,
        htmlRootURL: URL,
        pageURL: URL,
        configURL: URL?
    ) -> URL {
        var path = loadPath
            .replacingOccurrences(of: "{{lng}}", with: locale)
            .replacingOccurrences(of: "{{locale}}", with: locale)
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        if path.hasPrefix("/") {
            return htmlRootURL
                .appendingPathComponent(String(path.dropFirst()))
                .standardizedFileURL
        }
        let baseURL = configURL?.deletingLastPathComponent() ?? pageURL.deletingLastPathComponent()
        return baseURL.appendingPathComponent(path).standardizedFileURL
    }

    /// 論理名（日本語）: locale resource候補検出関数
    /// 処理概要: literal loadPath の placeholder 位置から、実在する locale JSON の locale 名を逆算します。
    ///
    /// - Parameters:
    ///   - loadPath: i18n backend.loadPath。
    ///   - htmlRootURL: HTML root URL。
    ///   - pageURL: 対象 HTML URL。
    ///   - configURL: i18n config を検出した file URL。
    /// - Returns: loadPath から参照できる locale 名一覧。
    private func discoveredLocaleResourceLocales(
        loadPath: String,
        htmlRootURL: URL,
        pageURL: URL,
        configURL: URL?
    ) -> [String] {
        guard loadPath.contains("{{lng}}") || loadPath.contains("{{locale}}") else {
            return []
        }

        let sentinel = "__OPENGRAPHITE_LOCALE__"
        let templateURL = localeResourceURL(
            loadPath: loadPath,
            locale: sentinel,
            htmlRootURL: htmlRootURL,
            pageURL: pageURL,
            configURL: configURL
        )
        let components = templateURL.standardizedFileURL.pathComponents
        guard let templateIndex = components.firstIndex(where: { $0.contains(sentinel) }) else {
            return []
        }

        let baseURL = Self.fileURL(fromPathComponents: Array(components.prefix(templateIndex)))
        let templateComponent = components[templateIndex]
        let suffixComponents = Array(components.dropFirst(templateIndex + 1))
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let discovered = entries.compactMap { entry -> String? in
            guard let locale = Self.localeName(from: entry.lastPathComponent, template: templateComponent, sentinel: sentinel) else {
                return nil
            }
            var candidateURL = baseURL.appendingPathComponent(
                templateComponent.replacingOccurrences(of: sentinel, with: locale)
            )
            for component in suffixComponents {
                candidateURL.appendPathComponent(component)
            }
            guard FileManager.default.fileExists(atPath: candidateURL.path) else {
                return nil
            }
            return locale
        }
        return normalizedLocales(discovered)
    }

    /// 論理名（日本語）: path component URL生成関数
    /// 処理概要: `URL.pathComponents` 由来の component 配列から file URL を復元します。
    ///
    /// - Parameter components: path component 配列。
    /// - Returns: 復元した file URL。
    private static func fileURL(fromPathComponents components: [String]) -> URL {
        guard !components.isEmpty else {
            return URL(fileURLWithPath: "/")
        }
        if components.first == "/" {
            let path = "/" + components.dropFirst().joined(separator: "/")
            return URL(fileURLWithPath: path.isEmpty ? "/" : path)
        }
        return URL(fileURLWithPath: components.joined(separator: "/"))
    }

    /// 論理名（日本語）: locale component逆算関数
    /// 処理概要: sentinel を含む template component と実在 component から locale 名を取り出します。
    ///
    /// - Parameters:
    ///   - component: 実在する path component。
    ///   - template: sentinel を含む path component template。
    ///   - sentinel: locale placeholder 代替文字列。
    /// - Returns: 抽出できた locale 名。
    private static func localeName(from component: String, template: String, sentinel: String) -> String? {
        let parts = template.components(separatedBy: sentinel)
        guard parts.count == 2 else { return nil }
        let prefix = parts[0]
        let suffix = parts[1]
        guard component.hasPrefix(prefix), component.hasSuffix(suffix) else {
            return nil
        }
        let start = component.index(component.startIndex, offsetBy: prefix.count)
        let end = component.index(component.endIndex, offsetBy: -suffix.count)
        guard start <= end else { return nil }
        let locale = String(component[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return locale.isEmpty ? nil : locale
    }

    /// 論理名（日本語）: locale resource merge関数
    /// 処理概要: HTML fallback と同梱 variant から flat key JSON を作成・追記します。
    private func mergeLocaleResource(
        at url: URL,
        locale: String,
        bindings: [OpenGraphiteHTMLTextBindingResource],
        fallbackLocale: String
    ) throws -> Bool {
        var resource = try readLocaleResource(at: url)
        let before = resource
        for binding in bindings {
            if resource[binding.key] != nil {
                continue
            }
            if locale == fallbackLocale {
                resource[binding.key] = binding.fallbackHTML
            } else if let variant = Self.variantValue(for: locale, in: binding.variants) {
                resource[binding.key] = variant
            } else {
                resource[binding.key] = binding.fallbackHTML
            }
        }
        guard resource as NSDictionary != before as NSDictionary else {
            return false
        }
        try writeLocaleResource(resource, to: url)
        return true
    }

    /// 論理名（日本語）: locale resource読込関数
    /// 処理概要: flat key JSON を辞書として読み、存在しない場合は空辞書を返します。
    private func readLocaleResource(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenGraphiteAgentCoreError(message: "locale JSON は object である必要があります: \(url.path)")
        }
        return dictionary
    }

    /// 論理名（日本語）: locale resource保存関数
    /// 処理概要: flat key JSON を pretty / sorted 形式で実装資源へ保存します。
    private func writeLocaleResource(_ resource: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: resource, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        var output = data
        output.append(0x0A)
        try output.write(to: url, options: .atomic)
    }

    private func fallbackLocale(from inspection: OpenGraphiteI18nRuntimeInspection) -> String? {
        inspection.fallbackLng.value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyTrimmed
    }

    private func normalizedLocales(_ locales: [String]) -> [String] {
        var result: [String] = []
        for locale in locales {
            let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedLocale.isEmpty, !result.contains(normalizedLocale) else { continue }
            result.append(normalizedLocale)
        }
        return result
    }

    private static let recommendedI18nLoadPath = "/locales/{{lng}}.json"

    private static let recommendedI18nRuntimeSource = """
    const fallbackLocale = "ja";
    const fallbackHTMLByElement = new WeakMap();
    const translatedElements = new Set();

    function fallbackHTMLFor(element) {
      if (!fallbackHTMLByElement.has(element)) {
        fallbackHTMLByElement.set(element, element.innerHTML);
        translatedElements.add(element);
      }
      return fallbackHTMLByElement.get(element) || "";
    }

    function setFallbackHTML(element, html) {
      fallbackHTMLByElement.set(element, String(html || ""));
      translatedElements.add(element);
    }

    function suspendTranslations() {
      const states = [];
      translatedElements.forEach((element) => {
        if (!element.isConnected) { return; }
        states.push({ element, runtimeHTML: element.innerHTML });
        element.innerHTML = fallbackHTMLFor(element);
      });
      return states;
    }

    function resumeTranslations(states) {
      (Array.isArray(states) ? states : []).forEach((state) => {
        if (state.element && state.element.isConnected) {
          state.element.innerHTML = state.runtimeHTML;
        }
      });
    }

    function previewField(name) {
      const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {};
      const fields = context.fields || {};
      if (!Object.prototype.hasOwnProperty.call(fields, name)) {
        return { found: false, value: "" };
      }
      return { found: true, value: String(fields[name]) };
    }

    function selectedLanguage() {
      const mock = previewField("selectedLanguage");
      if (mock.found) { return mock.value; }
      return document.documentElement.lang || fallbackLocale;
    }

    const i18n = window.i18n || {
      init(config) {
        window.__OPENGRAPHITE_I18N_CONFIG__ = config;
        return config;
      }
    };

    const runtimeConfig = i18n.init({
      lng: selectedLanguage(),
      fallbackLng: "ja",
      backend: {
        loadPath: "/locales/{{lng}}.json"
      }
    });

    function resolvedLoadPath(language) {
      return runtimeConfig.backend.loadPath.replace("{{lng}}", language);
    }

    function resolvedLocaleURL(language) {
      const path = resolvedLoadPath(language);
      if (document.location.protocol === "file:" && path.startsWith("/")) {
        return new URL(`.${path}`, document.baseURI);
      }
      return new URL(path, document.baseURI);
    }

    async function loadLocale(language) {
      const url = resolvedLocaleURL(language);
      try {
        const response = await fetch(url.href);
        if (response.ok) { return await response.json(); }
      } catch (_) {}
      return await new Promise((resolve) => {
        const request = new XMLHttpRequest();
        request.open("GET", url.href, true);
        request.onload = () => {
          if ((request.status >= 200 && request.status < 300) || request.status === 0) {
            try { resolve(JSON.parse(request.responseText)); } catch (_) { resolve({}); }
          } else {
            resolve({});
          }
        };
        request.onerror = () => resolve({});
        request.send();
      });
    }

    function elementsIncludingTemplateContent(root) {
      const elements = [];
      function visit(node) {
        if (!node) { return; }
        if (node.nodeType === Node.ELEMENT_NODE) {
          elements.push(node);
          if (node.tagName && node.tagName.toLowerCase() === "template") {
            Array.from(node.content.childNodes).forEach(visit);
          }
        }
        Array.from(node.childNodes || []).forEach(visit);
      }
      visit(root);
      return elements;
    }

    function textVariantAttributeForLocale(locale) {
      const normalizedLocale = String(locale || "").trim().toLowerCase().replace(/_/g, "-");
      if (!/^[a-z0-9-]+$/.test(normalizedLocale)) {
        return "";
      }
      if (normalizedLocale.split("-")[0] === "en") {
        return "data-og-text-variant-eng";
      }
      return `data-og-text-variant-${normalizedLocale}`;
    }

    async function applyI18n() {
      const language = selectedLanguage();
      const resources = await loadLocale(language);
      const variantAttribute = textVariantAttributeForLocale(language);
      document.documentElement.lang = language || fallbackLocale;
      elementsIncludingTemplateContent(document.documentElement).forEach((element) => {
        const key = element.getAttribute("data-i18n-key");
        if (!key) { return; }
        const fallbackHTML = fallbackHTMLFor(element);
        const variantHTML = variantAttribute ? element.getAttribute(variantAttribute) : null;
        const value = Object.prototype.hasOwnProperty.call(resources, key) ? resources[key] : variantHTML !== null ? variantHTML : fallbackHTML;
        element.innerHTML = typeof value === "string" ? value : fallbackHTML;
      });
    }

    window.OpenGraphiteI18n = {
      apply: applyI18n,
      fallbackHTMLFor,
      setFallbackHTML,
      suspend: suspendTranslations,
      resume: resumeTranslations
    };

    document.addEventListener("DOMContentLoaded", () => { applyI18n(); });
    document.addEventListener("opengraphite:components-ready", () => { applyI18n(); });
    """

    private static func insertingRecommendedI18nScriptIfNeeded(in html: String, scriptPath: String) -> String {
        let document = OpenGraphiteHTMLDocument(html: html)
        let normalizedScriptPath = normalizedScriptReference(scriptPath)
        if document.scriptReferences().contains(where: { reference in
            guard let src = reference.src else { return false }
            return normalizedScriptReference(src) == normalizedScriptPath
        }) {
            return html
        }
        let source = normalizedScriptPath.hasPrefix(".") || normalizedScriptPath.hasPrefix("/")
            ? normalizedScriptPath
            : "./\(normalizedScriptPath)"
        let script = "    <script src=\"\(escapeAttribute(source))\" defer></script>\n"
        if let range = html.range(of: "</head>", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: script, at: range.lowerBound)
            return result
        }
        if let range = html.range(of: "<body", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: script, at: range.lowerBound)
            return result
        }
        return "\(script)\(html)"
    }

    private static func resolvedImplementationURL(
        _ specifier: String,
        relativeTo sourceURL: URL,
        htmlRootURL: URL
    ) -> URL? {
        let trimmed = specifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("http://"),
              !trimmed.hasPrefix("https://"),
              !trimmed.hasPrefix("data:"),
              !trimmed.hasPrefix("node:")
        else {
            return nil
        }

        let candidate: URL
        if trimmed.hasPrefix("/") {
            candidate = htmlRootURL.appendingPathComponent(String(trimmed.dropFirst()))
        } else if trimmed.hasPrefix("./") || trimmed.hasPrefix("../") {
            candidate = sourceURL.deletingLastPathComponent().appendingPathComponent(trimmed)
        } else {
            return nil
        }

        let standardized = candidate.standardizedFileURL
        if FileManager.default.fileExists(atPath: standardized.path) {
            return standardized
        }
        if standardized.pathExtension.isEmpty {
            for ext in ["js", "mjs", "ts"] {
                let withExtension = standardized.appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: withExtension.path) {
                    return withExtension.standardizedFileURL
                }
            }
        }
        return standardized
    }

    private static func importSpecifiers(in source: String) -> [String] {
        var specifiers: [String] = []
        var searchIndex = source.startIndex
        while let range = source.range(of: "import", range: searchIndex..<source.endIndex) {
            let before = range.lowerBound > source.startIndex ? source[source.index(before: range.lowerBound)] : " "
            let after = range.upperBound < source.endIndex ? source[range.upperBound] : " "
            guard !isIdentifierCharacter(before), !isIdentifierCharacter(after) else {
                searchIndex = range.upperBound
                continue
            }
            let statementEnd = source[range.upperBound...].firstIndex(of: ";") ?? source.endIndex
            let statement = String(source[range.upperBound..<statementEnd])
            if let direct = firstQuotedString(in: statement) {
                specifiers.append(direct)
            } else if let fromRange = statement.range(of: "from"),
                      let imported = firstQuotedString(in: String(statement[fromRange.upperBound...])) {
                specifiers.append(imported)
            }
            searchIndex = statementEnd
        }
        return specifiers
    }

    private static func i18nInitObjectSource(in source: String) -> String? {
        guard let range = i18nInitObjectRange(in: source) else { return nil }
        return String(source[range])
    }

    private static func i18nInitObjectRange(in source: String) -> Range<String.Index>? {
        guard let initRange = source.range(of: "i18n.init") else { return nil }
        guard let parenIndex = source[initRange.upperBound...].firstIndex(of: "(") else { return nil }
        guard let objectStart = source[parenIndex...].firstIndex(of: "{") else { return nil }
        guard let objectEnd = matchingDelimiterEnd(in: source, start: objectStart, open: "{", close: "}") else {
            return nil
        }
        return objectStart..<source.index(after: objectEnd)
    }

    private static func objectPropertyExpression(named name: String, in source: String) -> String? {
        guard let range = objectPropertyValueRange(named: name, in: source) else { return nil }
        return String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func objectPropertyValueRange(named name: String, in source: String) -> Range<String.Index>? {
        var index = source.startIndex
        var quote: Character?
        var isEscaped = false
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
                index = source.index(after: index)
                continue
            }
            if isIdentifierStart(character) {
                let nameStart = index
                while index < source.endIndex, isIdentifierCharacter(source[index]) {
                    index = source.index(after: index)
                }
                let identifier = String(source[nameStart..<index])
                guard identifier == name else { continue }
                var cursor = index
                while cursor < source.endIndex, source[cursor].isWhitespace {
                    cursor = source.index(after: cursor)
                }
                guard cursor < source.endIndex, source[cursor] == ":" else { continue }
                cursor = source.index(after: cursor)
                while cursor < source.endIndex, source[cursor].isWhitespace {
                    cursor = source.index(after: cursor)
                }
                let valueStart = cursor
                let valueEnd = expressionEnd(in: source, start: valueStart)
                return valueStart..<valueEnd
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func replacingI18nLiteralProperty(named name: String, value: String, in source: String) -> String? {
        guard let objectRange = i18nInitObjectRange(in: source) else { return nil }
        let objectSource = String(source[objectRange])
        guard let valueRange = objectPropertyValueRange(named: name, in: objectSource) else { return nil }
        let objectOffset = source.distance(from: source.startIndex, to: objectRange.lowerBound)
        let valueStartOffset = objectSource.distance(from: objectSource.startIndex, to: valueRange.lowerBound)
        let valueEndOffset = objectSource.distance(from: objectSource.startIndex, to: valueRange.upperBound)
        let fullStart = source.index(source.startIndex, offsetBy: objectOffset + valueStartOffset)
        let fullEnd = source.index(source.startIndex, offsetBy: objectOffset + valueEndOffset)
        var updated = source
        updated.replaceSubrange(fullStart..<fullEnd, with: javaScriptStringLiteral(value))
        return updated
    }

    private static func expressionEnd(in source: String, start: String.Index) -> String.Index {
        var index = start
        var quote: Character?
        var isEscaped = false
        var depth = 0
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
            } else if character == "{" || character == "[" || character == "(" {
                depth += 1
            } else if character == "}" || character == "]" || character == ")" {
                if depth == 0 {
                    return index
                }
                depth -= 1
            } else if character == ",", depth == 0 {
                return index
            }
            index = source.index(after: index)
        }
        return index
    }

    private static func matchingDelimiterEnd(
        in source: String,
        start: String.Index,
        open: Character,
        close: Character
    ) -> String.Index? {
        var index = start
        var quote: Character?
        var isEscaped = false
        var depth = 0
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func configProperty(from expression: String?) -> OpenGraphiteI18nConfigProperty {
        guard let expression, !expression.isEmpty else {
            return missingI18nConfigProperty()
        }
        if let literal = literalStringValue(from: expression) {
            return OpenGraphiteI18nConfigProperty(
                source: .literal,
                value: literal,
                expression: nil,
                editable: true
            )
        }
        return OpenGraphiteI18nConfigProperty(
            source: .external,
            value: nil,
            expression: truncatedExpression(expression),
            editable: false
        )
    }

    private static func missingI18nConfigProperty() -> OpenGraphiteI18nConfigProperty {
        OpenGraphiteI18nConfigProperty(source: .missing, value: nil, expression: nil, editable: false)
    }

    private static func literalStringValue(from expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quote = trimmed.first, quote == "\"" || quote == "'" else {
            return nil
        }
        var index = trimmed.index(after: trimmed.startIndex)
        var result = ""
        var isEscaped = false
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == quote {
                let afterQuote = trimmed.index(after: index)
                let rest = trimmed[afterQuote...].trimmingCharacters(in: .whitespacesAndNewlines)
                return rest.isEmpty ? result : nil
            } else {
                result.append(character)
            }
            index = trimmed.index(after: index)
        }
        return nil
    }

    private static func localeFieldName(from expression: String?) -> String? {
        guard let expression else { return nil }
        for name in ["selectedLanguage", "locale", "language"] {
            if containsIdentifier(name, in: expression) {
                return name
            }
        }
        return nil
    }

    private static func containsIdentifier(_ name: String, in source: String) -> Bool {
        guard let range = source.range(of: name) else { return false }
        let before = range.lowerBound > source.startIndex ? source[source.index(before: range.lowerBound)] : " "
        let after = range.upperBound < source.endIndex ? source[range.upperBound] : " "
        return !isIdentifierCharacter(before) && !isIdentifierCharacter(after)
    }

    private static func firstQuotedString(in source: String) -> String? {
        var index = source.startIndex
        while index < source.endIndex {
            let quote = source[index]
            guard quote == "\"" || quote == "'" else {
                index = source.index(after: index)
                continue
            }
            var cursor = source.index(after: index)
            var result = ""
            var isEscaped = false
            while cursor < source.endIndex {
                let character = source[cursor]
                if isEscaped {
                    result.append(character)
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == quote {
                    return result
                } else {
                    result.append(character)
                }
                cursor = source.index(after: cursor)
            }
            return nil
        }
        return nil
    }

    private static func javaScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func normalizedScriptReference(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("./") {
            result = String(result.dropFirst(2))
        }
        return result
    }

    private static func variantValue(for locale: String, in variants: [String: String]) -> String? {
        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let value = variants[normalizedLocale] {
            return value
        }
        if normalizedLocale == "en", let value = variants["eng"] {
            return value
        }
        if normalizedLocale == "eng", let value = variants["en"] {
            return value
        }
        return nil
    }

    private static func truncatedExpression(_ expression: String) -> String {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 160 else { return trimmed }
        return "\(trimmed.prefix(157))..."
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character == "$" || character.isLetter
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }

    /// 論理名（日本語）: Locale typography root 解決関数
    /// 処理概要: page root の既存標準 ID / OpenGraphite annotation と CSS provenance から root selector を決定します。
    ///
    /// - Parameters:
    ///   - target: 解決済み page / component target。
    ///   - document: 対象 companion CSS 文書。
    /// - Returns: source 編集に使う root selector と DOM element。
    private func localeTypographyRoot(
        for target: OpenGraphiteProjectPageTarget,
        document: OpenGraphiteCompanionCSSDocument
    ) throws -> (selector: String, element: OpenGraphiteCSSDOMElement) {
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        let projectCSS = FileManager.default.fileExists(atPath: target.loadedProject.cssURL.path)
            ? try String(contentsOf: target.loadedProject.cssURL, encoding: .utf8)
            : nil
        let graph = try pageGraph(
            html: html,
            at: target.htmlURL,
            projectCSS: projectCSS,
            projectCSSURL: target.loadedProject.cssURL,
            allowedRootURL: target.loadedProject.rootURL,
            isProjectRegisteredResource: true
        )
        let rootNode = graph.nodes.first(where: {
            $0.capabilityEvidence.isProjectResourceRoot
        }) ?? graph.nodes.min(by: { lhs, rhs in
            if lhs.depth != rhs.depth { return lhs.depth < rhs.depth }
            return lhs.internalID < rhs.internalID
        })
        let element: OpenGraphiteCSSDOMElement
        let fallbackSelector: String
        if let rootNode {
            element = OpenGraphiteCSSDOMElement(
                tagName: rootNode.tagName,
                attributes: rootNode.attributes,
                isRoot: rootNode.tagName == "html"
            )
            fallbackSelector = Self.localeTypographyFallbackSelector(for: rootNode)
        } else {
            element = OpenGraphiteCSSDOMElement(tagName: "html", isRoot: true)
            fallbackSelector = ":root"
        }
        return (
            document.localeTypographyRootSelector(
                for: element,
                fallbackSelector: fallbackSelector
            ),
            element
        )
    }

    /// 論理名（日本語）: Locale typography fallback selector 生成関数
    /// 処理概要: 安全な標準 `id`、optional internal ID、root element の順で新規宣言先を選びます。
    ///
    /// - Parameter node: page / component root node。
    /// - Returns: source へ安全に追加できる selector。
    private static func localeTypographyFallbackSelector(for node: OpenGraphiteAgentNode) -> String {
        if let standardID = node.attributes["id"], isSafeCSSIdentifier(standardID) {
            return "#\(standardID)"
        }
        if !node.internalID.isEmpty {
            let escaped = node.internalID
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return #"[data-og-internal-id="\#(escaped)"]"#
        }
        if node.tagName == "html" { return ":root" }
        if node.tagName.contains("-"), isSafeCSSIdentifier(node.tagName) { return node.tagName }
        return ":root"
    }

    /// 論理名（日本語）: CSS identifier 安全性判定関数
    /// 処理概要: 追加の escape なしで ID / type selector に利用できる限定的な identifier を判定します。
    ///
    /// - Parameter value: selector 候補。
    /// - Returns: CSS injection を含まず identifier として安全な場合は `true`。
    private static func isSafeCSSIdentifier(_ value: String) -> Bool {
        guard let first = value.first, !value.isEmpty else { return false }
        guard first.isLetter || first == "_" || first == "-" else { return false }
        if first == "-", value.dropFirst().first?.isNumber == true { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// 論理名（日本語）: Locale typography 宣言整列関数
    /// 処理概要: default を先頭にし、locale と source order で安定した JSON 順序へ整列します。
    ///
    /// - Parameter declarations: authored locale typography 宣言。
    /// - Returns: deterministic に整列した宣言。
    private func sortedLocaleTypography(
        _ declarations: [OpenGraphiteLocaleTypographyDeclaration]
    ) -> [OpenGraphiteLocaleTypographyDeclaration] {
        declarations.sorted { lhs, rhs in
            let lhsDefault = lhs.locale == "default"
            let rhsDefault = rhs.locale == "default"
            if lhsDefault != rhsDefault { return lhsDefault }
            let localeOrder = lhs.locale.localizedCaseInsensitiveCompare(rhs.locale)
            if localeOrder != .orderedSame { return localeOrder == .orderedAscending }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    /// 論理名（日本語）: プロジェクトページターゲット解決関数
    /// 処理概要: `.ogp` を読み込み、page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(
        projectURL: URL,
        pageID: String,
        nodeReferenceIDs: [String] = []
    ) throws -> OpenGraphiteProjectPageTarget {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let resolvedPageID = try resolvedPageReferenceString(
            in: loadedProject.project,
            explicitPageID: pageID,
            nodeReferenceIDs: nodeReferenceIDs
        ) ?? pageID
        return try projectPageTarget(loadedProject: loadedProject, pageID: resolvedPageID)
    }

    /// 論理名（日本語）: Node ID正規化関数
    /// 処理概要: typed node 参照 ID が渡された場合は HTML 上の `data-og-internal-id` へ変換します。
    ///
    /// - Parameter id: raw node 内部 ID または `ogref:node` / `ogref:component-node`。
    /// - Returns: HTML 編集で使う node 内部 ID。
    private func resolvedNodeID(_ id: String) -> String {
        OpenGraphiteReferenceID.nodeInternalID(from: id) ?? id
    }

    /// 論理名（日本語）: 一意表示ID生成関数
    /// 処理概要: 既存 `data-og-id` と重複しない candidate を連番付きで生成します。
    ///
    /// - Parameters:
    ///   - base: 希望する base ID。
    ///   - existingIDs: 既存 `data-og-id` 一覧。
    /// - Returns: 重複しない `data-og-id`。
    private func uniqueDisplayID(base: String, existingIDs: Set<String>) -> String {
        let normalizedBase = base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "icon"
            : base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard existingIDs.contains(normalizedBase) else { return normalizedBase }

        var index = 2
        var candidate = "\(normalizedBase)-\(index)"
        while existingIDs.contains(candidate) {
            index += 1
            candidate = "\(normalizedBase)-\(index)"
        }
        return candidate
    }

    /// 論理名（日本語）: 一意内部ID生成関数
    /// 処理概要: 既存 `data-og-internal-id` と重複しない新規 ID を生成します。
    ///
    /// - Parameter existingIDs: 既存 `data-og-internal-id` 一覧。
    /// - Returns: 重複しない `data-og-internal-id`。
    private func uniqueInternalID(existingIDs: Set<String>) -> String {
        var candidate = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefix(12)
            .description
        while existingIDs.contains(candidate) {
            candidate = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
                .prefix(12)
                .description
        }
        return candidate
    }

    /// 論理名（日本語）: 参照IDページ整合性検証関数
    /// 処理概要: typed node 参照が含む page / component が互いに、また明示 page ID と一致するか検証します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - explicitPageID: 呼び出し側が明示した page ID。
    ///   - nodeReferenceIDs: raw ID または typed node 参照 ID 候補。
    /// - Returns: typed node 参照から復元した `ogref:page` または `ogref:component`。存在しない場合は `nil`。
    private func resolvedPageReferenceString(
        in project: OpenGraphiteProject,
        explicitPageID: String,
        nodeReferenceIDs: [String]
    ) throws -> String? {
        var resolvedReferenceID: String?
        var resolvedLocation: OpenGraphiteProjectPageLocation?

        for nodeReferenceID in nodeReferenceIDs {
            guard let pageReferenceID = OpenGraphiteReferenceID.containingPageReferenceString(from: nodeReferenceID) else {
                continue
            }
            guard let pageLocation = pageLocation(in: project, pageID: pageReferenceID) else {
                throw OpenGraphiteAgentCoreError(
                    message: "node reference \"\(nodeReferenceID)\" が指す page \"\(pageReferenceID)\" が .ogp に存在しません。"
                )
            }

            if let currentLocation = resolvedLocation, currentLocation != pageLocation {
                throw OpenGraphiteAgentCoreError(
                    message: "node reference IDs が異なる page を指しています: \"\(resolvedReferenceID ?? "")\" と \"\(pageReferenceID)\"。"
                )
            }

            if resolvedLocation == nil {
                resolvedReferenceID = pageReferenceID
                resolvedLocation = pageLocation
            }
        }

        guard let resolvedReferenceID, let resolvedLocation else {
            return nil
        }

        if let explicitLocation = pageLocation(in: project, pageID: explicitPageID),
           explicitLocation != resolvedLocation {
            throw OpenGraphiteAgentCoreError(
                message: "pageID \"\(explicitPageID)\" と node reference \"\(resolvedReferenceID)\" が異なる page を指しています。"
            )
        }

        return resolvedReferenceID
    }

    /// 論理名（日本語）: 読み込み済みプロジェクトページターゲット解決関数
    /// 処理概要: 既に読み込んだ `.ogp` から page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - loadedProject: 読み込み済み `.ogp`。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(
        loadedProject: LoadedOpenGraphiteProject,
        pageID: String
    ) throws -> OpenGraphiteProjectPageTarget {
        guard let location = pageLocation(in: loadedProject.project, pageID: pageID) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(pageID)\" が .ogp に存在しません。")
        }
        let page: OpenGraphitePage
        let chapter: OpenGraphiteChapter?
        let collection: OpenGraphiteComponentCollection?
        switch location.segment {
        case .pages:
            let resolvedChapter = loadedProject.project.chapters[location.groupIndex]
            chapter = resolvedChapter
            collection = nil
            page = resolvedChapter.pages[location.pageIndex]
        case .components:
            chapter = nil
            let resolvedCollection = loadedProject.project.collections[location.groupIndex]
            collection = resolvedCollection
            page = resolvedCollection.components[location.pageIndex]
        }
        try validateProjectPagePath(page.path)
        let htmlURL = loadedProject.htmlURL(for: page).standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: ".ogp page \"\(pageID)\" の HTML が見つかりません: \(htmlURL.path)")
        }
        return OpenGraphiteProjectPageTarget(
            loadedProject: loadedProject,
            segment: location.segment.rawValue,
            chapter: chapter,
            collection: collection,
            page: page,
            htmlURL: htmlURL
        )
    }

    /// 論理名（日本語）: 既定Chapter位置取得関数
    /// 処理概要: page 追加先として使う先頭 Chapter の index を返します。
    ///
    /// - Parameter project: 対象 `.ogp` プロジェクト。
    /// - Returns: 先頭 Chapter の index。
    private func defaultChapterIndex(in project: OpenGraphiteProject) throws -> Int {
        guard !project.chapters.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: ".ogp に chapters がありません。")
        }
        return 0
    }

    /// 論理名（日本語）: 書き込み可能Collection位置取得関数
    /// 処理概要: component 追加先 Collection を解決し、未指定かつ Collection がない場合は既定 Collection を作成します。
    ///
    /// - Parameters:
    ///   - project: 更新対象 `.ogp` project。
    ///   - collectionID: Collection の ID / 内部 ID / `ogref:collection`。
    /// - Returns: component 追加先 Collection の index。
    private func writableComponentCollectionIndex(
        in project: inout OpenGraphiteProject,
        collectionID: String?
    ) throws -> Int {
        let normalizedCollectionID = collectionID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedCollectionID, !normalizedCollectionID.isEmpty {
            let resolvedCollectionID = OpenGraphiteReferenceID.collectionInternalID(from: normalizedCollectionID)
                ?? normalizedCollectionID
            if let collectionIndex = project.collections.firstIndex(where: {
                $0.internalID == resolvedCollectionID || $0.id == resolvedCollectionID
            }) {
                return collectionIndex
            }
            throw OpenGraphiteAgentCoreError(message: "collection id \"\(collectionID ?? "")\" が見つかりません。")
        }

        if let collectionIndex = project.collections.firstIndex(where: { !$0.components.isEmpty }) {
            return collectionIndex
        }
        if let collectionIndex = project.collections.indices.first {
            return collectionIndex
        }

        project.collections.append(
            OpenGraphiteComponentCollection(
                id: OpenGraphiteComponentCollection.defaultID,
                internalID: "components",
                title: OpenGraphiteComponentCollection.defaultTitle,
                components: []
            )
        )
        return project.collections.count - 1
    }

    /// 論理名（日本語）: 注釈コンテナSelector解決関数
    /// 処理概要: Chapter / Collection selector の排他指定を検証し、表示 ID、内部 ID、typed 参照から対象キャンバスを返します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` project。
    ///   - chapterID: Chapter selector。
    ///   - collectionID: Collection selector。
    /// - Returns: 解決済み注釈コンテナ。
    private func annotationContainerTarget(
        in project: OpenGraphiteProject,
        chapterID: String?,
        collectionID: String?
    ) throws -> OpenGraphiteCanvasAnnotationContainerTarget {
        let normalizedChapterID = chapterID?.nonEmptyTrimmed
        let normalizedCollectionID = collectionID?.nonEmptyTrimmed
        guard (normalizedChapterID == nil) != (normalizedCollectionID == nil) else {
            throw OpenGraphiteAgentCoreError(
                message: "--chapter-id または --collection-id のどちらか一方を指定してください。"
            )
        }

        if let normalizedChapterID {
            let resolvedID = try annotationContainerSelectorInternalID(
                normalizedChapterID,
                expectedType: .chapter
            )
            guard let chapter = project.chapters.first(where: {
                $0.id == resolvedID || $0.internalID == resolvedID
            }) else {
                throw OpenGraphiteAgentCoreError(message: "chapter id \"\(normalizedChapterID)\" が見つかりません。")
            }
            return OpenGraphiteCanvasAnnotationContainerTarget(
                segment: .pages,
                id: chapter.id,
                internalID: chapter.internalID,
                referenceID: OpenGraphiteReferenceID.chapter(chapter.internalID).stringValue,
                annotations: chapter.annotations
            )
        }

        let requestedCollectionID = normalizedCollectionID ?? ""
        let resolvedID = try annotationContainerSelectorInternalID(
            requestedCollectionID,
            expectedType: .collection
        )
        guard let collection = project.collections.first(where: {
            $0.id == resolvedID || $0.internalID == resolvedID
        }) else {
            throw OpenGraphiteAgentCoreError(message: "collection id \"\(requestedCollectionID)\" が見つかりません。")
        }
        return OpenGraphiteCanvasAnnotationContainerTarget(
            segment: .components,
            id: collection.id,
            internalID: collection.internalID,
            referenceID: OpenGraphiteReferenceID.collection(collection.internalID).stringValue,
            annotations: collection.annotations
        )
    }

    /// 論理名（日本語）: 注釈typed参照コンテナ解決関数
    /// 処理概要: `ogref:annotation` に含まれる segment とコンテナ内部 ID から対象 Chapter / Collection を返します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` project。
    ///   - segment: Pages / Components segment。
    ///   - internalID: Chapter または Collection の内部 ID。
    /// - Returns: 解決済み注釈コンテナ。
    private func annotationContainerTarget(
        in project: OpenGraphiteProject,
        segment: OpenGraphiteCanvasSegment,
        internalID: String
    ) throws -> OpenGraphiteCanvasAnnotationContainerTarget {
        switch segment {
        case .pages:
            guard let chapter = project.chapters.first(where: { $0.internalID == internalID }) else {
                throw OpenGraphiteAgentCoreError(message: "annotation reference の Chapter \"\(internalID)\" が見つかりません。")
            }
            return OpenGraphiteCanvasAnnotationContainerTarget(
                segment: .pages,
                id: chapter.id,
                internalID: chapter.internalID,
                referenceID: OpenGraphiteReferenceID.chapter(chapter.internalID).stringValue,
                annotations: chapter.annotations
            )
        case .components:
            guard let collection = project.collections.first(where: { $0.internalID == internalID }) else {
                throw OpenGraphiteAgentCoreError(message: "annotation reference の Collection \"\(internalID)\" が見つかりません。")
            }
            return OpenGraphiteCanvasAnnotationContainerTarget(
                segment: .components,
                id: collection.id,
                internalID: collection.internalID,
                referenceID: OpenGraphiteReferenceID.collection(collection.internalID).stringValue,
                annotations: collection.annotations
            )
        }
    }

    /// 論理名（日本語）: 注釈コンテナ内部ID抽出関数
    /// 処理概要: raw selector または期待種別の Chapter / Collection typed 参照から検索用 ID を返します。
    ///
    /// - Parameters:
    ///   - value: selector 文字列。
    ///   - expectedType: 許可する typed 参照種別。
    /// - Returns: raw ID または typed 参照内の内部 ID。
    private func annotationContainerSelectorInternalID(
        _ value: String,
        expectedType: OpenGraphiteReferenceType
    ) throws -> String {
        if let reference = OpenGraphiteReferenceID(parsing: value) {
            guard reference.type == expectedType else {
                throw OpenGraphiteAgentCoreError(
                    message: "注釈コンテナ selector は ogref:\(expectedType.rawValue):... 形式で指定してください。"
                )
            }
            return reference.parts[0]
        }
        if value.lowercased().hasPrefix("\(OpenGraphiteReferenceID.scheme):") {
            throw OpenGraphiteAgentCoreError(message: "注釈コンテナ selector の typed 参照形式が不正です: \(value)")
        }
        return value
    }

    /// 論理名（日本語）: 注釈要約生成関数
    /// 処理概要: 付箋本文を保持しつつ、手書きは点列を展開せず stroke / point 数へ要約します。
    ///
    /// - Parameters:
    ///   - annotation: 要約対象注釈。
    ///   - target: 注釈を含む Chapter / Collection。
    /// - Returns: CLI / MCP 一覧向け注釈要約。
    private func annotationSummary(
        _ annotation: OpenGraphiteCanvasAnnotation,
        target: OpenGraphiteCanvasAnnotationContainerTarget
    ) -> OpenGraphiteCanvasAnnotationSummary {
        let isStickyNote = annotation.kind == .stickyNote
        let strokes = annotation.kind == .ink ? annotation.strokes : []
        return OpenGraphiteCanvasAnnotationSummary(
            internalID: annotation.internalID,
            referenceID: annotationReferenceID(for: annotation, target: target),
            kind: annotation.kind,
            frame: annotation.frame,
            text: isStickyNote ? annotation.text : nil,
            backgroundColor: isStickyNote ? annotation.backgroundColor : nil,
            textColor: isStickyNote ? annotation.textColor : nil,
            strokeCount: strokes.count,
            pointCount: strokes.reduce(0) { $0 + $1.points.count }
        )
    }

    /// 論理名（日本語）: 注釈参照ID生成関数
    /// 処理概要: 注釈を含む segment / Chapter / Collection と注釈内部 ID から typed 参照 ID を作ります。
    ///
    /// - Parameters:
    ///   - annotation: 参照対象注釈。
    ///   - target: 注釈を含む Chapter / Collection。
    /// - Returns: `ogref:annotation:<pages|components>:<container>:<annotation>`。
    private func annotationReferenceID(
        for annotation: OpenGraphiteCanvasAnnotation,
        target: OpenGraphiteCanvasAnnotationContainerTarget
    ) -> String {
        OpenGraphiteReferenceID.annotation(
            segment: target.segment,
            containerID: target.internalID,
            annotationID: annotation.internalID
        ).stringValue
    }

    /// 論理名（日本語）: ページ位置検索関数
    /// 処理概要: Chapter / Collection 配列を横断し、指定 page ID、内部 ID、または複合参照 ID の位置を返します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - pageID: 検索する page ID、内部 ID、または複合参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func pageLocation(in project: OpenGraphiteProject, pageID: String) -> OpenGraphiteProjectPageLocation? {
        let normalizedPageID = pageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let typedLocation = typedPageLocation(in: project, referenceID: normalizedPageID) {
            return typedLocation
        }
        if let compoundLocation = compoundPageLocation(in: project, referenceID: normalizedPageID) {
            return compoundLocation
        }

        for chapterIndex in project.chapters.indices {
            if let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: {
                $0.id == normalizedPageID || $0.internalID == normalizedPageID
            }) {
                return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
            }
        }
        for collectionIndex in project.collections.indices {
            if let componentIndex = project.collections[collectionIndex].components.firstIndex(where: {
                $0.id == normalizedPageID || $0.internalID == normalizedPageID
            }) {
                return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: componentIndex)
            }
        }

        return nil
    }

    /// 論理名（日本語）: typedページ参照解決関数
    /// 処理概要: `ogref:page` / `ogref:component` / typed node 参照を page 位置へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - referenceID: typed agent 参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func typedPageLocation(in project: OpenGraphiteProject, referenceID: String) -> OpenGraphiteProjectPageLocation? {
        guard let reference = OpenGraphiteReferenceID(parsing: referenceID) else {
            return nil
        }

        switch reference.type {
        case .page, .node:
            let chapterID = reference.parts[0]
            let pageID = reference.parts[1]
            guard let chapterIndex = project.chapters.firstIndex(where: { $0.internalID == chapterID }),
                  let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == pageID })
            else {
                return nil
            }
            return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
        case .component, .componentNode:
            let collectionID = reference.parts[0]
            let componentID = reference.parts[1]
            guard let collectionIndex = project.collections.firstIndex(where: { $0.internalID == collectionID }),
                  let pageIndex = project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == componentID })
            else {
                return nil
            }
            return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: pageIndex)
        case .chapter, .collection, .annotation:
            return nil
        }
    }

    /// 論理名（日本語）: 複合ページ参照解決関数
    /// 処理概要: raw `<chapterInternalID>:<pageInternalID>` または `<collectionInternalID>:<componentInternalID>` を page 位置へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - referenceID: agent 向け page または node 参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func compoundPageLocation(in project: OpenGraphiteProject, referenceID: String) -> OpenGraphiteProjectPageLocation? {
        let parts = referenceID.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        if parts.count >= 2,
           let chapterIndex = project.chapters.firstIndex(where: { $0.internalID == parts[0] }),
           let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == parts[1] }) {
            return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
        }

        if parts.count >= 2,
           let collectionIndex = project.collections.firstIndex(where: { $0.internalID == parts[0] }),
           let pageIndex = project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == parts[1] }) {
            return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: pageIndex)
        }

        return nil
    }

    /// 論理名（日本語）: ページ要約生成関数
    /// 処理概要: Chapter ID と page 定義から、解決済み HTML URL を含む summary を生成します。
    ///
    /// - Parameters:
    ///   - page: 要約する page 定義。
    ///   - chapter: 所属 Chapter。Components の場合は `nil`。
    ///   - collection: 所属 Collection。Pages セグメントの場合は `nil`。
    ///   - chapterIndex: 所属 Chapter index。Components の場合は `nil`。
    ///   - collectionIndex: 所属 Collection index。Pages セグメントの場合は `nil`。
    ///   - pageIndex: Chapter または Collection 配列内の page index。
    ///   - loadedProject: 読み込み済み `.ogp`。
    /// - Returns: JSON 出力用 page summary。
    private func pageSummary(
        for page: OpenGraphitePage,
        chapter: OpenGraphiteChapter?,
        collection: OpenGraphiteComponentCollection?,
        chapterIndex: Int?,
        collectionIndex: Int?,
        pageIndex: Int,
        segment: String,
        loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphitePageSummary {
        OpenGraphitePageSummary(
            chapterID: chapter?.id,
            chapterInternalID: chapter?.internalID,
            collectionID: collection?.id,
            collectionInternalID: collection?.internalID,
            segment: segment,
            id: page.id,
            internalID: page.internalID,
            referenceID: pageReferenceID(segment: segment, chapter: chapter, collection: collection, page: page),
            chapterIndex: chapterIndex,
            collectionIndex: collectionIndex,
            pageIndex: pageIndex,
            path: page.path,
            htmlURL: loadedProject.htmlURL(for: page).path,
            isCanvasHidden: segment == "pages" && page.isCanvasHidden,
            canvas: page.canvas
        )
    }

    /// 論理名（日本語）: ページ参照ID生成関数
    /// 処理概要: 内部 ID から agent が HTML カードを一意に指定できる短い参照 ID を作ります。
    ///
    /// - Parameters:
    ///   - segment: `pages` または `components`。
    ///   - chapter: 所属 Chapter。Components の場合は `nil`。
    ///   - collection: 所属 Collection。Pages セグメントの場合は `nil`。
    ///   - page: 参照対象 page entry。
    /// - Returns: `ogref:page:<chapterInternalID>:<pageInternalID>` または `ogref:component:<collectionInternalID>:<componentInternalID>`。
    private func pageReferenceID(
        segment: String,
        chapter: OpenGraphiteChapter?,
        collection: OpenGraphiteComponentCollection?,
        page: OpenGraphitePage
    ) -> String {
        if segment == "components" {
            return OpenGraphiteReferenceID
                .component(collectionID: collection?.internalID ?? "", componentID: page.internalID)
                .stringValue
        }

        return OpenGraphiteReferenceID
            .page(chapterID: chapter?.internalID ?? "", pageID: page.internalID)
            .stringValue
    }

    /// 論理名（日本語）: キャンバス配置名正規化関数
    /// 処理概要: CLI / MCP から指定された配置名を trim し、未指定なら `nil` として既存値維持を表します。
    ///
    /// - Parameter name: ユーザー指定の配置名。`nil` の場合は未指定。
    /// - Returns: 保存する配置名。空白だけの場合は空文字。
    private func normalizedCanvasName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: Preview Context更新関数
    /// 処理概要: CLI / MCP から指定された runtime mock state の部分更新を既存値へ反映します。
    ///
    /// - Parameters:
    ///   - current: 既存 preview Mock State。
    ///   - fieldMocks: 更新する canvas 全体の runtime mock state。`nil` の場合は既存値を維持します。
    ///   - placementMocks: 更新する placement 単位の runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 preview Mock State。
    private func updatedPreviewContext(
        _ current: OpenGraphitePreviewContext,
        fieldMocks: [String: String]?,
        placementMocks: [String: [String: String]]? = nil
    ) throws -> OpenGraphitePreviewContext {
        var nextFieldMocks = current.fieldMocks
        if let fieldMocks {
            for (key, value) in fieldMocks {
                let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedKey.isEmpty else { continue }
                nextFieldMocks[normalizedKey] = value
            }
        }
        var nextPlacementMocks = current.placementMocks
        if let placementMocks {
            for (rawPlacementID, fields) in placementMocks {
                let placementID = rawPlacementID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !placementID.isEmpty else { continue }
                var nextFields = nextPlacementMocks[placementID] ?? [:]
                for (rawKey, value) in fields {
                    let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { continue }
                    nextFields[key] = value
                }
                guard !nextFields.isEmpty else { continue }
                nextPlacementMocks[placementID] = nextFields
            }
        }

        return OpenGraphitePreviewContext(
            fieldMocks: nextFieldMocks,
            placementMocks: nextPlacementMocks
        )
    }

    /// 論理名（日本語）: プロジェクトページパス検証関数
    /// 処理概要: `chapters[].pages[].path` が `htmlRoot` 相対の明示的な HTML path として安全かを検証します。
    ///
    /// - Parameter path: `htmlRoot` から見た HTML path。
    private func validateProjectPagePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if path.isEmpty
            || path.hasPrefix("/")
            || path.hasSuffix("/")
            || components.contains("")
            || components.contains("..")
            || components.contains(".")
            || URL(fileURLWithPath: path).pathExtension.lowercased() != "html" {
            throw OpenGraphiteAgentCoreError(message: "page path は htmlRoot 配下の相対 HTML path で指定してください: \(path)")
        }
    }

    /// 論理名（日本語）: HTML配置範囲検証関数
    /// 処理概要: 解決済み HTML URL が `.ogp` の `htmlRoot` 配下に残っていることを確認します。
    ///
    /// - Parameters:
    ///   - htmlURL: 解決済み HTML URL。
    ///   - htmlRootURL: `.ogp` から解決した HTML root URL。
    private func ensureHTMLURL(_ htmlURL: URL, staysInside htmlRootURL: URL) throws {
        let rootPath = htmlRootURL.standardizedFileURL.path
        let htmlPath = htmlURL.standardizedFileURL.path
        guard htmlPath == rootPath || htmlPath.hasPrefix(rootPath + "/") else {
            throw OpenGraphiteAgentCoreError(message: "page HTML は htmlRoot 配下に配置してください: \(htmlPath)")
        }
    }

    /// 論理名（日本語）: 相対パス生成関数
    /// 処理概要: HTML 配置ディレクトリから CSS library への相対 path を生成します。
    ///
    /// - Parameters:
    ///   - directoryURL: 参照元ディレクトリ URL。
    ///   - targetURL: 参照先ファイル URL。
    /// - Returns: 相対 path。
    private static func relativePath(from directoryURL: URL, to targetURL: URL) -> String {
        let sourceComponents = directoryURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0
        while sharedCount < sourceComponents.count,
              sharedCount < targetComponents.count,
              sourceComponents[sharedCount] == targetComponents[sharedCount] {
            sharedCount += 1
        }

        let upward = Array(repeating: "..", count: max(sourceComponents.count - sharedCount, 0))
        let downward = Array(targetComponents.dropFirst(sharedCount))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    /// 論理名（日本語）: HTML Document Context変更保存関数
    /// 処理概要: `<html>` attribute 更新結果を検証し、成功時に HTML ファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - mutation: HTML document context 変更結果。
    ///   - htmlURL: 対象 HTML ファイル URL。
    ///   - didChange: 元 HTML から差分があるか。
    /// - Returns: 保存結果。
    private func persistHTMLDocumentContextMutation(
        _ mutation: OpenGraphiteHTMLMutationResult,
        htmlURL: URL,
        didChange: Bool
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let context = OpenGraphiteHTMLDocument(html: mutation.html).htmlDocumentContext()
        let blockingDiagnostics = mutation.diagnostics.filter { $0.severity == .error }
        guard blockingDiagnostics.isEmpty else {
            return OpenGraphiteHTMLDocumentContextResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                context: context,
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) }
            )
        }

        let candidateDocument = OpenGraphiteHTMLDocument(html: mutation.html)
        let companionCSS = try OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: htmlURL)
        let candidateDiagnostics = validate(
            nodes: candidateDocument.nodes(companionCSS: companionCSS, contract: contract),
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            companionCSSExists: companionCSS != nil
        )
        let allDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + candidateDiagnostics
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteHTMLDocumentContextResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                context: context,
                diagnostics: allDiagnostics
            )
        }

        if didChange {
            try mutation.html.write(to: htmlURL, atomically: true, encoding: .utf8)
        }
        return OpenGraphiteHTMLDocumentContextResult(
            schemaVersion: Self.schemaVersion,
            updated: didChange,
            path: htmlURL.path,
            context: context,
            diagnostics: allDiagnostics
        )
    }

    /// 論理名（日本語）: Companion CSS宣言保存関数
    /// 処理概要: CSS 宣言編集を HTML から分離し、同名 companion CSS と sanitization 済み HTML に保存します。
    private func persistCompanionCSSVariable(
        _ variable: String,
        value: String,
        nodeID: String,
        html: String,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        guard contract.isKnownCSSVariable(variable) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unknown-css-variable",
                        message: "\(variable) は OpenGraphite.contract.json に定義されていません。",
                        path: htmlURL.path,
                        nodeID: nodeID
                    )
                ],
                insertedNodes: nil
            )
        }
        guard !contract.runtimeCSSVariableSet.contains(variable) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-css-variable",
                        message: "\(variable) は正本 CSS へ保存できない実行時 CSS 変数です。",
                        path: htmlURL.path,
                        nodeID: nodeID
                    )
                ],
                insertedNodes: nil
            )
        }

        let runtimeSanitizedHTML = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let legacyDocument = OpenGraphiteHTMLDocument(html: runtimeSanitizedHTML)
        let sanitizedHTML = legacyDocument.removingOpenGraphiteStyleVariables(contract: contract)
        let document = OpenGraphiteHTMLDocument(html: sanitizedHTML)
        let matches = document.nodes(contract: contract).filter { $0.internalID == nodeID }
        let nodeDiagnostics = uniqueNodeDiagnostics(matches: matches, id: nodeID, path: htmlURL.path)
        guard nodeDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: nodeDiagnostics,
                insertedNodes: nil
            )
        }
        guard matches[0].supports(.editLayout) else {
            return unsupportedCapabilityResult(
                capability: .editLayout,
                operation: "node style edit",
                path: htmlURL.path,
                node: matches[0]
            )
        }

        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        migrateLegacyOpenGraphiteCSSVariables(from: legacyDocument, into: &companionCSS)
        companionCSS.setCSSVariable(variable, value: value, forNodeInternalID: nodeID)
        let candidateNodes = document.nodes(companionCSS: companionCSS, contract: contract)
        let candidateDiagnostics = validate(
            nodes: candidateNodes,
            tags: document.parsedTags(),
            path: htmlURL.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            companionCSSExists: true
        )
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: candidateDiagnostics,
                insertedNodes: nil
            )
        }

        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
        let previousCSS = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
        let htmlChanged = sanitizedHTML != html
        let cssChanged = companionCSS.css != previousCSS
        if htmlChanged {
            try sanitizedHTML.write(to: htmlURL, atomically: true, encoding: .utf8)
        }
        if cssChanged {
            try companionCSS.write(forHTMLURL: htmlURL)
        }

        let graph = try pageGraph(at: htmlURL)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: htmlChanged || cssChanged,
            path: htmlURL.path,
            node: graph.nodes.first { $0.internalID == nodeID },
            diagnostics: graph.diagnostics,
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: Wrapper CSS複数宣言保存関数
    /// 処理概要: icon wrapperの寸法などを同名companion CSSへ保存し、無関係なlegacy inline値は移行しません。
    private func persistWrapperStyleDeclarations(
        _ declarations: [String: String],
        nodeID: String,
        htmlURL: URL,
        baseResult: OpenGraphiteEditResult
    ) throws -> OpenGraphiteEditResult {
        guard !declarations.isEmpty else { return baseResult }
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)
        for key in declarations.keys.sorted() {
            guard contract.isKnownCSSVariable(key), !contract.runtimeCSSVariableSet.contains(key) else { continue }
            companionCSS.setCSSVariable(key, value: declarations[key] ?? "", forNodeInternalID: nodeID)
        }

        let candidateNodes = document.nodes(companionCSS: companionCSS, contract: contract)
        let candidateDiagnostics = validate(
            nodes: candidateNodes,
            tags: document.parsedTags(),
            path: htmlURL.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            companionCSSExists: true
        )
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: candidateNodes.first { $0.internalID == nodeID },
                diagnostics: candidateDiagnostics,
                insertedNodes: baseResult.insertedNodes
            )
        }

        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
        let previousCSS = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
        let cssChanged = companionCSS.css != previousCSS
        if cssChanged {
            try companionCSS.write(forHTMLURL: htmlURL)
        }

        let graph = try pageGraph(at: htmlURL)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: baseResult.updated || cssChanged,
            path: htmlURL.path,
            node: graph.nodes.first { $0.internalID == nodeID } ?? baseResult.node,
            diagnostics: graph.diagnostics,
            insertedNodes: baseResult.insertedNodes
        )
    }

    /// 論理名（日本語）: 関連実描画CSS複数宣言保存関数
    /// 処理概要: icon metadataから導出した標準mask propertyを実描画childへ順に保存します。
    private func persistRelatedStyleDeclarations(
        _ declarations: [String: String],
        wrapperNodeID: String,
        htmlURL: URL,
        baseResult: OpenGraphiteEditResult
    ) throws -> OpenGraphiteEditResult {
        var didUpdate = baseResult.updated
        var diagnostics = baseResult.diagnostics
        for property in declarations.keys.sorted() {
            let value = declarations[property] ?? ""
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let edit = try setRelatedStyleDeclaration(
                property,
                value: value,
                wrapperNodeID: wrapperNodeID,
                htmlURL: htmlURL
            )
            didUpdate = didUpdate || edit.updated
            diagnostics = edit.diagnostics
            if edit.diagnostics.contains(where: { $0.severity == .error }) {
                return OpenGraphiteEditResult(
                    schemaVersion: Self.schemaVersion,
                    updated: didUpdate,
                    path: htmlURL.path,
                    node: edit.node ?? baseResult.node,
                    diagnostics: edit.diagnostics,
                    insertedNodes: baseResult.insertedNodes
                )
            }
        }
        let graph = try pageGraph(at: htmlURL)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: didUpdate,
            path: htmlURL.path,
            node: graph.nodes.first { $0.internalID == wrapperNodeID } ?? baseResult.node,
            diagnostics: diagnostics.isEmpty ? graph.diagnostics : diagnostics,
            insertedNodes: baseResult.insertedNodes
        )
    }

    /// 論理名（日本語）: 関連実描画CSS宣言削除関数
    /// 処理概要: icon child置換前のDOM関係とsource provenanceを使い、旧mask declarationだけをcompanion CSSから除きます。
    private func removeRelatedStyleDeclarations(
        _ properties: [String],
        wrapperNodeID: String,
        document: OpenGraphiteHTMLDocument,
        companionCSS: inout OpenGraphiteCompanionCSSDocument
    ) {
        for property in properties {
            let targets = document.renderingTargets(forNodeID: wrapperNodeID, companionCSS: companionCSS)
            guard let target = targets.first(where: { $0.value.kind == "mask" }) else { continue }
            companionCSS.setCSSProperty(
                property,
                value: "",
                for: target.element,
                fallbackSelector: target.value.writeSelector
            )
        }
    }

    /// 論理名（日本語）: Legacy inline design value移行関数
    /// 処理概要: HTML inline style に残る編集対象 CSS declaration を既存 companion CSS の値を上書きしない形で移します。
    ///
    /// - Parameters:
    ///   - document: legacy inline style を含み得る HTML 文書。
    ///   - companionCSS: 追記先の companion CSS 文書。
    private func migrateLegacyOpenGraphiteCSSVariables(
        from document: OpenGraphiteHTMLDocument,
        into companionCSS: inout OpenGraphiteCompanionCSSDocument
    ) {
        for node in document.nodes(contract: contract) {
            guard !node.internalID.isEmpty else { continue }
            let existingVariables = companionCSS.cssVariables(forNodeInternalID: node.internalID, contract: contract)
            for key in node.cssVariables.keys.sorted()
                where !contract.runtimeCSSVariableSet.contains(key) && existingVariables[key] == nil {
                companionCSS.setCSSVariable(key, value: node.cssVariables[key] ?? "", forNodeInternalID: node.internalID)
            }
        }
    }

    /// HTML mutationを検証して永続化し、明示された元sourceと同一ならwriteせずno-op結果を返します。
    private func persistMutation(
        _ mutation: OpenGraphiteHTMLMutationResult,
        htmlURL: URL,
        nodeID: String,
        insertedNodeIDsBeforeMutation: Set<String>? = nil,
        migrateInlineDesignValues: Bool = false,
        originalHTMLForNoOp: String? = nil
    ) throws -> OpenGraphiteEditResult {
        let blockingDiagnostics = mutation.diagnostics.filter { $0.severity == .error }
        guard blockingDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) },
                insertedNodes: nil
            )
        }

        let persistence = try mutationPersistencePayload(
            html: mutation.html,
            htmlURL: htmlURL,
            migrateInlineDesignValues: migrateInlineDesignValues
        )
        if let originalHTMLForNoOp,
           persistence.html == originalHTMLForNoOp,
           persistence.companionCSS == nil {
            let graph = try pageGraph(at: htmlURL)
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: graph.nodes.first { $0.internalID == nodeID },
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + graph.diagnostics,
                insertedNodes: nil
            )
        }
        let candidateDocument = OpenGraphiteHTMLDocument(html: persistence.html)
        let existingCompanionCSS = try OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: htmlURL)
        let companionCSS = persistence.companionCSS ?? existingCompanionCSS
        let candidateDiagnostics = validate(
            nodes: candidateDocument.nodes(companionCSS: companionCSS, contract: contract),
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path,
            companionCSSURL: OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL),
            companionCSSExists: companionCSS != nil
        )
        let allDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + candidateDiagnostics
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: allDiagnostics,
                insertedNodes: nil
            )
        }

        try persistence.html.write(to: htmlURL, atomically: true, encoding: .utf8)
        if let companionCSS = persistence.companionCSS {
            try companionCSS.write(forHTMLURL: htmlURL)
        }
        let graph = try pageGraph(at: htmlURL)
        let insertedNodes = insertedNodeIDsBeforeMutation.map { beforeIDs in
            graph.nodes.filter { !beforeIDs.contains($0.id) }
        }
        let node = graph.nodes.first { $0.internalID == nodeID }
            ?? insertedNodes?.first
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: true,
            path: htmlURL.path,
            node: node,
            diagnostics: graph.diagnostics,
            insertedNodes: insertedNodes
        )
    }

    /// 論理名（日本語）: HTML mutation永続化payload生成関数
    /// 処理概要: 挿入HTML断片に含まれる inline design value を companion CSS へ移して保存候補を作ります。
    ///
    /// - Parameters:
    ///   - html: HTML mutation 後の候補HTML。
    ///   - htmlURL: 保存対象 HTML URL。
    ///   - migrateInlineDesignValues: `true` の場合、契約対象 CSS declaration を companion CSS へ移します。
    /// - Returns: 保存する HTML と、更新が必要な companion CSS。
    private func mutationPersistencePayload(
        html: String,
        htmlURL: URL,
        migrateInlineDesignValues: Bool
    ) throws -> (html: String, companionCSS: OpenGraphiteCompanionCSSDocument?) {
        guard migrateInlineDesignValues else {
            return (html, nil)
        }

        let runtimeSanitizedHTML = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let legacyDocument = OpenGraphiteHTMLDocument(html: runtimeSanitizedHTML)
        let sanitizedHTML = legacyDocument.removingOpenGraphiteStyleVariables(contract: contract)
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: htmlURL)
        let previousCSS = companionCSS.css
        migrateLegacyOpenGraphiteCSSVariables(from: legacyDocument, into: &companionCSS)
        let changedCompanionCSS = companionCSS.css == previousCSS ? nil : companionCSS
        return (sanitizedHTML, changedCompanionCSS)
    }

    private func writeProject(_ project: OpenGraphiteProject, to projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(project.normalizedInternalIDs())
        data.append(0x0A)
        try data.write(to: projectURL, options: .atomic)
    }

    /// 変更箇所前後3行を含む決定的な単一hunk unified diffを生成します。
    private static func unifiedDiff(before: String, after: String, path: String) -> String {
        guard before != after else { return "" }
        let beforeLines = before.components(separatedBy: "\n")
        let afterLines = after.components(separatedBy: "\n")
        var prefixCount = 0
        while prefixCount < beforeLines.count,
              prefixCount < afterLines.count,
              beforeLines[prefixCount] == afterLines[prefixCount] {
            prefixCount += 1
        }
        var suffixCount = 0
        while suffixCount < beforeLines.count - prefixCount,
              suffixCount < afterLines.count - prefixCount,
              beforeLines[beforeLines.count - 1 - suffixCount] == afterLines[afterLines.count - 1 - suffixCount] {
            suffixCount += 1
        }

        let context = 3
        let beforeStart = max(prefixCount - context, 0)
        let afterStart = beforeStart
        let beforeChangedEnd = beforeLines.count - suffixCount
        let afterChangedEnd = afterLines.count - suffixCount
        let beforeEnd = min(beforeChangedEnd + context, beforeLines.count)
        let afterEnd = min(afterChangedEnd + context, afterLines.count)
        var lines = [
            "--- \(path)",
            "+++ \(path)",
            "@@ -\(beforeStart + 1),\(beforeEnd - beforeStart) +\(afterStart + 1),\(afterEnd - afterStart) @@"
        ]
        if beforeStart < prefixCount {
            lines.append(contentsOf: beforeLines[beforeStart..<prefixCount].map { " \($0)" })
        }
        if prefixCount < beforeChangedEnd {
            lines.append(contentsOf: beforeLines[prefixCount..<beforeChangedEnd].map { "-\($0)" })
        }
        if prefixCount < afterChangedEnd {
            lines.append(contentsOf: afterLines[prefixCount..<afterChangedEnd].map { "+\($0)" })
        }
        let beforeSuffixStart = beforeLines.count - suffixCount
        if beforeSuffixStart < beforeEnd {
            lines.append(contentsOf: beforeLines[beforeSuffixStart..<beforeEnd].map { " \($0)" })
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func validate(
        nodes: [OpenGraphiteAgentNode],
        tags: [OpenGraphiteHTMLTag],
        path: String,
        companionCSSURL: URL? = nil,
        companionCSSExists: Bool = false
    ) -> [OpenGraphiteDiagnostic] {
        var diagnostics: [OpenGraphiteDiagnostic] = []
        for tag in tags {
            for attributeName in ["data-og-id", "data-og-internal-id"] {
                guard let identity = tag.emptyNilAttribute(named: attributeName),
                      tag.containsUnresolvedHTMLCharacterReference(named: attributeName)
                else { continue }
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unresolved-\(attributeName)-character-reference",
                        message: "\(attributeName) \"\(identity)\" はHTML character referenceのsemantic valueを確定できないため参照identityとして使用できません。",
                        path: path,
                        nodeID: tag.emptyNilAttribute(named: "data-og-id")
                    )
                )
            }
        }
        let annotatedIDs = tags.compactMap { tag -> (id: String, tag: OpenGraphiteHTMLTag)? in
            guard let id = tag.emptyNilAttribute(named: "data-og-id") else { return nil }
            return (id, tag)
        }
        let groupedIDs = Dictionary(grouping: annotatedIDs, by: { $0.id })

        for (id, matches) in groupedIDs where matches.count > 1 {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-id",
                    message: "data-og-id \"\(id)\" が重複しています。",
                    path: path,
                    nodeID: id
                )
            )
        }

        let annotatedInternalIDs = tags.compactMap { tag -> (id: String, tag: OpenGraphiteHTMLTag)? in
            guard let id = tag.emptyNilAttribute(named: "data-og-internal-id") else { return nil }
            return (id, tag)
        }
        let groupedInternalIDs = Dictionary(grouping: annotatedInternalIDs, by: { $0.id })
        for (id, matches) in groupedInternalIDs where matches.count > 1 {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-internal-id",
                    message: "data-og-internal-id \"\(id)\" が重複しています。",
                    path: path,
                    nodeID: matches.first?.tag.attributeValue(named: "data-og-id")
                )
            )
        }

        for tag in tags {
            for attribute in tag.attributes where contract.runtimeAttributeSet.contains(attribute.name.lowercased()) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-attribute-persisted",
                        message: "\(attribute.name) は正本 HTML に残せない実行時属性です。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    )
                )
            }
            if companionCSSExists,
               let style = tag.attributeValue(named: "style"),
               OpenGraphiteCSSStyle.parse(style).declarations.contains(where: {
                   $0.name.hasPrefix("--og-") && contract.isKnownCSSVariable($0.name)
               }) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "html-design-style-persisted",
                        message: "OpenGraphite予約design valueはHTML inline styleではなくcompanion CSSに保存します。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    )
                )
            }
        }

        for node in nodes {
            if let legacyRole = node.attributes["data-og-role"] {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-data-og-role",
                        message: "\(legacyRole) はlegacy data-og-roleです。標準role属性または要素semanticsへ移行してください。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            if node.tagName.lowercased() == "og-placement" {
                if (node.attributes["data-og-source-component-internal-id"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    diagnostics.append(
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "component-placement-missing-source-component",
                            message: "component placement には data-og-source-component-internal-id が必要です。",
                            path: path,
                            nodeID: node.id
                        )
                    )
                }
                if (node.attributes["data-og-source-node-internal-id"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    diagnostics.append(
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "component-placement-missing-source-node",
                            message: "component placement には data-og-source-node-internal-id が必要です。",
                            path: path,
                            nodeID: node.id
                        )
                    )
                }
            }

            for key in node.cssVariables.keys.sorted() where !contract.isKnownCSSVariable(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-css-variable",
                        message: "\(key) は OpenGraphite.contract.json に定義されていません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            for key in node.cssVariables.keys.sorted() where contract.runtimeCSSVariableSet.contains(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-css-variable-persisted",
                        message: "\(key) は正本 HTML に残せない実行時 CSS 変数です。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }
        }

        return diagnostics
    }

    /// 論理名（日本語）: Component Placement使用文脈検証関数
    /// 処理概要: component placement が Components / Collection canvas 以外に置かれていないか検証します。
    ///
    /// - Parameters:
    ///   - nodes: 検証対象 node 一覧。
    ///   - path: 診断に付与する HTML path。
    ///   - allowsComponentPlacements: component placement を許可する文脈か。
    /// - Returns: placement 使用文脈に関する diagnostics。
    private func componentPlacementUsageDiagnostics(
        nodes: [OpenGraphiteAgentNode],
        path: String,
        allowsComponentPlacements: Bool
    ) -> [OpenGraphiteDiagnostic] {
        guard !allowsComponentPlacements else { return [] }
        return nodes
            .filter { $0.tagName.lowercased() == "og-placement" }
            .map { node in
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "component-placement-outside-collection",
                    message: "component placement は Components / Collection canvas にだけ配置できます。",
                    path: path,
                    nodeID: node.id
                )
            }
    }

    /// 論理名（日本語）: Component Placement参照検証関数
    /// 処理概要: component placement の参照元 component / node が現在の component canvas 内で解決できるか検証します。
    ///
    /// - Parameters:
    ///   - nodes: 検証対象 node 一覧。
    ///   - path: 診断に付与する HTML path。
    ///   - componentInternalID: `.ogp` 上の component canvas 内部 ID。
    /// - Returns: placement 参照に関する diagnostics。
    private func componentPlacementReferenceDiagnostics(
        nodes: [OpenGraphiteAgentNode],
        path: String,
        componentInternalID: String
    ) -> [OpenGraphiteDiagnostic] {
        let internalIDs = Set(nodes.map(\.internalID).filter { !$0.isEmpty })
        return nodes
            .filter { $0.tagName.lowercased() == "og-placement" }
            .flatMap { node -> [OpenGraphiteDiagnostic] in
                var diagnostics: [OpenGraphiteDiagnostic] = []
                let sourceComponentID = (node.attributes["data-og-source-component-internal-id"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let sourceNodeID = (node.attributes["data-og-source-node-internal-id"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !sourceComponentID.isEmpty && sourceComponentID != componentInternalID {
                    diagnostics.append(
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "component-placement-source-component-mismatch",
                            message: "component placement の参照元 component は現在の component canvas と一致する必要があります。",
                            path: path,
                            nodeID: node.id
                        )
                    )
                }
                if !sourceNodeID.isEmpty && !internalIDs.contains(sourceNodeID) {
                    diagnostics.append(
                        OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "component-placement-source-node-missing",
                            message: "component placement の参照元 node が component canvas 内に見つかりません。",
                            path: path,
                            nodeID: node.id
                        )
                    )
                }
                return diagnostics
            }
    }

    private func uniqueNodeDiagnostics(
        matches: [OpenGraphiteAgentNode],
        id: String,
        path: String
    ) -> [OpenGraphiteDiagnostic] {
        if matches.count == 1 {
            return []
        }

        if matches.isEmpty {
            return [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-node",
                    message: "data-og-internal-id \"\(id)\" を持つノードが見つかりません。",
                    path: path,
                    nodeID: id
                )
            ]
        }

        return [
            OpenGraphiteDiagnostic(
                severity: .error,
                code: "duplicate-data-og-internal-id",
                message: "data-og-internal-id \"\(id)\" が \(matches.count) 件あります。",
                path: path,
                nodeID: id
            )
        ]
    }

    private func withPath(_ diagnostic: OpenGraphiteDiagnostic, path: String) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(
            severity: diagnostic.severity,
            code: diagnostic.code,
            message: diagnostic.message,
            path: diagnostic.path ?? path,
            nodeID: diagnostic.nodeID
        )
    }

    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeText(value).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// 論理名（日本語）: Legacy manifest移行結果
/// 概要: raw JSON range patch後のsource、legacy検出、blocking diagnosticsを保持します。
private struct OpenGraphiteLegacyManifestMigrationResult {
    var source: String
    var detectedLegacy: Bool
    var generatedHostFields: Set<String>
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Legacy previewContext raw JSON移行器
/// 概要: `.ogp`全体を再encodeせず、placement mock内の既知key/value rangeだけを変更します。
private enum OpenGraphiteLegacyManifestMigrator {
    private struct Replacement {
        var range: Range<Int>
        var value: String
    }

    private struct Member {
        var key: String
        var keyRange: Range<Int>
        var value: Value
        var commaBefore: Range<Int>?
        var commaAfter: Range<Int>?
    }

    private indirect enum Value {
        case object([Member], Range<Int>)
        case array([Value], Range<Int>)
        case string(String, Range<Int>)
        case scalar(Range<Int>)

        var range: Range<Int> {
            switch self {
            case .object(_, let range), .array(_, let range), .string(_, let range), .scalar(let range):
                return range
            }
        }

        var members: [Member]? {
            guard case .object(let members, _) = self else { return nil }
            return members
        }

        var elements: [Value]? {
            guard case .array(let values, _) = self else { return nil }
            return values
        }

        var string: String? {
            guard case .string(let value, _) = self else { return nil }
            return value
        }
    }

    private struct Parser {
        let source: String
        var cursor: String.Index

        init(source: String) {
            self.source = source
            cursor = source.startIndex
        }

        mutating func parse() -> Value? {
            skipWhitespace()
            guard let value = parseValue() else { return nil }
            skipWhitespace()
            return cursor == source.endIndex ? value : nil
        }

        private mutating func parseValue() -> Value? {
            skipWhitespace()
            guard cursor < source.endIndex else { return nil }
            switch source[cursor] {
            case "{": return parseObject()
            case "[": return parseArray()
            case "\"":
                guard let token = parseString() else { return nil }
                return .string(token.value, token.range)
            default:
                let start = cursor
                while cursor < source.endIndex,
                      !source[cursor].isWhitespace,
                      ![",", "]", "}"].contains(source[cursor]) {
                    cursor = source.index(after: cursor)
                }
                guard cursor > start else { return nil }
                return .scalar(offset(start)..<offset(cursor))
            }
        }

        private mutating func parseObject() -> Value? {
            let start = cursor
            cursor = source.index(after: cursor)
            var members: [Member] = []
            var commaBefore: Range<Int>?
            while true {
                skipWhitespace()
                guard cursor < source.endIndex else { return nil }
                if source[cursor] == "}" {
                    cursor = source.index(after: cursor)
                    return .object(members, offset(start)..<offset(cursor))
                }
                guard let key = parseString() else { return nil }
                skipWhitespace()
                guard cursor < source.endIndex, source[cursor] == ":" else { return nil }
                cursor = source.index(after: cursor)
                guard let value = parseValue() else { return nil }
                skipWhitespace()
                var commaAfter: Range<Int>?
                if cursor < source.endIndex, source[cursor] == "," {
                    let commaStart = cursor
                    cursor = source.index(after: cursor)
                    commaAfter = offset(commaStart)..<offset(cursor)
                }
                members.append(Member(
                    key: key.value,
                    keyRange: key.range,
                    value: value,
                    commaBefore: commaBefore,
                    commaAfter: commaAfter
                ))
                commaBefore = commaAfter
                if commaAfter == nil {
                    skipWhitespace()
                    guard cursor < source.endIndex, source[cursor] == "}" else { return nil }
                }
            }
        }

        private mutating func parseArray() -> Value? {
            let start = cursor
            cursor = source.index(after: cursor)
            var values: [Value] = []
            while true {
                skipWhitespace()
                guard cursor < source.endIndex else { return nil }
                if source[cursor] == "]" {
                    cursor = source.index(after: cursor)
                    return .array(values, offset(start)..<offset(cursor))
                }
                guard let value = parseValue() else { return nil }
                values.append(value)
                skipWhitespace()
                if cursor < source.endIndex, source[cursor] == "," {
                    cursor = source.index(after: cursor)
                    continue
                }
                guard cursor < source.endIndex, source[cursor] == "]" else { return nil }
            }
        }

        private mutating func parseString() -> (value: String, range: Range<Int>)? {
            guard cursor < source.endIndex, source[cursor] == "\"" else { return nil }
            let start = cursor
            cursor = source.index(after: cursor)
            var escaped = false
            while cursor < source.endIndex {
                let character = source[cursor]
                cursor = source.index(after: cursor)
                if escaped {
                    escaped = false
                    continue
                }
                if character == "\\" {
                    escaped = true
                    continue
                }
                if character == "\"" {
                    let raw = String(source[start..<cursor])
                    guard let data = raw.data(using: .utf8),
                          let value = try? JSONDecoder().decode(String.self, from: data)
                    else { return nil }
                    return (value, offset(start)..<offset(cursor))
                }
            }
            return nil
        }

        private mutating func skipWhitespace() {
            while cursor < source.endIndex, source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
        }

        private func offset(_ index: String.Index) -> Int {
            source.distance(from: source.startIndex, to: index)
        }
    }

    /// 論理名（日本語）: Legacy manifest移行関数
    /// 処理概要: `previewContext.placementMocks.*`に限定し、既知fieldのraw JSON rangeだけを移行します。
    ///
    /// - Parameters:
    ///   - source: authored `.ogp` JSON source。
    ///   - path: diagnosticsに記録するproject相対path。
    /// - Returns: unrelated bytesを保持した移行candidate、legacy検出結果、blocking diagnostics。
    static func migrate(_ source: String, path: String) -> OpenGraphiteLegacyManifestMigrationResult {
        var parser = Parser(source: source)
        guard let root = parser.parse(), let rootMembers = root.members else {
            return OpenGraphiteLegacyManifestMigrationResult(
                source: source,
                detectedLegacy: false,
                generatedHostFields: [],
                diagnostics: [diagnostic(
                    code: "migration-manifest-parse-failed",
                    message: "manifest JSONをlosslessに解析できません。",
                    path: path
                )]
            )
        }
        var replacements: [Replacement] = []
        var diagnostics: [OpenGraphiteDiagnostic] = []
        var detectedLegacy = false
        var generatedHostFields: Set<String> = []
        let placementObjects = placementMockObjects(
            rootMembers: rootMembers,
            path: path,
            diagnostics: &diagnostics
        )
        for placement in placementObjects {
            guard let members = placement.value.members else { continue }
            let duplicateKeys = Dictionary(grouping: members, by: \.key)
                .filter { $0.value.count > 1 }
                .keys
                .sorted()
            if !duplicateKeys.isEmpty {
                for duplicateKey in duplicateKeys {
                    diagnostics.append(diagnostic(
                        code: "migration-manifest-duplicate-key",
                        message: "placement mock \(placement.key) に重複key \(duplicateKey) があります。",
                        path: path
                    ))
                }
                if members.contains(where: { $0.key == "codeViewerMode" || $0.key == "placementMode" }) {
                    detectedLegacy = true
                }
                continue
            }
            let destinationMembers = members.filter { $0.key == "host.variant" }
            let legacyMembers = members.filter { $0.key == "codeViewerMode" || $0.key == "placementMode" }
            guard !legacyMembers.isEmpty else { continue }
            detectedLegacy = true
            var mapped: [(member: Member, value: String)] = []
            for member in legacyMembers {
                guard let value = member.value.string else {
                    diagnostics.append(diagnostic(
                        code: "unsupported-legacy-preview-mode",
                        message: "\(member.key) はstring値だけを移行できます。",
                        path: path
                    ))
                    continue
                }
                let normalized = value.lowercased()
                if member.key == "codeViewerMode", normalized == "preview" {
                    mapped.append((member, "preview"))
                } else if member.key == "placementMode", normalized == "collapsed" {
                    mapped.append((member, "collapsible collapsed"))
                } else {
                    diagnostics.append(diagnostic(
                        code: "unsupported-legacy-preview-mode",
                        message: "\(member.key)=\(value) の決定的mappingはありません。",
                        path: path
                    ))
                }
            }
            guard mapped.count == legacyMembers.count else { continue }
            let values = Set(mapped.map(\.value))
            if values.count > 1 {
                diagnostics.append(diagnostic(
                    code: "legacy-preview-context-conflict",
                    message: "placement mock \(placement.key) のlegacy fieldsは異なるhost.variantへ解決されます。",
                    path: path
                ))
                continue
            }
            let mappedValue = mapped[0].value
            if let destination = destinationMembers.first {
                guard destination.value.string == mappedValue else {
                    diagnostics.append(diagnostic(
                        code: "legacy-preview-context-conflict",
                        message: "placement mock \(placement.key) の既存host.variantとlegacy fieldが競合します。",
                        path: path
                    ))
                    continue
                }
                replacements.append(contentsOf: mapped.map { removal(for: $0.member) })
            } else {
                let first = mapped[0].member
                replacements.append(Replacement(range: first.keyRange, value: jsonString("host.variant")))
                replacements.append(Replacement(range: first.value.range, value: jsonString(mappedValue)))
                replacements.append(contentsOf: mapped.dropFirst().map { removal(for: $0.member) })
                generatedHostFields.insert("host.variant")
            }
        }
        guard diagnostics.isEmpty else {
            return OpenGraphiteLegacyManifestMigrationResult(
                source: source,
                detectedLegacy: detectedLegacy,
                generatedHostFields: [],
                diagnostics: diagnostics
            )
        }
        return OpenGraphiteLegacyManifestMigrationResult(
            source: applying(replacements, to: source),
            detectedLegacy: detectedLegacy,
            generatedHostFields: generatedHostFields,
            diagnostics: []
        )
    }

    private static func uniqueMember(named name: String, in members: [Member]) -> Member? {
        let matches = members.filter { $0.key == name }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func placementMockObjects(
        rootMembers: [Member],
        path: String,
        diagnostics: inout [OpenGraphiteDiagnostic]
    ) -> [Member] {
        var result: [Member] = []
        collectPlacementMocks(
            collectionKey: "chapters",
            resourceKey: "pages",
            rootMembers: rootMembers,
            path: path,
            diagnostics: &diagnostics,
            result: &result
        )
        collectPlacementMocks(
            collectionKey: "collections",
            resourceKey: "components",
            rootMembers: rootMembers,
            path: path,
            diagnostics: &diagnostics,
            result: &result
        )
        return result
    }

    private static func collectPlacementMocks(
        collectionKey: String,
        resourceKey: String,
        rootMembers: [Member],
        path: String,
        diagnostics: inout [OpenGraphiteDiagnostic],
        result: inout [Member]
    ) {
        guard let collections = member(
            named: collectionKey,
            in: rootMembers,
            jsonPath: collectionKey,
            sourcePath: path,
            diagnostics: &diagnostics
        )?.value.elements else { return }
        for (collectionIndex, collection) in collections.enumerated() {
            guard let collectionMembers = collection.members,
                  let resources = member(
                    named: resourceKey,
                    in: collectionMembers,
                    jsonPath: "\(collectionKey)[\(collectionIndex)].\(resourceKey)",
                    sourcePath: path,
                    diagnostics: &diagnostics
                  )?.value.elements
            else { continue }
            for (resourceIndex, resource) in resources.enumerated() {
                guard let resourceMembers = resource.members,
                      let canvasMembers = member(
                        named: "canvas",
                        in: resourceMembers,
                        jsonPath: "\(collectionKey)[\(collectionIndex)].\(resourceKey)[\(resourceIndex)].canvas",
                        sourcePath: path,
                        diagnostics: &diagnostics
                      )?.value.members,
                      let previewMembers = member(
                        named: "previewContext",
                        in: canvasMembers,
                        jsonPath: "\(collectionKey)[\(collectionIndex)].\(resourceKey)[\(resourceIndex)].canvas.previewContext",
                        sourcePath: path,
                        diagnostics: &diagnostics
                      )?.value.members,
                      let placements = member(
                        named: "placementMocks",
                        in: previewMembers,
                        jsonPath: "\(collectionKey)[\(collectionIndex)].\(resourceKey)[\(resourceIndex)].canvas.previewContext.placementMocks",
                        sourcePath: path,
                        diagnostics: &diagnostics
                      )?.value.members
                else { continue }
                let duplicatePlacementKeys = Dictionary(grouping: placements, by: \.key)
                    .filter { $0.value.count > 1 }
                    .keys
                    .sorted()
                for duplicateKey in duplicatePlacementKeys {
                    diagnostics.append(diagnostic(
                        code: "migration-manifest-duplicate-key",
                        message: "placementMocksに重複placement key \(duplicateKey) があります。",
                        path: path
                    ))
                }
                result.append(contentsOf: placements)
            }
        }
    }

    private static func member(
        named name: String,
        in members: [Member],
        jsonPath: String,
        sourcePath: String,
        diagnostics: inout [OpenGraphiteDiagnostic]
    ) -> Member? {
        let matches = members.filter { $0.key == name }
        guard matches.count <= 1 else {
            diagnostics.append(diagnostic(
                code: "migration-manifest-duplicate-key",
                message: "\(jsonPath) に重複key \(name) があります。",
                path: sourcePath
            ))
            return nil
        }
        return matches.first
    }

    private static func removal(for member: Member) -> Replacement {
        if let commaAfter = member.commaAfter {
            return Replacement(range: member.keyRange.lowerBound..<commaAfter.upperBound, value: "")
        }
        if let commaBefore = member.commaBefore {
            return Replacement(range: commaBefore.lowerBound..<member.value.range.upperBound, value: "")
        }
        return Replacement(range: member.keyRange.lowerBound..<member.value.range.upperBound, value: "")
    }

    private static func jsonString(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func applying(_ replacements: [Replacement], to source: String) -> String {
        var result = source
        for replacement in replacements.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            let lower = result.index(result.startIndex, offsetBy: replacement.range.lowerBound)
            let upper = result.index(result.startIndex, offsetBy: replacement.range.upperBound)
            result.replaceSubrange(lower..<upper, with: replacement.value)
        }
        return result
    }

    private static func diagnostic(code: String, message: String, path: String) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(severity: .error, code: code, message: message, path: path, nodeID: nil)
    }
}

/// 論理名（日本語）: Project Web契約移行engine
/// 概要: 登録source snapshot、SHA-256 proposal、staged multi-file applyを単一経路へ集約します。
private struct OpenGraphiteProjectMigrationEngine {
    private enum SourceKind: String {
        case manifest
        case html
        case css
        case runtime
    }

    private struct PendingSource {
        var authoredURL: URL
        var kind: SourceKind
        var required: Bool
    }

    private struct Source {
        var authoredURL: URL
        var url: URL
        var relativePath: String
        var kind: SourceKind
        var before: String
        var after: String
        var beforeData: Data
        var afterData: Data
        var existedBefore: Bool
    }

    private struct StagedSource {
        var source: Source
        var stagedURL: URL
        var backupURL: URL
        var originalPermissions: NSNumber?
        var originalPermissionsWereRestored: Bool
    }

    private var willCommitSource: ((Int, URL) -> Void)?

    /// 論理名（日本語）: Project Web契約移行engine初期化関数
    /// 処理概要: productionではnil、transaction race fixtureではcommit直前observerを保持します。
    init(willCommitSource: ((Int, URL) -> Void)? = nil) {
        self.willCommitSource = willCommitSource
    }

    /// 論理名（日本語）: Project Web契約移行実行関数
    /// 処理概要: 登録sourceを候補化し、errorが1件でもあればwriteを開始せず、dry-runまたはatomic apply結果を返します。
    ///
    /// - Parameters:
    ///   - projectURL: 対象`.ogp` file URL。
    ///   - targetVersion: 明示するWeb contract target version。
    ///   - options: proposalに束縛するmigration options。
    ///   - proposalReference: apply時に検証するdry-run proposal token。
    ///   - apply: `true`の場合だけstaged transactionをcommitします。
    ///   - contract: target versionとmigration policyの正本。
    /// - Returns: source version、proposal、path順diff、diagnosticsを持つmigration結果。
    func migrate(
        projectURL: URL,
        targetVersion: String,
        options: OpenGraphiteProjectMigrationOptions,
        proposalReference: String?,
        apply: Bool,
        contract: OpenGraphiteContract
    ) throws -> OpenGraphiteProjectMigrationResult {
        let supportedTarget = contract.migrationPolicy.targetVersion
        guard targetVersion == supportedTarget else {
            return result(
                targetVersion: targetVersion,
                apply: apply,
                diagnostics: [diagnostic(
                    code: "unsupported-migration-target-version",
                    message: "target version \(targetVersion) は未対応です。対応versionは \(supportedTarget) です。",
                    path: projectURL.path
                )]
            )
        }
        guard options.legacyCatalogVersion == "1" else {
            return result(
                targetVersion: targetVersion,
                apply: apply,
                diagnostics: [diagnostic(
                    code: "unsupported-migration-catalog-version",
                    message: "legacy catalog version \(options.legacyCatalogVersion) は未対応です。",
                    path: projectURL.path
                )]
            )
        }
        guard options.preserveUnknownDataAttributes else {
            return result(
                targetVersion: targetVersion,
                apply: apply,
                diagnostics: [diagnostic(
                    code: "unsupported-migration-options",
                    message: "catalog version 1はpreserveUnknownDataAttributes=trueだけをサポートします。",
                    path: projectURL.path
                )]
            )
        }
        if apply, proposalReference?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return result(
                targetVersion: targetVersion,
                apply: true,
                diagnostics: [diagnostic(
                    code: "migration-apply-requires-proposal",
                    message: "applyには同じtarget/optionsで実行したdry-runのproposalReferenceが必要です。",
                    path: projectURL.path
                )]
            )
        }

        let loaded: LoadedOpenGraphiteProject
        do {
            loaded = try ProjectLoader().loadProject(at: projectURL)
        } catch {
            var loadDiagnostics: [OpenGraphiteDiagnostic] = []
            if apply {
                loadDiagnostics.append(diagnostic(
                    code: "stale-migration-proposal",
                    message: "proposal作成後にprojectまたは登録sourceが読み込めない状態へ変更されました。全fileを再度dry-runしてください。",
                    path: projectURL.path
                ))
            }
            if case ProjectLoadError.missingHTML(let missingURL) = error {
                loadDiagnostics.append(diagnostic(
                    code: "migration-registered-resource-missing",
                    message: "proposalが束縛した登録resourceが見つかりません。",
                    path: missingURL.path
                ))
            } else {
                loadDiagnostics.append(diagnostic(
                    code: "migration-project-load-failed",
                    message: "projectをmigration用に読み込めません: \(error.localizedDescription)",
                    path: projectURL.path
                ))
            }
            return result(
                targetVersion: targetVersion,
                apply: apply,
                diagnostics: loadDiagnostics
            )
        }
        let resolvedRoot = loaded.rootURL.standardizedFileURL.resolvingSymlinksInPath()
        var diagnostics: [OpenGraphiteDiagnostic] = []
        var detectedLegacy = false
        var pendingSources: [PendingSource] = [PendingSource(
            authoredURL: loaded.fileURL,
            kind: .manifest,
            required: true
        )]
        var hasUnresolvedExternalStylesheet = false
        var hasUnresolvedExternalBase = false
        var hasUnresolvedExternalRuntime = false
        var hasUnsupportedImportReference = false
        var hasUnsupportedRuntimeDependency = false
        pendingSources.append(PendingSource(authoredURL: loaded.cssURL, kind: .css, required: true))
        var registeredHTMLURLs: [URL] = []
        var runtimeStyleElementIDsByPath: [String: Set<String>] = [:]
        var runtimeCSSOwnerElementIDsByPath: [String: Set<String>] = [:]
        for page in loaded.project.allPages {
            let htmlURL = loaded.htmlURL(for: page)
            pendingSources.append(PendingSource(authoredURL: htmlURL, kind: .html, required: true))
            registeredHTMLURLs.append(htmlURL)
            let companionURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
            if FileManager.default.fileExists(atPath: companionURL.path) {
                pendingSources.append(PendingSource(authoredURL: companionURL, kind: .css, required: true))
            }
        }
        for htmlURL in registeredHTMLURLs {
            guard let html = utf8Source(at: htmlURL) else { continue }
            let document = OpenGraphiteHTMLDocument(html: html)
            let localStyleElementIDs = document.authoredStyleElementIDs()
            let localCSSOwnerElementIDs = document.authoredCSSOwnerIDs()
            let tags = document.parsedTags()
            func isHTMLASCIIWhitespace(_ character: Character) -> Bool {
                !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
                    scalar.value == 0x09
                        || scalar.value == 0x0A
                        || scalar.value == 0x0C
                        || scalar.value == 0x0D
                        || scalar.value == 0x20
                }
            }
            func hasStylesheetRel(_ tag: OpenGraphiteHTMLTag) -> Bool {
                tag.attributeValue(named: "rel")?
                    .split(whereSeparator: isHTMLASCIIWhitespace)
                    .contains { $0.lowercased() == "stylesheet" } == true
            }
            var baseURL = htmlURL
            if let baseTag = tags.first(where: {
                $0.tagName == "base" && $0.attributeValue(named: "href") != nil
            }) {
                if baseTag.containsUnresolvedHTMLCharacterReference(named: "href") {
                    hasUnresolvedExternalBase = true
                    continue
                }
                let base = baseTag.attributeValue(named: "href") ?? ""
                guard let resolved = URL(string: base, relativeTo: htmlURL)?.absoluteURL,
                      resolved.isFileURL
                else {
                    hasUnresolvedExternalBase = true
                    continue
                }
                baseURL = resolved
            }
            for tag in tags where tag.tagName == "style" {
                if tag.containsUnresolvedHTMLCharacterReference(named: "type") {
                    hasUnresolvedExternalStylesheet = true
                }
            }
            for tag in tags where tag.tagName == "link" && hasStylesheetRel(tag) {
                if tag.containsUnresolvedHTMLCharacterReference(named: "href")
                    || tag.containsUnresolvedHTMLCharacterReference(named: "type") {
                    hasUnresolvedExternalStylesheet = true
                }
            }
            for tag in tags where tag.tagName == "script" {
                if tag.containsUnresolvedHTMLCharacterReference(named: "src")
                    || tag.containsUnresolvedHTMLCharacterReference(named: "type")
                    || tag.containsUnresolvedHTMLCharacterReference(named: "language") {
                    hasUnresolvedExternalRuntime = true
                }
            }
            for tag in tags where document.isCSSStylesheetLinkTag(tag) {
                guard !tag.containsUnresolvedHTMLCharacterReference(named: "href"),
                      !tag.containsUnresolvedHTMLCharacterReference(named: "type")
                else { continue }
                guard let href = tag.attributeValue(named: "href"),
                      let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL
                else { continue }
                if resolved.isFileURL {
                    pendingSources.append(PendingSource(authoredURL: resolved, kind: .css, required: false))
                }
                else { hasUnresolvedExternalStylesheet = true }
            }
            for tag in tags where document.isExecutableScriptTag(tag) {
                guard !tag.containsUnresolvedHTMLCharacterReference(named: "src"),
                      !tag.containsUnresolvedHTMLCharacterReference(named: "type"),
                      !tag.containsUnresolvedHTMLCharacterReference(named: "language")
                else { continue }
                guard let src = tag.attributeValue(named: "src") else { continue }
                guard let resolved = URL(string: src, relativeTo: baseURL)?.absoluteURL
                else {
                    hasUnresolvedExternalRuntime = true
                    continue
                }
                if resolved.isFileURL {
                    pendingSources.append(PendingSource(authoredURL: resolved, kind: .runtime, required: false))
                    let runtimePath = resolved.standardizedFileURL.resolvingSymlinksInPath().path
                    runtimeStyleElementIDsByPath[runtimePath, default: []]
                        .formUnion(localStyleElementIDs)
                    runtimeCSSOwnerElementIDsByPath[runtimePath, default: []]
                        .formUnion(localCSSOwnerElementIDs)
                } else {
                    hasUnresolvedExternalRuntime = true
                }
            }
            for stylesheet in document.embeddedStylesheetReferences() {
                let imports = localCSSImportReferences(in: stylesheet.content)
                hasUnsupportedImportReference = hasUnsupportedImportReference || imports.hasUnsupportedReference
                for importReference in imports.references {
                    guard let resolved = URL(string: importReference, relativeTo: baseURL)?.absoluteURL else {
                        hasUnsupportedImportReference = true
                        continue
                    }
                    if resolved.isFileURL {
                        pendingSources.append(PendingSource(authoredURL: resolved, kind: .css, required: false))
                    } else {
                        hasUnresolvedExternalStylesheet = true
                    }
                }
            }
        }
        var cssDependencyCursor = 0
        var inspectedCSSDependencyPaths: Set<String> = []
        while cssDependencyCursor < pendingSources.count {
            let pending = pendingSources[cssDependencyCursor]
            cssDependencyCursor += 1
            guard pending.kind == .css else { continue }
            let cssURL = pending.authoredURL.standardizedFileURL
            let resolvedCSSURL = cssURL.resolvingSymlinksInPath()
            guard contains(resolvedCSSURL, in: resolvedRoot),
                  inspectedCSSDependencyPaths.insert(resolvedCSSURL.path).inserted,
                  let css = utf8Source(at: resolvedCSSURL)
            else { continue }
            let imports = localCSSImportReferences(in: css)
            hasUnsupportedImportReference = hasUnsupportedImportReference || imports.hasUnsupportedReference
            for importReference in imports.references {
                guard let resolved = URL(string: importReference, relativeTo: cssURL)?.absoluteURL else {
                    hasUnsupportedImportReference = true
                    continue
                }
                if resolved.isFileURL {
                    pendingSources.append(PendingSource(authoredURL: resolved, kind: .css, required: false))
                }
                else { hasUnresolvedExternalStylesheet = true }
            }
        }

        var sources: [Source] = []
        var seenKindsByPath: [String: SourceKind] = [:]
        var generatedClassNames: Set<String> = []
        var existingClassNames: Set<String> = []
        var generatedDestinationAttributes: Set<String> = []
        var observedDestinationAttributes: Set<String> = []
        var removedLegacyDatasetAttributeNames: Set<String> = []
        var hasWholeDatasetRuntimeObserver = false
        var hasGeneratedClassObserver = false
        var hasGeneratedCustomPropertyObserver = false
        var hasWholeStyleObserver = false
        var hasInlineStyleMutation = false
        var hasHTMLSourceMutation = false
        var hasHTMLAttributeMutation = false
        var hasEmbeddedStyleMutation = false
        var hasExternalCSSSourceMutation = false
        var hasManifestSourceMutation = false
        var hasWholeAttributeRuntimeObserver = false
        var hasWholeMarkupRuntimeObserver = false
        var hasCSSOMRuntimeObserver = false
        var hasStyleTextRuntimeObserver = false
        var hasPreviewContextRuntimeObserver = false
        var generatedPreviewHostFields: Set<String> = []
        var observedPreviewHostFields: Set<String> = []
        var hasDynamicSelectorRuntimeObserver = false
        var hasAttributeNodeRuntimeObserver = false
        var generatedCustomPropertyNames: Set<String> = []
        var authoredCustomPropertyNames: Set<String> = []
        var deferredKindConflicts: [(path: String, existing: SourceKind, requested: SourceKind)] = []
        var missingDiscoveredDependencies: Set<String> = []
        var deferredDiscoveredDiagnostics: [OpenGraphiteDiagnostic] = []
        for pending in pendingSources {
            let standardizedURL = pending.authoredURL.standardizedFileURL
            let resolvedURL = standardizedURL.resolvingSymlinksInPath()
            guard contains(resolvedURL, in: resolvedRoot) else {
                let containmentDiagnostic = diagnostic(
                    code: "migration-resource-outside-project-root",
                    message: "\(pending.kind.rawValue) resourceはsymlink解決後のproject root内にある必要があります。",
                    path: standardizedURL.path
                )
                if pending.required {
                    diagnostics.append(containmentDiagnostic)
                } else {
                    deferredDiscoveredDiagnostics.append(containmentDiagnostic)
                }
                continue
            }
            let relativePath = relativePath(of: resolvedURL, from: resolvedRoot)
            if let existingKind = seenKindsByPath[relativePath] {
                if existingKind != pending.kind {
                    deferredKindConflicts.append((relativePath, existingKind, pending.kind))
                }
                continue
            }
            seenKindsByPath[relativePath] = pending.kind
            let existedBefore = FileManager.default.fileExists(atPath: resolvedURL.path)
            guard existedBefore else {
                if pending.required {
                    diagnostics.append(diagnostic(
                        code: "migration-registered-resource-missing",
                        message: "登録resourceが見つかりません。",
                        path: relativePath
                    ))
                } else {
                    missingDiscoveredDependencies.insert(relativePath)
                }
                sources.append(Source(
                    authoredURL: standardizedURL,
                    url: resolvedURL,
                    relativePath: relativePath,
                    kind: pending.kind,
                    before: "",
                    after: "",
                    beforeData: Data(),
                    afterData: Data(),
                    existedBefore: false
                ))
                continue
            }
            let beforeData: Data
            do {
                beforeData = existedBefore ? try Data(contentsOf: resolvedURL) : Data()
            } catch {
                let unreadableDiagnostic = diagnostic(
                    code: "migration-source-unreadable",
                    message: "UTF-8 sourceを読み込めません: \(error.localizedDescription)",
                    path: relativePath
                )
                if pending.required {
                    diagnostics.append(unreadableDiagnostic)
                } else {
                    deferredDiscoveredDiagnostics.append(unreadableDiagnostic)
                }
                continue
            }
            guard let before = decodeUTF8Source(beforeData) else {
                let invalidUTF8Diagnostic = diagnostic(
                    code: "migration-source-unreadable",
                    message: "sourceはvalid UTF-8である必要があります。",
                    path: relativePath
                )
                if pending.required {
                    diagnostics.append(invalidUTF8Diagnostic)
                } else {
                    deferredDiscoveredDiagnostics.append(invalidUTF8Diagnostic)
                }
                continue
            }
            var after = before
            if pending.kind == .manifest {
                let migration = OpenGraphiteLegacyManifestMigrator.migrate(before, path: relativePath)
                detectedLegacy = detectedLegacy || migration.detectedLegacy
                diagnostics.append(contentsOf: migration.diagnostics)
                after = migration.source
                hasManifestSourceMutation = hasManifestSourceMutation || migration.source != before
                generatedPreviewHostFields.formUnion(migration.generatedHostFields)
            } else if pending.kind == .html {
                let migration = OpenGraphiteHTMLDocument(html: before).migratingLegacyWebContract(path: relativePath)
                detectedLegacy = detectedLegacy || migration.detectedLegacy
                diagnostics.append(contentsOf: migration.diagnostics)
                generatedClassNames.formUnion(migration.generatedClassNames)
                existingClassNames.formUnion(migration.existingClassNames)
                generatedDestinationAttributes.formUnion(migration.generatedDestinationAttributes)
                observedDestinationAttributes.formUnion(migration.observedDestinationAttributes)
                removedLegacyDatasetAttributeNames.formUnion(migration.removedLegacyDatasetAttributeNames)
                hasWholeDatasetRuntimeObserver = hasWholeDatasetRuntimeObserver
                    || migration.hasWholeDatasetRuntimeObserver
                hasGeneratedClassObserver = hasGeneratedClassObserver || migration.hasGeneratedClassObserver
                hasGeneratedCustomPropertyObserver = hasGeneratedCustomPropertyObserver
                    || migration.hasGeneratedCustomPropertyStyleObserver
                    || migration.hasGeneratedCustomPropertyRuntimeObserver
                hasWholeStyleObserver = hasWholeStyleObserver
                    || migration.hasGeneratedCustomPropertyStyleObserver
                    || migration.hasWholeStyleRuntimeObserver
                hasInlineStyleMutation = hasInlineStyleMutation || migration.hasInlineStyleMutation
                hasHTMLSourceMutation = hasHTMLSourceMutation || migration.hasHTMLSourceMutation
                hasHTMLAttributeMutation = hasHTMLAttributeMutation || migration.hasHTMLAttributeMutation
                hasEmbeddedStyleMutation = hasEmbeddedStyleMutation || migration.hasEmbeddedStyleMutation
                hasWholeAttributeRuntimeObserver = hasWholeAttributeRuntimeObserver
                    || migration.hasWholeAttributeRuntimeObserver
                hasWholeMarkupRuntimeObserver = hasWholeMarkupRuntimeObserver
                    || migration.hasWholeMarkupRuntimeObserver
                hasCSSOMRuntimeObserver = hasCSSOMRuntimeObserver || migration.hasCSSOMRuntimeObserver
                hasStyleTextRuntimeObserver = hasStyleTextRuntimeObserver
                    || migration.hasStyleTextRuntimeObserver
                hasPreviewContextRuntimeObserver = hasPreviewContextRuntimeObserver
                    || migration.hasPreviewContextRuntimeObserver
                observedPreviewHostFields.formUnion(migration.observedPreviewHostFields)
                hasDynamicSelectorRuntimeObserver = hasDynamicSelectorRuntimeObserver
                    || migration.hasDynamicSelectorRuntimeObserver
                hasAttributeNodeRuntimeObserver = hasAttributeNodeRuntimeObserver
                    || migration.hasAttributeNodeRuntimeObserver
                generatedCustomPropertyNames.formUnion(migration.generatedCustomPropertyNames)
                authoredCustomPropertyNames.formUnion(migration.authoredCustomPropertyNames)
                hasUnsupportedRuntimeDependency = hasUnsupportedRuntimeDependency
                    || migration.hasUnsupportedRuntimeDependency
                after = migration.source
            } else if pending.kind == .css {
                let migration = OpenGraphiteLegacyCSSMigrator.migrate(before)
                detectedLegacy = detectedLegacy || migration.detectedLegacy
                generatedClassNames.formUnion(migration.generatedClassNames)
                existingClassNames.formUnion(migration.existingGeneratedClassNames)
                observedDestinationAttributes.formUnion(migration.observedDestinationAttributes)
                hasGeneratedClassObserver = hasGeneratedClassObserver || migration.hasGeneratedClassObserver
                hasGeneratedCustomPropertyObserver = hasGeneratedCustomPropertyObserver
                    || migration.hasGeneratedCustomPropertyStyleObserver
                hasWholeStyleObserver = hasWholeStyleObserver
                    || migration.hasGeneratedCustomPropertyStyleObserver
                generatedCustomPropertyNames.formUnion(migration.generatedCustomPropertyNames)
                authoredCustomPropertyNames.formUnion(migration.authoredCustomPropertyNames)
                after = migration.source
                hasExternalCSSSourceMutation = hasExternalCSSSourceMutation || migration.source != before
                for property in migration.unknownReservedProperties {
                    diagnostics.append(diagnostic(
                        code: "unknown-legacy-css-property",
                        message: "mapping catalogにないreserved custom property \(property) は移行できません。",
                        path: relativePath
                    ))
                }
                for construct in migration.unsupportedLegacyConstructs {
                    diagnostics.append(diagnostic(
                        code: "unsupported-legacy-css-construct",
                        message: "losslessに変換できないlegacy CSS構文です: \(construct)",
                        path: relativePath
                    ))
                }
                for destination in migration.destinationConflicts {
                    diagnostics.append(diagnostic(
                        code: "legacy-css-destination-conflict",
                        message: "legacy custom propertyの移行先 \(destination) がauthored declarationと競合します。",
                        path: relativePath
                    ))
                }
            } else if pending.kind == .runtime {
                let linkedStyleElementIDs = runtimeStyleElementIDsByPath[resolvedURL.path] ?? []
                let linkedCSSOwnerElementIDs = runtimeCSSOwnerElementIDsByPath[resolvedURL.path] ?? []
                hasUnsupportedRuntimeDependency = hasUnsupportedRuntimeDependency
                    || containsLocalRuntimeDependency(before)
                observedDestinationAttributes.formUnion(
                    OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(before)
                )
                hasGeneratedClassObserver = hasGeneratedClassObserver
                    || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver(before)
                hasGeneratedCustomPropertyObserver = hasGeneratedCustomPropertyObserver
                    || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedCustomPropertyObserver(before)
                hasWholeDatasetRuntimeObserver = hasWholeDatasetRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeDatasetObserver(before)
                hasWholeStyleObserver = hasWholeStyleObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeStyleObserver(before)
                hasWholeAttributeRuntimeObserver = hasWholeAttributeRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(before)
                hasWholeMarkupRuntimeObserver = hasWholeMarkupRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeMarkupObserver(before)
                hasCSSOMRuntimeObserver = hasCSSOMRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(
                        before,
                        authoredCSSOwnerIDs: linkedCSSOwnerElementIDs
                    )
                hasStyleTextRuntimeObserver = hasStyleTextRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
                        before,
                        authoredStyleIDs: linkedStyleElementIDs
                    )
                hasPreviewContextRuntimeObserver = hasPreviewContextRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(before)
                observedPreviewHostFields.formUnion(
                    OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(before)
                )
                hasDynamicSelectorRuntimeObserver = hasDynamicSelectorRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasDynamicSelectorObserver(before)
                hasAttributeNodeRuntimeObserver = hasAttributeNodeRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasAttributeNodeObserver(before)
                if containsLegacyRuntimeSource(before) {
                    detectedLegacy = true
                    diagnostics.append(diagnostic(
                        code: "unsupported-legacy-runtime-source",
                        message: "local runtime sourceにcatalog v1で自動変換しないlegacy readerがあります。runtimeを標準hookへ更新してから再実行してください。",
                        path: relativePath
                    ))
                }
            }
            sources.append(Source(
                authoredURL: standardizedURL,
                url: resolvedURL,
                relativePath: relativePath,
                kind: pending.kind,
                before: before,
                after: after,
                beforeData: beforeData,
                afterData: encodeUTF8Source(after, preservingBOMFrom: beforeData),
                existedBefore: existedBefore
            ))
        }
        let generatedConflicts = generatedClassNames.intersection(existingClassNames)
        for className in generatedConflicts.sorted() {
            diagnostics.append(diagnostic(
                code: "migration-generated-class-conflict",
                message: "migration専用class .\(className) はauthored sourceですでに使われています。",
                path: nil
            ))
        }
        if !generatedClassNames.isEmpty, hasGeneratedClassObserver {
            diagnostics.append(diagnostic(
                code: "migration-generated-class-conflict",
                message: "authored CSS/runtimeがclass属性またはmigration class namespaceを観測するため、generated class追加後のmatchを安全に証明できません。",
                path: nil
            ))
        }
        if !removedLegacyDatasetAttributeNames.isEmpty, hasWholeDatasetRuntimeObserver {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-runtime-source",
                message: "authored runtimeがdataset列全体を観測しており、migrationが削除する \(removedLegacyDatasetAttributeNames.sorted().joined(separator: ", ")) の影響を安全に証明できません。",
                path: nil
            ))
        }
        if (hasHTMLAttributeMutation && (
            hasWholeAttributeRuntimeObserver
                || hasDynamicSelectorRuntimeObserver
                || hasAttributeNodeRuntimeObserver
        )) || (hasHTMLSourceMutation && hasWholeMarkupRuntimeObserver) {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-runtime-source",
                message: "authored runtimeがHTML attribute/markup全体を観測しており、migrationによるHTML source変更の影響を安全に証明できません。",
                path: nil
            ))
        }
        if (hasExternalCSSSourceMutation && hasCSSOMRuntimeObserver)
            || (hasEmbeddedStyleMutation && (hasCSSOMRuntimeObserver || hasStyleTextRuntimeObserver)) {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-runtime-source",
                message: "authored runtimeがCSSOMまたはstyle本文全体を観測しており、migrationによるCSS source変更の影響を安全に証明できません。",
                path: nil
            ))
        }
        if hasManifestSourceMutation,
           hasPreviewContextRuntimeObserver
            || !generatedPreviewHostFields.intersection(observedPreviewHostFields).isEmpty {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-runtime-source",
                message: "authored runtimeがpreview context全体を観測しており、manifest migrationの影響を安全に証明できません。",
                path: nil
            ))
        }
        let destinationAttributeConflicts = generatedDestinationAttributes.intersection(observedDestinationAttributes)
        for attributeName in destinationAttributeConflicts.sorted() {
            diagnostics.append(diagnostic(
                code: "legacy-html-destination-conflict",
                message: "migrationが追加する\(attributeName)属性をauthored CSSがすでに観測しており、移行前後のmatchを安全に証明できません。",
                path: nil
            ))
        }
        let customPropertyConflicts = generatedCustomPropertyNames.intersection(authoredCustomPropertyNames)
        for propertyName in customPropertyConflicts.sorted() {
            diagnostics.append(diagnostic(
                code: "legacy-css-destination-conflict",
                message: "legacy custom propertyのmigration destination \(propertyName) は別sourceのauthored declarationと競合します。",
                path: nil
            ))
        }
        if (!generatedCustomPropertyNames.isEmpty && hasGeneratedCustomPropertyObserver)
            || (hasInlineStyleMutation && hasWholeStyleObserver) {
            diagnostics.append(diagnostic(
                code: "legacy-css-destination-conflict",
                message: "authored selector/runtimeがmigration destination custom propertyを観測するため、移行前後のmatchを安全に証明できません。",
                path: nil
            ))
        }
        if detectedLegacy {
            for conflict in deferredKindConflicts.sorted(by: {
                ($0.path, $0.existing.rawValue, $0.requested.rawValue)
                    < ($1.path, $1.existing.rawValue, $1.requested.rawValue)
            }) {
                diagnostics.append(diagnostic(
                    code: "migration-resource-kind-conflict",
                    message: "同一resourceが\(conflict.existing.rawValue)と\(conflict.requested.rawValue)の異なるsource kindで参照されています。",
                    path: conflict.path
                ))
            }
            for path in missingDiscoveredDependencies.sorted() {
                diagnostics.append(diagnostic(
                    code: "migration-registered-resource-missing",
                    message: "legacy projectが参照するlocal dependencyが見つかりません。",
                    path: path
                ))
            }
            diagnostics.append(contentsOf: deferredDiscoveredDiagnostics)
        }
        if detectedLegacy, hasUnresolvedExternalStylesheet {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-external-stylesheet",
                message: "external stylesheetがlegacy cascadeへ与える影響を検証できません。",
                path: nil
            ))
        }
        if detectedLegacy, hasUnresolvedExternalBase {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-external-base",
                message: "externalまたは解決不能なbase URLを介したdependencyは安全に列挙できません。",
                path: nil
            ))
        }
        if detectedLegacy, hasUnresolvedExternalRuntime {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-external-runtime",
                message: "external runtime sourceがlegacy Web契約をread/writeする可能性を検証できません。",
                path: nil
            ))
        }
        if detectedLegacy, hasUnsupportedImportReference {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-import-reference",
                message: "CSS @import URLをlosslessかつ一意に解決できません。",
                path: nil
            ))
        }
        if detectedLegacy, hasUnsupportedRuntimeDependency {
            diagnostics.append(diagnostic(
                code: "unsupported-legacy-runtime-dependency",
                message: "local runtimeのmodule dependency closureはcatalog v1で安全に列挙できません。単一sourceへ解決するかstandard runtimeへ更新してください。",
                path: nil
            ))
        }
        sources.sort { $0.relativePath < $1.relativePath }

        let proposal = makeProposalReference(
            targetVersion: targetVersion,
            options: options,
            sources: sources,
            projectURL: loaded.fileURL.standardizedFileURL.resolvingSymlinksInPath()
        )
        let diffs = sources.compactMap { source -> OpenGraphiteSourceDiff? in
            guard source.beforeData != source.afterData else { return nil }
            return OpenGraphiteSourceDiff(
                path: source.relativePath,
                beforeHash: sha256(source.beforeData),
                afterHash: sha256(source.afterData),
                unifiedDiff: unifiedDiff(
                    before: source.before,
                    after: source.after,
                    path: source.relativePath
                )
            )
        }
        var hasError = diagnostics.contains { $0.severity == .error }
        if apply, proposalReference != proposal {
            diagnostics.append(diagnostic(
                code: "stale-migration-proposal",
                message: "proposal作成後にprojectまたは登録sourceが変更されました。全fileを再度dry-runしてください。",
                path: relativePath(
                    of: loaded.fileURL.standardizedFileURL.resolvingSymlinksInPath(),
                    from: resolvedRoot
                )
            ))
            hasError = true
        }
        guard apply else {
            if hasError {
                return OpenGraphiteProjectMigrationResult(
                    schemaVersion: OpenGraphiteAgentCore.schemaVersion,
                    sourceContractVersion: detectedLegacy ? "0.1.0" : targetVersion,
                    targetContractVersion: targetVersion,
                    dryRun: true,
                    applied: false,
                    changed: false,
                    proposalReference: nil,
                    diffs: [],
                    diagnostics: diagnostics
                )
            }
            return OpenGraphiteProjectMigrationResult(
                schemaVersion: OpenGraphiteAgentCore.schemaVersion,
                sourceContractVersion: detectedLegacy ? "0.1.0" : targetVersion,
                targetContractVersion: targetVersion,
                dryRun: true,
                applied: false,
                changed: !diffs.isEmpty,
                proposalReference: hasError ? nil : proposal,
                diffs: diffs,
                diagnostics: diagnostics
            )
        }
        guard !hasError, proposalReference == proposal else {
            return OpenGraphiteProjectMigrationResult(
                schemaVersion: OpenGraphiteAgentCore.schemaVersion,
                sourceContractVersion: detectedLegacy ? "0.1.0" : targetVersion,
                targetContractVersion: targetVersion,
                dryRun: false,
                applied: false,
                changed: false,
                proposalReference: nil,
                diffs: [],
                diagnostics: diagnostics
            )
        }
        if diffs.isEmpty {
            return OpenGraphiteProjectMigrationResult(
                schemaVersion: OpenGraphiteAgentCore.schemaVersion,
                sourceContractVersion: targetVersion,
                targetContractVersion: targetVersion,
                dryRun: false,
                applied: true,
                changed: false,
                proposalReference: proposal,
                diffs: [],
                diagnostics: []
            )
        }

        let changedSources = sources.filter { $0.beforeData != $0.afterData }
        let applyDiagnostics = stagedApply(changedSources, snapshots: sources, root: resolvedRoot)
        diagnostics.append(contentsOf: applyDiagnostics)
        if !applyDiagnostics.isEmpty {
            return result(
                targetVersion: targetVersion,
                apply: true,
                diagnostics: diagnostics
            )
        }
        return OpenGraphiteProjectMigrationResult(
            schemaVersion: OpenGraphiteAgentCore.schemaVersion,
            sourceContractVersion: "0.1.0",
            targetContractVersion: targetVersion,
            dryRun: false,
            applied: applyDiagnostics.isEmpty,
            changed: true,
            proposalReference: proposal,
            diffs: diffs,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: Project migration失敗応答生成関数
    /// 処理概要: proposalまたはdiffを公開できないblocking状態を、無変更の共通result contractへ変換します。
    ///
    /// - Parameters:
    ///   - targetVersion: 応答に記録するWeb contract target version。
    ///   - apply: 要求がapplyだった場合は`dryRun` truth valueを反転するflag。
    ///   - diagnostics: blocking理由を示すstructured diagnostics。
    /// - Returns: `changed: false`、空diff、proposalなしのproject migration応答。
    private func result(
        targetVersion: String,
        apply: Bool,
        diagnostics: [OpenGraphiteDiagnostic]
    ) -> OpenGraphiteProjectMigrationResult {
        OpenGraphiteProjectMigrationResult(
            schemaVersion: OpenGraphiteAgentCore.schemaVersion,
            sourceContractVersion: "0.1.0",
            targetContractVersion: targetVersion,
            dryRun: !apply,
            applied: false,
            changed: false,
            proposalReference: nil,
            diffs: [],
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: Project migration proposal生成関数
    /// 処理概要: project identity、target、options、全sourceのpath・存在bit・SHA-256を決定的なapply専用tokenへ束縛します。
    ///
    /// - Parameters:
    ///   - targetVersion: 束縛するWeb contract target version。
    ///   - options: 束縛するmigration options。
    ///   - sources: manifestを含むcanonical source snapshot。
    ///   - projectURL: project identityに使うcanonical `.ogp` URL。
    /// - Returns: SHA-256で安定化したapply専用proposal reference。
    private func makeProposalReference(
        targetVersion: String,
        options: OpenGraphiteProjectMigrationOptions,
        sources: [Source],
        projectURL: URL
    ) -> String {
        let projectPath = projectURL.path
        let projectHash = sources.first(where: { $0.url.path == projectPath }).map { sha256($0.beforeData) } ?? sha256(Data())
        var components = [
            "migration-proposal:v1",
            "project-url:\(projectURL.absoluteString.utf8.count):\(projectURL.absoluteString)",
            "target:\(targetVersion.utf8.count):\(targetVersion)",
            "catalog:\(options.legacyCatalogVersion.utf8.count):\(options.legacyCatalogVersion)",
            "preserve-unknown-data:\(options.preserveUnknownDataAttributes)",
            "project-sha256:\(projectHash)"
        ]
        components.append(contentsOf: sources.map { source in
            "source:\(source.relativePath.utf8.count):\(source.relativePath):kind=\(source.kind.rawValue):exists=\(source.existedBefore):\(sha256(source.beforeData))"
        })
        return "ogref-session:migration:\(sha256(components.joined(separator: "|")))"
    }

    /// 論理名（日本語）: Project migration staged apply関数
    /// 処理概要: 全candidateをstageしてsnapshotを再検証し、commit失敗時はbytesとpermissionをrollbackします。
    ///
    /// - Parameters:
    ///   - sources: 適用前後sourceとauthored/resolved URLを持つtransaction candidate。
    ///   - snapshots: proposalへ束縛した変更有無を問わない全dependency snapshot。
    ///   - root: symlink再解決後のcontainmentを検証するproject root。
    /// - Returns: 成功時は空、失敗時はwriteとoptional rollbackのstructured diagnostics。
    private func stagedApply(
        _ sources: [Source],
        snapshots: [Source],
        root: URL
    ) -> [OpenGraphiteDiagnostic] {
        var staged: [StagedSource] = []
        do {
            for source in sources {
                let nonce = UUID().uuidString.lowercased()
                let directory = source.url.deletingLastPathComponent()
                let stagedURL = directory.appendingPathComponent(".og-migration-\(nonce).stage")
                let backupURL = directory.appendingPathComponent(".og-migration-\(nonce).backup")
                let permissions: NSNumber?
                if source.existedBefore,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: source.url.path) {
                    permissions = attributes[.posixPermissions] as? NSNumber
                } else {
                    permissions = nil
                }
                staged.append(StagedSource(
                    source: source,
                    stagedURL: stagedURL,
                    backupURL: backupURL,
                    originalPermissions: permissions,
                    originalPermissionsWereRestored: false
                ))
                try source.afterData.write(to: stagedURL, options: [.atomic])
                try source.beforeData.write(to: backupURL, options: [.atomic])
            }
        } catch {
            cleanup(staged)
            return [diagnostic(
                code: "migration-write-failed",
                message: "全candidateのstagingに失敗したためsourceは変更していません: \(error.localizedDescription)",
                path: staged.last?.source.relativePath
            )]
        }

        for source in snapshots {
            guard sourceSnapshotMatches(
                source,
                expectedData: source.beforeData,
                expectedExistence: source.existedBefore,
                root: root
            ) else {
                cleanup(staged)
                return [diagnostic(
                    code: "stale-migration-proposal",
                    message: "staging後のcommit直前にsource snapshotまたはpath解決が変化しました。全fileを再度dry-runしてください。",
                    path: source.relativePath
                )]
            }
        }

        var committed: [StagedSource] = []
        var committingPath: String?
        do {
            for (index, item) in staged.enumerated() {
                committingPath = item.source.relativePath
                willCommitSource?(index, item.source.authoredURL)
                let committedPaths = Set(committed.map(\.source.relativePath))
                let staleSource = snapshots.first { source in
                    let isCommitted = committedPaths.contains(source.relativePath)
                    return !sourceSnapshotMatches(
                        source,
                        expectedData: isCommitted ? source.afterData : source.beforeData,
                        expectedExistence: isCommitted ? true : source.existedBefore,
                        root: root
                    )
                }
                if let staleSource {
                    let rollbackErrors = rollback(committed, root: root)
                    cleanup(staged)
                    var staleDiagnostics = [diagnostic(
                        code: "stale-migration-proposal",
                        message: "各sourceのcommit直前にsnapshotまたはpath解決が変化しました。先行commitをrollbackし、全fileを再度dry-runしてください。",
                        path: staleSource.relativePath
                    )]
                    if !rollbackErrors.isEmpty {
                        staleDiagnostics.append(diagnostic(
                            code: "migration-rollback-failed",
                            message: "stale検出後のrollbackを完了できませんでした: \(rollbackErrors.joined(separator: "; "))",
                            path: staleSource.relativePath
                        ))
                    }
                    return staleDiagnostics
                }
                let stagedData = try Data(contentsOf: item.stagedURL)
                try stagedData.write(to: item.source.url, options: [.atomic])
                committed.append(item)
                if let permissions = item.originalPermissions {
                    try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: item.source.url.path)
                    committed[committed.count - 1].originalPermissionsWereRestored = true
                }
            }
            cleanup(staged)
            return []
        } catch {
            let rollbackErrors = rollback(committed, root: root)
            cleanup(staged)
            if !rollbackErrors.isEmpty {
                return [
                    diagnostic(
                        code: "migration-write-failed",
                        message: "commitに失敗しました: \(error.localizedDescription)",
                        path: committingPath
                    ),
                    diagnostic(
                        code: "migration-rollback-failed",
                        message: "commit失敗後のrollbackを完了できませんでした: \(rollbackErrors.joined(separator: "; "))",
                        path: committingPath
                    )
                ]
            }
            return [diagnostic(
                code: "migration-write-failed",
                message: "commitに失敗し、変更済みsourceはrollbackしました: \(error.localizedDescription)",
                path: committingPath
            )]
        }
    }

    /// 論理名（日本語）: Migration rollback関数
    /// 処理概要: commit済みsourceがmigration後snapshotと一致する場合だけ、逆順でraw bytesとPOSIX permissionを復元します。
    ///
    /// - Parameters:
    ///   - committed: migration bytesを書き込み済みのtransaction source。
    ///   - root: authored symlink再解決後のcontainmentを検証するproject root。
    /// - Returns: 外部編集との競合または復元失敗を示すsource別error。
    private func rollback(_ committed: [StagedSource], root: URL) -> [String] {
        var rollbackErrors: [String] = []
        for item in committed.reversed() {
            guard rollbackSnapshotMatches(item, root: root) else {
                rollbackErrors.append(
                    "\(item.source.relativePath): migration後snapshotから外部変更されたためrollbackせず現在のbytes/modeを保持しました"
                )
                continue
            }
            do {
                if item.source.existedBefore {
                    let backupData = try Data(contentsOf: item.backupURL)
                    try backupData.write(to: item.source.url, options: [.atomic])
                    if let permissions = item.originalPermissions {
                        try FileManager.default.setAttributes(
                            [.posixPermissions: permissions],
                            ofItemAtPath: item.source.url.path
                        )
                    }
                } else if FileManager.default.fileExists(atPath: item.source.url.path) {
                    try FileManager.default.removeItem(at: item.source.url)
                }
            } catch {
                rollbackErrors.append("\(item.source.relativePath): \(error.localizedDescription)")
            }
        }
        return rollbackErrors
    }

    /// 論理名（日本語）: Migration rollback CAS照合関数
    /// 処理概要: authored path、存在、migration後raw bytesと、commitで復元済みの場合はPOSIX modeも照合します。
    ///
    /// - Parameters:
    ///   - item: rollback候補のcommit済みsource。
    ///   - root: authored symlink再解決後のcontainmentを検証するproject root。
    /// - Returns: migrationが書いた状態から外部変更されていない場合は`true`。
    private func rollbackSnapshotMatches(_ item: StagedSource, root: URL) -> Bool {
        guard sourceSnapshotMatches(
            item.source,
            expectedData: item.source.afterData,
            expectedExistence: true,
            root: root
        ) else { return false }
        guard item.originalPermissionsWereRestored,
              let expectedPermissions = item.originalPermissions
        else { return true }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: item.source.url.path),
              let currentPermissions = attributes[.posixPermissions] as? NSNumber
        else { return false }
        return currentPermissions == expectedPermissions
    }

    private func cleanup(_ staged: [StagedSource]) {
        for item in staged {
            try? FileManager.default.removeItem(at: item.stagedURL)
            try? FileManager.default.removeItem(at: item.backupURL)
        }
    }

    /// 論理名（日本語）: Migration source snapshot照合関数
    /// 処理概要: authored symlink identity、root containment、存在bit、raw bytes SHA-256をcommit直前snapshotと照合します。
    private func sourceSnapshotMatches(
        _ source: Source,
        expectedData: Data,
        expectedExistence: Bool,
        root: URL
    ) -> Bool {
        let currentResolvedURL = source.authoredURL.resolvingSymlinksInPath()
        let currentlyExists = FileManager.default.fileExists(atPath: source.authoredURL.path)
        guard currentResolvedURL == source.url,
              contains(currentResolvedURL, in: root),
              currentlyExists == expectedExistence
        else { return false }
        if !currentlyExists { return expectedData.isEmpty }
        guard let currentData = try? Data(contentsOf: currentResolvedURL) else { return false }
        return currentData == expectedData
    }

    /// 論理名（日本語）: UTF-8 source読取関数
    /// 処理概要: UTF-8 BOMをsemantic sourceから除外しつつinvalid UTF-8を拒否します。
    private func utf8Source(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decodeUTF8Source(data)
    }

    /// 論理名（日本語）: UTF-8 source decode関数
    /// 処理概要: raw Data先頭のUTF-8 BOMだけを分離し、migration transformerへ本文を渡します。
    private func decodeUTF8Source(_ data: Data) -> String? {
        let payload = data.starts(with: utf8BOM) ? Data(data.dropFirst(utf8BOM.count)) : data
        return String(data: payload, encoding: .utf8)
    }

    /// 論理名（日本語）: UTF-8 source encode関数
    /// 処理概要: candidate本文をUTF-8化し、snapshotが持っていたBOMを同じraw位置へ復元します。
    private func encodeUTF8Source(_ source: String, preservingBOMFrom beforeData: Data) -> Data {
        var result = Data()
        if beforeData.starts(with: utf8BOM) { result.append(utf8BOM) }
        result.append(contentsOf: source.utf8)
        return result
    }

    private var utf8BOM: Data {
        Data([0xEF, 0xBB, 0xBF])
    }

    private func contains(_ url: URL, in root: URL) -> Bool {
        let rootPath = root.path == "/" ? "/" : root.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let candidatePath = url.path
        return candidatePath == root.path || candidatePath.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
            || (root.path == "/" && candidatePath.hasPrefix("/"))
            || candidatePath == rootPath
    }

    private func localCSSImportReferences(in source: String) -> (references: [String], hasUnsupportedReference: Bool) {
        func isCSSWhitespace(_ character: Character) -> Bool {
            !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
                scalar.value == 0x09
                    || scalar.value == 0x0A
                    || scalar.value == 0x0C
                    || scalar.value == 0x0D
                    || scalar.value == 0x20
            }
        }
        func isCSSNameCharacter(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { scalar in
                (0x30...0x39).contains(scalar.value)
                    || (0x41...0x5A).contains(scalar.value)
                    || (0x61...0x7A).contains(scalar.value)
                    || scalar.value == 0x2D
                    || scalar.value == 0x5F
                    || scalar.value >= 0x80
            }
        }
        func skipComment(from start: String.Index) -> String.Index? {
            let next = source.index(after: start)
            guard source[start] == "/", next < source.endIndex, source[next] == "*" else { return nil }
            return source[next...].range(of: "*/")?.upperBound ?? source.endIndex
        }
        func skipTrivia(from start: String.Index) -> String.Index {
            var cursor = start
            while cursor < source.endIndex {
                if isCSSWhitespace(source[cursor]) {
                    cursor = source.index(after: cursor)
                } else if let end = skipComment(from: cursor) {
                    cursor = end
                } else {
                    break
                }
            }
            return cursor
        }
        func decodeCSSURL(_ raw: String) -> String? {
            var decoded = ""
            var cursor = raw.startIndex
            while cursor < raw.endIndex {
                guard raw[cursor] == "\\" else {
                    decoded.append(raw[cursor])
                    cursor = raw.index(after: cursor)
                    continue
                }
                cursor = raw.index(after: cursor)
                guard cursor < raw.endIndex, raw[cursor] != "\n", raw[cursor] != "\r" else { return nil }
                var hexadecimal = ""
                while cursor < raw.endIndex, hexadecimal.count < 6,
                      raw[cursor].isHexDigit {
                    hexadecimal.append(raw[cursor])
                    cursor = raw.index(after: cursor)
                }
                if hexadecimal.isEmpty {
                    decoded.append(raw[cursor])
                    cursor = raw.index(after: cursor)
                } else {
                    if cursor < raw.endIndex, isCSSWhitespace(raw[cursor]) {
                        cursor = raw.index(after: cursor)
                    }
                    guard let scalarValue = UInt32(hexadecimal, radix: 16),
                          let scalar = UnicodeScalar(scalarValue),
                          !(0xD800...0xDFFF).contains(scalarValue)
                    else { return nil }
                    decoded.append(Character(scalar))
                }
            }
            return decoded
        }
        func quotedValue(from quoteIndex: String.Index) -> (String, String.Index)? {
            let quote = source[quoteIndex]
            var cursor = source.index(after: quoteIndex)
            let start = cursor
            while cursor < source.endIndex {
                if source[cursor] == "\\" {
                    cursor = source.index(after: cursor)
                    guard cursor < source.endIndex else { return nil }
                    cursor = source.index(after: cursor)
                    continue
                }
                if source[cursor] == quote {
                    guard let decoded = decodeCSSURL(String(source[start..<cursor])) else { return nil }
                    return (decoded, source.index(after: cursor))
                }
                cursor = source.index(after: cursor)
            }
            return nil
        }
        func importReference(from start: String.Index) -> (value: String, end: String.Index)? {
            var cursor = skipTrivia(from: start)
            guard cursor < source.endIndex else { return nil }
            if source[cursor] == "\"" || source[cursor] == "'" {
                return quotedValue(from: cursor)
            }
            let identifierStart = cursor
            while cursor < source.endIndex,
                  (source[cursor].isLetter || source[cursor] == "-") {
                cursor = source.index(after: cursor)
            }
            guard String(source[identifierStart..<cursor]).caseInsensitiveCompare("url") == .orderedSame else {
                return nil
            }
            cursor = skipTrivia(from: cursor)
            guard cursor < source.endIndex, source[cursor] == "(" else { return nil }
            cursor = skipTrivia(from: source.index(after: cursor))
            if cursor < source.endIndex, (source[cursor] == "\"" || source[cursor] == "'") {
                guard let quoted = quotedValue(from: cursor) else { return nil }
                let closing = skipTrivia(from: quoted.1)
                guard closing < source.endIndex, source[closing] == ")" else { return nil }
                return (quoted.0, source.index(after: closing))
            }
            let valueStart = cursor
            while cursor < source.endIndex, source[cursor] != ")" {
                if isCSSWhitespace(source[cursor]) { return nil }
                if source[cursor] == "\\" {
                    cursor = source.index(after: cursor)
                    guard cursor < source.endIndex else { return nil }
                }
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex else { return nil }
            guard let decoded = decodeCSSURL(String(source[valueStart..<cursor])) else { return nil }
            return (decoded, source.index(after: cursor))
        }
        func validatedImportEnd(from start: String.Index) -> String.Index? {
            var cursor = start
            var parenthesisDepth = 0
            while cursor < source.endIndex {
                if let end = skipComment(from: cursor) {
                    cursor = end
                    continue
                }
                if source[cursor] == "\"" || source[cursor] == "'" {
                    guard let (_, end) = quotedValue(from: cursor) else { return nil }
                    cursor = end
                    continue
                }
                switch source[cursor] {
                case "(":
                    parenthesisDepth += 1
                case ")":
                    guard parenthesisDepth > 0 else { return nil }
                    parenthesisDepth -= 1
                case ";" where parenthesisDepth == 0:
                    return source.index(after: cursor)
                case "{", "}", "@", "?":
                    return nil
                case "\\":
                    cursor = source.index(after: cursor)
                    guard cursor < source.endIndex else { return nil }
                default:
                    break
                }
                cursor = source.index(after: cursor)
            }
            return nil
        }

        var references: [String] = []
        var hasUnsupportedReference = false
        var cursor = source.startIndex
        var braceDepth = 0
        var importPhaseOpen = true
        while cursor < source.endIndex {
            if let end = skipComment(from: cursor) {
                cursor = end
                continue
            }
            if isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            if source[cursor] == "\"" || source[cursor] == "'" {
                if let (_, end) = quotedValue(from: cursor) { cursor = end } else { break }
                if braceDepth == 0 { importPhaseOpen = false }
                continue
            }
            if source[cursor] == "{" {
                if braceDepth == 0 { importPhaseOpen = false }
                braceDepth += 1
                cursor = source.index(after: cursor)
                continue
            }
            if source[cursor] == "}" {
                braceDepth = max(braceDepth - 1, 0)
                cursor = source.index(after: cursor)
                continue
            }
            guard braceDepth == 0, source[cursor] == "@" else {
                if braceDepth == 0, source[cursor] != ";" { importPhaseOpen = false }
                cursor = source.index(after: cursor)
                continue
            }
            var nameCursor = source.index(after: cursor)
            let nameStart = nameCursor
            if nameCursor < source.endIndex, source[nameCursor] == "\\" {
                // Escaped at-keywordはsemantic decodeなしに依存先を断定せず、legacy projectでは全体blockへ寄せます。
                hasUnsupportedReference = true
                importPhaseOpen = false
                cursor = source.index(after: nameCursor)
                continue
            }
            while nameCursor < source.endIndex,
                  isCSSNameCharacter(source[nameCursor]) {
                nameCursor = source.index(after: nameCursor)
            }
            let atRuleName = String(source[nameStart..<nameCursor]).lowercased()
            if atRuleName == "import" {
                guard importPhaseOpen else {
                    hasUnsupportedReference = true
                    cursor = nameCursor
                    continue
                }
                if let reference = importReference(from: nameCursor),
                   !reference.value.isEmpty,
                   let statementEnd = validatedImportEnd(from: reference.end) {
                    references.append(reference.value)
                    cursor = statementEnd
                    continue
                } else {
                    hasUnsupportedReference = true
                }
            } else if importPhaseOpen, ["charset", "layer"].contains(atRuleName) {
                if let statementEnd = validatedImportEnd(from: nameCursor) {
                    cursor = statementEnd
                    continue
                }
                importPhaseOpen = false
            } else {
                importPhaseOpen = false
            }
            cursor = nameCursor
        }
        return (references, hasUnsupportedReference)
    }

    private func containsLegacyRuntimeSource(_ source: String) -> Bool {
        OpenGraphiteLegacyJavaScriptInspector.containsLegacyReader(source)
    }

    private func containsLocalRuntimeDependency(_ source: String) -> Bool {
        var tokens: [String] = []
        var templateInterpolations: [String] = []
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let next = source.index(after: cursor)
            if source[cursor] == "/", next < source.endIndex, source[next] == "/" {
                cursor = OpenGraphiteJavaScriptLexical.lineCommentEnd(in: source, from: next)
                continue
            }
            if source[cursor] == "/", next < source.endIndex, source[next] == "*" {
                cursor = source[next...].range(of: "*/")?.upperBound ?? source.endIndex
                continue
            }
            if source[cursor] == "/",
               OpenGraphiteJavaScriptLexical.canStartRegularExpression(afterToken: tokens.last),
               let end = OpenGraphiteJavaScriptLexical.regularExpressionEnd(in: source, from: cursor) {
                tokens.append("<regex>")
                cursor = end
                continue
            }
            let character = source[cursor]
            if character == "\"" || character == "'" || character == "`" {
                let quote = character
                cursor = next
                while cursor < source.endIndex {
                    let current = source[cursor]
                    cursor = source.index(after: cursor)
                    if current == "\\", cursor < source.endIndex {
                        cursor = source.index(after: cursor)
                    } else if quote == "`", current == "$", cursor < source.endIndex,
                              source[cursor] == "{" {
                        let openingBrace = cursor
                        guard let closingBrace = javascriptInterpolationClosingBrace(
                            in: source,
                            openingBrace: openingBrace
                        ) else { return true }
                        let expressionStart = source.index(after: openingBrace)
                        templateInterpolations.append(String(source[expressionStart..<closingBrace]))
                        cursor = source.index(after: closingBrace)
                    } else if current == quote {
                        break
                    }
                }
                tokens.append("<string>")
                continue
            }
            if character.isLetter || character == "_" || character == "$" {
                let start = cursor
                cursor = next
                while cursor < source.endIndex,
                      (source[cursor].isLetter || source[cursor].isNumber
                        || source[cursor] == "_" || source[cursor] == "$") {
                    cursor = source.index(after: cursor)
                }
                tokens.append(String(source[start..<cursor]))
                continue
            }
            if !isECMAScriptWhitespace(character) { tokens.append(String(character)) }
            cursor = next
        }
        if templateInterpolations.contains(where: containsLocalRuntimeDependency) { return true }
        for index in tokens.indices {
            if tokens[index] == "import" {
                let nextIndex = index + 1
                if nextIndex < tokens.count, tokens[nextIndex] != "." { return true }
            }
            if tokens[index] == "export" {
                var scan = index + 1
                while scan < tokens.count, tokens[scan] != ";" {
                    if tokens[scan] == "from" { return true }
                    scan += 1
                }
            }
        }
        return false
    }

    private func javascriptInterpolationClosingBrace(
        in source: String,
        openingBrace: String.Index
    ) -> String.Index? {
        var depth = 1
        var cursor = source.index(after: openingBrace)
        var quote: Character?
        var previousToken: String?
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if let activeQuote = quote {
                if character == "\\", next < source.endIndex {
                    cursor = source.index(after: next)
                    continue
                }
                if character == activeQuote { quote = nil }
                cursor = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                cursor = OpenGraphiteJavaScriptLexical.lineCommentEnd(in: source, from: next)
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "*" {
                cursor = source[next...].range(of: "*/")?.upperBound ?? source.endIndex
                continue
            }
            if character == "/",
               OpenGraphiteJavaScriptLexical.canStartRegularExpression(afterToken: previousToken),
               let end = OpenGraphiteJavaScriptLexical.regularExpressionEnd(in: source, from: cursor) {
                previousToken = "<regex>"
                cursor = end
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
                previousToken = "<literal>"
            } else if character == "{" {
                depth += 1
                previousToken = "{"
            } else if character == "}" {
                depth -= 1
                if depth == 0 { return cursor }
                previousToken = "}"
            } else if !character.isWhitespace {
                previousToken = String(character)
            }
            cursor = next
        }
        return nil
    }

    private func isECMAScriptWhitespace(_ character: Character) -> Bool {
        character.isWhitespace || character.unicodeScalars.allSatisfy { $0.value == 0xFEFF }
    }

    private func relativePath(of url: URL, from root: URL) -> String {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(prefix) else { return url.lastPathComponent }
        return String(url.path.dropFirst(prefix.count))
    }

    private func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func unifiedDiff(before: String, after: String, path: String) -> String {
        guard before != after else { return "" }
        let beforeLines = before.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let afterLines = after.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output = ["--- a/\(path)", "+++ b/\(path)", "@@ -1,\(beforeLines.count) +1,\(afterLines.count) @@"]
        output.append(contentsOf: beforeLines.map { "-\($0)" })
        output.append(contentsOf: afterLines.map { "+\($0)" })
        return output.joined(separator: "\n") + "\n"
    }

    private func diagnostic(code: String, message: String, path: String?) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(
            severity: .error,
            code: code,
            message: message,
            path: path,
            nodeID: nil
        )
    }
}

/// 論理名（日本語）: Agent coreエラー
/// 概要: project file 更新など、diagnostics ではなく処理自体を止めるエラーです。
///
/// プロパティ:
/// - `message`: エラー説明。
struct OpenGraphiteAgentCoreError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}

private extension String {
    /// 論理名（日本語）: 空文字nil化済みtrim文字列
    /// 概要: 前後空白を除去し、空文字なら `nil` として返します。
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
