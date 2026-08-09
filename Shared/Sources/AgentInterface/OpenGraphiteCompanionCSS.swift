import Foundation

/// 論理名（日本語）: Locale typography 宣言
/// 概要: page / component root に authored された標準 `font-family` 宣言と CSS source provenance を表します。
///
/// プロパティ:
/// - `locale`: default 宣言では `default`、locale override では正規化済み BCP 47 tag。
/// - `selector`: 宣言に対応する authored selector。
/// - `property`: 常に標準 CSS property の `font-family`。
/// - `value`: authored `font-family` value。
/// - `important`: `!important` の有無。
/// - `atRules`: 外側から内側の at-rule scope。
/// - `sourceOrder`: CSS source 内の declaration 順。
struct OpenGraphiteLocaleTypographyDeclaration: Codable, Equatable {
    var locale: String
    var selector: String
    var property: String
    var value: String
    var important: Bool
    var atRules: [OpenGraphiteCSSAtRuleContext]
    var sourceOrder: Int
}

/// 論理名（日本語）: Locale typography locale
/// 概要: default root 宣言と selector-safe な BCP 47 locale override を区別します。
enum OpenGraphiteLocaleTypographyLocale: Equatable {
    case `default`
    case locale(String)

    /// 論理名（日本語）: Locale typography locale 解析関数
    /// 処理概要: 省略値と `default` を root 宣言として扱い、BCP 47 tag を case-insensitive に検証・正規化します。
    ///
    /// - Parameter value: `default`、BCP 47 tag、または省略値。
    /// - Returns: 正規化した locale。selector に安全に埋め込めない値は `nil`。
    static func parse(_ value: String?) -> OpenGraphiteLocaleTypographyLocale? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("default") != .orderedSame else {
            return .default
        }

        let hyphenated = trimmed.replacingOccurrences(of: "_", with: "-")
        guard hyphenated.count <= 63 else { return nil }
        let subtags = hyphenated.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard !subtags.isEmpty,
              !subtags.contains(where: \String.isEmpty),
              subtags.allSatisfy({ subtag in
                  (1...8).contains(subtag.count) && subtag.allSatisfy { $0.isLetter || $0.isNumber }
              })
        else { return nil }

        let primary = subtags[0]
        let isPrivateOrGrandfathered = primary.caseInsensitiveCompare("x") == .orderedSame
            || primary.caseInsensitiveCompare("i") == .orderedSame
        guard isPrivateOrGrandfathered || (2...8).contains(primary.count) && primary.allSatisfy(\.isLetter) else {
            return nil
        }
        if isPrivateOrGrandfathered, subtags.count < 2 { return nil }

        var canonical: [String] = [primary.lowercased()]
        for subtag in subtags.dropFirst() {
            if subtag.count == 4, subtag.allSatisfy(\.isLetter) {
                canonical.append(subtag.prefix(1).uppercased() + subtag.dropFirst().lowercased())
            } else if subtag.count == 2, subtag.allSatisfy(\.isLetter) {
                canonical.append(subtag.uppercased())
            } else {
                canonical.append(subtag.lowercased())
            }
        }
        return .locale(canonical.joined(separator: "-"))
    }

    /// 論理名（日本語）: Locale typography locale 識別子
    /// 処理概要: JSON / UI へ返す `default` または正規化済み BCP 47 tag を返します。
    var identifier: String {
        switch self {
        case .default: return "default"
        case let .locale(identifier): return identifier
        }
    }

    /// 論理名（日本語）: Locale typography selector 生成関数
    /// 処理概要: root selector と標準 `:lang()` を組み合わせた selector-safe な書き込み先を返します。
    ///
    /// - Parameter rootSelector: page / component root selector。
    /// - Returns: default または locale override の selector。
    func selector(rootSelector: String) -> String {
        switch self {
        case .default:
            return rootSelector
        case let .locale(identifier):
            return #"\#(rootSelector):lang("\#(identifier)")"#
        }
    }
}

