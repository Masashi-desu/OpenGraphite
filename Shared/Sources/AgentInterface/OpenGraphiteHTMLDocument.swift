import Foundation

/// 論理名（日本語）: Legacy HTML Web契約移行結果
/// 概要: 開始tagの対象attribute rangeだけを変更したcandidateとproject-wide collision判定情報を保持します。
struct OpenGraphiteLegacyHTMLMigrationResult: Equatable {
    var source: String
    var detectedLegacy: Bool
    var types: Set<String>
    var layouts: Set<String>
    var generatedClassNames: Set<String>
    var existingClassNames: Set<String>
    var removedLegacyDatasetAttributeNames: Set<String>
    var generatedDestinationAttributes: Set<String>
    var observedDestinationAttributes: Set<String>
    var hasWholeDatasetRuntimeObserver: Bool
    var hasGeneratedClassObserver: Bool
    var hasGeneratedCustomPropertyStyleObserver: Bool
    var hasGeneratedCustomPropertyRuntimeObserver: Bool
    var hasWholeStyleRuntimeObserver: Bool
    var hasInlineStyleMutation: Bool
    var hasHTMLSourceMutation: Bool
    var hasHTMLAttributeMutation: Bool
    var hasEmbeddedStyleMutation: Bool
    var hasWholeAttributeRuntimeObserver: Bool
    var hasWholeMarkupRuntimeObserver: Bool
    var hasCSSOMRuntimeObserver: Bool
    var hasStyleTextRuntimeObserver: Bool
    var hasPreviewContextRuntimeObserver: Bool
    var observedPreviewHostFields: Set<String>
    var hasDynamicSelectorRuntimeObserver: Bool
    var hasAttributeNodeRuntimeObserver: Bool
    var authoredCustomPropertyNames: Set<String>
    var generatedCustomPropertyNames: Set<String>
    var hasUnsupportedRuntimeDependency: Bool
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ECMAScript字句境界
/// 概要: JavaScript source scanner間でline commentとregular-expression literalの境界判定を共有します。
enum OpenGraphiteJavaScriptLexical {
    /// 論理名（日本語）: Line comment終端解決関数
    /// 処理概要: `//` comment本文の開始位置からCR・LF・LS・PSまたはEOFまでを返します。
    ///
    /// - Parameters:
    ///   - source: 検査対象のECMAScript source。
    ///   - start: Line comment本文の開始位置。
    /// - Returns: 最初のline terminator、またはsource終端のindex。
    static func lineCommentEnd(in source: String, from start: String.Index) -> String.Index {
        source[start...].firstIndex(where: isLineTerminator) ?? source.endIndex
    }

