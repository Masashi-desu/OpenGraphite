import AppKit
import SwiftUI

/// 論理名（日本語）: キャンバス注釈座標解決器
/// 概要: `.ogp` の canonical world 座標と、ページ名カード分だけ下へずれた Canvas 表示座標を相互変換します。
enum CanvasAnnotationCoordinateResolver {
    /// 論理名（日本語）: World座標変換関数
    /// 処理概要: 注釈レイヤー内の local 座標へ canvas bounds 原点を加え、`.ogp` の world 座標へ変換します。
    ///
    /// - Parameters:
    ///   - localPoint: ページ名カードオフセットを除いた注釈レイヤー内座標。
    ///   - canvasOrigin: 表示中 Canvas bounds の world 原点。
    /// - Returns: `.ogp` に保存する world 座標。
    static func worldPoint(localPoint: CGPoint, canvasOrigin: CGPoint) -> CGPoint {
        CGPoint(
            x: localPoint.x + canvasOrigin.x,
            y: localPoint.y + canvasOrigin.y
        )
    }

    /// 論理名（日本語）: 表示フレーム変換関数
    /// 処理概要: world 座標の注釈フレームを CanvasProjectView 内の local 表示フレームへ変換します。
    ///
    /// - Parameters:
    ///   - frame: `.ogp` の注釈フレーム。
    ///   - canvasOrigin: 表示中 Canvas bounds の world 原点。
    ///   - visualYOffset: ページ名カードの表示オフセット。
    /// - Returns: CanvasProjectView 内の表示フレーム。
    static func localFrame(
        _ frame: OpenGraphiteCanvasAnnotationFrame,
        canvasOrigin: CGPoint,
        visualYOffset: CGFloat
    ) -> CGRect {
        CGRect(
            x: CGFloat(frame.x) - canvasOrigin.x,
            y: CGFloat(frame.y) - canvasOrigin.y + visualYOffset,
            width: CGFloat(frame.width),
            height: CGFloat(frame.height)
        )
    }
}

/// 論理名（日本語）: 手書き線幅解決器
/// 概要: 保存済みの基準線幅と筆圧から、画面・PNG で共有できる実描画線幅を算出します。
enum CanvasInkLineWidthResolver {
    /// 論理名（日本語）: 筆圧反映線幅関数
    /// 処理概要: 0 から 1 の筆圧を視認可能な線幅倍率へ写し、0.5pt 以上を返します。
    ///
    /// - Parameters:
    ///   - baseWidth: ストロークの基準線幅。
    ///   - pressure: 正規化済み筆圧。
    /// - Returns: 描画に使う線幅。
    static func width(baseWidth: Double, pressure: Double) -> CGFloat {
        let normalizedPressure = pressure.isFinite ? min(max(pressure, 0), 1) : 1
        let normalizedBase = OpenGraphiteCanvasAnnotationLimits.lineWidth(baseWidth)
        return CGFloat(max(normalizedBase * (0.35 + normalizedPressure * 1.15), 0.5))
    }
}

/// 論理名（日本語）: 消しゴム描画寸法
/// 概要: 独立ツールと Sidecar の mode-change 入力で共有する、筆圧非依存の消去径を定義します。
///
/// 定義内容:
/// - `screenDiameter`: zoom に依存しない画面上の可視・判定共通直径。
/// - `pressure`: 消しゴム入力へ保存する固定筆圧。
/// - `minimumScreenSampleDistance`: 高頻度入力を間引く画面上の最小移動距離。
/// - `minimumSampleInterval`: pending軌跡をpreviewへ通知する最小時間間隔。
/// - `maximumLiveSampleCount`: 長時間gestureで一時表示が保持する最大サンプル数。
/// - `maximumPendingSampleCount`: 不正timestamp時にもpreview待機列をboundedに保つ上限。
/// - `baseLineWidth(zoom:)`: 共通線幅解決器で画面直径を再現する world 基準線幅。
/// - `minimumWorldSampleDistance(zoom:)`: 現在倍率に対応するworld最小移動距離。
enum CanvasEraserMetrics {
    static let screenDiameter: CGFloat = 8
    static let pressure = 1.0
    static let minimumScreenSampleDistance: CGFloat = 0.75
    static let minimumSampleInterval: TimeInterval = 1 / 60
    static let maximumLiveSampleCount = 256
    static let maximumPendingSampleCount = 32

    /// 論理名（日本語）: 消しゴムWorld基準線幅取得関数
    /// 処理概要: 画面上の消去径を一定に保つため、表示倍率で割った world 直径を線幅解決器の基準値へ変換します。
    ///
    /// - Parameter zoom: 現在の Canvas 表示倍率。
    /// - Returns: 固定筆圧1で画面直径8ptとなる world基準線幅。
    static func baseLineWidth(zoom: Double) -> Double {
        let safeZoom = zoom.isFinite && zoom > 0 ? zoom : 1
        return Double(screenDiameter) / safeZoom / 1.5
    }

    /// 論理名（日本語）: 消しゴムWorld最小サンプル距離取得関数
    /// 処理概要: Sidecarの高頻度eventを画面上0.75pt間隔へ整えるため、表示倍率に対応するworld距離を返します。
    ///
    /// - Parameter zoom: 現在の Canvas 表示倍率。
    /// - Returns: 入力サンプル間で必要なworld最小移動距離。
    static func minimumWorldSampleDistance(zoom: Double) -> CGFloat {
        let safeZoom = zoom.isFinite && zoom > 0 ? zoom : 1
        return minimumScreenSampleDistance / safeZoom
    }
}

/// 論理名（日本語）: 未確定手書きサンプル
/// 概要: pen-down から pen-up まで一時保持する world 座標、筆圧、傾き、入力デバイスを表します。
///
/// プロパティ:
/// - `point`: canonical world 座標。
/// - `pressure`: 0 から 1 の筆圧。
/// - `tiltX`: スタイラス傾きの X 成分。
/// - `tiltY`: スタイラス傾きの Y 成分。
/// - `inputDevice`: 入力デバイス種別。
/// - `deviceID`: proximity と tablet point 系列を対応付ける AppKit device ID。
/// - `timestamp`: AppKit event timestamp。
struct CanvasInkDraftSample: Equatable {
    var point: CGPoint
    var pressure: Double
    var tiltX: Double
    var tiltY: Double
    var inputDevice: OpenGraphiteInkInputDevice
    var deviceID: Int = 0
    var timestamp: TimeInterval
}

/// 論理名（日本語）: スタイラスイベント判定器
/// 概要: event 自身の tablet data と device ID に基づき、通常 mouse を proximity 中の Pencil と混同せず入力種別を解決します。
enum CanvasStylusEventResolver {
    /// 論理名（日本語）: 入力デバイス解決関数
    /// 処理概要: tablet point data を持つ event だけを同じ device ID の proximity 情報へ対応付け、通常 event は常に mouse とします。
    ///
    /// - Parameters:
    ///   - hasTabletPointData: event type または subtype が tablet point か。
    ///   - deviceID: event 自身の AppKit device ID。
    ///   - proximityDevices: proximity 内にある device ID 別の入力種別。
    ///   - isEraserMode: Pencil mode change による消しゴム切替状態。
    ///   - forcedInputDevice: ツール側から強制する入力種別。独立した消しゴムツールで使用します。
    /// - Returns: この event sample の入力デバイス種別。
    static func inputDevice(
        hasTabletPointData: Bool,
        deviceID: Int,
        proximityDevices: [Int: OpenGraphiteInkInputDevice],
        isEraserMode: Bool,
        forcedInputDevice: OpenGraphiteInkInputDevice? = nil
    ) -> OpenGraphiteInkInputDevice {
        if let forcedInputDevice { return forcedInputDevice }
        guard hasTabletPointData else { return .mouse }
        if isEraserMode { return .eraser }
        return proximityDevices[deviceID] ?? .pen
    }
}

