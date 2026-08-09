import AppKit
import SwiftUI
import WebKit

/// 論理名（日本語）: Webスクロール方向
/// 概要: WKWebView 内外のスクロールルーティングで利用する主要なスクロール方向を表します。
///
/// 定義内容:
/// - `up`: 上方向。
/// - `down`: 下方向。
/// - `left`: 左方向。
/// - `right`: 右方向。
enum WebScrollDirection {
    case up
    case down
    case left
    case right
}

/// 論理名（日本語）: Webスクロール状態
/// 概要: ポインタ直下の DOM が各方向へスクロール可能かを Swift 側へ渡す状態モデルです。
///
/// プロパティ:
/// - `isInside`: ポインタが WebView 内にあるか。
/// - `canScrollUp`: DOM が上方向へスクロールできるか。
/// - `canScrollDown`: DOM が下方向へスクロールできるか。
/// - `canScrollLeft`: DOM が左方向へスクロールできるか。
/// - `canScrollRight`: DOM が右方向へスクロールできるか。
/// - `canScrollElementUp`: document root 以外の DOM が上方向へスクロールできるか。
/// - `canScrollElementDown`: document root 以外の DOM が下方向へスクロールできるか。
/// - `canScrollElementLeft`: document root 以外の DOM が左方向へスクロールできるか。
/// - `canScrollElementRight`: document root 以外の DOM が右方向へスクロールできるか。
struct WebScrollState: Equatable {
    var isInside: Bool
    var canScrollUp: Bool
    var canScrollDown: Bool
    var canScrollLeft: Bool
    var canScrollRight: Bool
    var canScrollElementUp: Bool
    var canScrollElementDown: Bool
    var canScrollElementLeft: Bool
    var canScrollElementRight: Bool

    static let outside = WebScrollState(
        isInside: false,
        canScrollUp: false,
        canScrollDown: false,
        canScrollLeft: false,
        canScrollRight: false
    )

    /// 論理名（日本語）: Webスクロール状態初期化関数
    /// 処理概要: WebView 内外と四方向のスクロール可否を明示値から構成します。
    ///
    /// - Parameters:
    ///   - isInside: ポインタが WebView 内にあるか。
    ///   - canScrollUp: 上方向へスクロールできるか。
    ///   - canScrollDown: 下方向へスクロールできるか。
    ///   - canScrollLeft: 左方向へスクロールできるか。
    ///   - canScrollRight: 右方向へスクロールできるか。
    ///   - canScrollElementUp: document root 以外の DOM が上方向へスクロールできるか。
    ///   - canScrollElementDown: document root 以外の DOM が下方向へスクロールできるか。
    ///   - canScrollElementLeft: document root 以外の DOM が左方向へスクロールできるか。
    ///   - canScrollElementRight: document root 以外の DOM が右方向へスクロールできるか。
    init(
        isInside: Bool,
        canScrollUp: Bool,
        canScrollDown: Bool,
        canScrollLeft: Bool,
        canScrollRight: Bool,
        canScrollElementUp: Bool = false,
        canScrollElementDown: Bool = false,
        canScrollElementLeft: Bool = false,
        canScrollElementRight: Bool = false
    ) {
        self.isInside = isInside
        self.canScrollUp = canScrollUp
        self.canScrollDown = canScrollDown
        self.canScrollLeft = canScrollLeft
        self.canScrollRight = canScrollRight
        self.canScrollElementUp = canScrollElementUp
        self.canScrollElementDown = canScrollElementDown
        self.canScrollElementLeft = canScrollElementLeft
        self.canScrollElementRight = canScrollElementRight
    }

    /// 論理名（日本語）: payload初期化関数
    /// 処理概要: JavaScript から届く辞書 payload を Web スクロール状態へ変換します。
    ///
    /// - Parameter payload: `inside`、全体スクロール可否、要素スクロール可否を持つ辞書。
    init(payload: [String: Any]) {
        self.init(
            isInside: payload["inside"] as? Bool ?? false,
            canScrollUp: payload["up"] as? Bool ?? false,
            canScrollDown: payload["down"] as? Bool ?? false,
            canScrollLeft: payload["left"] as? Bool ?? false,
            canScrollRight: payload["right"] as? Bool ?? false,
            canScrollElementUp: payload["elementUp"] as? Bool ?? false,
            canScrollElementDown: payload["elementDown"] as? Bool ?? false,
            canScrollElementLeft: payload["elementLeft"] as? Bool ?? false,
            canScrollElementRight: payload["elementRight"] as? Bool ?? false
        )
    }

    /// 論理名（日本語）: 方向別スクロール可否判定関数
    /// 処理概要: 指定方向に対する DOM のスクロール可否を返します。
    ///
    /// - Parameter direction: 判定するスクロール方向。
    /// - Returns: 指定方向へスクロールできる場合は `true`。
    func canScroll(_ direction: WebScrollDirection) -> Bool {
        switch direction {
        case .up:
            canScrollUp
        case .down:
            canScrollDown
        case .left:
            canScrollLeft
        case .right:
            canScrollRight
        }
    }

    /// 論理名（日本語）: 要素方向別スクロール可否判定関数
    /// 処理概要: document root 以外の DOM が指定方向へスクロールできるかを返します。
    ///
    /// - Parameter direction: 判定するスクロール方向。
    /// - Returns: 明示的な overflow scroll 要素が指定方向へスクロールできる場合は `true`。
    func canScrollElement(_ direction: WebScrollDirection) -> Bool {
        switch direction {
        case .up:
            canScrollElementUp
        case .down:
            canScrollElementDown
        case .left:
            canScrollElementLeft
        case .right:
            canScrollElementRight
        }
    }

    var canScrollAnyDirection: Bool {
        canScrollUp || canScrollDown || canScrollLeft || canScrollRight
    }

    var canScrollAnyElementDirection: Bool {
        canScrollElementUp || canScrollElementDown || canScrollElementLeft || canScrollElementRight
    }
}

/// 論理名（日本語）: Webスクロール状態レジストリ
/// 概要: 複数の WKWebView ごとに JavaScript 由来のスクロール状態を保持します。
///
/// メソッド:
/// - `update(_:for:)`: WebView の状態を更新します。
/// - `state(for:)`: WebView の最新状態を取得します。
/// - `remove(for:)`: WebView 破棄時に状態を削除します。
final class WebScrollStateRegistry {
    static let shared = WebScrollStateRegistry()

    private var states: [ObjectIdentifier: WebScrollState] = [:]

    private init() {}

    /// 論理名（日本語）: Webスクロール状態更新関数
    /// 処理概要: 指定された WKWebView に対応するスクロール状態を保存します。
    ///
    /// - Parameters:
    ///   - state: 保存するスクロール状態。
    ///   - webView: 状態の対象となる WebView。
    func update(_ state: WebScrollState, for webView: WKWebView) {
        states[ObjectIdentifier(webView)] = state
    }

    /// 論理名（日本語）: Webスクロール状態取得関数
    /// 処理概要: 指定された WKWebView の最新スクロール状態を返します。
    ///
    /// - Parameter webView: 状態を取得する WebView。
    /// - Returns: 保存済み状態。未登録の場合は `nil`。
    func state(for webView: WKWebView) -> WebScrollState? {
        states[ObjectIdentifier(webView)]
    }

    /// 論理名（日本語）: Webスクロール状態削除関数
    /// 処理概要: WebView 破棄時にレジストリから状態を削除します。
    ///
    /// - Parameter webView: 削除対象の WebView。
    func remove(for webView: WKWebView) {
        states.removeValue(forKey: ObjectIdentifier(webView))
    }
}

/// 論理名（日本語）: Webキャンバス編集オーバーレイ
/// 概要: WebView 上に重ねて表示するフレーム配置 preview の描画情報です。
///
/// プロパティ:
/// - `rect`: WebView client 座標上の矩形。
/// - `label`: 矩形左上に表示する補助ラベル。
/// - `style`: preview の描画種別。
private struct WebCanvasEditingOverlay {
    enum Style {
        case placementPreview
    }

    var rect: CGRect
    var label: String
    var style: Style
}

/// 論理名（日本語）: Webキャンバス編集オーバーレイView
/// 概要: DOM pointer event が届かない frame 配置操作でも実態が見えるよう、WKWebView の最前面で編集用矩形を描画します。
private final class WebCanvasEditingOverlayView: NSView {
    var overlays: [WebCanvasEditingOverlay] = [] {
        didSet {
            isHidden = overlays.isEmpty
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    /// 論理名（日本語）: ヒットテスト無効化関数
    /// 処理概要: 編集オーバーレイが WebView の pointer / mouse event を奪わないようにします。
    ///
    /// - Parameter point: hit test 対象座標。
    /// - Returns: 常に `nil`。
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// 論理名（日本語）: オーバーレイ描画関数
    /// 処理概要: frame 配置 preview の矩形、塗り、補助ラベルを描画します。
    ///
    /// - Parameter dirtyRect: 再描画対象矩形。
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for overlay in overlays where overlay.rect.width > 0 && overlay.rect.height > 0 {
            draw(overlay)
        }
    }

    /// 論理名（日本語）: 単一オーバーレイ描画関数
    /// 処理概要: 指定された overlay の矩形とラベルを現在の graphics context へ描画します。
    ///
    /// - Parameter overlay: 描画する overlay。
    private func draw(_ overlay: WebCanvasEditingOverlay) {
        let rect = overlay.rect.integral.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(rect: rect)
        path.lineJoinStyle = .round

        switch overlay.style {
        case .placementPreview:
            NSColor.systemBlue.withAlphaComponent(0.16).setFill()
            path.fill()
            NSColor.systemBlue.withAlphaComponent(0.95).setStroke()
            path.lineWidth = 2
        }
        path.stroke()

        drawLabel(overlay.label, near: rect)
    }

    /// 論理名（日本語）: オーバーレイラベル描画関数
    /// 処理概要: 矩形の上端または内側に、サイズや ID を示す短いラベルを描画します。
    ///
    /// - Parameters:
    ///   - label: 表示するテキスト。
    ///   - rect: ラベルの基準となる overlay 矩形。
    private func drawLabel(_ label: String, near rect: CGRect) {
        guard !label.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: label, attributes: attributes)
        let textSize = attributed.size()
        let labelPadding = CGSize(width: 12, height: 5)
        let labelSize = CGSize(
            width: min(max(textSize.width + labelPadding.width, 36), max(bounds.width - 8, 36)),
            height: textSize.height + labelPadding.height
        )
        let labelOriginY = rect.minY >= labelSize.height + 4
            ? rect.minY - labelSize.height - 2
            : rect.minY + 3
        let labelOriginX = min(max(rect.minX, 4), max(bounds.width - labelSize.width - 4, 4))
        let labelRect = CGRect(origin: CGPoint(x: labelOriginX, y: labelOriginY), size: labelSize)
        let backgroundPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor.systemBlue.setFill()
        backgroundPath.fill()

        attributed.draw(
            in: CGRect(
                x: labelRect.minX + 6,
                y: labelRect.minY + 2,
                width: labelRect.width - 12,
                height: labelRect.height - 4
            )
        )
    }
}

/// 論理名（日本語）: OpenGraphiteコマンド対応WebView
/// 概要: `⌘C` と responder chain の `copy:` を OpenGraphite の選択ノードコピーへ接続する WKWebView です。
///
/// プロパティ:
/// - `copyCommandHandler`: OpenGraphite 専用コピーを実行し、処理できた場合に `true` を返す handler。
/// - `isDocumentScrollingSuppressed`: focus切り抜き中にroot文書のscroll chromeとelasticityを無効化するか。
private final class OpenGraphiteCommandWebView: WKWebView {
    var copyCommandHandler: (() -> Bool)?
    var activeToolRawValue = CanvasTool.select.rawValue
    private var isDocumentScrollingSuppressed = false
    private let editingOverlayView = WebCanvasEditingOverlayView()
    private let framePlacementPreviewDragThreshold: CGFloat = 3
    private var framePlacementPreviewStartPoint: CGPoint?
    private var framePlacementPreviewDidBegin = false
    private var framePlacementPreviewOverlay: WebCanvasEditingOverlay?

    /// 論理名（日本語）: WebView不透明判定
    /// 概要: WebKit の未描画期間に親キャンバス背景を透過表示するため、常に非不透明 view として扱います。
    override var isOpaque: Bool {
        false
    }

    /// 論理名（日本語）: レイアウト更新関数
    /// 処理概要: WebKit が内部 scroll view を再構成した場合でも、読み込み中背景の透明化を維持します。
    override func layout() {
        super.layout()
        applyTransparentPreviewBackground()
        applyDocumentScrollPresentation(in: self)
        layoutEditingOverlay()
    }

    /// 論理名（日本語）: ウィンドウ所属更新関数
    /// 処理概要: WebView が window 階層へ入ったタイミングで、読み込み前の背景を親キャンバスへ透過させます。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTransparentPreviewBackground()
        applyDocumentScrollPresentation(in: self)
    }

    /// 論理名（日本語）: キー相当処理関数
    /// 処理概要: `⌘C` を OpenGraphite 専用コピーへ流し、対象がない場合は標準 WebView 処理へ戻します。
    ///
    /// - Parameter event: 入力イベント。
    /// - Returns: OpenGraphite 側または WebView 側で処理できた場合は `true`。
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isCopyKeyEquivalent(event), copyCommandHandler?() == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// 論理名（日本語）: コピーアクション関数
    /// 処理概要: メニューなどから届く `copy:` action を OpenGraphite 専用コピーへ流します。
    ///
    /// - Parameter sender: action 送信元。
    @objc func copy(_ sender: Any?) {
        _ = copyCommandHandler?()
    }

    /// 論理名（日本語）: マウスダウン処理関数
    /// 処理概要: WebKit の DOM pointer event が届かない場合に備え、フレーム配置用の native 入力も bridge へ転送します。
    ///
    /// - Parameter event: AppKit から届いたマウスダウンイベント。
    override func mouseDown(with event: NSEvent) {
        beginNativeFramePlacementTrackingIfNeeded(event)
        forwardFramePlacementMouseEvent("down", event: event)
        super.mouseDown(with: event)
    }

    /// 論理名（日本語）: マウスドラッグ処理関数
    /// 処理概要: native drag 座標を WebView viewport 座標へ変換し、フレーム配置プレビュー更新へ渡します。
    ///
    /// - Parameter event: AppKit から届いたドラッグイベント。
    override func mouseDragged(with event: NSEvent) {
        updateNativeFramePlacementPreviewIfNeeded(event)
        forwardFramePlacementMouseEvent("move", event: event)
        super.mouseDragged(with: event)
    }

    /// 論理名（日本語）: マウスアップ処理関数
    /// 処理概要: native release 座標を WebView bridge へ渡し、フレーム配置を確定します。
    ///
    /// - Parameter event: AppKit から届いたマウスアップイベント。
    override func mouseUp(with event: NSEvent) {
        forwardFramePlacementMouseEvent("up", event: event)
        endNativeFramePlacementPreview()
        super.mouseUp(with: event)
    }

    /// 論理名（日本語）: アクティブツール反映関数
    /// 処理概要: SwiftUI 側の canvas tool を native overlay の制御にも反映します。
    ///
    /// - Parameter rawValue: `CanvasTool` の raw value。
    func setActiveToolRawValue(_ rawValue: String) {
        activeToolRawValue = rawValue
        if rawValue != CanvasTool.frame.rawValue {
            endNativeFramePlacementPreview()
        }
    }

    /// 論理名（日本語）: 編集オーバーレイ全消去関数
    /// 処理概要: navigation や document replacement の境界で AppKit 側の編集表示をリセットします。
    func clearEditingOverlays() {
        framePlacementPreviewStartPoint = nil
        framePlacementPreviewDidBegin = false
        framePlacementPreviewOverlay = nil
        refreshEditingOverlays()
    }

    /// 論理名（日本語）: プレビュー背景透明化関数
    /// 処理概要: WKWebView と WebKit 内部の scroll / clip view 背景を透明にし、navigation 中の白背景露出を防ぎます。
    func applyTransparentPreviewBackground() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        underPageBackgroundColor = .clear
        makeScrollContainersTransparent(in: self)
    }

    /// 論理名（日本語）: Root文書スクロール抑止設定関数
    /// 処理概要: focus切り抜きではWKWebViewのroot scroll indicatorとelasticityを無効化し、通常pageでは標準状態へ戻します。
    ///
    /// - Parameter isSuppressed: root文書scrollを参照表示へ露出させない場合は`true`。
    func setDocumentScrollingSuppressed(_ isSuppressed: Bool) {
        isDocumentScrollingSuppressed = isSuppressed
        applyDocumentScrollPresentation(in: self)
    }

    /// 論理名（日本語）: プレビュー内容非表示関数
    /// 処理概要: provisional document のDOM準備前にWebKit contentを親キャンバスへ透過させます。
    func hidePreviewContentUntilStyled() {
        alphaValue = 0
    }

    /// 論理名（日本語）: プレビュー内容表示関数
    /// 処理概要: 標準HTML文書のDOM準備後に、利用するstylesheetを問わずcontentを表示します。
    func revealStyledPreviewContent() {
        alphaValue = 1
    }

    /// 論理名（日本語）: スクロールコンテナ透明化関数
    /// 処理概要: macOS 版 WKWebView の非公開 view 階層を型だけでたどり、公開 AppKit API で背景描画を無効化します。
    ///
    /// - Parameter root: 透明化対象の探索を開始する view。
    private func makeScrollContainersTransparent(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
        }

        if let clipView = root as? NSClipView {
            clipView.drawsBackground = false
            clipView.backgroundColor = .clear
        }

        root.subviews.forEach { subview in
            makeScrollContainersTransparent(in: subview)
        }
    }

    /// 論理名（日本語）: Root文書スクロール表示適用関数
    /// 処理概要: WebKit内部scroll viewへfocus表示用のindicatorとelasticity設定を再帰適用します。
    ///
    /// - Parameter root: scroll view探索を開始するview。
    private func applyDocumentScrollPresentation(in root: NSView) {
        if let scrollView = root as? NSScrollView {
            scrollView.hasHorizontalScroller = !isDocumentScrollingSuppressed
            scrollView.hasVerticalScroller = !isDocumentScrollingSuppressed
            scrollView.autohidesScrollers = !isDocumentScrollingSuppressed
            scrollView.horizontalScrollElasticity = isDocumentScrollingSuppressed ? .none : .automatic
            scrollView.verticalScrollElasticity = isDocumentScrollingSuppressed ? .none : .automatic
        }

        root.subviews.forEach { subview in
            applyDocumentScrollPresentation(in: subview)
        }
    }

    /// 論理名（日本語）: 編集オーバーレイ配置関数
    /// 処理概要: WebView の bounds に合わせて overlay view を最前面へ配置します。
    private func layoutEditingOverlay() {
        ensureEditingOverlayView()
        if editingOverlayView.superview === self {
            editingOverlayView.frame = bounds
        } else {
            editingOverlayView.frame = frame
        }
    }

    /// 論理名（日本語）: 編集オーバーレイView確保関数
    /// 処理概要: WebKit 内部 view に隠れないよう、可能なら WebView の親 view 上で前面 sibling として追加します。
    private func ensureEditingOverlayView() {
        let targetSuperview = superview ?? self
        if editingOverlayView.superview !== targetSuperview {
            editingOverlayView.removeFromSuperview()
            editingOverlayView.autoresizingMask = []
            editingOverlayView.isHidden = true
            if targetSuperview === self {
                addSubview(editingOverlayView, positioned: .above, relativeTo: nil)
            } else if let superview {
                superview.addSubview(editingOverlayView, positioned: .above, relativeTo: self)
            }
        }
    }

    /// 論理名（日本語）: 編集オーバーレイ更新関数
    /// 処理概要: native fallback が必要な frame 配置 preview overlay を描画 view へ反映します。
    private func refreshEditingOverlays() {
        ensureEditingOverlayView()
        layoutEditingOverlay()
        editingOverlayView.overlays = [framePlacementPreviewOverlay].compactMap { $0 }
    }

    /// 論理名（日本語）: フレーム配置preview追跡開始関数
    /// 処理概要: frame tool のドラッグ候補開始点を WebView client 座標で記録します。
    ///
    /// - Parameter event: AppKit から届いたマウスダウンイベント。
    private func beginNativeFramePlacementTrackingIfNeeded(_ event: NSEvent) {
        guard activeToolRawValue == CanvasTool.frame.rawValue,
              event.buttonNumber == 0
        else {
            return
        }
        framePlacementPreviewStartPoint = clientPoint(for: event)
        framePlacementPreviewDidBegin = false
        framePlacementPreviewOverlay = nil
    }

    /// 論理名（日本語）: フレーム配置preview更新関数
    /// 処理概要: native drag 中の対角矩形を AppKit overlay として更新します。
    ///
    /// - Parameter event: AppKit から届いたドラッグイベント。
    private func updateNativeFramePlacementPreviewIfNeeded(_ event: NSEvent) {
        guard activeToolRawValue == CanvasTool.frame.rawValue,
              let startPoint = framePlacementPreviewStartPoint
        else {
            return
        }
        let currentPoint = clientPoint(for: event)
        let dragDistance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        if !framePlacementPreviewDidBegin && dragDistance < framePlacementPreviewDragThreshold {
            return
        }
        framePlacementPreviewDidBegin = true
        let rect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        framePlacementPreviewOverlay = WebCanvasEditingOverlay(
            rect: rect,
            label: "Frame \(Int(rect.width.rounded())) x \(Int(rect.height.rounded()))",
            style: .placementPreview
        )
        refreshEditingOverlays()
    }

    /// 論理名（日本語）: フレーム配置preview終了関数
    /// 処理概要: mouse up / cancel 後に native preview overlay を消去します。
    private func endNativeFramePlacementPreview() {
        framePlacementPreviewStartPoint = nil
        framePlacementPreviewDidBegin = false
        framePlacementPreviewOverlay = nil
        refreshEditingOverlays()
    }

    /// 論理名（日本語）: フレーム配置マウスイベント転送関数
    /// 処理概要: AppKit 座標を DOM client 座標へ変換し、JavaScript bridge の native fallback へ送ります。
    ///
    /// - Parameters:
    ///   - kind: `down`、`move`、`up` のいずれか。
    ///   - event: AppKit から届いたマウスイベント。
    private func forwardFramePlacementMouseEvent(_ kind: String, event: NSEvent) {
        let point = clientPoint(for: event)
        let script = """
        window.OpenGraphite && window.OpenGraphite.handleFramePlacementNativeEvent(
          '\(kind)',
          \(point.x),
          \(point.y),
          \(event.buttonNumber)
        );
        """
        evaluateJavaScript(script, completionHandler: nil)
    }

    /// 論理名（日本語）: DOM client座標変換関数
    /// 処理概要: AppKit event 座標を DOM `clientX/clientY` と同じ左上原点座標へ変換します。
    ///
    /// - Parameter event: AppKit から届いたマウスイベント。
    /// - Returns: WebView client 座標。
    private func clientPoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let clientX = min(max(point.x, 0), bounds.width)
        let rawClientY = isFlipped ? point.y : bounds.height - point.y
        let clientY = min(max(rawClientY, 0), bounds.height)
        return CGPoint(x: clientX, y: clientY)
    }

    /// 論理名（日本語）: コピーショートカット判定関数
    /// 処理概要: 入力イベントが `⌘C` のキー相当かを判定します。
    ///
    /// - Parameter event: 入力イベント。
    /// - Returns: `⌘C` であれば `true`。
    private func isCopyKeyEquivalent(_ event: NSEvent) -> Bool {
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return relevantModifiers == .command
            && event.charactersIgnoringModifiers?.lowercased() == "c"
    }
}

/// 論理名（日本語）: WebキャンバスFocus隔離スクリプト
/// 概要: Focus表示中に選択DOM subtreeのみを可視化し、元のlayoutとsource identityを保つsession-only controllerを定義します。
///
/// 定義内容:
/// - `source`: DOM属性やinline styleを付与せず、キャンセル可能なWeb Animations API effectで
///   `window.OpenGraphiteFocusIsolation` を導入するJavaScript。
enum WebCanvasFocusIsolationScript {
    static var source: String {
        """
        (function() {
          if (window.OpenGraphiteFocusIsolation) { return; }
          const sessionAnimations = new Set();
          let activeTargets = [];

          function applySessionEffect(element, keyframe) {
            if (!(element instanceof Element) || typeof element.animate !== 'function') { return; }
            const animation = element.animate(
              [keyframe, keyframe],
              { duration: 86400000, fill: 'both' }
            );
            animation.pause();
            animation.currentTime = 0;
            sessionAnimations.add(animation);
          }

          function cancelSessionEffects() {
            sessionAnimations.forEach((animation) => animation.cancel());
            sessionAnimations.clear();
          }

          function clear() {
            cancelSessionEffects();
            activeTargets = [];
          }

          function apply(elements) {
            clear();
            const targets = (Array.isArray(elements) ? elements : []).filter((element) => {
              return element instanceof Element && element.isConnected;
            });
            if (targets.length === 0 || !document.documentElement) { return false; }

            activeTargets = targets.slice();
            applySessionEffect(document.documentElement, {
              overflow: 'hidden',
              overscrollBehavior: 'none'
            });
            if (document.body) {
              applySessionEffect(document.body, {
                overflow: 'hidden',
                overscrollBehavior: 'none'
              });
            }
            const documentScroller = document.scrollingElement || document.documentElement;
            if (documentScroller) {
              documentScroller.scrollLeft = 0;
              documentScroller.scrollTop = 0;
            }
            Array.from(document.body ? document.body.querySelectorAll('*') : []).forEach((element) => {
              const isVisible = targets.some((target) => element === target || target.contains(element));
              if (!isVisible) {
                applySessionEffect(element, { visibility: 'hidden' });
              }
            });
            targets.forEach((target) => applySessionEffect(target, { visibility: 'visible' }));
            return true;
          }

          function isActive() {
            return activeTargets.length > 0;
          }

          function suspend() {
            if (!isActive()) { return null; }
            const targets = activeTargets.slice();
            clear();
            return targets;
          }

          function resume(targets) {
            if (!Array.isArray(targets) || targets.length === 0) { return false; }
            return apply(targets);
          }

          window.OpenGraphiteFocusIsolation = Object.freeze({
            apply: apply,
            clear: clear,
            isActive: isActive,
            suspend: suspend,
            resume: resume,
            installStyle: function() { return true; }
          });
        })();
        """
    }
}

/// 論理名（日本語）: Webキャンバスビュー
/// 概要: HTML 正本を WKWebView で表示し、DOM 選択、Inspector 変更、コンテキストメニュー操作を SwiftUI へ接続します。
///
/// プロパティ:
/// - `store`: エディター状態を保持するストア。
/// - `pageURL`: 表示する HTML ファイル URL。未指定時は選択中ページを使います。
/// - `pageInternalID`: 表示している page card の内部 ID。
/// - `syncTarget`: 保存対象 HTML の object identity と固定 URL。
/// - `isInteractive`: DOM 収集、選択、編集同期を有効にするか。
/// - `reloadToken`: 外部変更で同じ URL を再読み込みするためのトークン。
/// - `previewContext`: エディター内 preview に注入する runtime Mock State。
/// - `allowsComponentPlacements`: component placement の preview clone 展開を許可するか。
/// - `focusedNodeIDs`: 通常選択とは独立して単独表示する DOM node ID 一覧。
/// - `onFocusedNodeFrame`: 単独表示対象のWebView座標矩形が解決されたときの通知。
struct WebCanvasView: NSViewRepresentable {
    @ObservedObject var store: EditorStore
    var pageURL: URL?
    var pageInternalID: String?
    var syncTarget: HTMLSyncTarget?
    var isInteractive = true
    var reloadToken = 0
    var previewContext: OpenGraphitePreviewContext = .empty
    var allowsComponentPlacements = false
    var focusedNodeIDs: [String] = []
    var onFocusedNodeFrame: ((CGRect?) -> Void)?

