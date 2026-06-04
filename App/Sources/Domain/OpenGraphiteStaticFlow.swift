import CoreGraphics
import Foundation

/// 論理名（日本語）: 静的フローリンク
/// 概要: HTML プレビュー内の静的リンク要素から抽出した遷移元ボタン位置と遷移先参照を表します。
///
/// プロパティ:
/// - `id`: 同一ページ内でリンクを識別する安定 ID。
/// - `sourceNodeID`: 遷移元要素の `data-og-id`。
/// - `sourceLabel`: UI 補助表示向けのリンクラベル。
/// - `targetHref`: HTML 属性に書かれた遷移先参照。
/// - `targetURL`: WebView が解決した遷移先 URL。
/// - `sourceRect`: WebView viewport 内の遷移元要素矩形。
struct OpenGraphiteStaticFlowLink: Identifiable, Equatable {
    var id: String
    var sourceNodeID: String
    var sourceLabel: String
    var targetHref: String
    var targetURL: String
    var sourceRect: CGRect

    /// 論理名（日本語）: payload初期化関数
    /// 処理概要: JavaScript bridge から届いた辞書 payload を静的フローリンクへ変換します。
    ///
    /// - Parameter payload: 遷移元要素 ID、href、viewport 矩形を含む辞書。
    init?(payload: [String: Any]) {
        let targetHref = payload["targetHref"] as? String ?? ""
        let targetURL = payload["targetURL"] as? String ?? ""
        guard !targetHref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !targetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let x = payload["x"] as? Double ?? 0
        let y = payload["y"] as? Double ?? 0
        let width = payload["width"] as? Double ?? 0
        let height = payload["height"] as? Double ?? 0
        guard [x, y, width, height].allSatisfy(\.isFinite), width > 0, height > 0 else {
            return nil
        }

        let sourceNodeID = payload["sourceNodeID"] as? String ?? ""
        let fallbackID = "link-\(targetHref)-\(x)-\(y)-\(width)-\(height)"
        id = payload["id"] as? String ?? (sourceNodeID.isEmpty ? fallbackID : sourceNodeID)
        self.sourceNodeID = sourceNodeID
        sourceLabel = payload["sourceLabel"] as? String ?? sourceNodeID
        self.targetHref = targetHref
        self.targetURL = targetURL
        sourceRect = CGRect(x: x, y: y, width: width, height: height)
    }

    /// 論理名（日本語）: 静的フローリンク初期化関数
    /// 処理概要: テストや解決処理で利用する静的フローリンク値を明示的に構成します。
    ///
    /// - Parameters:
    ///   - id: 同一ページ内でリンクを識別する安定 ID。
    ///   - sourceNodeID: 遷移元要素の `data-og-id`。
    ///   - sourceLabel: UI 補助表示向けのリンクラベル。
    ///   - targetHref: HTML 属性に書かれた遷移先参照。
    ///   - targetURL: WebView が解決した遷移先 URL。
    ///   - sourceRect: WebView viewport 内の遷移元要素矩形。
    init(
        id: String,
        sourceNodeID: String,
        sourceLabel: String,
        targetHref: String,
        targetURL: String,
        sourceRect: CGRect
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.sourceLabel = sourceLabel
        self.targetHref = targetHref
        self.targetURL = targetURL
        self.sourceRect = sourceRect
    }
}

/// 論理名（日本語）: 静的フロー元ホバー
/// 概要: HTML プレビュー内でホバー中の遷移元リンク要素を SwiftUI のフロー線強調へ渡す状態です。
///
/// プロパティ:
/// - `pageURL`: ホバー元リンクを含む HTML page の標準化済み URL。
/// - `linkID`: `OpenGraphiteStaticFlowLink.id` と一致するリンク ID。
/// - `sourceNodeID`: 遷移元要素の `data-og-id`。
struct OpenGraphiteStaticFlowSourceHover: Equatable {
    var pageURL: URL
    var linkID: String
    var sourceNodeID: String
}

/// 論理名（日本語）: 静的フロー水平接続側
/// 概要: フロー線を page preview の左右どちらの端へ接続するかを表します。
enum OpenGraphiteStaticFlowHorizontalSide: Equatable {
    case left
    case right
}

