import Foundation

/// HTML属性値のtoken分割に使うASCII whitespaceだけを判定します。
private func isHTMLASCIIWhitespace(_ character: Character) -> Bool {
    !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
        scalar.value == 0x09
            || scalar.value == 0x0A
            || scalar.value == 0x0C
            || scalar.value == 0x0D
            || scalar.value == 0x20
    }
}

/// CSS Syntaxのwhitespaceだけをsource両端から除きます。
private func trimmingCSSWhitespace<S: StringProtocol>(_ value: S) -> String {
    var result = String(value)
    while let first = result.first, OpenGraphiteCSSIdentifier.isCSSWhitespace(first) {
        result.removeFirst()
    }
    while let last = result.last, OpenGraphiteCSSIdentifier.isCSSWhitespace(last) {
        result.removeLast()
    }
    return result
}

/// 論理名（日本語）: CSS identifier decoder
/// 概要: CSS Syntaxのidentifier escapeをsemantic code pointへ復号し、authored sourceとは別の照合値を生成します。
private enum OpenGraphiteCSSIdentifier {
    /// 論理名（日本語）: CSS identifier token
    /// 概要: 復号済みidentifier値と、optional whitespaceを含むauthored token終端を保持します。
    struct Token {
        var value: String
        var end: String.Index
    }

    /// 論理名（日本語）: CSS escape token
    /// 概要: 1–6桁hexまたはescaped code pointの復号値とauthored token終端を保持します。
    struct Escape {
        var value: String
        var end: String.Index
    }

    /// 論理名（日本語）: CSS identifier消費関数
    /// 処理概要: name code pointとescapeを一つのidentifierとして読み、escapeだけをsemantic値へ復号します。
    ///
    /// - Parameters:
    ///   - source: authored CSS source。
    ///   - start: identifier開始位置。
    ///   - upperBound: scanner範囲の終端。
    /// - Returns: 1文字以上を消費したtoken。identifierでなければ`nil`。
    static func consume(
        in source: String,
        from start: String.Index,
        upperBound: String.Index
    ) -> Token? {
        var cursor = start
        var value = ""
        while cursor < upperBound {
            let character = source[cursor]
            if character == "\\" {
                guard let escape = consumeEscape(in: source, at: cursor, upperBound: upperBound) else {
                    return nil
                }
                value.append(contentsOf: escape.value)
                cursor = escape.end
            } else if isNameCodePoint(character) {
                value.append(character)
                cursor = source.index(after: cursor)
            } else {
                break
            }
        }
        guard cursor > start else { return nil }
        return Token(value: value, end: cursor)
    }

    /// 論理名（日本語）: CSS identifier範囲復号関数
    /// 処理概要: 指定範囲全体が単一identifierの場合だけsemantic値を返します。
    ///
    /// - Parameters:
    ///   - source: authored CSS source。
    ///   - range: identifierのauthored範囲。
    /// - Returns: 復号済みidentifier。範囲に別tokenを含む場合は`nil`。
    static func decode(in source: String, range: Range<String.Index>) -> String? {
        guard let token = consume(in: source, from: range.lowerBound, upperBound: range.upperBound),
              token.end == range.upperBound
        else { return nil }
        return token.value
    }

    /// 論理名（日本語）: CSS escape復号関数
    /// 処理概要: 1–6桁hex escapeと直後のoptional CSS whitespace、または単一escaped code pointを消費します。
    ///
    /// - Parameters:
    ///   - source: authored CSS source。
    ///   - index: backslash位置。
    ///   - upperBound: scanner範囲の終端。
    /// - Returns: 復号値とescape終端。newline escapeや末尾backslashは`nil`。
    static func consumeEscape(
        in source: String,
        at index: String.Index,
        upperBound: String.Index
    ) -> Escape? {
        var cursor = source.index(after: index)
        guard cursor < upperBound, !isCSSNewline(source[cursor]) else { return nil }

        var hexadecimal = ""
        while cursor < upperBound,
              hexadecimal.count < 6,
              isHexDigit(source[cursor]) {
            hexadecimal.append(source[cursor])
            cursor = source.index(after: cursor)
        }
        if !hexadecimal.isEmpty {
            if cursor < upperBound, isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
            }
            let codePoint = UInt32(hexadecimal, radix: 16) ?? 0
            let value: String
            if codePoint == 0
                || codePoint > 0x10FFFF
                || (0xD800...0xDFFF).contains(codePoint) {
                value = "\u{FFFD}"
            } else if let scalar = UnicodeScalar(codePoint) {
                value = String(Character(scalar))
            } else {
                value = "\u{FFFD}"
            }
            return Escape(value: value, end: cursor)
        }

        let escaped = source[cursor]
        cursor = source.index(after: cursor)
        return Escape(value: escaped == "\0" ? "\u{FFFD}" : String(escaped), end: cursor)
    }

    /// 論理名（日本語）: CSS name code point判定関数
    /// 処理概要: 指定文字がidentifierを構成できるCSS name code pointかを判定します。
    ///
    /// - Parameter character: 判定する文字。
    /// - Returns: CSS name code pointの場合は`true`。
    static func isNameCodePoint(_ character: Character) -> Bool {
        character.isLetter
            || character.isNumber
            || character == "-"
            || character == "_"
            || character.unicodeScalars.allSatisfy { $0.value >= 0x80 }
    }

    /// 論理名（日本語）: CSS whitespace判定関数
    /// 処理概要: 指定文字がCSS Syntax上のwhitespace code pointだけで構成されるかを判定します。
    ///
    /// - Parameter character: 判定する文字。
    /// - Returns: CSS whitespaceの場合は`true`。
    static func isCSSWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x09
                || scalar.value == 0x0A
                || scalar.value == 0x0C
                || scalar.value == 0x0D
                || scalar.value == 0x20
        }
    }

    private static func isCSSNewline(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x0A || scalar.value == 0x0C || scalar.value == 0x0D
        }
    }

    private static func isHexDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else { return false }
        return (48...57).contains(value)
            || (65...70).contains(value)
            || (97...102).contains(value)
    }
}

/// 論理名（日本語）: Legacy CSS移行結果
/// 概要: lossless source patch後のCSS、検出したlegacy有無、未対応reserved propertyを保持します。
///
/// プロパティ:
/// - `source`: 既知mappingだけを適用したCSS source。
/// - `detectedLegacy`: 入力に既知または未知の`--og-*`/legacy selectorが存在した場合は`true`。
/// - `unknownReservedProperties`: mapping catalogにない`--og-*`名。
/// - `unsupportedLegacyConstructs`: losslessに変換できないlegacy selector・at-rule・value構文。
/// - `destinationConflicts`: authored destinationと競合する生成custom property。
/// - `existingGeneratedClassNames`: 入力に既存のversioned migration class。
/// - `generatedClassNames`: このmigrationが生成するversioned class。
/// - `observedDestinationAttributes`: authored selectorが観測するstandard migration destination属性。
/// - `hasGeneratedClassObserver`: class属性の有無・値を観測し、generated class追加後にmatchが変わり得る場合は`true`。
/// - `hasGeneratedCustomPropertyStyleObserver`: inline style値または列全体を観測するCSSがある場合は`true`。
/// - `authoredCustomPropertyNames`: 入力にauthored済みのcustom property名。
/// - `generatedCustomPropertyNames`: このmigrationが生成するcustom property名。
struct OpenGraphiteLegacyCSSMigrationResult: Equatable {
    var source: String
    var detectedLegacy: Bool
    var unknownReservedProperties: [String]
    var unsupportedLegacyConstructs: [String] = []
    var destinationConflicts: [String] = []
    var existingGeneratedClassNames: [String] = []
    var generatedClassNames: [String] = []
    var observedDestinationAttributes: Set<String> = []
    var hasGeneratedClassObserver = false
    var hasGeneratedCustomPropertyStyleObserver = false
    var authoredCustomPropertyNames: [String] = []
    var generatedCustomPropertyNames: [String] = []
}

/// 論理名（日本語）: Legacy CSS明示移行器
/// 概要: known reserved custom propertyとlegacy selectorだけをrange-preservingに標準CSS/class selectorへ変換します。
enum OpenGraphiteLegacyCSSMigrator {
    private static let customPropertyMappings: [String: String] = [
        "--og-page-background": "--migrated-v1-page-background",
        "--og-text-color": "--migrated-v1-text-color",
        "--og-muted-color": "--migrated-v1-muted-color",
        "--og-accent": "--migrated-v1-accent",
        "--og-accent-foreground": "--migrated-v1-accent-foreground",
        "--og-font-family-default": "--migrated-v1-font-family-default",
        "--og-active-font-family": "--migrated-v1-font-family-active",
        "--og-object-fit": "--migrated-v1-object-fit",
        "--og-stroke-width": "--migrated-v1-stroke-width",
        "--og-icon-url": "--migrated-v1-icon-url",
        "--og-scale-x": "--migrated-v1-scale-x",
        "--og-scale-y": "--migrated-v1-scale-y"
    ]
    private static let runtimeCustomProperties: Set<String> = [
        "--og-edit-width",
        "--og-edit-min-height",
        "--og-preview-locale",
        "--og-preview-dir",
        "--og-drag-x",
        "--og-drag-y",
        "--og-reorder-x",
        "--og-reorder-y"
    ]
    /// 論理名（日本語）: Legacy CSS source移行関数
    /// 処理概要: runtime-only rule/declarationを除去し、既知reserved tokenとlegacy selectorを決定的に置換します。
    ///
    /// - Parameter source: authored CSS source。
    /// - Returns: unrelated byteを保持した移行候補と未知reserved token一覧。
    static func migrate(_ source: String) -> OpenGraphiteLegacyCSSMigrationResult {
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let existingGeneratedClasses = generatedMigrationClassNames(in: source)
        let authoredMigrationProperties = migrationCustomPropertyNames(in: source)
        let declarations = declarationMigration(in: source, document: document)
        let selectors = selectorMigration(in: source, document: document)
        let observers = migrationObserverInventory(in: source, document: document)
        let unsupportedAtRules = unsupportedLegacyAtRules(in: source, document: document)
        let unsupported = Array(Set(
            declarations.unsupported + selectors.unsupported + observers.unsupported + unsupportedAtRules
        )).sorted()
        let unknown = Array(Set(declarations.unknownReservedProperties)).sorted()
        let conflicts = Array(Set(declarations.destinationConflicts)).sorted()
        let detected = declarations.detectedLegacy || selectors.detectedLegacy
            || !observers.unsupported.isEmpty || !unsupportedAtRules.isEmpty
        guard unknown.isEmpty, unsupported.isEmpty, conflicts.isEmpty else {
            return OpenGraphiteLegacyCSSMigrationResult(
                source: source,
                detectedLegacy: detected,
                unknownReservedProperties: unknown,
                unsupportedLegacyConstructs: unsupported,
                destinationConflicts: conflicts,
                existingGeneratedClassNames: existingGeneratedClasses,
                generatedClassNames: [],
                observedDestinationAttributes: observers.observedDestinationAttributes,
                hasGeneratedClassObserver: observers.hasGeneratedClassObserver,
                hasGeneratedCustomPropertyStyleObserver: observers.hasGeneratedCustomPropertyStyleObserver,
                authoredCustomPropertyNames: authoredMigrationProperties,
                generatedCustomPropertyNames: declarations.generatedCustomPropertyNames
            )
        }
        let removedRuleRanges = selectors.removedRuleRanges
        let declarationPatches = declarations.patches.filter { patch in
            !removedRuleRanges.contains {
                $0.lowerBound <= patch.range.lowerBound && patch.range.upperBound <= $0.upperBound
            }
        }
        let migrated = applying(declarationPatches + selectors.patches, to: source)
        let remaining = remainingLegacyConstructs(in: migrated)
        guard remaining.isEmpty else {
            return OpenGraphiteLegacyCSSMigrationResult(
                source: source,
                detectedLegacy: true,
                unknownReservedProperties: [],
                unsupportedLegacyConstructs: remaining,
                destinationConflicts: [],
                existingGeneratedClassNames: existingGeneratedClasses,
                generatedClassNames: [],
                observedDestinationAttributes: observers.observedDestinationAttributes,
                hasGeneratedClassObserver: observers.hasGeneratedClassObserver,
                hasGeneratedCustomPropertyStyleObserver: observers.hasGeneratedCustomPropertyStyleObserver,
                authoredCustomPropertyNames: authoredMigrationProperties,
                generatedCustomPropertyNames: declarations.generatedCustomPropertyNames
            )
        }
        return OpenGraphiteLegacyCSSMigrationResult(
            source: migrated,
            detectedLegacy: detected,
            unknownReservedProperties: [],
            unsupportedLegacyConstructs: [],
            destinationConflicts: [],
            existingGeneratedClassNames: existingGeneratedClasses,
            generatedClassNames: selectors.generatedClassNames,
            observedDestinationAttributes: observers.observedDestinationAttributes,
            hasGeneratedClassObserver: observers.hasGeneratedClassObserver,
            hasGeneratedCustomPropertyStyleObserver: observers.hasGeneratedCustomPropertyStyleObserver,
            authoredCustomPropertyNames: authoredMigrationProperties,
            generatedCustomPropertyNames: declarations.generatedCustomPropertyNames
        )
    }

    /// 論理名（日本語）: Inline CSS宣言list移行関数
    /// 処理概要: synthetic selectorをsourceへ保存せず、同じdeclaration/`var()` token migratorを属性値rangeへ適用します。
    ///
    /// - Parameter source: `style`属性内のauthored declaration list。
    /// - Returns: unrelated declaration triviaを保持したcandidateとblocking情報。
    static func migrateDeclarationList(_ source: String) -> OpenGraphiteLegacyCSSMigrationResult {
        let prefix = ".og-inline-migration{"
        let wrapped = prefix + source + "}"
        let result = migrate(wrapped)
        let migratedSource: String
        if result.source.hasPrefix(prefix), result.source.hasSuffix("}") {
            migratedSource = String(result.source.dropFirst(prefix.count).dropLast())
        } else {
            migratedSource = source
        }
        return OpenGraphiteLegacyCSSMigrationResult(
            source: migratedSource,
            detectedLegacy: result.detectedLegacy,
            unknownReservedProperties: result.unknownReservedProperties,
            unsupportedLegacyConstructs: result.unsupportedLegacyConstructs,
            destinationConflicts: result.destinationConflicts,
            existingGeneratedClassNames: result.existingGeneratedClassNames,
            generatedClassNames: result.generatedClassNames,
            observedDestinationAttributes: result.observedDestinationAttributes,
            hasGeneratedClassObserver: result.hasGeneratedClassObserver,
            hasGeneratedCustomPropertyStyleObserver: result.hasGeneratedCustomPropertyStyleObserver,
            authoredCustomPropertyNames: result.authoredCustomPropertyNames,
            generatedCustomPropertyNames: result.generatedCustomPropertyNames
        )
    }

    private struct Patch {
        var range: Range<Int>
        var value: String
    }

    private struct DeclarationMigration {
        var patches: [Patch]
        var detectedLegacy: Bool
        var unknownReservedProperties: [String]
        var unsupported: [String]
        var destinationConflicts: [String]
        var authoredCustomPropertyNames: [String]
        var generatedCustomPropertyNames: [String]
    }

    private struct SelectorMigration {
        var patches: [Patch]
        var removedRuleRanges: [Range<Int>]
        var detectedLegacy: Bool
        var unsupported: [String]
        var generatedClassNames: [String]
    }

    private struct MigrationObserverInventory {
        var observedDestinationAttributes: Set<String>
        var hasGeneratedClassObserver: Bool
        var hasGeneratedCustomPropertyStyleObserver: Bool
        var unsupported: [String]
    }

    private struct VariableFunction {
        var range: Range<Int>
        var nameRange: Range<Int>
        var name: String
        var fallback: String?
    }

    private static func declarationMigration(
        in source: String,
        document: OpenGraphiteCSSSourceDocument
    ) -> DeclarationMigration {
        let declarations = document.rules.flatMap(\.declarations)
        let authoredDestinations = Set(declarations.map(\.name))
        var patches: [Patch] = []
        var detected = false
        var unknown: [String] = []
        var unsupported: [String] = []
        var destinations: [String] = []
        var generatedDestinations: Set<String> = []

        for declaration in declarations {
            let functions = variableFunctions(in: declaration.valueRange, source: source)
            if isLegacyReservedCustomPropertyName(declaration.name) {
                detected = true
                if runtimeCustomProperties.contains(declaration.name) {
                    patches.append(Patch(range: declaration.range, value: ""))
                } else if let destination = destinationName(for: declaration.name) {
                    generatedDestinations.insert(destination)
                    if authoredDestinations.contains(destination) {
                        destinations.append(destination)
                    }
                    if let nameRange = declarationNameRange(declaration, in: source) {
                        patches.append(Patch(range: nameRange, value: destination))
                    } else {
                        unsupported.append("escaped-or-malformed-declaration-name:\(declaration.name)")
                    }
                } else {
                    unknown.append(declaration.name)
                }
            }
            var replacedRuntimeFunctionRanges: [Range<Int>] = []
            for function in functions {
                guard isLegacyReservedCustomPropertyName(function.name) else { continue }
                if replacedRuntimeFunctionRanges.contains(where: {
                    $0.lowerBound <= function.range.lowerBound && function.range.upperBound <= $0.upperBound
                }) { continue }
                detected = true
                if runtimeCustomProperties.contains(function.name) {
                    let replacement: String
                    if let fallback = function.fallback {
                        guard let migratedFallback = migratedFallbackValue(fallback) else {
                            unsupported.append("unsupported-runtime-var-fallback:\(function.name)")
                            continue
                        }
                        replacement = migratedFallback
                    } else if declaration.name.hasPrefix("--") {
                        unsupported.append("runtime-var-without-fallback-in-custom-property:\(function.name)")
                        continue
                    } else {
                        replacement = "unset"
                    }
                    patches.append(Patch(range: function.range, value: replacement))
                    replacedRuntimeFunctionRanges.append(function.range)
                } else if let destination = destinationName(for: function.name) {
                    generatedDestinations.insert(destination)
                    patches.append(Patch(range: function.nameRange, value: destination))
                } else {
                    unknown.append(function.name)
                }
            }
        }
        return DeclarationMigration(
            patches: patches,
            detectedLegacy: detected,
            unknownReservedProperties: unknown,
            unsupported: unsupported,
            destinationConflicts: destinations,
            authoredCustomPropertyNames: authoredDestinations.filter { $0.hasPrefix("--") }.sorted(),
            generatedCustomPropertyNames: generatedDestinations.sorted()
        )
    }

    private static func destinationName(for name: String) -> String? {
        if let mapped = customPropertyMappings[name] { return mapped }
        guard name.range(
            of: #"^--og-font-family-[a-z0-9]+(?:-[a-z0-9]+)*$"#,
            options: .regularExpression
        ) != nil else { return nil }
        return "--migrated-v1-font-family-" + String(name.dropFirst("--og-font-family-".count))
    }

    /// 論理名（日本語）: Legacy custom property移行先解決関数
    /// 処理概要: HTML character referenceをsemantic decodeしたcustom propertyにも共有する決定的な移行先を返します。
    ///
    /// - Parameter name: Semantic decode後のlegacy custom property名。
    /// - Returns: 対応するstandard/generic destination名。catalog外の場合は`nil`。
    static func migrationDestinationName(for name: String) -> String? {
        destinationName(for: name)
    }

    /// 論理名（日本語）: Legacy reserved property判定関数
    /// 処理概要: 入力名がASCII catalog tokenとして予約されたlegacy custom propertyかを判定します。
    ///
    /// - Parameter name: 判定するcustom property名。
    /// - Returns: Legacy reserved namespaceの完全なASCII tokenである場合は`true`。
    static func isLegacyReservedName(_ name: String) -> Bool {
        isLegacyReservedCustomPropertyName(name)
    }

    private static func isLegacyReservedCustomPropertyName(_ name: String) -> Bool {
        guard name.hasPrefix("--og-"), name.count > "--og-".count else { return false }
        return name.dropFirst("--og-".count).unicodeScalars.allSatisfy { scalar in
            (0x30...0x39).contains(scalar.value)
                || (0x41...0x5A).contains(scalar.value)
                || (0x61...0x7A).contains(scalar.value)
                || scalar.value == 0x2D
                || scalar.value == 0x5F
        }
    }

    private static func migratedFallbackValue(_ value: String) -> String? {
        let prefix = ".og-fallback{color:"
        let wrapped = prefix + value + "}"
        let document = OpenGraphiteCSSSourceDocument.parse(wrapped)
        let migration = declarationMigration(in: wrapped, document: document)
        guard migration.unknownReservedProperties.isEmpty,
              migration.unsupported.isEmpty,
              migration.destinationConflicts.isEmpty
        else { return nil }
        let migrated = applying(migration.patches, to: wrapped)
        guard migrated.hasPrefix(prefix), migrated.hasSuffix("}") else { return nil }
        return String(migrated.dropFirst(prefix.count).dropLast())
    }

    private static func declarationNameRange(
        _ declaration: OpenGraphiteCSSSourceDeclaration,
        in source: String
    ) -> Range<Int>? {
        let lower = source.index(source.startIndex, offsetBy: declaration.range.lowerBound)
        let upper = source.index(source.startIndex, offsetBy: declaration.valueRange.lowerBound)
        let nameStart = skipCSSTrivia(in: source, from: lower, upperBound: upper)
        var cursor = nameStart
        guard let token = OpenGraphiteCSSIdentifier.consume(in: source, from: cursor, upperBound: upper),
              token.value == declaration.name
        else { return nil }
        cursor = token.end
        return source.distance(from: source.startIndex, to: nameStart)..<source.distance(from: source.startIndex, to: cursor)
    }

