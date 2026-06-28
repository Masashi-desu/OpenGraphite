import Foundation

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
        let rules = Self.rules(in: css)

        guard let matchingIndex = rules.lastIndex(where: { Self.selector($0.selector, containsExactSelector: rootSelector) }) else {
            guard !normalizedValue.isEmpty else { return }
            appendRule(
                selector: rootSelector,
                declarations: [OpenGraphiteCSSDeclaration(name: normalizedName, value: normalizedValue)]
            )
            return
        }

        let rule = rules[matchingIndex]
        var style = OpenGraphiteCSSStyle.parse(rule.body)
        style.set(normalizedName, value: normalizedValue)
        if style.declarations.isEmpty {
            css.replaceSubrange(rule.range, with: "")
        } else {
            css.replaceSubrange(rule.bodyRange, with: "\n\(Self.serializedDeclarations(style.declarations))")
        }
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
        var result: [String: String] = [:]
        for rule in Self.rules(in: css) where Self.selector(rule.selector, matchesInternalID: normalizedID) {
            let style = OpenGraphiteCSSStyle.parse(rule.body)
            for (key, value) in style.openGraphiteDeclarations(contract: contract) {
                result[key] = value
            }
        }
        return result
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
        let rules = Self.rules(in: css)
        guard let matchingIndex = rules.lastIndex(where: { Self.selector($0.selector, matchesInternalID: normalizedID) }) else {
            guard !normalizedValue.isEmpty else { return }
            appendRule(selector: Self.selector(forInternalID: normalizedID), declarations: [OpenGraphiteCSSDeclaration(name: name, value: normalizedValue)])
            return
        }

        let rule = rules[matchingIndex]
        var style = OpenGraphiteCSSStyle.parse(rule.body)
        style.set(name, value: normalizedValue)
        if style.declarations.isEmpty {
            css.replaceSubrange(rule.range, with: "")
        } else {
            css.replaceSubrange(rule.bodyRange, with: "\n\(Self.serializedDeclarations(style.declarations))")
        }
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
