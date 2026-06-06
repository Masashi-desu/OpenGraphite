import Foundation

/// 論理名（日本語）: OpenGraphiteプロジェクト定義
/// 概要: `.ogp` ファイルに保存されるプロジェクト管理情報、Chapter、ページ一覧を表します。
///
/// プロパティ:
/// - `version`: `.ogp` 形式のバージョン。
/// - `name`: プロジェクト表示名。
/// - `repositoryRoot`: `.ogp` から見たリポジトリルート。
/// - `htmlRoot`: HTML 成果物を置く public ルート。
/// - `cssLibrary`: OpenGraphite.css の参照パス。
/// - `chapters`: Chapter ごとのキャンバス定義。
/// - `collections`: Component master を格納する Collection 一覧。
struct OpenGraphiteProject: Codable, Equatable {
    var version: String
    var name: String
    var repositoryRoot: String?
    var htmlRoot: String
    var cssLibrary: String
    var chapters: [OpenGraphiteChapter]
    var collections: [OpenGraphiteComponentCollection]

    var allPages: [OpenGraphitePage] {
        chapters.flatMap(\.pages) + components
    }

    var components: [OpenGraphitePage] {
        collections.flatMap(\.components)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case name
        case repositoryRoot
        case htmlRoot
        case cssLibrary
        case chapters
        case collections
    }

