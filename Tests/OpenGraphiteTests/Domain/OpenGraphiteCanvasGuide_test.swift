import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: キャンバスガイド関連のテストスイート
/// 概要: `.ogp` Guide の Codable 契約、旧 project 互換、座標と内部 ID の正規化を確認します。
@Suite("キャンバスガイド関連のテストスイート")
struct OpenGraphiteCanvasGuideTests {
    /// 論理名（日本語）: ガイドCodableテスト
    /// 概要: Chapter / Collection の guides が方向と world 座標を保って `.ogp` JSON を往復することを検証します。
    @Test("ChapterとCollectionのguideをogp JSONで往復できる")
    func testCanvasGuidesRoundTripInProjectJSON() throws {
        // コンディション：垂直guideを持つChapterと水平guideを持つCollectionを用意する（Given）
        let verticalGuide = OpenGraphiteCanvasGuide(
            internalID: "vertical-opaque",
            orientation: .vertical,
            position: 320
        )
        let horizontalGuide = OpenGraphiteCanvasGuide(
            internalID: "horizontal-opaque",
            orientation: .horizontal,
            position: -48
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Guide Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "chapter-opaque",
                    pages: [],
                    guides: [verticalGuide]
                )
            ],
            collections: [
                OpenGraphiteComponentCollection(
                    id: "main",
                    internalID: "collection-opaque",
                    components: [],
                    guides: [horizontalGuide]
                )
            ]
        )

        // 検証内容：projectをJSONへencodeし、辞書とmodelの両方へdecodeする（When）
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(OpenGraphiteProject.self, from: data)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let chapters = try #require(json["chapters"] as? [[String: Any]])
        let chapterGuides = try #require(chapters.first?["guides"] as? [[String: Any]])
        let collections = try #require(json["collections"] as? [[String: Any]])
        let collectionGuides = try #require(collections.first?["guides"] as? [[String: Any]])

        // 期待値：方向・位置・内部IDがJSONと復元modelの両方で維持される（Then）
        #expect(decoded == project)
        #expect(chapterGuides.first?["internalID"] as? String == "vertical-opaque")
        #expect(chapterGuides.first?["orientation"] as? String == "vertical")
        #expect(chapterGuides.first?["position"] as? Double == 320)
        #expect(collectionGuides.first?["orientation"] as? String == "horizontal")
        #expect(collectionGuides.first?["position"] as? Double == -48)
    }

    /// 論理名（日本語）: 空ガイド配列互換テスト
    /// 概要: guides がない旧 `.ogp` を空配列として読み込み、再保存時も空 key を追加しないことを検証します。
    @Test("空guidesを省略して旧projectを読み込める")
    func testEmptyGuideArraysAreOmittedAndDecodeAsEmpty() throws {
        // コンディション：guidesを持たない現行modelとguides keyがない旧JSONを用意する（Given）
        let project = OpenGraphiteProject(
            version: "1",
            name: "Empty Guide Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [OpenGraphiteChapter(id: "main", pages: [])],
            collections: [OpenGraphiteComponentCollection(id: "main", components: [])]
        )
        let legacyJSON = Data(
            """
            {
              "version": "1",
              "name": "Legacy",
              "htmlRoot": "public",
              "cssLibrary": "CSS/OpenGraphite.css",
              "chapters": [{ "id": "main", "pages": [] }],
              "collections": [{ "id": "main", "components": [] }]
            }
            """.utf8
        )

        // 検証内容：空modelをencodeし、旧JSONをdecodeする（When）
        let encodedData = try JSONEncoder().encode(project)
        let encodedJSON = try #require(JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        let encodedChapters = try #require(encodedJSON["chapters"] as? [[String: Any]])
        let encodedCollections = try #require(encodedJSON["collections"] as? [[String: Any]])
        let decodedLegacy = try JSONDecoder().decode(OpenGraphiteProject.self, from: legacyJSON)

        // 期待値：空keyは出力されず、旧projectは空guidesとして扱われる（Then）
        #expect(encodedChapters.first?["guides"] == nil)
        #expect(encodedCollections.first?["guides"] == nil)
        #expect(decodedLegacy.chapters.first?.guides.isEmpty == true)
        #expect(decodedLegacy.collections.first?.guides.isEmpty == true)
    }

    /// 論理名（日本語）: ガイド正規化テスト
    /// 概要: 有限座標を安全範囲へ収め、未設定・重複内部 ID を project 全体で一意にすることを検証します。
    @Test("guide座標と内部IDを安全に正規化する")
    func testCanvasGuidePositionAndInternalIDsAreNormalized() throws {
        // コンディション：過大座標と未設定・注釈衝突IDを持つguideを用意する（Given）
        let annotation = OpenGraphiteCanvasAnnotation(
            internalID: "shared-opaque",
            kind: .stickyNote,
            frame: OpenGraphiteCanvasAnnotationFrame(x: 0, y: 0, width: 100, height: 100)
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "Guide Normalization Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    pages: [],
                    annotations: [annotation],
                    guides: [
                        OpenGraphiteCanvasGuide(
                            internalID: "shared-opaque",
                            orientation: .vertical,
                            position: .greatestFiniteMagnitude
                        ),
                        OpenGraphiteCanvasGuide(orientation: .horizontal, position: -120)
                    ]
                )
            ]
        )

        // 検証内容：project内部IDを正規化し、非有限値も入力検証する（When）
        let normalized = project.normalizedInternalIDs()
        let guides = try #require(normalized.chapters.first?.guides)
        let allIDs = normalized.chapters.flatMap(\.annotations).map(\.internalID)
            + guides.map(\.internalID)

        // 期待値：座標はclampされ、guide IDは注釈を含むmanifest全体で一意になる（Then）
        #expect(guides[0].position == OpenGraphiteCanvasGuide.maximumCoordinateMagnitude)
        #expect(guides[1].position == -120)
        #expect(Set(allIDs).count == allIDs.count)
        #expect(guides.allSatisfy { !$0.internalID.isEmpty })
        #expect(OpenGraphiteCanvasGuide.normalizedPosition(.infinity) == nil)
    }
}