    private static func variableFunctions(
        in range: Range<Int>,
        source: String
    ) -> [VariableFunction] {
        let lower = source.index(source.startIndex, offsetBy: range.lowerBound)
        let upper = source.index(source.startIndex, offsetBy: range.upperBound)
        var result: [VariableFunction] = []
        var cursor = lower
        while cursor < upper {
            if let skipped = skippedCSSCommentOrString(in: source, at: cursor, upperBound: upper) {
                cursor = skipped
                continue
            }
            guard OpenGraphiteCSSIdentifier.isNameCodePoint(source[cursor]) || source[cursor] == "\\",
                  let identifier = OpenGraphiteCSSIdentifier.consume(in: source, from: cursor, upperBound: upper)
            else {
                cursor = source.index(after: cursor)
                continue
            }
            guard identifier.end < upper, source[identifier.end] == "(" else {
                cursor = identifier.end
                continue
            }
            guard let blockEnd = cssParenthesisEnd(in: source, openingAt: identifier.end, upperBound: upper) else {
                cursor = identifier.end
                continue
            }
            if identifier.value.caseInsensitiveCompare("url") == .orderedSame {
                cursor = blockEnd
                continue
            }
            guard identifier.value.caseInsensitiveCompare("var") == .orderedSame else {
                cursor = source.index(after: identifier.end)
                continue
            }
            let argumentsStart = source.index(after: identifier.end)
            let argumentsEnd = source.index(before: blockEnd)
            let nameStart = skipCSSTrivia(in: source, from: argumentsStart, upperBound: argumentsEnd)
            guard let nameToken = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: nameStart,
                upperBound: argumentsEnd
            ) else {
                cursor = blockEnd
                continue
            }
            let afterName = skipCSSTrivia(in: source, from: nameToken.end, upperBound: argumentsEnd)
            var fallback: String?
            if afterName < argumentsEnd, source[afterName] == "," {
                let fallbackStart = skipCSSTrivia(
                    in: source,
                    from: source.index(after: afterName),
                    upperBound: argumentsEnd
                )
                fallback = String(source[fallbackStart..<argumentsEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if afterName != argumentsEnd {
                cursor = blockEnd
                continue
            }
            result.append(VariableFunction(
                range: offsetRange(cursor..<blockEnd, in: source),
                nameRange: offsetRange(nameStart..<nameToken.end, in: source),
                name: nameToken.value,
                fallback: fallback
            ))
            cursor = nameToken.end
        }
        return result
    }

    private static func selectorMigration(
        in source: String,
        document: OpenGraphiteCSSSourceDocument
    ) -> SelectorMigration {
        var patches: [Patch] = []
        var removedRules: [Range<Int>] = []
        var detected = false
        var unsupported: [String] = []
        var generatedClassNames: Set<String> = []
        for rule in document.rules {
            guard let preludeRange = selectorPreludeRange(rule, in: source) else { continue }
            let rawPrelude = substring(preludeRange, in: source)
            let branches = splitSelectorBranches(rawPrelude)
            var migratedBranches: [String] = []
            var changed = false
            for branch in branches {
                let result = migrateSelectorBranch(branch)
                detected = detected || result.detectedLegacy
                unsupported.append(contentsOf: result.unsupported)
                if result.remove {
                    changed = true
                    continue
                }
                changed = changed || result.source != branch
                migratedBranches.append(result.source)
                generatedClassNames.formUnion(result.generatedClassNames)
            }
            guard changed else { continue }
            if migratedBranches.isEmpty {
                patches.append(Patch(range: rule.range, value: ""))
                removedRules.append(rule.range)
            } else {
                patches.append(Patch(range: preludeRange, value: migratedBranches.joined(separator: ",")))
            }
        }
        return SelectorMigration(
            patches: patches,
            removedRuleRanges: removedRules,
            detectedLegacy: detected,
            unsupported: unsupported,
            generatedClassNames: generatedClassNames.sorted()
        )
    }

    private static func selectorPreludeRange(
        _ rule: OpenGraphiteCSSSourceRule,
        in source: String
    ) -> Range<Int>? {
        let lower = rule.range.lowerBound
        let upper = max(rule.bodyRange.lowerBound - 1, lower)
        let candidate = substring(lower..<upper, in: source)
        guard let range = candidate.range(of: rule.selectorText) else { return nil }
        let localLower = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
        let localUpper = candidate.distance(from: candidate.startIndex, to: range.upperBound)
        return (lower + localLower)..<(lower + localUpper)
    }

    private static func splitSelectorBranches(_ selector: String) -> [String] {
        var branches: [String] = []
        var start = selector.startIndex
        var cursor = start
        var round = 0
        var square = 0
        while cursor < selector.endIndex {
            if let skipped = skippedCSSCommentOrString(in: selector, at: cursor, upperBound: selector.endIndex) {
                cursor = skipped
                continue
            }
            if selector[cursor] == "\\",
               let escape = OpenGraphiteCSSIdentifier.consumeEscape(
                in: selector,
                at: cursor,
                upperBound: selector.endIndex
               ) {
                cursor = escape.end
                continue
            }
            let character = selector[cursor]
            if character == "(" { round += 1 }
            else if character == ")" { round = max(round - 1, 0) }
            else if character == "[" { square += 1 }
            else if character == "]" { square = max(square - 1, 0) }
            else if character == ",", round == 0, square == 0 {
                branches.append(String(selector[start..<cursor]))
                start = selector.index(after: cursor)
            }
            cursor = selector.index(after: cursor)
        }
        branches.append(String(selector[start..<selector.endIndex]))
        return branches
    }

    private static func migrateSelectorBranch(
        _ branch: String
    ) -> (source: String, detectedLegacy: Bool, remove: Bool, unsupported: [String], generatedClassNames: [String]) {
        let functional = removingKnownRuntimeFunctionalAlternatives(in: branch)
        let workingBranch = functional.source
        var localPatches: [Patch] = []
        var detected = functional.detectedLegacy
        var remove = false
        var unsupported: [String] = []
        var generatedClassNames: Set<String> = []
        var cursor = workingBranch.startIndex
        var parenthesisDepth = 0
        while cursor < workingBranch.endIndex {
            if let skipped = skippedCSSCommentOrString(in: workingBranch, at: cursor, upperBound: workingBranch.endIndex) {
                cursor = skipped
                continue
            }
            if workingBranch[cursor] == "(" {
                parenthesisDepth += 1
                cursor = workingBranch.index(after: cursor)
                continue
            }
            if workingBranch[cursor] == ")" {
                parenthesisDepth = max(parenthesisDepth - 1, 0)
                cursor = workingBranch.index(after: cursor)
                continue
            }
            guard workingBranch[cursor] == "[",
                  let end = cssSquareBracketEnd(in: workingBranch, openingAt: cursor)
            else {
                cursor = workingBranch.index(after: cursor)
                continue
            }
            let raw = String(workingBranch[cursor..<end])
            let parsed = legacySelectorAttribute(raw)
            if parsed.detectedLegacy { detected = true }
            if parsed.runtime {
                if parenthesisDepth == 0 {
                    remove = true
                } else {
                    unsupported.append("runtime-selector-in-functional-pseudo:\(raw)")
                }
            }
            if let replacement = parsed.replacement {
                localPatches.append(Patch(range: offsetRange(cursor..<end, in: workingBranch), value: replacement))
                generatedClassNames.formUnion(generatedMigrationClassNames(in: replacement))
            }
            if let reason = parsed.unsupported { unsupported.append(reason) }
            cursor = end
        }
        if remove {
            return (workingBranch, detected, true, [], [])
        }
        return (
            applying(localPatches, to: workingBranch),
            detected,
            false,
            unsupported,
            generatedClassNames.sorted()
        )
    }

    private static func removingKnownRuntimeFunctionalAlternatives(
        in selector: String
    ) -> (source: String, detectedLegacy: Bool) {
        let patterns: [(String, String)] = [
            (
                #"(?i):where\(\s*(html:lang\([^\)]*\))\s*,\s*html\[\s*data-og-preview-locale[^\]]*\]\s*\)"#,
                ":where($1)"
            ),
            (
                #"(?i):where\(\s*html\[\s*data-og-preview-locale[^\]]*\]\s*,\s*(html:lang\([^\)]*\))\s*\)"#,
                ":where($1)"
            ),
            (
                #"(?i):where\(\s*(html:dir\([^\)]*\))\s*,\s*html\[\s*data-og-preview-dir[^\]]*\]\s*\)"#,
                ":where($1)"
            ),
            (
                #"(?i):where\(\s*html\[\s*data-og-preview-dir[^\]]*\]\s*,\s*(html:dir\([^\)]*\))\s*\)"#,
                ":where($1)"
            )
        ]
        var result = selector
        for (pattern, template) in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            result = expression.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..<result.endIndex, in: result),
                withTemplate: template
            )
        }
        return (result, result != selector)
    }

    private static func legacySelectorAttribute(
        _ raw: String
    ) -> (detectedLegacy: Bool, runtime: Bool, replacement: String?, unsupported: String?) {
        guard raw.count >= 2 else { return (false, false, nil, nil) }
        let inner = String(raw.dropFirst().dropLast())
        var cursor = skipCSSTrivia(in: inner, from: inner.startIndex, upperBound: inner.endIndex)
        let nameStart = cursor
        guard let nameToken = OpenGraphiteCSSIdentifier.consume(
            in: inner,
            from: cursor,
            upperBound: inner.endIndex
        ) else {
            if containsKnownLegacySelectorName(in: inner) {
                return (true, false, nil, "unsupported-legacy-selector-token:\(raw)")
            }
            return (false, false, nil, nil)
        }
        let name = nameToken.value.lowercased()
        guard isKnownLegacySelectorAttributeName(name) else {
            if containsKnownLegacySelectorName(in: inner) {
                return (true, false, nil, "unsupported-namespaced-legacy-selector:\(raw)")
            }
            return (false, false, nil, nil)
        }
        cursor = nameToken.end
        var remainder = String(inner[cursor...])
        if let commentExpression = try? NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#) {
            remainder = commentExpression.stringByReplacingMatches(
                in: remainder,
                range: NSRange(remainder.startIndex..<remainder.endIndex, in: remainder),
                withTemplate: " "
            )
        }
        let pattern = #"^\s*(?:(~=|\|=|=)\s*(?:\"([^\"]*)\"|'([^']*)'|([A-Za-z0-9_\\-]+)))?\s*([iIsS])?\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: remainder,
                range: NSRange(remainder.startIndex..<remainder.endIndex, in: remainder)
              )
        else { return (true, false, nil, "unsupported-legacy-selector-token:\(raw)") }
        let value = [2, 3, 4].compactMap { index -> String? in
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: remainder) else { return nil }
            let authored = String(remainder[range])
            if index == 4,
               let token = OpenGraphiteCSSIdentifier.consume(
                in: authored,
                from: authored.startIndex,
                upperBound: authored.endIndex
               ), token.end == authored.endIndex {
                return token.value
            }
            return authored
        }.first
        let modifier: String? = {
            guard match.range(at: 5).location != NSNotFound,
                  let range = Range(match.range(at: 5), in: remainder)
            else { return nil }
            return String(remainder[range]).lowercased()
        }()
        let operatorToken: String? = {
            guard match.range(at: 1).location != NSNotFound,
                  let range = Range(match.range(at: 1), in: remainder)
            else { return nil }
            return String(remainder[range])
        }()
        if modifier == "s" {
            return (true, false, nil, "unsupported-case-sensitive-legacy-selector:\(raw)")
        }
        if isRuntimeSelectorAttribute(name) { return (true, true, nil, nil) }
        switch name {
        case "data-og-type":
            guard let value else {
                return (true, false, ":is(.og-migrated-v1-type-frame,.og-migrated-v1-type-page,.og-migrated-v1-type-text,.og-migrated-v1-type-button,.og-migrated-v1-type-image,.og-migrated-v1-type-icon)", nil)
            }
            guard operatorToken == "=" else {
                return (true, false, nil, "unsupported-data-og-type-selector:\(raw)")
            }
            let normalized = value.lowercased()
            if modifier == nil, value != normalized {
                return (true, false, nil, "case-changing-data-og-type-selector:\(raw)")
            }
            guard ["frame", "page", "text", "button", "image", "icon"].contains(normalized) else {
                return (true, false, nil, "unsupported-data-og-type-selector:\(value)")
            }
            return (true, false, ".og-migrated-v1-type-\(normalized)", nil)
        case "data-og-layout":
            guard operatorToken == "=", let value, ["vertical", "horizontal", "absolute"].contains(value.lowercased()) else {
                return (true, false, nil, "unsupported-data-og-layout-selector:\(value ?? "")")
            }
            let normalized = value.lowercased()
            if modifier == nil, value != normalized {
                return (true, false, nil, "case-changing-data-og-layout-selector:\(raw)")
            }
            return (true, false, ".og-migrated-v1-layout-\(normalized)", nil)
        case "data-og-hidden":
            guard operatorToken == "=", value?.lowercased() == "true" else {
                return (true, false, nil, "unsupported-data-og-hidden-selector:\(value ?? "")")
            }
            if modifier == nil, value != value?.lowercased() {
                return (true, false, nil, "case-changing-data-og-hidden-selector:\(raw)")
            }
            return (true, false, #"[hidden]:not(:where([hidden="until-found" i]))"#, nil)
        case "data-og-icon-mask":
            guard operatorToken == "=", value?.lowercased() == "true" else {
                return (true, false, nil, "unsupported-data-og-icon-mask-selector:\(value ?? "")")
            }
            if modifier == nil, value != value?.lowercased() {
                return (true, false, nil, "case-changing-data-og-icon-mask-selector:\(raw)")
            }
            return (true, false, ".og-migrated-v1-icon-mask", nil)
        case "data-og-variant": return (true, false, replacingAttributeName(raw, inner: inner, range: nameStart..<nameToken.end, with: "variant"), nil)
        case "data-og-slot":
            return (true, false, nil, "legacy-component-slot-requires-template-structure:\(raw)")
        case "data-og-part": return (true, false, replacingAttributeName(raw, inner: inner, range: nameStart..<nameToken.end, with: "part"), nil)
        case "data-og-placement-mode":
            return (true, false, nil, "legacy-placement-mode-requires-manifest-context:\(raw)")
        case "data-og-state-hidden", "data-og-state-visible":
            return (true, false, nil, "legacy-component-state-requires-host-variant-scope:\(raw)")
        case "data-og-component-kind", "data-og-role":
            return (true, false, nil, "legacy-component-selector-requires-structure-migration:\(raw)")
        default:
            return (false, false, nil, nil)
        }
    }

    private static func replacingAttributeName(
        _ raw: String,
        inner: String,
        range: Range<String.Index>,
        with name: String
    ) -> String {
        var migratedInner = inner
        migratedInner.replaceSubrange(range, with: name)
        return "[" + migratedInner + "]"
    }

    private static func isRuntimeSelectorAttribute(_ name: String) -> Bool {
        let exact: Set<String> = [
            "data-og-selected", "data-og-editing", "data-og-dragging", "data-og-editor-artifact",
            "data-og-expanded", "data-og-generated", "data-og-component-error", "data-og-host-id",
            "data-og-instance-source", "data-og-source-id", "data-og-source-component",
            "data-og-source-instance", "data-og-source-placement", "data-og-slot-origin",
            "data-og-preview-clone", "data-og-placement-generated", "data-og-preview-locale",
            "data-og-preview-dir", "data-og-runtime-fallback-html", "data-og-overlay-label-position",
            "data-og-placement-label"
        ]
        let prefixes = ["data-og-editor-focus-", "data-og-reorder-", "data-og-frame-"]
        return exact.contains(name) || prefixes.contains { name.hasPrefix($0) }
    }

    private static func isKnownLegacySelectorAttributeName(_ name: String) -> Bool {
        switch name.lowercased() {
        case "data-og-type", "data-og-layout", "data-og-hidden", "data-og-icon-mask",
             "data-og-variant", "data-og-slot", "data-og-part", "data-og-placement-mode",
             "data-og-state-hidden", "data-og-state-visible", "data-og-component-kind",
             "data-og-role":
            return true
        default:
            return isRuntimeSelectorAttribute(name.lowercased())
        }
    }

    private static func containsKnownLegacySelectorName(in source: String) -> Bool {
        let mask = cssSearchMask(source)
        var cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard OpenGraphiteCSSIdentifier.isNameCodePoint(mask[cursor]) || mask[cursor] == "\\",
                  let token = OpenGraphiteCSSIdentifier.consume(
                    in: mask,
                    from: cursor,
                    upperBound: mask.endIndex
                  )
            else {
                cursor = mask.index(after: cursor)
                continue
            }
            if isKnownLegacySelectorAttributeName(token.value) { return true }
            cursor = token.end
        }
        return false
    }

    /// 論理名（日本語）: Migration destination observer索引関数
    /// 処理概要: selector attributeとdeclaration `attr()`をsemantic decodeし、移行後だけmatchし得るobserverを列挙します。
    private static func migrationObserverInventory(
        in source: String,
        document: OpenGraphiteCSSSourceDocument
    ) -> MigrationObserverInventory {
        var observedDestinationAttributes: Set<String> = []
        var hasGeneratedClassObserver = false
        var hasGeneratedCustomPropertyStyleObserver = false
        var unsupported: [String] = []

        for rule in document.rules {
            var cursor = rule.selectorText.startIndex
            while cursor < rule.selectorText.endIndex {
                if let skipped = skippedCSSCommentOrString(
                    in: rule.selectorText,
                    at: cursor,
                    upperBound: rule.selectorText.endIndex
                ) {
                    cursor = skipped
                    continue
                }
                guard rule.selectorText[cursor] == "[",
                      let end = cssSquareBracketEnd(in: rule.selectorText, openingAt: cursor)
                else {
                    cursor = rule.selectorText.index(after: cursor)
                    continue
                }
                let innerStart = rule.selectorText.index(after: cursor)
                let innerEnd = rule.selectorText.index(before: end)
                let inner = String(rule.selectorText[innerStart..<innerEnd])
                if let selector = OpenGraphiteCSSSelector.parsedAttributeSelector(inner) {
                    if ["class", "hidden", "variant", "part"].contains(selector.name) {
                        observedDestinationAttributes.insert(selector.name)
                    }
                    if selector.name == "class" {
                        hasGeneratedClassObserver = true
                    }
                    if selector.name == "style", let value = selector.value {
                        hasGeneratedCustomPropertyStyleObserver = true
                        if containsSemanticReservedCustomProperty(in: value, prefix: "--og-") {
                            unsupported.append("legacy-inline-style-selector-reader:\(String(rule.selectorText[cursor..<end]))")
                        }
                    }
                } else if let attributeName = namespacedAttributeSelectorName(in: inner),
                          ["class", "hidden", "variant", "part"].contains(attributeName) {
                    // Namespace付きattribute selectorはHTML sourceで通常matchしなくても、migration先属性の追加で
                    // namespace解決が変わる可能性を静的に証明できないためconservative observerとして扱います。
                    observedDestinationAttributes.insert(attributeName)
                    if attributeName == "class" { hasGeneratedClassObserver = true }
                }
                cursor = end
            }
        }

        for declaration in document.rules.flatMap(\.declarations) {
            var cursor = source.index(source.startIndex, offsetBy: declaration.valueRange.lowerBound)
            let upperBound = source.index(source.startIndex, offsetBy: declaration.valueRange.upperBound)
            while cursor < upperBound {
                if let skipped = skippedCSSCommentOrString(in: source, at: cursor, upperBound: upperBound) {
                    cursor = skipped
                    continue
                }
                guard OpenGraphiteCSSIdentifier.isNameCodePoint(source[cursor]) || source[cursor] == "\\",
                      let identifier = OpenGraphiteCSSIdentifier.consume(
                        in: source,
                        from: cursor,
                        upperBound: upperBound
                      )
                else {
                    cursor = source.index(after: cursor)
                    continue
                }
                let functionOpening = skipCSSTrivia(
                    in: source,
                    from: identifier.end,
                    upperBound: upperBound
                )
                guard functionOpening < upperBound, source[functionOpening] == "(",
                      let functionEnd = cssParenthesisEnd(
                        in: source,
                        openingAt: functionOpening,
                        upperBound: upperBound
                      )
                else {
                    cursor = identifier.end
                    continue
                }
                if identifier.value.caseInsensitiveCompare("url") == .orderedSame {
                    cursor = functionEnd
                    continue
                }
                if identifier.value.caseInsensitiveCompare("attr") == .orderedSame {
                    let argumentEnd = source.index(before: functionEnd)
                    let argumentStart = skipCSSTrivia(
                        in: source,
                        from: source.index(after: functionOpening),
                        upperBound: argumentEnd
                    )
                    if let attribute = OpenGraphiteCSSIdentifier.consume(
                        in: source,
                        from: argumentStart,
                        upperBound: argumentEnd
                    ) {
                        let attributeName = attribute.value.lowercased()
                        if isKnownLegacySelectorAttributeName(attributeName) {
                            unsupported.append("legacy-attribute-function-reader:\(attribute.value)")
                        }
                        if ["class", "hidden", "variant", "part"].contains(attributeName) {
                            observedDestinationAttributes.insert(attributeName)
                        }
                        if attributeName == "class" {
                            hasGeneratedClassObserver = true
                        }
                        if attributeName == "style" {
                            hasGeneratedCustomPropertyStyleObserver = true
                        }
                    }
                }
                cursor = identifier.end
            }
        }
        return MigrationObserverInventory(
            observedDestinationAttributes: observedDestinationAttributes,
            hasGeneratedClassObserver: hasGeneratedClassObserver,
            hasGeneratedCustomPropertyStyleObserver: hasGeneratedCustomPropertyStyleObserver,
            unsupported: Array(Set(unsupported)).sorted()
        )
    }

    /// Namespace prefix付きattribute selectorからsemantic local nameを返します。
    private static func namespacedAttributeSelectorName(in source: String) -> String? {
        let mask = cssSearchMask(source)
        var cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard mask[cursor] == "|" else {
                cursor = mask.index(after: cursor)
                continue
            }
            cursor = mask.index(after: cursor)
            if cursor < mask.endIndex, mask[cursor] == "=" { continue }
            cursor = skipCSSTrivia(in: mask, from: cursor, upperBound: mask.endIndex)
            guard cursor < mask.endIndex,
                  let name = OpenGraphiteCSSIdentifier.consume(
                      in: mask,
                      from: cursor,
                      upperBound: mask.endIndex
                  )?.value.lowercased()
            else { continue }
            return name
        }
        return nil
    }

    /// 論理名（日本語）: Reserved custom property semantic検出関数
    /// 処理概要: CSS escapeを復号し、selector value内のreserved custom property identifierだけを検出します。
    private static func containsSemanticReservedCustomProperty(in source: String, prefix: String) -> Bool {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            guard OpenGraphiteCSSIdentifier.isNameCodePoint(source[cursor]) || source[cursor] == "\\",
                  let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: source,
                    from: cursor,
                    upperBound: source.endIndex
                  )
            else {
                cursor = source.index(after: cursor)
                continue
            }
            if prefix == "--og-", isLegacyReservedCustomPropertyName(identifier.value) { return true }
            cursor = identifier.end
        }
        return false
    }

    private static func unsupportedLegacyAtRules(
        in source: String,
        document: OpenGraphiteCSSSourceDocument
    ) -> [String] {
        let mask = cssSearchMask(source)
        var reasons: [String] = []
        if mask.range(of: #"(?i)@property\s+--og-[A-Za-z0-9_-]+"#, options: .regularExpression) != nil {
            reasons.append("legacy-property-registration")
        }
        if mask.range(of: #"(?i)@supports[^\{;]*--og-[A-Za-z0-9_-]+"#, options: .regularExpression) != nil {
            reasons.append("legacy-supports-condition")
        }
        for context in document.rules.flatMap(\.atRules) where context.name.lowercased() == "supports" {
            if cssSearchMask(context.prelude).range(of: #"--og-[A-Za-z0-9_-]+"#, options: .regularExpression) != nil {
                reasons.append("legacy-supports-condition")
            }
        }
        return Array(Set(reasons)).sorted()
    }

    private static func remainingLegacyConstructs(in source: String) -> [String] {
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        var reasons: [String] = unsupportedLegacyAtRules(in: source, document: document)
        for declaration in document.rules.flatMap(\.declarations) {
            if isLegacyReservedCustomPropertyName(declaration.name) {
                reasons.append("remaining-custom-property:\(declaration.name)")
            }
            for function in variableFunctions(in: declaration.valueRange, source: source)
            where isLegacyReservedCustomPropertyName(function.name) {
                reasons.append("remaining-var-reference:\(function.name)")
            }
        }
        for rule in document.rules {
            for branch in splitSelectorBranches(rule.selectorText) {
                let inspection = migrateSelectorBranch(branch)
                if inspection.detectedLegacy {
                    reasons.append("remaining-legacy-selector:\(branch.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }
        let mask = cssSearchMask(source)
        var cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard OpenGraphiteCSSIdentifier.isNameCodePoint(mask[cursor]) || mask[cursor] == "\\",
                  let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: mask,
                    from: cursor,
                    upperBound: mask.endIndex
                  )
            else {
                cursor = mask.index(after: cursor)
                continue
            }
            if isLegacyReservedCustomPropertyName(identifier.value) {
                reasons.append("remaining-reserved-token:\(identifier.value)")
            }
            cursor = identifier.end
        }
        cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard mask[cursor] == "[" else {
                cursor = mask.index(after: cursor)
                continue
            }
            guard let end = cssSquareBracketEnd(in: mask, openingAt: cursor) else {
                let tail = String(mask[cursor...])
                if tail.lowercased().contains("data-og-") {
                    reasons.append("remaining-malformed-legacy-selector:\(tail)")
                }
                break
            }
            let raw = String(mask[cursor..<end])
            if legacySelectorAttribute(raw).detectedLegacy {
                reasons.append("remaining-legacy-selector-token:\(raw)")
            }
            cursor = end
        }
        return Array(Set(reasons)).sorted()
    }

    private static func cssSearchMask(_ source: String) -> String {
        var result = source
        var ranges: [Range<Int>] = []
        var cursor = source.startIndex
        while cursor < source.endIndex {
            if let skipped = skippedCSSCommentOrString(in: source, at: cursor, upperBound: source.endIndex) {
                ranges.append(offsetRange(cursor..<skipped, in: source))
                cursor = skipped
                continue
            }
            if (OpenGraphiteCSSIdentifier.isNameCodePoint(source[cursor]) || source[cursor] == "\\"),
               let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: cursor,
                upperBound: source.endIndex
               ),
               identifier.value.caseInsensitiveCompare("url") == .orderedSame,
               identifier.end < source.endIndex,
               source[identifier.end] == "(",
               let end = cssParenthesisEnd(in: source, openingAt: identifier.end, upperBound: source.endIndex) {
                ranges.append(offsetRange(cursor..<end, in: source))
                cursor = end
                continue
            }
            cursor = source.index(after: cursor)
        }
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            let lower = result.index(result.startIndex, offsetBy: range.lowerBound)
            let upper = result.index(result.startIndex, offsetBy: range.upperBound)
            result.replaceSubrange(lower..<upper, with: String(repeating: " ", count: range.count))
        }
        return result
    }

    private static func generatedMigrationClassNames(in source: String) -> [String] {
        let mask = cssSearchMask(source)
        var names: Set<String> = []
        var cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard mask[cursor] == "." else {
                cursor = mask.index(after: cursor)
                continue
            }
            let identifierStart = mask.index(after: cursor)
            guard identifierStart < mask.endIndex,
                  let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: mask,
                    from: identifierStart,
                    upperBound: mask.endIndex
                  )
            else {
                cursor = identifierStart
                continue
            }
            if identifier.value.hasPrefix("og-migrated-v1-") {
                names.insert(identifier.value)
            }
            cursor = identifier.end
        }
        return names.sorted()
    }

    private static func migrationCustomPropertyNames(in source: String) -> [String] {
        let mask = cssSearchMask(source)
        var names: Set<String> = []
        var cursor = mask.startIndex
        while cursor < mask.endIndex {
            guard OpenGraphiteCSSIdentifier.isNameCodePoint(mask[cursor]) || mask[cursor] == "\\",
                  let token = OpenGraphiteCSSIdentifier.consume(
                    in: mask,
                    from: cursor,
                    upperBound: mask.endIndex
                  )
            else {
                cursor = mask.index(after: cursor)
                continue
            }
            if token.value.hasPrefix("--migrated-v1-") { names.insert(token.value) }
            cursor = token.end
        }
        return names.sorted()
    }

    private static func applying(_ patches: [Patch], to source: String) -> String {
        var result = source
        for patch in patches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            let lower = result.index(result.startIndex, offsetBy: patch.range.lowerBound)
            let upper = result.index(result.startIndex, offsetBy: patch.range.upperBound)
            result.replaceSubrange(lower..<upper, with: patch.value)
        }
        return result
    }

    private static func substring(_ range: Range<Int>, in source: String) -> String {
        let lower = source.index(source.startIndex, offsetBy: range.lowerBound)
        let upper = source.index(source.startIndex, offsetBy: range.upperBound)
        return String(source[lower..<upper])
    }

    private static func offsetRange(_ range: Range<String.Index>, in source: String) -> Range<Int> {
        source.distance(from: source.startIndex, to: range.lowerBound)..<source.distance(from: source.startIndex, to: range.upperBound)
    }

    private static func skipCSSTrivia(
        in source: String,
        from start: String.Index,
        upperBound: String.Index
    ) -> String.Index {
        var cursor = start
        while cursor < upperBound {
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            let next = source.index(after: cursor)
            if source[cursor] == "/", next < upperBound, source[next] == "*",
               let close = source[next...].range(of: "*/")?.upperBound, close <= upperBound {
                cursor = close
                continue
            }
            break
        }
        return cursor
    }

    private static func skippedCSSCommentOrString(
        in source: String,
        at start: String.Index,
        upperBound: String.Index
    ) -> String.Index? {
        let character = source[start]
        let next = source.index(after: start)
        if character == "/", next < upperBound, source[next] == "*" {
            return source[next..<upperBound].range(of: "*/")?.upperBound ?? upperBound
        }
        guard character == "\"" || character == "'" else { return nil }
        var cursor = next
        while cursor < upperBound {
            if source[cursor] == "\\" {
                cursor = source.index(after: cursor)
                if cursor < upperBound { cursor = source.index(after: cursor) }
                continue
            }
            let current = source[cursor]
            cursor = source.index(after: cursor)
            if current == character { return cursor }
        }
        return upperBound
    }

    private static func cssParenthesisEnd(
        in source: String,
        openingAt opening: String.Index,
        upperBound: String.Index
    ) -> String.Index? {
        var cursor = source.index(after: opening)
        var depth = 1
        while cursor < upperBound {
            if let skipped = skippedCSSCommentOrString(in: source, at: cursor, upperBound: upperBound) {
                cursor = skipped
                continue
            }
            if source[cursor] == "(" { depth += 1 }
            else if source[cursor] == ")" {
                depth -= 1
                cursor = source.index(after: cursor)
                if depth == 0 { return cursor }
                continue
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    private static func cssSquareBracketEnd(
        in source: String,
        openingAt opening: String.Index
    ) -> String.Index? {
        var cursor = source.index(after: opening)
        while cursor < source.endIndex {
            if let skipped = skippedCSSCommentOrString(in: source, at: cursor, upperBound: source.endIndex) {
                cursor = skipped
                continue
            }
            if source[cursor] == "]" { return source.index(after: cursor) }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    private static func isSafeGeneratedClassSuffix(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0)
        }
    }

}

/// 論理名（日本語）: CSS詳細度
/// 概要: selector の ID、class/属性/疑似class、type の重みを比較可能な値として保持します。
///
/// プロパティ:
/// - `ids`: ID selector の個数。
/// - `classes`: class、属性、疑似class selector の個数。
/// - `types`: type、疑似element selector の個数。
struct OpenGraphiteCSSSpecificity: Equatable, Comparable, Codable {
    var ids: Int
    var classes: Int
    var types: Int

    static let zero = OpenGraphiteCSSSpecificity(ids: 0, classes: 0, types: 0)

    /// 論理名（日本語）: CSS詳細度比較関数
    /// 処理概要: CSS cascade と同じく ID、class、type の順に辞書順で比較します。
    ///
    /// - Parameters:
    ///   - lhs: 左辺の詳細度。
    ///   - rhs: 右辺の詳細度。
    /// - Returns: 左辺が右辺より低い場合は `true`。
    static func < (lhs: OpenGraphiteCSSSpecificity, rhs: OpenGraphiteCSSSpecificity) -> Bool {
        if lhs.ids != rhs.ids { return lhs.ids < rhs.ids }
        if lhs.classes != rhs.classes { return lhs.classes < rhs.classes }
        return lhs.types < rhs.types
    }

    /// 論理名（日本語）: CSS詳細度加算関数
    /// 処理概要: selector segment ごとの詳細度を合成します。
    ///
    /// - Parameters:
    ///   - lhs: 左辺の詳細度。
    ///   - rhs: 右辺の詳細度。
    /// - Returns: 各重みを加算した詳細度。
    static func + (lhs: OpenGraphiteCSSSpecificity, rhs: OpenGraphiteCSSSpecificity) -> OpenGraphiteCSSSpecificity {
        OpenGraphiteCSSSpecificity(
            ids: lhs.ids + rhs.ids,
            classes: lhs.classes + rhs.classes,
            types: lhs.types + rhs.types
        )
    }
}

/// 論理名（日本語）: CSS照合用DOM要素
/// 概要: source selector を headless に照合するため、標準 DOM の必要最小限の情報を保持します。
///
/// プロパティ:
/// - `tagName`: lowercased tag name。
/// - `attributes`: lowercased attribute name と値。
/// - `ancestors`: 直近の親を先頭にした ancestor 一覧。
/// - `pseudoClasses`: preview/runtime が明示した一時疑似状態。
/// - `isRoot`: document root element かどうか。
/// - `typeIndex`: 同じ親を持つ同tag sibling中の1始まり位置。
/// - `typeCount`: 同じ親を持つ同tag sibling総数。
/// - `childIndex`: 同じ親を持つ全element sibling中の1始まり位置。
/// - `childCount`: 同じ親を持つ全element sibling総数。
/// - `previousSiblings`: 直前のelementを先頭にしたpreceding sibling一覧。
struct OpenGraphiteCSSDOMElement: Equatable {
    var tagName: String
    var attributes: [String: String]
    var ancestors: [OpenGraphiteCSSDOMElement]
    var pseudoClasses: Set<String>
    var isRoot: Bool
    var typeIndex: Int
    var typeCount: Int
    var childIndex: Int
    var childCount: Int
    var previousSiblings: [OpenGraphiteCSSDOMElement]

    /// 論理名（日本語）: CSS照合用DOM要素初期化関数
    /// 処理概要: selector 照合に必要な標準 DOM 情報を正規化して保持します。
    ///
    /// - Parameters:
    ///   - tagName: element の tag name。
    ///   - attributes: element の attribute 辞書。
    ///   - ancestors: 直近の親を先頭にした ancestor 一覧。
    ///   - pseudoClasses: 一時的に active とみなす疑似class名。
    ///   - isRoot: document root の場合は `true`。
    ///   - typeIndex: `:nth-of-type()` 照合用の1始まり sibling位置。
    ///   - typeCount: `:last-of-type`照合用の同tag sibling総数。
    ///   - childIndex: `:nth-child()`照合用の1始まり sibling位置。
    ///   - childCount: `:last-child`照合用のelement sibling総数。
    ///   - previousSiblings: sibling combinator照合用のpreceding element一覧。
    init(
        tagName: String,
        attributes: [String: String] = [:],
        ancestors: [OpenGraphiteCSSDOMElement] = [],
        pseudoClasses: Set<String> = [],
        isRoot: Bool = false,
        typeIndex: Int = 1,
        typeCount: Int = 1,
        childIndex: Int = 1,
        childCount: Int = 1,
        previousSiblings: [OpenGraphiteCSSDOMElement] = []
    ) {
        self.tagName = tagName.lowercased()
        self.attributes = Dictionary(uniqueKeysWithValues: attributes.map { ($0.key.lowercased(), $0.value) })
        self.ancestors = ancestors
        self.pseudoClasses = Set(pseudoClasses.map { $0.lowercased() })
        self.isRoot = isRoot
        self.typeIndex = max(typeIndex, 1)
        self.typeCount = max(typeCount, 1)
        self.childIndex = max(childIndex, 1)
        self.childCount = max(childCount, 1)
        self.previousSiblings = previousSiblings
    }

    var id: String { attributes["id"] ?? "" }
    var classNames: Set<String> {
        Set((attributes["class"] ?? "").split(whereSeparator: isHTMLASCIIWhitespace).map(String.init))
    }
    var language: String {
        if let lang = attributes["lang"], !lang.isEmpty {
            return lang.replacingOccurrences(of: "_", with: "-").lowercased()
        }
        return ancestors.lazy.compactMap { $0.attributes["lang"] }.first?
            .replacingOccurrences(of: "_", with: "-")
            .lowercased() ?? ""
    }
}

/// 論理名（日本語）: CSS DOM authored node
/// 概要: source HTMLに実在するelementと、そのsource tree上の親indexをbrowser CSS評価木へ渡します。
///
/// プロパティ:
/// - `element`: authored elementのselector照合情報。
/// - `parentIndex`: authored node配列内の親index。sourceに親tagがなければ`nil`。
struct OpenGraphiteCSSDOMSourceNode: Equatable {
    var element: OpenGraphiteCSSDOMElement
    var parentIndex: Int?
}

/// 論理名（日本語）: CSS DOM projected node
/// 概要: browserがHTML tree constructionで補うcontainerを含む、cascade評価専用elementを表します。
///
/// プロパティ:
/// - `element`: browser-equivalentなancestorとtype indexを持つselector照合情報。
/// - `parentIndex`: projection内の親index。
/// - `sourceIndex`: source HTMLに実在するnodeのindex。implicit elementでは`nil`。
struct OpenGraphiteCSSDOMProjectedNode: Equatable {
    var element: OpenGraphiteCSSDOMElement
    var parentIndex: Int?
    var sourceIndex: Int?
}

/// 論理名（日本語）: Browser CSS DOM projection
/// 概要: authored graphを変更せず、HTML parserが補う`html` / `head` / `body`とtable containerだけをCSS評価木へ投影します。
///
/// プロパティ:
/// - `nodes`: ancestorより後にdescendantが並ぶbrowser-equivalent評価node。
/// - `projectedIndexBySourceIndex`: authored node indexから評価node indexへの対応。
struct OpenGraphiteCSSDOMProjection: Equatable {
    var nodes: [OpenGraphiteCSSDOMProjectedNode]
    var projectedIndexBySourceIndex: [Int: Int]

    /// 論理名（日本語）: Browser document CSS DOM投影関数
    /// 処理概要: sourceにないdocument sectionとtable containerを評価時だけ補い、標準selectorとinheritanceのbrowser treeを構築します。
    ///
    /// - Parameter sourceNodes: DOM順のauthored elementとsource parent index。
    /// - Returns: source node対応を保持したbrowser-equivalent CSS評価木。
    static func browserDocument(from sourceNodes: [OpenGraphiteCSSDOMSourceNode]) -> OpenGraphiteCSSDOMProjection {
        let rootSourceIndex = sourceNodes.indices.first {
            sourceNodes[$0].element.tagName == "html" && sourceNodes[$0].parentIndex == nil
        }
        let headSourceIndex = sourceNodes.indices.first { index in
            guard sourceNodes[index].element.tagName == "head" else { return false }
            return sourceNodes[index].parentIndex == nil || sourceNodes[index].parentIndex == rootSourceIndex
        }
        let bodySourceIndex = sourceNodes.indices.first { index in
            guard sourceNodes[index].element.tagName == "body" else { return false }
            return sourceNodes[index].parentIndex == nil || sourceNodes[index].parentIndex == rootSourceIndex
        }

        var projectedNodes: [OpenGraphiteCSSDOMProjectedNode] = []
        var projectedIndexBySourceIndex: [Int: Int] = [:]
        var siblingTypePositions: [String: Int] = [:]

        /// browser treeへ1 nodeを追加し、parentからancestor chainと`:nth-of-type()`位置を確定します。
        func appendNode(
            tagName: String,
            attributes: [String: String] = [:],
            pseudoClasses: Set<String> = [],
            isRoot: Bool = false,
            parentIndex: Int?,
            sourceIndex: Int?
        ) -> Int {
            let normalizedTagName = tagName.lowercased()
            let siblingKey = "\(parentIndex ?? -1)|\(normalizedTagName)"
            let typeIndex = (siblingTypePositions[siblingKey] ?? 0) + 1
            siblingTypePositions[siblingKey] = typeIndex
            let ancestors: [OpenGraphiteCSSDOMElement]
            if let parentIndex {
                let parent = projectedNodes[parentIndex].element
                ancestors = [parent] + parent.ancestors
            } else {
                ancestors = []
            }
            let projectedIndex = projectedNodes.count
            projectedNodes.append(
                OpenGraphiteCSSDOMProjectedNode(
                    element: OpenGraphiteCSSDOMElement(
                        tagName: normalizedTagName,
                        attributes: attributes,
                        ancestors: ancestors,
                        pseudoClasses: pseudoClasses,
                        isRoot: isRoot,
                        typeIndex: typeIndex
                    ),
                    parentIndex: parentIndex,
                    sourceIndex: sourceIndex
                )
            )
            if let sourceIndex {
                projectedIndexBySourceIndex[sourceIndex] = projectedIndex
            }
            return projectedIndex
        }

        /// explicit document sectionのauthored属性を使い、欠落時は空のimplicit elementを返します。
        func sourceElement(at index: Int?, fallbackTagName: String) -> OpenGraphiteCSSDOMElement {
            index.map { sourceNodes[$0].element }
                ?? OpenGraphiteCSSDOMElement(tagName: fallbackTagName)
        }

        let rootSourceElement = sourceElement(at: rootSourceIndex, fallbackTagName: "html")
        let rootIndex = appendNode(
            tagName: "html",
            attributes: rootSourceElement.attributes,
            pseudoClasses: rootSourceElement.pseudoClasses,
            isRoot: true,
            parentIndex: nil,
            sourceIndex: rootSourceIndex
        )
        let headSourceElement = sourceElement(at: headSourceIndex, fallbackTagName: "head")
        let headIndex = appendNode(
            tagName: "head",
            attributes: headSourceElement.attributes,
            pseudoClasses: headSourceElement.pseudoClasses,
            parentIndex: rootIndex,
            sourceIndex: headSourceIndex
        )
        let bodySourceElement = sourceElement(at: bodySourceIndex, fallbackTagName: "body")
        let bodyIndex = appendNode(
            tagName: "body",
            attributes: bodySourceElement.attributes,
            pseudoClasses: bodySourceElement.pseudoClasses,
            parentIndex: rootIndex,
            sourceIndex: bodySourceIndex
        )

        var bodyInsertionModeStarted = false
        var activeImplicitTableContainer: [Int: (tagName: String, projectedIndex: Int)] = [:]

        for sourceIndex in sourceNodes.indices {
            if sourceIndex == rootSourceIndex || sourceIndex == headSourceIndex {
                continue
            }
            if sourceIndex == bodySourceIndex {
                bodyInsertionModeStarted = true
                continue
            }

            let sourceNode = sourceNodes[sourceIndex]
            let isDocumentChild = sourceNode.parentIndex == nil || sourceNode.parentIndex == rootSourceIndex
            let authoredParentIndex: Int
            if isDocumentChild {
                if !bodyInsertionModeStarted && Self.headContentElementNames.contains(sourceNode.element.tagName) {
                    authoredParentIndex = headIndex
                } else {
                    authoredParentIndex = bodyIndex
                    bodyInsertionModeStarted = true
                }
            } else if let sourceParentIndex = sourceNode.parentIndex,
                      let projectedParentIndex = projectedIndexBySourceIndex[sourceParentIndex] {
                authoredParentIndex = projectedParentIndex
            } else {
                // Valid document input is ancestor-first. A missing mapping can only arise from malformed source;
                // keep inspection deterministic by placing it in the implicit body without changing authored graph.
                authoredParentIndex = bodyIndex
                bodyInsertionModeStarted = true
            }

            var projectedParentIndex = authoredParentIndex
            if projectedNodes[authoredParentIndex].element.tagName == "table" {
                let implicitContainerTagName: String?
                switch sourceNode.element.tagName {
                case "tr": implicitContainerTagName = "tbody"
                case "col": implicitContainerTagName = "colgroup"
                default: implicitContainerTagName = nil
                }
                if let implicitContainerTagName {
                    if let active = activeImplicitTableContainer[authoredParentIndex],
                       active.tagName == implicitContainerTagName {
                        projectedParentIndex = active.projectedIndex
                    } else {
                        let containerIndex = appendNode(
                            tagName: implicitContainerTagName,
                            parentIndex: authoredParentIndex,
                            sourceIndex: nil
                        )
                        activeImplicitTableContainer[authoredParentIndex] = (
                            tagName: implicitContainerTagName,
                            projectedIndex: containerIndex
                        )
                        projectedParentIndex = containerIndex
                    }
                } else {
                    activeImplicitTableContainer[authoredParentIndex] = nil
                }
            }

            _ = appendNode(
                tagName: sourceNode.element.tagName,
                attributes: sourceNode.element.attributes,
                pseudoClasses: sourceNode.element.pseudoClasses,
                parentIndex: projectedParentIndex,
                sourceIndex: sourceIndex
            )
        }

        let siblingIndicesByParent = Dictionary(grouping: projectedNodes.indices) {
            projectedNodes[$0].parentIndex
        }
        for projectedIndex in projectedNodes.indices {
            let parentIndex = projectedNodes[projectedIndex].parentIndex
            let siblings = siblingIndicesByParent[parentIndex] ?? [projectedIndex]
            let childPosition = siblings.firstIndex(of: projectedIndex) ?? 0
            let sameTypeSiblings = siblings.filter {
                projectedNodes[$0].element.tagName == projectedNodes[projectedIndex].element.tagName
            }
            let typePosition = sameTypeSiblings.firstIndex(of: projectedIndex) ?? 0
            var element = projectedNodes[projectedIndex].element
            if let parentIndex {
                let parent = projectedNodes[parentIndex].element
                element.ancestors = [parent] + parent.ancestors
            } else {
                element.ancestors = []
            }
            element.childIndex = childPosition + 1
            element.childCount = siblings.count
            element.typeIndex = typePosition + 1
            element.typeCount = sameTypeSiblings.count
            element.previousSiblings = siblings[..<childPosition].reversed().map {
                projectedNodes[$0].element
            }
            projectedNodes[projectedIndex].element = element
        }

        return OpenGraphiteCSSDOMProjection(
            nodes: projectedNodes,
            projectedIndexBySourceIndex: projectedIndexBySourceIndex
        )
    }

    /// 論理名（日本語）: Authored node投影element取得関数
    /// 処理概要: source indexに対応するbrowser-equivalent selector照合elementを返します。
    ///
    /// - Parameter sourceIndex: authored node配列内のindex。
    /// - Returns: 対応する評価element。mappingがなければ`nil`。
    func element(forSourceIndex sourceIndex: Int) -> OpenGraphiteCSSDOMElement? {
        projectedIndexBySourceIndex[sourceIndex].map { nodes[$0].element }
    }

    /// document body開始前にheadへ挿入されるmetadata / script-supporting element名です。
    private static let headContentElementNames: Set<String> = [
        "base", "basefont", "bgsound", "link", "meta", "noframes", "noscript",
        "script", "style", "template", "title"
    ]
}

/// 論理名（日本語）: CSS at-rule文脈
/// 概要: declaration が属する `@media` 等の条件と source prelude を保持します。
///
/// プロパティ:
/// - `name`: lowercased at-rule 名。
/// - `prelude`: `@media` 等の名前を除いた authored condition。
struct OpenGraphiteCSSAtRuleContext: Equatable, Codable {
    var name: String
    var prelude: String
}

/// 論理名（日本語）: 独立CSS stylesheet source
/// 概要: browserのstylesheet境界を壊さず、source ID・種別・編集可否・外側conditionをcascadeへ渡します。
///
/// プロパティ:
/// - `sourceID`: file URLまたはHTML内styleを識別するstable ID。
/// - `sourceKind`: `project`、`companion`、`linked`、`embedded`等のorigin種別。
/// - `source`: stylesheetごとにlossless保持するauthored CSS。
/// - `editable`: 共通mutationが元sourceへ安全に書き戻せるか。
/// - `atRules`: link media等、stylesheet全体へ適用する外側condition。
struct OpenGraphiteCSSStylesheetSource: Equatable {
    var sourceID: String
    var sourceKind: String
    var source: String
    var editable: Bool
    var atRules: [OpenGraphiteCSSAtRuleContext] = []
}

/// 論理名（日本語）: 解析済み独立CSS stylesheet source
/// 概要: stylesheet origin metadataとlossless parse結果を対にし、同一DOM graph内のcascade評価で再利用します。
///
/// プロパティ:
/// - `stylesheet`: source ID、origin種別、編集可否、外側conditionを持つ独立stylesheet。
/// - `document`: stylesheetを一度だけlossless parseしたCSS source文書。
/// - `containsDynamicKeyframes`: stylesheetに標準またはWebKit keyframesが存在するか。
struct OpenGraphiteCSSParsedStylesheetSource: Equatable {
    var stylesheet: OpenGraphiteCSSStylesheetSource
    var document: OpenGraphiteCSSSourceDocument
    var containsDynamicKeyframes: Bool
}

/// 論理名（日本語）: CSS provenance完全性検査結果
/// 概要: headless cascadeがwinnerを断定できないsource構文を、sourceを変更せず理由一覧として返します。
///
/// プロパティ:
/// - `reasons`: malformed source、未対応conditional/layer、未対応selectorの決定的な理由一覧。
struct OpenGraphiteCSSProvenanceInspection: Equatable {
    var reasons: [String]

    var isComplete: Bool { reasons.isEmpty }
}

/// 論理名（日本語）: CSS source宣言
/// 概要: authored declaration の値、`!important`、lossless 書き戻し範囲を保持します。
///
/// プロパティ:
/// - `name`: CSS property 名。
/// - `value`: `!important` を除く authored value。
/// - `important`: `!important` の有無。
/// - `range`: property 名から semicolon までの文字offset範囲。
/// - `valueRange`: 値だけの文字offset範囲。
/// - `sourceOrder`: document 内の declaration 順。
struct OpenGraphiteCSSSourceDeclaration: Equatable {
    var name: String
    var value: String
    var important: Bool
    var range: Range<Int>
    var valueRange: Range<Int>
    var sourceOrder: Int
}

/// 論理名（日本語）: CSS source rule
/// 概要: selector list、declaration、at-rule scope と lossless source 範囲を保持します。
///
/// プロパティ:
/// - `selectorText`: authored selector list。
/// - `selectors`: top-level comma で分割した selector。
/// - `declarations`: rule body 内の declaration。
/// - `atRules`: 外側から内側の at-rule scope。
/// - `range`: rule 全体の文字offset範囲。
/// - `bodyRange`: brace 内側の文字offset範囲。
/// - `sourceOrder`: style rule の document 順。
struct OpenGraphiteCSSSourceRule: Equatable {
    var selectorText: String
    var selectors: [String]
    var declarations: [OpenGraphiteCSSSourceDeclaration]
    var atRules: [OpenGraphiteCSSAtRuleContext]
    var range: Range<Int>
    var bodyRange: Range<Int>
    var sourceOrder: Int
}

/// 論理名（日本語）: CSS宣言provenance
/// 概要: cascade 候補がどの selector、scope、source declaration から来たかを表します。
///
/// プロパティ:
/// - `property`: longhand 展開後の対象 property。
/// - `authoredProperty`: source に記載された property。
/// - `selector`: 一致した selector。
/// - `specificity`: selector の詳細度。
/// - `atRules`: declaration の条件scope。
/// - `declaration`: lossless source declaration。
struct OpenGraphiteCSSDeclarationProvenance: Equatable {
    var property: String
    var authoredProperty: String
    var selector: String
    var specificity: OpenGraphiteCSSSpecificity
    var atRules: [OpenGraphiteCSSAtRuleContext]
    var declaration: OpenGraphiteCSSSourceDeclaration
    var sourceID: String = ""
    var sourceKind: String = "unknown"
    var sourceEditable: Bool = false
    var stylesheetOrder: Int = 0
    var inherited: Bool = false
}

/// 論理名（日本語）: CSS cascade trace
/// 概要: authored candidate、winner、inheritance、custom property 解決後の値を分離して返します。
///
/// プロパティ:
/// - `candidates`: property ごとの cascade 候補。
/// - `winners`: property ごとの勝者 provenance。
/// - `authoredValues`: 勝者の authored value。
/// - `resolvedValues`: inheritance と `var()` 解決後の値。
/// - `incompleteProperties`: animation や未確定initial値など、headless computed値を断定しないproperty。
struct OpenGraphiteCSSCascadeTrace: Equatable {
    var candidates: [String: [OpenGraphiteCSSDeclarationProvenance]]
    var winners: [String: OpenGraphiteCSSDeclarationProvenance]
    var authoredValues: [String: String]
    var resolvedValues: [String: String]
    var incompleteProperties: Set<String> = []
}

/// 論理名（日本語）: CSS cascade評価環境
/// 概要: headless source trace で active とみなす media 条件を明示します。
///
/// プロパティ:
/// - `activeMediaQueries`: `@media` prelude の完全一致集合。
/// - `includeUnknownConditionalRules`: `@supports` 等を active とみなすかどうか。
struct OpenGraphiteCSSCascadeEnvironment: Equatable {
    var activeMediaQueries: Set<String>
    var includeUnknownConditionalRules: Bool

    static let base = OpenGraphiteCSSCascadeEnvironment(
        activeMediaQueries: [],
        includeUnknownConditionalRules: false
    )

    /// 論理名（日本語）: Headless CSS inspection環境生成関数
    /// 処理概要: authored media conditionを`CSSMediaRule.conditionText`相当のtoken表現で集合化し、未知conditional ruleはactiveにしません。
    ///
    /// - Parameter activeMediaQueries: 呼び出し側が実描画環境でactiveと確認した`@media`条件。
    /// - Returns: source cascade用の決定的なinspection環境。
    static func inspection(activeMediaQueries: [String]) -> OpenGraphiteCSSCascadeEnvironment {
        OpenGraphiteCSSCascadeEnvironment(
            activeMediaQueries: Set(normalizedActiveMediaQueries(activeMediaQueries)),
            includeUnknownConditionalRules: false
        )
    }

    /// 論理名（日本語）: Active media条件正規化関数
    /// 処理概要: authored条件とCSSOM条件のidentifier、colon、range operator、comma、空白を同じsemantic keyへ揃え、空条件と重複を除きます。
    ///
    /// - Parameter values: `CSSMediaRule.conditionText`または同じauthored条件文字列。
    /// - Returns: headless graphとCLI / MCPで共有する正規化済み条件。
    static func normalizedActiveMediaQueries(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let normalized = normalizedMediaCondition(value)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    /// 論理名（日本語）: Media条件semantic key生成関数
    /// 処理概要: source preludeとCSSOM `conditionText`を、raw sourceを変更せず同一の比較用token列へcanonicalizeします。
    ///
    /// - Parameter value: Authored media preludeまたはCSSOM `conditionText`。
    /// - Returns: Active media照合とJSON echoに使う決定的なsemantic key。
    static func normalizedMediaCondition(_ value: String) -> String {
        let tokens = mediaConditionTokens(in: value)
        var result = ""
        var previous: MediaConditionToken?

        func trimTrailingWhitespace() {
            while result.last.map(OpenGraphiteCSSIdentifier.isCSSWhitespace) == true { result.removeLast() }
        }
        func ensureSpace() {
            guard !result.isEmpty,
                  result.last.map(OpenGraphiteCSSIdentifier.isCSSWhitespace) != true
            else { return }
            result.append(" ")
        }

        for token in tokens {
            switch token {
            case .atom(let value), .quoted(let value):
                if let previous, previous.needsSeparatorBeforeAtom {
                    ensureSpace()
                }
                result.append(contentsOf: value)
            case .openParenthesis:
                if case .atom(let value) = previous,
                   ["and", "not", "only", "or"].contains(value) {
                    ensureSpace()
                } else if let previous, previous.needsSeparatorBeforeOpenParenthesis {
                    ensureSpace()
                }
                result.append("(")
            case .closeParenthesis:
                trimTrailingWhitespace()
                result.append(")")
            case .colon:
                trimTrailingWhitespace()
                result.append(": ")
            case .comma:
                trimTrailingWhitespace()
                result.append(", ")
            case .spacedOperator(let value):
                trimTrailingWhitespace()
                if !result.isEmpty { result.append(" ") }
                result.append(contentsOf: value)
                result.append(" ")
            case .delimiter(let value):
                trimTrailingWhitespace()
                result.append(contentsOf: value)
            }
            previous = token
        }
        trimTrailingWhitespace()
        return result
    }

    /// Media conditionのsemantic serializerが扱うtokenです。
    private enum MediaConditionToken {
        case atom(String)
        case quoted(String)
        case openParenthesis
        case closeParenthesis
        case colon
        case comma
        case spacedOperator(String)
        case delimiter(String)

        var needsSeparatorBeforeAtom: Bool {
            switch self {
            case .atom, .quoted, .closeParenthesis:
                return true
            default:
                return false
            }
        }

        var needsSeparatorBeforeOpenParenthesis: Bool {
            switch self {
            case .quoted, .closeParenthesis:
                return true
            default:
                return false
            }
        }
    }

    /// Raw media conditionをcomment / quote / CSS escape awareにsemantic tokenへ分解します。
    private static func mediaConditionTokens(in source: String) -> [MediaConditionToken] {
        var tokens: [MediaConditionToken] = []
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                cursor = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "*",
               let close = source[next...].range(of: "*/")?.upperBound {
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                let start = cursor
                let quote = character
                cursor = next
                while cursor < source.endIndex {
                    if source[cursor] == "\\",
                       let escape = OpenGraphiteCSSIdentifier.consumeEscape(
                        in: source,
                        at: cursor,
                        upperBound: source.endIndex
                       ) {
                        cursor = escape.end
                        continue
                    }
                    let current = source[cursor]
                    cursor = source.index(after: cursor)
                    if current == quote { break }
                }
                tokens.append(.quoted(String(source[start..<cursor])))
                continue
            }
            if let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: cursor,
                upperBound: source.endIndex
            ) {
                let semantic = identifier.value.hasPrefix("--")
                    ? identifier.value
                    : identifier.value.lowercased()
                tokens.append(.atom(semantic))
                cursor = identifier.end
                continue
            }
            if character == "<" || character == ">" || character == "=" {
                var operation = String(character)
                cursor = next
                if character != "=", cursor < source.endIndex, source[cursor] == "=" {
                    operation.append("=")
                    cursor = source.index(after: cursor)
                }
                tokens.append(.spacedOperator(operation))
                continue
            }
            switch character {
            case "(": tokens.append(.openParenthesis)
            case ")": tokens.append(.closeParenthesis)
            case ":": tokens.append(.colon)
            case ",": tokens.append(.comma)
            case "/", "+", "*": tokens.append(.spacedOperator(String(character)))
            default: tokens.append(.delimiter(String(character)))
            }
            cursor = next
        }
        return tokens
    }
}

/// 論理名（日本語）: Lossless CSS source文書
/// 概要: CSS を再整形せず、style rule と declaration provenance を抽出し、部分編集を文字範囲へ限定します。
///
/// プロパティ:
/// - `source`: authored CSS 全文。
/// - `rules`: nested at-rule を含めて抽出した style rule 一覧。
struct OpenGraphiteCSSSourceDocument: Equatable {
    var source: String
    var rules: [OpenGraphiteCSSSourceRule]

    /// 論理名（日本語）: Lossless CSS source解析関数
    /// 処理概要: comment、未知rule、at-ruleを source に保持したまま style rule と declaration 範囲だけを索引化します。
    ///
    /// - Parameter source: CSS source 全文。
    /// - Returns: lossless source と索引化済み rule を持つ文書。
    static func parse(_ source: String) -> OpenGraphiteCSSSourceDocument {
        var parser = OpenGraphiteCSSSourceParser(source: source)
        return OpenGraphiteCSSSourceDocument(source: source, rules: parser.parse())
    }

    /// 論理名（日本語）: 独立stylesheet一括解析関数
    /// 処理概要: stylesheet境界とorigin metadataを保持し、同じDOM graph内で再利用できるlossless parse結果を作ります。
    ///
    /// - Parameter stylesheets: document orderの独立stylesheet source一覧。
    /// - Returns: 各sourceを一度だけ解析したstylesheet一覧。
    static func parseStylesheets(
        _ stylesheets: [OpenGraphiteCSSStylesheetSource]
    ) -> [OpenGraphiteCSSParsedStylesheetSource] {
        stylesheets.map { stylesheet in
            OpenGraphiteCSSParsedStylesheetSource(
                stylesheet: stylesheet,
                document: parse(stylesheet.source),
                containsDynamicKeyframes: containsDynamicKeyframes(in: stylesheet.source)
            )
        }
    }

    /// 論理名（日本語）: CSS provenance完全性検査関数
    /// 処理概要: lossless sourceを保持したまま、未対応selector/conditional/layerと不均衡tokenを検出します。
    ///
    /// - Parameter source: 検査対象の独立stylesheet source。
    /// - Returns: headless winnerを断定できない理由一覧。空なら既知cascade範囲でcompleteです。
    static func provenanceInspection(_ source: String) -> OpenGraphiteCSSProvenanceInspection {
        let document = parse(source)
        var reasons: [String] = []
        if !hasBalancedSourceTokens(source) {
            reasons.append("malformed-css-source")
        }
        let unsupportedAtRules = Set(
            document.rules.flatMap(\.atRules).map { $0.name.lowercased() }
                .filter {
                    ![
                        "media", "supports", "container", "scope", "document", "starting-style",
                        "keyframes", "-webkit-keyframes"
                    ].contains($0)
                }
        )
        for name in unsupportedAtRules.sorted() {
            reasons.append("unsupported-at-rule:@\(name)")
        }
        let guardedAtRuleNames = [
            "import", "layer", "property"
        ]
        for name in guardedAtRuleNames where containsAtKeyword(name, in: source) {
            let reason = "unsupported-at-rule:@\(name)"
            if !reasons.contains(reason) { reasons.append(reason) }
        }
        for selector in document.rules.flatMap(\.selectors)
        where !OpenGraphiteCSSSelector.isSupportedForHeadlessMatching(selector) {
            reasons.append("unsupported-selector:\(selector)")
        }
        return OpenGraphiteCSSProvenanceInspection(reasons: reasons)
    }

    /// 論理名（日本語）: Dynamic keyframes source判定関数
    /// 処理概要: style ruleの通常cascadeへ参加しないkeyframes定義を、animation適用nodeだけの不完全provenance判定へ分離します。
    ///
    /// - Parameter source: 独立stylesheet source。
    /// - Returns: comment/string外に標準またはWebKit keyframes at-ruleがある場合は`true`。
    static func containsDynamicKeyframes(in source: String) -> Bool {
        containsAtKeyword("keyframes", in: source)
            || containsAtKeyword("-webkit-keyframes", in: source)
    }

    /// 論理名（日本語）: CSS cascade trace生成関数
    /// 処理概要: selector、specificity、source order、`!important`、inheritance、custom property、shorthand を評価します。
    ///
    /// - Parameters:
    ///   - element: selector 照合対象の DOM element。
    ///   - inheritedValues: 親の resolved computed value。
    ///   - environment: active media condition。
    /// - Returns: authored provenance と resolved value を分離した trace。
    func cascadeTrace(
        for element: OpenGraphiteCSSDOMElement,
        inheritedValues: [String: String] = [:],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> OpenGraphiteCSSCascadeTrace {
        let extraction = candidateExtraction(for: element, environment: environment)
        let candidates = extraction.candidates
        let incompleteProperties = extraction.incompleteProperties

        var winners: [String: OpenGraphiteCSSDeclarationProvenance] = [:]
        var authoredValues: [String: String] = [:]
        for (property, propertyCandidates) in candidates {
            guard let winner = propertyCandidates.max(by: { Self.precedes($0, $1) }) else { continue }
            winners[property] = winner
            authoredValues[property] = winner.declaration.value
        }

        var trace = OpenGraphiteCSSCascadeTrace(
            candidates: candidates,
            winners: winners,
            authoredValues: authoredValues,
            resolvedValues: [:],
            incompleteProperties: incompleteProperties
        )
        Self.resolveComputedValues(in: &trace, inheritedValues: inheritedValues)
        if Self.containsDynamicKeyframes(in: source), Self.hasActiveAnimation(in: trace) {
            trace.incompleteProperties.insert("*")
        }
        return trace
    }

    /// 論理名（日本語）: Multi-stylesheet cascade trace生成関数
    /// 処理概要: 各stylesheetを個別ASTとして解析し、browserのlink順だけをcandidate orderへ合成します。
    ///
    /// - Parameters:
    ///   - element: selector照合対象DOM element。
    ///   - stylesheets: document orderの独立stylesheet source。
    ///   - inheritedValues: 親要素のcomputed値。
    ///   - environment: active media condition集合。
    /// - Returns: source境界付きprovenanceと合成後computed値。
    static func cascadeTrace(
        for element: OpenGraphiteCSSDOMElement,
        stylesheets: [OpenGraphiteCSSStylesheetSource],
        inheritedValues: [String: String] = [:],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> OpenGraphiteCSSCascadeTrace {
        cascadeTrace(
            for: element,
            parsedStylesheets: parseStylesheets(stylesheets),
            inheritedValues: inheritedValues,
            environment: environment
        )
    }

    /// 論理名（日本語）: 解析済みmulti-stylesheet cascade trace生成関数
    /// 処理概要: 一度解析した各stylesheet ASTを再利用し、browserのsource orderとorigin metadataを保ってcascadeを合成します。
    ///
    /// - Parameters:
    ///   - element: selector照合対象DOM element。
    ///   - parsedStylesheets: document orderとorigin metadataを保持する解析済みstylesheet一覧。
    ///   - inheritedValues: 親要素のcomputed値。
    ///   - environment: active media condition集合。
    /// - Returns: source境界付きprovenanceと合成後computed値。
    static func cascadeTrace(
        for element: OpenGraphiteCSSDOMElement,
        parsedStylesheets: [OpenGraphiteCSSParsedStylesheetSource],
        inheritedValues: [String: String] = [:],
        environment: OpenGraphiteCSSCascadeEnvironment = .base
    ) -> OpenGraphiteCSSCascadeTrace {
        var candidates: [String: [OpenGraphiteCSSDeclarationProvenance]] = [:]
        var incompleteProperties: Set<String> = []
        for (stylesheetOrder, parsedStylesheet) in parsedStylesheets.enumerated() {
            let stylesheet = parsedStylesheet.stylesheet
            guard isActive(stylesheet.atRules, environment: environment) else { continue }
            let extraction = parsedStylesheet.document.candidateExtraction(
                for: element,
                environment: environment
            )
            incompleteProperties.formUnion(extraction.incompleteProperties)
            for (property, localCandidates) in extraction.candidates {
                candidates[property, default: []].append(contentsOf: localCandidates.map { candidate in
                    var candidate = candidate
                    candidate.atRules = stylesheet.atRules + candidate.atRules
                    candidate.sourceID = stylesheet.sourceID
                    candidate.sourceKind = stylesheet.sourceKind
                    candidate.sourceEditable = stylesheet.editable
                    candidate.stylesheetOrder = stylesheetOrder
                    return candidate
                })
            }
        }
        var winners: [String: OpenGraphiteCSSDeclarationProvenance] = [:]
        var authoredValues: [String: String] = [:]
        for (property, propertyCandidates) in candidates {
            guard let winner = propertyCandidates.max(by: precedes) else { continue }
            winners[property] = winner
            authoredValues[property] = winner.declaration.value
        }
        var trace = OpenGraphiteCSSCascadeTrace(
            candidates: candidates,
            winners: winners,
            authoredValues: authoredValues,
            resolvedValues: [:],
            incompleteProperties: incompleteProperties
        )
        resolveComputedValues(in: &trace, inheritedValues: inheritedValues)
        if parsedStylesheets.contains(where: \.containsDynamicKeyframes),
           hasActiveAnimation(in: trace) {
            trace.incompleteProperties.insert("*")
        }
        return trace
    }

    /// 論理名（日本語）: CSS cascade候補抽出関数
    /// 処理概要: stylesheet単体ではcomputed解決せず、selector一致candidateと未評価conditional propertyだけを抽出します。
    ///
    /// - Parameters:
    ///   - element: selector照合対象DOM element。
    ///   - environment: active media condition集合。
    /// - Returns: 合成前candidateと構文上のnode単位incomplete property。
    private func candidateExtraction(
        for element: OpenGraphiteCSSDOMElement,
        environment: OpenGraphiteCSSCascadeEnvironment
    ) -> (
        candidates: [String: [OpenGraphiteCSSDeclarationProvenance]],
        incompleteProperties: Set<String>
    ) {
        var candidates: [String: [OpenGraphiteCSSDeclarationProvenance]] = [:]
        var incompleteProperties: Set<String> = []
        for rule in rules {
            if !Self.isActive(rule.atRules, environment: environment) {
                if Self.hasUnsupportedConditionalContext(rule.atRules) {
                    for selector in rule.selectors
                    where OpenGraphiteCSSSelector.isSupportedForHeadlessMatching(selector)
                        && OpenGraphiteCSSSelector.matches(selector, element: element) {
                        for declaration in rule.declarations {
                        incompleteProperties.formUnion(Self.provenanceProperties(for: declaration))
                        }
                    }
                }
                continue
            }
            for selector in rule.selectors {
                guard OpenGraphiteCSSSelector.matches(selector, element: element) else { continue }
                let specificity = OpenGraphiteCSSSelector.specificity(of: selector)
                for declaration in rule.declarations {
                    let expandedProperties = Self.expandedProperties(for: declaration)
                    incompleteProperties.formUnion(Self.incompleteProperties(for: declaration))
                    for (property, value) in expandedProperties {
                        var expanded = declaration
                        expanded.value = value
                        candidates[property, default: []].append(
                            OpenGraphiteCSSDeclarationProvenance(
                                property: property,
                                authoredProperty: declaration.name,
                                selector: selector,
                                specificity: specificity,
                                atRules: rule.atRules,
                                declaration: expanded
                            )
                        )
                    }
                }
            }
        }
        return (candidates, incompleteProperties)
    }

    /// 論理名（日本語）: CSS computed値再解決関数
    /// 処理概要: cascade winnerのraw provenanceを保持したまま、custom propertyとCSS-wide keywordをcomputed値へ解決します。
    ///
    /// - Parameters:
    ///   - trace: winner/candidateを確定済みのcascade trace。
    ///   - inheritedValues: 親要素のcomputed値。明示`inherit`では非継承propertyにも利用します。
    static func resolveComputedValues(
        in trace: inout OpenGraphiteCSSCascadeTrace,
        inheritedValues: [String: String]
    ) {
        var resolved = inheritedValues.filter { key, _ in
            key.hasPrefix("--") || inheritedProperties.contains(key)
        }
        var authoredCustomProperties = resolved.filter { $0.key.hasPrefix("--") }
        for (property, value) in trace.authoredValues where property.hasPrefix("--") {
            switch cssWideKeyword(in: value) {
            case "initial":
                authoredCustomProperties[property] = nil
            case "inherit", "unset":
                authoredCustomProperties[property] = inheritedValues[property]
            case "revert", "revert-layer":
                authoredCustomProperties[property] = inheritedValues[property]
                trace.incompleteProperties.insert(property)
            default:
                authoredCustomProperties[property] = value
            }
        }
        var customProperties: [String: String] = [:]
        for (property, value) in authoredCustomProperties {
            let resolution = resolveCSSValue(
                value,
                customProperties: authoredCustomProperties,
                resolving: [property],
                depth: 0
            )
            if resolution.fullyResolved {
                customProperties[property] = resolution.value
                resolved[property] = resolution.value
            } else {
                resolved[property] = nil
            }
        }
        for property in trace.winners.keys where !property.hasPrefix("--") {
            let ordered = (trace.candidates[property] ?? []).sorted(by: precedes)
            if let winner = ordered.last {
                let semanticResolution = resolvedCandidateValue(
                    property: property,
                    candidate: winner,
                    customProperties: customProperties
                )
                if semanticResolution.fullyResolved {
                    let keyword = cssWideKeyword(in: semanticResolution.value)
                    let needsInitial = keyword == "initial"
                        || (keyword == "unset" && !inheritedProperties.contains(property))
                        || (keyword == "inherit" && inheritedValues[property] == nil)
                    if keyword == "revert" || keyword == "revert-layer" {
                        trace.incompleteProperties.insert(property)
                    } else if containsEnvironmentDependentFunction(in: semanticResolution.value) {
                        trace.incompleteProperties.insert(property)
                    } else if !isValidCSSPropertyValue(semanticResolution.value, for: property) {
                        trace.incompleteProperties.insert(property)
                    } else if needsInitial, initialValue(for: property) == nil {
                        trace.incompleteProperties.insert(property)
                    }
                } else {
                    trace.incompleteProperties.insert(property)
                }
            }
            if let winnerIndex = ordered.indices.last,
               let value = resolvedCascadeValue(
                property: property,
                candidates: ordered,
                index: winnerIndex,
                inheritedValues: inheritedValues,
                customProperties: customProperties
            ) {
                resolved[property] = value
            } else {
                resolved[property] = nil
            }
        }
        trace.resolvedValues = resolved
    }

    /// var-backed shorthand candidateをcustom substitution後に対象longhand componentへ展開します。
    private static func resolvedCandidateValue(
        property: String,
        candidate: OpenGraphiteCSSDeclarationProvenance,
        customProperties: [String: String]
    ) -> CSSValueResolution {
        let variableResolution = resolveCSSValue(
            candidate.declaration.value,
            customProperties: customProperties,
            resolving: [],
            depth: 0
        )
        guard variableResolution.fullyResolved,
              candidate.authoredProperty != property,
              containsVariableFunction(in: candidate.declaration.value)
        else { return variableResolution }

        var semanticDeclaration = candidate.declaration
        semanticDeclaration.name = candidate.authoredProperty
        semanticDeclaration.value = variableResolution.value
        guard let component = expandedProperties(for: semanticDeclaration).first(where: { $0.0 == property }) else {
            return CSSValueResolution(value: variableResolution.value, fullyResolved: false)
        }
        return CSSValueResolution(value: component.1, fullyResolved: true)
    }

    /// CSS-wide keywordをcomputed値へ解決し、origin/layer不明な`revert`系は継承値またはUA fallbackへ委ねます。
    private static func resolvedCascadeValue(
        property: String,
        candidates: [OpenGraphiteCSSDeclarationProvenance],
        index: Int,
        inheritedValues: [String: String],
        customProperties: [String: String]
    ) -> String? {
        guard candidates.indices.contains(index) else {
            return defaultCascadeValue(for: property, inheritedValues: inheritedValues)
        }
        let variableResolution = resolvedCandidateValue(
            property: property,
            candidate: candidates[index],
            customProperties: customProperties
        )
        guard variableResolution.fullyResolved else {
            return defaultCascadeValue(for: property, inheritedValues: inheritedValues)
        }
        let authored = variableResolution.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch cssWideKeyword(in: authored) {
        case "inherit":
            return inheritedValues[property] ?? initialValue(for: property)
        case "initial":
            return initialValue(for: property)
        case "unset":
            return inheritedProperties.contains(property)
                ? inheritedValues[property] ?? initialValue(for: property)
                : initialValue(for: property)
        case "revert", "revert-layer":
            return inheritedProperties.contains(property)
                ? inheritedValues[property] ?? initialValue(for: property)
                : nil
        default:
            if containsEnvironmentDependentFunction(in: authored) { return nil }
            return isValidCSSPropertyValue(authored, for: property)
                ? authored
                : defaultCascadeValue(for: property, inheritedValues: inheritedValues)
        }
    }

    /// keyframesがcomputed値を時間依存にするanimation指定かを保守的に判定します。
    private static func hasActiveAnimation(in trace: OpenGraphiteCSSCascadeTrace) -> Bool {
        if let animationName = trace.resolvedValues["animation-name"] {
            let names = splitTopLevel(animationName, delimiter: ",")
            if names.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "none" }) {
                return true
            }
        }
        guard let animation = trace.resolvedValues["animation"] else { return false }
        return splitTopLevel(animation, delimiter: ",").contains { layer in
            let tokens = splitWhitespacePreservingFunctions(layer).map { $0.lowercased() }
            return !tokens.isEmpty && tokens != ["none"]
        }
    }

    /// declarationがない場合のcascade defaultを継承可否に応じて返します。
    private static func defaultCascadeValue(
        for property: String,
        inheritedValues: [String: String]
    ) -> String? {
        if inheritedProperties.contains(property), let inherited = inheritedValues[property] {
            return inherited
        }
        return initialValue(for: property)
    }

    /// WSCMでinspection・編集する標準propertyのCSS initial valueを返します。
    private static func initialValue(for property: String) -> String? {
        switch property {
        case "width", "height", "min-width", "min-height": return "auto"
        case "max-width", "max-height": return "none"
        case "display": return "inline"
        case "visibility": return "visible"
        case "position": return "static"
        case "top", "right", "bottom", "left", "z-index": return "auto"
        case "flex-direction": return "row"
        case "flex-wrap": return "nowrap"
        case "flex": return "0 1 auto"
        case "flex-grow": return "0"
        case "flex-shrink": return "1"
        case "flex-basis": return "auto"
        case "grid-template-columns", "grid-template-rows": return "none"
        case "grid-auto-columns", "grid-auto-rows": return "auto"
        case "grid-auto-flow": return "row"
        case "grid-column", "grid-row": return "auto"
        case "margin", "margin-top", "margin-right", "margin-bottom", "margin-left": return "0px"
        case "padding", "padding-top", "padding-right", "padding-bottom", "padding-left": return "0px"
        case "gap", "row-gap", "column-gap": return "normal"
        case "align-items", "align-content", "align-self", "justify-content", "justify-items": return "normal"
        case "overflow-wrap": return "normal"
        case "background": return nil
        case "border": return "medium none currentcolor"
        case "border-radius": return "0px"
        case "box-shadow": return "none"
        case "font-family": return nil
        case "font-size": return "medium"
        case "font-weight": return "normal"
        case "line-height", "letter-spacing": return "normal"
        case "text-align": return "start"
        case "object-fit": return "fill"
        case "stroke-width": return "1px"
        case "mask-image", "-webkit-mask-image": return "none"
        case "animation": return "none 0s ease 0s 1 normal none running"
        case "animation-name": return "none"
        case "animation-duration", "animation-delay": return "0s"
        case "animation-timing-function": return "ease"
        case "animation-iteration-count": return "1"
        case "animation-direction": return "normal"
        case "animation-fill-mode": return "none"
        case "animation-play-state": return "running"
        case "animation-timeline": return "auto"
        case "animation-range", "animation-range-start", "animation-range-end": return "normal"
        case "timeline-scope", "scroll-timeline", "scroll-timeline-name",
             "view-timeline", "view-timeline-name": return "none"
        case "scroll-timeline-axis", "view-timeline-axis": return "block"
        case "view-timeline-inset": return "auto"
        case "scale": return "none"
        case "transform-origin": return "50% 50% 0px"
        case "content-visibility": return "visible"
        default: return nil
        }
    }

    /// 論理名（日本語）: CSS宣言最小差分更新関数
    /// 処理概要: provenance がある場合は authored value range だけを置換し、ない場合は指定 selector の rule へ安全に追記します。
    ///
    /// - Parameters:
    ///   - property: 更新する CSS property。
    ///   - value: 新しい値。空文字は declaration 削除。
    ///   - provenance: 書き戻し元 declaration。未指定時は selector へ新規追記。
    ///   - fallbackSelector: provenance がない場合に使う selector。
    ///   - fallbackScope: 新規ruleを既存at-rule scopeへ追加するときのanchor provenance。
    ///   - fallbackAtRules: 別stylesheet winnerのscopeをcompanionへ再現するときの明示at-rule文脈。
    ///   - important: 新規declarationを`!important`として保存する場合は`true`。
    /// - Returns: 更新後の lossless CSS source。
    func setting(
        property: String,
        value: String,
        provenance: OpenGraphiteCSSDeclarationProvenance?,
        fallbackSelector: String,
        fallbackScope: OpenGraphiteCSSDeclarationProvenance? = nil,
        fallbackAtRules: [OpenGraphiteCSSAtRuleContext]? = nil,
        important: Bool = false
    ) -> String {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let provenance {
            if normalizedValue.isEmpty {
                if let rule = rules.first(where: {
                    $0.range.lowerBound <= provenance.declaration.range.lowerBound
                        && provenance.declaration.range.upperBound <= $0.range.upperBound
                }) {
                    let beforeDeclaration = source.substring(
                        offsetRange: rule.bodyRange.lowerBound..<provenance.declaration.range.lowerBound
                    )
                    let afterDeclaration = source.substring(
                        offsetRange: provenance.declaration.range.upperBound..<rule.bodyRange.upperBound
                    )
                    if Self.containsOnlyWhitespace(beforeDeclaration + afterDeclaration) {
                        return source.replacingCharacters(in: rule.range, with: "")
                    }
                }
                return source.replacingCharacters(in: provenance.declaration.range, with: "")
            }
            return source.replacingCharacters(in: provenance.declaration.valueRange, with: normalizedValue)
        }

        guard !normalizedValue.isEmpty else { return source }
        let selector = fallbackSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty else { return source }
        let expectedAtRules = fallbackAtRules ?? fallbackScope?.atRules ?? []
        let serializedValue = normalizedValue + (important ? " !important" : "")
        if let rule = rules.last(where: { rule in
            rule.atRules == expectedAtRules && rule.selectors.contains(selector)
        }) {
            let insertion = rule.bodyRange.upperBound
            let prefix = source.substring(offsetRange: rule.bodyRange).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\n"
                : (source.character(beforeOffset: insertion) == "\n" ? "" : "\n")
            return source.inserting("\(prefix)  \(property): \(serializedValue);\n", atOffset: insertion)
        }

        if let fallbackScope,
           let anchorRule = rules.first(where: {
               $0.range.lowerBound <= fallbackScope.declaration.range.lowerBound
                   && fallbackScope.declaration.range.upperBound <= $0.range.upperBound
           }) {
            let indentation = source.lineIndentation(atOffset: anchorRule.range.lowerBound)
            let rule = "\n\(indentation)\(selector) {\n\(indentation)  \(property): \(serializedValue);\n\(indentation)}"
            return source.inserting(rule, atOffset: anchorRule.range.upperBound)
        }

        let separator: String
        if source.isEmpty { separator = "" }
        else if source.hasSuffix("\n\n") { separator = "" }
        else if source.hasSuffix("\n") { separator = "\n" }
        else { separator = "\n\n" }
        var serializedRule = "\(selector) {\n  \(property): \(serializedValue);\n}"
        for context in expectedAtRules.reversed() {
            let prelude = context.prelude.trimmingCharacters(in: .whitespacesAndNewlines)
            let header = prelude.isEmpty ? "@\(context.name)" : "@\(context.name) \(prelude)"
            serializedRule = "\(header) {\n" + serializedRule
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "  \($0)" }
                .joined(separator: "\n") + "\n}"
        }
        return source + "\(separator)\(serializedRule)\n"
    }

    /// 論理名（日本語）: CSS空白限定判定関数
    /// 処理概要: declaration削除後のrule bodyが空白だけかを判定し、commentを失わない空style rule cleanupに使います。
    ///
    /// - Parameter source: rule bodyの残存source。
    /// - Returns: 空白以外を含まない場合は`true`。
    private static func containsOnlyWhitespace(_ source: String) -> Bool {
        source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let inheritedProperties: Set<String> = [
        "color", "cursor", "direction", "font", "font-family", "font-size", "font-style",
        "font-variant", "font-weight", "letter-spacing", "line-height", "text-align",
        "text-indent", "text-transform", "visibility", "white-space", "word-spacing", "overflow-wrap",
        "stroke-width"
    ]

    /// 論理名（日本語）: CSS継承property判定関数
    /// 処理概要: 指定propertyが標準cascadeで親computed値を継承するかを判定します。
    ///
    /// - Parameter property: 判定するCSS property名。
    /// - Returns: custom propertyまたは標準の継承propertyの場合は`true`。
    static func isInheritedProperty(_ property: String) -> Bool {
        property.hasPrefix("--") || inheritedProperties.contains(property)
    }

    private static func isActive(
        _ contexts: [OpenGraphiteCSSAtRuleContext],
        environment: OpenGraphiteCSSCascadeEnvironment
    ) -> Bool {
        for context in contexts {
            switch context.name {
            case "media":
                guard environment.activeMediaQueries.contains(
                    OpenGraphiteCSSCascadeEnvironment.normalizedMediaCondition(context.prelude)
                ) else { return false }
            case "layer":
                continue
            default:
                guard environment.includeUnknownConditionalRules else { return false }
            }
        }
        return true
    }

    /// `@supports`等のheadlessで真偽を断定しないconditional contextを判定します。
    private static func hasUnsupportedConditionalContext(
        _ contexts: [OpenGraphiteCSSAtRuleContext]
    ) -> Bool {
        contexts.contains { context in
            ["supports", "container", "scope", "document", "starting-style"]
                .contains(context.name.lowercased())
        }
    }

    private static func precedes(
        _ lhs: OpenGraphiteCSSDeclarationProvenance,
        _ rhs: OpenGraphiteCSSDeclarationProvenance
    ) -> Bool {
        if lhs.declaration.important != rhs.declaration.important {
            return !lhs.declaration.important && rhs.declaration.important
        }
        if lhs.specificity != rhs.specificity {
            return lhs.specificity < rhs.specificity
        }
        if lhs.stylesheetOrder != rhs.stylesheetOrder {
            return lhs.stylesheetOrder < rhs.stylesheetOrder
        }
        return lhs.declaration.sourceOrder < rhs.declaration.sourceOrder
    }

    /// 論理名（日本語）: CSS shorthand展開関数
    /// 処理概要: authored declarationをcascade解決対象のproperty/value組へ展開し、遅延`var()` shorthandはraw値を各componentへ対応付けます。
    ///
    /// - Parameter declaration: 展開するauthored CSS declaration。
    /// - Returns: 展開後のproperty名と値の組。grammarが無効な場合は空配列。
    static func expandedProperties(
        for declaration: OpenGraphiteCSSSourceDeclaration
    ) -> [(String, String)] {
        let name = declaration.name
        if containsVariableFunction(in: declaration.value),
           let deferredProperties = deferredShorthandProperties[name] {
            return deferredProperties.map { ($0, declaration.value) }
        }
        guard isValidCSSPropertyValue(declaration.value, for: name) else { return [] }
        switch name {
        case "margin", "padding", "inset", "border-width", "border-style", "border-color":
            let values = splitWhitespacePreservingFunctions(declaration.value)
            guard (1...4).contains(values.count) else { return [] }
            let suffixes: [String]
            if name == "margin" || name == "padding" || name == "inset" {
                suffixes = ["top", "right", "bottom", "left"]
            } else {
                let prefix = String(name.dropLast(name.split(separator: "-").last?.count ?? 0)).dropLast()
                let terminal = name.split(separator: "-").last.map(String.init) ?? ""
                return boxValues(declaration.value).enumerated().map { index, value in
                    ("\(prefix)-\(["top", "right", "bottom", "left"][index])-\(terminal)", value)
                } + [(name, declaration.value)]
            }
            return boxValues(declaration.value).enumerated().map { index, value in
                ("\(name == "inset" ? "" : name + "-")\(suffixes[index])", value)
            } + [(name, declaration.value)]
        case "gap":
            let values = splitWhitespacePreservingFunctions(declaration.value)
            guard let first = values.first, values.count <= 2 else { return [] }
            return [
                ("row-gap", first),
                ("column-gap", values.count > 1 ? values[1] : first),
                (name, declaration.value)
            ]
        case "flex-flow":
            if cssWideKeyword(in: declaration.value) != nil {
                return [
                    ("flex-direction", declaration.value),
                    ("flex-wrap", declaration.value),
                    (name, declaration.value)
                ]
            }
            let tokens = splitWhitespacePreservingFunctions(declaration.value)
            let direction = tokens.first {
                ["row", "row-reverse", "column", "column-reverse"].contains($0.lowercased())
            } ?? "row"
            let wrap = tokens.first {
                ["nowrap", "wrap", "wrap-reverse"].contains($0.lowercased())
            } ?? "nowrap"
            return [
                ("flex-direction", direction),
                ("flex-wrap", wrap),
                (name, declaration.value)
            ]
        case "grid-template":
            guard let expanded = expandedGridTemplate(declaration.value) else { return [] }
            return [
                ("grid-template-rows", expanded.rows),
                ("grid-template-columns", expanded.columns),
                (name, declaration.value)
            ]
        case "grid":
            let expanded = expandedGrid(declaration.value)
            return expanded.isEmpty ? [] : expanded + [(name, declaration.value)]
        case "mask":
            return [("mask-image", maskImageValue(from: declaration.value)), (name, declaration.value)]
        case "-webkit-mask":
            return [("-webkit-mask-image", maskImageValue(from: declaration.value)), (name, declaration.value)]
        default:
            return [(name, declaration.value)]
        }
    }

    /// `var()`解決後までlonghand component抽出を遅延するshorthandと対象propertyを定義します。
    private static let deferredShorthandProperties: [String: [String]] = [
        "margin": ["margin-top", "margin-right", "margin-bottom", "margin-left", "margin"],
        "padding": ["padding-top", "padding-right", "padding-bottom", "padding-left", "padding"],
        "inset": ["top", "right", "bottom", "left", "inset"],
        "border-width": [
            "border-top-width", "border-right-width", "border-bottom-width", "border-left-width", "border-width"
        ],
        "border-style": [
            "border-top-style", "border-right-style", "border-bottom-style", "border-left-style", "border-style"
        ],
        "border-color": [
            "border-top-color", "border-right-color", "border-bottom-color", "border-left-color", "border-color"
        ],
        "gap": ["row-gap", "column-gap", "gap"],
        "flex-flow": ["flex-direction", "flex-wrap", "flex-flow"],
        "grid-template": ["grid-template-rows", "grid-template-columns", "grid-template"],
        "grid": [
            "grid-template-rows", "grid-template-columns", "grid-auto-rows", "grid-auto-columns", "grid-auto-flow", "grid"
        ],
        "mask": ["mask-image", "mask"],
        "-webkit-mask": ["-webkit-mask-image", "-webkit-mask"]
    ]

    /// `grid-template` shorthandをinspection用のrow/column longhandへ保守的に展開します。
    private static func expandedGridTemplate(_ value: String) -> (rows: String, columns: String)? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cssWideKeyword(in: normalized) != nil {
            return (normalized, normalized)
        }
        let sides = splitTopLevel(normalized, delimiter: "/")
        let rowSource = sides.first ?? "none"
        let columns = sides.count > 1 ? sides[1] : "none"
        let rowTokens = splitWhitespacePreservingFunctions(rowSource)
        let hasTemplateArea = rowTokens.contains {
            ($0.first == "\"" && $0.last == "\"") || ($0.first == "'" && $0.last == "'")
        }
        if hasTemplateArea, !hasValidGridTemplateAreas(rowTokens) { return nil }
        var normalizedRows: [String] = []
        var areaNeedsTrackSize = false
        if hasTemplateArea {
            for token in rowTokens {
                let isArea = (token.first == "\"" && token.last == "\"")
                    || (token.first == "'" && token.last == "'")
                let isLineNames = token.first == "[" && token.last == "]"
                if isArea {
                    if areaNeedsTrackSize { normalizedRows.append("auto") }
                    areaNeedsTrackSize = true
                } else if isLineNames {
                    if areaNeedsTrackSize {
                        normalizedRows.append("auto")
                        areaNeedsTrackSize = false
                    }
                    normalizedRows.append(token)
                } else if areaNeedsTrackSize {
                    normalizedRows.append(token)
                    areaNeedsTrackSize = false
                } else {
                    normalizedRows.append(token)
                }
            }
            if areaNeedsTrackSize { normalizedRows.append("auto") }
        }
        let rows = hasTemplateArea
            ? normalizedRows.joined(separator: " ")
            : (rowSource.isEmpty ? "none" : rowSource)
        return (rows, columns.isEmpty ? "none" : columns)
    }

    /// Grid template area stringのcell数・identifier・矩形領域を標準grammarへ照合します。
    private static func hasValidGridTemplateAreas(_ tokens: [String]) -> Bool {
        let quotedRows = tokens.filter {
            ($0.first == "\"" && $0.last == "\"") || ($0.first == "'" && $0.last == "'")
        }
        var rows: [[String]] = []
        for quoted in quotedRows {
            guard quoted.count >= 2 else { return false }
            let content = String(quoted.dropFirst().dropLast())
            let cells = content.split(whereSeparator: OpenGraphiteCSSIdentifier.isCSSWhitespace).map(String.init)
            guard !cells.isEmpty else { return false }
            var semanticCells: [String] = []
            for cell in cells {
                if cell.allSatisfy({ $0 == "." }) {
                    semanticCells.append(".")
                } else {
                    guard let identifier = OpenGraphiteCSSIdentifier.decode(
                        in: cell,
                        range: cell.startIndex..<cell.endIndex
                    ), !identifier.isEmpty else { return false }
                    semanticCells.append(identifier)
                }
            }
            rows.append(semanticCells)
        }
        guard let columnCount = rows.first?.count,
              rows.allSatisfy({ $0.count == columnCount })
        else { return false }
        let names = Set(rows.flatMap { $0 }.filter { $0 != "." })
        for name in names {
            let positions = rows.indices.flatMap { row in
                rows[row].indices.compactMap { column in
                    rows[row][column] == name ? (row, column) : nil
                }
            }
            guard let minRow = positions.map(\.0).min(),
                  let maxRow = positions.map(\.0).max(),
                  let minColumn = positions.map(\.1).min(),
                  let maxColumn = positions.map(\.1).max()
            else { continue }
            for row in minRow...maxRow where rows[row][minColumn...maxColumn].contains(where: { $0 != name }) {
                return false
            }
        }
        return true
    }

    /// `grid` shorthandのtemplate/auto-flow分岐とreset対象longhandを展開します。
    private static func expandedGrid(_ value: String) -> [(String, String)] {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cssWideKeyword(in: normalized) != nil {
            return [
                ("grid-template-rows", normalized),
                ("grid-template-columns", normalized),
                ("grid-auto-rows", normalized),
                ("grid-auto-columns", normalized),
                ("grid-auto-flow", normalized)
            ]
        }
        let sides = splitTopLevel(normalized, delimiter: "/")
        let before = sides.first ?? "none"
        let after = sides.count > 1 ? sides[1] : "none"
        let beforeTokens = splitWhitespacePreservingFunctions(before)
        let afterTokens = splitWhitespacePreservingFunctions(after)
        if beforeTokens.contains(where: { $0.lowercased() == "auto-flow" }) {
            let dense = beforeTokens.contains { $0.lowercased() == "dense" }
            let autoRows = beforeTokens.first {
                !["auto-flow", "dense"].contains($0.lowercased())
            } ?? "auto"
            return [
                ("grid-template-rows", "none"),
                ("grid-template-columns", after.isEmpty ? "none" : after),
                ("grid-auto-rows", autoRows),
                ("grid-auto-columns", "auto"),
                ("grid-auto-flow", dense ? "row dense" : "row")
            ]
        }
        if afterTokens.contains(where: { $0.lowercased() == "auto-flow" }) {
            let dense = afterTokens.contains { $0.lowercased() == "dense" }
            let autoColumns = afterTokens.first {
                !["auto-flow", "dense"].contains($0.lowercased())
            } ?? "auto"
            return [
                ("grid-template-rows", before.isEmpty ? "none" : before),
                ("grid-template-columns", "none"),
                ("grid-auto-rows", "auto"),
                ("grid-auto-columns", autoColumns),
                ("grid-auto-flow", dense ? "column dense" : "column")
            ]
        }
        guard let template = expandedGridTemplate(normalized) else { return [] }
        return [
            ("grid-template-rows", template.rows),
            ("grid-template-columns", template.columns),
            ("grid-auto-rows", "auto"),
            ("grid-auto-columns", "auto"),
            ("grid-auto-flow", "row")
        ]
    }

    /// 通常propertyでcomputed semanticsを持つCSS-wide keyword集合です。
    private static let cssWideKeywords: Set<String> = [
        "inherit", "initial", "unset", "revert", "revert-layer"
    ]

    /// 論理名（日本語）: CSS property値検証関数
    /// 処理概要: browserがdeclarationを破棄するkeyword、geometry、track、数値grammarを、CSS escapeとfunction blockを保ったsemantic tokenで検証します。
    ///
    /// - Parameters:
    ///   - value: authored CSS value。
    ///   - property: lowercased CSS property名。
    /// - Returns: 対応grammarで有効、またはheadless検証対象外なら`true`。
    static func isValidCSSPropertyValue(_ value: String, for property: String) -> Bool {
        let normalizedProperty = property.lowercased()
        let trimmed = trimmingCSSWhitespace(value)
        guard !trimmed.isEmpty,
              hasBalancedSourceTokens(trimmed),
              hasSafePropertyValueBoundary(trimmed)
        else { return false }
        if normalizedProperty.hasPrefix("--") { return true }
        if cssWideKeyword(in: trimmed) != nil { return true }
        if containsVariableFunction(in: trimmed) {
            return hasValidVariableFunctions(in: trimmed)
        }
        let rawTokens = splitWhitespacePreservingFunctions(trimmed)
        let tokens = rawTokens.compactMap { token in
            OpenGraphiteCSSIdentifier.decode(
                in: token,
                range: token.startIndex..<token.endIndex
            )?.lowercased()
        }
        switch normalizedProperty {
        case "display":
            guard tokens.count == rawTokens.count else { return false }
            let singleValues: Set<String> = [
                "none", "contents", "block", "inline", "run-in", "flow", "flow-root",
                "table", "flex", "grid", "ruby", "math", "list-item", "inline-block", "inline-table",
                "inline-flex", "inline-grid", "table-row-group", "table-header-group",
                "table-footer-group", "table-row", "table-cell", "table-column-group",
                "table-column", "table-caption", "ruby-base", "ruby-text", "ruby-base-container",
                "ruby-text-container"
            ]
            if tokens.count == 1 { return singleValues.contains(tokens[0]) }
            let tokenSet = Set(tokens)
            guard tokenSet.count == tokens.count else { return false }
            if tokenSet.contains("list-item") {
                return tokenSet.isSubset(of: ["list-item", "block", "inline", "run-in", "flow", "flow-root"])
                    && tokens.count <= 3
            }
            let outside: Set<String> = ["block", "inline", "run-in"]
            let inside: Set<String> = ["flow", "flow-root", "table", "flex", "grid", "ruby", "math"]
            return tokens.count == 2
                && tokens.contains(where: outside.contains)
                && tokens.contains(where: inside.contains)
        case "flex-direction":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1
                && ["row", "row-reverse", "column", "column-reverse"].contains(tokens[0])
        case "flex-wrap":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["nowrap", "wrap", "wrap-reverse"].contains(tokens[0])
        case "flex-flow":
            guard tokens.count == rawTokens.count else { return false }
            guard (1...2).contains(tokens.count) else { return false }
            let directions = tokens.filter {
                ["row", "row-reverse", "column", "column-reverse"].contains($0)
            }
            let wraps = tokens.filter { ["nowrap", "wrap", "wrap-reverse"].contains($0) }
            return directions.count <= 1 && wraps.count <= 1 && directions.count + wraps.count == tokens.count
        case "position":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["static", "relative", "absolute", "sticky", "fixed"].contains(tokens[0])
        case "visibility":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["visible", "hidden", "collapse"].contains(tokens[0])
        case "overflow-wrap":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["normal", "break-word", "anywhere"].contains(tokens[0])
        case "object-fit":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["fill", "contain", "cover", "none", "scale-down"].contains(tokens[0])
        case "content-visibility":
            guard tokens.count == rawTokens.count else { return false }
            return tokens.count == 1 && ["visible", "auto", "hidden"].contains(tokens[0])
        case "grid-auto-flow":
            guard tokens.count == rawTokens.count else { return false }
            guard (1...2).contains(tokens.count) else { return false }
            let tokenSet = Set(tokens)
            return tokenSet.count == tokens.count
                && tokenSet.isSubset(of: ["row", "column", "dense"])
                && !(tokenSet.contains("row") && tokenSet.contains("column"))
        case "width", "height", "min-width", "min-height", "max-width", "max-height":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            let keywords: Set<String> = normalizedProperty.hasPrefix("max-")
                ? ["none", "min-content", "max-content", "stretch", "fit-content"]
                : ["auto", "min-content", "max-content", "stretch", "fit-content"]
            return isLengthPercentageToken(token, allowNegative: false)
                || isSemanticIdentifier(token, in: keywords)
                || isFitContentFunction(token)
                || isTypedNumericFunction(token, allowing: lengthPercentageNumericKinds)
        case "left", "right", "top", "bottom":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isLengthPercentageToken(token, allowNegative: true)
                || isSemanticIdentifier(token, in: ["auto"])
                || isTypedNumericFunction(token, allowing: lengthPercentageNumericKinds)
        case "margin":
            return isBoxValue(rawTokens, allowAuto: true, allowNegative: true)
        case "margin-top", "margin-right", "margin-bottom", "margin-left":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isLengthPercentageToken(token, allowNegative: true)
                || isSemanticIdentifier(token, in: ["auto"])
        case "padding":
            return isBoxValue(rawTokens, allowAuto: false, allowNegative: false)
        case "padding-top", "padding-right", "padding-bottom", "padding-left":
            return rawTokens.count == 1
                && rawTokens.allSatisfy { isLengthPercentageToken($0, allowNegative: false) }
        case "inset":
            return isBoxValue(rawTokens, allowAuto: true, allowNegative: true)
        case "gap":
            guard (1...2).contains(rawTokens.count) else { return false }
            return rawTokens.allSatisfy {
                isLengthPercentageToken($0, allowNegative: false)
                    || isSemanticIdentifier($0, in: ["normal"])
            }
        case "row-gap", "column-gap":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isLengthPercentageToken(token, allowNegative: false)
                || isSemanticIdentifier(token, in: ["normal"])
        case "grid-template-columns", "grid-template-rows":
            return isGridTrackList(trimmed, allowsTemplateKeywords: true)
        case "grid-auto-columns", "grid-auto-rows":
            return isGridTrackList(trimmed, allowsTemplateKeywords: false)
        case "grid-template":
            guard let expanded = expandedGridTemplate(trimmed) else { return false }
            return isGridTrackList(expanded.rows, allowsTemplateKeywords: true)
                && isGridTrackList(expanded.columns, allowsTemplateKeywords: true)
        case "grid":
            let expanded = expandedGrid(trimmed)
            return !expanded.isEmpty && expanded.allSatisfy { property, component in
                isValidCSSPropertyValue(component, for: property)
            }
        case "z-index":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isCSSInteger(token)
                || isSemanticIdentifier(token, in: ["auto"])
                || isTypedNumericFunction(token, allowing: [.number], names: ["calc"])
        case "stroke-width":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isCSSNumber(token, allowNegative: false)
                || isLengthPercentageToken(token, allowNegative: false)
                || isTypedNumericFunction(
                    token,
                    allowing: lengthPercentageNumericKinds.union([.number])
                )
        case "scale":
            if rawTokens.count == 1, isSemanticIdentifier(rawTokens[0], in: ["none"]) { return true }
            guard (1...3).contains(rawTokens.count) else { return false }
            return rawTokens.allSatisfy {
                isCSSNumber($0, allowNegative: true)
                    || isPercentageToken($0, allowNegative: true)
                    || isTypedNumericFunction(
                        $0,
                        allowing: [.number, .percentage]
                    )
            }
        case "font-size":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isLengthPercentageToken(token, allowNegative: false)
                || isSemanticIdentifier(token, in: [
                    "xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large",
                    "smaller", "larger", "math"
                ])
        case "line-height":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isCSSNumber(token, allowNegative: false)
                || isLengthPercentageToken(token, allowNegative: false)
                || isTypedNumericFunction(
                    token,
                    allowing: lengthPercentageNumericKinds.union([.number])
                )
                || isSemanticIdentifier(token, in: ["normal"])
        case "letter-spacing":
            guard rawTokens.count == 1, let token = rawTokens.first else { return false }
            return isLengthPercentageToken(token, allowNegative: true, allowsPercentage: false)
                || isSemanticIdentifier(token, in: ["normal"])
        default:
            return true
        }
    }

    /// headlessでgrammarを明示検証するproperty集合です。
    private static let validatedCSSProperties: Set<String> = [
        "display", "flex-direction", "flex-wrap", "flex-flow", "position", "visibility",
        "overflow-wrap", "object-fit", "content-visibility", "grid-auto-flow",
        "width", "height", "min-width", "min-height", "max-width", "max-height",
        "left", "right", "top", "bottom", "margin", "margin-top", "margin-right", "margin-bottom",
        "margin-left", "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
        "inset", "gap", "row-gap", "column-gap", "grid-template-columns", "grid-template-rows",
        "grid-auto-columns", "grid-auto-rows", "grid-template", "grid", "z-index", "stroke-width",
        "scale", "font-size", "line-height", "letter-spacing"
    ]

    /// 論理名（日本語）: CSS不完全property抽出関数
    /// 処理概要: authored declarationがheadless grammarまたはenvironment依存性により確定不能なとき、影響するproperty集合を返します。
    ///
    /// - Parameter declaration: 不完全性を判定するauthored CSS declaration。
    /// - Returns: node-level incompleteとして扱うproperty名の集合。
    static func incompleteProperties(
        for declaration: OpenGraphiteCSSSourceDeclaration
    ) -> Set<String> {
        guard validatedCSSProperties.contains(declaration.name),
              containsEnvironmentDependentFunction(in: declaration.value)
                || !isValidCSSPropertyValue(declaration.value, for: declaration.name)
        else { return [] }
        if let expanded = deferredShorthandProperties[declaration.name] {
            return Set(expanded)
        }
        return [declaration.name]
    }

    /// 1〜4個のbox componentをlength-percentageとoptional autoへ照合します。
    private static func isBoxValue(
        _ tokens: [String],
        allowAuto: Bool,
        allowNegative: Bool
    ) -> Bool {
        guard (1...4).contains(tokens.count) else { return false }
        return tokens.allSatisfy { token in
            isLengthPercentageToken(token, allowNegative: allowNegative)
                || (allowAuto && isSemanticIdentifier(token, in: ["auto"]))
        }
    }

    /// CSS number tokenを符号境界付きで検証します。
    private static func isCSSNumber(_ token: String, allowNegative: Bool) -> Bool {
        let pattern = #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#
        guard token.range(of: pattern, options: .regularExpression) != nil,
              let number = Double(token)
        else { return false }
        return allowNegative || number >= 0
    }

    /// CSS integer tokenを検証します。
    private static func isCSSInteger(_ token: String) -> Bool {
        token.range(of: #"^[+-]?[0-9]+$"#, options: .regularExpression) != nil
    }

    /// percentage tokenを符号境界付きで検証します。
    private static func isPercentageToken(_ token: String, allowNegative: Bool) -> Bool {
        guard token.hasSuffix("%") else { return false }
        return isCSSNumber(String(token.dropLast()), allowNegative: allowNegative)
    }

    /// 標準length / percentage / math function tokenを検証します。
    private static func isLengthPercentageToken(
        _ token: String,
        allowNegative: Bool,
        allowsPercentage: Bool = true
    ) -> Bool {
        if allowsPercentage, isPercentageToken(token, allowNegative: allowNegative) { return true }
        if isTypedNumericFunction(token, allowing: lengthPercentageNumericKinds) {
            return true
        }
        return isRawLengthToken(token, allowNegative: allowNegative)
    }

    /// functionを含まない標準length dimensionまたはunitless zeroを検証します。
    private static func isRawLengthToken(_ token: String, allowNegative: Bool) -> Bool {
        let numberPattern = #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#
        guard let numberRange = token.range(of: numberPattern, options: .regularExpression),
              numberRange.lowerBound == token.startIndex,
              let number = Double(token[numberRange]),
              allowNegative || number >= 0
        else { return false }
        let rawUnit = String(token[numberRange.upperBound...])
        if rawUnit.isEmpty { return number == 0 }
        guard let unit = OpenGraphiteCSSIdentifier.decode(
            in: rawUnit,
            range: rawUnit.startIndex..<rawUnit.endIndex
        )?.lowercased() else { return false }
        return cssLengthUnits.contains(unit)
    }

    /// CSS length unitの標準集合です。
    private static let cssLengthUnits: Set<String> = [
        "px", "cm", "mm", "q", "in", "pc", "pt",
        "em", "ex", "cap", "ch", "ic", "rem", "lh", "rlh",
        "vw", "vh", "vi", "vb", "vmin", "vmax",
        "svw", "svh", "svi", "svb", "svmin", "svmax",
        "lvw", "lvh", "lvi", "lvb", "lvmin", "lvmax",
        "dvw", "dvh", "dvi", "dvb", "dvmin", "dvmax",
        "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax"
    ]

    /// 単一CSS identifierをsemantic keyword集合へ照合します。
    private static func isSemanticIdentifier(_ token: String, in values: Set<String>) -> Bool {
        guard let identifier = OpenGraphiteCSSIdentifier.decode(
            in: token,
            range: token.startIndex..<token.endIndex
        )?.lowercased() else { return false }
        return values.contains(identifier)
    }

    /// token全体を占めるbalanced CSS functionをsemantic名と引数へ分解します。
    private static func parsedValueFunction(_ token: String) -> (name: String, arguments: String)? {
        guard let identifier = OpenGraphiteCSSIdentifier.consume(
            in: token,
            from: token.startIndex,
            upperBound: token.endIndex
        ), identifier.end < token.endIndex, token[identifier.end] == "(",
              let end = simpleBlockEnd(in: token, openingAt: identifier.end), end == token.endIndex
        else { return nil }
        let argumentStart = token.index(after: identifier.end)
        let argumentEnd = token.index(before: end)
        return (
            identifier.value.lowercased(),
            String(token[argumentStart..<argumentEnd])
        )
    }

    /// 論理名（日本語）: CSS typed arithmetic数値種別
    /// 概要: math functionのresult typeをnumber、percentage、length、length-percentageへ分離してproperty grammarと照合します。
    private enum CSSNumericKind {
        case number
        case percentage
        case length
        case lengthPercentage
        case unknown
    }

    /// 論理名（日本語）: length-percentage 数値種別集合
    /// 概要: `<length-percentage>` を受理するpropertyで許可する単独・混合result typeを共有します。
    private static let lengthPercentageNumericKinds: Set<CSSNumericKind> = [
        .length, .percentage, .lengthPercentage
    ]

    /// `calc()` / `min()` / `max()` / `clamp()`を引数grammarとresult typeまで検証します。
    private static func isTypedNumericFunction(
        _ token: String,
        allowing allowedKinds: Set<CSSNumericKind>,
        names: Set<String> = ["calc", "min", "max", "clamp", "env", "anchor", "anchor-size"]
    ) -> Bool {
        guard let function = parsedValueFunction(token), names.contains(function.name) else { return false }
        if ["env", "anchor", "anchor-size"].contains(function.name) {
            let arguments = splitTopLevelArguments(function.arguments)
            return !arguments.isEmpty
                && !arguments[0].isEmpty
                && arguments.allSatisfy(hasBalancedSourceTokens)
        }
        guard let kind = numericFunctionKind(function) else { return false }
        return kind == .unknown || allowedKinds.contains(kind)
    }

    /// parsed math functionのresult typeを返します。
    private static func numericFunctionKind(
        _ function: (name: String, arguments: String)
    ) -> CSSNumericKind? {
        switch function.name {
        case "calc":
            return cssMathExpressionKind(function.arguments)
        case "min", "max":
            let arguments = splitTopLevelArguments(function.arguments)
            guard !arguments.isEmpty, arguments.allSatisfy({ !$0.isEmpty }) else { return nil }
            return commonNumericKind(arguments.compactMap(cssMathExpressionKind), expectedCount: arguments.count)
        case "clamp":
            let arguments = splitTopLevelArguments(function.arguments)
            guard arguments.count == 3, arguments.allSatisfy({ !$0.isEmpty }) else { return nil }
            return commonNumericKind(arguments.compactMap(cssMathExpressionKind), expectedCount: 3)
        default:
            return nil
        }
    }

    /// 数値function引数が同じtyped arithmetic categoryへ解決できることを確認します。
    private static func commonNumericKind(
        _ kinds: [CSSNumericKind],
        expectedCount: Int
    ) -> CSSNumericKind? {
        guard kinds.count == expectedCount else { return nil }
        let knownKinds = kinds.filter { $0 != .unknown }
        guard let first = knownKinds.first else { return .unknown }
        guard !knownKinds.dropFirst().allSatisfy({ $0 == first }) else { return first }
        let kindSet = Set(knownKinds)
        if kindSet.isSubset(of: [.length, .percentage, .lengthPercentage]) {
            return .lengthPercentage
        }
        return nil
    }

    /// top-level加減算・乗除算をCSS typed arithmeticとして再帰評価します。
    private static func cssMathExpressionKind(_ source: String) -> CSSNumericKind? {
        let normalized = removingCSSCommentsForValidation(source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, hasBalancedSourceTokens(normalized) else { return nil }

        if let additive = splitMathExpression(normalized, operators: ["+", "-"], requiresWhitespace: true),
           !additive.operators.isEmpty {
            let kinds = additive.operands.compactMap(cssMathExpressionKind)
            return commonNumericKind(kinds, expectedCount: additive.operands.count)
        }
        if let multiplicative = splitMathExpression(normalized, operators: ["*", "/"], requiresWhitespace: false),
           !multiplicative.operators.isEmpty {
            guard var result = cssMathExpressionKind(multiplicative.operands[0]) else { return nil }
            for index in multiplicative.operators.indices {
                guard let right = cssMathExpressionKind(multiplicative.operands[index + 1]) else { return nil }
                switch multiplicative.operators[index] {
                case "*":
                    if result == .number {
                        result = right
                    } else if right == .number {
                        continue
                    } else if result == .unknown || right == .unknown {
                        result = .unknown
                    } else {
                        return nil
                    }
                case "/":
                    guard right == .number || right == .unknown else { return nil }
                default:
                    return nil
                }
            }
            return result
        }
        return cssMathAtomKind(normalized)
    }

    /// 単一numeric token、grouping block、nested math functionのtypeを返します。
    private static func cssMathAtomKind(_ token: String) -> CSSNumericKind? {
        if token.first == "(",
           let end = simpleBlockEnd(in: token, openingAt: token.startIndex),
           end == token.endIndex {
            let start = token.index(after: token.startIndex)
            let finish = token.index(before: token.endIndex)
            return cssMathExpressionKind(String(token[start..<finish]))
        }
        if isCSSNumber(token, allowNegative: true) { return .number }
        if isPercentageToken(token, allowNegative: true) { return .percentage }
        if isRawLengthToken(token, allowNegative: true) { return .length }
        if isSemanticIdentifier(token, in: ["e", "pi", "infinity", "-infinity", "nan"]) {
            return .number
        }
        guard let function = parsedValueFunction(token) else { return nil }
        if ["env", "anchor", "anchor-size"].contains(function.name) {
            let arguments = splitTopLevelArguments(function.arguments)
            return !arguments.isEmpty && !arguments[0].isEmpty ? .unknown : nil
        }
        return numericFunctionKind(function)
    }

    /// 指定operatorだけでtop-level math expressionを分割します。
    private static func splitMathExpression(
        _ source: String,
        operators expectedOperators: Set<Character>,
        requiresWhitespace: Bool
    ) -> (operands: [String], operators: [Character])? {
        var operands: [String] = []
        var operators: [Character] = []
        var segmentStart = source.startIndex
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let character = source[cursor]
            if character == "\"" || character == "'" { return nil }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                continue
            }
            if simpleBlockCloser(for: character) != nil {
                guard let end = simpleBlockEnd(in: source, openingAt: cursor) else { return nil }
                cursor = end
                continue
            }
            if expectedOperators.contains(character) {
                let previousIsWhitespace = cursor > source.startIndex
                    && OpenGraphiteCSSIdentifier.isCSSWhitespace(source[source.index(before: cursor)])
                let next = source.index(after: cursor)
                let nextIsWhitespace = next < source.endIndex
                    && OpenGraphiteCSSIdentifier.isCSSWhitespace(source[next])
                if !requiresWhitespace || (previousIsWhitespace && nextIsWhitespace) {
                    let operand = String(source[segmentStart..<cursor])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !operand.isEmpty else {
                        cursor = next
                        continue
                    }
                    operands.append(operand)
                    operators.append(character)
                    segmentStart = next
                }
            }
            cursor = source.index(after: cursor)
        }
        guard !operators.isEmpty else { return ([], []) }
        let final = String(source[segmentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { return nil }
        operands.append(final)
        return operands.count == operators.count + 1 ? (operands, operators) : nil
    }

    /// `fit-content()`のsingle nonnegative length-percentage argumentを検証します。
    private static func isFitContentFunction(_ token: String) -> Bool {
        guard let function = parsedValueFunction(token), function.name == "fit-content" else { return false }
        let arguments = splitTopLevelArguments(function.arguments)
        return arguments.count == 1
            && isLengthPercentageToken(arguments[0], allowNegative: false)
    }

    /// Grid track functionをarity、count、track breadthまで検証します。
    private static func isValidGridTrackFunction(_ token: String) -> Bool {
        guard let function = parsedValueFunction(token) else { return false }
        switch function.name {
        case "calc", "min", "max", "clamp":
            return isTypedNumericFunction(token, allowing: lengthPercentageNumericKinds)
        case "fit-content":
            return isFitContentFunction(token)
        case "minmax":
            let arguments = splitTopLevelArguments(function.arguments)
            return arguments.count == 2
                && isGridTrackBreadth(arguments[0], allowsFlex: false)
                && isGridTrackBreadth(arguments[1], allowsFlex: true)
        case "repeat":
            let arguments = splitTopLevelArguments(function.arguments)
            guard arguments.count == 2 else { return false }
            let countIsValid = (isCSSInteger(arguments[0]) && (Int(arguments[0]) ?? 0) > 0)
                || isSemanticIdentifier(arguments[0], in: ["auto-fill", "auto-fit"])
            return countIsValid
                && !arguments[1].isEmpty
                && !containsFunction(named: "repeat", in: arguments[1])
                && isGridTrackList(arguments[1], allowsTemplateKeywords: false)
        default:
            return false
        }
    }

    /// `minmax()`等で使うsingle track breadthを検証します。
    private static func isGridTrackBreadth(_ value: String, allowsFlex: Bool) -> Bool {
        let token = removingCSSCommentsForValidation(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard splitWhitespacePreservingFunctions(token).count == 1 else { return false }
        return isLengthPercentageToken(token, allowNegative: false)
            || (allowsFlex && isGridFractionToken(token))
            || isSemanticIdentifier(token, in: ["auto", "min-content", "max-content"])
            || isFitContentFunction(token)
    }

    /// 指定semantic名のbalanced functionが値内に存在するかを返します。
    private static func containsFunction(named expectedName: String, in source: String) -> Bool {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            if let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: cursor,
                upperBound: source.endIndex
            ), identifier.end < source.endIndex, source[identifier.end] == "(" {
                if identifier.value.caseInsensitiveCompare(expectedName) == .orderedSame { return true }
                cursor = identifier.end
            } else {
                cursor = source.index(after: cursor)
            }
        }
        return false
    }

    /// headless環境だけではcomputed値を断定できないenvironment/layout functionを検出します。
    private static func containsEnvironmentDependentFunction(in source: String) -> Bool {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return true }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: source, from: cursor)
                continue
            }
            if character == "\\" || OpenGraphiteCSSIdentifier.isNameCodePoint(character) {
                guard let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: source,
                    from: cursor,
                    upperBound: source.endIndex
                ) else {
                    cursor = next
                    continue
                }
                if identifier.end < source.endIndex, source[identifier.end] == "(",
                   let end = simpleBlockEnd(in: source, openingAt: identifier.end) {
                    let name = identifier.value.lowercased()
                    if ["env", "anchor", "anchor-size"].contains(name) { return true }
                    let start = source.index(after: identifier.end)
                    let finish = source.index(before: end)
                    if containsEnvironmentDependentFunction(in: String(source[start..<finish])) { return true }
                    cursor = end
                    continue
                }
                cursor = identifier.end
                continue
            }
            cursor = next
        }
        return false
    }

    /// Grid track listをline name、track sizing keyword、標準track functionへ照合します。
    private static func isGridTrackList(_ value: String, allowsTemplateKeywords: Bool) -> Bool {
        let tokens = splitWhitespacePreservingFunctions(value)
        guard !tokens.isEmpty else { return false }
        if tokens.count == 1, isSemanticIdentifier(tokens[0], in: ["none"]) { return allowsTemplateKeywords }
        let templateKeywords: Set<String> = ["subgrid", "masonry"]
        return tokens.allSatisfy { token in
            if token.first == "[", token.last == "]" { return hasBalancedSourceTokens(token) }
            if isLengthPercentageToken(token, allowNegative: false) { return true }
            if isGridFractionToken(token) { return true }
            if isSemanticIdentifier(token, in: ["auto", "min-content", "max-content"]) { return true }
            if allowsTemplateKeywords, isSemanticIdentifier(token, in: templateKeywords) { return true }
            return isValidGridTrackFunction(token)
        }
    }

    /// Grid専用の非負`fr` dimensionを検証します。
    private static func isGridFractionToken(_ token: String) -> Bool {
        let numberPattern = #"^[+]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#
        guard let numberRange = token.range(of: numberPattern, options: .regularExpression),
              numberRange.lowerBound == token.startIndex
        else { return false }
        let rawUnit = String(token[numberRange.upperBound...])
        return OpenGraphiteCSSIdentifier.decode(
            in: rawUnit,
            range: rawUnit.startIndex..<rawUnit.endIndex
        )?.lowercased() == "fr"
    }

    /// conditional candidateのexpandedまたはincomplete property集合を一貫して返します。
    private static func provenanceProperties(
        for declaration: OpenGraphiteCSSSourceDeclaration
    ) -> Set<String> {
        let expanded = Set(expandedProperties(for: declaration).map(\.0))
        return expanded.isEmpty ? incompleteProperties(for: declaration) : expanded
    }

    /// CSS-wide keywordとして単一identifier tokenをescape復号して返します。
    private static func cssWideKeyword(in value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = splitWhitespacePreservingFunctions(trimmed)
        guard tokens.count == 1,
              let token = tokens.first,
              let decoded = OpenGraphiteCSSIdentifier.decode(
                in: token,
                range: token.startIndex..<token.endIndex
              )?.lowercased(),
              cssWideKeywords.contains(decoded)
        else { return nil }
        return decoded
    }

    /// mask shorthandの各layerからimage tokenを保守的に抽出し、target検出用longhand値を返します。
    private static func maskImageValue(from value: String) -> String {
        splitTopLevel(value, delimiter: ",").map { layer in
            let tokens = splitWhitespacePreservingFunctions(layer)
            return tokens.first(where: { token in
                let normalized = token.lowercased()
                return normalized == "none"
                    || normalized.hasPrefix("url(")
                    || normalized.contains("gradient(")
                    || normalized.hasPrefix("image(")
                    || normalized.hasPrefix("image-set(")
                    || normalized.hasPrefix("cross-fade(")
                    || normalized.hasPrefix("element(")
                    || normalized.hasPrefix("var(")
            }) ?? "none"
        }.joined(separator: ", ")
    }

    /// quote、comment、escape、simple blockを保持し、指定delimiterのtop-level位置だけで値を分割します。
    private static func splitTopLevel(_ value: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var segmentStart = value.startIndex
        var cursor = value.startIndex
        var closers: [Character] = []
        while cursor < value.endIndex {
            let character = value[cursor]
            let next = value.index(after: cursor)
            if character == "/", next < value.endIndex, value[next] == "*" {
                guard let close = value[next...].range(of: "*/")?.upperBound else { break }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: value, from: cursor)
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: value, at: cursor, upperBound: value.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
            } else if character == delimiter, closers.isEmpty {
                result.append(
                    String(value[segmentStart..<cursor])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                segmentStart = next
            }
            cursor = next
        }
        result.append(
            String(value[segmentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return result.filter { !$0.isEmpty }
    }

    /// quote、comment、escape、simple blockを保持し、空引数を落とさずtop-level commaで分割します。
    private static func splitTopLevelArguments(_ value: String) -> [String] {
        var result: [String] = []
        var segmentStart = value.startIndex
        var cursor = value.startIndex
        var closers: [Character] = []
        while cursor < value.endIndex {
            let character = value[cursor]
            let next = value.index(after: cursor)
            if character == "/", next < value.endIndex, value[next] == "*" {
                guard let close = value[next...].range(of: "*/")?.upperBound else { return [] }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: value, from: cursor)
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: value, at: cursor, upperBound: value.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
            } else if character == ",", closers.isEmpty {
                result.append(
                    removingCSSCommentsForValidation(String(value[segmentStart..<cursor]))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                segmentStart = next
            }
            cursor = next
        }
        let final = removingCSSCommentsForValidation(String(value[segmentStart...]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty, final.isEmpty { return [] }
        result.append(final)
        return result
    }

    /// 検証時だけCSS commentを除き、authored sourceのserializerには影響させません。
    private static func removingCSSCommentsForValidation(_ source: String) -> String {
        var output = ""
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return output }
                output.append(" ")
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                let end = quotedStringEnd(in: source, from: cursor)
                output.append(contentsOf: source[cursor..<end])
                cursor = end
                continue
            }
            if character == "\\" {
                let end = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                output.append(contentsOf: source[cursor..<end])
                cursor = end
                continue
            }
            output.append(character)
            cursor = next
        }
        return output
    }

    /// property value外周のdeclaration injection tokenを拒否し、block/string内tokenは保持します。
    private static func hasSafePropertyValueBoundary(_ source: String) -> Bool {
        var cursor = source.startIndex
        var closers: [Character] = []
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return false }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                let end = quotedStringEnd(in: source, from: cursor)
                guard end <= source.endIndex else { return false }
                cursor = end
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
            } else if closers.isEmpty, character == ";" || character == "!" {
                return false
            }
            cursor = next
        }
        return closers.isEmpty
    }

    /// 値内の全`var()`がsemantic custom property名を持つことを確認します。
    private static func hasValidVariableFunctions(in source: String) -> Bool {
        var cursor = source.startIndex
        var found = false
        while let function = nextVariableFunction(in: source, from: cursor) {
            found = true
            guard function.name != nil else { return false }
            if let fallback = function.fallback,
               containsVariableFunction(in: fallback),
               !hasValidVariableFunctions(in: fallback) {
                return false
            }
            cursor = function.range.upperBound
        }
        return found
    }

    private static func boxValues(_ value: String) -> [String] {
        let values = splitWhitespacePreservingFunctions(value)
        switch values.count {
        case 1: return [values[0], values[0], values[0], values[0]]
        case 2: return [values[0], values[1], values[0], values[1]]
        case 3: return [values[0], values[1], values[2], values[1]]
        default: return Array(values.prefix(4)) + Array(repeating: "", count: max(4 - values.count, 0))
        }
    }

    private static func splitWhitespacePreservingFunctions(_ value: String) -> [String] {
        var result: [String] = []
        var tokenStart: String.Index?
        var cursor = value.startIndex
        var closers: [Character] = []
        while cursor < value.endIndex {
            let character = value[cursor]
            let next = value.index(after: cursor)
            if character == "/", next < value.endIndex, value[next] == "*" {
                if closers.isEmpty, let start = tokenStart {
                    result.append(String(value[start..<cursor]))
                    tokenStart = nil
                } else if !closers.isEmpty {
                    tokenStart = tokenStart ?? cursor
                }
                guard let close = value[next...].range(of: "*/")?.upperBound else {
                    cursor = value.endIndex
                    continue
                }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                tokenStart = tokenStart ?? cursor
                cursor = quotedStringEnd(in: value, from: cursor)
                continue
            }
            if character == "\\" {
                tokenStart = tokenStart ?? cursor
                cursor = escapeEnd(in: value, at: cursor, upperBound: value.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                tokenStart = tokenStart ?? cursor
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
            } else if OpenGraphiteCSSIdentifier.isCSSWhitespace(character), closers.isEmpty {
                if let start = tokenStart {
                    result.append(String(value[start..<cursor]))
                    tokenStart = nil
                }
                cursor = next
                continue
            } else {
                tokenStart = tokenStart ?? cursor
            }
            cursor = next
        }
        if let tokenStart { result.append(String(value[tokenStart...])) }
        return result
    }

    /// 論理名（日本語）: CSS custom property参照解決関数
    /// 処理概要: authored value内の`var()`を、継承済みcustom property辞書で再帰的に解決します。
    ///
    /// - Parameters:
    ///   - value: 解決対象のauthored CSS value。
    ///   - customProperties: elementで有効なcustom propertyのcomputed辞書。
    /// - Returns: 解決可能な`var()`を置換した値。未解決参照はauthored表現を保持します。
    static func resolvingVariables(in value: String, customProperties: [String: String]) -> String {
        resolveVariables(in: value, customProperties: customProperties)
    }

    private struct CSSValueResolution {
        var value: String
        var fullyResolved: Bool
    }

    private struct CSSVariableFunction {
        var range: Range<String.Index>
        var name: String?
        var fallback: String?
    }

    private static func resolveVariables(in value: String, customProperties: [String: String]) -> String {
        resolveCSSValue(
            value,
            customProperties: customProperties,
            resolving: [],
            depth: 0
        ).value
    }

    /// authored value内にbalancedな`var()` functionが存在するかを返します。
    private static func containsVariableFunction(in value: String) -> Bool {
        nextVariableFunction(in: value, from: value.startIndex) != nil
    }

    /// balanced `var()`を順に解決し、未解決参照をauthored表現のまま保持します。
    private static func resolveCSSValue(
        _ value: String,
        customProperties: [String: String],
        resolving: Set<String>,
        depth: Int
    ) -> CSSValueResolution {
        guard depth < 32 else {
            return CSSValueResolution(value: value, fullyResolved: false)
        }
        var output = ""
        var cursor = value.startIndex
        var fullyResolved = true
        while let function = nextVariableFunction(in: value, from: cursor) {
            output.append(contentsOf: value[cursor..<function.range.lowerBound])
            if let replacement = resolveVariableFunction(
                function,
                customProperties: customProperties,
                resolving: resolving,
                depth: depth + 1
            ) {
                output.append(replacement.value)
                fullyResolved = fullyResolved && replacement.fullyResolved
            } else {
                output.append(contentsOf: value[function.range])
                fullyResolved = false
            }
            cursor = function.range.upperBound
        }
        output.append(contentsOf: value[cursor...])
        return CSSValueResolution(value: output, fullyResolved: fullyResolved)
    }

    /// custom property値またはfallbackをcycle guard付きで解決します。
    private static func resolveVariableFunction(
        _ function: CSSVariableFunction,
        customProperties: [String: String],
        resolving: Set<String>,
        depth: Int
    ) -> CSSValueResolution? {
        func resolvedFallback() -> CSSValueResolution? {
            guard let fallback = function.fallback else { return nil }
            return resolveCSSValue(
                fallback,
                customProperties: customProperties,
                resolving: resolving,
                depth: depth
            )
        }

        guard let name = function.name else { return nil }
        guard !resolving.contains(name), let authoredValue = customProperties[name] else {
            return resolvedFallback()
        }
        var nextResolving = resolving
        nextResolving.insert(name)
        let resolvedValue = resolveCSSValue(
            authoredValue,
            customProperties: customProperties,
            resolving: nextResolving,
            depth: depth
        )
        return resolvedValue.fullyResolved ? resolvedValue : resolvedFallback()
    }

    /// quote/comment/simple blockを飛ばし、次のbalanced `var()`全体を返します。
    private static func nextVariableFunction(
        in value: String,
        from start: String.Index
    ) -> CSSVariableFunction? {
        var cursor = start
        while cursor < value.endIndex {
            let character = value[cursor]
            let next = value.index(after: cursor)
            if character == "/", next < value.endIndex, value[next] == "*" {
                guard let close = value[next...].range(of: "*/")?.upperBound else { return nil }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: value, from: cursor)
                continue
            }
            if OpenGraphiteCSSIdentifier.isNameCodePoint(character) || character == "\\" {
                guard let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: value,
                    from: cursor,
                    upperBound: value.endIndex
                ) else {
                    cursor = next
                    continue
                }
                guard identifier.value.caseInsensitiveCompare("var") == .orderedSame,
                      identifier.end < value.endIndex,
                      value[identifier.end] == "(",
                      let functionEnd = simpleBlockEnd(
                          in: value,
                          openingAt: identifier.end
                      )
                else {
                    cursor = identifier.end
                    continue
                }
                let argumentStart = value.index(after: identifier.end)
                let argumentEnd = value.index(before: functionEnd)
                let argumentRange = argumentStart..<argumentEnd
                let comma = topLevelComma(in: value, range: argumentRange)
                let nameRange = argumentStart..<(comma ?? argumentEnd)
                let fallback: String?
                if let comma {
                    let fallbackStart = value.index(after: comma)
                    fallback = String(value[fallbackStart..<argumentEnd])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    fallback = nil
                }
                return CSSVariableFunction(
                    range: cursor..<functionEnd,
                    name: semanticCustomPropertyName(in: value, range: nameRange),
                    fallback: fallback
                )
            }
            cursor = next
        }
        return nil
    }

    /// `var()`第1引数を単一のdecoded custom property identifierへ正規化します。
    private static func semanticCustomPropertyName(
        in source: String,
        range: Range<String.Index>
    ) -> String? {
        let start = skipCSSTrivia(in: source, from: range.lowerBound, upperBound: range.upperBound)
        guard let identifier = OpenGraphiteCSSIdentifier.consume(
            in: source,
            from: start,
            upperBound: range.upperBound
        ) else { return nil }
        let end = skipCSSTrivia(in: source, from: identifier.end, upperBound: range.upperBound)
        guard end == range.upperBound,
              identifier.value.hasPrefix("--"),
              identifier.value.count > 2
        else { return nil }
        return identifier.value
    }

    /// simple block内の最初のtop-level commaを返します。
    private static func topLevelComma(
        in source: String,
        range: Range<String.Index>
    ) -> String.Index? {
        var cursor = range.lowerBound
        var closers: [Character] = []
        while cursor < range.upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < range.upperBound, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound,
                      close <= range.upperBound
                else { return nil }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: source, from: cursor, upperBound: range.upperBound)
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: range.upperBound)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
            } else if character == ",", closers.isEmpty {
                return cursor
            }
            cursor = next
        }
        return nil
    }

    /// opening tokenに対応するbalanced simple block終端を返します。
    private static func simpleBlockEnd(
        in source: String,
        openingAt opening: String.Index
    ) -> String.Index? {
        guard let outerCloser = simpleBlockCloser(for: source[opening]) else { return nil }
        var closers = [outerCloser]
        var cursor = source.index(after: opening)
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return nil }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: source, from: cursor)
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if closers.last == character {
                closers.removeLast()
                if closers.isEmpty { return next }
            }
            cursor = next
        }
        return nil
    }

    /// quoteと内部escapeを消費した直後のindexを返します。
    private static func quotedStringEnd(
        in source: String,
        from opening: String.Index,
        upperBound: String.Index? = nil
    ) -> String.Index {
        let limit = upperBound ?? source.endIndex
        let quote = source[opening]
        var cursor = source.index(after: opening)
        while cursor < limit {
            if source[cursor] == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: limit)
                continue
            }
            let character = source[cursor]
            cursor = source.index(after: cursor)
            if character == quote { return cursor }
        }
        return limit
    }

    /// CSS whitespace/commentを指定範囲内で読み飛ばします。
    private static func skipCSSTrivia(
        in source: String,
        from start: String.Index,
        upperBound: String.Index
    ) -> String.Index {
        var cursor = start
        while cursor < upperBound {
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            let next = source.index(after: cursor)
            if source[cursor] == "/", next < upperBound, source[next] == "*",
               let close = source[next...].range(of: "*/")?.upperBound,
               close <= upperBound {
                cursor = close
                continue
            }
            break
        }
        return cursor
    }

    /// CSS simple block開始文字に対応する終端文字を返します。
    private static func simpleBlockCloser(for character: Character) -> Character? {
        switch character {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        default: return nil
        }
    }

    /// CSS escapeのauthored終端を返し、invalid escapeでも必ずscannerを前進させます。
    private static func escapeEnd(
        in source: String,
        at index: String.Index,
        upperBound: String.Index
    ) -> String.Index {
        if let escape = OpenGraphiteCSSIdentifier.consumeEscape(
            in: source,
            at: index,
            upperBound: upperBound
        ) {
            return escape.end
        }
        let escaped = source.index(after: index)
        guard escaped < upperBound else { return escaped }
        return source.index(after: escaped)
    }

    /// comment/string/escapeを除くCSS simple blockが正しく閉じるかを検査します。
    private static func hasBalancedSourceTokens(_ source: String) -> Bool {
        var cursor = source.startIndex
        var closers: [Character] = []
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return false }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                let end = quotedStringEnd(in: source, from: cursor)
                guard end > cursor,
                      end <= source.endIndex,
                      source.index(before: end) < source.endIndex,
                      source[source.index(before: end)] == character
                else { return false }
                cursor = end
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                continue
            }
            if let closer = simpleBlockCloser(for: character) {
                closers.append(closer)
            } else if [")", "]", "}"].contains(character) {
                guard closers.last == character else { return false }
                closers.removeLast()
            }
            cursor = next
        }
        return closers.isEmpty
    }

    /// comment/string/escape外の`@keyword` tokenをcase-insensitiveに検出します。
    private static func containsAtKeyword(_ expectedName: String, in source: String) -> Bool {
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < source.endIndex, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound else { return false }
                cursor = close
                continue
            }
            if character == "\"" || character == "'" {
                cursor = quotedStringEnd(in: source, from: cursor)
                continue
            }
            if character == "\\" {
                cursor = escapeEnd(in: source, at: cursor, upperBound: source.endIndex)
                continue
            }
            guard character == "@" else {
                cursor = next
                continue
            }
            let nameStart = next
            if let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: nameStart,
                upperBound: source.endIndex
            ), identifier.value.caseInsensitiveCompare(expectedName) == .orderedSame {
                return true
            }
            cursor = next
        }
        return false
    }
}

