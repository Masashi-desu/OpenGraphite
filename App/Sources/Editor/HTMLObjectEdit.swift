import Foundation

/// 論理名（日本語）: HTMLドキュメント識別子
/// 概要: Pages / Components の文脈を含めて、`.ogp` 内の HTML カードを一意に指します。
///
/// プロパティ:
/// - `projectURL`: 所属する `.ogp` の URL。
/// - `segment`: Pages / Components の種別。
/// - `containerInternalID`: Chapter または Collection の内部 ID。
/// - `pageInternalID`: HTML カードの内部 ID。
struct HTMLDocumentIdentity: Equatable, Hashable {
    var projectURL: URL
    var segment: OpenGraphiteCanvasSegment
    var containerInternalID: String
    var pageInternalID: String
}

/// 論理名（日本語）: HTML同期対象
/// 概要: WebView が読み込んだ HTML の意味的識別子と、シリアライズ開始時点で固定する保存先 URL を保持します。
///
/// プロパティ:
/// - `identity`: `.ogp` 内の HTML カード識別子。
/// - `path`: `.ogp` に記録されている HTML path。
/// - `htmlURL`: 保存先として固定する HTML URL。
struct HTMLSyncTarget: Equatable {
    var identity: HTMLDocumentIdentity
    var path: String
    var htmlURL: URL
}

/// 論理名（日本語）: HTMLオブジェクト編集操作
/// 概要: 最新ディスク HTML に対して node 単位で rebase 可能な編集操作を表します。
///
/// 定義内容:
/// - `setCSSVariable`: CSS 変数を設定または削除します。
/// - `setCSSVariables`: 複数 CSS 変数を同一 node に設定または削除します。
/// - `setAttribute`: 永続属性を設定または削除します。
/// - `setIcon`: icon node の metadata と描画 HTML を更新します。
/// - `setTextContent`: text node のプレーンテキストを置換します。
/// - `insertHTML`: anchor node の相対位置へ HTML 断片を挿入します。
/// - `replaceNodeHTML`: node subtree を HTML 断片で置換します。
/// - `deleteNode`: node subtree を削除します。
/// - `moveNode`: node subtree を別位置へ移動します。
enum HTMLObjectEditOperation: Equatable {
    case setCSSVariable(nodeInternalID: String, key: String, value: String, expectedOldValue: String)
    case setCSSVariables(nodeInternalID: String, values: [String: String], expectedOldValues: [String: String])
    case setAttribute(nodeInternalID: String, name: String, value: String, expectedOldValue: String)
    case setIcon(nodeInternalID: String, library: String, name: String, source: String, expectedOldValues: [String: String])
    case setTextContent(nodeInternalID: String, text: String, expectedOldValue: String)
    case insertHTML(anchorInternalID: String, position: OpenGraphiteHTMLInsertionPosition, html: String, baselineNodeHash: String?)
    case replaceNodeHTML(nodeInternalID: String, html: String, baselineNodeHash: String?)
    case deleteNode(nodeInternalID: String, baselineNodeHash: String?)
    case moveNode(nodeInternalID: String, targetInternalID: String, position: OpenGraphiteHTMLInsertionPosition, baselineNodeHash: String?)

    /// 論理名（日本語）: WebView再読み込み要否
    /// 処理概要: WebView 側の DOM だけでは保存後の表示を継続できない操作かどうかを返します。
    var requiresWebViewReload: Bool {
        switch self {
        case .setCSSVariable, .setCSSVariables, .setAttribute, .setTextContent:
            return false
        case .setIcon:
            return true
        case .insertHTML, .replaceNodeHTML, .deleteNode:
            return true
        case .moveNode:
            return false
        }
    }
}

/// 論理名（日本語）: HTMLオブジェクト編集要求
/// 概要: 保存対象 HTML と node 単位の編集操作をまとめます。
///
/// プロパティ:
/// - `target`: 編集対象 HTML。
/// - `operation`: 適用する object edit。
struct HTMLObjectEdit: Equatable {
    var target: HTMLSyncTarget
    var operation: HTMLObjectEditOperation
}

/// 論理名（日本語）: HTMLオブジェクト編集結果
/// 概要: object edit の保存成否と、WebView をディスクから再読み込みすべきかを返します。
///
/// プロパティ:
/// - `updated`: ディスク HTML を更新できたか。
/// - `requiresReload`: WebView DOM をディスク内容で再同期すべきか。
struct HTMLObjectEditResult: Equatable {
    var updated: Bool
    var requiresReload: Bool

    static let noChange = HTMLObjectEditResult(updated: true, requiresReload: false)
    static let failed = HTMLObjectEditResult(updated: false, requiresReload: true)
}
