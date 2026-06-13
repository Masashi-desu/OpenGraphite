import Foundation

/// 論理名（日本語）: アイコンCDN依存性
/// 概要: HTML 内の CDN 参照 icon node を provider/package/version 単位で集約した依存情報です。
///
/// プロパティ:
/// - `library`: `data-og-icon-library` の値。
/// - `provider`: CDN provider の host。
/// - `package`: CDN 上の package 名。
/// - `version`: CDN package の version。`latest` の場合は未固定として扱います。
/// - `usedCount`: 対象 package/version を参照している icon node 数。
/// - `iconNames`: 参照されている icon 名の一意な一覧。
struct OpenGraphiteIconCDNDependency: Equatable, Hashable, Identifiable {
    var library: String
    var provider: String
    var package: String
    var version: String
    var usedCount: Int
    var iconNames: [String]

    var id: String {
        [library, provider, package, version].joined(separator: "#")
    }

    var packageLabel: String {
        guard !version.isEmpty else { return package }
        return "\(package)@\(version)"
    }

    var usageLabel: String {
        usedCount == 1 ? "1 use" : "\(usedCount) uses"
    }

    var statusLabel: String {
        version.lowercased() == "latest" ? "Unpinned" : "External"
    }
}

/// 論理名（日本語）: アイコンCDN依存性検出器
/// 概要: OpenGraphite HTML から `data-og-icon-source="cdn"` の icon node を検出し、依存性一覧向けに集約します。
enum OpenGraphiteIconCDNDependencyScanner {
    /// 論理名（日本語）: 読み込み済みprojectからのアイコンCDN依存性検出関数
    /// 処理概要: Project が保持する page と component master HTML を読み、CDN icon 依存を集約します。
    ///
    /// - Parameter loadedProject: 対象 project。
    /// - Returns: provider/package/version ごとに集約された CDN icon 依存性。
    static func dependencies(for loadedProject: LoadedOpenGraphiteProject) -> [OpenGraphiteIconCDNDependency] {
        var seenHTMLURLs: Set<URL> = []
        let htmlDocuments = loadedProject.project.allPages.compactMap { page -> String? in
            let htmlURL = loadedProject.htmlURL(for: page).standardizedFileURL
            guard seenHTMLURLs.insert(htmlURL).inserted else { return nil }
            return try? String(contentsOf: htmlURL, encoding: .utf8)
        }
        return dependencies(in: htmlDocuments)
    }

    /// 論理名（日本語）: HTML文字列からのアイコンCDN依存性検出関数
    /// 処理概要: HTML document 文字列群から CDN icon node を検出し、provider/package/version ごとに集約します。
    ///
    /// - Parameter htmlDocuments: 走査対象 HTML 文字列。
    /// - Returns: 集約済み CDN icon 依存性。
    static func dependencies(in htmlDocuments: [String]) -> [OpenGraphiteIconCDNDependency] {
        var buckets: [DependencyKey: DependencyBucket] = [:]

        for html in htmlDocuments {
            for match in iconNodeMatches(in: html) {
                guard let tagRange = Range(match.range(at: 0), in: html) else { continue }
                let tag = String(html[tagRange])
                let library = normalizedAttribute("data-og-icon-library", in: tag) ?? "lucide"
                let iconName = normalizedAttribute("data-og-icon-name", in: tag)
                let context = String(html[tagRange.lowerBound..<contextEndIndex(from: tagRange.upperBound, in: html)])
                let descriptor = cdnDescriptor(library: library, context: context)
                let key = DependencyKey(
                    library: library,
                    provider: descriptor.provider,
                    package: descriptor.package,
                    version: descriptor.version
                )

                var bucket = buckets[key] ?? DependencyBucket()
                bucket.usedCount += 1
                if let iconName, !iconName.isEmpty {
                    bucket.iconNames.insert(iconName)
                }
                buckets[key] = bucket
            }
        }

        return buckets.map { key, bucket in
            OpenGraphiteIconCDNDependency(
                library: key.library,
                provider: key.provider,
                package: key.package,
                version: key.version,
                usedCount: bucket.usedCount,
                iconNames: bucket.iconNames.sorted()
            )
        }
        .sorted { lhs, rhs in
            let lhsKey = [
                lhs.provider,
                lhs.package,
                lhs.version,
                lhs.library
            ].joined(separator: "\u{0}")
            let rhsKey = [
                rhs.provider,
                rhs.package,
                rhs.version,
                rhs.library
            ].joined(separator: "\u{0}")
            return lhsKey < rhsKey
        }
    }

    private struct DependencyKey: Hashable {
        var library: String
        var provider: String
        var package: String
        var version: String
    }

    private struct DependencyBucket {
        var usedCount = 0
        var iconNames: Set<String> = []
    }

    private struct CDNDescriptor {
        var provider: String
        var package: String
        var version: String
    }

    private static func iconNodeMatches(in html: String) -> [NSTextCheckingResult] {
        let pattern = #"<[A-Za-z][A-Za-z0-9:_-]*\b(?=[^>]*\bdata-og-icon-source\s*=\s*(["'])cdn\1)[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        return regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
    }

    private static func normalizedAttribute(_ name: String, in tag: String) -> String? {
        attribute(name, in: tag)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let valueRange = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }
        return String(tag[valueRange])
    }

    private static func contextEndIndex(from startIndex: String.Index, in html: String) -> String.Index {
        html.index(startIndex, offsetBy: 700, limitedBy: html.endIndex) ?? html.endIndex
    }

    private static func cdnDescriptor(library: String, context: String) -> CDNDescriptor {
        switch library {
        case "lucide":
            return CDNDescriptor(
                provider: "cdn.jsdelivr.net",
                package: "lucide-static",
                version: lucideStaticVersion(in: context) ?? "latest"
            )
        default:
            return CDNDescriptor(
                provider: "external",
                package: library.isEmpty ? "icon-cdn" : library,
                version: ""
            )
        }
    }

    private static func lucideStaticVersion(in context: String) -> String? {
        let pattern = #"https://cdn\.jsdelivr\.net/npm/lucide-static@([^/'")\s]+)/icons/"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: context, options: [], range: NSRange(context.startIndex..<context.endIndex, in: context)),
              let versionRange = Range(match.range(at: 1), in: context)
        else {
            return nil
        }
        return String(context[versionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
