import AppKit
import SwiftUI

/// 論理名（日本語）: Editor取り消し方向
/// 概要: 取り消しとやり直しのどちらを実行するかを表します。
///
/// 定義内容:
/// - `undo`: 直前の操作を取り消します。
/// - `redo`: 取り消した操作をやり直します。
enum OpenGraphiteUndoCommandDirection {
    case undo
    case redo
}

/// 論理名（日本語）: Editor取り消しコマンド送信先
/// 概要: focus中テキストのnative履歴、EditorStore履歴、実行不可のいずれへコマンドを送るかを表します。
///
/// 定義内容:
/// - `nativeTextEditor`: AppKit TextEditor の UndoManagerへ送ります。
/// - `editorStore`: HTMLまたはCanvas注釈のEditorStore履歴へ送ります。
/// - `unavailable`: 現在のfocus範囲では実行できません。
enum OpenGraphiteUndoCommandDestination: Equatable {
    case nativeTextEditor
    case editorStore
    case unavailable
}

/// 論理名（日本語）: Editor取り消し送信先解決器
/// 概要: focus中のTextEditorを独立したUndo範囲として優先し、未確定入力からEditorStore履歴へ誤ってfallbackしないようにします。
enum OpenGraphiteUndoCommandResolver {
    /// 論理名（日本語）: 取り消し送信先解決関数
    /// 処理概要: TextEditorがfocus中ならnative履歴だけを候補とし、それ以外ではEditorStore履歴を候補にします。
    ///
    /// - Parameters:
    ///   - isTextEditorFocused: Canvas付箋TextEditorがfocus中か。
    ///   - canPerformNative: focus中TextEditorのUndoManagerが指定操作を実行できるか。
    ///   - canPerformEditorStore: EditorStore履歴が指定操作を実行できるか。
    /// - Returns: コマンドを送る対象。focus中native履歴が空でもEditorStoreへはfallbackしません。
    static func destination(
        isTextEditorFocused: Bool,
        canPerformNative: Bool,
        canPerformEditorStore: Bool
    ) -> OpenGraphiteUndoCommandDestination {
        if isTextEditorFocused {
            return canPerformNative ? .nativeTextEditor : .unavailable
        }
        return canPerformEditorStore ? .editorStore : .unavailable
    }
}

/// 論理名（日本語）: Canvas付箋TextEditor focus値キー
/// 概要: focus中の付箋TextEditorがnative Undo範囲であることをScene Commandsへ伝えます。
private struct CanvasStickyNoteTextEditorFocusedKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    /// 論理名（日本語）: Canvas付箋TextEditor focus値
    /// 概要: Canvas付箋のTextEditorがfocus中の場合に`true`を公開します。
    var isCanvasStickyNoteTextEditorFocused: Bool? {
        get { self[CanvasStickyNoteTextEditorFocusedKey.self] }
        set { self[CanvasStickyNoteTextEditorFocusedKey.self] = newValue }
    }
}

/// 論理名（日本語）: Native TextEditor取り消し送信器
/// 概要: key windowのfirst responderがNSTextViewである場合に限り、そのUndoManagerへ取り消しまたはやり直しを送ります。
private enum OpenGraphiteNativeTextUndoDispatcher {
    /// 論理名（日本語）: Native操作可否判定関数
    /// 処理概要: focus中NSTextViewのUndoManagerが指定方向を実行できるかを返します。
    ///
    /// - Parameter direction: 判定する取り消し方向。
    /// - Returns: native UndoManagerが操作可能なら`true`。
    static func canPerform(_ direction: OpenGraphiteUndoCommandDirection) -> Bool {
        guard let undoManager = focusedTextViewUndoManager else { return false }
        switch direction {
        case .undo:
            return undoManager.canUndo
        case .redo:
            return undoManager.canRedo
        }
    }

    /// 論理名（日本語）: Native操作実行関数
    /// 処理概要: focus中NSTextViewのUndoManagerへ指定方向の操作を送り、別のresponderやEditorStoreへは送信しません。
    ///
    /// - Parameter direction: 実行する取り消し方向。
    static func perform(_ direction: OpenGraphiteUndoCommandDirection) {
        guard let undoManager = focusedTextViewUndoManager else { return }
        switch direction {
        case .undo where undoManager.canUndo:
            undoManager.undo()
        case .redo where undoManager.canRedo:
            undoManager.redo()
        default:
            break
        }
    }

