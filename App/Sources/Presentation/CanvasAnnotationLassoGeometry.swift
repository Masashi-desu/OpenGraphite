import Foundation

/// 論理名（日本語）: キャンバス注釈なげわ選択解決器
/// 概要: canonical world 座標の自由曲線を閉じた多角形として扱い、付箋矩形または手書き実線との包含・交差を判定します。
enum CanvasAnnotationLassoSelectionResolver {
    /// 論理名（日本語）: なげわ多角形有効性判定関数
    /// 処理概要: UI と選択解決で同じ正規化規則を共有し、自己交差を含む非共線の自由曲線を受理します。
    ///
    /// - Parameter polygon: canonical world 座標のなげわ頂点列。
    /// - Returns: 閉多角形として選択判定できる場合は `true`。
    static func isValidPolygon(_ polygon: [CGPoint]) -> Bool {
        CanvasLassoPolygon(points: polygon) != nil
    }

    /// 論理名（日本語）: なげわ選択注釈ID列取得関数
    /// 処理概要: 有効ななげわ多角形と交差する注釈だけを抽出し、入力注釈と同じ順序で内部 ID を返します。
    ///
    /// - Parameters:
    ///   - annotations: 判定対象のキャンバス注釈。
    ///   - polygon: canonical world 座標で記録したなげわ頂点列。終点から始点への辺は暗黙に閉じます。
    /// - Returns: 選択された注釈の内部 ID 列。多角形を構成できない場合は空配列。
    static func selectedAnnotationIDs(
        in annotations: [OpenGraphiteCanvasAnnotation],
        by polygon: [CGPoint]
    ) -> [String] {
        guard let lasso = CanvasLassoPolygon(points: polygon) else { return [] }
        return annotations.compactMap { annotation in
            intersects(annotation, lasso: lasso) ? annotation.internalID : nil
        }
    }

    /// 論理名（日本語）: なげわ単一注釈選択判定関数
    /// 処理概要: 付箋は表示矩形、手書きは frame-local 点を world 座標へ戻し、筆圧込みの表示線幅を持つ実線を対象になげわとの包含・交差を判定します。
    ///
    /// - Parameters:
    ///   - annotation: 判定対象のキャンバス注釈。
    ///   - polygon: canonical world 座標で記録したなげわ頂点列。終点から始点への辺は暗黙に閉じます。
    /// - Returns: 注釈がなげわ内にあるか、なげわ境界と交差する場合は `true`。
    static func isSelected(
        _ annotation: OpenGraphiteCanvasAnnotation,
        by polygon: [CGPoint]
    ) -> Bool {
        guard let lasso = CanvasLassoPolygon(points: polygon) else { return false }
        return intersects(annotation, lasso: lasso)
    }

    /// 論理名（日本語）: 注釈種別別なげわ交差判定関数
    /// 処理概要: 付箋と手書きをそれぞれの実形状に対応する判定へ振り分けます。
    ///
    /// - Parameters:
    ///   - annotation: 判定対象の注釈。
    ///   - lasso: 正規化済みのなげわ多角形。
    /// - Returns: 注釈が選択対象なら `true`。
    private static func intersects(
        _ annotation: OpenGraphiteCanvasAnnotation,
        lasso: CanvasLassoPolygon
    ) -> Bool {
        switch annotation.kind {
        case .stickyNote:
            return lasso.intersects(rect: annotation.frame)
        case .ink:
            return annotation.strokes.contains { stroke in
                let samples = stroke.points.map { point in
                    CanvasLassoInkSample(
                        point: CGPoint(
                            x: annotation.frame.x + point.x,
                            y: annotation.frame.y + point.y
                        ),
                        radius: CanvasInkLineWidthResolver.width(
                            baseWidth: stroke.lineWidth,
                            pressure: point.pressure
                        ) / 2
                    )
                }
                return lasso.intersects(stroke: samples)
            }
        }
    }
}

/// 論理名（日本語）: なげわ判定用手書きサンプル
/// 概要: canonical world 座標の中心点と、筆圧を反映した表示線の半径を保持します。
private struct CanvasLassoInkSample {
    var point: CGPoint
    var radius: CGFloat
}

/// 論理名（日本語）: なげわ多角形幾何
/// 概要: 重複終点を除いた有効な閉多角形を保持し、点・線分・矩形との境界を含む交差判定を提供します。
private struct CanvasLassoPolygon {
    /// 論理名（日本語）: なげわ線分
    /// 概要: 多角形または手書きの隣接する2点を結ぶ有限線分を表します。
    private struct Segment {
        var start: CGPoint
        var end: CGPoint
    }

