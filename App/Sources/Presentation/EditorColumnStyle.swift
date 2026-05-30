import SwiftUI

/// 論理名（日本語）: エディターカラムスタイル
/// 概要: 全面 Canvas に重ねる左右カラムで共有する余白、角丸、色調をまとめます。
///
/// 定義内容:
/// - `outerPadding`: カラム内コンテンツの左右余白。
/// - `rowRadius`: 行や小型コントロールの角丸。
/// - `panelRadius`: Inspector セクションなど大きめの面の角丸。
/// - `separatorColor`: カラム内の細い区切り線色。
/// - `rowFill`: 通常パネルや入力欄の背景色。
/// - `selectedRowFill`: 選択行の背景色。
enum EditorColumnStyle {
    static let outerPadding: CGFloat = 10
    static let rowRadius: CGFloat = 7
    static let panelRadius: CGFloat = 8
    static let separatorColor = Color.primary.opacity(0.08)
    static let rowFill = Color.primary.opacity(0.055)
    static let elevatedRowFill = Color.primary.opacity(0.075)
    static let selectedRowFill = Color.primary.opacity(0.10)
    static let accentFill = Color.accentColor.opacity(0.18)
}

/// 論理名（日本語）: エディターカラム背景ビュー
/// 概要: Sidebar と Inspector が Canvas に重なるための共通マテリアル背景です。
struct EditorColumnBackground: View {
    var body: some View {
        Rectangle()
            .fill(.bar)
            .overlay(Color.primary.opacity(0.015))
    }
}