    /// 論理名（日本語）: project JSONデコード関数
    /// 処理概要: Chapter 配列と Component Collection 配列を読み込みます。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        name = try container.decode(String.self, forKey: .name)
        repositoryRoot = try container.decodeIfPresent(String.self, forKey: .repositoryRoot)
        htmlRoot = try container.decode(String.self, forKey: .htmlRoot)
        cssLibrary = try container.decode(String.self, forKey: .cssLibrary)
        chapters = try container.decode([OpenGraphiteChapter].self, forKey: .chapters)
        collections = try container.decodeIfPresent([OpenGraphiteComponentCollection].self, forKey: .collections) ?? []
    }

    /// 論理名（日本語）: project JSONエンコード関数
    /// 処理概要: `collections` を含む現行 `.ogp` 形式として project manifest を保存します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(repositoryRoot, forKey: .repositoryRoot)
        try container.encode(htmlRoot, forKey: .htmlRoot)
        try container.encode(cssLibrary, forKey: .cssLibrary)
        try container.encode(chapters, forKey: .chapters)
        if !collections.isEmpty {
            try container.encode(collections, forKey: .collections)
        }
    }

    /// 論理名（日本語）: 既定Chapterプロジェクト初期化関数
    /// 処理概要: 指定 pages を既定 Chapter に格納してプロジェクトを作成します。
    ///
    /// - Parameters:
    ///   - version: `.ogp` 形式のバージョン。
    ///   - name: プロジェクト表示名。
    ///   - repositoryRoot: `.ogp` から見たリポジトリルート。
    ///   - htmlRoot: HTML 成果物を置く public ルート。
    ///   - cssLibrary: OpenGraphite.css の参照パス。
    ///   - pages: 既定 Chapter に入れるページ一覧。
    init(
        version: String,
        name: String,
        repositoryRoot: String?,
        htmlRoot: String,
        cssLibrary: String,
        pages: [OpenGraphitePage],
        collections: [OpenGraphiteComponentCollection] = [],
        components: [OpenGraphitePage] = []
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.chapters = [
            OpenGraphiteChapter(
                id: OpenGraphiteChapter.defaultID,
                title: OpenGraphiteChapter.defaultTitle,
                pages: pages
            )
        ]
        self.collections = Self.resolvedCollections(collections: collections, components: components)
    }

    /// 論理名（日本語）: Chapterプロジェクト初期化関数
    /// 処理概要: Chapter 配列を正本としてプロジェクトを作成します。
    ///
    /// - Parameters:
    ///   - version: `.ogp` 形式のバージョン。
    ///   - name: プロジェクト表示名。
    ///   - repositoryRoot: `.ogp` から見たリポジトリルート。
    ///   - htmlRoot: HTML 成果物を置く public ルート。
    ///   - cssLibrary: OpenGraphite.css の参照パス。
    ///   - chapters: プロジェクトが保持する Chapter 一覧。
    init(
        version: String,
        name: String,
        repositoryRoot: String?,
        htmlRoot: String,
        cssLibrary: String,
        chapters: [OpenGraphiteChapter],
        collections: [OpenGraphiteComponentCollection] = [],
        components: [OpenGraphitePage] = []
    ) {
        self.version = version
        self.name = name
        self.repositoryRoot = repositoryRoot
        self.htmlRoot = htmlRoot
        self.cssLibrary = cssLibrary
        self.chapters = chapters
        self.collections = Self.resolvedCollections(collections: collections, components: components)
    }

    /// 論理名（日本語）: 内部ID正規化関数
    /// 処理概要: Chapter と HTML カードの内部 ID を `.ogp` 内で一意になるよう補完・重複解消します。
    ///
    /// - Returns: 内部 ID が一意に補完された project 定義。
    func normalizedInternalIDs() -> OpenGraphiteProject {
        var normalized = self
        var usedManifestIDs: Set<String> = []

        for chapterIndex in normalized.chapters.indices {
            let chapterBase = Self.identityBase(
                preferred: normalized.chapters[chapterIndex].internalID,
                semanticPrefix: "chapter",
                seed: [
                    "chapter",
                    "\(chapterIndex)",
                    normalized.chapters[chapterIndex].id,
                    normalized.chapters[chapterIndex].title ?? ""
                ].joined(separator: "|")
            )
            normalized.chapters[chapterIndex].internalID = Self.uniqueIdentityID(
                base: chapterBase,
                used: &usedManifestIDs
            )

            for pageIndex in normalized.chapters[chapterIndex].pages.indices {
                let page = normalized.chapters[chapterIndex].pages[pageIndex]
                let pageBase = Self.identityBase(
                    preferred: page.internalID,
                    semanticPrefix: "page",
                    seed: [
                        "page",
                        "\(chapterIndex)",
                        "\(pageIndex)",
                        page.id,
                        page.title ?? "",
                        page.path
                    ].joined(separator: "|")
                )
                normalized.chapters[chapterIndex].pages[pageIndex].internalID = Self.uniqueIdentityID(
                    base: pageBase,
                    used: &usedManifestIDs
                )
            }
        }

        for collectionIndex in normalized.collections.indices {
            let collectionBase = Self.identityBase(
                preferred: normalized.collections[collectionIndex].internalID,
                semanticPrefix: "collection",
                seed: [
                    "collection",
                    "\(collectionIndex)",
                    normalized.collections[collectionIndex].id,
                    normalized.collections[collectionIndex].title ?? ""
                ].joined(separator: "|")
            )
            normalized.collections[collectionIndex].internalID = Self.uniqueIdentityID(
                base: collectionBase,
                used: &usedManifestIDs
            )

            for componentIndex in normalized.collections[collectionIndex].components.indices {
                let component = normalized.collections[collectionIndex].components[componentIndex]
                let componentBase = Self.identityBase(
                    preferred: component.internalID,
                    semanticPrefix: "component",
                    seed: [
                        "component",
                        "\(collectionIndex)",
                        "\(componentIndex)",
                        component.id,
                        component.title ?? "",
                        component.path
                    ].joined(separator: "|")
                )
                normalized.collections[collectionIndex].components[componentIndex].internalID = Self.uniqueIdentityID(
                    base: componentBase,
                    used: &usedManifestIDs
                )
            }
        }

        return normalized
    }

    /// 論理名（日本語）: Component Collection解決関数
    /// 処理概要: 明示 Collection がない場合に既定 Collection へ component 配列を格納します。
    ///
    /// - Parameters:
    ///   - collections: 明示された Collection 一覧。
    ///   - components: 既定 Collection に格納する component 一覧。
    /// - Returns: project に保持する Collection 一覧。
    private static func resolvedCollections(
        collections: [OpenGraphiteComponentCollection],
        components: [OpenGraphitePage]
    ) -> [OpenGraphiteComponentCollection] {
        if !collections.isEmpty || components.isEmpty {
            return collections
        }
        return [
            OpenGraphiteComponentCollection(
                id: OpenGraphiteComponentCollection.defaultID,
                title: OpenGraphiteComponentCollection.defaultTitle,
                components: components
            )
        ]
    }

    /// 論理名（日本語）: 内部ID基底値生成関数
    /// 処理概要: 既存の不透明内部 ID を維持し、未補完または意味付き ID の場合は不透明 ID を生成します。
    ///
    /// - Parameters:
    ///   - preferred: 既存の内部 ID。
    ///   - semanticPrefix: 意味付き ID 判定に使う prefix。
    ///   - seed: 不透明 ID 生成の入力値。
    /// - Returns: 内部 ID の基底値。
    private static func identityBase(preferred: String, semanticPrefix: String, seed: String) -> String {
        let preferredSlug = slug(preferred)
        if !preferredSlug.isEmpty && !isSemanticInternalID(preferredSlug, prefix: semanticPrefix) {
            return preferredSlug
        }

        return opaqueIdentityID(seed: seed)
    }

    /// 論理名（日本語）: 一意内部ID生成関数
    /// 処理概要: 既に使われた ID と衝突する場合は `-2` 以降の suffix を付けます。
    ///
    /// - Parameters:
    ///   - base: slug 化済み基底値。
    ///   - used: 使用済み ID 集合。
    /// - Returns: 使用済み集合に追加済みの一意 ID。
    private static func uniqueIdentityID(base: String, used: inout Set<String>) -> String {
        let normalizedBase = base.isEmpty ? "item" : base
        var candidate = normalizedBase
        var index = 2
        while used.contains(candidate) {
            candidate = "\(normalizedBase)-\(index)"
            index += 1
        }
        used.insert(candidate)
        return candidate
    }

    /// 論理名（日本語）: 意味付き内部ID判定関数
    /// 処理概要: `chapter-*` / `page-*` / `component-*` 形式の意味を持つ内部 ID かを判定します。
    ///
    /// - Parameters:
    ///   - id: 判定対象 ID。
    ///   - prefix: 期待する旧 prefix。
    /// - Returns: 意味付き内部 ID であれば `true`。
    private static func isSemanticInternalID(_ id: String, prefix: String) -> Bool {
        id == prefix || id.hasPrefix("\(prefix)-")
    }

    /// 論理名（日本語）: 不透明内部ID生成関数
    /// 処理概要: seed を安定 hash 化し、表示名を含まない短い base36 ID を生成します。
    ///
    /// - Parameter seed: ID 生成元 seed。
    /// - Returns: 意味を持たない内部 ID。
    private static func opaqueIdentityID(seed: String) -> String {
        String(stableHash(seed), radix: 36)
    }

    /// 論理名（日本語）: 安定hash関数
    /// 処理概要: プロセスに依存しない FNV-1a 64bit hash を返します。
    ///
    /// - Parameter value: hash 化する文字列。
    /// - Returns: 64bit hash。
    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    /// 論理名（日本語）: 内部ID用slug生成関数
    /// 処理概要: 参照文字列に使いやすい英数字、ハイフン、アンダースコアだけの小文字 ID へ正規化します。
    ///
    /// - Parameter value: 正規化する文字列。
    /// - Returns: slug 化した文字列。
    private static func slug(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_-")
        var result = ""
        for character in value.lowercased() {
            result.append(allowed.contains(character) ? character : "-")
        }
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result
    }
}