    /// 論理名（日本語）: Focus中TextView UndoManager
    /// 概要: key windowのfirst responderがNSTextViewの場合だけUndoManagerを返します。
    private static var focusedTextViewUndoManager: UndoManager? {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return nil }
        return textView.undoManager
    }
}

/// 論理名（日本語）: OpenGraphite取り消しコマンド
/// 概要: focus中TextEditorのnative履歴とEditorStore履歴を排他的にルーティングします。
private struct OpenGraphiteUndoRedoCommands: Commands {
    @ObservedObject var store: EditorStore
    @FocusedValue(\.isCanvasStickyNoteTextEditorFocused) private var isTextEditorFocused

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("取り消す") {
                perform(.undo)
            }
            .keyboardShortcut("z", modifiers: [.command])
            .disabled(isCommandDisabled(for: .undo))

            Button("やり直す") {
                perform(.redo)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(isCommandDisabled(for: .redo))
        }
    }

    /// 論理名（日本語）: 取り消しコマンド無効判定関数
    /// 処理概要: TextEditor focus中はnative履歴の通知更新前でもshortcutを受け止め、EditorStoreへの誤fallbackを防ぎます。
    ///
    /// - Parameter direction: 判定する取り消し方向。
    /// - Returns: TextEditor外かつEditorStore履歴も実行不能な場合は`true`。
    private func isCommandDisabled(for direction: OpenGraphiteUndoCommandDirection) -> Bool {
        if isTextEditorFocused == true {
            return false
        }
        return destination(for: direction) == .unavailable
    }

    /// 論理名（日本語）: 取り消し送信先取得関数
    /// 処理概要: 現在のfocusと各履歴の操作可否から、指定方向の送信先を決定します。
    ///
    /// - Parameter direction: 解決する取り消し方向。
    /// - Returns: native TextEditor、EditorStore、実行不可のいずれか。
    private func destination(
        for direction: OpenGraphiteUndoCommandDirection
    ) -> OpenGraphiteUndoCommandDestination {
        let canPerformEditorStore: Bool
        switch direction {
        case .undo:
            canPerformEditorStore = store.canUndo
        case .redo:
            canPerformEditorStore = store.canRedo
        }
        return OpenGraphiteUndoCommandResolver.destination(
            isTextEditorFocused: isTextEditorFocused == true,
            canPerformNative: OpenGraphiteNativeTextUndoDispatcher.canPerform(direction),
            canPerformEditorStore: canPerformEditorStore
        )
    }

    /// 論理名（日本語）: 取り消し実行関数
    /// 処理概要: 実行時点の送信先を再解決し、native履歴またはEditorStore履歴の片方だけを操作します。
    ///
    /// - Parameter direction: 実行する取り消し方向。
    private func perform(_ direction: OpenGraphiteUndoCommandDirection) {
        switch destination(for: direction) {
        case .nativeTextEditor:
            OpenGraphiteNativeTextUndoDispatcher.perform(direction)
        case .editorStore:
            switch direction {
            case .undo:
                store.undoDocumentChange()
            case .redo:
                store.redoDocumentChange()
            }
        case .unavailable:
            break
        }
    }
}

/// 論理名（日本語）: OpenGraphiteウィンドウメトリクス
/// 概要: メインウィンドウの最小サイズをまとめ、Figma 程度の小型表示までリサイズできるようにします。
///
/// 定義内容:
/// - `minimumWidth`: メインウィンドウの最小幅。
/// - `minimumHeight`: メインウィンドウの最小高さ。
private enum OpenGraphiteWindowMetrics {
    static let minimumWidth: CGFloat = 960
    static let minimumHeight: CGFloat = 640
}

/// 論理名（日本語）: OpenGraphiteアプリケーション
/// 概要: SwiftUI のアプリエントリーポイントとして共有 EditorStore、メインウィンドウ、メニューコマンドを構成します。
@main
struct OpenGraphiteApp: App {
    @StateObject private var store = EditorStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .background(WindowChromeConfigurator())
                .frame(
                    minWidth: OpenGraphiteWindowMetrics.minimumWidth,
                    minHeight: OpenGraphiteWindowMetrics.minimumHeight
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(UnifiedWindowToolbarStyle(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project...") {
                    store.createProjectWithPanel()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Divider()

                Button("Open Project...") {
                    store.openProjectWithPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open Sample Project") {
                    store.openSampleProject()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {}

            OpenGraphiteUndoRedoCommands(store: store)
        }
    }
}