/// 論理名（日本語）: OpenGraphite Companion CSS 文書
/// 概要: HTML と同名の CSS ファイルを node 単位の design value 正本として読み書きします。
///
/// プロパティ:
/// - `css`: companion CSS の全文。
struct OpenGraphiteCompanionCSSDocument: Equatable {
    var css: String

    /// 論理名（日本語）: Companion CSS URL生成関数
    /// 処理概要: HTML URL と同じ場所・同じ basename の `.css` URL を返します。
    ///
    /// - Parameter htmlURL: 対応する HTML URL。
    /// - Returns: companion CSS URL。
    static func companionURL(forHTMLURL htmlURL: URL) -> URL {
        htmlURL.deletingPathExtension().appendingPathExtension("css")
    }

    /// 論理名（日本語）: Companion CSS読込関数
    /// 処理概要: companion CSS が存在すれば読み込み、存在しない場合は空文書を返します。
    ///
    /// - Parameter htmlURL: 対応する HTML URL。
    /// - Returns: companion CSS 文書。
    static func read(forHTMLURL htmlURL: URL) throws -> OpenGraphiteCompanionCSSDocument {
        let cssURL = companionURL(forHTMLURL: htmlURL)
        guard FileManager.default.fileExists(atPath: cssURL.path) else {
            return OpenGraphiteCompanionCSSDocument(css: "")
        }
        return OpenGraphiteCompanionCSSDocument(css: try String(contentsOf: cssURL, encoding: .utf8))
    }

    /// 論理名（日本語）: Companion CSS既存読込関数
    /// 処理概要: companion CSS が存在する場合だけ文書を返します。
    ///
    /// - Parameter htmlURL: 対応する HTML URL。
    /// - Returns: companion CSS 文書。存在しない場合は `nil`。
    static func existing(forHTMLURL htmlURL: URL) throws -> OpenGraphiteCompanionCSSDocument? {
        let cssURL = companionURL(forHTMLURL: htmlURL)
        guard FileManager.default.fileExists(atPath: cssURL.path) else { return nil }
        return OpenGraphiteCompanionCSSDocument(css: try String(contentsOf: cssURL, encoding: .utf8))
    }

