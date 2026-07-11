import Foundation

/// 論理名（日本語）: 手書き部分消去結果
/// 概要: 消しゴム軌跡を適用したあと、保存変更が不要か、同じ注釈を更新するか、注釈全体を削除するかを表します。
///
/// 定義内容:
/// - `unchanged`: 表示中の手書きと消しゴムが交差せず、元の注釈をそのまま保持する。
/// - `updated`: 消去部分を除いた stroke fragment と tight frame を持つ注釈へ置き換える。
/// - `deleted`: 表示可能な stroke fragment が残らず、注釈を削除する。
enum CanvasInkPartialEraseResult: Equatable {
    case unchanged
    case updated(OpenGraphiteCanvasAnnotation)
    case deleted
}

/// 論理名（日本語）: 手書き消去保存Payload
/// 概要: 1回のgestureで部分更新するink注釈と、完全消去する元注釈IDをまとめます。
///
/// プロパティ:
/// - `updatedAnnotations`: 同じ内部IDで置換する分割後ink注釈。
/// - `deletedIDs`: gesture開始時に存在し、previewで完全に消えたink注釈ID。
struct CanvasInkErasureCommitPayload: Equatable {
    var updatedAnnotations: [OpenGraphiteCanvasAnnotation]
    var deletedIDs: [String]
}

/// 論理名（日本語）: 手書き消去保存Payload解決器
/// 概要: gesture開始snapshotと現在値が一致するときだけpreview差分を保存対象へ変換し、外部更新やCanvas切替への誤保存を防ぎます。
enum CanvasInkErasureCommitResolver {
    /// 論理名（日本語）: 手書き消去保存Payload解決関数
    /// 処理概要: currentがgesture開始snapshotから変わっていないことを確認し、元ink ID集合だけから更新・削除payloadを生成します。
    ///
    /// - Parameters:
    ///   - originalAnnotations: gesture開始時の注釈snapshot。
    ///   - previewAnnotations: 直近segmentを累積した部分消去preview。
    ///   - currentAnnotations: pen-up時点で保存先に存在する注釈列。
    /// - Returns: 安全に保存できる差分。外部更新などを検出した場合は`nil`。
    static func resolve(
        originalAnnotations: [OpenGraphiteCanvasAnnotation],
        previewAnnotations: [OpenGraphiteCanvasAnnotation],
        currentAnnotations: [OpenGraphiteCanvasAnnotation]
    ) -> CanvasInkErasureCommitPayload? {
        guard currentAnnotations == originalAnnotations else { return nil }

        let originalInk = originalAnnotations.filter { $0.kind == .ink }
        let originalInkByID = Dictionary(
            uniqueKeysWithValues: originalInk.map { ($0.internalID, $0) }
        )
        let previewInkIDs = Set(
            previewAnnotations
                .filter { $0.kind == .ink }
                .map(\.internalID)
        )
        let updatedAnnotations = previewAnnotations.filter { annotation in
            guard annotation.kind == .ink,
                  let original = originalInkByID[annotation.internalID]
            else {
                return false
            }
            return annotation != original
        }
        let deletedIDs = originalInk
            .map(\.internalID)
            .filter { !previewInkIDs.contains($0) }
        return CanvasInkErasureCommitPayload(
            updatedAnnotations: updatedAnnotations,
            deletedIDs: deletedIDs
        )
    }
}

