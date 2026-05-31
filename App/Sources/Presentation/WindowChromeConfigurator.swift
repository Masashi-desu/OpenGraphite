import AppKit
import SwiftUI

/// 論理名（日本語）: ウィンドウクローム設定ビュー
/// 概要: SwiftUI のルートビューから `NSWindow` を取得し、タイトルバー一体型の編集画面に必要な外観とドラッグ範囲の前提を適用します。
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
        nsView.refreshConfiguration()
    }

    /// 論理名（日本語）: ウィンドウ設定関数
    /// 処理概要: full size content と透明タイトルバーを有効化し、移動操作は専用ヘッダー領域に限定します。
    ///
    /// - Parameter window: 設定対象の `NSWindow`。
    func configure(window: NSWindow?) {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.toolbar?.showsBaselineSeparator = false
        window.isMovableByWindowBackground = false

        window.contentView?.layoutSubtreeIfNeeded()
        centerTrafficLightButtons(in: window)
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

            superview.layoutSubtreeIfNeeded()

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

/// 論理名（日本語）: ウィンドウヘッダードラッグ領域
/// 概要: SwiftUI の上部クローム背景に差し込む透明な AppKit view として、ヘッダーだけをウィンドウ移動対象にします。
struct WindowHeaderDragRegion: NSViewRepresentable {
    /// 論理名（日本語）: ヘッダードラッグNSView生成関数
    /// 処理概要: マウス操作をウィンドウドラッグへ委譲する透明な `NSView` を生成します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: ウィンドウ移動用の透明な `NSView`。
    func makeNSView(context: Context) -> WindowHeaderDragView {
        WindowHeaderDragView()
    }

    /// 論理名（日本語）: ヘッダードラッグNSView更新関数
    /// 処理概要: 状態を持たないため、SwiftUI 更新時には追加処理を行いません。
    ///
    /// - Parameters:
    ///   - nsView: ウィンドウ移動用の透明な `NSView`。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ nsView: WindowHeaderDragView, context: Context) {}
}

/// 論理名（日本語）: ウィンドウヘッダードラッグビュー
/// 概要: 非アクティブウィンドウでも上部クロームからドラッグ移動を開始できる透明な `NSView` です。
final class WindowHeaderDragView: NSView {
    /// 論理名（日本語）: マウスダウン移動許可プロパティ
    /// 概要: AppKit にこの view 上のマウスダウンがウィンドウ移動対象であることを伝えます。
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    /// 論理名（日本語）: 初回クリック受理判定関数
    /// 処理概要: 背面にあるウィンドウでもクリック直後のドラッグ移動を開始できるようにします。
    ///
    /// - Parameter event: 初回クリックイベント。
    /// - Returns: 常に true を返し、非アクティブ時のクリックを受理します。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// 論理名（日本語）: マウスダウン処理関数
    /// 処理概要: ヘッダー上のマウスダウンを所属ウィンドウの標準ドラッグ処理へ委譲します。
    ///
    /// - Parameter event: ドラッグ開始元のマウスイベント。
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// 論理名（日本語）: ウィンドウクローム設定用AppKitビュー
/// 概要: `viewDidMoveToWindow` で所属ウィンドウを SwiftUI 側の設定処理へ渡します。
///
/// プロパティ:
/// - `onWindowChange`: 所属ウィンドウ変更時に呼ばれる設定コールバック。
final class WindowChromeConfigurationView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?
    private weak var observedWindow: NSWindow?
    private var notificationObservers: [NSObjectProtocol] = []
    private var isConfigurationScheduled = false

    /// 論理名（日本語）: ウィンドウ移動通知関数
    /// 処理概要: view がウィンドウへ接続されたタイミングで設定コールバックを実行します。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshConfiguration()
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: SwiftUI 側のレイアウト更新後にウィンドウボタン位置を再補正できるよう、設定処理を予約します。
    override func layout() {
        super.layout()
        scheduleConfiguration()
    }

    /// 論理名（日本語）: 解放処理関数
    /// 処理概要: ウィンドウ通知の監視を解除し、AppKit 通知センターに observer を残さないようにします。
    deinit {
        removeWindowObservers()
    }

    /// 論理名（日本語）: 設定再読み込み関数
    /// 処理概要: 所属ウィンドウの監視を張り直し、次の run loop でクローム設定を適用します。
    func refreshConfiguration() {
        installWindowObservers(for: window)
        scheduleConfiguration()
    }

    /// 論理名（日本語）: ウィンドウ通知監視設定関数
    /// 処理概要: 初期表示後のリサイズ、画面移動、キー化に合わせてクローム設定を再適用する通知監視を設定します。
    ///
    /// - Parameter newWindow: 監視対象の `NSWindow`。
    private func installWindowObservers(for newWindow: NSWindow?) {
        guard observedWindow !== newWindow else { return }

        removeWindowObservers()
        observedWindow = newWindow

        guard let newWindow else { return }

        let notifications: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didChangeScreenNotification,
            NSWindow.didChangeBackingPropertiesNotification,
            NSWindow.didBecomeKeyNotification
        ]

        notificationObservers = notifications.map { notificationName in
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: newWindow,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleConfiguration()
            }
        }
    }

    /// 論理名（日本語）: ウィンドウ通知監視解除関数
    /// 処理概要: 現在登録済みのウィンドウ通知 observer をすべて解除します。
    private func removeWindowObservers() {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers = []
    }

    /// 論理名（日本語）: 設定予約関数
    /// 処理概要: AppKit と SwiftUI のレイアウト完了後に一度だけクローム設定を適用するよう予約します。
    private func scheduleConfiguration() {
        guard window != nil, !isConfigurationScheduled else { return }

        isConfigurationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.isConfigurationScheduled = false
            self.onWindowChange?(self.window)
        }
    }
}
