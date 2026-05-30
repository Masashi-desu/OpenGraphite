import Testing
@testable import OpenGraphite

/// 論理名（日本語）: ドキュメント同期履歴関連のテストスイート
/// 概要: 同期スナップショット単位の undo/redo スタック動作を検証します。
@Suite("ドキュメント同期履歴関連のテストスイート")
struct DocumentSyncHistoryTests {
    /// 論理名（日本語）: 同期単位履歴記録テスト
    /// 概要: HTML が変化した同期だけ undo 履歴へ積まれ、同じ HTML は重複記録されないことを確認します。
    @Test("同期されたHTMLだけを履歴へ記録する")
    func testRecordSyncStoresOnlyChangedHTML() {
        // コンディション：初期 HTML を持つ同期履歴を用意する
        var history = DocumentSyncHistory(initialHTML: "initial")

        // 検証内容：同じ HTML と異なる HTML を順に同期する
        let didRecordDuplicate = history.recordSync(html: "initial")
        let didRecordChange = history.recordSync(html: "changed")

        // 期待値：変更がある同期だけ undo 可能になる
        #expect(didRecordDuplicate == false)
        #expect(didRecordChange == true)
        #expect(history.canUndo == true)
        #expect(history.canRedo == false)
        #expect(history.undoStack == ["initial"])
    }

    /// 論理名（日本語）: 同期履歴取り消しやり直しテスト
    /// 概要: undo と redo が同期スナップショット単位で現在 HTML を移動することを確認します。
    @Test("同期スナップショット単位で取り消しとやり直しができる")
    func testUndoRedoMovesBetweenSyncedSnapshots() {
        // コンディション：複数回同期した履歴を用意する
        var history = DocumentSyncHistory(initialHTML: "initial")
        history.recordSync(html: "first")
        history.recordSync(html: "second")

        // 検証内容：一段取り消してからやり直す
        let undoHTML = history.undo()
        let redoHTML = history.redo()

        // 期待値：同期済みの HTML 単位で currentHTML が復元される
        #expect(undoHTML == "first")
        #expect(redoHTML == "second")
        #expect(history.currentHTML == "second")
        #expect(history.canUndo == true)
        #expect(history.canRedo == false)
    }
}