/// 論理名（日本語）: 手書きストローク正規化器
/// 概要: world 座標の draft samples を `.ogp` の frame と frame-local point 列へ変換します。
enum CanvasInkStrokeNormalizer {
    /// 論理名（日本語）: 保存ストローク生成関数
    /// 処理概要: 重複点を除き、線幅余白を含む world bounds と相対点列を生成します。
    ///
    /// - Parameters:
    ///   - samples: pen-down から pen-up までの入力サンプル。
    ///   - color: 保存する線色。
    ///   - lineWidth: 基準線幅。
    /// - Returns: 保存用 frame と stroke。サンプルが空なら `nil`。
    static func normalizedStroke(
        samples: [CanvasInkDraftSample],
        color: String,
        lineWidth: Double
    ) -> (frame: OpenGraphiteCanvasAnnotationFrame, stroke: OpenGraphiteInkStroke)? {
        let deduplicated = deduplicatedSamples(samples)
        guard let first = deduplicated.first else { return nil }

        let safeLineWidth = OpenGraphiteCanvasAnnotationLimits.lineWidth(lineWidth)
        let halfWidth = safeLineWidth * 0.75
        let minX = deduplicated.map { Double($0.point.x) }.min() ?? Double(first.point.x)
        let minY = deduplicated.map { Double($0.point.y) }.min() ?? Double(first.point.y)
        let maxX = deduplicated.map { Double($0.point.x) }.max() ?? Double(first.point.x)
        let maxY = deduplicated.map { Double($0.point.y) }.max() ?? Double(first.point.y)
        let frame = OpenGraphiteCanvasAnnotationFrame(
            x: rounded(minX - halfWidth),
            y: rounded(minY - halfWidth),
            width: rounded(max(maxX - minX + halfWidth * 2, 1)),
            height: rounded(max(maxY - minY + halfWidth * 2, 1))
        )
        let inputDevice = deduplicated.first(where: { $0.inputDevice != .unknown })?.inputDevice ?? .unknown
        let points = deduplicated.map { sample in
            OpenGraphiteInkPoint(
                x: rounded(Double(sample.point.x) - frame.x),
                y: rounded(Double(sample.point.y) - frame.y),
                pressure: rounded(sample.pressure),
                tiltX: rounded(sample.tiltX),
                tiltY: rounded(sample.tiltY)
            )
        }
        return (
            frame,
            OpenGraphiteInkStroke(
                points: points,
                color: color,
                lineWidth: safeLineWidth,
                inputDevice: inputDevice
            )
        )
    }

    /// 論理名（日本語）: 重複サンプル除去関数
    /// 処理概要: 同一時刻かつほぼ同一位置で届く tabletPoint / mouse subtype の重複を除きます。
    ///
    /// - Parameter samples: 未確定入力サンプル。
    /// - Returns: 入力順を維持した重複除去済みサンプル。
    private static func deduplicatedSamples(_ samples: [CanvasInkDraftSample]) -> [CanvasInkDraftSample] {
        samples.reduce(into: []) { result, sample in
            guard sample.point.x.isFinite,
                  sample.point.y.isFinite,
                  sample.pressure.isFinite,
                  sample.tiltX.isFinite,
                  sample.tiltY.isFinite
            else {
                return
            }
            if let last = result.last {
                let deltaX = sample.point.x - last.point.x
                let deltaY = sample.point.y - last.point.y
                let sameLocation = hypot(deltaX, deltaY) < 0.05
                let sameTime = abs(sample.timestamp - last.timestamp) < 0.000_1
                let sameDevice = sample.deviceID == last.deviceID
                if sameLocation && sameTime && sameDevice {
                    return
                }
            }
            result.append(sample)
        }
    }

    /// 論理名（日本語）: 手書き数値丸め関数
    /// 処理概要: `.ogp` の点列肥大化を避けるため小数3桁へ丸めます。
    ///
    /// - Parameter value: 丸める数値。
    /// - Returns: 小数3桁へ丸めた数値。
    private static func rounded(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }
}

/// 論理名（日本語）: 消しゴムGesture保存文脈
/// 概要: pen-down時のproject・Chapter / Collection・注釈snapshotを固定し、途中のCanvas切替や外部更新へ古いpreviewを誤保存しないために使います。
///
/// プロパティ:
/// - `projectPath`: gesture開始時に開いていた`.ogp`の標準化path。
/// - `segment`: PagesまたはComponents。
/// - `containerInternalID`: gesture開始時のChapterまたはCollection内部ID。
/// - `annotations`: gesture開始時の注釈snapshot。
struct CanvasEraserGestureContext: Equatable {
    var projectPath: String?
    var segment: OpenGraphiteCanvasSegment
    var containerInternalID: String?
    var annotations: [OpenGraphiteCanvasAnnotation]

    /// 論理名（日本語）: 現在文脈一致判定関数
    /// 処理概要: gesture開始後もproject、segment、container、注釈payloadが全て同一かを判定します。
    ///
    /// - Parameters:
    ///   - projectPath: 現在開いている`.ogp`の標準化path。
    ///   - segment: 現在のPages / Components segment。
    ///   - containerInternalID: 現在のChapter / Collection内部ID。
    ///   - annotations: 現在の注釈配列。
    /// - Returns: 保存対象とpayloadがgesture開始時のsnapshotと一致する場合は`true`。
    func matches(
        projectPath: String?,
        segment: OpenGraphiteCanvasSegment,
        containerInternalID: String?,
        annotations: [OpenGraphiteCanvasAnnotation]
    ) -> Bool {
        self.projectPath == projectPath
            && self.segment == segment
            && self.containerInternalID == containerInternalID
            && self.annotations == annotations
    }
}

/// 論理名（日本語）: キャンバス注釈レイヤービュー
/// 概要: HTML preview の前面へ付箋と手書きを描画し、選択中ツールに応じて作成入力を受けます。
///
/// プロパティ:
/// - `store`: `.ogp` 保存と選択状態を扱う EditorStore。
/// - `bounds`: page と annotation の world bounds。
/// - `visualYOffset`: ページ名カードによる表示オフセット。
/// - `zoom`: 現在の Canvas 表示倍率。
struct CanvasAnnotationLayerView: View {
    @ObservedObject var store: EditorStore
    var bounds: CanvasProjectBounds
    var visualYOffset: CGFloat
    var zoom: Double

    @State private var dragPreviewAnchorID: String?
    @State private var dragPreviewTranslation: CGSize = .zero
    @State private var eraserPreviewAnnotations: [OpenGraphiteCanvasAnnotation]?
    @State private var eraserGestureContext: CanvasEraserGestureContext?
    @State private var isEraserGestureInvalidated = false