/// 論理名（日本語）: キャンバス手書き部分消去器
/// 概要: 保存済み ink の実描画中心線から消しゴムの swept capsule を差し引き、残線を複数 stroke へ分割します。
enum CanvasInkPartialEraser {
    /// 論理名（日本語）: 手書き部分消去関数
    /// 処理概要: ink と eraser の線分ごとの実描画半径を使って交差区間を求め、残る区間を frame-local stroke へ再構築します。
    ///
    /// - Parameters:
    ///   - annotation: 部分消去する保存済みキャンバス注釈。
    ///   - eraserFrame: 消しゴム入力を包含する canonical world frame。
    ///   - eraserStroke: `eraserFrame` を原点とする消しゴムの point 列と基準線幅。
    /// - Returns: 非交差、部分更新、全消去のいずれかを表す結果。
    static func erase(
        annotation: OpenGraphiteCanvasAnnotation,
        eraserFrame: OpenGraphiteCanvasAnnotationFrame,
        eraserStroke: OpenGraphiteInkStroke
    ) -> CanvasInkPartialEraseResult {
        guard annotation.kind == .ink else { return .unchanged }
        let eraserCapsules = capsules(frame: eraserFrame, stroke: eraserStroke)
        guard !eraserCapsules.isEmpty,
              let eraserInteractionFrame = interactionFrame(for: eraserCapsules),
              framesIntersect(annotation.frame, eraserInteractionFrame)
        else {
            return .unchanged
        }

        var didErase = false
        var retainedStrokes: [WorldStroke] = []
        for stroke in annotation.strokes {
            let worldStroke = worldStroke(frame: annotation.frame, stroke: stroke)
            let erased = erase(stroke: worldStroke, with: eraserCapsules)
            didErase = didErase || erased.didErase
            retainedStrokes.append(contentsOf: erased.fragments)
        }

        guard didErase else { return .unchanged }
        let canonicalStrokes = retainedStrokes.compactMap(canonicalized)
        guard let frame = renderedFrame(for: canonicalStrokes) else { return .deleted }

        var updated = annotation
        updated.frame = frame
        updated.strokes = canonicalStrokes.map { stroke in
            return OpenGraphiteInkStroke(
                points: stroke.points.map { point in
                    OpenGraphiteInkPoint(
                        x: rounded(point.x - frame.x),
                        y: rounded(point.y - frame.y),
                        pressure: point.pressure,
                        tiltX: point.tiltX,
                        tiltY: point.tiltY
                    )
                },
                color: stroke.color,
                lineWidth: stroke.lineWidth,
                inputDevice: stroke.inputDevice
            )
        }
        return updated.strokes.isEmpty ? .deleted : .updated(updated)
    }

    /// 論理名（日本語）: World手書き点
    /// 概要: canonical world 座標と、切断境界で補間・描画幅補正する筆圧および傾きをまとめて保持します。
    private struct WorldPoint: Equatable {
        var x: Double
        var y: Double
        var pressure: Double
        var tiltX: Double
        var tiltY: Double

        /// 論理名（日本語）: 線形補間点生成関数
        /// 処理概要: 線分上の割合に応じて座標、筆圧、傾きを同じ比率で補間します。
        ///
        /// - Parameters:
        ///   - other: 線分終点。
        ///   - parameter: 始点を0、終点を1とする線分上の割合。
        /// - Returns: 補間済みの world point。
        func interpolated(to other: WorldPoint, parameter: Double) -> WorldPoint {
            let t = min(max(parameter, 0), 1)
            return WorldPoint(
                x: x + (other.x - x) * t,
                y: y + (other.y - y) * t,
                pressure: pressure + (other.pressure - pressure) * t,
                tiltX: tiltX + (other.tiltX - tiltX) * t,
                tiltY: tiltY + (other.tiltY - tiltY) * t
            )
        }
    }

    /// 論理名（日本語）: World手書きストローク
    /// 概要: frame から独立した world point 列と、分割後も維持する stroke payload を保持します。
    private struct WorldStroke {
        var points: [WorldPoint]
        var color: String
        var lineWidth: Double
        var inputDevice: OpenGraphiteInkInputDevice
    }

    /// 論理名（日本語）: 消しゴムカプセル
    /// 概要: 実描画と同じ平均筆圧線幅を半径にした、1本の消しゴム線分または単一点を表します。
    private struct Capsule {
        var start: Point
        var end: Point
        var radius: Double
    }

    /// 論理名（日本語）: 幾何計算点
    /// 概要: bounded な world 座標で距離・内積・外積を計算するための二次元点です。
    private struct Point {
        var x: Double
        var y: Double
    }

    /// 論理名（日本語）: 線分パラメータ区間
    /// 概要: 0から1の線分パラメータ上で消去対象となる閉区間を表します。
    private struct Interval {
        var lower: Double
        var upper: Double
    }

    private static let geometryEpsilon = 0.000_000_001
    private static let parameterEpsilon = 0.000_000_1

    /// 論理名（日本語）: Worldストローク変換関数
    /// 処理概要: 保存済み frame-local point を canonical world point へ戻し、stroke payload と一緒に保持します。
    ///
    /// - Parameters:
    ///   - frame: 注釈の world frame。
    ///   - stroke: frame-local の保存済み stroke。
    /// - Returns: world 座標へ変換した stroke。
    private static func worldStroke(
        frame: OpenGraphiteCanvasAnnotationFrame,
        stroke: OpenGraphiteInkStroke
    ) -> WorldStroke {
        WorldStroke(
            points: stroke.points.map { point in
                WorldPoint(
                    x: frame.x + point.x,
                    y: frame.y + point.y,
                    pressure: point.pressure,
                    tiltX: point.tiltX,
                    tiltY: point.tiltY
                )
            },
            color: stroke.color,
            lineWidth: stroke.lineWidth,
            inputDevice: stroke.inputDevice
        )
    }

