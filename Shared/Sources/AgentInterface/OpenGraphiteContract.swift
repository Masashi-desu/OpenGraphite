import Foundation

/// 論理名（日本語）: OpenGraphite契約定義
/// 概要: `data-og-*`、`--og-*`、type、layout、role の機械可読な編集契約を表します。
///
/// プロパティ:
/// - `version`: 契約ファイルのバージョン。
/// - `types`: 許可済み `data-og-type` の一覧。
/// - `layouts`: 許可済み `data-og-layout` の一覧。
/// - `roles`: 既知の `data-og-role` の一覧。
/// - `editableAttributes`: CLI / MCP が編集できる永続属性。
/// - `runtimeAttributes`: 正本 HTML に残さない実行時属性。
/// - `cssVariables`: 既知の `--og-*` CSS 変数定義。
struct OpenGraphiteContract: Codable, Equatable {
    var version: String
    var types: [String]
    var layouts: [String]
    var roles: [String]
    var editableAttributes: [String]
    var runtimeAttributes: [String]
    var cssVariables: [OpenGraphiteCSSVariableContract]

    var typeSet: Set<String> { Set(types) }
    var layoutSet: Set<String> { Set(layouts) }
    var roleSet: Set<String> { Set(roles) }
    var editableAttributeSet: Set<String> { Set(editableAttributes) }
    var runtimeAttributeSet: Set<String> { Set(runtimeAttributes) }
    var cssVariableSet: Set<String> { Set(cssVariables.map(\.name)) }
    var runtimeCSSVariableSet: Set<String> {
        Set(cssVariables.filter { !$0.editable }.map(\.name))
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
        types: ["page", "frame", "text", "button", "image"],
        layouts: ["vertical", "horizontal", "absolute"],
        roles: [
            "page-preview",
            "landing-hero",
            "primary-button",
            "secondary-button",
            "card",
            "eyebrow",
            "muted"
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
            "data-og-slot-origin",
            "contenteditable",
            "spellcheck"
        ],
        cssVariables: [
            OpenGraphiteCSSVariableContract(name: "--og-page-background", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-text-color", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-muted-color", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-accent", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-accent-foreground", category: "theme", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-min-width", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-min-height", category: "box", syntax: "<length-percentage>|auto|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-max-width", category: "box", syntax: "<length-percentage>|none|min()|max()|clamp()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-flex", category: "layout", syntax: "<flex-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-margin", category: "layout", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-padding", category: "layout", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-gap", category: "layout", syntax: "<length-percentage>{1,2}", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-align", category: "layout", syntax: "<align-items>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-justify", category: "layout", syntax: "<justify-content>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-x", category: "position", syntax: "<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-y", category: "position", syntax: "<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-foreground", category: "appearance", syntax: "<color>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-background", category: "appearance", syntax: "<color>|<image>|linear-gradient()", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-border", category: "appearance", syntax: "<border-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-radius", category: "appearance", syntax: "<box-shorthand>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-shadow", category: "appearance", syntax: "<box-shadow>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-size", category: "text", syntax: "<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-font-weight", category: "text", syntax: "<number>|<font-weight-keyword>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-line-height", category: "text", syntax: "<number>|<length-percentage>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-letter-spacing", category: "text", syntax: "<length>|normal", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-text-align", category: "text", syntax: "<text-align>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-object-fit", category: "media", syntax: "<object-fit>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-scale-x", category: "transform", syntax: "<number>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-scale-y", category: "transform", syntax: "<number>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-transform-origin", category: "transform", syntax: "<position>", editable: true),
            OpenGraphiteCSSVariableContract(name: "--og-edit-width", category: "runtime", syntax: "<length-percentage>|auto", editable: false),
            OpenGraphiteCSSVariableContract(name: "--og-edit-min-height", category: "runtime", syntax: "<length-percentage>", editable: false)
        ]
    )
}

/// 論理名（日本語）: OpenGraphite CSS変数契約
/// 概要: 単一の `--og-*` CSS 変数について、カテゴリ、値構文、編集可否を表します。
///
/// プロパティ:
/// - `name`: CSS 変数名。
/// - `category`: theme、layout、appearance などの分類。
/// - `syntax`: 人間と diagnostics 向けの値構文ラベル。
/// - `editable`: 正本 HTML の編集対象として扱うか。
struct OpenGraphiteCSSVariableContract: Codable, Equatable {
    var name: String
    var category: String
    var syntax: String
    var editable: Bool
}