    /// 論理名（日本語）: 正規表現literal終端解決関数
    /// 処理概要: code位置のslashから始まるliteralをcharacter classとescapeを保って走査します。
    ///
    /// - Parameters:
    ///   - source: 検査対象のECMAScript source。
    ///   - start: Slash tokenの開始位置。
    /// - Returns: Literal終了直後のindex。完全なliteralでない場合は`nil`。
    static func regularExpressionEnd(in source: String, from start: String.Index) -> String.Index? {
        guard source[start] == "/" else { return nil }
        var cursor = source.index(after: start)
        guard cursor < source.endIndex, source[cursor] != "/", source[cursor] != "*" else { return nil }
        var inCharacterClass = false
        while cursor < source.endIndex {
            let character = source[cursor]
            if isLineTerminator(character) { return nil }
            if character == "\\" {
                cursor = source.index(after: cursor)
                guard cursor < source.endIndex else { return nil }
                cursor = source.index(after: cursor)
                continue
            }
            if character == "[" {
                inCharacterClass = true
            } else if character == "]" {
                inCharacterClass = false
            } else if character == "/", !inCharacterClass {
                cursor = source.index(after: cursor)
                while cursor < source.endIndex,
                      source[cursor].isLetter || source[cursor].isNumber
                        || source[cursor] == "_" || source[cursor] == "$" {
                    cursor = source.index(after: cursor)
                }
                return cursor
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    /// 論理名（日本語）: 正規表現literal開始判定関数
    /// 処理概要: 直前tokenからslashをdivisionではなくregular-expression literal開始として扱えるかを判定します。
    ///
    /// - Parameter token: Slash直前のsemantic token。先頭の場合は`nil`。
    /// - Returns: Regular-expression literalを開始できる場合は`true`。
    static func canStartRegularExpression(afterToken token: String?) -> Bool {
        guard let token else { return true }
        return ["(", "[", "{", "=", ":", ",", ";", "!", "?", "&", "|", "+", "-", "*", "%", "^", "~", "<", ">", "=>", "return", "throw", "case", "delete", "void", "typeof", "yield", "await"].contains(token)
    }

    /// ECMAScriptのline terminator code pointだけで構成されるCharacterかを返します。
    private static func isLineTerminator(_ character: Character) -> Bool {
        !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x000A
                || scalar.value == 0x000D
                || scalar.value == 0x2028
                || scalar.value == 0x2029
        }
    }
}

/// 論理名（日本語）: Legacy JavaScript observer検査器
/// 概要: commentを除外したJavaScript sourceからdeprecated readerとmigration destination observerを保守的に検出します。
enum OpenGraphiteLegacyJavaScriptInspector {
    private static let generatedDestinationAttributeNames = ["hidden", "variant", "part"]
    private static let datasetPropertyNames = [
        "ogType", "ogLayout", "ogHidden", "ogIconMask", "ogVariant", "ogSlot", "ogPart",
        "ogStateHidden", "ogStateVisible", "ogPlacementMode", "ogComponentKind", "ogRole",
        "ogSelected", "ogEditing", "ogDragging", "ogPreviewLocale", "ogPreviewDir"
    ]

    /// 論理名（日本語）: Deprecated runtime reader検出関数
    /// 処理概要: raw legacy名と`dataset.og*`のdot/optional/bracket accessをexact catalogで検出します。
    static func containsLegacyReader(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let denylistedTokens = [
            "codeViewerMode", "placementMode", "--og-", "data-og-type", "data-og-layout",
            "data-og-hidden", "data-og-icon-mask", "data-og-variant", "data-og-slot",
            "data-og-part", "data-og-component-kind", "data-og-role", "data-og-state-hidden",
            "data-og-state-visible", "data-og-placement-mode", "data-og-selected",
            "data-og-editing", "data-og-dragging", "data-og-preview-locale", "data-og-preview-dir"
        ]
        if denylistedTokens.contains(where: { semanticSource.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        let alternatives = datasetPropertyNames.joined(separator: "|")
        let patterns = [
            #"\bdataset\s*(?:\?\.|\.)\s*(?:"# + alternatives + #")\b"#,
            #"\bdataset\s*(?:\?\.)?\s*\[\s*["'](?:"# + alternatives + #")["']\s*\]"#,
            #"\bdataset\s*(?:\?\.)?\s*\[\s*(?:"# + alternatives + #")\s*\]"#
        ]
        return patterns.contains { pattern in
            semanticSource.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// 論理名（日本語）: Generated class observer検出関数
    /// 処理概要: reserved class namespace、class列全体、class attribute selectorを観測するJavaScriptを検出します。
    static func containsGeneratedClassObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        if semanticSource.contains("og-migrated-v1-") { return true }
        let patterns = [
            #"(?:\?\.|\.)\s*className\b"#,
            #"(?:\?\.|\.)\s*classList\b"#,
            #"\[\s*["'](?:className|classList)["']\s*\]"#,
            #"\{[^{}\n;]*\b(?:className|classList)\b[^{}\n;]*\}\s*="#,
            #"\b(?:get|has|set|remove|toggle)Attribute\s*\(\s*["']class["'](?:\s*[,\)])"#,
            #"\[\s*["'](?:get|has|set|remove|toggle)Attribute["']\s*\]\s*(?:\?\.)?\s*\(\s*["']class["'](?:\s*[,\)])"#,
            #"\[\s*class(?:\s|\]|[~|^$*]?=)"#
        ]
        return patterns.contains { pattern in
            semanticSource.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        } || hasAliasedLiteralAttributeObserver(in: semanticSource, attributeName: "class")
            || hasBorrowedLiteralAttributeObserver(in: semanticSource, attributeName: "class")
    }

    /// 論理名（日本語）: Generated destination attribute observer索引関数
    /// 処理概要: property/bracket access、attribute accessor/mutator、selector文字列が観測する`hidden`/`variant`/`part`を返します。
    static func observedGeneratedDestinationAttributes(_ source: String) -> Set<String> {
        let semanticSource = commentStrippedSource(source)
        var observed: Set<String> = []
        for name in generatedDestinationAttributeNames {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"(?:\?\.|\.)\s*"# + escapedName + #"\b"#,
                #"\[\s*["']"# + escapedName + #"["']\s*\]"#,
                #"\{[^{}\n;]*\b"# + escapedName + #"\b[^{}\n;]*\}\s*="#,
                #"\b(?:get|has|set|remove|toggle)Attribute\s*\(\s*["']"#
                    + escapedName + #"["'](?:\s*[,\)])"#,
                #"\[\s*["'](?:get|has|set|remove|toggle)Attribute["']\s*\]\s*(?:\?\.)?\s*\(\s*["']"#
                    + escapedName + #"["'](?:\s*[,\)])"#,
                #"\[\s*"# + escapedName + #"(?:\s|\]|[~|^$*]?=)"#
            ]
            if patterns.contains(where: {
                semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
            }) {
                observed.insert(name)
            }
            if hasAliasedLiteralAttributeObserver(in: semanticSource, attributeName: name) {
                observed.insert(name)
            }
            if hasBorrowedLiteralAttributeObserver(in: semanticSource, attributeName: name) {
                observed.insert(name)
            }
        }
        return observed
    }

    /// 論理名（日本語）: Dataset whole-column observer検出関数
    /// 処理概要: property/bracket accessとdestructuringによって`dataset`列を取得するruntime sourceを保守的に検出します。
    static func hasWholeDatasetObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"(?:\?\.|\.)\s*dataset\b"#,
            #"\[\s*["']dataset["']\s*\]"#,
            #"\{[^{}\n;]*\bdataset\b[^{}\n;]*\}\s*="#
        ]
        return patterns.contains {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// 論理名（日本語）: Style whole-column observer検出関数
    /// 処理概要: property/bracket accessとdestructuringによって`style`列を取得するruntime sourceを保守的に検出します。
    static func hasWholeStyleObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"(?:\?\.|\.)\s*style\b"#,
            #"\[\s*["']style["']\s*\]"#,
            #"\{[^{}\n;]*\bstyle\b[^{}\n;]*\}\s*="#,
            #"\b(?:get|has|set|remove|toggle)Attribute\s*\(\s*["']style["'](?:\s*[,\)])"#
        ]
        return patterns.contains {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// 論理名（日本語）: HTML attribute whole-column observer検出関数
    /// 処理概要: attribute列の列挙・存在確認と、名前を静的に確定できないaccessor/mutatorを保守的に検出します。
    static func hasWholeAttributeObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"(?:\?\.|\.)\s*attributes\b"#,
            #"\[\s*[\"']attributes[\"']\s*\]"#,
            #"\{[^{}\n;]*\battributes\b[^{}\n;]*\}\s*="#,
            #"\b(?:getAttributeNames|hasAttributes)\s*(?:\?\.)?\s*\("#,
            #"\b(?:(?:get|has|set|remove)Attribute(?:NS)?|toggleAttribute)\s*(?:\?\.)?\s*\(\s*(?![\"'])"#,
            #"\[\s*[\"'](?:(?:get|has|set|remove)Attribute(?:NS)?|toggleAttribute)[\"']\s*\]\s*\(\s*(?![\"'])"#,
            #"\b(?:(?:get|has|set|remove)Attribute(?:NS)?|toggleAttribute)\s*\.\s*call\s*\([^,]+,(?!\s*[\"'][^\"'\r\n]*[\"']\s*(?:,|\)))"#,
            #"\b(?:(?:get|has|set|remove)Attribute(?:NS)?|toggleAttribute)\s*\.\s*apply\s*\([^,]+,(?!\s*\[\s*[\"'][^\"'\r\n]*[\"']\s*(?:,|\]))"#
        ]
        if patterns.contains(where: {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            return true
        }
        for receiver in domReceiverNames(in: semanticSource) {
            let escaped = NSRegularExpression.escapedPattern(for: receiver)
            let computed = #"\b"# + escaped + #"\s*(?:\?\.)?\[\s*(?![\"'])[^\]\r\n]+\]"#
            let reflected = #"\bReflect\s*(?:\?\.|\.)\s*(?:get|set|has|deleteProperty|ownKeys)\s*\(\s*"#
                + escaped + #"\s*(?:,|\))"#
            if semanticSource.range(of: computed, options: [.regularExpression, .caseInsensitive]) != nil
                || semanticSource.range(of: reflected, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        let documentComputed = #"\bdocument\s*(?:\?\.|\.)\s*(?:body|documentElement)\s*(?:\?\.)?\[\s*(?![\"'])"#
        return semanticSource.range(of: documentComputed, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// 論理名（日本語）: HTML markup whole-column observer検出関数
    /// 処理概要: `innerHTML`/`outerHTML`列とXML serializationによる要素markup全体の観測を保守的に検出します。
    static func hasWholeMarkupObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"(?:\?\.|\.)\s*(?:innerHTML|outerHTML)\b"#,
            #"\[\s*[\"'](?:innerHTML|outerHTML)[\"']\s*\]"#,
            #"\{[^{}\n;]*\b(?:innerHTML|outerHTML)\b[^{}\n;]*\}\s*="#,
            #"\bXMLSerializer\b"#,
            #"\bserializeToString\s*(?:\?\.)?\s*\("#
        ]
        return patterns.contains {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// 論理名（日本語）: CSSOM whole-source observer検出関数
    /// 処理概要: stylesheet rule列やCSSStyleSheet mutation APIを介したauthored CSS全体の観測を保守的に検出します。
    static func hasCSSOMObserver(
        _ source: String,
        authoredCSSOwnerIDs: Set<String> = []
    ) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let directOrigins = [
            #"\bdocument\s*(?:\?\.|\.)\s*styleSheets\b"#,
            #"\bdocument\s*\[\s*[\"']styleSheets[\"']\s*\]"#,
            #"\{[^{}\n;]*\bstyleSheets\b[^{}\n;]*\}\s*=\s*document\b"#,
            #"\bCSSStyleSheet\b"#,
            #"\b(?:insertRule|deleteRule|replaceSync)\s*(?:\?\.)?\s*\("#
        ]
        if directOrigins.contains(where: {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            return true
        }

        var ownerNames: Set<String> = ["styleElement", "styleNode", "styleTag", "authoredStyle", "linkElement", "stylesheetLink"]
        let ownerAcquisition = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:querySelector(?:All)?\s*\(\s*[\"']\s*(?:style\b|link\b)|getElementsByTagName\s*\(\s*[\"'](?:style|link)[\"'])"#
        ownerNames.formUnion(captureGroupOne(in: semanticSource, pattern: ownerAcquisition))
        for id in authoredCSSOwnerIDs {
            let escapedID = NSRegularExpression.escapedPattern(for: id)
            let idAcquisition = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:getElementById\s*\(\s*[\"']"#
                + escapedID + #"[\"']|querySelector\s*\(\s*[\"']\s*#"# + escapedID + #"(?:\b|[^\"']*)[\"'])"#
            ownerNames.formUnion(captureGroupOne(in: semanticSource, pattern: idAcquisition))
        }

        var sheetNames: Set<String> = ["sheet", "styleSheet", "stylesheet"]
        for owner in ownerNames {
            let escaped = NSRegularExpression.escapedPattern(for: owner)
            let access = #"\b"# + escaped + #"\s*(?:(?:\?\.|\.)\s*sheet\b|\[\s*[\"']sheet[\"']\s*\])"#
            let destructure = #"\{[^{}\n;]*\bsheet\b[^{}\n;]*\}\s*=\s*"# + escaped + #"\b"#
            let reflected = #"\bReflect\s*(?:\?\.|\.)\s*(?:get|set|has|deleteProperty|ownKeys)\s*\(\s*"#
                + escaped + #"\s*(?:,|\))"#
            if [access, destructure, reflected].contains(where: {
                semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
            }) {
                return true
            }
            let assignment = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*"#
                + escaped + #"\s*(?:(?:\?\.|\.)\s*sheet\b|\[\s*[\"']sheet[\"']\s*\])"#
            sheetNames.formUnion(captureGroupOne(in: semanticSource, pattern: assignment))
        }
        let directOwnerSheet = #"(?:querySelector(?:All)?\s*\(\s*[\"']\s*(?:style\b|link\b)[^\"']*[\"']|getElementsByTagName\s*\(\s*[\"'](?:style|link)[\"']\s*\))[^;\r\n]*(?:(?:\?\.|\.)\s*sheet\b|\[\s*[\"']sheet[\"']\s*\])"#
        if semanticSource.range(of: directOwnerSheet, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        for id in authoredCSSOwnerIDs {
            let escapedID = NSRegularExpression.escapedPattern(for: id)
            let directIDSheet = #"(?:getElementById\s*\(\s*[\"']"# + escapedID
                + #"[\"']\s*\)|querySelector\s*\(\s*[\"']\s*#"# + escapedID
                + #"(?:\b|[^\"']*)[\"']\s*\))[^;\r\n]*(?:(?:\?\.|\.)\s*sheet\b|\[\s*[\"']sheet[\"']\s*\])"#
            if semanticSource.range(of: directIDSheet, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }

        let sheetAssignment = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:document\s*(?:\?\.|\.)\s*styleSheets|\b(?:sheet|styleSheet|stylesheet)\b)"#
        sheetNames.formUnion(captureGroupOne(in: semanticSource, pattern: sheetAssignment))
        var ruleNames: Set<String> = ["rule", "cssRule", "styleRule"]
        for sheet in sheetNames {
            let escaped = NSRegularExpression.escapedPattern(for: sheet)
            let sheetObserver = #"\b"# + escaped
                + #"\s*(?:(?:\?\.|\.)\s*(?:cssRules|rules)\b|\[\s*[\"'](?:cssRules|rules)[\"']\s*\])"#
            let sheetDestructure = #"\{[^{}\n;]*\b(?:cssRules|rules)\b[^{}\n;]*\}\s*=\s*"# + escaped + #"\b"#
            let sheetMutation = #"\b"# + escaped
                + #"\s*(?:\?\.|\.)\s*(?:insertRule|deleteRule|replaceSync|replace)\s*\("#
            let sheetBracketMutation = #"\b"# + escaped
                + #"\s*\[\s*["'](?:insertRule|deleteRule|replaceSync|replace)["']\s*\]\s*(?:\?\.)?\s*\("#
            let sheetCallMutation = #"\b(?:insertRule|deleteRule|replaceSync|replace)\s*\.\s*(?:call|apply)\s*\(\s*"#
                + escaped + #"\s*(?:,|\))"#
            let reflected = #"\bReflect\s*(?:\?\.|\.)\s*(?:get|set|has|deleteProperty|ownKeys)\s*\(\s*"#
                + escaped + #"\s*(?:,|\))"#
            if [sheetObserver, sheetDestructure, sheetMutation, sheetBracketMutation, sheetCallMutation, reflected].contains(where: {
                semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
            }) {
                return true
            }
            let ruleAssignment = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*"#
                + escaped + #"\s*(?:(?:\?\.|\.)\s*(?:cssRules|rules)\b|\[\s*[\"'](?:cssRules|rules)[\"']\s*\])"#
            ruleNames.formUnion(captureGroupOne(in: semanticSource, pattern: ruleAssignment))
        }
        for rule in ruleNames {
            let escaped = NSRegularExpression.escapedPattern(for: rule)
            let property = #"\b"# + escaped
                + #"\s*(?:(?:\?\.|\.)\s*(?:cssText|selectorText)\b|\[\s*[\"'](?:cssText|selectorText)[\"']\s*\])"#
            let destructure = #"\{[^{}\n;]*\b(?:cssText|selectorText)\b[^{}\n;]*\}\s*=\s*"# + escaped + #"\b"#
            if semanticSource.range(of: property, options: [.regularExpression, .caseInsensitive]) != nil
                || semanticSource.range(of: destructure, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    /// 論理名（日本語）: Embedded style text whole-source observer検出関数
    /// 処理概要: aliasを含む`textContent` property取得により`<style>`本文全体を観測し得るruntimeを検出します。
    static func hasStyleTextObserver(
        _ source: String,
        authoredStyleIDs: Set<String> = []
    ) -> Bool {
        let semanticSource = commentStrippedSource(source)
        var aliases: Set<String> = ["style", "styleElement", "styleNode", "styleTag", "authoredStyle"]
        let acquisition = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:querySelector(?:All)?\s*\(\s*[\"']\s*style\b[^\"']*[\"']|getElementsByTagName\s*\(\s*[\"']style[\"'])"#
        aliases.formUnion(captureGroupOne(in: semanticSource, pattern: acquisition))
        for id in authoredStyleIDs {
            let escapedID = NSRegularExpression.escapedPattern(for: id)
            let idAcquisition = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:getElementById\s*\(\s*[\"']"#
                + escapedID + #"[\"']|querySelector\s*\(\s*[\"']\s*#"# + escapedID + #"(?:\b|[^\"']*)[\"'])"#
            aliases.formUnion(captureGroupOne(in: semanticSource, pattern: idAcquisition))
        }
        let assignmentSuffix = #"(?!\s*=(?!=|>))"#
        for alias in aliases {
            let escaped = NSRegularExpression.escapedPattern(for: alias)
            let propertyRead = #"\b"# + escaped + #"\s*(?:\?\.|\.)\s*(?:textContent|innerText)\b"#
                + assignmentSuffix
            let bracketRead = #"\b"# + escaped + #"\s*\[\s*[\"'](?:textContent|innerText)[\"']\s*\]"#
                + assignmentSuffix
            let destructuredRead = #"\{[^{}\n;]*\b(?:textContent|innerText)\b[^{}\n;]*\}\s*=\s*"#
                + escaped + #"\b"#
            let childDataRead = #"\b"# + escaped
                + #"\s*(?:\?\.|\.)\s*firstChild\s*(?:\?\.|\.)\s*(?:data|nodeValue)\b"#
                + assignmentSuffix
            let childBracketRead = #"\b"# + escaped
                + #"\s*(?:(?:\?\.|\.)\s*firstChild|\[\s*["']firstChild["']\s*\])\s*(?:(?:\?\.|\.)\s*(?:data|nodeValue)\b|\[\s*["'](?:data|nodeValue)["']\s*\])"#
                + assignmentSuffix
            let childDestructure = #"\{[^{}\n;]*\b(?:data|nodeValue)\b[^{}\n;]*\}\s*=\s*"#
                + escaped + #"\s*(?:(?:\?\.|\.)\s*firstChild|\[\s*["']firstChild["']\s*\])"#
            if [propertyRead, bracketRead, destructuredRead, childDataRead, childBracketRead, childDestructure].contains(where: {
                semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
            }) {
                return true
            }
        }
        let directStyleRead = #"(?:querySelector(?:All)?\s*\(\s*[\"']\s*style\b[^\"']*[\"']|getElementsByTagName\s*\(\s*[\"']style[\"']\s*\))[^;\r\n]*(?:(?:\?\.|\.)\s*(?:textContent|innerText)\b|\[\s*[\"'](?:textContent|innerText)[\"']\s*\]|(?:\?\.|\.)\s*firstChild\s*(?:\?\.|\.)\s*(?:data|nodeValue)\b)"#
            + assignmentSuffix
        if semanticSource.range(of: directStyleRead, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        for id in authoredStyleIDs {
            let escapedID = NSRegularExpression.escapedPattern(for: id)
            let directIDRead = #"(?:getElementById\s*\(\s*[\"']"# + escapedID
                + #"[\"']\s*\)|querySelector\s*\(\s*[\"']\s*#"# + escapedID
                + #"(?:\b|[^\"']*)[\"']\s*\))[^;\r\n]*(?:(?:\?\.|\.)\s*(?:textContent|innerText)\b|\[\s*[\"'](?:textContent|innerText)[\"']\s*\]|(?:\?\.|\.)\s*firstChild\s*(?:\?\.|\.)\s*(?:data|nodeValue)\b)"#
                + assignmentSuffix
            if semanticSource.range(of: directIDRead, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    /// 論理名（日本語）: Preview context whole-object observer検出関数
    /// 処理概要: preview context globalまたは`placementMocks` objectのalias・列挙・serialization起点を検出します。
    static func hasPreviewContextObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let globalName = "__OPENGRAPHITE_PREVIEW_CONTEXT__"
        let global = #"(?:(?:window|globalThis)\s*(?:(?:\?\.|\.)\s*"# + globalName
            + #"|(?:\?\.)?\s*\[\s*[\"']"# + globalName + #"[\"']\s*\])|\b"#
            + globalName + #"\b)"#
        var operands = [global]
        let aliasPattern = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*"#
            + global + #"(?:\s*(?:\|\||\?\?)\s*\{\s*\})?\s*(?:;|$)"#
        var aliases = Set(captureGroupOne(in: semanticSource, pattern: aliasPattern))
        var foundAlias = true
        while foundAlias {
            foundAlias = false
            for alias in Array(aliases) {
                let escaped = NSRegularExpression.escapedPattern(for: alias)
                let propagation = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*"#
                    + escaped + #"\s*(?:;|$)"#
                for captured in captureGroupOne(in: semanticSource, pattern: propagation)
                where !aliases.contains(captured) {
                    aliases.insert(captured)
                    foundAlias = true
                }
            }
        }
        operands.append(contentsOf: aliases.map {
            #"\b"# + NSRegularExpression.escapedPattern(for: $0) + #"\b"#
        })
        for operand in operands {
            let wholePatterns = [
                operand + #"\s*(?:(?:\?\.|\.)\s*placementMocks\b|(?:\?\.)?\s*\[\s*[\"']placementMocks[\"']\s*\])"#,
                #"\{[^{}\n;]*\bplacementMocks\b[^{}\n;]*\}\s*=\s*"# + operand,
                operand + #"\s*(?:\?\.)?\[\s*(?![\"'])[^\]\r\n]+\]"#,
                #"\.\.\.\s*"# + operand,
                #"\{[^{}\n;]*\.\.\.[^{}\n;]*\}\s*=\s*"# + operand,
                #"\b(?:Object\s*\.\s*(?:keys|values|entries|getOwnPropertyNames)|JSON\s*\.\s*stringify|Reflect\s*\.\s*ownKeys)\s*\(\s*"#
                    + operand + #"\s*(?:,|\))"#,
                #"\bReflect\s*\.\s*(?:get|set|has|deleteProperty)\s*\(\s*"#
                    + operand + #"\s*,\s*(?:(?![\"'])|[\"']placementMocks[\"'])"#,
                #"\bstructuredClone\s*\(\s*"# + operand + #"\s*\)"#,
                #"\bObject\s*\.\s*assign\s*\([^;\n]*"# + operand + #"[^;\n]*\)"#,
                #"\bfor\s*\([^;\n]*\bin\s*"# + operand + #"\s*\)"#
            ]
            if wholePatterns.contains(where: {
                semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
            }) {
                return true
            }
        }
        return false
    }

    /// 論理名（日本語）: Preview host field observer索引関数
    /// 処理概要: runtime sourceがexact string keyとして観測するmigration destination `host.*` fieldを返します。
    static func observedPreviewHostFields(_ source: String) -> Set<String> {
        let semanticSource = commentStrippedSource(source)
        let fields = ["host.variant"]
        var observed = Set(fields.filter { semanticSource.contains("\"\($0)\"") || semanticSource.contains("'\($0)'") })
        if semanticSource.range(
            of: #"["']host\.["']\s*\+\s*["']variant["']"#,
            options: .regularExpression
        ) != nil {
            observed.insert("host.variant")
        }
        return observed
    }

    /// 論理名（日本語）: Dynamic selector observer検出関数
    /// 処理概要: selector引数をliteralとして静的確定できないquery/match APIを検出します。
    static func hasDynamicSelectorObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"\b(?:querySelectorAll|querySelector|matches|closest|webkitMatchesSelector)\s*(?:\?\.)?\s*\(\s*(?![\"'])"#,
            #"\[\s*[\"'](?:querySelectorAll|querySelector|matches|closest|webkitMatchesSelector)[\"']\s*\]\s*(?:\?\.)?\s*\(\s*(?![\"'])"#,
            #"\b(?:querySelectorAll|querySelector|matches|closest|webkitMatchesSelector)\s*\.\s*(?:call|apply)\s*\([^,]+,\s*(?![\"'])"#
        ]
        if patterns.contains(where: {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) { return true }
        let aliasPattern = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:(?:\?\.|\.)\s*|\[\s*[\"'])(?:querySelectorAll|querySelector|matches|closest|webkitMatchesSelector)(?:[\"']\s*\])?"#
        return captureGroupOne(in: semanticSource, pattern: aliasPattern).contains { alias in
            let escaped = NSRegularExpression.escapedPattern(for: alias)
            let call = #"\b"# + escaped + #"\s*(?:\?\.)?\s*\(\s*(?![\"'])"#
            return semanticSource.range(of: call, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// 論理名（日本語）: AttributeNode observer検出関数
    /// 処理概要: attribute token objectを取得・設定・削除するDOM APIを検出します。
    static func hasAttributeNodeObserver(_ source: String) -> Bool {
        let semanticSource = commentStrippedSource(source)
        let patterns = [
            #"\b(?:getAttributeNode(?:NS)?|setAttributeNode(?:NS)?|removeAttributeNode)\s*(?:\?\.)?\s*\("#,
            #"\[\s*[\"'](?:getAttributeNode(?:NS)?|setAttributeNode(?:NS)?|removeAttributeNode)[\"']\s*\]\s*(?:\?\.)?\s*\("#,
            #"\b(?:getAttributeNode(?:NS)?|setAttributeNode(?:NS)?|removeAttributeNode)\s*\.\s*(?:call|apply)\s*\("#
        ]
        if patterns.contains(where: {
            semanticSource.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) { return true }
        let aliasPattern = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:(?:\?\.|\.)\s*|\[\s*[\"'])(?:getAttributeNode(?:NS)?|setAttributeNode(?:NS)?|removeAttributeNode)(?:[\"']\s*\])?"#
        return captureGroupOne(in: semanticSource, pattern: aliasPattern).contains { alias in
            let escaped = NSRegularExpression.escapedPattern(for: alias)
            return semanticSource.range(
                of: #"\b"# + escaped + #"\s*(?:\?\.)?\s*\("#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    /// 論理名（日本語）: Generated custom property observer検出関数
    /// 処理概要: runtime code/stringがmigration destination custom property namespaceを参照する場合に`true`を返します。
    static func containsGeneratedCustomPropertyObserver(_ source: String) -> Bool {
        commentStrippedSource(source).contains("--migrated-v1-")
    }

    private static func domReceiverNames(in source: String) -> Set<String> {
        var names: Set<String> = [
            "node", "element", "el", "target", "currentTarget", "host", "root", "instance", "this"
        ]
        let assignmentPatterns = [
            #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:querySelector(?:All)?|getElementById|getElementsBy(?:ClassName|TagName))\s*\("#,
            #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*\b(?:event|evt|e)\s*(?:\?\.|\.)\s*(?:target|currentTarget)\b"#
        ]
        for pattern in assignmentPatterns {
            names.formUnion(captureGroupOne(in: source, pattern: pattern))
        }
        return names
    }

    private static func captureGroupOne(in source: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        }
    }

    /// DOM attribute accessor/mutator aliasが指定literal属性を観測するかを返します。
    private static func hasAliasedLiteralAttributeObserver(
        in source: String,
        attributeName: String
    ) -> Bool {
        let aliasPattern = #"\b(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*[^;\n]*(?:(?:\?\.|\.)\s*|\[\s*["'])(?:get|has|set|remove|toggle)Attribute(?:["']\s*\])?"#
        let escapedAttribute = NSRegularExpression.escapedPattern(for: attributeName)
        return captureGroupOne(in: source, pattern: aliasPattern).contains { alias in
            let escapedAlias = NSRegularExpression.escapedPattern(for: alias)
            let call = #"\b"# + escapedAlias + #"\s*(?:\?\.)?\s*\(\s*["']"#
                + escapedAttribute + #"["'](?:\s*[,\)])"#
            return source.range(of: call, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// DOM attribute accessor/mutatorを`call`/`apply`で借用し、指定literal属性を観測するかを返します。
    private static func hasBorrowedLiteralAttributeObserver(
        in source: String,
        attributeName: String
    ) -> Bool {
        let escapedAttribute = NSRegularExpression.escapedPattern(for: attributeName)
        let callPattern = #"\b(?:get|has|set|remove|toggle)Attribute\s*(?:\?\.|\.)\s*call\s*\(\s*[^,\r\n]+,\s*[\"']"#
            + escapedAttribute + #"[\"']\s*(?:,|\))"#
        let applyPattern = #"\b(?:get|has|set|remove|toggle)Attribute\s*(?:\?\.|\.)\s*apply\s*\(\s*[^,\r\n]+,\s*\[\s*[\"']"#
            + escapedAttribute + #"[\"']\s*(?:,|\])"#
        return [callPattern, applyPattern].contains {
            source.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// 論理名（日本語）: JavaScript comment除外関数
    /// 処理概要: line/block commentを空白へ置換し、codeとstring/template literalはobserver検査用に保持します。
    private static func commentStrippedSource(_ source: String) -> String {
        var result = ""
        var cursor = source.startIndex
        var previousToken: String?
        while cursor < source.endIndex {
            let next = source.index(after: cursor)
            if source[cursor] == "/", next < source.endIndex, source[next] == "/" {
                let end = OpenGraphiteJavaScriptLexical.lineCommentEnd(in: source, from: next)
                result.append(" ")
                cursor = end
                continue
            }
            if source[cursor] == "/", next < source.endIndex, source[next] == "*" {
                let end = source[next...].range(of: "*/")?.upperBound ?? source.endIndex
                result.append(" ")
                cursor = end
                continue
            }
            if source[cursor] == "/",
               OpenGraphiteJavaScriptLexical.canStartRegularExpression(afterToken: previousToken),
               let end = OpenGraphiteJavaScriptLexical.regularExpressionEnd(in: source, from: cursor) {
                result.append(contentsOf: source[cursor..<end])
                previousToken = "<regex>"
                cursor = end
                continue
            }
            let character = source[cursor]
            result.append(character)
            cursor = next
            if character == "\"" || character == "'" || character == "`" {
                while cursor < source.endIndex {
                    let current = source[cursor]
                    result.append(current)
                    cursor = source.index(after: cursor)
                    if current == "\\", cursor < source.endIndex {
                        result.append(source[cursor])
                        cursor = source.index(after: cursor)
                    } else if current == character {
                        break
                    }
                }
                previousToken = "<literal>"
            } else if !character.isWhitespace {
                previousToken = String(character)
            }
        }
        return result
    }
}

/// 論理名（日本語）: HTML Lang source
/// 概要: HTML `lang` 属性を literal fallback として使うか runtime field で解決するかを表します。
enum OpenGraphiteHTMLLangSource: String, Codable, Equatable, CaseIterable {
    case literal
    case binding
}

/// 論理名（日本語）: HTML Dir source
/// 概要: HTML `dir` 属性を literal fallback、自動推定、runtime field のどれで解決するかを表します。
enum OpenGraphiteHTMLDirSource: String, Codable, Equatable, CaseIterable {
    case literal
    case auto
    case binding
}

/// 論理名（日本語）: HTML Document Context
/// 概要: `<html>` に永続化する document attribute と OpenGraphite binding metadata を表します。
///
/// プロパティ:
/// - `langSource`: `lang` の解決方式。
/// - `langValue`: `lang` 属性として保存する literal / fallback 値。
/// - `langField`: binding 時に参照する runtime field 名。
/// - `dirSource`: `dir` の解決方式。
/// - `dirValue`: `dir` 属性として保存する literal / fallback 値。
/// - `dirField`: binding 時に参照する runtime field 名。
struct OpenGraphiteHTMLDocumentContext: Codable, Equatable {
    static let empty = OpenGraphiteHTMLDocumentContext()

    var langSource: OpenGraphiteHTMLLangSource
    var langValue: String
    var langField: String
    var dirSource: OpenGraphiteHTMLDirSource
    var dirValue: String
    var dirField: String

    /// 論理名（日本語）: HTML Document Context初期化関数
    /// 処理概要: `<html>` attribute と binding metadata を正規化して保持します。
    ///
    /// - Parameters:
    ///   - langSource: `lang` の解決方式。
    ///   - langValue: `lang` 属性として保存する literal / fallback 値。
    ///   - langField: binding 時に参照する runtime field 名。
    ///   - dirSource: `dir` の解決方式。
    ///   - dirValue: `dir` 属性として保存する literal / fallback 値。
    ///   - dirField: binding 時に参照する runtime field 名。
    init(
        langSource: OpenGraphiteHTMLLangSource = .literal,
        langValue: String = "",
        langField: String = "",
        dirSource: OpenGraphiteHTMLDirSource = .literal,
        dirValue: String = "",
        dirField: String = ""
    ) {
        self.langSource = langSource
        self.langValue = langValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.langField = langField.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dirSource = dirSource
        self.dirValue = dirValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dirField = dirField.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 論理名（日本語）: HTML script参照
/// 概要: HTML 内の `<script>` 要素から i18n 実装検出に必要な参照情報を抽出した値です。
///
/// プロパティ:
/// - `src`: `src` 属性。inline script の場合は `nil`。
/// - `type`: `type` 属性。
/// - `content`: inline script 本文。
struct OpenGraphiteHTMLScriptReference: Equatable {
    var src: String?
    var type: String?
    var content: String
}

/// 論理名（日本語）: HTML embedded stylesheet参照
/// 概要: HTML内のactual `<style>` element本文をdocument orderで保持します。
///
/// プロパティ:
/// - `content`: `<style>` start/end tagの間にあるraw CSS source。
struct OpenGraphiteHTMLEmbeddedStylesheetReference: Equatable {
    var content: String
}

/// 論理名（日本語）: HTML stylesheet解決結果
/// 概要: browser document orderの独立stylesheetと、headless winnerを断定できないsource診断を保持します。
///
/// プロパティ:
/// - `sources`: raw連結せず個別ASTとして評価するstylesheet一覧。
/// - `diagnostics`: unreadable/external/import/layer/unsupported selector等のprovenance診断。
/// - `hasIncompleteProvenance`: 既知candidateを返せてもwinnerを完全には断定できない場合は`true`。
struct OpenGraphiteHTMLStylesheetResolution: Equatable {
    var sources: [OpenGraphiteCSSStylesheetSource]
    var diagnostics: [OpenGraphiteDiagnostic]
    var hasIncompleteProvenance: Bool
}

/// 論理名（日本語）: HTML text binding resource
/// 概要: `data-i18n-key` を持つ text binding の fallback HTML と同梱 variant 属性を表します。
///
/// プロパティ:
/// - `key`: `data-i18n-key`。
/// - `fallbackHTML`: 要素本文に残る fallback HTML。
/// - `variants`: `data-og-text-variant-<locale>` の locale と値。
struct OpenGraphiteHTMLTextBindingResource: Equatable {
    var key: String
    var fallbackHTML: String
    var variants: [String: String]
}

/// 論理名（日本語）: HTML実描画target
/// 概要: wrapper nodeから解決した実DOM要素とAgent向けsource provenanceをCSS編集経路へ渡します。
///
/// プロパティ:
/// - `value`: CLI / MCP / Appへ公開する描画target情報。
/// - `element`: source selector照合に使うDOM要素。
/// - `tag`: inline sourceの最小差分編集に使う開始tag。
/// - `inlineWinnerProperties`: inline styleがcascade winnerのproperty集合。
/// - `winnerProvenance`: propertyごとのfull multi-stylesheet cascade winner。
/// - `hasIncompleteCSSProvenance`: target自身のanimation/CSS-wide computed値をheadlessで断定できない場合のguard。
struct OpenGraphiteHTMLRenderingTarget: Equatable {
    var value: OpenGraphiteAgentRenderingTarget
    var element: OpenGraphiteCSSDOMElement
    var tag: OpenGraphiteHTMLTag
    var inlineWinnerProperties: Set<String>
    var winnerProvenance: [String: OpenGraphiteCSSDeclarationProvenance]
    var hasIncompleteCSSProvenance: Bool
}

/// 論理名（日本語）: HTML参照対象
/// 概要: Canvas Object Referenceの解決に必要な軽量source情報だけを保持します。
///
/// プロパティ:
/// - `id`: optionalな`data-og-id`。
/// - `internalID`: typed referenceが指す`data-og-internal-id`。
/// - `tagName`: authored elementの小文字tag name。
/// - `depth`: authored DOMでの深さ。
/// - `isProjectResourceRoot`: Page / Component全体の配置対象か。
struct OpenGraphiteHTMLReferenceTarget: Equatable {
    var id: String
    var internalID: String
    var tagName: String
    var depth: Int
    var isProjectResourceRoot: Bool
}

/// 論理名（日本語）: HTML DOM索引record
/// 概要: annotationの有無に依存せず、開始tag、authored親関係、source用要素とbrowser CSS評価用要素を分離して保持します。
///
/// プロパティ:
/// - `tag`: source HTMLに実在する開始tag。
/// - `element`: authored parentだけを持ち、locator / relative pathへ使うsource DOM要素。
/// - `cssElement`: implicit browser ancestorを含み、selector cascadeだけに使う評価DOM要素。
/// - `parentIndex`: authored node配列内の親index。
/// - `siblingTypeCount`: authored parent直下の同tag sibling総数。
/// - `contentEnd`: 開始tag直後から要素内容が終わるsource offset。
/// - `fullEnd`: 閉じtagまたは要素source全体が終わるoffset。
private struct OpenGraphiteHTMLDOMRecord: Equatable {
    var tag: OpenGraphiteHTMLTag
    var element: OpenGraphiteCSSDOMElement
    var cssElement: OpenGraphiteCSSDOMElement
    var parentIndex: Int?
    var siblingTypeCount: Int
    var contentEnd: Int?
    var fullEnd: Int?
}

/// HTML tree constructionで確定したauthored elementの親関係とsource終端を保持します。
private struct OpenGraphiteHTMLParsedElement: Equatable {
    var tag: OpenGraphiteHTMLTag
    var parentIndex: Int?
    var contentEnd: Int?
    var fullEnd: Int?
}

/// 論理名（日本語）: HTML text要素source範囲
/// 概要: text content抽出で必要な開始tagとsource終端だけを保持します。
///
/// プロパティ:
/// - `tag`: text抽出対象の開始tag。
/// - `contentEnd`: 要素内容が終わるsource offset。
/// - `fullEnd`: 閉じtagを含む要素全体が終わるsource offset。
private struct OpenGraphiteHTMLTextElementRange {
    var tag: OpenGraphiteHTMLTag
    var contentEnd: Int?
    var fullEnd: Int?
}

/// inline styleの値と`!important`優先度をsource cascadeと比較する内部値です。
private struct OpenGraphiteHTMLInlineStyleValue: Equatable {
    var property: String
    var value: String
    var important: Bool
    var sourceOrder: Int
    var propertyRange: Range<Int>
    var valueRange: Range<Int>
    var declarationRange: Range<Int>
}

/// HTML entityをdecodeしたinline CSS tokenとraw source rangeの対応です。
private struct OpenGraphiteInlineCSSSemanticComponent {
    /// 論理名（日本語）: inline CSS semantic component種別
    /// 概要: HTML entityとCSS escapeを復号した文字token、または空白・comment triviaを区別します。
    enum Kind {
        case character(Character, escaped: Bool)
        case trivia

        var character: Character? {
            guard case let .character(character, _) = self else { return nil }
            return character
        }

        var isEscaped: Bool {
            guard case let .character(_, escaped) = self else { return false }
            return escaped
        }

        var isTrivia: Bool {
            if case .trivia = self { return true }
            return false
        }
    }

    var kind: Kind
    var rawRange: Range<String.Index>
}

/// 論理名（日本語）: OpenGraphite HTML文書
/// 概要: annotation有無に依存しないHTML node抽出と、明示された開始タグ単位の編集を担当します。
///
/// プロパティ:
/// - `html`: 対象 HTML 文字列。
struct OpenGraphiteHTMLDocument {
    var html: String

    /// 論理名（日本語）: HTML Document Context取得関数
    /// 処理概要: `<html>` 開始タグから永続 document attribute と binding metadata を読み取ります。
    ///
    /// - Returns: HTML document context。`<html>` がない場合は空 context を返します。
    func htmlDocumentContext() -> OpenGraphiteHTMLDocumentContext {
        guard let tag = parsedTags().first(where: { $0.tagName == "html" }) else {
            return .empty
        }
        return OpenGraphiteHTMLDocumentContext(
            langSource: OpenGraphiteHTMLLangSource(rawValue: tag.attributeValue(named: "data-og-lang-source") ?? "") ?? .literal,
            langValue: tag.attributeValue(named: "lang") ?? "",
            langField: tag.attributeValue(named: "data-og-lang-field") ?? "",
            dirSource: OpenGraphiteHTMLDirSource(rawValue: tag.attributeValue(named: "data-og-dir-source") ?? "") ?? .literal,
            dirValue: tag.attributeValue(named: "dir") ?? "",
            dirField: tag.attributeValue(named: "data-og-dir-field") ?? ""
        )
    }

    /// 論理名（日本語）: HTML stylesheet source解決関数
    /// 処理概要: `<style>`とscope内local `<link rel="stylesheet">`をdocument orderで個別読込し、project/companion fallbackを同じorigin modelへ統合します。
    ///
    /// - Parameters:
    ///   - documentURL: 対象HTMLのfile URL。
    ///   - allowedRootURL: local stylesheetが越えてはならないproject/resource root。省略時はHTML所在directory。
    ///   - projectCSSURL: `.ogp` cssLibraryのread-only source URL。
    ///   - projectCSS: 呼出し側が既に読込済みのproject CSS source。
    ///   - companionCSS: HTMLと同名のeditable companion CSS。
    /// - Returns: source identity/order/editabilityとincomplete provenance診断を持つ解決結果。
    func stylesheetResolution(
        documentURL: URL,
        allowedRootURL: URL? = nil,
        projectCSSURL: URL? = nil,
        projectCSS: String? = nil,
        companionCSS: OpenGraphiteCompanionCSSDocument? = nil
    ) -> OpenGraphiteHTMLStylesheetResolution {
        let standardizedDocumentURL = documentURL.standardizedFileURL
        let allowedRoot = (allowedRootURL ?? standardizedDocumentURL.deletingLastPathComponent())
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let standardizedProjectURL = projectCSSURL?.standardizedFileURL
        let companionURL = OpenGraphiteCompanionCSSDocument
            .companionURL(forHTMLURL: standardizedDocumentURL)
            .standardizedFileURL
        var sources: [OpenGraphiteCSSStylesheetSource] = []
        var diagnostics: [OpenGraphiteDiagnostic] = []
        var seenLocalURLs: Set<URL> = []
        var editableScopesByURL: [URL: Set<String>] = [:]

        func diagnostic(_ message: String, path: String?) -> OpenGraphiteDiagnostic {
            OpenGraphiteDiagnostic(
                severity: .warning,
                code: "incomplete-css-provenance",
                message: message,
                path: path,
                nodeID: nil
            )
        }

        func appendSource(
            sourceID: String,
            sourceKind: String,
            source: String,
            editable: Bool,
            atRules: [OpenGraphiteCSSAtRuleContext] = []
        ) {
            sources.append(
                OpenGraphiteCSSStylesheetSource(
                    sourceID: sourceID,
                    sourceKind: sourceKind,
                    source: source,
                    editable: editable,
                    atRules: atRules
                )
            )
            let inspection = OpenGraphiteCSSSourceDocument.provenanceInspection(source)
            guard !inspection.isComplete else { return }
            diagnostics.append(
                diagnostic(
                    "CSS source \(sourceID) のwinnerを完全評価できません: \(inspection.reasons.joined(separator: ", "))",
                    path: sourceID
                )
            )
        }

        let authoredTags = parsedTags()
        let authoredBaseURL: URL = {
            guard let baseTag = authoredTags.first(where: {
                $0.tagName == "base" && $0.attributeValue(named: "href") != nil
            }),
                  let href = baseTag.attributeValue(named: "href"),
                  let resolved = URL(string: href, relativeTo: standardizedDocumentURL)?.absoluteURL
            else { return standardizedDocumentURL }
            guard resolved.isFileURL else {
                diagnostics.append(
                    diagnostic(
                        "外部base URLはheadless local stylesheet resolverで評価できません: \(resolved.absoluteString)",
                        path: standardizedDocumentURL.path
                    )
                )
                return standardizedDocumentURL
            }
            let safeURL = resolved.standardizedFileURL.resolvingSymlinksInPath()
            guard Self.isURL(safeURL, containedIn: allowedRoot) else {
                diagnostics.append(
                    diagnostic(
                        "base URLが許可root外を参照します: \(safeURL.path)",
                        path: standardizedDocumentURL.path
                    )
                )
                return standardizedDocumentURL
            }
            return safeURL
        }()

        for tag in authoredTags {
            if tag.tagName == "style" {
                guard isCSSEmbeddedStyleTag(tag),
                      !tag.attributes.contains(where: { $0.name.caseInsensitiveCompare("disabled") == .orderedSame }),
                      let element = element(for: tag)
                else { continue }
                let media = tag.attributeValue(named: "media")
                    .map(Self.trimmingASCIIWhitespace) ?? ""
                let atRules = media.isEmpty || media.caseInsensitiveCompare("all") == .orderedSame
                    ? []
                    : [OpenGraphiteCSSAtRuleContext(name: "media", prelude: media)]
                appendSource(
                    sourceID: "\(standardizedDocumentURL.absoluteString)#style-\(tag.range.lowerBound)",
                    sourceKind: "embedded",
                    source: html.substring(element.contentRange),
                    editable: false,
                    atRules: atRules
                )
                continue
            }
            guard isCSSStylesheetLinkTag(tag) else { continue }
            let relations = Set(Self.asciiWhitespaceSeparatedTokens(tag.attributeValue(named: "rel") ?? ""))
            guard !relations.contains("alternate"),
                  !tag.attributes.contains(where: { $0.name.caseInsensitiveCompare("disabled") == .orderedSame }),
                  let href = tag.attributeValue(named: "href"), !href.isEmpty,
                  let resolvedURL = URL(string: href, relativeTo: authoredBaseURL)?.absoluteURL
            else { continue }
            guard resolvedURL.isFileURL else {
                diagnostics.append(
                    diagnostic(
                        "外部stylesheetはheadless source provenanceを読めません: \(resolvedURL.absoluteString)",
                        path: standardizedDocumentURL.path
                    )
                )
                continue
            }
            let localURL = resolvedURL.standardizedFileURL.resolvingSymlinksInPath()
            guard Self.isURL(localURL, containedIn: allowedRoot) else {
                diagnostics.append(
                    diagnostic(
                        "stylesheetが許可root外を参照します: \(localURL.path)",
                        path: localURL.path
                    )
                )
                continue
            }
            let source: String?
            if let standardizedProjectURL,
               localURL.standardizedFileURL == standardizedProjectURL.standardizedFileURL,
               let projectCSS {
                source = projectCSS
            } else if localURL.standardizedFileURL == companionURL.standardizedFileURL,
                      let companionCSS {
                source = companionCSS.css
            } else {
                source = try? String(contentsOf: localURL, encoding: .utf8)
            }
            guard let source else {
                diagnostics.append(
                    diagnostic("stylesheetを読み込めません: \(localURL.path)", path: localURL.path)
                )
                continue
            }
            seenLocalURLs.insert(localURL.standardizedFileURL)
            let kind: String
            let editable: Bool
            if let standardizedProjectURL,
               localURL.standardizedFileURL == standardizedProjectURL.standardizedFileURL {
                kind = "project"
                editable = false
            } else if localURL.standardizedFileURL == companionURL.standardizedFileURL {
                kind = "companion"
                editable = true
            } else {
                kind = "linked"
                editable = false
            }
            let media = tag.attributeValue(named: "media")
                .map(Self.trimmingASCIIWhitespace) ?? ""
            let atRules = media.isEmpty || media.caseInsensitiveCompare("all") == .orderedSame
                ? []
                : [OpenGraphiteCSSAtRuleContext(name: "media", prelude: media)]
            if editable {
                let scopeKey = atRules.map {
                    "\($0.name.lowercased()):\(OpenGraphiteCSSCascadeEnvironment.normalizedMediaCondition($0.prelude))"
                }.joined(separator: "|")
                let previousScopes = editableScopesByURL[localURL.standardizedFileURL] ?? []
                if !previousScopes.isEmpty, !previousScopes.contains(scopeKey) {
                    diagnostics.append(
                        diagnostic(
                            "同じeditable stylesheetが異なるlink media scopeで複数回参照され、単一source rangeを安全に編集できません: \(localURL.path)",
                            path: localURL.path
                        )
                    )
                }
                editableScopesByURL[localURL.standardizedFileURL, default: []].insert(scopeKey)
            }
            appendSource(
                sourceID: "\(localURL.absoluteString)#link-\(tag.range.lowerBound)",
                sourceKind: kind,
                source: source,
                editable: editable,
                atRules: atRules
            )
        }

        if let standardizedProjectURL,
           let projectCSS,
           !seenLocalURLs.contains(standardizedProjectURL.standardizedFileURL) {
            let fallback = OpenGraphiteCSSStylesheetSource(
                sourceID: standardizedProjectURL.absoluteString,
                sourceKind: "project",
                source: projectCSS,
                editable: false
            )
            sources.insert(fallback, at: 0)
            let inspection = OpenGraphiteCSSSourceDocument.provenanceInspection(projectCSS)
            if !inspection.isComplete {
                diagnostics.append(
                    diagnostic(
                        "CSS source \(standardizedProjectURL.absoluteString) のwinnerを完全評価できません: \(inspection.reasons.joined(separator: ", "))",
                        path: standardizedProjectURL.path
                    )
                )
            }
        }
        if let companionCSS,
           !seenLocalURLs.contains(companionURL.standardizedFileURL) {
            appendSource(
                sourceID: companionURL.absoluteString,
                sourceKind: "companion",
                source: companionCSS.css,
                editable: true
            )
        }
        return OpenGraphiteHTMLStylesheetResolution(
            sources: sources,
            diagnostics: diagnostics,
            hasIncompleteProvenance: !diagnostics.isEmpty
        )
    }

    /// 論理名（日本語）: ノード一覧抽出関数
    /// 処理概要: HTML を軽量に走査し、annotationのない標準要素を含む全開始タグをAgent nodeへ変換します。
    ///
    /// - Parameters:
    ///   - companionCSS: HTML と同名の design value 正本 CSS。未指定時は project CSS と inline style だけを読みます。
    ///   - projectCSS: `.ogp` の `cssLibrary` が指す project-wide author stylesheet。companion CSS より前に cascade します。
    ///   - activeMediaQueries: headless inspectionでactiveとみなすauthored `@media` 条件。source上の条件文字列を正規化して照合します。
    ///   - contract: 抽出対象の CSS 宣言を定義する OpenGraphite 契約。
    ///   - documentURL: locatorとrevision-scoped referenceに含める標準化済みdocument URL。
    ///   - isProjectRegisteredResource: `.ogp`から明示参照されたpage/componentのroot evidenceを算出する場合は`true`。
    /// - Returns: DOM 出現順の OpenGraphite agent node 一覧。
    func nodes(
        companionCSS: OpenGraphiteCompanionCSSDocument? = nil,
        projectCSS: String? = nil,
        stylesheetSources: [OpenGraphiteCSSStylesheetSource]? = nil,
        hasIncompleteCSSProvenance: Bool = false,
        activeMediaQueries: [String] = [],
        contract: OpenGraphiteContract = .builtIn,
        documentURL: String = "",
        isProjectRegisteredResource: Bool = false
    ) -> [OpenGraphiteAgentNode] {
        let resolvedStylesheets = stylesheetSources ?? [
            projectCSS.map {
                OpenGraphiteCSSStylesheetSource(
                    sourceID: "project-css",
                    sourceKind: "project",
                    source: $0,
                    editable: false
                )
            },
            companionCSS.map {
                OpenGraphiteCSSStylesheetSource(
                    sourceID: "companion-css",
                    sourceKind: "companion",
                    source: $0.css,
                    editable: true
                )
            }
        ].compactMap { $0 }
        let records = domRecords()
        let companionCascadeTraces = cascadeTraces(
            for: records,
            stylesheetSources: resolvedStylesheets,
            environment: .inspection(activeMediaQueries: activeMediaQueries)
        )
        let internalIDCounts = Dictionary(
            grouping: records.compactMap { $0.tag.emptyNilAttribute(named: "data-og-internal-id") },
            by: { $0 }
        ).mapValues(\.count)
        let locators = records.indices.map { nodeLocator(for: $0, records: records, documentURL: documentURL) }
        let references = records.indices.map { index in
            nodeReference(
                for: index,
                records: records,
                locator: locators[index],
                internalIDCounts: internalIDCounts
            )
        }
        let resolvedStyles = Dictionary(uniqueKeysWithValues: records.indices.map { index in
            (
                index,
                resolvedStandardStyle(
                    for: index,
                    records: records,
                    trace: companionCascadeTraces[index]
                )
            )
        })
        let resolvedRenderingTargets = Dictionary(uniqueKeysWithValues: records.indices.map { index in
            (
                index,
                renderingTargets(
                    forWrapperAt: index,
                    records: records,
                    cascadeTraces: companionCascadeTraces
                )
            )
        })
        let projectResourceBoundaryIndices = isProjectRegisteredResource
            ? projectResourceBoundaryIndices(in: records)
            : []
        let projectResourceRootIndex = projectResourceBoundaryIndices.count == 1
            ? projectResourceBoundaryIndices.first
            : nil
        let textElementAtOffset = Dictionary(
            uniqueKeysWithValues: records.map {
                (
                    $0.tag.range.lowerBound,
                    OpenGraphiteHTMLTextElementRange(
                        tag: $0.tag,
                        contentEnd: $0.contentEnd,
                        fullEnd: $0.fullEnd
                    )
                )
            }
        )

        return records.indices.map { index in
            let record = records[index]
            let tag = record.tag
            let id = tag.emptyNilAttribute(named: "data-og-id") ?? ""
            let internalID = tag.emptyNilAttribute(named: "data-og-internal-id") ?? ""
            let inlineVariables = inlineStyleValues(for: tag, properties: nil).reduce(
                into: [String: String]()
            ) { result, entry in
                guard contract.isKnownCSSVariable(entry.key) else { return }
                result[entry.key] = entry.value.value
            }
            let companionTrace = companionCascadeTraces[index]
            let companionVariables = companionTrace?.authoredValues.filter {
                contract.isKnownCSSVariable($0.key)
            } ?? [:]
            let cssVariables = companionVariables.isEmpty
                ? inlineVariables
                : inlineVariables.merging(companionVariables) { _, companionValue in companionValue }
            let cssSourceTrace = companionTrace?.candidates.reduce(
                into: [String: [OpenGraphiteAgentCSSDeclarationTrace]]()
            ) { result, entry in
                result[entry.key] = entry.value.map { Self.agentTrace($0) }
            } ?? [:]
            let resolvedStandardValues = resolvedStyles[index] ?? [:]
            let nodeHasIncompleteCSSProvenance = hasIncompleteCSSProvenance
                || companionTrace?.incompleteProperties.isEmpty == false
            let cssResolvedValues = resolvedStandardValues.filter {
                contract.isKnownCSSVariable($0.key)
                    || $0.key.hasPrefix("--")
                    || $0.key == "content-visibility"
            }

            let renderingTargets = resolvedRenderingTargets[index] ?? []
            let capabilityEvidence = capabilityEvidence(
                for: index,
                records: records,
                resolvedStyles: resolvedStyles,
                renderingTargets: renderingTargets,
                projectResourceRootIndex: projectResourceRootIndex
            )
            let capabilities = capabilities(
                for: index,
                records: records,
                resolvedStyles: resolvedStyles,
                evidence: capabilityEvidence,
                projectResourceBoundaryIndices: Set(projectResourceBoundaryIndices)
            )
            let node = OpenGraphiteAgentNode(
                id: id,
                internalID: internalID,
                reference: references[index].value,
                annotationStatus: annotationStatus(for: tag),
                referenceStability: references[index].stability,
                locator: locators[index],
                tagName: tag.tagName,
                legacyTypeHint: tag.emptyNilAttribute(named: "data-og-type"),
                capabilities: capabilities,
                capabilityEvidence: capabilityEvidence,
                layout: derivedLayout(from: resolvedStandardValues),
                role: tag.emptyNilAttribute(named: "role"),
                cssVariables: cssVariables,
                cssSourceTrace: cssSourceTrace,
                cssResolvedValues: cssResolvedValues,
                hasIncompleteCSSProvenance: nodeHasIncompleteCSSProvenance,
                renderingTargets: renderingTargets.map(\.value),
                hidden: hasStandardHiddenAttribute(tag),
                locked: tag.attributeValue(named: "data-og-locked") == "true",
                depth: tag.depth,
                parentID: nearestAnnotatedParentID(for: index, records: records),
                parentReference: record.parentIndex.map { references[$0].value },
                textContent: textContent(
                    for: index,
                    records: records,
                    elementAtOffset: textElementAtOffset
                ),
                attributes: tag.attributeDictionary
            )

            return node
        }
    }

    /// 論理名（日本語）: HTML参照対象解決関数
    /// 処理概要: typed Canvas Object Referenceの内部IDを、1回のHTML tree走査だけで表示用軽量情報へ解決します。
    ///
    /// - Parameters:
    ///   - internalID: 参照が指す`data-og-internal-id`。
    ///   - isProjectRegisteredResource: Page / Component root判定を行う場合は`true`。
    /// - Returns: 一意な内部IDと一致する軽量参照対象。不在または重複時は`nil`。
    func referenceTarget(
        internalID: String,
        isProjectRegisteredResource: Bool = false
    ) -> OpenGraphiteHTMLReferenceTarget? {
        guard !internalID.isEmpty else { return nil }
        let elements = parsedElements()
        let matches = elements.indices.filter {
            elements[$0].tag.emptyNilAttribute(named: "data-og-internal-id") == internalID
        }
        guard matches.count == 1, let targetIndex = matches.first else { return nil }

        let projectResourceRootIndex: Int?
        if isProjectRegisteredResource {
            let bodyIndex = elements.indices.first { elements[$0].tag.tagName == "body" }
            let candidates: [Int]
            if let bodyIndex {
                candidates = elements.indices.filter {
                    elements[$0].parentIndex == bodyIndex
                        && Self.isProjectResourceRootCandidate(elements[$0].tag)
                }
            } else {
                let htmlIndex = elements.indices.first { elements[$0].tag.tagName == "html" }
                candidates = elements.indices.filter { index in
                    guard Self.isProjectResourceRootCandidate(elements[index].tag) else { return false }
                    return elements[index].parentIndex == htmlIndex || elements[index].parentIndex == nil
                }
            }
            projectResourceRootIndex = candidates.count == 1 ? candidates.first : nil
        } else {
            projectResourceRootIndex = nil
        }

        let tag = elements[targetIndex].tag
        return OpenGraphiteHTMLReferenceTarget(
            id: tag.emptyNilAttribute(named: "data-og-id") ?? "",
            internalID: internalID,
            tagName: tag.tagName,
            depth: tag.depth,
            isProjectResourceRoot: targetIndex == projectResourceRootIndex
        )
    }

    /// 論理名（日本語）: 実描画target解決関数
    /// 処理概要: annotation付きwrapperからmedia、SVG、maskの実DOM要素と標準CSS provenanceを解決します。
    ///
    /// - Parameters:
    ///   - id: wrapperの`data-og-internal-id`。
    ///   - companionCSS: source selectorとcascadeを評価する同名CSS文書。
    /// - Returns: wrapperから到達できる実描画target。HTML annotationは追加・変更しません。
    func renderingTargets(
        forNodeID id: String,
        companionCSS: OpenGraphiteCompanionCSSDocument?
    ) -> [OpenGraphiteHTMLRenderingTarget] {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return [] }
        let records = domRecords()
        let matches = records.indices.filter {
            records[$0].tag.attributeValue(named: "data-og-internal-id") == normalizedID
        }
        guard matches.count == 1 else { return [] }
        return renderingTargets(
            forWrapperAt: matches[0],
            records: records,
            cascadeTraces: cascadeTraces(
                for: records,
                sourceDocument: companionCSS.map { OpenGraphiteCSSSourceDocument.parse($0.css) }
            )
        )
    }

    /// 論理名（日本語）: Multi-stylesheet実描画target解決関数
    /// 処理概要: project/linked/embedded/companionを個別ASTのまま合成し、active media込みの実描画target provenanceを返します。
    ///
    /// - Parameters:
    ///   - id: wrapperの`data-og-internal-id`。
    ///   - stylesheetSources: browser document orderの独立stylesheet source。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: wrapperから到達できる実描画target一覧。
    func renderingTargets(
        forNodeID id: String,
        stylesheetSources: [OpenGraphiteCSSStylesheetSource],
        activeMediaQueries: [String] = []
    ) -> [OpenGraphiteHTMLRenderingTarget] {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return [] }
        let records = domRecords()
        let matches = records.indices.filter {
            records[$0].tag.attributeValue(named: "data-og-internal-id") == normalizedID
        }
        guard matches.count == 1 else { return [] }
        return renderingTargets(
            forWrapperAt: matches[0],
            records: records,
            cascadeTraces: cascadeTraces(
                for: records,
                stylesheetSources: stylesheetSources,
                environment: .inspection(activeMediaQueries: activeMediaQueries)
            )
        )
    }

    /// 論理名（日本語）: ノード自身CSS target解決関数
    /// 処理概要: annotation付きnode自身について、標準CSSのsource provenanceと安全な保存先selectorを解決します。
    ///
    /// - Parameters:
    ///   - id: nodeの`data-og-internal-id`。
    ///   - properties: node自身で評価・編集する標準CSS property。
    ///   - companionCSS: source selectorとcascadeを評価する同名CSS文書。
    ///   - activeMediaQueries: 実描画環境でactiveなauthored media条件。
    /// - Returns: nodeが一意に解決できる場合はself target。HTML annotationは追加・変更しません。
    func styleTarget(
        forNodeID id: String,
        properties: [String],
        companionCSS: OpenGraphiteCompanionCSSDocument?,
        activeMediaQueries: [String] = []
    ) -> OpenGraphiteHTMLRenderingTarget? {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !properties.isEmpty else { return nil }
        let records = domRecords()
        let matches = records.indices.filter {
            records[$0].tag.attributeValue(named: "data-og-internal-id") == normalizedID
        }
        guard matches.count == 1 else { return nil }
        let index = matches[0]
        return renderingTarget(
            kind: "self",
            properties: properties,
            targetIndex: index,
            wrapperIndex: index,
            records: records,
            cascadeTraces: cascadeTraces(
                for: records,
                sourceDocument: companionCSS.map { OpenGraphiteCSSSourceDocument.parse($0.css) },
                environment: .inspection(activeMediaQueries: activeMediaQueries)
            )
        )
    }

    /// 論理名（日本語）: Multi-stylesheet node自身CSS target解決関数
    /// 処理概要: 独立stylesheet origin/orderを保持したfull cascadeからnode自身のwinnerと保存先selectorを解決します。
    ///
    /// - Parameters:
    ///   - id: nodeの`data-og-internal-id`。
    ///   - properties: 評価・編集するCSS property。
    ///   - stylesheetSources: browser document orderの独立stylesheet source。
    ///   - activeMediaQueries: 実描画環境でactiveな標準`@media`条件。
    /// - Returns: nodeが一意ならfull winner provenanceを持つself target。
    func styleTarget(
        forNodeID id: String,
        properties: [String],
        stylesheetSources: [OpenGraphiteCSSStylesheetSource],
        activeMediaQueries: [String] = []
    ) -> OpenGraphiteHTMLRenderingTarget? {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !properties.isEmpty else { return nil }
        let records = domRecords()
        let matches = records.indices.filter {
            records[$0].tag.attributeValue(named: "data-og-internal-id") == normalizedID
        }
        guard matches.count == 1 else { return nil }
        let index = matches[0]
        return renderingTarget(
            kind: "self",
            properties: properties,
            targetIndex: index,
            wrapperIndex: index,
            records: records,
            cascadeTraces: cascadeTraces(
                for: records,
                stylesheetSources: stylesheetSources,
                environment: .inspection(activeMediaQueries: activeMediaQueries)
            )
        )
    }

    /// 論理名（日本語）: Inline実描画CSS宣言更新関数
    /// 処理概要: inline styleがcascade winnerの場合に対象value rangeだけを置換し、HTML上unsafeになるunquoted属性だけをquote化して他のtriviaと宣言を保持します。
    ///
    /// - Parameters:
    ///   - property: 更新する標準CSS property。
    ///   - value: CSS値。空の場合は対象declarationだけを削除。
    ///   - target: 解決済み実描画target。
    /// - Returns: 最小差分で更新したHTML mutation。
    func settingInlineRenderingStyleProperty(
        _ property: String,
        value: String,
        target: OpenGraphiteHTMLRenderingTarget
    ) -> OpenGraphiteHTMLMutationResult {
        let normalizedProperty = property.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let declaration = inlineStyleValues(
            for: target.tag,
            properties: [normalizedProperty]
        )[normalizedProperty]
        else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-inline-style-declaration",
                    message: "\(normalizedProperty) のinline source declarationを解決できません。",
                    path: nil,
                    nodeID: nil
                )
            )
        }
        var updatedHTML = html
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedValue.isEmpty {
            updatedHTML.replaceRange(declaration.declarationRange, with: "")
        } else if let styleRange = styleAttributeValueRange(for: target.tag),
                  styleAttributeQuote(for: target.tag, valueRange: styleRange) == nil {
            var rawStyle = html.substring(styleRange)
            let localLower = declaration.valueRange.lowerBound - styleRange.lowerBound
            let localUpper = declaration.valueRange.upperBound - styleRange.lowerBound
            rawStyle.replaceRange(
                localLower..<localUpper,
                with: Self.escapeAdoptionAttributeValue(normalizedValue)
            )
            updatedHTML.replaceRange(
                styleRange,
                with: Self.isSafeUnquotedAttributeValue(rawStyle) ? rawStyle : "\"\(rawStyle)\""
            )
        } else {
            updatedHTML.replaceRange(
                declaration.valueRange,
                with: Self.escapeAdoptionAttributeValue(normalizedValue)
            )
        }
        return OpenGraphiteHTMLMutationResult(html: updatedHTML, diagnostics: [])
    }

    /// 論理名（日本語）: script参照抽出関数
    /// 処理概要: HTML 内の `<script>` 要素から `src`、`type`、inline 本文を抽出します。
    ///
    /// - Returns: DOM 出現順の script 参照一覧。
    func scriptReferences() -> [OpenGraphiteHTMLScriptReference] {
        parsedTags().compactMap { tag in
            guard tag.tagName == "script" else { return nil }
            let content = element(for: tag).map { html.substring($0.contentRange) } ?? ""
            return OpenGraphiteHTMLScriptReference(
                src: tag.emptyNilAttribute(named: "src"),
                type: tag.emptyNilAttribute(named: "type"),
                content: content
            )
        }
    }

    /// 論理名（日本語）: Embedded stylesheet参照抽出関数
    /// 処理概要: HTML parserが認識したactual `<style>` element本文だけを抽出し、commentやscript内の見かけ上のtagを除外します。
    ///
    /// - Returns: DOM出現順のembedded stylesheet参照一覧。
    func embeddedStylesheetReferences() -> [OpenGraphiteHTMLEmbeddedStylesheetReference] {
        parsedTags().compactMap { tag in
            guard isCSSEmbeddedStyleTag(tag), let element = element(for: tag) else { return nil }
            return OpenGraphiteHTMLEmbeddedStylesheetReference(
                content: html.substring(element.contentRange)
            )
        }
    }

    /// 論理名（日本語）: Authored CSS owner ID索引関数
    /// 処理概要: actual CSS style/link elementのIDを返し、runtimeのCSSOM origin判定に使います。
    func authoredCSSOwnerIDs() -> Set<String> {
        Set(parsedTags().compactMap { tag in
            guard isCSSEmbeddedStyleTag(tag) || isCSSStylesheetLinkTag(tag) else { return nil }
            guard let id = tag.attributeValue(named: "id"), !id.isEmpty else { return nil }
            return id
        })
    }

    /// 論理名（日本語）: Authored embedded style ID索引関数
    /// 処理概要: actual CSS style elementのIDを返し、runtimeの本文observerとsource mutationを結び付けます。
    func authoredStyleElementIDs() -> Set<String> {
        Set(parsedTags().compactMap { tag in
            guard isCSSEmbeddedStyleTag(tag) else { return nil }
            guard let id = tag.attributeValue(named: "id"), !id.isEmpty else { return nil }
            return id
        })
    }

    /// 論理名（日本語）: CSS style element判定関数
    /// 処理概要: `type`省略・空値・`text/css`だけをCSS sourceとして扱い、別MIME type本文はopaqueに保持します。
    func isCSSEmbeddedStyleTag(_ tag: OpenGraphiteHTMLTag) -> Bool {
        guard tag.tagName == "style" else { return false }
        guard let type = tag.attributeValue(named: "type") else { return true }
        return type.isEmpty || Self.asciiLowercased(type) == "text/css"
    }

    /// 論理名（日本語）: CSS stylesheet link判定関数
    /// 処理概要: `rel~=stylesheet`かつtype省略・空値・`text/css`のlinkだけをauthored CSS dependencyとして扱います。
    func isCSSStylesheetLinkTag(_ tag: OpenGraphiteHTMLTag) -> Bool {
        guard tag.tagName == "link" else { return false }
        let relations = Set(Self.asciiWhitespaceSeparatedTokens(tag.attributeValue(named: "rel") ?? ""))
        guard relations.contains("stylesheet") else { return false }
        guard let type = tag.attributeValue(named: "type") else { return true }
        let normalized = Self.mimeEssence(type)
        return normalized == "text/css"
    }

    /// 論理名（日本語）: Executable script判定関数
    /// 処理概要: classic JavaScript MIMEと`module`だけをruntime sourceとして扱い、JSON/JSON-LD/importmap/speculationrules data blockを除外します。
    func isExecutableScriptTag(_ tag: OpenGraphiteHTMLTag) -> Bool {
        guard tag.tagName == "script" else { return false }
        let normalized: String
        if let type = tag.attributeValue(named: "type") {
            if type.isEmpty { return true }
            let rawType = Self.asciiLowercased(type)
            if rawType == "module" { return true }
            normalized = rawType
        } else if let language = tag.attributeValue(named: "language"), !language.isEmpty {
            normalized = Self.asciiLowercased("text/\(language)")
        } else {
            return true
        }
        return [
            "text/javascript", "application/javascript", "text/ecmascript", "application/ecmascript",
            "application/x-javascript", "application/x-ecmascript", "text/jscript", "text/livescript",
            "text/javascript1.0", "text/javascript1.1", "text/javascript1.2", "text/javascript1.3",
            "text/javascript1.4", "text/javascript1.5", "text/x-ecmascript", "text/x-javascript"
        ].contains(normalized)
    }

    private static func mimeEssence(_ value: String) -> String {
        let prefix = value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]
        return asciiLowercased(trimmingHTTPWhitespace(String(prefix)))
    }

    private static func asciiLowercased(_ value: String) -> String {
        String(decoding: value.utf8.map { byte in
            (65...90).contains(byte) ? byte + 32 : byte
        }, as: UTF8.self)
    }

    fileprivate static func trimmingASCIIWhitespace(_ value: String) -> String {
        let bytes = Array(value.utf8)
        var lower = 0
        var upper = bytes.count
        while lower < upper, isASCIIWhitespace(bytes[lower]) { lower += 1 }
        while upper > lower, isASCIIWhitespace(bytes[upper - 1]) { upper -= 1 }
        return String(decoding: bytes[lower..<upper], as: UTF8.self)
    }

    private static func trimmingHTTPWhitespace(_ value: String) -> String {
        let bytes = Array(value.utf8)
        var lower = 0
        var upper = bytes.count
        while lower < upper, isHTTPWhitespace(bytes[lower]) { lower += 1 }
        while upper > lower, isHTTPWhitespace(bytes[upper - 1]) { upper -= 1 }
        return String(decoding: bytes[lower..<upper], as: UTF8.self)
    }

    private static func asciiWhitespaceSeparatedTokens(_ value: String) -> [String] {
        value.utf8.split(whereSeparator: isASCIIWhitespace).map {
            asciiLowercased(String(decoding: $0, as: UTF8.self))
        }
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x09 || byte == 0x0A || byte == 0x0C || byte == 0x0D || byte == 0x20
    }

    private static func isHTTPWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x20
    }

    private static func isASCIIAlpha(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else { return false }
        return (0x41...0x5A).contains(value) || (0x61...0x7A).contains(value)
    }

    /// 論理名（日本語）: HTML ASCII whitespace判定関数
    /// 処理概要: tag/attribute microsyntaxでdelimiterとなる5種類のASCII whitespaceだけを判定します。
    fileprivate static func isHTMLASCIIWhitespace(_ character: Character) -> Bool {
        !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x09 || scalar.value == 0x0A || scalar.value == 0x0C
                || scalar.value == 0x0D || scalar.value == 0x20
        }
    }

    private static func isCSSASCIIWhitespace(_ character: Character) -> Bool {
        isHTMLASCIIWhitespace(character)
    }

    private static func isECMAScriptWhitespace(_ character: Character) -> Bool {
        character.isWhitespace || character.unicodeScalars.allSatisfy { $0.value == 0xFEFF }
    }

    /// 論理名（日本語）: text binding resource抽出関数
    /// 処理概要: `data-i18n-key` を持つ要素本文と HTML 同梱 locale variant を locale JSON へ移行できる形で抽出します。
    ///
    /// - Returns: i18n key ごとの fallback / variant 値一覧。
    func textBindingResources() -> [OpenGraphiteHTMLTextBindingResource] {
        parsedTags().compactMap { tag in
            guard let key = tag.emptyNilAttribute(named: "data-i18n-key"),
                  let element = element(for: tag)
            else {
                return nil
            }
            let variants = tag.attributes.reduce(into: [String: String]()) { result, attribute in
                let prefix = "data-og-text-variant-"
                let normalizedName = attribute.name.lowercased()
                guard normalizedName.hasPrefix(prefix) else { return }
                let locale = String(normalizedName.dropFirst(prefix.count))
                guard !locale.isEmpty else { return }
                if result[locale] == nil {
                    result[locale] = attribute.value
                }
            }
            return OpenGraphiteHTMLTextBindingResource(
                key: key,
                fallbackHTML: html.substring(element.contentRange),
                variants: variants
            )
        }
    }

    /// 論理名（日本語）: Node明示adoption関数
    /// 処理概要: stable/session referenceまたは公開locatorで一意に解決したnode/subtreeへidentity属性だけを最小差分追加します。
    ///
    /// - Parameters:
    ///   - reference: dry-runではgraphが返したstable/session reference、applyではdry-runが返したproposal reference。
    ///   - selector: locatorが返した一意なstandard ID / annotation selector。
    ///   - domPath: locatorが返した決定的DOM path。
    ///   - scope: 対象nodeだけ、またはsubtree全体。
    ///   - displayID: targetへ明示する`data-og-id`候補。未指定時は既存の安全なselectorを再利用し、必要な場合だけdisplay annotationを生成。
    ///   - documentURL: stale guardとcandidate graphに使うdocument URL。
    /// - Returns: source mutation、apply専用proposal target reference、adopt対象DOM path。読み取りだけではsourceを変更しません。
    func adoptingNode(
        reference: String?,
        selector: String?,
        domPath: String?,
        scope: OpenGraphiteNodeAdoptionScope,
        displayID: String?,
        documentURL: String
    ) -> (mutation: OpenGraphiteHTMLMutationResult, targetReference: String, adoptedDomPaths: [String]) {
        let normalizedReference = reference?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSelector = selector?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDOMPath = domPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let providedTargets = [normalizedReference, normalizedSelector, normalizedDOMPath]
            .compactMap { value in value.flatMap { $0.isEmpty ? nil : $0 } }
        guard providedTargets.count == 1 else {
            return (
                .failure(
                    html: html,
                    diagnostic: OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "invalid-adoption-target",
                        message: "adopt targetはreference、selector、domPathのいずれか1つで指定してください。",
                        path: nil,
                        nodeID: nil
                    )
                ),
                providedTargets.first ?? "",
                []
            )
        }

        let requestedDisplayID = displayID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayID != nil, requestedDisplayID?.isEmpty != false {
            return (
                .failure(
                    html: html,
                    diagnostic: OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "invalid-adoption-display-id",
                        message: "--display-idには空でない値が必要です。",
                        path: nil,
                        nodeID: nil
                    )
                ),
                providedTargets[0],
                []
            )
        }

        let records = domRecords()
        let nodes = nodes(documentURL: documentURL)
        let snapshotReferences = nodes.map { revisionScopedReference(locator: $0.locator) }
        let proposalReferences = nodes.map {
            adoptionProposalReference(
                locator: $0.locator,
                scope: scope,
                displayID: requestedDisplayID
            )
        }
        let matches: [Int]
        if let normalizedReference, !normalizedReference.isEmpty {
            if normalizedReference.hasPrefix("ogref-session:adoption:") {
                matches = proposalReferences.indices.filter { proposalReferences[$0] == normalizedReference }
            } else if normalizedReference.hasPrefix("ogref-session:node:") {
                matches = snapshotReferences.indices.filter { snapshotReferences[$0] == normalizedReference }
            } else if let internalID = OpenGraphiteReferenceID.nodeInternalID(from: normalizedReference) {
                matches = nodes.indices.filter { nodes[$0].internalID == internalID }
            } else {
                matches = nodes.indices.filter { nodes[$0].reference == normalizedReference }
            }
        } else if let normalizedSelector, !normalizedSelector.isEmpty {
            matches = nodes.indices.filter { nodes[$0].locator.selector == normalizedSelector }
        } else {
            matches = nodes.indices.filter { nodes[$0].locator.domPath == normalizedDOMPath }
        }

        guard matches.count == 1 else {
            let isAdoptionProposal = normalizedReference?.hasPrefix("ogref-session:adoption:") == true
            let isStaleReference = normalizedReference?.hasPrefix("ogref-session:") == true
            let diagnostic = OpenGraphiteDiagnostic(
                severity: .error,
                code: isAdoptionProposal
                    ? "stale-adoption-proposal"
                    : (isStaleReference ? "stale-node-reference" : (matches.isEmpty ? "missing-adoption-target" : "ambiguous-adoption-target")),
                message: isAdoptionProposal
                    ? "adoption proposalは現在のdocument/sourceまたはscope/display IDと一致しません。dry-runを再実行してください。"
                    : (isStaleReference
                        ? "session node referenceは現在のsource range/content hashと一致しません。graphを再取得してください。"
                        : "adopt targetを一意に解決できません。"),
                path: nil,
                nodeID: nil
            )
            return (.failure(html: html, diagnostic: diagnostic), providedTargets[0], [])
        }

        let targetIndex = matches[0]
        var selectedIndices = [targetIndex]
        if scope == .subtree {
            selectedIndices = records.indices.filter { index in
                index == targetIndex || isDescendant(index, of: targetIndex, records: records)
            }
        }

        if let unsafeIndex = selectedIndices.first(where: { index in
            records[index].tag.containsUnresolvedHTMLCharacterReference(
                named: "data-og-internal-id"
            )
        }) {
            let unsafeTag = records[unsafeIndex].tag
            return (
                .failure(
                    html: html,
                    diagnostic: OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unresolved-data-og-internal-id-character-reference",
                        message: "data-og-internal-idにsemantic valueを確定できないHTML character referenceがあります。既存参照を保護するためadoptを中止しました。",
                        path: nil,
                        nodeID: unsafeTag.emptyNilAttribute(named: "data-og-id")
                    )
                ),
                providedTargets[0],
                []
            )
        }

        var usedDisplayIDs = Set(records.compactMap { $0.tag.emptyNilAttribute(named: "data-og-id") })
        var usedInternalIDs = Set(records.compactMap { $0.tag.emptyNilAttribute(named: "data-og-internal-id") })
        if let requestedDisplayID,
           records.indices.contains(targetIndex),
           records[targetIndex].tag.emptyNilAttribute(named: "data-og-id") == nil,
           usedDisplayIDs.contains(requestedDisplayID) {
            return (
                .failure(
                    html: html,
                    diagnostic: OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "duplicate-data-og-id",
                        message: "data-og-id \"\(requestedDisplayID)\" は既に存在します。",
                        path: nil,
                        nodeID: requestedDisplayID
                    )
                ),
                providedTargets[0],
                []
            )
        }

        var additionsByIndex: [Int: [(name: String, value: String)]] = [:]
        for index in selectedIndices {
            let record = records[index]
            var additions: [(name: String, value: String)] = []
            let preferred = index == targetIndex ? requestedDisplayID : nil
            let existingInternalID = record.tag.emptyNilAttribute(named: "data-og-internal-id")
            let hasStableInternalID = existingInternalID != nil
            let reusesSafeAuthoredSelector = preferred == nil
                && (uniqueStandardIDSelector(for: index, records: records) != nil
                    || uniqueAuthoredSelector(for: index, records: records) != nil)
            let shouldAddDisplayID = preferred != nil || (!hasStableInternalID && !reusesSafeAuthoredSelector)
            if record.tag.emptyNilAttribute(named: "data-og-id") == nil, shouldAddDisplayID {
                let base = preferred ?? "\(record.tag.tagName)-\(nodes[index].locator.contentHash.prefix(7))"
                let generatedID = Self.uniqueAdoptionID(base: base, used: &usedDisplayIDs)
                additions.append(("data-og-id", generatedID))
            }
            if existingInternalID == nil {
                let seed = "adopt|\(documentURL)|\(nodes[index].locator.domPath)|\(nodes[index].locator.contentHash)"
                let internalID = Self.uniqueOpaqueInternalID(seed: seed, used: &usedInternalIDs)
                additions.append(("data-og-internal-id", internalID))
            }
            if !additions.isEmpty {
                additionsByIndex[index] = additions
            }
        }

        var updatedHTML = html
        for index in selectedIndices.reversed() {
            guard let additions = additionsByIndex[index] else { continue }
            Self.insertAttributes(additions, into: &updatedHTML, tag: records[index].tag)
        }
        return (
            OpenGraphiteHTMLMutationResult(html: updatedHTML, diagnostics: []),
            proposalReferences[targetIndex],
            selectedIndices.map { nodes[$0].locator.domPath }
        )
    }

    /// 論理名（日本語）: ノードHTML抽出関数
    /// 処理概要: 一意な `data-og-internal-id` を持つ node subtree の HTML 断片を返します。
    ///
    /// - Parameter id: 対象ノードの `data-og-internal-id`。
    /// - Returns: 対象 node の HTML。見つからない、または重複している場合は `nil`。
    func elementHTML(forNodeID id: String) -> String? {
        guard let element = uniqueElement(forNodeID: id).element else { return nil }
        return html.substring(element.fullRange)
    }

    /// 論理名（日本語）: ノードHTMLハッシュ生成関数
    /// 処理概要: 一意な `data-og-internal-id` を持つ node subtree の安定 hash を返します。
    ///
    /// - Parameter id: 対象ノードの `data-og-internal-id`。
    /// - Returns: 対象 node の HTML hash。見つからない、または重複している場合は `nil`。
    func elementHTMLHash(forNodeID id: String) -> String? {
        elementHTML(forNodeID: id).map(Self.contentHash)
    }

    /// 論理名（日本語）: 内容ハッシュ生成関数
    /// 処理概要: HTML 断片や文字列の比較用に、プロセスに依存しない短い hash を返します。
    ///
    /// - Parameter value: hash 化する文字列。
    /// - Returns: FNV-1a ベースの安定 hash。
    static func contentHash(_ value: String) -> String {
        String(stableHash(value), radix: 36)
    }

    /// 論理名（日本語）: Legacy HTML Web契約明示移行関数
    /// 処理概要: known `data-og-*`をASCII case-insensitiveに解釈し、開始tag全体を再serializeせず標準属性とversioned classへ移します。
    ///
    /// - Parameter path: diagnosticsへ記録するproject相対path。
    /// - Returns: unrelated属性、quote、entity、comment、triviaを保持したcandidate。
    func migratingLegacyWebContract(path: String) -> OpenGraphiteLegacyHTMLMigrationResult {
        let typeValues: Set<String> = ["frame", "page", "text", "button", "image", "icon"]
        let layoutValues: Set<String> = ["vertical", "horizontal", "absolute"]
        let identityAttributes: Set<String> = [
            "data-og-id", "data-og-internal-id", "data-og-locked", "data-og-component",
            "data-og-icon-source", "data-og-icon-library", "data-og-icon-name",
            "data-og-text-source", "data-og-text-field", "data-og-lang-source",
            "data-og-lang-field", "data-og-dir-source", "data-og-dir-field",
            "data-og-source-component-internal-id", "data-og-source-node-internal-id",
            "data-i18n-key"
        ]
        let knownLegacyAttributes: Set<String> = [
            "data-og-type", "data-og-layout", "data-og-hidden", "data-og-icon-mask",
            "data-og-variant", "data-og-slot", "data-og-part", "data-og-state-hidden",
            "data-og-state-visible", "data-og-placement-mode", "data-og-component-kind",
            "data-og-role"
        ]
        let runtimeExactAttributes: Set<String> = [
            "data-og-selected", "data-og-editing", "data-og-editor-focus-", "data-og-dragging",
            "data-og-reorder-", "data-og-frame-", "data-og-editor-artifact", "data-og-expanded",
            "data-og-generated", "data-og-component-error", "data-og-host-id",
            "data-og-instance-source", "data-og-source-id", "data-og-source-component",
            "data-og-source-instance", "data-og-source-placement", "data-og-slot-origin",
            "data-og-preview-clone", "data-og-placement-generated", "data-og-preview-locale",
            "data-og-preview-dir", "data-og-runtime-fallback-html", "data-og-overlay-label-position",
            "data-og-placement-label"
        ]
        let runtimeAttributePrefixes = ["data-og-editor-focus-", "data-og-reorder-", "data-og-frame-"]
        let runtimeAttributes = runtimeExactAttributes.subtracting(runtimeAttributePrefixes)
        func isRuntimeAttribute(_ name: String) -> Bool {
            runtimeAttributes.contains(name) || runtimeAttributePrefixes.contains { name.hasPrefix($0) }
        }
        let tags = parsedTags()
        let authoredStyleIDs: Set<String> = Set(tags.compactMap { tag -> String? in
            guard isCSSEmbeddedStyleTag(tag), let id = tag.attributeValue(named: "id"), !id.isEmpty else {
                return nil
            }
            return id
        })
        let authoredCSSOwnerIDs: Set<String> = Set(tags.compactMap { tag -> String? in
            guard isCSSEmbeddedStyleTag(tag) || isCSSStylesheetLinkTag(tag),
                  let id = tag.attributeValue(named: "id"), !id.isEmpty
            else { return nil }
            return id
        })
        var diagnostics: [OpenGraphiteDiagnostic] = []
        var types: Set<String> = []
        var layouts: Set<String> = []
        var generatedClasses: Set<String> = []
        var existingClasses: Set<String> = []
        var removedLegacyDatasetAttributeNames: Set<String> = []
        var generatedDestinationAttributes: Set<String> = []
        var observedDestinationAttributes: Set<String> = []
        var hasWholeDatasetRuntimeObserver = false
        var hasGeneratedClassObserver = false
        var hasGeneratedCustomPropertyStyleObserver = false
        var hasGeneratedCustomPropertyRuntimeObserver = false
        var hasWholeStyleRuntimeObserver = false
        var hasWholeAttributeRuntimeObserver = false
        var hasWholeMarkupRuntimeObserver = false
        var hasCSSOMRuntimeObserver = false
        var hasStyleTextRuntimeObserver = false
        var hasPreviewContextRuntimeObserver = false
        var observedPreviewHostFields: Set<String> = []
        var hasDynamicSelectorRuntimeObserver = false
        var hasAttributeNodeRuntimeObserver = false
        var authoredCustomPropertyNames: Set<String> = []
        var generatedCustomPropertyNames: Set<String> = []
        var hasUnsupportedRuntimeDependency = false
        var detectedLegacy = false
        var inlineStyleCandidates: [Int: (range: Range<Int>, source: String)] = [:]
        var embeddedStyleCandidates: [Int: (range: Range<Int>, source: String)] = [:]

        func appendCSSDiagnostics(
            _ migration: OpenGraphiteLegacyCSSMigrationResult,
            nodeID: String?
        ) {
            generatedClasses.formUnion(migration.generatedClassNames)
            existingClasses.formUnion(migration.existingGeneratedClassNames)
            observedDestinationAttributes.formUnion(migration.observedDestinationAttributes)
            hasGeneratedClassObserver = hasGeneratedClassObserver || migration.hasGeneratedClassObserver
            hasGeneratedCustomPropertyStyleObserver = hasGeneratedCustomPropertyStyleObserver
                || migration.hasGeneratedCustomPropertyStyleObserver
            authoredCustomPropertyNames.formUnion(migration.authoredCustomPropertyNames)
            generatedCustomPropertyNames.formUnion(migration.generatedCustomPropertyNames)
            for property in migration.unknownReservedProperties {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unknown-legacy-css-property",
                    message: "mapping catalogにないreserved custom property \(property) は移行できません。",
                    path: path,
                    nodeID: nodeID
                ))
            }
            for construct in migration.unsupportedLegacyConstructs {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-css-construct",
                    message: "losslessに変換できないlegacy CSS構文です: \(construct)",
                    path: path,
                    nodeID: nodeID
                ))
            }
            for destination in migration.destinationConflicts {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "legacy-css-destination-conflict",
                    message: "legacy custom propertyの移行先 \(destination) がauthored declarationと競合します。",
                    path: path,
                    nodeID: nodeID
                ))
            }
        }

        for tag in tags {
            existingClasses.formUnion(classTokens(tag.attributeValue(named: "class") ?? ""))
            let grouped = Dictionary(grouping: tag.attributes) { $0.name.lowercased() }
            for (name, attributes) in grouped where attributes.count > 1 && knownLegacyAttributes.contains(name) {
                detectedLegacy = true
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "ambiguous-legacy-html-attribute",
                    message: "ASCII caseだけが異なる重複legacy属性 \(name) は安全に移行できません。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            for attribute in tag.attributes {
                let name = attribute.name.lowercased()
                if knownLegacyAttributes.contains(name)
                    || (!identityAttributes.contains(name)
                        && isRuntimeAttribute(name)) {
                    detectedLegacy = true
                }
                if !identityAttributes.contains(name), isRuntimeAttribute(name) {
                    removedLegacyDatasetAttributeNames.insert(name)
                }
                if name == "style", let styleRange = styleAttributeValueRange(for: tag) {
                    let authoredStyle = html.substring(styleRange)
                    let semanticDeclarations = inlineStyleValueList(for: tag)
                    let authoredProperties = Set(semanticDeclarations.map(\.property))
                    var semanticStyle = authoredStyle
                    var semanticPatches: [(range: Range<Int>, value: String)] = []
                    var semanticDetectedLegacy = false
                    for declaration in semanticDeclarations {
                        let rawProperty = html.substring(declaration.propertyRange)
                        guard rawProperty.contains("&"), rawProperty != declaration.property else { continue }
                        if let destination = OpenGraphiteLegacyCSSMigrator.migrationDestinationName(
                            for: declaration.property
                        ) {
                            semanticDetectedLegacy = true
                            generatedCustomPropertyNames.insert(destination)
                            if authoredProperties.contains(destination) {
                                diagnostics.append(OpenGraphiteDiagnostic(
                                    severity: .error,
                                    code: "legacy-css-destination-conflict",
                                    message: "legacy custom propertyの移行先 \(destination) がauthored declarationと競合します。",
                                    path: path,
                                    nodeID: tag.attributeValue(named: "data-og-id")
                                ))
                            }
                            let localPropertyLower = declaration.propertyRange.lowerBound
                                - styleRange.lowerBound
                            let localPropertyUpper = declaration.propertyRange.upperBound
                                - styleRange.lowerBound
                            let localPropertyRange = localPropertyLower..<localPropertyUpper
                            semanticPatches.append((localPropertyRange, destination))
                        } else if OpenGraphiteLegacyCSSMigrator.isLegacyReservedName(declaration.property) {
                            semanticDetectedLegacy = true
                            diagnostics.append(OpenGraphiteDiagnostic(
                                severity: .error,
                                code: "unknown-legacy-css-property",
                                message: "mapping catalogにないreserved custom property \(declaration.property) は移行できません。",
                                path: path,
                                nodeID: tag.attributeValue(named: "data-og-id")
                            ))
                        }
                    }
                    for patch in semanticPatches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
                        semanticStyle.replaceRange(patch.range, with: patch.value)
                    }
                    let migration = OpenGraphiteLegacyCSSMigrator.migrateDeclarationList(semanticStyle)
                    detectedLegacy = detectedLegacy || migration.detectedLegacy || semanticDetectedLegacy
                    appendCSSDiagnostics(migration, nodeID: tag.attributeValue(named: "data-og-id"))
                    if containsReservedCustomPropertyToken(attribute.value),
                       !migration.detectedLegacy, !semanticDetectedLegacy {
                        detectedLegacy = true
                        diagnostics.append(OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "unsupported-legacy-inline-style",
                            message: "HTML character referenceを介したlegacy inline CSSはraw rangeへ安全に対応付けできません。",
                            path: path,
                            nodeID: tag.attributeValue(named: "data-og-id")
                        ))
                    }
                    if migration.source != authoredStyle {
                        inlineStyleCandidates[tag.range.lowerBound] = (styleRange, migration.source)
                    }
                }
                if name.hasPrefix("on"), name.count > 2,
                   containsLegacyRuntimeJavaScript(attribute.value) {
                    detectedLegacy = true
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-runtime-source",
                        message: "inline event handlerがlegacy Web契約をread/writeしています。standard hookへ更新してから移行してください。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                }
                if name.hasPrefix("on"), name.count > 2 {
                    hasWholeDatasetRuntimeObserver = hasWholeDatasetRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasWholeDatasetObserver(attribute.value)
                    observedDestinationAttributes.formUnion(
                        OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(attribute.value)
                    )
                    hasGeneratedClassObserver = hasGeneratedClassObserver
                        || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver(attribute.value)
                    hasGeneratedCustomPropertyRuntimeObserver = hasGeneratedCustomPropertyRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedCustomPropertyObserver(attribute.value)
                    hasWholeStyleRuntimeObserver = hasWholeStyleRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasWholeStyleObserver(attribute.value)
                    hasWholeAttributeRuntimeObserver = hasWholeAttributeRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(attribute.value)
                    hasWholeMarkupRuntimeObserver = hasWholeMarkupRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasWholeMarkupObserver(attribute.value)
                    hasCSSOMRuntimeObserver = hasCSSOMRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(
                            attribute.value,
                            authoredCSSOwnerIDs: authoredCSSOwnerIDs
                        )
                    hasStyleTextRuntimeObserver = hasStyleTextRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
                            attribute.value,
                            authoredStyleIDs: authoredStyleIDs
                        )
                    hasPreviewContextRuntimeObserver = hasPreviewContextRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(attribute.value)
                    observedPreviewHostFields.formUnion(
                        OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(attribute.value)
                    )
                    hasDynamicSelectorRuntimeObserver = hasDynamicSelectorRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasDynamicSelectorObserver(attribute.value)
                    hasAttributeNodeRuntimeObserver = hasAttributeNodeRuntimeObserver
                        || OpenGraphiteLegacyJavaScriptInspector.hasAttributeNodeObserver(attribute.value)
                }
                // Catalog外のdata-*（data-og-*を含む）はownershipを推測せずraw bytesのまま保持します。
            }
            if isCSSEmbeddedStyleTag(tag), let element = element(for: tag) {
                let authoredCSS = html.substring(element.contentRange)
                let migration = OpenGraphiteLegacyCSSMigrator.migrate(authoredCSS)
                detectedLegacy = detectedLegacy || migration.detectedLegacy
                appendCSSDiagnostics(migration, nodeID: tag.attributeValue(named: "data-og-id"))
                if migration.source != authoredCSS {
                    embeddedStyleCandidates[tag.range.lowerBound] = (element.contentRange, migration.source)
                }
            }
            if isExecutableScriptTag(tag), let element = element(for: tag) {
                let script = html.substring(element.contentRange)
                hasUnsupportedRuntimeDependency = hasUnsupportedRuntimeDependency
                    || containsLocalRuntimeDependency(script)
                if containsLegacyRuntimeJavaScript(script) {
                    detectedLegacy = true
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-runtime-source",
                        message: "embedded scriptがlegacy Web契約をread/writeしています。standard hookへ更新してから移行してください。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                }
                hasGeneratedClassObserver = hasGeneratedClassObserver
                    || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedClassObserver(script)
                hasWholeDatasetRuntimeObserver = hasWholeDatasetRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeDatasetObserver(script)
                observedDestinationAttributes.formUnion(
                    OpenGraphiteLegacyJavaScriptInspector.observedGeneratedDestinationAttributes(script)
                )
                hasGeneratedCustomPropertyRuntimeObserver = hasGeneratedCustomPropertyRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.containsGeneratedCustomPropertyObserver(script)
                hasWholeStyleRuntimeObserver = hasWholeStyleRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeStyleObserver(script)
                hasWholeAttributeRuntimeObserver = hasWholeAttributeRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeAttributeObserver(script)
                hasWholeMarkupRuntimeObserver = hasWholeMarkupRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasWholeMarkupObserver(script)
                hasCSSOMRuntimeObserver = hasCSSOMRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasCSSOMObserver(
                        script,
                        authoredCSSOwnerIDs: authoredCSSOwnerIDs
                    )
                hasStyleTextRuntimeObserver = hasStyleTextRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasStyleTextObserver(
                        script,
                        authoredStyleIDs: authoredStyleIDs
                    )
                hasPreviewContextRuntimeObserver = hasPreviewContextRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasPreviewContextObserver(script)
                observedPreviewHostFields.formUnion(
                    OpenGraphiteLegacyJavaScriptInspector.observedPreviewHostFields(script)
                )
                hasDynamicSelectorRuntimeObserver = hasDynamicSelectorRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasDynamicSelectorObserver(script)
                hasAttributeNodeRuntimeObserver = hasAttributeNodeRuntimeObserver
                    || OpenGraphiteLegacyJavaScriptInspector.hasAttributeNodeObserver(script)
            }
            if let authoredValue = tag.attributeValue(named: "data-og-type") {
                let value = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredValue))
                if typeValues.contains(value) {
                    types.insert(value)
                    generatedClasses.insert("og-migrated-v1-type-\(value)")
                    removedLegacyDatasetAttributeNames.insert("data-og-type")
                } else {
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-data-og-type",
                        message: "data-og-type=\(value) の決定的mappingはありません。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                }
            }
            if let authoredValue = tag.attributeValue(named: "data-og-layout") {
                let value = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredValue))
                if layoutValues.contains(value) {
                    layouts.insert(value)
                    generatedClasses.insert("og-migrated-v1-layout-\(value)")
                    removedLegacyDatasetAttributeNames.insert("data-og-layout")
                } else {
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-data-og-layout",
                        message: "data-og-layout=\(value) の決定的mappingはありません。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                }
            }
            if let value = tag.attributeValue(named: "data-og-hidden") {
                let normalized = Self.asciiLowercased(Self.trimmingASCIIWhitespace(value))
                guard ["true", "false"].contains(normalized) else {
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-boolean-value",
                        message: "data-og-hidden=\(value) はtrue/falseだけを移行できます。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                    continue
                }
                removedLegacyDatasetAttributeNames.insert("data-og-hidden")
                if normalized == "false", tag.attributes.contains(where: { $0.name.lowercased() == "hidden" }) {
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "legacy-html-destination-conflict",
                        message: "data-og-hidden=falseと既存hidden属性が競合します。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                } else if normalized == "true", let existingHidden = tag.attributeValue(named: "hidden") {
                    let existingSemantic = Self.asciiLowercased(existingHidden)
                    if existingSemantic == "until-found" {
                        diagnostics.append(OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "legacy-html-destination-conflict",
                            message: "data-og-hidden=trueと既存hidden=\(existingHidden)が競合します。",
                            path: path,
                            nodeID: tag.attributeValue(named: "data-og-id")
                        ))
                    }
                } else if normalized == "true",
                          !tag.attributes.contains(where: { $0.name.lowercased() == "hidden" }) {
                    generatedDestinationAttributes.insert("hidden")
                }
            }
            if let value = tag.attributeValue(named: "data-og-icon-mask") {
                let normalized = Self.asciiLowercased(Self.trimmingASCIIWhitespace(value))
                if !["true", "false"].contains(normalized) {
                    diagnostics.append(OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unsupported-legacy-boolean-value",
                        message: "data-og-icon-mask=\(value) はtrue/falseだけを移行できます。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    ))
                } else {
                    removedLegacyDatasetAttributeNames.insert("data-og-icon-mask")
                }
            }
            for (legacy, standard) in [("data-og-variant", "variant"), ("data-og-part", "part")] {
                guard let legacyValue = tag.attributeValue(named: legacy) else { continue }
                removedLegacyDatasetAttributeNames.insert(legacy)
                if let standardValue = tag.attributeValue(named: standard) {
                    let legacyTokens = legacyValue.split(whereSeparator: Self.isHTMLASCIIWhitespace).map(String.init)
                    let standardTokens = standardValue.split(whereSeparator: Self.isHTMLASCIIWhitespace).map(String.init)
                    if legacyTokens != standardTokens {
                        diagnostics.append(OpenGraphiteDiagnostic(
                            severity: .error,
                            code: "legacy-html-destination-conflict",
                            message: "\(legacy)と既存\(standard)属性が競合します。",
                            path: path,
                            nodeID: tag.attributeValue(named: "data-og-id")
                        ))
                    }
                } else {
                    generatedDestinationAttributes.insert(standard)
                }
            }
            if tag.attributeValue(named: "data-og-slot") != nil {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-component-slot",
                    message: "data-og-slotはcomponent masterのfallbackをstandard <slot name>構造へ変換する必要があります。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            for attributeName in ["data-og-state-hidden", "data-og-state-visible"] {
                guard let value = tag.attributeValue(named: attributeName) else { continue }
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-component-state",
                    message: "\(attributeName)=\(value) はstandard host variant scopeを一意に確定できません。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            if let value = tag.attributeValue(named: "data-og-placement-mode") {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-placement-context",
                    message: "data-og-placement-mode=\(value) はmanifest placementMocksとの参照対応を確定できません。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            if let value = tag.attributeValue(named: "data-og-component-kind"), value.lowercased() != "master" {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-component-kind",
                    message: "data-og-component-kind=\(value) は未対応です。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            if tag.attributeValue(named: "data-og-component-kind") != nil {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-component-structure",
                    message: "legacy component masterはtemplate/slot構造を一意に確認してから移行する必要があります。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            }
            if let role = tag.attributeValue(named: "data-og-role"),
               role.lowercased() != "component-placement" || tag.tagName.lowercased() != "og-placement" {
                diagnostics.append(OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-legacy-data-og-role",
                    message: "data-og-role=\(role) はog-placement hostだけで冗長annotationとして除去できます。",
                    path: path,
                    nodeID: tag.attributeValue(named: "data-og-id")
                ))
            } else if tag.attributeValue(named: "data-og-role") != nil {
                removedLegacyDatasetAttributeNames.insert("data-og-role")
            }
        }
        guard diagnostics.isEmpty else {
            return OpenGraphiteLegacyHTMLMigrationResult(
                source: html,
                detectedLegacy: detectedLegacy,
                types: types,
                layouts: layouts,
                generatedClassNames: generatedClasses,
                existingClassNames: existingClasses,
                removedLegacyDatasetAttributeNames: removedLegacyDatasetAttributeNames,
                generatedDestinationAttributes: generatedDestinationAttributes,
                observedDestinationAttributes: observedDestinationAttributes,
                hasWholeDatasetRuntimeObserver: hasWholeDatasetRuntimeObserver,
                hasGeneratedClassObserver: hasGeneratedClassObserver,
                hasGeneratedCustomPropertyStyleObserver: hasGeneratedCustomPropertyStyleObserver,
                hasGeneratedCustomPropertyRuntimeObserver: hasGeneratedCustomPropertyRuntimeObserver,
                hasWholeStyleRuntimeObserver: hasWholeStyleRuntimeObserver,
                hasInlineStyleMutation: !inlineStyleCandidates.isEmpty,
                hasHTMLSourceMutation: false,
                hasHTMLAttributeMutation: false,
                hasEmbeddedStyleMutation: false,
                hasWholeAttributeRuntimeObserver: hasWholeAttributeRuntimeObserver,
                hasWholeMarkupRuntimeObserver: hasWholeMarkupRuntimeObserver,
                hasCSSOMRuntimeObserver: hasCSSOMRuntimeObserver,
                hasStyleTextRuntimeObserver: hasStyleTextRuntimeObserver,
                hasPreviewContextRuntimeObserver: hasPreviewContextRuntimeObserver,
                observedPreviewHostFields: observedPreviewHostFields,
                hasDynamicSelectorRuntimeObserver: hasDynamicSelectorRuntimeObserver,
                hasAttributeNodeRuntimeObserver: hasAttributeNodeRuntimeObserver,
                authoredCustomPropertyNames: authoredCustomPropertyNames,
                generatedCustomPropertyNames: generatedCustomPropertyNames,
                hasUnsupportedRuntimeDependency: hasUnsupportedRuntimeDependency,
                diagnostics: diagnostics
            )
        }

        var updated = html
        var hasHTMLAttributeMutation = false
        for tag in tags.reversed() {
            if let embedded = embeddedStyleCandidates[tag.range.lowerBound] {
                updated.replaceRange(embedded.range, with: embedded.source)
            }
            var currentTag = tag
            if let inline = inlineStyleCandidates[tag.range.lowerBound] {
                hasHTMLAttributeMutation = true
                if inline.source.allSatisfy(Self.isCSSASCIIWhitespace) {
                    Self.applyAttributeChanges([("style", "")], into: &updated, tag: currentTag)
                } else {
                    updated.replaceRange(inline.range, with: inline.source)
                }
                if let reparsed = OpenGraphiteHTMLDocument(html: updated).parsedTags().first(where: {
                    $0.range.lowerBound == tag.range.lowerBound
                }) {
                    currentTag = reparsed
                }
            }
            var changes: [(name: String, value: String?)] = []
            var classes = classTokens(tag.attributeValue(named: "class") ?? "")
            if let authoredType = tag.attributeValue(named: "data-og-type") {
                let type = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredType))
                classes.appendUnique("og-migrated-v1-type-\(type)")
                changes.append(("data-og-type", nil))
            }
            if let authoredLayout = tag.attributeValue(named: "data-og-layout") {
                let layout = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredLayout))
                classes.appendUnique("og-migrated-v1-layout-\(layout)")
                changes.append(("data-og-layout", nil))
            }
            if let authoredHidden = tag.attributeValue(named: "data-og-hidden") {
                let hidden = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredHidden))
                if hidden == "true" {
                    if !tag.attributes.contains(where: { $0.name.lowercased() == "hidden" }) {
                        changes.append(("hidden", ""))
                    }
                } else if hidden != "false" {
                    continue
                }
                changes.append(("data-og-hidden", nil))
            }
            if let authoredMask = tag.attributeValue(named: "data-og-icon-mask") {
                let mask = Self.asciiLowercased(Self.trimmingASCIIWhitespace(authoredMask))
                if mask == "true" { classes.appendUnique("og-migrated-v1-icon-mask") }
                changes.append(("data-og-icon-mask", nil))
            }
            for (legacy, standard) in [("data-og-variant", "variant"), ("data-og-part", "part")] {
                if let value = tag.attributeValue(named: legacy) {
                    if !tag.attributes.contains(where: { $0.name.lowercased() == standard }) {
                        changes.append((standard, value))
                    }
                    changes.append((legacy, nil))
                }
            }
            if tag.tagName.lowercased() == "og-placement",
               tag.attributeValue(named: "data-og-role")?.lowercased() == "component-placement" {
                changes.append(("data-og-role", nil))
            }
            for attribute in tag.attributes {
                let name = attribute.name.lowercased()
                if !identityAttributes.contains(name),
                   isRuntimeAttribute(name) {
                    changes.append((name, nil))
                }
            }
            let originalClasses = classTokens(tag.attributeValue(named: "class") ?? "")
            let addedClasses = classes.filter { !originalClasses.contains($0) }
            if !addedClasses.isEmpty {
                hasHTMLAttributeMutation = true
                if tag.attributeValue(named: "class") != nil {
                    Self.appendClassTokens(addedClasses, into: &updated, tag: currentTag)
                    if let reparsed = OpenGraphiteHTMLDocument(html: updated).parsedTags().first(where: {
                        $0.range.lowerBound == tag.range.lowerBound
                    }) {
                        currentTag = reparsed
                    }
                } else {
                    changes.append(("class", addedClasses.joined(separator: " ")))
                }
            }
            if !changes.isEmpty { hasHTMLAttributeMutation = true }
            Self.applyAttributeChanges(changes, into: &updated, tag: currentTag)
        }
        return OpenGraphiteLegacyHTMLMigrationResult(
            source: updated,
            detectedLegacy: detectedLegacy,
            types: types,
            layouts: layouts,
            generatedClassNames: generatedClasses,
            existingClassNames: existingClasses,
            removedLegacyDatasetAttributeNames: removedLegacyDatasetAttributeNames,
            generatedDestinationAttributes: generatedDestinationAttributes,
            observedDestinationAttributes: observedDestinationAttributes,
            hasWholeDatasetRuntimeObserver: hasWholeDatasetRuntimeObserver,
            hasGeneratedClassObserver: hasGeneratedClassObserver,
            hasGeneratedCustomPropertyStyleObserver: hasGeneratedCustomPropertyStyleObserver,
            hasGeneratedCustomPropertyRuntimeObserver: hasGeneratedCustomPropertyRuntimeObserver,
            hasWholeStyleRuntimeObserver: hasWholeStyleRuntimeObserver,
            hasInlineStyleMutation: !inlineStyleCandidates.isEmpty,
            hasHTMLSourceMutation: updated != html,
            hasHTMLAttributeMutation: hasHTMLAttributeMutation,
            hasEmbeddedStyleMutation: !embeddedStyleCandidates.isEmpty,
            hasWholeAttributeRuntimeObserver: hasWholeAttributeRuntimeObserver,
            hasWholeMarkupRuntimeObserver: hasWholeMarkupRuntimeObserver,
            hasCSSOMRuntimeObserver: hasCSSOMRuntimeObserver,
            hasStyleTextRuntimeObserver: hasStyleTextRuntimeObserver,
            hasPreviewContextRuntimeObserver: hasPreviewContextRuntimeObserver,
            observedPreviewHostFields: observedPreviewHostFields,
            hasDynamicSelectorRuntimeObserver: hasDynamicSelectorRuntimeObserver,
            hasAttributeNodeRuntimeObserver: hasAttributeNodeRuntimeObserver,
            authoredCustomPropertyNames: authoredCustomPropertyNames,
            generatedCustomPropertyNames: generatedCustomPropertyNames,
            hasUnsupportedRuntimeDependency: hasUnsupportedRuntimeDependency,
            diagnostics: []
        )
    }

    private func classTokens(_ value: String) -> [String] {
        value.split(whereSeparator: Self.isHTMLASCIIWhitespace).map(String.init)
    }

    private func containsLegacyRuntimeJavaScript(_ source: String) -> Bool {
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
                      source[cursor].isLetter || source[cursor].isNumber
                        || source[cursor] == "_" || source[cursor] == "$" {
                    cursor = source.index(after: cursor)
                }
                tokens.append(String(source[start..<cursor]))
                continue
            }
            if !Self.isECMAScriptWhitespace(character) { tokens.append(String(character)) }
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

    private func isSafeClassSuffix(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0)
        }
    }

    private func containsReservedCustomPropertyToken(_ value: String) -> Bool {
        let style = OpenGraphiteCSSStyle.parse(value)
        return style.declarations.contains { declaration in
            isLegacyReservedCustomPropertyName(declaration.name)
                || declaration.value.contains("--og-")
        }
    }

    private func isLegacyReservedCustomPropertyName(_ name: String) -> Bool {
        guard name.hasPrefix("--og-"), name.count > "--og-".count else { return false }
        return name.dropFirst("--og-".count).unicodeScalars.allSatisfy { scalar in
            (0x30...0x39).contains(scalar.value)
                || (0x41...0x5A).contains(scalar.value)
                || (0x61...0x7A).contains(scalar.value)
                || scalar.value == 0x2D
                || scalar.value == 0x5F
        }
    }


    /// 論理名（日本語）: 全開始タグ解析関数
    /// 処理概要: HTML の開始タグを走査し、属性、深度、文字範囲を保持した内部表現へ変換します。
    ///
    /// - Returns: HTML 内の開始タグ一覧。
    func parsedTags() -> [OpenGraphiteHTMLTag] {
        parsedElements().map(\.tag)
    }

    /// authored開始tagをHTMLのimplied end tag規則とともに走査し、親関係とsource範囲を一度に確定します。
    private func parsedElements() -> [OpenGraphiteHTMLParsedElement] {
        var elements: [OpenGraphiteHTMLParsedElement] = []
        var stack: [Int] = []
        var index = html.startIndex

        while let openIndex = html[index...].firstIndex(of: "<") {
            if html[openIndex...].hasPrefix("<!--") {
                index = Self.htmlCommentEnd(in: html, from: openIndex) ?? html.endIndex
                continue
            }
            if html[openIndex...].hasPrefix("<![CDATA[") {
                if Self.isInForeignContent(stack: stack, elements: elements),
                   let endRange = html.range(
                       of: "]]>",
                       range: html.index(openIndex, offsetBy: 9)..<html.endIndex
                   ) {
                    index = endRange.upperBound
                } else {
                    index = Self.htmlBogusCommentEnd(in: html, from: openIndex) ?? html.endIndex
                }
                continue
            }

            guard let closeIndex = findTagEnd(startingAt: html.index(after: openIndex)) else {
                break
            }

            let afterOpen = html.index(after: openIndex)
            let inner = String(html[afterOpen..<closeIndex])
            let trimmed = Self.trimmingASCIIWhitespace(inner)
            let afterClose = html.index(after: closeIndex)
            let openOffset = html.distance(from: html.startIndex, to: openIndex)
            let afterCloseOffset = html.distance(from: html.startIndex, to: afterClose)

            if trimmed.hasPrefix("/") {
                let closingName = tagName(fromClosingTag: trimmed)
                if let matchPosition = stack.lastIndex(where: {
                    elements[$0].tag.tagName == closingName
                }) {
                    if matchPosition + 1 < stack.count {
                        Self.closeOpenElements(
                            stack[(matchPosition + 1)...],
                            at: openOffset,
                            elements: &elements
                        )
                    }
                    let matchedElementIndex = stack[matchPosition]
                    elements[matchedElementIndex].contentEnd = openOffset
                    elements[matchedElementIndex].fullEnd = afterCloseOffset
                    stack.removeSubrange(matchPosition..<stack.endIndex)
                }
                index = afterClose
                continue
            }

            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("?") {
                index = afterClose
                continue
            }

            let (rawName, attributeSource, lexicalSelfClosing) = splitOpeningTag(trimmed)
            guard let firstNameCharacter = rawName.first,
                  Self.isASCIIAlpha(firstNameCharacter)
            else {
                index = afterClose
                continue
            }

            let tagName = rawName.lowercased()
            Self.adjustStackForImpliedEndTags(
                beforeOpening: tagName,
                at: openOffset,
                stack: &stack,
                elements: &elements
            )
            let isVoid = Self.voidElementNames.contains(tagName)
            let isForeignElement = tagName == "svg"
                || tagName == "math"
                || Self.isInForeignContent(stack: stack, elements: elements)
            // HTML namespaceのnon-void要素だけはself-closing flagを無視し、SVG/MathMLではsource境界としてhonorします。
            let selfClosing = lexicalSelfClosing && (isVoid || isForeignElement)
            let tag = OpenGraphiteHTMLTag(
                range: openOffset..<afterCloseOffset,
                rawTagName: rawName,
                tagName: tagName,
                attributes: Self.parseAttributes(attributeSource),
                depth: stack.count,
                selfClosing: selfClosing,
                lexicalSelfClosing: lexicalSelfClosing
            )
            let elementIndex = elements.count
            elements.append(
                OpenGraphiteHTMLParsedElement(
                    tag: tag,
                    parentIndex: stack.last,
                    contentEnd: nil,
                    fullEnd: nil
                )
            )

            if !selfClosing, Self.rawTextElementNames.contains(tagName) {
                if tagName == "plaintext" {
                    let documentEnd = html.distance(from: html.startIndex, to: html.endIndex)
                    elements[elementIndex].contentEnd = documentEnd
                    elements[elementIndex].fullEnd = documentEnd
                    index = html.endIndex
                } else {
                    if let rawTextRange = rawTextClosingRange(tagName: tagName, from: afterClose) {
                        elements[elementIndex].contentEnd = html.distance(
                            from: html.startIndex,
                            to: rawTextRange.lowerBound
                        )
                        elements[elementIndex].fullEnd = html.distance(
                            from: html.startIndex,
                            to: rawTextRange.upperBound
                        )
                        index = rawTextRange.upperBound
                    } else {
                        let documentEnd = html.distance(from: html.startIndex, to: html.endIndex)
                        elements[elementIndex].contentEnd = documentEnd
                        elements[elementIndex].fullEnd = documentEnd
                        index = html.endIndex
                    }
                }
                continue
            }

            if selfClosing || isVoid {
                elements[elementIndex].contentEnd = afterCloseOffset
                elements[elementIndex].fullEnd = afterCloseOffset
            } else {
                stack.append(elementIndex)
            }

            index = afterClose
        }

        let documentEnd = html.distance(from: html.startIndex, to: html.endIndex)
        Self.closeOpenElements(stack[...], at: documentEnd, elements: &elements)
        return elements
    }

    /// HTML commentの標準close tokenまたはabrupt empty close直後を返します。
    private static func htmlCommentEnd(in source: String, from openIndex: String.Index) -> String.Index? {
        let bodyStart = source.index(openIndex, offsetBy: 4)
        if bodyStart < source.endIndex, source[bodyStart] == ">" {
            return source.index(after: bodyStart)
        }
        let standard = source.range(of: "-->", range: bodyStart..<source.endIndex)
        let bang = source.range(of: "--!>", range: bodyStart..<source.endIndex)
        switch (standard, bang) {
        case let (standard?, bang?):
            return standard.lowerBound < bang.lowerBound ? standard.upperBound : bang.upperBound
        case let (standard?, nil):
            return standard.upperBound
        case let (nil, bang?):
            return bang.upperBound
        case (nil, nil):
            return nil
        }
    }

    /// HTML namespaceで未知markup declarationがbogus commentとして閉じる位置を返します。
    private static func htmlBogusCommentEnd(in source: String, from openIndex: String.Index) -> String.Index? {
        guard let close = source[openIndex...].firstIndex(of: ">") else { return nil }
        return source.index(after: close)
    }

    /// 現在のopen-element stackがCDATA sectionを許可するforeign content内かを返します。
    private static func isInForeignContent(
        stack: [Int],
        elements: [OpenGraphiteHTMLParsedElement]
    ) -> Bool {
        var foreign = false
        for index in stack {
            switch elements[index].tag.tagName {
            case "svg", "math":
                foreign = true
            case "foreignobject":
                foreign = false
            default:
                break
            }
        }
        return foreign
    }

    /// HTMLで終了タグを省略できる要素を、次の開始tag位置でsource stackから閉じます。
    private static func adjustStackForImpliedEndTags(
        beforeOpening tagName: String,
        at boundary: Int,
        stack: inout [Int],
        elements: inout [OpenGraphiteHTMLParsedElement]
    ) {
        if stack.last.map({ elements[$0].tag.tagName }) == "head",
           !headContentStartTags.contains(tagName) {
            popLastImpliedElement(
                named: ["head"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if stack.last.map({ elements[$0].tag.tagName }) == "colgroup",
           tagName != "col",
           tagName != "template" {
            popLastImpliedElement(
                named: ["colgroup"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tableCaptionClosingStartTags.contains(tagName) {
            popLastImpliedElement(
                named: ["caption"],
                scopedBy: ["table"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tagName == "li" {
            popLastImpliedElement(
                named: ["li"],
                scopedBy: ["ul", "ol", "menu"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tagName == "dt" || tagName == "dd" {
            popLastImpliedElement(
                named: ["dt", "dd"],
                scopedBy: ["dl"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if impliedParagraphClosingStartTags.contains(tagName) {
            popLastImpliedElement(
                named: ["p"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        let rubyElementsToClose: Set<String>
        switch tagName {
        case "rb":
            rubyElementsToClose = ["rb", "rtc"]
        case "rt":
            rubyElementsToClose = ["rb", "rt", "rp"]
        case "rtc":
            rubyElementsToClose = ["rb", "rtc"]
        case "rp":
            rubyElementsToClose = ["rb", "rt", "rtc", "rp"]
        default:
            rubyElementsToClose = []
        }
        if !rubyElementsToClose.isEmpty {
            popLastImpliedElement(
                named: rubyElementsToClose,
                scopedBy: ["ruby"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tagName == "option" {
            popLastImpliedElement(
                named: ["option"],
                scopedBy: ["select", "datalist", "optgroup"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        } else if tagName == "optgroup" {
            popLastImpliedElement(
                named: ["option"],
                scopedBy: ["select", "datalist", "optgroup"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
            popLastImpliedElement(
                named: ["optgroup"],
                scopedBy: ["select"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tableSectionElementNames.contains(tagName) {
            popLastImpliedElement(
                named: tableSectionElementNames,
                scopedBy: ["table"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tagName == "tr" {
            popLastImpliedElement(
                named: ["tr"],
                scopedBy: tableSectionElementNames.union(["table"]),
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
        if tagName == "td" || tagName == "th" {
            popLastImpliedElement(
                named: ["td", "th"],
                scopedBy: ["tr"],
                at: boundary,
                stack: &stack,
                elements: &elements
            )
        }
    }

    /// 指定scope内で最後に開かれたoptional要素とその未閉鎖descendantをstackから除きます。
    private static func popLastImpliedElement(
        named names: Set<String>,
        scopedBy scopeNames: Set<String>? = nil,
        at boundary: Int,
        stack: inout [Int],
        elements: inout [OpenGraphiteHTMLParsedElement]
    ) {
        guard let matchIndex = stack.lastIndex(where: {
            names.contains(elements[$0].tag.tagName)
        }) else { return }
        if let scopeNames {
            guard let scopeIndex = stack.lastIndex(where: {
                scopeNames.contains(elements[$0].tag.tagName)
            }), matchIndex > scopeIndex else {
                return
            }
        }
        closeOpenElements(stack[matchIndex...], at: boundary, elements: &elements)
        stack.removeSubrange(matchIndex..<stack.endIndex)
    }

    /// source上で未閉鎖のstack要素を指定境界までのelementとして確定します。
    private static func closeOpenElements(
        _ elementIndices: ArraySlice<Int>,
        at boundary: Int,
        elements: inout [OpenGraphiteHTMLParsedElement]
    ) {
        for elementIndex in elementIndices {
            elements[elementIndex].contentEnd = boundary
            elements[elementIndex].fullEnd = boundary
        }
    }

    /// script/style/RCDATA本文中の`<...>`をphantom elementとして解釈せず対応closing tag範囲を返します。
    private func rawTextClosingRange(
        tagName: String,
        from startIndex: String.Index
    ) -> Range<String.Index>? {
        var searchStart = startIndex
        let needle = "</\(tagName)"
        while searchStart < html.endIndex,
              let range = html.range(
                  of: needle,
                  options: [.caseInsensitive],
                  range: searchStart..<html.endIndex
              ) {
            let nameEnd = range.upperBound
            if nameEnd < html.endIndex {
                let boundary = html[nameEnd]
                guard Self.isHTMLASCIIWhitespace(boundary) || boundary == "/" || boundary == ">" else {
                    searchStart = nameEnd
                    continue
                }
            }
            guard let close = findTagEnd(startingAt: nameEnd) else { return nil }
            return range.lowerBound..<html.index(after: close)
        }
        return nil
    }

    /// raw text / RCDATA要素の対応closing tag終端を返します。
    private func rawTextClosingEnd(tagName: String, from startIndex: String.Index) -> String.Index? {
        rawTextClosingRange(tagName: tagName, from: startIndex)?.upperBound
    }

    /// 論理名（日本語）: CSS宣言設定関数
    /// 処理概要: legacy HTML の inline style に残る OpenGraphite 編集対象 CSS 宣言を設定します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS property または custom property 名。
    ///   - value: 設定値。空の場合は対象変数を削除します。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingCSSVariable(
        _ variable: String,
        value: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        if !contract.isKnownCSSVariable(variable) {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unknown-css-variable",
                    message: "\(variable) は OpenGraphite.contract.json に定義されていません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueTag(forNodeID: id)
        guard let tag = match.tag else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        sanitized = sanitizedDocument.settingInlineStyleProperty(
            variable,
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            for: tag
        )
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノード属性設定関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードへ、契約とoperation capabilityの両方が許可する属性だけを設定します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 設定値。空文字もpresent-empty属性として保持します。削除は`removingAttribute`を使います。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingAttribute(
        name: String,
        value: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        changingAttribute(name: name, value: value, forNodeID: id, contract: contract)
    }

    /// 論理名（日本語）: ノード属性削除関数
    /// 処理概要: 一意なnodeから許可済み属性tokenを削除し、空文字を設定する操作とは区別します。
    ///
    /// - Parameters:
    ///   - name: 削除する属性名。
    ///   - id: 対象ノードの`data-og-internal-id`。
    ///   - contract: 検証に使うOpenGraphite契約。
    /// - Returns: 更新済みHTMLとdiagnostics。
    func removingAttribute(
        name: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        changingAttribute(name: name, value: nil, forNodeID: id, contract: contract)
    }

    /// 空文字を含むsetとtoken removalを分離し、共通のcontract/capability target validationを適用します。
    private func changingAttribute(
        name: String,
        value: String?,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let normalizedName = name.lowercased()
        guard normalizedName != "data-og-id",
              normalizedName != "data-og-internal-id",
              contract.isEditableAttribute(normalizedName)
        else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "disallowed-attribute",
                    message: "\(name) は node attr set で編集できる属性ではありません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueTag(forNodeID: id)
        guard let tag = match.tag else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }
        let hasAuthoredAttribute = tag.attributes.contains {
            $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        guard let node = sanitizedDocument.capabilityNode(forNodeID: id, contract: contract),
              Self.canSetEditableAttribute(normalizedName, on: tag, node: node)
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(normalizedName) は対象nodeの標準DOM semanticsとoperation capabilityでは編集できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }
        if value == nil, !hasAuthoredAttribute {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
        }

        Self.applyAttributeChanges(
            [(normalizedName, value)],
            into: &sanitized,
            tag: tag
        )
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノード表示ID変更関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードの `data-og-id` を、同一 HTML 内で重複しない値へ変更します。
    ///
    /// - Parameters:
    ///   - value: 新しい `data-og-id`。空文字は拒否します。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: runtime 属性除去に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func renamingNodeID(
        value: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "invalid-data-og-id",
                    message: "data-og-id には空でない値が必要です。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueTag(forNodeID: id)
        guard let tag = match.tag else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        let currentValue = tag.attributeValue(named: "data-og-id") ?? ""
        guard currentValue != normalizedValue else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
        }

        if sanitizedDocument.parsedTags().contains(where: { candidate in
            candidate.range != tag.range && candidate.attributeValue(named: "data-og-id") == normalizedValue
        }) {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-id",
                    message: "data-og-id \"\(normalizedValue)\" が重複しています。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        Self.applyAttributeChanges(
            [("data-og-id", normalizedValue)],
            into: &sanitized,
            tag: tag
        )
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: アイコン設定関数
    /// 処理概要: icon node の library/name/source metadata と保存済み描画 HTML を同時に更新します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide。
    ///   - name: icon name。空の場合は circle。
    ///   - source: icon source。空の場合は inline。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    ///   - capabilityConfirmed: Coreがproject/companion CSSを含むgraphで`edit-icon`を確認済みの場合は`true`。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingIcon(
        library: String,
        name: String,
        source: String,
        forNodeID id: String,
        contract: OpenGraphiteContract,
        capabilityConfirmed: Bool = false
    ) -> OpenGraphiteHTMLMutationResult {
        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueElement(forNodeID: id)
        guard let element = match.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        guard Self.hasIconProvenance(element.tag),
              capabilityConfirmed
                || sanitizedDocument.capabilityNode(forNodeID: id, contract: contract)?.supports(.editIcon) == true
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(id) はedit-icon capabilityと既存OpenGraphite icon metadataの両方を確認できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        guard !element.tag.selfClosing && !Self.voidElementNames.contains(element.tag.tagName) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "self-closing-icon-node",
                    message: "\(id) は自己終了タグのため icon content を設定できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        let icon = OpenGraphiteIconMarkup.contentHTML(
            library: library,
            name: name,
            source: source,
            nodeID: id
        )
        guard icon.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: icon.diagnostics)
        }

        sanitized.replaceRange(element.contentRange, with: icon.html)
        Self.applyAttributeChanges(
            [
                ("data-og-icon-library", icon.library),
                ("data-og-icon-name", icon.name),
                ("data-og-icon-source", icon.source)
            ],
            into: &sanitized,
            tag: element.tag
        )
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: HTML Document Context設定関数
    /// 処理概要: `<html>` の `lang` / `dir` と OpenGraphite binding metadata を保存します。
    ///
    /// - Parameters:
    ///   - context: 保存する HTML document context。
    ///   - contract: runtime 属性除去に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingHTMLDocumentContext(
        _ context: OpenGraphiteHTMLDocumentContext,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        guard let tag = sanitizedDocument.parsedTags().first(where: { $0.tagName == "html" }) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-html-root",
                    message: "<html> 開始タグが見つかりません。",
                    path: nil,
                    nodeID: nil
                )
            )
        }

        let normalizedContext = OpenGraphiteHTMLDocumentContext(
            langSource: context.langSource,
            langValue: context.langValue,
            langField: context.langField,
            dirSource: context.dirSource,
            dirValue: context.dirValue,
            dirField: context.dirField
        )
        guard normalizedContext.langSource != .binding || !normalizedContext.langField.isEmpty else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-lang-field",
                    message: "HTML Lang の Binding には field 名が必要です。",
                    path: nil,
                    nodeID: nil
                )
            )
        }
        guard normalizedContext.dirSource != .binding || !normalizedContext.dirField.isEmpty else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-dir-field",
                    message: "Text Dir の Binding には field 名が必要です。",
                    path: nil,
                    nodeID: nil
                )
            )
        }
        guard Self.isValidDirectionFallback(normalizedContext.dirValue) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "invalid-dir-value",
                    message: "dir 属性の fallback は ltr / rtl / auto のいずれか、または空にしてください。",
                    path: nil,
                    nodeID: nil
                )
            )
        }

        Self.applyAttributeChanges(
            [
                ("lang", normalizedContext.langValue.isEmpty ? nil : normalizedContext.langValue),
                ("data-og-lang-source", normalizedContext.langSource.rawValue),
                (
                    "data-og-lang-field",
                    normalizedContext.langSource == .binding ? normalizedContext.langField : nil
                ),
                ("dir", normalizedContext.dirValue.isEmpty ? nil : normalizedContext.dirValue),
                ("data-og-dir-source", normalizedContext.dirSource.rawValue),
                (
                    "data-og-dir-field",
                    normalizedContext.dirSource == .binding ? normalizedContext.dirField : nil
                )
            ],
            into: &sanitized,
            tag: tag
        )
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: Stylesheet link追加関数
    /// 処理概要: 指定 href の stylesheet link が `<head>` に存在しない場合だけ追加します。
    ///
    /// - Parameters:
    ///   - href: 追加する stylesheet href。
    ///   - contract: runtime 属性除去に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func ensuringStylesheetLink(
        href: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let normalizedHref = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHref.isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "empty-stylesheet-href",
                    message: "stylesheet href は空にできません。",
                    path: nil,
                    nodeID: nil
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        guard !sanitizedDocument.containsStylesheetLink(href: normalizedHref) else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
        }

        let linkHTML = Self.stylesheetLinkHTML(href: normalizedHref)
        let tags = sanitizedDocument.parsedTags()
        if let headTag = tags.first(where: { $0.tagName == "head" }),
           let headElement = sanitizedDocument.element(for: headTag) {
            sanitized.insert("\n\(linkHTML)", atOffset: headElement.contentRange.upperBound)
        } else if let htmlTag = tags.first(where: { $0.tagName == "html" }) {
            sanitized.insert("\n<head>\n\(linkHTML)</head>\n", atOffset: htmlTag.range.upperBound)
        } else if let bodyTag = tags.first(where: { $0.tagName == "body" }) {
            sanitized.insert("<head>\n\(linkHTML)</head>\n", atOffset: bodyTag.range.lowerBound)
        } else {
            sanitized = "<head>\n\(linkHTML)</head>\n\(sanitized)"
        }
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: 子HTML先頭挿入関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードの開始タグ直後へ子 HTML を挿入します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - id: 親ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func prependingChildHTML(
        _ childHTML: String,
        toNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        insertingHTML(childHTML, relativeToNodeID: id, position: .prepend, contract: contract)
    }

    /// 論理名（日本語）: テキスト内容設定関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードの内側を HTML escape 済み text content で置換します。
    ///
    /// - Parameters:
    ///   - text: 設定するプレーンテキスト。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingTextContent(
        _ text: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueElement(forNodeID: id)
        guard let element = match.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        guard sanitizedDocument.capabilityNode(forNodeID: id, contract: contract)?.supports(.editText) == true else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(id) は標準DOM text semanticsからedit-text capabilityを確認できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        guard !element.tag.selfClosing && !Self.voidElementNames.contains(element.tag.tagName) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "self-closing-text-target",
                    message: "\(id) は自己終了タグのため text content を設定できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        sanitized.replaceRange(element.contentRange, with: Self.escapeText(text))
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: テキストvariant設定関数
    /// 処理概要: `data-i18n-key` に一致する binding text の locale variant を属性として保存します。
    ///
    /// - Parameters:
    ///   - text: 保存する variant HTML。空文字も有効な variant として保持されます。
    ///   - locale: variant の locale 名。
    ///   - i18nKey: 対象 `data-i18n-key`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingTextVariant(
        _ text: String,
        locale: String,
        i18nKey: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let normalizedKey = i18nKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "empty-i18n-key",
                    message: "text variant の data-i18n-key は空にできません。",
                    path: nil,
                    nodeID: nil
                )
            )
        }

        guard let normalizedLocale = Self.normalizedTextVariantLocale(locale) else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "invalid-text-variant-locale",
                    message: "text variant locale は a-z / 0-9 / - の非空文字列で指定してください。",
                    path: nil,
                    nodeID: normalizedKey
                )
            )
        }

        let attributeName = "data-og-text-variant-\(normalizedLocale)"
        guard contract.editableAttributeSet.contains(attributeName) else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unknown-text-variant-locale",
                    message: "\(attributeName) は OpenGraphite.contract.json に定義されていません。",
                    path: nil,
                    nodeID: normalizedKey
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let matches = sanitizedDocument.parsedTags().filter { tag in
            tag.attributeValue(named: "data-i18n-key") == normalizedKey
        }
        guard !matches.isEmpty else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-i18n-key",
                    message: "data-i18n-key \"\(normalizedKey)\" を持つ text binding が見つかりません。",
                    path: nil,
                    nodeID: normalizedKey
                )
            )
        }

        for tag in matches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            Self.applyAttributeChanges(
                [(attributeName, text)],
                into: &sanitized,
                tag: tag
            )
        }
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: HTML断片挿入関数
    /// 処理概要: 一意な `data-og-internal-id` を持つ anchor node を基準に HTML 断片を挿入します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - id: 基準ノードの `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func insertingHTML(
        _ fragmentHTML: String,
        relativeToNodeID id: String,
        position: OpenGraphiteHTMLInsertionPosition,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let boundaryTrimmedFragmentHTML = fragmentHTML.trimmingCharacters(in: .newlines)
        guard !boundaryTrimmedFragmentHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "empty-html-fragment",
                    message: "挿入する HTML が空です。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueElement(forNodeID: id)
        guard let element = match.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        let childInsertion = position == .prepend || position == .append
        let records = sanitizedDocument.domRecords()
        let targetIndex = records.firstIndex { $0.tag.range == element.tag.range }
        let receiverIndex = targetIndex.flatMap { childInsertion ? $0 : records[$0].parentIndex }
        let capabilityNodes = sanitizedDocument.nodes(contract: contract)
        guard let receiverIndex,
              capabilityNodes.indices.contains(receiverIndex),
              capabilityNodes[receiverIndex].supports(.receiveChildren)
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(id) の挿入先は標準DOM semanticsからreceive-children capabilityを確認できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }
        guard !childInsertion || (!element.tag.selfClosing && !Self.voidElementNames.contains(element.tag.tagName)) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "self-closing-parent",
                    message: "\(id) は自己終了タグのため子 HTML を挿入できません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        Self.insertRawHTML(boundaryTrimmedFragmentHTML, into: &sanitized, relativeTo: element, position: position)
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノードHTML置換関数
    /// 処理概要: 一意な `data-og-internal-id` を持つ node 全体を HTML 断片で置換します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func replacingNodeHTML(
        _ replacementHTML: String,
        nodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        let boundaryTrimmedReplacementHTML = replacementHTML.trimmingCharacters(in: .newlines)
        guard !boundaryTrimmedReplacementHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "empty-html-fragment",
                    message: "置換する HTML が空です。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueElement(forNodeID: id)
        guard let element = match.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        sanitized.replaceRange(element.fullRange, with: boundaryTrimmedReplacementHTML)
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノード削除関数
    /// 処理概要: 一意な `data-og-internal-id` を持つ node subtree を HTML から削除します。
    ///
    /// - Parameters:
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func deletingNode(
        nodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let match = sanitizedDocument.uniqueElement(forNodeID: id)
        guard let element = match.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: match.diagnostics)
        }

        sanitized.replaceRange(element.fullRange, with: "")
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノード移動関数
    /// 処理概要: 一意な source node subtree を target node 基準位置へ移動します。
    ///
    /// - Parameters:
    ///   - sourceID: 移動元ノードの `data-og-internal-id`。
    ///   - targetID: 移動先基準ノードの `data-og-internal-id`。
    ///   - position: 移動先位置。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func movingNode(
        nodeID sourceID: String,
        relativeToNodeID targetID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        guard sourceID != targetID else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "same-source-and-target",
                    message: "移動元と移動先に同じ data-og-internal-id は指定できません。",
                    path: nil,
                    nodeID: sourceID
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let sourceMatch = sanitizedDocument.uniqueElement(forNodeID: sourceID)
        guard let sourceElement = sourceMatch.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: sourceMatch.diagnostics)
        }
        let targetMatch = sanitizedDocument.uniqueElement(forNodeID: targetID)
        guard let targetElement = targetMatch.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: targetMatch.diagnostics)
        }

        let records = sanitizedDocument.domRecords()
        let capabilityNodes = sanitizedDocument.nodes(contract: contract)
        let sourceIndex = records.firstIndex { $0.tag.range == sourceElement.tag.range }
        let targetIndex = records.firstIndex { $0.tag.range == targetElement.tag.range }
        let childInsertion = position == .prepend || position == .append
        let receiverIndex = targetIndex.flatMap { childInsertion ? $0 : records[$0].parentIndex }
        guard let sourceIndex,
              capabilityNodes.indices.contains(sourceIndex),
              capabilityNodes[sourceIndex].supports(.dragPosition)
                || capabilityNodes[sourceIndex].supports(.reorderFlow)
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(sourceID) はdrag-positionまたはreorder-flow capabilityを持たないため移動できません。",
                    path: nil,
                    nodeID: sourceID
                )
            )
        }
        guard let receiverIndex,
              capabilityNodes.indices.contains(receiverIndex),
              capabilityNodes[receiverIndex].supports(.receiveChildren)
                || Self.canReorderChild(
                    records[sourceIndex].tag,
                    in: records[receiverIndex].tag,
                    childIsHTMLNamespace: sanitizedDocument.isHTMLNamespace(for: sourceIndex, records: records),
                    parentIsHTMLNamespace: sanitizedDocument.isHTMLNamespace(for: receiverIndex, records: records)
                )
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(targetID) の移動先はreceive-children capabilityを持ちません。",
                    path: nil,
                    nodeID: targetID
                )
            )
        }

        guard !sourceElement.fullRange.contains(targetElement.fullRange.lowerBound) else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "move-target-inside-source",
                    message: "\(targetID) は \(sourceID) の subtree 内にあるため移動先にできません。",
                    path: nil,
                    nodeID: sourceID
                )
            )
        }

        let movedHTML = sanitized.substring(sourceElement.fullRange)
        let removalRange = Self.lineRemovalRange(for: sourceElement, in: sanitized)
        sanitized.replaceRange(removalRange, with: "")
        var withoutSource = sanitized
        let targetAfterRemoval = OpenGraphiteHTMLDocument(html: withoutSource).uniqueElement(forNodeID: targetID)
        guard let updatedTargetElement = targetAfterRemoval.element else {
            return OpenGraphiteHTMLMutationResult(html: withoutSource, diagnostics: targetAfterRemoval.diagnostics)
        }

        Self.insertMovedHTML(movedHTML, into: &withoutSource, relativeTo: updatedTargetElement, position: position)
        return OpenGraphiteHTMLMutationResult(html: withoutSource, diagnostics: [])
    }