    /// 論理名（日本語）: コーディネーター生成関数
    /// 処理概要: WKWebView の navigation、script message、context menu を処理するコーディネーターを生成します。
    ///
    /// - Returns: WebCanvasView 用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(
            store: store,
            isInteractive: isInteractive,
            pageInternalID: pageInternalID,
            focusedNodeIDs: focusedNodeIDs,
            onFocusedNodeFrame: onFocusedNodeFrame
        )
    }

    /// 論理名（日本語）: WKWebView生成関数
    /// 処理概要: OpenGraphite ブリッジスクリプトとメッセージハンドラを設定した WKWebView を作成します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: HTML プレビュー用 WKWebView。
    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "openGraphiteNodes")
        userContentController.add(context.coordinator, name: "openGraphiteNodeDetails")
        userContentController.add(context.coordinator, name: "openGraphiteSelection")
        userContentController.add(context.coordinator, name: "openGraphiteContextMenu")
        userContentController.add(context.coordinator, name: "openGraphiteScrollState")
        userContentController.add(context.coordinator, name: "openGraphiteDocumentChange")
        userContentController.add(context.coordinator, name: "openGraphiteTextEditing")
        userContentController.add(context.coordinator, name: "openGraphiteStaticFlowLinks")
        userContentController.add(context.coordinator, name: "openGraphiteStaticFlowHover")
        userContentController.add(context.coordinator, name: "openGraphiteSelectionOverlay")
        userContentController.add(context.coordinator, name: "openGraphiteNodeDragPreview")
        Self.installUserScripts(
            on: userContentController,
            previewContext: previewContext,
            allowsComponentPlacements: allowsComponentPlacements
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        let webView = OpenGraphiteCommandWebView(frame: .zero, configuration: configuration)
        webView.applyTransparentPreviewBackground()
        webView.setDocumentScrollingSuppressed(!focusedNodeIDs.isEmpty)
        webView.hidePreviewContentUntilStyled()
        webView.copyCommandHandler = { [weak coordinator = context.coordinator] in
            coordinator?.copySelectionForCommand() ?? false
        }
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.lastPreviewContext = previewContext
        context.coordinator.lastAllowsComponentPlacements = allowsComponentPlacements
        context.coordinator.lastFocusedNodeIDs = nil
        WebScrollStateRegistry.shared.update(.outside, for: webView)
        return webView
    }

    /// 論理名（日本語）: WKWebView更新関数
    /// 処理概要: 選択ページ、選択ノード、Inspector mutation の変化を WKWebView に反映します。
    ///
    /// - Parameters:
    ///   - webView: 更新対象の WKWebView。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ webView: WKWebView, context: Context) {
        let becameInteractive = !context.coordinator.isInteractive && isInteractive
        context.coordinator.store = store
        context.coordinator.isInteractive = isInteractive
        context.coordinator.pageInternalID = pageInternalID
        context.coordinator.syncTarget = syncTarget
        context.coordinator.focusedNodeIDs = focusedNodeIDs
        context.coordinator.onFocusedNodeFrame = onFocusedNodeFrame
        (webView as? OpenGraphiteCommandWebView)?.setDocumentScrollingSuppressed(
            !focusedNodeIDs.isEmpty
        )

        let previewContextChanged = context.coordinator.lastPreviewContext != previewContext
        let componentPlacementModeChanged = context.coordinator.lastAllowsComponentPlacements != allowsComponentPlacements
        if previewContextChanged || componentPlacementModeChanged {
            Self.installUserScripts(
                on: webView.configuration.userContentController,
                previewContext: previewContext,
                allowsComponentPlacements: allowsComponentPlacements
            )
            context.coordinator.lastPreviewContext = previewContext
            context.coordinator.lastAllowsComponentPlacements = allowsComponentPlacements
        }

        let targetPageURL = syncTarget?.htmlURL ?? pageURL ?? store.selectedPageURL
        if let targetPageURL {
            let loadedURLChanged = context.coordinator.loadedURL != targetPageURL
            let reloadTokenChanged = context.coordinator.lastReloadToken != reloadToken
            if loadedURLChanged || reloadTokenChanged || previewContextChanged || componentPlacementModeChanged {
                context.coordinator.loadedURL = targetPageURL
                context.coordinator.lastReloadToken = reloadToken
                context.coordinator.lastSelectedNodeID = nil
                context.coordinator.lastSelectedNodeIDs = []
                context.coordinator.lastActiveTool = nil
                context.coordinator.lastFocusedNodeIDs = nil
                context.coordinator.hidePreviewUntilStyled()
                if loadedURLChanged || webView.url == nil {
                    let readAccessURL = store.projectRootURL ?? targetPageURL.deletingLastPathComponent()
                    webView.loadFileURL(targetPageURL, allowingReadAccessTo: readAccessURL)
                } else {
                    webView.reloadFromOrigin()
                }
            }
        }

        if pageURL == nil, targetPageURL == nil {
            context.coordinator.loadedURL = nil
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.lastSelectedNodeID = nil
            context.coordinator.lastSelectedNodeIDs = []
            context.coordinator.lastFocusedNodeIDs = nil
        }

        guard isInteractive else {
            if context.coordinator.lastSelectedNodeID != nil || !context.coordinator.lastSelectedNodeIDs.isEmpty {
                context.coordinator.lastSelectedNodeID = nil
                context.coordinator.lastSelectedNodeIDs = []
                context.coordinator.selectNodes([], primaryID: nil)
            }
            if context.coordinator.lastFocusedNodeIDs != focusedNodeIDs {
                context.coordinator.lastFocusedNodeIDs = focusedNodeIDs
                context.coordinator.setFocusedNodes(focusedNodeIDs)
            }
            return
        }

        if becameInteractive {
            context.coordinator.collectNodes()
            context.coordinator.lastSelectedNodeID = nil
            context.coordinator.lastSelectedNodeIDs = []
            context.coordinator.lastActiveTool = nil
        }

        let selectedNodeIDs = store.selectedLayerNodeIDsInNodeOrder
        if context.coordinator.lastSelectedNodeID != store.selectedNodeID
            || context.coordinator.lastSelectedNodeIDs != selectedNodeIDs {
            context.coordinator.lastSelectedNodeID = store.selectedNodeID
            context.coordinator.lastSelectedNodeIDs = selectedNodeIDs
            context.coordinator.selectNodes(selectedNodeIDs, primaryID: store.selectedNodeID)
        }

        if context.coordinator.lastFocusedNodeIDs != focusedNodeIDs {
            context.coordinator.lastFocusedNodeIDs = focusedNodeIDs
            context.coordinator.setFocusedNodes(focusedNodeIDs)
        }

        if context.coordinator.lastActiveTool != store.activeTool {
            context.coordinator.lastActiveTool = store.activeTool
            context.coordinator.setActiveTool(store.activeTool)
        }

        if let mutation = store.cssMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedMutationSequence != mutation.sequence {
            context.coordinator.applyMutation(mutation)
        }

        if let mutation = store.cssVariablesMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedVariablesMutationSequence != mutation.sequence {
            context.coordinator.applyVariablesMutation(mutation)
        }

        if let mutation = store.cssVariablesBatchMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedVariablesBatchMutationSequence != mutation.sequence {
            context.coordinator.applyVariablesBatchMutation(mutation)
        }

        if let mutation = store.attributeMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedAttributeMutationSequence != mutation.sequence {
            context.coordinator.applyAttributeMutation(mutation)
        }

        if let mutation = store.textMutation,
           mutation.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedTextMutationSequence != mutation.sequence {
            context.coordinator.applyTextMutation(mutation)
        }

        if let request = store.documentReplacementRequest,
           request.pageURL == context.coordinator.loadedURL,
           context.coordinator.lastAppliedDocumentReplacementSequence != request.sequence {
            context.coordinator.applyDocumentReplacement(request)
        }
    }

    /// 論理名（日本語）: WKWebView解体関数
    /// 処理概要: script message handler とスクロール状態登録を破棄します。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象の WKWebView。
    ///   - coordinator: WKWebView に紐づくコーディネーター。
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteNodes")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteNodeDetails")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteSelection")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteContextMenu")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteScrollState")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteDocumentChange")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteTextEditing")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteStaticFlowLinks")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteStaticFlowHover")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteSelectionOverlay")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openGraphiteNodeDragPreview")
        WebScrollStateRegistry.shared.remove(for: nsView)
    }

    /// 論理名（日本語）: WebViewユーザースクリプト設定関数
    /// 処理概要: preview Mock State 注入 script と編集 bridge script を読み込み順に登録します。
    ///
    /// - Parameters:
    ///   - userContentController: script を保持する WKUserContentController。
    ///   - previewContext: preview に注入する runtime Mock State。
    private static func installUserScripts(
        on userContentController: WKUserContentController,
        previewContext: OpenGraphitePreviewContext,
        allowsComponentPlacements: Bool
    ) {
        userContentController.removeAllUserScripts()
        userContentController.addUserScript(
            WKUserScript(
                source: previewContextScript(for: previewContext),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        if allowsComponentPlacements {
            userContentController.addUserScript(
                WKUserScript(
                    source: componentPlacementReferencesScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
        }
        userContentController.addUserScript(
            WKUserScript(
                source: bridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
    }

    /// 論理名（日本語）: プレビューContext注入スクリプト生成関数
    /// 処理概要: HTML document metadata と `.ogp` の Mock State を preview 用 JS と HTML 属性へ反映します。
    ///
    /// - Parameter previewContext: preview に注入する runtime Mock State。
    /// - Returns: document start で実行する JavaScript。
    static func previewContextScript(for previewContext: OpenGraphitePreviewContext) -> String {
        let payload: [String: Any] = [
            "fields": previewContext.fieldMocks,
            "placementMocks": previewContext.placementMocks
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data("{}".utf8)
        let literal = String(data: data, encoding: .utf8) ?? "{}"
        return """
        (function() {
          const payload = \(literal);
          const rawFields = payload && typeof payload.fields === 'object' && payload.fields ? payload.fields : {};
          const rawPlacementMocks = payload && typeof payload.placementMocks === 'object' && payload.placementMocks ? payload.placementMocks : {};
          const fields = {};
          Object.keys(rawFields).forEach((key) => {
            fields[key] = rawFields[key];
          });
          Object.freeze(fields);
          const placementMocks = {};
          Object.keys(rawPlacementMocks).forEach((placementID) => {
            const rawPlacementFields = rawPlacementMocks[placementID];
            if (!rawPlacementFields || typeof rawPlacementFields !== 'object') { return; }
            const placementFields = {};
            Object.keys(rawPlacementFields).forEach((key) => {
              placementFields[key] = rawPlacementFields[key];
            });
            placementMocks[placementID] = Object.freeze(placementFields);
          });
          Object.freeze(placementMocks);
          const root = document.documentElement;
          function fieldOverride(name) {
            if (!name || !Object.prototype.hasOwnProperty.call(fields, name)) {
              return { found: false, value: '' };
            }
            return { found: true, value: String(fields[name]) };
          }
          function primaryLanguageSubtag(lang) {
            return String(lang || '').trim().split(/[-_]/)[0].toLowerCase();
          }
          function directionForLanguage(lang) {
            const rtlLanguages = new Set(['ar', 'arc', 'dv', 'fa', 'ha', 'he', 'khw', 'ks', 'ku', 'ps', 'ur', 'yi']);
            return rtlLanguages.has(primaryLanguageSubtag(lang)) ? 'rtl' : 'ltr';
          }
          const fallbackLang = root.getAttribute('lang') || '';
          const langSource = root.getAttribute('data-og-lang-source') || 'literal';
          const langField = root.getAttribute('data-og-lang-field') || '';
          let resolvedLang = fallbackLang;
          if (langSource === 'binding') {
            const binding = fieldOverride(langField);
            if (binding.found) {
              resolvedLang = binding.value;
            }
          }
          const fallbackDir = root.getAttribute('dir') || '';
          const dirSource = root.getAttribute('data-og-dir-source') || 'literal';
          const dirField = root.getAttribute('data-og-dir-field') || '';
          let resolvedDir = fallbackDir;
          if (dirSource === 'binding') {
            const binding = fieldOverride(dirField);
            if (binding.found) {
              resolvedDir = binding.value;
            }
          } else if (dirSource === 'auto') {
            resolvedDir = resolvedLang ? directionForLanguage(resolvedLang) : fallbackDir;
          }
          const documentContext = Object.freeze({
            lang: resolvedLang,
            locale: resolvedLang,
            langSource: langSource,
            langField: langField,
            langFallback: fallbackLang,
            dir: resolvedDir,
            dirSource: dirSource,
            dirField: dirField,
            dirFallback: fallbackDir
          });
          const context = {
            document: documentContext,
            fields: fields,
            placementMocks: placementMocks
          };
          const blockedKeys = new Set(['__proto__', 'constructor', 'prototype']);
          Object.keys(fields).forEach((key) => {
            if (/^[A-Za-z_$][0-9A-Za-z_$]*$/.test(key) && !blockedKeys.has(key) && !(key in context)) {
              context[key] = fields[key];
            }
          });
          if (!Object.prototype.hasOwnProperty.call(window, '__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__')) {
            Object.defineProperty(window, '__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__', {
              configurable: false,
              enumerable: false,
              value: Object.freeze({
                hasLang: document.documentElement.hasAttribute('lang'),
                lang: document.documentElement.getAttribute('lang') || '',
                hasDir: document.documentElement.hasAttribute('dir'),
                dir: document.documentElement.getAttribute('dir') || ''
              })
            });
          }
          if (documentContext.lang) {
            document.documentElement.lang = documentContext.lang;
          } else {
            document.documentElement.removeAttribute('lang');
          }
          if (documentContext.dir) {
            document.documentElement.dir = documentContext.dir;
          } else {
            document.documentElement.removeAttribute('dir');
          }
          window.__OPENGRAPHITE_PREVIEW_CONTEXT__ = Object.freeze(context);
        })();
        """
    }

    /// 論理名（日本語）: Component Placement参照レンダリングスクリプト
    /// 処理概要: HTML 内の placement host へ参照元 component node の clone を展開し、
    /// DOM属性ではなくsession-onlyの `WeakMap` / `WeakSet` でprovenanceを保持します。
    static let componentPlacementReferencesScript = """
        (function() {
          if (window.OpenGraphiteComponentPlacementReferences &&
              typeof window.OpenGraphiteComponentPlacementReferences.render === 'function') {
            window.OpenGraphiteComponentPlacementReferences.render();
            return;
          }

          const metadataByElement = new WeakMap();
          const generatedElements = new WeakSet();
          const generatedRootByHost = new WeakMap();

          function placementHosts() {
            return Array.from(document.querySelectorAll('og-placement[data-og-source-node-internal-id]'));
          }

          function elementValue(value) {
            if (value && value.nodeType === Node.ELEMENT_NODE) { return value; }
            return value && value.parentElement ? value.parentElement : null;
          }

          function composedParent(value) {
            if (!value) { return null; }
            if (value.parentElement) { return value.parentElement; }
            const root = typeof value.getRootNode === 'function' ? value.getRootNode() : null;
            return root && root.host ? root.host : null;
          }

          function composedElements(root) {
            const elements = [];
            function visit(node) {
              if (!node || node.nodeType !== Node.ELEMENT_NODE) { return; }
              elements.push(node);
              if (node.shadowRoot) {
                Array.from(node.shadowRoot.children || []).forEach(visit);
              }
              Array.from(node.children || []).forEach(visit);
            }
            visit(root);
            return elements;
          }

          function cloneWithOpenShadowRoots(source) {
            const clone = source.cloneNode(true);
            function copyShadowTrees(sourceNode, cloneNode) {
              if (!sourceNode || !cloneNode || sourceNode.nodeType !== Node.ELEMENT_NODE || cloneNode.nodeType !== Node.ELEMENT_NODE) {
                return;
              }
              if (sourceNode.shadowRoot) {
                let cloneShadowRoot = cloneNode.shadowRoot;
                if (!cloneShadowRoot) {
                  try {
                    cloneShadowRoot = cloneNode.attachShadow({ mode: 'open' });
                  } catch (_) {
                    cloneShadowRoot = null;
                  }
                }
                if (cloneShadowRoot) {
                  cloneShadowRoot.replaceChildren(...Array.from(sourceNode.shadowRoot.childNodes).map((child) => child.cloneNode(true)));
                  Array.from(sourceNode.shadowRoot.children || []).forEach((sourceChild, index) => {
                    copyShadowTrees(sourceChild, cloneShadowRoot.children[index]);
                  });
                }
              }
              Array.from(sourceNode.children || []).forEach((sourceChild, index) => {
                copyShadowTrees(sourceChild, cloneNode.children[index]);
              });
            }
            copyShadowTrees(source, clone);
            return clone;
          }

          function applyStandardHostPreviewState(host, fields) {
            const runtime = window.OpenGraphiteRuntime;
            if (runtime && typeof runtime.applyPreviewState === 'function') {
              return runtime.applyPreviewState(host, fields);
            }
            const booleanAttributes = new Set([
              'autofocus', 'autoplay', 'checked', 'controls', 'disabled', 'hidden', 'inert',
              'loop', 'multiple', 'muted', 'open', 'readonly', 'required', 'selected'
            ]);
            const protectedAttributes = new Set(['id', 'part', 'slot', 'style']);
            const appliedAttributes = [];
            const appliedClasses = [];
            Object.keys(fields || {}).sort().forEach((fieldName) => {
              if (!fieldName.startsWith('host.')) { return; }
              const attributeName = fieldName.slice(5).trim().toLowerCase();
              if (!/^[a-z_:][a-z0-9_.:-]*$/.test(attributeName)) { return; }
              if (attributeName.startsWith('on') || attributeName.startsWith('data-og-') || protectedAttributes.has(attributeName)) { return; }
              const value = String(fields[fieldName]);
              if (attributeName === 'class') {
                value.split(/\\s+/).filter(Boolean).forEach((token) => {
                  try {
                    host.classList.add(token);
                    appliedClasses.push(token);
                  } catch (_) {}
                });
                return;
              }
              if (booleanAttributes.has(attributeName)) {
                const present = !['0', 'false', 'no', 'off'].includes(value.trim().toLowerCase());
                if (present) { host.setAttribute(attributeName, ''); }
                else { host.removeAttribute(attributeName); }
              } else {
                host.setAttribute(attributeName, value);
              }
              appliedAttributes.push(attributeName);
            });
            return Object.freeze({
              attributes: Object.freeze(appliedAttributes),
              classes: Object.freeze(appliedClasses)
            });
          }

          function metadataFor(value) {
            let element = elementValue(value);
            while (element) {
              const metadata = metadataByElement.get(element);
              if (metadata) { return metadata; }
              element = composedParent(element);
            }
            return null;
          }

          function isGenerated(value) {
            let element = elementValue(value);
            while (element) {
              if (generatedElements.has(element)) { return true; }
              element = composedParent(element);
            }
            return false;
          }

          function hostFor(value) {
            const metadata = metadataFor(value);
            return metadata ? metadata.host : null;
          }

          function rootFor(value) {
            const metadata = metadataFor(value);
            return metadata ? metadata.root : null;
          }

          function sourceFor(value) {
            const metadata = metadataFor(value);
            return metadata ? metadata.source : null;
          }

          function placementIDFor(value) {
            const metadata = metadataFor(value);
            return metadata ? metadata.placementID : '';
          }

          function sourceNodeFor(host) {
            const nodeInternalID = String(host.getAttribute('data-og-source-node-internal-id') || '').trim();
            if (!nodeInternalID) { return null; }
            return Array.from(document.querySelectorAll('[data-og-internal-id]')).find((element) => {
              if (element === host) { return false; }
              if (isGenerated(element)) { return false; }
              return element.getAttribute('data-og-internal-id') === nodeInternalID;
            }) || null;
          }

          function clearGeneratedPlacementContent(host) {
            const root = generatedRootByHost.get(host);
            if (!root) { return; }
            composedElements(root).forEach((element) => {
              generatedElements.delete(element);
              metadataByElement.delete(element);
            });
            if (root.parentNode === host) {
              root.remove();
            }
            generatedRootByHost.delete(host);
          }

          function mockFieldsFor(host) {
            const context = window.__OPENGRAPHITE_PREVIEW_CONTEXT__ || {};
            const fields = Object.assign({}, context.fields || {});
            const placementMocks = context.placementMocks || {};
            const internalID = String(host.getAttribute('data-og-internal-id') || '').trim();
            const displayID = String(host.getAttribute('data-og-id') || '').trim();
            const placementFields = (internalID && placementMocks[internalID])
              || (displayID && placementMocks[displayID])
              || null;
            if (placementFields) { Object.assign(fields, placementFields); }
            return fields;
          }

          function registerGeneratedClone(root, source, host) {
            const placementID = String(
              host.getAttribute('data-og-id') || host.getAttribute('data-og-internal-id') || ''
            ).trim();
            const cloneElements = composedElements(root);
            const sourceElements = composedElements(source);
            cloneElements.forEach((element, index) => {
              const sourceElement = sourceElements[index] || source;
              generatedElements.add(element);
              metadataByElement.set(element, Object.freeze({
                host: host,
                root: root,
                source: sourceElement,
                placementID: placementID,
                previewClone: true
              }));
            });
            generatedRootByHost.set(host, root);
          }

          function inlinePlacementVariable(host, name) {
            if (!host) { return ''; }
            const inlineValue = String((host.style && host.style.getPropertyValue(name)) || '').trim();
            if (inlineValue) { return inlineValue; }
            try {
              return String(window.getComputedStyle(host).getPropertyValue(name) || '').trim();
            } catch (_) {
              return '';
            }
          }

          function applyPlacementFrameSizing(clone, host) {
            clone.style.setProperty('margin', '0');
            if (inlinePlacementVariable(host, 'width')) {
              clone.style.setProperty('width', '100%');
              clone.style.setProperty('max-width', 'none');
            }
            if (inlinePlacementVariable(host, 'height')) {
              clone.style.setProperty('height', '100%');
            }
          }

          function renderComponentPlacementReferences() {
            const hosts = placementHosts();
            hosts.forEach(clearGeneratedPlacementContent);
            hosts.forEach((host) => {
              const source = sourceNodeFor(host);
              if (!source) { return; }
              const clone = cloneWithOpenShadowRoots(source);
              const fields = mockFieldsFor(host);
              applyPlacementFrameSizing(clone, host);
              host.appendChild(clone);
              applyStandardHostPreviewState(clone, fields);
              registerGeneratedClone(clone, source, host);
            });
          }

          function clear() {
            placementHosts().forEach(clearGeneratedPlacementContent);
          }

          function suspend() {
            const state = [];
            placementHosts().forEach((host) => {
              const root = generatedRootByHost.get(host);
              if (!root || root.parentNode !== host) { return; }
              state.push(Object.freeze({ host: host, root: root, nextSibling: root.nextSibling }));
              root.remove();
            });
            return state;
          }

          function resume(state) {
            if (!Array.isArray(state)) { return false; }
            state.forEach((entry) => {
              if (!entry || !entry.host || !entry.host.isConnected || !entry.root) { return; }
              const nextSibling = entry.nextSibling && entry.nextSibling.parentNode === entry.host
                ? entry.nextSibling
                : null;
              entry.host.insertBefore(entry.root, nextSibling);
            });
            return true;
          }

          window.OpenGraphiteComponentPlacementReferences = Object.freeze({
            render: renderComponentPlacementReferences,
            clear: clear,
            suspend: suspend,
            resume: resume,
            metadataFor: metadataFor,
            isGenerated: isGenerated,
            hostFor: hostFor,
            rootFor: rootFor,
            sourceFor: sourceFor,
            placementIDFor: placementIDFor
          });
          renderComponentPlacementReferences();
        })();
        """

    /// 論理名（日本語）: Webキャンバスコーディネーター
    /// 概要: WKWebView と SwiftUI ストアの間で JavaScript bridge、HTML 永続化、context menu を仲介します。
    ///
    /// プロパティ:
    /// - `store`: エディター状態ストア。
    /// - `webView`: 管理対象の WKWebView。
    /// - `loadedURL`: 現在読み込み済みの HTML URL。
    /// - `pageInternalID`: 現在の WebView が対応する page card 内部 ID。
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        @MainActor var store: EditorStore
        weak var webView: WKWebView?
        var isInteractive: Bool
        var focusedNodeIDs: [String]
        var onFocusedNodeFrame: ((CGRect?) -> Void)?
        var pageInternalID: String?
        var syncTarget: HTMLSyncTarget?
        var loadedURL: URL?
        var lastReloadToken = 0
        var lastSelectedNodeID: String?
        var lastSelectedNodeIDs: [String] = []
        var lastActiveTool: CanvasTool?
        var lastFocusedNodeIDs: [String]?
        var lastPreviewContext = OpenGraphitePreviewContext.empty
        var lastAllowsComponentPlacements = false
        var lastAppliedMutationSequence = 0
        var lastAppliedVariablesMutationSequence = 0
        var lastAppliedVariablesBatchMutationSequence = 0
        var lastAppliedAttributeMutationSequence = 0
        var lastAppliedTextMutationSequence = 0
        var lastAppliedDocumentReplacementSequence = 0
        private var previewReadinessGeneration = 0
        private var contextMenuFocusTarget: (nodeID: String, rect: CGRect)?
        private var contextMenuFocusSegment: OpenGraphiteCanvasSegment?
        private static let htmlPasteboardType = NSPasteboard.PasteboardType("public.html")
        private static let nodeReferencePasteboardType = NSPasteboard.PasteboardType("dev.opengraphite.node-reference+json")
        private static let cssVariablesPasteboardType = NSPasteboard.PasteboardType("dev.opengraphite.css-variables")
        private static let openGraphiteStyleKeys: Set<String> = [
            "width",
            "height",
            "min-width",
            "min-height",
            "max-width",
            "display",
            "flex-direction",
            "grid-template-columns",
            "grid-template-rows",
            "grid-auto-flow",
            "flex",
            "margin",
            "padding",
            "gap",
            "align-items",
            "justify-content",
            "position",
            "left",
            "top",
            "right",
            "bottom",
            "z-index",
            "visibility",
            "overflow-wrap",
            "color",
            "background",
            "border",
            "border-radius",
            "box-shadow",
            "font-family",
            "font-size",
            "font-weight",
            "line-height",
            "letter-spacing",
            "text-align",
            "transform-origin",
            "object-fit",
            "stroke-width",
            "mask-image",
            "-webkit-mask-image",
            "scale"
        ]
        private static let webKitErrorDomain = "WebKitErrorDomain"
        private static let frameLoadInterruptedErrorCode = 102

        /// 論理名（日本語）: コーディネーター初期化関数
        /// 処理概要: WebView ブリッジで更新するエディター状態ストアを保持します。
        ///
        /// - Parameters:
        ///   - store: 連携対象のエディター状態ストア。
        ///   - isInteractive: DOM 収集、選択、編集同期を有効にするか。
        ///   - pageInternalID: WebView が表示する page card の内部 ID。
        ///   - focusedNodeIDs: 通常選択とは独立して単独表示する node ID 一覧。
        ///   - onFocusedNodeFrame: 単独表示対象の実測矩形通知。
        init(
            store: EditorStore,
            isInteractive: Bool,
            pageInternalID: String?,
            focusedNodeIDs: [String],
            onFocusedNodeFrame: ((CGRect?) -> Void)?
        ) {
            self.store = store
            self.isInteractive = isInteractive
            self.pageInternalID = pageInternalID
            self.focusedNodeIDs = focusedNodeIDs
            self.onFocusedNodeFrame = onFocusedNodeFrame
        }

        /// 論理名（日本語）: Navigationエラー抑止判定関数
        /// 処理概要: 外部変更同期や同一URL再読み込みで発生する正常な中断をユーザー表示から除外します。
        ///
        /// - Parameter error: WebKit から渡された navigation error。
        /// - Returns: 一時的な navigation 中断として無視できる場合は true。
        static func shouldSuppressNavigationError(_ error: Error) -> Bool {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return true
            }

            if nsError.domain == webKitErrorDomain, nsError.code == frameLoadInterruptedErrorCode {
                return true
            }

            return false
        }

        /// 論理名（日本語）: 暫定プレビュー非表示関数
        /// 処理概要: navigation または document 全体置換の開始時に WebKit content を隠し、古い readiness 判定を無効化します。
        func hidePreviewUntilStyled() {
            previewReadinessGeneration += 1
            (webView as? OpenGraphiteCommandWebView)?.hidePreviewContentUntilStyled()
        }

        /// 論理名（日本語）: Script Message受信関数
        /// 処理概要: JavaScript から届くノード一覧、選択、context menu、スクロール状態、ドキュメント変更通知をストアへ反映します。
        ///
        /// - Parameters:
        ///   - userContentController: メッセージ送信元の user content controller。
        ///   - message: JavaScript bridge から届いたメッセージ。
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard isInteractive
                    || message.name == "openGraphiteScrollState"
                    || message.name == "openGraphiteStaticFlowLinks"
                    || message.name == "openGraphiteStaticFlowHover"
            else {
                return
            }

            if message.name == "openGraphiteNodes", let payload = message.body as? [[String: Any]] {
                Task { @MainActor in
                    store.ingestNodePayload(payload)
                    refreshFocusedNodeFrame()
                }
            }

            if message.name == "openGraphiteNodeDetails", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    store.ingestNodeDetailPayload(payload)
                }
            }

            if message.name == "openGraphiteSelection", let id = message.body as? String {
                Task { @MainActor in
                    let selectedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !selectedID.isEmpty else {
                        store.selectNode(id: nil)
                        return
                    }
                    if store.selectPrimaryNodeWithinCurrentSelection(id: selectedID) {
                        selectNodes(store.selectedLayerNodeIDsInNodeOrder, primaryID: selectedID)
                    } else {
                        store.selectNode(id: selectedID)
                    }
                }
            }

            if message.name == "openGraphiteContextMenu", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    if let id = payload["id"] as? String, !id.isEmpty {
                        store.selectNode(id: id)
                    }
                    showContextMenu(payload: payload)
                }
            }

            if message.name == "openGraphiteScrollState", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    updateScrollState(payload: payload)
                }
            }

            if message.name == "openGraphiteDocumentChange", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    guard let target = syncTarget else { return }
                    let result = store.applyHTMLObjectEditPayload(payload, target: target)
                    if result.updated {
                        if let selectedID = payload["selectedID"] as? String, !selectedID.isEmpty {
                            store.selectNode(id: selectedID)
                        }
                        if result.requiresReload {
                            reloadCurrentPageFromDisk()
                        } else {
                            collectNodes()
                        }
                    } else {
                        reloadCurrentPageFromDisk()
                    }
                }
            }

            if message.name == "openGraphiteTextEditing", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    store.ingestTextEditingPayload(payload)
                }
            }

            if message.name == "openGraphiteStaticFlowLinks", let payload = message.body as? [[String: Any]] {
                Task { @MainActor in
                    guard let loadedURL else { return }
                    store.ingestStaticFlowLinkPayload(payload, pageURL: loadedURL, pageInternalID: pageInternalID)
                }
            }

            if message.name == "openGraphiteStaticFlowHover", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    guard let loadedURL else { return }
                    store.ingestStaticFlowSourceHoverPayload(payload, pageURL: loadedURL, pageInternalID: pageInternalID)
                }
            }

            if message.name == "openGraphiteSelectionOverlay" {
                Task { @MainActor in
                    ingestSelectionOverlayPayload(message.body)
                }
            }

            if message.name == "openGraphiteNodeDragPreview", let payload = message.body as? [String: Any] {
                Task { @MainActor in
                    store.ingestNodeDragPreviewPayload(payload, pageInternalID: pageInternalID)
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 選択オーバーレイ受信関数
        /// 処理概要: WebView JavaScript から届いた実測選択矩形を Store に反映します。
        ///
        /// - Parameter body: script message body。選択中は辞書、それ以外は空辞書または不正値です。
        private func ingestSelectionOverlayPayload(_ body: Any) {
            store.ingestSelectionOverlayPayload(body as? [String: Any], pageInternalID: pageInternalID)
        }

        /// 論理名（日本語）: WebView読み込み完了関数
        /// 処理概要: HTML 読み込み完了後に DOM ノード一覧を収集し、選択状態を再適用します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みが完了した WebView。
        ///   - navigation: 完了した navigation。
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            renderLocalComponentReferences(in: webView)
            renderComponentPlacements(in: webView) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.finishPreviewLoad(in: webView)
            }
        }

        /// 論理名（日本語）: Preview読み込み後処理関数
        /// 処理概要: 生成DOMの反映後に preview 表示、静的リンク収集、編集状態の再適用を行います。
        ///
        /// - Parameter webView: 読み込み完了後の WebView。
        private func finishPreviewLoad(in webView: WKWebView) {
            revealPreviewWhenDocumentIsStyled(in: webView)
            collectStaticFlowLinks()
            if isInteractive || !focusedNodeIDs.isEmpty {
                collectNodes()
            }
            Task { @MainActor in
                if isInteractive {
                    setActiveTool(store.activeTool)
                    selectNodes(store.selectedLayerNodeIDsInNodeOrder, primaryID: store.selectedNodeID)
                }
                setFocusedNodes(focusedNodeIDs)
            }
        }

        /// 論理名（日本語）: ローカルcomponent参照レンダリング関数
        /// 処理概要: `file://` の component master を Swift 側で読み、runtime に渡して WKWebView の file URL 制約を補完します。
        ///
        /// - Parameter webView: component 参照を展開する WebView。
        private func renderLocalComponentReferences(in webView: WKWebView) {
            let discoveryScript = """
            (function() {
              return {
                componentHrefs: Array.from(document.querySelectorAll('link[rel="opengraphite-components"][href]')).map((link) => link.href),
                runtimeLoaded: !!(window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function'),
                runtimeHrefs: Array.from(document.querySelectorAll('script[src*="OpenGraphite.runtime.js"]')).map((script) => script.src)
              };
            })();
            """

            webView.evaluateJavaScript(discoveryScript) { [weak self, weak webView] result, _ in
                guard let self, let webView, let payload = result as? [String: Any] else { return }
                let componentHrefs = payload["componentHrefs"] as? [String] ?? []
                let componentDocuments = self.localHTMLDocumentsWithBaseURLs(from: componentHrefs)
                guard !componentDocuments.isEmpty else { return }

                let runtimeLoaded = payload["runtimeLoaded"] as? Bool ?? false
                let runtimeHrefs = payload["runtimeHrefs"] as? [String] ?? []
                let runtimeSource = self.localTextDocuments(from: runtimeHrefs).first
                guard runtimeLoaded || runtimeSource != nil else { return }

                let componentDocumentsLiteral = Self.javaScriptObjectArrayLiteral(componentDocuments)
                let renderScript = """
                (function() {
                  \(runtimeSource ?? "")
                  if (window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.renderComponentHTMLDocuments === 'function') {
                    window.OpenGraphiteRuntime.renderComponentHTMLDocuments(\(componentDocumentsLiteral));
                    return true;
                  }
                  return false;
                })();
                """

                webView.evaluateJavaScript(renderScript) { [weak self] result, _ in
                    guard let self, (result as? Bool) == true else { return }
                    self.renderComponentPlacements(in: webView) { [weak self, weak webView] in
                        guard let self, let webView else { return }
                        self.finishPreviewLoad(in: webView)
                    }
                }
            }
        }

        /// 論理名（日本語）: Component Placement再描画関数
        /// 処理概要: WebView 内の placement host へ source node clone と placement-local state を反映します。
        ///
        /// - Parameters:
        ///   - webView: placement を展開する WebView。
        ///   - completion: 展開試行後に main thread で実行する処理。
        private func renderComponentPlacements(in webView: WKWebView, completion: (() -> Void)? = nil) {
            let script = """
            (function() {
              if (window.OpenGraphiteComponentPlacementReferences &&
                  typeof window.OpenGraphiteComponentPlacementReferences.render === 'function') {
                window.OpenGraphiteComponentPlacementReferences.render();
                return true;
              }
              return false;
            })();
            """
            webView.evaluateJavaScript(script) { _, _ in
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }

        /// 論理名（日本語）: ローカルtext文書読み込み関数
        /// 処理概要: JS から得た href のうち `file://` URL だけを UTF-8 text として読み込みます。
        ///
        /// - Parameter hrefs: component link や runtime script の href 一覧。
        /// - Returns: 読み込みに成功した text document 一覧。
        private func localTextDocuments(from hrefs: [String]) -> [String] {
            hrefs.compactMap { href -> String? in
                guard let url = URL(string: href), url.isFileURL else { return nil }
                return try? String(contentsOf: url, encoding: .utf8)
            }
        }

        /// 論理名（日本語）: base URL付きローカルHTML文書読み込み関数
        /// 処理概要: component HTMLと元のfile URLを組にし、相対stylesheet・asset参照をruntimeが正しく解決できるpayloadを作ります。
        ///
        /// - Parameter hrefs: component linkのhref一覧。
        /// - Returns: HTML本文とbase URLを持つdocument payload一覧。
        private func localHTMLDocumentsWithBaseURLs(from hrefs: [String]) -> [[String: String]] {
            hrefs.compactMap { href -> [String: String]? in
                guard
                    let url = URL(string: href),
                    url.isFileURL,
                    let html = try? String(contentsOf: url, encoding: .utf8)
                else {
                    return nil
                }
                return ["baseURL": url.absoluteString, "html": html]
            }
        }

        /// 論理名（日本語）: WebViewノード収集関数
        /// 処理概要: 表示中 DOM から OpenGraphite node graph を JavaScript bridge 経由で再収集します。
        func collectNodes() {
            webView?.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.collectLayerNodes();")
        }

        /// 論理名（日本語）: WebView静的フローリンク収集関数
        /// 処理概要: 表示中 DOM の静的リンク要素と viewport 矩形を JavaScript bridge 経由で再収集します。
        func collectStaticFlowLinks() {
            webView?.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.collectStaticFlowLinks();")
        }

        /// 論理名（日本語）: WebView暫定読み込み開始関数
        /// 処理概要: WebKit が provisional document を描画する前に content を隠し、白背景の露出を抑止します。
        ///
        /// - Parameters:
        ///   - webView: 読み込み開始対象の WebView。
        ///   - navigation: 開始した provisional navigation。
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            lastActiveTool = nil
            (webView as? OpenGraphiteCommandWebView)?.clearEditingOverlays()
            hidePreviewUntilStyled()
        }

        /// 論理名（日本語）: WebViewコミット開始関数
        /// 処理概要: レスポンスが main frame に反映される境界でも content を隠した状態を維持します。
        ///
        /// - Parameters:
        ///   - webView: 読み込み中の WebView。
        ///   - navigation: コミットされた navigation。
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            lastActiveTool = nil
            (webView as? OpenGraphiteCommandWebView)?.clearEditingOverlays()
            (webView as? OpenGraphiteCommandWebView)?.hidePreviewContentUntilStyled()
        }

        /// 論理名（日本語）: WebView読み込み失敗関数
        /// 処理概要: 確定後 navigation の失敗をエディターのエラー表示へ転送します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みに失敗した WebView。
        ///   - navigation: 失敗した navigation。
        ///   - error: WebKit から渡されたエラー。
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !Self.shouldSuppressNavigationError(error) else { return }
            Task { @MainActor in
                store.reportWebError("HTMLの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }

        /// 論理名（日本語）: WebView暫定読み込み失敗関数
        /// 処理概要: provisional navigation の失敗をエディターのエラー表示へ転送します。
        ///
        /// - Parameters:
        ///   - webView: 読み込みに失敗した WebView。
        ///   - navigation: 失敗した provisional navigation。
        ///   - error: WebKit から渡されたエラー。
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !Self.shouldSuppressNavigationError(error) else { return }
            Task { @MainActor in
                store.reportWebError("HTMLの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }

        /// 論理名（日本語）: 文書準備後プレビュー表示関数
        /// 処理概要: 標準HTML文書のDOM準備を確認してWebKit contentを表示し、判定不能でも上限到達時に必ず表示します。
        ///
        /// - Parameters:
        ///   - webView: 表示判定対象の WebView。
        ///   - generation: 判定開始時点の readiness 世代。省略時は現在世代を使います。
        ///   - attempt: 再試行回数。
        private func revealPreviewWhenDocumentIsStyled(
            in webView: WKWebView,
            generation: Int? = nil,
            attempt: Int = 0
        ) {
            let generation = generation ?? previewReadinessGeneration
            webView.evaluateJavaScript(Self.previewReadinessScript) { [weak self, weak webView] result, _ in
                guard let self, let webView else { return }
                let isReady = (result as? Bool) == true
                DispatchQueue.main.async {
                    guard self.previewReadinessGeneration == generation else { return }
                    if isReady {
                        (webView as? OpenGraphiteCommandWebView)?.revealStyledPreviewContent()
                    } else if attempt < Self.previewReadinessMaximumAttempts {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewReadinessRetryInterval) { [weak self, weak webView] in
                            guard let self, let webView else { return }
                            self.revealPreviewWhenDocumentIsStyled(
                                in: webView,
                                generation: generation,
                                attempt: attempt + 1
                            )
                        }
                    } else {
                        (webView as? OpenGraphiteCommandWebView)?.revealStyledPreviewContent()
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: WebViewノード選択関数
        /// 処理概要: Swift 側の選択 ID を JavaScript bridge 経由で DOM の選択表示へ反映します。
        ///
        /// - Parameter id: 選択する node ID。placement clone 内では表示専用の合成 ID、選択解除時は `nil`。
        func selectNode(_ id: String?) {
            selectNodes(id.map { [$0] } ?? [], primaryID: id)
        }

        @MainActor
        /// 論理名（日本語）: WebView複数ノード選択関数
        /// 処理概要: Swift 側の選択 ID 群を JavaScript bridge 経由で DOM へ反映し、実測矩形を即時に取り込みます。
        ///
        /// - Parameters:
        ///   - ids: 選択する node ID 群。
        ///   - primaryID: Inspector / Canvas 操作用の主選択 ID。選択解除時は `nil`。
        func selectNodes(_ ids: [String], primaryID: String?) {
            guard let webView else { return }
            lastSelectedNodeID = primaryID
            lastSelectedNodeIDs = ids
            if primaryID == nil && ids.isEmpty {
                store.clearSelectionOverlayFrame(pageInternalID: pageInternalID)
            }
            let idsLiteral = Self.jsonLiteral(ids)
            let primaryIDLiteral = Self.javaScriptLiteral(primaryID ?? "")
            let script = """
            (function() {
              let didSelect = false;
              if (window.OpenGraphite && typeof window.OpenGraphite.selectNodes === 'function') {
                didSelect = !!window.OpenGraphite.selectNodes(\(idsLiteral), \(primaryIDLiteral));
              } else if (window.OpenGraphite && typeof window.OpenGraphite.selectNode === 'function') {
                didSelect = !!window.OpenGraphite.selectNode(\(primaryIDLiteral));
              }
              if (didSelect && typeof window.OpenGraphite.collectNodeDetails === 'function') {
                window.OpenGraphite.collectNodeDetails(\(primaryIDLiteral));
              }
              if (!didSelect || typeof window.OpenGraphite.selectionOverlayPayload !== 'function') {
                return null;
              }
              return window.OpenGraphite.selectionOverlayPayload();
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let payload = result as? [String: Any] else { return }
                Task { @MainActor [weak self] in
                    self?.ingestSelectionOverlayPayload(payload)
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: WebViewフォーカス対象反映関数
        /// 処理概要: 通常選択とは独立した node ID を JavaScript bridge へ送り、対象subtree以外のvisibilityをsession上で切り替えます。
        ///
        /// - Parameter ids: 単独表示する node ID 一覧。空配列では隔離表示を解除します。
        func setFocusedNodes(_ ids: [String]) {
            guard let webView else { return }
            focusedNodeIDs = ids
            lastFocusedNodeIDs = ids
            let idsLiteral = Self.jsonLiteral(ids)
            let script = """
            (function() {
              if (!window.OpenGraphite || typeof window.OpenGraphite.setFocusedNodes !== 'function') {
                return null;
              }
              window.OpenGraphite.setFocusedNodes(\(idsLiteral));
              if (\(idsLiteral).length !== 1 || typeof window.OpenGraphite.focusedNodeFrame !== 'function') {
                return null;
              }
              return window.OpenGraphite.focusedNodeFrame(\(idsLiteral)[0]);
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self else { return }
                let frame = Self.focusedNodeFrame(from: result)
                DispatchQueue.main.async {
                    self.onFocusedNodeFrame?(frame)
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: フォーカス対象矩形再計測関数
        /// 処理概要: DOMまたはCSS変更後の単一フォーカスnodeを再計測し、参照カードの実表示寸法へ反映します。
        private func refreshFocusedNodeFrame() {
            guard let webView,
                  focusedNodeIDs.count == 1,
                  let focusedNodeID = focusedNodeIDs.first
            else {
                onFocusedNodeFrame?(nil)
                return
            }
            let script = """
            window.OpenGraphite && typeof window.OpenGraphite.focusedNodeFrame === 'function'
              ? window.OpenGraphite.focusedNodeFrame(\(Self.javaScriptLiteral(focusedNodeID)))
              : null;
            """
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self else { return }
                let frame = Self.focusedNodeFrame(from: result)
                DispatchQueue.main.async {
                    self.onFocusedNodeFrame?(frame)
                }
            }
        }

        /// 論理名（日本語）: フォーカス対象矩形変換関数
        /// 処理概要: JavaScriptの有限な正寸法payloadだけをSwiftの`CGRect`へ変換します。
        ///
        /// - Parameter result: `evaluateJavaScript`が返した値。
        /// - Returns: 有効な対象矩形。不正または未解決時は`nil`。
        private static func focusedNodeFrame(from result: Any?) -> CGRect? {
            guard let payload = result as? [String: Any],
                  let x = payload["x"] as? Double,
                  let y = payload["y"] as? Double,
                  let width = payload["width"] as? Double,
                  let height = payload["height"] as? Double,
                  x.isFinite,
                  y.isFinite,
                  width.isFinite,
                  height.isFinite,
                  width > 0,
                  height > 0
            else {
                return nil
            }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        @MainActor
        /// 論理名（日本語）: アクティブツール反映関数
        /// 処理概要: SwiftUI 側のキャンバスツール状態を JavaScript bridge へ反映します。
        ///
        /// - Parameter tool: 現在選択されているキャンバスツール。
        func setActiveTool(_ tool: CanvasTool) {
            guard let webView else { return }
            lastActiveTool = tool
            (webView as? OpenGraphiteCommandWebView)?.setActiveToolRawValue(tool.rawValue)
            webView.evaluateJavaScript(
                "window.OpenGraphite && window.OpenGraphite.setActiveTool(\(Self.javaScriptLiteral(tool.rawValue)));"
            )
        }

        @MainActor
        /// 論理名（日本語）: CSS宣言mutation反映関数
        /// 処理概要: CSS declaration mutation を DOM へ適用し、成功時に HTML をディスクへ同期します。
        ///
        /// - Parameter mutation: 反映対象の CSS declaration mutation。
        func applyMutation(_ mutation: CSSVariableMutation) {
            guard let webView else { return }
            lastAppliedMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setCSSVariable(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.key)),
              \(Self.javaScriptLiteral(mutation.value))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("CSS宣言の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 複数CSS宣言mutation反映関数
        /// 処理概要: 複数 CSS declaration mutation を DOM へまとめて適用し、成功時に mutation を完了扱いにします。
        ///
        /// - Parameter mutation: 反映対象の複数 CSS declaration mutation。
        func applyVariablesMutation(_ mutation: CSSVariablesMutation) {
            guard let webView else { return }
            lastAppliedVariablesMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setCSSVariables(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.jsonLiteral(mutation.values))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("CSS宣言の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markVariablesMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 複数ノードCSS宣言mutation反映関数
        /// 処理概要: 同時選択ノード群の CSS declaration mutation を DOM へまとめて適用し、成功時に mutation を完了扱いにします。
        ///
        /// - Parameter mutation: 反映対象の複数ノード CSS declaration mutation。
        func applyVariablesBatchMutation(_ mutation: CSSVariablesBatchMutation) {
            guard let webView else { return }
            lastAppliedVariablesBatchMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setCSSVariablesBatch(
              \(Self.jsonLiteral(mutation.nodeValues))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("CSS宣言の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markVariablesBatchMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 属性mutation反映関数
        /// 処理概要: 標準HTML属性またはmetadata属性の空値設定と明示削除を区別してDOMへ適用し、成功時に保存済みmutationを完了扱いにします。
        ///
        /// - Parameter mutation: 反映対象の属性 mutation。
        func applyAttributeMutation(_ mutation: NodeAttributeMutation) {
            guard let webView else { return }
            lastAppliedAttributeMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setAttributeValue(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.name)),
              \(Self.javaScriptLiteral(mutation.value)),
              \(mutation.removesAttribute ? "true" : "false")
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("属性の反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markAttributeMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: テキストmutation反映関数
        /// 処理概要: Inspector で更新された text content を DOM へ適用し、成功時に mutation を完了扱いにします。
        ///
        /// - Parameter mutation: 反映対象の text mutation。
        func applyTextMutation(_ mutation: NodeTextContentMutation) {
            guard let webView else { return }
            lastAppliedTextMutationSequence = mutation.sequence

            let script = """
            window.OpenGraphite && window.OpenGraphite.setTextContent(
              \(Self.javaScriptLiteral(mutation.nodeID)),
              \(Self.javaScriptLiteral(mutation.value)),
              \(Self.javaScriptLiteral(mutation.mode.rawValue))
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("テキストの反映に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if (result as? Bool) == true {
                        self.store.markTextMutationApplied(sequence: mutation.sequence)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: ドキュメント置換適用関数
        /// 処理概要: undo/redo で選ばれた HTML スナップショットを DOM へ反映し、失敗時はディスクから再読み込みします。
        ///
        /// - Parameter request: WebView へ適用する HTML 置換要求。
        func applyDocumentReplacement(_ request: DocumentReplacementRequest) {
            guard let webView else { return }
            lastAppliedDocumentReplacementSequence = request.sequence
            hidePreviewUntilStyled()

            let script = """
            window.OpenGraphite && window.OpenGraphite.replaceDocumentHTML(
              \(Self.javaScriptLiteral(request.html)),
              \(Self.javaScriptLiteral(request.selectedNodeID ?? ""))
            );
            """

            webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました: \(error.localizedDescription)")
                        self.reloadCurrentPageFromDisk()
                    } else if (result as? Bool) != true {
                        self.store.reportWebError("履歴の WebView 反映に失敗しました。")
                        self.reloadCurrentPageFromDisk()
                    } else if let webView {
                        self.renderLocalComponentReferences(in: webView)
                        self.renderComponentPlacements(in: webView) { [weak self, weak webView] in
                            guard let self, let webView else { return }
                            self.finishPreviewLoad(in: webView)
                        }
                    }

                    self.store.markDocumentReplacementApplied(sequence: request.sequence)
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: HTMLシリアライズ同期関数
        /// 処理概要: DOM から編集用選択属性を除いた HTML を生成し、現在ページへ同期します。
        ///
        /// - Parameter onSuccess: 同期成功後に実行する処理。
        private func serializeAndSyncHTML(onSuccess: @escaping @MainActor () -> Void) {
            guard let webView, let target = syncTarget else { return }

            let script = """
            (function() {
              const focusController = window.OpenGraphiteFocusIsolation;
              const focusState = focusController && typeof focusController.suspend === 'function'
                ? focusController.suspend()
                : null;
              const editorController = window.OpenGraphite;
              const editorState = editorController && typeof editorController.suspendTransientStateForSerialization === 'function'
                ? editorController.suspendTransientStateForSerialization()
                : null;
              try {
              const editorStyleSelector = '#opengraphite-editor-selection-style,#opengraphite-editor-focus-style';
              function removeEditorStyles(root) {
                if (!root || typeof root.querySelectorAll !== 'function') { return; }
                root.querySelectorAll(editorStyleSelector).forEach((element) => {
                  element.remove();
                });
              }
              function restorePreviewDocumentAttributes(root) {
                if (!root || typeof root.removeAttribute !== 'function') { return; }
                const original = window.__OPENGRAPHITE_PREVIEW_DOCUMENT_ATTRIBUTES__;
                if (!original || typeof original !== 'object') { return; }
                if (original.hasLang === true) {
                  root.setAttribute('lang', typeof original.lang === 'string' ? original.lang : '');
                } else {
                  root.removeAttribute('lang');
                }
                if (original.hasDir === true) {
                  root.setAttribute('dir', typeof original.dir === 'string' ? original.dir : '');
                } else {
                  root.removeAttribute('dir');
                }
              }
              if (window.OpenGraphiteRuntime && typeof window.OpenGraphiteRuntime.serializeDocument === 'function') {
                const html = window.OpenGraphiteRuntime.serializeDocument();
                const parsedDocument = new DOMParser().parseFromString(html || '', 'text/html');
                removeEditorStyles(parsedDocument);
                if (!parsedDocument.documentElement) { return html; }
                restorePreviewDocumentAttributes(parsedDocument.documentElement);
                return '<!doctype html>\\n' + parsedDocument.documentElement.outerHTML;
              }
              const clone = document.documentElement.cloneNode(true);
              removeEditorStyles(clone);
              restorePreviewDocumentAttributes(clone);
              return '<!doctype html>\\n' + clone.outerHTML;
              } finally {
                if (editorController && typeof editorController.resumeTransientStateAfterSerialization === 'function') {
                  editorController.resumeTransientStateAfterSerialization(editorState);
                }
                if (focusController && typeof focusController.resume === 'function') {
                  focusController.resume(focusState);
                }
              }
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("HTMLのシリアライズに失敗しました: \(error.localizedDescription)")
                        return
                    }

                    if let html = result as? String {
                        if self.store.syncHTML(html, target: target) {
                            onSuccess()
                        } else {
                            self.reloadCurrentPageFromDisk()
                        }
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: 現在ページディスク再読み込み関数
        /// 処理概要: WebView 側 DOM 更新に失敗した場合、同期済みディスク内容を再読み込みして表示を戻します。
        private func reloadCurrentPageFromDisk() {
            guard let webView, let loadedURL else { return }
            let readAccessURL = store.projectRootURL ?? loadedURL.deletingLastPathComponent()
            hidePreviewUntilStyled()
            webView.loadFileURL(loadedURL, allowingReadAccessTo: readAccessURL)
        }

        /// 論理名（日本語）: JavaScript文字列リテラル生成関数
        /// 処理概要: Swift 文字列を JSON エンコードし、JavaScript へ安全に埋め込める文字列へ変換します。
        ///
        /// - Parameter string: JavaScript に渡す Swift 文字列。
        /// - Returns: JavaScript 文字列リテラル。
        private static func javaScriptLiteral(_ string: String) -> String {
            let data = (try? JSONEncoder().encode(string)) ?? Data("\"\"".utf8)
            return String(data: data, encoding: .utf8) ?? "\"\""
        }

        /// 論理名（日本語）: JavaScript object配列リテラル生成関数
        /// 処理概要: base URL付きHTML document payloadをJavaScriptへ安全に渡すJSON配列へ変換します。
        ///
        /// - Parameter values: JSON objectとして表現する文字列dictionary一覧。
        /// - Returns: JavaScriptで評価可能なJSON配列文字列。
        private static func javaScriptObjectArrayLiteral(_ values: [[String: String]]) -> String {
            let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }

        private static let previewReadinessMaximumAttempts = 120
        private static let previewReadinessRetryInterval: TimeInterval = 1.0 / 60.0
        static let previewReadinessScript = """
        (function() {
          return !!document.documentElement && !!document.body && document.readyState !== 'loading';
        })();
        """

        @MainActor
        /// 論理名（日本語）: スクロール状態更新関数
        /// 処理概要: JavaScript 由来のスクロール状態 payload を registry に保存します。
        ///
        /// - Parameter payload: WebView 内のスクロール可否 payload。
        private func updateScrollState(payload: [String: Any]) {
            guard let webView else { return }
            WebScrollStateRegistry.shared.update(WebScrollState(payload: payload), for: webView)
        }

        @MainActor
        /// 論理名（日本語）: コンテキストメニュー表示関数
        /// 処理概要: JavaScript から渡されたクリック位置と候補レイヤーをもとに編集メニューを表示します。
        ///
        /// - Parameter payload: 選択 ID、座標、候補レイヤーを含む payload。
        private func showContextMenu(payload: [String: Any]) {
            guard let webView else { return }

            let selectedID = payload["id"] as? String
            let selectedNode = selectedID.flatMap { id in store.nodes.first { $0.id == id } }
            let isPageNode = selectedNode?.capabilityEvidence.isProjectResourceRoot == true
            let hasHiddenAttribute = selectedNode?.hasHiddenAttribute == true
            let isLocked = selectedNode?.isLocked == true
            let hasCompleteCSSProvenance = selectedNode?.hasIncompleteCSSProvenance != true
            let hasStableEditTarget = selectedNode?.hasStableReference == true
            let canMutateSelection = hasStableEditTarget && !isPageNode && !isLocked
            let canSetLayout = hasStableEditTarget
                && selectedNode?.supports(.editLayout) == true
                && hasCompleteCSSProvenance
                && !isLocked
            let canReceiveChildren = selectedNode?.supports(.receiveChildren) == true
            let canReorder = canMutateSelection && selectedNode?.supports(.reorderFlow) == true
            let canGroup = canMutateSelection && selectedNode?.supports(.group) == true
            let canUngroup = canMutateSelection && selectedNode?.supports(.ungroup) == true
            let hasPasteContent = pasteboardPayload() != nil
            let hasCSSVariableContent = cssVariablesPasteboardPayload() != nil
            let focusFramePayload = payload["focusFrame"] as? [String: Any]
            let focusRect = focusFramePayload.flatMap { Self.focusedPreviewRect(from: $0) }
            contextMenuFocusTarget = selectedID.flatMap { id in focusRect.map { (id, $0) } }
            contextMenuFocusSegment = store.selectedDocumentSegment
            let menu = NSMenu(title: "OpenGraphite")
            menu.autoenablesItems = false

            if store.focusedPreviewTarget != nil {
                addMenuItem("フォーカス表示を解除", command: "endFocusedPreview", to: menu, enabled: true)
            } else {
                addMenuItem(
                    "フォーカス表示",
                    command: "focusPreview",
                    to: menu,
                    enabled: contextMenuFocusTarget != nil
                )
            }
            menu.addItem(.separator())

            addMenuItem("コピー", command: "copy", to: menu, enabled: selectedID != nil, keyEquivalent: "c", modifiers: [.command])
            addMenuItem("ここに貼り付け", command: "pasteHere", to: menu, enabled: hasStableEditTarget && canReceiveChildren && hasPasteContent)
            addMenuItem("貼り付けて置換", command: "pasteReplace", to: menu, enabled: canMutateSelection && hasPasteContent, keyEquivalent: "r", modifiers: [.command, .shift])

            let copyOptions = NSMenu(title: "コピー/貼り付けオプション")
            addMenuItem("参照IDをコピー", command: "copyReferenceID", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("HTMLとしてコピー", command: "copyHTML", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("テキストとしてコピー", command: "copyText", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("CSS宣言としてコピー", command: "copyCSSVariables", to: copyOptions, enabled: selectedID != nil)
            addMenuItem("HTMLをここに貼り付け", command: "pasteHere", to: copyOptions, enabled: hasStableEditTarget && canReceiveChildren && hasPasteContent)
            addMenuItem(
                "CSS宣言を貼り付け",
                command: "pasteCSSVariables",
                to: copyOptions,
                enabled: canMutateSelection && hasCompleteCSSProvenance && hasCSSVariableContent
            )
            let copyOptionsItem = NSMenuItem(title: "コピー/貼り付けオプション", action: nil, keyEquivalent: "")
            copyOptionsItem.submenu = copyOptions
            menu.addItem(copyOptionsItem)

            menu.addItem(.separator())

            if let candidates = layerCandidates(from: payload), !candidates.isEmpty {
                let layerMenu = NSMenu(title: "レイヤーを選択")
                for candidate in candidates {
                    let item = NSMenuItem(title: candidate.title, action: #selector(performContextMenuAction(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = "select:\(candidate.id)"
                    item.state = candidate.id == selectedID ? .on : .off
                    layerMenu.addItem(item)
                }

                let layerItem = NSMenuItem(title: "レイヤーを選択", action: nil, keyEquivalent: "")
                layerItem.submenu = layerMenu
                menu.addItem(layerItem)
            }

            addMenuItem("最前面へ移動", command: "moveFront", to: menu, enabled: canReorder, keyEquivalent: "]")
            addMenuItem("最背面へ移動", command: "moveBack", to: menu, enabled: canReorder, keyEquivalent: "[")

            menu.addItem(.separator())

            addMenuItem("選択範囲のフレーム化", command: "wrapFrame", to: menu, enabled: canGroup, keyEquivalent: "g", modifiers: [.command, .option])
            addMenuItem("グループ解除", command: "ungroup", to: menu, enabled: canUngroup, keyEquivalent: "\u{8}", modifiers: [.command])

            menu.addItem(.separator())

            addMenuItem("オートレイアウトを追加", command: "layoutVertical", to: menu, enabled: canSetLayout, keyEquivalent: "a", modifiers: [.shift])

            let layoutMenu = NSMenu(title: "その他のレイアウトオプション")
            addMenuItem("縦方向レイアウト", command: "layoutVertical", to: layoutMenu, enabled: canSetLayout)
            addMenuItem("横方向レイアウト", command: "layoutHorizontal", to: layoutMenu, enabled: canSetLayout)
            addMenuItem("グリッドレイアウト", command: "layoutGrid", to: layoutMenu, enabled: canSetLayout)
            addMenuItem("標準フロー", command: "layoutBlock", to: layoutMenu, enabled: canSetLayout)
            let layoutItem = NSMenuItem(title: "その他のレイアウトオプション", action: nil, keyEquivalent: "")
            layoutItem.submenu = layoutMenu
            menu.addItem(layoutItem)

            menu.addItem(.separator())

            addMenuItem(hasHiddenAttribute ? "hidden属性を解除" : "hidden属性を追加", command: "toggleHidden", to: menu, enabled: canMutateSelection, keyEquivalent: "h", modifiers: [.command, .shift])
            addMenuItem(isLocked ? "ロック解除" : "ロック", command: "toggleLocked", to: menu, enabled: hasStableEditTarget && !isPageNode, keyEquivalent: "l", modifiers: [.command, .shift])
            addMenuItem("左右反転", command: "flipHorizontal", to: menu, enabled: canMutateSelection && hasCompleteCSSProvenance, keyEquivalent: "h", modifiers: [.shift])
            addMenuItem("上下反転", command: "flipVertical", to: menu, enabled: canMutateSelection && hasCompleteCSSProvenance, keyEquivalent: "v", modifiers: [.shift])

            menu.addItem(.separator())

            addMenuItem("削除", command: "delete", to: menu, enabled: canMutateSelection, keyEquivalent: "\u{8}")

            let x = payload["x"] as? Double ?? Double(webView.bounds.midX)
            let y = payload["y"] as? Double ?? Double(webView.bounds.midY)
            let point = NSPoint(x: x, y: y)
            DispatchQueue.main.async { [weak webView] in
                guard let webView else { return }
                menu.popUp(positioning: nil, at: point, in: webView)
            }
        }

        /// 論理名（日本語）: 標準レイアウト編集可否判定関数
        /// 処理概要: legacy typeやlayout annotationを参照せず、operation別capabilityからlayout menuの可否を決めます。
        ///
        /// - Parameter node: Context menu対象のinspection node。
        /// - Returns: 標準`display` / flex / grid declarationを編集できる場合は`true`。
        private static func canSetStandardLayout(on node: OpenGraphiteNode) -> Bool {
            node.supports(.editLayout)
        }

        /// 論理名（日本語）: フォーカス表示矩形変換関数
        /// 処理概要: JavaScript context menu payload の document 座標矩形を検証し、有限な正寸法の `CGRect` へ変換します。
        ///
        /// - Parameter payload: `x`、`y`、`width`、`height` を含む辞書。
        /// - Returns: 有効な object 矩形。不正値では `nil`。
        private static func focusedPreviewRect(from payload: [String: Any]) -> CGRect? {
            guard let x = payload["x"] as? Double,
                  let y = payload["y"] as? Double,
                  let width = payload["width"] as? Double,
                  let height = payload["height"] as? Double,
                  x.isFinite,
                  y.isFinite,
                  width.isFinite,
                  height.isFinite,
                  width > 0,
                  height > 0
            else {
                return nil
            }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        /// 論理名（日本語）: メニュー項目追加関数
        /// 処理概要: context menu に実行コマンド付きの `NSMenuItem` を追加します。
        ///
        /// - Parameters:
        ///   - title: 表示タイトル。
        ///   - command: 実行する OpenGraphite コマンド。
        ///   - menu: 追加先メニュー。
        ///   - enabled: 項目を有効にするか。
        ///   - keyEquivalent: キーボードショートカット文字。
        ///   - modifiers: キーボードショートカットの修飾キー。
        private func addMenuItem(
            _ title: String,
            command: String,
            to menu: NSMenu,
            enabled: Bool,
            keyEquivalent: String = "",
            modifiers: NSEvent.ModifierFlags = []
        ) {
            let item = NSMenuItem(title: title, action: #selector(performContextMenuAction(_:)), keyEquivalent: keyEquivalent)
            item.target = self
            item.representedObject = command
            item.isEnabled = enabled
            item.keyEquivalentModifierMask = modifiers
            menu.addItem(item)
        }

        /// 論理名（日本語）: コンテキストメニューアクション実行関数
        /// 処理概要: `NSMenuItem` に保持されたコマンド文字列を取得し、メインアクター上で処理します。
        ///
        /// - Parameter sender: 選択されたメニュー項目。
        @objc private func performContextMenuAction(_ sender: NSMenuItem) {
            guard let command = sender.representedObject as? String else { return }
            Task { @MainActor in
                handleContextMenuAction(command)
            }
        }

        @MainActor
        /// 論理名（日本語）: コンテキストメニューコマンド処理関数
        /// 処理概要: コピー、貼り付け、レイアウト変更、表示状態変更などのメニューコマンドを実行します。
        ///
        /// - Parameter command: 実行するコマンド名。
        private func handleContextMenuAction(_ command: String) {
            if command.hasPrefix("select:") {
                let id = String(command.dropFirst("select:".count))
                store.selectNode(id: id)
                selectNode(id)
                return
            }

            switch command {
            case "focusPreview":
                guard let target = contextMenuFocusTarget,
                      let segment = contextMenuFocusSegment,
                      let pageInternalID
                else {
                    return
                }
                store.beginFocusedPreview(
                    nodeID: target.nodeID,
                    pageInternalID: pageInternalID,
                    segment: segment,
                    rect: target.rect
                )
            case "endFocusedPreview":
                store.endFocusedPreview()
            case "copy", "copyHTML":
                copySelection(includeHTML: true, includeText: command == "copyHTML", includeReferenceID: command == "copy")
            case "copyReferenceID":
                copySelection(includeHTML: true, includeText: false, includeReferenceID: true)
            case "copyText":
                copySelection(includeHTML: false, includeText: true)
            case "copyCSSVariables":
                copySelection(includeHTML: false, includeText: false, includeCSSVariables: true)
            case "pasteHere", "pasteReplace":
                guard let payload = pasteboardPayload() else { return }
                performDOMCommand(command, payload: payload)
            case "pasteCSSVariables":
                guard let payload = cssVariablesPasteboardPayload() else { return }
                performDOMCommand(command, payload: payload)
            case "layoutVertical":
                performDOMCommand("setLayout", payload: ["layout": "vertical"])
            case "layoutHorizontal":
                performDOMCommand("setLayout", payload: ["layout": "horizontal"])
            case "layoutGrid":
                performDOMCommand("setLayout", payload: ["layout": "grid"])
            case "layoutBlock":
                performDOMCommand("setLayout", payload: ["layout": "block"])
            case "flipHorizontal", "flipVertical":
                let authoredScale = store.selectedNode?.cssVariables["scale"]
                performDOMCommand(
                    command,
                    payload: [
                        "hasAuthoredScale": authoredScale == nil ? "false" : "true",
                        "authoredScale": authoredScale ?? ""
                    ]
                )
            default:
                performDOMCommand(command, payload: [:])
            }
        }

        @MainActor
        /// 論理名（日本語）: コマンドコピー処理関数
        /// 処理概要: `⌘C` や responder chain の `copy:` から通常コピーと同じ参照 ID 付き payload を作ります。
        /// 選択 node がない場合は選択 HTML カードの参照 ID をコピーします。
        ///
        /// - Returns: OpenGraphite の選択対象コピーとして処理できた場合は `true`。
        func copySelectionForCommand() -> Bool {
            guard isInteractive else { return false }
            guard store.selectedNodeID != nil else {
                return store.copySelectedReferenceIDToPasteboard()
            }
            copySelection(includeHTML: true, includeText: false, includeReferenceID: true)
            return true
        }

        @MainActor
        /// 論理名（日本語）: 選択内容コピー関数
        /// 処理概要: 選択中 DOM の HTML、テキスト、参照 ID、CSS declaration を pasteboard へ書き込みます。
        ///
        /// - Parameters:
        ///   - includeHTML: HTML をコピー対象に含めるか。
        ///   - includeText: テキストをコピー対象に含めるか。
        ///   - includeReferenceID: テキスト欄貼り付け用に複合参照 ID をコピー対象に含めるか。
        ///   - includeCSSVariables: CSS declaration をコピー対象に含めるか。
        private func copySelection(
            includeHTML: Bool,
            includeText: Bool,
            includeReferenceID: Bool = false,
            includeCSSVariables: Bool = false
        ) {
            guard let webView else { return }

            webView.evaluateJavaScript("window.OpenGraphite && window.OpenGraphite.copyPayload();") { result, error in
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("コピーに失敗しました: \(error.localizedDescription)")
                        return
                    }

                    guard let payload = result as? [String: Any] else { return }
                    let html = payload["html"] as? String ?? ""
                    let text = payload["text"] as? String ?? ""
                    let nodeID = payload["id"] as? String ?? ""
                    let nodeInternalID = payload["internalID"] as? String ?? ""
                    let cssVariables = (payload["cssVariables"] as? [String: Any] ?? [:])
                        .compactMapValues { $0 as? String }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let referenceID = includeReferenceID
                        ? self.store.nodeReferenceID(forNodeID: nodeID, nodeInternalID: nodeInternalID)
                        : nil

                    if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: Self.htmlPasteboardType)
                    }

                    if let referenceID, !referenceID.isEmpty {
                        pasteboard.setString(referenceID, forType: .string)
                    } else if includeText, !text.isEmpty {
                        pasteboard.setString(text, forType: .string)
                    } else if includeHTML, !html.isEmpty {
                        pasteboard.setString(html, forType: .string)
                    }

                    if includeReferenceID,
                       let referencePayload = self.store.nodeReferencePasteboardPayload(
                        forNodeID: nodeID,
                        nodeInternalID: nodeInternalID,
                        html: html
                       ),
                       let data = try? JSONSerialization.data(withJSONObject: referencePayload),
                       let json = String(data: data, encoding: .utf8) {
                        pasteboard.setString(json, forType: Self.nodeReferencePasteboardType)
                    }

                    if includeCSSVariables, !cssVariables.isEmpty,
                       let data = try? JSONSerialization.data(withJSONObject: cssVariables),
                       let json = String(data: data, encoding: .utf8) {
                        pasteboard.setString(json, forType: Self.cssVariablesPasteboardType)
                    }
                }
            }
        }

        @MainActor
        /// 論理名（日本語）: DOMコマンド実行関数
        /// 処理概要: JavaScript bridge の `runCommand` を呼び出し、成功時に HTML をディスクへ同期します。
        ///
        /// - Parameters:
        ///   - command: DOM に対して実行するコマンド名。
        ///   - payload: コマンドに渡す文字列 payload。
        private func performDOMCommand(_ command: String, payload: [String: String]) {
            guard let webView else { return }
            let payloadLiteral = Self.jsonLiteral(payload)
            let script = """
            window.OpenGraphite && window.OpenGraphite.runCommand(
              \(Self.javaScriptLiteral(command)),
              \(payloadLiteral)
            );
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.store.reportWebError("コンテキストメニュー操作に失敗しました: \(error.localizedDescription)")
                        return
                    }

                    guard let response = result as? [String: Any],
                          (response["success"] as? Bool) == true
                    else {
                        return
                    }

                    guard let target = self.syncTarget,
                          let editPayload = response["edit"] as? [String: Any]
                    else {
                        self.store.reportWebError("HTMLの保存形式が不正です。ページを再読み込みしてからもう一度設定してください。")
                        self.reloadCurrentPageFromDisk()
                        return
                    }

                    let editResult = self.store.applyHTMLObjectEditPayload(editPayload, target: target)
                    guard editResult.updated else {
                        self.reloadCurrentPageFromDisk()
                        return
                    }

                    if let selectedID = response["selectedID"] as? String, !selectedID.isEmpty {
                        self.store.selectNode(id: selectedID)
                    }

                    if editResult.requiresReload {
                        self.reloadCurrentPageFromDisk()
                    } else {
                        self.collectNodes()
                    }
                }
            }
        }

        /// 論理名（日本語）: pasteboard payload取得関数
        /// 処理概要: pasteboard から HTML またはテキストを読み取り、DOM コマンド用 payload に変換します。
        ///
        /// - Returns: 貼り付け可能な payload。空の場合は `nil`。
        private func pasteboardPayload() -> [String: String]? {
            let pasteboard = NSPasteboard.general
            if let json = pasteboard.string(forType: Self.nodeReferencePasteboardType),
               let data = json.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let html = object["html"] as? String,
               !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["html": html]
            }

            if let html = pasteboard.string(forType: Self.htmlPasteboardType),
               !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["html": html]
            }

            if let string = pasteboard.string(forType: .string),
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ["text": string]
            }

            return nil
        }

        /// 論理名（日本語）: CSS宣言pasteboard payload取得関数
        /// 処理概要: pasteboard から OpenGraphite 専用形式の CSS 宣言 JSON を読み取ります。
        ///
        /// - Returns: OpenGraphite 編集対象 CSS 宣言だけを含む payload。空の場合は `nil`。
        private func cssVariablesPasteboardPayload() -> [String: String]? {
            let pasteboard = NSPasteboard.general
            guard let json = pasteboard.string(forType: Self.cssVariablesPasteboardType),
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            else {
                return nil
            }

            let variables = object.filter { key, value in
                Self.isOpenGraphiteStyleKey(key) && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return variables.isEmpty ? nil : variables
        }

        /// 論理名（日本語）: OpenGraphite CSS宣言キー判定関数
        /// 処理概要: pasteboard の CSS 宣言が OpenGraphite の編集対象かどうかを判定します。
        ///
        /// - Parameter key: CSS property または custom property 名。
        /// - Returns: 編集対象であれば `true`。
        private static func isOpenGraphiteStyleKey(_ key: String) -> Bool {
            let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
            return openGraphiteStyleKeys.contains(normalized)
        }

        /// 論理名（日本語）: レイヤー候補
        /// 概要: 右クリック位置の DOM 祖先から選択候補として表示するレイヤー情報です。
        ///
        /// プロパティ:
        /// - `id`: annotation有無に応じたWebCanvas session内の選択キー。
        /// - `title`: メニューに表示するタイトル。
        private struct LayerCandidate {
            var id: String
            var title: String
        }

        /// 論理名（日本語）: レイヤー候補変換関数
        /// 処理概要: JavaScript payload の候補配列を context menu 表示用モデルへ変換します。
        ///
        /// - Parameter payload: JavaScript から渡された context menu payload。
        /// - Returns: レイヤー候補一覧。候補がない場合は `nil`。
        private func layerCandidates(from payload: [String: Any]) -> [LayerCandidate]? {
            guard let rawCandidates = payload["candidates"] as? [[String: Any]] else { return nil }
            return rawCandidates.compactMap { candidate -> LayerCandidate? in
                guard let id = candidate["id"] as? String, !id.isEmpty else { return nil }
                let tagName = candidate["tagName"] as? String ?? id
                let capabilities = Self.stringArray(candidate["capabilities"])
                let detail = [capabilities.isEmpty ? nil : capabilities.joined(separator: ", "), candidate["role"] as? String]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                let title = detail.isEmpty ? tagName : "\(tagName)  \(detail)"
                return LayerCandidate(id: id, title: title)
            }
        }

        /// 論理名（日本語）: JavaScript文字列配列変換関数
        /// 処理概要: WebKit message payloadのNSArray表現から文字列要素だけを順序維持で取得します。
        ///
        /// - Parameter value: JavaScript由来の配列値。
        /// - Returns: 文字列要素一覧。非配列では空配列。
        private static func stringArray(_ value: Any?) -> [String] {
            if let values = value as? [String] { return values }
            return (value as? [Any] ?? []).compactMap { $0 as? String }
        }

        /// 論理名（日本語）: JavaScript JSONリテラル生成関数
        /// 処理概要: Swift の JSON 化可能な値を文字列化し、JavaScript へ安全に渡せるリテラルへ変換します。
        ///
        /// - Parameter value: JavaScript に渡す JSON 化可能な値。
        /// - Returns: JavaScript リテラルとして利用できる JSON 文字列。
        private static func jsonLiteral(_ value: Any) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: value)) ?? Data("null".utf8)
            return String(data: data, encoding: .utf8) ?? "null"
        }
    }

    /// 論理名（日本語）: WebCanvas編集bridge script
    /// 概要: Canvas node収集、選択、編集と、media / SVG / mask 描画実体のcomputed style収集をWebViewへ導入します。
    static let bridgeScript = """
    \(WebCanvasFocusIsolationScript.source)
    (function() {
        if (window.OpenGraphite) {
          if (typeof window.OpenGraphite.installEditorSelectionStyle === 'function') {
            window.OpenGraphite.installEditorSelectionStyle();
          }
          if (typeof window.OpenGraphite.collectLayerNodes === 'function') {
            window.OpenGraphite.collectLayerNodes();
          } else {
            window.OpenGraphite.collectNodes();
          }
          return;
        }

        let currentSelectedID = '';
        let dragStartThreshold = 3;
        let pointerDragButtons = 1;
        let primaryPointerButton = 0;
        let selectionRevealPadding = 24;
        let passivePointerOptions = { capture: true, passive: true };
        let activePointerOptions = { capture: true, passive: false };
        var activeTool = 'select';
        var pendingDrag = null;
        var activeDrag = null;
        var pendingFramePlacement = null;
        var framePlacement = null;
        var selectionOverlay = null;
        var pendingNodeCollectionTimer = 0;
        const observedMediaQueries = new Map();
        var selectionOverlayFrame = null;
        var selectionOverlayUpdateTimer = null;
        var lastSelectionOverlayUpdateTime = 0;
        var editingTextElement = null;
        var editingOriginalText = '';
        var editingPresentationState = null;
        var suppressNextClick = false;
        var clickSequenceStartSelectedID = '';
        var currentSelectedIDs = new Set();
        var focusedNodeIDs = [];
        var nodeCollectionContext = null;
        const frameGuideAnimations = new Map();
        const reorderAnimations = new WeakMap();
        let minimumFramePlacementSize = 2;

        function installEditorSelectionStyle() {
          return true;
        }

      const openGraphiteStyleKeys = new Set([
        'width',
        'height',
        'min-width',
        'min-height',
        'max-width',
        'display',
        'flex-direction',
        'grid-template-columns',
        'grid-template-rows',
        'grid-auto-flow',
        'flex',
        'margin',
        'padding',
        'gap',
        'align-items',
        'justify-content',
        'position',
        'left',
        'top',
        'right',
        'bottom',
        'z-index',
        'visibility',
        'overflow-wrap',
        'color',
        'background',
        'border',
        'border-radius',
        'box-shadow',
        'font-family',
        'font-size',
        'font-weight',
        'line-height',
        'letter-spacing',
        'text-align',
        'animation',
        'animation-name',
        'animation-duration',
        'animation-delay',
        'animation-timing-function',
        'animation-iteration-count',
        'animation-direction',
        'animation-fill-mode',
        'animation-play-state',
        'animation-timeline',
        'animation-range',
        'animation-range-start',
        'animation-range-end',
        'timeline-scope',
        'scroll-timeline',
        'scroll-timeline-name',
        'scroll-timeline-axis',
        'view-timeline',
        'view-timeline-name',
        'view-timeline-axis',
        'view-timeline-inset',
        'transform-origin',
        'object-fit',
        'stroke-width',
        'mask-image',
        '-webkit-mask-image',
        'scale'
      ]);

      function isOpenGraphiteStyleKey(key) {
        return openGraphiteStyleKeys.has(key);
      }

      function cssVariables(element) {
        const variables = {};
        const style = element.style;
        for (let index = 0; index < style.length; index += 1) {
          const key = String(style.item(index) || '').trim();
          const value = String(style.getPropertyValue(key) || '').trim();
          if (isOpenGraphiteStyleKey(key) && value.length > 0) {
            variables[key] = value;
          }
        }
        return variables;
      }

      function computedStylePayload(element) {
        if (nodeCollectionContext && nodeCollectionContext.computedStyles.has(element)) {
          return nodeCollectionContext.computedStyles.get(element);
        }
        let payload;
        try {
          const style = window.getComputedStyle(element);
          payload = {
            display: String(style.display || '').trim(),
            flexDirection: String(style.flexDirection || '').trim(),
            gridTemplateColumns: String(style.gridTemplateColumns || '').trim(),
            gridTemplateRows: String(style.gridTemplateRows || '').trim(),
            gridAutoFlow: String(style.gridAutoFlow || '').trim(),
            position: String(style.position || '').trim(),
            visibility: String(style.visibility || '').trim(),
            contentVisibility: String(style.contentVisibility || '').trim(),
            overflowWrap: String(style.overflowWrap || style.wordWrap || '').trim(),
            alignItems: String(style.alignItems || '').trim(),
            justifyContent: String(style.justifyContent || '').trim()
          };
        } catch (_) {
          payload = {
            display: '', flexDirection: '', gridTemplateColumns: '', gridTemplateRows: '',
            gridAutoFlow: '', position: '', visibility: '', contentVisibility: '', overflowWrap: '',
            alignItems: '', justifyContent: ''
          };
        }
        if (nodeCollectionContext) {
          nodeCollectionContext.computedStyles.set(element, payload);
        }
        return payload;
      }

      function layoutModeForComputedStyle(style) {
        const display = String(style && style.display || '').trim().toLowerCase();
        if (display === 'flex' || display === 'inline-flex') {
          const direction = String(style && style.flexDirection || '').trim().toLowerCase();
          return direction.startsWith('row') ? 'horizontal' : 'vertical';
        }
        if (display === 'grid' || display === 'inline-grid') { return 'grid'; }
        return display;
      }

      function isHiddenByComputedStyle(element) {
        const ownStyle = computedStylePayload(element);
        const ownVisibility = ownStyle.visibility.toLowerCase();
        if (ownVisibility === 'hidden' || ownVisibility === 'collapse') { return true; }
        let candidate = element;
        while (candidate && candidate.nodeType === Node.ELEMENT_NODE) {
          const style = computedStylePayload(candidate);
          const display = style.display.toLowerCase();
          if (display === 'none') { return true; }
          if (style.contentVisibility.toLowerCase() === 'hidden') { return true; }
          candidate = composedParentElement(candidate);
        }
        return false;
      }

      const genericFlowContainerTags = new Set([
        'address', 'article', 'aside', 'blockquote', 'body', 'caption', 'dd', 'details', 'dialog',
        'div', 'dt', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'header',
        'li', 'main', 'nav', 'search', 'section', 'td', 'th'
      ]);
      const standardHTMLTags = new Set([
        'a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdi', 'bdo',
        'blockquote', 'body', 'br', 'button', 'canvas', 'caption', 'cite', 'code', 'col', 'colgroup',
        'data', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt', 'em', 'embed',
        'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'head', 'header', 'hgroup', 'hr', 'html', 'i', 'iframe', 'img', 'input', 'ins', 'kbd',
        'label', 'legend', 'li', 'link', 'main', 'map', 'mark', 'menu', 'meta', 'meter', 'nav',
        'noscript', 'object', 'ol', 'optgroup', 'option', 'output', 'p', 'picture', 'pre', 'progress',
        'q', 'rp', 'rt', 'ruby', 's', 'samp', 'script', 'search', 'section', 'select', 'slot', 'small',
        'source', 'span', 'strong', 'style', 'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'template',
        'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video',
        'wbr', 'acronym', 'applet', 'basefont', 'bgsound', 'big', 'center', 'dir', 'font', 'frame',
        'frameset', 'keygen', 'marquee', 'noembed', 'noframes', 'param', 'plaintext', 'strike', 'tt', 'xmp'
      ]);

      function canReceiveChildren(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) { return false; }
        if (element.namespaceURI !== 'http://www.w3.org/1999/xhtml') { return false; }
        const tagName = element.tagName.toLowerCase();
        return genericFlowContainerTags.has(tagName) || isValidCustomElementName(tagName) ||
          (!standardHTMLTags.has(tagName) && typeof HTMLUnknownElement !== 'undefined' &&
            element instanceof HTMLUnknownElement);
      }

      function isValidCustomElementName(value) {
        return /^[a-z][a-z0-9._-]*-[a-z0-9._-]+$/.test(String(value || ''));
      }

      function canReorderFlowChild(element, parent) {
        if (!element || !parent) { return false; }
        if (canReceiveChildren(parent)) { return true; }
        const childTag = element.tagName.toLowerCase();
        const parentTag = parent.tagName.toLowerCase();
        if ((parentTag === 'ul' || parentTag === 'ol' || parentTag === 'menu') &&
            childTag === 'li') { return true; }
        if ((parentTag === 'thead' || parentTag === 'tbody' || parentTag === 'tfoot') &&
            childTag === 'tr') { return true; }
        if (parentTag === 'tr' && (childTag === 'td' || childTag === 'th')) { return true; }
        if (parentTag === 'optgroup' && childTag === 'option') { return true; }
        return parentTag === 'colgroup' && childTag === 'col';
      }

      const nativeControlTags = new Set([
        'button', 'input', 'select', 'textarea', 'option', 'optgroup', 'fieldset',
        'details', 'summary', 'dialog', 'meter', 'progress', 'output'
      ]);
      const interactiveARIARoles = new Set([
        'button', 'checkbox', 'combobox', 'gridcell', 'listbox', 'menuitem',
        'menuitemcheckbox', 'menuitemradio', 'option', 'radio', 'scrollbar', 'searchbox',
        'slider', 'spinbutton', 'switch', 'tab', 'textbox', 'treeitem'
      ]);
      const recognizedARIARoles = new Set([
        'alert', 'alertdialog', 'application', 'article', 'banner', 'blockquote', 'button',
        'caption', 'cell', 'checkbox', 'code', 'columnheader', 'combobox', 'complementary',
        'contentinfo', 'definition', 'deletion', 'dialog', 'directory', 'document', 'emphasis',
        'feed', 'figure', 'form', 'generic', 'grid', 'gridcell', 'group', 'heading', 'img',
        'insertion', 'link', 'list', 'listbox', 'listitem', 'log', 'main', 'marquee', 'math',
        'menu', 'menubar', 'menuitem', 'menuitemcheckbox', 'menuitemradio', 'meter',
        'navigation', 'none', 'note', 'option', 'paragraph', 'presentation', 'progressbar',
        'radio', 'radiogroup', 'region', 'row', 'rowgroup', 'rowheader', 'scrollbar', 'search',
        'searchbox', 'separator', 'slider', 'spinbutton', 'status', 'strong', 'subscript',
        'suggestion', 'superscript', 'switch', 'tab', 'table', 'tablist', 'tabpanel', 'term', 'textbox',
        'time', 'timer', 'toolbar', 'tooltip', 'tree', 'treegrid', 'treeitem'
      ]);
      const textSemanticTags = new Set([
        'abbr', 'address', 'b', 'bdi', 'bdo', 'blockquote', 'button', 'caption', 'cite',
        'code', 'dd', 'del', 'dfn', 'dt', 'em', 'figcaption', 'h1', 'h2', 'h3', 'h4',
        'h5', 'h6', 'i', 'ins', 'kbd', 'label', 'legend', 'li', 'mark', 'option', 'p',
        'pre', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'small', 'span', 'strong', 'sub',
        'summary', 'sup', 'td', 'th', 'time', 'u', 'var'
      ]);
      const domTextEditingExcludedTags = new Set(['input', 'optgroup', 'select', 'textarea']);
      const mediaTags = new Set([
        'audio', 'canvas', 'embed', 'iframe', 'img', 'object', 'picture', 'source', 'track', 'video'
      ]);
      const svgTags = new Set([
        'svg', 'g', 'path', 'circle', 'ellipse', 'line', 'polyline', 'polygon', 'rect', 'use',
        'defs', 'symbol', 'mask', 'clippath', 'lineargradient', 'radialgradient', 'stop',
        'text', 'tspan', 'foreignobject'
      ]);
      const safelyUngroupableTags = new Set([
        'div', 'span', 'section', 'article', 'main', 'aside', 'header', 'footer', 'nav',
        'figure', 'figcaption'
      ]);
      const nonOperationalTags = new Set([
        'base', 'basefont', 'bgsound', 'head', 'html', 'link', 'meta', 'noframes',
        'noembed', 'noscript', 'script', 'style', 'template', 'title', 'xmp', 'plaintext'
      ]);
      const nonTextEditableTags = new Set([
        'base', 'head', 'html', 'link', 'meta', 'noembed', 'noframes', 'noscript',
        'script', 'style', 'template', 'xmp', 'plaintext'
      ]);

      function directAuthoredTextPresent(element) {
        if (!element) { return false; }
        return Array.from(element.childNodes).some((node) => {
          return node.nodeType === Node.TEXT_NODE && String(node.textContent || '').trim().length > 0;
        });
      }

      function isEffectivelyContentEditable(element) {
        let candidate = element;
        while (candidate && candidate.nodeType === Node.ELEMENT_NODE) {
          if (candidate.hasAttribute('contenteditable')) {
            const value = String(candidate.getAttribute('contenteditable') || '')
              .trim()
              .toLowerCase();
            if (value === '' || value === 'true' || value === 'plaintext-only') { return true; }
            if (value === 'false') { return false; }
          }
          candidate = candidate.parentElement;
        }
        return false;
      }

      function firstRecognizedARIARole(element) {
        if (!element) { return ''; }
        const tokens = String(element.getAttribute('role') || '')
          .trim()
          .toLowerCase()
          .split(/\\s+/)
          .filter((token) => token.length > 0);
        return tokens.find((token) => recognizedARIARoles.has(token)) || '';
      }

      function elementOrDescendantMatches(element, selector) {
        if (!element || typeof element.matches !== 'function') { return false; }
        try {
          return element.matches(selector) || !!element.querySelector(selector);
        } catch (_) {
          return false;
        }
      }

      function authoredResourceRootElement() {
        if (!document.body) { return null; }
        const authoredTopLevel = Array.from(document.body.children).filter((element) => {
          return isInspectableElement(element) && !isPlacementGeneratedElement(element) && !isRuntimeGeneratedNode(element);
        });
        return authoredTopLevel.length === 1 ? authoredTopLevel[0] : null;
      }

      function isProtectedResourceTopLevel(element) {
        return !!element && (element === document.body || element.parentElement === document.body);
      }

      function capabilityEvidenceForElement(element) {
        const tagName = element ? element.tagName.toLowerCase() : '';
        const ariaRole = firstRecognizedARIARole(element);
        const computed = computedStylePayload(element);
        const hasMaskContent = !!element && maskRenderElements(element).length > 0;
        return {
          isProjectResourceRoot: !!element && authoredResourceRootElement() === element,
          isNativeControl: nativeControlTags.has(tagName),
          isCustomElement: isValidCustomElementName(tagName) ||
            isValidCustomElementName(element.getAttribute('is')),
          isLink: ((tagName === 'a' || tagName === 'area') && element.hasAttribute('href')) || ariaRole === 'link',
          hasDirectText: directAuthoredTextPresent(element),
          hasElementChildren: !!element && element.children.length > 0,
          hasMediaContent: mediaTags.has(tagName) || elementOrDescendantMatches(element, 'audio, canvas, embed, iframe, img, object, picture, source, track, video'),
          hasSVGContent: svgTags.has(tagName) || elementOrDescendantMatches(
            element,
            'svg, g, path, circle, ellipse, line, polyline, polygon, rect, use, defs, symbol, mask, clipPath, linearGradient, radialGradient, stop, text, tspan, foreignObject'
          ),
          hasMaskContent: hasMaskContent,
          ariaRole: ariaRole || null,
          resolvedDisplay: computed.display || null
        };
      }

      function capabilitiesForElement(element, evidence) {
        if (!element) { return []; }
        const facts = evidence || capabilityEvidenceForElement(element);
        const tagName = element.tagName.toLowerCase();
        const capabilities = new Set();
        const canContain = canReceiveChildren(element);
        const isOperational = !nonOperationalTags.has(tagName);
        const isProtectedTopLevel = isProtectedResourceTopLevel(element);
        const position = computedPosition(element);
        const display = String(facts.resolvedDisplay || '').trim().toLowerCase();
        const role = String(facts.ariaRole || '').trim().toLowerCase();
        const hasIconProvenance = [
          'data-og-icon-library', 'data-og-icon-name', 'data-og-icon-source'
        ].some((attributeName) => element.hasAttribute(attributeName));

        if (canContain) { capabilities.add('receive-children'); }
        const hasSafeTextShape = facts.hasDirectText || textSemanticTags.has(tagName) ||
          isEffectivelyContentEditable(element) || role === 'textbox';
        if (!nonTextEditableTags.has(tagName) &&
            !domTextEditingExcludedTags.has(tagName) && hasSafeTextShape) {
          capabilities.add('edit-text');
        }
        const hasHrefAttribute = element.hasAttribute('href');
        const isNativeHyperlink = tagName === 'a' || tagName === 'area';
        if (hasHrefAttribute && (isNativeHyperlink || role === 'link')) {
          capabilities.add('edit-link');
        }
        if (facts.hasMediaContent) { capabilities.add('edit-media'); }
        if (facts.hasSVGContent || facts.hasMaskContent || hasIconProvenance) {
          capabilities.add('edit-icon');
        }
        if (facts.isNativeControl || interactiveARIARoles.has(role) ||
            (role === 'link' && !hasHrefAttribute)) {
          capabilities.add('edit-control');
        }
        if (isOperational) { capabilities.add('edit-layout'); }

        if (isOperational && !isProtectedTopLevel && (position === 'absolute' || position === 'fixed')) {
          capabilities.add('drag-position');
        }
        const parent = element.parentElement;
        const parentDisplay = parent
          ? String(computedStylePayload(parent).display || '').trim().toLowerCase()
          : '';
        if (isOperational && !isProtectedTopLevel && parent && canReorderFlowChild(element, parent) &&
            position !== 'absolute' && position !== 'fixed' &&
            parentDisplay !== 'none' && parentDisplay !== 'contents' &&
            display !== 'none' && display !== 'contents') {
          capabilities.add('reorder-flow');
        }
        const parentCanReceiveGenericChildren = !!parent && canReceiveChildren(parent) &&
          parentDisplay !== 'none' && parentDisplay !== 'contents';
        if (isOperational && !isProtectedTopLevel && parentCanReceiveGenericChildren) {
          capabilities.add('group');
        }
        if (isOperational && !isProtectedTopLevel && safelyUngroupableTags.has(tagName) &&
            parentCanReceiveGenericChildren && facts.hasElementChildren) {
          capabilities.add('ungroup');
        }
        return Array.from(capabilities).sort();
      }

      function nodeCapabilityPayload(element) {
        const evidence = capabilityEvidenceForElement(element);
        return {
          capabilities: capabilitiesForElement(element, evidence),
          evidence: evidence
        };
      }

      function elementSupportsCapability(element, capability) {
        return capabilitiesForElement(element).includes(capability);
      }

      function operationAttributesForElement(element) {
        if (!element) { return {}; }
        const attributes = {};
        [
          'href', 'target', 'rel', 'download', 'src', 'alt', 'value', 'name', 'type',
          'placeholder', 'disabled', 'checked', 'selected', 'role', 'aria-label'
        ].forEach((attributeName) => {
          if (element.hasAttribute(attributeName)) {
            attributes[attributeName] = element.getAttribute(attributeName) || '';
          }
        });
        return attributes;
      }

      function scheduleNodeCollection() {
        if (pendingNodeCollectionTimer) { return; }
        pendingNodeCollectionTimer = window.setTimeout(function() {
          pendingNodeCollectionTimer = 0;
          collectLayerNodes();
        }, 0);
      }

      function observeAuthoredMediaCondition(condition) {
        if (!condition || observedMediaQueries.has(condition)) {
          const observed = observedMediaQueries.get(condition);
          return observed ? observed.mediaQuery : null;
        }
        const mediaQuery = window.matchMedia(condition);
        const listener = function() { scheduleNodeCollection(); };
        if (typeof mediaQuery.addEventListener === 'function') {
          mediaQuery.addEventListener('change', listener);
        } else if (typeof mediaQuery.addListener === 'function') {
          mediaQuery.addListener(listener);
        }
        observedMediaQueries.set(condition, { mediaQuery: mediaQuery, listener: listener });
        return mediaQuery;
      }

      function releaseUnobservedMediaConditions(authoredConditions) {
        observedMediaQueries.forEach((observed, condition) => {
          if (authoredConditions.has(condition)) { return; }
          if (typeof observed.mediaQuery.removeEventListener === 'function') {
            observed.mediaQuery.removeEventListener('change', observed.listener);
          } else if (typeof observed.mediaQuery.removeListener === 'function') {
            observed.mediaQuery.removeListener(observed.listener);
          }
          observedMediaQueries.delete(condition);
        });
      }

      function activeAuthoredMediaState() {
        const activeConditions = new Set();
        const authoredConditions = new Set();
        const visitedStyleSheets = new Set();
        let unreadableStyleSheetCount = 0;
        const recordAuthoredCondition = function(value) {
          const condition = String(value || '').trim();
          if (!condition) { return; }
          authoredConditions.add(condition);
          const mediaQuery = observeAuthoredMediaCondition(condition);
          if (mediaQuery && mediaQuery.matches) {
            activeConditions.add(condition);
          }
        };
        const visitRules = function(rules) {
          Array.from(rules || []).forEach((rule) => {
            const isMediaRule = typeof CSSRule !== 'undefined' && rule.type === CSSRule.MEDIA_RULE;
            if (isMediaRule) {
              recordAuthoredCondition(rule.conditionText);
            }
            const isImportRule = typeof CSSRule !== 'undefined' && rule.type === CSSRule.IMPORT_RULE;
            if (isImportRule) {
              try {
                recordAuthoredCondition(rule.media && rule.media.mediaText);
                if (rule.styleSheet) { visitStyleSheet(rule.styleSheet); }
              } catch (_) {
                unreadableStyleSheetCount += 1;
              }
              return;
            }
            try {
              if (rule.cssRules) { visitRules(rule.cssRules); }
            } catch (_) {
              unreadableStyleSheetCount += 1;
            }
          });
        };
        const visitStyleSheet = function(styleSheet) {
          if (!styleSheet || visitedStyleSheets.has(styleSheet)) { return; }
          visitedStyleSheets.add(styleSheet);
          try {
            recordAuthoredCondition(styleSheet.media && styleSheet.media.mediaText);
            visitRules(styleSheet.cssRules);
          } catch (_) {
            unreadableStyleSheetCount += 1;
          }
        };
        Array.from(document.styleSheets || []).forEach(visitStyleSheet);
        releaseUnobservedMediaConditions(authoredConditions);
        return {
          activeMediaQueries: Array.from(activeConditions).sort(),
          unreadableStyleSheetCount: unreadableStyleSheetCount
        };
      }

      function resolvedFontFamily(element) {
        try {
          return String(window.getComputedStyle(element).fontFamily || '').trim();
        } catch (_) {
          return '';
        }
      }

      function renderTargetRelation(wrapper, target) {
        if (wrapper === target) { return 'self'; }
        return target && composedParentElement(target) === wrapper ? 'direct-child' : 'descendant';
      }

      function renderTargetPathSegment(element) {
        const tagName = element.tagName.toLowerCase();
        const parent = composedParentElement(element);
        if (!parent) { return tagName; }
        const sameTagSiblings = Array.from(parent.children).filter((candidate) => candidate.tagName === element.tagName);
        if (sameTagSiblings.length <= 1) { return tagName; }
        return tagName + ':nth-of-type(' + (sameTagSiblings.indexOf(element) + 1) + ')';
      }

      function renderTargetRelationSelector(wrapper, target) {
        if (wrapper === target) { return ':scope'; }
        const segments = [];
        let cursor = target;
        while (cursor && cursor !== wrapper) {
          segments.unshift(renderTargetPathSegment(cursor));
          cursor = composedParentElement(cursor);
        }
        if (cursor !== wrapper || segments.length === 0) { return '';
        }
        return ':scope > ' + segments.join(' > ');
      }

      function belongsToRenderingScope(wrapper, candidate) {
        if (wrapper === candidate) { return true; }
        let cursor = composedParentElement(candidate);
        while (cursor && cursor !== wrapper) {
          if (cursor.hasAttribute('data-og-id') || cursor.hasAttribute('data-og-internal-id')) {
            return false;
          }
          cursor = composedParentElement(cursor);
        }
        return cursor === wrapper;
      }

      function relatedElements(wrapper, selector) {
        const candidates = [];
        if (wrapper.matches && wrapper.matches(selector)) { candidates.push(wrapper); }
        shadowIncludingElements(wrapper).forEach((candidate) => {
          if (candidate === wrapper || !candidate.matches || !candidate.matches(selector)) { return; }
          if (belongsToRenderingScope(wrapper, candidate)) { candidates.push(candidate); }
        });
        return candidates;
      }

      function computedCSSProperty(element, property) {
        try {
          return String(window.getComputedStyle(element).getPropertyValue(property) || '').trim();
        } catch (_) {
          return '';
        }
      }

      function authoredInlineCSSProperty(element, property) {
        try {
          return String(element.style.getPropertyValue(property) || '').trim();
        } catch (_) {
          return '';
        }
      }

      function hasComputedMask(element) {
        return ['mask-image', '-webkit-mask-image'].some((property) => {
          const value = computedCSSProperty(element, property).toLowerCase();
          return value.length > 0 && value !== 'none';
        });
      }

      function maskRenderElements(wrapper) {
        const candidates = relatedElements(wrapper, '*');
        const rendered = candidates.filter((candidate) => hasComputedMask(candidate));
        if (rendered.length > 0) { return rendered; }
        if ((wrapper.getAttribute('data-og-icon-source') || '').toLowerCase() !== 'cdn') { return []; }
        const fallback = candidates.find((candidate) => candidate !== wrapper && candidate.matches('span, i'));
        return fallback ? [fallback] : [];
      }

      function renderingTargetPayload(wrapper, target, kind, properties) {
        if (!target) { return null; }
        const authoredInlineValues = {};
        const computedValues = {};
        properties.forEach((property) => {
          authoredInlineValues[property] = authoredInlineCSSProperty(target, property);
          computedValues[property] = computedCSSProperty(target, property);
        });
        return {
          kind,
          tagName: target.tagName.toLowerCase(),
          relation: renderTargetRelation(wrapper, target),
          relationSelector: renderTargetRelationSelector(wrapper, target),
          targetStandardID: target.getAttribute('id') || '',
          targetInternalID: target.getAttribute('data-og-internal-id') || '',
          authoredInlineValues,
          computedValues
        };
      }

      function renderingTargets(wrapper) {
        const targets = [];
        const mediaElements = relatedElements(wrapper, 'img, video');
        const svgElements = relatedElements(
          wrapper,
          'svg, g, path, circle, ellipse, line, polyline, polygon, rect, use'
        );
        const maskElements = maskRenderElements(wrapper);
        mediaElements.forEach((element) => {
          const target = renderingTargetPayload(wrapper, element, 'media', ['object-fit']);
          if (target) { targets.push(target); }
        });
        svgElements.forEach((element) => {
          const target = renderingTargetPayload(wrapper, element, 'svg', ['stroke-width']);
          if (target) { targets.push(target); }
        });
        maskElements.forEach((element) => {
          const target = renderingTargetPayload(
            wrapper,
            element,
            'mask',
            ['mask-image', '-webkit-mask-image']
          );
          if (target) { targets.push(target); }
        });
        return targets;
      }

      function isPlacementGeneratedElement(element) {
        const controller = window.OpenGraphiteComponentPlacementReferences;
        return !!(controller && typeof controller.isGenerated === 'function' && controller.isGenerated(element));
      }

      function placementGeneratedRootForElement(element) {
        const controller = window.OpenGraphiteComponentPlacementReferences;
        return controller && typeof controller.rootFor === 'function' ? controller.rootFor(element) : null;
      }

      function runtimeMetadataForElement(element) {
        const runtime = window.OpenGraphiteRuntime;
        return runtime && typeof runtime.metadataFor === 'function' ? runtime.metadataFor(element) : null;
      }

      function composedParentElement(element) {
        if (!element) { return null; }
        if (element.parentElement) { return element.parentElement; }
        const root = typeof element.getRootNode === 'function' ? element.getRootNode() : null;
        return root && root.host ? root.host : null;
      }

      function shadowIncludingElements(root) {
        const elements = [];
        const visitedRoots = new Set();
        function visit(node, includeNode) {
          if (!node || visitedRoots.has(node)) { return; }
          if (node.nodeType === Node.DOCUMENT_NODE || node.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
            visitedRoots.add(node);
            Array.from(node.childNodes || []).forEach((child) => visit(child, true));
            return;
          }
          if (node.nodeType !== Node.ELEMENT_NODE) { return; }
          if (includeNode) { elements.push(node); }
          if (node.shadowRoot) { visit(node.shadowRoot, false); }
          Array.from(node.childNodes || []).forEach((child) => visit(child, true));
        }
        visit(root, true);
        return elements;
      }

      function originalEventTarget(event) {
        if (event && typeof event.composedPath === 'function') {
          const path = event.composedPath();
          if (path.length > 0) { return path[0]; }
        }
        return event ? event.target : null;
      }

      function isExpandedRuntimeInstance(element) {
        const runtime = window.OpenGraphiteRuntime;
        return !!(runtime && typeof runtime.isExpanded === 'function' && runtime.isExpanded(element));
      }

      const inspectionExcludedTags = new Set([
        'html', 'head', 'script', 'style', 'link', 'meta', 'title', 'base', 'template', 'noscript'
      ]);
      const sessionReferenceByElement = new WeakMap();
      const sessionElementByReference = new Map();
      let sessionReferenceCounter = 0;
      const inspectionSessionID = (function() {
        const used = new Set();
        return randomInternalID(used);
      })();

      function isInspectableElement(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) { return false; }
        const tagName = (element.tagName || '').toLowerCase();
        if (inspectionExcludedTags.has(tagName)) { return false; }
        if (element === document.body) {
          const hasExplicitIdentityOrSemantics = [
            'id',
            'data-og-id',
            'data-og-internal-id',
            'data-og-type',
            'role'
          ].some((attributeName) => {
            return (element.getAttribute(attributeName) || '').trim().length > 0;
          });
          if (!hasExplicitIdentityOrSemantics) { return false; }
        }
        if (isPlacementGeneratedElement(element)) { return true; }
        const persistentPlacementRoot = element.closest('og-placement');
        if (persistentPlacementRoot && persistentPlacementRoot !== element) { return false; }
        return !isExpandedRuntimeInstance(element);
      }

      function allInspectableNodes() {
        const runtime = window.OpenGraphiteRuntime;
        const candidates = runtime && typeof runtime.elementsForInspection === 'function'
          ? runtime.elementsForInspection()
          : (document.body ? shadowIncludingElements(document.body) : []);
        return candidates.filter(isInspectableElement);
      }

      function allEditableNodes() {
        return allInspectableNodes();
      }

      function allAuthoredSourceElements() {
        if (nodeCollectionContext && nodeCollectionContext.authoredSourceElements) {
          return nodeCollectionContext.authoredSourceElements;
        }
        const sourceElements = [];
        const roots = [document];
        while (roots.length > 0) {
          const root = roots.shift();
          Array.from(root.querySelectorAll('*')).forEach((candidate) => {
            sourceElements.push(candidate);
            if ((candidate.tagName || '').toLowerCase() === 'template' && candidate.content) {
              roots.push(candidate.content);
            }
          });
        }
        const authoredSourceElements = sourceElements.filter((candidate) => {
          return !isPlacementGeneratedElement(candidate) && !isRuntimeGeneratedNode(candidate);
        });
        if (nodeCollectionContext) {
          nodeCollectionContext.authoredSourceElements = authoredSourceElements;
        }
        return authoredSourceElements;
      }

      function attributeValueCounts(attributeName, trimsValue) {
        if (!nodeCollectionContext) { return null; }
        const cache = trimsValue
          ? nodeCollectionContext.trimmedAttributeCounts
          : nodeCollectionContext.rawAttributeCounts;
        if (cache.has(attributeName)) { return cache.get(attributeName); }
        const counts = new Map();
        allAuthoredSourceElements().forEach((candidate) => {
          const rawValue = candidate.getAttribute(attributeName);
          if (rawValue === null) { return; }
          const value = trimsValue ? rawValue.trim() : rawValue;
          if (!value) { return; }
          counts.set(value, (counts.get(value) || 0) + 1);
        });
        cache.set(attributeName, counts);
        return counts;
      }

      function hasUniqueInspectableAttribute(element, attributeName) {
        if (!element) { return false; }
        if (isPlacementGeneratedElement(element) || isRuntimeGeneratedNode(element)) { return false; }
        const value = (element.getAttribute(attributeName) || '').trim();
        if (!value) { return false; }
        const counts = attributeValueCounts(attributeName, true);
        if (counts) { return counts.get(value) === 1; }
        return allAuthoredSourceElements().filter((candidate) => {
          return (candidate.getAttribute(attributeName) || '').trim() === value;
        }).length === 1;
      }

      function hasUniqueAuthoredRawAttribute(element, attributeName) {
        if (!element) { return false; }
        if (isPlacementGeneratedElement(element) || isRuntimeGeneratedNode(element)) { return false; }
        const value = element.getAttribute(attributeName);
        if (value === null || value.trim().length === 0) { return false; }
        const counts = attributeValueCounts(attributeName, false);
        if (counts) { return counts.get(value) === 1; }
        return allAuthoredSourceElements().filter((candidate) => {
          return candidate.getAttribute(attributeName) === value;
        }).length === 1;
      }

      function depth(element) {
        let count = 0;
        let parent = composedParentElement(element);
        while (parent && parent !== document.body && parent !== document.documentElement) {
          if (isInspectableElement(parent)) {
            count += 1;
          }
          parent = composedParentElement(parent);
        }
        return count;
      }

      function annotationStatusForElement(element) {
        if (!element) { return 'none'; }
        const hasID = (element.getAttribute('data-og-id') || '').trim().length > 0;
        const hasInternalID = (element.getAttribute('data-og-internal-id') || '').trim().length > 0;
        if (hasID && hasInternalID) { return 'complete'; }
        return hasID || hasInternalID ? 'partial' : 'none';
      }

      function cssEscapedIdentifier(value) {
        if (!value) { return ''; }
        if (window.CSS && typeof window.CSS.escape === 'function') {
          return window.CSS.escape(value);
        }
        return value.replace(/[^a-zA-Z0-9_-]/g, function(character) {
          return '\\\\' + character.codePointAt(0).toString(16) + ' ';
        });
      }

      function standardIDSelector(element) {
        if (!element) { return ''; }
        const rawID = element.getAttribute('id');
        if (rawID === null || !rawID.trim() || !hasUniqueAuthoredRawAttribute(element, 'id')) { return ''; }
        if (rawID === rawID.trim() && /^[A-Za-z_][A-Za-z0-9_-]*$/.test(rawID)) {
          return '#' + rawID;
        }
        return quotedAttributeSelector('id', rawID);
      }

      function quotedAttributeSelector(attributeName, value) {
        const escaped = Array.from(String(value)).map((character) => {
          if (character.codePointAt(0) === 92) { return String.fromCharCode(92, 92); }
          if (character === '"') { return String.fromCharCode(92, 34); }
          return character;
        }).join('');
        return '[' + attributeName + '="' + escaped + '"]';
      }

      function safeAuthoredSelector(element) {
        if (!element || isPlacementGeneratedElement(element) || isRuntimeGeneratedNode(element)) { return ''; }
        const sourceElements = allAuthoredSourceElements();
        const tagName = (element.tagName || '').toLowerCase();
        const classNames = (element.getAttribute('class') || '').trim().split(/\\s+/).filter((className) => {
          return /^[A-Za-z_][A-Za-z0-9_-]*$/.test(className);
        });
        for (const className of classNames) {
          const matchingClassElements = sourceElements.filter((candidate) => {
            return candidate.classList && candidate.classList.contains(className);
          });
          const classSelector = '.' + cssEscapedIdentifier(className);
          if (matchingClassElements.length === 1 && matchingClassElements[0] === element) {
            return classSelector;
          }
          const matchingTagClassElements = matchingClassElements.filter((candidate) => {
            return (candidate.tagName || '').toLowerCase() === tagName;
          });
          if (matchingTagClassElements.length === 1 && matchingTagClassElements[0] === element) {
            return tagName + classSelector;
          }
        }
        if (tagName.includes('-')) {
          const matchingTags = sourceElements.filter((candidate) => {
            return (candidate.tagName || '').toLowerCase() === tagName;
          });
          if (matchingTags.length === 1 && matchingTags[0] === element) {
            return tagName;
          }
        }
        return '';
      }

      function domPathForElement(element) {
        if (!element || !element.isConnected) { return ''; }
        const segments = [];
        let current = element;
        while (current && current.nodeType === Node.ELEMENT_NODE) {
          const tagName = (current.tagName || '').toLowerCase();
          if (!tagName) { break; }
          let segment = tagName;
          const parent = composedParentElement(current);
          if (parent) {
            const currentRoot = typeof current.getRootNode === 'function' ? current.getRootNode() : null;
            const siblingSource = currentRoot && currentRoot.host === parent
              ? currentRoot.children
              : parent.children;
            const sameTagSiblings = Array.from(siblingSource || []).filter((candidate) => {
              return (candidate.tagName || '').toLowerCase() === tagName;
            });
            segment += ':nth-of-type(' + (sameTagSiblings.indexOf(current) + 1) + ')';
          } else {
            segment += ':nth-of-type(1)';
          }
          segments.unshift(segment);
          if (current === document.documentElement) { break; }
          current = parent;
        }
        return segments.join(' > ');
      }

      function inspectionContentHash(element) {
        const source = element ? element.outerHTML || '' : '';
        let hash = 2166136261;
        for (let index = 0; index < source.length; index += 1) {
          hash ^= source.charCodeAt(index);
          hash = Math.imul(hash, 16777619);
        }
        return (hash >>> 0).toString(16).padStart(8, '0');
      }

      function locatorForElement(element) {
        if (nodeCollectionContext && nodeCollectionContext.locators.has(element)) {
          return nodeCollectionContext.locators.get(element);
        }
        const locator = {
          documentURL: window.location.href || '',
          selector: standardIDSelector(element) || safeAuthoredSelector(element) || null,
          domPath: domPathForElement(element),
          sourceRange: { start: -1, end: -1 },
          contentHash: inspectionContentHash(element)
        };
        if (nodeCollectionContext) {
          nodeCollectionContext.locators.set(element, locator);
        }
        return locator;
      }

      function sessionReferenceForElement(element) {
        if (!element) { return ''; }
        const existing = sessionReferenceByElement.get(element);
        if (existing) { return existing; }
        const locator = locatorForElement(element);
        sessionReferenceCounter += 1;
        const locatorHint = locator.selector || locator.domPath || String(sessionReferenceCounter);
        const reference = [
          'ogref-session:node',
          encodeURIComponent(inspectionSessionID),
          encodeURIComponent(locatorHint),
          encodeURIComponent(locator.contentHash)
        ].join(':');
        sessionReferenceByElement.set(element, reference);
        sessionElementByReference.set(reference, element);
        return reference;
      }

      function referenceForElement(element) {
        if (nodeCollectionContext && nodeCollectionContext.references.has(element)) {
          return nodeCollectionContext.references.get(element);
        }
        const internalID = nodeInternalID(element);
        let reference;
        if (internalID && hasUniqueInspectableAttribute(element, 'data-og-internal-id')) {
          reference = 'ogref-dom:node:' + encodeURIComponent(internalID);
        } else {
          reference = sessionReferenceForElement(element);
        }
        if (nodeCollectionContext) {
          nodeCollectionContext.references.set(element, reference);
        }
        return reference;
      }

      function referenceStabilityForElement(element) {
        return hasUniqueInspectableAttribute(element, 'data-og-internal-id') ? 'stable' : 'session';
      }

      function parentReferenceForElement(element) {
        let parent = composedParentElement(element);
        while (parent && parent !== document.documentElement) {
          if (isInspectableElement(parent)) {
            return referenceForElement(parent);
          }
          parent = composedParentElement(parent);
        }
        return null;
      }

      function inspectableElementFromTarget(target) {
        let element = target;
        while (element && element.nodeType !== Node.ELEMENT_NODE) {
          element = composedParentElement(element);
        }
        while (element && element !== document.documentElement) {
          if (isInspectableElement(element)) { return element; }
          element = composedParentElement(element);
        }
        return null;
      }

      function editableSourceElement(element) {
        return !!element && hasUniqueInspectableAttribute(element, 'data-og-internal-id');
      }

        function randomInternalID(used) {
          const bytes = new Uint8Array(6);
          let candidate = '';
          do {
            if (window.crypto && typeof window.crypto.getRandomValues === 'function') {
              window.crypto.getRandomValues(bytes);
              candidate = Array.from(bytes).map((byte) => byte.toString(16).padStart(2, '0')).join('');
            } else {
              candidate = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER).toString(36);
            }
          } while (!candidate || used.has(candidate));
          used.add(candidate);
          return candidate;
        }

        function isRuntimeGeneratedNode(element) {
          const runtime = window.OpenGraphiteRuntime;
          return !!(runtime && typeof runtime.isGenerated === 'function' && runtime.isGenerated(element));
        }

        function nodeWithID(id) {
          if (!id) { return null; }
          const sessionElement = sessionElementByReference.get(id);
          if (sessionElement && sessionElement.isConnected) { return sessionElement; }
          return allInspectableNodes().find((element) => {
            return selectionIDForElement(element) === id;
          });
        }

        function canScrollForSelection(element) {
          if (!element || typeof window.getComputedStyle !== 'function') { return false; }
          const style = window.getComputedStyle(element);
          const scrollableY = /(auto|scroll|overlay)/.test(style.overflowY || '');
          const scrollableX = /(auto|scroll|overlay)/.test(style.overflowX || '');
          const epsilon = 1;
          return (scrollableY && element.scrollHeight - element.clientHeight > epsilon) ||
            (scrollableX && element.scrollWidth - element.clientWidth > epsilon);
        }

        function selectionScrollContainers(element) {
          const containers = [];
          let current = composedParentElement(element);
          while (current && current !== document.documentElement) {
            if (canScrollForSelection(current)) {
              containers.push(current);
            }
            current = composedParentElement(current);
          }

          const root = document.scrollingElement || document.documentElement;
          if (root) {
            containers.push(root);
          }

          return Array.from(new Set(containers));
        }

        function viewportRectForSelectionContainer(container) {
          const root = document.scrollingElement || document.documentElement;
          if (container === root || container === document.documentElement || container === document.body) {
            return {
              top: 0,
              left: 0,
              right: document.documentElement.clientWidth || window.innerWidth || 0,
              bottom: document.documentElement.clientHeight || window.innerHeight || 0
            };
          }
          return container.getBoundingClientRect();
        }

        function revealDeltaForAxis(start, end, viewportStart, viewportEnd) {
          const paddedStart = viewportStart + selectionRevealPadding;
          const paddedEnd = viewportEnd - selectionRevealPadding;
          const available = Math.max(paddedEnd - paddedStart, 0);
          const size = Math.max(end - start, 0);

          if (size > available) {
            if (start < paddedStart) {
              return start - paddedStart;
            }
            if (end > paddedEnd && start > paddedStart) {
              return start - paddedStart;
            }
            return 0;
          }

          if (start < paddedStart) {
            return start - paddedStart;
          }
          if (end > paddedEnd) {
            return end - paddedEnd;
          }
          return 0;
        }

        function scrollSelectionContainer(container, deltaX, deltaY) {
          if (deltaX === 0 && deltaY === 0) { return; }
          const root = document.scrollingElement || document.documentElement;
          if (container === root || container === document.documentElement || container === document.body) {
            window.scrollBy(deltaX, deltaY);
            return;
          }
          container.scrollLeft += deltaX;
          container.scrollTop += deltaY;
        }

        function revealElementForSelection(element) {
          if (!element || typeof element.getBoundingClientRect !== 'function') { return; }
          selectionScrollContainers(element).forEach((container) => {
            const rect = element.getBoundingClientRect();
            const viewport = viewportRectForSelectionContainer(container);
            const deltaX = revealDeltaForAxis(rect.left, rect.right, viewport.left, viewport.right);
            const deltaY = revealDeltaForAxis(rect.top, rect.bottom, viewport.top, viewport.bottom);
            scrollSelectionContainer(container, deltaX, deltaY);
          });
        }

        function selectedElement() {
          if (currentSelectedID) {
            const element = nodeWithID(currentSelectedID);
            if (element) { return element; }
          }
          return null;
        }

        function selectedElements() {
          const elements = [];
          currentSelectedIDs.forEach((id) => {
            const element = nodeWithID(id);
            if (element) { elements.push(element); }
          });
          return elements;
        }

        function isFrameElement(element) {
          return !!element && elementSupportsCapability(element, 'receive-children');
        }

        function shouldShowFrameGuides() {
          return activeTool === 'frame' || !!framePlacement || isFrameElement(selectedElement());
        }

        function updateFrameGuideState() {
          frameGuideAnimations.forEach((animation) => animation.cancel());
          frameGuideAnimations.clear();
          if (!shouldShowFrameGuides()) { return; }

          const selected = new Set(selectedElements());
          allEditableNodes().forEach((element) => {
            if (!isFrameElement(element) || selected.has(element) || typeof element.animate !== 'function') { return; }
            const animation = element.animate(
              [{ outline: '1px dashed rgba(29,155,240,.35)', outlineOffset: '-1px' }],
              { duration: 1, fill: 'both' }
            );
            frameGuideAnimations.set(element, animation);
          });
        }

        function framePlacementViewportRect(placement, event) {
          const left = Math.min(placement.startClientX, event.clientX);
          const top = Math.min(placement.startClientY, event.clientY);
          const width = Math.abs(event.clientX - placement.startClientX);
          const height = Math.abs(event.clientY - placement.startClientY);
          return { left: left, top: top, width: width, height: height };
        }

        function selectedElementFramePayload(element) {
          if (!element || typeof element.getBoundingClientRect !== 'function') { return null; }
          const rect = element.getBoundingClientRect();
          if (!Number.isFinite(rect.left) || !Number.isFinite(rect.top) ||
              !Number.isFinite(rect.width) || !Number.isFinite(rect.height) ||
              rect.width <= 0 || rect.height <= 0) {
            return null;
          }
          return {
            id: selectionIDForElement(element) || elementID(element) || element.tagName.toLowerCase(),
            x: rect.left,
            y: rect.top,
            width: rect.width,
            height: rect.height
          };
        }

        function focusedPreviewFramePayload(element) {
          const payload = selectedElementFramePayload(element);
          if (!payload) { return null; }
          return {
            id: payload.id,
            x: payload.x + window.scrollX,
            y: payload.y + window.scrollY,
            width: payload.width,
            height: payload.height
          };
        }

        function selectionOverlayPayload() {
          const nodes = selectedElements()
            .map(selectedElementFramePayload)
            .filter((payload) => payload !== null);
          if (nodes.length === 0) { return null; }

          const left = Math.min.apply(null, nodes.map((node) => node.x));
          const top = Math.min.apply(null, nodes.map((node) => node.y));
          const right = Math.max.apply(null, nodes.map((node) => node.x + node.width));
          const bottom = Math.max.apply(null, nodes.map((node) => node.y + node.height));
          if (!Number.isFinite(left) || !Number.isFinite(top) ||
              !Number.isFinite(right) || !Number.isFinite(bottom) ||
              right <= left || bottom <= top) {
            return null;
          }

          return {
            active: true,
            id: currentSelectedID || nodes[0].id,
            x: left,
            y: top,
            width: right - left,
            height: bottom - top,
            nodes: nodes
          };
        }

        function postSelectionOverlayPayload(payload) {
          if (!window.webkit ||
              !window.webkit.messageHandlers ||
              !window.webkit.messageHandlers.openGraphiteSelectionOverlay) {
            return;
          }
          window.webkit.messageHandlers.openGraphiteSelectionOverlay.postMessage(payload || {});
        }

        function nodeDragPreviewPayload(drag) {
          const element = drag ? (drag.visualElement || drag.element) : null;
          if (!drag || !element || typeof element.getBoundingClientRect !== 'function') {
            return { active: false };
          }
          const rect = element.getBoundingClientRect();
          if (!Number.isFinite(rect.left) || !Number.isFinite(rect.top) ||
              !Number.isFinite(rect.width) || !Number.isFinite(rect.height) ||
              rect.width <= 0 || rect.height <= 0) {
            return { active: false };
          }
          return {
            active: true,
            id: drag.selectedID || elementID(element) || element.tagName.toLowerCase(),
            x: rect.left + window.scrollX,
            y: rect.top + window.scrollY,
            width: rect.width,
            height: rect.height
          };
        }

        function postNodeDragPreviewPayload(payload) {
          if (!window.webkit ||
              !window.webkit.messageHandlers ||
              !window.webkit.messageHandlers.openGraphiteNodeDragPreview) {
            return;
          }
          window.webkit.messageHandlers.openGraphiteNodeDragPreview.postMessage(payload || { active: false });
        }

        function postNodeDragPreview(drag) {
          postNodeDragPreviewPayload(nodeDragPreviewPayload(drag));
        }

        function clearNodeDragPreview() {
          postNodeDragPreviewPayload({ active: false });
        }

        function removeSelectionOverlay() {
          if (selectionOverlay) {
            selectionOverlay.remove();
          }
          selectionOverlay = null;
        }

        function hideSelectionOverlay() {
          removeSelectionOverlay();
          postSelectionOverlayPayload(null);
        }

        function clearSelectionOverlayUpdateTimer() {
          if (selectionOverlayUpdateTimer === null) { return; }
          window.clearTimeout(selectionOverlayUpdateTimer);
          selectionOverlayUpdateTimer = null;
        }

        function updateSelectionOverlay() {
          selectionOverlayFrame = null;
          lastSelectionOverlayUpdateTime = window.performance.now();
          const payload = selectionOverlayPayload();
          if (!payload) {
            hideSelectionOverlay();
            return;
          }
          removeSelectionOverlay();
          postSelectionOverlayPayload(payload);
        }

        function scheduleSelectionOverlayUpdate(options) {
          if (selectionOverlayFrame !== null) { return; }
          const throttled = !!(options && options.throttled);
          if (!throttled) {
            clearSelectionOverlayUpdateTimer();
          } else {
            const minimumInterval = 80;
            const now = window.performance.now();
            const elapsed = now - lastSelectionOverlayUpdateTime;
            if (elapsed < minimumInterval) {
              if (selectionOverlayUpdateTimer === null) {
                selectionOverlayUpdateTimer = window.setTimeout(function() {
                  selectionOverlayUpdateTimer = null;
                  scheduleSelectionOverlayUpdate();
                }, minimumInterval - elapsed);
              }
              return;
            }
          }
          selectionOverlayFrame = window.requestAnimationFrame(updateSelectionOverlay);
        }

        function setActiveTool(tool) {
          if (editingTextElement) {
            finishTextEditing(false);
          }
          if (framePlacement) {
            finishFramePlacement(true);
          }
          pendingFramePlacement = null;
          if (activeDrag) {
            finishActiveDrag(true);
          }
          activeTool = tool || 'select';
          pendingDrag = null;
          updateFrameGuideState();
        }

        function elementID(element) {
          if (!element) { return ''; }
          const authoredID = element.getAttribute('data-og-id') || '';
          if (authoredID) { return authoredID; }
          const runtime = window.OpenGraphiteRuntime;
          return runtime && typeof runtime.hostIDFor === 'function' ? runtime.hostIDFor(element) : '';
        }

        function sourcePlacementIDForElement(element) {
          const controller = window.OpenGraphiteComponentPlacementReferences;
          return controller && typeof controller.placementIDFor === 'function'
            ? controller.placementIDFor(element)
            : '';
        }

        function selectionIDForElement(element) {
          if (!element) { return ''; }
          const sourceID = elementID(element);
          if (!isPlacementGeneratedElement(element)) {
            const internalID = nodeInternalID(element);
            const authoredIDIsUnique = hasUniqueInspectableAttribute(element, 'data-og-id');
            const internalIDIsUnique = hasUniqueInspectableAttribute(element, 'data-og-internal-id');
            return (sourceID && authoredIDIsUnique)
              ? sourceID
              : (internalID && internalIDIsUnique
                ? 'ogdom:' + encodeURIComponent(internalID)
                : sessionReferenceForElement(element));
          }
          const placementID = sourcePlacementIDForElement(element);
          const stableNodeID = nodeInternalID(element) || sourceID || sessionReferenceForElement(element);
          if (!placementID || !stableNodeID) { return sourceID || sessionReferenceForElement(element); }
          return 'ogpl:' + encodeURIComponent(placementID) + ':' + encodeURIComponent(stableNodeID);
        }

        function sourceElementForPlacementGeneratedElement(element) {
          if (!isPlacementGeneratedElement(element)) { return element; }
          const controller = window.OpenGraphiteComponentPlacementReferences;
          if (controller && typeof controller.sourceFor === 'function') {
            const source = controller.sourceFor(element);
            if (source) { return source; }
          }
          const internalID = nodeInternalID(element);
          const sourceID = elementID(element);
          return allInspectableNodes().find((candidate) => {
            if (candidate === element || isPlacementGeneratedElement(candidate)) { return false; }
            if (internalID) {
              return nodeInternalID(candidate) === internalID;
            }
            return sourceID && elementID(candidate) === sourceID;
          }) || null;
        }

        function editElementForSelectionID(id) {
          const element = nodeWithID(id);
          if (!element) { return null; }
          return sourceElementForPlacementGeneratedElement(element) || element;
        }

        function editableElementFromTarget(target) {
          return inspectableElementFromTarget(target);
        }

        function selectableChainFor(element) {
          const chain = [];
          let current = element;
          while (current && current !== document.documentElement) {
            if (isInspectableElement(current)) {
              chain.push(current);
            }
            current = composedParentElement(current);
          }

          const rootToLeaf = chain.reverse();
          const withoutPage = rootToLeaf.filter((candidate) => {
            return !capabilityEvidenceForElement(candidate).isProjectResourceRoot;
          });
          return withoutPage.length > 0 ? withoutPage : rootToLeaf;
        }

        function nextSelectionIDForClick(element) {
          const chain = selectableChainFor(element);
          if (chain.length === 0) { return ''; }

          const currentIndex = chain.findIndex((candidate) => selectionIDForElement(candidate) === currentSelectedID);
          if (currentIndex < 0) {
            return selectionIDForElement(chain[0]);
          }

          const nextIndex = Math.min(currentIndex + 1, chain.length - 1);
          return selectionIDForElement(chain[nextIndex]);
        }

        function elementInChain(chain, id) {
          if (!id) { return null; }
          return chain.find((candidate) => selectionIDForElement(candidate) === id) || null;
        }

        function hasLockedAncestor(element) {
          let current = element;
          while (current && current !== document.documentElement) {
            if (current.getAttribute && current.getAttribute('data-og-locked') === 'true') {
              return true;
            }
            current = current.parentElement;
          }
          return false;
        }

        function canDragElement(element) {
          if (!element) { return false; }
          return editableSourceElement(element)
            && (elementSupportsCapability(element, 'drag-position') || elementSupportsCapability(element, 'reorder-flow'))
            && !isRuntimeGeneratedNode(element)
            && !hasLockedAncestor(element);
        }

        function isTextElement(element) {
          return !!element && elementSupportsCapability(element, 'edit-text');
        }

        function draggableElementForChain(chain) {
          const selected = elementInChain(chain, currentSelectedID);
          if (canDragElement(selected)) {
            return selected;
          }
          const reorderCandidate = reorderCandidateForChain(chain);
          if (reorderCandidate) {
            return reorderCandidate;
          }
          return chain.find(canDragElement) || null;
        }

        function textElementForEditing(element, selectedID) {
          const selectionBaselineID = typeof selectedID === 'string' ? selectedID : currentSelectedID;
          const chain = selectableChainFor(element);
          const selected = elementInChain(chain, selectionBaselineID);
          if (isTextElement(selected) && !hasLockedAncestor(selected)) {
            return selected;
          }
          return null;
        }

        function editingSelectionBaselineForClick(event) {
          if (!event || event.detail <= 1) {
            clickSequenceStartSelectedID = currentSelectedID;
            return currentSelectedID;
          }
          return clickSequenceStartSelectedID;
        }

        var staticFlowCollectionFrame = null;
        var currentStaticFlowHoverID = '';

        function staticFlowSelector() {
          return [
            'a[href]',
            'area[href]',
            '[role="link"][href]',
            '[data-og-target]',
            '[data-og-href]',
            '[data-og-link]'
          ].join(',');
        }

        function staticFlowElements() {
          return Array.from(new Set(Array.from(document.querySelectorAll(staticFlowSelector()))));
        }

        function staticFlowTargetFor(element) {
          const rawTarget = [
            element.getAttribute('href'),
            element.getAttribute('data-og-target'),
            element.getAttribute('data-og-href'),
            element.getAttribute('data-og-link')
          ].find((value) => value && value.trim().length > 0) || '';
          if (!rawTarget) { return null; }

          let resolvedTarget = '';
          if (typeof element.href === 'string' && element.href.trim().length > 0) {
            resolvedTarget = element.href;
          } else {
            try {
              resolvedTarget = new URL(rawTarget, window.location.href).href;
            } catch (_) {
              resolvedTarget = rawTarget;
            }
          }

          return {
            raw: rawTarget,
            resolved: resolvedTarget
          };
        }

        function sourceLabelForStaticFlow(element, fallback) {
          const text = (element.innerText || element.textContent || '').trim().replace(/\\s+/g, ' ');
          if (text.length > 0) { return text; }
          return fallback || '';
        }

        function staticFlowPayloadItems() {
          return staticFlowElements().flatMap((element, index) => {
            const target = staticFlowTargetFor(element);
            if (!target) { return []; }

            const rect = element.getBoundingClientRect();
            if (!Number.isFinite(rect.x) || !Number.isFinite(rect.y) || rect.width <= 0 || rect.height <= 0) {
              return [];
            }

            const sourceNodeID = element.getAttribute('data-og-id') || element.id || '';
            const fallbackID = 'static-flow-' + index + '-' + target.raw;
            const id = (sourceNodeID || fallbackID) + ':' + target.raw;
            return [{
              element: element,
              payload: {
                id: id,
                sourceNodeID: sourceNodeID,
                sourceLabel: sourceLabelForStaticFlow(element, sourceNodeID),
                targetHref: target.raw,
                targetURL: target.resolved,
                x: rect.x,
                y: rect.y,
                width: rect.width,
                height: rect.height
              }
            }];
          });
        }

        function collectStaticFlowLinks() {
          const links = staticFlowPayloadItems().map((item) => item.payload);
          if (currentStaticFlowHoverID && !links.some((link) => link.id === currentStaticFlowHoverID)) {
            postStaticFlowHover(null);
          }
          window.webkit.messageHandlers.openGraphiteStaticFlowLinks.postMessage(links);
          return links;
        }

        function scheduleStaticFlowLinkCollection() {
          if (staticFlowCollectionFrame !== null) { return; }
          staticFlowCollectionFrame = window.requestAnimationFrame(function() {
            staticFlowCollectionFrame = null;
            collectStaticFlowLinks();
          });
        }

        function staticFlowElementFromTarget(target) {
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }
          return element ? element.closest(staticFlowSelector()) : null;
        }

        function staticFlowPayloadForElement(element) {
          if (!element) { return null; }
          const item = staticFlowPayloadItems().find((candidate) => candidate.element === element);
          return item ? item.payload : null;
        }

        function postStaticFlowHover(payload) {
          const id = payload ? payload.id || '' : '';
          if (id === currentStaticFlowHoverID) { return; }
          currentStaticFlowHoverID = id;
          window.webkit.messageHandlers.openGraphiteStaticFlowHover.postMessage(payload || {
            id: '',
            sourceNodeID: ''
          });
        }

        function updateStaticFlowHoverFromTarget(target) {
          const payload = staticFlowPayloadForElement(staticFlowElementFromTarget(target));
          postStaticFlowHover(payload);
        }

        function resetNodeCollectionContext() {
          nodeCollectionContext = {
            authoredSourceElements: null,
            computedStyles: new WeakMap(),
            locators: new WeakMap(),
            references: new WeakMap(),
            trimmedAttributeCounts: new Map(),
            rawAttributeCounts: new Map()
          };
          allAuthoredSourceElements();
        }

        function nodePayloadForElement(element, mediaState, includesDetails) {
          const runtimeMetadata = runtimeMetadataForElement(element);
          const locator = locatorForElement(element);
          const payload = {
            id: selectionIDForElement(element),
            authoredID: element.getAttribute('data-og-id') || '',
            standardID: element.getAttribute('id') || '',
            internalID: element.getAttribute('data-og-internal-id') || '',
            reference: referenceForElement(element),
            annotationStatus: annotationStatusForElement(element),
            referenceStability: referenceStabilityForElement(element),
            locator: locator,
            parentReference: parentReferenceForElement(element),
            tagName: element.tagName.toLowerCase(),
            legacyTypeHint: element.getAttribute('data-og-type') || '',
            attributes: operationAttributesForElement(element),
            role: element.getAttribute('role') || '',
            componentID: element.getAttribute('data-og-component') || '',
            componentMaster: (element.tagName || '').toLowerCase() !== 'og-instance' &&
              (element.tagName || '').toLowerCase().includes('-') &&
              !!(element.getAttribute('data-og-component') || '').trim() &&
              Array.from(element.children || []).some((child) => (child.tagName || '').toLowerCase() === 'template'),
            sourceComponentID: runtimeMetadata ? runtimeMetadata.sourceComponent || '' : '',
            sourceInstanceID: runtimeMetadata ? runtimeMetadata.sourceInstance || '' : '',
            sourceNodeInternalID: element.getAttribute('data-og-source-node-internal-id') || '',
            sourceNodeID: isPlacementGeneratedElement(element)
              ? elementID(element)
              : (runtimeMetadata ? runtimeMetadata.sourceID || '' : ''),
            sourcePlacementID: sourcePlacementIDForElement(element),
            placementGenerated: isPlacementGeneratedElement(element),
            textSource: element.getAttribute('data-og-text-source') || '',
            i18nKey: element.getAttribute('data-i18n-key') || '',
            iconLibrary: element.getAttribute('data-og-icon-library') || '',
            iconName: element.getAttribute('data-og-icon-name') || '',
            iconSource: element.getAttribute('data-og-icon-source') || '',
            activeMediaQueries: mediaState.activeMediaQueries,
            unreadableStyleSheetCount: mediaState.unreadableStyleSheetCount,
            hidden: element.hasAttribute('hidden') || element.getAttribute('aria-hidden') === 'true',
            hasHiddenAttribute: element.hasAttribute('hidden'),
            locked: element.getAttribute('data-og-locked') === 'true',
            depth: depth(element)
          };
          if (!includesDetails) { return payload; }

          const computedStyle = computedStylePayload(element);
          const capabilityPayload = nodeCapabilityPayload(element);
          payload.capabilities = capabilityPayload.capabilities;
          payload.capabilityEvidence = capabilityPayload.evidence;
          payload.layout = layoutModeForComputedStyle(computedStyle);
          payload.textContent = editablePlainText(element);
          payload.fallbackTextContent = fallbackPlainText(element);
          payload.cssVariables = cssVariables(element);
          payload.computedStyle = computedStyle;
          payload.resolvedFontFamily = resolvedFontFamily(element);
          payload.renderingTargets = renderingTargets(element);
          payload.hidden = isHiddenByComputedStyle(element);
          return payload;
        }

        function prepareNodeCollection() {
          if (window.OpenGraphiteComponentPlacementReferences && typeof window.OpenGraphiteComponentPlacementReferences.render === 'function') {
            window.OpenGraphiteComponentPlacementReferences.render();
            if (currentSelectedID) {
              selectNode(currentSelectedID);
            }
          }
          resetNodeCollectionContext();
          return activeAuthoredMediaState();
        }

        function finishNodeCollection(nodes) {
          window.webkit.messageHandlers.openGraphiteNodes.postMessage(nodes);
          refreshFocusIsolation();
          scheduleStaticFlowLinkCollection();
          scheduleSelectionOverlayUpdate();
          return nodes;
        }

        function collectNodes() {
          const mediaState = prepareNodeCollection();
          const nodes = allInspectableNodes().map((element) => {
            return nodePayloadForElement(element, mediaState, true);
          });
          return finishNodeCollection(nodes);
        }

        function collectLayerNodes() {
          const mediaState = prepareNodeCollection();
          const nodes = allInspectableNodes().map((element) => {
            return nodePayloadForElement(element, mediaState, false);
          });
          finishNodeCollection(nodes);
          if (currentSelectedID) {
            collectNodeDetails(currentSelectedID, mediaState);
          }
          return nodes;
        }

        function collectNodeDetails(id, existingMediaState) {
          if (!nodeCollectionContext) { resetNodeCollectionContext(); }
          const element = nodeWithID(id);
          if (!element) { return null; }
          const payload = nodePayloadForElement(
            element,
            existingMediaState || activeAuthoredMediaState(),
            true
          );
          const handler = window.webkit && window.webkit.messageHandlers
            ? window.webkit.messageHandlers.openGraphiteNodeDetails
            : null;
          if (handler) { handler.postMessage(payload); }
          return payload;
        }

        function refreshFocusIsolation() {
          const controller = window.OpenGraphiteFocusIsolation;
          if (!controller) { return false; }
          if (focusedNodeIDs.length === 0) {
            controller.clear();
            return false;
          }
          const elements = focusedNodeIDs
            .map((id) => nodeWithID(id))
            .filter((element) => !!element);
          return controller.apply(elements);
        }

        function setFocusedNodes(ids) {
          const requestedIDs = Array.isArray(ids) ? ids : [];
          focusedNodeIDs = requestedIDs
            .map((id) => typeof id === 'string' ? id.trim() : '')
            .filter((id, index, all) => id.length > 0 && all.indexOf(id) === index);
          const didApply = refreshFocusIsolation();
          scheduleSelectionOverlayUpdate();
          return focusedNodeIDs.length > 0 ? didApply : true;
        }

        function focusedNodeFrame(id) {
          const element = nodeWithID(id);
          if (!element) { return null; }
          const rect = element.getBoundingClientRect();
          if (![rect.x, rect.y, rect.width, rect.height].every(Number.isFinite) || rect.width <= 0 || rect.height <= 0) {
            return null;
          }
          return {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height
          };
        }

        function setFocusMode(isEnabled) {
          return setFocusedNodes(isEnabled ? Array.from(currentSelectedIDs) : []);
        }

        function clearSelection() {
          currentSelectedID = '';
          currentSelectedIDs = new Set();
          hideSelectionOverlay();
          updateFrameGuideState();
        }

        function selectNode(id) {
          return selectNodes(id ? [id] : [], id || '');
        }

        function selectNodes(ids, primaryID) {
          const requestedIDs = Array.isArray(ids) ? ids : [];
          const normalizedIDs = requestedIDs
            .map((id) => typeof id === 'string' ? id.trim() : '')
            .filter((id, index, all) => id.length > 0 && all.indexOf(id) === index);
          const primary = typeof primaryID === 'string' ? primaryID.trim() : '';
          if (editingTextElement && !normalizedIDs.includes(selectionIDForElement(editingTextElement))) {
            finishTextEditing(false, false);
          }
          clearSelection();
          if (normalizedIDs.length === 0) { return false; }

          const selected = [];
          normalizedIDs.forEach((id) => {
            const element = nodeWithID(id);
            if (!element) { return; }
            selected.push({ id: id, element: element });
          });
          if (selected.length === 0) { return false; }

          currentSelectedIDs = new Set(selected.map((item) => item.id));
          const primarySelection = selected.find((item) => item.id === primary) || selected[selected.length - 1];
          currentSelectedID = primarySelection.id;
          revealElementForSelection(primarySelection.element);
          refreshFocusIsolation();
          updateFrameGuideState();
          scheduleSelectionOverlayUpdate();
          return true;
        }

        function selectedGroupIDForClick(element, proposedID) {
          if (currentSelectedIDs.size <= 1) { return ''; }
          const proposed = typeof proposedID === 'string' ? proposedID.trim() : '';
          if (proposed && currentSelectedIDs.has(proposed)) { return proposed; }
          const chain = selectableChainFor(element);
          const selected = chain.find((item) => currentSelectedIDs.has(selectionIDForElement(item)));
          return selected ? selectionIDForElement(selected) : '';
        }

        function preserveMultiSelectionForClick(element, proposedID) {
          const selectedID = selectedGroupIDForClick(element, proposedID);
          if (!selectedID) { return false; }
          const ids = Array.from(currentSelectedIDs);
          selectNodes(ids, selectedID);
          notifySelection(selectedID);
          collectNodeDetails(selectedID);
          return true;
        }

        function notifySelection(id) {
          window.webkit.messageHandlers.openGraphiteSelection.postMessage(id || '');
        }

        function nodeInternalID(element) {
          return element ? element.getAttribute('data-og-internal-id') || '' : '';
        }

        function escapeHTMLText(value) {
          return (value || '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        }

        function htmlForNodeList(nodes) {
          return Array.from(nodes).map((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              if (isPlacementGeneratedElement(node)) {
                return '';
              }
              return node.outerHTML;
            }
            if (node.nodeType === Node.TEXT_NODE) { return escapeHTMLText(node.textContent || ''); }
            return '';
          }).join('');
        }

        function fragmentHTML(fragment) {
          return htmlForNodeList(fragment ? fragment.childNodes : []);
        }

        function notifyDocumentChange(edit) {
          if (!edit || !edit.operation) { return; }
          window.webkit.messageHandlers.openGraphiteDocumentChange.postMessage(edit);
        }

        function notifyTextEditingChange(element) {
          if (!element) { return; }
          window.webkit.messageHandlers.openGraphiteTextEditing.postMessage({
            id: selectionIDForElement(element),
            text: editablePlainText(element)
          });
        }

        function editablePlainText(element) {
          if (!element) { return ''; }
          const value = typeof element.innerText === 'string' ? element.innerText : element.textContent || '';
          return value.replace(/\\n+$/, '');
        }

        function fallbackPlainText(element) {
          if (!element) { return ''; }
          const i18nRuntime = window.OpenGraphiteI18n;
          const runtimeFallback = i18nRuntime && typeof i18nRuntime.fallbackHTMLFor === 'function' && element.hasAttribute('data-i18n-key')
            ? i18nRuntime.fallbackHTMLFor(element)
            : null;
          const fallbackHTML = runtimeFallback ?? element.getAttribute('data-og-fallback-text');
          if (fallbackHTML === null) {
            return editablePlainText(element);
          }
          const container = document.createElement('span');
          container.innerHTML = fallbackHTML;
          return editablePlainText(container);
        }

        function selectTextContents(element) {
          const selection = window.getSelection();
          if (!selection) { return; }
          const range = document.createRange();
          range.selectNodeContents(element);
          selection.removeAllRanges();
          selection.addRange(range);
        }

        function caretRangeFromPoint(clientX, clientY) {
          if (typeof document.caretRangeFromPoint === 'function') {
            return document.caretRangeFromPoint(clientX, clientY);
          }
          if (typeof document.caretPositionFromPoint === 'function') {
            const position = document.caretPositionFromPoint(clientX, clientY);
            if (!position) { return null; }
            const range = document.createRange();
            range.setStart(position.offsetNode, position.offset);
            range.collapse(true);
            return range;
          }
          return null;
        }

        function applyCaretRange(range) {
          const selection = window.getSelection();
          if (!selection || !range) { return false; }
          selection.removeAllRanges();
          selection.addRange(range);
          return true;
        }

        function placeCaretAtEnd(element) {
          const range = document.createRange();
          range.selectNodeContents(element);
          range.collapse(false);
          return applyCaretRange(range);
        }

        function placeCaretAtPoint(element, clientX, clientY) {
          const range = caretRangeFromPoint(clientX, clientY);
          if (range && element.contains(range.startContainer)) {
            return applyCaretRange(range);
          }
          return placeCaretAtEnd(element);
        }

        function applyTextEditingMetrics(element) {
          const rect = element.getBoundingClientRect();
          element.style.width = pixelString(rect.width);
          element.style.minHeight = pixelString(rect.height);
        }

        function captureTextEditingPresentation(element) {
          return {
            contentEditable: attributeState(element, 'contenteditable'),
            spellcheck: attributeState(element, 'spellcheck'),
            width: inlineStyleState(element, 'width'),
            minHeight: inlineStyleState(element, 'min-height')
          };
        }

        function restoreTextEditingPresentation(element, state) {
          restoreAttributeState(element, 'contenteditable', state ? state.contentEditable : null);
          restoreAttributeState(element, 'spellcheck', state ? state.spellcheck : null);
          restoreInlineStyleState(element, 'width', state ? state.width : null);
          restoreInlineStyleState(element, 'min-height', state ? state.minHeight : null);
        }

        function applyTextEditingPresentation(element) {
          applyTextEditingMetrics(element);
          element.setAttribute('contenteditable', 'plaintext-only');
          element.setAttribute('spellcheck', 'true');
        }

        function replaceTextContents(element, text) {
          element.replaceChildren();
          const lines = (text || '').split('\\n');
          lines.forEach((line, index) => {
            if (index > 0) {
              element.append(document.createElement('br'));
            }
            if (line.length > 0) {
              element.append(document.createTextNode(line));
            }
          });
        }

        function htmlForPlainText(text) {
          const container = document.createElement('span');
          replaceTextContents(container, text);
          return htmlForNodeList(container.childNodes);
        }

        function setTextContent(id, text, mode) {
          const element = editElementForSelectionID(id);
          if (!element || !elementSupportsCapability(element, 'edit-text')) { return false; }

          if (mode === 'resolved') {
            replaceTextContents(element, text);
            collectLayerNodes();
            return true;
          }

          const previousActiveText = editablePlainText(element);
          const previousFallbackText = fallbackPlainText(element);
          const i18nRuntime = window.OpenGraphiteI18n;
          const hasRuntimeFallback = !!(
            element.hasAttribute('data-i18n-key') &&
            i18nRuntime &&
            typeof i18nRuntime.setFallbackHTML === 'function'
          );
          const hasFallbackText = element.hasAttribute('data-og-fallback-text');
          if (hasRuntimeFallback || hasFallbackText) {
            const fallbackHTML = htmlForPlainText(text);
            if (hasRuntimeFallback) {
              i18nRuntime.setFallbackHTML(element, fallbackHTML);
            }
            if (hasFallbackText) {
              element.setAttribute('data-og-fallback-text', fallbackHTML);
            }
            if (previousActiveText === previousFallbackText) {
              replaceTextContents(element, text);
            }
          } else {
            replaceTextContents(element, text);
          }

          collectLayerNodes();
          return true;
        }

        function beginTextEditing(element, options) {
          if (activeTool !== 'select' || !isTextElement(element) || hasLockedAncestor(element)) {
            return false;
          }

          if (editingTextElement && editingTextElement !== element) {
            finishTextEditing(false, false);
          }

          const shouldSelectText = typeof options === 'boolean' ? options : !!(options && options.selectText);
          const shouldPlaceCaret = !shouldSelectText &&
            options &&
            Number.isFinite(options.clientX) &&
            Number.isFinite(options.clientY);
          const id = selectionIDForElement(element);
          selectNode(id);
          notifySelection(id);
          editingTextElement = element;
          editingOriginalText = editablePlainText(element);
          editingPresentationState = captureTextEditingPresentation(element);
          applyTextEditingPresentation(element);
          element.focus({ preventScroll: true });

          if (shouldSelectText) {
            selectTextContents(element);
          } else if (shouldPlaceCaret) {
            placeCaretAtPoint(element, options.clientX, options.clientY);
          } else {
            placeCaretAtEnd(element);
          }
          return true;
        }

        function finishTextEditing(cancelled, shouldRestoreSelection) {
          const element = editingTextElement;
          if (!element) { return; }
          const selectedID = selectionIDForElement(element);
          const originalText = editingOriginalText;
          const nextText = cancelled ? originalText : editablePlainText(element);

          editingTextElement = null;
          editingOriginalText = '';
          replaceTextContents(element, nextText);
          restoreTextEditingPresentation(element, editingPresentationState);
          editingPresentationState = null;

          if (shouldRestoreSelection !== false) {
            selectNode(selectedID);
            notifySelection(selectedID);
          }

          if (!cancelled && nextText !== originalText) {
            const editElement = editElementForSelectionID(selectedID) || element;
            if (editElement !== element) {
              replaceTextContents(editElement, nextText);
            }
            collectLayerNodes();
            notifyDocumentChange({
              operation: 'setTextContent',
              nodeID: selectedID,
              nodeInternalID: nodeInternalID(editElement),
              value: nextText,
              previousValue: originalText
            });
          }
        }

      function applyCSSVariableValue(element, key, value) {
        if ((value || '').trim().length === 0) {
          element.style.removeProperty(key);
        } else {
          element.style.setProperty(key, value);
        }
      }

      function setCSSVariable(id, key, value) {
        const element = editElementForSelectionID(id);
        if (!element || !elementSupportsCapability(element, 'edit-layout')) { return false; }
        applyCSSVariableValue(element, key, value);
        collectLayerNodes();
        return true;
      }

      function setCSSVariables(id, values) {
        const element = editElementForSelectionID(id);
        if (!element || !elementSupportsCapability(element, 'edit-layout') ||
            !values || typeof values !== 'object') { return false; }
        const keys = Object.keys(values);
        keys.forEach((key) => {
          applyCSSVariableValue(element, key, values[key] || '');
        });
        collectLayerNodes();
        return true;
      }

      function setCSSVariablesBatch(nodeValues) {
        if (!nodeValues || typeof nodeValues !== 'object') { return false; }
        const entries = Object.entries(nodeValues);
        const canApplyEveryEntry = entries.every(([id, values]) => {
          const element = editElementForSelectionID(id);
          return !!element && elementSupportsCapability(element, 'edit-layout') &&
            !!values && typeof values === 'object';
        });
        if (!canApplyEveryEntry) { return false; }
        let didApply = false;
        entries.forEach(([id, values]) => {
          const element = editElementForSelectionID(id);
          if (!element || !values || typeof values !== 'object') { return; }
          Object.keys(values).forEach((key) => {
            applyCSSVariableValue(element, key, values[key] || '');
          });
          didApply = true;
        });
        if (!didApply) { return false; }
        collectLayerNodes();
        return true;
      }

        function setAttributeValue(id, name, value, removesAttribute) {
          const element = editElementForSelectionID(id);
          if (!element) { return false; }
        const normalizedName = String(name || '').trim().toLowerCase();
        const linkAttributes = new Set(['href', 'target', 'rel', 'download']);
        const mediaAttributes = new Set(['src', 'alt']);
        const controlAttributes = new Set([
          'name', 'type', 'placeholder', 'disabled', 'checked', 'selected'
        ]);
        const iconAttributes = new Set([
          'data-og-icon-library', 'data-og-icon-name', 'data-og-icon-source'
        ]);
        if (linkAttributes.has(normalizedName)) {
          const tagName = element.tagName.toLowerCase();
          const isNativeHyperlink = tagName === 'a' || tagName === 'area';
          const hasHref = element.hasAttribute('href');
          const linkRole = firstRecognizedARIARole(element) === 'link';
          const canEditLink = elementSupportsCapability(element, 'edit-link');
          if (normalizedName === 'target') {
            if (!canEditLink || (!isNativeHyperlink && !element.hasAttribute('target'))) { return false; }
          } else if (!canEditLink || !hasHref || (!isNativeHyperlink && !linkRole)) {
            return false;
          }
        }
        if (mediaAttributes.has(normalizedName) && !elementSupportsCapability(element, 'edit-media')) {
          return false;
        }
        if (controlAttributes.has(normalizedName) && !elementSupportsCapability(element, 'edit-control')) {
          return false;
        }
        if (normalizedName === 'value') {
          const valueTag = element.tagName.toLowerCase();
          const validValueTags = new Set([
            'button', 'data', 'input', 'li', 'meter', 'option', 'progress'
          ]);
          const hasRequiredCapability = elementSupportsCapability(element, 'edit-layout');
          if (!validValueTags.has(valueTag) || !hasRequiredCapability) { return false; }
        }
        if (iconAttributes.has(normalizedName) && !elementSupportsCapability(element, 'edit-icon')) {
          return false;
        }
        if (normalizedName === 'aria-label' &&
            !elementSupportsCapability(element, 'edit-control')) {
          return false;
        }
        if (normalizedName === 'src' &&
            !new Set(['audio', 'embed', 'iframe', 'img', 'source', 'track', 'video'])
              .has(element.tagName.toLowerCase())) { return false; }
        if (normalizedName === 'alt' && element.tagName.toLowerCase() !== 'img') { return false; }
        if (normalizedName === 'hidden' && !elementSupportsCapability(element, 'edit-layout')) {
          return false;
        }
        if (removesAttribute === true) {
          element.removeAttribute(name);
        } else {
          element.setAttribute(name, value == null ? '' : String(value));
        }
        collectLayerNodes();
        if (name === 'data-og-id') {
          const nextSelectionID = id.indexOf('ogpl:') === 0 ? id : (value || '').trim();
          if (nextSelectionID) {
            selectNode(nextSelectionID);
            notifySelection(nextSelectionID);
          }
        }
          return true;
        }

        function slug(value) {
          const allowed = 'abcdefghijklmnopqrstuvwxyz0123456789_-';
          let result = '';
          Array.from((value || 'node').toLowerCase()).forEach((character) => {
            result += allowed.indexOf(character) >= 0 ? character : '-';
          });
          while (result.indexOf('--') >= 0) {
            result = result.replaceAll('--', '-');
          }
          result = result.replaceAll('_-', '_').replaceAll('-_', '_');
          if (result.startsWith('-')) { result = result.slice(1); }
          if (result.endsWith('-')) { result = result.slice(0, -1); }
          return result || 'node';
        }

        function uniqueID(base) {
          const existing = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-id') || ''));
          const cleanBase = slug(base);
          let candidate = cleanBase;
          let index = 2;
          while (existing.has(candidate)) {
            candidate = cleanBase + '-' + index;
            index += 1;
          }
          return candidate;
        }

        function editableElementsInside(root) {
          const result = [];
          function visit(node, isTopLevel) {
            if (node.nodeType !== Node.ELEMENT_NODE) { return; }
            if (isTopLevel || node.hasAttribute('data-og-id') || node.hasAttribute('data-og-internal-id')) {
              result.push(node);
            }
            Array.from(node.children).forEach((child) => visit(child, false));
          }
          Array.from(root.childNodes).forEach((node) => visit(node, true));
          return result;
        }

        function normalizeEditableIDs(fragment) {
          const used = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-id') || ''));
          const usedInternalIDs = new Set(allEditableNodes().map((element) => element.getAttribute('data-og-internal-id') || ''));
          editableElementsInside(fragment).forEach((element) => {
            const current = element.getAttribute('data-og-id') || element.tagName.toLowerCase();
            let candidate = slug(current);
            let index = 2;
            while (used.has(candidate)) {
              candidate = slug(current) + '-' + index;
              index += 1;
            }
            element.setAttribute('data-og-id', candidate);
            element.setAttribute('data-og-internal-id', randomInternalID(usedInternalIDs));
            used.add(candidate);
          });
        }

        function textElementFromString(text) {
          const element = document.createElement('p');
          element.setAttribute('data-og-id', uniqueID('text'));
          element.setAttribute('data-og-internal-id', randomInternalID(new Set(allEditableNodes().map((node) => node.getAttribute('data-og-internal-id') || ''))));
          element.textContent = text || '';
          return element;
        }

        function fragmentFromPayload(payload) {
          const fragment = document.createDocumentFragment();
          const html = payload && payload.html ? payload.html : '';
          const text = payload && payload.text ? payload.text : '';
          if (html.trim().length > 0) {
            const template = document.createElement('template');
            template.innerHTML = html;
            fragment.append(template.content.cloneNode(true));
          } else {
            fragment.append(textElementFromString(text));
          }

          if (editableElementsInside(fragment).length === 0) {
            const textContent = fragment.textContent || text || html;
            fragment.replaceChildren(textElementFromString(textContent));
          }

          normalizeEditableIDs(fragment);
          return fragment;
        }

        function firstEditableID(root) {
          const editable = editableElementsInside(root)[0];
          return editable ? editable.getAttribute('data-og-id') || '' : '';
        }

        function newInternalID() {
          return randomInternalID(new Set(allEditableNodes().map((node) => nodeInternalID(node))));
        }

        function createFrameID() {
          return uniqueID('frame');
        }

        function applyDefaultBoxStyles(element, width, height) {
          element.style.setProperty('width', width);
          element.style.setProperty('height', height);
        }

        function lucideInlineSVG(name) {
          if (name === 'circle') {
            return [
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">',
              '<circle cx="12" cy="12" r="10"></circle>',
              '</svg>'
            ].join('');
          }
          return [
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">',
            '<circle cx="12" cy="12" r="10"></circle>',
            '</svg>'
          ].join('');
        }

        function createIconElement() {
          const element = document.createElement('span');
          const iconName = 'circle';
          element.setAttribute('data-og-id', uniqueID('icon'));
          element.setAttribute('data-og-internal-id', newInternalID());
          element.setAttribute('role', 'img');
          element.setAttribute('aria-label', iconName);
          element.setAttribute('data-og-icon-library', 'lucide');
          element.setAttribute('data-og-icon-name', iconName);
          element.setAttribute('data-og-icon-source', 'inline');
          element.innerHTML = lucideInlineSVG(iconName);
          applyDefaultBoxStyles(element, '24px', '24px');
          return element;
        }

        function createFrameElement() {
          const element = document.createElement('div');
          element.setAttribute('data-og-id', createFrameID());
          element.setAttribute('data-og-internal-id', newInternalID());
          element.style.setProperty('display', 'flex');
          element.style.setProperty('flex-direction', 'column');
          element.style.setProperty('gap', '0');
          element.style.setProperty('padding', '0');
          return element;
        }

        function createTextElement() {
          const element = textElementFromString('Text');
          element.style.setProperty('font-size', '16px');
          return element;
        }

        function createdElementForTool(tool) {
          if (tool === 'text') { return createTextElement(); }
          if (tool === 'frame') { return createFrameElement(); }
          if (tool === 'icon') { return createIconElement(); }
          return null;
        }

        function selectedFramePlacementParent() {
          const visualElement = selectedElement();
          const element = editElementForSelectionID(currentSelectedID) || visualElement;
          if (!element || !canReceiveChildren(element) || hasLockedAncestor(element)) {
            return null;
          }
          return element;
        }

        function localPointInElement(element, event) {
          const rect = element.getBoundingClientRect();
          return {
            x: event.clientX - rect.left + (element.scrollLeft || 0),
            y: event.clientY - rect.top + (element.scrollTop || 0)
          };
        }

        function framePlacementRect(placement, event) {
          const point = localPointInElement(placement.parent, event);
          const left = Math.min(placement.startX, point.x);
          const top = Math.min(placement.startY, point.y);
          const width = Math.abs(point.x - placement.startX);
          const height = Math.abs(point.y - placement.startY);
          return { left: left, top: top, width: width, height: height };
        }

        function applyFramePlacementRect(placement, rect) {
          placement.frame.style.setProperty('position', 'absolute');
          placement.frame.style.setProperty('left', pixelString(rect.left));
          placement.frame.style.setProperty('top', pixelString(rect.top));
          placement.frame.style.setProperty('width', pixelString(rect.width));
          placement.frame.style.setProperty('height', pixelString(rect.height));
          placement.lastRect = rect;
        }

        function eventPointerID(event) {
          return event && event.pointerId !== undefined ? event.pointerId : 'mouse';
        }

        function framePlacementMatchesEvent(event) {
          if (!framePlacement) { return false; }
          return framePlacementPointerMatches(framePlacement.pointerID, event);
        }

        function framePlacementPointerMatches(storedPointerID, event) {
          const pointerID = eventPointerID(event);
          return storedPointerID === pointerID ||
            storedPointerID === 'native-mouse' ||
            pointerID === 'native-mouse';
        }

        function pendingFramePlacementMatchesEvent(event) {
          if (!pendingFramePlacement) { return false; }
          return framePlacementPointerMatches(pendingFramePlacement.pointerID, event);
        }

        function framePlacementCandidateFromEvent(event) {
          if (activeTool !== 'frame' || event.button !== primaryPointerButton) { return false; }
          const parent = selectedFramePlacementParent();
          if (!parent) { return false; }
          const anchorInternalID = nodeInternalID(parent);
          if (!anchorInternalID) { return false; }

          const start = localPointInElement(parent, event);
          return {
            pointerID: eventPointerID(event),
            parent: parent,
            anchorInternalID: anchorInternalID,
            startX: start.x,
            startY: start.y,
            startClientX: event.clientX,
            startClientY: event.clientY
          };
        }

        function beginPendingFramePlacement(event) {
          if (framePlacement || pendingFramePlacement) { return true; }
          const candidate = framePlacementCandidateFromEvent(event);
          if (!candidate) { return false; }
          pendingFramePlacement = candidate;
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function selectFrameToolClickTarget(event) {
          const element = editableElementFromTarget(originalEventTarget(event));
          if (!element) { return false; }
          const id = nextSelectionIDForClick(element);
          selectNode(id);
          notifySelection(id);
          collectLayerNodes();
          return true;
        }

        function startFramePlacementIfNeeded(event) {
          if (framePlacement) { return true; }
          if (!pendingFramePlacementMatchesEvent(event)) { return false; }

          const pending = pendingFramePlacement;
          const dragDistance = Math.hypot(
            event.clientX - pending.startClientX,
            event.clientY - pending.startClientY
          );
          if (dragDistance < dragStartThreshold) { return false; }

          pendingFramePlacement = null;
          const frame = createFrameElement();
          pending.parent.append(frame);
          framePlacement = {
            pointerID: pending.pointerID,
            parent: pending.parent,
            frame: frame,
            anchorInternalID: pending.anchorInternalID,
            startX: pending.startX,
            startY: pending.startY,
            startClientX: pending.startClientX,
            startClientY: pending.startClientY,
            lastRect: { left: pending.startX, top: pending.startY, width: 0, height: 0 },
            didDrag: true
          };
          applyFramePlacementRect(framePlacement, framePlacementRect(framePlacement, event));
          updateFrameGuideState();
          try {
            if (event.pointerId !== undefined && typeof frame.setPointerCapture === 'function') {
              frame.setPointerCapture(event.pointerId);
            }
          } catch (_) {}
          suppressNextClick = true;
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function updateFramePlacement(event) {
          if (!framePlacement && !startFramePlacementIfNeeded(event)) { return false; }
          if (!framePlacementMatchesEvent(event)) { return false; }

          const rect = framePlacementRect(framePlacement, event);
          const dragDistance = Math.hypot(rect.width, rect.height);
          framePlacement.didDrag = framePlacement.didDrag || dragDistance >= dragStartThreshold;
          applyFramePlacementRect(framePlacement, rect);
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function finishFramePlacement(cancelled) {
          const placement = framePlacement;
          framePlacement = null;
          pendingFramePlacement = null;
          updateFrameGuideState();
          if (!placement) { return; }
          try {
            if (placement.pointerID !== 'mouse' && typeof placement.frame.releasePointerCapture === 'function') {
              placement.frame.releasePointerCapture(placement.pointerID);
            }
          } catch (_) {}

          const rect = placement.lastRect || { width: 0, height: 0 };
          const shouldInsert = !cancelled &&
            placement.didDrag &&
            rect.width >= minimumFramePlacementSize &&
            rect.height >= minimumFramePlacementSize;
          if (!shouldInsert) {
            placement.frame.remove();
            collectLayerNodes();
            return;
          }

          const selectedID = elementID(placement.frame);
          const html = placement.frame.outerHTML;
          collectLayerNodes();
          selectNode(selectedID);
          notifySelection(selectedID);
          collectStaticFlowLinks();
          notifyDocumentChange({
            operation: 'insertHTML',
            selectedID: selectedID,
            anchorInternalID: placement.anchorInternalID,
            position: 'append',
            html: html
          });
        }

        function finishFramePlacementFromEvent(event, cancelled) {
          if (!framePlacementMatchesEvent(event)) {
            if (pendingFramePlacementMatchesEvent(event)) {
              pendingFramePlacement = null;
              if (!cancelled && selectFrameToolClickTarget(event)) {
                suppressNextClick = true;
                event.preventDefault();
                event.stopPropagation();
                return true;
              }
              if (cancelled) {
                event.preventDefault();
                event.stopPropagation();
                return true;
              }
            }
            return false;
          }
          if (!cancelled) {
            const rect = framePlacementRect(framePlacement, event);
            const dragDistance = Math.hypot(rect.width, rect.height);
            framePlacement.didDrag = framePlacement.didDrag || dragDistance >= dragStartThreshold;
            applyFramePlacementRect(framePlacement, rect);
          }
          finishFramePlacement(cancelled);
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function framePlacementNativeEvent(clientX, clientY, button) {
          return {
            clientX: clientX,
            clientY: clientY,
            button: button === undefined ? primaryPointerButton : button,
            pointerId: 'native-mouse',
            target: document.elementFromPoint(clientX, clientY),
            preventDefault: function() {},
            stopPropagation: function() {}
          };
        }

        function handleFramePlacementNativeEvent(kind, clientX, clientY, button) {
          const event = framePlacementNativeEvent(clientX, clientY, button);
          if (kind === 'down') {
            return beginPendingFramePlacement(event);
          }
          if (kind === 'move') {
            return updateFramePlacement(event);
          }
          if (kind === 'up') {
            return finishFramePlacementFromEvent(event, false);
          }
          if (kind === 'cancel') {
            return finishFramePlacementFromEvent(event, true);
          }
          return false;
        }

        function placeCreatedElement(event) {
          const created = createdElementForTool(activeTool);
          if (!created) { return false; }

          const anchor = editableElementFromTarget(originalEventTarget(event)) || selectedElement();
          if (!anchor || hasLockedAncestor(anchor)) { return false; }

          const appendToAnchor = canReceiveChildren(anchor);
          const parent = appendToAnchor ? anchor : anchor.parentElement;
          if (!parent || hasLockedAncestor(parent)) { return false; }
          if (!appendToAnchor && !canReceiveChildren(parent)) { return false; }

          const position = appendToAnchor ? 'append' : 'after';
          const anchorInternalID = nodeInternalID(anchor);
          if (!anchorInternalID) { return false; }

          const html = created.outerHTML;
          if (appendToAnchor) {
            anchor.append(created);
          } else {
            anchor.after(created);
          }

          const selectedID = elementID(created);
          collectLayerNodes();
          selectNode(selectedID);
          notifySelection(selectedID);
          collectStaticFlowLinks();
          notifyDocumentChange({
            operation: 'insertHTML',
            selectedID: selectedID,
            anchorInternalID: anchorInternalID,
            position: position,
            html: html
          });
          return true;
        }

        function parseScaleAxes(value) {
          const normalized = String(value || '').trim();
          if (!normalized || normalized.toLowerCase() === 'none') {
            return { axes: ['1', '1'], sourceCount: 0 };
          }
          const tokens = normalized.split(/\\s+/).filter((token) => token.length > 0);
          if (tokens.length < 1 || tokens.length > 3) { return null; }
          const numericScalePattern = /^[+-]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?%?$/;
          if (!tokens.every((token) => numericScalePattern.test(token))) { return null; }
          if (tokens.length === 1) {
            return { axes: [tokens[0], tokens[0]], sourceCount: 1 };
          }
          return { axes: tokens.slice(), sourceCount: tokens.length };
        }

        function negatedScaleAxis(value) {
          const normalized = String(value || '').trim();
          if (normalized.startsWith('-')) {
            return normalized.slice(1) || '0';
          }
          if (normalized.startsWith('+')) {
            return '-' + normalized.slice(1);
          }
          return '-' + normalized;
        }

        function serializedScaleAxes(parsed, axisIndex) {
          if (!parsed || !Array.isArray(parsed.axes) || parsed.axes.length < 2) { return ''; }
          const axes = parsed.axes.slice();
          axes[axisIndex] = negatedScaleAxis(axes[axisIndex]);
          if (parsed.sourceCount === 3 && axes.length === 3) {
            return axes.join(' ');
          }
          return axes.slice(0, 2).join(' ');
        }

        function numericScaleAxis(value) {
          const normalized = String(value || '').trim();
          const number = Number.parseFloat(normalized);
          if (!Number.isFinite(number)) { return null; }
          return normalized.endsWith('%') ? number / 100 : number;
        }

        function equivalentScaleValues(first, second) {
          const firstParsed = parseScaleAxes(first);
          const secondParsed = parseScaleAxes(second);
          if (!firstParsed || !secondParsed) { return false; }
          const count = Math.max(firstParsed.axes.length, secondParsed.axes.length, 2);
          for (let index = 0; index < count; index += 1) {
            const firstAxis = numericScaleAxis(firstParsed.axes[index] || '1');
            const secondAxis = numericScaleAxis(secondParsed.axes[index] || '1');
            if (firstAxis === null || secondAxis === null || Math.abs(firstAxis - secondAxis) > 0.000001) {
              return false;
            }
          }
          return true;
        }

        function computedScaleValue(element) {
          try {
            return window.getComputedStyle(element).getPropertyValue('scale') || 'none';
          } catch (_) {
            return 'none';
          }
        }

        function authoredScaleInput(payload) {
          const hasAuthoredScale = !!payload &&
            (payload.hasAuthoredScale === true || payload.hasAuthoredScale === 'true');
          return {
            isPresent: hasAuthoredScale,
            value: hasAuthoredScale ? String(payload.authoredScale || '').trim() : ''
          };
        }

        function flippedScaleValue(element, axisIndex, scaleInput) {
          if (!element || (axisIndex !== 0 && axisIndex !== 1)) { return ''; }
          let parsed = null;
          if (scaleInput && scaleInput.isPresent) {
            parsed = parseScaleAxes(scaleInput.value);
            if (!parsed) { return ''; }
          } else {
            const computed = computedScaleValue(element);
            if (!equivalentScaleValues(computed, '1 1')) { return ''; }
            parsed = parseScaleAxes('none');
          }
          const nextValue = serializedScaleAxes(parsed, axisIndex);
          if (!nextValue || (window.CSS && typeof window.CSS.supports === 'function' && !window.CSS.supports('scale', nextValue))) {
            return '';
          }
          return nextValue;
        }

        function flipScaleAxis(element, axisIndex, payload) {
          const scaleInput = authoredScaleInput(payload);
          const previousValue = scaleInput.isPresent ? scaleInput.value : '';
          const nextValue = flippedScaleValue(element, axisIndex, scaleInput);
          if (!nextValue) { return null; }
          const priority = element.style.getPropertyPriority('scale') || '';
          element.style.setProperty('scale', nextValue, priority);
          if (!equivalentScaleValues(computedScaleValue(element), nextValue) && priority !== 'important') {
            element.style.setProperty('scale', nextValue, 'important');
          }
          return { previousValue: previousValue, value: nextValue };
        }

        function layerCandidatesFor(element) {
          const result = [];
          let current = element;
          while (current && current !== document.documentElement) {
            if (isInspectableElement(current)) {
              const capabilityPayload = nodeCapabilityPayload(current);
              result.push({
                id: selectionIDForElement(current),
                tagName: current.tagName.toLowerCase(),
                legacyTypeHint: current.getAttribute('data-og-type') || '',
                capabilities: capabilityPayload.capabilities,
                role: current.getAttribute('role') || ''
              });
            }
            current = current.parentElement;
          }
          return result;
        }

        function allowsOverflowScroll(value) {
          return value === 'auto' || value === 'scroll' || value === 'overlay';
        }

        let lastPointer = null;
        let lastScrollStateSignature = '';

        function emptyScrollState(isInside) {
          return {
            inside: !!isInside,
            up: false,
            down: false,
            left: false,
            right: false,
            elementUp: false,
            elementDown: false,
            elementLeft: false,
            elementRight: false
          };
        }

        function scrollStateForElement(element, includeDocument) {
          if (!element || element.nodeType !== Node.ELEMENT_NODE) {
            return emptyScrollState(true);
          }

          const style = window.getComputedStyle(element);
          const epsilon = 0;
          const canScrollY = (includeDocument || allowsOverflowScroll(style.overflowY)) &&
            element.scrollHeight > element.clientHeight + epsilon;
          const canScrollX = (includeDocument || allowsOverflowScroll(style.overflowX)) &&
            element.scrollWidth > element.clientWidth + epsilon;

          return {
            inside: true,
            up: canScrollY && element.scrollTop > epsilon,
            down: canScrollY && element.scrollTop + element.clientHeight < element.scrollHeight - epsilon,
            left: canScrollX && element.scrollLeft > epsilon,
            right: canScrollX && element.scrollLeft + element.clientWidth < element.scrollWidth - epsilon
          };
        }

        function mergeScrollState(into, state) {
          into.up = into.up || state.up;
          into.down = into.down || state.down;
          into.left = into.left || state.left;
          into.right = into.right || state.right;
          return into;
        }

        function mergeElementScrollState(into, state) {
          into.elementUp = into.elementUp || state.up;
          into.elementDown = into.elementDown || state.down;
          into.elementLeft = into.elementLeft || state.left;
          into.elementRight = into.elementRight || state.right;
          return into;
        }

        function scrollStateForTarget(target) {
          const result = emptyScrollState(!!target);
          let element = target;
          while (element && element.nodeType !== Node.ELEMENT_NODE) {
            element = element.parentElement;
          }

          while (element && element !== document.documentElement) {
            const elementState = scrollStateForElement(element, false);
            mergeScrollState(result, elementState);
            mergeElementScrollState(result, elementState);
            element = element.parentElement;
          }

          const scrollingElement = document.scrollingElement || document.documentElement;
          mergeScrollState(result, scrollStateForElement(scrollingElement, true));
          return result;
        }

        function postScrollState(state) {
          const signature = [
            state.inside,
            state.up,
            state.down,
            state.left,
            state.right,
            state.elementUp,
            state.elementDown,
            state.elementLeft,
            state.elementRight
          ].join(':');
          if (signature === lastScrollStateSignature) { return; }
          lastScrollStateSignature = signature;
          window.webkit.messageHandlers.openGraphiteScrollState.postMessage(state);
        }

        function updateScrollStateAt(clientX, clientY) {
          lastPointer = { x: clientX, y: clientY };
          postScrollState(scrollStateForTarget(document.elementFromPoint(clientX, clientY)));
        }

        function updateLastPointerScrollState() {
          if (!lastPointer) { return; }
          updateScrollStateAt(lastPointer.x, lastPointer.y);
        }

        function markPointerOutside() {
          lastPointer = null;
          postScrollState(emptyScrollState(false));
        }

        function numericPixelValue(value, fallback) {
          const trimmed = (value || '').trim();
          if (trimmed.length === 0) { return fallback; }
          if (/^-?\\d+(\\.\\d+)?(px)?$/.test(trimmed)) {
            return Number.parseFloat(trimmed);
          }
          return fallback;
        }

        function stylePixelValue(element, key, fallback) {
          return numericPixelValue(element.style.getPropertyValue(key), fallback);
        }

        function computedPosition(element) {
          if (!element) { return ''; }
          try {
            return String(window.getComputedStyle(element).position || '').trim().toLowerCase();
          } catch (_) {
            return '';
          }
        }

        function participatesInFlow(element) {
          const position = computedPosition(element);
          return position !== 'absolute' && position !== 'fixed';
        }

        function canPositionDrag(element) {
          return elementSupportsCapability(element, 'drag-position');
        }

        function dragStartValue(element, key, absoluteFallback) {
          const position = computedPosition(element);
          const fallback = position === 'absolute' || position === 'fixed' ? absoluteFallback : 0;
          return stylePixelValue(element, key, fallback);
        }

        function pixelString(value) {
          const rounded = Math.round(value * 10) / 10;
          const normalized = Math.abs(rounded) < 0.05 ? 0 : rounded;
          return normalized + 'px';
        }

        function inlineStyleState(element, property) {
          const hadStyleAttribute = element.hasAttribute('style');
          return {
            hadStyleAttribute: hadStyleAttribute,
            attributeValue: hadStyleAttribute ? element.getAttribute('style') || '' : '',
            value: element.style.getPropertyValue(property),
            priority: element.style.getPropertyPriority(property)
          };
        }

        function restoreInlineStyleState(element, property, state) {
          if (state && Object.prototype.hasOwnProperty.call(state, 'attributeValue')) {
            if (state.hadStyleAttribute) {
              element.setAttribute('style', state.attributeValue);
            } else {
              element.removeAttribute('style');
            }
            return;
          }
          if (state && state.value) {
            element.style.setProperty(property, state.value, state.priority || '');
          } else {
            element.style.removeProperty(property);
          }
          if ((!state || !state.hadStyleAttribute) && element.style.length === 0) {
            element.removeAttribute('style');
          }
        }

        function attributeState(element, name) {
          return {
            isPresent: element.hasAttribute(name),
            value: element.getAttribute(name) || ''
          };
        }

        function restoreAttributeState(element, name, state) {
          if (state && state.isPresent) {
            element.setAttribute(name, state.value);
          } else {
            element.removeAttribute(name);
          }
        }

        function autoLayoutMode(parent) {
          if (!parent) { return ''; }
          const style = computedStylePayload(parent);
          const display = style.display.toLowerCase();
          if (display === 'flex' || display === 'inline-flex') {
            return style.flexDirection.toLowerCase().startsWith('row') ? 'horizontal' : 'vertical';
          }
          if (display === 'grid' || display === 'inline-grid') {
            return style.gridAutoFlow.toLowerCase().startsWith('column') ? 'vertical' : 'horizontal';
          }
          if (display === 'inline') { return 'horizontal'; }
          if (display === 'block' || display === 'flow-root' || display === 'list-item' ||
              display.startsWith('table')) {
            return 'vertical';
          }
          return '';
        }

        function reorderFlowSiblings(parent) {
          return editableElementChildren(parent).filter((child) => {
            return participatesInFlow(child) && editableSourceElement(child);
          });
        }

        function elementOrdersMatch(first, second) {
          return first.length === second.length && first.every((element, index) => element === second[index]);
        }

        function visualOrderForReorder(siblings, axis) {
          const entries = siblings.map((element) => {
            const rect = visualElementForDragElement(element).getBoundingClientRect();
            return { element: element, center: reorderAxisValue(axis, rect) };
          }).sort((first, second) => first.center - second.center);
          for (let index = 1; index < entries.length; index += 1) {
            if (Math.abs(entries[index].center - entries[index - 1].center) < 0.5) {
              return null;
            }
          }
          return entries.map((entry) => entry.element);
        }

        function measuredDOMInsertionDirection(siblings, axis, allowReverse) {
          const visualOrder = visualOrderForReorder(siblings, axis);
          if (!visualOrder) { return ''; }
          if (elementOrdersMatch(visualOrder, siblings)) { return 'forward'; }
          if (allowReverse && elementOrdersMatch(visualOrder, siblings.slice().reverse())) { return 'reverse'; }
          return '';
        }

        function siblingsShareSingleVisualLine(siblings, axis) {
          let commonStart = Number.NEGATIVE_INFINITY;
          let commonEnd = Number.POSITIVE_INFINITY;
          siblings.forEach((element) => {
            const rect = visualElementForDragElement(element).getBoundingClientRect();
            const start = axis === 'x' ? rect.top : rect.left;
            const end = axis === 'x' ? rect.bottom : rect.right;
            commonStart = Math.max(commonStart, start);
            commonEnd = Math.min(commonEnd, end);
          });
          return commonStart <= commonEnd + 0.5;
        }

        function usesDefaultReorderPlacement(element) {
          try {
            const style = window.getComputedStyle(element);
            if (String(style.order || '').trim() !== '0') { return false; }
            return ['gridRowStart', 'gridRowEnd', 'gridColumnStart', 'gridColumnEnd'].every((key) => {
              return String(style[key] || '').trim().toLowerCase() === 'auto';
            });
          } catch (_) {
            return false;
          }
        }

        function usesDefaultFlexOrder(element) {
          try {
            return String(window.getComputedStyle(element).order || '').trim() === '0';
          } catch (_) {
            return false;
          }
        }

        function reorderLayoutDescriptor(parent) {
          if (!parent) { return null; }
          const siblings = reorderFlowSiblings(parent);
          if (siblings.length < 2) { return null; }

          let style = null;
          try {
            style = window.getComputedStyle(parent);
          } catch (_) {
            return null;
          }
          const display = String(style.display || '').trim().toLowerCase();
          let axis = '';
          let allowReverse = false;

          if (display === 'flex' || display === 'inline-flex') {
            if (String(style.flexWrap || '').trim().toLowerCase() !== 'nowrap') { return null; }
            if (!siblings.every(usesDefaultFlexOrder)) { return null; }
            axis = String(style.flexDirection || '').trim().toLowerCase().startsWith('row') ? 'x' : 'y';
            allowReverse = true;
          } else if (display === 'grid' || display === 'inline-grid') {
            if (!siblings.every(usesDefaultReorderPlacement)) { return null; }
            axis = String(style.gridAutoFlow || '').trim().toLowerCase().startsWith('column') ? 'y' : 'x';
            if (!siblingsShareSingleVisualLine(siblings, axis)) { return null; }
            allowReverse = true;
          } else if (display === 'block' || display === 'flow-root' || display === 'list-item' ||
                     display.startsWith('table')) {
            axis = 'y';
          } else {
            return null;
          }

          const domInsertionDirection = measuredDOMInsertionDirection(siblings, axis, allowReverse);
          if (!domInsertionDirection) { return null; }
          return { axis: axis, domInsertionDirection: domInsertionDirection };
        }

        function canReorderElement(element, descriptor) {
          const parent = element ? element.parentElement : null;
          const layoutDescriptor = descriptor || reorderLayoutDescriptor(parent);
          return canDragElement(element) &&
            elementSupportsCapability(element, 'reorder-flow') &&
            participatesInFlow(element) &&
            !!layoutDescriptor &&
            reorderFlowSiblings(parent).some((child) => child !== element);
        }

        function runtimeHostForGeneratedElement(element) {
          const runtime = window.OpenGraphiteRuntime;
          if (!runtime || typeof runtime.isGenerated !== 'function' || !runtime.isGenerated(element)) {
            return null;
          }
          return typeof runtime.instanceFor === 'function' ? runtime.instanceFor(element) : null;
        }

        function visualElementForDragElement(element) {
          if (!element) { return null; }
          const runtime = window.OpenGraphiteRuntime;
          if (runtime && typeof runtime.isExpanded === 'function' && runtime.isExpanded(element)) {
            return typeof runtime.generatedRootFor === 'function' ? runtime.generatedRootFor(element) || element : element;
          }
          return element;
        }

        function reorderElementForChainElement(element) {
          if (canReorderElement(element)) { return element; }
          const runtimeHost = runtimeHostForGeneratedElement(element);
          return canReorderElement(runtimeHost) ? runtimeHost : null;
        }

        function reorderCandidateForChain(chain) {
          for (const candidate of chain.slice().reverse()) {
            const reorderElement = reorderElementForChainElement(candidate);
            if (reorderElement) { return reorderElement; }
          }
          return null;
        }

        function reorderAxisValue(axis, rect) {
          return axis === 'x' ? rect.left + rect.width / 2 : rect.top + rect.height / 2;
        }

        function reorderPositionAlreadyApplied(drag, target, position) {
          const siblings = editableElementChildren(drag.parent).filter(participatesInFlow);
          const sourceIndex = siblings.indexOf(drag.element);
          const targetIndex = siblings.indexOf(target);
          if (sourceIndex < 0 || targetIndex < 0) { return true; }
          if (position === 'before') {
            return sourceIndex === targetIndex - 1;
          }
          return sourceIndex === targetIndex + 1;
        }

        function cancelReorderAnimation(element) {
          if (!element) { return; }
          const animation = reorderAnimations.get(element);
          if (animation) {
            animation.cancel();
            reorderAnimations.delete(element);
          }
        }

        function animateReorderSiblings(parent, draggedElement, mutate) {
          const siblings = editableElementChildren(parent).filter((child) => child !== draggedElement);
          const previousRects = new Map();
          siblings.forEach((child) => {
            const visualChild = visualElementForDragElement(child);
            previousRects.set(child, visualChild.getBoundingClientRect());
          });

          mutate();

          siblings.forEach((child) => {
            const previousRect = previousRects.get(child);
            if (!previousRect) { return; }
            const visualChild = visualElementForDragElement(child);
            const nextRect = visualChild.getBoundingClientRect();
            const deltaX = previousRect.left - nextRect.left;
            const deltaY = previousRect.top - nextRect.top;
            if (Math.abs(deltaX) < 0.5 && Math.abs(deltaY) < 0.5) { return; }
            cancelReorderAnimation(visualChild);
            const animation = visualChild.animate(
              [
                { translate: pixelString(deltaX) + ' ' + pixelString(deltaY) },
                { translate: '0px 0px' }
              ],
              {
                duration: 160,
                easing: 'cubic-bezier(.2,0,.2,1)',
                composite: 'add'
              }
            );
            reorderAnimations.set(visualChild, animation);
            animation.addEventListener('finish', function() {
              if (reorderAnimations.get(visualChild) === animation) {
                reorderAnimations.delete(visualChild);
              }
            }, { once: true });
          });
        }

        function reorderPlacementForDrag(drag) {
          const siblings = editableElementChildren(drag.parent).filter((child) => {
            return child !== drag.element && participatesInFlow(child) && editableSourceElement(child);
          });
          if (siblings.length === 0) { return null; }

          const visualSiblings = visualOrderForReorder(siblings, drag.axis);
          if (!visualSiblings) { return null; }

          const baseRect = drag.baseRect || drag.visualElement.getBoundingClientRect();
          const dragRect = {
            left: baseRect.left + (drag.deltaX || 0),
            top: baseRect.top + (drag.deltaY || 0),
            width: baseRect.width,
            height: baseRect.height
          };
          const dragCenter = reorderAxisValue(drag.axis, dragRect);
          for (const sibling of visualSiblings) {
            const rect = visualElementForDragElement(sibling).getBoundingClientRect();
            const siblingCenter = reorderAxisValue(drag.axis, rect);
            if (dragCenter < siblingCenter) {
              return {
                target: sibling,
                position: drag.domInsertionDirection === 'reverse' ? 'after' : 'before'
              };
            }
          }

          return {
            target: visualSiblings[visualSiblings.length - 1],
            position: drag.domInsertionDirection === 'reverse' ? 'before' : 'after'
          };
        }

        function applyReorderPlacement(drag, placement) {
          if (!placement || !placement.target || placement.target === drag.element) { return; }
          if (!editableSourceElement(placement.target)) { return; }
          if (reorderPositionAlreadyApplied(drag, placement.target, placement.position)) { return; }

          animateReorderSiblings(drag.parent, drag.element, function() {
            if (placement.position === 'before') {
              placement.target.before(drag.element);
            } else {
              placement.target.after(drag.element);
            }
          });
          drag.didReorder = true;
        }

        function draggedBaseRect(drag) {
          const element = drag.visualElement || drag.element;
          const deltaX = drag.deltaX || 0;
          const deltaY = drag.deltaY || 0;
          if (drag.translationAnimation) {
            drag.translationAnimation.cancel();
            drag.translationAnimation = null;
          }
          const rect = element.getBoundingClientRect();
          if (deltaX !== 0 || deltaY !== 0) {
            applyReorderDragTranslation(drag, deltaX, deltaY);
          }
          return rect;
        }

        function updateReorderDraggedElementPosition(drag, event) {
          const baseRect = draggedBaseRect(drag);
          const nextX = event.clientX - drag.pointerOffsetX - baseRect.left;
          const nextY = event.clientY - drag.pointerOffsetY - baseRect.top;
          drag.baseRect = baseRect;
          drag.deltaX = nextX;
          drag.deltaY = nextY;
          applyReorderDragTranslation(drag, nextX, nextY);
          drag.didMove = true;
        }

        function updateReorderDrag(drag, event) {
          updateReorderDraggedElementPosition(drag, event);
          applyReorderPlacement(drag, reorderPlacementForDrag(drag));
          updateReorderDraggedElementPosition(drag, event);
        }

        function applyPositionDragTranslation(drag, deltaX, deltaY) {
          if (!drag || !drag.element || typeof drag.element.animate !== 'function') { return false; }
          const keyframes = [{ translate: pixelString(deltaX) + ' ' + pixelString(deltaY) }];
          if (drag.translationAnimation && drag.translationAnimation.effect &&
              typeof drag.translationAnimation.effect.setKeyframes === 'function') {
            drag.translationAnimation.effect.setKeyframes(keyframes);
            return true;
          }
          drag.translationAnimation = drag.element.animate(
            keyframes,
            { duration: 1, fill: 'both', composite: 'add' }
          );
          drag.translationAnimation.pause();
          drag.translationAnimation.currentTime = 0;
          return true;
        }

        function applyReorderDragTranslation(drag, deltaX, deltaY) {
          const element = drag && (drag.visualElement || drag.element);
          if (!element || typeof element.animate !== 'function') { return false; }
          const keyframes = [{ translate: pixelString(deltaX) + ' ' + pixelString(deltaY) }];
          if (drag.translationAnimation && drag.translationAnimation.effect &&
              typeof drag.translationAnimation.effect.setKeyframes === 'function') {
            drag.translationAnimation.effect.setKeyframes(keyframes);
            return true;
          }
          if (drag.translationAnimation) {
            drag.translationAnimation.cancel();
          }
          drag.translationAnimation = element.animate(
            keyframes,
            { duration: 1, fill: 'both', composite: 'add' }
          );
          drag.translationAnimation.pause();
          drag.translationAnimation.currentTime = 0;
          return true;
        }

        function updateDraggedElementPosition(drag, event) {
          const deltaX = event.clientX - drag.startClientX;
          const deltaY = event.clientY - drag.startClientY;
          drag.deltaX = deltaX;
          drag.deltaY = deltaY;
          applyPositionDragTranslation(drag, deltaX, deltaY);
          drag.didMove = true;
        }

        function cleanupActiveDragStyles(drag) {
          if (!drag || !drag.element) { return; }
          if (drag.presentationAnimation) {
            drag.presentationAnimation.cancel();
          }
          if (drag.translationAnimation) {
            drag.translationAnimation.cancel();
          }
        }

        function restoreReorderOrigin(drag) {
          if (!drag || !drag.parent || drag.element.parentElement !== drag.parent) { return; }
          animateReorderSiblings(drag.parent, drag.element, function() {
            restoreReorderOriginWithoutAnimation(drag);
          });
        }

        function restoreReorderOriginWithoutAnimation(drag) {
          if (!drag || !drag.parent || drag.element.parentElement !== drag.parent) { return; }
          if (drag.originalNextSibling &&
              drag.originalNextSibling.parentNode === drag.parent &&
              drag.originalNextSibling !== drag.element) {
            drag.parent.insertBefore(drag.element, drag.originalNextSibling);
          } else {
            drag.parent.appendChild(drag.element);
          }
        }

        function reorderEditPayload(drag) {
          const siblings = editableElementChildren(drag.parent).filter(participatesInFlow);
          const finalIndex = siblings.indexOf(drag.element);
          if (finalIndex < 0 || finalIndex === drag.startIndex) { return null; }

          const previousSibling = finalIndex > 0 ? siblings[finalIndex - 1] : null;
          const nextSibling = finalIndex < siblings.length - 1 ? siblings[finalIndex + 1] : null;
          if (previousSibling && editableSourceElement(previousSibling)) {
            return {
              operation: 'moveNode',
              nodeID: drag.selectedID,
              nodeInternalID: nodeInternalID(drag.element),
              targetInternalID: nodeInternalID(previousSibling),
              position: 'after'
            };
          }
          if (nextSibling && editableSourceElement(nextSibling)) {
            return {
              operation: 'moveNode',
              nodeID: drag.selectedID,
              nodeInternalID: nodeInternalID(drag.element),
              targetInternalID: nodeInternalID(nextSibling),
              position: 'before'
            };
          }
          return null;
        }

        function beginPendingDrag(event) {
          if (activeTool !== 'select' || event.button !== primaryPointerButton) { return; }
          const element = editableElementFromTarget(originalEventTarget(event));
          if (!element) { return; }

          const chain = selectableChainFor(element);
          const dragElement = draggableElementForChain(chain);
          if (!dragElement) { return; }

          pendingDrag = {
            pointerID: event.pointerId,
            element: dragElement,
            selectedID: selectionIDForElement(dragElement),
            startClientX: event.clientX,
            startClientY: event.clientY
          };
          event.preventDefault();
          event.stopPropagation();
        }

        function startActiveDragIfNeeded(event) {
          if (!pendingDrag || pendingDrag.pointerID !== event.pointerId) { return false; }
          const deltaX = event.clientX - pendingDrag.startClientX;
          const deltaY = event.clientY - pendingDrag.startClientY;
          if (Math.hypot(deltaX, deltaY) < dragStartThreshold) { return false; }

          const element = pendingDrag.element;
          const selectedID = pendingDrag.selectedID;
          const visualElement = visualElementForDragElement(element);
          const startRect = visualElement.getBoundingClientRect();
          const layout = autoLayoutMode(element.parentElement);
          const reorderDescriptor = reorderLayoutDescriptor(element.parentElement);
          if (layout && participatesInFlow(element) && !canReorderElement(element, reorderDescriptor)) {
            pendingDrag = null;
            return false;
          }
          if (canReorderElement(element, reorderDescriptor)) {
            activeDrag = {
              mode: 'reorder',
              pointerID: pendingDrag.pointerID,
              element: element,
              visualElement: visualElement,
              parent: element.parentElement,
              selectedID: selectedID,
              startClientX: pendingDrag.startClientX,
              startClientY: pendingDrag.startClientY,
              pointerOffsetX: pendingDrag.startClientX - startRect.left,
              pointerOffsetY: pendingDrag.startClientY - startRect.top,
              axis: reorderDescriptor.axis,
              domInsertionDirection: reorderDescriptor.domInsertionDirection,
              originalNextSibling: element.nextSibling,
              startIndex: editableElementChildren(element.parentElement).filter(participatesInFlow).indexOf(element),
              deltaX: 0,
              deltaY: 0,
              translationAnimation: null,
              didMove: false,
              didReorder: false
            };
          } else if (canPositionDrag(element)) {
            activeDrag = {
              mode: 'position',
              pointerID: pendingDrag.pointerID,
              element: element,
              selectedID: selectedID,
              startClientX: pendingDrag.startClientX,
              startClientY: pendingDrag.startClientY,
              startX: dragStartValue(element, 'left', element.offsetLeft || 0),
              startY: dragStartValue(element, 'top', element.offsetTop || 0),
              previousValues: {
                'left': element.style.getPropertyValue('left') || '',
                'top': element.style.getPropertyValue('top') || ''
              },
              previousStyleStates: {
                'left': inlineStyleState(element, 'left'),
                'top': inlineStyleState(element, 'top')
              },
              deltaX: 0,
              deltaY: 0,
              translationAnimation: null,
              didMove: false
            };
          } else {
            pendingDrag = null;
            return false;
          }
          const dragVisualElement = activeDrag.visualElement || element;
          if (typeof dragVisualElement.animate === 'function') {
            activeDrag.presentationAnimation = dragVisualElement.animate(
              [{
                cursor: 'grabbing',
                filter: 'drop-shadow(0 14px 24px rgba(0,0,0,.28))',
                pointerEvents: activeDrag.mode === 'reorder' ? 'none' : 'auto',
                zIndex: '2147483647'
              }],
              { duration: 1, fill: 'both' }
            );
          }
          pendingDrag = null;
          suppressNextClick = true;
          selectNode(selectedID);
          notifySelection(selectedID);
          return true;
        }

        function updateActiveDrag(event) {
          if (!activeDrag || activeDrag.pointerID !== event.pointerId) { return false; }
          if ((event.buttons & pointerDragButtons) === 0) {
            finishActiveDrag(false);
            return false;
          }

          if (activeDrag.mode === 'reorder') {
            updateReorderDrag(activeDrag, event);
          } else {
            updateDraggedElementPosition(activeDrag, event);
          }
          scheduleSelectionOverlayUpdate();
          postNodeDragPreview(activeDrag);
          event.preventDefault();
          event.stopPropagation();
          return true;
        }

        function restorePositionDragValues(drag) {
          Object.entries(drag.previousStyleStates || {}).forEach(([key, state]) => {
            restoreInlineStyleState(drag.element, key, state);
          });
        }

        function finishReorderDrag(drag, cancelled) {
          let edit = null;
          if (cancelled) {
            restoreReorderOrigin(drag);
          } else if (drag.didMove && drag.didReorder) {
            edit = reorderEditPayload(drag);
            if (!edit) {
              restoreReorderOrigin(drag);
            }
          }

          cleanupActiveDragStyles(drag);
          if (!edit) {
            collectLayerNodes();
            return;
          }

          collectLayerNodes();
          notifyDocumentChange(edit);
        }

        function finishActiveDrag(cancelled) {
          pendingDrag = null;
          const drag = activeDrag;
          activeDrag = null;
          if (!drag) { return; }
          if (drag.mode === 'reorder') {
            finishReorderDrag(drag, cancelled);
            clearNodeDragPreview();
            return;
          }
          if (cancelled) {
            cleanupActiveDragStyles(drag);
            restorePositionDragValues(drag);
            collectLayerNodes();
            clearNodeDragPreview();
            return;
          }
          if (!drag.didMove) {
            cleanupActiveDragStyles(drag);
            clearNodeDragPreview();
            return;
          }
          drag.element.style.setProperty('left', pixelString(drag.startX + (drag.deltaX || 0)));
          drag.element.style.setProperty('top', pixelString(drag.startY + (drag.deltaY || 0)));
          cleanupActiveDragStyles(drag);
          collectLayerNodes();
          notifyDocumentChange({
            operation: 'setCSSVariables',
            nodeID: drag.selectedID,
            nodeInternalID: nodeInternalID(drag.element),
            values: {
              'left': drag.element.style.getPropertyValue('left') || '',
              'top': drag.element.style.getPropertyValue('top') || ''
            },
            previousValues: drag.previousValues || {}
          });
          clearNodeDragPreview();
        }

        function suspendTransientStateForSerialization() {
          const state = { editing: null, drag: null, frame: null, placements: null };

          if (editingTextElement && editingPresentationState) {
            state.editing = {
              element: editingTextElement,
              livePresentation: captureTextEditingPresentation(editingTextElement)
            };
            restoreTextEditingPresentation(editingTextElement, editingPresentationState);
          }

          if (activeDrag && activeDrag.element) {
            if (activeDrag.mode === 'reorder') {
              state.drag = {
                mode: 'reorder',
                element: activeDrag.element,
                parent: activeDrag.parent,
                nextSibling: activeDrag.element.nextSibling
              };
              restoreReorderOriginWithoutAnimation(activeDrag);
            } else {
              state.drag = {
                mode: 'position',
                element: activeDrag.element,
                liveLeft: inlineStyleState(activeDrag.element, 'left'),
                liveTop: inlineStyleState(activeDrag.element, 'top')
              };
              restorePositionDragValues(activeDrag);
            }
          }

          if (framePlacement && framePlacement.frame && framePlacement.frame.isConnected) {
            state.frame = {
              element: framePlacement.frame,
              parent: framePlacement.frame.parentNode,
              nextSibling: framePlacement.frame.nextSibling
            };
            framePlacement.frame.remove();
          }
          const placementController = window.OpenGraphiteComponentPlacementReferences;
          if (placementController && typeof placementController.suspend === 'function') {
            state.placements = placementController.suspend();
          }
          return state;
        }

        function resumeTransientStateAfterSerialization(state) {
          if (!state || typeof state !== 'object') { return; }

          const placementController = window.OpenGraphiteComponentPlacementReferences;
          if (placementController && typeof placementController.resume === 'function') {
            placementController.resume(state.placements);
          }

          if (state.frame && state.frame.parent && state.frame.parent.isConnected) {
            state.frame.parent.insertBefore(
              state.frame.element,
              state.frame.nextSibling && state.frame.nextSibling.parentNode === state.frame.parent
                ? state.frame.nextSibling
                : null
            );
          }

          if (state.drag && state.drag.element && state.drag.element.isConnected) {
            if (state.drag.mode === 'reorder') {
              if (state.drag.parent && state.drag.parent.isConnected) {
                state.drag.parent.insertBefore(
                  state.drag.element,
                  state.drag.nextSibling && state.drag.nextSibling.parentNode === state.drag.parent
                    ? state.drag.nextSibling
                    : null
                );
              }
            } else {
              restoreInlineStyleState(state.drag.element, 'left', state.drag.liveLeft);
              restoreInlineStyleState(state.drag.element, 'top', state.drag.liveTop);
            }
          }

          if (state.editing && state.editing.element && state.editing.element.isConnected) {
            restoreTextEditingPresentation(state.editing.element, state.editing.livePresentation);
          }
        }

        function copyPayload() {
          const visualElement = selectedElement();
          if (!visualElement) {
            return { id: '', internalID: '', html: '', text: '' };
          }
          const element = editElementForSelectionID(currentSelectedID) || visualElement;
          const placementController = window.OpenGraphiteComponentPlacementReferences;
          const placementState = placementController && typeof placementController.suspend === 'function'
            ? placementController.suspend()
            : null;
          try {
            const clone = element.cloneNode(true);
            return {
              id: selectionIDForElement(element),
              internalID: element.getAttribute('data-og-internal-id') || '',
              reference: referenceForElement(element),
              referenceStability: referenceStabilityForElement(element),
              html: clone.outerHTML,
              text: (clone.textContent || '').trim(),
              cssVariables: cssVariables(element)
            };
          } finally {
            if (placementController && typeof placementController.resume === 'function') {
              placementController.resume(placementState);
            }
          }
        }

        function replaceDocumentHTML(html, selectedID) {
          const parsedDocument = new DOMParser().parseFromString(html || '', 'text/html');
          if (!parsedDocument || !parsedDocument.documentElement) {
            return false;
          }

          pendingDrag = null;
          if (activeDrag) {
            cleanupActiveDragStyles(activeDrag);
          }
          activeDrag = null;
          pendingFramePlacement = null;
          if (framePlacement && framePlacement.frame) {
            framePlacement.frame.remove();
          }
          framePlacement = null;
          frameGuideAnimations.forEach((animation) => animation.cancel());
          frameGuideAnimations.clear();
          if (window.OpenGraphiteFocusIsolation) {
            window.OpenGraphiteFocusIsolation.clear();
          }
          hideSelectionOverlay();
          clearSelectionOverlayUpdateTimer();
          clearNodeDragPreview();
          selectionOverlay = null;
          selectionOverlayFrame = null;
          editingTextElement = null;
          editingOriginalText = '';
          editingPresentationState = null;
          const nextRoot = document.importNode(parsedDocument.documentElement, true);
          document.documentElement.replaceWith(nextRoot);
          currentSelectedID = '';
          currentSelectedIDs = new Set();
          installEditorSelectionStyle();
          collectLayerNodes();

          if (selectedID && nodeWithID(selectedID)) {
            selectNode(selectedID);
            notifySelection(selectedID);
          } else {
            notifySelection('');
          }

          postScrollState(emptyScrollState(false));
          collectStaticFlowLinks();
          return true;
        }

        function editableElementChildren(parent) {
          return Array.from(parent ? parent.children : []).filter((child) => {
            return isInspectableElement(child) || isExpandedRuntimeInstance(child);
          });
        }

        function runCommand(command, payload) {
          const visualElement = selectedElement();
          const element = editElementForSelectionID(currentSelectedID) || visualElement;
          if (!element && command !== 'pasteHere') {
            return { success: false, selectedID: '' };
          }

          let selectedID = visualElement ? selectionIDForElement(visualElement) : '';
          const selectedInternalID = nodeInternalID(element);
          let edit = null;
          const isLocked = element && element.getAttribute('data-og-locked') === 'true';
          if (element && !editableSourceElement(element)) {
            return { success: false, selectedID: selectedID, requiresAdoption: true };
          }
          if (isLocked && command !== 'toggleLocked') {
            return { success: false, selectedID: selectedID };
          }

          if (command === 'pasteHere') {
            if (!element) { return { success: false, selectedID: '' }; }
            const canAppend = elementSupportsCapability(element, 'receive-children');
            const canInsertAfter = elementSupportsCapability(element, 'group');
            if (!canAppend && !canInsertAfter) {
              return { success: false, selectedID: selectedID };
            }
            const fragment = fragmentFromPayload(payload || {});
            const html = fragmentHTML(fragment);
            selectedID = firstEditableID(fragment);
            const position = canAppend ? 'append' : 'after';
            edit = {
              operation: 'insertHTML',
              anchorInternalID: selectedInternalID,
              position: position,
              html: html
            };
            if (position === 'append') {
              element.append(fragment);
            } else {
              element.after(fragment);
            }
          } else if (command === 'pasteReplace') {
            if (!elementSupportsCapability(element, 'group')) {
              return { success: false, selectedID: selectedID };
            }
            const fragment = fragmentFromPayload(payload || {});
            const html = fragmentHTML(fragment);
            selectedID = firstEditableID(fragment);
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: html
            };
            element.replaceWith(fragment);
          } else if (command === 'delete') {
            if (!elementSupportsCapability(element, 'group')) {
              return { success: false, selectedID: selectedID };
            }
            const parentEditable = element.parentElement ? inspectableElementFromTarget(element.parentElement) : null;
            selectedID = parentEditable ? selectionIDForElement(parentEditable) : '';
            edit = {
              operation: 'deleteNode',
              nodeInternalID: selectedInternalID
            };
            element.remove();
          } else if (command === 'moveFront') {
            if (!elementSupportsCapability(element, 'reorder-flow')) {
              return { success: false, selectedID: selectedID };
            }
            const siblings = editableElementChildren(element.parentElement).filter((child) => {
              return child !== element && canReorderFlowChild(child, element.parentElement);
            });
            const target = siblings[siblings.length - 1];
            if (!target) { return { success: false, selectedID: selectedID }; }
            if (!editableSourceElement(target)) {
              return { success: false, selectedID: selectedID, requiresAdoption: true };
            }
            edit = {
              operation: 'moveNode',
              nodeInternalID: selectedInternalID,
              targetInternalID: nodeInternalID(target),
              position: 'after'
            };
            target.after(element);
          } else if (command === 'moveBack') {
            if (!elementSupportsCapability(element, 'reorder-flow')) {
              return { success: false, selectedID: selectedID };
            }
            const siblings = editableElementChildren(element.parentElement).filter((child) => {
              return child !== element && canReorderFlowChild(child, element.parentElement);
            });
            const target = siblings[0];
            if (!target) { return { success: false, selectedID: selectedID }; }
            if (!editableSourceElement(target)) {
              return { success: false, selectedID: selectedID, requiresAdoption: true };
            }
            edit = {
              operation: 'moveNode',
              nodeInternalID: selectedInternalID,
              targetInternalID: nodeInternalID(target),
              position: 'before'
            };
            target.before(element);
          } else if (command === 'wrapFrame') {
            if (!elementSupportsCapability(element, 'group')) {
              return { success: false, selectedID: selectedID };
            }
            const frame = document.createElement('div');
            selectedID = createFrameID();
            frame.setAttribute('data-og-id', selectedID);
            frame.setAttribute('data-og-internal-id', randomInternalID(new Set(allEditableNodes().map((node) => nodeInternalID(node)))));
            frame.style.setProperty('display', 'flex');
            frame.style.setProperty('flex-direction', 'column');
            frame.style.setProperty('gap', '0');
            frame.style.setProperty('padding', '0');
            element.before(frame);
            frame.append(element);
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: frame.outerHTML
            };
          } else if (command === 'ungroup') {
            if (!elementSupportsCapability(element, 'ungroup')) {
              return { success: false, selectedID: selectedID };
            }
            const children = Array.from(element.childNodes);
            if (children.length === 0) { return { success: false, selectedID: selectedID }; }
            const html = htmlForNodeList(children);
            const firstChild = children.find((child) => child.nodeType === Node.ELEMENT_NODE && isInspectableElement(child));
            selectedID = firstChild ? selectionIDForElement(firstChild) : '';
            edit = {
              operation: 'replaceNodeHTML',
              nodeInternalID: selectedInternalID,
              html: html
            };
            children.forEach((child) => element.parentElement.insertBefore(child, element));
            element.remove();
          } else if (command === 'setLayout') {
            if (!elementSupportsCapability(element, 'edit-layout')) {
              return { success: false, selectedID: selectedID };
            }
            const nextLayout = (payload && payload.layout) || 'vertical';
            const previousValues = {
              'display': element.style.getPropertyValue('display') || '',
              'flex-direction': element.style.getPropertyValue('flex-direction') || ''
            };
            const values = nextLayout === 'horizontal'
              ? { 'display': 'flex', 'flex-direction': 'row' }
              : nextLayout === 'grid'
                ? { 'display': 'grid' }
                : nextLayout === 'block'
                  ? { 'display': 'block' }
                  : { 'display': 'flex', 'flex-direction': 'column' };
            Object.entries(values).forEach(([key, value]) => applyCSSVariableValue(element, key, value));
            selectedID = selectionIDForElement(element);
            edit = {
              operation: 'setCSSVariables',
              nodeInternalID: selectedInternalID,
              values: values,
              previousValues: previousValues
            };
          } else if (command === 'pasteCSSVariables') {
            const values = {};
            const previousValues = {};
            Object.entries(payload || {}).forEach(([key, value]) => {
              if (!isOpenGraphiteStyleKey(key)) { return; }
              previousValues[key] = element.style.getPropertyValue(key) || '';
              values[key] = value || '';
              if ((value || '').trim().length === 0) {
                element.style.removeProperty(key);
              } else {
                element.style.setProperty(key, value);
              }
            });
            edit = {
              operation: 'setCSSVariables',
              nodeInternalID: selectedInternalID,
              values: values,
              previousValues: previousValues
            };
          } else if (command === 'toggleHidden') {
            if (!elementSupportsCapability(element, 'edit-layout')) {
              return { success: false, selectedID: selectedID };
            }
            const hadHiddenAttribute = element.hasAttribute('hidden');
            const previousValue = hadHiddenAttribute ? element.getAttribute('hidden') || '' : '';
            const nextValue = hadHiddenAttribute ? '' : 'hidden';
            if (nextValue) {
              element.setAttribute('hidden', nextValue);
            } else {
              element.removeAttribute('hidden');
            }
            edit = {
              operation: 'setAttribute',
              nodeInternalID: selectedInternalID,
              name: 'hidden',
              value: nextValue,
              previousValue: previousValue,
              previousAttributePresent: hadHiddenAttribute,
              removeAttribute: hadHiddenAttribute
            };
          } else if (command === 'toggleLocked') {
            const hadLockedAttribute = element.hasAttribute('data-og-locked');
            const previousValue = element.getAttribute('data-og-locked') || '';
            const nextValue = previousValue === 'true' ? '' : 'true';
            if (nextValue) {
              element.setAttribute('data-og-locked', nextValue);
            } else {
              element.removeAttribute('data-og-locked');
            }
            edit = {
              operation: 'setAttribute',
              nodeInternalID: selectedInternalID,
              name: 'data-og-locked',
              value: nextValue,
              previousValue: previousValue,
              previousAttributePresent: hadLockedAttribute,
              removeAttribute: hadLockedAttribute && !nextValue
            };
          } else if (command === 'flipHorizontal') {
            const scaleChange = flipScaleAxis(element, 0, payload || {});
            if (!scaleChange) { return { success: false, selectedID: selectedID }; }
            edit = {
              operation: 'setCSSVariable',
              nodeInternalID: selectedInternalID,
              key: 'scale',
              value: scaleChange.value,
              previousValue: scaleChange.previousValue
            };
          } else if (command === 'flipVertical') {
            const scaleChange = flipScaleAxis(element, 1, payload || {});
            if (!scaleChange) { return { success: false, selectedID: selectedID }; }
            edit = {
              operation: 'setCSSVariable',
              nodeInternalID: selectedInternalID,
              key: 'scale',
              value: scaleChange.value,
              previousValue: scaleChange.previousValue
            };
          } else {
            return { success: false, selectedID: selectedID };
          }

          collectLayerNodes();
          if (selectedID) {
            selectNode(selectedID);
            notifySelection(selectedID);
          }
          collectStaticFlowLinks();
          return { success: true, selectedID: selectedID, edit: edit };
        }

        window.OpenGraphite = {
          collectNodes: collectNodes,
          collectLayerNodes: collectLayerNodes,
          collectNodeDetails: collectNodeDetails,
          collectStaticFlowLinks: collectStaticFlowLinks,
          installEditorSelectionStyle: installEditorSelectionStyle,
          selectNode: selectNode,
          selectNodes: selectNodes,
          selectionOverlayPayload: selectionOverlayPayload,
          setFocusedNodes: setFocusedNodes,
          focusedNodeFrame: focusedNodeFrame,
          setFocusMode: setFocusMode,
          setActiveTool: setActiveTool,
          handleFramePlacementNativeEvent: handleFramePlacementNativeEvent,
          setCSSVariable: setCSSVariable,
          setCSSVariables: setCSSVariables,
          setCSSVariablesBatch: setCSSVariablesBatch,
          setAttributeValue: setAttributeValue,
          setTextContent: setTextContent,
          copyPayload: copyPayload,
          replaceDocumentHTML: replaceDocumentHTML,
          suspendTransientStateForSerialization: suspendTransientStateForSerialization,
          resumeTransientStateAfterSerialization: resumeTransientStateAfterSerialization,
          runCommand: runCommand
        };

        document.addEventListener('pointerdown', function(event) {
          if (editingTextElement) {
            if (editingTextElement.contains(originalEventTarget(event))) { return; }
            finishTextEditing(false);
          }
          if (beginPendingFramePlacement(event)) {
            return;
          }
          beginPendingDrag(event);
        }, activePointerOptions);

        document.addEventListener('mousedown', function(event) {
          if (editingTextElement) {
            if (editingTextElement.contains(originalEventTarget(event))) { return; }
            finishTextEditing(false);
          }
          if (beginPendingFramePlacement(event)) {
            return;
          }
        }, activePointerOptions);

        document.addEventListener('pointermove', function(event) {
          updateStaticFlowHoverFromTarget(originalEventTarget(event));
          updateScrollStateAt(event.clientX, event.clientY);
          if (updateFramePlacement(event)) {
            return;
          }
          if (!editingTextElement && (activeDrag || startActiveDragIfNeeded(event))) {
            updateActiveDrag(event);
          }
        }, activePointerOptions);

        document.addEventListener('pointerover', function(event) {
          updateStaticFlowHoverFromTarget(originalEventTarget(event));
        }, passivePointerOptions);

        document.addEventListener('pointerout', function(event) {
          updateStaticFlowHoverFromTarget(event.relatedTarget);
        }, passivePointerOptions);

        document.addEventListener('pointerup', function(event) {
          if (finishFramePlacementFromEvent(event, false)) {
            return;
          }
          if (activeDrag && activeDrag.pointerID === event.pointerId) {
            event.preventDefault();
            event.stopPropagation();
            finishActiveDrag(false);
            return;
          }
          if (pendingDrag && pendingDrag.pointerID === event.pointerId) {
            pendingDrag = null;
          }
        }, activePointerOptions);

        document.addEventListener('mouseup', function(event) {
          if (finishFramePlacementFromEvent(event, false)) {
            return;
          }
        }, activePointerOptions);

        document.addEventListener('pointercancel', function(event) {
          if (finishFramePlacementFromEvent(event, true)) {
            return;
          }
          if (activeDrag && activeDrag.pointerID === event.pointerId) {
            event.preventDefault();
            event.stopPropagation();
            finishActiveDrag(true);
          }
          if (pendingDrag && pendingDrag.pointerID === event.pointerId) {
            pendingDrag = null;
          }
        }, activePointerOptions);

        document.addEventListener('dragstart', function(event) {
          if (editingTextElement && editingTextElement.contains(originalEventTarget(event))) { return; }
          if (activeTool !== 'select' || !editableElementFromTarget(originalEventTarget(event))) { return; }
          event.preventDefault();
          event.stopPropagation();
        }, activePointerOptions);

        document.addEventListener('keydown', function(event) {
          const isReturnKey = event.key === 'Enter' || event.key === 'Return';
          const isComposing = event.isComposing || event.keyCode === 229;

          if (editingTextElement) {
            if (isComposing) { return; }

            if (event.key === 'Escape') {
              event.preventDefault();
              event.stopPropagation();
              finishTextEditing(true);
              return;
            }

            if (isReturnKey && !event.shiftKey && !event.altKey && !event.metaKey && !event.ctrlKey) {
              event.preventDefault();
              event.stopPropagation();
              finishTextEditing(false);
            }
            return;
          }

          if ((framePlacement || pendingFramePlacement) && event.key === 'Escape') {
            event.preventDefault();
            event.stopPropagation();
            if (framePlacement) {
              finishFramePlacement(true);
            } else {
              pendingFramePlacement = null;
            }
            return;
          }

          if (activeTool !== 'select' || !isReturnKey) { return; }
          const element = selectedElement();
          if (!isTextElement(element) || hasLockedAncestor(element)) { return; }
          event.preventDefault();
          event.stopPropagation();
          beginTextEditing(element, true);
        }, { capture: true });

        document.addEventListener('focusout', function(event) {
          if (!editingTextElement || originalEventTarget(event) !== editingTextElement) { return; }
          finishTextEditing(false);
        }, true);

        document.addEventListener('input', function(event) {
          if (!editingTextElement || originalEventTarget(event) !== editingTextElement) { return; }
          notifyTextEditingChange(editingTextElement);
        }, true);

        document.addEventListener('paste', function(event) {
          if (!editingTextElement || originalEventTarget(event) !== editingTextElement) { return; }
          const text = event.clipboardData ? event.clipboardData.getData('text/plain') : '';
          if (text.length === 0) { return; }
          event.preventDefault();
          document.execCommand('insertText', false, text);
        }, true);

        document.addEventListener('mousemove', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
          if (updateFramePlacement(event)) {
            return;
          }
        }, activePointerOptions);

        document.addEventListener('mouseleave', function() {
          markPointerOutside();
          postStaticFlowHover(null);
        }, { capture: true });

        document.addEventListener('scroll', function() {
          updateLastPointerScrollState();
          scheduleStaticFlowLinkCollection();
          scheduleSelectionOverlayUpdate({ throttled: true });
        }, true);

        document.addEventListener('wheel', function(event) {
          updateScrollStateAt(event.clientX, event.clientY);
        }, passivePointerOptions);

        window.addEventListener('resize', function() {
          scheduleNodeCollection();
          scheduleStaticFlowLinkCollection();
          scheduleSelectionOverlayUpdate();
        }, passivePointerOptions);

        if (window.ResizeObserver) {
          const staticFlowResizeObserver = new ResizeObserver(scheduleStaticFlowLinkCollection);
          staticFlowResizeObserver.observe(document.documentElement);
          if (document.body) {
            staticFlowResizeObserver.observe(document.body);
          }
          window.__openGraphiteStaticFlowResizeObserver = staticFlowResizeObserver;
        }

        document.addEventListener('click', function(event) {
          if (suppressNextClick) {
            suppressNextClick = false;
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          if (editingTextElement && editingTextElement.contains(originalEventTarget(event))) { return; }
          if (activeTool !== 'select') {
            if (activeTool === 'frame') {
              const element = editableElementFromTarget(originalEventTarget(event));
              if (element) {
                event.preventDefault();
                event.stopPropagation();
                const id = nextSelectionIDForClick(element);
                selectNode(id);
                notifySelection(id);
                collectNodeDetails(id);
                return;
              }
              event.preventDefault();
              event.stopPropagation();
              return;
            }
            if (placeCreatedElement(event)) {
              event.preventDefault();
              event.stopPropagation();
            }
            return;
          }
          const element = editableElementFromTarget(originalEventTarget(event));
          if (!element) { return; }
          event.preventDefault();
          event.stopPropagation();
          const id = nextSelectionIDForClick(element);
          if (preserveMultiSelectionForClick(element, id)) {
            return;
          }
          const textElement = textElementForEditing(element, editingSelectionBaselineForClick(event));
          if (textElement) {
            suppressNextClick = false;
            beginTextEditing(textElement, {
              selectText: false,
              clientX: event.clientX,
              clientY: event.clientY
            });
            return;
          }
          selectNode(id);
          notifySelection(id);
          collectNodeDetails(id);
        }, true);

        document.addEventListener('dblclick', function(event) {
          if (editingTextElement && editingTextElement.contains(originalEventTarget(event))) { return; }
          if (activeTool !== 'select') { return; }
          const element = editableElementFromTarget(originalEventTarget(event));
          if (!element) { return; }
          const textElement = textElementForEditing(element, clickSequenceStartSelectedID);
          if (!textElement) { return; }
          event.preventDefault();
          event.stopPropagation();
          suppressNextClick = false;
          beginTextEditing(textElement, true);
        }, true);

        document.addEventListener('contextmenu', function(event) {
          if (editingTextElement && editingTextElement.contains(originalEventTarget(event))) { return; }
          const element = editableElementFromTarget(originalEventTarget(event));
          if (!element) { return; }
          event.preventDefault();
          event.stopPropagation();
          const id = activeTool === 'select' ? nextSelectionIDForClick(element) : selectionIDForElement(element);
          selectNode(id);
          notifySelection(id);
          collectNodeDetails(id);
          const focusElement = nodeWithID(id) || element;
          window.webkit.messageHandlers.openGraphiteContextMenu.postMessage({
            id: id,
            x: event.clientX,
            y: event.clientY,
            focusFrame: focusedPreviewFramePayload(focusElement),
            candidates: layerCandidatesFor(element)
          });
        }, true);

        document.addEventListener('opengraphite:components-ready', function() {
          collectLayerNodes();
          collectStaticFlowLinks();
          if (currentSelectedID) {
            selectNode(currentSelectedID);
          }
        });

      installEditorSelectionStyle();

      setTimeout(function() {
        collectLayerNodes();
        collectStaticFlowLinks();
        postScrollState(emptyScrollState(false));
      }, 0);
    })();
    """
}