/// 論理名（日本語）: CSS selector評価器
/// 概要: 標準的な type、ID、class、attribute、descendant、child、主要疑似classを headless DOM 情報へ照合します。
enum OpenGraphiteCSSSelector {
    /// 論理名（日本語）: CSS selector一致判定関数
    /// 処理概要: selector を右端から評価し、ancestor combinator を含む一致可否を返します。
    ///
    /// - Parameters:
    ///   - selector: authored selector。
    ///   - element: 対象 DOM element。
    /// - Returns: selector が element に一致する場合は `true`。
    static func matches(_ selector: String, element: OpenGraphiteCSSDOMElement) -> Bool {
        let normalized = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        if let split = rightmostCombinator(in: normalized) {
            guard matchesCompound(split.right, element: element) else { return false }
            switch split.combinator {
            case ">":
                guard let parent = element.ancestors.first else { return false }
                return matches(split.left, element: parent)
            case "+":
                guard let sibling = element.previousSiblings.first else { return false }
                return matches(split.left, element: sibling)
            case "~":
                return element.previousSiblings.contains { matches(split.left, element: $0) }
            default:
                return element.ancestors.contains { matches(split.left, element: $0) }
            }
        }
        return matchesCompound(normalized, element: element)
    }

    /// 論理名（日本語）: CSS selector詳細度算出関数
    /// 処理概要: selector list の単一 selector について CSS specificity の三要素を数えます。
    ///
    /// - Parameter selector: authored selector。
    /// - Returns: ID、class、type の重み。
    static func specificity(of selector: String) -> OpenGraphiteCSSSpecificity {
        var result = OpenGraphiteCSSSpecificity.zero
        var index = selector.startIndex
        var expectsType = true
        while index < selector.endIndex {
            let character = selector[index]
            if let commentEnd = commentEnd(in: selector, at: index) {
                index = commentEnd
                continue
            } else if character == "#" {
                result.ids += 1
                index = consumeIdentifier(in: selector, after: index)
                expectsType = false
            } else if character == "." || character == "[" {
                result.classes += 1
                index = character == "[" ? consumeBalanced(in: selector, from: index, open: "[", close: "]") : consumeIdentifier(in: selector, after: index)
                expectsType = false
            } else if character == ":" {
                let next = selector.index(after: index)
                if next < selector.endIndex, selector[next] == ":" {
                    result.types += 1
                    index = consumeIdentifier(in: selector, after: next)
                } else {
                    let nameEnd = consumeIdentifier(in: selector, after: index)
                    let name = decodedIdentifier(
                        in: selector,
                        range: selector.index(after: index)..<nameEnd
                    )?.lowercased() ?? ""
                    if nameEnd < selector.endIndex, selector[nameEnd] == "(" {
                        let end = consumeBalanced(in: selector, from: nameEnd, open: "(", close: ")")
                        let argumentStart = selector.index(after: nameEnd)
                        let argumentEnd = selector.index(before: end)
                        let argument = argumentStart <= argumentEnd ? String(selector[argumentStart..<argumentEnd]) : ""
                        if name == "is" || name == "not" || name == "has" {
                            let maximum = splitSelectorList(argument).map(specificity).max() ?? .zero
                            result = result + maximum
                        } else if name != "where" {
                            result.classes += 1
                        }
                        index = end
                    } else {
                        result.classes += 1
                        index = nameEnd
                    }
                }
                expectsType = false
            } else if character == ">" || character == "+" || character == "~"
                        || OpenGraphiteCSSIdentifier.isCSSWhitespace(character) || character == "," {
                expectsType = true
                index = selector.index(after: index)
            } else if character == "*" {
                expectsType = false
                index = selector.index(after: index)
            } else if expectsType && isIdentifierCharacter(character) {
                result.types += 1
                index = consumeIdentifierStartingAt(in: selector, index: index)
                expectsType = false
            } else {
                index = selector.index(after: index)
            }
        }
        return result
    }