/// 論理名（日本語）: 静的フロー接続
/// 概要: ページ配置と静的リンクを解決した、キャンバス座標上のフロー線を表します。
///
/// プロパティ:
/// - `id`: 接続線の安定 ID。
/// - `sourcePageID`: 遷移元 page ID。
/// - `targetPageID`: 遷移先 page ID。
/// - `sourcePageURL`: 遷移元 HTML page の標準化済み URL。
/// - `sourcePoint`: 遷移元ボタン接続端のキャンバス座標。
/// - `sourceSide`: 遷移元ボタンの接続側。
/// - `targetPoint`: 遷移先プレビュー上部の接続点キャンバス座標。
/// - `targetSide`: 遷移先プレビューの接続側。
/// - `link`: 元になった静的フローリンク。
struct OpenGraphiteStaticFlowConnection: Identifiable, Equatable {
    var id: String
    var sourcePageID: String
    var targetPageID: String
    var sourcePageURL: URL
    var sourcePoint: CGPoint
    var sourceSide: OpenGraphiteStaticFlowHorizontalSide
    var targetPoint: CGPoint
    var targetSide: OpenGraphiteStaticFlowHorizontalSide
    var link: OpenGraphiteStaticFlowLink
}

/// 論理名（日本語）: 静的フロー解決器
/// 概要: HTML の静的リンクと `.ogp` の Pages 配置から、同じ配置名同士の画面遷移線を解決します。
///
/// メソッド:
/// - `connections(pages:loadedProject:linksByPageURL:)`: 表示中 Pages からフロー接続一覧を生成します。
enum OpenGraphiteStaticFlowResolver {
    /// 論理名（日本語）: 静的フロー接続生成関数
    /// 処理概要: 各 page の静的リンク参照を HTML URL または page ID/path へ解決し、同じ canvas name の Pages 同士だけを接続します。
    ///
    /// - Parameters:
    ///   - pages: 表示中 Chapter の page 一覧。
    ///   - loadedProject: HTML URL 解決に使う読み込み済み project。
    ///   - linksByPageURL: WebView から収集された page URL 別リンク一覧。
    /// - Returns: キャンバス座標上の静的フロー接続一覧。
    static func connections(
        pages: [OpenGraphitePage],
        loadedProject: LoadedOpenGraphiteProject,
        linksByPageURL: [URL: [OpenGraphiteStaticFlowLink]]
    ) -> [OpenGraphiteStaticFlowConnection] {
        guard !pages.isEmpty else { return [] }

        let minX = pages.map { CGFloat($0.canvas.x) }.min() ?? 0
        let minY = pages.map { CGFloat($0.canvas.y) }.min() ?? 0
        var connections: [OpenGraphiteStaticFlowConnection] = []

        for sourcePage in pages {
            let sourceURL = loadedProject.htmlURL(for: sourcePage).standardizedFileURL
            let links = linksByPageURL[sourceURL] ?? linksByPageURL[loadedProject.htmlURL(for: sourcePage)] ?? []
            for link in links {
                guard let targetPage = targetPage(
                    for: link,
                    sourcePage: sourcePage,
                    sourceURL: sourceURL,
                    pages: pages,
                    loadedProject: loadedProject
                ) else {
                    continue
                }

                let sourceOrigin = CGPoint(
                    x: CGFloat(sourcePage.canvas.x) - minX,
                    y: CGFloat(sourcePage.canvas.y) - minY
                )
                let targetOrigin = CGPoint(
                    x: CGFloat(targetPage.canvas.x) - minX,
                    y: CGFloat(targetPage.canvas.y) - minY
                )
                let sourceSide = resolvedSourceSide(
                    sourceOrigin: sourceOrigin,
                    sourceRect: link.sourceRect,
                    targetOrigin: targetOrigin,
                    targetPage: targetPage
                )
                let sourcePoint = resolvedSourcePoint(
                    origin: sourceOrigin,
                    rect: link.sourceRect,
                    side: sourceSide
                )
                let targetSide = resolvedTargetSide(
                    sourcePoint: sourcePoint,
                    targetOrigin: targetOrigin,
                    targetPage: targetPage
                )
                let targetPoint = resolvedTargetPoint(origin: targetOrigin, page: targetPage, side: targetSide)
                let connection = OpenGraphiteStaticFlowConnection(
                    id: "\(sourcePage.id):\(link.id):\(targetPage.id)",
                    sourcePageID: sourcePage.id,
                    targetPageID: targetPage.id,
                    sourcePageURL: sourceURL,
                    sourcePoint: sourcePoint,
                    sourceSide: sourceSide,
                    targetPoint: targetPoint,
                    targetSide: targetSide,
                    link: link
                )
                connections.append(connection)
            }
        }

        return connections
    }