/// 論理名（日本語）: OpenGraphite Chapter定義
/// 概要: Pages の上位概念として、独立したキャンバスに配置されるページ群を表します。
///
/// プロパティ:
/// - `id`: Chapter 識別子。
/// - `internalID`: `.ogp` 内で Chapter を一意に指す内部識別子。
/// - `title`: UI 表示用タイトル。未指定時は `id` を表示名として使います。
/// - `pages`: Chapter 内の HTML ページ一覧。
struct OpenGraphiteChapter: Codable, Equatable, Identifiable {
    static let defaultID = "main"
    static let defaultTitle = "Main"

    var id: String
    var internalID: String
    var title: String?
    var pages: [OpenGraphitePage]

    var displayName: String {
        guard let title, !title.isEmpty else { return id }
        return title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case internalID
        case title
        case pages
    }

    /// 論理名（日本語）: Chapter初期化関数
    /// 処理概要: 表示用 ID と内部 ID、ページ一覧から Chapter 定義を構成します。
    ///
    /// - Parameters:
    ///   - id: 表示用 Chapter ID。
    ///   - internalID: `.ogp` 内で一意な内部 ID。空の場合は読み込み時に補完されます。
    ///   - title: UI 表示タイトル。
    ///   - pages: Chapter に含まれる page entry 一覧。
    init(id: String, internalID: String = "", title: String? = nil, pages: [OpenGraphitePage]) {
        self.id = id
        self.internalID = internalID
        self.title = title
        self.pages = pages
    }