    /// 論理名（日本語）: ノード複製関数
    /// 処理概要: 一意な source node subtree の表示用 `data-og-id` に prefix を付けて target node 基準位置へ複製します。
    ///
    /// - Parameters:
    ///   - sourceID: 複製元ノードの `data-og-internal-id`。
    ///   - targetID: 複製先基準ノードの `data-og-internal-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func copyingNode(
        nodeID sourceID: String,
        relativeToNodeID targetID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        guard !idPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "empty-id-prefix",
                    message: "複製には空でない data-og-id prefix が必要です。",
                    path: nil,
                    nodeID: sourceID
                )
            )
        }

        var sanitized = OpenGraphiteHTMLDocument(html: html).removingRuntimeState(contract: contract)
        let sanitizedDocument = OpenGraphiteHTMLDocument(html: sanitized)
        let sourceMatch = sanitizedDocument.uniqueElement(forNodeID: sourceID)
        guard let sourceElement = sourceMatch.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: sourceMatch.diagnostics)
        }
        let targetMatch = sanitizedDocument.uniqueElement(forNodeID: targetID)
        guard let targetElement = targetMatch.element else {
            return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: targetMatch.diagnostics)
        }

        let records = sanitizedDocument.domRecords()
        let capabilityNodes = sanitizedDocument.nodes(contract: contract)
        let sourceIndex = records.firstIndex { $0.tag.range == sourceElement.tag.range }
        let targetIndex = records.firstIndex { $0.tag.range == targetElement.tag.range }
        let childInsertion = position == .prepend || position == .append
        let receiverIndex = targetIndex.flatMap { childInsertion ? $0 : records[$0].parentIndex }
        guard let sourceIndex,
              capabilityNodes.indices.contains(sourceIndex),
              capabilityNodes[sourceIndex].supports(.group)
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(sourceID) はgroup capabilityを持たないため複製対象にできません。",
                    path: nil,
                    nodeID: sourceID
                )
            )
        }
        guard let receiverIndex,
              capabilityNodes.indices.contains(receiverIndex),
              capabilityNodes[receiverIndex].supports(.receiveChildren)
        else {
            return .failure(
                html: sanitized,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "unsupported-node-capability",
                    message: "\(targetID) の複製先はreceive-children capabilityを持ちません。",
                    path: nil,
                    nodeID: targetID
                )
            )
        }

        let copiedHTML = Self.prefixingDataOGIDs(in: sanitized.substring(sourceElement.fullRange), prefix: idPrefix)
        Self.insertRawHTML(copiedHTML, into: &sanitized, relativeTo: targetElement, position: position)
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: Source保持関数
    /// 処理概要: 通常の編集経路ではlegacy runtime helperを暗黙変換せず、入力HTMLをそのまま返します。
    ///
    /// - Parameter contract: 呼び出し互換性のため受け取る契約。明示migrationだけがlegacy名を解釈します。
    /// - Returns: byte相当で未変更のHTML。
    func removingRuntimeState(contract: OpenGraphiteContract) -> String {
        _ = contract
        return html
    }

    /// 論理名（日本語）: OpenGraphite design style削除関数
    /// 処理概要: companion CSS 正本へ移す OpenGraphite 編集対象 CSS 宣言を HTML inline style から除去します。
    ///
    /// - Parameter contract: 除去対象の CSS 宣言を定義する OpenGraphite 契約。
    /// - Returns: OpenGraphite 編集対象 CSS 宣言を取り除いた HTML。
    func removingOpenGraphiteStyleVariables(contract: OpenGraphiteContract = .builtIn) -> String {
        var result = html
        for tag in parsedTags().reversed() {
            let document = OpenGraphiteHTMLDocument(html: result)
            let properties = Set(
                document.inlineStyleValues(for: tag, properties: nil).keys.filter {
                    contract.isKnownCSSVariable($0)
                }
            )
            guard !properties.isEmpty else { continue }
            result = document.removingInlineStyleProperties(properties, for: tag)
        }
        return result
    }

    /// annotationのない要素も含むDOM索引を構築し、selector照合と安全なrelative path生成に使います。
    private func domRecords() -> [OpenGraphiteHTMLDOMRecord] {
        let parsedElements = parsedElements()
        var records: [OpenGraphiteHTMLDOMRecord] = []
        var siblingPositions: [String: Int] = [:]

        for parsedElement in parsedElements {
            let tag = parsedElement.tag
            let parentIndex = parsedElement.parentIndex
            let siblingKey = "\(parentIndex ?? -1)|\(tag.tagName)"
            let typeIndex = (siblingPositions[siblingKey] ?? 0) + 1
            siblingPositions[siblingKey] = typeIndex
            var ancestors: [OpenGraphiteCSSDOMElement] = []
            var ancestorIndex = parentIndex
            while let current = ancestorIndex {
                ancestors.append(records[current].element)
                ancestorIndex = records[current].parentIndex
            }
            let element = OpenGraphiteCSSDOMElement(
                tagName: tag.tagName,
                attributes: tag.attributeDictionary,
                ancestors: ancestors,
                isRoot: tag.tagName == "html",
                typeIndex: typeIndex
            )
            records.append(
                OpenGraphiteHTMLDOMRecord(
                    tag: tag,
                    element: element,
                    cssElement: element,
                    parentIndex: parentIndex,
                    siblingTypeCount: 1,
                    contentEnd: parsedElement.contentEnd,
                    fullEnd: parsedElement.fullEnd
                )
            )
        }

        let cssProjection = OpenGraphiteCSSDOMProjection.browserDocument(
            from: records.map {
                OpenGraphiteCSSDOMSourceNode(element: $0.element, parentIndex: $0.parentIndex)
            }
        )
        for index in records.indices {
            if let cssElement = cssProjection.element(forSourceIndex: index) {
                records[index].cssElement = cssElement
            }
        }

        let totals = Dictionary(grouping: records.indices) { index in
            "\(records[index].parentIndex ?? -1)|\(records[index].tag.tagName)"
        }.mapValues(\.count)
        for index in records.indices {
            let key = "\(records[index].parentIndex ?? -1)|\(records[index].tag.tagName)"
            records[index].siblingTypeCount = totals[key] ?? 1
        }
        return records
    }

    /// optional identity annotationの充足状態を返します。
    private func annotationStatus(for tag: OpenGraphiteHTMLTag) -> OpenGraphiteNodeAnnotationStatus {
        let hasDisplayID = tag.emptyNilAttribute(named: "data-og-id") != nil
        let hasInternalID = tag.emptyNilAttribute(named: "data-og-internal-id") != nil
        if hasDisplayID && hasInternalID {
            return .complete
        }
        if hasDisplayID || hasInternalID {
            return .partial
        }
        return .none
    }

    /// 論理名（日本語）: Project resource root索引解決関数
    /// 処理概要: authoredまたは省略body相当の直下に操作対象要素が1件だけある場合に限り、project登録rootとして確定します。
    ///
    /// - Parameter records: authored DOM親関係を保持するrecord一覧。
    /// - Returns: authored body相当直下のresource境界index。1件の場合だけ呼び出し側がroot evidenceにします。
    private func projectResourceBoundaryIndices(in records: [OpenGraphiteHTMLDOMRecord]) -> [Int] {
        let bodyIndex = records.indices.first { records[$0].tag.tagName == "body" }
        let candidates: [Int]
        if let bodyIndex {
            candidates = records.indices.filter {
                records[$0].parentIndex == bodyIndex
                    && Self.isProjectResourceRootCandidate(records[$0].tag)
            }
        } else {
            let htmlIndex = records.indices.first { records[$0].tag.tagName == "html" }
            candidates = records.indices.filter { index in
                guard Self.isProjectResourceRootCandidate(records[index].tag) else { return false }
                return records[index].parentIndex == htmlIndex || records[index].parentIndex == nil
            }
        }
        return candidates
    }

    /// authored top-level elementがproject resource root候補として操作可能かを判定します。
    private static func isProjectResourceRootCandidate(_ tag: OpenGraphiteHTMLTag) -> Bool {
        !nonOperationalElementNames.contains(tag.tagName)
            && !["html", "head", "body"].contains(tag.tagName)
    }

    /// 論理名（日本語）: ノード操作能力根拠導出関数
    /// 処理概要: 標準tag、直接text/child、ARIA、media/SVG/mask実体、computed display、project rootをlegacy typeから独立して評価します。
    ///
    /// - Parameters:
    ///   - index: 対象authored DOM record index。
    ///   - records: authored DOM record一覧。
    ///   - resolvedStyles: source cascadeとUA fallbackを分離評価した標準CSS値。
    ///   - renderingTargets: 対象subtree内のmedia/SVG/mask実描画target。
    ///   - projectResourceRootIndex: project登録rootとして一意に確定したindex。
    /// - Returns: capability setを説明するevidence。
    private func capabilityEvidence(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        resolvedStyles: [Int: [String: String]],
        renderingTargets: [OpenGraphiteHTMLRenderingTarget],
        projectResourceRootIndex: Int?
    ) -> OpenGraphiteNodeCapabilityEvidence {
        let tag = records[index].tag
        let ariaRole = Self.semanticARIARole(tag.attributeValue(named: "role"))
        let isNativeControl = Self.nativeControlElementNames.contains(tag.tagName)
        let isLink = ((tag.tagName == "a" || tag.tagName == "area")
            && tag.attributes.contains { $0.name.caseInsensitiveCompare("href") == .orderedSame })
            || ariaRole == "link"
        let subtreeIndices = records.indices.filter {
            $0 == index || isAuthoredDescendant($0, of: index, records: records)
        }
        let hasMediaContent = subtreeIndices.contains {
            Self.mediaElementNames.contains(records[$0].tag.tagName)
        } || renderingTargets.contains { $0.value.kind == "media" }
        let hasSVGContent = subtreeIndices.contains {
            Self.svgElementNames.contains(records[$0].tag.tagName)
        } || renderingTargets.contains { $0.value.kind == "svg" }
        let hasMaskContent = renderingTargets.contains { $0.value.kind == "mask" }
            || subtreeIndices.contains { subtreeIndex in
                let values = resolvedStyles[subtreeIndex] ?? [:]
                return ["mask-image", "-webkit-mask-image"].contains { property in
                    guard let value = values[property]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    else { return false }
                    return !value.isEmpty && value != "none"
                }
            }
        return OpenGraphiteNodeCapabilityEvidence(
            isProjectResourceRoot: index == projectResourceRootIndex,
            isNativeControl: isNativeControl,
            isCustomElement: Self.isValidCustomElementName(tag.tagName)
                || Self.isValidCustomElementName(tag.emptyNilAttribute(named: "is") ?? ""),
            isLink: isLink,
            hasDirectText: hasDirectTextContent(for: index, records: records),
            hasElementChildren: records.contains { $0.parentIndex == index },
            hasMediaContent: hasMediaContent,
            hasSVGContent: hasSVGContent,
            hasMaskContent: hasMaskContent,
            ariaRole: ariaRole,
            resolvedDisplay: resolvedStyles[index]?["display"]
        )
    }

    /// authored parent chainだけをたどり、対象recordが指定ancestorのsubtreeに属するかを返します。
    private func isAuthoredDescendant(
        _ candidateIndex: Int,
        of ancestorIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        var cursor = records[candidateIndex].parentIndex
        while let current = cursor {
            if current == ancestorIndex { return true }
            cursor = records[current].parentIndex
        }
        return false
    }

    /// 論理名（日本語）: ノード操作能力導出関数
    /// 処理概要: capability evidenceとDOM親/CSS positionをoperationごとに判定し、raw value昇順の決定的配列を返します。
    ///
    /// - Parameters:
    ///   - index: 対象authored DOM record index。
    ///   - records: authored DOM record一覧。
    ///   - resolvedStyles: 対象と親のcomputed CSS値。
    ///   - evidence: legacy typeに依存せず導出済みのsemantic evidence。
    ///   - projectResourceBoundaryIndices: project body直下のresource境界。複数root候補も移動/groupを保守拒否します。
    /// - Returns: mutation authorizationへ使うoperation capability配列。
    private func capabilities(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        resolvedStyles: [Int: [String: String]],
        evidence: OpenGraphiteNodeCapabilityEvidence,
        projectResourceBoundaryIndices: Set<Int>
    ) -> [OpenGraphiteNodeCapability] {
        let tag = records[index].tag
        let isOperational = !Self.nonOperationalElementNames.contains(tag.tagName)
            && !["html", "head", "body"].contains(tag.tagName)
        let isLayoutOperational = !Self.nonOperationalElementNames.contains(tag.tagName)
            && !["html", "head"].contains(tag.tagName)
        let targetIsHTMLNamespace = isHTMLNamespace(for: index, records: records)
        let canReceiveChildren = Self.canReceiveChildren(tag, isHTMLNamespace: targetIsHTMLNamespace)
        let cannotEditDOMText = Self.controlTextContentElementNames.contains(tag.tagName)
        let isTextSemantic = Self.textSemanticElementNames.contains(tag.tagName)
            || evidence.ariaRole == "textbox"
            || isEffectivelyContentEditable(index, records: records)
        let isInteractiveARIA = evidence.ariaRole.map(Self.interactiveARIARoles.contains) == true
        let hasAuthoredHref = tag.attributes.contains {
            $0.name.caseInsensitiveCompare("href") == .orderedSame
        }
        let canEditLink = hasAuthoredHref
            && (["a", "area"].contains(tag.tagName) || evidence.ariaRole == "link")
        let position = resolvedStyles[index]?["position"]?.lowercased() ?? "static"
        let display = resolvedStyles[index]?["display"]?.lowercased() ?? "block"
        let isPositionedForDragging = position == "absolute" || position == "fixed"
        let isProjectResourceBoundary = projectResourceBoundaryIndices.contains(index)
        let parentCanReceiveFlow: Bool
        let parentAllowsGenericGrouping: Bool
        if let parentIndex = records[index].parentIndex {
            let parentDisplay = resolvedStyles[parentIndex]?["display"]?.lowercased() ?? "block"
            let parentIsHTMLNamespace = isHTMLNamespace(for: parentIndex, records: records)
            parentCanReceiveFlow = Self.canReorderChild(
                tag,
                in: records[parentIndex].tag,
                childIsHTMLNamespace: targetIsHTMLNamespace,
                parentIsHTMLNamespace: parentIsHTMLNamespace
            )
                && parentDisplay != "none"
                && parentDisplay != "contents"
            parentAllowsGenericGrouping = Self.canReceiveChildren(
                records[parentIndex].tag,
                isHTMLNamespace: parentIsHTMLNamespace
            )
                && parentDisplay != "none"
                && parentDisplay != "contents"
        } else {
            parentCanReceiveFlow = false
            parentAllowsGenericGrouping = false
        }

        var result: Set<OpenGraphiteNodeCapability> = []
        if canReceiveChildren { result.insert(.receiveChildren) }
        if !Self.nonTextEditableElementNames.contains(tag.tagName),
           !cannotEditDOMText,
           evidence.hasDirectText || isTextSemantic {
            result.insert(.editText)
        }
        if canEditLink { result.insert(.editLink) }
        if evidence.hasMediaContent { result.insert(.editMedia) }
        if evidence.hasSVGContent || evidence.hasMaskContent || Self.hasIconProvenance(tag) {
            result.insert(.editIcon)
        }
        if evidence.isNativeControl
            || isInteractiveARIA
            || (evidence.ariaRole == "link" && !canEditLink) {
            result.insert(.editControl)
        }
        if isLayoutOperational { result.insert(.editLayout) }
        if isOperational, !isProjectResourceBoundary, isPositionedForDragging {
            result.insert(.dragPosition)
        }
        if isOperational,
           !isProjectResourceBoundary,
           !isPositionedForDragging,
           display != "none",
           display != "contents",
           parentCanReceiveFlow {
            result.insert(.reorderFlow)
        }
        if isOperational,
           !isProjectResourceBoundary,
           parentAllowsGenericGrouping {
            result.insert(.group)
        }
        if isOperational,
           !isProjectResourceBoundary,
           evidence.hasElementChildren,
           Self.safeUngroupHostElementNames.contains(tag.tagName),
           parentAllowsGenericGrouping {
            result.insert(.ungroup)
        }
        return result.sorted { $0.rawValue < $1.rawValue }
    }

    /// nodeが標準DOM childを安全に受け取れるかをtag semanticsから判定します。
    private static func canReceiveChildren(
        _ tag: OpenGraphiteHTMLTag,
        isHTMLNamespace: Bool = true
    ) -> Bool {
        guard isHTMLNamespace,
              !tag.selfClosing,
              !voidElementNames.contains(tag.tagName),
              !rawTextElementNames.contains(tag.tagName),
              !nonOperationalElementNames.contains(tag.tagName),
              !svgElementNames.contains(tag.tagName)
        else { return false }
        return genericFlowContainerElementNames.contains(tag.tagName)
            || tag.tagName.contains("-")
            || !standardHTMLElementNames.contains(tag.tagName)
    }

    /// 既存semantic siblingを親内で並べ替えてもcontent modelを壊さない組合せを返します。
    private static func canReorderChild(
        _ child: OpenGraphiteHTMLTag,
        in parent: OpenGraphiteHTMLTag,
        childIsHTMLNamespace: Bool = true,
        parentIsHTMLNamespace: Bool = true
    ) -> Bool {
        guard childIsHTMLNamespace, parentIsHTMLNamespace else { return false }
        if canReceiveChildren(parent, isHTMLNamespace: true) { return true }
        switch parent.tagName {
        case "ul", "ol", "menu":
            return child.tagName == "li"
        case "thead", "tbody", "tfoot":
            return child.tagName == "tr"
        case "tr":
            return child.tagName == "td" || child.tagName == "th"
        case "optgroup":
            return child.tagName == "option"
        case "colgroup":
            return child.tagName == "col"
        default:
            return false
        }
    }

    /// Authored ancestor chainをHTML/SVG/MathML namespaceへ投影し、foreignObject integration pointだけHTMLへ復帰させます。
    private func isHTMLNamespace(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        var path: [Int] = []
        var cursor: Int? = index
        while let current = cursor {
            path.append(current)
            cursor = records[current].parentIndex
        }
        var namespace = "html"
        var parentTagName: String?
        for current in path.reversed() {
            let tagName = records[current].tag.tagName
            if namespace == "svg", parentTagName == "foreignobject" {
                namespace = "html"
            }
            if namespace == "html" {
                if tagName == "svg" {
                    namespace = "svg"
                } else if tagName == "math" {
                    namespace = "mathml"
                }
            }
            parentTagName = tagName
        }
        return namespace == "html"
    }

    /// HTML custom element名またはcustomized built-inの`is`値として使える保守的なhyphenated名かを返します。
    private static func isValidCustomElementName(_ value: String) -> Bool {
        value.range(of: #"^[a-z][a-z0-9._-]*-[a-z0-9._-]+$"#, options: .regularExpression) != nil
    }

    /// 論理名（日本語）: 編集可能属性対象判定関数
    /// 処理概要: 契約に列挙された標準属性を、実際のHTML targetとoperation capabilityへ対応付けて誤った要素への追加を拒否します。
    ///
    /// - Parameters:
    ///   - name: ASCII lowercaseへ正規化済みの属性名。
    ///   - tag: 属性を更新するauthored HTML tag。
    ///   - node: 同じtagから導出済みのAgent node。
    /// - Returns: targetへ属性を設定または削除してよい場合は`true`。
    private static func canSetEditableAttribute(
        _ name: String,
        on tag: OpenGraphiteHTMLTag,
        node: OpenGraphiteAgentNode
    ) -> Bool {
        let hasAttribute: (String) -> Bool = { attributeName in
            tag.attributes.contains {
                $0.name.caseInsensitiveCompare(attributeName) == .orderedSame
            }
        }
        switch name {
        case "hidden":
            return node.supports(.editLayout)
        case "href":
            return node.supports(.editLink) && hasAttribute("href")
        case "target":
            return node.supports(.editLink)
                && (["a", "area"].contains(tag.tagName) || hasAttribute("target"))
        case "aria-label":
            return node.supports(.editControl)
        case "value":
            return valueAttributeElementNames.contains(tag.tagName)
        case "src":
            return node.supports(.editMedia) && sourceAttributeMediaElementNames.contains(tag.tagName)
        case "alt":
            return node.supports(.editMedia) && tag.tagName == "img"
        case "data-og-icon-library", "data-og-icon-name", "data-og-icon-source":
            return node.supports(.editIcon) && hasIconProvenance(tag)
        default:
            return true
        }
    }

    /// OpenGraphite固有typeではなく、存在するicon metadataが実描画provenanceを示すかを判定します。
    private static func hasIconProvenance(_ tag: OpenGraphiteHTMLTag) -> Bool {
        ["data-og-icon-library", "data-og-icon-name", "data-og-icon-source"].contains {
            tag.emptyNilAttribute(named: $0) != nil
        }
    }

    /// ARIA role fallback listから最初に認識できる標準roleをASCII case-insensitiveに返します。
    private static func semanticARIARole(_ authoredValue: String?) -> String? {
        guard let authoredValue else { return nil }
        return authoredValue
            .split(whereSeparator: Self.isHTMLASCIIWhitespace)
            .map { $0.lowercased() }
            .first(where: recognizedARIARoles.contains)
    }

    /// authored parent chainからHTML contenteditable継承状態を解決します。
    private func isEffectivelyContentEditable(
        _ index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        var cursor: Int? = index
        while let current = cursor {
            let tag = records[current].tag
            if tag.attributes.contains(where: {
                $0.name.caseInsensitiveCompare("contenteditable") == .orderedSame
            }) {
                let value = Self.asciiLowercased(
                    tag.attributeValue(named: "contenteditable") ?? ""
                )
                if value.isEmpty || value == "true" || value == "plaintext-only" { return true }
                if value == "false" { return false }
            }
            cursor = records[current].parentIndex
        }
        return false
    }

    /// direct child element範囲を除いたsource本文にtext nodeが存在するかを判定します。
    private func hasDirectTextContent(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        guard let containerElement = element(for: records[index]), !containerElement.contentRange.isEmpty else {
            return false
        }
        let childRanges = records.indices
            .filter { records[$0].parentIndex == index }
            .compactMap { element(for: records[$0])?.fullRange }
            .sorted { $0.lowerBound < $1.lowerBound }
        var cursor = containerElement.contentRange.lowerBound
        var directSource = ""
        for childRange in childRanges where childRange.lowerBound < containerElement.contentRange.upperBound {
            if cursor < childRange.lowerBound {
                directSource += html.substring(cursor..<min(childRange.lowerBound, containerElement.contentRange.upperBound))
            }
            cursor = max(cursor, min(childRange.upperBound, containerElement.contentRange.upperBound))
        }
        if cursor < containerElement.contentRange.upperBound {
            directSource += html.substring(cursor..<containerElement.contentRange.upperBound)
        }
        return Self.containsDirectTextToken(directSource)
    }

    /// direct source片からcomment/tag triviaを飛ばし、text tokenが残るかを判定します。
    private static func containsDirectTextToken(_ source: String) -> Bool {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            if Self.isHTMLASCIIWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            if source[cursor...].hasPrefix("<!--") {
                guard let end = Self.htmlCommentEnd(in: source, from: cursor) else { return false }
                cursor = end
                continue
            }
            if source[cursor...].hasPrefix("<![CDATA[") {
                let start = source.index(cursor, offsetBy: 9)
                let end = source.range(of: "]]>", range: start..<source.endIndex)?.lowerBound ?? source.endIndex
                return source[start..<end].contains { !Self.isHTMLASCIIWhitespace($0) }
            }
            if source[cursor] == "<" {
                guard let end = source[cursor...].firstIndex(of: ">") else { return true }
                cursor = source.index(after: end)
                continue
            }
            return true
        }
        return false
    }

    /// annotationに依存せず標準ID、DOM path、source range、content hashを組み合わせたlocatorを返します。
    private func nodeLocator(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        documentURL: String
    ) -> OpenGraphiteNodeLocator {
        let record = records[index]
        let sourceRange = element(for: record)?.fullRange ?? record.tag.range
        let sourceHTML = html.substring(sourceRange)
        let selector = uniqueStandardIDSelector(for: index, records: records)
            ?? uniqueAuthoredSelector(for: index, records: records)
            ?? uniqueAnnotationSelector(for: index, records: records)
        return OpenGraphiteNodeLocator(
            documentURL: documentURL,
            selector: selector,
            domPath: domPath(for: index, records: records),
            sourceRange: OpenGraphiteSourceRange(start: sourceRange.lowerBound, end: sourceRange.upperBound),
            contentHash: Self.contentHash(sourceHTML)
        )
    }

    /// 一意なinternal IDがある場合はstable、ない場合はsource revision scoped referenceを生成します。
    private func nodeReference(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        locator: OpenGraphiteNodeLocator,
        internalIDCounts: [String: Int]
    ) -> (value: String, stability: OpenGraphiteNodeReferenceStability) {
        let documentIdentity = locator.documentURL.isEmpty
            ? Self.contentHash(html)
            : Self.contentHash(locator.documentURL)
        if let internalID = records[index].tag.emptyNilAttribute(named: "data-og-internal-id"),
           internalIDCounts[internalID] == 1,
           !records[index].tag.containsUnresolvedHTMLCharacterReference(
               named: "data-og-internal-id"
           ) {
            return (
                "ogref:node:standalone:\(documentIdentity):\(internalID)",
                .stable
            )
        }
        return (revisionScopedReference(locator: locator), .session)
    }

    /// annotation有無に関係なくsource revisionを照合するinspection用graph session referenceを生成します。
    private func revisionScopedReference(locator: OpenGraphiteNodeLocator) -> String {
        let documentIdentity = locator.documentURL.isEmpty
            ? Self.contentHash(html)
            : Self.contentHash(locator.documentURL)
        return "ogref-session:node:\(documentIdentity):\(Self.contentHash(locator.domPath)):\(locator.sourceRange.start)-\(locator.sourceRange.end):\(locator.contentHash)"
    }

    /// source revisionと正規化済みadoption parameterを束縛したapply専用proposal snapshot tokenを生成します。
    private func adoptionProposalReference(
        locator: OpenGraphiteNodeLocator,
        scope: OpenGraphiteNodeAdoptionScope,
        displayID: String?
    ) -> String {
        let documentIdentity = locator.documentURL.isEmpty
            ? Self.contentHash(html)
            : Self.contentHash(locator.documentURL)
        let displayIDComponent = displayID.map { "value:\($0.utf8.count):\($0)" } ?? "none"
        let proposalSeed = [
            "adoption-proposal:v1",
            "document-content-hash:\(Self.contentHash(html))",
            "scope:\(scope.rawValue)",
            "display-id:\(displayIDComponent)"
        ].joined(separator: "|")
        return "ogref-session:adoption:\(documentIdentity):\(Self.contentHash(locator.domPath)):\(locator.sourceRange.start)-\(locator.sourceRange.end):\(locator.contentHash):\(Self.contentHash(proposalSeed))"
    }

    /// tag名と`:nth-of-type()`を全階層へ付けた一意なDOM pathを返します。
    private func domPath(for index: Int, records: [OpenGraphiteHTMLDOMRecord]) -> String {
        var segments: [String] = []
        var cursor: Int? = index
        while let current = cursor {
            let record = records[current]
            segments.append("\(record.tag.tagName):nth-of-type(\(record.element.typeIndex))")
            cursor = record.parentIndex
        }
        return segments.reversed().joined(separator: " > ")
    }

    /// recordが指定祖先のsubtreeに含まれるかを親indexで判定します。
    private func isDescendant(
        _ index: Int,
        of ancestorIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        var cursor = records[index].parentIndex
        while let current = cursor {
            if current == ancestorIndex { return true }
            cursor = records[current].parentIndex
        }
        return false
    }

    /// 既存`data-og-id`と衝突しないadoption用display IDを決定します。
    private static func uniqueAdoptionID(base: String, used: inout Set<String>) -> String {
        let normalizedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = normalizedBase.isEmpty ? "node" : normalizedBase
        var candidate = seed
        var suffix = 2
        while used.contains(candidate) {
            candidate = "\(seed)-\(suffix)"
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    /// 開始tagの既存bytesを再直列化せず、閉じ山括弧直前へ新規属性だけを挿入します。
    private static func insertAttributes(
        _ attributes: [(name: String, value: String)],
        into source: inout String,
        tag: OpenGraphiteHTMLTag
    ) {
        applyAttributeChanges(
            attributes.map { (name: $0.name, value: Optional($0.value)) },
            into: &source,
            tag: tag
        )
    }

    /// 開始tagのraw bytesを保ったまま、指定属性だけを追加・更新・削除します。
    ///
    /// - Parameters:
    ///   - changes: 属性名と新しいsemantic値。`nil`は同名case-insensitive属性をすべて削除します。
    ///   - source: 更新対象HTML source。
    ///   - tag: 変更対象の開始tag。
    private static func applyAttributeChanges(
        _ changes: [(name: String, value: String?)],
        into source: inout String,
        tag: OpenGraphiteHTMLTag
    ) {
        guard !changes.isEmpty else { return }
        let tagStart = source.index(source.startIndex, offsetBy: tag.range.lowerBound)
        let tagEnd = source.index(source.startIndex, offsetBy: tag.range.upperBound)
        var rawTag = String(source[tagStart..<tagEnd])
        var attributesToInsert: [(name: String, value: String)] = []
        for change in changes {
            if let value = change.value {
                if !replaceAttributeValueIfPresent(change.name, value: value, in: &rawTag) {
                    attributesToInsert.append((change.name, value))
                }
            } else {
                while removeAttributeIfPresent(change.name, in: &rawTag) {}
            }
        }
        if !attributesToInsert.isEmpty, let closeIndex = rawTag.lastIndex(of: ">") {
            var cursor = closeIndex
            while cursor > rawTag.startIndex {
                let previous = rawTag.index(before: cursor)
                if Self.isHTMLASCIIWhitespace(rawTag[previous]) {
                    cursor = previous
                    continue
                }
                break
            }
            var insertionIndex = cursor
            if tag.lexicalSelfClosing, cursor > rawTag.startIndex {
                let previous = rawTag.index(before: cursor)
                if rawTag[previous] == "/" {
                    insertionIndex = previous
                    while insertionIndex > rawTag.startIndex {
                        let beforeSlash = rawTag.index(before: insertionIndex)
                        guard Self.isHTMLASCIIWhitespace(rawTag[beforeSlash]) else { break }
                        insertionIndex = beforeSlash
                    }
                }
            }
            let serialized = attributesToInsert.map { attribute in
                " \(attribute.name)=\"\(escapeAdoptionAttributeValue(attribute.value))\""
            }.joined()
            rawTag.insert(contentsOf: serialized, at: insertionIndex)
        }
        source.replaceSubrange(tagStart..<tagEnd, with: rawTag)
    }

    /// 既存class属性値のraw entity/quote/triviaを保持し、migration専用tokenだけを末尾へ追加します。
    private static func appendClassTokens(
        _ tokens: [String],
        into source: inout String,
        tag: OpenGraphiteHTMLTag
    ) {
        guard !tokens.isEmpty else { return }
        guard let valueRange = OpenGraphiteHTMLDocument(html: source)
            .attributeValueRange(named: "class", for: tag)
        else {
            applyAttributeChanges(
                [("class", tokens.joined(separator: " "))],
                into: &source,
                tag: tag
            )
            return
        }
        let rawValue = source.substring(valueRange)
        let separator = rawValue.isEmpty || rawValue.last.map(Self.isHTMLASCIIWhitespace) == true ? "" : " "
        let addition = separator + tokens.joined(separator: " ")
        let valueStart = source.index(source.startIndex, offsetBy: valueRange.lowerBound)
        let isQuoted = valueStart > source.startIndex && {
            let previous = source[source.index(before: valueStart)]
            return previous == "\"" || previous == "'"
        }()
        if isQuoted {
            source.insert(addition, atOffset: valueRange.upperBound)
        } else {
            source.replaceRange(valueRange, with: "\"\(rawValue)\(addition)\"")
        }
    }

    /// 開始tag内に同名属性があれば値部分だけを置換し、authored quoteとtriviaを保持します。
    private static func replaceAttributeValueIfPresent(
        _ name: String,
        value: String,
        in rawTag: inout String
    ) -> Bool {
        var index = rawTag.startIndex
        guard index < rawTag.endIndex, rawTag[index] == "<" else { return false }
        index = rawTag.index(after: index)
        while index < rawTag.endIndex,
              !Self.isHTMLASCIIWhitespace(rawTag[index]),
              rawTag[index] != "/",
              rawTag[index] != ">" {
            index = rawTag.index(after: index)
        }

        while index < rawTag.endIndex {
            while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                index = rawTag.index(after: index)
            }
            guard index < rawTag.endIndex, rawTag[index] != "/", rawTag[index] != ">" else {
                return false
            }

            let nameStart = index
            while index < rawTag.endIndex,
                  !Self.isHTMLASCIIWhitespace(rawTag[index]),
                  rawTag[index] != "=",
                  rawTag[index] != "/",
                  rawTag[index] != ">" {
                index = rawTag.index(after: index)
            }
            let nameEnd = index
            let attributeName = String(rawTag[nameStart..<index])
            while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                index = rawTag.index(after: index)
            }

            guard index < rawTag.endIndex, rawTag[index] == "=" else {
                if attributeName.caseInsensitiveCompare(name) == .orderedSame {
                    if value.isEmpty {
                        return true
                    }
                    let escaped = escapeAdoptionAttributeValue(value)
                    rawTag.replaceSubrange(nameStart..<nameEnd, with: "\(attributeName)=\"\(escaped)\"")
                    return true
                }
                continue
            }
            index = rawTag.index(after: index)
            while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                index = rawTag.index(after: index)
            }

            let valueStart: String.Index
            let valueEnd: String.Index
            let quote: Character?
            if index < rawTag.endIndex, rawTag[index] == "\"" || rawTag[index] == "'" {
                quote = rawTag[index]
                valueStart = rawTag.index(after: index)
                var cursor = valueStart
                while cursor < rawTag.endIndex, rawTag[cursor] != quote {
                    cursor = rawTag.index(after: cursor)
                }
                valueEnd = cursor
                index = cursor < rawTag.endIndex ? rawTag.index(after: cursor) : cursor
            } else {
                quote = nil
                valueStart = index
                while index < rawTag.endIndex,
                      !Self.isHTMLASCIIWhitespace(rawTag[index]),
                      rawTag[index] != ">" {
                    index = rawTag.index(after: index)
                }
                valueEnd = index
            }

            if attributeName.caseInsensitiveCompare(name) == .orderedSame {
                let authoredValue = String(rawTag[valueStart..<valueEnd])
                if decodingHTMLTextCharacterReferences(authoredValue) == value {
                    if value.isEmpty, quote == nil {
                        rawTag.replaceSubrange(valueStart..<valueEnd, with: "\"\"")
                    }
                    return true
                }
                let escaped = escapeAdoptionAttributeValue(value)
                rawTag.replaceSubrange(
                    valueStart..<valueEnd,
                    with: quote == nil && isSafeUnquotedAttributeValue(value)
                        ? escaped
                        : (quote == nil ? "\"\(escaped)\"" : escaped)
                )
                return true
            }
        }
        return false
    }

    /// 開始tagから同名属性tokenを1件だけ削除し、周囲のauthored whitespaceを保持します。
    ///
    /// - Parameters:
    ///   - name: case-insensitiveに照合する属性名。
    ///   - rawTag: 更新対象の開始tag source。
    /// - Returns: 属性を削除した場合は`true`。
    private static func removeAttributeIfPresent(_ name: String, in rawTag: inout String) -> Bool {
        var index = rawTag.startIndex
        guard index < rawTag.endIndex, rawTag[index] == "<" else { return false }
        index = rawTag.index(after: index)
        while index < rawTag.endIndex,
              !Self.isHTMLASCIIWhitespace(rawTag[index]),
              rawTag[index] != "/",
              rawTag[index] != ">" {
            index = rawTag.index(after: index)
        }

        while index < rawTag.endIndex {
            let separatorStart = index
            while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                index = rawTag.index(after: index)
            }
            guard index < rawTag.endIndex, rawTag[index] != "/", rawTag[index] != ">" else {
                return false
            }

            let nameStart = index
            while index < rawTag.endIndex,
                  !Self.isHTMLASCIIWhitespace(rawTag[index]),
                  rawTag[index] != "=",
                  rawTag[index] != "/",
                  rawTag[index] != ">" {
                index = rawTag.index(after: index)
            }
            let nameEnd = index
            let attributeName = String(rawTag[nameStart..<index])
            while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                index = rawTag.index(after: index)
            }

            var attributeEnd = nameEnd
            if index < rawTag.endIndex, rawTag[index] == "=" {
                index = rawTag.index(after: index)
                while index < rawTag.endIndex, Self.isHTMLASCIIWhitespace(rawTag[index]) {
                    index = rawTag.index(after: index)
                }
                if index < rawTag.endIndex, rawTag[index] == "\"" || rawTag[index] == "'" {
                    let quote = rawTag[index]
                    index = rawTag.index(after: index)
                    while index < rawTag.endIndex, rawTag[index] != quote {
                        index = rawTag.index(after: index)
                    }
                    if index < rawTag.endIndex {
                        index = rawTag.index(after: index)
                    }
                } else {
                    while index < rawTag.endIndex,
                          !Self.isHTMLASCIIWhitespace(rawTag[index]),
                          rawTag[index] != ">" {
                        index = rawTag.index(after: index)
                    }
                }
                attributeEnd = index
            }

            if attributeName.caseInsensitiveCompare(name) == .orderedSame {
                rawTag.removeSubrange(separatorStart..<attributeEnd)
                return true
            }
        }
        return false
    }

    /// adoption identityを既存attribute quote内へ安全に保存するescape値を返します。
    private static func escapeAdoptionAttributeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    /// semantic属性値を既存unquoted形式のまま保存できるかをHTML forbidden characterで判定します。
    private static func isSafeUnquotedAttributeValue(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { character in
            !Self.isHTMLASCIIWhitespace(character)
                && character != "\""
                && character != "'"
                && character != "`"
                && character != "="
                && character != "<"
                && character != ">"
        }
    }

    /// DOM順に親のresolved値を渡し、custom propertyと継承を含むcascade traceを構築します。
    private func cascadeTraces(
        for records: [OpenGraphiteHTMLDOMRecord],
        sourceDocument: OpenGraphiteCSSSourceDocument?,
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> [Int: OpenGraphiteCSSCascadeTrace] {
        let parsedStylesheets: [OpenGraphiteCSSParsedStylesheetSource] = sourceDocument.map { document in
            let stylesheet = OpenGraphiteCSSStylesheetSource(
                sourceID: "companion-css",
                sourceKind: "companion",
                source: document.source,
                editable: true
            )
            return [OpenGraphiteCSSParsedStylesheetSource(
                stylesheet: stylesheet,
                document: document,
                containsDynamicKeyframes: OpenGraphiteCSSSourceDocument.containsDynamicKeyframes(
                    in: document.source
                )
            )]
        } ?? []
        return cascadeTraces(
            for: records,
            parsedStylesheets: parsedStylesheets,
            environment: environment
        )
    }

    /// 独立stylesheet境界とsource originを保ってDOM順にcascade traceを構築します。
    private func cascadeTraces(
        for records: [OpenGraphiteHTMLDOMRecord],
        stylesheetSources: [OpenGraphiteCSSStylesheetSource],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> [Int: OpenGraphiteCSSCascadeTrace] {
        cascadeTraces(
            for: records,
            parsedStylesheets: OpenGraphiteCSSSourceDocument.parseStylesheets(stylesheetSources),
            environment: environment
        )
    }

    /// 論理名（日本語）: 解析済みmulti-stylesheet DOM cascade構築関数
    /// 処理概要: 1つのDOM graph内でstylesheet ASTを再利用し、親から子へcomputed値を継承してtraceを構築します。
    ///
    /// - Parameters:
    ///   - records: authored DOM record一覧。
    ///   - parsedStylesheets: document orderとorigin metadataを保持する解析済みstylesheet一覧。
    ///   - environment: active media condition集合。
    /// - Returns: authored record indexごとのcascade trace。
    private func cascadeTraces(
        for records: [OpenGraphiteHTMLDOMRecord],
        parsedStylesheets: [OpenGraphiteCSSParsedStylesheetSource],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> [Int: OpenGraphiteCSSCascadeTrace] {
        let projection = OpenGraphiteCSSDOMProjection.browserDocument(
            from: records.map {
                OpenGraphiteCSSDOMSourceNode(element: $0.element, parentIndex: $0.parentIndex)
            }
        )
        var projectedTraces: [Int: OpenGraphiteCSSCascadeTrace] = [:]
        var sourceTraces: [Int: OpenGraphiteCSSCascadeTrace] = [:]
        for projectedIndex in projection.nodes.indices {
            let projectedNode = projection.nodes[projectedIndex]
            let inheritedValues = projectedNode.parentIndex.flatMap {
                projectedTraces[$0]?.resolvedValues
            } ?? [:]
            var trace = OpenGraphiteCSSSourceDocument.cascadeTrace(
                for: projectedNode.element,
                parsedStylesheets: parsedStylesheets,
                inheritedValues: inheritedValues,
                environment: environment
            )
            if let sourceIndex = projectedNode.sourceIndex {
                mergeInlineStyle(
                    for: records[sourceIndex].tag,
                    into: &trace,
                    inheritedValues: inheritedValues
                )
            }
            if let parentIndex = projectedNode.parentIndex,
               let parentTrace = projectedTraces[parentIndex] {
                for (property, parentCandidates) in parentTrace.candidates
                where OpenGraphiteCSSSourceDocument.isInheritedProperty(property)
                    && trace.candidates[property] == nil {
                    trace.candidates[property] = parentCandidates.map { provenance in
                        var provenance = provenance
                        provenance.inherited = true
                        return provenance
                    }
                }
            }
            if let sourceIndex = projectedNode.sourceIndex {
                sourceTraces[sourceIndex] = trace
            }
            projectedTraces[projectedIndex] = trace
        }
        return sourceTraces
    }

    /// 論理名（日本語）: 標準CSS headless解決関数
    /// 処理概要: authored cascade値へHTML UA既定と標準hidden属性を非永続のinspection fallbackとして重ねます。
    ///
    /// - Parameters:
    ///   - index: authored DOM record内の対象index。
    ///   - records: parent/sibling文脈とHTML属性を保持するauthored DOM records。
    ///   - trace: project / companion / inline sourceを評価したcascade trace。
    /// - Returns: sourceを書き換えずにlayout・visibility inspectionへ使うresolved標準CSS値。
    private func resolvedStandardStyle(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        trace: OpenGraphiteCSSCascadeTrace?
    ) -> [String: String] {
        let tag = records[index].tag
        var resolved = trace?.resolvedValues ?? [:]
        resolved["display"] = resolved["display"] ?? defaultDisplay(for: index, records: records)
        resolved["flex-direction"] = resolved["flex-direction"] ?? "row"
        resolved["position"] = resolved["position"] ?? "static"
        resolved["visibility"] = resolved["visibility"] ?? "visible"
        resolved["overflow-wrap"] = resolved["overflow-wrap"] ?? "normal"
        resolved["grid-template-columns"] = resolved["grid-template-columns"] ?? "none"
        resolved["grid-template-rows"] = resolved["grid-template-rows"] ?? "none"
        resolved["grid-auto-columns"] = resolved["grid-auto-columns"] ?? "auto"
        resolved["grid-auto-rows"] = resolved["grid-auto-rows"] ?? "auto"
        resolved["grid-auto-flow"] = resolved["grid-auto-flow"] ?? "row"
        resolved["grid-column"] = resolved["grid-column"] ?? "auto"
        resolved["grid-row"] = resolved["grid-row"] ?? "auto"
        resolved["content-visibility"] = resolved["content-visibility"]
            ?? (hasUntilFoundHiddenValue(tag) ? "hidden" : "visible")
        if hasStandardHiddenAttribute(tag),
           trace?.winners["display"] == nil,
           tag.tagName != "embed",
           !hasUntilFoundHiddenValue(tag) {
            resolved["display"] = "none"
        }
        return resolved
    }

    /// 標準`hidden`属性がcase-insensitiveなHTML attributeとして存在するかを返します。
    private func hasStandardHiddenAttribute(_ tag: OpenGraphiteHTMLTag) -> Bool {
        tag.attributes.contains { $0.name.caseInsensitiveCompare("hidden") == .orderedSame }
    }

    /// `hidden="until-found"`をHTMLのASCII case-insensitive keywordとして判定します。
    private func hasUntilFoundHiddenValue(_ tag: OpenGraphiteHTMLTag) -> Bool {
        tag.attributeValue(named: "hidden").map(Self.asciiLowercased) == "until-found"
    }

    /// HTML要素のtag・属性・親/sibling文脈に対応するUA既定displayをsourceへ保存せず返します。
    private func defaultDisplay(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String {
        let tag = records[index].tag
        switch tag.tagName.lowercased() {
        case "head", "area", "base", "basefont", "datalist", "link", "meta", "noembed",
             "noframes", "noscript", "param", "rp", "style", "title", "script", "template":
            return "none"
        case "dialog":
            return tag.attributes.contains { $0.name.caseInsensitiveCompare("open") == .orderedSame }
                ? "block"
                : "none"
        case "input":
            let inputType = tag.attributeValue(named: "type").map(Self.asciiLowercased)
            return inputType == "hidden"
                ? "none"
                : "inline-block"
        case "summary":
            guard let parentIndex = records[index].parentIndex,
                  records[parentIndex].tag.tagName == "details"
            else { return "block" }
            let hasEarlierSummary = records.indices.contains { siblingIndex in
                siblingIndex < index
                    && records[siblingIndex].parentIndex == parentIndex
                    && records[siblingIndex].tag.tagName == "summary"
            }
            return hasEarlierSummary ? "block" : "list-item"
        case "slot":
            return "contents"
        case "html", "body", "address", "article", "aside", "blockquote", "details",
             "div", "dl", "fieldset", "figcaption", "figure", "footer", "form", "header", "hgroup",
             "legend", "main", "menu", "nav", "ol", "p", "pre", "search", "section", "ul",
             "h1", "h2", "h3", "h4", "h5", "h6", "hr":
            return "block"
        case "li":
            return "list-item"
        case "table":
            return "table"
        case "caption":
            return "table-caption"
        case "colgroup":
            return "table-column-group"
        case "col":
            return "table-column"
        case "thead":
            return "table-header-group"
        case "tbody":
            return "table-row-group"
        case "tfoot":
            return "table-footer-group"
        case "tr":
            return "table-row"
        case "td", "th":
            return "table-cell"
        case "button", "select", "textarea":
            return "inline-block"
        default:
            return "inline"
        }
    }

    /// resolved `display`と`flex-direction`から既存graph互換のlayout表示値を導出します。
    private func derivedLayout(from resolvedValues: [String: String]) -> String? {
        let authoredDisplay = resolvedValues["display"]
            .map(Self.trimmingASCIIWhitespace) ?? ""
        guard !authoredDisplay.isEmpty else { return nil }
        let display = authoredDisplay.lowercased()
        let displayTokens = Set(display.split(whereSeparator: Self.isCSSASCIIWhitespace).map(String.init))
        if displayTokens.contains("flex") || displayTokens.contains("inline-flex") {
            let direction = resolvedValues["flex-direction"]?.lowercased() ?? "row"
            return direction.hasPrefix("column") ? "vertical" : "horizontal"
        }
        if displayTokens.contains("grid") || displayTokens.contains("inline-grid") {
            return "grid"
        }
        return display
    }

    /// inline styleをauthor stylesheet traceへcascadeし、子へ渡すcomputed値とprovenanceを統合します。
    private func mergeInlineStyle(
        for tag: OpenGraphiteHTMLTag,
        into trace: inout OpenGraphiteCSSCascadeTrace,
        inheritedValues: [String: String]
    ) {
        for inlineValue in inlineStyleValueList(for: tag) {
            let authoredDeclaration = OpenGraphiteCSSSourceDeclaration(
                name: inlineValue.property,
                value: inlineValue.value,
                important: inlineValue.important,
                range: inlineValue.declarationRange,
                valueRange: inlineValue.valueRange,
                sourceOrder: 1_000_000_000 + inlineValue.sourceOrder
            )
            let expandedProperties = OpenGraphiteCSSSourceDocument.expandedProperties(
                for: authoredDeclaration
            )
            if expandedProperties.isEmpty {
                trace.incompleteProperties.formUnion(
                    OpenGraphiteCSSSourceDocument.incompleteProperties(for: authoredDeclaration)
                )
            }
            for (property, expandedValue) in expandedProperties {
                var declaration = authoredDeclaration
                declaration.value = expandedValue
                let provenance = OpenGraphiteCSSDeclarationProvenance(
                    property: property,
                    authoredProperty: inlineValue.property,
                    selector: "<inline style>",
                    specificity: OpenGraphiteCSSSpecificity(ids: 1_000_000, classes: 0, types: 0),
                    atRules: [],
                    declaration: declaration,
                    sourceID: "<inline style>",
                    sourceKind: "inline",
                    sourceEditable: true,
                    stylesheetOrder: Int.max
                )
                trace.candidates[property, default: []].append(provenance)
                let currentWinner = trace.winners[property]
                let inlineWins = currentWinner?.declaration.important != true
                    || inlineValue.important
                if inlineWins {
                    trace.winners[property] = provenance
                    trace.authoredValues[property] = expandedValue
                }
            }
        }

        OpenGraphiteCSSSourceDocument.resolveComputedValues(
            in: &trace,
            inheritedValues: inheritedValues
        )
    }

    /// OpenGraphite annotation付きの最寄り祖先IDを探索します。
    private func nearestAnnotatedParentID(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String? {
        var cursor = records[index].parentIndex
        while let current = cursor {
            if let id = records[current].tag.emptyNilAttribute(named: "data-og-id") {
                return id
            }
            cursor = records[current].parentIndex
        }
        return nil
    }

    /// wrapper配下の標準media / SVG / mask描画targetをsource cascadeと共に組み立てます。
    private func renderingTargets(
        forWrapperAt wrapperIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        cascadeTraces: [Int: OpenGraphiteCSSCascadeTrace]
    ) -> [OpenGraphiteHTMLRenderingTarget] {
        let subtree = records.indices.filter {
            $0 == wrapperIndex || belongsToRenderingScope($0, wrapperIndex: wrapperIndex, records: records)
        }
        var results: [OpenGraphiteHTMLRenderingTarget] = []

        let mediaIndices = subtree.filter { ["img", "video"].contains(records[$0].tag.tagName) }
        let tracedMediaIndex = mediaIndices.first {
            hasAuthoredProperty("object-fit", record: records[$0], trace: cascadeTraces[$0])
        }
        if let mediaIndex = tracedMediaIndex ?? mediaIndices.first {
            results.append(
                renderingTarget(
                    kind: "media",
                    properties: ["object-fit"],
                    targetIndex: mediaIndex,
                    wrapperIndex: wrapperIndex,
                    records: records,
                    cascadeTraces: cascadeTraces
                )
            )
        }

        let svgElementNames: Set<String> = [
            "svg", "g", "path", "circle", "ellipse", "line", "polyline", "polygon", "rect", "use"
        ]
        let svgIndices = subtree.filter { svgElementNames.contains(records[$0].tag.tagName) }
        let authoredSVGIndices = svgIndices.filter {
            hasAuthoredProperty("stroke-width", record: records[$0], trace: cascadeTraces[$0])
        }
        let tracedSVGIndex = deepestRenderingIndex(
            in: authoredSVGIndices.filter { records[$0].tag.tagName != "svg" },
            records: records
        )
            ?? authoredSVGIndices.first(where: { records[$0].tag.tagName == "svg" })
        let inheritedSVGIndex = deepestRenderingIndex(
            in: svgIndices.filter {
                records[$0].tag.tagName != "svg"
                    && cascadeTraces[$0]?.resolvedValues["stroke-width"] != nil
            },
            records: records
        )
        let fallbackSVGIndex = inheritedSVGIndex
            ?? svgIndices.first(where: { records[$0].tag.tagName == "svg" })
            ?? svgIndices.first
        if let svgIndex = tracedSVGIndex ?? fallbackSVGIndex {
            results.append(
                renderingTarget(
                    kind: "svg",
                    properties: ["stroke-width"],
                    targetIndex: svgIndex,
                    wrapperIndex: wrapperIndex,
                    records: records,
                    cascadeTraces: cascadeTraces
                )
            )
        }

        let maskProperties = ["mask-image", "-webkit-mask-image"]
        let authoredMaskIndices = subtree.filter { index in
            index != wrapperIndex && maskProperties.contains {
                hasAuthoredProperty($0, record: records[index], trace: cascadeTraces[index])
            }
        }
        let tracedMaskIndex = deepestRenderingIndex(in: authoredMaskIndices, records: records)
        let wrapperTag = records[wrapperIndex].tag
        let isCDNIcon = wrapperTag.attributeValue(named: "data-og-icon-source")?.lowercased() == "cdn"
        let fallbackMaskIndex = subtree.first {
            $0 != wrapperIndex
                && records[$0].parentIndex == wrapperIndex
                && ["span", "i"].contains(records[$0].tag.tagName)
                && records[$0].tag.attributeValue(named: "aria-hidden")?.lowercased() == "true"
        }
        if let maskIndex = tracedMaskIndex ?? (isCDNIcon ? fallbackMaskIndex : nil) {
            results.append(
                renderingTarget(
                    kind: "mask",
                    properties: maskProperties,
                    targetIndex: maskIndex,
                    wrapperIndex: wrapperIndex,
                    records: records,
                    cascadeTraces: cascadeTraces
                )
            )
        }
        return results
    }

    /// 描画候補から最深のDOM要素を選び、同じ深さではDOM出現順の先頭を安定して返します。
    private func deepestRenderingIndex(
        in indices: [Int],
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Int? {
        indices.reduce(nil) { best, candidate in
            guard let best else { return candidate }
            return records[candidate].tag.depth > records[best].tag.depth ? candidate : best
        }
    }

    /// 単一の描画targetについて安全なselectorと標準CSS provenanceを生成します。
    private func renderingTarget(
        kind: String,
        properties: [String],
        targetIndex: Int,
        wrapperIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        cascadeTraces: [Int: OpenGraphiteCSSCascadeTrace]
    ) -> OpenGraphiteHTMLRenderingTarget {
        let record = records[targetIndex]
        let trace = cascadeTraces[targetIndex]
        var authoredValues: [String: String] = [:]
        var resolvedValues: [String: String] = [:]
        var sourceTrace: [String: [OpenGraphiteAgentCSSDeclarationTrace]] = [:]
        var inlineWinnerProperties: Set<String> = []
        for property in properties {
            if let resolvedValue = trace?.resolvedValues[property] {
                resolvedValues[property] = resolvedValue
            }
            if let sourceValue = trace?.authoredValues[property] {
                authoredValues[property] = sourceValue
            }
            if trace?.winners[property]?.selector == "<inline style>" {
                inlineWinnerProperties.insert(property)
            }

            var candidates = trace?.candidates[property]?.map { Self.agentTrace($0) } ?? []
            if candidates.isEmpty {
                candidates = inheritedAgentTrace(
                    property: property,
                    targetIndex: targetIndex,
                    records: records,
                    cascadeTraces: cascadeTraces
                )
            }
            if !candidates.isEmpty {
                sourceTrace[property] = candidates
            }
        }
        let relationSelector = relativeSelector(
            from: wrapperIndex,
            to: targetIndex,
            records: records
        )
        let writeSelector = preferredSelector(
            for: targetIndex,
            wrapperIndex: wrapperIndex,
            relationSelector: relationSelector,
            records: records
        )
        return OpenGraphiteHTMLRenderingTarget(
            value: OpenGraphiteAgentRenderingTarget(
                kind: kind,
                tagName: record.tag.tagName,
                relation: targetIndex == wrapperIndex
                    ? "self"
                    : (record.parentIndex == wrapperIndex ? "direct-child" : "descendant"),
                relationSelector: relationSelector,
                writeSelector: writeSelector,
                targetInternalID: record.tag.emptyNilAttribute(named: "data-og-internal-id"),
                authoredValues: authoredValues,
                resolvedValues: resolvedValues,
                sourceTrace: sourceTrace
            ),
            element: record.cssElement,
            tag: record.tag,
            inlineWinnerProperties: inlineWinnerProperties,
            winnerProvenance: Dictionary(
                uniqueKeysWithValues: properties.compactMap { property in
                    trace?.winners[property].map { (property, $0) }
                }
            ),
            hasIncompleteCSSProvenance: trace.map { trace in
                trace.incompleteProperties.contains("*")
                    || !trace.incompleteProperties.isDisjoint(with: Set(properties))
            } ?? false
        )
    }

    /// target自身にsource candidateがない継承propertyについて、最寄り祖先のprovenanceを返します。
    private func inheritedAgentTrace(
        property: String,
        targetIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        cascadeTraces: [Int: OpenGraphiteCSSCascadeTrace]
    ) -> [OpenGraphiteAgentCSSDeclarationTrace] {
        var cursor = records[targetIndex].parentIndex
        while let current = cursor {
            if let candidates = cascadeTraces[current]?.candidates[property], !candidates.isEmpty {
                return candidates.map { Self.agentTrace($0, inherited: true) }
            }
            cursor = records[current].parentIndex
        }
        return []
    }

    /// 指定propertyがinline styleまたはcompanion CSS sourceに存在するかを判定します。
    private func hasAuthoredProperty(
        _ property: String,
        record: OpenGraphiteHTMLDOMRecord,
        trace: OpenGraphiteCSSCascadeTrace?
    ) -> Bool {
        if inlineStyleValues(for: record.tag, properties: [property])[property] != nil {
            return true
        }
        return trace?.candidates[property]?.contains(where: { !$0.inherited }) == true
    }

    /// inline style declarationを`!important`と分離し、同propertyの後勝ちを保持します。
    private func inlineStyleValues(
        for tag: OpenGraphiteHTMLTag,
        properties: Set<String>?
    ) -> [String: OpenGraphiteHTMLInlineStyleValue] {
        var result: [String: OpenGraphiteHTMLInlineStyleValue] = [:]
        for declaration in inlineStyleValueList(for: tag)
        where properties?.contains(declaration.property) != false {
            if let existing = result[declaration.property], existing.important && !declaration.important {
                continue
            }
            result[declaration.property] = declaration
        }
        return result
    }

    /// inline style内の全valid declarationをsource順とlossless range付きで返します。
    ///
    /// - Parameter tag: `style`属性を持つ開始tag。
    /// - Returns: duplicate propertyを保持したsource順declaration一覧。
    private func inlineStyleValueList(
        for tag: OpenGraphiteHTMLTag
    ) -> [OpenGraphiteHTMLInlineStyleValue] {
        guard let styleRange = styleAttributeValueRange(for: tag) else { return [] }
        let source = html.substring(styleRange)
        var segments: [(range: Range<String.Index>, delimiter: Range<String.Index>?)] = []
        var segmentStart = source.startIndex
        var cursor = source.startIndex
        var quote: Character?
        var blockClosers: [Character] = []
        var inComment = false
        while cursor < source.endIndex {
            if inComment {
                let token = Self.inlineCSSHTMLDecodedToken(
                    in: source,
                    at: cursor,
                    before: source.endIndex
                )
                let nextToken = token.upperBound < source.endIndex
                    ? Self.inlineCSSHTMLDecodedToken(
                        in: source,
                        at: token.upperBound,
                        before: source.endIndex
                    )
                    : nil
                if token.character == "*", nextToken?.character == "/" {
                    inComment = false
                    cursor = nextToken?.upperBound ?? token.upperBound
                } else {
                    cursor = token.upperBound
                }
                continue
            }
            let token = Self.inlineCSSSemanticToken(
                in: source,
                at: cursor,
                before: source.endIndex
            )
            let character = token.character
            let nextToken = token.upperBound < source.endIndex
                ? Self.inlineCSSSemanticToken(in: source, at: token.upperBound, before: source.endIndex)
                : nil
            if let activeQuote = quote {
                if character == activeQuote, !token.escaped { quote = nil }
            } else if character == "/", !token.escaped,
                      nextToken?.character == "*", nextToken?.escaped == false {
                inComment = true
                cursor = nextToken?.upperBound ?? token.upperBound
                continue
            } else if (character == "\"" || character == "'"), !token.escaped {
                quote = character
            } else if !token.escaped, let closer = Self.inlineCSSBlockCloser(for: character) {
                blockClosers.append(closer)
            } else if !token.escaped, blockClosers.last == character {
                blockClosers.removeLast()
            } else if character == ";", !token.escaped, blockClosers.isEmpty {
                segments.append((segmentStart..<token.upperBound, cursor..<token.upperBound))
                segmentStart = token.upperBound
            }
            cursor = token.upperBound
        }
        if segmentStart < source.endIndex {
            segments.append((segmentStart..<source.endIndex, nil))
        }

        return segments.enumerated().compactMap { sourceOrder, segment in
            inlineStyleValue(
                in: source,
                range: segment.range,
                delimiterRange: segment.delimiter,
                globalOffset: styleRange.lowerBound,
                sourceOrder: sourceOrder
            )
        }
    }

    /// inline styleの指定propertyだけをsource rangeで更新し、unknown宣言・comment・triviaを保持します。
    private func settingInlineStyleProperty(
        _ property: String,
        value: String,
        for tag: OpenGraphiteHTMLTag
    ) -> String {
        let normalizedProperty = property.hasPrefix("--") ? property : property.lowercased()
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedValue.isEmpty {
            return removingInlineStyleProperties([normalizedProperty], for: tag)
        }

        if let declaration = inlineStyleValues(
            for: tag,
            properties: [normalizedProperty]
        )[normalizedProperty] {
            guard declaration.value != normalizedValue else { return html }
            var result = html
            let escapedValue = Self.escapeAdoptionAttributeValue(normalizedValue)
            if let styleRange = styleAttributeValueRange(for: tag),
               styleAttributeQuote(for: tag, valueRange: styleRange) == nil {
                var rawStyle = html.substring(styleRange)
                let localLower = declaration.valueRange.lowerBound - styleRange.lowerBound
                let localUpper = declaration.valueRange.upperBound - styleRange.lowerBound
                rawStyle.replaceRange(localLower..<localUpper, with: escapedValue)
                result.replaceRange(
                    styleRange,
                    with: Self.isSafeUnquotedAttributeValue(rawStyle) ? rawStyle : "\"\(rawStyle)\""
                )
            } else {
                result.replaceRange(declaration.valueRange, with: escapedValue)
            }
            return result
        }

        guard let styleRange = styleAttributeValueRange(for: tag) else {
            var result = html
            Self.applyAttributeChanges(
                [("style", "\(normalizedProperty):\(normalizedValue);")],
                into: &result,
                tag: tag
            )
            return result
        }

        let rawStyle = html.substring(styleRange)
        let addition = "\(normalizedProperty):\(Self.escapeAdoptionAttributeValue(normalizedValue));"
        var result = html
        if styleAttributeQuote(for: tag, valueRange: styleRange) == nil {
            let combined = addition + rawStyle
            result.replaceRange(
                styleRange,
                with: Self.isSafeUnquotedAttributeValue(combined) ? combined : "\"\(combined)\""
            )
        } else {
            result.insert(addition, atOffset: styleRange.lowerBound)
        }
        return result
    }

    /// inline styleから指定propertyの全duplicate declarationだけを削除します。
    private func removingInlineStyleProperties(
        _ properties: Set<String>,
        for tag: OpenGraphiteHTMLTag
    ) -> String {
        let matches = inlineStyleValueList(for: tag).filter { properties.contains($0.property) }
        guard !matches.isEmpty else { return html }
        var result = html
        for declaration in matches.sorted(by: { $0.declarationRange.lowerBound > $1.declarationRange.lowerBound }) {
            result.replaceRange(declaration.declarationRange, with: "")
        }

        let reparsed = OpenGraphiteHTMLDocument(html: result)
        guard let updatedTag = reparsed.parsedTags().first(where: {
            $0.range.lowerBound == tag.range.lowerBound && $0.tagName == tag.tagName
        }),
        let updatedStyleRange = reparsed.styleAttributeValueRange(for: updatedTag),
        reparsed.html.substring(updatedStyleRange).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return result
        }
        Self.applyAttributeChanges([("style", nil)], into: &result, tag: updatedTag)
        return result
    }

    /// inline declaration segmentからproperty/value/importantとlossless rangeを抽出します。
    private func inlineStyleValue(
        in source: String,
        range: Range<String.Index>,
        delimiterRange: Range<String.Index>?,
        globalOffset: Int,
        sourceOrder: Int
    ) -> OpenGraphiteHTMLInlineStyleValue? {
        var cursor = range.lowerBound
        var quote: Character?
        var blockClosers: [Character] = []
        var inComment = false
        var colonRange: Range<String.Index>?
        while cursor < range.upperBound {
            if inComment {
                let token = Self.inlineCSSHTMLDecodedToken(
                    in: source,
                    at: cursor,
                    before: range.upperBound
                )
                let nextToken = token.upperBound < range.upperBound
                    ? Self.inlineCSSHTMLDecodedToken(
                        in: source,
                        at: token.upperBound,
                        before: range.upperBound
                    )
                    : nil
                if token.character == "*", nextToken?.character == "/" {
                    inComment = false
                    cursor = nextToken?.upperBound ?? token.upperBound
                } else {
                    cursor = token.upperBound
                }
                continue
            }
            let token = Self.inlineCSSSemanticToken(
                in: source,
                at: cursor,
                before: range.upperBound
            )
            let character = token.character
            let nextToken = token.upperBound < range.upperBound
                ? Self.inlineCSSSemanticToken(in: source, at: token.upperBound, before: range.upperBound)
                : nil
            if let activeQuote = quote {
                if character == activeQuote, !token.escaped { quote = nil }
            } else if character == "/", !token.escaped,
                      nextToken?.character == "*", nextToken?.escaped == false {
                inComment = true
                cursor = nextToken?.upperBound ?? token.upperBound
                continue
            } else if (character == "\"" || character == "'"), !token.escaped {
                quote = character
            } else if !token.escaped, let closer = Self.inlineCSSBlockCloser(for: character) {
                blockClosers.append(closer)
            } else if !token.escaped, blockClosers.last == character {
                blockClosers.removeLast()
            } else if character == ":", !token.escaped, blockClosers.isEmpty {
                colonRange = cursor..<token.upperBound
                break
            }
            cursor = token.upperBound
        }
        guard let colonRange else { return nil }
        let propertyStart = skipInlineTriviaForward(
            in: source,
            from: range.lowerBound,
            to: colonRange.lowerBound
        )
        let authoredName = Self.inlineCSSPropertyName(
            in: source,
            range: propertyStart..<colonRange.lowerBound
        )
        let normalizedName = authoredName.hasPrefix("--") ? authoredName : authoredName.lowercased()
        guard !normalizedName.isEmpty else { return nil }

        let declarationEnd = delimiterRange?.lowerBound ?? range.upperBound
        var valueStart = colonRange.upperBound
        valueStart = skipInlineTriviaForward(in: source, from: valueStart, to: declarationEnd)
        let priority = Self.inlineCSSPriority(
            in: source,
            valueRange: valueStart..<declarationEnd
        )
        let valueEnd = priority.valueEnd
        guard valueStart <= valueEnd else { return nil }

        let declarationUpper = range.upperBound
        let localValueLower = source.distance(from: source.startIndex, to: valueStart)
        let localValueUpper = source.distance(from: source.startIndex, to: valueEnd)
        let localDeclarationLower = source.distance(from: source.startIndex, to: propertyStart)
        let localPropertyUpper = source.distance(from: source.startIndex, to: colonRange.lowerBound)
        let localDeclarationUpper = source.distance(from: source.startIndex, to: declarationUpper)
        return OpenGraphiteHTMLInlineStyleValue(
            property: normalizedName,
            value: Self.decodingHTMLTextCharacterReferences(String(source[valueStart..<valueEnd])),
            important: priority.important,
            sourceOrder: sourceOrder,
            propertyRange: (globalOffset + localDeclarationLower)..<(globalOffset + localPropertyUpper),
            valueRange: (globalOffset + localValueLower)..<(globalOffset + localValueUpper),
            declarationRange: (globalOffset + localDeclarationLower)..<(globalOffset + localDeclarationUpper)
        )
    }

    /// HTML decode後にCSS token 1文字となるcharacter referenceをraw range付きで返します。
    private static func inlineCSSCharacterReference(
        in source: String,
        at start: String.Index,
        before end: String.Index
    ) -> (decoded: String, upperBound: String.Index)? {
        guard start < end, source[start] == "&" else { return nil }
        let referenceStart = source.index(after: start)
        guard referenceStart < end else { return nil }
        let upperBound: String.Index
        if source[referenceStart] == "#" {
            var cursor = source.index(after: referenceStart)
            var radix = 10
            if cursor < end, source[cursor] == "x" || source[cursor] == "X" {
                radix = 16
                cursor = source.index(after: cursor)
            }
            let digitsStart = cursor
            while cursor < end, Self.isASCIIReferenceDigit(source[cursor], radix: radix) {
                cursor = source.index(after: cursor)
            }
            guard cursor > digitsStart else { return nil }
            upperBound = cursor < end && source[cursor] == ";"
                ? source.index(after: cursor)
                : cursor
        } else {
            guard let semicolon = source[referenceStart..<end].firstIndex(of: ";") else { return nil }
            let name = String(source[referenceStart..<semicolon])
            guard !name.isEmpty,
                  name.allSatisfy(Self.isASCIIReferenceNameCharacter),
                  Self.htmlNamedCharacterReferences[name] != nil
            else { return nil }
            upperBound = source.index(after: semicolon)
        }
        let authored = String(source[start..<upperBound])
        let decoded = decodingHTMLTextCharacterReferences(authored)
        guard decoded != authored else { return nil }
        return (decoded, upperBound)
    }

    /// raw source 1 tokenをHTML decode後のCSS文字とraw上限へ投影します。
    private static func inlineCSSSemanticToken(
        in source: String,
        at start: String.Index,
        before end: String.Index
    ) -> (character: Character, upperBound: String.Index, escaped: Bool) {
        precondition(start < end)
        let first = inlineCSSHTMLDecodedToken(in: source, at: start, before: end)
        guard first.character == "\\", first.upperBound < end else {
            return (first.character, first.upperBound, false)
        }

        let next = inlineCSSHTMLDecodedToken(in: source, at: first.upperBound, before: end)
        if next.character.isHexDigit {
            var digits = String(next.character)
            var upperBound = next.upperBound
            while digits.count < 6, upperBound < end {
                let candidate = inlineCSSHTMLDecodedToken(
                    in: source,
                    at: upperBound,
                    before: end
                )
                guard candidate.character.isHexDigit else { break }
                digits.append(candidate.character)
                upperBound = candidate.upperBound
            }
            if upperBound < end {
                let whitespace = inlineCSSHTMLDecodedToken(
                    in: source,
                    at: upperBound,
                    before: end
                )
                if Self.isCSSASCIIWhitespace(whitespace.character) {
                    upperBound = whitespace.upperBound
                }
            }
            let scalarValue = UInt32(digits, radix: 16) ?? 0xFFFD
            let scalar = UnicodeScalar(scalarValue) ?? UnicodeScalar(0xFFFD)!
            return (Character(String(scalar)), upperBound, true)
        }
        return (next.character, next.upperBound, true)
    }

    /// HTML character referenceだけをdecodeしたraw 1 tokenを返します。
    private static func inlineCSSHTMLDecodedToken(
        in source: String,
        at start: String.Index,
        before end: String.Index
    ) -> (character: Character, upperBound: String.Index) {
        if let reference = inlineCSSCharacterReference(
            in: source,
            at: start,
            before: end
        ), reference.decoded.count == 1, let character = reference.decoded.first {
            return (character, reference.upperBound)
        }
        return (source[start], source.index(after: start))
    }

    /// CSS escapeとHTML entityをsemantic decodeした単一property名を返します。
    private static func inlineCSSPropertyName(
        in source: String,
        range: Range<String.Index>
    ) -> String {
        let components = inlineCSSSemanticComponents(in: source, range: range)
        var lower = 0
        var upper = components.count
        while lower < upper, components[lower].kind.isTrivia { lower += 1 }
        while upper > lower, components[upper - 1].kind.isTrivia { upper -= 1 }
        guard !components[lower..<upper].contains(where: { $0.kind.isTrivia }) else { return "" }
        return String(components[lower..<upper].compactMap(\.kind.character))
    }

    /// CSS simple block開始tokenに対応する終了tokenを返します。
    private static func inlineCSSBlockCloser(for character: Character) -> Character? {
        switch character {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        default: return nil
        }
    }

    /// inline CSS value末尾のsemantic `!important`と実valueのraw終端を返します。
    private static func inlineCSSPriority(
        in source: String,
        valueRange: Range<String.Index>
    ) -> (important: Bool, valueEnd: String.Index) {
        let components = inlineCSSSemanticComponents(in: source, range: valueRange)
        var significantEnd = components.count
        while significantEnd > 0, components[significantEnd - 1].kind.isTrivia {
            significantEnd -= 1
        }
        let fallbackEnd = significantEnd > 0
            ? components[significantEnd - 1].rawRange.upperBound
            : valueRange.lowerBound

        var cursor = significantEnd
        for expected in "important".reversed() {
            guard cursor > 0,
                  components[cursor - 1].kind.character.map({
                      String($0).lowercased() == String(expected)
                  }) == true
            else { return (false, fallbackEnd) }
            cursor -= 1
        }
        while cursor > 0, components[cursor - 1].kind.isTrivia {
            cursor -= 1
        }
        guard cursor > 0,
              components[cursor - 1].kind.character == "!",
              !components[cursor - 1].kind.isEscaped
        else {
            return (false, fallbackEnd)
        }
        let bangIndex = cursor - 1
        var valueComponentEnd = bangIndex
        while valueComponentEnd > 0, components[valueComponentEnd - 1].kind.isTrivia {
            valueComponentEnd -= 1
        }
        let valueEnd = valueComponentEnd > 0
            ? components[valueComponentEnd - 1].rawRange.upperBound
            : valueRange.lowerBound
        return (true, valueEnd)
    }

    /// HTML decode後のinline CSS文字をcomment/whitespace triviaとraw rangeへ分けます。
    private static func inlineCSSSemanticComponents(
        in source: String,
        range: Range<String.Index>
    ) -> [OpenGraphiteInlineCSSSemanticComponent] {
        var components: [OpenGraphiteInlineCSSSemanticComponent] = []
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            let token = inlineCSSSemanticToken(in: source, at: cursor, before: range.upperBound)
            if Self.isCSSASCIIWhitespace(token.character), !token.escaped {
                components.append(
                    OpenGraphiteInlineCSSSemanticComponent(
                        kind: .trivia,
                        rawRange: cursor..<token.upperBound
                    )
                )
                cursor = token.upperBound
                continue
            }
            let nextToken = token.upperBound < range.upperBound
                ? inlineCSSSemanticToken(in: source, at: token.upperBound, before: range.upperBound)
                : nil
            if token.character == "/", !token.escaped,
               nextToken?.character == "*", nextToken?.escaped == false {
                let commentStart = cursor
                var commentCursor = nextToken?.upperBound ?? token.upperBound
                while commentCursor < range.upperBound {
                    let commentToken = inlineCSSHTMLDecodedToken(
                        in: source,
                        at: commentCursor,
                        before: range.upperBound
                    )
                    let followingToken = commentToken.upperBound < range.upperBound
                        ? inlineCSSHTMLDecodedToken(
                            in: source,
                            at: commentToken.upperBound,
                            before: range.upperBound
                        )
                        : nil
                    if commentToken.character == "*", followingToken?.character == "/" {
                        commentCursor = followingToken?.upperBound ?? commentToken.upperBound
                        break
                    }
                    commentCursor = commentToken.upperBound
                }
                components.append(
                    OpenGraphiteInlineCSSSemanticComponent(
                        kind: .trivia,
                        rawRange: commentStart..<commentCursor
                    )
                )
                cursor = commentCursor
                continue
            }
            components.append(
                OpenGraphiteInlineCSSSemanticComponent(
                        kind: .character(token.character, escaped: token.escaped),
                    rawRange: cursor..<token.upperBound
                )
            )
            cursor = token.upperBound
        }
        return components
    }

    /// inline value先頭の空白/comment triviaを飛ばします。
    private func skipInlineTriviaForward(
        in source: String,
        from start: String.Index,
        to end: String.Index
    ) -> String.Index {
        var cursor = start
        while cursor < end {
            let token = Self.inlineCSSSemanticToken(in: source, at: cursor, before: end)
            if Self.isCSSASCIIWhitespace(token.character), !token.escaped {
                cursor = token.upperBound
                continue
            }
            let nextToken = token.upperBound < end
                ? Self.inlineCSSSemanticToken(in: source, at: token.upperBound, before: end)
                : nil
            if token.character == "/", !token.escaped,
               nextToken?.character == "*", nextToken?.escaped == false {
                var commentCursor = nextToken?.upperBound ?? token.upperBound
                var foundClose = false
                while commentCursor < end {
                    let commentToken = Self.inlineCSSHTMLDecodedToken(
                        in: source,
                        at: commentCursor,
                        before: end
                    )
                    let followingToken = commentToken.upperBound < end
                        ? Self.inlineCSSHTMLDecodedToken(
                            in: source,
                            at: commentToken.upperBound,
                            before: end
                        )
                        : nil
                    if commentToken.character == "*", followingToken?.character == "/" {
                        cursor = followingToken?.upperBound ?? commentToken.upperBound
                        foundClose = true
                        break
                    }
                    commentCursor = commentToken.upperBound
                }
                guard foundClose else { return cursor }
                continue
            }
            break
        }
        return cursor
    }

    /// 開始tag sourceを再直列化せず、style属性値だけのglobal offset rangeを索引化します。
    private func styleAttributeValueRange(for tag: OpenGraphiteHTMLTag) -> Range<Int>? {
        attributeValueRange(named: "style", for: tag)
    }

    /// 開始tag sourceを再直列化せず、指定属性値だけのglobal offset rangeを索引化します。
    private func attributeValueRange(named targetName: String, for tag: OpenGraphiteHTMLTag) -> Range<Int>? {
        let openingTag = html.substring(tag.range)
        var cursor = openingTag.index(after: openingTag.startIndex)
        cursor = openingTag.index(cursor, offsetBy: tag.rawTagName.count, limitedBy: openingTag.endIndex)
            ?? openingTag.endIndex
        while cursor < openingTag.endIndex {
            while cursor < openingTag.endIndex, Self.isHTMLASCIIWhitespace(openingTag[cursor]) {
                cursor = openingTag.index(after: cursor)
            }
            guard cursor < openingTag.endIndex,
                  openingTag[cursor] != ">", openingTag[cursor] != "/"
            else { break }
            let nameStart = cursor
            while cursor < openingTag.endIndex,
                  !Self.isHTMLASCIIWhitespace(openingTag[cursor]),
                  openingTag[cursor] != "=",
                  openingTag[cursor] != ">",
                  openingTag[cursor] != "/" {
                cursor = openingTag.index(after: cursor)
            }
            let name = String(openingTag[nameStart..<cursor]).lowercased()
            while cursor < openingTag.endIndex, Self.isHTMLASCIIWhitespace(openingTag[cursor]) {
                cursor = openingTag.index(after: cursor)
            }
            guard cursor < openingTag.endIndex, openingTag[cursor] == "=" else { continue }
            cursor = openingTag.index(after: cursor)
            while cursor < openingTag.endIndex, Self.isHTMLASCIIWhitespace(openingTag[cursor]) {
                cursor = openingTag.index(after: cursor)
            }
            guard cursor < openingTag.endIndex else { break }
            let valueStart: String.Index
            let valueEnd: String.Index
            if openingTag[cursor] == "\"" || openingTag[cursor] == "'" {
                let quote = openingTag[cursor]
                valueStart = openingTag.index(after: cursor)
                valueEnd = openingTag[valueStart...].firstIndex(of: quote) ?? openingTag.endIndex
                cursor = valueEnd < openingTag.endIndex ? openingTag.index(after: valueEnd) : valueEnd
            } else {
                valueStart = cursor
                while cursor < openingTag.endIndex,
                      !Self.isHTMLASCIIWhitespace(openingTag[cursor]),
                      openingTag[cursor] != ">" {
                    cursor = openingTag.index(after: cursor)
                }
                valueEnd = cursor
            }
            if name == targetName.lowercased() {
                let lower = tag.range.lowerBound + openingTag.distance(from: openingTag.startIndex, to: valueStart)
                let upper = tag.range.lowerBound + openingTag.distance(from: openingTag.startIndex, to: valueEnd)
                return lower..<upper
            }
        }
        return nil
    }

    /// style属性値を囲むauthored quoteを返し、unquoted値では`nil`を返します。
    private func styleAttributeQuote(
        for tag: OpenGraphiteHTMLTag,
        valueRange: Range<Int>
    ) -> Character? {
        guard valueRange.lowerBound > tag.range.lowerBound else { return nil }
        let valueStart = html.index(html.startIndex, offsetBy: valueRange.lowerBound)
        let previous = html[html.index(before: valueStart)]
        return previous == "\"" || previous == "'" ? previous : nil
    }

    /// nested annotation wrapperを境界にし、外側nodeへ内側の描画targetを誤集約しないようにします。
    private func belongsToRenderingScope(
        _ targetIndex: Int,
        wrapperIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> Bool {
        var cursor = records[targetIndex].parentIndex
        while let current = cursor {
            if current == wrapperIndex { return true }
            let tag = records[current].tag
            if tag.emptyNilAttribute(named: "data-og-id") != nil
                || tag.emptyNilAttribute(named: "data-og-internal-id") != nil {
                return false
            }
            cursor = records[current].parentIndex
        }
        return false
    }

    /// wrapper相対の`:scope` selectorをDOM pathから生成します。
    private func relativeSelector(
        from wrapperIndex: Int,
        to targetIndex: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String {
        guard targetIndex != wrapperIndex else { return ":scope" }
        var segments: [String] = []
        var cursor: Int? = targetIndex
        while let current = cursor, current != wrapperIndex {
            let record = records[current]
            let suffix = record.siblingTypeCount > 1
                ? ":nth-of-type(\(record.element.typeIndex))"
                : ""
            segments.append(record.tag.tagName + suffix)
            cursor = record.parentIndex
        }
        guard cursor == wrapperIndex else { return "" }
        return ":scope > " + segments.reversed().joined(separator: " > ")
    }

    /// standard id、既存internal ID、wrapper-relative selectorの順に保存先selectorを選びます。
    private func preferredSelector(
        for targetIndex: Int,
        wrapperIndex: Int,
        relationSelector: String,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String {
        if let selector = uniqueStandardIDSelector(for: targetIndex, records: records) {
            return selector
        }
        if let internalSelector = uniqueAnnotationSelector(
            named: "data-og-internal-id",
            for: targetIndex,
            records: records
        ) {
            return internalSelector
        }
        guard let wrapperSelector = uniqueStandardIDSelector(for: wrapperIndex, records: records)
            ?? uniqueAnnotationSelector(for: wrapperIndex, records: records)
        else { return "" }
        guard relationSelector != ":scope" else { return wrapperSelector }
        return relationSelector.replacingOccurrences(of: ":scope", with: wrapperSelector)
    }

    /// 一意な標準`id`を安全なCSS selectorとして返します。
    private func uniqueStandardIDSelector(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String? {
        guard let idValue = records[index].tag.attributeValue(named: "id"),
              !records[index].tag.containsUnresolvedHTMLCharacterReference(named: "id")
        else { return nil }
        let id = idValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              records.filter({ $0.tag.attributeValue(named: "id") == idValue }).count == 1,
              Self.isSafeCSSAttributeSelectorValue(idValue)
        else { return nil }
        if idValue == id,
           id.range(of: #"^[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil {
            return "#\(id)"
        }
        return Self.attributeSelector(name: "id", value: idValue)
    }

    /// authored classまたはcustom-element tagから一意でescape不要なselectorを返します。
    private func uniqueAuthoredSelector(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String? {
        let record = records[index]
        let authoredClass = record.tag.attributeValue(named: "class") ?? ""
        let classNames = record.tag.containsUnresolvedHTMLCharacterReference(named: "class")
            ? []
            : authoredClass.split(whereSeparator: Self.isHTMLASCIIWhitespace).map(String.init)
        for className in classNames
        where className.range(of: #"^[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil {
            let matchingClassIndices = records.indices.filter { candidateIndex in
                let candidateClasses = (records[candidateIndex].tag.attributeValue(named: "class") ?? "")
                    .split(whereSeparator: Self.isHTMLASCIIWhitespace)
                    .map(String.init)
                return candidateClasses.contains(className)
            }
            if matchingClassIndices.count == 1 {
                return ".\(className)"
            }
            let matchingTagClassCount = matchingClassIndices.filter { candidateIndex in
                records[candidateIndex].tag.tagName == record.tag.tagName
            }.count
            if matchingTagClassCount == 1,
               Self.isConservativeCSSTypeSelector(record.tag.tagName) {
                return "\(record.tag.tagName).\(className)"
            }
        }

        if record.tag.tagName.contains("-"),
           Self.isConservativeCSSTypeSelector(record.tag.tagName),
           records.filter({ $0.tag.tagName == record.tag.tagName }).count == 1 {
            return record.tag.tagName
        }
        return nil
    }

    /// wrapperに既にある一意なOpenGraphite参照selectorを返します。
    private func uniqueAnnotationSelector(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String? {
        for name in ["data-og-internal-id", "data-og-id"] {
            if let selector = uniqueAnnotationSelector(named: name, for: index, records: records) {
                return selector
            }
        }
        return nil
    }

    /// DOM semantic値と正規化値がともに一意なannotationだけを正確なattribute selectorへ変換します。
    private func uniqueAnnotationSelector(
        named name: String,
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord]
    ) -> String? {
        guard let value = records[index].tag.attributeValue(named: name),
              !records[index].tag.containsUnresolvedHTMLCharacterReference(named: name)
        else { return nil }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else { return nil }
        let normalizedMatches = records.filter { record in
            record.tag.attributeValue(named: name)?
                .trimmingCharacters(in: .whitespacesAndNewlines) == normalizedValue
        }
        guard normalizedMatches.count == 1,
              records.filter({ $0.tag.attributeValue(named: name) == value }).count == 1,
              Self.isSafeCSSAttributeSelectorValue(value)
        else { return nil }
        return Self.attributeSelector(name: name, value: value)
    }

    /// 論理名（日本語）: 未解決HTML character reference判定関数
    /// 処理概要: authored属性値に未対応namedまたは不正numeric character referenceがあるかを判定します。
    ///
    /// - Parameter value: entity復号前のauthored属性値。
    /// - Returns: 完全な復号を保証できないcharacter reference候補がある場合は`true`。
    static func containsUnresolvedHTMLCharacterReference(_ value: String) -> Bool {
        var cursor = value.startIndex
        while cursor < value.endIndex,
              let ampersand = value[cursor...].firstIndex(of: "&") {
            let referenceStart = value.index(after: ampersand)
            guard referenceStart < value.endIndex else { return false }

            if value[referenceStart] == "#" {
                var scan = value.index(after: referenceStart)
                var radix = 10
                if scan < value.endIndex, value[scan] == "x" || value[scan] == "X" {
                    radix = 16
                    scan = value.index(after: scan)
                }
                let digitsStart = scan
                while scan < value.endIndex,
                      Self.isASCIIReferenceDigit(value[scan], radix: radix) {
                    scan = value.index(after: scan)
                }
                guard scan > digitsStart else { return true }
                cursor = scan < value.endIndex && value[scan] == ";"
                    ? value.index(after: scan)
                    : scan
                continue
            }

            var scan = referenceStart
            while scan < value.endIndex, Self.isASCIIReferenceNameCharacter(value[scan]) {
                scan = value.index(after: scan)
            }
            guard scan > referenceStart else {
                cursor = referenceStart
                continue
            }
            guard scan < value.endIndex, value[scan] == ";" else { return true }
            let name = String(value[referenceStart..<scan])
            guard Self.htmlNamedCharacterReferences[name] != nil else { return true }
            cursor = value.index(after: scan)
        }
        return false
    }

    /// HTML character reference名を構成するASCII英数字かを返します。
    private static func isASCIIReferenceNameCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else { return false }
        return (0x30...0x39).contains(value)
            || (0x41...0x5A).contains(value)
            || (0x61...0x7A).contains(value)
    }

    /// numeric character referenceの指定radixで有効なASCII digitかを返します。
    private static func isASCIIReferenceDigit(_ character: Character, radix: Int) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else { return false }
        if (0x30...0x39).contains(value) { return true }
        guard radix == 16 else { return false }
        return (0x41...0x46).contains(value) || (0x61...0x66).contains(value)
    }

    /// CSS quoted attribute selectorへ未escapeで置けないcontrol文字を含まないかを返します。
    private static func isSafeCSSAttributeSelectorValue(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.newlines.contains(scalar)
        }
    }

    /// escapeなしのCSS type selectorとして扱える保守的なASCIIタグ名かを返します。
    private static func isConservativeCSSTypeSelector(_ tagName: String) -> Bool {
        tagName.range(of: #"^[a-z][a-z0-9_-]*$"#, options: .regularExpression) != nil
    }

    /// CSS attribute selector用にquoteとbackslashをescapeします。
    private static func attributeSelector(name: String, value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return #"[\#(name)="\#(escaped)"]"#
    }

    /// CSS source provenanceをAgent JSON向けtraceへ変換します。
    private static func agentTrace(
        _ provenance: OpenGraphiteCSSDeclarationProvenance,
        inherited: Bool? = nil
    ) -> OpenGraphiteAgentCSSDeclarationTrace {
        OpenGraphiteAgentCSSDeclarationTrace(
            property: provenance.property,
            authoredProperty: provenance.authoredProperty,
            selector: provenance.selector,
            specificity: provenance.specificity,
            atRules: provenance.atRules,
            value: provenance.declaration.value,
            important: provenance.declaration.important,
            sourceID: provenance.sourceID,
            sourceKind: provenance.sourceKind,
            sourceEditable: provenance.sourceEditable,
            stylesheetOrder: provenance.stylesheetOrder,
            sourceOrder: provenance.declaration.sourceOrder,
            inherited: inherited ?? provenance.inherited
        )
    }

    /// 開始時に未閉鎖`p`を暗黙終了させるHTML block要素名です。
    private static let impliedParagraphClosingStartTags: Set<String> = [
        "address", "article", "aside", "blockquote", "center", "details", "dialog", "dir", "div", "dl", "fieldset",
        "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6",
        "header", "hgroup", "hr", "listing", "main", "menu", "nav", "ol", "p", "pre", "search",
        "section", "summary", "table", "ul"
    ]

    /// 相互の開始時に前のsectionを暗黙終了させるtable section要素名です。
    private static let tableSectionElementNames: Set<String> = ["thead", "tbody", "tfoot"]

    /// 開始時に直前の省略可能な`caption`終了tagを確定するtable構造要素名です。
    private static let tableCaptionClosingStartTags: Set<String> = [
        "caption", "colgroup", "tbody", "tfoot", "thead", "tr"
    ]

    /// 明示`head`の終了tagを省略したまま引き続きhead内へ置ける開始tag名です。
    private static let headContentStartTags: Set<String> = [
        "base", "basefont", "bgsound", "link", "meta", "noframes", "noscript",
        "script", "style", "template", "title"
    ]

    /// DOM editing operationを持たないdocument metadata / raw program要素名です。
    private static let nonOperationalElementNames: Set<String> = [
        "base", "basefont", "bgsound", "head", "html", "link", "meta", "noframes",
        "noembed", "noscript", "script", "style", "template", "title", "xmp", "plaintext"
    ]

    /// 標準HTML native controlとしてcontrol操作を優先する要素名です。
    private static let nativeControlElementNames: Set<String> = [
        "button", "details", "dialog", "fieldset", "input", "meter", "optgroup", "option",
        "output", "progress", "select", "summary", "textarea"
    ]

    /// generic flow fragmentを受け取れる標準HTML container要素名です。
    private static let genericFlowContainerElementNames: Set<String> = [
        "address", "article", "aside", "blockquote", "body", "caption", "dd", "details", "dialog",
        "div", "dt", "fieldset", "figcaption", "figure", "footer", "form", "header", "li", "main",
        "nav", "search", "section", "td", "th"
    ]

    /// 子を親へ展開してもcustom element contractを暗黙破壊しない汎用container要素名です。
    private static let safeUngroupHostElementNames: Set<String> = [
        "article", "aside", "div", "figcaption", "figure", "footer", "header", "main", "nav",
        "section", "span"
    ]

    /// value/control操作とDOM text置換を分離するnative control要素名です。
    private static let controlTextContentElementNames: Set<String> = [
        "input", "optgroup", "select", "textarea"
    ]

    /// direct textが空でもtext編集operationを持つ標準semantic要素名です。
    private static let textSemanticElementNames: Set<String> = [
        "abbr", "address", "b", "bdi", "bdo", "blockquote", "button", "caption", "cite",
        "code", "dd", "del", "dfn", "dt", "em", "figcaption", "h1", "h2", "h3", "h4",
        "h5", "h6", "i", "ins", "kbd", "label", "legend", "li", "mark", "option", "p",
        "pre", "q", "rp", "rt", "ruby", "s", "samp", "small", "span", "strong", "sub",
        "summary", "sup", "td", "th", "time", "u", "var"
    ]

    /// DOM text置換をsource code/runtime内容の破壊につなげない要素名です。
    private static let nonTextEditableElementNames: Set<String> = [
        "base", "head", "html", "link", "meta", "noembed", "noframes", "noscript",
        "script", "style", "template", "xmp", "plaintext"
    ]

    /// 標準media contentとしてmedia編集operationを持つ要素名です。
    private static let mediaElementNames: Set<String> = [
        "audio", "canvas", "embed", "iframe", "img", "object", "picture", "source", "track", "video"
    ]

    /// 標準`value` content attributeを持てるHTML要素名です。
    private static let valueAttributeElementNames: Set<String> = [
        "button", "data", "input", "li", "meter", "option", "progress"
    ]

    /// 標準`src` content attributeを持つmedia実体要素名です。
    private static let sourceAttributeMediaElementNames: Set<String> = [
        "audio", "embed", "iframe", "img", "source", "track", "video"
    ]

    /// SVG実体としてicon編集operationの根拠になる要素名です。
    private static let svgElementNames: Set<String> = [
        "svg", "g", "path", "circle", "ellipse", "line", "polyline", "polygon", "rect", "use",
        "defs", "symbol", "mask", "clippath", "lineargradient", "radialgradient", "stop", "text",
        "tspan", "foreignobject"
    ]

    /// Unknown/custom hostをgeneric containerとして扱う際に標準tagを曖昧hostから除外する一覧です。
    private static let standardHTMLElementNames: Set<String> = [
        "a", "abbr", "address", "area", "article", "aside", "audio", "b", "base", "bdi", "bdo",
        "blockquote", "body", "br", "button", "canvas", "caption", "cite", "code", "col", "colgroup",
        "data", "datalist", "dd", "del", "details", "dfn", "dialog", "div", "dl", "dt", "em", "embed",
        "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6",
        "head", "header", "hgroup", "hr", "html", "i", "iframe", "img", "input", "ins", "kbd",
        "label", "legend", "li", "link", "main", "map", "mark", "menu", "meta", "meter", "nav",
        "noscript", "object", "ol", "optgroup", "option", "output", "p", "picture", "pre", "progress",
        "q", "rp", "rt", "ruby", "s", "samp", "script", "search", "section", "select", "slot", "small",
        "source", "span", "strong", "style", "sub", "summary", "sup", "table", "tbody", "td", "template",
        "textarea", "tfoot", "th", "thead", "time", "title", "tr", "track", "u", "ul", "var", "video",
        "wbr", "acronym", "applet", "basefont", "bgsound", "big", "center", "dir", "font", "frame",
        "frameset", "keygen", "marquee", "noembed", "noframes", "param", "plaintext", "strike", "tt", "xmp"
    ]

    /// Explicit ARIA semanticsがnative controlと同じoperationを要求するroleです。
    private static let interactiveARIARoles: Set<String> = [
        "button", "checkbox", "combobox", "gridcell", "listbox", "menuitem", "menuitemcheckbox",
        "menuitemradio", "option", "radio", "searchbox", "slider", "spinbutton", "switch",
        "scrollbar", "tab", "textbox", "treeitem"
    ]

    /// role fallback listのsemantic解決に使う標準WAI-ARIA role名です。
    private static let recognizedARIARoles: Set<String> = [
        "alert", "alertdialog", "application", "article", "banner", "blockquote", "button",
        "caption", "cell", "checkbox", "code", "columnheader", "combobox", "complementary",
        "contentinfo", "definition", "deletion", "dialog", "directory", "document", "emphasis",
        "feed", "figure", "form", "generic", "grid", "gridcell", "group", "heading", "img",
        "insertion", "link", "list", "listbox", "listitem", "log", "main", "marquee", "math",
        "menu", "menubar", "menuitem", "menuitemcheckbox", "menuitemradio", "meter", "navigation",
        "none", "note", "option", "paragraph", "presentation", "progressbar", "radio", "radiogroup",
        "region", "row", "rowgroup", "rowheader", "scrollbar", "search", "searchbox", "separator",
        "slider", "spinbutton", "status", "strong", "subscript", "suggestion", "superscript", "switch",
        "tab", "table", "tablist", "tabpanel", "term", "textbox", "time", "timer", "toolbar",
        "tooltip", "tree", "treegrid", "treeitem"
    ]

    private static let voidElementNames: Set<String> = [
        "area",
        "base",
        "br",
        "col",
        "embed",
        "hr",
        "img",
        "input",
        "link",
        "meta",
        "param",
        "source",
        "track",
        "wbr"
    ]

    /// HTML raw text / RCDATA要素。`template` contentは将来のWeb Components編集対象として意図的に除外します。
    private static let rawTextElementNames: Set<String> = [
        "script", "style", "textarea", "title", "xmp", "iframe", "noembed", "noframes", "noscript", "plaintext"
    ]

    /// raw text要素のうちHTML character referenceを解釈するRCDATA要素名です。
    private static let rcdataElementNames: Set<String> = ["textarea", "title"]

    private func uniqueTag(forNodeID id: String) -> (tag: OpenGraphiteHTMLTag?, diagnostics: [OpenGraphiteDiagnostic]) {
        let tags = parsedTags()
        let matches = tags.filter { $0.attributeValue(named: "data-og-internal-id") == id }
        if matches.count == 1 {
            return (matches[0], [])
        }

        if matches.isEmpty {
            return (
                nil,
                [
                    OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-node",
                    message: "data-og-internal-id \"\(id)\" を持つノードが見つかりません。",
                    path: nil,
                    nodeID: id
                )
                ]
            )
        }

        return (
            nil,
            [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-internal-id",
                    message: "data-og-internal-id \"\(id)\" が \(matches.count) 件あります。",
                    path: nil,
                    nodeID: id
                )
            ]
        )
    }

    private func uniqueElement(forNodeID id: String) -> (element: OpenGraphiteHTMLElement?, diagnostics: [OpenGraphiteDiagnostic]) {
        let match = uniqueTag(forNodeID: id)
        guard let tag = match.tag else {
            return (nil, match.diagnostics)
        }

        guard let element = element(for: tag) else {
            return (
                nil,
                [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-closing-tag",
                        message: "\(id) の閉じタグが見つかりません。",
                        path: nil,
                        nodeID: id
                    )
                ]
            )
        }

        return (element, [])
    }

    /// 指定internal IDの一意なAgent nodeを返し、operation guardを同じcapability正本へ接続します。
    private func capabilityNode(
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteAgentNode? {
        let matches = nodes(contract: contract).filter { $0.internalID == id }
        return matches.count == 1 ? matches[0] : nil
    }

    private func element(for tag: OpenGraphiteHTMLTag) -> OpenGraphiteHTMLElement? {
        guard let parsedElement = parsedElements().first(where: {
            $0.tag.range == tag.range && $0.tag.tagName == tag.tagName
        }),
        let contentEnd = parsedElement.contentEnd,
        let fullEnd = parsedElement.fullEnd
        else {
            return nil
        }

        return OpenGraphiteHTMLElement(
            tag: tag,
            contentRange: tag.range.upperBound..<contentEnd,
            fullRange: tag.range.lowerBound..<fullEnd
        )
    }

    /// 論理名（日本語）: DOM record要素範囲変換関数
    /// 処理概要: tree走査時に保持済みの終端offsetを、再解析せず要素範囲へ変換します。
    ///
    /// - Parameter record: 開始tagと解析済み終端offsetを持つDOM record。
    /// - Returns: content / full rangeが確定した要素。閉じ範囲不明時は`nil`。
    private func element(for record: OpenGraphiteHTMLDOMRecord) -> OpenGraphiteHTMLElement? {
        guard let contentEnd = record.contentEnd, let fullEnd = record.fullEnd else { return nil }
        return OpenGraphiteHTMLElement(
            tag: record.tag,
            contentRange: record.tag.range.upperBound..<contentEnd,
            fullRange: record.tag.range.lowerBound..<fullEnd
        )
    }

    /// 論理名（日本語）: DOM recordテキスト抽出関数
    /// 処理概要: 1回のtree走査で保持した全recordのsource範囲を再利用し、対象subtreeのテキストを抽出します。
    ///
    /// - Parameters:
    ///   - index: 対象DOM record index。
    ///   - records: 解析済みDOM record一覧。
    ///   - elementAtOffset: 開始offsetをkeyにした解析済み要素source範囲map。
    /// - Returns: HTML character referenceを復号し、空白を正規化したtext content。
    private func textContent(
        for index: Int,
        records: [OpenGraphiteHTMLDOMRecord],
        elementAtOffset: [Int: OpenGraphiteHTMLTextElementRange]
    ) -> String? {
        let record = records[index]
        guard let contentEnd = record.contentEnd, record.tag.range.upperBound < contentEnd else {
            return nil
        }
        return textContent(
            for: record.tag,
            contentEnd: contentEnd,
            elementAtOffset: elementAtOffset
        )
    }

    private func textContent(for tag: OpenGraphiteHTMLTag) -> String? {
        let parsedElements = parsedElements()
        guard let parsedElement = parsedElements.first(where: {
            $0.tag.range == tag.range && $0.tag.tagName == tag.tagName
        }),
        let contentEnd = parsedElement.contentEnd,
        tag.range.upperBound < contentEnd
        else {
            return nil
        }

        let elementAtOffset = Dictionary(
            uniqueKeysWithValues: parsedElements.map { parsedElement in
                (
                    parsedElement.tag.range.lowerBound,
                    OpenGraphiteHTMLTextElementRange(
                        tag: parsedElement.tag,
                        contentEnd: parsedElement.contentEnd,
                        fullEnd: parsedElement.fullEnd
                    )
                )
            }
        )
        return textContent(for: tag, contentEnd: contentEnd, elementAtOffset: elementAtOffset)
    }

    /// 論理名（日本語）: 解析済み要素mapテキスト抽出関数
    /// 処理概要: 解析済み要素終端mapを使ってsubtreeの正規化text contentを返します。
    ///
    /// - Parameters:
    ///   - tag: text抽出対象の開始tag。
    ///   - contentEnd: 対象要素のcontent終端offset。
    ///   - elementAtOffset: 開始offsetをkeyにした解析済み要素source範囲map。
    /// - Returns: HTML character referenceを復号し、空白を正規化したtext content。
    private func textContent(
        for tag: OpenGraphiteHTMLTag,
        contentEnd: Int,
        elementAtOffset: [Int: OpenGraphiteHTMLTextElementRange]
    ) -> String? {
        let contentRange = tag.range.upperBound..<contentEnd
        if Self.rawTextElementNames.contains(tag.tagName) {
            let sourceText = html.substring(contentRange)
            return Self.normalizedTextContent(
                Self.rcdataElementNames.contains(tag.tagName)
                    ? Self.decodingHTMLTextCharacterReferences(sourceText)
                    : sourceText
            )
        }

        var text = ""
        var cursor = html.index(html.startIndex, offsetBy: contentRange.lowerBound)
        let contentEndIndex = html.index(html.startIndex, offsetBy: contentRange.upperBound)

        while cursor < contentEndIndex {
            guard let openIndex = html[cursor..<contentEndIndex].firstIndex(of: "<") else {
                text += Self.decodingHTMLTextCharacterReferences(String(html[cursor..<contentEndIndex]))
                break
            }
            if cursor < openIndex {
                text += Self.decodingHTMLTextCharacterReferences(String(html[cursor..<openIndex]))
            }

            if html[openIndex...].hasPrefix("<!--") {
                guard let commentEnd = Self.htmlCommentEnd(in: html, from: openIndex),
                      commentEnd <= contentEndIndex else {
                    cursor = contentEndIndex
                    continue
                }
                cursor = commentEnd
                continue
            }
            if html[openIndex...].hasPrefix("<![CDATA[") {
                let cdataStart = html.index(openIndex, offsetBy: 9)
                guard let cdataEnd = html.range(
                    of: "]]>",
                    range: cdataStart..<contentEndIndex
                ) else {
                    text += String(html[cdataStart..<contentEndIndex])
                    cursor = contentEndIndex
                    continue
                }
                text += String(html[cdataStart..<cdataEnd.lowerBound])
                cursor = cdataEnd.upperBound
                continue
            }

            let openOffset = html.distance(from: html.startIndex, to: openIndex)
            if let child = elementAtOffset[openOffset],
               Self.rawTextElementNames.contains(child.tag.tagName),
               let childContentEnd = child.contentEnd,
               let childFullEnd = child.fullEnd {
                let childContentRange = child.tag.range.upperBound..<min(childContentEnd, contentRange.upperBound)
                let childSourceText = html.substring(childContentRange)
                text += Self.rcdataElementNames.contains(child.tag.tagName)
                    ? Self.decodingHTMLTextCharacterReferences(childSourceText)
                    : childSourceText
                cursor = html.index(
                    html.startIndex,
                    offsetBy: min(childFullEnd, contentRange.upperBound)
                )
                continue
            }

            guard let closeIndex = findTagEnd(startingAt: html.index(after: openIndex)),
                  closeIndex < contentEndIndex else {
                text += Self.decodingHTMLTextCharacterReferences(String(html[openIndex..<contentEndIndex]))
                break
            }
            cursor = html.index(after: closeIndex)
        }

        return Self.normalizedTextContent(text)
    }

    /// source順に抽出したDOM textを既存Agent graph互換の単一空白へ正規化します。
    private static func normalizedTextContent(_ value: String) -> String? {
        let collapsed = value.split(whereSeparator: Self.isHTMLASCIIWhitespace).joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    /// HTML data/RCDATA/属性値で復号する標準named character referenceの対応subsetです。
    private static let htmlNamedCharacterReferences: [String: String] = [
        "Tab": "\t",
        "NewLine": "\n",
        "amp": "&",
        "ast": "*",
        "bsol": "\\",
        "colon": ":",
        "excl": "!",
        "lcub": "{",
        "lpar": "(",
        "lsqb": "[",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{00A0}",
        "period": ".",
        "rcub": "}",
        "rpar": ")",
        "rsqb": "]",
        "semi": ";",
        "sol": "/"
    ]

    private static let htmlNumericCharacterReferenceReplacements: [UInt32: UInt32] = [
        0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
        0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6,
        0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
        0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
        0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
        0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
        0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178
    ]

    private static func decodedNumericCharacterReference(_ value: UInt32?) -> Character {
        guard let value, value != 0, value <= 0x10FFFF,
              !(0xD800...0xDFFF).contains(value)
        else { return "\u{FFFD}" }
        let normalized = htmlNumericCharacterReferenceReplacements[value] ?? value
        return UnicodeScalar(normalized).map(Character.init) ?? "\u{FFFD}"
    }

    /// HTML data/RCDATA stateで解釈される標準named/numeric character referenceの対応subsetを復号します。
    private static func decodingHTMLTextCharacterReferences(_ value: String) -> String {
        var result = ""
        var cursor = value.startIndex
        while cursor < value.endIndex {
            guard let ampersand = value[cursor...].firstIndex(of: "&") else {
                result += String(value[cursor...])
                break
            }
            result += String(value[cursor..<ampersand])
            let referenceStart = value.index(after: ampersand)
            if referenceStart < value.endIndex, value[referenceStart] == "#" {
                var digitStart = value.index(after: referenceStart)
                var radix = 10
                if digitStart < value.endIndex, value[digitStart] == "x" || value[digitStart] == "X" {
                    radix = 16
                    digitStart = value.index(after: digitStart)
                }
                var digitEnd = digitStart
                while digitEnd < value.endIndex {
                    let scalar = value[digitEnd].unicodeScalars.first?.value
                    let isDigit = scalar.map { scalar in
                        (48...57).contains(scalar)
                            || (radix == 16 && ((65...70).contains(scalar) || (97...102).contains(scalar)))
                    } ?? false
                    guard isDigit else { break }
                    digitEnd = value.index(after: digitEnd)
                }
                if digitEnd > digitStart {
                    let scalarValue = UInt32(value[digitStart..<digitEnd], radix: radix)
                    result.append(decodedNumericCharacterReference(scalarValue))
                    if digitEnd < value.endIndex, value[digitEnd] == ";" {
                        cursor = value.index(after: digitEnd)
                    } else {
                        cursor = digitEnd
                    }
                    continue
                }
            }
            guard let semicolon = value[referenceStart...].firstIndex(of: ";") else {
                result += String(value[ampersand...])
                break
            }
            let reference = String(value[referenceStart..<semicolon])
            let decoded: String?
            if reference.hasPrefix("#x") || reference.hasPrefix("#X") {
                decoded = UInt32(reference.dropFirst(2), radix: 16)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            } else if reference.hasPrefix("#") {
                decoded = UInt32(reference.dropFirst(), radix: 10)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            } else {
                decoded = htmlNamedCharacterReferences[reference]
            }
            if let decoded {
                result += decoded
                cursor = value.index(after: semicolon)
            } else {
                result.append("&")
                cursor = referenceStart
            }
        }
        return result
    }

    private static func insertRawHTML(
        _ fragmentHTML: String,
        into html: inout String,
        relativeTo element: OpenGraphiteHTMLElement,
        position: OpenGraphiteHTMLInsertionPosition
    ) {
        let offset: Int
        switch position {
        case .before:
            offset = element.fullRange.lowerBound
        case .after:
            offset = element.fullRange.upperBound
        case .prepend:
            offset = element.tag.range.upperBound
        case .append:
            offset = element.contentRange.upperBound
        }
        html.insert("\n\(fragmentHTML)", atOffset: offset)
    }

    /// 論理名（日本語）: 移動HTML挿入関数
    /// 処理概要: sibling 移動時に target 行の indentation を保った位置へ HTML 断片を挿入します。
    private static func insertMovedHTML(
        _ fragmentHTML: String,
        into html: inout String,
        relativeTo element: OpenGraphiteHTMLElement,
        position: OpenGraphiteHTMLInsertionPosition
    ) {
        guard position == .before || position == .after else {
            insertRawHTML(fragmentHTML, into: &html, relativeTo: element, position: position)
            return
        }

        let context = lineIndentContext(before: element.fullRange.lowerBound, in: html)
        let offset = position == .before ? context.lineBreakOffset ?? element.fullRange.lowerBound : element.fullRange.upperBound
        html.insert("\n\(context.indentation)\(fragmentHTML)", atOffset: offset)
    }

    /// 論理名（日本語）: 移動元行削除範囲計算関数
    /// 処理概要: node 移動時に source 要素だけでなく、その行頭 indentation も同時に除去します。
    private static func lineRemovalRange(for element: OpenGraphiteHTMLElement, in html: String) -> Range<Int> {
        let context = lineIndentContext(before: element.fullRange.lowerBound, in: html)
        guard let lineBreakOffset = context.lineBreakOffset else { return element.fullRange }
        return lineBreakOffset..<element.fullRange.upperBound
    }

    /// 論理名（日本語）: 行indentation文脈取得関数
    /// 処理概要: 指定 offset の直前が行頭空白だけで構成されている場合、その改行位置と indentation を返します。
    private static func lineIndentContext(before offset: Int, in html: String) -> (lineBreakOffset: Int?, indentation: String) {
        let targetIndex = html.index(html.startIndex, offsetBy: offset)
        var index = targetIndex
        while index > html.startIndex {
            let previous = html.index(before: index)
            if html[previous] == "\n" {
                let indentationStart = html.index(after: previous)
                let indentation = String(html[indentationStart..<targetIndex])
                guard isLineIndentation(indentation) else { return (nil, "") }
                return (html.distance(from: html.startIndex, to: previous), indentation)
            }
            index = previous
        }

        let indentation = String(html[html.startIndex..<targetIndex])
        return isLineIndentation(indentation) ? (nil, indentation) : (nil, "")
    }

    /// 論理名（日本語）: 行indentation判定関数
    /// 処理概要: 文字列がスペースまたはタブのみで構成されるかを返します。
    private static func isLineIndentation(_ value: String) -> Bool {
        value.allSatisfy { character in
            character == " " || character == "\t"
        }
    }

    /// standardized file URLが許可root自身またはdescendantかをpath component境界で判定します。
    private static func isURL(_ url: URL, containedIn rootURL: URL) -> Bool {
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath().path
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
        return candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private func internalIDSet(excluding element: OpenGraphiteHTMLElement? = nil) -> Set<String> {
        Set(parsedTags().compactMap { tag in
            if let element, element.fullRange.contains(tag.range.lowerBound) {
                return nil
            }
            let internalID = tag.attributeValue(named: "data-og-internal-id") ?? ""
            return internalID.isEmpty ? nil : internalID
        })
    }

    private static func uniqueOpaqueInternalID(seed: String, used: inout Set<String>) -> String {
        let base = opaqueInternalID(seed: seed)
        var candidate = base
        var index = 2
        while used.contains(candidate) {
            candidate = "\(base)-\(index)"
            index += 1
        }
        used.insert(candidate)
        return candidate
    }

    /// 複製subtree内の既存identityだけを再発行し、未注釈descendantを暗黙adoptしません。
    private static func prefixingDataOGIDs(in fragmentHTML: String, prefix: String) -> String {
        var result = fragmentHTML
        let document = OpenGraphiteHTMLDocument(html: fragmentHTML)
        for tag in document.parsedTags().reversed() {
            let displayID = tag.attributeValue(named: "data-og-id")
            let internalID = tag.attributeValue(named: "data-og-internal-id")
            guard displayID != nil || internalID != nil else { continue }
            let identitySeed = displayID ?? internalID ?? tag.tagName
            var changes: [(name: String, value: String?)] = [
                (
                    "data-og-internal-id",
                    opaqueInternalID(seed: "\(prefix)|\(identitySeed)|\(tag.range.lowerBound)")
                )
            ]
            if let displayID {
                changes.insert(("data-og-id", "\(prefix)\(displayID)"), at: 0)
            }
            applyAttributeChanges(
                changes,
                into: &result,
                tag: tag
            )
        }
        return result
    }

    private static func opaqueInternalID(seed: String) -> String {
        String(stableHash(seed), radix: 36)
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func unescapeAttributeText(_ value: String) -> String {
        decodingHTMLTextCharacterReferences(value)
    }

    private func findTagEnd(startingAt startIndex: String.Index) -> String.Index? {
        Self.findTagEnd(in: html, startingAt: startIndex)
    }

    private static func findTagEnd(in source: String, startingAt startIndex: String.Index) -> String.Index? {
        var index = startIndex
        var quote: Character?

        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }
            index = source.index(after: index)
        }

        return nil
    }

    private func splitOpeningTag(_ source: String) -> (name: String, attributes: String, selfClosing: Bool) {
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            if Self.isHTMLASCIIWhitespace(character) || character == "/" {
                break
            }
            index = source.index(after: index)
        }

        let name = String(source[source.startIndex..<index])
        let rest = String(source[index...])
        let selfClosingMarker = selfClosingMarkerRange(in: rest)
        let selfClosing = selfClosingMarker != nil
        let attributes = selfClosingMarker.map {
            Self.trimmingASCIIWhitespace(String(rest[..<$0.lowerBound]))
        } ?? rest
        return (name, attributes, selfClosing)
    }

    /// 開始tag末尾のslashがunquoted属性値ではなくself-closing marker tokenかを返します。
    private func selfClosingMarkerRange(in source: String) -> Range<String.Index>? {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            while cursor < source.endIndex, Self.isHTMLASCIIWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex else { return nil }

            if source[cursor] == "/" {
                let markerEnd = source.index(after: cursor)
                if source[markerEnd...].allSatisfy(Self.isHTMLASCIIWhitespace) {
                    return cursor..<markerEnd
                }
                cursor = markerEnd
                continue
            }

            while cursor < source.endIndex,
                  !Self.isHTMLASCIIWhitespace(source[cursor]),
                  source[cursor] != "=",
                  source[cursor] != "/" {
                cursor = source.index(after: cursor)
            }
            while cursor < source.endIndex, Self.isHTMLASCIIWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex, source[cursor] == "=" else { continue }

            cursor = source.index(after: cursor)
            while cursor < source.endIndex, Self.isHTMLASCIIWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex else { return nil }
            if source[cursor] == "\"" || source[cursor] == "'" {
                let quote = source[cursor]
                cursor = source.index(after: cursor)
                while cursor < source.endIndex, source[cursor] != quote {
                    cursor = source.index(after: cursor)
                }
                if cursor < source.endIndex {
                    cursor = source.index(after: cursor)
                }
            } else {
                while cursor < source.endIndex, !Self.isHTMLASCIIWhitespace(source[cursor]) {
                    cursor = source.index(after: cursor)
                }
            }
        }
        return nil
    }

    private func tagName(fromClosingTag source: String) -> String {
        let body = Self.trimmingASCIIWhitespace(String(source.dropFirst()))
        let endIndex = body.firstIndex(where: { Self.isHTMLASCIIWhitespace($0) || $0 == ">" }) ?? body.endIndex
        return String(body[..<endIndex]).lowercased()
    }

    private static func parseAttributes(_ source: String) -> [OpenGraphiteHTMLAttribute] {
        var attributes: [OpenGraphiteHTMLAttribute] = []
        var index = source.startIndex

        while index < source.endIndex {
            while index < source.endIndex, Self.isHTMLASCIIWhitespace(source[index]) {
                index = source.index(after: index)
            }
            guard index < source.endIndex else { break }

            let nameStart = index
            while index < source.endIndex,
                  !Self.isHTMLASCIIWhitespace(source[index]),
                  source[index] != "=",
                  source[index] != "/" {
                index = source.index(after: index)
            }
            let name = String(source[nameStart..<index])
            guard !name.isEmpty else {
                index = source.index(after: index)
                continue
            }

            while index < source.endIndex, Self.isHTMLASCIIWhitespace(source[index]) {
                index = source.index(after: index)
            }

            var value = ""
            if index < source.endIndex, source[index] == "=" {
                index = source.index(after: index)
                while index < source.endIndex, Self.isHTMLASCIIWhitespace(source[index]) {
                    index = source.index(after: index)
                }

                if index < source.endIndex, source[index] == "\"" || source[index] == "'" {
                    let quote = source[index]
                    index = source.index(after: index)
                    let valueStart = index
                    while index < source.endIndex, source[index] != quote {
                        index = source.index(after: index)
                    }
                    value = String(source[valueStart..<index])
                    if index < source.endIndex {
                        index = source.index(after: index)
                    }
                } else {
                    let valueStart = index
                    while index < source.endIndex, !Self.isHTMLASCIIWhitespace(source[index]) {
                        index = source.index(after: index)
                    }
                    value = String(source[valueStart..<index])
                }
            }

            attributes.append(
                OpenGraphiteHTMLAttribute(
                    name: name,
                    value: Self.unescapeAttributeText(value),
                    authoredValue: value
                )
            )
        }

        return attributes
    }

    private func containsStylesheetLink(href: String) -> Bool {
        parsedTags().contains { tag in
            guard tag.tagName == "link",
                  let rel = tag.attributeValue(named: "rel"),
                  let linkHref = tag.attributeValue(named: "href")
            else {
                return false
            }
            let relTokens = rel
                .lowercased()
                .split(whereSeparator: Self.isHTMLASCIIWhitespace)
                .map(String.init)
            return relTokens.contains("stylesheet") && linkHref == href
        }
    }

    private static func stylesheetLinkHTML(href: String) -> String {
        "    <link rel=\"stylesheet\" href=\"\(escapeAttributeValue(href))\">\n"
    }

    private static func escapeAttributeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private static func isValidDirectionFallback(_ value: String) -> Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty || ["ltr", "rtl", "auto"].contains(normalizedValue)
    }

    /// 論理名（日本語）: テキストvariant locale正規化関数
    /// 処理概要: HTML 属性名に使える locale suffix だけを許可します。
    ///
    /// - Parameter locale: 入力 locale。
    /// - Returns: 正規化済み locale。無効な場合は `nil`。
    private static func normalizedTextVariantLocale(_ locale: String) -> String? {
        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLocale.isEmpty else { return nil }
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard normalizedLocale.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return nil
        }
        return normalizedLocale
    }
}

private extension Array where Element == String {
    mutating func appendUnique(_ value: String) {
        if !contains(value) { append(value) }
    }
}

/// 論理名（日本語）: OpenGraphite HTMLタグ
/// 概要: 開始タグの文字範囲、タグ名、属性、DOM 深度を保持する内部モデルです。
///
/// プロパティ:
/// - `range`: HTML 文字列上の開始タグ範囲。
/// - `rawTagName`: 元 HTML のタグ名表記。
/// - `tagName`: 小文字化したタグ名。
/// - `attributes`: 属性の順序付き一覧。
/// - `depth`: DOM 深度。
/// - `selfClosing`: HTML void要素、またはforeign content内でlexical markerにより自己終了するタグか。
/// - `lexicalSelfClosing`: source開始tagがself-closing markerを持つか。
struct OpenGraphiteHTMLTag: Equatable {
    var range: Range<Int>
    var rawTagName: String
    var tagName: String
    var attributes: [OpenGraphiteHTMLAttribute]
    var depth: Int
    var selfClosing: Bool
    var lexicalSelfClosing: Bool

    var attributeDictionary: [String: String] {
        attributes.reduce(into: [String: String]()) { result, attribute in
            let normalizedName = attribute.name.lowercased()
            if result[normalizedName] == nil {
                result[normalizedName] = attribute.value
            }
        }
    }

    /// 論理名（日本語）: 属性値取得関数
    /// 処理概要: 指定名の属性値を返します。
    ///
    /// - Parameter name: 取得する属性名。
    /// - Returns: 属性値。存在しない場合は `nil`。
    func attributeValue(named name: String) -> String? {
        let normalizedName = name.lowercased()
        return attributes.first { $0.name.lowercased() == normalizedName }?.value
    }

    /// 論理名（日本語）: authored属性値取得関数
    /// 処理概要: 指定名のentity復号前source属性値を返します。
    ///
    /// - Parameter name: 取得する属性名。
    /// - Returns: authored属性値。存在しない場合は`nil`。
    func authoredAttributeValue(named name: String) -> String? {
        let normalizedName = name.lowercased()
        return attributes.first { $0.name.lowercased() == normalizedName }?.authoredValue
    }

    /// 論理名（日本語）: 属性別未解決HTML character reference判定関数
    /// 処理概要: 指定属性のauthored tokenに未解決HTML character referenceがあるかを判定します。
    ///
    /// - Parameter name: 判定する属性名。
    /// - Returns: 未解決character referenceを含む場合は`true`。
    func containsUnresolvedHTMLCharacterReference(named name: String) -> Bool {
        guard let authoredValue = authoredAttributeValue(named: name) else { return false }
        return OpenGraphiteHTMLDocument.containsUnresolvedHTMLCharacterReference(authoredValue)
    }

    /// 論理名（日本語）: 空文字nil属性取得関数
    /// 処理概要: 空文字の属性値を `nil` として扱い、UI / JSON 向けの省略値にします。
    ///
    /// - Parameter name: 取得する属性名。
    /// - Returns: 空でない属性値。
    func emptyNilAttribute(named name: String) -> String? {
        guard let value = attributeValue(named: name) else { return nil }
        let normalized = OpenGraphiteHTMLDocument.trimmingASCIIWhitespace(value)
        return normalized.isEmpty ? nil : normalized
    }

}

/// 論理名（日本語）: OpenGraphite HTML要素
/// 概要: 開始タグ、内容範囲、要素全体範囲を文字オフセットで保持する内部モデルです。
///
/// プロパティ:
/// - `tag`: 開始タグモデル。
/// - `contentRange`: 開始タグ直後から閉じタグ直前までの範囲。
/// - `fullRange`: 開始タグから閉じタグ終端までの範囲。
struct OpenGraphiteHTMLElement: Equatable {
    var tag: OpenGraphiteHTMLTag
    var contentRange: Range<Int>
    var fullRange: Range<Int>
}

/// 論理名（日本語）: OpenGraphite HTML属性
/// 概要: HTML 開始タグ内の単一属性を順序付きで保持します。
///
/// プロパティ:
/// - `name`: 属性名。
/// - `value`: DOM semantic属性値。
/// - `authoredValue`: entity復号前のsource属性値。
struct OpenGraphiteHTMLAttribute: Equatable {
    var name: String
    var value: String
    var authoredValue: String
}

/// 論理名（日本語）: OpenGraphite CSS style
/// 概要: CSS 宣言を順序付きで保持し、legacy inline style と companion CSS rule body の解析に使います。
///
/// プロパティ:
/// - `declarations`: CSS 宣言の順序付き一覧。
struct OpenGraphiteCSSStyle: Equatable {
    var declarations: [OpenGraphiteCSSDeclaration]

    /// 論理名（日本語）: CSS style解析関数
    /// 処理概要: CSS 宣言文字列を宣言一覧へ分解します。
    ///
    /// - Parameter source: HTML 属性内の style 値。
    /// - Returns: CSS style モデル。
    static func parse(_ source: String) -> OpenGraphiteCSSStyle {
        let declarations = splitDeclarations(source)
            .compactMap { item -> OpenGraphiteCSSDeclaration? in
                let pair = item.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2 else { return nil }
                let name = trimmingCSSWhitespace(pair[0])
                let value = trimmingCSSWhitespace(pair[1])
                guard !name.isEmpty else { return nil }
                return OpenGraphiteCSSDeclaration(name: name, value: value)
            }
        return OpenGraphiteCSSStyle(declarations: declarations)
    }

    /// 論理名（日本語）: CSS宣言分割関数
    /// 処理概要: CSS 宣言文字列を quote と括弧の内側を保ったまま宣言単位へ分割します。
    ///
    /// - Parameter source: CSS 宣言文字列。
    /// - Returns: 宣言ごとの文字列。
    private static func splitDeclarations(_ source: String) -> [String] {
        var declarations: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?

        func flush() {
            let declaration = trimmingCSSWhitespace(current)
            if !declaration.isEmpty {
                declarations.append(declaration)
            }
            current = ""
        }

        for character in source {
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                current.append(character)
                continue
            }

            if character == "(" {
                depth += 1
                current.append(character)
                continue
            }

            if character == ")" {
                depth = max(depth - 1, 0)
                current.append(character)
                continue
            }

            if character == ";" && depth == 0 {
                flush()
                continue
            }

            current.append(character)
        }

        flush()
        return declarations
    }

    /// 論理名（日本語）: CSS宣言設定関数
    /// 処理概要: 指定 CSS declaration を設定し、空値の場合は宣言を削除します。
    ///
    /// - Parameters:
    ///   - name: CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: 設定値。空の場合は削除。
    mutating func set(_ name: String, value: String) {
        let normalizedValue = Self.trimmingCSSWhitespace(value)
        if normalizedValue.isEmpty {
            declarations.removeAll { $0.name == name }
            return
        }

        if let index = declarations.firstIndex(where: { $0.name == name }) {
            declarations[index].value = normalizedValue
        } else {
            declarations.append(OpenGraphiteCSSDeclaration(name: name, value: normalizedValue))
        }
    }

    /// 論理名（日本語）: CSS宣言一括削除関数
    /// 処理概要: 指定された CSS declaration 名に一致する宣言を削除します。
    ///
    /// - Parameter names: 削除対象の CSS property または OpenGraphite 予約 custom property 名。
    mutating func removeVariables(_ names: Set<String>) {
        declarations.removeAll { names.contains($0.name) }
    }

    /// CSS Syntaxで定義されたASCII whitespaceだけを両端から除きます。
    private static func trimmingCSSWhitespace<S: StringProtocol>(_ value: S) -> String {
        var result = String(value)
        while let first = result.first, isCSSWhitespace(first) {
            result.removeFirst()
        }
        while let last = result.last, isCSSWhitespace(last) {
            result.removeLast()
        }
        return result
    }

    private static func isCSSWhitespace(_ character: Character) -> Bool {
        !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x09
                || scalar.value == 0x0A
                || scalar.value == 0x0C
                || scalar.value == 0x0D
                || scalar.value == 0x20
        }
    }

    /// 論理名（日本語）: OpenGraphite CSS宣言辞書化関数
    /// 処理概要: contract で定義された編集対象 CSS 宣言だけを JSON / node model 向け辞書へ変換します。
    ///
    /// - Parameter contract: 抽出対象の CSS 宣言を定義する OpenGraphite 契約。
    /// - Returns: OpenGraphite 編集対象 CSS 宣言辞書。
    func openGraphiteDeclarations(contract: OpenGraphiteContract) -> [String: String] {
        var result: [String: String] = [:]
        for declaration in declarations where contract.isKnownCSSVariable(declaration.name) {
            result[declaration.name] = declaration.value
        }
        return result
    }

    /// 論理名（日本語）: CSS style直列化関数
    /// 処理概要: CSS 宣言一覧を declaration list 文字列に変換します。
    ///
    /// - Returns: `name:value;` 形式の style 文字列。
    func serialized() -> String {
        declarations.map { "\($0.name):\($0.value);" }.joined(separator: " ")
    }
}

