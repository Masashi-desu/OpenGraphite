import Foundation
import AppKit
import SwiftUI
import WebKit

/// 論理名（日本語）: OpenGraphiteフォントソースID
/// 概要: フォントブラウザで選べる情報ソースを表します。
///
/// 定義内容:
/// - `presets`: OpenGraphite 組み込みの安全な font stack。
/// - `external`: 外部 provider から取得・読み込みする Web font。
/// - `systemFonts`: 実行中 macOS にインストール済みのフォントファミリー。
/// - `customCSS`: 任意の CSS font-family 文字列。
enum OpenGraphiteFontSourceID: String, CaseIterable, Identifiable {
    case presets
    case external
    case systemFonts
    case customCSS

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presets:
            return "Presets"
        case .external:
            return "External"
        case .systemFonts:
            return "System"
        case .customCSS:
            return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .presets:
            return "Portable font stacks"
        case .external:
            return "Fonts from external providers"
        case .systemFonts:
            return "Installed on this Mac"
        case .customCSS:
            return "Direct CSS value"
        }
    }
}

/// 論理名（日本語）: OpenGraphite外部フォントProvider ID
/// 概要: External ソース内で選択できるフォント提供元を表します。
///
/// 定義内容:
/// - `googleFonts`: Google Fonts Developer API と CSS API v2 で扱う Web font。
enum OpenGraphiteExternalFontProviderID: String, CaseIterable, Identifiable {
    case googleFonts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .googleFonts:
            return "Google Fonts"
        }
    }

    var detail: String {
        switch self {
        case .googleFonts:
            return "Adds a stylesheet link"
        }
    }
}

/// 論理名（日本語）: OpenGraphiteフォントジャンルID
/// 概要: フォント候補を用途・形状・技術属性で絞り込む genre を表します。
///
/// 定義内容:
/// - `all`: 全候補。
/// - `sansSerif`: sans-serif 系。
/// - `serif`: serif 系。
/// - `monospace`: monospace / code 系。
/// - `display`: 見出し・装飾向け。
/// - `handwriting`: script / handwriting 系。
/// - `japanese`: 日本語向け。
/// - `ui`: UI 向け。
/// - `reading`: 長文・本文向け。
/// - `rounded`: 丸みのある書体。
/// - `condensed`: 幅が狭い書体。
/// - `variable`: variable font。
enum OpenGraphiteFontGenreID: String, CaseIterable, Identifiable {
    case all
    case sansSerif
    case serif
    case monospace
    case display
    case handwriting
    case japanese
    case ui
    case reading
    case rounded
    case condensed
    case variable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .sansSerif:
            return "Sans Serif"
        case .serif:
            return "Serif"
        case .monospace:
            return "Monospace"
        case .display:
            return "Display"
        case .handwriting:
            return "Handwriting"
        case .japanese:
            return "Japanese"
        case .ui:
            return "UI"
        case .reading:
            return "Reading"
        case .rounded:
            return "Rounded"
        case .condensed:
            return "Condensed"
        case .variable:
            return "Variable"
        }
    }

    var matchTokens: Set<String> {
        switch self {
        case .all:
            return []
        case .sansSerif:
            return ["sans-serif", "sans serif", "sans", "ui", "geometric", "neo grotesque", "grotesque"]
        case .serif:
            return ["serif", "reading", "editorial", "old style", "transitional", "slab"]
        case .monospace:
            return ["monospace", "mono", "code"]
        case .display:
            return ["display", "headline", "decorative"]
        case .handwriting:
            return ["handwriting", "script", "cursive", "handwritten"]
        case .japanese:
            return ["japanese", "ja", "jpan", "noto sans jp", "noto serif jp"]
        case .ui:
            return ["ui", "interface", "business"]
        case .reading:
            return ["reading", "editorial", "serif", "body"]
        case .rounded:
            return ["rounded", "round"]
        case .condensed:
            return ["condensed", "narrow"]
        case .variable:
            return ["variable"]
        }
    }
}

/// 論理名（日本語）: OpenGraphiteフォント候補
/// 概要: 単一フォント候補の表示情報、保存する CSS 値、必要な stylesheet 参照を保持します。
///
/// プロパティ:
/// - `id`: 候補の安定 ID。
/// - `sourceID`: 候補を提供する情報ソース。
/// - `externalProviderID`: External ソース内の provider。External 以外では `nil`。
/// - `familyName`: フォントファミリー名。
/// - `category`: sans-serif / serif などの分類。
/// - `cssFamily`: `--og-font-family` に保存する CSS 値。
/// - `stylesheetHref`: 選択時に HTML `<head>` へ追加する stylesheet。不要な場合は `nil`。
/// - `tags`: 検索用補助語。
struct OpenGraphiteFontCandidate: Identifiable, Equatable {
    var id: String
    var sourceID: OpenGraphiteFontSourceID
    var externalProviderID: OpenGraphiteExternalFontProviderID?
    var familyName: String
    var category: String
    var cssFamily: String
    var stylesheetHref: String?
    var tags: [String]

    var sourceTitle: String {
        if let externalProviderID {
            return externalProviderID.title
        }
        return sourceID.title
    }

    var searchText: String {
        ([familyName, category, sourceTitle] + tags)
            .joined(separator: " ")
            .lowercased()
    }

    var genreSearchText: String {
        ([familyName, category] + tags)
            .joined(separator: " ")
            .lowercased()
    }

    var nativePreviewFamilyNames: [String] {
        OpenGraphiteFontLibrary.nativePreviewFamilyNames(for: cssFamily)
    }
}

/// 論理名（日本語）: OpenGraphiteフォントライブラリ
/// 概要: フォントブラウザへ候補を提供する情報ソース別カタログです。
enum OpenGraphiteFontLibrary {
    static let defaultSampleText = "Design what is visible"
    static let candidateDisplayPageSize = 80