    var body: some View {
        let annotations = store.selectedCanvasAnnotations
        let displayedAnnotations = eraserPreviewAnnotations ?? annotations
        let canvasOrigin = bounds.origin
        let projectURL = store.loadedProject?.fileURL
        let usesExplicitEraser = store.activeTool == .eraser

        ZStack(alignment: .topLeading) {
            CanvasInkRenderingView(
                annotations: displayedAnnotations,
                canvasOrigin: canvasOrigin,
                previewAnnotationIDs: dragPreviewAnchorID == nil
                    ? []
                    : store.selectedCanvasAnnotationIDs,
                previewTranslation: dragPreviewTranslation
            )
                .frame(width: bounds.width, height: bounds.height)
                .offset(y: visualYOffset)
                .allowsHitTesting(false)

            ForEach(displayedAnnotations.filter {
                $0.kind == .ink
                    && store.activeTool != .select
                    && store.selectedCanvasAnnotationIDs.contains($0.internalID)
            }) { annotation in
                Rectangle()
                    .fill(Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(
                                Color.accentColor,
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                            )
                    )
                    .frame(
                        width: max(CGFloat(annotation.frame.width), 12),
                        height: max(CGFloat(annotation.frame.height), 12)
                    )
                    .offset(
                        x: CGFloat(annotation.frame.x) - canvasOrigin.x
                            + dragPreviewOffset(for: annotation.internalID).width,
                        y: CGFloat(annotation.frame.y) - canvasOrigin.y + visualYOffset
                            + dragPreviewOffset(for: annotation.internalID).height
                    )
                    .allowsHitTesting(false)
            }

            if store.activeTool == .stickyNote {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: bounds.width, height: bounds.height)
                    .offset(y: visualYOffset)
                    .gesture(
                        SpatialTapGesture(coordinateSpace: .named("OpenGraphiteCanvasAnnotationLayer"))
                            .onEnded { value in
                                let localPoint = CGPoint(
                                    x: value.location.x,
                                    y: value.location.y - visualYOffset
                                )
                                let worldPoint = CanvasAnnotationCoordinateResolver.worldPoint(
                                    localPoint: localPoint,
                                    canvasOrigin: canvasOrigin
                                )
                                store.addStickyNote(at: worldPoint)
                            }
                    )
            }

            if store.activeTool == .select {
                ForEach(annotations.filter { $0.kind == .ink }) { annotation in
                    CanvasInkSelectionTarget(
                        annotation: annotation,
                        isSelected: store.selectedCanvasAnnotationIDs.contains(annotation.internalID),
                        selectionCount: store.selectedCanvasAnnotationIDs.contains(annotation.internalID)
                            ? store.selectedCanvasAnnotationIDs.count
                            : 1,
                        zoom: zoom,
                        onSelect: { store.selectCanvasAnnotation(id: annotation.internalID) },
                        onMovePreview: {
                            updateDragPreview(anchorID: annotation.internalID, translation: $0)
                        },
                        onMove: {
                            commitDragPreview(
                                anchorID: annotation.internalID,
                                translation: $0
                            )
                        },
                        onDelete: { store.deleteCanvasAnnotation(id: annotation.internalID) },
                        onDeleteSelection: { store.deleteSelectedCanvasAnnotations() },
                        onCopyReference: { store.copyCanvasAnnotationReferenceIDToPasteboard(annotation) },
                        onCopySelection: { store.copySelectedCanvasAnnotationReferenceIDsToPasteboard() }
                    )
                    .frame(
                        width: max(CGFloat(annotation.frame.width), 12),
                        height: max(CGFloat(annotation.frame.height), 12)
                    )
                    .offset(
                        x: CGFloat(annotation.frame.x) - canvasOrigin.x
                            + dragPreviewOffset(for: annotation.internalID).width,
                        y: CGFloat(annotation.frame.y) - canvasOrigin.y + visualYOffset
                            + dragPreviewOffset(for: annotation.internalID).height
                    )
                }
            }

            ForEach(annotations.filter { $0.kind == .stickyNote }) { annotation in
                CanvasStickyNoteView(
                    annotation: annotation,
                    isSelected: store.selectedCanvasAnnotationIDs.contains(annotation.internalID),
                    selectionCount: store.selectedCanvasAnnotationIDs.contains(annotation.internalID)
                        ? store.selectedCanvasAnnotationIDs.count
                        : 1,
                    zoom: zoom,
                    projectURL: projectURL,
                    onSelect: { store.selectCanvasAnnotation(id: annotation.internalID) },
                    onTextChange: { store.stageCanvasAnnotationText(id: annotation.internalID, text: $0) },
                    onTextCommit: { targetProjectURL, text in
                        store.updateCanvasAnnotationText(
                            projectURL: targetProjectURL,
                            id: annotation.internalID,
                            text: text
                        )
                    },
                    onMovePreview: {
                        updateDragPreview(anchorID: annotation.internalID, translation: $0)
                    },
                    onMove: {
                        commitDragPreview(
                            anchorID: annotation.internalID,
                            translation: $0
                        )
                    },
                    onDelete: { store.deleteCanvasAnnotation(id: annotation.internalID) },
                    onDeleteSelection: { store.deleteSelectedCanvasAnnotations() },
                    onCopyReference: { store.copyCanvasAnnotationReferenceIDToPasteboard(annotation) },
                    onCopySelection: { store.copySelectedCanvasAnnotationReferenceIDsToPasteboard() }
                )
                .id("\(projectURL?.standardizedFileURL.path ?? "")#\(annotation.internalID)")
                .frame(width: CGFloat(annotation.frame.width), height: CGFloat(annotation.frame.height))
                .offset(
                    x: CGFloat(annotation.frame.x) - canvasOrigin.x
                        + dragPreviewOffset(for: annotation.internalID).width,
                    y: CGFloat(annotation.frame.y) - canvasOrigin.y + visualYOffset
                        + dragPreviewOffset(for: annotation.internalID).height
                )
            }

            if store.activeTool == .lasso {
                CanvasLassoInputView(
                    annotations: annotations,
                    canvasOrigin: canvasOrigin,
                    selectedCount: store.selectedCanvasAnnotationIDs.count,
                    onSelection: { store.selectCanvasAnnotations(ids: $0) },
                    onDeleteSelected: { store.deleteSelectedCanvasAnnotations() },
                    onCopySelected: { store.copySelectedCanvasAnnotationReferenceIDsToPasteboard() }
                )
                .frame(width: bounds.width, height: bounds.height)
                .offset(y: visualYOffset)
            }

            if store.activeTool == .pen || usesExplicitEraser {
                CanvasStylusInputView(
                    canvasOrigin: canvasOrigin,
                    color: usesExplicitEraser ? "#6B7280" : "#FF4D67",
                    lineWidth: 3.5,
                    eraserLineWidth: CanvasEraserMetrics.baseLineWidth(zoom: zoom),
                    eraserMinimumSampleDistance: CanvasEraserMetrics.minimumWorldSampleDistance(zoom: zoom),
                    forcedInputDevice: usesExplicitEraser ? .eraser : nil,
                    onPreview: { frame, stroke in
                        guard stroke.inputDevice == .eraser else { return }
                        previewInkErasure(intersecting: frame, stroke: stroke)
                    },
                    onEraserCommit: {
                        commitInkErasure()
                    }
                ) { frame, stroke in
                    store.addInkAnnotation(frame: frame, strokes: [stroke])
                }
                .frame(width: bounds.width, height: bounds.height)
                .offset(y: visualYOffset)
            }
        }
        .frame(
            width: bounds.width,
            height: bounds.height + visualYOffset,
            alignment: .topLeading
        )
        .coordinateSpace(name: "OpenGraphiteCanvasAnnotationLayer")
        .onChange(of: store.activeTool) { _, _ in
            clearDragPreview()
            clearEraserGesture()
        }
        .onDisappear {
            clearDragPreview()
            clearEraserGesture()
        }
    }

    /// 論理名（日本語）: 注釈ドラッグプレビュー差分取得関数
    /// 処理概要: ドラッグanchorを含む同時選択注釈へだけ、確定前の共通移動量を返します。
    ///
    /// - Parameter annotationID: 表示する注釈 ID。
    /// - Returns: 選択集合のドラッグプレビュー対象なら共通移動量、それ以外はゼロ。
    private func dragPreviewOffset(for annotationID: String) -> CGSize {
        guard dragPreviewAnchorID != nil,
              store.selectedCanvasAnnotationIDs.contains(annotationID)
        else {
            return .zero
        }
        return dragPreviewTranslation
    }

    /// 論理名（日本語）: 注釈ドラッグプレビュー更新関数
    /// 処理概要: 選択集合全体をmouse-up前から同じ差分で表示するため、anchorと一時移動量を保持します。
    ///
    /// - Parameters:
    ///   - anchorID: dragを開始した注釈 ID。
    ///   - translation: zoom補正済みworld移動量。
    private func updateDragPreview(anchorID: String, translation: CGSize) {
        dragPreviewAnchorID = anchorID
        dragPreviewTranslation = translation
    }

    /// 論理名（日本語）: 注釈ドラッグ確定関数
    /// 処理概要: 一時表示を解除し、同じ移動量を選択集合の `.ogp` frameへ一度だけ保存します。
    ///
    /// - Parameters:
    ///   - anchorID: dragを開始した注釈 ID。
    ///   - translation: zoom補正済みworld移動量。
    private func commitDragPreview(anchorID: String, translation: CGSize) {
        clearDragPreview()
        store.moveSelectedCanvasAnnotations(anchorID: anchorID, translation: translation)
    }

    /// 論理名（日本語）: 注釈ドラッグプレビュー解除関数
    /// 処理概要: ツール切替、view終了、drag確定時に一時移動状態を初期化します。
    private func clearDragPreview() {
        dragPreviewAnchorID = nil
        dragPreviewTranslation = .zero
    }

    /// 論理名（日本語）: 手書き部分消去プレビュー関数
    /// 処理概要: eraser dragの直近60Hz区間に含まれるsegment列を前回previewへ累積し、`.ogp`を書き換えず分割後fragmentを即時表示します。
    ///
    /// - Parameters:
    ///   - frame: eraser gesture を包含する world frame。
    ///   - stroke: frame-local の eraser point 列。
    private func previewInkErasure(
        intersecting frame: OpenGraphiteCanvasAnnotationFrame,
        stroke: OpenGraphiteInkStroke
    ) {
        let context: CanvasEraserGestureContext
        if let existingContext = eraserGestureContext {
            context = existingContext
        } else {
            let newContext = currentEraserGestureContext()
            eraserGestureContext = newContext
            isEraserGestureInvalidated = false
            context = newContext
        }
        guard !isEraserGestureInvalidated,
              isCurrentEraserGestureContext(context)
        else {
            isEraserGestureInvalidated = true
            eraserPreviewAnnotations = nil
            return
        }

        let sourceAnnotations = eraserPreviewAnnotations ?? context.annotations
        let result = resolveInkErasure(
            in: sourceAnnotations,
            intersecting: frame,
            stroke: stroke
        )
        if result.didChange {
            eraserPreviewAnnotations = result.annotations
        }
    }

    /// 論理名（日本語）: 手書き部分消去確定関数
    /// 処理概要: drag中に直近segmentずつ累積したpreviewを再計算せず、分割更新と完全消去として`.ogp`へ一度だけatomic保存します。
    private func commitInkErasure() {
        guard let context = eraserGestureContext,
              !isEraserGestureInvalidated,
              isCurrentEraserGestureContext(context),
              let previewAnnotations = eraserPreviewAnnotations
        else {
            clearEraserGesture()
            return
        }
        defer { clearEraserGesture() }

        guard let payload = CanvasInkErasureCommitResolver.resolve(
            originalAnnotations: context.annotations,
            previewAnnotations: previewAnnotations,
            currentAnnotations: store.selectedCanvasAnnotations
        ) else {
            return
        }
        store.applyCanvasInkErasure(
            updatedAnnotations: payload.updatedAnnotations,
            deletedIDs: payload.deletedIDs,
            expectedAnnotations: context.annotations
        )
    }

    /// 論理名（日本語）: 現在消しゴムGesture文脈生成関数
    /// 処理概要: 最初のeraser preview時点のproject・container identityと注釈snapshotを固定します。
    ///
    /// - Returns: 現在Canvasを表す保存文脈。
    private func currentEraserGestureContext() -> CanvasEraserGestureContext {
        CanvasEraserGestureContext(
            projectPath: store.loadedProject?.fileURL.standardizedFileURL.path,
            segment: store.selectedCanvasSegment,
            containerInternalID: currentCanvasContainerInternalID,
            annotations: store.selectedCanvasAnnotations
        )
    }

    /// 論理名（日本語）: 消しゴムGesture文脈一致判定関数
    /// 処理概要: project・containerと注釈snapshotがpen-down後に変化していないことを確かめ、古いpreviewの誤保存を防ぎます。
    ///
    /// - Parameter context: gesture開始時に固定した文脈。
    /// - Returns: 現在も同じ保存対象・同じ注釈payloadなら`true`。
    private func isCurrentEraserGestureContext(_ context: CanvasEraserGestureContext) -> Bool {
        context.matches(
            projectPath: store.loadedProject?.fileURL.standardizedFileURL.path,
            segment: store.selectedCanvasSegment,
            containerInternalID: currentCanvasContainerInternalID,
            annotations: store.selectedCanvasAnnotations
        )
    }

    /// 論理名（日本語）: 現在CanvasコンテナID取得関数
    /// 処理概要: PagesではChapter、ComponentsではCollectionの内部IDを返します。
    ///
    /// - Returns: 現在表示中containerの内部ID。
    private var currentCanvasContainerInternalID: String? {
        switch store.selectedCanvasSegment {
        case .pages:
            return store.selectedChapter?.internalID
        case .components:
            return store.selectedComponentCollection?.internalID
        }
    }

    /// 論理名（日本語）: 消しゴムGesture状態解除関数
    /// 処理概要: pen-up、ツール切替、view終了時にpreview・保存文脈・無効化状態を破棄します。
    private func clearEraserGesture() {
        eraserPreviewAnnotations = nil
        eraserGestureContext = nil
        isEraserGestureInvalidated = false
    }

    /// 論理名（日本語）: 手書き部分消去一括解決関数
    /// 処理概要: 追加された直近eraser区間を現在のpreview全inkへ適用し、表示順を保つ次のpreviewを構成します。
    ///
    /// - Parameters:
    ///   - annotations: 今回の追加segmentを適用する保存済みまたはpreview中の注釈列。
    ///   - frame: eraser gesture を包含する world frame。
    ///   - stroke: frame-local の eraser point 列。
    /// - Returns: 部分消去後の全注釈と変更有無。
    private func resolveInkErasure(
        in annotations: [OpenGraphiteCanvasAnnotation],
        intersecting frame: OpenGraphiteCanvasAnnotationFrame,
        stroke: OpenGraphiteInkStroke
    ) -> (annotations: [OpenGraphiteCanvasAnnotation], didChange: Bool) {
        var resolvedAnnotations: [OpenGraphiteCanvasAnnotation] = []
        var didChange = false

        for annotation in annotations {
            guard annotation.kind == .ink else {
                resolvedAnnotations.append(annotation)
                continue
            }
            switch CanvasInkPartialEraser.erase(
                annotation: annotation,
                eraserFrame: frame,
                eraserStroke: stroke
            ) {
            case .unchanged:
                resolvedAnnotations.append(annotation)
            case .updated(let updatedAnnotation):
                resolvedAnnotations.append(updatedAnnotation)
                didChange = true
            case .deleted:
                didChange = true
            }
        }
        return (resolvedAnnotations, didChange)
    }

}