    /// 論理名（日本語）: 消しゴムカプセル列生成関数
    /// 処理概要: 単一点を円、複数点を renderer と同じ平均 endpoint pressure の capsule 列へ変換します。
    ///
    /// - Parameters:
    ///   - frame: 消しゴムの world frame。
    ///   - stroke: frame-local の消しゴム stroke。
    /// - Returns: 入力順の swept capsule 列。point が空なら空配列。
    private static func capsules(
        frame: OpenGraphiteCanvasAnnotationFrame,
        stroke: OpenGraphiteInkStroke
    ) -> [Capsule] {
        let points = stroke.points.map { point in
            (
                point: Point(x: frame.x + point.x, y: frame.y + point.y),
                pressure: point.pressure
            )
        }
        guard let first = points.first else { return [] }
        guard points.count > 1 else {
            return [Capsule(
                start: first.point,
                end: first.point,
                radius: renderedRadius(baseWidth: stroke.lineWidth, pressure: first.pressure)
            )]
        }
        return (1..<points.count).map { index in
            let start = points[index - 1]
            let end = points[index]
            return Capsule(
                start: start.point,
                end: end.point,
                radius: renderedRadius(
                    baseWidth: stroke.lineWidth,
                    pressure: (start.pressure + end.pressure) / 2
                )
            )
        }
    }

    /// 論理名（日本語）: ストローク部分消去関数
    /// 処理概要: 単一点は円同士、複数点は各実描画 segment と全 eraser capsule の交差区間を使って fragment へ分割します。
    ///
    /// - Parameters:
    ///   - stroke: world point 列と保存 payload。
    ///   - eraserCapsules: 1回の消しゴム gesture を構成する全 capsule。
    /// - Returns: 元 stroke を置き換える fragment と、実際に消去が発生したか。
    private static func erase(
        stroke: WorldStroke,
        with eraserCapsules: [Capsule]
    ) -> (fragments: [WorldStroke], didErase: Bool) {
        guard let first = stroke.points.first else { return ([stroke], false) }
        guard stroke.points.count > 1 else {
            let inkRadius = renderedRadius(baseWidth: stroke.lineWidth, pressure: first.pressure)
            let point = Point(x: first.x, y: first.y)
            let isErased = eraserCapsules.contains { capsule in
                pointDistance(point, to: capsule.start, capsule.end) <= inkRadius + capsule.radius
            }
            return isErased ? ([], true) : ([stroke], false)
        }

        var fragments: [[WorldPoint]] = []
        var openFragment: [WorldPoint] = []
        var previousSegmentReachedEnd = false
        var didErase = false

        for index in 1..<stroke.points.count {
            let start = stroke.points[index - 1]
            let end = stroke.points[index]
            let inkRadius = renderedRadius(
                baseWidth: stroke.lineWidth,
                pressure: (start.pressure + end.pressure) / 2
            )
            let erasedIntervals = erasedIntervals(
                from: Point(x: start.x, y: start.y),
                to: Point(x: end.x, y: end.y),
                inkRadius: inkRadius,
                eraserCapsules: eraserCapsules
            )
            let retainedIntervals = complement(of: erasedIntervals)
            didErase = didErase || !erasedIntervals.isEmpty

            if retainedIntervals.first?.lower ?? 1 > parameterEpsilon {
                finish(&openFragment, into: &fragments)
                previousSegmentReachedEnd = false
            }
            if retainedIntervals.isEmpty {
                finish(&openFragment, into: &fragments)
                previousSegmentReachedEnd = false
                continue
            }

            for (retainedIndex, interval) in retainedIntervals.enumerated() {
                var fragmentStart = start.interpolated(to: end, parameter: interval.lower)
                var fragmentEnd = start.interpolated(to: end, parameter: interval.upper)
                preserveRenderedPressure(
                    start: start,
                    end: end,
                    interval: interval,
                    fragmentStart: &fragmentStart,
                    fragmentEnd: &fragmentEnd
                )
                let joinsPrevious = retainedIndex == 0
                    && interval.lower <= parameterEpsilon
                    && previousSegmentReachedEnd
                    && !openFragment.isEmpty

                if !joinsPrevious {
                    finish(&openFragment, into: &fragments)
                    openFragment = [fragmentStart]
                } else {
                    appendIfDistinct(fragmentStart, to: &openFragment)
                }
                appendIfDistinct(fragmentEnd, to: &openFragment)

                let reachesEnd = interval.upper >= 1 - parameterEpsilon
                let hasLaterInterval = retainedIndex < retainedIntervals.count - 1
                if hasLaterInterval || !reachesEnd {
                    finish(&openFragment, into: &fragments)
                    previousSegmentReachedEnd = false
                } else {
                    previousSegmentReachedEnd = true
                }
            }
        }
        finish(&openFragment, into: &fragments)

        guard didErase else { return ([stroke], false) }
        let worldFragments = fragments.map { points in
            WorldStroke(
                points: points,
                color: stroke.color,
                lineWidth: stroke.lineWidth,
                inputDevice: stroke.inputDevice
            )
        }
        return (worldFragments, true)
    }