    static let googleFontCandidates: [OpenGraphiteFontCandidate] = [
        googleFont("Inter", category: "sans-serif", tags: ["ui", "latin", "variable"]),
        googleFont("Roboto", category: "sans-serif", tags: ["ui", "latin"]),
        googleFont("Open Sans", category: "sans-serif", tags: ["ui", "latin"]),
        googleFont("Lato", category: "sans-serif", tags: ["ui", "latin"]),
        googleFont("Noto Sans", category: "sans-serif", tags: ["global", "ui", "variable"]),
        googleFont("Work Sans", category: "sans-serif", tags: ["ui", "latin", "variable"]),
        googleFont("Source Sans 3", category: "sans-serif", tags: ["ui", "latin", "variable"]),
        googleFont("IBM Plex Sans", category: "sans-serif", tags: ["ui", "latin"]),
        googleFont("Public Sans", category: "sans-serif", tags: ["ui", "latin"]),
        googleFont("Atkinson Hyperlegible", category: "sans-serif", tags: ["ui", "reading", "latin"]),
        googleFont("Montserrat", category: "sans-serif", tags: ["display", "latin", "variable"]),
        googleFont("Poppins", category: "sans-serif", tags: ["display", "latin"]),
        googleFont("Raleway", category: "sans-serif", tags: ["display", "latin"]),
        googleFont("Nunito Sans", category: "sans-serif", tags: ["rounded", "ui", "latin"]),
        googleFont("Rubik", category: "sans-serif", tags: ["rounded", "ui", "latin"]),
        googleFont("Noto Serif", category: "serif", fallback: "serif", tags: ["global", "reading", "variable"]),
        googleFont("Merriweather", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("Lora", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("Libre Baskerville", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("Alegreya", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("EB Garamond", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("Playfair Display", category: "serif", fallback: "serif", tags: ["display", "editorial", "latin"]),
        googleFont("Crimson Pro", category: "serif", fallback: "serif", tags: ["editorial", "reading", "latin", "variable"]),
        googleFont("Source Serif 4", category: "serif", fallback: "serif", tags: ["reading", "latin", "variable"]),
        googleFont("IBM Plex Serif", category: "serif", fallback: "serif", tags: ["reading", "latin"]),
        googleFont("Roboto Serif", category: "serif", fallback: "serif", tags: ["reading", "latin", "variable"]),
        googleFont("IBM Plex Mono", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Roboto Mono", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Source Code Pro", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Fira Code", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("JetBrains Mono", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Inconsolata", category: "monospace", fallback: "monospace", tags: ["code", "latin", "variable"]),
        googleFont("Space Mono", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Cousine", category: "monospace", fallback: "monospace", tags: ["code", "latin"]),
        googleFont("Oswald", category: "sans-serif", tags: ["condensed", "display", "latin"]),
        googleFont("Roboto Condensed", category: "sans-serif", tags: ["condensed", "ui", "latin", "variable"]),
        googleFont("Barlow Condensed", category: "sans-serif", tags: ["condensed", "display", "latin"]),
        googleFont("Archivo Narrow", category: "sans-serif", tags: ["narrow", "ui", "latin"]),
        googleFont("Fjalla One", category: "sans-serif", tags: ["condensed", "headline", "latin"]),
        googleFont("Yanone Kaffeesatz", category: "sans-serif", tags: ["condensed", "headline", "latin"]),
        googleFont("PT Sans Narrow", category: "sans-serif", tags: ["narrow", "ui", "latin"]),
        googleFont("Teko", category: "sans-serif", tags: ["condensed", "display", "latin"]),
        googleFont("Bebas Neue", category: "display", tags: ["headline", "condensed", "latin"]),
        googleFont("Anton", category: "display", tags: ["headline", "latin"]),
        googleFont("Archivo Black", category: "display", tags: ["headline", "latin"]),
        googleFont("Abril Fatface", category: "display", fallback: "serif", tags: ["headline", "latin"]),
        googleFont("Lobster", category: "display", fallback: "cursive", tags: ["decorative", "script", "latin"]),
        googleFont("Pacifico", category: "handwriting", fallback: "cursive", tags: ["script", "latin"]),
        googleFont("Dancing Script", category: "handwriting", fallback: "cursive", tags: ["script", "latin"]),
        googleFont("Caveat", category: "handwriting", fallback: "cursive", tags: ["handwritten", "latin", "variable"]),
        googleFont("Indie Flower", category: "handwriting", fallback: "cursive", tags: ["handwritten", "latin"]),
        googleFont("Permanent Marker", category: "handwriting", fallback: "cursive", tags: ["marker", "latin"]),
        googleFont("Shadows Into Light", category: "handwriting", fallback: "cursive", tags: ["handwritten", "latin"]),
        googleFont("Great Vibes", category: "handwriting", fallback: "cursive", tags: ["script", "latin"]),
        googleFont("Kalam", category: "handwriting", fallback: "cursive", tags: ["handwritten", "latin"]),
        googleFont("Noto Sans JP", category: "sans-serif", tags: ["japanese", "ja", "ui", "variable"]),
        googleFont("Noto Serif JP", category: "serif", fallback: "serif", tags: ["japanese", "ja", "reading", "variable"]),
        googleFont("M PLUS 1p", category: "sans-serif", tags: ["japanese", "ja"]),
        googleFont("M PLUS Rounded 1c", category: "sans-serif", tags: ["japanese", "ja", "rounded"]),
        googleFont("Kosugi", category: "sans-serif", tags: ["japanese", "ja"]),
        googleFont("Kosugi Maru", category: "sans-serif", tags: ["japanese", "ja", "rounded"]),
        googleFont("Sawarabi Gothic", category: "sans-serif", tags: ["japanese", "ja"]),
        googleFont("Sawarabi Mincho", category: "serif", fallback: "serif", tags: ["japanese", "ja", "reading"]),
        googleFont("Zen Kaku Gothic New", category: "sans-serif", tags: ["japanese", "ja", "ui"]),
        googleFont("Zen Maru Gothic", category: "sans-serif", tags: ["japanese", "ja", "rounded"]),
        googleFont("Quicksand", category: "sans-serif", tags: ["rounded", "display", "latin"]),
        googleFont("Varela Round", category: "sans-serif", tags: ["rounded", "ui", "latin"]),
        googleFont("Comfortaa", category: "sans-serif", tags: ["rounded", "display", "latin"]),
        googleFont("Baloo 2", category: "display", tags: ["rounded", "latin", "variable"]),
        googleFont("Roboto Flex", category: "sans-serif", tags: ["ui", "latin", "variable"]),
        googleFont("Recursive", category: "sans-serif", tags: ["ui", "code", "latin", "variable"]),
        googleFont("Fraunces", category: "serif", fallback: "serif", tags: ["display", "editorial", "latin", "variable"])
    ]

    /// 論理名（日本語）: フォント候補取得関数
    /// 処理概要: 指定ソースの候補一覧を返します。
    ///
    /// - Parameter sourceID: 情報ソース ID。
    /// - Returns: 対応するフォント候補一覧。
    static func candidates(for sourceID: OpenGraphiteFontSourceID) -> [OpenGraphiteFontCandidate] {
        switch sourceID {
        case .presets:
            return CSSFontFamilyPreset.presets.map { preset in
                OpenGraphiteFontCandidate(
                    id: "preset:\(preset.id)",
                    sourceID: .presets,
                    externalProviderID: nil,
                    familyName: preset.title,
                    category: "preset",
                    cssFamily: preset.cssValue,
                    stylesheetHref: nil,
                    tags: [preset.id]
                )
            }
        case .external:
            return googleFontCandidates
        case .systemFonts:
            return NSFontManager.shared.availableFontFamilies
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { familyName in
                    OpenGraphiteFontCandidate(
                        id: "system:\(familyName)",
                        sourceID: .systemFonts,
                        externalProviderID: nil,
                        familyName: familyName,
                        category: "system",
                        cssFamily: "\(quotedCSSFamilyName(familyName)), system-ui, sans-serif",
                        stylesheetHref: nil,
                        tags: ["local"]
                    )
                }
        case .customCSS:
            return []
        }
    }

    /// 論理名（日本語）: フォント候補検索関数
    /// 処理概要: 指定ソースの候補を検索文字列で絞り込みます。
    ///
    /// - Parameters:
    ///   - sourceID: 情報ソース ID。
    ///   - query: 検索文字列。
    /// - Returns: 検索条件に合う候補一覧。
    static func filteredCandidates(
        for sourceID: OpenGraphiteFontSourceID,
        query: String
    ) -> [OpenGraphiteFontCandidate] {
        filteredCandidates(candidates(for: sourceID), query: query, genreID: .all)
    }

    /// 論理名（日本語）: 指定候補検索関数
    /// 処理概要: 呼び出し元が用意した候補一覧を検索文字列と genre で絞り込みます。
    ///
    /// - Parameters:
    ///   - candidates: 検索対象のフォント候補一覧。
    ///   - query: 検索文字列。
    ///   - genreID: genre filter。
    /// - Returns: 検索条件に合う候補一覧。
    static func filteredCandidates(
        _ candidates: [OpenGraphiteFontCandidate],
        query: String,
        genreID: OpenGraphiteFontGenreID = .all
    ) -> [OpenGraphiteFontCandidate] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let genreCandidates = candidates.filter { candidate in
            matchesGenre(candidate, genreID: genreID)
        }
        guard !normalizedQuery.isEmpty else { return genreCandidates }
        let terms = normalizedQuery.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return genreCandidates
            .filter { candidate in
                terms.allSatisfy { candidate.searchText.contains($0) }
            }
    }

    /// 論理名（日本語）: フォント候補表示制限関数
    /// 処理概要: 検索済み候補から現在 UI に描画する件数だけを取り出します。
    ///
    /// - Parameters:
    ///   - candidates: 検索・genre filter 適用済みのフォント候補一覧。
    ///   - limit: 表示上限件数。
    /// - Returns: 表示上限内のフォント候補一覧。
    static func displayedCandidates(
        _ candidates: [OpenGraphiteFontCandidate],
        limit: Int
    ) -> [OpenGraphiteFontCandidate] {
        Array(candidates.prefix(max(0, limit)))
    }

    /// 論理名（日本語）: 次回フォント候補表示上限算出関数
    /// 処理概要: `Show more` 実行時の次の表示上限件数を返します。
    ///
    /// - Parameters:
    ///   - currentLimit: 現在の表示上限件数。
    ///   - totalCount: 検索・genre filter 適用済み候補の総数。
    /// - Returns: 次に適用する表示上限件数。
    static func nextCandidateDisplayLimit(
        currentLimit: Int,
        totalCount: Int
    ) -> Int {
        min(max(0, currentLimit) + candidateDisplayPageSize, max(0, totalCount))
    }

    /// 論理名（日本語）: フォント候補Genre照合関数
    /// 処理概要: 候補の category と tags が指定 genre に該当するか判定します。
    ///
    /// - Parameters:
    ///   - candidate: 判定対象の候補。
    ///   - genreID: genre filter。
    /// - Returns: 指定 genre に該当する場合は `true`。
    static func matchesGenre(
        _ candidate: OpenGraphiteFontCandidate,
        genreID: OpenGraphiteFontGenreID
    ) -> Bool {
        guard genreID != .all else { return true }
        let candidateTokens = Set(([candidate.category] + candidate.tags).map { $0.lowercased() })
        return !candidateTokens.isDisjoint(with: genreID.matchTokens)
    }

    /// 論理名（日本語）: 現在値候補照合関数
    /// 処理概要: 保存済み CSS font-family 値に一致する既知候補を探します。
    ///
    /// - Parameter cssFamily: 検索する CSS font-family 値。
    /// - Returns: 一致した候補。見つからない場合は `nil`。
    static func candidate(matching cssFamily: String) -> OpenGraphiteFontCandidate? {
        let normalizedValue = CSSFontFamilyPreset.normalized(cssFamily)
        guard !normalizedValue.isEmpty else { return nil }
        let sourceCandidates = OpenGraphiteFontSourceID.allCases
            .filter { $0 != .systemFonts && $0 != .customCSS }
            .flatMap { candidates(for: $0) }
        if let exactCandidate = sourceCandidates.first(where: { CSSFontFamilyPreset.normalized($0.cssFamily) == normalizedValue }) {
            return exactCandidate
        }

        let familyNames = nativePreviewFamilyNames(for: cssFamily)
            .map { $0.lowercased() }
        guard !familyNames.isEmpty else { return nil }
        for familyName in familyNames {
            if let candidate = sourceCandidates.first(where: { $0.familyName.lowercased() == familyName }) {
                return candidate
            }
        }
        return nil
    }

    /// 論理名（日本語）: Custom候補生成関数
    /// 処理概要: 任意 CSS font-family 文字列をフォント候補として包みます。
    ///
    /// - Parameters:
    ///   - cssFamily: 保存する CSS font-family 値。
    ///   - stylesheetInput: HTML head に追加する stylesheet URL または embed snippet。
    /// - Returns: Custom ソースの候補。
    static func customCandidate(cssFamily: String, stylesheetInput: String = "") -> OpenGraphiteFontCandidate {
        let normalizedValue = cssFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        let stylesheetHref = customStylesheetHref(from: stylesheetInput)
        return OpenGraphiteFontCandidate(
            id: "custom:\(normalizedValue):\(stylesheetHref ?? "")",
            sourceID: .customCSS,
            externalProviderID: nil,
            familyName: "Custom CSS",
            category: "custom",
            cssFamily: normalizedValue,
            stylesheetHref: stylesheetHref,
            tags: []
        )
    }

    /// 論理名（日本語）: Customフォントstylesheet抽出関数
    /// 処理概要: URL、`<link>`、`@import` の入力から stylesheet href を取り出します。
    ///
    /// - Parameter input: ユーザーが入力した stylesheet URL または embed snippet。
    /// - Returns: HTML head に追加する stylesheet href。空入力なら `nil`。
    static func customStylesheetHref(from input: String) -> String? {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else { return nil }

        if let href = stylesheetHrefFromLinkTags(in: normalizedInput) {
            return normalizedStylesheetHref(href)
        }

        let hrefPattern = #"href\s*=\s*["']([^"']+)["']"#
        if let href = firstRegexCapture(pattern: hrefPattern, in: normalizedInput) {
            return normalizedStylesheetHref(href)
        }

        let importPattern = #"@import\s+(?:url\()?["']?([^"'\)\s]+)["']?\)?"#
        if let href = firstRegexCapture(pattern: importPattern, in: normalizedInput) {
            return normalizedStylesheetHref(href)
        }

        return normalizedStylesheetHref(normalizedInput)
    }

    /// 論理名（日本語）: ネイティブプレビューフォント候補取得関数
    /// 処理概要: CSS font-family 値から macOS 上で直接解決できる可能性がある family 名を抽出します。
    ///
    /// - Parameter cssFamily: CSS font-family 文字列。
    /// - Returns: generic family を除いた候補 family 名。
    static func nativePreviewFamilyNames(for cssFamily: String) -> [String] {
        CSSValueTokenizer.splitCommas(cssFamily)
            .map(unquotedCSSFamilyName)
            .filter { !$0.isEmpty && !isGenericCSSFamily($0) }
    }

    /// 論理名（日本語）: Google Fonts候補生成関数
    /// 処理概要: Google Fonts の family metadata から保存・読み込みに必要な候補を生成します。
    ///
    /// - Parameters:
    ///   - familyName: Google Fonts の family 名。
    ///   - category: Google Fonts metadata の category。
    ///   - tags: 検索補助に使う tag。
    /// - Returns: External / Google Fonts provider のフォント候補。
    static func googleFontCandidate(
        familyName: String,
        category: String,
        tags: [String] = []
    ) -> OpenGraphiteFontCandidate {
        googleFont(
            familyName,
            category: category,
            fallback: googleFallback(for: category),
            tags: tags
        )
    }

    private static func googleFont(
        _ familyName: String,
        category: String,
        fallback: String = "sans-serif",
        tags: [String] = []
    ) -> OpenGraphiteFontCandidate {
        OpenGraphiteFontCandidate(
            id: "google:\(familyName)",
            sourceID: .external,
            externalProviderID: .googleFonts,
            familyName: familyName,
            category: category,
            cssFamily: "\(quotedCSSFamilyName(familyName)), \(fallback)",
            stylesheetHref: googleStylesheetHref(familyName: familyName),
            tags: tags
        )
    }

    private static func googleStylesheetHref(familyName: String) -> String {
        let encodedFamily = familyName
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: "+")
        return "https://fonts.googleapis.com/css2?family=\(encodedFamily)&display=swap"
    }

    private static func quotedCSSFamilyName(_ familyName: String) -> String {
        "\"\(familyName.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func firstRegexCapture(pattern: String, in input: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: fullRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: input)
        else {
            return nil
        }
        return String(input[range])
    }

    private static func regexMatches(pattern: String, in input: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.matches(in: input, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: input) else { return nil }
            return String(input[range])
        }
    }

    private static func stylesheetHrefFromLinkTags(in input: String) -> String? {
        let linkTags = regexMatches(pattern: #"<link\b[^>]*>"#, in: input)
        for linkTag in linkTags {
            guard let href = firstRegexCapture(pattern: #"href\s*=\s*["']([^"']+)["']"#, in: linkTag) else {
                continue
            }
            let lowercasedTag = linkTag.lowercased()
            let lowercasedHref = href.lowercased()
            if lowercasedTag.contains("stylesheet")
                || lowercasedHref.contains("fonts.googleapis.com/css")
                || lowercasedHref.contains(".css") {
                return href
            }
        }
        return nil
    }

    private static func normalizedStylesheetHref(_ href: String) -> String {
        href
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func googleFallback(for category: String) -> String {
        switch category.lowercased() {
        case "serif":
            return "serif"
        case "monospace":
            return "monospace"
        case "handwriting":
            return "cursive"
        default:
            return "sans-serif"
        }
    }

    private static func unquotedCSSFamilyName(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.count >= 2 else { return trimmedValue }
        let firstCharacter = trimmedValue.first
        let lastCharacter = trimmedValue.last
        if (firstCharacter == "\"" && lastCharacter == "\"") || (firstCharacter == "'" && lastCharacter == "'") {
            return String(trimmedValue.dropFirst().dropLast())
        }
        return trimmedValue
    }

    private static func isGenericCSSFamily(_ familyName: String) -> Bool {
        let normalizedName = familyName.lowercased()
        return [
            "serif",
            "sans-serif",
            "monospace",
            "cursive",
            "fantasy",
            "system-ui",
            "ui-sans-serif",
            "ui-serif",
            "ui-monospace",
            "-apple-system",
            "blinkmacsystemfont"
        ].contains(normalizedName)
    }
}

/// 論理名（日本語）: OpenGraphiteフォントプレビュー解決器
/// 概要: フォント候補を macOS ネイティブ描画用の `NSFont` へ変換します。
enum OpenGraphiteFontPreviewResolver {
    /// 論理名（日本語）: NSFont解決関数
    /// 処理概要: 候補の family 名または CSS font-family から利用可能な macOS フォントを探します。
    ///
    /// - Parameters:
    ///   - candidate: プレビュー対象のフォント候補。
    ///   - size: 表示サイズ。
    ///   - weight: フォントウェイト。
    /// - Returns: 解決できた `NSFont`。見つからない場合はシステムフォント。
    static func nsFont(
        for candidate: OpenGraphiteFontCandidate,
        size: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSFont {
        let familyNames = ([candidate.familyName] + candidate.nativePreviewFamilyNames).removingDuplicates()
        for familyName in familyNames {
            if let familyFont = NSFontManager.shared.font(
                withFamily: familyName,
                traits: [],
                weight: nsFontManagerWeight(for: weight),
                size: size
            ) {
                return familyFont
            }
            if let namedFont = NSFont(name: familyName, size: size) {
                return namedFont
            }
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private static func nsFontManagerWeight(for weight: NSFont.Weight) -> Int {
        switch weight {
        case .ultraLight:
            return 2
        case .thin:
            return 3
        case .light:
            return 4
        case .regular:
            return 5
        case .medium:
            return 6
        case .semibold:
            return 8
        case .bold:
            return 9
        case .heavy:
            return 10
        case .black:
            return 12
        default:
            return 5
        }
    }
}

private extension Array where Element: Hashable {
    /// 論理名（日本語）: 重複除去関数
    /// 処理概要: 配列の出現順を保ったまま重複要素を取り除きます。
    ///
    /// - Returns: 重複要素を除いた配列。
    func removingDuplicates() -> [Element] {
        var seenElements: Set<Element> = []
        return filter { element in
            seenElements.insert(element).inserted
        }
    }
}

/// 論理名（日本語）: OpenGraphite Google Fonts Client
/// 概要: Google Fonts Developer API からフォント metadata を取得し、OpenGraphite の候補へ変換します。
enum OpenGraphiteGoogleFontsClient {
    /// 論理名（日本語）: Google Fonts候補取得関数
    /// 処理概要: API key を使って Google Fonts Developer API から全 family metadata を取得します。
    ///
    /// - Parameter apiKey: Google Fonts Developer API key。
    /// - Returns: 取得した Google Fonts 候補一覧。
    /// 参考URL:
    /// https://developers.google.com/fonts/docs/developer_api
    static func fetchCandidates(apiKey: String) async throws -> [OpenGraphiteFontCandidate] {
        var components = URLComponents(string: "https://www.googleapis.com/webfonts/v1/webfonts")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "sort", value: "popularity")
        ]
        guard let url = components?.url else {
            throw OpenGraphiteGoogleFontsClientError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenGraphiteGoogleFontsClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw OpenGraphiteGoogleFontsClientError.badStatus(httpResponse.statusCode)
        }

        return try candidates(from: data)
    }

    /// 論理名（日本語）: Google Fontsレスポンス変換関数
    /// 処理概要: Developer API の JSON response を OpenGraphite の候補一覧へ変換します。
    ///
    /// - Parameter data: Developer API の JSON response。
    /// - Returns: OpenGraphite の Google Fonts 候補一覧。
    static func candidates(from data: Data) throws -> [OpenGraphiteFontCandidate] {
        let response = try JSONDecoder().decode(OpenGraphiteGoogleFontsResponse.self, from: data)
        return response.items.map { font in
            OpenGraphiteFontLibrary.googleFontCandidate(
                familyName: font.family,
                category: font.category,
                tags: font.searchTags
            )
        }
    }
}

/// 論理名（日本語）: OpenGraphite Google Fonts Client Error
/// 概要: Google Fonts Developer API 取得時に発生するエラーを表します。
///
/// 定義内容:
/// - `invalidURL`: API URL を構成できない。
/// - `invalidResponse`: HTTP response として解釈できない。
/// - `badStatus`: API が 2xx 以外の HTTP status を返した。
enum OpenGraphiteGoogleFontsClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Google Fonts API URL を構成できませんでした。"
        case .invalidResponse:
            return "Google Fonts API response を解釈できませんでした。"
        case let .badStatus(statusCode):
            return "Google Fonts API request failed (\(statusCode))."
        }
    }
}

/// 論理名（日本語）: OpenGraphite Google Fonts Response
/// 概要: Google Fonts Developer API の family list response を decode します。
///
/// プロパティ:
/// - `items`: 取得した font family metadata。
private struct OpenGraphiteGoogleFontsResponse: Decodable {
    var items: [OpenGraphiteGoogleFontsItem]
}

/// 論理名（日本語）: OpenGraphite Google Fonts Item
/// 概要: Google Fonts Developer API の単一 font family metadata を decode します。
///
/// プロパティ:
/// - `family`: family 名。
/// - `category`: serif / sans-serif などの分類。
/// - `subsets`: 対応 script。
/// - `variants`: 対応 variant。
private struct OpenGraphiteGoogleFontsItem: Decodable {
    var family: String
    var category: String
    var subsets: [String]?
    var variants: [String]?
    var axes: [OpenGraphiteGoogleFontsAxis]?

    var searchTags: [String] {
        var tags = (subsets ?? []) + (variants ?? [])
        if let variants, variants.count >= 6 {
            tags.append("many-styles")
        }
        if let axes, !axes.isEmpty {
            tags.append("variable")
            tags.append(contentsOf: axes.map { "axis-\($0.tag.lowercased())" })
        }
        return tags
    }
}

/// 論理名（日本語）: OpenGraphite Google Fonts Axis
/// 概要: Google Fonts Developer API の variable font axis metadata を decode します。
///
/// プロパティ:
/// - `tag`: axis tag。
private struct OpenGraphiteGoogleFontsAxis: Decodable {
    var tag: String
}

/// 論理名（日本語）: OpenGraphiteフォントブラウザ
/// 概要: 情報ソースを選び、その中のフォント候補を検索・プレビュー・適用する小窓です。
///
/// プロパティ:
/// - `currentValue`: 現在の `--og-font-family` 値。
/// - `sampleText`: プレビューに表示する文言。
/// - `onSelect`: 選択確定時に呼び出す処理。
struct OpenGraphiteFontBrowserView: View {
    var currentValue: String
    var sampleText: String
    var onSelect: (OpenGraphiteFontCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: OpenGraphiteFontSourceID
    @State private var externalProviderID: OpenGraphiteExternalFontProviderID
    @State private var selectedGenreID: OpenGraphiteFontGenreID = .all
    @State private var query = ""
    @State private var selectedCandidateID: String?
    @State private var customCSSValue: String
    @State private var customStylesheetInput: String
    @State private var googleFontsAPIKey: String
    @State private var fetchedGoogleFontCandidates: [OpenGraphiteFontCandidate] = []
    @State private var externalFontMessage: String?
    @State private var isLoadingExternalFonts = false
    @State private var candidateDisplayLimit = OpenGraphiteFontLibrary.candidateDisplayPageSize

    /// 論理名（日本語）: OpenGraphiteフォントブラウザ初期化関数
    /// 処理概要: 現在値から初期ソースと選択候補を推定します。
    ///
    /// - Parameters:
    ///   - currentValue: 現在の `--og-font-family` 値。
    ///   - sampleText: プレビューに表示する文言。
    ///   - onSelect: 選択確定時に呼び出す処理。
    init(
        currentValue: String,
        sampleText: String = OpenGraphiteFontLibrary.defaultSampleText,
        onSelect: @escaping (OpenGraphiteFontCandidate) -> Void
    ) {
        self.currentValue = currentValue
        self.sampleText = sampleText
        self.onSelect = onSelect
        let matchedCandidate = OpenGraphiteFontLibrary.candidate(matching: currentValue)
        let normalizedCurrentValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialSourceID = matchedCandidate?.sourceID ?? (normalizedCurrentValue.isEmpty ? .external : .customCSS)
        let initialProviderID = matchedCandidate?.externalProviderID ?? .googleFonts
        let apiKey = ProcessInfo.processInfo.environment["OPENGRAPHITE_GOOGLE_FONTS_API_KEY"] ?? ""
        _sourceID = State(initialValue: initialSourceID)
        _externalProviderID = State(initialValue: initialProviderID)
        _selectedCandidateID = State(initialValue: matchedCandidate?.id)
        _customCSSValue = State(initialValue: normalizedCurrentValue)
        _customStylesheetInput = State(initialValue: matchedCandidate?.stylesheetHref ?? "")
        _googleFontsAPIKey = State(initialValue: apiKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectedTextPreview
            Divider()
            sourceSelector
            Divider()
            HStack(spacing: 0) {
                sourcePanel
                    .frame(width: 320)
                Divider()
                previewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 840, height: 640)
        .onAppear {
            selectInitialCandidateIfNeeded()
            loadExternalFontsIfPossible()
        }
        .onChange(of: sourceID) { _, _ in
            resetCandidateDisplayLimit()
            selectInitialCandidateIfNeeded()
            loadExternalFontsIfPossible()
        }
        .onChange(of: externalProviderID) { _, _ in
            resetCandidateDisplayLimit()
            selectedCandidateID = nil
            selectInitialCandidateIfNeeded()
            loadExternalFontsIfPossible()
        }
        .onChange(of: selectedGenreID) { _, _ in
            resetCandidateDisplayLimit()
            selectedCandidateID = nil
            selectInitialCandidateIfNeeded()
        }
        .onChange(of: query) { _, _ in
            resetCandidateDisplayLimit()
            selectInitialCandidateIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Font Library")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var selectedTextPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Selected text preview")
                    .font(.caption.weight(.semibold))
                Text(activeCandidate.cssFamily.isEmpty ? "unset" : activeCandidate.cssFamily)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            OpenGraphiteSelectedTextFontPreview(
                candidate: activeCandidate,
                sampleText: selectedPreviewText
            )
            .frame(height: 74)
            .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sourceSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Source")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Source", selection: $sourceID) {
                ForEach(OpenGraphiteFontSourceID.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 390)

            Text(sourceDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sourceID != .customCSS {
                directCSSFamilyQuickEntry
            }

            if sourceID == .customCSS {
                customEditor
            } else if sourceID == .external {
                externalProviderControls

                TextField("Search fonts", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                fontList
                .frame(maxHeight: .infinity)
            } else {
                TextField("Search fonts", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                fontList
                .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
    }

    private var directCSSFamilyQuickEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Direct --og-font-family")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("\"Brand Sans\", system-ui, sans-serif", text: $customCSSValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .controlSize(.small)
                    .onSubmit(activateCustomCSSValue)

                Button("Use") {
                    activateCustomCSSValue()
                }
                .controlSize(.small)
                .disabled(customCSSValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextField("Stylesheet URL or embed <link>", text: $customStylesheetInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption2.monospaced())
                .controlSize(.small)
                .onSubmit(activateCustomCSSValue)
        }
        .padding(8)
        .background(
            EditorColumnStyle.elevatedRowFill,
            in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(EditorColumnStyle.separatorColor.opacity(0.7), lineWidth: 1)
        )
    }

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CSS font-family")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $customCSSValue)
                .font(.caption.monospaced())
                .scrollContentBackground(.hidden)
                .frame(minHeight: 116)
                .padding(6)
                .background(
                    EditorColumnStyle.elevatedRowFill,
                    in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
                )

            Text("Example: \"Brand Sans\", system-ui, sans-serif")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Stylesheet URL or embed <link>")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            TextField("https://fonts.googleapis.com/css2?family=Brand+Sans&display=swap", text: $customStylesheetInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .controlSize(.small)

            Spacer()
        }
    }

    private var externalProviderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Provider")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Provider", selection: $externalProviderID) {
                    ForEach(OpenGraphiteExternalFontProviderID.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { loadExternalFonts(force: true) }) {
                    if isLoadingExternalFonts {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 16, height: 16)
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh")
                .disabled(isExternalFetchDisabled)
            }

            if externalProviderID == .googleFonts {
                SecureField("Google Fonts API key", text: $googleFontsAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit {
                        loadExternalFonts(force: true)
                    }
            }

            HStack(spacing: 8) {
                Text("Genre")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Genre", selection: $selectedGenreID) {
                    ForEach(OpenGraphiteFontGenreID.allCases) { genre in
                        Text(genre.title).tag(genre)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let externalStatusText {
                Text(externalStatusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fontList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(displayedCandidates) { candidate in
                    OpenGraphiteFontCandidateRow(
                        candidate: candidate,
                        isSelected: candidate.id == selectedCandidateID,
                        onSelect: {
                            selectedCandidateID = candidate.id
                        }
                    )
                }

                fontListFooter
            }
            .padding(5)
        }
        .background(
            EditorColumnStyle.elevatedRowFill,
            in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var fontListFooter: some View {
        if filteredCandidates.isEmpty {
            Text("No fonts found")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 6) {
                Text("Showing \(displayedCandidates.count) of \(filteredCandidates.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if hasMoreCandidates {
                    Button("Show more") {
                        candidateDisplayLimit = OpenGraphiteFontLibrary.nextCandidateDisplayLimit(
                            currentLimit: candidateDisplayLimit,
                            totalCount: filteredCandidates.count
                        )
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var previewPanel: some View {
        OpenGraphiteFontPreviewPanel(
            candidate: activeCandidate,
            sampleText: sampleText
        )
        .padding(16)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            Button("Apply") {
                onSelect(activeCandidate)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canApply)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filteredCandidates: [OpenGraphiteFontCandidate] {
        OpenGraphiteFontLibrary.filteredCandidates(
            sourceCandidates,
            query: query,
            genreID: activeGenreID
        )
    }

    private var displayedCandidates: [OpenGraphiteFontCandidate] {
        OpenGraphiteFontLibrary.displayedCandidates(
            filteredCandidates,
            limit: candidateDisplayLimit
        )
    }

    private var hasMoreCandidates: Bool {
        displayedCandidates.count < filteredCandidates.count
    }

    private var sourceCandidates: [OpenGraphiteFontCandidate] {
        switch sourceID {
        case .external:
            return externalProviderCandidates
        default:
            return OpenGraphiteFontLibrary.candidates(for: sourceID)
        }
    }

    private var externalProviderCandidates: [OpenGraphiteFontCandidate] {
        switch externalProviderID {
        case .googleFonts:
            guard fetchedGoogleFontCandidates.isEmpty else { return fetchedGoogleFontCandidates }
            return OpenGraphiteFontLibrary.candidates(for: .external)
                .filter { $0.externalProviderID == .googleFonts }
        }
    }

    private var selectedCandidate: OpenGraphiteFontCandidate? {
        guard let selectedCandidateID else { return nil }
        return filteredCandidates.first { $0.id == selectedCandidateID }
            ?? sourceCandidates.first { $0.id == selectedCandidateID }
    }

    private var activeCandidate: OpenGraphiteFontCandidate {
        if sourceID == .customCSS {
            return OpenGraphiteFontLibrary.customCandidate(
                cssFamily: customCSSValue,
                stylesheetInput: customStylesheetInput
            )
        }
        return selectedCandidate ?? filteredCandidates.first ?? OpenGraphiteFontLibrary.customCandidate(cssFamily: currentValue)
    }

    private var canApply: Bool {
        !activeCandidate.cssFamily.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeGenreID: OpenGraphiteFontGenreID {
        sourceID == .external ? selectedGenreID : .all
    }

    private var selectedPreviewText: String {
        let normalizedText = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedText.isEmpty {
            return OpenGraphiteFontLibrary.defaultSampleText
        }
        return normalizedText
    }

    private var sourceDetail: String {
        if sourceID == .external {
            return externalProviderID.detail
        }
        return sourceID.detail
    }

    private var externalStatusText: String? {
        if let externalFontMessage {
            return externalFontMessage
        }
        if externalProviderID == .googleFonts,
           googleFontsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Using bundled Google Fonts."
        }
        return nil
    }

    private var isExternalFetchDisabled: Bool {
        isLoadingExternalFonts || googleFontsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func selectInitialCandidateIfNeeded() {
        guard sourceID != .customCSS else { return }
        let candidates = filteredCandidates
        guard !candidates.isEmpty else {
            selectedCandidateID = nil
            return
        }
        if let selectedCandidateID,
           candidates.contains(where: { $0.id == selectedCandidateID }) {
            ensureSelectedCandidateIsVisible(in: candidates)
            return
        }
        selectedCandidateID = candidates[0].id
        ensureSelectedCandidateIsVisible(in: candidates)
    }

    private func resetCandidateDisplayLimit() {
        candidateDisplayLimit = OpenGraphiteFontLibrary.candidateDisplayPageSize
    }

    private func ensureSelectedCandidateIsVisible(in candidates: [OpenGraphiteFontCandidate]) {
        guard let selectedCandidateID,
              let selectedIndex = candidates.firstIndex(where: { $0.id == selectedCandidateID }),
              selectedIndex >= candidateDisplayLimit
        else {
            return
        }
        let pageSize = OpenGraphiteFontLibrary.candidateDisplayPageSize
        candidateDisplayLimit = ((selectedIndex / pageSize) + 1) * pageSize
    }

    private func activateCustomCSSValue() {
        selectedCandidateID = nil
        sourceID = .customCSS
        resetCandidateDisplayLimit()
    }

    private func loadExternalFontsIfPossible() {
        guard sourceID == .external else { return }
        guard externalProviderID == .googleFonts else { return }
        guard !googleFontsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            externalFontMessage = nil
            return
        }
        loadExternalFonts(force: false)
    }

    private func loadExternalFonts(force: Bool) {
        guard sourceID == .external else { return }
        guard externalProviderID == .googleFonts else { return }
        let apiKey = googleFontsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            fetchedGoogleFontCandidates = []
            externalFontMessage = "Using bundled Google Fonts."
            resetCandidateDisplayLimit()
            selectInitialCandidateIfNeeded()
            return
        }
        if !force && !fetchedGoogleFontCandidates.isEmpty {
            return
        }

        isLoadingExternalFonts = true
        externalFontMessage = nil
        Task {
            do {
                let candidates = try await OpenGraphiteGoogleFontsClient.fetchCandidates(apiKey: apiKey)
                await MainActor.run {
                    fetchedGoogleFontCandidates = candidates
                    isLoadingExternalFonts = false
                    externalFontMessage = "Loaded \(candidates.count) Google Fonts."
                    resetCandidateDisplayLimit()
                    selectInitialCandidateIfNeeded()
                }
            } catch {
                await MainActor.run {
                    fetchedGoogleFontCandidates = []
                    isLoadingExternalFonts = false
                    externalFontMessage = "Live catalog unavailable. Showing bundled Google Fonts."
                    resetCandidateDisplayLimit()
                    selectInitialCandidateIfNeeded()
                }
            }
        }
    }
}

/// 論理名（日本語）: OpenGraphiteフォント候補行
/// 概要: フォントブラウザの一覧に表示する候補行です。
///
/// プロパティ:
/// - `candidate`: 表示するフォント候補。
/// - `isSelected`: 選択中の行かどうか。
/// - `onSelect`: 行選択時に呼び出す処理。
private struct OpenGraphiteFontCandidateRow: View {
    var candidate: OpenGraphiteFontCandidate
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    OpenGraphiteNativeFontText(candidate: candidate, text: candidate.familyName, isSelected: isSelected)
                        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading)
                        .allowsHitTesting(false)
                    Text(candidate.category)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }
                Text(candidate.cssFamily)
                    .font(.caption2.monospaced())
                    .foregroundStyle(isSelected ? .white.opacity(0.72) : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: some ShapeStyle {
        isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear)
    }
}

/// 論理名（日本語）: OpenGraphiteネイティブフォントテキスト
/// 概要: macOS にインストール済みのフォントで短いラベルを描画します。
///
/// プロパティ:
/// - `candidate`: フォント候補。
/// - `text`: 表示文言。
/// - `isSelected`: 選択中の表示色にするかどうか。
private struct OpenGraphiteNativeFontText: NSViewRepresentable {
    var candidate: OpenGraphiteFontCandidate
    var text: String
    var isSelected: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(labelWithString: text)
        textField.lineBreakMode = .byTruncatingTail
        textField.usesSingleLineMode = true
        textField.maximumNumberOfLines = 1
        textField.backgroundColor = .clear
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        textField.stringValue = text
        textField.font = OpenGraphiteFontPreviewResolver.nsFont(for: candidate, size: 15, weight: .semibold)
        textField.textColor = isSelected ? .selectedMenuItemTextColor : .labelColor
    }
}

/// 論理名（日本語）: OpenGraphiteフォントプレビューパネル
/// 概要: 選択フォントの Web プレビューと保存値を表示します。
///
/// プロパティ:
/// - `candidate`: プレビューするフォント候補。
/// - `sampleText`: プレビューに表示する文言。
private struct OpenGraphiteFontPreviewPanel: View {
    var candidate: OpenGraphiteFontCandidate
    var sampleText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.familyName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(candidate.sourceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            OpenGraphiteWebFontPreview(candidate: candidate, sampleText: sampleText)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                        .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("--og-font-family")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Text(candidate.cssFamily.isEmpty ? "unset" : candidate.cssFamily)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let stylesheetHref = candidate.stylesheetHref {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stylesheet")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text(stylesheetHref)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
    }
}

/// 論理名（日本語）: OpenGraphite選択テキストフォントプレビュー
/// 概要: フォント選択画面上部で、選択中テキストを候補フォントで即時描画します。
///
/// プロパティ:
/// - `candidate`: プレビューするフォント候補。
/// - `sampleText`: 選択中ノードから渡されたプレビュー文言。
private struct OpenGraphiteSelectedTextFontPreview: NSViewRepresentable {
    var candidate: OpenGraphiteFontCandidate
    var sampleText: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.wantsLayer = true
        webView.layer?.isOpaque = false
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.underPageBackgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = previewHTML
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var previewHTML: String {
        let stylesheet = candidate.stylesheetHref.map { href in
            "<link rel=\"stylesheet\" href=\"\(escapeAttribute(href))\">"
        } ?? ""
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            \(stylesheet)
            <style>
              :root { color-scheme: light dark; }
              body {
                margin: 0;
                padding: 12px 14px;
                color: CanvasText;
                background: transparent;
                font-family: \(safeCSS(candidate.cssFamily.isEmpty ? "system-ui, sans-serif" : candidate.cssFamily));
              }
              .sample {
                font-size: 24px;
                line-height: 1.2;
                font-weight: 680;
                white-space: pre-wrap;
                overflow: hidden;
                display: -webkit-box;
                -webkit-box-orient: vertical;
                -webkit-line-clamp: 2;
              }
            </style>
          </head>
          <body>
            <div class="sample">\(escapeText(sampleText))</div>
          </body>
        </html>
        """
    }

    private func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func safeCSS(_ value: String) -> String {
        value.replacingOccurrences(of: "</", with: "<\\/")
    }

    /// 論理名（日本語）: 選択テキストプレビューコーディネータ
    /// 概要: 同一 HTML の再ロードを避けるため、最後に読み込んだ HTML を保持します。
    final class Coordinator {
        var lastHTML = ""
    }
}

/// 論理名（日本語）: OpenGraphite Webフォントプレビュー
/// 概要: stylesheet を読み込む小さな WKWebView でフォントの実表示を確認します。
///
/// プロパティ:
/// - `candidate`: プレビューするフォント候補。
/// - `sampleText`: 表示するサンプル文言。
private struct OpenGraphiteWebFontPreview: NSViewRepresentable {
    var candidate: OpenGraphiteFontCandidate
    var sampleText: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.wantsLayer = true
        webView.layer?.isOpaque = false
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.underPageBackgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = previewHTML
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var previewHTML: String {
        let stylesheet = candidate.stylesheetHref.map { href in
            "<link rel=\"stylesheet\" href=\"\(escapeAttribute(href))\">"
        } ?? ""
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            \(stylesheet)
            <style>
              :root { color-scheme: light dark; }
              body {
                margin: 0;
                padding: 18px;
                color: CanvasText;
                background: transparent;
                font-family: \(safeCSS(candidate.cssFamily.isEmpty ? "system-ui, sans-serif" : candidate.cssFamily));
              }
              .sample {
                font-size: 30px;
                line-height: 1.16;
                font-weight: 650;
                overflow-wrap: anywhere;
              }
              .meta {
                margin-top: 14px;
                font-size: 13px;
                line-height: 1.45;
                opacity: 0.72;
              }
            </style>
          </head>
          <body>
            <div class="sample">\(escapeText(sampleText))</div>
            <div class="meta">The quick brown fox jumps over the lazy dog. 1234567890</div>
          </body>
        </html>
        """
    }

    private func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func safeCSS(_ value: String) -> String {
        value.replacingOccurrences(of: "</", with: "<\\/")
    }

    /// 論理名（日本語）: Webフォントプレビューコーディネータ
    /// 概要: 同一 HTML の再ロードを避けるため、最後に読み込んだ HTML を保持します。
    final class Coordinator {
        var lastHTML = ""
    }
}