/// 論理名（日本語）: キャンバス注釈なげわ入力ビュー
/// 概要: 自由曲線を一時表示し、確定時に world 座標の閉多角形として付箋と手書きの複数選択を解決します。
private struct CanvasLassoInputView: View {
    var annotations: [OpenGraphiteCanvasAnnotation]
    var canvasOrigin: CGPoint
    var selectedCount: Int
    var onSelection: ([String]) -> Void
    var onDeleteSelected: () -> Void
    var onCopySelected: () -> Void

    @State private var points: [CGPoint] = []

    var body: some View {
        Canvas { context, _ in
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            if points.count > 2 {
                path.closeSubpath()
                context.fill(path, with: .color(Color.accentColor.opacity(0.10)))
            }
            context.stroke(
                path,
                with: .color(Color.accentColor.opacity(0.90)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [6, 4])
            )
        }
        .contentShape(Rectangle())
        .gesture(lassoGesture)
        .contextMenu {
            Button("選択した\(selectedCount)件の参照IDをコピー", action: onCopySelected)
                .disabled(selectedCount == 0)
            Divider()
            Button("選択した\(selectedCount)件を削除", role: .destructive, action: onDeleteSelected)
                .disabled(selectedCount == 0)
        }
        .accessibilityLabel("なげわ選択領域")
    }

