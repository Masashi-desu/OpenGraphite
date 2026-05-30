import SwiftUI

/// 論理名（日本語）: エディターオーバーレイメトリクス
/// 概要: 全面 Canvas に重ねる左右カラムの幅とタイトルバー余白をまとめます。
///
/// 定義内容:
/// - `sidebarWidth`: 左カラムの固定幅。
/// - `inspectorWidth`: 右カラムの固定幅。
/// - `topChromeHeight`: Pencil 風の一段ヘッダー高さ。
/// - `chromeControlInset`: 上部ヘッダー内ボタンの水平余白。
/// - `columnTopGap`: 上部ヘッダーとカラム先頭要素の間隔。
/// - `titlebarInset`: カラム内コンテンツが上部ヘッダーと重ならず、詰まりすぎないようにする上余白。
/// - `collapsedLeadingChromeWidth`: 左カラム非表示時に traffic light と左ボタン用に残す幅。
/// - `collapsedTrailingChromeWidth`: 右カラム非表示時に右ボタン用に残す幅。
/// - `trafficLightReservedWidth`: macOS の traffic light と重ならないための左側予約幅。
enum EditorOverlayMetrics {
    static let sidebarWidth: CGFloat = 296
    static let inspectorWidth: CGFloat = 320
    static let topChromeHeight: CGFloat = 50
    static let chromeControlInset: CGFloat = 11
    static let columnTopGap: CGFloat = 10
    static let titlebarInset: CGFloat = topChromeHeight + columnTopGap
    static let collapsedLeadingChromeWidth: CGFloat = 148
    static let collapsedTrailingChromeWidth: CGFloat = 56
    static let trafficLightReservedWidth: CGFloat = 104
}
