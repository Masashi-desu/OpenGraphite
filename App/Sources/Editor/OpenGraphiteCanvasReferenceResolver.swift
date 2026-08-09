import Foundation

/// 論理名（日本語）: 解決済みキャンバスオブジェクト参照
/// 概要: typed参照IDから確定したHTMLカードと任意階層ノードを、プレビューと編集同期で共有します。
///
/// プロパティ:
/// - `referenceID`: 正規化済みtyped参照ID。
/// - `segment`: 参照元HTMLカードが属するPages / Componentsセグメント。
/// - `containerInternalID`: 参照元Chapter / Collectionの内部ID。
/// - `page`: 参照元HTMLカード。
/// - `node`: 参照元HTMLノード。
/// - `pageURL`: 参照元HTMLファイルの解決済みURL。
struct OpenGraphiteResolvedCanvasReference: Equatable {
    var referenceID: String
    var segment: OpenGraphiteCanvasSegment
    var containerInternalID: String
    var page: OpenGraphitePage
    var node: OpenGraphiteHTMLReferenceTarget
    var pageURL: URL
}

/// 論理名（日本語）: キャンバス参照source解決情報
/// 概要: typed参照IDの軽量manifest解決結果を、HTML読み込みと分離して保持します。
///
/// プロパティ:
/// - `referenceID`: 正規化済みtyped参照ID。
/// - `segment`: 参照元のPages / Componentsセグメント。
/// - `containerInternalID`: Chapter / Collection内部ID。
/// - `page`: 参照元HTMLカード。
/// - `nodeInternalID`: HTML内の安定node内部ID。
/// - `pageURL`: 参照元HTML URL。
struct OpenGraphiteCanvasReferenceResolutionSource: Equatable {
    var referenceID: String
    var segment: OpenGraphiteCanvasSegment
    var containerInternalID: String
    var page: OpenGraphitePage
    var nodeInternalID: String
    var pageURL: URL
}

/// 論理名（日本語）: キャンバスオブジェクト参照解決エラー
/// 概要: 入力参照IDの形式、参照階層、ファイル、ノード解決に関する利用者向けエラーを表します。
enum OpenGraphiteCanvasReferenceResolutionError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedType
    case missingContainer
    case missingPage
    case unreadablePage
    case missingNode
    case pageRootNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "参照IDの形式が正しくありません。"
        case .unsupportedType:
            return "ogref:node または ogref:component-node を入力してください。"
        case .missingContainer:
            return "参照元のChapterまたはCollectionが見つかりません。"
        case .missingPage:
            return "参照元のPageまたはComponentが見つかりません。"
        case .unreadablePage:
            return "参照元HTMLを読み込めません。"
        case .missingNode:
            return "参照元オブジェクトが見つかりません。"
        case .pageRootNotSupported:
            return "Page全体は既存のPage配置を使用してください。Page内オブジェクトだけを参照配置できます。"
        }
    }
}

/// 論理名（日本語）: キャンバスオブジェクト参照解決器
/// 概要: `ogref:node` / `ogref:component-node` をproject内のHTMLカードと任意階層ノードへ解決します。
enum OpenGraphiteCanvasReferenceResolver {
    /// 論理名（日本語）: キャンバスオブジェクト参照解決関数
    /// 処理概要: typed参照IDのcontainer、HTMLカード、内部不変node IDを順に検証して参照元を返します。
    ///
    /// - Parameters:
    ///   - value: 入力された参照ID。
    ///   - project: 解決対象の読み込み済みproject。
    /// - Returns: プレビューと編集同期に使う解決済み参照元。
    /// - Throws: 形式または参照先が不正な場合の解決エラー。
    static func resolve(
        _ value: String,
        in project: LoadedOpenGraphiteProject
    ) throws -> OpenGraphiteResolvedCanvasReference {
        try resolve(source(value, in: project))
    }

