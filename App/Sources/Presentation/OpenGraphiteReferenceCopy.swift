import Foundation

/// 論理名（日本語）: OpenGraphite参照コピー補助
/// 概要: SwiftUI の copy command へ agent 向け参照 ID を文字列 item provider として渡します。
enum OpenGraphiteReferenceCopy {
    /// 論理名（日本語）: 参照ID item provider生成関数
    /// 処理概要: 空でない参照 ID を macOS pasteboard 向け item provider 配列へ変換します。
    ///
    /// - Parameter referenceID: コピーする agent 向け参照 ID。
    /// - Returns: 参照 ID を含む item provider。空の場合は空配列。
    static func itemProviders(for referenceID: String?) -> [NSItemProvider] {
        guard let referenceID = referenceID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !referenceID.isEmpty else {
            return []
        }

        return [NSItemProvider(object: referenceID as NSString)]
    }
}