    /// 論理名（日本語）: CSS selector list分割関数
    /// 処理概要: quote、comment、simple block内のcommaを保持し、top-level commaだけでselector listを分割します。
    ///
    /// - Parameter source: authored selector list。
    /// - Returns: source順の個別selector。
    static func splitSelectorList(_ source: String) -> [String] {
        splitTopLevel(source, delimiter: ",")
    }

    /// 論理名（日本語）: Headless selector対応判定関数
    /// 処理概要: 実装済みDOM文脈だけでwinnerを確定できるselectorかをtoken-awareに判定します。
    ///
    /// - Parameter selector: authored selector list中の単一selector。
    /// - Returns: sibling/structural selectorを含めheadless matcherで意味を失わず評価できる場合は`true`。
    static func isSupportedForHeadlessMatching(_ selector: String) -> Bool {
        let supportedSimplePseudos: Set<String> = [
            "root", "scope", "first-child", "last-child", "only-child",
            "first-of-type", "last-of-type", "only-of-type",
            "disabled", "enabled", "hover", "focus", "focus-visible", "focus-within",
            "active", "visited", "link", "checked", "indeterminate", "placeholder-shown",
            "required", "optional", "valid", "invalid", "in-range", "out-of-range",
            "read-only", "read-write", "target", "fullscreen", "open", "modal",
            "popover-open", "defined"
        ]
        let supportedFunctionalPseudos: Set<String> = [
            "not", "is", "where", "lang", "nth-child", "nth-last-child",
            "nth-of-type", "nth-last-of-type"
        ]
        var cursor = selector.startIndex
        while cursor < selector.endIndex {
            if let commentEnd = commentEnd(in: selector, at: cursor) {
                cursor = commentEnd
                continue
            }
            let character = selector[cursor]
            if character == "\\" {
                cursor = indexAfterCSSEscape(in: selector, at: cursor)
                continue
            }
            if character == "\"" || character == "'" {
                let quote = character
                cursor = selector.index(after: cursor)
                while cursor < selector.endIndex {
                    if selector[cursor] == "\\" {
                        cursor = indexAfterCSSEscape(in: selector, at: cursor)
                        continue
                    }
                    let current = selector[cursor]
                    cursor = selector.index(after: cursor)
                    if current == quote { break }
                }
                continue
            }
            if character == "&" { return false }
            if character == "|" {
                let next = selector.index(after: cursor)
                if next < selector.endIndex, selector[next] == "|" { return false }
            }
            guard character == ":" else {
                cursor = selector.index(after: cursor)
                continue
            }
            let nameStart = selector.index(after: cursor)
            guard nameStart < selector.endIndex, selector[nameStart] != ":" else { return false }
            let nameEnd = consumeIdentifierStartingAt(in: selector, index: nameStart)
            guard nameEnd > nameStart,
                  let name = decodedIdentifier(in: selector, range: nameStart..<nameEnd)?.lowercased()
            else { return false }
            if nameEnd < selector.endIndex, selector[nameEnd] == "(" {
                guard supportedFunctionalPseudos.contains(name) else { return false }
                let end = consumeBalanced(in: selector, from: nameEnd, open: "(", close: ")")
                guard end > nameEnd, selector.index(before: end) < selector.endIndex else { return false }
                let argumentStart = selector.index(after: nameEnd)
                let argumentEnd = selector.index(before: end)
                let argument = String(selector[argumentStart..<argumentEnd])
                if ["not", "is", "where"].contains(name),
                   !splitSelectorList(argument).allSatisfy({ isSupportedForHeadlessMatching($0) }) {
                    return false
                }
                if ["nth-child", "nth-last-child"].contains(name),
                   argument.range(
                    of: #"\s+of\s+"#,
                    options: [.regularExpression, .caseInsensitive]
                   ) != nil {
                    return false
                }
                cursor = end
            } else {
                guard supportedSimplePseudos.contains(name) else { return false }
                cursor = nameEnd
            }
        }
        return true
    }