    private var lassoGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                append(value.location, to: &points)
            }
            .onEnded { value in
                var completedPoints = points
                append(value.location, to: &completedPoints)
                points = []
                let worldPolygon = completedPoints.map { point in
                    CanvasAnnotationCoordinateResolver.worldPoint(
                        localPoint: point,
                        canvasOrigin: canvasOrigin
                    )
                }
                guard CanvasAnnotationLassoSelectionResolver.isValidPolygon(worldPolygon) else { return }
                onSelection(
                    CanvasAnnotationLassoSelectionResolver.selectedAnnotationIDs(
                        in: annotations,
                        by: worldPolygon
                    )
                )
            }
    }

    /// 論理名（日本語）: なげわ点追加関数
    /// 処理概要: 近接した drag event を間引き、表示と判定に必要な点だけを保持します。
    ///
    /// - Parameters:
    ///   - point: 追加候補の view-local 座標。
    ///   - target: 追加先の点列。
    private func append(_ point: CGPoint, to target: inout [CGPoint]) {
        guard point.x.isFinite, point.y.isFinite else { return }
        if let last = target.last, hypot(last.x - point.x, last.y - point.y) < 2 {
            return
        }
        target.append(point)
    }

}

/// 論理名（日本語）: Canvas付箋Text同期状態
/// 概要: 入力中draft、未確定保存、model反映中フラグをまとめ、Undo / Redo後のtextを再保存しないようにします。
///
/// プロパティ:
/// - `draftText`: TextEditorに表示する編集中text。
/// - `hasUncommittedText`: debounceまたはfocus lossで保存すべき入力があるか。
struct CanvasStickyNoteTextSyncState: Equatable {
    var draftText: String
    private(set) var hasUncommittedText = false
    private var isApplyingStoredText = false

    /// 論理名（日本語）: Canvas付箋Text同期状態初期化関数
    /// 処理概要: 保存済みtextを初期draftとし、未確定入力のない状態を生成します。
    ///
    /// - Parameter draftText: TextEditorへ初期表示する保存済みtext。
    init(draftText: String) {
        self.draftText = draftText
    }

    /// 論理名（日本語）: Draft変更登録関数
    /// 処理概要: ユーザー入力を未確定として登録し、model同期によるdraft更新は入力として扱わないようにします。
    ///
    /// - Returns: 変更をユーザー入力としてstage・保存予約する場合は`true`。
    mutating func registerDraftChange() -> Bool {
        if isApplyingStoredText {
            isApplyingStoredText = false
            return false
        }
        hasUncommittedText = true
        return true
    }

    /// 論理名（日本語）: 保存済みText反映要否判定関数
    /// 処理概要: Undo / Redoを含むmodel textが現在のdraftと異なるかを判定します。
    ///
    /// - Parameter storedText: modelから通知された保存済みtext。
    /// - Returns: pending入力を破棄してdraftへ反映する必要がある場合は`true`。
    func shouldApplyStoredText(_ storedText: String) -> Bool {
        storedText != draftText
    }

    /// 論理名（日本語）: 保存済みText反映関数
    /// 処理概要: 未確定入力を解除し、model textをdraftへ設定して後続onChangeの再保存を抑止します。
    ///
    /// - Parameter storedText: Undo / Redoまたは外部同期後のmodel text。
    mutating func applyStoredText(_ storedText: String) {
        guard shouldApplyStoredText(storedText) else { return }
        hasUncommittedText = false
        isApplyingStoredText = true
        draftText = storedText
    }

    /// 論理名（日本語）: 指定Draft保存確定関数
    /// 処理概要: debounce予約時と同じdraftが未確定の場合だけ保存対象として取り出します。
    ///
    /// - Parameter expectedDraft: debounce予約時にcaptureしたdraft。
    /// - Returns: 保存対象text。予約後にmodel同期や追加入力があれば`nil`。
    mutating func takePendingText(expectedDraft: String) -> String? {
        guard hasUncommittedText, draftText == expectedDraft else { return nil }
        hasUncommittedText = false
        return draftText
    }

    /// 論理名（日本語）: 未確定Draft保存確定関数
    /// 処理概要: focus lossまたはview終了時に現在の未確定draftを保存対象として取り出します。
    ///
    /// - Returns: 未確定なら現在のdraft、確定済みなら`nil`。
    mutating func takePendingText() -> String? {
        guard hasUncommittedText else { return nil }
        hasUncommittedText = false
        return draftText
    }
}

/// 論理名（日本語）: キャンバス付箋ビュー
/// 概要: 付箋テキストの debounce 保存、選択、移動、削除を扱います。
private struct CanvasStickyNoteView: View {
    var annotation: OpenGraphiteCanvasAnnotation
    var isSelected: Bool
    var selectionCount: Int
    var zoom: Double
    var projectURL: URL?
    var onSelect: () -> Void
    var onTextChange: (String) -> Void
    var onTextCommit: (URL?, String) -> Void
    var onMovePreview: (CGSize) -> Void
    var onMove: (CGSize) -> Void
    var onDelete: () -> Void
    var onDeleteSelection: () -> Void
    var onCopyReference: () -> Void
    var onCopySelection: () -> Void

    @State private var textSyncState: CanvasStickyNoteTextSyncState
    @State private var saveTask: Task<Void, Never>?
    @State private var targetProjectURL: URL?
    @FocusState private var isTextFocused: Bool

    /// 論理名（日本語）: キャンバス付箋ビュー初期化関数
    /// 処理概要: 保存済み付箋テキストを編集用 local state へ初期設定します。
    ///
    /// - Parameters:
    ///   - annotation: 表示する付箋注釈。
    ///   - isSelected: 選択中か。
    ///   - selectionCount: この付箋を含む同時選択件数。
    ///   - zoom: Canvas 表示倍率。
    ///   - projectURL: debounce 開始時の保存対象 `.ogp` URL。
    ///   - onSelect: 選択処理。
    ///   - onTextChange: 入力ごとの app cache 反映処理。
    ///   - onTextCommit: debounce 後の `.ogp` 保存処理。
    ///   - onMovePreview: drag中の選択集合表示処理。
    ///   - onMove: 移動確定処理。
    ///   - onDelete: この付箋だけの削除処理。
    ///   - onDeleteSelection: 同時選択全体の削除処理。
    ///   - onCopyReference: この付箋だけの参照 ID コピー処理。
    ///   - onCopySelection: 同時選択全体の参照 ID コピー処理。
    init(
        annotation: OpenGraphiteCanvasAnnotation,
        isSelected: Bool,
        selectionCount: Int,
        zoom: Double,
        projectURL: URL?,
        onSelect: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onTextCommit: @escaping (URL?, String) -> Void,
        onMovePreview: @escaping (CGSize) -> Void,
        onMove: @escaping (CGSize) -> Void,
        onDelete: @escaping () -> Void,
        onDeleteSelection: @escaping () -> Void,
        onCopyReference: @escaping () -> Void,
        onCopySelection: @escaping () -> Void
    ) {
        self.annotation = annotation
        self.isSelected = isSelected
        self.selectionCount = selectionCount
        self.zoom = zoom
        self.projectURL = projectURL
        self.onSelect = onSelect
        self.onTextChange = onTextChange
        self.onTextCommit = onTextCommit
        self.onMovePreview = onMovePreview
        self.onMove = onMove
        self.onDelete = onDelete
        self.onDeleteSelection = onDeleteSelection
        self.onCopyReference = onCopyReference
        self.onCopySelection = onCopySelection
        self._textSyncState = State(initialValue: CanvasStickyNoteTextSyncState(draftText: annotation.text))
        self._targetProjectURL = State(initialValue: projectURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(noteTextColor.opacity(0.55))
                Spacer(minLength: 0)
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(noteTextColor.opacity(0.7))
                .accessibilityLabel("付箋を削除")
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(noteDragGesture)

            TextEditor(text: $textSyncState.draftText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(noteTextColor)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 7)
                .padding(.bottom, 8)
                .focused($isTextFocused)
                .focusedValue(\.isCanvasStickyNoteTextEditorFocused, true)
                .onTapGesture { onSelect() }
        }
        .background(noteBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.10), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.20), radius: 8, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture { onSelect() }
        .contextMenu {
            Button(selectionCount > 1 ? "選択した\(selectionCount)件の参照IDをコピー" : "参照IDをコピー") {
                if selectionCount > 1 {
                    onCopySelection()
                } else {
                    onCopyReference()
                }
            }
            Divider()
            Button(selectionCount > 1 ? "選択した\(selectionCount)件を削除" : "付箋を削除", role: .destructive) {
                if selectionCount > 1 {
                    onDeleteSelection()
                } else {
                    onDelete()
                }
            }
        }
        .onAppear {
            if isSelected && annotation.text.isEmpty {
                isTextFocused = true
            }
        }
        .onChange(of: textSyncState.draftText) { _, value in
            guard textSyncState.registerDraftChange() else { return }
            onTextChange(value)
            scheduleTextSave(value)
        }
        .onChange(of: annotation.text) { _, value in
            guard textSyncState.shouldApplyStoredText(value) else { return }
            saveTask?.cancel()
            saveTask = nil
            textSyncState.applyStoredText(value)
        }
        .onChange(of: isTextFocused) { _, focused in
            if !focused {
                flushTextSave()
            }
        }
        .onDisappear {
            flushTextSave()
        }
    }

    private var noteBackgroundColor: Color {
        CanvasAnnotationColor.color(annotation.backgroundColor, fallback: NSColor(calibratedRed: 1, green: 0.91, blue: 0.54, alpha: 1))
    }

    private var noteTextColor: Color {
        CanvasAnnotationColor.color(annotation.textColor, fallback: NSColor(calibratedWhite: 0.12, alpha: 1))
    }

    private var noteDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if !isSelected {
                    onSelect()
                }
                onMovePreview(CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                ))
            }
            .onEnded { value in
                let translation = CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                onMovePreview(.zero)
                onMove(translation)
            }
    }

    /// 論理名（日本語）: 付箋テキスト保存予約関数
    /// 処理概要: 連続入力中の atomic write を避け、400ms 入力が止まった時点で保存します。
    ///
    /// - Parameter value: 保存予約するテキスト。
    private func scheduleTextSave(_ value: String) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            guard let pendingText = textSyncState.takePendingText(expectedDraft: value) else { return }
            onTextCommit(targetProjectURL, pendingText)
            saveTask = nil
        }
    }

    /// 論理名（日本語）: 付箋テキスト即時保存関数
    /// 処理概要: focus loss または view 終了時に debounce を止め、未保存テキストを確定します。
    private func flushTextSave() {
        saveTask?.cancel()
        saveTask = nil
        guard let pendingText = textSyncState.takePendingText() else { return }
        onTextCommit(targetProjectURL, pendingText)
    }
}