    /// 論理名（日本語）: Chapterデコード初期化関数
    /// 処理概要: `internalID` が未指定の場合は空として読み込み、正規化時に補完します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        internalID = try container.decodeIfPresent(String.self, forKey: .internalID) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title)
        pages = try container.decode([OpenGraphitePage].self, forKey: .pages)
    }

    /// 論理名（日本語）: Chapterエンコード関数
    /// 処理概要: 内部 ID が未補完の場合は省略します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if !internalID.isEmpty {
            try container.encode(internalID, forKey: .internalID)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(pages, forKey: .pages)
    }
}

/// 論理名（日本語）: OpenGraphite Component Collection定義
/// 概要: Components セグメントの上位概念として、独立したキャンバスに配置される component master 群を表します。
///
/// プロパティ:
/// - `id`: Collection 識別子。
/// - `internalID`: `.ogp` 内で Collection を一意に指す内部識別子。
/// - `title`: UI 表示用タイトル。未指定時は `id` を表示名として使います。
/// - `components`: Collection 内の component master HTML 一覧。
struct OpenGraphiteComponentCollection: Codable, Equatable, Identifiable {
    static let defaultID = "main"
    static let defaultTitle = "Main"

    var id: String
    var internalID: String
    var title: String?
    var components: [OpenGraphitePage]

    var displayName: String {
        guard let title, !title.isEmpty else { return id }
        return title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case internalID
        case title
        case components
    }

    /// 論理名（日本語）: Component Collection初期化関数
    /// 処理概要: 表示用 ID と内部 ID、component 一覧から Collection 定義を構成します。
    ///
    /// - Parameters:
    ///   - id: 表示用 Collection ID。
    ///   - internalID: `.ogp` 内で一意な内部 ID。空の場合は読み込み時に補完されます。
    ///   - title: UI 表示タイトル。
    ///   - components: Collection に含まれる component entry 一覧。
    init(id: String, internalID: String = "", title: String? = nil, components: [OpenGraphitePage]) {
        self.id = id
        self.internalID = internalID
        self.title = title
        self.components = components
    }

    /// 論理名（日本語）: Component Collectionデコード初期化関数
    /// 処理概要: `internalID` が未指定の場合は空として読み込み、正規化時に補完します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        internalID = try container.decodeIfPresent(String.self, forKey: .internalID) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title)
        components = try container.decode([OpenGraphitePage].self, forKey: .components)
    }

    /// 論理名（日本語）: Component Collectionエンコード関数
    /// 処理概要: 内部 ID が未補完の場合は省略します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if !internalID.isEmpty {
            try container.encode(internalID, forKey: .internalID)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(components, forKey: .components)
    }
}

/// 論理名（日本語）: OpenGraphiteページ定義
/// 概要: `.ogp` 内の単一 HTML ページとキャンバス配置情報を表します。
///
/// プロパティ:
/// - `id`: ページ識別子。
/// - `internalID`: `.ogp` 内で HTML カードを一意に指す内部識別子。
/// - `title`: UI 表示用タイトル。未指定時は `id` を使います。
/// - `path`: `htmlRoot` から見た HTML ファイルパス。
/// - `canvas`: キャンバス上の配置とサイズ。
struct OpenGraphitePage: Codable, Equatable, Identifiable {
    var id: String
    var internalID: String
    var title: String?
    var path: String
    var canvas: OpenGraphiteCanvas

    var displayName: String {
        guard let title, !title.isEmpty else { return id }
        return title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case internalID
        case title
        case path
        case canvas
    }

    /// 論理名（日本語）: ページ定義初期化関数
    /// 処理概要: 表示用 ID、内部 ID、HTML path、canvas 配置から page entry を構成します。
    ///
    /// - Parameters:
    ///   - id: 表示用 page ID。
    ///   - internalID: `.ogp` 内で一意な内部 ID。空の場合は読み込み時に補完されます。
    ///   - title: UI 表示タイトル。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    init(id: String, internalID: String = "", title: String? = nil, path: String, canvas: OpenGraphiteCanvas) {
        self.id = id
        self.internalID = internalID
        self.title = title
        self.path = path
        self.canvas = canvas
    }

    /// 論理名（日本語）: ページデコード初期化関数
    /// 処理概要: `internalID` が未指定の場合は空として読み込み、正規化時に補完します。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        internalID = try container.decodeIfPresent(String.self, forKey: .internalID) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title)
        path = try container.decode(String.self, forKey: .path)
        canvas = try container.decode(OpenGraphiteCanvas.self, forKey: .canvas)
    }

    /// 論理名（日本語）: ページエンコード関数
    /// 処理概要: 内部 ID が未補完の場合は省略します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if !internalID.isEmpty {
            try container.encode(internalID, forKey: .internalID)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(path, forKey: .path)
        try container.encode(canvas, forKey: .canvas)
    }
}

