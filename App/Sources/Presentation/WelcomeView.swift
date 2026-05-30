import AppKit
import SwiftUI

/// 論理名（日本語）: Welcomeビュー
/// 概要: 起動直後に表示され、サンプルプロジェクトまたは任意の `.ogp` を開く導線を提供します。
struct WelcomeView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                WelcomeAppIconView()

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

/// 論理名（日本語）: Welcomeアプリアイコンビュー
/// 概要: Welcome画面の上部にアプリバンドル内のOpenGraphiteアイコン画像を表示します。
private struct WelcomeAppIconView: View {
    private static let imageSize: CGFloat = 96

    var body: some View {
        Group {
            if let image = Self.openGraphiteImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.imageSize, height: Self.imageSize)
        .accessibilityLabel("OpenGraphite")
    }

    /// 処理概要: アプリバンドルにコピーされた `OpenGraphite.png` を読み込みます。
    private static var openGraphiteImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "OpenGraphite", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