/// 論理名（日本語）: 手書き注釈選択領域
/// 概要: 選択ツール時に手書き注釈の参照 ID コピーと削除を提供する透明 hit target です。
private struct CanvasInkSelectionTarget: View {
    var annotation: OpenGraphiteCanvasAnnotation
    var isSelected: Bool
    var selectionCount: Int
    var zoom: Double
    var onSelect: () -> Void
    var onMovePreview: (CGSize) -> Void
    var onMove: (CGSize) -> Void
    var onDelete: () -> Void
    var onDeleteSelection: () -> Void
    var onCopyReference: () -> Void
    var onCopySelection: () -> Void

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(CanvasInkHitShape(annotation: annotation))
            .overlay {
                Rectangle()
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
                    .allowsHitTesting(false)
            }
            .onTapGesture(perform: onSelect)
            .gesture(inkDragGesture)
            .contextMenu {
                Button(selectionCount > 1 ? "選択した\(selectionCount)件の参照IDをコピー" : "参照IDをコピー") {
                    if selectionCount > 1 {
                        onCopySelection()
                    } else {
                        onCopyReference()
                    }
                }
                Divider()
                Button(selectionCount > 1 ? "選択した\(selectionCount)件を削除" : "手書きを削除", role: .destructive) {
                    if selectionCount > 1 {
                        onDeleteSelection()
                    } else {
                        onDelete()
                    }
                }
            }
    }

    private var inkDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if !isSelected {
                    onSelect()
                }
                onMovePreview(CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                ))
            }
            .onEnded { value in
                let translation = CanvasPageDragResolver.canvasTranslation(
                    screenTranslation: value.translation,
                    zoom: zoom
                )
                onMovePreview(.zero)
                onMove(translation)
            }
    }
}

/// 論理名（日本語）: 手書き注釈ヒット領域
/// 概要: 外接矩形全体ではなく、保存済みの実線と操作余白に沿った選択領域を生成します。
struct CanvasInkHitShape: Shape {
    var annotation: OpenGraphiteCanvasAnnotation

    /// 論理名（日本語）: 手書きヒットパス生成関数
    /// 処理概要: 各点を円、各線分を太さ付き四角形として合成し、細い線も選択できる最小操作幅を確保します。
    ///
    /// - Parameter rect: SwiftUI が提示する注釈ローカル矩形。
    /// - Returns: frame-local point 列に沿う閉じたヒット領域。
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for stroke in annotation.strokes {
            let samples = stroke.points.map { point in
                (
                    point: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)),
                    radius: max(
                        CanvasInkLineWidthResolver.width(
                            baseWidth: stroke.lineWidth,
                            pressure: point.pressure
                        ) / 2 + 3,
                        6
                    )
                )
            }
            for sample in samples {
                path.addEllipse(in: CGRect(
                    x: sample.point.x - sample.radius,
                    y: sample.point.y - sample.radius,
                    width: sample.radius * 2,
                    height: sample.radius * 2
                ))
            }
            guard samples.count > 1 else { continue }

            for index in 1..<samples.count {
                let start = samples[index - 1]
                let end = samples[index]
                let deltaX = end.point.x - start.point.x
                let deltaY = end.point.y - start.point.y
                let length = hypot(deltaX, deltaY)
                guard length > 0.000_1 else { continue }
                let radius = max(start.radius, end.radius)
                let perpendicular = CGPoint(
                    x: -deltaY / length * radius,
                    y: deltaX / length * radius
                )
                path.move(to: CGPoint(x: start.point.x + perpendicular.x, y: start.point.y + perpendicular.y))
                path.addLine(to: CGPoint(x: end.point.x + perpendicular.x, y: end.point.y + perpendicular.y))
                path.addLine(to: CGPoint(x: end.point.x - perpendicular.x, y: end.point.y - perpendicular.y))
                path.addLine(to: CGPoint(x: start.point.x - perpendicular.x, y: start.point.y - perpendicular.y))
                path.closeSubpath()
            }
        }
        return path
    }
}

/// 論理名（日本語）: 保存済み手書き描画ビュー
/// 概要: `.ogp` の frame-local point と筆圧を描画し、複数選択drag中は対象inkへ共通の一時移動量を適用します。
private struct CanvasInkRenderingView: View {
    var annotations: [OpenGraphiteCanvasAnnotation]
    var canvasOrigin: CGPoint
    var previewAnnotationIDs: Set<String>
    var previewTranslation: CGSize

    var body: some View {
        Canvas { context, _ in
            for annotation in annotations where annotation.kind == .ink {
                for stroke in annotation.strokes {
                    draw(stroke: stroke, annotation: annotation, in: &context)
                }
            }
        }
    }

