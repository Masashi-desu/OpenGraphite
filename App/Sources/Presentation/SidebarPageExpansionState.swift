import Foundation

/// 論理名（日本語）: サイドバーHTML展開状態
/// 概要: 左カラムの Pages / Components カード展開状態をキャンバス側のページ選択と同期するための軽量モデルです。
///
/// プロパティ:
/// - `expandedPageID`: 現在展開中の HTML page 内部 ID。
struct SidebarPageExpansionState: Equatable {
    private(set) var expandedPageID: String?

    /// 論理名（日本語）: サイドバーHTML展開状態初期化関数
    /// 処理概要: 既存の展開 page ID を指定して状態を構築します。
    ///
    /// - Parameter expandedPageID: 初期状態で展開しておく HTML page 内部 ID。
    init(expandedPageID: String? = nil) {
        self.expandedPageID = expandedPageID
    }

    /// 論理名（日本語）: HTMLカード展開判定関数
    /// 処理概要: 指定 page ID のカードが現在展開中かどうかを返します。
    ///
    /// - Parameter pageID: 判定対象の HTML page 内部 ID。
    /// - Returns: 展開中であれば `true`。
    func isExpanded(pageID: String) -> Bool {
        expandedPageID == pageID
    }

    /// 論理名（日本語）: HTMLカード展開関数
    /// 処理概要: 指定 page ID のカードを展開対象として保存します。
    ///
    /// - Parameter pageID: 展開する HTML page 内部 ID。
    mutating func expand(pageID: String) {
        expandedPageID = pageID
    }

    /// 論理名（日本語）: HTMLカード開閉切替関数
    /// 処理概要: 指定 page ID のカードが展開中なら閉じ、閉じていれば展開します。
    ///
    /// - Parameter pageID: 開閉を切り替える HTML page 内部 ID。
    mutating func toggle(pageID: String) {
        if expandedPageID == pageID {
            expandedPageID = nil
        } else {
            expandedPageID = pageID
        }
    }

    /// 論理名（日本語）: 選択HTML同期関数
    /// 処理概要: キャンバス側の選択 page ID に合わせて展開状態を更新し、選択解除時は展開状態も解除します。
    ///
    /// - Parameters:
    ///   - selectedPageID: 現在選択中の HTML page 内部 ID。選択解除時は `nil`。
    ///   - validPageIDs: 現在のサイドバーパネルに表示されている有効な HTML page 内部 ID 一覧。
    mutating func synchronizeSelection(selectedPageID: String?, validPageIDs: Set<String>) {
        guard let selectedPageID, validPageIDs.contains(selectedPageID) else {
            expandedPageID = nil
            return
        }

        expandedPageID = selectedPageID
    }
}
