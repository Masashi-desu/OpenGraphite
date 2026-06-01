import Foundation

/// 論理名（日本語）: OpenGraphite component build結果
/// 概要: `<og-instance>` を component master で静的展開した build の結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `built`: すべての対象ページを出力できた場合は `true`。
/// - `outputURL`: build 出力先ディレクトリ。
/// - `pages`: 出力した通常 page 一覧。
/// - `assets`: 出力した静的 asset 一覧。
/// - `diagnostics`: build 中の警告またはエラー。
struct OpenGraphiteComponentBuildResult: Codable, Equatable {
    var schemaVersion: String
    var built: Bool
    var outputURL: String
    var pages: [OpenGraphiteBuiltPage]
    var assets: [OpenGraphiteBuiltAsset]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: OpenGraphite build済みページ
/// 概要: build で生成された単一 HTML ページの入出力パスを表します。
///
/// プロパティ:
/// - `id`: `.ogp` 内 page ID。
/// - `sourcePath`: `htmlRoot` から見た入力 HTML path。
/// - `outputPath`: build 出力先 HTML path。
struct OpenGraphiteBuiltPage: Codable, Equatable {
    var id: String
    var sourcePath: String
    var outputPath: String
}

/// 論理名（日本語）: OpenGraphite build済みasset
/// 概要: build で出力された CSS / 静的 asset の入出力パスを表します。
///
/// プロパティ:
/// - `kind`: asset 種別。
/// - `sourcePath`: 入力 asset path。
/// - `outputPath`: build 出力先 asset path。
struct OpenGraphiteBuiltAsset: Codable, Equatable {
    var kind: String
    var sourcePath: String
    var outputPath: String
}

/// 論理名（日本語）: OpenGraphite component builder
/// 概要: Pages HTML の `<og-instance>` を Components HTML の master subtree で展開し、静的 HTML を生成します。
struct OpenGraphiteComponentBuilder {
    private static let schemaVersion = "0.1"

