import AppKit
import SwiftUI
import WebKit

/// 論理名（日本語）: エディターシェルビュー
/// 概要: Toolbar、Sidebar、Canvas、Inspector を三分割で配置する編集画面のルートビューです。
struct EditorShellView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbarView()
            Divider()
            HSplitView {
                SidebarView()
                    .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)

                CanvasPaneView()
                    .frame(minWidth: 360)

                InspectorView()
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 380)
            }
        }
    }
}

/// 論理名（日本語）: エディターツールバービュー
/// 概要: プロジェクトオープン操作、プロジェクト名、参照ルート、選択ページ情報を表示します。
///
/// プロパティ:
/// - `store`: エディター状態ストア。
private struct EditorToolbarView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.openProjectWithPanel()
            } label: {
                Image(systemName: "folder")
            }
            .help("Open .ogp")

            Button {
                store.openSampleProject()
            } label: {
                Image(systemName: "play.rectangle")
            }
            .help("Open Sample Project")

            Divider()
                .frame(height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(store.loadedProject?.project.name ?? "OpenGraphite")
                        .font(.headline)

                    if let projectRootPath {
                        PathBadge(title: "Project", path: projectRootPath)
                    }

                    if let publicRootPath {
                        PathBadge(title: "Public", path: publicRootPath)
                    }
                }
                Text(store.selectedPage?.path ?? store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var projectRootPath: String? {
        store.loadedProject?.rootURL.path
    }

    private var publicRootPath: String? {
        guard let loadedProject = store.loadedProject else { return nil }
        return loadedProject.rootURL
            .appendingPathComponent(loadedProject.project.htmlRoot)
            .path
    }
}

/// 論理名（日本語）: パスバッジビュー
/// 概要: プロジェクトルートや public ルートをツールバー上で省略表示する小型ラベルです。
///
/// プロパティ:
/// - `title`: バッジの種別名。
/// - `path`: 表示するファイルシステムパス。
private struct PathBadge: View {
    var title: String
    var path: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .fontWeight(.semibold)
            Text(path)
                .truncationMode(.middle)
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
        .help(path)
        .frame(maxWidth: 180)
    }
}

/// 論理名（日本語）: キャンバスペインビュー
/// 概要: HTML プレビュー、ツールパレット、ズーム HUD を重ねて表示する中央ペインです。
private struct CanvasPaneView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let page = store.selectedPage {
                ZoomableCanvasScrollView(zoom: $store.zoom, documentID: page.id) {
                    CanvasDocumentView(store: store, page: page, zoom: store.zoom)
                }

                CanvasToolPalette(activeTool: $store.activeTool)
                    .padding(.leading, 14)
                    .padding(.top, 14)