    /// 論理名（日本語）: 分割境界筆圧補正関数
    /// 処理概要: rendererが各segmentの両端平均筆圧を使うため、切断後も消去前segmentと同じ描画幅になるよう生成境界の筆圧だけを補正します。
    ///
    /// - Parameters:
    ///   - start: 消去前segmentの始点。
    ///   - end: 消去前segmentの終点。
    ///   - interval: segment内に残す区間。
    ///   - fragmentStart: 補正する残存区間始点。
    ///   - fragmentEnd: 補正する残存区間終点。
    private static func preserveRenderedPressure(
        start: WorldPoint,
        end: WorldPoint,
        interval: Interval,
        fragmentStart: inout WorldPoint,
        fragmentEnd: inout WorldPoint
    ) {
        let trimsStart = interval.lower > parameterEpsilon
        let trimsEnd = interval.upper < 1 - parameterEpsilon
        switch (trimsStart, trimsEnd) {
        case (true, true):
            let average = (start.pressure + end.pressure) / 2
            fragmentStart.pressure = average
            fragmentEnd.pressure = average
        case (true, false):
            fragmentStart.pressure = start.pressure
        case (false, true):
            fragmentEnd.pressure = end.pressure
        case (false, false):
            break
        }
    }

    /// 論理名（日本語）: 消去区間解決関数
    /// 処理概要: 線分と capsule の解析的な円・有限帯交差区間を統合し、疎な長線を再サンプリングせず切断境界を求めます。
    ///
    /// - Parameters:
    ///   - start: ink segment の world 始点。
    ///   - end: ink segment の world 終点。
    ///   - inkRadius: renderer がこの segment に使う平均筆圧由来の半径。
    ///   - eraserCapsules: gesture を構成する消しゴム capsule 列。
    /// - Returns: 0から1へ正規化・統合した消去区間。
    private static func erasedIntervals(
        from start: Point,
        to end: Point,
        inkRadius: Double,
        eraserCapsules: [Capsule]
    ) -> [Interval] {
        var candidates: [Interval] = []
        for capsule in eraserCapsules {
            candidates.append(contentsOf: capsuleIntervals(
                from: start,
                to: end,
                capsule: capsule,
                radius: inkRadius + capsule.radius
            ))
        }
        return merge(candidates)
    }

    /// 論理名（日本語）: Capsule交差区間生成関数
    /// 処理概要: capsule を両端円と有限線分の帯へ分解し、ink centerline が指定半径内に入る全パラメータ区間を解析的に求めます。
    ///
    /// - Parameters:
    ///   - start: ink segment 始点。
    ///   - end: ink segment 終点。
    ///   - capsule: 消しゴム中心線と実描画半径。
    ///   - radius: ink と eraser の描画半径の合計。
    /// - Returns: capsule 内に入る未統合区間。
    private static func capsuleIntervals(
        from start: Point,
        to end: Point,
        capsule: Capsule,
        radius: Double
    ) -> [Interval] {
        let eraserDelta = Point(
            x: capsule.end.x - capsule.start.x,
            y: capsule.end.y - capsule.start.y
        )
        let eraserLengthSquared = dot(eraserDelta, eraserDelta)
        if eraserLengthSquared <= geometryEpsilon {
            return circleInterval(from: start, to: end, center: capsule.start, radius: radius).map { [$0] } ?? []
        }

        var intervals: [Interval] = []
        if let startCircle = circleInterval(from: start, to: end, center: capsule.start, radius: radius) {
            intervals.append(startCircle)
        }
        if let endCircle = circleInterval(from: start, to: end, center: capsule.end, radius: radius) {
            intervals.append(endCircle)
        }
        if let strip = stripInterval(
            from: start,
            to: end,
            stripStart: capsule.start,
            stripDelta: eraserDelta,
            radius: radius
        ) {
            intervals.append(strip)
        }
        return intervals
    }