    /// 論理名（日本語）: Companion CSS保存関数
    /// 処理概要: 対応する companion CSS URL へ文書を書き込みます。
    ///
    /// - Parameter htmlURL: 対応する HTML URL。
    func write(forHTMLURL htmlURL: URL) throws {
        let cssURL = Self.companionURL(forHTMLURL: htmlURL)
        try FileManager.default.createDirectory(at: cssURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try css.write(to: cssURL, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: デザイントークン抽出関数
    /// 処理概要: Project CSS の `:root` rule に保存された CSS custom property を design token として抽出します。
    ///
    /// - Parameter contract: design token の selector と名前規則を定義する OpenGraphite 契約。
    /// - Returns: cascade 順に解決した design token 一覧。
    func designTokens(contract: OpenGraphiteContract = .builtIn) -> [OpenGraphiteDesignToken] {
        let rootSelector = contract.designTokens.selector
        var order: [String] = []
        var values: [String: String] = [:]

        for rule in Self.rules(in: css) where Self.selector(rule.selector, containsExactSelector: rootSelector) {
            let style = OpenGraphiteCSSStyle.parse(rule.body)
            for declaration in style.declarations where declaration.name.hasPrefix("--") {
                guard contract.isValidDesignTokenName(declaration.name) else { continue }
                if values[declaration.name] != nil {
                    order.removeAll { $0 == declaration.name }
                }
                order.append(declaration.name)
                values[declaration.name] = declaration.value
            }
        }

        return order.compactMap { name in
            guard let value = values[name] else { return nil }
            return OpenGraphiteDesignToken(
                name: name,
                value: value,
                category: Self.designTokenCategory(for: name),
                reference: "var(\(name))"
            )
        }
    }

    /// 論理名（日本語）: デザイントークン設定関数
    /// 処理概要: Project CSS の `:root` rule に CSS custom property を設定し、空値なら削除します。
    ///
    /// - Parameters:
    ///   - name: 更新する design token 名。
    ///   - value: CSS 値。空の場合は削除。
    ///   - contract: design token の selector と名前規則を定義する OpenGraphite 契約。
    mutating func setDesignToken(
        _ name: String,
        value: String,
        contract: OpenGraphiteContract = .builtIn
    ) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard contract.isValidDesignTokenName(normalizedName) else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootSelector = contract.designTokens.selector
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        let root = OpenGraphiteCSSDOMElement(tagName: "html", isRoot: true)
        let trace = sourceDocument.cascadeTrace(for: root)
        let provenance = trace.winners[normalizedName].flatMap { winner in
            winner.authoredProperty == normalizedName ? winner : nil
        }
        css = sourceDocument.setting(
            property: normalizedName,
            value: normalizedValue,
            provenance: provenance,
            fallbackSelector: rootSelector
        )
    }

    /// 論理名（日本語）: Locale typography 一覧関数
    /// 処理概要: root selector と同じ scope の標準 `font-family` / `:lang()` 宣言を lossless CSS source index から返します。
    ///
    /// - Parameter rootSelector: page / component root selector。
    /// - Returns: authored selector、at-rule scope、`!important`、source order を保持した宣言一覧。
    func localeTypography(rootSelector: String) -> [OpenGraphiteLocaleTypographyDeclaration] {
        let normalizedRoot = rootSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRoot.isEmpty else { return [] }
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        return localeTypographyProvenance(
            in: sourceDocument,
            rootSelector: normalizedRoot
        ).map { item in
            OpenGraphiteLocaleTypographyDeclaration(
                locale: item.locale.identifier,
                selector: item.provenance.selector,
                property: "font-family",
                value: item.provenance.declaration.value,
                important: item.provenance.declaration.important,
                atRules: item.provenance.atRules,
                sourceOrder: item.provenance.declaration.sourceOrder
            )
        }
    }

    /// 論理名（日本語）: Locale typography root selector 解決関数
    /// 処理概要: DOM root に一致する既存 `font-family` selector を優先し、新規文書だけ caller の fallback selector を使います。
    ///
    /// - Parameters:
    ///   - element: page / component root の標準 DOM 情報。
    ///   - fallbackSelector: 既存 selector がない場合だけ使う安全な selector。
    /// - Returns: locale override からは `:lang()` suffix を外した root selector。
    func localeTypographyRootSelector(
        for element: OpenGraphiteCSSDOMElement,
        fallbackSelector: String
    ) -> String {
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        let matching = sourceDocument.rules.flatMap { rule in
            rule.selectors.flatMap { selector -> [(selector: String, localeScoped: Bool, atRules: [OpenGraphiteCSSAtRuleContext], declaration: OpenGraphiteCSSSourceDeclaration)] in
                let selectorParts = Self.localeTypographySelectorParts(selector)
                let baseSelector = selectorParts?.rootSelector ?? selector
                guard OpenGraphiteCSSSelector.matches(baseSelector, element: element),
                      rule.declarations.contains(where: { $0.name == "font-family" })
                else { return [] }
                return rule.declarations.compactMap { declaration in
                    guard declaration.name == "font-family" else { return nil }
                    return (baseSelector, selectorParts != nil, rule.atRules, declaration)
                }
            }
        }
        let preferred = [
            matching.filter { !$0.localeScoped && $0.atRules.isEmpty },
            matching.filter { !$0.localeScoped },
            matching.filter { $0.atRules.isEmpty },
            matching
        ].first(where: { !$0.isEmpty }) ?? []
        if let winner = preferred.max(by: { lhs, rhs in
            if lhs.declaration.important != rhs.declaration.important {
                return !lhs.declaration.important && rhs.declaration.important
            }
            let lhsSpecificity = OpenGraphiteCSSSelector.specificity(of: lhs.selector)
            let rhsSpecificity = OpenGraphiteCSSSelector.specificity(of: rhs.selector)
            if lhsSpecificity != rhsSpecificity { return lhsSpecificity < rhsSpecificity }
            return lhs.declaration.sourceOrder < rhs.declaration.sourceOrder
        }) {
            return winner.selector
        }
        return fallbackSelector.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: Locale typography 設定関数
    /// 処理概要: 既存 declaration provenance があれば value range だけを更新し、空値なら対象 declaration だけを削除します。
    ///
    /// - Parameters:
    ///   - locale: 省略 / `default` または任意の妥当な BCP 47 tag。
    ///   - fontFamily: 標準 `font-family` value。空の場合は削除。
    ///   - rootSelector: 既存 provenance がない場合だけ使う root selector。
    /// - Returns: locale が妥当な場合は正規化値、selector、更新後宣言。無効な locale は `nil`。
    mutating func setLocaleTypography(
        locale: String?,
        fontFamily: String,
        rootSelector: String
    ) -> (locale: String, selector: String, declaration: OpenGraphiteLocaleTypographyDeclaration?)? {
        guard let parsedLocale = OpenGraphiteLocaleTypographyLocale.parse(locale) else { return nil }
        let normalizedRoot = rootSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRoot.isEmpty else { return nil }
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        let authoredProvenance = localeTypographyProvenance(
            in: sourceDocument,
            rootSelector: normalizedRoot
        )
        let candidates = authoredProvenance.filter { $0.locale == parsedLocale }.map(\.provenance)
        let provenance = candidates.max(by: Self.precedes)
        let defaultProvenance = authoredProvenance.filter { $0.locale == .default }.map(\.provenance)
        let fallbackScope = defaultProvenance
            .filter(\.atRules.isEmpty)
            .max(by: Self.precedes)
            ?? defaultProvenance.max(by: Self.precedes)
            ?? authoredProvenance.map(\.provenance).max(by: Self.precedes)
        let selector = provenance?.selector ?? parsedLocale.selector(rootSelector: normalizedRoot)
        css = sourceDocument.setting(
            property: "font-family",
            value: fontFamily,
            provenance: provenance,
            fallbackSelector: selector,
            fallbackScope: fallbackScope
        )
        let updatedProvenance = localeTypographyProvenance(
            in: OpenGraphiteCSSSourceDocument.parse(css),
            rootSelector: normalizedRoot
        )
            .filter { $0.locale == parsedLocale }
            .map(\.provenance)
            .max(by: Self.precedes)
        let declaration = updatedProvenance.map {
            OpenGraphiteLocaleTypographyDeclaration(
                locale: parsedLocale.identifier,
                selector: $0.selector,
                property: "font-family",
                value: $0.declaration.value,
                important: $0.declaration.important,
                atRules: $0.atRules,
                sourceOrder: $0.declaration.sourceOrder
            )
        }
        return (parsedLocale.identifier, selector, declaration)
    }

    /// 論理名（日本語）: Locale typography provenance 走査関数
    /// 処理概要: root selector および同じ root selector の `:lang()` rule にある `font-family` 宣言を抽出します。
    private func localeTypographyProvenance(
        in sourceDocument: OpenGraphiteCSSSourceDocument,
        rootSelector: String
    ) -> [(locale: OpenGraphiteLocaleTypographyLocale, provenance: OpenGraphiteCSSDeclarationProvenance)] {
        sourceDocument.rules.flatMap { rule in
            rule.selectors.flatMap { selector -> [(OpenGraphiteLocaleTypographyLocale, OpenGraphiteCSSDeclarationProvenance)] in
                let locale: OpenGraphiteLocaleTypographyLocale
                if selector.trimmingCharacters(in: .whitespacesAndNewlines) == rootSelector {
                    locale = .default
                } else if let parts = Self.localeTypographySelectorParts(selector),
                          parts.rootSelector == rootSelector,
                          let parsed = OpenGraphiteLocaleTypographyLocale.parse(parts.locale) {
                    locale = parsed
                } else {
                    return []
                }
                let specificity = OpenGraphiteCSSSelector.specificity(of: selector)
                return rule.declarations.compactMap { declaration in
                    guard declaration.name == "font-family" else { return nil }
                    return (
                        locale,
                        OpenGraphiteCSSDeclarationProvenance(
                            property: "font-family",
                            authoredProperty: "font-family",
                            selector: selector,
                            specificity: specificity,
                            atRules: rule.atRules,
                            declaration: declaration
                        )
                    )
                }
            }
        }
    }

    /// 論理名（日本語）: Locale typography selector 分解関数
    /// 処理概要: selector 末尾の標準 `:lang()` から root selector と locale tag を復元します。
    private static func localeTypographySelectorParts(_ selector: String) -> (rootSelector: String, locale: String)? {
        let pattern = #"(?is)^(.*?)\s*:\s*lang\s*\(\s*(?:\"([^\"]+)\"|'([^']+)'|([^\)\s]+))\s*\)\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: selector,
                  range: NSRange(selector.startIndex..<selector.endIndex, in: selector)
              ),
              let rootRange = Range(match.range(at: 1), in: selector)
        else { return nil }
        let locale = [2, 3, 4].compactMap { index -> String? in
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: selector)
            else { return nil }
            return String(selector[range])
        }.first ?? ""
        let rootSelector = String(selector[rootRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootSelector.isEmpty, !locale.isEmpty else { return nil }
        return (rootSelector, locale)
    }

    /// 論理名（日本語）: CSS provenance 優先順位比較関数
    /// 処理概要: `!important`、specificity、source order の標準 cascade 順で候補を比較します。
    private static func precedes(
        _ lhs: OpenGraphiteCSSDeclarationProvenance,
        _ rhs: OpenGraphiteCSSDeclarationProvenance
    ) -> Bool {
        if lhs.declaration.important != rhs.declaration.important {
            return !lhs.declaration.important && rhs.declaration.important
        }
        if lhs.specificity != rhs.specificity { return lhs.specificity < rhs.specificity }
        return lhs.declaration.sourceOrder < rhs.declaration.sourceOrder
    }

    /// 論理名（日本語）: Node CSS宣言抽出関数
    /// 処理概要: `data-og-internal-id` selector に保存された編集対象 CSS 宣言を cascade 順に辞書化します。
    ///
    /// - Parameter internalID: 対象 node の `data-og-internal-id`。
    ///   - contract: 抽出対象の CSS 宣言を定義する OpenGraphite 契約。
    /// - Returns: 対象 node の CSS 宣言。
    func cssVariables(
        forNodeInternalID internalID: String,
        contract: OpenGraphiteContract = .builtIn
    ) -> [String: String] {
        let normalizedID = internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return [:] }
        return cssVariables(
            for: OpenGraphiteCSSDOMElement(
                tagName: "*",
                attributes: ["data-og-internal-id": normalizedID]
            ),
            contract: contract
        )
    }

    /// 論理名（日本語）: DOM要素CSS宣言抽出関数
    /// 処理概要: 任意の authored selector と標準 cascade を評価し、編集契約に含まれる source value を返します。
    ///
    /// - Parameters:
    ///   - element: selector 照合対象の標準 DOM 情報。
    ///   - inheritedValues: 親から継承した resolved value。
    ///   - environment: active media condition。
    ///   - contract: 抽出対象 CSS declaration の契約。
    /// - Returns: cascade winner の authored value。
    func cssVariables(
        for element: OpenGraphiteCSSDOMElement,
        inheritedValues: [String: String] = [:],
        environment: OpenGraphiteCSSCascadeEnvironment = .base,
        contract: OpenGraphiteContract = .builtIn
    ) -> [String: String] {
        cascadeTrace(
            for: element,
            inheritedValues: inheritedValues,
            environment: environment
        ).authoredValues.filter { contract.isKnownCSSVariable($0.key) }
    }

    /// 論理名（日本語）: DOM要素CSS cascade trace生成関数
    /// 処理概要: CSS source AST を使い、computed style と分離された declaration provenance を返します。
    ///
    /// - Parameters:
    ///   - element: selector 照合対象の標準 DOM 情報。
    ///   - inheritedValues: 親から継承した resolved value。
    ///   - environment: active media condition。
    /// - Returns: candidate、winner、authored/resolved value を含む trace。
    func cascadeTrace(
        for element: OpenGraphiteCSSDOMElement,
        inheritedValues: [String: String] = [:],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> OpenGraphiteCSSCascadeTrace {
        OpenGraphiteCSSSourceDocument.parse(css).cascadeTrace(
            for: element,
            inheritedValues: inheritedValues,
            environment: environment
        )
    }

    /// 論理名（日本語）: Node CSS宣言設定関数
    /// 処理概要: `data-og-internal-id` selector の rule に CSS 宣言を設定し、空値なら削除します。
    ///
    /// - Parameters:
    ///   - name: 更新する CSS property または custom property 名。
    ///   - value: CSS 値。空の場合は削除。
    ///   - internalID: 対象 node の `data-og-internal-id`。
    mutating func setCSSVariable(_ name: String, value: String, forNodeInternalID internalID: String) {
        let normalizedID = internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        let element = OpenGraphiteCSSDOMElement(
            tagName: "*",
            attributes: ["data-og-internal-id": normalizedID]
        )
        let winner = sourceDocument.cascadeTrace(for: element).winners[name]
        let provenance = winner.flatMap { $0.authoredProperty == name ? $0 : nil }
        css = sourceDocument.setting(
            property: name,
            value: normalizedValue,
            provenance: provenance,
            fallbackSelector: Self.selector(forInternalID: normalizedID)
        )
    }

    /// 論理名（日本語）: 実DOM要素CSS宣言設定関数
    /// 処理概要: 実描画要素のcascade winnerを最小差分で更新し、未定義時だけ安全なfallback selectorへ追記します。
    ///
    /// - Parameters:
    ///   - name: 更新する標準CSS property。
    ///   - value: CSS値。空の場合はwinner declarationを削除。
    ///   - element: authored selectorを照合する実DOM要素。
    ///   - fallbackSelector: source provenanceがない場合の保存先selector。
    ///   - activeMediaQueries: 実描画環境でactiveなauthored `@media` 条件。
    mutating func setCSSProperty(
        _ name: String,
        value: String,
        for element: OpenGraphiteCSSDOMElement,
        fallbackSelector: String,
        activeMediaQueries: [String] = []
    ) {
        let sourceDocument = OpenGraphiteCSSSourceDocument.parse(css)
        let trace = sourceDocument.cascadeTrace(
            for: element,
            environment: .inspection(activeMediaQueries: activeMediaQueries)
        )
        let winner = trace.winners[name]
        let provenance = winner.flatMap { $0.authoredProperty == name ? $0 : nil }
        css = sourceDocument.setting(
            property: name,
            value: value,
            provenance: provenance,
            fallbackSelector: fallbackSelector,
            fallbackScope: winner
        )
    }

    /// 論理名（日本語）: CSS rule追加関数
    /// 処理概要: 文書末尾へ node selector rule を追加します。
    private mutating func appendRule(selector: String, declarations: [OpenGraphiteCSSDeclaration]) {
        let prefix: String
        if css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prefix = ""
        } else if css.hasSuffix("\n\n") {
            prefix = ""
        } else if css.hasSuffix("\n") {
            prefix = "\n"
        } else {
            prefix = "\n\n"
        }
        css += "\(prefix)\(selector) {\n\(Self.serializedDeclarations(declarations))}\n"
    }

    /// 論理名（日本語）: CSS宣言直列化関数
    /// 処理概要: CSS rule body 用に宣言をインデント付きで直列化します。
    private static func serializedDeclarations(_ declarations: [OpenGraphiteCSSDeclaration]) -> String {
        declarations.map { "  \($0.name): \($0.value);\n" }.joined()
    }

    /// 論理名（日本語）: Node selector生成関数
    /// 処理概要: `data-og-internal-id` 用の属性 selector を生成します。
    private static func selector(forInternalID internalID: String) -> String {
        #"[data-og-internal-id="\#(internalID.replacingOccurrences(of: "\"", with: "\\\""))"]"#
    }

    /// 論理名（日本語）: Node selector一致判定関数
    /// 処理概要: selector list に対象 `data-og-internal-id` selector が含まれるか判定します。
    private static func selector(_ selector: String, matchesInternalID internalID: String) -> Bool {
        let expectedDouble = #"[data-og-internal-id="\#(internalID)"]"#
        let expectedSingle = #"[data-og-internal-id='\#(internalID)']"#
        return selector
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { $0 == expectedDouble || $0 == expectedSingle }
    }

    /// 論理名（日本語）: CSS selector含有判定関数
    /// 処理概要: selector list に指定 selector が完全一致で含まれるか判定します。
    private static func selector(_ selector: String, containsExactSelector expected: String) -> Bool {
        selector
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(expected)
    }

    /// 論理名（日本語）: デザイントークン分類生成関数
    /// 処理概要: `--color-primary` なら `color` のように名前の先頭 segment を分類名にします。
    private static func designTokenCategory(for name: String) -> String {
        let tokenBody = name.dropFirst(2)
        let category = tokenBody.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        return category.isEmpty ? "token" : category
    }

    /// 論理名（日本語）: CSS rule走査関数
    /// 処理概要: top-level CSS rule の selector と body 範囲を返します。
    private static func rules(in css: String) -> [OpenGraphiteCompanionCSSRule] {
        var rules: [OpenGraphiteCompanionCSSRule] = []
        var index = css.startIndex
        var ruleStart = css.startIndex
        while index < css.endIndex {
            guard let open = nextTopLevelOpenBrace(in: css, startingAt: index) else { break }
            let selector = String(css[ruleStart..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let close = matchingCloseBrace(in: css, openingAt: open) else { break }
            let bodyStart = css.index(after: open)
            let body = String(css[bodyStart..<close])
            let afterClose = css.index(after: close)
            if !selector.hasPrefix("@") {
                rules.append(
                    OpenGraphiteCompanionCSSRule(
                        selector: selector,
                        body: body,
                        range: ruleStart..<afterClose,
                        bodyRange: bodyStart..<close
                    )
                )
            }
            index = afterClose
            ruleStart = afterClose
        }
        return rules
    }

    /// 論理名（日本語）: Top-level開始brace検索関数
    /// 処理概要: quote / comment の内側を避けて次の `{` を探します。
    private static func nextTopLevelOpenBrace(in css: String, startingAt start: String.Index) -> String.Index? {
        var index = start
        var quote: Character?
        var inComment = false
        while index < css.endIndex {
            let character = css[index]
            let next = css.index(after: index)
            if inComment {
                if character == "*", next < css.endIndex, css[next] == "/" {
                    inComment = false
                    index = css.index(after: next)
                    continue
                }
                index = next
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    index = next < css.endIndex ? css.index(after: next) : next
                    continue
                }
                if character == activeQuote {
                    quote = nil
                }
                index = next
                continue
            }
            if character == "/", next < css.endIndex, css[next] == "*" {
                inComment = true
                index = css.index(after: next)
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                index = next
                continue
            }
            if character == "{" {
                return index
            }
            index = next
        }
        return nil
    }

    /// 論理名（日本語）: 対応終了brace検索関数
    /// 処理概要: quote / comment / nested block を考慮して対応する `}` を探します。
    private static func matchingCloseBrace(in css: String, openingAt open: String.Index) -> String.Index? {
        var index = css.index(after: open)
        var depth = 1
        var quote: Character?
        var inComment = false
        while index < css.endIndex {
            let character = css[index]
            let next = css.index(after: index)
            if inComment {
                if character == "*", next < css.endIndex, css[next] == "/" {
                    inComment = false
                    index = css.index(after: next)
                    continue
                }
                index = next
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    index = next < css.endIndex ? css.index(after: next) : next
                    continue
                }
                if character == activeQuote {
                    quote = nil
                }
                index = next
                continue
            }
            if character == "/", next < css.endIndex, css[next] == "*" {
                inComment = true
                index = css.index(after: next)
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                index = next
                continue
            }
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = next
        }
        return nil
    }
}

/// 論理名（日本語）: OpenGraphite Companion CSS rule
/// 概要: top-level CSS rule の selector、body、置換範囲を表します。
private struct OpenGraphiteCompanionCSSRule {
    var selector: String
    var body: String
    var range: Range<String.Index>
    var bodyRange: Range<String.Index>
}