                CanvasZoomHUD(
                    zoom: store.zoom,
                    canZoomOut: store.zoom > CanvasZoom.range.lowerBound,
                    canZoomIn: store.zoom < CanvasZoom.range.upperBound,
                    onZoomOut: {
                        adjustZoom(by: -CanvasZoom.buttonStep)
                    },
                    onZoomIn: {
                        adjustZoom(by: CanvasZoom.buttonStep)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 14)
            } else {
                ContentUnavailableView(
                    "No Page",
                    systemImage: "doc",
                    description: Text("pages を持つ .ogp を開いてください。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// 論理名（日本語）: ズーム調整関数
    /// 処理概要: HUD ボタン操作に応じてズーム倍率を許容範囲内で増減します。
    ///
    /// - Parameter delta: 追加するズーム倍率差分。
    private func adjustZoom(by delta: Double) {
        withAnimation(.easeOut(duration: 0.12)) {
            store.zoom = CanvasZoom.clamped(store.zoom + delta)
        }
    }

}

/// 論理名（日本語）: キャンバスドキュメントビュー
/// 概要: `.ogp` のキャンバスサイズを反映し、その上に WKWebView ベースの HTML プレビューを配置します。
///
/// プロパティ:
/// - `store`: エディター状態ストア。
/// - `page`: 表示対象ページ。
/// - `zoom`: 現在の表示倍率。
private struct CanvasDocumentView: View {
    @ObservedObject var store: EditorStore
    var page: OpenGraphitePage
    var zoom: Double

    var body: some View {
        let scale = CGFloat(zoom)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .frame(width: page.canvas.width, height: page.canvas.height)

            WebCanvasView(store: store)
                .frame(width: page.canvas.width, height: page.canvas.height)
        }
        .frame(width: page.canvas.width, height: page.canvas.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: page.canvas.width * scale, height: page.canvas.height * scale, alignment: .topLeading)
        .padding(CanvasMetrics.documentPadding)
        .padding(.leading, max(0, page.canvas.x) * scale)
        .padding(.top, max(0, page.canvas.y) * scale)
    }
}

/// 論理名（日本語）: キャンバスメトリクス
/// 概要: キャンバス表示で共有する余白などの静的寸法をまとめます。
///
/// 定義内容:
/// - `documentPadding`: ドキュメント周囲の余白。
private enum CanvasMetrics {
    static let documentPadding: CGFloat = 48
}

/// 論理名（日本語）: キャンバスズーム設定
/// 概要: キャンバス倍率の範囲、ボタン単位、表示文字列生成をまとめます。
///
/// 定義内容:
/// - `range`: 許容ズーム範囲。
/// - `buttonStep`: HUD ボタンのズーム差分。
private enum CanvasZoom {
    static let range: ClosedRange<Double> = 0.25...2.0
    static let buttonStep = 0.1

    /// 論理名（日本語）: ズーム範囲補正関数
    /// 処理概要: 任意の倍率を OpenGraphite が許可する範囲に丸めます。
    ///
    /// - Parameter value: 補正前の倍率。
    /// - Returns: 許容範囲内へ補正された倍率。
    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// 論理名（日本語）: ズームパーセント文字列生成関数
    /// 処理概要: 倍率を UI 表示用の百分率文字列に変換します。
    ///
    /// - Parameter zoom: 表示する倍率。
    /// - Returns: `100%` 形式の文字列。
    static func percent(_ zoom: Double) -> String {
        "\(Int((zoom * 100).rounded()))%"
    }
}

/// 論理名（日本語）: キャンバスズームHUD
/// 概要: キャンバス右下に現在倍率とズームイン/アウトボタンを表示します。
///
/// プロパティ:
/// - `zoom`: 現在倍率。
/// - `canZoomOut`: 縮小操作が可能か。
/// - `canZoomIn`: 拡大操作が可能か。
/// - `onZoomOut`: 縮小ボタン押下時の処理。
/// - `onZoomIn`: 拡大ボタン押下時の処理。
private struct CanvasZoomHUD: View {
    var zoom: Double
    var canZoomOut: Bool
    var canZoomIn: Bool
    var onZoomOut: () -> Void
    var onZoomIn: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onZoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .disabled(!canZoomOut)
            .buttonStyle(.plain)
            .help("Zoom Out")

            Text(CanvasZoom.percent(zoom))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .frame(minWidth: 58)
                .contentTransition(.numericText(value: zoom))

            Button(action: onZoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .disabled(!canZoomIn)
            .buttonStyle(.plain)
            .help("Zoom In")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zoom \(CanvasZoom.percent(zoom))")
    }
}

/// 論理名（日本語）: ズーム可能キャンバススクロールビュー
/// 概要: SwiftUI のキャンバス内容を `NSScrollView` へ載せ、スクロールとズーム入力を AppKit 側で制御します。
///
/// プロパティ:
/// - `zoom`: 双方向バインディングされたキャンバス倍率。
/// - `documentID`: 表示中ドキュメントの識別子。
/// - `content`: スクロールビュー内に表示する SwiftUI content。
private struct ZoomableCanvasScrollView<Content: View>: NSViewRepresentable {
    @Binding var zoom: Double
    var documentID: String
    var content: () -> Content

    /// 論理名（日本語）: ズーム可能スクロールビュー初期化関数
    /// 処理概要: ズームバインディング、ドキュメント ID、表示 content を保持します。
    ///
    /// - Parameters:
    ///   - zoom: キャンバス倍率のバインディング。
    ///   - documentID: 表示中ドキュメントの識別子。
    ///   - content: スクロールビュー内に表示する SwiftUI content。
    init(
        zoom: Binding<Double>,
        documentID: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._zoom = zoom
        self.documentID = documentID
        self.content = content
    }

    /// 論理名（日本語）: スクロールビューコーディネーター生成関数
    /// 処理概要: AppKit 入力イベントを処理するコーディネーターを生成します。
    ///
    /// - Returns: ズーム可能スクロールビュー用コーディネーター。
    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: $zoom, documentID: documentID, content: content)
    }