    /// 論理名（日本語）: 円交差区間関数
    /// 処理概要: 線分パラメータの二次不等式を解き、指定円内にある区間を0から1へclampします。
    ///
    /// - Parameters:
    ///   - start: 線分始点。
    ///   - end: 線分終点。
    ///   - center: 円中心。
    ///   - radius: 円半径。
    /// - Returns: 円内区間。非交差なら `nil`。
    private static func circleInterval(
        from start: Point,
        to end: Point,
        center: Point,
        radius: Double
    ) -> Interval? {
        let delta = Point(x: end.x - start.x, y: end.y - start.y)
        let offset = Point(x: start.x - center.x, y: start.y - center.y)
        let quadratic = dot(delta, delta)
        if quadratic <= geometryEpsilon {
            return dot(offset, offset) <= radius * radius ? Interval(lower: 0, upper: 1) : nil
        }
        let linear = 2 * dot(offset, delta)
        let constant = dot(offset, offset) - radius * radius
        let discriminant = linear * linear - 4 * quadratic * constant
        guard discriminant >= 0 else { return nil }
        let root = sqrt(max(discriminant, 0))
        let first = (-linear - root) / (2 * quadratic)
        let second = (-linear + root) / (2 * quadratic)
        let lower = max(min(first, second), 0)
        let upper = min(max(first, second), 1)
        return lower <= upper ? Interval(lower: lower, upper: upper) : nil
    }

    /// 論理名（日本語）: Capsule帯交差区間関数
    /// 処理概要: eraser 線分への射影範囲と垂直距離範囲を線形不等式としてclipし、有限長の帯に入る区間を求めます。
    ///
    /// - Parameters:
    ///   - start: ink segment 始点。
    ///   - end: ink segment 終点。
    ///   - stripStart: eraser segment 始点。
    ///   - stripDelta: eraser segment 方向ベクトル。
    ///   - radius: ink と eraser の描画半径の合計。
    /// - Returns: 有限帯内の区間。非交差なら `nil`。
    private static func stripInterval(
        from start: Point,
        to end: Point,
        stripStart: Point,
        stripDelta: Point,
        radius: Double
    ) -> Interval? {
        let inkDelta = Point(x: end.x - start.x, y: end.y - start.y)
        let offset = Point(x: start.x - stripStart.x, y: start.y - stripStart.y)
        let lengthSquared = dot(stripDelta, stripDelta)
        var interval = Interval(lower: 0, upper: 1)

        guard clipLinearBand(
            base: dot(offset, stripDelta),
            slope: dot(inkDelta, stripDelta),
            lower: 0,
            upper: lengthSquared,
            interval: &interval
        ) else {
            return nil
        }
        let perpendicularLimit = radius * sqrt(lengthSquared)
        guard clipLinearBand(
            base: cross(offset, stripDelta),
            slope: cross(inkDelta, stripDelta),
            lower: -perpendicularLimit,
            upper: perpendicularLimit,
            interval: &interval
        ) else {
            return nil
        }
        return interval
    }

    /// 論理名（日本語）: 線形帯域クリップ関数
    /// 処理概要: `lower <= base + slope * t <= upper` を満たす範囲で既存区間を狭めます。
    ///
    /// - Parameters:
    ///   - base: t が0のときの値。
    ///   - slope: t に対する変化量。
    ///   - lower: 許容下限。
    ///   - upper: 許容上限。
    ///   - interval: 入出力する現在のパラメータ区間。
    /// - Returns: 有効な区間が残る場合は `true`。
    private static func clipLinearBand(
        base: Double,
        slope: Double,
        lower: Double,
        upper: Double,
        interval: inout Interval
    ) -> Bool {
        guard abs(slope) > geometryEpsilon else {
            return base >= lower && base <= upper
        }
        let first = (lower - base) / slope
        let second = (upper - base) / slope
        interval.lower = max(interval.lower, min(first, second))
        interval.upper = min(interval.upper, max(first, second))
        return interval.lower <= interval.upper
    }

