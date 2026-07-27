import AppKit
import Foundation
import SwiftUI

/// 論理名（日本語）: キャンバス表示領域状態
/// 概要: AppKit スクロールビューの表示原点と SwiftUI content 原点を補助表示の座標変換へ渡します。
///
/// プロパティ:
/// - `visibleOrigin`: document 座標上の viewport 左上。
/// - `hostingOrigin`: document 座標上の SwiftUI hosting view 左上。
/// - `viewportSize`: スクロールビューの表示寸法。
struct CanvasViewportState: Equatable {
    var visibleOrigin: CGPoint = .zero
    var hostingOrigin: CGPoint = .zero
    var viewportSize: CGSize = .zero

    var isReady: Bool {
        visibleOrigin.x.isFinite
            && visibleOrigin.y.isFinite
            && hostingOrigin.x.isFinite
            && hostingOrigin.y.isFinite
            && viewportSize.width.isFinite
            && viewportSize.height.isFinite
            && viewportSize.width > 0
            && viewportSize.height > 0
    }
}

/// 論理名（日本語）: キャンバス補助表示座標解決器
/// 概要: スクロール、無限余白、固定 padding、描画オフセット、Zoom を考慮して viewport 座標とキャンバスワールド座標を相互変換します。
enum CanvasAidCoordinateResolver {
    /// 論理名（日本語）: 軸別描画オフセット取得関数
    /// 処理概要: `.ogp` の page 座標が指す page 本体と、情報カードを含む描画 content の原点差を対象軸へ変換します。
    ///
    /// - Parameter orientation: X 軸を使う垂直線または Y 軸を使う水平線。
    /// - Returns: 未拡大 content 内で world 原点へ到達するために加える描画オフセット。
    static func contentOffset(for orientation: OpenGraphiteCanvasGuideOrientation) -> CGFloat {
        orientation == .vertical ? 0 : CanvasMetrics.pageNameCardOutsideOffset
    }

    /// 論理名（日本語）: ワールド座標変換関数
    /// 処理概要: viewport 上の X または Y を未拡大のキャンバスワールド座標へ変換します。
    ///
    /// - Parameters:
    ///   - viewportPosition: CanvasPane 左上を基準にした画面上の X または Y。
    ///   - visibleOrigin: document 座標上の viewport 原点成分。
    ///   - hostingOrigin: document 座標上の hosting view 原点成分。
    ///   - canvasOrigin: 表示 content が基準にするワールド原点成分。
    ///   - zoom: 現在のキャンバス倍率。
    ///   - contentPadding: hosting view 内の固定余白。
    ///   - contentOffset: page 本体の world 原点と描画 content 原点の未拡大差分。
    /// - Returns: キャンバスワールド座標。入力が無効な場合は `nil`。
    static func worldPosition(
        viewportPosition: CGFloat,
        visibleOrigin: CGFloat,
        hostingOrigin: CGFloat,
        canvasOrigin: CGFloat,
        zoom: Double,
        contentPadding: CGFloat,
        contentOffset: CGFloat = 0
    ) -> Double? {
        guard viewportPosition.isFinite,
              visibleOrigin.isFinite,
              hostingOrigin.isFinite,
              canvasOrigin.isFinite,
              contentPadding.isFinite,
              contentOffset.isFinite,
              zoom.isFinite,
              zoom > 0
        else {
            return nil
        }
        return Double(canvasOrigin) + Double(
            (visibleOrigin + viewportPosition - hostingOrigin - contentPadding) / CGFloat(zoom)
                - contentOffset
        )
    }

    /// 論理名（日本語）: Viewport座標変換関数
    /// 処理概要: キャンバスワールド座標を現在のスクロールと Zoom に対応する画面位置へ変換します。
    ///
    /// - Parameters:
    ///   - worldPosition: キャンバスワールド座標。
    ///   - visibleOrigin: document 座標上の viewport 原点成分。
    ///   - hostingOrigin: document 座標上の hosting view 原点成分。
    ///   - canvasOrigin: 表示 content が基準にするワールド原点成分。
    ///   - zoom: 現在のキャンバス倍率。
    ///   - contentPadding: hosting view 内の固定余白。
    ///   - contentOffset: page 本体の world 原点と描画 content 原点の未拡大差分。
    /// - Returns: CanvasPane 左上を基準にした X または Y。入力が無効な場合は `nil`。
    static func viewportPosition(
        worldPosition: Double,
        visibleOrigin: CGFloat,
        hostingOrigin: CGFloat,
        canvasOrigin: CGFloat,
        zoom: Double,
        contentPadding: CGFloat,
        contentOffset: CGFloat = 0
    ) -> CGFloat? {
        guard worldPosition.isFinite,
              visibleOrigin.isFinite,
              hostingOrigin.isFinite,
              canvasOrigin.isFinite,
              contentPadding.isFinite,
              contentOffset.isFinite,
              zoom.isFinite,
              zoom > 0
        else {
            return nil
        }
        let position = hostingOrigin
            + contentPadding
            + (CGFloat(worldPosition - Double(canvasOrigin)) + contentOffset) * CGFloat(zoom)
            - visibleOrigin
        return position.isFinite ? position : nil
    }
}

/// 論理名（日本語）: キャンバス補助表示刻み解決器
/// 概要: Zoom が変わってもグリッドとルーラーの目盛りが過密にならないワールド刻みを選びます。
enum CanvasAidStepResolver {
    private static let candidates: [Double] = [10, 20, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000]

    /// 論理名（日本語）: 小目盛り刻み解決関数
    /// 処理概要: 画面上で最低間隔を満たす最小候補を返します。
    ///
    /// - Parameters:
    ///   - zoom: 現在のキャンバス倍率。
    ///   - minimumScreenSpacing: 許容する画面上の最小間隔。
    /// - Returns: キャンバスワールド座標での小目盛り間隔。
    static func minorStep(zoom: Double, minimumScreenSpacing: CGFloat = 8) -> Double {
        guard zoom.isFinite, zoom > 0, minimumScreenSpacing.isFinite, minimumScreenSpacing > 0 else {
            return 100
        }
        return candidates.first { $0 * zoom >= Double(minimumScreenSpacing) } ?? candidates.last ?? 10_000
    }

