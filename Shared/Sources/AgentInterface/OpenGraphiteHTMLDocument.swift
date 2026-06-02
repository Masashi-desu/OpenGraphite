import Foundation

/// 論理名（日本語）: OpenGraphite HTML文書
/// 概要: `data-og-id` と `data-og-internal-id` を持つ HTML ノードの抽出、検証、開始タグ単位の編集を担当します。
///
/// プロパティ:
/// - `html`: 対象 HTML 文字列。
struct OpenGraphiteHTMLDocument {
    var html: String

    /// 論理名（日本語）: ノード一覧抽出関数
    /// 処理概要: HTML を軽量に走査し、`data-og-id` を持つ開始タグを OpenGraphite ノードへ変換します。
    ///
    /// - Returns: DOM 出現順の OpenGraphite agent node 一覧。
    func nodes() -> [OpenGraphiteAgentNode] {
        var nodeStack: [(depth: Int, id: String)] = []
        return parsedTags().compactMap { tag in
            while let last = nodeStack.last, last.depth >= tag.depth {
                nodeStack.removeLast()
            }

            guard let id = tag.attributeValue(named: "data-og-id"), !id.isEmpty else {
                return nil
            }

            let node = OpenGraphiteAgentNode(
                id: id,
                internalID: tag.attributeValue(named: "data-og-internal-id") ?? "",
                tagName: tag.tagName,
                type: tag.attributeValue(named: "data-og-type") ?? "",
                layout: tag.emptyNilAttribute(named: "data-og-layout"),
                role: tag.emptyNilAttribute(named: "data-og-role"),
                cssVariables: OpenGraphiteCSSStyle.parse(tag.attributeValue(named: "style") ?? "").ogVariables(),
                hidden: tag.attributeValue(named: "data-og-hidden") == "true",
                locked: tag.attributeValue(named: "data-og-locked") == "true",
                depth: tag.depth,
                parentID: nodeStack.last?.id,
                textContent: textContent(for: tag),
                attributes: tag.attributeDictionary
            )

            if !tag.selfClosing && !Self.voidElementNames.contains(tag.tagName) {
                nodeStack.append((depth: tag.depth, id: id))
            }
            return node
        }
    }

    /// 論理名（日本語）: 内部ID補完HTML生成関数
    /// 処理概要: `data-og-id` を持つ要素へ、欠落または重複しない `data-og-internal-id` を補完します。
    ///
    /// - Returns: 内部 ID が補完された HTML。
    func ensuringInternalIDs() -> String {
        Self.ensuringInternalIDs(in: html, used: [])
    }

    /// 論理名（日本語）: 全開始タグ解析関数
    /// 処理概要: HTML の開始タグを走査し、属性、深度、文字範囲を保持した内部表現へ変換します。
    ///
    /// - Returns: HTML 内の開始タグ一覧。
    func parsedTags() -> [OpenGraphiteHTMLTag] {
        var tags: [OpenGraphiteHTMLTag] = []
        var stack: [String] = []
        var index = html.startIndex

        while let openIndex = html[index...].firstIndex(of: "<") {
            guard let closeIndex = findTagEnd(startingAt: html.index(after: openIndex)) else {
                break
            }

            let afterOpen = html.index(after: openIndex)
            let inner = String(html[afterOpen..<closeIndex])
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            let afterClose = html.index(after: closeIndex)

            if trimmed.hasPrefix("/") {
                let closingName = tagName(fromClosingTag: trimmed)
                if let matchIndex = stack.lastIndex(of: closingName) {
                    stack.removeSubrange(matchIndex..<stack.endIndex)
                }
                index = afterClose
                continue
            }

            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("?") {
                index = afterClose
                continue
            }

            let (rawName, attributeSource, selfClosing) = splitOpeningTag(trimmed)
            guard !rawName.isEmpty else {
                index = afterClose
                continue
            }

            let tagName = rawName.lowercased()
            let isVoid = Self.voidElementNames.contains(tagName)
            let tag = OpenGraphiteHTMLTag(
                range: html.distance(from: html.startIndex, to: openIndex)..<html.distance(from: html.startIndex, to: afterClose),
                rawTagName: rawName,
                tagName: tagName,
                attributes: Self.parseAttributes(attributeSource),
                depth: stack.count,
                selfClosing: selfClosing
            )
            tags.append(tag)

            if !selfClosing && !isVoid {
                stack.append(tagName)
            }

            index = afterClose
        }

        return tags
    }