    /// 論理名（日本語）: 区間統合関数
    /// 処理概要: capsule ごとの交差区間を並べ替え、重複・隣接部分を1つの消去区間へまとめます。
    ///
    /// - Parameter intervals: 未統合の交差区間。
    /// - Returns: 0から1内へclampした重複のない区間列。
    private static func merge(_ intervals: [Interval]) -> [Interval] {
        var sorted: [Interval] = []
        sorted.reserveCapacity(intervals.count)
        for interval in intervals {
            let normalized = Interval(
                lower: max(interval.lower, 0),
                upper: min(interval.upper, 1)
            )
            if normalized.upper - normalized.lower > parameterEpsilon {
                sorted.append(normalized)
            }
        }
        sorted.sort { lhs, rhs in
            if lhs.lower == rhs.lower {
                return lhs.upper < rhs.upper
            }
            return lhs.lower < rhs.lower
        }
        guard var current = sorted.first else { return [] }
        var result: [Interval] = []
        for interval in sorted.dropFirst() {
            if interval.lower <= current.upper + parameterEpsilon {
                current.upper = max(current.upper, interval.upper)
            } else {
                result.append(current)
                current = interval
            }
        }
        result.append(current)
        return result
    }

    /// 論理名（日本語）: 消去区間補集合関数
    /// 処理概要: 0から1の線分全体から統合済み消去区間を引き、描画に残す区間を返します。
    ///
    /// - Parameter erased: 正規化・統合済みの消去区間。
    /// - Returns: 順序付きの残存区間。
    private static func complement(of erased: [Interval]) -> [Interval] {
        guard !erased.isEmpty else { return [Interval(lower: 0, upper: 1)] }
        var retained: [Interval] = []
        var cursor = 0.0
        for interval in erased {
            if interval.lower - cursor > parameterEpsilon {
                retained.append(Interval(lower: cursor, upper: interval.lower))
            }
            cursor = max(cursor, interval.upper)
        }
        if 1 - cursor > parameterEpsilon {
            retained.append(Interval(lower: cursor, upper: 1))
        }
        return retained
    }

    /// 論理名（日本語）: Fragment点追加関数
    /// 処理概要: 隣接 segment の共有 endpoint を二重保存せず、異なる補間点だけを追加します。
    ///
    /// - Parameters:
    ///   - point: 追加候補の world point。
    ///   - fragment: 構築中の fragment point 列。
    private static func appendIfDistinct(_ point: WorldPoint, to fragment: inout [WorldPoint]) {
        if fragment.last != point {
            fragment.append(point)
        }
    }

    /// 論理名（日本語）: Fragment確定関数
    /// 処理概要: 構築中の空でない point 列を結果へ移し、次の非連続区間を受けられる状態へ戻します。
    ///
    /// - Parameters:
    ///   - fragment: 構築中の fragment。
    ///   - result: 確定済み fragment 列。
    private static func finish(_ fragment: inout [WorldPoint], into result: inout [[WorldPoint]]) {
        guard !fragment.isEmpty else { return }
        result.append(fragment)
        fragment = []
    }