/// 論理名（日本語）: OpenGraphiteキャンバス定義
/// 概要: ページプレビューをキャンバスへ配置するための座標とサイズを表します。
///
/// プロパティ:
/// - `name`: 同一キャンバス内でフロー解決対象を絞り込む配置名。名前なしは空文字として明示します。
/// - `x`: キャンバス上の X 座標。
/// - `y`: キャンバス上の Y 座標。
/// - `width`: プレビュー幅。
/// - `height`: プレビュー高さ。
/// - `previewContext`: エディター内プレビューへ注入する runtime Mock State。
struct OpenGraphiteCanvas: Codable, Equatable {
    var name: String = ""
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var previewContext: OpenGraphitePreviewContext = .empty

    private enum CodingKeys: String, CodingKey {
        case name
        case x
        case y
        case width
        case height
        case previewContext
    }

    /// フロー解決で比較する正規化済み配置名。
    var flowResolutionName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// UI 表示向けの配置名。未指定時は `nil` を返します。
    var displayName: String? {
        let normalizedName = flowResolutionName
        return normalizedName.isEmpty ? nil : normalizedName
    }

    /// 解像度を UI 表示向けに短く整形した文字列。
    var resolutionLabel: String {
        "\(Self.displayValue(width)) x \(Self.displayValue(height))"
    }

    /// キャンバス座標を UI 表示向けに短く整形した文字列。
    var positionLabel: String {
        "\(Self.displayValue(x)), \(Self.displayValue(y))"
    }

    /// 論理名（日本語）: キャンバス定義初期化関数
    /// 処理概要: キャンバス配置と preview Mock State を明示値から構成します。
    ///
    /// - Parameters:
    ///   - name: フロー解決用の配置名。
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: プレビュー幅。
    ///   - height: プレビュー高さ。
    ///   - previewContext: エディター内プレビューへ注入する runtime Mock State。
    init(
        name: String = "",
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        previewContext: OpenGraphitePreviewContext = .empty
    ) {
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.previewContext = previewContext
    }

    /// 論理名（日本語）: キャンバスデコード初期化関数
    /// 処理概要: 旧 `.ogp` との互換性のため preview Mock State 未指定時は空として読み込みます。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        previewContext = try container.decodeIfPresent(OpenGraphitePreviewContext.self, forKey: .previewContext) ?? .empty
    }

    /// 論理名（日本語）: キャンバスエンコード関数
    /// 処理概要: preview Mock State が空の場合は既存 `.ogp` 形式を保つため省略します。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        if !previewContext.isEmpty {
            try container.encode(previewContext, forKey: .previewContext)
        }
    }

    /// 論理名（日本語）: キャンバス値表示関数
    /// 処理概要: キャンバス座標や解像度を UI 表示向けに整数優先の短い文字列へ変換します。
    ///
    /// - Parameter value: 表示するキャンバス数値。
    /// - Returns: 整数に近い値は整数、それ以外は小数1桁の文字列。
    private static func displayValue(_ value: Double) -> String {
        let roundedValue = value.rounded()
        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", value)
    }
}

/// 論理名（日本語）: OpenGraphiteプレビューContext
/// 概要: エディター内 preview にだけ注入する runtime mock state を表します。
///
/// プロパティ:
/// - `locale`: 旧形式の preview locale。decode 互換用で、新規保存では使いません。
/// - `direction`: 旧形式の preview direction。decode 互換用で、新規保存では使いません。
/// - `fieldMocks`: runtime script が初期状態として参照する任意の mock field 値。
struct OpenGraphitePreviewContext: Codable, Equatable {
    static let empty = OpenGraphitePreviewContext(locale: "", direction: "", fieldMocks: [:])

    var locale: String
    var direction: String
    var fieldMocks: [String: String]

    var isEmpty: Bool {
        fieldMocks.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case locale
        case direction
        case fieldMocks
    }

