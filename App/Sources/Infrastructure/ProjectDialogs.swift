import AppKit
import UniformTypeIdentifiers

/// 論理名（日本語）: プロジェクトダイアログ
/// 概要: `.ogp` ファイルを選択する macOS 標準パネルを提供します。
///
/// 定義内容:
/// - `openProjectURL()`: ユーザーが選択した `.ogp` の URL を返します。
@MainActor
enum ProjectDialogs {
    /// 論理名（日本語）: プロジェクトURL選択関数
    /// 処理概要: `NSOpenPanel` を表示し、単一の `.ogp` ファイルを選択させます。
    ///
    /// - Returns: 選択された `.ogp` の URL。キャンセル時は `nil`。
    static func openProjectURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open OpenGraphite Project"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "ogp") ?? .json]

        return panel.runModal() == .OK ? panel.url : nil
    }
}
