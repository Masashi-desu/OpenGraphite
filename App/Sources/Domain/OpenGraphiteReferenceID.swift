import Foundation

/// 論理名（日本語）: OpenGraphite参照種別
/// 概要: agent に渡す `ogref` 参照 ID が指す階層を表します。
enum OpenGraphiteReferenceType: String, Codable, Equatable {
    case chapter
    case collection
    case page
    case component
    case node
    case componentNode = "component-node"

    /// 論理名（日本語）: 参照部品数
    /// 処理概要: 種別ごとに `ogref:<type>:` 以降へ必要な ID 部品数を返します。
    var requiredPartCount: Int {
        switch self {
        case .chapter, .collection:
            return 1
        case .page, .component:
            return 2
        case .node, .componentNode:
            return 3
        }
    }
}

/// 論理名（日本語）: OpenGraphite参照ID
/// 概要: `.ogp` 内の Chapter / page / component canvas / node を一意に指す `ogref` 文字列を生成・解析します。
struct OpenGraphiteReferenceID: Equatable {
    static let scheme = "ogref"

    var type: OpenGraphiteReferenceType
    var parts: [String]

    /// 論理名（日本語）: 文字列表現
    /// 処理概要: `ogref:<type>:<id...>` 形式の参照 ID を返します。
    var stringValue: String {
        ([Self.scheme, type.rawValue] + parts).joined(separator: ":")
    }

    /// 論理名（日本語）: 参照ID初期化関数
    /// 処理概要: 種別と ID 部品から参照 ID を構築します。
    ///
    /// - Parameters:
    ///   - type: 参照種別。
    ///   - parts: `ogref:<type>:` 以降の ID 部品。
    init(type: OpenGraphiteReferenceType, parts: [String]) {
        self.type = type
        self.parts = parts
    }

    /// 論理名（日本語）: 参照ID解析関数
    /// 処理概要: `ogref:<type>:<id...>` 形式の文字列を解析し、種別ごとの部品数を検証します。
    ///
    /// - Parameter value: 解析対象文字列。
    init?(parsing value: String) {
        let components = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)
        guard components.count >= 3,
              components[0].lowercased() == Self.scheme,
              let type = OpenGraphiteReferenceType(rawValue: components[1].lowercased())
        else {
            return nil
        }

        let parts = Array(components.dropFirst(2))
        guard parts.count == type.requiredPartCount,
              !parts.contains(where: { $0.isEmpty })
        else {
            return nil
        }