    /// 論理名（日本語）: プレビューContext初期化関数
    /// 処理概要: runtime mock state と旧形式 preview fields を正規化して保持します。
    ///
    /// - Parameters:
    ///   - locale: 旧形式の preview locale。
    ///   - direction: 旧形式の preview direction。
    ///   - fieldMocks: JavaScript runtime mock state。
    init(locale: String = "", direction: String = "", fieldMocks: [String: String] = [:]) {
        self.locale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        self.direction = direction.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fieldMocks = fieldMocks
            .reduce(into: [String: String]()) { result, item in
                let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }
                result[key] = item.value
            }
    }

    /// 論理名（日本語）: プレビューContextデコード初期化関数
    /// 処理概要: 省略された field を空値として読み込みます。
    ///
    /// - Parameter decoder: JSON decoder。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            locale: try container.decodeIfPresent(String.self, forKey: .locale) ?? "",
            direction: try container.decodeIfPresent(String.self, forKey: .direction) ?? "",
            fieldMocks: try container.decodeIfPresent([String: String].self, forKey: .fieldMocks) ?? [:]
        )
    }

    /// 論理名（日本語）: プレビューContextエンコード関数
    /// 処理概要: Mock State だけを JSON へ保存し、旧形式 locale / direction は再保存しません。
    ///
    /// - Parameter encoder: JSON encoder。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !fieldMocks.isEmpty {
            try container.encode(fieldMocks, forKey: .fieldMocks)
        }
    }
}

/// 論理名（日本語）: 読み込み済みOpenGraphiteプロジェクト
/// 概要: `.ogp` の内容に加えて、ファイル URL と解決済みリポジトリルートを保持します。
///
/// プロパティ:
/// - `project`: デコード済みプロジェクト定義。
/// - `fileURL`: 読み込んだ `.ogp` の URL。
/// - `rootURL`: HTML と CSS を解決するリポジトリルート URL。
struct LoadedOpenGraphiteProject: Identifiable, Equatable {
    let id = UUID()
    var project: OpenGraphiteProject
    var fileURL: URL
    var rootURL: URL

    var cssURL: URL {
        rootURL.appendingPathComponent(project.cssLibrary)
    }

    /// 論理名（日本語）: HTMLページURL解決関数
    /// 処理概要: `rootURL`、`htmlRoot`、ページパスを連結して表示対象 HTML の URL を返します。
    ///
    /// - Parameter page: URL を解決するページ定義。
    /// - Returns: 対象 HTML ファイルの URL。
    func htmlURL(for page: OpenGraphitePage) -> URL {
        rootURL
            .appendingPathComponent(project.htmlRoot)
            .appendingPathComponent(page.path)
    }
}

/// 論理名（日本語）: キャンバス表示セグメント
/// 概要: エディタ中央キャンバスが通常 Pages と Components のどちらを表示しているかを表します。
///
/// 定義内容:
/// - `pages`: `.ogp` の `chapters[].pages[]` を表示する通常ページ編集セグメント。
/// - `components`: `.ogp` の `collections[].components[]` を表示する component master 編集セグメント。
enum OpenGraphiteCanvasSegment: String, Equatable {
    case pages
    case components

    var title: String {
        switch self {
        case .pages:
            return "Pages"
        case .components:
            return "Components"
        }
    }
}

/// 論理名（日本語）: プロジェクト資源選択
/// 概要: 左カラムの Project セグメントで選択できる実装資源または依存性を表します。
///
/// 定義内容:
/// - `overview`: project manifest と主要ルートの概要。
/// - `htmlRoot`: HTML root 依存性。
/// - `cssLibrary`: CSS library 依存性。
/// - `runtime`: HTML から参照される実装 runtime。
/// - `i18nRuntime`: i18n runtime 設定。
/// - `localeResource`: locale JSON resource。
enum OpenGraphiteProjectResourceSelection: Hashable, Equatable {
    case overview
    case htmlRoot
    case cssLibrary
    case runtime(path: String)
    case i18nRuntime
    case localeResource(locale: String, path: String)

    var title: String {
        switch self {
        case .overview:
            return "Project"
        case .htmlRoot:
            return "HTML Root"
        case .cssLibrary:
            return "CSS"
        case .runtime:
            return "Runtime"
        case .i18nRuntime:
            return "I18n Runtime"
        case .localeResource(let locale, _):
            return "\(locale).json"
        }
    }

    var detail: String {
        switch self {
        case .overview:
            return "All resources"
        case .htmlRoot:
            return "public root"
        case .cssLibrary:
            return "OpenGraphite CSS"
        case .runtime(let path):
            return path
        case .i18nRuntime:
            return "implementation i18n config"
        case .localeResource(_, let path):
            return path
        }
    }
}
