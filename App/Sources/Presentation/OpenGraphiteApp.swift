import SwiftUI

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

            CommandGroup(replacing: .undoRedo) {
                Button("取り消す") {
                    store.undoDocumentChange()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!store.canUndo)

                Button("やり直す") {
                    store.redoDocumentChange()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.canRedo)
            }
        }
    }
}