    /// 論理名（日本語）: 大目盛り刻み解決関数
    /// 処理概要: 小目盛り 5 本ごとを基準に、10px 小目盛りでは読みやすい 100px 単位へ揃えます。
    ///
    /// - Parameter minorStep: 選択済みの小目盛り間隔。
    /// - Returns: キャンバスワールド座標での大目盛り間隔。
    static func majorStep(for minorStep: Double) -> Double {
        minorStep <= 10 ? 100 : minorStep * 5
    }
}

/// 論理名（日本語）: キャンバス補助表示レイアウト
/// 概要: Sidebar、Inspector、上部クロームとルーラーを避けた描画領域を解決します。
struct CanvasAidLayout: Equatable {
    static let rulerThickness: CGFloat = 30

    var activeRect: CGRect
    var contentRect: CGRect
    var horizontalRulerRect: CGRect
    var verticalRulerRect: CGRect
    var rulerCornerRect: CGRect

    /// 論理名（日本語）: キャンバス補助表示レイアウト生成関数
    /// 処理概要: CanvasPane 全体から overlay column と上部クロームを除き、必要時は上・左ルーラー分も予約します。
    ///
    /// - Parameters:
    ///   - size: CanvasPane 全体の寸法。
    ///   - avoidance: Sidebar、Inspector、上部クロームの回避幅。
    ///   - showsRulers: ルーラー表示中か。
    /// - Returns: グリッド、ガイド、ルーラーに使う矩形一式。
    static func resolve(
        size: CGSize,
        avoidance: CanvasOverlayAvoidance,
        showsRulers: Bool
    ) -> CanvasAidLayout {
        let leading = sanitized(avoidance.leading, maximum: size.width)
        let trailing = sanitized(avoidance.trailing, maximum: max(size.width - leading, 0))
        let top = sanitized(avoidance.top, maximum: size.height)
        let activeRect = CGRect(
            x: leading,
            y: top,
            width: max(size.width - leading - trailing, 0),
            height: max(size.height - top, 0)
        )
        guard showsRulers else {
            return CanvasAidLayout(
                activeRect: activeRect,
                contentRect: activeRect,
                horizontalRulerRect: .zero,
                verticalRulerRect: .zero,
                rulerCornerRect: .zero
            )
        }

        let thickness = min(Self.rulerThickness, activeRect.width, activeRect.height)
        return CanvasAidLayout(
            activeRect: activeRect,
            contentRect: CGRect(
                x: activeRect.minX + thickness,
                y: activeRect.minY + thickness,
                width: max(activeRect.width - thickness, 0),
                height: max(activeRect.height - thickness, 0)
            ),
            horizontalRulerRect: CGRect(
                x: activeRect.minX + thickness,
                y: activeRect.minY,
                width: max(activeRect.width - thickness, 0),
                height: thickness
            ),
            verticalRulerRect: CGRect(
                x: activeRect.minX,
                y: activeRect.minY + thickness,
                width: thickness,
                height: max(activeRect.height - thickness, 0)
            ),
            rulerCornerRect: CGRect(
                x: activeRect.minX,
                y: activeRect.minY,
                width: thickness,
                height: thickness
            )
        )
    }

    /// 論理名（日本語）: 回避幅正規化関数
    /// 処理概要: 非有限値と負値を 0 に戻し、CanvasPane の範囲へ丸めます。
    ///
    /// - Parameters:
    ///   - value: 正規化前の回避幅。
    ///   - maximum: 許容する最大幅。
    /// - Returns: 安全な回避幅。
    private static func sanitized(_ value: CGFloat, maximum: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, max(maximum, 0))
    }
}

/// 論理名（日本語）: ガイドルーラーマーカーレイアウト
/// 概要: 配置済みガイドとルーラーの接点に表示する三角マーカーの操作領域を解決します。
enum CanvasGuideRulerMarkerLayout {
    static let interactionLength: CGFloat = 18

    /// 論理名（日本語）: マーカー操作領域解決関数
    /// 処理概要: 三角形をルーラー内へ収め、先端がガイド線の開始位置へ接する矩形を返します。
    ///
    /// - Parameters:
    ///   - guidePosition: CanvasPane 上のガイド X または Y 座標。
    ///   - orientation: 垂直または水平のガイド方向。
    ///   - contentRect: ルーラーを除いたキャンバス表示矩形。
    /// - Returns: マーカーの 18pt 操作領域。
    static func interactionFrame(
        guidePosition: CGFloat,
        orientation: OpenGraphiteCanvasGuideOrientation,
        contentRect: CGRect
    ) -> CGRect {
        guard guidePosition.isFinite,
              contentRect.minX.isFinite,
              contentRect.minY.isFinite
        else {
            return .zero
        }
        let halfLength = interactionLength / 2
        if orientation == .vertical {
            return CGRect(
                x: guidePosition - halfLength,
                y: contentRect.minY - interactionLength,
                width: interactionLength,
                height: interactionLength
            )
        }
        return CGRect(
            x: contentRect.minX - interactionLength,
            y: guidePosition - halfLength,
            width: interactionLength,
            height: interactionLength
        )
    }
}

/// 論理名（日本語）: ガイド操作解決器
/// 概要: ガイド本体とルーラーマーカーが共有するドラッグ終了判定を提供します。
enum CanvasGuideInteractionResolver {
    /// 論理名（日本語）: ルーラー戻し判定関数
    /// 処理概要: 垂直ガイドは上ルーラー、水平ガイドは左ルーラーへ戻されたかを判定します。
    ///
    /// - Parameters:
    ///   - location: CanvasPane 座標のドラッグ終了位置。
    ///   - orientation: 対象ガイドの方向。
    ///   - contentRect: ルーラーを除いたキャンバス表示矩形。
    /// - Returns: 対応するルーラー領域へ戻された場合は `true`。
    static func isDraggedBackToRuler(
        location: CGPoint,
        orientation: OpenGraphiteCanvasGuideOrientation,
        contentRect: CGRect
    ) -> Bool {
        if orientation == .vertical {
            return location.y < contentRect.minY
        }
        return location.x < contentRect.minX
    }
}

