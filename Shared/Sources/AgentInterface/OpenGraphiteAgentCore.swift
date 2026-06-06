import Foundation

/// 論理名（日本語）: Agent向けノード
/// 概要: CLI / MCP が返す OpenGraphite HTML ノードの JSON 表現です。
///
/// プロパティ:
/// - `id`: `data-og-id`。
/// - `internalID`: `data-og-internal-id`。
/// - `tagName`: 小文字化した HTML タグ名。
/// - `type`: `data-og-type`。
/// - `layout`: `data-og-layout`。
/// - `role`: `data-og-role`。
/// - `cssVariables`: inline style 内の `--og-*` 変数。
/// - `hidden`: `data-og-hidden` 状態。
/// - `locked`: `data-og-locked` 状態。
/// - `depth`: DOM 階層深度。
/// - `parentID`: 最も近い OpenGraphite 親ノードの `data-og-id`。
/// - `textContent`: ノード配下のプレーンテキスト。
/// - `attributes`: 開始タグの属性辞書。
struct OpenGraphiteAgentNode: Codable, Equatable {
    var id: String
    var internalID: String
    var tagName: String
    var type: String
    var layout: String?
    var role: String?
    var cssVariables: [String: String]
    var hidden: Bool
    var locked: Bool
    var depth: Int
    var parentID: String?
    var textContent: String?
    var attributes: [String: String]
}

/// 論理名（日本語）: Agent診断
/// 概要: CLI / MCP / validation が返す問題、警告、情報メッセージを表します。
///
/// プロパティ:
/// - `severity`: error、warning、info。
/// - `code`: 機械判定用コード。
/// - `message`: 人間向け説明。
/// - `path`: 対象ファイルパス。
/// - `nodeID`: 関連する `data-og-id`。
struct OpenGraphiteDiagnostic: Codable, Equatable {
    var severity: OpenGraphiteDiagnosticSeverity
    var code: String
    var message: String
    var path: String?
    var nodeID: String?
}

/// 論理名（日本語）: Agent診断重要度
/// 概要: validation 結果の重要度を表します。
///
/// 定義内容:
/// - `error`: write を止める問題。
/// - `warning`: write は止めないが注意が必要な問題。
/// - `info`: 補助情報。
enum OpenGraphiteDiagnosticSeverity: String, Codable, Equatable {
    case error
    case warning
    case info
}

/// 論理名（日本語）: ページグラフ応答
/// 概要: HTML ページから抽出した node graph と diagnostics を保持します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `nodes`: 抽出された node 一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageGraph: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索応答
/// 概要: 条件に一致した OpenGraphite node 一覧を返します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 対象 HTML URL。
/// - `query`: 適用した検索条件。
/// - `nodes`: 条件に一致した node。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteNodeQueryResult: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var query: OpenGraphiteNodeQuery
    var nodes: [OpenGraphiteAgentNode]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ノード検索条件
/// 概要: CLI / MCP が `data-og-id`、type、role、tag、text で node を絞り込む条件です。
///
/// プロパティ:
/// - `idContains`: `data-og-id` に含まれる文字列。
/// - `type`: `data-og-type` の完全一致。
/// - `role`: `data-og-role` の完全一致。
/// - `tag`: tag name の完全一致。
/// - `textContains`: textContent に含まれる文字列。
struct OpenGraphiteNodeQuery: Codable, Equatable {
    var idContains: String?
    var type: String?
    var role: String?
    var tag: String?
    var textContains: String?
}

/// 論理名（日本語）: 検証応答
/// 概要: HTML または project の validation 結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `valid`: error がない場合は `true`。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteValidationResult: Codable, Equatable {
    var schemaVersion: String
    var valid: Bool
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: ページ作成応答
/// 概要: HTML page file 作成結果と作成後 graph を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: ファイルを書き込んだ場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `graph`: 作成後 page graph。
/// - `diagnostics`: 検証結果。
struct OpenGraphitePageWriteResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var path: String
    var graph: OpenGraphitePageGraph?
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクト要約応答
/// 概要: `.ogp` と解決済み HTML / CSS 参照を CLI / MCP 向けに表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `projectName`: プロジェクト名。
/// - `projectURL`: `.ogp` の URL。
/// - `rootURL`: 解決済みリポジトリルート。
/// - `htmlRoot`: HTML root。
/// - `cssURL`: CSS library URL。
/// - `chapters`: Chapter 要約一覧。
/// - `collections`: Collection 要約一覧。
/// - `pages`: 全 Chapter のページ要約一覧。
/// - `components`: 全 Collection の component canvas 要約一覧。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectSummary: Codable, Equatable {
    var schemaVersion: String
    var projectName: String
    var projectURL: String
    var rootURL: String
    var htmlRoot: String
    var cssURL: String
    var chapters: [OpenGraphiteChapterSummary]
    var collections: [OpenGraphiteComponentCollectionSummary]
    var pages: [OpenGraphitePageSummary]
    var components: [OpenGraphitePageSummary]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Chapter要約
/// 概要: `.ogp` 内の Chapter と、その Chapter に属する page summary を JSON 出力向けに表します。
///
/// プロパティ:
/// - `id`: Chapter ID。
/// - `internalID`: `.ogp` 内で一意な Chapter 内部 ID。
/// - `index`: `.ogp` 内の Chapter index。
/// - `title`: Chapter 表示名。
/// - `pages`: Chapter 内のページ要約一覧。
struct OpenGraphiteChapterSummary: Codable, Equatable {
    var id: String
    var internalID: String
    var index: Int
    var title: String?
    var pages: [OpenGraphitePageSummary]
}

/// 論理名（日本語）: Component Collection要約
/// 概要: `.ogp` 内の Collection と、その Collection に属する component summary を JSON 出力向けに表します。
///
/// プロパティ:
/// - `id`: Collection ID。
/// - `internalID`: `.ogp` 内で一意な Collection 内部 ID。
/// - `index`: `.ogp` 内の Collection index。
/// - `title`: Collection 表示名。
/// - `components`: Collection 内の component canvas 要約一覧。
struct OpenGraphiteComponentCollectionSummary: Codable, Equatable {
    var id: String
    var internalID: String
    var index: Int
    var title: String?
    var components: [OpenGraphitePageSummary]
}

/// 論理名（日本語）: ページ要約
/// 概要: `.ogp` 内のページと解決済み HTML URL を JSON 出力向けに表します。
///
/// プロパティ:
/// - `chapterID`: 所属 Chapter ID。Components では `nil`。
/// - `chapterInternalID`: 所属 Chapter 内部 ID。Components では `nil`。
/// - `collectionID`: 所属 Collection ID。Pages セグメントでは `nil`。
/// - `collectionInternalID`: 所属 Collection 内部 ID。Pages セグメントでは `nil`。
/// - `segment`: `pages` または `components`。
/// - `id`: ページ ID。
/// - `internalID`: `.ogp` 内で一意な HTML カード内部 ID。
/// - `referenceID`: `segment` と内部 ID を組み合わせた agent 向け page 参照 ID。
/// - `chapterIndex`: Pages セグメント内の Chapter index。
/// - `collectionIndex`: Components 内の Collection index。
/// - `pageIndex`: Chapter または Collection 配列内の page index。
/// - `path`: `htmlRoot` からの相対パス。
/// - `htmlURL`: 解決済み HTML URL。
/// - `canvas`: キャンバス定義。
struct OpenGraphitePageSummary: Codable, Equatable {
    var chapterID: String?
    var chapterInternalID: String?
    var collectionID: String?
    var collectionInternalID: String?
    var segment: String
    var id: String
    var internalID: String
    var referenceID: String
    var chapterIndex: Int?
    var collectionIndex: Int?
    var pageIndex: Int
    var path: String
    var htmlURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ参照
/// 概要: `.ogp` の page / component canvas から解決された編集対象 HTML と読み取り許可範囲を表します。
///
/// プロパティ:
/// - `projectURL`: 参照元 `.ogp` の URL。
/// - `segment`: 対象が Pages / Components のどちらに属するか。
/// - `chapterID`: `.ogp` 内の Chapter ID。Components では `nil`。
/// - `chapterInternalID`: `.ogp` 内で一意な Chapter 内部 ID。Components では `nil`。
/// - `collectionID`: `.ogp` 内の Collection ID。Pages セグメントでは `nil`。
/// - `collectionInternalID`: `.ogp` 内で一意な Collection 内部 ID。Pages セグメントでは `nil`。
/// - `pageID`: ``.ogp` 内の page 参照 ID。
/// - `pageInternalID`: `.ogp` 内で一意な HTML カード内部 ID。
/// - `referenceID`: agent 向け page 参照 ID。
/// - `path`: `htmlRoot` から見た HTML path。
/// - `htmlURL`: 解決済み HTML URL。
/// - `rootURL`: HTML / CSS / assets の読み取り許可ルート。
/// - `canvas`: `.ogp` 上の canvas 配置。
struct OpenGraphiteProjectPageReference: Codable, Equatable {
    var projectURL: String
    var segment: String
    var chapterID: String?
    var chapterInternalID: String?
    var collectionID: String?
    var collectionInternalID: String?
    var pageID: String
    var pageInternalID: String
    var referenceID: String
    var path: String
    var htmlURL: String
    var rootURL: String
    var canvas: OpenGraphiteCanvas
}

/// 論理名（日本語）: プロジェクトページ作成応答
/// 概要: `.ogp` を経由した HTML 作成と page entry 登録の結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `created`: HTML と `.ogp` の両方が更新された場合は `true`。
/// - `project`: 更新後 project summary。
/// - `page`: 追加された page summary。
/// - `htmlPath`: 作成対象 HTML パス。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteProjectPageCreateResult: Codable, Equatable {
    var schemaVersion: String
    var created: Bool
    var project: OpenGraphiteProjectSummary?
    var page: OpenGraphitePageSummary?
    var htmlPath: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: プロジェクトページ内部ターゲット
/// 概要: core 内部で `.ogp` page と解決済み HTML URL をまとめて渡すための値です。
///
/// プロパティ:
/// - `loadedProject`: 読み込み済み `.ogp`。
/// - `segment`: 対象が Pages / Components のどちらに属するか。
/// - `chapter`: 対象 page entry を含む Chapter。Components では `nil`。
/// - `collection`: 対象 component entry を含む Collection。Pages セグメントでは `nil`。
/// - `page`: 対象 page entry。
/// - `htmlURL`: 解決済み HTML URL。
private struct OpenGraphiteProjectPageTarget {
    var loadedProject: LoadedOpenGraphiteProject
    var segment: String
    var chapter: OpenGraphiteChapter?
    var collection: OpenGraphiteComponentCollection?
    var page: OpenGraphitePage
    var htmlURL: URL
}

/// 論理名（日本語）: プロジェクトページ位置
/// 概要: `.ogp` 内で対象 HTML が属するセグメント、グループ index、page index を表します。
///
/// プロパティ:
/// - `segment`: Pages / Components の区分。
/// - `groupIndex`: Chapter または Collection 配列内の位置。
/// - `pageIndex`: Chapter 内 pages または Collection 内 components 配列の位置。
private struct OpenGraphiteProjectPageLocation: Equatable {
    var segment: OpenGraphiteCanvasSegment
    var groupIndex: Int
    var pageIndex: Int
}

/// 論理名（日本語）: i18n検出用script source
/// 概要: HTML inline script と解決済み外部 script を同じ形で検査するための内部値です。
///
/// プロパティ:
/// - `url`: 外部 script の file URL。inline script の場合は HTML URL。
/// - `displayPath`: Inspector / CLI に表示する path。
/// - `source`: script 本文。
/// - `isInline`: HTML inline script か。
private struct OpenGraphiteI18nScriptSource {
    var url: URL
    var displayPath: String
    var source: String
    var isInline: Bool
}

/// 論理名（日本語）: HTML変更応答
/// 概要: node 単位編集の結果 HTML と diagnostics を保持します。
///
/// プロパティ:
/// - `html`: 更新済み HTML。
/// - `diagnostics`: 変更時に発生した diagnostics。
struct OpenGraphiteHTMLMutationResult: Equatable {
    var html: String
    var diagnostics: [OpenGraphiteDiagnostic]

    /// 論理名（日本語）: 失敗結果生成関数
    /// 処理概要: 単一 diagnostic を持つ HTML 変更失敗結果を作ります。
    ///
    /// - Parameters:
    ///   - html: 元の HTML。
    ///   - diagnostic: 失敗理由。
    /// - Returns: 失敗結果。
    static func failure(html: String, diagnostic: OpenGraphiteDiagnostic) -> OpenGraphiteHTMLMutationResult {
        OpenGraphiteHTMLMutationResult(html: html, diagnostics: [diagnostic])
    }
}

/// 論理名（日本語）: Agent編集応答
/// 概要: CLI / MCP の write operation が返す対象 node と diagnostics を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: ファイルを書き換えた場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `node`: 更新後 node。
/// - `diagnostics`: 検証結果。
/// - `insertedNodes`: 挿入操作で新たに増えた node。
struct OpenGraphiteEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var node: OpenGraphiteAgentNode?
    var diagnostics: [OpenGraphiteDiagnostic]
    var insertedNodes: [OpenGraphiteAgentNode]?
}

/// 論理名（日本語）: HTML Document Context編集応答
/// 概要: `<html>` の document attribute と binding metadata の更新結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: HTML ファイルを書き換えた場合は `true`。
/// - `path`: 対象 HTML パス。
/// - `context`: 保存後の HTML document context。
/// - `diagnostics`: 検証結果。
struct OpenGraphiteHTMLDocumentContextResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var context: OpenGraphiteHTMLDocumentContext
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n adapter種別
/// 概要: HTML 実装 runtime から検出した i18n adapter の種類を表します。
///
/// 定義内容:
/// - `i18next`: `i18n.init({...})` 形式の i18next 系設定。
/// - `unknown`: 自動検出できない、または未対応の設定。
enum OpenGraphiteI18nAdapter: String, Codable, Equatable {
    case i18next
    case unknown
}

