import Foundation

/// 論理名（日本語）: ドキュメント置換要求
/// 概要: 取り消し・やり直しで確定した HTML スナップショットを WebView へ再適用する要求です。
///
/// プロパティ:
/// - `sequence`: 要求の順序番号。
/// - `pageURL`: 適用対象の HTML ファイル URL。
/// - `html`: 適用する HTML 全文。
/// - `selectedNodeID`: 復元後に再選択を試みる node ID。placement clone 内では表示専用の合成 ID。
struct DocumentReplacementRequest: Equatable {
    var sequence: Int
    var pageURL: URL
    var html: String
    var selectedNodeID: String?
}

/// 論理名（日本語）: ドキュメント同期履歴
/// 概要: ディスク同期された HTML スナップショットを単位として undo/redo スタックを管理します。
///
/// プロパティ:
/// - `currentHTML`: 現在ディスクと同期済みの HTML。
/// - `undoStack`: 取り消し先の HTML スナップショット一覧。
/// - `redoStack`: やり直し先の HTML スナップショット一覧。
struct DocumentSyncHistory: Equatable {
    private(set) var currentHTML: String
    private(set) var undoStack: [String]
    private(set) var redoStack: [String]
    private let maximumSnapshotCount: Int

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// 論理名（日本語）: ドキュメント同期履歴初期化関数
    /// 処理概要: 最初にディスクから読んだ HTML を現在値として履歴を初期化します。
    ///
    /// - Parameters:
    ///   - initialHTML: 初期状態の HTML。
    ///   - maximumSnapshotCount: undo/redo で保持する最大スナップショット数。
    init(initialHTML: String, maximumSnapshotCount: Int = 100) {
        self.currentHTML = initialHTML
        self.undoStack = []
        self.redoStack = []
        self.maximumSnapshotCount = maximumSnapshotCount
    }

    /// 論理名（日本語）: 同期スナップショット記録関数
    /// 処理概要: 新しい HTML が現在値と異なる場合だけ、現在値を undo 履歴へ積みます。
    ///
    /// - Parameter html: ディスク同期済みにする HTML。
    /// - Returns: 履歴が追加された場合は `true`。
    @discardableResult
    mutating func recordSync(html: String) -> Bool {
        guard html != currentHTML else { return false }

        undoStack.append(currentHTML)
        trimUndoStackIfNeeded()
        currentHTML = html
        redoStack.removeAll()
        return true
    }

    /// 論理名（日本語）: 取り消し関数
    /// 処理概要: 直前の同期スナップショットを現在値へ戻し、元の現在値を redo 履歴へ積みます。
    ///
    /// - Returns: 取り消し後に適用すべき HTML。取り消せない場合は `nil`。
    mutating func undo() -> String? {
        guard let previousHTML = undoStack.popLast() else { return nil }

        redoStack.append(currentHTML)
        trimRedoStackIfNeeded()
        currentHTML = previousHTML
        return previousHTML
    }

    /// 論理名（日本語）: やり直し関数
    /// 処理概要: redo 履歴の先頭スナップショットを現在値へ戻し、元の現在値を undo 履歴へ積みます。
    ///
    /// - Returns: やり直し後に適用すべき HTML。やり直せない場合は `nil`。
    mutating func redo() -> String? {
        guard let nextHTML = redoStack.popLast() else { return nil }

        undoStack.append(currentHTML)
        trimUndoStackIfNeeded()
        currentHTML = nextHTML
        return nextHTML
    }

    /// 論理名（日本語）: undo履歴上限調整関数
    /// 処理概要: undo スタックが上限を超えた場合に古いスナップショットを破棄します。
    private mutating func trimUndoStackIfNeeded() {
        guard undoStack.count > maximumSnapshotCount else { return }
        undoStack.removeFirst(undoStack.count - maximumSnapshotCount)
    }

    /// 論理名（日本語）: redo履歴上限調整関数
    /// 処理概要: redo スタックが上限を超えた場合に古いスナップショットを破棄します。
    private mutating func trimRedoStackIfNeeded() {
        guard redoStack.count > maximumSnapshotCount else { return }
        redoStack.removeFirst(redoStack.count - maximumSnapshotCount)
    }
}