/// 論理名（日本語）: ルーラーコンテキストガイド位置解決器
/// 概要: ルーラー内の右クリック位置をキャンバスペイン座標へ変換します。
enum CanvasRulerContextGuideResolver {
    /// 論理名（日本語）: ルーラー右クリック位置変換関数
    /// 処理概要: ルーラー左上を原点にした AppKit 座標へルーラー矩形の原点を加え、共有座標変換で使うペイン座標を返します。
    ///
    /// - Parameters:
    ///   - localPoint: ルーラー内の左上原点右クリック位置。
    ///   - rulerRect: CanvasPane 上のルーラー矩形。
    /// - Returns: CanvasPane 上の右クリック位置。入力が無効またはルーラー外の場合は `nil`。
    static func panePoint(localPoint: CGPoint, rulerRect: CGRect) -> CGPoint? {
        guard localPoint.x.isFinite,
              localPoint.y.isFinite,
              rulerRect.minX.isFinite,
              rulerRect.minY.isFinite,
              rulerRect.width.isFinite,
              rulerRect.height.isFinite,
              rulerRect.width > 0,
              rulerRect.height > 0,
              CGRect(origin: .zero, size: rulerRect.size).contains(localPoint)
        else {
            return nil
        }
        return CGPoint(
            x: rulerRect.minX + localPoint.x,
            y: rulerRect.minY + localPoint.y
        )
    }
}

/// 論理名（日本語）: ガイド位置入力解決器
/// 概要: コンテキストメニューから開く位置入力で使う表示文字列と有限数値への変換を提供します。
enum CanvasGuidePositionInput {
    /// 論理名（日本語）: ガイド位置表示文字列生成関数
    /// 処理概要: 現在位置を再入力可能な文字列へ変換し、整数値では不要な小数点以下を省略します。
    ///
    /// - Parameter position: 表示するガイドの world 座標。
    /// - Returns: 位置入力欄へ初期表示する文字列。
    static func text(for position: Double) -> String {
        guard position != 0 else { return "0" }
        let text = String(position)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// 論理名（日本語）: ガイド位置入力値解決関数
    /// 処理概要: 前後の空白を除去して数値へ変換し、`.ogp` に保存できない非有限値を拒否します。
    ///
    /// - Parameter text: 利用者が位置入力欄へ入力した文字列。
    /// - Returns: 有効な有限 world 座標。空文字、数値以外、非有限値の場合は `nil`。
    static func value(from text: String) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedText), value.isFinite else { return nil }
        return value
    }
}

/// 論理名（日本語）: キャンバスグリッドオーバーレイ
/// 概要: スクロールと Zoom に追従する格子を HTML カードより背面のキャンバス全体へ描画します。
struct CanvasGridOverlay: View {
    var viewport: CanvasViewportState
    var canvasOrigin: CGPoint
    var zoom: Double
    var overlayAvoidance: CanvasOverlayAvoidance
    var showsRulers: Bool

