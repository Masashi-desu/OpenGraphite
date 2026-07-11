import Testing
@testable import OpenGraphite

/// 論理名（日本語）: Canvas付箋Undo routingテストスイート
/// 概要: focus中TextEditorのnative履歴優先とmodel Undo / Redo後のdraft同期を検証します。
@Suite
struct CanvasStickyNoteUndoRoutingTests {
    /// 論理名（日本語）: Focus中native履歴優先テスト
    /// 概要: TextEditor focus中はEditorStore履歴よりnative UndoManagerを優先します。
    @Test
    func testFocusedTextEditorUsesNativeUndo() {
        // コンディション：TextEditorとEditorStoreの両方にUndo可能な履歴があるとき（Given）
        // 検証内容：送信先を解決したら（When）
        let destination = OpenGraphiteUndoCommandResolver.destination(
            isTextEditorFocused: true,
            canPerformNative: true,
            canPerformEditorStore: true
        )

        // 期待値：native TextEditorだけが選ばれる（Then）
        #expect(destination == .nativeTextEditor)
    }

    /// 論理名（日本語）: Focus中fallback抑止テスト
    /// 概要: TextEditorのnative履歴が空でも過去のEditorStore履歴を誤操作しないことを検証します。
    @Test
    func testFocusedTextEditorDoesNotFallBackToEditorStore() {
        // コンディション：TextEditor focus中でnative Undoが不能だがEditorStoreはUndo可能なとき（Given）
        // 検証内容：送信先を解決したら（When）
        let destination = OpenGraphiteUndoCommandResolver.destination(
            isTextEditorFocused: true,
            canPerformNative: false,
            canPerformEditorStore: true
        )

        // 期待値：EditorStoreへfallbackせず実行不可になる（Then）
        #expect(destination == .unavailable)
    }

    /// 論理名（日本語）: 非Focus時EditorStore routingテスト
    /// 概要: TextEditor外では従来どおりEditorStore履歴を使用します。
    @Test
    func testEditorStoreUndoIsUsedOutsideTextEditorFocus() {
        // コンディション：TextEditorがfocusされずEditorStoreにUndo履歴があるとき（Given）
        // 検証内容：送信先を解決したら（When）
        let destination = OpenGraphiteUndoCommandResolver.destination(
            isTextEditorFocused: false,
            canPerformNative: false,
            canPerformEditorStore: true
        )

        // 期待値：EditorStoreが選ばれる（Then）
        #expect(destination == .editorStore)
    }

    /// 論理名（日本語）: Model Undo draft同期テスト
    /// 概要: 入力debounce待ちでもmodel Undoのtextをdraftへ反映し、古い入力を未確定から除外します。
    @Test
    func testStoredUndoTextReplacesPendingDraft() {
        // コンディション：新しいdraftが未確定のまま以前の保存済みtextへUndoされたとき（Given）
        var state = CanvasStickyNoteTextSyncState(draftText: "保存済み")
        state.draftText = "保存前の入力"
        let didRegisterDraft = state.registerDraftChange()
        #expect(didRegisterDraft)

        // 検証内容：Undo後のmodel textを反映したら（When）
        #expect(state.shouldApplyStoredText("保存済み"))
        state.applyStoredText("保存済み")
        let shouldRestageModelText = state.registerDraftChange()
        let pendingText = state.takePendingText()

        // 期待値：draftはmodelへ戻り、再stage・再保存対象にならない（Then）
        #expect(state.draftText == "保存済み")
        #expect(!shouldRestageModelText)
        #expect(pendingText == nil)
    }

    /// 論理名（日本語）: 古いDebounce保存抑止テスト
    /// 概要: model同期後はcancel前にcaptureされたdraftを保存対象として取り出せないことを検証します。
    @Test
    func testStoredRedoTextInvalidatesCapturedDebounceDraft() {
        // コンディション：debounceが入力draftをcaptureした後にmodel Redoが別textを通知したとき（Given）
        var state = CanvasStickyNoteTextSyncState(draftText: "初期")
        state.draftText = "入力中"
        let didRegisterDraft = state.registerDraftChange()
        #expect(didRegisterDraft)

        // 検証内容：Redo textを反映して古いcaptureを確定しようとしたら（When）
        state.applyStoredText("確定済みRedo")
        let stalePendingText = state.takePendingText(expectedDraft: "入力中")

        // 期待値：古い入力は保存対象にならずRedo textがdraftに残る（Then）
        #expect(stalePendingText == nil)
        #expect(state.draftText == "確定済みRedo")
    }

    /// 論理名（日本語）: 入力Stage echo保持テスト
    /// 概要: キー入力をapp cacheへstageした同値model通知ではdebounce待ちを破棄しないことを検証します。
    @Test
    func testMatchingStagedTextKeepsPendingDraft() {
        // コンディション：ユーザー入力を未確定登録し、app cacheから同じtextが通知されたとき（Given）
        var state = CanvasStickyNoteTextSyncState(draftText: "初期")
        state.draftText = "入力中"
        let didRegisterDraft = state.registerDraftChange()

        // 検証内容：model textの反映要否とdebounce保存対象を確認したら（When）
        let shouldApplyStoredText = state.shouldApplyStoredText("入力中")
        let pendingText = state.takePendingText(expectedDraft: "入力中")

        // 期待値：同値model通知はdraftを上書きせず、入力が保存対象として残る（Then）
        #expect(didRegisterDraft)
        #expect(!shouldApplyStoredText)
        #expect(pendingText == "入力中")
    }
}