    /// 論理名（日本語）: 保存ストローク描画関数
    /// 処理概要: 連続点を筆圧線幅の丸端 segment として描きます。
    ///
    /// - Parameters:
    ///   - stroke: 描画する保存ストローク。
    ///   - annotation: world frame を持つ注釈。
    ///   - context: SwiftUI Canvas 描画 context。
    private func draw(
        stroke: OpenGraphiteInkStroke,
        annotation: OpenGraphiteCanvasAnnotation,
        in context: inout GraphicsContext
    ) {
        guard let first = stroke.points.first else { return }
        let color = CanvasAnnotationColor.color(stroke.color, fallback: .systemRed)
        let translation = previewAnnotationIDs.contains(annotation.internalID)
            ? previewTranslation
            : .zero
        let origin = CGPoint(
            x: CGFloat(annotation.frame.x) - canvasOrigin.x + translation.width,
            y: CGFloat(annotation.frame.y) - canvasOrigin.y + translation.height
        )
        if stroke.points.count == 1 {
            let width = CanvasInkLineWidthResolver.width(baseWidth: stroke.lineWidth, pressure: first.pressure)
            let rect = CGRect(
                x: origin.x + CGFloat(first.x) - width / 2,
                y: origin.y + CGFloat(first.y) - width / 2,
                width: width,
                height: width
            )
            context.fill(Path(ellipseIn: rect), with: .color(color))
            return
        }

        for index in 1..<stroke.points.count {
            let previous = stroke.points[index - 1]
            let current = stroke.points[index]
            var path = Path()
            path.move(to: CGPoint(x: origin.x + CGFloat(previous.x), y: origin.y + CGFloat(previous.y)))
            path.addLine(to: CGPoint(x: origin.x + CGFloat(current.x), y: origin.y + CGFloat(current.y)))
            let pressure = (previous.pressure + current.pressure) / 2
            let width = CanvasInkLineWidthResolver.width(baseWidth: stroke.lineWidth, pressure: pressure)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

/// 論理名（日本語）: スタイラス入力AppKitブリッジ
/// 概要: Sidecar の tablet event と mouse fallback を受け、penは保存用stroke、eraserは逐次previewとpen-up確定を通知します。
private struct CanvasStylusInputView: NSViewRepresentable {
    var canvasOrigin: CGPoint
    var color: String
    var lineWidth: Double
    var eraserLineWidth: Double
    var eraserMinimumSampleDistance: CGFloat
    var forcedInputDevice: OpenGraphiteInkInputDevice?
    var onPreview: ((OpenGraphiteCanvasAnnotationFrame, OpenGraphiteInkStroke) -> Void)?
    var onEraserCommit: (() -> Void)?
    var onCommit: (OpenGraphiteCanvasAnnotationFrame, OpenGraphiteInkStroke) -> Void

    /// 論理名（日本語）: スタイラス入力ビュー生成関数
    /// 処理概要: 透明な AppKit view を作り、入力確定 callback と Canvas world 原点を設定します。
    ///
    /// - Parameter context: SwiftUI representable context。
    /// - Returns: tablet event を受ける AppKit view。
    func makeNSView(context: Context) -> CanvasStylusCaptureNSView {
        let view = CanvasStylusCaptureNSView()
        configure(view)
        return view
    }

    /// 論理名（日本語）: スタイラス入力ビュー更新関数
    /// 処理概要: Canvas bounds 変更後の world 原点と描画設定を AppKit view へ反映します。
    ///
    /// - Parameters:
    ///   - nsView: 更新対象 view。
    ///   - context: SwiftUI representable context。
    func updateNSView(_ nsView: CanvasStylusCaptureNSView, context: Context) {
        configure(nsView)
    }

    /// 論理名（日本語）: スタイラス入力ビュー設定関数
    /// 処理概要: representable の最新値を AppKit view へまとめて渡します。
    ///
    /// - Parameter view: 設定対象 view。
    private func configure(_ view: CanvasStylusCaptureNSView) {
        view.canvasOrigin = canvasOrigin
        view.strokeColor = color
        view.baseLineWidth = lineWidth
        view.eraserLineWidth = eraserLineWidth
        view.eraserMinimumSampleDistance = eraserMinimumSampleDistance
        view.forcedInputDevice = forcedInputDevice
        view.onPreview = onPreview
        view.onEraserCommit = onEraserCommit
        view.onCommit = onCommit
    }
}

/// 論理名（日本語）: スタイラス入力Captureビュー
/// 概要: AppKit mouse / tabletPoint / tabletProximity を収集し、live stroke を描画して pen-up で確定します。
private final class CanvasStylusCaptureNSView: NSView {
    var canvasOrigin: CGPoint = .zero
    var strokeColor = "#FF4D67"
    var baseLineWidth = 3.5
    var eraserLineWidth = CanvasEraserMetrics.baseLineWidth(zoom: 1)
    var eraserMinimumSampleDistance = CanvasEraserMetrics.minimumWorldSampleDistance(zoom: 1)
    var forcedInputDevice: OpenGraphiteInkInputDevice?
    var onPreview: ((OpenGraphiteCanvasAnnotationFrame, OpenGraphiteInkStroke) -> Void)?
    var onEraserCommit: (() -> Void)?
    var onCommit: ((OpenGraphiteCanvasAnnotationFrame, OpenGraphiteInkStroke) -> Void)?

    private var samples: [CanvasInkDraftSample] = []
    private var pendingEraserSamples: [CanvasInkDraftSample] = []
    private var lastEraserPreviewTimestamp: TimeInterval?
    private var proximityDevices: [Int: OpenGraphiteInkInputDevice] = [:]
    private var activeTabletDeviceID: Int?
    private var isDrawing = false
    private var isEraserMode = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// 論理名（日本語）: スタイラスCaptureビュー初期化関数
    /// 処理概要: 透明 layer-backed view として live stroke 再描画を有効にします。
    ///
    /// - Parameter frameRect: 初期 frame。
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// 論理名（日本語）: NSCoder初期化関数
    /// 処理概要: storyboard 経路を使わないため `nil` を返します。
    ///
    /// - Parameter coder: NSCoder。
    required init?(coder: NSCoder) {
        nil
    }

    /// 論理名（日本語）: Mouse down処理関数
    /// 処理概要: 通常 mouse または Sidecar Pencil の最初の sample を記録します。
    ///
    /// - Parameter event: mouse down event。
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        samples = []
        pendingEraserSamples = []
        lastEraserPreviewTimestamp = nil
        isDrawing = true
        activeTabletDeviceID = hasTabletPointData(event) ? event.deviceID : nil
        append(event, force: true)
    }

    /// 論理名（日本語）: Mouse drag処理関数
    /// 処理概要: drag event が tablet subtype の場合は筆圧と傾きも記録します。
    ///
    /// - Parameter event: mouse drag event。
    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        append(event)
    }

    /// 論理名（日本語）: Mouse up処理関数
    /// 処理概要: 最終sampleを保持し、penはframe-local stroke、eraserは累積previewの確定を一度だけ通知します。
    ///
    /// - Parameter event: mouse up event。
    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        append(event, force: true)
        flushEraserPreview()
        isDrawing = false
        if samples.first?.inputDevice == .eraser {
            onEraserCommit?()
        } else if let result = normalizedDraftStroke() {
            onCommit?(result.frame, result.stroke)
        }
        samples = []
        pendingEraserSamples = []
        lastEraserPreviewTimestamp = nil
        activeTabletDeviceID = nil
        needsDisplay = true
    }

    /// 論理名（日本語）: Tablet point処理関数
    /// 処理概要: mouse-down から最初の drag まで届く Sidecar / tablet sample を追加します。
    ///
    /// - Parameter event: tablet point event。
    override func tabletPoint(with event: NSEvent) {
        guard isDrawing else { return }
        append(event)
    }

    /// 論理名（日本語）: Tablet proximity処理関数
    /// 処理概要: API契約上安全な proximity event から pen / eraser を追跡します。
    ///
    /// - Parameter event: tablet proximity event。
    override func tabletProximity(with event: NSEvent) {
        let deviceID = event.deviceID
        guard event.isEnteringProximity else {
            proximityDevices.removeValue(forKey: deviceID)
            return
        }
        switch event.pointingDeviceType {
        case .pen:
            proximityDevices[deviceID] = .pen
        case .eraser:
            proximityDevices[deviceID] = .eraser
        case .cursor:
            proximityDevices[deviceID] = .mouse
        case .unknown:
            proximityDevices[deviceID] = .unknown
        @unknown default:
            proximityDevices[deviceID] = .unknown
        }
    }

    /// 論理名（日本語）: Apple Pencil mode変更処理関数
    /// 処理概要: Sidecar から届く Apple Pencil double-tap で pen と部分消去 eraser を切り替えます。
    ///
    /// - Parameter event: changeMode event。
    override func changeMode(with event: NSEvent) {
        isEraserMode.toggle()
    }