/// 論理名（日本語）: OpenGraphite CSS宣言
/// 概要: CSS source 内の単一 CSS 宣言を表します。
///
/// プロパティ:
/// - `name`: CSS property または custom property 名。
/// - `value`: CSS 値。
struct OpenGraphiteCSSDeclaration: Equatable {
    var name: String
    var value: String
}

private extension String {
    /// 論理名（日本語）: 文字オフセット範囲置換関数
    /// 処理概要: 文字数ベースの範囲を現在の String.Index へ変換して置換します。
    ///
    /// - Parameters:
    ///   - range: 置換対象の文字オフセット範囲。
    ///   - replacement: 置換後文字列。
    mutating func replaceRange(_ range: Range<Int>, with replacement: String) {
        let lower = index(startIndex, offsetBy: range.lowerBound)
        let upper = index(startIndex, offsetBy: range.upperBound)
        replaceSubrange(lower..<upper, with: replacement)
    }

    /// 論理名（日本語）: 文字オフセット挿入関数
    /// 処理概要: 文字数ベースの位置を現在の String.Index へ変換して文字列を挿入します。
    ///
    /// - Parameters:
    ///   - string: 挿入する文字列。
    ///   - offset: 挿入位置の文字オフセット。
    mutating func insert(_ string: String, atOffset offset: Int) {
        let index = index(startIndex, offsetBy: offset)
        insert(contentsOf: string, at: index)
    }

    /// 論理名（日本語）: 文字オフセット部分文字列取得関数
    /// 処理概要: 文字数ベースの範囲を現在の String.Index へ変換して部分文字列を返します。
    ///
    /// - Parameter range: 取得対象の文字オフセット範囲。
    /// - Returns: 部分文字列。
    func substring(_ range: Range<Int>) -> String {
        let lower = index(startIndex, offsetBy: range.lowerBound)
        let upper = index(startIndex, offsetBy: range.upperBound)
        return String(self[lower..<upper])
    }
}