    /// 論理名（日本語）: Tight描画フレーム生成関数
    /// 処理概要: 残存する各点・線分の round cap を含む実描画 bounds を合成し、world frame として返します。
    ///
    /// - Parameter strokes: 部分消去後の world stroke fragment 列。
    /// - Returns: 表示可能な点がある場合は tight world frame、全て空なら `nil`。
    private static func renderedFrame(for strokes: [WorldStroke]) -> OpenGraphiteCanvasAnnotationFrame? {
        var minimumX = Double.infinity
        var minimumY = Double.infinity
        var maximumX = -Double.infinity
        var maximumY = -Double.infinity

        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            if stroke.points.count == 1 {
                let canonicalFirst = canonicalized(first)
                let radius = renderedRadius(baseWidth: stroke.lineWidth, pressure: canonicalFirst.pressure)
                include(
                    canonicalFirst,
                    radius: radius,
                    minX: &minimumX,
                    minY: &minimumY,
                    maxX: &maximumX,
                    maxY: &maximumY
                )
                continue
            }
            for index in 1..<stroke.points.count {
                let start = canonicalized(stroke.points[index - 1])
                let end = canonicalized(stroke.points[index])
                let radius = renderedRadius(
                    baseWidth: stroke.lineWidth,
                    pressure: (start.pressure + end.pressure) / 2
                )
                include(start, radius: radius, minX: &minimumX, minY: &minimumY, maxX: &maximumX, maxY: &maximumY)
                include(end, radius: radius, minX: &minimumX, minY: &minimumY, maxX: &maximumX, maxY: &maximumY)
            }
        }
        guard minimumX.isFinite,
              minimumY.isFinite,
              maximumX.isFinite,
              maximumY.isFinite
        else {
            return nil
        }
        let frameX = roundedDown(minimumX)
        let frameY = roundedDown(minimumY)
        let frameMaximumX = roundedUp(maximumX)
        let frameMaximumY = roundedUp(maximumY)
        return OpenGraphiteCanvasAnnotationFrame(
            x: frameX,
            y: frameY,
            width: frameMaximumX - frameX,
            height: frameMaximumY - frameY
        )
    }

    /// 論理名（日本語）: 描画Bounds点包含関数
    /// 処理概要: round cap の半径を含めた点の外接矩形で現在の bounds を更新します。
    ///
    /// - Parameters:
    ///   - point: world point。
    ///   - radius: point 周辺の実描画半径。
    ///   - minX: 更新する最小X。
    ///   - minY: 更新する最小Y。
    ///   - maxX: 更新する最大X。
    ///   - maxY: 更新する最大Y。
    private static func include(
        _ point: WorldPoint,
        radius: Double,
        minX: inout Double,
        minY: inout Double,
        maxX: inout Double,
        maxY: inout Double
    ) {
        minX = min(minX, point.x - radius)
        minY = min(minY, point.y - radius)
        maxX = max(maxX, point.x + radius)
        maxY = max(maxY, point.y + radius)
    }

    /// 論理名（日本語）: 実描画半径解決関数
    /// 処理概要: renderer と同じ `CanvasInkLineWidthResolver` の線幅を半分にし、hit tolerance を加えず返します。
    ///
    /// - Parameters:
    ///   - baseWidth: 保存済み基準線幅。
    ///   - pressure: 単一点の筆圧または線分両端の平均筆圧。
    /// - Returns: 実描画 capsule の半径。
    private static func renderedRadius(baseWidth: Double, pressure: Double) -> Double {
        Double(CanvasInkLineWidthResolver.width(baseWidth: baseWidth, pressure: pressure)) / 2
    }

    /// 論理名（日本語）: 点線分距離関数
    /// 処理概要: 点を有限線分へ射影し、clampした最近点までのEuclidean距離を返します。
    ///
    /// - Parameters:
    ///   - point: 距離を測る点。
    ///   - start: 線分始点。
    ///   - end: 線分終点。
    /// - Returns: 点と線分の最短距離。
    private static func pointDistance(_ point: Point, to start: Point, _ end: Point) -> Double {
        let delta = Point(x: end.x - start.x, y: end.y - start.y)
        let lengthSquared = dot(delta, delta)
        guard lengthSquared > geometryEpsilon else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let projection = dot(Point(x: point.x - start.x, y: point.y - start.y), delta) / lengthSquared
        let parameter = min(max(projection, 0), 1)
        return hypot(
            point.x - (start.x + delta.x * parameter),
            point.y - (start.y + delta.y * parameter)
        )
    }

    /// 論理名（日本語）: 消しゴム相互作用フレーム生成関数
    /// 処理概要: 直近eraser capsule列の中心線と実描画半径を包含するworld frameを生成します。
    ///
    /// - Parameter capsules: 今回判定するeraser capsule列。
    /// - Returns: capsuleがある場合は描画半径込みframe、それ以外は`nil`。
    private static func interactionFrame(
        for capsules: [Capsule]
    ) -> OpenGraphiteCanvasAnnotationFrame? {
        guard let first = capsules.first else { return nil }
        var minimumX = min(first.start.x, first.end.x) - first.radius
        var minimumY = min(first.start.y, first.end.y) - first.radius
        var maximumX = max(first.start.x, first.end.x) + first.radius
        var maximumY = max(first.start.y, first.end.y) + first.radius
        for capsule in capsules.dropFirst() {
            minimumX = min(minimumX, min(capsule.start.x, capsule.end.x) - capsule.radius)
            minimumY = min(minimumY, min(capsule.start.y, capsule.end.y) - capsule.radius)
            maximumX = max(maximumX, max(capsule.start.x, capsule.end.x) + capsule.radius)
            maximumY = max(maximumY, max(capsule.start.y, capsule.end.y) + capsule.radius)
        }
        return OpenGraphiteCanvasAnnotationFrame(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    /// 論理名（日本語）: 注釈フレーム交差判定関数
    /// 処理概要: 実描画余白を含むink frameとeraser相互作用frameが離れている注釈を、stroke走査前に除外します。
    ///
    /// - Parameters:
    ///   - inkFrame: 保存済みinkの描画frame。
    ///   - eraserFrame: 今回のeraser segmentの描画frame。
    /// - Returns: 両frameが接触または交差する場合は`true`。
    private static func framesIntersect(
        _ inkFrame: OpenGraphiteCanvasAnnotationFrame,
        _ eraserFrame: OpenGraphiteCanvasAnnotationFrame
    ) -> Bool {
        inkFrame.x <= eraserFrame.x + eraserFrame.width
            && inkFrame.x + inkFrame.width >= eraserFrame.x
            && inkFrame.y <= eraserFrame.y + eraserFrame.height
            && inkFrame.y + inkFrame.height >= eraserFrame.y
    }

    /// 論理名（日本語）: 二次元内積関数
    /// 処理概要: 2つのベクトルの内積を返します。
    ///
    /// - Parameters:
    ///   - lhs: 左辺ベクトル。
    ///   - rhs: 右辺ベクトル。
    /// - Returns: 内積。
    private static func dot(_ lhs: Point, _ rhs: Point) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y
    }

    /// 論理名（日本語）: 二次元外積関数
    /// 処理概要: 2つのベクトルの外積Z成分を返します。
    ///
    /// - Parameters:
    ///   - lhs: 左辺ベクトル。
    ///   - rhs: 右辺ベクトル。
    /// - Returns: 外積Z成分。
    private static func cross(_ lhs: Point, _ rhs: Point) -> Double {
        lhs.x * rhs.y - lhs.y * rhs.x
    }

    /// 論理名（日本語）: Worldストローク正規化関数
    /// 処理概要: 全pointを小数3桁へ揃え、同一座標へ潰れた隣接点とsubpixel fragmentをframe計算前に除外します。
    ///
    /// - Parameter stroke: 正規化前のworld stroke。
    /// - Returns: 表示可能な正規化stroke。複数点fragmentが単一点へ潰れた場合は`nil`。
    private static func canonicalized(_ stroke: WorldStroke) -> WorldStroke? {
        guard !stroke.points.isEmpty else { return nil }
        var points: [WorldPoint] = []
        points.reserveCapacity(stroke.points.count)
        for point in stroke.points {
            let canonicalPoint = canonicalized(point)
            if let last = points.last,
               last.x == canonicalPoint.x,
               last.y == canonicalPoint.y {
                points[points.count - 1] = canonicalPoint
            } else {
                points.append(canonicalPoint)
            }
        }
        guard stroke.points.count == 1 || points.count > 1 else { return nil }
        return WorldStroke(
            points: points,
            color: stroke.color,
            lineWidth: stroke.lineWidth,
            inputDevice: stroke.inputDevice
        )
    }

    /// 論理名（日本語）: World点正規化関数
    /// 処理概要: frame計算と保存payloadが同じ小数3桁の座標・筆圧・傾きを使うようworld点を正規化します。
    ///
    /// - Parameter point: 正規化前のworld点。
    /// - Returns: 全数値を小数3桁へ丸めたworld点。
    private static func canonicalized(_ point: WorldPoint) -> WorldPoint {
        WorldPoint(
            x: rounded(point.x),
            y: rounded(point.y),
            pressure: rounded(point.pressure),
            tiltX: rounded(point.tiltX),
            tiltY: rounded(point.tiltY)
        )
    }

    /// 論理名（日本語）: 部分消去数値丸め関数
    /// 処理概要: `.ogp` の数値表現を手書き入力と同じ小数3桁へ正規化します。
    ///
    /// - Parameter value: 正規化する有限値。
    /// - Returns: 小数3桁へ丸めた値。
    private static func rounded(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }

    /// 論理名（日本語）: 描画境界下方向丸め関数
    /// 処理概要: tight frame が実線をclipしないよう、最小境界を小数3桁の外側へ丸めます。
    ///
    /// - Parameter value: 最小境界値。
    /// - Returns: 小数3桁単位で元値以下の境界。
    private static func roundedDown(_ value: Double) -> Double {
        floor(value * 1_000) / 1_000
    }

    /// 論理名（日本語）: 描画境界上方向丸め関数
    /// 処理概要: tight frame が実線をclipしないよう、最大境界を小数3桁の外側へ丸めます。
    ///
    /// - Parameter value: 最大境界値。
    /// - Returns: 小数3桁単位で元値以上の境界。
    private static func roundedUp(_ value: Double) -> Double {
        ceil(value * 1_000) / 1_000
    }
}