/// 論理名（日本語）: i18n設定値source
/// 概要: i18n 設定値が literal として編集可能か、外部式として readonly かを表します。
///
/// 定義内容:
/// - `literal`: 文字列 literal として検出でき、OpenGraphite から正本へ書き戻せる可能性がある値。
/// - `external`: env 参照、関数式、識別子など、OpenGraphite が勝手に書き換えない値。
/// - `missing`: 設定が見つからない値。
enum OpenGraphiteI18nConfigSource: String, Codable, Equatable {
    case literal
    case external
    case missing
}

/// 論理名（日本語）: i18n設定プロパティ
/// 概要: `lng`、`fallbackLng`、`backend.loadPath` など検出対象の値と編集可否を表します。
///
/// プロパティ:
/// - `source`: literal / external / missing。
/// - `value`: literal の値。
/// - `expression`: external と判定した式の短い表示値。
/// - `editable`: OpenGraphite から書き戻せるか。
struct OpenGraphiteI18nConfigProperty: Codable, Equatable {
    var source: OpenGraphiteI18nConfigSource
    var value: String?
    var expression: String?
    var editable: Bool
}

/// 論理名（日本語）: i18n locale resource状態
/// 概要: locale JSON の解決先、存在有無、編集可否を Inspector / CLI へ返します。
///
/// プロパティ:
/// - `locale`: locale 名。
/// - `path`: 解決済みファイル path。
/// - `exists`: ファイルが存在するか。
/// - `editable`: literal loadPath または推奨 path として OpenGraphite が書き戻せるか。
struct OpenGraphiteI18nResourceStatus: Codable, Equatable {
    var locale: String
    var path: String
    var exists: Bool
    var editable: Bool
}

/// 論理名（日本語）: i18n runtime検査結果
/// 概要: HTML 実装資源から検出した i18n runtime 設定と locale JSON 状態を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `pageURL`: 検査対象 HTML。
/// - `adapter`: 検出した i18n adapter。
/// - `configSource`: 設定を検出した HTML / JS / TS ファイル path。
/// - `lng`: `lng` 設定値。
/// - `fallbackLng`: `fallbackLng` 設定値。
/// - `loadPath`: `backend.loadPath` 設定値。
/// - `localeField`: preview mock として注入できる言語 field 名。
/// - `resources`: locale JSON の状態。
/// - `diagnostics`: 検出時の補助診断。
struct OpenGraphiteI18nRuntimeInspection: Codable, Equatable {
    var schemaVersion: String
    var pageURL: String
    var adapter: OpenGraphiteI18nAdapter
    var configSource: String?
    var lng: OpenGraphiteI18nConfigProperty
    var fallbackLng: OpenGraphiteI18nConfigProperty
    var loadPath: OpenGraphiteI18nConfigProperty
    var localeField: String?
    var resources: [OpenGraphiteI18nResourceStatus]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n推奨設定適用結果
/// 概要: 推奨 runtime script と locale JSON を実装資源へ作成・更新した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: 実装ファイルを書き換えたか。
/// - `pageURL`: 対象 HTML。
/// - `configPath`: 作成または検出した i18n 設定ファイル。
/// - `loadPath`: 推奨 loadPath。
/// - `resources`: locale JSON の状態。
/// - `diagnostics`: 適用時の診断。
struct OpenGraphiteI18nRecommendResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var pageURL: String
    var configPath: String?
    var loadPath: String
    var resources: [OpenGraphiteI18nResourceStatus]
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n resource編集結果
/// 概要: locale JSON の flat key に値を書き戻した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: JSON ファイルを書き換えたか。
/// - `path`: 対象 locale JSON path。
/// - `locale`: 更新 locale。
/// - `key`: 更新 key。
/// - `value`: 保存値。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteI18nResourceEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var path: String
    var locale: String
    var key: String
    var value: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: i18n runtime編集結果
/// 概要: 実装側 i18n 設定ファイルの literal 値を更新した結果を表します。
///
/// プロパティ:
/// - `schemaVersion`: JSON schema バージョン。
/// - `updated`: 実装ファイルを書き換えたか。
/// - `configPath`: 更新対象 i18n 設定ファイル。
/// - `inspection`: 更新後の i18n runtime 検査結果。
/// - `diagnostics`: 編集時の診断。
struct OpenGraphiteI18nRuntimeEditResult: Codable, Equatable {
    var schemaVersion: String
    var updated: Bool
    var configPath: String?
    var inspection: OpenGraphiteI18nRuntimeInspection
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: HTML挿入位置
/// 概要: HTML 断片または既存 node をどこへ配置するかを表します。
///
/// 定義内容:
/// - `before`: 対象 node の直前。
/// - `after`: 対象 node の直後。
/// - `prepend`: 対象 node の最初の子。
/// - `append`: 対象 node の最後の子。
enum OpenGraphiteHTMLInsertionPosition: String, Codable, Equatable {
    case before
    case after
    case prepend
    case append
}

/// 論理名（日本語）: Agent core
/// 概要: `ogkiln` CLI と OpenGraphite MCP server が共有する project / HTML graph / validation / edit 処理です。
///
/// メソッド:
/// - `inspectProject(at:)`: `.ogp` を解決して要約する。
/// - `addProjectPage(projectURL:id:path:canvas:allowDuplicatePath:)`: `.ogp` に page entry を追加する。
/// - `addProjectComponent(projectURL:collectionID:id:path:canvas:)`: `.ogp` に component entry を追加する。
/// - `removeProjectComponent(projectURL:id:deleteFile:)`: `.ogp` から component entry を削除する。
/// - `createProjectPage(projectURL:id:path:canvas:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML 作成と page entry 登録を一体で行う。
/// - `createProjectComponent(projectURL:collectionID:id:path:canvas:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML 作成と component entry 登録を一体で行う。
/// - `projectPageReference(projectURL:pageID:)`: ``.ogp` の page 参照 ID から HTML を解決する。
/// - `placeProjectPage(projectURL:id:name:x:y:width:height:previewFieldMocks:)`: 既存 page entry の canvas 配置と preview mock state を更新する。
/// - `placeProjectComponent(projectURL:id:name:x:y:width:height:previewFieldMocks:)`: 既存 component entry の canvas 配置と preview mock state を更新する。
/// - `setProjectPageHTMLDocumentContext(projectURL:id:context:)`: page HTML 正本の document attribute を更新する。
/// - `setProjectComponentHTMLDocumentContext(projectURL:id:context:)`: component HTML 正本の document attribute を更新する。
/// - `createPage(at:title:lang:stylesheetPath:bodyHTML:overwrite:)`: HTML page file を作成する。
/// - `pageGraph(at:)`: HTML から node graph を抽出する。
/// - `validateHTML(at:)`: HTML を契約に対して検証する。
/// - `setCSSVariable(_:value:nodeID:htmlURL:)`: node 単位で CSS 変数を更新する。
/// - `setAttribute(_:value:nodeID:htmlURL:)`: node 単位で属性を更新する。
/// - `setTextContent(_:nodeID:htmlURL:)`: node の text content を更新する。
/// - `insertHTML(_:anchorNodeID:position:htmlURL:)`: anchor node 基準で HTML 断片を挿入する。
/// - `replaceNodeHTML(_:nodeID:htmlURL:)`: node 全体を HTML 断片で置換する。
/// - `deleteNode(nodeID:htmlURL:)`: node 全体を削除する。
/// - `moveNode(nodeID:targetNodeID:position:htmlURL:)`: 既存 node を移動する。
/// - `copyNode(nodeID:targetNodeID:position:idPrefix:htmlURL:)`: node subtree を複製する。
struct OpenGraphiteAgentCore {
    static let schemaVersion = "0.1"

    var contract: OpenGraphiteContract

    /// 論理名（日本語）: Agent core初期化関数
    /// 処理概要: CLI / MCP で共有する契約を保持します。
    ///
    /// - Parameter contract: 検証に使う OpenGraphite 契約。
    init(contract: OpenGraphiteContract) {
        self.contract = contract
    }

    /// 論理名（日本語）: プロジェクト要約関数
    /// 処理概要: `.ogp` を読み込み、解決済み URL と diagnostics を返します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: project summary。
    func inspectProject(at url: URL) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: url)
        var diagnostics: [OpenGraphiteDiagnostic] = []
        if !FileManager.default.fileExists(atPath: loadedProject.cssURL.path) {
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

        let chapters = loadedProject.project.chapters.enumerated().map { chapterIndex, chapter in
            let pages = chapter.pages.enumerated().map { pageIndex, page in
                pageSummary(
                    for: page,
                    chapter: chapter,
                    collection: nil,
                    chapterIndex: chapterIndex,
                    collectionIndex: nil,
                    pageIndex: pageIndex,
                    segment: "pages",
                    loadedProject: loadedProject
                )
            }
            return OpenGraphiteChapterSummary(
                id: chapter.id,
                internalID: chapter.internalID,
                index: chapterIndex,
                title: chapter.title,
                pages: pages
            )
        }
        let pages = chapters.flatMap(\.pages)
        let collections = loadedProject.project.collections.enumerated().map { collectionIndex, collection in
            let components = collection.components.enumerated().map { pageIndex, page in
                pageSummary(
                    for: page,
                    chapter: nil,
                    collection: collection,
                    chapterIndex: nil,
                    collectionIndex: collectionIndex,
                    pageIndex: pageIndex,
                    segment: "components",
                    loadedProject: loadedProject
                )
            }
            return OpenGraphiteComponentCollectionSummary(
                id: collection.id,
                internalID: collection.internalID,
                index: collectionIndex,
                title: collection.title,
                components: components
            )
        }
        let components = collections.flatMap(\.components)

        return OpenGraphiteProjectSummary(
            schemaVersion: Self.schemaVersion,
            projectName: loadedProject.project.name,
            projectURL: loadedProject.fileURL.path,
            rootURL: loadedProject.rootURL.path,
            htmlRoot: loadedProject.project.htmlRoot,
            cssURL: loadedProject.cssURL.path,
            chapters: chapters,
            collections: collections,
            pages: pages,
            components: components,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページ参照解決関数
    /// 処理概要: ``.ogp` の page 参照 ID から編集対象 HTML と読み取り許可ルートを解決します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 解決済み page reference。
    func projectPageReference(projectURL: URL, pageID: String) throws -> OpenGraphiteProjectPageReference {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let target = try projectPageTarget(loadedProject: loadedProject, pageID: pageID)
        return OpenGraphiteProjectPageReference(
            projectURL: loadedProject.fileURL.path,
            segment: target.segment,
            chapterID: target.chapter?.id,
            chapterInternalID: target.chapter?.internalID,
            collectionID: target.collection?.id,
            collectionInternalID: target.collection?.internalID,
            pageID: target.page.id,
            pageInternalID: target.page.internalID,
            referenceID: pageReferenceID(segment: target.segment, chapter: target.chapter, collection: target.collection, page: target.page),
            path: target.page.path,
            htmlURL: target.htmlURL.path,
            rootURL: loadedProject.rootURL.path,
            canvas: target.page.canvas
        )
    }

    /// 論理名（日本語）: プロジェクトページグラフ生成関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML だけを対象に node graph を生成します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: page graph。
    func pageGraph(projectURL: URL, pageID: String) throws -> OpenGraphitePageGraph {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try pageGraph(at: target.htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ追加関数
    /// 処理概要: `.ogp` の既定 Chapter pages に新しい HTML ページ定義を追加し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - allowDuplicatePath: 同じ HTML path を別 preview canvas として再登録するか。
    /// - Returns: 更新後 project summary。
    func addProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas
    ) throws -> OpenGraphiteProjectSummary {
        try addProjectPage(
            projectURL: projectURL,
            id: id,
            path: path,
            canvas: canvas,
            allowDuplicatePath: false
        )
    }

    /// 論理名（日本語）: プロジェクトページ追加関数
    /// 処理概要: `.ogp` の既定 Chapter pages に新しい HTML ページ定義を追加し、必要な場合は同じ HTML path の再登録を許可します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - allowDuplicatePath: 同じ HTML path を別 preview canvas として再登録するか。
    /// - Returns: 更新後 project summary。
    func addProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        allowDuplicatePath: Bool
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        var project = loadedProject.project
        let targetChapterIndex = try defaultChapterIndex(in: project)
        if project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if !allowDuplicatePath, project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }
        let htmlURL = loadedProject.rootURL.appendingPathComponent(project.htmlRoot).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: "追加する page HTML が見つかりません: \(htmlURL.path)")
        }