    var body: some View {
        GeometryReader { geometry in
            let layout = CanvasAidLayout.resolve(
                size: geometry.size,
                avoidance: overlayAvoidance,
                showsRulers: showsRulers
            )
            Canvas { context, _ in
                drawGrid(context: &context, rect: layout.contentRect)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 論理名（日本語）: グリッド描画関数
    /// 処理概要: 現在 viewport に入る小目盛りと大目盛りを別の濃度で描画します。
    ///
    /// - Parameters:
    ///   - context: SwiftUI Canvas の描画コンテキスト。
    ///   - rect: Sidebar、Inspector、クローム、ルーラーを除いた描画矩形。
    private func drawGrid(context: inout GraphicsContext, rect: CGRect) {
        guard viewport.isReady, rect.width > 0, rect.height > 0 else { return }
        let minorStep = CanvasAidStepResolver.minorStep(zoom: zoom)
        let majorStep = CanvasAidStepResolver.majorStep(for: minorStep)
        var minorPath = Path()
        var majorPath = Path()

        appendLines(
            axis: .vertical,
            rect: rect,
            minorStep: minorStep,
            majorStep: majorStep,
            minorPath: &minorPath,
            majorPath: &majorPath
        )
        appendLines(
            axis: .horizontal,
            rect: rect,
            minorStep: minorStep,
            majorStep: majorStep,
            minorPath: &minorPath,
            majorPath: &majorPath
        )

        context.stroke(minorPath, with: .color(.primary.opacity(0.055)), lineWidth: 0.5)
        context.stroke(majorPath, with: .color(.primary.opacity(0.11)), lineWidth: 0.75)
    }

    /// 論理名（日本語）: グリッド線追加関数
    /// 処理概要: 指定軸の visible world 範囲を走査し、小目盛りと大目盛りの Path へ線分を追加します。
    ///
    /// - Parameters:
    ///   - axis: 水平線または垂直線の方向。
    ///   - rect: グリッド描画矩形。
    ///   - minorStep: 小目盛りのワールド間隔。
    ///   - majorStep: 大目盛りのワールド間隔。
    ///   - minorPath: 小目盛り線を書き込む Path。
    ///   - majorPath: 大目盛り線を書き込む Path。
    private func appendLines(
        axis: OpenGraphiteCanvasGuideOrientation,
        rect: CGRect,
        minorStep: Double,
        majorStep: Double,
        minorPath: inout Path,
        majorPath: inout Path
    ) {
        let startViewport = axis == .vertical ? rect.minX : rect.minY
        let endViewport = axis == .vertical ? rect.maxX : rect.maxY
        guard let startWorld = worldPosition(at: startViewport, orientation: axis),
              let endWorld = worldPosition(at: endViewport, orientation: axis)
        else {
            return
        }

        var value = floor(min(startWorld, endWorld) / minorStep) * minorStep
        let maximum = max(startWorld, endWorld) + minorStep
        var count = 0
        while value <= maximum, count < 2_000 {
            if let position = viewportPosition(for: value, orientation: axis),
               position >= startViewport - 1,
               position <= endViewport + 1 {
                let isMajor = abs(value / majorStep - (value / majorStep).rounded()) < 0.000_001
                if axis == .vertical {
                    if isMajor {
                        majorPath.move(to: CGPoint(x: position, y: rect.minY))
                        majorPath.addLine(to: CGPoint(x: position, y: rect.maxY))
                    } else {
                        minorPath.move(to: CGPoint(x: position, y: rect.minY))
                        minorPath.addLine(to: CGPoint(x: position, y: rect.maxY))
                    }
                } else if isMajor {
                    majorPath.move(to: CGPoint(x: rect.minX, y: position))
                    majorPath.addLine(to: CGPoint(x: rect.maxX, y: position))
                } else {
                    minorPath.move(to: CGPoint(x: rect.minX, y: position))
                    minorPath.addLine(to: CGPoint(x: rect.maxX, y: position))
                }
            }
            value += minorStep
            count += 1
        }
    }

    /// 論理名（日本語）: 軸別ワールド座標取得関数
    /// 処理概要: X/Y に対応する viewport 状態と content 原点を共通解決器へ渡します。
    ///
    /// - Parameters:
    ///   - viewportPosition: CanvasPane 上の X または Y。
    ///   - orientation: X を使う垂直線または Y を使う水平線。
    /// - Returns: 対応するワールド座標。
    private func worldPosition(
        at viewportPosition: CGFloat,
        orientation: OpenGraphiteCanvasGuideOrientation
    ) -> Double? {
        CanvasAidCoordinateResolver.worldPosition(
            viewportPosition: viewportPosition,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }

    /// 論理名（日本語）: 軸別Viewport座標取得関数
    /// 処理概要: X/Y に対応する viewport 状態と content 原点から線の画面位置を返します。
    ///
    /// - Parameters:
    ///   - worldPosition: ガイドまたはグリッドのワールド座標。
    ///   - orientation: X を使う垂直線または Y を使う水平線。
    /// - Returns: CanvasPane 上の X または Y。
    private func viewportPosition(
        for worldPosition: Double,
        orientation: OpenGraphiteCanvasGuideOrientation
    ) -> CGFloat? {
        CanvasAidCoordinateResolver.viewportPosition(
            worldPosition: worldPosition,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }
}

/// 論理名（日本語）: キャンバスルーラーガイド描画順
/// 概要: ルーラーの Material よりガイド線と三角マーカーを前面へ固定する z-index を定義します。
enum CanvasRulerGuideLayer: Double {
    case ruler = 0
    case guide = 1
}

/// 論理名（日本語）: キャンバスルーラーガイドオーバーレイ
/// 概要: 固定ルーラーと、ルーラーから生成・移動・削除できる `.ogp` ガイドをキャンバス前面へ表示します。
struct CanvasRulerGuideOverlay: View {
    private static let coordinateSpaceName = "OpenGraphiteCanvasAids"

    var viewport: CanvasViewportState
    var canvasOrigin: CGPoint
    var zoom: Double
    var overlayAvoidance: CanvasOverlayAvoidance
    var showsRulers: Bool
    var showsGuides: Bool
    var guides: [OpenGraphiteCanvasGuide]
    var onAddGuide: (OpenGraphiteCanvasGuideOrientation, Double) -> Void
    var onUpdateGuide: (String, Double) -> Void
    var onDeleteGuide: (String) -> Void

    @State private var pendingGuide: OpenGraphiteCanvasGuide?

    var body: some View {
        GeometryReader { geometry in
            let layout = CanvasAidLayout.resolve(
                size: geometry.size,
                avoidance: overlayAvoidance,
                showsRulers: showsRulers
            )

            ZStack(alignment: .topLeading) {
                if showsRulers {
                    rulerView(
                        orientation: .vertical,
                        rect: layout.horizontalRulerRect,
                        contentRect: layout.contentRect
                    )
                    rulerView(
                        orientation: .horizontal,
                        rect: layout.verticalRulerRect,
                        contentRect: layout.contentRect
                    )

                    Rectangle()
                        .fill(.regularMaterial)
                        .overlay(
                            Rectangle().stroke(Color.primary.opacity(0.16), lineWidth: 0.5)
                        )
                        .frame(width: layout.rulerCornerRect.width, height: layout.rulerCornerRect.height)
                        .position(x: layout.rulerCornerRect.midX, y: layout.rulerCornerRect.midY)
                        .allowsHitTesting(false)
                        .zIndex(CanvasRulerGuideLayer.ruler.rawValue)
                }

                if showsGuides {
                    ForEach(guides) { guide in
                        CanvasPlacedGuideView(
                            guide: guide,
                            viewport: viewport,
                            canvasOrigin: canvasOrigin,
                            zoom: zoom,
                            contentRect: layout.contentRect,
                            showsRulerMarker: showsRulers,
                            coordinateSpaceName: Self.coordinateSpaceName,
                            onUpdate: onUpdateGuide,
                            onDelete: onDeleteGuide
                        )
                        .zIndex(CanvasRulerGuideLayer.guide.rawValue)
                    }

                    if let pendingGuide {
                        guideLine(
                            orientation: pendingGuide.orientation,
                            worldPosition: pendingGuide.position,
                            contentRect: layout.contentRect
                        )
                        .allowsHitTesting(false)
                        .zIndex(CanvasRulerGuideLayer.guide.rawValue)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .coordinateSpace(name: Self.coordinateSpaceName)
        }
        .accessibilityElement(children: .contain)
    }

    /// 論理名（日本語）: ルーラービュー生成関数
    /// 処理概要: 目盛り描画とガイド生成 DragGesture を指定矩形へ配置します。
    ///
    /// - Parameters:
    ///   - orientation: 生成するガイド方向。上ルーラーは垂直、左ルーラーは水平を使います。
    ///   - rect: ルーラーの固定表示矩形。
    ///   - contentRect: ガイドを配置できるキャンバス矩形。
    /// - Returns: 目盛りと透明なドラッグ領域を持つルーラービュー。
    @ViewBuilder
    private func rulerView(
        orientation: OpenGraphiteCanvasGuideOrientation,
        rect: CGRect,
        contentRect: CGRect
    ) -> some View {
        CanvasRulerTicksView(
            orientation: orientation,
            paneOrigin: rect.origin,
            viewport: viewport,
            canvasOrigin: canvasOrigin,
            zoom: zoom
        )
        .frame(width: rect.width, height: rect.height)
        .background(.regularMaterial)
        .overlay(
            Rectangle().stroke(Color.primary.opacity(0.16), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .background {
            CanvasRulerContextMenuView(
                itemTitle: orientation == .vertical
                    ? "ここに垂直ガイドを追加"
                    : "ここに水平ガイドを追加",
                isActionEnabled: showsGuides
            ) { localPoint in
                guard let panePoint = CanvasRulerContextGuideResolver.panePoint(
                    localPoint: localPoint,
                    rulerRect: rect
                ),
                let position = worldPosition(at: panePoint, orientation: orientation)
                else {
                    return
                }
                onAddGuide(orientation, position.rounded())
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.coordinateSpaceName))
                .onChanged { value in
                    guard showsGuides,
                          let position = worldPosition(at: value.location, orientation: orientation)
                    else {
                        pendingGuide = nil
                        return
                    }
                    pendingGuide = OpenGraphiteCanvasGuide(
                        internalID: "pending",
                        orientation: orientation,
                        position: position.rounded()
                    )
                }
                .onEnded { value in
                    defer { pendingGuide = nil }
                    guard showsGuides,
                          contentRect.contains(value.location),
                          let position = worldPosition(at: value.location, orientation: orientation)
                    else {
                        return
                    }
                    onAddGuide(orientation, position.rounded())
                }
        )
        .zIndex(CanvasRulerGuideLayer.ruler.rawValue)
        .accessibilityLabel(orientation == .vertical ? "上ルーラー" : "左ルーラー")
        .accessibilityHint("ドラッグまたはコンテキストメニューでガイドを追加")
    }

    /// 論理名（日本語）: ガイド線生成関数
    /// 処理概要: ルーラーからドラッグ中の仮ガイドを現在の viewport 位置へ表示します。
    ///
    /// - Parameters:
    ///   - orientation: ガイド方向。
    ///   - worldPosition: ガイドのワールド座標。
    ///   - contentRect: ガイド線を表示するキャンバス矩形。
    /// - Returns: アクセント色の水平または垂直線。
    @ViewBuilder
    private func guideLine(
        orientation: OpenGraphiteCanvasGuideOrientation,
        worldPosition: Double,
        contentRect: CGRect
    ) -> some View {
        if let position = viewportPosition(for: worldPosition, orientation: orientation) {
            if orientation == .vertical {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.9))
                    .frame(width: 1, height: contentRect.height)
                    .position(x: position, y: contentRect.midY)
            } else {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.9))
                    .frame(width: contentRect.width, height: 1)
                    .position(x: contentRect.midX, y: position)
            }
        }
    }

    /// 論理名（日本語）: Pointワールド座標取得関数
    /// 処理概要: ガイド方向に対応する Point 成分をキャンバスワールド座標へ変換します。
    ///
    /// - Parameters:
    ///   - point: CanvasPane 座標のドラッグ位置。
    ///   - orientation: 配置するガイド方向。
    /// - Returns: 垂直なら X、水平なら Y のワールド座標。
    private func worldPosition(
        at point: CGPoint,
        orientation: OpenGraphiteCanvasGuideOrientation
    ) -> Double? {
        CanvasAidCoordinateResolver.worldPosition(
            viewportPosition: orientation == .vertical ? point.x : point.y,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }

    /// 論理名（日本語）: ガイドViewport座標取得関数
    /// 処理概要: ガイド方向に対応するワールド座標を CanvasPane 上の線位置へ変換します。
    ///
    /// - Parameters:
    ///   - worldPosition: ガイドのワールド座標。
    ///   - orientation: ガイド方向。
    /// - Returns: 垂直なら X、水平なら Y の viewport 座標。
    private func viewportPosition(
        for worldPosition: Double,
        orientation: OpenGraphiteCanvasGuideOrientation
    ) -> CGFloat? {
        CanvasAidCoordinateResolver.viewportPosition(
            worldPosition: worldPosition,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }
}

/// 論理名（日本語）: ルーラーコンテキストメニューView
/// 概要: SwiftUI のドラッグ操作を遮らず、ルーラー内の右クリックだけを AppKit で監視してガイド追加メニューを表示します。
private struct CanvasRulerContextMenuView: NSViewRepresentable {
    var itemTitle: String
    var isActionEnabled: Bool
    var onAddGuide: (CGPoint) -> Void

    /// 論理名（日本語）: ルーラーコンテキストメニューAppKit View生成関数
    /// 処理概要: 右クリック位置とガイド追加callbackを保持する非ヒットテストViewを生成します。
    ///
    /// - Parameter context: SwiftUI が提供するRepresentableコンテキスト。
    /// - Returns: ルーラー右クリックをローカル監視するAppKit View。
    func makeNSView(context: Context) -> CanvasRulerContextMenuNSView {
        let view = CanvasRulerContextMenuNSView()
        update(view)
        return view
    }

    /// 論理名（日本語）: ルーラーコンテキストメニューAppKit View更新関数
    /// 処理概要: 表示文言、ガイド表示状態、追加callbackを最新のSwiftUI状態へ同期します。
    ///
    /// - Parameters:
    ///   - nsView: 更新対象のAppKit View。
    ///   - context: SwiftUI が提供するRepresentableコンテキスト。
    func updateNSView(_ nsView: CanvasRulerContextMenuNSView, context: Context) {
        update(nsView)
    }

    /// 論理名（日本語）: ルーラーコンテキストメニューView破棄関数
    /// 処理概要: SwiftUI階層から外れる際にローカルイベント監視を明示的に解除します。
    ///
    /// - Parameters:
    ///   - nsView: 破棄対象のAppKit View。
    ///   - coordinator: SwiftUI が提供するCoordinator。
    static func dismantleNSView(_ nsView: CanvasRulerContextMenuNSView, coordinator: Void) {
        nsView.stopMonitoring()
    }

    /// 論理名（日本語）: ルーラーコンテキストメニュー内容更新関数
    /// 処理概要: Representableの生成時と更新時に共通する値同期を適用します。
    ///
    /// - Parameter view: 値を同期するAppKit View。
    private func update(_ view: CanvasRulerContextMenuNSView) {
        view.itemTitle = itemTitle
        view.isActionEnabled = isActionEnabled
        view.onAddGuide = onAddGuide
    }
}

/// 論理名（日本語）: ルーラーコンテキストメニューAppKit View
/// 概要: 自身をマウスヒット対象にせず、同一Windowの右クリックからルーラー内座標を固定してネイティブメニューを開きます。
private final class CanvasRulerContextMenuNSView: NSView {
    var itemTitle = ""
    var isActionEnabled = true
    var onAddGuide: ((CGPoint) -> Void)?

    private var contextPoint = CGPoint.zero
    private var eventMonitor: Any?

    override var isFlipped: Bool { true }

    /// 論理名（日本語）: ルーラーコンテキストメニューViewヒットテスト関数
    /// 処理概要: SwiftUI側の左ドラッグ操作を維持するため、自身を通常のマウスイベント対象から除外します。
    ///
    /// - Parameter point: View内のヒットテスト位置。
    /// - Returns: 常に `nil`。
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// 論理名（日本語）: Window所属変更処理関数
    /// 処理概要: Windowへ追加された間だけ右クリックのローカルイベント監視を有効にします。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.handleRightMouseDown(event)
        }
    }

    /// 論理名（日本語）: 右クリックイベント処理関数
    /// 処理概要: 同一Windowかつ自身の表示矩形内だけを対象に、クリック位置を固定してガイド追加メニューを表示します。
    ///
    /// - Parameter event: AppKit から届いた右マウスダウンイベント。
    /// - Returns: メニューを表示した場合は `nil`、対象外の場合は元イベント。
    private func handleRightMouseDown(_ event: NSEvent) -> NSEvent? {
        guard let window,
              event.window === window,
              !isHiddenOrHasHiddenAncestor
        else {
            return event
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        guard bounds.contains(localPoint) else { return event }

        contextPoint = localPoint
        let menu = NSMenu(title: "OpenGraphite Ruler")
        let item = NSMenuItem(
            title: itemTitle,
            action: #selector(addGuideAtContextPoint),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = isActionEnabled
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return nil
    }

    /// 論理名（日本語）: 右クリック位置ガイド追加関数
    /// 処理概要: メニュー表示時に固定したルーラー内座標をSwiftUIへ通知します。
    @objc private func addGuideAtContextPoint() {
        guard isActionEnabled else { return }
        onAddGuide?(contextPoint)
    }

    /// 論理名（日本語）: 右クリック監視終了関数
    /// 処理概要: 登録済みのAppKitローカルイベントモニターを解除して保持を破棄します。
    func stopMonitoring() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }
}

/// 論理名（日本語）: キャンバスルーラー目盛りビュー
/// 概要: 現在 viewport に対応する数値ラベルと大小の目盛りを上または左ルーラーへ描画します。
///
/// プロパティ:
/// - `orientation`: X 軸を表示する上ルーラーまたは Y 軸を表示する左ルーラー。
/// - `paneOrigin`: ルーラー矩形の CanvasPane 座標原点。
/// - `viewport`: スクロール中の表示領域状態。
/// - `canvasOrigin`: 描画 content が基準にする world 原点。
/// - `zoom`: 現在のキャンバス倍率。
private struct CanvasRulerTicksView: View {
    var orientation: OpenGraphiteCanvasGuideOrientation
    var paneOrigin: CGPoint
    var viewport: CanvasViewportState
    var canvasOrigin: CGPoint
    var zoom: Double

    var body: some View {
        Canvas { context, size in
            drawTicks(context: &context, size: size)
        }
    }

    /// 論理名（日本語）: ルーラー目盛り描画関数
    /// 処理概要: visible world 範囲を走査し、小目盛り線と大目盛りの数値ラベルを描画します。
    ///
    /// - Parameters:
    ///   - context: SwiftUI Canvas の描画コンテキスト。
    ///   - size: ルーラー矩形の寸法。
    private func drawTicks(context: inout GraphicsContext, size: CGSize) {
        guard viewport.isReady, size.width > 0, size.height > 0 else { return }
        let minorStep = CanvasAidStepResolver.minorStep(zoom: zoom)
        let majorStep = CanvasAidStepResolver.majorStep(for: minorStep)
        let startPane = orientation == .vertical ? paneOrigin.x : paneOrigin.y
        let endPane = startPane + (orientation == .vertical ? size.width : size.height)
        guard let startWorld = worldPosition(at: startPane),
              let endWorld = worldPosition(at: endPane)
        else {
            return
        }

        var value = floor(min(startWorld, endWorld) / minorStep) * minorStep
        let maximum = max(startWorld, endWorld) + minorStep
        var tickPath = Path()
        var count = 0
        while value <= maximum, count < 1_000 {
            if let panePosition = viewportPosition(for: value) {
                let localPosition = panePosition - startPane
                let isMajor = abs(value / majorStep - (value / majorStep).rounded()) < 0.000_001
                if orientation == .vertical {
                    let length: CGFloat = isMajor ? 10 : 5
                    tickPath.move(to: CGPoint(x: localPosition, y: size.height - length))
                    tickPath.addLine(to: CGPoint(x: localPosition, y: size.height))
                    if isMajor {
                        let labelLayout = CanvasRulerLabelLayout.resolve(
                            orientation: orientation,
                            tickPosition: localPosition
                        )
                        context.draw(
                            rulerLabel(value),
                            at: labelLayout.position,
                            anchor: labelLayout.anchor
                        )
                    }
                } else {
                    let length: CGFloat = isMajor ? 10 : 5
                    tickPath.move(to: CGPoint(x: size.width - length, y: localPosition))
                    tickPath.addLine(to: CGPoint(x: size.width, y: localPosition))
                    if isMajor {
                        let labelLayout = CanvasRulerLabelLayout.resolve(
                            orientation: orientation,
                            tickPosition: localPosition
                        )
                        context.draw(
                            rulerLabel(value),
                            at: labelLayout.position,
                            anchor: labelLayout.anchor
                        )
                    }
                }
            }
            value += minorStep
            count += 1
        }
        context.stroke(tickPath, with: .color(.primary.opacity(0.55)), lineWidth: 0.75)
    }

    /// 論理名（日本語）: ルーラーラベル生成関数
    /// 処理概要: 大目盛り値を整数優先の小さな等幅ラベルへ変換します。
    ///
    /// - Parameter value: 表示するワールド座標。
    /// - Returns: SwiftUI Canvas で描画する Text。
    private func rulerLabel(_ value: Double) -> Text {
        let label = abs(value.rounded() - value) < 0.000_001
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
        return Text(label)
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(.secondary)
    }

    /// 論理名（日本語）: ルーラーワールド座標取得関数
    /// 処理概要: ルーラー方向に対応する viewport 成分をワールド座標へ変換します。
    ///
    /// - Parameter viewportPosition: CanvasPane 上の X または Y。
    /// - Returns: 対応するワールド座標。
    private func worldPosition(at viewportPosition: CGFloat) -> Double? {
        CanvasAidCoordinateResolver.worldPosition(
            viewportPosition: viewportPosition,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }

    /// 論理名（日本語）: ルーラーViewport座標取得関数
    /// 処理概要: 大小目盛りのワールド座標をルーラー上の画面位置へ変換します。
    ///
    /// - Parameter worldPosition: 目盛りのワールド座標。
    /// - Returns: CanvasPane 上の X または Y。
    private func viewportPosition(for worldPosition: Double) -> CGFloat? {
        CanvasAidCoordinateResolver.viewportPosition(
            worldPosition: worldPosition,
            visibleOrigin: orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: orientation)
        )
    }
}

/// 論理名（日本語）: ルーラー数値ラベル配置
/// 概要: 上・左ルーラーの数値中心を対応する主目盛り座標へ揃える描画位置とアンカーを解決します。
///
/// プロパティ:
/// - `position`: ルーラー内でラベルを描画する基準点。
/// - `anchor`: 基準点へラベルのどの位置を合わせるか。
struct CanvasRulerLabelLayout: Equatable {
    var position: CGPoint
    var anchor: UnitPoint

    /// 論理名（日本語）: ルーラーラベル配置解決関数
    /// 処理概要: 上ルーラーは数値の水平中心、左ルーラーは数値の垂直中心を主目盛り位置へ一致させます。
    ///
    /// - Parameters:
    ///   - orientation: X 軸を使う上ルーラーまたは Y 軸を使う左ルーラー。
    ///   - tickPosition: ルーラー内の主目盛り座標。
    /// - Returns: 数値中心が主目盛りへ一致する描画位置とアンカー。
    static func resolve(
        orientation: OpenGraphiteCanvasGuideOrientation,
        tickPosition: CGFloat
    ) -> CanvasRulerLabelLayout {
        if orientation == .vertical {
            return CanvasRulerLabelLayout(
                position: CGPoint(x: tickPosition, y: 3),
                anchor: .top
            )
        }
        return CanvasRulerLabelLayout(
            position: CGPoint(x: 3, y: tickPosition),
            anchor: .leading
        )
    }
}

/// 論理名（日本語）: 配置済みキャンバスガイドビュー
/// 概要: `.ogp` に保存済みのガイドを表示し、ドラッグ移動、位置の数値入力、ルーラー側へのドラッグ削除を提供します。
private struct CanvasPlacedGuideView: View {
    var guide: OpenGraphiteCanvasGuide
    var viewport: CanvasViewportState
    var canvasOrigin: CGPoint
    var zoom: Double
    var contentRect: CGRect
    var showsRulerMarker: Bool
    var coordinateSpaceName: String
    var onUpdate: (String, Double) -> Void
    var onDelete: (String) -> Void

    @State private var dragPosition: Double?
    @State private var positionEditorIsPresented = false
    @State private var draftPositionText = ""

    var body: some View {
        if let position = viewportPosition(for: dragPosition ?? guide.position) {
            ZStack {
                if guide.orientation == .vertical {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.88))
                        .frame(width: 1, height: contentRect.height)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 10, height: contentRect.height)
                        .contentShape(Rectangle())
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.88))
                        .frame(width: contentRect.width, height: 1)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: contentRect.width, height: 10)
                        .contentShape(Rectangle())
                }
            }
            .position(
                x: guide.orientation == .vertical ? position : contentRect.midX,
                y: guide.orientation == .horizontal ? position : contentRect.midY
            )
            .modifier(interactionModifier)
            .accessibilityLabel(guide.orientation == .vertical ? "垂直ガイド" : "水平ガイド")
            .accessibilityValue(
                CanvasGuidePositionInput.text(for: (dragPosition ?? guide.position).rounded())
            )
            .accessibilityHint("ドラッグで移動。コンテキストメニューで位置変更または削除")
            .alert(
                guide.orientation == .vertical ? "垂直ガイドの位置" : "水平ガイドの位置",
                isPresented: $positionEditorIsPresented
            ) {
                TextField("位置", text: $draftPositionText)
                Button("キャンセル", role: .cancel) {}
                Button("変更") {
                    commitDraftPosition()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draftPosition == nil)
            } message: {
                Text(guide.orientation == .vertical ? "X 座標を入力してください。" : "Y 座標を入力してください。")
            }

            if showsRulerMarker {
                let markerFrame = CanvasGuideRulerMarkerLayout.interactionFrame(
                    guidePosition: position,
                    orientation: guide.orientation,
                    contentRect: contentRect
                )
                CanvasGuideRulerMarker(orientation: guide.orientation)
                    .frame(width: markerFrame.width, height: markerFrame.height)
                    .position(x: markerFrame.midX, y: markerFrame.midY)
                    .modifier(interactionModifier)
                    .accessibilityLabel(
                        guide.orientation == .vertical
                            ? "垂直ガイドのルーラーマーカー"
                            : "水平ガイドのルーラーマーカー"
                    )
                    .accessibilityValue(
                        CanvasGuidePositionInput.text(for: (dragPosition ?? guide.position).rounded())
                    )
                    .accessibilityHint("ドラッグで移動。コンテキストメニューで位置変更または削除")
            }
        }
    }

