import Foundation

/// 論理名（日本語）: OpenGraphiteアイコン描画準備結果
/// 概要: アイコン metadata の正規化結果、生成 HTML、診断をまとめます。
///
/// プロパティ:
/// - `library`: 正規化済み icon library。
/// - `name`: 正規化済み icon name。
/// - `source`: 正規化済み icon source。
/// - `html`: icon node 内へ保存する HTML。
/// - `diagnostics`: 生成時に発生した diagnostics。
struct OpenGraphiteIconMarkupResult: Equatable {
    var library: String
    var name: String
    var source: String
    var html: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: OpenGraphiteアイコンマークアップ生成器
/// 概要: GUI / CLI / MCP が共有する icon node 用の保存 HTML を生成します。
enum OpenGraphiteIconMarkup {
    static let defaultLibrary = "lucide"
    static let defaultName = "circle"
    static let defaultSource = "inline"

    private static let supportedLibraries: Set<String> = ["lucide"]
    private static let supportedSources: Set<String> = ["inline", "cdn", "library"]
    private static let lucideStaticCDNBaseURL = "https://cdn.jsdelivr.net/npm/lucide-static@latest/icons"
    private static let allowedNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    private static let lucideInlineBodies: [String: String] = [
        "arrow-right": #"<path d="M5 12h14"></path><path d="m12 5 7 7-7 7"></path>"#,
        "check": #"<path d="M20 6 9 17l-5-5"></path>"#,
        "circle": #"<circle cx="12" cy="12" r="10"></circle>"#,
        "heart": #"<path d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-7 7-7-7c-1.5-1.5-3-3.2-3-5.5"></path>"#,
        "minus": #"<path d="M5 12h14"></path>"#,
        "plus": #"<path d="M5 12h14"></path><path d="M12 5v14"></path>"#,
        "star": #"<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.751a.53.53 0 0 1 .294.904l-3.736 3.642a2.123 2.123 0 0 0-.611 1.878l.882 5.145a.53.53 0 0 1-.77.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.145a2.123 2.123 0 0 0-.611-1.879L2.16 9.79a.53.53 0 0 1 .294-.906l5.165-.75a2.123 2.123 0 0 0 1.596-1.16z"></path>"#,
        "x": #"<path d="M18 6 6 18"></path><path d="m6 6 12 12"></path>"#
    ]

    /// 論理名（日本語）: アイコン内容HTML生成関数
    /// 処理概要: library/name/source を検証して icon node の子 HTML を生成します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide。
    ///   - name: icon name。空の場合は circle。
    ///   - source: icon source。空の場合は inline。
    ///   - nodeID: diagnostics に付与する node ID。
    /// - Returns: 正規化済み metadata と生成 HTML。
    static func contentHTML(
        library: String,
        name: String,
        source: String,
        nodeID: String?
    ) -> OpenGraphiteIconMarkupResult {
        let normalizedLibrary = normalizeLibrary(library)
        let normalizedSource = normalizeSource(source)
        let normalizedName = normalizeName(name)

        guard supportedLibraries.contains(normalizedLibrary) else {
            return failure(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                code: "unsupported-icon-library",
                message: "\(normalizedLibrary) は対応していない icon library です。",
                nodeID: nodeID
            )
        }

        guard supportedSources.contains(normalizedSource) else {
            return failure(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                code: "unsupported-icon-source",
                message: "\(normalizedSource) は対応していない icon source です。",
                nodeID: nodeID
            )
        }

        guard isValidName(normalizedName) else {
            return failure(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                code: "invalid-icon-name",
                message: "icon name は a-z / 0-9 / - の非空文字列で指定してください。",
                nodeID: nodeID
            )
        }

        switch normalizedSource {
        case "inline":
            guard let body = lucideInlineBodies[normalizedName] else {
                return failure(
                    library: normalizedLibrary,
                    name: normalizedName,
                    source: normalizedSource,
                    code: "unsupported-inline-icon",
                    message: "\(normalizedName) は inline 保存に未対応です。cdn または library source を選択してください。",
                    nodeID: nodeID
                )
            }
            return OpenGraphiteIconMarkupResult(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                html: #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">\#(body)</svg>"#,
                diagnostics: []
            )
        case "cdn":
            let url = "\(lucideStaticCDNBaseURL)/\(normalizedName).svg"
            return OpenGraphiteIconMarkupResult(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                html: #"<span data-og-icon-mask="true" style="--og-icon-url:url('\#(url)');" aria-hidden="true"></span>"#,
                diagnostics: []
            )
        case "library":
            return OpenGraphiteIconMarkupResult(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                html: #"<i data-lucide="\#(normalizedName)" aria-hidden="true"></i>"#,
                diagnostics: []
            )
        default:
            return failure(
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                code: "unsupported-icon-source",
                message: "\(normalizedSource) は対応していない icon source です。",
                nodeID: nodeID
            )
        }
    }