    /// 論理名（日本語）: project build関数
    /// 処理概要: `.ogp` の通常 Pages を対象に component instance を展開し、出力ディレクトリへ HTML を保存します。
    ///
    /// - Parameters:
    ///   - projectURL: build する `.ogp` URL。
    ///   - outputURL: build 出力先ディレクトリ URL。
    /// - Returns: build 結果。
    func buildProject(projectURL: URL, outputURL: URL) throws -> OpenGraphiteComponentBuildResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var diagnostics: [OpenGraphiteDiagnostic] = []
        var builtPages: [OpenGraphiteBuiltPage] = []
        var builtAssets: [OpenGraphiteBuiltAsset] = []
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let cssOutputURL = outputURL.appendingPathComponent(loadedProject.cssURL.lastPathComponent)
        if fileManager.fileExists(atPath: loadedProject.cssURL.path) {
            try copyFile(from: loadedProject.cssURL, to: cssOutputURL)
            builtAssets.append(
                OpenGraphiteBuiltAsset(
                    kind: "css",
                    sourcePath: loadedProject.cssURL.path,
                    outputPath: cssOutputURL.path
                )
            )
        } else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .warning,
                    code: "missing-css-library",
                    message: "CSS library が見つかりません: \(loadedProject.cssURL.path)",
                    path: loadedProject.cssURL.path,
                    nodeID: nil
                )
            )
        }
        builtAssets.append(
            contentsOf: try copyHTMLRootAssets(
                loadedProject: loadedProject,
                outputURL: outputURL
            )
        )

        for chapter in loadedProject.project.chapters {
            for page in chapter.pages {
                let pageURL = loadedProject.htmlURL(for: page)
                let outputPageURL = outputURL.appendingPathComponent(page.path)
                try fileManager.createDirectory(at: outputPageURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                let sourceHTML = try String(contentsOf: pageURL, encoding: .utf8)
                var pageDiagnostics: [OpenGraphiteDiagnostic] = []
                let builtHTML = try buildPageHTML(
                    sourceHTML,
                    pageURL: pageURL,
                    diagnostics: &pageDiagnostics,
                    outputPageURL: outputPageURL,
                    sourceCSSURL: loadedProject.cssURL,
                    outputCSSURL: cssOutputURL
                )
                diagnostics.append(contentsOf: pageDiagnostics)
                try builtHTML.write(to: outputPageURL, atomically: true, encoding: .utf8)
                builtPages.append(OpenGraphiteBuiltPage(id: page.id, sourcePath: page.path, outputPath: outputPageURL.path))
            }
        }

        return OpenGraphiteComponentBuildResult(
            schemaVersion: Self.schemaVersion,
            built: !diagnostics.contains { $0.severity == .error },
            outputURL: outputURL.path,
            pages: builtPages,
            assets: builtAssets,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: HTML build関数
    /// 処理概要: 1 つの page HTML に含まれる component link を解決し、`<og-instance>` を展開します。
    ///
    /// - Parameters:
    ///   - html: 入力 page HTML。
    ///   - pageURL: 入力 page URL。
    ///   - diagnostics: 追記先 diagnostics。
    /// - Returns: 展開済み HTML。
    func buildPageHTML(
        _ html: String,
        pageURL: URL,
        diagnostics: inout [OpenGraphiteDiagnostic],
        outputPageURL: URL? = nil,
        sourceCSSURL: URL? = nil,
        outputCSSURL: URL? = nil
    ) throws -> String {
        var components: [String: String] = [:]
        for href in componentHrefs(in: html) {
            let componentURL = resolveComponentURL(href, relativeTo: pageURL)
            let componentHTML = try String(contentsOf: componentURL, encoding: .utf8)
            for (componentID, masterHTML) in componentMasters(in: componentHTML) {
                components[componentID] = masterHTML
            }
        }

        let expandedHTML = expandInstances(in: html, components: components, pageURL: pageURL, diagnostics: &diagnostics)
        let staticHTML = stripRuntimeReferences(from: expandedHTML)
        guard let outputPageURL, let sourceCSSURL, let outputCSSURL else {
            return staticHTML
        }
        return rewriteStylesheetReferences(
            in: staticHTML,
            pageURL: pageURL,
            outputPageURL: outputPageURL,
            sourceCSSURL: sourceCSSURL,
            outputCSSURL: outputCSSURL
        )
    }

    /// 論理名（日本語）: HTML root assetコピー関数
    /// 処理概要: `htmlRoot` 配下の公開用非HTML asset を build 出力へコピーします。
    private func copyHTMLRootAssets(
        loadedProject: LoadedOpenGraphiteProject,
        outputURL: URL
    ) throws -> [OpenGraphiteBuiltAsset] {
        let fileManager = FileManager.default
        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .standardizedFileURL
        guard let enumerator = fileManager.enumerator(
            at: htmlRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let pagePaths = Set(loadedProject.project.chapters.flatMap(\.pages).map(\.path))
        let componentPaths = Set(loadedProject.project.components.map(\.path))
        var assets: [OpenGraphiteBuiltAsset] = []
        for case let sourceURL as URL in enumerator {
            let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true { continue }
            if sourceURL.standardizedFileURL.path == loadedProject.cssURL.standardizedFileURL.path {
                continue
            }

            let relativePath = Self.relativePath(from: htmlRootURL, to: sourceURL)
            guard shouldCopyHTMLRootAsset(relativePath, pagePaths: pagePaths, componentPaths: componentPaths) else {
                continue
            }

            let outputAssetURL = outputURL.appendingPathComponent(relativePath)
            try copyFile(from: sourceURL, to: outputAssetURL)
            assets.append(
                OpenGraphiteBuiltAsset(
                    kind: "asset",
                    sourcePath: sourceURL.path,
                    outputPath: outputAssetURL.path
                )
            )
        }
        return assets
    }

    /// 論理名（日本語）: HTML root assetコピー判定関数
    /// 処理概要: build に同梱する public asset かどうかを判定します。
    private func shouldCopyHTMLRootAsset(
        _ relativePath: String,
        pagePaths: Set<String>,
        componentPaths: Set<String>
    ) -> Bool {
        if pagePaths.contains(relativePath) || componentPaths.contains(relativePath) {
            return false
        }
        if relativePath == "OpenGraphite.runtime.js" {
            return false
        }
        if URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "html" {
            return false
        }
        return true
    }

    /// 論理名（日本語）: ファイルコピー関数
    /// 処理概要: 出力先親ディレクトリを作成し、既存ファイルを置き換えてコピーします。
    private func copyFile(from sourceURL: URL, to outputURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        try fileManager.copyItem(at: sourceURL, to: outputURL)
    }

    /// 論理名（日本語）: component link抽出関数
    /// 処理概要: `rel="opengraphite-components"` の link href を HTML から取り出します。
    private func componentHrefs(in html: String) -> [String] {
        matches(pattern: #"<link\b[^>]*>"#, in: html).compactMap { tag in
            guard attribute("rel", in: tag) == "opengraphite-components" else { return nil }
            return attribute("href", in: tag)
        }
    }

    /// 論理名（日本語）: component master抽出関数
    /// 処理概要: Components HTML から `data-og-component-kind="master"` の subtree を component ID ごとに抽出します。
    private func componentMasters(in html: String) -> [String: String] {
        let pattern = #"(?is)<([A-Za-z][\w:-]*)\b(?=[^>]*\bdata-og-component=(["'])(.*?)\2)(?=[^>]*\bdata-og-component-kind=(["'])master\4)[^>]*>.*?</\1>"#
        var result: [String: String] = [:]
        for match in regexMatches(pattern: pattern, in: html) {
            guard match.numberOfRanges >= 4,
                  let fullRange = Range(match.range(at: 0), in: html),
                  let componentRange = Range(match.range(at: 3), in: html)
            else {
                continue
            }
            result[String(html[componentRange])] = String(html[fullRange])
        }
        return result
    }

    /// 論理名（日本語）: instance展開関数
    /// 処理概要: `<og-instance>` を対応する component master HTML で置換します。
    private func expandInstances(
        in html: String,
        components: [String: String],
        pageURL: URL,
        diagnostics: inout [OpenGraphiteDiagnostic]
    ) -> String {
        let pattern = #"(?is)<og-instance\b([^>]*)>(.*?)</og-instance>"#
        var result = html
        for match in regexMatches(pattern: pattern, in: html).reversed() {
            guard let fullRange = Range(match.range(at: 0), in: html),
                  let attributeRange = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }
            let attributes = String(html[attributeRange])
            let content = String(html[contentRange])
            guard let componentID = attribute("data-og-component", in: attributes) else { continue }
            guard let masterHTML = components[componentID] else {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-component-master",
                        message: "component master が見つかりません: \(componentID)",
                        path: pageURL.path,
                        nodeID: attribute("data-og-id", in: attributes)
                    )
                )
                continue
            }
            let idPrefix = attribute("data-og-id", in: attributes) ?? "\(componentID)-instance"
            let instanceStyle = attribute("style", in: attributes)
            let rendered = render(masterHTML: masterHTML, slots: slots(in: content), idPrefix: idPrefix, instanceStyle: instanceStyle)
            result.replaceSubrange(fullRange, with: rendered)
        }
        return result
    }

    /// 論理名（日本語）: master描画関数
    /// 処理概要: master HTML に slot 内容、ID prefix、instance style を適用して page 内 HTML を生成します。
    private func render(masterHTML: String, slots: [String: String], idPrefix: String, instanceStyle: String?) -> String {
        var html = masterHTML
        html = removeAttribute("data-og-component-kind", from: html)
        html = applySlots(to: html, slots: slots)
        html = rewriteIDs(in: html, idPrefix: idPrefix)
        if let instanceStyle, !instanceStyle.isEmpty {
            html = mergeRootStyle(instanceStyle, into: html)
        }
        return html
    }

    /// 論理名（日本語）: slot抽出関数
    /// 処理概要: instance source child の `slot` 属性と inner HTML を対応付けます。
    private func slots(in html: String) -> [String: String] {
        let pattern = #"(?is)<([A-Za-z][\w:-]*)\b(?=[^>]*\bslot=(["'])(.*?)\2)([^>]*)>(.*?)</\1>"#
        var result: [String: String] = [:]
        for match in regexMatches(pattern: pattern, in: html) {
            guard let slotRange = Range(match.range(at: 3), in: html),
                  let contentRange = Range(match.range(at: 5), in: html)
            else {
                continue
            }
            result[String(html[slotRange])] = String(html[contentRange])
        }
        return result
    }

    /// 論理名（日本語）: slot適用関数
    /// 処理概要: `data-og-slot` を持つ要素の中身を instance slot 内容で置き換えます。
    private func applySlots(to html: String, slots: [String: String]) -> String {
        let pattern = #"(?is)<([A-Za-z][\w:-]*)\b(?=[^>]*\bdata-og-slot=(["'])(.*?)\2)([^>]*)>(.*?)</\1>"#
        var result = html
        for match in regexMatches(pattern: pattern, in: html).reversed() {
            guard let fullRange = Range(match.range(at: 0), in: html),
                  let tagRange = Range(match.range(at: 1), in: html),
                  let slotRange = Range(match.range(at: 3), in: html),
                  let attributeRange = Range(match.range(at: 4), in: html),
                  let fallbackRange = Range(match.range(at: 5), in: html)
            else {
                continue
            }
            let tag = String(html[tagRange])
            let attributes = String(html[attributeRange])
            let slotName = String(html[slotRange])
            let fallback = String(html[fallbackRange])
            let content = slots[slotName] ?? fallback
            result.replaceSubrange(fullRange, with: "<\(tag)\(attributes)>\(content)</\(tag)>")
        }
        return result
    }

    /// 論理名（日本語）: data-og-id prefix関数
    /// 処理概要: 展開済み component subtree の `data-og-id` を instance ID に基づく一意 ID へ変換します。
    private func rewriteIDs(in html: String, idPrefix: String) -> String {
        let pattern = #"\bdata-og-id=(["'])(.*?)\1"#
        var result = html
        let matches = regexMatches(pattern: pattern, in: html)
        for (index, match) in matches.enumerated().reversed() {
            guard let fullRange = Range(match.range(at: 0), in: html),
                  let idRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }
            let originalID = String(html[idRange])
            let replacementID = index == 0 || originalID == "root" ? idPrefix : "\(idPrefix)-\(originalID)"
            result.replaceSubrange(fullRange, with: "data-og-id=\"\(replacementID)\"")
        }
        return result
    }

    /// 論理名（日本語）: root style統合関数
    /// 処理概要: instance source の inline style を展開 root の style へ追加します。
    private func mergeRootStyle(_ style: String, into html: String) -> String {
        guard let firstTag = regexMatches(pattern: #"(?is)<[A-Za-z][\w:-]*\b[^>]*>"#, in: html).first,
              let tagRange = Range(firstTag.range(at: 0), in: html)
        else {
            return html
        }

        var tag = String(html[tagRange])
        if let currentStyle = attribute("style", in: tag) {
            tag = setAttribute("style", value: mergedStyle(currentStyle, style), in: tag)
        } else {
            tag.insert(contentsOf: " style=\"\(style)\"", at: tag.index(before: tag.endIndex))
        }

        var result = html
        result.replaceSubrange(tagRange, with: tag)
        return result
    }

    /// 論理名（日本語）: style結合関数
    /// 処理概要: component master と instance の inline style を余分な区切りなしで結合します。
    private func mergedStyle(_ baseStyle: String, _ overrideStyle: String) -> String {
        [baseStyle, overrideStyle]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ;\n\t")) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }

    /// 論理名（日本語）: runtime参照削除関数
    /// 処理概要: 静的 build 出力から component source link と runtime script を除去します。
    private func stripRuntimeReferences(from html: String) -> String {
        var result = html
        for tag in matches(pattern: #"<link\b[^>]*>"#, in: html).reversed() where attribute("rel", in: tag) == "opengraphite-components" {
            if let range = result.range(of: tag) {
                result.removeSubrange(range)
            }
        }
        let scriptPattern = #"(?is)<script\b(?=[^>]*\bsrc=(["'])[^"']*OpenGraphite\.runtime\.js\1)[^>]*>\s*</script>"#
        for match in regexMatches(pattern: scriptPattern, in: result).reversed() {
            guard let range = Range(match.range(at: 0), in: result) else { continue }
            result.removeSubrange(range)
        }
        return result
    }

    /// 論理名（日本語）: stylesheet参照書き換え関数
    /// 処理概要: build 出力 HTML の OpenGraphite.css 参照を dist 内へ向け直します。
    private func rewriteStylesheetReferences(
        in html: String,
        pageURL: URL,
        outputPageURL: URL,
        sourceCSSURL: URL,
        outputCSSURL: URL
    ) -> String {
        var result = html
        let tags = matches(pattern: #"<link\b[^>]*>"#, in: html)
        for tag in tags.reversed() {
            guard attribute("rel", in: tag) == "stylesheet",
                  let href = attribute("href", in: tag)
            else { continue }
            let resolvedHref = resolveURL(href, relativeTo: pageURL)
            guard resolvedHref.standardizedFileURL.path == sourceCSSURL.standardizedFileURL.path else {
                continue
            }

            let outputHref = Self.relativePath(
                from: outputPageURL.deletingLastPathComponent(),
                to: outputCSSURL
            )
            let replacement = setAttribute("href", value: outputHref, in: tag)
            if let range = result.range(of: tag) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private func resolveComponentURL(_ href: String, relativeTo pageURL: URL) -> URL {
        let hrefWithoutFragment = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        if hrefWithoutFragment.hasPrefix("/") {
            return URL(fileURLWithPath: hrefWithoutFragment).standardizedFileURL
        }
        return pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutFragment).standardizedFileURL
    }

    private func resolveURL(_ href: String, relativeTo pageURL: URL) -> URL {
        let hrefWithoutFragment = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        if hrefWithoutFragment.hasPrefix("/") {
            return URL(fileURLWithPath: hrefWithoutFragment).standardizedFileURL
        }
        if hrefWithoutFragment.contains("://") {
            return URL(string: hrefWithoutFragment) ?? pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutFragment)
        }
        return pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutFragment).standardizedFileURL
    }

    /// 論理名（日本語）: 相対パス生成関数
    /// 処理概要: あるディレクトリから対象 URL への相対 path を生成します。
    private static func relativePath(from baseURL: URL, to targetURL: URL) -> String {
        let base = baseURL.standardizedFileURL.pathComponents
        let target = targetURL.standardizedFileURL.pathComponents
        var commonCount = 0
        while commonCount < base.count,
              commonCount < target.count,
              base[commonCount] == target[commonCount] {
            commonCount += 1
        }

        let upward = Array(repeating: "..", count: base.count - commonCount)
        let downward = Array(target.dropFirst(commonCount))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    private func attribute(_ name: String, in text: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"(?i)\b\#(escapedName)\s*=\s*(["'])(.*?)\1"#
        guard let match = regexMatches(pattern: pattern, in: text).first,
              let range = Range(match.range(at: 2), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func setAttribute(_ name: String, value: String, in tag: String) -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"(?i)\b\#(escapedName)\s*=\s*(["']).*?\1"#
        guard let match = regexMatches(pattern: pattern, in: tag).first,
              let range = Range(match.range(at: 0), in: tag)
        else {
            var updatedTag = tag
            updatedTag.insert(contentsOf: " \(name)=\"\(value)\"", at: updatedTag.index(before: updatedTag.endIndex))
            return updatedTag
        }
        var result = tag
        result.replaceSubrange(range, with: "\(name)=\"\(value)\"")
        return result
    }

    private func removeAttribute(_ name: String, from html: String) -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        return html.replacingOccurrences(of: #"(?i)\s+\#(escapedName)\s*=\s*(["']).*?\1"#, with: "", options: .regularExpression)
    }

    private func matches(pattern: String, in text: String) -> [String] {
        regexMatches(pattern: pattern, in: text).compactMap { match in
            guard let range = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func regexMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return []
        }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