    /// 論理名（日本語）: ガイド共通操作Modifier
    /// 概要: ガイド線とルーラー上の三角マーカーへ同じ移動・数値入力・削除インターフェースを付与します。
    private var interactionModifier: CanvasGuideInteractionModifier {
        CanvasGuideInteractionModifier(
            guide: guide,
            dragPosition: $dragPosition,
            contentRect: contentRect,
            coordinateSpaceName: coordinateSpaceName,
            worldPosition: { point in
                worldPosition(at: point)
            },
            onEditPosition: presentPositionEditor,
            onUpdate: onUpdate,
            onDelete: onDelete
        )
    }

    /// 論理名（日本語）: ガイド位置入力ダイアログ表示関数
    /// 処理概要: 最新の保存位置を入力欄へ設定し、右クリック元に関係なく共通ダイアログを表示します。
    private func presentPositionEditor() {
        draftPositionText = CanvasGuidePositionInput.text(for: guide.position)
        positionEditorIsPresented = true
    }

    /// 論理名（日本語）: ガイド位置入力値確定関数
    /// 処理概要: 有効な入力だけを既存のガイド更新経路へ渡し、Undo 可能な1操作として保存します。
    private func commitDraftPosition() {
        guard let draftPosition else { return }
        onUpdate(guide.id, draftPosition)
    }