    /// 論理名（日本語）: アイコン要素HTML生成関数
    /// 処理概要: icon node 全体を HTML 断片として生成します。
    ///
    /// - Parameters:
    ///   - id: `data-og-id`。
    ///   - internalID: `data-og-internal-id`。
    ///   - library: icon library。
    ///   - name: icon name。
    ///   - source: icon source。
    ///   - width: `--og-width`。空の場合は省略。
    ///   - height: `--og-height`。空の場合は省略。
    ///   - nodeID: diagnostics に付与する node ID。
    /// - Returns: 正規化済み metadata と icon node HTML。
    static func elementHTML(
        id: String,
        internalID: String,
        library: String,
        name: String,
        source: String,
        width: String?,
        height: String?,
        nodeID: String?
    ) -> OpenGraphiteIconMarkupResult {
        let content = contentHTML(library: library, name: name, source: source, nodeID: nodeID)
        guard content.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            return content
        }

        let attributes = iconAttributes(
            id: id,
            internalID: internalID,
            library: content.library,
            name: content.name,
            source: content.source,
            width: width,
            height: height
        )
            .map { "\($0.name)=\"\(escapeAttribute($0.value))\"" }
            .joined(separator: " ")

        return OpenGraphiteIconMarkupResult(
            library: content.library,
            name: content.name,
            source: content.source,
            html: "<Icon \(attributes)>\(content.html)</Icon>",
            diagnostics: []
        )
    }

    /// 論理名（日本語）: アイコンIDベース正規化関数
    /// 処理概要: icon name から `data-og-id` に使う安定した base ID を作ります。
    ///
    /// - Parameter name: icon name。
    /// - Returns: `icon-<name>` 形式の base ID。
    static func defaultDisplayIDBase(name: String) -> String {
        "icon-\(normalizeName(name))"
    }

    private static func normalizeLibrary(_ library: String) -> String {
        let normalized = library.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? defaultLibrary : normalized
    }

    private static func normalizeSource(_ source: String) -> String {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? defaultSource : normalized
    }

    private static func normalizeName(_ name: String) -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? defaultName : normalized
    }

    private static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.unicodeScalars.allSatisfy { allowedNameCharacters.contains($0) }
    }

    private static func iconAttributes(
        id: String,
        internalID: String,
        library: String,
        name: String,
        source: String,
        width: String?,
        height: String?
    ) -> [(name: String, value: String)] {
        var attributes: [(name: String, value: String)] = [
            ("data-og-id", id),
            ("data-og-internal-id", internalID),
            ("data-og-type", "icon"),
            ("data-og-icon-library", library),
            ("data-og-icon-name", name),
            ("data-og-icon-source", source)
        ]

        let styleDeclarations = [
            ("--og-width", width?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
            ("--og-height", height?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        ]
            .filter { !$0.1.isEmpty }
            .map { "\($0.0):\($0.1);" }
            .joined(separator: " ")
        if !styleDeclarations.isEmpty {
            attributes.append(("style", styleDeclarations))
        }
        return attributes
    }

    private static func failure(
        library: String,
        name: String,
        source: String,
        code: String,
        message: String,
        nodeID: String?
    ) -> OpenGraphiteIconMarkupResult {
        OpenGraphiteIconMarkupResult(
            library: library,
            name: name,
            source: source,
            html: "",
            diagnostics: [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: code,
                    message: message,
                    path: nil,
                    nodeID: nodeID
                )
            ]
        )
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }
}