    /// 論理名（日本語）: NSScrollView生成関数
    /// 処理概要: HTML キャンバス用のスクロールビューを生成し、hosting view を documentView として設定します。
    ///
    /// - Parameter context: SwiftUI が提供する representable context。
    /// - Returns: キャンバス用 NSScrollView。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.allowsMagnification = false
        scrollView.scrollerStyle = .overlay

        scrollView.documentView = context.coordinator.hostingView
        context.coordinator.attach(to: scrollView)
        context.coordinator.refreshDocumentSize()

        return scrollView
    }

    /// 論理名（日本語）: NSScrollView更新関数
    /// 処理概要: SwiftUI content、ドキュメント ID、documentView サイズを最新状態へ更新します。
    ///
    /// - Parameters:
    ///   - scrollView: 更新対象の NSScrollView。
    ///   - context: SwiftUI が提供する representable context。
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.zoom = $zoom
        context.coordinator.updateContent(documentID: documentID, content: content)
        context.coordinator.refreshDocumentSizeIfNeeded()
    }

    /// 論理名（日本語）: NSScrollView解体関数
    /// 処理概要: local event monitor を破棄して AppKit 入力監視を終了します。
    ///
    /// - Parameters:
    ///   - nsView: 解体対象の NSScrollView。
    ///   - coordinator: 紐づくコーディネーター。
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.dismantle()
    }

    /// 論理名（日本語）: キャンバススクロールコーディネーター
    /// 概要: AppKit のスクロール、magnify、gesture イベントを処理し、ズームとスクロールルーティングを制御します。
    ///
    /// プロパティ:
    /// - `zoom`: キャンバス倍率のバインディング。
    /// - `content`: 表示する SwiftUI content。
    /// - `hostingView`: NSScrollView に載せる hosting view。
    final class Coordinator: NSObject {
        var zoom: Binding<Double>
        var content: () -> Content
        let hostingView: NSHostingView<Content>

        private weak var scrollView: NSScrollView?
        private var monitor: Any?
        private var renderedDocumentID: String
        private var lastViewportSize: NSSize = .zero
        private var lastZoom: Double

        /// 論理名（日本語）: キャンバススクロールコーディネーター初期化関数
        /// 処理概要: ズームバインディング、ドキュメント ID、初期 content を hosting view に保持します。
        ///
        /// - Parameters:
        ///   - zoom: キャンバス倍率のバインディング。
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - content: 初期表示する SwiftUI content。
        init(
            zoom: Binding<Double>,
            documentID: String,
            content: @escaping () -> Content
        ) {
            self.zoom = zoom
            self.content = content
            self.renderedDocumentID = documentID
            self.lastZoom = CanvasZoom.clamped(zoom.wrappedValue)
            self.hostingView = NSHostingView(rootView: content())
            self.hostingView.isFlipped = true
            super.init()
        }

        /// 論理名（日本語）: スクロールビュー接続関数
        /// 処理概要: NSScrollView を保持し、スクロールとズームの local event monitor を登録します。
        ///
        /// - Parameter scrollView: 接続対象の NSScrollView。
        func attach(to scrollView: NSScrollView) {
            self.scrollView = scrollView
            guard monitor == nil else { return }

            let eventMask: NSEvent.EventTypeMask = [.scrollWheel, .magnify, .gesture]
            monitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
                guard let self, self.handleInputEvent(event) else {
                    return event
                }
                return nil
            }
        }

        /// 論理名（日本語）: content更新関数
        /// 処理概要: ドキュメント ID またはズームが変化したときに hosting view の rootView とサイズを更新します。
        ///
        /// - Parameters:
        ///   - documentID: 表示中ドキュメントの識別子。
        ///   - content: 新しい SwiftUI content。
        func updateContent(documentID: String, content: @escaping () -> Content) {
            self.content = content
            let currentZoom = CanvasZoom.clamped(zoom.wrappedValue)
            guard renderedDocumentID != documentID || abs(lastZoom - currentZoom) > 0.0005 else { return }

            renderedDocumentID = documentID
            lastZoom = currentZoom
            hostingView.rootView = content()
            refreshDocumentSize(force: true)
        }

        /// 論理名（日本語）: ドキュメントサイズ更新関数
        /// 処理概要: hosting view の fittingSize と viewport をもとに documentView サイズを強制更新します。
        func refreshDocumentSize() {
            refreshDocumentSize(force: true)
        }

        /// 論理名（日本語）: 必要時ドキュメントサイズ更新関数
        /// 処理概要: viewport サイズが変わった場合だけ documentView サイズを更新します。
        func refreshDocumentSizeIfNeeded() {
            guard let scrollView else { return }
            let viewportSize = scrollView.contentView.bounds.size
            guard viewportSize != lastViewportSize else { return }
            refreshDocumentSize(force: true)
        }

        /// 論理名（日本語）: ドキュメントサイズ内部更新関数
        /// 処理概要: hosting view の実サイズが viewport より小さくならないように frame を調整します。
        ///
        /// - Parameter force: viewport 変化がなくても更新するか。
        private func refreshDocumentSize(force: Bool) {
            guard let scrollView else { return }
            let viewportSize = scrollView.contentView.bounds.size
            guard force || viewportSize != lastViewportSize else { return }

            hostingView.layoutSubtreeIfNeeded()
            let fittingSize = hostingView.fittingSize
            let documentSize = NSSize(
                width: max(fittingSize.width, viewportSize.width),
                height: max(fittingSize.height, viewportSize.height)
            )

            if hostingView.frame.size != documentSize {
                hostingView.setFrameSize(documentSize)
            }
            lastViewportSize = viewportSize
        }

        /// 論理名（日本語）: イベント監視破棄関数
        /// 処理概要: 登録済み local event monitor を削除します。
        func dismantle() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        /// 論理名（日本語）: 入力イベント処理関数
        /// 処理概要: 対象 scroll view 内の scroll、magnify、gesture をズームまたはスクロールルーティングへ振り分けます。
        ///
        /// - Parameter event: AppKit から届いた入力イベント。
        /// - Returns: OpenGraphite 側で消費した場合は `true`。
        private func handleInputEvent(_ event: NSEvent) -> Bool {
            guard let scrollView,
                  event.window === scrollView.window,
                  isEventInsideScrollView(event, scrollView: scrollView)
            else {
                return false
            }

            if event.type == .magnify {
                return handleMagnify(event)
            }

            if event.type == .gesture {
                return handleGesture(event)
            }

            if event.modifierFlags.contains(.command) {
                return handleCommandScroll(event)
            }

            return routeCanvasScrollIfNeeded(event, in: scrollView)
        }

        /// 論理名（日本語）: Commandスクロール処理関数
        /// 処理概要: `⌘ + scroll` をキャンバスズームへ変換します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: ズーム操作として消費した場合は `true`。
        private func handleCommandScroll(_ event: NSEvent) -> Bool {
            let verticalDelta = verticalScrollDelta(for: event)
            guard verticalDelta.value != 0 else { return false }

            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let scale = scaleFactor(for: verticalDelta.value, isPrecise: verticalDelta.isPrecise)
            let newZoom = CanvasZoom.clamped(oldZoom * scale)
            guard newZoom.isFinite, newZoom != oldZoom else { return true }

            zoom.wrappedValue = newZoom
            return true
        }

        /// 論理名（日本語）: magnifyイベント処理関数
        /// 処理概要: トラックパッドなどの magnify 値をキャンバスズームへ反映します。
        ///
        /// - Parameter event: magnify イベント。
        /// - Returns: ズーム操作として消費した場合は `true`。
        private func handleMagnify(_ event: NSEvent) -> Bool {
            applyMagnification(event.magnification)
        }

        /// 論理名（日本語）: gestureイベント処理関数
        /// 処理概要: Mac Mouse Fix などが発行する gesture subtype の magnification をズームへ反映します。
        ///
        /// - Parameter event: gesture イベント。
        /// - Returns: 対応する magnification を消費した場合は `true`。
        private func handleGesture(_ event: NSEvent) -> Bool {
            guard let cgEvent = event.cgEvent,
                  let subtypeField = CGEventField(rawValue: 110),
                  let magnificationField = CGEventField(rawValue: 113),
                  cgEvent.getIntegerValueField(subtypeField) == 8
            else {
                return false
            }

            return applyMagnification(CGFloat(cgEvent.getDoubleValueField(magnificationField)))
        }

        /// 論理名（日本語）: magnification適用関数
        /// 処理概要: 入力された magnification を倍率へ掛け合わせ、許容範囲内へ補正します。
        ///
        /// - Parameter magnification: AppKit または CGEvent 由来の拡大率差分。
        /// - Returns: OpenGraphite 側で処理した場合は `true`。
        private func applyMagnification(_ magnification: CGFloat) -> Bool {
            guard magnification != 0 else { return true }

            let oldZoom = CanvasZoom.clamped(zoom.wrappedValue)
            let newZoom = CanvasZoom.clamped(oldZoom * (1 + Double(magnification)))
            guard newZoom.isFinite, newZoom != oldZoom else { return true }

            zoom.wrappedValue = newZoom
            return true
        }

        /// 論理名（日本語）: キャンバススクロールルーティング関数
        /// 処理概要: ポインタ直下の WebView がスクロールできない場合だけ外側 NSScrollView へイベントを渡します。
        ///
        /// - Parameters:
        ///   - event: scroll wheel イベント。
        ///   - scrollView: 外側のキャンバス NSScrollView。
        /// - Returns: 外側 scroll view へルーティングして消費した場合は `true`。
        private func routeCanvasScrollIfNeeded(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
            guard let webView = webViewUnderEvent(event, in: scrollView),
                  let scrollState = WebScrollStateRegistry.shared.state(for: webView),
                  scrollState.isInside
            else {
                return false
            }

            if let direction = dominantScrollDirection(for: event),
               scrollState.canScroll(direction) {
                return false
            }

            if dominantScrollDirection(for: event) == nil,
               scrollState.canScrollAnyDirection {
                return false
            }

            scrollView.scrollWheel(with: event)
            return true
        }

        /// 論理名（日本語）: スクロールビュー内イベント判定関数
        /// 処理概要: 入力イベントの window 座標が対象 NSScrollView の bounds 内か判定します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 対象 NSScrollView。
        /// - Returns: イベント位置が scroll view 内なら `true`。
        private func isEventInsideScrollView(_ event: NSEvent, scrollView: NSScrollView) -> Bool {
            scrollView.bounds.contains(scrollView.convert(event.locationInWindow, from: nil))
        }

        /// 論理名（日本語）: イベント直下WebView取得関数
        /// 処理概要: 入力イベント位置を hitTest し、祖先をたどって WKWebView を探します。
        ///
        /// - Parameters:
        ///   - event: 判定する入力イベント。
        ///   - scrollView: 探索の基準となる NSScrollView。
        /// - Returns: ポインタ直下にある WKWebView。存在しない場合は `nil`。
        private func webViewUnderEvent(_ event: NSEvent, in scrollView: NSScrollView) -> WKWebView? {
            let point = scrollView.convert(event.locationInWindow, from: nil)
            var view = scrollView.hitTest(point)
            while let current = view {
                if let webView = current as? WKWebView {
                    return webView
                }
                view = current.superview
            }
            return nil
        }

        /// 論理名（日本語）: 主スクロール方向判定関数
        /// 処理概要: X/Y のスクロール差分から支配的なスクロール方向を決定します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: 主方向。差分がない場合は `nil`。
        private func dominantScrollDirection(for event: NSEvent) -> WebScrollDirection? {
            let delta = scrollDelta(for: event)
            let deltaX = delta.x
            let deltaY = delta.y
            guard deltaX != 0 || deltaY != 0 else { return nil }

            if abs(deltaX) > abs(deltaY) {
                return deltaX < 0 ? .right : .left
            }

            return deltaY < 0 ? .down : .up
        }

        /// 論理名（日本語）: スクロール差分取得関数
        /// 処理概要: precise delta と legacy delta を統合し、X/Y のスクロール差分を返します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: X/Y のスクロール差分。
        private func scrollDelta(for event: NSEvent) -> CGPoint {
            CGPoint(
                x: axisScrollDelta(precise: event.scrollingDeltaX, legacy: event.deltaX).value,
                y: axisScrollDelta(precise: event.scrollingDeltaY, legacy: event.deltaY).value
            )
        }

        /// 論理名（日本語）: 垂直スクロール差分取得関数
        /// 処理概要: ズーム計算に使う垂直方向のスクロール差分と precise 判定を返します。
        ///
        /// - Parameter event: scroll wheel イベント。
        /// - Returns: 差分値と precise delta かどうか。
        private func verticalScrollDelta(for event: NSEvent) -> (value: CGFloat, isPrecise: Bool) {
            axisScrollDelta(
                precise: event.scrollingDeltaY,
                legacy: event.deltaY,
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
            )
        }

        /// 論理名（日本語）: 軸別スクロール差分選択関数
        /// 処理概要: precise delta が有効なら優先し、なければ legacy delta を使用します。
        ///
        /// - Parameters:
        ///   - precise: precise scrolling delta。
        ///   - legacy: legacy delta。
        ///   - hasPreciseScrollingDeltas: precise delta が有効なイベントか。
        /// - Returns: 採用した差分値と precise 判定。
        private func axisScrollDelta(
            precise: CGFloat,
            legacy: CGFloat,
            hasPreciseScrollingDeltas: Bool = true
        ) -> (value: CGFloat, isPrecise: Bool) {
            if hasPreciseScrollingDeltas, precise != 0 {
                return (precise, true)
            }

            if legacy != 0 {
                return (legacy, false)
            }

            return (precise, hasPreciseScrollingDeltas)
        }

        /// 論理名（日本語）: ズーム倍率係数生成関数
        /// 処理概要: スクロール差分を指数関数の倍率係数へ変換し、小さな入力も捨てずに反映します。
        ///
        /// - Parameters:
        ///   - rawDelta: スクロール差分。
        ///   - isPrecise: precise delta 由来か。
        /// - Returns: 現在倍率へ掛ける倍率係数。
        private func scaleFactor(for rawDelta: CGFloat, isPrecise: Bool) -> Double {
            exp(Double(rawDelta) * (isPrecise ? 0.002 : 0.08))
        }

        deinit {
            dismantle()
        }
    }
}

/// 論理名（日本語）: キャンバスツールパレット
/// 概要: 編集カーソル、レクトアングル、テキスト、フレーム、ハンドのツールを縦型ツールバーとして表示します。
///
/// プロパティ:
/// - `activeTool`: 現在選択中のキャンバスツール。
private struct CanvasToolPalette: View {
    @Binding var activeTool: CanvasTool

    var body: some View {
        VStack(spacing: 6) {
            ForEach(CanvasTool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(activeTool == tool ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(activeTool == tool ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(activeTool == tool ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .help(tool.title)
                .accessibilityLabel(tool.title)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}