    /// 論理名（日本語）: CSS変数設定関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードの inline style に `--og-*` CSS 変数を設定します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS 変数名。
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
        guard variable.hasPrefix("--og-") else {
            return .failure(
                html: html,
                diagnostic: OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "invalid-css-variable",
                    message: "\(variable) は --og-* CSS 変数ではありません。",
                    path: nil,
                    nodeID: id
                )
            )
        }

        if !contract.cssVariableSet.contains(variable) {
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

        var attributes = tag.attributes
        var style = OpenGraphiteCSSStyle.parse(tag.attributeValue(named: "style") ?? "")
        style.set(variable, value: value.trimmingCharacters(in: .whitespacesAndNewlines))

        if style.declarations.isEmpty {
            attributes.removeAll { $0.name == "style" }
        } else {
            Self.setAttribute("style", value: style.serialized(), in: &attributes)
        }

        sanitized.replaceRange(tag.range, with: tag.serialized(with: attributes))
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: ノード属性設定関数
    /// 処理概要: 一意な `data-og-internal-id` を持つノードの許可済み `data-og-*` 属性を設定します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 設定値。空の場合は属性を削除します。
    ///   - id: 対象ノードの `data-og-internal-id`。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: 更新済み HTML と diagnostics。
    func settingAttribute(
        name: String,
        value: String,
        forNodeID id: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        guard name != "data-og-id",
              name != "data-og-internal-id",
              contract.editableAttributeSet.contains(name)
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

        var attributes = tag.attributes
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedValue.isEmpty {
            attributes.removeAll { $0.name == name }
        } else {
            Self.setAttribute(name, value: normalizedValue, in: &attributes)
        }

        sanitized.replaceRange(tag.range, with: tag.serialized(with: attributes))
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

        let preparedFragmentHTML = Self.ensuringInternalIDs(
            in: boundaryTrimmedFragmentHTML,
            used: sanitizedDocument.internalIDSet()
        )
        Self.insertRawHTML(preparedFragmentHTML, into: &sanitized, relativeTo: element, position: position)
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

        let usedInternalIDs = sanitizedDocument.internalIDSet(excluding: element)
        let replacementHTML = Self.ensuringInternalIDs(
            in: boundaryTrimmedReplacementHTML,
            used: usedInternalIDs,
            preservingRootInternalID: element.tag.attributeValue(named: "data-og-internal-id")
        )
        sanitized.replaceRange(element.fullRange, with: replacementHTML)
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
        sanitized.replaceRange(sourceElement.fullRange, with: "")
        var withoutSource = sanitized
        let targetAfterRemoval = OpenGraphiteHTMLDocument(html: withoutSource).uniqueElement(forNodeID: targetID)
        guard let updatedTargetElement = targetAfterRemoval.element else {
            return OpenGraphiteHTMLMutationResult(html: withoutSource, diagnostics: targetAfterRemoval.diagnostics)
        }

        Self.insertRawHTML(movedHTML, into: &withoutSource, relativeTo: updatedTargetElement, position: position)
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

        let copiedHTML = Self.prefixingDataOGIDs(in: sanitized.substring(sourceElement.fullRange), prefix: idPrefix)
        Self.insertRawHTML(copiedHTML, into: &sanitized, relativeTo: targetElement, position: position)
        return OpenGraphiteHTMLMutationResult(html: sanitized, diagnostics: [])
    }

    /// 論理名（日本語）: 実行時状態削除関数
    /// 処理概要: `data-og-selected`、`data-og-editing`、編集補助 CSS 変数を正本 HTML から除去します。
    ///
    /// - Parameter contract: 実行時属性と CSS 変数を判定する契約。
    /// - Returns: 実行時状態を取り除いた HTML。
    func removingRuntimeState(contract: OpenGraphiteContract) -> String {
        var result = html
        for tag in parsedTags().reversed() {
            var attributes = tag.attributes
            let originalAttributes = attributes
            attributes.removeAll { contract.runtimeAttributeSet.contains($0.name) }

            if let styleIndex = attributes.firstIndex(where: { $0.name == "style" }) {
                var style = OpenGraphiteCSSStyle.parse(attributes[styleIndex].value)
                let originalStyle = style
                style.removeVariables(contract.runtimeCSSVariableSet)
                if style != originalStyle {
                    if style.declarations.isEmpty {
                        attributes.remove(at: styleIndex)
                    } else {
                        attributes[styleIndex].value = style.serialized()
                    }
                }
            }

            guard attributes != originalAttributes else { continue }
            result.replaceRange(tag.range, with: tag.serialized(with: attributes))
        }
        return result
    }

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

    private func element(for tag: OpenGraphiteHTMLTag) -> OpenGraphiteHTMLElement? {
        if tag.selfClosing || Self.voidElementNames.contains(tag.tagName) {
            return OpenGraphiteHTMLElement(tag: tag, contentRange: tag.range.upperBound..<tag.range.upperBound, fullRange: tag.range)
        }

        guard let closingRange = closingTagRange(for: tag) else {
            return nil
        }

        return OpenGraphiteHTMLElement(
            tag: tag,
            contentRange: tag.range.upperBound..<closingRange.lowerBound,
            fullRange: tag.range.lowerBound..<closingRange.upperBound
        )
    }

    private func closingTagRange(for tag: OpenGraphiteHTMLTag) -> Range<Int>? {
        var nestingDepth = 1
        var index = html.index(html.startIndex, offsetBy: tag.range.upperBound)

        while let openIndex = html[index...].firstIndex(of: "<") {
            guard let closeIndex = findTagEnd(startingAt: html.index(after: openIndex)) else {
                return nil
            }

            let afterOpen = html.index(after: openIndex)
            let inner = String(html[afterOpen..<closeIndex])
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            let afterClose = html.index(after: closeIndex)
            defer { index = afterClose }

            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("?") {
                continue
            }

            if trimmed.hasPrefix("/") {
                let closingName = tagName(fromClosingTag: trimmed)
                guard closingName == tag.tagName else { continue }
                nestingDepth -= 1
                if nestingDepth == 0 {
                    return html.distance(from: html.startIndex, to: openIndex)..<html.distance(from: html.startIndex, to: afterClose)
                }
                continue
            }

            let (rawName, _, selfClosing) = splitOpeningTag(trimmed)
            let tagName = rawName.lowercased()
            if tagName == tag.tagName && !selfClosing && !Self.voidElementNames.contains(tagName) {
                nestingDepth += 1
            }
        }

        return nil
    }

    private func textContent(for tag: OpenGraphiteHTMLTag) -> String? {
        guard let element = element(for: tag),
              element.contentRange.lowerBound < element.contentRange.upperBound else {
            return nil
        }

        var text = html.substring(element.contentRange)
        while let openIndex = text.firstIndex(of: "<"),
              let closeIndex = Self.findTagEnd(in: text, startingAt: text.index(after: openIndex)) {
            text.replaceSubrange(openIndex...closeIndex, with: "")
        }

        let collapsed = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
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

    private func internalIDSet(excluding element: OpenGraphiteHTMLElement? = nil) -> Set<String> {
        Set(parsedTags().compactMap { tag in
            if let element, element.fullRange.contains(tag.range.lowerBound) {
                return nil
            }
            let internalID = tag.attributeValue(named: "data-og-internal-id") ?? ""
            return internalID.isEmpty ? nil : internalID
        })
    }

    private static func ensuringInternalIDs(
        in fragmentHTML: String,
        used existingIDs: Set<String>,
        preservingRootInternalID: String? = nil
    ) -> String {
        var result = fragmentHTML
        var used = existingIDs
        let document = OpenGraphiteHTMLDocument(html: fragmentHTML)
        let tags = document.parsedTags()
        let rootRange = tags.first { tag in
            tag.attributeValue(named: "data-og-id") != nil
        }?.range

        for tag in tags.reversed() {
            guard tag.attributeValue(named: "data-og-id") != nil else { continue }
            var attributes = tag.attributes
            let existingInternalID = tag.attributeValue(named: "data-og-internal-id") ?? ""
            let preservingRoot = rootRange.map { tag.range == $0 } ?? false
            let preferredInternalID = preservingRoot ? preservingRootInternalID ?? existingInternalID : existingInternalID
            let internalID: String
            if !preferredInternalID.isEmpty, !used.contains(preferredInternalID) {
                internalID = preferredInternalID
                used.insert(internalID)
            } else {
                internalID = uniqueOpaqueInternalID(
                    seed: "\(fragmentHTML)|\(tag.range.lowerBound)|\(tag.tagName)",
                    used: &used
                )
            }
            setAttribute("data-og-internal-id", value: internalID, in: &attributes)
            result.replaceRange(tag.range, with: tag.serialized(with: attributes))
        }
        return result
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

    private static func prefixingDataOGIDs(in fragmentHTML: String, prefix: String) -> String {
        var result = fragmentHTML
        let document = OpenGraphiteHTMLDocument(html: fragmentHTML)
        for tag in document.parsedTags().reversed() {
            guard let id = tag.attributeValue(named: "data-og-id") else { continue }
            var attributes = tag.attributes
            setAttribute("data-og-id", value: "\(prefix)\(id)", in: &attributes)
            setAttribute(
                "data-og-internal-id",
                value: opaqueInternalID(seed: "\(prefix)|\(id)|\(tag.range.lowerBound)"),
                in: &attributes
            )
            result.replaceRange(tag.range, with: tag.serialized(with: attributes))
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
            if character.isWhitespace || character == "/" {
                break
            }
            index = source.index(after: index)
        }

        let name = String(source[source.startIndex..<index])
        let rest = String(source[index...])
        let selfClosing = rest.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/")
        let attributes = selfClosing ? String(rest.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines) : rest
        return (name, attributes, selfClosing)
    }

    private func tagName(fromClosingTag source: String) -> String {
        let body = source.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        let endIndex = body.firstIndex(where: { $0.isWhitespace || $0 == ">" }) ?? body.endIndex
        return String(body[..<endIndex]).lowercased()
    }

    private static func parseAttributes(_ source: String) -> [OpenGraphiteHTMLAttribute] {
        var attributes: [OpenGraphiteHTMLAttribute] = []
        var index = source.startIndex

        while index < source.endIndex {
            while index < source.endIndex, source[index].isWhitespace {
                index = source.index(after: index)
            }
            guard index < source.endIndex else { break }

            let nameStart = index
            while index < source.endIndex,
                  !source[index].isWhitespace,
                  source[index] != "=",
                  source[index] != "/" {
                index = source.index(after: index)
            }
            let name = String(source[nameStart..<index])
            guard !name.isEmpty else {
                index = source.index(after: index)
                continue
            }

            while index < source.endIndex, source[index].isWhitespace {
                index = source.index(after: index)
            }

            var value = ""
            if index < source.endIndex, source[index] == "=" {
                index = source.index(after: index)
                while index < source.endIndex, source[index].isWhitespace {
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
                    while index < source.endIndex, !source[index].isWhitespace {
                        index = source.index(after: index)
                    }
                    value = String(source[valueStart..<index])
                }
            }

            attributes.append(OpenGraphiteHTMLAttribute(name: name, value: value))
        }

        return attributes
    }

    private static func setAttribute(_ name: String, value: String, in attributes: inout [OpenGraphiteHTMLAttribute]) {
        if let index = attributes.firstIndex(where: { $0.name == name }) {
            attributes[index].value = value
        } else {
            attributes.append(OpenGraphiteHTMLAttribute(name: name, value: value))
        }
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
/// - `selfClosing`: 自己終了タグか。
struct OpenGraphiteHTMLTag: Equatable {
    var range: Range<Int>
    var rawTagName: String
    var tagName: String
    var attributes: [OpenGraphiteHTMLAttribute]
    var depth: Int
    var selfClosing: Bool

    var attributeDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: attributes.map { ($0.name, $0.value) })
    }

    /// 論理名（日本語）: 属性値取得関数
    /// 処理概要: 指定名の属性値を返します。
    ///
    /// - Parameter name: 取得する属性名。
    /// - Returns: 属性値。存在しない場合は `nil`。
    func attributeValue(named name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    /// 論理名（日本語）: 空文字nil属性取得関数
    /// 処理概要: 空文字の属性値を `nil` として扱い、UI / JSON 向けの省略値にします。
    ///
    /// - Parameter name: 取得する属性名。
    /// - Returns: 空でない属性値。
    func emptyNilAttribute(named name: String) -> String? {
        guard let value = attributeValue(named: name), !value.isEmpty else { return nil }
        return value
    }

    /// 論理名（日本語）: 開始タグ直列化関数
    /// 処理概要: 指定属性一覧を使って開始タグ文字列を再生成します。
    ///
    /// - Parameter attributes: 直列化する属性一覧。
    /// - Returns: HTML 開始タグ文字列。
    func serialized(with attributes: [OpenGraphiteHTMLAttribute]) -> String {
        let attributeText = attributes
            .map { "\($0.name)=\"\(Self.escapeAttribute($0.value))\"" }
            .joined(separator: " ")
        let suffix = selfClosing ? " /" : ""
        if attributeText.isEmpty {
            return "<\(rawTagName)\(suffix)>"
        }
        return "<\(rawTagName) \(attributeText)\(suffix)>"
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
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
/// - `value`: 属性値。
struct OpenGraphiteHTMLAttribute: Equatable {
    var name: String
    var value: String
}

/// 論理名（日本語）: OpenGraphite CSS style
/// 概要: inline style の CSS 宣言を順序付きで保持し、`--og-*` 変数の更新に使います。
///
/// プロパティ:
/// - `declarations`: CSS 宣言の順序付き一覧。
struct OpenGraphiteCSSStyle: Equatable {
    var declarations: [OpenGraphiteCSSDeclaration]

    /// 論理名（日本語）: CSS style解析関数
    /// 処理概要: inline style 文字列を宣言一覧へ分解します。
    ///
    /// - Parameter source: HTML 属性内の style 値。
    /// - Returns: CSS style モデル。
    static func parse(_ source: String) -> OpenGraphiteCSSStyle {
        let declarations = source
            .split(separator: ";", omittingEmptySubsequences: true)
            .compactMap { item -> OpenGraphiteCSSDeclaration? in
                let pair = item.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2 else { return nil }
                let name = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return OpenGraphiteCSSDeclaration(name: name, value: value)
            }
        return OpenGraphiteCSSStyle(declarations: declarations)
    }

    /// 論理名（日本語）: CSS変数設定関数
    /// 処理概要: 指定 CSS 変数を設定し、空値の場合は宣言を削除します。
    ///
    /// - Parameters:
    ///   - name: CSS 変数名。
    ///   - value: 設定値。空の場合は削除。
    mutating func set(_ name: String, value: String) {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// 論理名（日本語）: CSS変数一括削除関数
    /// 処理概要: 指定された CSS 変数名に一致する宣言を削除します。
    ///
    /// - Parameter names: 削除対象の CSS 変数名。
    mutating func removeVariables(_ names: Set<String>) {
        declarations.removeAll { names.contains($0.name) }
    }

    /// 論理名（日本語）: OpenGraphite CSS変数辞書化関数
    /// 処理概要: `--og-*` 宣言だけを JSON / node model 向け辞書へ変換します。
    ///
    /// - Returns: `--og-*` CSS 変数辞書。
    func ogVariables() -> [String: String] {
        Dictionary(uniqueKeysWithValues: declarations.filter { $0.name.hasPrefix("--og-") }.map { ($0.name, $0.value) })
    }

    /// 論理名（日本語）: CSS style直列化関数
    /// 処理概要: CSS 宣言一覧を HTML 属性内へ戻す文字列に変換します。
    ///
    /// - Returns: `name:value;` 形式の style 文字列。
    func serialized() -> String {
        declarations.map { "\($0.name):\($0.value);" }.joined(separator: " ")
    }
}

/// 論理名（日本語）: OpenGraphite CSS宣言
/// 概要: inline style 内の単一 CSS 宣言を表します。
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