    /// 論理名（日本語）: 遷移元接続側判定関数
    /// 処理概要: 遷移先プレビュー中心に近い左右端を、遷移元ボタンの接続側として選択します。
    ///
    /// - Parameters:
    ///   - sourceOrigin: 遷移元プレビュー左上のキャンバス座標。
    ///   - sourceRect: WebView viewport 内の遷移元要素矩形。
    ///   - targetOrigin: 遷移先プレビュー左上のキャンバス座標。
    ///   - targetPage: 遷移先 page。
    /// - Returns: 遷移元ボタンの接続側。
    private static func resolvedSourceSide(
        sourceOrigin: CGPoint,
        sourceRect: CGRect,
        targetOrigin: CGPoint,
        targetPage: OpenGraphitePage
    ) -> OpenGraphiteStaticFlowHorizontalSide {
        let sourceMidX = sourceOrigin.x + sourceRect.midX
        let targetMidX = targetOrigin.x + CGFloat(targetPage.canvas.width) / 2
        return targetMidX < sourceMidX ? .left : .right
    }

    /// 論理名（日本語）: 遷移元接続点生成関数
    /// 処理概要: 選択された左右端に応じて、遷移元ボタン中央高の接続点を生成します。
    ///
    /// - Parameters:
    ///   - origin: 遷移元プレビュー左上のキャンバス座標。
    ///   - rect: WebView viewport 内の遷移元要素矩形。
    ///   - side: 遷移元ボタンの接続側。
    /// - Returns: 遷移元ボタン接続端のキャンバス座標。
    private static func resolvedSourcePoint(
        origin: CGPoint,
        rect: CGRect,
        side: OpenGraphiteStaticFlowHorizontalSide
    ) -> CGPoint {
        let x = side == .left ? rect.minX : rect.maxX
        return CGPoint(x: origin.x + x, y: origin.y + rect.midY)
    }

    /// 論理名（日本語）: 遷移先接続側判定関数
    /// 処理概要: 遷移元点に近い左右端を、遷移先プレビュー上部の接続側として選択します。
    ///
    /// - Parameters:
    ///   - sourcePoint: 遷移元ボタン接続端のキャンバス座標。
    ///   - targetOrigin: 遷移先プレビュー左上のキャンバス座標。
    ///   - targetPage: 遷移先 page。
    /// - Returns: 遷移先プレビューの接続側。
    private static func resolvedTargetSide(
        sourcePoint: CGPoint,
        targetOrigin: CGPoint,
        targetPage: OpenGraphitePage
    ) -> OpenGraphiteStaticFlowHorizontalSide {
        let targetMidX = targetOrigin.x + CGFloat(targetPage.canvas.width) / 2
        return sourcePoint.x > targetMidX ? .right : .left
    }

    /// 論理名（日本語）: 遷移先接続点生成関数
    /// 処理概要: 選択された左右端に応じて、遷移先プレビュー上部の接続点を生成します。
    ///
    /// - Parameters:
    ///   - origin: 遷移先プレビュー左上のキャンバス座標。
    ///   - page: 遷移先 page。
    ///   - side: 遷移先プレビューの接続側。
    /// - Returns: 遷移先プレビュー上部の接続点キャンバス座標。
    private static func resolvedTargetPoint(
        origin: CGPoint,
        page: OpenGraphitePage,
        side: OpenGraphiteStaticFlowHorizontalSide
    ) -> CGPoint {
        switch side {
        case .left:
            return origin
        case .right:
            return CGPoint(x: origin.x + CGFloat(page.canvas.width), y: origin.y)
        }
    }