    /// 論理名（日本語）: キャンバス参照source解決関数
    /// 処理概要: typed参照IDからmanifest内のcontainer、HTMLカード、node内部IDを、HTMLを読まずに確定します。
    ///
    /// - Parameters:
    ///   - value: 入力されたtyped参照ID。
    ///   - project: 解決対象の読み込み済みproject。
    /// - Returns: キャッシュkeyとbackground HTML解決に使うsource情報。
    /// - Throws: 形式またはmanifest参照が不正な場合の解決エラー。
    static func source(
        _ value: String,
        in project: LoadedOpenGraphiteProject
    ) throws -> OpenGraphiteCanvasReferenceResolutionSource {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty,
              let reference = OpenGraphiteReferenceID(parsing: normalizedValue)
        else {
            throw OpenGraphiteCanvasReferenceResolutionError.invalidFormat
        }

        let segment: OpenGraphiteCanvasSegment
        let containerInternalID: String
        let page: OpenGraphitePage
        let nodeInternalID: String

        switch reference.type {
        case .node:
            segment = .pages
            containerInternalID = reference.parts[0]
            nodeInternalID = reference.parts[2]
            guard let chapter = project.project.chapters.first(where: {
                $0.internalID == containerInternalID
            }) else {
                throw OpenGraphiteCanvasReferenceResolutionError.missingContainer
            }
            guard let resolvedPage = chapter.pages.first(where: {
                $0.internalID == reference.parts[1]
            }) else {
                throw OpenGraphiteCanvasReferenceResolutionError.missingPage
            }
            page = resolvedPage
        case .componentNode:
            segment = .components
            containerInternalID = reference.parts[0]
            nodeInternalID = reference.parts[2]
            guard let collection = project.project.collections.first(where: {
                $0.internalID == containerInternalID
            }) else {
                throw OpenGraphiteCanvasReferenceResolutionError.missingContainer
            }
            guard let resolvedPage = collection.components.first(where: {
                $0.internalID == reference.parts[1]
            }) else {
                throw OpenGraphiteCanvasReferenceResolutionError.missingPage
            }
            page = resolvedPage
        case .chapter, .collection, .page, .component, .annotation:
            throw OpenGraphiteCanvasReferenceResolutionError.unsupportedType
        }

        return OpenGraphiteCanvasReferenceResolutionSource(
            referenceID: reference.stringValue,
            segment: segment,
            containerInternalID: containerInternalID,
            page: page,
            nodeInternalID: nodeInternalID,
            pageURL: project.htmlURL(for: page)
        )
    }

    /// 論理名（日本語）: HTMLキャンバス参照解決関数
    /// 処理概要: manifestで確定済みのsource情報からHTMLを1回だけ走査し、参照用軽量nodeを返します。
    ///
    /// - Parameter source: manifest側で検証済みの参照source情報。
    /// - Returns: プレビュと編集同期に使う解決済み参照元。
    /// - Throws: HTML読み込み、node解決、Page root guardに失敗した場合の解決エラー。
    static func resolve(
        _ source: OpenGraphiteCanvasReferenceResolutionSource
    ) throws -> OpenGraphiteResolvedCanvasReference {
        let pageURL = source.pageURL
        guard let html = try? String(contentsOf: pageURL, encoding: .utf8) else {
            throw OpenGraphiteCanvasReferenceResolutionError.unreadablePage
        }
        guard let node = OpenGraphiteHTMLDocument(html: html).referenceTarget(
            internalID: source.nodeInternalID,
            isProjectRegisteredResource: true
        ) else {
            throw OpenGraphiteCanvasReferenceResolutionError.missingNode
        }
        guard !node.isProjectResourceRoot else {
            throw OpenGraphiteCanvasReferenceResolutionError.pageRootNotSupported
        }

        return OpenGraphiteResolvedCanvasReference(
            referenceID: source.referenceID,
            segment: source.segment,
            containerInternalID: source.containerInternalID,
            page: source.page,
            node: node,
            pageURL: pageURL
        )
    }
}