    private static let epsilon: CGFloat = 0.000_001
    private static let minimumInteractionArea: CGFloat = 9

    private let points: [CGPoint]
    private let edges: [Segment]

    /// 論理名（日本語）: なげわ多角形初期化関数
    /// 処理概要: 非有限点と微小な手ぶれを拒否し、連続重複点と明示的な重複終点を除いたうえで、操作面積を持つ3点以上の閉多角形を生成します。
    ///
    /// - Parameter points: canonical world 座標の自由曲線点列。
    init?(points: [CGPoint]) {
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }

        var normalized: [CGPoint] = []
        normalized.reserveCapacity(points.count)
        for point in points where normalized.last.map({ !Self.areEqual($0, point) }) ?? true {
            normalized.append(point)
        }
        if normalized.count > 1,
           let first = normalized.first,
           let last = normalized.last,
           Self.areEqual(first, last) {
            normalized.removeLast()
        }

        guard normalized.count >= 3,
              Self.hasNonCollinearPoints(normalized),
              Self.absoluteTriangleArea(normalized) >= Self.minimumInteractionArea
        else {
            return nil
        }
        self.points = normalized
        self.edges = normalized.indices.map { index in
            Segment(
                start: normalized[index],
                end: normalized[(index + 1) % normalized.count]
            )
        }
    }

    /// 論理名（日本語）: なげわ矩形交差判定関数
    /// 処理概要: 多角形内の矩形、矩形内の多角形、または両者の境界交差を検出します。
    ///
    /// - Parameter frame: canonical world 座標の付箋矩形。
    /// - Returns: 矩形の面または境界がなげわの面または境界と共有部分を持つ場合は `true`。
    func intersects(rect frame: OpenGraphiteCanvasAnnotationFrame) -> Bool {
        let minimumX = CGFloat(frame.x)
        let minimumY = CGFloat(frame.y)
        let maximumX = CGFloat(frame.x + frame.width)
        let maximumY = CGFloat(frame.y + frame.height)
        let corners = [
            CGPoint(x: minimumX, y: minimumY),
            CGPoint(x: maximumX, y: minimumY),
            CGPoint(x: maximumX, y: maximumY),
            CGPoint(x: minimumX, y: maximumY)
        ]

        if corners.contains(where: contains) {
            return true
        }
        if points.contains(where: { point in
            Self.contains(point, inRectFrom: corners)
        }) {
            return true
        }

        let rectEdges = corners.indices.map { index in
            Segment(start: corners[index], end: corners[(index + 1) % corners.count])
        }
        return edges.contains { lassoEdge in
            rectEdges.contains { rectEdge in
                Self.intersects(lassoEdge, rectEdge)
            }
        }
    }

    /// 論理名（日本語）: なげわ実線交差判定関数
    /// 処理概要: 手書きの実点が多角形内にあるか、隣接する実線分が多角形境界を横切るかを検出します。
    ///
    /// - Parameter polyline: canonical world 座標へ変換済みの手書き点列。
    /// - Returns: 実点または実線分がなげわの面または境界と共有部分を持つ場合は `true`。
    func intersects(polyline: [CGPoint]) -> Bool {
        guard let first = polyline.first else { return false }
        if contains(first) { return true }
        guard polyline.count > 1 else { return false }

        for index in 1..<polyline.count {
            let start = polyline[index - 1]
            let end = polyline[index]
            if contains(end) {
                return true
            }
            let inkSegment = Segment(start: start, end: end)
            if edges.contains(where: { Self.intersects($0, inkSegment) }) {
                return true
            }
        }
        return false
    }

    /// 論理名（日本語）: なげわ表示ストローク交差判定関数
    /// 処理概要: 中心線の包含・交差に加え、筆圧込みの表示半径内へなげわ境界が触れた場合も選択します。
    ///
    /// - Parameter samples: world 座標の中心点と表示半径を持つ手書きサンプル列。
    /// - Returns: 表示される手書き領域がなげわの面または境界と共有部分を持つ場合は `true`。
    func intersects(stroke samples: [CanvasLassoInkSample]) -> Bool {
        guard let first = samples.first else { return false }
        if intersects(polyline: samples.map(\.point)) {
            return true
        }
        guard samples.count > 1 else {
            return edges.contains {
                Self.pointDistance(first.point, to: $0.start, $0.end) <= first.radius
            }
        }

        for index in 1..<samples.count {
            let start = samples[index - 1]
            let end = samples[index]
            let inkSegment = Segment(start: start.point, end: end.point)
            let visibleRadius = (start.radius + end.radius) / 2
            if edges.contains(where: {
                Self.segmentDistance($0, inkSegment) <= visibleRadius
            }) {
                return true
            }
        }
        return false
    }

    /// 論理名（日本語）: なげわ点包含判定関数
    /// 処理概要: 境界上を包含として先に扱い、残りを奇偶規則のray castingで判定します。
    ///
    /// - Parameter point: 判定する canonical world 座標点。
    /// - Returns: 点が多角形内部または境界上なら `true`。
    private func contains(_ point: CGPoint) -> Bool {
        if edges.contains(where: { Self.contains(point, on: $0) }) {
            return true
        }

        var isInside = false
        for edge in edges {
            let crossesScanline = (edge.start.y > point.y) != (edge.end.y > point.y)
            guard crossesScanline else { continue }
            let intersectionX = edge.start.x
                + (point.y - edge.start.y) * (edge.end.x - edge.start.x)
                / (edge.end.y - edge.start.y)
            if point.x < intersectionX {
                isInside.toggle()
            }
        }
        return isInside
    }

    /// 論理名（日本語）: 線分交差判定関数
    /// 処理概要: 境界接触を先に拾い、残りは両線分の端点が互いの直線の反対側にあるかで判定します。
    ///
    /// - Parameters:
    ///   - lhs: 1本目の線分。
    ///   - rhs: 2本目の線分。
    /// - Returns: 線分同士が交差または接触する場合は `true`。
    private static func intersects(_ lhs: Segment, _ rhs: Segment) -> Bool {
        if contains(lhs.start, on: rhs)
            || contains(lhs.end, on: rhs)
            || contains(rhs.start, on: lhs)
            || contains(rhs.end, on: lhs) {
            return true
        }

        let lhsStartSide = cross(rhs.start, rhs.end, lhs.start)
        let lhsEndSide = cross(rhs.start, rhs.end, lhs.end)
        let rhsStartSide = cross(lhs.start, lhs.end, rhs.start)
        let rhsEndSide = cross(lhs.start, lhs.end, rhs.end)
        return ((lhsStartSide > epsilon && lhsEndSide < -epsilon)
            || (lhsStartSide < -epsilon && lhsEndSide > epsilon))
            && ((rhsStartSide > epsilon && rhsEndSide < -epsilon)
                || (rhsStartSide < -epsilon && rhsEndSide > epsilon))
    }

    /// 論理名（日本語）: 点の線分上判定関数
    /// 処理概要: 点から線分への最短距離と線分の軸方向範囲を使い、端点を含む境界接触を判定します。
    ///
    /// - Parameters:
    ///   - point: 判定する点。
    ///   - segment: 判定対象の線分。
    /// - Returns: 点が許容誤差内で線分上にある場合は `true`。
    private static func contains(_ point: CGPoint, on segment: Segment) -> Bool {
        let deltaX = segment.end.x - segment.start.x
        let deltaY = segment.end.y - segment.start.y
        let squaredLength = deltaX * deltaX + deltaY * deltaY
        guard squaredLength > epsilon * epsilon else {
            return areEqual(point, segment.start)
        }
        let projection = ((point.x - segment.start.x) * deltaX
            + (point.y - segment.start.y) * deltaY) / squaredLength
        guard projection >= -epsilon, projection <= 1 + epsilon else { return false }
        let closest = CGPoint(
            x: segment.start.x + min(max(projection, 0), 1) * deltaX,
            y: segment.start.y + min(max(projection, 0), 1) * deltaY
        )
        return hypot(point.x - closest.x, point.y - closest.y) <= epsilon
    }

    /// 論理名（日本語）: 線分間距離関数
    /// 処理概要: 交差時は0、非交差時は両線分の各端点から相手線分への最短距離を返します。
    ///
    /// - Parameters:
    ///   - lhs: 1本目の線分。
    ///   - rhs: 2本目の線分。
    /// - Returns: 2本の有限線分間の最短距離。
    private static func segmentDistance(_ lhs: Segment, _ rhs: Segment) -> CGFloat {
        if intersects(lhs, rhs) { return 0 }
        return min(
            pointDistance(lhs.start, to: rhs.start, rhs.end),
            pointDistance(lhs.end, to: rhs.start, rhs.end),
            pointDistance(rhs.start, to: lhs.start, lhs.end),
            pointDistance(rhs.end, to: lhs.start, lhs.end)
        )
    }

    /// 論理名（日本語）: 点線分距離関数
    /// 処理概要: 点を有限線分へ射影して範囲内へ収め、最近点との距離を返します。
    ///
    /// - Parameters:
    ///   - point: 距離を測る点。
    ///   - start: 線分始点。
    ///   - end: 線分終点。
    /// - Returns: 点と有限線分の最短距離。
    private static func pointDistance(_ point: CGPoint, to start: CGPoint, _ end: CGPoint) -> CGFloat {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let squaredLength = deltaX * deltaX + deltaY * deltaY
        guard squaredLength > epsilon * epsilon else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let projection = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / squaredLength
        let clamped = min(max(projection, 0), 1)
        let closest = CGPoint(x: start.x + deltaX * clamped, y: start.y + deltaY * clamped)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    /// 論理名（日本語）: 矩形点包含判定関数
    /// 処理概要: 4隅から得た最小・最大座標を使い、境界を含めて点を判定します。
    ///
    /// - Parameters:
    ///   - point: 判定する点。
    ///   - corners: 左上から時計回りの矩形4隅。
    /// - Returns: 点が矩形内部または境界上なら `true`。
    private static func contains(_ point: CGPoint, inRectFrom corners: [CGPoint]) -> Bool {
        guard corners.count == 4 else { return false }
        let minimumX = corners.map(\.x).min() ?? 0
        let maximumX = corners.map(\.x).max() ?? 0
        let minimumY = corners.map(\.y).min() ?? 0
        let maximumY = corners.map(\.y).max() ?? 0
        return point.x >= minimumX - epsilon
            && point.x <= maximumX + epsilon
            && point.y >= minimumY - epsilon
            && point.y <= maximumY + epsilon
    }

    /// 論理名（日本語）: 非同一直線点存在判定関数
    /// 処理概要: 最初の異なる2点と直線を構成し、その直線外に3点目が存在することを確認します。
    ///
    /// - Parameter points: 連続重複除去済み点列。
    /// - Returns: 面を構成できる3点が存在する場合は `true`。
    private static func hasNonCollinearPoints(_ points: [CGPoint]) -> Bool {
        guard let first = points.first,
              let second = points.dropFirst().first(where: { !areEqual(first, $0) })
        else {
            return false
        }
        return points.contains { point in
            abs(cross(first, second, point)) > epsilon
        }
    }

    /// 論理名（日本語）: 絶対三角形面積合計関数
    /// 処理概要: 先頭点を基準に隣接点ペアとの三角形面積を絶対値で合計し、自己交差で符号が相殺されない操作面積を求めます。
    ///
    /// - Parameter points: 正規化済みの自由曲線点列。
    /// - Returns: 自己交差する各領域も正値として数えた面積合計。
    private static func absoluteTriangleArea(_ points: [CGPoint]) -> CGFloat {
        guard let first = points.first, points.count >= 3 else { return 0 }
        return (1..<(points.count - 1)).reduce(CGFloat.zero) { result, index in
            result + abs(cross(first, points[index], points[index + 1])) / 2
        }
    }

    /// 論理名（日本語）: 外積関数
    /// 処理概要: 有向線分と点の2次元外積を求め、左右関係と同一直線性の判定に使います。
    ///
    /// - Parameters:
    ///   - start: 有向線分の始点。
    ///   - end: 有向線分の終点。
    ///   - point: 有向線分との位置関係を求める点。
    /// - Returns: 2次元外積。正負が線分の左右、0が同一直線を表します。
    private static func cross(_ start: CGPoint, _ end: CGPoint, _ point: CGPoint) -> CGFloat {
        (end.x - start.x) * (point.y - start.y)
            - (end.y - start.y) * (point.x - start.x)
    }

    /// 論理名（日本語）: 座標点近似一致判定関数
    /// 処理概要: X/Yそれぞれの差を小さな許容誤差で比較します。
    ///
    /// - Parameters:
    ///   - lhs: 1点目。
    ///   - rhs: 2点目。
    /// - Returns: 両点が許容誤差内で同じ位置なら `true`。
    private static func areEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) <= epsilon && abs(lhs.y - rhs.y) <= epsilon
    }
}
