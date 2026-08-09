import AppKit
import Foundation

/// 論理名（日本語）: ノードドラッグプレビュー
/// 概要: WebView 内でドラッグ中の選択ノード矩形を、Canvas 側の選択枠へ一時反映するための状態です。
///
/// プロパティ:
/// - `pageInternalID`: preview を送信した page card の内部 ID。
/// - `nodeID`: ドラッグ中の node ID。
/// - `rect`: page content 座標上のドラッグ中矩形。
struct OpenGraphiteNodeDragPreview: Equatable {
    var pageInternalID: String?
    var nodeID: String
    var rect: CGRect
}

/// 論理名（日本語）: 選択オーバーレイ矩形
/// 概要: WebView の `getBoundingClientRect()` 由来の実測矩形を、Canvas 側の選択枠へ渡すための状態です。
///
/// プロパティ:
/// - `pageInternalID`: rect を送信した page card の内部 ID。
/// - `primaryNodeID`: Inspector が扱う主選択 node ID。
/// - `nodeIDs`: 実測 rect を持つ選択 node ID 一覧。
/// - `nodeRectsByID`: node ID ごとの WebView viewport 座標上の実測矩形。
/// - `rect`: 選択 node 群全体を覆う union 矩形。
struct OpenGraphiteSelectionOverlayFrame: Equatable {
    var pageInternalID: String?
    var primaryNodeID: String
    var nodeIDs: [String]
    var nodeRectsByID: [String: CGRect]
    var rect: CGRect
}

/// 論理名（日本語）: フォーカスプレビュー対象
/// 概要: 右クリックで単独表示する HTML object または page 全体と、その表示範囲を通常選択から独立して保持するセッション状態です。
///
/// プロパティ:
/// - `segment`: 対象 page が属する Pages / Components セグメント。
/// - `pageInternalID`: 対象 object を含む page card の内部 ID。
/// - `nodeID`: 単独表示する node ID。page 全体を表示する場合は `nil`。
/// - `rect`: page document 座標上の object 実測矩形、または page 全体の矩形。
struct OpenGraphiteFocusedPreviewTarget: Equatable, Identifiable {
    var segment: OpenGraphiteCanvasSegment
    var pageInternalID: String
    var nodeID: String?
    var rect: CGRect

    var id: String {
        let subjectID = nodeID.map { "node:\($0)" } ?? "whole-page"
        return "\(segment.rawValue):\(pageInternalID):\(subjectID)"
    }
}

/// 論理名（日本語）: エディター履歴表示状態
/// 概要: 作業履歴の各項目が現在適用済みで取り消せるか、取り消し済みでやり直せるかを表します。
///
/// 定義内容:
/// - `undoable`: 現在適用済みで Undo 対象になっている項目。
/// - `redoable`: Undo 済みで Redo 対象になっている項目。
enum EditorHistoryItemState: Equatable {
    case undoable
    case redoable
}

/// 論理名（日本語）: エディター履歴簡易プレビュー種別
/// 概要: 左サイドバーの履歴行で、編集対象を小さな図として識別するための表示情報です。
///
/// 定義内容:
/// - `node`: HTMLオブジェクトまたはpageと、DOM capabilityから導出した表示専用hint。
/// - `stickyNote`: 背景色と本文を持つ付箋。
/// - `ink`: 代表色を持つ手書き。
/// - `guide`: 水平または垂直ガイド。
/// - `reference`: HTML オブジェクト参照配置。
enum EditorHistoryPreviewKind: Equatable {
    case node(hint: OpenGraphiteNodePresentationHint)
    case stickyNote(backgroundColor: String, text: String)
    case ink(color: String)
    case guide(orientation: OpenGraphiteCanvasGuideOrientation)
    case reference
}

/// 論理名（日本語）: エディター履歴表示項目
/// 概要: 統合 Undo / Redo 時系列を、サイドバーへ表示するための時刻・対象名・簡易プレビューへ変換した値です。
///
/// プロパティ:
/// - `id`: 同じ操作が Undo / Redo 間を移動しても維持される識別子。
/// - `timestamp`: 操作が正本へ確定した時刻。
/// - `objectName`: 操作対象オブジェクトの表示名。
/// - `actionName`: 履歴行で補助表示する操作名。
/// - `previewKind`: 対象の簡易プレビュー種別。
/// - `state`: Undo 可能または Redo 可能の表示状態。
struct EditorHistoryListItem: Equatable, Identifiable {
    var id: UUID
    var timestamp: Date
    var objectName: String
    var actionName: String
    var previewKind: EditorHistoryPreviewKind
    var state: EditorHistoryItemState
}

/// 論理名（日本語）: キャンバス参照非同期解決状態
/// 概要: SwiftUI描画とHTML参照解決を分離し、placeholder、解決済み対象、利用者向けエラーを表します。
///
/// 定義内容:
/// - `idle`: 解決task開始前。
/// - `loading`: backgroundでHTML参照を解決中。
/// - `resolved`: 現在のproject / page revisionに対する解決済み対象。
/// - `failed`: 現在のrevisionで参照を解決できない状態。
enum OpenGraphiteCanvasReferenceResolutionState: Equatable {
    case idle
    case loading
    case resolved(OpenGraphiteResolvedCanvasReference)
    case failed(String)

    /// 論理名（日本語）: 解決済み参照取得関数
    /// 処理概要: 現在状態が解決済みの場合だけCanvas表示対象を返します。
    ///
    /// - Returns: 解決済み参照。未解決・読込中・失敗時は`nil`。
    var target: OpenGraphiteResolvedCanvasReference? {
        guard case let .resolved(target) = self else { return nil }
        return target
    }

    /// 論理名（日本語）: 参照解決エラー取得関数
    /// 処理概要: 解決失敗状態に保持した利用者向けメッセージを返します。
    ///
    /// - Returns: 解決失敗メッセージ。失敗以外は`nil`。
    var errorMessage: String? {
        guard case let .failed(message) = self else { return nil }
        return message
    }
}

/// 論理名（日本語）: キャンバス参照解決キャッシュkey
/// 概要: project instance、typed参照ID、HTML URL、page reload tokenを束縛してstaleな解決結果を再利用しないようにします。
///
/// プロパティ:
/// - `projectID`: 読み込み済みproject instance ID。
/// - `referenceID`: 正規化済みtyped参照ID。
/// - `pageURL`: 参照元HTML URL。
/// - `reloadToken`: HTML変更ごとに進むrevision token。
private struct CanvasReferenceResolutionCacheKey: Hashable {
    var projectID: UUID
    var referenceID: String
    var pageURL: URL
    var reloadToken: Int
}

/// 論理名（日本語）: ノード正本索引キャッシュkey
/// 概要: 表示中page、media condition、参照component、各source revisionを束縛し、staleな正本graphをLayersへ再利用しないようにします。
///
/// プロパティ:
/// - `projectID`: 読み込み済みproject instance。単独HTMLでは空文字列。
/// - `targetURL`: 表示中HTML URL。
/// - `pageReferenceID`: Shared graphへ渡すpage/component参照ID。
/// - `targetReloadToken`: 表示中HTMLと依存sourceのrevision token。
/// - `activeMediaQueries`: WebKitでmatchしたauthored media condition。
/// - `referencedComponentIDs`: runtime nodeが実際に参照するcomponent ID。
/// - `referencedSourceNodeIDs`: runtime nodeが実際に参照するsource internal ID。
/// - `componentRevisions`: 登録component pageごとのreload revision。
private struct NodeSourceIndexCacheKey: Hashable, @unchecked Sendable {
    var projectID: String
    var targetURL: URL
    var pageReferenceID: String
    var targetReloadToken: Int
    var activeMediaQueries: [String]
    var referencedComponentIDs: [String]
    var referencedSourceNodeIDs: [String]
    var componentRevisions: [String]
}

/// 論理名（日本語）: Component正本索引候補
/// 概要: runtime payloadが参照したcomponentだけをbackground graph化するための登録page情報です。
///
/// プロパティ:
/// - `pageReferenceID`: Shared graphへ渡すcomponent page参照ID。
/// - `htmlURL`: component master HTML URL。
private struct NodeSourceIndexComponent: Hashable, @unchecked Sendable {
    var pageReferenceID: String
    var htmlURL: URL
}

/// 論理名（日本語）: ノード正本索引リクエスト
/// 概要: MainActorから切り離してShared source graphを構築するために必要なimmutable入力を保持します。
///
/// プロパティ:
/// - `key`: revisionを含むcache key。
/// - `projectURL`: `.ogp` URL。単独HTMLでは`nil`。
/// - `projectRootURL`: contractとresource解決の開始URL。
/// - `targetHTMLURL`: 表示中HTML URL。
/// - `components`: 登録component page候補。
private struct NodeSourceIndexRequest: @unchecked Sendable {
    var key: NodeSourceIndexCacheKey
    var projectURL: URL?
    var projectRootURL: URL
    var targetHTMLURL: URL
    var components: [NodeSourceIndexComponent]
}

/// 論理名（日本語）: 現在HTML正本ノード索引
/// 概要: annotation済みnodeはinternal ID、未注釈nodeはsafe selectorとbrowser投影済みDOM pathでWebCanvas payloadへ結びます。
///
/// プロパティ:
/// - `byInternalID`: pageと実参照componentの一意なinternal ID索引。
/// - `bySelector`: 現在page内の一意なsafe selector索引。
/// - `byBrowserDOMPath`: 現在page内のbrowser-equivalent DOM path索引。
private struct CurrentSourceNodeIndexes: @unchecked Sendable {
    var byInternalID: [String: OpenGraphiteAgentNode]
    var bySelector: [String: OpenGraphiteAgentNode]
    var byBrowserDOMPath: [String: OpenGraphiteAgentNode]

    static let empty = CurrentSourceNodeIndexes(
        byInternalID: [:],
        bySelector: [:],
        byBrowserDOMPath: [:]
    )
}

/// 論理名（日本語）: ノード正本索引background builder
/// 概要: 表示中pageとruntime payloadが実参照するcomponentだけをShared graph化し、MainActorへimmutable索引を返します。
private enum OpenGraphiteNodeSourceIndexBuilder {
    /// 論理名（日本語）: ノード正本索引生成関数
    /// 処理概要: page graphと必要なcomponent graphをbackgroundで構築し、selectorとbrowser DOM pathの衝突を除外します。
    ///
    /// - Parameter request: project、target、media、参照componentを固定した入力。
    /// - Returns: WebCanvas payloadのsource provenance補完に使う索引。
    static func build(_ request: NodeSourceIndexRequest) -> CurrentSourceNodeIndexes {
        guard let html = try? String(contentsOf: request.targetHTMLURL, encoding: .utf8) else {
            return .empty
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: request.projectRootURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        var byInternalID = componentNodes(
            request: request,
            contract: contract,
            core: core
        )
        var bySelector: [String: OpenGraphiteAgentNode] = [:]
        var ambiguousSelectors: Set<String> = []
        var byBrowserDOMPath: [String: OpenGraphiteAgentNode] = [:]
        var ambiguousBrowserDOMPaths: Set<String> = []
        let currentNodes: [OpenGraphiteAgentNode]
        if let projectURL = request.projectURL,
           !request.key.pageReferenceID.isEmpty,
           let graph = try? core.pageGraph(
               projectURL: projectURL,
               pageID: request.key.pageReferenceID,
               activeMediaQueries: request.key.activeMediaQueries
           ) {
            currentNodes = graph.nodes
        } else {
            let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: request.targetHTMLURL)
            currentNodes = OpenGraphiteHTMLDocument(html: html).nodes(
                companionCSS: companionCSS,
                activeMediaQueries: request.key.activeMediaQueries,
                contract: contract,
                documentURL: request.targetHTMLURL.standardizedFileURL.absoluteString
            )
        }

        let internalIDCounts = Dictionary(
            grouping: currentNodes.filter { !$0.internalID.isEmpty },
            by: \.internalID
        ).mapValues(\.count)
        currentNodes.forEach { node in
            if !node.internalID.isEmpty, internalIDCounts[node.internalID] == 1 {
                byInternalID[node.internalID] = node
            } else if !node.internalID.isEmpty {
                byInternalID.removeValue(forKey: node.internalID)
            }
            if let selector = node.locator.selector, !selector.isEmpty {
                insertUnique(
                    node,
                    key: selector,
                    into: &bySelector,
                    ambiguousKeys: &ambiguousSelectors
                )
            }
        }
        let browserPaths = browserDOMPathsBySourceDOMPath(for: currentNodes)
        currentNodes.forEach { node in
            guard let browserPath = browserPaths[node.locator.domPath] else { return }
            insertUnique(
                node,
                key: browserPath,
                into: &byBrowserDOMPath,
                ambiguousKeys: &ambiguousBrowserDOMPaths
            )
        }
        return CurrentSourceNodeIndexes(
            byInternalID: byInternalID,
            bySelector: bySelector,
            byBrowserDOMPath: byBrowserDOMPath
        )
    }

    /// runtime payloadが参照したcomponentを含む登録pageだけをgraph化します。
    private static func componentNodes(
        request: NodeSourceIndexRequest,
        contract: OpenGraphiteContract,
        core: OpenGraphiteAgentCore
    ) -> [String: OpenGraphiteAgentNode] {
        guard let projectURL = request.projectURL,
              !request.key.referencedComponentIDs.isEmpty || !request.key.referencedSourceNodeIDs.isEmpty
        else { return [:] }
        var result: [String: OpenGraphiteAgentNode] = [:]
        for component in request.components where component.htmlURL.standardizedFileURL != request.targetHTMLURL.standardizedFileURL {
            guard let html = try? String(contentsOf: component.htmlURL, encoding: .utf8) else { continue }
            let isReferenced = request.key.referencedComponentIDs.contains { html.contains($0) }
                || request.key.referencedSourceNodeIDs.contains { html.contains($0) }
            guard isReferenced else { continue }
            let nodes: [OpenGraphiteAgentNode]
            if let graph = try? core.pageGraph(
                projectURL: projectURL,
                pageID: component.pageReferenceID,
                activeMediaQueries: request.key.activeMediaQueries
            ) {
                nodes = graph.nodes
            } else {
                let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: component.htmlURL)
                nodes = OpenGraphiteHTMLDocument(html: html).nodes(
                    companionCSS: companionCSS,
                    activeMediaQueries: request.key.activeMediaQueries,
                    contract: contract,
                    documentURL: component.htmlURL.standardizedFileURL.absoluteString
                )
            }
            nodes.forEach { node in
                guard !node.internalID.isEmpty, node.referenceStability == .stable else { return }
                result[node.internalID] = node
            }
        }
        return result
    }

    /// source DOM pathをbrowserのimplicit container込みpathへ投影します。
    private static func browserDOMPathsBySourceDOMPath(
        for nodes: [OpenGraphiteAgentNode]
    ) -> [String: String] {
        var sourceIndexByDOMPath: [String: Int] = [:]
        var sourceNodes: [OpenGraphiteCSSDOMSourceNode] = []
        for node in nodes {
            let sourceDOMPath = node.locator.domPath
            let segments = sourceDOMPath.components(separatedBy: " > ")
            let parentDOMPath = segments.count > 1
                ? segments.dropLast().joined(separator: " > ")
                : ""
            let parentIndex = parentDOMPath.isEmpty ? nil : sourceIndexByDOMPath[parentDOMPath]
            let sourceIndex = sourceNodes.count
            sourceNodes.append(
                OpenGraphiteCSSDOMSourceNode(
                    element: OpenGraphiteCSSDOMElement(
                        tagName: node.tagName,
                        attributes: node.attributes
                    ),
                    parentIndex: parentIndex
                )
            )
            if !sourceDOMPath.isEmpty {
                sourceIndexByDOMPath[sourceDOMPath] = sourceIndex
            }
        }

        let projection = OpenGraphiteCSSDOMProjection.browserDocument(from: sourceNodes)
        var result: [String: String] = [:]
        for sourceIndex in sourceNodes.indices {
            guard nodes.indices.contains(sourceIndex),
                  let projectedIndex = projection.projectedIndexBySourceIndex[sourceIndex]
            else { continue }
            let element = projection.nodes[projectedIndex].element
            let browserSegments = ([element] + element.ancestors).reversed().map {
                "\($0.tagName):nth-of-type(\($0.typeIndex))"
            }
            result[nodes[sourceIndex].locator.domPath] = browserSegments.joined(separator: " > ")
        }
        return result
    }

    /// 同じselector/pathが複数nodeへ衝突する場合は誤mergeを避けて索引から除外します。
    private static func insertUnique(
        _ node: OpenGraphiteAgentNode,
        key: String,
        into index: inout [String: OpenGraphiteAgentNode],
        ambiguousKeys: inout Set<String>
    ) {
        guard !key.isEmpty, !ambiguousKeys.contains(key) else { return }
        if let existing = index[key], existing.reference != node.reference {
            index.removeValue(forKey: key)
            ambiguousKeys.insert(key)
            return
        }
        index[key] = node
    }
}

/// 論理名（日本語）: Node adoption確認プレビュー
/// 概要: 未注釈または部分注釈nodeへoptional identityを追加するdry-run結果と、target・document revision・scope・display IDを束縛した明示apply専用proposal tokenを保持します。
///
/// プロパティ:
/// - `id`: confirmation sheetを識別する一意な値。
/// - `nodeID`: WebCanvas session内の選択ID。
/// - `displayName`: UI表示用node名。
/// - `scope`: node単体またはsubtree。
/// - `reference`: dry-runが返したtarget locator、document content hash、正規化済みscope / display ID固定のapply専用proposal token。
/// - `selector`: dry-run解決後のapplyでは常に`nil`。
/// - `domPath`: dry-run解決後のapplyでは常に`nil`。
/// - `displayID`: ユーザーが明示指定した場合だけ渡すoptional display ID。通常は`nil`。
/// - `path`: dry-run対象HTML path。
/// - `changed`: candidate sourceに差分があるか。
/// - `unifiedDiff`: 適用前に確認するsource diff。
/// - `diagnostics`: dry-run diagnostics。
struct OpenGraphiteNodeAdoptionPreview: Equatable, Identifiable {
    var id: UUID
    var nodeID: String
    var displayName: String
    var scope: OpenGraphiteNodeAdoptionScope
    var reference: String?
    var selector: String?
    var domPath: String?
    var displayID: String?
    var path: String
    var changed: Bool
    var unifiedDiff: String
    var diagnostics: [OpenGraphiteDiagnostic]
}

/// 論理名（日本語）: Project migration状態
/// 概要: Project Inspectorで、明示migrationの未確認・差分あり・最新・適用済み・stale・失敗状態を表示します。
///
/// 定義内容:
/// - `unavailable`: project未読込でmigrationを開始できない状態。
/// - `notChecked`: sourceを走査しておらず、明示dry-run待ちの状態。
/// - `changesAvailable`: dry-runで適用候補差分が見つかった状態。
/// - `upToDate`: dry-runで変更不要と確認できた状態。
/// - `applied`: 確認済みproposalを適用して表示を再読込した状態。
/// - `stale`: dry-run後にsourceが変わり、proposalを再作成する必要がある状態。
/// - `failed`: migration transactionを適用できなかった状態。
enum OpenGraphiteProjectMigrationStatus: Equatable {
    case unavailable
    case notChecked(targetVersion: String)
    case changesAvailable(sourceVersion: String, targetVersion: String, fileCount: Int)
    case upToDate(version: String)
    case applied(version: String, fileCount: Int)
    case stale(targetVersion: String)
    case failed(targetVersion: String, message: String)

    /// 論理名（日本語）: Migration状態ラベル
    /// 処理概要: Inspectorのstatus行に表示する短い状態名を返します。
    var label: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .notChecked:
            return "Not checked"
        case .changesAvailable:
            return "Changes available"
        case .upToDate:
            return "Up to date"
        case .applied:
            return "Applied"
        case .stale:
            return "Preview stale"
        case .failed:
            return "Failed"
        }
    }

    /// 論理名（日本語）: Migration対象version
    /// 処理概要: 状態が保持するtarget Web contract versionを返します。
    var targetVersion: String? {
        switch self {
        case .unavailable:
            return nil
        case .notChecked(let targetVersion),
             .changesAvailable(_, let targetVersion, _),
             .stale(let targetVersion),
             .failed(let targetVersion, _):
            return targetVersion
        case .upToDate(let version), .applied(let version, _):
            return version
        }
    }

    /// 論理名（日本語）: Migration状態詳細
    /// 処理概要: 明示操作の次の手順または結果をInspector向けの説明文として返します。
    var detail: String {
        switch self {
        case .unavailable:
            return "Projectを開くとmigrationを確認できます。"
        case .notChecked:
            return "Sourceは未走査です。Preview Migrationで差分を確認してください。"
        case .changesAvailable(_, _, let fileCount):
            return "\(fileCount) source file(s)に確認待ちの差分があります。"
        case .upToDate:
            return "標準Web contractへの変更はありません。"
        case .applied(_, let fileCount):
            return "\(fileCount) source file(s)を更新し、Project表示を再読込しました。"
        case .stale:
            return "Sourceがdry-run後に変わりました。Previewを更新してください。"
        case .failed(_, let message):
            return message
        }
    }
}

/// 論理名（日本語）: Project migration確認プレビュー
/// 概要: Project全体のdry-run結果、multi-file diff、apply専用proposal、stale/diagnostic状態をconfirmation sheetへ渡します。
///
/// プロパティ:
/// - `id`: confirmation sheetを識別する一意な値。
/// - `sourceContractVersion`: migration入力として判定されたWeb contract version。
/// - `targetContractVersion`: 明示apply後のWeb contract version。
/// - `proposalReference`: source hash・target・optionsを束縛したapply専用proposal token。
/// - `changed`: candidate sourceに差分があるか。
/// - `diffs`: path順のmulti-file source差分。
/// - `diagnostics`: dry-runまたはapplyのdiagnostics。
struct OpenGraphiteProjectMigrationPreview: Equatable, Identifiable {
    var id: UUID
    var sourceContractVersion: String
    var targetContractVersion: String
    var proposalReference: String?
    var changed: Bool
    var diffs: [OpenGraphiteSourceDiff]
    var diagnostics: [OpenGraphiteDiagnostic]

    /// 論理名（日本語）: Stale proposal判定
    /// 処理概要: Shared coreのmachine-readable diagnosticから再dry-runが必要かを判定します。
    var isStale: Bool {
        diagnostics.contains { $0.code == "stale-migration-proposal" }
    }

    /// 論理名（日本語）: Migration適用可否
    /// 処理概要: 差分とproposalがあり、errorまたはstale diagnosticがない場合だけ明示Applyを許可します。
    var canApply: Bool {
        changed
            && !(proposalReference?.isEmpty ?? true)
            && !isStale
            && !diagnostics.contains { $0.severity == .error }
    }
}

/// 論理名（日本語）: エディター状態ストア
/// 概要: 読み込み済みプロジェクト、Pages/Components 選択、DOM ノード一覧、Inspector 変更要求を保持するメイン状態管理クラスです。
///
/// プロパティ:
/// - `loadedProject`: 現在開いている `.ogp`。
/// - `selectedCanvasSegment`: 中央キャンバスに表示する Pages / Components セグメント。
/// - `selectedChapterID`: 選択中 Chapter の ID。
/// - `selectedChapterInternalID`: 選択中 Chapter の内部 ID。
/// - `selectedPageID`: 選択中ページの ID。
/// - `selectedPageInternalID`: 選択中ページカードの内部 ID。
/// - `selectedCollectionID`: 選択中 Component Collection の ID。
/// - `selectedCollectionInternalID`: 選択中 Component Collection の内部 ID。
/// - `selectedComponentPageID`: 選択中 component canvas の ID。
/// - `selectedComponentPageInternalID`: 選択中 component canvas カードの内部 ID。
/// - `selectedCanvasAnnotationID`: 選択中の `.ogp` 専用キャンバス注釈の primary ID。
/// - `selectedCanvasAnnotationIDs`: なげわを含む Canvas 操作で同時選択中の注釈 ID 集合。
/// - `selectedCanvasReferenceID`: 選択中のキャンバス直下オブジェクト参照配置 ID。
/// - `selectedCanvasReferenceTarget`: 選択中参照が解決したHTMLカードとnode。
/// - `nodes`: WebView から抽出された編集ノード一覧。
/// - `selectedNodeID`: 選択中ノードのWebCanvas selection key。annotation済みID、session reference、placement clone用合成IDを区別します。
/// - `selectedNodeIDs`: Sidebar Layers 上で同時選択されている node ID 一覧。
/// - `zoom`: キャンバス表示倍率。
/// - `activeTool`: キャンバス上の選択ツール。
/// - `previewDisplayMode`: 中央キャンバスの通常/フロー表示モード。
/// - `focusedPreviewTarget`: 右クリックで単独表示している object のセッション状態。
/// - `selectionOverlayFrame`: WebView 実測値から作る選択ノード表示枠。
/// - `nodeDragPreview`: ドラッグ中だけ使う選択ノード矩形 preview。
/// - `hoveredStaticFlowSource`: HTML プレビュー内でホバー中の静的フロー遷移元リンク。
/// - `staticFlowLinksByPageInternalID`: page card 内部 ID ごとに収集した静的フローリンク。
/// - `cssMutation`: WebView へ反映待ちの CSS declaration 変更。
/// - `cssVariablesMutation`: WebView へ反映待ちの複数 CSS declaration 変更。
/// - `attributeMutation`: WebView へ反映待ちの属性変更。
/// - `textMutation`: WebView へ反映待ちの text content 変更。
/// - `documentReplacementRequest`: undo/redo で WebView へ適用する HTML 置換要求。
/// - `inspectorSectionOpenRequest`: Preview 側編集に応じて Inspector カードを開く one-shot 要求。
/// - `nodeAdoptionPreview`: 明示adoptのdry-run差分を確認するsheet state。
/// - `projectMigrationStatus`: Project Inspectorへ表示する明示migration状態。
/// - `projectMigrationPreview`: Project全体のdry-run差分を確認するsheet state。
/// - `canvasReferenceResolutionCache`: project / page revisionごとの非同期Canvas Object Reference解決状態。
/// - `nodeSourceIndexBuildCount`: 同一revisionの正本graph cache再利用を回帰テストで確認する構築回数。
@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var loadedProject: LoadedOpenGraphiteProject?
    @Published var selectedCanvasSegment: OpenGraphiteCanvasSegment = .pages
    @Published var selectedChapterID: String?
    @Published var selectedChapterInternalID: String?
    @Published var selectedPageID: String?
    @Published var selectedPageInternalID: String?
    @Published var selectedCollectionID: String?
    @Published var selectedCollectionInternalID: String?
    @Published var selectedComponentPageID: String?
    @Published var selectedComponentPageInternalID: String?
    @Published var selectedCanvasAnnotationID: String? {
        didSet {
            guard !isApplyingCanvasAnnotationMultiSelection else { return }
            selectedCanvasAnnotationIDs = selectedCanvasAnnotationID.map { Set([$0]) } ?? []
        }
    }
    @Published private(set) var selectedCanvasAnnotationIDs: Set<String> = []
    @Published private(set) var selectedCanvasReferenceID: String?
    @Published private(set) var selectedCanvasReferenceTarget: OpenGraphiteResolvedCanvasReference?
    @Published var selectedProjectResource: OpenGraphiteProjectResourceSelection? {
        didSet {
            guard oldValue != selectedProjectResource else { return }
            inspectorSectionOpenRequest = nil
        }
    }
    @Published private(set) var nodes: [OpenGraphiteNode] = [] {
        didSet {
            if nodes.isEmpty {
                cssVariableBaselinesByInternalID = [:]
                selectionOverlayFrame = nil
                nodeSourceIndexTask?.cancel()
                nodeSourceIndexTask = nil
                nodeSourceIndexTaskKey = nil
                latestNodeSourceIndexKey = nil
                latestLayerNodePayload = []
                nodeDetailPayloadsByID = [:]
            }
        }
    }
    @Published var selectedNodeID: String? {
        didSet {
            guard oldValue != selectedNodeID else { return }
            if selectedNodeID != nil {
                selectedCanvasAnnotationID = nil
            }
            synchronizeLayerNodeSelectionForPrimarySelection()
            inspectorSectionOpenRequest = nil
            nodeAdoptionPreview = nil
            selectionOverlayFrame = nil
            nodeDragPreview = nil
        }
    }
    @Published private(set) var selectedNodeIDs: Set<String> = []
    @Published var zoom: Double = 0.72
    @Published var statusMessage = "HTMLを正本として開きます。"
    @Published var lastError: String?
    @Published var activeTool: CanvasTool = .select
    @Published var previewDisplayMode: OpenGraphitePreviewDisplayMode = .normal
    @Published private(set) var focusedPreviewTarget: OpenGraphiteFocusedPreviewTarget?
    @Published private(set) var selectionOverlayFrame: OpenGraphiteSelectionOverlayFrame?
    @Published private(set) var nodeDragPreview: OpenGraphiteNodeDragPreview?
    @Published private(set) var hoveredStaticFlowSource: OpenGraphiteStaticFlowSourceHover?
    @Published private(set) var cssMutation: CSSVariableMutation?
    @Published private(set) var cssVariablesMutation: CSSVariablesMutation?
    @Published private(set) var cssVariablesBatchMutation: CSSVariablesBatchMutation?
    @Published private(set) var attributeMutation: NodeAttributeMutation?
    @Published private(set) var textMutation: NodeTextContentMutation?
    @Published private(set) var documentReplacementRequest: DocumentReplacementRequest?
    @Published private(set) var inspectorSectionOpenRequest: InspectorSectionOpenRequest?
    @Published var nodeAdoptionPreview: OpenGraphiteNodeAdoptionPreview?
    @Published private(set) var projectMigrationStatus: OpenGraphiteProjectMigrationStatus = .unavailable
    @Published var projectMigrationPreview: OpenGraphiteProjectMigrationPreview?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var historyItems: [EditorHistoryListItem] = []
    @Published private(set) var pageReloadTokensByURL: [URL: Int] = [:]
    @Published private(set) var staticFlowLinksByPageInternalID: [String: [OpenGraphiteStaticFlowLink]] = [:]
    @Published private(set) var staticFlowLinksByPageURL: [URL: [OpenGraphiteStaticFlowLink]] = [:]
    @Published private var canvasReferenceResolutionCache: [
        CanvasReferenceResolutionCacheKey: OpenGraphiteCanvasReferenceResolutionState
    ] = [:]
    private var nodeSourceIndexCache: [NodeSourceIndexCacheKey: CurrentSourceNodeIndexes] = [:]
    private var nodeSourceIndexTask: Task<Void, Never>?
    private var nodeSourceIndexTaskKey: NodeSourceIndexCacheKey?
    private var latestNodeSourceIndexKey: NodeSourceIndexCacheKey?
    private var latestLayerNodePayload: [[String: Any]] = []
    private var nodeDetailPayloadsByID: [String: [String: Any]] = [:]
    private(set) var nodeSourceIndexBuildCount = 0

    private let loader: ProjectLoader
    private let projectCreator: ProjectCreator
    private let sampleProjectLocator: SampleProjectLocator
    private let currentProjectStore: OpenGraphiteCurrentProjectStore?
    private var mutationSequence = 0
    private var attributeMutationSequence = 0
    private var textMutationSequence = 0
    private var documentReplacementSequence = 0
    private var inspectorSectionOpenRequestSequence = 0
    private var syncHistories: [URL: DocumentSyncHistory] = [:]
    private var editorUndoStack: [EditorHistoryRecord] = []
    private var editorRedoStack: [EditorHistoryRecord] = []
    @Published private var stagedCanvasAnnotationTextDrafts: [String: StagedCanvasAnnotationTextDraft] = [:]
    private var lastKnownPageHTMLByURL: [URL: String] = [:]
    private var cssVariableBaselinesByInternalID: [String: [String: String]] = [:]
    private var activeMediaQueriesByHTMLURL: [URL: [String]] = [:]
    private var selectedNodeSelectionAnchorID: String?
    private var isApplyingNodeRangeSelection = false
    private var isApplyingCanvasAnnotationMultiSelection = false
    private var pageChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private var dependencyChangeMonitorsByURL: [URL: OpenGraphiteFileChangeMonitor] = [:]
    private let projectChangeMonitor = OpenGraphiteFileChangeMonitor()
    private var monitoredProjectURL: URL?
    private static let relatedStyleProperties: Set<String> = [
        "object-fit",
        "stroke-width",
        "mask-image",
        "-webkit-mask-image"
    ]
    /// Source-aware 編集で DOM runtime 値より authored source を優先する標準 CSS property 群。
    private static let sourceAuthoritativeStyleProperties: Set<String> = ["scale"]
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 論理名（日本語）: エディターストア初期化関数
    /// 処理概要: project loader と sample project locator を保持し、通常利用時は既定実装を使います。
    ///
    /// - Parameters:
    ///   - loader: `.ogp` 読み込みに使う loader。
    ///   - projectCreator: 新規 `.ogp` 作成に使う creator。
    ///   - sampleProjectLocator: Open Sample Project の解決に使う locator。
    ///   - currentProjectStore: 現在開いている `.ogp` の共有状態保存先。
    init(
        loader: ProjectLoader = ProjectLoader(),
        projectCreator: ProjectCreator = ProjectCreator(),
        sampleProjectLocator: SampleProjectLocator = SampleProjectLocator(),
        currentProjectStore: OpenGraphiteCurrentProjectStore? = nil
    ) {
        self.loader = loader
        self.projectCreator = projectCreator
        self.sampleProjectLocator = sampleProjectLocator
        self.currentProjectStore = currentProjectStore ?? (Self.isRunningTests ? nil : OpenGraphiteCurrentProjectStore())
    }

    deinit {
        nodeSourceIndexTask?.cancel()
        for monitor in pageChangeMonitorsByURL.values {
            monitor.cancel()
        }
        for monitor in dependencyChangeMonitorsByURL.values {
            monitor.cancel()
        }
        projectChangeMonitor.cancel()
    }

    var selectedChapter: OpenGraphiteChapter? {
        guard let loadedProject else { return nil }
        return loadedProject.project.chapters.first { $0.internalID == selectedChapterInternalID }
            ?? Self.preferredVisibleChapter(in: loadedProject.project)
    }

    var selectedChapterPages: [OpenGraphitePage] {
        selectedChapter?.pages ?? []
    }

    var selectedComponentCollection: OpenGraphiteComponentCollection? {
        guard let loadedProject else { return nil }
        return loadedProject.project.collections.first { $0.internalID == selectedCollectionInternalID }
            ?? loadedProject.project.collections.first
    }

    var componentPages: [OpenGraphitePage] {
        selectedComponentCollection?.components ?? []
    }

    var selectedCanvasPages: [OpenGraphitePage] {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapterPages.filter { !$0.isCanvasHidden }
        case .components:
            return componentPages
        }
    }

    var selectedCanvasAnnotations: [OpenGraphiteCanvasAnnotation] {
        let annotations: [OpenGraphiteCanvasAnnotation]
        switch selectedCanvasSegment {
        case .pages:
            annotations = selectedChapter?.annotations ?? []
        case .components:
            annotations = selectedComponentCollection?.annotations ?? []
        }
        guard let projectURL = loadedProject?.fileURL else { return annotations }
        return annotations.map { annotation in
            let key = canvasAnnotationBaselineKey(
                projectURL: projectURL,
                annotationID: annotation.internalID
            )
            guard let draft = stagedCanvasAnnotationTextDrafts[key],
                  annotation.kind == .stickyNote
            else {
                return annotation
            }
            var overlaidAnnotation = annotation
            overlaidAnnotation.text = draft.text
            return overlaidAnnotation
        }
    }

    /// 論理名（日本語）: 選択キャンバスオブジェクト参照一覧
    /// 概要: 現在表示中のChapterまたはCollection直下に保存された編集可能なノード参照を返します。
    var selectedCanvasReferences: [OpenGraphiteCanvasReference] {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapter?.references ?? []
        case .components:
            return selectedComponentCollection?.references ?? []
        }
    }

    /// 論理名（日本語）: 選択キャンバスガイド一覧
    /// 概要: 現在の Pages Chapter または Components Collection に保存された `.ogp` ガイドを返します。
    var selectedCanvasGuides: [OpenGraphiteCanvasGuide] {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapter?.guides ?? []
        case .components:
            return selectedComponentCollection?.guides ?? []
        }
    }

    var selectedCanvasAnnotation: OpenGraphiteCanvasAnnotation? {
        guard let selectedCanvasAnnotationID else { return nil }
        return selectedCanvasAnnotations.first { $0.internalID == selectedCanvasAnnotationID }
    }

    var selectedCanvasTitle: String {
        switch selectedCanvasSegment {
        case .pages:
            return selectedChapter?.displayName ?? "Pages"
        case .components:
            return selectedComponentCollection?.displayName ?? "Components"
        }
    }

    var inspectorExpansionScopeIdentifier: String {
        if let selectedProjectResource {
            return "project-resource:\(selectedProjectResource)"
        }
        if let selectedNodeID {
            return [
                "node",
                selectedDocumentSegment.rawValue,
                selectedPage?.internalID ?? "",
                selectedNodeID
            ].joined(separator: ":")
        }
        if let selectedPage {
            return [
                "page",
                selectedDocumentSegment.rawValue,
                selectedPage.internalID
            ].joined(separator: ":")
        }
        switch selectedCanvasSegment {
        case .pages:
            return "chapter:\(selectedChapter?.internalID ?? "")"
        case .components:
            return "collection:\(selectedComponentCollection?.internalID ?? "")"
        }
    }

    var selectedPage: OpenGraphitePage? {
        if let selectedCanvasReferenceTarget {
            return selectedCanvasReferenceTarget.page
        }
        switch selectedCanvasSegment {
        case .pages:
            guard selectedPageInternalID != nil else { return nil }
            return selectedChapterPages.first { $0.internalID == selectedPageInternalID }
        case .components:
            guard selectedComponentPageInternalID != nil else { return nil }
            return componentPages.first { $0.internalID == selectedComponentPageInternalID }
        }
    }

    var selectedPageURL: URL? {
        if let selectedCanvasReferenceTarget {
            return selectedCanvasReferenceTarget.pageURL
        }
        guard let loadedProject, let selectedPage else { return nil }
        return loadedProject.htmlURL(for: selectedPage)
    }

    /// 論理名（日本語）: 選択HTML文書セグメント
    /// 概要: 通常カード選択では現在のCanvasセグメント、参照配置選択では参照元HTMLカードのセグメントを返します。
    var selectedDocumentSegment: OpenGraphiteCanvasSegment {
        selectedCanvasReferenceTarget?.segment ?? selectedCanvasSegment
    }

    var selectedHTMLDocumentContext: OpenGraphiteHTMLDocumentContext {
        guard let selectedPageURL,
              let html = readHTMLFromDisk(at: selectedPageURL)
        else {
            return .empty
        }
        return OpenGraphiteHTMLDocument(html: html).htmlDocumentContext()
    }

    var selectedI18nRuntimeInspection: OpenGraphiteI18nRuntimeInspection? {
        guard let loadedProject,
              let pageID = selectedPageReferenceID()
        else {
            return nil
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return try? core.inspectI18n(projectURL: loadedProject.fileURL, pageID: pageID)
    }

    /// 論理名（日本語）: 選択HTML locale typography
    /// 概要: Shared coreからpage / component rootの標準`font-family`と`:lang()`宣言を取得します。
    var selectedLocaleTypography: OpenGraphiteLocaleTypographyListResult? {
        guard let loadedProject,
              let pageID = selectedPageReferenceID()
        else {
            return nil
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return try? core.localeTypography(projectURL: loadedProject.fileURL, pageID: pageID)
    }

    var projectI18nRuntimeInspection: OpenGraphiteI18nRuntimeInspection? {
        guard let loadedProject,
              let pageID = projectI18nReferencePageID()
        else {
            return nil
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return try? core.inspectI18n(projectURL: loadedProject.fileURL, pageID: pageID)
    }

    var projectDesignTokens: [OpenGraphiteDesignToken] {
        guard let loadedProject else { return [] }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        return (try? core.designTokens(at: loadedProject.cssURL).tokens) ?? []
    }

    /// 論理名（日本語）: HTML同期対象生成関数
    /// 処理概要: 指定 HTML カードの object identity と現在解決済み URL を保存対象としてまとめます。
    ///
    /// - Parameters:
    ///   - page: 対象 HTML カード。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: 保存先固定 URL を含む同期対象。project 内で解決できない場合は `nil`。
    func htmlSyncTarget(for page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> HTMLSyncTarget? {
        guard let loadedProject else { return nil }

        switch segment {
        case .pages:
            guard let chapter = loadedProject.project.chapters.first(where: { chapter in
                chapter.pages.contains { $0.internalID == page.internalID }
            }) else {
                return nil
            }
            return HTMLSyncTarget(
                identity: HTMLDocumentIdentity(
                    projectURL: loadedProject.fileURL,
                    segment: .pages,
                    containerInternalID: chapter.internalID,
                    pageInternalID: page.internalID
                ),
                path: page.path,
                htmlURL: loadedProject.htmlURL(for: page)
            )
        case .components:
            guard let collection = loadedProject.project.collections.first(where: { collection in
                collection.components.contains { $0.internalID == page.internalID }
            }) else {
                return nil
            }
            return HTMLSyncTarget(
                identity: HTMLDocumentIdentity(
                    projectURL: loadedProject.fileURL,
                    segment: .components,
                    containerInternalID: collection.internalID,
                    pageInternalID: page.internalID
                ),
                path: page.path,
                htmlURL: loadedProject.htmlURL(for: page)
            )
        }
    }

    var projectRootURL: URL? {
        loadedProject?.rootURL
    }

    var selectedNode: OpenGraphiteNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    var selectedLayerNodes: [OpenGraphiteNode] {
        guard !selectedNodeIDs.isEmpty else {
            return selectedNode.map { [$0] } ?? []
        }

        return nodes.filter { selectedNodeIDs.contains($0.id) }
    }

    var selectedLayerNodeIDsInNodeOrder: [String] {
        selectedLayerNodes.map(\.id)
    }

    var selectedComponentSource: OpenGraphiteComponentSource? {
        guard let selectedNode else { return nil }
        return componentSource(for: selectedNode)
    }

    var selectedAppliedParentAnimationContext: OpenGraphiteAppliedAnimationContext? {
        guard let selectedNode else { return nil }
        return appliedParentAnimationContext(for: selectedNode)
    }

    /// 論理名（日本語）: Chapter参照ID生成関数
    /// 処理概要: `.ogp` 内で Chapter を一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameter chapter: 参照する Chapter。
    /// - Returns: `ogref:chapter:<chapterInternalID>`。現在の project に含まれない場合は `nil`。
    func chapterReferenceID(for chapter: OpenGraphiteChapter) -> String? {
        guard loadedProject?.project.chapters.contains(where: { $0.internalID == chapter.internalID }) == true,
              !chapter.internalID.isEmpty
        else {
            return nil
        }
        return OpenGraphiteReferenceID.chapter(chapter.internalID).stringValue
    }

    /// 論理名（日本語）: Component Collection参照ID生成関数
    /// 処理概要: `.ogp` 内で Component Collection を一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameter collection: 参照する Component Collection。
    /// - Returns: `ogref:collection:<collectionInternalID>`。現在の project に含まれない場合は `nil`。
    func collectionReferenceID(for collection: OpenGraphiteComponentCollection) -> String? {
        guard loadedProject?.project.collections.contains(where: { $0.internalID == collection.internalID }) == true,
              !collection.internalID.isEmpty
        else {
            return nil
        }
        return OpenGraphiteReferenceID.collection(collection.internalID).stringValue
    }

    /// 論理名（日本語）: ページ参照ID生成関数
    /// 処理概要: Pages / Components の HTML カードを `.ogp` 内で一意に指す agent 向け参照 ID を返します。
    ///
    /// - Parameters:
    ///   - page: 参照する page entry。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: Pages は `ogref:page:<chapterInternalID>:<pageInternalID>`、Components は `ogref:component:<collectionInternalID>:<componentInternalID>`。
    func pageReferenceID(for page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> String? {
        let pageInternalID = page.internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pageInternalID.isEmpty, let loadedProject else { return nil }

        switch segment {
        case .pages:
            guard let chapter = loadedProject.project.chapters.first(where: { chapter in
                chapter.pages.contains { $0.internalID == pageInternalID }
            }), !chapter.internalID.isEmpty else {
                return nil
            }
            return OpenGraphiteReferenceID
                .page(chapterID: chapter.internalID, pageID: pageInternalID)
                .stringValue
        case .components:
            guard let collection = loadedProject.project.collections.first(where: { collection in
                collection.components.contains { $0.internalID == pageInternalID }
            }), !collection.internalID.isEmpty else {
                return nil
            }
            return OpenGraphiteReferenceID
                .component(collectionID: collection.internalID, componentID: pageInternalID)
                .stringValue
        }
    }

    /// 論理名（日本語）: 選択ページ参照ID生成関数
    /// 処理概要: 現在選択中の HTML カードを `.ogp` 内で一意に指す agent 向け参照 ID を返します。
    ///
    /// - Returns: 選択ページの参照 ID。未選択の場合は `nil`。
    func selectedPageReferenceID() -> String? {
        guard let selectedPage else { return nil }
        return pageReferenceID(for: selectedPage, segment: selectedDocumentSegment)
    }

    /// 論理名（日本語）: Project i18n代表ページ参照ID生成関数
    /// 処理概要: Project 依存性として共有 i18n runtime を検出・編集する入口になる代表 page 参照 ID を返します。
    ///
    /// - Returns: 先頭 Pages HTML の参照 ID。Pages がない場合は先頭 Component HTML を返します。
    func projectI18nReferencePageID() -> String? {
        guard let loadedProject else { return nil }
        if let page = loadedProject.project.chapters.flatMap(\.pages).first,
           let referenceID = pageReferenceID(for: page, segment: .pages) {
            return referenceID
        }
        if let component = loadedProject.project.components.first {
            return pageReferenceID(for: component, segment: .components)
        }
        return nil
    }

    /// 論理名（日本語）: 参照ID pasteboardコピー関数
    /// 処理概要: agent 向け参照 ID をテキストとして pasteboard に保存し、ステータスを更新します。
    ///
    /// - Parameters:
    ///   - referenceID: コピーする参照 ID。
    ///   - label: ステータスメッセージに使う対象名。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyReferenceIDToPasteboard(_ referenceID: String?, label: String) -> Bool {
        guard let referenceID = referenceID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !referenceID.isEmpty else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(referenceID, forType: .string)
        statusMessage = "\(label)の参照IDをコピーしました。"
        return true
    }

    /// 論理名（日本語）: Chapter参照IDコピー関数
    /// 処理概要: 指定 Chapter の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter chapter: コピー対象 Chapter。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyChapterReferenceIDToPasteboard(_ chapter: OpenGraphiteChapter) -> Bool {
        copyReferenceIDToPasteboard(chapterReferenceID(for: chapter), label: "Chapter \(chapter.displayName)")
    }

    /// 論理名（日本語）: ページ参照IDコピー関数
    /// 処理概要: 指定 HTML カードの agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameters:
    ///   - page: コピー対象 page entry。
    ///   - segment: page が属する Pages / Components セグメント。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyPageReferenceIDToPasteboard(_ page: OpenGraphitePage, segment: OpenGraphiteCanvasSegment) -> Bool {
        copyReferenceIDToPasteboard(pageReferenceID(for: page, segment: segment), label: "Page \(page.displayName)")
    }

    /// 論理名（日本語）: ノード参照IDコピー関数
    /// 処理概要: 指定 DOM node の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter node: コピー対象 DOM node。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyNodeReferenceIDToPasteboard(_ node: OpenGraphiteNode) -> Bool {
        copyReferenceIDToPasteboard(
            nodeReferenceID(forNodeID: node.editTargetNodeID, nodeInternalID: node.internalID),
            label: "Node \(node.displayID)"
        )
    }

    /// 論理名（日本語）: 選択階層参照IDコピー関数
    /// 処理概要: 選択 node、選択 HTML カード、選択 Chapter の順に agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copySelectedReferenceIDToPasteboard() -> Bool {
        if selectedCanvasAnnotationIDs.count > 1,
           copySelectedCanvasAnnotationReferenceIDsToPasteboard() {
            return true
        }
        if let selectedCanvasAnnotation,
           copyCanvasAnnotationReferenceIDToPasteboard(selectedCanvasAnnotation) {
            return true
        }
        if let selectedNode, copyNodeReferenceIDToPasteboard(selectedNode) {
            return true
        }
        if let selectedPage, copyPageReferenceIDToPasteboard(selectedPage, segment: selectedDocumentSegment) {
            return true
        }
        if selectedCanvasSegment == .components,
           let selectedComponentCollection,
           copyReferenceIDToPasteboard(collectionReferenceID(for: selectedComponentCollection), label: "Collection \(selectedComponentCollection.displayName)") {
            return true
        }
        if selectedCanvasSegment == .pages,
           let selectedChapter,
           copyChapterReferenceIDToPasteboard(selectedChapter) {
            return true
        }
        return false
    }

    /// 論理名（日本語）: キャンバス注釈参照ID生成関数
    /// 処理概要: 現在表示中の Chapter / Collection と注釈内部 ID から agent 向け参照 ID を返します。
    ///
    /// - Parameter annotation: 参照するキャンバス注釈。
    /// - Returns: `ogref:annotation:<segment>:<containerInternalID>:<annotationInternalID>`。現在の Canvas に含まれない場合は `nil`。
    func canvasAnnotationReferenceID(for annotation: OpenGraphiteCanvasAnnotation) -> String? {
        guard selectedCanvasAnnotations.contains(where: { $0.internalID == annotation.internalID }),
              !annotation.internalID.isEmpty
        else {
            return nil
        }

        let containerInternalID: String?
        switch selectedCanvasSegment {
        case .pages:
            containerInternalID = selectedChapter?.internalID
        case .components:
            containerInternalID = selectedComponentCollection?.internalID
        }
        guard let containerInternalID, !containerInternalID.isEmpty else { return nil }
        return OpenGraphiteReferenceID.annotation(
            segment: selectedCanvasSegment,
            containerID: containerInternalID,
            annotationID: annotation.internalID
        ).stringValue
    }

    /// 論理名（日本語）: キャンバス注釈参照IDコピー関数
    /// 処理概要: 指定注釈の agent 向け参照 ID を pasteboard へ保存します。
    ///
    /// - Parameter annotation: コピー対象のキャンバス注釈。
    /// - Returns: コピーできた場合は `true`。
    @discardableResult
    func copyCanvasAnnotationReferenceIDToPasteboard(_ annotation: OpenGraphiteCanvasAnnotation) -> Bool {
        copyReferenceIDToPasteboard(
            canvasAnnotationReferenceID(for: annotation),
            label: "Canvas annotation"
        )
    }

    /// 論理名（日本語）: 複数キャンバス注釈参照IDコピー関数
    /// 処理概要: なげわなどで同時選択した注釈の typed reference を Canvas 配列順の改行区切りで pasteboard へ保存します。
    ///
    /// - Returns: 1件以上の参照 ID をコピーできた場合は `true`。
    @discardableResult
    func copySelectedCanvasAnnotationReferenceIDsToPasteboard() -> Bool {
        let referenceIDs: [String] = selectedCanvasAnnotations.compactMap { annotation -> String? in
            guard selectedCanvasAnnotationIDs.contains(annotation.internalID) else { return nil }
            return canvasAnnotationReferenceID(for: annotation)
        }
        guard !referenceIDs.isEmpty else { return false }
        return copyReferenceIDToPasteboard(
            referenceIDs.joined(separator: "\n"),
            label: "Canvas annotations (\(referenceIDs.count))"
        )
    }

    /// 論理名（日本語）: Project資源選択関数
    /// 処理概要: Pages / Components の HTML 選択を維持したまま、Inspector 表示対象を Project 依存性へ切り替えます。
    ///
    /// - Parameter resource: 選択する Project 資源。`nil` の場合は Project 資源選択を解除します。
    func selectProjectResource(_ resource: OpenGraphiteProjectResourceSelection?) {
        selectedProjectResource = resource
        clearCanvasReferenceSelection()
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if let resource {
            statusMessage = "\(resource.title) を表示しています。"
        } else {
            statusMessage = "Project 資源選択を解除しました。"
        }
    }

    /// 論理名（日本語）: Chapter追加関数
    /// 処理概要: 現在の `.ogp` に空の Chapter を追加保存し、追加した Chapter を Pages セグメントで選択します。
    func addChapter() {
        guard var loadedProject else { return }

        let chapterNumber = loadedProject.project.chapters.count + 1
        let chapter = OpenGraphiteChapter(
            id: nextChapterID(in: loadedProject.project),
            internalID: nextChapterInternalID(in: loadedProject.project),
            title: "Chapter \(chapterNumber)",
            pages: []
        )
        loadedProject.project.chapters.append(chapter)

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            let addedChapter = reloadedProject.project.chapters.first { $0.id == chapter.id }
                ?? reloadedProject.project.chapters.last
            self.loadedProject = reloadedProject
            selectedProjectResource = nil
            selectChapter(addedChapter)
            lastError = nil
            statusMessage = "\(addedChapter?.displayName ?? chapter.displayName) を追加しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Page追加関数
    /// 処理概要: 現在選択中の Chapter に新しい HTML page file を作成し、`.ogp` へ page entry を追加保存します。
    func addPage() {
        guard var loadedProject else { return }

        let targetChapterIndex = writableChapterIndex(in: &loadedProject.project)
        let previousProject = loadedProject.project
        let pageID = nextPageID(in: loadedProject.project)
        let pagePath = nextPagePath(in: loadedProject, idPrefix: "page")
        let pageFileName = URL(fileURLWithPath: pagePath).lastPathComponent
        let pageCanvas = nextPageCanvas(
            in: loadedProject.project.chapters[targetChapterIndex],
            fallbackProject: loadedProject.project
        )
        let page = OpenGraphitePage(
            id: pageID,
            path: pagePath,
            canvas: pageCanvas
        )
        let htmlURL = loadedProject
            .rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .appendingPathComponent(pagePath)
            .standardizedFileURL
        let companionCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
        let stylesheetPath = Self.relativePath(
            from: htmlURL.deletingLastPathComponent(),
            to: loadedProject.cssURL
        )
        let rootNodeInternalID = UUID().uuidString.lowercased()
        let bodyHTML = """
            <main id="\(pageID)-root" data-og-internal-id="\(rootNodeInternalID)" style="display: flex; flex-direction: column;"></main>
        """
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)

        do {
            let writeResult = try core.createPage(
                at: htmlURL,
                title: pageFileName,
                lang: "ja",
                stylesheetPath: stylesheetPath,
                bodyHTML: bodyHTML,
                overwrite: false
            )
            guard writeResult.created else {
                lastError = writeResult.diagnostics.first(where: { $0.severity == .error })?.message
                    ?? "ページHTMLの作成に失敗しました。"
                return
            }

            loadedProject.project.chapters[targetChapterIndex].pages.append(page)
            do {
                try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
                let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
                self.loadedProject = reloadedProject
                let addedPage = reloadedProject.project.chapters
                    .flatMap(\.pages)
                    .first { $0.id == pageID }
                if let addedPage {
                    selectPage(internalID: addedPage.internalID)
                }
                lastError = nil
                statusMessage = "\(addedPage?.displayName ?? page.displayName) を追加しました。"
                restartExternalProjectMonitoring(force: true)
                restartExternalPageMonitoring(force: true)
            } catch {
                try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
                try? FileManager.default.removeItem(at: htmlURL)
                try? FileManager.default.removeItem(at: companionCSSURL)
                lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            }
        } catch {
            lastError = "ページHTMLの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: 既存Page追加関数
    /// 処理概要: `htmlRoot` 配下に存在する HTML file を、現在選択中の Chapter の page entry として `.ogp` へ追加保存します。
    ///
    /// - Parameter htmlURL: 追加する既存 HTML file の URL。
    func addExistingPage(at htmlURL: URL) {
        guard var loadedProject else { return }

        let pathResult = Self.existingHTMLPath(for: htmlURL, in: loadedProject)
        guard let pagePath = pathResult.path else {
            lastError = pathResult.error ?? "追加する HTML file を確認できませんでした。"
            return
        }
        guard !loadedProject.project.allPages.contains(where: { $0.path == pagePath }) else {
            lastError = "同じ HTML path が既に登録されています: \(pagePath)"
            return
        }

        let targetChapterIndex = writableChapterIndex(in: &loadedProject.project)
        let previousProject = loadedProject.project
        let pageID = Self.existingPageID(forHTMLPath: pagePath, in: loadedProject.project)
        let pageCanvas = nextPageCanvas(
            in: loadedProject.project.chapters[targetChapterIndex],
            fallbackProject: loadedProject.project
        )
        let page = OpenGraphitePage(
            id: pageID,
            path: pagePath,
            canvas: pageCanvas
        )
        loadedProject.project.chapters[targetChapterIndex].pages.append(page)
        let targetChapter = loadedProject.project.chapters[targetChapterIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            let addedChapter = Self.reloadedChapter(
                in: reloadedProject.project,
                matching: targetChapter,
                fallbackIndex: targetChapterIndex
            )
            let addedPage = addedChapter?.pages.first { candidate in
                candidate.id == pageID && candidate.path == pagePath
            }
            guard let addedChapter, let addedPage else {
                throw NSError(
                    domain: "OpenGraphite.EditorStore",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "追加した page を再読み込みできませんでした。"]
                )
            }

            self.loadedProject = reloadedProject
            selectedProjectResource = nil
            selectedCanvasSegment = .pages
            selectedChapterID = addedChapter.id
            selectedChapterInternalID = addedChapter.internalID
            selectPage(internalID: addedPage.internalID)
            lastError = nil
            statusMessage = "\(addedPage.displayName) を追加しました。"
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
        } catch {
            try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Chapter表示名更新関数
    /// 処理概要: 指定 Chapter の UI 表示タイトルを `.ogp` に保存し、選択状態を維持したまま反映します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 Chapter の内部 ID。
    ///   - value: Sidebar で入力された表示名。空の場合は title を解除して ID 表示へ戻します。
    func updateChapterTitle(internalID: String, value: String) {
        guard var loadedProject,
              let chapterIndex = loadedProject.project.chapters.firstIndex(where: { $0.internalID == internalID })
        else {
            return
        }

        let normalizedTitle = Self.normalizedManifestTitle(value)
        guard loadedProject.project.chapters[chapterIndex].title != normalizedTitle else { return }
        loadedProject.project.chapters[chapterIndex].title = normalizedTitle
        let updatedChapter = loadedProject.project.chapters[chapterIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = "\(updatedChapter.displayName) に変更しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Chapter一覧非表示関数
    /// 処理概要: 指定 Chapter とそのキャンバス内容を `.ogp` に残したまま、Sidebar の Chapter 一覧から隠します。
    ///
    /// - Parameter internalID: 非表示にする Chapter の内部 ID。
    func hideChapterFromSidebar(internalID: String) {
        guard var loadedProject,
              let chapterIndex = loadedProject.project.chapters.firstIndex(where: {
                  $0.internalID == internalID && !$0.isSidebarHidden
              })
        else {
            return
        }

        let hiddenChapter = loadedProject.project.chapters[chapterIndex]
        loadedProject.project.chapters[chapterIndex].isSidebarHidden = true

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            if selectedChapterInternalID == internalID {
                selectChapter(Self.preferredVisibleChapter(in: loadedProject.project))
            }
            lastError = nil
            statusMessage = "\(hiddenChapter.displayName) を一覧から非表示にしました。キャンバス内容は保持されています。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Pageキャンバス表示更新関数
    /// 処理概要: 指定 Page entry を Sidebar に残したまま、Chapter キャンバスでの表示状態を `.ogp` に保存します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 Page の内部 ID。
    ///   - hidden: キャンバスから隠す場合は `true`、再表示する場合は `false`。
    func setPageCanvasHidden(internalID: String, hidden: Bool) {
        guard var loadedProject,
              let chapterIndex = loadedProject.project.chapters.firstIndex(where: { chapter in
                  chapter.pages.contains { $0.internalID == internalID }
              }),
              let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: {
                  $0.internalID == internalID
              }),
              loadedProject.project.chapters[chapterIndex].pages[pageIndex].isCanvasHidden != hidden
        else {
            return
        }

        loadedProject.project.chapters[chapterIndex].pages[pageIndex].isCanvasHidden = hidden
        let updatedPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            if hidden, selectedPageInternalID == internalID {
                selectedNodeID = nil
                selectedCanvasAnnotationID = nil
                nodes = []
                focusedPreviewTarget = nil
            }
            lastError = nil
            statusMessage = hidden
                ? "\(updatedPage.displayName) をキャンバスから非表示にしました。"
                : "\(updatedPage.displayName) をキャンバスに表示しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Page完全削除可否判定関数
    /// 処理概要: 指定 Page の HTML path が `.ogp` 内の他の Page / Component 配置から使われていない場合だけ削除可能と判定します。
    ///
    /// - Parameter internalID: 判定対象 Page の内部 ID。
    /// - Returns: Page entry と HTML / companion CSS を安全に削除できる場合は `true`。
    func canPermanentlyDeletePage(internalID: String) -> Bool {
        guard let loadedProject,
              let page = loadedProject.project.chapters
                .flatMap(\.pages)
                .first(where: { $0.internalID == internalID })
        else {
            return false
        }

        let pageURL = loadedProject.htmlURL(for: page).standardizedFileURL
        return loadedProject.project.allPages.filter {
            loadedProject.htmlURL(for: $0).standardizedFileURL == pageURL
        }.count == 1
    }

    /// 論理名（日本語）: Page完全削除関数
    /// 処理概要: 他に配置されていない Page entry、参照配置、HTML、同名 companion CSS を一つの操作として削除します。
    ///
    /// - Parameter internalID: 完全削除する Page の内部 ID。
    func permanentlyDeletePage(internalID: String) {
        guard var loadedProject,
              canPermanentlyDeletePage(internalID: internalID),
              let chapterIndex = loadedProject.project.chapters.firstIndex(where: { chapter in
                  chapter.pages.contains { $0.internalID == internalID }
              }),
              let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: {
                  $0.internalID == internalID
              })
        else {
            lastError = "この Page は `.ogp` 内の別の配置でも使われているため、完全に削除できません。"
            return
        }

        let previousProject = loadedProject.project
        let page = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
        let htmlURL = loadedProject.htmlURL(for: page).standardizedFileURL
        let companionCSSURL = OpenGraphiteCompanionCSSDocument
            .companionURL(forHTMLURL: htmlURL)
            .standardizedFileURL
        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .standardizedFileURL
        let fileManager = FileManager.default
        var htmlIsDirectory: ObjCBool = false
        var companionCSSIsDirectory: ObjCBool = false

        guard Self.isFileURL(htmlURL, containedIn: htmlRootURL),
              Self.isFileURL(companionCSSURL, containedIn: htmlRootURL),
              htmlURL.pathExtension.lowercased() == "html",
              companionCSSURL.pathExtension.lowercased() == "css",
              !(fileManager.fileExists(atPath: htmlURL.path, isDirectory: &htmlIsDirectory)
                  && htmlIsDirectory.boolValue),
              !(fileManager.fileExists(atPath: companionCSSURL.path, isDirectory: &companionCSSIsDirectory)
                  && companionCSSIsDirectory.boolValue)
        else {
            lastError = "HTML root 外のファイルは完全に削除できません。"
            return
        }

        let htmlBackup = try? Data(contentsOf: htmlURL)
        let companionCSSBackup = try? Data(contentsOf: companionCSSURL)
        loadedProject.project.chapters[chapterIndex].pages.remove(at: pageIndex)
        Self.removeCanvasReferences(toPageInternalID: internalID, from: &loadedProject.project)

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            if fileManager.fileExists(atPath: htmlURL.path) {
                try fileManager.removeItem(at: htmlURL)
            }
            if fileManager.fileExists(atPath: companionCSSURL.path) {
                try fileManager.removeItem(at: companionCSSURL)
            }

            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            self.loadedProject = reloadedProject
            discardPageRuntimeState(pageInternalID: internalID, pageURL: htmlURL)
            if selectedPageInternalID == internalID {
                selectedPageID = nil
                selectedPageInternalID = nil
                selectedNodeID = nil
                selectedCanvasAnnotationID = nil
                nodes = []
                focusedPreviewTarget = nil
            }
            clearCanvasReferenceSelection()
            seedKnownHTMLForProject(reloadedProject)
            lastError = nil
            statusMessage = "\(page.displayName) と同名 companion CSS を完全に削除しました。"
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
        } catch {
            if let htmlBackup {
                try? htmlBackup.write(to: htmlURL, options: .atomic)
            }
            if let companionCSSBackup {
                try? companionCSSBackup.write(to: companionCSSURL, options: .atomic)
            }
            try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
            lastError = "Page の完全削除に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Collection表示名更新関数
    /// 処理概要: 指定 Component Collection の UI 表示タイトルを `.ogp` に保存し、選択状態を維持したまま反映します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 Collection の内部 ID。
    ///   - value: Sidebar で入力された表示名。空の場合は title を解除して ID 表示へ戻します。
    func updateCollectionTitle(internalID: String, value: String) {
        guard var loadedProject,
              let collectionIndex = loadedProject.project.collections.firstIndex(where: { $0.internalID == internalID })
        else {
            return
        }

        let normalizedTitle = Self.normalizedManifestTitle(value)
        guard loadedProject.project.collections[collectionIndex].title != normalizedTitle else { return }
        loadedProject.project.collections[collectionIndex].title = normalizedTitle
        let updatedCollection = loadedProject.project.collections[collectionIndex]

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = "\(updatedCollection.displayName) に変更しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: HTMLカードファイル名更新関数
    /// 処理概要: 指定 Page または Component canvas の HTML ファイル名を変更し、`.ogp` の path と同名 companion CSS を同期します。
    ///
    /// - Parameters:
    ///   - internalID: 更新対象 HTML カードの内部 ID。
    ///   - segment: Pages / Components のどちらを更新するか。
    ///   - value: Sidebar で入力された新しい HTML ファイル名。拡張子省略時は `.html` を補います。
    func updatePageFilename(internalID: String, segment: OpenGraphiteCanvasSegment, value: String) {
        guard var loadedProject else { return }

        guard cssMutation == nil,
              cssVariablesMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            lastError = "未適用の編集があるため、ファイル名変更を保留しました。"
            return
        }

        let originalPage: OpenGraphitePage
        let updatePagePath: (String) -> Void
        switch segment {
        case .pages:
            guard let chapterIndex = loadedProject.project.chapters.firstIndex(where: { chapter in
                chapter.pages.contains { $0.internalID == internalID }
            }),
                  let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == internalID })
            else {
                return
            }
            originalPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
            updatePagePath = { nextPath in
                loadedProject.project.chapters[chapterIndex].pages[pageIndex].path = nextPath
                loadedProject.project.chapters[chapterIndex].pages[pageIndex].title = nil
            }
        case .components:
            guard let collectionIndex = loadedProject.project.collections.firstIndex(where: { collection in
                collection.components.contains { $0.internalID == internalID }
            }),
                  let pageIndex = loadedProject.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == internalID })
            else {
                return
            }
            originalPage = loadedProject.project.collections[collectionIndex].components[pageIndex]
            updatePagePath = { nextPath in
                loadedProject.project.collections[collectionIndex].components[pageIndex].path = nextPath
                loadedProject.project.collections[collectionIndex].components[pageIndex].title = nil
            }
        }

        let renamePath = Self.renamedHTMLPath(currentPath: originalPage.path, value: value)
        guard let nextPath = renamePath.path else {
            lastError = renamePath.error ?? "ファイル名が正しくありません。"
            return
        }
        guard nextPath != originalPage.path else { return }
        guard !loadedProject.project.allPages.contains(where: { page in
            page.internalID != originalPage.internalID && page.path == nextPath
        }) else {
            lastError = "同じ HTML path が既に登録されています: \(nextPath)"
            return
        }

        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .standardizedFileURL
        let currentHTMLURL = htmlRootURL
            .appendingPathComponent(originalPage.path)
            .standardizedFileURL
        let nextHTMLURL = htmlRootURL
            .appendingPathComponent(nextPath)
            .standardizedFileURL
        let currentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: currentHTMLURL).standardizedFileURL
        let nextCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: nextHTMLURL).standardizedFileURL
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: currentHTMLURL.path) else {
            lastError = "変更元の HTML が見つかりません: \(currentHTMLURL.path)"
            return
        }
        guard !fileManager.fileExists(atPath: nextHTMLURL.path) else {
            lastError = "変更先の HTML が既に存在します: \(nextHTMLURL.path)"
            return
        }
        if currentCSSURL != nextCSSURL,
           fileManager.fileExists(atPath: nextCSSURL.path) {
            lastError = "変更先の companion CSS が既に存在します: \(nextCSSURL.path)"
            return
        }

        let previousProject = loadedProject.project
        let movedCSS = currentCSSURL != nextCSSURL && fileManager.fileExists(atPath: currentCSSURL.path)
        var dependencyBackups: [HTMLDependencyRewriteBackup] = []
        var didMoveHTML = false
        var didMoveCSS = false

        do {
            if segment == .components {
                dependencyBackups = try rewriteComponentDependencyReferences(
                    in: loadedProject,
                    from: currentHTMLURL,
                    to: nextHTMLURL,
                    excludingPageInternalID: originalPage.internalID
                )
            }
            try fileManager.createDirectory(at: nextHTMLURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: currentHTMLURL, to: nextHTMLURL)
            didMoveHTML = true
            if movedCSS {
                try fileManager.moveItem(at: currentCSSURL, to: nextCSSURL)
                didMoveCSS = true
            }

            updatePagePath(nextPath)
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            let reloadedProject = try loader.loadProject(at: loadedProject.fileURL)
            self.loadedProject = reloadedProject
            migratePageRuntimeState(from: currentHTMLURL, to: nextHTMLURL)
            seedKnownHTMLForProject(reloadedProject)
            if selectedCanvasSegment == segment {
                switch segment {
                case .pages:
                    selectedPageInternalID = originalPage.internalID
                    selectedPageID = originalPage.id
                case .components:
                    selectedComponentPageInternalID = originalPage.internalID
                    selectedComponentPageID = originalPage.id
                }
                selectedNodeID = nil
                nodes = []
                prepareHistoryForSelectedPage()
            }
            lastError = nil
            statusMessage = "\(URL(fileURLWithPath: nextPath).lastPathComponent) に変更しました。"
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
        } catch {
            if didMoveCSS {
                try? fileManager.moveItem(at: nextCSSURL, to: currentCSSURL)
            }
            if didMoveHTML {
                try? fileManager.moveItem(at: nextHTMLURL, to: currentHTMLURL)
            }
            for backup in dependencyBackups {
                try? backup.data.write(to: backup.url, options: .atomic)
            }
            try? writeProjectManifest(previousProject, to: loadedProject.fileURL)
            lastError = "ファイル名の変更に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: ノード複合参照ID生成関数
    /// 処理概要: 選択中 HTML 文脈と node 内部 ID から `.ogp` 内で一意な agent 向け参照 ID を作ります。
    ///
    /// - Parameter nodeID: 参照するDOM nodeのWebCanvas selection key。
    /// - Parameter nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    /// - Returns: `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>` 形式の参照 ID。
    func nodeReferenceID(forNodeID nodeID: String) -> String? {
        nodeReferenceID(forNodeID: nodeID, nodeInternalID: nil)
    }

    /// 論理名（日本語）: ノード複合参照ID生成関数
    /// 処理概要: 選択中 HTML 文脈と明示された node 内部 ID から `.ogp` 内で一意な agent 向け参照 ID を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照するDOM nodeのWebCanvas selection key。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    /// - Returns: Pages は `ogref:node:<chapterInternalID>:<pageInternalID>:<nodeInternalID>`、Components は `ogref:component-node:<collectionInternalID>:<componentInternalID>:<nodeInternalID>`。
    func nodeReferenceID(forNodeID nodeID: String, nodeInternalID: String?) -> String? {
        guard !nodeID.isEmpty, let page = selectedPage else { return nil }
        let pageInternalID = page.internalID.trimmingCharacters(in: .whitespacesAndNewlines)
        let inspectedNode = nodes.first { $0.id == nodeID || $0.editTargetNodeID == nodeID }
        let resolvedNodeInternalID = nodeInternalID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? inspectedNode?.internalID
            ?? ""
        guard !pageInternalID.isEmpty else { return nil }
        if inspectedNode?.referenceStability == .session,
           let sessionReference = inspectedNode?.reference.trimmingCharacters(in: .whitespacesAndNewlines),
           !sessionReference.isEmpty {
            return sessionReference
        }
        guard !resolvedNodeInternalID.isEmpty else {
            return nil
        }

        let syncTarget = currentHTMLSyncTarget()
        switch selectedDocumentSegment {
        case .pages:
            guard let chapterID = syncTarget?.identity.containerInternalID,
                  !chapterID.isEmpty
            else {
                return nil
            }
            return OpenGraphiteReferenceID
                .node(chapterID: chapterID, pageID: pageInternalID, nodeID: resolvedNodeInternalID)
                .stringValue
        case .components:
            guard let collectionID = syncTarget?.identity.containerInternalID,
                  !collectionID.isEmpty
            else {
                return nil
            }
            return OpenGraphiteReferenceID
                .componentNode(collectionID: collectionID, componentID: pageInternalID, nodeID: resolvedNodeInternalID)
                .stringValue
        }
    }

    /// 論理名（日本語）: ノード参照pasteboard payload生成関数
    /// 処理概要: OpenGraphite 内貼り付けとテキスト欄 ID 貼り付けの両方で使う node 参照情報を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照するDOM nodeのWebCanvas selection key。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    ///   - html: OpenGraphite 内貼り付け用の HTML subtree。
    /// - Returns: pasteboard 専用 JSON に変換できる辞書。
    func nodeReferencePasteboardPayload(forNodeID nodeID: String, html: String) -> [String: Any]? {
        nodeReferencePasteboardPayload(forNodeID: nodeID, nodeInternalID: nil, html: html)
    }

    /// 論理名（日本語）: ノード参照pasteboard payload生成関数
    /// 処理概要: 明示された node 内部 ID を含む pasteboard 専用 JSON payload を作ります。
    ///
    /// - Parameters:
    ///   - nodeID: 参照するDOM nodeのWebCanvas selection key。
    ///   - nodeInternalID: 参照する DOM node の `data-og-internal-id`。
    ///   - html: OpenGraphite 内貼り付け用の HTML subtree。
    /// - Returns: pasteboard 専用 JSON に変換できる辞書。
    func nodeReferencePasteboardPayload(
        forNodeID nodeID: String,
        nodeInternalID: String?,
        html: String
    ) -> [String: Any]? {
        let inspectedNode = nodes.first { $0.id == nodeID || $0.editTargetNodeID == nodeID }
        let resolvedNodeInternalID = nodeInternalID?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? inspectedNode?.internalID
            ?? ""
        guard let referenceID = nodeReferenceID(forNodeID: nodeID, nodeInternalID: resolvedNodeInternalID),
              let page = selectedPage
        else {
            return nil
        }

        var payload: [String: Any] = [
            "schemaVersion": "1",
            "kind": "opengraphite-node",
            "referenceID": referenceID,
            "segment": selectedDocumentSegment.rawValue,
            "pageID": page.id,
            "pageInternalID": page.internalID,
            "path": page.path,
            "nodeID": nodeID,
            "nodeInternalID": resolvedNodeInternalID,
            "annotationStatus": inspectedNode?.annotationStatus.rawValue ?? "partial",
            "referenceStability": inspectedNode?.referenceStability.rawValue ?? "stable",
            "html": html
        ]

        if let locator = inspectedNode?.locator {
            var locatorPayload: [String: Any] = [
                "documentURL": locator.documentURL,
                "domPath": locator.domPath,
                "sourceRange": ["start": locator.sourceStart, "end": locator.sourceEnd],
                "contentHash": locator.contentHash
            ]
            if let selector = locator.selector {
                locatorPayload["selector"] = selector
            }
            payload["locator"] = locatorPayload
        }

        if let projectURL = loadedProject?.fileURL.path {
            payload["projectURL"] = projectURL
        }

        switch selectedDocumentSegment {
        case .pages:
            if let chapter = loadedProject?.project.chapters.first(where: {
                $0.internalID == currentHTMLSyncTarget()?.identity.containerInternalID
            }) {
                payload["chapterID"] = chapter.id
                payload["chapterInternalID"] = chapter.internalID
                if let chapterIndex = loadedProject?.project.chapters.firstIndex(where: { $0.internalID == chapter.internalID }) {
                    payload["chapterIndex"] = chapterIndex
                    if let pageIndex = loadedProject?.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == page.internalID }) {
                        payload["pageIndex"] = pageIndex
                    }
                }
            }
        case .components:
            if let collection = loadedProject?.project.collections.first(where: {
                $0.internalID == currentHTMLSyncTarget()?.identity.containerInternalID
            }) {
                payload["collectionID"] = collection.id
                payload["collectionInternalID"] = collection.internalID
                if let collectionIndex = loadedProject?.project.collections.firstIndex(where: { $0.internalID == collection.internalID }) {
                    payload["collectionIndex"] = collectionIndex
                    if let componentIndex = loadedProject?.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == page.internalID }) {
                        payload["componentIndex"] = componentIndex
                    }
                }
            }
        }

        return payload
    }

    /// 論理名（日本語）: Project migration dry-run関数
    /// 処理概要: ユーザーの明示操作時だけShared coreをdry-runし、sourceを書かずにmulti-file diffとapply専用proposalを公開します。
    func previewProjectMigration() {
        guard let loadedProject else { return }
        guard cssMutation == nil,
              cssVariablesMutation == nil,
              cssVariablesBatchMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            lastError = "未適用の編集があるため、Project migrationのPreviewを保留しました。"
            statusMessage = "Canvasへの編集反映が完了してからProject migrationを再実行してください。"
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.migrateProject(
                projectURL: loadedProject.fileURL,
                targetVersion: contract.migrationPolicy.targetVersion,
                options: .standard
            )
            projectMigrationPreview = Self.projectMigrationPreview(from: result)
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                projectMigrationStatus = result.diagnostics.contains { $0.code == "stale-migration-proposal" }
                    ? .stale(targetVersion: result.targetContractVersion)
                    : .failed(targetVersion: result.targetContractVersion, message: error.message)
                lastError = error.message
                statusMessage = "Project migrationのPreviewを作成できませんでした。"
            } else if result.changed {
                projectMigrationStatus = .changesAvailable(
                    sourceVersion: result.sourceContractVersion,
                    targetVersion: result.targetContractVersion,
                    fileCount: result.diffs.count
                )
                lastError = nil
                statusMessage = "Project migration差分をdry-runしました。Applyするまでsourceは変更されません。"
            } else {
                projectMigrationStatus = .upToDate(version: result.targetContractVersion)
                lastError = nil
                statusMessage = "ProjectはWeb contract \(result.targetContractVersion)に対応済みです。"
            }
        } catch {
            projectMigrationStatus = .failed(
                targetVersion: contract.migrationPolicy.targetVersion,
                message: error.localizedDescription
            )
            lastError = "Project migrationのdry-runに失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Project migration明示適用関数
    /// 処理概要: confirmation sheetで確認したproposalをShared coreのatomic applyへ渡し、成功時だけmanifest・dependency・全page表示を再読込します。
    func applyProjectMigrationPreview() {
        guard let preview = projectMigrationPreview,
              let loadedProject,
              preview.canApply,
              let proposalReference = preview.proposalReference,
              !proposalReference.isEmpty
        else {
            return
        }
        guard cssMutation == nil,
              cssVariablesMutation == nil,
              cssVariablesBatchMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            lastError = "未適用の編集があるため、Project migrationのApplyを保留しました。"
            statusMessage = "Canvasへの編集反映が完了してからProject migrationを再実行してください。"
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        let pageURLs = loadedProject.project.allPages.map { loadedProject.htmlURL(for: $0) }
        do {
            let result = try core.migrateProject(
                projectURL: loadedProject.fileURL,
                targetVersion: preview.targetContractVersion,
                options: .standard,
                proposalReference: proposalReference,
                apply: true
            )
            let hasError = result.diagnostics.contains { $0.severity == .error }
            guard !hasError, result.applied || !result.changed else {
                projectMigrationPreview = Self.projectMigrationPreview(
                    from: result,
                    fallbackProposalReference: proposalReference
                )
                if result.diagnostics.contains(where: { $0.code == "stale-migration-proposal" }) {
                    projectMigrationStatus = .stale(targetVersion: result.targetContractVersion)
                } else {
                    let message = result.diagnostics.first(where: { $0.severity == .error })?.message
                        ?? "Project migrationを適用できませんでした。"
                    projectMigrationStatus = .failed(
                        targetVersion: result.targetContractVersion,
                        message: message
                    )
                }
                lastError = result.diagnostics.first(where: { $0.severity == .error })?.message
                    ?? "Project migrationを適用できませんでした。"
                statusMessage = result.diagnostics.contains(where: { $0.code == "stale-migration-proposal" })
                    ? "Sourceが変更されたため、Project migrationのPreviewを更新してください。"
                    : "Project migrationを適用できませんでした。"
                return
            }

            projectMigrationPreview = nil
            for pageURL in pageURLs {
                refreshPageFromDiskIfChanged(at: pageURL)
            }
            refreshProjectManifestFromDiskIfChanged()
            refreshProjectDependenciesFromDisk()
            projectMigrationStatus = result.applied
                ? .applied(version: result.targetContractVersion, fileCount: result.diffs.count)
                : .upToDate(version: result.targetContractVersion)
            lastError = nil
            statusMessage = result.applied
                ? "Web contract \(result.targetContractVersion) migrationを適用し、Project表示を再読込しました。"
                : "ProjectはWeb contract \(result.targetContractVersion)に対応済みです。"
        } catch {
            projectMigrationStatus = .failed(
                targetVersion: preview.targetContractVersion,
                message: error.localizedDescription
            )
            lastError = "Project migrationの適用に失敗しました: \(error.localizedDescription)"
            statusMessage = "Project migrationを適用できませんでした。"
        }
    }

    /// 論理名（日本語）: Project migration確認取消関数
    /// 処理概要: dry-run結果だけを破棄し、sourceと確認済みstatusを変更せずconfirmation sheetを閉じます。
    func cancelProjectMigrationPreview() {
        projectMigrationPreview = nil
    }

    /// 論理名（日本語）: Project migrationプレビュー変換関数
    /// 処理概要: Shared resultをApp sheet stateへ変換し、apply失敗応答がproposalを省略した場合は確認済みtokenを保持します。
    ///
    /// - Parameters:
    ///   - result: Shared coreが返したdry-runまたはapply結果。
    ///   - fallbackProposalReference: apply失敗時に保持する確認済みproposal token。
    /// - Returns: Project migration confirmation sheet state。
    private static func projectMigrationPreview(
        from result: OpenGraphiteProjectMigrationResult,
        fallbackProposalReference: String? = nil
    ) -> OpenGraphiteProjectMigrationPreview {
        OpenGraphiteProjectMigrationPreview(
            id: UUID(),
            sourceContractVersion: result.sourceContractVersion,
            targetContractVersion: result.targetContractVersion,
            proposalReference: result.proposalReference ?? fallbackProposalReference,
            changed: result.changed,
            diffs: result.diffs,
            diagnostics: result.diagnostics
        )
    }

    /// 論理名（日本語）: 選択Node adoption dry-run関数
    /// 処理概要: sourceを変更せず、既存のsafe authored selectorまたはDOM pathで対象を解決し、optional identity追加差分とapply条件を束縛したproposal tokenをconfirmation sheetへ公開します。
    ///
    /// - Parameter scope: 選択nodeだけ、またはそのsubtree全体。
    func previewSelectedNodeAdoption(scope: OpenGraphiteNodeAdoptionScope) {
        guard let loadedProject,
              let pageID = selectedPageReferenceID(),
              let node = selectedNode,
              node.canAdoptIdentity,
              let locator = node.locator
        else {
            return
        }

        let target = adoptionTarget(for: node, locator: locator)
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.adoptNode(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                reference: target.reference,
                selector: target.selector,
                domPath: target.domPath,
                scope: scope,
                displayID: nil,
                apply: false
            )
            nodeAdoptionPreview = OpenGraphiteNodeAdoptionPreview(
                id: UUID(),
                nodeID: node.id,
                displayName: node.displayID,
                scope: scope,
                reference: result.targetReference,
                selector: nil,
                domPath: nil,
                displayID: nil,
                path: result.path,
                changed: result.changed,
                unifiedDiff: result.diff?.unifiedDiff ?? "",
                diagnostics: result.diagnostics
            )
            lastError = nil
            statusMessage = "\(node.displayID) のadoption差分をdry-runしました。"
        } catch {
            lastError = "Node adoptionのdry-runに失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Node adoption明示適用関数
    /// 処理概要: confirmation sheetで確認済みのtarget・document revision・scope・display ID固定proposal tokenをShared coreへ渡し、成功時に対象WebCanvasを再読み込みします。
    func applyNodeAdoptionPreview() {
        guard let preview = nodeAdoptionPreview,
              let loadedProject,
              let pageID = selectedPageReferenceID(),
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.adoptNode(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                reference: preview.reference,
                selector: preview.selector,
                domPath: preview.domPath,
                scope: preview.scope,
                displayID: preview.displayID,
                apply: true
            )
            let hasError = result.diagnostics.contains { $0.severity == .error }
            guard !hasError, result.applied || !result.changed else {
                nodeAdoptionPreview = OpenGraphiteNodeAdoptionPreview(
                    id: UUID(),
                    nodeID: preview.nodeID,
                    displayName: preview.displayName,
                    scope: preview.scope,
                    reference: preview.reference,
                    selector: preview.selector,
                    domPath: preview.domPath,
                    displayID: preview.displayID,
                    path: result.path,
                    changed: result.changed,
                    unifiedDiff: result.diff?.unifiedDiff ?? preview.unifiedDiff,
                    diagnostics: result.diagnostics
                )
                lastError = result.diagnostics.first(where: { $0.severity == .error })?.message
                    ?? "Node adoptionを適用できませんでした。"
                return
            }
            nodeAdoptionPreview = nil
            incrementReloadToken(for: target.htmlURL)
            lastError = nil
            statusMessage = result.applied
                ? "\(preview.displayName) をstable referenceへadoptしました。"
                : "\(preview.displayName) は既にadopt済みです。"
        } catch {
            lastError = "Node adoptionの適用に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Node adoption確認取消関数
    /// 処理概要: dry-run結果を破棄し、sourceを変更せずconfirmation sheetを閉じます。
    func cancelNodeAdoptionPreview() {
        nodeAdoptionPreview = nil
    }

    /// 論理名（日本語）: Node adoption target選択関数
    /// 処理概要: stable referenceを最優先し、未注釈nodeでは既存のsafe authored selector、最後にDOM pathを選び、target指定を必ず1つにします。
    ///
    /// - Parameters:
    ///   - node: adoption対象のinspection node。
    ///   - locator: source locator。
    /// - Returns: Shared coreへ渡す排他的target指定。
    private func adoptionTarget(
        for node: OpenGraphiteNode,
        locator: OpenGraphiteNodeSourceLocator
    ) -> (reference: String?, selector: String?, domPath: String?) {
        if node.referenceStability == .stable, !node.reference.isEmpty {
            return (node.reference, nil, nil)
        }
        if let selector = locator.selector, !selector.isEmpty {
            return (nil, selector, nil)
        }
        return (nil, nil, locator.domPath)
    }

    /// 論理名（日本語）: ページ再読み込みトークン取得関数
    /// 処理概要: 指定 HTML URL の外部変更を WebView へ通知するための単調増加トークンを返します。
    ///
    /// - Parameter pageURL: reload token を取得する HTML URL。
    /// - Returns: WebView が比較する reload token。
    func reloadToken(for pageURL: URL) -> Int {
        pageReloadTokensByURL[pageURL] ?? 0
    }

    /// 論理名（日本語）: パネル経由プロジェクト作成関数
    /// 処理概要: 保存パネルから新規 `.ogp` の作成先を選ばせ、作成後に読み込みます。
    func createProjectWithPanel() {
        guard let url = ProjectDialogs.createProjectURL() else { return }
        createProject(at: url)
    }

    /// 論理名（日本語）: プロジェクト作成関数
    /// 処理概要: 指定された URL に新規 `.ogp` と初期 HTML/CSS を作成し、作成した project を開きます。
    ///
    /// - Parameter url: 新規 `.ogp` の作成先 URL。
    func createProject(at url: URL) {
        do {
            let projectURL = try projectCreator.createProject(at: url)
            openProject(at: projectURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: サンプルプロジェクトオープン関数
    /// 処理概要: Debug 実行時は指定 sample `.ogp`、Release/no-env 時は Application Support の編集用 sample を読み込みます。
    func openSampleProject() {
        do {
            let url = try sampleProjectLocator.sampleProjectURL()
            openProject(at: url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: パネル経由プロジェクトオープン関数
    /// 処理概要: ファイル選択パネルから `.ogp` を選ばせ、選択された URL を読み込みます。
    func openProjectWithPanel() {
        guard let url = ProjectDialogs.openProjectURL() else { return }
        openProject(at: url)
    }

    /// 論理名（日本語）: プロジェクトオープン関数
    /// 処理概要: 指定された `.ogp` を読み込み、Chapter 表示対象とノード状態を初期化します。
    ///
    /// - Parameter url: 読み込む `.ogp` の URL。
    func openProject(at url: URL) {
        do {
            let project = try loader.loadProject(at: url)
            let initialChapter = Self.preferredVisibleChapter(in: project.project)
            let initialCollection = Self.preferredCollection(in: project.project)
            loadedProject = project
            selectedCanvasSegment = project.project.chapters.flatMap(\.pages).isEmpty && !project.project.collections.isEmpty
                ? .components
                : .pages
            selectedChapterID = initialChapter?.id
            selectedChapterInternalID = initialChapter?.internalID
            selectedPageID = nil
            selectedPageInternalID = nil
            selectedCollectionID = initialCollection?.id
            selectedCollectionInternalID = initialCollection?.internalID
            selectedComponentPageID = nil
            selectedComponentPageInternalID = nil
            selectedCanvasAnnotationID = nil
            clearCanvasReferenceSelection()
            selectedProjectResource = nil
            selectedNodeID = nil
            focusedPreviewTarget = nil
            nodes = []
            cssMutation = nil
            cssVariablesMutation = nil
            cssVariablesBatchMutation = nil
            attributeMutation = nil
            textMutation = nil
            documentReplacementRequest = nil
            nodeAdoptionPreview = nil
            projectMigrationPreview = nil
            projectMigrationStatus = .notChecked(
                targetVersion: OpenGraphiteContract.loadDefault(startingAt: project.fileURL)
                    .migrationPolicy.targetVersion
            )
            canvasReferenceResolutionCache = [:]
            nodeSourceIndexTask?.cancel()
            nodeSourceIndexTask = nil
            nodeSourceIndexTaskKey = nil
            latestNodeSourceIndexKey = nil
            latestLayerNodePayload = []
            nodeDetailPayloadsByID = [:]
            nodeSourceIndexCache = [:]
            nodeSourceIndexBuildCount = 0
            syncHistories = [:]
            editorUndoStack = []
            editorRedoStack = []
            stagedCanvasAnnotationTextDrafts = [:]
            lastKnownPageHTMLByURL = [:]
            pageReloadTokensByURL = [:]
            staticFlowLinksByPageInternalID = [:]
            staticFlowLinksByPageURL = [:]
            hoveredStaticFlowSource = nil
            do {
                try currentProjectStore?.write(projectURL: project.fileURL)
            } catch {
                lastError = error.localizedDescription
            }
            seedKnownHTMLForProject(project)
            prepareHistoryForSelectedPage()
            restartExternalProjectMonitoring(force: true)
            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
            statusMessage = "\(project.project.name) を開きました。"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: ページ選択解除関数
    /// 処理概要: `nil` 指定時に選択ページを解除し、ノード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみページ選択を解除します。
    func selectPage(id: String?) {
        guard id == nil else { return }
        selectPage(internalID: nil)
    }

    /// 論理名（日本語）: 内部IDページ選択関数
    /// 処理概要: HTML カードの内部 ID で選択ページを切り替えます。
    ///
    /// - Parameter internalID: 選択するページカード内部 ID。`nil` の場合はページ選択を解除します。
    func selectPage(internalID: String?) {
        selectPage(matching: { page in page.internalID == internalID })
    }

    /// 論理名（日本語）: ページ選択共通関数
    /// 処理概要: 指定条件でページを解決し、表示対象と履歴状態を更新します。
    ///
    /// - Parameter predicate: 選択対象ページの判定。
    private func selectPage(matching predicate: (OpenGraphitePage) -> Bool) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        switch selectedCanvasSegment {
        case .pages:
            let page = selectedChapterPages.first(where: predicate)
            selectedPageID = page?.id
            selectedPageInternalID = page?.internalID
        case .components:
            let page = componentPages.first(where: predicate)
            selectedComponentPageID = page?.id
            selectedComponentPageInternalID = page?.internalID
        }
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        } else {
            statusMessage = "ページ選択を解除しました。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Chapter選択解除関数
    /// 処理概要: `nil` 指定時に先頭 Chapter を表示し、HTML カード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみ先頭 Chapter が表示対象になります。
    func selectChapter(id: String?) {
        guard id == nil else { return }
        guard let loadedProject else { return }
        selectChapter(Self.preferredVisibleChapter(in: loadedProject.project))
    }

    /// 論理名（日本語）: 内部ID Chapter選択関数
    /// 処理概要: Chapter 内部 ID で Pages セグメントの表示対象を切り替え、HTML カード選択を解除します。
    ///
    /// - Parameter internalID: 選択する Chapter 内部 ID。`nil` の場合は先頭 Chapter が表示対象になります。
    func selectChapter(internalID: String?) {
        guard let loadedProject else { return }
        let chapter = loadedProject.project.chapters.first { $0.internalID == internalID }
            ?? Self.preferredVisibleChapter(in: loadedProject.project)
        selectChapter(chapter)
    }

    /// 論理名（日本語）: Chapter選択共通関数
    /// 処理概要: 指定 Chapter を Pages セグメントへ反映し、HTML カードを未選択にします。
    ///
    /// - Parameter chapter: 選択する Chapter。`nil` の場合は未選択状態にします。
    private func selectChapter(_ chapter: OpenGraphiteChapter?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        selectedCanvasSegment = .pages
        selectedChapterID = chapter?.id
        selectedChapterInternalID = chapter?.internalID
        selectedPageID = nil
        selectedPageInternalID = nil
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }

        if let chapter {
            statusMessage = "\(chapter.displayName) を表示しています。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Collection選択解除関数
    /// 処理概要: `nil` 指定時に先頭 Collection を表示し、component canvas 選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: `nil` の場合のみ先頭 Collection が表示対象になります。
    func selectCollection(id: String?) {
        guard id == nil else { return }
        guard let loadedProject else { return }
        selectCollection(Self.preferredCollection(in: loadedProject.project))
    }

    /// 論理名（日本語）: 内部ID Collection選択関数
    /// 処理概要: Collection 内部 ID で Components セグメントの表示対象を切り替えます。
    ///
    /// - Parameter internalID: 選択する Collection 内部 ID。`nil` の場合は先頭 Collection が表示対象になります。
    func selectCollection(internalID: String?) {
        guard let loadedProject else { return }
        let collection = Self.preferredCollection(in: loadedProject.project, internalID: internalID)
        selectCollection(collection)
    }

    /// 論理名（日本語）: Collection選択共通関数
    /// 処理概要: 指定 Collection を Components セグメントへ反映し、component canvas は未選択にします。
    ///
    /// - Parameter collection: 選択する Collection。`nil` の場合は未選択状態にします。
    private func selectCollection(_ collection: OpenGraphiteComponentCollection?) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        selectedCanvasSegment = .components
        selectedCollectionID = collection?.id
        selectedCollectionInternalID = collection?.internalID
        selectedComponentPageID = nil
        selectedComponentPageInternalID = nil
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }

        if let collection {
            statusMessage = "\(collection.displayName) を表示しています。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Pagesセグメント選択関数
    /// 処理概要: Pages canvas を表示し、HTML カードが未選択なら Chapter 階層を維持します。
    func selectPagesSegment() {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        selectedCanvasSegment = .pages
        if selectedChapterInternalID == nil
            || loadedProject?.project.chapters.contains(where: {
                $0.internalID == selectedChapterInternalID && !$0.isSidebarHidden
            }) != true {
            let chapter = loadedProject.flatMap { Self.preferredVisibleChapter(in: $0.project) }
            selectedChapterID = chapter?.id
            selectedChapterInternalID = chapter?.internalID
        }
        if let selectedPageInternalID,
           !selectedChapterPages.contains(where: { $0.internalID == selectedPageInternalID }) {
            selectedPageID = nil
            self.selectedPageInternalID = nil
        }
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL || selectedPage == nil {
            nodes = []
        }
        statusMessage = "Pages を表示しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Componentsセグメント選択関数
    /// 処理概要: Components canvas を表示し、有効な既存選択だけを維持します。
    func selectComponentsSegment() {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        selectedCanvasSegment = .components
        if selectedCollectionInternalID == nil
            || loadedProject?.project.collections.contains(where: { $0.internalID == selectedCollectionInternalID }) != true {
            let collection = loadedProject.flatMap { Self.preferredCollection(in: $0.project) }
            selectedCollectionID = collection?.id
            selectedCollectionInternalID = collection?.internalID
        }
        if selectedComponentPageInternalID == nil || !componentPages.contains(where: { $0.internalID == selectedComponentPageInternalID }) {
            selectedComponentPageID = nil
            selectedComponentPageInternalID = nil
        }
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        statusMessage = "Components を表示しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: Componentページ選択解除関数
    /// 処理概要: `nil` 指定時に Components セグメント内の HTML canvas 選択を解除します。
    ///
    /// - Parameter id: `nil` の場合のみ選択解除します。
    func selectComponentPage(id: String?) {
        guard id == nil else { return }
        selectComponentPage(internalID: nil)
    }

    /// 論理名（日本語）: 内部ID Componentページ選択関数
    /// 処理概要: Component canvas カードの内部 ID で選択対象を切り替えます。
    ///
    /// - Parameter internalID: 選択する component page 内部 ID。`nil` の場合は選択解除します。
    func selectComponentPage(internalID: String?) {
        selectComponentPage(matching: { page in page.internalID == internalID })
    }

    /// 論理名（日本語）: Componentページ選択共通関数
    /// 処理概要: 指定条件で component page を解決し、選択状態を更新します。
    ///
    /// - Parameter predicate: 選択対象 component page の判定。
    private func selectComponentPage(matching predicate: (OpenGraphitePage) -> Bool) {
        let previousCanvasSegment = selectedCanvasSegment
        let previousPageURL = selectedPageURL
        clearCanvasReferenceSelection()
        selectedProjectResource = nil
        var collection = selectedComponentCollection
        var page = collection?.components.first(where: predicate)
        if page == nil, let loadedProject {
            for candidateCollection in loadedProject.project.collections {
                if let candidatePage = candidateCollection.components.first(where: predicate) {
                    collection = candidateCollection
                    page = candidatePage
                    break
                }
            }
        }
        selectedCanvasSegment = .components
        selectedCollectionID = collection?.id
        selectedCollectionInternalID = collection?.internalID
        selectedComponentPageID = page?.id
        selectedComponentPageInternalID = page?.internalID
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        if selectedCanvasSegment != previousCanvasSegment || selectedPageURL != previousPageURL {
            nodes = []
        }
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        } else {
            statusMessage = "Component ページ選択を解除しました。"
        }
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: ノード選択関数
    /// 処理概要: Layers、Canvas、Context Menu から渡されたannotation非依存のWebCanvas selection keyを保存します。
    ///
    /// - Parameter id: 選択するノード ID。placement clone 内では表示専用の合成 ID、選択解除時は `nil`。
    func selectNode(id: String?) {
        if id != nil {
            selectedProjectResource = nil
        }
        selectedNodeSelectionAnchorID = id
        selectedNodeIDs = id.map { Set([$0]) } ?? []
        selectedNodeID = id
    }

    /// 論理名（日本語）: フォーカスプレビュー開始関数
    /// 処理概要: 右クリック対象の node と document 座標上の実測矩形を、通常選択とは独立した単独表示対象として保持します。
    ///
    /// - Parameters:
    ///   - nodeID: 単独表示する node ID。
    ///   - pageInternalID: node を含む page card の内部 ID。
    ///   - segment: page card が属する Pages / Components セグメント。
    ///   - rect: page document 座標上の object 実測矩形。
    /// - Returns: 有効な対象を開始できた場合は `true`。
    @discardableResult
    func beginFocusedPreview(
        nodeID: String,
        pageInternalID: String,
        segment: OpenGraphiteCanvasSegment,
        rect: CGRect
    ) -> Bool {
        let normalizedNodeID = nodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPageInternalID = pageInternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNodeID.isEmpty,
              !normalizedPageInternalID.isEmpty,
              rect.minX.isFinite,
              rect.minY.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.width > 0,
              rect.height > 0
        else {
            return false
        }

        focusedPreviewTarget = OpenGraphiteFocusedPreviewTarget(
            segment: segment,
            pageInternalID: normalizedPageInternalID,
            nodeID: normalizedNodeID,
            rect: rect
        )
        statusMessage = "\(normalizedNodeID) をフォーカス表示しています。"
        return true
    }

    /// 論理名（日本語）: ページ全体フォーカスプレビュー開始関数
    /// 処理概要: page card の右クリックから、page canvas 全体を通常選択とは独立した単独表示対象として保持します。
    ///
    /// - Parameters:
    ///   - pageInternalID: 単独表示する page card の内部 ID。
    ///   - segment: page card が属する Pages / Components セグメント。
    ///   - size: original resolution として使う page canvas 寸法。
    /// - Returns: 有効な page 対象を開始できた場合は `true`。
    @discardableResult
    func beginFocusedPagePreview(
        pageInternalID: String,
        segment: OpenGraphiteCanvasSegment,
        size: CGSize
    ) -> Bool {
        let normalizedPageInternalID = pageInternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPageInternalID.isEmpty,
              size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else {
            return false
        }

        focusedPreviewTarget = OpenGraphiteFocusedPreviewTarget(
            segment: segment,
            pageInternalID: normalizedPageInternalID,
            nodeID: nil,
            rect: CGRect(origin: .zero, size: size)
        )
        statusMessage = "page をフォーカス表示しています。"
        return true
    }

    /// 論理名（日本語）: フォーカスプレビュー解除関数
    /// 処理概要: 右クリックで開始した単独表示対象を解除し、Normal / Flow のキャンバス表示へ戻します。
    func endFocusedPreview() {
        guard focusedPreviewTarget != nil else { return }
        focusedPreviewTarget = nil
        statusMessage = "フォーカス表示を解除しました。"
    }

    /// 論理名（日本語）: ノード範囲選択関数
    /// 処理概要: Sidebar Layers の表示順を基準に、選択アンカーから指定ノードまでを同時選択状態にします。
    ///
    /// - Parameters:
    ///   - id: 範囲選択の終端にするノード ID。
    ///   - visibleNodeIDs: 現在 Sidebar Layers に表示されているノード ID の順序付き一覧。
    func selectNodeRange(to id: String, visibleNodeIDs: [String]) {
        let orderedIDs = visibleNodeIDs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let targetIndex = orderedIDs.firstIndex(of: id) else {
            selectNode(id: id)
            return
        }

        let anchorID = selectedNodeSelectionAnchorID ?? selectedNodeID
        guard let anchorID,
              let anchorIndex = orderedIDs.firstIndex(of: anchorID)
        else {
            selectNode(id: id)
            return
        }

        selectedProjectResource = nil
        let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedNodeIDs = Set(orderedIDs[bounds])
        selectedNodeSelectionAnchorID = anchorID
        isApplyingNodeRangeSelection = true
        selectedNodeID = id
        isApplyingNodeRangeSelection = false
    }

    /// 論理名（日本語）: 同時選択内主ノード選択関数
    /// 処理概要: Sidebar Layers の同時選択セットを維持したまま、Inspector が扱う主選択 node だけを切り替えます。
    ///
    /// - Parameter id: 主選択へ切り替える node ID。
    /// - Returns: 同時選択内の主選択として処理できた場合は `true`。
    @discardableResult
    func selectPrimaryNodeWithinCurrentSelection(id: String) -> Bool {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty,
              selectedNodeIDs.count > 1,
              selectedNodeIDs.contains(normalizedID)
        else {
            return false
        }

        selectedProjectResource = nil
        isApplyingNodeRangeSelection = true
        defer { isApplyingNodeRangeSelection = false }
        selectedNodeID = normalizedID
        return true
    }

    /// 論理名（日本語）: 主ノード選択同期関数
    /// 処理概要: 単一選択系の更新では Sidebar Layers の同時選択を単一行へ戻し、範囲選択中のみ既存セットを維持します。
    private func synchronizeLayerNodeSelectionForPrimarySelection() {
        guard let selectedNodeID else {
            selectedNodeIDs = []
            selectedNodeSelectionAnchorID = nil
            return
        }

        guard isApplyingNodeRangeSelection else {
            selectedNodeIDs = Set([selectedNodeID])
            selectedNodeSelectionAnchorID = selectedNodeID
            return
        }

        if !selectedNodeIDs.contains(selectedNodeID) {
            selectedNodeIDs.insert(selectedNodeID)
        }
        if selectedNodeSelectionAnchorID == nil {
            selectedNodeSelectionAnchorID = selectedNodeID
        }
    }

    /// 論理名（日本語）: ノード一覧同期後選択整理関数
    /// 処理概要: WebView から再取得したノード一覧に存在しない Sidebar Layers の同時選択を破棄します。
    private func synchronizeLayerNodeSelectionWithAvailableNodes() {
        guard let selectedNodeID else {
            selectedNodeIDs = []
            selectedNodeSelectionAnchorID = nil
            return
        }

        let availableNodeIDs = Set(nodes.map(\.id))
        guard availableNodeIDs.contains(selectedNodeID) else {
            self.selectedNodeID = nil
            return
        }

        selectedNodeIDs.formIntersection(availableNodeIDs)
        selectedNodeIDs.insert(selectedNodeID)
        if let selectedNodeSelectionAnchorID,
           !availableNodeIDs.contains(selectedNodeSelectionAnchorID) {
            self.selectedNodeSelectionAnchorID = selectedNodeID
        } else if selectedNodeSelectionAnchorID == nil {
            selectedNodeSelectionAnchorID = selectedNodeID
        }
    }

    /// 論理名（日本語）: 選択オーバーレイpayload取り込み関数
    /// 処理概要: WebView 実測 rect payload を検証し、Canvas 側の選択枠 source of truth として保存します。
    ///
    /// - Parameters:
    ///   - payload: `active`、`id`、`nodes`、`x`、`y`、`width`、`height` を含む JavaScript bridge payload。
    ///   - pageInternalID: payload を送信した page card の内部 ID。
    func ingestSelectionOverlayPayload(_ payload: [String: Any]?, pageInternalID: String?) {
        let normalizedPageInternalID = Self.normalizedOptionalString(pageInternalID)
        guard let payload,
              payload["active"] as? Bool == true
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let selectedNodeIDsInOrder = selectedLayerNodeIDsInNodeOrder
        guard let selectedNodeID,
              !selectedNodeIDsInOrder.isEmpty
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let rawNodePayloads = payload["nodes"] as? [[String: Any]] ?? [payload]
        let selectedNodeIDSet = Set(selectedNodeIDsInOrder)
        var nodeRectsByID: [String: CGRect] = [:]
        for rawNodePayload in rawNodePayloads {
            guard let nodeFrame = Self.selectionOverlayNodeFrame(from: rawNodePayload),
                  selectedNodeIDSet.contains(nodeFrame.id)
            else {
                continue
            }
            nodeRectsByID[nodeFrame.id] = nodeFrame.rect
        }

        let measuredNodeIDs = selectedNodeIDsInOrder.filter { nodeRectsByID[$0] != nil }
        guard !measuredNodeIDs.isEmpty,
              let unionRect = Self.unionRect(measuredNodeIDs.compactMap { nodeRectsByID[$0] })
        else {
            clearSelectionOverlayFrame(pageInternalID: normalizedPageInternalID)
            return
        }

        let payloadPrimaryID = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryNodeID = selectedNodeIDSet.contains(payloadPrimaryID) ? payloadPrimaryID : selectedNodeID
        selectionOverlayFrame = OpenGraphiteSelectionOverlayFrame(
            pageInternalID: normalizedPageInternalID,
            primaryNodeID: primaryNodeID,
            nodeIDs: measuredNodeIDs,
            nodeRectsByID: nodeRectsByID,
            rect: unionRect
        )
    }

    /// 論理名（日本語）: 選択オーバーレイ解除関数
    /// 処理概要: 選択解除や対象 page 切り替え時に実測選択枠を破棄します。
    ///
    /// - Parameter pageInternalID: 解除対象を page card 内部 ID で限定します。`nil` の場合は無条件で解除します。
    func clearSelectionOverlayFrame(pageInternalID: String? = nil) {
        guard let pageInternalID else {
            selectionOverlayFrame = nil
            return
        }
        if selectionOverlayFrame?.pageInternalID == pageInternalID {
            selectionOverlayFrame = nil
        }
    }

    /// 論理名（日本語）: ノードドラッグpreview payload取り込み関数
    /// 処理概要: WebView でドラッグ中の選択 node 矩形を受け取り、Canvas 側の選択枠を一時的に追従させます。
    ///
    /// - Parameters:
    ///   - payload: `active`、`id`、`x`、`y`、`width`、`height` を含む JavaScript bridge payload。
    ///   - pageInternalID: payload を送信した page card の内部 ID。
    func ingestNodeDragPreviewPayload(_ payload: [String: Any], pageInternalID: String?) {
        guard payload["active"] as? Bool == true else {
            clearNodeDragPreview(pageInternalID: pageInternalID)
            return
        }

        let id = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              id == selectedNodeID,
              let x = Self.cgFloatValue(payload["x"]),
              let y = Self.cgFloatValue(payload["y"]),
              let width = Self.cgFloatValue(payload["width"]),
              let height = Self.cgFloatValue(payload["height"]),
              width > 0,
              height > 0
        else {
            return
        }

        nodeDragPreview = OpenGraphiteNodeDragPreview(
            pageInternalID: pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines),
            nodeID: id,
            rect: CGRect(x: x, y: y, width: width, height: height)
        )
    }

    /// 論理名（日本語）: ノードドラッグpreview解除関数
    /// 処理概要: ドラッグ終了や対象 page 切り替え時に一時 preview を破棄します。
    ///
    /// - Parameter pageInternalID: 解除対象を page card 内部 ID で限定します。`nil` の場合は無条件で解除します。
    func clearNodeDragPreview(pageInternalID: String? = nil) {
        guard let pageInternalID else {
            nodeDragPreview = nil
            return
        }
        if nodeDragPreview?.pageInternalID == pageInternalID {
            nodeDragPreview = nil
        }
    }

    /// 論理名（日本語）: プレビューテキスト編集中payload取り込み関数
    /// 処理概要: WebView の contenteditable 入力中に届く text payload を選択中 node へ反映し、Inspector 表示を即時同期します。
    ///
    /// - Parameter payload: `id` と `text` を含む JavaScript bridge payload。
    func ingestTextEditingPayload(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              !id.isEmpty,
              id == selectedNodeID,
              let index = nodes.firstIndex(where: { $0.id == id }),
              nodes[index].supports(.editText)
        else {
            return
        }

        let text = payload["text"] as? String ?? ""
        let previousText = nodes[index].textContent ?? ""
        nodes[index].textContent = text
        if !nodes[index].isTextBinding {
            nodes[index].fallbackTextContent = text
        }
        if previousText != text {
            requestInspectorSections([.text])
        }
    }

    /// 論理名（日本語）: コンポーネント継承元解決関数
    /// 処理概要: 選択ノードの `data-og-component` または runtime-private component metadata から project 内の master 配置を解決します。
    ///
    /// - Parameter node: 継承元を調べる OpenGraphite ノード。
    /// - Returns: project 内で見つかった component master の表示情報。未解決の場合は `nil`。
    func componentSource(for node: OpenGraphiteNode) -> OpenGraphiteComponentSource? {
        guard let componentID = node.inheritedComponentID,
              let loadedProject
        else {
            return nil
        }
        return componentSource(componentID: componentID, in: loadedProject)
    }

    /// 論理名（日本語）: 適用親アニメーション文脈解決関数
    /// 処理概要: 選択ノードの祖先を近い順にたどり、Inspector に表示する親側 animation / timeline declaration を取得します。
    ///
    /// - Parameter node: 表示中の選択ノード。
    /// - Returns: 親側の animation / timeline context。該当する祖先がない場合は `nil`。
    private func appliedParentAnimationContext(for node: OpenGraphiteNode) -> OpenGraphiteAppliedAnimationContext? {
        guard let selectedIndex = nodes.firstIndex(where: { $0.id == node.id }) else {
            return nil
        }

        let ancestors = Self.ancestorNodes(in: nodes, selectedIndex: selectedIndex)
        let requestedTimelineNames = Self.dashedIdentifiers(in: node.cssVariables["animation-timeline"] ?? "")
        if !requestedTimelineNames.isEmpty,
           let matchedAncestor = ancestors.first(where: { ancestor in
               !Self.timelineProviderNames(in: ancestor.cssVariables).isDisjoint(with: requestedTimelineNames)
           }) {
            let matchedNames = Self.timelineProviderNames(in: matchedAncestor.cssVariables)
                .intersection(requestedTimelineNames)
                .sorted()
            return Self.animationContext(for: matchedAncestor, matchedTimelineNames: matchedNames)
        }

        return ancestors.lazy.compactMap { ancestor in
            Self.animationContext(for: ancestor)
        }.first
    }

    /// 論理名（日本語）: コンポーネント継承元表示関数
    /// 処理概要: Inspector から指定された component master の canvas へ表示対象を切り替え、master root を再選択します。
    ///
    /// - Parameter source: 移動先 component master の表示情報。
    func revealComponentSource(_ source: OpenGraphiteComponentSource) {
        guard loadedProject?.project.collections.contains(where: { collection in
            collection.internalID == source.collectionInternalID
                && collection.components.contains { $0.internalID == source.componentPageInternalID }
        }) == true else {
            return
        }

        selectComponentPage(internalID: source.componentPageInternalID)
        selectedNodeID = source.masterNodeID
        statusMessage = "\(source.componentID) の component master を表示しています。"
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 既存の配置名を保持したまま、選択中ページのキャンバス座標と解像度を `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    func updateSelectedPageCanvas(x: Double, y: Double, width: Double, height: Double) {
        updateSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: selectedPage?.canvas.name ?? "",
            previewContext: selectedPage?.canvas.previewContext ?? .empty
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス位置更新関数
    /// 処理概要: 選択中ページの既存の配置名、解像度、preview Mock State を維持したまま、canvas 座標だけを `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    func updateSelectedPageCanvasPosition(x: Double, y: Double) {
        guard let canvas = selectedPage?.canvas else { return }
        persistSelectedPageCanvas(
            x: x,
            y: y,
            width: canvas.width,
            height: canvas.height,
            name: canvas.name,
            previewContext: canvas.previewContext,
            statusMessageBuilder: { page in
                "\(page.path) のキャンバス位置を更新しました。"
            }
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 選択中ページのキャンバス配置名、座標、解像度、preview Mock State を `.ogp` へ保存し、表示中 project state へ反映します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    ///   - previewContext: エディター内 preview へ注入する runtime Mock State。
    func updateSelectedPageCanvas(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String,
        previewContext: OpenGraphitePreviewContext
    ) {
        persistSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: name,
            previewContext: previewContext,
            statusMessageBuilder: nil
        )
    }

    /// 論理名（日本語）: 選択ページキャンバス保存関数
    /// 処理概要: 選択中 page / component canvas の配置情報を検証し、`.ogp` と表示中 project state へ反映します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    ///   - previewContext: エディター内 preview へ注入する runtime Mock State。
    ///   - statusMessageBuilder: 保存成功時のステータス文言を作る任意クロージャ。
    private func persistSelectedPageCanvas(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        name: String,
        previewContext: OpenGraphitePreviewContext,
        statusMessageBuilder: ((OpenGraphitePage) -> String)?
    ) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite, width > 0, height > 0 else {
            lastError = "キャンバス配置の入力が不正です。"
            return
        }
        guard var loadedProject else { return }

        let normalizedName = Self.normalizedCanvasName(name)
        let nextCanvas = OpenGraphiteCanvas(
            name: normalizedName,
            x: x,
            y: y,
            width: width,
            height: height,
            previewContext: previewContext
        )
        let updatedPage: OpenGraphitePage
        switch selectedCanvasSegment {
        case .pages:
            guard let selectedPageInternalID else { return }
            var chapterIndex: Array<OpenGraphiteChapter>.Index?
            if let selectedChapterInternalID,
               let selectedChapterIndex = loadedProject.project.chapters.firstIndex(where: { $0.internalID == selectedChapterInternalID }),
               loadedProject.project.chapters[selectedChapterIndex].pages.contains(where: { $0.internalID == selectedPageInternalID }) {
                chapterIndex = selectedChapterIndex
            }
            if chapterIndex == nil {
                chapterIndex = loadedProject.project.chapters.firstIndex { chapter in
                    chapter.pages.contains { $0.internalID == selectedPageInternalID }
                }
            }
            guard let chapterIndex,
                  let pageIndex = loadedProject.project.chapters[chapterIndex].pages.firstIndex(where: { $0.internalID == selectedPageInternalID })
            else {
                return
            }
            guard loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.chapters[chapterIndex].pages[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.chapters[chapterIndex].pages[pageIndex]
        case .components:
            guard let selectedComponentPageInternalID else {
                return
            }
            var collectionIndex: Array<OpenGraphiteComponentCollection>.Index?
            if let selectedCollectionInternalID,
               let selectedCollectionIndex = loadedProject.project.collections.firstIndex(where: { $0.internalID == selectedCollectionInternalID }),
               loadedProject.project.collections[selectedCollectionIndex].components.contains(where: { $0.internalID == selectedComponentPageInternalID }) {
                collectionIndex = selectedCollectionIndex
            }
            if collectionIndex == nil {
                collectionIndex = loadedProject.project.collections.firstIndex { collection in
                    collection.components.contains { $0.internalID == selectedComponentPageInternalID }
                }
            }
            guard let collectionIndex,
                  let pageIndex = loadedProject.project.collections[collectionIndex].components.firstIndex(where: { $0.internalID == selectedComponentPageInternalID })
            else {
                return
            }
            guard loadedProject.project.collections[collectionIndex].components[pageIndex].canvas != nextCanvas else { return }
            loadedProject.project.collections[collectionIndex].components[pageIndex].canvas = nextCanvas
            updatedPage = loadedProject.project.collections[collectionIndex].components[pageIndex]
        }

        do {
            try writeProjectManifest(loadedProject.project, to: loadedProject.fileURL)
            self.loadedProject = loadedProject
            lastError = nil
            statusMessage = statusMessageBuilder?(updatedPage)
                ?? "\(updatedPage.path) のキャンバス配置を更新しました。Mock State も保存しました。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: キャンバスガイド追加関数
    /// 処理概要: 現在表示中の Chapter / Collection へガイドを追加し、`.ogp` だけを保存します。
    ///
    /// - Parameters:
    ///   - orientation: 水平または垂直のガイド方向。
    ///   - position: 垂直なら X、水平なら Y のキャンバス world 座標。
    /// - Returns: 追加したガイドの内部 ID。保存できない場合は `nil`。
    @discardableResult
    func addCanvasGuide(
        orientation: OpenGraphiteCanvasGuideOrientation,
        position: Double
    ) -> String? {
        guard let position = OpenGraphiteCanvasGuide.normalizedPosition(position) else { return nil }
        let internalID = UUID().uuidString.lowercased()
        let guide = OpenGraphiteCanvasGuide(
            internalID: internalID,
            orientation: orientation,
            position: position
        )
        guard persistSelectedCanvasGuides({ guides in
            guides.append(guide)
            return true
        }, status: "ガイドを .ogp に追加しました。") else {
            return nil
        }
        return internalID
    }

    /// 論理名（日本語）: キャンバスガイド位置更新関数
    /// 処理概要: 指定ガイドの方向と内部 ID を維持し、world 座標を `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - id: 更新対象ガイドの内部 ID。
    ///   - position: 更新後の X または Y world 座標。
    func updateCanvasGuide(id: String, position: Double) {
        guard let position = OpenGraphiteCanvasGuide.normalizedPosition(position) else { return }
        _ = persistSelectedCanvasGuides({ guides in
            guard let index = guides.firstIndex(where: { $0.internalID == id }),
                  guides[index].position != position
            else {
                return false
            }
            guides[index].position = position
            return true
        }, status: "ガイドの位置を .ogp に保存しました。")
    }

    /// 論理名（日本語）: キャンバスガイド削除関数
    /// 処理概要: 指定ガイドを現在の Chapter / Collection から削除して `.ogp` へ保存します。
    ///
    /// - Parameter id: 削除対象ガイドの内部 ID。
    func deleteCanvasGuide(id: String) {
        _ = persistSelectedCanvasGuides({ guides in
            let previousCount = guides.count
            guides.removeAll { $0.internalID == id }
            return guides.count != previousCount
        }, status: "ガイドを .ogp から削除しました。")
    }

    /// 論理名（日本語）: 付箋追加関数
    /// 処理概要: 現在表示中の Chapter / Collection へテキスト編集可能な付箋を追加し、`.ogp` だけを保存します。
    ///
    /// - Parameter point: 付箋左上にするキャンバス座標。
    /// - Returns: 追加した注釈の内部 ID。保存できない場合は `nil`。
    @discardableResult
    func addStickyNote(at point: CGPoint) -> String? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let internalID = UUID().uuidString.lowercased()
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: internalID,
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(
                x: Double(point.x),
                y: Double(point.y),
                width: 240,
                height: 160
            )
        )
        guard persistSelectedCanvasAnnotations({ annotations in
            annotations.append(annotation)
            return true
        }, status: "付箋を .ogp に追加しました。") else {
            return nil
        }
        selectCanvasAnnotation(id: internalID)
        return internalID
    }

    /// 論理名（日本語）: 手書き注釈追加関数
    /// 処理概要: 正規化済みフレームとストロークを現在の Chapter / Collection へ追加し、`.ogp` だけを保存します。
    ///
    /// - Parameters:
    ///   - frame: ストロークを包含するキャンバス座標フレーム。
    ///   - strokes: フレーム左上を原点とする手書きストローク。
    /// - Returns: 追加した注釈の内部 ID。保存できない場合は `nil`。
    @discardableResult
    func addInkAnnotation(
        frame: OpenGraphiteCanvasAnnotationFrame,
        strokes: [OpenGraphiteInkStroke]
    ) -> String? {
        guard strokes.contains(where: { !$0.points.isEmpty }) else { return nil }
        let internalID = UUID().uuidString.lowercased()
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: internalID,
            kind: .ink,
            frame: frame,
            strokes: strokes
        )
        guard persistSelectedCanvasAnnotations({ annotations in
            annotations.append(annotation)
            return true
        }, status: "手書きメモを .ogp に追加しました。") else {
            return nil
        }
        selectCanvasAnnotation(id: internalID)
        return internalID
    }

    /// 論理名（日本語）: 付箋テキスト即時キャッシュ反映関数
    /// 処理概要: キー入力ごとに app cache の付箋本文を更新し、Canvas の複数 surface へディスク保存を待たず反映します。
    ///
    /// - Parameters:
    ///   - id: 更新対象注釈の内部 ID。
    ///   - text: cache へ反映する付箋テキスト。
    func stageCanvasAnnotationText(id: String, text: String) {
        guard let loadedProject else { return }
        let baselineKey = canvasAnnotationBaselineKey(projectURL: loadedProject.fileURL, annotationID: id)
        if var draft = stagedCanvasAnnotationTextDrafts[baselineKey] {
            guard draft.text != text else { return }
            draft.text = text
            stagedCanvasAnnotationTextDrafts[baselineKey] = draft
            lastError = nil
            return
        }

        guard let snapshot = canvasAnnotationSnapshot(containing: id, in: loadedProject.project),
              let annotation = snapshot.annotations.first(where: { $0.internalID == id }),
              annotation.kind == .stickyNote,
              annotation.text != text
        else {
            return
        }
        stagedCanvasAnnotationTextDrafts[baselineKey] = StagedCanvasAnnotationTextDraft(
            target: snapshot.target,
            annotationID: id,
            baselineText: annotation.text,
            text: text
        )
        lastError = nil
    }

    /// 論理名（日本語）: 付箋テキスト更新関数
    /// 処理概要: 即時反映済みの cache を含めて指定付箋のプレーンテキストを、HTML / CSS を変更せず `.ogp` へ確定します。
    ///
    /// - Parameters:
    ///   - projectURL: debounce 開始時の保存対象 `.ogp`。現在別 project を表示していても元 project へ確定します。
    ///   - id: 更新対象注釈の内部 ID。
    ///   - text: 保存する付箋テキスト。
    func updateCanvasAnnotationText(projectURL: URL? = nil, id: String, text: String) {
        _ = persistCanvasAnnotation(projectURL: projectURL, id: id, mutation: { annotation in
            guard annotation.kind == .stickyNote, annotation.text != text else { return false }
            annotation.text = text
            return true
        }, status: nil)
    }

    /// 論理名（日本語）: キャンバス注釈フレーム更新関数
    /// 処理概要: 付箋または手書き注釈の配置矩形を `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - id: 更新対象注釈の内部 ID。
    ///   - frame: 保存するキャンバス座標フレーム。
    func updateCanvasAnnotationFrame(id: String, frame: OpenGraphiteCanvasAnnotationFrame) {
        _ = persistSelectedCanvasAnnotations({ annotations in
            guard let index = annotations.firstIndex(where: { $0.internalID == id }),
                  annotations[index].frame != frame
            else {
                return false
            }
            annotations[index].frame = frame
            return true
        }, status: "キャンバス注釈の位置を更新しました。")
    }

    /// 論理名（日本語）: 手書き部分消去適用関数
    /// 処理概要: ピクセル消しで分割・再配置した ink と完全に消えた ink を、現在の Chapter / Collection へ一度の atomic write で反映します。
    ///
    /// - Parameters:
    ///   - updatedAnnotations: 同じ内部 ID を保った部分消去後の ink 注釈。
    ///   - deletedIDs: 手書きが全て消えた ink 注釈の内部 ID。
    ///   - expectedAnnotations: gesture 開始時の保存先注釈。保存直前のディスク内容が異なる場合は外部更新との競合として中止します。
    func applyCanvasInkErasure(
        updatedAnnotations: [OpenGraphiteCanvasAnnotation],
        deletedIDs: [String],
        expectedAnnotations: [OpenGraphiteCanvasAnnotation]
    ) {
        guard selectedCanvasAnnotations == expectedAnnotations else { return }
        let currentInkIDs = Set(
            expectedAnnotations
                .filter { $0.kind == .ink }
                .map(\.internalID)
        )
        var validDeletedIDs = Set(deletedIDs).intersection(currentInkIDs)
        var replacementByID: [String: OpenGraphiteCanvasAnnotation] = [:]
        for var annotation in updatedAnnotations {
            guard annotation.kind == .ink,
                  currentInkIDs.contains(annotation.internalID)
            else {
                continue
            }
            annotation.strokes.removeAll { $0.points.isEmpty }
            guard !annotation.strokes.isEmpty else {
                validDeletedIDs.insert(annotation.internalID)
                replacementByID.removeValue(forKey: annotation.internalID)
                continue
            }
            guard !validDeletedIDs.contains(annotation.internalID) else { continue }
            replacementByID[annotation.internalID] = annotation
        }
        guard !validDeletedIDs.isEmpty || !replacementByID.isEmpty else { return }

        let affectedIDs = validDeletedIDs.union(replacementByID.keys)
        let expectedAnnotationsByID = Dictionary(
            uniqueKeysWithValues: expectedAnnotations
                .filter { affectedIDs.contains($0.internalID) }
                .map { ($0.internalID, $0) }
        )
        guard expectedAnnotationsByID.count == affectedIDs.count else { return }

        let status = replacementByID.isEmpty
            ? "手書きを消去しました。"
            : "手書きの一部を消去しました。"

        let didErase = persistSelectedCanvasAnnotations({ annotations in
            var changed = false
            annotations = annotations.compactMap { annotation in
                guard annotation.kind == .ink else { return annotation }
                if validDeletedIDs.contains(annotation.internalID) {
                    changed = true
                    return nil
                }
                guard let replacement = replacementByID[annotation.internalID],
                      replacement != annotation
                else {
                    return annotation
                }
                changed = true
                return replacement
            }
            return changed
        }, status: status, expectedDiskAnnotationsByID: expectedAnnotationsByID)
        guard didErase else { return }

        let survivingSelection = selectedCanvasAnnotationIDs.subtracting(validDeletedIDs)
        let orderedSurvivingIDs = selectedCanvasAnnotations
            .map(\.internalID)
            .filter { survivingSelection.contains($0) }
        let primaryID = selectedCanvasAnnotationID.flatMap {
            survivingSelection.contains($0) ? $0 : nil
        } ?? orderedSurvivingIDs.last
        applyCanvasAnnotationSelection(ids: Set(orderedSurvivingIDs), primaryID: primaryID)
    }

    /// 論理名（日本語）: キャンバス注釈削除関数
    /// 処理概要: 指定注釈を現在の Chapter / Collection から削除して `.ogp` へ保存します。
    ///
    /// - Parameter id: 削除対象注釈の内部 ID。
    func deleteCanvasAnnotation(id: String) {
        deleteCanvasAnnotations(ids: [id])
    }

    /// 論理名（日本語）: 複数キャンバス注釈削除関数
    /// 処理概要: なげわや個別操作で指定した注釈を、現在の Chapter / Collection から一度の `.ogp` 保存で削除します。
    ///
    /// - Parameter ids: 削除対象注釈の内部 ID 一覧。
    func deleteCanvasAnnotations(ids: [String]) {
        let availableIDs = Set(selectedCanvasAnnotations.map(\.internalID))
        let deletionIDs = Set(ids).intersection(availableIDs)
        guard !deletionIDs.isEmpty else { return }
        let didDelete = persistSelectedCanvasAnnotations({ annotations in
            let previousCount = annotations.count
            annotations.removeAll { deletionIDs.contains($0.internalID) }
            return annotations.count != previousCount
        }, status: "キャンバス注釈を \(deletionIDs.count) 件削除しました。")
        guard didDelete else { return }

        let remainingSelection = selectedCanvasAnnotationIDs.subtracting(deletionIDs)
        let orderedRemainingIDs = selectedCanvasAnnotations
            .map(\.internalID)
            .filter { remainingSelection.contains($0) }
        let primaryID = selectedCanvasAnnotationID.flatMap { remainingSelection.contains($0) ? $0 : nil }
            ?? orderedRemainingIDs.last
        applyCanvasAnnotationSelection(ids: Set(orderedRemainingIDs), primaryID: primaryID)
    }

    /// 論理名（日本語）: 選択キャンバス注釈削除関数
    /// 処理概要: 同時選択中の注釈をまとめて削除します。未選択時は何もしません。
    func deleteSelectedCanvasAnnotations() {
        deleteCanvasAnnotations(ids: Array(selectedCanvasAnnotationIDs))
    }

    /// 論理名（日本語）: 選択キャンバス注釈移動関数
    /// 処理概要: ドラッグした注釈が同時選択中なら選択全体を、未選択ならその注釈だけを安全な座標範囲内の共通 world 差分で移動します。
    ///
    /// - Parameters:
    ///   - anchorID: ドラッグ操作を開始した注釈 ID。
    ///   - translation: zoom 補正済みの Canvas world 移動量。選択全体の相対配置を保つ範囲へ clamp します。
    func moveSelectedCanvasAnnotations(anchorID: String, translation: CGSize) {
        guard translation.width.isFinite,
              translation.height.isFinite,
              translation != .zero,
              selectedCanvasAnnotations.contains(where: { $0.internalID == anchorID })
        else {
            return
        }

        if !selectedCanvasAnnotationIDs.contains(anchorID) {
            selectCanvasAnnotation(id: anchorID)
        }
        let movingIDs = selectedCanvasAnnotationIDs
        let movingAnnotations = selectedCanvasAnnotations.filter { movingIDs.contains($0.internalID) }
        let maximumCoordinate = OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude
        let minimumXTranslation = movingAnnotations.map { -maximumCoordinate - $0.frame.x }.max() ?? 0
        let maximumXTranslation = movingAnnotations.map { maximumCoordinate - $0.frame.x }.min() ?? 0
        let minimumYTranslation = movingAnnotations.map { -maximumCoordinate - $0.frame.y }.max() ?? 0
        let maximumYTranslation = movingAnnotations.map { maximumCoordinate - $0.frame.y }.min() ?? 0
        let effectiveX = min(max(Double(translation.width), minimumXTranslation), maximumXTranslation)
        let effectiveY = min(max(Double(translation.height), minimumYTranslation), maximumYTranslation)
        guard effectiveX != 0 || effectiveY != 0 else { return }

        let didMove = persistSelectedCanvasAnnotations({ annotations in
            var changed = false
            for index in annotations.indices where movingIDs.contains(annotations[index].internalID) {
                let currentFrame = annotations[index].frame
                let nextFrame = OpenGraphiteCanvasAnnotationFrame(
                    x: currentFrame.x + effectiveX,
                    y: currentFrame.y + effectiveY,
                    width: currentFrame.width,
                    height: currentFrame.height
                )
                guard nextFrame != currentFrame else { continue }
                annotations[index].frame = nextFrame
                changed = true
            }
            return changed
        }, status: "キャンバス注釈を \(movingIDs.count) 件移動しました。")
        if didMove {
            applyCanvasAnnotationSelection(ids: movingIDs, primaryID: selectedCanvasAnnotationID)
        }
    }

    /// 論理名（日本語）: 参照ID解決関数
    /// 処理概要: 入力中または保存済みtyped参照IDを、現在project内のHTMLカードと任意階層ノードへ解決します。
    ///
    /// - Parameter referenceID: `ogref:node` または `ogref:component-node`。
    /// - Returns: プレビューと編集同期に使う解決済み参照元。
    /// - Throws: project未読込または参照解決に失敗した場合のエラー。
    func resolveCanvasReferenceID(_ referenceID: String) throws -> OpenGraphiteResolvedCanvasReference {
        guard let loadedProject else {
            throw OpenGraphiteCanvasReferenceResolutionError.missingContainer
        }
        let context = try canvasReferenceResolutionContext(
            for: referenceID,
            in: loadedProject
        )
        if case let .resolved(target) = canvasReferenceResolutionCache[context.key] {
            return target
        }
        let target = try OpenGraphiteCanvasReferenceResolver.resolve(context.source)
        canvasReferenceResolutionCache[context.key] = .resolved(target)
        return target
    }

    /// 論理名（日本語）: キャンバス参照解決状態取得関数
    /// 処理概要: 現在のproject / page revisionに対するキャッシュ済み状態を、HTML読み込みなしで返します。
    ///
    /// - Parameter referenceID: `ogref:node`または`ogref:component-node`。
    /// - Returns: 未開始、読込中、解決済み、失敗のいずれか。
    func canvasReferenceResolutionState(
        for referenceID: String
    ) -> OpenGraphiteCanvasReferenceResolutionState {
        guard let loadedProject else {
            return .failed(OpenGraphiteCanvasReferenceResolutionError.missingContainer.localizedDescription)
        }
        do {
            let context = try canvasReferenceResolutionContext(
                for: referenceID,
                in: loadedProject
            )
            return canvasReferenceResolutionCache[context.key] ?? .idle
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 論理名（日本語）: キャンバス参照解決revision ID取得関数
    /// 処理概要: SwiftUI `task(id:)`がprojectまたはHTML revision変更時だけ再起動する安定IDを返します。
    ///
    /// - Parameter referenceID: 非同期解決対象のtyped参照ID。
    /// - Returns: project instance、参照ID、page URL、reload tokenを含む文字列。
    func canvasReferenceResolutionRequestID(for referenceID: String) -> String {
        guard let loadedProject,
              let context = try? canvasReferenceResolutionContext(
                  for: referenceID,
                  in: loadedProject
              )
        else {
            return "unresolved|\(loadedProject?.id.uuidString ?? "no-project")|\(referenceID)"
        }
        return [
            context.key.projectID.uuidString,
            context.key.referenceID,
            context.key.pageURL.absoluteString,
            String(context.key.reloadToken)
        ].joined(separator: "|")
    }

    /// 論理名（日本語）: キャンバス参照非同期準備関数
    /// 処理概要: SwiftUIのメインスレッドを塞がずにHTMLを読み、軽量参照解決結果をrevisionキャッシュへ公開します。
    ///
    /// - Parameter referenceID: 非同期解決対象のtyped参照ID。
    func prepareCanvasReferenceResolution(for referenceID: String) async {
        guard let loadedProject else { return }
        let context: (
            source: OpenGraphiteCanvasReferenceResolutionSource,
            key: CanvasReferenceResolutionCacheKey
        )
        do {
            context = try canvasReferenceResolutionContext(
                for: referenceID,
                in: loadedProject
            )
        } catch {
            return
        }
        switch canvasReferenceResolutionCache[context.key] {
        case .loading?, .resolved?, .failed?:
            return
        case nil, .idle?:
            break
        }

        canvasReferenceResolutionCache[context.key] = .loading
        let result = await Task.detached(priority: .userInitiated) {
            do {
                return OpenGraphiteCanvasReferenceResolutionState.resolved(
                    try OpenGraphiteCanvasReferenceResolver.resolve(context.source)
                )
            } catch {
                return OpenGraphiteCanvasReferenceResolutionState.failed(error.localizedDescription)
            }
        }.value

        guard let currentProject = self.loadedProject,
              let currentContext = try? canvasReferenceResolutionContext(
                  for: referenceID,
                  in: currentProject
              ),
              currentContext.key == context.key
        else {
            return
        }
        canvasReferenceResolutionCache[context.key] = result
    }

    /// 論理名（日本語）: キャンバス参照解決context生成関数
    /// 処理概要: manifestの軽量source解決とpage reload tokenから、background taskとキャッシュが共有するcontextを作ります。
    ///
    /// - Parameters:
    ///   - referenceID: typed参照ID。
    ///   - loadedProject: 解決対象のproject snapshot。
    /// - Returns: manifest解決済みsourceとrevisionキャッシュkey。
    /// - Throws: typed参照またはmanifest参照が不正な場合の解決エラー。
    private func canvasReferenceResolutionContext(
        for referenceID: String,
        in loadedProject: LoadedOpenGraphiteProject
    ) throws -> (
        source: OpenGraphiteCanvasReferenceResolutionSource,
        key: CanvasReferenceResolutionCacheKey
    ) {
        let source = try OpenGraphiteCanvasReferenceResolver.source(
            referenceID,
            in: loadedProject
        )
        let key = CanvasReferenceResolutionCacheKey(
            projectID: loadedProject.id,
            referenceID: source.referenceID,
            pageURL: source.pageURL.standardizedFileURL,
            reloadToken: reloadToken(for: source.pageURL)
        )
        return (source, key)
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照追加関数
    /// 処理概要: 解決可能なnode参照を右クリックworld座標へ作成し、選択Chapter / Collection直下の`.ogp`へ保存します。
    ///
    /// - Parameters:
    ///   - referenceID: 参照元ノードのtyped参照ID。
    ///   - point: 配置先のキャンバスworld座標。
    /// - Returns: 追加した参照配置の内部ID。保存できない場合は`nil`。
    @discardableResult
    func addCanvasReference(referenceID: String, at point: CGPoint) -> String? {
        guard point.x.isFinite, point.y.isFinite,
              let target = try? resolveCanvasReferenceID(referenceID)
        else {
            return nil
        }
        let internalID = UUID().uuidString.lowercased()
        let reference = OpenGraphiteCanvasReference(
            internalID: internalID,
            referenceID: target.referenceID,
            x: Double(point.x),
            y: Double(point.y)
        )
        guard persistSelectedCanvasReferences({ references in
            references.append(reference)
            return true
        }, status: "参照オブジェクトをキャンバスへ追加しました。") else {
            return nil
        }
        selectCanvasReference(id: internalID)
        return internalID
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照位置更新関数
    /// 処理概要: ドラッグ終了位置をworld座標へ戻し、選択コンテナの参照配置だけを`.ogp`へ保存します。
    ///
    /// - Parameters:
    ///   - id: 更新対象参照配置の内部ID。
    ///   - x: 新しいworld X座標。
    ///   - y: 新しいworld Y座標。
    func updateCanvasReferencePosition(id: String, x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return }
        _ = persistSelectedCanvasReferences({ references in
            guard let index = references.firstIndex(where: { $0.internalID == id }) else {
                return false
            }
            let next = OpenGraphiteCanvasReference(
                internalID: references[index].internalID,
                referenceID: references[index].referenceID,
                x: x,
                y: y,
                width: references[index].width,
                height: references[index].height
            )
            guard next != references[index] else { return false }
            references[index] = next
            return true
        }, status: "参照オブジェクトの位置を更新しました。")
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照削除関数
    /// 処理概要: 指定参照配置をChapter / Collection直下から削除し、参照元HTMLノードは変更しません。
    ///
    /// - Parameter id: 削除対象参照配置の内部ID。
    func deleteCanvasReference(id: String) {
        let wasSelected = selectedCanvasReferenceID == id
        let didDelete = persistSelectedCanvasReferences({ references in
            let previousCount = references.count
            references.removeAll { $0.internalID == id }
            return references.count != previousCount
        }, status: "参照オブジェクトをキャンバスから削除しました。")
        if didDelete, wasSelected {
            clearCanvasReferenceSelection()
            selectedNodeID = nil
            nodes = []
            prepareHistoryForSelectedPage()
        }
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照選択関数
    /// 処理概要: 保存済み配置を参照元HTMLノードへ解決し、キャンバスを切り替えずInspectorとWeb編集の対象にします。
    ///
    /// - Parameter id: 選択する参照配置の内部ID。`nil`または不明IDでは選択を解除します。
    func selectCanvasReference(id: String?) {
        guard let id,
              let reference = selectedCanvasReferences.first(where: { $0.internalID == id }),
              let target = try? resolveCanvasReferenceID(reference.referenceID)
        else {
            clearCanvasReferenceSelection()
            return
        }

        selectedProjectResource = nil
        selectedCanvasAnnotationID = nil
        switch selectedCanvasSegment {
        case .pages:
            selectedPageID = nil
            selectedPageInternalID = nil
        case .components:
            selectedComponentPageID = nil
            selectedComponentPageInternalID = nil
        }
        selectedCanvasReferenceID = id
        selectedCanvasReferenceTarget = target
        nodes = []
        selectNode(id: target.node.id)
        statusMessage = "\(target.node.id) の参照オブジェクトを編集しています。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: キャンバス注釈選択関数
    /// 処理概要: 現在の Canvas に含まれる注釈を選択し、HTML page / node 選択を解除します。
    ///
    /// - Parameter id: 選択する注釈内部 ID。`nil` または不明な ID の場合は注釈選択を解除します。
    func selectCanvasAnnotation(id: String?) {
        selectCanvasAnnotations(ids: id.map { [$0] } ?? [])
    }

    /// 論理名（日本語）: 複数キャンバス注釈選択関数
    /// 処理概要: なげわが返した注釈 ID を現在の Canvas 配列順で同時選択し、HTML page / node 選択と排他的にします。
    ///
    /// - Parameter ids: 選択候補の注釈内部 ID 一覧。空または不明 ID だけの場合は注釈選択を解除します。
    func selectCanvasAnnotations(ids: [String]) {
        let requestedIDs = Set(ids)
        let orderedIDs = selectedCanvasAnnotations
            .map(\.internalID)
            .filter { requestedIDs.contains($0) }
        guard !orderedIDs.isEmpty else {
            applyCanvasAnnotationSelection(ids: [], primaryID: nil)
            statusMessage = "キャンバス注釈の選択を解除しました。"
            return
        }

        selectedProjectResource = nil
        clearCanvasReferenceSelection()
        selectedNodeID = nil
        switch selectedCanvasSegment {
        case .pages:
            selectedPageID = nil
            selectedPageInternalID = nil
        case .components:
            selectedComponentPageID = nil
            selectedComponentPageInternalID = nil
        }
        nodes = []
        applyCanvasAnnotationSelection(ids: Set(orderedIDs), primaryID: orderedIDs.last)
        statusMessage = orderedIDs.count == 1
            ? "キャンバス注釈を選択しました。"
            : "キャンバス注釈を \(orderedIDs.count) 件選択しました。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: キャンバス注釈選択状態適用関数
    /// 処理概要: primary ID の `didSet` による単一選択同期を一時停止し、複数選択集合と primary を原子的に更新します。
    ///
    /// - Parameters:
    ///   - ids: 同時選択 ID 集合。
    ///   - primaryID: コピーなど単一対象操作で優先する注釈 ID。
    private func applyCanvasAnnotationSelection(ids: Set<String>, primaryID: String?) {
        isApplyingCanvasAnnotationMultiSelection = true
        defer { isApplyingCanvasAnnotationMultiSelection = false }
        selectedCanvasAnnotationIDs = ids
        selectedCanvasAnnotationID = primaryID.flatMap { ids.contains($0) ? $0 : nil }
    }

    /// 論理名（日本語）: キャンバス選択解除関数
    /// 処理概要: 空のキャンバス操作に応じて page、node、注釈の選択をまとめて解除します。
    func clearCanvasSelection() {
        clearCanvasReferenceSelection()
        switch selectedCanvasSegment {
        case .pages:
            selectedPageID = nil
            selectedPageInternalID = nil
        case .components:
            selectedComponentPageID = nil
            selectedComponentPageInternalID = nil
        }
        selectedNodeID = nil
        selectedCanvasAnnotationID = nil
        nodes = []
        statusMessage = "キャンバス選択を解除しました。"
        prepareHistoryForSelectedPage()
    }

    /// 論理名（日本語）: キャンバスオブジェクト参照選択解除関数
    /// 処理概要: 参照配置と解決済み参照元を同時に破棄し、通常カード選択へ戻せる状態にします。
    private func clearCanvasReferenceSelection() {
        selectedCanvasReferenceID = nil
        selectedCanvasReferenceTarget = nil
    }

    /// 論理名（日本語）: 選択キャンバス参照保存関数
    /// 処理概要: 最新`.ogp`を再読込し、現在表示中Chapter / Collectionの`references[]`だけへ変更をatomic writeして統合履歴へ記録します。
    ///
    /// - Parameters:
    ///   - mutation: 参照配列を変更し、保存が必要なら`true`を返す処理。
    ///   - status: 保存成功時の状態メッセージ。
    /// - Returns: `.ogp`を更新できた場合は`true`。
    @discardableResult
    private func persistSelectedCanvasReferences(
        _ mutation: (inout [OpenGraphiteCanvasReference]) -> Bool,
        status: String
    ) -> Bool {
        guard let currentProject = loadedProject,
              let historyTarget = selectedCanvasReferenceHistoryTarget(in: currentProject.project)
        else {
            return false
        }

        var targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: currentProject.fileURL)
        } catch {
            lastError = ".ogp の保存前確認に失敗しました: \(error.localizedDescription)"
            return false
        }

        let didChange: Bool
        let previousReferences: [OpenGraphiteCanvasReference]
        switch historyTarget.segment {
        case .pages:
            guard let index = targetProject.project.chapters.firstIndex(where: {
                $0.internalID == historyTarget.containerInternalID
            }) else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousReferences = targetProject.project.chapters[index].references
            didChange = mutation(&targetProject.project.chapters[index].references)
        case .components:
            guard let index = targetProject.project.collections.firstIndex(where: {
                $0.internalID == historyTarget.containerInternalID
            }) else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousReferences = targetProject.project.collections[index].references
            didChange = mutation(&targetProject.project.collections[index].references)
        }
        guard didChange else {
            if targetProject.project != currentProject.project
                || targetProject.rootURL != currentProject.rootURL {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
            }
            return false
        }

        do {
            targetProject.project = targetProject.project.normalizedInternalIDs()
            try writeProjectManifest(targetProject.project, to: targetProject.fileURL)
            loadedProject = targetProject
            reconcileCanvasReferenceSelectionAfterManifestChange()
            let nextReferences = canvasReferences(for: historyTarget, in: targetProject.project) ?? []
            recordCanvasReferenceHistory(
                projectURL: targetProject.fileURL,
                target: historyTarget,
                previousReferences: previousReferences,
                nextReferences: nextReferences
            )
            lastError = nil
            statusMessage = status
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: Manifest変更後参照選択整合関数
    /// 処理概要: 選択配置が最新manifestにも存在し参照元を解決できる場合だけ、編集対象を新しいprojectへ接続し直します。
    private func reconcileCanvasReferenceSelectionAfterManifestChange() {
        guard let selectedCanvasReferenceID,
              let reference = selectedCanvasReferences.first(where: {
                  $0.internalID == selectedCanvasReferenceID
              }),
              let target = try? resolveCanvasReferenceID(reference.referenceID)
        else {
            clearCanvasReferenceSelection()
            return
        }
        selectedCanvasReferenceTarget = target
    }

    /// 論理名（日本語）: 選択Canvas注釈保存関数
    /// 処理概要: 現在表示中の Chapter / Collection の注釈配列だけを変更し、project manifest を atomic write します。
    ///
    /// - Parameters:
    ///   - mutation: 注釈配列を変更し、保存が必要な場合に `true` を返す処理。
    ///   - status: 保存成功時に表示する任意のステータス文言。
    ///   - expectedDiskAnnotationsByID: 指定時は保存直前に `.ogp` を再読込し、更新対象注釈が一致する場合だけ最新 manifest へ mutation を適用します。
    /// - Returns: `.ogp` を更新できた場合は `true`。
    @discardableResult
    private func persistSelectedCanvasAnnotations(
        _ mutation: (inout [OpenGraphiteCanvasAnnotation]) -> Bool,
        status: String?,
        expectedDiskAnnotationsByID: [String: OpenGraphiteCanvasAnnotation]? = nil
    ) -> Bool {
        guard let currentProject = loadedProject,
              let historyTarget = selectedCanvasAnnotationHistoryTarget(in: currentProject.project)
        else {
            return false
        }
        var targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: currentProject.fileURL)
        } catch {
            lastError = ".ogp の保存前確認に失敗しました: \(error.localizedDescription)"
            return false
        }

        let didChange: Bool
        let previousAnnotations: [OpenGraphiteCanvasAnnotation]
        switch historyTarget.segment {
        case .pages:
            let chapterIndex = targetProject.project.chapters.firstIndex {
                $0.internalID == historyTarget.containerInternalID
            }
            guard let chapterIndex else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousAnnotations = targetProject.project.chapters[chapterIndex].annotations
            if let expectedDiskAnnotationsByID,
               !annotationsMatchExpectedValues(
                    targetProject.project.chapters[chapterIndex].annotations,
                    expectedByID: expectedDiskAnnotationsByID
               ) {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                statusMessage = ".ogp の外部変更を検出したため、手書きの消去を中止しました。もう一度操作してください。"
                return false
            }
            didChange = mutation(&targetProject.project.chapters[chapterIndex].annotations)
        case .components:
            let collectionIndex = targetProject.project.collections.firstIndex {
                $0.internalID == historyTarget.containerInternalID
            }
            guard let collectionIndex else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousAnnotations = targetProject.project.collections[collectionIndex].annotations
            if let expectedDiskAnnotationsByID,
               !annotationsMatchExpectedValues(
                    targetProject.project.collections[collectionIndex].annotations,
                    expectedByID: expectedDiskAnnotationsByID
               ) {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                statusMessage = ".ogp の外部変更を検出したため、手書きの消去を中止しました。もう一度操作してください。"
                return false
            }
            didChange = mutation(&targetProject.project.collections[collectionIndex].annotations)
        }
        guard didChange else {
            if targetProject.project != currentProject.project
                || targetProject.rootURL != currentProject.rootURL {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
            }
            return false
        }

        do {
            targetProject.project = targetProject.project.normalizedInternalIDs()
            try writeProjectManifest(targetProject.project, to: targetProject.fileURL)
            removeMissingStagedCanvasAnnotationTextDrafts(
                from: targetProject.project,
                projectURL: targetProject.fileURL
            )
            self.loadedProject = targetProject
            reconcileCanvasAnnotationSelectionAfterManifestChange()
            let nextAnnotations = canvasAnnotations(for: historyTarget, in: targetProject.project) ?? []
            recordCanvasAnnotationHistory(
                projectURL: targetProject.fileURL,
                target: historyTarget,
                previousAnnotations: previousAnnotations,
                nextAnnotations: nextAnnotations
            )
            lastError = nil
            if let status {
                statusMessage = status
            }
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: 選択Canvasガイド保存関数
    /// 処理概要: 最新 `.ogp` を再読込し、現在表示中の Chapter / Collection のガイド配列だけを atomic write して統合履歴へ記録します。
    ///
    /// - Parameters:
    ///   - mutation: ガイド配列を変更し、保存が必要な場合に `true` を返す処理。
    ///   - status: 保存成功時に表示するステータス文言。
    /// - Returns: `.ogp` を更新できた場合は `true`。
    @discardableResult
    private func persistSelectedCanvasGuides(
        _ mutation: (inout [OpenGraphiteCanvasGuide]) -> Bool,
        status: String
    ) -> Bool {
        guard let currentProject = loadedProject,
              let historyTarget = selectedCanvasGuideHistoryTarget(in: currentProject.project)
        else {
            return false
        }

        var targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: currentProject.fileURL)
        } catch {
            lastError = ".ogp の保存前確認に失敗しました: \(error.localizedDescription)"
            return false
        }

        let didChange: Bool
        let previousGuides: [OpenGraphiteCanvasGuide]
        switch historyTarget.segment {
        case .pages:
            guard let chapterIndex = targetProject.project.chapters.firstIndex(where: {
                $0.internalID == historyTarget.containerInternalID
            }) else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousGuides = targetProject.project.chapters[chapterIndex].guides
            didChange = mutation(&targetProject.project.chapters[chapterIndex].guides)
        case .components:
            guard let collectionIndex = targetProject.project.collections.firstIndex(where: {
                $0.internalID == historyTarget.containerInternalID
            }) else {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
                return false
            }
            previousGuides = targetProject.project.collections[collectionIndex].guides
            didChange = mutation(&targetProject.project.collections[collectionIndex].guides)
        }
        guard didChange else {
            if targetProject.project != currentProject.project
                || targetProject.rootURL != currentProject.rootURL {
                synchronizeAfterCanvasManifestDiskChange(targetProject)
            }
            return false
        }

        do {
            targetProject.project = targetProject.project.normalizedInternalIDs()
            try writeProjectManifest(targetProject.project, to: targetProject.fileURL)
            removeMissingStagedCanvasAnnotationTextDrafts(
                from: targetProject.project,
                projectURL: targetProject.fileURL
            )
            self.loadedProject = targetProject
            reconcileCanvasAnnotationSelectionAfterManifestChange()
            let nextGuides = canvasGuides(for: historyTarget, in: targetProject.project) ?? []
            recordCanvasGuideHistory(
                projectURL: targetProject.fileURL,
                target: historyTarget,
                previousGuides: previousGuides,
                nextGuides: nextGuides
            )
            lastError = nil
            statusMessage = status
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: 保存前注釈一致判定関数
    /// 処理概要: 最新 `.ogp` の対象 container 内で、今回更新する注釈 ID が gesture 開始時の値から変わっていないことを確認します。
    ///
    /// - Parameters:
    ///   - annotations: 保存直前にディスクから読み込んだ注釈配列。
    ///   - expectedByID: gesture 開始時の更新対象注釈を ID で引く辞書。
    /// - Returns: 全ての対象 ID が同じ値で存在する場合は `true`。
    private func annotationsMatchExpectedValues(
        _ annotations: [OpenGraphiteCanvasAnnotation],
        expectedByID: [String: OpenGraphiteCanvasAnnotation]
    ) -> Bool {
        let currentByID = Dictionary(uniqueKeysWithValues: annotations.map { ($0.internalID, $0) })
        return expectedByID.allSatisfy { id, expected in
            currentByID[id] == expected
        }
    }

    /// 論理名（日本語）: キャンバスManifest変更同期関数
    /// 処理概要: 注釈またはガイドの保存直前に読み込んだ最新 manifest を表示へ反映し、削除済み注釈の未確定本文だけを破棄します。
    ///
    /// - Parameter project: ディスクから読み込んだ最新 project。
    private func synchronizeAfterCanvasManifestDiskChange(
        _ project: LoadedOpenGraphiteProject
    ) {
        removeMissingStagedCanvasAnnotationTextDrafts(
            from: project.project,
            projectURL: project.fileURL
        )
        loadedProject = project
        reconcileCanvasAnnotationSelectionAfterManifestChange()
        reconcileCanvasReferenceSelectionAfterManifestChange()
        lastError = nil
        restartExternalProjectMonitoring(force: true)
    }

    /// 論理名（日本語）: 付箋本文保存競合同期関数
    /// 処理概要: 入力開始後に同じ付箋本文が外部変更された場合、local draft の上書きを中止して最新 manifest と履歴可否を同期します。
    ///
    /// - Parameters:
    ///   - project: ディスクから読み込んだ最新 project。
    ///   - baselineKey: 破棄する付箋本文draftのキー。
    private func synchronizeAfterCanvasAnnotationTextConflict(
        _ project: LoadedOpenGraphiteProject,
        baselineKey: String
    ) {
        stagedCanvasAnnotationTextDrafts.removeValue(forKey: baselineKey)
        if loadedProject?.fileURL.standardizedFileURL == project.fileURL.standardizedFileURL {
            synchronizeAfterCanvasAnnotationHistoryConflict(with: project)
        }
        lastError = nil
        statusMessage = ".ogp で同じ付箋本文が外部変更されたため、入力内容の保存を中止しました。"
    }

    /// 論理名（日本語）: ID指定キャンバス注釈保存関数
    /// 処理概要: debounce 中に表示キャンバスが切り替わっても、project 全体で一意な注釈 ID から元の Chapter / Collection を解決して保存します。
    ///
    /// - Parameters:
    ///   - projectURL: 保存対象 project URL。未指定時は現在読み込み中の project。
    ///   - id: 更新対象注釈の project 内部 ID。
    ///   - mutation: 対象注釈を変更し、保存が必要な場合に `true` を返す処理。
    ///   - status: 保存成功時に表示する任意のステータス文言。
    /// - Returns: `.ogp` を更新できた場合は `true`。
    @discardableResult
    private func persistCanvasAnnotation(
        projectURL: URL?,
        id: String,
        mutation: (inout OpenGraphiteCanvasAnnotation) -> Bool,
        status: String?
    ) -> Bool {
        guard let targetURL = projectURL?.standardizedFileURL
            ?? loadedProject?.fileURL.standardizedFileURL
        else {
            return false
        }
        var targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: targetURL)
        } catch {
            lastError = ".ogp の読み込みに失敗しました: \(error.localizedDescription)"
            return false
        }

        let baselineKey = canvasAnnotationBaselineKey(projectURL: targetProject.fileURL, annotationID: id)
        let stagedDraft = stagedCanvasAnnotationTextDrafts[baselineKey]
        let historySnapshot: CanvasAnnotationHistorySnapshot
        if let stagedDraft {
            guard let currentAnnotations = canvasAnnotations(
                for: stagedDraft.target,
                in: targetProject.project
            ),
            let currentAnnotation = currentAnnotations.first(where: { $0.internalID == id }),
            currentAnnotation.kind == .stickyNote,
            currentAnnotation.text == stagedDraft.baselineText
            else {
                synchronizeAfterCanvasAnnotationTextConflict(
                    targetProject,
                    baselineKey: baselineKey
                )
                return false
            }
            historySnapshot = CanvasAnnotationHistorySnapshot(
                target: stagedDraft.target,
                annotations: currentAnnotations
            )
        } else {
            guard let snapshot = canvasAnnotationSnapshot(containing: id, in: targetProject.project) else {
                return false
            }
            historySnapshot = snapshot
        }

        let didChange = mutateCanvasAnnotation(
            in: &targetProject.project,
            target: historySnapshot.target,
            id: id,
            mutation: mutation
        )
        let isCurrentProject = loadedProject?.fileURL.standardizedFileURL
            == targetProject.fileURL.standardizedFileURL
        guard didChange else {
            if isCurrentProject {
                self.loadedProject = targetProject
                reconcileCanvasAnnotationSelectionAfterManifestChange()
                restartExternalProjectMonitoring(force: true)
            }
            stagedCanvasAnnotationTextDrafts.removeValue(forKey: baselineKey)
            lastError = nil
            return false
        }

        do {
            targetProject.project = targetProject.project.normalizedInternalIDs()
            try writeProjectManifest(targetProject.project, to: targetProject.fileURL)
            if isCurrentProject {
                self.loadedProject = targetProject
                reconcileCanvasAnnotationSelectionAfterManifestChange()
                restartExternalProjectMonitoring(force: true)
            }
            stagedCanvasAnnotationTextDrafts.removeValue(forKey: baselineKey)
            if let nextAnnotations = canvasAnnotations(for: historySnapshot.target, in: targetProject.project),
               isCurrentProject {
                recordCanvasAnnotationHistory(
                    projectURL: targetProject.fileURL,
                    target: historySnapshot.target,
                    previousAnnotations: historySnapshot.annotations,
                    nextAnnotations: nextAnnotations
                )
            }
            lastError = nil
            if let status {
                statusMessage = status
            }
            return true
        } catch {
            lastError = ".ogp の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: Project内キャンバス注釈変更関数
    /// 処理概要: 履歴対象で固定した Chapter / Collection 内の注釈だけへ、指定の変更を一度だけ適用します。
    ///
    /// - Parameters:
    ///   - project: 変更対象 project。
    ///   - target: 変更対象の Chapter / Collection。
    ///   - id: 注釈内部 ID。
    ///   - mutation: 対象注釈へ適用する変更。
    /// - Returns: 対象が見つかり変更された場合は `true`。
    private func mutateCanvasAnnotation(
        in project: inout OpenGraphiteProject,
        target: CanvasAnnotationHistoryTarget,
        id: String,
        mutation: (inout OpenGraphiteCanvasAnnotation) -> Bool
    ) -> Bool {
        switch target.segment {
        case .pages:
            guard let chapterIndex = project.chapters.firstIndex(where: {
                $0.internalID == target.containerInternalID
            }),
            let annotationIndex = project.chapters[chapterIndex].annotations.firstIndex(where: {
                $0.internalID == id
            }) else {
                return false
            }
            return mutation(&project.chapters[chapterIndex].annotations[annotationIndex])
        case .components:
            guard let collectionIndex = project.collections.firstIndex(where: {
                $0.internalID == target.containerInternalID
            }),
            let annotationIndex = project.collections[collectionIndex].annotations.firstIndex(where: {
                $0.internalID == id
            }) else {
                return false
            }
            return mutation(&project.collections[collectionIndex].annotations[annotationIndex])
        }
    }

    /// 論理名（日本語）: 注釈包含コンテナ履歴取得関数
    /// 処理概要: project 内で指定注釈を含む Chapter / Collection と注釈配列を履歴用に取得します。
    ///
    /// - Parameters:
    ///   - id: 検索する注釈内部 ID。
    ///   - project: 検索対象 project。
    /// - Returns: 注釈を含むコンテナのスナップショット。見つからない場合は `nil`。
    private func canvasAnnotationSnapshot(
        containing id: String,
        in project: OpenGraphiteProject
    ) -> CanvasAnnotationHistorySnapshot? {
        if let chapter = project.chapters.first(where: { chapter in
            chapter.annotations.contains { $0.internalID == id }
        }) {
            return CanvasAnnotationHistorySnapshot(
                target: CanvasAnnotationHistoryTarget(
                    segment: .pages,
                    containerInternalID: chapter.internalID
                ),
                annotations: chapter.annotations
            )
        }
        if let collection = project.collections.first(where: { collection in
            collection.annotations.contains { $0.internalID == id }
        }) {
            return CanvasAnnotationHistorySnapshot(
                target: CanvasAnnotationHistoryTarget(
                    segment: .components,
                    containerInternalID: collection.internalID
                ),
                annotations: collection.annotations
            )
        }
        return nil
    }

    /// 論理名（日本語）: 選択キャンバス注釈履歴対象取得関数
    /// 処理概要: 現在の segment と選択containerを、最新manifestへrebaseできる固定targetへ変換します。
    ///
    /// - Parameter project: 選択解決の基準にする現在の project。
    /// - Returns: 選択中 Chapter / Collection。対象がなければ`nil`。
    private func selectedCanvasAnnotationHistoryTarget(
        in project: OpenGraphiteProject
    ) -> CanvasAnnotationHistoryTarget? {
        switch selectedCanvasSegment {
        case .pages:
            let containerInternalID = selectedChapterInternalID
                ?? project.chapters.first?.internalID
            guard let containerInternalID,
                  project.chapters.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasAnnotationHistoryTarget(
                segment: .pages,
                containerInternalID: containerInternalID
            )
        case .components:
            let containerInternalID = selectedCollectionInternalID
                ?? project.collections.first?.internalID
            guard let containerInternalID,
                  project.collections.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasAnnotationHistoryTarget(
                segment: .components,
                containerInternalID: containerInternalID
            )
        }
    }

    /// 論理名（日本語）: コンテナ注釈配列取得関数
    /// 処理概要: 履歴対象が示す Chapter / Collection の注釈配列を取得します。
    ///
    /// - Parameters:
    ///   - target: 履歴対象コンテナ。
    ///   - project: 取得対象 project。
    /// - Returns: 対象コンテナの注釈配列。対象が存在しない場合は `nil`。
    private func canvasAnnotations(
        for target: CanvasAnnotationHistoryTarget,
        in project: OpenGraphiteProject
    ) -> [OpenGraphiteCanvasAnnotation]? {
        switch target.segment {
        case .pages:
            return project.chapters.first { $0.internalID == target.containerInternalID }?.annotations
        case .components:
            return project.collections.first { $0.internalID == target.containerInternalID }?.annotations
        }
    }

    /// 論理名（日本語）: 選択キャンバスガイド履歴対象取得関数
    /// 処理概要: 現在の segment と選択 container を、最新 manifest へ rebase できるガイド履歴対象へ変換します。
    ///
    /// - Parameter project: 選択解決の基準にする現在の project。
    /// - Returns: 選択中 Chapter / Collection。対象がなければ `nil`。
    private func selectedCanvasGuideHistoryTarget(
        in project: OpenGraphiteProject
    ) -> CanvasGuideHistoryTarget? {
        switch selectedCanvasSegment {
        case .pages:
            let containerInternalID = selectedChapterInternalID
                ?? project.chapters.first?.internalID
            guard let containerInternalID,
                  project.chapters.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasGuideHistoryTarget(
                segment: .pages,
                containerInternalID: containerInternalID
            )
        case .components:
            let containerInternalID = selectedCollectionInternalID
                ?? project.collections.first?.internalID
            guard let containerInternalID,
                  project.collections.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasGuideHistoryTarget(
                segment: .components,
                containerInternalID: containerInternalID
            )
        }
    }

    /// 論理名（日本語）: コンテナガイド配列取得関数
    /// 処理概要: 履歴対象が示す Chapter / Collection のガイド配列を取得します。
    ///
    /// - Parameters:
    ///   - target: ガイド履歴対象コンテナ。
    ///   - project: 取得対象 project。
    /// - Returns: 対象コンテナのガイド配列。対象が存在しない場合は `nil`。
    private func canvasGuides(
        for target: CanvasGuideHistoryTarget,
        in project: OpenGraphiteProject
    ) -> [OpenGraphiteCanvasGuide]? {
        switch target.segment {
        case .pages:
            return project.chapters.first { $0.internalID == target.containerInternalID }?.guides
        case .components:
            return project.collections.first { $0.internalID == target.containerInternalID }?.guides
        }
    }

    /// 論理名（日本語）: 選択キャンバス参照履歴対象取得関数
    /// 処理概要: 現在のsegmentと選択containerを、最新manifestへrebaseできる参照配置履歴対象へ変換します。
    ///
    /// - Parameter project: 選択解決の基準にする現在のproject。
    /// - Returns: 選択中Chapter / Collection。対象がなければ`nil`。
    private func selectedCanvasReferenceHistoryTarget(
        in project: OpenGraphiteProject
    ) -> CanvasReferenceHistoryTarget? {
        switch selectedCanvasSegment {
        case .pages:
            let containerInternalID = selectedChapterInternalID
                ?? project.chapters.first?.internalID
            guard let containerInternalID,
                  project.chapters.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasReferenceHistoryTarget(
                segment: .pages,
                containerInternalID: containerInternalID
            )
        case .components:
            let containerInternalID = selectedCollectionInternalID
                ?? project.collections.first?.internalID
            guard let containerInternalID,
                  project.collections.contains(where: { $0.internalID == containerInternalID })
            else {
                return nil
            }
            return CanvasReferenceHistoryTarget(
                segment: .components,
                containerInternalID: containerInternalID
            )
        }
    }

    /// 論理名（日本語）: コンテナ参照配置配列取得関数
    /// 処理概要: 履歴対象が示すChapter / Collectionの参照配置配列を取得します。
    ///
    /// - Parameters:
    ///   - target: 参照配置履歴対象container。
    ///   - project: 取得対象project。
    /// - Returns: 対象containerの参照配置配列。対象が存在しない場合は`nil`。
    private func canvasReferences(
        for target: CanvasReferenceHistoryTarget,
        in project: OpenGraphiteProject
    ) -> [OpenGraphiteCanvasReference]? {
        switch target.segment {
        case .pages:
            return project.chapters.first { $0.internalID == target.containerInternalID }?.references
        case .components:
            return project.collections.first { $0.internalID == target.containerInternalID }?.references
        }
    }

    /// 論理名（日本語）: 消滅付箋Draft破棄関数
    /// 処理概要: 最新manifestに存在しない注釈の未確定本文だけを対象projectのoverlayから除外します。
    ///
    /// - Parameters:
    ///   - project: 最新の project 定義。
    ///   - projectURL: draftを分離する `.ogp` URL。
    private func removeMissingStagedCanvasAnnotationTextDrafts(
        from project: OpenGraphiteProject,
        projectURL: URL
    ) {
        let availableAnnotationIDs = Set(
            project.chapters.flatMap(\.annotations).map(\.internalID)
                + project.collections.flatMap(\.annotations).map(\.internalID)
        )
        let projectKeyPrefix = "\(projectURL.standardizedFileURL.path)\u{0}"
        let keysToRemove = stagedCanvasAnnotationTextDrafts.compactMap { key, draft in
            key.hasPrefix(projectKeyPrefix) && !availableAnnotationIDs.contains(draft.annotationID)
                ? key
                : nil
        }
        for key in keysToRemove {
            stagedCanvasAnnotationTextDrafts.removeValue(forKey: key)
        }
    }

    /// 論理名（日本語）: 注釈入力基準キー生成関数
    /// 処理概要: debounce 中の付箋本文について project と注釈を一意に結ぶ履歴基準キーを生成します。
    ///
    /// - Parameters:
    ///   - projectURL: 保存対象 `.ogp` URL。
    ///   - annotationID: 注釈内部 ID。
    /// - Returns: project URL と注釈 ID を連結したキー。
    private func canvasAnnotationBaselineKey(projectURL: URL, annotationID: String) -> String {
        "\(projectURL.standardizedFileURL.path)\u{0}\(annotationID)"
    }

    /// 論理名（日本語）: 選択ページキャンバス配置更新関数
    /// 処理概要: 既存 preview Mock State を維持し、キャンバス配置だけを `.ogp` へ保存します。
    ///
    /// - Parameters:
    ///   - x: キャンバス上の X 座標。
    ///   - y: キャンバス上の Y 座標。
    ///   - width: ページプレビュー幅。0 より大きい値が必要です。
    ///   - height: ページプレビュー高さ。0 より大きい値が必要です。
    ///   - name: フロー解決で利用する配置名。空白のみの場合は空文字として保存します。
    func updateSelectedPageCanvas(x: Double, y: Double, width: Double, height: Double, name: String) {
        updateSelectedPageCanvas(
            x: x,
            y: y,
            width: width,
            height: height,
            name: name,
            previewContext: selectedPage?.canvas.previewContext ?? .empty
        )
    }

    /// 論理名（日本語）: HTML Document Context更新関数
    /// 処理概要: 選択中 HTML の `<html>` document attribute と binding metadata を正本 HTML へ保存します。
    ///
    /// - Parameter context: 保存する HTML document context。
    func updateSelectedHTMLDocumentContext(_ context: OpenGraphiteHTMLDocumentContext) {
        guard let target = currentHTMLSyncTarget() else { return }
        guard let diskHTML = readHTMLFromDisk(at: target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let mutation = OpenGraphiteHTMLDocument(html: diskHTML)
            .settingHTMLDocumentContext(context, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = mutation.diagnostics.first(where: { $0.severity == .error })?.message
                ?? "HTML document attributes の保存に失敗しました。"
            return
        }
        guard mutation.html != diskHTML else { return }
        guard syncHTML(mutation.html, target: target) else { return }
        incrementReloadToken(for: target.htmlURL)
        lastError = nil
        statusMessage = "\(target.htmlURL.lastPathComponent) の HTML document attributes を更新しました。"
    }

    /// 論理名（日本語）: 選択ページi18n推奨設定適用関数
    /// 処理概要: 選択中 HTML の実装資源へ推奨 i18n runtime と locale JSON を作成・更新します。
    func recommendI18nForSelectedPage() {
        guard let loadedProject,
              let pageID = selectedPageReferenceID()
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.recommendI18n(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                locales: ["ja", "eng"]
            )
            if let selectedPageURL {
                incrementReloadToken(for: selectedPageURL)
                refreshPageFromDiskIfChanged(at: selectedPageURL)
            }
            lastError = nil
            statusMessage = result.updated
                ? "i18n runtime と locale JSON を実装資源へ更新しました。"
                : "i18n runtime と locale JSON は既に推奨設定です。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = "i18n 推奨設定の適用に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Project i18n推奨設定適用関数
    /// 処理概要: Project 内の Pages HTML へ推奨 i18n runtime 参照を用意し、共有 locale JSON を実装資源へ作成・更新します。
    func recommendI18nForProject() {
        guard let loadedProject else { return }
        let pages = loadedProject.project.chapters.flatMap(\.pages)
        let targetPages = pages.isEmpty ? loadedProject.project.components : pages
        guard !targetPages.isEmpty else { return }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        var updated = false

        do {
            for page in targetPages {
                let segment: OpenGraphiteCanvasSegment = pages.isEmpty ? .components : .pages
                guard let pageID = pageReferenceID(for: page, segment: segment) else { continue }
                let result = try core.recommendI18n(
                    projectURL: loadedProject.fileURL,
                    pageID: pageID,
                    locales: ["ja", "eng"]
                )
                updated = updated || result.updated
            }
            refreshProjectDependenciesFromDisk()
            for page in targetPages {
                refreshPageFromDiskIfChanged(at: loadedProject.htmlURL(for: page))
            }
            lastError = nil
            statusMessage = updated
                ? "Project の i18n runtime と locale JSON を実装資源へ更新しました。"
                : "Project の i18n runtime と locale JSON は既に推奨設定です。"
            restartExternalProjectMonitoring(force: true)
        } catch {
            lastError = "Project i18n 推奨設定の適用に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Project i18n runtime literal更新関数
    /// 処理概要: Project 依存性で選択された共有 i18n 設定ファイルへ literal の loadPath / fallbackLng を保存します。
    ///
    /// - Parameters:
    ///   - loadPath: 更新する `backend.loadPath`。`nil` の場合は更新しません。
    ///   - fallbackLocale: 更新する `fallbackLng`。`nil` の場合は更新しません。
    func updateProjectI18nRuntime(loadPath: String?, fallbackLocale: String?) {
        guard let loadedProject,
              let pageID = projectI18nReferencePageID()
        else {
            return
        }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.updateI18nRuntimeLiterals(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                loadPath: loadPath,
                fallbackLocale: fallbackLocale
            )
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return
            }
            refreshProjectDependenciesFromDisk()
            lastError = nil
            statusMessage = result.updated
                ? "Project の i18n runtime 設定を更新しました。"
                : "Project の i18n runtime 設定は変更されていません。"
        } catch {
            lastError = "Project i18n runtime 設定の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Projectデザイントークン更新関数
    /// 処理概要: CSS library の `:root` に design token を保存し、開いている preview を再読み込みします。
    ///
    /// - Parameters:
    ///   - name: CSS custom property 名。
    ///   - value: CSS 値。
    func updateProjectDesignToken(name: String, value: String) {
        guard let loadedProject else { return }
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.setDesignToken(name, value: value, projectURL: loadedProject.fileURL)
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return
            }
            refreshProjectDependenciesFromDisk()
            lastError = nil
            statusMessage = result.updated
                ? "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) を Design Tokens に保存しました。"
                : "Design Tokens は変更されていません。"
        } catch {
            lastError = "Design Tokens の更新に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: Projectデザイントークン削除関数
    /// 処理概要: CSS library の `:root` から design token を削除し、開いている preview を再読み込みします。
    ///
    /// - Parameter name: 削除する CSS custom property 名。
    func removeProjectDesignToken(name: String) {
        updateProjectDesignToken(name: name, value: "")
    }

    /// 論理名（日本語）: 静的フローリンクpayload取り込み関数
    /// 処理概要: WebView から届いた静的リンク一覧を page card 内部 ID と page URL ごとに保持し、フロー表示オーバーレイの入力へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から受け取ったリンク辞書配列。
    ///   - pageURL: payload を収集した HTML page URL。
    ///   - pageInternalID: payload を収集した page card の内部 ID。
    func ingestStaticFlowLinkPayload(_ payload: [[String: Any]], pageURL: URL, pageInternalID: String? = nil) {
        let links = payload.compactMap(OpenGraphiteStaticFlowLink.init(payload:))
        staticFlowLinksByPageURL[pageURL.standardizedFileURL] = links
        let normalizedPageInternalID = pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedPageInternalID.isEmpty {
            staticFlowLinksByPageInternalID[normalizedPageInternalID] = links
        }
    }

    /// 論理名（日本語）: 静的フロー元ホバーpayload取り込み関数
    /// 処理概要: WebView から届いたホバー中リンク ID を保持し、フロー線の強調表示入力へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から受け取った hover 対象リンク辞書。
    ///   - pageURL: payload を収集した HTML page URL。
    ///   - pageInternalID: payload を収集した page card の内部 ID。
    func ingestStaticFlowSourceHoverPayload(_ payload: [String: Any], pageURL: URL, pageInternalID: String? = nil) {
        let linkID = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !linkID.isEmpty else {
            clearStaticFlowSourceHover(pageURL: pageURL, pageInternalID: pageInternalID)
            return
        }

        hoveredStaticFlowSource = OpenGraphiteStaticFlowSourceHover(
            pageURL: pageURL.standardizedFileURL,
            pageInternalID: pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines),
            linkID: linkID,
            sourceNodeID: payload["sourceNodeID"] as? String ?? ""
        )
    }

    /// 論理名（日本語）: 静的フロー元ホバー解除関数
    /// 処理概要: 指定 page または現在保持中の静的フロー遷移元 hover 状態を解除します。
    ///
    /// - Parameters:
    ///   - pageURL: 解除対象を限定する HTML page URL。`nil` の場合は無条件で解除します。
    ///   - pageInternalID: 解除対象を限定する page card 内部 ID。
    func clearStaticFlowSourceHover(pageURL: URL? = nil, pageInternalID: String? = nil) {
        guard let pageURL else {
            hoveredStaticFlowSource = nil
            return
        }

        guard hoveredStaticFlowSource?.pageURL == pageURL.standardizedFileURL else {
            return
        }

        let normalizedPageInternalID = pageInternalID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedPageInternalID.isEmpty,
           hoveredStaticFlowSource?.pageInternalID != normalizedPageInternalID {
            return
        }

        if hoveredStaticFlowSource?.pageURL == pageURL.standardizedFileURL {
            hoveredStaticFlowSource = nil
        }
    }

    /// 論理名（日本語）: ノードpayload取り込み関数
    /// 処理概要: WebView の JavaScript から受け取った辞書配列を `OpenGraphiteNode` 配列へ変換します。
    ///
    /// - Parameter payload: DOM から収集されたノード辞書の配列。
    func ingestNodePayload(_ payload: [[String: Any]]) {
        let activeMediaQueries = Self.stringArray(payload.first?["activeMediaQueries"])
        if let target = currentHTMLSyncTarget() {
            let htmlURL = target.htmlURL.standardizedFileURL
            activeMediaQueriesByHTMLURL[htmlURL] = activeMediaQueries
        }
        latestLayerNodePayload = payload
        guard let request = nodeSourceIndexRequest(
            payload: payload,
            activeMediaQueries: activeMediaQueries
        ) else {
            latestNodeSourceIndexKey = nil
            nodeDetailPayloadsByID = [:]
            publishNodePayload(payload, sourceNodes: .empty)
            return
        }
        if latestNodeSourceIndexKey != request.key {
            nodeDetailPayloadsByID = [:]
        }
        latestNodeSourceIndexKey = request.key
        if let cachedSourceNodes = nodeSourceIndexCache[request.key] {
            publishNodePayload(payload, sourceNodes: cachedSourceNodes)
            return
        }
        publishNodePayload(payload, sourceNodes: .empty)
        scheduleNodeSourceIndexBuild(request)
    }

    /// 論理名（日本語）: 選択ノード詳細payload取り込み関数
    /// 処理概要: Layers全体を再構築せず、選択された1 nodeのcomputed style、capability、text、render targetだけを既存行へ統合します。
    ///
    /// - Parameter payload: WebCanvasが選択nodeだけから収集した詳細辞書。
    func ingestNodeDetailPayload(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              !id.isEmpty,
              let index = nodes.firstIndex(where: { $0.id == id })
        else { return }
        nodeDetailPayloadsByID[id] = payload
        if let sourceIndexKey = latestNodeSourceIndexKey,
           nodeSourceIndexCache[sourceIndexKey] == nil {
            return
        }
        let basePayload = latestLayerNodePayload.first { $0["id"] as? String == id } ?? payload
        let mergedPayload = basePayload.merging(payload) { _, detail in detail }
        let sourceNodes = latestNodeSourceIndexKey.flatMap { nodeSourceIndexCache[$0] } ?? .empty
        let sourceNode = Self.sourceNode(for: mergedPayload, in: sourceNodes)
        guard let node = Self.node(from: mergedPayload, sourceNode: sourceNode) else { return }
        nodes[index] = node
        updateCSSVariableBaseline(for: node, sourceNode: sourceNode)
    }

    /// 論理名（日本語）: ノード正本索引待機関数
    /// 処理概要: 現在pageのbackground source enrichmentがあれば完了まで待ち、テストと明示検証で最終Inspector状態を観測可能にします。
    func waitForNodeSourceEnrichment() async {
        let task = nodeSourceIndexTask
        await task?.value
    }

    /// Layers payloadへcache済み詳細と正本graphを統合して公開します。
    private func publishNodePayload(
        _ payload: [[String: Any]],
        sourceNodes: CurrentSourceNodeIndexes
    ) {
        var nextCSSVariableBaselines: [String: [String: String]] = [:]
        nodes = payload.compactMap { dictionary in
            let id = dictionary["id"] as? String ?? ""
            let mergedDictionary = dictionary.merging(nodeDetailPayloadsByID[id] ?? [:]) { _, detail in detail }
            let internalID = mergedDictionary["internalID"] as? String ?? ""
            let sourceNode = Self.sourceNode(for: mergedDictionary, in: sourceNodes)
            if !internalID.isEmpty, let sourceNode {
                var baseline = sourceNode.cssVariables
                for target in sourceNode.renderingTargets {
                    for (property, value) in target.authoredValues {
                        baseline[property] = value
                    }
                }
                nextCSSVariableBaselines[internalID] = baseline
            }
            return Self.node(from: mergedDictionary, sourceNode: sourceNode)
        }
        cssVariableBaselinesByInternalID = nextCSSVariableBaselines

        synchronizeLayerNodeSelectionWithAvailableNodes()
    }

    /// 1 nodeのsource-authored CSS baselineだけを更新します。
    private func updateCSSVariableBaseline(
        for node: OpenGraphiteNode,
        sourceNode: OpenGraphiteAgentNode?
    ) {
        guard !node.internalID.isEmpty, let sourceNode else { return }
        var baseline = sourceNode.cssVariables
        for target in sourceNode.renderingTargets {
            for (property, value) in target.authoredValues {
                baseline[property] = value
            }
        }
        cssVariableBaselinesByInternalID[node.internalID] = baseline
    }

    /// WebCanvas payloadのstable ID、safe selector、browser DOM path順で正本nodeを解決します。
    private static func sourceNode(
        for dictionary: [String: Any],
        in indexes: CurrentSourceNodeIndexes
    ) -> OpenGraphiteAgentNode? {
        let internalID = dictionary["internalID"] as? String ?? ""
        let webLocator = nodeSourceLocator(from: dictionary["locator"])
        return (!internalID.isEmpty ? indexes.byInternalID[internalID] : nil)
            ?? webLocator?.selector.flatMap { indexes.bySelector[$0] }
            ?? webLocator.flatMap { indexes.byBrowserDOMPath[$0.domPath] }
    }

    /// 表示中page revisionと実参照componentからbackground source graph入力を作ります。
    private func nodeSourceIndexRequest(
        payload: [[String: Any]],
        activeMediaQueries: [String]
    ) -> NodeSourceIndexRequest? {
        guard let target = currentHTMLSyncTarget() else { return nil }
        let targetURL = target.htmlURL.standardizedFileURL
        let referencedComponentIDs = Set(payload.compactMap { dictionary -> String? in
            let value = (dictionary["sourceComponentID"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }).sorted()
        let referencedSourceNodeIDs = Set(payload.compactMap { dictionary -> String? in
            let value = (dictionary["sourceNodeInternalID"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }).sorted()
        let components: [NodeSourceIndexComponent]
        let componentRevisions: [String]
        if let loadedProject {
            var nextComponents: [NodeSourceIndexComponent] = []
            var nextRevisions: [String] = []
            for collection in loadedProject.project.collections {
                for component in collection.components where !component.internalID.isEmpty {
                    let pageReferenceID = OpenGraphiteReferenceID.component(
                        collectionID: collection.internalID,
                        componentID: component.internalID
                    ).stringValue
                    let htmlURL = loadedProject.htmlURL(for: component).standardizedFileURL
                    nextComponents.append(
                        NodeSourceIndexComponent(
                            pageReferenceID: pageReferenceID,
                            htmlURL: htmlURL
                        )
                    )
                    nextRevisions.append("\(pageReferenceID):\(reloadToken(for: htmlURL))")
                }
            }
            components = nextComponents.sorted { $0.pageReferenceID < $1.pageReferenceID }
            componentRevisions = nextRevisions.sorted()
        } else {
            components = []
            componentRevisions = []
        }
        let pageReferenceID = selectedPageReferenceID() ?? ""
        let key = NodeSourceIndexCacheKey(
            projectID: loadedProject?.id.uuidString ?? "",
            targetURL: targetURL,
            pageReferenceID: pageReferenceID,
            targetReloadToken: reloadToken(for: targetURL),
            activeMediaQueries: activeMediaQueries,
            referencedComponentIDs: referencedComponentIDs,
            referencedSourceNodeIDs: referencedSourceNodeIDs,
            componentRevisions: componentRevisions
        )
        return NodeSourceIndexRequest(
            key: key,
            projectURL: loadedProject?.fileURL,
            projectRootURL: projectRootURL ?? targetURL.deletingLastPathComponent(),
            targetHTMLURL: targetURL,
            components: components
        )
    }

    /// cache missしたsource graphだけをMainActor外で構築し、最新payloadへ適用します。
    private func scheduleNodeSourceIndexBuild(_ request: NodeSourceIndexRequest) {
        guard nodeSourceIndexTaskKey != request.key else { return }
        nodeSourceIndexTask?.cancel()
        nodeSourceIndexTaskKey = request.key
        nodeSourceIndexBuildCount += 1
        nodeSourceIndexTask = Task { [weak self] in
            let indexes = await Task.detached(priority: .userInitiated) {
                OpenGraphiteNodeSourceIndexBuilder.build(request)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.nodeSourceIndexCache[request.key] = indexes
            if self.nodeSourceIndexCache.count > 16 {
                self.nodeSourceIndexCache = [request.key: indexes]
            }
            guard self.latestNodeSourceIndexKey == request.key else {
                if self.nodeSourceIndexTaskKey == request.key {
                    self.nodeSourceIndexTask = nil
                    self.nodeSourceIndexTaskKey = nil
                }
                return
            }
            self.publishNodePayload(self.latestLayerNodePayload, sourceNodes: indexes)
            if self.nodeSourceIndexTaskKey == request.key {
                self.nodeSourceIndexTask = nil
                self.nodeSourceIndexTaskKey = nil
            }
        }
    }

    /// 論理名（日本語）: CSS宣言更新関数
    /// 処理概要: 選択中ノードの編集対象CSS declarationをsource-aware経路で保存し、WebViewを正本sourceから再読み込みします。
    ///
    /// - Parameters:
    ///   - key: 更新する CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: Inspector から入力された値。前後空白は除去します。
    func updateCSSVariable(key: String, value: String) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedLayerNodes.count <= 1,
           Self.relatedStyleProperties.contains(normalizedKey),
           selectedNode?.renderTarget(for: normalizedKey) != nil {
            updateRelatedStyleDeclaration(property: normalizedKey, value: value)
            return
        }
        if selectedLayerNodes.count > 1, !normalizedKey.isEmpty {
            let valuesByNodeID = Dictionary(
                uniqueKeysWithValues: selectedLayerNodes.map { node in
                    (node.id, [normalizedKey: value])
                }
            )
            updateSelectedLayerNodeCSSVariables(valuesByNodeID: valuesByNodeID)
            return
        }

        guard let selectedNodeID,
              let selectedNode,
              let displayTarget = currentHTMLSyncTarget(),
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard selectedNode.supports(.editLayout) else {
            lastError = "選択中の標準HTML要素ではCSSレイアウトを編集できません。"
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedOldValue = selectedNode.cssVariables[normalizedKey] ?? ""
        let expectedOldValue = expectedOldCSSVariableValue(
            for: selectedNode,
            key: normalizedKey,
            fallback: selectedOldValue
        )

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let currentValue = nodes[index].cssVariables[normalizedKey] ?? ""
            guard currentValue != normalizedValue else { return }
        }

        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .setCSSVariable(
                nodeInternalID: selectedNode.internalID,
                key: normalizedKey,
                value: normalizedValue,
                expectedOldValue: expectedOldValue
            )
        )
        let result = applyHTMLObjectEdit(edit)
        guard result.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            if normalizedValue.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: normalizedKey)
            } else {
                nodes[index].cssVariables[normalizedKey] = normalizedValue
            }
        }

        if result.requiresReload {
            incrementReloadToken(for: displayTarget.htmlURL)
        } else {
            mutationSequence += 1
            cssMutation = CSSVariableMutation(
                sequence: mutationSequence,
                pageURL: displayTarget.htmlURL,
                nodeID: selectedNode.id,
                key: normalizedKey,
                value: normalizedValue
            )
        }
        statusMessage = "\(selectedNode.displayID) の \(normalizedKey) を更新しました。"
    }

    /// 論理名（日本語）: 描画実体標準CSS宣言更新関数
    /// 処理概要: 選択 wrapper の DOM relation と Shared の cascade provenance から実体 media / SVG / mask element を解決し、標準 CSS property を最小差分で保存します。
    ///
    /// - Parameters:
    ///   - property: `object-fit`、`stroke-width`、`mask-image`、`-webkit-mask-image` のいずれか。
    ///   - value: Inspector から入力された authored CSS value。空の場合は winner declaration を削除します。
    func updateRelatedStyleDeclaration(property: String, value: String) {
        let normalizedProperty = property.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.relatedStyleProperties.contains(normalizedProperty),
              let selectedNodeID,
              let selectedNode,
              let renderTarget = selectedNode.renderTarget(for: normalizedProperty),
              let displayTarget = currentHTMLSyncTarget(),
              let editTarget = cssEditTarget(for: selectedNode),
              !selectedNode.internalID.isEmpty
        else {
            return
        }
        let requiredCapability: OpenGraphiteNodeCapability = normalizedProperty == "object-fit"
            ? .editMedia
            : .editIcon
        guard selectedNode.supports(.editLayout), selectedNode.supports(requiredCapability) else {
            lastError = "選択中の標準HTML要素では描画実体のCSSを編集できません。"
            return
        }
        guard renderTarget.authoredValue != normalizedValue else { return }
        let expectedOldValue = expectedOldCSSVariableValue(
            for: selectedNode,
            key: normalizedProperty,
            fallback: renderTarget.authoredValue
        )
        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .setCSSVariable(
                nodeInternalID: selectedNode.internalID,
                key: normalizedProperty,
                value: normalizedValue,
                expectedOldValue: expectedOldValue
            )
        )
        let result = applyHTMLObjectEdit(edit)
        guard result.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            nodes[index].updateRenderTargetValue(property: normalizedProperty, value: normalizedValue)
        }
        incrementReloadToken(for: displayTarget.htmlURL)
        statusMessage = "\(selectedNode.displayID) の \(renderTarget.targetLabel) にある \(normalizedProperty) を更新しました。"
    }

    /// 論理名（日本語）: 選択ノード標準レイアウト更新関数
    /// 処理概要: legacy layout属性を変更せず、選択modeを標準`display` / `flex-direction` declarationへ変換して同一編集単位で保存します。
    ///
    /// - Parameter mode: `vertical`、`horizontal`、`grid`、`block`のいずれか。
    func updateSelectedNodeLayout(mode: String) {
        let values: [String: String]
        switch mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "horizontal":
            values = ["display": "flex", "flex-direction": "row"]
        case "grid":
            values = ["display": "grid"]
        case "block":
            values = ["display": "block"]
        default:
            values = ["display": "flex", "flex-direction": "column"]
        }
        updateSelectedNodeCSSVariables(values: values)
    }

    /// 論理名（日本語）: 選択ノード複数CSS宣言更新関数
    /// 処理概要: 選択中ノードの複数CSS declarationを同一source-aware編集単位で保存し、WebViewを再読み込みします。
    ///
    /// - Parameter values: 更新する CSS property または OpenGraphite 予約 custom property 名と値の組。
    func updateSelectedNodeCSSVariables(values: [String: String]) {
        if selectedLayerNodes.count > 1 {
            let valuesByNodeID = Dictionary(
                uniqueKeysWithValues: selectedLayerNodes.map { node in
                    (node.id, values)
                }
            )
            updateSelectedLayerNodeCSSVariables(valuesByNodeID: valuesByNodeID)
            return
        }

        guard let selectedNodeID,
              let selectedNode,
              let displayTarget = currentHTMLSyncTarget(),
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard selectedNode.supports(.editLayout) else {
            lastError = "選択中の標準HTML要素ではCSSレイアウトを編集できません。"
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let normalizedValues = values.reduce(into: [String: String]()) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            result[key] = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !normalizedValues.isEmpty,
              let index = nodes.firstIndex(where: { $0.id == selectedNodeID })
        else {
            return
        }

        let changedValues = normalizedValues.filter { key, value in
            Self.authoredCSSValue(for: key, in: nodes[index]) != value
        }
        guard !changedValues.isEmpty else { return }

        let expectedOldValues = changedValues.reduce(into: [String: String]()) { result, entry in
            result[entry.key] = expectedOldCSSVariableValue(
                for: selectedNode,
                key: entry.key,
                fallback: Self.authoredCSSValue(for: entry.key, in: selectedNode)
            )
        }
        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .setCSSVariables(
                nodeInternalID: selectedNode.internalID,
                values: changedValues,
                expectedOldValues: expectedOldValues
            )
        )
        let result = applyHTMLObjectEdit(edit)
        guard result.updated else { return }

        for (key, value) in changedValues {
            if Self.relatedStyleProperties.contains(key) {
                nodes[index].updateRenderTargetValue(property: key, value: value)
            } else if value.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: key)
            } else {
                nodes[index].cssVariables[key] = value
            }
        }

        if result.requiresReload {
            incrementReloadToken(for: displayTarget.htmlURL)
        } else {
            mutationSequence += 1
            cssVariablesMutation = CSSVariablesMutation(
                sequence: mutationSequence,
                pageURL: displayTarget.htmlURL,
                nodeID: selectedNode.id,
                values: changedValues
            )
        }
        statusMessage = "\(selectedNode.displayID) のサイズを更新しました。"
    }

    /// 論理名（日本語）: 選択レイヤー群CSS宣言更新関数
    /// 処理概要: 同時選択中ノードそれぞれのCSS declarationを保存し、一時inline値を残さずWebViewを一度再読み込みします。
    ///
    /// - Parameter valuesByNodeID: ノード ID ごとの CSS property または OpenGraphite 予約 custom property 名と値の組。
    func updateSelectedLayerNodeCSSVariables(valuesByNodeID: [String: [String: String]]) {
        guard let displayTarget = currentHTMLSyncTarget() else { return }
        guard selectedLayerNodes.allSatisfy({ $0.supports(.editLayout) }) else {
            lastError = "選択中の標準HTML要素を含むためCSSレイアウトを一括編集できません。"
            return
        }
        guard !selectedLayerNodes.contains(where: \.hasIncompleteCSSProvenance) else {
            lastError = "一部stylesheetのsourceを読み取れないためCSSを変更できません。読み取り可能なsourceへ移してから再実行してください。"
            return
        }
        var changedValuesByNodeID: [String: [String: String]] = [:]
        var requiresReload = false

        for node in selectedLayerNodes {
            guard let requestedValues = valuesByNodeID[node.id],
                  !node.internalID.isEmpty,
                  let editTarget = cssEditTarget(for: node)
            else {
                continue
            }

            let normalizedValues = requestedValues.reduce(into: [String: String]()) { result, entry in
                let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }
                result[key] = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !normalizedValues.isEmpty,
                  let index = nodes.firstIndex(where: { $0.id == node.id })
            else {
                continue
            }

            let changedValues = normalizedValues.filter { key, value in
                Self.authoredCSSValue(for: key, in: nodes[index]) != value
            }
            guard !changedValues.isEmpty else { continue }

            let expectedOldValues = changedValues.reduce(into: [String: String]()) { result, entry in
                result[entry.key] = expectedOldCSSVariableValue(
                    for: node,
                    key: entry.key,
                    fallback: Self.authoredCSSValue(for: entry.key, in: node)
                )
            }
            let edit = HTMLObjectEdit(
                target: editTarget,
                operation: .setCSSVariables(
                    nodeInternalID: node.internalID,
                    values: changedValues,
                    expectedOldValues: expectedOldValues
                )
            )
            let result = applyHTMLObjectEdit(edit)
            guard result.updated else { continue }
            requiresReload = requiresReload || result.requiresReload

            for (key, value) in changedValues {
                if Self.relatedStyleProperties.contains(key) {
                    nodes[index].updateRenderTargetValue(property: key, value: value)
                } else if value.isEmpty {
                    nodes[index].cssVariables.removeValue(forKey: key)
                } else {
                    nodes[index].cssVariables[key] = value
                }
            }
            changedValuesByNodeID[node.id] = changedValues
        }

        guard !changedValuesByNodeID.isEmpty else { return }
        if requiresReload {
            incrementReloadToken(for: displayTarget.htmlURL)
        } else {
            mutationSequence += 1
            cssVariablesBatchMutation = CSSVariablesBatchMutation(
                sequence: mutationSequence,
                pageURL: displayTarget.htmlURL,
                nodeValues: changedValuesByNodeID
            )
        }
        statusMessage = "\(changedValuesByNodeID.count)個のオブジェクトを更新しました。"
    }

    /// 論理名（日本語）: 選択HTML locale typography更新関数
    /// 処理概要: Shared coreを通じてrootの標準`font-family`または任意BCP 47 `:lang()` ruleを保存します。
    ///
    /// - Parameters:
    ///   - locale: defaultでは`nil`、locale overrideではBCP 47 tag。
    ///   - fontFamily: 標準`font-family`値。空の場合は宣言を削除します。
    func updateSelectedLocaleTypography(locale: String?, fontFamily: String) {
        _ = persistSelectedLocaleTypography(locale: locale, fontFamily: fontFamily)
    }

    /// 論理名（日本語）: フォント候補適用関数
    /// 処理概要: 選択中ノードへ `font-family` を保存し、必要な stylesheet link を HTML 正本へ追加します。
    ///
    /// - Parameter candidate: フォントブラウザで選択された候補。
    func applyFontCandidate(_ candidate: OpenGraphiteFontCandidate) {
        guard selectedNode?.internalID.isEmpty == false,
              selectedNode?.hasIncompleteCSSProvenance == false,
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        let normalizedCSSFamily = candidate.cssFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        updateCSSVariable(key: "font-family", value: normalizedCSSFamily)

        ensureFontStylesheet(for: candidate, target: target)
    }

    /// 論理名（日本語）: 選択HTML localeフォント候補適用関数
    /// 処理概要: Page / Component Inspectorで選んだ候補を標準`font-family`へ保存し、必要なstylesheet linkを追加します。
    ///
    /// - Parameters:
    ///   - locale: defaultでは`nil`、locale overrideではBCP 47 tag。
    ///   - candidate: フォントブラウザで選択された候補。
    func applySelectedLocaleFontCandidate(locale: String?, candidate: OpenGraphiteFontCandidate) {
        guard let target = currentHTMLSyncTarget() else { return }
        let normalizedCSSFamily = candidate.cssFamily.trimmingCharacters(in: .whitespacesAndNewlines)
        guard persistSelectedLocaleTypography(locale: locale, fontFamily: normalizedCSSFamily) else { return }
        ensureFontStylesheet(for: candidate, target: target)
    }

    /// 論理名（日本語）: 選択HTML locale typography保存関数
    /// 処理概要: Shared coreのlossless CSS編集を実行し、companion CSS履歴とWebView reloadを同期します。
    ///
    /// - Parameters:
    ///   - locale: defaultでは`nil`、locale overrideではBCP 47 tag。
    ///   - fontFamily: 標準`font-family`値。空の場合は宣言を削除します。
    /// - Returns: 入力が妥当でShared coreの保存経路を完了した場合は`true`。
    @discardableResult
    private func persistSelectedLocaleTypography(locale: String?, fontFamily: String) -> Bool {
        guard let loadedProject,
              let pageID = selectedPageReferenceID(),
              let target = currentHTMLSyncTarget()
        else {
            return false
        }

        let previousCompanionCSS = companionCSSHistorySnapshot(for: target.htmlURL)
        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.setLocaleTypography(
                projectURL: loadedProject.fileURL,
                pageID: pageID,
                locale: locale,
                fontFamily: fontFamily
            )
            if let diagnostic = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = diagnostic.message
                return false
            }

            if result.updated {
                let nextCompanionCSS = companionCSSHistorySnapshot(for: target.htmlURL)
                if previousCompanionCSS != nextCompanionCSS {
                    recordDocumentHistory(
                        projectURL: loadedProject.fileURL,
                        pageURL: target.htmlURL,
                        advancesHTMLHistory: false,
                        companionCSSChange: CompanionCSSHistoryChange(
                            previousCSS: previousCompanionCSS,
                            nextCSS: nextCompanionCSS
                        )
                    )
                }
                incrementReloadToken(for: target.htmlURL)
                restartExternalPageMonitoring(force: true)
            }

            lastError = nil
            statusMessage = result.updated
                ? "\(result.selector) の font-family を更新しました。"
                : "\(result.selector) の font-family に変更はありません。"
            return true
        } catch {
            lastError = "Locale typography の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: フォントstylesheet保証関数
    /// 処理概要: 外部フォント候補が要求する stylesheet link を HTML `<head>` へ重複なく保存します。
    ///
    /// - Parameters:
    ///   - candidate: stylesheet URL を持つ可能性があるフォント候補。
    ///   - target: 保存対象 HTML。
    private func ensureFontStylesheet(for candidate: OpenGraphiteFontCandidate, target: HTMLSyncTarget) {
        guard let stylesheetHref = candidate.stylesheetHref?.trimmingCharacters(in: .whitespacesAndNewlines),
              !stylesheetHref.isEmpty
        else {
            return
        }
        guard let diskHTML = readHTMLFromDisk(at: target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let mutation = OpenGraphiteHTMLDocument(html: diskHTML)
            .ensuringStylesheetLink(href: stylesheetHref, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = mutation.diagnostics.first(where: { $0.severity == .error })?.message
                ?? "font stylesheet の保存に失敗しました。"
            return
        }
        guard mutation.html != diskHTML else { return }
        guard syncHTML(mutation.html, target: target) else { return }
        incrementReloadToken(for: target.htmlURL)
        lastError = nil
        statusMessage = "\(candidate.familyName) の font stylesheet を追加しました。"
    }

    /// 論理名（日本語）: ノード属性更新関数
    /// 処理概要: 選択中ノードの編集対象属性を空文字を含む指定値へ設定し、属性削除intentとは分離してWebViewへ反映します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: Inspector から入力された値。標準属性では先頭末尾空白と空文字をsource intentとして保持します。
    func updateNodeAttribute(name: String, value: String) {
        guard let selectedNodeID,
              let selectedNode,
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        guard selectedNode.supportsEditingAttribute(name) else {
            lastError = "選択中の標準HTML要素では \(name) 属性を安全に編集できません。"
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedName.isEmpty else { return }
        let persistedValue = normalizedName.hasPrefix("data-og-")
            ? value.trimmingCharacters(in: .whitespacesAndNewlines)
            : value
        let currentNode = nodes.first(where: { $0.id == selectedNodeID }) ?? selectedNode
        let authoredAttribute = currentNode.attributes.first {
            $0.key.caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        let expectedOldPresence = normalizedName == "hidden"
            ? currentNode.hasHiddenAttribute
            : authoredAttribute != nil
        let expectedOldValue = authoredAttribute?.value ?? ""
        guard !expectedOldPresence || expectedOldValue != persistedValue else { return }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setAttribute(
                nodeInternalID: selectedNode.internalID,
                name: normalizedName,
                value: persistedValue,
                expectedOldValue: expectedOldValue,
                expectedOldPresence: expectedOldPresence
            )
        )
        let editResult = applyHTMLObjectEdit(edit)
        guard editResult.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let existingName = nodes[index].attributes.keys.first {
                $0.caseInsensitiveCompare(normalizedName) == .orderedSame
            }
            if let existingName, existingName != normalizedName {
                nodes[index].attributes.removeValue(forKey: existingName)
            }
            nodes[index].attributes[normalizedName] = persistedValue
            switch normalizedName {
            case "hidden":
                nodes[index].hasHiddenAttribute = true
            case "role":
                nodes[index].role = persistedValue.isEmpty ? nil : persistedValue
            case "data-og-icon-library":
                nodes[index].iconLibrary = persistedValue.isEmpty ? nil : persistedValue
            case "data-og-icon-name":
                nodes[index].iconName = persistedValue.isEmpty ? nil : persistedValue
            case "data-og-icon-source":
                nodes[index].iconSource = persistedValue.isEmpty ? nil : persistedValue
            default: break
            }
        }

        if editResult.requiresReload {
            requestDocumentReplacementFromDisk(for: target, selectedNodeID: selectedNode.id)
        } else {
            attributeMutationSequence += 1
            attributeMutation = NodeAttributeMutation(
                sequence: attributeMutationSequence,
                pageURL: target.htmlURL,
                nodeID: selectedNode.id,
                name: normalizedName,
                value: persistedValue
            )
        }
        statusMessage = "\(selectedNode.displayID) の \(normalizedName) を更新しました。"
    }

    /// 論理名（日本語）: ノード属性削除関数
    /// 処理概要: 選択中ノードに存在する属性tokenだけを明示的に削除し、空文字設定とは別operationとして保存します。
    ///
    /// - Parameter name: 削除する属性名。
    func removeNodeAttribute(name: String) {
        guard let selectedNodeID,
              let selectedNode,
              let target = currentHTMLSyncTarget()
        else { return }
        guard selectedNode.supportsEditingAttribute(name) else {
            lastError = "選択中の標準HTML要素では \(name) 属性を安全に削除できません。"
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentNode = nodes.first(where: { $0.id == selectedNodeID }) ?? selectedNode
        let authoredAttribute = currentNode.attributes.first {
            $0.key.caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        let isPresent = normalizedName == "hidden"
            ? currentNode.hasHiddenAttribute
            : authoredAttribute != nil
        guard isPresent else { return }
        let expectedOldValue = authoredAttribute?.value ?? ""
        let edit = HTMLObjectEdit(
            target: target,
            operation: .removeAttribute(
                nodeInternalID: selectedNode.internalID,
                name: normalizedName,
                expectedOldValue: expectedOldValue,
                expectedOldPresence: true
            )
        )
        let editResult = applyHTMLObjectEdit(edit)
        guard editResult.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            if let existingName = nodes[index].attributes.keys.first(where: {
                $0.caseInsensitiveCompare(normalizedName) == .orderedSame
            }) {
                nodes[index].attributes.removeValue(forKey: existingName)
            }
            switch normalizedName {
            case "hidden": nodes[index].hasHiddenAttribute = false
            case "role": nodes[index].role = nil
            case "data-og-icon-library": nodes[index].iconLibrary = nil
            case "data-og-icon-name": nodes[index].iconName = nil
            case "data-og-icon-source": nodes[index].iconSource = nil
            default: break
            }
        }

        if editResult.requiresReload {
            requestDocumentReplacementFromDisk(for: target, selectedNodeID: selectedNode.id)
        } else {
            attributeMutationSequence += 1
            attributeMutation = NodeAttributeMutation(
                sequence: attributeMutationSequence,
                pageURL: target.htmlURL,
                nodeID: selectedNode.id,
                name: normalizedName,
                value: "",
                removesAttribute: true
            )
        }
        statusMessage = "\(selectedNode.displayID) の \(normalizedName) を削除しました。"
    }

    /// 論理名（日本語）: ノード表示ID更新関数
    /// 処理概要: Layers のインライン編集から選択中ノードの `data-og-id` を正規化して更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameter value: Layers で入力された新しいオブジェクト名。
    func updateNodeDisplayID(value: String) {
        guard let selectedNodeID,
              let selectedNode,
              let editTarget = cssEditTarget(for: selectedNode)
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let normalizedValue = Self.normalizedNodeDisplayID(value)
        guard selectedNode.displayID != normalizedValue else { return }

        let edit = HTMLObjectEdit(
            target: editTarget,
            operation: .renameNodeID(
                nodeInternalID: selectedNode.internalID,
                value: normalizedValue,
                expectedOldValue: selectedNode.displayID
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return }

        attributeMutationSequence += 1
        attributeMutation = NodeAttributeMutation(
            sequence: attributeMutationSequence,
            pageURL: editTarget.htmlURL,
            nodeID: selectedNodeID,
            name: "data-og-id",
            value: normalizedValue
        )
        statusMessage = "\(selectedNode.displayID) を \(normalizedValue) に変更しました。"
    }

    /// 論理名（日本語）: ノードテキスト内容プレビュー関数
    /// 処理概要: 選択中 text node の app 内 cache を更新し、永続化せず WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から入力中のプレーンテキスト。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ反映します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ反映します。
    /// - Returns: live 反映対象として受理できた場合は `true`。
    @discardableResult
    func previewNodeTextContent(_ value: String, expectedNodeID: String? = nil, expectedPageURL: URL? = nil) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.supports(.editText),
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }
        guard let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) else {
            return false
        }

        let previousActiveValue = nodes[index].textContent ?? ""
        let previousFallbackValue = selectedNodeTextFallbackValue(nodes[index])
        let shouldUpdateActiveValue = !nodes[index].isTextBinding || previousActiveValue == previousFallbackValue
        guard previousFallbackValue != value || (shouldUpdateActiveValue && previousActiveValue != value) else {
            return true
        }

        nodes[index].fallbackTextContent = value
        if shouldUpdateActiveValue {
            nodes[index].textContent = value
        }

        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .fallback
        )
        return true
    }

    /// 論理名（日本語）: ノードテキスト内容更新関数
    /// 処理概要: 選択中 text node の HTML 正本 fallback を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から確定されたプレーンテキスト。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedOldValue: 入力開始時の保存済み fallback。live cache 更新後の確定保存で競合判定に使います。
    /// - Returns: 保存が成功した、または保存不要だった場合は `true`。
    @discardableResult
    func updateNodeTextContent(
        _ value: String,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil,
        expectedOldValue: String? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.supports(.editText),
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return false
        }

        let resolvedExpectedOldValue = expectedOldValue ?? selectedNodeTextFallbackValue(selectedNode)
        guard resolvedExpectedOldValue != value else { return true }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setTextContent(
                nodeInternalID: selectedNode.internalID,
                text: value,
                expectedOldValue: resolvedExpectedOldValue
            )
        )
        guard applyHTMLObjectEdit(edit).updated else { return false }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            let previousActiveValue = nodes[index].textContent ?? ""
            let previousFallbackValue = selectedNodeTextFallbackValue(nodes[index])
            nodes[index].fallbackTextContent = value
            if !nodes[index].isTextBinding || previousActiveValue == previousFallbackValue {
                nodes[index].textContent = value
            }
        }

        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .fallback
        )
        statusMessage = "\(selectedNode.displayID) の text を更新しました。"
        return true
    }

    /// 論理名（日本語）: i18nテキストresource値一覧取得関数
    /// 処理概要: 選択中 text node の i18n key に対応する locale JSON 値を読み取ります。
    ///
    /// - Parameters:
    ///   - node: 値を読み取る binding text node。
    ///   - inspection: i18n runtime 検査結果。
    /// - Returns: locale を key、resource 内 text を value とする辞書。
    func i18nTextResourceValues(
        for node: OpenGraphiteNode,
        inspection: OpenGraphiteI18nRuntimeInspection?
    ) -> [String: String] {
        guard node.isTextBinding,
              let i18nKey = Self.nonEmptyTrimmed(node.i18nKey),
              let inspection
        else {
            return [:]
        }

        var values: [String: String] = [:]
        for resource in inspection.resources {
            let resourceURL = URL(fileURLWithPath: resource.path)
            guard let value = Self.i18nTextResourceValue(at: resourceURL, key: i18nKey) else {
                continue
            }
            values[resource.locale] = value
        }
        return values
    }

    /// 論理名（日本語）: Active Resolvedテキスト編集文脈取得関数
    /// 処理概要: 選択中 binding text の表示 locale と locale JSON への書き戻し可否を返します。
    ///
    /// - Parameter node: 文脈を取得する text node。
    /// - Returns: 表示 locale と編集可否。binding text ではない場合や locale を解決できない場合は `nil`。
    func activeResolvedTextEditContext(for node: OpenGraphiteNode) -> (locale: String, isEditable: Bool)? {
        resolvedTextEditContext(for: node, locale: nil)
    }

    /// 論理名（日本語）: Resolvedテキスト編集文脈取得関数
    /// 処理概要: 指定 locale の locale JSON へ書き戻せるかを返します。locale 未指定時は preview 表示中 locale を使います。
    ///
    /// - Parameters:
    ///   - node: 文脈を取得する text node。
    ///   - locale: 対象 locale。`nil` の場合は active preview locale。
    /// - Returns: 対象 locale と編集可否。binding text ではない場合や locale を解決できない場合は `nil`。
    func resolvedTextEditContext(
        for node: OpenGraphiteNode,
        locale: String?
    ) -> (locale: String, isEditable: Bool)? {
        guard node.isTextBinding,
              node.i18nKey != nil,
              let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale()
        else {
            return nil
        }

        guard let inspection = selectedI18nRuntimeInspection,
              inspection.adapter != .unknown
        else {
            return (locale: resolvedLocale, isEditable: false)
        }

        let resource = inspection.resources.first { $0.locale == resolvedLocale }
        let isEditable = resource?.editable ?? (inspection.loadPath.source != .external)
        return (locale: resolvedLocale, isEditable: isEditable)
    }

    /// 論理名（日本語）: Active Resolvedテキスト内容プレビュー関数
    /// 処理概要: 表示中 locale の解決済み text を app 内 cache と WebView へ反映します。locale resource は保存しません。
    ///
    /// - Parameters:
    ///   - value: Inspector から入力中の表示中 locale のプレーンテキスト。
    ///   - locale: 更新対象 locale。省略時は現在の preview context から解決します。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ反映します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ反映します。
    /// - Returns: live 反映対象として受理できた場合は `true`。
    @discardableResult
    func previewActiveResolvedTextContent(
        _ value: String,
        locale: String? = nil,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.isTextBinding,
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }

        guard let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale() else {
            lastError = "表示中 locale を解決できないため Active Resolved を反映できません。"
            return false
        }
        guard resolvedTextEditContext(for: selectedNode, locale: resolvedLocale)?.isEditable == true else {
            lastError = "\(resolvedLocale) の text resource は編集できません。Project の i18n 設定を確認してください。"
            return false
        }
        guard isActiveResolvedLocale(resolvedLocale) else {
            lastError = nil
            return true
        }
        guard let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) else {
            return false
        }
        guard nodes[index].textContent != value else {
            return true
        }

        nodes[index].textContent = value
        publishTextMutation(
            pageURL: target.htmlURL,
            nodeID: selectedNode.id,
            value: value,
            mode: .resolved
        )
        lastError = nil
        return true
    }

    /// 論理名（日本語）: Active Resolvedテキスト内容更新関数
    /// 処理概要: 表示中 locale の i18n resource 値を更新し、WebView へ解決済み表示値の mutation を発行します。
    ///
    /// - Parameters:
    ///   - value: Inspector から確定された表示中 locale のプレーンテキスト。
    ///   - locale: 更新対象 locale。省略時は現在の preview context から解決します。
    ///   - expectedNodeID: 入力開始時の node ID。指定時は現在選択と一致する場合だけ保存します。
    ///   - expectedPageURL: 入力開始時の HTML URL。指定時は現在選択と一致する場合だけ保存します。
    /// - Returns: 保存が成功した、または保存不要だった場合は `true`。
    @discardableResult
    func updateActiveResolvedTextContent(
        _ value: String,
        locale: String? = nil,
        expectedNodeID: String? = nil,
        expectedPageURL: URL? = nil
    ) -> Bool {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.isTextBinding,
              let i18nKey = selectedNode.i18nKey,
              let loadedProject,
              let pageID = selectedPageReferenceID(),
              let target = currentHTMLSyncTarget()
        else {
            return false
        }
        guard expectedNodeID == nil || selectedNodeID == expectedNodeID else { return false }
        if let expectedPageURL {
            guard target.htmlURL.standardizedFileURL == expectedPageURL.standardizedFileURL else { return false }
        }

        let resolvedLocale = Self.nonEmptyTrimmed(locale) ?? activeResolvedTextLocale()
        guard let resolvedLocale else {
            lastError = "表示中 locale を解決できないため Active Resolved を保存できません。"
            return false
        }
        guard resolvedTextEditContext(for: selectedNode, locale: resolvedLocale)?.isEditable == true else {
            lastError = "\(resolvedLocale) の locale JSON は編集できません。Project の i18n 設定を確認してください。"
            return false
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: loadedProject.fileURL)
        let core = OpenGraphiteAgentCore(contract: contract)
        do {
            let result = try core.setI18nResourceValue(
                value,
                locale: resolvedLocale,
                key: i18nKey,
                projectURL: loadedProject.fileURL,
                pageID: pageID
            )
            if let error = result.diagnostics.first(where: { $0.severity == .error }) {
                lastError = error.message
                return false
            }

            if isActiveResolvedLocale(resolvedLocale),
               let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                nodes[index].textContent = value
                publishTextMutation(
                    pageURL: target.htmlURL,
                    nodeID: selectedNode.id,
                    value: value,
                    mode: .resolved
                )
            }
            lastError = nil
            statusMessage = result.updated
                ? "\(selectedNode.displayID) の \(resolvedLocale) text resource を更新しました。"
                : "\(selectedNode.displayID) の \(resolvedLocale) text resource は変更されていません。"
            return true
        } catch {
            lastError = "Active Resolved の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: アイコン属性更新関数
    /// 処理概要: 選択中 icon node の metadata と保存済み描画 HTML を更新し、WebView へ置換要求を発行します。
    ///
    /// - Parameters:
    ///   - library: icon library。空の場合は lucide として保存します。
    ///   - name: icon name。空の場合は circle として保存します。
    ///   - source: icon source。空の場合は inline として保存します。
    func updateIcon(library: String, name: String, source: String) {
        guard let selectedNodeID,
              let selectedNode,
              selectedNode.supports(.editIcon),
              let target = currentHTMLSyncTarget()
        else {
            return
        }
        guard !selectedNode.internalID.isEmpty else {
            reportHTMLObjectEditConflict()
            return
        }

        let currentLibrary = selectedNode.iconLibrary ?? OpenGraphiteIconMarkup.defaultLibrary
        let currentName = selectedNode.iconName ?? OpenGraphiteIconMarkup.defaultName
        let currentSource = selectedNode.iconSource ?? OpenGraphiteIconMarkup.defaultSource
        let normalizedLibrary = Self.normalizedIconValue(library, defaultValue: OpenGraphiteIconMarkup.defaultLibrary)
        let normalizedName = Self.normalizedIconValue(name, defaultValue: OpenGraphiteIconMarkup.defaultName)
        let normalizedSource = Self.normalizedIconValue(source, defaultValue: OpenGraphiteIconMarkup.defaultSource)

        guard currentLibrary != normalizedLibrary
                || currentName != normalizedName
                || currentSource != normalizedSource
        else {
            return
        }

        let edit = HTMLObjectEdit(
            target: target,
            operation: .setIcon(
                nodeInternalID: selectedNode.internalID,
                library: normalizedLibrary,
                name: normalizedName,
                source: normalizedSource,
                expectedOldValues: [
                    "data-og-icon-library": selectedNode.iconLibrary ?? "",
                    "data-og-icon-name": selectedNode.iconName ?? "",
                    "data-og-icon-source": selectedNode.iconSource ?? ""
                ]
            )
        )
        let result = applyHTMLObjectEdit(edit)
        guard result.updated else { return }

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            nodes[index].iconLibrary = normalizedLibrary
            nodes[index].iconName = normalizedName
            nodes[index].iconSource = normalizedSource
        }

        if result.requiresReload {
            requestDocumentReplacementFromDisk(for: target, selectedNodeID: selectedNodeID)
        }
        statusMessage = "\(selectedNode.displayID) の icon を更新しました。"
    }

    /// 論理名（日本語）: CSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markMutationApplied(sequence: Int) {
        guard cssMutation?.sequence == sequence else { return }
        cssMutation = nil
    }

    /// 論理名（日本語）: 複数CSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した複数 CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markVariablesMutationApplied(sequence: Int) {
        guard cssVariablesMutation?.sequence == sequence else { return }
        cssVariablesMutation = nil
    }

    /// 論理名（日本語）: 複数ノードCSS宣言mutation適用完了関数
    /// 処理概要: WebView への反映が完了した複数ノード CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markVariablesBatchMutationApplied(sequence: Int) {
        guard cssVariablesBatchMutation?.sequence == sequence else { return }
        cssVariablesBatchMutation = nil
    }

    /// 論理名（日本語）: 属性mutation適用完了関数
    /// 処理概要: WebView への反映が完了した属性 mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markAttributeMutationApplied(sequence: Int) {
        guard attributeMutation?.sequence == sequence else { return }
        attributeMutation = nil
    }

    /// 論理名（日本語）: テキストmutation適用完了関数
    /// 処理概要: WebView への反映が完了した text mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markTextMutationApplied(sequence: Int) {
        guard textMutation?.sequence == sequence else { return }
        textMutation = nil
    }

    /// 論理名（日本語）: 現在HTML同期関数
    /// 処理概要: 互換用に現在選択中 HTML へ全文同期します。WebView callback では URL 固定の `syncHTML(_:target:)` を使います。
    ///
    /// - Parameter html: 同期する HTML 文字列。
    func syncCurrentHTML(_ html: String) {
        guard let target = currentHTMLSyncTarget() else { return }
        syncHTML(html, target: target)
    }

    /// 論理名（日本語）: HTML全文同期関数
    /// 処理概要: 固定済み保存対象へ HTML 全文を同期します。ディスクが別編集で更新済みの場合は上書きしません。
    ///
    /// - Parameters:
    ///   - html: 同期する HTML 文字列。
    ///   - target: 保存対象 HTML。
    /// - Returns: 同期できた場合は `true`。
    @discardableResult
    func syncHTML(_ html: String, target: HTMLSyncTarget) -> Bool {
        guard validateHTMLSyncTarget(target) != nil else { return false }
        guard diskHTMLMatchesKnownBaseline(at: target.htmlURL) else {
            reportHTMLObjectEditConflict()
            return false
        }
        var history = historyForPage(at: target.htmlURL, fallbackHTML: html)

        do {
            try html.write(to: target.htmlURL, atomically: true, encoding: .utf8)
            lastKnownPageHTMLByURL[target.htmlURL] = html
            let didRecordHistory = history.recordSync(html: html)
            syncHistories[target.htmlURL] = history
            if didRecordHistory, let projectURL = loadedProject?.fileURL {
                recordDocumentHistory(projectURL: projectURL, pageURL: target.htmlURL)
            } else {
                updateHistoryAvailability()
            }
            statusMessage = "\(target.htmlURL.lastPathComponent) と同期しました。"
            return true
        } catch {
            lastError = "HTMLの同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集payload適用関数
    /// 処理概要: JavaScript 由来の object edit payload を固定済み HTML 対象へ保存します。
    ///
    /// - Parameters:
    ///   - payload: `operation` を含む JavaScript bridge payload。
    ///   - target: 保存対象 HTML。
    /// - Returns: 保存結果。
    func applyHTMLObjectEditPayload(_ payload: [String: Any], target: HTMLSyncTarget) -> HTMLObjectEditResult {
        guard let edit = htmlObjectEdit(from: payload, target: target) else {
            lastError = "HTMLの保存形式が不正です。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }
        let result = applyHTMLObjectEdit(edit)
        if result.updated {
            requestInspectorSections(for: edit.operation)
        }
        return result
    }

    /// 論理名（日本語）: Inspectorセクション開放要求関数
    /// 処理概要: Preview 側編集で変更されたパラメータに対応する Inspector カードを現在選択スコープ内で開く要求を発行します。
    ///
    /// - Parameter sectionIDs: 開く対象の Inspector セクション ID 集合。
    private func requestInspectorSections(_ sectionIDs: Set<InspectorSectionID>) {
        guard !sectionIDs.isEmpty else { return }
        inspectorSectionOpenRequestSequence += 1
        inspectorSectionOpenRequest = InspectorSectionOpenRequest(
            sequence: inspectorSectionOpenRequestSequence,
            scopeIdentifier: inspectorExpansionScopeIdentifier,
            sectionIDs: sectionIDs
        )
    }

    /// 論理名（日本語）: HTML編集操作対応Inspectorセクション開放要求関数
    /// 処理概要: Web preview 由来の object edit 操作を Inspector セクションへ分類し、該当カードを開く要求を発行します。
    ///
    /// - Parameter operation: 保存に成功した HTML object edit 操作。
    private func requestInspectorSections(for operation: HTMLObjectEditOperation) {
        requestInspectorSections(InspectorSectionID.sections(for: operation))
    }

    /// 論理名（日本語）: ドキュメント変更取り消し関数
    /// 処理概要: HTML、companion CSS、キャンバス注釈、ガイド、参照配置の統合履歴を一段戻し、各正本へ適用します。
    func undoDocumentChange() {
        applyHistoryNavigation(direction: .undo)
    }

    /// 論理名（日本語）: ドキュメント変更やり直し関数
    /// 処理概要: HTML、companion CSS、キャンバス注釈、ガイド、参照配置の統合redo履歴を一段進め、各正本へ適用します。
    func redoDocumentChange() {
        applyHistoryNavigation(direction: .redo)
    }

    /// 論理名（日本語）: ドキュメント置換要求適用完了関数
    /// 処理概要: WebView で適用済みになった HTML 置換要求を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した置換要求の順序番号。
    func markDocumentReplacementApplied(sequence: Int) {
        guard documentReplacementRequest?.sequence == sequence else { return }
        documentReplacementRequest = nil
    }

    /// 論理名（日本語）: 外部HTML変更同期関数
    /// 処理概要: ディスク上の現在ページ HTML が最後に把握した内容から変わっていれば WebView 置換要求へ変換します。
    func refreshSelectedPageFromDiskIfChanged() {
        guard let selectedPageURL else { return }
        refreshPageFromDiskIfChanged(at: selectedPageURL)
    }

    /// 論理名（日本語）: ページHTML外部変更同期関数
    /// 処理概要: 指定 HTML の外部変更を検出し、選択中ページは置換要求へ、非選択ページは WebView reload token へ反映します。
    ///
    /// - Parameter pageURL: 外部変更を確認する HTML URL。
    func refreshPageFromDiskIfChanged(at pageURL: URL) {
        guard let diskHTML = readHTMLFromDisk(at: pageURL) else { return }

        defer {
            restartExternalPageMonitoring(force: true)
        }

        let lastKnownHTML = lastKnownPageHTMLByURL[pageURL]
        guard lastKnownHTML != diskHTML else { return }

        if pageURL != selectedPageURL {
            lastKnownPageHTMLByURL[pageURL] = diskHTML
            incrementReloadToken(for: pageURL)
            statusMessage = "\(pageURL.lastPathComponent) の外部変更を表示へ同期しました。"
            return
        }

        guard cssMutation == nil,
              cssVariablesMutation == nil,
              attributeMutation == nil,
              textMutation == nil,
              documentReplacementRequest == nil
        else {
            statusMessage = "\(pageURL.lastPathComponent) の外部変更を検出しました。未適用の編集があるため自動同期を保留しています。"
            return
        }

        var history = historyForPage(at: pageURL, fallbackHTML: diskHTML)
        let didRecordHistory = history.recordSync(html: diskHTML)
        syncHistories[pageURL] = history
        if didRecordHistory, let projectURL = loadedProject?.fileURL {
            recordDocumentHistory(projectURL: projectURL, pageURL: pageURL)
        }
        lastKnownPageHTMLByURL[pageURL] = diskHTML
        documentReplacementSequence += 1
        documentReplacementRequest = DocumentReplacementRequest(
            sequence: documentReplacementSequence,
            pageURL: pageURL,
            html: diskHTML,
            selectedNodeID: selectedNodeID
        )
        updateHistoryAvailability()
        statusMessage = "\(pageURL.lastPathComponent) の外部変更を同期しました。"
    }

    /// 論理名（日本語）: 外部プロジェクト変更同期関数
    /// 処理概要: ディスク上の `.ogp` が変わっていれば再読込し、ページ一覧とキャンバス配置を表示へ反映します。
    func refreshProjectManifestFromDiskIfChanged() {
        guard let currentProject = loadedProject else { return }

        defer {
            restartExternalProjectMonitoring(force: true)
        }

        do {
            let reloadedProject = try loader.loadProject(at: currentProject.fileURL)
            guard reloadedProject.project != currentProject.project
                    || reloadedProject.rootURL != currentProject.rootURL
            else {
                return
            }

            let previousSelectedPageInternalID = selectedPageInternalID
            let previousSelectedComponentPageInternalID = selectedComponentPageInternalID
            let previousSelectedChapterInternalID = selectedChapterInternalID
            let previousSelectedCollectionInternalID = selectedCollectionInternalID
            let previousSelectedCanvasSegment = selectedCanvasSegment
            let previousSelectedCanvasAnnotationID = selectedCanvasAnnotationID
            let previousSelectedCanvasAnnotationIDs = selectedCanvasAnnotationIDs
            let previousSelectedPageURL = selectedPageURL
            loadedProject = reloadedProject
            seedKnownHTMLForProject(reloadedProject)

            if let chapter = reloadedProject.project.chapters.first(where: {
                $0.internalID == previousSelectedChapterInternalID && !$0.isSidebarHidden
            }) {
                selectedChapterID = chapter.id
                selectedChapterInternalID = chapter.internalID
            } else {
                let chapter = Self.preferredVisibleChapter(in: reloadedProject.project)
                selectedChapterID = chapter?.id
                selectedChapterInternalID = chapter?.internalID
            }

            let currentChapterPages = selectedChapter?.pages ?? []
            if let page = currentChapterPages.first(where: {
                $0.internalID == previousSelectedPageInternalID
            }) {
                selectedPageID = page.id
                selectedPageInternalID = page.internalID
            } else if previousSelectedPageInternalID != nil {
                selectedPageID = currentChapterPages.first?.id
                selectedPageInternalID = currentChapterPages.first?.internalID
            } else {
                selectedPageID = nil
                selectedPageInternalID = nil
            }

            if let collection = Self.preferredCollection(in: reloadedProject.project, internalID: previousSelectedCollectionInternalID) {
                selectedCollectionID = collection.id
                selectedCollectionInternalID = collection.internalID
            } else {
                selectedCollectionID = nil
                selectedCollectionInternalID = nil
            }

            let currentCollectionComponents = selectedComponentCollection?.components ?? []
            if let componentPage = currentCollectionComponents.first(where: {
                $0.internalID == previousSelectedComponentPageInternalID
            }) {
                selectedComponentPageID = componentPage.id
                selectedComponentPageInternalID = componentPage.internalID
            } else if previousSelectedComponentPageInternalID != nil,
                      let containingCollection = reloadedProject.project.collections.first(where: { collection in
                          collection.components.contains { $0.internalID == previousSelectedComponentPageInternalID }
                      }),
                      let componentPage = containingCollection.components.first(where: {
                          $0.internalID == previousSelectedComponentPageInternalID
                      }) {
                selectedCollectionID = containingCollection.id
                selectedCollectionInternalID = containingCollection.internalID
                selectedComponentPageID = componentPage.id
                selectedComponentPageInternalID = componentPage.internalID
            } else {
                let fallbackCollection = Self.preferredCollection(in: reloadedProject.project, internalID: selectedCollectionInternalID)
                selectedCollectionID = fallbackCollection?.id
                selectedCollectionInternalID = fallbackCollection?.internalID
                selectedComponentPageID = nil
                selectedComponentPageInternalID = nil
            }

            if previousSelectedCanvasSegment == .components, !reloadedProject.project.collections.isEmpty {
                selectedCanvasSegment = .components
            } else {
                selectedCanvasSegment = .pages
            }

            let availableAnnotationIDs = Set(selectedCanvasAnnotations.map(\.internalID))
            let survivingAnnotationIDs = previousSelectedCanvasAnnotationIDs.intersection(availableAnnotationIDs)
            let survivingPrimaryID = previousSelectedCanvasAnnotationID.flatMap {
                survivingAnnotationIDs.contains($0) ? $0 : nil
            } ?? selectedCanvasAnnotations.last(where: {
                survivingAnnotationIDs.contains($0.internalID)
            })?.internalID
            applyCanvasAnnotationSelection(
                ids: survivingAnnotationIDs,
                primaryID: survivingPrimaryID
            )
            reconcileCanvasReferenceSelectionAfterManifestChange()

            if selectedPageURL != previousSelectedPageURL {
                selectedNodeID = nil
                nodes = []
                prepareHistoryForSelectedPage()
            }

            restartExternalPageMonitoring(force: true)
            restartExternalDependencyMonitoring(force: true)
            statusMessage = "\(reloadedProject.project.name) の .ogp 外部変更を同期しました。"
        } catch {
            lastError = ".ogp の再読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: project依存ファイル外部変更同期関数
    /// 処理概要: CSS、runtime、component master など HTML 以外の依存変更を全 WebView の reload token へ反映します。
    func refreshProjectDependenciesFromDisk() {
        guard let loadedProject else { return }

        for page in loadedProject.project.allPages {
            incrementReloadToken(for: loadedProject.htmlURL(for: page))
        }
        restartExternalDependencyMonitoring(force: true)
        statusMessage = "CSS / Components の外部変更を表示へ同期しました。"
    }

    /// 論理名（日本語）: 外部依存ファイル変更同期関数
    /// 処理概要: HTML直下またはlocal CSS `@import` graphに含まれる依存だけを再読込対象とし、未知URLの通知では表示を変えません。
    ///
    /// - Parameter url: 外部変更を検出したlocal resource URL。
    func refreshProjectDependencyFromDiskIfChanged(at url: URL) {
        guard let loadedProject else { return }
        let dependencyURLs = projectDependencyURLs(for: loadedProject)
        let standardizedURL = url.standardizedFileURL
        let resolvedURL = standardizedURL.resolvingSymlinksInPath()
        let wasMonitored = dependencyChangeMonitorsByURL.keys.contains(standardizedURL)
            || dependencyChangeMonitorsByURL.keys.contains(resolvedURL)
        guard wasMonitored
                || dependencyURLs.contains(standardizedURL)
                || dependencyURLs.contains(resolvedURL)
        else {
            return
        }
        refreshProjectDependenciesFromDisk()
    }

    /// 論理名（日本語）: WebViewエラー報告関数
    /// 処理概要: WebView や JavaScript ブリッジで発生したエラー文を画面表示用に保存します。
    ///
    /// - Parameter message: 表示するエラーメッセージ。
    func reportWebError(_ message: String) {
        lastError = message
    }

    /// 論理名（日本語）: 履歴ナビゲーション方向
    /// 概要: undo/redo のどちらの履歴移動を行うかを表します。
    ///
    /// 定義内容:
    /// - `undo`: 取り消し方向。
    /// - `redo`: やり直し方向。
    private enum HistoryNavigationDirection {
        case undo
        case redo
    }

    /// 論理名（日本語）: Companion CSS履歴変更
    /// 概要: 一度の文書編集に含まれるcompanion CSSファイルの変更前後を、ファイル未作成状態も含めて保持します。
    private struct CompanionCSSHistoryChange: Equatable {
        var previousCSS: String?
        var nextCSS: String?
    }

    /// 論理名（日本語）: HTML履歴項目
    /// 概要: 一度のHTMLまたはcompanion CSS同期をprojectとpage URLに固定し、統合履歴から正本を復元するために保持します。
    private struct DocumentHistoryEntry: Equatable {
        var projectURL: URL
        var pageURL: URL
        var advancesHTMLHistory: Bool
        var companionCSSChange: CompanionCSSHistoryChange?
    }

    /// 論理名（日本語）: キャンバス注釈履歴対象
    /// 概要: `.ogp` 内で undo/redo の注釈配列を差し替える Chapter または Collection を識別します。
    private struct CanvasAnnotationHistoryTarget: Equatable {
        var segment: OpenGraphiteCanvasSegment
        var containerInternalID: String
    }

    /// 論理名（日本語）: キャンバス注釈履歴スナップショット
    /// 概要: 対象コンテナと、その時点の注釈配列を一つの履歴状態として保持します。
    private struct CanvasAnnotationHistorySnapshot: Equatable {
        var target: CanvasAnnotationHistoryTarget
        var annotations: [OpenGraphiteCanvasAnnotation]
    }

    /// 論理名（日本語）: 付箋本文Draft
    /// 概要: debounce 中の本文をmanifest cacheから分離し、保存開始時の本文だけを競合判定基準として保持します。
    private struct StagedCanvasAnnotationTextDraft: Equatable {
        var target: CanvasAnnotationHistoryTarget
        var annotationID: String
        var baselineText: String
        var text: String
    }

    /// 論理名（日本語）: キャンバス注釈履歴項目
    /// 概要: 一度の `.ogp` atomic write の変更前後を、⌘Z／やり直しの一操作として保持します。
    private struct CanvasAnnotationHistoryEntry: Equatable {
        var projectURL: URL
        var target: CanvasAnnotationHistoryTarget
        var previousAnnotations: [OpenGraphiteCanvasAnnotation]
        var nextAnnotations: [OpenGraphiteCanvasAnnotation]
    }

    /// 論理名（日本語）: キャンバスガイド履歴対象
    /// 概要: `.ogp` 内で undo/redo のガイド配列を差し替える Chapter または Collection を識別します。
    private struct CanvasGuideHistoryTarget: Equatable {
        var segment: OpenGraphiteCanvasSegment
        var containerInternalID: String
    }

    /// 論理名（日本語）: キャンバスガイド履歴項目
    /// 概要: 一度の `.ogp` atomic write によるガイド変更前後を、⌘Z／やり直しの一操作として保持します。
    private struct CanvasGuideHistoryEntry: Equatable {
        var projectURL: URL
        var target: CanvasGuideHistoryTarget
        var previousGuides: [OpenGraphiteCanvasGuide]
        var nextGuides: [OpenGraphiteCanvasGuide]
    }

    /// 論理名（日本語）: キャンバス参照履歴対象
    /// 概要: `.ogp`内でundo/redoの参照配置配列を差し替えるChapterまたはCollectionを識別します。
    private struct CanvasReferenceHistoryTarget: Equatable {
        var segment: OpenGraphiteCanvasSegment
        var containerInternalID: String
    }

    /// 論理名（日本語）: キャンバス参照履歴項目
    /// 概要: 一度の`.ogp` atomic writeによる参照配置変更前後を、⌘Z／やり直しの一操作として保持します。
    private struct CanvasReferenceHistoryEntry: Equatable {
        var projectURL: URL
        var target: CanvasReferenceHistoryTarget
        var previousReferences: [OpenGraphiteCanvasReference]
        var nextReferences: [OpenGraphiteCanvasReference]
    }

    /// 論理名（日本語）: エディター統合履歴項目
    /// 概要: HTML、companion CSS、キャンバス注釈、ガイド、参照配置の保存操作を、domainをまたいだ一つの時系列として保持します。
    private enum EditorHistoryEntry: Equatable {
        case document(DocumentHistoryEntry)
        case canvasAnnotation(CanvasAnnotationHistoryEntry)
        case canvasGuide(CanvasGuideHistoryEntry)
        case canvasReference(CanvasReferenceHistoryEntry)

        /// 論理名（日本語）: 履歴Project URL
        /// 処理概要: 操作記録時に固定した `.ogp` URL を返します。
        var projectURL: URL {
            switch self {
            case let .document(entry):
                return entry.projectURL
            case let .canvasAnnotation(entry):
                return entry.projectURL
            case let .canvasGuide(entry):
                return entry.projectURL
            case let .canvasReference(entry):
                return entry.projectURL
            }
        }

        /// 論理名（日本語）: ページURL移行関数
        /// 処理概要: Page / Component の rename 後も HTML 履歴を適用できるよう対象 URL を置き換えます。
        ///
        /// - Parameters:
        ///   - currentURL: rename 前の HTML URL。
        ///   - nextURL: rename 後の HTML URL。
        /// - Returns: 必要に応じて page URL を更新した履歴項目。
        func migratingPageURL(from currentURL: URL, to nextURL: URL) -> EditorHistoryEntry {
            guard case var .document(entry) = self,
                  entry.pageURL.standardizedFileURL == currentURL.standardizedFileURL
            else {
                return self
            }
            entry.pageURL = nextURL.standardizedFileURL
            return .document(entry)
        }
    }

    /// 論理名（日本語）: エディター履歴表示情報
    /// 概要: 正本復元用の履歴項目とは分離して、利用者へ見せる対象名・操作名・簡易プレビューを保持します。
    ///
    /// プロパティ:
    /// - `objectName`: 操作対象オブジェクトの表示名。
    /// - `actionName`: 操作内容を表す短い表示名。
    /// - `previewKind`: 対象オブジェクトの簡易プレビュー種別。
    private struct EditorHistoryPresentation: Equatable {
        var objectName: String
        var actionName: String
        var previewKind: EditorHistoryPreviewKind
    }

    /// 論理名（日本語）: エディター履歴記録
    /// 概要: 正本復元用の統合履歴項目へ、記録時刻とサイドバー表示情報を結び付けます。
    ///
    /// プロパティ:
    /// - `id`: Undo / Redo 間の移動でも維持する操作識別子。
    /// - `timestamp`: 操作が正本へ確定した時刻。
    /// - `presentation`: サイドバーへ表示する対象情報。
    /// - `entry`: Undo / Redo で正本へ適用する履歴項目。
    private struct EditorHistoryRecord: Equatable {
        var id: UUID
        var timestamp: Date
        var presentation: EditorHistoryPresentation
        var entry: EditorHistoryEntry

        var projectURL: URL {
            entry.projectURL
        }

        /// 論理名（日本語）: 履歴記録ページURL移行関数
        /// 処理概要: 表示情報と時刻を維持したまま、内部のHTML履歴だけをrename後URLへ移します。
        ///
        /// - Parameters:
        ///   - currentURL: rename 前の HTML URL。
        ///   - nextURL: rename 後の HTML URL。
        /// - Returns: 必要に応じて page URL を更新した履歴記録。
        func migratingPageURL(from currentURL: URL, to nextURL: URL) -> EditorHistoryRecord {
            var migratedRecord = self
            migratedRecord.entry = entry.migratingPageURL(from: currentURL, to: nextURL)
            return migratedRecord
        }

        /// 論理名（日本語）: 履歴リスト項目生成関数
        /// 処理概要: 記録済み時刻と表示情報へ現在のUndo / Redo状態を加えて公開用の値を返します。
        ///
        /// - Parameter state: 現在の履歴表示状態。
        /// - Returns: 左サイドバー向けの履歴表示項目。
        func listItem(state: EditorHistoryItemState) -> EditorHistoryListItem {
            EditorHistoryListItem(
                id: id,
                timestamp: timestamp,
                objectName: presentation.objectName,
                actionName: presentation.actionName,
                previewKind: presentation.previewKind,
                state: state
            )
        }
    }

    /// 論理名（日本語）: HTML依存参照復元情報
    /// 概要: Component ファイル名変更時に書き換えた参照元 HTML を、失敗時に元へ戻すための最小情報を保持します。
    ///
    /// プロパティ:
    /// - `url`: 復元対象 HTML URL。
    /// - `data`: 変更前 HTML data。
    private struct HTMLDependencyRewriteBackup {
        var url: URL
        var data: Data
    }

    /// 論理名（日本語）: 選択ページ履歴準備関数
    /// 処理概要: 選択ページの HTML をディスクから読み込み、未登録であれば履歴の初期値にします。
    private func prepareHistoryForSelectedPage() {
        guard let selectedPageURL else {
            updateHistoryAvailability()
            return
        }

        if syncHistories[selectedPageURL] == nil,
           let html = readHTMLFromDisk(at: selectedPageURL) {
            syncHistories[selectedPageURL] = DocumentSyncHistory(initialHTML: html)
            lastKnownPageHTMLByURL[selectedPageURL] = html
        }
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: ページ履歴取得関数
    /// 処理概要: 指定ページの同期履歴を返し、未登録の場合はディスク上の HTML または fallback で初期化します。
    ///
    /// - Parameters:
    ///   - pageURL: 履歴を取得するページ URL。
    ///   - fallbackHTML: ディスク読み込みに失敗した場合の初期 HTML。
    /// - Returns: 指定ページの同期履歴。
    private func historyForPage(at pageURL: URL, fallbackHTML: String) -> DocumentSyncHistory {
        if let history = syncHistories[pageURL] {
            return history
        }

        let initialHTML = readHTMLFromDisk(at: pageURL) ?? fallbackHTML
        let history = DocumentSyncHistory(initialHTML: initialHTML)
        syncHistories[pageURL] = history
        return history
    }

    /// 論理名（日本語）: 現在HTML同期対象取得関数
    /// 処理概要: 現在選択中の HTML カードを object edit 用同期対象に変換します。
    private func currentHTMLSyncTarget() -> HTMLSyncTarget? {
        guard let selectedPage else { return nil }
        return htmlSyncTarget(for: selectedPage, segment: selectedDocumentSegment)
    }

    /// 論理名（日本語）: HTML同期対象page参照ID生成関数
    /// 処理概要: 選択状態に依存せず、固定済みdocument identityからproject-aware AgentCore APIへ渡すpage/component参照IDを生成します。
    ///
    /// - Parameter target: PagesまたはComponentsのHTML同期対象。
    /// - Returns: project内page/component参照ID。identityが空の場合は`nil`。
    private func pageReferenceID(for target: HTMLSyncTarget) -> String? {
        let containerID = target.identity.containerInternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageID = target.identity.pageInternalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !containerID.isEmpty, !pageID.isEmpty else { return nil }
        switch target.identity.segment {
        case .pages:
            return OpenGraphiteReferenceID.page(chapterID: containerID, pageID: pageID).stringValue
        case .components:
            return OpenGraphiteReferenceID.component(collectionID: containerID, componentID: pageID).stringValue
        }
    }

    /// 論理名（日本語）: CSS編集対象HTML同期先取得関数
    /// 処理概要: runtime 展開された component instance 内 node は component master の HTML/CSS を保存先にし、それ以外は現在表示中 HTML を保存先にします。
    ///
    /// - Parameter node: CSS declaration を編集する選択ノード。
    /// - Returns: CSS declaration の保存対象。解決できない場合は `nil`。
    private func cssEditTarget(for node: OpenGraphiteNode) -> HTMLSyncTarget? {
        if node.isRuntimeComponentGenerated,
           let source = componentSource(for: node),
           let componentTarget = htmlSyncTarget(forComponentSource: source) {
            return componentTarget
        }
        return currentHTMLSyncTarget()
    }

    /// 論理名（日本語）: Component source同期先取得関数
    /// 処理概要: Inspector が解決した component master 情報から、該当 component canvas の HTML 同期対象を取得します。
    ///
    /// - Parameter source: component master の場所を表す情報。
    /// - Returns: component canvas の同期対象。project から解決できない場合は `nil`。
    private func htmlSyncTarget(forComponentSource source: OpenGraphiteComponentSource) -> HTMLSyncTarget? {
        guard let loadedProject,
              let collection = loadedProject.project.collections.first(where: { $0.internalID == source.collectionInternalID }),
              let componentPage = collection.components.first(where: { $0.internalID == source.componentPageInternalID })
        else {
            return nil
        }
        return htmlSyncTarget(for: componentPage, segment: .components)
    }

    /// 論理名（日本語）: HTML同期対象検証関数
    /// 処理概要: object identity が現在の `.ogp` に残っており、解決 URL が固定済み URL と一致するか確認します。
    ///
    /// - Parameter target: 検証する同期対象。
    /// - Returns: 現在の project から解決した page。検証できない場合は `nil`。
    private func validateHTMLSyncTarget(_ target: HTMLSyncTarget) -> OpenGraphitePage? {
        guard let loadedProject,
              loadedProject.fileURL == target.identity.projectURL,
              let page = page(for: target.identity, in: loadedProject)
        else {
            reportHTMLObjectEditConflict()
            return nil
        }

        let resolvedURL = loadedProject.htmlURL(for: page).standardizedFileURL
        let fixedURL = target.htmlURL.standardizedFileURL
        guard resolvedURL == fixedURL, page.path == target.path else {
            reportHTMLObjectEditConflict()
            return nil
        }
        return page
    }

    /// 論理名（日本語）: HTMLカード解決関数
    /// 処理概要: HTML document identity から現在 project 内の page entry を解決します。
    ///
    /// - Parameters:
    ///   - identity: 解決する document identity。
    ///   - loadedProject: 検索対象 project。
    /// - Returns: 対応する page entry。見つからない場合は `nil`。
    private func page(for identity: HTMLDocumentIdentity, in loadedProject: LoadedOpenGraphiteProject) -> OpenGraphitePage? {
        switch identity.segment {
        case .pages:
            return loadedProject.project.chapters
                .first { $0.internalID == identity.containerInternalID }?
                .pages
                .first { $0.internalID == identity.pageInternalID }
        case .components:
            return loadedProject.project.collections
                .first { $0.internalID == identity.containerInternalID }?
                .components
                .first { $0.internalID == identity.pageInternalID }
        }
    }

    /// 論理名（日本語）: 既知HTML基準一致判定関数
    /// 処理概要: ディスク上の HTML が最後に把握した内容から変わっていないかを確認します。
    ///
    /// - Parameter pageURL: 確認する HTML URL。
    /// - Returns: 既知基準と一致する場合は `true`。
    private func diskHTMLMatchesKnownBaseline(at pageURL: URL) -> Bool {
        guard let baselineHTML = lastKnownPageHTMLByURL[pageURL] else { return true }
        guard let diskHTML = readHTMLFromDisk(at: pageURL) else { return false }
        return baselineHTML == diskHTML
    }

    /// 論理名（日本語）: HTMLオブジェクト編集適用関数
    /// 処理概要: 最新ディスク HTML に node 単位 mutation を適用し、同一 object の競合があれば上書きせず中止します。
    ///
    /// - Parameter edit: 適用する object edit。
    /// - Returns: 保存結果。
    @discardableResult
    private func applyHTMLObjectEdit(_ edit: HTMLObjectEdit) -> HTMLObjectEditResult {
        guard validateHTMLSyncTarget(edit.target) != nil else { return .failed }
        guard !cssMutationHasIncompleteProvenance(edit.operation) else {
            lastError = "一部stylesheetのsourceを読み取れないためCSSを変更できません。読み取り可能なsourceへ移してから再実行してください。"
            return .failed
        }
        guard let diskHTML = readHTMLFromDisk(at: edit.target.htmlURL) else {
            lastError = "HTMLを読み込めませんでした。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }

        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? edit.target.htmlURL)
        let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: edit.target.htmlURL)
        let document = OpenGraphiteHTMLDocument(html: diskHTML)
        guard objectEditBaselineMatches(
            edit.operation,
            in: document,
            companionCSS: companionCSS,
            contract: contract,
            activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL),
            target: edit.target
        ) else {
            reportHTMLObjectEditConflict()
            return .failed
        }

        if let cssResult = applyCompanionCSSObjectEditIfNeeded(edit, diskHTML: diskHTML, contract: contract) {
            return cssResult
        }

        let mutation = mutationResult(for: edit.operation, html: diskHTML, contract: contract)
        guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
            lastError = "HTMLの保存に失敗しました。ページを再読み込みしてからもう一度設定してください。"
            return .failed
        }
        if mutation.html == diskHTML {
            return .noChange
        }

        do {
            let persisted = try htmlObjectEditPersistencePayload(
                for: edit,
                mutationHTML: mutation.html,
                contract: contract
            )
            let previousCompanionCSS = companionCSSHistorySnapshot(for: edit.target.htmlURL)
            let companionCSSChanged = persisted.companionCSS.map {
                $0.css != (previousCompanionCSS ?? "")
            } ?? false
            if persisted.html == diskHTML && !companionCSSChanged {
                return .noChange
            }

            try persisted.html.write(to: edit.target.htmlURL, atomically: true, encoding: .utf8)
            if companionCSSChanged, let companionCSS = persisted.companionCSS {
                try companionCSS.write(forHTMLURL: edit.target.htmlURL)
            }
            lastKnownPageHTMLByURL[edit.target.htmlURL] = persisted.html
            var history = historyForPage(at: edit.target.htmlURL, fallbackHTML: diskHTML)
            let didRecordHistory = history.recordSync(html: persisted.html)
            syncHistories[edit.target.htmlURL] = history
            let companionCSSChange = companionCSSChanged
                ? CompanionCSSHistoryChange(
                    previousCSS: previousCompanionCSS,
                    nextCSS: companionCSSHistorySnapshot(for: edit.target.htmlURL)
                )
                : nil
            if (didRecordHistory || companionCSSChange != nil),
               let projectURL = loadedProject?.fileURL {
                recordDocumentHistory(
                    projectURL: projectURL,
                    pageURL: edit.target.htmlURL,
                    advancesHTMLHistory: didRecordHistory,
                    companionCSSChange: companionCSSChange
                )
            } else {
                updateHistoryAvailability()
            }
            statusMessage = "\(edit.target.htmlURL.lastPathComponent) と同期しました。"
            return HTMLObjectEditResult(updated: true, requiresReload: edit.operation.requiresWebViewReload)
        } catch {
            lastError = "HTMLの同期に失敗しました: \(error.localizedDescription)"
            return .failed
        }
    }

    /// 論理名（日本語）: CSS source provenance不足編集拒否判定関数
    /// 処理概要: WebKitまたはShared source graphが読み取り不能stylesheetを報告したnodeへのCSS保存を拒否し、computed inspectionだけを許可します。
    ///
    /// - Parameter operation: 保存予定のHTML object edit操作。
    /// - Returns: 対象CSS mutationを安全にsourceへrebaseできない場合は`true`。
    private func cssMutationHasIncompleteProvenance(_ operation: HTMLObjectEditOperation) -> Bool {
        let nodeInternalID: String
        switch operation {
        case let .setCSSVariable(candidate, _, _, _),
             let .setCSSVariables(candidate, _, _):
            nodeInternalID = candidate
        default:
            return false
        }
        return nodes.contains { node in
            node.hasIncompleteCSSProvenance
                && (node.internalID == nodeInternalID || node.sourceNodeInternalID == nodeInternalID)
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集永続化payload生成関数
    /// 処理概要: HTML mutation の保存内容を整え、挿入HTML内の editable design value を companion CSS へ移します。
    ///
    /// - Parameters:
    ///   - edit: 適用中の object edit。
    ///   - mutationHTML: HTML mutation 後の候補HTML。
    ///   - contract: CSS declaration の判定に使う OpenGraphite 契約。
    /// - Returns: 保存する HTML と、更新が必要な companion CSS。
    private func htmlObjectEditPersistencePayload(
        for edit: HTMLObjectEdit,
        mutationHTML: String,
        contract: OpenGraphiteContract
    ) throws -> (html: String, companionCSS: OpenGraphiteCompanionCSSDocument?) {
        guard case .insertHTML = edit.operation else {
            return (mutationHTML, nil)
        }

        let runtimeSanitizedHTML = OpenGraphiteHTMLDocument(html: mutationHTML)
            .removingRuntimeState(contract: contract)
        let legacyDocument = OpenGraphiteHTMLDocument(html: runtimeSanitizedHTML)
        let sanitizedHTML = legacyDocument.removingOpenGraphiteStyleVariables(contract: contract)
        var companionCSS = try OpenGraphiteCompanionCSSDocument.read(forHTMLURL: edit.target.htmlURL)
        migrateInlineOpenGraphiteCSSVariables(from: legacyDocument, into: &companionCSS, contract: contract)
        return (sanitizedHTML, companionCSS)
    }

    /// 論理名（日本語）: Inline design value移行関数
    /// 処理概要: HTML inline style に残る OpenGraphite 編集対象 CSS declaration を companion CSS へ移します。
    ///
    /// - Parameters:
    ///   - document: inline style を含み得る HTML 文書。
    ///   - companionCSS: 移行先の companion CSS 文書。
    ///   - contract: CSS declaration の判定に使う OpenGraphite 契約。
    private func migrateInlineOpenGraphiteCSSVariables(
        from document: OpenGraphiteHTMLDocument,
        into companionCSS: inout OpenGraphiteCompanionCSSDocument,
        contract: OpenGraphiteContract
    ) {
        for node in document.nodes(contract: contract) {
            guard !node.internalID.isEmpty else { continue }
            let existingVariables = companionCSS.cssVariables(forNodeInternalID: node.internalID, contract: contract)
            for key in node.cssVariables.keys.sorted()
                where !contract.runtimeCSSVariableSet.contains(key) && existingVariables[key] == nil {
                companionCSS.setCSSVariable(key, value: node.cssVariables[key] ?? "", forNodeInternalID: node.internalID)
            }
        }
    }

    /// 論理名（日本語）: HTMLオブジェクト編集payload変換関数
    /// 処理概要: JavaScript bridge payload を Swift の object edit へ変換します。
    ///
    /// - Parameters:
    ///   - payload: JavaScript から届いた辞書。
    ///   - target: 保存対象 HTML。
    /// - Returns: 変換済み object edit。形式不正の場合は `nil`。
    private func htmlObjectEdit(from payload: [String: Any], target: HTMLSyncTarget) -> HTMLObjectEdit? {
        guard let operation = payload["operation"] as? String else { return nil }

        switch operation {
        case "setCSSVariable":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let key = payload["key"] as? String
            else {
                return nil
            }
            let expectedOldValue = cssVariableBaselineValues(
                for: nodeInternalID,
                keys: [key],
                target: target,
                fallback: [key: payload["previousValue"] as? String ?? ""]
            )[key] ?? ""
            return HTMLObjectEdit(
                target: target,
                operation: .setCSSVariable(
                    nodeInternalID: nodeInternalID,
                    key: key,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: expectedOldValue
                )
            )
        case "setCSSVariables":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let values = payload["values"] as? [String: String]
            else {
                return nil
            }
            let expectedOldValues = cssVariableBaselineValues(
                for: nodeInternalID,
                keys: Array(values.keys),
                target: target,
                fallback: payload["previousValues"] as? [String: String] ?? [:]
            )
            return HTMLObjectEdit(
                target: target,
                operation: .setCSSVariables(
                    nodeInternalID: nodeInternalID,
                    values: values,
                    expectedOldValues: expectedOldValues
                )
            )
        case "setAttribute":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let name = payload["name"] as? String
            else {
                return nil
            }
            if payload["removeAttribute"] as? Bool == true {
                return HTMLObjectEdit(
                    target: target,
                    operation: .removeAttribute(
                        nodeInternalID: nodeInternalID,
                        name: name,
                        expectedOldValue: payload["previousValue"] as? String ?? "",
                        expectedOldPresence: payload["previousAttributePresent"] as? Bool ?? true
                    )
                )
            }
            return HTMLObjectEdit(
                target: target,
                operation: .setAttribute(
                    nodeInternalID: nodeInternalID,
                    name: name,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? "",
                    expectedOldPresence: payload["previousAttributePresent"] as? Bool
                )
            )
        case "renameNodeID":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .renameNodeID(
                    nodeInternalID: nodeInternalID,
                    value: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? ""
                )
            )
        case "setIcon":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .setIcon(
                    nodeInternalID: nodeInternalID,
                    library: payload["library"] as? String ?? OpenGraphiteIconMarkup.defaultLibrary,
                    name: payload["name"] as? String ?? OpenGraphiteIconMarkup.defaultName,
                    source: payload["source"] as? String ?? OpenGraphiteIconMarkup.defaultSource,
                    expectedOldValues: payload["previousValues"] as? [String: String] ?? [:]
                )
            )
        case "setTextContent":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .setTextContent(
                    nodeInternalID: nodeInternalID,
                    text: payload["value"] as? String ?? "",
                    expectedOldValue: payload["previousValue"] as? String ?? ""
                )
            )
        case "insertHTML":
            guard let anchorInternalID = payload["anchorInternalID"] as? String,
                  let positionValue = payload["position"] as? String,
                  let position = OpenGraphiteHTMLInsertionPosition(rawValue: positionValue),
                  let html = payload["html"] as? String
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .insertHTML(
                    anchorInternalID: anchorInternalID,
                    position: position,
                    html: html,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: anchorInternalID)
                )
            )
        case "replaceNodeHTML":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let html = payload["html"] as? String
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .replaceNodeHTML(
                    nodeInternalID: nodeInternalID,
                    html: html,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        case "deleteNode":
            guard let nodeInternalID = payload["nodeInternalID"] as? String else { return nil }
            return HTMLObjectEdit(
                target: target,
                operation: .deleteNode(
                    nodeInternalID: nodeInternalID,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        case "moveNode":
            guard let nodeInternalID = payload["nodeInternalID"] as? String,
                  let targetInternalID = payload["targetInternalID"] as? String,
                  let positionValue = payload["position"] as? String,
                  let position = OpenGraphiteHTMLInsertionPosition(rawValue: positionValue)
            else {
                return nil
            }
            return HTMLObjectEdit(
                target: target,
                operation: .moveNode(
                    nodeInternalID: nodeInternalID,
                    targetInternalID: targetInternalID,
                    position: position,
                    baselineNodeHash: baselineNodeHash(for: target, nodeInternalID: nodeInternalID)
                )
            )
        default:
            return nil
        }
    }

    /// 論理名（日本語）: CSS宣言baseline値取得関数
    /// 処理概要: DOM payload の inline style 旧値ではなく、ディスク上 HTML と companion CSS の正本値を編集基準にします。
    ///
    /// - Parameters:
    ///   - nodeInternalID: 対象 node の `data-og-internal-id`。
    ///   - keys: 取得する CSS property または OpenGraphite 予約 custom property 名。
    ///   - target: 保存対象 HTML。
    ///   - fallback: 正本から読めない場合に使う payload 由来の旧値。
    /// - Returns: CSS property または OpenGraphite 予約 custom property 名ごとの baseline 値。
    private func cssVariableBaselineValues(
        for nodeInternalID: String,
        keys: [String],
        target: HTMLSyncTarget,
        fallback: [String: String]
    ) -> [String: String] {
        guard let html = readHTMLFromDisk(at: target.htmlURL) else { return fallback }
        let contract = OpenGraphiteContract.loadDefault(startingAt: projectRootURL ?? target.htmlURL)
        let companionCSS = try? OpenGraphiteCompanionCSSDocument.existing(forHTMLURL: target.htmlURL)
        let sourceNode = sourceNodeForCSSBaseline(
            nodeInternalID: nodeInternalID,
            target: target,
            document: OpenGraphiteHTMLDocument(html: html),
            companionCSS: companionCSS,
            activeMediaQueries: activeMediaQueries(for: target.htmlURL),
            contract: contract
        )
        return keys.reduce(into: [String: String]()) { result, key in
            if Self.relatedStyleProperties.contains(key) {
                result[key] = sourceNode?.renderingTargets.lazy
                    .compactMap { $0.authoredValues[key] }
                    .first ?? fallback[key] ?? ""
                return
            }
            result[key] = sourceNode?.cssVariables[key] ?? fallback[key] ?? ""
        }
    }

    /// 論理名（日本語）: CSS宣言期待旧値取得関数
    /// 処理概要: Inspector 表示由来の既定値ではなく、payload 取り込み時に正本 CSS に存在した値を編集基準として返します。
    ///
    /// - Parameters:
    ///   - node: 対象 node。
    ///   - key: 更新する CSS property または OpenGraphite 予約 custom property 名。
    ///   - fallback: 正本 baseline がない場合に使う旧値。
    /// - Returns: object edit に渡す期待旧値。
    private func expectedOldCSSVariableValue(
        for node: OpenGraphiteNode,
        key: String,
        fallback: String
    ) -> String {
        guard let baseline = cssVariableBaselinesByInternalID[node.internalID] else {
            return fallback
        }
        return baseline[key] ?? ""
    }

    /// 論理名（日本語）: 編集対象CSS authored値取得関数
    /// 処理概要: wrapper 自身の CSS と描画実体の標準 CSS を同じ編集経路で比較できるよう、保存対象に応じた authored 値を返します。
    ///
    /// - Parameters:
    ///   - key: CSS property または OpenGraphite 予約 custom property 名。
    ///   - node: 値を保持する Inspector node。
    /// - Returns: 描画実体 property では render target の authored value、それ以外は wrapper の CSS declaration 値。
    private static func authoredCSSValue(for key: String, in node: OpenGraphiteNode) -> String {
        if relatedStyleProperties.contains(key) {
            return node.renderTarget(for: key)?.authoredValue ?? ""
        }
        return node.cssVariables[key] ?? ""
    }

    /// 論理名（日本語）: CSS宣言baseline更新関数
    /// 処理概要: companion CSS への保存成功後、次回編集の競合判定に使う正本 baseline を更新します。
    ///
    /// - Parameter operation: 保存に成功した object edit operation。
    private func recordCSSVariableBaselineUpdate(for operation: HTMLObjectEditOperation) {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, value, _):
            recordCSSVariableBaseline(nodeInternalID: nodeInternalID, key: key, value: value)
        case let .setCSSVariables(nodeInternalID, values, _):
            for (key, value) in values {
                recordCSSVariableBaseline(nodeInternalID: nodeInternalID, key: key, value: value)
            }
        default:
            break
        }
    }

    /// 論理名（日本語）: CSS宣言baseline単項更新関数
    /// 処理概要: 指定 node の CSS declaration について、保存済み baseline 値を追加・更新・削除します。
    ///
    /// - Parameters:
    ///   - nodeInternalID: 対象 node の `data-og-internal-id`。
    ///   - key: CSS property または OpenGraphite 予約 custom property 名。
    ///   - value: 保存後の値。空文字列の場合は declaration 削除として扱います。
    private func recordCSSVariableBaseline(nodeInternalID: String, key: String, value: String) {
        guard !nodeInternalID.isEmpty else { return }
        var baseline = cssVariableBaselinesByInternalID[nodeInternalID] ?? [:]
        if value.isEmpty {
            baseline.removeValue(forKey: key)
        } else {
            baseline[key] = value
        }
        cssVariableBaselinesByInternalID[nodeInternalID] = baseline
    }

    /// 論理名（日本語）: HTML別active media condition取得関数
    /// 処理概要: WebKitがsame-origin stylesheetから収集した現在match中のauthored `@media` conditionをsource cascadeへ渡し、runtime component保存先には表示中Pageのviewport条件を引き継ぎます。
    ///
    /// - Parameter htmlURL: 表示中HTMLのURL。
    /// - Returns: 重複を除いた安定順のcondition一覧。未収集時は空配列。
    private func activeMediaQueries(for htmlURL: URL) -> [String] {
        let standardizedURL = htmlURL.standardizedFileURL
        if let currentURL = currentHTMLSyncTarget()?.htmlURL.standardizedFileURL,
           currentURL != standardizedURL,
           let current = activeMediaQueriesByHTMLURL[currentURL] {
            return current
        }
        return activeMediaQueriesByHTMLURL[standardizedURL] ?? []
    }

    /// 論理名（日本語）: オブジェクト編集基準一致判定関数
    /// 処理概要: 対象 node の旧値または subtree hash が最新ディスク HTML と一致するか確認します。
    ///
    /// - Parameters:
    ///   - operation: 検証する編集操作。
    ///   - document: 最新ディスク HTML document。
    ///   - activeMediaQueries: WebKitで現在match中のauthored `@media` condition。
    ///   - target: project CSSを含むpage graphの解決対象。
    /// - Returns: 競合がない場合は `true`。
    private func objectEditBaselineMatches(
        _ operation: HTMLObjectEditOperation,
        in document: OpenGraphiteHTMLDocument,
        companionCSS: OpenGraphiteCompanionCSSDocument?,
        contract: OpenGraphiteContract,
        activeMediaQueries: [String],
        target: HTMLSyncTarget
    ) -> Bool {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, _, expectedOldValue):
            guard let node = sourceNodeForCSSBaseline(
                nodeInternalID: nodeInternalID,
                target: target,
                document: document,
                companionCSS: companionCSS,
                activeMediaQueries: activeMediaQueries,
                contract: contract
            ) else { return false }
            if Self.relatedStyleProperties.contains(key) {
                let authoredValue = node.renderingTargets.lazy
                    .compactMap { $0.authoredValues[key] }
                    .first ?? ""
                return authoredValue == expectedOldValue
            }
            return (node.cssVariables[key] ?? "") == expectedOldValue
        case let .setCSSVariables(nodeInternalID, _, expectedOldValues):
            guard let node = sourceNodeForCSSBaseline(
                nodeInternalID: nodeInternalID,
                target: target,
                document: document,
                companionCSS: companionCSS,
                activeMediaQueries: activeMediaQueries,
                contract: contract
            ) else { return false }
            return expectedOldValues.allSatisfy { key, value in
                if Self.relatedStyleProperties.contains(key) {
                    let authoredValue = node.renderingTargets.lazy
                        .compactMap { $0.authoredValues[key] }
                        .first ?? ""
                    return authoredValue == value
                }
                return (node.cssVariables[key] ?? "") == value
            }
        case let .setAttribute(nodeInternalID, name, _, expectedOldValue, expectedOldPresence):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            let authoredAttribute = node.attributes.first { attributeName, _ in
                attributeName.caseInsensitiveCompare(name) == .orderedSame
            }
            if let expectedOldPresence {
                guard (authoredAttribute != nil) == expectedOldPresence else { return false }
                return !expectedOldPresence || authoredAttribute?.value == expectedOldValue
            }
            return (authoredAttribute?.value ?? "") == expectedOldValue
        case let .removeAttribute(nodeInternalID, name, expectedOldValue, expectedOldPresence):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            let authoredAttribute = node.attributes.first { attributeName, _ in
                attributeName.caseInsensitiveCompare(name) == .orderedSame
            }
            return (authoredAttribute != nil) == expectedOldPresence
                && (authoredAttribute?.value ?? "") == expectedOldValue
        case let .renameNodeID(nodeInternalID, _, expectedOldValue):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return node.id == expectedOldValue
        case let .setIcon(nodeInternalID, _, _, _, expectedOldValues):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return expectedOldValues.allSatisfy { key, value in
                (node.attributes[key] ?? "") == value
            }
        case let .setTextContent(nodeInternalID, _, expectedOldValue):
            guard let node = document.nodes().first(where: { $0.internalID == nodeInternalID }) else { return false }
            return (node.textContent ?? "") == expectedOldValue
        case let .insertHTML(anchorInternalID, _, _, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: anchorInternalID, in: document)
        case let .replaceNodeHTML(nodeInternalID, _, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        case let .deleteNode(nodeInternalID, baselineNodeHash):
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        case let .moveNode(nodeInternalID, targetInternalID, _, baselineNodeHash):
            guard document.elementHTMLHash(forNodeID: targetInternalID) != nil else { return false }
            return nodeHashMatches(baselineNodeHash, nodeInternalID: nodeInternalID, in: document)
        }
    }

    /// 論理名（日本語）: Project-aware CSS baselineノード取得関数
    /// 処理概要: project CSS、companion CSS、active mediaを含むpage graphを優先し、standalone時だけHTML source graphへfallbackします。
    ///
    /// - Parameters:
    ///   - nodeInternalID: 対象nodeのinternal ID。
    ///   - target: project内HTML同期対象。
    ///   - document: fallback用HTML document。
    ///   - companionCSS: fallback用companion CSS。
    ///   - activeMediaQueries: WebKitでmatch中のauthored media condition。
    ///   - contract: CSS契約。
    /// - Returns: project-wide cascadeを反映した対象node。未解決時は`nil`。
    private func sourceNodeForCSSBaseline(
        nodeInternalID: String,
        target: HTMLSyncTarget,
        document: OpenGraphiteHTMLDocument,
        companionCSS: OpenGraphiteCompanionCSSDocument?,
        activeMediaQueries: [String],
        contract: OpenGraphiteContract
    ) -> OpenGraphiteAgentNode? {
        if let pageID = pageReferenceID(for: target),
           let graph = try? OpenGraphiteAgentCore(contract: contract).pageGraph(
               projectURL: target.identity.projectURL,
               pageID: pageID,
               activeMediaQueries: activeMediaQueries
           ),
           let node = graph.nodes.first(where: { $0.internalID == nodeInternalID }) {
            return node
        }
        return document.nodes(
            companionCSS: companionCSS,
            activeMediaQueries: activeMediaQueries,
            contract: contract
        ).first { $0.internalID == nodeInternalID }
    }

    /// 論理名（日本語）: Agent coreオブジェクト編集適用関数
    /// 処理概要: CSS declaration や icon 更新を Editor 専用 HTML mutation ではなく AgentCore の正本保存経路へ通します。
    ///
    /// - Parameters:
    ///   - edit: 適用する object edit。
    ///   - diskHTML: 編集前の最新ディスク HTML。
    ///   - contract: 検証に使う OpenGraphite 契約。
    /// - Returns: CSS 編集として処理した場合は保存結果。それ以外は `nil`。
    private func applyCompanionCSSObjectEditIfNeeded(
        _ edit: HTMLObjectEdit,
        diskHTML: String,
        contract: OpenGraphiteContract
    ) -> HTMLObjectEditResult? {
        do {
            let core = OpenGraphiteAgentCore(contract: contract)
            let previousCompanionCSS = companionCSSHistorySnapshot(for: edit.target.htmlURL)
            var lastResult: OpenGraphiteEditResult?
            switch edit.operation {
            case let .setCSSVariable(nodeInternalID, key, value, _):
                if Self.relatedStyleProperties.contains(key) {
                    if let pageID = pageReferenceID(for: edit.target) {
                        lastResult = try core.setRelatedStyleDeclaration(
                            key,
                            value: value,
                            wrapperNodeID: nodeInternalID,
                            projectURL: edit.target.identity.projectURL,
                            pageID: pageID,
                            activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                        )
                    } else {
                        lastResult = try core.setRelatedStyleDeclaration(
                            key,
                            value: value,
                            wrapperNodeID: nodeInternalID,
                            htmlURL: edit.target.htmlURL,
                            activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                        )
                    }
                } else {
                    if let pageID = pageReferenceID(for: edit.target) {
                        lastResult = try core.setCSSVariable(
                            key,
                            value: value,
                            nodeID: nodeInternalID,
                            projectURL: edit.target.identity.projectURL,
                            pageID: pageID,
                            activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                        )
                    } else {
                        lastResult = try core.setCSSVariable(
                            key,
                            value: value,
                            nodeID: nodeInternalID,
                            htmlURL: edit.target.htmlURL,
                            activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                        )
                    }
                }
            case let .setCSSVariables(nodeInternalID, values, _):
                for key in values.keys.sorted() {
                    if Self.relatedStyleProperties.contains(key) {
                        if let pageID = pageReferenceID(for: edit.target) {
                            lastResult = try core.setRelatedStyleDeclaration(
                                key,
                                value: values[key] ?? "",
                                wrapperNodeID: nodeInternalID,
                                projectURL: edit.target.identity.projectURL,
                                pageID: pageID,
                                activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                            )
                        } else {
                            lastResult = try core.setRelatedStyleDeclaration(
                                key,
                                value: values[key] ?? "",
                                wrapperNodeID: nodeInternalID,
                                htmlURL: edit.target.htmlURL,
                                activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                            )
                        }
                    } else {
                        if let pageID = pageReferenceID(for: edit.target) {
                            lastResult = try core.setCSSVariable(
                                key,
                                value: values[key] ?? "",
                                nodeID: nodeInternalID,
                                projectURL: edit.target.identity.projectURL,
                                pageID: pageID,
                                activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                            )
                        } else {
                            lastResult = try core.setCSSVariable(
                                key,
                                value: values[key] ?? "",
                                nodeID: nodeInternalID,
                                htmlURL: edit.target.htmlURL,
                                activeMediaQueries: activeMediaQueries(for: edit.target.htmlURL)
                            )
                        }
                    }
                }
            case let .setIcon(nodeInternalID, library, name, source, _):
                lastResult = try core.setIcon(
                    library: library,
                    name: name,
                    source: source,
                    nodeID: nodeInternalID,
                    htmlURL: edit.target.htmlURL
                )
            default:
                return nil
            }

            if lastResult?.diagnostics.contains(where: { $0.severity == .error }) == true {
                lastError = "変更の保存に失敗しました。ページを再読み込みしてからもう一度設定してください。"
                return .failed
            }

            let nextHTML = readHTMLFromDisk(at: edit.target.htmlURL)
            let nextCompanionCSS = companionCSSHistorySnapshot(for: edit.target.htmlURL)
            if let nextHTML {
                lastKnownPageHTMLByURL[edit.target.htmlURL] = nextHTML
                var history = historyForPage(at: edit.target.htmlURL, fallbackHTML: diskHTML)
                let didRecordHistory = history.recordSync(html: nextHTML)
                syncHistories[edit.target.htmlURL] = history
                let companionCSSChange = previousCompanionCSS != nextCompanionCSS
                    ? CompanionCSSHistoryChange(
                        previousCSS: previousCompanionCSS,
                        nextCSS: nextCompanionCSS
                    )
                    : nil
                if (didRecordHistory || companionCSSChange != nil),
                   let projectURL = loadedProject?.fileURL {
                    recordDocumentHistory(
                        projectURL: projectURL,
                        pageURL: edit.target.htmlURL,
                        advancesHTMLHistory: didRecordHistory,
                        companionCSSChange: companionCSSChange
                    )
                } else {
                    updateHistoryAvailability()
                }
            }

            statusMessage = "\(OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: edit.target.htmlURL).lastPathComponent) と同期しました。"
            let result = HTMLObjectEditResult(
                updated: (lastResult?.updated ?? false)
                    || previousCompanionCSS != nextCompanionCSS
                    || diskHTML != nextHTML,
                requiresReload: edit.operation.requiresWebViewReload
            )
            if result.updated {
                recordCSSVariableBaselineUpdate(for: edit.operation)
            }
            return result
        } catch {
            lastError = "CSSの同期に失敗しました: \(error.localizedDescription)"
            return .failed
        }
    }

    /// 論理名（日本語）: ノードhash一致判定関数
    /// 処理概要: baseline がある場合に最新ディスク HTML の node subtree hash と比較します。
    private func nodeHashMatches(_ baselineNodeHash: String?, nodeInternalID: String, in document: OpenGraphiteHTMLDocument) -> Bool {
        guard let currentHash = document.elementHTMLHash(forNodeID: nodeInternalID) else { return false }
        guard let baselineNodeHash else { return true }
        return currentHash == baselineNodeHash
    }

    /// 論理名（日本語）: HTMLオブジェクトmutation生成関数
    /// 処理概要: object edit operation を既存の HTML document mutation API へ変換します。
    private func mutationResult(
        for operation: HTMLObjectEditOperation,
        html: String,
        contract: OpenGraphiteContract
    ) -> OpenGraphiteHTMLMutationResult {
        switch operation {
        case let .setCSSVariable(nodeInternalID, key, value, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingCSSVariable(key, value: value, forNodeID: nodeInternalID, contract: contract)
        case let .setCSSVariables(nodeInternalID, values, _):
            var currentHTML = html
            for key in values.keys.sorted() {
                let mutation = OpenGraphiteHTMLDocument(html: currentHTML)
                    .settingCSSVariable(key, value: values[key] ?? "", forNodeID: nodeInternalID, contract: contract)
                guard mutation.diagnostics.filter({ $0.severity == .error }).isEmpty else {
                    return mutation
                }
                currentHTML = mutation.html
            }
            return OpenGraphiteHTMLMutationResult(html: currentHTML, diagnostics: [])
        case let .setAttribute(nodeInternalID, name, value, _, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingAttribute(name: name, value: value, forNodeID: nodeInternalID, contract: contract)
        case let .removeAttribute(nodeInternalID, name, _, _):
            return OpenGraphiteHTMLDocument(html: html)
                .removingAttribute(name: name, forNodeID: nodeInternalID, contract: contract)
        case let .renameNodeID(nodeInternalID, value, _):
            return OpenGraphiteHTMLDocument(html: html)
                .renamingNodeID(value: value, forNodeID: nodeInternalID, contract: contract)
        case let .setIcon(nodeInternalID, library, name, source, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingIcon(library: library, name: name, source: source, forNodeID: nodeInternalID, contract: contract)
        case let .setTextContent(nodeInternalID, text, _):
            return OpenGraphiteHTMLDocument(html: html)
                .settingTextContent(text, forNodeID: nodeInternalID, contract: contract)
        case let .insertHTML(anchorInternalID, position, fragmentHTML, _):
            return OpenGraphiteHTMLDocument(html: html)
                .insertingHTML(fragmentHTML, relativeToNodeID: anchorInternalID, position: position, contract: contract)
        case let .replaceNodeHTML(nodeInternalID, replacementHTML, _):
            return OpenGraphiteHTMLDocument(html: html)
                .replacingNodeHTML(replacementHTML, nodeID: nodeInternalID, contract: contract)
        case let .deleteNode(nodeInternalID, _):
            return OpenGraphiteHTMLDocument(html: html)
                .deletingNode(nodeID: nodeInternalID, contract: contract)
        case let .moveNode(nodeInternalID, targetInternalID, position, _):
            return OpenGraphiteHTMLDocument(html: html)
                .movingNode(nodeID: nodeInternalID, relativeToNodeID: targetInternalID, position: position, contract: contract)
        }
    }

    /// 論理名（日本語）: baselineノードhash取得関数
    /// 処理概要: 最後に把握した HTML から対象 node subtree の hash を取得します。
    private func baselineNodeHash(for target: HTMLSyncTarget, nodeInternalID: String) -> String? {
        guard let baselineHTML = lastKnownPageHTMLByURL[target.htmlURL] else { return nil }
        return OpenGraphiteHTMLDocument(html: baselineHTML).elementHTMLHash(forNodeID: nodeInternalID)
    }

    /// 論理名（日本語）: テキストmutation発行関数
    /// 処理概要: app 内 cache 上の text 変更を WebView へ反映するための mutation を発行します。
    ///
    /// - Parameters:
    ///   - pageURL: 反映対象 HTML の URL。
    ///   - nodeID: 反映対象 node の表示 ID。
    ///   - value: WebView へ渡す text 値。
    ///   - mode: fallback / resolved の反映モード。
    private func publishTextMutation(
        pageURL: URL,
        nodeID: String,
        value: String,
        mode: NodeTextContentMutationMode
    ) {
        textMutationSequence += 1
        textMutation = NodeTextContentMutation(
            sequence: textMutationSequence,
            pageURL: pageURL,
            nodeID: nodeID,
            value: value,
            mode: mode
        )
    }

    /// 論理名（日本語）: HTMLオブジェクト編集競合報告関数
    /// 処理概要: 同時編集や path 変更を検出したときに、上書きせず再設定を促す簡易エラーを表示します。
    private func reportHTMLObjectEditConflict() {
        lastError = "HTMLが別の編集で更新されています。ページを再読み込みしてからもう一度設定してください。"
    }

    /// 論理名（日本語）: 選択ノードテキストfallback値取得関数
    /// 処理概要: binding text では HTML 正本の fallback、literal text では現在の本文を編集基準値として返します。
    ///
    /// - Parameter node: 基準値を取得する text node。
    /// - Returns: Inspector から保存する text content の現在値。
    private func selectedNodeTextFallbackValue(_ node: OpenGraphiteNode) -> String {
        node.fallbackTextContent ?? node.textContent ?? ""
    }

    /// 論理名（日本語）: Active Resolved locale解決関数
    /// 処理概要: i18n runtime の locale field、preview mock state、HTML lang fallback から表示中 locale を解決します。
    ///
    /// - Returns: 表示中 text resource の locale。解決できない場合は `nil`。
    private func activeResolvedTextLocale() -> String? {
        let inspection = selectedI18nRuntimeInspection
        let previewContext = selectedPage?.canvas.previewContext ?? .empty
        if let localeField = Self.nonEmptyTrimmed(inspection?.localeField),
           let locale = Self.nonEmptyTrimmed(previewContext.fieldMocks[localeField]) {
            return locale
        }

        let htmlContext = selectedHTMLDocumentContext
        if htmlContext.langSource == .binding,
           let locale = Self.nonEmptyTrimmed(previewContext.fieldMocks[htmlContext.langField]) {
            return locale
        }

        if let locale = Self.nonEmptyTrimmed(previewContext.locale) {
            return locale
        }
        return Self.nonEmptyTrimmed(htmlContext.langValue)
    }

    /// 論理名（日本語）: Active Resolved locale一致判定関数
    /// 処理概要: 指定 locale が現在 preview 表示中の locale と一致するかを判定します。
    ///
    /// - Parameter locale: 判定対象 locale。
    /// - Returns: active preview locale と一致する場合は `true`。
    private func isActiveResolvedLocale(_ locale: String) -> Bool {
        activeResolvedTextLocale() == locale
    }

    /// 論理名（日本語）: i18nテキストresource値読込関数
    /// 処理概要: flat locale JSON から指定 key の文字列値だけを読み取ります。
    ///
    /// - Parameters:
    ///   - url: locale JSON URL。
    ///   - key: 読み取る i18n key。
    /// - Returns: resource に保存された文字列値。未作成、非文字列、読込失敗時は `nil`。
    private static func i18nTextResourceValue(at url: URL, key: String) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let resource = object as? [String: Any]
        else {
            return nil
        }
        return resource[key] as? String
    }

    /// 論理名（日本語）: 空でないtrim済み文字列取得関数
    /// 処理概要: 前後空白と改行を除去し、空文字の場合は `nil` にします。
    ///
    /// - Parameter value: 正規化する文字列。
    /// - Returns: 空でない trim 済み文字列。
    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }

    /// 論理名（日本語）: HTMLディスク読み込み関数
    /// 処理概要: 指定 URL の HTML を UTF-8 文字列として読み込みます。
    ///
    /// - Parameter pageURL: 読み込み対象の HTML ファイル URL。
    /// - Returns: 読み込めた HTML。失敗時は `nil`。
    private func readHTMLFromDisk(at pageURL: URL) -> String? {
        try? String(contentsOf: pageURL, encoding: .utf8)
    }

    /// 論理名（日本語）: Companion CSS履歴スナップショット取得関数
    /// 処理概要: 指定HTMLと同名のcompanion CSSをUTF-8文字列として読み込み、ファイル未作成状態は`nil`で保持します。
    ///
    /// - Parameter pageURL: companion CSSの基準になるHTML URL。
    /// - Returns: 読み込めたCSS。ファイルが存在しない、または読み込めない場合は`nil`。
    private func companionCSSHistorySnapshot(for pageURL: URL) -> String? {
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: pageURL)
        return try? String(contentsOf: cssURL, encoding: .utf8)
    }

    /// 論理名（日本語）: Companion CSS履歴スナップショット書き込み関数
    /// 処理概要: 履歴スナップショットが文字列ならatomic writeし、`nil`なら編集前の未作成状態へ戻します。
    ///
    /// - Parameters:
    ///   - css: 復元するCSS。`nil`はcompanion CSSファイルを存在させない状態。
    ///   - pageURL: companion CSSの基準になるHTML URL。
    private func writeCompanionCSSHistorySnapshot(_ css: String?, for pageURL: URL) throws {
        let cssURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: pageURL)
        if let css {
            try css.write(to: cssURL, atomically: true, encoding: .utf8)
        } else if FileManager.default.fileExists(atPath: cssURL.path) {
            try FileManager.default.removeItem(at: cssURL)
        }
    }

    /// 論理名（日本語）: ディスクHTML置換要求発行関数
    /// 処理概要: 保存済み HTML を読み直し、選択中 WebView へ document replacement として反映します。
    ///
    /// - Parameters:
    ///   - target: 置換対象 HTML。
    ///   - selectedNodeID: 置換後に維持する選択 node ID。
    private func requestDocumentReplacementFromDisk(for target: HTMLSyncTarget, selectedNodeID: String?) {
        guard let html = readHTMLFromDisk(at: target.htmlURL) else { return }
        documentReplacementSequence += 1
        documentReplacementRequest = DocumentReplacementRequest(
            sequence: documentReplacementSequence,
            pageURL: target.htmlURL,
            html: html,
            selectedNodeID: selectedNodeID
        )
    }

    /// 論理名（日本語）: 次Chapter ID生成関数
    /// 処理概要: 既存 Chapter の ID と重複しない `chapter-N` 形式の ID を返します。
    ///
    /// - Parameter project: Chapter を追加する project manifest。
    /// - Returns: 重複しない Chapter ID。
    private func nextChapterID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(project.chapters.map(\.id))
        return Self.nextSequencedID(prefix: "chapter", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 次Chapter内部ID生成関数
    /// 処理概要: 既存 manifest 内部 ID と重複しない `chapter-N` 形式の内部 ID を返します。
    ///
    /// - Parameter project: Chapter を追加する project manifest。
    /// - Returns: 重複しない Chapter 内部 ID。
    private func nextChapterInternalID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(
            project.chapters.map(\.internalID)
                + project.chapters.flatMap { $0.pages.map(\.internalID) }
                + project.collections.map(\.internalID)
                + project.collections.flatMap { $0.components.map(\.internalID) }
        )
        return Self.nextSequencedID(prefix: "chapter", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 書き込み対象Chapter位置取得関数
    /// 処理概要: 選択中 Chapter を優先し、未選択または Chapter がない場合は page 追加先を確保して index を返します。
    ///
    /// - Parameter project: page を追加する project manifest。
    /// - Returns: page 追加先 Chapter の index。
    private func writableChapterIndex(in project: inout OpenGraphiteProject) -> Int {
        if let selectedChapterInternalID,
           let index = project.chapters.firstIndex(where: { $0.internalID == selectedChapterInternalID }) {
            return index
        }
        if let visibleChapterIndex = project.chapters.firstIndex(where: { !$0.isSidebarHidden }) {
            return visibleChapterIndex
        }
        project.chapters.append(
            OpenGraphiteChapter(
                id: project.chapters.isEmpty ? OpenGraphiteChapter.defaultID : nextChapterID(in: project),
                internalID: nextChapterInternalID(in: project),
                title: project.chapters.isEmpty
                    ? OpenGraphiteChapter.defaultTitle
                    : "Chapter \(project.chapters.count + 1)",
                pages: []
            )
        )
        return project.chapters.index(before: project.chapters.endIndex)
    }

    /// 論理名（日本語）: 既存HTML path検証関数
    /// 処理概要: 選択された file URL が project の `htmlRoot` 配下にある HTML file かを確認し、manifest 用の相対 path を返します。
    ///
    /// - Parameters:
    ///   - htmlURL: ユーザーが選択した HTML file URL。
    ///   - loadedProject: path 解決の基準になる読み込み済み project。
    /// - Returns: 正常時は `htmlRoot` 相対 path、異常時は error メッセージ。
    private static func existingHTMLPath(
        for htmlURL: URL,
        in loadedProject: LoadedOpenGraphiteProject
    ) -> (path: String?, error: String?) {
        guard htmlURL.isFileURL else {
            return (nil, "追加する HTML は local file である必要があります。")
        }

        let htmlURL = htmlURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: htmlURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return (nil, "追加する HTML が見つかりません: \(htmlURL.path)")
        }
        guard htmlURL.pathExtension.lowercased() == "html" else {
            return (nil, "追加するファイルは .html で終わる必要があります。")
        }

        let htmlRootURL = loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot, isDirectory: true)
            .standardizedFileURL
        let rootPath = htmlRootURL.path
        let htmlPath = htmlURL.path
        guard htmlPath.hasPrefix(rootPath + "/") else {
            return (nil, "追加する HTML は htmlRoot 配下に配置してください: \(htmlPath)")
        }

        let relativePath = String(htmlPath.dropFirst(rootPath.count + 1))
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasSuffix("/"),
              !components.contains(""),
              !components.contains("."),
              !components.contains(".."),
              URL(fileURLWithPath: relativePath).pathExtension.lowercased() == "html"
        else {
            return (nil, "HTML path は htmlRoot 配下の相対 path である必要があります。")
        }

        return (relativePath, nil)
    }

    /// 論理名（日本語）: 次Page ID生成関数
    /// 処理概要: 既存 page / component の ID と重複しない `page-N` 形式の ID を返します。
    ///
    /// - Parameter project: page を追加する project manifest。
    /// - Returns: 重複しない page ID。
    private func nextPageID(in project: OpenGraphiteProject) -> String {
        let usedIDs = Set(project.allPages.map(\.id))
        return Self.nextSequencedID(prefix: "page", usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 既存HTML用Page ID生成関数
    /// 処理概要: HTML file 名から manifest 用 ID を生成し、既存 page / component ID と重複する場合は連番 suffix を付けます。
    ///
    /// - Parameters:
    ///   - path: `htmlRoot` から見た HTML path。
    ///   - project: ID の重複を確認する project manifest。
    /// - Returns: 既存 HTML 登録に使う page ID。
    private static func existingPageID(forHTMLPath path: String, in project: OpenGraphiteProject) -> String {
        let fileStem = URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
        let preferredID = manifestIDSlug(from: fileStem, fallback: "page")
        let usedIDs = Set(project.allPages.map(\.id))
        guard usedIDs.contains(preferredID) else { return preferredID }
        return nextSequencedID(prefix: preferredID, usedIDs: usedIDs)
    }

    /// 論理名（日本語）: 次Page path生成関数
    /// 処理概要: manifest と実ファイルの双方で重複しない `page-N.html` path を返します。
    ///
    /// - Parameters:
    ///   - loadedProject: path と HTML root を確認する読み込み済み project。
    ///   - idPrefix: path の接頭辞。
    /// - Returns: 新規 page HTML path。
    private func nextPagePath(in loadedProject: LoadedOpenGraphiteProject, idPrefix: String) -> String {
        let usedPaths = Set(loadedProject.project.allPages.map(\.path))
        let htmlRootURL = loadedProject.rootURL.appendingPathComponent(loadedProject.project.htmlRoot)
        var index = 1
        while true {
            let candidate = "\(idPrefix)-\(index).html"
            let htmlURL = htmlRootURL.appendingPathComponent(candidate)
            let companionURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: htmlURL)
            if !usedPaths.contains(candidate),
               !FileManager.default.fileExists(atPath: htmlURL.path),
               !FileManager.default.fileExists(atPath: companionURL.path) {
                return candidate
            }
            index += 1
        }
    }

    /// 論理名（日本語）: 次Pageキャンバス生成関数
    /// 処理概要: Chapter 末尾 page の右隣、または既存 project page の寸法を使った原点配置を返します。
    ///
    /// - Parameters:
    ///   - chapter: page を追加する Chapter。
    ///   - fallbackProject: Chapter が空の場合に寸法を参照する project manifest。
    /// - Returns: 新規 page の canvas 配置。
    private func nextPageCanvas(in chapter: OpenGraphiteChapter, fallbackProject: OpenGraphiteProject) -> OpenGraphiteCanvas {
        let spacing: Double = 80
        if let lastCanvas = chapter.pages.last?.canvas {
            return OpenGraphiteCanvas(
                name: lastCanvas.name,
                x: lastCanvas.x + lastCanvas.width + spacing,
                y: lastCanvas.y,
                width: lastCanvas.width,
                height: lastCanvas.height,
                previewContext: lastCanvas.previewContext
            )
        }

        if let fallbackCanvas = fallbackProject.allPages.first?.canvas {
            return OpenGraphiteCanvas(
                name: fallbackCanvas.name,
                x: 0,
                y: 0,
                width: fallbackCanvas.width,
                height: fallbackCanvas.height,
                previewContext: fallbackCanvas.previewContext
            )
        }

        return OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
    }

    /// 論理名（日本語）: 再読込Chapter解決関数
    /// 処理概要: `.ogp` 保存後に再読み込みされた project から、追加先だった Chapter を内部 ID または index で復元します。
    ///
    /// - Parameters:
    ///   - project: 再読み込み後の project manifest。
    ///   - chapter: 保存前に追加先だった Chapter。
    ///   - fallbackIndex: 保存前の Chapter index。
    /// - Returns: 再読み込み後の Chapter。見つからない場合は `nil`。
    private static func reloadedChapter(
        in project: OpenGraphiteProject,
        matching chapter: OpenGraphiteChapter,
        fallbackIndex: Int
    ) -> OpenGraphiteChapter? {
        if !chapter.internalID.isEmpty,
           let matchedChapter = project.chapters.first(where: { $0.internalID == chapter.internalID }) {
            return matchedChapter
        }
        if project.chapters.indices.contains(fallbackIndex) {
            return project.chapters[fallbackIndex]
        }
        return project.chapters.first { $0.id == chapter.id }
    }

    /// 論理名（日本語）: 連番ID生成関数
    /// 処理概要: 指定 prefix に数値 suffix を付け、既存 ID と衝突しない最初の値を返します。
    ///
    /// - Parameters:
    ///   - prefix: ID の接頭辞。
    ///   - usedIDs: 既に使われている ID。
    /// - Returns: 未使用の連番 ID。
    private static func nextSequencedID(prefix: String, usedIDs: Set<String>) -> String {
        var index = 1
        while true {
            let candidate = "\(prefix)-\(index)"
            if !usedIDs.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }

    /// 論理名（日本語）: Manifest ID slug生成関数
    /// 処理概要: ファイル名などの任意文字列から page ID として扱いやすい英数字 hyphen 形式の値を生成します。
    ///
    /// - Parameters:
    ///   - value: slug 化する文字列。
    ///   - fallback: slug が空になった場合に使う値。
    /// - Returns: manifest ID として使う slug。
    private static func manifestIDSlug(from value: String, fallback: String) -> String {
        var slug = ""
        var previousWasSeparator = false

        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.append(String(scalar))
                previousWasSeparator = false
            } else if !previousWasSeparator {
                slug.append("-")
                previousWasSeparator = true
            }
        }

        let normalized = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return normalized.isEmpty ? fallback : normalized
    }

    /// 論理名（日本語）: Manifest表示名正規化関数
    /// 処理概要: `.ogp` の title 欄に保存する人間向け表示名として前後空白を除去し、空文字は未指定に戻します。
    ///
    /// - Parameter title: Sidebar から入力された表示名。
    /// - Returns: 保存する title。空の場合は `nil`。
    private static func normalizedManifestTitle(_ title: String) -> String? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedTitle.isEmpty ? nil : normalizedTitle
    }

    /// 論理名（日本語）: HTMLファイル名変更path生成関数
    /// 処理概要: 現在の HTML path のディレクトリを保ったまま、入力値から `.html` ファイル名を生成します。
    ///
    /// - Parameters:
    ///   - currentPath: 変更前の `htmlRoot` 相対 HTML path。
    ///   - value: Sidebar から入力されたファイル名。
    /// - Returns: 更新後 path。入力が無効な場合は error に理由を返します。
    private static func renamedHTMLPath(currentPath: String, value: String) -> (path: String?, error: String?) {
        let rawFileName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawFileName.isEmpty else {
            return (nil, "ファイル名を入力してください。")
        }
        guard rawFileName.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) == nil else {
            return (nil, "ファイル名にはディレクトリ区切りを含められません。")
        }
        guard rawFileName.rangeOfCharacter(from: .newlines) == nil else {
            return (nil, "ファイル名には改行を含められません。")
        }

        var fileName = rawFileName
        if URL(fileURLWithPath: fileName).pathExtension.isEmpty {
            fileName += ".html"
        }
        guard URL(fileURLWithPath: fileName).pathExtension.lowercased() == "html" else {
            return (nil, "HTML ファイル名は .html で終わる必要があります。")
        }

        let fileStem = String(fileName.dropLast(".html".count))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !fileStem.isEmpty, fileName != ".", fileName != ".." else {
            return (nil, "ファイル名が正しくありません。")
        }

        let directory = (currentPath as NSString).deletingLastPathComponent
        let nextPath = directory.isEmpty || directory == "."
            ? fileName
            : "\(directory)/\(fileName)"
        let components = nextPath.split(separator: "/", omittingEmptySubsequences: false)
        guard !nextPath.isEmpty,
              !nextPath.hasPrefix("/"),
              !nextPath.hasSuffix("/"),
              !components.contains(""),
              !components.contains("."),
              !components.contains("..")
        else {
            return (nil, "HTML path は htmlRoot 配下の相対 path である必要があります。")
        }

        return (nextPath, nil)
    }

    /// 論理名（日本語）: 相対path生成関数
    /// 処理概要: 基準ディレクトリから対象 URL への相対 path を POSIX 区切りで返します。
    ///
    /// - Parameters:
    ///   - directoryURL: 基準ディレクトリ URL。
    ///   - targetURL: 参照先 URL。
    /// - Returns: 相対 path。算出できない場合は対象 URL の path。
    private static func relativePath(from directoryURL: URL, to targetURL: URL) -> String {
        let baseComponents = directoryURL.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var sharedCount = 0
        while sharedCount < baseComponents.count,
              sharedCount < targetComponents.count,
              baseComponents[sharedCount] == targetComponents[sharedCount] {
            sharedCount += 1
        }
        guard sharedCount > 0 else {
            return targetURL.path
        }
        let up = Array(repeating: "..", count: baseComponents.count - sharedCount)
        let down = Array(targetComponents.dropFirst(sharedCount))
        let path = (up + down).joined(separator: "/")
        return path.isEmpty ? "." : path
    }

    /// 論理名（日本語）: キャンバス配置名正規化関数
    /// 処理概要: Inspector 入力の前後空白を除去し、空白のみの名前を空文字に変換します。
    ///
    /// - Parameter name: 正規化する配置名。
    /// - Returns: 保存用の配置名。名前なしの場合は空文字。
    private static func normalizedCanvasName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 論理名（日本語）: 優先表示Chapter解決関数
    /// 処理概要: Sidebar で非表示にされていない Chapter のうち、指定内部 ID または先頭 Chapter を返します。
    ///
    /// - Parameters:
    ///   - project: Chapter を保持する project manifest。
    ///   - internalID: 優先して選択する Chapter 内部 ID。
    /// - Returns: 表示可能な Chapter。全 Chapter が非表示の場合は `nil`。
    private static func preferredVisibleChapter(
        in project: OpenGraphiteProject,
        internalID: String? = nil
    ) -> OpenGraphiteChapter? {
        if let internalID,
           let chapter = project.chapters.first(where: {
               $0.internalID == internalID && !$0.isSidebarHidden
           }) {
            return chapter
        }
        return project.chapters.first { !$0.isSidebarHidden }
    }

    /// 論理名（日本語）: HTML root内URL判定関数
    /// 処理概要: 削除候補の file URL が symlink 解決後も指定 HTML root の配下にあるかを検証します。
    ///
    /// - Parameters:
    ///   - fileURL: 検証する file URL。
    ///   - directoryURL: 許可する HTML root URL。
    /// - Returns: file URL が HTML root 配下にある場合は `true`。
    private static func isFileURL(_ fileURL: URL, containedIn directoryURL: URL) -> Bool {
        guard fileURL.isFileURL, directoryURL.isFileURL else { return false }
        let directoryPath = directoryURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let filePath = fileURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return filePath.hasPrefix(directoryPath + "/")
    }

    /// 論理名（日本語）: Page参照配置除去関数
    /// 処理概要: 完全削除する Page の node を指す Chapter / Collection 直下の参照配置を manifest から取り除きます。
    ///
    /// - Parameters:
    ///   - pageInternalID: 完全削除する Page の内部 ID。
    ///   - project: 参照配置を更新する project manifest。
    private static func removeCanvasReferences(
        toPageInternalID pageInternalID: String,
        from project: inout OpenGraphiteProject
    ) {
        let targetsPage: (OpenGraphiteCanvasReference) -> Bool = { reference in
            guard let parsed = OpenGraphiteReferenceID(parsing: reference.referenceID),
                  parsed.type == .node,
                  parsed.parts.count >= 2
            else {
                return false
            }
            return parsed.parts[1] == pageInternalID
        }

        for chapterIndex in project.chapters.indices {
            project.chapters[chapterIndex].references.removeAll(where: targetsPage)
        }
        for collectionIndex in project.collections.indices {
            project.collections[collectionIndex].references.removeAll(where: targetsPage)
        }
    }

    /// 論理名（日本語）: アイコン値正規化関数
    /// 処理概要: Inspector 入力の前後空白を除去し、空の場合は既定値へ置き換えます。
    ///
    /// - Parameters:
    ///   - value: Inspector 入力値。
    ///   - defaultValue: 空入力時の既定値。
    /// - Returns: 保存用の icon metadata。
    private static func normalizedIconValue(_ value: String, defaultValue: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? defaultValue : normalized
    }

    /// 論理名（日本語）: 優先Collection解決関数
    /// 処理概要: 指定内部 ID の Collection、component を持つ先頭 Collection、先頭 Collection の順に選択対象を解決します。
    ///
    /// - Parameters:
    ///   - project: Collection を保持する project manifest。
    ///   - internalID: 優先して選択する Collection 内部 ID。
    /// - Returns: 選択候補の Collection。Collection が存在しない場合は `nil`。
    private static func preferredCollection(in project: OpenGraphiteProject, internalID: String? = nil) -> OpenGraphiteComponentCollection? {
        if let internalID,
           let collection = project.collections.first(where: { $0.internalID == internalID }) {
            return collection
        }
        return project.collections.first { !$0.components.isEmpty } ?? project.collections.first
    }

    /// 論理名（日本語）: コンポーネントmaster探索関数
    /// 処理概要: project の component canvas HTML を走査し、指定 `data-og-component` の master 情報を返します。
    ///
    /// - Parameters:
    ///   - componentID: 探索する `data-og-component`。
    ///   - loadedProject: 探索対象 project。
    /// - Returns: component master の表示情報。見つからない場合は `nil`。
    private func componentSource(
        componentID: String,
        in loadedProject: LoadedOpenGraphiteProject
    ) -> OpenGraphiteComponentSource? {
        for collection in loadedProject.project.collections {
            for componentPage in collection.components {
                let pageURL = loadedProject.htmlURL(for: componentPage)
                guard let html = readHTMLFromDisk(at: pageURL) else { continue }
                let masterNode = OpenGraphiteHTMLDocument(html: html).nodes().first { node in
                    node.attributes["data-og-component"] == componentID
                        && node.tagName.contains("-")
                        && node.tagName != "og-instance"
                }
                guard let masterNode else { continue }

                return OpenGraphiteComponentSource(
                    componentID: componentID,
                    masterNodeID: masterNode.id,
                    collectionInternalID: collection.internalID,
                    collectionName: collection.displayName,
                    componentPageID: componentPage.id,
                    componentPageInternalID: componentPage.internalID,
                    componentPageName: componentPage.displayName,
                    componentPagePath: componentPage.path,
                    canvas: componentPage.canvas
                )
            }
        }

        return nil
    }

    /// 論理名（日本語）: プロジェクトmanifest保存関数
    /// 処理概要: 更新済み project manifest を `.ogp` ファイルへ atomic write で保存します。
    ///
    /// - Parameters:
    ///   - project: 保存する project 定義。
    ///   - projectURL: 保存先 `.ogp` URL。
    private func writeProjectManifest(_ project: OpenGraphiteProject, to projectURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(project.normalizedInternalIDs())
        try data.write(to: projectURL, options: .atomic)
    }

    /// 論理名（日本語）: プロジェクトHTML既知状態初期化関数
    /// 処理概要: project 内の全 Chapter の HTML を読み、外部変更検出の比較基準として保存します。
    ///
    /// - Parameter project: 比較基準を初期化する読み込み済み project。
    private func seedKnownHTMLForProject(_ project: LoadedOpenGraphiteProject) {
        for page in project.project.allPages {
            let pageURL = project.htmlURL(for: page)
            if let html = readHTMLFromDisk(at: pageURL) {
                lastKnownPageHTMLByURL[pageURL] = html
            }
        }
    }

    /// 論理名（日本語）: ページ実行時状態移行関数
    /// 処理概要: HTML ファイル名変更に伴い、履歴、既知 HTML、reload token、静的フロー cache を新 URL へ移します。
    ///
    /// - Parameters:
    ///   - currentHTMLURL: 変更前 HTML URL。
    ///   - nextHTMLURL: 変更後 HTML URL。
    private func migratePageRuntimeState(from currentHTMLURL: URL, to nextHTMLURL: URL) {
        let currentURL = currentHTMLURL.standardizedFileURL
        let nextURL = nextHTMLURL.standardizedFileURL

        if let key = matchingURLKey(in: syncHistories, for: currentURL),
           let history = syncHistories.removeValue(forKey: key) {
            syncHistories[nextURL] = history
        }
        editorUndoStack = editorUndoStack.map {
            $0.migratingPageURL(from: currentURL, to: nextURL)
        }
        editorRedoStack = editorRedoStack.map {
            $0.migratingPageURL(from: currentURL, to: nextURL)
        }
        if let key = matchingURLKey(in: lastKnownPageHTMLByURL, for: currentURL),
           let html = lastKnownPageHTMLByURL.removeValue(forKey: key) {
            lastKnownPageHTMLByURL[nextURL] = html
        }
        if let key = matchingURLKey(in: staticFlowLinksByPageURL, for: currentURL),
           let links = staticFlowLinksByPageURL.removeValue(forKey: key) {
            staticFlowLinksByPageURL[nextURL] = links
        }
        if let key = matchingURLKey(in: pageReloadTokensByURL, for: currentURL),
           let token = pageReloadTokensByURL.removeValue(forKey: key) {
            pageReloadTokensByURL[nextURL] = token + 1
        } else {
            pageReloadTokensByURL[nextURL, default: 0] += 1
        }
        if let key = matchingURLKey(in: pageChangeMonitorsByURL, for: currentURL) {
            pageChangeMonitorsByURL[key]?.cancel()
            pageChangeMonitorsByURL.removeValue(forKey: key)
        }
    }

    /// 論理名（日本語）: Page実行時状態破棄関数
    /// 処理概要: 完全削除した Page に結び付く履歴、監視、reload token、静的フロー cache を破棄します。
    ///
    /// - Parameters:
    ///   - pageInternalID: 削除した Page の内部 ID。
    ///   - pageURL: 削除した HTML の URL。
    private func discardPageRuntimeState(pageInternalID: String, pageURL: URL) {
        let standardizedURL = pageURL.standardizedFileURL
        if let key = matchingURLKey(in: syncHistories, for: standardizedURL) {
            syncHistories.removeValue(forKey: key)
        }
        if let key = matchingURLKey(in: lastKnownPageHTMLByURL, for: standardizedURL) {
            lastKnownPageHTMLByURL.removeValue(forKey: key)
        }
        if let key = matchingURLKey(in: staticFlowLinksByPageURL, for: standardizedURL) {
            staticFlowLinksByPageURL.removeValue(forKey: key)
        }
        if let key = matchingURLKey(in: pageReloadTokensByURL, for: standardizedURL) {
            pageReloadTokensByURL.removeValue(forKey: key)
        }
        if let key = matchingURLKey(in: pageChangeMonitorsByURL, for: standardizedURL) {
            pageChangeMonitorsByURL[key]?.cancel()
            pageChangeMonitorsByURL.removeValue(forKey: key)
        }
        staticFlowLinksByPageInternalID.removeValue(forKey: pageInternalID)
        editorUndoStack.removeAll()
        editorRedoStack.removeAll()
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: URL辞書key照合関数
    /// 処理概要: URL を key に持つ cache から、標準化後に一致する既存 key を探します。
    ///
    /// - Parameters:
    ///   - dictionary: URL key を持つ辞書。
    ///   - url: 探索する URL。
    /// - Returns: 一致した既存 key。見つからない場合は `nil`。
    private func matchingURLKey<Value>(in dictionary: [URL: Value], for url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        return dictionary.keys.first { key in
            key == url || key.standardizedFileURL == standardizedURL
        }
    }

    /// 論理名（日本語）: ページ再読み込みトークン更新関数
    /// 処理概要: 指定 HTML URL の reload token を進め、対応する非選択 WebView に再読み込みを促します。
    ///
    /// - Parameter pageURL: reload token を進める HTML URL。
    private func incrementReloadToken(for pageURL: URL) {
        let standardizedPageURL = pageURL.standardizedFileURL
        canvasReferenceResolutionCache = canvasReferenceResolutionCache.filter { key, _ in
            key.pageURL.standardizedFileURL != standardizedPageURL
        }
        var tokens = pageReloadTokensByURL
        tokens[pageURL, default: 0] += 1
        pageReloadTokensByURL = tokens
    }

    /// 論理名（日本語）: 履歴可用性更新関数
    /// 処理概要: 現在開いている project の統合 undo/redo 時系列をメニュー表示用 Published 値へ反映します。
    private func updateHistoryAvailability() {
        guard let currentProjectURL = loadedProject?.fileURL.standardizedFileURL else {
            canUndo = false
            canRedo = false
            historyItems = []
            return
        }
        canUndo = editorUndoStack.last?.projectURL.standardizedFileURL == currentProjectURL
        canRedo = editorRedoStack.last?.projectURL.standardizedFileURL == currentProjectURL
        let undoItems = editorUndoStack
            .filter { $0.projectURL.standardizedFileURL == currentProjectURL }
            .reversed()
            .map { $0.listItem(state: .undoable) }
        let redoItems = editorRedoStack
            .filter { $0.projectURL.standardizedFileURL == currentProjectURL }
            .reversed()
            .map { $0.listItem(state: .redoable) }
        historyItems = undoItems + redoItems
    }

    /// 論理名（日本語）: HTML履歴記録関数
    /// 処理概要: ページ別同期履歴へ追加したHTML保存、またはcompanion CSSだけの保存をproject全体の統合時系列へ記録します。
    ///
    /// - Parameters:
    ///   - projectURL: 操作時に開いていた `.ogp` URL。
    ///   - pageURL: 同期した HTML URL。
    ///   - advancesHTMLHistory: ページ別HTML履歴も一段進めた操作か。
    ///   - companionCSSChange: 同じ操作に含まれるcompanion CSS変更前後。`nil`はCSSを履歴対象にしないことを表します。
    private func recordDocumentHistory(
        projectURL: URL,
        pageURL: URL,
        advancesHTMLHistory: Bool = true,
        companionCSSChange: CompanionCSSHistoryChange? = nil
    ) {
        let didChangeCompanionCSS = companionCSSChange.map {
            $0.previousCSS != $0.nextCSS
        } ?? false
        guard advancesHTMLHistory || didChangeCompanionCSS else {
            return
        }
        recordEditorHistory(
            .document(
                DocumentHistoryEntry(
                    projectURL: projectURL.standardizedFileURL,
                    pageURL: pageURL.standardizedFileURL,
                    advancesHTMLHistory: advancesHTMLHistory,
                    companionCSSChange: companionCSSChange
                )
            )
        )
    }

    /// 論理名（日本語）: 履歴表示情報生成関数
    /// 処理概要: 統合履歴の正本復元情報から、対象名、操作名、種類別簡易プレビューを記録時点で確定します。
    ///
    /// - Parameter entry: 表示情報を生成する統合履歴項目。
    /// - Returns: 左サイドバーへ表示する履歴情報。
    private func historyPresentation(for entry: EditorHistoryEntry) -> EditorHistoryPresentation {
        switch entry {
        case let .document(documentEntry):
            return documentHistoryPresentation(for: documentEntry)
        case let .canvasAnnotation(annotationEntry):
            return canvasAnnotationHistoryPresentation(for: annotationEntry)
        case let .canvasGuide(guideEntry):
            return canvasGuideHistoryPresentation(for: guideEntry)
        case let .canvasReference(referenceEntry):
            return canvasReferenceHistoryPresentation(for: referenceEntry)
        }
    }

    /// 論理名（日本語）: HTML履歴表示情報生成関数
    /// 処理概要: 選択中オブジェクトまたは対象pageを、HTML / companion CSS履歴の表示対象として解決します。
    ///
    /// - Parameter entry: HTML履歴項目。
    /// - Returns: HTMLオブジェクトまたはpageの履歴表示情報。
    private func documentHistoryPresentation(for entry: DocumentHistoryEntry) -> EditorHistoryPresentation {
        let selectedURL = selectedPageURL?.standardizedFileURL
        if selectedURL == entry.pageURL.standardizedFileURL, let selectedNode {
            return EditorHistoryPresentation(
                objectName: selectedNode.displayID,
                actionName: documentHistoryActionName(for: entry),
                previewKind: .node(hint: selectedNode.presentationHint)
            )
        }

        let page = loadedProject?.project.allPages.first { page in
            loadedProject?.htmlURL(for: page).standardizedFileURL == entry.pageURL.standardizedFileURL
        }
        return EditorHistoryPresentation(
            objectName: page?.displayName ?? entry.pageURL.lastPathComponent,
            actionName: documentHistoryActionName(for: entry),
            previewKind: .node(hint: .page)
        )
    }

    /// 論理名（日本語）: 文書履歴操作名生成関数
    /// 処理概要: HTMLとcompanion CSSのどちらが一操作で変化したかを短い履歴ラベルへ変換します。
    ///
    /// - Parameter entry: HTML履歴項目。
    /// - Returns: 文書履歴の操作名。
    private func documentHistoryActionName(for entry: DocumentHistoryEntry) -> String {
        switch (entry.advancesHTMLHistory, entry.companionCSSChange != nil) {
        case (true, true):
            return "HTML / スタイルを編集"
        case (false, true):
            return "スタイルを編集"
        default:
            return "HTMLを編集"
        }
    }

    /// 論理名（日本語）: 注釈履歴表示情報生成関数
    /// 処理概要: 変更前後の注釈配列から対象付箋または手書きと追加・削除・編集の種別を特定します。
    ///
    /// - Parameter entry: キャンバス注釈履歴項目。
    /// - Returns: 注釈履歴の表示情報。
    private func canvasAnnotationHistoryPresentation(
        for entry: CanvasAnnotationHistoryEntry
    ) -> EditorHistoryPresentation {
        let changes = Self.changedHistoryValues(
            previous: entry.previousAnnotations,
            next: entry.nextAnnotations,
            id: \OpenGraphiteCanvasAnnotation.internalID
        )
        guard let change = changes.first,
              let annotation = change.next ?? change.previous
        else {
            return EditorHistoryPresentation(
                objectName: "キャンバス注釈",
                actionName: "注釈を編集",
                previewKind: .stickyNote(backgroundColor: "#FFE88A", text: "")
            )
        }

        let previewKind: EditorHistoryPreviewKind
        let baseName: String
        switch annotation.kind {
        case .stickyNote:
            previewKind = .stickyNote(
                backgroundColor: annotation.backgroundColor,
                text: annotation.text
            )
            baseName = Self.stickyNoteHistoryName(text: annotation.text)
        case .ink:
            previewKind = .ink(color: annotation.strokes.first?.color ?? "#FF4D67")
            baseName = "手書き"
        }

        if changes.count > 1 {
            return EditorHistoryPresentation(
                objectName: "\(changes.count)個のキャンバス注釈",
                actionName: "注釈を一括編集",
                previewKind: previewKind
            )
        }

        return EditorHistoryPresentation(
            objectName: baseName,
            actionName: Self.historyChangeActionName(
                baseName: annotation.kind == .stickyNote ? "付箋" : "手書き",
                previous: change.previous,
                next: change.next
            ),
            previewKind: previewKind
        )
    }

    /// 論理名（日本語）: ガイド履歴表示情報生成関数
    /// 処理概要: 変更前後のガイド配列から方向、座標、追加・削除・移動の表示情報を生成します。
    ///
    /// - Parameter entry: キャンバスガイド履歴項目。
    /// - Returns: ガイド履歴の表示情報。
    private func canvasGuideHistoryPresentation(
        for entry: CanvasGuideHistoryEntry
    ) -> EditorHistoryPresentation {
        let changes = Self.changedHistoryValues(
            previous: entry.previousGuides,
            next: entry.nextGuides,
            id: \OpenGraphiteCanvasGuide.internalID
        )
        guard let change = changes.first,
              let guide = change.next ?? change.previous
        else {
            return EditorHistoryPresentation(
                objectName: "キャンバスガイド",
                actionName: "ガイドを編集",
                previewKind: .guide(orientation: .vertical)
            )
        }
        let orientationName = guide.orientation == .vertical ? "垂直ガイド" : "水平ガイド"
        let objectName = changes.count > 1
            ? "\(changes.count)本のキャンバスガイド"
            : "\(orientationName) \(Self.historyCoordinateLabel(guide.position))"
        let actionName = changes.count > 1
            ? "ガイドを一括編集"
            : Self.historyChangeActionName(
                baseName: "ガイド",
                previous: change.previous,
                next: change.next,
                updateVerb: "移動"
            )
        return EditorHistoryPresentation(
            objectName: objectName,
            actionName: actionName,
            previewKind: .guide(orientation: guide.orientation)
        )
    }

    /// 論理名（日本語）: 参照配置履歴表示情報生成関数
    /// 処理概要: 変更前後の参照配置配列から参照元オブジェクト名と追加・削除・移動の表示情報を生成します。
    ///
    /// - Parameter entry: キャンバス参照履歴項目。
    /// - Returns: 参照配置履歴の表示情報。
    private func canvasReferenceHistoryPresentation(
        for entry: CanvasReferenceHistoryEntry
    ) -> EditorHistoryPresentation {
        let changes = Self.changedHistoryValues(
            previous: entry.previousReferences,
            next: entry.nextReferences,
            id: \OpenGraphiteCanvasReference.internalID
        )
        guard let change = changes.first,
              let reference = change.next ?? change.previous
        else {
            return EditorHistoryPresentation(
                objectName: "参照オブジェクト",
                actionName: "参照配置を編集",
                previewKind: .reference
            )
        }
        let resolvedName = (try? resolveCanvasReferenceID(reference.referenceID))?.node.id
        let fallbackName = reference.referenceID.split(separator: ":").last.map(String.init)
            ?? "参照オブジェクト"
        let objectName = changes.count > 1
            ? "\(changes.count)個の参照オブジェクト"
            : (resolvedName ?? fallbackName)
        let actionName = changes.count > 1
            ? "参照配置を一括編集"
            : Self.historyChangeActionName(
                baseName: "参照配置",
                previous: change.previous,
                next: change.next,
                updateVerb: "移動"
            )
        return EditorHistoryPresentation(
            objectName: objectName,
            actionName: actionName,
            previewKind: .reference
        )
    }

    /// 論理名（日本語）: 履歴変更値抽出関数
    /// 処理概要: 安定IDを持つ変更前後の配列から、追加・削除・更新された値だけをID順で抽出します。
    ///
    /// - Parameters:
    ///   - previous: 操作前の値一覧。
    ///   - next: 操作後の値一覧。
    ///   - id: 値から安定IDを返す処理。
    /// - Returns: 値が異なるIDごとの変更前後。
    private static func changedHistoryValues<Value: Equatable>(
        previous: [Value],
        next: [Value],
        id: (Value) -> String
    ) -> [(previous: Value?, next: Value?)] {
        let previousByID = previous.reduce(into: [String: Value]()) { result, value in
            result[id(value)] = value
        }
        let nextByID = next.reduce(into: [String: Value]()) { result, value in
            result[id(value)] = value
        }
        return Set(previousByID.keys).union(nextByID.keys).sorted().compactMap { key in
            let previousValue = previousByID[key]
            let nextValue = nextByID[key]
            guard previousValue != nextValue else { return nil }
            return (previousValue, nextValue)
        }
    }

    /// 論理名（日本語）: 履歴変更操作名生成関数
    /// 処理概要: 値の有無から追加・削除・更新を判定し、対象種別と動詞を組み合わせます。
    ///
    /// - Parameters:
    ///   - baseName: 操作対象の短い種別名。
    ///   - previous: 操作前の値。
    ///   - next: 操作後の値。
    ///   - updateVerb: 両方の値がある場合に使う動詞。
    /// - Returns: 履歴行へ表示する操作名。
    private static func historyChangeActionName<Value>(
        baseName: String,
        previous: Value?,
        next: Value?,
        updateVerb: String = "編集"
    ) -> String {
        if previous == nil {
            return "\(baseName)を追加"
        }
        if next == nil {
            return "\(baseName)を削除"
        }
        return "\(baseName)を\(updateVerb)"
    }

    /// 論理名（日本語）: 付箋履歴名生成関数
    /// 処理概要: 付箋本文の先頭行を短く整え、空本文でも識別できる対象名を返します。
    ///
    /// - Parameter text: 付箋本文。
    /// - Returns: 履歴行向けの付箋名。
    private static func stickyNoteHistoryName(text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \Character.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !firstLine.isEmpty else { return "付箋" }
        let summary = String(firstLine.prefix(24))
        return "付箋「\(summary)\(firstLine.count > summary.count ? "…" : "")」"
    }

    /// 論理名（日本語）: 履歴座標ラベル生成関数
    /// 処理概要: ガイド座標を整数優先、小数1桁までの短い表示へ変換します。
    ///
    /// - Parameter value: 表示するworld座標。
    /// - Returns: 履歴行向けの座標文字列。
    private static func historyCoordinateLabel(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }

    /// 論理名（日本語）: エディター統合履歴記録関数
    /// 処理概要: HTML、companion CSS、注釈、ガイド、参照配置の一操作をundo側へ積み、domainを問わず既存redo分岐を破棄します。
    ///
    /// - Parameter entry: 記録する履歴項目。
    private func recordEditorHistory(_ entry: EditorHistoryEntry) {
        guard loadedProject?.fileURL.standardizedFileURL == entry.projectURL.standardizedFileURL else {
            return
        }
        editorUndoStack.append(
            EditorHistoryRecord(
                id: UUID(),
                timestamp: Date(),
                presentation: historyPresentation(for: entry),
                entry: entry
            )
        )
        if editorUndoStack.count > 100 {
            editorUndoStack.removeFirst(editorUndoStack.count - 100)
        }
        editorRedoStack.removeAll()
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: 履歴移動適用関数
    /// 処理概要: HTML、companion CSS、注釈、ガイド、参照配置を同じ時系列から一項目だけ取り出し、対応する正本へ適用します。
    ///
    /// - Parameter direction: 適用する履歴移動方向。
    private func applyHistoryNavigation(direction: HistoryNavigationDirection) {
        let record: EditorHistoryRecord?
        switch direction {
        case .undo:
            record = editorUndoStack.last
        case .redo:
            record = editorRedoStack.last
        }
        guard let record,
              loadedProject?.fileURL.standardizedFileURL == record.projectURL.standardizedFileURL
        else {
            updateHistoryAvailability()
            return
        }

        let didApply: Bool
        switch record.entry {
        case let .document(documentEntry):
            didApply = applyDocumentHistoryNavigation(direction: direction, entry: documentEntry)
        case let .canvasAnnotation(annotationEntry):
            didApply = applyCanvasAnnotationHistoryNavigation(direction: direction, entry: annotationEntry)
        case let .canvasGuide(guideEntry):
            didApply = applyCanvasGuideHistoryNavigation(direction: direction, entry: guideEntry)
        case let .canvasReference(referenceEntry):
            didApply = applyCanvasReferenceHistoryNavigation(direction: direction, entry: referenceEntry)
        }
        guard didApply else {
            updateHistoryAvailability()
            return
        }

        switch direction {
        case .undo:
            guard editorUndoStack.last == record else { return }
            _ = editorUndoStack.popLast()
            editorRedoStack.append(record)
        case .redo:
            guard editorRedoStack.last == record else { return }
            _ = editorRedoStack.popLast()
            editorUndoStack.append(record)
        }
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: HTML履歴移動適用関数
    /// 処理概要: 履歴項目が固定したページの HTML undo/redo をディスクと WebView へ適用します。
    ///
    /// - Parameters:
    ///   - direction: 適用する履歴移動方向。
    ///   - entry: project とページを固定した HTML 履歴項目。
    /// - Returns: HTML を適用できた場合は `true`。
    private func applyDocumentHistoryNavigation(
        direction: HistoryNavigationDirection,
        entry: DocumentHistoryEntry
    ) -> Bool {
        guard var history = syncHistories[entry.pageURL] else { return false }
        let latestProject: LoadedOpenGraphiteProject
        do {
            latestProject = try loader.loadProject(at: entry.projectURL)
        } catch {
            invalidateDocumentHistoryAfterConflict(
                entry: entry,
                diskHTML: nil,
                errorMessage: "履歴の適用前に .ogp を確認できませんでした: \(error.localizedDescription)"
            )
            return false
        }

        guard isRegisteredDocumentHistoryPage(entry.pageURL, in: latestProject) else {
            invalidateDocumentHistoryAfterConflict(entry: entry, diskHTML: nil)
            return false
        }
        let diskHTML = readHTMLFromDisk(at: entry.pageURL)
        guard diskHTML == history.currentHTML else {
            invalidateDocumentHistoryAfterConflict(
                entry: entry,
                diskHTML: diskHTML
            )
            return false
        }

        let diskCompanionCSS = companionCSSHistorySnapshot(for: entry.pageURL)
        if let companionCSSChange = entry.companionCSSChange {
            let expectedCompanionCSS = direction == .undo
                ? companionCSSChange.nextCSS
                : companionCSSChange.previousCSS
            guard diskCompanionCSS == expectedCompanionCSS else {
                invalidateDocumentHistoryAfterConflict(
                    entry: entry,
                    diskHTML: diskHTML,
                    statusMessageOverride: "HTML / companion CSS の外部変更を検出したため、履歴適用を中止しました。"
                )
                return false
            }
        }

        let html: String?
        if entry.advancesHTMLHistory {
            switch direction {
            case .undo:
                html = history.undo()
            case .redo:
                html = history.redo()
            }
        } else {
            html = diskHTML
        }

        guard let html else { return false }

        do {
            if html != diskHTML {
                try html.write(to: entry.pageURL, atomically: true, encoding: .utf8)
            }
            if let companionCSSChange = entry.companionCSSChange {
                let replacementCompanionCSS = direction == .undo
                    ? companionCSSChange.previousCSS
                    : companionCSSChange.nextCSS
                try writeCompanionCSSHistorySnapshot(replacementCompanionCSS, for: entry.pageURL)
            }
            lastKnownPageHTMLByURL[entry.pageURL] = html
            syncHistories[entry.pageURL] = history
            cssVariableBaselinesByInternalID = [:]
            documentReplacementSequence += 1
            documentReplacementRequest = DocumentReplacementRequest(
                sequence: documentReplacementSequence,
                pageURL: entry.pageURL,
                html: html,
                selectedNodeID: entry.pageURL == selectedPageURL ? selectedNodeID : nil
            )
            lastError = nil
            statusMessage = historyStatusMessage(for: direction, pageURL: entry.pageURL)
            return true
        } catch {
            if let diskHTML {
                try? diskHTML.write(to: entry.pageURL, atomically: true, encoding: .utf8)
            }
            if entry.companionCSSChange != nil {
                try? writeCompanionCSSHistorySnapshot(diskCompanionCSS, for: entry.pageURL)
            }
            lastError = "履歴の同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: HTML履歴対象登録判定関数
    /// 処理概要: 最新 `.ogp` が現在も履歴対象 URL を Page / Component として登録しているかを確認します。
    ///
    /// - Parameters:
    ///   - pageURL: 履歴が固定した HTML URL。
    ///   - project: ディスクから再読込した最新 project。
    /// - Returns: 最新 project のいずれかの HTML card が同じ URL を参照している場合は `true`。
    private func isRegisteredDocumentHistoryPage(
        _ pageURL: URL,
        in project: LoadedOpenGraphiteProject
    ) -> Bool {
        let standardizedPageURL = pageURL.standardizedFileURL
        return project.project.allPages.contains { page in
            project.htmlURL(for: page).standardizedFileURL == standardizedPageURL
        }
    }

    /// 論理名（日本語）: HTML履歴競合同期関数
    /// 処理概要: 外部 HTML 更新または Page 登録削除を検出したとき、古い履歴を書き込まず最新表示へ同期して統合履歴を無効化します。
    ///
    /// - Parameters:
    ///   - entry: 競合した HTML 履歴項目。
    ///   - diskHTML: 読み取れた最新 HTML。未登録または削除済みの場合は `nil`。
    ///   - errorMessage: `.ogp` 読み込み失敗など、履歴無効化と併せて表示する任意エラー。
    private func invalidateDocumentHistoryAfterConflict(
        entry: DocumentHistoryEntry,
        diskHTML: String?,
        errorMessage: String? = nil,
        statusMessageOverride: String? = nil
    ) {
        refreshProjectManifestFromDiskIfChanged()
        let remainsRegistered = loadedProject.map {
            isRegisteredDocumentHistoryPage(entry.pageURL, in: $0)
        } ?? false

        if remainsRegistered, let diskHTML {
            lastKnownPageHTMLByURL[entry.pageURL] = diskHTML
            syncHistories[entry.pageURL] = DocumentSyncHistory(initialHTML: diskHTML)
            if selectedPageURL?.standardizedFileURL == entry.pageURL.standardizedFileURL {
                documentReplacementSequence += 1
                documentReplacementRequest = DocumentReplacementRequest(
                    sequence: documentReplacementSequence,
                    pageURL: entry.pageURL,
                    html: diskHTML,
                    selectedNodeID: selectedNodeID
                )
            } else {
                incrementReloadToken(for: entry.pageURL)
            }
        } else {
            if documentReplacementRequest?.pageURL.standardizedFileURL == entry.pageURL.standardizedFileURL {
                documentReplacementRequest = nil
            }
            if let key = matchingURLKey(in: syncHistories, for: entry.pageURL) {
                syncHistories.removeValue(forKey: key)
            }
            if let key = matchingURLKey(in: lastKnownPageHTMLByURL, for: entry.pageURL) {
                lastKnownPageHTMLByURL.removeValue(forKey: key)
            }
            if let key = matchingURLKey(in: pageReloadTokensByURL, for: entry.pageURL) {
                pageReloadTokensByURL.removeValue(forKey: key)
            }
        }

        editorUndoStack.removeAll()
        editorRedoStack.removeAll()
        cssVariableBaselinesByInternalID = [:]
        lastError = errorMessage
        statusMessage = statusMessageOverride
            ?? "HTML の外部変更を検出したため、履歴適用を中止しました。"
        restartExternalPageMonitoring(force: true)
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: キャンバス注釈履歴記録関数
    /// 処理概要: 一度の注釈保存を project 全体の統合時系列へ積み、新しい分岐として redo 履歴を破棄します。
    ///
    /// - Parameters:
    ///   - projectURL: 注釈を保存した `.ogp` URL。
    ///   - target: 変更対象コンテナ。
    ///   - previousAnnotations: 保存前の注釈配列。
    ///   - nextAnnotations: 保存後の注釈配列。
    private func recordCanvasAnnotationHistory(
        projectURL: URL,
        target: CanvasAnnotationHistoryTarget,
        previousAnnotations: [OpenGraphiteCanvasAnnotation],
        nextAnnotations: [OpenGraphiteCanvasAnnotation]
    ) {
        guard previousAnnotations != nextAnnotations else { return }
        recordEditorHistory(
            .canvasAnnotation(
                CanvasAnnotationHistoryEntry(
                    projectURL: projectURL.standardizedFileURL,
                    target: target,
                    previousAnnotations: previousAnnotations,
                    nextAnnotations: nextAnnotations
                )
            )
        )
    }

    /// 論理名（日本語）: キャンバス注釈履歴移動適用関数
    /// 処理概要: 最新 `.ogp` の対象配列が期待値と一致する場合だけ、履歴の注釈配列を差し替えて atomic write します。
    ///
    /// - Parameters:
    ///   - direction: 適用する履歴移動方向。
    ///   - entry: project、container、変更前後配列を固定した注釈履歴項目。
    /// - Returns: 注釈履歴を適用できた場合は `true`。
    private func applyCanvasAnnotationHistoryNavigation(
        direction: HistoryNavigationDirection,
        entry: CanvasAnnotationHistoryEntry
    ) -> Bool {
        let targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: entry.projectURL)
        } catch {
            lastError = "注釈履歴の適用前確認に失敗しました: \(error.localizedDescription)"
            return false
        }
        guard loadedProject?.fileURL.standardizedFileURL == targetProject.fileURL.standardizedFileURL else {
            return false
        }

        var updatedProject = targetProject
        let expectedAnnotations = direction == .undo
            ? entry.nextAnnotations
            : entry.previousAnnotations
        let replacementAnnotations = direction == .undo
            ? entry.previousAnnotations
            : entry.nextAnnotations
        guard canvasAnnotations(for: entry.target, in: updatedProject.project) == expectedAnnotations else {
            synchronizeAfterCanvasAnnotationHistoryConflict(with: targetProject)
            return false
        }

        switch entry.target.segment {
        case .pages:
            guard let index = updatedProject.project.chapters.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasAnnotationHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.chapters[index].annotations = replacementAnnotations
        case .components:
            guard let index = updatedProject.project.collections.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasAnnotationHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.collections[index].annotations = replacementAnnotations
        }

        do {
            try writeProjectManifest(updatedProject.project, to: entry.projectURL)
            self.loadedProject = updatedProject
            reconcileCanvasAnnotationSelectionAfterManifestChange()
            lastError = nil
            statusMessage = direction == .undo
                ? "キャンバス注釈の変更を取り消しました。"
                : "キャンバス注釈の変更をやり直しました。"
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = "注釈履歴の同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: 注釈履歴競合同期関数
    /// 処理概要: 履歴記録後に対象注釈配列が外部変更された場合、上書きを中止して最新 manifest を表示し、無効化された時系列を破棄します。
    ///
    /// - Parameter project: ディスクから再読込した最新 project。
    private func synchronizeAfterCanvasAnnotationHistoryConflict(
        with project: LoadedOpenGraphiteProject
    ) {
        loadedProject = project
        reconcileCanvasAnnotationSelectionAfterManifestChange()
        editorUndoStack.removeAll()
        editorRedoStack.removeAll()
        lastError = nil
        statusMessage = ".ogp の外部変更を検出したため、キャンバス注釈の履歴適用を中止しました。"
        restartExternalProjectMonitoring(force: true)
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: キャンバスガイド履歴記録関数
    /// 処理概要: 一度のガイド保存を project 全体の統合時系列へ積み、新しい分岐として redo 履歴を破棄します。
    ///
    /// - Parameters:
    ///   - projectURL: ガイドを保存した `.ogp` URL。
    ///   - target: 変更対象コンテナ。
    ///   - previousGuides: 保存前のガイド配列。
    ///   - nextGuides: 保存後のガイド配列。
    private func recordCanvasGuideHistory(
        projectURL: URL,
        target: CanvasGuideHistoryTarget,
        previousGuides: [OpenGraphiteCanvasGuide],
        nextGuides: [OpenGraphiteCanvasGuide]
    ) {
        guard previousGuides != nextGuides else { return }
        recordEditorHistory(
            .canvasGuide(
                CanvasGuideHistoryEntry(
                    projectURL: projectURL.standardizedFileURL,
                    target: target,
                    previousGuides: previousGuides,
                    nextGuides: nextGuides
                )
            )
        )
    }

    /// 論理名（日本語）: キャンバスガイド履歴移動適用関数
    /// 処理概要: 最新 `.ogp` の対象配列が期待値と一致する場合だけ、履歴のガイド配列を差し替えて atomic write します。
    ///
    /// - Parameters:
    ///   - direction: 適用する履歴移動方向。
    ///   - entry: project、container、変更前後配列を固定したガイド履歴項目。
    /// - Returns: ガイド履歴を適用できた場合は `true`。
    private func applyCanvasGuideHistoryNavigation(
        direction: HistoryNavigationDirection,
        entry: CanvasGuideHistoryEntry
    ) -> Bool {
        let targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: entry.projectURL)
        } catch {
            lastError = "ガイド履歴の適用前確認に失敗しました: \(error.localizedDescription)"
            return false
        }
        guard loadedProject?.fileURL.standardizedFileURL == targetProject.fileURL.standardizedFileURL else {
            return false
        }

        var updatedProject = targetProject
        let expectedGuides = direction == .undo
            ? entry.nextGuides
            : entry.previousGuides
        let replacementGuides = direction == .undo
            ? entry.previousGuides
            : entry.nextGuides
        guard canvasGuides(for: entry.target, in: updatedProject.project) == expectedGuides else {
            synchronizeAfterCanvasGuideHistoryConflict(with: targetProject)
            return false
        }

        switch entry.target.segment {
        case .pages:
            guard let index = updatedProject.project.chapters.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasGuideHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.chapters[index].guides = replacementGuides
        case .components:
            guard let index = updatedProject.project.collections.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasGuideHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.collections[index].guides = replacementGuides
        }

        do {
            try writeProjectManifest(updatedProject.project, to: entry.projectURL)
            removeMissingStagedCanvasAnnotationTextDrafts(
                from: updatedProject.project,
                projectURL: updatedProject.fileURL
            )
            self.loadedProject = updatedProject
            reconcileCanvasAnnotationSelectionAfterManifestChange()
            lastError = nil
            statusMessage = direction == .undo
                ? "キャンバスガイドの変更を取り消しました。"
                : "キャンバスガイドの変更をやり直しました。"
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = "ガイド履歴の同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: ガイド履歴競合同期関数
    /// 処理概要: 履歴記録後に対象ガイド配列が外部変更された場合、上書きを中止して最新 manifest を表示し、無効化された時系列を破棄します。
    ///
    /// - Parameter project: ディスクから再読込した最新 project。
    private func synchronizeAfterCanvasGuideHistoryConflict(
        with project: LoadedOpenGraphiteProject
    ) {
        removeMissingStagedCanvasAnnotationTextDrafts(
            from: project.project,
            projectURL: project.fileURL
        )
        loadedProject = project
        reconcileCanvasAnnotationSelectionAfterManifestChange()
        editorUndoStack.removeAll()
        editorRedoStack.removeAll()
        lastError = nil
        statusMessage = ".ogp の外部変更を検出したため、キャンバスガイドの履歴適用を中止しました。"
        restartExternalProjectMonitoring(force: true)
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: キャンバス参照履歴記録関数
    /// 処理概要: 一度の参照配置保存をproject全体の統合時系列へ積み、新しい分岐としてredo履歴を破棄します。
    ///
    /// - Parameters:
    ///   - projectURL: 参照配置を保存した`.ogp` URL。
    ///   - target: 変更対象container。
    ///   - previousReferences: 保存前の参照配置配列。
    ///   - nextReferences: 保存後の参照配置配列。
    private func recordCanvasReferenceHistory(
        projectURL: URL,
        target: CanvasReferenceHistoryTarget,
        previousReferences: [OpenGraphiteCanvasReference],
        nextReferences: [OpenGraphiteCanvasReference]
    ) {
        guard previousReferences != nextReferences else { return }
        recordEditorHistory(
            .canvasReference(
                CanvasReferenceHistoryEntry(
                    projectURL: projectURL.standardizedFileURL,
                    target: target,
                    previousReferences: previousReferences,
                    nextReferences: nextReferences
                )
            )
        )
    }

    /// 論理名（日本語）: キャンバス参照履歴移動適用関数
    /// 処理概要: 最新`.ogp`の対象配列が期待値と一致する場合だけ、履歴の参照配置配列を差し替えてatomic writeします。
    ///
    /// - Parameters:
    ///   - direction: 適用する履歴移動方向。
    ///   - entry: project、container、変更前後配列を固定した参照配置履歴項目。
    /// - Returns: 参照配置履歴を適用できた場合は`true`。
    private func applyCanvasReferenceHistoryNavigation(
        direction: HistoryNavigationDirection,
        entry: CanvasReferenceHistoryEntry
    ) -> Bool {
        let targetProject: LoadedOpenGraphiteProject
        do {
            targetProject = try loader.loadProject(at: entry.projectURL)
        } catch {
            lastError = "参照配置履歴の適用前確認に失敗しました: \(error.localizedDescription)"
            return false
        }
        guard loadedProject?.fileURL.standardizedFileURL == targetProject.fileURL.standardizedFileURL else {
            return false
        }

        var updatedProject = targetProject
        let expectedReferences = direction == .undo
            ? entry.nextReferences
            : entry.previousReferences
        let replacementReferences = direction == .undo
            ? entry.previousReferences
            : entry.nextReferences
        guard canvasReferences(for: entry.target, in: updatedProject.project) == expectedReferences else {
            synchronizeAfterCanvasReferenceHistoryConflict(with: targetProject)
            return false
        }

        switch entry.target.segment {
        case .pages:
            guard let index = updatedProject.project.chapters.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasReferenceHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.chapters[index].references = replacementReferences
        case .components:
            guard let index = updatedProject.project.collections.firstIndex(where: {
                $0.internalID == entry.target.containerInternalID
            }) else {
                synchronizeAfterCanvasReferenceHistoryConflict(with: targetProject)
                return false
            }
            updatedProject.project.collections[index].references = replacementReferences
        }

        do {
            try writeProjectManifest(updatedProject.project, to: entry.projectURL)
            self.loadedProject = updatedProject
            reconcileCanvasReferenceSelectionAfterManifestChange()
            lastError = nil
            statusMessage = direction == .undo
                ? "参照配置の変更を取り消しました。"
                : "参照配置の変更をやり直しました。"
            restartExternalProjectMonitoring(force: true)
            return true
        } catch {
            lastError = "参照配置履歴の同期に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    /// 論理名（日本語）: 参照配置履歴競合同期関数
    /// 処理概要: 履歴記録後に対象参照配置配列が外部変更された場合、上書きを中止して最新manifestを表示し、無効化された時系列を破棄します。
    ///
    /// - Parameter project: ディスクから再読込した最新project。
    private func synchronizeAfterCanvasReferenceHistoryConflict(
        with project: LoadedOpenGraphiteProject
    ) {
        loadedProject = project
        reconcileCanvasReferenceSelectionAfterManifestChange()
        editorUndoStack.removeAll()
        editorRedoStack.removeAll()
        lastError = nil
        statusMessage = ".ogp の外部変更を検出したため、参照配置の履歴適用を中止しました。"
        restartExternalProjectMonitoring(force: true)
        updateHistoryAvailability()
    }

    /// 論理名（日本語）: 注釈履歴後選択整合関数
    /// 処理概要: manifest 差し替え後も存在する注釈だけを複数選択と primary 選択へ残します。
    private func reconcileCanvasAnnotationSelectionAfterManifestChange() {
        let availableIDs = Set(selectedCanvasAnnotations.map(\.internalID))
        let survivingIDs = selectedCanvasAnnotationIDs.intersection(availableIDs)
        let primaryID = selectedCanvasAnnotationID.flatMap {
            survivingIDs.contains($0) ? $0 : nil
        } ?? selectedCanvasAnnotations.last(where: {
            survivingIDs.contains($0.internalID)
        })?.internalID
        applyCanvasAnnotationSelection(ids: survivingIDs, primaryID: primaryID)
    }

    /// 論理名（日本語）: 外部ページ監視再起動関数
    /// 処理概要: project 内の全 HTML ファイルを監視し、外部変更時にページ単位の同期を試みます。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalPageMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            cancelPageChangeMonitors()
            return
        }

        guard let loadedProject else {
            cancelPageChangeMonitors()
            return
        }

        let pageURLs = Set(loadedProject.project.allPages.map { loadedProject.htmlURL(for: $0) })
        for monitoredURL in Array(pageChangeMonitorsByURL.keys) where !pageURLs.contains(monitoredURL) {
            pageChangeMonitorsByURL[monitoredURL]?.cancel()
            pageChangeMonitorsByURL.removeValue(forKey: monitoredURL)
        }

        for pageURL in pageURLs where force || pageChangeMonitorsByURL[pageURL] == nil {
            pageChangeMonitorsByURL[pageURL]?.cancel()
            let monitor = OpenGraphiteFileChangeMonitor()
            monitor.start(url: pageURL) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { @MainActor [weak self] in
                        self?.refreshPageFromDiskIfChanged(at: pageURL)
                    }
                }
            }
            pageChangeMonitorsByURL[pageURL] = monitor
        }
    }

    /// 論理名（日本語）: 外部依存ファイル監視再起動関数
    /// 処理概要: CSS、component master、runtime script など page 表示に影響するファイルを監視します。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalDependencyMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            cancelDependencyChangeMonitors()
            return
        }

        guard let loadedProject else {
            cancelDependencyChangeMonitors()
            return
        }

        let dependencyURLs = projectDependencyURLs(for: loadedProject)
        for monitoredURL in Array(dependencyChangeMonitorsByURL.keys) where !dependencyURLs.contains(monitoredURL) {
            dependencyChangeMonitorsByURL[monitoredURL]?.cancel()
            dependencyChangeMonitorsByURL.removeValue(forKey: monitoredURL)
        }

        for dependencyURL in dependencyURLs where force || dependencyChangeMonitorsByURL[dependencyURL] == nil {
            dependencyChangeMonitorsByURL[dependencyURL]?.cancel()
            let monitor = OpenGraphiteFileChangeMonitor()
            monitor.start(url: dependencyURL) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { @MainActor [weak self] in
                        self?.refreshProjectDependencyFromDiskIfChanged(at: dependencyURL)
                    }
                }
            }
            dependencyChangeMonitorsByURL[dependencyURL] = monitor
        }
    }

    /// 論理名（日本語）: ページ変更監視停止関数
    /// 処理概要: 登録済みの全 HTML ファイル監視を停止します。
    private func cancelPageChangeMonitors() {
        for monitor in pageChangeMonitorsByURL.values {
            monitor.cancel()
        }
        pageChangeMonitorsByURL = [:]
    }

    /// 論理名（日本語）: 依存ファイル監視停止関数
    /// 処理概要: 登録済みの CSS / component / runtime file 監視を停止します。
    private func cancelDependencyChangeMonitors() {
        for monitor in dependencyChangeMonitorsByURL.values {
            monitor.cancel()
        }
        dependencyChangeMonitorsByURL = [:]
    }

    /// 論理名（日本語）: 外部プロジェクト監視再起動関数
    /// 処理概要: 現在開いている `.ogp` ファイルを監視し、外部変更時に project manifest を再読み込みします。
    ///
    /// - Parameter force: 同じ URL でも監視を作り直す場合は `true`。
    private func restartExternalProjectMonitoring(force: Bool = false) {
        guard !Self.isRunningTests else {
            projectChangeMonitor.cancel()
            monitoredProjectURL = nil
            return
        }

        guard let projectURL = loadedProject?.fileURL else {
            projectChangeMonitor.cancel()
            monitoredProjectURL = nil
            return
        }

        guard force || monitoredProjectURL != projectURL else { return }
        monitoredProjectURL = projectURL
        projectChangeMonitor.start(url: projectURL) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task { @MainActor [weak self] in
                    self?.refreshProjectManifestFromDiskIfChanged()
                }
            }
        }
    }

    /// 論理名（日本語）: project依存URL抽出関数
    /// 処理概要: project の HTML から local stylesheet、component link、runtime script の URL を収集します。
    private func projectDependencyURLs(for loadedProject: LoadedOpenGraphiteProject) -> Set<URL> {
        var urls: Set<URL> = []
        let fileManager = FileManager.default

        let cssURL = loadedProject.cssURL.standardizedFileURL
        if fileManager.fileExists(atPath: cssURL.path) {
            urls.insert(cssURL)
        }

        for component in loadedProject.project.components {
            let componentURL = loadedProject.htmlURL(for: component).standardizedFileURL
            if fileManager.fileExists(atPath: componentURL.path) {
                urls.insert(componentURL)
            }
        }

        for page in loadedProject.project.allPages {
            let pageURL = loadedProject.htmlURL(for: page).standardizedFileURL
            guard let html = readHTMLFromDisk(at: pageURL) else { continue }
            for href in dependencyHrefs(in: html) {
                let dependencyURL = resolveDependencyURL(href, relativeTo: pageURL).standardizedFileURL
                if dependencyURL.isFileURL, fileManager.fileExists(atPath: dependencyURL.path) {
                    urls.insert(dependencyURL)
                }
            }
        }

        urls.formUnion(
            localCSSImportDependencyURLs(
                startingAt: Set(urls.filter { $0.pathExtension.caseInsensitiveCompare("css") == .orderedSame }),
                allowedRootURL: loadedProject.rootURL
            )
        )

        let pageURLs = Set(loadedProject.project.chapters.flatMap(\.pages).map { loadedProject.htmlURL(for: $0).standardizedFileURL })
        return urls.subtracting(pageURLs)
    }

    /// 論理名（日本語）: Local CSS import依存URL展開関数
    /// 処理概要: HTML/projectから到達したCSSの`@import`をcycle-safeに辿り、project root内の実在fileだけを監視集合へ追加します。
    ///
    /// - Parameters:
    ///   - startingURLs: HTMLまたはproject manifestから直接参照されたCSS URL。
    ///   - allowedRootURL: importが越えてはならないproject root URL。
    /// - Returns: 起点を含むlocal CSS依存URL集合。
    private func localCSSImportDependencyURLs(
        startingAt startingURLs: Set<URL>,
        allowedRootURL: URL
    ) -> Set<URL> {
        let fileManager = FileManager.default
        let allowedRoot = allowedRootURL.standardizedFileURL.resolvingSymlinksInPath()
        var pending = Array(startingURLs)
        var visited: Set<URL> = []

        while let candidate = pending.popLast() {
            let cssURL = candidate.standardizedFileURL.resolvingSymlinksInPath()
            guard cssURL.isFileURL,
                  Self.isDependencyURL(cssURL, containedIn: allowedRoot),
                  cssURL.pathExtension.caseInsensitiveCompare("css") == .orderedSame,
                  !visited.contains(cssURL),
                  fileManager.fileExists(atPath: cssURL.path)
            else {
                continue
            }
            visited.insert(cssURL)
            guard let css = try? String(contentsOf: cssURL, encoding: .utf8) else { continue }
            for href in cssImportHrefs(in: css) {
                let importedURL = resolveDependencyURL(href, relativeTo: cssURL)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                guard importedURL.isFileURL,
                      Self.isDependencyURL(importedURL, containedIn: allowedRoot),
                      importedURL.pathExtension.caseInsensitiveCompare("css") == .orderedSame,
                      fileManager.fileExists(atPath: importedURL.path)
                else {
                    continue
                }
                pending.append(importedURL)
            }
        }
        return visited
    }

    /// 論理名（日本語）: CSS import href抽出関数
    /// 処理概要: comment/string内の見かけ上の`@import`を除外し、quotedまたは`url()`形式の標準import URLをlossless sourceから意味値へ復号します。
    ///
    /// - Parameter css: 調査するCSS source。
    /// - Returns: source順のimport href一覧。
    private func cssImportHrefs(in css: String) -> [String] {
        let characters = Array(css)
        var hrefs: [String] = []
        var index = 0

        func skipsComment(at cursor: Int) -> Bool {
            cursor + 1 < characters.count
                && characters[cursor] == "/"
                && characters[cursor + 1] == "*"
        }

        func skipComment(_ cursor: inout Int) {
            guard skipsComment(at: cursor) else { return }
            cursor += 2
            while cursor + 1 < characters.count {
                if characters[cursor] == "*", characters[cursor + 1] == "/" {
                    cursor += 2
                    return
                }
                cursor += 1
            }
            cursor = characters.count
        }

        func skipTrivia(_ cursor: inout Int) {
            while cursor < characters.count {
                if characters[cursor].isWhitespace {
                    cursor += 1
                } else if skipsComment(at: cursor) {
                    skipComment(&cursor)
                } else {
                    return
                }
            }
        }

        func parseQuotedValue(_ cursor: inout Int) -> String? {
            guard cursor < characters.count,
                  characters[cursor] == "\"" || characters[cursor] == "'"
            else {
                return nil
            }
            let quote = characters[cursor]
            cursor += 1
            var raw = ""
            while cursor < characters.count {
                let character = characters[cursor]
                if character == quote {
                    cursor += 1
                    return Self.decodedCSSImportURL(raw)
                }
                if character == "\\", cursor + 1 < characters.count {
                    raw.append(character)
                    cursor += 1
                    raw.append(characters[cursor])
                    cursor += 1
                    continue
                }
                raw.append(character)
                cursor += 1
            }
            return nil
        }

        func parseIdentifier(_ cursor: inout Int) -> String {
            var raw = ""
            while cursor < characters.count {
                let character = characters[cursor]
                if Self.isCSSIdentifierCharacter(character) {
                    raw.append(character)
                    cursor += 1
                    continue
                }
                guard character == "\\", cursor + 1 < characters.count else { break }
                raw.append(character)
                cursor += 1
                var hexCount = 0
                while cursor < characters.count,
                      hexCount < 6,
                      characters[cursor].isHexDigit {
                    raw.append(characters[cursor])
                    cursor += 1
                    hexCount += 1
                }
                if hexCount == 0, cursor < characters.count {
                    raw.append(characters[cursor])
                    cursor += 1
                } else if cursor < characters.count, characters[cursor].isWhitespace {
                    raw.append(characters[cursor])
                    cursor += 1
                }
            }
            return Self.decodedCSSImportURL(raw) ?? ""
        }

        while index < characters.count {
            if skipsComment(at: index) {
                skipComment(&index)
                continue
            }
            if characters[index] == "\"" || characters[index] == "'" {
                _ = parseQuotedValue(&index)
                continue
            }
            if characters[index] == "\\" {
                index = min(index + 2, characters.count)
                continue
            }
            guard characters[index] == "@" else {
                index += 1
                continue
            }
            var cursor = index + 1
            let atKeyword = parseIdentifier(&cursor)
            guard atKeyword.caseInsensitiveCompare("import") == .orderedSame else {
                index += 1
                continue
            }
            skipTrivia(&cursor)
            var href = parseQuotedValue(&cursor)
            if href == nil {
                let beforeURL = cursor
                let functionName = parseIdentifier(&cursor)
                guard functionName.caseInsensitiveCompare("url") == .orderedSame else {
                    index = max(index + 1, cursor)
                    continue
                }
                skipTrivia(&cursor)
                if cursor < characters.count, characters[cursor] == "(" {
                    cursor += 1
                    skipTrivia(&cursor)
                    href = parseQuotedValue(&cursor)
                    if href == nil {
                        var raw = ""
                        while cursor < characters.count {
                            if characters[cursor] == ")" { break }
                            if characters[cursor] == "\\", cursor + 1 < characters.count {
                                raw.append(characters[cursor])
                                cursor += 1
                                raw.append(characters[cursor])
                                cursor += 1
                                continue
                            }
                            raw.append(characters[cursor])
                            cursor += 1
                        }
                        href = Self.decodedCSSImportURL(
                            raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                } else {
                    cursor = beforeURL
                }
            }
            if let href, !href.isEmpty {
                hrefs.append(href)
            }
            index = max(index + 1, cursor)
        }
        return hrefs
    }

    /// 論理名（日本語）: CSS import URL escape復号関数
    /// 処理概要: CSS string/url tokenのsimple escape、hex escape、line continuationをfile URL解決用の意味値へ変換します。
    ///
    /// - Parameter raw: quoteを除いたCSS URL token source。
    /// - Returns: 復号済みURL。NULまたは不正scalarを含む場合は`nil`。
    private static func decodedCSSImportURL(_ raw: String) -> String? {
        let scalars = Array(raw.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            guard scalar != "\0" else { return nil }
            guard scalar == "\\" else {
                result.append(scalar)
                index += 1
                continue
            }
            index += 1
            guard index < scalars.count else { return nil }
            if scalars[index] == "\n" || scalars[index] == "\r" || scalars[index] == "\u{000C}" {
                if scalars[index] == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 1
                }
                index += 1
                continue
            }
            var hex = ""
            while index < scalars.count, hex.count < 6,
                  CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains(scalars[index]) {
                hex.unicodeScalars.append(scalars[index])
                index += 1
            }
            if !hex.isEmpty {
                guard let value = UInt32(hex, radix: 16),
                      value != 0,
                      let decoded = UnicodeScalar(value)
                else {
                    return nil
                }
                result.append(decoded)
                if index < scalars.count, CharacterSet.whitespacesAndNewlines.contains(scalars[index]) {
                    index += 1
                }
                continue
            }
            result.append(scalars[index])
            index += 1
        }
        return String(result)
    }

    /// 論理名（日本語）: 依存URL root包含判定関数
    /// 処理概要: symlink解決済みcandidateがproject root自身またはその子孫であることをpath component境界付きで確認します。
    ///
    /// - Parameters:
    ///   - candidate: 判定するlocal file URL。
    ///   - root: 許可するlocal root URL。
    /// - Returns: candidateがroot内にある場合は`true`。
    private static func isDependencyURL(_ candidate: URL, containedIn root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path == root.path || candidate.path.hasPrefix(rootPath)
    }

    /// 論理名（日本語）: Component依存参照書き換え関数
    /// 処理概要: Component HTML ファイル名変更時に、参照元 HTML の component link と同名 CSS link を新しい相対 path へ更新します。
    ///
    /// - Parameters:
    ///   - loadedProject: 変更前の project。
    ///   - currentHTMLURL: 変更前 component HTML URL。
    ///   - nextHTMLURL: 変更後 component HTML URL。
    ///   - excludingPageInternalID: rename 対象自身の page 内部 ID。
    /// - Returns: 失敗時 rollback に使う変更前 HTML data 一覧。
    private func rewriteComponentDependencyReferences(
        in loadedProject: LoadedOpenGraphiteProject,
        from currentHTMLURL: URL,
        to nextHTMLURL: URL,
        excludingPageInternalID: String
    ) throws -> [HTMLDependencyRewriteBackup] {
        var backups: [HTMLDependencyRewriteBackup] = []
        do {
            for page in loadedProject.project.allPages where page.internalID != excludingPageInternalID {
                let pageURL = loadedProject.htmlURL(for: page).standardizedFileURL
                guard let data = try? Data(contentsOf: pageURL),
                      let html = String(data: data, encoding: .utf8)
                else {
                    continue
                }
                let rewrittenHTML = rewriteComponentDependencyReferences(
                    in: html,
                    pageURL: pageURL,
                    currentHTMLURL: currentHTMLURL,
                    nextHTMLURL: nextHTMLURL
                )
                guard rewrittenHTML != html else { continue }
                backups.append(HTMLDependencyRewriteBackup(url: pageURL, data: data))
                try rewrittenHTML.write(to: pageURL, atomically: true, encoding: .utf8)
                lastKnownPageHTMLByURL[pageURL] = rewrittenHTML
                incrementReloadToken(for: pageURL)
            }
            return backups
        } catch {
            for backup in backups {
                try? backup.data.write(to: backup.url, options: .atomic)
            }
            throw error
        }
    }

    /// 論理名（日本語）: Component依存参照HTML書き換え関数
    /// 処理概要: HTML 文字列内の `opengraphite-components` と同名 stylesheet 参照を、新しい component ファイル名へ差し替えます。
    ///
    /// - Parameters:
    ///   - html: 書き換え対象 HTML。
    ///   - pageURL: HTML の URL。
    ///   - currentHTMLURL: 変更前 component HTML URL。
    ///   - nextHTMLURL: 変更後 component HTML URL。
    /// - Returns: 必要な href を置換した HTML。
    private func rewriteComponentDependencyReferences(
        in html: String,
        pageURL: URL,
        currentHTMLURL: URL,
        nextHTMLURL: URL
    ) -> String {
        let currentComponentURL = currentHTMLURL.standardizedFileURL
        let nextComponentURL = nextHTMLURL.standardizedFileURL
        let currentCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: currentHTMLURL).standardizedFileURL
        let nextCSSURL = OpenGraphiteCompanionCSSDocument.companionURL(forHTMLURL: nextHTMLURL).standardizedFileURL
        var result = html
        for tag in matches(pattern: #"<link\b[^>]*>"#, in: html).reversed() {
            guard let href = attribute("href", in: tag) else { continue }
            let rel = attribute("rel", in: tag)?.lowercased() ?? ""
            let resolvedURL = resolveDependencyURL(href, relativeTo: pageURL).standardizedFileURL
            let replacementHref: String?
            if rel == "opengraphite-components", resolvedURL == currentComponentURL {
                replacementHref = Self.relativePath(from: pageURL.deletingLastPathComponent(), to: nextComponentURL)
            } else if rel == "stylesheet", resolvedURL == currentCSSURL {
                replacementHref = Self.relativePath(from: pageURL.deletingLastPathComponent(), to: nextCSSURL)
            } else {
                replacementHref = nil
            }
            guard let replacementHref,
                  let rewrittenTag = replacingAttribute("href", in: tag, with: replacementHref),
                  let range = result.range(of: tag)
            else {
                continue
            }
            result.replaceSubrange(range, with: rewrittenTag)
        }
        return result
    }

    /// 論理名（日本語）: HTML属性値置換関数
    /// 処理概要: 開始タグ文字列に含まれる指定属性の値だけを置き換え、引用符や他属性を維持します。
    ///
    /// - Parameters:
    ///   - name: 置換する属性名。
    ///   - tag: 対象開始タグ文字列。
    ///   - value: 新しい属性値。
    /// - Returns: 属性値を置換したタグ。属性が見つからない場合は `nil`。
    private func replacingAttribute(_ name: String, in tag: String, with value: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }
        var rewrittenTag = tag
        rewrittenTag.replaceSubrange(range, with: htmlAttributeEscapedValue(value))
        return rewrittenTag
    }

    /// 論理名（日本語）: HTML属性値エスケープ関数
    /// 処理概要: href 属性へ保存する相対 path の最小 HTML entity escape を行います。
    ///
    /// - Parameter value: 属性へ保存する値。
    /// - Returns: HTML 属性値として安全な文字列。
    private func htmlAttributeEscapedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// 論理名（日本語）: HTML依存href抽出関数
    /// 処理概要: stylesheet、component link、script src の local 依存候補を HTML から取り出します。
    private func dependencyHrefs(in html: String) -> [String] {
        var hrefs: [String] = []
        for tag in matches(pattern: #"<link\b[^>]*>"#, in: html) {
            let relations = Set(
                (attribute("rel", in: tag) ?? "")
                    .split(whereSeparator: \Character.isWhitespace)
                    .map { $0.lowercased() }
            )
            guard relations.contains("stylesheet") || relations.contains("opengraphite-components") else {
                continue
            }
            if let href = attribute("href", in: tag) {
                hrefs.append(href)
            }
        }
        for tag in matches(pattern: #"<script\b[^>]*>"#, in: html) {
            if let src = attribute("src", in: tag) {
                hrefs.append(src)
            }
        }
        return hrefs
    }

    /// 論理名（日本語）: HTML属性値抽出関数
    /// 処理概要: 開始タグ文字列から指定属性の値を単純抽出します。
    private func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }
        return String(tag[range])
    }

    /// 論理名（日本語）: HTML正規表現一致抽出関数
    /// 処理概要: 指定 pattern に一致する部分文字列を順序通りに返します。
    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let swiftRange = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    /// 論理名（日本語）: 依存URL解決関数
    /// 処理概要: HTML 内の相対 URL を HTML ファイル位置から file URL へ解決します。
    private func resolveDependencyURL(_ href: String, relativeTo pageURL: URL) -> URL {
        let hrefWithoutFragment = href
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? href
        let hrefWithoutQuery = hrefWithoutFragment
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? hrefWithoutFragment

        if hrefWithoutQuery.hasPrefix("/") {
            return URL(fileURLWithPath: hrefWithoutQuery)
        }
        if hrefWithoutQuery.contains("://") {
            return URL(string: hrefWithoutQuery) ?? pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutQuery)
        }
        return pageURL.deletingLastPathComponent().appendingPathComponent(hrefWithoutQuery)
    }

    /// 論理名（日本語）: 履歴ステータスメッセージ生成関数
    /// 処理概要: undo/redo 適用後に表示する短い同期結果メッセージを生成します。
    ///
    /// - Parameters:
    ///   - direction: 適用した履歴移動方向。
    ///   - pageURL: 対象ページ URL。
    /// - Returns: 画面表示用のステータスメッセージ。
    private func historyStatusMessage(for direction: HistoryNavigationDirection, pageURL: URL) -> String {
        switch direction {
        case .undo:
            return "\(pageURL.lastPathComponent) の変更を取り消して同期しました。"
        case .redo:
            return "\(pageURL.lastPathComponent) の変更をやり直して同期しました。"
        }
    }

    private static let animationContextPropertyOrder = [
        "animation-name",
        "animation-duration",
        "animation-delay",
        "animation-timing-function",
        "animation-iteration-count",
        "animation-fill-mode",
        "animation-direction",
        "animation-play-state",
        "animation",
        "animation-timeline",
        "animation-range-start",
        "animation-range-end",
        "animation-range",
        "timeline-scope",
        "scroll-timeline-name",
        "scroll-timeline-axis",
        "scroll-timeline",
        "view-timeline-name",
        "view-timeline-axis",
        "view-timeline-inset",
        "view-timeline"
    ]

    private static let timelineProviderPropertyKeys = [
        "timeline-scope",
        "scroll-timeline-name",
        "scroll-timeline",
        "view-timeline-name",
        "view-timeline"
    ]

    /// 論理名（日本語）: 祖先ノード一覧生成関数
    /// 処理概要: WebView 由来の DOM 順 `nodes` と `depth` から、選択ノードの祖先を近い順に復元します。
    ///
    /// - Parameters:
    ///   - nodes: DOM 順に並んだ編集ノード一覧。
    ///   - selectedIndex: 選択ノードの index。
    /// - Returns: 選択ノードの祖先一覧。親から root に向かう順序です。
    private static func ancestorNodes(in nodes: [OpenGraphiteNode], selectedIndex: Int) -> [OpenGraphiteNode] {
        guard nodes.indices.contains(selectedIndex) else { return [] }
        var requiredDepth = nodes[selectedIndex].depth - 1
        guard requiredDepth >= 0 else { return [] }

        var ancestors: [OpenGraphiteNode] = []
        for index in stride(from: selectedIndex - 1, through: 0, by: -1) {
            let candidate = nodes[index]
            if candidate.depth == requiredDepth {
                ancestors.append(candidate)
                requiredDepth -= 1

                if requiredDepth < 0 {
                    break
                }
            }
        }
        return ancestors
    }

    /// 論理名（日本語）: アニメーション文脈生成関数
    /// 処理概要: 対象ノードが持つ animation / timeline declaration を Inspector 表示用 context へ変換します。
    ///
    /// - Parameters:
    ///   - node: 表示元になる祖先ノード。
    ///   - matchedTimelineNames: 選択ノードの `animation-timeline` と一致した named timeline。
    /// - Returns: 表示する CSS declaration がある場合は context。空の場合は `nil`。
    private static func animationContext(
        for node: OpenGraphiteNode,
        matchedTimelineNames: [String] = []
    ) -> OpenGraphiteAppliedAnimationContext? {
        let declarations = animationContextPropertyOrder.compactMap { key -> OpenGraphiteAppliedAnimationDeclaration? in
            guard let value = node.cssVariables[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                return nil
            }
            return OpenGraphiteAppliedAnimationDeclaration(key: key, value: value)
        }
        guard !declarations.isEmpty else { return nil }
        return OpenGraphiteAppliedAnimationContext(
            nodeID: node.id,
            nodeInternalID: node.internalID,
            displayID: node.displayID,
            tagName: node.tagName,
            declarations: declarations,
            matchedTimelineNames: matchedTimelineNames
        )
    }

    /// 論理名（日本語）: Timeline提供名抽出関数
    /// 処理概要: named scroll / view timeline を提供する CSS declaration から dashed ident を抽出します。
    ///
    /// - Parameter cssVariables: ノードが持つ CSS declaration。
    /// - Returns: `--name` 形式の timeline 名一覧。
    private static func timelineProviderNames(in cssVariables: [String: String]) -> Set<String> {
        timelineProviderPropertyKeys.reduce(into: Set<String>()) { names, key in
            names.formUnion(dashedIdentifiers(in: cssVariables[key] ?? ""))
        }
    }

    /// 論理名（日本語）: 選択オーバーレイnode frame変換関数
    /// 処理概要: JavaScript bridge payload の単一 node rect を Swift の選択枠用 tuple へ変換します。
    ///
    /// - Parameter payload: `id`、`x`、`y`、`width`、`height` を含む辞書。
    /// - Returns: node ID と有効な矩形。変換できない場合は `nil`。
    private static func selectionOverlayNodeFrame(from payload: [String: Any]) -> (id: String, rect: CGRect)? {
        let id = (payload["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty,
              let x = cgFloatValue(payload["x"]),
              let y = cgFloatValue(payload["y"]),
              let width = cgFloatValue(payload["width"]),
              let height = cgFloatValue(payload["height"]),
              width > 0,
              height > 0
        else {
            return nil
        }
        return (id, CGRect(x: x, y: y, width: width, height: height))
    }

    /// 論理名（日本語）: 矩形Union生成関数
    /// 処理概要: 複数の実測矩形をすべて覆う単一矩形へまとめます。
    ///
    /// - Parameter rects: 対象矩形一覧。
    /// - Returns: すべての矩形を覆う union 矩形。空の場合は `nil`。
    private static func unionRect(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { partialResult, rect in
            partialResult.union(rect)
        }
    }

    /// 論理名（日本語）: 任意文字列正規化関数
    /// 処理概要: 前後空白を除去し、空文字を `nil` に変換します。
    ///
    /// - Parameter value: 正規化する任意文字列。
    /// - Returns: 空でない正規化済み文字列。
    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    /// 論理名（日本語）: CGFloat payload変換関数
    /// 処理概要: JavaScript bridge 由来の数値を Canvas preview に使う有限な `CGFloat` へ変換します。
    ///
    /// - Parameter value: JavaScript payload の数値候補。
    /// - Returns: 有限な数値。変換できない場合は `nil`。
    private static func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let value = value as? Double, value.isFinite {
            return CGFloat(value)
        }
        if let value = value as? NSNumber {
            let doubleValue = value.doubleValue
            return doubleValue.isFinite ? CGFloat(doubleValue) : nil
        }
        return nil
    }

    /// 論理名（日本語）: CSS dashed ident抽出関数
    /// 処理概要: CSS 値から `--timeline-name` のような dashed ident を抽出します。
    ///
    /// - Parameter value: CSS property の文字列表現。
    /// - Returns: 見つかった dashed ident の集合。
    private static func dashedIdentifiers(in value: String) -> Set<String> {
        var identifiers = Set<String>()
        var index = value.startIndex

        while index < value.endIndex {
            let nextIndex = value.index(after: index)
            guard value[index] == "-", nextIndex < value.endIndex, value[nextIndex] == "-" else {
                index = nextIndex
                continue
            }

            var endIndex = value.index(after: nextIndex)
            while endIndex < value.endIndex, isCSSIdentifierCharacter(value[endIndex]) {
                endIndex = value.index(after: endIndex)
            }

            let identifier = String(value[index..<endIndex])
            if identifier.count > 2 {
                identifiers.insert(identifier)
            }
            index = endIndex
        }

        return identifiers
    }

    /// 論理名（日本語）: CSS識別子文字判定関数
    /// 処理概要: timeline 名の簡易抽出で、英数字、hyphen、underscore を識別子の構成文字として扱います。
    ///
    /// - Parameter character: 判定する 1 文字。
    /// - Returns: CSS dashed ident の一部として扱う場合は `true`。
    private static func isCSSIdentifierCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first
        else {
            return false
        }
        return CharacterSet.alphanumerics.contains(scalar)
            || character == "-"
            || character == "_"
    }

    /// 論理名（日本語）: ノード辞書変換関数
    /// 処理概要: JavaScript 由来の辞書から必須項目を検証し、`OpenGraphiteNode` を生成します。
    ///
    /// - Parameter dictionary: DOM ノードから収集した辞書。
    /// - Returns: 必須値がそろっている場合はノード、欠けている場合は `nil`。
    private static func node(from dictionary: [String: Any], sourceNode: OpenGraphiteAgentNode? = nil) -> OpenGraphiteNode? {
        guard
            let id = dictionary["id"] as? String,
            !id.isEmpty,
            let tagName = dictionary["tagName"] as? String
        else {
            return nil
        }

        var cssVariables = sourceNode?.cssVariables ?? [:]
        for (key, value) in dictionary["cssVariables"] as? [String: String] ?? [:] {
            if sourceNode != nil, sourceAuthoritativeStyleProperties.contains(key) {
                continue
            }
            cssVariables[key] = value
        }
        let computedStyle = nodeComputedStyle(from: dictionary["computedStyle"])
        let computedLayout = computedStyle.layoutMode
        let webAttributes = stringDictionary(dictionary["attributes"])
        let attributes = sourceNode?.attributes ?? webAttributes
        let webCapabilities = Set(
            stringArray(dictionary["capabilities"]).compactMap(OpenGraphiteNodeCapability.init(rawValue:))
        )
        let capabilities = sourceNode.map { sourceNode in
            dictionary["capabilities"] == nil
                ? Set(sourceNode.capabilities)
                : Set(sourceNode.capabilities).intersection(webCapabilities)
        } ?? webCapabilities
        let capabilityEvidence = mergedCapabilityEvidence(
            source: sourceNode?.capabilityEvidence,
            web: nodeCapabilityEvidence(from: dictionary["capabilityEvidence"]),
            computedDisplay: computedStyle.display
        )
        var node = OpenGraphiteNode(
            id: id,
            authoredID: sourceNode?.id ?? dictionary["authoredID"] as? String,
            standardID: sourceNode != nil
                ? sourceNode?.attributes["id"]
                : dictionary["standardID"] as? String,
            internalID: sourceNode?.internalID ?? dictionary["internalID"] as? String ?? "",
            reference: sourceNode?.reference ?? dictionary["reference"] as? String ?? "",
            annotationStatus: sourceNode?.annotationStatus ?? (dictionary["annotationStatus"] as? String)
                .flatMap(OpenGraphiteNodeAnnotationStatus.init(rawValue:)),
            referenceStability: sourceNode?.referenceStability ?? (dictionary["referenceStability"] as? String)
                .flatMap(OpenGraphiteNodeReferenceStability.init(rawValue:)),
            locator: sourceNode.map { nodeSourceLocator(from: $0.locator) }
                ?? nodeSourceLocator(from: dictionary["locator"]),
            parentReference: sourceNode != nil
                ? sourceNode?.parentReference
                : dictionary["parentReference"] as? String,
            tagName: tagName,
            legacyTypeHint: sourceNode != nil
                ? sourceNode?.legacyTypeHint
                : dictionary["legacyTypeHint"] as? String,
            capabilities: capabilities,
            capabilityEvidence: capabilityEvidence,
            attributes: attributes,
            layout: computedLayout.isEmpty ? (dictionary["layout"] as? String ?? sourceNode?.layout) : computedLayout,
            role: sourceNode != nil
                ? sourceNode?.attributes["role"]
                : dictionary["role"] as? String,
            componentID: sourceNode != nil
                ? sourceNode?.attributes["data-og-component"]
                : dictionary["componentID"] as? String,
            isComponentMaster: sourceNode.map { sourceNode in
                sourceNode.tagName.contains("-")
                    && sourceNode.tagName != "og-instance"
                    && sourceNode.attributes["data-og-component"] != nil
            } ?? (dictionary["componentMaster"] as? Bool ?? false),
            sourceComponentID: dictionary["sourceComponentID"] as? String,
            sourceInstanceID: dictionary["sourceInstanceID"] as? String,
            sourceNodeInternalID: dictionary["sourceNodeInternalID"] as? String,
            sourceNodeID: dictionary["sourceNodeID"] as? String,
            sourcePlacementID: dictionary["sourcePlacementID"] as? String,
            isPlacementGenerated: dictionary["placementGenerated"] as? Bool ?? false,
            textContent: dictionary["textContent"] as? String,
            fallbackTextContent: sourceNode?.textContent ?? dictionary["fallbackTextContent"] as? String,
            textSource: sourceNode != nil
                ? sourceNode?.attributes["data-og-text-source"]
                : dictionary["textSource"] as? String,
            i18nKey: sourceNode != nil
                ? sourceNode?.attributes["data-i18n-key"]
                : dictionary["i18nKey"] as? String,
            iconLibrary: sourceNode != nil
                ? sourceNode?.attributes["data-og-icon-library"]
                : dictionary["iconLibrary"] as? String,
            iconName: sourceNode != nil
                ? sourceNode?.attributes["data-og-icon-name"]
                : dictionary["iconName"] as? String,
            iconSource: sourceNode != nil
                ? sourceNode?.attributes["data-og-icon-source"]
                : dictionary["iconSource"] as? String,
            cssVariables: cssVariables,
            computedStyle: computedStyle,
            hasIncompleteCSSProvenance: (dictionary["unreadableStyleSheetCount"] as? Int ?? 0) > 0
                || sourceNode?.hasIncompleteCSSProvenance == true,
            renderTargets: renderingTargets(
                sourceTargets: sourceNode?.renderingTargets ?? [],
                webPayload: dictionary["renderingTargets"]
            ),
            isHidden: dictionary["hidden"] as? Bool ?? false,
            hasHiddenAttribute: sourceNode?.hidden ?? dictionary["hasHiddenAttribute"] as? Bool ?? false,
            isLocked: sourceNode.map { $0.attributes["data-og-locked"] == "true" }
                ?? dictionary["locked"] as? Bool ?? false,
            depth: dictionary["depth"] as? Int ?? 0
        )
        if let resolvedFontFamily = dictionary["resolvedFontFamily"] as? String {
            let normalizedFontFamily = resolvedFontFamily.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedFontFamily.isEmpty {
                node.resolvedFontFamily = normalizedFontFamily
            }
        }
        return node
    }

    /// 論理名（日本語）: WebCanvas capability evidence変換関数
    /// 処理概要: JavaScript payloadの標準DOM semantic flagsをShared schemaと同じevidence値へ変換します。
    ///
    /// - Parameter payload: WebCanvasが返す`capabilityEvidence`辞書。
    /// - Returns: 必須boolean値を持つevidence。payloadがない場合は`nil`。
    private static func nodeCapabilityEvidence(from payload: Any?) -> OpenGraphiteNodeCapabilityEvidence? {
        guard let values = payload as? [String: Any] else { return nil }
        return OpenGraphiteNodeCapabilityEvidence(
            isProjectResourceRoot: values["isProjectResourceRoot"] as? Bool ?? false,
            isNativeControl: values["isNativeControl"] as? Bool ?? false,
            isCustomElement: values["isCustomElement"] as? Bool ?? false,
            isLink: values["isLink"] as? Bool ?? false,
            hasDirectText: values["hasDirectText"] as? Bool ?? false,
            hasElementChildren: values["hasElementChildren"] as? Bool ?? false,
            hasMediaContent: values["hasMediaContent"] as? Bool ?? false,
            hasSVGContent: values["hasSVGContent"] as? Bool ?? false,
            hasMaskContent: values["hasMaskContent"] as? Bool ?? false,
            ariaRole: nonEmptyTrimmed(values["ariaRole"] as? String),
            resolvedDisplay: nonEmptyTrimmed(values["resolvedDisplay"] as? String)
        )
    }

    /// 論理名（日本語）: Source/WebKit capability evidence統合関数
    /// 処理概要: project root境界は両経路の検出を維持し、その他のsemantic evidenceはsource/runtime両方が肯定した安全側だけを採用します。
    ///
    /// - Parameters:
    ///   - source: Shared source inspection由来のevidence。
    ///   - web: WebCanvas DOM由来のevidence。
    ///   - computedDisplay: WebKitが現在解決した`display`。
    /// - Returns: Appでinspectionとcapability説明に使う統合evidence。
    private static func mergedCapabilityEvidence(
        source: OpenGraphiteNodeCapabilityEvidence?,
        web: OpenGraphiteNodeCapabilityEvidence?,
        computedDisplay: String
    ) -> OpenGraphiteNodeCapabilityEvidence {
        let agreed: (Bool?, Bool?) -> Bool = { sourceValue, webValue in
            switch (sourceValue, webValue) {
            case let (.some(sourceValue), .some(webValue)):
                sourceValue && webValue
            case let (.some(sourceValue), .none):
                sourceValue
            case let (.none, .some(webValue)):
                webValue
            case (.none, .none):
                false
            }
        }
        let ariaRole: String?
        if let sourceRole = source?.ariaRole, let webRole = web?.ariaRole {
            ariaRole = sourceRole.caseInsensitiveCompare(webRole) == .orderedSame ? webRole : nil
        } else {
            ariaRole = web?.ariaRole ?? source?.ariaRole
        }
        return OpenGraphiteNodeCapabilityEvidence(
            isProjectResourceRoot: source?.isProjectResourceRoot == true || web?.isProjectResourceRoot == true,
            isNativeControl: agreed(source?.isNativeControl, web?.isNativeControl),
            isCustomElement: agreed(source?.isCustomElement, web?.isCustomElement),
            isLink: agreed(source?.isLink, web?.isLink),
            hasDirectText: agreed(source?.hasDirectText, web?.hasDirectText),
            hasElementChildren: agreed(source?.hasElementChildren, web?.hasElementChildren),
            hasMediaContent: agreed(source?.hasMediaContent, web?.hasMediaContent),
            hasSVGContent: agreed(source?.hasSVGContent, web?.hasSVGContent),
            hasMaskContent: agreed(source?.hasMaskContent, web?.hasMaskContent),
            ariaRole: nonEmptyTrimmed(ariaRole),
            resolvedDisplay: nonEmptyTrimmed(computedDisplay)
                ?? nonEmptyTrimmed(web?.resolvedDisplay)
                ?? nonEmptyTrimmed(source?.resolvedDisplay)
        )
    }

    /// 論理名（日本語）: WebKit computed style変換関数
    /// 処理概要: JavaScript bridgeのcomputed値をauthored CSS辞書へ混ぜず、現在の描画状態専用モデルへ変換します。
    ///
    /// - Parameter payload: `getComputedStyle()`から抽出した標準CSS値辞書。
    /// - Returns: 不足値を空文字列で補ったcomputed style。
    private static func nodeComputedStyle(from payload: Any?) -> OpenGraphiteNodeComputedStyle {
        let values = stringDictionary(payload)
        return OpenGraphiteNodeComputedStyle(
            display: values["display"] ?? "",
            flexDirection: values["flexDirection"] ?? "",
            gridTemplateColumns: values["gridTemplateColumns"] ?? "",
            gridTemplateRows: values["gridTemplateRows"] ?? "",
            gridAutoFlow: values["gridAutoFlow"] ?? "",
            position: values["position"] ?? "",
            visibility: values["visibility"] ?? "",
            contentVisibility: values["contentVisibility"] ?? "",
            overflowWrap: values["overflowWrap"] ?? "",
            alignItems: values["alignItems"] ?? "",
            justifyContent: values["justifyContent"] ?? ""
        )
    }

    /// 論理名（日本語）: WebCanvas source locator変換関数
    /// 処理概要: JavaScript bridge の locator 辞書を non-invasive selection / adoption で使う App model へ変換します。
    ///
    /// - Parameter payload: `documentURL`、selector、DOM path、source range、content hash を含む辞書。
    /// - Returns: 必須の document URL と DOM path がある locator。形式不正時は `nil`。
    private static func nodeSourceLocator(from payload: Any?) -> OpenGraphiteNodeSourceLocator? {
        guard let dictionary = payload as? [String: Any],
              let documentURL = dictionary["documentURL"] as? String,
              let domPath = dictionary["domPath"] as? String,
              let contentHash = dictionary["contentHash"] as? String
        else {
            return nil
        }
        let sourceRange = dictionary["sourceRange"] as? [String: Any]
        return OpenGraphiteNodeSourceLocator(
            documentURL: documentURL,
            selector: (dictionary["selector"] as? String).flatMap { value in
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            },
            domPath: domPath,
            sourceStart: sourceRange?["start"] as? Int ?? -1,
            sourceEnd: sourceRange?["end"] as? Int ?? -1,
            contentHash: contentHash
        )
    }

    /// 論理名（日本語）: Shared source locator変換関数
    /// 処理概要: source ASTが返した正確なrange/hashをAppのinspection locatorへ移します。
    ///
    /// - Parameter locator: Shared graphのsource locator。
    /// - Returns: Appのnon-invasive inspection / adoption locator。
    private static func nodeSourceLocator(from locator: OpenGraphiteNodeLocator) -> OpenGraphiteNodeSourceLocator {
        OpenGraphiteNodeSourceLocator(
            documentURL: locator.documentURL,
            selector: locator.selector,
            domPath: locator.domPath,
            sourceStart: locator.sourceRange.start,
            sourceEnd: locator.sourceRange.end,
            contentHash: locator.contentHash
        )
    }

    /// 論理名（日本語）: 描画実体payload統合関数
    /// 処理概要: Shared source ASTのauthored/provenance値とWebCanvasのcomputed値をkind単位で統合し、property単位のInspector modelへ変換します。
    ///
    /// - Parameters:
    ///   - sourceTargets: Shared graph が返す media / SVG / mask target。
    ///   - webPayload: JavaScript bridge が返す同じ実体の session-only computed payload。
    /// - Returns: `object-fit`、`stroke-width`、mask property単位の描画実体編集対象。
    private static func renderingTargets(
        sourceTargets: [OpenGraphiteAgentRenderingTarget],
        webPayload: Any?
    ) -> [OpenGraphiteRenderTarget] {
        let webTargets = (webPayload as? [[String: Any]] ?? []).compactMap(WebRenderingTargetPayload.init)
        let propertiesByKind: [(kind: String, properties: [String])] = [
            ("media", ["object-fit"]),
            ("svg", ["stroke-width"]),
            ("mask", ["mask-image", "-webkit-mask-image"])
        ]

        return propertiesByKind.flatMap { entry -> [OpenGraphiteRenderTarget] in
            let source = sourceTargets.first { $0.kind == entry.kind }
            let webCandidates = webTargets.filter { $0.kind == entry.kind }
            let web: WebRenderingTargetPayload?
            if let source {
                web = webCandidates.first { candidate in
                    source.targetInternalID?.isEmpty == false
                        && candidate.targetInternalID == source.targetInternalID
                } ?? webCandidates.first { candidate in
                    guard !candidate.targetStandardID.isEmpty else { return false }
                    let escapedID = candidate.targetStandardID
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    return source.writeSelector == "#\(candidate.targetStandardID)"
                        || source.writeSelector == "[id=\"\(escapedID)\"]"
                } ?? webCandidates.first { candidate in
                    !source.relationSelector.isEmpty
                        && candidate.relationSelector == source.relationSelector
                }
            } else {
                web = webCandidates.first
            }
            guard source != nil || web != nil else { return [] }
            return entry.properties.map { property in
                let trace = (source?.sourceTrace[property] ?? []).map { candidate in
                    OpenGraphiteRenderTargetSourceTrace(
                        authoredProperty: candidate.authoredProperty,
                        selector: candidate.selector,
                        atRuleScope: candidate.atRules.map { atRule in
                            "@\(atRule.name) \(atRule.prelude)".trimmingCharacters(in: .whitespaces)
                        },
                        value: candidate.value,
                        important: candidate.important,
                        specificityIDs: candidate.specificity.ids,
                        specificityClasses: candidate.specificity.classes,
                        specificityTypes: candidate.specificity.types,
                        sourceOrder: candidate.sourceOrder
                    )
                }
                return OpenGraphiteRenderTarget(
                    kind: entry.kind,
                    property: property,
                    targetTagName: source?.tagName ?? web?.tagName ?? "",
                    relation: source?.relation ?? web?.relation ?? "",
                    writeSelector: source?.writeSelector ?? "",
                    targetInternalID: source?.targetInternalID ?? web?.targetInternalID ?? "",
                    authoredValue: source?.authoredValues[property]
                        ?? web?.authoredInlineValues[property]
                        ?? "",
                    resolvedValue: source?.resolvedValues[property] ?? "",
                    computedValue: web?.computedValues[property] ?? "",
                    relationSelector: source?.relationSelector ?? web?.relationSelector ?? "",
                    sourceTrace: trace
                )
            }
        }
    }

    /// 論理名（日本語）: WebCanvas描画実体payload
    /// 概要: JavaScript辞書からkind、relation selector、inline/computed標準CSS値だけを安全に取り出します。
    private struct WebRenderingTargetPayload {
        var kind: String
        var tagName: String
        var relation: String
        var relationSelector: String
        var targetStandardID: String
        var targetInternalID: String
        var authoredInlineValues: [String: String]
        var computedValues: [String: String]

        /// 論理名（日本語）: WebCanvas描画実体payload初期化関数
        /// 処理概要: JavaScript bridge辞書に必要なkindがある場合だけ正規化済みpayloadを生成します。
        ///
        /// - Parameter dictionary: WebCanvas `renderingTargets` 配列内の辞書。
        init?(_ dictionary: [String: Any]) {
            guard let kind = dictionary["kind"] as? String, !kind.isEmpty else { return nil }
            self.kind = kind
            tagName = dictionary["tagName"] as? String ?? ""
            relation = dictionary["relation"] as? String ?? ""
            relationSelector = dictionary["relationSelector"] as? String ?? ""
            targetStandardID = dictionary["targetStandardID"] as? String ?? ""
            targetInternalID = dictionary["targetInternalID"] as? String ?? ""
            authoredInlineValues = EditorStore.stringDictionary(dictionary["authoredInlineValues"])
            computedValues = EditorStore.stringDictionary(dictionary["computedValues"])
        }
    }

    /// 論理名（日本語）: JavaScript文字列辞書変換関数
    /// 処理概要: WebKit bridgeが`[String: Any]`として渡した値から文字列entryだけを保持します。
    ///
    /// - Parameter value: JavaScript object由来の値。
    /// - Returns: 文字列だけを持つ辞書。
    nonisolated private static func stringDictionary(_ value: Any?) -> [String: String] {
        if let dictionary = value as? [String: String] { return dictionary }
        return (value as? [String: Any] ?? [:]).reduce(into: [String: String]()) { result, entry in
            guard let string = entry.value as? String else { return }
            result[entry.key] = string
        }
    }

    /// 論理名（日本語）: JavaScript文字列配列変換関数
    /// 処理概要: WebKit bridgeの配列から空白だけの値と重複を除き、source condition照合へ渡す安定順の文字列配列を返します。
    ///
    /// - Parameter value: JavaScript array由来の値。
    /// - Returns: 正規化済みの文字列配列。
    nonisolated private static func stringArray(_ value: Any?) -> [String] {
        let strings = (value as? [String]) ?? (value as? [Any] ?? []).compactMap { $0 as? String }
        return Array(Set(strings.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        })).sorted()
    }

    /// 論理名（日本語）: ノード表示ID正規化関数
    /// 処理概要: Layers の入力値を `data-og-id` として扱いやすい小文字英数字、ハイフン、アンダースコアの ID へ変換します。
    ///
    /// - Parameter value: 正規化する入力値。
    /// - Returns: 空になった場合は `node` を返します。
    private static func normalizedNodeDisplayID(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_-")
        var result = ""
        for character in value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            result.append(allowed.contains(character) ? character : "-")
        }
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result
            .replacingOccurrences(of: "_-", with: "_")
            .replacingOccurrences(of: "-_", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "node" : result
    }

}