        project.chapters[targetChapterIndex].pages.append(OpenGraphitePage(id: id, path: path, canvas: canvas))
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント追加関数
    /// 処理概要: `.ogp` の Collection に既存 HTML component canvas 定義を追加し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - collectionID: 追加先 Collection の ID / 内部 ID / `ogref:collection`。`nil` の場合は既定 Collection。
    ///   - id: 追加する component ID。
    ///   - path: `htmlRoot` から見た component HTML path。
    ///   - canvas: キャンバス配置。
    /// - Returns: 更新後 project summary。
    func addProjectComponent(
        projectURL: URL,
        collectionID: String?,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        var project = loadedProject.project
        if project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page or component id \"\(id)\" は既に存在します。")
        }
        if project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page or component path \"\(path)\" は既に存在します。")
        }
        let htmlURL = loadedProject.rootURL.appendingPathComponent(project.htmlRoot).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: "追加する component HTML が見つかりません: \(htmlURL.path)")
        }

        let collectionIndex = try writableComponentCollectionIndex(in: &project, collectionID: collectionID)
        project.collections[collectionIndex].components.append(OpenGraphitePage(id: id, path: path, canvas: canvas))
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント削除関数
    /// 処理概要: `.ogp` の Collection から component entry を削除し、指定時は HTML file も削除します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 削除する component ID。
    ///   - deleteFile: component HTML file も削除するか。
    /// - Returns: 更新後 project summary。
    func removeProjectComponent(
        projectURL: URL,
        id: String,
        deleteFile: Bool
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let componentLocation = pageLocation(in: project, pageID: id),
              componentLocation.segment == .components
        else {
            throw OpenGraphiteAgentCoreError(message: "component internalID \"\(id)\" が見つかりません。")
        }

        let removedComponent = project.collections[componentLocation.groupIndex].components.remove(at: componentLocation.pageIndex)
        if deleteFile {
            let htmlRootURL = loadedProject.rootURL
                .appendingPathComponent(project.htmlRoot)
                .standardizedFileURL
            let htmlURL = htmlRootURL
                .appendingPathComponent(removedComponent.path)
                .standardizedFileURL
            try ensureHTMLURL(htmlURL, staysInside: htmlRootURL)
            if FileManager.default.fileExists(atPath: htmlURL.path) {
                try FileManager.default.removeItem(at: htmlURL)
            }
        }

        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトページ作成関数
    /// 処理概要: `.ogp` の `htmlRoot` 配下へ HTML を作成し、同じ処理で既定 Chapter pages に登録します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 追加する page ID。
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - canvas: キャンバス配置。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: stylesheet href。`nil` の場合は `.ogp` の CSS 参照から相対 path を計算します。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存 HTML を上書きするか。
    /// - Returns: 作成と登録の結果。
    func createProjectPage(
        projectURL: URL,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        title: String,
        lang: String,
        stylesheetPath: String?,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphiteProjectPageCreateResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        if loadedProject.project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は既に存在します。")
        }
        if loadedProject.project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page path \"\(path)\" は既に存在します。")
        }

        let htmlURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(path)
            .standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))

        let fileManager = FileManager.default
        let previousData = fileManager.fileExists(atPath: htmlURL.path) ? try Data(contentsOf: htmlURL) : nil
        let stylesheet = stylesheetPath ?? Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let writeResult = try createPage(
            at: htmlURL,
            title: title,
            lang: lang,
            stylesheetPath: stylesheet,
            bodyHTML: bodyHTML,
            overwrite: overwrite
        )
        guard writeResult.created else {
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                project: try? inspectProject(at: projectURL),
                page: nil,
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics
            )
        }

        do {
            let summary = try addProjectPage(projectURL: projectURL, id: id, path: path, canvas: canvas)
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: true,
                project: summary,
                page: summary.pages.first { $0.id == id },
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics + summary.diagnostics
            )
        } catch {
            if let previousData {
                try? previousData.write(to: htmlURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: htmlURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: プロジェクトコンポーネント作成関数
    /// 処理概要: `.ogp` の `htmlRoot` 配下へ component HTML を作成し、同じ処理で Collection に登録します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - collectionID: 登録先 Collection の ID / 内部 ID / `ogref:collection`。`nil` の場合は既定 Collection。
    ///   - id: 追加する component ID。
    ///   - path: `htmlRoot` から見た component HTML path。
    ///   - canvas: キャンバス配置。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: stylesheet href。`nil` の場合は `.ogp` の CSS 参照から相対 path を計算します。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存 HTML を上書きするか。
    /// - Returns: 作成と登録の結果。
    func createProjectComponent(
        projectURL: URL,
        collectionID: String?,
        id: String,
        path: String,
        canvas: OpenGraphiteCanvas,
        title: String,
        lang: String,
        stylesheetPath: String?,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphiteProjectPageCreateResult {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        try validateProjectPagePath(path)
        if loadedProject.project.allPages.contains(where: { $0.id == id }) {
            throw OpenGraphiteAgentCoreError(message: "page or component id \"\(id)\" は既に存在します。")
        }
        if loadedProject.project.allPages.contains(where: { $0.path == path }) {
            throw OpenGraphiteAgentCoreError(message: "page or component path \"\(path)\" は既に存在します。")
        }

        let htmlURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(path)
            .standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))

        let fileManager = FileManager.default
        let previousData = fileManager.fileExists(atPath: htmlURL.path) ? try Data(contentsOf: htmlURL) : nil
        let stylesheet = stylesheetPath ?? Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let writeResult = try createPage(
            at: htmlURL,
            title: title,
            lang: lang,
            stylesheetPath: stylesheet,
            bodyHTML: bodyHTML,
            overwrite: overwrite
        )
        guard writeResult.created else {
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                project: try? inspectProject(at: projectURL),
                page: nil,
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics
            )
        }

        do {
            let summary = try addProjectComponent(projectURL: projectURL, collectionID: collectionID, id: id, path: path, canvas: canvas)
            return OpenGraphiteProjectPageCreateResult(
                schemaVersion: Self.schemaVersion,
                created: true,
                project: summary,
                page: summary.components.first { $0.id == id },
                htmlPath: htmlURL.path,
                diagnostics: writeResult.diagnostics + summary.diagnostics
            )
        } catch {
            if let previousData {
                try? previousData.write(to: htmlURL, options: .atomic)
            } else {
                try? fileManager.removeItem(at: htmlURL)
            }
            throw error
        }
    }

    /// 論理名（日本語）: プロジェクトページ配置関数
    /// 処理概要: `.ogp` の既存 page entry に対して canvas 座標、サイズ、preview mock state を部分更新し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新する page ID。
    ///   - name: 更新後の配置名。`nil` の場合は既存値を維持します。
    ///   - x: 更新後 X 座標。`nil` の場合は既存値を維持します。
    ///   - y: 更新後 Y 座標。`nil` の場合は既存値を維持します。
    ///   - width: 更新後プレビュー幅。`nil` の場合は既存値を維持します。
    ///   - height: 更新後プレビュー高さ。`nil` の場合は既存値を維持します。
    ///   - previewFieldMocks: 更新する runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 project summary。
    func placeProjectPage(
        projectURL: URL,
        id: String,
        name: String?,
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        previewFieldMocks: [String: String]? = nil
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let pageLocation = pageLocation(in: project, pageID: id) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" が見つかりません。")
        }
        if let width, width <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--width は 0 より大きい数値で指定してください。")
        }
        if let height, height <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--height は 0 より大きい数値で指定してください。")
        }

        if pageLocation.segment == .components {
            let currentCanvas = project.collections[pageLocation.groupIndex].components[pageLocation.pageIndex].canvas
            project.collections[pageLocation.groupIndex].components[pageLocation.pageIndex].canvas = OpenGraphiteCanvas(
                name: normalizedCanvasName(name) ?? currentCanvas.name,
                x: x ?? currentCanvas.x,
                y: y ?? currentCanvas.y,
                width: width ?? currentCanvas.width,
                height: height ?? currentCanvas.height,
                previewContext: try updatedPreviewContext(
                    currentCanvas.previewContext,
                    fieldMocks: previewFieldMocks
                )
            )
        } else {
            let currentCanvas = project.chapters[pageLocation.groupIndex].pages[pageLocation.pageIndex].canvas
            project.chapters[pageLocation.groupIndex].pages[pageLocation.pageIndex].canvas = OpenGraphiteCanvas(
                name: normalizedCanvasName(name) ?? currentCanvas.name,
                x: x ?? currentCanvas.x,
                y: y ?? currentCanvas.y,
                width: width ?? currentCanvas.width,
                height: height ?? currentCanvas.height,
                previewContext: try updatedPreviewContext(
                    currentCanvas.previewContext,
                    fieldMocks: previewFieldMocks
                )
            )
        }
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: プロジェクトコンポーネント配置関数
    /// 処理概要: `.ogp` の既存 component entry に対して canvas 座標、サイズ、preview mock state を部分更新し、更新後 summary を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新する component page 内部 ID。
    ///   - name: 更新後の配置名。`nil` の場合は既存値を維持します。
    ///   - x: 更新後 X 座標。`nil` の場合は既存値を維持します。
    ///   - y: 更新後 Y 座標。`nil` の場合は既存値を維持します。
    ///   - width: 更新後プレビュー幅。`nil` の場合は既存値を維持します。
    ///   - height: 更新後プレビュー高さ。`nil` の場合は既存値を維持します。
    ///   - previewFieldMocks: 更新する runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 project summary。
    func placeProjectComponent(
        projectURL: URL,
        id: String,
        name: String?,
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        previewFieldMocks: [String: String]? = nil
    ) throws -> OpenGraphiteProjectSummary {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        var project = loadedProject.project
        guard let componentLocation = pageLocation(in: project, pageID: id),
              componentLocation.segment == .components
        else {
            throw OpenGraphiteAgentCoreError(message: "component internalID \"\(id)\" が見つかりません。")
        }
        if let width, width <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--width は 0 より大きい数値で指定してください。")
        }
        if let height, height <= 0 {
            throw OpenGraphiteAgentCoreError(message: "--height は 0 より大きい数値で指定してください。")
        }

        let currentCanvas = project.collections[componentLocation.groupIndex].components[componentLocation.pageIndex].canvas
        project.collections[componentLocation.groupIndex].components[componentLocation.pageIndex].canvas = OpenGraphiteCanvas(
            name: normalizedCanvasName(name) ?? currentCanvas.name,
            x: x ?? currentCanvas.x,
            y: y ?? currentCanvas.y,
            width: width ?? currentCanvas.width,
            height: height ?? currentCanvas.height,
            previewContext: try updatedPreviewContext(
                currentCanvas.previewContext,
                fieldMocks: previewFieldMocks
            )
        )
        try writeProject(project, to: projectURL)
        return try inspectProject(at: projectURL)
    }

    /// 論理名（日本語）: HTMLページ作成関数
    /// 処理概要: 指定 body HTML を含む standalone HTML を作成し、OpenGraphite contract で検証して保存します。
    ///
    /// - Parameters:
    ///   - url: 作成する HTML ファイル URL。
    ///   - title: `<title>` のテキスト。
    ///   - lang: HTML lang。
    ///   - stylesheetPath: OpenGraphite.css への相対または絶対参照。
    ///   - bodyHTML: `<body>` 内へ入れる OpenGraphite HTML。
    ///   - overwrite: 既存ファイルを上書きするか。
    /// - Returns: 作成結果。
    func createPage(
        at url: URL,
        title: String,
        lang: String,
        stylesheetPath: String,
        bodyHTML: String,
        overwrite: Bool
    ) throws -> OpenGraphitePageWriteResult {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path), !overwrite {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "page-file-exists",
                        message: "\(url.path) は既に存在します。上書きする場合は --overwrite を指定してください。",
                        path: url.path,
                        nodeID: nil
                    )
                ]
            )
        }

        let rawHTML = """
        <!doctype html>
        <html lang="\(Self.escapeAttribute(lang))">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(Self.escapeText(title))</title>
            <link rel="stylesheet" href="\(Self.escapeAttribute(stylesheetPath))">
          </head>
          <body>
        \(bodyHTML.trimmingCharacters(in: .newlines))
          </body>
        </html>
        """
        let html = OpenGraphiteHTMLDocument(html: rawHTML).ensuringInternalIDs()

        let document = OpenGraphiteHTMLDocument(html: html)
        let diagnostics = validate(nodes: document.nodes(), tags: document.parsedTags(), path: url.path)
        guard !diagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphitePageWriteResult(
                schemaVersion: Self.schemaVersion,
                created: false,
                path: url.path,
                graph: nil,
                diagnostics: diagnostics
            )
        }

        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try html.write(to: url, atomically: true, encoding: .utf8)
        let graph = try pageGraph(at: url)
        return OpenGraphitePageWriteResult(
            schemaVersion: Self.schemaVersion,
            created: true,
            path: url.path,
            graph: graph,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: ページグラフ生成関数
    /// 処理概要: 指定 HTML から node graph と validation diagnostics を生成します。
    ///
    /// - Parameter url: HTML ファイル URL。
    /// - Returns: page graph。
    func pageGraph(at url: URL) throws -> OpenGraphitePageGraph {
        let html = try String(contentsOf: url, encoding: .utf8)
        let document = OpenGraphiteHTMLDocument(html: html)
        let nodes = document.nodes()
        return OpenGraphitePageGraph(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            nodes: nodes,
            diagnostics: validate(nodes: nodes, tags: document.parsedTags(), path: url.path)
        )
    }

    /// 論理名（日本語）: ノード検索関数
    /// 処理概要: HTML page graph から指定条件に一致する OpenGraphite node を抽出します。
    ///
    /// - Parameters:
    ///   - url: HTML ファイル URL。
    ///   - query: 絞り込み条件。
    /// - Returns: node query result。
    func queryNodes(at url: URL, query: OpenGraphiteNodeQuery) throws -> OpenGraphiteNodeQueryResult {
        let graph = try pageGraph(at: url)
        let nodes = graph.nodes.filter { node in
            if let idContains = query.idContains, !node.id.localizedCaseInsensitiveContains(idContains) {
                return false
            }
            if let type = query.type, node.type != type {
                return false
            }
            if let role = query.role, node.role != role {
                return false
            }
            if let tag = query.tag, node.tagName != tag.lowercased() {
                return false
            }
            if let textContains = query.textContains,
               !(node.textContent ?? "").localizedCaseInsensitiveContains(textContains) {
                return false
            }
            return true
        }
        return OpenGraphiteNodeQueryResult(
            schemaVersion: Self.schemaVersion,
            pageURL: url.path,
            query: query,
            nodes: nodes,
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: HTML検証関数
    /// 処理概要: 指定 HTML を OpenGraphite 契約に対して検証します。
    ///
    /// - Parameter url: HTML ファイル URL。
    /// - Returns: validation result。
    func validateHTML(at url: URL) throws -> OpenGraphiteValidationResult {
        let graph = try pageGraph(at: url)
        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !graph.diagnostics.contains { $0.severity == .error },
            diagnostics: graph.diagnostics
        )
    }

    /// 論理名（日本語）: HTML Document Contextファイル更新関数
    /// 処理概要: HTML 正本の `<html>` attribute と OpenGraphite binding metadata を更新します。
    ///
    /// - Parameters:
    ///   - context: 保存する HTML document context。
    ///   - htmlURL: 対象 HTML ファイル URL。
    /// - Returns: 更新結果。
    func setHTMLDocumentContext(
        _ context: OpenGraphiteHTMLDocumentContext,
        htmlURL: URL
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingHTMLDocumentContext(context, contract: contract)
        return try persistHTMLDocumentContextMutation(
            mutation,
            htmlURL: htmlURL,
            didChange: mutation.html != html
        )
    }

    /// 論理名（日本語）: プロジェクトページHTML Document Context更新関数
    /// 処理概要: `.ogp` の page 参照 ID から HTML 正本を解決し、document attribute を更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新対象 page ID。
    ///   - context: 保存する HTML document context。
    /// - Returns: 更新結果。
    func setProjectPageHTMLDocumentContext(
        projectURL: URL,
        id: String,
        context: OpenGraphiteHTMLDocumentContext
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: id)
        guard target.segment == OpenGraphiteCanvasSegment.pages.rawValue else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(id)\" は Pages ではありません。component は project component document を使ってください。")
        }
        return try setHTMLDocumentContext(context, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: プロジェクトComponent HTML Document Context更新関数
    /// 処理概要: `.ogp` の component ID から HTML 正本を解決し、document attribute を更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - id: 更新対象 component ID。
    ///   - context: 保存する HTML document context。
    /// - Returns: 更新結果。
    func setProjectComponentHTMLDocumentContext(
        projectURL: URL,
        id: String,
        context: OpenGraphiteHTMLDocumentContext
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: id)
        guard target.segment == OpenGraphiteCanvasSegment.components.rawValue else {
            throw OpenGraphiteAgentCoreError(message: "component id \"\(id)\" は Components ではありません。page は project page document を使ってください。")
        }
        return try setHTMLDocumentContext(context, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: i18n runtime検査関数
    /// 処理概要: `.ogp` の page 参照から HTML 実装資源を辿り、i18next 系 `i18n.init` と locale JSON 状態を検出します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - locales: 状態を確認する locale。未指定時は `ja` と `eng`。
    /// - Returns: i18n runtime 検査結果。
    func inspectI18n(
        projectURL: URL,
        pageID: String,
        locales: [String] = ["ja", "eng"]
    ) throws -> OpenGraphiteI18nRuntimeInspection {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try inspectI18n(target: target, locales: locales)
    }

    /// 論理名（日本語）: i18n推奨設定適用関数
    /// 処理概要: 自動検出できないページへ推奨 runtime を追加し、`public/locales/<locale>.json` を実装資源として作成・更新します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - locales: 作成・更新する locale 一覧。
    /// - Returns: 推奨設定適用結果。
    func recommendI18n(
        projectURL: URL,
        pageID: String,
        locales: [String]
    ) throws -> OpenGraphiteI18nRecommendResult {
        let normalizedLocales = normalizedLocales(locales.isEmpty ? ["ja", "eng"] : locales)
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let beforeInspection = try inspectI18n(target: target, locales: normalizedLocales)
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        var nextHTML = html
        var updated = false
        var configURL: URL?

        if beforeInspection.adapter == .unknown {
            let i18nURL = htmlRootURL.appendingPathComponent("i18n.js").standardizedFileURL
            configURL = i18nURL
            if !FileManager.default.fileExists(atPath: i18nURL.path) {
                try FileManager.default.createDirectory(at: i18nURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Self.recommendedI18nRuntimeSource.write(to: i18nURL, atomically: true, encoding: .utf8)
                updated = true
            }
            let scriptPath = Self.relativePath(from: target.htmlURL.deletingLastPathComponent(), to: i18nURL)
            nextHTML = Self.insertingRecommendedI18nScriptIfNeeded(in: nextHTML, scriptPath: scriptPath)
            if nextHTML != html {
                try nextHTML.write(to: target.htmlURL, atomically: true, encoding: .utf8)
                updated = true
            }
        } else if let configSource = beforeInspection.configSource {
            configURL = URL(fileURLWithPath: configSource)
        }

        let resourceLoadPath = beforeInspection.loadPath.source == .literal
            ? beforeInspection.loadPath.value ?? Self.recommendedI18nLoadPath
            : Self.recommendedI18nLoadPath
        let textBindings = OpenGraphiteHTMLDocument(html: nextHTML).textBindingResources()
        var resourceStatuses: [OpenGraphiteI18nResourceStatus] = []
        for locale in normalizedLocales {
            let resourceURL = localeResourceURL(
                loadPath: resourceLoadPath,
                locale: locale,
                htmlRootURL: htmlRootURL,
                pageURL: target.htmlURL,
                configURL: configURL
            )
            let didUpdateResource = try mergeLocaleResource(
                at: resourceURL,
                locale: locale,
                bindings: textBindings,
                fallbackLocale: fallbackLocale(from: beforeInspection) ?? "ja"
            )
            updated = updated || didUpdateResource
            resourceStatuses.append(
                OpenGraphiteI18nResourceStatus(
                    locale: locale,
                    path: resourceURL.path,
                    exists: FileManager.default.fileExists(atPath: resourceURL.path),
                    editable: true
                )
            )
        }

        return OpenGraphiteI18nRecommendResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            pageURL: target.htmlURL.path,
            configPath: configURL?.path,
            loadPath: resourceLoadPath,
            resources: resourceStatuses,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: i18n runtime literal更新関数
    /// 処理概要: 実装側 `i18n.init({...})` の literal 設定だけを正本 JS/TS ファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - loadPath: 更新する `backend.loadPath`。`nil` の場合は更新しません。
    ///   - fallbackLocale: 更新する `fallbackLng`。`nil` の場合は更新しません。
    /// - Returns: 更新後の i18n runtime 検査結果を含む編集結果。
    func updateI18nRuntimeLiterals(
        projectURL: URL,
        pageID: String,
        loadPath: String?,
        fallbackLocale: String?
    ) throws -> OpenGraphiteI18nRuntimeEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let inspection = try inspectI18n(target: target, locales: ["ja", "eng"])
        var diagnostics: [OpenGraphiteDiagnostic] = []

        guard inspection.adapter != .unknown else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-i18n-runtime",
                    message: "i18n.init({...}) を検出できないため runtime 設定を編集できません。",
                    path: target.htmlURL.path,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: inspection.configSource,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        guard let configSource = inspection.configSource,
              !configSource.contains("#inline-script")
        else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "inline-i18n-config",
                    message: "inline script の i18n 設定は Project Dependencies から直接編集できません。",
                    path: inspection.configSource,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: inspection.configSource,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        let configURL = URL(fileURLWithPath: configSource)
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-i18n-config-file",
                    message: "i18n 設定ファイルが見つかりません: \(configURL.path)",
                    path: configURL.path,
                    nodeID: nil
                )
            )
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: configURL.path,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        var source = try String(contentsOf: configURL, encoding: .utf8)
        let before = source

        if let loadPath {
            if inspection.loadPath.source == .literal {
                source = Self.replacingI18nLiteralProperty(named: "loadPath", value: loadPath, in: source) ?? source
            } else {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-load-path",
                        message: "backend.loadPath は external / readonly のため Project Dependencies から編集できません。",
                        path: configURL.path,
                        nodeID: nil
                    )
                )
            }
        }

        if let fallbackLocale {
            if inspection.fallbackLng.source == .literal {
                source = Self.replacingI18nLiteralProperty(named: "fallbackLng", value: fallbackLocale, in: source) ?? source
            } else {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-fallback",
                        message: "fallbackLng は external / readonly のため Project Dependencies から編集できません。",
                        path: configURL.path,
                        nodeID: nil
                    )
                )
            }
        }

        guard diagnostics.filter({ $0.severity == .error }).isEmpty else {
            return OpenGraphiteI18nRuntimeEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                configPath: configURL.path,
                inspection: inspection,
                diagnostics: diagnostics
            )
        }

        let updated = source != before
        if updated {
            try source.write(to: configURL, atomically: true, encoding: .utf8)
        }
        let nextInspection = try inspectI18n(target: target, locales: ["ja", "eng"])
        return OpenGraphiteI18nRuntimeEditResult(
            schemaVersion: Self.schemaVersion,
            updated: updated,
            configPath: configURL.path,
            inspection: nextInspection,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: i18n resource値設定関数
    /// 処理概要: 検出済みまたは推奨 loadPath から locale JSON を解決し、flat key の値を正本 JSON へ保存します。
    ///
    /// - Parameters:
    ///   - value: 保存する HTML/text 値。空文字も有効です。
    ///   - locale: 更新 locale。
    ///   - key: 更新する flat i18n key。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    /// - Returns: resource 編集結果。
    func setI18nResourceValue(
        _ value: String,
        locale: String,
        key: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteI18nResourceEditResult {
        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLocale.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: "locale は空にできません。")
        }
        guard !normalizedKey.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: "i18n resource key は空にできません。")
        }

        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        let inspection = try inspectI18n(target: target, locales: [normalizedLocale])
        guard inspection.loadPath.source != .external else {
            return OpenGraphiteI18nResourceEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: "",
                locale: normalizedLocale,
                key: normalizedKey,
                value: value,
                diagnostics: [
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "external-i18n-load-path",
                        message: "backend.loadPath は external / readonly のため、対象 resource path を自動更新できません。",
                        path: inspection.configSource,
                        nodeID: nil
                    )
                ]
            )
        }

        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let resourceURL = localeResourceURL(
            loadPath: inspection.loadPath.value ?? Self.recommendedI18nLoadPath,
            locale: normalizedLocale,
            htmlRootURL: htmlRootURL,
            pageURL: target.htmlURL,
            configURL: inspection.configSource.map { URL(fileURLWithPath: $0) }
        )
        var resource = try readLocaleResource(at: resourceURL)
        let didChange = resource[normalizedKey] as? String != value
        resource[normalizedKey] = value
        if didChange {
            try writeLocaleResource(resource, to: resourceURL)
        }
        return OpenGraphiteI18nResourceEditResult(
            schemaVersion: Self.schemaVersion,
            updated: didChange,
            path: resourceURL.path,
            locale: normalizedLocale,
            key: normalizedKey,
            value: value,
            diagnostics: []
        )
    }

    /// 論理名（日本語）: プロジェクト検証関数
    /// 処理概要: `.ogp` と参照 HTML / CSS をまとめて検証します。
    ///
    /// - Parameter url: `.ogp` ファイル URL。
    /// - Returns: validation result。
    func validateProject(at url: URL) throws -> OpenGraphiteValidationResult {
        let summary = try inspectProject(at: url)
        var diagnostics = summary.diagnostics
        for page in summary.pages + summary.components {
            diagnostics.append(contentsOf: try validateHTML(at: URL(fileURLWithPath: page.htmlURL)).diagnostics)
        }

        return OpenGraphiteValidationResult(
            schemaVersion: Self.schemaVersion,
            valid: !diagnostics.contains { $0.severity == .error },
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: プロジェクトページノード検索関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML から node を検索します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    ///   - query: 絞り込み条件。
    /// - Returns: node query result。
    func queryNodes(
        projectURL: URL,
        pageID: String,
        query: OpenGraphiteNodeQuery
    ) throws -> OpenGraphiteNodeQueryResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try queryNodes(at: target.htmlURL, query: query)
    }

    /// 論理名（日本語）: ノード取得関数
    /// 処理概要: HTML から一意な `data-og-internal-id` に一致する node を取得します。
    ///
    /// - Parameters:
    ///   - id: 対象 `data-og-internal-id`。
    ///   - url: HTML ファイル URL。
    /// - Returns: edit result 形式の node 取得結果。
    func node(id: String, at url: URL) throws -> OpenGraphiteEditResult {
        let resolvedID = resolvedNodeID(id)
        let graph = try pageGraph(at: url)
        let matches = graph.nodes.filter { $0.internalID == resolvedID }
        let diagnostics = uniqueNodeDiagnostics(matches: matches, id: resolvedID, path: url.path)
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: false,
            path: url.path,
            node: matches.count == 1 ? matches[0] : nil,
            diagnostics: diagnostics,
            insertedNodes: nil
        )
    }

    /// 論理名（日本語）: プロジェクトページノード取得関数
    /// 処理概要: `.ogp` の page 参照 ID で明示された HTML から `data-og-internal-id` に一致する node を取得します。
    ///
    /// - Parameters:
    ///   - id: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    /// - Returns: edit result 形式の node 取得結果。
    func node(id: String, projectURL: URL, pageID: String) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [id])
        return try node(id: resolvedNodeID(id), at: target.htmlURL)
    }

    /// 論理名（日本語）: CSS変数ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node に CSS 変数を設定し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS 変数。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setCSSVariable(_ variable: String, value: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingCSSVariable(
            variable,
            value: value,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページCSS変数更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の CSS 変数を更新します。
    ///
    /// - Parameters:
    ///   - variable: 更新する CSS 変数。
    ///   - value: CSS 値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setCSSVariable(
        _ variable: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setCSSVariable(variable, value: value, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード属性ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node に許可済み属性を設定し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setAttribute(_ name: String, value: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingAttribute(
            name: name,
            value: value,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページ属性更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の編集可能属性を更新します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: 属性値。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setAttribute(
        _ name: String,
        value: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setAttribute(name, value: value, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: テキスト内容ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の text content を更新し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。HTML としてではなく text として escape されます。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setTextContent(_ text: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingTextContent(
            text,
            forNodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページテキスト更新関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の text content を更新します。
    ///
    /// - Parameters:
    ///   - text: 設定するテキスト。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setTextContent(
        _ text: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try setTextContent(text, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: テキストvariantファイル更新関数
    /// 処理概要: HTML ファイル内の `data-i18n-key` に一致する text binding へ locale variant を保存します。
    ///
    /// - Parameters:
    ///   - text: 保存する variant HTML。空文字も有効な値として保持されます。
    ///   - locale: variant の locale 名。
    ///   - i18nKey: 対象 `data-i18n-key`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func setTextVariant(_ text: String, locale: String, i18nKey: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).settingTextVariant(
            text,
            locale: locale,
            i18nKey: i18nKey,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: "")
    }

    /// 論理名（日本語）: プロジェクトページテキストvariant更新関数
    /// 処理概要: `.ogp` の page 参照 ID で明示された HTML 内の text binding variant を更新します。
    ///
    /// - Parameters:
    ///   - text: 保存する variant HTML。空文字も有効な値として保持されます。
    ///   - locale: variant の locale 名。
    ///   - i18nKey: 対象 `data-i18n-key`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func setTextVariant(
        _ text: String,
        locale: String,
        i18nKey: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID)
        return try setTextVariant(text, locale: locale, i18nKey: i18nKey, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: HTML断片挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の anchor node を基準に HTML 断片を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let resolvedAnchorNodeID = resolvedNodeID(anchorNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).insertingHTML(
            fragmentHTML,
            relativeToNodeID: resolvedAnchorNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: resolvedAnchorNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページHTML挿入関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML に対して anchor node 基準で HTML 断片を挿入します。
    ///
    /// - Parameters:
    ///   - fragmentHTML: 挿入する HTML 断片。
    ///   - anchorNodeID: 基準 `data-og-internal-id`。
    ///   - position: 挿入位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func insertHTML(
        _ fragmentHTML: String,
        anchorNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [anchorNodeID])
        return try insertHTML(fragmentHTML, anchorNodeID: resolvedNodeID(anchorNodeID), position: position, htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: 子HTML先頭挿入ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node の先頭へ子 HTML を挿入し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func prependChildHTML(_ childHTML: String, parentNodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, htmlURL: htmlURL)
    }

    /// 論理名（日本語）: プロジェクトページ子HTML先頭挿入関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node の先頭へ子 HTML を挿入します。
    ///
    /// - Parameters:
    ///   - childHTML: 挿入する HTML 断片。
    ///   - parentNodeID: 親 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func prependChildHTML(
        _ childHTML: String,
        parentNodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        try insertHTML(childHTML, anchorNodeID: parentNodeID, position: .prepend, projectURL: projectURL, pageID: pageID)
    }

    /// 論理名（日本語）: ノードHTML置換ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node 全体を HTML 断片で置換し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func replaceNodeHTML(_ replacementHTML: String, nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).replacingNodeHTML(
            replacementHTML,
            nodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: normalizedNodeID,
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノードHTML置換関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を HTML 断片で置換します。
    ///
    /// - Parameters:
    ///   - replacementHTML: 置換後 HTML 断片。
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func replaceNodeHTML(
        _ replacementHTML: String,
        nodeID: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try replaceNodeHTML(replacementHTML, nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード削除ファイル更新関数
    /// 処理概要: HTML ファイル内の指定 node subtree を削除し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, htmlURL: URL) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).deletingNode(
            nodeID: normalizedNodeID,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード削除関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を削除します。
    ///
    /// - Parameters:
    ///   - nodeID: 対象 `data-og-internal-id`。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func deleteNode(nodeID: String, projectURL: URL, pageID: String) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID])
        return try deleteNode(nodeID: resolvedNodeID(nodeID), htmlURL: target.htmlURL)
    }

    /// 論理名（日本語）: ノード移動ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を別 node 基準位置へ移動し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-internal-id`。
    ///   - targetNodeID: 移動先基準 `data-og-internal-id`。
    ///   - position: 移動先位置。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedTargetNodeID = resolvedNodeID(targetNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let mutation = OpenGraphiteHTMLDocument(html: html).movingNode(
            nodeID: normalizedNodeID,
            relativeToNodeID: normalizedTargetNodeID,
            position: position,
            contract: contract
        )
        return try persistMutation(mutation, htmlURL: htmlURL, nodeID: normalizedNodeID)
    }

    /// 論理名（日本語）: プロジェクトページノード移動関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を移動します。
    ///
    /// - Parameters:
    ///   - nodeID: 移動する `data-og-internal-id`。
    ///   - targetNodeID: 移動先基準 `data-og-internal-id`。
    ///   - position: 移動先位置。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func moveNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID, targetNodeID])
        return try moveNode(
            nodeID: resolvedNodeID(nodeID),
            targetNodeID: resolvedNodeID(targetNodeID),
            position: position,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: ノード複製ファイル更新関数
    /// 処理概要: HTML ファイル内の node subtree を `data-og-id` prefix 付きで複製し、成功時に同じファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-internal-id`。
    ///   - targetNodeID: 複製先基準 `data-og-internal-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - htmlURL: HTML ファイル URL。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        htmlURL: URL
    ) throws -> OpenGraphiteEditResult {
        let normalizedNodeID = resolvedNodeID(nodeID)
        let normalizedTargetNodeID = resolvedNodeID(targetNodeID)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let beforeIDs = Set(OpenGraphiteHTMLDocument(html: html).nodes().map(\.id))
        let mutation = OpenGraphiteHTMLDocument(html: html).copyingNode(
            nodeID: normalizedNodeID,
            relativeToNodeID: normalizedTargetNodeID,
            position: position,
            idPrefix: idPrefix,
            contract: contract
        )
        return try persistMutation(
            mutation,
            htmlURL: htmlURL,
            nodeID: "\(idPrefix)\(normalizedNodeID)",
            insertedNodeIDsBeforeMutation: beforeIDs
        )
    }

    /// 論理名（日本語）: プロジェクトページノード複製関数
    /// 処理概要: ``.ogp` の page 参照 ID で明示された HTML 内 node subtree を prefix 付きで複製します。
    ///
    /// - Parameters:
    ///   - nodeID: 複製元 `data-og-internal-id`。
    ///   - targetNodeID: 複製先基準 `data-og-internal-id`。
    ///   - position: 複製先位置。
    ///   - idPrefix: 複製 node の `data-og-id` に付ける prefix。
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 編集結果。
    func copyNode(
        nodeID: String,
        targetNodeID: String,
        position: OpenGraphiteHTMLInsertionPosition,
        idPrefix: String,
        projectURL: URL,
        pageID: String
    ) throws -> OpenGraphiteEditResult {
        let target = try projectPageTarget(projectURL: projectURL, pageID: pageID, nodeReferenceIDs: [nodeID, targetNodeID])
        return try copyNode(
            nodeID: resolvedNodeID(nodeID),
            targetNodeID: resolvedNodeID(targetNodeID),
            position: position,
            idPrefix: idPrefix,
            htmlURL: target.htmlURL
        )
    }

    /// 論理名（日本語）: i18n runtime内部検査関数
    /// 処理概要: 解決済み page target から HTML と script / module import を読み、i18n 設定と resource 状態を構成します。
    private func inspectI18n(
        target: OpenGraphiteProjectPageTarget,
        locales: [String]
    ) throws -> OpenGraphiteI18nRuntimeInspection {
        let normalizedLocales = normalizedLocales(locales.isEmpty ? ["ja", "eng"] : locales)
        let html = try String(contentsOf: target.htmlURL, encoding: .utf8)
        let htmlDocument = OpenGraphiteHTMLDocument(html: html)
        let htmlRootURL = target.loadedProject.rootURL
            .appendingPathComponent(target.loadedProject.project.htmlRoot)
            .standardizedFileURL
        let scriptSources = try i18nScriptSources(
            htmlDocument: htmlDocument,
            pageURL: target.htmlURL,
            htmlRootURL: htmlRootURL
        )
        let detected = detectedI18nConfig(in: scriptSources)
        let localeField = detected.localeField
            ?? htmlDocument.htmlDocumentContext().langField.nonEmptyTrimmed
            ?? target.page.canvas.previewContext.fieldMocks.keys.sorted().first(where: { $0 == "selectedLanguage" })
        let resourceLoadPath = detected.loadPath.value ?? Self.recommendedI18nLoadPath
        let configURL = detected.configSource.map { URL(fileURLWithPath: $0) }
        let resourceEditable = detected.loadPath.source != .external
        let resources = normalizedLocales.map { locale in
            let resourceURL = localeResourceURL(
                loadPath: resourceLoadPath,
                locale: locale,
                htmlRootURL: htmlRootURL,
                pageURL: target.htmlURL,
                configURL: configURL
            )
            return OpenGraphiteI18nResourceStatus(
                locale: locale,
                path: resourceURL.path,
                exists: FileManager.default.fileExists(atPath: resourceURL.path),
                editable: resourceEditable
            )
        }

        let diagnostics: [OpenGraphiteDiagnostic]
        if detected.adapter == .unknown {
            diagnostics = [
                OpenGraphiteDiagnostic(
                    severity: .info,
                    code: "missing-i18n-runtime",
                    message: "i18n.init({...}) を検出できませんでした。推奨設定を作成できます。",
                    path: target.htmlURL.path,
                    nodeID: nil
                )
            ]
        } else if detected.loadPath.source == .external {
            diagnostics = [
                OpenGraphiteDiagnostic(
                    severity: .info,
                    code: "external-i18n-load-path",
                    message: "backend.loadPath は external / readonly です。OpenGraphite は動的式を自動で書き換えません。",
                    path: detected.configSource,
                    nodeID: nil
                )
            ]
        } else {
            diagnostics = []
        }

        return OpenGraphiteI18nRuntimeInspection(
            schemaVersion: Self.schemaVersion,
            pageURL: target.htmlURL.path,
            adapter: detected.adapter,
            configSource: detected.configSource,
            lng: detected.lng,
            fallbackLng: detected.fallbackLng,
            loadPath: detected.loadPath,
            localeField: localeField,
            resources: resources,
            diagnostics: diagnostics
        )
    }

    /// 論理名（日本語）: i18n script source収集関数
    /// 処理概要: HTML script と辿れる module import を読み、i18n 設定検出の入力へ変換します。
    private func i18nScriptSources(
        htmlDocument: OpenGraphiteHTMLDocument,
        pageURL: URL,
        htmlRootURL: URL
    ) throws -> [OpenGraphiteI18nScriptSource] {
        var sources: [OpenGraphiteI18nScriptSource] = []
        var visited = Set<String>()

        func appendExternalScript(_ url: URL, depth: Int) throws {
            guard depth <= 12 else { return }
            let standardized = url.standardizedFileURL
            let key = standardized.path
            guard !visited.contains(key) else { return }
            visited.insert(key)
            guard FileManager.default.fileExists(atPath: standardized.path) else { return }
            let source = try String(contentsOf: standardized, encoding: .utf8)
            sources.append(
                OpenGraphiteI18nScriptSource(
                    url: standardized,
                    displayPath: standardized.path,
                    source: source,
                    isInline: false
                )
            )
            for specifier in Self.importSpecifiers(in: source) {
                guard let importURL = Self.resolvedImplementationURL(
                    specifier,
                    relativeTo: standardized,
                    htmlRootURL: htmlRootURL
                ) else {
                    continue
                }
                try appendExternalScript(importURL, depth: depth + 1)
            }
        }

        for script in htmlDocument.scriptReferences() {
            if let src = script.src,
               let scriptURL = Self.resolvedImplementationURL(src, relativeTo: pageURL, htmlRootURL: htmlRootURL) {
                try appendExternalScript(scriptURL, depth: 0)
            } else if !script.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sources.append(
                    OpenGraphiteI18nScriptSource(
                        url: pageURL,
                        displayPath: "\(pageURL.path)#inline-script",
                        source: script.content,
                        isInline: true
                    )
                )
            }
        }

        return sources
    }

    /// 論理名（日本語）: i18n config検出関数
    /// 処理概要: script source 内の `i18n.init({...})` から検出対象 literal / external 値を抽出します。
    private func detectedI18nConfig(
        in sources: [OpenGraphiteI18nScriptSource]
    ) -> (
        adapter: OpenGraphiteI18nAdapter,
        configSource: String?,
        lng: OpenGraphiteI18nConfigProperty,
        fallbackLng: OpenGraphiteI18nConfigProperty,
        loadPath: OpenGraphiteI18nConfigProperty,
        localeField: String?
    ) {
        for source in sources {
            guard let objectSource = Self.i18nInitObjectSource(in: source.source) else { continue }
            let lngExpression = Self.objectPropertyExpression(named: "lng", in: objectSource)
            let fallbackExpression = Self.objectPropertyExpression(named: "fallbackLng", in: objectSource)
            let loadPathExpression = Self.objectPropertyExpression(named: "loadPath", in: objectSource)
            return (
                adapter: .i18next,
                configSource: source.displayPath,
                lng: Self.configProperty(from: lngExpression),
                fallbackLng: Self.configProperty(from: fallbackExpression),
                loadPath: Self.configProperty(from: loadPathExpression),
                localeField: Self.localeFieldName(from: lngExpression)
            )
        }

        return (
            adapter: .unknown,
            configSource: nil,
            lng: Self.missingI18nConfigProperty(),
            fallbackLng: Self.missingI18nConfigProperty(),
            loadPath: Self.missingI18nConfigProperty(),
            localeField: nil
        )
    }

    /// 論理名（日本語）: locale resource URL解決関数
    /// 処理概要: literal loadPath または推奨 loadPath から locale JSON の file URL を求めます。
    private func localeResourceURL(
        loadPath: String,
        locale: String,
        htmlRootURL: URL,
        pageURL: URL,
        configURL: URL?
    ) -> URL {
        var path = loadPath
            .replacingOccurrences(of: "{{lng}}", with: locale)
            .replacingOccurrences(of: "{{locale}}", with: locale)
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        if path.hasPrefix("/") {
            return htmlRootURL
                .appendingPathComponent(String(path.dropFirst()))
                .standardizedFileURL
        }
        let baseURL = configURL?.deletingLastPathComponent() ?? pageURL.deletingLastPathComponent()
        return baseURL.appendingPathComponent(path).standardizedFileURL
    }

    /// 論理名（日本語）: locale resource merge関数
    /// 処理概要: HTML fallback と同梱 variant から flat key JSON を作成・追記します。
    private func mergeLocaleResource(
        at url: URL,
        locale: String,
        bindings: [OpenGraphiteHTMLTextBindingResource],
        fallbackLocale: String
    ) throws -> Bool {
        var resource = try readLocaleResource(at: url)
        let before = resource
        for binding in bindings {
            if resource[binding.key] != nil {
                continue
            }
            if locale == fallbackLocale {
                resource[binding.key] = binding.fallbackHTML
            } else if let variant = Self.variantValue(for: locale, in: binding.variants) {
                resource[binding.key] = variant
            } else {
                resource[binding.key] = binding.fallbackHTML
            }
        }
        guard resource as NSDictionary != before as NSDictionary else {
            return false
        }
        try writeLocaleResource(resource, to: url)
        return true
    }

    /// 論理名（日本語）: locale resource読込関数
    /// 処理概要: flat key JSON を辞書として読み、存在しない場合は空辞書を返します。
    private func readLocaleResource(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenGraphiteAgentCoreError(message: "locale JSON は object である必要があります: \(url.path)")
        }
        return dictionary
    }

    /// 論理名（日本語）: locale resource保存関数
    /// 処理概要: flat key JSON を pretty / sorted 形式で実装資源へ保存します。
    private func writeLocaleResource(_ resource: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: resource, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        var output = data
        output.append(0x0A)
        try output.write(to: url, options: .atomic)
    }

    private func fallbackLocale(from inspection: OpenGraphiteI18nRuntimeInspection) -> String? {
        inspection.fallbackLng.value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyTrimmed
    }

    private func normalizedLocales(_ locales: [String]) -> [String] {
        var result: [String] = []
        for locale in locales {
            let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedLocale.isEmpty, !result.contains(normalizedLocale) else { continue }
            result.append(normalizedLocale)
        }
        return result
    }

    private static let recommendedI18nLoadPath = "/locales/{{lng}}.json"

    private static let recommendedI18nRuntimeSource = """
    const fallbackLocale = "ja";

    function previewField(name) {
      const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {};
      const fields = context.fields || {};
      if (!Object.prototype.hasOwnProperty.call(fields, name)) {
        return { found: false, value: "" };
      }
      return { found: true, value: String(fields[name]) };
    }

    function selectedLanguage() {
      const mock = previewField("selectedLanguage");
      if (mock.found) { return mock.value; }
      return document.documentElement.lang || fallbackLocale;
    }

    const i18n = window.i18n || {
      init(config) {
        window.__OPENGRAPHITE_I18N_CONFIG__ = config;
        return config;
      }
    };

    const runtimeConfig = i18n.init({
      lng: selectedLanguage(),
      fallbackLng: "ja",
      backend: {
        loadPath: "/locales/{{lng}}.json"
      }
    });

    function resolvedLoadPath(language) {
      return runtimeConfig.backend.loadPath.replace("{{lng}}", language);
    }

    function resolvedLocaleURL(language) {
      const path = resolvedLoadPath(language);
      if (document.location.protocol === "file:" && path.startsWith("/")) {
        return new URL(`.${path}`, document.baseURI);
      }
      return new URL(path, document.baseURI);
    }

    async function loadLocale(language) {
      const url = resolvedLocaleURL(language);
      try {
        const response = await fetch(url.href);
        if (response.ok) { return await response.json(); }
      } catch (_) {}
      return await new Promise((resolve) => {
        const request = new XMLHttpRequest();
        request.open("GET", url.href, true);
        request.onload = () => {
          if ((request.status >= 200 && request.status < 300) || request.status === 0) {
            try { resolve(JSON.parse(request.responseText)); } catch (_) { resolve({}); }
          } else {
            resolve({});
          }
        };
        request.onerror = () => resolve({});
        request.send();
      });
    }

    function elementsIncludingTemplateContent(root) {
      const elements = [];
      function visit(node) {
        if (!node) { return; }
        if (node.nodeType === Node.ELEMENT_NODE) {
          elements.push(node);
          if (node.tagName && node.tagName.toLowerCase() === "template") {
            Array.from(node.content.childNodes).forEach(visit);
          }
        }
        Array.from(node.childNodes || []).forEach(visit);
      }
      visit(root);
      return elements;
    }

    function textVariantAttributeForLocale(locale) {
      const normalizedLocale = String(locale || "").trim().toLowerCase().replace(/_/g, "-");
      if (!/^[a-z0-9-]+$/.test(normalizedLocale)) {
        return "";
      }
      if (normalizedLocale.split("-")[0] === "en") {
        return "data-og-text-variant-eng";
      }
      return `data-og-text-variant-${normalizedLocale}`;
    }

    async function applyI18n() {
      const language = selectedLanguage();
      const resources = await loadLocale(language);
      const variantAttribute = textVariantAttributeForLocale(language);
      document.documentElement.lang = language || fallbackLocale;
      elementsIncludingTemplateContent(document.documentElement).forEach((element) => {
        const key = element.getAttribute("data-i18n-key");
        if (!key) { return; }
        if (!element.hasAttribute("data-og-runtime-fallback-html")) {
          element.setAttribute("data-og-runtime-fallback-html", element.innerHTML);
        }
        const fallbackHTML = element.getAttribute("data-og-runtime-fallback-html") || "";
        const variantHTML = variantAttribute ? element.getAttribute(variantAttribute) : null;
        const value = Object.prototype.hasOwnProperty.call(resources, key) ? resources[key] : variantHTML !== null ? variantHTML : fallbackHTML;
        element.innerHTML = typeof value === "string" ? value : fallbackHTML;
      });
    }

    window.OpenGraphiteI18n = { apply: applyI18n };

    document.addEventListener("DOMContentLoaded", () => { applyI18n(); });
    document.addEventListener("opengraphite:components-ready", () => { applyI18n(); });
    document.addEventListener("opengraphite:serialize-complete", () => { applyI18n(); });
    """

    private static func insertingRecommendedI18nScriptIfNeeded(in html: String, scriptPath: String) -> String {
        let document = OpenGraphiteHTMLDocument(html: html)
        let normalizedScriptPath = normalizedScriptReference(scriptPath)
        if document.scriptReferences().contains(where: { reference in
            guard let src = reference.src else { return false }
            return normalizedScriptReference(src) == normalizedScriptPath
        }) {
            return html
        }
        let source = normalizedScriptPath.hasPrefix(".") || normalizedScriptPath.hasPrefix("/")
            ? normalizedScriptPath
            : "./\(normalizedScriptPath)"
        let script = "    <script src=\"\(escapeAttribute(source))\" defer></script>\n"
        if let range = html.range(of: "</head>", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: script, at: range.lowerBound)
            return result
        }
        if let range = html.range(of: "<body", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: script, at: range.lowerBound)
            return result
        }
        return "\(script)\(html)"
    }

    private static func resolvedImplementationURL(
        _ specifier: String,
        relativeTo sourceURL: URL,
        htmlRootURL: URL
    ) -> URL? {
        let trimmed = specifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("http://"),
              !trimmed.hasPrefix("https://"),
              !trimmed.hasPrefix("data:"),
              !trimmed.hasPrefix("node:")
        else {
            return nil
        }

        let candidate: URL
        if trimmed.hasPrefix("/") {
            candidate = htmlRootURL.appendingPathComponent(String(trimmed.dropFirst()))
        } else if trimmed.hasPrefix("./") || trimmed.hasPrefix("../") {
            candidate = sourceURL.deletingLastPathComponent().appendingPathComponent(trimmed)
        } else {
            return nil
        }

        let standardized = candidate.standardizedFileURL
        if FileManager.default.fileExists(atPath: standardized.path) {
            return standardized
        }
        if standardized.pathExtension.isEmpty {
            for ext in ["js", "mjs", "ts"] {
                let withExtension = standardized.appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: withExtension.path) {
                    return withExtension.standardizedFileURL
                }
            }
        }
        return standardized
    }

    private static func importSpecifiers(in source: String) -> [String] {
        var specifiers: [String] = []
        var searchIndex = source.startIndex
        while let range = source.range(of: "import", range: searchIndex..<source.endIndex) {
            let before = range.lowerBound > source.startIndex ? source[source.index(before: range.lowerBound)] : " "
            let after = range.upperBound < source.endIndex ? source[range.upperBound] : " "
            guard !isIdentifierCharacter(before), !isIdentifierCharacter(after) else {
                searchIndex = range.upperBound
                continue
            }
            let statementEnd = source[range.upperBound...].firstIndex(of: ";") ?? source.endIndex
            let statement = String(source[range.upperBound..<statementEnd])
            if let direct = firstQuotedString(in: statement) {
                specifiers.append(direct)
            } else if let fromRange = statement.range(of: "from"),
                      let imported = firstQuotedString(in: String(statement[fromRange.upperBound...])) {
                specifiers.append(imported)
            }
            searchIndex = statementEnd
        }
        return specifiers
    }

    private static func i18nInitObjectSource(in source: String) -> String? {
        guard let range = i18nInitObjectRange(in: source) else { return nil }
        return String(source[range])
    }

    private static func i18nInitObjectRange(in source: String) -> Range<String.Index>? {
        guard let initRange = source.range(of: "i18n.init") else { return nil }
        guard let parenIndex = source[initRange.upperBound...].firstIndex(of: "(") else { return nil }
        guard let objectStart = source[parenIndex...].firstIndex(of: "{") else { return nil }
        guard let objectEnd = matchingDelimiterEnd(in: source, start: objectStart, open: "{", close: "}") else {
            return nil
        }
        return objectStart..<source.index(after: objectEnd)
    }

    private static func objectPropertyExpression(named name: String, in source: String) -> String? {
        guard let range = objectPropertyValueRange(named: name, in: source) else { return nil }
        return String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func objectPropertyValueRange(named name: String, in source: String) -> Range<String.Index>? {
        var index = source.startIndex
        var quote: Character?
        var isEscaped = false
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
                index = source.index(after: index)
                continue
            }
            if isIdentifierStart(character) {
                let nameStart = index
                while index < source.endIndex, isIdentifierCharacter(source[index]) {
                    index = source.index(after: index)
                }
                let identifier = String(source[nameStart..<index])
                guard identifier == name else { continue }
                var cursor = index
                while cursor < source.endIndex, source[cursor].isWhitespace {
                    cursor = source.index(after: cursor)
                }
                guard cursor < source.endIndex, source[cursor] == ":" else { continue }
                cursor = source.index(after: cursor)
                while cursor < source.endIndex, source[cursor].isWhitespace {
                    cursor = source.index(after: cursor)
                }
                let valueStart = cursor
                let valueEnd = expressionEnd(in: source, start: valueStart)
                return valueStart..<valueEnd
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func replacingI18nLiteralProperty(named name: String, value: String, in source: String) -> String? {
        guard let objectRange = i18nInitObjectRange(in: source) else { return nil }
        let objectSource = String(source[objectRange])
        guard let valueRange = objectPropertyValueRange(named: name, in: objectSource) else { return nil }
        let objectOffset = source.distance(from: source.startIndex, to: objectRange.lowerBound)
        let valueStartOffset = objectSource.distance(from: objectSource.startIndex, to: valueRange.lowerBound)
        let valueEndOffset = objectSource.distance(from: objectSource.startIndex, to: valueRange.upperBound)
        let fullStart = source.index(source.startIndex, offsetBy: objectOffset + valueStartOffset)
        let fullEnd = source.index(source.startIndex, offsetBy: objectOffset + valueEndOffset)
        var updated = source
        updated.replaceSubrange(fullStart..<fullEnd, with: javaScriptStringLiteral(value))
        return updated
    }

    private static func expressionEnd(in source: String, start: String.Index) -> String.Index {
        var index = start
        var quote: Character?
        var isEscaped = false
        var depth = 0
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
            } else if character == "{" || character == "[" || character == "(" {
                depth += 1
            } else if character == "}" || character == "]" || character == ")" {
                if depth == 0 {
                    return index
                }
                depth -= 1
            } else if character == ",", depth == 0 {
                return index
            }
            index = source.index(after: index)
        }
        return index
    }

    private static func matchingDelimiterEnd(
        in source: String,
        start: String.Index,
        open: Character,
        close: Character
    ) -> String.Index? {
        var index = start
        var quote: Character?
        var isEscaped = false
        var depth = 0
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = source.index(after: index)
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                quote = character
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func configProperty(from expression: String?) -> OpenGraphiteI18nConfigProperty {
        guard let expression, !expression.isEmpty else {
            return missingI18nConfigProperty()
        }
        if let literal = literalStringValue(from: expression) {
            return OpenGraphiteI18nConfigProperty(
                source: .literal,
                value: literal,
                expression: nil,
                editable: true
            )
        }
        return OpenGraphiteI18nConfigProperty(
            source: .external,
            value: nil,
            expression: truncatedExpression(expression),
            editable: false
        )
    }

    private static func missingI18nConfigProperty() -> OpenGraphiteI18nConfigProperty {
        OpenGraphiteI18nConfigProperty(source: .missing, value: nil, expression: nil, editable: false)
    }

    private static func literalStringValue(from expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quote = trimmed.first, quote == "\"" || quote == "'" else {
            return nil
        }
        var index = trimmed.index(after: trimmed.startIndex)
        var result = ""
        var isEscaped = false
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == quote {
                let afterQuote = trimmed.index(after: index)
                let rest = trimmed[afterQuote...].trimmingCharacters(in: .whitespacesAndNewlines)
                return rest.isEmpty ? result : nil
            } else {
                result.append(character)
            }
            index = trimmed.index(after: index)
        }
        return nil
    }

    private static func localeFieldName(from expression: String?) -> String? {
        guard let expression else { return nil }
        for name in ["selectedLanguage", "locale", "language"] {
            if containsIdentifier(name, in: expression) {
                return name
            }
        }
        return nil
    }

    private static func containsIdentifier(_ name: String, in source: String) -> Bool {
        guard let range = source.range(of: name) else { return false }
        let before = range.lowerBound > source.startIndex ? source[source.index(before: range.lowerBound)] : " "
        let after = range.upperBound < source.endIndex ? source[range.upperBound] : " "
        return !isIdentifierCharacter(before) && !isIdentifierCharacter(after)
    }

    private static func firstQuotedString(in source: String) -> String? {
        var index = source.startIndex
        while index < source.endIndex {
            let quote = source[index]
            guard quote == "\"" || quote == "'" else {
                index = source.index(after: index)
                continue
            }
            var cursor = source.index(after: index)
            var result = ""
            var isEscaped = false
            while cursor < source.endIndex {
                let character = source[cursor]
                if isEscaped {
                    result.append(character)
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == quote {
                    return result
                } else {
                    result.append(character)
                }
                cursor = source.index(after: cursor)
            }
            return nil
        }
        return nil
    }

    private static func javaScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func normalizedScriptReference(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("./") {
            result = String(result.dropFirst(2))
        }
        return result
    }

    private static func variantValue(for locale: String, in variants: [String: String]) -> String? {
        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let value = variants[normalizedLocale] {
            return value
        }
        if normalizedLocale == "en", let value = variants["eng"] {
            return value
        }
        if normalizedLocale == "eng", let value = variants["en"] {
            return value
        }
        return nil
    }

    private static func truncatedExpression(_ expression: String) -> String {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 160 else { return trimmed }
        return "\(trimmed.prefix(157))..."
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character == "$" || character.isLetter
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }

    /// 論理名（日本語）: プロジェクトページターゲット解決関数
    /// 処理概要: `.ogp` を読み込み、page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(
        projectURL: URL,
        pageID: String,
        nodeReferenceIDs: [String] = []
    ) throws -> OpenGraphiteProjectPageTarget {
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)
        let resolvedPageID = try resolvedPageReferenceString(
            in: loadedProject.project,
            explicitPageID: pageID,
            nodeReferenceIDs: nodeReferenceIDs
        ) ?? pageID
        return try projectPageTarget(loadedProject: loadedProject, pageID: resolvedPageID)
    }

    /// 論理名（日本語）: Node ID正規化関数
    /// 処理概要: typed node 参照 ID が渡された場合は HTML 上の `data-og-internal-id` へ変換します。
    ///
    /// - Parameter id: raw node 内部 ID または `ogref:node` / `ogref:component-node`。
    /// - Returns: HTML 編集で使う node 内部 ID。
    private func resolvedNodeID(_ id: String) -> String {
        OpenGraphiteReferenceID.nodeInternalID(from: id) ?? id
    }

    /// 論理名（日本語）: 参照IDページ整合性検証関数
    /// 処理概要: typed node 参照が含む page / component が互いに、また明示 page ID と一致するか検証します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - explicitPageID: 呼び出し側が明示した page ID。
    ///   - nodeReferenceIDs: raw ID または typed node 参照 ID 候補。
    /// - Returns: typed node 参照から復元した `ogref:page` または `ogref:component`。存在しない場合は `nil`。
    private func resolvedPageReferenceString(
        in project: OpenGraphiteProject,
        explicitPageID: String,
        nodeReferenceIDs: [String]
    ) throws -> String? {
        var resolvedReferenceID: String?
        var resolvedLocation: OpenGraphiteProjectPageLocation?

        for nodeReferenceID in nodeReferenceIDs {
            guard let pageReferenceID = OpenGraphiteReferenceID.containingPageReferenceString(from: nodeReferenceID) else {
                continue
            }
            guard let pageLocation = pageLocation(in: project, pageID: pageReferenceID) else {
                throw OpenGraphiteAgentCoreError(
                    message: "node reference \"\(nodeReferenceID)\" が指す page \"\(pageReferenceID)\" が .ogp に存在しません。"
                )
            }

            if let currentLocation = resolvedLocation, currentLocation != pageLocation {
                throw OpenGraphiteAgentCoreError(
                    message: "node reference IDs が異なる page を指しています: \"\(resolvedReferenceID ?? "")\" と \"\(pageReferenceID)\"。"
                )
            }

            if resolvedLocation == nil {
                resolvedReferenceID = pageReferenceID
                resolvedLocation = pageLocation
            }
        }

        guard let resolvedReferenceID, let resolvedLocation else {
            return nil
        }

        if let explicitLocation = pageLocation(in: project, pageID: explicitPageID),
           explicitLocation != resolvedLocation {
            throw OpenGraphiteAgentCoreError(
                message: "pageID \"\(explicitPageID)\" と node reference \"\(resolvedReferenceID)\" が異なる page を指しています。"
            )
        }

        return resolvedReferenceID
    }

    /// 論理名（日本語）: 読み込み済みプロジェクトページターゲット解決関数
    /// 処理概要: 既に読み込んだ `.ogp` から page ID が指す HTML URL を検証して返します。
    ///
    /// - Parameters:
    ///   - loadedProject: 読み込み済み `.ogp`。
    ///   - pageID: ``.ogp` 内の page 参照 ID。
    /// - Returns: 内部ターゲット。
    private func projectPageTarget(
        loadedProject: LoadedOpenGraphiteProject,
        pageID: String
    ) throws -> OpenGraphiteProjectPageTarget {
        guard let location = pageLocation(in: loadedProject.project, pageID: pageID) else {
            throw OpenGraphiteAgentCoreError(message: "page id \"\(pageID)\" が .ogp に存在しません。")
        }
        let page: OpenGraphitePage
        let chapter: OpenGraphiteChapter?
        let collection: OpenGraphiteComponentCollection?
        switch location.segment {
        case .pages:
            let resolvedChapter = loadedProject.project.chapters[location.groupIndex]
            chapter = resolvedChapter
            collection = nil
            page = resolvedChapter.pages[location.pageIndex]
        case .components:
            chapter = nil
            let resolvedCollection = loadedProject.project.collections[location.groupIndex]
            collection = resolvedCollection
            page = resolvedCollection.components[location.pageIndex]
        }
        try validateProjectPagePath(page.path)
        let htmlURL = loadedProject.htmlURL(for: page).standardizedFileURL
        try ensureHTMLURL(htmlURL, staysInside: loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot))
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw OpenGraphiteAgentCoreError(message: ".ogp page \"\(pageID)\" の HTML が見つかりません: \(htmlURL.path)")
        }
        return OpenGraphiteProjectPageTarget(
            loadedProject: loadedProject,
            segment: location.segment.rawValue,
            chapter: chapter,
            collection: collection,
            page: page,
            htmlURL: htmlURL
        )
    }

    /// 論理名（日本語）: 既定Chapter位置取得関数
    /// 処理概要: page 追加先として使う先頭 Chapter の index を返します。
    ///
    /// - Parameter project: 対象 `.ogp` プロジェクト。
    /// - Returns: 先頭 Chapter の index。
    private func defaultChapterIndex(in project: OpenGraphiteProject) throws -> Int {
        guard !project.chapters.isEmpty else {
            throw OpenGraphiteAgentCoreError(message: ".ogp に chapters がありません。")
        }
        return 0
    }

    /// 論理名（日本語）: 書き込み可能Collection位置取得関数
    /// 処理概要: component 追加先 Collection を解決し、未指定かつ Collection がない場合は既定 Collection を作成します。
    ///
    /// - Parameters:
    ///   - project: 更新対象 `.ogp` project。
    ///   - collectionID: Collection の ID / 内部 ID / `ogref:collection`。
    /// - Returns: component 追加先 Collection の index。
    private func writableComponentCollectionIndex(
        in project: inout OpenGraphiteProject,
        collectionID: String?
    ) throws -> Int {
        let normalizedCollectionID = collectionID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedCollectionID, !normalizedCollectionID.isEmpty {
            let resolvedCollectionID = OpenGraphiteReferenceID.collectionInternalID(from: normalizedCollectionID)
                ?? normalizedCollectionID
            if let collectionIndex = project.collections.firstIndex(where: {
                $0.internalID == resolvedCollectionID || $0.id == resolvedCollectionID
            }) {
                return collectionIndex
            }
            throw OpenGraphiteAgentCoreError(message: "collection id \"\(collectionID ?? "")\" が見つかりません。")
        }

        if let collectionIndex = project.collections.firstIndex(where: { !$0.components.isEmpty }) {
            return collectionIndex
        }
        if let collectionIndex = project.collections.indices.first {
            return collectionIndex
        }

        project.collections.append(
            OpenGraphiteComponentCollection(
                id: OpenGraphiteComponentCollection.defaultID,
                internalID: "components",
                title: OpenGraphiteComponentCollection.defaultTitle,
                components: []
            )
        )
        return project.collections.count - 1
    }

    /// 論理名（日本語）: ページ位置検索関数
    /// 処理概要: Chapter / Collection 配列を横断し、指定 page ID、内部 ID、または複合参照 ID の位置を返します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - pageID: 検索する page ID、内部 ID、または複合参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func pageLocation(in project: OpenGraphiteProject, pageID: String) -> OpenGraphiteProjectPageLocation? {
        let normalizedPageID = pageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let typedLocation = typedPageLocation(in: project, referenceID: normalizedPageID) {
            return typedLocation
        }
        if let compoundLocation = compoundPageLocation(in: project, referenceID: normalizedPageID) {
            return compoundLocation
        }

        for chapterIndex in project.chapters.indices {
            if let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: {
                $0.id == normalizedPageID || $0.internalID == normalizedPageID
            }) {
                return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
            }
        }
        for collectionIndex in project.collections.indices {
            if let componentIndex = project.collections[collectionIndex].components.firstIndex(where: {
                $0.id == normalizedPageID || $0.internalID == normalizedPageID
            }) {
                return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: componentIndex)
            }
        }

        return nil
    }

    /// 論理名（日本語）: typedページ参照解決関数
    /// 処理概要: `ogref:page` / `ogref:component` / typed node 参照を page 位置へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - referenceID: typed agent 参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func typedPageLocation(in project: OpenGraphiteProject, referenceID: String) -> OpenGraphiteProjectPageLocation? {
        guard let reference = OpenGraphiteReferenceID(parsing: referenceID) else {
            return nil
        }

        switch reference.type {
        case .page, .node:
            let chapterID = reference.parts[0]
            let pageID = reference.parts[1]
            guard let chapterIndex = project.chapters.firstIndex(where: { $0.internalID == chapterID }),
                  let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == pageID })
            else {
                return nil
            }
            return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
        case .component, .componentNode:
            let collectionID = reference.parts[0]
            let componentID = reference.parts[1]
            guard let collectionIndex = project.collections.firstIndex(where: { $0.internalID == collectionID }),
                  let pageIndex = project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == componentID })
            else {
                return nil
            }
            return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: pageIndex)
        case .chapter, .collection:
            return nil
        }
    }

    /// 論理名（日本語）: 複合ページ参照解決関数
    /// 処理概要: raw `<chapterInternalID>:<pageInternalID>` または `<collectionInternalID>:<componentInternalID>` を page 位置へ解決します。
    ///
    /// - Parameters:
    ///   - project: 検索対象 `.ogp` プロジェクト。
    ///   - referenceID: agent 向け page または node 参照 ID。
    /// - Returns: 見つかった page の位置。存在しない場合は `nil`。
    private func compoundPageLocation(in project: OpenGraphiteProject, referenceID: String) -> OpenGraphiteProjectPageLocation? {
        let parts = referenceID.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        if parts.count >= 2,
           let chapterIndex = project.chapters.firstIndex(where: { $0.internalID == parts[0] }),
           let pageIndex = project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == parts[1] }) {
            return OpenGraphiteProjectPageLocation(segment: .pages, groupIndex: chapterIndex, pageIndex: pageIndex)
        }

        if parts.count >= 2,
           let collectionIndex = project.collections.firstIndex(where: { $0.internalID == parts[0] }),
           let pageIndex = project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == parts[1] }) {
            return OpenGraphiteProjectPageLocation(segment: .components, groupIndex: collectionIndex, pageIndex: pageIndex)
        }

        return nil
    }

    /// 論理名（日本語）: ページ要約生成関数
    /// 処理概要: Chapter ID と page 定義から、解決済み HTML URL を含む summary を生成します。
    ///
    /// - Parameters:
    ///   - page: 要約する page 定義。
    ///   - chapter: 所属 Chapter。Components の場合は `nil`。
    ///   - collection: 所属 Collection。Pages セグメントの場合は `nil`。
    ///   - chapterIndex: 所属 Chapter index。Components の場合は `nil`。
    ///   - collectionIndex: 所属 Collection index。Pages セグメントの場合は `nil`。
    ///   - pageIndex: Chapter または Collection 配列内の page index。
    ///   - loadedProject: 読み込み済み `.ogp`。
    /// - Returns: JSON 出力用 page summary。
    private func pageSummary(
        for page: OpenGraphitePage,
        chapter: OpenGraphiteChapter?,
        collection: OpenGraphiteComponentCollection?,
        chapterIndex: Int?,
        collectionIndex: Int?,
        pageIndex: Int,
        segment: String,
        loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphitePageSummary {
        OpenGraphitePageSummary(
            chapterID: chapter?.id,
            chapterInternalID: chapter?.internalID,
            collectionID: collection?.id,
            collectionInternalID: collection?.internalID,
            segment: segment,
            id: page.id,
            internalID: page.internalID,
            referenceID: pageReferenceID(segment: segment, chapter: chapter, collection: collection, page: page),
            chapterIndex: chapterIndex,
            collectionIndex: collectionIndex,
            pageIndex: pageIndex,
            path: page.path,
            htmlURL: loadedProject.htmlURL(for: page).path,
            canvas: page.canvas
        )
    }

    /// 論理名（日本語）: ページ参照ID生成関数
    /// 処理概要: 内部 ID から agent が HTML カードを一意に指定できる短い参照 ID を作ります。
    ///
    /// - Parameters:
    ///   - segment: `pages` または `components`。
    ///   - chapter: 所属 Chapter。Components の場合は `nil`。
    ///   - collection: 所属 Collection。Pages セグメントの場合は `nil`。
    ///   - page: 参照対象 page entry。
    /// - Returns: `ogref:page:<chapterInternalID>:<pageInternalID>` または `ogref:component:<collectionInternalID>:<componentInternalID>`。
    private func pageReferenceID(
        segment: String,
        chapter: OpenGraphiteChapter?,
        collection: OpenGraphiteComponentCollection?,
        page: OpenGraphitePage
    ) -> String {
        if segment == "components" {
            return OpenGraphiteReferenceID
                .component(collectionID: collection?.internalID ?? "", componentID: page.internalID)
                .stringValue
        }

        return OpenGraphiteReferenceID
            .page(chapterID: chapter?.internalID ?? "", pageID: page.internalID)
            .stringValue
    }

    /// 論理名（日本語）: キャンバス配置名正規化関数
    /// 処理概要: CLI / MCP から指定された配置名を trim し、未指定なら `nil` として既存値維持を表します。
    ///
    /// - Parameter name: ユーザー指定の配置名。`nil` の場合は未指定。
    /// - Returns: 保存する配置名。空白だけの場合は空文字。
    private func normalizedCanvasName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: Preview Context更新関数
    /// 処理概要: CLI / MCP から指定された runtime mock state の部分更新を既存値へ反映します。
    ///
    /// - Parameters:
    ///   - current: 既存 preview Mock State。
    ///   - fieldMocks: 更新する runtime mock state。`nil` の場合は既存値を維持します。
    /// - Returns: 更新後 preview Mock State。
    private func updatedPreviewContext(
        _ current: OpenGraphitePreviewContext,
        fieldMocks: [String: String]?
    ) throws -> OpenGraphitePreviewContext {
        var nextFieldMocks = current.fieldMocks
        if let fieldMocks {
            for (key, value) in fieldMocks {
                let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedKey.isEmpty else { continue }
                nextFieldMocks[normalizedKey] = value
            }
        }

        return OpenGraphitePreviewContext(fieldMocks: nextFieldMocks)
    }

    /// 論理名（日本語）: プロジェクトページパス検証関数
    /// 処理概要: `chapters[].pages[].path` が `htmlRoot` 相対の明示的な HTML path として安全かを検証します。
    ///
    /// - Parameter path: `htmlRoot` から見た HTML path。
    private func validateProjectPagePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if path.isEmpty
            || path.hasPrefix("/")
            || path.hasSuffix("/")
            || components.contains("")
            || components.contains("..")
            || components.contains(".")
            || URL(fileURLWithPath: path).pathExtension.lowercased() != "html" {
            throw OpenGraphiteAgentCoreError(message: "page path は htmlRoot 配下の相対 HTML path で指定してください: \(path)")
        }
    }

    /// 論理名（日本語）: HTML配置範囲検証関数
    /// 処理概要: 解決済み HTML URL が `.ogp` の `htmlRoot` 配下に残っていることを確認します。
    ///
    /// - Parameters:
    ///   - htmlURL: 解決済み HTML URL。
    ///   - htmlRootURL: `.ogp` から解決した HTML root URL。
    private func ensureHTMLURL(_ htmlURL: URL, staysInside htmlRootURL: URL) throws {
        let rootPath = htmlRootURL.standardizedFileURL.path
        let htmlPath = htmlURL.standardizedFileURL.path
        guard htmlPath == rootPath || htmlPath.hasPrefix(rootPath + "/") else {
            throw OpenGraphiteAgentCoreError(message: "page HTML は htmlRoot 配下に配置してください: \(htmlPath)")
        }
    }

    /// 論理名（日本語）: 相対パス生成関数
    /// 処理概要: HTML 配置ディレクトリから CSS library への相対 path を生成します。
    ///
    /// - Parameters:
    ///   - directoryURL: 参照元ディレクトリ URL。
    ///   - targetURL: 参照先ファイル URL。
    /// - Returns: 相対 path。
    private static func relativePath(from directoryURL: URL, to targetURL: URL) -> String {
        let sourceComponents = directoryURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0
        while sharedCount < sourceComponents.count,
              sharedCount < targetComponents.count,
              sourceComponents[sharedCount] == targetComponents[sharedCount] {
            sharedCount += 1
        }

        let upward = Array(repeating: "..", count: max(sourceComponents.count - sharedCount, 0))
        let downward = Array(targetComponents.dropFirst(sharedCount))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    /// 論理名（日本語）: HTML Document Context変更保存関数
    /// 処理概要: `<html>` attribute 更新結果を検証し、成功時に HTML ファイルへ書き戻します。
    ///
    /// - Parameters:
    ///   - mutation: HTML document context 変更結果。
    ///   - htmlURL: 対象 HTML ファイル URL。
    ///   - didChange: 元 HTML から差分があるか。
    /// - Returns: 保存結果。
    private func persistHTMLDocumentContextMutation(
        _ mutation: OpenGraphiteHTMLMutationResult,
        htmlURL: URL,
        didChange: Bool
    ) throws -> OpenGraphiteHTMLDocumentContextResult {
        let context = OpenGraphiteHTMLDocument(html: mutation.html).htmlDocumentContext()
        let blockingDiagnostics = mutation.diagnostics.filter { $0.severity == .error }
        guard blockingDiagnostics.isEmpty else {
            return OpenGraphiteHTMLDocumentContextResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                context: context,
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) }
            )
        }

        let candidateDocument = OpenGraphiteHTMLDocument(html: mutation.html)
        let candidateDiagnostics = validate(
            nodes: candidateDocument.nodes(),
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path
        )
        let allDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + candidateDiagnostics
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteHTMLDocumentContextResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                context: context,
                diagnostics: allDiagnostics
            )
        }

        if didChange {
            try mutation.html.write(to: htmlURL, atomically: true, encoding: .utf8)
        }
        return OpenGraphiteHTMLDocumentContextResult(
            schemaVersion: Self.schemaVersion,
            updated: didChange,
            path: htmlURL.path,
            context: context,
            diagnostics: allDiagnostics
        )
    }

    private func persistMutation(
        _ mutation: OpenGraphiteHTMLMutationResult,
        htmlURL: URL,
        nodeID: String,
        insertedNodeIDsBeforeMutation: Set<String>? = nil
    ) throws -> OpenGraphiteEditResult {
        let blockingDiagnostics = mutation.diagnostics.filter { $0.severity == .error }
        guard blockingDiagnostics.isEmpty else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: mutation.diagnostics.map { withPath($0, path: htmlURL.path) },
                insertedNodes: nil
            )
        }

        let candidateDocument = OpenGraphiteHTMLDocument(html: mutation.html)
        let candidateDiagnostics = validate(
            nodes: candidateDocument.nodes(),
            tags: candidateDocument.parsedTags(),
            path: htmlURL.path
        )
        let allDiagnostics = mutation.diagnostics.map { withPath($0, path: htmlURL.path) } + candidateDiagnostics
        guard !candidateDiagnostics.contains(where: { $0.severity == .error }) else {
            return OpenGraphiteEditResult(
                schemaVersion: Self.schemaVersion,
                updated: false,
                path: htmlURL.path,
                node: nil,
                diagnostics: allDiagnostics,
                insertedNodes: nil
            )
        }

        try mutation.html.write(to: htmlURL, atomically: true, encoding: .utf8)
        let graph = try pageGraph(at: htmlURL)
        let insertedNodes = insertedNodeIDsBeforeMutation.map { beforeIDs in
            graph.nodes.filter { !beforeIDs.contains($0.id) }
        }
        let node = graph.nodes.first { $0.internalID == nodeID }
            ?? insertedNodes?.first
        return OpenGraphiteEditResult(
            schemaVersion: Self.schemaVersion,
            updated: true,
            path: htmlURL.path,
            node: node,
            diagnostics: graph.diagnostics,
            insertedNodes: insertedNodes
        )
    }

    private func writeProject(_ project: OpenGraphiteProject, to projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(project.normalizedInternalIDs())
        data.append(0x0A)
        try data.write(to: projectURL, options: .atomic)
    }

    private func validate(
        nodes: [OpenGraphiteAgentNode],
        tags: [OpenGraphiteHTMLTag],
        path: String
    ) -> [OpenGraphiteDiagnostic] {
        var diagnostics: [OpenGraphiteDiagnostic] = []
        let groupedIDs = Dictionary(grouping: nodes, by: \.id)

        for (id, matches) in groupedIDs where matches.count > 1 {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-id",
                    message: "data-og-id \"\(id)\" が重複しています。",
                    path: path,
                    nodeID: id
                )
            )
        }

        for node in nodes where node.internalID.isEmpty {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-data-og-internal-id",
                    message: "\(node.id) に data-og-internal-id がありません。",
                    path: path,
                    nodeID: node.id
                )
            )
        }

        let groupedInternalIDs = Dictionary(grouping: nodes.filter { !$0.internalID.isEmpty }, by: \.internalID)
        for (id, matches) in groupedInternalIDs where matches.count > 1 {
            diagnostics.append(
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "duplicate-data-og-internal-id",
                    message: "data-og-internal-id \"\(id)\" が重複しています。",
                    path: path,
                    nodeID: matches.first?.id
                )
            )
        }

        for tag in tags {
            for attribute in tag.attributes where contract.runtimeAttributeSet.contains(attribute.name) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-attribute-persisted",
                        message: "\(attribute.name) は正本 HTML に残せない実行時属性です。",
                        path: path,
                        nodeID: tag.attributeValue(named: "data-og-id")
                    )
                )
            }
        }

        for node in nodes {
            if node.type.isEmpty {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "missing-data-og-type",
                        message: "\(node.id) に data-og-type がありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            } else if !contract.typeSet.contains(node.type) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unknown-data-og-type",
                        message: "\(node.type) は既知の data-og-type ではありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            if let layout = node.layout, !contract.layoutSet.contains(layout) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "unknown-data-og-layout",
                        message: "\(layout) は既知の data-og-layout ではありません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            if let role = node.role, !contract.roleSet.contains(role) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-data-og-role",
                        message: "\(role) は OpenGraphite.contract.json に定義されていない role です。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            for key in node.cssVariables.keys.sorted() where !contract.cssVariableSet.contains(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .warning,
                        code: "unknown-css-variable",
                        message: "\(key) は OpenGraphite.contract.json に定義されていません。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }

            for key in node.cssVariables.keys.sorted() where contract.runtimeCSSVariableSet.contains(key) {
                diagnostics.append(
                    OpenGraphiteDiagnostic(
                        severity: .error,
                        code: "runtime-css-variable-persisted",
                        message: "\(key) は正本 HTML に残せない実行時 CSS 変数です。",
                        path: path,
                        nodeID: node.id
                    )
                )
            }
        }

        return diagnostics
    }

    private func uniqueNodeDiagnostics(
        matches: [OpenGraphiteAgentNode],
        id: String,
        path: String
    ) -> [OpenGraphiteDiagnostic] {
        if matches.count == 1 {
            return []
        }

        if matches.isEmpty {
            return [
                OpenGraphiteDiagnostic(
                    severity: .error,
                    code: "missing-node",
                    message: "data-og-internal-id \"\(id)\" を持つノードが見つかりません。",
                    path: path,
                    nodeID: id
                )
            ]
        }

        return [
            OpenGraphiteDiagnostic(
                severity: .error,
                code: "duplicate-data-og-internal-id",
                message: "data-og-internal-id \"\(id)\" が \(matches.count) 件あります。",
                path: path,
                nodeID: id
            )
        ]
    }

    private func withPath(_ diagnostic: OpenGraphiteDiagnostic, path: String) -> OpenGraphiteDiagnostic {
        OpenGraphiteDiagnostic(
            severity: diagnostic.severity,
            code: diagnostic.code,
            message: diagnostic.message,
            path: diagnostic.path ?? path,
            nodeID: diagnostic.nodeID
        )
    }

    private static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeText(value).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// 論理名（日本語）: Agent coreエラー
/// 概要: project file 更新など、diagnostics ではなく処理自体を止めるエラーです。
///
/// プロパティ:
/// - `message`: エラー説明。
struct OpenGraphiteAgentCoreError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}

private extension String {
    /// 論理名（日本語）: 空文字nil化済みtrim文字列
    /// 概要: 前後空白を除去し、空文字なら `nil` として返します。
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