    private static func matchesCompound(_ compound: String, element: OpenGraphiteCSSDOMElement) -> Bool {
        var index = compound.startIndex
        var consumedType = false
        var matchedToken = false
        while index < compound.endIndex {
            let character = compound[index]
            if let commentEnd = commentEnd(in: compound, at: index) {
                index = commentEnd
                continue
            }
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                index = compound.index(after: index)
                continue
            }
            if character == "*" {
                consumedType = true
                matchedToken = true
                index = compound.index(after: index)
                continue
            }
            if character == "#" {
                let end = consumeIdentifier(in: compound, after: index)
                guard let value = decodedIdentifier(
                    in: compound,
                    range: compound.index(after: index)..<end
                ) else { return false }
                guard element.id == value else { return false }
                consumedType = true
                matchedToken = true
                index = end
                continue
            }
            if character == "." {
                let end = consumeIdentifier(in: compound, after: index)
                guard let value = decodedIdentifier(
                    in: compound,
                    range: compound.index(after: index)..<end
                ) else { return false }
                guard element.classNames.contains(value) else { return false }
                consumedType = true
                matchedToken = true
                index = end
                continue
            }
            if character == "[" {
                let end = consumeBalanced(in: compound, from: index, open: "[", close: "]")
                guard end > index else { return false }
                let start = compound.index(after: index)
                let close = compound.index(before: end)
                guard matchesAttribute(String(compound[start..<close]), element: element) else { return false }
                consumedType = true
                matchedToken = true
                index = end
                continue
            }
            if character == ":" {
                let next = compound.index(after: index)
                if next < compound.endIndex, compound[next] == ":" { return false }
                let nameEnd = consumeIdentifier(in: compound, after: index)
                guard let name = decodedIdentifier(in: compound, range: next..<nameEnd)?.lowercased()
                else { return false }
                var argument: String?
                var end = nameEnd
                if nameEnd < compound.endIndex, compound[nameEnd] == "(" {
                    end = consumeBalanced(in: compound, from: nameEnd, open: "(", close: ")")
                    let argumentStart = compound.index(after: nameEnd)
                    let argumentEnd = compound.index(before: end)
                    argument = argumentStart <= argumentEnd ? String(compound[argumentStart..<argumentEnd]) : ""
                }
                guard matchesPseudo(name, argument: argument, element: element) else { return false }
                consumedType = true
                matchedToken = true
                index = end
                continue
            }
            if !consumedType && isIdentifierCharacter(character) {
                let end = consumeIdentifierStartingAt(in: compound, index: index)
                guard let name = decodedIdentifier(in: compound, range: index..<end)?.lowercased()
                else { return false }
                guard name == element.tagName else { return false }
                consumedType = true
                matchedToken = true
                index = end
                continue
            }
            return false
        }
        return matchedToken
    }

    private static func matchesAttribute(_ source: String, element: OpenGraphiteCSSDOMElement) -> Bool {
        guard let selector = parsedAttributeSelector(source),
              let actual = element.attributes[selector.name]
        else { return false }
        guard let operation = selector.operation,
              let expected = selector.value
        else { return true }
        let comparedActual: String
        let comparedExpected: String
        if selector.modifier == "i" {
            comparedActual = asciiLowercased(actual)
            comparedExpected = asciiLowercased(expected)
        } else {
            comparedActual = actual
            comparedExpected = expected
        }
        switch operation {
        case "=": return comparedActual == comparedExpected
        case "~=":
            return comparedActual.split(whereSeparator: isHTMLASCIIWhitespace)
                .contains(Substring(comparedExpected))
        case "|=":
            return comparedActual == comparedExpected
                || comparedActual.hasPrefix(comparedExpected + "-")
        case "^=": return comparedActual.hasPrefix(comparedExpected)
        case "$=": return comparedActual.hasSuffix(comparedExpected)
        case "*=": return comparedActual.contains(comparedExpected)
        default: return false
        }
    }

    fileprivate struct CSSAttributeSelector {
        var name: String
        var operation: String?
        var value: String?
        var modifier: String?
    }

    /// attribute selectorをcomment/escape awareな単一token経路で意味解析します。
    fileprivate static func parsedAttributeSelector(_ source: String) -> CSSAttributeSelector? {
        var cursor = skipSelectorTrivia(in: source, from: source.startIndex, upperBound: source.endIndex)
        guard let name = OpenGraphiteCSSIdentifier.consume(
            in: source,
            from: cursor,
            upperBound: source.endIndex
        ) else { return nil }
        cursor = skipSelectorTrivia(in: source, from: name.end, upperBound: source.endIndex)
        let normalizedName = name.value.lowercased()
        guard !normalizedName.isEmpty else { return nil }
        if cursor == source.endIndex {
            return CSSAttributeSelector(
                name: normalizedName,
                operation: nil,
                value: nil,
                modifier: nil
            )
        }

        let operatorStart = cursor
        let first = source[cursor]
        cursor = source.index(after: cursor)
        let operation: String
        if first == "=" {
            operation = "="
        } else if ["~", "|", "^", "$", "*"].contains(first),
                  cursor < source.endIndex,
                  source[cursor] == "=" {
            operation = String(source[operatorStart...cursor])
            cursor = source.index(after: cursor)
        } else {
            return nil
        }

        cursor = skipSelectorTrivia(in: source, from: cursor, upperBound: source.endIndex)
        let value: String
        if cursor < source.endIndex,
           (source[cursor] == "\"" || source[cursor] == "'") {
            guard let string = decodedAttributeString(in: source, openingAt: cursor) else { return nil }
            value = string.value
            cursor = string.end
        } else {
            guard let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: cursor,
                upperBound: source.endIndex
            ) else { return nil }
            value = identifier.value
            cursor = identifier.end
        }

        cursor = skipSelectorTrivia(in: source, from: cursor, upperBound: source.endIndex)
        var modifier: String?
        if cursor < source.endIndex {
            guard let identifier = OpenGraphiteCSSIdentifier.consume(
                in: source,
                from: cursor,
                upperBound: source.endIndex
            ) else { return nil }
            let normalizedModifier = identifier.value.lowercased()
            guard normalizedModifier == "i" || normalizedModifier == "s" else { return nil }
            modifier = normalizedModifier
            cursor = skipSelectorTrivia(
                in: source,
                from: identifier.end,
                upperBound: source.endIndex
            )
        }
        guard cursor == source.endIndex else { return nil }
        return CSSAttributeSelector(
            name: normalizedName,
            operation: operation,
            value: value,
            modifier: modifier
        )
    }

    /// quoted attribute valueをCSS string escape込みでsemantic文字列へ復号します。
    private static func decodedAttributeString(
        in source: String,
        openingAt opening: String.Index
    ) -> (value: String, end: String.Index)? {
        let quote = source[opening]
        var cursor = source.index(after: opening)
        var value = ""
        while cursor < source.endIndex {
            let character = source[cursor]
            if character == quote {
                return (value, source.index(after: cursor))
            }
            if character == "\\" {
                guard let escape = OpenGraphiteCSSIdentifier.consumeEscape(
                    in: source,
                    at: cursor,
                    upperBound: source.endIndex
                ) else { return nil }
                value.append(contentsOf: escape.value)
                cursor = escape.end
                continue
            }
            guard character != "\n" && character != "\r" && character != "\u{000C}" else {
                return nil
            }
            value.append(character)
            cursor = source.index(after: cursor)
        }
        return nil
    }

    /// selector token間のCSS whitespace/commentをsemantic比較から除外します。
    private static func skipSelectorTrivia(
        in source: String,
        from start: String.Index,
        upperBound: String.Index
    ) -> String.Index {
        var cursor = start
        while cursor < upperBound {
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            if let end = commentEnd(in: source, at: cursor, upperBound: upperBound) {
                cursor = end
                continue
            }
            break
        }
        return cursor
    }

    /// CSS attribute selectorの`i` modifier用にASCII英大文字だけをfoldします。
    private static func asciiLowercased(_ value: String) -> String {
        String(value.unicodeScalars.map { scalar -> Character in
            if (65...90).contains(scalar.value),
               let lowercased = UnicodeScalar(scalar.value + 32) {
                return Character(lowercased)
            }
            return Character(scalar)
        })
    }

    private static func matchesPseudo(_ name: String, argument: String?, element: OpenGraphiteCSSDOMElement) -> Bool {
        switch name {
        case "root": return element.isRoot
        case "scope": return true
        case "first-child": return element.childIndex == 1
        case "last-child": return element.childIndex == element.childCount
        case "only-child": return element.childCount == 1
        case "first-of-type": return element.typeIndex == 1
        case "last-of-type": return element.typeIndex == element.typeCount
        case "only-of-type": return element.typeCount == 1
        case "nth-child":
            return argument.map {
                matchesNthExpression($0, position: element.childIndex, count: element.childCount)
            } ?? false
        case "nth-last-child":
            return argument.map {
                matchesNthExpression(
                    $0,
                    position: element.childCount - element.childIndex + 1,
                    count: element.childCount
                )
            } ?? false
        case "nth-of-type":
            return argument.map {
                matchesNthExpression($0, position: element.typeIndex, count: element.typeCount)
            } ?? false
        case "nth-last-of-type":
            return argument.map {
                matchesNthExpression(
                    $0,
                    position: element.typeCount - element.typeIndex + 1,
                    count: element.typeCount
                )
            } ?? false
        case "lang":
            let requested = (argument ?? "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\"'"))
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            return !requested.isEmpty && (element.language == requested || element.language.hasPrefix(requested + "-"))
        case "not": return !(argument.map { splitSelectorList($0).contains { matches($0, element: element) } } ?? false)
        case "is", "where": return argument.map { splitSelectorList($0).contains { matches($0, element: element) } } ?? false
        case "host":
            guard element.tagName.contains("-") else { return false }
            return argument.map { matchesCompound($0, element: element) } ?? true
        case "disabled":
            return element.attributes.keys.contains("disabled") || element.attributes["aria-disabled"] == "true"
        case "enabled":
            return !element.attributes.keys.contains("disabled") && element.attributes["aria-disabled"] != "true"
        default:
            return element.pseudoClasses.contains(name)
        }
    }

    /// `an+b`、odd/even、整数のstructural pseudo式を指定positionへ照合します。
    private static func matchesNthExpression(_ source: String, position: Int, count: Int) -> Bool {
        guard position > 0, position <= count else { return false }
        let normalized = source
            .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
            .filter { !OpenGraphiteCSSIdentifier.isCSSWhitespace($0) }
            .lowercased()
        if normalized == "odd" { return position % 2 == 1 }
        if normalized == "even" { return position % 2 == 0 }
        if let exact = Int(normalized) { return exact == position }
        guard let nIndex = normalized.firstIndex(of: "n") else { return false }
        let aSource = String(normalized[..<nIndex])
        let bSource = String(normalized[normalized.index(after: nIndex)...])
        let a: Int
        switch aSource {
        case "", "+": a = 1
        case "-": a = -1
        default:
            guard let value = Int(aSource) else { return false }
            a = value
        }
        let sentinel = Int.min
        let b = bSource.isEmpty ? 0 : (Int(bSource) ?? sentinel)
        guard b != sentinel else { return false }
        if a == 0 { return position == b }
        let delta = position - b
        return delta % a == 0 && delta / a >= 0
    }

    private static func rightmostCombinator(in selector: String) -> (left: String, combinator: Character, right: String)? {
        var depthRound = 0
        var depthSquare = 0
        var quote: Character?
        var candidate: (String.Index, Character)?
        var lastTopLevelSignificant: Character?
        var index = selector.startIndex
        while index < selector.endIndex {
            let character = selector[index]
            if let activeQuote = quote {
                if character == "\\" {
                    index = indexAfterCSSEscape(in: selector, at: index)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "\\" {
                if depthRound == 0 && depthSquare == 0 { lastTopLevelSignificant = "\\" }
                index = indexAfterCSSEscape(in: selector, at: index)
                continue
            } else if let commentEnd = commentEnd(in: selector, at: index) {
                index = commentEnd
                continue
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(" { depthRound += 1 }
            else if character == ")" { depthRound = max(depthRound - 1, 0) }
            else if character == "[" { depthSquare += 1 }
            else if character == "]" { depthSquare = max(depthSquare - 1, 0) }
            else if depthRound == 0 && depthSquare == 0 && [">", "+", "~"].contains(character) {
                candidate = (index, character)
            } else if depthRound == 0 && depthSquare == 0
                        && OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                let following = nextNonTriviaCharacter(
                    in: selector,
                    from: selector.index(after: index)
                )
                if let following,
                   lastTopLevelSignificant.map({ ![">", "+", "~"].contains($0) }) ?? true,
                   ![">", "+", "~"].contains(following) {
                    candidate = (index, " ")
                }
            }
            if depthRound == 0,
               depthSquare == 0,
               !OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                lastTopLevelSignificant = character
            }
            index = selector.index(after: index)
        }
        guard let candidate else { return nil }
        let left = String(selector[..<candidate.0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rightStart = selector.index(after: candidate.0)
        let right = String(selector[rightStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty, !right.isEmpty else { return nil }
        return (left, candidate.1, right)
    }

    private static func splitTopLevel(_ source: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var start = source.startIndex
        var index = source.startIndex
        var round = 0
        var square = 0
        var quote: Character?
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if character == "\\" {
                    index = indexAfterCSSEscape(in: source, at: index)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "\\" {
                index = indexAfterCSSEscape(in: source, at: index)
                continue
            } else if let commentEnd = commentEnd(in: source, at: index) {
                index = commentEnd
                continue
            } else if character == "\"" || character == "'" { quote = character }
            else if character == "(" { round += 1 }
            else if character == ")" { round = max(round - 1, 0) }
            else if character == "[" { square += 1 }
            else if character == "]" { square = max(square - 1, 0) }
            else if character == delimiter && round == 0 && square == 0 {
                result.append(String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines))
                start = source.index(after: index)
            }
            index = source.index(after: index)
        }
        result.append(String(source[start...]).trimmingCharacters(in: .whitespacesAndNewlines))
        return result.filter { !$0.isEmpty }
    }

    private static func consumeIdentifier(in source: String, after marker: String.Index) -> String.Index {
        consumeIdentifierStartingAt(in: source, index: source.index(after: marker))
    }

    private static func consumeIdentifierStartingAt(in source: String, index: String.Index) -> String.Index {
        OpenGraphiteCSSIdentifier.consume(
            in: source,
            from: index,
            upperBound: source.endIndex
        )?.end ?? index
    }

    private static func decodedIdentifier(
        in source: String,
        range: Range<String.Index>
    ) -> String? {
        OpenGraphiteCSSIdentifier.decode(in: source, range: range)
    }

    private static func consumeBalanced(
        in source: String,
        from start: String.Index,
        open: Character,
        close: Character
    ) -> String.Index {
        var cursor = start
        var depth = 0
        var quote: Character?
        while cursor < source.endIndex {
            let character = source[cursor]
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(in: source, at: cursor)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "\\" {
                cursor = indexAfterCSSEscape(in: source, at: cursor)
                continue
            } else if let commentEnd = commentEnd(in: source, at: cursor) {
                cursor = commentEnd
                continue
            } else if character == "\"" || character == "'" { quote = character }
            else if character == open { depth += 1 }
            else if character == close {
                depth -= 1
                if depth == 0 { return source.index(after: cursor) }
            }
            cursor = source.index(after: cursor)
        }
        return source.endIndex
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        OpenGraphiteCSSIdentifier.isNameCodePoint(character) || character == "\\"
    }

    private static func indexAfterCSSEscape(in source: String, at index: String.Index) -> String.Index {
        if let escape = OpenGraphiteCSSIdentifier.consumeEscape(
            in: source,
            at: index,
            upperBound: source.endIndex
        ) {
            return escape.end
        }
        let escaped = source.index(after: index)
        guard escaped < source.endIndex else { return escaped }
        return source.index(after: escaped)
    }

    /// selector scannerがcomment tokenを読み飛ばすため、そのauthored終端を返します。
    private static func commentEnd(
        in source: String,
        at index: String.Index,
        upperBound: String.Index? = nil
    ) -> String.Index? {
        let limit = upperBound ?? source.endIndex
        let next = source.index(after: index)
        guard source[index] == "/", next < limit, source[next] == "*" else { return nil }
        return source[next..<limit].range(of: "*/")?.upperBound ?? limit
    }

    /// whitespace/commentを除く次のselector code pointを返し、escaped code pointは通常tokenとして扱います。
    private static func nextNonTriviaCharacter(
        in source: String,
        from start: String.Index
    ) -> Character? {
        var cursor = start
        while cursor < source.endIndex {
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            if let commentEnd = commentEnd(in: source, at: cursor) {
                cursor = commentEnd
                continue
            }
            return source[cursor] == "\\" ? "\\" : source[cursor]
        }
        return nil
    }
}

/// 論理名（日本語）: CSS source parser
/// 概要: source を再構築せず、style rule と declaration の offset index を生成します。
private struct OpenGraphiteCSSSourceParser {
    let source: String
    var ruleOrder = 0
    var declarationOrder = 0

    /// 論理名（日本語）: CSS source rule解析関数
    /// 処理概要: stylesheet全体を走査し、lossless source range付きstyle ruleを返します。
    ///
    /// - Returns: source順のstyle rule一覧。
    mutating func parse() -> [OpenGraphiteCSSSourceRule] {
        parseRules(in: source.startIndex..<source.endIndex, contexts: [])
    }

    private mutating func parseRules(
        in range: Range<String.Index>,
        contexts: [OpenGraphiteCSSAtRuleContext]
    ) -> [OpenGraphiteCSSSourceRule] {
        var rules: [OpenGraphiteCSSSourceRule] = []
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            cursor = skipWhitespaceAndComments(from: cursor, upperBound: range.upperBound)
            guard cursor < range.upperBound,
                  let boundary = nextBoundary(from: cursor, upperBound: range.upperBound)
            else { break }
            if boundary.character == ";" {
                cursor = source.index(after: boundary.index)
                continue
            }
            if boundary.character == "}" { break }
            guard boundary.character == "{",
                  let close = matchingCloseBrace(open: boundary.index, upperBound: range.upperBound)
            else { break }
            let prelude = String(source[cursor..<boundary.index]).trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyStart = source.index(after: boundary.index)
            let bodyRange = bodyStart..<close
            if prelude.hasPrefix("@") {
                let atRule = parseAtRule(prelude)
                if ["media", "supports", "layer", "container", "scope", "document"].contains(atRule.name) {
                    rules.append(contentsOf: parseRules(in: bodyRange, contexts: contexts + [atRule]))
                }
            } else if !prelude.isEmpty {
                let declarations = parseDeclarations(in: bodyRange)
                rules.append(
                    OpenGraphiteCSSSourceRule(
                        selectorText: prelude,
                        selectors: OpenGraphiteCSSSelector.splitSelectorList(prelude),
                        declarations: declarations,
                        atRules: contexts,
                        range: source.offset(of: cursor)..<source.offset(of: source.index(after: close)),
                        bodyRange: source.offset(of: bodyStart)..<source.offset(of: close),
                        sourceOrder: ruleOrder
                    )
                )
                ruleOrder += 1
            }
            cursor = source.index(after: close)
        }
        return rules
    }

    private mutating func parseDeclarations(in range: Range<String.Index>) -> [OpenGraphiteCSSSourceDeclaration] {
        var declarations: [OpenGraphiteCSSSourceDeclaration] = []
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            cursor = skipWhitespaceAndComments(from: cursor, upperBound: range.upperBound)
            guard cursor < range.upperBound else { break }
            let boundary = declarationBoundary(from: cursor, upperBound: range.upperBound)
            let end = boundary.end
            let semicolonEnd = end < range.upperBound && source[end] == ";" ? source.index(after: end) : end
            let segment = source[cursor..<end]
            if let colon = boundary.colon,
               let normalizedName = semanticPropertyName(in: cursor..<colon) {
                let valueStart = skipWhitespaceAndComments(
                    from: source.index(after: colon),
                    upperBound: end
                )
                let priorityRange = importantPriorityRange(in: valueStart..<end)
                let valueUpperBound = priorityRange?.lowerBound ?? end
                let valueEnd = trimmingTrailingTrivia(
                    in: valueStart..<valueUpperBound
                ).upperBound
                let value = String(source[valueStart..<valueEnd])
                declarations.append(
                    OpenGraphiteCSSSourceDeclaration(
                        name: normalizedName,
                        value: value,
                        important: priorityRange != nil,
                        range: source.offset(of: cursor)..<source.offset(of: semicolonEnd),
                        valueRange: source.offset(of: valueStart)..<source.offset(of: valueEnd),
                        sourceOrder: declarationOrder
                    )
                )
                declarationOrder += 1
            } else if segment.contains("{") {
                // CSS nesting は lossless に保持し、未対応 selector scope は read-only とします。
            }
            cursor = semicolonEnd > cursor ? semicolonEnd : source.index(after: cursor)
        }
        return declarations
    }

    private func parseAtRule(_ prelude: String) -> OpenGraphiteCSSAtRuleContext {
        let trimmed = prelude.dropFirst()
        let name = trimmed.prefix { !OpenGraphiteCSSIdentifier.isCSSWhitespace($0) }.lowercased()
        let condition = trimmed.dropFirst(name.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return OpenGraphiteCSSAtRuleContext(name: name, prelude: condition)
    }

    private func nextBoundary(
        from start: String.Index,
        upperBound: String.Index
    ) -> (index: String.Index, character: Character)? {
        var cursor = start
        var round = 0
        var square = 0
        var quote: Character?
        var inComment = false
        while cursor < upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if inComment {
                if character == "*", next < upperBound, source[next] == "/" {
                    inComment = false
                    cursor = source.index(after: next)
                } else { cursor = next }
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "/", next < upperBound, source[next] == "*" {
                inComment = true
                cursor = source.index(after: next)
                continue
            } else if character == "\\" {
                cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                continue
            } else if character == "\"" || character == "'" { quote = character }
            else if character == "(" { round += 1 }
            else if character == ")" { round = max(round - 1, 0) }
            else if character == "[" { square += 1 }
            else if character == "]" { square = max(square - 1, 0) }
            else if round == 0 && square == 0 && (character == "{" || character == ";" || character == "}") {
                return (cursor, character)
            }
            cursor = next
        }
        return nil
    }

    private func matchingCloseBrace(open: String.Index, upperBound: String.Index) -> String.Index? {
        var cursor = source.index(after: open)
        var depth = 1
        var quote: Character?
        var inComment = false
        while cursor < upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if inComment {
                if character == "*", next < upperBound, source[next] == "/" {
                    inComment = false
                    cursor = source.index(after: next)
                } else { cursor = next }
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "/", next < upperBound, source[next] == "*" {
                inComment = true
                cursor = source.index(after: next)
                continue
            } else if character == "\\" {
                cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                continue
            } else if character == "\"" || character == "'" { quote = character }
            else if character == "{" { depth += 1 }
            else if character == "}" {
                depth -= 1
                if depth == 0 { return cursor }
            }
            cursor = next
        }
        return nil
    }

    /// 論理名（日本語）: CSS declaration境界解析関数
    /// 処理概要: quote、comment、`()[]{}` simple block、CSS escapeを追跡し、top-level colonとsemicolonだけをdeclaration境界として返します。
    ///
    /// - Parameters:
    ///   - start: declaration候補の開始位置。
    ///   - upperBound: style rule bodyの終端。
    /// - Returns: property/valueを分けるcolonと、declarationを終えるsemicolonまたはbody終端。
    private func declarationBoundary(
        from start: String.Index,
        upperBound: String.Index
    ) -> (colon: String.Index?, end: String.Index) {
        var cursor = start
        var colon: String.Index?
        var blockClosers: [Character] = []
        var quote: Character?
        var inComment = false
        while cursor < upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if inComment {
                if character == "*", next < upperBound, source[next] == "/" {
                    inComment = false
                    cursor = source.index(after: next)
                } else { cursor = next }
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "/", next < upperBound, source[next] == "*" {
                inComment = true
                cursor = source.index(after: next)
                continue
            } else if character == "\\" {
                cursor = indexAfterCSSEscape(at: cursor, upperBound: upperBound)
                continue
            } else if character == "\"" || character == "'" {
                quote = character
            } else if let closer = Self.simpleBlockCloser(for: character) {
                blockClosers.append(closer)
            } else if blockClosers.last == character {
                blockClosers.removeLast()
            } else if character == ":", blockClosers.isEmpty, colon == nil {
                colon = cursor
            } else if character == ";", blockClosers.isEmpty {
                return (colon, cursor)
            }
            cursor = next
        }
        return (colon, upperBound)
    }

    /// 論理名（日本語）: CSS property名意味正規化関数
    /// 処理概要: property名のcommentをCSS preprocessing同様に除き、前後triviaを無視しつつ内部whitespaceを持つ無効名を拒否します。
    ///
    /// - Parameter range: property名のauthored source範囲。
    /// - Returns: custom propertyではcaseを保ち、それ以外はlowercase化したsemantic property名。
    private func semanticPropertyName(in range: Range<String.Index>) -> String? {
        var cursor = range.lowerBound
        var name = ""
        var hasNameContent = false
        var hasPendingWhitespace = false
        while cursor < range.upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if character == "/", next < range.upperBound, source[next] == "*" {
                guard let close = source[next...].range(of: "*/")?.upperBound,
                      close <= range.upperBound
                else { return nil }
                if hasNameContent { hasPendingWhitespace = true }
                cursor = close
                continue
            }
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                if hasNameContent { hasPendingWhitespace = true }
                cursor = next
                continue
            }
            if hasPendingWhitespace { return nil }
            if character == "\\" {
                guard let escape = OpenGraphiteCSSIdentifier.consumeEscape(
                    in: source,
                    at: cursor,
                    upperBound: range.upperBound
                ) else { return nil }
                name.append(contentsOf: escape.value)
                cursor = escape.end
            } else if OpenGraphiteCSSIdentifier.isNameCodePoint(character) {
                name.append(character)
                cursor = next
            } else {
                return nil
            }
            hasNameContent = true
        }
        guard !name.isEmpty else { return nil }
        return name.hasPrefix("--") ? name : name.lowercased()
    }

    /// 論理名（日本語）: CSS important priority範囲解析関数
    /// 処理概要: value末尾のtop-level `!important`を、間のwhitespace/commentを許容して検出し、raw source範囲を保持します。
    ///
    /// - Parameter range: declaration valueからsemicolon直前までのsource範囲。
    /// - Returns: priority delimiterから末尾triviaまでの範囲。priorityがなければ`nil`。
    private func importantPriorityRange(in range: Range<String.Index>) -> Range<String.Index>? {
        var cursor = range.lowerBound
        var blockClosers: [Character] = []
        var quote: Character?
        var inComment = false
        while cursor < range.upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if inComment {
                if character == "*", next < range.upperBound, source[next] == "/" {
                    inComment = false
                    cursor = source.index(after: next)
                } else {
                    cursor = next
                }
                continue
            }
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(at: cursor, upperBound: range.upperBound)
                    continue
                }
                if character == activeQuote { quote = nil }
            } else if character == "/", next < range.upperBound, source[next] == "*" {
                inComment = true
                cursor = source.index(after: next)
                continue
            } else if character == "\\" {
                cursor = indexAfterCSSEscape(at: cursor, upperBound: range.upperBound)
                continue
            } else if character == "\"" || character == "'" {
                quote = character
            } else if let closer = Self.simpleBlockCloser(for: character) {
                blockClosers.append(closer)
            } else if blockClosers.last == character {
                blockClosers.removeLast()
            } else if character == "!", blockClosers.isEmpty {
                let identifierStart = skipWhitespaceAndComments(from: next, upperBound: range.upperBound)
                if let identifier = OpenGraphiteCSSIdentifier.consume(
                    in: source,
                    from: identifierStart,
                    upperBound: range.upperBound
                ),
                   identifier.value.caseInsensitiveCompare("important") == .orderedSame,
                   skipWhitespaceAndComments(from: identifier.end, upperBound: range.upperBound) == range.upperBound {
                    return cursor..<range.upperBound
                }
            }
            cursor = next
        }
        return nil
    }

    /// 論理名（日本語）: CSS末尾trivia除外関数
    /// 処理概要: value mutation範囲から末尾whitespace/commentだけを外し、priority周辺のauthored triviaを保持します。
    ///
    /// - Parameter range: priorityを除いたvalue候補範囲。
    /// - Returns: semantic value末尾までに縮めた範囲。
    private func trimmingTrailingTrivia(in range: Range<String.Index>) -> Range<String.Index> {
        var cursor = range.lowerBound
        var lastSignificantEnd = range.lowerBound
        var quote: Character?
        while cursor < range.upperBound {
            let character = source[cursor]
            let next = source.index(after: cursor)
            if let activeQuote = quote {
                if character == "\\" {
                    cursor = indexAfterCSSEscape(at: cursor, upperBound: range.upperBound)
                } else {
                    cursor = next
                    if character == activeQuote { quote = nil }
                }
                lastSignificantEnd = cursor
                continue
            }
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(character) {
                cursor = next
                continue
            }
            if character == "/", next < range.upperBound, source[next] == "*",
               let close = source[next...].range(of: "*/")?.upperBound,
               close <= range.upperBound {
                cursor = close
                continue
            }
            if character == "\\" {
                cursor = indexAfterCSSEscape(at: cursor, upperBound: range.upperBound)
            } else {
                cursor = next
                if character == "\"" || character == "'" { quote = character }
            }
            lastSignificantEnd = cursor
        }
        return range.lowerBound..<lastSignificantEnd
    }

    /// 論理名（日本語）: CSS simple block終端取得関数
    /// 処理概要: opening tokenに対応する`)`、`]`、`}`を返します。
    ///
    /// - Parameter character: lexerが読んだCSS code point。
    /// - Returns: simple block開始文字なら対応終端、それ以外は`nil`。
    private static func simpleBlockCloser(for character: Character) -> Character? {
        switch character {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        default: return nil
        }
    }

    /// 論理名（日本語）: CSS escape終端取得関数
    /// 処理概要: quote内外を問わずbackslashと直後のcode pointを一つのescaped unitとして読み飛ばします。
    ///
    /// - Parameters:
    ///   - index: backslash位置。
    ///   - upperBound: scanner範囲の終端。
    /// - Returns: escape unit直後のindex。
    private func indexAfterCSSEscape(at index: String.Index, upperBound: String.Index) -> String.Index {
        if let escape = OpenGraphiteCSSIdentifier.consumeEscape(
            in: source,
            at: index,
            upperBound: upperBound
        ) {
            return escape.end
        }
        let escaped = source.index(after: index)
        guard escaped < upperBound else { return escaped }
        return source.index(after: escaped)
    }

    private func skipWhitespaceAndComments(from start: String.Index, upperBound: String.Index) -> String.Index {
        var cursor = start
        while cursor < upperBound {
            if OpenGraphiteCSSIdentifier.isCSSWhitespace(source[cursor]) {
                cursor = source.index(after: cursor)
                continue
            }
            let next = source.index(after: cursor)
            if source[cursor] == "/", next < upperBound, source[next] == "*",
               let close = source[next...].range(of: "*/")?.upperBound {
                cursor = min(close, upperBound)
                continue
            }
            break
        }
        return cursor
    }
}

