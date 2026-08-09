import Foundation

/// 論理名（日本語）: WebCanvasノードsource locator
/// 概要: source HTML を変更せず、標準 selector、DOM path、source range、content hash から inspection node を再特定します。
///
/// プロパティ:
/// - `documentURL`: inspection 対象 document URL。
/// - `selector`: 一意な標準 `id` 等から作れる安全な selector。
/// - `domPath`: document root からの構造 path。
/// - `sourceStart`: source 上の開始 offset。不明時は `-1`。
/// - `sourceEnd`: source 上の終了 offset。不明時は `-1`。
/// - `contentHash`: 対象 subtree の revision 検出用 hash。
struct OpenGraphiteNodeSourceLocator: Hashable {
    var documentURL: String
    var selector: String?
    var domPath: String
    var sourceStart: Int
    var sourceEnd: Int
    var contentHash: String

    /// 論理名（日本語）: Source-backed locator判定
    /// 概要: Shared source inspectionが返した非空の文字範囲を持ち、明示adoptionの対象にできる場合に`true`を返します。
    var isSourceBacked: Bool {
        sourceStart >= 0 && sourceEnd > sourceStart
    }
}

/// 論理名（日本語）: 描画実体CSS宣言trace
/// 概要: wrapper から解決した media / SVG / mask 実体について、標準 CSS declaration の保存元を Inspector 向けに保持します。
///
/// プロパティ:
/// - `authoredProperty`: source に記載された CSS property。
/// - `selector`: declaration が属する authored selector。
/// - `atRuleScope`: declaration を囲む at-rule の表示文字列。
/// - `value`: authored value。
/// - `important`: `!important` の有無。
/// - `specificityIDs`: selector specificity の ID count。
/// - `specificityClasses`: selector specificity の class / attribute / pseudo-class count。
/// - `specificityTypes`: selector specificity の type / pseudo-element count。
/// - `sourceOrder`: stylesheet 内の declaration 順。
struct OpenGraphiteRenderTargetSourceTrace: Hashable {
    var authoredProperty: String
    var selector: String
    var atRuleScope: [String]
    var value: String
    var important: Bool
    var specificityIDs: Int
    var specificityClasses: Int
    var specificityTypes: Int
    var sourceOrder: Int
}

/// 論理名（日本語）: 描画実体CSS編集対象
/// 概要: 選択 wrapper と実際に描画する `img` / `video` / SVG / mask element の relation、source provenance、computed value を分離して保持します。
///
/// プロパティ:
/// - `kind`: media、SVG、mask の描画実体区分。
/// - `property`: 編集対象の標準 CSS property。
/// - `targetTagName`: 描画実体の tag name。
/// - `relation`: wrapper 自身、直下 child、descendant の関係。
/// - `writeSelector`: Shared source parser が安全な保存先として解決した selector。
/// - `targetInternalID`: 描画実体に既存 annotation がある場合だけ保持する internal ID。
/// - `authoredValue`: cascade winner の authored value。
/// - `resolvedValue`: Shared の headless cascade で解決した値。
/// - `computedValue`: WebKit が現在描画している computed value。
/// - `relationSelector`: WebCanvas 内で同じ実体を確認するための wrapper 相対 selector。
/// - `sourceTrace`: declaration provenance の候補一覧。
struct OpenGraphiteRenderTarget: Identifiable, Hashable {
    var kind: String
    var property: String
    var targetTagName: String
    var relation: String
    var writeSelector: String
    var targetInternalID: String
    var authoredValue: String
    var resolvedValue: String
    var computedValue: String
    var relationSelector: String
    var sourceTrace: [OpenGraphiteRenderTargetSourceTrace]

    var id: String { property }

    /// 論理名（日本語）: Inspector表示値
    /// 処理概要: source の authored value を優先し、未指定時だけ headless resolved value、WebKit computed valueの順に返します。
    ///
    /// - Returns: Inspector control に表示する CSS value。
    var displayValue: String {
        if !authoredValue.isEmpty { return authoredValue }
        if !resolvedValue.isEmpty { return resolvedValue }
        return computedValue
    }

    /// 論理名（日本語）: 描画実体表示ラベル
    /// 処理概要: source selector がある場合はそれを返し、未指定時は wrapper relation と tag name から読み取り専用ラベルを作ります。
    ///
    /// - Returns: Inspector で実体を識別するラベル。
    var targetLabel: String {
        if !writeSelector.isEmpty { return writeSelector }
        if relation == "self" { return targetTagName }
        return "\(relation) \(targetTagName)"
    }