    /// 論理名（日本語）: ガイド位置入力中の数値
    /// 概要: 入力文字列を `.ogp` へ保存可能な有限 world 座標として解決します。
    private var draftPosition: Double? {
        CanvasGuidePositionInput.value(from: draftPositionText)
    }

    /// 論理名（日本語）: ドラッグ位置ワールド座標取得関数
    /// 処理概要: ガイド方向に対応するドラッグ Point 成分をワールド座標へ変換します。
    ///
    /// - Parameter point: CanvasPane 座標のドラッグ位置。
    /// - Returns: ガイドの更新に使う X または Y ワールド座標。
    private func worldPosition(at point: CGPoint) -> Double? {
        CanvasAidCoordinateResolver.worldPosition(
            viewportPosition: guide.orientation == .vertical ? point.x : point.y,
            visibleOrigin: guide.orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: guide.orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: guide.orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: guide.orientation)
        )
    }

    /// 論理名（日本語）: ガイド画面位置取得関数
    /// 処理概要: 保存済みまたはドラッグ中のワールド座標を CanvasPane 上の線位置へ変換します。
    ///
    /// - Parameter worldPosition: ガイドのワールド座標。
    /// - Returns: 垂直なら X、水平なら Y の viewport 座標。
    private func viewportPosition(for worldPosition: Double) -> CGFloat? {
        CanvasAidCoordinateResolver.viewportPosition(
            worldPosition: worldPosition,
            visibleOrigin: guide.orientation == .vertical ? viewport.visibleOrigin.x : viewport.visibleOrigin.y,
            hostingOrigin: guide.orientation == .vertical ? viewport.hostingOrigin.x : viewport.hostingOrigin.y,
            canvasOrigin: guide.orientation == .vertical ? canvasOrigin.x : canvasOrigin.y,
            zoom: zoom,
            contentPadding: CanvasMetrics.documentPadding,
            contentOffset: CanvasAidCoordinateResolver.contentOffset(for: guide.orientation)
        )
    }
}