private extension String {
    /// 論理名（日本語）: 文字列offset変換関数
    /// 処理概要: 文字列indexを先頭からのoffsetへ変換します。
    ///
    /// - Parameter index: 変換する文字列index。
    /// - Returns: `startIndex`からのoffset。
    func offset(of index: String.Index) -> Int {
        distance(from: startIndex, to: index)
    }

    /// 論理名（日本語）: offset範囲部分文字列取得関数
    /// 処理概要: 先頭基準のoffset範囲に対応する部分文字列を返します。
    ///
    /// - Parameter offsetRange: 取得するoffset範囲。
    /// - Returns: 指定範囲の部分文字列。
    func substring(offsetRange: Range<Int>) -> String {
        let lower = index(startIndex, offsetBy: offsetRange.lowerBound)
        let upper = index(startIndex, offsetBy: offsetRange.upperBound)
        return String(self[lower..<upper])
    }

    /// 論理名（日本語）: offset範囲文字列置換関数
    /// 処理概要: 先頭基準のoffset範囲だけを指定文字列へ置換したcopyを返します。
    ///
    /// - Parameters:
    ///   - offsetRange: 置換するoffset範囲。
    ///   - replacement: 挿入する文字列。
    /// - Returns: 指定範囲を置換した文字列。
    func replacingCharacters(in offsetRange: Range<Int>, with replacement: String) -> String {
        var copy = self
        let lower = copy.index(copy.startIndex, offsetBy: offsetRange.lowerBound)
        let upper = copy.index(copy.startIndex, offsetBy: offsetRange.upperBound)
        copy.replaceSubrange(lower..<upper, with: replacement)
        return copy
    }