    /// 論理名（日本語）: Cascade勝者trace
    /// 処理概要: `!important`、specificity、source order の順で authored declaration candidate を比較します。
    ///
    /// - Returns: 現在の cascade winner。候補がない場合は `nil`。
    var winnerTrace: OpenGraphiteRenderTargetSourceTrace? {
        sourceTrace.max { lhs, rhs in
            if lhs.important != rhs.important { return !lhs.important && rhs.important }
            let lhsSpecificity = (lhs.specificityIDs, lhs.specificityClasses, lhs.specificityTypes)
            let rhsSpecificity = (rhs.specificityIDs, rhs.specificityClasses, rhs.specificityTypes)
            if lhsSpecificity != rhsSpecificity {
                if lhsSpecificity.0 != rhsSpecificity.0 { return lhsSpecificity.0 < rhsSpecificity.0 }
                if lhsSpecificity.1 != rhsSpecificity.1 { return lhsSpecificity.1 < rhsSpecificity.1 }
                return lhsSpecificity.2 < rhsSpecificity.2
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }
}

/// 論理名（日本語）: WebKit解決済みノードスタイル
/// 概要: authored CSS declaration とは分離して、現在のviewportとcascadeをWebKitが評価した標準CSSの描画状態を保持します。
///
/// プロパティ:
/// - `display`: computed `display`。
/// - `flexDirection`: computed `flex-direction`。
/// - `gridTemplateColumns`: computed `grid-template-columns`。
/// - `gridTemplateRows`: computed `grid-template-rows`。
/// - `gridAutoFlow`: computed `grid-auto-flow`。
/// - `position`: computed `position`。
/// - `visibility`: computed `visibility`。
/// - `contentVisibility`: computed `content-visibility`。
/// - `overflowWrap`: computed `overflow-wrap`。
/// - `alignItems`: computed `align-items`。
/// - `justifyContent`: computed `justify-content`。
struct OpenGraphiteNodeComputedStyle: Hashable {
    var display: String = ""
    var flexDirection: String = ""
    var gridTemplateColumns: String = ""
    var gridTemplateRows: String = ""
    var gridAutoFlow: String = ""
    var position: String = ""
    var visibility: String = ""
    var contentVisibility: String = ""
    var overflowWrap: String = ""
    var alignItems: String = ""
    var justifyContent: String = ""

    /// 論理名（日本語）: Computedレイアウトモード
    /// 処理概要: 標準`display`とflex方向から、InspectorとLayersで使う現在のレイアウト分類を導出します。
    ///
    /// - Returns: `vertical`、`horizontal`、`grid`、または標準`display`値。未解決時は空文字列。
    var layoutMode: String {
        let normalizedDisplay = display.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedDisplay {
        case "flex", "inline-flex":
            let direction = flexDirection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return direction.hasPrefix("row") ? "horizontal" : "vertical"
        case "grid", "inline-grid":
            return "grid"
        default:
            return normalizedDisplay
        }
    }

    /// 論理名（日本語）: CSS整列適用可否
    /// 概要: 現在のcomputed displayがflexまたはgrid formatting contextの場合に整列controlを有効化します。
    var supportsAlignment: Bool {
        ["flex", "inline-flex", "grid", "inline-grid"].contains(
            display.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}

/// 論理名（日本語）: ノード表示ヒント
/// 概要: 複数のDOM capabilityからLayersと履歴のアイコンだけを選ぶ表示専用分類です。編集可否の判定には使用しません。
///
/// 定義内容:
/// - `page`: project resource root。
/// - `container`: 子要素を受け入れる構造要素。
/// - `text`: 安全なプレーンテキスト編集対象。
/// - `control`: native control、ARIA control、またはlink。
/// - `media`: image、video、audio等のmedia実体を持つ要素。
/// - `icon`: SVGまたはmask実体を持つ要素。
/// - `generic`: 単一の表示分類へ強制しない一般要素。
enum OpenGraphiteNodePresentationHint: String, Hashable {
    case page
    case container
    case text
    case control
    case media
    case icon
    case generic
}

/// 論理名（日本語）: OpenGraphite編集ノード
/// 概要: annotation の有無にかかわらず HTML 要素を Layers と Inspector で扱い、stable / session reference を区別する表示・編集モデルです。
///
/// プロパティ:
/// - `id`: WebCanvas session 内の選択用 ID。
/// - `authoredID`: source に存在する optional な `data-og-id`。
/// - `standardID`: source に存在する標準 `id`。
/// - `internalID`: `data-og-internal-id` の値。
/// - `reference`: agent inspection が返す stable または session-scoped reference。
/// - `annotationStatus`: optional OpenGraphite annotation の付与状態。
/// - `referenceStability`: reference が resource revision を越えて安定するか。
/// - `locator`: source を変更せず node を再特定する document / selector / DOM path 情報。
/// - `parentReference`: 親 inspection node の reference。
/// - `tagName`: HTML タグ名または独自タグ名。
/// - `legacyTypeHint`: 既存sourceに存在するlegacy `data-og-type`。編集operationの認可には使用しません。
/// - `capabilities`: DOM semanticsとcomputed styleからoperationごとに導出した編集能力。
/// - `capabilityEvidence`: capability導出根拠となる標準DOM semantics。
/// - `attributes`: source inspectionとWebCanvasから得た標準HTML属性。
/// - `layout`: WebKit computed `display` / `flex-direction` から導出した現在のレイアウト分類。
/// - `role`: authored standard `role` 属性の値。
/// - `componentID`: `data-og-component` の値。
/// - `isComponentMaster`: Custom Element hostが直下templateを所有するcomponent masterなら`true`。
/// - `sourceComponentID`: component runtime が private metadata として返す参照元 component ID。
/// - `sourceInstanceID`: component runtime が private metadata として返す参照元 instance ID。
/// - `sourceNodeInternalID`: component placement が参照する source node の内部 ID。
/// - `sourceNodeID`: component placement clone が参照する source node の `data-og-id`。
/// - `sourcePlacementID`: component placement clone の生成元 placement host ID。
/// - `isPlacementGenerated`: component placement から生成された表示専用 clone か。
/// - `textContent`: preview DOM 上で現在解決され表示されているプレーンテキスト。
/// - `fallbackTextContent`: HTML 正本に残る fallback のプレーンテキスト。
/// - `textSource`: `data-og-text-source` の値。
/// - `i18nKey`: `data-i18n-key` の値。
/// - `iconLibrary`: `data-og-icon-library` の値。
/// - `iconName`: `data-og-icon-name` の値。
/// - `iconSource`: `data-og-icon-source` の値。
/// - `cssVariables`: source HTML / companion CSS の authored CSS declaration。computed値は含めません。
/// - `computedStyle`: WebKitが現在のviewportとcascadeで解決した標準CSS値。
/// - `hasIncompleteCSSProvenance`: cross-origin等でsource ruleを読めずcomputed provenanceが部分的か。
/// - `resolvedFontFamily`: preview DOM の computed style で解決された font-family。
/// - `renderTargets`: wrapper と関係する media / SVG / mask 実体の標準 CSS 編集対象。
/// - `isHidden`: WebKit computed `display` / `visibility` / `content-visibility` とancestor状態から判定した現在の非表示状態。
/// - `hasHiddenAttribute`: source intentとして標準`hidden`属性が存在するか。
/// - `isLocked`: `data-og-locked` によるロック状態。
/// - `depth`: DOM ツリー上の階層深度。
struct OpenGraphiteNode: Identifiable, Hashable {
    var id: String
    var authoredID: String?
    var standardID: String?
    var internalID: String = ""
    var reference: String
    var annotationStatus: OpenGraphiteNodeAnnotationStatus
    var referenceStability: OpenGraphiteNodeReferenceStability
    var locator: OpenGraphiteNodeSourceLocator?
    var parentReference: String?
    var tagName: String
    var legacyTypeHint: String?
    var capabilities: Set<OpenGraphiteNodeCapability>
    var capabilityEvidence: OpenGraphiteNodeCapabilityEvidence
    var attributes: [String: String]
    var layout: String?
    var role: String?
    var componentID: String?
    var isComponentMaster: Bool
    var sourceComponentID: String?
    var sourceInstanceID: String?
    var sourceNodeInternalID: String?
    var sourceNodeID: String?
    var sourcePlacementID: String?
    var isPlacementGenerated: Bool
    var textContent: String?
    var fallbackTextContent: String?
    var textSource: String?
    var i18nKey: String?
    var iconLibrary: String?
    var iconName: String?
    var iconSource: String?
    var cssVariables: [String: String]
    var computedStyle: OpenGraphiteNodeComputedStyle
    var hasIncompleteCSSProvenance: Bool
    var resolvedFontFamily: String? = nil
    var renderTargets: [OpenGraphiteRenderTarget]
    var isHidden: Bool
    var hasHiddenAttribute: Bool
    var isLocked: Bool
    var depth: Int

    /// 論理名（日本語）: OpenGraphite編集ノード初期化関数
    /// 処理概要: HTML ノードの session 選択 ID、optional annotation、source locator、編集メタデータから UI モデルを構成します。
    ///
    /// - Parameters:
    ///   - id: WebCanvas session 内の選択用 ID。
    ///   - authoredID: source に存在する optional な `data-og-id`。
    ///   - standardID: source に存在する標準 `id`。
    ///   - internalID: `data-og-internal-id`。
    ///   - reference: stable または session-scoped reference。
    ///   - annotationStatus: optional annotation の付与状態。省略時は ID 群から推定します。
    ///   - referenceStability: reference の安定性。省略時は internal ID の有無から推定します。
    ///   - locator: non-invasive inspection 用 source locator。
    ///   - parentReference: 親 inspection node の reference。
    ///   - tagName: HTML tag name。
    ///   - legacyTypeHint: optionalなlegacy `data-og-type`表示hint。
    ///   - type: 既存呼び出し互換用のlegacy `data-og-type`入力。operation認可には使用しません。
    ///   - capabilities: DOM semanticsとcomputed styleから導出したoperation capability集合。
    ///   - capabilityEvidence: capability導出に使った標準DOM semantics。
    ///   - attributes: Inspectorのlink/control等に使う標準HTML属性。
    ///   - layout: WebKit computed styleから導出した現在のレイアウト分類。
    ///   - role: authored standard `role`属性。
    ///   - componentID: `data-og-component`。
    ///   - isComponentMaster: template ownershipから導出したcomponent master判定。
    ///   - sourceComponentID: runtime-private metadata の参照元 component ID。
    ///   - sourceInstanceID: runtime-private metadata の参照元 instance ID。
    ///   - sourceNodeInternalID: `data-og-source-node-internal-id`。
    ///   - sourceNodeID: 表示専用 placement clone が参照する source node の `data-og-id`。
    ///   - sourcePlacementID: 表示専用 placement clone の生成元 placement host ID。
    ///   - isPlacementGenerated: component placement から生成された表示専用 clone か。
    ///   - textContent: preview DOM 上で現在解決され表示されているプレーンテキスト。
    ///   - fallbackTextContent: HTML 正本に残る fallback のプレーンテキスト。
    ///   - textSource: `data-og-text-source`。
    ///   - i18nKey: `data-i18n-key`。
    ///   - iconLibrary: `data-og-icon-library`。
    ///   - iconName: `data-og-icon-name`。
    ///   - iconSource: `data-og-icon-source`。
    ///   - cssVariables: source HTML / companion CSS 上のauthored CSS declaration。
    ///   - computedStyle: WebKitが現在のviewportとcascadeで解決した標準CSS値。
    ///   - hasIncompleteCSSProvenance: 読み取り不能stylesheetによりcomputed provenanceが部分的か。
    ///   - renderTargets: media / SVG / mask 実体の標準 CSS 編集対象。
    ///   - isHidden: WebKit computed display / visibility / content-visibilityとancestor状態から判定した非表示状態。
    ///   - hasHiddenAttribute: source intentとして標準`hidden`属性が存在するか。
    ///   - isLocked: ロック状態。
    ///   - depth: DOM 階層深度。
    init(
        id: String,
        authoredID: String? = nil,
        standardID: String? = nil,
        internalID: String = "",
        reference: String = "",
        annotationStatus: OpenGraphiteNodeAnnotationStatus? = nil,
        referenceStability: OpenGraphiteNodeReferenceStability? = nil,
        locator: OpenGraphiteNodeSourceLocator? = nil,
        parentReference: String? = nil,
        tagName: String,
        legacyTypeHint: String? = nil,
        type: String? = nil,
        capabilities: Set<OpenGraphiteNodeCapability> = [],
        capabilityEvidence: OpenGraphiteNodeCapabilityEvidence? = nil,
        attributes: [String: String] = [:],
        layout: String?,
        role: String?,
        componentID: String? = nil,
        isComponentMaster: Bool = false,
        sourceComponentID: String? = nil,
        sourceInstanceID: String? = nil,
        sourceNodeInternalID: String? = nil,
        sourceNodeID: String? = nil,
        sourcePlacementID: String? = nil,
        isPlacementGenerated: Bool = false,
        textContent: String? = nil,
        fallbackTextContent: String? = nil,
        textSource: String? = nil,
        i18nKey: String? = nil,
        iconLibrary: String? = nil,
        iconName: String? = nil,
        iconSource: String? = nil,
        cssVariables: [String: String],
        computedStyle: OpenGraphiteNodeComputedStyle = OpenGraphiteNodeComputedStyle(),
        hasIncompleteCSSProvenance: Bool = false,
        renderTargets: [OpenGraphiteRenderTarget] = [],
        isHidden: Bool,
        hasHiddenAttribute: Bool = false,
        isLocked: Bool,
        depth: Int
    ) {
        self.id = id
        let inferredAuthoredID = id.hasPrefix("ogref-session:") || id.hasPrefix("ogdom:") || id.hasPrefix("ogpl:")
            ? nil
            : id
        self.authoredID = Self.emptyNil(authoredID) ?? Self.emptyNil(inferredAuthoredID)
        self.standardID = Self.emptyNil(standardID)
        self.internalID = internalID
        self.reference = reference
        self.annotationStatus = annotationStatus ?? Self.inferredAnnotationStatus(
            authoredID: self.authoredID,
            internalID: internalID
        )
        self.referenceStability = referenceStability ?? (internalID.isEmpty ? .session : .stable)
        self.locator = locator
        self.parentReference = Self.emptyNil(parentReference)
        self.tagName = tagName
        self.legacyTypeHint = Self.emptyNil(legacyTypeHint) ?? Self.emptyNil(type)
        self.capabilities = capabilities
        self.capabilityEvidence = capabilityEvidence ?? Self.emptyCapabilityEvidence
        self.attributes = attributes
        self.layout = layout
        self.role = role
        self.componentID = Self.emptyNil(componentID)
        self.isComponentMaster = isComponentMaster
        self.sourceComponentID = Self.emptyNil(sourceComponentID)
        self.sourceInstanceID = Self.emptyNil(sourceInstanceID)
        self.sourceNodeInternalID = Self.emptyNil(sourceNodeInternalID)
        self.sourceNodeID = Self.emptyNil(sourceNodeID)
        self.sourcePlacementID = Self.emptyNil(sourcePlacementID)
        self.isPlacementGenerated = isPlacementGenerated
        self.textContent = textContent
        self.fallbackTextContent = fallbackTextContent
        self.textSource = Self.emptyNil(textSource)
        self.i18nKey = Self.emptyNil(i18nKey)
        self.iconLibrary = Self.emptyNil(iconLibrary)
        self.iconName = Self.emptyNil(iconName)
        self.iconSource = Self.emptyNil(iconSource)
        self.cssVariables = cssVariables
        self.computedStyle = computedStyle
        self.hasIncompleteCSSProvenance = hasIncompleteCSSProvenance
        self.renderTargets = renderTargets
        self.isHidden = isHidden
        self.hasHiddenAttribute = hasHiddenAttribute
        self.isLocked = isLocked
        self.depth = depth
    }

    var isTextBinding: Bool {
        textSource == "binding" || i18nKey != nil
    }

    /// 論理名（日本語）: ノードcapability保有判定
    /// 処理概要: legacy type hintを参照せず、指定operation capabilityがDOM semanticsから成立しているかを返します。
    ///
    /// - Parameter capability: 判定するoperation capability。
    /// - Returns: capability集合に含まれる場合は`true`。
    func supports(_ capability: OpenGraphiteNodeCapability) -> Bool {
        capabilities.contains(capability)
    }

    /// 論理名（日本語）: 標準HTML属性編集可否判定
    /// 処理概要: operation capabilityに加えてtag固有のcontent attribute適用先を検証し、無効な標準属性追加を防ぎます。
    ///
    /// - Parameter name: 編集するHTML属性名。
    /// - Returns: 選択nodeへその属性を安全に保存できる場合は`true`。
    func supportsEditingAttribute(_ name: String) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTag = tagName.lowercased()
        let hasHref = attributes.keys.contains { $0.caseInsensitiveCompare("href") == .orderedSame }
        let hasTarget = attributes.keys.contains { $0.caseInsensitiveCompare("target") == .orderedSame }
        switch normalizedName {
        case "href", "rel", "download":
            let isNativeHyperlink = ["a", "area"].contains(normalizedTag)
            return supports(.editLink) && hasHref
                && (isNativeHyperlink || capabilityEvidence.ariaRole == "link")
        case "target":
            return supports(.editLink) && (["a", "area"].contains(normalizedTag) || hasTarget)
        case "src":
            return supports(.editMedia)
                && ["audio", "embed", "iframe", "img", "source", "track", "video"].contains(normalizedTag)
        case "alt":
            return supports(.editMedia) && normalizedTag == "img"
        case "value":
            guard ["button", "data", "input", "li", "meter", "option", "progress"]
                .contains(normalizedTag)
            else { return false }
            return supports(.editLayout)
        case "name", "type", "placeholder", "disabled", "checked", "selected":
            return supports(.editControl)
        case "aria-label":
            return supports(.editControl)
        case "data-og-icon-library", "data-og-icon-name", "data-og-icon-source":
            return supports(.editIcon)
        case "hidden":
            return supports(.editLayout)
        default:
            return true
        }
    }

    /// 論理名（日本語）: Authored属性存在判定
    /// 処理概要: source-backed属性辞書をASCII case-insensitiveに検索し、空値属性も存在として区別します。
    ///
    /// - Parameter name: 検索するHTML属性名。
    /// - Returns: authored属性tokenが存在する場合は`true`。
    func hasAuthoredAttribute(named name: String) -> Bool {
        attributes.keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// 論理名（日本語）: ノード表示分類
    /// 処理概要: 複数capabilityを維持したまま、Layersと履歴のアイコンを標準DOM evidenceだけから選びます。legacy type hintはInspector情報表示に限定します。
    var presentationHint: OpenGraphiteNodePresentationHint {
        if capabilityEvidence.isProjectResourceRoot { return .page }
        if supports(.editIcon) { return .icon }
        if supports(.editMedia) { return .media }
        if supports(.editControl) || supports(.editLink) { return .control }
        if supports(.editText) { return .text }
        if supports(.receiveChildren) { return .container }

        return .generic
    }

    /// 論理名（日本語）: 描画実体CSS編集対象取得関数
    /// 処理概要: media / SVG / mask 実体に対応する標準 CSS property の編集対象を返します。
    ///
    /// - Parameter property: `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image` のいずれか。
    /// - Returns: 対応する描画実体。見つからない場合は `nil`。
    func renderTarget(for property: String) -> OpenGraphiteRenderTarget? {
        renderTargets.first { $0.property == property }
    }

    /// 論理名（日本語）: 描画実体CSS値更新関数
    /// 処理概要: Shared core への保存成功後、同じ property の authored / resolved / computed cache を同期します。
    ///
    /// - Parameters:
    ///   - property: 更新した標準 CSS property。
    ///   - value: 保存後の authored value。空の場合は declaration 削除。
    mutating func updateRenderTargetValue(property: String, value: String) {
        guard let index = renderTargets.firstIndex(where: { $0.property == property }) else { return }
        renderTargets[index].authoredValue = value
        renderTargets[index].resolvedValue = value
        renderTargets[index].computedValue = value
    }

    var textSourceLabel: String {
        if let textSource, !textSource.isEmpty {
            return textSource
        }
        return isTextBinding ? "binding" : "literal"
    }

    var displayID: String {
        sourceNodeID
            ?? authoredID
            ?? standardID
            ?? locator?.selector
            ?? tagName
    }

    var editTargetNodeID: String {
        sourceNodeID ?? authoredID ?? id
    }

    var inheritedComponentID: String? {
        if let sourceComponentID {
            return sourceComponentID
        }
        guard tagName == "og-instance", !isComponentMaster else {
            return nil
        }
        return componentID
    }

    /// 論理名（日本語）: Runtime component生成ノード判定
    /// 概要: `<og-instance>` runtime が component master から展開した node で、placement preview clone ではない場合に `true` を返します。
    var isRuntimeComponentGenerated: Bool {
        sourceComponentID != nil && sourceInstanceID != nil && !isPlacementGenerated
    }

    /// 論理名（日本語）: Layersノード詳細行
    /// 処理概要: tag、computed layout、非static position、role、rendered hidden、lock状態をLayers向けに連結します。
    var detailLine: String {
        var parts = [tagName]
        if let layout, !layout.isEmpty {
            parts.append(layout)
        }
        let computedPosition = computedStyle.position.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !computedPosition.isEmpty, computedPosition != "static" {
            parts.append(computedPosition)
        }
        if let role, !role.isEmpty {
            parts.append(role)
        }
        if isHidden {
            parts.append("hidden")
        }
        if isLocked {
            parts.append("locked")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 論理名（日本語）: 安定参照利用可否
    /// 概要: 既存 internal ID に基づく stable reference を利用できる場合に `true` を返します。
    var hasStableReference: Bool {
        referenceStability == .stable && !internalID.isEmpty
    }

    /// 論理名（日本語）: Optional identity adoption利用可否
    /// 概要: annotationが未完了で、browser生成DOMではなくauthored sourceへ解決済みのlocatorを持つ場合だけ`true`を返します。
    var canAdoptIdentity: Bool {
        annotationStatus != .complete && locator?.isSourceBacked == true
    }

    /// 論理名（日本語）: Annotation状態推定関数
    /// 処理概要: `data-og-id` と internal ID がそろえば complete、いずれかだけなら partial、それ以外を none とします。legacy type hintはidentity annotationに数えません。
    ///
    /// - Parameters:
    ///   - authoredID: optional な `data-og-id`。
    ///   - internalID: optional な `data-og-internal-id`。
    /// - Returns: 推定した annotation status。
    private static func inferredAnnotationStatus(
        authoredID: String?,
        internalID: String
    ) -> OpenGraphiteNodeAnnotationStatus {
        if authoredID != nil, !internalID.isEmpty { return .complete }
        if authoredID != nil || !internalID.isEmpty { return .partial }
        return .none
    }

    /// 論理名（日本語）: 空capability evidence
    /// 概要: WebCanvasまたはShared graphがevidenceを返さない既存fixture向けに、推測を行わない空状態を提供します。
    private static let emptyCapabilityEvidence = OpenGraphiteNodeCapabilityEvidence(
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
        resolvedDisplay: nil
    )

    /// 論理名（日本語）: 空文字nil変換関数
    /// 処理概要: 属性値の前後空白を除去し、空文字を `nil` として保存します。
    ///
    /// - Parameter value: 正規化する属性値。
    /// - Returns: 空でない属性値。空の場合は `nil`。
    private static func emptyNil(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }
}

/// 論理名（日本語）: OpenGraphiteコンポーネント継承元
/// 概要: 選択された component instance が参照する master の名称と配置情報を Inspector へ渡す表示モデルです。
///
/// プロパティ:
/// - `componentID`: master の `data-og-component`。
/// - `masterNodeID`: master root の `data-og-id`。
/// - `collectionInternalID`: master を含む Collection の内部 ID。
/// - `collectionName`: Collection の表示名。
/// - `componentPageID`: master を含む component canvas の ID。
/// - `componentPageInternalID`: master を含む component canvas の内部 ID。
/// - `componentPageName`: component canvas の表示名。
/// - `componentPagePath`: component canvas の HTML path。
/// - `canvas`: component canvas の配置情報。
struct OpenGraphiteComponentSource: Equatable, Identifiable {
    var componentID: String
    var masterNodeID: String?
    var collectionInternalID: String
    var collectionName: String
    var componentPageID: String
    var componentPageInternalID: String
    var componentPageName: String
    var componentPagePath: String
    var canvas: OpenGraphiteCanvas

    var id: String {
        "\(collectionInternalID):\(componentPageInternalID):\(componentID)"
    }

    var locationLabel: String {
        "\(collectionName) / \(componentPageName)"
    }

    var canvasLabel: String {
        "\(canvas.positionLabel) · \(canvas.resolutionLabel)"
    }
}

/// 論理名（日本語）: 親アニメーションCSS宣言
/// 概要: 選択中ノードに効く親オブジェクトの animation / timeline declaration を Inspector に表示するための行データです。
///
/// プロパティ:
/// - `key`: CSS property 名。
/// - `value`: CSS property の値。
struct OpenGraphiteAppliedAnimationDeclaration: Equatable, Identifiable {
    var key: String
    var value: String

    var id: String {
        key
    }
}

/// 論理名（日本語）: 適用親アニメーション文脈
/// 概要: 選択中ノードの祖先から見つかった、適用元として表示する animation / timeline 情報をまとめます。
///
/// プロパティ:
/// - `nodeID`: 親オブジェクトの選択 ID。
/// - `nodeInternalID`: 親オブジェクトの `data-og-internal-id`。
/// - `displayID`: Inspector に表示する親オブジェクト ID。
/// - `tagName`: 親オブジェクトの tag name。
/// - `declarations`: 表示する CSS declaration 一覧。
/// - `matchedTimelineNames`: 選択ノードの `animation-timeline` と一致した named timeline。
struct OpenGraphiteAppliedAnimationContext: Equatable, Identifiable {
    var nodeID: String
    var nodeInternalID: String
    var displayID: String
    var tagName: String
    var declarations: [OpenGraphiteAppliedAnimationDeclaration]
    var matchedTimelineNames: [String] = []

    var id: String {
        nodeID
    }

    var sourceLabel: String {
        let normalizedDisplayID = displayID.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedDisplayID.isEmpty {
            return tagName
        }
        return normalizedDisplayID
    }
}

/// 論理名（日本語）: CSS宣言変更要求
/// 概要: Inspector で編集された CSS declaration の値を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードのWebCanvas session内選択キー。
/// - `key`: CSS property または OpenGraphite 予約 custom property 名。
/// - `value`: 反映する CSS 値。
struct CSSVariableMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var key: String
    var value: String
}

/// 論理名（日本語）: 複数CSS宣言変更要求
/// 概要: リサイズなどで複数の CSS declaration を同時に WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードのWebCanvas session内選択キー。
/// - `values`: CSS property または OpenGraphite 予約 custom property 名と反映値の組。
struct CSSVariablesMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var values: [String: String]
}

/// 論理名（日本語）: 複数ノードCSS宣言変更要求
/// 概要: 同時選択した複数ノードの CSS declaration を WebView 側 DOM へまとめて反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeValues`: 対象ノードのWebCanvas session内選択キーごとの CSS declaration 群。
struct CSSVariablesBatchMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeValues: [String: [String: String]]
}

/// 論理名（日本語）: ノード属性変更要求
/// 概要: Inspector で編集された標準HTML属性または根拠あるmetadata属性を、空値設定と明示削除を区別してWebView側DOMへ反映します。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードのWebCanvas session内選択キー。
/// - `name`: 更新する属性名。
/// - `value`: 反映する属性値。
/// - `removesAttribute`: 値設定でなく属性tokenの明示削除か。
struct NodeAttributeMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var name: String
    var value: String
    var removesAttribute: Bool = false
}

/// 論理名（日本語）: ノードテキスト変更モード
/// 概要: Inspector で編集された text が HTML fallback と解決済み表示値のどちらを更新するかを表します。
///
/// 定義内容:
/// - `fallback`: HTML 正本に残る fallback text を更新します。
/// - `resolved`: i18n resource で解決された表示中 text を更新します。
enum NodeTextContentMutationMode: String, Equatable {
    case fallback
    case resolved
}

/// 論理名（日本語）: ノードテキスト変更要求
/// 概要: Inspector で編集された text node の内容を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードのWebCanvas session内選択キー。
/// - `value`: 反映するプレーンテキスト。
/// - `mode`: fallback と resolved のどちらへ反映するか。
struct NodeTextContentMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var value: String
    var mode: NodeTextContentMutationMode = .fallback
}

/// 論理名（日本語）: キャンバス操作ツール
/// 概要: HTML プレビュー編集と `.ogp` 専用キャンバス注釈に利用する各操作モードを表します。
///
/// 定義内容:
/// - `select`: ノード選択用の編集カーソル。
/// - `text`: テキスト作成ツール。
/// - `frame`: フレーム作成ツール。
/// - `icon`: アイコン作成ツール。
/// - `stickyNote`: `.ogp` キャンバスへ付箋を配置するツール。
/// - `pen`: `.ogp` キャンバスへ手書きストロークを記録するツール。
/// - `eraser`: `.ogp` キャンバス上の手書きストロークを消去するツール。
/// - `lasso`: `.ogp` キャンバス注釈を囲んで選択するツール。
/// - `hand`: キャンバス移動用ツール。
enum CanvasTool: String, CaseIterable, Identifiable {
    case select
    case text
    case frame
    case icon
    case stickyNote
    case pen
    case eraser
    case lasso
    case hand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select:
            return "編集カーソル"
        case .text:
            return "テキスト"
        case .frame:
            return "フレーム"
        case .icon:
            return "アイコン"
        case .stickyNote:
            return "付箋"
        case .pen:
            return "ペン"
        case .eraser:
            return "消しゴム"
        case .lasso:
            return "なげわ"
        case .hand:
            return "ハンド"
        }
    }

    var systemImage: String {
        switch self {
        case .select:
            return "cursorarrow"
        case .text:
            return "textformat"
        case .frame:
            return "square.dashed"
        case .icon:
            return "star"
        case .stickyNote:
            return "note.text"
        case .pen:
            return "pencil.tip"
        case .eraser:
            return "eraser"
        case .lasso:
            return "lasso"
        case .hand:
            return "hand.raised"
        }
    }
}

/// 論理名（日本語）: プレビュー表示モード
/// 概要: 中央キャンバスで通常編集と画面遷移フローの表示を切り替える状態を表します。
///
/// 定義内容:
/// - `normal`: 通常の編集プレビュー表示。
/// - `flow`: 静的リンクから解決した画面遷移線を重ねるフロー表示。
enum OpenGraphitePreviewDisplayMode: String, CaseIterable, Identifiable {
    case normal
    case flow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .flow:
            return "Flow"
        }
    }

    var systemImage: String {
        switch self {
        case .normal:
            return "eye"
        case .flow:
            return "arrow.right"
        }
    }

    var help: String {
        switch self {
        case .normal:
            return "通常表示"
        case .flow:
            return "フロー表示"
        }
    }
}
