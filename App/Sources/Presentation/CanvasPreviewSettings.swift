import SwiftUI

/// 論理名（日本語）: キャンバス表示設定
/// 概要: Settings とキャンバス表示が共有する UserDefaults キーと既定値を定義します。
enum CanvasDisplayPreferences {
    static let showsRulersKey = "canvas.display.showsRulers"
    static let showsGuidesKey = "canvas.display.showsGuides"
    static let showsGridKey = "canvas.display.showsGrid"

    static let showsRulersByDefault = true
    static let showsGuidesByDefault = true
    static let showsGridByDefault = false
}

/// 論理名（日本語）: キャンバス設定ビュー
/// 概要: ルーラー、ガイド、グリッドの表示可否を切り替える macOS Settings 画面です。
struct CanvasSettingsView: View {
    @AppStorage(CanvasDisplayPreferences.showsRulersKey)
    private var showsRulers = CanvasDisplayPreferences.showsRulersByDefault
    @AppStorage(CanvasDisplayPreferences.showsGuidesKey)
    private var showsGuides = CanvasDisplayPreferences.showsGuidesByDefault
    @AppStorage(CanvasDisplayPreferences.showsGridKey)
    private var showsGrid = CanvasDisplayPreferences.showsGridByDefault

    var body: some View {
        Form {
            Section("キャンバス") {
                Toggle("ルーラーを表示", isOn: $showsRulers)
                Toggle("ガイドを表示", isOn: $showsGuides)
                Toggle("グリッドを表示", isOn: $showsGrid)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 220)
    }
}
