import AppKit
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: ウィンドウクローム設定関連のテストスイート
/// 概要: メインウィンドウのドラッグ範囲とタイトルバー一体表示に必要な設定を確認します。
@MainActor
@Suite("ウィンドウクローム設定関連のテストスイート")
struct WindowChromeConfiguratorTests {
    /// 論理名（日本語）: 背景ドラッグ無効化テスト
    /// 概要: ウィンドウ全体の背景ではなく専用ヘッダーだけがドラッグ対象になる前提を検証します。
    @Test("ウィンドウ背景ドラッグを無効化する")
    func testConfigureDisablesWindowBackgroundDrag() {
        // コンディション：背景ドラッグが有効なウィンドウを用意する
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isMovableByWindowBackground = true

        // 検証内容：OpenGraphite のウィンドウクローム設定を適用する
        WindowChromeConfigurator().configure(window: window)

        // 期待値：背景ドラッグは無効化され、full size content は維持される
        #expect(window.isMovableByWindowBackground == false)
        #expect(window.styleMask.contains(.fullSizeContentView))
    }

    /// 論理名（日本語）: ヘッダードラッグ領域設定テスト
    /// 概要: 上部クローム用の透明 view がウィンドウ移動対象として機能することを検証します。
    @Test("ヘッダードラッグ領域がウィンドウ移動を受け付ける")
    func testWindowHeaderDragViewAcceptsWindowMovement() {
        // コンディション：ヘッダー用の透明ドラッグ view を用意する
        let view = WindowHeaderDragView()

        // 検証内容：AppKit のウィンドウ移動関連フックを確認する
        let acceptsFirstMouse = view.acceptsFirstMouse(for: nil)

        // 期待値：ヘッダーはウィンドウ移動対象で、非アクティブ時の初回クリックも受け付ける
        #expect(view.mouseDownCanMoveWindow == true)
        #expect(acceptsFirstMouse == true)
    }
}