    /// 論理名（日本語）: offset位置文字列挿入関数
    /// 処理概要: 先頭基準のoffset位置へ指定文字列を挿入したcopyを返します。
    ///
    /// - Parameters:
    ///   - value: 挿入する文字列。
    ///   - offset: 挿入位置のoffset。
    /// - Returns: 指定値を挿入した文字列。
    func inserting(_ value: String, atOffset offset: Int) -> String {
        var copy = self
        let index = copy.index(copy.startIndex, offsetBy: offset)
        copy.insert(contentsOf: value, at: index)
        return copy
    }

    /// 論理名（日本語）: offset直前文字取得関数
    /// 処理概要: 先頭基準のoffset直前にある文字を安全に返します。
    ///
    /// - Parameter offset: 基準にするoffset。
    /// - Returns: 直前の文字。先頭位置の場合は`nil`。
    func character(beforeOffset offset: Int) -> Character? {
        guard offset > 0 else { return nil }
        return self[index(startIndex, offsetBy: offset - 1)]
    }

    /// 論理名（日本語）: 行インデント取得関数
    /// 処理概要: 指定offsetを含む行の先頭から位置直前までにある空白とtabを返します。
    ///
    /// - Parameter offset: 行を特定するoffset。
    /// - Returns: 指定位置の行インデント。
    func lineIndentation(atOffset offset: Int) -> String {
        let position = index(startIndex, offsetBy: offset)
        let lineStart = self[..<position].lastIndex(of: "\n").map { index(after: $0) } ?? startIndex
        return String(self[lineStart..<position].prefix { $0 == " " || $0 == "\t" })
    }
}
