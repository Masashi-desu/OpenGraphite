import SwiftUI

/// 論理名（日本語）: ルートビュー
/// 概要: プロジェクト未読込時は Welcome、読込後は EditorShell を表示し、エラー alert を管理します。
struct RootView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        Group {
            if store.loadedProject == nil {
                WelcomeView()
            } else {
                EditorShellView()
            }
        }
        .alert(
            "OpenGraphite",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
