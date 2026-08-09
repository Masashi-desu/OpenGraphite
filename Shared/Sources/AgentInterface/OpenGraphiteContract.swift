import Foundation

/// 論理名（日本語）: OpenGraphite契約定義
/// 概要: 根拠ある`data-og-*`、編集可能CSS宣言、legacy layout decode、optional annotation policyの機械可読契約を表します。
///
/// プロパティ:
/// - `version`: 契約ファイルのバージョン。
/// - `layouts`: legacy contract decode互換用のlayout一覧。標準CSS移行後の組み込み契約では空です。
/// - `editableAttributes`: CLI / MCP が編集できる永続属性。
/// - `runtimeAttributes`: 正本 HTML に残さない実行時属性。
/// - `cssVariables`: 既知の編集可能 CSS 宣言定義。標準 CSS property と OpenGraphite 固有 custom property を含む。
/// - `cssVariablePatterns`: locale suffix など動的に許可する CSS custom property パターン。
/// - `designTokens`: Project CSS に保存する design token の機械可読契約。
/// - `annotationPolicy`: optional identity、inspection、明示adoptionの機械可読policy。
/// - `capabilityPolicy`: operation capability、evidence、legacy type hint、query semanticsの機械可読policy。
/// - `migrationPolicy`: legacy Web contractを明示migrationだけで更新する機械可読policy。
struct OpenGraphiteContract: Codable, Equatable {
    var version: String
    var layouts: [String]
    var editableAttributes: [String]
    var runtimeAttributes: [String]
    var cssVariables: [OpenGraphiteCSSVariableContract]
    var cssVariablePatterns: [OpenGraphiteCSSVariablePatternContract]
    var designTokens: OpenGraphiteDesignTokenContract
    var annotationPolicy: OpenGraphiteAnnotationPolicyContract
    var capabilityPolicy: OpenGraphiteCapabilityPolicyContract
    var migrationPolicy: OpenGraphiteMigrationPolicyContract

    private enum CodingKeys: String, CodingKey {
        case version
        case layouts
        case editableAttributes
        case runtimeAttributes
        case cssVariables
        case cssVariablePatterns
        case designTokens
        case annotationPolicy
        case capabilityPolicy
        case migrationPolicy
    }

    var layoutSet: Set<String> { Set(layouts) }
    var editableAttributeSet: Set<String> { Set(editableAttributes) }
    var runtimeAttributeSet: Set<String> { Set(runtimeAttributes) }

    var cssVariableSet: Set<String> { Set(cssVariables.map(\.name)) }

    var runtimeCSSVariableSet: Set<String> {
        Set(cssVariables.filter { $0.category == "runtime" }.map(\.name))
    }

    /// 論理名（日本語）: OpenGraphite契約初期化関数
    /// 処理概要: JSON ファイルまたは組み込み定義から契約値を保持します。
    ///
    /// - Parameters:
    ///   - version: 契約ファイルのバージョン。
    ///   - layouts: legacy contract decode互換用のlayout一覧。
    ///   - editableAttributes: CLI / MCP が編集できる永続属性。
    ///   - runtimeAttributes: 正本 HTML に残さない実行時属性。
    ///   - cssVariables: 既知の編集可能 CSS 宣言定義。
    ///   - cssVariablePatterns: 動的に許可する CSS custom property パターン。
    ///   - designTokens: Project CSS の `:root` design token 契約。
    ///   - annotationPolicy: optional identityと明示adoptionの契約。
    ///   - capabilityPolicy: DOM operation capabilityとlegacy hint分離の契約。
    ///   - migrationPolicy: legacy Web contractの明示migration契約。
    init(
        version: String,
        layouts: [String],
        editableAttributes: [String],
        runtimeAttributes: [String],
        cssVariables: [OpenGraphiteCSSVariableContract],
        cssVariablePatterns: [OpenGraphiteCSSVariablePatternContract] = [],
        designTokens: OpenGraphiteDesignTokenContract = .builtIn,
        annotationPolicy: OpenGraphiteAnnotationPolicyContract = .builtIn,
        capabilityPolicy: OpenGraphiteCapabilityPolicyContract = .builtIn,
        migrationPolicy: OpenGraphiteMigrationPolicyContract = .builtIn
    ) {
        self.version = version
        self.layouts = layouts
        self.editableAttributes = editableAttributes
        self.runtimeAttributes = runtimeAttributes
        self.cssVariables = cssVariables
        self.cssVariablePatterns = cssVariablePatterns
        self.designTokens = designTokens
        self.annotationPolicy = annotationPolicy
        self.capabilityPolicy = capabilityPolicy
        self.migrationPolicy = migrationPolicy
    }