    /// 論理名（日本語）: 遷移先ページ解決関数
    /// 処理概要: 静的リンクの href、解決済み URL、page ID/path を候補にし、同じ配置名の page を返します。
    ///
    /// - Parameters:
    ///   - link: 解決対象の静的リンク。
    ///   - sourcePage: 遷移元 page。
    ///   - sourceURL: 遷移元 HTML URL。
    ///   - pages: 探索対象 page 一覧。
    ///   - loadedProject: HTML URL 解決に使う読み込み済み project。
    /// - Returns: 解決できた遷移先 page。見つからない場合は `nil`。
    private static func targetPage(
        for link: OpenGraphiteStaticFlowLink,
        sourcePage: OpenGraphitePage,
        sourceURL: URL,
        pages: [OpenGraphitePage],
        loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphitePage? {
        let sourceFlowName = sourcePage.canvas.flowResolutionName
        guard !sourceFlowName.isEmpty else { return nil }
        let candidates = pages.filter { page in
            page.id != sourcePage.id
                && page.canvas.flowResolutionName == sourceFlowName
                && matches(page: page, link: link, sourceURL: sourceURL, loadedProject: loadedProject)
        }
        return candidates.first
    }

    /// 論理名（日本語）: ページ一致判定関数
    /// 処理概要: page ID、page path、標準化済み HTML URL のいずれかがリンク参照と一致するかを判定します。
    ///
    /// - Parameters:
    ///   - page: 判定対象 page。
    ///   - link: 静的リンク。
    ///   - sourceURL: 遷移元 HTML URL。
    ///   - loadedProject: HTML URL 解決に使う読み込み済み project。
    /// - Returns: リンクが page を指す場合は `true`。
    private static func matches(
        page: OpenGraphitePage,
        link: OpenGraphiteStaticFlowLink,
        sourceURL: URL,
        loadedProject: LoadedOpenGraphiteProject
    ) -> Bool {
        let referenceValues = normalizedReferenceValues(for: link)
        if referenceValues.contains(page.id) || referenceValues.contains(normalizedPath(page.path)) {
            return true
        }

        guard let candidateURL = normalizedTargetURL(for: link, sourceURL: sourceURL) else { return false }
        return candidateURL == loadedProject.htmlURL(for: page).standardizedFileURL
    }

    /// 論理名（日本語）: 参照値正規化関数
    /// 処理概要: href や data 属性の値から fragment/query と相対パス記号を取り除いた比較用文字列を生成します。
    ///
    /// - Parameter link: 正規化対象の静的リンク。
    /// - Returns: page ID/path 比較に使う文字列集合。
    private static func normalizedReferenceValues(for link: OpenGraphiteStaticFlowLink) -> Set<String> {
        let rawValues = [link.targetHref, link.targetURL]
        let values = rawValues.flatMap { value -> [String] in
            let strippedValue = stripQueryAndFragment(from: value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !strippedValue.isEmpty else { return [] }

            var candidates = [strippedValue, normalizedPath(strippedValue)]
            if let url = URL(string: strippedValue), let lastPath = url.path.split(separator: "/").last {
                candidates.append(String(lastPath))
            }
            return candidates
        }
        return Set(values.filter { !$0.isEmpty })
    }

    /// 論理名（日本語）: 遷移先URL正規化関数
    /// 処理概要: WebView の解決済み URL または相対 href を標準化済み file URL へ変換します。
    ///
    /// - Parameters:
    ///   - link: 正規化対象の静的リンク。
    ///   - sourceURL: 相対 URL 解決基準の遷移元 HTML URL。
    /// - Returns: 標準化済み file URL。外部 URL など解決対象外の場合は `nil`。
    private static func normalizedTargetURL(for link: OpenGraphiteStaticFlowLink, sourceURL: URL) -> URL? {
        for rawValue in [link.targetURL, link.targetHref] {
            let value = stripQueryAndFragment(from: rawValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            if let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty {
                guard url.isFileURL else { continue }
                return url.standardizedFileURL
            }

            if value.hasPrefix("/") {
                return URL(fileURLWithPath: value).standardizedFileURL
            }

            return sourceURL
                .deletingLastPathComponent()
                .appendingPathComponent(value)
                .standardizedFileURL
        }
        return nil
    }

    /// 論理名（日本語）: パス正規化関数
    /// 処理概要: 比較用に先頭の `./` と `/` を取り除きます。
    ///
    /// - Parameter path: 正規化対象のパス文字列。
    /// - Returns: 比較用パス。
    private static func normalizedPath(_ path: String) -> String {
        var result = stripQueryAndFragment(from: path)
        while result.hasPrefix("./") {
            result.removeFirst(2)
        }
        while result.hasPrefix("/") {
            result.removeFirst()
        }
        return result
    }

    /// 論理名（日本語）: query/fragment除去関数
    /// 処理概要: URL 文字列から `?` と `#` 以降を取り除きます。
    ///
    /// - Parameter value: 対象文字列。
    /// - Returns: query と fragment を除いた文字列。
    private static func stripQueryAndFragment(from value: String) -> String {
        let withoutFragment = value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? value
        return withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? withoutFragment
    }
}
