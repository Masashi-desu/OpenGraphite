import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバス注釈関連のテストスイート
/// 概要: `.ogp` 専用の付箋と手書き注釈について、Codable 契約、値の正規化、空値省略、内部 ID の安定性を確認します。
@Suite("キャンバス注釈関連のテストスイート")
struct OpenGraphiteCanvasAnnotationTests {
    /// 論理名（日本語）: 付箋と手書き注釈のCodableテスト
    /// 概要: 種別ごとに必要な payload だけが JSON へ保存され、同じモデルへ復元できることを検証します。
    @Test("付箋と手書き注釈を種別固有JSONで往復できる")
    func testCanvasAnnotationsRoundTripWithKindSpecificPayloads() throws {
        // コンディション：付箋を持つ Chapter と手書きを持つ Collection を含む project を用意する（Given）
        let stickyNote = OpenGraphiteCanvasAnnotation(
            internalID: "sticky-opaque",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 32, y: -18, width: 240, height: 160),
            text: "CLI から読めるメモ",
            backgroundColor: "#FFF3A6",
            textColor: "#211F18"
        )
        let ink = OpenGraphiteCanvasAnnotation(
            internalID: "ink-opaque",
            kind: .ink,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 420, y: 96, width: 180, height: 80),
            strokes: [
                OpenGraphiteInkStroke(
                    points: [
                        OpenGraphiteInkPoint(x: 0, y: 4, pressure: 0.25, tiltX: -0.2, tiltY: 0.4),
                        OpenGraphiteInkPoint(x: 24, y: 16, pressure: 0.8, tiltX: 0.1, tiltY: 0.3)
                    ],
                    color: "#2D6BFF",
                    lineWidth: 4,
                    inputDevice: .pen
                )
            ]
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Annotation Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapter-opaque",
                    title: "Main",
                    pages: [],
                    annotations: [stickyNote]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collection-opaque",
                    title: "Main",
                    components: [],
                    annotations: [ink]
                )
            ]
        )

        // 検証内容：project を JSON へエンコードし、辞書とモデルの両方へデコードする（When）
        let data = try JSONEncoder().encode(project)
        let decodedProject = try JSONDecoder().decode(OpenGraphiteProject.self, from: data)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let chapters = try #require(json["chapters"] as? [[String: Any]])
        let chapterAnnotations = try #require(chapters.first?["annotations"] as? [[String: Any]])
        let stickyJSON = try #require(chapterAnnotations.first)
        let collections = try #require(json["collections"] as? [[String: Any]])
        let collectionAnnotations = try #require(collections.first?["annotations"] as? [[String: Any]])
        let inkJSON = try #require(collectionAnnotations.first)
        let strokesJSON = try #require(inkJSON["strokes"] as? [[String: Any]])
        let strokeJSON = try #require(strokesJSON.first)

        // 期待値：付箋と手書きは不要な相互 payload を持たず、全値が同じモデルへ復元される（Then）
        #expect(decodedProject == project)
        #expect(stickyJSON["kind"] as? String == "stickyNote")
        #expect(stickyJSON["text"] as? String == "CLI から読めるメモ")
        #expect(stickyJSON["backgroundColor"] as? String == "#FFF3A6")
        #expect(stickyJSON["strokes"] == nil)
        #expect(inkJSON["kind"] as? String == "ink")
        #expect(inkJSON["text"] == nil)
        #expect(inkJSON["backgroundColor"] == nil)
        #expect(strokeJSON["color"] as? String == "#2D6BFF")
        #expect(strokeJSON["inputDevice"] as? String == "pen")
        #expect((strokeJSON["points"] as? [[String: Any]])?.count == 2)
    }

    /// 論理名（日本語）: 注釈数値正規化テスト
    /// 概要: 外部 `.ogp` と入力デバイス由来の不正な寸法、筆圧、色、線幅が安全な範囲へ補正されることを検証します。
    @Test("注釈フレームと手書き値を安全な範囲へ正規化する")
    func testCanvasAnnotationValuesAreNormalized() throws {
        // コンディション：不正な有限値と既定値省略を含む frame / stroke JSON、および非有限座標を用意する（Given）
        let frameJSON = Data(#"{"x":12,"y":-8,"width":-40,"height":0}"#.utf8)
        let strokeJSON = Data(
            #"{"points":[{"x":3,"y":4,"pressure":2.4},{"x":8,"y":9}],"color":"   ","lineWidth":0.1}"#.utf8
        )

        // 検証内容：JSON をデコードし、非有限値を通常初期化関数へ渡す（When）
        let frame = try JSONDecoder().decode(OpenGraphiteCanvasAnnotationFrame.self, from: frameJSON)
        let stroke = try JSONDecoder().decode(OpenGraphiteInkStroke.self, from: strokeJSON)
        let nonFiniteFrame = OpenGraphiteCanvasAnnotationFrame(
            x: .infinity,
            y: .nan,
            width: .nan,
            height: .infinity
        )
        let nonFinitePoint = OpenGraphiteInkPoint(
            x: .nan,
            y: .infinity,
            pressure: .nan,
            tiltX: .nan,
            tiltY: .infinity
        )
        let hugeFiniteFrame = OpenGraphiteCanvasAnnotationFrame(
            x: .greatestFiniteMagnitude,
            y: -.greatestFiniteMagnitude,
            width: .greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude
        )
        let hugeFinitePoint = OpenGraphiteInkPoint(
            x: .greatestFiniteMagnitude,
            y: -.greatestFiniteMagnitude,
            pressure: 0.5,
            tiltX: .greatestFiniteMagnitude,
            tiltY: -.greatestFiniteMagnitude
        )
        let hugeFiniteStroke = OpenGraphiteInkStroke(
            points: [hugeFinitePoint],
            lineWidth: .greatestFiniteMagnitude
        )

        // 期待値：寸法は1以上、筆圧は0から1、その他の不正値は安全な既定値になる（Then）
        #expect(frame == OpenGraphiteCanvasAnnotationFrame(x: 12, y: -8, width: 1, height: 1))
        #expect(stroke.color == "#FF4D67")
        #expect(stroke.lineWidth == 0.5)
        #expect(stroke.inputDevice == .unknown)
        #expect(stroke.points.map(\.pressure) == [1, 1])
        #expect(stroke.points[1].tiltX == 0)
        #expect(stroke.points[1].tiltY == 0)
        #expect(nonFiniteFrame == OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 1, height: 1))
        #expect(nonFinitePoint == OpenGraphiteInkPoint(x: 0, y: 0, pressure: 1, tiltX: 0, tiltY: 0))
        #expect(hugeFiniteFrame.x == OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude)
        #expect(hugeFiniteFrame.y == -OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude)
        #expect(hugeFiniteFrame.width == OpenGraphiteCanvasAnnotationLimits.maximumDimension)
        #expect((hugeFiniteFrame.x + hugeFiniteFrame.width).isFinite)
        #expect(hugeFinitePoint.x == OpenGraphiteCanvasAnnotationLimits.maximumCoordinateMagnitude)
        #expect(hugeFinitePoint.tiltX == OpenGraphiteCanvasAnnotationLimits.maximumTiltMagnitude)
        #expect(hugeFinitePoint.tiltY == -OpenGraphiteCanvasAnnotationLimits.maximumTiltMagnitude)
        #expect(hugeFiniteStroke.lineWidth == OpenGraphiteCanvasAnnotationLimits.maximumLineWidth)
    }

    /// 論理名（日本語）: 空注釈配列互換テスト
    /// 概要: annotations がない現行 `.ogp` を空配列として読み込み、再保存時にも不要なキーを追加しないことを検証します。
    @Test("空の注釈配列をJSONから省略して旧projectを読み込める")
    func testEmptyAnnotationArraysAreOmittedAndDecodeAsEmpty() throws {
        // コンディション：空の Chapter / Collection を持つモデルと annotations キーがない旧形式 JSON を用意する（Given）
        let project = OpenGraphiteProject(
            version: "1",
            name: "Empty Annotation Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(id: "main", internalID: "chapter-opaque", title: "Main", pages: [])
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collection-opaque",
                    title: "Main",
                    components: []
                )
            ]
        )
        let legacyJSON = Data(
            """
            {
              "version": "1",
              "name": "Legacy",
              "htmlRoot": "public",
              "cssLibrary": "CSS/OpenGraphite.css",
              "chapters": [
                { "id": "main", "internalID": "chapter-opaque", "pages": [] }
              ],
              "collections": [
                { "id": "main", "internalID": "collection-opaque", "components": [] }
              ]
            }
            """.utf8
        )

        // 検証内容：空モデルをエンコードし、旧形式 JSON をデコードする（When）
        let encodedData = try JSONEncoder().encode(project)
        let encodedJSON = try #require(JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        let encodedChapters = try #require(encodedJSON["chapters"] as? [[String: Any]])
        let encodedCollections = try #require(encodedJSON["collections"] as? [[String: Any]])
        let decodedLegacy = try JSONDecoder().decode(OpenGraphiteProject.self, from: legacyJSON)

        // 期待値：空 annotations キーは保存されず、未指定の旧 project は空配列として読み込まれる（Then）
        #expect(encodedChapters.first?["annotations"] == nil)
        #expect(encodedCollections.first?["annotations"] == nil)
        #expect(decodedLegacy.chapters.first?.annotations.isEmpty == true)
        #expect(decodedLegacy.collections.first?.annotations.isEmpty == true)
    }

    /// 論理名（日本語）: 注釈内部ID安定化テスト
    /// 概要: 未設定、意味付き、重複した注釈内部 ID が manifest 全体で一意になり、その後の内容更新でも維持されることを検証します。
    @Test("注釈内部IDを一意に補完して内容更新後も維持する")
    func testAnnotationInternalIDsAreUniqueAndStable() throws {
        // コンディション：未設定、意味付き、重複した内部 ID を持つ Chapter / Collection 注釈を用意する（Given）
        let frame = OpenGraphiteCanvasAnnotationFrame(x: 10, y: 20, width: 240, height: 160)
        let project = OpenGraphiteProject(
            version: "1",
            name: "Annotation ID Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapter-main",
                    title: "Main",
                    pages: [],
                    annotations: [
                        OpenGraphiteCanvasAnnotation(
                            internalID: "fixedopaque",
                            kind: .stickyNote,
                            frame: frame,
                            text: "維持するID"
                        ),
                        OpenGraphiteCanvasAnnotation(kind: .stickyNote, frame: frame, text: "未設定ID"),
                        OpenGraphiteCanvasAnnotation(
                            internalID: "annotation-note",
                            kind: .stickyNote,
                            frame: frame,
                            text: "意味付きID"
                        ),
                        OpenGraphiteCanvasAnnotation(
                            internalID: "fixedopaque",
                            kind: .ink,
                            frame: frame,
                            strokes: []
                        )
                    ]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collection-main",
                    title: "Main",
                    components: [],
                    annotations: [
                        OpenGraphiteCanvasAnnotation(
                            internalID: "fixedopaque",
                            kind: .stickyNote,
                            frame: frame,
                            text: "Collection側"
                        )
                    ]
                )
            ]
        )

        // 検証内容：project を正規化し、付箋本文を変更してから再度正規化する（When）
        let normalized = project.normalizedInternalIDs()
        let initialAnnotationIDs = normalized.chapters.flatMap(\.annotations).map(\.internalID)
            + normalized.collections.flatMap(\.annotations).map(\.internalID)
        var textUpdated = normalized
        textUpdated.chapters[0].annotations[0].text = "更新後も同じID"
        let normalizedAgain = textUpdated.normalizedInternalIDs()
        let updatedAnnotationIDs = normalizedAgain.chapters.flatMap(\.annotations).map(\.internalID)
            + normalizedAgain.collections.flatMap(\.annotations).map(\.internalID)
        let allManifestIDs = normalized.chapters.map(\.internalID)
            + normalized.chapters.flatMap(\.pages).map(\.internalID)
            + normalized.chapters.flatMap(\.annotations).map(\.internalID)
            + normalized.collections.map(\.internalID)
            + normalized.collections.flatMap(\.components).map(\.internalID)
            + normalized.collections.flatMap(\.annotations).map(\.internalID)

        // 期待値：既存 opaque ID は優先され、全 ID が一意かつ内容変更後も同じ値になる（Then）
        #expect(initialAnnotationIDs.first == "fixedopaque")
        #expect(initialAnnotationIDs.allSatisfy { !$0.isEmpty })
        #expect(initialAnnotationIDs.allSatisfy { $0 != "annotation-note" })
        #expect(Set(allManifestIDs).count == allManifestIDs.count)
        #expect(updatedAnnotationIDs == initialAnnotationIDs)
    }

    /// 論理名（日本語）: 構造内部ID優先正規化テスト
    /// 概要: 注釈が Chapter / Page / Collection / Component の既存 ID と衝突しても、参照先となる構造 ID が維持されることを検証します。
    @Test("注釈衝突よりChapter Page Collection Componentの既存IDを優先する")
    func testStructuralInternalIDsTakePriorityOverAnnotationCollisions() {
        // コンディション：4種の構造IDをそれぞれ内部IDに持つ注釈を、早いChapterと後続Collectionに用意する（Given）
        let frame = OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 100)
        let page = OpenGraphitePage(
            id: "home",
            internalID: "pageopaque",
            path: "index.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1_440, height: 1_200)
        )
        let component = OpenGraphitePage(
            id: "button",
            internalID: "componentopaque",
            path: "_components/button.html",
            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 320, height: 240)
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Structural Priority Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapteropaque",
                    pages: [page],
                    annotations: [
                        OpenGraphiteCanvasAnnotation(
                            internalID: "collectionopaque",
                            kind: .stickyNote,
                            frame: frame
                        ),
                        OpenGraphiteCanvasAnnotation(
                            internalID: "componentopaque",
                            kind: .ink,
                            frame: frame
                        )
                    ]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collectionopaque",
                    components: [component],
                    annotations: [
                        OpenGraphiteCanvasAnnotation(
                            internalID: "chapteropaque",
                            kind: .stickyNote,
                            frame: frame
                        ),
                        OpenGraphiteCanvasAnnotation(
                            internalID: "pageopaque",
                            kind: .stickyNote,
                            frame: frame
                        )
                    ]
                )
            ]
        )

        // 検証内容：project全体の内部IDを二段階で正規化する（When）
        let normalized = project.normalizedInternalIDs()
        let structuralIDs = [
            normalized.chapters[0].internalID,
            normalized.chapters[0].pages[0].internalID,
            normalized.collections[0].internalID,
            normalized.collections[0].components[0].internalID
        ]
        let annotationIDs = normalized.chapters[0].annotations.map(\.internalID)
            + normalized.collections[0].annotations.map(\.internalID)

        // 期待値：構造IDはすべて維持され、衝突する注釈側だけが一意化される（Then）
        #expect(structuralIDs == ["chapteropaque", "pageopaque", "collectionopaque", "componentopaque"])
        #expect(Set(annotationIDs).isDisjoint(with: Set(structuralIDs)))
        #expect(Set(structuralIDs + annotationIDs).count == structuralIDs.count + annotationIDs.count)
    }
}