    /// 論理名（日本語）: OpenGraphite契約デコード初期化関数
    /// 処理概要: 古い契約 JSON でも読めるように、CSS 変数パターン未定義時は空配列として扱います。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        layouts = try container.decode([String].self, forKey: .layouts)
        editableAttributes = try container.decode([String].self, forKey: .editableAttributes)
        runtimeAttributes = try container.decode([String].self, forKey: .runtimeAttributes)
        cssVariables = try container.decode([OpenGraphiteCSSVariableContract].self, forKey: .cssVariables)
        cssVariablePatterns = try container.decodeIfPresent([OpenGraphiteCSSVariablePatternContract].self, forKey: .cssVariablePatterns) ?? []
        designTokens = try container.decodeIfPresent(OpenGraphiteDesignTokenContract.self, forKey: .designTokens) ?? .builtIn
        annotationPolicy = try container.decodeIfPresent(OpenGraphiteAnnotationPolicyContract.self, forKey: .annotationPolicy) ?? .builtIn
        capabilityPolicy = try container.decodeIfPresent(OpenGraphiteCapabilityPolicyContract.self, forKey: .capabilityPolicy) ?? .builtIn
        migrationPolicy = try container.decodeIfPresent(OpenGraphiteMigrationPolicyContract.self, forKey: .migrationPolicy) ?? .builtIn
    }

    /// 論理名（日本語）: 編集可能属性判定関数
    /// 処理概要: 契約に列挙された永続 HTML 属性かを判定します。
    ///
    /// - Parameter name: 判定する属性名。
    /// - Returns: CLI / MCP / Inspector から編集可能な属性であれば `true`。
    func isEditableAttribute(_ name: String) -> Bool {
        editableAttributeSet.contains(name)
    }

    /// 論理名（日本語）: CSS宣言既知判定関数
    /// 処理概要: 固定定義または動的パターンに一致する OpenGraphite 編集対象 CSS 宣言かを判定します。
    ///
    /// - Parameter name: 判定する CSS property または custom property 名。
    /// - Returns: 契約で扱える CSS 宣言であれば `true`。
    func isKnownCSSVariable(_ name: String) -> Bool {
        if cssVariableSet.contains(name) {
            return true
        }
        return cssVariablePatterns.contains { pattern in
            name.range(of: pattern.pattern, options: [.regularExpression]) != nil
        }
    }

    /// 論理名（日本語）: デザイントークン名判定関数
    /// 処理概要: Project CSS の `:root` へ保存できる CSS custom property 名かを判定します。
    ///
    /// - Parameter name: 判定する CSS custom property 名。
    /// - Returns: design token 名として保存できる場合は `true`。
    func isValidDesignTokenName(_ name: String) -> Bool {
        !name.hasPrefix("--og-")
            && name.range(of: designTokens.namePattern, options: [.regularExpression]) != nil
    }

    /// 論理名（日本語）: 契約ファイル読み込み関数
    /// 処理概要: 指定 URL の JSON をデコードして OpenGraphite の機械可読契約を返します。
    ///
    /// - Parameter url: `OpenGraphite.contract.json` の URL。
    /// - Returns: デコード済み契約。
    static func load(from url: URL) throws -> OpenGraphiteContract {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(OpenGraphiteContract.self, from: data)
    }

    /// 論理名（日本語）: デフォルト契約読み込み関数
    /// 処理概要: 指定ディレクトリから親方向へ `OpenGraphite.contract.json` を探し、見つからなければ組み込み契約を返します。
    ///
    /// - Parameter startURL: 探索開始 URL。
    /// - Returns: ファイルまたは組み込みの OpenGraphite 契約。
    static func loadDefault(startingAt startURL: URL) -> OpenGraphiteContract {
        if let url = findContractURL(startingAt: startURL),
           let contract = try? load(from: url) {
            return contract
        }
        return builtIn
    }

    /// 論理名（日本語）: 契約ファイル探索関数
    /// 処理概要: 開始 URL からファイルシステムの親階層をたどって契約 JSON を探します。
    ///
    /// - Parameter startURL: 探索開始 URL。
    /// - Returns: 見つかった契約 JSON の URL。見つからない場合は `nil`。
    static func findContractURL(startingAt startURL: URL) -> URL? {
        var currentPath = (startURL.hasDirectoryPath ? startURL : startURL.deletingLastPathComponent())
            .standardizedFileURL
            .path
        let fileManager = FileManager.default

        while true {
            let current = URL(fileURLWithPath: currentPath, isDirectory: true)
            let candidate = current.appendingPathComponent("OpenGraphite.contract.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath == currentPath || parentPath.isEmpty {
                return nil
            }
            currentPath = parentPath
        }
    }

    static let builtIn = OpenGraphiteContract(
        version: "1.0.0",
        layouts: [],
        editableAttributes: [
            "hidden",
            "href",
            "target",
            "aria-label",
            "value",
            "src",
            "alt",
            "role",
            "variant",
            "slot",
            "part",
            "data-og-component",
            "data-og-text-source",
            "data-og-lang-source",
            "data-og-lang-field",
            "data-og-dir-source",
            "data-og-dir-field",
            "data-og-source-component-internal-id",
            "data-og-source-node-internal-id",
            "data-og-icon-library",
            "data-og-icon-name",
            "data-og-icon-source",
            "data-i18n-key",
            "data-og-text-variant-eng",
            "data-og-locked"
        ],
        runtimeAttributes: [],
        cssVariables: [
            OpenGraphiteCSSVariableContract(name: "width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "min-width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "min-height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "max-width", category: "box", syntax: "<length-percentage>|none|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "display", category: "layout", syntax: "<display-outside> || <display-inside>|<display-listitem>|<display-internal>|<display-box>|<display-legacy>", editable: true),
            OpenGraphiteCSSVariableContract(name: "flex-direction", category: "layout", syntax: "row|row-reverse|column|column-reverse", editable: true),
            OpenGraphiteCSSVariableContract(name: "flex-wrap", category: "layout", syntax: "nowrap|wrap|wrap-reverse", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-template-columns", category: "layout", syntax: "none|<track-list>|<auto-track-list>", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-template-rows", category: "layout", syntax: "none|<track-list>|<auto-track-list>", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-auto-columns", category: "layout", syntax: "<track-size>+", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-auto-rows", category: "layout", syntax: "<track-size>+", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-auto-flow", category: "layout", syntax: "row|column|dense|row dense|column dense", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-column", category: "layout", syntax: "<grid-line>[/<grid-line>]", editable: true),
            OpenGraphiteCSSVariableContract(name: "grid-row", category: "layout", syntax: "<grid-line>[/<grid-line>]", editable: true),
            OpenGraphiteCSSVariableContract(name: "flex", category: "layout", syntax: "<flex-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "margin", category: "layout", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "padding", category: "layout", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "gap", category: "layout", syntax: "<length-percentage>{1,2}", editable: true),
            OpenGraphiteCSSVariableContract(name: "align-items", category: "layout", syntax: "<align-items>", editable: true),
            OpenGraphiteCSSVariableContract(name: "justify-content", category: "layout", syntax: "<justify-content>", editable: true),
            OpenGraphiteCSSVariableContract(name: "position", category: "position", syntax: "static|relative|absolute|fixed|sticky", editable: true),
            OpenGraphiteCSSVariableContract(name: "left", category: "position", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "top", category: "position", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "right", category: "position", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "bottom", category: "position", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "z-index", category: "position", syntax: "<integer>|auto", editable: true),
            OpenGraphiteCSSVariableContract(name: "visibility", category: "visibility", syntax: "visible|hidden|collapse", editable: true),
            OpenGraphiteCSSVariableContract(name: "overflow-wrap", category: "text", syntax: "normal|break-word|anywhere", editable: true),
            OpenGraphiteCSSVariableContract(name: "color", category: "appearance", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "background", category: "appearance", syntax: "<color>|<image>|linear-gradient()", editable: true),
            OpenGraphiteCSSVariableContract(name: "border", category: "appearance", syntax: "<border-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "border-radius", category: "appearance", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "box-shadow", category: "appearance", syntax: "<box-shadow>", editable: true),
            OpenGraphiteCSSVariableContract(name: "font-family", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "font-size", category: "text", syntax: "<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "font-weight", category: "text", syntax: "<number>|<font-weight-keyword>", editable: true),
            OpenGraphiteCSSVariableContract(name: "line-height", category: "text", syntax: "<number>|<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "letter-spacing", category: "text", syntax: "<length>|normal", editable: true),
            OpenGraphiteCSSVariableContract(name: "text-align", category: "text", syntax: "<text-align>", editable: true),
            OpenGraphiteCSSVariableContract(name: "object-fit", category: "media", syntax: "fill|contain|cover|none|scale-down", editable: true),
            OpenGraphiteCSSVariableContract(name: "stroke-width", category: "icon", syntax: "<number>|<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "mask-image", category: "icon", syntax: "none|<image>", editable: true),
            OpenGraphiteCSSVariableContract(name: "-webkit-mask-image", category: "icon", syntax: "none|<image>", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation", category: "animation", syntax: "<animation-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-name", category: "animation", syntax: "<keyframes-name>#|none", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-duration", category: "animation", syntax: "<time>#|auto", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-delay", category: "animation", syntax: "<time>#", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-timing-function", category: "animation", syntax: "<easing-function>#", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-iteration-count", category: "animation", syntax: "<number>|infinite", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-direction", category: "animation", syntax: "normal|reverse|alternate|alternate-reverse", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-fill-mode", category: "animation", syntax: "none|forwards|backwards|both", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-play-state", category: "animation", syntax: "running|paused", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-timeline", category: "scroll-animation", syntax: "auto|none|<dashed-ident>|scroll()|view()", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-range", category: "scroll-animation", syntax: "<animation-range-start> <animation-range-end>?", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-range-start", category: "scroll-animation", syntax: "normal|<timeline-range-name>? <length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "animation-range-end", category: "scroll-animation", syntax: "normal|<timeline-range-name>? <length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "timeline-scope", category: "scroll-animation", syntax: "none|all|<dashed-ident>#", editable: true),
            OpenGraphiteCSSVariableContract(name: "scroll-timeline", category: "scroll-animation", syntax: "<scroll-timeline-name> <scroll-timeline-axis>?", editable: true),
            OpenGraphiteCSSVariableContract(name: "scroll-timeline-name", category: "scroll-animation", syntax: "none|<dashed-ident>#", editable: true),
            OpenGraphiteCSSVariableContract(name: "scroll-timeline-axis", category: "scroll-animation", syntax: "block|inline|x|y", editable: true),
            OpenGraphiteCSSVariableContract(name: "view-timeline", category: "scroll-animation", syntax: "<view-timeline-name> <view-timeline-axis>?", editable: true),
            OpenGraphiteCSSVariableContract(name: "view-timeline-name", category: "scroll-animation", syntax: "none|<dashed-ident>#", editable: true),
            OpenGraphiteCSSVariableContract(name: "view-timeline-axis", category: "scroll-animation", syntax: "block|inline|x|y", editable: true),
            OpenGraphiteCSSVariableContract(name: "view-timeline-inset", category: "scroll-animation", syntax: "auto|<length-percentage>{1,2}", editable: true),
            OpenGraphiteCSSVariableContract(name: "scale", category: "transform", syntax: "none|[<number>|<percentage>]{1,3}", editable: true),
            OpenGraphiteCSSVariableContract(name: "transform-origin", category: "transform", syntax: "<position>", editable: true)
        ],
        cssVariablePatterns: [],
        designTokens: .builtIn,
        annotationPolicy: .builtIn,
        capabilityPolicy: .builtIn,
        migrationPolicy: .builtIn
    )
}

/// 論理名（日本語）: Web契約移行policy
/// 概要: legacy readerを通常読込から分離し、dry-runとdiffを経由する明示migrationの対応範囲を表します。
///
/// プロパティ:
/// - `explicitOnly`: open/loadで暗黙変換せず明示操作だけを許可する場合は`true`。
/// - `dryRunRequired`: apply前に同じsource snapshotのdry-run proposalを要求する場合は`true`。
/// - `supportedSourceVersions`: compatibility readerが明示migration入力として扱うWeb contract version。
/// - `targetVersion`: migrationが生成するWeb contract version。
/// - `legacyReaderRemovalConditions`: compatibility readerを削除できる条件。
struct OpenGraphiteMigrationPolicyContract: Codable, Equatable {
    var explicitOnly: Bool
    var dryRunRequired: Bool
    var supportedSourceVersions: [String]
    var targetVersion: String
    var legacyReaderRemovalConditions: [String]

    static let builtIn = OpenGraphiteMigrationPolicyContract(
        explicitOnly: true,
        dryRunRequired: true,
        supportedSourceVersions: ["0.1.0"],
        targetVersion: "1.0.0",
        legacyReaderRemovalConditions: [
            "minimum-supported-web-contract-version-is-greater-than-0.1.0",
            "official-and-generated-assets-contain-no-known-legacy-tokens",
            "legacy-fixtures-and-release-notes-are-retired-by-an-explicit-major-release"
        ]
    )
}

/// 論理名（日本語）: DOM操作Capability policy契約
/// 概要: 単一legacy type分類に代えて、operation set、inspection evidence、legacy hint読込、query semanticsを機械可読化します。
///
/// プロパティ:
/// - `operations`: raw value昇順のoperation capability一覧。
/// - `evidenceFields`: Agent nodeのcapability evidence JSON field一覧。
/// - `legacyTypeAttribute`: migration入力として読むlegacy属性名。
/// - `legacyReadOnlyHint`: legacy属性がinspection hintに限定される場合は`true`。
/// - `generated`: 新規node/adoptionでlegacy type属性を生成する場合は`true`。
/// - `queryMatch`: 複数capability queryの照合方法。
struct OpenGraphiteCapabilityPolicyContract: Codable, Equatable {
    var operations: [String]
    var evidenceFields: [String]
    var legacyTypeAttribute: String
    var legacyReadOnlyHint: Bool
    var generated: Bool
    var queryMatch: String

    static let builtIn = OpenGraphiteCapabilityPolicyContract(
        operations: OpenGraphiteNodeCapability.allCases.map(\.rawValue).sorted(),
        evidenceFields: [
            "isProjectResourceRoot",
            "isNativeControl",
            "isCustomElement",
            "isLink",
            "hasDirectText",
            "hasElementChildren",
            "hasMediaContent",
            "hasSVGContent",
            "hasMaskContent",
            "ariaRole",
            "resolvedDisplay"
        ],
        legacyTypeAttribute: "data-og-type",
        legacyReadOnlyHint: true,
        generated: false,
        queryMatch: "all"
    )
}

/// 論理名（日本語）: Annotation policy契約
/// 概要: optional identityがinspection/validationを妨げず、明示adoptionだけがsourceを変更する規則を表します。
struct OpenGraphiteAnnotationPolicyContract: Codable, Equatable {
    var identityAttributes: [String]
    var requiredForInspection: Bool
    var missingIsValidationError: Bool
    var inspectionMutatesSource: Bool
    var annotationStatuses: [String]
    var referenceStabilities: [String]
    var adoption: OpenGraphiteAdoptionPolicyContract

    static let builtIn = OpenGraphiteAnnotationPolicyContract(
        identityAttributes: ["data-og-id", "data-og-internal-id"],
        requiredForInspection: false,
        missingIsValidationError: false,
        inspectionMutatesSource: false,
        annotationStatuses: OpenGraphiteNodeAnnotationStatus.allCases.map(\.rawValue),
        referenceStabilities: OpenGraphiteNodeReferenceStability.allCases.map(\.rawValue),
        adoption: .builtIn
    )
}

/// 論理名（日本語）: 明示adoption policy契約
/// 概要: dry-run既定、diff必須、locator優先順、stale guardをCLI/MCP/Appで共有します。
struct OpenGraphiteAdoptionPolicyContract: Codable, Equatable {
    var explicit: Bool
    var dryRunDefault: Bool
    var diffRequired: Bool
    var locatorPreference: [String]
    var staleGuards: [String]

    static let builtIn = OpenGraphiteAdoptionPolicyContract(
        explicit: true,
        dryRunDefault: true,
        diffRequired: true,
        locatorPreference: ["standard-id", "safe-selector", "dom-path"],
        staleGuards: ["source-range", "content-hash", "document-content-hash", "proposal-parameters"]
    )
}

/// 論理名（日本語）: デザイントークン契約
/// 概要: Project CSS 内で design token として扱う CSS custom property の保存場所と名前規則を表します。
///
/// プロパティ:
/// - `selector`: token を保存する CSS selector。
/// - `namePattern`: 許可する token 名の正規表現。
/// - `valueSyntax`: token 値の概念的な CSS 構文。
struct OpenGraphiteDesignTokenContract: Codable, Equatable {
    var selector: String
    var namePattern: String
    var valueSyntax: String

    static let builtIn = OpenGraphiteDesignTokenContract(
        selector: ":root",
        namePattern: #"^--(?!og-)[A-Za-z_][A-Za-z0-9_-]*$"#,
        valueSyntax: "<declaration-value>"
    )
}

/// 論理名（日本語）: OpenGraphite CSS宣言契約
/// 概要: 単一の編集可能 CSS property または custom property について、カテゴリ、値構文、編集可否を表します。
///
/// プロパティ:
/// - `name`: CSS property または custom property 名。
/// - `category`: theme、layout、appearance などの分類。
/// - `syntax`: 人間と diagnostics 向けの値構文ラベル。
/// - `editable`: 正本 HTML の編集対象として扱うか。
struct OpenGraphiteCSSVariableContract: Codable, Equatable {
    var name: String
    var category: String
    var syntax: String
    var editable: Bool
}

/// 論理名（日本語）: OpenGraphite CSS宣言パターン契約
/// 概要: locale suffix など、固定名ではなく正規表現で許可する CSS custom property を表します。
///
/// プロパティ:
/// - `pattern`: CSS property または custom property 名に対する正規表現。
/// - `category`: text、runtime などの分類。
/// - `syntax`: 人間と diagnostics 向けの値構文ラベル。
/// - `editable`: 正本 HTML の編集対象として扱うか。
struct OpenGraphiteCSSVariablePatternContract: Codable, Equatable {
    var pattern: String
    var category: String
    var syntax: String
    var editable: Bool
}
