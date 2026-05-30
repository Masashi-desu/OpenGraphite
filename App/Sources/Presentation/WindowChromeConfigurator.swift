import AppKit
import SwiftUI

/// 論理名（日本語）: ウィンドウクローム設定ビュー
/// 概要: SwiftUI のルートビューから `NSWindow` を取得し、タイトルバー一体型の編集画面に必要な外観を適用します。
struct WindowChromeConfigurator: NSViewRepresentable {
    /// 論理名（日本語）: NSView生成関数
    /// 処理概要: ウィンドウ接続時に設定処理を呼び出す透明な AppKit view を生成します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: ウィンドウ設定用の透明な `NSView`。
    func makeNSView(context: Context) -> WindowChromeConfigurationView {
        let view = WindowChromeConfigurationView()
        view.onWindowChange = configure(window:)
        return view
    }

    /// 論理名（日本語）: NSView更新関数
    /// 処理概要: SwiftUI 更新時に最新の `NSWindow` へタイトルバー設定を再適用します。
    ///
    /// - Parameters:
    ///   - nsView: 設定処理を保持する透明な `NSView`。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ nsView: WindowChromeConfigurationView, context: Context) {
        nsView.onWindowChange = configure(window:)
        configure(window: nsView.window)
    }

    /// 論理名（日本語）: ウィンドウ設定関数
    /// 処理概要: full size content と透明タイトルバーを有効化し、左カラムがタイトルバー領域まで伸びる外観へ整えます。
    ///
    /// - Parameter window: 設定対象の `NSWindow`。
    private func configure(window: NSWindow?) {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.toolbar?.showsBaselineSeparator = false
        window.isMovableByWindowBackground = true

        DispatchQueue.main.async {
            centerTrafficLightButtons(in: window)
        }
    }

    /// 論理名（日本語）: トラフィックライト中央揃え関数
    /// 処理概要: 透明タイトルバー内の標準ウィンドウボタンを上部ヘッダー高に対して中央へ寄せ、左余白も同じ基準へ揃えます。
    ///
    /// - Parameter window: 標準ウィンドウボタンを持つ対象ウィンドウ。
    private func centerTrafficLightButtons(in window: NSWindow) {
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let closeButton = window.standardWindowButton(.closeButton)
        let targetLeading = closeButton.map {
            ((EditorOverlayMetrics.topChromeHeight - $0.frame.width) / 2).rounded(.toNearestOrAwayFromZero)
        }
        let horizontalOffset = targetLeading.map { $0 - (closeButton?.frame.minX ?? $0) } ?? 0

        for buttonType in buttons {
            guard let button = window.standardWindowButton(buttonType),
                  let superview = button.superview
            else {
                continue
            }

            var frame = button.frame
            let headerHeight = EditorOverlayMetrics.topChromeHeight
            let centeredY: CGFloat

            if superview.isFlipped {
                centeredY = (headerHeight - frame.height) / 2
            } else {
                centeredY = superview.bounds.height - ((headerHeight + frame.height) / 2)
            }

            frame.origin.x += horizontalOffset
            frame.origin.y = centeredY.rounded(.toNearestOrAwayFromZero)
            button.setFrameOrigin(frame.origin)
        }
    }
}

/// 論理名（日本語）: ウィンドウクローム設定用AppKitビュー
/// 概要: `viewDidMoveToWindow` で所属ウィンドウを SwiftUI 側の設定処理へ渡します。
///
/// プロパティ:
/// - `onWindowChange`: 所属ウィンドウ変更時に呼ばれる設定コールバック。
final class WindowChromeConfigurationView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    /// 論理名（日本語）: ウィンドウ移動通知関数
    /// 処理概要: view がウィンドウへ接続されたタイミングで設定コールバックを実行します。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