        self.type = type
        self.parts = parts
    }

    /// 論理名（日本語）: Chapter参照ID生成関数
    /// 処理概要: Chapter 内部 ID から `ogref:chapter` を作ります。
    ///
    /// - Parameter chapterID: Chapter 内部 ID。
    /// - Returns: Chapter 参照 ID。
    static func chapter(_ chapterID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .chapter, parts: [chapterID])
    }

    /// 論理名（日本語）: Collection参照ID生成関数
    /// 処理概要: Collection 内部 ID から `ogref:collection` を作ります。
    ///
    /// - Parameter collectionID: Collection 内部 ID。
    /// - Returns: Collection 参照 ID。
    static func collection(_ collectionID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .collection, parts: [collectionID])
    }

    /// 論理名（日本語）: Page参照ID生成関数
    /// 処理概要: Chapter 内部 ID と page 内部 ID から `ogref:page` を作ります。
    ///
    /// - Parameters:
    ///   - chapterID: Chapter 内部 ID。
    ///   - pageID: Page 内部 ID。
    /// - Returns: Page 参照 ID。
    static func page(chapterID: String, pageID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .page, parts: [chapterID, pageID])
    }

    /// 論理名（日本語）: Component参照ID生成関数
    /// 処理概要: Collection 内部 ID と component canvas 内部 ID から `ogref:component` を作ります。
    ///
    /// - Parameters:
    ///   - collectionID: Collection 内部 ID。
    ///   - componentID: component canvas 内部 ID。
    /// - Returns: Component 参照 ID。
    static func component(collectionID: String, componentID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .component, parts: [collectionID, componentID])
    }

    /// 論理名（日本語）: Node参照ID生成関数
    /// 処理概要: Chapter / page / node の内部 ID から `ogref:node` を作ります。
    ///
    /// - Parameters:
    ///   - chapterID: Chapter 内部 ID。
    ///   - pageID: Page 内部 ID。
    ///   - nodeID: Node 内部 ID。
    /// - Returns: Node 参照 ID。
    static func node(chapterID: String, pageID: String, nodeID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .node, parts: [chapterID, pageID, nodeID])
    }

    /// 論理名（日本語）: Component Node参照ID生成関数
    /// 処理概要: Collection / component canvas / node の内部 ID から `ogref:component-node` を作ります。
    ///
    /// - Parameters:
    ///   - collectionID: Collection 内部 ID。
    ///   - componentID: component canvas 内部 ID。
    ///   - nodeID: Node 内部 ID。
    /// - Returns: Component node 参照 ID。
    static func componentNode(collectionID: String, componentID: String, nodeID: String) -> OpenGraphiteReferenceID {
        OpenGraphiteReferenceID(type: .componentNode, parts: [collectionID, componentID, nodeID])
    }

    /// 論理名（日本語）: 含有ページ参照抽出関数
    /// 処理概要: typed 参照 ID が page / component / node を指す場合、対象 HTML を指す page 参照へ変換します。
    ///
    /// - Parameter value: `ogref` 参照 ID。
    /// - Returns: page または component 参照 ID。Chapter 参照や不正な形式の場合は `nil`。
    static func containingPageReferenceString(from value: String) -> String? {
        guard let reference = OpenGraphiteReferenceID(parsing: value) else {
            return nil
        }

        switch reference.type {
        case .page, .component:
            return reference.stringValue
        case .node:
            return OpenGraphiteReferenceID
                .page(chapterID: reference.parts[0], pageID: reference.parts[1])
                .stringValue
        case .componentNode:
            return OpenGraphiteReferenceID
                .component(collectionID: reference.parts[0], componentID: reference.parts[1])
                .stringValue
        case .chapter, .collection:
            return nil
        }
    }

    /// 論理名（日本語）: Node内部ID抽出関数
    /// 処理概要: typed node 参照 ID から実際の `data-og-internal-id` を取り出します。
    ///
    /// - Parameter value: `ogref:node` または `ogref:component-node`。
    /// - Returns: Node 内部 ID。node 参照ではない場合は `nil`。
    static func nodeInternalID(from value: String) -> String? {
        guard let reference = OpenGraphiteReferenceID(parsing: value) else {
            return nil
        }

        switch reference.type {
        case .node:
            return reference.parts[2]
        case .componentNode:
            return reference.parts[2]
        case .chapter, .collection, .page, .component:
            return nil
        }
    }

    /// 論理名（日本語）: Component内部ID抽出関数
    /// 処理概要: typed component 参照 ID から component canvas 内部 ID を取り出します。
    ///
    /// - Parameter value: `ogref:component` または `ogref:component-node`。
    /// - Returns: component canvas 内部 ID。component 参照ではない場合は `nil`。
    static func componentInternalID(from value: String) -> String? {
        guard let reference = OpenGraphiteReferenceID(parsing: value) else {
            return nil
        }

        switch reference.type {
        case .component, .componentNode:
            return reference.parts[1]
        case .chapter, .collection, .page, .node:
            return nil
        }
    }

    /// 論理名（日本語）: Collection内部ID抽出関数
    /// 処理概要: typed collection / component 参照 ID から Collection 内部 ID を取り出します。
    ///
    /// - Parameter value: `ogref:collection`、`ogref:component`、`ogref:component-node`。
    /// - Returns: Collection 内部 ID。Collection / component 参照ではない場合は `nil`。
    static func collectionInternalID(from value: String) -> String? {
        guard let reference = OpenGraphiteReferenceID(parsing: value) else {
            return nil
        }

        switch reference.type {
        case .collection:
            return reference.parts[0]
        case .component, .componentNode:
            return reference.parts[0]
        case .chapter, .page, .node:
            return nil
        }
    }
}