/// 論理名（日本語）: ガイドルーラーマーカー
/// 概要: ガイドが上または左ルーラーへ接する位置を小さなアクセント色の三角形で示します。
private struct CanvasGuideRulerMarker: View {
    var orientation: OpenGraphiteCanvasGuideOrientation

    var body: some View {
        CanvasGuideRulerMarkerShape(orientation: orientation)
            .fill(Color.accentColor)
            .frame(
                width: orientation == .vertical ? 9 : 7,
                height: orientation == .vertical ? 7 : 9
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: orientation == .vertical ? .bottom : .trailing
            )
            .contentShape(Rectangle())
    }
}

/// 論理名（日本語）: ガイドルーラーマーカー形状
/// 概要: 垂直ガイドでは下向き、水平ガイドでは右向きの三角形を描画します。
private struct CanvasGuideRulerMarkerShape: Shape {
    var orientation: OpenGraphiteCanvasGuideOrientation

    /// 論理名（日本語）: 三角形Path生成関数
    /// 処理概要: ガイド方向に応じてルーラーからキャンバス側を向く三角形を返します。
    ///
    /// - Parameter rect: 三角形を収める矩形。
    /// - Returns: 下向きまたは右向きの三角形 Path。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if orientation == .vertical {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// 論理名（日本語）: ガイド共通操作Modifier
/// 概要: ガイド線とルーラーマーカーへ共通のドラッグ移動、数値入力、ルーラー戻し削除、右クリック削除を提供します。
private struct CanvasGuideInteractionModifier: ViewModifier {
    var guide: OpenGraphiteCanvasGuide
    @Binding var dragPosition: Double?
    var contentRect: CGRect
    var coordinateSpaceName: String
    var worldPosition: (CGPoint) -> Double?
    var onEditPosition: () -> Void
    var onUpdate: (String, Double) -> Void
    var onDelete: (String) -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpaceName))
                    .onChanged { value in
                        dragPosition = worldPosition(value.location)?.rounded()
                    }
                    .onEnded { value in
                        defer { dragPosition = nil }
                        if CanvasGuideInteractionResolver.isDraggedBackToRuler(
                            location: value.location,
                            orientation: guide.orientation,
                            contentRect: contentRect
                        ) {
                            onDelete(guide.id)
                        } else if let position = worldPosition(value.location) {
                            onUpdate(guide.id, position.rounded())
                        }
                    }
            )
            .contextMenu {
                Button("位置を変更…") {
                    onEditPosition()
                }
                Divider()
                Button("ガイドを削除", role: .destructive) {
                    onDelete(guide.id)
                }
            }
    }
}
