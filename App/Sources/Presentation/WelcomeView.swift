import SwiftUI

/// 論理名（日本語）: Welcomeビュー
/// 概要: 起動直後に表示され、サンプルプロジェクトまたは任意の `.ogp` を開く導線を提供します。
struct WelcomeView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.secondary)

                Text("OpenGraphite")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))

                Text("HTMLをそのまま編集可能な正本として扱うデザインアプリ")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    store.openSampleProject()
                } label: {
                    Label("Open Sample Project", systemImage: "play.rectangle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    store.openProjectWithPanel()
                } label: {
                    Label("Open .ogp", systemImage: "folder")
                }
                .controlSize(.large)
            }
        }
        .padding(48)
    }
}
