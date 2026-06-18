import Foundation

/// 論理名（日本語）: OpenGraphite契約定義
/// 概要: `data-og-*`、編集可能 CSS 宣言、type、layout、role の機械可読な編集契約を表します。
///
/// プロパティ:
/// - `version`: 契約ファイルのバージョン。
/// - `types`: 許可済み `data-og-type` の一覧。
/// - `layouts`: 許可済み `data-og-layout` の一覧。
/// - `roles`: 既知の `data-og-role` の一覧。
/// - `editableAttributes`: CLI / MCP が編集できる永続属性。
/// - `runtimeAttributes`: 正本 HTML に残さない実行時属性。
/// - `cssVariables`: 既知の編集可能 CSS 宣言定義。標準 CSS property と OpenGraphite 固有 custom property を含む。
/// - `cssVariablePatterns`: locale suffix など動的に許可する CSS custom property パターン。
struct OpenGraphiteContract: Codable, Equatable {
    var version: String
    var types: [String]
    var layouts: [String]
    var roles: [String]
    var editableAttributes: [String]
    var runtimeAttributes: [String]
    var cssVariables: [OpenGraphiteCSSVariableContract]
    var cssVariablePatterns: [OpenGraphiteCSSVariablePatternContract]

    private enum CodingKeys: String, CodingKey {
        case version
        case types
        case layouts
        case roles
        case editableAttributes
        case runtimeAttributes
        case cssVariables
        case cssVariablePatterns
    }

    var typeSet: Set<String> { Set(types) }
    var layoutSet: Set<String> { Set(layouts) }
    var roleSet: Set<String> { Set(roles) }
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
    ///   - types: 許可済み `data-og-type` の一覧。
    ///   - layouts: 許可済み `data-og-layout` の一覧。
    ///   - roles: 既知の `data-og-role` の一覧。
    ///   - editableAttributes: CLI / MCP が編集できる永続属性。
    ///   - runtimeAttributes: 正本 HTML に残さない実行時属性。
    ///   - cssVariables: 既知の編集可能 CSS 宣言定義。
    ///   - cssVariablePatterns: 動的に許可する CSS custom property パターン。
    init(
        version: String,
        types: [String],
        layouts: [String],
        roles: [String],
        editableAttributes: [String],
        runtimeAttributes: [String],
        cssVariables: [OpenGraphiteCSSVariableContract],
        cssVariablePatterns: [OpenGraphiteCSSVariablePatternContract] = []
    ) {
        self.version = version
        self.types = types
        self.layouts = layouts
        self.roles = roles
        self.editableAttributes = editableAttributes
        self.runtimeAttributes = runtimeAttributes
        self.cssVariables = cssVariables
        self.cssVariablePatterns = cssVariablePatterns
    }

    /// 論理名（日本語）: OpenGraphite契約デコード初期化関数
    /// 処理概要: 古い契約 JSON でも読めるように、CSS 変数パターン未定義時は空配列として扱います。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        types = try container.decode([String].self, forKey: .types)
        layouts = try container.decode([String].self, forKey: .layouts)
        roles = try container.decode([String].self, forKey: .roles)
        editableAttributes = try container.decode([String].self, forKey: .editableAttributes)
        runtimeAttributes = try container.decode([String].self, forKey: .runtimeAttributes)
        cssVariables = try container.decode([OpenGraphiteCSSVariableContract].self, forKey: .cssVariables)
        cssVariablePatterns = try container.decodeIfPresent([OpenGraphiteCSSVariablePatternContract].self, forKey: .cssVariablePatterns) ?? []
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
        version: "0.1.0",
        types: ["page", "frame", "text", "button", "image", "icon"],
        layouts: ["vertical", "horizontal", "absolute"],
        roles: [
            "component-placement"
        ],
        editableAttributes: [
            "data-og-type",
            "data-og-layout",
            "data-og-role",
            "data-og-component",
            "data-og-component-kind",
            "data-og-variant",
            "data-og-slot",
            "data-og-part",
            "data-og-text-source",
            "data-og-lang-source",
            "data-og-lang-field",
            "data-og-dir-source",
            "data-og-dir-field",
            "data-og-source-component-internal-id",
            "data-og-source-node-internal-id",
            "data-og-placement-mode",
            "data-og-state-hidden",
            "data-og-state-visible",
            "data-og-icon-library",
            "data-og-icon-name",
            "data-og-icon-source",
            "data-i18n-key",
            "data-og-text-variant-eng",
            "data-og-hidden",
            "data-og-locked"
        ],
        runtimeAttributes: [
            "data-og-selected",
            "data-og-editing",
            "data-og-expanded",
            "data-og-generated",
            "data-og-component-error",
            "data-og-host-id",
            "data-og-instance-source",
            "data-og-source-component",
            "data-og-source-instance",
            "data-og-source-placement",
            "data-og-preview-clone",
            "data-og-placement-generated",
            "data-og-slot-origin",
            "data-og-preview-locale",
            "data-og-preview-dir",
            "data-og-runtime-fallback-html",
            "contenteditable",
            "spellcheck"
        ],
        cssVariables: [
            OpenGraphiteCSSVariableContract(name: "--og-page-background", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-text-color", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-muted-color", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-accent", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-accent-foreground", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "min-width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "min-height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "max-width", category: "box", syntax: "<length-percentage>|none|min()|max()|clamp()", editable: true),
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
            OpenGraphiteCSSVariableContract(name: "color", category: "appearance", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "background", category: "appearance", syntax: "<color>|<image>|linear-gradient()", editable: true),
            OpenGraphiteCSSVariableContract(name: "border", category: "appearance", syntax: "<border-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "border-radius", category: "appearance", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "box-shadow", category: "appearance", syntax: "<box-shadow>", editable: true),
            OpenGraphiteCSSVariableContract(name: "font-family", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-family-default", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-family-ja", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-family-en", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-family-eng", category: "text", syntax: "<font-family-list>|var()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-active-font-family", category: "runtime", syntax: "<font-family-list>|var()", editable: false),
            OpenGraphiteCSSVariableContract(name: "font-size", category: "text", syntax: "<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "font-weight", category: "text", syntax: "<number>|<font-weight-keyword>", editable: true),
            OpenGraphiteCSSVariableContract(name: "line-height", category: "text", syntax: "<number>|<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "letter-spacing", category: "text", syntax: "<length>|normal", editable: true),
            OpenGraphiteCSSVariableContract(name: "text-align", category: "text", syntax: "<text-align>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-object-fit", category: "media", syntax: "<object-fit>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-stroke-width", category: "icon", syntax: "<number>|<length>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-icon-url", category: "icon", syntax: "url()", editable: false),
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
            OpenGraphiteCSSVariableContract(name: "--og-scale-x", category: "transform", syntax: "<number>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-scale-y", category: "transform", syntax: "<number>", editable: true),
            OpenGraphiteCSSVariableContract(name: "transform-origin", category: "transform", syntax: "<position>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-edit-width", category: "runtime", syntax: "<length-percentage>|auto", editable: false),
            OpenGraphiteCSSVariableContract(name: "--og-edit-min-height", category: "runtime", syntax: "<length-percentage>", editable: false)
        ],
        cssVariablePatterns: [
            OpenGraphiteCSSVariablePatternContract(
                pattern: #"^--og-font-family-[a-z0-9]+(?:-[a-z0-9]+)*$"#,
                category: "text",
                syntax: "<font-family-list>|var()",
                editable: true
            )
        ]
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