    /// 論理名（日本語）: Live stroke描画関数
    /// 処理概要: 未確定 samples を筆圧対応の丸端 segment として描画します。
    ///
    /// - Parameter dirtyRect: 再描画領域。
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let first = samples.first else { return }
        let isEraser = first.inputDevice == .eraser
        let effectiveBaseLineWidth = isEraser ? eraserLineWidth : baseLineWidth
        let color = isEraser
            ? NSColor.systemGray.withAlphaComponent(0.45)
            : CanvasAnnotationColor.nsColor(strokeColor, fallback: .systemRed)
        color.setFill()
        color.setStroke()

        if samples.count == 1 {
            let width = CanvasInkLineWidthResolver.width(
                baseWidth: effectiveBaseLineWidth,
                pressure: first.pressure
            )
            NSBezierPath(ovalIn: NSRect(
                x: first.point.x - canvasOrigin.x - width / 2,
                y: first.point.y - canvasOrigin.y - width / 2,
                width: width,
                height: width
            )).fill()
            return
        }

        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(
                x: previous.point.x - canvasOrigin.x,
                y: previous.point.y - canvasOrigin.y
            ))
            path.line(to: CGPoint(
                x: current.point.x - canvasOrigin.x,
                y: current.point.y - canvasOrigin.y
            ))
            path.lineWidth = CanvasInkLineWidthResolver.width(
                baseWidth: effectiveBaseLineWidth,
                pressure: (previous.pressure + current.pressure) / 2
            )
            path.stroke()
        }
    }

    /// 論理名（日本語）: 入力Event追加関数
    /// 処理概要: view local 座標を canonical world へ変換し、tablet event の場合だけ pressure / tilt を読みます。
    ///
    /// - Parameters:
    ///   - event: mouse または tablet point event。
    ///   - force: pen-down / pen-up の端点を通常の時間・距離間引きにかかわらず保持するか。
    private func append(_ event: NSEvent, force: Bool = false) {
        let tabletPointData = hasTabletPointData(event)
        let deviceID = tabletPointData ? event.deviceID : 0
        if tabletPointData {
            if let activeTabletDeviceID {
                guard activeTabletDeviceID == deviceID else { return }
            } else {
                guard samples.isEmpty else { return }
                activeTabletDeviceID = deviceID
            }
        } else if activeTabletDeviceID != nil {
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        let worldPoint = CanvasAnnotationCoordinateResolver.worldPoint(
            localPoint: localPoint,
            canvasOrigin: canvasOrigin
        )
        let tilt = tabletPointData ? event.tilt : .zero
        let device = CanvasStylusEventResolver.inputDevice(
            hasTabletPointData: tabletPointData,
            deviceID: deviceID,
            proximityDevices: proximityDevices,
            isEraserMode: isEraserMode,
            forcedInputDevice: forcedInputDevice
        )
        let pressure = device == .eraser
            ? CanvasEraserMetrics.pressure
            : tabletPointData ? min(max(Double(event.pressure), 0), 1) : 1
        let sample = CanvasInkDraftSample(
            point: worldPoint,
            pressure: pressure,
            tiltX: Double(tilt.x),
            tiltY: Double(tilt.y),
            inputDevice: device,
            deviceID: deviceID,
            timestamp: event.timestamp
        )
        if let last = samples.last, last.deviceID == sample.deviceID {
            let distance = hypot(last.point.x - sample.point.x, last.point.y - sample.point.y)
            if device == .eraser {
                guard distance >= 0.000_1 else { return }
                if !force, distance < eraserMinimumSampleDistance {
                    return
                }
            } else if abs(last.timestamp - sample.timestamp) < 0.000_1, distance < 0.05 {
                return
            }
        }
        samples.append(sample)
        if device == .eraser, samples.count > CanvasEraserMetrics.maximumLiveSampleCount {
            samples.removeFirst(CanvasEraserMetrics.maximumLiveSampleCount / 2)
        }
        if device == .eraser {
            pendingEraserSamples.append(sample)
            let shouldFlush: Bool
            if let lastEraserPreviewTimestamp {
                let elapsed = sample.timestamp - lastEraserPreviewTimestamp
                shouldFlush = !elapsed.isFinite
                    || elapsed < 0
                    || elapsed >= CanvasEraserMetrics.minimumSampleInterval
            } else {
                shouldFlush = true
            }
            if shouldFlush
                || pendingEraserSamples.count >= CanvasEraserMetrics.maximumPendingSampleCount {
                flushEraserPreview()
            }
        }
        needsDisplay = true
    }

    /// 論理名（日本語）: 消しゴムPreview確定関数
    /// 処理概要: 60Hz区間内に保持した空間間引き済みpoint列を1本の連続軌跡として通知し、終点を次区間のanchorへ残します。
    private func flushEraserPreview() {
        guard let last = pendingEraserSamples.last,
              pendingEraserSamples.count > 1 || lastEraserPreviewTimestamp == nil
        else {
            return
        }
        if let result = normalizedDraftStroke(targetSamples: pendingEraserSamples) {
            onPreview?(result.frame, result.stroke)
        }
        lastEraserPreviewTimestamp = last.timestamp
        pendingEraserSamples = [last]
    }

    /// 論理名（日本語）: 未確定ストローク正規化関数
    /// 処理概要: 現在の入力種別に応じた pen または画面固定径 eraser の基準線幅で、収集中サンプルを world frameへ正規化します。
    ///
    /// - Parameter targetSamples: preview区間を明示する場合のsample列。`nil`なら現在のpen全sampleを使います。
    /// - Returns: 有効なサンプルがある場合はframeとstroke、それ以外は`nil`。
    private func normalizedDraftStroke(
        targetSamples: [CanvasInkDraftSample]? = nil
    ) -> (
        frame: OpenGraphiteCanvasAnnotationFrame,
        stroke: OpenGraphiteInkStroke
    )? {
        let normalizedSamples = targetSamples ?? samples
        let lineWidth = normalizedSamples.first?.inputDevice == .eraser
            ? eraserLineWidth
            : baseLineWidth
        return CanvasInkStrokeNormalizer.normalizedStroke(
            samples: normalizedSamples,
            color: strokeColor,
            lineWidth: lineWidth
        )
    }

    /// 論理名（日本語）: Tablet point data判定関数
    /// 処理概要: native tablet event と mouse event の tablet subtype を同じ入力系列として判定します。
    ///
    /// - Parameter event: 判定対象 AppKit event。
    /// - Returns: pressure / tilt / device ID を tablet sample として読める場合は `true`。
    private func hasTabletPointData(_ event: NSEvent) -> Bool {
        event.type == .tabletPoint || event.subtype == .tabletPoint
    }
}

/// 論理名（日本語）: キャンバス注釈色変換器
/// 概要: `.ogp` に保存された CSS hex 色を AppKit / SwiftUI 描画色へ変換します。
private enum CanvasAnnotationColor {
    /// 論理名（日本語）: SwiftUI色変換関数
    /// 処理概要: CSS hex 色を SwiftUI Color へ変換します。
    ///
    /// - Parameters:
    ///   - value: `#RRGGBB` または `#RRGGBBAA`。
    ///   - fallback: 変換失敗時の AppKit 色。
    /// - Returns: SwiftUI 描画色。
    static func color(_ value: String, fallback: NSColor) -> Color {
        Color(nsColor: nsColor(value, fallback: fallback))
    }

    /// 論理名（日本語）: AppKit色変換関数
    /// 処理概要: CSS hex 色を sRGB NSColor へ変換します。
    ///
    /// - Parameters:
    ///   - value: `#RRGGBB` または `#RRGGBBAA`。
    ///   - fallback: 変換失敗時の色。
    /// - Returns: AppKit 描画色。
    static func nsColor(_ value: String, fallback: NSColor) -> NSColor {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        guard hex.count == 6 || hex.count == 8,
              let raw = UInt64(hex, radix: 16)
        else {
            return fallback
        }
        let hasAlpha = hex.count == 8
        let red = hasAlpha ? (raw >> 24) & 0xff : (raw >> 16) & 0xff
        let green = hasAlpha ? (raw >> 16) & 0xff : (raw >> 8) & 0xff
        let blue = hasAlpha ? (raw >> 8) & 0xff : raw & 0xff
        let alpha = hasAlpha ? raw & 0xff : 0xff
        return NSColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}
